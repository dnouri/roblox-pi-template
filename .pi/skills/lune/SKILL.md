---
name: lune
description: Use this to run Luau scripts outside Studio. Automate builds, manipulate place files, run tests, and write CI/CD scripts — all without needing Roblox Studio running.
---

# Lune Skill

Lune is a standalone Luau runtime that runs outside of Roblox Studio.

**Use Lune for offline automation:**
- Manipulate .rbxl/.rbxm files without Studio
- CI/CD scripts (build, test, deploy)
- Unit test pure Luau logic (no Roblox services)
- File processing, HTTP requests, general scripting

**Use `studio_run_code` instead when you need:**
- Live Studio connection (marketplace search, previews)
- Roblox services (Players, InsertService, etc.)
- Debugging objects in a running session

## Setup Type Definitions

Run once to get editor autocomplete for Lune APIs:
```bash
./bin/lune setup
```

## Commands

### Run a Script
```bash
./bin/lune run scripts/my-script.luau
```

### Interactive REPL
```bash
./bin/lune repl
```

## Built-in Libraries

Lune provides these globals (not available in regular Roblox):

| Library | Purpose |
|---------|---------|
| `fs` | Filesystem operations (read, write, copy, move) |
| `net` | HTTP requests and serving |
| `process` | Environment variables, args, spawn, exit |
| `stdio` | Terminal input/output, colors |
| `task` | Async scheduling (spawn, wait, delay) |
| `roblox` | Read/write .rbxl, .rbxm files, Instance creation |

## Example: Modify a Place File

```luau
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

-- Read and deserialize place file
local content = fs.readFile("build.rbxl")
local game = roblox.deserializePlace(content)

-- Add a new folder to ReplicatedStorage
local repStorage = game:FindFirstChild("ReplicatedStorage")
local folder = roblox.Instance.new("Folder")
folder.Name = "AddedByLune"
folder.Parent = repStorage

-- Serialize and write back
local newContent = roblox.serializePlace(game)
fs.writeFile("build.rbxl", newContent)
```

## Example: HTTP Request

```luau
local net = require("@lune/net")

local response = net.request({
    url = "https://api.example.com/data",
    method = "GET",
})

if response.ok then
    print(response.body)
end
```

## Example: Run Tests

```luau
-- scripts/test.luau
local fs = require("@lune/fs")
local process = require("@lune/process")

-- Find and run test files
for _, file in fs.readDir("src") do
    if file:match("%.spec%.luau$") then
        local result = process.spawn("./bin/lune", {"run", "src/" .. file})
        if not result.ok then
            process.exit(1)
        end
    end
end
```

## Script Location

Place Lune scripts in the `scripts/` directory:
```
scripts/
├── build-assets.luau
├── test.luau
└── deploy.luau
```
