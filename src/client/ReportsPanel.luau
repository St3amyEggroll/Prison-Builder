-- ReportsPanel: PA's Reports window — the warden's numbers in one place.
-- Population, finance and security stats on the left; live bars for the
-- prison-wide average of every need on the right (fed by the NeedAvg_*
-- attributes NeedsService publishes). Opens from its own toolbar tab,
-- centered like PA's report screen, coordinated by UIKit so it never
-- overlaps another menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)
local PAToolbar = require(script.Parent.PAToolbar)

local ReportsPanel = {}

local NEEDS = { "food", "sleep", "hygiene", "recreation", "safety" }

function ReportsPanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownReports"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7

	local panel = UIKit.panel(gui, "ReportsPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, -20)
	panel.Size = UDim2.new(0, 470, 0, 336)
	UIKit.titleBar(panel, "Reports")
	UIKit.registerPanel(panel)
	panel.Parent = gui

	local function header(x, y, w, text)
		local label = Instance.new("TextLabel")
		label.Position = UDim2.new(0, x, 0, y)
		label.Size = UDim2.new(0, w, 0, 16)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = UIKit.EDGE
		label.Text = string.upper(text)
		label.Parent = panel
	end

	local function statLine(x, y, w, name)
		local left = Instance.new("TextLabel")
		left.Position = UDim2.new(0, x, 0, y)
		left.Size = UDim2.new(0, w - 80, 0, 18)
		left.BackgroundTransparency = 1
		left.Font = Enum.Font.GothamMedium
		left.TextSize = 12
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.TextColor3 = UIKit.DIM
		left.Text = name
		left.Parent = panel
		local value = Instance.new("TextLabel")
		value.Position = UDim2.new(0, x + w - 96, 0, y)
		value.Size = UDim2.new(0, 96, 0, 18)
		value.BackgroundTransparency = 1
		value.Font = Enum.Font.GothamBold
		value.TextSize = 13
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = UIKit.TEXT
		value.Text = "—"
		value.Parent = panel
		return value
	end

	-- Left column ------------------------------------------------------
	local LX, LW = 16, 210
	header(LX, 36, LW, "Population")
	local housedValue = statLine(LX, 56, LW, "Housed")
	local gateValue = statLine(LX, 76, LW, "At the gate")
	local escapesValue = statLine(LX, 96, LW, "Escapes")
	local riotsValue = statLine(LX, 116, LW, "Riots")

	header(LX, 146, LW, "Finance")
	local balanceValue = statLine(LX, 166, LW, "Balance")
	local grantsValue = statLine(LX, 186, LW, "Grants")
	local payrollValue = statLine(LX, 206, LW, "Payroll")

	header(LX, 236, LW, "Security")
	local unrestValue = statLine(LX, 256, LW, "Unrest")
	local guardsValue = statLine(LX, 276, LW, "Guards")
	local statusValue = statLine(LX, 296, LW, "Status")

	-- Right column: the need bars --------------------------------------
	local RX, RW = 252, 202
	header(RX, 36, RW, "Prisoner needs (average)")
	local needBars = {}
	for i, need in ipairs(NEEDS) do
		local y = 60 + (i - 1) * 50
		local name = Instance.new("TextLabel")
		name.Position = UDim2.new(0, RX, 0, y)
		name.Size = UDim2.new(0, RW - 44, 0, 16)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = UIKit.DIM
		name.Text = need:sub(1, 1):upper() .. need:sub(2)
		name.Parent = panel

		local pct = Instance.new("TextLabel")
		pct.Position = UDim2.new(0, RX + RW - 40, 0, y)
		pct.Size = UDim2.new(0, 40, 0, 16)
		pct.BackgroundTransparency = 1
		pct.Font = Enum.Font.GothamBold
		pct.TextSize = 12
		pct.TextXAlignment = Enum.TextXAlignment.Right
		pct.TextColor3 = UIKit.TEXT
		pct.Text = "—"
		pct.Parent = panel

		local track = Instance.new("Frame")
		track.Position = UDim2.new(0, RX, 0, y + 20)
		track.Size = UDim2.new(0, RW, 0, 10)
		track.BackgroundColor3 = UIKit.STRIP
		track.BorderSizePixel = 0
		UIKit.stroke(track, UIKit.EDGE_DIM, 1, 0)
		track.Parent = panel

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = UIKit.GOOD
		fill.BorderSizePixel = 0
		fill.Parent = track

		needBars[need] = { fill = fill, pct = pct }
	end

	gui.Parent = playerGui

	-- Refresh ----------------------------------------------------------
	local function refresh()
		if not panel.Visible then
			return
		end
		local housed = player:GetAttribute("PrisonHoused") or 0
		local capacity = player:GetAttribute("PrisonCapacity") or 0
		housedValue.Text = ("%d / %d"):format(housed, capacity)
		gateValue.Text = tostring(player:GetAttribute("PrisonWaiting") or 0)
		escapesValue.Text = tostring(player:GetAttribute("PrisonEscapes") or 0)
		riotsValue.Text = tostring(player:GetAttribute("PrisonRiots") or 0)

		local unrest = player:GetAttribute("PrisonUnrest") or 0
		balanceValue.Text = Format.money(cashValue.Value)
		local perMin = housed * Config.GrantPerPrisoner * (60 / Config.GrantInterval) * (1 - unrest / 200)
		grantsValue.Text = Format.money(perMin) .. "/min"
		payrollValue.Text = ("%s / %ds"):format(
			Format.money(player:GetAttribute("StaffWage") or 0), Config.WageInterval)

		unrestValue.Text = unrest .. "%"
		unrestValue.TextColor3 = unrest >= 60 and UIKit.BAD or (unrest >= 30 and UIKit.WARN or UIKit.TEXT)
		guardsValue.Text = tostring(player:GetAttribute("Staff_Guard") or 0)
		if player:GetAttribute("PrisonRiot") == true then
			statusValue.Text = "RIOT!"
			statusValue.TextColor3 = UIKit.BAD
		elseif player:GetAttribute("PrisonLockdown") == true then
			statusValue.Text = "Lockdown"
			statusValue.TextColor3 = UIKit.WARN
		else
			statusValue.Text = "Calm"
			statusValue.TextColor3 = UIKit.GOOD
		end

		for need, bar in pairs(needBars) do
			local value = player:GetAttribute("NeedAvg_" .. need)
			if type(value) ~= "number" then
				value = 100
			end
			bar.pct.Text = value .. "%"
			bar.fill.Size = UDim2.new(value / 100, 0, 1, 0)
			bar.fill.BackgroundColor3 = value < 25 and UIKit.BAD or (value < 50 and UIKit.WARN or UIKit.GOOD)
		end
	end

	for _, attr in ipairs({
		"PrisonHoused", "PrisonCapacity", "PrisonWaiting", "PrisonEscapes", "PrisonRiots",
		"PrisonUnrest", "PrisonLockdown", "PrisonRiot", "StaffWage", "Staff_Guard",
		"NeedAvg_food", "NeedAvg_sleep", "NeedAvg_hygiene", "NeedAvg_recreation", "NeedAvg_safety",
	}) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	cashValue.Changed:Connect(refresh)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		PAToolbar.setPressed("reports", panel.Visible)
		refresh()
	end)

	PAToolbar.addTab({
		id = "reports",
		icon = "reports",
		label = "Reports",
		order = 13,
		onClick = function()
			UIKit.showOnly(panel)
		end,
	})
end

return ReportsPanel
