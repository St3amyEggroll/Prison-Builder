-- GridMath: the snapping math, shared by server and client so the ghost
-- preview on your screen and the server's final placement always agree.
--
-- Grid coordinates are integers: (0, 0) is one corner of a plot zone,
-- and each step is Config.GridSize studs. An asset occupies a rectangle
-- of w x d grid squares; (gx, gz) is the rectangle's smallest corner.
-- Zones can sit anywhere in the map at any rotation — all math happens
-- in the zone's own local space, so grids stay straight on rotated zones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GRID = Config.GridSize

local GridMath = {}

-- Measure a zone Part once: how many grid squares fit, and the CFrame of
-- the grid's corner on the zone's TOP surface.
function GridMath.zoneInfo(zonePart)
	local size = zonePart.Size
	local cols = math.max(1, math.floor(size.X / GRID))
	local rows = math.max(1, math.floor(size.Z / GRID))
	local corner = zonePart.CFrame * CFrame.new(-cols * GRID / 2, size.Y / 2, -rows * GRID / 2)
	return {
		part = zonePart,
		corner = corner,
		cols = cols,
		rows = rows,
	}
end

-- An asset's footprint in grid squares, after rotation (a 1x3 wall
-- turned 90 degrees occupies 3x1).
function GridMath.footprint(asset, rot)
	if rot % 2 == 0 then
		return asset.cellsW, asset.cellsD
	end
	return asset.cellsD, asset.cellsW
end

-- World-space CFrame of the CENTER of a w x d footprint whose corner is
-- at grid square (gx, gz), sitting on the zone's top surface.
function GridMath.regionCenter(zoneInfo, gx, gz, w, d)
	return zoneInfo.corner * CFrame.new((gx + w / 2) * GRID, 0, (gz + d / 2) * GRID)
end

-- Convert a world position (wherever the player is pointing) into the
-- nearest valid grid corner for a w x d footprint, clamped inside the zone.
function GridMath.worldToCell(zoneInfo, worldPos, w, d)
	local localPos = zoneInfo.corner:PointToObjectSpace(worldPos)
	local gx = math.floor(localPos.X / GRID - w / 2 + 0.5)
	local gz = math.floor(localPos.Z / GRID - d / 2 + 0.5)
	gx = math.clamp(gx, 0, math.max(0, zoneInfo.cols - w))
	gz = math.clamp(gz, 0, math.max(0, zoneInfo.rows - d))
	return gx, gz
end

function GridMath.inBounds(zoneInfo, gx, gz, w, d)
	return gx >= 0 and gz >= 0 and gx + w <= zoneInfo.cols and gz + d <= zoneInfo.rows
end

-- Turn a drag from square (x1,z1) to (x2,z2) into a straight line of
-- squares along the dominant axis (PA-style wall dragging). Returns the
-- line's start square, the axis ("x" or "z"), and how many squares.
function GridMath.lineCells(x1, z1, x2, z2)
	local dx, dz = x2 - x1, z2 - z1
	if math.abs(dx) >= math.abs(dz) then
		return math.min(x1, x2), z1, "x", math.abs(dx) + 1
	end
	return x1, math.min(z1, z2), "z", math.abs(dz) + 1
end

-- The final world CFrame for a placed asset: footprint center, raised by
-- half the asset's height, spun by the rotation, then adjusted by the
-- asset's own pivot offset so ANY model lands resting on the ground.
function GridMath.placementPivot(zoneInfo, asset, gx, gz, rot)
	local w, d = GridMath.footprint(asset, rot)
	local center = GridMath.regionCenter(zoneInfo, gx, gz, w, d)
	local boundingBoxTarget = center
		* CFrame.Angles(0, math.rad(rot * 90), 0)
		* CFrame.new(0, asset.size.Y / 2, 0)
	return boundingBoxTarget * asset.pivotOffset, center * CFrame.Angles(0, math.rad(rot * 90), 0)
end

return GridMath
