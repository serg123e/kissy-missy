-- Remote event names used for server-client communication
-- All RemoteEvents are created by the server in ReplicatedStorage.Remotes

local RemoteEvents = {
	-- Server → Client
	GameStateChanged = "GameStateChanged", -- { state: GameState, timeRemaining: number }
	PlayerCaptured = "PlayerCaptured", -- { playerId: number }
	PlayerFreed = "PlayerFreed", -- { playerId: number }
	CoinsUpdated = "CoinsUpdated", -- { coins: number }
	SpeedUpdated = "SpeedUpdated", -- { speed: number }
	DoorStateChanged = "DoorStateChanged", -- { isOpen: boolean }

	-- Client → Server
	DoorInteract = "DoorInteract", -- player pressed Y near prison door
}

return RemoteEvents
