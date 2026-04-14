# Kissy AI Polish Spec

## Summary

Bundle of five targeted fixes to the Kissy Missy NPC AI, driven by a pass through `../GOTCHAS.md` (Roblox-docs findings). Two are performance/correctness bugs in pathfinding, one is a visual smoothness gap, two are AI responsiveness improvements. All scope is contained to `KissyService` + one new client controller + one new workspace part.

## Goal

- NPC pathfinding is efficient and responsive (no wasted CPU, no silent stalls, reacts to dynamic obstacles).
- NPC movement looks smooth on real-world latency (100–300 ms ping), not just in LAN Studio tests.
- NPC does not wander into the prison interior and re-catch just-freed players.

## Why now

GOTCHAS review surfaced concrete Roblox-engine rules that our current code violates. Each item is small, but two (`#46`, `#52`) are **latent production bugs** that only manifest under specific conditions (long play sessions, player running far away). Fix them before the kid designer playtests with external friends on real internet.

## Context

- `src/server/Services/KissyService.luau` owns all NPC behavior today — spawn, hunt loop, pathfinding, capture check.
- The existing hunt loop: `task.spawn` → every 0.5s `_huntTick` → every 1s recompute full path.
- The prison area consists of `PrisonSpawn`, `PrisonExit`, `PrisonDoor` parts declared in `default.project.json`. There is **no dedicated "prison interior" volume part today**.
- Project conventions (indentation, formatting, init order, service wiring) are in `CLAUDE.md` — follow without restating.
- GOTCHAS items addressed: `#44`, `#46`, `#49`, `#51` (variant a only), `#52`. All five are listed in `../GOTCHAS.md`.

## Scope

In scope (all five ship together, one branch, may be multiple commits):
1. **GOTCHA #46** — single module-scope `Path` object reused across recomputes instead of `CreatePath` every tick.
2. **GOTCHA #52** — `humanoid.MoveToFinished` handler; `reached=false` triggers immediate recompute instead of silent stall.
3. **GOTCHA #49** — subscribe to `path.Blocked`; recompute only if blocked waypoint is ahead of current index.
4. **GOTCHA #51(a)** — new invisible `Part` enclosing the prison interior, with `PathfindingModifier` child labelled so Kissy path cost inside is `math.huge` (impassable).
5. **GOTCHA #44** — new client controller `src/client/Controllers/KissySmoothingController.luau` that applies RenderStepped CFrame lerp between replication updates. Approach **A** (chosen — see Decisions).

Out of scope:
- GOTCHA #45 (`PivotTo` for player teleport) — deferred until an accessories-lag regression is observed.
- GOTCHA #51(b) (driving players toward prison via cost map) — design-level change, must be reviewed with the game designer separately.
- GOTCHA #58 (`NameOcclusion` horror effect) — product direction; current `DisplayDistanceType=None` stays.
- Performance optimizations unrelated to pathfinding (hunt tick rate, capture radius check).
- Changes to capture/prison/queue state machines.

## Facts

- `KissyService:_computePath` currently calls `PathfindingService:CreatePath({...})` every recompute. The `Path` object holds a `.Blocked` signal that the current code never connects to.
- `KissyService:_followPath` issues `humanoid:MoveTo(waypoint.Position)` without listening for `MoveToFinished`.
- Kissy's `HumanoidRootPart` is pinned to the server via `SetNetworkOwner(nil)` (committed earlier this branch in `f0c9e2b`). Server-owned parts replicate at ~20 Hz → visible jitter on real-world ping.
- The codebase enforces server authority for all gameplay decisions. The new client controller is **visual-only**: it MUST NOT influence capture radius math, Kissy position on the server, or any gameplay state.
- `src/shared/Logic/*.luau` modules are `--!strict`. New Logic extracted for this spec should follow that convention.

## Assumptions

- Kissy will always be a single Model (there is no plan for multiple hunters in this phase).
- The prison interior is a simple convex volume that can be bounded by one axis-aligned `Part`.
- The kid designer edits `default.project.json` and can add a new Part via Studio or JSON.

## Constraints

- **Server authority preserved.** The client smoothing controller reads `HumanoidRootPart.CFrame` (server-driven) and lerps a **visual** offset. It does not write CFrame on the server side, does not influence raycasts, does not predict future position beyond simple interpolation.
- **No new dependencies.** Stay within stdlib, Rojo, existing Wally packages.
- **Existing tests stay green.** The 41-test Lune suite must pass unchanged.
- **Gate unchanged.** `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.

## Decisions

- **D1.** Client interpolation uses **RenderStepped CFrame lerp** (option A from the interview). The controller tracks Kissy's last known server-replicated `CFrame`, and each frame moves the visual `HumanoidRootPart.CFrame` a fraction of the way toward it (frame-rate-independent via `1 - math.exp(-dt * rate)` or equivalent). No server-side changes, no extra RemoteEvents.
- **D2.** Path object reused: one `local path = PathfindingService:CreatePath({...})` at module scope (lazy-initialized on first hunt). The same object is passed to `ComputeAsync` each recompute. Agent params become fixed at module load time.
- **D3.** `path.Blocked:Connect(...)` subscribed once (when the path object is created). Handler guards with `if blockedWaypointIndex >= currentWaypointIndex then recompute()`.
- **D4.** `MoveToFinished` handler lives alongside the hunt loop, not inline in `_followPath`. If `reached=false`, force recompute on next tick by setting `lastPathTime = 0`.
- **D5.** Prison pathfinding volume: **new invisible `Part` named `PrisonZone`** added to `default.project.json`, enclosing the prison interior (`CanCollide=false`, `Transparency=1`, `Anchored=true`). A `PathfindingModifier` child has `Label="PrisonInterior"`. `KissyService` creates the `Path` with `Costs = { PrisonInterior = math.huge }`.
- **D6.** Smoothing controller snaps (no lerp) when the server-replicated CFrame jumps more than a **threshold distance** (≥ 20 studs) — this avoids visible "wipe" across the map on respawn/teleport.
- **D7.** Client locates the Kissy Model via a `CollectionService` tag `"KissyNPC"` applied by the server at spawn. The client subscribes with `CollectionService:GetInstanceAddedSignal("KissyNPC")` / `GetInstanceRemovedSignal`. Name-based lookup (`workspace.KissyMissy`) is not used — the tag makes future renaming, multiple NPCs, or boss-variants trivial without a second client rewrite.

## Approach

1. Server-side (`KissyService.luau`):
   - Move `PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true, Costs={PrisonInterior=math.huge}})` to module scope (lazy init).
   - Connect `path.Blocked` once with the ahead-of-agent guard.
   - In `_computePath`, call `ComputeAsync` on the reused object.
   - In `_followPath`, wire `humanoid.MoveToFinished:Connect(...)` with recompute-on-timeout logic. Disconnect on despawn.
   - In `_spawnKissy`, after `kissyModel.Parent = workspace`, call `CollectionService:AddTag(kissyModel, "KissyNPC")`.
2. Workspace (`default.project.json`):
   - Add `PrisonZone` Part (position + size to be set by designer in Studio; spec only defines its role).
   - Add a `PathfindingModifier` child with `Label="PrisonInterior"`.
   - Update `CLAUDE.md` required-parts list.
3. Client-side (new `src/client/Controllers/KissySmoothingController.luau`):
   - Subscribe to `CollectionService:GetInstanceAddedSignal("KissyNPC")` and `GetInstanceRemovedSignal("KissyNPC")`. Also iterate `GetTagged("KissyNPC")` at startup in case the Kissy was spawned before the local player joined.
   - On new Kissy: record "target" CFrame via `HumanoidRootPart:GetPropertyChangedSignal("CFrame")`; render visual via `RenderStepped` lerp. Disable the humanoid's default position smoothing by writing a new CFrame each frame derived from the target.
   - On large jumps (≥ 20 studs): snap immediately.
   - On removal: disconnect RenderStepped and clear state.
   - Register in `src/client/init.client.luau`.
4. Tests: no new Lune tests — all changes rely on Roblox engine APIs (`PathfindingService`, `Humanoid`, `RenderStepped`) that Lune does not expose. Validate in Studio.

## Risks

- **Client smoothing hiding server truth during capture.** If a player is caught right at the moment of lerp, the visual Kissy may *look* further away than the server thinks. → Mitigation: catches are distance-checked server-side against `HumanoidRootPart.Position` (already the case). Visual lag is cosmetic only.
- **PrisonZone misaligned.** If the designer draws the zone too small, Kissy still wanders in; too large, Kissy can't approach the door to guard it. → Mitigation: designer places the zone in Studio and tunes it; zone is edit-time, not code.
- **`Path` object reuse in a concurrent context.** If two `ComputeAsync` calls overlap, Roblox's behavior with a shared Path is undefined. → Mitigation: the hunt loop is single-threaded (one `task.spawn` serial loop); calls never overlap.
- **Lerp rate feels wrong** (too sluggish vs jittery). → Mitigation: expose rate as `GameConfig.KISSY_VISUAL_LERP_RATE` so the designer can tune without code changes.

## Done when

- `KissyService` calls `PathfindingService:CreatePath` exactly once per service lifetime (grep-verifiable).
- `MoveToFinished` handler exists and triggers a recompute when `reached=false`.
- `path.Blocked` is connected and triggers a recompute only for ahead-of-agent blocks.
- `default.project.json` contains a `PrisonZone` Part with a `PathfindingModifier` child labelled `PrisonInterior`, and `CLAUDE.md` lists it under required workspace parts.
- `src/client/Controllers/KissySmoothingController.luau` exists, is wired in `init.client.luau`, locates Kissy via `CollectionService` tag `"KissyNPC"`, and lerps Kissy's visual CFrame on RenderStepped (with large-jump snap).
- `KissyService:_spawnKissy` tags the model with `"KissyNPC"` via `CollectionService:AddTag`.
- `GameConfig.KISSY_VISUAL_LERP_RATE` exists and is consumed by the controller.
- Full gate passes: `stylua src/ tests/ && selene src/ && lune run tests/run.luau && rojo build -o /tmp/test.rbxl`.
- Existing 41 Lune tests still pass unchanged.

## Validation

Manual Studio playtest (on the Windows VM) with these scenarios:
1. **Long session** — leave Kissy hunting for 5+ minutes; no frame hitches or memory growth (CPU profile flat, no `CreatePath` allocations visible in stats).
2. **Player runs far** — player sprints a long distance; Kissy recovers within one recompute interval (≤ 1.5s) when `MoveTo` would have silently timed out.
3. **Obstacle drops ahead** — move an obstacle into Kissy's path while she chases; she recomputes quickly, doesn't hammer into it for a second.
4. **Obstacle drops behind** — same but behind her; she keeps moving without pointless recompute (observable via added temporary log at the `path.Blocked` handler).
5. **Simulated latency** — Studio → Test → Network → Incoming Replication Lag = 0.2s. Kissy moves smoothly, no visible teleporting between network ticks.
6. **Prison re-entry** — free a captured player at the door; Kissy walks up to the door but does not enter the prison interior.
7. **Teleport snap** — force Kissy respawn at round start; visual model does not "wipe" across the map (snap, not lerp).

