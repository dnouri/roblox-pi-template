-- Deadly Lava
-- Any part named "Lava" kills players on touch.
-- Works with parts that exist at startup or are created later by other scripts.

local Workspace = game:GetService("Workspace")

local function setupLava(lava: BasePart)
	lava.Touched:Connect(function(otherPart)
		local character = otherPart.Parent
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
end

-- Setup any existing Lava parts
for _, child in Workspace:GetChildren() do
	if child.Name == "Lava" and child:IsA("BasePart") then
		setupLava(child)
	end
end

-- Also listen for Lava parts added later
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Lava" and child:IsA("BasePart") then
		setupLava(child)
	end
end)
