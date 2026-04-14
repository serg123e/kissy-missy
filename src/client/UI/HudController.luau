-- Creates and manages the game HUD: state/timer, coins, door prompt, notifications
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)
local TimeFormat = require(ReplicatedStorage.Shared.Logic.TimeFormat)

local HudController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- State
local currentState = "Intermission"
local timeRemaining = 0
local lastServerSync = 0
local isDoorOpen = false
local isCaptured = false

-- UI elements (set in _createUI)
local stateLabel: TextLabel
local timerLabel: TextLabel
local coinsLabel: TextLabel
local promptLabel: TextLabel
local notifLabel: TextLabel
local queueStatusLabel: TextLabel
local queueStatusFrame: Frame
local leaveQueueButton: TextButton

local notifThread: thread? = nil

function HudController:Init()
	self:_createUI()
	self:_startHudLoop()
	print("[HudController] Initialized")
end

-- Public: called from init.client.luau when remotes fire

function HudController:UpdateGameState(state: string, remaining: number)
	currentState = state
	timeRemaining = remaining
	lastServerSync = os.clock()

	stateLabel.Text = self:_stateDisplay(state)

	if state == "SafeZone" then
		isCaptured = false
	end
end

function HudController:UpdateCoins(total: number)
	coinsLabel.Text = tostring(total)
end

function HudController:OnPlayerCaptured(userId: number)
	if userId == player.UserId then
		isCaptured = true
		self:_notify("You were captured!")
	else
		local p = Players:GetPlayerByUserId(userId)
		if p then
			self:_notify(p.Name .. " was captured!")
		end
	end
end

function HudController:OnPlayerFreed(userId: number)
	if userId == player.UserId then
		isCaptured = false
		self:_notify("You were freed!")
	else
		local p = Players:GetPlayerByUserId(userId)
		if p then
			self:_notify(p.Name .. " escaped!")
		end
	end
end

function HudController:OnDoorStateChanged(isOpen: boolean)
	isDoorOpen = isOpen
	if isOpen then
		self:_notify("Prison door opened!")
	end
end

function HudController:OnQueueStateChanged(data: {
	treadmillName: string,
	position: number?,
	isActive: boolean,
	isRejected: boolean,
})
	if data.isRejected then
		self:_notify("Queue full — try another treadmill")
		return
	end

	if data.position == nil then
		queueStatusFrame.Visible = false
		leaveQueueButton.Visible = false
		return
	end

	if data.isActive then
		queueStatusLabel.Text = "Active on " .. data.treadmillName
		leaveQueueButton.Text = "Leave Treadmill"
		leaveQueueButton.Visible = true
	else
		queueStatusLabel.Text = "Queue #" .. tostring(data.position - 1) .. " for " .. data.treadmillName
		leaveQueueButton.Text = "Leave Queue"
		leaveQueueButton.Visible = true
	end
	queueStatusFrame.Visible = true
end

-- Private: UI creation

function HudController:_createUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GameHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Top center: state + timer
	local stateFrame = self:_panel(gui, UDim2.fromOffset(260, 56), UDim2.new(0.5, -130, 0, 10))

	stateLabel = self:_label(stateFrame, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 4),
		TextSize = 16,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		Text = "INTERMISSION",
	})

	timerLabel = self:_label(stateFrame, {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 26),
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 220, 80),
		Text = "0:00",
	})

	-- Top right: coins
	local coinsFrame = self:_panel(gui, UDim2.fromOffset(140, 36), UDim2.new(1, -150, 0, 10))

	self:_label(coinsFrame, {
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 215, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "$",
	})

	coinsLabel = self:_label(coinsFrame, {
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
	})

	-- Bottom center: door interaction prompt
	promptLabel = self:_label(gui, {
		Size = UDim2.fromOffset(260, 36),
		Position = UDim2.new(0.5, -130, 1, -80),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "[Y] Open Prison Door",
		Visible = false,
	})

	local promptBg = Instance.new("Frame")
	promptBg.Size = UDim2.fromScale(1, 1)
	promptBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	promptBg.BackgroundTransparency = 0.5
	promptBg.BorderSizePixel = 0
	promptBg.ZIndex = promptLabel.ZIndex - 1
	promptBg.Parent = promptLabel

	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 6)
	promptCorner.Parent = promptBg

	-- Center: notifications
	notifLabel = self:_label(gui, {
		Size = UDim2.fromOffset(400, 40),
		Position = UDim2.new(0.5, -200, 0, 80),
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 100, 100),
		Text = "",
		Visible = false,
	})

	-- Bottom left: queue status
	queueStatusFrame = self:_panel(gui, UDim2.fromOffset(260, 36), UDim2.new(0, 10, 1, -50))
	queueStatusFrame.Visible = false

	queueStatusLabel = self:_label(queueStatusFrame, {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextSize = 16,
		TextColor3 = Color3.fromRGB(120, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	leaveQueueButton = Instance.new("TextButton")
	leaveQueueButton.Size = UDim2.fromOffset(140, 36)
	leaveQueueButton.Position = UDim2.new(0, 10, 1, -92)
	leaveQueueButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	leaveQueueButton.BackgroundTransparency = 0.3
	leaveQueueButton.BorderSizePixel = 0
	leaveQueueButton.Font = Enum.Font.GothamBold
	leaveQueueButton.TextSize = 16
	leaveQueueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaveQueueButton.Text = "Leave Queue"
	leaveQueueButton.Visible = false
	leaveQueueButton.Parent = gui

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 8)
	leaveCorner.Parent = leaveQueueButton

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local queueLeaveRemote = remotesFolder:WaitForChild(RemoteEventNames.QueueLeave)
	leaveQueueButton.Activated:Connect(function()
		queueLeaveRemote:FireServer()
	end)
end

function HudController:_panel(parent: Instance, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	return frame
end

function HudController:_label(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.Text = ""

	for key, value in props do
		(label :: any)[key] = value
	end

	label.Parent = parent
	return label
end

-- Private: loops

function HudController:_startHudLoop()
	RunService.Heartbeat:Connect(function()
		-- Client-side countdown between server syncs
		local elapsed = os.clock() - lastServerSync
		local display = math.max(0, math.floor(timeRemaining - elapsed))
		timerLabel.Text = TimeFormat.format(display)

		promptLabel.Visible = self:_shouldShowPrompt()
	end)
end

function HudController:_shouldShowPrompt(): boolean
	-- Only show during Hunt — server rejects door interact in other phases
	if currentState ~= "Hunt" then
		return false
	end
	if isCaptured or isDoorOpen then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local door = workspace:FindFirstChild("PrisonDoor")
	if not hrp or not door then
		return false
	end

	local dist = (hrp.Position - door.Position).Magnitude
	return dist <= GameConfig.PRISON_DOOR_INTERACT_RADIUS
end

-- Private: helpers

function HudController:_stateDisplay(state: string): string
	if state == "Intermission" then
		return "INTERMISSION"
	elseif state == "SafeZone" then
		return "SAFE ZONE"
	elseif state == "Hunt" then
		return "HUNT"
	elseif state == "RoundEnd" then
		return "ROUND OVER"
	end
	return state:upper()
end

function HudController:_notify(text: string)
	if notifThread then
		task.cancel(notifThread)
	end

	notifLabel.Text = text
	notifLabel.Visible = true

	notifThread = task.delay(3, function()
		notifLabel.Visible = false
		notifThread = nil
	end)
end

return HudController
