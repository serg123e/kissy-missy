# Kissy Missy's Castle

Tag/chase multiplayer Roblox game. Kissy Missy (NPC) hunts players around a castle, catches them and teleports to prison. Players can free prisoners and train on treadmills to run faster.

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

## What to create in Studio

The code expects these objects. Placeholder Parts already exist after build/sync — move them to the correct positions in your castle.

### Workspace (already created, just reposition)

| Part | Where to place | Purpose |
|------|---------------|---------|
| `PrisonSpawn` | Inside the prison room | Caught players teleport here |
| `PrisonExit` | Outside the prison door | Freed players teleport here |
| `PrisonDoor` | Prison entrance | Opens/closes when players press Y |
| `KissySpawn` | Inside the castle | Kissy Missy spawns here each round |
| `Treadmills` (Folder) | Training zone near spawn | Contains Part children — reposition each treadmill Part individually |

### ServerStorage (create manually)

Create a **Model** named `KissyMissy`:
1. In Explorer, right-click **ServerStorage** -> Insert Object -> **Model**
2. Rename it to `KissyMissy`
3. Add a **Humanoid** inside the model
4. Add body parts (Head, Torso, etc.) or use a character template
5. Make sure it has a **HumanoidRootPart** (the main body part)
6. Design the character appearance as you like

## Project structure

```
src/
  server/          -> ServerScriptService (server-only code)
    Services/      -> Game services (round manager, prison, AI, etc.)
  client/          -> StarterPlayerScripts (client-only code)
  shared/          -> ReplicatedStorage (shared between server & client)
    Config/        -> Game constants and configuration
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
