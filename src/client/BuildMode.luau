-- BuildMode: the whole building experience on the player's screen.
--
--   🔨 Build button (or B key)  ->  opens the asset menu
--   pick an asset               ->  ghost preview follows your pointer,
--                                   snapped to your plot's grid
--   click / tap                 ->  asks the server to place it
--   R key or ↻ button           ->  rotate 90 degrees
--   🗑️ mode                     ->  click placed objects to demolish
--
-- The menu builds itself from whatever is in ReplicatedStorage/
-- Buildables — including little live 3D thumbnails — so new assets the
-- map-maker drops in show up automatically, no code changes ever.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GridMath = require(ReplicatedStorage.Shared:WaitForChild("GridMath"))
local AssetCatalog = require(ReplicatedStorage.Shared:WaitForChild("AssetCatalog"))

local BuildMode = {}

local GREEN = Color3.fromRGB(80, 255, 120)
local RED = Color3.fromRGB(255, 80, 80)
local PANEL_BG = Color3.fromRGB(20, 24, 20)

function BuildMode.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local placeRequest = remotes:WaitForChild("PlaceRequest")
	local deleteRequest = remotes:WaitForChild("DeleteRequest")

	local buildablesFolder = ReplicatedStorage:WaitForChild(Config.BuildablesFolderName)
	local catalogByName, catalogOrdered = AssetCatalog.load(buildablesFolder)

	-- My zone (the server drops a "BuildZone" pointer into the Player).
	local zone = nil -- { part, info, placed }
	local occupied = {} -- local mirror of taken grid squares, for preview colors

	-- Build-mode state.
	local mode = "off" -- "off" | "place" | "delete"
	local selected = nil -- asset currently being placed
	local rot = 0
	local ghost = nil -- the preview model
	local ghostHighlight = nil
	local lastPointer = Vector2.new(0, 0)
	local ghostCell = nil -- {gx, gz} of the current preview spot
	local ghostValid = false
	local hoverHighlight = nil -- delete-mode red glow
	local zoneBox = nil -- outline of my plot while building

	-- Occupancy mirror ---------------------------------------------------
	-- The server stamps every placed model with its grid info, so the
	-- client can tell "that square is taken" without asking.

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
			-- Attributes are set before parenting, so they're readable now.
			markModel(model, true)
		end)
		zone.placed.ChildRemoved:Connect(function(model)
			markModel(model, nil)
		end)
	end

	local zoneMarker = player:WaitForChild("BuildZone", 30)
	if zoneMarker and zoneMarker.Value then
		watchZone(zoneMarker.Value)
	elseif zoneMarker then
		zoneMarker.Changed:Connect(function(value)
			if value and not zone then
				watchZone(value)
			end
		end)
	end

	-- Ghost preview ------------------------------------------------------

	local function destroyGhost()
		if ghost then
			ghost:Destroy()
			ghost = nil
			ghostHighlight = nil
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

	local function pointerRay()
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		return camera:ViewportPointToRay(lastPointer.X, lastPointer.Y)
	end

	local function updateGhost()
		if not (zone and selected and ghost) then
			return
		end
		local ray = pointerRay()
		if not ray then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { zone.part }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
		if not hit then
			ghost.Parent = nil -- pointing at the sky / off-plot: hide it
			ghostCell = nil
			return
		end

		local w, d = GridMath.footprint(selected, rot)
		local gx, gz = GridMath.worldToCell(zone.info, hit.Position, w, d)
		local pivot = GridMath.placementPivot(zone.info, selected, gx, gz, rot)
		ghost:PivotTo(pivot)
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
	toggle.Name = "BuildToggle"
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
	panel.Name = "BuildPanel"
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
	status.Name = "Status"
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

	local rotateButton = Instance.new("TextButton")
	rotateButton.Size = UDim2.new(0, 44, 0, 44)
	rotateButton.Position = UDim2.new(0, 8, 0, 8)
	rotateButton.BackgroundColor3 = Color3.fromRGB(45, 52, 45)
	rotateButton.Font = Enum.Font.GothamBold
	rotateButton.TextSize = 22
	rotateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rotateButton.Text = "↻"
	local rotateCorner = Instance.new("UICorner")
	rotateCorner.CornerRadius = UDim.new(0, 10)
	rotateCorner.Parent = rotateButton
	rotateButton.Parent = panel

	local deleteButton = Instance.new("TextButton")
	deleteButton.Size = UDim2.new(0, 44, 0, 44)
	deleteButton.Position = UDim2.new(0, 8, 0, 60)
	deleteButton.BackgroundColor3 = Color3.fromRGB(45, 52, 45)
	deleteButton.Font = Enum.Font.GothamBold
	deleteButton.TextSize = 20
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.Text = "🗑️"
	local deleteCorner = Instance.new("UICorner")
	deleteCorner.CornerRadius = UDim.new(0, 10)
	deleteCorner.Parent = deleteButton
	deleteButton.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "Assets"
	list.Position = UDim2.new(0, 60, 0, 8)
	list.Size = UDim2.new(1, -68, 1, -16)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	list.Parent = panel

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

	-- One menu tile per asset, with a live 3D thumbnail.
	local assetButtons = {}
	local function refreshSelectionLook()
		for name, button in pairs(assetButtons) do
			button.BackgroundColor3 = (selected and selected.name == name)
				and Color3.fromRGB(60, 110, 60)
				or Color3.fromRGB(45, 52, 45)
		end
	end

	local selectAsset -- declared below; tiles need it
	for order, asset in ipairs(catalogOrdered) do
		local tile = Instance.new("TextButton")
		tile.Name = asset.name
		tile.LayoutOrder = order
		tile.Size = UDim2.new(0, 104, 1, 0)
		tile.BackgroundColor3 = Color3.fromRGB(45, 52, 45)
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
		tile.Parent = list
		assetButtons[asset.name] = tile
	end

	gui.Parent = playerGui

	-- Mode switching -----------------------------------------------------

	local function clearHover()
		if hoverHighlight then
			hoverHighlight:Destroy()
			hoverHighlight = nil
		end
	end

	local function setMode(newMode)
		mode = newMode
		destroyGhost()
		clearHover()
		if mode ~= "place" then
			selected = nil
		end
		refreshSelectionLook()
		panel.Visible = mode ~= "off"
		toggle.Text = mode == "off" and "🔨 Build" or "✖ Close"
		deleteButton.BackgroundColor3 = mode == "delete" and Color3.fromRGB(140, 50, 50) or Color3.fromRGB(45, 52, 45)
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
	end

	selectAsset = function(asset)
		if not zone then
			flashStatus("No build plot assigned yet!", RED)
			return
		end
		mode = "place"
		selected = asset
		clearHover()
		makeGhost(asset)
		refreshSelectionLook()
		deleteButton.BackgroundColor3 = Color3.fromRGB(45, 52, 45)
		flashStatus("Placing: " .. asset.name .. "  (R or ↻ to rotate)", GREEN)
	end

	toggle.Activated:Connect(function()
		setMode(mode == "off" and "menu" or "off")
	end)
	rotateButton.Activated:Connect(function()
		rot = (rot + 1) % 4
	end)
	deleteButton.Activated:Connect(function()
		if mode == "delete" then
			setMode("menu")
		else
			setMode("delete")
			flashStatus("Demolish mode: tap an object to remove it", RED)
		end
	end)

	-- Input --------------------------------------------------------------

	local function tryPlace()
		if not (zone and selected and ghostCell) then
			return
		end
		local ok, result = pcall(function()
			return placeRequest:InvokeServer(selected.name, ghostCell[1], ghostCell[2], rot)
		end)
		if ok and result and result.ok then
			flashStatus(selected.name .. " placed!", GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't place that.", RED)
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
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
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
			return -- the click landed on a button, not the world
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if mode == "place" then
				updateGhost() -- make sure the ghost matches this exact tap
				if ghostValid then
					tryPlace()
				end
			elseif mode == "delete" then
				tryDelete()
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			setMode(mode == "off" and "menu" or "off")
		elseif input.KeyCode == Enum.KeyCode.R and mode == "place" then
			rot = (rot + 1) % 4
		end
	end)

	RunService.RenderStepped:Connect(function()
		if mode == "place" then
			updateGhost()
		elseif mode == "delete" then
			local model = findPlacedModel()
			if model then
				-- One reusable highlight, just re-aimed — no churn.
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
