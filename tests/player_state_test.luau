local runner = require("./lib/runner")
local PlayerStateLogic = require("../src/shared/Logic/PlayerStateLogic")

local describe = runner.describe
local it = runner.it
local assertTrue = runner.assertTrue
local assertFalse = runner.assertFalse
local assertEqual = runner.assertEqual

describe("PlayerStateLogic", function()
	describe("canCapture", function()
		it("returns true for Alive", function()
			assertTrue(PlayerStateLogic.canCapture({ state = "Alive" }))
		end)

		it("returns false for Captured", function()
			assertFalse(PlayerStateLogic.canCapture({ state = "Captured" }))
		end)

		it("returns false for nil data", function()
			assertFalse(PlayerStateLogic.canCapture(nil))
		end)
	end)

	describe("canFree", function()
		it("returns true for Captured", function()
			assertTrue(PlayerStateLogic.canFree({ state = "Captured" }))
		end)

		it("returns false for Alive", function()
			assertFalse(PlayerStateLogic.canFree({ state = "Alive" }))
		end)
	end)

	describe("countAlive", function()
		it("counts only Alive in mixed states", function()
			local map = {
				a = { state = "Alive" },
				b = { state = "Captured" },
				c = { state = "Alive" },
				d = { state = "Captured" },
			}
			assertEqual(PlayerStateLogic.countAlive(map), 2)
		end)
	end)

	describe("double-capture guard", function()
		it("rejects second capture after state becomes Captured", function()
			local data = { state = "Alive" }
			assertTrue(PlayerStateLogic.canCapture(data), "first capture should be allowed")
			data.state = "Captured"
			assertFalse(PlayerStateLogic.canCapture(data), "second capture should be rejected")
		end)
	end)
end)
