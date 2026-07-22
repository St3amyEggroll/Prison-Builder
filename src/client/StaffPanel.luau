-- StaffPanel: PA's Staff tab, living in the toolbar like the original.
-- Its menu lists each staff type as a PA row — click a row to pick that
-- hire up, then CLICK THEM DOWN wherever you want them (BuildMode's
-- staff-placement mode handles the ghost and the click). The − lets one
-- go, the payroll footer shows the running wage bill, and the tab grows
-- a red alert dot the moment payroll is missed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)
local PAIcons = require(script.Parent.PAIcons)
local PAToolbar = require(script.Parent.PAToolbar)

local StaffPanel = {}

-- Icon tints so the trades read apart at a glance.
local TINTS = {
	Workman = Color3.fromRGB(255, 205, 105),
	Guard = Color3.fromRGB(126, 156, 224),
	Cook = Color3.fromRGB(236, 236, 236),
	Janitor = Color3.fromRGB(120, 196, 140),
}

-- `build` is BuildMode's controller (wired in the client bootstrap).
function StaffPanel.start(build)
	local player = Players.LocalPlayer
	local staffRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StaffRequest")

	local menu = PAToolbar.menu("staff", "Staff", 260)
	local rows = {}
	for i, def in ipairs(Config.StaffTypes) do
		local handle = PAToolbar.row(menu.list, {
			order = i,
			name = def.id,
			right = Format.money(def.wage),
			onClick = function()
				build.placeStaff({ id = def.id, tint = TINTS[def.id] })
			end,
		})
		PAIcons.draw(handle.icon, "staff", TINTS[def.id] or UIKit.ICON, 2)

		-- The little − lets one go (the row itself hires).
		local fire = Instance.new("TextButton")
		fire.AnchorPoint = Vector2.new(1, 0.5)
		fire.Position = UDim2.new(1, -80, 0.5, 0)
		fire.Size = UDim2.new(0, 22, 0, 22)
		fire.BackgroundColor3 = UIKit.PANEL
		fire.BorderSizePixel = 0
		fire.AutoButtonColor = true
		fire.Font = Enum.Font.GothamBold
		fire.TextSize = 16
		fire.TextColor3 = UIKit.BAD
		fire.Text = "−"
		UIKit.stroke(fire, UIKit.EDGE_DIM, 1, 0)
		fire.Activated:Connect(function()
			pcall(function()
				return staffRequest:InvokeServer("fire", def.id)
			end)
		end)
		fire.Parent = handle.button
		rows[def.id] = handle
	end

	-- Payroll footer under the rows.
	local payroll = Instance.new("TextLabel")
	payroll.LayoutOrder = 99
	payroll.Size = UDim2.new(1, -8, 0, 22)
	payroll.BackgroundTransparency = 1
	payroll.Font = Enum.Font.GothamMedium
	payroll.TextSize = 12
	payroll.TextXAlignment = Enum.TextXAlignment.Left
	payroll.TextColor3 = UIKit.DIM
	payroll.Text = ""
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = payroll
	payroll.Parent = menu.list
	menu.fit()

	PAToolbar.addTab({
		id = "staff",
		icon = "staff",
		label = "Staff",
		order = 12,
		onClick = function()
			PAToolbar.toggleMenu("staff")
		end,
	})
	-- Stay lit exactly while the menu shows (however it gets closed).
	menu.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		PAToolbar.setPressed("staff", menu.panel.Visible)
	end)

	local function refresh()
		local total = player:GetAttribute("StaffWage") or 0
		local unpaid = player:GetAttribute("StaffUnpaid") == true
		payroll.Text = ("Payroll %s / %ds%s"):format(
			Format.money(total), Config.WageInterval, unpaid and " — UNPAID!" or "")
		payroll.TextColor3 = unpaid and UIKit.BAD or UIKit.DIM
		for _, def in ipairs(Config.StaffTypes) do
			local n = player:GetAttribute("Staff_" .. def.id) or 0
			rows[def.id].name.Text = n > 0 and ("%s  ×%d"):format(def.id, n) or def.id
		end
		PAToolbar.setAlert("staff", unpaid)
	end
	for _, def in ipairs(Config.StaffTypes) do
		player:GetAttributeChangedSignal("Staff_" .. def.id):Connect(refresh)
	end
	player:GetAttributeChangedSignal("StaffWage"):Connect(refresh)
	player:GetAttributeChangedSignal("StaffUnpaid"):Connect(refresh)
	refresh()
end

return StaffPanel
