local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	
	if Rune_Frame.Name == "Kingslayer" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Divinity" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Prosperity" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Immortality" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	

	if Rune_Frame.Name == "Odyssey" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Destiny" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	

	if Rune_Frame.Name == "Triarch" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Liberty" then
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
	
	
	local Amount = Player.Runes.Gilded.Value
	local Rune_Frame = Frame.Gilded
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Gilded_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Gilded_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Gilded_Droplets(Amount))} Droplets`


	local Amount = Player.Runes.Royalty.Value
	local Rune_Frame = Frame.Royalty
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Flame.Text = `x{EN.Format(RuneFormulas.Royalty_Flame(Amount))} Flame`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Royalty_RuneLuck(Amount))} RuneLuck`


	local Amount = Player.Runes.Crown.Value
	local Rune_Frame = Frame.Crown
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Crown_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Crown_Prisms(Amount))} Prisms`
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Crown_RuneBulk(Amount))} Rune Bulk`


	local Amount = Player.Runes.Throne.Value
	local Rune_Frame = Frame.Throne
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Throne_Tickets(Amount))} Tickets`
	Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Throne_ArcticPoints(Amount))} AP`

	local Amount = Player.Runes.Monarch.Value
	local Rune_Frame = Frame.Monarch
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Monarch_Droplets(Amount))} Droplets`
	Rune_Frame.Boosts.Energy.Text = `x{EN.Format(RuneFormulas.Monarch_Energy(Amount))} Energy`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Monarch_Tickets(Amount))} Tickets`


	local Amount = Player.Runes.Imperial.Value
	local Rune_Frame = Frame.Imperial
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Imperial_Orbs(Amount))} Orbs`
	Rune_Frame.Boosts.Chromium.Text = `x{EN.Format(RuneFormulas.Imperial_Chromium(Amount))} Chromium`
	Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Imperial_Tickets(Amount))} Tickets`
	
	local Amount = Player.Runes.Sovereign.Value
	local Rune_Frame = Frame.Sovereign
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.TicketChance.Text = `-1/{EN.Format(RuneFormulas.Sovereign_TicketChance(Amount))} Ticket Chance`
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Sovereign_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Kingslayer.Value
	local Rune_Frame = Frame.Kingslayer
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Orbs.Text = `x{EN.Format(RuneFormulas.Kingslayer_Orbs(Amount))} Orbs`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Kingslayer_RuneLuck(Amount))} Rune Luck`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Kingslayer_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Divinity.Value
	local Rune_Frame = Frame.Divinity
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `+{EN.Format(RuneFormulas.Divinity_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneLuck.Text = `x{EN.Format(RuneFormulas.Divinity_RuneLuck(Amount))} Rune Luck`
	
	local Amount = Player.Runes.Prosperity.Value
	local Rune_Frame = Frame.Prosperity
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.Chest.Text = `-{EN.Format(RuneFormulas.Prosperity_ChestChance(Amount))} Chest Chance`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Prosperity_RuneSpeed(Amount))} Rune Speed`
	

	local Amount = Player.Runes.Immortality.Value
	local Rune_Frame = Frame.Immortality
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Immortality_RuneBulk(Amount))} Rune Bulk`
	
	local Amount = Player.Runes.Odyssey.Value
	local Rune_Frame = Frame.Odyssey
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk1.Text = `x{EN.Format(RuneFormulas.Odyssey_RuneBulk1(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneBulk2.Text = `x{EN.Format(RuneFormulas.Odyssey_RuneBulk2(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Odyssey_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Destiny.Value
	local Rune_Frame = Frame.Destiny
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Destiny_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Destiny_RuneSpeed(Amount))} Rune Speed`
	
	local Amount = Player.Runes.Triarch.Value
	local Rune_Frame = Frame.Triarch
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Triarch_RuneSpeed1(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Triarch_RuneSpeed2(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneSpeed3.Text = `x{EN.Format(RuneFormulas.Triarch_RuneSpeed3(Amount))} Rune Speed`

	local Amount = Player.Runes.Liberty.Value
	local Rune_Frame = Frame.Liberty
	ShowRune(Rune_Frame, Amount)
	Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Liberty_RuneSpeed(Amount))} Rune Speed`
	Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Liberty_RuneBulk(Amount))} Rune Bulk`
	Rune_Frame.Boosts.Hail.Text = `x{EN.Format(RuneFormulas.Liberty_Hail(Amount))} Hail`
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end
