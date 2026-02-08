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

## After Code Changes

Rojo syncs files instantly, but a running game caches scripts on first `require()`.
After ANY `edit` or `write` to `.luau` files:
1. Tell the user to restart the game (Stop → Play)
2. **Wait for the user to confirm** the game is running again
3. Only then verify with `studio_run_code`

Do NOT use `studio_run_code` to test changes without a restart — you'll be testing stale code.

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

**⚠️ VM Isolation:** Code runs in plugin VM, not game VM. Use MCPBridge for game state (see below).

**⚠️ Timeouts:** If `studio_run_code` returns "Request timed out", Studio is not connected. Do NOT retry — ask the user to open Studio and connect first.

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

## Common Pitfalls

### Model:PivotTo() vs Direct CFrame Assignment

`Model:PivotTo(cf)` positions the model's **pivot point** at `cf`, not the PrimaryPart. Imported meshes (GLB, FBX) often have pivot offsets from their 3D modeling tool.

**Symptoms:** Model appears in wrong position/rotation despite correct CFrame math. Rotation animations look wrong. Static tests with `part.CFrame` work but animated code with `PivotTo` doesn't.

**Diagnosis:** If your CFrame math is correct but the model is off, you're likely hitting pivot offset issues.

```luau
-- ❌ UNPREDICTABLE: Pivot may be offset from PrimaryPart
model:PivotTo(targetCFrame)

-- ✅ PREDICTABLE: Directly set the part's CFrame
local part = model:FindFirstChildWhichIsA("BasePart", true)
part.CFrame = targetCFrame
```

**When PivotTo is fine:** Placing models in the world where rough positioning is acceptable.

**When to use direct CFrame:** Animations, ViewportFrames, any precise orientation work.

### Imported Model Orientation

3D models from external tools (Blender, TRELLIS, etc.) often have non-standard orientations. Document the model's actual geometry when you figure it out:

```luau
--[[
    Fish Model Geometry (from GLB export):
    - Bounding box: X=0.46, Y=0.58, Z=1.0 (Z is longest = head-to-tail)
    - Default orientation: nose points along -Y axis (not -Z as typical)
    - Required correction: 90°X + 180°Z roll to align nose to +Z
]]
Config.ModelCorrection = CFrame.Angles(math.rad(90), 0, math.rad(180))
```

**Diagnosis approach:** Create visual test variants with different rotations, place them in front of the player, iterate until correct. Don't guess - test visually.

## Modifying Game State via MCP

**CRITICAL: Read `src/server/MCPBridge.server.luau` before debugging data issues!**

Roblox plugins (including MCP) run in a **separate Luau VM** from game scripts. Without the bridge, `require()` returns different module instances - you can't access game state.

With `MCPBridge.server.luau` installed, `require()` works transparently during play mode:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(ReplicatedStorage.Shared.PlayerDataManager)

PlayerDataManager.setCoins({_playerRef = "PlayerName"}, 5000)  -- Modifies real game state
local coins = PlayerDataManager.getCoins({_playerRef = "PlayerName"})  -- Reads real game state
```

Use `{_playerRef = "Name"}` for Player arguments (Player objects can't cross VM boundary).

### What MCPBridge CAN'T Do

The bridge proxies method calls into the game's VM, but:

| Works | Doesn't Work |
|-------|--------------|
| Calling module functions | Direct table manipulation |
| Reading return values | Resetting module-level caches |
| DataStore operations | Preventing PlayerRemoving saves |

**To reset player data completely:**
1. Reset DataStore directly (works - crosses to Roblox servers)
2. But in-memory module state persists until player rejoins
3. When player leaves, `PlayerRemoving` saves the OLD in-memory data
4. **Solution:** Reset DataStore, then kick player to force fresh load


