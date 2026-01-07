# Roblox Development with Pi-Coding-Agent

## Before Making Changes

Read existing scripts in `src/` to understand how they work. Integrate with existing patterns.

Before using a new Roblox API, you must take a look at docs in `docs/creator-docs/` for up-to-date versions and useful patterns.

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

### studio_run_code Contexts

The tool supports different contexts for querying Studio state:

| Context | When to use |
|---------|-------------|
| `any` (default) | Auto-detect - uses server if playing, edit otherwise |
| `edit` | Query the static scene |
| `server` | Query live game state - players, spawned objects, runtime values |

**Examples:**
```luau
-- Check what's in workspace (auto-detect context)
studio_run_code with code: "return workspace:GetChildren()"

-- Count live players during play mode
studio_run_code with code: "return #game:GetService('Players'):GetPlayers()" and context: "server"
```

**Output format:** Results are prefixed with the responding context: `[server] ...` or `[edit] ...`

**Troubleshooting:** See `.pi/extensions/studio-mcp/README.md` for setup, protocol details, and error resolution.

## File Locations

| Location | Script Type | Runs On |
|----------|-------------|---------|
| `src/server/*.server.luau` | Script | Server only |
| `src/client/*.client.luau` | LocalScript | Client only |
| `src/shared/*.luau` | ModuleScript | Wherever required |

`default.project.json` is for static world setup only (baseplate, spawn).

## Skills

Load a skill with `read` when you need detailed instructions for that workflow.

| Skill | Use this to... |
|-------|----------------|
| `rojo` | Sync code from filesystem to Studio |
| `lune` | Run Luau scripts outside Studio (CI/CD, automation) |
| `roblox-cloud` | Publish, manage datastores, send cross-server messages |
| `upload-assets` | Upload images, sounds, models to Roblox |
| `use-assets` | Load models by AssetId at runtime (includes marketplace search) |

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

## Modifying Game State via MCP

With `MCPBridge.server.luau` installed, `require()` works transparently during play mode:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(ReplicatedStorage.Shared.PlayerDataManager)

PlayerDataManager.setCoins({_playerRef = "PlayerName"}, 5000)  -- Modifies real game state
local coins = PlayerDataManager.getCoins({_playerRef = "PlayerName"})  -- Reads real game state
```

Use `{_playerRef = "Name"}` for Player arguments (Player objects can't cross VM boundary).


