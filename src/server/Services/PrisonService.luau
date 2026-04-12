-- Manages the prison: teleporting captured players, door interaction (Y key)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local PrisonService = {}

local isDoorOpen = false
local doorCloseThread: thread? = nil

local RemoteService
local PlayerService
local RoundService

local doorInteractCooldown: { [Player]: number } = {}

function PrisonService:Init(remoteService, playerService, roundService)
	RemoteService = remoteService
	PlayerService = playerService
	RoundService = roundService

	Players.PlayerRemoving:Connect(function(player)
		doorInteractCooldown[player] = nil
	end)

	-- Listen for door interact from clients
	local doorRemote = RemoteService:Get(RemoteEventNames.DoorInteract)
	if doorRemote then
		doorRemote.OnServerEvent:Connect(function(player)
			self:_onDoorInteract(player)
		end)
	end

	print("[PrisonService] Initialized")
end

function PrisonService:TeleportToPrison(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local prisonSpawn = workspace:FindFirstChild("PrisonSpawn")
	if not prisonSpawn then
		warn("[PrisonService] PrisonSpawn not found in workspace")
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = prisonSpawn.CFrame + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
	end
end

function PrisonService:TeleportFromPrison(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local prisonExit = workspace:FindFirstChild("PrisonExit")
	if not prisonExit then
		warn("[PrisonService] PrisonExit not found in workspace")
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = prisonExit.CFrame + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
	end
end

function PrisonService:OpenDoor()
	if isDoorOpen then
		return
	end

	isDoorOpen = true
	RemoteService:FireAll(RemoteEventNames.DoorStateChanged, true)
	print("[PrisonService] Door opened")

	-- Animate door in workspace if it exists
	local door = workspace:FindFirstChild("PrisonDoor")
	if door then
		door.Transparency = 0.8
		door.CanCollide = false
	end

	-- Free all captured players
	local captured = PlayerService:GetCapturedPlayers()
	for _, player in captured do
		PlayerService:FreePlayer(player)
		self:TeleportFromPrison(player)
	end

	-- Auto-close after configured time
	if doorCloseThread then
		task.cancel(doorCloseThread)
	end

	doorCloseThread = task.delay(GameConfig.PRISON_DOOR_OPEN_TIME, function()
		self:CloseDoor()
	end)
end

function PrisonService:CloseDoor()
	if not isDoorOpen then
		return
	end

	if doorCloseThread then
		task.cancel(doorCloseThread)
	end

	isDoorOpen = false
	doorCloseThread = nil
	RemoteService:FireAll(RemoteEventNames.DoorStateChanged, false)
	print("[PrisonService] Door closed")

	local door = workspace:FindFirstChild("PrisonDoor")
	if door then
		door.Transparency = 0
		door.CanCollide = true
	end
end

function PrisonService:IsDoorOpen(): boolean
	return isDoorOpen
end

function PrisonService:Reset()
	-- Teleport captured players out before closing door and resetting state
	local captured = PlayerService:GetCapturedPlayers()
	for _, player in captured do
		self:TeleportFromPrison(player)
	end
	self:CloseDoor()
end

-- Private

function PrisonService:_onDoorInteract(player: Player)
	-- Rate limit: 2 second cooldown per player
	local now = os.clock()
	if doorInteractCooldown[player] and now - doorInteractCooldown[player] < 2 then
		return
	end
	doorInteractCooldown[player] = now

	-- Only during Hunt phase
	if RoundService:GetState() ~= "Hunt" then
		return
	end

	local data = PlayerService:GetData(player)
	if not data or data.state ~= "Alive" then
		return
	end

	-- Check proximity to prison door
	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local doorPart = workspace:FindFirstChild("PrisonDoor")
	if not humanoidRootPart or not doorPart then
		return
	end

	local distance = (humanoidRootPart.Position - doorPart.Position).Magnitude
	if distance > GameConfig.PRISON_DOOR_INTERACT_RADIUS then
		return
	end

	-- Only award coins if door actually opens (prevents TOCTOU double-award)
	if isDoorOpen then
		return
	end

	local capturedCount = #PlayerService:GetCapturedPlayers()
	self:OpenDoor()

	if capturedCount > 0 then
		PlayerService:AddCoins(player, GameConfig.COINS_FREE_PRISONER)
	end
end

return PrisonService
