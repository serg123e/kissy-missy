# Kissy Missy's Castle — Game Design Document

## Overview

Tag/chase multiplayer game. Kissy Missy (NPC) lives in a castle and hunts players. Caught players are teleported to the prison inside the castle. Players work together to survive and free captured teammates.

## Setting

- A **castle** in the center of the map with a **prison** inside
- Open area around the castle where players spawn and run
- **Training zone** ("Saigur zone") with treadmills near the spawn area

## Characters

### Kissy Missy (NPC)
- AI-controlled antagonist
- Lives in the castle, exits after a delay at the start of each round
- Runs faster than any player (even fully trained)
- Chases the nearest player (or uses smarter targeting — see AI section)
- On contact with a player → that player is teleported to prison

### Players
- Spawn around the castle
- Start with base walk speed
- Can train on treadmills to increase speed
- Can free prisoners by pressing Y near the prison door
- Goal: survive until the round ends

## Core Mechanics

### Speed & Treadmills
- Players start with base speed (16 studs/s)
- Treadmills are located in the training zone
- Standing on a treadmill and running increases player speed over time
- Speed caps at a maximum (24 studs/s)
- Kissy Missy is always faster (28 studs/s) — players can never outrun her forever, only buy time
- Speed resets each round

### Prison
- Located inside the castle
- Caught players are teleported here
- Prison door is closed by default
- Any free player can approach the door and press Y to open it
- Door stays open for 5 seconds, then closes automatically
- All prisoners inside can escape during those 5 seconds
- Freeing prisoners is risky — Kissy Missy may be nearby

### Kissy Missy AI
- Exits the castle after an initial delay (safe zone period)
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
1. **Intermission** (15s) — players gather in lobby, scores shown
2. **Safe zone** (15s) — players spawn around the castle, can train on treadmills, Kissy Missy stays inside
3. **Hunt** (5 min) — Kissy Missy exits and chases players
4. **Round end** — either all players caught (Kissy wins) or time runs out (players win)
5. Back to intermission

### Win Conditions
- **Kissy Missy wins:** all players are in prison simultaneously
- **Players win:** at least one player is free when the timer runs out

### Economy & Leaderboard
- Players who are **free when the round ends** earn coins
- Coins are the primary leaderboard metric
- Leaderboard sorted by total coins earned
- Bonus coins for freeing prisoners (risk/reward)
- Coins persist for the server session

## Map Layout

```
         [Training Zone / Treadmills]

    [Spawn Area]          [Spawn Area]

              [   Castle   ]
              [             ]
              [  [Prison]   ]
              [             ]

    [Spawn Area]          [Spawn Area]
```

- Castle is the central landmark, visible from everywhere
- Training zone is near spawn but away from the castle entrance
- Open terrain around the castle with a few **treehouses** as hiding spots (scarce — 3-4 max)
- Treehouses provide temporary cover but Kissy Missy can still reach them

## Decided Parameters
- **Max players:** 32
- **Round duration:** 5 minutes
- **Kissy Missy speed:** constant, does not increase during the round
- **Treadmill training:** resets each round
- **Hiding spots:** treehouses on trees, very few (scarcity forces players to move and cooperate)

## Open Questions
- Should prison have a visual indicator (glow, sound) when players are inside?
- Can Kissy Missy enter treehouses or does she wait below?
- How many treehouses? (3-4 suggested)
- How many players can fit in one treehouse?
