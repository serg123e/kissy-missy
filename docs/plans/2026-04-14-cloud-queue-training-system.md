# Implement Cloud/Queue Training System

## Overview

Implement the cloud safe zone with treadmill queue system, Kissy phase-aware AI, eager win check, and coin eligibility snapshot as specified in IMPLEMENTATION_PLAN.md (Phases 0-10). This converts the current proximity-based treadmill training into a FIFO queue system on a cloud platform, with movement locking, AFK detection, and synchronized Safe Zone to Hunt transitions.

## Context

- Files involved: `src/shared/Config/GameConfig.luau`, `src/shared/Config/RemoteEvents.luau`, `src/server/init.server.luau`, `src/server/Services/PlayerService.luau`, `src/server/Services/RoundService.luau`, `src/server/Services/TreadmillService.luau`, `src/server/Services/KissyService.luau`, `src/client/init.client.luau`, `src/client/Controllers/InputController.luau`, `src/client/UI/HudController.luau`, `default.project.json`
- Related patterns: manual dependency injection via Init(), RemoteEvents table auto-creates remotes, task.spawn/task.wait for async loops, proximity-based detection with Magnitude checks
- Dependencies: none external; all work is within existing codebase
- Specs: `docs/GAME_DESIGN.md`, `docs/CLOUD_QUEUE_SPEC.md`, `docs/IMPLEMENTATION_PLAN.md`

## Development Approach

- **Testing approach**: Lint + format + build verification after each task (`stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`)
- Complete each task fully before moving to the next
- Each task = one or two commits following the implementation plan's commit messages
- Manual playtesting in Roblox Studio happens separately on Windows VM
- **CRITICAL: every task MUST pass `selene src/` and `stylua src/` before moving on**
- **CRITICAL: `rojo build -o /tmp/test.rbxl` must succeed before starting next task**

## Implementation Steps

### Task 1: Add queue system constants and remote events

**Files:**
- Modify: `src/shared/Config/GameConfig.luau`
- Modify: `src/shared/Config/RemoteEvents.luau`

- [x] Add constants to GameConfig: `MAX_QUEUE_LENGTH = 10`, `QUEUE_JOIN_KEY = Enum.KeyCode.E`, `AFK_KICK_TIMEOUT = 60`, `QUEUE_JOIN_RADIUS = 8`
- [x] Add remote events to RemoteEvents: `QueueJoin`, `QueueLeave`, `QueueStateChanged`, `MovementLockChanged`
- [x] Verify RemoteService auto-creates new remotes (it iterates the table, should work)
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 2: Add cloud platform geometry to project

**Files:**
- Modify: `default.project.json`

- [x] Add CloudSpawn Part to Workspace in project.json (position at Y=200+)
- [x] Add CloudPlatform Part to Workspace (large enough for 5 treadmills + queues)
- [x] Reposition Treadmills folder entries to cloud elevation (Y=200+)
- [x] Run `rojo build -o /tmp/test.rbxl` to verify project builds

### Task 3: Split PlayerService state reset from teleport

**Files:**
- Modify: `src/server/Services/PlayerService.luau`

- [x] Extract teleport logic from `ResetForRound()` so it only resets state (state=Alive, speed=base, captureTime=nil, joinedRound update, SetSpeed call)
- [x] Add `TeleportAllToCloud()` method -- iterates all players, teleports each to CloudSpawn
- [x] Add `TeleportAllToCastle()` method -- teleports to random SpawnLocations child (current behavior extracted)
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 4: Wire cloud teleport into RoundService phases

**Files:**
- Modify: `src/server/Services/RoundService.luau`

- [x] In `_runSafeZone`: after `ResetForRound()`, call `PlayerService:TeleportAllToCloud()`
- [x] In `_runHunt`: before setting state to Hunt, call `PlayerService:TeleportAllToCastle()`
- [x] Verify round flow order: PrisonService:Reset -> SetRound -> ResetForRound -> TeleportAllToCloud -> KissyService:Activate -> countdown
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 5: Rewrite TreadmillService with occupancy and FIFO queue

**Files:**
- Modify: `src/server/Services/TreadmillService.luau`

- [x] Define TreadmillState type: `{ part, activeUser, queue, activeStartTime, lastInputTime }`
- [x] Rewrite `Init()` to accept playerService and roundService dependencies
- [x] Implement `OnQueueJoin(player, treadmillName)`: find treadmill, validate player is on cloud + within QUEUE_JOIN_RADIUS, assign active or append to queue (reject if full), fire QueueStateChanged
- [x] Implement `OnQueueLeave(player)`: remove from queue, advance queue if needed, fire QueueStateChanged
- [x] Implement `OnPlayerRemoving(player)`: cleanup on disconnect
- [x] Implement queue advancement: when active user leaves, promote queue[1] to active, shift others
- [x] Wire QueueJoin and QueueLeave remote event handlers in `Start()`
- [x] Modify training loop: only grant speed to `activeUser` per treadmill (not proximity-based)
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 6: Client queue join input and queue status UI

**Files:**
- Modify: `src/client/Controllers/InputController.luau`
- Modify: `src/client/UI/HudController.luau`
- Modify: `src/client/init.client.luau`

- [x] InputController: listen for E key (QUEUE_JOIN_KEY), find nearest treadmill within QUEUE_JOIN_RADIUS, fire QueueJoin remote with treadmill name
- [x] HudController: handle QueueStateChanged remote -- display "Active on T1" or "Queue #3 for T2" status label
- [x] HudController: show "Queue full -- try another treadmill" notification (3s) when isRejected=true
- [x] HudController: clear queue status label when player leaves queue (state cleared)
- [x] Wire QueueStateChanged listener in init.client.luau
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 7: Movement lock system and queue positioning

**Files:**
- Modify: `src/server/Services/PlayerService.luau`
- Modify: `src/server/Services/TreadmillService.luau`

- [x] PlayerService: add `LockMovement(player)` -- sets WalkSpeed=0 without overwriting data.speed, fires MovementLockChanged(true)
- [x] PlayerService: add `UnlockMovement(player)` -- restores WalkSpeed=data.speed, fires MovementLockChanged(false)
- [x] PlayerService: modify CharacterAdded handler to check if player is movement-locked and apply WalkSpeed=0
- [x] TreadmillService: on adding player to queue (not active) -> call LockMovement
- [x] TreadmillService: on player transitioning queued->active -> call UnlockMovement
- [x] TreadmillService: on player leaving queue -> call UnlockMovement
- [x] TreadmillService: compute queue positions behind treadmill (3 studs apart along -LookVector), set queued players' CFrames
- [x] TreadmillService: shift remaining players to new positions when queue advances
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 8: AFK kick and Leave Queue button

**Files:**
- Modify: `src/server/Services/TreadmillService.luau`
- Modify: `src/client/UI/HudController.luau`

- [x] TreadmillService: in training loop, poll activeUser's humanoid.MoveDirection.Magnitude; update lastInputTime if > 0
- [x] TreadmillService: if os.clock() - lastInputTime > AFK_KICK_TIMEOUT, evict active user and advance queue
- [x] HudController: when QueueStateChanged shows position >= 2, display "Leave Queue" button
- [x] HudController: on button click, fire QueueLeave remote
- [x] HudController: hide button when position becomes nil or 1
- [x] TreadmillService: handle QueueLeave remote -- remove player, unlock movement, fire QueueStateChanged
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 9: Safe Zone end synchronous queue release

**Files:**
- Modify: `src/server/Services/TreadmillService.luau`
- Modify: `src/server/Services/RoundService.luau`
- Modify: `src/server/init.server.luau`

- [x] TreadmillService: implement `ResetAllQueues()` -- clear all active users, unlock all queued players, fire QueueStateChanged to clear client UI
- [x] RoundService: add TreadmillService dependency (inject via Init or late-inject)
- [x] RoundService: in `_runHunt`, before TeleportAllToCastle, call `TreadmillService:ResetAllQueues()`
- [x] Update init.server.luau wiring to pass TreadmillService to RoundService (or use setter pattern)
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 10: Kissy phase-aware AI behavior

**Files:**
- Modify: `src/server/Services/KissyService.luau`
- Modify: `src/server/init.server.luau`

- [x] Add `SetRoundService(roundService)` method to KissyService for late-inject (avoids circular dep)
- [x] In `_huntTick()`: check `RoundService:GetState()`; if not "Hunt", return early (no chase, no catch)
- [x] Update init.server.luau: after both KissyService and RoundService are inited, call `KissyService:SetRoundService(RoundService)`
- [x] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 11: Eager win check and coin eligibility snapshot

**Files:**
- Modify: `src/server/Services/PlayerService.luau`
- Modify: `src/server/Services/RoundService.luau`

- [ ] PlayerService: in `CapturePlayer`, after capture callback, check if no alive players remain; if so, invoke onAllCapturedCallback
- [ ] PlayerService: add `SetOnAllCaptured(callback)` method
- [ ] RoundService: set PlayerService:SetOnAllCaptured to signal Hunt-phase early termination flag
- [ ] RoundService: in `_runHunt`, check early-termination flag in countdown's shouldStop condition
- [ ] PlayerService: add `SnapshotEligible(roundNumber)` -- sets joinedRound for all connected players
- [ ] PlayerService: remove joinedRound assignment from `ResetForRound` (was making late-joiners look eligible)
- [ ] RoundService: call `SnapshotEligible(roundNumber)` at start of `_runSafeZone`, after `SetRound()`, before `ResetForRound()`
- [ ] Run `stylua src/ && selene src/ && rojo build -o /tmp/test.rbxl`

### Task 12: Verification and documentation update

- [ ] Run `stylua src/` -- fix any formatting issues
- [ ] Run `selene src/` -- fix all warnings
- [ ] Run `rojo build -o /tmp/test.rbxl` -- verify clean build
- [ ] Update CLAUDE.md: add TreadmillService dependency on RoundService to init order, add CloudSpawn/CloudPlatform to required workspace parts, note KissyService late-inject pattern
- [ ] Move implementation plan to `docs/plans/completed/`
