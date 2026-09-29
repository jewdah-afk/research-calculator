--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Services ]]--
local ReplicatedStorage = Framework:GetService("ReplicatedStorage")

--[[ Modules ]]--
local Formulas = Framework:GetSharedModule("Formulas")
local EternityNum = Framework:GetLibrary("EternityNum")

local Functions = require(script.Parent.Functions)
local Data = require(script.Data)

--[[ Variables ]]--
local Purchase_Product = Framework:GetEvent("Purchase_Product")

local ScreenGui = Framework.Gui.Store
local Container = ScreenGui.Holder.Content
local Featured = Container.Featured
local Confirmation = ScreenGui.Confirmation

local Player = Framework:GetPlayer()

local RuneBulkProduct = Player.Stats.RuneBulkProduct
local RuneLuckProduct = Player.Stats.RuneLuckProduct
local RuneCloneProduct = Player.Stats.RuneCloneProduct
local RuneLuckLevel = Player.Stats.RuneLuckLevel
local RuneSpeedProduct = Player.Stats.RuneSpeedProduct
local RuneSpeedLevel = Player.Stats.RuneSpeedLevel
local RuneBulkLevel = Player.Stats.RuneBulkLevel
local RuneBulkMultiplierProduct = Player.Stats.RuneBulkMultiplierProduct

local SecretStatsProduct = Player.Stats.SecretStatsProduct
local SecretStatsLevel = Player.Stats.SecretStatsLevel

local AntimatterProduct = Player.Stats.AntimatterProduct
local BoundlessProduct = Player.Stats.BoundlessProduct
local EtherbornProduct = Player.Stats.EtherbornProduct
local AnkhProduct = Player.Stats.AnkhProduct
local PrimordialProduct = Player.Stats.PrimordialProduct
local OmenProduct = Player.Stats.OmenProduct
local EternalProduct = Player.Stats.EternalProduct

local RTokenPrices = require(ReplicatedStorage.Framework.Libraries.ProductHandler.RTokenPrices)

local Runes = {}

--[[ Functions ]]--
function UpdateRuneBulk()
	local RuneBulkFrame = Featured.RuneBulk
	local RuneBulkStat = Player.Stats.RuneBulkProduct
	
	local function Update()
		Featured.RuneBulk.Current.Text = `+{Formulas.Product_RuneBulk(Player)} RUNE BULK`
		Featured.RuneBulk.LVL.Text = `LVL {math.clamp(math.floor(RuneBulkProduct.Value), 0, 1000000)}`
	end
	
	Functions.AddProduct(RuneBulkFrame)
	
	Update()
	RuneBulkStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local RuneLuckFrame = Featured.RuneLuck
	local RuneLuckStat = Player.Stats.RuneLuckProduct

	local function Update()
		Featured.RuneLuck.Current.Text = `x{Formulas.Product_RuneLuck(Player)} RUNE LUCK`
		Featured.RuneLuck.LVL.Text = `LVL {math.clamp(math.floor(RuneLuckLevel.Value), 0, 25)}/25`
	end

	Functions.AddProduct(RuneLuckFrame)

	Update()
	RuneLuckStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local RuneSpeedFrame = Featured.RuneSpeed
	local RuneSpeedStat = Player.Stats.RuneSpeedProduct

	local function Update()
		Featured.RuneSpeed.Current.Text = `x{Formulas.Product_RuneSpeed(Player)} RUNE SPEED`
		Featured.RuneSpeed.LVL.Text = `LVL {math.clamp(math.floor(RuneSpeedLevel.Value), 0, 50)}/50`
	end

	Functions.AddProduct(RuneSpeedFrame)

	Update()
	RuneSpeedStat:GetPropertyChangedSignal("Value"):Connect(Update)
	

	local RuneBulkFrame2 = Featured.RuneBulkMultiplier
	local RuneBulkStat2 = Player.Stats.RuneBulkMultiplierProduct

	local function Update()
		Featured.RuneBulkMultiplier.Current.Text = `x{Formulas.Product_RuneBulk2(Player)} RUNE BULK`
		Featured.RuneBulkMultiplier.LVL.Text = `LVL {math.clamp(math.floor(RuneBulkLevel.Value), 0, 20)}/20`
	end

	Functions.AddProduct(RuneBulkFrame2)

	Update()
	RuneBulkStat2:GetPropertyChangedSignal("Value"):Connect(Update)
	
	
	
	local AntimatterFrame = Featured.Antimatter
	local AntimatterStat = Player.Stats.AntimatterProduct

	local function Update()
		Featured.Antimatter.LVL.Text = `STOCK: {30 - math.clamp(math.floor(AntimatterProduct.Value), 0, 30)}/30`
	end

	Functions.AddProduct(AntimatterFrame)

	Update()
	AntimatterStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	
	local BoundlessFrame = Featured.Boundless
	local BoundlessStat = Player.Stats.BoundlessProduct

	local function Update()
		Featured.Boundless.LVL.Text = `STOCK: {30 - math.clamp(math.floor(BoundlessProduct.Value), 0, 30)}/30`
	end

	Functions.AddProduct(BoundlessFrame)

	Update()
	BoundlessStat:GetPropertyChangedSignal("Value"):Connect(Update)
	

	local AnkhFrame = Featured.Ankh
	local AnkhStat = Player.Stats.AnkhProduct

	local function Update()
		Featured.Ankh.LVL.Text = `STOCK: {8 - math.clamp(math.floor(AnkhProduct.Value), 0, 8)}/8`
	end

	Functions.AddProduct(AnkhFrame)

	Update()
	AnkhStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local PrimordialFrame = Featured.Primordial
	local PrimordialStat = Player.Stats.PrimordialProduct

	local function Update()
		Featured.Primordial.LVL.Text = `STOCK: {4 - math.clamp(math.floor(PrimordialProduct.Value), 0, 4)}/4`
	end

	Functions.AddProduct(PrimordialFrame)

	Update()
	PrimordialStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local OmenFrame = Featured.Omen
	local OmenStat = Player.Stats.OmenProduct

	local function Update()
		Featured.Omen.LVL.Text = `STOCK: {4 - math.clamp(math.floor(OmenProduct.Value), 0, 4)}/4`
	end

	Functions.AddProduct(OmenFrame)

	Update()
	OmenStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local EternalFrame = Featured.Eternal
	local EternalStat = Player.Stats.EternalProduct

	local function Update()
		Featured.Eternal.LVL.Text = `STOCK: {4 - math.clamp(math.floor(OmenProduct.Value), 0, 4)}/4`
	end

	Functions.AddProduct(EternalFrame)

	Update()
	EternalStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local EtherbornFrame = Featured.Etherborn
	local EtherbornStat = Player.Stats.EtherbornProduct

	local function Update()
		Featured.Etherborn.LVL.Text = `STOCK: {5 - math.clamp(math.floor(EtherbornProduct.Value), 0, 5)}/5`
	end

	Functions.AddProduct(EtherbornFrame)

	Update()
	EtherbornStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	local SecretStatsFrame = Featured.MoreSecretStats
	local SecretStatsStat = Player.Stats.SecretStatsProduct

	local function Update()
		Featured.MoreSecretStats.Current.Text = `x{Formulas.Product_SecretStats(Player)} All Secret Stats`
		Featured.MoreSecretStats.LVL.Text = `LVL {math.clamp(math.floor(SecretStatsLevel.Value), 0, 10)}/10`
	end

	Functions.AddProduct(SecretStatsFrame)

	Update()
	SecretStatsStat:GetPropertyChangedSignal("Value"):Connect(Update)
end


function UpdateRuneClone()
	local RuneCloneFrame = Featured.RuneClone
	local RuneCloneStat = Player.Stats.RuneCloneProduct
	
	local function Update()
		local CurrentLevel = math.clamp(math.floor(RuneCloneStat.Value), 0, 10)
		local CurrentChance = Formulas.Product_RuneClone(Player)
		local NextChance = CurrentChance * 10
		
		RuneCloneFrame.Level.Text = `LVL {CurrentLevel}/8`
		RuneCloneFrame.Price.Text = `{Data.Prices[CurrentLevel + 1] or 9999} R$`
		
		RuneCloneFrame.Current.Text = `CLONES RUNES BELOW 1/{EternityNum.Format(CurrentChance)}`
		RuneCloneFrame.Next.Text = `CLONES RUNES BELOW 1/{EternityNum.Format(NextChance)}`
		
		if CurrentLevel == 0 then
			RuneCloneFrame.Current.Text = `NO CLONE ACTIVE`
			RuneCloneFrame.Next.Text = `CLONES RUNES BELOW 1/{EternityNum.Format(CurrentChance)}`
			return
		end

		if CurrentLevel == 7 then
			RuneCloneFrame.Current.Text = `CLONES RUNES BELOW 1/{EternityNum.Format(CurrentChance)}`
			RuneCloneFrame.Next.Text = "MAXED OUT"
			return
		end
		
		CurrentChance /= 10
		NextChance /= 10
	end
	
	Update()
	RuneCloneStat:GetPropertyChangedSignal("Value"):Connect(Update)
	
	RuneCloneFrame.Buy.Activated:Connect(function()
		
		local id = Data.IDs[math.floor(RuneCloneStat.Value + 1)]

		if Player:GetAttribute("RTokens") and RTokenPrices[id] then		
			local data = {
				Product_Type = "Product",
				Product_Display = `"Rune Clone {RuneCloneStat.Value + 1}`,
				Product_ID = id,
				Product_Price = RTokenPrices[id] or 9999,
			}
			Functions.UpdateConfirmation(data)
			Confirmation.Visible = true
			return
		end
	
		Purchase_Product:FireServer(Data.IDs[math.floor(RuneCloneStat.Value + 1)])
	end)
	
	local OriginalText = RuneCloneFrame.Price.Text
	Player:GetAttributeChangedSignal("RTokens"):Connect(function()
		local id = Data.IDs[math.floor(RuneCloneStat.Value + 1)]
		if Player:GetAttribute("RTokens") then
			RuneCloneFrame.Price.Text = `{RTokenPrices[id]} Robux Tokens`
			return
		end
		RuneCloneFrame.Price.Text = OriginalText
	end)
end

--[[ Code ]]--
function Runes.init()
	UpdateRuneBulk()
	UpdateRuneClone()
	
	local GlobalRune = Container.GlobalRune:WaitForChild("Container")
	local UltraRune = Container.GlobalRune:WaitForChild("Container2")
	local AncientRune = Container.GlobalRune:WaitForChild("Container3")
	local MadnessRune = Container.GlobalRune:WaitForChild("Container4")
	
	
	
	if Player:GetAttribute("RNG_Banned") then
		for _, Key in {"Buy 1", "Buy 10", "Buy 100", "Buy 1000", "Buy 10000"} do
			if GlobalRune:FindFirstChild(Key) then GlobalRune[Key]:Destroy() end
			if UltraRune:FindFirstChild(Key)  then UltraRune[Key]:Destroy() end
			if AncientRune:FindFirstChild(Key)  then AncientRune[Key]:Destroy() end
			if MadnessRune:FindFirstChild(Key)  then MadnessRune[Key]:Destroy() end
		end
		
		for _, Key in {"Price_1", "Price_10", "Price_100", "Price_1000", "Price_10000"} do
			if GlobalRune:FindFirstChild(Key) then GlobalRune.Visible = false end
			if UltraRune:FindFirstChild(Key) then UltraRune.Visible = false end
			if AncientRune:FindFirstChild(Key) then AncientRune.Visible = false end
			if MadnessRune:FindFirstChild(Key) then MadnessRune.Visible = false end
		end
		
		Container.GlobalRune.Visible = false
	else
		local GlobalRuneIDs = {
			["Buy 1"] = 1814500714,
			["Buy 10"] = 2700366584,
			["Buy 100"] = 2992210697,
			["Buy 1000"] = 3348035777
		}
		
		for Key, ID in GlobalRuneIDs do
			if GlobalRune[Key] then
				GlobalRune[Key].Activated:Connect(function()
					Purchase_Product:FireServer(ID)
				end)
			end
		end
		
		local UltraRuneIDs = {
			["Buy 1"] = 3226706331,
			["Buy 10"] = 3226707317,
			["Buy 100"] = 3226707595,
			["Buy 1000"] = 3348035329
		}

		for Key, ID in UltraRuneIDs do
			if UltraRune[Key] then
				UltraRune[Key].Activated:Connect(function()
					Purchase_Product:FireServer(ID)
				end)
			end
		end
		
		local AncientRuneIDs = {
			["Buy 1"] = 3355767327,
			["Buy 10"] = 3355767497,
			["Buy 100"] = 3355767667,
			["Buy 1000"] = 3355767833,
			["Buy 10000"] = 3355792504
		}

		for Key, ID in AncientRuneIDs do
			if AncientRune[Key] then
				AncientRune[Key].Activated:Connect(function()
					Purchase_Product:FireServer(ID)
				end)
			end
		end
		
		local MadnessRuneIDs = {
			["Buy 1"] = 3362608256,
			["Buy 10"] = 3362610779,
			["Buy 100"] = 3362611353,
			["Buy 1000"] = 3362611713,
			["Buy 10000"] = 3362612521
		}

		for Key, ID in MadnessRuneIDs do
			if MadnessRune[Key] then
				MadnessRune[Key].Activated:Connect(function()
					Purchase_Product:FireServer(ID)
				end)
			end
		end
		
		
	end
end

return Runes