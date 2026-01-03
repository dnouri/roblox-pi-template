--[[
	MCPBridge.server.luau
	Generic bridge for MCP/plugin access to game module state
	
	============================================================================
	WHY THIS EXISTS
	============================================================================
	
	Roblox plugins run in a SEPARATE Luau VM from game scripts. This means
	require() from plugin code returns DIFFERENT module instances - you can't
	read or modify game state directly.
	
	This bridge runs in the GAME's VM, allowing the MCP plugin to transparently
	proxy require() calls through it. With this bridge installed, MCP code
	just works:
	
	    local PlayerDataManager = require(ReplicatedStorage.Shared.PlayerDataManager)
	    PlayerDataManager.setCoins({_playerRef = "PlayerName"}, 5000)
	
	============================================================================
	PLAYER REFERENCES
	============================================================================
	
	Player objects can't cross the VM boundary. Use {_playerRef = "Name"} or
	{_playerRef = UserId} instead - the bridge resolves these automatically.
	
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

--------------------------------------------------------------------------------
-- MODULE RESOLUTION
--------------------------------------------------------------------------------
local moduleCache: { [string]: any } = {}

local function resolveModule(path: string): any?
	-- Check cache first
	if moduleCache[path] then
		return moduleCache[path]
	end

	-- Parse path like "ReplicatedStorage.Shared.PlayerDataManager"
	local parts = string.split(path, ".")
	if #parts < 2 then
		return nil
	end

	-- Get the service
	local serviceName = parts[1]
	local success, service = pcall(function()
		return game:GetService(serviceName)
	end)

	if not success or not service then
		return nil
	end

	-- Navigate to the module
	local current: Instance = service
	for i = 2, #parts do
		local child = current:FindFirstChild(parts[i])
		if not child then
			return nil
		end
		current = child
	end

	-- Require if it's a ModuleScript
	if current:IsA("ModuleScript") then
		local ok, result = pcall(require, current)
		if ok then
			moduleCache[path] = result
			return result
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- PLAYER RESOLUTION
--------------------------------------------------------------------------------
local function resolvePlayer(identifier: string | number): Player?
	if typeof(identifier) == "number" then
		return Players:GetPlayerByUserId(identifier)
	elseif typeof(identifier) == "string" then
		return Players:FindFirstChild(identifier) :: Player?
	end
	return nil
end

--------------------------------------------------------------------------------
-- BRIDGE FUNCTION
--------------------------------------------------------------------------------
local bridge = Instance.new("BindableFunction")
bridge.Name = "MCPBridge"
bridge.Parent = ServerScriptService

bridge.OnInvoke = function(modulePath: string, methodName: string, ...: any)
	-- Special command: _getType returns type info without calling functions
	if modulePath == "_getType" then
		local actualPath = methodName
		local key = select(1, ...)
		local module = resolveModule(actualPath)
		if not module then
			return { success = false, error = "Module not found: " .. actualPath }
		end
		local value = module[key]
		if value == nil then
			return { success = false, error = "Key not found: " .. key }
		end
		return { success = true, isProperty = typeof(value) ~= "function", result = typeof(value) }
	end

	-- Resolve the module
	local module = resolveModule(modulePath)
	if not module then
		return { success = false, error = "Module not found: " .. modulePath }
	end

	-- Get the method
	local method = module[methodName]
	if not method then
		return { success = false, error = "Method not found: " .. methodName }
	end

	if typeof(method) ~= "function" then
		-- It's a property, just return it
		return { success = true, result = method, isProperty = true }
	end

	-- Process arguments - convert player refs to Player objects
	local args = { ... }
	for i, arg in ipairs(args) do
		if typeof(arg) == "table" and arg._playerRef then
			local player = resolvePlayer(arg._playerRef)
			if player then
				args[i] = player
			else
				return { success = false, error = "Player not found: " .. tostring(arg._playerRef) }
			end
		end
	end

	-- Call the method
	local results = { pcall(method, table.unpack(args)) }
	local ok = table.remove(results, 1)

	if not ok then
		return { success = false, error = tostring(results[1]) }
	end

	return { success = true, result = results[1], results = results }
end

print("[MCPBridge] Ready - external tools can access game modules")
