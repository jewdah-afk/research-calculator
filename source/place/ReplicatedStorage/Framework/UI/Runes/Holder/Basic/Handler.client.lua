local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	
	if Rune_Frame.Name == "Mystery" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	

	if Rune_Frame.Name == "HyperFinality" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Shyft" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Array" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	

	if Rune_Frame.Name == "Disarray" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Apex" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Strix" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Nexus" then
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
	
	
	local Amount = Player.Runes.Basic.Value
	local Rune_Frame = Frame.BasicRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Basic_Energy(Amount))} Energy`


	local Amount = Player.Runes.Unique.Value
	local Rune_Frame = Frame.UniqueRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Unique_Energy(Amount))} Energy`


	local Amount = Player.Runes.Rare.Value
	local Rune_Frame = Frame.RareRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Rare_Flame(Amount))} Flame`


	local Amount = Player.Runes.Ascendant.Value
	local Rune_Frame = Frame.AscendantRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Ascendant_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Ascendant_Flame(Amount))} Flame`

	local Amount = Player.Runes.Exotic.Value
	local Rune_Frame = Frame.ExoticRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Exotic_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Exotic_Flame(Amount))} Flame`
	Rune_Frame.Boosts.Power.Text = `x{EN.Format(RuneFormulas.Exotic_Power(Amount))} Power`


	local Amount = Player.Runes.Unknown.Value
	local Rune_Frame = Frame.UnknownRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RP.Text = `x{EN.Format(RuneFormulas.Unknown_RealmPoints(Amount))} RP`
	Rune_Frame.Boosts.DMG.Text = `x{EN.Format(RuneFormulas.Unknown_Damage(Amount))} DMG`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Unknown_RuneLuck(Amount))} RUNE LUCK`
	
	local Amount = Player.Runes.Mystery.Value
	local Rune_Frame = Frame.Mystery
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Mystery_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RToken.Text = `-{EN.Format(RuneFormulas.Mystery_RobuxTokenCD(Amount))} RTOKEN CD`

	local Amount = Player.Runes.HyperFinality.Value
	local Rune_Frame = Frame.HyperFinality
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.HyperFinality_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Shyft.Value
	local Rune_Frame = Frame.Shyft
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Shyft_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Walkspeed.Text = `+{EN.Format(RuneFormulas.Shyft_Walkspeed(Amount))} Walkspeed`
	
	local Amount = Player.Runes.Array.Value
	local Rune_Frame = Frame.Array
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `+{EN.Format(RuneFormulas.Array_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Array_RuneBulk2(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Array_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Disarray.Value
	local Rune_Frame = Frame.Disarray
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `+{EN.Format(RuneFormulas.Disarray_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Disarray_RuneBulk2(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Apex.Value
	local Rune_Frame = Frame.Apex
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Apex_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Apex_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Strix.Value
	local Rune_Frame = Frame.Strix
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Strix_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Nexus.Value
	local Rune_Frame = Frame.Nexus
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Chrome.Text = `x{EN.Format(RuneFormulas.Nexus_Chrome(Amount))} Chrome`
	
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
