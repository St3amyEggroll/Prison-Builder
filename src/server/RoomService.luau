-- RoomService: Prison Architect-style room designation. The player picks
-- a room type FIRST, then drags a rectangle on their plot; the floor
-- tints with that room's color. Painting is per grid square underneath
-- everything else, so walls and objects sit on top of it naturally.
--
-- For now rooms are paint — the meaning (a Cell needs a bed, inmates eat
-- in the Canteen) arrives with the needs/economy phases, and this data
-- is already saved per square so nothing will need repainting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RoomService = {}

local GRID = Config.GridSize

local playerZones = {} -- player -> zone record
local zoneRooms = {} -- zone -> { map = {["x:z"] = typeId], tilesFolder, rowParts = {[z] = {parts}} }

local function cellKey(x, z)
	return x .. ":" .. z
end

-- Rendering: one thin colored strip per run of same-type squares in a
-- row — a 10x10 room is ~10 parts, not 100.
local function renderRow(zone, z)
	local state = zoneRooms[zone]
	if state.rowParts[z] then
		for _, p in ipairs(state.rowParts[z]) do
			p:Destroy()
		end
	end
	state.rowParts[z] = {}

	local cols = zone.info.cols
	local x = 0
	while x < cols do
		local t = state.map[cellKey(x, z)]
		if t then
			local runStart = x
			while x < cols and state.map[cellKey(x, z)] == t do
				x += 1
			end
			local len = x - runStart
			local strip = Instance.new("Part")
			strip.Anchored = true
			strip.CanCollide = false
			strip.CanQuery = false
			strip.CanTouch = false
			strip.CastShadow = false
			strip.Material = Enum.Material.SmoothPlastic
			strip.Transparency = 0.35
			strip.Color = Config.RoomTypes[t].color
			strip.Size = Vector3.new(len * GRID, 0.12, GRID)
			strip.CFrame = zone.info.corner * CFrame.new((runStart + len / 2) * GRID, 0.07, (z + 0.5) * GRID)
			strip.Name = "RoomStrip"
			strip.Parent = state.tilesFolder
			table.insert(state.rowParts[z], strip)
		else
			x += 1
		end
	end
end

local function paintRect(zone, typeId, x1, z1, x2, z2)
	local state = zoneRooms[zone]
	for z = z1, z2 do
		for x = x1, x2 do
			state.map[cellKey(x, z)] = typeId ~= 0 and typeId or nil
		end
	end
	for z = z1, z2 do
		renderRow(zone, z)
	end
end

-- Wiring (called by PlotService) ------------------------------------------

function RoomService.assignZone(player, zone, savedRooms)
	playerZones[player] = zone

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "RoomTiles"
	tilesFolder.Parent = zone.part
	zoneRooms[zone] = { map = {}, tilesFolder = tilesFolder, rowParts = {} }

	-- Rebuild the paint from the save (stored as horizontal runs).
	if type(savedRooms) == "table" then
		local state = zoneRooms[zone]
		local touchedRows = {}
		for _, run in ipairs(savedRooms) do
			if type(run) == "table"
				and type(run.t) == "number" and Config.RoomTypes[run.t]
				and type(run.x) == "number" and type(run.z) == "number" and type(run.l) == "number"
			then
				local z = math.floor(run.z)
				for x = math.floor(run.x), math.floor(run.x) + math.floor(run.l) - 1 do
					if x >= 0 and x < zone.info.cols and z >= 0 and z < zone.info.rows then
						state.map[cellKey(x, z)] = math.floor(run.t)
					end
				end
				touchedRows[z] = true
			end
		end
		for z in pairs(touchedRows) do
			renderRow(zone, z)
		end
	end
end

function RoomService.releasePlayer(player)
	local zone = playerZones[player]
	playerZones[player] = nil
	if zone and zoneRooms[zone] then
		zoneRooms[zone].tilesFolder:Destroy()
		zoneRooms[zone] = nil
	end
end

-- What SaveService writes: the paint compressed into horizontal runs.
function RoomService.snapshotRooms(player)
	local zone = playerZones[player]
	local state = zone and zoneRooms[zone]
	if not state then
		return {}
	end
	local runs = {}
	for z = 0, zone.info.rows - 1 do
		local x = 0
		while x < zone.info.cols do
			local t = state.map[cellKey(x, z)]
			if t then
				local runStart = x
				while x < zone.info.cols and state.map[cellKey(x, z)] == t do
					x += 1
				end
				table.insert(runs, { t = t, x = runStart, z = z, l = x - runStart })
			else
				x += 1
			end
		end
	end
	return runs
end

-- Player requests ---------------------------------------------------------

function RoomService.handlePaint(player, typeId, x1, z1, x2, z2)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if type(typeId) ~= "number" or type(x1) ~= "number" or type(z1) ~= "number"
		or type(x2) ~= "number" or type(z2) ~= "number"
	then
		return { ok = false, err = "Bad request." }
	end
	typeId = math.floor(typeId)
	if typeId ~= 0 and not Config.RoomTypes[typeId] then
		return { ok = false, err = "Unknown room type." }
	end

	-- Normalize and clamp the rectangle to the zone.
	x1, x2 = math.min(x1, x2), math.max(x1, x2)
	z1, z2 = math.min(z1, z2), math.max(z1, z2)
	x1 = math.clamp(math.floor(x1), 0, zone.info.cols - 1)
	x2 = math.clamp(math.floor(x2), 0, zone.info.cols - 1)
	z1 = math.clamp(math.floor(z1), 0, zone.info.rows - 1)
	z2 = math.clamp(math.floor(z2), 0, zone.info.rows - 1)

	paintRect(zone, typeId, x1, z1, x2, z2)
	return { ok = true }
end

function RoomService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.RoomPaintRequest.OnServerInvoke = RoomService.handlePaint
end

return RoomService
