local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Time = Framework:GetLibrary("Time")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")


local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	
	if Rune_Frame.Name == "Garmin" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Stray" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Buff" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Bozo" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	

	if Rune_Frame.Name == "Mommy" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Soup" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end

	
	Rune_Frame["???"].Visible = not HasRune
	Rune_Frame["Info"].Visible = not HasRune
	Rune_Frame.Boosts.Visible = HasRune
	Rune_Frame.Owned.Text = `{EN.Format(Amount, 3)}`
end

--// Main Function \\--
local function Update()
	
	if Framework.Gui.Runes.Enabled == false then return end
	
	local Amount = Player.Runes.Mist.Value
	local Rune_Frame = Frame.Mist
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Mist_Spheres(Amount))} SPHERES`
	
	local Amount = Player.Runes.Breeze.Value
	local Rune_Frame = Frame.Breeze
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Breeze_Droplets(Amount))} DROPLETS`
	Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Breeze_Water(Amount))} WATER`
	
	local Amount = Player.Runes.Shiver.Value
	local Rune_Frame = Frame.Shiver
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Shiver_Water(Amount))} WATER`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Shiver_Prisms(Amount))} PRISMS`
	Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Shiver_ArcticPoints(Amount))} AP`
	
	local Amount = Player.Runes.Frigid.Value
	local Rune_Frame = Frame.Frigid
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Frigid_Droplets(Amount))} DROPLETS`
	Rune_Frame.Boosts.Ice.Text = `x{EN.Format(RuneFormulas.Frigid_Ice(Amount))} ICE`
	Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Frigid_ArcticPoints(Amount))} AP`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Frigid_RuneLuck(Amount))} RUNE LUCK`
	

	local Amount = Player.Runes.Icequake.Value
	local Rune_Frame = Frame.Icequake
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Icequake_Water(Amount))} WATER`
	Rune_Frame.Boosts.Ice.Text = `x{EN.Format(RuneFormulas.Icequake_Ice(Amount))} ICE`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Icequake_Prisms(Amount))} PRISMS`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Icequake_Spheres(Amount))} SPHERES`
	Rune_Frame.Boosts.CD.Text = `-{Time(RuneFormulas.Icequake_DropletsCD(Amount))} DROPLETS CD`
	
	local Amount = Player.Runes.Garmin.Value
	local Rune_Frame = Frame.Garmin
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Garmin_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Stray.Value
	local Rune_Frame = Frame.Stray
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Stray_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Stray_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Buff.Value
	local Rune_Frame = Frame.Buff
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets1.Text = `x{EN.Format(RuneFormulas.Buff_Tickets1(Amount))} Tickets`
	Rune_Frame.Boosts.Tickets2.Text = `x{EN.Format(RuneFormulas.Buff_Tickets2(Amount))} Tickets`
	
	local Amount = Player.Runes.Bozo.Value
	local Rune_Frame = Frame.Bozo
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Bozo_RuneSpeed(Amount))} RuneSpeed`
	Rune_Frame.Boosts.BaseChrome.Text = `+{EN.Format(RuneFormulas.Bozo_BaseChrome(Amount))} Base Chrome`
	
	local Amount = Player.Runes.Mommy.Value
	local Rune_Frame = Frame.Mommy
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Mommy_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Reflection.Text = `x{EN.Format(RuneFormulas.Mommy_Reflection(Amount))} Reflection`
	Rune_Frame.Boosts.Shine.Text = `x{EN.Format(RuneFormulas.Mommy_Shine(Amount))} Shine`
	

	local Amount = Player.Runes.Soup.Value
	local Rune_Frame = Frame.Soup
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Soup_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Soup_RuneSpeed2(Amount))} Rune Speed`
	Rune_Frame.Boosts.Shine.Text = `x{EN.Format(RuneFormulas.Soup_Shine(Amount))} Shine`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
