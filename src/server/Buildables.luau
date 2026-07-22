-- Buildables: makes sure the asset folder exists and, until you've made
-- your own models, fills it with simple placeholder assets so the build
-- menu is never empty.
--
-- How replacing works (see docs/BUILDING_ASSETS.md):
--   * Your Models in ReplicatedStorage/Buildables always win — a
--     placeholder is only added if no model with that name exists yet.
--   * Done with placeholders entirely? Set attribute NoPlaceholders =
--     true on the Buildables folder and they all stay away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AssetCatalog = require(ReplicatedStorage.Shared.AssetCatalog)

local Buildables = {}

local GRAY = Color3.fromRGB(200, 198, 190)
local DARK = Color3.fromRGB(95, 95, 100)
local METAL = Color3.fromRGB(35, 35, 40)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Concrete
	p.Color = GRAY
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Each builder positions its parts with the model's bottom at Y = 0 and
-- its footprint centered on the origin. The catalog measures the result,
-- so these are just "build it roughly right and it works".
local PLACEHOLDERS = {
	{
		-- A full grid square of solid wall, Prison Architect style — wall
		-- runs tile with no gaps, corners just work.
		name = "Wall",
		category = "Walls & Doors",
		price = 40,
		build = function(model)
			part({ Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(0, 4, 0) }, model)
		end,
	},
	{
		name = "Floor Tile",
		category = "Flooring",
		price = 10,
		build = function(model)
			part({ Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(0, 0.2, 0), Color = DARK }, model)
		end,
	},
	{
		name = "Fence",
		category = "Walls & Doors",
		price = 30,
		build = function(model)
			for i = 0, 4 do
				part({
					Size = Vector3.new(0.3, 6, 0.3),
					CFrame = CFrame.new(-1.8 + i * 0.9, 3, 0),
					Material = Enum.Material.Metal,
					Color = METAL,
				}, model)
			end
			part({
				Size = Vector3.new(4, 0.3, 0.3),
				CFrame = CFrame.new(0, 5.85, 0),
				Material = Enum.Material.Metal,
				Color = METAL,
			}, model)
		end,
	},
	{
		-- Same width and thinness as the Fence, so a door drops cleanly
		-- into a fence run.
		name = "Security Door",
		category = "Walls & Doors",
		price = 150,
		build = function(model)
			part({ Size = Vector3.new(0.4, 8, 0.4), CFrame = CFrame.new(-1.8, 4, 0) }, model)
			part({ Size = Vector3.new(0.4, 8, 0.4), CFrame = CFrame.new(1.8, 4, 0) }, model)
			part({ Size = Vector3.new(4, 0.5, 0.4), CFrame = CFrame.new(0, 7.75, 0) }, model)
			-- The sliding slab: DoorService animates parts with this name.
			part({
				Name = "DoorPanel",
				Size = Vector3.new(3.2, 7, 0.4),
				CFrame = CFrame.new(0, 3.5, 0),
				Material = Enum.Material.DiamondPlate,
				Color = Color3.fromRGB(91, 105, 117),
			}, model)
			model:SetAttribute("Door", true)
		end,
	},
	{
		-- Cells aren't prefab objects anymore — you BUILD them: walls, a
		-- door, floor, paint the Cell room, and put a Bed inside. The bed
		-- is what houses a prisoner (SpawnsInmate), but only once its Cell
		-- room shows ✓ ready.
		name = "Bed",
		category = "Objects",
		price = 150,
		build = function(model)
			part({
				Size = Vector3.new(3.4, 0.6, 7),
				CFrame = CFrame.new(0, 0.5, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(70, 70, 75),
			}, model)
			part({
				Size = Vector3.new(3.2, 0.6, 6.6),
				CFrame = CFrame.new(0, 1.1, 0),
				Material = Enum.Material.Fabric,
				Color = Color3.fromRGB(235, 235, 230),
			}, model)
			part({
				Size = Vector3.new(2.6, 0.35, 1.5),
				CFrame = CFrame.new(0, 1.55, -2.4),
				Material = Enum.Material.Fabric,
				Color = Color3.fromRGB(255, 170, 60),
			}, model)
			model:SetAttribute("SpawnsInmate", true)
		end,
	},
	{
		name = "Guard Tower",
		category = "Objects",
		price = 400,
		build = function(model)
			for _, offset in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
				part({
					Size = Vector3.new(1, 10, 1),
					CFrame = CFrame.new(offset[1], 5, offset[2]),
					Material = Enum.Material.Metal,
					Color = METAL,
				}, model)
			end
			part({ Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(0, 10.5, 0), Color = DARK }, model)
			for _, offset in ipairs({ { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 } }) do
				part({
					Size = Vector3.new(0.5, 4, 0.5),
					CFrame = CFrame.new(offset[1], 13, offset[2]),
					Material = Enum.Material.Metal,
					Color = METAL,
				}, model)
			end
			part({ Size = Vector3.new(9, 0.8, 9), CFrame = CFrame.new(0, 15.4, 0), Color = GRAY }, model)
		end,
	},
}

local catalogByName = nil
local catalogOrdered = nil

function Buildables.init()
	local folder = ReplicatedStorage:FindFirstChild(Config.BuildablesFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Config.BuildablesFolderName
		folder.Parent = ReplicatedStorage
	end

	if folder:GetAttribute("NoPlaceholders") ~= true then
		for _, def in ipairs(PLACEHOLDERS) do
			if not folder:FindFirstChild(def.name) then
				local model = Instance.new("Model")
				model.Name = def.name
				def.build(model)
				model:SetAttribute("Placeholder", true)
				model:SetAttribute("Category", def.category)
				model:SetAttribute("Price", def.price)
				model.Parent = folder
			end
		end
	end

	catalogByName, catalogOrdered = AssetCatalog.load(folder)
	print(("[Lockdown] Build menu loaded: %d assets"):format(#catalogOrdered))
end

function Buildables.get(name)
	return catalogByName[name]
end

return Buildables
