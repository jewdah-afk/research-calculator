--!nonstrict
-- ============================================================================================================
-- SampleData: PLACEHOLDER values for UI that has no game system behind it yet. Replace these with live data as
-- each system lands (search the code for `SampleData.` to find every place one is read).
--   * Window bodies show Figma's own sample save (the text baked into UI/Figma/Layouts/*.luau). Binders overwrite
--     the parts that have live data (UI/Binders.luau); everything else stays the Figma sample until wired.
--   * The HUD reads the values below for the context bars, hotbars and prompts when the state has no number.
-- ============================================================================================================
local SampleData = {}

-- context bar (top centre), per area. level / xp come from the save where it has them (see Hud.updateContext)
SampleData.context = {
	fishing = { level = 12, xp = 1240, need = 2000, info = { "128 caught", "3 per catch" } },
	mine = { title = "AREA 3", level = 3, xp = 820e3, need = 1.8e6, unit = "HP", info = { "+8% damage here", "1.8M HP for next" } },
	expedition = { level = 18, xp = 1.2e6, need = 3.4e6, info = { "x1.25 points", "4:32", "NIGHT floor 7", "0:45 boss back" } },
	echo = { count = 12, cap = 40, info = { "25% chance", "+1.2K per echo egg", "4.5M lifetime" } },
	desert = { count = 18, cap = 24, info = { "4.5% chance", "1.2K per golden egg", "12s SANDSTORM" } },
	nest = { title = "NEST III", level = 3, xp = 4200, need = 6000, info = { "x1.50 twigs", "Move close to a tree to collect" } },
}

-- hotbar (bottom centre)
SampleData.hotbar = {
	fishing = { baitCount = 24, cooldown = 1.4 },
	mine = { giantIn = 42, restFor = 18 },
	expedition = { potions = 2, hp = 8400, hpMax = 12000 },
}

-- context AUTO key: fishing unlocks at 10 catches (Birb), the mine at area 1
SampleData.autoFish = { have = 3, need = 10 }

-- [E] prompts shown near stations (no proximity system yet: Hud.prompt(kind) shows one, nil hides)
SampleData.prompts = { "aquarium", "fish market", "expedition", "return", "next floor", "station", "platform" }

-- companions list levels for companions the save does not track yet
SampleData.companions = { redpanda = "III" }

-- Profile / Settings / Teleport / Leaderboards / Offline (hand-built screens): rows with no backing data yet
SampleData.leaderboards = {
	{ "BirbLord", "1.84SpSpg" }, { "PeckQueen", "255.75Dc" }, { "EggHoarder", "12.4No" }, { "MoltMaster", "980.1Oc" },
	{ "SeedSniper", "44.2Sp" }, { "CrowCaller", "3.3Sx" }, { "TwigTwister", "870.2Qi" }, { "you", "2.41Qd" },
}
SampleData.offline = { hours = 6.4, cap = 8, eggs = "2.41Qd", twigs = "128.4K", panda = "55%" }

return SampleData
