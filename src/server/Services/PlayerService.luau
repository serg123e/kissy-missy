-- Manages player state, speed, coins, and leaderboard
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local PlayerService = {}

-- { [Player]: PlayerData }
local playerData: {
	[Player]: {
		state: string,
		speed: number,
		captureTime: number?,
		coins: number,
		joinedRound: number, -- which round the player joined; 0 = before first round
		movementLocked: boolean,
	},
} =
	{}

local currentRound: number = 0

local RemoteService -- injected via Init
local onCaptureCallback: ((Player) -> ())? = nil
local onAllCapturedCallback: (() -> ())? = nil

function PlayerService:Init(remoteService)
	RemoteService = remoteService

	-- Set up leaderboard stats
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerData[player] = nil
	end)

	-- Handle players already in game
	for _, player in Players:GetPlayers() do
		if not playerData[player] then
			self:_onPlayerAdded(player)
		end
	end

	print("[PlayerService] Initialized")
end

function PlayerService:_onPlayerAdded(player: Player)
	playerData[player] = {
		state = "Alive",
		speed = GameConfig.BASE_PLAYER_SPEED,
		captureTime = nil,
		coins = 0,
		joinedRound = 0,
		movementLocked = false,
	}

	-- Re-apply stored speed (or lock) when character respawns
	player.CharacterAdded:Connect(function(character)
		local data = playerData[player]
		if not data then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			if data.movementLocked then
				humanoid.WalkSpeed = 0
			else
				humanoid.WalkSpeed = data.speed
			end
		end
	end)

	-- Leaderboard display
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = 0
	coinsValue.Parent = leaderstats
end

function PlayerService:GetData(player: Player)
	return playerData[player]
end

function PlayerService:GetAllData()
	return playerData
end

function PlayerService:GetAlivePlayers(): { Player }
	local alive = {}
	for player, data in playerData do
		if data.state == "Alive" then
			table.insert(alive, player)
		end
	end
	return alive
end

function PlayerService:GetCapturedPlayers(): { Player }
	local captured = {}
	for player, data in playerData do
		if data.state == "Captured" then
			table.insert(captured, player)
		end
	end
	return captured
end

function PlayerService:CapturePlayer(player: Player)
	local data = playerData[player]
	if not data or data.state ~= "Alive" then
		return
	end

	data.state = "Captured"
	data.captureTime = os.clock()

	RemoteService:FireAll(RemoteEventNames.PlayerCaptured, player.UserId)
	print("[PlayerService]", player.Name, "captured")

	if onCaptureCallback then
		onCaptureCallback(player)
	end

	if onAllCapturedCallback and #self:GetAlivePlayers() == 0 then
		onAllCapturedCallback()
	end
end

function PlayerService:SetOnCapture(callback: (Player) -> ())
	onCaptureCallback = callback
end

function PlayerService:SetOnAllCaptured(callback: () -> ())
	onAllCapturedCallback = callback
end

function PlayerService:FreePlayer(player: Player)
	local data = playerData[player]
	if not data or data.state ~= "Captured" then
		return
	end

	data.state = "Alive"
	data.captureTime = nil

	RemoteService:FireAll(RemoteEventNames.PlayerFreed, player.UserId)
	print("[PlayerService]", player.Name, "freed")
end

function PlayerService:AddCoins(player: Player, amount: number)
	local data = playerData[player]
	if not data then
		return
	end

	data.coins += amount

	-- Update leaderboard display
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coinsValue = leaderstats:FindFirstChild("Coins")
		if coinsValue then
			coinsValue.Value = data.coins
		end
	end

	RemoteService:FireClient(player, RemoteEventNames.CoinsUpdated, data.coins)
end

function PlayerService:LockMovement(player: Player)
	local data = playerData[player]
	if not data then
		return
	end

	data.movementLocked = true

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
		end
	end
end

function PlayerService:UnlockMovement(player: Player)
	local data = playerData[player]
	if not data then
		return
	end

	data.movementLocked = false

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = data.speed
		end
	end
end

function PlayerService:SetSpeed(player: Player, speed: number)
	local data = playerData[player]
	if not data then
		return
	end

	data.speed = math.min(speed, GameConfig.MAX_PLAYER_SPEED)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and not data.movementLocked then
			humanoid.WalkSpeed = data.speed
		end
	end

	RemoteService:FireClient(player, RemoteEventNames.SpeedUpdated, data.speed)
end

function PlayerService:SetRound(roundNumber: number)
	currentRound = roundNumber
end

function PlayerService:ResetForRound()
	for player, data in playerData do
		data.state = "Alive"
		data.speed = GameConfig.BASE_PLAYER_SPEED
		data.captureTime = nil
		data.movementLocked = false
		self:SetSpeed(player, GameConfig.BASE_PLAYER_SPEED)
	end
end

function PlayerService:SnapshotEligible(roundNumber: number)
	for _, data in playerData do
		data.joinedRound = roundNumber
	end
end

function PlayerService:TeleportAllToCloud()
	local cloudSpawn = workspace:FindFirstChild("CloudSpawn")
	if not cloudSpawn then
		warn("[PlayerService] CloudSpawn not found in workspace")
		return
	end
	for player in playerData do
		self:_teleportToPart(player, cloudSpawn)
	end
end

function PlayerService:TeleportAllToCastle()
	local spawns = self:_getSpawnLocations()
	for player in playerData do
		self:_teleportToSpawn(player, spawns)
	end
end

function PlayerService:_getSpawnLocations(): { SpawnLocation }
	local folder = workspace:FindFirstChild("SpawnLocations")
	if not folder then
		return {}
	end
	local spawns = {}
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") then
			table.insert(spawns, child)
		end
	end
	return spawns
end

function PlayerService:_teleportToPart(player: Player, part: BasePart)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	hrp.CFrame = part.CFrame + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
end

function PlayerService:_teleportToSpawn(player: Player, spawns: { SpawnLocation })
	if #spawns == 0 then
		return
	end
	local spawn = spawns[math.random(#spawns)]
	self:_teleportToPart(player, spawn)
end

function PlayerService:AwardSurvivors()
	for player, data in playerData do
		-- Only award players who were present at round start (not mid-round joiners)
		if data.state == "Alive" and data.joinedRound == currentRound then
			self:AddCoins(player, GameConfig.COINS_SURVIVE_ROUND)
			print("[PlayerService]", player.Name, "survived — earned", GameConfig.COINS_SURVIVE_ROUND, "coins")
		end
	end
end

return PlayerService
