-- CashHud: the money display, back from the dead for Phase 3.
--   * Top-center cash counter with a smooth count-up.
--   * Little "+$120 / -$40" blips floating off it on every change.
--   * The mini cashflow report: income per minute from housed prisoners,
--     plus what this session has earned and spent.
--   * A warning line when handcuffed arrivals can't reach any cell.
-- Reads leaderstats.Cash and the attributes the server publishes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))

local CashHud = {}

function CashHud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownCash"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.new(0, 240, 0, 66)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
	panel.BackgroundTransparency = 0.25
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.new(1, -16, 0, 34)
	cashLabel.Position = UDim2.new(0, 8, 0, 4)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = Enum.Font.GothamBlack
	cashLabel.TextScaled = true
	cashLabel.TextColor3 = Color3.fromRGB(140, 255, 150)
	cashLabel.Text = Format.money(cashValue.Value)
	cashLabel.Parent = panel

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.new(1, -16, 0, 14)
	incomeLabel.Position = UDim2.new(0, 8, 0, 38)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextScaled = true
	incomeLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	incomeLabel.Parent = panel

	local sessionLabel = Instance.new("TextLabel")
	sessionLabel.Size = UDim2.new(1, -16, 0, 12)
	sessionLabel.Position = UDim2.new(0, 8, 0, 52)
	sessionLabel.BackgroundTransparency = 1
	sessionLabel.Font = Enum.Font.Gotham
	sessionLabel.TextScaled = true
	sessionLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
	sessionLabel.Text = ""
	sessionLabel.Parent = panel

	local stuckLabel = Instance.new("TextLabel")
	stuckLabel.AnchorPoint = Vector2.new(0.5, 0)
	stuckLabel.Position = UDim2.new(0.5, 0, 1, 4)
	stuckLabel.Size = UDim2.new(0, 340, 0, 20)
	stuckLabel.BackgroundTransparency = 1
	stuckLabel.Font = Enum.Font.GothamBold
	stuckLabel.TextScaled = true
	stuckLabel.TextColor3 = Color3.fromRGB(255, 170, 110)
	stuckLabel.TextStrokeTransparency = 0.5
	stuckLabel.Text = ""
	stuckLabel.Parent = panel

	panel.Parent = gui
	gui.Parent = playerGui

	-- Smooth count-up toward the real value.
	local shown = cashValue.Value
	RunService.RenderStepped:Connect(function(dt)
		local target = cashValue.Value
		if shown ~= target then
			shown += (target - shown) * math.min(dt * 6, 1)
			if math.abs(target - shown) < 1 then
				shown = target
			end
			cashLabel.Text = Format.money(shown)
		end
	end)

	-- Delta blips + the session tally.
	local earned, spent = 0, 0
	local lastValue = cashValue.Value
	local function refreshSession()
		sessionLabel.Text = ("session: +%s · -%s"):format(Format.money(earned), Format.money(spent))
	end
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
		refreshSession()

		local blip = Instance.new("TextLabel")
		blip.AnchorPoint = Vector2.new(0.5, 0)
		blip.Position = UDim2.new(0.5, math.random(-40, 40), 0, 40)
		blip.Size = UDim2.new(0, 120, 0, 22)
		blip.BackgroundTransparency = 1
		blip.Font = Enum.Font.GothamBlack
		blip.TextScaled = true
		blip.TextColor3 = delta > 0 and Color3.fromRGB(140, 255, 150) or Color3.fromRGB(255, 130, 120)
		blip.TextStrokeTransparency = 0.5
		blip.Text = (delta > 0 and "+" or "-") .. Format.money(math.abs(delta))
		blip.Parent = panel
		TweenService:Create(blip, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = blip.Position + UDim2.new(0, 0, 0, 34),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.3, function()
			blip:Destroy()
		end)
	end)
	refreshSession()

	-- Income line + gate warning, from published attributes.
	local function refreshIncome()
		local housed = player:GetAttribute("PrisonHoused") or 0
		local perMin = housed * Config.GrantPerPrisoner * (60 / Config.GrantInterval)
		incomeLabel.Text = ("%d prisoner%s · %s/min in grants"):format(
			housed, housed == 1 and "" or "s", Format.money(perMin))
	end
	local function refreshStuck()
		if player:GetAttribute("IntakeStuck") == true then
			stuckLabel.Text = "⚠ Arrivals can't reach a cell — is there a door path?"
		else
			stuckLabel.Text = ""
		end
	end
	player:GetAttributeChangedSignal("PrisonHoused"):Connect(refreshIncome)
	player:GetAttributeChangedSignal("IntakeStuck"):Connect(refreshStuck)
	refreshIncome()
	refreshStuck()
end

return CashHud
