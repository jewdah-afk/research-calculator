local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = game.ReplicatedStorage.Framework.Libraries.Upgrades
local Runes = game.ReplicatedStorage.Framework.Libraries.Runes

function ReconcileKey(Data : {}, Key : string, Default : any)
	return (Data and Data[Key]) or Default
end

return function(Data)
	local Reconciled_Data = {
		Stats = {
			Tier = ReconcileKey(Data, "Tier", 0);
			Chromatize = ReconcileKey(Data, "Chromatize", 0); -- Basically tiers for world 2
			Chromify = ReconcileKey(Data, "Chromify", 0); -- Basically tiers for world 2
			
			HazeStartTime = ReconcileKey(Data, "HazeStartTime" , -1);
			HazeTotalTime = ReconcileKey(Data, "HazeTotalTime", 24*60*60);
			
			HailStartTime = ReconcileKey(Data, "HailStartTime" , -1);
			HailTotalTime = ReconcileKey(Data, "HailTotalTime", 24*60*60);
			
			LootStartTime = ReconcileKey(Data, "LootStartTime" , -1);
			LootTotalTime = ReconcileKey(Data, "LootTotalTime", 10*60);
			
			ChromaStartTime = ReconcileKey(Data, "ChromaStartTime" , -1);
			ChromaTotalTime = ReconcileKey(Data, "ChromaTotalTime", 10);
			
			ShineStartTime = ReconcileKey(Data, "ShineStartTime" , -1);
			ShineTotalTime = ReconcileKey(Data, "ShineTotalTime", 30);
			
			AscendedStartTime = ReconcileKey(Data, "AscendedStartTime2" , -1);
			AscendedTotalTime = ReconcileKey(Data, "AscendedTotalTime", 2);
			

			LightStartTime = ReconcileKey(Data, "LightStartTime" , -1);
			LightTotalTime = ReconcileKey(Data, "LightTotalTime", 2);
			
			LastLogin = ReconcileKey(Data, "LastLogin", 0);
			
			Energy = ReconcileKey(Data, "Energy", "0");
			Droplets = ReconcileKey(Data, "Droplets", "0");
			Water = ReconcileKey(Data, "Water", "0");
			Flame = ReconcileKey(Data, "Flame", "0");
			["Realm Points"] = ReconcileKey(Data, "Realm Points", "0");
			Power = ReconcileKey(Data, "Power", "0");
			Reflection = ReconcileKey(Data, "Reflection", "0");
			Gears = ReconcileKey(Data, "Gears", 0);
			Prisms = ReconcileKey(Data, "Prisms", "0");
			Orbs = ReconcileKey(Data, "Orbs", "0");
			Accelerator = ReconcileKey(Data, "Accelerator", 0);
			Icicles = ReconcileKey(Data, "Icicles", "0");
			ArcticPoints = ReconcileKey(Data, "ArcticPoints", "0");
			Ice = ReconcileKey(Data, "Ice", "0");
			Haze = ReconcileKey(Data, "Haze", 0);
			Chroma = ReconcileKey(Data, "Chroma", 0);
			Shine = ReconcileKey(Data, "Shine", 0);
			Light = ReconcileKey(Data, "Light", 0);
			Hail = ReconcileKey(Data, "Hail", 0);
			Loot = ReconcileKey(Data, "Loot", 0);
			
			XP = ReconcileKey(Data, "XP", "0");
			Level = ReconcileKey(Data, "Level", 0);
			
			--[ Realm Purchases ]
			R1_Purchased = ReconcileKey(Data, "R1_Purchased", true);
			R2_Purchased = ReconcileKey(Data, "R2_Purchased", false);
			
			--[ Upgrades ]
			Color_Rune_Luck = ReconcileKey(Data, "Color_Rune_Luck", 1);
			Polychrome_Rune_Luck = ReconcileKey(Data, "Polychrome_Rune_Luck", 1);
			Arctic_Rune_Luck = ReconcileKey(Data, "Arctic_Rune_Luck", 1);
			
			Arctic_Rune_Bulk = ReconcileKey(Data, "Arctic_Rune_Bulk", 1);
			Royal_Rune_Bulk = ReconcileKey(Data, "Royal_Rune_Bulk", 1);
			Polychrome_Rune_Bulk = ReconcileKey(Data, "Polychrome_Rune_Bulk", 1);
			
			Global_Rune_Luck = ReconcileKey(Data, "Global_Rune_Luck", 1);
			Global_Rune_Bulk = ReconcileKey(Data, "Global_Rune_Bulk", 1); -- This is a multiplier
			
			
			--[ Ascensions ]--
			AscensionOne = ReconcileKey(Data, "AscensionOne", false);
	
			Mobs_Level = ReconcileKey(Data, "Mobs_Level", 1);
			Mobs_SetLevel = ReconcileKey(Data, "Mobs_SetLevel", 1);
			Flesh = ReconcileKey(Data, "Flesh", "0");
			Mobs_Killed = ReconcileKey(Data, "Mobs_Killed", 0);
			Mobs_TotalKilled = ReconcileKey(Data, "Mobs_TotalKilled", 0);
			
			Cube_Level = ReconcileKey(Data, "Cube_Level", 1);

			Spheres = ReconcileKey(Data, "Spheres", "0");
			Sphere_Levels = ReconcileKey(Data, "Sphere_Levels", 0);

			Realm = ReconcileKey(Data, "Realm", "One");
			Location = ReconcileKey(Data, "Location", "0;0;0");
			Playtime = ReconcileKey(Data, "Playtime", 0);
			TimeJoined = ReconcileKey(Data, "TimeJoined", tick());
			TierTwelveTime = ReconcileKey(Data, "TierTwelveTime", 0);
			RobuxSpent = ReconcileKey(Data, "RobuxSpent", 0);
			RobuxDonated = ReconcileKey(Data, "RobuxDonated", 0);
			Verified = ReconcileKey(Data, "Verified", false);
			RLBoost = ReconcileKey(Data, "RLBoost", false);
			RBBoost = ReconcileKey(Data, "RBBoost", false);
			RSBoost = ReconcileKey(Data, "RSBoost", false);
			RSBoost2 = ReconcileKey(Data, "RSBoost2", false);
			BulkFix = ReconcileKey(Data, "BulkFix", false);
			BanTracker = ReconcileKey(Data, "BanTracker", 0);
			Blitz = ReconcileKey(Data, "Blitz", false);
			LikeReward = ReconcileKey(Data, "LikeReward", 0);
			RobuxTokens = ReconcileKey(Data, "RobuxTokens", 0);

			Basic_Opened = ReconcileKey(Data, "Basic_Opened", 0);
			Color_Opened = ReconcileKey(Data, "Color_Opened", 0);
			Nature_Opened = ReconcileKey(Data, "Nature_Opened", 0);
			Polychrome_Opened = ReconcileKey(Data, "Polychrome_Opened", 0);
			Cryo_Opened = ReconcileKey(Data, "Cryo_Opened", 0);
			Arctic_Opened = ReconcileKey(Data, "Arctic_Opened", 0);
			Beginner_Opened = ReconcileKey(Data, "Beginner_Opened", 0);
			Royal_Opened = ReconcileKey(Data, "Royal_Opened", 0);
			Galactic_Opened = ReconcileKey(Data, "Galactic_Opened", 0);
			
			Tickets = ReconcileKey(Data, "Tickets", "0");
			Total_Tickets = ReconcileKey(Data, "Total_Tickets", 0);
			
			Total_Energy = ReconcileKey(Data, "Total_Energy", "0");
			Runes_Opened = ReconcileKey(Data, "Runes_Opened", 0);
			RawRunes_Opened = ReconcileKey(Data, "RawRunes_Opened", 0);
			Highest_Tier = ReconcileKey(Data, "Highest_Tier", 0);
			Highest_Cube = ReconcileKey(Data, "Highest_Cube", 1);
			
			Tutorial_Finished = ReconcileKey(Data, "Tutorial_Finished", false);
			
			InChallenge = ReconcileKey(Data, "InChallenge", false);
			CurrentChallenge = ReconcileKey(Data, "CurrentChallenge", "");
			
			C1 = ReconcileKey(Data, "C1", false);
			C2 = ReconcileKey(Data, "C2", false);
			C3 = ReconcileKey(Data, "C3", false);
			C4 = ReconcileKey(Data, "C4", false);
			
			GlobalElixir = ReconcileKey(Data, "GlobalElixir", 0);
			ServerElixir = ReconcileKey(Data, "ServerElixir", 0);
			ServerElixirDuration = ReconcileKey(Data, "ServerElixirDuration", 0);
			
			StatsElixir = ReconcileKey(Data, "StatsElixir", 0);
			StatsElixirDuration = ReconcileKey(Data, "StatsElixirDuration", 0);
			RuneLuckElixir = ReconcileKey(Data, "RuneLuckElixir", 0);
			RuneLuckElixirDuration = ReconcileKey(Data, "RuneLuckElixirDuration", 0);
			RuneSpeedElixir = ReconcileKey(Data, "RuneSpeedElixir", 0);
			RuneSpeedElixirDuration = ReconcileKey(Data, "RuneSpeedElixirDuration", 0);
			
			Starter_Pack_Timer = ReconcileKey(Data, "Starter_Pack_Timer", 3600);
			
			SecretStatsProduct = ReconcileKey(Data, "SecretStatsProduct", 1);
			SecretStatsLevel = ReconcileKey(Data, "SecretStatsLevel", 0);
			
			RuneBulkProduct = ReconcileKey(Data, "RuneBulkProduct", 0);
			RuneLuckLevel = ReconcileKey(Data, "RuneLuckLevel", 0);
			RuneLuckProduct = ReconcileKey(Data, "RuneLuckProduct", 1);
			RuneSpeedLevel = ReconcileKey(Data, "RuneSpeedLevel", 0);
			RuneSpeedProduct = ReconcileKey(Data, "RuneSpeedProduct", 1);
			RuneCloneProduct = ReconcileKey(Data, "RuneCloneProduct", 0);
			RuneBulkLevel = ReconcileKey(Data, "RuneBulkLevel", 0);
			RuneBulkMultiplierProduct = ReconcileKey(Data, "RuneBulkMultiplierProduct", 1);
			
			AntimatterProduct = ReconcileKey(Data, "AntimatterProduct", 0);
			BoundlessProduct = ReconcileKey(Data, "BoundlessProduct", 0);
			EtherbornProduct = ReconcileKey(Data, "EtherbornProduct", 0);
			AnkhProduct = ReconcileKey(Data, "AnkhProduct", 0);
			OmenProduct = ReconcileKey(Data, "OmenProduct", 0);
			PrimordialProduct = ReconcileKey(Data, "PrimordialProduct", 0);
			EternalProduct = ReconcileKey(Data, "EternalProduct", 0);
			
			LeaderboardTimer = ReconcileKey(Data, "LeaderboardTimer", 0);
			GrinderBonus = ReconcileKey(Data, "GrinderBonus", false);
			
			Akn_Follow = ReconcileKey(Data, "Akn_Follow", false);
			Icy_Follow = ReconcileKey(Data, "Icy_Follow", false);
			Ayla_Follow = ReconcileKey(Data, "Ayla_Follow", false);
			Iris_Follow = ReconcileKey(Data, "Iris_Follow", false);
			Luffy_Follow = ReconcileKey(Data, "Luffy_Follow", false);
			Draco_Follow = ReconcileKey(Data, "Draco_Follow", false);
			Nexo_Follow = ReconcileKey(Data, "Nexo_Follow", false);
			
			
			Gifting_Change = ReconcileKey(Data , "Gifting_Change", false);
			
			Booster_Pack = ReconcileKey(Data, "Booster_Pack", false);
			Runic_Bundle = ReconcileKey(Data, "Runic_Bundle", false);
			Elixir_Bundle = ReconcileKey(Data, "Elixir_Bundle", false);
			
			Color_StarStage = ReconcileKey(Data, "Color_StarStage", "Star1");
			Arctic_StarStage = ReconcileKey(Data, "Arctic_StarStage", "Star1");
			Polychrome_StarStage = ReconcileKey(Data, "Polychrome_StarStage", "Star1");
			Royal_StarStage = ReconcileKey(Data, "Royal_StarStage", "Star1");
						
			IceUnlocked = ReconcileKey(Data, "IceUnlocked", false);
			
			Droplets_Multiplier = ReconcileKey(Data, "Droplets_Multiplier", 1);
			Water_Multiplier = ReconcileKey(Data, "Water_Multiplier", 1);
			Ice_Multiplier = ReconcileKey(Data, "Ice_Multiplier", 1);
			AP_Multiplier = ReconcileKey(Data, "AP_Multiplier", 1);
			Chromium_Multiplier = ReconcileKey(Data, "Chromium_Multiplier", 1);
			Prisms_Multiplier = ReconcileKey(Data, "Prisms_Multiplier", 1);
			Spheres_Multiplier = ReconcileKey(Data, "Spheres_Multiplier", 1);
			Icicles_Multiplier = ReconcileKey(Data, "Icicles_Multiplier", 1);
			
			Tier_Freeze = ReconcileKey(Data, "Tier_Freeze", 0);

			Color_RuneLuck = ReconcileKey(Data, "Color_RuneLuck", 1);
			Arctic_RuneLuck = ReconcileKey(Data, "Arctic_RuneLuck", 1);
			Polychrome_RuneLuck = ReconcileKey(Data, "Polychrome_RuneLuck", 1);
			Chromium = ReconcileKey(Data, "Chromium", "0");
			
			GGPlaytimeTimer = ReconcileKey(Data, "GGPlaytimeTimer", 0);
			GGRunesTimer = ReconcileKey(Data, "GGRunesTimer", 0);
			
			GGPlaytimeRank = ReconcileKey(Data, "GGPlaytimeRank", 0);
			GGRobuxRank = ReconcileKey(Data, "GGRobuxRank", 0);
			GGRunesRank = ReconcileKey(Data, "GGRunesRank", 0);
			
			PlaytimeStreak = ReconcileKey(Data, "PlaytimeStreak", 0);
			
			UltraPackBundle = ReconcileKey(Data, "UltraPackBundle", false);
			AncientPack = ReconcileKey(Data, "AncientPack", false);
			MadnessPack = ReconcileKey(Data, "MadnessPack", false);
			RunePack = ReconcileKey(Data, "RunePack", false);
			RunePackV2 = ReconcileKey(Data, "RunePackV2", false);
			
		};
		
		Settings = {
			Music = true;
			SoundEffects = true;
			Particles = true;
			Overhead = true;
			Players = true;
			ChatTags = true;
			Automation = true;
			RuneLuck = true;
			Gifting = false;
			Popups = true;
			Scientific = false;
			Shadows = true;
			MaxUpg = true;
			
			SetWalkSpeed = ReconcileKey(Data, "SetWalkSpeed", 16);
		};
		
		["OverheadPins"] = {
			Energy_Pin = true;
			Flame_Pin = true;
			Power_Pin = true;
			RealmPoints_Pin = true;
			Damage_Pin = true;
			Flesh_Pin = true;
			Prisms_Pin = true;
			Orbs_Pin = true;
			Spheres_Pin = true;
			Prime_Pin = true;
			Droplets_Pin = false;
			Chromium_Pin= false;
			Water_Pin = false;
			ArcticPoints_Pin = false;
			Icicles_Pin = false;
			Ice_Pin = false;
		};
		
		Gamepasses = {
			Grinder = ReconcileKey(Data, "Grinder", false);
			Prime = ReconcileKey(Data, "Prime", false);
			MoreRuneSpeed = ReconcileKey(Data, "MoreRuneSpeed", false);
			MoreRuneLuck = ReconcileKey(Data, "MoreRuneLuck", false);
			Sprint = ReconcileKey(Data, "Sprint", false);
			MoreAttackSpeed = ReconcileKey(Data, "MoreAttackSpeed", false);
			MoreDamage = ReconcileKey(Data, "MoreDamage", false);
			MoreStats = ReconcileKey(Data, "MoreStats", false);
			MorePrisms = ReconcileKey(Data, "MorePrisms", false);
			TripleEnergy = ReconcileKey(Data, "TripleEnergy", false);
			X2Chromium = ReconcileKey(Data, "X2Chromium", 0);
			FasterSecretStats = ReconcileKey(Data, "FasterSecretStats", false);
			--GlobalBundle = ReconcileKey(Data, "GlobalBundle", false);
			--UltraPack = ReconcileKey(Data, "UltraPack", false);
			
		};
		
		ChatSettings = {
			OGPinned = ReconcileKey(Data, "OGPinned", false);
			PrimePinned = ReconcileKey(Data, "PrimePinned", false);
			TotalEnergyPinned = ReconcileKey(Data, "TotalEnergyPinned", false);
			RobuxSpentPinned = ReconcileKey(Data, "RobuxSpentPinned", false);
			PrismsPinned = ReconcileKey(Data, "PrismsPinned", false);
			RunesOpenedPinned = ReconcileKey(Data, "RunesOpenedPinned", false);
			PlaytimePinned = ReconcileKey(Data, "PlaytimePinned", false);
		};
		
		Upgrades = {
			
		}; -- Automated
		
		Runes = {
			
			-- Global Runes
			Lightmatter = ReconcileKey(Data, "Lightmatter", 0);
			Darkmatter = ReconcileKey(Data, "Darkmatter", 0);
			Antimatter = ReconcileKey(Data, "Antimatter", 0);
			Etherborn = ReconcileKey(Data, "Etherborn", 0);
			
			-- Ultra Runes
			Eternal = ReconcileKey(Data, "Eternal", 0);
			Primordial = ReconcileKey(Data, "Primordial", 0);
			Boundless = ReconcileKey(Data, "Boundless", 0);
			Almighty = ReconcileKey(Data, "Almighty", 0);
			Omnipotent = ReconcileKey(Data, "Omnipotent", 0);
			Omniscient = ReconcileKey(Data, "Omniscient", 0);
			
			-- Ancient Runes
			Omen = ReconcileKey(Data, "Omen", 0);
			Ankh = ReconcileKey(Data, "Ankh", 0);
			Sigil = ReconcileKey(Data, "Sigil", 0);
			Glyph = ReconcileKey(Data, "Glyph", 0);
			Bone = ReconcileKey(Data, "Bone", 0);
			Dust = ReconcileKey(Data, "Dust", 0);
			
			-- Madness Runes
			Malevolence = ReconcileKey(Data, "Malevolence", 0);
			Vehemence = ReconcileKey(Data, "Vehemence", 0);
			Violence = ReconcileKey(Data, "Violence", 0);
			Rage = ReconcileKey(Data, "Rage", 0);
			Mad = ReconcileKey(Data, "Mad", 0);
			
			Cryo = ReconcileKey(Data, "Cryo", 0)
		}; -- Automated
	}
	
	for Setting , _ in Reconciled_Data.Settings do
		if Setting == "SetRuneLuck" or Setting == "SetWalkSpeed" then continue end
		
		if not Data or Data[Setting] == nil then
			if Setting == "Scientific" then Reconciled_Data.Settings.Scientific = false continue end
			Reconciled_Data.Settings[Setting] = true
			continue
		end
		
		Reconciled_Data.Settings[Setting] = Data[Setting]
	end
	
	for OverheadPin , _ in Reconciled_Data.OverheadPins do
		if not Data or Data[OverheadPin] == nil then
			Reconciled_Data.OverheadPins[OverheadPin] = true
			continue
		end

		Reconciled_Data.OverheadPins[OverheadPin] = Data[OverheadPin]
	end
	
	for _ , Category in Upgrades:GetChildren() do
		for _ , Upgrade in Category:GetChildren() do
			Reconciled_Data.Upgrades[Upgrade.Name] = ReconcileKey(Data, Upgrade.Name, 0)
		end
	end

	for _ , Category in Runes:GetChildren() do
		Category = require(Category)
		for _ , Rune in Category.Runes do
			Reconciled_Data.Runes[Rune.Name] = ReconcileKey(Data, Rune.Name, 0)
		end
	end
	
	if not Reconciled_Data.Stats.Gifting_Change then
		Reconciled_Data.Stats.Gifting_Change = true
		Reconciled_Data.Settings.Gifting = false
	end
	
	if Reconciled_Data.Gamepasses.FasterSecretStats then
		Reconciled_Data.Stats.HazeTotalTime = 24 * 60 * 60 * 0.5
		Reconciled_Data.Stats.HailTotalTime = 24 * 60 * 60 * 0.5
		Reconciled_Data.Stats.LootTotalTime = 10 * 60 * 0.5
		Reconciled_Data.Stats.ChromaTotalTime = 10 * 0.5
		Reconciled_Data.Stats.ShineTotalTime = 30 * 0.5
		Reconciled_Data.Stats.AscendedTotalTime = 2 * 0.5
		Reconciled_Data.Stats.LightTotalTime = 2 * 0.5
	end
	
	if typeof(Reconciled_Data.Stats.Tickets) == "number" then Reconciled_Data.Stats.Tickets = EN.toString(EN.convert(Reconciled_Data.Stats.Tickets)) end

	return Reconciled_Data
end