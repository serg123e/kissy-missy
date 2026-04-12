-- Game configuration constants
local GameConfig = {
	-- Player settings
	BASE_PLAYER_SPEED = 16, -- default Roblox walk speed
	MAX_PLAYER_SPEED = 24, -- max speed after treadmill training
	SPEED_PER_TREADMILL_TICK = 0.5, -- speed gained per training interval
	TREADMILL_TICK_SECONDS = 3, -- how often treadmill grants speed

	-- Kissy Missy settings
	KISSY_SPEED = 28, -- faster than max player speed
	KISSY_CATCH_RADIUS = 5, -- studs to catch a player
	KISSY_SPAWN_DELAY = 10, -- seconds before Kissy leaves the castle

	-- Prison settings
	PRISON_DOOR_OPEN_TIME = 5, -- seconds door stays open after player presses Y
	PRISON_DOOR_INTERACT_KEY = Enum.KeyCode.Y,
	PRISON_DOOR_INTERACT_RADIUS = 15, -- studs from door center to allow interaction
	TELEPORT_Y_OFFSET = 3, -- studs above spawn point to avoid clipping into floor

	-- Game flow
	ROUND_DURATION = 300, -- 5 minutes per round
	ROUND_END_DURATION = 5, -- seconds to show results before next intermission
	MIN_PLAYERS = 2,
	INTERMISSION_DURATION = 15,

	-- Economy
	COINS_SURVIVE_ROUND = 100, -- coins for being free when round ends
	COINS_FREE_PRISONER = 25, -- coins for opening the prison door

	-- Zones
	SAFE_ZONE_DURATION = 15, -- seconds of initial safe zone

	-- Server
	MAX_PLAYERS = 32,

	-- Map
	TREEHOUSE_COUNT = 4, -- few hiding spots, forces movement
}

return GameConfig
