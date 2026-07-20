-- PlacementService: the server half of the building system. The client
-- may PREVIEW anything, but nothing exists until this file approves it.
-- Every request is re-checked here (owner? real asset? inside the zone?
-- not overlapping?) because clients can be modified by cheaters — the
-- golden rule of Roblox: never trust the client.
--
-- It also keeps each player's layout as plain data ({name, x, z, rot}
-- per object), which is what gets cloud-saved and rebuilt on rejoin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridMath = require(ReplicatedStorage.Shared.GridMath)
local Buildables = require(script.Parent.Buildables)

local PlacementService = {}

local playerZones = {} -- player -> zone record (set by PlotService)
local occupancy = {} -- zone -> set of "gx:gz" occupied grid squares
local layouts = {} -- player -> array of {n, x, z, r, id, model}
local lastAction = {} -- player -> os.clock() (anti-spam)
local nextId = 0

local function cellKey(gx, gz)
	return gx .. ":" .. gz
end

local function eachCell(gx, gz, w, d, fn)
	for x = gx, gx + w - 1 do
		for z = gz, gz + d - 1 do
			fn(cellKey(x, z))
		end
	end
end

local function regionFree(zone, gx, gz, w, d)
	local taken = occupancy[zone]
	local free = true
	eachCell(gx, gz, w, d, function(key)
		if taken[key] then
			free = false
		end
	end)
	return free
end

local function setRegion(zone, gx, gz, w, d, value)
	local taken = occupancy[zone]
	eachCell(gx, gz, w, d, function(key)
		taken[key] = value
	end)
end

-- The one true "make it exist" function — used by live purchases and by
-- save-file rebuilds, so they can never behave differently.
local function placeInternal(player, zone, asset, gx, gz, rot)
	local w, d = GridMath.footprint(asset, rot)
	if not GridMath.inBounds(zone.info, gx, gz, w, d) then
		return nil, "That spot is outside your plot."
	end
	if not regionFree(zone, gx, gz, w, d) then
		return nil, "Something is already there."
	end

	nextId += 1
	local id = nextId

	local pivot = GridMath.placementPivot(zone.info, asset, gx, gz, rot)
	local model = asset.model:Clone()
	model:PivotTo(pivot)
	-- Attributes double as the client's info source (for previews and
	-- delete-mode) and as debugging breadcrumbs in the Explorer.
	-- (Housing assets keep their SpawnsInmate attribute — IntakeService
	-- counts them as capacity; prisoners arrive via intake, not on
	-- placement.)
	model:SetAttribute("LayoutId", id)
	model:SetAttribute("Asset", asset.name)
	model:SetAttribute("GX", gx)
	model:SetAttribute("GZ", gz)
	model:SetAttribute("Rot", rot)
	model.Parent = zone.placed

	setRegion(zone, gx, gz, w, d, true)
	table.insert(layouts[player], { n = asset.name, x = gx, z = gz, r = rot, id = id, model = model })
	return model
end

-- Wiring (called by PlotService) -----------------------------------------

function PlacementService.assignZone(player, zone, savedLayout)
	playerZones[player] = zone
	occupancy[zone] = {}
	layouts[player] = {}

	-- Rebuild everything from the save. Entries that no longer make
	-- sense (asset renamed/deleted, corrupt data) are skipped quietly —
	-- better to lose one wall than crash the whole load.
	if type(savedLayout) == "table" then
		for _, entry in ipairs(savedLayout) do
			if type(entry) == "table"
				and type(entry.n) == "string"
				and type(entry.x) == "number"
				and type(entry.z) == "number"
				and type(entry.r) == "number"
			then
				local asset = Buildables.get(entry.n)
				if asset then
					placeInternal(player, zone, asset, math.floor(entry.x), math.floor(entry.z), math.floor(entry.r) % 4)
				end
			end
		end
	end
end

function PlacementService.releasePlayer(player)
	local zone = playerZones[player]
	playerZones[player] = nil
	layouts[player] = nil
	lastAction[player] = nil
	if zone then
		occupancy[zone] = nil
		zone.placed:ClearAllChildren()
	end
end

-- What SaveService writes to the cloud: just the plain numbers, no
-- Instances or server-only ids.
function PlacementService.snapshotLayout(player)
	local out = {}
	for _, entry in ipairs(layouts[player] or {}) do
		table.insert(out, { n = entry.n, x = entry.x, z = entry.z, r = entry.r })
	end
	return out
end

-- Player requests (via RemoteFunctions) -----------------------------------

local function tooFast(player)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.1 then
		return true
	end
	lastAction[player] = now
	return false
end

function PlacementService.handlePlace(player, assetName, gx, gz, rot)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if type(assetName) ~= "string" or type(gx) ~= "number" or type(gz) ~= "number" or type(rot) ~= "number" then
		return { ok = false, err = "Bad request." }
	end
	local asset = Buildables.get(assetName)
	if not asset then
		return { ok = false, err = "Unknown asset." }
	end

	local model, err = placeInternal(player, zone, asset, math.floor(gx), math.floor(gz), math.floor(rot) % 4)
	if not model then
		return { ok = false, err = err }
	end
	return { ok = true }
end

-- Drag-to-build: place a straight line of a 1x1 asset in one request
-- (walls, fences, floors). Occupied squares along the line are skipped
-- rather than failing the whole drag.
function PlacementService.handlePlaceLine(player, assetName, x1, z1, x2, z2)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if type(assetName) ~= "string" or type(x1) ~= "number" or type(z1) ~= "number"
		or type(x2) ~= "number" or type(z2) ~= "number"
	then
		return { ok = false, err = "Bad request." }
	end
	local asset = Buildables.get(assetName)
	if not asset then
		return { ok = false, err = "Unknown asset." }
	end
	if asset.cellsW ~= 1 or asset.cellsD ~= 1 then
		return { ok = false, err = "Only 1-square assets can be dragged in lines." }
	end

	local startX, startZ, axis, count = GridMath.lineCells(
		math.floor(x1), math.floor(z1), math.floor(x2), math.floor(z2)
	)
	count = math.min(count, 64)
	-- Pieces auto-face along the drag: lengthwise walls form a solid run.
	local rot = axis == "x" and 0 or 1

	local placed = 0
	for i = 0, count - 1 do
		local gx = axis == "x" and startX + i or startX
		local gz = axis == "z" and startZ + i or startZ
		local model = placeInternal(player, zone, asset, gx, gz, rot)
		if model then
			placed += 1
		end
	end
	if placed == 0 then
		return { ok = false, err = "Nothing free along that line." }
	end
	return { ok = true, placed = placed }
end

function PlacementService.handleDelete(player, model)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	-- The model must be a real placed object inside THIS player's zone.
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Parent ~= zone.placed then
		return { ok = false, err = "That's not yours to demolish." }
	end
	local id = model:GetAttribute("LayoutId")

	local layout = layouts[player]
	for index, entry in ipairs(layout) do
		if entry.id == id then
			local asset = Buildables.get(entry.n)
			if asset then
				local w, d = GridMath.footprint(asset, entry.r)
				setRegion(zone, entry.x, entry.z, w, d, nil)
			end
			table.remove(layout, index)
			model:Destroy()
			return { ok = true }
		end
	end
	return { ok = false, err = "Couldn't find that object." }
end

function PlacementService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.PlaceRequest.OnServerInvoke = PlacementService.handlePlace
	remotes.PlaceLineRequest.OnServerInvoke = PlacementService.handlePlaceLine
	remotes.DeleteRequest.OnServerInvoke = PlacementService.handleDelete
end

return PlacementService
