--!nonstrict
-- Birb core formulas, ported 1:1 from the birbplay.com build (see CORE_FORMULAS.md).
-- `s` is a state table: s.upgrades[id] = level, s.owned[id] = true for one-time
-- (sunflower/desert/archivist) nodes, plus resource fields used below.
-- Upgrade definitions (baseCost, costMultiplier, maxLevel, tree, ...) live in upgrades.json.

local F = {}

local function has(s, id: string): boolean
	return s.owned ~= nil and s.owned[id] == true
end

-- Starting level: p_/pr_/s_/m_ start at 1 (p_auric_silo only once Auric Blueprints is owned), others 0.
function F.level(s, id: string): number
	local v = s.upgrades and s.upgrades[id]
	if v ~= nil then return v end
	local prefixed = id:sub(1, 2) == "p_" or id:sub(1, 3) == "pr_" or id:sub(1, 2) == "s_" or id:sub(1, 2) == "m_"
	if prefixed and (id ~= "p_auric_silo" or has(s, "d_desert_auric_blueprints")) then return 1 end
	return 0
end

-- Cost of buying the next level, charged at the CURRENT level L. `def` is a row of upgrades.json.
function F.cost(def, L: number): number
	local id = def.id
	if id == "p_echo_value" then
		local t = math.clamp(math.floor(L), 1, 999)
		return math.floor(10 * 1.35 ^ math.min(24, t - 1) * 1.114 ^ math.min(75, math.max(0, t - 25)) * 1.14 ^ math.max(0, t - 100))
	end
	if id == "m_rupture" then return math.ceil(2e6 * 2.7 ^ (L - 1)) end
	if id == "m_charged_strike" then return 4800 * 24 ^ (L - 1) end
	if def.growth ~= nil and def.cost ~= nil then -- leveled sunflower/desert nodes
		local a = math.max(0, math.floor(L))
		local r = if id == "d_mine_abyssal_forge" then 3 ^ math.min(200, a) * 2.85 ^ math.max(0, a - 200) else def.growth ^ a
		return math.ceil(def.cost * r)
	end
	if id == "p_value" then
		return if L < 5 then L else math.floor(4 * 1.3312 ^ (L - 4))
	end
	local base = def.baseCost or def.cost or 0
	local mult = def.costMultiplier or 1
	local t = def.tree
	if t == "P" or t == "PR" or t == "S" or t == "M" then
		return math.floor(base * mult ^ math.max(0, L - (def.initialLevel or 1)))
	end
	return math.floor(base * mult ^ L)
end

-- Final price after discounts (Auric Bargain on golden popcorn costs).
function F.discountedCost(s, def, L: number): number
	local c = F.cost(def, L)
	if c > 0 and def.costCurrency == "goldenPopcorn" and has(s, "d_desert_auric_bargain") then
		return math.max(1, math.floor(0.75 * c))
	end
	return c
end

-- Upgrade effects (level -> value)
function F.popcornValue(L: number) return L end
function F.spawnTime(L: number) return math.max(0.2, 2.6 - 0.2 * L) end
function F.capacity(L: number) return 2 * L end
function F.wingSpeed(L: number) return 1 + math.max(0, L - 1) / 19 end
function F.popcornMult(L: number) return 2 ^ (L - 1) end
function F.goldenPopcornMult(L: number) return 2 ^ math.max(0, L - 1) end
function F.radiusMult(L: number) return 1 + 0.2 * L end
function F.respawnMult(L: number) return 1 + 0.5 * math.max(0, L - 1) end
function F.morePopcorn(L: number) return 1 + 0.2 * math.max(0, L - 1) end
function F.moreFeathers(L: number) return 1 + 0.2 * math.max(0, L - 1) end
function F.moreSeeds(L: number) return L end

function F.maxLevel(s, def): number
	local n = def.maxLevel or 1
	if def.id == "pr_popcorn_mult" and has(s, "d_pop_max_lvl") then n += 2 end
	if def.id == "p_move_speed" and has(s, "d_wing_mastery_plus") then n += 10 end
	if def.id == "p_capacity" and has(s, "d_silo_mastery_plus") then n += 10 end
	return n
end

-- Spawning ------------------------------------------------------------------
function F.spawnInterval(s, inDesert: boolean): number
	local t = F.spawnTime(F.level(s, "p_speed")) / F.respawnMult(F.level(s, "pr_respawn_mult"))
	if has(s, "d_quantum_corn") then t /= 1.2 end
	local sparrow = math.min(10, 1 + math.sqrt(math.max(0, s.sparrowRebirbs or 0)) * 1.5)
	local dave = 1
	if inDesert then
		local d = math.floor(math.clamp(s.daveRebirbs or 0, 0, 100))
		dave = math.min(10, 1 + math.sqrt(d) * (9 / math.sqrt(100)))
	end
	return t / math.max(sparrow, dave)
end

function F.maxCapacity(s): number
	local base = F.capacity(F.level(s, "p_capacity"))
	if has(s, "d_desert_auric_blueprints") then base += 2 * F.level(s, "p_auric_silo") end
	local m = if has(s, "d_popcorn_cap") then 2 else 1
	if has(s, "d_void_silo") then m *= 1.1 end
	return math.floor(base * m)
end

F.PopcornTypes = {
	{ id = "plain",   value = 1,   weight = 100 },
	{ id = "butter",  value = 2,   weight = 20 },
	{ id = "caramel", value = 10,  weight = 5 },
	{ id = "cheese",  value = 25,  weight = 1 },
	{ id = "rainbow", value = 100, weight = 0.1 },
	{ id = "red",     value = 100, weight = 0.01 },
	{ id = "golden",  value = 1,   weight = 0 },
}

function F.desertGoldenChance(s): number
	if s.sandstormActive then return 1 end
	if not has(s, "d_desert_core_mockup") then return 0 end
	local p = 0.05
	for _, id in { "d_desert_golden_popcorn_chance", "d_desert_golden_popcorn_chance_2", "d_desert_golden_popcorn_chance_3",
		"d_desert_golden_popcorn_chance_4", "d_desert_golden_popcorn_chance_5" } do
		if has(s, id) then p += 0.025 end
	end
	return p
end

function F.rollType(s, inDesert: boolean, rng: Random): string
	if inDesert then
		return if rng:NextNumber() < F.desertGoldenChance(s) then "golden" else "plain"
	end
	local weights, total = {}, 0
	for _, t in F.PopcornTypes do
		local w = t.weight
		if t.id == "cheese" and has(s, "d_cheese_powder") then w *= 1.5 end
		if t.id == "rainbow" then
			w += F.level(s, "f_rainbow_chance")
			if has(s, "d_rainbow_aura") then w *= 2 end
		end
		if t.id == "butter" and has(s, "d_butter_bonanza") then w *= 1.5 end
		weights[t.id] = w
		total += w
	end
	local r = rng:NextNumber() * total
	for _, t in F.PopcornTypes do
		r -= weights[t.id]
		if r <= 0 then return t.id end
	end
	return "plain"
end

-- Value -----------------------------------------------------------------------
-- External factors default to 1 when absent: fishPopcornMult, grainSiloMultiplier,
-- sparrowDrainMultiplier, sacrificeMultiplier, questPopcornMultiplier, roomMultiplier.
function F.totalPopcornMultiplier(s): number
	local t = F.popcornValue(F.level(s, "p_value"))
		* F.popcornMult(F.level(s, "pr_popcorn_mult"))
		* F.morePopcorn(F.level(s, "s_more_popcorn"))
	if has(s, "d_butter_hose") then t *= 1.5 end
	if has(s, "d_kernel_polish") then t *= 2 end
	t *= s.fishPopcornMult or 1
	if (s.evolutionCount or 0) >= 2 then t *= s.evolutionCount end
	if has(s, "d_seed_synergy") then t *= 1 + 1.3 * math.log10(1 + (s.seeds or 0) / 5e4) end
	t *= math.max(1, s.grainSiloMultiplier or 1)
	if has(s, "d_trophy_bonus") then t *= 1 + 3 * math.log10(1 + (s.highestFishWeight or 0)) end
	t *= s.sparrowDrainMultiplier or 1
	if has(s, "d_golden_butter") then t *= 1 + 0.5 * math.log10((s.goldenFeathers or 0) + 1) end
	t *= s.sacrificeMultiplier or 1
	t *= s.questPopcornMultiplier or 1
	return t
end

function F.popcornGain(s, baseValue: number, inDesert: boolean): number
	local m = F.totalPopcornMultiplier(s) * (s.roomMultiplier or 1)
	if inDesert and has(s, "d_desert_fever") then m *= 5 end
	if has(s, "d_desert_popcorn_gain_x2") then m *= 2 end
	return baseValue * m
end

-- Rebirb ------------------------------------------------------------------------
local function A(x: number): number
	if x <= 0 then return 0 end
	local i = math.log10(x + 1) / 16
	return 6 * (if i <= 1 then i else 1 + math.log(1 + (i - 1)) / 10)
end
F.archivistCurve = A

function F.playtimeMultiplier(s): number
	if not has(s, "d_rebirth_playtime") then return 1 end
	return math.min(10, 1 + 0.01 * ((s.playTimeSeconds or 0) / 60))
end

function F.rebirbFeathers(s): number
	local base = math.floor((s.popcorn or 0) / 1000)
	local fl = F.level(s, "s_more_feathers")
	local featherEffect = if fl > 0 then F.moreFeathers(fl) else 1
	local a = F.playtimeMultiplier(s) + (featherEffect - 1)
	if has(s, "d_golden_harvest") then a *= 3 end
	if has(s, "d_desert_rebirb_golden_feathers") then a *= 2 end
	a *= 1 + (s.questFeatherBonus or 0)
	local evo = s.evolutionCount or 0
	local auric = if has(s, "d_archivist_auric_rebirb") then 1 + A(s.goldenPopcorn or 0) else 1
	local payout = (s.roomMultiplier or 1) * (s.fishFeatherMult or 1) * (if evo >= 2 then evo else 1) * auric
	return math.floor(base * a * payout)
end

return F
