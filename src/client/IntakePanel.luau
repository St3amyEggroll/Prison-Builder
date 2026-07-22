-- IntakePanel: the warden's intake report — accept prisoners and toggle
-- auto-intake. Lives in the shared dock (UIKit) so it can't overlap the
-- other menus, and its dock button shows a badge when prisoners queue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)

local IntakePanel = {}

function IntakePanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local intakeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("IntakeRequest")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownIntake"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	local panel = UIKit.card(gui, "IntakePanel")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -82, 1, -12)
	panel.Size = UDim2.new(0, 250, 0, 176)
	UIKit.registerPanel(panel)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 14, 0, 10)
	title.Size = UDim2.new(1, -28, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UIKit.WARN
	title.Text = "🚔 INTAKE"
	title.Parent = panel

	local function label(y, color)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(0, 14, 0, y)
		l.Size = UDim2.new(1, -28, 0, 20)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color or UIKit.TEXT
		l.Parent = panel
		return l
	end
	local housedLabel = label(36)
	local waitingLabel = label(60)
	local statusLabel = label(84, UIKit.DIM)

	local function bigButton(y, color, text)
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, 14, 0, y)
		b.Size = UDim2.new(1, -28, 0, 32)
		b.BackgroundColor3 = color
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = text
		UIKit.corner(b, 10)
		b.Parent = panel
		return b
	end
	local acceptButton = bigButton(108, Color3.fromRGB(52, 120, 66), "➕ Accept prisoner")
	local autoButton = bigButton(144, UIKit.BG2, "Auto-intake: …")

	gui.Parent = playerGui

	local dockButton = UIKit.dockButton(playerGui, 2, "🚔", "Intake", function()
		UIKit.showOnly(panel)
	end)

	local statusId = 0
	local function flash(text, color)
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
		waitingLabel.TextColor3 = waiting > 0 and UIKit.WARN or UIKit.TEXT
		autoButton.Text = auto and "Auto-intake: ON" or "Auto-intake: OFF"
		autoButton.BackgroundColor3 = auto and Color3.fromRGB(52, 120, 66) or UIKit.BG2
		UIKit.setBadge(dockButton, waiting > 0 and tostring(waiting) or nil)
	end
	for _, attr in ipairs({ "PrisonHoused", "PrisonCapacity", "PrisonWaiting", "AutoIntake" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()

	acceptButton.Activated:Connect(function()
		local ok, result = pcall(function()
			return intakeRequest:InvokeServer("accept")
		end)
		if ok and result and result.ok then
			flash("New prisoner at the gate!", UIKit.GOOD)
		elseif ok and result then
			flash(result.err or "Couldn't accept.", UIKit.BAD)
		end
	end)
	autoButton.Activated:Connect(function()
		pcall(function()
			return intakeRequest:InvokeServer("toggleAuto")
		end)
	end)
end

return IntakePanel
