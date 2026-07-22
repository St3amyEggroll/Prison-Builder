-- InmateService: builds inmates as LIGHTWEIGHT CUSTOM RIGS.
--
-- This is the performance rule from the game plan, made real. A default
-- Roblox character carries a Humanoid — physics, a 20-state machine,
-- network ownership — and a prison full of those melts phones. Our
-- inmates are just 6 anchored blocks in a Model: no Humanoid, no
-- physics, no collisions, no shadows. Dozens of them cost almost
-- nothing. The gentle "idle sway" that makes them feel alive is done on
-- each player's own device (see client/InmateAnimator.luau), which is
-- free for the server.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local InmateService = {}

local SKIN = Color3.fromRGB(234, 184, 146)
local SHOE = Color3.fromRGB(60, 60, 60)

local function makePart(name, size, color, cframe, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false -- players walk through inmates, never trip on them
	p.CanQuery = false -- invisible to raycasts (cheap)
	p.CanTouch = false -- fires no touch events (cheap)
	p.CastShadow = false -- shadows are a real cost with many rigs
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Builds one NPC standing at baseCF (feet on the ground at that spot).
-- cellIndex picks the name and look. opts.outfit = "worker" builds a
-- construction workman (blue overalls, hard hat) instead of an inmate.
function InmateService.spawn(baseCF, cellIndex, parent, opts)
	local outfit = opts and opts.outfit or "inmate"
	local model = Instance.new("Model")
	model.Name = (outfit == "worker" and "Worker" or "Inmate") .. cellIndex

	-- Every NPC gets a slightly different shade and sway rhythm so a
	-- full cellblock doesn't look like a copy-paste army. Seeding with
	-- cellIndex keeps each one looking the same each visit.
	local rng = Random.new(cellIndex * 7919)
	local OUTFITS = {
		worker = { torso = Color3.fromRGB(60 + rng:NextInteger(0, 20), 90, 170), hat = Color3.fromRGB(255, 200, 40), tag = Color3.fromRGB(255, 220, 120) },
		guard = { torso = Color3.fromRGB(45, 55, 100), hat = Color3.fromRGB(25, 30, 50), tag = Color3.fromRGB(150, 180, 255) },
		cook = { torso = Color3.fromRGB(235, 235, 235), hat = Color3.fromRGB(250, 250, 250), tag = Color3.fromRGB(255, 255, 255) },
		janitor = { torso = Color3.fromRGB(60, 130, 80), hat = nil, tag = Color3.fromRGB(170, 255, 190) },
	}
	local look = OUTFITS[outfit]
	local jumpsuit = look and look.torso
		or Color3.fromRGB(255, 120 + rng:NextInteger(0, 40), 25 + rng:NextInteger(0, 25))

	-- Face a random direction inside the cell.
	local root = baseCF * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	-- Classic R6 proportions: 2-stud legs, 2-stud torso, 1-stud head.
	makePart("LeftLeg", Vector3.new(1, 2, 1), SHOE, root * CFrame.new(-0.5, 1, 0), model)
	makePart("RightLeg", Vector3.new(1, 2, 1), SHOE, root * CFrame.new(0.5, 1, 0), model)
	local torso = makePart("Torso", Vector3.new(2, 2, 1), jumpsuit, root * CFrame.new(0, 3, 0), model)
	makePart("LeftArm", Vector3.new(1, 2, 1), jumpsuit, root * CFrame.new(-1.5, 3, 0), model)
	makePart("RightArm", Vector3.new(1, 2, 1), jumpsuit, root * CFrame.new(1.5, 3, 0), model)
	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2), SKIN, root * CFrame.new(0, 4.6, 0), model)

	if look and look.hat then
		-- The hat: what separates professionals from prisoners.
		makePart("HardHat", Vector3.new(1.4, 0.35, 1.4), look.hat, root * CFrame.new(0, 5.35, 0), model)
	end

	-- The classic Roblox smile, shipped inside the engine (no download).
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Floating name tag.
	local nameList = outfit ~= "inmate" and Config.WorkerNames or Config.InmateNames
	local nameIndex = ((cellIndex - 1) % #nameList) + 1
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.new(0, 130, 0, 26)
	tag.StudsOffset = Vector3.new(0, 1.4, 0)
	tag.MaxDistance = 70 -- vanishes when far away: less to draw
	tag.AlwaysOnTop = false
	local tagText = Instance.new("TextLabel")
	tagText.Size = UDim2.new(1, 0, 1, 0)
	tagText.BackgroundTransparency = 1
	tagText.Font = Enum.Font.GothamBold
	tagText.TextScaled = true
	tagText.TextColor3 = Color3.fromRGB(255, 220, 180)
	tagText.TextStrokeTransparency = 0.4
	tagText.Text = nameList[nameIndex]
	model:SetAttribute("NpcName", nameList[nameIndex])
	if look then
		tagText.TextColor3 = look.tag
	end
	tagText.Parent = tag
	tag.Parent = head

	model.PrimaryPart = torso

	-- The client-side animator finds inmates through this tag, and uses
	-- Seed so everyone sways off-beat from their neighbors.
	model:SetAttribute("Seed", rng:NextNumber(0, math.pi * 2))
	CollectionService:AddTag(model, "Inmate")

	model.Parent = parent
	return model
end

return InmateService
