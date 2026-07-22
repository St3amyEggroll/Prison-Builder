-- Lockdown client bootstrap. Runs on each player's own device and starts
-- what they personally see: build mode (the PA toolbar + top-down
-- camera), the PA HUD readouts, the intake popup (opened from the
-- Prisoners readout), the Staff tab (which arms BuildMode's click-to-
-- place hiring — that's the `build` wiring below), the Emergencies tab,
-- and NPC animation.

local StarterGui = game:GetService("StarterGui")

-- PA has no floating player list — and Roblox's sat right on top of the
-- clock panel. (SetCoreGuiEnabled can fail while CoreGui boots; retry.)
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end)

local build = require(script.BuildMode).start()
local IntakePanel = require(script.IntakePanel)
IntakePanel.start()
require(script.StaffPanel).start(build)
require(script.EmergencyPanel).start()
require(script.CashHud).start({ onPrisoners = IntakePanel.toggle })
require(script.InmateAnimator).start()
require(script.MoodDisplay).start()
