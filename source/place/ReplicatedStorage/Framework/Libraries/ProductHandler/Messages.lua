local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")

return {
	--[[ BUNDLES ]]--
	[792138184] = function(Player : Player)
		return "Thank you for purchasing Grinder!"
	end,
	
	[1814656195] = function(Player : Player)
		return "Thank you for purchasing Infinite Elixirs!"
	end,
	
	[3345764905] = function(Player : Player)
		return "Thank you for purchasing x1.1 Rune Luck!"
	end,
	
	[3348081399] = function(Player : Player)
		return "Thank you for purchasing x1.05 Rune Speed!"
	end,
	
	[3359401666] = function(Player : Player)
		return "Thank you for purchasing +0.5x Secret Stats!"
	end,
	
	[3350893660] = function(Player : Player)
		return "Thank you for purchasing +0.25x Rune Bulk!"
	end,
	

	[3357869982] = function(Player : Player)
		return "Thank you for purchasing +1 Antimatter Rune!"
	end,

	[3357915813] = function(Player : Player)
		return "Thank you for purchasing +1 Boundless Rune!"
	end,
	
	[3360190882] = function(Player : Player)
		return "Thank you for purchasing +1 Etherborn Rune!"
	end,

	[3362614318] = function(Player : Player)
		return "Thank you for purchasing +1 Ankh Rune!"
	end,
	
	[3365757590] = function(Player : Player)
		return "Thank you for purchasing +1 Primordial Rune!"
	end,
	
	[3365754337] = function(Player : Player)
		return "Thank you for purchasing +1 Omen Rune!"
	end,
	
	[3365757966] = function(Player : Player)
		return "Thank you for purchasing +1 Eternal Rune!"
	end,
	
	[3226715563] = function(Player : Player)
		return "Thank you for purchasing Ultra Pack!"
	end,
	
	[3355888276] = function(Player : Player)
		return "Thank you for purchasing Ancient Pack!"
	end,
	

	[3362614840] = function(Player : Player)
		return "Thank you for purchasing Madness Pack!"
	end,
	
	[3144442512] = function(Player : Player)
		return "Thank you for purchasing Starter Pack!"
	end,
	
	[3354370539] = function(Player : Player)
		return "Thank you for purchasing the Rune Pack V2!"
	end,
	
	[3290590303] = function(Player : Player)
		return "Thank you for purchasing Global Bundle!"
	end,
	
	[3354354611] = function(Player : Player)
		return "Thank you for purchasing Global Bundle II!"
	end,
	
	[2875625034] = function(Player : Player)
		return "Thank you for purchasing the Elixir Bundle!"
	end,
	
	[3144440764] = function(Player : Player)
		return "Thank you for purchasing Booster Pack!"
	end,
	
	[3144387087] = function(Player : Player)
		return "Thank you for purchasing Super Bundle!"
	end,

	[3144471596] = function(Player : Player)
		return "Thank you for purchasing Runic Bundle"
	end,
	
	--[[ OFFERS ]]--
	[1044507959] = function(Player : Player)
		return "Thank you for purchasing Triple Energy!"
	end,

	--[[ FEATURED ]]--
	[2700372705] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl {math.floor(Player.Stats.RuneCloneProduct.Value)}!`
	end,

	[3345688812] = function(Player : Player)
		return `Thank you for purchasing Rune Bulk Lvl {math.floor(Player.Stats.RuneBulkProduct.Value)}!`
	end,
	
	[2700303341] = function(Player : Player)
		return `Thank you for purchasing Rune Bulk Lvl {math.floor(Player.Stats.RuneBulkProduct.Value)}!`
	end,
	
	[2836283999] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 1!`
	end,

	[2700372705] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 2!`
	end,

	[2700372980] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 3!`
	end,

	[2700373142] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 4!`
	end,

	[2700373392] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 5!`
	end,

	[2700373559] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 6!`
	end,

	[2700373904] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 7!`
	end,
	
	[3106634261] = function(Player : Player)
		return `Thank you for purchasing Rune Clone Lvl 8!`
	end,
	
	[792703755] = function(Player : Player)
		return `Thank you for purchasing Rune Bulk Lvl 5!`
	end,

	--[[ PASSES ]]--
	[792235071] = function(Player : Player)
		return "Thank you for purchasing Prime!"
	end,
	
	[791787809] = function(Player : Player)
		return "Thank you for purchasing X2 Stats!"
	end,
	
	[791769975] = function(Player : Player)
		return "Thank you for purchasing X2 Rune Luck!"
	end,

	[791941355] = function(Player : Player)
		return "Thank you for purchasing X2 Rune Speed!"
	end,

	[791999108] = function(Player : Player)
		return "Thank you for purchasing Sprint!"
	end,

	[792134127] = function(Player : Player)
		return "Thank you for purchasing X2 Prisms!"
	end,
	
	[3226710712] = function(Player : Player)
		return "Thank you for purchasing Faster Secret Stats!"
	end,
	
	[3226702193] = function(Player : Player)
		return "Thank you for purchasing X2 Chromium!"
	end,

	[791995082] = function(Player : Player)
		return "Thank you for purchasing X1.5 Attack Speed and Faster Generation!"
	end,

	[791665991] = function(Player : Player)
		return "Thank you for purchasing X3 Damage!"
	end,
	
	--[[ ELIXIRS ]]--
	[2701666839] = function(Player: Player)
		return "Thank you for purchasing 1 Global Elixir!"
	end,

	[2701672538] = function(Player: Player)
		return "Thank you for purchasing 10 Global Elixirs!"
	end,

	[1814498795] = function(Player: Player)
		return "Thank you for purchasing 1 Server Elixir!"
	end,

	[1815125222] = function(Player: Player)
		return "Thank you for purchasing 10 Server Elixirs!"
	end,

	[1814496426] = function(Player: Player)
		return "Thank you for purchasing 1 Stat Elixir!"
	end,

	[1814496569] = function(Player: Player)
		return "Thank you for purchasing 10 Stat Elixirs!"
	end,

	[1814492707] = function(Player: Player)
		return "Thank you for purchasing 1 Rune Luck Elixir!"
	end,

	[1814493014] = function(Player: Player)
		return "Thank you for purchasing 10 Rune Luck Elixirs!"
	end,

	[1814494326] = function(Player: Player)
		return "Thank you for purchasing 1 Rune Speed Elixir!"
	end,

	[1814494448] = function(Player: Player)
		return "Thank you for purchasing 10 Rune Speed Elixirs!"
	end,
	
	[2875625034] = function(Player : Player)
		return "Thank you for purchasing the Elixir Bundle!"
	end,
	
	--[[ TICKETS ]]--
	[1814487036] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(2.5e4 * Multi)} Tickets!`
	end,
	
	[1814486537] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(5e3 * Multi)} Tickets!`
	end,
	
	[1814485924] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(1e3 * Multi)} Tickets!`
	end,
	
	[1814485720] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(300 * Multi)} Tickets!`
	end,
	
	[1814485591] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(100 * Multi)} Tickets!`
	end,
	
	[1814485131] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(50 * Multi)} Tickets!`
	end,
	
	[1814482025] = function(Player: Player)
		local Multi = Formulas.Tickets(Player)
		return `Thank you for purchasing {EN.Format(10 * Multi)} Tickets!`
	end,
	
	--[[ RTOKENS ]]--
	[3144476691] = function(Player: Player)
		return "Thank you for purchasing 10 RTokens!"
	end,

	[3144477913] = function(Player: Player)
		return "Thank you for purchasing 50 RTokens!"
	end,

	[3144478033] = function(Player: Player)
		return "Thank you for purchasing 100 RTokens!"
	end,

	[3144478323] = function(Player: Player)
		return "Thank you for purchasing 500 RTokens!"
	end,

	[3144478450] = function(Player: Player)
		return "Thank you for purchasing 2000 RTokens!"
	end,

	[3144478596] = function(Player: Player)
		return "Thank you for purchasing 10000 RTokens!"
	end,

	[3144478833] = function(Player: Player)
		return "Thank you for purchasing 25000 RTokens!"
	end,
	
	--[[ DONATIONS ]]--
	[2700376066] = function(Player: Player)
		return "Thank you for Donating 10 Robux! Increasing boost."
	end,

	[2700376274] = function(Player: Player)
		return "Thank you for Donating 50 Robux! Increasing boost."
	end,

	[2700376377] = function(Player: Player)
		return "Thank you for Donating 100 Robux! Increasing boost."
	end,

	[2700376673] = function(Player: Player)
		return "Thank you for Donating 500 Robux! Increasing boost."
	end,

	[2700376803] = function(Player: Player)
		return "Thank you for Donating 2500 Robux! Increasing boost."
	end,

	[2700377017] = function(Player: Player)
		return "Thank you for Donating 10000 Robux! Increasing boost."
	end,

	[2700377146] = function(Player: Player)
		return "Thank you for Donating 50000 Robux! Increasing boost."
	end,
	
	[2837094737] = function(Player : Player)
		return "Thank you for purchasing the Starter Pack. Enjoy the Free Tier Ups and Tickets!"
	end,
	
	--[ Global Runes ]--
	[1814500714] = function(Player : Player)
		return "Thank you for purchasing a Global Rune!"
	end,

	[2700366584] = function(Player : Player)
		return "OMG, Thank you for purchasing 10x Global Runes!"
	end,
	
	[2992210697] = function(Player : Player)
		return "OMGG, Thank you for purchasing 100x Global Runes!!!"
	end,
	
	[3348035777] = function(Player : Player)
		return "HOLYY, Thank you for purchasing 1000x Global Runes!!!"
	end,
	
	--[ Ultra Runes ]--
	[3226706331] = function(Player : Player)
		return "Thank you for purchasing a Ultra Rune!"
	end,

	[3226707317] = function(Player : Player)
		return "OMG, Thank you for purchasing 10x Ultra Runes!"
	end,

	[3226707595] = function(Player : Player)
		return "OMGG, Thank you for purchasing 100x Ultra Runes!!!"
	end,
	
	[3348035329] = function(Player : Player)
		return "HOLYY, Thank you for purchasing x1000 Ultra Runes!!!"
	end,
	
	--[ Ancient Runes ]--
	[3355767327] = function(Player : Player)
		return "Thank you for purchasing an Ancient Rune!"
	end,

	[3355767497] = function(Player : Player)
		return "OMG, Thank you for purchasing 10x Ancient Runes!"
	end,

	[3355767667] = function(Player : Player)
		return "OMGG, Thank you for purchasing 100x Ancient Runes!!!"
	end,

	[3355767833] = function(Player : Player)
		return "HOLYY, Thank you for purchasing x1000 Ancient Runes!!!"
	end,

	[3355792504] = function(Player : Player)
		return "????, Thank you for purchasing x10000 Ancient Runes!!!"
	end,

	[3362608256] = function(Player : Player)
		return "Thank you for purchasing an Madness Rune!"
	end,

	[3362610779] = function(Player : Player)
		return "OMG, Thank you for purchasing 10x Madness Runes!"
	end,

	[3362611353] = function(Player : Player)
		return "OMGG, Thank you for purchasing 100x Madness Runes!!!"
	end,

	[3362611713] = function(Player : Player)
		return "HOLYY, Thank you for purchasing x1000 Madness Runes!!!"
	end,

	[3362612521] = function(Player : Player)
		return "????, Thank you for purchasing x10000 Madness Runes!!!"
	end,

	
	
	
}