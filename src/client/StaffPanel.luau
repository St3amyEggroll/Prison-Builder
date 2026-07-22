-- StaffPanel: the 👮 Staff hire/fire panel (PA's Staff tab). A button
-- stack in the bottom-right opens a card with a row per staff type —
-- icon, name, live count, wage, and Hire / Fire buttons. Reads the
-- Staff_<Type> and StaffWage attributes the server publishes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))

local StaffPanel = {}

local PANEL_BG = Color3.fromRGB(20, 24, 20)
local RED = Color3.fromRGB(255, 120, 110)

function StaffPanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local staffRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StaffRequest")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownStaff"
	gui.ResetOnSpawn = false

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -14, 1, -126)
	toggle.Size = UDim2.new(0, 120, 0, 48)
	toggle.BackgroundColor3 = PANEL_BG
	toggle.BackgroundTransparency = 0.2
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 20
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Text = "👮 Staff"
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggle.Parent = gui

	local rowH = 52
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -14, 1, -182)
	panel.Size = UDim2.new(0, 300, 0, 40 + rowH * #Config.StaffTypes)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel

	local wageLabel = Instance.new("TextLabel")
	wageLabel.Position = UDim2.new(0, 12, 0, 8)
	wageLabel.Size = UDim2.new(1, -24, 0, 22)
	wageLabel.BackgroundTransparency = 1
	wageLabel.Font = Enum.Font.GothamBold
	wageLabel.TextScaled = true
	wageLabel.TextXAlignment = Enum.TextXAlignment.Left
	wageLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
	wageLabel.Parent = panel

	local countLabels = {}
	for i, def in ipairs(Config.StaffTypes) do
		local y = 36 + (i - 1) * rowH
		local info = Instance.new("TextLabel")
		info.Position = UDim2.new(0, 12, 0, y)
		info.Size = UDim2.new(0, 170, 0, rowH - 8)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextColor3 = Color3.fromRGB(255, 255, 255)
		info.Parent = panel
		countLabels[def.id] = info

		local function actionButton(text, color, xoff, action)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, xoff, 0, y + (rowH - 8) / 2)
			b.Size = UDim2.new(0, 44, 0, 36)
			b.BackgroundColor3 = color
			b.Font = Enum.Font.GothamBold
			b.TextSize = 18
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Text = text
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 10)
			c.Parent = b
			b.Activated:Connect(function()
				pcall(function()
					return staffRequest:InvokeServer(action, def.id)
				end)
			end)
			b.Parent = panel
		end
		actionButton("−", Color3.fromRGB(120, 50, 50), -14, "fire")
		actionButton("+", Color3.fromRGB(60, 110, 60), -62, "hire")
	end

	panel.Parent = gui
	gui.Parent = playerGui

	local function refresh()
		local total = player:GetAttribute("StaffWage") or 0
		local unpaid = player:GetAttribute("StaffUnpaid") == true
		wageLabel.Text = ("Payroll: %s / %ds%s"):format(Format.money(total), Config.WageInterval, unpaid and "  ⚠ UNPAID" or "")
		wageLabel.TextColor3 = unpaid and RED or Color3.fromRGB(255, 220, 130)
		for _, def in ipairs(Config.StaffTypes) do
			local n = player:GetAttribute("Staff_" .. def.id) or 0
			countLabels[def.id].Text = ("%s %s: %d  (%s ea)"):format(def.icon, def.id, n, Format.money(def.wage))
		end
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	for _, def in ipairs(Config.StaffTypes) do
		player:GetAttributeChangedSignal("Staff_" .. def.id):Connect(refresh)
	end
	player:GetAttributeChangedSignal("StaffWage"):Connect(refresh)
	player:GetAttributeChangedSignal("StaffUnpaid"):Connect(refresh)
	refresh()
end

return StaffPanel
