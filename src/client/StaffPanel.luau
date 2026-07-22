-- StaffPanel: hire/fire Guards, Cooks, Janitors (PA's Staff tab). Lives in
-- the shared dock (UIKit) alongside Intake, so only one is open at a time
-- and nothing overlaps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

local StaffPanel = {}

function StaffPanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local staffRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StaffRequest")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownStaff"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	local rowH = 50
	local panel = UIKit.card(gui, "StaffPanel")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -82, 1, -12)
	panel.Size = UDim2.new(0, 310, 0, 44 + rowH * #Config.StaffTypes)
	UIKit.registerPanel(panel)

	local wageLabel = Instance.new("TextLabel")
	wageLabel.Position = UDim2.new(0, 14, 0, 10)
	wageLabel.Size = UDim2.new(1, -28, 0, 22)
	wageLabel.BackgroundTransparency = 1
	wageLabel.Font = Enum.Font.GothamBlack
	wageLabel.TextScaled = true
	wageLabel.TextXAlignment = Enum.TextXAlignment.Left
	wageLabel.TextColor3 = UIKit.WARN
	wageLabel.Parent = panel

	local countLabels = {}
	for i, def in ipairs(Config.StaffTypes) do
		local y = 40 + (i - 1) * rowH
		local info = Instance.new("TextLabel")
		info.Position = UDim2.new(0, 14, 0, y)
		info.Size = UDim2.new(0, 180, 0, rowH - 8)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextColor3 = UIKit.TEXT
		info.Parent = panel
		countLabels[def.id] = info

		local function actionButton(text, color, xoff, action)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, xoff, 0, y + (rowH - 8) / 2)
			b.Size = UDim2.new(0, 40, 0, 34)
			b.BackgroundColor3 = color
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 20
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Text = text
			UIKit.corner(b, 10)
			b.Activated:Connect(function()
				pcall(function()
					return staffRequest:InvokeServer(action, def.id)
				end)
			end)
			b.Parent = panel
		end
		actionButton("−", Color3.fromRGB(120, 50, 50), -14, "fire")
		actionButton("+", Color3.fromRGB(52, 120, 66), -60, "hire")
	end

	gui.Parent = playerGui

	local dockButton = UIKit.dockButton(playerGui, 3, "👮", "Staff", function()
		UIKit.showOnly(panel)
	end)

	local function refresh()
		local total = player:GetAttribute("StaffWage") or 0
		local unpaid = player:GetAttribute("StaffUnpaid") == true
		wageLabel.Text = ("Payroll %s / %ds%s"):format(Format.money(total), Config.WageInterval, unpaid and "  ⚠ UNPAID" or "")
		wageLabel.TextColor3 = unpaid and UIKit.BAD or UIKit.WARN
		for _, def in ipairs(Config.StaffTypes) do
			local n = player:GetAttribute("Staff_" .. def.id) or 0
			countLabels[def.id].Text = ("%s %s: %d  (%s ea)"):format(def.icon, def.id, n, Format.money(def.wage))
		end
		UIKit.setBadge(dockButton, unpaid and "!" or nil)
	end
	for _, def in ipairs(Config.StaffTypes) do
		player:GetAttributeChangedSignal("Staff_" .. def.id):Connect(refresh)
	end
	player:GetAttributeChangedSignal("StaffWage"):Connect(refresh)
	player:GetAttributeChangedSignal("StaffUnpaid"):Connect(refresh)
	refresh()
end

return StaffPanel
