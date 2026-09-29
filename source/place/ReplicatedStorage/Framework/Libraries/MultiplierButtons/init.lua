
local Framework = require(game.ReplicatedStorage.Framework)
local Sound_Service = Framework:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

local Environment = Framework.Environment

local MultiplierButtons = {}
local ButtonDataModules = {}

for _, module in pairs(script:GetChildren()) do
	ButtonDataModules[module.Name] = require(module)
end

local function getStartName(item)
	return item:match("^[a-zA-Z]+") or ""
end

local function getNumber(item)
	return tonumber(item:match("%d+$"))  
end	

function MultiplierButtons.CanAfford(currency : number, Player : Player, price) : boolean
	return EN.meeq(currency, price)
end

function MultiplierButtons.Setup(button : Model)
	local name = getStartName(button.Name)
	local buttonData = ButtonDataModules[name]

	if not buttonData then return end

	local number = getNumber(button.Name)
	local price = EN.mul(buttonData.Base_Price, EN.pow(buttonData.Price_Exponential, (number-1)))

	local effect = EN.mul(buttonData.Base_Effect, EN.pow(buttonData.Effect_Exponential,(number-1)))

	local gui = button:FindFirstChild("BillboardGui",true)
	if gui then
		local effectString = EN.toSuffix(effect)
		local priceString = EN.toSuffix(price)

		gui[name].Text = "+" .. effectString .. " " .. string.upper(name)
		gui.Price.Text = priceString .. " " .. gui.Price.Text:match("(%S+)%s*$")
	end
end

function MultiplierButtons.Buy(player : Player, button : Model)
	local name = getStartName(button.Name)
	local buttonData = ButtonDataModules[name]

	if not buttonData then return end
	if not buttonData.HasRequirement(player) then return end

	local number = getNumber(button.Name)
	local price = EN.mul(buttonData.Base_Price, EN.pow(buttonData.Price_Exponential, (number-1)))
	local currency = player.Stats[buttonData.Currency]
		
	if not currency then return end
	if not MultiplierButtons.CanAfford(currency.Value, player, price) then return end
	
	if typeof(currency.Value) == "number" then
		currency.Value -= EN.toNumber(price)
	elseif typeof(currency.Value) == "string" then
		currency.Value = EN.toString(EN.sub(currency.Value, price))
	end
	
	local amount = EN.mul(buttonData.Base_Effect, EN.pow(buttonData.Effect_Exponential,(number-1)))
	amount = EN.mul(amount, buttonData.Formula(player))
	buttonData.OnPurchase(player, button, amount)
	return true	
end

for _, button in pairs(CollectionService:GetTagged("MultiplierButtons")) do 
	MultiplierButtons.Setup(button)
end

return MultiplierButtons
