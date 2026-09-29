local replicatedStorage = game:GetService("ReplicatedStorage")
local runeStarring_EVENT = replicatedStorage.RemoteEvents.rune_Starring

local UI = script.Parent
local Holder = UI.Holder

local Packs = Holder.Packs

local Player = game.Players.LocalPlayer
local Stats = Player:WaitForChild("Stats")
local Runes = Player:WaitForChild("Runes")

local Vibrances = Runes:WaitForChild("Vibrance")
local Subzero = Runes:WaitForChild("Subzero")
local Refraction = Runes:WaitForChild("Refraction")
local Odyssey = Runes:WaitForChild("Odyssey")

local Framework = require(game:GetService("ReplicatedStorage").Framework)
local EN = Framework:GetLibrary("EternityNum")
local runeStarring_Client = Framework:GetClientModule("RuneStarring_Setup")

runeStarring_Client.init()

local function closeFrames()
	for i, v in Holder:GetChildren() do
		if v:IsA("ScrollingFrame") then
			if v.Name == "Packs" then continue end
			v.Visible = false
		end
	end
end

for i, v in Packs:GetChildren() do
	if not v:IsA("TextButton") then continue end
	v.Activated:Connect(function()
		closeFrames()
		Holder:FindFirstChild(v.Name).Visible = true
		
		for i, v in Holder[v.Name]:GetDescendants() do
			if not v:IsA("TextLabel") then continue end
			if v.Name == "Vibrance" then
				v.Text = EN.Format(Vibrances.Value).."/"..v:GetAttribute("Req")
				Vibrances.Changed:Connect(function(AfterValue)
					v.Text = EN.Format(AfterValue).."/"..v:GetAttribute("Req")
				end)
			elseif v.Name == "Subzero" then
				v.Text = EN.Format(Subzero.Value).."/"..v:GetAttribute("Req")
				Subzero.Changed:Connect(function(AfterValue)
					v.Text = EN.Format(AfterValue).."/"..v:GetAttribute("Req")
				end)
			elseif v.Name == "Refraction" then
				v.Text = EN.Format(Refraction.Value).."/"..v:GetAttribute("Req")
				Refraction.Changed:Connect(function(AfterValue)
					v.Text = EN.Format(AfterValue).."/"..v:GetAttribute("Req")
				end)
			elseif v.Name == "Odyssey" then
				v.Text = EN.Format(Odyssey.Value).."/"..v:GetAttribute("Req")
				Odyssey.Changed:Connect(function(AfterValue)
					v.Text = EN.Format(AfterValue).."/"..v:GetAttribute("Req")
				end)
			end

		end
	end)
end

for i, v in Holder:GetDescendants() do
	if not v:IsA("TextButton") then continue end
	if v.Name ~= "Star" then continue end
	v.Activated:Connect(function()
		runeStarring_EVENT:FireServer(v.Parent.Parent.Name)
	end)
end



runeStarring_EVENT.OnClientEvent:Connect(function(Rune, StarStage)
	if not Holder:FindFirstChild(Rune) then return end
	
	local Frame = Holder[Rune]
	local StarFrame = Frame:FindFirstChild(StarStage)
	if not StarFrame then return end
	for i, v in Frame:GetChildren() do
		if not v:IsA("Frame") then continue end
		if v.Name == "Title" then 
			v.Star.Text = "[" .. StarStage .. "]"	
		end
		v.Visible = false
	end
	StarFrame.Visible = true
end)
