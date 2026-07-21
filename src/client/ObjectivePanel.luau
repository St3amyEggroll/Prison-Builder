-- ObjectivePanel: the current starter objective (PA's grants, simplified)
-- as a small card in the top-left. Reads the attributes ObjectiveService
-- publishes: ObjText, ObjProgress, ObjTarget, ObjReward, ObjDone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local ObjectivePanel = {}

function ObjectivePanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LockdownObjective"
	gui.ResetOnSpawn = false

	local card = Instance.new("Frame")
	card.Position = UDim2.new(0, 12, 0, 12)
	card.Size = UDim2.new(0, 250, 0, 74)
	card.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
	card.BackgroundTransparency = 0.25
	card.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 10, 0, 4)
	title.Size = UDim2.new(1, -20, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 220, 130)
	title.Text = "📋 OBJECTIVE"
	title.Parent = card

	local text = Instance.new("TextLabel")
	text.Position = UDim2.new(0, 10, 0, 22)
	text.Size = UDim2.new(1, -20, 0, 30)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = card

	local progress = Instance.new("TextLabel")
	progress.Position = UDim2.new(0, 10, 0, 54)
	progress.Size = UDim2.new(1, -20, 0, 16)
	progress.BackgroundTransparency = 1
	progress.Font = Enum.Font.Gotham
	progress.TextScaled = true
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.TextColor3 = Color3.fromRGB(200, 200, 200)
	progress.Parent = card

	card.Parent = gui
	gui.Parent = playerGui

	local function refresh()
		if player:GetAttribute("ObjDone") == true then
			card.Visible = true
			text.Text = "All objectives complete! 🎉"
			progress.Text = "More coming in later phases."
			return
		end
		local objText = player:GetAttribute("ObjText")
		if type(objText) ~= "string" then
			card.Visible = false
			return
		end
		card.Visible = true
		text.Text = objText
		local current = player:GetAttribute("ObjProgress") or 0
		local target = player:GetAttribute("ObjTarget") or 0
		local reward = player:GetAttribute("ObjReward") or 0
		progress.Text = ("%d / %d  ·  reward %s"):format(current, target, Format.money(reward))
	end

	for _, attr in ipairs({ "ObjText", "ObjProgress", "ObjTarget", "ObjReward", "ObjDone" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
end

return ObjectivePanel
