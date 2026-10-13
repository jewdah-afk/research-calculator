--[[
	Game-wide settings. The only file to edit when publishing:
	  1. Create each game pass and developer product on the Creator Dashboard (names and prices below).
	  2. Paste their asset ids into PASS_IDS and PRODUCT_IDS.
	An id of 0 means "not created yet": the store shows the item but can't sell it, and nobody owns it
	(in Studio, STUDIO_OWNS_ALL_PASSES lets you test every pass).
	What each pass and product does, and its price, comes from onslaught-data/expansion.json (ExpansionData).
]]

local Config = {}

Config.PASS_IDS = {
	vip = 0,
	speed = 0,
	commander = 0,
	clearance = 0,
	supply = 0,
	intel2 = 0,
	combomaster = 0,
	arsenal = 0,
	skins_retro = 0,
	skins_neon = 0,
}
-- revive_2 and revive_3 are the doubled Second Chance prices (99 -> 199 -> 399 Robux); a product has one fixed price.
Config.PRODUCT_IDS = {
	drop_s = 0,
	drop_m = 0,
	drop_l = 0,
	life = 0,
	revive = 0,
	revive_2 = 0,
	revive_3 = 0,
	airstrike = 0,
	freeze = 0,
	intel_s = 0,
	intel_m = 0,
	intel_l = 0,
	intel_xl = 0,
	xpboost = 0,
	partyboost = 0,
	reroll = 0,
}

Config.STUDIO_OWNS_ALL_PASSES = true -- Studio play-tests only; live servers always ask MarketplaceService
Config.MAX_PARTY = 4
Config.SPEEDS = { 1, 2, 3, 5 } -- 3x and 5x need the Speed Demon pass (host's)
Config.FREE_SPEED = 2
Config.SNAPSHOT_HZ = 15 -- server -> client state updates per second
Config.MAX_STEPS_PER_FRAME = 600 -- ms of game time simulated per Heartbeat at most (5x at 60 fps needs ~83)
Config.ACTIONS_PER_SECOND = 30 -- per player; extra actions are dropped
Config.PARTY_ARRIVE_TIMEOUT = 45 -- seconds a match server waits for the rest of the party
Config.AUTOSAVE_SECONDS = 90
Config.DATASTORE = "OnslaughtProfiles_v1"
Config.LEADERBOARD_STORES = {
	classic = "OnslaughtBestWave_Classic_v1", -- pure runs: Classic rules, no balance passes or products
	plus = "OnslaughtBestWave_Plus_v1", -- Onslaught+ runs that used no in-game product
	kills = "OnslaughtLifetimeKills_v1", -- EternityNum-encoded (lbencode)
}
Config.BOARD = { scale = 0.1, height = 0.5 } -- 1 px of the original 720x480 board = 0.1 studs

return Config
