-- CashHud: the Prison Architect top bar, Roblox-ified.
--
--   [ DAY 9 ] [ 💰 $4,266 ] [ 👷 2 ] [ 🧍 3/6 ]        (top-center)
--                                          [ 14:32 ]    (top-right clock)
--
-- Segments: prison day, cash (with ±$ blips and an income/session line
-- under it), work crew, prisoners housed/capacity (amber when arrivals
-- queue at the gate). The clock derives from a single server epoch
-- attribute — every player sees the same time with zero network traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))

local CashHud = {}

local CHIP_BG = Color3.fromRGB(20, 24, 20)

local function chip(parent, order, width)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(0, width, 1, 0)
	frame.BackgroundColor3 = CHIP_BG
	frame.BackgroundTransparency = 0.25
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, -8)
	label.Position = UDim2.new(0, 6, 0, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = frame
	frame.Parent = parent
	return frame, label
end

function CashHud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownTopBar"
	gui.ResetOnSpawn = false

	-- The segmented top bar --------------------------------------------
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.Size = UDim2.new(0, 0, 0, 40)
	bar.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local _, dayLabel = chip(bar, 1, 90)
	dayLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
	dayLabel.Text = "DAY 1"

	local cashChip, cashLabel = chip(bar, 2, 150)
	cashLabel.TextColor3 = Color3.fromRGB(140, 255, 150)
	cashLabel.Text = Format.money(cashValue.Value)

	local _, crewLabel = chip(bar, 3, 70)
	crewLabel.Text = "👷 " .. Config.WorkmenPerPlot

	local prisonersChip, prisonersLabel = chip(bar, 4, 100)
	prisonersLabel.Text = "🧍 0/0"

	bar.Parent = gui

	-- Income + session line and the gate warning, under the bar.
	local subLine = Instance.new("TextLabel")
	subLine.AnchorPoint = Vector2.new(0.5, 0)
	subLine.Position = UDim2.new(0.5, 0, 0, 50)
	subLine.Size = UDim2.new(0, 420, 0, 15)
	subLine.BackgroundTransparency = 1
	subLine.Font = Enum.Font.GothamBold
	subLine.TextScaled = true
	subLine.TextColor3 = Color3.fromRGB(200, 200, 200)
	subLine.TextStrokeTransparency = 0.6
	subLine.Text = ""
	subLine.Parent = gui

	local stuckLine = Instance.new("TextLabel")
	stuckLine.AnchorPoint = Vector2.new(0.5, 0)
	stuckLine.Position = UDim2.new(0.5, 0, 0, 67)
	stuckLine.Size = UDim2.new(0, 440, 0, 18)
	stuckLine.BackgroundTransparency = 1
	stuckLine.Font = Enum.Font.GothamBold
	stuckLine.TextScaled = true
	stuckLine.TextColor3 = Color3.fromRGB(255, 170, 110)
	stuckLine.TextStrokeTransparency = 0.5
	stuckLine.Text = ""
	stuckLine.Parent = gui

	-- The clock, top-right like PA -------------------------------------
	local clockPanel = Instance.new("Frame")
	clockPanel.AnchorPoint = Vector2.new(1, 0)
	clockPanel.Position = UDim2.new(1, -14, 0, 8)
	clockPanel.Size = UDim2.new(0, 110, 0, 52)
	clockPanel.BackgroundColor3 = CHIP_BG
	clockPanel.BackgroundTransparency = 0.25
	local clockCorner = Instance.new("UICorner")
	clockCorner.CornerRadius = UDim.new(0, 10)
	clockCorner.Parent = clockPanel
	local clockLabel = Instance.new("TextLabel")
	clockLabel.Size = UDim2.new(1, -10, 0, 30)
	clockLabel.Position = UDim2.new(0, 5, 0, 3)
	clockLabel.BackgroundTransparency = 1
	clockLabel.Font = Enum.Font.GothamBlack
	clockLabel.TextScaled = true
	clockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	clockLabel.Text = "00:00"
	clockLabel.Parent = clockPanel
	local clockSub = Instance.new("TextLabel")
	clockSub.Size = UDim2.new(1, -10, 0, 14)
	clockSub.Position = UDim2.new(0, 5, 0, 34)
	clockSub.BackgroundTransparency = 1
	clockSub.Font = Enum.Font.GothamBold
	clockSub.TextScaled = true
	clockSub.TextColor3 = Color3.fromRGB(180, 180, 180)
	clockSub.Text = "prison time"
	clockSub.Parent = clockPanel
	clockPanel.Parent = gui

	gui.Parent = playerGui

	-- Cash count-up + blips --------------------------------------------
	local shown = cashValue.Value
	local earned, spent = 0, 0
	local lastValue = cashValue.Value

	cashValue.Changed:Connect(function(value)
		local delta = value - lastValue
		lastValue = value
		if delta == 0 then
			return
		end
		if delta > 0 then
			earned += delta
		else
			spent -= delta
		end

		local blip = Instance.new("TextLabel")
		blip.AnchorPoint = Vector2.new(0.5, 0)
		blip.Position = UDim2.new(0.5, math.random(-30, 30), 1, 2)
		blip.Size = UDim2.new(0, 110, 0, 20)
		blip.BackgroundTransparency = 1
		blip.Font = Enum.Font.GothamBlack
		blip.TextScaled = true
		blip.TextColor3 = delta > 0 and Color3.fromRGB(140, 255, 150) or Color3.fromRGB(255, 130, 120)
		blip.TextStrokeTransparency = 0.5
		blip.Text = (delta > 0 and "+" or "-") .. Format.money(math.abs(delta))
		blip.Parent = cashChip
		TweenService:Create(blip, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = blip.Position + UDim2.new(0, 0, 0, 26),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.3, function()
			blip:Destroy()
		end)
	end)

	-- Live refreshes ----------------------------------------------------
	local function refreshStats()
		local housed = player:GetAttribute("PrisonHoused") or 0
		local capacity = player:GetAttribute("PrisonCapacity") or 0
		local waiting = player:GetAttribute("PrisonWaiting") or 0
		prisonersLabel.Text = ("🧍 %d/%d"):format(housed, capacity)
		prisonersLabel.TextColor3 = waiting > 0 and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(255, 255, 255)
		prisonersChip.BackgroundColor3 = waiting > 0 and Color3.fromRGB(45, 32, 18) or CHIP_BG

		local perMin = housed * Config.GrantPerPrisoner * (60 / Config.GrantInterval)
		subLine.Text = ("%s/min in grants · session +%s / -%s"):format(
			Format.money(perMin), Format.money(earned), Format.money(spent))

		stuckLine.Text = player:GetAttribute("IntakeStuck") == true
			and "⚠ Arrivals can't reach a cell — is there a door path?" or ""

		dayLabel.Text = ("DAY %d"):format(player:GetAttribute("PrisonDay") or 1)
	end
	for _, attr in ipairs({ "PrisonHoused", "PrisonCapacity", "PrisonWaiting", "IntakeStuck", "PrisonDay" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshStats)
	end
	refreshStats()

	RunService.RenderStepped:Connect(function(dt)
		-- Smooth cash count-up.
		local target = cashValue.Value
		if shown ~= target then
			shown += (target - shown) * math.min(dt * 6, 1)
			if math.abs(target - shown) < 1 then
				shown = target
			end
			cashLabel.Text = Format.money(shown)
		end

		-- The shared clock, derived from the server's epoch.
		local epoch = workspace:GetAttribute("ClockEpoch")
		if epoch then
			local dayFraction = ((workspace:GetServerTimeNow() - epoch) % Config.DayLength) / Config.DayLength
			local totalMinutes = math.floor(dayFraction * 24 * 60)
			clockLabel.Text = ("%02d:%02d"):format(math.floor(totalMinutes / 60), totalMinutes % 60)
		end
	end)
end

return CashHud
