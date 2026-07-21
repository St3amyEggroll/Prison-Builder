-- PlotService: finds the build zones in YOUR hand-made map and assigns
-- one to each player who joins.
--
-- The convention (docs/BUILDING_ASSETS.md): put a folder named
-- "PlotZones" in Workspace, and drop flat anchored Parts in it — each
-- Part is one player's build area. Size, position, and rotation are all
-- up to you; the grid adapts.
--
-- No PlotZones folder yet? A simple flat test map gets generated so the
-- game always runs — handy before your real map exists, and it's what
-- the quick-demo Lockdown.rbxlx uses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local SaveService = require(script.Parent.SaveService)
local PlacementService = require(script.Parent.PlacementService)
local RoomService = require(script.Parent.RoomService)
local IntakeService = require(script.Parent.IntakeService)
local ConstructionService = require(script.Parent.ConstructionService)

local PlotService = {}

local zones = {} -- array of { part, info, placed, owner }

-- Fallback test map (only when your map doesn't exist yet) --------------

local function buildFallbackMap()
	local root = Instance.new("Folder")
	root.Name = "LockdownTestMap"

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(900, 4, 500)
	ground.CFrame = CFrame.new(0, -2, 0)
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(106, 153, 85)
	ground.Parent = root

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.5, 160)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = root

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = Config.ZonesFolderName

	local zoneSize = Config.FallbackZoneSize
	local spacing = zoneSize + 15
	for i = 1, Config.FallbackZoneCount do
		local zone = Instance.new("Part")
		zone.Name = "Zone" .. i
		zone.Anchored = true
		zone.Size = Vector3.new(zoneSize, 1, zoneSize)
		zone.CFrame = CFrame.new((i - (Config.FallbackZoneCount + 1) / 2) * spacing, 0.5, 0)
		zone.Material = Enum.Material.Concrete
		zone.Color = Color3.fromRGB(163, 162, 165)
		zone.Parent = zonesFolder
	end
	zonesFolder.Parent = root

	root.Parent = workspace
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	print("[Lockdown] No " .. Config.ZonesFolderName .. " folder found — built the fallback test map.")
	return zonesFolder
end

-- Zone management --------------------------------------------------------

local function discoverZones()
	local folder = workspace:FindFirstChild(Config.ZonesFolderName)
	if not folder or #folder:GetChildren() == 0 then
		folder = buildFallbackMap()
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			local placed = Instance.new("Folder")
			placed.Name = "Placed"
			placed.Parent = child
			table.insert(zones, {
				part = child,
				info = GridMath.zoneInfo(child),
				placed = placed,
				owner = nil,
			})
		else
			warn("[Lockdown] Ignoring '" .. child.Name .. "' in " .. Config.ZonesFolderName .. " — zones must be Parts.")
		end
	end
	print(("[Lockdown] %d build zones ready"):format(#zones))
end

local function assignZone(player)
	local data = SaveService.waitForData(player)
	if not data or not player:IsDescendantOf(game) then
		return
	end

	local zone = nil
	for _, candidate in ipairs(zones) do
		if candidate.owner == nil then
			zone = candidate
			break
		end
	end
	if not zone then
		warn("[Lockdown] No free build zone for " .. player.Name)
		return
	end

	zone.owner = player
	PlacementService.assignZone(player, zone, data.layout)
	RoomService.assignZone(player, zone, data.rooms)
	ConstructionService.assignPlayer(player, zone)
	IntakeService.assignPlayer(player, zone, data.intake)
	SaveService.attachSource(player, "layout", PlacementService.snapshotLayout)
	SaveService.attachSource(player, "rooms", RoomService.snapshotRooms)
	SaveService.attachSource(player, "intake", IntakeService.snapshotIntake)

	-- Tell this player's client which zone is theirs (the build UI needs
	-- it for grid math and aiming).
	local marker = Instance.new("ObjectValue")
	marker.Name = "BuildZone"
	marker.Value = zone.part
	marker.Parent = player

	-- Walk each character spawn over to their zone's front edge.
	local function placeCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or zone.owner ~= player then
			return
		end
		task.wait(0.1)
		local zoneCF, zoneSize = zone.part.CFrame, zone.part.Size
		local edge = zoneCF * CFrame.new(0, zoneSize.Y / 2 + 3.5, zoneSize.Z / 2 + 6)
		local lookTarget = zoneCF * CFrame.new(0, zoneSize.Y / 2 + 3.5, 0)
		character:PivotTo(CFrame.lookAt(edge.Position, lookTarget.Position))
	end
	player.CharacterAdded:Connect(placeCharacter)
	if player.Character then
		task.spawn(placeCharacter, player.Character)
	end
end

local function releaseZone(player)
	IntakeService.releasePlayer(player)
	ConstructionService.releasePlayer(player)
	RoomService.releasePlayer(player)
	PlacementService.releasePlayer(player)
	local marker = player:FindFirstChild("BuildZone")
	if marker then
		marker:Destroy()
	end
	for _, zone in ipairs(zones) do
		if zone.owner == player then
			zone.owner = nil
		end
	end
end

function PlotService.init()
	discoverZones()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(assignZone, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(assignZone, player)
	end
	Players.PlayerRemoving:Connect(releaseZone)
end

return PlotService
