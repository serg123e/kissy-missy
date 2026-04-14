# Kissy Missy's Castle — Game Design Document

## Overview

Tag/chase multiplayer game. Kissy Missy (NPC) lives in a castle and hunts players. Caught players are teleported to the prison inside the castle. Players work together to survive and free captured teammates.

## Setting

Two distinct areas:

- **Castle map** — a castle in the center with a **prison** inside. Open terrain around it where players run during the Hunt phase.
- **Cloud (training zone)** — a separate area in the sky where players train on treadmills during the Safe Zone phase. Kissy Missy cannot reach the cloud. See [CLOUD_QUEUE_SPEC.md](CLOUD_QUEUE_SPEC.md) for the full cloud/queue system spec.

## Characters

### Kissy Missy (NPC)
- AI-controlled antagonist
- Lives in the castle, exits after a delay into Safe Zone
- Runs faster than any trained player
- On contact with a player → player is teleported to prison
- Cannot reach the cloud (target list restricted to active Hunt players only)

**Done when:** Kissy exits the castle during Safe Zone, chases players during Hunt, and catching a player teleports them to prison within 1 second.

### Players
- Teleported to the **cloud** at Safe Zone start
- Teleported to spawn points **around the castle** at Hunt start
- Start each round with base walk speed
- Can train on treadmills (1 per treadmill, FIFO queue — see [CLOUD_QUEUE_SPEC.md](CLOUD_QUEUE_SPEC.md))
- Can free prisoners by pressing Y near the prison door
- Goal: survive until the Hunt timer runs out, or free trapped teammates for bonus coins

## Core Mechanics

### Speed & Treadmills

Players start each round with base speed. Kissy Missy is always faster than any fully trained player — players can never outrun her forever, only buy time. Speed resets each round.

Treadmill training happens on the cloud during Safe Zone. The cloud/queue system is specified in detail in [CLOUD_QUEUE_SPEC.md](CLOUD_QUEUE_SPEC.md). Summary:
- 5 treadmills total (4 free + 1 VIP placeholder — VIP behaves as regular for now, monetization deferred)
- 1 active user per treadmill, FIFO queue behind each
- Movement locked while queued, AFK kick for active user only
- All numeric values live in `src/shared/Config/GameConfig.luau`

**Done when:** A player standing on an active treadmill gains speed over time up to the cap, and that speed applies in the Hunt phase after teleport.

### Prison
- Located inside the castle
- Caught players are teleported here
- Door is closed by default
- Any free player presses **Y** within 15 studs of the door to open it
- Door stays open for 5 seconds, then closes automatically
- All prisoners inside can escape during those 5 seconds
- Opening the door awards 25 coins to the opener
- Freeing prisoners is risky — Kissy Missy may be nearby

**Done when:** A free player within 15 studs of the door pressing Y opens the door. All captured players teleport out within 5 seconds. Door closes automatically. Opener receives 25 coins.

### Kissy Missy AI

**In scope for v1 (current implementation):**
- Chase nearest active Hunt player (primary behavior)
- Guard the prison door when players approach
- 10% chance per retarget to switch to a random player (unpredictability)

**Deferred / future:**
- Prioritize groups over lone players
- Speed up as fewer players remain free

Kissy's target list is restricted to players currently in the Hunt phase on the castle map. Cloud players are never targeted — this is how cloud inaccessibility is enforced.

**Done when:** Kissy consistently chases the nearest alive player during Hunt, prefers players near the prison door, and occasionally switches to a random target.

### Teamwork Dynamics
- One player can distract Kissy while others escape or free prisoners
- Kissy may not take the bait — she may go after the larger group or guard the door
- Communication and coordination between players is key

## Game Flow

### Round Structure
1. **Intermission** — players gather, scores shown. Waits for minimum player count before countdown.
2. **Safe Zone** — all players teleport to the **cloud** (CloudSpawn). Kissy Missy stays in the castle. Kissy exits her castle position partway through Safe Zone and idles at the castle exit point (she does not reach the cloud).
3. **Safe Zone end** — **synchronous release sequence**: clear queue state → release movement locks → restore speeds → teleport all players from cloud to castle SpawnLocations → start Hunt.
4. **Hunt** — Kissy chases players around the castle map.
5. **Round End** — results displayed, survivors awarded coins.
6. Back to Intermission.

Timing values (durations, Kissy exit delay) live in `src/shared/Config/GameConfig.luau`.

### Win Conditions
- **Kissy Missy wins:** all players are in prison simultaneously. Win is checked **eagerly** on every capture event — even if the prison door is mid-cycle, the moment the last free player is caught Kissy wins.
- **Players win:** at least one player is free when the Hunt timer runs out.

### Player count below minimum
If players drop below the minimum mid-round, the current round **continues to its natural end** — Kissy still chases remaining players. A new round only blocks in Intermission if the minimum is not met.

### Economy & Leaderboard
- **100 coins** awarded to each surviving player at round end
- **Eligibility snapshot**: any player connected during Intermission is eligible for survival coins. Mid-round joiners (joined during Safe Zone or later) are ineligible for that round's survival reward.
- **25 coins** awarded immediately to the player who opens the prison door (flat, regardless of how many prisoners escape)
- Leaderboard sorted by total coins earned
- Coins persist for the server session (no cross-session persistence in v1)

**Done when:** Surviving players at Hunt end receive 100 coins. Opening the prison door credits 25 coins immediately. Leaderboard updates live.

## Map Layout

### Castle map (Hunt phase)
```
              [   Castle   ]
              [             ]
              [  [Prison]   ]
              [             ]

    [Spawn]                [Spawn]

         (open terrain, treehouses)

    [Spawn]                [Spawn]
```

Castle is the central landmark, visible from everywhere. Spawn locations surround it. Open terrain has a few **treehouses** as scarce hiding spots (3-4 max).

### Cloud (Safe Zone phase)
```
    +---------------------------------+
    |  [T1]  [T2]  [T3]  [T4]  [VIP] |
    |   |     |     |     |     |    |
    |  queue queue queue queue queue |
    +---------------------------------+
```

Floating platform in the sky, inaccessible from the castle map. Fence + invisible wall around the edge. Single neutral entry point `CloudSpawn` where all players arrive at Safe Zone start.

## Open Questions

- Should the prison have a visual indicator (glow, sound) when players are inside?
- Can Kissy Missy enter treehouses or does she wait below?
- How many treehouses? (3-4 suggested)
- How many players can fit in one treehouse?

## Deferred Features

### VIP Treadmill Monetization
The 5th treadmill is visually distinct but behaves identically to regular ones. When monetization is prioritized, decide:
- **Mechanical benefit:** (a) faster training, (b) separate/guaranteed queue, (c) higher speed cap, (d) cosmetic only
- **Purchase model:** Gamepass (permanent) vs Developer Product (per-round)
