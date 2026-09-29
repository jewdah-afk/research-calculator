local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()
local Upgrade_Spheres = Framework:GetEvent("Upgrade_Spheres")
--// Layer \\--
local Obj = workspace.Layers.Spheres
local Board = Obj.Milestones
local Ascender = Obj.Ascender

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		Obj.Parent = workspace.Layers
		return
	end
	Obj.Parent = game.ReplicatedStorage.Layers_Storage
end

function module.Update()
	local Sphere_Level = Player.Stats.Sphere_Levels.Value
	local Spheres = Player.Stats.Spheres.Value
	
	Board.SurfaceGui.Main.Amount.Text = `{EN.Format(Player.Stats.Spheres.Value)}`
	
	--[ Update Milestones ]--
	for _ , Milestone in Board.SurfaceGui.Main.Milestones:GetChildren() do
		if Milestone.ClassName ~= "Frame" then continue end
		
		local AscensionOne_Req = Milestone:GetAttribute("AscensionOne_Req") or false
		local Unlocked = true
		if AscensionOne_Req then
			Unlocked = AscensionOne_Req and Player.Stats.AscensionOne.Value
		end
		
		Milestone.Visible = Unlocked
		
		if EN.meeq(Spheres, Milestone:GetAttribute("Requirement") or 0) then
			Milestone.Gradient.Color = script.Unlocked.Color
		else
			Milestone.Gradient.Color = script.Locked.Color
		end
	end
	
	--[ Update Ascender ]--
	local Cost = Formulas.Spheres_Cost(Player)
	local Rate = Cooldowns.Spheres(Player)
	local Gain = Formulas.Spheres(Player)
	local CurrentEffect = Formulas.Spheres_Spheres(Sphere_Level)
	local NextEffect = Formulas.Spheres_Spheres(Sphere_Level + 1)
	Ascender.Part.SurfaceGui.Price.Text = `{EN.Format(Cost)} SPHERES`
	Ascender.Part.SurfaceGui.SphereMulti.Text = `x{EN.Format(CurrentEffect)} >> x{EN.Format(NextEffect)} SPHERES`
	Ascender.Part.SurfaceGui.Spheres.Text = `+{EN.Format(Gain)} SPHERES / {EN.Format(Rate)}S`
end

Ascender.Part.SurfaceGui.Buy.Activated:Connect(function()
	Upgrade_Spheres:FireServer()
end)

return module
