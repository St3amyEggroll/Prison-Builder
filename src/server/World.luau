-- World: builds the shared map — the grass ground, the welcome plaza
-- where players first spawn, and pleasant daytime lighting. The prisons
-- themselves are built per-player by PlotService.

local Lighting = game:GetService("Lighting")

local World = {}

-- Small helper used all over the server: make an anchored Part in one
-- call. Everything in this game is anchored (nothing needs physics),
-- which is a big part of why it runs well on phones.
function World.part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

function World.build()
	-- One folder to hold everything we generate, so the Explorer window
	-- in Studio stays tidy.
	local root = Instance.new("Folder")
	root.Name = "Lockdown"

	-- The ground: one huge grass slab. Its top surface sits at Y = 0,
	-- which every other measurement in the game builds up from.
	World.part({
		Name = "Ground",
		Size = Vector3.new(1600, 4, 1600),
		CFrame = CFrame.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(106, 153, 85),
	}, root)

	-- The welcome plaza, in front of the row of prisons. Players spawn
	-- here for a split second before PlotService walks them to their plot.
	World.part({
		Name = "Plaza",
		Size = Vector3.new(40, 1, 40),
		CFrame = CFrame.new(0, 0.25, 110),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(163, 162, 165),
	}, root)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.9, 110)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- no forcefield bubble
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Color = Color3.fromRGB(80, 109, 84)
	spawnLocation.Parent = root

	root.Parent = workspace

	-- Sunny mid-afternoon, always.
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
end

return World
