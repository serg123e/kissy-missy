-- Minimal test runner. No framework; collects describe/it blocks and reports pass/fail.
local runner = {}

local state = {
	currentGroup = nil :: string?,
	tests = {} :: { { name: string, fn: () -> () } },
}

function runner.describe(name: string, fn: () -> ())
	local parent = state.currentGroup
	state.currentGroup = if parent then parent .. " > " .. name else name
	fn()
	state.currentGroup = parent
end

function runner.it(name: string, fn: () -> ())
	local fullName = if state.currentGroup then state.currentGroup .. " > " .. name else name
	table.insert(state.tests, { name = fullName, fn = fn })
end

local function formatValue(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function runner.assertEqual(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		local prefix = if msg then msg .. ": " else ""
		error(string.format("%sexpected %s, got %s", prefix, formatValue(expected), formatValue(actual)), 2)
	end
end

function runner.assertTrue(value: any, msg: string?)
	if not value then
		error((msg or "assertTrue failed") .. " (got " .. formatValue(value) .. ")", 2)
	end
end

function runner.assertFalse(value: any, msg: string?)
	if value then
		error((msg or "assertFalse failed") .. " (got " .. formatValue(value) .. ")", 2)
	end
end

function runner.assertNil(value: any, msg: string?)
	if value ~= nil then
		error((msg or "assertNil failed") .. " (got " .. formatValue(value) .. ")", 2)
	end
end

function runner.run(): boolean
	local passed = 0
	local failed = 0
	local failures: { { name: string, err: string } } = {}

	for _, t in state.tests do
		local ok, err = pcall(t.fn)
		if ok then
			passed += 1
			print("  PASS  " .. t.name)
		else
			failed += 1
			table.insert(failures, { name = t.name, err = tostring(err) })
			print("  FAIL  " .. t.name)
		end
	end

	print(string.format("\n%d tests, %d passed, %d failed", #state.tests, passed, failed))

	if #failures > 0 then
		print("\nFailures:")
		for _, f in failures do
			print(string.format("  %s\n    %s", f.name, f.err))
		end
	end

	return failed == 0
end

return runner
