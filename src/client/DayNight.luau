-- DayNight: the shared prison clock made visible. Lighting follows the
-- same ClockEpoch every HUD clock derives from, so 06:00 on the top-right
-- clock IS sunrise and the Sleep regime really happens in the dark. One
-- full day-night cycle = Config.DayLength real seconds (10 minutes by
-- default), identical for every player on the server — time is shared.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DayNight = {}

function DayNight.start()
	RunService.Heartbeat:Connect(function()
		local epoch = workspace:GetAttribute("ClockEpoch")
		if not epoch then
			return
		end
		local frac = ((workspace:GetServerTimeNow() - epoch) % Config.DayLength) / Config.DayLength
		Lighting.ClockTime = frac * 24
	end)
end

return DayNight
