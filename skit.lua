-- skot.lua ~ beta build
-- Advanced Anti-Aim Menu with CS-like features

local module = {}

local isLoaded = false
local menuOpen = false
local mainGui = nil
local updateThread = nil
local glowParts = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ===========================================================
-- SETTINGS (Anti-Aim Configuration)
-- ===========================================================

local Settings = {
	-- Desync
	DesyncEnabled = true,
	DesyncAngle = 89,
	DesyncJitter = false,
	DesyncJitterAmount = 45,
	DesyncDistance = 3,

	-- Yaw
	YawBase = 0,
	YawJitter = false,
	YawJitterAmount = 30,
	YawSpin = false,
	YawSpinSpeed = 10,

	-- Anti-Aim
	AntiAimEnabled = false,
	FakeLag = false,
	FakeLagAmount = 3,
	BodyLean = false,
	BodyLeanAngle = 15,

	-- Visuals
	GlowEnabled = true,
	GlowColor = Color3.fromRGB(0, 170, 255),
	GlowTransparency = 0.5,
	GlowPulse = false,

	-- Menu
	MenuKey = Enum.KeyCode.J,
	AccentColor = Color3.fromRGB(138, 43, 226), -- Purple accent
	BackgroundColor = Color3.fromRGB(25, 25, 35),
	SecondaryColor = Color3.fromRGB(35, 35, 50),
}

-- ===========================================================
-- UI LIBRARY
-- ===========================================================

local UI = {}

-- Create smooth tween
function UI.Tween(object, properties, duration)
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

-- Create main frame
function UI.CreateFrame(name, parent, size, position, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or Settings.BackgroundColor
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- Create text label
function UI.CreateLabel(text, parent, size, position, textSize, alignment)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 14
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Create toggle button
function UI.CreateToggle(name, parent, position, default, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "_Toggle"
	container.Size = UDim2.new(1, -20, 0, 30)
	container.Position = position
	container.BackgroundTransparency = 1
	container.Parent = parent

	local label = UI.CreateLabel(name, container, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 0, 0, 0), 13)

	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.new(0, 44, 0, 22)
	toggleBg.Position = UDim2.new(1, -44, 0.5, -11)
	toggleBg.BackgroundColor3 = default and Settings.AccentColor or Color3.fromRGB(60, 60, 70)
	toggleBg.BorderSizePixel = 0
	toggleBg.Parent = container

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 11)
	toggleCorner.Parent = toggleBg

	local toggleCircle = Instance.new("Frame")
	toggleCircle.Size = UDim2.new(0, 18, 0, 18)
	toggleCircle.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toggleCircle.BorderSizePixel = 0
	toggleCircle.Parent = toggleBg

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent = toggleCircle

	local enabled = default

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = toggleBg

	button.MouseButton1Click:Connect(function()
		enabled = not enabled
		UI.Tween(toggleBg, {BackgroundColor3 = enabled and Settings.AccentColor or Color3.fromRGB(60, 60, 70)})
		UI.Tween(toggleCircle, {Position = enabled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)})
		if callback then callback(enabled) end
	end)

	return container
end

-- Create slider
function UI.CreateSlider(name, parent, position, min, max, default, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "_Slider"
	container.Size = UDim2.new(1, -20, 0, 45)
	container.Position = position
	container.BackgroundTransparency = 1
	container.Parent = parent

	local valueLabel = UI.CreateLabel(tostring(default), container, UDim2.new(0, 40, 0, 20), UDim2.new(1, -40, 0, 0), 12, Enum.TextXAlignment.Right)
	local label = UI.CreateLabel(name, container, UDim2.new(0.7, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13)

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, 0, 0, 6)
	sliderBg.Position = UDim2.new(0, 0, 0, 28)
	sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = container

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 3)
	sliderCorner.Parent = sliderBg

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = Settings.AccentColor
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = sliderFill

	local sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.new(0, 14, 0, 14)
	sliderKnob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
	sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderKnob.BorderSizePixel = 0
	sliderKnob.ZIndex = 2
	sliderKnob.Parent = sliderBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = sliderKnob

	local dragging = false

	local function updateSlider(input)
		local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
		local value = math.floor(min + (max - min) * pos)

		sliderFill.Size = UDim2.new(pos, 0, 1, 0)
		sliderKnob.Position = UDim2.new(pos, -7, 0.5, -7)
		valueLabel.Text = tostring(value)

		if callback then callback(value) end
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateSlider(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSlider(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return container
end

-- Create dropdown
function UI.CreateDropdown(name, parent, position, options, default, callback)
	local container = Instance.new("Frame")
	container.Name = name .. "_Dropdown"
	container.Size = UDim2.new(1, -20, 0, 55)
	container.Position = position
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.Parent = parent

	local label = UI.CreateLabel(name, container, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13)

	local dropdownBg = Instance.new("Frame")
	dropdownBg.Size = UDim2.new(1, 0, 0, 28)
	dropdownBg.Position = UDim2.new(0, 0, 0, 22)
	dropdownBg.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	dropdownBg.BorderSizePixel = 0
	dropdownBg.Parent = container

	local dropCorner = Instance.new("UICorner")
	dropCorner.CornerRadius = UDim.new(0, 6)
	dropCorner.Parent = dropdownBg

	local selectedLabel = UI.CreateLabel(default, dropdownBg, UDim2.new(1, -30, 1, 0), UDim2.new(0, 10, 0, 0), 12)

	local arrow = UI.CreateLabel("¡", dropdownBg, UDim2.new(0, 20, 1, 0), UDim2.new(1, -25, 0, 0), 10, Enum.TextXAlignment.Center)

	local optionsFrame = Instance.new("Frame")
	optionsFrame.Size = UDim2.new(1, 0, 0, #options * 25)
	optionsFrame.Position = UDim2.new(0, 0, 0, 30)
	optionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	optionsFrame.BorderSizePixel = 0
	optionsFrame.Visible = false
	optionsFrame.ZIndex = 10
	optionsFrame.Parent = dropdownBg

	local optCorner = Instance.new("UICorner")
	optCorner.CornerRadius = UDim.new(0, 6)
	optCorner.Parent = optionsFrame

	local isOpen = false

	for i, option in ipairs(options) do
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, 0, 0, 25)
		optBtn.Position = UDim2.new(0, 0, 0, (i-1) * 25)
		optBtn.BackgroundTransparency = 1
		optBtn.Text = option
		optBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
		optBtn.TextSize = 12
		optBtn.Font = Enum.Font.Gotham
		optBtn.ZIndex = 11
		optBtn.Parent = optionsFrame

		optBtn.MouseEnter:Connect(function()
			optBtn.TextColor3 = Settings.AccentColor
		end)

		optBtn.MouseLeave:Connect(function()
			optBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
		end)

		optBtn.MouseButton1Click:Connect(function()
			selectedLabel.Text = option
			optionsFrame.Visible = false
			isOpen = false
			arrow.Text = "¡"
			if callback then callback(option) end
		end)
	end

	local mainBtn = Instance.new("TextButton")
	mainBtn.Size = UDim2.new(1, 0, 1, 0)
	mainBtn.BackgroundTransparency = 1
	mainBtn.Text = ""
	mainBtn.Parent = dropdownBg

	mainBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		optionsFrame.Visible = isOpen
		arrow.Text = isOpen and "^" or "¡"
	end)

	return container
end

-- Create section
function UI.CreateSection(name, parent, position)
	local section = Instance.new("Frame")
	section.Name = name .. "_Section"
	section.Size = UDim2.new(1, -20, 0, 30)
	section.Position = position
	section.BackgroundTransparency = 1
	section.Parent = parent

	local line1 = Instance.new("Frame")
	line1.Size = UDim2.new(0.2, 0, 0, 1)
	line1.Position = UDim2.new(0, 0, 0.5, 0)
	line1.BackgroundColor3 = Settings.AccentColor
	line1.BorderSizePixel = 0
	line1.Parent = section

	local label = UI.CreateLabel(name, section, UDim2.new(0.6, 0, 1, 0), UDim2.new(0.2, 10, 0, 0), 11, Enum.TextXAlignment.Center)
	label.TextColor3 = Settings.AccentColor

	local line2 = Instance.new("Frame")
	line2.Size = UDim2.new(0.2, 0, 0, 1)
	line2.Position = UDim2.new(0.8, -10, 0.5, 0)
	line2.BackgroundColor3 = Settings.AccentColor
	line2.BorderSizePixel = 0
	line2.Parent = section

	return section
end

-- ===========================================================
-- ANTI-AIM LOGIC
-- ===========================================================

local currentYaw = 0
local jitterState = false
local spinAngle = 0
local pulseValue = 0.5

-- Create glow part
local function createGlowPart(bodyPart)
	local glow = Instance.new("Part")
	glow.Name = "SkotGlow_" .. bodyPart.Name
	glow.Size = bodyPart.Size * 1.1
	glow.Color = Settings.GlowColor
	glow.Material = Enum.Material.Neon
	glow.Transparency = Settings.GlowTransparency
	glow.CanCollide = false
	glow.Anchored = true
	glow.CastShadow = false
	glow.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Settings.GlowColor
	light.Brightness = 2
	light.Range = 4
	light.Parent = glow

	return glow
end

-- Setup character glow
local function setupCharacterGlow(character)
	for _, glow in pairs(glowParts) do
		if glow and glow.Parent then
			glow:Destroy()
		end
	end
	glowParts = {}

	if not Settings.GlowEnabled then return end

	local bodyPartNames = {
		"Head", "Torso", "HumanoidRootPart",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg",
		"UpperTorso", "LowerTorso",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot"
	}

	for _, partName in ipairs(bodyPartNames) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			glowParts[partName] = createGlowPart(part)
		end
	end
end

-- Calculate final desync angle
local function calculateDesyncAngle()
	local baseAngle = Settings.DesyncAngle

	-- Apply desync jitter
	if Settings.DesyncJitter then
		jitterState = not jitterState
		if jitterState then
			baseAngle = baseAngle + Settings.DesyncJitterAmount
		else
			baseAngle = baseAngle - Settings.DesyncJitterAmount
		end
	end

	return math.rad(baseAngle)
end

-- Calculate final yaw
local function calculateYaw()
	local yaw = Settings.YawBase

	-- Apply yaw jitter
	if Settings.YawJitter then
		jitterState = not jitterState
		if jitterState then
			yaw = yaw + Settings.YawJitterAmount
		else
			yaw = yaw - Settings.YawJitterAmount
		end
	end

	-- Apply spin
	if Settings.YawSpin then
		spinAngle = spinAngle + Settings.YawSpinSpeed
		if spinAngle >= 360 then spinAngle = 0 end
		yaw = yaw + spinAngle
	end

	return math.rad(yaw)
end

-- Get desync CFrame
local function getDesyncCFrame(originalCFrame)
	local desyncAngle = calculateDesyncAngle()
	local yawAngle = calculateYaw()

	local totalRotation = CFrame.Angles(0, desyncAngle + yawAngle, 0)
	local offset = originalCFrame.LookVector * Settings.DesyncDistance

	-- Apply body lean
	local leanAngle = 0
	if Settings.BodyLean then
		leanAngle = math.rad(Settings.BodyLeanAngle)
	end

	local leanRotation = CFrame.Angles(0, 0, leanAngle)

	return CFrame.new(originalCFrame.Position + offset) * totalRotation * leanRotation
end

-- Update pulse effect
local function updatePulse()
	if Settings.GlowPulse then
		pulseValue = 0.3 + math.abs(math.sin(tick() * 3)) * 0.4
	else
		pulseValue = Settings.GlowTransparency
	end
end

-- Update desync
local function updateDesync()
	if not Settings.DesyncEnabled then
		for _, glow in pairs(glowParts) do
			if glow and glow.Parent then
				glow.Transparency = 1
			end
		end
		return
	end

	local character = LocalPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	updatePulse()

	local desyncBase = getDesyncCFrame(rootPart.CFrame)
	local originalRoot = rootPart.CFrame

	for partName, glowPart in pairs(glowParts) do
		local bodyPart = character:FindFirstChild(partName)
		if bodyPart and bodyPart:IsA("BasePart") and glowPart and glowPart.Parent then
			local relativeOffset = originalRoot:ToObjectSpace(bodyPart.CFrame)
			local desyncCFrame = desyncBase * relativeOffset

			glowPart.CFrame = desyncCFrame
			glowPart.Size = bodyPart.Size * 1.1
			glowPart.Transparency = pulseValue
			glowPart.Color = Settings.GlowColor

			local light = glowPart:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = Settings.GlowColor
				light.Brightness = 2 + (1 - pulseValue) * 2
			end
		end
	end
end

-- ===========================================================
-- MAIN MENU CREATION
-- ===========================================================

local function createMenu()
	-- Main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkotLua"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Main Window
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 500, 0, 600)
	mainFrame.Position = UDim2.new(0.5, -250, 0.5, -300)
	mainFrame.BackgroundColor3 = Settings.BackgroundColor
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	-- Gradient border effect
	local borderGradient = Instance.new("UIStroke")
	borderGradient.Thickness = 2
	borderGradient.Color = Settings.AccentColor
	borderGradient.Parent = mainFrame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	-- Fix header bottom corners
	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 15)
	headerFix.Position = UDim2.new(0, 0, 1, -15)
	headerFix.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "skot.lua"
	titleLabel.Size = UDim2.new(0, 100, 1, 0)
	titleLabel.Position = UDim2.new(0, 15, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Settings.AccentColor
	titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	local betaLabel = Instance.new("TextLabel")
	betaLabel.Text = "~ beta build"
	betaLabel.Size = UDim2.new(0, 100, 1, 0)
	betaLabel.Position = UDim2.new(0, 105, 0, 0)
	betaLabel.BackgroundTransparency = 1
	betaLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	betaLabel.TextSize = 14
	betaLabel.Font = Enum.Font.GothamMedium
	betaLabel.TextXAlignment = Enum.TextXAlignment.Left
	betaLabel.Parent = header

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "?"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		menuOpen = false
	end)

	-- Tab Container
	local tabContainer = Instance.new("Frame")
	tabContainer.Size = UDim2.new(1, -20, 0, 35)
	tabContainer.Position = UDim2.new(0, 10, 0, 55)
	tabContainer.BackgroundColor3 = Settings.SecondaryColor
	tabContainer.BorderSizePixel = 0
	tabContainer.Parent = mainFrame

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 8)
	tabCorner.Parent = tabContainer

	-- Content Frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -20, 1, -105)
	contentFrame.Position = UDim2.new(0, 10, 0, 95)
	contentFrame.BackgroundColor3 = Settings.SecondaryColor
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollBarImageColor3 = Settings.AccentColor
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 900)
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 8)
	contentCorner.Parent = contentFrame

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.Parent = contentFrame

	-- ===========================================================
	-- TAB SYSTEM
	-- ===========================================================

	local tabs = {"Anti-Aim", "Visuals", "Misc"}
	local tabButtons = {}
	local tabContents = {}
	local currentTab = "Anti-Aim"

	for i, tabName in ipairs(tabs) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tabName
		tabBtn.Text = tabName
		tabBtn.Size = UDim2.new(1/#tabs, -6, 1, -6)
		tabBtn.Position = UDim2.new((i-1)/#tabs, 3, 0, 3)
		tabBtn.BackgroundColor3 = i == 1 and Settings.AccentColor or Color3.fromRGB(50, 50, 65)
		tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.TextSize = 13
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Parent = tabContainer

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = tabBtn

		tabButtons[tabName] = tabBtn

		-- Create content frame for each tab
		local tabContent = Instance.new("Frame")
		tabContent.Name = tabName .. "_Content"
		tabContent.Size = UDim2.new(1, -10, 0, 850)
		tabContent.Position = UDim2.new(0, 0, 0, 0)
		tabContent.BackgroundTransparency = 1
		tabContent.Visible = i == 1
		tabContent.Parent = contentFrame

		tabContents[tabName] = tabContent

		tabBtn.MouseButton1Click:Connect(function()
			for name, btn in pairs(tabButtons) do
				UI.Tween(btn, {BackgroundColor3 = name == tabName and Settings.AccentColor or Color3.fromRGB(50, 50, 65)})
			end
			for name, content in pairs(tabContents) do
				content.Visible = name == tabName
			end
			currentTab = tabName
		end)
	end

	-- ===========================================================
	-- ANTI-AIM TAB CONTENT
	-- ===========================================================

	local aaContent = tabContents["Anti-Aim"]
	local yPos = 0

	-- Desync Section
	UI.CreateSection("DESYNC", aaContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Desync", aaContent, UDim2.new(0, 0, 0, yPos), Settings.DesyncEnabled, function(v)
		Settings.DesyncEnabled = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Desync Angle", aaContent, UDim2.new(0, 0, 0, yPos), 0, 180, Settings.DesyncAngle, function(v)
		Settings.DesyncAngle = v
	end)
	yPos = yPos + 50

	UI.CreateToggle("Desync Jitter", aaContent, UDim2.new(0, 0, 0, yPos), Settings.DesyncJitter, function(v)
		Settings.DesyncJitter = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Jitter Amount", aaContent, UDim2.new(0, 0, 0, yPos), 0, 90, Settings.DesyncJitterAmount, function(v)
		Settings.DesyncJitterAmount = v
	end)
	yPos = yPos + 50

	UI.CreateSlider("Desync Distance", aaContent, UDim2.new(0, 0, 0, yPos), 1, 10, Settings.DesyncDistance, function(v)
		Settings.DesyncDistance = v
	end)
	yPos = yPos + 55

	-- Yaw Section
	UI.CreateSection("YAW", aaContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateDropdown("Yaw Base Mode", aaContent, UDim2.new(0, 0, 0, yPos), {"Static", "Spin", "Random", "At Target"}, "Static", function(v)
		if v == "Spin" then
			Settings.YawSpin = true
		else
			Settings.YawSpin = false
		end
	end)
	yPos = yPos + 60

	UI.CreateSlider("Yaw Offset", aaContent, UDim2.new(0, 0, 0, yPos), -180, 180, Settings.YawBase, function(v)
		Settings.YawBase = v
	end)
	yPos = yPos + 50

	UI.CreateToggle("Yaw Jitter", aaContent, UDim2.new(0, 0, 0, yPos), Settings.YawJitter, function(v)
		Settings.YawJitter = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Yaw Jitter Amount", aaContent, UDim2.new(0, 0, 0, yPos), 0, 180, Settings.YawJitterAmount, function(v)
		Settings.YawJitterAmount = v
	end)
	yPos = yPos + 50

	UI.CreateSlider("Spin Speed", aaContent, UDim2.new(0, 0, 0, yPos), 1, 50, Settings.YawSpinSpeed, function(v)
		Settings.YawSpinSpeed = v
	end)
	yPos = yPos + 55

	-- Body Section
	UI.CreateSection("BODY", aaContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Body Lean", aaContent, UDim2.new(0, 0, 0, yPos), Settings.BodyLean, function(v)
		Settings.BodyLean = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Lean Angle", aaContent, UDim2.new(0, 0, 0, yPos), 0, 45, Settings.BodyLeanAngle, function(v)
		Settings.BodyLeanAngle = v
	end)
	yPos = yPos + 50

	UI.CreateDropdown("Fake Body", aaContent, UDim2.new(0, 0, 0, yPos), {"Off", "Left", "Right", "Jitter"}, "Off", function(v)
		-- Fake body logic
	end)
	yPos = yPos + 60

	-- ===========================================================
	-- VISUALS TAB CONTENT
	-- ===========================================================

	local visContent = tabContents["Visuals"]
	yPos = 0

	UI.CreateSection("GLOW SETTINGS", visContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Glow", visContent, UDim2.new(0, 0, 0, yPos), Settings.GlowEnabled, function(v)
		Settings.GlowEnabled = v
		if LocalPlayer.Character then
			setupCharacterGlow(LocalPlayer.Character)
		end
	end)
	yPos = yPos + 35

	UI.CreateToggle("Pulse Effect", visContent, UDim2.new(0, 0, 0, yPos), Settings.GlowPulse, function(v)
		Settings.GlowPulse = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Glow Transparency", visContent, UDim2.new(0, 0, 0, yPos), 0, 100, math.floor(Settings.GlowTransparency * 100), function(v)
		Settings.GlowTransparency = v / 100
	end)
	yPos = yPos + 55

	UI.CreateSection("GLOW COLOR", visContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateDropdown("Color Preset", visContent, UDim2.new(0, 0, 0, yPos), {"Cyan", "Purple", "Red", "Green", "Pink", "Rainbow"}, "Cyan", function(v)
		local colors = {
			Cyan = Color3.fromRGB(0, 170, 255),
			Purple = Color3.fromRGB(138, 43, 226),
			Red = Color3.fromRGB(255, 50, 50),
			Green = Color3.fromRGB(50, 255, 100),
			Pink = Color3.fromRGB(255, 100, 200),
		}
		if colors[v] then
			Settings.GlowColor = colors[v]
		end
	end)
	yPos = yPos + 65

	UI.CreateSlider("Red", visContent, UDim2.new(0, 0, 0, yPos), 0, 255, 0, function(v)
		Settings.GlowColor = Color3.fromRGB(v, Settings.GlowColor.G * 255, Settings.GlowColor.B * 255)
	end)
	yPos = yPos + 50

	UI.CreateSlider("Green", visContent, UDim2.new(0, 0, 0, yPos), 0, 255, 170, function(v)
		Settings.GlowColor = Color3.fromRGB(Settings.GlowColor.R * 255, v, Settings.GlowColor.B * 255)
	end)
	yPos = yPos + 50

	UI.CreateSlider("Blue", visContent, UDim2.new(0, 0, 0, yPos), 0, 255, 255, function(v)
		Settings.GlowColor = Color3.fromRGB(Settings.GlowColor.R * 255, Settings.GlowColor.G * 255, v)
	end)

	-- ===========================================================
	-- MISC TAB CONTENT
	-- ===========================================================

	local miscContent = tabContents["Misc"]
	yPos = 0

	UI.CreateSection("FAKE LAG", miscContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Fake Lag", miscContent, UDim2.new(0, 0, 0, yPos), Settings.FakeLag, function(v)
		Settings.FakeLag = v
	end)
	yPos = yPos + 35

	UI.CreateSlider("Choke Amount", miscContent, UDim2.new(0, 0, 0, yPos), 1, 14, Settings.FakeLagAmount, function(v)
		Settings.FakeLagAmount = v
	end)
	yPos = yPos + 55

	UI.CreateSection("INFO", miscContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Text = [[
skot.lua ~ beta build

Hotkeys:
 J - Toggle Menu
 Desync jitter switches sides each frame
 Yaw jitter alternates between +/- offset

Features:
 Full desync customization
 CS-like anti-aim options
 Glow visualization
 Smooth UI with animations

Made for educational purposes.
    ]]
	infoLabel.Size = UDim2.new(1, -10, 0, 200)
	infoLabel.Position = UDim2.new(0, 0, 0, yPos)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLabel.TextSize = 12
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.TextWrapped = true
	infoLabel.Parent = miscContent

	-- ===========================================================
	-- DRAGGABLE
	-- ===========================================================

	local dragging = false
	local dragStart = nil
	local startPos = nil

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
		end
	end)

	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	return screenGui, mainFrame
end

-- ===========================================================
-- MAIN LOOP
-- ===========================================================

local function startMainLoop()
	updateThread = task.spawn(function()
		while isLoaded do
			updateDesync()
			RunService.RenderStepped:Wait()
		end
	end)
end

local function onCharacterAdded(character)
	task.wait(0.5)
	if isLoaded then
		setupCharacterGlow(character)
	end
end

-- ===========================================================
-- MODULE FUNCTIONS
-- ===========================================================

function module.Init()
	if isLoaded then
		warn("[skot.lua] Already loaded!")
		return
	end

	isLoaded = true
	print("[skot.lua] Loading beta build...")

	-- Create GUI
	mainGui, mainFrame = createMenu()

	-- Setup keybind
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Settings.MenuKey then
			menuOpen = not menuOpen
			mainFrame.Visible = menuOpen
		end
	end)

	-- Setup character
	if LocalPlayer.Character then
		setupCharacterGlow(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	-- Start loop
	startMainLoop()

	print("[skot.lua] Loaded! Press J to open menu.")
end

function module.IsLoaded()
	return isLoaded
end

function module.Unload()
	if not isLoaded then return end

	isLoaded = false

	-- Clean up glow
	for _, glow in pairs(glowParts) do
		if glow and glow.Parent then
			glow:Destroy()
		end
	end
	glowParts = {}

	-- Clean up GUI
	if mainGui then
		mainGui:Destroy()
	end

	print("[skot.lua] Unloaded!")
end

return module
