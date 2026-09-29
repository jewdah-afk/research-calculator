local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Eternal" then
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
	pcall(function()
		
		if Framework.Gui.Runes.Enabled == false then return end
		
		
		local Amount = Player.Runes.Almighty.Value
		local Rune_Frame = Frame.AlmightyRune
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.AllStats.Text = `x{EN.Format(RuneFormulas.Almighty_Ice(Amount))} ALL STATS`
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Almighty_RuneSpeed(Amount))} RUNE SPEED`
		Rune_Frame.Boosts.Chromium.Text = `x{EN.Format(RuneFormulas.Almighty_Chromium(Amount))} CHROMIUM`

		local Amount = Player.Runes.Boundless.Value
		local Rune_Frame = Frame.BoundlessRune
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Boundless_RuneBulk(Amount))} RUNE BULK`
		Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Boundless_Tickets(Amount))} TICKETS`
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Boundless_RuneSpeed(Amount))} RUNE SPEED`

		local Amount = Player.Runes.Omnipotent.Value
		local Rune_Frame = Frame.OmnipotentRune
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Boost.Text = `x{EN.Format(RuneFormulas.Omnipotent_Water(Amount))} WATER, AP, ICE`

		local Amount = Player.Runes.Omniscient.Value
		local Rune_Frame = Frame.OmniscientRune
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Boost.Text = `x{EN.Format(RuneFormulas.Omniscient_Spheres(Amount))} SPHERES >> WATER`

		local Amount = Player.Runes.Primordial.Value
		local Rune_Frame = Frame.Primordial
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Primordial_RuneBulk(Amount))} Rune Bulk`
		Rune_Frame.Boosts.Chest.Text = `-{EN.Format(RuneFormulas.Primordial_ChestChance(Amount))} Chest Chance`
		
		local Amount = Player.Runes.Eternal.Value
		local Rune_Frame = Frame.Eternal
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Eternal_RuneBulk(Amount))} Rune Bulk`
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Eternal_RuneSpeed(Amount))} Rune Speed`
		Rune_Frame.Boosts.AllSecret.Text = `x{EN.Format(RuneFormulas.Eternal_AllSecret(Amount))} Secret Stats`
	end)
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
