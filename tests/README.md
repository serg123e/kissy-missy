# Tests

Lune-based unit tests for pure logic. Not a replacement for playtesting in Studio.

## Running

```sh
lune run tests/run.luau
```

Exits non-zero on any failure.

## Scope

**In scope:** pure logic that takes plain tables/primitives and returns values — queue state machine, player state guards, coin eligibility, time formatting, config invariants. These live (or will live) under `src/shared/Logic/`.

**Out of scope:** anything that touches `game`, `workspace`, `Instance.new`, `RemoteEvent`, `Humanoid`, `CFrame`, pathfinding, UI rendering, `CharacterAdded`. These require the Roblox engine and are verified manually in Studio.

## Layout

```
tests/
  run.luau              entrypoint — requires each test file
  lib/runner.luau       describe / it / assertEqual / assertTrue / assertFalse / assertNil
  runner_self_test.luau sanity check that the runner itself works
  <topic>_test.luau     one file per logic module under test
```

## Writing a test

```lua
local runner = require("./lib/runner")
local Subject = require("../src/shared/Logic/Subject")

runner.describe("Subject.method", function()
	runner.it("does the thing", function()
		runner.assertEqual(Subject.method(1), 2)
	end)
end)
```

Then add `require("./<name>_test")` to `run.luau`.

## Why no framework

At this scale, a 70-line runner is clearer than pulling in a dependency. If the suite grows past ~20 files or we need fixtures / parallelism, consider [TestEZ](https://github.com/Roblox/testez) (Roblox-side) or [Jestronaut](https://github.com/Jestronaut/jestronaut) (Lune-side).

## Selene

`selene.toml` uses `std = "roblox"`, which doesn't recognize Lune's `@lune/*` imports. Selene is run only on `src/`, not `tests/`. StyLua formats both.
