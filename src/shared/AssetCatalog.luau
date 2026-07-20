-- AssetCatalog: reads the Buildables folder and measures every Model in
-- it, producing the list the build menu shows and the placement system
-- uses. Server and client both run this over the same folder, so they
-- always agree on sizes.
--
-- Drop ANY Model into ReplicatedStorage/Buildables and it shows up in
-- the build menu automatically — that's the whole convention. Optional
-- extras (set as Attributes on the Model):
--   SpawnsInmate (boolean): marks the asset as housing for one prisoner.
--   Category (string): which bottom-bar button it lives under
--     ("Walls & Doors", "Flooring", "Objects", or any new name you like —
--     unknown names become new toolbar buttons automatically).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AssetCatalog = {}

-- Returns two views of the same data:
--   byName: { ["Wall"] = asset, ... }        (for lookups)
--   ordered: { asset, asset, ... }           (alphabetical, for the menu)
-- Each asset: { name, model, size, pivotOffset, cellsW, cellsD, spawnsInmate }
function AssetCatalog.load(folder)
	local byName = {}
	local ordered = {}

	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local boxCF, boxSize = model:GetBoundingBox()
			-- The tiny 0.05 forgiveness means a model exactly GridSize
			-- studs wide counts as 1 square, not accidentally 2.
			local asset = {
				name = model.Name,
				model = model,
				size = boxSize,
				-- Where the model's pivot sits relative to its bounding
				-- box — lets placement rest ANY model on the ground, no
				-- matter how it was built or grouped.
				pivotOffset = boxCF:ToObjectSpace(model:GetPivot()),
				cellsW = math.max(1, math.ceil((boxSize.X - 0.05) / Config.GridSize)),
				cellsD = math.max(1, math.ceil((boxSize.Z - 0.05) / Config.GridSize)),
				spawnsInmate = model:GetAttribute("SpawnsInmate") == true,
				category = (function()
					local raw = model:GetAttribute("Category")
					return (type(raw) == "string" and raw ~= "") and raw or "Objects"
				end)(),
			}
			byName[asset.name] = asset
			table.insert(ordered, asset)
		end
	end

	table.sort(ordered, function(a, b)
		return a.name < b.name
	end)

	return byName, ordered
end

return AssetCatalog
