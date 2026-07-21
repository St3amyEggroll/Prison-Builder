-- DoorService: makes placed Door assets actually work. When the WARDEN
-- (the plot's owner) walks up, the door's panels slide down into the
-- floor and stop colliding; walk away and it closes. Inmates and other
-- players never trigger it — a closed door is the first real security
-- boundary in the game.
--
-- Conventions (docs/BUILDING_ASSETS.md): the asset has attribute
-- Door = true; parts named "DoorPanel" are what slides. If a door model
-- has no DoorPanel parts, the whole model fades open instead — ugly but
-- functional, so any door the map-maker builds works on day one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local DoorService = {}

local doors = {} -- model -> { player, panels = {part -> closedCF}, fadeAll, open, position }

local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function DoorService.register(model, player)
	local panels = {}
	local found = false
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "DoorPanel" then
			panels[descendant] = descendant.CFrame
			found = true
		end
	end
	if not found then
		-- Fallback: no named panel, so the whole model will fade/unblock.
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				panels[descendant] = descendant.CFrame
			end
		end
	end

	doors[model] = {
		player = player,
		panels = panels,
		fadeAll = not found,
		open = false,
		position = model:GetPivot().Position,
	}
	model.Destroying:Connect(function()
		doors[model] = nil
	end)
end

local function setOpen(model, door, shouldOpen)
	door.open = shouldOpen
	model:SetAttribute("DoorOpen", shouldOpen)
	for part, closedCF in pairs(door.panels) do
		part.CanCollide = not shouldOpen
		if door.fadeAll then
			TweenService:Create(part, TWEEN, {
				Transparency = shouldOpen and 0.8 or 0,
			}):Play()
		else
			-- Slide down into the floor, leaving a sliver visible.
			local target = shouldOpen
				and closedCF * CFrame.new(0, -(part.Size.Y * 0.92), 0)
				or closedCF
			TweenService:Create(part, TWEEN, { CFrame = target }):Play()
		end
	end
end

function DoorService.init()
	task.spawn(function()
		while true do
			task.wait(Config.DoorCheckInterval)
			for model, door in pairs(doors) do
				local character = door.player and door.player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local shouldOpen = root ~= nil
					and (root.Position - door.position).Magnitude < Config.DoorOpenDistance
				if shouldOpen ~= door.open then
					setOpen(model, door, shouldOpen)
				end
			end
		end
	end)
end

return DoorService
