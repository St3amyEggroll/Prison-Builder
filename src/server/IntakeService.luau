-- IntakeService: how prisoners actually arrive (Prison Architect's
-- intake report, Roblox-ified).
--
-- The flow:
--   1. The warden accepts a prisoner (or has auto-intake ON).
--   2. The prisoner appears at the FRONT of the plot — handcuffed,
--      standing still. They cannot move on their own.
--   3. The moment an empty housing asset exists (any placed model with
--      the SpawnsInmate attribute), they're escorted to it: they walk
--      over, the cuffs come off, and they live there — wandering about.
--   4. No room? They wait at the gate, cuffed. A crowd at your gate IS
--      the "build more cells" warning light.
--
-- The escort walk is animated on each player's device (InmateAnimator):
-- the server just stamps attributes (from, to, start time, duration) and
-- does ONE authoritative move at the end — no per-frame replication.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local Buildables = require(script.Parent.Buildables)
local InmateService = require(script.Parent.InmateService)
local PathService = require(script.Parent.PathService)

local IntakeService = {}

-- The rig's pivot is its torso, exactly 3 studs above the feet (2-stud
-- legs + half the torso). All escort math works in floor positions, so
-- moves add this back to keep feet on the ground.
local PIVOT_HEIGHT = 3

-- player -> {
--   zone, arrivalsFolder, auto, spawnCounter, nextGateSlot,
--   prisoners = array of { model, status = "waiting"|"escorting"|"housed", house },
--   connections = {...},
-- }
local records = {}

local function housingAssets(zone)
	local houses = {}
	for _, model in ipairs(zone.placed:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("SpawnsInmate") == true
			and model:GetAttribute("Blueprint") ~= true -- unbuilt = no capacity
		then
			table.insert(houses, model)
		end
	end
	return houses
end

local function houseFloorCF(house)
	local boxCF, boxSize = house:GetBoundingBox()
	-- Bottom-center of the asset, nudged off-center so they don't stand
	-- inside the bed.
	return (boxCF * CFrame.new(-1.5, -boxSize.Y / 2, 1))
end

local function gateCF(zone, slot)
	-- The front of the plot is the zone Part's +Z side (rotate the Part
	-- in Studio to choose which side that is). Slots spread arrivals out
	-- so they queue instead of stacking.
	local size = zone.part.Size
	local offsetX = (slot - (Config.MaxWaiting - 1) / 2) * 3
	return zone.part.CFrame * CFrame.new(offsetX, size.Y / 2, size.Z / 2 - 3)
end

local function addCuffs(model)
	local torso = model.PrimaryPart
	if not torso then
		return
	end
	local cuffs = Instance.new("Part")
	cuffs.Name = "Cuffs"
	cuffs.Anchored = true
	cuffs.CanCollide = false
	cuffs.CanQuery = false
	cuffs.CanTouch = false
	cuffs.CastShadow = false
	cuffs.Material = Enum.Material.Metal
	cuffs.Color = Color3.fromRGB(60, 60, 65)
	cuffs.Size = Vector3.new(1.4, 0.35, 0.35)
	-- In front of the waist, where the client-side pose holds the hands.
	cuffs.CFrame = torso.CFrame * CFrame.new(0, -0.7, -1.05)
	cuffs.Parent = model
end

local function refresh(player)
	local rec = records[player]
	if not rec then
		return
	end

	-- Prune prisoners whose model is gone (e.g. their cell was demolished
	-- with them inside — that's a transfer, not an escape).
	for i = #rec.prisoners, 1, -1 do
		local prisoner = rec.prisoners[i]
		if prisoner.model.Parent == nil then
			table.remove(rec.prisoners, i)
		elseif prisoner.status ~= "waiting" and (not prisoner.house or prisoner.house.Parent == nil) then
			if prisoner.status == "escorting" then
				-- Their destination was demolished mid-walk; back to waiting.
				prisoner.status = "waiting"
				prisoner.house = nil
				PathService.finishWalk(prisoner.model)
			else
				table.remove(rec.prisoners, i)
			end
		end
	end

	-- Try to escort waiting prisoners into empty houses.
	local houses = housingAssets(rec.zone)
	local occupied = {}
	for _, prisoner in ipairs(rec.prisoners) do
		if prisoner.house then
			occupied[prisoner.house] = true
		end
	end

	for _, prisoner in ipairs(rec.prisoners) do
		if prisoner.status == "waiting" then
			local target = nil
			for _, house in ipairs(houses) do
				if not occupied[house] then
					target = house
					break
				end
			end
			if not target then
				break
			end

			-- Pathfind gate -> cell around walls, through doors. No route
			-- means they wait cuffed (rec.stuck warns the warden).
			local model = prisoner.model
			local from = model:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0)
			local to = houseFloorCF(target).Position
			local footprint = { gx = 0, gz = 0, w = 1, d = 1 }
			do
				local asset = Buildables.get(target:GetAttribute("Asset") or "")
				footprint.gx = target:GetAttribute("GX") or 0
				footprint.gz = target:GetAttribute("GZ") or 0
				if asset then
					footprint.w, footprint.d = GridMath.footprint(asset, target:GetAttribute("Rot") or 0)
				end
			end
			local route = PathService.findRoute(rec.zone, from, footprint, to)
			if not route then
				rec.stuck = true
				break
			end
			rec.stuck = false

			occupied[target] = true
			prisoner.status = "escorting"
			prisoner.house = target
			local duration = PathService.startWalk(model, route, Config.EscortSpeed)

			task.delay(duration, function()
				if prisoner.status ~= "escorting" or model.Parent == nil then
					return
				end
				if not prisoner.house or prisoner.house.Parent == nil then
					return -- refresh() already handled the demolition
				end
				-- The one authoritative move: they now live here.
				PathService.finishWalk(model, houseFloorCF(prisoner.house) * CFrame.new(0, PIVOT_HEIGHT, 0))
				model.Parent = prisoner.house -- demolishing the house removes them too
				local cuffs = model:FindFirstChild("Cuffs")
				if cuffs then
					cuffs:Destroy()
				end
				model:SetAttribute("Handcuffed", false)
				prisoner.status = "housed"
				refresh(player)
			end)
		end
	end

	-- Publish the numbers the Intake panel shows.
	local housed, waiting = 0, 0
	for _, prisoner in ipairs(rec.prisoners) do
		if prisoner.status == "waiting" then
			waiting += 1
		else
			housed += 1
		end
	end
	player:SetAttribute("PrisonCapacity", #houses)
	player:SetAttribute("PrisonHoused", housed)
	player:SetAttribute("PrisonWaiting", waiting)
	player:SetAttribute("AutoIntake", rec.auto)
	player:SetAttribute("IntakeStuck", rec.stuck == true and waiting > 0)
end

local function arrive(player, skipGate)
	local rec = records[player]
	if not rec then
		return false, "No plot yet."
	end
	local waiting = 0
	for _, prisoner in ipairs(rec.prisoners) do
		if prisoner.status == "waiting" then
			waiting += 1
		end
	end
	if not skipGate and waiting >= Config.MaxWaiting then
		return false, "The front gate is crowded — house some prisoners first!"
	end

	rec.spawnCounter += 1
	rec.nextGateSlot = (rec.nextGateSlot % Config.MaxWaiting) + 1
	local model = InmateService.spawn(gateCF(rec.zone, rec.nextGateSlot - 1), rec.spawnCounter, rec.arrivalsFolder)
	model:SetAttribute("Handcuffed", true)
	addCuffs(model)
	table.insert(rec.prisoners, { model = model, status = "waiting", house = nil })
	refresh(player)
	return true
end

-- Wiring (called by PlotService) ------------------------------------------

function IntakeService.assignPlayer(player, zone, savedIntake)
	local arrivalsFolder = Instance.new("Folder")
	arrivalsFolder.Name = "Arrivals"
	arrivalsFolder.Parent = zone.part

	local rec = {
		zone = zone,
		arrivalsFolder = arrivalsFolder,
		auto = true,
		spawnCounter = 0,
		nextGateSlot = 0,
		prisoners = {},
		connections = {},
	}
	records[player] = rec

	if type(savedIntake) == "table" then
		rec.auto = savedIntake.auto ~= false
		-- Restore the population: housed prisoners reappear directly in
		-- their homes (no escort theater on rejoin), waiting ones at the gate.
		local houses = housingAssets(zone)
		local housedCount = math.min(tonumber(savedIntake.housed) or 0, #houses)
		for i = 1, housedCount do
			rec.spawnCounter += 1
			local house = houses[i]
			local model = InmateService.spawn(houseFloorCF(house), rec.spawnCounter, house)
			model:SetAttribute("Handcuffed", false)
			table.insert(rec.prisoners, { model = model, status = "housed", house = house })
		end
		local waitingCount = math.min(tonumber(savedIntake.waiting) or 0, Config.MaxWaiting)
		for _ = 1, waitingCount do
			arrive(player, true)
		end
	end

	-- Anything placed or demolished can change capacity — re-check.
	table.insert(rec.connections, zone.placed.ChildAdded:Connect(function()
		task.defer(refresh, player)
	end))
	table.insert(rec.connections, zone.placed.ChildRemoved:Connect(function()
		task.defer(refresh, player)
	end))

	refresh(player)
end

-- Re-check capacity/escorts (used after moves and blueprint completions).
function IntakeService.poke(player)
	refresh(player)
end

function IntakeService.releasePlayer(player)
	local rec = records[player]
	records[player] = nil
	if rec then
		for _, connection in ipairs(rec.connections) do
			connection:Disconnect()
		end
		rec.arrivalsFolder:Destroy()
	end
end

function IntakeService.snapshotIntake(player)
	local rec = records[player]
	if not rec then
		return { housed = 0, waiting = 0, auto = true }
	end
	local housed, waiting = 0, 0
	for _, prisoner in ipairs(rec.prisoners) do
		if prisoner.status == "waiting" then
			waiting += 1
		else
			housed += 1
		end
	end
	return { housed = housed, waiting = waiting, auto = rec.auto }
end

-- Player requests ---------------------------------------------------------

function IntakeService.handleRequest(player, action)
	local rec = records[player]
	if not rec then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if action == "accept" then
		local ok, err = arrive(player)
		if not ok then
			return { ok = false, err = err }
		end
		return { ok = true }
	elseif action == "toggleAuto" then
		rec.auto = not rec.auto
		refresh(player)
		return { ok = true }
	end
	return { ok = false, err = "Bad request." }
end

function IntakeService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.IntakeRequest.OnServerInvoke = IntakeService.handleRequest

	-- Auto-intake: a new prisoner arrives every IntakeInterval seconds
	-- while there's room to house them (Prison Architect's "Fill Capacity").
	task.spawn(function()
		while true do
			task.wait(Config.IntakeInterval)
			for player, rec in pairs(records) do
				if rec.auto and player:IsDescendantOf(Players) then
					local total = #rec.prisoners
					if total < #housingAssets(rec.zone) then
						arrive(player)
					end
				end
			end
		end
	end)
end

return IntakeService
