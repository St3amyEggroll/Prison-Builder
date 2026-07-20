-- Lockdown server bootstrap. This is the first script the game runs.
-- It creates the RemoteEvents (the "phone lines" the server and each
-- player's screen use to talk), then starts every game system in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Phone lines to the client:
--   Popup          -> "show a floating +$40 at this spot"
--   PurchaseResult -> "your buy attempt succeeded/failed, react!"
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local popupRemote = Instance.new("RemoteEvent")
popupRemote.Name = "Popup"
popupRemote.Parent = remotes

local purchaseRemote = Instance.new("RemoteEvent")
purchaseRemote.Name = "PurchaseResult"
purchaseRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

-- Start the systems. Order matters: the world must exist before plots
-- are placed on it, and saving must be ready before players get plots.
local World = require(script.World)
local SaveService = require(script.SaveService)
local PlotService = require(script.PlotService)
local Economy = require(script.Economy)

World.build()
SaveService.init()
PlotService.init()
Economy.init()

print("[Lockdown] Server ready — Phase 1 MVP")
