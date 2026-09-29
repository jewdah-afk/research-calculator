
--[[ FRAMEWORK ]]--
local Framework = require(game.ReplicatedStorage.Framework)
local StatsEvent = Framework:GetEvent("Toggle_Tag")

local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

--[[ VARIABLES ]]--
local Player = Framework:GetPlayer()
local PlayerGui = Framework.Gui
local ScreenGui = PlayerGui:WaitForChild("Index")
local Holder = ScreenGui.Holder

local Index = {}

local function UpdateHazeGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local HazeMenu = SecetsMenu:WaitForChild("Haze")
	local hazeValue = Player.Stats.Haze.Value

	HazeMenu.Visible = EN.me(hazeValue, "0")
	HazeMenu.Amount.Text = EN.Format(hazeValue)
		
	local gotHaze = false
	local statsValue = 1
	local luckValue = 1
	
	-- For Droplets, Water, Ice
	
	if Player.Stats.Haze.Value >= 1 then 
		statsValue = EN.mul(statsValue, 1+math.min(Player.Stats.Haze.Value * 2, 100))
		luckValue = EN.mul(luckValue, 1+math.min(Player.Stats.Haze.Value * 0.3, 25))
		gotHaze = true
	end
	
	
	HazeMenu.Boosts.Ice.Text = `x{statsValue} Ice`
	HazeMenu.Boosts.Water.Text = `x{statsValue} Water`
	HazeMenu.Boosts.Droplets.Text = `x{statsValue} Droplets`
	HazeMenu.Boosts.RuneLuck.Text = `x{luckValue} Rune Luck`
	
end

local function UpdateLightGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local LightMenu = SecetsMenu:WaitForChild("Light")
	local LightValue = Player.Stats.Light.Value

	LightMenu.Visible = EN.me(LightValue, "0")
	LightMenu.Amount.Text = EN.Format(LightValue)

	local gotLight = false
	local ChromeValue = 1

	-- For Droplets, Water, Ice

	if Player.Stats.Light.Value >= 1 then 
		ChromeValue = EN.mul(ChromeValue, 1+math.min(Player.Stats.Light.Value * 0.05, 1e300))
		gotLight = true
	end


	LightMenu.Boosts.Chrome.Text = `x{ChromeValue} Chrome`

end


local function UpdateHailGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local HailMenu = SecetsMenu:WaitForChild("Hail")
	local hailValue = Player.Stats.Hail.Value

	HailMenu.Visible = EN.me(hailValue, "0")
	HailMenu.Amount.Text = EN.Format(hailValue)

	local gotHail = false
	local statsValue2 = 1
	local speedValue = 1



	if Player.Stats.Hail.Value >= 1 then 
		statsValue2 = EN.mul(statsValue2, 1+math.min(Player.Stats.Hail.Value * 0.5, 1000))
		speedValue = EN.mul(speedValue, 1+math.min(Player.Stats.Hail.Value * 0.085, 4))
		gotHail = true
	end

	HailMenu.Boosts.Prisms.Text = `x{statsValue2} Prisms`
	HailMenu.Boosts.Droplets.Text = `x{statsValue2} Droplets`
	HailMenu.Boosts.RuneSpeed.Text = `x{speedValue} Rune Speed`
end

local function UpdateLootGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local LootMenu = SecetsMenu:WaitForChild("Loot")
	local lootValue = Player.Stats.Loot.Value

	LootMenu.Visible = EN.me(lootValue, "0")
	LootMenu.Amount.Text = EN.Format(lootValue)

	local gotLoot = false
	local statsValue3 = 1
	local bulkValue = 1



	if Player.Stats.Loot.Value >= 1 then 
		statsValue3 = EN.mul(statsValue3, 1+math.min(Player.Stats.Loot.Value * 0.05, 1000))
		bulkValue = EN.mul(bulkValue, 1+math.min(Player.Stats.Loot.Value * 0.0075, 2))
		gotLoot = true
	end

	LootMenu.Boosts.Energy.Text = `x{statsValue3} Energy`
	LootMenu.Boosts.Flesh.Text = `x{statsValue3} Flesh`
	LootMenu.Boosts.RuneBulk.Text = `x{bulkValue} Rune Bulk`
end

local function UpdateChromaGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local ChromaMenu = SecetsMenu:WaitForChild("Chroma")
	local ChromaValue = Player.Stats.Chroma.Value

	ChromaMenu.Visible = EN.me(ChromaValue, "0")
	ChromaMenu.Amount.Text = EN.Format(ChromaValue)

	local gotChroma = false
	local statsValue4 = 1
	local speedValue2 = 1



	if Player.Stats.Loot.Value >= 1 then 
		statsValue4 = EN.mul(statsValue4, 1+math.min(Player.Stats.Chroma.Value * 1, 1e300))
		speedValue2 = EN.mul(speedValue2, 1+math.min(Player.Stats.Chroma.Value * 0.00001, 0.25))
		gotChroma = true
	end

	ChromaMenu.Boosts.Prisms.Text = `x{statsValue4} Prisms`
	ChromaMenu.Boosts.RuneSpeed.Text = `x{speedValue2} Rune Speed`
end

local function UpdateShineGUI()
	local SecetsMenu = Holder:WaitForChild("Secrets")
	local ShineMenu = SecetsMenu:WaitForChild("Shine")
	local ShineValue = Player.Stats.Shine.Value

	ShineMenu.Visible = EN.me(ShineValue, "0")
	ShineMenu.Amount.Text = EN.Format(ShineValue)

	local gotShine = false
	local LMValue = 1
	local SMValue = 1
	local CMValue = 1


	if Player.Stats.Shine.Value >= 1 then 
		LMValue = EN.mul(LMValue, 1+math.min(Player.Stats.Shine.Value * 0.1, 1e300))
		CMValue = EN.mul(CMValue, 1+math.min(Player.Stats.Shine.Value * 0.01, 1e300))
		SMValue = EN.mul(SMValue, 1+math.min(Player.Stats.Shine.Value * 0.0001, 0.1))
		gotShine = true
	end

	ShineMenu.Boosts.Light.Text = `x{LMValue} Light`
	ShineMenu.Boosts.Chroma.Text = `x{CMValue} Chroma`
	ShineMenu.Boosts.RPS.Text = `x{SMValue} RPS`
end

function Index:init()
	UpdateHazeGUI()
	Player.Stats.Haze:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateHazeGUI()
	end)
	
	UpdateHailGUI()
	Player.Stats.Hail:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateHailGUI()
	end)
	
	UpdateLootGUI()
	Player.Stats.Loot:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateLootGUI()
	end)
	
	UpdateChromaGUI()
	Player.Stats.Chroma:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateChromaGUI()
	end)
	

	UpdateLightGUI()
	Player.Stats.Light:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateLightGUI()
	end)
	
	UpdateShineGUI()
	Player.Stats.Shine:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateShineGUI()
	end)
	
end

return Index
