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
    Controllers/   → Client controllers (input, visual smoothing)
    UI/            → GUI controllers (HUD)
  shared/          → ReplicatedStorage (shared between server & client)
    Config/        → Game constants and configuration
    Logic/         → Pure logic modules (testable without Roblox engine)
```

## Service Architecture
Services use manual dependency injection. Initialization order in `init.server.luau`:
1. `RemoteService:Init()` — creates Remotes folder and all RemoteEvents
2. `PlayerService:Init(remoteService)` — player state, coins, leaderboard
3. `KissyService:Init(playerService)` — NPC AI, pathfinding, capture
4. `RoundService:Init(remoteService, playerService, prisonService, kissyService)` — game loop
5. `PrisonService:Init(remoteService, playerService, roundService)` — prison + door
6. `TreadmillService:Init(remoteService, playerService, roundService)` — queue-based speed training

Late-inject (avoids circular init dependencies):
- `RoundService:SetTreadmillService(TreadmillService)` — round end releases all queues
- `KissyService:SetRoundService(RoundService)` — phase-aware AI (only chases during Hunt)

Then wire `PlayerService:SetOnCapture` → `PrisonService:TeleportToPrison` and call `RoundService:Start()` + `TreadmillService:Start()`.

## Required Workspace Parts (must exist in Studio place file)
- `PrisonSpawn` — Part inside the castle prison; players teleport here on capture
- `PrisonExit` — Part outside the prison; freed players teleport here
- `PrisonDoor` — Part representing the prison door; toggled transparent/collidable
- `KissySpawn` — Part inside the castle; Kissy Missy spawns here each round
- `Treadmills` — Folder with Part children; players stand on them to train speed
- `SpawnLocations` — Folder with SpawnLocation children; players teleport here at Hunt start
- `CloudSpawn` — Part on the cloud platform; all players teleport here at Safe Zone start
- `CloudPlatform` — Large Part at cloud elevation; the platform players stand on during Safe Zone
- `CloudWalls` — Folder with 4 invisible wall Parts around the cloud platform edge; prevents players from falling off
- `PrisonZone` — Invisible Part enclosing the prison interior; has a PathfindingModifier child (Label="PrisonInterior") so Kissy's pathfinding treats the prison as impassable

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

## Game Constants
All timing, speed, radius, and coin values live in `src/shared/Config/GameConfig.luau` — the single source of truth. Do not duplicate values in docs; reference the file.

## Specs
- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) — gameplay design document
- [docs/CLOUD_QUEUE_SPEC.md](docs/CLOUD_QUEUE_SPEC.md) — cloud/queue training system spec (implemented)
- [docs/KISSY_AI_POLISH_SPEC.md](docs/KISSY_AI_POLISH_SPEC.md) — Kissy AI pathfinding and smoothing polish spec (implemented)

## Testing

Automated tests use Lune (standalone Luau runtime). Run the full pre-commit gate:

```bash
./scripts/test.sh
```

This runs: `stylua --check src/ tests/` → `selene src/` → `lune run tests/run.luau` → `rojo build -o /tmp/test.rbxl`.

- Tests live in `tests/`. Hand-rolled runner at `tests/lib/runner.luau` — no framework.
- **In scope:** pure logic in `src/shared/Logic/` (queue state machine, eligibility, player state guards, time formatting) and config integrity.
- **Out of scope:** anything engine-dependent (pathfinding, CFrame/teleport, RemoteEvent wiring, UI rendering, `CharacterAdded` timing) — verified manually in Studio.
- Selene runs on `src/` only — `std="roblox"` doesn't recognize Lune's `@lune/*` imports. StyLua formats both `src/` and `tests/`.

## Code Style
- Tabs for indentation
- 120 char line width
- Double quotes preferred
- Run `stylua src/` to auto-format
- Run `selene src/` to lint — fix all warnings
