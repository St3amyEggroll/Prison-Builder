-- IntakePanel: the warden's version of Prison Architect's Intake report.
-- A 🚔 button opens a small panel showing the population, with a button
-- to accept one prisoner and a toggle for auto-intake (fill capacity).
-- The numbers update live from attributes the server sets on the Player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IntakePanel = {}

local PANEL_BG = Color3.fromRGB(20, 24, 20)
local GREEN = Color3.fromRGB(140, 255, 150)
local RED = Color3.fromRGB(255, 120, 110)

function IntakePanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local intakeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("IntakeRequest")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownIntake"
	gui.ResetOnSpawn = false

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -14, 1, -70)
	toggle.Size = UDim2.new(0, 120, 0, 48)
	toggle.BackgroundColor3 = PANEL_BG
	toggle.BackgroundTransparency = 0.2
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 20
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Text = "🚔 Intake"
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -14, 1, -126)
	panel.Size = UDim2.new(0, 230, 0, 170)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel
	panel.Parent = gui

	local function makeLabel(y)
		local label = Instance.new("TextLabel")
		label.Position = UDim2.new(0, 12, 0, y)
		label.Size = UDim2.new(1, -24, 0, 22)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Parent = panel
		return label
	end

	local housedLabel = makeLabel(10)
	local waitingLabel = makeLabel(36)
	local statusLabel = makeLabel(62)
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	local acceptButton = Instance.new("TextButton")
	acceptButton.Position = UDim2.new(0, 12, 0, 90)
	acceptButton.Size = UDim2.new(1, -24, 0, 34)
	acceptButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
	acceptButton.Font = Enum.Font.GothamBold
	acceptButton.TextSize = 17
	acceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	acceptButton.Text = "➕ Accept prisoner"
	local acceptCorner = Instance.new("UICorner")
	acceptCorner.CornerRadius = UDim.new(0, 10)
	acceptCorner.Parent = acceptButton
	acceptButton.Parent = panel

	local autoButton = Instance.new("TextButton")
	autoButton.Position = UDim2.new(0, 12, 0, 130)
	autoButton.Size = UDim2.new(1, -24, 0, 30)
	autoButton.BackgroundColor3 = Color3.fromRGB(45, 52, 45)
	autoButton.Font = Enum.Font.GothamBold
	autoButton.TextSize = 15
	autoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoButton.Text = "Auto-intake: …"
	local autoCorner = Instance.new("UICorner")
	autoCorner.CornerRadius = UDim.new(0, 10)
	autoCorner.Parent = autoButton
	autoButton.Parent = panel

	gui.Parent = playerGui

	local statusId = 0
	local function flashStatus(text, color)
		statusId += 1
		local id = statusId
		statusLabel.Text = text
		statusLabel.TextColor3 = color
		task.delay(3, function()
			if statusId == id then
				statusLabel.Text = ""
			end
		end)
	end

	local function refresh()
		local housed = player:GetAttribute("PrisonHoused") or 0
		local capacity = player:GetAttribute("PrisonCapacity") or 0
		local waiting = player:GetAttribute("PrisonWaiting") or 0
		local auto = player:GetAttribute("AutoIntake")
		housedLabel.Text = ("🔒 Housed: %d / %d"):format(housed, capacity)
		waitingLabel.Text = ("⛓️ At the gate: %d"):format(waiting)
		waitingLabel.TextColor3 = waiting > 0 and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(255, 255, 255)
		-- Badge on the button so a queue at the gate is visible at a glance.
		toggle.Text = waiting > 0 and ("🚔 Intake (%d)"):format(waiting) or "🚔 Intake"
		toggle.TextColor3 = waiting > 0 and Color3.fromRGB(255, 210, 130) or Color3.fromRGB(255, 255, 255)
		autoButton.Text = auto and "Auto-intake: ON" or "Auto-intake: OFF"
		autoButton.BackgroundColor3 = auto and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 52, 45)
	end

	for _, attr in ipairs({ "PrisonHoused", "PrisonCapacity", "PrisonWaiting", "AutoIntake" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	acceptButton.Activated:Connect(function()
		local ok, result = pcall(function()
			return intakeRequest:InvokeServer("accept")
		end)
		if ok and result and result.ok then
			flashStatus("New prisoner at the gate!", GREEN)
		elseif ok and result then
			flashStatus(result.err or "Couldn't accept.", RED)
		end
	end)

	autoButton.Activated:Connect(function()
		pcall(function()
			return intakeRequest:InvokeServer("toggleAuto")
		end)
	end)
end

return IntakePanel
