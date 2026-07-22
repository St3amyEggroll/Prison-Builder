-- TimeService: the game clock. One shared time-of-day for the whole
-- server (clients compute it from a single epoch attribute — zero
-- network traffic), plus a per-player DAY counter: how many in-game
-- days their prison has existed, accumulated across sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SaveService = require(script.Parent.SaveService)

local TimeService = {}

local TICK = 15 -- seconds between day-counter updates

function TimeService.init()
	-- Clients derive the clock: (now - epoch) % DayLength -> time of day.
	workspace:SetAttribute("ClockEpoch", workspace:GetServerTimeNow())

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local st = SaveService.waitForData(player)
				if st then
					st.playedSeconds += TICK
					player:SetAttribute("PrisonDay", math.floor(st.playedSeconds / Config.DayLength) + 1)
				end
			end
		end
	end)
end

return TimeService
