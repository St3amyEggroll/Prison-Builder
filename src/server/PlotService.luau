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
local Format = require(ReplicatedStorage.Shared.Format)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local SaveService = require(script.Parent.SaveService)
local EconomyService = require(script.Parent.EconomyService)
local PlacementService = require(script.Parent.PlacementService)
local RoomService = require(script.Parent.RoomService)
local IntakeService = require(script.Parent.IntakeService)
local StaffService = require(script.Parent.StaffService)
local NeedsService = require(script.Parent.NeedsService)
local SecurityService = require(script.Parent.SecurityService)
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
	ground.Size = Vector3.new(1200, 4, 750)
	ground.CFrame = CFrame.new(0, -2, 0)
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(106, 153, 85)
	ground.Parent = root

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.5, 170)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = root

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = Config.ZonesFolderName

	local zoneSize = Config.FallbackZoneSize
	local spacing = zoneSize + 20
	for i = 1, Config.FallbackZoneCount do
		local zone = Instance.new("Part")
		zone.Name = "Zone" .. i
		zone.Anchored = true
		zone.Size = Vector3.new(zoneSize, 1, zoneSize)
		zone.CFrame = CFrame.new((i - (Config.FallbackZoneCount + 1) / 2) * spacing, 0.5, 0)
		zone.Material = Enum.Material.Concrete
		zone.Color = Color3.fromRGB(163, 162, 165)

		-- Demo land parcels (quarters): front-left free, the rest buyable —
		-- the same convention the owner uses in their own map.
		local quarter = zoneSize / 4
		for _, quad in ipairs({
			{ -quarter, quarter, 0 }, -- front-left: free starting land
			{ quarter, quarter, 2000 },
			{ -quarter, -quarter, 2500 },
			{ quarter, -quarter, 3000 },
		}) do
			local parcel = Instance.new("Part")
			parcel.Name = "Land"
			parcel.Anchored = true
			parcel.Size = Vector3.new(zoneSize / 2, 0.5, zoneSize / 2)
			parcel.CFrame = zone.CFrame * CFrame.new(quad[1], 0.5, quad[2])
			parcel.Transparency = 1
			parcel.CanCollide = false
			if quad[3] > 0 then
				parcel:SetAttribute("Price", quad[3])
			end
			parcel.Parent = zone
		end
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
			local info = GridMath.zoneInfo(child)

			-- Land parcels: any Part inside the zone Part marks a region.
			-- No Price attribute (or 0) = free starting land; a Price =
			-- buyable expansion. No parcels at all = whole zone unlocked.
			local parcels = {}
			for _, marker in ipairs(child:GetChildren()) do
				if marker:IsA("BasePart") then
					local x1, z1, x2, z2 = GridMath.partRect(info, marker)
					table.insert(parcels, {
						x1 = x1,
						z1 = z1,
						x2 = x2,
						z2 = z2,
						price = math.max(0, math.floor(tonumber(marker:GetAttribute("Price")) or 0)),
					})
					marker.Transparency = 1
					marker.CanCollide = false
					marker.CanQuery = false
					marker.CanTouch = false
				end
			end
			table.sort(parcels, function(a, b)
				if a.z1 ~= b.z1 then
					return a.z1 < b.z1
				end
				return a.x1 < b.x1
			end)
			for i, parcel in ipairs(parcels) do
				parcel.index = i
			end

			table.insert(zones, {
				part = child,
				info = info,
				placed = placed,
				owner = nil,
				parcels = parcels,
				unlocked = nil,
				purchasedList = {},
			})
		else
			warn("[Lockdown] Ignoring '" .. child.Name .. "' in " .. Config.ZonesFolderName .. " — zones must be Parts.")
		end
	end
	print(("[Lockdown] %d build zones ready"):format(#zones))
end

local function unlockParcel(zone, parcel)
	for x = parcel.x1, parcel.x2 do
		for z = parcel.z1, parcel.z2 do
			zone.unlocked[x .. ":" .. z] = true
		end
	end
end

-- A locked parcel: dark slab + price tag + click-to-buy.
local function makeOverlay(player, zone, parcel, folder)
	local G = Config.GridSize
	local w, d = parcel.x2 - parcel.x1 + 1, parcel.z2 - parcel.z1 + 1

	local overlay = Instance.new("Part")
	overlay.Name = "LandOverlay"
	overlay.Anchored = true
	overlay.CanCollide = false
	overlay.CanTouch = false
	overlay.CastShadow = false
	overlay.Material = Enum.Material.SmoothPlastic
	overlay.Color = Color3.fromRGB(35, 35, 40)
	overlay.Transparency = 0.4
	overlay.Size = Vector3.new(w * G - 0.3, 0.5, d * G - 0.3)
	overlay.CFrame = GridMath.regionCenter(zone.info, parcel.x1, parcel.z1, w, d) * CFrame.new(0, 0.3, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 240, 0, 56)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.TextStrokeTransparency = 0.4
	label.Text = ("🔒 Buy land — %s"):format(Format.money(parcel.price))
	label.Parent = gui
	gui.Parent = overlay

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 1000
	click.MouseClick:Connect(function(clicker)
		if clicker ~= player or zone.owner ~= player then
			return
		end
		if not EconomyService.tryCharge(player, parcel.price) then
			return
		end
		table.insert(zone.purchasedList, parcel.index)
		unlockParcel(zone, parcel)
		overlay:Destroy()
		RoomService.poke(player)
		IntakeService.poke(player)
	end)
	click.Parent = overlay
	overlay.Parent = folder
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

	-- Land: free parcels + previously bought ones unlock; the rest get
	-- purchase overlays. No parcels = the whole zone is buildable.
	zone.purchasedList = {}
	if #zone.parcels > 0 then
		zone.unlocked = {}
		local purchasedSet = {}
		if type(data.land) == "table" then
			for _, idx in ipairs(data.land) do
				purchasedSet[math.floor(tonumber(idx) or -1)] = true
			end
		end
		local lockedFolder = Instance.new("Folder")
		lockedFolder.Name = "LockedLand"
		lockedFolder.Parent = zone.part
		for _, parcel in ipairs(zone.parcels) do
			if parcel.price <= 0 or purchasedSet[parcel.index] then
				unlockParcel(zone, parcel)
				if parcel.price > 0 then
					table.insert(zone.purchasedList, parcel.index)
				end
			else
				makeOverlay(player, zone, parcel, lockedFolder)
			end
		end
	else
		zone.unlocked = nil
	end

	PlacementService.assignZone(player, zone, data.layout)
	RoomService.assignZone(player, zone, data.rooms)
	ConstructionService.assignPlayer(player, zone)
	IntakeService.assignPlayer(player, zone, data.intake)
	StaffService.assignPlayer(player, zone, data.staff)
	NeedsService.assignPlayer(player, zone)
	SecurityService.assignPlayer(player, zone)
	SaveService.attachSource(player, "layout", PlacementService.snapshotLayout)
	SaveService.attachSource(player, "rooms", RoomService.snapshotRooms)
	SaveService.attachSource(player, "intake", IntakeService.snapshotIntake)
	SaveService.attachSource(player, "land", function()
		return zone.purchasedList
	end)
	SaveService.attachSource(player, "staff", StaffService.snapshotStaff)

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
	SecurityService.releasePlayer(player)
	NeedsService.releasePlayer(player)
	StaffService.releasePlayer(player)
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
			local locked = zone.part:FindFirstChild("LockedLand")
			if locked then
				locked:Destroy()
			end
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
