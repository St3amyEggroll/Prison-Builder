-- Lockdown server bootstrap — first thing the game runs.
-- Creates the RemoteFunctions (the "ask the server" phone lines the
-- build UI uses), then starts every system in order.
--
-- Order matters: saving must exist before plots hand out zones, and the
-- asset catalog must exist before anything can be placed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

-- Client asks "place this asset at grid square X,Z rotated R" and gets
-- back { ok = true } or { ok = false, err = "reason" }.
local placeRequest = Instance.new("RemoteFunction")
placeRequest.Name = "PlaceRequest"
placeRequest.Parent = remotes

local deleteRequest = Instance.new("RemoteFunction")
deleteRequest.Name = "DeleteRequest"
deleteRequest.Parent = remotes

remotes.Parent = ReplicatedStorage

local SaveService = require(script.SaveService)
local Buildables = require(script.Buildables)
local PlacementService = require(script.PlacementService)
local PlotService = require(script.PlotService)

SaveService.init()
Buildables.init()
PlacementService.init()
PlotService.init()

print("[Lockdown] Server ready — placement build")
