---
name: roblox-assets
description: Upload images, sounds, and models to Roblox using rbxcloud.
---

# Roblox Assets Skill

Upload assets using rbxcloud.

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

## Use in Game

```luau
local decal = Instance.new("Decal")
decal.Texture = "rbxassetid://123456789"  -- Your asset ID
decal.Parent = workspace.Part
```
