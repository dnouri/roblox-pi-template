---
name: use-assets
description: Use this to add models, decorations, and props to your game. Store AssetIds in Luau configs and load at runtime from Roblox CDN. Keeps your repo clean with version-controlled asset references instead of binary files.
---

# Use Assets Skill

**Preferred approach for game assets** because:
- AssetIds are just numbers in `.luau` files — easy to diff, review, and version control
- No binary files (.rbxm) cluttering your repo
- No need to save place files to persist models
- Assets load directly from Roblox's CDN at runtime

**How it works:** Store AssetIds in Luau config files, then load models at runtime using `InsertService:LoadAsset()`.

**Works with:** Your own uploaded assets, group assets, shared assets, and free marketplace models.

## Asset Access Permissions

| Asset Type | LoadAsset | Requires Setting? |
|------------|-----------|-------------------|
| **Your own assets** | ✅ Yes | No |
| **Your group's assets** | ✅ Yes | No |
| **Assets shared with you** | ✅ Yes | No |
| **Roblox-owned assets** | ✅ Yes | No |
| **Free marketplace (third-party)** | ✅ Yes | Yes* |

*Enable in **Game Settings > Security > "Allow Loading Third Party Assets"**

## Workflow

### Option A: Use Your Own Assets

1. Upload a model to Roblox (via Studio or `upload-assets` skill)
2. Get the AssetId from the URL or Creator Dashboard
3. Store in config and load at runtime

```lua
local MyAssets = {
    FarmBuilding = 123456789,  -- Your asset
    CustomTree = 987654321,    -- Your asset
}
```

### Option B: Discover Free Marketplace Assets

Use `studio_run_code` to search:

```lua
local InsertService = game:GetService("InsertService")

local results = InsertService:GetFreeModelsAsync("farm building", 0)
local data = results[1]

for i, item in ipairs(data.Results) do
    print(item.Name, item.AssetId, item.CreatorName)
end
```

### Preview Before Committing

Load and inspect in Studio:

```lua
-- Works in Studio (plugin context)
local objects = game:GetObjects("rbxassetid://210055534")
for _, obj in ipairs(objects) do
    obj.Parent = workspace
    print("Loaded:", obj.Name, obj.ClassName)
end
```

### Store AssetIds in Config

Create `src/shared/AssetIds.luau`:

```lua
-- AssetIds.luau
-- Can be your own assets, group assets, or marketplace finds

return {
    -- Your own/group assets (always accessible)
    CustomShop = 123456789,
    
    -- Marketplace discoveries (need third-party setting)
    FarmShop = 210055534,
    Scarecrow = 8900106835,
}
```

### Load at Runtime

```lua
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local function loadAsset(assetId: number): Model?
    local success, result = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    
    if success then
        local model = result:GetChildren()[1]
        return model
    else
        warn("Failed to load asset:", assetId, result)
        return nil
    end
end

local shop = loadAsset(AssetIds.FarmShop)
if shop then
    shop.Parent = workspace
    shop:PivotTo(CFrame.new(-30, 0, 0))
end
```

## API Reference

| Method | Purpose | Context |
|--------|---------|---------|
| `InsertService:GetFreeModelsAsync(query, page)` | Search marketplace | Server |
| `InsertService:LoadAsset(assetId)` | Load at runtime | Server |
| `AssetService:LoadAssetAsync(assetId)` | Modern LoadAsset alternative | Server |
| `game:GetObjects("rbxassetid://ID")` | Preview/load in Studio | Studio/Plugin |

## Tips

- **Own assets are always accessible** — no special settings needed
- **Preview in Studio first** — use `game:GetObjects()` before committing IDs
- **Cache loaded models** — clone from a template instead of reloading
- **Handle failures gracefully** — always wrap in pcall
