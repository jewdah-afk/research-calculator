local Framework = require(game.ReplicatedStorage.Framework)
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = Framework:GetLibrary("Upgrades")
--[ Modules ]--
local RuneFormulas = Framework:GetSharedModule("RuneFormulas")
--[ Variables ]--
local Base_WS = game.StarterPlayer.CharacterWalkSpeed

local Formulas = {}

--[ INDEX ]--
-- Changed often
-- Ctrl + G
-- Stats :: Line 20
-- Donations :: Line 517
-- Tickets :: Line 530
-- Level / XP :: 553



--[ STATS ]--
function Formulas.Energy(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	-- Player.Stats

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 1 then Tier_Bonus = 2 end -- Player has Tier 1 | x2 Energy
	if Player.Stats.Tier.Value >= 2 then Tier_Bonus = 4 end -- Player has Tier 2 | x4 Energy
	if Player.Stats.Tier.Value >= 3 then Tier_Bonus = 20 end -- Player has Tier 3 | x20 Energy
	if Player.Stats.Tier.Value >= 4 then Tier_Bonus = 80 end -- Player has Tier 4 | x80 Energy
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 5e2 end -- Player has Tier 5 | x500 Energy
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 5e3 end -- Player has Tier 6 | x5K Energy
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 7.5e4 end -- Player has Tier 7 | x75K Energy
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 2.5e6 end -- Player has Tier 8 | x2.5M Energy
	if Player.Stats.Tier.Value >= 9 then Tier_Bonus = 2.5e7 end -- Player has Tier 9 | x25M Energy
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 5e10 end -- Player has Tier 10 | x50B Energy

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Basic_Energy(Player.Runes.Basic.Value))
		Value = EN.mul(Value, RuneFormulas.Unique_Energy(Player.Runes.Unique.Value))
		Value = EN.mul(Value, RuneFormulas.Ascendant_Energy(Player.Runes.Ascendant.Value))
		Value = EN.mul(Value, RuneFormulas.Exotic_Energy(Player.Runes.Exotic.Value))
		Value = EN.mul(Value, RuneFormulas.Tinted_Energy(Player.Runes.Tinted.Value))
		Value = EN.mul(Value, RuneFormulas.Colorful_Energy(Player.Runes.Colorful.Value))
		Value = EN.mul(Value, RuneFormulas.Radiance_Energy(Player.Runes.Radiance.Value))
		Value = EN.mul(Value, RuneFormulas.Neon_Energy(Player.Runes.Neon.Value))
		Value = EN.mul(Value, RuneFormulas.Chrome_Energy(Player.Runes.Chrome.Value))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Energy(Player.Runes.Vibrance.Value))
		Value = EN.mul(Value, RuneFormulas.Oak_Energy(Player.Runes.Oak.Value))
		Value = EN.mul(Value, RuneFormulas.Dew_Energy(Player.Runes.Dew.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Energy(Player.Runes.Thunderstorm.Value))
		Value = EN.mul(Value, RuneFormulas.Earthvein_Energy(Player.Runes.Oak.Value))
		Value = EN.mul(Value, RuneFormulas.Dreamscape_Energy(Player.Runes.Dreamscape.Value))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Energy(Player.Runes.Lightmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Energy(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Glow_Energy(Player.Runes.Glow.Value))
		Value = EN.mul(Value, RuneFormulas.Noob_Energy(Player.Runes.Noob.Value))
		Value = EN.mul(Value, RuneFormulas.Experienced_Energy(Player.Runes.Experienced.Value))
		Value = EN.mul(Value, RuneFormulas.Champion_Energy(Player.Runes.Champion.Value))
		Value = EN.mul(Value, RuneFormulas.Superstar_Energy(Player.Runes.Superstar.Value))
		Value = EN.mul(Value, RuneFormulas.Gilded_Energy(Player.Runes.Gilded.Value))
		Value = EN.mul(Value, RuneFormulas.Crown_Energy(Player.Runes.Crown.Value))
		Value = EN.mul(Value, RuneFormulas.Monarch_Energy(Player.Runes.Monarch.Value))
		Value = EN.mul(Value, RuneFormulas.Overlord_Energy(Player.Runes.Overlord.Value))
		Value = EN.mul(Value, RuneFormulas.Dust_Energy(Player.Runes.Dust.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Basic_Energy(Player.Runes.Basic.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Unique_Energy(Player.Runes.Unique.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Ascendant_Energy(Player.Runes.Ascendant.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Exotic_Energy(Player.Runes.Exotic.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Tinted_Energy(Player.Runes.Tinted.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Colorful_Energy(Player.Runes.Colorful.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Radiance_Energy(Player.Runes.Radiance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Neon_Energy(Player.Runes.Neon.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Chrome_Energy(Player.Runes.Chrome.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Energy(Player.Runes.Vibrance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Oak_Energy(Player.Runes.Oak.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Dew_Energy(Player.Runes.Dew.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Energy(Player.Runes.Thunderstorm.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Earthvein_Energy(Player.Runes.Oak.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Dreamscape_Energy(Player.Runes.Dreamscape.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Energy(Player.Runes.Lightmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Energy(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Glow_Energy(Player.Runes.Glow.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Noob_Energy(Player.Runes.Noob.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Experienced_Energy(Player.Runes.Experienced.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Champion_Energy(Player.Runes.Champion.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Superstar_Energy(Player.Runes.Superstar.Value ^0.33))
		Value = EN.mul(Value, RuneFormulas.Gilded_Energy(Player.Runes.Gilded.Value ^0.33))
		Value = EN.mul(Value, RuneFormulas.Crown_Energy(Player.Runes.Crown.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Monarch_Energy(Player.Runes.Monarch.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Overlord_Energy(Player.Runes.Overlord.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Dust_Energy(Player.Runes.Dust.Value ^ 0.33))
	end

	if EN.meeq(Player.Stats.Spheres.Value, 100) then
		Value = EN.mul(Value, 25)
	end
	--// Final Calculations \\--
	Value = EN.mul(Value, Upgrades("RP_Energy"):GetEffect(Player.Upgrades.RP_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Energy2"):GetEffect(Player.Upgrades.RP_Energy2.Value, Player))
	Value = EN.mul(Value, Upgrades("Power_Energy"):GetEffect(Player.Upgrades.Power_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Energy"):GetEffect(Player.Upgrades.Flesh_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Energy1"):GetEffect(Player.Upgrades.Prisms_Energy1.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Energy2"):GetEffect(Player.Upgrades.Prisms_Energy2.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Multi"):GetEffect(Player.Upgrades.Prisms_Multi.Value, Player))
	Value = EN.mul(Value, Upgrades("Orbs_Energy"):GetEffect(Player.Upgrades.Orbs_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Energy"):GetEffect(Player.Upgrades.Spheres_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Energy"):GetEffect(Player.Upgrades.Tickets_Energy.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Energy2"):GetEffect(Player.Upgrades.Spheres_Energy2.Value, Player))
	Value = EN.mul(Value, Formulas.Flame_Energy(Player.Stats.Flame.Value))
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Orbs_Energy(Player.Stats.Orbs.Value))
	Value = EN.mul(Value, Formulas.Cube_Energy(Player.Stats.Cube_Level.Value))
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))
	Value = EN.mul(Value, Formulas.Level_Energy(Player.Stats.Level.Value))
	
	if Player:GetAttribute("GroupMember") then Value = EN.mul(Value, 1.5) end
	
	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	
	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end
	
	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end
	
	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Gamepasses.TripleEnergy.Value then Value = EN.mul(Value, 3) end
	
	local gotLoot = false 
	if Player.Stats.Loot.Value >= 1 then 
		local LootBoost = 1+math.min(Player.Stats.Loot.Value * 0.05, 1000)
		Value = EN.mul(Value, LootBoost)
		gotLoot = true
	end
	

	--[ Challenges ]--
	if Player.Stats.C1.Value then Value = EN.mul(Value, 1e12) end
	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.C3.Value and EN.me(Value, 1) then Value = EN.pow(Value, 1.1) end
	if Player.Stats.CurrentChallenge.Value == "C1" and EN.me(Value, 1) then Value = EN.pow(Value, 0.425) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Flame(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	if Player.Stats.CurrentChallenge.Value == "C3" then return 0 end

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 2 then Tier_Bonus = 2 end -- Player has Tier 2 | x2 Flame
	if Player.Stats.Tier.Value >= 3 then Tier_Bonus = 5 end -- Player has Tier 3 | x5 Flame
	if Player.Stats.Tier.Value >= 4 then Tier_Bonus = 15 end -- Player has Tier 4 | x15 Flame
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 30 end -- Player has Tier 5 | x30 Flame
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 200 end -- Player has Tier 6 | x200 Flame
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 2.5e3 end -- Player has Tier 7 | x2.5K Flame
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 1e5 end -- Player has Tier 8 | x100K Flame
	if Player.Stats.Tier.Value >= 9 then Tier_Bonus = 1.5e6 end -- Player has Tier 9 | x1.5M Flame
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 5e8 end -- Player has Tier 10 | x500M Flame

	Value = EN.mul(Value, Upgrades("RP_Flame"):GetEffect(Player.Upgrades.RP_Flame.Value, Player))
	Value = EN.mul(Value, Upgrades("Power_Flame"):GetEffect(Player.Upgrades.Power_Flame.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Flame"):GetEffect(Player.Upgrades.Flesh_Flame.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Flame1"):GetEffect(Player.Upgrades.Prisms_Flame1.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Flame2"):GetEffect(Player.Upgrades.Prisms_Flame2.Value, Player))
	Value = EN.mul(Value, Upgrades("Orbs_Flame"):GetEffect(Player.Upgrades.Orbs_Flame.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Flame"):GetEffect(Player.Upgrades.Spheres_Flame.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Flame"):GetEffect(Player.Upgrades.Tickets_Flame.Value, Player))
	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Rare_Flame(Player.Runes.Rare.Value))
		Value = EN.mul(Value, RuneFormulas.Ascendant_Flame(Player.Runes.Ascendant.Value))
		Value = EN.mul(Value, RuneFormulas.Exotic_Flame(Player.Runes.Exotic.Value))
		Value = EN.mul(Value, RuneFormulas.Chrome_Flame(Player.Runes.Chrome.Value))
		Value = EN.mul(Value, RuneFormulas.Rainbow_Flame(Player.Runes.Rainbow.Value))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Flame(Player.Runes.Vibrance.Value))
		Value = EN.mul(Value, RuneFormulas.Moss_Flame(Player.Runes.Moss.Value))
		Value = EN.mul(Value, RuneFormulas.Skylight_Flame(Player.Runes.Skylight.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Flame(Player.Runes.Thunderstorm.Value))
		Value = EN.mul(Value, RuneFormulas.Emberglow_Flame(Player.Runes.Emberglow.Value))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Flame(Player.Runes.Lightmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Flame(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Intermediate_Flame(Player.Runes.Intermediate.Value))
		Value = EN.mul(Value, RuneFormulas.Master_Flame(Player.Runes.Master.Value))
		Value = EN.mul(Value, RuneFormulas.Royalty_Flame(Player.Runes.Royalty.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Rare_Flame(Player.Runes.Rare.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Ascendant_Flame(Player.Runes.Ascendant.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Exotic_Flame(Player.Runes.Exotic.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Chrome_Flame(Player.Runes.Chrome.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Rainbow_Flame(Player.Runes.Rainbow.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Flame(Player.Runes.Vibrance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Moss_Flame(Player.Runes.Moss.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Skylight_Flame(Player.Runes.Skylight.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Flame(Player.Runes.Thunderstorm.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Emberglow_Flame(Player.Runes.Emberglow.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Flame(Player.Runes.Lightmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Flame(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Intermediate_Flame(Player.Runes.Intermediate.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Master_Flame(Player.Runes.Master.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Royalty_Flame(Player.Runes.Royalty.Value ^ 0.33))
	end

	if Player.Upgrades.Flesh_Flame2.Value > 0 and EN.meeq(Player.Stats.Prisms.Value, 1) then
		local Offset = EN.div(Player.Stats.Prisms.Value, 1)
		Value = EN.mul(Value, EN.mul(100, Offset))
	end

	--// Final Calculations \\--
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Orbs_Flame(Player.Stats.Orbs.Value))
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))
	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end

	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	if Player.Upgrades.Flesh_Flame2.Value > 0 then
		Value = EN.mul(Value, Formulas.Prisms_Flame(EN.convert(Player.Stats.Prisms.Value)))
	end
	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Challenges ]--
	if Player.Stats.C1.Value then Value = EN.mul(Value, 1e12) end
	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.C3.Value and EN.me(Value, 1) then Value = EN.pow(Value, 1.1) end
	if Player.Stats.CurrentChallenge.Value == "C1" and EN.me(Value, 1) then Value = EN.pow(Value, 0.425) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.RealmPoints(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	if Player.Stats.CurrentChallenge.Value == "C3" then return 0 end
	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 4 then Tier_Bonus = 1.25 end -- Player has Tier 4 | 1.25 RealmPoints
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 1.5 end -- Player has Tier 5 | x1.5 RealmPoints
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 3 end -- Player has Tier 6 | x3 RealmPoints
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 9 end -- Player has Tier 7 | x9 RealmPoints
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 27 end -- Player has Tier 8 | x27 RealmPoints
	Value = EN.mul(Value, Formulas.Orbs_RealmPoints(Player.Stats.Orbs.Value, Player))

	--[ Upgrades ]--
	Value = EN.mul(Value, Upgrades("Flesh_RP"):GetEffect(Player.Upgrades.Flesh_RP.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_RP1"):GetEffect(Player.Upgrades.Prisms_RP1.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_RP2"):GetEffect(Player.Upgrades.Prisms_RP2.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_RP"):GetEffect(Player.Upgrades.RP_RP.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_RP2"):GetEffect(Player.Upgrades.RP_RP2.Value, Player))
	--Value = EN.mul(Value, Upgrades("RP_Power"):GetEffect(Player.Upgrades.RP_Power.Value, Player))
	
	--[ Rune Effects]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Unknown_RealmPoints(Player.Runes.Unknown.Value))
		Value = EN.mul(Value, RuneFormulas.Neon_RealmPoints(Player.Runes.Neon.Value))
		Value = EN.mul(Value, RuneFormulas.Dew_RealmPoints(Player.Runes.Dew.Value))
		Value = EN.mul(Value, RuneFormulas.Nightshade_RealmPoints(Player.Runes.Nightshade.Value))
		Value = EN.mul(Value, RuneFormulas.Earthvein_RealmPoints(Player.Runes.Earthvein.Value))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_RealmPoints(Player.Runes.Lightmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_RealmPoints(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Glow_RealmPoints(Player.Runes.Glow.Value))
		Value = EN.mul(Value, RuneFormulas.Iridium_RealmPoints(Player.Runes.Iridium.Value))
		Value = EN.mul(Value, RuneFormulas.Legend_RealmPoints(Player.Runes.Legend.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Unknown_RealmPoints(Player.Runes.Unknown.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Neon_RealmPoints(Player.Runes.Neon.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Dew_RealmPoints(Player.Runes.Dew.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Nightshade_RealmPoints(Player.Runes.Nightshade.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Earthvein_RealmPoints(Player.Runes.Earthvein.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_RealmPoints(Player.Runes.Lightmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_RealmPoints(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Glow_RealmPoints(Player.Runes.Glow.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Iridium_RealmPoints(Player.Runes.Iridium.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Legend_RealmPoints(Player.Runes.Legend.Value ^ 0.33))
	end

	Value = EN.mul(Value, Tier_Bonus)

	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	
	--[ Server Elixir ]--
	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end
	
	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end
	
	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	
	--[ Ascension Bonus ]--
	if Player.Stats.AscensionOne.Value then
		Value = EN.mul(Value, 10)
	end

	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.CurrentChallenge.Value == "C1" and EN.me(Value, 1) then Value = EN.pow(Value, 0.425) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.ArcticPoints(Player: Player, Gain: number)
	
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 12 then Tier_Bonus *= 1.5 end -- Player has Tier 12 | x1.5 Arctic Points
	if Player.Stats.Tier.Value >= 13 then Tier_Bonus *= 5 end -- Player has Tier 13 | x5 Arctic Points
	
	Value = EN.mul(Value, Upgrades("Chromium_AP1"):GetEffect(Player.Upgrades.Chromium_AP1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_AP6"):GetEffect(Player.Upgrades.Chromium_AP6.Value, Player))
	Value = EN.mul(Value, Upgrades("Droplets_AP1"):GetEffect(Player.Upgrades.Droplets_AP1.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_AP1"):GetEffect(Player.Upgrades.AP_AP1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze2"):GetEffect(Player.Upgrades.Freeze2.Value, Player, "ArcticPoints"))
	Value = EN.mul(Value, Upgrades("Freeze4"):GetEffect(Player.Upgrades.Freeze4.Value, Player, "ArcticPoints"))
	
	Value = EN.mul(Value, RuneFormulas.Shiver_ArcticPoints(Player.Runes.Shiver.Value))
	Value = EN.mul(Value, RuneFormulas.Frigid_ArcticPoints(Player.Runes.Frigid.Value))
	Value = EN.mul(Value, RuneFormulas.Avalanche_ArcticPoints(Player.Runes.Avalanche.Value))
	Value = EN.mul(Value, RuneFormulas.Frostveil_ArcticPoints(Player.Runes.Frostveil.Value))
	Value = EN.mul(Value, RuneFormulas.Omnipotent_ArcticPoints(Player.Runes.Omnipotent.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_ArcticPoints(Player.Runes.Almighty.Value))
	Value = EN.mul(Value, RuneFormulas.Throne_ArcticPoints(Player.Runes.Throne.Value))
	Value = EN.mul(Value, RuneFormulas.Glyph_ArcticPoints(Player.Runes.Glyph.Value))
	

	
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end
	
	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 4 then Chromatize_Bonus *= 3 end -- Player has Chromatize 4 | x3 Arctic Points
	Value = EN.mul(Value, Chromatize_Bonus)
	
	local FreezeMultipler = 1
	if Player.Upgrades.Freeze2.Value >= 1 then FreezeMultipler *= 2 end
	if Player.Upgrades.Freeze4.Value >= 1 then FreezeMultipler *= 4 end

	Value = EN.mul(Value, FreezeMultipler)
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end
	
	return Value
end

function Formulas.Tier(Player : Player, Gain : number)
	local Value = Gain or 1

	--// Put Milestones or Upgrades or something below here \\--

	return Value
end

function Formulas.Power(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	--// Put Milestones or Upgrades or something below here \\--
	-- Flame Scale
	local Flame = Player.Stats.Flame.Value
	if EN.me(Flame, 0) then
		local Offset = EN.sub(Flame, 50)
		if EN.me(Offset, 0) then
			local Div_Offset = EN.div(Offset, 50)
			Value = EN.add(Value, Div_Offset)
		end
	end
	-- Tier Scale
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 3 then Tier_Bonus = 2 end -- Player has Tier 3 | x2 Power
	if Player.Stats.Tier.Value >= 4 then Tier_Bonus = 4 end -- Player has Tier 4 | x4 Power
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 16 end -- Player has Tier 5 | x16 Power
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 80 end -- Player has Tier 6 | x80 Power
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 250 end -- Player has Tier 7 | x250 Power
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 1e4 end -- Player has Tier 8 | x10K Power
	if Player.Stats.Tier.Value >= 9 then Tier_Bonus = 7.5e5 end -- Player has Tier 9 | x750K Power
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 5e7 end -- Player has Tier 10 | x50M Power

	-- [ Upgrades ]--
	Value = EN.mul(Value, Upgrades("Power_Power"):GetEffect(Player.Upgrades.Power_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Power"):GetEffect(Player.Upgrades.RP_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Power"):GetEffect(Player.Upgrades.Flesh_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Power"):GetEffect(Player.Upgrades.Prisms_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Power"):GetEffect(Player.Upgrades.Spheres_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Power"):GetEffect(Player.Upgrades.Tickets_Power.Value, Player))

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Exotic_Power(Player.Runes.Exotic.Value))
		Value = EN.mul(Value, RuneFormulas.Radiance_Power(Player.Runes.Radiance.Value))
		Value = EN.mul(Value, RuneFormulas.Oak_Power(Player.Runes.Oak.Value))
		Value = EN.mul(Value, RuneFormulas.Skylight_Power(Player.Runes.Skylight.Value))
		Value = EN.mul(Value, RuneFormulas.Wavecaller_Power(Player.Runes.Wavecaller.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Power(Player.Runes.Thunderstorm.Value))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Power(Player.Runes.Lightmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Power(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Experienced_Power(Player.Runes.Experienced.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Exotic_Power(Player.Runes.Exotic.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Radiance_Power(Player.Runes.Radiance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Oak_Power(Player.Runes.Oak.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Skylight_Power(Player.Runes.Skylight.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Wavecaller_Power(Player.Runes.Wavecaller.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Power(Player.Runes.Thunderstorm.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Power(Player.Runes.Lightmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Power(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Experienced_Power(Player.Runes.Experienced.Value ^ 0.33))
	end

	--// Final Calculation \\--
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Orbs_Power(Player.Stats.Orbs.Value))
	Value = EN.mul(Value, Formulas.Cube_Power(Player.Stats.Cube_Level.Value))
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end

	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.CurrentChallenge.Value == "C1" and EN.me(Value, 1) then Value = EN.pow(Value, 0.425) end
	if Player.Stats.CurrentChallenge.Value == "C4"  and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Damage(Player : Player, Gain : number)
	local Value = Gain or 1

	--// Put Milestones or Upgrades or something below here \\--
	Value = EN.mul(Value, Formulas.Power_Damage(Player.Stats.Power.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_DMG"):GetEffect(Player.Upgrades.RP_DMG.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_DMG2"):GetEffect(Player.Upgrades.RP_DMG2.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_DMG"):GetEffect(Player.Upgrades.Flesh_DMG.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Damage"):GetEffect(Player.Upgrades.Prisms_Damage.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_DMG"):GetEffect(Player.Upgrades.Spheres_DMG.Value, Player))
	
	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Neon_Damage(Player.Runes.Neon.Value))
		Value = EN.mul(Value, RuneFormulas.Rainbow_Damage(Player.Runes.Rainbow.Value))
		Value = EN.mul(Value, RuneFormulas.Moss_Damage(Player.Runes.Moss.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Damage(Player.Runes.Thunderstorm.Value))
		Value = EN.mul(Value, RuneFormulas.Dreamscape_Damage(Player.Runes.Dreamscape.Value))
		Value = EN.mul(Value, RuneFormulas.Experienced_Damage(Player.Runes.Experienced.Value))
	end

	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreDamage.Value then Value = EN.mul(Value, 3) end
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	--// Final Calculation \\--
	if Player.Stats.C2.Value then Value = EN.mul(Value, 50) end
	if Player.Stats.CurrentChallenge.Value == "C4"  and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Flesh(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 2.5 end -- Player has Tier 5 | x2.5 Flesh
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 10 end -- Player has Tier 6 | x10 Flesh
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 250 end -- Player has Tier 7 | x250 Flesh
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 2e4 end -- Player has Tier 8 | x20K Flesh
	if Player.Stats.Tier.Value >= 9 then Tier_Bonus = 5e6 end -- Player has Tier 9 | x5M Flesh
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 2.5e9 end -- Player has Tier 10 | x2.5B Flesh

	--[ Upgrades ]--
	Value = EN.mul(Value, Upgrades("Power_Flesh"):GetEffect(Player.Upgrades.Power_Flesh.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Power"):GetEffect(Player.Upgrades.Flesh_Power.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Flesh"):GetEffect(Player.Upgrades.Prisms_Flesh.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Multi"):GetEffect(Player.Upgrades.Prisms_Multi.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Flesh"):GetEffect(Player.Upgrades.Spheres_Flesh.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Flesh"):GetEffect(Player.Upgrades.Tickets_Flesh.Value, Player))

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Colorful_Flesh(Player.Runes.Colorful.Value))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Flesh(Player.Runes.Vibrance.Value))
		Value = EN.mul(Value, RuneFormulas.Nightshade_Flesh(Player.Runes.Nightshade.Value))
		Value = EN.mul(Value, RuneFormulas.Wavecaller_Flesh(Player.Runes.Wavecaller.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Flesh(Player.Runes.Vibrance.Value))
		Value = EN.mul(Value, RuneFormulas.Emberglow_Flesh(Player.Runes.Emberglow.Value))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Flesh(Player.Runes.Lightmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Flesh(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Iridium_Flesh(Player.Runes.Iridium.Value))
		Value = EN.mul(Value, RuneFormulas.Spectrum_Flesh(Player.Runes.Spectrum.Value))
		Value = EN.mul(Value, RuneFormulas.Master_Flesh(Player.Runes.Master.Value))
		Value = EN.mul(Value, RuneFormulas.Legend_Flesh(Player.Runes.Legend.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Colorful_Flesh(Player.Runes.Colorful.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Flesh(Player.Runes.Vibrance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Nightshade_Flesh(Player.Runes.Nightshade.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Wavecaller_Flesh(Player.Runes.Wavecaller.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Flesh(Player.Runes.Vibrance.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Emberglow_Flesh(Player.Runes.Emberglow.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Lightmatter_Flesh(Player.Runes.Lightmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Flesh(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Iridium_Flesh(Player.Runes.Iridium.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Spectrum_Flesh(Player.Runes.Spectrum.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Master_Flesh(Player.Runes.Master.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Legend_Flesh(Player.Runes.Legend.Value ^ 0.33))
	end

	if EN.meeq(Player.Stats.Spheres.Value, 1e98) then
		Value = EN.mul(Value, 1e15)
	end
	
	if EN.meeq(Player.Stats.Spheres.Value, 1e150) then
		local Cube_Offset = Player.Stats.Cube_Level.Value ^ 3
		Value = EN.mul(Value, Cube_Offset)
	end
	
	local gotLoot = false 
	if Player.Stats.Loot.Value >= 1 then 
		local LootBoost = 1+math.min(Player.Stats.Loot.Value * 0.05, 1000)
		Value = EN.mul(Value, LootBoost)
		gotLoot = true
	end
	
	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Server Elixir ]--
	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--// Final Calculation \\--
	Value = EN.mul(Value, Formulas.Orbs_Flesh(Player.Stats.Orbs.Value))
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end


	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Prisms(Player : Player, Gain : number, nextIce : boolean)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 6 then Tier_Bonus = 1.5 end -- Player has Tier 6 | x1.5 Prisms
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 2 end -- Player has Tier 7 | x2 Prisms
	if Player:GetAttribute("Prisms_X2") then
		Value = EN.mul(Value, 2)
	end
	Value = EN.mul(Value, Upgrades("Prisms_Prisms1"):GetEffect(Player.Upgrades.Prisms_Prisms1.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Prisms2"):GetEffect(Player.Upgrades.Prisms_Prisms2.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Prisms"):GetEffect(Player.Upgrades.RP_Prisms.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Prisms1"):GetEffect(Player.Upgrades.Chromium_Prisms1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Prisms2"):GetEffect(Player.Upgrades.Chromium_Prisms2.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Prisms4"):GetEffect(Player.Upgrades.Chromium_Prisms4.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_Prisms1"):GetEffect(Player.Upgrades.AP_Prisms1.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_Prisms2"):GetEffect(Player.Upgrades.AP_Prisms2.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze5"):GetEffect(Player.Upgrades.Freeze5.Value, Player, "Prisms"))
	Value = EN.mul(Value, Upgrades("Freeze8"):GetEffect(Player.Upgrades.Freeze8.Value, Player, "Prisms"))
	
	if Player.Stats.Draco_Follow then
		Value = EN.mul(Value, 1.25)
	end
	
	-- [Chromatize Effects] --
	
	if Player.Stats.Chromatize.Value >= 1 then
		local Chromatize_Bonus = 3 ^ Player.Stats.Chromatize.Value 

		if Chromatize_Bonus > 1e300 then 
			Chromatize_Bonus = 1e300
		end
		Value = EN.mul(Value, Chromatize_Bonus)
	end

	Value = EN.mul(Value, EN.add(1, EN.mul(Player.Stats.Chromium.Value, 0.05)))

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Chrome_Prisms(Player.Runes.Chrome.Value))
		Value = EN.mul(Value, RuneFormulas.Skylight_Prisms(Player.Runes.Skylight.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Prisms(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Shimmer_Prisms(Player.Runes.Shimmer.Value))
		Value = EN.mul(Value, RuneFormulas.Spectrum_Prisms(Player.Runes.Spectrum.Value))
		Value = EN.mul(Value, RuneFormulas.Refraction_Prisms(Player.Runes.Refraction.Value))
		Value = EN.mul(Value, RuneFormulas.Champion_Prisms(Player.Runes.Champion.Value))
		Value = EN.mul(Value, RuneFormulas.Elite_Prisms(Player.Runes.Elite.Value))
		Value = EN.mul(Value, RuneFormulas.Crown_Prisms(Player.Runes.Crown.Value))
		Value = EN.mul(Value, RuneFormulas.Dust_Prisms(Player.Runes.Dust.Value))
	else
		Value = EN.mul(Value, RuneFormulas.Chrome_Prisms(Player.Runes.Chrome.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Skylight_Prisms(Player.Runes.Skylight.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Prisms(Player.Runes.Darkmatter.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Shimmer_Prisms(Player.Runes.Shimmer.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Spectrum_Prisms(Player.Runes.Spectrum.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Refraction_Prisms(Player.Runes.Refraction.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Champion_Prisms(Player.Runes.Champion.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Elite_Prisms(Player.Runes.Elite.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Crown_Prisms(Player.Runes.Crown.Value ^ 0.33))
		Value = EN.mul(Value, RuneFormulas.Dust_Prisms(Player.Runes.Dust.Value ^ 0.33))
	end

	if Player.Upgrades.Chromium_Prisms3.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Prisms Boost
		local Chromium_Offset = EN.pow(Player.Stats.Prisms.Value, 0.9) -- This is supposed to be +0.05x Prisms per 1 Chromium, cap of 3 levels up to +0.15x per 1
		if EN.le(Chromium_Offset, 10) then
			Value = EN.mul(Value, Chromium_Offset)
		end	
	end
	
	if Player.Upgrades.Chromium_Prisms5.Value > 0 and EN.me(Player.Stats.Mobs_Level.Value, 0) then -- Mob Level >> Prisms Boost
		local MobLevel_Offset = EN.pow(Player.Stats.Mobs_Level.Value, 0.9) -- This is supposed to be 1 Mob level = +5x Prisms
		
		if EN.le(MobLevel_Offset, 10) then	
			Value = EN.mul(Value, MobLevel_Offset)
		end		
	end
	
	if Player.Upgrades.Chromium_Icicles3.Value > 0 and EN.me(Player.Stats.Icicles.Value, 0) then -- Icicles >> Prisms Boost
		local Icicles_Offset = EN.pow(Player.Stats.Prisms.Value, 0.5) -- Icicles >> Prisms ^0.5
		
		if EN.le(Icicles_Offset,10) then
			Value = EN.mul(Value, Icicles_Offset)
		end		
	end
	
	--[ Buffs ]--
	if Player.Stats.Cube_Level.Value >= 400 then
		Value = EN.mul(Value, Formulas.Prisms_Prisms(Player.Stats.Prisms.Value))
	end
	
	if Player.Upgrades.Prisms_Prisms4.Value >= 1 then
		Value = EN.mul(Value, Formulas.Playtime_Prisms(Player.Stats.Playtime.Value))
	end
	
	if Player.Upgrades.Flesh_Prisms.Value >= 1 then
		local Offset = 1 + (Player.Stats.Runes_Opened.Value / 1e8)
		if Offset > 1e300 then Offset = 1e300 end
		Value = EN.mul(Value, Offset)
	end
	
	local gotHail = false 
	if Player.Stats.Hail.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Hail.Value * 0.5, 1000))
		gotHail = true
	end
	
	local gotChroma = false 
	if Player.Stats.Chroma.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Chroma.Value * 1, 1e300))
		gotChroma = true
	end

	--// Final Calculation \\--
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	--[ Ascension Bonus ]--
	if Player.Stats.AscensionOne.Value then
		Value = EN.mul(Value, 3)
	end
	
	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	--if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.MorePrisms.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end

	if Player.Stats.C1.Value then Value = EN.mul(Value, 2) end
	if Player.Stats.C4.Value then Value = EN.mul(Value, 15) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	if Player.Upgrades.Chromium_Icicles3.Value >= 1 then
		local addAmount = nextIce and 1 or 0
		local Icicles = EN.add(Player.Stats.Icicles.Value,1 + addAmount)
		Value = EN.mul(Value, EN.pow(Icicles,0.5))
	end

	local FreezeMultiplier = 1
	if Player.Upgrades.Freeze5.Value >= 1 then FreezeMultiplier *= 50 end
	if Player.Upgrades.Freeze8.Value >= 1 then FreezeMultiplier *= 3 end

	Value = EN.mul(Value, FreezeMultiplier)

	return Value
end

function Formulas.Orbs(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 8 then Tier_Bonus = 4 end -- Player has Tier 8 | x4 Orbs
	if Player.Stats.Tier.Value >= 9 then Tier_Bonus = 50 end -- Player has Tier 9 | x50 Orbs
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 5e3 end -- Player has Tier 10 | x5K Orbs

	Value = EN.mul(Value, Upgrades("Flesh_Orbs"):GetEffect(Player.Upgrades.Flesh_Orbs.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Orbs2"):GetEffect(Player.Upgrades.Flesh_Orbs2.Value, Player))
	Value = EN.mul(Value, Upgrades("Orbs_Orbs"):GetEffect(Player.Upgrades.Orbs_Orbs.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Orbs1"):GetEffect(Player.Upgrades.Prisms_Orbs2.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Orbs2"):GetEffect(Player.Upgrades.Prisms_Orbs2.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Orbs"):GetEffect(Player.Upgrades.RP_Orbs.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Orbs2"):GetEffect(Player.Upgrades.RP_Orbs2.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Orbs"):GetEffect(Player.Upgrades.Spheres_Orbs.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_Orbs2"):GetEffect(Player.Upgrades.Spheres_Orbs2.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Orbs"):GetEffect(Player.Upgrades.Tickets_Orbs.Value, Player))
	Value = EN.mul(Value, Formulas.Cube_Orbs(Player.Stats.Cube_Level.Value))

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Chrome_Orbs(Player.Runes.Chrome.Value))
		Value = EN.mul(Value, RuneFormulas.Rainbow_Orbs(Player.Runes.Rainbow.Value))
		Value = EN.mul(Value, RuneFormulas.Vibrance_Orbs(Player.Runes.Vibrance.Value))
		Value = EN.mul(Value, RuneFormulas.Nightshade_Orbs(Player.Runes.Nightshade.Value))
		Value = EN.mul(Value, RuneFormulas.Thunderstorm_Orbs(Player.Runes.Thunderstorm.Value))
		Value = EN.mul(Value, RuneFormulas.Earthvein_Orbs(Player.Runes.Earthvein.Value))
		Value = EN.mul(Value, RuneFormulas.Emberglow_Orbs(Player.Runes.Emberglow.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Orbs(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Shimmer_Orbs(Player.Runes.Shimmer.Value))
		Value = EN.mul(Value, RuneFormulas.Iridium_Orbs(Player.Runes.Iridium.Value))
		Value = EN.mul(Value, RuneFormulas.Champion_Orbs(Player.Runes.Champion.Value))
		Value = EN.mul(Value, RuneFormulas.Elite_Orbs(Player.Runes.Elite.Value))
		Value = EN.mul(Value, RuneFormulas.Imperial_Orbs(Player.Runes.Imperial.Value))
		Value = EN.mul(Value, RuneFormulas.Kingslayer_Orbs(Player.Runes.Kingslayer.Value))
		Value = EN.mul(Value, RuneFormulas.Bone_Orbs(Player.Runes.Bone.Value))
		Value = EN.mul(Value, RuneFormulas.Mad_Orbs(Player.Runes.Mad.Value))
	end

	if Player.Upgrades.Prisms_OrbsEnhance.Value > 0 and EN.me(Player.Stats.Prisms.Value, 0) then -- Prisms >> Orbs Boost
		local Prisms_Offset = EN.pow(Player.Stats.Prisms.Value, 0.9) -- Prisms 0.9 ^ 
		Value = EN.mul(Value, Prisms_Offset)
	end
	
	if Player.Upgrades.Prisms_RPEnhance.Value > 0 then -- Orbs >> RP Boost
		Value = EN.mul(Value, Formulas.Orbs_RP(Player.Stats.Orbs.Value))
	end
	

	if EN.meeq(Player.Stats.Spheres.Value, 2.5e17) then
		Value = EN.mul(Value, 25)
	end
	
	if EN.meeq(Player.Stats.Spheres.Value, 1e184) and Player.Stats.Mobs_TotalKilled.Value then
		local MobKill_Offset = (1 + Player.Stats.Mobs_TotalKilled.Value) ^ 3
		Value = EN.mul(Value, MobKill_Offset)
	end
	
	--// Final Calculation \\--
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	
	--[ Ascension Bonus ]--
	if Player.Stats.AscensionOne.Value then
		Value = EN.mul(Value, 5e4)
	end

	--[ Challenges ]--
	if Player.Stats.C1.Value then Value = EN.mul(Value, 1e6) end
	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.C3.Value and EN.me(Value, 1) then Value = EN.pow(Value, 1.1) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Spheres(Player : Player, Gain : number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)

	--// Put Milestones or Upgrades or something below here \\--
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 25 end -- Player has Tier 10 | x25 Spheres

	Value = EN.mul(Value, Formulas.Spheres_Spheres(Player.Stats.Sphere_Levels.Value))
	Value = EN.mul(Value, Upgrades("Prisms_Spheres3"):GetEffect(Player.Upgrades.Prisms_Spheres3.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Spheres2"):GetEffect(Player.Upgrades.Prisms_Spheres2.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Spheres1"):GetEffect(Player.Upgrades.Prisms_Spheres1.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Spheres"):GetEffect(Player.Upgrades.RP_Spheres.Value, Player))
	Value = EN.mul(Value, Upgrades("RP_Spheres2"):GetEffect(Player.Upgrades.RP_Spheres2.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Spheres"):GetEffect(Player.Upgrades.Flesh_Spheres.Value, Player))
	Value = EN.mul(Value, Upgrades("Flesh_Spheres2"):GetEffect(Player.Upgrades.Flesh_Spheres2.Value, Player))
	Value = EN.mul(Value, Upgrades("Power_Spheres"):GetEffect(Player.Upgrades.Power_Spheres.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Spheres"):GetEffect(Player.Upgrades.Tickets_Spheres.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Spheres5"):GetEffect(Player.Upgrades.Prisms_Spheres5.Value, Player))
	Value = EN.mul(Value, Upgrades("Droplets_Spheres1"):GetEffect(Player.Upgrades.Droplets_Spheres1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze6"):GetEffect(Player.Upgrades.Freeze6.Value, Player, "Spheres"))
	
	local DropletsValue = EN.add(Player.Stats.Droplets.Value, 1)
	Value = EN.mul(Value, DropletsValue)

	--[ Rune Effects ]--
	if Player.Stats.CurrentChallenge.Value ~= "C2" then
		Value = EN.mul(Value, RuneFormulas.Nightshade_Spheres(Player.Runes.Nightshade.Value))
		Value = EN.mul(Value, RuneFormulas.Wavecaller_Spheres(Player.Runes.Wavecaller.Value))
		Value = EN.mul(Value, RuneFormulas.Dreamscape_Spheres(Player.Runes.Dreamscape.Value))
		Value = EN.mul(Value, RuneFormulas.Darkmatter_Spheres(Player.Runes.Darkmatter.Value))
		Value = EN.mul(Value, RuneFormulas.Shimmer_Spheres(Player.Runes.Shimmer.Value))
		Value = EN.mul(Value, RuneFormulas.Mist_Spheres(Player.Runes.Mist.Value))
		Value = EN.mul(Value, RuneFormulas.Icequake_Spheres(Player.Runes.Icequake.Value))
		Value = EN.mul(Value, RuneFormulas.Snowflake_Spheres(Player.Runes.Snowflake.Value))
		Value = EN.mul(Value, RuneFormulas.Icy_Spheres(Player.Runes.Icy.Value))
		Value = EN.mul(Value, RuneFormulas.Omniscient_Spheres(Player.Runes.Omniscient.Value))
		Value = EN.mul(Value, RuneFormulas.Bloom_Spheres(Player.Runes.Bloom.Value))
		Value = EN.mul(Value, RuneFormulas.Legend_Spheres(Player.Runes.Legend.Value))
		Value = EN.mul(Value, RuneFormulas.Mad_Spheres(Player.Runes.Mad.Value))
	end
	
	if Player.Upgrades.Chromium_SpheresEnhance.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Spheres Boost
		if Player.Upgrades.Chromium_SpheresEnhance.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Spheres Boost
			local Chromium_Offset = EN.pow(Player.Stats.Spheres.Value, 0.75)
			if EN.le(Chromium_Offset, 1) then
				Chromium_Offset = EN.fromNumber(1)
			end
			Value = EN.mul(Value, Chromium_Offset)
		end
	end
	
	-- if Player.Stats.R2_Purchased.Value >= 1 and EN.me(Player.Stats.Droplets.Value, 0) then -- Droplets >> Spheres Boost
	--	local Droplets_Offset = EN.pow(Player.Stats.Spheres.Value, 0.25) -- This is supposed to be +x1 Spheres per 1 Droplet? Answer: yes
	--	Value = EN.mul(Value, Droplets_Offset)
	--end

	local iceValue = Player.Stats.Ice.Value
	Value = EN.mul(Value, EN.add(1, EN.mul(0.1, iceValue)))

	if EN.meeq(Player.Stats.Spheres.Value, 1e7) then
		Value = EN.mul(Value, 5)
	end
	
	if Player.Upgrades.Prisms_SpheresEnhance.Value > 0 and EN.me(Player.Stats["Realm Points"].Value, 0) then
		local Offset = EN.pow(Player.Stats["Realm Points"].Value, 0.1)
		Value = EN.mul(Value, Offset)
	end
	
	if Player.Upgrades.Power_Spheres2.Value > 0 then
		Value = EN.mul(Value, Formulas.Tickets_Spheres(Player.Stats.Tickets.Value))
	end
	
	--// Final Calculation \\--
	Value = EN.mul(Value, Tier_Bonus)
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	--[ Potions ]--
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end

	--[ Follow Reward ]--
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end

	if Player.Upgrades.Spheres_Spheres2.Value > 0 then
		Value = EN.mul(Value, Formulas.Power_Spheres(Player.Stats.Power.Value))
	end

	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.CurrentChallenge.Value == "C4" and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end
	
	local FreezeMultiplier = 1
	if Player.Upgrades.Freeze6.Value >= 1 then FreezeMultiplier *= 7 end

	Value = EN.mul(Value, FreezeMultiplier)

	return Value
end

function Formulas.Droplets(Player: Player, Gain: number, nextIce : boolean)
	local Value = Gain or 0.5
	Value = EN.mul(Value, 2) -- Event)
	
	
	local dropletsUpgrade = Player.Stats.Droplets_Multiplier
	Value = EN.mul(Value, dropletsUpgrade.Value)
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 11 then Tier_Bonus *= 3 end -- Player has Tier 11 | x3 Droplets
	if Player.Stats.Tier.Value >= 12 then Tier_Bonus *= 250 end -- Player has Tier 12 | x250 Droplets
	if Player.Stats.Tier.Value >= 13 then Tier_Bonus *= 4e4 end -- Player has Tier 11 | x40K Droplets
	
	Value = EN.mul(Value, Tier_Bonus)

	local waterValue = Player.Stats.Water
	
	Value = EN.mul(Value, EN.add(1, EN.mul(0.5, waterValue.Value)))
	
	Value = EN.mul(Value, Upgrades("Prisms_Droplets1"):GetEffect(Player.Upgrades.Prisms_Droplets1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Droplets2"):GetEffect(Player.Upgrades.Chromium_Droplets2.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Droplets1"):GetEffect(Player.Upgrades.Chromium_Droplets1.Value, Player))
	Value = EN.mul(Value, Upgrades("Droplets_Droplets1"):GetEffect(Player.Upgrades.Droplets_Droplets1.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_Droplets1"):GetEffect(Player.Upgrades.AP_Droplets1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze1"):GetEffect(Player.Upgrades.Freeze1.Value, Player, "Droplets"))
	Value = EN.mul(Value, Upgrades("Freeze4"):GetEffect(Player.Upgrades.Freeze4.Value, Player, "Droplets"))
	Value = EN.mul(Value, Upgrades("Tickets_Droplets"):GetEffect(Player.Upgrades.Tickets_Droplets.Value, Player))
	
	-- [Rune Effects] --
	Value = EN.mul(Value, RuneFormulas.Breeze_Droplets(Player.Runes.Breeze.Value))
	Value = EN.mul(Value, RuneFormulas.Frigid_Droplets(Player.Runes.Frigid.Value))
	Value = EN.mul(Value, RuneFormulas.Snowflake_Droplets(Player.Runes.Snowflake.Value))
	Value = EN.mul(Value, RuneFormulas.Frostveil_Droplets(Player.Runes.Frostveil.Value))
	Value = EN.mul(Value, RuneFormulas.Omniscient_Droplets(Player.Runes.Frostveil.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_Droplets(Player.Runes.Frostveil.Value))
	Value = EN.mul(Value, RuneFormulas.Monarch_Droplets(Player.Runes.Monarch.Value))
	Value = EN.mul(Value, RuneFormulas.Gilded_Droplets(Player.Runes.Gilded.Value))
	Value = EN.mul(Value, RuneFormulas.Master_Droplets(Player.Runes.Master.Value))
	Value = EN.mul(Value, RuneFormulas.Glyph_Droplets(Player.Runes.Glyph.Value))
	
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	
	--if Player.Upgrades.Chromium_Droplets1.Value > 0 and EN.me(Player.Stats.RuneSpeed.Value, 0) then -- Rune Speed >> Droplets Boost
	--	local RuneSpeed_Offset = EN.pow(Player.Stats.Droplets.Value, 1.5) -- RuneSpeed >> Droplets ^1.5
	--	Value = EN.mul(Value, RuneSpeed_Offset)
	--end
	
	--if EN.me(Player.Stats.Water.Value,  0) then -- Water >> Droplets Boost
	--	local Water_Offset = EN.add(Player.Stats.Droplets.Value, 0.5) -- 1 Water >> Droplets +0.5x
	--	Value = EN.mul(Value, Water_Offset)
	--end

	local gotHaze = false 
	if Player.Stats.Haze.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Haze.Value * 2, 100))
		gotHaze = true
	end
	
	local gotHail = false 
	if Player.Stats.Hail.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Hail.Value * 0.5, 1000))
		gotHail = true
	end


	local addAmount = nextIce and 1 or 0
	local Icicles = EN.add(Player.Stats.Icicles.Value,1 + addAmount)
	Value = EN.mul(Value, EN.pow(Icicles,2))
	
	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 2 then Chromatize_Bonus *= 1e4 end -- Player has Chromatize 2 | x10K Droplets
	Value = EN.mul(Value, Chromatize_Bonus)
	
	local FreezeMultiplier = 1	
	if Player.Upgrades.Freeze1.Value >= 1 then FreezeMultiplier *= 10 end
	if Player.Upgrades.Freeze4.Value >= 1 then FreezeMultiplier *= 100 end

	Value = EN.mul(Value, FreezeMultiplier)
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	
	return Value
end

function Formulas.Water(Player: Player, Gain: number, nextIce : boolean)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 11 then Tier_Bonus *= 1.5 end -- Player has Tier 11 | x1.5 Water
	if Player.Stats.Tier.Value >= 12 then Tier_Bonus *= 10 end -- Player has Tier 12 | x10 Water
	Value = EN.mul(Value, Tier_Bonus)

	Value = EN.mul(Value, Upgrades("Prisms_Water1"):GetEffect(Player.Upgrades.Prisms_Water1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Water1"):GetEffect(Player.Upgrades.Chromium_Water1.Value, Player))
	Value = EN.mul(Value, Upgrades("Droplets_Water1"):GetEffect(Player.Upgrades.Droplets_Water1.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_Water1"):GetEffect(Player.Upgrades.AP_Water1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze1"):GetEffect(Player.Upgrades.Freeze1.Value, Player, "Water"))
	Value = EN.mul(Value, Upgrades("Freeze2"):GetEffect(Player.Upgrades.Freeze2.Value, Player, "Water"))
	Value = EN.mul(Value, Upgrades("Freeze3"):GetEffect(Player.Upgrades.Freeze3.Value, Player, "Water"))
	Value = EN.mul(Value, Upgrades("Tickets_Water"):GetEffect(Player.Upgrades.Tickets_Water.Value, Player))

	-- [Rune Effects] --	
	Value = EN.mul(Value, RuneFormulas.Breeze_Water(Player.Runes.Breeze.Value))
	Value = EN.mul(Value, RuneFormulas.Shiver_Water(Player.Runes.Shiver.Value))
	Value = EN.mul(Value, RuneFormulas.Icequake_Water(Player.Runes.Icequake.Value))
	Value = EN.mul(Value, RuneFormulas.Snow_Water(Player.Runes.Snow.Value))
	Value = EN.mul(Value, RuneFormulas.Avalanche_Water(Player.Runes.Avalanche.Value))
	Value = EN.mul(Value, RuneFormulas.Subzero_Water(Player.Runes.Subzero.Value))
	Value = EN.mul(Value, RuneFormulas.Omniscient_Water(Player.Runes.Omniscient.Value))
	Value = EN.mul(Value, RuneFormulas.Omnipotent_Water(Player.Runes.Omnipotent.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_Water(Player.Runes.Almighty.Value))
	
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	local gotHaze = false 
	if Player.Stats.Haze.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Haze.Value * 2, 100))
		gotHaze = true
	end


	local Icevalue = Player.Stats.Ice.Value
	Value = EN.mul(Value, EN.add(1, Icevalue))

	if Player.Upgrades.Chromium_Icicles2.Value >= 1 then
		local addAmount = nextIce and 1 or 0
		local Icicles = EN.add(Player.Stats.Icicles.Value,1 + addAmount)
		Value = EN.mul(Value, EN.pow(Icicles,1))
	end

	if Player.Upgrades.Chromium_Icicles2.Value > 0 and EN.me(Player.Stats.Icicles.Value, 0) and EN.me(Player.Stats.Water.Value, 1) then -- Icicles >> Water Boost
		local Icicles_Offset = EN.pow(Player.Stats.Water.Value, 0.9) -- Icicles >> Water 0.9 ^ 
		Value = EN.mul(Value, Icicles_Offset)
	end
	

	local FreezeMultiplier = 1	
	if Player.Upgrades.Freeze1.Value >= 1 then FreezeMultiplier *= 3 end
	if Player.Upgrades.Freeze2.Value >= 1 then FreezeMultiplier *= 20 end
	if Player.Upgrades.Freeze3.Value >= 1 then FreezeMultiplier *= 5 end

	
	Value = EN.mul(Value, FreezeMultiplier)
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end


	return Value
end

function Formulas.Ice(Player: Player, Gain: number, nextIce : boolean)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 12 then Tier_Bonus *= 3 end -- Player has Tier 12 | x3 Ice
	Value = EN.mul(Value, Tier_Bonus)


	Value = EN.mul(Value, Upgrades("Chromium_Ice1"):GetEffect(Player.Upgrades.Chromium_Ice1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze3"):GetEffect(Player.Upgrades.Freeze3.Value, Player, "Ice"))
	Value = EN.mul(Value, Upgrades("Freeze5"):GetEffect(Player.Upgrades.Freeze5.Value, Player, "Ice"))
	Value = EN.mul(Value, Upgrades("Tickets_Ice"):GetEffect(Player.Upgrades.Tickets_Ice.Value, Player))

	-- [Rune Effects] --
	Value = EN.mul(Value, RuneFormulas.Frigid_Ice(Player.Runes.Frigid.Value))
	Value = EN.mul(Value, RuneFormulas.Icequake_Ice(Player.Runes.Icequake.Value))
	Value = EN.mul(Value, RuneFormulas.Snow_Ice(Player.Runes.Snow.Value))
	Value = EN.mul(Value, RuneFormulas.Avalanche_Ice(Player.Runes.Avalanche.Value))
	Value = EN.mul(Value, RuneFormulas.Omnipotent_Ice(Player.Runes.Omnipotent.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_Ice(Player.Runes.Almighty.Value))
	
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	
	if Player.Upgrades.Chromium_Ice2.Value > 0 and EN.me(Player.Stats.Ice.Value, 0) then -- Ice Boosts itself
		local Ice_Offset = EN.pow(Player.Stats.Ice.Value, 0.1) -- Ice ^0.1
		if EN.le(Ice_Offset, 1) then 
			Ice_Offset = EN(1)
		end
		Value = EN.mul(Value, Ice_Offset)
	end
	
	local gotHaze = false 
	if Player.Stats.Haze.Value >= 1 then 
		Value = EN.mul(Value, 1+math.min(Player.Stats.Haze.Value * 2, 100))
		gotHaze = true
	end

	if Player.Upgrades.Chromium_Icicles4.Value >= 1 then
		local addAmount = nextIce and 1 or 0
		local Icicles = EN.add(Player.Stats.Icicles.Value,1 + addAmount)
		Value = EN.mul(Value, EN.pow(Icicles,0.2))
	end

	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 2 then Chromatize_Bonus *= 10 end -- Player has Chromatize 2 | x10 Ice
	Value = EN.mul(Value, Chromatize_Bonus)

	local FreezeMultiplier = 1	
	if Player.Upgrades.Freeze3.Value >= 1 then FreezeMultiplier *= 3 end
	if Player.Upgrades.Freeze5.Value >= 1 then FreezeMultiplier *= 15 end

	Value = EN.mul(Value, FreezeMultiplier)
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	return Value
end

function Formulas.Chromium(Player: Player, Gain: number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 13 then Tier_Bonus *= 4 end -- Player has Tier 13 | x4 Chromium
	Value = EN.mul(Value, Tier_Bonus)

	Value = EN.mul(Value, Upgrades("Prisms_Chromium1"):GetEffect(Player.Upgrades.Prisms_Chromium1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Chromium1"):GetEffect(Player.Upgrades.Chromium_Chromium1.Value, Player))
	Value = EN.mul(Value, Upgrades("Droplets_Chromium1"):GetEffect(Player.Upgrades.Droplets_Chromium1.Value, Player))
	Value = EN.mul(Value, Upgrades("AP_Chromium1"):GetEffect(Player.Upgrades.AP_Chromium1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze5"):GetEffect(Player.Upgrades.Freeze5.Value, Player, "Chromium"))
	Value = EN.mul(Value, Upgrades("Freeze8"):GetEffect(Player.Upgrades.Freeze8.Value, Player, "Chromium"))
	Value = EN.mul(Value, Upgrades("Tickets_Chromium"):GetEffect(Player.Upgrades.Tickets_Chromium.Value, Player))
	
	if Player.Gamepasses.X2Chromium.Value > 0 then Value = EN.mul(Value, 2) end

	-- [Rune Effects] --
	Value = EN.mul(Value, RuneFormulas.Icy_Chromium(Player.Runes.Icy.Value))
	Value = EN.mul(Value, RuneFormulas.Hailstorm_Chromium(Player.Runes.Hailstorm.Value))
	Value = EN.mul(Value, RuneFormulas.Subzero_Chromium(Player.Runes.Subzero.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_Chromium(Player.Runes.Almighty.Value))
	Value = EN.mul(Value, RuneFormulas.Imperial_Chromium(Player.Runes.Imperial.Value))
	
	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 2 then Chromatize_Bonus *= 2 end -- Player has Chromatize 2 | x2 Chromium
	if Player.Stats.Chromatize.Value >= 4 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 4 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 5 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 5 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 6 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 6 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 7 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 7 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 8 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 8 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 9 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 9 | +0.25x Chromium Per level
	if Player.Stats.Chromatize.Value >= 10 then Chromatize_Bonus += 0.25 end -- Player has Chromatize 10 | +0.25x Chromium Per level
	Value = EN.mul(Value, Chromatize_Bonus)

	local FreezeMultiplier = 1
	if Player.Upgrades.Freeze5.Value >= 1 then FreezeMultiplier *= 3 end
	if Player.Upgrades.Freeze8.Value >= 1 then FreezeMultiplier *= 5 end

	Value = EN.mul(Value, FreezeMultiplier)
	if Player.Stats.Nexo_Follow.Value then Value = EN.mul(Value, 1.25) end

	return Value
end

function Formulas.Icicles(Player: Player, Gain: number)
	local Value = Gain or 1
	Value = EN.mul(Value, 2) -- Event)
	
	Value = EN.mul(Value, Upgrades("Chromium_Icicles1"):GetEffect(Player.Upgrades.Chromium_Icicles1.Value, Player))
	Value = EN.mul(Value, Upgrades("Freeze7"):GetEffect(Player.Upgrades.Freeze7.Value, Player, "Icicles"))
	Value = EN.mul(Value, Upgrades("Tickets_Icicles"):GetEffect(Player.Upgrades.Tickets_Icicles.Value, Player))
	
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end

	-- [Rune Effects] --
	Value = EN.mul(Value, RuneFormulas.Avalanche_Icicles(Player.Runes.Avalanche.Value))
	Value = EN.mul(Value, RuneFormulas.Frostveil_Icicles(Player.Runes.Frostveil.Value))
	Value = EN.mul(Value, RuneFormulas.Almighty_Icicles(Player.Runes.Almighty.Value))
	
	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 7 then Chromatize_Bonus *= 1.5 end -- Player has Chromatize 7 | x1.5 Icicles Per level
	if Player.Stats.Chromatize.Value >= 8 then Chromatize_Bonus *= 1.5 end -- Player has Chromatize 8 | x1.5 Icicles Per level
	if Player.Stats.Chromatize.Value >= 9 then Chromatize_Bonus *= 1.5 end -- Player has Chromatize 9 | x1.5 Icicles Per level
	if Player.Stats.Chromatize.Value >= 10 then Chromatize_Bonus *= 1.5 end -- Player has Chromatize 10 | x1.5 Icicles Per level
	Value = EN.mul(Value, Chromatize_Bonus)
	
	local FreezeMultiplier = 1
	if Player.Upgrades.Freeze7.Value >= 1 then FreezeMultiplier *= 3 end

	Value = EN.mul(Value, FreezeMultiplier)
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end

	return Value
end

function Formulas.Haze(Player : Player, Gain : number)
	local Value = 1
	Value *= Formulas.Product_SecretStats(Player)
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	return Value
end

function Formulas.Shine(Player : Player, Gain : number)
	local Value = 1
	Value *= Formulas.Product_SecretStats(Player)
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	Value *= RuneFormulas.Mommy_Shine(Player.Runes.Mommy.Value)
	Value *= RuneFormulas.Soup_Shine(Player.Runes.Soup.Value)
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	Value *= Upgrades("Chromium_Shine1"):GetEffect(Player.Upgrades.Chromium_Shine1.Value, Player)
	Value *= Upgrades("Chromium_Shine2"):GetEffect(Player.Upgrades.Chromium_Shine2.Value, Player)
	return Value
end

function Formulas.Hail(Player : Player, Gain : number)
	local Value = 1
	
	Value *= RuneFormulas.Liberty_Hail(Player.Runes.Liberty.Value)
	Value *= Formulas.Product_SecretStats(Player)
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	Value *= Upgrades("Chromium_Hail1"):GetEffect(Player.Upgrades.Chromium_Hail1.Value, Player)
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	return Value
end

function Formulas.Loot(Player : Player, Gain : number)
	local Value = 1
	Value *= Formulas.Product_SecretStats(Player)
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	return Value
end

function Formulas.Light(Player : Player, Gain : number)
	local Value = 1
	Value += Upgrades("Chromium_Light9"):GetEffect(Player.Upgrades.Chromium_Light9.Value, Player)
	
	Value *= Formulas.Product_SecretStats(Player)
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Violence_Light(Player.Runes.Violence.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Hurricane_Light(Player.Runes.Hurricane.Value)
	Value *= RuneFormulas.Galaxy_Light(Player.Runes.Galaxy.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	Value *= RuneFormulas.Axium_Light(Player.Runes.Axium.Value)
	Value *= RuneFormulas.Paracosm_Light(Player.Runes.Paracosm.Value)
	Value *= Upgrades("Light_Light"):GetEffect(Player.Upgrades.Light_Light.Value, Player)
	Value *= Upgrades("Chromium_Light1"):GetEffect(Player.Upgrades.Chromium_Light1.Value, Player)
	Value *= Upgrades("Chromium_Light2"):GetEffect(Player.Upgrades.Chromium_Light2.Value, Player)
	Value *= Upgrades("Chromium_Light3"):GetEffect(Player.Upgrades.Chromium_Light3.Value, Player)
	Value *= Upgrades("Chromium_Light4"):GetEffect(Player.Upgrades.Chromium_Light4.Value, Player)
	Value *= Upgrades("Chromium_Light5"):GetEffect(Player.Upgrades.Chromium_Light5.Value, Player)
	Value *= Upgrades("Chromium_Light6"):GetEffect(Player.Upgrades.Chromium_Light6.Value, Player)
	Value *= Upgrades("Chromium_Light7"):GetEffect(Player.Upgrades.Chromium_Light7.Value, Player)
	Value *= Upgrades("Chromium_Light10"):GetEffect(Player.Upgrades.Chromium_Light10.Value, Player)
	Value *= Upgrades("Reflection_Light1"):GetEffect(Player.Upgrades.Reflection_Light1.Value)
	if Player.Stats.Chromify.Value >= 2 then
		Value *= 3
	end
	
	if Player.Stats.Chromify.Value >= 3 then
		Value *= 5
	end
	
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	
	local gotShine = false 
	if Player.Stats.Shine.Value >= 1 then 
		Value *= 1+math.min(Player.Stats.Shine.Value * 0.1, 1e300)
		gotShine = true
	end
	
	Value ^= Upgrades("Chromium_Light8"):GetEffect(Player.Upgrades.Chromium_Light8.Value, Player)
	return Value
end

function Formulas.Chroma(Player : Player, Gain : number)
	local Value = 1
	Value += Upgrades("Chromium_Chrome3"):GetEffect(Player.Upgrades.Chromium_Chrome3.Value)
	Value += Upgrades("Chromium_Chrome4"):GetEffect(Player.Upgrades.Chromium_Chrome4.Value)
	Value += Upgrades("Chromium_Chrome6"):GetEffect(Player.Upgrades.Chromium_Chrome6.Value)
	Value += Upgrades("Chromium_Chrome9"):GetEffect(Player.Upgrades.Chromium_Chrome9.Value)
	Value += Upgrades("Light_Chrome1"):GetEffect(Player.Upgrades.Light_Chrome1.Value)
	Value += RuneFormulas.Bozo_BaseChrome(Player.Runes.Bozo.Value)
	
	Value *= RuneFormulas.Eternal_AllSecret(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Vehemence_AllSecret(Player.Runes.Vehemence.Value)
	Value *= RuneFormulas.Malevolence_AllSecret(Player.Runes.Malevolence.Value)
	Value *= RuneFormulas.Raze_Chrome(Player.Runes.Raze.Value)
	Value *= RuneFormulas.Glint_Chrome1(Player.Runes.Glint.Value)
	Value *= RuneFormulas.Glint_Chrome2(Player.Runes.Glint.Value)
	Value *= RuneFormulas.Nexus_Chrome(Player.Runes.Nexus.Value)
	Value *= RuneFormulas.Rage_Chroma(Player.Runes.Rage.Value)
	Value *= RuneFormulas.Galaxy_Chroma(Player.Runes.Galaxy.Value)
	Value *= RuneFormulas.Violence_Chroma(Player.Runes.Violence.Value)
	Value *= RuneFormulas.Axium_Chroma(Player.Runes.Axium.Value)
	Value *= RuneFormulas.Hyperion_Chroma1(Player.Runes.Hyperion.Value)
	Value *= RuneFormulas.Hyperion_Chroma2(Player.Runes.Hyperion.Value)
	Value *= Upgrades("Chromium_Chrome1"):GetEffect(Player.Upgrades.Chromium_Chrome1.Value, Player)
	Value *= Upgrades("Chromium_Chrome2"):GetEffect(Player.Upgrades.Chromium_Chrome2.Value, Player)
	Value *= Upgrades("Chromium_Chrome5"):GetEffect(Player.Upgrades.Chromium_Chrome5.Value, Player)
	Value *= Upgrades("Chromium_Chrome7"):GetEffect(Player.Upgrades.Chromium_Chrome7.Value, Player)
	Value *= Upgrades("Chromium_Chrome8"):GetEffect(Player.Upgrades.Chromium_Chrome8.Value, Player)
	Value *= Upgrades("Chromium_Chrome10"):GetEffect(Player.Upgrades.Chromium_Chrome10.Value, Player)
	Value *= Upgrades("Chromium_Chrome11"):GetEffect(Player.Upgrades.Chromium_Chrome11.Value, Player)
	Value *= Upgrades("Chromium_Chrome12"):GetEffect(Player.Upgrades.Chromium_Chrome12.Value, Player)
	Value *= Upgrades("Chromium_Chrome13"):GetEffect(Player.Upgrades.Chromium_Chrome13.Value, Player)
	Value *= Upgrades("Chromium_Chrome15"):GetEffect(Player.Upgrades.Chromium_Chrome15.Value, Player)
	Value *= Upgrades("Chromium_Chrome16"):GetEffect(Player.Upgrades.Chromium_Chrome16.Value, Player)
	Value *= Upgrades("Chromium_Chrome17"):GetEffect(Player.Upgrades.Chromium_Chrome17.Value, Player)
	Value *= Upgrades("Chromium_Chrome18"):GetEffect(Player.Upgrades.Chromium_Chrome18.Value, Player)
	Value *= Upgrades("Chromium_Chrome19"):GetEffect(Player.Upgrades.Chromium_Chrome19.Value, Player)
	Value *= Upgrades("Chromium_Chrome21"):GetEffect(Player.Upgrades.Chromium_Chrome21.Value, Player)
	Value *= Upgrades("Chromium_Chrome22"):GetEffect(Player.Upgrades.Chromium_Chrome22.Value, Player)
	Value *= Upgrades("Tickets_Chrome1"):GetEffect(Player.Upgrades.Tickets_Chrome1.Value, Player)
	
	Value *= Upgrades("Light_Chrome2"):GetEffect(Player.Upgrades.Light_Chrome2.Value)
	
	Value *= Upgrades("Reflection_Chrome1"):GetEffect(Player.Upgrades.Reflection_Chrome1.Value)
	
	if Player.Stats.Chromify.Value >= 3 then
		Value *= 10
	end
	
	
	if Player:GetAttribute("ServerBoosted") then Value *= 1.25 end
	
	local gotLight = false 
	if Player.Stats.Light.Value >= 1 then 
		Value *= 1+math.min(Player.Stats.Light.Value * 0.05, 1e300)
		gotLight = true
	end
	
	local gotShine = false 
	if Player.Stats.Shine.Value >= 1 then 
		Value *= 1+math.min(Player.Stats.Shine.Value * 0.01, 1e300)
		gotShine = true
	end
	
	Value *= Formulas.Product_SecretStats(Player)
	
	Value ^= Upgrades("Chromium_Chrome20"):GetEffect(Player.Upgrades.Chromium_Chrome20.Value, Player)
	Value ^= Upgrades("Chromium_Chrome14"):GetEffect(Player.Upgrades.Chromium_Chrome14.Value, Player)
	return Value
end

function Formulas.Reflection(Player : Player, Gain : number)
	local Value = Gain or 1

	--// Put Milestones or Upgrades or something below here \\--
	-- Flame Scale
	local Light = Player.Stats.Light.Value
	if EN.me(Light, 0) then
		local Offset = EN.sub(Light, 1e20)
		if EN.me(Offset, 0) then
			local Div_Offset = EN.div(Offset, 1e20)
			Value = EN.add(Value, Div_Offset)
		end
	end
	
	Value = EN.mul(Value, Upgrades("Chromium_Reflection1"):GetEffect(Player.Upgrades.Chromium_Reflection1.Value, Player)) 
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))
	Value = EN.mul(Value, RuneFormulas.Violence_Reflection(Player.Runes.Violence.Value))
	Value = EN.mul(Value, RuneFormulas.Axium_Reflection(Player.Runes.Axium.Value))
	Value = EN.mul(Value, RuneFormulas.Mommy_Reflection(Player.Runes.Mommy.Value))

	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	return Value
end

function Formulas.Ascended(Player : Player, Gain : number)
	local Value = 1
	return Value
end

--[ DONATIONS ]--
function Formulas.Donation_Stats(Value : number)
	if Value < 1 then return 1 end
	return 1 + (0.25 * math.log10(Value))
end

function Formulas.Donation_RuneLuck(Value : number)
	if Value < 1 then return 1 end
	return 1 + (0.15 * math.log10(Value))
end

function Formulas.Donation_RuneSpeed(Value : number)
	if Value < 1 then return 1 end
	return 1 + (0.15 * math.log10(Value))
end


--[ FAVORITES ]--
function Formulas.Favorites_RuneLuck(Value : number)
	local Boost = 1
	
	if Value >= 1e4 then
		return 1.9 + (0.000005 * (Value - 1e4))
	end
	
	if Value >= 5e3 then
		return 1.65 + (0.00005 * (Value - 5e3))
	end
	
	if Value >= 1e3 then
		return 1.25 + (0.0001 * (Value - 1e3))
	end
	
	Boost += 0.00025 * Value
	
	return math.clamp(Boost, 1, 10)
end



--[ TICKETS ]--
function Formulas.Tickets(Player : Player)
	local Value = 1
	Value = EN.mul(Value, 2) -- Event)
	
	Value = EN.mul(Value, RuneFormulas.Darkmatter_Tickets(Player.Runes.Darkmatter.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Tickets"):GetEffect(Player.Upgrades.Prisms_Tickets.Value, Player))
	Value = EN.mul(Value, Upgrades("Prisms_Tickets2"):GetEffect(Player.Upgrades.Prisms_Tickets2.Value, Player))
	Value = EN.mul(Value, Upgrades("Tickets_Tickets"):GetEffect(Player.Upgrades.Tickets_Tickets.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Tickets1"):GetEffect(Player.Upgrades.Chromium_Tickets1.Value, Player))
	Value = EN.mul(Value, Upgrades("Chromium_Tickets2"):GetEffect(Player.Upgrades.Chromium_Tickets2.Value, Player))
	Value = EN.mul(Value, RuneFormulas.Prismatic_Tickets(Player.Runes.Prismatic.Value))
	Value = EN.mul(Value, RuneFormulas.Vexed_Tickets(Player.Runes.Vexed.Value))
	Value = EN.mul(Value, RuneFormulas.Hailstorm_Tickets(Player.Runes.Hailstorm.Value))
	Value = EN.mul(Value, RuneFormulas.Boundless_Tickets(Player.Runes.Boundless.Value))
	Value = EN.mul(Value, RuneFormulas.Intermediate_Tickets(Player.Runes.Intermediate.Value))
	Value = EN.mul(Value, RuneFormulas.Legend_Tickets(Player.Runes.Legend.Value))
	Value = EN.mul(Value, RuneFormulas.Gilded_Tickets(Player.Runes.Gilded.Value))
	Value = EN.mul(Value, RuneFormulas.Throne_Tickets(Player.Runes.Throne.Value))
	Value = EN.mul(Value, RuneFormulas.Monarch_Tickets(Player.Runes.Monarch.Value))
	Value = EN.mul(Value, RuneFormulas.Imperial_Tickets(Player.Runes.Imperial.Value))
	Value = EN.mul(Value, RuneFormulas.Thorn_Tickets(Player.Runes.Thorn.Value))
	Value = EN.mul(Value, RuneFormulas.Abyssium_Tickets(Player.Runes.Abyssium.Value))
	Value = EN.mul(Value, RuneFormulas.Garmin_Tickets(Player.Runes.Garmin.Value))
	Value = EN.mul(Value, RuneFormulas.Vanta_Tickets(Player.Runes.Vanta.Value))
	Value = EN.mul(Value, RuneFormulas.Squid_Tickets(Player.Runes.Squid.Value))
	Value = EN.mul(Value, RuneFormulas.Array_Tickets(Player.Runes.Array.Value))
	Value = EN.mul(Value, RuneFormulas.Stray_Tickets(Player.Runes.Stray.Value))
	Value = EN.mul(Value, RuneFormulas.Whirl_Tickets(Player.Runes.Whirl.Value))
	Value = EN.mul(Value, RuneFormulas.Riptide_Tickets(Player.Runes.Riptide.Value))
	Value = EN.mul(Value, RuneFormulas.CosmicDust_Tickets(Player.Runes.CosmicDust.Value))
	Value = EN.mul(Value, RuneFormulas.Star_Tickets(Player.Runes.Star.Value))
	Value = EN.mul(Value, RuneFormulas.Buff_Tickets1(Player.Runes.Buff.Value))
	Value = EN.mul(Value, RuneFormulas.Buff_Tickets2(Player.Runes.Buff.Value))
	Value = EN.mul(Value, RuneFormulas.Sorcerer_Tickets(Player.Runes.Sorcerer.Value))
	Value = EN.mul(Value, RuneFormulas.Rocket_Tickets(Player.Runes.Rocket.Value))
	Value = EN.mul(Value, RuneFormulas.Hurricane_Tickets(Player.Runes.Hurricane.Value))
	Value = EN.mul(Value, RuneFormulas.Rage_Tickets(Player.Runes.Rage.Value))
	
	
	
	
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))
	
	
	if EN.meeq(Player.Stats.Spheres.Value, 1e27) then
		Value = EN.mul(Value, 2)
	end
	
	--[ Server Elixir ]--

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value = EN.mul(Value, 1.5)
	end
	
	if Player.Stats.StatsElixirDuration.Value > 1 then Value = EN.mul(Value, 2) end
	
	if Player.Stats.Ayla_Follow.Value then Value = EN.mul(Value, 1.25) end
		
	-- [Chromatize Effects] --
	local Chromatize_Bonus = 1
	if Player.Stats.Chromatize.Value >= 10 then Chromatize_Bonus *= 2 end -- Player has Chromatize 10 | x2 Tickets
	Value = EN.mul(Value, Chromatize_Bonus)

	return Value
end

function Formulas.Ticket_Chance(Player : Player, runeName)
	local Denominator = 10000
	Denominator -= RuneFormulas.Antimatter_TicketChance(Player.Runes.Antimatter.Value, Player)
	Denominator -= RuneFormulas.Sovereign_TicketChance(Player.Runes.Sovereign.Value, Player)
	Denominator -= RuneFormulas.Ankh_TicketChance(Player.Runes.Ankh.Value, Player)
	local Value = 1/Denominator
	Value *= Formulas.Rune_Bulk(Player,false,runeName) -- Affected by Rune Bulk

	return Value
end

function Formulas.Chest_Chance(Player : Player)
	local Denominator = 10000
	Denominator -= RuneFormulas.Refraction_ChestChance(Player.Runes.Refraction.Value, Player)
	Denominator -= RuneFormulas.Prosperity_ChestChance(Player.Runes.Prosperity.Value, Player)
	Denominator -= RuneFormulas.Primordial_ChestChance(Player.Runes.Prosperity.Value, Player)
	Denominator -= RuneFormulas.Ankh_ChestChance(Player.Runes.Ankh.Value, Player)
	
	local Value = 1/Denominator
	return Value
end

--[ LEVEL / XP ]--
function Formulas.XP(Player : Player, Gain : number)
	local Value = Gain or 1

	--// Put Milestones or Upgrades or something below here \\--
	Value = EN.mul(Value, Formulas.Flame_XP(EN.convert(Player.Stats.Flame.Value)))
	Value = EN.mul(Value, Upgrades("RP_XP"):GetEffect(Player.Upgrades.RP_XP.Value, Player))
	Value = EN.mul(Value, Upgrades("Power_XP"):GetEffect(Player.Upgrades.Power_XP.Value, Player))
	Value = EN.mul(Value, Upgrades("Spheres_XP"):GetEffect(Player.Upgrades.Spheres_XP.Value, Player))
	--// Final Calculation \\--

	--[ Gamepasses ]--
	if Player.Gamepasses.MoreStats.Value then Value = EN.mul(Value, 2) end
	if Player.Gamepasses.Prime.Value then Value = EN.mul(Value, 1.5) end
	Value = EN.mul(Value, Formulas.Donation_Stats(Player.Stats.RobuxDonated.Value))

	if Player.Stats.C2.Value then Value = EN.mul(Value, 20) end
	if Player.Stats.CurrentChallenge.Value == "C4"  and EN.me(Value, 1) then Value = EN.pow(Value, 0.5) end

	return Value
end

function Formulas.Level_Req(Currency : number)
	return EN.mul(1e2,EN.pow(3, Currency)) -- Temporary Formula
end


--[ PRODUCTS ]--
function Formulas.Product_RuneBulk(Player : Player)
	return 1 * math.clamp(Player.Stats.RuneBulkProduct.Value, 0, 1000000)
end

function Formulas.Product_RuneLuck(Player : Player)
	return 1 * math.clamp(Player.Stats.RuneLuckProduct.Value, 1, 10.8)
end

function Formulas.Product_RuneSpeed(Player : Player)
	return 1 * math.clamp(Player.Stats.RuneSpeedProduct.Value, 1, 11.4)
end

function Formulas.Product_RuneBulk2(Player : Player)
	return 1 * math.clamp(Player.Stats.RuneBulkMultiplierProduct.Value, 1, 6)
end

function Formulas.Product_SecretStats(Player : Player)
	return 1 * math.clamp(Player.Stats.SecretStatsProduct.Value, 1, 6)
end

function Formulas.Product_RuneClone(Player : Player)
	local Clone_Level = Player.Stats.RuneCloneProduct.Value
	if Clone_Level == 8 then return 1e12 end
	if Clone_Level == 7 then return 1e10 end
	if Clone_Level == 1 then return 1e3 end
	return (1000 * (10 ^ math.clamp(Clone_Level - 1, 0, 7)))
end


function Formulas.Mob_Respawn(Player : Player)
	local Value = 3

	Value -= Upgrades("Prisms_SpawnSpeed"):GetEffect(Player.Upgrades.Prisms_SpawnSpeed.Value, Player)

	return Value
end

--// Power Stuff \\--
function Formulas.Power_LevelCap(Player : Player)
	local Value = 0

	Value += Upgrades("Prisms_Caps"):GetEffect(Player.Upgrades.Prisms_Caps.Value, Player)

	return Value
end

function Formulas.AutoPower(Player : Player)
	local Value = 0.1

	Value += Upgrades("Prisms_AutoPower2"):GetEffect(Player.Upgrades.Prisms_AutoPower2.Value, Player)

	return Value
end


--// Cubes \\--
function Formulas.Cube_Level(Player : Player)
	local Value = 1

	Value += Upgrades("Orbs_SpawnLevel"):GetEffect(Player.Upgrades.Orbs_SpawnLevel.Value, Player)

	return Value
end

function Formulas.Cube_Energy(Level : number)
	return EN.pow(3, Level - 1)
end

function Formulas.Cube_Power(Level : number)
	return EN.pow(2, Level - 1)
end

function Formulas.Cube_Orbs(Level : number)
	return EN.pow(1.5, Level - 1)
end

function Formulas.Playtime_Prisms(Playtime : number)
	local Base = 0.002
	local Offset = math.floor(Playtime / 60)
	
	return 1 + (Base * Offset)
end

--// Runes \\--
function Formulas.Rune_Luck(Player : Player, convert : boolean, runeName)
	if not Player.Settings.RuneLuck.Value then return 1 end
	
	local Value = 1
	 -- Event
	Value *= Formulas.Product_RuneLuck(Player)
	Value *= Formulas.Favorites_RuneLuck(game.ReplicatedStorage.Favorites.Value)
	if Player.Stats.RLBoost.Value then Value *= 1.1 end
	
	--[ Upgrades ]--
	Value *= Upgrades("Prisms_RuneLuck"):GetEffect(Player.Upgrades.Prisms_RuneLuck.Value, Player)
	Value *= Upgrades("Orbs_RuneLuck"):GetEffect(Player.Upgrades.Orbs_RuneLuck.Value, Player)
	Value *= Upgrades("Prisms_RuneLuck2"):GetEffect(Player.Upgrades.Prisms_RuneLuck2.Value, Player)
	Value *= Upgrades("Tickets_RuneLuck"):GetEffect(Player.Upgrades.Tickets_RuneLuck.Value, Player)
	Value *= Upgrades("Tickets_RuneLuck2"):GetEffect(Player.Upgrades.Tickets_RuneLuck2.Value, Player)
	
	--[ Rune Effects ]--
	Value *= RuneFormulas.Rainbow_RuneLuck(Player.Runes.Rainbow.Value)
	Value *= RuneFormulas.Unknown_RuneLuck(Player.Runes.Unknown.Value, Player)
	Value *= RuneFormulas.Antimatter_RuneLuck(Player.Runes.Antimatter.Value, Player)
	Value *= RuneFormulas.Iridium_RuneLuck(Player.Runes.Iridium.Value)	
	Value *= RuneFormulas.Aether_RuneLuck(Player.Runes.Aether.Value)
	Value *= RuneFormulas.Frigid_RuneLuck(Player.Runes.Frigid.Value)
	Value *= RuneFormulas.Master_RuneLuck(Player.Runes.Master.Value)
	Value *= RuneFormulas.Royalty_RuneLuck(Player.Runes.Royalty.Value)
	Value *= RuneFormulas.Kingslayer_RuneLuck(Player.Runes.Kingslayer.Value)
	Value *= RuneFormulas.Divinity_RuneLuck(Player.Runes.Divinity.Value)
	Value *= RuneFormulas.Oscillon_RuneLuck(Player.Runes.Oscillon.Value)
	Value *= RuneFormulas.Sigil_RuneLuck(Player.Runes.Sigil.Value)
	
	if Player.Upgrades.Chromium_RuneLuck1.Value > 0 and EN.me(Player.Stats.Chromium.Value, 0) then -- Chromium >> Rune Luck Boost
		
		local Chromium_Offset = EN.add(EN.mul(EN.div(Player.Stats.Chromium.Value, "1e21"),0.01),1)
		if EN.me(Chromium_Offset,2) then
			Chromium_Offset = EN.convert(2)
		end
		
		Chromium_Offset = EN.toNumber(Chromium_Offset)
		Value *= Chromium_Offset
	end
	
	local gotHaze = false 
	if Player.Stats.Haze.Value >= 1 then 
		Value *= 1+math.min(Player.Stats.Haze.Value * 0.3, 25)
		gotHaze = true
	end
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 5 then Tier_Bonus = 1.25 end -- Player has Tier 5 | x1.25 Rune Luck
	Value = Value * Tier_Bonus
	
	if runeName == "Color" then 
		Value *= Player.Stats.Color_Rune_Luck.Value
	elseif runeName == "Arctic" then
		Value *= Player.Stats.Arctic_Rune_Luck.Value
	elseif runeName == "Polychrome" then
		Value *= Player.Stats.Polychrome_Rune_Luck.Value
	end

	Value *= Player.Stats.Global_Rune_Luck.Value

	if EN.meeq(Player.Stats.Spheres.Value, 1e69) then
		Value *= 1.5
	end
	
	if Player.Gamepasses.MoreRuneLuck.Value then
		Value *= 2
	end
	
	if Player.Stats.RuneLuckElixirDuration.Value > 1 then
		Value *= 2
	end
	
	if Player.Stats.Akn_Follow.Value then Value *= 1.25 end
	
	if Player:GetAttribute("PlaytimeLuckIncrease") then 
		Value *= 1 + (Player:GetAttribute("PlaytimeLuckIncrease")/100)
	end
	
	
	if Player.Stats.Realm.Value == "One" and Player.Stats.AscensionOne.Value then
		Value *= 2
	end
	
	Value *= Formulas.Donation_RuneLuck(Player.Stats.RobuxDonated.Value)

	return Value
end

function Formulas.Rune_Bulk(Player : Player, Convert : boolean, runeName)
	local Value = 1
	
	if Player.Stats.Verified.Value then Value += 1 end
	local Tier_Bonus = 0
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 1 end -- Player has Tier 7 | +1 RuneBulk
	if Player.Stats.Tier.Value >= 10 then Tier_Bonus = 3 end -- Player has Tier 10 | +3 RuneBulk

	Value += Formulas.Orbs_RuneBulk(Player.Stats.Orbs.Value)
	--Value += Player.Stats.RuneBulk.Value

	--[ Upgrades ]--
	Value += Upgrades("Orbs_RuneBulk"):GetEffect(Player.Upgrades.Orbs_RuneBulk.Value)
	Value += Upgrades("Prisms_RuneBulk"):GetEffect(Player.Upgrades.Prisms_RuneBulk.Value)
	Value += Upgrades("Tickets_RuneBulk"):GetEffect(Player.Upgrades.Tickets_RuneBulk.Value, Player)
	Value += Upgrades("Prisms_RuneBulk4"):GetEffect(Player.Upgrades.Prisms_RuneBulk4.Value)
	
	--[ Rune Effects ]--
	Value += RuneFormulas.Emberglow_RuneBulk(Player.Runes.Emberglow.Value)
	Value += RuneFormulas.Prismatic_RuneBulk(Player.Runes.Prismatic.Value)
	Value += RuneFormulas.Elite_RuneBulk(Player.Runes.Elite.Value)
	Value += RuneFormulas.Crown_RuneBulk(Player.Runes.Crown.Value)
	Value += RuneFormulas.Sovereign_RuneBulk(Player.Runes.Sovereign.Value)
	Value += RuneFormulas.Divinity_RuneBulk(Player.Runes.Divinity.Value)
	Value += RuneFormulas.Shyft_RuneBulk(Player.Runes.Shyft.Value)
	Value += RuneFormulas.Overlord_RuneBulk(Player.Runes.Overlord.Value)
	Value += RuneFormulas.Array_RuneBulk1(Player.Runes.Array.Value)
	Value += RuneFormulas.Disarray_RuneBulk1(Player.Runes.Disarray.Value)
	Value += RuneFormulas.Planet_RuneBulk1(Player.Runes.Planet.Value)
	
	
	if Player:GetAttribute("PlaytimeBulkIncrease") then
		Value += Player:GetAttribute("PlaytimeBulkIncrease")
	end
	
	--[ Ascension Bonus ]--
	if Player.Stats.Realm.Value == "One" and Player.Stats.AscensionOne.Value then
		Value += 10
	end
	
	if EN.meeq(Player.Stats.Spheres.Value, 5e72) then
		Value += 3
	end
	
	
	if Player.Stats.Icy_Follow.Value then Value += 1.25 end

	Value += Tier_Bonus
	Value += Formulas.Product_RuneBulk(Player)
	Value *= Player.Stats["Global_Rune_Bulk"].Value
	Value *= RuneFormulas.Blizzard_RuneBulk(Player.Runes.Blizzard.Value)
	Value *= RuneFormulas.Boundless_RuneBulk(Player.Runes.Boundless.Value)
	Value *= RuneFormulas.Mystery_RuneBulk(Player.Runes.Mystery.Value)
	Value *= RuneFormulas.Antimatter_RuneBulk(Player.Runes.Antimatter.Value)
	Value *= RuneFormulas.Abyssium_RuneBulk(Player.Runes.Abyssium.Value)
	Value *= RuneFormulas.Gleam_RuneBulk(Player.Runes.Gleam.Value)
	Value *= RuneFormulas.Oblivion_RuneBulk(Player.Runes.Oblivion.Value)
	Value *= RuneFormulas.Immortality_RuneBulk(Player.Runes.Immortality.Value)
	Value *= RuneFormulas.Vanta_RuneBulk(Player.Runes.Vanta.Value)
	Value *= RuneFormulas.Odyssey_RuneBulk1(Player.Runes.Odyssey.Value)
	Value *= RuneFormulas.Odyssey_RuneBulk2(Player.Runes.Odyssey.Value)
	Value *= RuneFormulas.Destiny_RuneBulk(Player.Runes.Destiny.Value)
	Value *= RuneFormulas.Squid_RuneBulk(Player.Runes.Squid.Value)
	Value *= RuneFormulas.Array_RuneBulk2(Player.Runes.Array.Value)
	Value *= RuneFormulas.Disarray_RuneBulk2(Player.Runes.Disarray.Value)
	Value *= RuneFormulas.Bolt_RuneBulk1(Player.Runes.Bolt.Value)
	Value *= RuneFormulas.Bolt_RuneBulk2(Player.Runes.Bolt.Value)
	Value *= RuneFormulas.Zephyr_RuneBulk(Player.Runes.Zephyr.Value)
	Value *= RuneFormulas.Primordial_RuneBulk(Player.Runes.Primordial.Value)
	Value *= RuneFormulas.Sigil_RuneBulk(Player.Runes.Sigil.Value)
	Value *= RuneFormulas.Omen_RuneBulk(Player.Runes.Omen.Value)
	Value *= RuneFormulas.Bone_RuneBulk(Player.Runes.Bone.Value)
	Value *= RuneFormulas.Apex_RuneBulk(Player.Runes.Apex.Value)
	Value *= RuneFormulas.Liberty_RuneBulk(Player.Runes.Liberty.Value)
	Value *= RuneFormulas.Constellation_RuneBulk1(Player.Runes.Constellation.Value)
	Value *= RuneFormulas.Constellation_RuneBulk2(Player.Runes.Constellation.Value)
	Value *= RuneFormulas.Vanguard_RuneBulk1(Player.Runes.Vanguard.Value)
	Value *= RuneFormulas.Vanguard_RuneBulk2(Player.Runes.Vanguard.Value)
	Value *= RuneFormulas.Eternal_RuneBulk(Player.Runes.Eternal.Value)
	Value *= RuneFormulas.Raze_RuneBulk(Player.Runes.Raze.Value)
	Value *= RuneFormulas.Vehemence_RuneBulk(Player.Runes.Vehemence.Value)
	Value *= Upgrades("Tickets_RuneBulk2"):GetEffect(Player.Upgrades.Tickets_RuneBulk2.Value, Player)
	Value *= Upgrades("Tickets_RuneBulk3"):GetEffect(Player.Upgrades.Tickets_RuneBulk3.Value, Player)
	Value *= 3-- Event
	Value *= Formulas.Product_RuneBulk2(Player)
	
	if Player.Stats.Chromatize.Value >= 150 then
		local Chromatize_Bonus = 1 + (0.01 * (Player.Stats.Chromatize.Value - 149))

		if Chromatize_Bonus > 4.5 then 
			Chromatize_Bonus = 4.5
		end
		Value *= Chromatize_Bonus
	end

	if runeName and runeName == "Polychrome" then
		if Player.Stats.Polychrome_Rune_Bulk and Player.Stats.Polychrome_Rune_Bulk.Value > 0 then
			Value *= Player.Stats.Polychrome_Rune_Bulk.Value
		end
	elseif runeName and runeName == "Arctic" then 
		if Player.Stats.Arctic_Rune_Bulk and Player.Stats.Arctic_Rune_Bulk.Value > 0 then
			Value *= Player.Stats.Arctic_Rune_Bulk.Value
		end
	elseif runeName and runeName == "5MRoyal" then 
		if Player.Stats.Royal_Rune_Bulk and Player.Stats.Royal_Rune_Bulk.Value > 0 then
			Value *= Player.Stats.Royal_Rune_Bulk.Value
		end
	end

	
	if Player.Stats.Iris_Follow.Value then Value *= 1.25 end
	if Player.Stats.RBBoost.Value then Value *= 1.1 end
	if Player.Stats.BulkFix.Value then Value *= 1.25 end
	
	local gotLoot = false 
	if Player.Stats.Loot.Value >= 1 then 
		Value *= 1+math.min(Player.Stats.Loot.Value * 0.0075, 2)
		gotLoot = true
	end
	

	if game.ReplicatedStorage.GlobalElixirDuration.Value > 0 then
		Value *= 1.25
	end
	
	
	Value ^= RuneFormulas.Planet_RuneBulk2(Player.Runes.Planet.Value)
	Value ^= RuneFormulas.Oscillon_RuneBulk(Player.Runes.Oscillon.Value)
	Value ^= RuneFormulas.Cyclone_RuneBulk(Player.Runes.Cyclone.Value)
	Value ^= Upgrades("Prisms_RuneBulk3"):GetEffect(Player.Upgrades.Prisms_RuneBulk3.Value, Player)
	Value ^= Upgrades("Tickets_RuneBulk4"):GetEffect(Player.Upgrades.Tickets_RuneBulk4.Value, Player)
	Value ^= Upgrades("Chromium_RPS6"):GetEffect(Player.Upgrades.Chromium_RPS6.Value, Player)
	
	--[ Rune Speed : Bulk Conversion ]--
	if Convert then
		local Rune_Speed = 1 / Formulas.Rune_Speed(Player)
		local Offset = Rune_Speed - 60
		if Offset > 0 then
			Value *= 1 + (Offset / 60)
		end
	end

	if Player.Upgrades.Prisms_RuneBulk2.Value > 0 then
		Value *= 1.1
	end
	
	if Player.Upgrades.Prisms_RuneClone.Value > 0 then
		Value *= 1.5
	end

	return math.floor(Value) -- To prevent any decimal bulks
end

function Formulas.Rune_Speed(Player : Player)
	local Value = 1
	Value /= 3 -- Event
	Value /= Formulas.Product_RuneSpeed(Player)
	if Player.Stats.RSBoost.Value then Value /= 1.1 end
	if Player.Stats.RSBoost2.Value then Value /= 1.1 end
	if Player:GetAttribute("Premium") then
		Value /= 1.15
	end
	
	Value /= Upgrades("Orbs_RuneSpeed"):GetEffect(Player.Upgrades.Orbs_RuneSpeed.Value)
	Value /= Upgrades("Prisms_RuneSpeed"):GetEffect(Player.Upgrades.Prisms_RuneSpeed.Value)
	Value /= Upgrades("Tickets_RuneSpeed"):GetEffect(Player.Upgrades.Tickets_RuneSpeed.Value, Player)
	Value /= Upgrades("Tickets_RuneSpeed2"):GetEffect(Player.Upgrades.Tickets_RuneSpeed2.Value, Player)
	Value /= Upgrades("Tickets_RuneSpeed3"):GetEffect(Player.Upgrades.Tickets_RuneSpeed3.Value, Player)
	Value /= Upgrades("Chromium_RuneSpeed"):GetEffect(Player.Upgrades.Chromium_RuneSpeed.Value)
	Value /= Upgrades("Prisms_RuneSpeed2"):GetEffect(Player.Upgrades.Prisms_RuneSpeed2.Value)
	Value /= Upgrades("Prisms_RuneSpeed3"):GetEffect(Player.Upgrades.Prisms_RuneSpeed3.Value)
	Value /= Upgrades("Prisms_RPS"):GetEffect(Player.Upgrades.Prisms_RPS.Value)
	Value /= Upgrades("Prisms_RPS2"):GetEffect(Player.Upgrades.Prisms_RPS2.Value)
	Value /= Upgrades("Chromium_RPS1"):GetEffect(Player.Upgrades.Chromium_RPS1.Value)
	Value /= Upgrades("Chromium_RPS2"):GetEffect(Player.Upgrades.Chromium_RPS2.Value)
	Value /= Upgrades("Chromium_RPS3"):GetEffect(Player.Upgrades.Chromium_RPS3.Value)
	Value /= Upgrades("Chromium_RPS4"):GetEffect(Player.Upgrades.Chromium_RPS4.Value)
	Value /= Upgrades("Chromium_RPS5"):GetEffect(Player.Upgrades.Chromium_RPS5.Value)
	Value /= Upgrades("Chromium_RPS7"):GetEffect(Player.Upgrades.Chromium_RPS7.Value)
	Value /= Upgrades("Chromium_RPS8"):GetEffect(Player.Upgrades.Chromium_RPS8.Value)
	Value /= Upgrades("Chromium_RPS9"):GetEffect(Player.Upgrades.Chromium_RPS9.Value)
	Value /= Upgrades("Chromium_RPS10"):GetEffect(Player.Upgrades.Chromium_RPS10.Value)
	Value /= Upgrades("Reflection_RPS1"):GetEffect(Player.Upgrades.Reflection_RPS1.Value)
	
	--[ Rune Effects ]--
	Value /= RuneFormulas.Vibrance_RuneSpeed(Player.Runes.Vibrance.Value)
	Value /= RuneFormulas.Earthvein_RuneSpeed(Player.Runes.Earthvein.Value)
	Value /= RuneFormulas.Refraction_RuneSpeed(Player.Runes.Refraction.Value)
	Value /= RuneFormulas.Subzero_RuneSpeed(Player.Runes.Subzero.Value)
	Value /= RuneFormulas.Boundless_RuneSpeed(Player.Runes.Boundless.Value)
	Value /= RuneFormulas.Kingslayer_RuneSpeed(Player.Runes.Kingslayer.Value)
	Value /= RuneFormulas.Thorn_RuneSpeed(Player.Runes.Thorn.Value)
	Value /= RuneFormulas.Prosperity_RuneSpeed(Player.Runes.Prosperity.Value)
	Value /= RuneFormulas.Almighty_RuneSpeed(Player.Runes.Almighty.Value)
	Value /= RuneFormulas.HyperFinality_RuneSpeed(Player.Runes.HyperFinality.Value)
	Value /= RuneFormulas.Etherborn_RuneSpeed(Player.Runes.Etherborn.Value)
	Value /= RuneFormulas.Gleam_RuneSpeed(Player.Runes.Gleam.Value)
	Value /= RuneFormulas.Mirror_RuneSpeed1(Player.Runes.Mirror.Value)
	Value /= RuneFormulas.Mirror_RuneSpeed2(Player.Runes.Mirror.Value)
	Value /= RuneFormulas.Vanta_RuneSpeed(Player.Runes.Vanta.Value)
	Value /= RuneFormulas.Frostbite_RuneSpeed(Player.Runes.Frostbite.Value)
	Value /= RuneFormulas.Odyssey_RuneSpeed(Player.Runes.Odyssey.Value)
	Value /= RuneFormulas.Destiny_RuneSpeed(Player.Runes.Destiny.Value)
	Value /= RuneFormulas.Cyclone_RuneSpeed(Player.Runes.Cyclone.Value)
	Value /= RuneFormulas.Stray_RuneSpeed(Player.Runes.Stray.Value)
	Value /= RuneFormulas.Triarch_RuneSpeed1(Player.Runes.Triarch.Value)
	Value /= RuneFormulas.Triarch_RuneSpeed2(Player.Runes.Triarch.Value)
	Value /= RuneFormulas.Triarch_RuneSpeed3(Player.Runes.Triarch.Value)
	Value /= RuneFormulas.Zephyr_RuneSpeed(Player.Runes.Zephyr.Value)
	Value /= RuneFormulas.Glyph_RuneSpeed(Player.Runes.Glyph.Value)
	Value /= RuneFormulas.Ankh_RuneSpeed(Player.Runes.Ankh.Value)
	Value /= RuneFormulas.Omen_RuneSpeed(Player.Runes.Omen.Value)
	Value /= RuneFormulas.Whirl_RuneSpeed(Player.Runes.Whirl.Value)
	Value /= RuneFormulas.Riptide_RuneSpeed1(Player.Runes.Riptide.Value)
	Value /= RuneFormulas.Riptide_RuneSpeed2(Player.Runes.Riptide.Value)
	Value /= RuneFormulas.Star_RuneSpeed(Player.Runes.Star.Value)
	Value /= RuneFormulas.CosmicDust_RuneSpeed(Player.Runes.CosmicDust.Value)
	Value /= RuneFormulas.Apex_RuneSpeed(Player.Runes.Apex.Value)
	Value /= RuneFormulas.Torrent_RuneSpeed(Player.Runes.Torrent.Value)
	Value /= RuneFormulas.Sorcerer_RuneSpeed1(Player.Runes.Sorcerer.Value)
	Value /= RuneFormulas.Sorcerer_RuneSpeed2(Player.Runes.Sorcerer.Value)
	Value /= RuneFormulas.Strix_RuneSpeed(Player.Runes.Strix.Value)
	Value /= RuneFormulas.Onyx_RuneSpeed1(Player.Runes.Onyx.Value)
	Value /= RuneFormulas.Onyx_RuneSpeed2(Player.Runes.Onyx.Value)
	Value /= RuneFormulas.Liberty_RuneSpeed(Player.Runes.Liberty.Value)
	Value /= RuneFormulas.Rocket_RuneSpeed(Player.Runes.Rocket.Value)
	Value /= RuneFormulas.Vanguard_RuneSpeed1(Player.Runes.Vanguard.Value)
	Value /= RuneFormulas.Vanguard_RuneSpeed2(Player.Runes.Vanguard.Value)
	Value /= RuneFormulas.Eternal_RuneSpeed(Player.Runes.Eternal.Value)
	Value /= RuneFormulas.Raze_RuneSpeed(Player.Runes.Raze.Value)
	Value /= RuneFormulas.Bozo_RuneSpeed(Player.Runes.Bozo.Value)
	Value /= RuneFormulas.Glint_RuneSpeed(Player.Runes.Glint.Value)
	Value /= RuneFormulas.Rage_RuneSpeed(Player.Runes.Rage.Value)
	Value /= RuneFormulas.Malevolence_RuneSpeed(Player.Runes.Malevolence.Value)
	Value /= RuneFormulas.Axium_RuneSpeed(Player.Runes.Axium.Value)
	Value /= RuneFormulas.Mommy_RuneSpeed(Player.Runes.Mommy.Value)
	Value /= RuneFormulas.Hyperion_RuneSpeed(Player.Runes.Hyperion.Value)
	Value /= RuneFormulas.Soup_RuneSpeed1(Player.Runes.Soup.Value)
	Value /= RuneFormulas.Soup_RuneSpeed2(Player.Runes.Soup.Value)
	Value /= RuneFormulas.Paracosm_RuneSpeed(Player.Runes.Paracosm.Value)
	
	Value /= Formulas.Donation_RuneSpeed(Player.Stats.RobuxDonated.Value)
	
	
	local Tier_Bonus = 1
	if Player.Stats.Tier.Value >= 7 then Tier_Bonus = 1.25 end -- Player has Tier 7 | x1.25 RuneSpeed

	if EN.meeq(Player.Stats.Spheres.Value, 1e69) then
		Value /= 1.25
	end
	
	if Player.Stats.Luffy_Follow.Value then Value /= 1.25 end
	
	if Player.Gamepasses.MoreRuneSpeed.Value then Value /= 2 end
	
	local gotHail = false 
	if Player.Stats.Hail.Value >= 1 then 
		Value /= 1+math.min(Player.Stats.Hail.Value * 0.075, 4)
		gotHail = true
	end
	
	local gotChroma = false 
	if Player.Stats.Chroma.Value >= 1 then 
		Value /= 1+math.min(Player.Stats.Chroma.Value * 0.00001, 0.25)
		gotChroma = true
	end
	
	local gotShine = false 
	if Player.Stats.Shine.Value >= 1 then 
		Value /= 1+math.min(Player.Stats.Shine.Value * 0.0001, 0.1)
		gotShine = true
	end
	
	--[ Server Elixir ]--
	if Player:GetAttribute("ServerBoosted") then Value /= 1.75 end

	if Player.Stats.RuneSpeedElixirDuration.Value > 1 then
		Value /= 2
	end

	Value /= Tier_Bonus

	return Value
end

function Formulas.Rune_Clone(Player : Player)
	local Value = 1
	
	if Player.Upgrades.Prisms_RuneClone.Value then Value += 1 end

	return Value
end

function Formulas.RPS(Rune_Bulk : number, Rune_Speed : number) -- Used for Visual
	local Speed = 1 / Rune_Speed
	local RPS = Rune_Bulk * Speed

	return RPS
end

function Formulas.Rune_OpenTime(Afford : number, RPS : number)
	return Afford / RPS
end

function Formulas.Rune_Afford(Currency : number, Cost : number)
	local Afford = EN.toNumber(EN.div(Currency, Cost))
	if Afford < 0 then return 0 end

	return math.floor(Afford)
end

--// Walkspeed \\--
function Formulas.Walkspeed(Player : Player)
	local Base = Base_WS -- Refer to StarterPlayer Properties

	if Player.Gamepasses.Prime.Value then
		Base += 7
	end
	
	if Player.Gamepasses.Sprint.Value then
		Base += 12
	end
	
	if Player.Stats.Blitz.Value then Base += 5 end
	
	if Player.Stats.GGRobuxRank.Value > 0 then
		Base += (4-Player.Stats.GGRobuxRank.Value)*2
	end
	
	if Player:GetAttribute("GroupMember") then Base += 5 end

	Base += Upgrades("Prisms_Walkspeed"):GetEffect(Player.Upgrades.Prisms_Walkspeed.Value, Player)
	Base += RuneFormulas.Prismatic_Walkspeed(Player.Runes.Prismatic.Value)
	Base += RuneFormulas.Shyft_Walkspeed(Player.Runes.Shyft.Value)

	return Base
end

--// Effects \\--
function Formulas.Flame_Energy(Currency : number) -- Flame >> Energy Boost
	local Scale = 0.5

	local Calculation = EN.add(1, EN.mul(Scale, Currency)) -- +50% Energy Boost per Flame
	return Calculation
end

function Formulas.Flame_XP(Currency : number) -- Flame >> XP Boost
	if EN.le(Currency, 1e6) then return 1 end
	local Power = 0.03 
	
	local Calculation = EN.pow(Currency, Power) -- Flame ^ 0.03 = XP Multi Bonus
	return Calculation
end

function Formulas.Gears_Speed(Currency : number)
	local Effect = 0.025
	return Effect * Currency
end

function Formulas.Accelerator_PrismSpeed(Currency : number)
	local Effect = 1

	Effect += 0.1 * Currency

	return Effect
end

function Formulas.Accelerator_CubeSpeed(Currency : number)
	local Effect = 1

	Effect += 0.05 * Currency

	return Effect
end


function Formulas.Power_Damage(Currency : number, Player : Player) -- Power >> Damage Boost
	if EN.le(Currency, 1) then return 1 end
	local Power = 0.075

	if Player.Upgrades.Prisms_DMG.Value > 0 then
		Power += 0.1
	end

	local Calculation = EN.pow(Currency, Power) -- Power ^ 0.04 = Damage Multi Bonus
	return Calculation
end

function Formulas.Power_Spheres(Currency : number, Player : Player) -- Power >> Spheres Boost
	if EN.le(Currency, 1) then return 1 end
	local Power = 0.01

	local Calculation = EN.pow(Currency, Power) -- Power ^ 0.04 = Damage Multi Bonus
	return Calculation
end

function Formulas.Prisms_Flame(Currency : number, Player : Player) -- Prisms >> Flame Boost
	if EN.le(Currency, 1) then return 1 end
	local Prisms = 2

	local Calculation = EN.pow(Currency, Prisms)
	return Calculation
end

function Formulas.Prisms_Prisms(Currency : number, Player : Player) -- Prisms >> Prisms Boost
	if EN.le(Currency, 1) then return 1 end

	local Calculation = EN.pow(Currency, 0.25)
	return Calculation
end

function Formulas.Level_Energy(Currency : number) -- Level >> Energy Boost
	local Effect = 1
	if Currency <= 0 then return Effect end

	return EN.pow(1.3, Currency)
end

function Formulas.Orbs_Energy(Currency : number) -- Orbs >> Energy Boost
	if EN.leeq(Currency, 20) then return 1 end
	local Effect = 1

	--// Scaling \\--
	Effect = EN.mul(EN.div(Currency,20), 1)

	return Effect
end

function Formulas.RuneLuck_RuneBulk(Currency : number) -- Orbs >> Energy Boost
	if EN.leeq(Currency, 1) then return 1 end
	local Effect = 1

	--// Scaling \\--
	Effect = EN.mul(EN.div(Currency, 1), 1)

	return Effect
end

function Formulas.Orbs_Flame(Currency : number) -- Orbs >> Flame Boost
	if EN.le(Currency, 500) then return 1 end
	local Effect = 1

	--// Scaling \\--
	Effect = EN.mul(EN.div(Currency,500), 1)

	return Effect
end

function Formulas.Orbs_RP(Currency : number, Player : Player) -- Orbs >> RP Boost
	if EN.le(Currency, 1) then return 1 end
	local Power = 0.15

	local Calculation = EN.pow(Currency, Power)
	return Calculation
end

function Formulas.Orbs_Power(Currency : number) -- Orbs >> Power Boost
	if EN.le(Currency, 1e4) then return 1 end
	local Effect = 1

	--// Scaling \\--
	Effect = EN.mul(EN.div(Currency,1e4), 1)

	return Effect
end

function Formulas.Orbs_RealmPoints(Currency : number, Player : Player) -- Orbs >> Realm Points Boost
	if EN.le(Currency, 4e15) then return 1 end
	local Effect = 1
	
	--// Scaling \\--
	local Scale = .35
	local RP_Enhance = math.min(Player.Upgrades.Prisms_RPEnhance.Value , 5)
	Scale += (0.01 * RP_Enhance)
	Effect = EN.pow(EN.div(Currency,4e15), Scale)

	return Effect
end

function Formulas.Orbs_Flesh(Currency : number) -- Orbs >> Flesh Boost
	if EN.le(Currency, 4e28) then return 1 end
	local Effect = 1

	--// Scaling \\--
	Effect = EN.pow(EN.div(Currency,4e28), 0.75)

	return Effect
end

function Formulas.Tickets_Spheres(Currency : number) -- Tickets >> Spheres Boost
	return EN.add(1, Currency)
end

function Formulas.Orbs_RuneBulk(Currency : number) -- Orbs >> Rune Bulk Boost
	local Effect = 0

	--// Scaling \\--
	if EN.meeq(Currency, 1e39) then
		Effect += 1
	end

	if EN.meeq(Currency, 1e78) then
		Effect += 1
	end
	
	if EN.meeq(Currency, 1e147) then
		Effect += 1
	end

	return Effect
end

function Formulas.Spheres_Spheres(Currency : number) -- Orbs >> Rune Bulk Boost
	local Effect = 1

	Effect = EN.pow(1.5, Currency)

	return Effect
end

--// Gains \\--

--// Costs \\--
local Tier_Costs = {
	[0] = 100;
	[1] = 1e6;
	[2] = 5e9;
	[3] = 2.5e15;
	[4] = 7.5e23;	
	[5] = 1e40;
	[6] = 1e65;
	[7] = 1e153; 	
	[8] = 1e276;
	[9] = "1e978";
	[10] = "5e60"; -- Droplets
	[11] = "7.5e113";
	[12] = "1e195";
	[13] = "9e9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999";
}
function Formulas.Tier_Cost(Tier : number)
	Tier = math.floor(Tier)
	if Tier_Costs[Tier] then return Tier_Costs[Tier] end -- Returns Set Cost, else performs auto scaling formula

	--// Settings \\--
	local Base_Cost = 100
	local Scale = 100
	local Super_Scale = 1 -- Another exponential to cost

	--// Conditions \\--
	if Tier >= 2 then Scale += 50 end
	if Tier >= 3 then Super_Scale += 0.15 end
	if Tier >= 4 then Super_Scale += 0.25 end

	--// Final \\--
	return EN.pow(EN.mul(Base_Cost, EN.pow(Scale, Tier)), Super_Scale)
end

local Chromatize_Costs = {
	[1] = "1e43";
	[2] = "1e50";
	[3] = "1e55";
	[4] = "1e60";
	[5] = "1e65";
	[6] = "1e70";
	[7] = "1e85";
	[8] = "1e95";
	[9] = "1e105";
	[10] = "5e178";
	[1001] = "1e33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
}

function Formulas.Chromatize_Cost(Chromatize : number)
	Chromatize = math.floor(Chromatize)
	if Chromatize_Costs[Chromatize] then return Chromatize_Costs[Chromatize] end -- Returns Set Cost, else performs auto scaling formula

	--// Settings \\--
	local Base_Cost = 1e40
	local Scale = 100
	local Super_Scale = 1 -- Another exponential to cost

	--// Conditions \\--
	if Chromatize >= 2 then Scale += 50 end
	if Chromatize >= 3 then Super_Scale += 0.15 end
	if Chromatize >= 4 then Super_Scale += 0.25 end

	--// Final \\--
	return EN.pow(EN.mul(Base_Cost, EN.pow(Scale, Chromatize)), Super_Scale)
end


local Chromify_Costs = {
	[0] = "1e23";
	[1] = "7.5e36";
	[2] = "1e78";
	[3] = "1e100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
}

function Formulas.Chromify_Cost(Chromify : number)
	Chromify = math.floor(Chromify)
	if Chromify_Costs[Chromify] then return Chromify_Costs[Chromify] end -- Returns Set Cost, else performs auto scaling formula

	--// Settings \\--
	local Base_Cost = 1e24
	local Scale = 10000
	local Super_Scale = 1 -- Another exponential to cost

	--// Conditions \\--
	if Chromify >= 2 then Scale += 50 end
	if Chromify >= 3 then Super_Scale += 0.15 end
	if Chromify >= 4 then Super_Scale += 0.25 end

	--// Final \\--
	return EN.pow(EN.mul(Base_Cost, EN.pow(Scale, Chromify)), Super_Scale)
end

function Formulas.Flame_Cost(Player : Player)
	--// Settings \\--
	local Base_Cost = 50

	return Base_Cost
end

function Formulas.Gears_Cost(Gears : number)
	return EN.mul(1e7, EN.pow(1e3, Gears))
end

function Formulas.Accelerator_Cost(Accelerators : number)
	return EN.mul(1e243, EN.pow(75, Accelerators))
end

function Formulas.Power_Cost(Player : Player)
	--// Settings \\--
	local Base_Cost = 50

	return Base_Cost
end

function Formulas.Reflection_Cost(Player : Player)
	--// Settings \\--
	local Base_Cost = 1e20

	return Base_Cost
end

function Formulas.Spheres_Cost(Player : Player)
	--// Settings \\--
	local Base_Cost = 25

	Base_Cost = EN.mul(Base_Cost, EN.pow(4, Player.Stats.Sphere_Levels.Value))

	return Base_Cost
end

function Formulas.Accelerator_Levels(Player : Player)
	local Base = 30
	
	Base += Upgrades("Prisms_Accelerator"):GetEffect(Player.Upgrades.Prisms_Accelerator.Value)
	
	return math.clamp(Base, 30, 60)
end

return Formulas
