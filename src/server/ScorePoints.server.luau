-- Score Points Example
-- Players earn 1 point per second while alive. Death resets score to 0.
-- Points display on the built-in leaderboard (top-right corner).
--
-- Based on: docs/creator-docs/tutorials/use-case-tutorials/scripting/basic-scripting/score-points.md

local Players = game:GetService("Players")

local function onCharacterAdded(character: Model, player: Player)
	player:SetAttribute("IsAlive", true)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		local points = player.leaderstats.Points
		points.Value = 0
		player:SetAttribute("IsAlive", false)
	end)
end

local function onPlayerAdded(player: Player)
	-- Create leaderstats folder (required name for built-in leaderboard)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Create Points value
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = 0
	points.Parent = leaderstats

	player:SetAttribute("IsAlive", false)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Award points every second to living players
while true do
	task.wait(1)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("IsAlive") then
			local points = player.leaderstats.Points
			points.Value += 1
		end
	end
end
