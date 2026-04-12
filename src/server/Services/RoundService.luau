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

function RoundService:Init(remoteService, playerService, prisonService)
	RemoteService = remoteService
	PlayerService = playerService
	PrisonService = prisonService
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

function RoundService:_countdown(duration: number): boolean
	timeRemaining = duration
	while timeRemaining > 0 do
		task.wait(1)
		timeRemaining -= 1

		-- Notify clients every 5 seconds or in the last 5 seconds
		if timeRemaining % 5 == 0 or timeRemaining <= 5 then
			RemoteService:FireAll(RemoteEventNames.GameStateChanged, state, timeRemaining)
		end
	end
	return true
end

-- Phase: Intermission
function RoundService:_runIntermission()
	self:_setState("Intermission", GameConfig.INTERMISSION_DURATION)

	-- Wait for enough players
	while #Players:GetPlayers() < GameConfig.MIN_PLAYERS do
		task.wait(1)
	end

	self:_countdown(GameConfig.INTERMISSION_DURATION)
end

-- Phase: SafeZone (players train, Kissy stays in castle)
function RoundService:_runSafeZone()
	roundNumber += 1
	print("[RoundService] Round", roundNumber, "starting")

	PlayerService:ResetForRound()
	PrisonService:Reset()
	self:_setState("SafeZone", GameConfig.SAFE_ZONE_DURATION)
	self:_countdown(GameConfig.SAFE_ZONE_DURATION)
end

-- Phase: Hunt (Kissy chases players)
function RoundService:_runHunt()
	self:_setState("Hunt", GameConfig.ROUND_DURATION)

	-- Countdown with win condition check each second
	timeRemaining = GameConfig.ROUND_DURATION
	while timeRemaining > 0 do
		task.wait(1)
		timeRemaining -= 1

		-- Check: all players captured = Kissy wins
		local alive = PlayerService:GetAlivePlayers()
		if #alive == 0 then
			print("[RoundService] All players captured — Kissy wins!")
			return
		end

		-- Periodic client updates
		if timeRemaining % 5 == 0 or timeRemaining <= 5 then
			RemoteService:FireAll(RemoteEventNames.GameStateChanged, state, timeRemaining)
		end
	end

	-- Time ran out = players win
	print("[RoundService] Time's up — players win!")
end

-- Phase: RoundEnd (award coins, show results)
function RoundService:_runRoundEnd()
	self:_setState("RoundEnd", 5)

	-- Award survivors
	PlayerService:AwardSurvivors()

	self:_countdown(5)
end

return RoundService
