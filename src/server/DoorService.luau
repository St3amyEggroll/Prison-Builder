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

local CollectionService = game:GetService("CollectionService")
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

-- Re-measure after the Move tool relocates a door.
function DoorService.updatePosition(model)
	local door = doors[model]
	if door then
		door.position = model:GetPivot().Position
		for part in pairs(door.panels) do
			door.panels[part] = door.open
				and part.CFrame * CFrame.new(0, part.Size.Y * 0.92, 0)
				or part.CFrame
		end
	end
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
			-- NPCs mid-walk (escorted prisoners, workmen on the way to a
			-- job) also open doors — a guard is implied. Their live position
			-- must be computed from the walk attributes: the client animates
			-- the walk, so server-side part positions are stale until it ends.
			local now = workspace:GetServerTimeNow()
			local walkers = {}
			for _, npc in ipairs(CollectionService:GetTagged("Inmate")) do
				local start = npc:GetAttribute("EscortStart")
				if start ~= nil then
					local duration = npc:GetAttribute("EscortDur") or 1
					local alpha = math.clamp((now - start) / duration, 0, 1)
					local pathString = npc:GetAttribute("EscortPath")
					if type(pathString) == "string" then
						-- Decode the waypoints and find the point at `alpha`
						-- along the path's total length.
						local y = npc:GetAttribute("EscortY") or 0
						local points = {}
						for pair in string.gmatch(pathString, "[^|]+") do
							local xs, zs = string.match(pair, "([^,]+),([^,]+)")
							local x, z = tonumber(xs), tonumber(zs)
							if x and z then
								table.insert(points, Vector3.new(x, y, z))
							end
						end
						if #points >= 2 then
							local total = 0
							for i = 2, #points do
								total += (points[i] - points[i - 1]).Magnitude
							end
							local walked = alpha * total
							for i = 2, #points do
								local seg = (points[i] - points[i - 1]).Magnitude
								if walked <= seg or i == #points then
									local t = seg > 0 and math.clamp(walked / seg, 0, 1) or 1
									table.insert(walkers, points[i - 1]:Lerp(points[i], t))
									break
								end
								walked -= seg
							end
						end
					else
						local from = npc:GetAttribute("EscortFrom")
						local to = npc:GetAttribute("EscortTo")
						if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
							table.insert(walkers, from:Lerp(to, alpha))
						end
					end
				end
			end

			for model, door in pairs(doors) do
				local character = door.player and door.player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local shouldOpen = root ~= nil
					and (root.Position - door.position).Magnitude < Config.DoorOpenDistance
				if not shouldOpen then
					for _, pos in ipairs(walkers) do
						if (pos - door.position).Magnitude < Config.DoorOpenDistance then
							shouldOpen = true
							break
						end
					end
				end
				if shouldOpen ~= door.open then
					setOpen(model, door, shouldOpen)
				end
			end
		end
	end)
end

return DoorService
