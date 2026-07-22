-- Lockdown client bootstrap. Runs on each player's own device and starts
-- what they personally see: build mode (with the top-down camera), the
-- cash HUD, the objective card, the intake panel, and NPC animation.

require(script.BuildMode).start()
require(script.CashHud).start()
require(script.IntakePanel).start()
require(script.InmateAnimator).start()
