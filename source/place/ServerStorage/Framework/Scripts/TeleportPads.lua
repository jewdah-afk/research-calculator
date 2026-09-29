local Framework = require(game.ReplicatedStorage.Framework)
local Collection_Service = Framework:GetService("CollectionService")
local Players = Framework:GetService("Players")
local Tween_Service = Framework:GetService("TweenService")

local TeleportPads = {}

local PhaseInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BufferInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TeleportInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Goal = {Transparency = 0}

function PhaseIn(Char : Model)
	for _ , v in Char:GetChildren() do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "HumanoidRootPart" then
			local Tween = Tween_Service:Create(v, PhaseInfo, {Transparency = 0})
			Tween:Play()
		end
	end
end

function PhaseOut(Char : Model)
	for _ , v in Char:GetChildren() do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "HumanoidRootPart" then
			local Tween = Tween_Service:Create(v, PhaseInfo, {Transparency = 1})
			Tween:Play()
		end
	end
end

function Add(TeleportPad : Model)
	TeleportPad.PrimaryPart.Touched:Connect(function(hit)
		local Char = hit.Parent
		local HRP = Char:FindFirstChild("HumanoidRootPart")
		if not HRP then return end
		local Player = Players:GetPlayerFromCharacter(Char)
		if Player:GetAttribute("Teleporting") then return end
		Player:SetAttribute("Teleporting", true)
		
		HRP.Anchored = true
		local Tween = Tween_Service:Create(HRP, BufferInfo, {CFrame = CFrame.new(HRP.Position + Vector3.new(0,10,0))})
		Tween:Play()
		Tween.Completed:Wait()
		
		PhaseOut(Char)
		task.wait(.25)
		HRP.CFrame = CFrame.new(TeleportPad:GetAttribute("TeleportCords") + Vector3.new(0,10,0))
		PhaseIn(Char)
		
		--local Tween = Tween_Service:Create(HRP, TeleportInfo, {CFrame = CFrame.new(TeleportPad:GetAttribute("TeleportCords"))})
		--Tween:Play()
		--Tween.Completed:Wait()
		
		local Tween = Tween_Service:Create(HRP, BufferInfo, {CFrame = CFrame.new(HRP.Position - Vector3.new(0,10,0))})
		Tween:Play()
		Tween.Completed:Wait()
		
		
		HRP.Anchored = false
		Player:SetAttribute("Teleporting", false)
	end)
end

function TeleportPads.init()
	Collection_Service:GetInstanceAddedSignal("Teleporters"):Connect(Add)
	for _ , TeleportPad in Collection_Service:GetTagged("Teleporters") do
		Add(TeleportPad)
	end
end

return TeleportPads
