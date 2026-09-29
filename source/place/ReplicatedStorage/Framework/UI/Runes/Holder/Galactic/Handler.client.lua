local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	
	if Rune_Frame.Name == "Galaxy" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Axium" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Paracosm" then
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
	
	
	local Amount = Player.Runes.CosmicDust.Value
	local Rune_Frame = Frame.CosmicDust
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.CosmicDust_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.CosmicDust_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Star.Value
	local Rune_Frame = Frame.Star
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Star_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Star_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Constellation.Value
	local Rune_Frame = Frame.Constellation
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `x{EN.Format(RuneFormulas.Constellation_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Constellation_RuneBulk2(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Planet.Value
	local Rune_Frame = Frame.Planet
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `+{EN.Format(RuneFormulas.Planet_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `^{EN.Format(RuneFormulas.Planet_RuneBulk2(Amount), 5)} Rune Bulk`

	local Amount = Player.Runes.Rocket.Value
	local Rune_Frame = Frame.Rocket
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Rocket_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Rocket_Tickets(Amount))} Tickets`

	local Amount = Player.Runes.Galaxy.Value
	local Rune_Frame = Frame.Galaxy
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Chroma.Text = `x{EN.Format(RuneFormulas.Galaxy_Chroma(Amount))} Chroma`
	Rune_Frame.Boosts.Light.Text = `x{EN.Format(RuneFormulas.Galaxy_Light(Amount))} Light`
	
	local Amount = Player.Runes.Axium.Value
	local Rune_Frame = Frame.Axium
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Chroma.Text = `x{EN.Format(RuneFormulas.Axium_Chroma(Amount))} Chroma`
	Rune_Frame.Boosts.Light.Text = `x{EN.Format(RuneFormulas.Axium_Light(Amount))} Light`
	Rune_Frame.Boosts.Reflection.Text = `x{EN.Format(RuneFormulas.Axium_Reflection(Amount))} Reflection`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Axium_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Paracosm.Value
	local Rune_Frame = Frame.Paracosm
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Light.Text = `x{EN.Format(RuneFormulas.Paracosm_Light(Amount))} Light`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Paracosm_RuneSpeed(Amount))} Rune Speed`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
