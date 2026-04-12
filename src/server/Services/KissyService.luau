-- Manages Kissy Missy NPC: spawning, AI chase behavior, and player capture
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local KissyService = {}

local kissyModel: Model? = nil
local isHunting = false
local huntThread: thread? = nil

local PlayerService

-- Pathfinding: recompute interval and state
local PATH_RECOMPUTE_INTERVAL = 1 -- seconds between path recomputation
local lastPathTime = 0
local currentWaypoints: { PathWaypoint } = {}
local currentWaypointIndex = 0

-- AI: occasional random target switch
local RANDOM_RETARGET_CHANCE = 0.1 -- 10% chance per retarget to pick a random player

function KissyService:Init(playerService)
	PlayerService = playerService
	print("[KissyService] Initialized")
end

-- Called at the start of SafeZone phase.
-- Spawns Kissy in the castle, waits KISSY_SPAWN_DELAY, then starts hunting.
function KissyService:Activate()
	self:_spawnKissy()

	huntThread = task.spawn(function()
		task.wait(GameConfig.KISSY_SPAWN_DELAY)

		isHunting = true
		lastPathTime = 0
		currentWaypoints = {}
		currentWaypointIndex = 0
		print("[KissyService] Kissy Missy is hunting!")

		while isHunting do
			self:_huntTick()
			task.wait(0.5)
		end
	end)
end

-- Called at RoundEnd. Stops hunting and removes the NPC.
function KissyService:Deactivate()
	isHunting = false
	if huntThread then
		task.cancel(huntThread)
		huntThread = nil
	end
	currentWaypoints = {}
	currentWaypointIndex = 0
	self:_despawnKissy()
end

-- Spawn

function KissyService:_spawnKissy()
	self:_despawnKissy()

	local kissySpawn = workspace:FindFirstChild("KissySpawn")
	if not kissySpawn then
		warn("[KissyService] KissySpawn part not found in workspace")
		return
	end

	local template = ServerStorage:FindFirstChild("KissyMissy")
	if not template then
		warn("[KissyService] KissyMissy model not found in ServerStorage")
		return
	end

	kissyModel = template:Clone()
	kissyModel.Parent = workspace

	local humanoidRootPart = kissyModel:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = kissySpawn.CFrame + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
	end

	local humanoid = kissyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.KISSY_SPEED
	end

	print("[KissyService] Kissy Missy spawned")
end

function KissyService:_despawnKissy()
	if kissyModel then
		kissyModel:Destroy()
		kissyModel = nil
	end
end

-- AI loop

function KissyService:_huntTick()
	if not kissyModel then
		return
	end

	local humanoidRootPart = kissyModel:FindFirstChild("HumanoidRootPart")
	local humanoid = kissyModel:FindFirstChildOfClass("Humanoid")
	if not humanoidRootPart or not humanoid then
		return
	end

	local kissyPos = humanoidRootPart.Position

	-- 1. Catch nearby players
	self:_checkCatches(kissyPos)

	-- 2. Pick target
	local targetPos = self:_pickTarget(kissyPos)
	if not targetPos then
		return
	end

	-- 3. Move toward target (recompute path periodically)
	local now = os.clock()
	if now - lastPathTime >= PATH_RECOMPUTE_INTERVAL then
		lastPathTime = now
		self:_computePath(kissyPos, targetPos, humanoid)
	end

	self:_followPath(humanoid)
end

function KissyService:_checkCatches(kissyPosition: Vector3)
	local alivePlayers = PlayerService:GetAlivePlayers()
	for _, player in alivePlayers do
		local character = player.Character
		if not character then
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end
		local distance = (hrp.Position - kissyPosition).Magnitude
		if distance <= GameConfig.KISSY_CATCH_RADIUS then
			PlayerService:CapturePlayer(player)
		end
	end
end

function KissyService:_pickTarget(kissyPosition: Vector3): Vector3?
	local alivePlayers = PlayerService:GetAlivePlayers()
	if #alivePlayers == 0 then
		return nil
	end

	-- Small chance to pick a random target instead of nearest (unpredictable AI)
	if #alivePlayers > 1 and math.random() < RANDOM_RETARGET_CHANCE then
		local randomPlayer = alivePlayers[math.random(#alivePlayers)]
		local character = randomPlayer.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				return hrp.Position
			end
		end
	end

	-- Check if any alive player is near the prison door — prioritize guarding
	local doorPart = workspace:FindFirstChild("PrisonDoor")
	if doorPart then
		local closestDoorPlayer: Vector3? = nil
		local closestDoorDist = GameConfig.PRISON_DOOR_INTERACT_RADIUS * 2

		for _, player in alivePlayers do
			local character = player.Character
			if not character then
				continue
			end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end
			local distToDoor = (hrp.Position - doorPart.Position).Magnitude
			if distToDoor < closestDoorDist then
				closestDoorDist = distToDoor
				closestDoorPlayer = hrp.Position
			end
		end

		if closestDoorPlayer then
			return closestDoorPlayer
		end
	end

	-- Default: chase nearest player
	local nearestPos: Vector3? = nil
	local nearestDist = math.huge

	for _, player in alivePlayers do
		local character = player.Character
		if not character then
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end
		local dist = (hrp.Position - kissyPosition).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestPos = hrp.Position
		end
	end

	return nearestPos
end

-- Pathfinding

function KissyService:_computePath(fromPos: Vector3, targetPos: Vector3, humanoid: Humanoid)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local ok = pcall(function()
		path:ComputeAsync(fromPos, targetPos)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		currentWaypoints = path:GetWaypoints()
		-- Skip first waypoint (it's the current position)
		currentWaypointIndex = 2
	else
		-- Fallback: move directly toward target
		currentWaypoints = {}
		currentWaypointIndex = 0
		humanoid:MoveTo(targetPos)
	end
end

function KissyService:_followPath(humanoid: Humanoid)
	if currentWaypointIndex < 1 or currentWaypointIndex > #currentWaypoints then
		return
	end

	local waypoint = currentWaypoints[currentWaypointIndex]
	humanoid:MoveTo(waypoint.Position)

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end

	-- Advance to next waypoint if close enough
	local humanoidRootPart = kissyModel and kissyModel:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local dist = (humanoidRootPart.Position - waypoint.Position).Magnitude
		if dist < 4 then
			currentWaypointIndex += 1
		end
	end
end

return KissyService
