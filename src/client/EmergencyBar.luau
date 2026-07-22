-- EmergencyBar: Prison Architect's red emergency buttons, bottom-right.
-- The real systems (Lockdown, searches, roll call) arrive in Phase 5 —
-- until then the buttons sit grayed out like PA's locked tools, so the
-- layout is final from day one.

local Players = game:GetService("Players")

local EmergencyBar = {}

local BUTTONS = {
	{ icon = "🚨", name = "Lockdown" },
	{ icon = "🔍", name = "Shakedown" },
	{ icon = "🕳️", name = "Tunnel Search" },
	{ icon = "📢", name = "Roll Call" },
}

function EmergencyBar.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownEmergencies"
	gui.ResetOnSpawn = false

	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 14, 1, -14)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.new(0, 0, 0, 48)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row

	local note = Instance.new("TextLabel")
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 14, 1, -66)
	note.Size = UDim2.new(0, 240, 0, 18)
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.GothamBold
	note.TextScaled = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextColor3 = Color3.fromRGB(255, 170, 150)
	note.TextStrokeTransparency = 0.5
	note.Text = ""
	note.Parent = gui

	local noteId = 0
	for _, def in ipairs(BUTTONS) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 52, 0, 44)
		button.BackgroundColor3 = Color3.fromRGB(60, 25, 25)
		button.BackgroundTransparency = 0.35
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.TextTransparency = 0.4
		button.Text = def.icon
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(160, 60, 60)
		stroke.Transparency = 0.5
		stroke.Thickness = 1.5
		stroke.Parent = button
		button.Activated:Connect(function()
			noteId += 1
			local id = noteId
			note.Text = def.name .. " — coming in Phase 5!"
			task.delay(2.5, function()
				if noteId == id then
					note.Text = ""
				end
			end)
		end)
		button.Parent = row
	end

	row.Parent = gui
	gui.Parent = playerGui
end

return EmergencyBar
