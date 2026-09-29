local Framework = require(game.ReplicatedStorage.Framework)
local Tween_Service = Framework:GetService("TweenService")
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Mobs = Framework:GetLibrary('MobsHandler')
--// Variables \\--
local Mob_Zone = workspace.Areas["Spawn Island"].Map.Bases.Mob_Zone
local Mob_Zone_Base = workspace.Areas["Spawn Island"].Map.Bases.Mob_Zone_Base
local Layer = workspace.Layers.Flesh
local Board = Layer.FleshBoard
local Stat_UI = Layer.Health.HealthUI
local Health_Bar = Stat_UI.Container.Background.Bar :: Frame
local Health_Display = Stat_UI.Container.Background.Health :: TextLabel
local Level_Bar = Layer.LevelBar

--// Animations \\--
local Tween_Info = TweenInfo.new(1/5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false)
local Goal_Highlighted = {Color = Color3.fromRGB(218, 61, 61)}
local Goal_Unhighlighted = {Color = Color3.fromRGB(218, 133, 65)}
local Highlight_Anim = Tween_Service:Create(Mob_Zone, Tween_Info, Goal_Highlighted)
local Unhighlight_Anim = Tween_Service:Create(Mob_Zone, Tween_Info, Goal_Unhighlighted)

local Mobs_Client = {}
--// Player \\--
local Player = Framework:GetPlayer()
local Mobs_Level = Player.Stats.Mobs_Level
local Mobs_SetLevel = Player.Stats.Mobs_SetLevel
local Mobs_Killed = Player.Stats.Mobs_Killed

--// Mob Cache \\--
local Current_Health = 100
local Max_Health = 100
local Respawning = false
local Current_Mob = nil
local Highlighted = false

function Mobs_Client.init()
	
end

function Mobs_Client.Toggle(HasReq : boolean)
	if HasReq then
		Layer.Parent = workspace.Layers
		return
	end
	
	Layer.Parent = game.ReplicatedStorage.Layers_Storage
end

function Mobs_Client.Update(Amount : number)
	Board.SurfaceGui.Main.Amount.Text = EN.Format(Amount)
	Board.SurfaceGui.Main.Multiplier.Text = `x{EN.Format(Formulas.Flesh(Player))} FLESH`
	
	local Current_Level = Mobs_SetLevel.Value
	local Max_Level = Mobs_Level.Value
	local Current_Kills = Mobs_Killed.Value
	local Mobs_Needed = Mobs.GetKillsNeeded(Player)
	
	-- Case 2 | Has Enough Mobs
	Level_Bar.SurfaceGui.Current.Text = `LVL {EN.Format(Current_Level)}`
	Level_Bar.SurfaceGui.Next.Text = `LVL {EN.Format(Current_Level + 1)}`
	
	-- Case 1 | Set Level is under Max or Mobs killed 
	if Current_Level < Max_Level or Current_Kills >= Mobs_Needed then
		Level_Bar.SurfaceGui.Background.Requirement.Text = "Level already passed. Advance when ready!"
		Level_Bar.SurfaceGui.Background.Bar.Size = UDim2.new(0.987,0,0.85,0)
		return
	end
	
	if Current_Level == Max_Level then
		local Percentage = math.clamp(Current_Kills / Mobs_Needed, 0, 0.987)
		Level_Bar.SurfaceGui.Background.Bar.Size = UDim2.new(Percentage,0,0.85,0)
		Level_Bar.SurfaceGui.Background.Requirement.Text = `{EN.Format(Current_Kills)}/{EN.Format(Mobs_Needed)} LVL {Current_Level} MONSTERS KILLED`
		return
	end
	
	if Current_Level >= Max_Level then
		Level_Bar.SurfaceGui.Background.Requirement.Text = "You hacker! How did you get here?? (Easter Egg)"
		Level_Bar.SurfaceGui.Background.Bar.Size = UDim2.new(0.987,0,0.85,0)
		return
	end
end

function Mobs_Client.Respawn(Seconds : number)
	if not Current_Mob then return end
	
	task.spawn(function()
		local Respawning_Mob = Current_Mob
		Respawning_Mob:SetAttribute("Dead", true)
		Current_Mob = nil
		
		local Respawn_Info = TweenInfo.new(Seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false)
		Tween_Service:Create(Respawning_Mob.PrimaryPart, Respawn_Info, {Transparency = 1}):Play()
		for i = 1, Seconds do
			Health_Display.Text = `Respawning in {Seconds - i}s`
			Health_Bar:TweenSize(UDim2.new(math.clamp(i / Seconds,0,.99),0,.9,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true)
			task.wait(1)
		end
		
		Respawning_Mob:Destroy()
		Respawning_Mob = nil
	end)
end

function Mobs_Client.AnimateHP()
	local Percentage = math.clamp(EN.toNumber(EN.div(Current_Health, Max_Health)) , 0 , 0.99)
	Health_Bar:TweenSize(UDim2.new(Percentage,0,.9,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true)
end

function Mobs_Client.UpdateHP()
	Health_Display.Text = `{EN.Format(Current_Health)} / {EN.Format(Max_Health)} HP`
end

function Mobs_Client.Highlight_Zone()
	if Highlighted then return end
	Highlighted = true
	Highlight_Anim:Play()
end

function Mobs_Client.OnDamage()
	if not Current_Mob or not Player.Settings.Particles.Value then return end
	for _ , Emitter in Current_Mob.Mob.VFX:GetChildren() do
		Emitter:Emit(Emitter:GetAttribute("EmitCount"))
	end
end

function Mobs_Client.Summon(Type : number)
	Current_Mob = script[Type]:Clone() :: Model
	Current_Mob.Parent = Layer
end

function Mobs_Client.Unhighlight_Zone()
	if not Highlighted then return end
	Highlighted = false
	Unhighlight_Anim:Play()
end

Framework.Events.Mob_Refresh.OnClientEvent:Connect(function(Data : {})
	Max_Health = Data.Max_Health
	Current_Health = Data.Health
	Mobs_Client.Summon(Data.Type)
	Mobs_Client.UpdateHP()
	Mobs_Client.AnimateHP()
	Stat_UI.Level.Text = `LVL {EN.Format(Data.Level or 1)}`
end)

Framework.Events.Mob_Respawn.OnClientEvent:Connect(function(Timer : number)
	Mobs_Client.Respawn(Timer)
end)

Framework.Events.Mob_Update.OnClientEvent:Connect(function(Data : {})
	Current_Health = Data.Health
	Mobs_Client.UpdateHP()
	Mobs_Client.AnimateHP()
end)

Framework.Events.Mob_Hit.OnClientEvent:Connect(function()
	Mobs_Client.OnDamage()
end)

return Mobs_Client
