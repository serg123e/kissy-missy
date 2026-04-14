local runner = require("./lib/runner")
local EligibilityLogic = require("../src/shared/Logic/EligibilityLogic")

local describe = runner.describe
local it = runner.it
local assertEqual = runner.assertEqual
local assertTrue = runner.assertTrue
local assertFalse = runner.assertFalse

describe("EligibilityLogic.isEligibleForSurvivalReward", function()
	it("alive + joinedRound matches → eligible", function()
		local data = { state = "Alive", joinedRound = 3 }
		assertTrue(EligibilityLogic.isEligibleForSurvivalReward(data, 3))
	end)

	it("alive + joinedRound < currentRound (mid-round joiner) → NOT eligible", function()
		local data = { state = "Alive", joinedRound = 2 }
		assertFalse(EligibilityLogic.isEligibleForSurvivalReward(data, 3))
	end)

	it("captured + joinedRound matches → NOT eligible", function()
		local data = { state = "Captured", joinedRound = 3 }
		assertFalse(EligibilityLogic.isEligibleForSurvivalReward(data, 3))
	end)
end)

describe("EligibilityLogic.snapshotEligible", function()
	it("updates all entries to given round without changing state", function()
		local map = {
			a = { state = "Alive", joinedRound = 0 },
			b = { state = "Captured", joinedRound = 1 },
			c = { state = "Alive", joinedRound = 2 },
		}
		EligibilityLogic.snapshotEligible(map, 5)
		assertEqual(map.a.joinedRound, 5)
		assertEqual(map.b.joinedRound, 5)
		assertEqual(map.c.joinedRound, 5)
		assertEqual(map.a.state, "Alive")
		assertEqual(map.b.state, "Captured")
		assertEqual(map.c.state, "Alive")
	end)

	it("empty map → no-op, no crash", function()
		local map = {}
		EligibilityLogic.snapshotEligible(map, 1)
	end)
end)
