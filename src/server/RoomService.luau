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
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local Buildables = require(script.Parent.Buildables)
local PlacementService = require(script.Parent.PlacementService)

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

-- Is this asset name something that walls a room in? Anything from the
-- "Walls & Doors" category (doors count — a doorway isn't a hole).
local function blocksEnclosure(assetName)
	local asset = assetName and Buildables.get(assetName)
	return asset ~= nil and (asset.category == "Walls & Doors" or asset.door)
end

-- Evaluate a painted region against Config.RoomRequirements. Returns
-- (met, statusText).
local function evaluateRegion(zone, typeName, regionCells, placedInfos)
	local req = Config.RoomRequirements[typeName]
	if not req then
		return true, "✓"
	end
	local missing = {}

	if req.minCells and #regionCells < req.minCells then
		table.insert(missing, ("bigger room (%d/%d)"):format(#regionCells, req.minCells))
	end

	if req.enclosed then
		local inRegion = {}
		for _, cell in ipairs(regionCells) do
			inRegion[cell[1] .. ":" .. cell[2]] = true
		end
		local enclosed = true
		for _, cell in ipairs(regionCells) do
			for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, nz = cell[1] + step[1], cell[2] + step[2]
				if not inRegion[nx .. ":" .. nz] then
					local outOfBounds = nx < 0 or nx >= zone.info.cols or nz < 0 or nz >= zone.info.rows
					if outOfBounds or not blocksEnclosure(PlacementService.cellAsset(zone, nx, nz)) then
						enclosed = false
					end
				end
				if not enclosed then
					break
				end
			end
			if not enclosed then
				break
			end
		end
		if not enclosed then
			table.insert(missing, "surround with walls + a door")
		end
	end

	if req.attrCounts then
		local inRegion = {}
		for _, cell in ipairs(regionCells) do
			inRegion[cell[1] .. ":" .. cell[2]] = true
		end
		for attrName, wanted in pairs(req.attrCounts) do
			local count = 0
			for _, info in ipairs(placedInfos) do
				if info.model:GetAttribute(attrName) == true then
					local overlaps = false
					for x = info.gx, info.gx + info.w - 1 do
						for z = info.gz, info.gz + info.d - 1 do
							if inRegion[x .. ":" .. z] then
								overlaps = true
							end
						end
					end
					if overlaps then
						count += 1
					end
				end
			end
			if count < wanted then
				local label = Config.RequirementText[attrName] or attrName
				table.insert(missing, ("%d× %s"):format(wanted - count, label))
			end
		end
	end

	if #missing == 0 then
		return true, "✓ ready"
	end
	return false, "needs: " .. table.concat(missing, ", ")
end

-- The room's name written flat on the floor, Prison Architect style.
-- One label per contiguous region, found by flood fill. Each label also
-- shows the region's requirement status (PA's "this room needs...").
local function rebuildLabels(zone)
	local state = zoneRooms[zone]
	state.labelsFolder:ClearAllChildren()

	-- Snapshot the placed objects once for the requirement checks.
	local placedInfos = {}
	for _, model in ipairs(zone.placed:GetChildren()) do
		local asset = Buildables.get(model:GetAttribute("Asset") or "")
		local gx = model:GetAttribute("GX")
		local gz = model:GetAttribute("GZ")
		local r = model:GetAttribute("Rot")
		if asset and type(gx) == "number" and type(gz) == "number" and type(r) == "number" then
			local w, d = GridMath.footprint(asset, r)
			table.insert(placedInfos, { model = model, gx = gx, gz = gz, w = w, d = d })
		end
	end

	local map = state.map
	local seen = {}
	for z = 0, zone.info.rows - 1 do
		for x = 0, zone.info.cols - 1 do
			local startKey = cellKey(x, z)
			local t = map[startKey]
			if t and not seen[startKey] then
				-- Flood-fill the whole connected region of this type.
				seen[startKey] = true
				local stack = { { x, z } }
				local regionCells = {}
				local minX, maxX, minZ, maxZ = x, x, z, z
				while #stack > 0 do
					local cell = table.remove(stack)
					table.insert(regionCells, cell)
					local cx, cz = cell[1], cell[2]
					minX, maxX = math.min(minX, cx), math.max(maxX, cx)
					minZ, maxZ = math.min(minZ, cz), math.max(maxZ, cz)
					for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
						local nx, nz = cx + step[1], cz + step[2]
						if nx >= 0 and nx < zone.info.cols and nz >= 0 and nz < zone.info.rows then
							local nkey = cellKey(nx, nz)
							if map[nkey] == t and not seen[nkey] then
								seen[nkey] = true
								table.insert(stack, { nx, nz })
							end
						end
					end
				end

				local widthStuds = (maxX - minX + 1) * GRID
				local depthStuds = (maxZ - minZ + 1) * GRID
				local labelPart = Instance.new("Part")
				labelPart.Name = "RoomLabel"
				labelPart.Anchored = true
				labelPart.CanCollide = false
				labelPart.CanQuery = false
				labelPart.CanTouch = false
				labelPart.CastShadow = false
				labelPart.Transparency = 1
				labelPart.Size = Vector3.new(math.min(widthStuds, 28), 0.05, math.clamp(depthStuds, 3, 7))
				labelPart.CFrame = zone.info.corner
					* CFrame.new((minX + maxX + 1) / 2 * GRID, 0.22, (minZ + maxZ + 1) / 2 * GRID)

				local met, statusText = evaluateRegion(zone, Config.RoomTypes[t].name, regionCells, placedInfos)

				local surface = Instance.new("SurfaceGui")
				surface.Face = Enum.NormalId.Top
				surface.PixelsPerStud = 25
				surface.Parent = labelPart
				local text = Instance.new("TextLabel")
				text.Size = UDim2.new(1, 0, 0.58, 0)
				text.BackgroundTransparency = 1
				text.Font = Enum.Font.GothamBlack
				text.TextScaled = true
				text.TextColor3 = Color3.fromRGB(255, 255, 255)
				text.TextTransparency = 0.15
				text.TextStrokeTransparency = 0.6
				text.Text = string.upper(Config.RoomTypes[t].name)
				text.Parent = surface
				local statusLabel = Instance.new("TextLabel")
				statusLabel.AnchorPoint = Vector2.new(0, 1)
				statusLabel.Position = UDim2.new(0, 0, 1, 0)
				statusLabel.Size = UDim2.new(1, 0, 0.4, 0)
				statusLabel.BackgroundTransparency = 1
				statusLabel.Font = Enum.Font.GothamBold
				statusLabel.TextScaled = true
				statusLabel.TextColor3 = met and Color3.fromRGB(150, 255, 160) or Color3.fromRGB(255, 190, 120)
				statusLabel.TextTransparency = 0.1
				statusLabel.TextStrokeTransparency = 0.55
				statusLabel.Text = statusText
				statusLabel.Parent = surface

				labelPart.Parent = state.labelsFolder
			end
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
	rebuildLabels(zone)
end

-- Wiring (called by PlotService) ------------------------------------------

function RoomService.assignZone(player, zone, savedRooms)
	playerZones[player] = zone

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "RoomTiles"
	tilesFolder.Parent = zone.part
	local labelsFolder = Instance.new("Folder")
	labelsFolder.Name = "RoomLabels"
	labelsFolder.Parent = zone.part
	local state = { map = {}, tilesFolder = tilesFolder, labelsFolder = labelsFolder, rowParts = {}, connections = {} }
	zoneRooms[zone] = state

	-- Building or bulldozing can change enclosure and object counts, so
	-- requirement labels re-evaluate (debounced) on any placement change.
	local function queueRebuild()
		if state.rebuildQueued then
			return
		end
		state.rebuildQueued = true
		task.delay(0.2, function()
			state.rebuildQueued = false
			if zoneRooms[zone] == state then
				rebuildLabels(zone)
			end
		end)
	end
	table.insert(state.connections, zone.placed.ChildAdded:Connect(queueRebuild))
	table.insert(state.connections, zone.placed.ChildRemoved:Connect(queueRebuild))

	-- Rebuild the paint from the save (stored as horizontal runs).
	if type(savedRooms) == "table" then
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
		rebuildLabels(zone)
	end
end

function RoomService.releasePlayer(player)
	local zone = playerZones[player]
	playerZones[player] = nil
	if zone and zoneRooms[zone] then
		for _, connection in ipairs(zoneRooms[zone].connections) do
			connection:Disconnect()
		end
		zoneRooms[zone].tilesFolder:Destroy()
		zoneRooms[zone].labelsFolder:Destroy()
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
