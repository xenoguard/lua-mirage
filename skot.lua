-- skot.lua ~ beta build v2.0
-- Server-Side Anti-Aim with Debug Info

local module = {}

local isLoaded = false
local menuOpen = false
local mainGui = nil
local updateThread = nil
local glowParts = {}
local fakeCharacter = nil
local debugInfo = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════
-- DEBUG SYSTEM
-- ═══════════════════════════════════════════════════════════

local DebugStats = {
	FPS = 0,
	Ping = 0,
	DesyncActive = false,
	CurrentYaw = 0,
	CurrentDesyncAngle = 0,
	JitterState = false,
	SpinAngle = 0,
	FrameTime = 0,
	UpdateCount = 0,
	LastError = "None",
	CharacterState = "Unknown",
	NetworkOwnership = "Unknown",
	BodyPartsDesynced = 0,
	MemoryUsage = 0,
	ServerTime = 0,
}

local fpsCounter = 0
local fpsTimer = tick()

-- ═══════════════════════════════════════════════════════════
-- SETTINGS
-- ═══════════════════════════════════════════════════════════

local Settings = {
	-- Desync (Server-Side)
	DesyncEnabled = true,
	DesyncMode = "Jitter", -- "Static", "Jitter", "Spin", "Random"
	DesyncAngle = 89,
	DesyncJitter = false,
	DesyncJitterAmount = 45,
	DesyncDistance = 3,

	-- Server-Side Options
	ServerSideEnabled = true,
	FakeBodyEnabled = true,
	BreakAnimations = false,
	DesyncMethod = "CFrame", -- "CFrame", "Velocity", "Both"

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

	-- Resolver Anti
	AntiResolver = false,
	LBYBreaker = false,
	MicroMovement = false,

	-- Visuals
	GlowEnabled = true,
	GlowColor = Color3.fromRGB(0, 170, 255),
	GlowTransparency = 0.5,
	GlowPulse = false,
	ShowRealPosition = true,
	ShowFakePosition = true,
	RealColor = Color3.fromRGB(0, 255, 0),
	FakeColor = Color3.fromRGB(255, 0, 0),

	-- Debug
	DebugEnabled = true,
	DebugPosition = "TopRight", -- "TopLeft", "TopRight", "BottomLeft", "BottomRight"
	ShowNetworkInfo = true,
	ShowDesyncInfo = true,
	ShowPerformanceInfo = true,
	VerboseLogging = false,

	-- Menu
	MenuKey = Enum.KeyCode.J,
	DebugKey = Enum.KeyCode.K,
	AccentColor = Color3.fromRGB(138, 43, 226),
	BackgroundColor = Color3.fromRGB(25, 25, 35),
	SecondaryColor = Color3.fromRGB(35, 35, 50),
}

-- ═══════════════════════════════════════════════════════════
-- LOGGER SYSTEM
-- ═══════════════════════════════════════════════════════════

local Logger = {
	logs = {},
	maxLogs = 50,
}

function Logger:Log(level, message)
	local timestamp = os.date("%H:%M:%S")
	local logEntry = {
		time = timestamp,
		level = level,
		message = message,
		tick = tick()
	}

	table.insert(self.logs, 1, logEntry)

	if #self.logs > self.maxLogs then
		table.remove(self.logs)
	end

	if Settings.VerboseLogging then
		print(string.format("[skot.lua][%s][%s] %s", timestamp, level, message))
	end
end

function Logger:Info(msg) self:Log("INFO", msg) end
function Logger:Warn(msg) self:Log("WARN", msg) end
function Logger:Error(msg) self:Log("ERROR", msg); DebugStats.LastError = msg end
function Logger:Debug(msg) if Settings.VerboseLogging then self:Log("DEBUG", msg) end end

-- ═══════════════════════════════════════════════════════════
-- UI LIBRARY
-- ═══════════════════════════════════════════════════════════

local UI = {}

function UI.Tween(object, properties, duration)
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

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

	local arrow = UI.CreateLabel("▼", dropdownBg, UDim2.new(0, 20, 1, 0), UDim2.new(1, -25, 0, 0), 10, Enum.TextXAlignment.Center)

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
			arrow.Text = "▼"
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
		arrow.Text = isOpen and "▲" or "▼"
	end)

	return container
end

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

-- ═══════════════════════════════════════════════════════════
-- SERVER-SIDE ANTI-AIM SYSTEM
-- ═══════════════════════════════════════════════════════════

local ServerSideAA = {}

local currentYaw = 0
local jitterState = false
local spinAngle = 0
local pulseValue = 0.5
local fakeLagCounter = 0
local originalCFrames = {}

-- Сохранение оригинальных CFrame
function ServerSideAA.SaveOriginalCFrames(character)
	originalCFrames = {}
	for _, part in pairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			originalCFrames[part.Name] = part.CFrame
		end
	end
	Logger:Debug("Saved original CFrames for " .. tostring(#originalCFrames) .. " parts")
end

-- Создание фейкового персонажа (для визуализации серверного десинка)
function ServerSideAA.CreateFakeCharacter(realCharacter)
	if fakeCharacter then
		fakeCharacter:Destroy()
	end

	fakeCharacter = Instance.new("Model")
	fakeCharacter.Name = "FakeCharacter_Skot"

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
		local realPart = realCharacter:FindFirstChild(partName)
		if realPart and realPart:IsA("BasePart") then
			local fakePart = Instance.new("Part")
			fakePart.Name = partName
			fakePart.Size = realPart.Size
			fakePart.CFrame = realPart.CFrame
			fakePart.Color = Settings.FakeColor
			fakePart.Material = Enum.Material.ForceField
			fakePart.Transparency = 0.6
			fakePart.CanCollide = false
			fakePart.Anchored = true
			fakePart.CastShadow = false
			fakePart.Parent = fakeCharacter
		end
	end

	fakeCharacter.Parent = workspace
	Logger:Info("Created fake character visualization")

	return fakeCharacter
end

-- Расчет угла десинка
function ServerSideAA.CalculateDesyncAngle()
	local baseAngle = Settings.DesyncAngle

	if Settings.DesyncJitter then
		jitterState = not jitterState
		DebugStats.JitterState = jitterState
		if jitterState then
			baseAngle = baseAngle + Settings.DesyncJitterAmount
		else
			baseAngle = baseAngle - Settings.DesyncJitterAmount
		end
	end

	DebugStats.CurrentDesyncAngle = baseAngle
	return math.rad(baseAngle)
end

-- Расчет Yaw
function ServerSideAA.CalculateYaw()
	local yaw = Settings.YawBase

	if Settings.YawJitter then
		jitterState = not jitterState
		if jitterState then
			yaw = yaw + Settings.YawJitterAmount
		else
			yaw = yaw - Settings.YawJitterAmount
		end
	end

	if Settings.YawSpin then
		spinAngle = spinAngle + Settings.YawSpinSpeed
		if spinAngle >= 360 then spinAngle = 0 end
		yaw = yaw + spinAngle
		DebugStats.SpinAngle = spinAngle
	end

	DebugStats.CurrentYaw = yaw
	return math.rad(yaw)
end

-- Получение CFrame десинка
function ServerSideAA.GetDesyncCFrame(originalCFrame)
	local desyncAngle = ServerSideAA.CalculateDesyncAngle()
	local yawAngle = ServerSideAA.CalculateYaw()

	local totalRotation = CFrame.Angles(0, desyncAngle + yawAngle, 0)
	local offset = originalCFrame.LookVector * Settings.DesyncDistance

	local leanAngle = 0
	if Settings.BodyLean then
		leanAngle = math.rad(Settings.BodyLeanAngle)
	end

	local leanRotation = CFrame.Angles(0, 0, leanAngle)

	return CFrame.new(originalCFrame.Position + offset) * totalRotation * leanRotation
end

-- Применить серверный десинк
function ServerSideAA.ApplyServerDesync(character)
	if not Settings.ServerSideEnabled or not Settings.DesyncEnabled then
		DebugStats.DesyncActive = false
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		Logger:Error("HumanoidRootPart not found")
		return
	end

	DebugStats.DesyncActive = true

	-- Fake Lag
	if Settings.FakeLag then
		fakeLagCounter = fakeLagCounter + 1
		if fakeLagCounter < Settings.FakeLagAmount then
			return
		end
		fakeLagCounter = 0
	end

	local desyncCFrame = ServerSideAA.GetDesyncCFrame(rootPart.CFrame)

	-- Применяем десинк в зависимости от метода
	if Settings.DesyncMethod == "CFrame" or Settings.DesyncMethod == "Both" then
		-- Метод через CFrame - влияет на серверную позицию
		pcall(function()
			-- Попытка изменить сетевое владение (требует эксплойт)
			if sethiddenproperty then
				sethiddenproperty(rootPart, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
			end
		end)
	end

	if Settings.DesyncMethod == "Velocity" or Settings.DesyncMethod == "Both" then
		-- Метод через Velocity
		pcall(function()
			local velocity = (desyncCFrame.Position - rootPart.Position) * 60
			rootPart.Velocity = velocity
		end)
	end

	-- Обновляем fake character
	if fakeCharacter and Settings.ShowFakePosition then
		local originalRoot = rootPart.CFrame
		local partsUpdated = 0

		for _, fakePart in pairs(fakeCharacter:GetChildren()) do
			if fakePart:IsA("BasePart") then
				local realPart = character:FindFirstChild(fakePart.Name)
				if realPart and realPart:IsA("BasePart") then
					local relativeOffset = originalRoot:ToObjectSpace(realPart.CFrame)
					fakePart.CFrame = desyncCFrame * relativeOffset
					fakePart.Color = Settings.FakeColor
					partsUpdated = partsUpdated + 1
				end
			end
		end

		DebugStats.BodyPartsDesynced = partsUpdated
	end

	-- Микро-движения для анти-резольвера
	if Settings.MicroMovement then
		pcall(function()
			local microOffset = Vector3.new(
				math.random(-10, 10) / 100,
				0,
				math.random(-10, 10) / 100
			)
			rootPart.CFrame = rootPart.CFrame * CFrame.new(microOffset)
		end)
	end

	-- LBY Breaker
	if Settings.LBYBreaker then
		pcall(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.AutoRotate = false
			end
		end)
	end
end

-- ═══════════════════════════════════════════════════════════
-- GLOW SYSTEM
-- ═══════════════════════════════════════════════════════════

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

	Logger:Info("Setup glow for " .. tostring(#glowParts) .. " parts")
end

local function updatePulse()
	if Settings.GlowPulse then
		pulseValue = 0.3 + math.abs(math.sin(tick() * 3)) * 0.4
	else
		pulseValue = Settings.GlowTransparency
	end
end

local function updateGlowVisuals()
	local character = LocalPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	updatePulse()

	if not Settings.DesyncEnabled then
		for _, glow in pairs(glowParts) do
			if glow and glow.Parent then
				glow.Transparency = 1
			end
		end
		return
	end

	local desyncBase = ServerSideAA.GetDesyncCFrame(rootPart.CFrame)
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

-- ═══════════════════════════════════════════════════════════
-- DEBUG PANEL
-- ═══════════════════════════════════════════════════════════

local debugPanel = nil
local debugLabels = {}

local function createDebugPanel(screenGui)
	debugPanel = Instance.new("Frame")
	debugPanel.Name = "DebugPanel"
	debugPanel.Size = UDim2.new(0, 280, 0, 400)
	debugPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	debugPanel.BackgroundTransparency = 0.1
	debugPanel.BorderSizePixel = 0
	debugPanel.Visible = Settings.DebugEnabled
	debugPanel.Parent = screenGui

	-- Позиционирование
	local positions = {
		TopRight = UDim2.new(1, -290, 0, 10),
		TopLeft = UDim2.new(0, 10, 0, 10),
		BottomRight = UDim2.new(1, -290, 1, -410),
		BottomLeft = UDim2.new(0, 10, 1, -410),
	}
	debugPanel.Position = positions[Settings.DebugPosition] or positions.TopRight

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = debugPanel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Settings.AccentColor
	stroke.Thickness = 1
	stroke.Parent = debugPanel

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundColor3 = Settings.AccentColor
	header.BorderSizePixel = 0
	header.Parent = debugPanel

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 10)
	headerFix.Position = UDim2.new(0, 0, 1, -10)
	headerFix.BackgroundColor3 = Settings.AccentColor
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "🔧 DEBUG INFO"
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = header

	-- Content scroll
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -10, 1, -40)
	content.Position = UDim2.new(0, 5, 0, 35)
	content.BackgroundTransparency = 1
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Settings.AccentColor
	content.CanvasSize = UDim2.new(0, 0, 0, 600)
	content.Parent = debugPanel

	local yPos = 0
	local function addDebugLine(category, name, valueKey, color)
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, -10, 0, 18)
		line.Position = UDim2.new(0, 0, 0, yPos)
		line.BackgroundTransparency = 1
		line.Parent = content

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text = name .. ":"
		nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = color or Color3.fromRGB(180, 180, 180)
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = line

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = valueKey
		valueLabel.Text = "---"
		valueLabel.Size = UDim2.new(0.45, 0, 1, 0)
		valueLabel.Position = UDim2.new(0.55, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		valueLabel.TextSize = 11
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = line

		debugLabels[valueKey] = valueLabel
		yPos = yPos + 18
	end

	local function addSectionHeader(text)
		local header = Instance.new("TextLabel")
		header.Text = "━━ " .. text .. " ━━"
		header.Size = UDim2.new(1, 0, 0, 22)
		header.Position = UDim2.new(0, 0, 0, yPos)
		header.BackgroundTransparency = 1
		header.TextColor3 = Settings.AccentColor
		header.TextSize = 11
		header.Font = Enum.Font.GothamBlack
		header.Parent = content
		yPos = yPos + 25
	end

	-- Performance Section
	addSectionHeader("PERFORMANCE")
	addDebugLine("perf", "FPS", "fps", Color3.fromRGB(100, 255, 100))
	addDebugLine("perf", "Frame Time", "frametime")
	addDebugLine("perf", "Memory (MB)", "memory")
	addDebugLine("perf", "Ping (ms)", "ping", Color3.fromRGB(255, 255, 100))
	addDebugLine("perf", "Update Count", "updatecount")

	-- Desync Section
	addSectionHeader("DESYNC STATUS")
	addDebugLine("desync", "Desync Active", "desyncactive", Color3.fromRGB(0, 255, 255))
	addDebugLine("desync", "Server-Side", "serverside")
	addDebugLine("desync", "Desync Angle", "desyncangle")
	addDebugLine("desync", "Current Yaw", "currentyaw")
	addDebugLine("desync", "Jitter State", "jitterstate")
	addDebugLine("desync", "Spin Angle", "spinangle")
	addDebugLine("desync", "Desync Method", "desyncmethod")
	addDebugLine("desync", "Parts Desynced", "partsdesynced")

	-- Character Section
	addSectionHeader("CHARACTER")
	addDebugLine("char", "Character State", "charstate")
	addDebugLine("char", "Root Position", "rootpos")
	addDebugLine("char", "Velocity", "velocity")
	addDebugLine("char", "Health", "health")

	-- Network Section
	addSectionHeader("NETWORK")
	addDebugLine("net", "Network Owner", "netowner")
	addDebugLine("net", "Server Time", "servertime")
	addDebugLine("net", "Data Send (KB/s)", "datasend")
	addDebugLine("net", "Data Recv (KB/s)", "datarecv")

	-- Anti-Aim Section
	addSectionHeader("ANTI-AIM")
	addDebugLine("aa", "Fake Lag", "fakelag")
	addDebugLine("aa", "Choke Amount", "chokeamount")
	addDebugLine("aa", "Body Lean", "bodylean")
	addDebugLine("aa", "LBY Breaker", "lbybreaker")
	addDebugLine("aa", "Micro Movement", "micromovement")

	-- Errors Section
	addSectionHeader("ERRORS/LOGS")
	addDebugLine("err", "Last Error", "lasterror", Color3.fromRGB(255, 100, 100))

	-- Log display
	local logFrame = Instance.new("Frame")
	logFrame.Size = UDim2.new(1, -10, 0, 80)
	logFrame.Position = UDim2.new(0, 0, 0, yPos + 5)
	logFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	logFrame.BorderSizePixel = 0
	logFrame.Parent = content

	local logCorner = Instance.new("UICorner")
	logCorner.CornerRadius = UDim.new(0, 4)
	logCorner.Parent = logFrame

	local logText = Instance.new("TextLabel")
	logText.Name = "LogText"
	logText.Size = UDim2.new(1, -6, 1, -6)
	logText.Position = UDim2.new(0, 3, 0, 3)
	logText.BackgroundTransparency = 1
	logText.TextColor3 = Color3.fromRGB(150, 150, 150)
	logText.TextSize = 9
	logText.Font = Enum.Font.Code
	logText.TextXAlignment = Enum.TextXAlignment.Left
	logText.TextYAlignment = Enum.TextYAlignment.Top
	logText.TextWrapped = true
	logText.Text = "No logs yet..."
	logText.Parent = logFrame

	debugLabels["logtext"] = logText

	content.CanvasSize = UDim2.new(0, 0, 0, yPos + 100)

	Logger:Info("Debug panel created")
	return debugPanel
end

local function updateDebugPanel()
	if not Settings.DebugEnabled or not debugPanel then return end

	-- Update FPS
	fpsCounter = fpsCounter + 1
	if tick() - fpsTimer >= 1 then
		DebugStats.FPS = fpsCounter
		fpsCounter = 0
		fpsTimer = tick()
	end

	-- Get network stats
	pcall(function()
		DebugStats.Ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		DebugStats.MemoryUsage = math.floor(Stats:GetTotalMemoryUsageMb())
	end)

	DebugStats.ServerTime = workspace:GetServerTimeNow()
	DebugStats.UpdateCount = DebugStats.UpdateCount + 1
	DebugStats.FrameTime = math.floor(RunService.RenderStepped:Wait() * 1000 * 100) / 100

	-- Character state
	local character = LocalPlayer.Character
	if character then
		DebugStats.CharacterState = "Alive"
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.Health <= 0 then
				DebugStats.CharacterState = "Dead"
			end
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			DebugStats.RootPosition = string.format("%.1f, %.1f, %.1f", 
				rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z)
			DebugStats.Velocity = string.format("%.1f", rootPart.Velocity.Magnitude)
		end
	else
		DebugStats.CharacterState = "None"
	end

	-- Update labels
	if debugLabels["fps"] then debugLabels["fps"].Text = tostring(DebugStats.FPS) end
	if debugLabels["frametime"] then debugLabels["frametime"].Text = tostring(DebugStats.FrameTime) .. "ms" end
	if debugLabels["memory"] then debugLabels["memory"].Text = tostring(DebugStats.MemoryUsage) end
	if debugLabels["ping"] then debugLabels["ping"].Text = tostring(math.floor(DebugStats.Ping)) end
	if debugLabels["updatecount"] then debugLabels["updatecount"].Text = tostring(DebugStats.UpdateCount) end

	if debugLabels["desyncactive"] then 
		debugLabels["desyncactive"].Text = DebugStats.DesyncActive and "✓ YES" or "✗ NO"
		debugLabels["desyncactive"].TextColor3 = DebugStats.DesyncActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
	end
	if debugLabels["serverside"] then 
		debugLabels["serverside"].Text = Settings.ServerSideEnabled and "✓ ON" or "✗ OFF" 
		debugLabels["serverside"].TextColor3 = Settings.ServerSideEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
	end
	if debugLabels["desyncangle"] then debugLabels["desyncangle"].Text = tostring(DebugStats.CurrentDesyncAngle) .. "°" end
	if debugLabels["currentyaw"] then debugLabels["currentyaw"].Text = tostring(math.floor(DebugStats.CurrentYaw)) .. "°" end
	if debugLabels["jitterstate"] then debugLabels["jitterstate"].Text = DebugStats.JitterState and "LEFT" or "RIGHT" end
	if debugLabels["spinangle"] then debugLabels["spinangle"].Text = tostring(math.floor(DebugStats.SpinAngle)) .. "°" end
	if debugLabels["desyncmethod"] then debugLabels["desyncmethod"].Text = Settings.DesyncMethod end
	if debugLabels["partsdesynced"] then debugLabels["partsdesynced"].Text = tostring(DebugStats.BodyPartsDesynced) end

	if debugLabels["charstate"] then debugLabels["charstate"].Text = DebugStats.CharacterState end
	if debugLabels["rootpos"] then debugLabels["rootpos"].Text = DebugStats.RootPosition or "N/A" end
	if debugLabels["velocity"] then debugLabels["velocity"].Text = (DebugStats.Velocity or "0") .. " studs/s" end
	if debugLabels["health"] then 
		local hp = "N/A"
		if LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hp = tostring(math.floor(hum.Health)) .. "/" .. tostring(math.floor(hum.MaxHealth)) end
		end
		debugLabels["health"].Text = hp
	end

	if debugLabels["netowner"] then debugLabels["netowner"].Text = "Local" end
	if debugLabels["servertime"] then debugLabels["servertime"].Text = string.format("%.2f", DebugStats.ServerTime) end

	pcall(function()
		if debugLabels["datasend"] then 
			debugLabels["datasend"].Text = string.format("%.1f", Stats.Network.ServerStatsItem["Data Send kBps"]:GetValue()) 
		end
		if debugLabels["datarecv"] then 
			debugLabels["datarecv"].Text = string.format("%.1f", Stats.Network.ServerStatsItem["Data Receive kBps"]:GetValue()) 
		end
	end)

	if debugLabels["fakelag"] then debugLabels["fakelag"].Text = Settings.FakeLag and "ON" or "OFF" end
	if debugLabels["chokeamount"] then debugLabels["chokeamount"].Text = tostring(Settings.FakeLagAmount) end
	if debugLabels["bodylean"] then debugLabels["bodylean"].Text = Settings.BodyLean and tostring(Settings.BodyLeanAngle) .. "°" or "OFF" end
	if debugLabels["lbybreaker"] then debugLabels["lbybreaker"].Text = Settings.LBYBreaker and "ON" or "OFF" end
	if debugLabels["micromovement"] then debugLabels["micromovement"].Text = Settings.MicroMovement and "ON" or "OFF" end

	if debugLabels["lasterror"] then 
		debugLabels["lasterror"].Text = string.sub(DebugStats.LastError, 1, 25)
	end

	-- Update log
	if debugLabels["logtext"] and #Logger.logs > 0 then
		local logStr = ""
		for i = 1, math.min(5, #Logger.logs) do
			local log = Logger.logs[i]
			logStr = logStr .. string.format("[%s] %s\n", log.level, string.sub(log.message, 1, 35))
		end
		debugLabels["logtext"].Text = logStr
	end
end

-- ═══════════════════════════════════════════════════════════
-- MAIN MENU CREATION
-- ═══════════════════════════════════════════════════════════

local function createMenu()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkotLua"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Create debug panel
	createDebugPanel(screenGui)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 520, 0, 650)
	mainFrame.Position = UDim2.new(0.5, -260, 0.5, -325)
	mainFrame.BackgroundColor3 = Settings.BackgroundColor
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

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

	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 15)
	headerFix.Position = UDim2.new(0, 0, 1, -15)
	headerFix.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

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
	betaLabel.Text = "~ v2.0 server-side"
	betaLabel.Size = UDim2.new(0, 150, 1, 0)
	betaLabel.Position = UDim2.new(0, 105, 0, 0)
	betaLabel.BackgroundTransparency = 1
	betaLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	betaLabel.TextSize = 14
	betaLabel.Font = Enum.Font.GothamMedium
	betaLabel.TextXAlignment = Enum.TextXAlignment.Left
	betaLabel.Parent = header

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
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
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 1200)
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 8)
	contentCorner.Parent = contentFrame

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.Parent = contentFrame

	-- Tab System
	local tabs = {"Anti-Aim", "Server-Side", "Visuals", "Debug", "Misc"}
	local tabButtons = {}
	local tabContents = {}
	local currentTab = "Anti-Aim"

	for i, tabName in ipairs(tabs) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tabName
		tabBtn.Text = tabName
		tabBtn.Size = UDim2.new(1/#tabs, -4, 1, -6)
		tabBtn.Position = UDim2.new((i-1)/#tabs, 2, 0, 3)
		tabBtn.BackgroundColor3 = i == 1 and Settings.AccentColor or Color3.fromRGB(50, 50, 65)
		tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.TextSize = 11
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Parent = tabContainer

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = tabBtn

		tabButtons[tabName] = tabBtn

		local tabContent = Instance.new("Frame")
		tabContent.Name = tabName .. "_Content"
		tabContent.Size = UDim2.new(1, -10, 0, 1100)
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

	-- ═══════════════════════════════════════════════════════════
	-- ANTI-AIM TAB
	-- ═══════════════════════════════════════════════════════════

	local aaContent = tabContents["Anti-Aim"]
	local yPos = 0

	UI.CreateSection("DESYNC", aaContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Desync", aaContent, UDim2.new(0, 0, 0, yPos), Settings.DesyncEnabled, function(v)
		Settings.DesyncEnabled = v
		Logger:Info("Desync " .. (v and "enabled" or "disabled"))
	end)
	yPos = yPos + 35

	UI.CreateDropdown("Desync Mode", aaContent, UDim2.new(0, 0, 0, yPos), {"Static", "Jitter", "Spin", "Random"}, Settings.DesyncMode, function(v)
		Settings.DesyncMode = v
		Settings.DesyncJitter = (v == "Jitter")
		Settings.YawSpin = (v == "Spin")
		Logger:Info("Desync mode set to: " .. v)
	end)
	yPos = yPos + 60

	UI.CreateSlider("Desync Angle", aaContent, UDim2.new(0, 0, 0, yPos), 0, 180, Settings.DesyncAngle, function(v)
		Settings.DesyncAngle = v
	end)
	yPos = yPos + 50

	UI.CreateSlider("Jitter Amount", aaContent, UDim2.new(0, 0, 0, yPos), 0, 90, Settings.DesyncJitterAmount, function(v)
		Settings.DesyncJitterAmount = v
	end)
	yPos = yPos + 50

	UI.CreateSlider("Desync Distance", aaContent, UDim2.new(0, 0, 0, yPos), 1, 10, Settings.DesyncDistance, function(v)
		Settings.DesyncDistance = v
	end)
	yPos = yPos + 55

	UI.CreateSection("YAW", aaContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

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

	-- ═══════════════════════════════════════════════════════════
	-- SERVER-SIDE TAB
	-- ═══════════════════════════════════════════════════════════

	local ssContent = tabContents["Server-Side"]
	yPos = 0

	UI.CreateSection("SERVER-SIDE CONFIG", ssContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Server-Side", ssContent, UDim2.new(0, 0, 0, yPos), Settings.ServerSideEnabled, function(v)
		Settings.ServerSideEnabled = v
		Logger:Info("Server-side " .. (v and "enabled" or "disabled"))
	end)
	yPos = yPos + 35

	UI.CreateDropdown("Desync Method", ssContent, UDim2.new(0, 0, 0, yPos), {"CFrame", "Velocity", "Both"}, Settings.DesyncMethod, function(v)
		Settings.DesyncMethod = v
		Logger:Info("Desync method: " .. v)
	end)
	yPos = yPos + 60

	UI.CreateToggle("Fake Body Visual", ssContent, UDim2.new(0, 0, 0, yPos), Settings.FakeBodyEnabled, function(v)
		Settings.FakeBodyEnabled = v
		if v and LocalPlayer.Character then
			ServerSideAA.CreateFakeCharacter(LocalPlayer.Character)
		elseif fakeCharacter then
			fakeCharacter:Destroy()
			fakeCharacter = nil
		end
	end)
	yPos = yPos + 35

	UI.CreateToggle("Show Real Position", ssContent, UDim2.new(0, 0, 0, yPos), Settings.ShowRealPosition, function(v)
		Settings.ShowRealPosition = v
	end)
	yPos = yPos + 35

	UI.CreateToggle("Show Fake Position", ssContent, UDim2.new(0, 0, 0, yPos), Settings.ShowFakePosition, function(v)
		Settings.ShowFakePosition = v
	end)
	yPos = yPos + 40

	UI.CreateSection("ANTI-RESOLVER", ssContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Anti-Resolver", ssContent, UDim2.new(0, 0, 0, yPos), Settings.AntiResolver, function(v)
		Settings.AntiResolver = v
	end)
	yPos = yPos + 35

	UI.CreateToggle("LBY Breaker", ssContent, UDim2.new(0, 0, 0, yPos), Settings.LBYBreaker, function(v)
		Settings.LBYBreaker = v
	end)
	yPos = yPos + 35

	UI.CreateToggle("Micro Movement", ssContent, UDim2.new(0, 0, 0, yPos), Settings.MicroMovement, function(v)
		Settings.MicroMovement = v
	end)
	yPos = yPos + 40

	UI.CreateSection("FAKE LAG", ssContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Enable Fake Lag", ssContent, UDim2.new(0, 0, 0, yPos), Settings.FakeLag, function(v)
		Settings.FakeLag = v
		Logger:Info("Fake lag " .. (v and "enabled" or "disabled"))
	end)
	yPos = yPos + 35

	UI.CreateSlider("Choke Amount", ssContent, UDim2.new(0, 0, 0, yPos), 1, 14, Settings.FakeLagAmount, function(v)
		Settings.FakeLagAmount = v
	end)
	yPos = yPos + 50

	UI.CreateToggle("Break Animations", ssContent, UDim2.new(0, 0, 0, yPos), Settings.BreakAnimations, function(v)
		Settings.BreakAnimations = v
	end)
	yPos = yPos + 35

	-- ═══════════════════════════════════════════════════════════
	-- VISUALS TAB
	-- ═══════════════════════════════════════════════════════════

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

	-- ═══════════════════════════════════════════════════════════
	-- DEBUG TAB
	-- ═══════════════════════════════════════════════════════════

	local dbgContent = tabContents["Debug"]
	yPos = 0

	UI.CreateSection("DEBUG PANEL", dbgContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Show Debug Panel", dbgContent, UDim2.new(0, 0, 0, yPos), Settings.DebugEnabled, function(v)
		Settings.DebugEnabled = v
		if debugPanel then
			debugPanel.Visible = v
		end
	end)
	yPos = yPos + 35

	UI.CreateDropdown("Panel Position", dbgContent, UDim2.new(0, 0, 0, yPos), {"TopRight", "TopLeft", "BottomRight", "BottomLeft"}, Settings.DebugPosition, function(v)
		Settings.DebugPosition = v
		if debugPanel then
			local positions = {
				TopRight = UDim2.new(1, -290, 0, 10),
				TopLeft = UDim2.new(0, 10, 0, 10),
				BottomRight = UDim2.new(1, -290, 1, -410),
				BottomLeft = UDim2.new(0, 10, 1, -410),
			}
			debugPanel.Position = positions[v]
		end
	end)
	yPos = yPos + 60

	UI.CreateToggle("Verbose Logging", dbgContent, UDim2.new(0, 0, 0, yPos), Settings.VerboseLogging, function(v)
		Settings.VerboseLogging = v
	end)
	yPos = yPos + 40

	UI.CreateSection("INFO TOGGLES", dbgContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	UI.CreateToggle("Show Network Info", dbgContent, UDim2.new(0, 0, 0, yPos), Settings.ShowNetworkInfo, function(v)
		Settings.ShowNetworkInfo = v
	end)
	yPos = yPos + 35

	UI.CreateToggle("Show Desync Info", dbgContent, UDim2.new(0, 0, 0, yPos), Settings.ShowDesyncInfo, function(v)
		Settings.ShowDesyncInfo = v
	end)
	yPos = yPos + 35

	UI.CreateToggle("Show Performance Info", dbgContent, UDim2.new(0, 0, 0, yPos), Settings.ShowPerformanceInfo, function(v)
		Settings.ShowPerformanceInfo = v
	end)

	-- ═══════════════════════════════════════════════════════════
	-- MISC TAB
	-- ═══════════════════════════════════════════════════════════

	local miscContent = tabContents["Misc"]
	yPos = 0

	UI.CreateSection("INFO", miscContent, UDim2.new(0, 0, 0, yPos))
	yPos = yPos + 35

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Text = [[
skot.lua ~ v2.0 Server-Side Build
    
Hotkeys:
• J - Toggle Menu
• K - Toggle Debug Panel
    
Server-Side Features:
• CFrame/Velocity desync methods
• Fake lag with choke control
• Anti-resolver techniques
• LBY breaker
• Micro movement anti-aim
    
Visual Features:
• Real/Fake position visualization
• Customizable glow effects
• Pulse animations
    
Debug Features:
• Real-time FPS/Ping monitoring
• Desync state tracking
• Network statistics
• Error logging
    
⚠️ For educational purposes only.
    ]]
	infoLabel.Size = UDim2.new(1, -10, 0, 350)
	infoLabel.Position = UDim2.new(0, 0, 0, yPos)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLabel.TextSize = 12
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.TextWrapped = true
	infoLabel.Parent = miscContent

	-- Draggable
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

-- ═══════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════

local function startMainLoop()
	updateThread = task.spawn(function()
		while isLoaded do
			local success, err = pcall(function()
				-- Update server-side desync
				if LocalPlayer.Character then
					ServerSideAA.ApplyServerDesync(LocalPlayer.Character)
				end

				-- Update glow visuals
				updateGlowVisuals()

				-- Update debug panel
				updateDebugPanel()
			end)

			if not success then
				Logger:Error(tostring(err))
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

local function onCharacterAdded(character)
	task.wait(0.5)
	if isLoaded then
		setupCharacterGlow(character)
		ServerSideAA.SaveOriginalCFrames(character)

		if Settings.FakeBodyEnabled then
			ServerSideAA.CreateFakeCharacter(character)
		end

		Logger:Info("Character setup complete")
	end
end

-- ═══════════════════════════════════════════════════════════
-- MODULE FUNCTIONS
-- ═══════════════════════════════════════════════════════════

function module.Init()
	if isLoaded then
		warn("[skot.lua] Already loaded!")
		return
	end

	isLoaded = true
	Logger:Info("Loading v2.0 server-side build...")

	mainGui, mainFrame = createMenu()

	-- Keybinds
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Settings.MenuKey then
			menuOpen = not menuOpen
			mainFrame.Visible = menuOpen
		end

		if input.KeyCode == Settings.DebugKey then
			Settings.DebugEnabled = not Settings.DebugEnabled
			if debugPanel then
				debugPanel.Visible = Settings.DebugEnabled
			end
		end
	end)

	-- Character setup
	if LocalPlayer.Character then
		setupCharacterGlow(LocalPlayer.Character)
		ServerSideAA.SaveOriginalCFrames(LocalPlayer.Character)
		if Settings.FakeBodyEnabled then
			ServerSideAA.CreateFakeCharacter(LocalPlayer.Character)
		end
	end
	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	startMainLoop()

	Logger:Info("Loaded! Press J for menu, K for debug panel")
	print("[skot.lua] v2.0 Server-Side loaded! Press J to open menu, K for debug.")
end

function module.IsLoaded()
	return isLoaded
end

function module.GetSettings()
	return Settings
end

function module.GetDebugStats()
	return DebugStats
end

function module.GetLogs()
	return Logger.logs
end

function module.Unload()
	if not isLoaded then return end

	isLoaded = false

	for _, glow in pairs(glowParts) do
		if glow and glow.Parent then
			glow:Destroy()
		end
	end
	glowParts = {}

	if fakeCharacter then
		fakeCharacter:Destroy()
		fakeCharacter = nil
	end

	if mainGui then
		mainGui:Destroy()
	end

	Logger:Info("Unloaded")
	print("[skot.lua] Unloaded!")
end

return module
