# Roblox Development with Pi-Coding-Agent

## Before Making Changes

Read existing scripts in `src/` to understand how they work. Integrate with existing patterns.

Consult docs before using Roblox APIs - they change frequently. Run `make setup-docs` if missing.

| Topic | Path |
|-------|------|
| Scripting basics | `docs/creator-docs/scripting/` |
| Luau language | `docs/creator-docs/luau/` |
| Remote events | `docs/creator-docs/scripting/events/remote.md` |
| Data storage | `docs/creator-docs/tutorials/use-case-tutorials/data-storage/` |
| Tutorials | `docs/creator-docs/tutorials/use-case-tutorials/scripting/` |

## How to Make Changes

Use `write` to create new `.luau` files. Use `edit` to modify existing ones. Rojo syncs them to Studio automatically.

`studio_run_code` is for debugging and inspection only (e.g., "what's in workspace?", "check player position").

| User says | Tool |
|-----------|------|
| "Add coins to collect" | `write` → `src/server/Coins.server.luau` |
| "Fix the scoring bug" | `edit` → `src/server/ScorePoints.server.luau` |
| "What parts are in workspace?" | `studio_run_code` |

## File Locations

| Location | Script Type | Runs On |
|----------|-------------|---------|
| `src/server/*.server.luau` | Script | Server only |
| `src/client/*.client.luau` | LocalScript | Client only |
| `src/shared/*.luau` | ModuleScript | Wherever required |

`default.project.json` is for static world setup only (baseplate, spawn).

## Common Patterns

### Creating Parts in Scripts

```luau
local part = Instance.new("Part")
part.Name = "Lava"
part.Size = Vector3.new(4, 1, 4)
part.Position = Vector3.new(10, 0.5, 0)
part.Anchored = true
part.Material = Enum.Material.Neon
part.BrickColor = BrickColor.new("Bright orange")
part.Parent = Workspace
```

### Getting Services

```luau
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
```

### Module Scripts

```luau
-- src/shared/Config.luau
local Config = {}
Config.LavaRadius = 15
return Config
```


