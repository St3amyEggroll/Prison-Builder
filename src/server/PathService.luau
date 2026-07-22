-- PathService: A* pathfinding over the build grid, plus the shared
-- "walk an NPC along a path" machinery that prisoners and workmen use.
--
-- Walkability comes straight from the placement grid: empty squares and
-- Flooring are walkable, walls/fences/objects block, and DOORS COUNT AS
-- PASSABLE (escorts and workmen are allowed through). No route at all —
-- a fully sealed prison with no door — means the walk fails, and the
-- caller shows the player why ("the gate can't reach your cells!").
--
-- The walk itself stays cheap: the server stamps the path onto the model
-- as attributes (a string of waypoints + a start time on the shared
-- server clock) and does ONE authoritative move at the end; every
-- client's InmateAnimator plays the same walk locally.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GridMath = require(ReplicatedStorage.Shared.GridMath)
local Buildables = require(script.Parent.Buildables)

local PathService = {}

-- Injected by the bootstrap (PlacementService.cellAsset) — a direct
-- require would create a dependency cycle.
local cellLookup = nil
function PathService.setCellLookup(fn)
	cellLookup = fn
end

local function isWalkable(zone, x, z)
	if x < 0 or x >= zone.info.cols or z < 0 or z >= zone.info.rows then
		return false
	end
	if zone.unlocked and not zone.unlocked[x .. ":" .. z] then
		return false -- land they haven't bought yet
	end
	local assetName = cellLookup and cellLookup(zone, x, z)
	if not assetName then
		return true
	end
	local asset = Buildables.get(assetName)
	return asset ~= nil and (asset.category == "Flooring" or asset.door)
end

-- Plain A* on the zone grid (max ~1024 squares — instant).
local function aStar(zone, sx, sz, gx, gz)
	local function key(x, z)
		return x .. ":" .. z
	end
	local open = { { x = sx, z = sz, g = 0, f = math.abs(gx - sx) + math.abs(gz - sz) } }
	local bestG = { [key(sx, sz)] = 0 }
	local cameFrom = {}
	local steps = 0

	while #open > 0 and steps < 4096 do
		steps += 1
		-- Pull the lowest-f node (linear scan is fine at this scale).
		local bestIndex = 1
		for i = 2, #open do
			if open[i].f < open[bestIndex].f then
				bestIndex = i
			end
		end
		local current = table.remove(open, bestIndex)
		if current.x == gx and current.z == gz then
			-- Rebuild the path.
			local path = { { current.x, current.z } }
			local k = key(current.x, current.z)
			while cameFrom[k] do
				local prev = cameFrom[k]
				table.insert(path, 1, { prev[1], prev[2] })
				k = key(prev[1], prev[2])
			end
			return path
		end
		for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, nz = current.x + step[1], current.z + step[2]
			if isWalkable(zone, nx, nz) then
				local nk = key(nx, nz)
				local g = current.g + 1
				if bestG[nk] == nil or g < bestG[nk] then
					bestG[nk] = g
					cameFrom[nk] = { current.x, current.z }
					table.insert(open, {
						x = nx,
						z = nz,
						g = g,
						f = g + math.abs(gx - nx) + math.abs(gz - nz),
					})
				end
			end
		end
	end
	return nil
end

-- Drop waypoints that continue in a straight line.
local function compress(path)
	if #path <= 2 then
		return path
	end
	local out = { path[1] }
	for i = 2, #path - 1 do
		local a, b, c = out[#out], path[i], path[i + 1]
		local abx, abz = b[1] - a[1], b[2] - a[2]
		local bcx, bcz = c[1] - b[1], c[2] - b[2]
		if abx * bcz - abz * bcx ~= 0 then
			table.insert(out, b)
		end
	end
	table.insert(out, path[#path])
	return out
end

-- Find a route from a world position to (adjacent to) a footprint.
-- Returns an array of world Vector3 waypoints ending AT targetPos, or nil.
function PathService.findRoute(zone, fromPos, footprint, targetPos)
	-- Wherever they're standing counts as the start even if that square
	-- is technically blocked — A* only needs the neighbors to work.
	local sx, sz = GridMath.worldToCell(zone.info, fromPos, 1, 1)

	-- Candidate goals: every walkable square hugging the footprint edge.
	local candidates = {}
	for x = footprint.gx - 1, footprint.gx + footprint.w do
		for z = footprint.gz - 1, footprint.gz + footprint.d do
			local onEdge = x < footprint.gx or x > footprint.gx + footprint.w - 1
				or z < footprint.gz or z > footprint.gz + footprint.d - 1
			if onEdge and isWalkable(zone, x, z) then
				table.insert(candidates, { x, z, math.abs(x - sx) + math.abs(z - sz) })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a[3] < b[3]
	end)

	for i = 1, math.min(#candidates, 4) do
		local goal = candidates[i]
		local cells = aStar(zone, sx, sz, goal[1], goal[2])
		if cells then
			cells = compress(cells)
			local points = {}
			for _, cell in ipairs(cells) do
				table.insert(points, GridMath.regionCenter(zone.info, cell[1], cell[2], 1, 1).Position)
			end
			-- Start exactly where they stand, end exactly at the target.
			points[1] = Vector3.new(fromPos.X, points[1] and points[1].Y or fromPos.Y, fromPos.Z)
			table.insert(points, targetPos)
			return points
		end
	end
	return nil
end

-- Stamp a path walk onto a model (clients animate it) and return its
-- duration. The caller is responsible for finishing the walk.
function PathService.startWalk(model, points, speed)
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	local duration = math.max(0.5, total / speed)

	local encoded = {}
	for _, p in ipairs(points) do
		table.insert(encoded, ("%.1f,%.1f"):format(p.X, p.Z))
	end
	model:SetAttribute("EscortPath", table.concat(encoded, "|"))
	model:SetAttribute("EscortY", points[1].Y)
	model:SetAttribute("EscortFrom", points[1])
	model:SetAttribute("EscortTo", points[#points])
	model:SetAttribute("EscortDur", duration)
	model:SetAttribute("EscortStart", workspace:GetServerTimeNow())
	return duration
end

-- Clear the walk attributes and drop the model at its destination.
-- finalCF is where the pivot ends up (remember the pivot rides 3 studs
-- above the feet).
function PathService.finishWalk(model, finalCF)
	if finalCF then
		model:PivotTo(finalCF)
	end
	model:SetAttribute("EscortStart", nil)
	model:SetAttribute("EscortPath", nil)
	model:SetAttribute("EscortDur", nil)
	model:SetAttribute("EscortFrom", nil)
	model:SetAttribute("EscortTo", nil)
	model:SetAttribute("EscortY", nil)
end

-- Convenience: is this square reachable at all from that position?
function PathService.canReach(zone, fromPos, footprint, targetPos)
	return PathService.findRoute(zone, fromPos, footprint, targetPos) ~= nil
end

-- Walk speed shared by escorts unless the caller overrides.
PathService.DefaultSpeed = Config.EscortSpeed

return PathService
