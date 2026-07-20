-- Lockdown client bootstrap. Runs on each player's own device and starts
-- what they personally see: the build mode UI and the idle sway that
-- brings placed inmates to life.

require(script.BuildMode).start()
require(script.InmateAnimator).start()
