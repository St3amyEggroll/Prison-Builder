-- IntakePanel: the warden's intake report — accept prisoners by hand or
-- flip on auto-intake. It's the popup behind the Prisoners readout in
-- the bottom-right corner (CashHud wires the click through the client
-- bootstrap), styled as a PA panel and coordinated by UIKit so it never
-- overlaps another menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)

local IntakePanel = {}

local panel = nil

-- CashHud's Prisoners row calls this.
function IntakePanel.toggle()
	if panel then
		UIKit.showOnly(panel)
	end
end

function IntakePanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local intakeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("IntakeRequest")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownIntake"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	panel = UIKit.panel(gui, "IntakePanel")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -12, 1, -104)
	panel.Size = UDim2.new(0, 232, 0, 168)
	UIKit.titleBar(panel, "Intake")
	UIKit.registerPanel(panel)

	local function label(y, color)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(0, 10, 0, y)
		l.Size = UDim2.new(1, -20, 0, 18)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 13
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color or UIKit.TEXT
		l.Parent = panel
		return l
	end
	local housedLabel = label(32)
	local waitingLabel = label(52)
	local statusLabel = label(72, UIKit.DIM)

	local function paButton(y, text)
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, 10, 0, y)
		b.Size = UDim2.new(1, -20, 0, 26)
		b.BackgroundColor3 = UIKit.BTN
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = UIKit.TEXT
		b.Text = text
		UIKit.stroke(b, UIKit.EDGE, 1, 0.35)
		b.Parent = panel
		return b
	end
	local acceptButton = paButton(96, "Accept Prisoner")
	local autoButton = paButton(128, "Auto-Intake: …")

	gui.Parent = playerGui

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
		housedLabel.Text = ("Housed: %d / %d"):format(housed, capacity)
		waitingLabel.Text = ("At the gate: %d"):format(waiting)
		waitingLabel.TextColor3 = waiting > 0 and UIKit.WARN or UIKit.TEXT
		autoButton.Text = auto and "Auto-Intake: ON" or "Auto-Intake: OFF"
		autoButton.BackgroundColor3 = auto and UIKit.BTN_ON or UIKit.BTN
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
