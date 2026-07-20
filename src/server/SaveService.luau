-- SaveService: owns every player's money and progress, and saves it to
-- Roblox's DataStores (cloud storage tied to the published game).
--
-- Plain-English rules this file enforces:
--   * The SERVER is the only thing that ever changes your cash. A hacked
--     client can ask, but never take. This is Roblox security 101.
--   * If loading a player's save fails, we give them a fresh session but
--     REFUSE to save over their cloud data — a network hiccup must never
--     wipe someone's prison.
--   * Saves happen when you leave, every 60s (autosave), and when the
--     server shuts down.
--
-- Note for Studio: saving only works after the game is published with
-- "Studio Access to API Services" enabled (see SETUP.md). Before that,
-- everything still plays fine — progress just resets each session.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SaveService = {}

-- The cloud storage bucket. The "_v1" suffix lets us switch to a fresh
-- bucket later if the save format ever changes drastically.
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Lockdown_v1")
	end)
	if ok then
		store = result
	else
		warn("[Lockdown] DataStores unavailable (normal in unpublished Studio). Progress won't save this session.")
	end
end

-- Live data for everyone currently in the server: player -> state table.
local state = {}

local function keyFor(player)
	return "p_" .. player.UserId
end

local function defaultData()
	return {
		cash = Config.StartingCash,
		cells = 0,
		totalEarned = 0,
	}
end

-- Try a DataStore read up to 3 times before giving up (Roblox services
-- occasionally hiccup; retrying quietly fixes most of it).
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
			return result, true -- result may be nil for a first-time player
		end
		warn(("[Lockdown] Load attempt %d failed for %s"):format(attempt, player.Name))
		task.wait(attempt) -- back off a little more each try
	end
	return nil, false
end

local function onPlayerAdded(player)
	local saved, loadOk = loadData(player)
	local data = saved or defaultData()

	-- leaderstats is a magic folder name: Roblox shows its values in the
	-- player list automatically. Free UI!
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = data.cash
	cashValue.Parent = leaderstats

	local inmatesValue = Instance.new("IntValue")
	inmatesValue.Name = "Inmates"
	inmatesValue.Value = data.cells
	inmatesValue.Parent = leaderstats

	leaderstats.Parent = player

	state[player] = {
		cash = data.cash,
		cells = data.cells,
		totalEarned = data.totalEarned or 0,
		-- Only allowed to write to the cloud if the read worked. A failed
		-- read must never let default data overwrite a real save.
		canSave = store ~= nil and loadOk,
		cashValue = cashValue,
		inmatesValue = inmatesValue,
	}
end

local function saveNow(player)
	local st = state[player]
	if not st or not st.canSave then
		return
	end
	local snapshot = {
		cash = st.cash,
		cells = st.cells,
		totalEarned = st.totalEarned,
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

-- Public API used by the other systems ---------------------------------

-- Waits until the player's data has loaded (returns nil if they left).
function SaveService.waitForData(player)
	while state[player] == nil and player:IsDescendantOf(game) do
		task.wait(0.05)
	end
	return state[player]
end

function SaveService.getCash(player)
	local st = state[player]
	return st and st.cash or 0
end

-- Income and refunds go through here so leaderstats always stays in sync.
function SaveService.addCash(player, amount)
	local st = state[player]
	if not st then
		return
	end
	st.cash += amount
	if amount > 0 then
		st.totalEarned += amount
	end
	st.cashValue.Value = st.cash
end

-- Spending: only succeeds if the player can actually afford it.
function SaveService.trySpend(player, amount)
	local st = state[player]
	if not st or st.cash < amount then
		return false
	end
	st.cash -= amount
	st.cashValue.Value = st.cash
	return true
end

function SaveService.setCells(player, count)
	local st = state[player]
	if not st then
		return
	end
	st.cells = count
	st.inmatesValue.Value = count
end

function SaveService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Catch anyone who joined before this script connected (rare, but
	-- classic Studio race condition).
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveNow(player)
		state[player] = nil
	end)

	-- Autosave loop, so a server crash can only ever lose ~1 minute.
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(state) do
				task.spawn(saveNow, player)
			end
		end
	end)

	-- When Roblox shuts this server down, save everyone before it dies.
	game:BindToClose(function()
		for player in pairs(state) do
			saveNow(player)
		end
	end)
end

return SaveService
