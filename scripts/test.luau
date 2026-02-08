-- test.luau
-- Main test runner - discovers and runs all *.spec.luau files
-- Usage: ./bin/lune run scripts/test.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")
local roblox = require("@lune/roblox")

--------------------------------------------------------------------------------
-- TIMEOUT WATCHDOG
-- Kills the test runner if tests hang for too long
--------------------------------------------------------------------------------
local TIMEOUT_SECONDS = 30

task.spawn(function()
	task.wait(TIMEOUT_SECONDS)
	print("")
	print(stdio.color("red") .. "✗ TIMEOUT: Tests took longer than " .. TIMEOUT_SECONDS .. " seconds" .. stdio.color("reset"))
	print(stdio.color("red") .. "  A test may be hanging or stuck in an infinite loop" .. stdio.color("reset"))
	print("")
	process.exit(1)
end)

--------------------------------------------------------------------------------
-- INJECT ROBLOX GLOBALS
-- This must happen BEFORE requiring any game modules
--------------------------------------------------------------------------------
Vector3 = roblox.Vector3
CFrame = roblox.CFrame
Color3 = roblox.Color3
UDim = roblox.UDim
UDim2 = roblox.UDim2
Enum = roblox.Enum
Instance = roblox.Instance
BrickColor = roblox.BrickColor
NumberRange = roblox.NumberRange
NumberSequence = roblox.NumberSequence
ColorSequence = roblox.ColorSequence
NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
Ray = roblox.Ray
Rect = roblox.Rect
Region3 = roblox.Region3
Font = roblox.Font

-- Mock Random class (not in @lune/roblox)
-- Uses simple LCG for deterministic pseudo-random numbers
Random = {}
Random.__index = Random

function Random.new(seed: number?): typeof(Random)
	local self = setmetatable({}, Random)
	-- LCG parameters (same as many C rand implementations)
	self._state = seed or os.clock() * 1000000
	self._a = 1103515245
	self._c = 12345
	self._m = 2^31
	return self
end

function Random:NextNumber(min: number?, max: number?): number
	-- Linear congruential generator step
	self._state = (self._a * self._state + self._c) % self._m
	local normalized = self._state / self._m
	
	if min and max then
		return min + normalized * (max - min)
	elseif min then
		return min + normalized * (1 - min)
	end
	return normalized
end

function Random:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1))
end

--------------------------------------------------------------------------------
-- MINIMAL TEST FRAMEWORK (inline to avoid path issues)
--------------------------------------------------------------------------------
local results = {
	passed = 0,
	failed = 0,
	errors = {},
}

local currentDescribe = ""

local function formatValue(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		return "{...}"
	else
		return tostring(value)
	end
end

-- Test structure
local describeHadFailure = false

function describe(name: string, fn: () -> ())
	currentDescribe = name
	describeHadFailure = false
	fn()
	currentDescribe = ""
end

function it(name: string, fn: () -> ())
	local success, err = pcall(fn)
	if success then
		results.passed += 1
	else
		-- Print describe header on first failure in this block
		if not describeHadFailure then
			print(stdio.color("blue") .. "▶ " .. currentDescribe .. stdio.color("reset"))
			describeHadFailure = true
		end
		results.failed += 1
		print(stdio.color("red") .. "  ✗ " .. name .. stdio.color("reset"))
		print(stdio.color("red") .. "    " .. tostring(err) .. stdio.color("reset"))
		table.insert(results.errors, {
			describe = currentDescribe,
			test = name,
			error = tostring(err),
		})
	end
end

-- Assertions
function assertEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		local msg = message or string.format(
			"Expected %s but got %s",
			formatValue(expected),
			formatValue(actual)
		)
		error(msg, 2)
	end
end

function assertTrue(value: any, message: string?)
	if not value then
		error(message or "Expected true but got " .. formatValue(value), 2)
	end
end

function assertFalse(value: any, message: string?)
	if value then
		error(message or "Expected false but got " .. formatValue(value), 2)
	end
end

function assertNil(value: any, message: string?)
	if value ~= nil then
		error(message or "Expected nil but got " .. formatValue(value), 2)
	end
end

function assertNotNil(value: any, message: string?)
	if value == nil then
		error(message or "Expected non-nil value", 2)
	end
end

function assertApprox(actual: number, expected: number, tolerance: number?, message: string?)
	tolerance = tolerance or 0.001
	if math.abs(actual - expected) > tolerance then
		local msg = message or string.format(
			"Expected %s ≈ %s (tolerance %s)",
			formatValue(actual),
			formatValue(expected),
			formatValue(tolerance)
		)
		error(msg, 2)
	end
end

--------------------------------------------------------------------------------
-- DISCOVER SPEC FILES
--------------------------------------------------------------------------------
local function findSpecFiles(dir: string): { string }
	local specFiles = {}
	
	local success, entries = pcall(fs.readDir, dir)
	if not success then
		return specFiles
	end
	
	for _, entry in entries do
		local path = dir .. "/" .. entry
		local isDir = fs.isDir(path)
		
		if isDir then
			local subFiles = findSpecFiles(path)
			for _, file in subFiles do
				table.insert(specFiles, file)
			end
		elseif entry:match("%.spec%.luau$") then
			-- Keep the fs-relative path for display, convert for require
			table.insert(specFiles, path)
		end
	end
	
	return specFiles
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
local specFiles = findSpecFiles("./src")

if #specFiles == 0 then
	print("No spec files found in src/")
	print("Create test files named *.spec.luau (see AGENTS.md 'Testing Patterns')")
	process.exit(0)
end

-- Load and run each spec file
-- We need to require from THIS script's context, so paths are ../src/...
for _, filePath in specFiles do
	-- Convert ./src/shared/Foo.spec.luau -> ../src/shared/Foo.spec
	local requirePath = filePath:gsub("^%./", "../"):gsub("%.luau$", "")
	
	local success, err = pcall(function()
		require(requirePath)
	end)
	
	if not success then
		results.failed += 1
		print(stdio.color("red") .. "✗ Failed to load: " .. filePath .. stdio.color("reset"))
		print(stdio.color("red") .. "  " .. tostring(err) .. stdio.color("reset"))
	end
end

-- Summary
local total = results.passed + results.failed
local summary = string.format("%d passed, %d failed, %d total", results.passed, results.failed, total)

if results.failed == 0 then
	print(stdio.color("green") .. "✓ All tests passed! " .. summary .. stdio.color("reset"))
else
	print("")
	print(string.rep("─", 50))
	print(stdio.color("red") .. "✗ Tests failed! " .. summary .. stdio.color("reset"))
end

process.exit(results.failed == 0 and 0 or 1)
