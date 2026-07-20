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
