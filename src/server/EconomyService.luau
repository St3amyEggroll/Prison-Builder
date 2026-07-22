-- EconomyService: the money. Server-authoritative — a hacked client can
-- ask to spend, never take. Cash lives inside SaveService's player state
-- (so it cloud-saves for free) and mirrors into leaderstats, which both
-- shows it in the player list and feeds the client HUD.
--
-- Income: every GrantInterval seconds each HOUSED prisoner pays their
-- grant (read from the PrisonHoused attribute IntakeService publishes —
-- handcuffed arrivals at the gate pay nothing).
--
-- Config.FreeBuild = true turns all charging off (owner sandbox switch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SaveService = require(script.Parent.SaveService)

local EconomyService = {}

local wallets = {} -- player -> { st = SaveService state, cashValue = IntValue }
local grantedListeners = {} -- fns(player, amount) — ObjectiveService hooks in

local function onPlayerAdded(player)
	local st = SaveService.waitForData(player)
	if not st or not player:IsDescendantOf(game) then
		return
	end
	if type(st.cash) ~= "number" or st.cash <= 0 then
		st.cash = st.cash or 0
		if st.cash == 0 and (st.totalSpent or 0) == 0 then
			st.cash = Config.StartingCash
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = math.floor(st.cash)
	cashValue.Parent = leaderstats
	leaderstats.Parent = player

	wallets[player] = { st = st, cashValue = cashValue }
end

function EconomyService.getCash(player)
	local wallet = wallets[player]
	return wallet and wallet.st.cash or 0
end

function EconomyService.credit(player, amount)
	local wallet = wallets[player]
	if not wallet or amount <= 0 then
		return
	end
	wallet.st.cash += amount
	wallet.cashValue.Value = math.floor(wallet.st.cash)
end

-- Spend if affordable. FreeBuild makes everything cost nothing.
function EconomyService.tryCharge(player, amount)
	if Config.FreeBuild or amount <= 0 then
		return true
	end
	local wallet = wallets[player]
	if not wallet or wallet.st.cash < amount then
		return false
	end
	wallet.st.cash -= amount
	wallet.st.totalSpent = (wallet.st.totalSpent or 0) + amount
	wallet.cashValue.Value = math.floor(wallet.st.cash)
	return true
end

function EconomyService.onGranted(fn)
	table.insert(grantedListeners, fn)
end

function EconomyService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		wallets[player] = nil
	end)

	-- The grant tick: housed prisoners pay their keep.
	task.spawn(function()
		while true do
			task.wait(Config.GrantInterval)
			for player in pairs(wallets) do
				local housed = player:GetAttribute("PrisonHoused") or 0
				if housed > 0 then
					-- Miserable prisons pay less: 100% unrest halves grants.
					local unrest = player:GetAttribute("PrisonUnrest") or 0
					local amount = math.floor(housed * Config.GrantPerPrisoner * (1 - unrest / 200))
					EconomyService.credit(player, amount)
					for _, fn in ipairs(grantedListeners) do
						task.spawn(fn, player, amount)
					end
				end
			end
		end
	end)
end

return EconomyService
