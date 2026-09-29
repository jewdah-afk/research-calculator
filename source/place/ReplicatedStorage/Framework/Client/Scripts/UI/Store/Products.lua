--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--
local Purchase_Product = Framework:GetEvent("Purchase_Product")

local Functions = require(script.Parent.Functions)

--[[ Variables ]]--
local Player = Framework:GetPlayer()

local ScreenGui = Framework.Gui.Store
local ContentGui = ScreenGui.Holder.Content

local Packs = ContentGui.Packs
local Bundles = ContentGui.Bundles

local Products = {}

--[[ Functions ]]--
function RunicBundle()
	local function UpdatePack()
		if Player.Stats.Runic_Bundle.Value == true then
			
			Bundles.RunicBundle.Buy.Buy.Text = "OWNED"
			--Bundles.RunicBundle.Buy.Visible = false
			
			--Bundles.RunicBundle.Gift.Position = UDim2.new(0.07, 0, 0.836, 0)
			--Bundles.RunicBundle.Price.Position = UDim2.new(0.14, 0, 0.849, 0)
			--Bundles.RunicBundle.Worth.Position = UDim2.new(0.14, 0, 0.763, 0)

			return
		end
	end

	UpdatePack()
	Player.Stats.Runic_Bundle:GetPropertyChangedSignal("Value"):Connect(UpdatePack)
end

function BoosterPack()
	local function UpdatePack()
		if Player.Stats.Booster_Pack.Value == true then
			Packs.BoosterPack.Buy.Visible = false
			Packs.BoosterPack.Price.Visible = false
			
			return
		end
	end
	
	UpdatePack()
	Player.Stats.Booster_Pack:GetPropertyChangedSignal("Value"):Connect(UpdatePack)
end

function StarterPack()
	local Pack_Timer = Player.Stats.Starter_Pack_Timer

	local function UpdatePack()
		if Player.Stats.Tier.Value >= 4 or Pack_Timer.Value <= 0 then
			Packs.StarterPack.Buy.Visible = false
			Packs.StarterPack.Price.Visible = false

			return
		end

		Packs.StarterPack.Price.Visible = true
		Packs.StarterPack.Buy.Visible = true
	end

	UpdatePack()
	Pack_Timer:GetPropertyChangedSignal("Value"):Connect(UpdatePack)
end

--[[ Code ]]--
function Products.init()
	pcall(function()
		BoosterPack()
	end)
	StarterPack()
	RunicBundle()
end

return Products