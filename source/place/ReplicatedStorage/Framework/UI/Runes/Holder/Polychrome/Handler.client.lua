local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Time = Framework:GetLibrary("Time")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Aether" then
		Rune_Frame.Visible = HasRune
		
		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Vexed" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Abyssium" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Oscillon" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Oblivion" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end


	if Rune_Frame.Name == "Zephyr" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Raze" then
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
	
	
	local Amount = Player.Runes.Glow.Value
	local Rune_Frame = Frame.Glow
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Glow_Energy(Amount))} ENERGY`
	
	local Amount = Player.Runes.Shimmer.Value
	local Rune_Frame = Frame.Shimmer
	ShowRune(Rune_Frame, Amount)
	
	local Boost = RuneFormulas.Shimmer_Prisms(Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Shimmer_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Shimmer_Spheres(Amount))} SPHERES`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Shimmer_Prisms(Amount), 5)} PRISMS`
	
	local Amount = Player.Runes.Iridium.Value
	local Rune_Frame = Frame.Iridium
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Iridium_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Iridium_Orbs(Amount))} ORBS`
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Iridium_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Iridium_RuneLuck(Amount), 5)} RUNE LUCK`
	

	local Amount = Player.Runes.Spectrum.Value
	local Rune_Frame = Frame.Spectrum
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flesh.Text = `x{EN.Format(RuneFormulas.Spectrum_Flesh(Amount))} FLESH`
	Rune_Frame.Boosts.Prisms.Text = `x{ EN.Format(RuneFormulas.Spectrum_Prisms(Amount),2)} PRISMS`
	
	local TimeElapsed = math.clamp(60 - (tick() - (Player:GetAttribute("AutoTalents") or 0)), 0, 60)
	Rune_Frame.Boosts.Cd.Text = string.format("[%.2fs]", TimeElapsed)
	

	local Amount = Player.Runes.Prismatic.Value
	local Rune_Frame = Frame.Prismatic
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Prismatic_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.Ticket.Text = `x{EN.Format(RuneFormulas.Prismatic_Tickets(Amount))} TICKETS`
	Rune_Frame.Boosts.Walkspeed.Text = `+{EN.Format(RuneFormulas.Prismatic_Walkspeed(Amount))} WALKSPEED`
	Rune_Frame.Boosts.Bulk.Text = `+{EN.Format(RuneFormulas.Prismatic_RuneBulk(Amount))} RUNE BULK`


	local Amount = Player.Runes.Refraction.Value
	local Rune_Frame = Frame.Refraction
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Refraction_Prisms(Amount))} PRISMS`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Refraction_RuneSpeed(Amount))} RUNE SPEED`
	Rune_Frame.Boosts.RToken.Text = `-{Time(RuneFormulas.Refraction_RobuxTokenCD(Amount))} RTOKEN CD`
	Rune_Frame.Boosts.Chest.Text = `-{EN.Format(RuneFormulas.Refraction_ChestChance(Amount))} CHEST SPAWN CHANCE`

	local Amount = Player.Runes.Aether.Value
	local Rune_Frame = Frame.Aether
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Aether_RuneLuck(Amount), 4)} RUNE LUCK`
	
	local Amount = Player.Runes.Vexed.Value
	local Rune_Frame = Frame.Vexed
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Vexed_Tickets(Amount))} TICKETS`
	
	local Amount = Player.Runes.Abyssium.Value
	local Rune_Frame = Frame.Abyssium
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Abyssium_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Abyssium_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Oscillon.Value
	local Rune_Frame = Frame.Oscillon
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Oscillon_RuneLuck(Amount))} Rune Luck`
	Rune_Frame.Boosts.RuneBulk.Text = `^{EN.Format(RuneFormulas.Oscillon_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Oblivion.Value
	local Rune_Frame = Frame.Oblivion
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Oblivion_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Zephyr.Value
	local Rune_Frame = Frame.Zephyr
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Zephyr_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Zephyr_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Raze.Value
	local Rune_Frame = Frame.Raze
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Raze_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Raze_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Chrome.Text = `x{EN.Format(RuneFormulas.Raze_Chrome(Amount))} Chrome`
		
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end