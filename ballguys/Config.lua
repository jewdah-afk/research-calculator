-- Ball Guys–style merge rules. Tweak numbers here; nothing else hardcodes them.

local Config = {}

-- 11 tiers, smallest -> biggest (matches the prototype's progression bar).
-- radius is in studs; points are awarded when a merge CREATES this tier.
Config.Tiers = {
	{ name = "Blue",     color = Color3.fromRGB(110, 190, 235), radius = 1.0, points = 1 },
	{ name = "Green",    color = Color3.fromRGB(110, 205, 95),  radius = 1.3, points = 3 },
	{ name = "Purple",   color = Color3.fromRGB(175, 120, 225), radius = 1.7, points = 6 },
	{ name = "Pink",     color = Color3.fromRGB(225, 100, 185), radius = 2.1, points = 10 },
	{ name = "Red",      color = Color3.fromRGB(215, 50, 55),   radius = 2.6, points = 15 },
	{ name = "Orange",   color = Color3.fromRGB(220, 135, 45),  radius = 3.1, points = 21 },
	{ name = "Yellow",   color = Color3.fromRGB(220, 200, 70),  radius = 3.7, points = 28 },
	{ name = "White",    color = Color3.fromRGB(225, 228, 235), radius = 4.3, points = 36 },
	{ name = "Black",    color = Color3.fromRGB(35, 40, 50),    radius = 5.0, points = 45 },
	{ name = "Gold",     color = Color3.fromRGB(215, 175, 40),  radius = 5.8, points = 55 },
	{ name = "Cyan",     color = Color3.fromRGB(40, 215, 205),  radius = 6.7, points = 66 },
}
Config.MaxTier = #Config.Tiers

-- Two max-tier balls touching: both vanish for a bonus (classic merge-game finale).
Config.MaxTierClearBonus = 100

-- Only small tiers can be dropped. Weights = relative odds.
Config.DropPool = { [1] = 30, [2] = 25, [3] = 20, [4] = 15, [5] = 10 }

-- Drop pacing
Config.DropCooldown = 0.5 -- seconds between drops

-- Combos: merges within ComboWindow seconds of each other chain.
-- Merge points are multiplied by (1 + (chain-1) * ComboStep), capped.
Config.ComboWindow = 1.0
Config.ComboStep = 0.5
Config.ComboMaxMultiplier = 5

-- Lose rule: a ball (not the one just dropped) staying above the
-- danger line for GraceTime seconds ends the run. A ball leaving the cup ends it instantly.
Config.DangerGraceTime = 2.0
Config.FreshDropImmunity = 1.5 -- seconds a newly dropped ball is ignored

-- Abilities (charges per run). Sniper deletes one ball; Swap trades current & next.
Config.Abilities = {
	Sniper = { charges = 1, earnEveryPoints = 500 },
	Swap   = { charges = 2, earnEveryPoints = 300 },
}

return Config
