-- NeedsService: gives every housed prisoner a life. Five needs decay over
-- time (Food, Sleep, Hygiene, Recreation, Safety), and the REGIME (the
-- prison's daily schedule on the shared clock) tells them where to be:
--
--   Sleep    -> walk to their bed, sleep need recovers
--   Eat      -> walk to a ✓-ready Canteen; food recovers ONLY if the food
--               chain is complete (a ✓-ready Kitchen + a hired Cook)
--   Yard     -> walk to a ✓-ready Yard, recreation recovers
--   FreeTime -> shower if grubby (✓-ready Shower), else mill about
--
-- Safety recovers when enough Guards are on staff, decays otherwise.
-- Neglected needs raise UNREST, which cuts grant income (EconomyService)
-- and is the fuse for Phase 5's riots and escapes.
--
-- Movement reuses PathService: the server picks a destination, pathfinds,
-- and tracks a LOGICAL position (updated when a walk finishes) so need
-- math never fights the client-side walk animation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local PathService = require(script.Parent.PathService)
local RoomService = require(script.Parent.RoomService)
local IntakeService = require(script.Parent.IntakeService)
local StaffService = require(script.Parent.StaffService)

local NeedsService = {}

local PIVOT_HEIGHT = 3
local ARRIVE_DIST = 8

-- model -> per-prisoner state
local lives = {}
-- player -> zone (set on assign)
local playerZones = {}

local function newLife(pos)
	return {
		needs = { food = 80, sleep = 80, hygiene = 80, recreation = 80, safety = 80 },
		pos = pos, -- logical feet position
		walking = false,
		walkUntil = 0,
	}
end

-- Centre-of-mass world position of the nearest ✓-ready room of a type.
local function readyRoomCenter(player, zone, roomType, fromPos)
	local best, bestDist
	for _, region in ipairs(RoomService.getReadyRegions(player)) do
		if region.type == roomType then
			local sx, sz, n = 0, 0, 0
			for _, cell in ipairs(region.cells) do
				sx += cell[1]
				sz += cell[2]
				n += 1
			end
			local cx, cz = math.floor(sx / n), math.floor(sz / n)
			local pos = GridMath.regionCenter(zone.info, cx, cz, 1, 1).Position
			local dist = (pos - fromPos).Magnitude
			if not bestDist or dist < bestDist then
				best, bestDist = pos, dist
			end
		end
	end
	return best
end

-- Where should this prisoner be right now, which need does being there
-- feed, and is that need actually being provided?
local function resolveActivity(player, zone, life, house, activity)
	if activity == "Sleep" then
		local pos = house and house.Parent and (house:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0))
		return pos, "sleep", pos ~= nil
	elseif activity == "Eat" then
		local pos = readyRoomCenter(player, zone, "Canteen", life.pos)
		-- The food chain: a canteen alone isn't enough — you need a
		-- kitchen making the food and a cook to run it.
		local fed = pos ~= nil
			and readyRoomCenter(player, zone, "Kitchen", life.pos) ~= nil
			and StaffService.hasCook(player)
		return pos, "food", fed
	elseif activity == "Yard" then
		local pos = readyRoomCenter(player, zone, "Yard", life.pos)
		return pos, "recreation", pos ~= nil
	else -- FreeTime
		if life.needs.hygiene < 55 then
			local pos = readyRoomCenter(player, zone, "Shower", life.pos)
			if pos then
				return pos, "hygiene", true
			end
		end
		local pos = house and house.Parent and (house:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0))
		return pos, nil, false
	end
end

local function walkTo(zone, model, life, targetPos)
	local from = life.pos
	-- Target a walkable square near the destination.
	local tx, tz = GridMath.worldToCell(zone.info, targetPos, 1, 1)
	local footprint = { gx = tx, gz = tz, w = 1, d = 1 }
	local route = PathService.findRoute(zone, from, footprint, targetPos)
	if not route then
		return false
	end
	local duration = PathService.startWalk(model, route, Config.WalkSpeed)
	life.walking = true
	life.walkUntil = workspace:GetServerTimeNow() + duration
	task.delay(duration, function()
		if model.Parent == nil then
			return
		end
		PathService.finishWalk(model, CFrame.new(targetPos + Vector3.new(0, PIVOT_HEIGHT, 0)))
		life.pos = targetPos
		life.walking = false
	end)
	return true
end

local function step(player)
	local zone = playerZones[player]
	if not zone then
		return
	end

	local hour = 12
	local epoch = workspace:GetAttribute("ClockEpoch")
	if epoch then
		local frac = ((workspace:GetServerTimeNow() - epoch) % Config.DayLength) / Config.DayLength
		hour = frac * 24
	end
	local activity = Config.activityAt(hour)

	local housed = IntakeService.getHoused(player)
	local guardCount = StaffService.count(player, "Guard")
	local janitorCount = StaffService.count(player, "Janitor")
	local prisonerCount = #housed
	local safetyOk = prisonerCount == 0
		or guardCount >= math.ceil(prisonerCount / Config.GuardsPerPrisoners)

	local unrestSum = 0

	for _, entry in ipairs(housed) do
		local model = entry.model
		local life = lives[model]
		if not life then
			life = newLife(model:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0))
			lives[model] = life
		end

		-- Decay.
		for need, rate in pairs(Config.NeedDecay) do
			life.needs[need] = math.max(0, life.needs[need] - rate * Config.NeedTick)
		end
		life.needs.safety = math.clamp(
			life.needs.safety + (safetyOk and Config.SafetyRegen or -Config.SafetyDecay) * Config.NeedTick,
			0, 100
		)

		-- Behaviour: go where the regime says, recover the right need there.
		if not life.walking and workspace:GetServerTimeNow() >= life.walkUntil then
			local target, need, provided = resolveActivity(player, zone, life, entry.house, activity)
			if target and (target - life.pos).Magnitude > ARRIVE_DIST then
				walkTo(zone, model, life, target)
			elseif need and provided then
				local regen = Config.NeedRegen[need] or 0
				-- Janitors give a gentle hygiene bump everywhere.
				life.needs[need] = math.min(100, life.needs[need] + regen * Config.NeedTick)
			end
		end
		if janitorCount > 0 then
			life.needs.hygiene = math.min(100, life.needs.hygiene + 0.1 * janitorCount * Config.NeedTick)
		end

		-- Worst need drives the mood shown over their head.
		local worst, worstVal = "content", 101
		for need, val in pairs(life.needs) do
			if val < worstVal then
				worst, worstVal = need, val
			end
		end
		model:SetAttribute("Mood", worstVal < 25 and worst or (worstVal < 50 and "uneasy" or "content"))
		model:SetAttribute("MoodValue", math.floor(worstVal))

		-- This prisoner's contribution to unrest.
		local avg = 0
		for _, val in pairs(life.needs) do
			avg += val
		end
		avg /= 5
		if avg < 40 then
			unrestSum += (40 - avg)
		end
	end

	-- Prison-wide unrest: nudge toward the neglect level.
	local unrest = player:GetAttribute("PrisonUnrest") or 0
	if prisonerCount > 0 then
		local pressure = unrestSum / prisonerCount -- 0..40ish
		if pressure > 8 then
			unrest = math.min(100, unrest + Config.UnrestRise * Config.NeedTick)
		else
			unrest = math.max(0, unrest - Config.UnrestFall * Config.NeedTick)
		end
	else
		unrest = math.max(0, unrest - Config.UnrestFall * Config.NeedTick)
	end
	player:SetAttribute("PrisonUnrest", math.floor(unrest))
	player:SetAttribute("RegimeActivity", activity)
end

function NeedsService.assignPlayer(player, zone)
	playerZones[player] = zone
end

function NeedsService.releasePlayer(player)
	playerZones[player] = nil
	-- Drop lives whose models belong to this zone (cheap: prune dead ones).
	for model in pairs(lives) do
		if model.Parent == nil then
			lives[model] = nil
		end
	end
end

function NeedsService.init()
	task.spawn(function()
		while true do
			task.wait(Config.NeedTick)
			for model in pairs(lives) do
				if model.Parent == nil then
					lives[model] = nil
				end
			end
			for player in pairs(playerZones) do
				step(player)
			end
		end
	end)
end

return NeedsService
