local runner = require("./lib/runner")
local TimeFormat = require("../src/shared/Logic/TimeFormat")

local describe = runner.describe
local it = runner.it
local assertEqual = runner.assertEqual

describe("TimeFormat", function()
	it("formats 0 as 0:00", function()
		assertEqual(TimeFormat.format(0), "0:00")
	end)

	it("formats 5 as 0:05", function()
		assertEqual(TimeFormat.format(5), "0:05")
	end)

	it("formats 60 as 1:00", function()
		assertEqual(TimeFormat.format(60), "1:00")
	end)

	it("formats 125 as 2:05", function()
		assertEqual(TimeFormat.format(125), "2:05")
	end)

	it("clamps negative to 0:00", function()
		assertEqual(TimeFormat.format(-1), "0:00")
	end)

	it("truncates fractional seconds", function()
		assertEqual(TimeFormat.format(65.7), "1:05")
	end)

	it("formats round duration (300) as 5:00", function()
		assertEqual(TimeFormat.format(300), "5:00")
	end)
end)
