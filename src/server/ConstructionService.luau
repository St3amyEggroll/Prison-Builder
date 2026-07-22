-- ConstructionService: Prison Architect's construction feel. Placements
-- arrive as BLUEPRINTS — see-through, blue-glowing, non-solid — and the
-- WORKMEN ON STAFF walk over (pathfinding around walls, through doors)
-- and hammer them into real objects. The crew is whatever StaffService
-- says it is: hire more workmen under Staff and blueprints go up faster;
-- lose them all to an unpaid payroll and construction simply stops.
--
-- A blueprint isn't functional yet: doors don't work, housing doesn't
-- count as capacity, and it doesn't satisfy room requirements until a
-- workman finishes it. Bulldozing a blueprint refunds in full.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DoorService = require(script.Parent.DoorService)
local PathService = require(script.Parent.PathService)
local StaffService = require(script.Parent.StaffService)

local ConstructionService = {}

local PIVOT_HEIGHT = 3 -- rig pivot rides 3 studs above the feet

-- player -> { zone, busy = {model = true}, queue = { {model, asset, saved} } }
local records = {}
local completionListeners = {} -- fns(player, model, asset)

local function ghostify(model)
	local saved = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(saved, {
				part = descendant,
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
			})
			descendant.Transparency = math.clamp(descendant.Transparency + 0.6, 0.6, 1)
			descendant.CanCollide = false
		end
	end
	local glow = Instance.new("Highlight")
	glow.Name = "BlueprintGlow"
	glow.FillColor = Color3.fromRGB(90, 160, 255)
	glow.FillTransparency = 0.75
	glow.OutlineColor = Color3.fromRGB(120, 190, 255)
	glow.Adornee = model
	glow.Parent = model
	return saved
end

local function completeBlueprint(player, job)
	local model = job.model
	if model.Parent == nil then
		return
	end
	for _, entry in ipairs(job.saved) do
		if entry.part.Parent ~= nil then
			entry.part.Transparency = entry.transparency
			entry.part.CanCollide = entry.canCollide
		end
	end
	local glow = model:FindFirstChild("BlueprintGlow")
	if glow then
		glow:Destroy()
	end
	model:SetAttribute("Blueprint", nil)

	-- Now it's real: doors start working, housing counts, rooms re-check.
	if job.asset.door then
		DoorService.register(model, player)
	end
	for _, fn in ipairs(completionListeners) do
		task.spawn(fn, player, model, job.asset)
	end

	-- A little "ta-da": green flash + a thunk.
	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.fromRGB(120, 255, 140)
	flash.FillTransparency = 0.5
	flash.OutlineColor = Color3.fromRGB(120, 255, 140)
	flash.Adornee = model
	flash.Parent = model
	Debris:AddItem(flash, 0.35)
	local root = model:FindFirstChildWhichIsA("BasePart")
	if root then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.Volume = 0.4
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, 2)
	end
end

-- Called by PlacementService for every non-instant placement.
function ConstructionService.queueBlueprint(player, _zone, model, asset)
	local rec = records[player]
	if not rec then
		-- No crew (shouldn't happen) — build it instantly rather than never.
		if asset.door then
			DoorService.register(model, player)
		end
		return
	end
	model:SetAttribute("Blueprint", true)
	local saved = ghostify(model)
	table.insert(rec.queue, { model = model, asset = asset, saved = saved })
end

function ConstructionService.onCompleted(fn)
	table.insert(completionListeners, fn)
end

-- Wiring (called by PlotService) ------------------------------------------

function ConstructionService.assignPlayer(player, zone)
	-- The workman models themselves live with StaffService — this record
	-- only tracks the job queue and who's mid-hammer.
	records[player] = { zone = zone, busy = {}, queue = {} }
end

function ConstructionService.releasePlayer(player)
	records[player] = nil
end

function ConstructionService.init()
	task.spawn(function()
		while true do
			task.wait(0.6)
			for player, rec in pairs(records) do
				-- Drop finished/bulldozed jobs off the front of the queue.
				while rec.queue[1] and rec.queue[1].model.Parent == nil do
					table.remove(rec.queue, 1)
				end
				if #rec.queue == 0 then
					continue
				end

				-- Prune busy marks for workmen who quit/were fired mid-job.
				for model in pairs(rec.busy) do
					if model.Parent == nil then
						rec.busy[model] = nil
					end
				end

				-- The crew is the Workmen on staff, right now.
				for _, workman in ipairs(StaffService.getStaff(player, "Workman")) do
					local job = table.remove(rec.queue, 1)
					if not job then
						break
					end
					if rec.busy[workman] then
						-- Not available: put the job back for the next one.
						table.insert(rec.queue, 1, job)
						continue
					end
					if job.model.Parent == nil then
						continue
					end

					-- Pathfind to the blueprint. Unreachable? Requeue at the
					-- back and try again later (build a door!).
					local footprint = {
						gx = job.model:GetAttribute("GX") or 0,
						gz = job.model:GetAttribute("GZ") or 0,
						w = 1,
						d = 1,
					}
					local boxCF, boxSize = job.model:GetBoundingBox()
					footprint.w = math.max(1, math.round(boxSize.X / Config.GridSize))
					footprint.d = math.max(1, math.round(boxSize.Z / Config.GridSize))
					local targetPos = Vector3.new(
						boxCF.Position.X,
						rec.zone.part.Position.Y + rec.zone.part.Size.Y / 2,
						boxCF.Position.Z
					)
					local fromPos = workman:GetPivot().Position - Vector3.new(0, PIVOT_HEIGHT, 0)
					local route = PathService.findRoute(rec.zone, fromPos, footprint, targetPos)
					if not route then
						table.insert(rec.queue, job)
						continue
					end
					-- Walk to the square BESIDE the job, never into it — the
					-- route's final point is the blueprint's center, and ending
					-- the walk there desynced client/server (the teleport bug).
					if #route > 1 then
						table.remove(route)
					end

					rec.busy[workman] = true
					local duration = PathService.startWalk(workman, route, Config.WorkerSpeed)
					local cells = footprint.w * footprint.d
					local buildTime = Config.BuildTimeBase + Config.BuildTimePerCell * cells

					task.spawn(function()
						task.wait(duration)
						if workman.Parent == nil then
							-- They quit mid-walk: the job goes back on the pile.
							table.insert(rec.queue, 1, job)
							return
						end
						-- Arrive next to the job and start hammering.
						local stand = route[#route]
						local standCF
						if (stand - targetPos).Magnitude > 0.05 then
							standCF = CFrame.lookAt(stand, targetPos)
						else
							standCF = CFrame.new(stand)
						end
						PathService.finishWalk(workman, standCF * CFrame.new(0, PIVOT_HEIGHT, 0))
						workman:SetAttribute("Working", true)
						task.wait(buildTime)
						workman:SetAttribute("Working", nil)
						if job.model.Parent ~= nil then
							completeBlueprint(player, job)
						end
						rec.busy[workman] = nil
					end)
				end
			end
		end
	end)
end

return ConstructionService
