-- StaffService: hire and fire staff (Guards, Cooks, Janitors), pay their
-- wages, and let them quit when the money runs dry (Prison Architect's
-- rule). Staff are NPCs that mill about the prison; what they DO lives in
-- other systems that ask us "how many guards / any cook?":
--   * Guards  -> NeedsService reads the guard ratio for prisoner Safety.
--   * Cooks   -> NeedsService needs one for the Kitchen->Canteen food chain.
--   * Janitors-> keep hygiene from rotting (a small passive bonus).
--
-- Hiring is free; wages charge every Config.WageInterval seconds. Can't
-- pay the full bill? Someone quits, and the warden gets a warning.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local InmateService = require(script.Parent.InmateService)

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
	-- Staff gather along the front-right of the plot, opposite the crew.
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

local function spawnStaff(player, def)
	local rec = records[player]
	rec.spawnCounter += 1
	local total = 0
	for _, def2 in ipairs(Config.StaffTypes) do
		total += #(rec.staff[def2.id] or {})
	end
	local model = InmateService.spawn(staffPost(rec.zone, total), rec.spawnCounter, rec.folder, { outfit = def.outfit })
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

	if type(savedStaff) == "table" then
		for _, def in ipairs(Config.StaffTypes) do
			local n = math.clamp(math.floor(tonumber(savedStaff[def.id]) or 0), 0, Config.MaxStaffPerType)
			for _ = 1, n do
				spawnStaff(player, def)
			end
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

function StaffService.handleRequest(player, action, typeId)
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
		spawnStaff(player, def)
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
	-- quits until the bill fits.
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
							-- Can't pay: quit the priciest staff, warn, retry.
							local quit = false
							for i = #Config.StaffTypes, 1, -1 do
								if fireStaff(player, Config.StaffTypes[i].id) then
									quit = true
									break
								end
							end
							player:SetAttribute("StaffUnpaid", true)
							publish(player)
							-- Charge the reduced bill if we now can.
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
