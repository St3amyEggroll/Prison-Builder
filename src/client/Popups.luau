-- Popups: floating "+$40" text in the world whenever your inmates pay
-- up. Each popup is a tiny invisible part with a BillboardGui that
-- drifts upward and fades — created on this player's device only, so it
-- costs the server nothing.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local Popups = {}

function Popups.start()
	local popupRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Popup")

	popupRemote.OnClientEvent:Connect(function(worldPosition, amount)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(worldPosition)

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 130, 0, 40)
		gui.StudsOffset = Vector3.new(0, 0, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 250

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(140, 255, 150)
		label.TextStrokeTransparency = 0.3
		label.Text = "+" .. Format.money(amount)
		label.Parent = gui
		gui.Parent = anchor
		anchor.Parent = workspace

		-- Drift up 4 studs while the text fades out, then self-destruct.
		local drift = TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = Vector3.new(0, 4, 0),
		})
		local fade = TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		drift:Play()
		fade:Play()
		Debris:AddItem(anchor, 1.6)
	end)
end

return Popups
