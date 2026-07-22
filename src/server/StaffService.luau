-- StaffService: hire and fire staff (Workmen, Guards, Cooks, Janitors),
-- pay their wages, and let them quit when the money runs dry (Prison
-- Architect's rule). Staff are NPCs; what they DO lives in other systems
-- that ask us for their people:
--   * Workmen -> ConstructionService pulls the crew that builds blueprints.
--   * Guards  -> NeedsService reads the guard ratio for prisoner Safety;
--                SecurityService patrols them and sends them chasing.
--   * Cooks   -> NeedsService needs one for the Kitchen->Canteen food chain.
--   * Janitors-> keep hygiene from rotting (a small passive bonus).
--
-- Hiring is free and CLICK-PLACED, PA style: the client sends the grid
-- square the warden clicked and the new hire appears right there. Wages
-- charge every Config.WageInterval seconds; an unpayable bill makes the
-- cheapest staff quit (workmen last — they build everything).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local EconomyService = require(script.Parent.EconomyService)
local InmateService = require(script.Parent.InmateService)
local PathService = require(script.Parent.PathService)

local StaffService = {}

-- player -> { zone, folder, staff = { [typeId] = { model, model, ... } }, spawnCounter }
local records = {}

local function typeDef(typeId)
	for _, def in ipairs(Config.StaffTypes) do
		if def.id == typeId then
			return def
		end
	end
	return nil
end

local function staffPost(zone, index)
	-- The fallback spot (saves, auto-hires): along the plot's front-right.
	local size = zone.part.Size
	local col = index % 5
	local row = math.floor(index / 5)
	return zone.part.CFrame * CFrame.new(size.X / 2 - 6 - col * 4, size.Y / 2, size.Z / 2 - 4 - row * 4)
end

local function publish(player)
	local rec = records[player]
	if not rec then
		return
	end
	local totalWage = 0
	for _, def in ipairs(Config.StaffTypes) do
		local n = #(rec.staff[def.id] or {})
		player:SetAttribute("Staff_" .. def.id, n)
		totalWage += n * def.wage
	end
	player:SetAttribute("StaffWage", totalWage)
end

function StaffService.count(player, typeId)
	local rec = records[player]
	return rec and #(rec.staff[typeId] or {}) or 0
end

function StaffService.hasCook(player)
	return StaffService.count(player, "Cook") > 0
end

-- The live models of one staff type (pruned of destroyed ones) — this is
-- how ConstructionService gets its crew and SecurityService its guards.
function StaffService.getStaff(player, typeId)
	local rec = records[player]
	local out = {}
	if rec then
		local list = rec.staff[typeId]
		if list then
			for i = #list, 1, -1 do
				if list[i].Parent == nil then
					table.remove(list, i)
				end
			end
			for _, model in ipairs(list) do
				table.insert(out, model)
			end
		end
	end
	return out
end

local function spawnStaff(player, def, cf)
	local rec = records[player]
	rec.spawnCounter += 1
	if not cf then
		local total = 0
		for _, def2 in ipairs(Config.StaffTypes) do
			total += #(rec.staff[def2.id] or {})
		end
		cf = staffPost(rec.zone, total)
	end
	local model = InmateService.spawn(cf, rec.spawnCounter, rec.folder, { outfit = def.outfit })
	rec.staff[def.id] = rec.staff[def.id] or {}
	table.insert(rec.staff[def.id], model)
end

local function fireStaff(player, typeId)
	local rec = records[player]
	local list = rec and rec.staff[typeId]
	if list and #list > 0 then
		local model = table.remove(list)
		if model then
			model:Destroy()
		end
		return true
	end
	return false
end

-- Wiring ------------------------------------------------------------------

function StaffService.assignPlayer(player, zone, savedStaff)
	local folder = Instance.new("Folder")
	folder.Name = "Staff"
	folder.Parent = zone.part

	records[player] = { zone = zone, folder = folder, staff = {}, spawnCounter = 0 }

	local sawWorkmen = false
	if type(savedStaff) == "table" then
		for _, def in ipairs(Config.StaffTypes) do
			local n = math.clamp(math.floor(tonumber(savedStaff[def.id]) or 0), 0, Config.MaxStaffPerType)
			for _ = 1, n do
				spawnStaff(player, def)
			end
		end
		-- Pre-Workman saves have no Workman key at all — grant the
		-- starting crew below so old prisons can still build.
		sawWorkmen = savedStaff.Workman ~= nil
	end
	if not sawWorkmen then
		-- Every prison opens with a small crew on payroll: they're what
		-- turns blueprints into buildings. Hire more under Staff.
		local workman = typeDef("Workman")
		for _ = 1, Config.StartingWorkmen do
			spawnStaff(player, workman)
		end
	end
	publish(player)
end

function StaffService.releasePlayer(player)
	local rec = records[player]
	records[player] = nil
	if rec then
		rec.folder:Destroy()
	end
end

function StaffService.snapshotStaff(player)
	local rec = records[player]
	local out = {}
	if rec then
		for _, def in ipairs(Config.StaffTypes) do
			out[def.id] = #(rec.staff[def.id] or {})
		end
	end
	return out
end

-- Player requests ---------------------------------------------------------

function StaffService.handleRequest(player, action, typeId, gx, gz)
	local rec = records[player]
	if not rec then
		return { ok = false, err = "You don't have a plot yet." }
	end
	local def = typeDef(typeId)
	if not def then
		return { ok = false, err = "Unknown staff type." }
	end

	if action == "hire" then
		if #(rec.staff[def.id] or {}) >= Config.MaxStaffPerType then
			return { ok = false, err = "You already have the max " .. def.id .. "s." }
		end
		-- Click-placement: the client sends the grid square the warden
		-- clicked; the hire appears there (PA's drop-the-staff feel).
		local cf = nil
		if gx ~= nil or gz ~= nil then
			if type(gx) ~= "number" or type(gz) ~= "number" then
				return { ok = false, err = "Bad request." }
			end
			gx, gz = math.floor(gx), math.floor(gz)
			local zone = rec.zone
			if gx < 0 or gx >= zone.info.cols or gz < 0 or gz >= zone.info.rows then
				return { ok = false, err = "Outside your plot." }
			end
			if zone.unlocked and not zone.unlocked[gx .. ":" .. gz] then
				return { ok = false, err = "You don't own that land yet." }
			end
			if not PathService.isWalkable(zone, gx, gz) then
				return { ok = false, err = "Something's in the way there." }
			end
			cf = GridMath.regionCenter(zone.info, gx, gz, 1, 1)
		end
		spawnStaff(player, def, cf)
		publish(player)
		return { ok = true }
	elseif action == "fire" then
		if not fireStaff(player, def.id) then
			return { ok = false, err = "No " .. def.id .. " to fire." }
		end
		publish(player)
		return { ok = true }
	end
	return { ok = false, err = "Bad request." }
end

function StaffService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.StaffRequest.OnServerInvoke = StaffService.handleRequest

	-- The payroll: charge wages, and if the till can't cover it, someone
	-- quits until the bill fits (cheapest type first — see StaffTypes).
	task.spawn(function()
		while true do
			task.wait(Config.WageInterval)
			for player, rec in pairs(records) do
				if player:IsDescendantOf(Players) then
					local function bill()
						local total = 0
						for _, def in ipairs(Config.StaffTypes) do
							total += #(rec.staff[def.id] or {}) * def.wage
						end
						return total
					end
					local total = bill()
					if total > 0 then
						if EconomyService.tryCharge(player, total) then
							player:SetAttribute("StaffUnpaid", false)
						else
							local quit = false
							for i = #Config.StaffTypes, 1, -1 do
								if fireStaff(player, Config.StaffTypes[i].id) then
									quit = true
									break
								end
							end
							player:SetAttribute("StaffUnpaid", true)
							publish(player)
							local reduced = bill()
							if quit and reduced > 0 then
								EconomyService.tryCharge(player, reduced)
							end
						end
					end
				end
			end
		end
	end)
end

return StaffService
