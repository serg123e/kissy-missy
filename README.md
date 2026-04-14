# Kissy Missy's Castle

Tag/chase multiplayer Roblox game. Up to 32 players try to survive while Kissy Missy (AI-controlled NPC) hunts them around a castle. Caught players are teleported to prison. Free players can open the prison door to rescue teammates. Train on treadmills to run faster — but Kissy is always faster.

## How the game works

### Round flow

1. **Intermission** (15s) — scores shown, waiting for at least 2 players
2. **Safe Zone** (15s) — all players teleport to the cloud platform, can train on treadmills (1 per treadmill, FIFO queue). Kissy Missy exits the castle after 10s
3. **Hunt** (5 min) — Kissy chases and catches players
4. **Round End** (5s) — survivors earn 100 coins, results displayed

### Mechanics

- **Treadmills** — press **E** near a treadmill on the cloud to join its queue (1 active user, FIFO queue up to 10). Training grants +0.5 speed every 3s (max 24). Kissy is always faster (28). Speed resets each round
- **Prison** — caught players are teleported to prison inside the castle. Any free player can press **Y** near the prison door to open it for 5 seconds, freeing everyone inside (25 coins reward)
- **Kissy Missy AI** — chases the nearest player, guards the prison door when players approach, occasionally switches targets unpredictably
- **Win** — players win if at least one survives when the timer runs out. Kissy wins if everyone is captured

### Leaderboard

Players who survive earn **100 coins**. Opening the prison door earns **25 coins**. Coins are the leaderboard metric.

## Setup (Windows — Roblox Studio)

### 1. Install Rokit

Open PowerShell and run:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1" -OutFile "install-rokit.ps1"
.\install-rokit.ps1
```

Close and reopen the terminal after installation.

### 2. Clone the repo

```powershell
git clone https://github.com/serg123e/kissy-missy.git
cd kissy-missy
```

### 3. Install tools

Rokit reads `rokit.toml` and installs the correct versions of all tools:

```powershell
rokit install
```

This installs: Rojo, Wally, Selene, StyLua, Lune.

### 4. Install the Rojo plugin in Roblox Studio

1. Open Roblox Studio
2. Go to **Plugins** tab -> **Manage Plugins**
3. Search for **Rojo** and install it
4. Restart Studio

### 5. Connect Studio to the project

In the terminal, start the Rojo dev server:

```powershell
rojo serve
```

In Roblox Studio:
1. Open any place (or create a new one)
2. Click the **Rojo** button in the Plugins tab
3. Click **Connect** (default address `localhost:34872`)
4. Studio will sync with the project files

Changes to `.luau` files are now live-synced to Studio.

### 6. Build a place file (alternative to live sync)

If you just want to generate a `.rbxl` file without live sync:

```powershell
rojo build -o game.rbxl
```

Then open `game.rbxl` in Roblox Studio.

## What to set up in Studio

Placeholder objects are already created by Rojo — reposition them in your castle map.

### Workspace (reposition after sync)

| Object | Where to place | Purpose |
|--------|---------------|---------|
| `PrisonSpawn` | Inside the prison room | Caught players teleport here |
| `PrisonExit` | Outside the prison door | Freed players teleport here |
| `PrisonDoor` | Prison entrance | Opens/closes when players press Y |
| `KissySpawn` | Inside the castle | Kissy Missy spawns here each round |
| `Treadmills/` (Folder) | On the cloud platform | Reposition each Part child individually |
| `SpawnLocations/` (Folder) | Around the castle | Reposition each SpawnLocation child individually |
| `CloudSpawn` | On the cloud platform | All players teleport here at Safe Zone start |
| `CloudPlatform` | Sky elevation | Platform players stand on during Safe Zone |
| `CloudWalls/` (Folder) | Around cloud edge | 4 invisible walls preventing players from falling off |
| `PrisonZone` | Enclosing the prison interior | Invisible volume with PathfindingModifier; prevents Kissy from entering prison |

### ServerStorage (create manually)

Create a **Model** named `KissyMissy`:
1. In Explorer: right-click **ServerStorage** -> Insert Object -> **Model**
2. Rename it to `KissyMissy`
3. Add a **Humanoid** inside the model
4. Add body parts (Head, Torso, etc.) or use a character template
5. Make sure it has a **HumanoidRootPart** (the main body part)
6. Design the character appearance as you like

### Map building checklist

- [ ] Build the castle (central landmark, visible from everywhere)
- [ ] Build the prison room inside the castle
- [ ] Place the prison door at the entrance
- [ ] Position PrisonSpawn inside and PrisonExit outside the prison
- [ ] Position KissySpawn inside the castle
- [ ] Position 5 treadmills on the cloud platform
- [ ] Place 4 spawn locations around the castle
- [ ] Position CloudSpawn on the cloud platform
- [ ] Position CloudPlatform at sky elevation
- [ ] Position 4 CloudWalls around the cloud platform edge
- [ ] Position and size PrisonZone to enclose the prison interior
- [ ] Create the KissyMissy model in ServerStorage
- [ ] Optional: add 3-4 treehouses as hiding spots

## Project structure

```
src/
  server/              -> ServerScriptService
    Services/
      RemoteService    — creates RemoteEvents
      PlayerService    — player state, coins, speed, leaderboard
      RoundService     — game loop (Intermission -> SafeZone -> Hunt -> RoundEnd)
      PrisonService    — prison door, teleport, Y key interaction
      KissyService     — NPC AI, pathfinding, catch detection
      TreadmillService — speed training on treadmill parts
  client/              -> StarterPlayerScripts
    Controllers/
      InputController            — Y key fires DoorInteract remote
      KissySmoothingController  — client-side visual smoothing for Kissy NPC
    UI/
      HudController    — game state, timer, coins, door prompt, notifications
  shared/              -> ReplicatedStorage
    Config/
      GameConfig       — all game constants (speeds, timers, radii, coins)
      RemoteEvents     — remote event name constants
    Logic/
      QueueLogic       — pure queue state machine (FIFO assign/remove/position)
      EligibilityLogic — survival reward eligibility checks
      PlayerStateLogic — player state guard predicates
      TimeFormat       — time formatting for HUD display
```

## Testing

Run the pre-commit gate (format check + lint + tests + build):

```bash
./scripts/test.sh
```

## Development (Linux)

Edit `.luau` files on Linux. Run Roblox Studio on a Windows VM with the Rojo plugin connected via `rojo serve` (use bridged/host-only networking).

```bash
# Format code
stylua src/

# Lint code
selene src/

# Build place file
rojo build -o game.rbxl
```
