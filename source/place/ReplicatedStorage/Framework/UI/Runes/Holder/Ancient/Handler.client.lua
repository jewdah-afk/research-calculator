local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Omen" then
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
	
	local Amount = Player.Runes.Dust.Value
	local Rune_Frame = Frame.Dust
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Dust_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Dust_Prisms(Amount))} Prisms`
	
	local Amount = Player.Runes.Bone.Value
	local Rune_Frame = Frame.Bone
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Bone_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Bone_Orbs(Amount))} Orbs`

	local Amount = Player.Runes.Glyph.Value
	local Rune_Frame = Frame.Glyph
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Glyph_Droplets(Amount))} Droplets`
	Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Glyph_ArcticPoints(Amount))} AP`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Glyph_RuneSpeed(Amount))} Rune Speed`

	local Amount = Player.Runes.Sigil.Value
	local Rune_Frame = Frame.Sigil
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Sigil_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Sigil_RuneLuck(Amount))} Rune Luck`
	
	local Amount = Player.Runes.Ankh.Value
	local Rune_Frame = Frame.Ankh
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Ankh_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.TicketChance.Text = `-1/{EN.Format(RuneFormulas.Ankh_TicketChance(Amount))} Ticket Chance`
	Rune_Frame.Boosts.Chest.Text = `-{EN.Format(RuneFormulas.Ankh_ChestChance(Amount))} Chest Chance`
	
	local Amount = Player.Runes.Omen.Value
	local Rune_Frame = Frame.Omen
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Omen_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Omen_RuneBulk(Amount))} Rune Bulk`

end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
