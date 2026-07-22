-- PAToolbar: Prison Architect's bottom-left toolbar, rebuilt for Roblox.
--
-- A strip of square blueprint-blue buttons hugs the bottom-left corner
-- (icon art drawn in code — see PAIcons). Hovering shows a tooltip;
-- locked tabs render dark exactly like PA's, and clicking a live tab
-- opens a PA-style menu ABOVE the strip: a titled panel of rows, each
-- with an icon, a name and a price. UIKit's coordinator guarantees only
-- one menu is open at a time.
--
-- Other files register their tabs through addTab/menu — the strip builds
-- itself lazily on the first call, so registration order doesn't matter
-- (LayoutOrder decides the on-screen order).

local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)
local PAIcons = require(script.Parent.PAIcons)

local PAToolbar = {}

local BTN = 44 -- toolbar buttons are squares this big

local gui, strip, tooltip
local entries = {} -- id -> { button, enabled, pressed }
local menus = {} -- id -> menu panel frame
local activeTool = nil

local function ensure()
	if gui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "LockdownToolbar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.new(0, 12, 1, -12)
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Size = UDim2.new(0, 0, 0, BTN + 8)
	strip.BackgroundColor3 = UIKit.STRIP
	strip.BackgroundTransparency = 0.05
	strip.BorderSizePixel = 0
	UIKit.stroke(strip, UIKit.EDGE_DIM, 1, 0)
	UIKit.pad(strip, 4)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	strip.Parent = gui

	tooltip = Instance.new("TextLabel")
	tooltip.Name = "Tooltip"
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.Size = UDim2.new(0, 0, 0, 0)
	tooltip.BackgroundColor3 = UIKit.STRIP
	tooltip.BorderSizePixel = 0
	tooltip.Font = Enum.Font.GothamMedium
	tooltip.TextSize = 13
	tooltip.TextColor3 = UIKit.TEXT
	tooltip.Visible = false
	tooltip.ZIndex = 60
	UIKit.stroke(tooltip, UIKit.EDGE_DIM, 1, 0)
	UIKit.pad(tooltip, 5)
	tooltip.Parent = gui

	gui.Parent = playerGui
end

local function paint(id)
	local e = entries[id]
	if not e then
		return
	end
	if e.pressed then
		e.button.BackgroundColor3 = UIKit.BTN_ON
	elseif e.enabled then
		e.button.BackgroundColor3 = UIKit.BTN
	else
		e.button.BackgroundColor3 = UIKit.BTN_DARK
	end
end

-- Add a square tab. def = { id, icon (PAIcons name), label (tooltip),
-- order, enabled (default true), onClick }.
function PAToolbar.addTab(def)
	ensure()
	local enabled = def.enabled ~= false
	local button = Instance.new("TextButton")
	button.Name = def.id
	button.LayoutOrder = def.order or 0
	button.Size = UDim2.fromOffset(BTN, BTN)
	button.BackgroundColor3 = enabled and UIKit.BTN or UIKit.BTN_DARK
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	UIKit.stroke(button, enabled and UIKit.EDGE or UIKit.EDGE_DIM, 1, 0.35)
	PAIcons.draw(button, def.icon, enabled and UIKit.ICON or UIKit.ICON_DARK)

	-- The little red attention dot (payroll missed, etc.).
	local alert = Instance.new("Frame")
	alert.Name = "Alert"
	alert.AnchorPoint = Vector2.new(1, 0)
	alert.Position = UDim2.new(1, -3, 0, 3)
	alert.Size = UDim2.fromOffset(9, 9)
	alert.BackgroundColor3 = UIKit.BAD
	alert.BorderSizePixel = 0
	alert.Visible = false
	alert.Parent = button

	local entry = { button = button, enabled = enabled, pressed = false }
	entries[def.id] = entry

	button.MouseEnter:Connect(function()
		if enabled and not entry.pressed then
			button.BackgroundColor3 = UIKit.BTN_HOVER
		end
		tooltip.Text = def.label .. (enabled and "" or "  (locked)")
		tooltip.Position = UDim2.fromOffset(
			button.AbsolutePosition.X + button.AbsoluteSize.X / 2,
			button.AbsolutePosition.Y - 6
		)
		tooltip.Visible = true
	end)
	button.MouseLeave:Connect(function()
		paint(def.id)
		tooltip.Visible = false
	end)
	button.Activated:Connect(function()
		tooltip.Visible = false
		if def.onClick then
			def.onClick(button)
		end
	end)
	button.Parent = strip
	return button
end

function PAToolbar.setPressed(id, on)
	local e = entries[id]
	if e then
		e.pressed = on == true
		paint(id)
	end
end

-- Exactly one TOOL tab is pressed at a time (the walk toggle is managed
-- separately with setPressed — it can be lit alongside a tool).
function PAToolbar.setActiveTool(id)
	if activeTool and activeTool ~= id then
		PAToolbar.setPressed(activeTool, false)
	end
	activeTool = id
	if id then
		PAToolbar.setPressed(id, true)
	end
end

function PAToolbar.setAlert(id, on)
	local e = entries[id]
	local a = e and e.button:FindFirstChild("Alert")
	if a then
		a.Visible = on == true
	end
end

-- Create the PA menu that opens above the strip for a tab. Fill its
-- .list with row()s, then call .fit() to size the panel to its contents.
function PAToolbar.menu(id, title, width)
	ensure()
	width = width or 272
	local panel = Instance.new("Frame")
	panel.Name = id .. "Menu"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -(12 + BTN + 8 + 6))
	panel.Size = UDim2.new(0, width, 0, 120)
	panel.BackgroundColor3 = UIKit.PANEL
	panel.BackgroundTransparency = 0.03
	panel.BorderSizePixel = 0
	UIKit.stroke(panel, UIKit.EDGE_DIM, 1, 0)
	UIKit.titleBar(panel, title)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, 26)
	list.Size = UDim2.new(1, 0, 1, -26)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = list
	list.Parent = panel

	panel.Parent = gui
	UIKit.registerPanel(panel)
	menus[id] = panel

	local handle = { panel = panel, list = list }
	function handle.fit()
		local total = 8
		local count = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then
				total += child.Size.Y.Offset
				count += 1
			end
		end
		total += math.max(count - 1, 0) * 2
		panel.Size = UDim2.new(0, width, 0, 26 + math.min(total, 400))
	end
	return handle
end

-- Toggle a tab's menu (closing every other panel). Returns visibility.
function PAToolbar.toggleMenu(id)
	return UIKit.showOnly(menus[id])
end

-- Open a tab's menu if it isn't already the one showing.
function PAToolbar.openMenu(id)
	local panel = menus[id]
	if panel and not panel.Visible then
		UIKit.showOnly(panel)
	end
end

-- One PA menu row: [icon] Name ............ $price. opts = { order,
-- name, right, height, onClick }. Put art in .icon; flip .setSelected.
function PAToolbar.row(list, opts)
	local button = Instance.new("TextButton")
	button.LayoutOrder = opts.order or 0
	button.Size = UDim2.new(1, -8, 0, opts.height or 34)
	button.BackgroundColor3 = UIKit.ROW_HOVER
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""

	local selectedState = false
	local function paintRow(hover)
		if selectedState then
			button.BackgroundColor3 = UIKit.ROW_ON
			button.BackgroundTransparency = 0
		elseif hover then
			button.BackgroundColor3 = UIKit.ROW_HOVER
			button.BackgroundTransparency = 0
		else
			button.BackgroundTransparency = 1
		end
	end
	button.MouseEnter:Connect(function()
		paintRow(true)
	end)
	button.MouseLeave:Connect(function()
		paintRow(false)
	end)

	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.AnchorPoint = Vector2.new(0, 0.5)
	iconSlot.Position = UDim2.new(0, 8, 0.5, 0)
	iconSlot.Size = UDim2.fromOffset(26, 26)
	iconSlot.BackgroundTransparency = 1
	iconSlot.Parent = button

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Position = UDim2.new(0, 42, 0, 0)
	nameLabel.Size = UDim2.new(1, -116, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextColor3 = UIKit.TEXT
	nameLabel.Text = opts.name or ""
	nameLabel.Parent = button

	local rightLabel = Instance.new("TextLabel")
	rightLabel.Name = "ItemRight"
	rightLabel.AnchorPoint = Vector2.new(1, 0.5)
	rightLabel.Position = UDim2.new(1, -10, 0.5, 0)
	rightLabel.Size = UDim2.new(0, 64, 0, 18)
	rightLabel.BackgroundTransparency = 1
	rightLabel.Font = Enum.Font.GothamBold
	rightLabel.TextSize = 14
	rightLabel.TextXAlignment = Enum.TextXAlignment.Right
	rightLabel.TextColor3 = UIKit.GOOD
	rightLabel.Text = opts.right or ""
	rightLabel.Parent = button

	if opts.onClick then
		button.Activated:Connect(opts.onClick)
	end
	button.Parent = list

	local handle = { button = button, icon = iconSlot, name = nameLabel, right = rightLabel }
	function handle.setSelected(on)
		selectedState = on == true
		paintRow(false)
	end
	return handle
end

return PAToolbar
