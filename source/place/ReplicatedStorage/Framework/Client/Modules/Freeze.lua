local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()
local Freeze_Tiers = Framework:GetEvent("Freeze_Tiers")

--// Layer \\--
local Obj = workspace.Areas.Arctic.Freeze

local module = {}
local Active = false

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Obj.Parent = workspace.Areas.Arctic
		return
	end
	if not HasReq then
		Active = false
		Obj.Parent = game.ReplicatedStorage.Layers_Storage
	end
end

--[ Freeze Board Visual ]--
local FreezeBoard = Obj.FreezeBoard

function HideAll()
	for _, v in FreezeBoard.SurfaceGui.Main.Content:GetChildren() do
		if v:IsA("Frame") then
			v.Visible = false
			v.Buy.MouseButton1Click:Connect(function()
				Freeze_Tiers:FireServer(v.Name)
			end)
		end
	end
end

function ShowTiers(Number: number)
	HideAll()
	for i = 1,Number+1 do
		local Tier = FreezeBoard.SurfaceGui.Main.Content:FindFirstChild(tostring(i))
		if Tier then
			Tier.Visible = true
		end
	end
end

ShowTiers(Player.Stats.Tier_Freeze.Value)
Player.Stats.Tier_Freeze:GetPropertyChangedSignal("Value"):Connect(function()
	ShowTiers(Player.Stats.Tier_Freeze.Value)
end)

return module 