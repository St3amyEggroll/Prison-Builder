-- Config: every "game designer number" lives in this one file.
-- Want cells cheaper, inmates to pay more, or a bigger prison?
-- Change a number here and rebuild — no real code needs touching.

local Config = {}

-- Money -----------------------------------------------------------------

-- Cash a brand-new warden starts with. It exactly covers the first cell,
-- so the very first thing a player does is buy something (instant win!).
Config.StartingCash = 50

-- Price of each cell, in order. Cell #1 costs 50, cell #2 costs 100, etc.
-- The list length also decides the max prison size for now (22 cells).
Config.CellCosts = {
	50, 100, 170, 280, 450, 700, 1100, 1700, 2600, 3900,
	5800, 8500, 12000, 17000, 24000, 33000, 45000, 60000,
	80000, 105000, 135000, 170000,
}
Config.MaxCells = #Config.CellCosts

-- Every PayoutInterval seconds, each inmate pays PayoutPerInmate cash.
-- 10 cash every 5 seconds = $2/sec per inmate. With the numbers above, a
-- new player affords cell #2 about 50 seconds in — under the golden-rule
-- 90 seconds for the first real upgrade.
Config.PayoutInterval = 5
Config.PayoutPerInmate = 10

-- World -----------------------------------------------------------------

-- How many player plots the server builds. Each visitor gets their own.
Config.PlotCount = 6

-- Saving ----------------------------------------------------------------

-- How often (seconds) progress is auto-saved, on top of saving when a
-- player leaves. Roblox limits DataStore writes, so keep this >= 60.
Config.AutosaveInterval = 60

-- Flavor ----------------------------------------------------------------

-- Inmate names, assigned by cell number (cell #1 always holds Sneaky
-- Pete). Silly on purpose — this is a cozy prison.
Config.InmateNames = {
	"Sneaky Pete", "Tunnel Tim", "Fingers McGee", "Slippery Sam",
	"Crowbar Carl", "Ladder Larry", "Muddy Marv", "Wall-Eye Wally",
	"Shovel Steve", "Grapple Gus", "Lockpick Lou", "Vent-Crawl Vince",
	"Bedsheet Bill", "Spoon Simon", "Laundry Lee", "Big House Bruno",
	"Quiet Quentin", "Two-Step Tony", "Gopher Gil", "Fence-Hop Fred",
	"Papers Pablo", "Half-Inch Hank",
}

return Config
