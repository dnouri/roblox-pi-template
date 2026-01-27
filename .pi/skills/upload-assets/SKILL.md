---
name: upload-assets
description: Use this to upload images, sounds, and 3D models to Roblox. Uses Open Cloud API via rbxcloud CLI. Returns AssetIds for use in your game.
---

# Upload Assets Skill

Upload your own assets (images, audio, 3D models) to Roblox via Open Cloud API.

**Pairs with:** The `use-assets` skill to load uploaded assets at runtime.

## Prerequisites

API key with `assets` permission (Write). Set in `.env`:
```bash
ROBLOX_OPEN_CLOUD_API_KEY=your-key-here
ROBLOX_USER_ID=your-user-id
```

## Quick Reference

```bash
source .env

# Upload image
./bin/rbxcloud assets create \
  --display-name "My Icon" \
  --description "Icon for my game" \
  --creator-type user --creator-id $ROBLOX_USER_ID \
  --asset-type decal-png \
  --filepath icon.png \
  --api-key $ROBLOX_OPEN_CLOUD_API_KEY

# Check status (uploads are async)
./bin/rbxcloud assets get-operation \
  --operation-id "operation-id-from-create" \
  --api-key $ROBLOX_OPEN_CLOUD_API_KEY
```

## Asset Types

| Type | Use For |
|------|---------|
| `decal-png`, `decal-jpeg` | Images, textures, icons |
| `audio-mp3`, `audio-ogg`, `audio-wav` | Sound effects, music |
| `model-fbx` | 3D models (FBX only, not GLB) |

## Converting GLB to FBX

**Problem:** Many 3D sources (Sketchfab, TurboSquid, AI generators like TRELLIS) provide GLB files, but Roblox only accepts FBX. Naive Blender conversion loses textures due to two issues:

1. **Complex material nodes**: glTF uses packed textures (e.g., metallicRoughness). Blender's importer creates intermediate nodes that the FBX exporter doesn't understand.

2. **Metallic materials break diffuse baking**: Blender's DIFFUSE bake returns **black** for metallic materials because PBR metals have no diffuse component—they're purely specular. AI generators like TRELLIS often output high metalness values.

**Solution:** Use the included script with emission-based texture baking:

```bash
# Standard conversion
blender --background --python {baseDir}/scripts/glb_to_fbx.py -- input.glb output.fbx

# For organic models (characters, animals, plants) - skip metallic texture
blender --background --python {baseDir}/scripts/glb_to_fbx.py -- input.glb output.fbx --no-metallic
```

**What it does:**
1. Imports GLB with all complex material nodes
2. Bakes each channel via Emission shader (bypasses PBR physics issues)
3. Creates clean material with direct texture connections
4. Exports FBX with textures embedded

**When to use `--no-metallic`:** For organic/natural objects that shouldn't have metallic reflections. Without this flag, models may appear dark in Roblox ViewportFrames (which lack environment reflections for metallic surfaces).

**Requirements:** Blender 3.0+ from https://blender.org

**Batch conversion:**
```bash
for f in *.glb; do
  blender --background --python {baseDir}/scripts/glb_to_fbx.py -- "$f" "${f%.glb}.fbx" --no-metallic
done
```

## Asset Permissions

After uploading, grant your experience permission to use the assets:

```bash
curl -X POST "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions/grant" \
  -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "assetIds": [123456789, 987654321],
    "universePermissions": [{"universeId": "YOUR_UNIVERSE_ID", "action": "Use"}]
  }'
```

## Use in Game

```luau
-- Images/decals
local decal = Instance.new("Decal")
decal.Texture = "rbxassetid://123456789"
decal.Parent = workspace.Part

-- 3D models (see use-assets skill for patterns)
local InsertService = game:GetService("InsertService")
local model = InsertService:LoadAsset(123456789)
model.Parent = workspace
```

## Troubleshooting

### Model appears black/dark in ViewportFrame
Metallic materials need environment reflections. Either:
- Re-convert with `--no-metallic` flag
- Clear `SurfaceAppearance.MetalnessMap` at runtime:
  ```luau
  local sa = meshPart:FindFirstChildOfClass("SurfaceAppearance")
  if sa then sa.MetalnessMap = "" end
  ```

### Model appears gray/untextured
The diffuse texture didn't bake correctly. This happens with standard DIFFUSE baking on metallic materials. Use the included script which uses emission-based baking.

### Textures missing after FBX export
Blender's FBX exporter only recognizes direct `Image Texture → Principled BSDF` connections. The script handles this by creating a clean material after baking.
