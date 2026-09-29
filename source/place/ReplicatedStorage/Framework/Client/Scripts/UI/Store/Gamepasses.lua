--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--
local Functions = require(script.Parent.Functions)

--[[ Variables ]]--
local ScreenGui = Framework.Gui.Store
local ContentGui = ScreenGui.Holder.Content

local GamepassesGui = ContentGui.Gamepasses
local FeaturedGui = ContentGui.Featured
local BundlesGui = ContentGui.Bundles
local OffersGui = ContentGui.Offer
local PacksGui = ContentGui.Packs


local Gamepasses = {}

--[[ Code ]]--
function Gamepasses.init()
	Functions.AddGamepass(GamepassesGui.MorePrisms)
	Functions.AddGamepass(FeaturedGui.Prime)
	Functions.AddGamepass(OffersGui.TripleEnergy)	
	Functions.AddGamepass(BundlesGui.Grinder)
	
	Functions.AddProduct(BundlesGui.RunicBundle)
	Functions.AddProduct(BundlesGui.GlobalMix)
	Functions.AddProduct(PacksGui.RunePack)
	Functions.AddProduct(PacksGui.MadnessPack)
	Functions.AddProduct(BundlesGui.ElixirBundle)
	Functions.AddProduct(FeaturedGui.FasterSecretStats)
	Functions.AddProduct(OffersGui.DoubleChromium)
	Functions.AddProduct(PacksGui.StarterPack)
	
	for _, Pass in GamepassesGui.Container:GetChildren() do
		if Pass:IsA("Frame") then
			Functions.AddGamepass(Pass)
		end
	end
end

return Gamepasses