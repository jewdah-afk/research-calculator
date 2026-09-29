
local Framework = require(game.ReplicatedStorage.Framework)
local Sound_Service = Framework:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local EN = Framework:GetLibrary("EternityNum")
local Environment = Framework.Environment

local RunService = game:GetService("RunService")
local Formulas = Framework:GetSharedModule("Formulas")

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
	 
	local gui = button:FindFirstChild("BillboardGui",true)
	if gui then
		local effect = EN.mul(buttonData.Base_Effect, EN.pow(buttonData.Effect_Exponential,(number-1)))
		RunService.RenderStepped:Connect(function()
			
			local newEffect = EN.mul(effect, buttonData.Formula(game.Players.LocalPlayer))
			
			local effectString = EN.toSuffix(newEffect)
			gui[name].Text = "+" .. effectString .. " " .. string.upper(name)
		end)
		
	end
end

for _, button in pairs(CollectionService:GetTagged("MultiplierButtons")) do 	
	MultiplierButtons.Setup(button)
end



return MultiplierButtons
