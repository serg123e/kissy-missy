# Kissy Missy's Castle

Roblox tag/chase game built with Rojo.

## Tech Stack
- **Language:** Luau
- **Build:** Rojo (file sync to Roblox Studio)
- **Packages:** Wally
- **Linter:** Selene (`selene src/`)
- **Formatter:** StyLua (`stylua src/`)
- **Runtime (standalone):** Lune
- **Toolchain:** Rokit (`rokit.toml`)

## Project Structure
```
src/
  server/          → ServerScriptService (server-only code)
    Services/      → Game services (round manager, prison, AI, treadmills)
  client/          → StarterPlayerScripts (client-only code)
    Controllers/   → Client controllers (input)
    UI/            → GUI controllers (HUD)
  shared/          → ReplicatedStorage (shared between server & client)
    Config/        → Game constants and configuration
```

## Service Architecture
Services use manual dependency injection. Initialization order in `init.server.luau`:
1. `RemoteService:Init()` — creates Remotes folder and all RemoteEvents
2. `PlayerService:Init(remoteService)` — player state, coins, leaderboard
3. `KissyService:Init(playerService)` — NPC AI, pathfinding, capture
4. `RoundService:Init(remoteService, playerService, prisonService, kissyService)` — game loop
5. `PrisonService:Init(remoteService, playerService, roundService)` — prison + door
6. `TreadmillService:Init(playerService, roundService)` — speed training

Then wire `PlayerService:SetOnCapture` → `PrisonService:TeleportToPrison` and call `RoundService:Start()` + `TreadmillService:Start()`.

## Required Workspace Parts (must exist in Studio place file)
- `PrisonSpawn` — Part inside the castle prison; players teleport here on capture
- `PrisonExit` — Part outside the prison; freed players teleport here
- `PrisonDoor` — Part representing the prison door; toggled transparent/collidable
- `KissySpawn` — Part inside the castle; Kissy Missy spawns here each round
- `Treadmills` — Folder with Part children; players stand on them to train speed
- `SpawnLocations` — Folder with SpawnLocation children; players teleport here at round start

## Required ServerStorage Assets
- `KissyMissy` — Model with Humanoid + HumanoidRootPart; the NPC template cloned each round

## File Naming Conventions
- `*.server.luau` → Script (runs on server)
- `*.client.luau` → LocalScript (runs on client)
- `*.luau` → ModuleScript (importable module)
- `init.server.luau` / `init.client.luau` → entry point for directory

## Development Workflow
- Linux: edit `.luau` files, run `selene src/` and `stylua src/` before commit
- Windows VM: run Roblox Studio with Rojo plugin connected to `rojo serve`
- Build place file: `rojo build -o game.rbxl`

## Key Timing Values
- `SAFE_ZONE_DURATION = 15s` — players can train on treadmills
- `KISSY_SPAWN_DELAY = 10s` — Kissy exits castle 10s into SafeZone (last 5s overlap with hunting)
- `ROUND_DURATION = 300s` (5 min) — hunt phase
- `ROUND_END_DURATION = 5s` — results display

## Code Style
- Tabs for indentation
- 120 char line width
- Double quotes preferred
- Run `stylua src/` to auto-format
- Run `selene src/` to lint — fix all warnings
