-- Config: every tunable number and naming convention in one place.
--
-- The two IMPORTANT CONVENTIONS the map-maker (you!) uses in Studio:
--   * Workspace -> a folder named "PlotZones" holding flat, anchored
--     Parts. Each Part is one player's build area. Your map, your rules —
--     the code finds them wherever you put them.
--   * ReplicatedStorage -> a folder named "Buildables" holding Models.
--     Every Model in it automatically appears in the build menu.
-- Full guide: docs/BUILDING_ASSETS.md

local Config = {}

-- Money ------------------------------------------------------------------

Config.StartingCash = 3000

-- Owner switches: FreeBuild ignores all prices; InstantBuild skips the
-- workman/blueprint construction (handy while designing your map).
Config.FreeBuild = false
Config.InstantBuild = false

-- Bulldozing refunds this fraction of the price. Undo refunds 100%.
Config.RefundRate = 0.5

-- Every GrantInterval seconds, each HOUSED prisoner pays their grant.
-- (Waiting handcuffed at the gate pays nothing — house them!)
Config.GrantInterval = 30
Config.GrantPerPrisoner = 60

-- One in-game day, in real seconds (the top-bar clock and DAY counter).
Config.DayLength = 600

-- An asset's price = its "Price" attribute, else its category's default.
Config.DefaultLandPrice = 2000 -- buyable parcels without a Price attribute

Config.DefaultPrices = {
	["Walls & Doors"] = 40,
	["Flooring"] = 10,
	["Objects"] = 250,
}
Config.FallbackPrice = 50

-- Construction -----------------------------------------------------------

-- Placements start as transparent blueprints; workmen walk over and
-- build them (Prison Architect's whole vibe).
Config.WorkmenPerPlot = 2
Config.WorkerSpeed = 6 -- studs/sec walking to the job
Config.BuildTimeBase = 1 -- seconds per job...
Config.BuildTimePerCell = 0.5 -- ...plus this per grid square of footprint
Config.WorkerNames = { "Hammer Hank", "Nailgun Ned", "Plank Paul", "Rivet Rita", "Sawdust Sam", "Bolt Betty" }


-- Building ---------------------------------------------------------------

-- Placement grid size in studs. Everything snaps to this. Assets bigger
-- than one grid square automatically take up more squares.
Config.GridSize = 4

-- Rotation happens in steps of 90 degrees (0, 90, 180, 270).

-- Folder names the code looks for (the conventions described up top).
Config.ZonesFolderName = "PlotZones"
Config.BuildablesFolderName = "Buildables"

-- Set attribute "NoPlaceholders" = true on your Buildables folder once
-- you have your own assets and want Claude's placeholder models gone.

-- Toolbar categories -----------------------------------------------------

-- The Prison Architect-style bottom bar. Assets declare theirs with a
-- "Category" attribute (defaults to "Objects"); a category the code has
-- never seen just becomes a new button automatically.
Config.AssetCategories = { "Walls & Doors", "Flooring", "Objects" }
Config.CategoryIcons = {
	["Walls & Doors"] = "🧱",
	["Flooring"] = "🟫",
	["Objects"] = "🪑",
}

-- Shown grayed-out like PA's locked tabs — real features in later phases.
Config.ComingSoon = {
	{ icon = "👮", name = "Staff", note = "Staff arrive in Phase 4!" },
	{ icon = "💡", name = "Utilities", note = "Utilities — later, maybe. Pipes on a phone is a big ask 😄" },
}

-- Foundations ------------------------------------------------------------

-- The 🏗️ tool: drag a rectangle, walls go up around the edge with floor
-- inside (add a door yourself afterward, like PA). It builds using these
-- assets from the Buildables folder — rename here if yours differ.
Config.FoundationWallAsset = "Wall"
Config.FoundationFloorAsset = "Floor Tile"
Config.FoundationMinSize = 3 -- squares per side (needs an interior)
Config.FoundationMaxArea = 400 -- squares per drag

-- Doors ------------------------------------------------------------------

-- Assets with attribute Door = true open for the WARDEN when they walk
-- close (inmates and strangers stay blocked). Parts named "DoorPanel"
-- inside the model are what slides down; no panel named -> the whole
-- model fades open instead.
Config.DoorOpenDistance = 8 -- studs
Config.DoorCheckInterval = 0.25 -- seconds between proximity checks

-- Room requirements ------------------------------------------------------

-- Painted rooms show what they still need, PA-style. "enclosed" means
-- every square just outside the room is filled by a "Walls & Doors"
-- asset (or a Door). attrCounts counts placed objects inside the room
-- carrying that attribute. minCells is the minimum painted size.
Config.RoomRequirements = {
	Cell = { enclosed = true, minCells = 4, attrCounts = { SpawnsInmate = 1 } },
	Canteen = { enclosed = true, minCells = 9 },
	Kitchen = { enclosed = true, minCells = 6 },
	Yard = { minCells = 9 },
	Shower = { enclosed = true, minCells = 4 },
	Workshop = { enclosed = true, minCells = 9 },
	Office = { enclosed = true, minCells = 4 },
	Storage = { enclosed = true, minCells = 4 },
}

-- Friendly names for attrCounts requirements in the floor labels.
Config.RequirementText = {
	SpawnsInmate = "bed",
}

-- Rooms ------------------------------------------------------------------

-- Room types for the room painter (pick one, then drag a rectangle).
-- Colors are the floor-overlay tint players see.
Config.RoomTypes = {
	{ name = "Cell", color = Color3.fromRGB(255, 140, 60) },
	{ name = "Canteen", color = Color3.fromRGB(255, 220, 90) },
	{ name = "Kitchen", color = Color3.fromRGB(235, 90, 80) },
	{ name = "Yard", color = Color3.fromRGB(110, 210, 110) },
	{ name = "Shower", color = Color3.fromRGB(100, 180, 255) },
	{ name = "Workshop", color = Color3.fromRGB(190, 140, 90) },
	{ name = "Office", color = Color3.fromRGB(190, 120, 220) },
	{ name = "Storage", color = Color3.fromRGB(160, 160, 160) },
}

-- Intake -----------------------------------------------------------------

-- Prisoners arrive at the FRONT of the plot (the +Z side of the zone
-- Part — rotate the Part in Studio to choose which side that is),
-- handcuffed, and wait until an empty housing asset exists. Then they're
-- escorted in, uncuffed, and start living there.
Config.MaxWaiting = 6 -- how many can crowd the front gate
Config.IntakeInterval = 12 -- seconds between auto-intake arrivals
Config.EscortSpeed = 4.5 -- studs/sec while being walked to a cell

-- Inmate life ------------------------------------------------------------

Config.WanderRadius = 3.5 -- how far a housed inmate roams from home
Config.WalkSpeed = 3.5 -- studs/sec while wandering

-- Saving ----------------------------------------------------------------

-- How often (seconds) layouts auto-save, on top of saving when a player
-- leaves. Roblox limits DataStore writes, so keep this >= 60.
Config.AutosaveInterval = 60

-- Fallback test map ------------------------------------------------------

-- Only used when Workspace has no PlotZones folder yet: the code builds
-- a simple flat test map so the game always runs. The moment your real
-- map (with a PlotZones folder) exists, none of this happens.
Config.FallbackZoneCount = 2
Config.FallbackZoneSize = 240

-- Flavor ----------------------------------------------------------------

-- Inmate names for assets that spawn an inmate (SpawnsInmate attribute).
Config.InmateNames = {
	"Sneaky Pete", "Tunnel Tim", "Fingers McGee", "Slippery Sam",
	"Crowbar Carl", "Ladder Larry", "Muddy Marv", "Wall-Eye Wally",
	"Shovel Steve", "Grapple Gus", "Lockpick Lou", "Vent-Crawl Vince",
	"Bedsheet Bill", "Spoon Simon", "Laundry Lee", "Big House Bruno",
	"Quiet Quentin", "Two-Step Tony", "Gopher Gil", "Fence-Hop Fred",
	"Papers Pablo", "Half-Inch Hank",
}

return Config
