---
name: roblox-cloud
description: Roblox Open Cloud API operations using rbxcloud CLI. Use for publishing, datastores, messaging, and universe management.
---

# Roblox Cloud Skill (rbxcloud)

rbxcloud provides CLI access to Roblox Open Cloud APIs.

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

List datastores:
```bash
./bin/rbxcloud datastore list \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID
```

List keys in a datastore:
```bash
./bin/rbxcloud datastore entries list \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --datastore-name PlayerData
```

Get a value:
```bash
./bin/rbxcloud datastore entries get \
    --api-key $ROBLOX_OPEN_CLOUD_API_KEY \
    --universe-id $ROBLOX_UNIVERSE_ID \
    --datastore-name PlayerData \
    --entry-id player_123
```

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
