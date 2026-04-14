-- Entrypoint for the Lune test suite. Run with: lune run tests/run.luau
local process = require("@lune/process")
local runner = require("./lib/runner")

-- Test files are required here. Each file calls runner.describe/it at module load.
require("./runner_self_test")
require("./queue_logic_test")
require("./eligibility_test")

local ok = runner.run()
if not ok then
	process.exit(1)
end
