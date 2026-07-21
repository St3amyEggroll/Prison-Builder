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
local Config = require(ReplicatedStorage.Shared.Config)
local Buildables = require(script.Parent.Buildables)
local DoorService = require(script.Parent.DoorService)
local EconomyService = require(script.Parent.EconomyService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local ConstructionService = require(script.Parent.ConstructionService)

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

-- Which asset (by name) occupies a grid square — RoomService uses this
-- for enclosure checks. nil = empty.
function PlacementService.cellAsset(zone, gx, gz)
	local taken = occupancy[zone]
	return taken and taken[gx .. ":" .. gz] or nil
end

local movedListeners = {} -- fns(player) — bootstrap wires room/intake pokes
function PlacementService.onMoved(fn)
	table.insert(movedListeners, fn)
end

-- The one true "make it exist" function — used by live purchases and by
-- save-file rebuilds, so they can never behave differently. instant=true
-- (save rebuilds, Config.InstantBuild) skips the blueprint/workman step.
local function placeInternal(player, zone, asset, gx, gz, rot, instant)
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

	if instant then
		if asset.door then
			DoorService.register(model, player)
		end
	else
		ConstructionService.queueBlueprint(player, zone, model, asset)
	end

	setRegion(zone, gx, gz, w, d, asset.name)
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
					placeInternal(player, zone, asset, math.floor(entry.x), math.floor(entry.z), math.floor(entry.r) % 4, true)
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

-- Charge, then place; refund if placement failed. Returns the model plus
-- an error kind ("cash" means stop trying, anything else means that one
-- square failed).
local function paidPlace(player, zone, asset, gx, gz, rot)
	if not EconomyService.tryCharge(player, asset.price) then
		return nil, "cash"
	end
	local model, err = placeInternal(player, zone, asset, gx, gz, rot, Config.InstantBuild)
	if not model then
		EconomyService.credit(player, asset.price)
		return nil, err
	end
	if asset.category == "Walls & Doors" then
		ObjectiveService.notify(player, "wall_built")
	end
	return model
end

local NEED_CASH = "Not enough cash!"

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

	local model, err = paidPlace(player, zone, asset, math.floor(gx), math.floor(gz), math.floor(rot) % 4)
	if not model then
		return { ok = false, err = err == "cash" and NEED_CASH or err }
	end
	return { ok = true, model = model, spent = Config.FreeBuild and 0 or asset.price }
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

	local startX, startZ, axis, rawCount = GridMath.lineCells(
		math.floor(x1), math.floor(z1), math.floor(x2), math.floor(z2)
	)
	-- Pieces auto-face along the drag (long side follows it), and pieces
	-- bigger than one square step by their own length so runs stay solid.
	local rot
	if axis == "x" then
		rot = asset.cellsW >= asset.cellsD and 0 or 1
	else
		rot = asset.cellsW >= asset.cellsD and 1 or 0
	end
	local w, d = GridMath.footprint(asset, rot)
	local step = math.max(1, axis == "x" and w or d)
	local pieces = math.min(math.floor((rawCount - 1) / step) + 1, 64)

	local models = {}
	local broke = false
	for i = 0, pieces - 1 do
		local gx = axis == "x" and startX + i * step or startX
		local gz = axis == "z" and startZ + i * step or startZ
		local model, err = paidPlace(player, zone, asset, gx, gz, rot)
		if model then
			table.insert(models, model)
		elseif err == "cash" then
			broke = true
			break
		end
	end
	if #models == 0 then
		return { ok = false, err = broke and NEED_CASH or "Nothing free along that line." }
	end
	return { ok = true, placed = #models, models = models, broke = broke }
end

-- Rectangle FILL (Prison Architect flooring): tile the whole dragged
-- rectangle with the asset, stepping by its footprint.
function PlacementService.handlePlaceRect(player, assetName, x1, z1, x2, z2, rot)
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
	rot = math.floor(tonumber(rot) or 0) % 4
	local w, d = GridMath.footprint(asset, rot)

	local minX = math.max(0, math.floor(math.min(x1, x2)))
	local maxX = math.min(zone.info.cols - 1, math.floor(math.max(x1, x2)))
	local minZ = math.max(0, math.floor(math.min(z1, z2)))
	local maxZ = math.min(zone.info.rows - 1, math.floor(math.max(z1, z2)))

	local models = {}
	local broke = false
	for gz = minZ, maxZ, d do
		for gx = minX, maxX, w do
			if #models >= 512 or broke then
				break
			end
			local model, err = paidPlace(player, zone, asset, gx, gz, rot)
			if model then
				table.insert(models, model)
			elseif err == "cash" then
				broke = true
			end
		end
	end
	if #models == 0 then
		return { ok = false, err = broke and NEED_CASH or "No room in that rectangle." }
	end
	return { ok = true, placed = #models, models = models, broke = broke }
end

-- The 🏗️ Foundations tool: drag a rectangle, get perimeter walls and an
-- interior floor in one go (add a door yourself, like PA). Occupied
-- squares are skipped rather than failing the whole build.
function PlacementService.handleFoundation(player, x1, z1, x2, z2)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if type(x1) ~= "number" or type(z1) ~= "number" or type(x2) ~= "number" or type(z2) ~= "number" then
		return { ok = false, err = "Bad request." }
	end
	local wallAsset = Buildables.get(Config.FoundationWallAsset)
	local floorAsset = Buildables.get(Config.FoundationFloorAsset)
	if not wallAsset or not floorAsset then
		return { ok = false, err = ("Foundations need assets named '%s' and '%s' in Buildables."):format(
			Config.FoundationWallAsset, Config.FoundationFloorAsset) }
	end

	local minX = math.max(0, math.floor(math.min(x1, x2)))
	local maxX = math.min(zone.info.cols - 1, math.floor(math.max(x1, x2)))
	local minZ = math.max(0, math.floor(math.min(z1, z2)))
	local maxZ = math.min(zone.info.rows - 1, math.floor(math.max(z1, z2)))
	local width, depth = maxX - minX + 1, maxZ - minZ + 1
	if width < Config.FoundationMinSize or depth < Config.FoundationMinSize then
		return { ok = false, err = ("Foundations need at least %d×%d squares."):format(
			Config.FoundationMinSize, Config.FoundationMinSize) }
	end
	if width * depth > Config.FoundationMaxArea then
		return { ok = false, err = ("Too big — foundations max out at %d squares per drag."):format(
			Config.FoundationMaxArea) }
	end

	local models = {}
	local broke = false
	for z = minZ, maxZ do
		for x = minX, maxX do
			if broke then
				break
			end
			local isBorder = x == minX or x == maxX or z == minZ or z == maxZ
			local model, err = paidPlace(player, zone, isBorder and wallAsset or floorAsset, x, z, 0)
			if model then
				table.insert(models, model)
			elseif err == "cash" then
				broke = true
			end
		end
	end
	if #models == 0 then
		return { ok = false, err = broke and NEED_CASH or "No room for a foundation there." }
	end
	return { ok = true, built = #models, models = models, broke = broke }
end

-- refundRate: bulldozing pays back Config.RefundRate; Undo passes 1.0.
-- Blueprints always refund in full (nothing was built yet).
local function deleteOne(player, zone, model, refundRate)
	-- The model must be a real placed object inside THIS player's zone.
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Parent ~= zone.placed then
		return false, "That's not yours to demolish.", 0
	end
	local id = model:GetAttribute("LayoutId")
	local isBlueprint = model:GetAttribute("Blueprint") == true

	local layout = layouts[player]
	for index, entry in ipairs(layout) do
		if entry.id == id then
			local asset = Buildables.get(entry.n)
			local refund = 0
			if asset then
				local w, d = GridMath.footprint(asset, entry.r)
				setRegion(zone, entry.x, entry.z, w, d, nil)
				if not Config.FreeBuild then
					refund = math.floor(asset.price * (isBlueprint and 1 or refundRate))
					EconomyService.credit(player, refund)
				end
			end
			table.remove(layout, index)
			model:Destroy()
			return true, nil, refund
		end
	end
	return false, "Couldn't find that object.", 0
end

function PlacementService.handleDelete(player, model)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	local ok, err, refund = deleteOne(player, zone, model, Config.RefundRate)
	if not ok then
		return { ok = false, err = err }
	end
	return { ok = true, refund = refund }
end

-- Batch demolish, used by Undo to revert a whole line or foundation in
-- one request.
function PlacementService.handleDeleteMany(player, models)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if type(models) ~= "table" or #models > 512 then
		return { ok = false, err = "Bad request." }
	end
	local deleted, refundTotal = 0, 0
	for _, model in ipairs(models) do
		local ok, _, refund = deleteOne(player, zone, model, 1)
		if ok then
			deleted += 1
			refundTotal += refund
		end
	end
	if deleted == 0 then
		return { ok = false, err = "Nothing to demolish." }
	end
	return { ok = true, deleted = deleted, refund = refundTotal }
end

-- Rectangle BULLDOZE: demolish everything whose footprint touches the
-- dragged rectangle. Returns the identities so Undo can rebuild them.
function PlacementService.handleDeleteRect(player, x1, z1, x2, z2)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if type(x1) ~= "number" or type(z1) ~= "number" or type(x2) ~= "number" or type(z2) ~= "number" then
		return { ok = false, err = "Bad request." }
	end
	local minX, maxX = math.floor(math.min(x1, x2)), math.floor(math.max(x1, x2))
	local minZ, maxZ = math.floor(math.min(z1, z2)), math.floor(math.max(z1, z2))

	-- Collect first (deleteOne edits the layout list while we scan it).
	local victims = {}
	for _, entry in ipairs(layouts[player]) do
		local asset = Buildables.get(entry.n)
		if asset and #victims < 512 then
			local w, d = GridMath.footprint(asset, entry.r)
			if entry.x <= maxX and entry.x + w - 1 >= minX
				and entry.z <= maxZ and entry.z + d - 1 >= minZ
			then
				table.insert(victims, entry)
			end
		end
	end

	local items = {}
	local refundTotal = 0
	for _, entry in ipairs(victims) do
		local params = { n = entry.n, x = entry.x, z = entry.z, r = entry.r }
		local ok, _, refund = deleteOne(player, zone, entry.model, Config.RefundRate)
		if ok then
			table.insert(items, params)
			refundTotal += refund
		end
	end
	if #items == 0 then
		return { ok = false, err = "Nothing there to bulldoze." }
	end
	return { ok = true, deleted = #items, items = items, refund = refundTotal }
end

-- The Move tool, done properly: free, instant, no blueprint — picking
-- up your own furniture shouldn't cost half its price.
function PlacementService.handleMove(player, model, gx, gz, rot)
	local zone = playerZones[player]
	if not zone then
		return { ok = false, err = "You don't have a plot yet." }
	end
	if tooFast(player) then
		return { ok = false, err = "Too fast!" }
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Parent ~= zone.placed
		or type(gx) ~= "number" or type(gz) ~= "number" or type(rot) ~= "number"
	then
		return { ok = false, err = "Bad request." }
	end
	if model:GetAttribute("Blueprint") == true then
		return { ok = false, err = "That's still under construction!" }
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") then
			return { ok = false, err = "Someone lives there — can't move an occupied cell!" }
		end
	end

	local id = model:GetAttribute("LayoutId")
	local layout = layouts[player]
	for _, entry in ipairs(layout) do
		if entry.id == id then
			local asset = Buildables.get(entry.n)
			if not asset then
				return { ok = false, err = "Can't move that one." }
			end
			gx, gz, rot = math.floor(gx), math.floor(gz), math.floor(rot) % 4
			local oldW, oldD = GridMath.footprint(asset, entry.r)
			local newW, newD = GridMath.footprint(asset, rot)

			-- Free the old squares first so moving within your own
			-- footprint works, then validate the new spot.
			setRegion(zone, entry.x, entry.z, oldW, oldD, nil)
			if not GridMath.inBounds(zone.info, gx, gz, newW, newD)
				or not regionFree(zone, gx, gz, newW, newD)
			then
				setRegion(zone, entry.x, entry.z, oldW, oldD, asset.name)
				return { ok = false, err = "Can't move it there." }
			end

			model:PivotTo(GridMath.placementPivot(zone.info, asset, gx, gz, rot))
			model:SetAttribute("GX", gx)
			model:SetAttribute("GZ", gz)
			model:SetAttribute("Rot", rot)
			setRegion(zone, gx, gz, newW, newD, asset.name)
			entry.x, entry.z, entry.r = gx, gz, rot
			if asset.door then
				DoorService.updatePosition(model)
			end
			for _, fn in ipairs(movedListeners) do
				task.spawn(fn, player)
			end
			return { ok = true }
		end
	end
	return { ok = false, err = "Couldn't find that object." }
end

function PlacementService.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.PlaceRequest.OnServerInvoke = PlacementService.handlePlace
	remotes.PlaceLineRequest.OnServerInvoke = PlacementService.handlePlaceLine
	remotes.FoundationRequest.OnServerInvoke = PlacementService.handleFoundation
	remotes.PlaceRectRequest.OnServerInvoke = PlacementService.handlePlaceRect
	remotes.DeleteRequest.OnServerInvoke = PlacementService.handleDelete
	remotes.DeleteManyRequest.OnServerInvoke = PlacementService.handleDeleteMany
	remotes.DeleteRectRequest.OnServerInvoke = PlacementService.handleDeleteRect
	remotes.MoveRequest.OnServerInvoke = PlacementService.handleMove
end

return PlacementService
