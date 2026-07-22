-- MoodDisplay: a small mood face that floats over unhappy prisoners so
-- you can spot trouble from the top-down view (PA shows need bubbles).
-- Purely cosmetic and client-side; it reads the Mood attribute the
-- server sets on each housed prisoner (staff and workers never get one,
-- so they stay bubble-free).

local CollectionService = game:GetService("CollectionService")

local MoodDisplay = {}

local FACES = {
	safety = "😨",
	food = "🍽️",
	sleep = "😴",
	hygiene = "🚿",
	recreation = "🥱",
	uneasy = "😕",
}

function MoodDisplay.start()
	local shown = {} -- model -> BillboardGui

	local function update(model)
		local mood = model:GetAttribute("Mood")
		local gui = shown[model]
		-- "content" (or nil) shows nothing.
		if not mood or mood == "content" then
			if gui then
				gui.Enabled = false
			end
			return
		end
		if not gui then
			local head = model:FindFirstChild("Head")
			if not head then
				return
			end
			gui = Instance.new("BillboardGui")
			gui.Name = "MoodBubble"
			gui.Size = UDim2.new(0, 30, 0, 30)
			gui.StudsOffset = Vector3.new(0, 2.6, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 120
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Name = "Face"
			label.Parent = gui
			gui.Parent = head
			shown[model] = gui
		end
		gui.Enabled = true
		gui.Face.Text = FACES[mood] or "😕"
	end

	local function watch(model)
		task.spawn(function()
			-- Only prisoners ever get a Mood attribute set.
			model:GetAttributeChangedSignal("Mood"):Connect(function()
				update(model)
			end)
			update(model)
		end)
	end

	for _, model in ipairs(CollectionService:GetTagged("Inmate")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Inmate"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Inmate"):Connect(function(model)
		shown[model] = nil
	end)
end

return MoodDisplay
