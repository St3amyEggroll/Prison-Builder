-- BuildCamera: the Prison Architect view. While build mode is open the
-- camera detaches from your character and hovers above your plot,
-- looking down at a tilt (the 2.5D feel), and you fly it:
--
--   PC:     WASD / arrows pan · scroll wheel zooms · Q / E rotate 45°
--   Phone:  two-finger drag pans · pinch zooms
--
-- Your character is gently frozen in place meanwhile (so WASD pans the
-- camera instead of walking you off a roof), and everything is restored
-- the moment build mode closes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BuildCamera = {}

local PITCH = math.rad(-68) -- the 2.5D tilt: steep, but not straight down
-- The Prison Architect look is mostly LENS: a narrow field of view makes
-- the world near-orthographic (walls stay upright instead of splaying
-- outward). Distances are larger to compensate.
local FOV = 28
local MIN_DIST, MAX_DIST = 60, 420

local active = false
local focus = Vector3.new()
local yaw = 0
local targetYaw = 0
local dist = 90
local targetDist = 90
local panDragging = false -- middle-mouse held
local blendStart = 0 -- os.clock() when build mode was entered
local blendFrom = nil -- camera CFrame we eased away from
local zonePart = nil
local savedFov = 70
local connections = {}
local touches = {} -- active touch inputs (for two-finger pan/pinch)
local characterConn = nil

local function setCharacterFrozen(frozen)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = frozen
	end
end

local function clampFocus(pos)
	if not zonePart then
		return pos
	end
	-- Keep the camera's attention near the plot (a bit of overshoot is
	-- allowed so the gate area is visible).
	local localPos = zonePart.CFrame:PointToObjectSpace(pos)
	local halfX = zonePart.Size.X / 2 + 25
	local halfZ = zonePart.Size.Z / 2 + 25
	return zonePart.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPos.X, -halfX, halfX),
		localPos.Y,
		math.clamp(localPos.Z, -halfZ, halfZ)
	))
end

local function disconnectAll()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
end

function BuildCamera.enter(part)
	if active then
		return
	end
	active = true
	zonePart = part
	touches = {}

	local camera = workspace.CurrentCamera
	-- Ease in from wherever the character camera was, instead of snapping.
	blendFrom = camera.CFrame
	blendStart = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	savedFov = camera.FieldOfView
	camera.FieldOfView = FOV

	local zoneCF = part.CFrame
	focus = zoneCF.Position + Vector3.new(0, part.Size.Y / 2, 0)
	local _, ry, _ = zoneCF:ToEulerAnglesYXZ()
	yaw, targetYaw = ry, ry
	dist = math.clamp(math.max(part.Size.X, part.Size.Z) * 1.6, MIN_DIST, MAX_DIST)
	targetDist = dist
	panDragging = false

	setCharacterFrozen(true)
	-- Respawns mid-build-mode need re-freezing.
	characterConn = Players.LocalPlayer.CharacterAdded:Connect(function(character)
		if active then
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root and active then
				root.Anchored = true
			end
		end
	end)

	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		-- Zoom glides instead of stepping.
		dist += (targetDist - dist) * math.min(dt * 8, 1)

		-- Keyboard panning, aligned to the camera's current rotation.
		local pan = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			pan += Vector3.new(0, 0, -1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			pan += Vector3.new(0, 0, 1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			pan += Vector3.new(-1, 0, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			pan += Vector3.new(1, 0, 0)
		end
		-- Edge scrolling (PC): nudge the mouse against a screen edge to
		-- pan, like every city builder since forever. The corners where
		-- UI lives (toolbar bottom-left, readouts bottom-right) don't pan.
		if UserInputService.MouseEnabled and not panDragging then
			local mouse = UserInputService:GetMouseLocation()
			local viewport = camera.ViewportSize
			local margin = 14
			if mouse.X <= margin then
				pan += Vector3.new(-1, 0, 0)
			elseif mouse.X >= viewport.X - margin and mouse.Y < viewport.Y - 140 then
				pan += Vector3.new(1, 0, 0)
			end
			if mouse.Y <= margin then
				pan += Vector3.new(0, 0, -1)
			elseif mouse.Y >= viewport.Y - margin
				and mouse.X > 820 and mouse.X < viewport.X - 220
			then
				pan += Vector3.new(0, 0, 1)
			end
		end

		if pan.Magnitude > 0 then
			local speed = dist * 0.9 * dt
			focus = clampFocus(focus + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(pan.Unit * speed))
		end

		yaw += (targetYaw - yaw) * math.min(dt * 10, 1)

		local offset = CFrame.Angles(0, yaw, 0) * CFrame.Angles(PITCH, 0, 0)
		local camPos = focus - offset.LookVector * dist
		local target = CFrame.lookAt(camPos, focus)
		-- Smooth ~0.45s ease from the old camera into the build view.
		local blend = math.clamp((os.clock() - blendStart) / 0.45, 0, 1)
		if blend < 1 and blendFrom then
			local eased = 1 - (1 - blend) * (1 - blend) -- ease-out quad
			camera.CFrame = blendFrom:Lerp(target, eased)
		else
			camera.CFrame = target
		end
	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			targetDist = math.clamp(targetDist - input.Position.Z * 34, MIN_DIST, MAX_DIST)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and panDragging then
			-- Middle-mouse drag pans, RTS style.
			local scale = dist / 550
			focus = clampFocus(focus + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(
				Vector3.new(-input.Delta.X * scale, 0, -input.Delta.Y * scale)
			))
		elseif input.UserInputType == Enum.UserInputType.Touch and touches[input] then
			local before = {}
			local count = 0
			for touch, pos in pairs(touches) do
				count += 1
				before[touch] = pos
			end
			if count == 2 then
				-- Two fingers: pan by how the midpoint moved, zoom by how
				-- the finger gap changed.
				local other = nil
				for touch in pairs(touches) do
					if touch ~= input then
						other = touch
					end
				end
				local oldA = before[input]
				local newA = Vector2.new(input.Position.X, input.Position.Y)
				local posB = before[other]
				local oldMid = (oldA + posB) / 2
				local newMid = (newA + posB) / 2
				local delta = newMid - oldMid
				local scale = dist / 400
				focus = clampFocus(focus + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(
					Vector3.new(-delta.X * scale, 0, -delta.Y * scale)
				))
				local oldGap = (oldA - posB).Magnitude
				local newGap = (newA - posB).Magnitude
				if newGap > 1 and oldGap > 1 then
					targetDist = math.clamp(targetDist * (oldGap / newGap), MIN_DIST, MAX_DIST)
				end
			end
			touches[input] = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))

	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = Vector2.new(input.Position.X, input.Position.Y)
		end
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			panDragging = true
		elseif input.KeyCode == Enum.KeyCode.Q then
			targetYaw += math.rad(45)
		elseif input.KeyCode == Enum.KeyCode.E then
			targetYaw -= math.rad(45)
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = nil
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			panDragging = false
		end
	end))
end

-- How many fingers are currently down — BuildMode uses this so a
-- two-finger camera gesture never places an object.
function BuildCamera.touchCount()
	local count = 0
	for _ in pairs(touches) do
		count += 1
	end
	return count
end

function BuildCamera.exit()
	if not active then
		return
	end
	active = false
	zonePart = nil
	disconnectAll()
	if characterConn then
		characterConn:Disconnect()
		characterConn = nil
	end
	touches = {}

	setCharacterFrozen(false)
	local camera = workspace.CurrentCamera
	camera.FieldOfView = savedFov
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

return BuildCamera
