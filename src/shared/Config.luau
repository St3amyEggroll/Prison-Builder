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
	{ icon = "🏗️", name = "Foundations", note = "Foundations — coming soon!" },
	{ icon = "👮", name = "Staff", note = "Staff arrive in Phase 2!" },
	{ icon = "💡", name = "Utilities", note = "Utilities — later, maybe. Pipes on a phone is a big ask 😄" },
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
Config.FallbackZoneCount = 4
Config.FallbackZoneSize = 128

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
