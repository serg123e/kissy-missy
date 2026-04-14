# Implementation Plan — Align Code with Spec

Incremental, ordered plan to bring the codebase in line with [GAME_DESIGN.md](GAME_DESIGN.md) and [CLOUD_QUEUE_SPEC.md](CLOUD_QUEUE_SPEC.md).

**Guiding rules:**
- One step = one commit. Each step must compile (`stylua src/ && selene src/`), build (`rojo build`), and be independently verifiable before moving on.
- Don't start the next step until the current one is committed and pushed.
- If a step's scope blows up, stop and split it.
- Manual testing happens in Roblox Studio on the Windows VM.

---

## Phase 0 — Prep work (config + remotes + cloud placeholder)

### Step 0.1 — Add new constants to GameConfig

**File:** `src/shared/Config/GameConfig.luau`

Add:
```luau
-- Queue system (cloud training zone)
MAX_QUEUE_LENGTH = 10, -- max players queued behind a treadmill (full rejects new)
QUEUE_JOIN_KEY = Enum.KeyCode.E, -- press E near treadmill to join queue
AFK_KICK_TIMEOUT = 60, -- seconds of no movement before active user is kicked
QUEUE_JOIN_RADIUS = 8, -- studs from treadmill to allow queue join (server-validated)
```

**Done when:** File lints clean, `rojo build` passes.

**Commit:** `Add queue system constants to GameConfig`

---

### Step 0.2 — Add new remote events

**File:** `src/shared/Config/RemoteEvents.luau`

Add:
```luau
-- Queue system
QueueJoin = "QueueJoin", -- client → server, args: treadmillName: string
QueueLeave = "QueueLeave", -- client → server, no args
QueueStateChanged = "QueueStateChanged", -- server → client, args: state: table { treadmillName, position, isActive, isRejected }
MovementLockChanged = "MovementLockChanged", -- server → client, args: isLocked: boolean
```

**File:** `src/server/Services/RemoteService.luau` — verify iteration still creates all events (should Just Work if it iterates the table).

**Done when:** Server logs show all new remotes created in `ReplicatedStorage.Remotes`.

**Commit:** `Add queue system remote events`

---

### Step 0.3 — Add CloudSpawn and cloud platform to project.json

**File:** `default.project.json`

Add under Workspace:
- `CloudSpawn` — Part, single neutral entry point on cloud (invisible marker)
- `CloudPlatform` — Part, the floor of the cloud, large enough for 5 treadmills + queues
- Move `Treadmills` folder onto the cloud (reposition above existing coords to Y=200+)

**Done when:** `rojo build -o /tmp/test.rbxl` passes. On Windows Studio, cloud platform and treadmills are visible in the sky.

**Commit:** `Add cloud platform geometry and CloudSpawn marker`

---

## Phase 1 — Cloud teleport (Layer 1)

### Step 1.1 — Split ResetForRound into state-reset + teleport phases

**File:** `src/server/Services/PlayerService.luau`

Refactor `ResetForRound()`:
- Keep state-reset loop (state=Alive, speed=base, captureTime=nil, joinedRound update, SetSpeed call)
- Move teleport call out into two new public methods:
  - `TeleportAllToCloud()` — iterates all players, teleports each to `CloudSpawn`
  - `TeleportAllToCastle()` — current behaviour (random `SpawnLocations` child)
- Delete `_getSpawnLocations` / `_teleportToSpawn` helpers or reuse them for castle side

**Done when:** Unit test or logs show ResetForRound does not teleport; TeleportAllToCloud and TeleportAllToCastle teleport correctly when called directly.

**Commit:** `PlayerService: split ResetForRound state-reset from teleport`

---

### Step 1.2 — Wire cloud teleport into RoundService

**File:** `src/server/Services/RoundService.luau`

In `_runSafeZone`:
1. `PrisonService:Reset()`
2. `PlayerService:SetRound(roundNumber)`
3. `PlayerService:ResetForRound()` (state only, no teleport)
4. **NEW:** `PlayerService:TeleportAllToCloud()`
5. `KissyService:Activate()`
6. `_setState("SafeZone", ...)`
7. `_countdown(...)`

In `_runHunt`:
1. **NEW:** `PlayerService:TeleportAllToCastle()` (before setting state to Hunt)
2. `_setState("Hunt", ...)`
3. existing countdown

**Done when:** Playtest — Safe Zone starts → all players on cloud. Hunt starts → all on castle spawns.

**Commit:** `RoundService: teleport players to cloud at SafeZone, castle at Hunt`

---

## Phase 2 — Queue state machine (Layer 2)

### Step 2.1 — Rewrite TreadmillService to track occupancy + FIFO queue

**File:** `src/server/Services/TreadmillService.luau` (full rewrite)

State per treadmill:
```luau
type TreadmillState = {
  part: BasePart,
  activeUser: Player?,
  queue: { Player }, -- ordered list, [1] = next
  activeStartTime: number?, -- os.clock() when became active
  lastInputTime: number?, -- for AFK detection (Phase 5)
}
```

Methods:
- `Init(playerService, roundService)` — existing signature
- `Start()` — cache treadmills (existing) + start training loop (existing)
- `OnQueueJoin(player, treadmillName)` — server handler for remote
- `OnQueueLeave(player)` — server handler
- `OnPlayerRemoving(player)` — cleanup on disconnect
- `ResetAllQueues()` — called by RoundService at Safe Zone end (Phase 7)

Queue join logic:
- Find treadmill by name
- Validate player is on cloud (phase == "SafeZone" && player Y ~= cloud Y)
- Validate distance to treadmill <= `QUEUE_JOIN_RADIUS`
- If free → set active
- Else → append to queue (if `#queue < MAX_QUEUE_LENGTH`, otherwise reject)
- Fire `QueueStateChanged` to player with position info

**Note:** Movement lock, UI rendering, and position snapping are in later phases. This step only tracks state and grants speed to the active user.

Training loop: only grants speed to `activeUser` of each treadmill.

**Done when:** Logs show correct active/queue state. 3 players press E near one treadmill → 1 active, 2 queued (in order). Active leaves → next becomes active.

**Commit:** `TreadmillService: rewrite with 1-per-treadmill occupancy + FIFO queue`

---

### Step 2.2 — Client side: E key fires QueueJoin

**File:** `src/client/Controllers/InputController.luau`

Add:
- Listen for `QUEUE_JOIN_KEY` keypress
- On press: find nearest treadmill within `QUEUE_JOIN_RADIUS`; fire `QueueJoin` with its name
- Leave server to validate distance

**Done when:** Press E near a treadmill fires `QueueJoin` to server. Press E away from any treadmill does nothing.

**Commit:** `InputController: handle E key to join treadmill queue`

---

## Phase 3 — Queue feedback UI (Layer 2 continued)

### Step 3.1 — Show queue position / "queue full" in HUD

**File:** `src/client/UI/HudController.luau`

Handle `QueueStateChanged`:
- State includes: `treadmillName`, `position` (1 = active, 2+ = queue), `isRejected` (queue was full)
- If `isRejected`: show notification "Queue full — try another treadmill" (3s)
- Else: show a queue-status label ("Active on T1" or "Queue #3 for T2")
- Clear label when player leaves queue

**Done when:** Playtest — joining a queue shows position; 11th player sees "queue full".

**Commit:** `HudController: display queue status and queue-full notification`

---

## Phase 4 — Movement lock (Layer 3)

### Step 4.1 — PlayerService: LockMovement / UnlockMovement

**File:** `src/server/Services/PlayerService.luau`

Add:
- `LockMovement(player)` — sets `humanoid.WalkSpeed = 0` without overwriting `data.speed`. Also fires `MovementLockChanged(true)` to that client.
- `UnlockMovement(player)` — restores `humanoid.WalkSpeed = data.speed`. Fires `MovementLockChanged(false)`.

Also: modify the `CharacterAdded` re-apply handler so that if the player should be locked at respawn, WalkSpeed is set to 0.

**Done when:** Calling LockMovement freezes movement; UnlockMovement restores speed to stored trained value.

**Commit:** `PlayerService: add LockMovement and UnlockMovement methods`

---

### Step 4.2 — TreadmillService: lock queued players, unlock on dequeue

**File:** `src/server/Services/TreadmillService.luau`

- On adding a player to the queue (not active) → `PlayerService:LockMovement(player)`
- On a player transitioning from queued to active → `PlayerService:UnlockMovement(player)`
- On player leaving queue (voluntary or Safe Zone end) → unlock
- On player leaving active treadmill → no change (they could already move)

**Done when:** Queued player cannot walk but can rotate the camera. Advancing to active restores movement.

**Commit:** `TreadmillService: lock movement for queued players`

---

### Step 4.3 — Position queued players behind the treadmill

**File:** `src/server/Services/TreadmillService.luau`

When a player joins queue at position N:
- Compute a line of CFrames behind the treadmill (e.g., 3 studs apart along -LookVector)
- Set player's HumanoidRootPart CFrame to slot N's position

When queue advances (someone left):
- Shift remaining players to new positions

**Done when:** Queued players visibly stand one behind another. When the front one leaves, the rest step forward.

**Commit:** `TreadmillService: position queued players in a visible line`

---

## Phase 5 — AFK kick (Layer 4)

### Step 5.1 — Detect active-user AFK and evict

**File:** `src/server/Services/TreadmillService.luau`

In the existing training loop (or a separate loop):
- For each treadmill with an `activeUser`, poll `humanoid.MoveDirection.Magnitude`
- If > 0: update `lastInputTime = os.clock()`
- If `os.clock() - lastInputTime > AFK_KICK_TIMEOUT`: evict active user, advance queue

Do NOT apply this check to queued players (they are movement-locked by design).

**Done when:** Active user standing still 60s is removed; next in queue activates.

**Commit:** `TreadmillService: AFK kick after 60s of no movement for active user`

---

### Step 5.2 — Leave Queue button in HUD

**File:** `src/client/UI/HudController.luau`

- When client receives `QueueStateChanged` with `position >= 2` (queued, not active), show a "Leave Queue" button
- On click: fire `QueueLeave` remote
- Hide button on next state update (position=nil or position=1)

**File:** `src/server/Services/TreadmillService.luau`

- Handle `QueueLeave` remote: remove player from whatever queue they're in, unlock movement, fire QueueStateChanged to clear their position

**Done when:** Queued player clicks Leave Queue → they regain movement, queue advances.

**Commit:** `HudController + TreadmillService: Leave Queue button`

---

## Phase 6 — Safe Zone end synchronous release (Layer 5)

### Step 6.1 — Implement ResetAllQueues + wire into RoundService

**File:** `src/server/Services/TreadmillService.luau`

Add `ResetAllQueues()`:
- For each treadmill: if activeUser, clear it; for each queued player, unlock movement
- All players' stored speed (data.speed) is unchanged — they keep their training gains
- Notify clients via `QueueStateChanged` to clear their UI state

**File:** `src/server/Services/RoundService.luau`

In `_runHunt` (before teleport to castle):
1. `TreadmillService:ResetAllQueues()` — releases all locks
2. `PlayerService:TeleportAllToCastle()` — teleport happens after locks released
3. Set state to Hunt

**Done when:** A player queued when Safe Zone ends is unlocked and teleported to a castle spawn with full movement and their trained speed.

**Commit:** `TreadmillService: ResetAllQueues at SafeZone end; RoundService wires synchronous release`

---

## Phase 7 — Kissy behavior fixes

### Step 7.1 — Kissy idles during Safe Zone, only hunts in Hunt phase

**File:** `src/server/Services/KissyService.luau`

In `_huntTick()`:
- At the top, check `RoundService:GetState()`. If not `"Hunt"`, return early (no chase, no catch).
- This means the loop still ticks (so transition to Hunt is instant when state changes), but she doesn't do anything meaningful during SafeZone.

Alternative (cleaner): delay the while-loop start until state becomes "Hunt", not just `KISSY_SPAWN_DELAY` from SafeZone start.

Choose the simpler approach: phase check inside `_huntTick`.

**Done when:** During Safe Zone, Kissy spawns, stands at her exit point, does not chase or catch. Hunt starts → she immediately begins chasing.

**Commit:** `KissyService: idle during SafeZone, only hunt when phase == Hunt`

---

### Step 7.2 — Pass RoundService to KissyService

**File:** `src/server/init.server.luau` and `src/server/Services/KissyService.luau`

KissyService currently only receives PlayerService. Add RoundService dependency so `_huntTick` can check phase.

Change init order carefully — RoundService.Init now requires KissyService, which needs RoundService. Use two-phase init or late-inject RoundService into KissyService.

Simplest: `KissyService:SetRoundService(roundService)` after both are inited.

**Done when:** Compiles, runs, phase check works.

**Commit:** `KissyService: inject RoundService dependency for phase-aware AI`

---

## Phase 8 — Eager win check

### Step 8.1 — Check all-captured after every capture

**File:** `src/server/Services/PlayerService.luau`

In `CapturePlayer`, after firing the remote and invoking capture callback:
- Call `onAllCapturedCallback` if no alive players remain

Add `SetOnAllCaptured(callback)` method.

**File:** `src/server/Services/RoundService.luau`

- Add an "early termination" flag or signal
- Set `PlayerService:SetOnAllCaptured(function() ... end)` to signal Hunt-phase early exit
- In `_runHunt`, the countdown's `shouldStop` checks this flag in addition to the existing condition

**Done when:** Last free player is caught → Hunt phase ends within 1 second.

**Commit:** `Eager win check: Hunt ends immediately when last player captured`

---

## Phase 9 — Coin eligibility snapshot (Intermission-based)

### Step 9.1 — Snapshot eligible players at end of Intermission

**File:** `src/server/Services/PlayerService.luau`

Add `SnapshotEligible(roundNumber)`:
- For each connected player, set `data.joinedRound = roundNumber`
- Called by RoundService just before Safe Zone starts
- Mid-Safe-Zone and mid-Hunt joiners keep their original `joinedRound = previousRound`, so they fail the eligibility check

Remove the `joinedRound = currentRound` line from `ResetForRound` (it was overwriting late-joiners to look eligible).

**File:** `src/server/Services/RoundService.luau`

At end of `_runIntermission` (after player-wait + countdown, before `_runSafeZone`):
- `PlayerService:SnapshotEligible(roundNumber + 1)` — the round that's about to start

Actually simpler: do the snapshot at the start of `_runSafeZone`, right after `SetRound(roundNumber)`, before `ResetForRound()`.

**Done when:** Player joining during Hunt does not receive survival coins at round end.

**Commit:** `PlayerService: snapshot coin-eligible players at round start`

---

## Phase 10 — Verification + cleanup

### Step 10.1 — Re-run `/my-code-review`

Launch a full code review. Address any new issues.

**Commit:** `Fix issues from post-implementation code review`

---

### Step 10.2 — Full playtest checklist

In Studio with 2+ players (or a Play Solo test with dummy NPCs):
- [ ] Round flow: Intermission → Safe Zone (on cloud) → Hunt (on castle) → Round End → loop
- [ ] Single player queue: press E near treadmill → become active → train → gain speed
- [ ] Queue occupancy: 2nd player on same treadmill → queued, locked in place, can rotate
- [ ] Queue advance: active leaves → 2nd becomes active, regains movement
- [ ] Queue full: 11th player sees "queue full" notification
- [ ] AFK kick: active user idle 60s → removed, queue advances
- [ ] Leave queue: click button → exit queue, regain movement
- [ ] Safe Zone end: queued player teleports to castle, movement works, speed preserved
- [ ] Kissy behavior: idles during Safe Zone, chases during Hunt, cannot target cloud players
- [ ] Prison door: Y within 15 studs opens door, prisoners escape, opener gets 25 coins
- [ ] Eager win: last free player caught → Hunt ends immediately
- [ ] Coin eligibility: mid-Hunt joiner gets no survival coins

**Commit:** none (this is manual verification).

---

## Rollback plan

If a phase causes regression, revert with `git revert <commit-hash>` and reopen the spec for discussion. No phase should be reverted without understanding why.

## Out of scope for this plan

- VIP treadmill mechanical benefit (deferred — see GDD § Deferred Features)
- Cross-session coin persistence (DataStore)
- Treehouse mechanics (open question)
- Prison visual indicator (open question)
