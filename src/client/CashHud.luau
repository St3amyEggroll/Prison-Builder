-- CashHud: Prison Architect's readouts, in PA's exact places.
--
--   top-right:      the clock panel — the time big, "Day N — activity"
--                   under it. (PA's speed controls are deliberately
--                   absent: multiplayer time is shared.)
--   bottom-right:   the Balance and Prisoners rows, PA's corner
--                   readouts. Prisoners ambers when arrivals queue at
--                   the gate — CLICK IT to open the Intake panel.
--
-- Cash changes still blip ±$ off the Balance row, and the clock derives
-- from a single server epoch attribute — every player sees the same time
-- with zero network traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

local CashHud = {}

function CashHud.start(opts)
	opts = opts or {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownHud"
	gui.ResetOnSpawn = false

	-- Top-right: the clock panel ----------------------------------------
	local clockPanel = UIKit.panel(gui, "ClockPanel")
	clockPanel.AnchorPoint = Vector2.new(1, 0)
	clockPanel.Position = UDim2.new(1, -12, 0, 12)
	clockPanel.Size = UDim2.new(0, 124, 0, 58)

	local clockLabel = Instance.new("TextLabel")
	clockLabel.Position = UDim2.new(0, 0, 0, 4)
	clockLabel.Size = UDim2.new(1, 0, 0, 30)
	clockLabel.BackgroundTransparency = 1
	clockLabel.Font = Enum.Font.GothamBlack
	clockLabel.TextSize = 24
	clockLabel.TextColor3 = UIKit.TEXT
	clockLabel.Text = "00:00"
	clockLabel.Parent = clockPanel

	local clockSub = Instance.new("TextLabel")
	clockSub.Position = UDim2.new(0, 0, 0, 36)
	clockSub.Size = UDim2.new(1, 0, 0, 16)
	clockSub.BackgroundTransparency = 1
	clockSub.Font = Enum.Font.GothamMedium
	clockSub.TextSize = 12
	clockSub.TextColor3 = UIKit.DIM
	clockSub.Text = "Day 1"
	clockSub.Parent = clockPanel

	-- Bottom-right: Balance / Prisoners ---------------------------------
	local stack = Instance.new("Frame")
	stack.AnchorPoint = Vector2.new(1, 1)
	stack.Position = UDim2.new(1, -12, 1, -12)
	stack.Size = UDim2.new(0, 190, 0, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack
	stack.Parent = gui

	local function statRow(order, clickable)
		local row = Instance.new(clickable and "TextButton" or "Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundColor3 = UIKit.PANEL
		row.BackgroundTransparency = 0.03
		row.BorderSizePixel = 0
		if clickable then
			row.Text = ""
			row.AutoButtonColor = true
		end
		UIKit.stroke(row, UIKit.EDGE_DIM, 1, 0)
		local left = Instance.new("TextLabel")
		left.Position = UDim2.new(0, 8, 0, 0)
		left.Size = UDim2.new(0, 80, 1, 0)
		left.BackgroundTransparency = 1
		left.Font = Enum.Font.GothamMedium
		left.TextSize = 12
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.TextColor3 = UIKit.DIM
		left.Parent = row
		local right = Instance.new("TextLabel")
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -8, 0, 0)
		right.Size = UDim2.new(0, 120, 1, 0)
		right.BackgroundTransparency = 1
		right.Font = Enum.Font.GothamBold
		right.TextSize = 14
		right.TextXAlignment = Enum.TextXAlignment.Right
		right.TextColor3 = UIKit.TEXT
		right.Parent = row
		row.Parent = stack
		return row, left, right
	end

	local infoRow, infoLeft, infoRight = statRow(1, false)
	infoRow.Size = UDim2.new(1, 0, 0, 18)
	infoRow.BackgroundTransparency = 0.35
	infoLeft.Text = "Grants"
	infoRight.Font = Enum.Font.GothamMedium
	infoRight.TextSize = 11
	infoRight.TextColor3 = UIKit.DIM

	local balanceRow, balanceLeft, balanceRight = statRow(2, false)
	balanceLeft.Text = "Balance"
	balanceRight.TextColor3 = UIKit.GOOD
	balanceRight.Text = Format.money(cashValue.Value)

	local prisonersRow, prisonersLeft, prisonersRight = statRow(3, true)
	prisonersLeft.Text = "Prisoners"
	prisonersRight.Text = "0 / 0"
	prisonersRow.Activated:Connect(function()
		if opts.onPrisoners then
			opts.onPrisoners()
		end
	end)

	-- The gate-stuck warning, top-center where PA floats its alerts.
	local stuckLine = Instance.new("TextLabel")
	stuckLine.AnchorPoint = Vector2.new(0.5, 0)
	stuckLine.Position = UDim2.new(0.5, 0, 0, 12)
	stuckLine.Size = UDim2.new(0, 440, 0, 18)
	stuckLine.BackgroundTransparency = 1
	stuckLine.Font = Enum.Font.GothamBold
	stuckLine.TextScaled = true
	stuckLine.TextColor3 = Color3.fromRGB(255, 170, 110)
	stuckLine.TextStrokeTransparency = 0.5
	stuckLine.Text = ""
	stuckLine.Parent = gui

	-- Security alerts (escapes, catches, lockdowns) under it, in red.
	local alertLine = Instance.new("TextLabel")
	alertLine.AnchorPoint = Vector2.new(0.5, 0)
	alertLine.Position = UDim2.new(0.5, 0, 0, 32)
	alertLine.Size = UDim2.new(0, 480, 0, 20)
	alertLine.BackgroundTransparency = 1
	alertLine.Font = Enum.Font.GothamBold
	alertLine.TextScaled = true
	alertLine.TextColor3 = Color3.fromRGB(255, 140, 125)
	alertLine.TextStrokeTransparency = 0.45
	alertLine.Text = ""
	alertLine.Parent = gui

	gui.Parent = playerGui

	local alertId = 0
	player:GetAttributeChangedSignal("SecurityAlert"):Connect(function()
		local raw = player:GetAttribute("SecurityAlert")
		if type(raw) ~= "string" then
			return
		end
		-- The server prefixes a counter so repeat alerts still fire.
		alertId += 1
		local id = alertId
		alertLine.Text = string.match(raw, "^%d+|(.*)$") or raw
		task.delay(6, function()
			if alertId == id then
				alertLine.Text = ""
			end
		end)
	end)

	-- Cash count-up + blips off the Balance row -------------------------
	local shown = cashValue.Value
	local lastValue = cashValue.Value

	cashValue.Changed:Connect(function(value)
		local delta = value - lastValue
		lastValue = value
		if delta == 0 then
			return
		end
		local blip = Instance.new("TextLabel")
		blip.AnchorPoint = Vector2.new(1, 1)
		blip.Position = UDim2.new(1, -4, 0, -2)
		blip.Size = UDim2.new(0, 110, 0, 18)
		blip.BackgroundTransparency = 1
		blip.Font = Enum.Font.GothamBlack
		blip.TextScaled = true
		blip.TextXAlignment = Enum.TextXAlignment.Right
		blip.TextColor3 = delta > 0 and UIKit.GOOD or UIKit.BAD
		blip.TextStrokeTransparency = 0.5
		blip.Text = (delta > 0 and "+" or "-") .. Format.money(math.abs(delta))
		blip.Parent = balanceRow
		TweenService:Create(blip, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = blip.Position + UDim2.new(0, 0, 0, -24),
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
		if waiting > 0 then
			prisonersRight.Text = ("%d / %d  (+%d)"):format(housed, capacity, waiting)
			prisonersRight.TextColor3 = UIKit.WARN
		else
			prisonersRight.Text = ("%d / %d"):format(housed, capacity)
			prisonersRight.TextColor3 = UIKit.TEXT
		end

		local unrest = player:GetAttribute("PrisonUnrest") or 0
		local perMin = housed * Config.GrantPerPrisoner * (60 / Config.GrantInterval) * (1 - unrest / 200)
		infoRight.Text = ("%s/min · unrest %d%%"):format(Format.money(perMin), unrest)
		infoRight.TextColor3 = unrest >= 60 and UIKit.BAD or (unrest >= 30 and UIKit.WARN or UIKit.DIM)

		stuckLine.Text = player:GetAttribute("IntakeStuck") == true
			and "⚠ Arrivals can't reach a cell — is there a door path?" or ""
	end
	local function refreshClockSub()
		local day = player:GetAttribute("PrisonDay") or 1
		if player:GetAttribute("PrisonLockdown") == true then
			clockSub.Text = ("Day %d — LOCKDOWN"):format(day)
			clockSub.TextColor3 = UIKit.BAD
		else
			clockSub.Text = ("Day %d — %s"):format(day, player:GetAttribute("RegimeActivity") or "FreeTime")
			clockSub.TextColor3 = UIKit.DIM
		end
	end
	for _, attr in ipairs({ "PrisonHoused", "PrisonCapacity", "PrisonWaiting", "IntakeStuck", "PrisonUnrest" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshStats)
	end
	player:GetAttributeChangedSignal("PrisonDay"):Connect(refreshClockSub)
	player:GetAttributeChangedSignal("RegimeActivity"):Connect(refreshClockSub)
	player:GetAttributeChangedSignal("PrisonLockdown"):Connect(refreshClockSub)
	refreshStats()
	refreshClockSub()

	RunService.RenderStepped:Connect(function(dt)
		-- Smooth cash count-up.
		local target = cashValue.Value
		if shown ~= target then
			shown += (target - shown) * math.min(dt * 6, 1)
			if math.abs(target - shown) < 1 then
				shown = target
			end
			balanceRight.Text = Format.money(shown)
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
