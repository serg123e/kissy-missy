-- Manages the prison: teleporting captured players, door interaction (Y key)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local PrisonService = {}

local isDoorOpen = false
local doorCloseThread: thread? = nil

local RemoteService
local PlayerService

function PrisonService:Init(remoteService, playerService)
	RemoteService = remoteService
	PlayerService = playerService

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
		humanoidRootPart.CFrame = prisonSpawn.CFrame + Vector3.new(0, 3, 0)
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
		humanoidRootPart.CFrame = prisonExit.CFrame + Vector3.new(0, 3, 0)
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
	self:CloseDoor()
end

-- Private

function PrisonService:_onDoorInteract(player: Player)
	local data = PlayerService:GetData(player)
	if not data or data.state ~= "Alive" then
		return -- only alive players can open the door
	end

	-- Check if player is near the prison door
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
	if distance > 15 then
		return -- too far from the door
	end

	-- Award coins for freeing prisoners
	local capturedCount = #PlayerService:GetCapturedPlayers()
	if capturedCount > 0 then
		PlayerService:AddCoins(player, GameConfig.COINS_FREE_PRISONER)
	end

	self:OpenDoor()
end

return PrisonService
