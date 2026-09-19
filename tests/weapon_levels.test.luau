--!strict
-- Sim/WeaponLevels. Oracle: research/vs/weapons.md base table L27-39, the
-- per-weapon level tables L45-276 (deltas, folded HERE from the .md text),
-- max-level totals, and the shipped `ignores` tips. Player-stat conventions:
-- SCHEMA.md L321-322 and characters.md L256-258.
local T = require("./_harness")
local F = require("./_fixtures")
local WeaponLevels = require("../src/shared/Sim/WeaponLevels")
local Tuning = require("../src/shared/Tuning")
local Weapons = require("../src/shared/Data/Weapons")

local IDS = {
	"whip",
	"magic_wand",
	"knife",
	"axe",
	"runetracer",
	"fire_wand",
	"king_bible",
	"garlic",
	"santa_water",
	"lightning_ring",
	"cross",
}

-- weapons.md L29-39. nil = "-" (field absent from the shipped record).
type BaseRow = {
	damage: number,
	area: number,
	speed: number,
	amount: number,
	duration: number?,
	cooldown: number,
	pierce: number?,
	knockback: number?,
	poolLimit: number,
	projectileInterval: number,
	hitboxDelay: number?,
	critChance: number?,
	critMultiplier: number?,
}
local BASE: { [string]: BaseRow } = {
	whip = {
		damage = 10,
		area = 1,
		speed = 1,
		amount = 1,
		cooldown = 1.35,
		poolLimit = 30,
		projectileInterval = 0.1,
		critChance = 0.2,
		critMultiplier = 2,
	},
	magic_wand = {
		damage = 10,
		area = 1,
		speed = 1,
		amount = 1,
		cooldown = 1.2,
		pierce = 1,
		poolLimit = 60,
		projectileInterval = 0.1,
	},
	knife = {
		damage = 6.5,
		area = 1,
		speed = 1,
		amount = 1,
		cooldown = 1,
		pierce = 1,
		knockback = 0.5,
		poolLimit = 70,
		projectileInterval = 0.1,
		critChance = 0.3,
		critMultiplier = 3,
	},
	axe = {
		damage = 20,
		area = 1,
		speed = 1,
		amount = 1,
		duration = 2,
		cooldown = 4,
		pierce = 3,
		poolLimit = 70,
		projectileInterval = 0.2,
		critChance = 0.3,
		critMultiplier = 2,
	},
	runetracer = {
		damage = 10,
		area = 1,
		speed = 1,
		amount = 1,
		duration = 2.25,
		cooldown = 3,
		poolLimit = 50,
		projectileInterval = 0.2,
		hitboxDelay = 0.5,
	},
	fire_wand = {
		damage = 20,
		area = 1,
		speed = 0.75,
		amount = 3,
		duration = 0.1,
		cooldown = 3,
		poolLimit = 30,
		projectileInterval = 0.02,
	},
	king_bible = {
		damage = 10,
		area = 1,
		speed = 1,
		amount = 1,
		duration = 3,
		cooldown = 3,
		poolLimit = 50,
		projectileInterval = 0,
		hitboxDelay = 1.7,
	},
	garlic = {
		damage = 5,
		area = 1,
		speed = 1,
		amount = 1,
		duration = 1.3,
		cooldown = 1.3,
		knockback = 0,
		poolLimit = 50,
		projectileInterval = 0,
	},
	santa_water = {
		damage = 10,
		area = 1,
		speed = 1,
		amount = 1,
		duration = 2,
		cooldown = 4.5,
		knockback = 0,
		poolLimit = 20,
		projectileInterval = 0.3,
		hitboxDelay = 0.5,
	},
	lightning_ring = {
		damage = 15,
		area = 1,
		speed = 1,
		amount = 2,
		cooldown = 4.5,
		poolLimit = 50,
		projectileInterval = 0.05,
	},
	cross = { damage = 5, area = 1, speed = 1, amount = 1, cooldown = 2, poolLimit = 100, projectileInterval = 0.1 },
}

-- weapons.md per-weapon "Lv | Change" tables, Lv2..Lv8, as deltas.
type Delta = { [string]: number }
local LEVELS: { [string]: { Delta } } = {
	-- L55-62
	whip = {
		{ amount = 1 },
		{ damage = 5 },
		{ damage = 5, area = 0.1 },
		{ damage = 5 },
		{ damage = 5, area = 0.1 },
		{ damage = 5 },
		{ damage = 5 },
	},
	-- L76-83
	magic_wand = {
		{ amount = 1 },
		{ cooldown = -0.2 },
		{ amount = 1 },
		{ damage = 10 },
		{ amount = 1 },
		{ pierce = 1 },
		{ damage = 10 },
	},
	-- L97-104
	knife = {
		{ amount = 1 },
		{ damage = 5, amount = 1 },
		{ amount = 1, projectileInterval = -0.02 },
		{ pierce = 1 },
		{ amount = 1, projectileInterval = -0.02 },
		{ damage = 5, amount = 1 },
		{ pierce = 1, projectileInterval = -0.02 },
	},
	-- L118-125
	axe = {
		{ amount = 1 },
		{ damage = 20 },
		{ pierce = 2 },
		{ amount = 1 },
		{ damage = 20 },
		{ pierce = 2 },
		{ damage = 20 },
	},
	-- L139-146
	runetracer = {
		{ damage = 5, speed = 0.2 },
		{ damage = 5, duration = 0.25 },
		{ amount = 1 },
		{ damage = 5, speed = 0.2 },
		{ damage = 5, duration = 0.25 },
		{ amount = 1 },
		{ duration = 0.5 },
	},
	-- L160-167
	fire_wand = {
		{ damage = 10 },
		{ damage = 10, speed = 0.2 },
		{ damage = 10 },
		{ damage = 10, speed = 0.2 },
		{ damage = 10 },
		{ damage = 10, speed = 0.2 },
		{ damage = 10 },
	},
	-- L183-190
	king_bible = {
		{ amount = 1 },
		{ area = 0.25, speed = 0.3 },
		{ damage = 10, duration = 0.5 },
		{ amount = 1 },
		{ area = 0.25, speed = 0.3 },
		{ damage = 10, duration = 0.5 },
		{ amount = 1 },
	},
	-- L204-211
	garlic = {
		{ damage = 2, area = 0.4 },
		{ damage = 1, cooldown = -0.1 },
		{ damage = 1, area = 0.2 },
		{ damage = 2, cooldown = -0.1 },
		{ damage = 1, area = 0.2 },
		{ damage = 1, cooldown = -0.1 },
		{ damage = 2, area = 0.2 },
	},
	-- L225-232 (conflict: shipped +0.5/+0.25/+0.25 duration is authoritative)
	santa_water = {
		{ area = 0.2, amount = 1 },
		{ damage = 10, duration = 0.5 },
		{ area = 0.2, amount = 1 },
		{ damage = 10, duration = 0.25 },
		{ area = 0.2, amount = 1 },
		{ damage = 5, duration = 0.25 },
		{ damage = 5, area = 0.2 },
	},
	-- L246-253
	lightning_ring = {
		{ amount = 1 },
		{ damage = 10, area = 1 },
		{ amount = 1 },
		{ damage = 20, area = 1 },
		{ amount = 1 },
		{ damage = 20, area = 1 },
		{ amount = 1 },
	},
	-- L266-274
	cross = {
		{ damage = 10 },
		{ area = 0.1, speed = 0.25 },
		{ amount = 1 },
		{ damage = 10 },
		{ area = 0.1, speed = 0.25 },
		{ amount = 1 },
		{ damage = 10 },
	},
}

-- Absent fields resolve to the engine default named in Tuning.defaults.
local DEFAULT_KEY: { [string]: string } = {
	duration = "weaponDuration",
	pierce = "weaponPierce",
	knockback = "weaponKnockback",
	hitboxDelay = "weaponHitboxDelay",
	critChance = "weaponCritChance",
	critMultiplier = "weaponCritMultiplier",
}
local FIELDS = {
	"damage",
	"area",
	"speed",
	"amount",
	"duration",
	"cooldown",
	"pierce",
	"knockback",
	"poolLimit",
	"projectileInterval",
	"hitboxDelay",
	"critChance",
	"critMultiplier",
}

local function expectedAt(id: string, level: number): { [string]: number }
	local row = BASE[id] :: any
	local out: { [string]: number } = {}
	for _, f in FIELDS do
		local v = row[f]
		if v == nil then
			v = (Tuning.defaults :: any)[DEFAULT_KEY[f]]
		end
		out[f] = v
	end
	for lv = 2, level do
		for f, d in LEVELS[id][lv - 1] do
			out[f] += d
		end
	end
	return out
end

T.test("WL-01 weapons.md L29-39: statsAt(id, 1) equals the base row for all 11 weapons", function()
	for _, id in IDS do
		local s = WeaponLevels.statsAt(id, 1) :: any
		local exp = expectedAt(id, 1)
		for _, f in FIELDS do
			T.eq(s[f], exp[f], id .. " Lv1 " .. f)
		end
	end
end)

T.test("WL-01 weapons.md L19: statsAt(id, 1) matches the Data record (baseDamage = rawPower x 10)", function()
	for _, id in IDS do
		local s = WeaponLevels.statsAt(id, 1)
		local rec = (Weapons.data :: any)[id]
		T.eq(s.damage, rec.baseDamage, id .. " damage")
		T.eq(s.damage, rec.rawPower * Weapons.displayScale, id .. " display scale")
		T.eq(s.cooldown, rec.cooldown, id .. " cooldown")
		T.eq(s.poolLimit, rec.poolLimit, id .. " poolLimit")
		T.eq(s.projectileInterval, rec.projectileInterval, id .. " projectileInterval")
		T.eq(s.amount, rec.amount, id .. " amount")
		T.eq(s.area, rec.area, id .. " area")
		T.eq(s.speed, rec.speed, id .. " speed")
	end
end)

T.test("WL-01 weapons.md L41 + Tuning.defaults: UNKNOWN fields take the engine default, never 0", function()
	T.eq(WeaponLevels.statsAt("whip", 1).pierce, Tuning.defaults.weaponPierce, "whip pierce")
	T.eq(WeaponLevels.statsAt("magic_wand", 1).critChance, Tuning.defaults.weaponCritChance, "wand critChance")
	T.eq(
		WeaponLevels.statsAt("magic_wand", 1).critMultiplier,
		Tuning.defaults.weaponCritMultiplier,
		"wand critMultiplier"
	)
	T.eq(WeaponLevels.statsAt("whip", 1).duration, Tuning.defaults.weaponDuration, "whip duration")
	T.eq(WeaponLevels.statsAt("whip", 1).knockback, Tuning.defaults.weaponKnockback, "whip knockback")
	T.eq(WeaponLevels.statsAt("whip", 1).hitboxDelay, Tuning.defaults.weaponHitboxDelay, "whip hitboxDelay")
	T.eq(WeaponLevels.statsAt("knife", 1).knockback, 0.5, "knife knockback L31")
	T.eq(WeaponLevels.statsAt("garlic", 1).knockback, 0, "garlic knockback L36 (real zero)")
	T.eq(WeaponLevels.statsAt("santa_water", 1).knockback, 0, "santa water knockback L37")
end)

T.test("WL-01 weapons.md L29-38 + conflicts L284-286: innate crits Whip 0.2/2, Axe 0.3/2, Knife 0.3/3", function()
	T.eq(WeaponLevels.statsAt("whip", 1).critChance, 0.2, "whip chance")
	T.eq(WeaponLevels.statsAt("whip", 1).critMultiplier, 2, "whip mult")
	T.eq(WeaponLevels.statsAt("axe", 1).critChance, 0.3, "axe chance")
	T.eq(WeaponLevels.statsAt("axe", 1).critMultiplier, 2, "axe mult")
	T.eq(WeaponLevels.statsAt("knife", 1).critChance, 0.3, "knife chance")
	T.eq(WeaponLevels.statsAt("knife", 1).critMultiplier, 3, "knife mult")
end)

T.test("WL-02 weapons.md per-weapon tables: every level 1-8 of all 11 weapons folds to the .md deltas", function()
	for _, id in IDS do
		for level = 1, 8 do
			local s = WeaponLevels.statsAt(id, level) :: any
			local exp = expectedAt(id, level)
			for _, f in FIELDS do
				T.eq(s[f], exp[f], id .. " Lv" .. level .. " " .. f)
			end
		end
	end
end)

T.test("WL-02 weapons.md 'Max-level totals': Lv8 equals base + quoted totals", function()
	local whip = WeaponLevels.statsAt("whip", 8) -- L51
	T.eq(whip.damage, 40, "whip dmg")
	T.eq(whip.area, 1.2, "whip area")
	T.eq(whip.amount, 2, "whip amount")
	local wand = WeaponLevels.statsAt("magic_wand", 8) -- L72
	T.eq(wand.damage, 30, "wand dmg")
	T.eq(wand.amount, 4, "wand amount")
	T.eq(wand.cooldown, 1.0, "wand cooldown")
	T.eq(wand.pierce, 2, "wand pierce")
	local knife = WeaponLevels.statsAt("knife", 8) -- L93
	T.eq(knife.damage, 16.5, "knife dmg")
	T.eq(knife.amount, 6, "knife amount")
	T.eq(knife.pierce, 3, "knife pierce")
	T.eq(knife.projectileInterval, 0.04, "knife interval")
	local axe = WeaponLevels.statsAt("axe", 8) -- L114
	T.eq(axe.damage, 80, "axe dmg")
	T.eq(axe.amount, 3, "axe amount")
	T.eq(axe.pierce, 7, "axe pierce")
	local rune = WeaponLevels.statsAt("runetracer", 8) -- L135
	T.eq(rune.damage, 30, "rune dmg")
	T.eq(rune.speed, 1.4, "rune speed")
	T.eq(rune.duration, 3.25, "rune duration")
	T.eq(rune.amount, 3, "rune amount")
	local fire = WeaponLevels.statsAt("fire_wand", 8) -- L156
	T.eq(fire.damage, 90, "fire dmg")
	T.eq(fire.speed, 1.35, "fire speed")
	T.eq(fire.amount, 3, "fire amount (conflict L281: base 3)")
	local bible = WeaponLevels.statsAt("king_bible", 8) -- L179
	T.eq(bible.damage, 30, "bible dmg")
	T.eq(bible.area, 1.5, "bible area")
	T.eq(bible.speed, 1.6, "bible speed")
	T.eq(bible.duration, 4, "bible duration")
	T.eq(bible.amount, 4, "bible amount")
	local garlic = WeaponLevels.statsAt("garlic", 8) -- L200
	T.eq(garlic.damage, 15, "garlic dmg")
	T.eq(garlic.area, 2.0, "garlic area")
	T.eq(garlic.cooldown, 1.0, "garlic cooldown")
	local water = WeaponLevels.statsAt("santa_water", 8) -- L221
	T.eq(water.damage, 40, "water dmg")
	T.eq(water.area, 1.8, "water area")
	T.eq(water.amount, 4, "water amount")
	T.eq(water.duration, 3, "water duration")
	T.eq(water.cooldown, 4.5, "water cooldown (conflict L280: 4.5 s)")
	local ring = WeaponLevels.statsAt("lightning_ring", 8) -- L242
	T.eq(ring.damage, 65, "ring dmg")
	T.eq(ring.area, 4, "ring area")
	T.eq(ring.amount, 6, "ring amount")
	local cross = WeaponLevels.statsAt("cross", 8) -- L263
	T.eq(cross.damage, 35, "cross dmg")
	T.eq(cross.area, 1.2, "cross area")
	T.eq(cross.speed, 1.5, "cross speed")
	T.eq(cross.amount, 3, "cross amount")
end)

T.test("WL-02 weapons.md L227/L229 and L100: intermediate levels", function()
	T.eq(WeaponLevels.statsAt("santa_water", 3).duration, 2.5, "water Lv3 duration")
	T.eq(WeaponLevels.statsAt("santa_water", 5).duration, 2.75, "water Lv5 duration")
	T.eq(WeaponLevels.statsAt("knife", 4).projectileInterval, 0.08, "knife Lv4 interval")
	T.eq(WeaponLevels.statsAt("magic_wand", 3).cooldown, 1.0, "wand Lv3 cooldown L78")
	T.eq(WeaponLevels.statsAt("magic_wand", 6).pierce, 1, "wand Lv6 pierce")
	T.eq(WeaponLevels.statsAt("magic_wand", 7).pierce, 2, "wand Lv7 pierce L82")
end)

T.test("WL-02 statsAt returns a fresh table (folding never mutates Data)", function()
	local a = WeaponLevels.statsAt("whip", 8)
	local b = WeaponLevels.statsAt("whip", 8)
	T.truthy(a ~= b, "distinct tables")
	T.eq(Weapons.data.whip.baseDamage, 10, "Data untouched")
end)

T.test("WL-03 core_loop.md L208 / passives_evolutions.md L102: maxLevel 8 for all 11 base weapons", function()
	for _, id in IDS do
		T.eq(WeaponLevels.maxLevel(id), 8, id)
		T.eq(WeaponLevels.maxLevel(id), (Weapons.data :: any)[id].maxLevel, id .. " vs Data")
	end
end)

T.test("WL-03 statsAt errors for level < 1, level > maxLevel, unknown id", function()
	T.throws(function()
		WeaponLevels.statsAt("whip", 0)
	end, "level 0")
	T.throws(function()
		WeaponLevels.statsAt("whip", 9)
	end, "level 9")
	T.throws(function()
		WeaponLevels.statsAt("sword", 1)
	end, "unknown id")
	T.throws(function()
		WeaponLevels.maxLevel("sword")
	end, "maxLevel unknown id")
end)

-- SCHEMA.md L321: multiplier stats multiply; characters.md L257: amount is flat.
T.test("WL-04 SCHEMA.md L321 / characters.md L256-257: effective() applies the StatBlock per convention", function()
	local knife = WeaponLevels.effective(WeaponLevels.statsAt("knife", 8), F.baseStats({ amount = 3 }))
	T.eq(knife.amount, 9, "knife Lv8 (6) + Gennaro 1 + Duplicator 2 = 9")
	local whip = WeaponLevels.effective(WeaponLevels.statsAt("whip", 1), F.baseStats({ might = 1.5 }))
	T.eq(whip.damage, 15, "whip 10 x might 1.5")
	local wand = WeaponLevels.effective(WeaponLevels.statsAt("magic_wand", 1), F.baseStats({ cooldown = 0.6 }))
	T.eq(wand.cooldown, 0.72, "wand 1.2 x cooldown 0.6")
	local portaWhip = WeaponLevels.effective(WeaponLevels.statsAt("whip", 1), F.baseStats({ cooldown = 0.1 }))
	T.eq(portaWhip.cooldown, 0.135, "whip 1.35 x Porta 0.1")
	local water = WeaponLevels.effective(WeaponLevels.statsAt("santa_water", 1), F.baseStats({ duration = 1.5 }))
	T.eq(water.duration, 3, "water 2 x duration 1.5")
	local bible = WeaponLevels.effective(WeaponLevels.statsAt("king_bible", 1), F.baseStats({ area = 1.3 }))
	T.eq(bible.area, 1.3, "bible 1 x area 1.3")
end)

T.test("WL-04 effective() leaves pierce/knockback/pool/interval/hitboxDelay/crit unchanged", function()
	local player = F.baseStats({ might = 2, area = 2, speed = 2, duration = 2, cooldown = 0.5, amount = 2 })
	local base = WeaponLevels.statsAt("knife", 8)
	local e = WeaponLevels.effective(base, player)
	T.eq(e.pierce, base.pierce, "pierce")
	T.eq(e.knockback, base.knockback, "knockback")
	T.eq(e.poolLimit, base.poolLimit, "poolLimit")
	T.eq(e.projectileInterval, base.projectileInterval, "projectileInterval")
	T.eq(e.hitboxDelay, base.hitboxDelay, "hitboxDelay")
	T.eq(e.critChance, base.critChance, "critChance")
	T.eq(e.critMultiplier, base.critMultiplier, "critMultiplier")
	T.eq(e.damage, 33, "damage 16.5 x 2")
	T.eq(e.amount, 8, "amount 6 + 2")
end)

T.test("WL-04 amount is an integer >= 1 and effective() does not mutate its input", function()
	local base = WeaponLevels.statsAt("whip", 1)
	local e = WeaponLevels.effective(base, F.baseStats({ amount = 2, might = 3 }))
	T.eq(e.amount, 3, "amount")
	T.eq(e.amount, math.floor(e.amount), "integer")
	T.eq(base.damage, 10, "base damage untouched")
	T.eq(base.amount, 1, "base amount untouched")
	local zero = WeaponLevels.effective(WeaponLevels.statsAt("whip", 1), F.baseStats({ amount = -5 }))
	T.truthy(zero.amount >= 1, "amount never below 1")
end)

-- weapons.md shipped tips: Whip L49, Garlic L198, Santa Water L219,
-- Lightning Ring L240, Magic Wand L70, Knife L91, Axe L112, Fire Wand L154, Cross L261.
T.test("WL-05 weapons.md L198: Garlic ignores Amount, Duration, Speed", function()
	local g = WeaponLevels.effective(
		WeaponLevels.statsAt("garlic", 1),
		F.baseStats({ amount = 3, speed = 1.5, duration = 2 })
	)
	T.eq(g.amount, 1, "amount ignored")
	T.eq(g.speed, 1, "speed ignored")
	T.eq(g.duration, 1.3, "duration ignored")
	local g2 = WeaponLevels.effective(
		WeaponLevels.statsAt("garlic", 1),
		F.baseStats({ area = 1.5, might = 2, cooldown = 0.5 })
	)
	T.eq(g2.area, 1.5, "area still applies")
	T.eq(g2.damage, 10, "might still applies")
	T.eq(g2.cooldown, 0.65, "cooldown still applies")
end)

T.test("WL-05 weapons.md L49: Whip ignores Speed and Duration", function()
	local w = WeaponLevels.effective(WeaponLevels.statsAt("whip", 1), F.baseStats({ speed = 1.5, duration = 1.5 }))
	T.eq(w.speed, 1, "speed ignored")
	T.eq(w.duration, WeaponLevels.statsAt("whip", 1).duration, "duration ignored")
end)

T.test("WL-05 weapons.md L240: Lightning Ring ignores Speed and Duration", function()
	local r =
		WeaponLevels.effective(WeaponLevels.statsAt("lightning_ring", 1), F.baseStats({ speed = 1.5, duration = 1.5 }))
	T.eq(r.speed, 1, "speed ignored")
	T.eq(r.duration, WeaponLevels.statsAt("lightning_ring", 1).duration, "duration ignored")
end)

T.test("WL-05 weapons.md L219: Santa Water ignores Speed only", function()
	local s = WeaponLevels.effective(
		WeaponLevels.statsAt("santa_water", 1),
		F.baseStats({ speed = 1.5, duration = 1.5, amount = 2 })
	)
	T.eq(s.speed, 1, "speed ignored")
	T.eq(s.duration, 3, "duration applies")
	T.eq(s.amount, 3, "amount applies")
end)

T.test("WL-05 weapons.md L70/L91/L112/L154/L261: Wand/Knife/Axe/Fire Wand/Cross ignore Duration only", function()
	for _, id in { "magic_wand", "knife", "axe", "fire_wand", "cross" } do
		local base = WeaponLevels.statsAt(id, 1)
		local e = WeaponLevels.effective(base, F.baseStats({ duration = 1.5, speed = 1.5 }))
		T.eq(e.duration, base.duration, id .. " duration ignored")
		T.eq(e.speed, base.speed * 1.5, id .. " speed applies")
	end
end)

T.test("WL-05 weapons.md L175: King Bible ignores nothing (Best with Speed, Duration, Area)", function()
	local b = WeaponLevels.effective(
		WeaponLevels.statsAt("king_bible", 1),
		F.baseStats({ speed = 1.5, duration = 1.5, area = 1.5 })
	)
	T.eq(b.speed, 1.5, "speed applies")
	T.eq(b.duration, 4.5, "duration applies")
	T.eq(b.area, 1.5, "area applies")
end)

T.test("WL-05 weapons.md L133: Runetracer ignores nothing (Best with Speed, Duration)", function()
	local r = WeaponLevels.effective(WeaponLevels.statsAt("runetracer", 1), F.baseStats({ speed = 1.5, duration = 2 }))
	T.eq(r.speed, 1.5, "speed applies")
	T.eq(r.duration, 4.5, "duration applies")
end)

return T.finish()
