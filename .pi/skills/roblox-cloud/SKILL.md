---
name: roblox-cloud
description: Use this to publish your game, manage datastores, and send cross-server messages — all from the command line without opening a browser.
---

# Roblox Cloud Skill

**Use this for command-line game management:**
- Publish places without opening Studio or the website
- Read/write datastore entries for debugging or migrations
- Send messages to all running servers (announcements, restarts)

**Requires:** Open Cloud API key from https://create.roblox.com/dashboard/credentials

## Prerequisites

Set in `.env`:
```bash
ROBLOX_OPEN_CLOUD_API_KEY=your-key-here
ROBLOX_UNIVERSE_ID=123456789
ROBLOX_PLACE_ID=987654321
```

Then source it:
```bash
source .env
```

## Commands

### Publish Place

Build and publish in one step:
```bash
make build
./bin/rbxcloud experience publish \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --place-id $ROBLOX_PLACE_ID \
    --filename build.rbxl \
    --version-type published
```

Use `--version-type saved` to save without publishing.

### DataStore Operations

List all datastores in a universe:
```bash
./bin/rbxcloud datastore list-stores \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --limit 100
```

List keys in a datastore (`--limit` is required):
```bash
./bin/rbxcloud datastore list \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --datastore-name PlayerData \
    --limit 100
```

Get a value by key:
```bash
./bin/rbxcloud datastore get \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --datastore-name PlayerData \
    --key player_123
```

Delete an entry:
```bash
./bin/rbxcloud datastore delete \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --datastore-name PlayerData \
    --key player_123
```

**Available subcommands:** `list-stores`, `list`, `get`, `set`, `increment`, `delete`, `list-versions`, `get-version`. Run `./bin/rbxcloud datastore --help` for details.

### Messaging (Cross-Server)

Publish a message to all servers:
```bash
./bin/rbxcloud messaging publish \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --topic ServerAnnouncement \
    --message '{"text": "Server restart in 5 minutes"}'
```

## API Key Permissions

Create your API key at https://create.roblox.com/dashboard/credentials

Add these API Systems with Write permission:
- **Publishing**: `universe-places`
- **DataStores**: `universe-datastores`
- **Messaging**: `universe.messaging-service`
- **Assets**: `assets`

## Finding Universe and Place IDs

1. Go to https://create.roblox.com/dashboard/creations
2. Click on your experience
3. Universe ID is in the URL: `universes/UNIVERSE_ID/...`
4. Place ID is shown on the experience page
