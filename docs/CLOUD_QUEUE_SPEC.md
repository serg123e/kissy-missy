# Cloud & Queue System — Implementation Spec

Task spec for building the Safe Zone training system. Parent design: [GAME_DESIGN.md](GAME_DESIGN.md).

## Goal

Replace the current proximity-based treadmill system with a server-authoritative queued training system, hosted on a separate cloud platform where Kissy Missy cannot reach.

## Context

### Current state
- 4 treadmills stand around the castle (not on a cloud)
- `TreadmillService` detects players via horizontal + vertical distance; any number of players can train on the same treadmill simultaneously
- Players move freely during Safe Zone
- No queue, no access limit, no movement lock, no AFK detection
- `PlayerService:ResetForRound` teleports players to castle `SpawnLocations`

### Target state
- 5 treadmills on a separate cloud platform (4 free + 1 VIP, VIP behaves as regular for now)
- 1 player per treadmill, FIFO queue behind each (max 10)
- Movement lock while queued (rotate only)
- AFK kick for active user only
- All players teleport to cloud at Safe Zone start, to castle at Hunt start

## Mechanics

### Cloud platform
- Floating platform in the sky, inaccessible from the castle map
- Fence + invisible wall around the edge — players cannot fall off
- Single neutral entry point `CloudSpawn` — all players land here at Safe Zone start

### Treadmill occupancy
- Each treadmill has exactly 1 active user at a time
- Walking up to a treadmill and pressing **E** joins its queue (or starts training if empty)
- Free treadmill → new player immediately becomes the active user
- Occupied treadmill → new player enters the FIFO queue

### Queue
- FIFO (first-in-first-out)
- Maximum 10 players per queue
- Full queue rejects new joiners — UI notification "Queue full — try another treadmill"
- Queued players line up visually behind the treadmill (server positions them)
- **Movement lock while queued**: server-authoritative `WalkSpeed = 0`. Camera rotation still free.
- When a queued player reaches the active slot, their `WalkSpeed` is restored to their stored `data.speed` (coordinated with `PlayerService:SetSpeed`)

### Voluntary leave
- Queued players can leave via a **Leave Queue** UI button (not by walking away — they are locked)
- Active users can leave by walking off the treadmill
- On leave, the next player in queue advances to the active slot

### AFK kick
- Applies **only to the active treadmill user**, not to queued players
- If the active user provides no movement input for 60 seconds, they are removed and the next in queue takes the slot
- Queued players are exempt (they cannot move by design)

### Safe Zone end transition
Order of operations is **synchronous**:
1. All queue state cleared
2. All movement locks released (WalkSpeed restored to each player's trained value)
3. All players teleported from cloud to castle `SpawnLocations`
4. Hunt phase begins

Without this order, locked players arrive at castle permanently frozen.

### Kissy and the cloud
Kissy Missy cannot reach the cloud. Enforced by: her target list is filtered to "active Hunt players only" (derived from `RoundService` state). Cloud players are never added to her target set.

## Parameters

| Constant | Value | Location |
|----------|-------|----------|
| `MAX_QUEUE_LENGTH` | 10 | `GameConfig.luau` (new) |
| `AFK_KICK_TIMEOUT` | 60 seconds | `GameConfig.luau` (new) |
| `QUEUE_JOIN_KEY` | `Enum.KeyCode.E` | `GameConfig.luau` (new) |
| `QUEUE_JOIN_RADIUS` | 8 studs | `GameConfig.luau` (new) |
| Treadmill count | 5 (4 free + 1 VIP) | Workspace |

Existing timing/speed values live in `src/shared/Config/GameConfig.luau` — see there for `SAFE_ZONE_DURATION`, `MAX_PLAYER_SPEED`, etc.

## Suggested build order

Each layer is independently testable. Build and verify one before moving to the next.

### Layer 1 — Cloud platform + teleport
- Add `CloudSpawn` Part in workspace (cloud platform entry point)
- `PlayerService:ResetForRound` splits into two phases: `TeleportToCloud` at Safe Zone start, `TeleportToCastle` at Hunt start
- Cloud has fence + invisible wall
- **Done when:** All players teleport to the cloud when Safe Zone begins, and to castle spawns when Hunt begins. Players cannot fall off the cloud edge.

### Layer 2 — Treadmill occupancy + queue
- Rewrite `TreadmillService`: track active user per treadmill + FIFO queue
- Press E near treadmill to join queue or become active
- Full queue (10) rejects new joiners with UI notification
- **Done when:** 6 players press E near the same treadmill → 1 active, 5 queued. A 7th is rejected with a visible message. 1st leaves → 2nd becomes active → 3rd moves up in queue.

### Layer 3 — Movement lock for queued players
- Server sets `WalkSpeed = 0` on queue entry; restores to stored `data.speed` on dequeue
- Camera rotation remains free
- Queued players positioned visually in line behind the treadmill
- **Done when:** Queued players cannot move but can rotate the camera. On reaching the active slot, their WalkSpeed returns correctly.

### Layer 4 — AFK kick + Leave Queue UI
- Detect movement input for active user; after 60s idle → remove + advance queue
- "Leave Queue" button in HUD when player is in a queue
- **Done when:** A player standing idle on a treadmill for 60s is removed and the next in queue activates. A queued player clicking "Leave Queue" exits and the queue shifts.

### Layer 5 — Safe Zone end synchronous release
- On Safe Zone end: clear queue state → release locks → restore speeds → teleport
- **Done when:** A queued or active player at Safe Zone end arrives at Hunt with correct WalkSpeed (≥ base speed) and full movement.

### Layer 6 — VIP treadmill (deferred)
- Scoped out of this iteration. VIP treadmill exists visually but behaves as a regular treadmill. Revisit when monetization is prioritized.

## Resolved Questions

- **Queued player visual**: Server positions queued players via `CFrame.lookAt` along the treadmill's `-LookVector`, spaced `QUEUE_SPACING = 3` studs apart. Server sets `HumanoidRootPart.CFrame` directly.
- **AFK detection**: Server-side polling of `Humanoid.MoveDirection.Magnitude > 0` every `TREADMILL_TICK_SECONDS`. No client-side replication needed.
- **Queue full feedback**: Toast-style notification in the HUD (existing `_notify` method, auto-hides after 3 seconds).
- **Voluntary leave cooldown**: No cooldown. Players can immediately re-join the same queue at the back.

## Affected subsystems

- `TreadmillService` — full rewrite (queue state, FIFO, access control, movement lock coordination, AFK kick, `ResetAllQueues`)
- `PlayerService` — split `ResetForRound` into `TeleportAllToCloud` + `TeleportAllToCastle`; add `LockMovement`/`UnlockMovement`, `SnapshotEligible`, `SetOnAllCaptured`
- `RoundService` — call cloud teleport at Safe Zone start; synchronous release sequence at Safe Zone end; eager win check via `huntEarlyTermination` flag; late-inject `TreadmillService` via `SetTreadmillService`
- `KissyService` — phase-aware AI: `_huntTick` skips chase when `RoundService:GetState() ~= "Hunt"`; late-inject `RoundService` via `SetRoundService`
- `HudController` (client) — add queue status label, "Leave Queue"/"Leave Treadmill" button; queue-full notification
- `InputController` (client) — add E key → fire `QueueJoin` remote with nearest treadmill name
- `RemoteEvents` — new events: `QueueJoin`, `QueueLeave`, `QueueStateChanged`
- `GameConfig` — add `MAX_QUEUE_LENGTH`, `AFK_KICK_TIMEOUT`, `QUEUE_JOIN_KEY`, `QUEUE_JOIN_RADIUS`
- Workspace — add `CloudSpawn` Part, `CloudPlatform` Part, reposition treadmills to cloud elevation
- `init.server.luau` — late-inject wiring for `RoundService:SetTreadmillService` and `KissyService:SetRoundService`
