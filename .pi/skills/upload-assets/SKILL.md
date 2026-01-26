---
name: upload-assets
description: Use this to upload images, sounds, and 3D models to Roblox. Uses Open Cloud API via rbxcloud CLI. Returns AssetIds for use in your game.
---

# Upload Assets Skill

**Use this to:** Upload your own assets (images, audio, 3D models) to Roblox and get AssetIds back.

**How it works:** Uses the Open Cloud API via `rbxcloud` CLI to upload files and retrieve AssetIds.

**Pairs with:** The `use-assets` skill to load your uploaded assets at runtime.

## Prerequisites

API key with `assets` permission (Write). Set in `.env`:
```bash
ROBLOX_OPEN_CLOUD_API_KEY=your-key-here
ROBLOX_USER_ID=your-user-id
```

## Upload an Asset

```bash
source .env
./bin/rbxcloud assets create \
  --display-name "My Icon" \
  --description "Icon for my game" \
  --creator-type user \
  --creator-id $ROBLOX_USER_ID \
  --asset-type decal-png \
  --filepath path/to/image.png \
  --api-key $ROBLOX_OPEN_CLOUD_API_KEY
```

## Asset Types

| Type | Use For |
|------|---------|
| `decal-png`, `decal-jpeg` | Images, textures, icons |
| `audio-mp3`, `audio-ogg`, `audio-wav` | Sound effects, music |
| `model-fbx` | 3D models |

## Check Upload Status

Uploads are async. Check completion:

```bash
./bin/rbxcloud assets get-operation \
  --operation-id "operation-id-from-create" \
  --api-key $ROBLOX_OPEN_CLOUD_API_KEY
```

The response includes `assetId` when done.

## ⚠️ Grant Experience Permissions

**Uploaded assets are private by default.** Other players cannot access them until you grant your experience permission to use them.

### Why This Matters

When you upload via Open Cloud API:
- Asset is owned by your **user account**
- Only you can see/hear it in Studio and playtesting
- Other players experience **nothing** in the published game

### Grant Permissions via API

Use the Asset Permissions API to grant your experience "Use" permission:

```bash
curl -X PATCH \
  "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions" \
  -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "subjectType": "Universe",
    "subjectId": "YOUR_UNIVERSE_ID",
    "action": "Use",
    "requests": [
      {"assetId": 123456789},
      {"assetId": 987654321}
    ]
  }'
```

### API Key Requirements

Your API key needs an **additional scope**:
1. Go to Creator Dashboard → Credentials
2. Edit your API key
3. Add `asset-permissions` to Access Permissions
4. Enable `Write` operation

### Environment Variables

Add to `.env`:
```bash
ROBLOX_UNIVERSE_ID=your-universe-id
```

Find your Universe ID in Game Settings → Basic Info, or from the URL when editing the game.

## Use Uploaded Assets in Game

Once uploaded and permissions granted, store the AssetId and use it:

```luau
-- For images/decals
local decal = Instance.new("Decal")
decal.Texture = "rbxassetid://123456789"
decal.Parent = workspace.Part

-- For models, see the use-assets skill
local InsertService = game:GetService("InsertService")
local model = InsertService:LoadAsset(123456789)
```
