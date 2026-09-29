local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
local Player = Framework:GetPlayer()
local Frame = script.Parent
repeat task.wait() until Player:GetAttribute("Loaded")

function ShowRune(Rune_Frame : Frame, Amount : number)
	local HasRune = Amount > 0
	
	if Rune_Frame.Name == "Blizzard" then
		Rune_Frame.Visible = HasRune
		
		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Mirror" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end
	
	if Rune_Frame.Name == "Frostbite" then
		Rune_Frame.Visible = HasRune

		if not HasRune then
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		else
			Frame.CanvasSize = UDim2.new(0, 0, 2, 0)
		end
	end

	if Rune_Frame.Name == "Glint" then
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
	Rune_Frame.Owned.Text = `{EN.Format(Amount, 2)}`
end

--// Main Function \\--
local function Update()
	pcall(function()
		
		if Framework.Gui.Runes.Enabled == false then return end
		
		
		local Amount = Player.Runes.Snowflake.Value
		local Rune_Frame = Frame.Snowflake
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Snowflake_Spheres(Amount))} SPHERES`
		Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Snowflake_Droplets(Amount))} DROPLETS`

		local Amount = Player.Runes.Snow.Value
		local Rune_Frame = Frame.Snow
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Ice.Text = `x{EN.Format(RuneFormulas.Snow_Ice(Amount))} ICE`
		Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Snow_Water(Amount))} WATER`

		local Amount = Player.Runes.Icy.Value
		local Rune_Frame = Frame.Icy
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Spheres.Text = `x{EN.Format(RuneFormulas.Icy_Spheres(Amount))} SPHERE`
		Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Icy_Prisms(Amount))} PRISMS`
		Rune_Frame.Boosts.Chromium.Text = `x{EN.Format(RuneFormulas.Icy_Chromium(Amount))} CHROMIUM`
		
		local Amount = Player.Runes.Avalanche.Value
		local Rune_Frame = Frame.Avalanche
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Avalanche_Water(Amount))} WATER`
		Rune_Frame.Boosts.Ice.Text = `x{EN.Format(RuneFormulas.Avalanche_Ice(Amount))} ICE`
		Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Avalanche_ArcticPoints(Amount))} AP`
		Rune_Frame.Boosts.Icicles.Text = `x{EN.Format(RuneFormulas.Avalanche_Icicles(Amount))} ICICLES`

		local Amount = Player.Runes.Hailstorm.Value
		local Rune_Frame = Frame.Hailstorm
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Chromium.Text = `x{EN.Format(RuneFormulas.Hailstorm_Chromium(Amount))} CHROMIUM`
		Rune_Frame.Boosts.Tickets.Text = `x{EN.Format(RuneFormulas.Hailstorm_Tickets(Amount))} TICKETS`
		
		local Amount = Player.Runes.Frostveil.Value
		local Rune_Frame = Frame.Frostveil
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.Droplets.Text = `x{EN.Format(RuneFormulas.Frostveil_Droplets(Amount))} DROPLETS`
		Rune_Frame.Boosts.Prisms.Text = `x{EN.Format(RuneFormulas.Frostveil_Prisms(Amount))} PRISMS`
		Rune_Frame.Boosts.AP.Text = `x{EN.Format(RuneFormulas.Frostveil_ArcticPoints(Amount))} AP`
		Rune_Frame.Boosts.Icicles.Text = `x{EN.Format(RuneFormulas.Frostveil_Icicles(Amount))} ICICLES`
		
		local Amount = Player.Runes.Subzero.Value
		local Rune_Frame = Frame.SubzeroRune
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Subzero_RuneSpeed(Amount))} RUNE SPEED`
		Rune_Frame.Boosts.Chromium.Text = `x{EN.Format(RuneFormulas.Subzero_Chromium(Amount))} CHROMIUM`
		Rune_Frame.Boosts.Water.Text = `x{EN.Format(RuneFormulas.Subzero_Water(Amount))} WATER`
		
		local Amount = Player.Runes.Blizzard.Value
		local Rune_Frame = Frame.Blizzard
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneBulk.Text = `x{EN.Format(RuneFormulas.Blizzard_RuneBulk(Amount))} RUNE BULK`
		
		local Amount = Player.Runes.Mirror.Value
		local Rune_Frame = Frame.Mirror
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneSpeed1.Text = `x{EN.Format(RuneFormulas.Mirror_RuneSpeed1(Amount))} Rune Speed`
		Rune_Frame.Boosts.RuneSpeed2.Text = `x{EN.Format(RuneFormulas.Mirror_RuneSpeed2(Amount))} Rune Speed`
		
		local Amount = Player.Runes.Frostbite.Value
		local Rune_Frame = Frame.Frostbite
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Frostbite_RuneSpeed(Amount))} Rune Speed`


		local Amount = Player.Runes.Glint.Value
		local Rune_Frame = Frame.Glint
		ShowRune(Rune_Frame, Amount)
		Rune_Frame.Boosts.RuneSpeed.Text = `x{EN.Format(RuneFormulas.Glint_RuneSpeed(Amount))} RS [EXP]`
		Rune_Frame.Boosts.Chrome1.Text = `x{EN.Format(RuneFormulas.Glint_Chrome1(Amount))} Chrome`
		Rune_Frame.Boosts.Chrome2.Text = `x{EN.Format(RuneFormulas.Glint_Chrome2(Amount))} Chrome`
	end)
end

--// Loop \\--
while task.wait(1/8) do
	Update()
end

--Kai