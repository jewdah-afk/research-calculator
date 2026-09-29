local Framework = require(game.ReplicatedStorage.Framework)
local Formulas = Framework:GetSharedModule("Formulas")
local Messenger = Framework:GetLibrary("Messenger")
local GlobalRune = Framework:GetLibrary("GlobalRune")
local UltraRune = Framework:GetLibrary("UltraRune")
local AncientRune = Framework:GetLibrary("AncientRune")
local MadnessRune = Framework:GetLibrary("MadnessRune")
local RTokensRatio = 1

local EN = Framework:GetLibrary("EternityNum")

return {
	--[[ BUNDLES ]]--
	[792138184] = function(Player : Player)
		Player.Gamepasses.Grinder.Value = true
		
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, 100))
		Player.Stats.GrinderBonus.Value = true
		
		for _, Pass in Player.Gamepasses:GetChildren() do
			if Pass then
				Pass.Value = true
			end
		end
	end,
	
	[3226715563] = function(Player : Player)
		Player.Stats.UltraPackBundle.Value = true
		
		for i = 1, 3, 1 do
			UltraRune.Roll(Player)
		end
		
		Player.Stats.StatsElixir.Value += 2
		Player.Stats.RuneLuckElixir.Value += 2
		Player.Stats.RuneSpeedElixir.Value += 2
	end,
	
	[3355888276] = function(Player : Player)

		for i = 1, 3, 1 do
			AncientRune.Roll(Player)
		end

		Player.Stats.StatsElixir.Value += 1
		Player.Stats.RuneLuckElixir.Value += 1
		Player.Stats.RuneSpeedElixir.Value += 1
	end,
	
	[3362614840] = function(Player : Player)

		for i = 1, 15, 1 do
			MadnessRune.Roll(Player)
		end
		
	end,
	
	[3354370539] = function(Player : Player)
		Player.Stats.RunePackV2.Value = true

		for i = 1, 100, 1 do
			UltraRune.Roll(Player)
		end
		
		for i = 1, 100, 1 do
			GlobalRune.Roll(Player)
		end
	end,
	
	[3290590303] = function (Player : Player) 
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR10";
		})

		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR10"
		})
	end,
	
	[3362639381] = function (Player : Player) 
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR100";
		})

		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR100"
		})
		
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR100"
		})
	end,
	
	[1814656195] = function(Player : Player)
		Player.Stats.StatsElixir.Value += 100000
		Player.Stats.RuneLuckElixir.Value += 100000
		Player.Stats.RuneSpeedElixir.Value += 100000
	end,
	
	[2875625034] = function(Player : Player)
		Player.Stats.StatsElixir.Value += 5
		Player.Stats.RuneLuckElixir.Value += 5
		Player.Stats.RuneSpeedElixir.Value += 5
		
		Player.Stats.Elixir_Bundle.Value = true
	end,
	
	[3144442512] = function(Player : Player)
		Player.Stats.Tier.Value = 4
		Player.Gamepasses.Sprint.Value = true
	end,
	
	[3226702193] = function(Player : Player)
		Player.Gamepasses.X2Chromium.Value = 1
	end,
	
	[3144440764] = function(Player : Player)
		Player.Stats.RobuxTokens.Value += (50 * RTokensRatio) 
		
		for i = 1, 3, 1 do
			GlobalRune.Roll(Player)
		end
		
		Player.Stats.Booster_Pack.Value = true
	end,
	
	[3144387087] = function(Player : Player)
		Player.Stats.StatsElixir.Value += 2
		Player.Stats.RuneLuckElixir.Value += 2
		Player.Stats.RuneSpeedElixir.Value += 2
		
		Player.Stats.RobuxTokens.Value += (50* RTokensRatio) 
	end,
	
	[3144471596] = function(Player : Player)
		Player.Stats.RuneLuckElixir.Value += 3
		Player.Stats.RuneSpeedElixir.Value += 3
		
		Player.Gamepasses.MoreRuneLuck.Value = true
		Player.Gamepasses.MoreRuneSpeed.Value = true
		
		Player.Stats.Runic_Bundle.Value = true
	end,
	
	--[[ OFFERS ]]--
	[1044507959] = function(Player : Player)
		Player.Gamepasses.TripleEnergy.Value = true
	end,
	
	--[[ FEATURED ]]--
	[2836283999] = function(Player : Player)
		 Player.Stats.RuneCloneProduct.Value = 1
	end,
	
	[2700372705] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 2
	end,
	
	[2700372980] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 3
	end,
	
	[2700373142] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 4
	end,
	
	[2700373392] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 5
	end,
	
	[2700373559] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 6
	end,
	
	[2700373904] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 7
	end,
	
	[3106634261] = function(Player : Player)
		Player.Stats.RuneCloneProduct.Value = 8
	end,

	[2700303341] = function(Player : Player)
		Player.Stats.RuneBulkProduct.Value += 10
	end,
	
	[3345688812] = function(Player : Player)
		Player.Stats.RuneBulkProduct.Value += 1
	end,
	

	[2700303341] = function(Player : Player)
		Player.Stats.RuneBulkProduct.Value += 10
	end,
	
	[3345764905] = function(Player : Player)
		Player.Stats.RuneLuckProduct.Value *= 1.1
		Player.Stats.RuneLuckLevel.Value += 1
	end,
	
	[3348081399] = function(Player : Player)
		Player.Stats.RuneSpeedProduct.Value *= 1.05
		Player.Stats.RuneSpeedLevel.Value += 1
	end,
	
	[3350893660] = function(Player : Player)
		Player.Stats.RuneBulkMultiplierProduct.Value += 0.25
		Player.Stats.RuneBulkLevel.Value += 1
	end,
	
	[3357869982] = function(Player : Player)
		Player.Runes.Antimatter.Value += 1
		Player.Stats.AntimatterProduct.Value += 1
	end,

	[3357915813] = function(Player : Player)
		Player.Runes.Boundless.Value += 1
		Player.Stats.BoundlessProduct.Value += 1
	end,


	[3360190882] = function(Player : Player)
		Player.Runes.Etherborn.Value += 1
		Player.Stats.EtherbornProduct.Value += 1
	end,

	[3362614318] = function(Player : Player)
		Player.Runes.Ankh.Value += 1
		Player.Stats.AnkhProduct.Value += 1
	end,
	
	[3365757590] = function(Player : Player)
		Player.Runes.Primordial.Value += 1
		Player.Stats.PrimordialProduct.Value += 1
	end,
	
	[3365754337] = function(Player : Player)
		Player.Runes.Omen.Value += 1
		Player.Stats.OmenProduct.Value += 1
	end,
	
	[3365757966] = function(Player : Player)
		Player.Runes.Eternal.Value += 1
		Player.Stats.EternalProduct.Value += 1
	end,

	[3359401666] = function(Player : Player)
		Player.Stats.SecretStatsProduct.Value += 0.5
		Player.Stats.SecretStatsLevel.Value += 1
	end,



	
	
	--[[ PASSES ]]--
	[792235071] = function(Player : Player)
		Player.Gamepasses.Prime.Value = true
	end,
	
	[791787809] = function(Player : Player)
		Player.Gamepasses.MoreStats.Value = true
	end,
	
	[791769975] = function(Player : Player)
		Player.Gamepasses.MoreRuneLuck.Value = true
	end,
	
	[791941355] = function(Player : Player)
		Player.Gamepasses.MoreRuneSpeed.Value = true
	end,
	
	[791999108] = function(Player : Player)
		Player.Gamepasses.Sprint.Value = true
	end,
	
	[792134127] = function(Player : Player)
		Player.Gamepasses.MorePrisms.Value = true
	end,
	
	[3226710712] = function(Player : Player)
		Player.Gamepasses.FasterSecretStats.Value = true
		Player.Stats.HazeTotalTime.Value = 24 * 60 * 60 * 0.5
		Player.Stats.HailTotalTime.Value = 24 * 60 * 60 * 0.5
		Player.Stats.LootTotalTime.Value = 60 * 10 * 0.5
		Player.Stats.ChromaTotalTime.Value = 10 * 0.5
		Player.Stats.ShineTotalTime.Value = 30 * 0.5
		Player.Stats.AscendedTotalTime.Value = 10 * 0.5
		Player.Stats.LightTotalTime.Value = 2 * 0.5
	end,
	
	[791995082] = function(Player : Player)
		Player.Gamepasses.MoreAttackSpeed.Value = true
	end,
	
	[791665991] = function(Player : Player)
		Player.Gamepasses.MoreDamage.Value = true
	end,
	
	--[[ ELIXIRS ]]--
	[2701666839] = function(Player: Player)
		Player.Stats.GlobalElixir.Value += 1
	end,
	
	[2701672538] = function(Player: Player)
		Player.Stats.GlobalElixir.Value += 10
	end,
	
	[1814498795] = function(Player: Player)
		Player.Stats.ServerElixir.Value += 1
	end,
	
	[1815125222] = function(Player: Player)
		Player.Stats.ServerElixir.Value += 10
	end,
	
	[1814496426] = function(Player: Player)
		Player.Stats.StatsElixir.Value += 1
	end,
	
	[1814496569] = function(Player: Player)
		Player.Stats.StatsElixir.Value += 10
	end,
	
	[1814492707] = function(Player: Player)
		Player.Stats.RuneLuckElixir.Value += 1
	end,
	
	[1814493014] = function(Player: Player)
		Player.Stats.RuneLuckElixir.Value += 10
	end,
	
	[1814494326] = function(Player: Player)
		Player.Stats.RuneSpeedElixir.Value += 1
	end,
	
	[1814494448] = function(Player: Player)
		Player.Stats.RuneSpeedElixir.Value += 10
	end,
	
	--[[ TICKETS ]]--
	[1814487036] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(1.25e5,Multi))))
		
		Player.Stats.StatsElixir.Value += 10
		Player.Stats.RuneLuckElixir.Value += 10
		Player.Stats.RuneSpeedElixir.Value += 10
	end,

	[1814486537] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(2.5e4,Multi))))

		--Player.Stats.Tickets.Value += (2.5e4* Multi)
	end,

	[1814485924] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(5e3,Multi))))

		--Player.Stats.Tickets.Value += (5e3 * Multi)
	end,

	[1814485720] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(1500,Multi))))

		--Player.Stats.Tickets.Value += (1500 * Multi)
	end,

	[1814485591] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(500,Multi))))

		--Player.Stats.Tickets.Value += (500 * Multi)
	end,

	[1814485131] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, (EN.mul(250,Multi))))

		--Player.Stats.Tickets.Value += (250 * Multi)
	end,

	[1814482025] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		
		Player.Stats.Tickets.Value += EN.mul(50,Multi)

		--Player.Stats.Tickets.Value += (50 * Multi)
	end,
	
	--[[ RTOKENS ]]--
	[3144476691] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (10* RTokensRatio) 
	end,
	
	[3144477913] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (50* RTokensRatio) 
	end,
	
	[3144478033] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (100* RTokensRatio) 
	end,
	
	[3144478323] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (500* RTokensRatio) 
	end,
	
	[3144478450] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (2000* RTokensRatio) 
	end,
	
	[3144478596] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (10000* RTokensRatio) 
	end,
	
	[3144478833] = function(Player: Player)
		Player.Stats.RobuxTokens.Value += (25000* RTokensRatio) 
	end,
	
	--[[ DONATIONS ]]--
	[2700376066] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 10
	end,
	
	[2700376274] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 50
	end,
	
	[2700376377] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 100
	end,
	
	[2700376673] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 500
	end,
	
	[2700376803] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 2500
	end,
	
	[2700377017] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 10000
	end,
	
	[2700377146] = function(Player: Player)
		Player.Stats.RobuxDonated.Value += 50000
		
		Player.Stats.StatsElixir.Value += 5
		Player.Stats.RuneLuckElixir.Value += 5
		Player.Stats.RuneSpeedElixir.Value += 5
	end,
	
	--[ PACKS ]--
	[2837094737] = function(Player : Player)
		Player.Stats.Tier.Value = 4
		
		Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, 100))

		--Player.Stats.Tickets.Value += 100
	end,
	
	--[ GLOBAL RUNES ]--
	[1814500714] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR100";
		})
	end,
	
	[2700366584] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR1000";
		})
	end,
	
	[2992210697] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR10000";
		})
		
		Player.Runes.Antimatter.Value += 50
		Player.Runes.Etherborn.Value += 1.5
	end,
	
	[3348035777] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "GR100000";
		})
		
		Player.Runes.Antimatter.Value += 150
		Player.Runes.Etherborn.Value += 10
	end,
	
	--[ ULTRA RUNES ]--
	[3226706331] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR50";
		})
	end,

	[3226707317] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR500";
		})
	end,

	[3226707595] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR5000";
		})
		
		Player.Runes.Boundless.Value += 5
		Player.Runes.Primordial.Value += 1
		Player.Runes.Eternal.Value += 0.3
	end,
	
	[3348035329] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "UR50000";
		})
		
		Player.Runes.Boundless.Value += 50
		Player.Runes.Primordial.Value += 10
		Player.Runes.Eternal.Value += 4
	end,
	
	--[ ANCIENT RUNES ]--
	[3355767327] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR10";
		})
	end,

	[3355767497] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR100";
		})
	end,

	[3355767667] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR1000";
		})
		
		Player.Runes.Ankh.Value += 1
	end,

	[3355767833] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR10000";
		})
		
		Player.Runes.Ankh.Value += 7.5
		Player.Runes.Omen.Value += 0.75
	end,
	
	[3355792504] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "AR100000";
		})
		
		Player.Runes.Ankh.Value += 25
		Player.Runes.Omen.Value += 7.5
	end,
	
	
	--[ MADNESS RUNES ]--
	[3362608256] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "MR3";
		})
	end,

	[3362610779] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "MR30";
		})
	end,

	[3362611353] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "MR300";
		})

		Player.Runes.Violence.Value += 1
	end,

	[3362611713] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "MR3000";
		})

		Player.Runes.Violence.Value += 5
		Player.Runes.Vehemence.Value += 0.1
	end,

	[3362612521] = function(Player : Player)
		Messenger.Publish({
			Sender = Player.Name;
			Type = "MR30000";
		})

		Player.Runes.Vehemence.Value += 0.75
		Player.Runes.Malevolence.Value += 0.25
	end,
};