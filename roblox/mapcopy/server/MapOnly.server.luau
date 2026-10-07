--!strict
-- Peckwood map-only copy: builds the Park island at runtime and drops the player on it.
-- How the map is made: ReplicatedStorage.Peckwood.MapData (the tile grid + scenery positions)
-- -> ServerScriptService.Peckwood.Island (per-tile grass/dirt/sand tops, soil columns, ragged floating underside,
-- studs on grass, scenery models from ReplicatedStorage.Peckwood.Models).
local Island = require(script.Parent:WaitForChild("Island"))
local map = Island.build()
local Players = game:GetService("Players")
local function place(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	task.wait()
	hrp.CFrame = CFrame.new(Island.tileCenter(12, 10) + Vector3.new(0, 8, 0))
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(place) end)
for _, p in Players:GetPlayers() do if p.Character then place(p.Character) end; p.CharacterAdded:Connect(place) end
print("Peckwood map built:", #map:GetDescendants(), "instances")
