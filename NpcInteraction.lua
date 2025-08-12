--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// Player reference
local player = Players.LocalPlayer

--// Remote events
local NPCInteract = ReplicatedStorage:WaitForChild("NPCInteract")
local NPCResponse = ReplicatedStorage:WaitForChild("NPCResponse")

--// NPC storage folder
local NPCFolder = workspace:WaitForChild("NPCs")

--// UI container for interaction system
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPC_UI"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Frame for option buttons
local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0.3, 0, 0.5, 0)
buttonFrame.Position = UDim2.new(0.7, 0, 0.25, 0)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Visible = false
buttonFrame.Parent = screenGui

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = buttonFrame
uiListLayout.Padding = UDim.new(0, 8)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder

--// State variables
local activeBillboard     	 
local currentHighlight    	 
local currentNPCName      	 
local interactionActive = false
local lastResponseTime = 0 

----- Show dialogue above NPC's head
local function showNPCDialogue(npcModel, text)
	if activeBillboard then activeBillboard:Destroy() end
	local head = npcModel:FindFirstChild("Head")
	if not head then return end

	-- Create billboard GUI above NPC head
	activeBillboard = Instance.new("BillboardGui")
	activeBillboard.Adornee = head
	activeBillboard.Size = UDim2.new(0, 300, 0, 60)
	activeBillboard.StudsOffset = Vector3.new(0, 3, 0)
	activeBillboard.AlwaysOnTop = true
	activeBillboard.Parent = npcModel

	-- Text label for billboard
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = activeBillboard

	-- Animate text
	label.Text = ""
	for i = 1, #text do
		label.Text = string.sub(text, 1, i)
		task.wait(0.03)
	end
	
	lastResponseTime = tick()
end

----- Clear NPC UI & re-enable prompt
local function clearInteraction()
	if activeBillboard then activeBillboard:Destroy() end

	-- Remove all option buttons
	for _, child in ipairs(buttonFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	buttonFrame.Visible = false
	interactionActive = false

	-- Re-enable prompt for current NPC
	if currentNPCName then
		local npcModel = NPCFolder:FindFirstChild(currentNPCName)
		if npcModel then
			local head = npcModel:FindFirstChild("Head")
			if head then
				local prompt = head:FindFirstChildWhichIsA("ProximityPrompt")
				if prompt then
					prompt.Enabled = true
				end
			end
		end
	end

	currentNPCName = nil
end

----- Create UI button for each dialogue option
local function createButton(index, option, npcName)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.95, 0, 0, 45)
	btn.BackgroundTransparency = 0.3
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.Text = string.format("  %d. %s", index, option.Text) 
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 22
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextStrokeTransparency = 0.3
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.TextWrapped = true
	btn.Parent = buttonFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	-- Hover animation: smooth scale & color shift
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(80, 140, 255),
			TextSize = 24
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.95, 0, 0, 45),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			TextSize = 22
		}):Play()
	end)

	-- Click handling
	btn.MouseButton1Click:Connect(function()
		if option.Response and option.Response ~= "" then
			showNPCDialogue(NPCFolder:FindFirstChild(npcName), option.Response)
		else
			if activeBillboard then activeBillboard:Destroy() end
		end

		-- Inform server which option was chosen
		NPCResponse:FireServer(npcName, index)

		-- Close interaction if required
		if option.CloseOnClick then
			task.delay(1, function()
				if tick() - lastResponseTime >= 1 then
					clearInteraction()
				end
			end)
		end
	end)

	-- Fade-in effect for new button
	btn.BackgroundTransparency = 1
	btn.TextTransparency = 1
	TweenService:Create(btn, TweenInfo.new(0.25), {
		BackgroundTransparency = 0.3,
		TextTransparency = 0
	}):Play()
end

----- Server -> Client event: show NPC greeting & options
NPCInteract.OnClientEvent:Connect(function(npcName, data)
	local npcModel = NPCFolder:FindFirstChild(npcName)
	if not npcModel then return end

	-- Disable prompt while interacting
	local head = npcModel:FindFirstChild("Head")
	if head then
		local prompt = head:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end

	currentNPCName = npcName
	interactionActive = true

	-- Show greeting dialogue
	showNPCDialogue(npcModel, data.Greeting)

	-- Remove old buttons & create new ones
	for _, child in ipairs(buttonFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for i, option in ipairs(data.Options) do
		createButton(i, option, npcName)
	end

	buttonFrame.Visible = true
end)

----- Highlight NPC when player is close
RunService.RenderStepped:Connect(function()
	local nearestNPC, nearestDist

	-- Find closest NPC in folder
	for _, npc in ipairs(NPCFolder:GetChildren()) do
		if npc:IsA("Model") and npc:FindFirstChild("Head") then
			local dist = (npc:GetPivot().Position - player.Character:GetPivot().Position).Magnitude
			if not nearestDist or dist < nearestDist then
				nearestDist = dist
				nearestNPC = npc
			end
		end
	end

	-- If within 10 studs, show outline highlight
	if nearestNPC and nearestDist <= 10 then
		if not currentHighlight or currentHighlight.Adornee ~= nearestNPC then
			if currentHighlight then currentHighlight:Destroy() end
			currentHighlight = Instance.new("Highlight")
			currentHighlight.FillTransparency = 1
			currentHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			currentHighlight.OutlineTransparency = 0
			currentHighlight.Adornee = nearestNPC
			currentHighlight.Parent = nearestNPC
		end
	else
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
	end

	-- Auto-close if player walks away (after message finishes)
	if interactionActive and currentNPCName then
		local npcModel = NPCFolder:FindFirstChild(currentNPCName)
		if npcModel and player:DistanceFromCharacter(npcModel:GetPivot().Position) > 12 then
			if tick() - lastResponseTime >= 1 then
				clearInteraction()
			end
		end
	end
end)
