-- UIKit: the shared Prison Architect look. One palette, a few builders,
-- and a panel coordinator so only one menu is ever open at a time.
--
-- PA's HUD is steel-gray panels with sharp corners, 1px borders and
-- blueprint-blue buttons — so that's what everything here produces. The
-- art itself is ours (see PAIcons); only the layout language is PA's.
-- Every client menu builds through here, so restyling the whole game is
-- one file.

local UIKit = {}

-- Palette -----------------------------------------------------------------

UIKit.STRIP = Color3.fromRGB(24, 28, 33) -- the toolbar strip / tooltips
UIKit.PANEL = Color3.fromRGB(33, 37, 43) -- menu + readout bodies
UIKit.TITLE = Color3.fromRGB(45, 51, 59) -- menu title bars

UIKit.BTN = Color3.fromRGB(42, 58, 76) -- blueprint-blue buttons
UIKit.BTN_HOVER = Color3.fromRGB(54, 74, 96)
UIKit.BTN_ON = Color3.fromRGB(66, 110, 152) -- pressed / active tab
UIKit.BTN_DARK = Color3.fromRGB(27, 32, 38) -- locked tabs (PA's dark ones)

UIKit.EDGE = Color3.fromRGB(106, 137, 168) -- thin border on live buttons
UIKit.EDGE_DIM = Color3.fromRGB(56, 66, 78) -- border on panels/locked tabs

UIKit.ROW_HOVER = Color3.fromRGB(52, 58, 66) -- menu row under the mouse
UIKit.ROW_ON = Color3.fromRGB(45, 95, 138) -- selected menu row

UIKit.ICON = Color3.fromRGB(208, 224, 238) -- icon art on live buttons
UIKit.ICON_DARK = Color3.fromRGB(74, 85, 96) -- icon art on locked ones

UIKit.TEXT = Color3.fromRGB(232, 236, 239)
UIKit.DIM = Color3.fromRGB(154, 164, 173)
UIKit.GOOD = Color3.fromRGB(125, 220, 132)
UIKit.WARN = Color3.fromRGB(232, 179, 75)
UIKit.BAD = Color3.fromRGB(224, 94, 80)

-- Builders ----------------------------------------------------------------

function UIKit.stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function UIKit.pad(inst, px)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = u, u, u, u
	p.Parent = inst
	return p
end

-- A PA panel: sharp corners, PANEL fill, 1px EDGE_DIM border.
function UIKit.panel(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name or "Panel"
	frame.BackgroundColor3 = UIKit.PANEL
	frame.BackgroundTransparency = 0.03
	frame.BorderSizePixel = 0
	UIKit.stroke(frame, UIKit.EDGE_DIM, 1, 0)
	frame.Parent = parent
	return frame
end

-- The 26px title bar every PA menu carries: name left, × on the right.
function UIKit.titleBar(panel, text)
	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 26)
	bar.BackgroundColor3 = UIKit.TITLE
	bar.BorderSizePixel = 0
	bar.Parent = panel

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Size = UDim2.new(1, -40, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIKit.TEXT
	label.Text = text
	label.Parent = bar

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.new(0, 26, 0, 26)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.GothamBold
	close.TextSize = 14
	close.TextColor3 = UIKit.DIM
	close.Text = "×"
	close.Activated:Connect(function()
		UIKit.closeAll()
	end)
	close.Parent = bar
	return bar
end

-- Panel coordination ------------------------------------------------------

local panels = {} -- frame -> true

-- Show `panel` and hide every other registered panel. Showing an already
-- visible panel hides it instead (toggle). Returns the new visibility.
function UIKit.showOnly(panel)
	local wasVisible = panel and panel.Visible
	for other in pairs(panels) do
		other.Visible = false
	end
	if panel and not wasVisible then
		panel.Visible = true
		return true
	end
	return false
end

function UIKit.registerPanel(panel)
	panels[panel] = true
	panel.Visible = false
end

function UIKit.closeAll()
	for other in pairs(panels) do
		other.Visible = false
	end
end

return UIKit
