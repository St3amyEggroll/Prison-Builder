-- BuildMode: the whole building experience on the player's screen.
--
--   🔨 Build (or B)      ->  top-down build camera + the build panel
--   🧱 Objects tab       ->  pick an asset, ghost preview snaps to your
--                            grid; click/tap places. 1-square assets
--                            (walls, fences, floors) support PRESS-DRAG
--                            to build a whole line at once, auto-rotated
--                            along the drag.
--   🎨 Rooms tab         ->  pick the room type FIRST, then drag a
--                            rectangle to paint it (eraser included).
--   ↻ / R                ->  rotate the ghost 90°
--   🗑️                   ->  demolish mode
--
-- The menu builds itself from ReplicatedStorage/Buildables (live 3D
-- thumbnails included), so new assets appear automatically. The server
-- re-validates everything — this file is just the friendly face.

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
	local roomPaintRequest = remotes:WaitForChild("RoomPaintRequest")

	local buildablesFolder = ReplicatedStorage:WaitForChild(Config.BuildablesFolderName)
	local catalogByName, catalogOrdered = AssetCatalog.load(buildablesFolder)

	-- My zone (the server drops a "BuildZone" pointer into the Player).
	local zone = nil -- { part, info, placed }
	local occupied = {} -- local mirror of taken squares, for preview colors

	-- State.
	local mode = "off" -- "off" | "objects" | "rooms" | "delete"
	local selected = nil -- asset being placed (objects tab)
	local selectedRoom = nil -- room type id being painted (rooms tab; 0 = eraser)
	local rot = 0
	local ghost, ghostHighlight = nil, nil
	local ghostCell, ghostValid = nil, false
	local lastPointer = Vector2.new(0, 0)
	local pressing = false -- a press that started on the world, not UI
	local pressStartCell = nil
	local stretchBox = nil -- the drag preview (lines & room rects)
	local hoverHighlight = nil
	local zoneBox = nil

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

	-- The translucent slab shown while dragging a line or a room rect.
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

	-- UI -----------------------------------------------------------------

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

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -70)
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
	status.Position = UDim2.new(0.5, 0, 0, -6)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(255, 255, 255)
	status.TextStrokeTransparency = 0.4
	status.Text = ""
	status.Parent = panel

	local function sideButton(text, x, y)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 44, 0, 44)
		button.Position = UDim2.new(0, x, 0, y)
		button.BackgroundColor3 = BUTTON_BG
		button.Font = Enum.Font.GothamBold
		button.TextSize = 20
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		button.Parent = panel
		return button
	end

	local objectsTab = sideButton("🧱", 8, 8)
	local roomsTab = sideButton("🎨", 8, 60)
	local rotateButton = sideButton("↻", 58, 8)
	local deleteButton = sideButton("🗑️", 58, 60)

	local function makeList()
		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.new(0, 110, 0, 8)
		list.Size = UDim2.new(1, -118, 1, -16)
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

	-- Objects tab tiles (3D thumbnails).
	local assetButtons = {}
	local roomButtons = {}
	local function refreshSelectionLook()
		for name, button in pairs(assetButtons) do
			button.BackgroundColor3 = (selected and selected.name == name) and SELECTED_BG or BUTTON_BG
		end
		for id, button in pairs(roomButtons) do
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = (selectedRoom == id) and 0 or 1
			end
		end
		objectsTab.BackgroundColor3 = (mode == "objects") and SELECTED_BG or BUTTON_BG
		roomsTab.BackgroundColor3 = (mode == "rooms") and SELECTED_BG or BUTTON_BG
		deleteButton.BackgroundColor3 = (mode == "delete") and Color3.fromRGB(140, 50, 50) or BUTTON_BG
	end

	local selectAsset, selectRoom

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
		assetButtons[asset.name] = tile
	end

	-- Rooms tab tiles (color chips). Index 0 = the eraser.
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

	gui.Parent = playerGui

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
		panel.Visible = mode ~= "off"
		objectsList.Visible = mode ~= "rooms"
		roomsList.Visible = mode == "rooms"
		toggle.Text = mode == "off" and "🔨 Build" or "✖ Close"
		refreshSelectionLook()

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

	selectAsset = function(asset)
		if not zone then
			flashStatus("No build plot assigned yet!", RED)
			return
		end
		mode = "objects"
		selected = asset
		selectedRoom = nil
		clearHover()
		hideStretchBox()
		makeGhost(asset)
		objectsList.Visible = true
		roomsList.Visible = false
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
		mode = "rooms"
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

	toggle.Activated:Connect(function()
		setMode(mode == "off" and "objects" or "off")
	end)
	objectsTab.Activated:Connect(function()
		setMode("objects")
	end)
	roomsTab.Activated:Connect(function()
		setMode("rooms")
	end)
	rotateButton.Activated:Connect(function()
		rot = (rot + 1) % 4
	end)
	deleteButton.Activated:Connect(function()
		if mode == "delete" then
			setMode("objects")
		else
			setMode("delete")
			flashStatus("Demolish mode: tap an object to remove it", RED)
		end
	end)

	-- Requests -----------------------------------------------------------

	local function tryPlaceSingle(gx, gz)
		if not (zone and selected) then
			return
		end
		local ok, result = pcall(function()
			return placeRequest:InvokeServer(selected.name, gx, gz, rot)
		end)
		if ok and result and result.ok then
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
			flashStatus(("%d × %s placed!"):format(result.placed, selected.name), GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't build that line.", RED)
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

	local function tryDelete()
		local model = findPlacedModel()
		if not model then
			return
		end
		local ok, result = pcall(function()
			return deleteRequest:InvokeServer(model)
		end)
		if ok and result and result.ok then
			flashStatus("Demolished!", GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't demolish that.", RED)
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
			-- A second finger means a camera gesture — cancel the press.
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
			elseif mode == "rooms" and selectedRoom ~= nil then
				local gx, gz = cellUnderPointer(1, 1)
				if gx then
					pressing = true
					pressStartCell = { gx, gz }
				end
			elseif mode == "delete" then
				tryDelete()
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			setMode(mode == "off" and "objects" or "off")
		elseif input.KeyCode == Enum.KeyCode.R and mode == "objects" then
			rot = (rot + 1) % 4
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
		end
		pressStartCell = nil
	end)

	RunService.RenderStepped:Connect(function()
		if mode == "objects" then
			updateGhost()
			-- Dragging a 1-square asset: show the line preview instead.
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
		elseif mode == "delete" then
			local model = findPlacedModel()
			if model then
				if not hoverHighlight then
					hoverHighlight = Instance.new("Highlight")
					hoverHighlight.FillColor = RED
					hoverHighlight.FillTransparency = 0.6
					hoverHighlight.OutlineColor = RED
					hoverHighlight.Parent = gui
				end
				hoverHighlight.Adornee = model
			elseif hoverHighlight then
				hoverHighlight.Adornee = nil
			end
		end
	end)
end

return BuildMode
