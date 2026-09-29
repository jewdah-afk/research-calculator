local module = {}

local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")

local Freeze_Tiers = Framework:GetEvent("Freeze_Tiers")
local Data = require(script.Data)

local FreezeBoard = workspace.Areas.Arctic.Freeze.FreezeBoard

local BypassTier11 = true

function module.Freeze(Player: Player, Lvl)
	print(Lvl)
	local PlayerDroplets = EN.toNumber(EN.fromString(Player.Stats.Droplets.Value))
	local PlayerFreezeTier = Player.Stats.Tier_Freeze.Value
	local TierOfPlayer = Player.Stats.Tier
	local FreezeData = Data["Freeze_" .. tostring(Lvl)]

	if not FreezeData or tostring(PlayerFreezeTier) >= tostring(Lvl) then
		return
	end

	if not BypassTier11 and TierOfPlayer.Value < 11 then
		return
	end

	if PlayerDroplets >= FreezeData.Needed then
		print("Successfully upgraded freeze tier to " .. Lvl)
		Player.Stats.Droplets.Value = EN.toString(EN.sub(PlayerDroplets, FreezeData.Needed))
		Player.Stats.Tier_Freeze.Value = tonumber(Lvl)
	end

	Lvl = tostring(Lvl)

	if Lvl == "1" then
		Player.Stats.Droplets_Multiplier.Value = FreezeData.Give.Boost_Droplets
		Player.Stats.Water_Multiplier.Value = FreezeData.Give.Boost_Water

		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end

		end
	elseif Lvl == "2" then
		Player.Stats.IceUnlocked.Value = true
		Player.Stats.Water_Multiplier.Value = FreezeData.Give.Boost_Water
		Player.Stats.AP_Multiplier.Value = FreezeData.Give.Boost_AP

	elseif Lvl == "3" then
		Player.Stats.Water_Multiplier.Value = FreezeData.Give.Boost_Water
		Player.Stats.Ice_Multiplier.Value = FreezeData.Give.Boost_Ice
		
		if not Player.Runes:FindFirstChild("Cryo") then
			local value = Instance.new("NumberValue")
			value.Name = "Cryo"
			value.Parent = Player.Runes
		else
			Player.Runes:FindFirstChild("Cryo").Value += 1
		end
		
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
	elseif Lvl == "4" then
		Player.Stats.Droplets_Multiplier.Value = FreezeData.Give.Boost_Droplets
		Player.Stats.AP_Multiplier.Value = FreezeData.Give.Boost_AP
		-- Mega Talent
	elseif Lvl == "5" then
		Player.Stats.Chromium_Multiplier.Value = FreezeData.Give.Boost_Chromium
		Player.Stats.Ice_Multiplier.Value = FreezeData.Give.Boost_Ice
		Player.Stats.Prisms_Multiplier.Value = FreezeData.Give.Boost_Prisms
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
	elseif Lvl == "6" then
		Player.Stats.Spheres_Multiplier.Value = FreezeData.Give.Boost_Spheres
		-- Unlocks Droplets_AP
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
	elseif Lvl == "7" then
		-- New Ticket Perk
		Player.Stats.Icicles_Multiplier.Value = FreezeData.Give.Boost_ICICLES
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
	elseif Lvl == "8" then
		Player.Stats.Prisms_Multiplier.Value = FreezeData.Give.Boost_Prisms
		Player.Stats.Chromium_Multiplier.Value = FreezeData.Give.Boost_Chromium
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
	elseif Lvl == "9" then
		-- New Droplet Upgrade
		for _, v in ipairs(FreezeData.Give.Talents) do
			if not Player.Upgrades:FindFirstChild(v) then
				local value = Instance.new("NumberValue")
				value.Name = v
				value.Parent = Player.Upgrades
			end
		end
		-- Mega talent
	end
end

return module
