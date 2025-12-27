---
name: rojo
description: Rojo operations for syncing filesystem to Roblox Studio. Use for serving, building, and managing Rojo projects.
---

# Rojo Skill

Rojo syncs your filesystem to Roblox Studio in real-time.

## Prerequisites

Ensure tools are installed:
```bash
make setup-tools
```

Install the Rojo plugin in Studio:
- Download from https://github.com/rojo-rbx/rojo/releases (Rojo.rbxm)
- Place in your Studio plugins folder

## Commands

### Start Live Sync
```bash
./bin/rojo serve
```
Then connect from Studio: Plugins tab → Rojo → Connect

### Build Place File
```bash
./bin/rojo build -o build.rbxl
```

### Build Model File
```bash
./bin/rojo build -o build.rbxm
```

### Generate Sourcemap
```bash
./bin/rojo sourcemap -o sourcemap.json
```

## Project Configuration

The `default.project.json` maps filesystem paths to Roblox DataModel:

```json
{
  "name": "game-name",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$path": "src/server"
    },
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/client"
      }
    }
  }
}
```

## File Naming Conventions

| Pattern | Roblox Type |
|---------|-------------|
| `init.server.luau` | ServerScript (folder becomes script) |
| `init.client.luau` | LocalScript (folder becomes script) |
| `init.luau` | ModuleScript (folder becomes module) |
| `*.server.luau` | ServerScript |
| `*.client.luau` | LocalScript |
| `*.luau` | ModuleScript |

## Creating Game Objects

Use `write` to create new `.luau` files in `src/`. Use `edit` to modify existing ones. Rojo syncs them automatically.

`studio_run_code` is for debugging and inspection only.
