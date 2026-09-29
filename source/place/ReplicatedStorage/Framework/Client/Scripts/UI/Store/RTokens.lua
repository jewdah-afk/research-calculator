--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--
local EternityNum = Framework:GetLibrary("EternityNum")

local Functions = require(script.Parent.Functions)

local RTokenEvent = Framework:GetEvent("RTokenToggle")
local RobuxEvent = Framework:GetEvent("RobuxToggle")

--[[ Variables ]]--
local Player = Framework:GetPlayer()

local ScreenGui = Framework.Gui.Store
local Confirmation = ScreenGui.Confirmation

local Holder = ScreenGui.Holder
local RTokenGui = Holder.Content.RTokens
local RTokenToggle = Holder.RTokenToggle
local RobuxToggle = Holder.RobuxToggle

local RTokens = {}

function HandleTokens()
	local function Update()
		Confirmation.RTokens.Text = `{EternityNum.Format(Player.Stats.RobuxTokens.Value)}`
		ScreenGui.Holder.RTokens.Text = `{EternityNum.Format(Player.Stats.RobuxTokens.Value)}`
	end
	
	RTokenToggle.Activated:Connect(function()
		RTokenEvent:FireServer()
	end)

	RobuxToggle.Activated:Connect(function()
		RobuxEvent:FireServer()
	end)
	
	Update()
	Player.Stats.RobuxTokens:GetPropertyChangedSignal("Value"):Connect(Update)
end

function RTokens.init()
	HandleTokens()
	
	Functions.AddProduct(RTokenGui["25K"])
	
	for _, RToken in RTokenGui.RTokens:GetChildren() do
		if RToken:IsA("Frame") then 
			Functions.AddProduct(RToken) 
		end
	end
end

return RTokens