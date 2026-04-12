-- Type definitions for the game
export type GameState = "Intermission" | "SafeZone" | "Hunt" | "RoundEnd"

export type PlayerState = "Alive" | "Captured" | "Spectating"

export type KissyState = "Idle" | "Chasing" | "Returning"

export type PlayerData = {
	state: PlayerState,
	speed: number,
	captureTime: number?, -- timestamp when captured
	coins: number, -- total coins earned, used for leaderboard
}

return nil
