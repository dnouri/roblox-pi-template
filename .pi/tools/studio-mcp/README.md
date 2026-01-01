# Studio MCP Tool

Execute Luau code in Roblox Studio from pi-agent.

## Prerequisites

1. **MCP Server**: `bin/rbx-studio-mcp` (compiled Rust binary)
2. **Studio Plugin**: `MCPStudioPlugin.rbxm` installed in Studio's Plugins folder
3. **LoadStringEnabled**: Set in `default.project.json` for server-side execution

## Usage

### studio_run_code

Execute Luau code and return results.

| Context | Use case |
|---------|----------|
| `any` (default) | Auto-detect available context |
| `edit` | Query static scene |
| `server` | Query live game state during play mode |

**Examples:**
```
# Check workspace contents (auto-detect)
studio_run_code with code: "return workspace:GetChildren()"

# Count players in running game
studio_run_code with code: "return #game:GetService('Players'):GetPlayers()" and context: "server"
```

### Searching & Inserting Marketplace Models

Use `studio_run_code` directly (see the `use-assets` skill for the full workflow):

```lua
-- Search marketplace
local InsertService = game:GetService("InsertService")
local results = InsertService:GetFreeModelsAsync("tree", 0)[1]
for i, item in ipairs(results.Results) do
    print(i, item.Name, item.AssetId)
end
```

```lua
-- Preview a specific asset
local objects = game:GetObjects("rbxassetid://123456789")
objects[1].Parent = workspace
```

The recommended workflow is to store AssetIds in config files and load at runtime - see the `use-assets` skill.

## Troubleshooting

### "Request timed out"

1. **Is Studio running?** The plugin only works when Studio is open.
2. **Is the plugin loaded?** Check Studio Output for:
   ```
   [MCP Plugin] Running in context: edit
   [MCP Plugin] Connected in edit mode - ready for prompts.
   ```
3. **Using server context?** Press Play first - server context only exists during play mode.
4. **Plugin not connecting?** Restart Studio to reload the plugin.

### "loadstring() is not available"

Server-side code execution requires `LoadStringEnabled`:

1. Check `default.project.json` has:
   ```json
   "ServerScriptService": {
       "$properties": {
           "LoadStringEnabled": true
       }
   }
   ```
2. Re-sync with Rojo: `bin/rojo serve`

### "MCP server started but not responding"

The server binary may be missing or crashed:

```bash
# Check if running
ps aux | grep rbx-studio-mcp

# Start manually
./bin/rbx-studio-mcp --http-only

# Check logs
./scripts/start-mcp-server.sh status
```

## Protocol

The tool communicates with Studio via HTTP proxy.

**Request:** `POST http://127.0.0.1:44755/proxy`
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "context": "server",
  "args": {
    "RunCode": { "command": "return workspace:GetChildren()" }
  }
}
```

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "response": "[RETURNED RESULTS] {...}",
  "context": "server"
}
```

## Architecture

During play mode, Studio has multiple DataModels:

- **Edit DataModel**: Suspended when playing (but still queryable)
- **Server DataModel**: The running server
- **Client DataModel**: The player's view (no HTTP access)

The plugin runs in each DataModel and connects with its context identifier. The MCP server routes requests to the matching context.

## Building from Source

See `/tmp/context.md` for full build instructions, or:

```bash
# Build Rust server
cd /tmp/mcp-plugin-mod
cargo build --release
cp target/release/rbx-studio-mcp ~/co/roblox-pi-template/bin/

# Build plugin
cd /tmp/mcp-plugin-mod/plugin
~/co/roblox-pi-template/bin/rojo build -o ~/co/roblox-pi-template/bin/MCPStudioPlugin.rbxm

# Install plugin
cp ~/co/roblox-pi-template/bin/MCPStudioPlugin.rbxm ~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/$USER/AppData/Local/Roblox/Plugins/
```
