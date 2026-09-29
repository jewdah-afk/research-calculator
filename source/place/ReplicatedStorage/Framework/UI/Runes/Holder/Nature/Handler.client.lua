local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Thorn" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Squid" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Cyclone" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end


	if Rune_Frame.Name == "Bolt" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Riptide" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Torrent" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Hurricane" then
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
	
	
	local Amount = Player.Runes.Oak.Value
	local Rune_Frame = Frame.OakRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Oak_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Oak_Power(Amount))} POWER`
	
	local Amount = Player.Runes.Moss.Value
	local Rune_Frame = Frame.MossRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Moss_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Moss_Damage(Amount))} DMG`
	
	local Amount = Player.Runes.Dew.Value
	local Rune_Frame = Frame.DewRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Dew_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Dew_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Dew_RealmPoints(Amount))} RP`
	
	local Amount = Player.Runes.Skylight.Value
	local Rune_Frame = Frame.SkylightRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Skylight_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Skylight_Power(Amount))} POWER`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Skylight_Prisms(Amount))} PRISMS`
	
	local Amount = Player.Runes.Nightshade.Value
	local Rune_Frame = Frame.NightshadeRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Nightshade_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Nightshade_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Nightshade_Spheres(Amount))} SPHERES`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Nightshade_Flesh(Amount))} FLESH`
	
	local Amount = Player.Runes.Wavecaller.Value
	local Rune_Frame = Frame.WavecallerRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Wavecaller_Power(Amount))} POWER`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Wavecaller_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Wavecaller_Spheres(Amount))} SPHERES`
	
	local Amount = Player.Runes.Thunderstorm.Value
	local Rune_Frame = Frame.ThunderstormRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Thunderstorm_Energy(Amount))} ENERGY>>POWER`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Thunderstorm_Damage(Amount))} DMG`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Thunderstorm_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Thunderstorm_Orbs(Amount))} ORBS`
	
	local Amount = Player.Runes.Earthvein.Value
	local Rune_Frame = Frame.EarthveinRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Earthvein_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Earthvein_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Earthvein_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Earthvein_RuneSpeed(Amount))} RUNE SPEED`
	
	local Amount = Player.Runes.Emberglow.Value
	local Rune_Frame = Frame.EmberglowRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Emberglow_Flame(Amount))} FLAME`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Emberglow_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Emberglow_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Emberglow_RuneBulk(Amount))} RUNE BULK`
	
	local Amount = Player.Runes.Dreamscape.Value
	local Rune_Frame = Frame.DreamscapeRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Dreamscape_Energy(Amount))} ENERGY`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Dreamscape_Damage(Amount))} DMG`
	Rune_Frame.Boosts.SPHERES.Text = `x{EN.Format(RuneFormulas.Dreamscape_Spheres(Amount))} SPHERES`
	

	local Amount = Player.Runes.Thorn.Value
	local Rune_Frame = Frame.Thorn
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Thorn_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Thorn_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Squid.Value
	local Rune_Frame = Frame.Squid
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Squid_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Squid_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Cyclone.Value
	local Rune_Frame = Frame.Cyclone
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `+^{EN.Format(RuneFormulas.Cyclone_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Cyclone_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Bolt.Value
	local Rune_Frame = Frame.Bolt
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `x{EN.Format(RuneFormulas.Bolt_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Bolt_RuneBulk2(Amount))} Rune Bulk`
	

	local Amount = Player.Runes.Riptide.Value
	local Rune_Frame = Frame.Riptide
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Riptide_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Riptide_RuneSpeed2(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Riptide_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Torrent.Value
	local Rune_Frame = Frame.Torrent
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Torrent_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Hurricane.Value
	local Rune_Frame = Frame.Hurricane
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Hurricane_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.Light.Text = `x{EN.Format(RuneFormulas.Hurricane_Light(Amount))} Light`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
