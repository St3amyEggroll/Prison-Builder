-- InmateAnimator: brings the blocky prisoners to life — entirely on each
-- player's own device, so a full prison of them costs the server nothing.
--
-- Every inmate is in one of three states, driven by attributes the
-- server stamps on the model:
--   HANDCUFFED  (Handcuffed = true, no escort running)
--     Stands still at the gate, hands bound in front, tiny nervous bob.
--   ESCORTED    (EscortFrom/To/Start/Dur set)
--     Walks a straight line to their new cell, legs swinging, still cuffed.
--   HOUSED      (cuffs off)
--     Free-roams around their home spot: idle a while, amble to a random
--     nearby point, repeat. This is the "prison feels alive" layer.
--
-- Performance rules: no Humanoids, no physics — just CFrame math on
-- anchored parts, skipped entirely for inmates far from the camera.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local InmateAnimator = {}

local CULL_DISTANCE = 170
local LIMB_NAMES = { "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

function InmateAnimator.start()
	local tracked = {}

	local REQUIRED_PARTS = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
	local function rigComplete(model)
		for _, partName in ipairs(REQUIRED_PARTS) do
			if not model:FindFirstChild(partName) then
				return false
			end
		end
		return model.PrimaryPart ~= nil
	end

	local function watch(model)
		task.spawn(function()
			-- Wait for the WHOLE rig to replicate. Animating a half-arrived
			-- inmate leaves the late parts behind — instant body horror.
			local tries = 0
			while not rigComplete(model) and model.Parent ~= nil and tries < 100 do
				tries += 1
				task.wait(0.1)
			end
			if not (rigComplete(model) and model.Parent) then
				return
			end

			-- Work in FEET space: the model's pivot is its torso, 3 studs
			-- above the ground — everything here is measured from the feet
			-- so it lines up with the server's floor-level escort positions.
			local feetCF = model:GetPivot() * CFrame.new(0, -3, 0)
			local info = {
				parts = {},
				offsets = {}, -- part -> resting CFrame relative to the root
				hips = {}, -- limb part -> pivot point at the TOP of the limb
				seed = model:GetAttribute("Seed") or 0,
				pos = feetCF.Position,
				home = feetCF.Position,
				yaw = select(2, feetCF:ToEulerAnglesYXZ()),
				mode = "idle",
				timer = 1 + math.random() * 4,
				target = nil,
				phase = 0,
				escortTo = nil,
				pathKey = nil, -- which EscortStart the cached path belongs to
				path = nil, -- { points = {Vector3...}, lengths = {seg lens}, total }
			}
			for _, part in ipairs(model:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "Cuffs" then
					info.parts[part.Name] = part
					info.offsets[part.Name] = feetCF:ToObjectSpace(part.CFrame)
				end
			end
			for _, limbName in ipairs(LIMB_NAMES) do
				if info.offsets[limbName] then
					-- Limbs rotate from their top (the shoulder / hip).
					info.hips[limbName] = info.offsets[limbName] * CFrame.new(0, 1, 0)
				end
			end

			-- When the server finishes an escort it clears EscortStart —
			-- that's the moment this inmate's home becomes the cell.
			model:GetAttributeChangedSignal("EscortStart"):Connect(function()
				if model:GetAttribute("EscortStart") == nil and info.escortTo then
					info.pos = info.escortTo
					info.home = info.escortTo
					info.escortTo = nil
					info.mode = "idle"
					info.timer = 1 + math.random() * 3
				end
			end)

			tracked[model] = info
		end)
	end

	for _, model in ipairs(CollectionService:GetTagged("Inmate")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Inmate"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Inmate"):Connect(function(model)
		tracked[model] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		local t = os.clock()

		for model, info in pairs(tracked) do
			if model.Parent == nil then
				tracked[model] = nil
				continue
			end
			if (info.pos - camPos).Magnitude > CULL_DISTANCE then
				continue
			end

			local cuffed = model:GetAttribute("Handcuffed") == true
			local escortStart = model:GetAttribute("EscortStart")
			local walking = false
			local bob = 0

			local working = model:GetAttribute("Working") == true

			if escortStart then
				-- WALKING: follow the server's waypoint path on a shared
				-- clock, so everyone sees the same walk. (Falls back to a
				-- straight from->to line if no path was stamped.)
				local dur = model:GetAttribute("EscortDur") or 1
				if info.pathKey ~= escortStart then
					info.pathKey = escortStart
					info.path = nil
					local pathString = model:GetAttribute("EscortPath")
					local y = model:GetAttribute("EscortY") or info.pos.Y
					if type(pathString) == "string" then
						local points = {}
						for pair in string.gmatch(pathString, "[^|]+") do
							local xs, zs = string.match(pair, "([^,]+),([^,]+)")
							local px, pz = tonumber(xs), tonumber(zs)
							if px and pz then
								table.insert(points, Vector3.new(px, y, pz))
							end
						end
						if #points >= 2 then
							local lengths, total = {}, 0
							for i = 2, #points do
								local seg = (points[i] - points[i - 1]).Magnitude
								table.insert(lengths, seg)
								total += seg
							end
							info.path = { points = points, lengths = lengths, total = math.max(total, 0.001) }
						end
					end
				end

				local alpha = math.clamp((now - escortStart) / dur, 0, 1)
				if info.path then
					local walked = alpha * info.path.total
					local points = info.path.points
					for i = 1, #info.path.lengths do
						local seg = info.path.lengths[i]
						if walked <= seg or i == #info.path.lengths then
							local t2 = seg > 0 and math.clamp(walked / seg, 0, 1) or 1
							info.pos = points[i]:Lerp(points[i + 1], t2)
							local dir = points[i + 1] - points[i]
							if dir.Magnitude > 0.01 then
								info.yaw = math.atan2(-dir.X, -dir.Z)
							end
							break
						end
						walked -= seg
					end
					info.escortTo = points[#points]
				else
					local from = model:GetAttribute("EscortFrom")
					local to = model:GetAttribute("EscortTo")
					if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
						info.escortTo = to
						info.pos = from:Lerp(to, alpha)
						local dir = to - from
						if dir.Magnitude > 0.01 then
							info.yaw = math.atan2(-dir.X, -dir.Z)
						end
					end
				end
				walking = alpha < 1
			elseif working then
				-- HAMMERING a blueprint: plant the feet, swing the arms.
				bob = math.abs(math.sin(t * 6 + info.seed)) * 0.06
			elseif cuffed then
				-- HANDCUFFED at the gate: stand still, shift nervously.
				bob = math.abs(math.sin(t * 1.4 + info.seed)) * 0.05
			else
				-- HOUSED: the idle/amble loop.
				if info.mode == "idle" then
					bob = math.abs(math.sin(t * 1.7 + info.seed)) * 0.08
					info.yaw += math.sin(t * 0.5 + info.seed) * 0.003
					info.timer -= dt
					if info.timer <= 0 then
						local angle = math.random() * math.pi * 2
						local radius = 1 + math.random() * (Config.WanderRadius - 1)
						info.target = info.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
						info.mode = "walk"
					end
				else
					local dir = info.target - info.pos
					local flat = Vector3.new(dir.X, 0, dir.Z)
					if flat.Magnitude < 0.2 then
						info.mode = "idle"
						info.timer = 2 + math.random() * 5
					else
						local step = math.min(Config.WalkSpeed * dt, flat.Magnitude)
						info.pos += flat.Unit * step
						local wantYaw = math.atan2(-flat.X, -flat.Z)
						local diff = math.atan2(math.sin(wantYaw - info.yaw), math.cos(wantYaw - info.yaw))
						info.yaw += diff * math.min(dt * 8, 1)
						walking = true
					end
				end
			end

			if walking then
				info.phase += dt * 9
				bob = math.abs(math.sin(info.phase)) * 0.12
			end

			-- Write the skeleton: root, then each limb with its motion.
			local root = CFrame.new(info.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, info.yaw, 0)
			local swing = walking and math.sin(info.phase) * 0.5 or 0

			for name, part in pairs(info.parts) do
				if name == "LeftLeg" or name == "RightLeg" then
					local legSwing = name == "LeftLeg" and swing or -swing
					part.CFrame = root * info.hips[name] * CFrame.Angles(legSwing, 0, 0) * CFrame.new(0, -1, 0)
				elseif name == "LeftArm" or name == "RightArm" then
					local armCF
					if working then
						-- Alternating hammer swings.
						local swingPhase = t * 10 + info.seed + (name == "LeftArm" and 0 or math.pi)
						armCF = CFrame.Angles(-0.6 + math.sin(swingPhase) * 0.55, 0, 0)
					elseif cuffed then
						-- Hands bound in front at the waist.
						armCF = CFrame.Angles(math.rad(-50), 0, name == "LeftArm" and math.rad(12) or math.rad(-12))
					elseif walking then
						armCF = CFrame.Angles(name == "LeftArm" and -swing * 0.7 or swing * 0.7, 0, 0)
					else
						armCF = CFrame.Angles(math.sin(t * 1.1 + info.seed) * 0.04, 0, 0)
					end
					part.CFrame = root * info.hips[name] * armCF * CFrame.new(0, -1, 0)
				else
					part.CFrame = root * info.offsets[name]
				end
			end

			-- The cuffs prop rides along in front of the waist.
			local cuffsPart = model:FindFirstChild("Cuffs")
			if cuffsPart then
				cuffsPart.CFrame = root * CFrame.new(0, 2.3, -1.05)
			end
		end
	end)
end

return InmateAnimator
