-- PAIcons: the toolbar's icon art, drawn in code.
--
-- Prison Architect's real icons are copyrighted image files, so shipping
-- them would get the game struck. Instead, every icon here is a tiny
-- picture assembled from plain Frames — rectangles, rotated rectangles
-- and rounded circles — in the same flat single-color style. Original
-- art, nothing to upload, and each icon is one function, so swapping one
-- for a real image later touches exactly one place.

local PAIcons = {}

local function rect(canvas, color, x, y, w, h, rot, round)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = canvas
	return f
end

local function outline(canvas, color, x, y, w, h, thickness, rot, round)
	local f = rect(canvas, color, x, y, w, h, rot, round)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return f
end

local DRAW = {}

function DRAW.build(c, col) -- hammer
	rect(c, col, 0.42, 0.6, 0.14, 0.62, 45)
	rect(c, col, 0.6, 0.3, 0.46, 0.22, 45)
end

function DRAW.foundations(c, col) -- house plan
	outline(c, col, 0.5, 0.64, 0.56, 0.46, 2)
	rect(c, col, 0.5, 0.28, 0.34, 0.34, 45)
end

function DRAW.walls(c, col) -- brick courses
	rect(c, col, 0.3, 0.26, 0.44, 0.16)
	rect(c, col, 0.76, 0.26, 0.36, 0.16)
	rect(c, col, 0.24, 0.5, 0.32, 0.16)
	rect(c, col, 0.68, 0.5, 0.48, 0.16)
	rect(c, col, 0.3, 0.74, 0.44, 0.16)
	rect(c, col, 0.76, 0.74, 0.36, 0.16)
end

function DRAW.flooring(c, col) -- checkerboard tiles
	rect(c, col, 0.34, 0.34, 0.3, 0.3)
	rect(c, col, 0.68, 0.68, 0.3, 0.3)
	outline(c, col, 0.68, 0.34, 0.3, 0.3, 1.5)
	outline(c, col, 0.34, 0.68, 0.3, 0.3, 1.5)
end

function DRAW.rooms(c, col) -- paint roller
	rect(c, col, 0.46, 0.28, 0.64, 0.26, 0, 0.25)
	rect(c, col, 0.72, 0.52, 0.1, 0.26)
	rect(c, col, 0.72, 0.78, 0.16, 0.24, 0, 0.3)
end

function DRAW.objects(c, col) -- chair, side on
	rect(c, col, 0.34, 0.4, 0.12, 0.56)
	rect(c, col, 0.54, 0.62, 0.52, 0.12)
	rect(c, col, 0.74, 0.82, 0.1, 0.3)
	rect(c, col, 0.38, 0.82, 0.1, 0.3)
end

function DRAW.staff(c, col) -- person with a cap
	rect(c, col, 0.5, 0.1, 0.32, 0.1)
	rect(c, col, 0.5, 0.27, 0.26, 0.26, 0, 0.5)
	rect(c, col, 0.5, 0.68, 0.5, 0.4, 0, 0.25)
end

function DRAW.utilities(c, col) -- lightning bolt
	rect(c, col, 0.56, 0.3, 0.18, 0.44, 20)
	rect(c, col, 0.44, 0.68, 0.18, 0.44, 20)
end

function DRAW.deployment(c, col) -- shield
	outline(c, col, 0.5, 0.5, 0.52, 0.52, 2, 45)
	rect(c, col, 0.5, 0.5, 0.22, 0.22, 45)
end

function DRAW.logistics(c, col) -- shipping crate
	outline(c, col, 0.5, 0.55, 0.62, 0.5, 2)
	rect(c, col, 0.5, 0.42, 0.62, 0.07)
	rect(c, col, 0.5, 0.64, 0.08, 0.32)
end

function DRAW.intelligence(c, col) -- watching eye
	outline(c, col, 0.5, 0.5, 0.8, 0.44, 2, 0, 0.5)
	rect(c, col, 0.5, 0.5, 0.2, 0.2, 0, 0.5)
end

function DRAW.quickbuild(c, col) -- room with a plus
	outline(c, col, 0.5, 0.55, 0.56, 0.46, 2)
	rect(c, col, 0.5, 0.55, 0.3, 0.08)
	rect(c, col, 0.5, 0.55, 0.08, 0.3)
end

function DRAW.planning(c, col) -- pencil
	rect(c, col, 0.56, 0.44, 0.16, 0.6, 45)
	rect(c, col, 0.28, 0.72, 0.13, 0.13, 45)
	rect(c, col, 0.78, 0.22, 0.18, 0.1, 45)
end

function DRAW.emergencies(c, col) -- alarm "!"
	rect(c, col, 0.5, 0.36, 0.16, 0.44)
	rect(c, col, 0.5, 0.76, 0.16, 0.14)
end

function DRAW.move(c, col) -- crossed arrows
	rect(c, col, 0.5, 0.5, 0.8, 0.13)
	rect(c, col, 0.5, 0.5, 0.13, 0.8)
	rect(c, col, 0.5, 0.12, 0.18, 0.18, 45)
	rect(c, col, 0.5, 0.88, 0.18, 0.18, 45)
	rect(c, col, 0.12, 0.5, 0.18, 0.18, 45)
	rect(c, col, 0.88, 0.5, 0.18, 0.18, 45)
end

function DRAW.bulldoze(c, col) -- demolish X
	rect(c, col, 0.5, 0.5, 0.16, 0.9, 45)
	rect(c, col, 0.5, 0.5, 0.16, 0.9, -45)
end

function DRAW.box(c, col) -- generic category crate
	outline(c, col, 0.5, 0.5, 0.6, 0.55, 2)
	rect(c, col, 0.5, 0.35, 0.6, 0.07)
end

-- Draw `name` into `parent` (any square-ish GuiObject). The art scales
-- with the parent, minus `inset` px of breathing room per side.
function PAIcons.draw(parent, name, color, inset)
	local canvas = Instance.new("Frame")
	canvas.Name = "IconArt"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.new(1, -2 * (inset or 7), 1, -2 * (inset or 7))
	canvas.BackgroundTransparency = 1
	local fn = DRAW[name] or DRAW.box
	fn(canvas, color)
	canvas.Parent = parent
	return canvas
end

return PAIcons
