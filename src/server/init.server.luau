-- Lockdown server bootstrap — first thing the game runs.
-- Creates the RemoteFunctions (the "ask the server" phone lines the
-- client UIs use), starts every system in order, and wires the
-- cross-system hooks in one visible place.

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
	"MoveRequest",
	"RoomPaintRequest",
	"IntakeRequest",
}) do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
end

remotes.Parent = ReplicatedStorage

local SaveService = require(script.SaveService)
local EconomyService = require(script.EconomyService)
local ObjectiveService = require(script.ObjectiveService)
local Buildables = require(script.Buildables)
local DoorService = require(script.DoorService)
local PathService = require(script.PathService)
local ConstructionService = require(script.ConstructionService)
local PlacementService = require(script.PlacementService)
local RoomService = require(script.RoomService)
local IntakeService = require(script.IntakeService)
local PlotService = require(script.PlotService)

SaveService.init()
EconomyService.init()
ObjectiveService.init()
Buildables.init()
DoorService.init()
ConstructionService.init()
PlacementService.init()
RoomService.init()
IntakeService.init()
PlotService.init()

-- Cross-system wiring, all in one visible place:
-- PathService walks the same occupancy grid placements live on...
PathService.setCellLookup(PlacementService.cellAsset)
-- ...finished construction changes capacity and room validity...
ConstructionService.onCompleted(function(player)
	RoomService.poke(player)
	IntakeService.poke(player)
end)
-- ...and so does moving something.
PlacementService.onMoved(function(player)
	RoomService.poke(player)
	IntakeService.poke(player)
end)

print("[Lockdown] Server ready — Phase 3: money, workmen, pathfinding")
