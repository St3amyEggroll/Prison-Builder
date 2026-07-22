-- UIKit: shared look-and-feel so every panel matches, plus two things
-- that fix the "scattered corners / overlapping panels" mess:
--   * a single bottom-right DOCK of icon buttons (Build, Intake, Staff…)
--   * a panel coordinator so opening one panel closes the others.
--
-- Every client menu builds through here, so restyling the whole game is
-- one file.

local UIKit = {}

-- Palette -----------------------------------------------------------------
UIKit.BG = Color3.fromRGB(22, 26, 24)
UIKit.BG2 = Color3.fromRGB(38, 44, 40)
UIKit.ACCENT = Color3.fromRGB(90, 200, 130)
UIKit.GOOD = Color3.fromRGB(120, 230, 140)
UIKit.WARN = Color3.fromRGB(255, 200, 120)
UIKit.BAD = Color3.fromRGB(255, 120, 110)
UIKit.TEXT = Color3.fromRGB(240, 244, 240)
UIKit.DIM = Color3.fromRGB(160, 168, 162)

function UIKit.corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = inst
	return c
end

function UIKit.stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.7
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

-- A soft drop shadow behind a frame (an ImageLabel would need an asset;
-- a translucent stroke reads clean enough and needs nothing external).
function UIKit.card(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name or "Card"
	frame.BackgroundColor3 = UIKit.BG
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	UIKit.corner(frame, 14)
	UIKit.stroke(frame, Color3.fromRGB(0, 0, 0), 1, 0.5)
	frame.Parent = parent
	return frame
end

-- Panel coordination ------------------------------------------------------

local panels = {} -- frame -> true

-- Show `panel` and hide every other registered panel. Pass nil to close
-- them all. Returns the panel's new visibility.
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

-- The dock ----------------------------------------------------------------

local dockList = nil

local function ensureDock(playerGui)
	if dockList then
		return dockList
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownDock"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -12, 1, -12)
	holder.Size = UDim2.new(0, 60, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	holder.Parent = gui

	gui.Parent = playerGui
	dockList = holder
	return holder
end

-- Add a square icon button to the dock. onClick receives the button so it
-- can flip its own highlight. Returns the button.
function UIKit.dockButton(playerGui, order, icon, label, onClick)
	local dock = ensureDock(playerGui)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(0, 60, 0, 58)
	button.BackgroundColor3 = UIKit.BG
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = ""
	UIKit.corner(button, 12)
	UIKit.stroke(button, Color3.fromRGB(0, 0, 0), 1, 0.55)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 30)
	iconLabel.Position = UDim2.new(0, 0, 0, 5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 22
	iconLabel.Text = icon
	iconLabel.Parent = button

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 16)
	nameLabel.Position = UDim2.new(0, 2, 1, -18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = UIKit.TEXT
	nameLabel.Text = label
	nameLabel.Parent = button

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -2, 0, 2)
	badge.Size = UDim2.new(0, 20, 0, 20)
	badge.BackgroundColor3 = UIKit.BAD
	badge.Font = Enum.Font.GothamBlack
	badge.TextScaled = true
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Text = ""
	badge.Visible = false
	UIKit.corner(badge, 10)
	badge.Parent = button

	button.Activated:Connect(function()
		onClick(button)
	end)
	button.Parent = dock

	return button
end

-- Flip a dock button's "active" look.
function UIKit.setActive(button, active)
	button.BackgroundColor3 = active and UIKit.ACCENT or UIKit.BG
	button.BackgroundTransparency = active and 0 or 0.08
	local icon = button:FindFirstChild("Icon")
	if icon then
		icon.TextColor3 = active and Color3.fromRGB(20, 30, 24) or UIKit.TEXT
	end
end

function UIKit.setBadge(button, text)
	local badge = button:FindFirstChild("Badge")
	if badge then
		badge.Text = text or ""
		badge.Visible = text ~= nil and text ~= ""
	end
end

return UIKit
