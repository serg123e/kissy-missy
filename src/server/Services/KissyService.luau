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
local RoundService

-- Pathfinding: recompute interval and state
local PATH_RECOMPUTE_INTERVAL = 1 -- seconds between path recomputation
local lastPathTime = 0
local currentWaypoints: { PathWaypoint } = {}
local currentWaypointIndex = 0
local sharedPath: Path? = nil
local blockedConnection: RBXScriptConnection? = nil
local moveToFinishedConnection: RBXScriptConnection? = nil

local function _getOrCreatePath(): Path
	if not sharedPath then
		sharedPath = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			Costs = { PrisonInterior = math.huge },
		})
		blockedConnection = sharedPath.Blocked:Connect(function(blockedWaypointIndex)
			if blockedWaypointIndex >= currentWaypointIndex then
				lastPathTime = 0
			end
		end)
	end
	return sharedPath
end

local function _destroyPath()
	if blockedConnection then
		blockedConnection:Disconnect()
		blockedConnection = nil
	end
	sharedPath = nil
end

-- AI: occasional random target switch
local RANDOM_RETARGET_CHANCE = 0.1 -- 10% chance per retarget to pick a random player

function KissyService:Init(playerService)
	PlayerService = playerService
	print("[KissyService] Initialized")
end

function KissyService:SetRoundService(roundService)
	RoundService = roundService
end

-- Called at the start of SafeZone phase.
-- Spawns Kissy in the castle, waits KISSY_SPAWN_DELAY, then starts hunting.
function KissyService:Activate()
	-- Cancel any previous hunt loop to prevent duplicate concurrent loops
	self:Deactivate()
	self:_spawnKissy()

	if kissyModel then
		local humanoid = kissyModel:FindFirstChildOfClass("Humanoid")
		if humanoid then
			moveToFinishedConnection = humanoid.MoveToFinished:Connect(function(reached)
				if not reached and kissyModel ~= nil then
					lastPathTime = 0
				end
			end)
		end
	end

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
	if moveToFinishedConnection then
		moveToFinishedConnection:Disconnect()
		moveToFinishedConnection = nil
	end
	currentWaypoints = {}
	currentWaypointIndex = 0
	_destroyPath()
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
		-- Pin NPC physics to the server so no client can diverge Kissy's position
		-- (default ownership would drift to the nearest player).
		humanoidRootPart:SetNetworkOwner(nil)
	end

	local humanoid = kissyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.KISSY_SPEED
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
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
	if RoundService and RoundService:GetState() ~= "Hunt" then
		return
	end

	local model = kissyModel
	if not model then
		return
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
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
	-- _computePath yields (ComputeAsync), so re-check model after
	local now = os.clock()
	if now - lastPathTime >= PATH_RECOMPUTE_INTERVAL then
		lastPathTime = now
		self:_computePath(kissyPos, targetPos, humanoid)
	end

	-- Model may have been destroyed during ComputeAsync yield
	if not kissyModel then
		return
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

	-- Single pass: find nearest player and nearest player to prison door
	local doorPart = workspace:FindFirstChild("PrisonDoor")
	local doorPos = doorPart and doorPart.Position
	-- 2x interact radius so Kissy starts moving toward the door before the player can press Y
	local doorThreshold = GameConfig.PRISON_DOOR_INTERACT_RADIUS * 2

	local nearestPos: Vector3? = nil
	local nearestDist = math.huge
	local doorTargetPos: Vector3? = nil
	local closestDoorDist = doorThreshold

	for _, player in alivePlayers do
		local character = player.Character
		if not character then
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end
		local pos = hrp.Position

		local dist = (pos - kissyPosition).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestPos = pos
		end

		if doorPos then
			local distToDoor = (pos - doorPos).Magnitude
			if distToDoor < closestDoorDist then
				closestDoorDist = distToDoor
				doorTargetPos = pos
			end
		end
	end

	-- Prioritize guarding the prison door over chasing nearest
	return doorTargetPos or nearestPos
end

-- Pathfinding

function KissyService:_computePath(fromPos: Vector3, targetPos: Vector3, humanoid: Humanoid)
	local path = _getOrCreatePath()

	local ok = pcall(function()
		path:ComputeAsync(fromPos, targetPos)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		currentWaypoints = path:GetWaypoints()
		currentWaypointIndex = 2
	else
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

	-- Advance past reached waypoints. At 28 studs/s with 0.5s ticks Kissy moves
	-- ~14 studs between checks, so use a generous threshold to avoid stalling.
	local humanoidRootPart = kissyModel and kissyModel:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local pos = humanoidRootPart.Position
		while currentWaypointIndex <= #currentWaypoints do
			local dist = (pos - currentWaypoints[currentWaypointIndex].Position).Magnitude
			if dist > 8 then
				break
			end
			currentWaypointIndex += 1
		end
	end
end

return KissyService
