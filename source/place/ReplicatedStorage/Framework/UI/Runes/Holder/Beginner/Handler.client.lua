local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	
	if Rune_Frame.Name == "Superstar" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Overlord" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Sorcerer" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Vanguard" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Hyperion" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	local HasRune = Amount > 0
	Rune_Frame["???"].Visible = not HasRune
	Rune_Frame["Info"].Visible = not HasRune
	Rune_Frame.Boosts.Visible = HasRune
	Rune_Frame.Owned.Text = `{EN.Format(Amount, 3)}`
end


--// Main Function \\--
local function Update()
	
	if Framework.Gui.Runes.Enabled == false then return end
	
	
	local Amount = Player.Runes.Noob.Value
	local Rune_Frame = Frame.Noob
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Noob_Energy(Amount))} Energy`


	local Amount = Player.Runes.Intermediate.Value
	local Rune_Frame = Frame.Intermediate
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Intermediate_Flame(Amount))} Flame`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Intermediate_Tickets(Amount))} Tickets`


	local Amount = Player.Runes.Experienced.Value
	local Rune_Frame = Frame.Experienced
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Experienced_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Experienced_Power(Amount))} Power`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Experienced_Damage(Amount))} DMG`


	local Amount = Player.Runes.Master.Value
	local Rune_Frame = Frame.Master
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Master_Flame(Amount))} Flame`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Master_Flesh(Amount))} Flesh`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Master_RuneLuck(Amount))} Rune Luck`
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Master_Droplets(Amount))} Droplets`

	local Amount = Player.Runes.Champion.Value
	local Rune_Frame = Frame.Champion
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Champion_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Champion_Orbs(Amount))} Orbs`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Champion_Prisms(Amount))} Prisms`


	local Amount = Player.Runes.Legend.Value
	local Rune_Frame = Frame.Legend
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Legend_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Legend_Spheres(Amount))} Spheres`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Legend_Flesh(Amount))} Flesh`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Legend_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Elite.Value
	local Rune_Frame = Frame.Elite
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Elite_Orbs(Amount))} Orbs`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Elite_Prisms(Amount))} Prisms`
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Elite_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Superstar.Value
	local Rune_Frame = Frame.Superstar
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Superstar_Energy(Amount))} Energy`
	
	local Amount = Player.Runes.Overlord.Value
	local Rune_Frame = Frame.Overlord
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Overlord_Energy(Amount))} Energy`
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Overlord_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Sorcerer.Value
	local Rune_Frame = Frame.Sorcerer
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Sorcerer_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Sorcerer_RuneSpeed2(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Sorcerer_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Vanguard.Value
	local Rune_Frame = Frame.Vanguard
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Vanguard_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Vanguard_RuneSpeed2(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneBulk1.Text = `x{EN.Format(RuneFormulas.Vanguard_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Vanguard_RuneBulk2(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Hyperion.Value
	local Rune_Frame = Frame.Hyperion
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Hyperion_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Chroma1.Text = `x{EN.Format(RuneFormulas.Hyperion_Chroma1(Amount))} Chroma`
	Rune_Frame.Boosts.Chroma2.Text = `x{EN.Format(RuneFormulas.Hyperion_Chroma2(Amount))} Chroma`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
