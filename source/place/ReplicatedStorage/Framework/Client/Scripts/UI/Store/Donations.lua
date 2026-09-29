--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--
local EternityNum = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

local Functions = require(script.Parent.Functions)

--[[ Variables ]]--
local Player = Framework:GetPlayer()

local ScreenGui = Framework.Gui.Store
local DonationsGui = ScreenGui.Holder.Content.Donations

local Donations = {}

--[[ Functions ]]--
function HandleDonations()
	local DonationBoost = DonationsGui.Boost
	local DonatedStat = Player.Stats.RobuxDonated
	
	local function UpdateDonations()
		DonationBoost.Title.Text = `DONATION BOOST ({EternityNum.Format(DonatedStat.Value)})`
		DonationBoost.RuneLuck.Text = `x{EternityNum.Format(Formulas.Donation_RuneLuck(DonatedStat.Value), 2)} RUNE LUCK`
		DonationBoost.RuneSpeed.Text = `x{EternityNum.Format(Formulas.Donation_RuneSpeed(DonatedStat.Value), 3)} RUNE SPEED`
		DonationBoost.Stats.Text = `x{EternityNum.Format(Formulas.Donation_Stats(DonatedStat.Value), 2)} STATS`
	end
	
	UpdateDonations()
	DonatedStat:GetPropertyChangedSignal("Value"):Connect(UpdateDonations)
end

function Donations.init()
	HandleDonations()

	Functions.AddProduct(DonationsGui["50K"])
	
	for _, Donation in DonationsGui.Container:GetChildren() do
		if Donation:IsA("Frame") then 
			Functions.AddProduct(Donation) 
		end
	end
end

return Donations