-- SecurityService: Phase 5's teeth — guard patrols, escape attempts, and
-- the warden's emergency powers (Lockdown, Roll Call).
--
-- ESCAPES: a prisoner in an angry prison (high unrest) or at the end of
-- their rope (worst need below 20) may bolt for the plot's front row.
-- They run the same A* walk grid as everyone else — out through DOORS,
-- never through walls — so a sealed prison genuinely keeps everyone in.
-- A free (or patrolling) guard gives chase, aiming for a point 70% along
-- the runner's path; reach it nearly in time and the runner is caught
-- and marched back to their cell. No guard fast enough? They're gone:
-- fine paid, capacity lost, alert raised.
--
-- PATROLS: idle guards wander to random walkable squares so the prison
-- feels watched (and chases start from useful places).
--
-- EMERGENCIES: Lockdown confines everyone to their cells (regime forced
-- to Sleep, no new escapes, unrest cools fast, grants halved while it
-- lasts — see NeedsService/EconomyService). Roll Call rounds up every
-- in-progress runner at once, on a cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local Buildables = require(script.Parent.Buildables)
local PathService = require(script.Parent.PathService)
local StaffService = require(script.Parent.StaffService)
local IntakeService = require(script.Parent.IntakeService)
local EconomyService = require(script.Parent.EconomyService)

local SecurityService = {}

local PIVOT_HEIGHT = 3

-- player -> { zone, walks, guardBusy, escapes, alertCount, escaped, lastRollCall }
--   walks[model]     = { points, start, duration } (so a walker can be
--                      stopped mid-stride at the right spot)
--   guardBusy[model] = "patrol" | "chase" (chases may interrupt patrols)
--   escapes[model]   = { active, house }
local records = {}

-- Alerts land in a player attribute; the counter prefix guarantees the
-- changed-signal fires even for identical texts (client strips it).
local function alert(player, text)
	local rec = records[player]
	if not rec then
		return
	end
	rec.alertCount += 1
	player:SetAttribute("SecurityAlert", rec.alertCount .. "|" .. text)
end

-- Walk bookkeeping ---------------------------------------------------------

local function pathLength(points)
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

local function pointAlong(points, dist)
	for i = 2, #points do
		local seg = points[i] - points[i - 1]
		local len = seg.Magnitude
		if dist <= len or i == #points then
			if len < 0.001 then
				return points[i]
			end
			return points[i - 1] + seg * math.clamp(dist / len, 0, 1)
		end
		dist -= len
	end
	return points[#points]
end

local function rememberWalk(rec, model, points, duration)
	rec.walks[model] = { points = points, start = workspace:GetServerTimeNow(), duration = duration }
end

-- Where are this walker's feet right now?
local function currentFloorPos(rec, model)
	local walk = rec.walks[model]
	if walk then
		local elapsed = workspace:GetServerTimeNow() - walk.start
		if elapsed < walk.duration then
			local total = pathLength(walk.points)
			return pointAlong(walk.points, total * math.clamp(elapsed / walk.duration, 0, 1))
		end
	end
	return model:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0)
end

-- Halt a walker exactly where the animation has them and return the spot.
local function stopWalk(rec, model)
	local pos = currentFloorPos(rec, model)
	PathService.finishWalk(model, CFrame.new(pos + Vector3.new(0, PIVOT_HEIGHT, 0)))
	rec.walks[model] = nil
	return pos
end

-- Homes --------------------------------------------------------------------

local function houseFloorPos(house)
	local boxCF, boxSize = house:GetBoundingBox()
	return (boxCF * CFrame.new(-1.5, -boxSize.Y / 2, 1)).Position
end

local function houseFootprint(house)
	local footprint = { gx = house:GetAttribute("GX") or 0, gz = house:GetAttribute("GZ") or 0, w = 1, d = 1 }
	local asset = Buildables.get(house:GetAttribute("Asset") or "")
	if asset then
		footprint.w, footprint.d = GridMath.footprint(asset, house:GetAttribute("Rot") or 0)
	end
	return footprint
end

-- March a rounded-up prisoner back to their bed.
local function sendHome(rec, prisoner, house, fromPos)
	if not (house and house.Parent) then
		prisoner:SetAttribute("Escaping", nil)
		return
	end
	local route = PathService.findRoute(rec.zone, fromPos, houseFootprint(house), houseFloorPos(house))
	if not route then
		prisoner:SetAttribute("Escaping", nil)
		return
	end
	local duration = PathService.startWalk(prisoner, route, Config.EscortSpeed)
	rememberWalk(rec, prisoner, route, duration)
	task.delay(duration, function()
		if prisoner.Parent == nil then
			return
		end
		PathService.finishWalk(prisoner, CFrame.new(houseFloorPos(house) + Vector3.new(0, PIVOT_HEIGHT, 0)))
		rec.walks[prisoner] = nil
		prisoner:SetAttribute("Escaping", nil)
	end)
end

-- Escapes ------------------------------------------------------------------

-- The runner's goal: any walkable square on the plot's front row (+Z).
local function frontTarget(zone)
	local cols, rows = zone.info.cols, zone.info.rows
	local mid = math.floor(cols / 2)
	for offset = 0, mid do
		for _, x in ipairs({ mid - offset, mid + offset }) do
			if x >= 0 and x < cols and PathService.isWalkable(zone, x, rows - 1) then
				return x, rows - 1
			end
		end
	end
	return nil
end

-- Round up a runner (lockdown / roll call): stop them where they are and
-- march them home. Returns true if there was an attempt to cancel.
local function cancelEscape(rec, prisoner)
	local attempt = rec.escapes[prisoner]
	if not attempt or not attempt.active then
		return false
	end
	attempt.active = false
	rec.escapes[prisoner] = nil
	if prisoner.Parent == nil then
		return true
	end
	local pos = stopWalk(rec, prisoner)
	sendHome(rec, prisoner, attempt.house, pos)
	return true
end

local function tryEscape(player, rec, entry)
	local prisoner = entry.model
	if rec.escapes[prisoner] then
		return
	end
	if prisoner:GetAttribute("EscortStart") ~= nil then
		return -- mid-walk on someone else's clock (regime/escort)
	end
	local zone = rec.zone
	local now = workspace:GetServerTimeNow()
	prisoner:SetAttribute("EscapeCooldown", now + Config.EscapeCooldown)

	local tx, tz = frontTarget(zone)
	if not tx then
		return
	end
	local fromPos = prisoner:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0)
	local targetPos = GridMath.regionCenter(zone.info, tx, tz, 1, 1).Position
	local route = PathService.findRoute(zone, fromPos, { gx = tx, gz = tz, w = 1, d = 1 }, targetPos)
	if not route then
		return -- sealed tight: the walls are doing their job
	end

	local attempt = { active = true, house = entry.house }
	rec.escapes[prisoner] = attempt
	prisoner:SetAttribute("Escaping", true)
	local duration = PathService.startWalk(prisoner, route, Config.EscapeRunSpeed)
	rememberWalk(rec, prisoner, route, duration)
	local name = prisoner:GetAttribute("NpcName") or "A prisoner"
	alert(player, "🚨 " .. name .. " is making a run for it!")

	-- Can a guard cut them off? Aim for a point partway along the route.
	local total = pathLength(route)
	local interceptPos = pointAlong(route, total * Config.InterceptFraction)
	local tIntercept = duration * Config.InterceptFraction
	local chaser, chaseRoute = nil, nil
	for _, guard in ipairs(StaffService.getStaff(player, "Guard")) do
		local busy = rec.guardBusy[guard]
		if busy == nil or busy == "patrol" then -- chases interrupt patrols
			local gFrom = currentFloorPos(rec, guard)
			local ix, iz = GridMath.worldToCell(zone.info, interceptPos, 1, 1)
			local gRoute = PathService.findRoute(zone, gFrom, { gx = ix, gz = iz, w = 1, d = 1 }, interceptPos)
			if gRoute then
				local gDur = math.max(0.5, pathLength(gRoute) / Config.EscapeRunSpeed)
				local tCatch = math.max(tIntercept, gDur)
				if gDur <= tIntercept + Config.GuardCatchGrace and tCatch < duration then
					chaser, chaseRoute = guard, gRoute
					break
				end
			end
		end
	end

	if chaser then
		stopWalk(rec, chaser) -- drop whatever patrol they were on
		rec.guardBusy[chaser] = "chase"
		local chaseDur = PathService.startWalk(chaser, chaseRoute, Config.EscapeRunSpeed)
		rememberWalk(rec, chaser, chaseRoute, chaseDur)
		local tCatch = math.max(tIntercept, chaseDur)
		task.delay(tCatch, function()
			if chaser.Parent ~= nil then
				stopWalk(rec, chaser)
			end
			if not attempt.active or prisoner.Parent == nil then
				-- Already rounded up (lockdown/roll call) or gone.
				rec.guardBusy[chaser] = nil
				return
			end
			-- CAUGHT.
			attempt.active = false
			rec.escapes[prisoner] = nil
			local pos = stopWalk(rec, prisoner)
			alert(player, "👮 " .. name .. " was caught and marched back to their cell.")
			sendHome(rec, prisoner, attempt.house, pos)
			task.delay(2, function()
				rec.guardBusy[chaser] = nil
			end)
		end)
	end

	-- The gate: still active when the run completes means they're gone.
	task.delay(duration, function()
		if not attempt.active or prisoner.Parent == nil then
			return
		end
		attempt.active = false
		rec.escapes[prisoner] = nil
		rec.walks[prisoner] = nil
		rec.escaped += 1
		player:SetAttribute("PrisonEscapes", rec.escaped)
		EconomyService.tryCharge(player, Config.EscapeFine)
		alert(player, "🚨 " .. name .. " ESCAPED! Fine: " .. Format.money(Config.EscapeFine))
		prisoner:Destroy()
		IntakeService.poke(player)
	end)
end

-- Emergencies --------------------------------------------------------------

function SecurityService.handleRequest(player, action)
	local rec = records[player]
	if not rec then
		return { ok = false, err = "You don't have a plot yet." }
	end

	if action == "lockdown" then
		local on = player:GetAttribute("PrisonLockdown") ~= true
		player:SetAttribute("PrisonLockdown", on)
		if on then
			local rounded = 0
			for prisoner in pairs(rec.escapes) do
				if cancelEscape(rec, prisoner) then
					rounded += 1
				end
			end
			alert(player, rounded > 0
				and ("🔒 LOCKDOWN — %d runner%s rounded up."):format(rounded, rounded == 1 and "" or "s")
				or "🔒 LOCKDOWN — everyone to their cells.")
		else
			alert(player, "🔓 Lockdown lifted — back to the regime.")
		end
		return { ok = true, on = on }
	elseif action == "rollcall" then
		local now = workspace:GetServerTimeNow()
		local remaining = Config.RollCallCooldown - (now - rec.lastRollCall)
		if remaining > 0 then
			return { ok = false, err = ("wait %ds"):format(math.ceil(remaining)) }
		end
		rec.lastRollCall = now
		local rounded = 0
		for prisoner in pairs(rec.escapes) do
			if cancelEscape(rec, prisoner) then
				rounded += 1
			end
		end
		local housedCount = #IntakeService.getHoused(player)
		alert(player, rounded > 0
			and ("📢 Roll call: %d runner%s rounded up, %d accounted for."):format(
				rounded, rounded == 1 and "" or "s", housedCount)
			or ("📢 Roll call: all %d prisoners accounted for."):format(housedCount))
		return { ok = true }
	end
	return { ok = false, err = "Bad request." }
end

-- Wiring -------------------------------------------------------------------

function SecurityService.assignPlayer(player, zone)
	records[player] = {
		zone = zone,
		walks = {},
		guardBusy = {},
		escapes = {},
		alertCount = 0,
		escaped = 0,
		lastRollCall = 0,
	}
	player:SetAttribute("PrisonLockdown", false)
	player:SetAttribute("PrisonEscapes", 0)
end

function SecurityService.releasePlayer(player)
	records[player] = nil
end

function SecurityService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.EmergencyRequest.OnServerInvoke = SecurityService.handleRequest

	-- Patrols: idle guards wander — presence is deterrence (and chases
	-- start from useful places).
	task.spawn(function()
		while true do
			task.wait(Config.PatrolInterval)
			for player, rec in pairs(records) do
				for model in pairs(rec.guardBusy) do
					if model.Parent == nil then
						rec.guardBusy[model] = nil
					end
				end
				for model in pairs(rec.walks) do
					if model.Parent == nil then
						rec.walks[model] = nil
					end
				end
				local zone = rec.zone
				for _, guard in ipairs(StaffService.getStaff(player, "Guard")) do
					if rec.guardBusy[guard] == nil
						and guard:GetAttribute("EscortStart") == nil
						and math.random() < Config.PatrolChance
					then
						for _ = 1, 6 do
							local x = math.random(0, zone.info.cols - 1)
							local z = math.random(0, zone.info.rows - 1)
							if PathService.isWalkable(zone, x, z) then
								local fromPos = guard:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0)
								local targetPos = GridMath.regionCenter(zone.info, x, z, 1, 1).Position
								local route = PathService.findRoute(
									zone, fromPos, { gx = x, gz = z, w = 1, d = 1 }, targetPos)
								if route then
									rec.guardBusy[guard] = "patrol"
									local duration = PathService.startWalk(guard, route, Config.PatrolSpeed)
									rememberWalk(rec, guard, route, duration)
									task.delay(duration, function()
										if guard.Parent == nil then
											return
										end
										-- A chase may have taken over this guard
										-- mid-patrol — only land the patrol if
										-- this walk is still theirs.
										local walk = rec.walks[guard]
										if walk and walk.points == route then
											PathService.finishWalk(guard,
												CFrame.new(targetPos + Vector3.new(0, PIVOT_HEIGHT, 0)))
											rec.walks[guard] = nil
											rec.guardBusy[guard] = nil
										end
									end)
								end
								break
							end
						end
					end
				end
			end
		end
	end)

	-- Escape checks.
	task.spawn(function()
		while true do
			task.wait(Config.EscapeCheckInterval)
			local now = workspace:GetServerTimeNow()
			for player, rec in pairs(records) do
				if not player:IsDescendantOf(Players) then
					continue
				end
				if player:GetAttribute("PrisonLockdown") == true then
					continue -- confined to cells: nobody runs
				end
				local unrest = player:GetAttribute("PrisonUnrest") or 0
				for _, entry in ipairs(IntakeService.getHoused(player)) do
					local prisoner = entry.model
					if rec.escapes[prisoner] == nil and now >= (prisoner:GetAttribute("EscapeCooldown") or 0) then
						local chance = Config.EscapeUnrestFactor * (unrest / 100)
						if (prisoner:GetAttribute("MoodValue") or 100) < 20 then
							chance += Config.EscapeDesperationChance
						end
						if chance > 0 and math.random() < chance then
							tryEscape(player, rec, entry)
						end
					end
				end
			end
		end
	end)
end

return SecurityService
