-- Server-authoritative treadmill queue system: 1 active user + FIFO queue per treadmill
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)
local QueueLogic = require(ReplicatedStorage.Shared.Logic.QueueLogic)

type TreadmillState = {
	part: BasePart,
	activeUser: Player?,
	queue: { Player },
	lastInputTime: number?,
}

local TreadmillService = {}

local RemoteService
local PlayerService
local RoundService

local treadmills: { [string]: TreadmillState } = {}
local playerTreadmill: { [Player]: string } = {}

function TreadmillService:Init(remoteService, playerService, roundService)
	RemoteService = remoteService
	PlayerService = playerService
	RoundService = roundService
	print("[TreadmillService] Initialized")
end

function TreadmillService:Start()
	local folder = workspace:FindFirstChild("Treadmills")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				treadmills[child.Name] = {
					part = child,
					activeUser = nil,
					queue = {},
					lastInputTime = nil,
				}
			end
		end
	end

	local count = 0
	for _ in treadmills do
		count += 1
	end

	if count == 0 then
		warn("[TreadmillService] No treadmill parts found — training disabled")
		return
	end

	local queueJoinRemote = RemoteService:Get(RemoteEventNames.QueueJoin)
	if queueJoinRemote then
		queueJoinRemote.OnServerEvent:Connect(function(player, treadmillName)
			self:OnQueueJoin(player, treadmillName)
		end)
	end

	local queueLeaveRemote = RemoteService:Get(RemoteEventNames.QueueLeave)
	if queueLeaveRemote then
		queueLeaveRemote.OnServerEvent:Connect(function(player)
			self:OnQueueLeave(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.TREADMILL_TICK_SECONDS)
			self:_tick()
		end
	end)
	print("[TreadmillService] Training loop started (" .. count .. " treadmills)")
end

function TreadmillService:OnQueueJoin(player: Player, treadmillName: string)
	if typeof(treadmillName) ~= "string" then
		return
	end

	local tm = treadmills[treadmillName]
	if not tm then
		return
	end

	if playerTreadmill[player] then
		return
	end

	if RoundService:GetState() ~= "SafeZone" then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local dist = (hrp.Position - tm.part.Position).Magnitude
	if dist > GameConfig.QUEUE_JOIN_RADIUS then
		return
	end

	local result, pos = QueueLogic.tryAssign(tm, player, GameConfig.MAX_QUEUE_LENGTH)

	if result == "active" then
		tm.lastInputTime = os.clock()
		playerTreadmill[player] = treadmillName
		RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
			treadmillName = treadmillName,
			position = 1,
			isActive = true,
			isRejected = false,
		})
	elseif result == "rejected" then
		RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
			treadmillName = treadmillName,
			position = nil,
			isActive = false,
			isRejected = true,
		})
	else
		playerTreadmill[player] = treadmillName
		PlayerService:LockMovement(player)
		self:_positionQueuedPlayers(treadmillName)
		RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
			treadmillName = treadmillName,
			position = pos,
			isActive = false,
			isRejected = false,
		})
	end
end

function TreadmillService:OnQueueLeave(player: Player)
	local treadmillName = playerTreadmill[player]
	if not treadmillName then
		return
	end

	local tm = treadmills[treadmillName]
	if not tm then
		playerTreadmill[player] = nil
		return
	end

	local result, promoted = QueueLogic.remove(tm, player)
	if result == "notPresent" then
		return
	end

	playerTreadmill[player] = nil
	RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
		treadmillName = treadmillName,
		position = nil,
		isActive = false,
		isRejected = false,
	})

	if result == "wasActive" then
		tm.lastInputTime = nil
		if promoted then
			self:_settlePromotion(treadmillName, promoted)
		end
	else
		PlayerService:UnlockMovement(player)
		self:_notifyQueue(treadmillName)
		self:_positionQueuedPlayers(treadmillName)
	end
end

function TreadmillService:OnPlayerRemoving(player: Player)
	self:OnQueueLeave(player)
end

function TreadmillService:_settlePromotion(treadmillName: string, promoted: Player)
	local tm = treadmills[treadmillName]
	if not tm then
		return
	end

	PlayerService:UnlockMovement(promoted)

	local character = promoted.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		local _, nextPromoted = QueueLogic.remove(tm, promoted)
		playerTreadmill[promoted] = nil
		RemoteService:FireClient(promoted, RemoteEventNames.QueueStateChanged, {
			treadmillName = treadmillName,
			position = nil,
			isActive = false,
			isRejected = false,
		})
		self:_notifyQueue(treadmillName)
		self:_positionQueuedPlayers(treadmillName)
		if nextPromoted then
			self:_settlePromotion(treadmillName, nextPromoted)
		end
		return
	end

	hrp.CFrame = tm.part.CFrame + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
	tm.lastInputTime = os.clock()
	RemoteService:FireClient(promoted, RemoteEventNames.QueueStateChanged, {
		treadmillName = treadmillName,
		position = 1,
		isActive = true,
		isRejected = false,
	})
	self:_notifyQueue(treadmillName)
	self:_positionQueuedPlayers(treadmillName)
end

function TreadmillService:_notifyQueue(treadmillName: string)
	local tm = treadmills[treadmillName]
	if not tm then
		return
	end

	for i, player in tm.queue do
		RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
			treadmillName = treadmillName,
			position = i + 1,
			isActive = false,
			isRejected = false,
		})
	end
end

local QUEUE_SPACING = 3

function TreadmillService:_positionQueuedPlayers(treadmillName: string)
	local tm = treadmills[treadmillName]
	if not tm then
		return
	end

	local backDir = -tm.part.CFrame.LookVector
	local basePos = tm.part.Position

	for i, player in tm.queue do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local offset = backDir * (QUEUE_SPACING * i)
				local queuePos = basePos + offset + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
				local lookTarget = basePos + Vector3.new(0, GameConfig.TELEPORT_Y_OFFSET, 0)
				hrp.CFrame = CFrame.lookAt(queuePos, lookTarget)
			end
		end
	end
end

function TreadmillService:ResetAllQueues()
	for treadmillName, tm in treadmills do
		if tm.activeUser then
			local player = tm.activeUser
			tm.activeUser = nil
			tm.lastInputTime = nil
			playerTreadmill[player] = nil
			RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
				treadmillName = treadmillName,
				position = nil,
				isActive = false,
				isRejected = false,
			})
		end

		for _, player in tm.queue do
			PlayerService:UnlockMovement(player)
			playerTreadmill[player] = nil
			RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
				treadmillName = treadmillName,
				position = nil,
				isActive = false,
				isRejected = false,
			})
		end
		tm.queue = {}
	end
	print("[TreadmillService] All queues reset")
end

function TreadmillService:_tick()
	local roundState = RoundService:GetState()
	if roundState ~= "SafeZone" and roundState ~= "Hunt" then
		return
	end

	for treadmillName, tm in treadmills do
		local toRemove = {}
		for _, queuedPlayer in tm.queue do
			if not queuedPlayer.Character or not queuedPlayer.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(toRemove, queuedPlayer)
			end
		end
		for _, queuedPlayer in toRemove do
			QueueLogic.remove(tm, queuedPlayer)
			PlayerService:UnlockMovement(queuedPlayer)
			playerTreadmill[queuedPlayer] = nil
			RemoteService:FireClient(queuedPlayer, RemoteEventNames.QueueStateChanged, {
				treadmillName = treadmillName,
				position = nil,
				isActive = false,
				isRejected = false,
			})
		end
		if #toRemove > 0 then
			self:_notifyQueue(treadmillName)
			self:_positionQueuedPlayers(treadmillName)
		end

		if tm.activeUser then
			local character = tm.activeUser.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChild("Humanoid")

			local shouldKick = false
			if not hrp or (hrp.Position - tm.part.Position).Magnitude > GameConfig.QUEUE_JOIN_RADIUS then
				shouldKick = true
			else
				if humanoid and humanoid.MoveDirection.Magnitude > 0 then
					tm.lastInputTime = os.clock()
				end
				if tm.lastInputTime and os.clock() - tm.lastInputTime > GameConfig.AFK_KICK_TIMEOUT then
					shouldKick = true
				end
			end

			if shouldKick then
				local player = tm.activeUser
				local _, promoted = QueueLogic.remove(tm, player)
				tm.lastInputTime = nil
				playerTreadmill[player] = nil
				RemoteService:FireClient(player, RemoteEventNames.QueueStateChanged, {
					treadmillName = treadmillName,
					position = nil,
					isActive = false,
					isRejected = false,
				})
				if promoted then
					self:_settlePromotion(treadmillName, promoted)
				end
			else
				local data = PlayerService:GetData(tm.activeUser)
				if data and data.speed < GameConfig.MAX_PLAYER_SPEED then
					PlayerService:SetSpeed(tm.activeUser, data.speed + GameConfig.SPEED_PER_TREADMILL_TICK)
				end
			end
		end
	end
end

return TreadmillService
