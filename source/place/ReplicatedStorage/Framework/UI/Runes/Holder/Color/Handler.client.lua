local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0

	if Rune_Frame.Name == "BloomRune" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Gleam" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Vanta" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Whirl" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Onyx" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
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
	
	
	local Amount = Player.Runes.Tinted.Value
	local Rune_Frame = Frame.TintedRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Tinted_Energy(Amount))} ENERGY`

	local Amount = Player.Runes.Colorful.Value
	local Rune_Frame = Frame.ColorfulRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Colorful_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Colorful_Flesh(Amount))} FLESH`

	local Amount = Player.Runes.Radiance.Value
	local Rune_Frame = Frame.RadianceRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Radiance_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Radiance_Power(Amount))} POWER`


	local Amount = Player.Runes.Neon.Value
	local Rune_Frame = Frame.NeonRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Neon_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Neon_Damage(Amount))} DMG`
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Neon_RealmPoints(Amount))} RP`


	local Amount = Player.Runes.Chrome.Value
	local Rune_Frame = Frame.ChromeRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Chrome_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Chrome_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Chrome_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Chrome_Prisms(Amount))} PRISMS`


	local Amount = Player.Runes.Rainbow.Value
	local Rune_Frame = Frame.RainbowRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Rainbow_Damage(Amount))} DMG`
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Rainbow_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Rainbow_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Rainbow_RuneLuck(Amount))} RUNE LUCK`


	local Amount = Player.Runes.Vibrance.Value
	local Rune_Frame = Frame.VibranceRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Vibrance_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Vibrance_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Vibrance_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Vibrance_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Vibrance_RuneSpeed(Amount))} RUNE SPEED`
	
	local Amount = Player.Runes.Bloom.Value
	local Rune_Frame = Frame.BloomRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Bloom_Spheres(Amount))} SPHERES`
	

	local Amount = Player.Runes.Gleam.Value
	local Rune_Frame = Frame.Gleam
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Gleam_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Gleam_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Vanta.Value
	local Rune_Frame = Frame.Vanta
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Vanta_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Vanta_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Vanta_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Whirl.Value
	local Rune_Frame = Frame.Whirl
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Whirl_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Whirl_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Onyx.Value
	local Rune_Frame = Frame.Onyx
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Onyx_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Onyx_RuneSpeed2(Amount))} Rune Speed`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
