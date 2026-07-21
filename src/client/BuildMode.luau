-- BuildMode: the whole building experience on the player's screen,
-- arranged like Prison Architect's bottom toolbar:
--
--   [🏗️ Foundations] [🧱 Walls & Doors] [🟫 Flooring] [🎨 Rooms] [🪑 Objects]
--   [✋ Move] [🗑️ Bulldoze] [↩ Undo] [👮] [💡]
--
-- Category buttons open an item panel above the bar (3D thumbnails for
-- assets, color chips for rooms). Grayed-out buttons are future phases,
-- just like PA's locked tabs. Assets pick their button with a "Category"
-- attribute — a name the toolbar has never seen becomes a new button
-- automatically.
--
--   🔨 Build (or B)  ->  build mode: top-down camera + the toolbar
--   Foundations       ->  drag a rectangle: walls around it, floor inside
--   Objects           ->  ghost preview snaps to the grid; click places;
--                         1-square assets PRESS-DRAG into whole lines
--   Rooms             ->  pick the type FIRST, then drag a rectangle
--   ✋ Move           ->  pick an object up and re-place it
--   ↩ / Ctrl+Z       ->  undo placements and demolishes
--   ↻ / R             ->  rotate 90°   ·   🗑️ Bulldoze -> click to demolish
--
-- The server re-validates everything — this file is just the friendly face.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GridMath = require(ReplicatedStorage.Shared:WaitForChild("GridMath"))
local AssetCatalog = require(ReplicatedStorage.Shared:WaitForChild("AssetCatalog"))
local BuildCamera = require(script.Parent.BuildCamera)

local BuildMode = {}

local GRID = Config.GridSize
local GREEN = Color3.fromRGB(80, 255, 120)
local RED = Color3.fromRGB(255, 80, 80)
local PANEL_BG = Color3.fromRGB(20, 24, 20)
local BUTTON_BG = Color3.fromRGB(45, 52, 45)
local SELECTED_BG = Color3.fromRGB(60, 110, 60)

function BuildMode.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local placeRequest = remotes:WaitForChild("PlaceRequest")
	local placeLineRequest = remotes:WaitForChild("PlaceLineRequest")
	local deleteRequest = remotes:WaitForChild("DeleteRequest")
	local deleteManyRequest = remotes:WaitForChild("DeleteManyRequest")
	local foundationRequest = remotes:WaitForChild("FoundationRequest")
	local roomPaintRequest = remotes:WaitForChild("RoomPaintRequest")

	local buildablesFolder = ReplicatedStorage:WaitForChild(Config.BuildablesFolderName)
	local catalogByName, catalogOrdered = AssetCatalog.load(buildablesFolder)

	-- Which categories exist? Start from the standard order, then append
	-- any new names the map-maker invented on their own assets.
	local categories = {}
	local categorySeen = {}
	for _, name in ipairs(Config.AssetCategories) do
		categorySeen[name] = false
	end
	for _, asset in ipairs(catalogOrdered) do
		categorySeen[asset.category] = true
	end
	for _, name in ipairs(Config.AssetCategories) do
		if categorySeen[name] then
			table.insert(categories, name)
		end
	end
	local extras = {}
	for name, present in pairs(categorySeen) do
		if present and not table.find(Config.AssetCategories, name) then
			table.insert(extras, name)
		end
	end
	table.sort(extras)
	for _, name in ipairs(extras) do
		table.insert(categories, name)
	end

	-- My zone (the server drops a "BuildZone" pointer into the Player).
	local zone = nil
	local occupied = {}

	-- State.
	local mode = "off" -- "off" | "objects" | "rooms" | "foundation" | "move" | "delete"
	local currentCategory = categories[1] or "Objects"
	local selected = nil
	local selectedRoom = nil
	local rot = 0
	local ghost, ghostHighlight = nil, nil
	local ghostCell, ghostValid = nil, false
	local lastPointer = Vector2.new(0, 0)
	local pressing = false
	local pressStartCell = nil
	local stretchBox = nil
	local hoverHighlight = nil
	local zoneBox = nil

	-- Undo: a stack of inverse actions (Ctrl+Z or the ↩ button).
	--   { kind = "place", models = {Model, ...} }        -> demolish them
	--   { kind = "delete", items = { {n, x, z, r}, ... } } -> re-place them
	local undoStack = {}
	local function pushUndo(entry)
		table.insert(undoStack, entry)
		if #undoStack > 20 then
			table.remove(undoStack, 1)
		end
	end

	-- Occupancy mirror ---------------------------------------------------

	local function markModel(model, value)
		local asset = catalogByName[model:GetAttribute("Asset") or ""]
		local gx = model:GetAttribute("GX")
		local gz = model:GetAttribute("GZ")
		local r = model:GetAttribute("Rot")
		if not asset or type(gx) ~= "number" or type(gz) ~= "number" or type(r) ~= "number" then
			return
		end
		local w, d = GridMath.footprint(asset, r)
		for x = gx, gx + w - 1 do
			for z = gz, gz + d - 1 do
				occupied[x .. ":" .. z] = value
			end
		end
	end

	local function regionFree(gx, gz, w, d)
		for x = gx, gx + w - 1 do
			for z = gz, gz + d - 1 do
				if occupied[x .. ":" .. z] then
					return false
				end
			end
		end
		return true
	end

	local function watchZone(zonePart)
		zone = {
			part = zonePart,
			info = GridMath.zoneInfo(zonePart),
			placed = zonePart:WaitForChild("Placed"),
		}
		occupied = {}
		for _, model in ipairs(zone.placed:GetChildren()) do
			markModel(model, true)
		end
		zone.placed.ChildAdded:Connect(function(model)
			markModel(model, true)
		end)
		zone.placed.ChildRemoved:Connect(function(model)
			markModel(model, nil)
		end)
	end

	task.spawn(function()
		local zoneMarker = player:WaitForChild("BuildZone", 60)
		if zoneMarker then
			if zoneMarker.Value then
				watchZone(zoneMarker.Value)
			else
				zoneMarker.Changed:Connect(function(value)
					if value and not zone then
						watchZone(value)
					end
				end)
			end
		end
	end)

	-- Pointer & preview helpers -------------------------------------------

	local function pointerRay()
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		return camera:ViewportPointToRay(lastPointer.X, lastPointer.Y)
	end

	local function cellUnderPointer(w, d)
		if not zone then
			return nil
		end
		local ray = pointerRay()
		if not ray then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { zone.part }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if not hit then
			return nil
		end
		return GridMath.worldToCell(zone.info, hit.Position, w, d)
	end

	local function destroyGhost()
		if ghost then
			ghost:Destroy()
			ghost, ghostHighlight = nil, nil
		end
		ghostCell = nil
	end

	local function makeGhost(asset)
		destroyGhost()
		local model = asset.model:Clone()
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
				descendant.Transparency = math.clamp(descendant.Transparency + 0.5, 0.5, 1)
			elseif descendant:IsA("BillboardGui") then
				descendant.Enabled = false
			end
		end
		local highlight = Instance.new("Highlight")
		highlight.FillColor = GREEN
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = GREEN
		highlight.Adornee = model
		highlight.Parent = model
		ghost = model
		ghostHighlight = highlight
	end

	local function hideStretchBox()
		if stretchBox then
			stretchBox:Destroy()
			stretchBox = nil
		end
	end

	local function showStretchBox(x1, z1, x2, z2, color)
		if not stretchBox then
			stretchBox = Instance.new("Part")
			stretchBox.Anchored = true
			stretchBox.CanCollide = false
			stretchBox.CanQuery = false
			stretchBox.CanTouch = false
			stretchBox.Material = Enum.Material.Neon
			stretchBox.Transparency = 0.55
			stretchBox.Parent = workspace
		end
		local minX, maxX = math.min(x1, x2), math.max(x1, x2)
		local minZ, maxZ = math.min(z1, z2), math.max(z1, z2)
		local w, d = maxX - minX + 1, maxZ - minZ + 1
		stretchBox.Color = color
		stretchBox.Size = Vector3.new(w * GRID, 0.4, d * GRID)
		stretchBox.CFrame = GridMath.regionCenter(zone.info, minX, minZ, w, d) * CFrame.new(0, 0.25, 0)
	end

	local function updateGhost()
		if not (zone and selected and ghost) then
			return
		end
		local w, d = GridMath.footprint(selected, rot)
		local gx, gz = cellUnderPointer(w, d)
		if gx == nil then
			ghost.Parent = nil
			ghostCell = nil
			return
		end
		ghost:PivotTo(GridMath.placementPivot(zone.info, selected, gx, gz, rot))
		ghost.Parent = workspace
		ghostCell = { gx, gz }
		ghostValid = regionFree(gx, gz, w, d)
		local color = ghostValid and GREEN or RED
		ghostHighlight.FillColor = color
		ghostHighlight.OutlineColor = color
	end

	-- UI: build toggle, PA-style bottom toolbar, item panel ----------------

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownBuild"
	gui.ResetOnSpawn = false

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -14, 1, -14)
	toggle.Size = UDim2.new(0, 120, 0, 48)
	toggle.BackgroundColor3 = PANEL_BG
	toggle.BackgroundTransparency = 0.2
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 20
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Text = "🔨 Build"
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggle.Parent = gui

	-- The bottom bar (visible whenever build mode is open).
	local toolbar = Instance.new("Frame")
	toolbar.AnchorPoint = Vector2.new(0.5, 1)
	toolbar.Position = UDim2.new(0.5, 0, 1, -10)
	toolbar.AutomaticSize = Enum.AutomaticSize.X
	toolbar.Size = UDim2.new(0, 0, 0, 66)
	toolbar.BackgroundColor3 = PANEL_BG
	toolbar.BackgroundTransparency = 0.15
	toolbar.Visible = false
	local toolbarCorner = Instance.new("UICorner")
	toolbarCorner.CornerRadius = UDim.new(0, 12)
	toolbarCorner.Parent = toolbar
	local toolbarPad = Instance.new("UIPadding")
	toolbarPad.PaddingLeft = UDim.new(0, 6)
	toolbarPad.PaddingRight = UDim.new(0, 6)
	toolbarPad.PaddingTop = UDim.new(0, 6)
	toolbarPad.PaddingBottom = UDim.new(0, 6)
	toolbarPad.Parent = toolbar
	local toolbarLayout = Instance.new("UIListLayout")
	toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
	toolbarLayout.Padding = UDim.new(0, 6)
	toolbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toolbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toolbarLayout.Parent = toolbar
	toolbar.Parent = gui

	-- A PA-style toolbar button: big icon on top, small label under it.
	local toolbarOrder = 0
	local function toolbarButton(icon, name, enabled)
		toolbarOrder += 1
		local button = Instance.new("TextButton")
		button.LayoutOrder = toolbarOrder
		button.Size = UDim2.new(0, 74, 0, 54)
		button.BackgroundColor3 = BUTTON_BG
		button.BackgroundTransparency = enabled and 0 or 0.5
		button.Text = ""
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0, 30)
		iconLabel.Position = UDim2.new(0, 0, 0, 2)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 22
		iconLabel.TextTransparency = enabled and 0 or 0.5
		iconLabel.Text = icon
		iconLabel.Parent = button

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0, 1)
		nameLabel.Position = UDim2.new(0, 2, 1, -3)
		nameLabel.Size = UDim2.new(1, -4, 0, 16)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextTransparency = enabled and 0 or 0.55
		nameLabel.Text = name
		nameLabel.Parent = button

		button.Parent = toolbar
		return button
	end

	-- The item panel that opens above the toolbar.
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -82)
	panel.Size = UDim2.new(0.94, 0, 0, 150)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel
	panel.Parent = gui

	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -238)
	status.Size = UDim2.new(0.9, 0, 0, 24)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(255, 255, 255)
	status.TextStrokeTransparency = 0.4
	status.Text = ""
	status.Parent = gui

	local rotateButton = Instance.new("TextButton")
	rotateButton.Size = UDim2.new(0, 44, 0, 44)
	rotateButton.Position = UDim2.new(0, 8, 0.5, -22)
	rotateButton.BackgroundColor3 = BUTTON_BG
	rotateButton.Font = Enum.Font.GothamBold
	rotateButton.TextSize = 22
	rotateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rotateButton.Text = "↻"
	local rotateCorner = Instance.new("UICorner")
	rotateCorner.CornerRadius = UDim.new(0, 10)
	rotateCorner.Parent = rotateButton
	rotateButton.Parent = panel

	local function makeList()
		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.new(0, 60, 0, 8)
		list.Size = UDim2.new(1, -68, 1, -16)
		list.BackgroundTransparency = 1
		list.ScrollBarThickness = 6
		list.ScrollingDirection = Enum.ScrollingDirection.X
		list.AutomaticCanvasSize = Enum.AutomaticSize.X
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		list.Parent = panel
		return list
	end

	local objectsList = makeList()
	local roomsList = makeList()
	roomsList.Visible = false

	local statusId = 0
	local function flashStatus(text, color)
		statusId += 1
		local id = statusId
		status.Text = text
		status.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		task.delay(2.5, function()
			if statusId == id then
				status.Text = ""
			end
		end)
	end

	-- Item tiles ----------------------------------------------------------

	local assetButtons = {} -- asset name -> { button, category }
	local roomButtons = {}
	local categoryButtons = {} -- category name -> toolbar button
	local roomsButton, deleteButton, foundationButton, moveButton

	local function refreshSelectionLook()
		for name, entry in pairs(assetButtons) do
			entry.button.BackgroundColor3 = (selected and selected.name == name) and SELECTED_BG or BUTTON_BG
		end
		for id, button in pairs(roomButtons) do
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = (selectedRoom == id) and 0 or 1
			end
		end
		for name, button in pairs(categoryButtons) do
			button.BackgroundColor3 = (mode == "objects" and currentCategory == name) and SELECTED_BG or BUTTON_BG
		end
		roomsButton.BackgroundColor3 = (mode == "rooms") and SELECTED_BG or BUTTON_BG
		foundationButton.BackgroundColor3 = (mode == "foundation") and SELECTED_BG or BUTTON_BG
		moveButton.BackgroundColor3 = (mode == "move") and Color3.fromRGB(120, 110, 40) or BUTTON_BG
		deleteButton.BackgroundColor3 = (mode == "delete") and Color3.fromRGB(140, 50, 50) or BUTTON_BG
	end

	local function refreshTileVisibility()
		for _, entry in pairs(assetButtons) do
			entry.button.Visible = entry.category == currentCategory
		end
	end

	local selectAsset, selectRoom, tryMove, doUndo

	for order, asset in ipairs(catalogOrdered) do
		local tile = Instance.new("TextButton")
		tile.LayoutOrder = order
		tile.Size = UDim2.new(0, 104, 1, 0)
		tile.BackgroundColor3 = BUTTON_BG
		tile.Text = ""
		local tileCorner = Instance.new("UICorner")
		tileCorner.CornerRadius = UDim.new(0, 10)
		tileCorner.Parent = tile

		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.new(1, -8, 1, -30)
		viewport.Position = UDim2.new(0, 4, 0, 4)
		viewport.BackgroundTransparency = 1
		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local preview = asset.model:Clone()
		preview.Parent = viewport
		local boxCF, boxSize = preview:GetBoundingBox()
		local distance = boxSize.Magnitude * 1.1 + 2
		camera.CFrame = CFrame.lookAt(
			boxCF.Position + Vector3.new(distance * 0.6, distance * 0.55, distance * 0.6),
			boxCF.Position
		)
		viewport.Parent = tile

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 4, 1, -4)
		label.Size = UDim2.new(1, -8, 0, 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = asset.name
		label.Parent = tile

		tile.Activated:Connect(function()
			selectAsset(asset)
		end)
		tile.Parent = objectsList
		assetButtons[asset.name] = { button = tile, category = asset.category }
	end

	local function roomTile(id, name, color, order)
		local tile = Instance.new("TextButton")
		tile.LayoutOrder = order
		tile.Size = UDim2.new(0, 104, 1, 0)
		tile.BackgroundColor3 = color
		tile.Text = ""
		local tileCorner = Instance.new("UICorner")
		tileCorner.CornerRadius = UDim.new(0, 10)
		tileCorner.Parent = tile
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 1
		stroke.Parent = tile

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 4, 1, -4)
		label.Size = UDim2.new(1, -8, 0, 22)
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 0.35
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = name
		local labelCorner = Instance.new("UICorner")
		labelCorner.CornerRadius = UDim.new(0, 6)
		labelCorner.Parent = label
		label.Parent = tile

		tile.Activated:Connect(function()
			selectRoom(id)
		end)
		tile.Parent = roomsList
		roomButtons[id] = tile
	end
	for id, roomType in ipairs(Config.RoomTypes) do
		roomTile(id, roomType.name, roomType.color, id)
	end
	roomTile(0, "✖ Eraser", Color3.fromRGB(80, 80, 85), #Config.RoomTypes + 1)

	-- Mode switching -----------------------------------------------------

	local function clearHover()
		if hoverHighlight then
			hoverHighlight.Adornee = nil
		end
	end

	local function setMode(newMode)
		local wasOff = mode == "off"
		mode = newMode
		pressing = false
		destroyGhost()
		hideStretchBox()
		clearHover()
		if mode ~= "objects" then
			selected = nil
		end
		if mode ~= "rooms" then
			selectedRoom = nil
		end
		toolbar.Visible = mode ~= "off"
		panel.Visible = mode == "objects" or mode == "rooms"
		objectsList.Visible = mode == "objects"
		roomsList.Visible = mode == "rooms"
		rotateButton.Visible = mode == "objects"
		toggle.Text = mode == "off" and "🔨 Build" or "✖ Close"
		refreshSelectionLook()
		refreshTileVisibility()

		if zoneBox then
			zoneBox:Destroy()
			zoneBox = nil
		end
		if mode ~= "off" and zone then
			zoneBox = Instance.new("SelectionBox")
			zoneBox.Adornee = zone.part
			zoneBox.Color3 = GREEN
			zoneBox.LineThickness = 0.06
			zoneBox.SurfaceTransparency = 1
			zoneBox.Parent = zone.part
		end

		-- The Prison Architect camera comes with build mode.
		if mode ~= "off" and wasOff and zone then
			BuildCamera.enter(zone.part)
		elseif mode == "off" and not wasOff then
			BuildCamera.exit()
		end
	end

	local function selectCategory(name)
		currentCategory = name
		setMode("objects")
	end

	selectAsset = function(asset)
		if not zone then
			flashStatus("No build plot assigned yet!", RED)
			return
		end
		selected = asset
		selectedRoom = nil
		clearHover()
		hideStretchBox()
		makeGhost(asset)
		refreshSelectionLook()
		if asset.cellsW == 1 and asset.cellsD == 1 then
			flashStatus("Placing " .. asset.name .. " — drag for a whole line! (R rotates)", GREEN)
		else
			flashStatus("Placing " .. asset.name .. " (R or ↻ rotates)", GREEN)
		end
	end

	selectRoom = function(id)
		if not zone then
			flashStatus("No build plot assigned yet!", RED)
			return
		end
		selectedRoom = id
		selected = nil
		destroyGhost()
		clearHover()
		refreshSelectionLook()
		if id == 0 then
			flashStatus("Eraser — drag a rectangle to clear room paint", Color3.fromRGB(220, 220, 220))
		else
			flashStatus("Drag a rectangle to paint: " .. Config.RoomTypes[id].name, Config.RoomTypes[id].color)
		end
	end

	-- Build the toolbar buttons (PA order: foundations, build stuff,
	-- rooms, objects, move/bulldoze/undo, then the locked future tabs).
	foundationButton = toolbarButton("🏗️", "Foundations", true)
	foundationButton.Activated:Connect(function()
		setMode("foundation")
		flashStatus("Drag a rectangle — walls around the edge, floor inside. Add a door after!", GREEN)
	end)
	for _, name in ipairs(categories) do
		if name ~= "Objects" then
			local button = toolbarButton(Config.CategoryIcons[name] or "📦", name, true)
			button.Activated:Connect(function()
				selectCategory(name)
			end)
			categoryButtons[name] = button
		end
	end
	roomsButton = toolbarButton("🎨", "Rooms", true)
	roomsButton.Activated:Connect(function()
		setMode("rooms")
	end)
	if table.find(categories, "Objects") then
		local button = toolbarButton(Config.CategoryIcons.Objects, "Objects", true)
		button.Activated:Connect(function()
			selectCategory("Objects")
		end)
		categoryButtons.Objects = button
	end
	moveButton = toolbarButton("✋", "Move", true)
	moveButton.Activated:Connect(function()
		if mode == "move" then
			setMode("objects")
		else
			setMode("move")
			flashStatus("Move: tap an object to pick it up", Color3.fromRGB(255, 230, 120))
		end
	end)
	deleteButton = toolbarButton("🗑️", "Bulldoze", true)
	deleteButton.Activated:Connect(function()
		if mode == "delete" then
			setMode("objects")
		else
			setMode("delete")
			flashStatus("Bulldoze: tap an object to remove it", RED)
		end
	end)
	local undoButton = toolbarButton("↩", "Undo", true)
	undoButton.Activated:Connect(function()
		doUndo()
	end)
	for _, future in ipairs(Config.ComingSoon) do
		local button = toolbarButton(future.icon, future.name, false)
		button.Activated:Connect(function()
			flashStatus(future.note, Color3.fromRGB(220, 220, 220))
		end)
	end

	toggle.Activated:Connect(function()
		setMode(mode == "off" and "objects" or "off")
	end)
	rotateButton.Activated:Connect(function()
		rot = (rot + 1) % 4
	end)

	gui.Parent = playerGui

	-- Requests -----------------------------------------------------------

	local function tryPlaceSingle(gx, gz)
		if not (zone and selected) then
			return
		end
		local ok, result = pcall(function()
			return placeRequest:InvokeServer(selected.name, gx, gz, rot)
		end)
		if ok and result and result.ok then
			if result.model then
				pushUndo({ kind = "place", models = { result.model } })
			end
			flashStatus(selected.name .. " placed!", GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't place that.", RED)
		end
	end

	local function tryPlaceLine(x1, z1, x2, z2)
		local ok, result = pcall(function()
			return placeLineRequest:InvokeServer(selected.name, x1, z1, x2, z2)
		end)
		if ok and result and result.ok then
			if result.models then
				pushUndo({ kind = "place", models = result.models })
			end
			flashStatus(("%d × %s placed!"):format(result.placed, selected.name), GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't build that line.", RED)
		end
	end

	local function tryFoundation(x1, z1, x2, z2)
		local ok, result = pcall(function()
			return foundationRequest:InvokeServer(x1, z1, x2, z2)
		end)
		if ok and result and result.ok then
			if result.models then
				pushUndo({ kind = "place", models = result.models })
			end
			flashStatus(("Foundation built — %d pieces. Now add a door!"):format(result.built), GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't build that foundation.", RED)
		end
	end

	local function tryPaintRoom(x1, z1, x2, z2)
		local ok, result = pcall(function()
			return roomPaintRequest:InvokeServer(selectedRoom, x1, z1, x2, z2)
		end)
		if ok and result and result.ok then
			if selectedRoom == 0 then
				flashStatus("Room paint cleared", Color3.fromRGB(220, 220, 220))
			else
				flashStatus(Config.RoomTypes[selectedRoom].name .. " painted!", Config.RoomTypes[selectedRoom].color)
			end
		elseif ok and result then
			flashStatus(result.err or "Couldn't paint that.", RED)
		end
	end

	local function findPlacedModel()
		if not zone then
			return nil
		end
		local ray = pointerRay()
		if not ray then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { zone.placed }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if not hit then
			return nil
		end
		local model = hit.Instance
		while model and model.Parent ~= zone.placed do
			model = model.Parent
		end
		return model
	end

	-- Read a placed model's identity before demolishing, so undo can
	-- rebuild it exactly.
	local function modelParams(model)
		local name = model:GetAttribute("Asset")
		local gx = model:GetAttribute("GX")
		local gz = model:GetAttribute("GZ")
		local r = model:GetAttribute("Rot")
		if type(name) == "string" and type(gx) == "number" and type(gz) == "number" and type(r) == "number" then
			return { n = name, x = gx, z = gz, r = r }
		end
		return nil
	end

	local function tryDelete()
		local model = findPlacedModel()
		if not model then
			return
		end
		local params = modelParams(model)
		local ok, result = pcall(function()
			return deleteRequest:InvokeServer(model)
		end)
		if ok and result and result.ok then
			if params then
				pushUndo({ kind = "delete", items = { params } })
			end
			flashStatus("Demolished!", GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't demolish that.", RED)
		end
	end

	-- The Move tool: pick an object up (it's demolished but remembered),
	-- then place it wherever — Ctrl+Z puts it back where it was.
	tryMove = function()
		local model = findPlacedModel()
		if not model then
			return
		end
		local params = modelParams(model)
		local asset = params and catalogByName[params.n]
		if not asset then
			flashStatus("Can't move that one.", RED)
			return
		end
		local ok, result = pcall(function()
			return deleteRequest:InvokeServer(model)
		end)
		if not (ok and result and result.ok) then
			flashStatus((ok and result and result.err) or "Couldn't pick that up.", RED)
			return
		end
		pushUndo({ kind = "delete", items = { params } })
		currentCategory = asset.category
		setMode("objects")
		selectAsset(asset)
		rot = params.r
		flashStatus("Moving " .. asset.name .. " — click to re-place (Ctrl+Z puts it back)", Color3.fromRGB(255, 230, 120))
	end

	doUndo = function()
		local entry = table.remove(undoStack)
		if not entry then
			flashStatus("Nothing to undo", Color3.fromRGB(220, 220, 220))
			return
		end
		if entry.kind == "place" then
			local alive = {}
			for _, model in ipairs(entry.models) do
				if typeof(model) == "Instance" and model.Parent ~= nil then
					table.insert(alive, model)
				end
			end
			if #alive == 0 then
				flashStatus("Nothing to undo", Color3.fromRGB(220, 220, 220))
				return
			end
			local ok, result = pcall(function()
				return deleteManyRequest:InvokeServer(alive)
			end)
			if ok and result and result.ok then
				flashStatus(("Undid %d placement%s"):format(result.deleted, result.deleted == 1 and "" or "s"), GREEN)
			end
		elseif entry.kind == "delete" then
			local restored = 0
			for _, item in ipairs(entry.items) do
				local ok, result = pcall(function()
					return placeRequest:InvokeServer(item.n, item.x, item.z, item.r)
				end)
				if ok and result and result.ok then
					restored += 1
				end
			end
			flashStatus(restored > 0 and "Restored!" or "Couldn't restore — spot taken?", restored > 0 and GREEN or RED)
		end
	end

	-- Input --------------------------------------------------------------

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		end
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if input.UserInputType == Enum.UserInputType.Touch and BuildCamera.touchCount() > 1 then
				pressing = false
				hideStretchBox()
				return
			end
			if mode == "objects" and selected then
				local cell = ghostCell
				if cell then
					pressing = true
					pressStartCell = { cell[1], cell[2] }
				end
			elseif (mode == "rooms" and selectedRoom ~= nil) or mode == "foundation" then
				local gx, gz = cellUnderPointer(1, 1)
				if gx then
					pressing = true
					pressStartCell = { gx, gz }
				end
			elseif mode == "delete" then
				tryDelete()
			elseif mode == "move" then
				tryMove()
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			setMode(mode == "off" and "objects" or "off")
		elseif input.KeyCode == Enum.KeyCode.R and mode == "objects" then
			rot = (rot + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.Z and mode ~= "off"
			and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
		then
			doUndo()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		if not pressing then
			return
		end
		pressing = false
		hideStretchBox()

		if mode == "objects" and selected and pressStartCell then
			local isOneSquare = selected.cellsW == 1 and selected.cellsD == 1
			local endCell = ghostCell
			if isOneSquare and endCell
				and (endCell[1] ~= pressStartCell[1] or endCell[2] ~= pressStartCell[2])
			then
				tryPlaceLine(pressStartCell[1], pressStartCell[2], endCell[1], endCell[2])
			elseif endCell and ghostValid then
				tryPlaceSingle(endCell[1], endCell[2])
			end
		elseif mode == "rooms" and selectedRoom ~= nil and pressStartCell then
			local gx, gz = cellUnderPointer(1, 1)
			if gx then
				tryPaintRoom(pressStartCell[1], pressStartCell[2], gx, gz)
			end
		elseif mode == "foundation" and pressStartCell then
			local gx, gz = cellUnderPointer(1, 1)
			if gx then
				tryFoundation(pressStartCell[1], pressStartCell[2], gx, gz)
			end
		end
		pressStartCell = nil
	end)

	RunService.RenderStepped:Connect(function()
		if mode == "objects" then
			updateGhost()
			if pressing and pressStartCell and selected
				and selected.cellsW == 1 and selected.cellsD == 1 and ghostCell
			then
				local sx, sz, axis, count = GridMath.lineCells(
					pressStartCell[1], pressStartCell[2], ghostCell[1], ghostCell[2]
				)
				local ex = axis == "x" and sx + count - 1 or sx
				local ez = axis == "z" and sz + count - 1 or sz
				if count > 1 then
					ghost.Parent = nil
					showStretchBox(sx, sz, ex, ez, GREEN)
				else
					hideStretchBox()
				end
			end
		elseif mode == "rooms" then
			if pressing and pressStartCell then
				local gx, gz = cellUnderPointer(1, 1)
				if gx then
					local color = selectedRoom == 0 and Color3.fromRGB(230, 230, 230)
						or Config.RoomTypes[selectedRoom].color
					showStretchBox(pressStartCell[1], pressStartCell[2], gx, gz, color)
				end
			end
		elseif mode == "foundation" then
			if pressing and pressStartCell then
				local gx, gz = cellUnderPointer(1, 1)
				if gx then
					showStretchBox(pressStartCell[1], pressStartCell[2], gx, gz, Color3.fromRGB(120, 180, 255))
				end
			end
		elseif mode == "delete" or mode == "move" then
			local model = findPlacedModel()
			if model then
				local color = mode == "delete" and RED or Color3.fromRGB(255, 230, 120)
				if not hoverHighlight then
					hoverHighlight = Instance.new("Highlight")
					hoverHighlight.FillTransparency = 0.6
					hoverHighlight.Parent = gui
				end
				hoverHighlight.FillColor = color
				hoverHighlight.OutlineColor = color
				hoverHighlight.Adornee = model
			elseif hoverHighlight then
				hoverHighlight.Adornee = nil
			end
		end
	end)
end

return BuildMode
