local runner = require("./lib/runner")

require("./lib/roblox_stub")
local GameConfig = require("../src/shared/Config/GameConfig")
local RemoteEvents = require("../src/shared/Config/RemoteEvents")

local describe = runner.describe
local it = runner.it
local assertTrue = runner.assertTrue
local assertEqual = runner.assertEqual

describe("GameConfig", function()
	describe("speed invariants", function()
		it("MAX_PLAYER_SPEED > BASE_PLAYER_SPEED", function()
			assertTrue(GameConfig.MAX_PLAYER_SPEED > GameConfig.BASE_PLAYER_SPEED, "max speed must exceed base speed")
		end)

		it("KISSY_SPEED > MAX_PLAYER_SPEED", function()
			assertTrue(GameConfig.KISSY_SPEED > GameConfig.MAX_PLAYER_SPEED, "Kissy must outrun maxed players")
		end)
	end)

	describe("radius invariants", function()
		it("KISSY_CATCH_RADIUS < PRISON_DOOR_INTERACT_RADIUS", function()
			assertTrue(
				GameConfig.KISSY_CATCH_RADIUS < GameConfig.PRISON_DOOR_INTERACT_RADIUS,
				"door interact area must be bigger than catch radius"
			)
		end)
	end)

	describe("queue bounds", function()
		it("MAX_QUEUE_LENGTH >= 1", function()
			assertTrue(GameConfig.MAX_QUEUE_LENGTH >= 1, "queue must allow at least 1")
		end)

		it("AFK_KICK_TIMEOUT > 0", function()
			assertTrue(GameConfig.AFK_KICK_TIMEOUT > 0, "AFK timeout must be positive")
		end)

		it("QUEUE_JOIN_RADIUS > 0", function()
			assertTrue(GameConfig.QUEUE_JOIN_RADIUS > 0, "join radius must be positive")
		end)
	end)

	describe("RemoteEvents", function()
		it("all values are strings", function()
			for key, value in RemoteEvents do
				assertEqual(type(value), "string", "RemoteEvents." .. tostring(key) .. " must be a string")
			end
		end)

		it("no duplicate values", function()
			local seen: { [string]: string } = {}
			for key, value in RemoteEvents do
				local existing = seen[value]
				assertTrue(
					existing == nil,
					"duplicate RemoteEvent name '"
						.. value
						.. "' used by both '"
						.. tostring(existing)
						.. "' and '"
						.. tostring(key)
						.. "'"
				)
				seen[value] = tostring(key)
			end
		end)
	end)
end)
