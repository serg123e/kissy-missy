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
    Services/      → Game services (round manager, prison, etc.)
    Components/    → Server-side entity components
  client/          → StarterPlayerScripts (client-only code)
    Controllers/   → Client controllers (input, camera, etc.)
    UI/            → GUI controllers
  shared/          → ReplicatedStorage (shared between server & client)
    Config/        → Game constants and configuration
    Types/         → Type definitions
    Modules/       → Shared utility modules
```

## File Naming Conventions
- `*.server.luau` → Script (runs on server)
- `*.client.luau` → LocalScript (runs on client)
- `*.luau` → ModuleScript (importable module)
- `init.server.luau` / `init.client.luau` → entry point for directory

## Development Workflow
- Linux: edit `.luau` files, run `selene src/` and `stylua src/` before commit
- Windows VM: run Roblox Studio with Rojo plugin connected to `rojo serve`
- Build place file: `rojo build -o game.rbxl`

## Code Style
- Tabs for indentation
- 120 char line width
- Double quotes preferred
- Run `stylua src/` to auto-format
- Run `selene src/` to lint — fix all warnings
