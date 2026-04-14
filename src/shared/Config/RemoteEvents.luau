-- Remote event names used for server-client communication
-- All RemoteEvents are created by the server in ReplicatedStorage.Remotes

local RemoteEvents = {
	-- Server → All Clients (positional args)
	GameStateChanged = "GameStateChanged", -- args: state: string, timeRemaining: number
	PlayerCaptured = "PlayerCaptured", -- args: userId: number
	PlayerFreed = "PlayerFreed", -- args: userId: number
	DoorStateChanged = "DoorStateChanged", -- args: isOpen: boolean

	-- Server → Individual Client (positional args)
	CoinsUpdated = "CoinsUpdated", -- args: newTotal: number
	SpeedUpdated = "SpeedUpdated", -- args: newSpeed: number

	-- Client → Server (no args, player is implicit)
	DoorInteract = "DoorInteract",

	-- Queue system
	QueueJoin = "QueueJoin",
	QueueLeave = "QueueLeave",
	QueueStateChanged = "QueueStateChanged",
	MovementLockChanged = "MovementLockChanged",
}

return RemoteEvents
