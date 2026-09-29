local Framework = require(game.ReplicatedStorage.Framework)
local Overhead = Framework:GetLibrary("Overhead")

function InitChar(Player : Player, Character : Model)
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	local HRP = Character:WaitForChild("HumanoidRootPart", 10)
	
	for key,value in Character:GetDescendants() do
		if value:IsA("BasePart") then
			value.CollisionGroup = "plrs"
		end
	end
	
	Overhead.New(Player)
	
	Humanoid.Died:Connect(function()
		Player:SetAttribute("Dead", true)
	end)
end

return function(Player : Player)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	InitChar(Player, Character)
	
	--// Spawn Last Location \\--
	local Location = string.split(Player.Stats.Location.Value, ";")
	if tonumber(Location[1]) ~= 0 then
		Character:WaitForChild("HumanoidRootPart").CFrame = CFrame.new(Vector3.new(tonumber(Location[1]),tonumber(Location[2]),tonumber(Location[3])))
	end
	Player:SetAttribute("Location_Ready", true)
	
	Player.CharacterAdded:Connect(function(Character)
		Player:SetAttribute("Dead", false)
		InitChar(Player, Character)
	end)
end