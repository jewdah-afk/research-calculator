local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Etherborn" then
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
	
	
	local Amount = Player.Runes.Lightmatter.Value
	local Rune_Frame = Frame.LightmatterRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Boost.Text = `x{EN.Format(RuneFormulas.Lightmatter_Energy(Amount))} ENERGY >> FLESH`

	local Amount = Player.Runes.Darkmatter.Value
	local Rune_Frame = Frame.DarkmatterRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.AllStats.Text = `x{EN.Format(RuneFormulas.Darkmatter_Energy(Amount))} ALL STATS`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Darkmatter_Tickets(Amount))} TICKETS`

	local Amount = Player.Runes.Antimatter.Value
	local Rune_Frame = Frame.AntimatterRune
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Antimatter_RuneBulk(Amount))} RUNE BULK`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Antimatter_RuneLuck(Amount))} RUNE LUCK`
	Rune_Frame.Boosts.TicketChance.Text = `-1/{EN.Format(RuneFormulas.Antimatter_TicketChance(Amount))} TICKET CHANCE`
	
	local Amount = Player.Runes.Etherborn.Value
	local Rune_Frame = Frame.Etherborn
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Etherborn_RuneSpeed(Amount))} RUNE SPEED`
	Rune_Frame.Boosts.RToken.Text = `-{EN.Format(RuneFormulas.Etherborn_RobuxTokenCD(Amount))} RTOKEN CD`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
