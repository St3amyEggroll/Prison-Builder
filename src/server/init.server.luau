-- Lockdown server bootstrap — first thing the game runs.
-- Creates the RemoteFunctions (the "ask the server" phone lines the
-- client UIs use), then starts every system in order.
--
-- Order matters: saving must exist before plots hand out zones, and the
-- asset catalog must exist before anything can be placed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

-- Every request returns { ok = true, ... } or { ok = false, err = "why" }.
for _, name in ipairs({
	"PlaceRequest",
	"PlaceLineRequest",
	"PlaceRectRequest",
	"FoundationRequest",
	"DeleteRequest",
	"DeleteManyRequest",
	"DeleteRectRequest",
	"RoomPaintRequest",
	"IntakeRequest",
}) do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
end

remotes.Parent = ReplicatedStorage

local SaveService = require(script.SaveService)
local Buildables = require(script.Buildables)
local DoorService = require(script.DoorService)
local PlacementService = require(script.PlacementService)
local RoomService = require(script.RoomService)
local IntakeService = require(script.IntakeService)
local PlotService = require(script.PlotService)

SaveService.init()
Buildables.init()
DoorService.init()
PlacementService.init()
RoomService.init()
IntakeService.init()
PlotService.init()

print("[Lockdown] Server ready — Phase 2: doors, foundations & room rules")
