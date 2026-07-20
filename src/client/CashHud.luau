-- CashHud: the on-screen money display, built entirely from code.
--   * Big cash counter, top-center, that smoothly counts up (juice!).
--   * An income line: "4 inmates · $8/sec".
--   * A hint bar at the bottom that doubles as the feedback line for
--     purchases ("Cell #3 built!" / "Need $120 more!").
-- Everything uses scale-friendly sizes and TextScaled so it reads fine
-- on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))

local CashHud = {}

local DEFAULT_HINT = "Walk onto the glowing green pad to buy a cell 🔑"

local function playBuiltInSound(fileName, volume)
	-- These sounds ship inside the Roblox engine itself — nothing to
	-- download, they can never go missing.
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/" .. fileName
	sound.Volume = volume
	SoundService:PlayLocalSound(sound)
	sound:Destroy()
end

function CashHud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")
	local inmatesValue = leaderstats:WaitForChild("Inmates")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownHUD"
	gui.ResetOnSpawn = false -- HUD survives respawns

	-- Cash panel -------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name = "CashPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 10)
	panel.Size = UDim2.new(0, 250, 0, 74)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.Size = UDim2.new(1, -16, 0, 44)
	cashLabel.Position = UDim2.new(0, 8, 0, 4)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = Enum.Font.GothamBlack
	cashLabel.TextScaled = true
	cashLabel.TextColor3 = Color3.fromRGB(140, 255, 150)
	cashLabel.Text = Format.money(cashValue.Value)
	cashLabel.Parent = panel

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.new(1, -16, 0, 20)
	incomeLabel.Position = UDim2.new(0, 8, 0, 48)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.Gotham
	incomeLabel.TextScaled = true
	incomeLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	incomeLabel.Parent = panel

	panel.Parent = gui

	-- Hint / feedback bar ---------------------------------------------
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -14)
	hint.Size = UDim2.new(0.9, 0, 0, 30)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(255, 255, 255)
	hint.TextStrokeTransparency = 0.4
	hint.Text = DEFAULT_HINT
	hint.Parent = gui

	gui.Parent = playerGui

	-- Smooth count-up: the shown number chases the real number every
	-- frame instead of teleporting. Cheap and very satisfying.
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

	local function refreshIncome()
		local n = inmatesValue.Value
		local perSec = n * Config.PayoutPerInmate / Config.PayoutInterval
		incomeLabel.Text = ("%d inmate%s · %s/sec"):format(n, n == 1 and "" or "s", Format.money(perSec))
	end
	refreshIncome()
	inmatesValue.Changed:Connect(refreshIncome)

	-- Purchase feedback ------------------------------------------------
	-- Each message bumps this counter; a message only clears itself if a
	-- newer one hasn't replaced it in the meantime.
	local messageId = 0
	local function flashHint(text, color)
		messageId += 1
		local id = messageId
		hint.Text = text
		hint.TextColor3 = color
		task.delay(2.5, function()
			if messageId == id then
				hint.Text = DEFAULT_HINT
				hint.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end)
	end

	local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PurchaseResult")
	purchaseRemote.OnClientEvent:Connect(function(success, info)
		if success then
			flashHint(
				("Cell #%d built — a new inmate moved in! 🔒"):format(info.cellIndex),
				Color3.fromRGB(140, 255, 150)
			)
			playBuiltInSound("electronicpingshort.wav", 0.6)
		elseif info.reason == "poor" then
			flashHint(
				("Need %s more for the next cell!"):format(Format.money(info.shortfall)),
				Color3.fromRGB(255, 120, 110)
			)
			playBuiltInSound("uuhhh.mp3", 0.4)
		elseif info.reason == "full" then
			flashHint("Your prison is full — max cells reached! 🏆", Color3.fromRGB(255, 215, 120))
		end
	end)
end

return CashHud
