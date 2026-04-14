# Add Automated Tests (Lune-based)

## Overview

Add a minimal automated test suite using Lune (already in `rokit.toml`) to cover the highest-risk pure logic in the codebase: treadmill queue FIFO state machine, player state guards, coin eligibility snapshot, and HUD formatters. No test framework — a single hand-rolled runner (~50 lines) is enough at this scale.

The goal is **regression protection for logic bugs that are easy to introduce and hard to catch in manual playtests** (queue off-by-one, double-capture, stale `joinedRound`, timer formatting).

**Out of scope:** pathfinding, CFrame/teleport math, RemoteEvent wiring, UI rendering, `CharacterAdded` timing — these need the Roblox engine and are verified manually in Studio.

## Context

- Runtime: Lune 0.10.4 (standalone Luau). Run via `lune run tests/run.luau`.
- No test framework installed. Hand-rolled runner at `tests/lib/runner.luau` exports `describe`, `it`, `assertEqual`, `assertTrue`, `assertFalse`, `assertNil`.
- Most services mix pure logic with Roblox side effects (`workspace:FindFirstChild`, `Instance.new`, `task.spawn`). Direct testing requires either mocking Roblox globals or extracting pure helpers.
- **Strategy: extract pure logic into small modules under `src/shared/Logic/`** and test those. Do not try to mock `game`/`workspace`/`Humanoid`.
- Selene is run on `src/` only — `std="roblox"` doesn't recognize Lune's `@lune/*` imports. Revisit if `tests/` grows past ~15 files or ~1000 LoC; at that point consider a minimal Lune-tailored selene std (whitelist only the `@lune/*` symbols actually used).
- Specs referenced: `docs/GAME_DESIGN.md`, `docs/CLOUD_QUEUE_SPEC.md`.

## Development Approach

- One test runner, no framework.
- Extract-and-test, don't mock-and-test. Side effects stay in service modules; state transitions move into pure modules.
- Each task = one commit. The gate for every task: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.
- Lune tests must **not** `require` anything from `src/server/` or `src/client/` (those pull Roblox services at module load). They may require from `src/shared/` **only if** those modules don't touch `game`/`workspace`/`Instance`.
- Pattern for loading a `src/shared/Logic/*.luau` module from a test: use Lune's filesystem-relative require, e.g. `require("../src/shared/Logic/QueueLogic")`.

## Implementation Steps

### Task 1: Test runner scaffolding

**Files:**
- Create: `tests/run.luau`
- Create: `tests/lib/runner.luau`
- Create: `tests/runner_self_test.luau`
- Create: `tests/README.md`

- [x] `tests/lib/runner.luau` exports `describe(name, fn)`, `it(name, fn)`, `assertEqual(a, b, msg?)`, `assertTrue(v, msg?)`, `assertFalse(v, msg?)`, `assertNil(v, msg?)`, `run()` — collects failures, prints summary, returns bool.
- [x] `tests/run.luau` requires each test file and calls `runner.run()`; exits 1 on failure via `@lune/process`.
- [x] Added `tests/runner_self_test.luau` with 4 assertions to keep the runner itself honest.
- [x] `tests/README.md` documents scope, layout, how to run, and why selene is not run on `tests/`.
- [x] `selene src/ tests/` not used — selene `std="roblox"` doesn't recognize Lune's `@lune/*` imports. Gate runs `selene src/` only. Revisit when tests/ grows past ~15 files; consider a Lune-tailored selene std at that point.
- [x] StyLua formats both `src/` and `tests/` (no config change needed — `.stylua.toml` applies to any path passed in).
- [x] `lune run tests/run.luau` → `4 tests, 4 passed, 0 failed`, exit 0.
- [x] Full gate passes: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 2: Extract queue logic into pure module + tests

**Files:**
- Create: `src/shared/Logic/QueueLogic.luau`
- Create: `tests/queue_logic_test.luau`
- Modify: `src/server/Services/TreadmillService.luau`

- [x] `QueueLogic.luau` exports pure functions operating on a plain state table `{ activeUser, queue: {Player} }`:
  - `tryAssign(state, player, maxQueueLength) -> ("active" | "queued" | "rejected", positionOrNil)`
  - `remove(state, player) -> ("wasActive" | "wasQueued" | "notPresent", promotedPlayerOrNil)` — if active left, promotes `queue[1]`; if queued, shifts.
  - `positionOf(state, player) -> number?` (1 = active, 2+ = queue index + 1)
- [x] No Roblox types — `Player` is just an opaque table identity.
- [x] Refactor `TreadmillService.OnQueueJoin` / `OnQueueLeave` / `_advanceQueue` / `_removeFromQueue` to call `QueueLogic` for state transitions; services still own side effects (remote fires, movement lock, CFrames).
- [x] Tests (`tests/queue_logic_test.luau`):
  - empty state + assign → "active", position 1
  - assign when active exists → "queued", position 2
  - assign when `#queue == maxQueueLength` → "rejected"
  - remove active with non-empty queue → "wasActive", promoted = old queue[1], new queue length = old - 1
  - remove active with empty queue → "wasActive", promoted = nil, active = nil
  - remove queued middle element → "wasQueued", shifts trailing indices down
  - remove player not present → "notPresent"
  - FIFO ordering preserved across join/leave/promote cycle
- [x] Run full gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 3: Extract coin eligibility logic + tests

**Files:**
- Create: `src/shared/Logic/EligibilityLogic.luau`
- Create: `tests/eligibility_test.luau`
- Modify: `src/server/Services/PlayerService.luau`

- [x] `EligibilityLogic.luau` exports:
  - `isEligibleForSurvivalReward(data, currentRound) -> boolean` — returns true iff `data.state == "Alive" and data.joinedRound == currentRound`.
  - `snapshotEligible(playerDataMap, roundNumber)` — mutates each entry to set `joinedRound = roundNumber`.
- [x] `PlayerService:AwardSurvivors` and `PlayerService:SnapshotEligible` delegate to `EligibilityLogic`.
- [x] Tests:
  - player alive + joinedRound matches → eligible
  - player alive + joinedRound < currentRound (mid-round joiner) → NOT eligible
  - player captured + joinedRound matches → NOT eligible
  - `snapshotEligible` updates all entries to given round
  - empty map → no-op, no crash
- [x] Run full gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 4: Extract player state guards + tests

**Files:**
- Create: `src/shared/Logic/PlayerStateLogic.luau`
- Create: `tests/player_state_test.luau`
- Modify: `src/server/Services/PlayerService.luau`

- [x] `PlayerStateLogic.luau` exports:
  - `canCapture(data) -> boolean` — true iff `data.state == "Alive"`.
  - `canFree(data) -> boolean` — true iff `data.state == "Captured"`.
  - `countAlive(map) -> number`
- [x] `PlayerService:CapturePlayer` / `:FreePlayer` use these guards instead of inline checks.
- [x] Tests:
  - canCapture for Alive=true, Captured=false, nil data=false
  - canFree for Captured=true, Alive=false
  - countAlive mixed states counts only Alive
  - double-capture rejected (second call with Captured state returns false)
- [x] Run full gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 5: HUD formatter tests

**Files:**
- Create: `src/shared/Logic/TimeFormat.luau`
- Create: `tests/time_format_test.luau`
- Modify: `src/client/UI/HudController.luau`

- [x] Extract `_formatTime` from `HudController` into `TimeFormat.format(seconds) -> string`.
- [x] `HudController._formatTime` becomes a thin wrapper (or is inlined).
- [x] Tests:
  - `format(0)` → `"0:00"`
  - `format(5)` → `"0:05"`
  - `format(60)` → `"1:00"`
  - `format(125)` → `"2:05"`
  - `format(-1)` → `"0:00"` (or document current behavior)
- [x] `_stateDisplay` is trivial enough to skip unless it grows.
- [x] Run full gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 6: Config integrity tests

**Files:**
- Create: `tests/config_test.luau`
- Create: `tests/lib/roblox_stub.luau` (minimal `Enum.KeyCode` stub)

- [x] `roblox_stub.luau` defines just enough `Enum` for `GameConfig` to load under Lune: `Enum = { KeyCode = setmetatable({}, { __index = function(_, k) return { Name = k } end }) }`. Applied globally before `require("../src/shared/Config/GameConfig")`. Note: `GameConfig.luau` currently uses `Enum.KeyCode.Y` and `Enum.KeyCode.E`; stub must cover both.
- [x] Tests:
  - `MAX_PLAYER_SPEED > BASE_PLAYER_SPEED`
  - `KISSY_SPEED > MAX_PLAYER_SPEED` (Kissy must outrun maxed players)
  - `KISSY_CATCH_RADIUS < PRISON_DOOR_INTERACT_RADIUS` (sanity: door area bigger than catch)
  - `MAX_QUEUE_LENGTH >= 1`, `AFK_KICK_TIMEOUT > 0`, `QUEUE_JOIN_RADIUS > 0`
  - `RemoteEvents` table has no duplicate values (all string names unique)
  - All `RemoteEvents` values are strings
- [x] Run full gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

### Task 7: CI-friendly script and docs

**Files:**
- Create: `scripts/test.sh`
- Modify: `CLAUDE.md`
- Modify: `README.md` (if test section doesn't exist)

- [x] `scripts/test.sh` runs: `stylua --check src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`. Exits on first failure. `set -euo pipefail` at the top.
- [x] `CLAUDE.md` gains a "Testing" section: where tests live, what's in scope (pure logic in `src/shared/Logic/`), what isn't (engine-dependent behavior), how to run, and the selene-on-`src/`-only caveat.
- [x] `README.md` mentions `./scripts/test.sh` as the pre-commit gate.
- [x] Run `./scripts/test.sh` end-to-end, confirm green.

### Task 8: Move plan to completed

- [x] `git mv docs/plans/2026-04-14-automated-tests.md docs/plans/completed/`
- [x] Commit.

## Done When

- `lune run tests/run.luau` passes with at least 20 assertions across 5+ test files (runner self-test already contributes 4).
- `QueueLogic`, `EligibilityLogic`, `PlayerStateLogic`, `TimeFormat` modules exist under `src/shared/Logic/` and are consumed by the services.
- `scripts/test.sh` runs stylua + selene (on `src/`) + lune + rojo build and is documented as the pre-commit gate.
- Services still build and `rojo build` produces a valid place file — no behavior change, only extraction.
- `CLAUDE.md` documents the testing layout, scope boundaries, and the selene-on-`src/`-only caveat.

## Non-Goals

- No test for `KissyService` (pathfinding) — engine-dependent.
- No test for `RemoteService` (creates `Instance.new("RemoteEvent")`) — engine-dependent.
- No test for `PrisonService` door toggle, `RoundService` phase loops (both lean heavily on `task.wait` and workspace parts).
- No mocks for `workspace`, `Players`, `Instance`, `CFrame`, `Vector3`, `Humanoid`.
- No integration tests driving a full round.
- No coverage target — tests are for the specific risky paths listed above, not a percentage.
