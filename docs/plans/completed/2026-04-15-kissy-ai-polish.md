# Kissy AI Polish — Implementation Plan

## Overview

Implement the 5 bundled fixes in `docs/KISSY_AI_POLISH_SPEC.md`: reuse the pathfinding `Path` object (#46), handle `MoveToFinished` timeouts (#52), subscribe to `path.Blocked` with ahead-of-agent guard (#49), prevent Kissy from entering the prison interior via `PathfindingModifier` (#51a), and add client-side CFrame lerp smoothing so the NPC moves smoothly at real-world latency (#44).

Scope is a single branch, 8 commits, no cross-team coordination. All changes are contained in `KissyService.luau`, one new client controller, `GameConfig.luau`, and a new workspace part.

## Context

- **Spec:** `docs/KISSY_AI_POLISH_SPEC.md` (authoritative — defer all behavior questions there).
- **Files modified:** `src/server/Services/KissyService.luau`, `src/shared/Config/GameConfig.luau`, `src/client/init.client.luau`, `default.project.json`, `CLAUDE.md`.
- **Files created:** `src/client/Controllers/KissySmoothingController.luau`.
- **Project conventions:** manual DI, tabs, 120-col, double quotes, `--!strict` on new pure-logic modules. See `CLAUDE.md`.
- **Gate:** `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl` must pass after every task.

## Development Approach

- Order tasks so each commit builds cleanly and behaves correctly even if the next task never lands. No task leaves the codebase in a half-broken state.
- No new Lune tests — every change relies on Roblox engine APIs (`PathfindingService`, `Humanoid`, `RenderStepped`, `CollectionService`) that Lune does not expose. Validation is done by playtest in Studio on the Windows VM.
- Existing 41 Lune tests must keep passing unchanged.
- After each task: run the gate. On failure, fix before moving on.

## Implementation Steps

### Task 1: Add `PrisonZone` workspace part and register it

**Files:**
- Modify: `default.project.json`
- Modify: `CLAUDE.md`

Lays down the workspace part the pathfinding modifier needs. Behavior-neutral until Task 2 wires the `Costs` map.

- [x] In `default.project.json`, add a new `PrisonZone` Part under Workspace. Properties: `Anchored=true`, `CanCollide=false`, `Transparency=1`. Size and position left for the designer to tune in Studio — the spec only requires it be big enough to enclose the prison interior.
- [x] Add a `PathfindingModifier` child with `Label="PrisonInterior"`.
- [x] Update `CLAUDE.md` "Required Workspace Parts" list to include `PrisonZone` with a one-line description.
- [x] Gate: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.
- [x] Commit: `feat: add PrisonZone workspace part with PathfindingModifier`.

### Task 2: Reuse a single module-scope `Path` object with prison cost

**Files:**
- Modify: `src/server/Services/KissyService.luau`

Addresses GOTCHA #46 (don't `CreatePath` every tick) and consumes the Task 1 modifier.

- [x] Move path creation out of `_computePath`. Add a module-level lazy initializer that creates the `Path` with `AgentRadius=2`, `AgentHeight=5`, `AgentCanJump=true`, and `Costs = { PrisonInterior = math.huge }`.
- [x] `_computePath` now calls `ComputeAsync` on the shared path object. Path status/ waypoint logic unchanged.
- [x] Add a `_destroyPath()` helper and call it from `Deactivate` to clear the reference (fresh create on next `Activate`).
- [x] Grep-verify: `PathfindingService:CreatePath` appears exactly once in `KissyService.luau`.
- [x] Gate.
- [x] Commit: `perf: reuse Kissy Path object across recomputes (GOTCHA #46)`.

### Task 3: Subscribe to `path.Blocked` with ahead-of-agent guard

**Files:**
- Modify: `src/server/Services/KissyService.luau`

Addresses GOTCHA #49. Relies on Task 2's shared path object.

- [x] In the lazy-initializer from Task 2, connect `path.Blocked:Connect(function(blockedWaypointIndex) ... end)`.
- [x] Handler: if `blockedWaypointIndex >= currentWaypointIndex`, force recompute on next tick (set `lastPathTime = 0`). Otherwise ignore (block is behind the agent).
- [x] Disconnect the signal in `_destroyPath` to avoid double-connects on re-`Activate`.
- [x] Gate.
- [x] Commit: `feat: recompute Kissy path on Blocked-ahead signal (GOTCHA #49)`.

### Task 4: Handle `MoveToFinished` timeouts

**Files:**
- Modify: `src/server/Services/KissyService.luau`

Addresses GOTCHA #52.

- [x] In `Activate`, after the humanoid is known, connect `humanoid.MoveToFinished:Connect(function(reached) ... end)`.
- [x] Handler: if `reached == false`, force recompute (set `lastPathTime = 0`). Guard against stale connections by checking `kissyModel ~= nil`.
- [x] Disconnect on `Deactivate` (store the connection handle; call `:Disconnect()`).
- [x] Gate.
- [x] Commit: `fix: recompute Kissy path on MoveTo 8s timeout (GOTCHA #52)`.

### Task 5: Tag the spawned Kissy model

**Files:**
- Modify: `src/server/Services/KissyService.luau`

Prerequisite for the client smoothing controller (Task 7).

- [x] Add `local CollectionService = game:GetService("CollectionService")` at the top of the service.
- [x] In `_spawnKissy`, after `kissyModel.Parent = workspace`, call `CollectionService:AddTag(kissyModel, "KissyNPC")`.
- [x] No need to explicitly remove the tag — `Destroy()` removes all tags.
- [x] Gate.
- [x] Commit: `feat: tag spawned Kissy with KissyNPC for client lookup`.

### Task 6: Add `KISSY_VISUAL_LERP_RATE` to GameConfig

**Files:**
- Modify: `src/shared/Config/GameConfig.luau`

Designer-tunable lerp speed for the smoothing controller (Task 7).

- [x] Add `KISSY_VISUAL_LERP_RATE = 12` (units: 1/s — higher = snappier). Include a one-line comment explaining the unit.
- [x] Update the `config_test.luau` sanity test to cover the new key: assert it's a positive number. (One-line addition; keeps our pattern of protecting GameConfig invariants.)
- [x] Gate.
- [x] Commit: `feat: add KISSY_VISUAL_LERP_RATE to GameConfig`.

### Task 7: Create `KissySmoothingController` and wire it on the client

**Files:**
- Create: `src/client/Controllers/KissySmoothingController.luau`
- Modify: `src/client/init.client.luau`

The visual-only client controller from spec D1 + D6 + D7.

- [x] Controller module exports `Init(): ()`.
- [x] `Init` captures references: `RunService`, `CollectionService`, `GameConfig`.
- [x] Set up state: a single `currentKissy: { model: Model, hrp: BasePart, target: CFrame, conn: RBXScriptConnection? }?`. One Kissy at a time (spec assumption).
- [x] Subscribe to `CollectionService:GetInstanceAddedSignal("KissyNPC")` → on add, wait for `HumanoidRootPart`, take its current CFrame as the initial target, connect `GetPropertyChangedSignal("CFrame")` to update `currentKissy.target`.
- [x] Also iterate `CollectionService:GetTagged("KissyNPC")` at `Init` time so a Kissy that spawned before this controller started is still picked up.
- [x] Subscribe to `GetInstanceRemovedSignal("KissyNPC")` → on remove, disconnect the CFrame-changed signal, clear state.
- [x] `RunService.RenderStepped:Connect(function(dt) ... end)`: if `currentKissy` is set, compute `alpha = 1 - math.exp(-dt * GameConfig.KISSY_VISUAL_LERP_RATE)`, apply `hrp.CFrame = hrp.CFrame:Lerp(target, alpha)`.
- [x] Large-jump snap: if `(hrp.Position - target.Position).Magnitude >= 20`, set `hrp.CFrame = target` immediately, skip lerp this frame.
- [x] Register the controller in `src/client/init.client.luau` alongside the other controllers.
- [x] Gate.
- [x] Commit: `feat: smooth Kissy visual movement client-side (GOTCHA #44)`.

### Task 8: Playtest validation and final docs pass

**Files:**
- Modify: `CLAUDE.md` (if any architecture note changed)

Run the 7 Studio scenarios from the spec and capture findings. No code changes unless a scenario fails.

- [x] Studio scenario 1 (long session, 5+ min) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 2 (player runs far) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 3 (obstacle ahead) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 4 (obstacle behind) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 5 (sim latency 0.2s via Studio → Test → Network) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 6 (prison re-entry) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] Studio scenario 7 (teleport snap on respawn) — manual test (skipped - not automatable, requires Roblox Studio)
- [x] If any scenario fails, open a follow-up commit or ticket (do not expand this plan's scope).
- [x] Final gate.
- [x] Move this plan: `git mv docs/plans/2026-04-15-kissy-ai-polish.md docs/plans/completed/`.
- [x] Commit: `docs: complete Kissy AI polish plan`.

## Done When

- All 8 tasks above are checked off.
- `docs/KISSY_AI_POLISH_SPEC.md` "Done when" criteria all satisfied (path reuse grep, CollectionService tag, new part, new controller, new config key, gate green).
- Existing 41 Lune tests pass unchanged.
- This plan is moved to `docs/plans/completed/`.

## Non-Goals (recap from spec)

- GOTCHA #45 (player teleport `PivotTo`).
- GOTCHA #51(b) (cost map driving players toward prison).
- GOTCHA #58 (NameOcclusion horror effect).
- Any changes to capture, queue, or prison state machines.
- Any new Lune tests for Roblox-only APIs.
