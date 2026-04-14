-- Round lifecycle: Intermission → SafeZone → Hunt → RoundEnd → repeat
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteEventNames = require(ReplicatedStorage.Shared.Config.RemoteEvents)

local RoundService = {}

local state: string = "Intermission"
local timeRemaining: number = 0
local roundNumber: number = 0

local RemoteService
local PlayerService
local PrisonService
local KissyService

function RoundService:Init(remoteService, playerService, prisonService, kissyService)
	RemoteService = remoteService
	PlayerService = playerService
	PrisonService = prisonService
	KissyService = kissyService
	print("[RoundService] Initialized")
end

function RoundService:Start()
	task.spawn(function()
		while true do
			self:_runIntermission()
			self:_runSafeZone()
			self:_runHunt()
			self:_runRoundEnd()
		end
	end)
	print("[RoundService] Game loop started")
end

function RoundService:GetState(): string
	return state
end

function RoundService:GetTimeRemaining(): number
	return timeRemaining
end

-- Private: state transitions

function RoundService:_setState(newState: string, duration: number)
	state = newState
	timeRemaining = duration
	print("[RoundService] State →", newState, "(" .. duration .. "s)")
	RemoteService:FireAll(RemoteEventNames.GameStateChanged, state, timeRemaining)
end

function RoundService:_countdown(duration: number, shouldStop: (() -> boolean)?)
	timeRemaining = duration
	while timeRemaining > 0 do
		task.wait(1)
		timeRemaining -= 1

		if shouldStop and shouldStop() then
			return true -- early exit
		end

		-- Notify clients every 5 seconds or in the last 5 seconds
		if timeRemaining % 5 == 0 or timeRemaining <= 5 then
			RemoteService:FireAll(RemoteEventNames.GameStateChanged, state, timeRemaining)
		end
	end
	return false -- completed naturally
end

-- Phase: Intermission
function RoundService:_runIntermission()
	self:_setState("Intermission", GameConfig.INTERMISSION_DURATION)

	-- Wait for enough players (no timer while waiting)
	while #Players:GetPlayers() < GameConfig.MIN_PLAYERS do
		task.wait(1)
		RemoteService:FireAll(RemoteEventNames.GameStateChanged, state, GameConfig.INTERMISSION_DURATION)
	end

	-- Once enough players, run the countdown once
	self:_countdown(GameConfig.INTERMISSION_DURATION)
end

-- Phase: SafeZone (players train, Kissy stays in castle)
function RoundService:_runSafeZone()
	roundNumber += 1
	print("[RoundService] Round", roundNumber, "starting")

	PrisonService:Reset() -- teleport captured players out first
	PlayerService:SetRound(roundNumber)
	PlayerService:ResetForRound()
	PlayerService:TeleportAllToCloud()
	KissyService:Activate() -- spawn Kissy in castle, starts hunting after KISSY_SPAWN_DELAY
	self:_setState("SafeZone", GameConfig.SAFE_ZONE_DURATION)
	self:_countdown(GameConfig.SAFE_ZONE_DURATION)
end

-- Phase: Hunt (Kissy chases players)
-- Kissy Missy is already hunting (activated during SafeZone with KISSY_SPAWN_DELAY).
function RoundService:_runHunt()
	PlayerService:TeleportAllToCastle()
	self:_setState("Hunt", GameConfig.ROUND_DURATION)

	local kissyWon = self:_countdown(GameConfig.ROUND_DURATION, function()
		local alive = PlayerService:GetAlivePlayers()
		-- Distinguish "all captured" from "server empty"
		return #alive == 0 and #Players:GetPlayers() > 0
	end)

	if kissyWon then
		print("[RoundService] All players captured — Kissy wins!")
	else
		print("[RoundService] Time's up — players win!")
	end
end

-- Phase: RoundEnd (award coins, show results)
function RoundService:_runRoundEnd()
	KissyService:Deactivate() -- stop hunting and despawn Kissy
	self:_setState("RoundEnd", GameConfig.ROUND_END_DURATION)

	-- Award survivors
	PlayerService:AwardSurvivors()

	self:_countdown(GameConfig.ROUND_END_DURATION)
end

return RoundService
