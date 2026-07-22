-- SaveService: cloud-saves each player's prison layout so it's rebuilt
-- exactly as they left it. (Cash returns here when the economy phase is
-- wired back in — the save format already has room for it.)
--
-- Safety rules this file enforces:
--   * If loading a save fails, the player still gets to play — but we
--     REFUSE to save over their cloud data that session. A network
--     hiccup must never wipe someone's prison.
--   * Saves happen when a player leaves, every 60 seconds, and when the
--     server shuts down.
--
-- Studio note: saving works after publishing with "Studio Access to API
-- Services" enabled (SETUP.md). Until then everything plays fine, the
-- layout just resets each session.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SaveService = {}

-- "_v2" = the placement-era save format. Old v1 saves (the preset-cell
-- prototype) are intentionally left behind in their own bucket.
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Lockdown_v2")
	end)
	if ok then
		store = result
	else
		warn("[Lockdown] DataStores unavailable (normal in unpublished Studio). Progress won't save this session.")
	end
end

local state = {} -- player -> { layout, cash, canSave, layoutSource }

local function keyFor(player)
	return "p_" .. player.UserId
end

local function loadData(player)
	if not store then
		return nil, false
	end
	local key = keyFor(player)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return result, true -- result is nil for a first-time player
		end
		warn(("[Lockdown] Load attempt %d failed for %s"):format(attempt, player.Name))
		task.wait(attempt)
	end
	return nil, false
end

local function onPlayerAdded(player)
	local saved, loadOk = loadData(player)
	if type(saved) ~= "table" then
		saved = nil
	end

	state[player] = {
		layout = saved and saved.layout or {},
		rooms = saved and saved.rooms or {},
		intake = saved and saved.intake or nil,
		cash = saved and saved.cash or 0,
		totalSpent = saved and saved.totalSpent or 0,
		land = saved and saved.land or {},
		-- Only allowed to write to the cloud if the read worked. A failed
		-- read must never let empty data overwrite a real save.
		canSave = store ~= nil and loadOk,
		-- key -> function(player) returning fresh data at save time.
		sources = {},
	}
end

local function saveNow(player)
	local st = state[player]
	if not st or not st.canSave then
		return
	end
	local snapshot = {
		layout = st.sources.layout and st.sources.layout(player) or st.layout,
		rooms = st.sources.rooms and st.sources.rooms(player) or st.rooms,
		intake = st.sources.intake and st.sources.intake(player) or st.intake,
		cash = st.cash,
		totalSpent = st.totalSpent,
		land = st.sources.land and st.sources.land(player) or st.land,
	}
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	if not ok then
		warn("[Lockdown] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Public API --------------------------------------------------------------

-- Waits until the player's data has loaded (nil if they left meanwhile).
function SaveService.waitForData(player)
	while state[player] == nil and player:IsDescendantOf(game) do
		task.wait(0.05)
	end
	return state[player]
end

-- The live game systems know the current layout/rooms/intake; each hands
-- us the function that snapshots its slice, and every save pulls fresh
-- data through them.
function SaveService.attachSource(player, key, sourceFn)
	local st = state[player]
	if st then
		st.sources[key] = sourceFn
	end
end

function SaveService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveNow(player)
		state[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(state) do
				task.spawn(saveNow, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in pairs(state) do
			saveNow(player)
		end
	end)
end

return SaveService
