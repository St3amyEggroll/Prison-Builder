-- EmergencyPanel: PA's Emergencies tab — live as of Phase 5. Lockdown
-- toggles (confine everyone to cells, cool unrest, half grants); Roll
-- Call is a one-shot round-up on a cooldown. The contraband tools stay
-- listed but dim until that system exists. The tab wears a red alert dot
-- the whole time a lockdown is active.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local PAIcons = require(script.Parent.PAIcons)
local PAToolbar = require(script.Parent.PAToolbar)

local EmergencyPanel = {}

function EmergencyPanel.start()
	local player = Players.LocalPlayer
	local emergencyRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EmergencyRequest")

	local menu = PAToolbar.menu("emergencies", "Emergencies", 260)

	local lockdownRow = PAToolbar.row(menu.list, {
		order = 1,
		name = "Lockdown",
		right = "OFF",
		onClick = function()
			pcall(function()
				return emergencyRequest:InvokeServer("lockdown")
			end)
		end,
	})
	PAIcons.draw(lockdownRow.icon, "emergencies", UIKit.BAD, 4)
	lockdownRow.right.TextColor3 = UIKit.DIM

	local rollcallRow
	rollcallRow = PAToolbar.row(menu.list, {
		order = 2,
		name = "Roll Call",
		right = "",
		onClick = function()
			local ok, result = pcall(function()
				return emergencyRequest:InvokeServer("rollcall")
			end)
			if ok and result and not result.ok and result.err then
				rollcallRow.right.Text = result.err
				rollcallRow.right.TextColor3 = UIKit.WARN
				task.delay(2.5, function()
					rollcallRow.right.Text = ""
				end)
			end
		end,
	})
	PAIcons.draw(rollcallRow.icon, "deployment", UIKit.ICON, 4)
	rollcallRow.right.Size = UDim2.new(0, 120, 0, 18)

	-- Waiting on the contraband system.
	for i, entry in ipairs({
		{ name = "Shakedown", icon = "intelligence" },
		{ name = "Tunnel Search", icon = "utilities" },
	}) do
		local row = PAToolbar.row(menu.list, { order = 2 + i, name = entry.name, right = "soon" })
		row.name.TextColor3 = UIKit.DIM
		row.right.TextColor3 = UIKit.DIM
		PAIcons.draw(row.icon, entry.icon, UIKit.ICON_DARK, 4)
	end
	menu.fit()

	PAToolbar.addTab({
		id = "emergencies",
		icon = "emergencies",
		label = "Emergencies",
		order = 27,
		onClick = function()
			PAToolbar.toggleMenu("emergencies")
		end,
	})
	menu.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		PAToolbar.setPressed("emergencies", menu.panel.Visible)
	end)

	local function refresh()
		local on = player:GetAttribute("PrisonLockdown") == true
		lockdownRow.right.Text = on and "ON" or "OFF"
		lockdownRow.right.TextColor3 = on and UIKit.BAD or UIKit.DIM
		lockdownRow.setSelected(on)
		PAToolbar.setAlert("emergencies", on)
	end
	player:GetAttributeChangedSignal("PrisonLockdown"):Connect(refresh)
	refresh()
end

return EmergencyPanel
