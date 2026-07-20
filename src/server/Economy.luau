-- Economy: the heartbeat of the money loop. Every few seconds, each
-- inmate pays their daily grant (well — five-secondly grant) to the
-- warden holding them. The client gets a Popup event so a satisfying
-- "+$40" floats up over the buy pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SaveService = require(script.Parent.SaveService)
local PlotService = require(script.Parent.PlotService)

local Economy = {}

function Economy.init()
	local popupRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Popup")

	task.spawn(function()
		while true do
			task.wait(Config.PayoutInterval)
			PlotService.eachOwnedPlot(function(player, plot)
				if plot.cellCount <= 0 then
					return
				end
				local amount = plot.cellCount * Config.PayoutPerInmate
				SaveService.addCash(player, amount)
				-- Only the owner sees their own popup — no screen spam
				-- from five other prisons paying out at once.
				popupRemote:FireClient(player, plot.pad.Position + Vector3.new(0, 4, 0), amount)
			end)
		end
	end)
end

return Economy
