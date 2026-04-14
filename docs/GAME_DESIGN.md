# Kissy Missy's Castle — Game Design Document

## Overview

Tag/chase multiplayer game. Kissy Missy (NPC) lives in a castle and hunts players. Caught players are teleported to the prison inside the castle. Players work together to survive and free captured teammates.

## Setting

Two distinct areas:

- **Castle map** — a castle in the center with a **prison** inside. Open terrain around it where players run during the Hunt phase.
- **Cloud (training zone)** — a separate area in the sky where players are teleported during the Safe Zone phase to train on treadmills. Kissy Missy cannot reach the cloud.

## Characters

### Kissy Missy (NPC)
- AI-controlled antagonist
- Lives in the castle, exits after a delay at the start of each round
- Runs faster than any player (even fully trained)
- Chases the nearest player (or uses smarter targeting — see AI section)
- On contact with a player → that player is teleported to prison

### Players
- Teleported to the **cloud** during Safe Zone to train
- Teleported to spawn points **around the castle** when Hunt begins
- Start with base walk speed
- Can train on treadmills (limited slots → queue system)
- Can free prisoners by pressing Y near the prison door
- Goal: survive until the round ends

## Core Mechanics

### Speed & Treadmills

- Players start with base speed (16 studs/s)
- Speed caps at maximum (24 studs/s)
- Kissy Missy is always faster (28 studs/s) — players can never outrun her forever, only buy time
- Speed resets each round

#### Cloud (training zone)
- **5 treadmills** total on the cloud
- **4 regular treadmills** (free for all players)
- **1 VIP treadmill** (requires Robux purchase to use)
- **Only one player per treadmill** at a time
- Standing on a treadmill increases speed over time (+0.5 every 3s)

#### Queue system
- All players arrive at a **single neutral entry point** on the cloud when Safe Zone starts
- From there, a player walks up to any treadmill to join its queue
- If the treadmill is free, the player immediately starts training
- If occupied, they enter the **queue** for that treadmill
- Queue is FIFO (first-in-first-out)
- **Maximum queue length: 10 players** per treadmill. If the queue is full, no more players can join it
- **Queue positioning:** players visually line up one behind another behind the treadmill. Movement is locked while queued — players can only rotate in place (look around) until they reach the treadmill or voluntarily leave the queue
- A player can **voluntarily leave** a treadmill or queue at any time (walks away → next in queue takes the slot)
- **AFK kick:** if a player on a treadmill is idle (no movement input) for **60 seconds**, they are automatically removed to let the queue progress
- When the current player leaves (voluntary, Safe Zone ends, disconnects, or AFK-kicked), the next player in queue takes the slot
- Queue resets at the end of each Safe Zone

### Prison
- Located inside the castle
- Caught players are teleported here
- Prison door is closed by default
- Any free player can approach the door and press Y to open it
- Door stays open for 5 seconds, then closes automatically
- All prisoners inside can escape during those 5 seconds
- Freeing prisoners is risky — Kissy Missy may be nearby

### Kissy Missy AI
- Stays in the castle during Safe Zone (cannot reach the cloud)
- Exits the castle 10s into Safe Zone — the last 5s of Safe Zone overlap with her active hunting (but players are safe on the cloud until Hunt begins)
- Primary behavior: chase nearest player
- Should be smart enough to not be easily baited by a lone decoy every time
- Potential behaviors:
  - Prioritize groups over lone players (harder to catch many at once, but more reward)
  - Occasionally switch targets unpredictably
  - Return to guard prison if players are near the door
  - Speed up slightly as fewer players remain free

### Teamwork Dynamics
- One player can distract Kissy Missy while others escape or free prisoners
- But Kissy Missy might not take the bait — she may go after the larger group
- Communication and coordination between players is key

## Game Flow

### Round Structure
1. **Intermission** (15s) — players gather, scores shown. Waits for minimum 2 players before countdown.
2. **Safe Zone** (15s) — players teleported to the **cloud**, can queue and train on treadmills. Kissy Missy remains in the castle.
3. **Hunt** (5 min) — all players teleported from the cloud to spawn points around the castle. Kissy Missy starts chasing.
4. **Round End** (5s) — results displayed, survivors awarded coins.
5. Back to intermission.

### Win Conditions
- **Kissy Missy wins:** all players are in prison simultaneously
- **Players win:** at least one player is free when the timer runs out

### Economy & Leaderboard
- Players who are **free when the round ends** earn coins
- Coins are the primary leaderboard metric
- Leaderboard sorted by total coins earned
- Bonus coins for freeing prisoners (risk/reward)
- Coins persist for the server session

### VIP Treadmill (Monetization)
- One of the 5 treadmills is locked behind a Robux purchase (developer product or gamepass — TBD)
- **Mechanical benefit deferred** — for now, VIP treadmill is visually distinct but uses the same mechanics as regular treadmills. Specific advantage to be decided later.
- Non-VIP players cannot use this treadmill or queue for it

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

- Castle is the central landmark, visible from everywhere
- Spawn locations positioned around the castle (players teleport here when Hunt begins)
- Open terrain with a few **treehouses** as hiding spots (scarce — 3-4 max)
- Treehouses provide temporary cover but Kissy Missy can still reach them

### Cloud (Safe Zone phase)
```
    +---------------------------------+
    |  [T1]  [T2]  [T3]  [T4]  [VIP] |
    |   |     |     |     |     |    |
    |  queue queue queue queue queue |
    +---------------------------------+
```

- Floating platform in the sky, inaccessible from the castle map
- 5 treadmills in a row: T1-T4 (free) and VIP
- Each treadmill has a visible queue spot behind it
- Kissy Missy cannot teleport to or reach the cloud

## Decided Parameters
- **Max players:** 32
- **Min players to start:** 2
- **Round duration:** 5 minutes
- **Round end display:** 5 seconds
- **Intermission:** 15 seconds
- **Safe Zone:** 15 seconds (Kissy exits castle at 10s, but players are safe on cloud)
- **Kissy Missy speed:** constant (28 studs/s), does not increase during the round
- **Base player speed:** 16 studs/s
- **Max player speed:** 24 studs/s
- **Treadmill speed gain:** +0.5 per 3 seconds
- **Treadmill training:** resets each round
- **Treadmill count:** 5 total (4 free + 1 VIP)
- **Treadmill occupancy:** 1 player at a time, others queue FIFO
- **Max queue length:** 10 players per treadmill (full queue rejects new players)
- **AFK kick timeout:** 60 seconds of no movement input
- **Queue behavior:** players lined up behind the treadmill, movement locked (rotation only) until their turn or they leave
- **Voluntary leave:** players can leave a treadmill or queue at any time
- **Cloud safety:** fence + invisible wall around the edge (players cannot fall off)
- **Teleport mode:** automatic — all players teleported to a single neutral entry point on the cloud at Safe Zone start
- **Hiding spots:** treehouses on trees, very few (scarcity forces movement and cooperation)
- **Coins per survived round:** 100 (only for players present at round start)
- **Coins per door open:** 25 (flat, regardless of prisoner count)

## Open Questions

### VIP Treadmill — DEFERRED
The entire VIP monetization system (mechanical benefit, purchase model, UI) is parked for now. The VIP treadmill exists visually but behaves identically to the regular ones until monetization is prioritized. Options to revisit when we come back to it:
- **Mechanical benefit:** (a) faster training (+1.0/3s), (b) guaranteed/separate queue, (c) higher speed cap (26 studs/s), (d) cosmetic only
- **Purchase model:** Gamepass (permanent) vs Developer Product (per-round)

### Other
- Should prison have a visual indicator (glow, sound) when players are inside?
- Can Kissy Missy enter treehouses or does she wait below?
- How many treehouses? (3-4 suggested)
- How many players can fit in one treehouse?
