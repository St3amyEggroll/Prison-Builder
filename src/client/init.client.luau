-- Lockdown client bootstrap. Runs on each player's own device and starts
-- what they personally see: build mode (the PA toolbar + top-down
-- camera), the PA HUD readouts, the intake popup (opened from the
-- Prisoners readout — that's the wiring below), the Staff tab, and NPC
-- animation.

require(script.BuildMode).start()
local IntakePanel = require(script.IntakePanel)
IntakePanel.start()
require(script.StaffPanel).start()
require(script.CashHud).start({ onPrisoners = IntakePanel.toggle })
require(script.InmateAnimator).start()
require(script.MoodDisplay).start()
