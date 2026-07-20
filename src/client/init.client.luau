-- Lockdown client bootstrap. Runs on each player's own device and starts
-- what they personally see: build mode (with the top-down camera), the
-- intake panel, and the inmate life animation.

require(script.BuildMode).start()
require(script.IntakePanel).start()
require(script.InmateAnimator).start()
