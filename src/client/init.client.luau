-- Lockdown client bootstrap. Runs on each player's own device and starts
-- everything the player personally sees: the cash HUD, the floating
-- "+$" popups, and the little idle sway that brings inmates to life.

require(script.CashHud).start()
require(script.Popups).start()
require(script.InmateAnimator).start()
