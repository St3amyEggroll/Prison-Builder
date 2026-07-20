-- PlotService: the heart of Phase 1. Builds the row of prison plots,
-- gives every joining player their own, and handles the one big verb of
-- the MVP: step on the glowing pad -> buy a cell -> an inmate moves in.
--
-- Layout of one plot (bird's-eye view, front gate at the bottom):
--
--        [c1][c2][c3][c4][c5][c6][c7][c8]      <- back row of cells
--      [c9]                          [c16]
--      [c10]                         [c17]
--      [c11]        (yard)           [c18]     <- cells fill the walls
--      [c12]                         [c19]        as you buy them
--      [c13]                         [c20]
--      [c14]         (pad)           [c21]
--      [c15]      __gate gap__       [c22]
--
-- Cells are just decoration + one inmate each. All the money math stays
-- in SaveService; all the rig building stays in InmateService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local World = require(script.Parent.World)
local SaveService = require(script.Parent.SaveService)
local InmateService = require(script.Parent.InmateService)

local PlotService = {}

local COLOR_WALL = Color3.fromRGB(200, 198, 190)
local COLOR_FLOOR = Color3.fromRGB(120, 120, 125)
local COLOR_CELL_FLOOR = Color3.fromRGB(95, 95, 100)
local COLOR_BARS = Color3.fromRGB(35, 35, 40)
local COLOR_PAD = Color3.fromRGB(80, 255, 100)

-- Where each cell sits inside a plot, in plot-local studs (plot center is
-- 0,0). "face" is the direction the open, barred side points (toward the
-- yard). 8 across the back, 7 down each side = 22, matching Config.
local CELL_SLOTS = {}
do
	for i = 1, 8 do
		CELL_SLOTS[i] = { pos = Vector3.new(-49 + (i - 1) * 14, 0, -52), face = Vector3.new(0, 0, 1) }
	end
	for i = 1, 7 do
		CELL_SLOTS[8 + i] = { pos = Vector3.new(-56, 0, -37 + (i - 1) * 14), face = Vector3.new(1, 0, 0) }
	end
	for i = 1, 7 do
		CELL_SLOTS[15 + i] = { pos = Vector3.new(56, 0, -37 + (i - 1) * 14), face = Vector3.new(-1, 0, 0) }
	end
	assert(#CELL_SLOTS == Config.MaxCells, "CELL_SLOTS must match Config.CellCosts length")
end

local plots = {} -- plot index -> plot record
local playerPlots = {} -- player -> plot record
local lastBuyAttempt = {} -- player -> os.clock() of last pad touch (debounce)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseRemote = remotes:WaitForChild("PurchaseResult")

-- Building ---------------------------------------------------------------

local function padText(plot)
	if plot.cellCount >= Config.MaxCells then
		return ("🔒 PRISON FULL!\n%d cells"):format(Config.MaxCells)
	end
	local nextCost = Config.CellCosts[plot.cellCount + 1]
	return ("🔒 Buy Cell #%d\n%s"):format(plot.cellCount + 1, Format.money(nextCost))
end

local function signText(plot)
	if plot.owner then
		return "🔒 " .. plot.owner.DisplayName .. "'s Prison"
	end
	return "Unclaimed Prison"
end

-- One plot: floor slab, four walls with a gate gap, a name sign, and the
-- glowing buy pad. Cells get added later, one purchase at a time.
local function buildPlot(index)
	local originCF = CFrame.new((index - (Config.PlotCount + 1) / 2) * 170, 0, -40)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- Floor slab; its top sits at Y = 0.5.
	World.part({
		Name = "Slab",
		Size = Vector3.new(130, 1, 130),
		CFrame = originCF,
		Material = Enum.Material.Concrete,
		Color = COLOR_FLOOR,
	}, model)

	-- Perimeter walls, 10 studs tall. The front wall has a 16-stud gate
	-- gap so players can walk in.
	local wallSpecs = {
		{ Vector3.new(130, 10, 1.5), CFrame.new(0, 5.5, -60) }, -- back
		{ Vector3.new(1.5, 10, 118), CFrame.new(-64.25, 5.5, 0) }, -- left
		{ Vector3.new(1.5, 10, 118), CFrame.new(64.25, 5.5, 0) }, -- right
		{ Vector3.new(57, 10, 1.5), CFrame.new(-36.5, 5.5, 60) }, -- front-left of gate
		{ Vector3.new(57, 10, 1.5), CFrame.new(36.5, 5.5, 60) }, -- front-right of gate
	}
	for _, spec in ipairs(wallSpecs) do
		World.part({
			Name = "Wall",
			Size = spec[1],
			CFrame = originCF * spec[2],
			Material = Enum.Material.Concrete,
			Color = COLOR_WALL,
		}, model)
	end

	-- Invisible post above the gate holding the prison's name sign.
	local signPost = World.part({
		Name = "SignPost",
		Size = Vector3.new(1, 1, 1),
		CFrame = originCF * CFrame.new(0, 13, 60),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "Sign"
	signGui.Size = UDim2.new(0, 320, 0, 70)
	signGui.MaxDistance = 400
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0.3
	signGui.Parent = signPost
	signLabel.Parent = signGui

	-- The glowing buy pad: a flat neon cylinder near the gate. Stepping
	-- on it is how you buy (works identically on PC and phones — no UI).
	local pad = World.part({
		Name = "BuyPad",
		Shape = Enum.PartType.Cylinder,
		-- A cylinder's height runs along X, so we lay it flat by rolling
		-- it 90 degrees; it becomes a 8-stud-wide, 0.5-thick disc.
		Size = Vector3.new(0.5, 8, 8),
		CFrame = originCF * CFrame.new(0, 0.85, 45) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = COLOR_PAD,
		CanCollide = false,
	}, model)
	local padGui = Instance.new("BillboardGui")
	padGui.Name = "PriceTag"
	padGui.Size = UDim2.new(0, 220, 0, 64)
	padGui.StudsOffset = Vector3.new(0, 4, 0)
	padGui.MaxDistance = 180
	local padLabel = Instance.new("TextLabel")
	padLabel.Size = UDim2.new(1, 0, 1, 0)
	padLabel.BackgroundTransparency = 1
	padLabel.Font = Enum.Font.GothamBold
	padLabel.TextScaled = true
	padLabel.TextColor3 = Color3.fromRGB(170, 255, 170)
	padLabel.TextStrokeTransparency = 0.3
	padGui.Parent = pad
	padLabel.Parent = padGui

	-- Purchased cells and their inmates live in these folders.
	local cellsFolder = Instance.new("Folder")
	cellsFolder.Name = "Cells"
	cellsFolder.Parent = model
	local inmatesFolder = Instance.new("Folder")
	inmatesFolder.Name = "Inmates"
	inmatesFolder.Parent = model

	model.Parent = workspace.Lockdown

	local plot = {
		index = index,
		originCF = originCF,
		model = model,
		pad = pad,
		padLabel = padLabel,
		signLabel = signLabel,
		cellsFolder = cellsFolder,
		inmatesFolder = inmatesFolder,
		owner = nil,
		cellCount = 0,
	}
	plot.padLabel.Text = padText(plot)
	plot.signLabel.Text = signText(plot)

	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or plot.owner ~= player then
			return
		end
		-- Walking over the pad fires Touched many times a second; only
		-- consider one buy attempt per second per player.
		local now = os.clock()
		if lastBuyAttempt[player] and now - lastBuyAttempt[player] < 1 then
			return
		end
		lastBuyAttempt[player] = now
		PlotService.tryBuyCell(player)
	end)

	return plot
end

-- One cell: floor, three low walls, jail bars across the yard side, a
-- bed, and its resident inmate.
local function buildCell(plot, cellIndex)
	local slot = CELL_SLOTS[cellIndex]
	-- Cell-local space: -Z points out through the bars toward the yard.
	local base = plot.originCF * CFrame.new(0, 0.5, 0)
		* CFrame.lookAt(slot.pos, slot.pos + slot.face)

	local cell = Instance.new("Model")
	cell.Name = "Cell" .. cellIndex

	World.part({
		Name = "Floor",
		Size = Vector3.new(13.4, 0.4, 11.4),
		CFrame = base * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.Concrete,
		Color = COLOR_CELL_FLOOR,
	}, cell)

	-- Back and side walls (the plot's perimeter wall looms behind).
	World.part({
		Name = "BackWall",
		Size = Vector3.new(13.4, 7, 0.4),
		CFrame = base * CFrame.new(0, 3.9, 5.5),
		Material = Enum.Material.Concrete,
		Color = COLOR_WALL,
	}, cell)
	for _, x in ipairs({ -6.5, 6.5 }) do
		World.part({
			Name = "SideWall",
			Size = Vector3.new(0.4, 7, 11.4),
			CFrame = base * CFrame.new(x, 3.9, 0),
			Material = Enum.Material.Concrete,
			Color = COLOR_WALL,
		}, cell)
	end

	-- Jail bars across the front. Purely decorative in Phase 1 — but they
	-- make it a prison.
	for k = 0, 5 do
		World.part({
			Name = "Bar",
			Size = Vector3.new(0.35, 6.6, 0.35),
			CFrame = base * CFrame.new(-5.4 + k * 2.16, 3.7, -5.5),
			Material = Enum.Material.Metal,
			Color = COLOR_BARS,
		}, cell)
	end
	World.part({
		Name = "BarRail",
		Size = Vector3.new(13.4, 0.4, 0.4),
		CFrame = base * CFrame.new(0, 7.2, -5.5),
		Material = Enum.Material.Metal,
		Color = COLOR_BARS,
	}, cell)

	-- A little bed: frame, mattress, pillow.
	World.part({
		Name = "BedFrame",
		Size = Vector3.new(2.8, 0.5, 5.6),
		CFrame = base * CFrame.new(4.7, 0.65, 1.8),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 70, 75),
	}, cell)
	World.part({
		Name = "Mattress",
		Size = Vector3.new(2.6, 0.6, 5.4),
		CFrame = base * CFrame.new(4.7, 1.2, 1.8),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(235, 235, 230),
	}, cell)
	World.part({
		Name = "Pillow",
		Size = Vector3.new(2.2, 0.35, 1.3),
		CFrame = base * CFrame.new(4.7, 1.65, -0.4),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(255, 170, 60),
	}, cell)

	cell.Parent = plot.cellsFolder

	-- The resident moves in, standing on the cell floor.
	InmateService.spawn(base * CFrame.new(-2, 0.4, 1), cellIndex, plot.inmatesFolder)
end

-- Claiming & buying -------------------------------------------------------

local function assignPlot(player)
	-- Wait for the player's save to load so we know how many cells to
	-- rebuild. If they left mid-load, waitForData returns nil.
	local data = SaveService.waitForData(player)
	if not data or not player:IsDescendantOf(game) then
		return
	end

	local plot = nil
	for _, candidate in ipairs(plots) do
		if candidate.owner == nil then
			plot = candidate
			break
		end
	end
	if not plot then
		-- More visitors than plots (7+ players). MVP limitation: they can
		-- wander and watch. Phase 5's Break Out mode gives them a job.
		warn("[Lockdown] No free plot for " .. player.Name)
		return
	end

	plot.owner = player
	playerPlots[player] = plot

	-- Rebuild everything they had saved from previous sessions.
	for i = 1, math.min(data.cells, Config.MaxCells) do
		plot.cellCount = i
		buildCell(plot, i)
	end
	plot.padLabel.Text = padText(plot)
	plot.signLabel.Text = signText(plot)

	-- Walk each new character to their own front gate (they spawn at the
	-- plaza otherwise, which is confusing).
	local function placeCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or plot.owner ~= player then
			return
		end
		task.wait(0.1) -- let the default spawn placement finish first
		local gate = plot.originCF * CFrame.new(0, 3.5, 68)
		local lookAtPad = plot.originCF * CFrame.new(0, 3.5, 45)
		character:PivotTo(CFrame.lookAt(gate.Position, lookAtPad.Position))
	end
	player.CharacterAdded:Connect(placeCharacter)
	if player.Character then
		task.spawn(placeCharacter, player.Character)
	end
end

local function releasePlot(player)
	lastBuyAttempt[player] = nil
	local plot = playerPlots[player]
	if not plot then
		return
	end
	playerPlots[player] = nil
	plot.owner = nil
	plot.cellCount = 0
	plot.cellsFolder:ClearAllChildren()
	plot.inmatesFolder:ClearAllChildren()
	plot.padLabel.Text = padText(plot)
	plot.signLabel.Text = signText(plot)
end

function PlotService.tryBuyCell(player)
	local plot = playerPlots[player]
	if not plot then
		return
	end

	if plot.cellCount >= Config.MaxCells then
		purchaseRemote:FireClient(player, false, { reason = "full" })
		return
	end

	local cost = Config.CellCosts[plot.cellCount + 1]
	if not SaveService.trySpend(player, cost) then
		purchaseRemote:FireClient(player, false, {
			reason = "poor",
			shortfall = cost - SaveService.getCash(player),
		})
		return
	end

	plot.cellCount += 1
	SaveService.setCells(player, plot.cellCount)
	buildCell(plot, plot.cellCount)
	plot.padLabel.Text = padText(plot)

	purchaseRemote:FireClient(player, true, {
		cellIndex = plot.cellCount,
		cost = cost,
	})
end

-- Used by Economy to pay every prison owner each tick.
function PlotService.eachOwnedPlot(callback)
	for player, plot in pairs(playerPlots) do
		callback(player, plot)
	end
end

function PlotService.init()
	for i = 1, Config.PlotCount do
		plots[i] = buildPlot(i)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(assignPlot, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(assignPlot, player)
	end
	Players.PlayerRemoving:Connect(releasePlot)
end

return PlotService
