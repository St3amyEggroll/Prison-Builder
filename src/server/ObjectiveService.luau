-- ObjectiveService: PA-style starter grants, simplified into a sequential
-- chain. One objective is active at a time; completing it pays out and
-- advances to the next. Progress cloud-saves.
--
-- Two objective kinds (defined in Config.Objectives):
--   counter -> other systems report events ("wall_built", "granted"...)
--   attr    -> watches a published player attribute (PrisonHoused, ...)
--
-- The client panel reads everything from player attributes: ObjText,
-- ObjProgress, ObjTarget, ObjReward, ObjDone (all finished).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SaveService = require(script.Parent.SaveService)
local EconomyService = require(script.Parent.EconomyService)

local ObjectiveService = {}

local states = {} -- player -> { index, progress, st }

local function publish(player)
	local state = states[player]
	if not state then
		return
	end
	local objective = Config.Objectives[state.index]
	if not objective then
		player:SetAttribute("ObjText", nil)
		player:SetAttribute("ObjDone", true)
		return
	end
	player:SetAttribute("ObjText", objective.text)
	player:SetAttribute("ObjProgress", math.min(state.progress, objective.target))
	player:SetAttribute("ObjTarget", objective.target)
	player:SetAttribute("ObjReward", objective.reward)
	player:SetAttribute("ObjDone", false)
end

local function checkComplete(player)
	local state = states[player]
	if not state then
		return
	end
	local objective = Config.Objectives[state.index]
	while objective and state.progress >= objective.target do
		EconomyService.credit(player, objective.reward)
		state.index += 1
		state.progress = 0
		-- Persist through SaveService's state table.
		state.st.objectives = { i = state.index, p = 0 }
		objective = Config.Objectives[state.index]
	end
	publish(player)
end

-- Counter-kind progress, reported by the other systems.
function ObjectiveService.notify(player, event, amount)
	local state = states[player]
	if not state then
		return
	end
	local objective = Config.Objectives[state.index]
	if objective and objective.kind == "counter" and objective.event == event then
		state.progress += amount or 1
		state.st.objectives = { i = state.index, p = state.progress }
		checkComplete(player)
	end
end

local function onPlayerAdded(player)
	local st = SaveService.waitForData(player)
	if not st or not player:IsDescendantOf(game) then
		return
	end
	local saved = type(st.objectives) == "table" and st.objectives or {}
	states[player] = {
		index = math.clamp(math.floor(tonumber(saved.i) or 1), 1, #Config.Objectives + 1),
		progress = math.max(0, math.floor(tonumber(saved.p) or 0)),
		st = st,
	}
	publish(player)
end

function ObjectiveService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- Grant income feeds the "earn $X" objective.
	EconomyService.onGranted(function(player, amount)
		ObjectiveService.notify(player, "granted", amount)
	end)

	-- Attr-kind objectives poll their published stat.
	task.spawn(function()
		while true do
			task.wait(2)
			for player, state in pairs(states) do
				local objective = Config.Objectives[state.index]
				if objective and objective.kind == "attr" then
					local value = player:GetAttribute(objective.attr)
					if type(value) == "number" and value ~= state.progress then
						state.progress = value
						checkComplete(player)
					end
				end
			end
		end
	end)
end

return ObjectiveService
