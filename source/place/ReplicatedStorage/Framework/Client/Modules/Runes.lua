local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Rune_Class = Framework:GetLibrary("Runes")
local Time = Framework:GetLibrary("Time")
--// Player \\--
local Player = Framework:GetPlayer()
local Energy = Player.Stats.Energy
--// Runes \\--
local Basic = workspace.Areas["Spawn Island"].Basic
local Cyro = workspace.Areas.Arctic.Cryo
local ArcticRune = workspace.Areas.Arctic.Arctic
local Basic_RPS_Display = Basic.RuneUI.BillboardGui.Display.RPS
local Basic_Afford_Display = Basic.RuneUI2.BillboardGui.Display
local Color = workspace.Areas["Spawn Island"].Color
local Color_RPS_Display = Color.RuneUI.BillboardGui.Display.RPS
local Color_Afford_Display = Color.RuneUI2.BillboardGui.Display
local Nature = workspace.Areas["Spawn Island"].Nature
local Nature_RPS_Display = Nature.RuneUI.BillboardGui.Display.RPS
local Nature_Afford_Display = Nature.RuneUI2.BillboardGui.Display

local Polychrome = workspace.Areas["Spawn Island"].Polychrome
local Polychrome_RPS_Display = Polychrome.RuneUI.BillboardGui.Display.RPS
local Polychrome_Afford_Display = Polychrome.RuneUI2.BillboardGui.Display

local Beginner = workspace.Areas["Spawn Island"].Beginner
local Beginner_RPS_Display = Beginner.RuneUI.BillboardGui.Display.RPS
local Beginner_Afford_Display = Beginner.RuneUI2.BillboardGui.Display

local Royal = workspace.Areas["Spawn Island"].Royal
local Royal_RPS_Display = Royal.RuneUI.BillboardGui.Display.RPS
local Royal_Afford_Display = Royal.RuneUI2.BillboardGui.Display

local Galactic = workspace.Areas["Spawn Island"].Galactic
local Galactic_RPS_Display = Galactic.RuneUI.BillboardGui.Display.RPS
local Galactic_Afford_Display = Galactic.RuneUI2.BillboardGui.Display

local Cyro = workspace.Areas.Arctic.Cryo
local Cyro_Afford_Display = Cyro.RuneUI2.BillboardGui.Display
local Cyro_RPS_Display = Cyro.RuneUI.BillboardGui.Display.RPS

local Arctic = workspace.Areas.Arctic.Arctic
local Arctic_Afford_Display = Arctic.RuneUI2.BillboardGui.Display
local Arctic_RPS_Display = Arctic.RuneUI.BillboardGui.Display.RPS

--// Rune Classes \\--
local Basic_Rune = Rune_Class("Basic")
local Color_Rune = Rune_Class("Color")
local Nature_Rune = Rune_Class("Nature")
local Polychrome_Rune = Rune_Class("Polychrome")
local Beginner_Rune = Rune_Class("Beginner")
local Royal_Rune = Rune_Class("Royal")
local Galactic_Rune = Rune_Class("Galactic")
local Cryo_Rune = Rune_Class("Cryo")
local Arctic_Rune = Rune_Class("Arctic")
--// Variables \\--
local Inf_Threshold = 60 * 60 * 24

local Runes_Client = {}

function Runes_Client.Toggle()
	local Tier = Player.Stats.Tier.Value
	
	if Tier < 1 then
		Beginner.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Beginner.Parent = workspace.Areas["Spawn Island"]
	end
	
	if Tier < 3 then
		Basic.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Basic.Parent = workspace.Areas["Spawn Island"]
	end
	
	if Tier < 6 then
		Color.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Color.Parent = workspace.Areas["Spawn Island"]
	end
	
	if Tier < 9 then
		Nature.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Nature.Parent = workspace.Areas["Spawn Island"]
	end
	
	if Tier < 1 then
		Royal.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Royal.Parent = workspace.Areas["Spawn Island"]
	end
	
	if Player.Upgrades.Freeze3.Value >= 1 then 
		Cyro.Parent = workspace.Areas.Arctic
	else 
		Cyro.Parent = game.ReplicatedStorage.Runes_Storage
	end
	
	if Player.Stats.Chromatize.Value >= 7 then
		ArcticRune.Parent = workspace.Areas.Arctic
	else 
		ArcticRune.Parent = game.ReplicatedStorage.Runes_Storage

	end
	
	if Player.Stats.Chromatize.Value < 750 then
		Galactic.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Galactic.Parent = workspace.Areas["Spawn Island"]
	end

	
	if not Player.Stats.AscensionOne.Value then
		Polychrome.Parent = game.ReplicatedStorage.Runes_Storage
	else
		Polychrome.Parent = workspace.Areas["Spawn Island"]
	end
end

function Runes_Client.UpdateRPS()
	local Bulk = Formulas.Rune_Bulk(Player)
	local RuneSpeed = Formulas.Rune_Speed(Player)
	local RPS = Formulas.RPS(Bulk, RuneSpeed)
	
	--[ 5M Beginner Rune ]--
	local Beginner_Afford = Formulas.Rune_Afford(Player.Stats.Tickets.Value, 1)
	local Beginner_Opened = Player.Stats.Beginner_Opened.Value
	local Beginner_OpenTime = Formulas.Rune_OpenTime(Beginner_Afford, RPS)

	if Beginner_Afford <= 0 then
		Beginner_Afford_Display.Count1.Text = "NO"
	else
		Beginner_Afford_Display.Count1.Text = `{EN.Format(Beginner_Afford)}`
	end

	if Beginner_OpenTime <= 0 then -- Open Time < 0s
		Beginner_Afford_Display.Count2.Text = "GET MORE TICKETS BRO"
	elseif Beginner_OpenTime > Inf_Threshold then -- Open Time > 1d
		Beginner_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Beginner_Afford_Display.Count2.Text = `{Time(Beginner_OpenTime, true)}`
	end

	Beginner.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Beginner_Opened)} Opened`
	Beginner_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	
	
	--[ Galactic Rune ]--
	local Galactic_Afford = Formulas.Rune_Afford(Player.Stats.Tickets.Value, 500)
	local Galactic_Opened = Player.Stats.Galactic_Opened.Value
	local Galactic_OpenTime = Formulas.Rune_OpenTime(Galactic_Afford, RPS)

	if Galactic_Afford <= 0 then
		Galactic_Afford_Display.Count1.Text = "NO"
	else
		Galactic_Afford_Display.Count1.Text = `{EN.Format(Galactic_Afford)}`
	end

	if Galactic_OpenTime <= 0 then -- Open Time < 0s
		Galactic_Afford_Display.Count2.Text = "GET MORE TICKETS BRO"
	elseif Galactic_OpenTime > Inf_Threshold then -- Open Time > 1d
		Galactic_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Galactic_Afford_Display.Count2.Text = `{Time(Galactic_OpenTime, true)}`
	end

	Galactic.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Galactic_Opened)} Opened`
	Galactic_RPS_Display.Text = `{EN.Format(RPS)} RPS`

	--[ Basic Rune ]--
	local Basic_Afford = Formulas.Rune_Afford(Player.Stats.Flame.Value, 1e3)
	local Basic_Opened = Player.Stats.Basic_Opened.Value
	local Basic_OpenTime = Formulas.Rune_OpenTime(Basic_Afford, RPS)
	
	if Basic_Afford <= 0 then
		Basic_Afford_Display.Count1.Text = "NO"
	else
		Basic_Afford_Display.Count1.Text = `{EN.Format(Basic_Afford)}`
	end
	
	if Basic_OpenTime <= 0 then -- Open Time < 0s
		Basic_Afford_Display.Count2.Text = "NEVERRRR"
	elseif Basic_OpenTime > Inf_Threshold then -- Open Time > 1d
		Basic_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Basic_Afford_Display.Count2.Text = `{Time(Basic_OpenTime, true)}`
	end
	
	Basic.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Basic_Opened)} Opened`
	Basic_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	
	
	--[ Color Rune ]--
	local Color_Afford = Formulas.Rune_Afford(Player.Stats["Realm Points"].Value, 2.5e4)
	local Color_Opened = Player.Stats.Color_Opened.Value
	local Color_OpenTime = Formulas.Rune_OpenTime(Color_Afford, RPS)

	if Color_Afford <= 0 then
		Color_Afford_Display.Count1.Text = "NO"
	else
		Color_Afford_Display.Count1.Text = `{EN.Format(Color_Afford)}`
	end

	if Color_OpenTime <= 0 then -- Open Time < 0s
		Color_Afford_Display.Count2.Text = "NEVERRRR"
	elseif Color_OpenTime > Inf_Threshold then -- Open Time > 1d
		Color_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Color_Afford_Display.Count2.Text = `{Time(Color_OpenTime, true)}`
	end

	Color.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Color_Opened)} Opened`
	Color_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	
	
	--[ Nature Rune ]--
	local Nature_Afford = Formulas.Rune_Afford(Player.Stats.Spheres.Value, 5e27)
	local Nature_Opened = Player.Stats.Nature_Opened.Value
	local Nature_OpenTime = Formulas.Rune_OpenTime(Nature_Afford, RPS)

	if Nature_Afford <= 0 then
		Nature_Afford_Display.Count1.Text = "NO"
	else
		Nature_Afford_Display.Count1.Text = `{EN.Format(Nature_Afford)}`
	end

	if Nature_OpenTime <= 0 then -- Open Time < 0s
		Nature_Afford_Display.Count2.Text = "NEVERRRR"
	elseif Nature_OpenTime > Inf_Threshold then -- Open Time > 1d
		Nature_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Nature_Afford_Display.Count2.Text = `{Time(Nature_OpenTime, true)}`
	end

	Nature.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Nature_Opened)} Opened`
	Nature_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	
	--[[ Polychrome Rune ]]--
	do
		local Bulk = Formulas.Rune_Bulk(Player,false,"Polychrome")
		local RuneSpeed = Formulas.Rune_Speed(Player)
		local RPS = Formulas.RPS(Bulk, RuneSpeed)
		
		local Polychrome_Afford = Formulas.Rune_Afford(Player.Stats.Prisms.Value, 1e15)
		local Polychrome_Opened = Player.Stats.Polychrome_Opened.Value
		local Polychrome_OpenTime = Formulas.Rune_OpenTime(Polychrome_Afford, RPS)

		if Polychrome_Afford <= 0 then
			Polychrome_Afford_Display.Count1.Text = "NO"
		else
			Polychrome_Afford_Display.Count1.Text = `{EN.Format(Polychrome_Afford)}`
		end

		if Polychrome_OpenTime <= 0 then -- Open Time < 0s
			Polychrome_Afford_Display.Count2.Text = "NEVERRRR"
		elseif Polychrome_OpenTime > Inf_Threshold then -- Open Time > 1d
			Polychrome_Afford_Display.Count2.Text = "INFINITE"
		else -- Displays open time
			Polychrome_Afford_Display.Count2.Text = `{Time(Polychrome_OpenTime, true)}`
		end

		Polychrome.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Polychrome_Opened)} Opened`
		Polychrome_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	end
	
	--[ 5M Royal Rune ]--
	local Royal_Afford = Formulas.Rune_Afford(Player.Stats.Tickets.Value, 50)
	local Royal_Opened = Player.Stats.Royal_Opened.Value
	local Royal_OpenTime = Formulas.Rune_OpenTime(Royal_Afford, RPS)

	if Royal_Afford <= 0 then
		Royal_Afford_Display.Count1.Text = "NO"
	else
		Royal_Afford_Display.Count1.Text = `{EN.Format(Royal_Afford)}`
	end

	if Royal_OpenTime <= 0 then -- Open Time < 0s
		Royal_Afford_Display.Count2.Text = "GET MORE TICKETS BRO"
	elseif Royal_OpenTime > Inf_Threshold then -- Open Time > 1d
		Royal_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Royal_Afford_Display.Count2.Text = `{Time(Royal_OpenTime, true)}`
	end

	Royal.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Royal_Opened)} Opened`
	Royal_RPS_Display.Text = `{EN.Format(RPS)} RPS`

	--[[ Cyro Rune ]]--
	local Cyro_Afford = Formulas.Rune_Afford(Player.Stats.ArcticPoints.Value, 50)
	local Cyro_Opened = Player.Stats.Cryo_Opened.Value
	local Cyro_OpenTime = Formulas.Rune_OpenTime(Cyro_Afford, RPS)

	if Cyro_Afford <= 0 then
		Cyro_Afford_Display.Count1.Text = "NO"
	else
		Cyro_Afford_Display.Count1.Text = `{EN.Format(Cyro_Afford)}`
	end

	if Cyro_OpenTime <= 0 then -- Open Time < 0s
		Cyro_Afford_Display.Count2.Text = "NEVERRRR"
	elseif Cyro_OpenTime > Inf_Threshold then -- Open Time > 1d
		Cyro_Afford_Display.Count2.Text = "INFINITE"
	else -- Displays open time
		Cyro_Afford_Display.Count2.Text = `{Time(Cyro_OpenTime, true)}`
	end

	Cyro.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Cyro_Opened)} Opened`
	Cyro_RPS_Display.Text = `{EN.Format(RPS)} RPS`

	--[[ Arctic Rune ]]--
	do
		local Bulk = Formulas.Rune_Bulk(Player,false,"Arctic")
		local RuneSpeed = Formulas.Rune_Speed(Player)
		local RPS = Formulas.RPS(Bulk, RuneSpeed)
		
		local Arctic_Afford = Formulas.Rune_Afford(Player.Stats.Chromium.Value, 1e6)
		local Arctic_Opened = Player.Stats.Arctic_Opened.Value
		local Arctic_OpenTime = Formulas.Rune_OpenTime(Arctic_Afford, RPS)

		if Arctic_Afford <= 0 then
			Arctic_Afford_Display.Count1.Text = "NO"
		else
			Arctic_Afford_Display.Count1.Text = `{EN.Format(Arctic_Afford)}`
		end

		if Arctic_OpenTime <= 0 then -- Open Time < 0s
			Arctic_Afford_Display.Count2.Text = "NEVERRRR"
		elseif Arctic_OpenTime > Inf_Threshold then -- Open Time > 1d
			Arctic_Afford_Display.Count2.Text = "INFINITE"
		else -- Displays open time
			Arctic_Afford_Display.Count2.Text = `{Time(Arctic_OpenTime, true)}`
		end

		Arctic.RuneUI.BillboardGui.Display.Counter.Text = `{EN.Format(Arctic_Opened)} Opened`
		Arctic_RPS_Display.Text = `{EN.Format(RPS)} RPS`
	end		
end

local function UpdateRuneDisplay(Display, New_Table)
	for _ , Rune in Display:GetChildren() do
		if Rune:IsA("TextLabel") then
			local Chance = (New_Table[Rune.Name] or 0)
			
			if Chance == 0 then
				Rune.Text = string.upper(`{Rune.Name} >> UNOBTAINABLE`)
				continue
			end
			
			if Chance >= 0.00001 then
				Rune.Text = string.upper(`{Rune.Name} >> {EN.Format(Chance * 100, 5)}%`)
			else
				Rune.Text = string.upper(`{Rune.Name} >> {EN.Format(Chance)}`)
			end
		end
	end
end

local Rune_Table
local New_Table
function Runes_Client.UpdateChances()
	--[ Rune Luck ]--
	local Luck = 1
	if Player.Settings.RuneLuck.Value then Luck = Formulas.Rune_Luck(Player) end
	--[ Setting Toggle Here ]--
	
	Luck = Formulas.Rune_Luck(Player, "Beginner")
	Rune_Table = Beginner_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Beginner.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Basic")
	Rune_Table = Basic_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Basic.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Color")
	Rune_Table = Color_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Color.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Nature")
	Rune_Table = Nature_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Nature.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Polychrome")
	Rune_Table = Polychrome_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Polychrome.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Royal")
	Rune_Table = Royal_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Royal.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Cryo")
	Rune_Table = Cryo_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Cyro.RuneUI.BillboardGui.Display.Content, New_Table)
	
	Luck = Formulas.Rune_Luck(Player, "Arctic")
	Rune_Table = Arctic_Rune:GetRuneTable(Luck)
	New_Table = {}
	for _ , Info in Rune_Table do
		New_Table[Info[1]] = Info[2]
	end
	UpdateRuneDisplay(Arctic.RuneUI.BillboardGui.Display.Content, New_Table)
	
	
	Rune_Table = nil
	New_Table = nil
end

return Runes_Client
