local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
local Client_Player = Framework:GetPlayer()
local Setting = Client_Player.Settings.Players

local Hide_Players = {}
local Cache = {}

local StarterGui = game:GetService("StarterGui")

--repeat
--	local success, errorMessage = pcall(function()
--		StarterGui:SetCore("ResetButtonCallback", false)
--	end)

--	wait(0.1)
--until success

function toggleChar(Char : Model)
	if not Setting.Value then
		Char.Parent = nil
		return
	end

	Char.Parent = workspace
end

function onCharAdd(Player : Player, Char : Model)
	Cache[Player.UserId] = Char
end

function onPlayerAdd(Player : Player)
	local Char = Player.Character or Player.CharacterAdded:Wait()
	Char:WaitForChild("HumanoidRootPart")
	onCharAdd(Player, Char)
	toggleChar(Char)

	Player.CharacterAdded:Connect(function(NewChar : Model)
		NewChar:WaitForChild("HumanoidRootPart")
		onCharAdd(Player, NewChar)
		toggleChar(Char)
	end)
end

function Update()
	for _ , Char in Cache do
		toggleChar(Char)
	end
end

function Hide_Players.init()
	for _ , Player in Players:GetPlayers() do
		if Player == Client_Player then continue end
		onPlayerAdd(Player)
	end
	Players.PlayerAdded:Connect(onPlayerAdd)

	Setting:GetPropertyChangedSignal("Value"):Connect(Update)
end

return Hide_Players
