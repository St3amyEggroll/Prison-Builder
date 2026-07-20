-- InmateAnimator: makes the blocky inmates feel alive without costing
-- anything. Server-side they are frozen statues; on each player's own
-- device this script gives nearby ones a slow idle sway (a little turn
-- of the shoulders, a tiny breathing bob).
--
-- Performance rules baked in:
--   * Inmates farther than CULL_DISTANCE from the camera don't animate
--     at all — you can't see a 0.1-stud bob from 60 studs away.
--   * Everything is plain CFrame math on anchored parts: no Humanoids,
--     no physics, no animation tracks. A phone shrugs at 100 of these.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local InmateAnimator = {}

local CULL_DISTANCE = 160

function InmateAnimator.start()
	-- model -> { base = original pose, seed = personal rhythm offset }
	local tracked = {}

	local function watch(model)
		-- The model streams in part-by-part; wait until its PrimaryPart
		-- (the torso) exists before measuring its resting pose.
		task.spawn(function()
			local tries = 0
			while model.PrimaryPart == nil and model.Parent ~= nil and tries < 100 do
				tries += 1
				task.wait(0.1)
			end
			if model.PrimaryPart and model.Parent then
				tracked[model] = {
					base = model:GetPivot(),
					seed = model:GetAttribute("Seed") or 0,
				}
			end
		end)
	end

	for _, model in ipairs(CollectionService:GetTagged("Inmate")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Inmate"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Inmate"):Connect(function(model)
		tracked[model] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()

		for model, info in pairs(tracked) do
			if model.Parent == nil then
				tracked[model] = nil
				continue
			end
			local distance = (info.base.Position - camPos).Magnitude
			if distance > CULL_DISTANCE then
				continue
			end
			-- Slow shoulder sway + faint breathing bob, offset by each
			-- inmate's personal seed so the cellblock never syncs up.
			local sway = math.sin(t * 0.9 + info.seed) * 0.25
			local bob = math.abs(math.sin(t * 1.7 + info.seed)) * 0.08
			model:PivotTo(info.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, 0))
		end
	end)
end

return InmateAnimator
