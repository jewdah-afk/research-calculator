local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Vehemence" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Malevolence" then
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
	Rune_Frame.Owned.Text = `{EN.Format(Amount)}`
end

--// Main Function \\--
local function Update()
	
	if Framework.Gui.Runes.Enabled == false then return end
	
	
	local Amount = Player.Runes.Mad.Value
	local Rune_Frame = Frame.Mad
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Mad_Orbs(Amount))} Orbs`
	Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Mad_Spheres(Amount))} Spheres`
	
	local Amount = Player.Runes.Rage.Value
	local Rune_Frame = Frame.Rage
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Rage_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Rage_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.Chroma.Text = `x{EN.Format(RuneFormulas.Rage_Chroma(Amount))} Chroma`

	local Amount = Player.Runes.Violence.Value
	local Rune_Frame = Frame.Violence
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Chroma.Text = `x{EN.Format(RuneFormulas.Violence_Chroma(Amount))} Chroma`
	Rune_Frame.Boosts.Light.Text = `x{EN.Format(RuneFormulas.Violence_Light(Amount))} Light`
	Rune_Frame.Boosts.Reflection.Text = `x{EN.Format(RuneFormulas.Violence_Reflection(Amount))} Reflection`
	
	local Amount = Player.Runes.Vehemence.Value
	local Rune_Frame = Frame.Vehemence
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.AllSecret.Text = `x{EN.Format(RuneFormulas.Vehemence_AllSecret(Amount))} Secret Stats`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Vehemence_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Malevolence.Value
	local Rune_Frame = Frame.Malevolence
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.AllSecret.Text = `x{EN.Format(RuneFormulas.Malevolence_AllSecret(Amount))} Secret Stats`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Malevolence_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.Rtoken.Text = `-{EN.Format(RuneFormulas.Malevolence_RobuxTokenCD(Amount))} RT Cooldown`

end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
