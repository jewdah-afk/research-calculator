--!nonstrict
-- Stacked prestige layers (Ascension, Transcension, ... add more by appending to LAYERS).
--
-- Each layer works like a TIER:
--   * one prestige = +1 point (times magnifiers from the layer above)
--   * the requirement climbs with every prestige:  need * growth ^ count
--       Ascension: 250 x 1.1^n rebirths   Transcension: 45 x 1.25^n lifetime AP
--   * PASSIVE per lifetime point magnifies the layer below:
--       Ascension:     rebirths per rebirth click = 1 + 0.1 * lifetimeAP (+ echo)
--       Transcension:  AP per ascension           = 1 + 0.25 * lifetimeTrP
--     (lifetime points, so spending in the shop never weakens the passive)
--   * SHOP: the first levels cost 1 point, then each line scales differently
--       scale = "exp"  cost * growth ^ lv        (gets steep)
--       scale = "lin"  cost + step * lv          (stays affordable)
--       scale = "soft" cost * (1 + lv) ^ growth  (polynomial, in between)
--   * RESETS a configurable set of lower progress
--
-- Effects are summed once per change and cached (see effects()), so the economy
-- can read them every frame for free no matter how many shop items exist.

local Big = require(script.Parent.Big)
local Runes = require(script.Parent.Runes)

local Prestige = {}

Prestige.LAYERS = {
	{
		id = "ascension",
		name = "Ascension",
		point = "AP",
		source = "rebirths",
		need = 250,
		growth = 1.1, -- requirement x1.1 per ascension, like a tier (250, 275, 303, 333, ...)
		perPoint = 0.1, -- +0.1x rebirths per click, per lifetime AP
		passiveTarget = "rebirthGain",
		resets = { run = true, rebirths = true, gems = true, tiers = false },
		shop = {
			-- the opener: 1 AP and you rebuild the run several times faster
			{ id = "AS-MOMENTUM", name = "Momentum", desc = "x5 cash, x3 luck per level", cost = 1, scale = "soft", growth = 1.5, cashLog = math.log10(5), luckLog = math.log10(3) },
			-- two more that start at 1 AP but scale differently
			{ id = "AS-LUCK", name = "Ascended Luck", desc = "x2 luck per level", cost = 1, scale = "lin", step = 1, luckLog = math.log10(2) },
			{ id = "AS-CASH", name = "Ascended Cash", desc = "x10 cash per level", cost = 1, scale = "exp", growth = 2, cashLog = 1 },
			{ id = "AS-ECHO", name = "Rebirth Echo", desc = "+0.1x rebirths per click per level", cost = 2, scale = "exp", growth = 2, rebirthGain = 0.1 },
			{ id = "AS-START", name = "Head Start", desc = "Start every run with 3 spawners", cost = 2, max = 1, startSpawners = 3 },
			{ id = "AS-GEMS", name = "Gem Vein", desc = "x2 gems per level", cost = 2, scale = "lin", step = 2, gemLog = math.log10(2) },
			{ id = "AS-MEMORY", name = "Rebirth Memory", desc = "Keep 5% of rebirths when you ascend", cost = 3, scale = "exp", growth = 2, max = 5, keepRebirths = 0.05 },
		},
	},
	{
		id = "transcension",
		name = "Transcension",
		point = "TrP",
		source = "ascensionLifetime", -- lifetime AP earned
		-- ~45 AP at x1.1 costs about as many rebirths as the old 10 AP at x1.6 did
		need = 45,
		growth = 1.25, -- requirement x1.25 lifetime AP per transcension
		perPoint = 0.25, -- +0.25x AP per ascension, per lifetime TrP
		passiveTarget = "ascensionGain",
		resets = { run = true, rebirths = true, gems = true, tiers = true, ascension = true },
		shop = {
			{ id = "TR-SURGE", name = "AP Surge", desc = "x2 AP per ascension per level", cost = 1, scale = "exp", growth = 3, apMult = 2 },
			{ id = "TR-LUCK", name = "Eternal Luck", desc = "x10 luck per level", cost = 1, scale = "lin", step = 1, luckLog = 1 },
			{ id = "TR-CASH", name = "Eternal Cash", desc = "x100 cash per level", cost = 1, scale = "exp", growth = 2, cashLog = 2 },
		},
	},
}

local byId = {}
for i, L in Prestige.LAYERS do
	L.index = i
	byId[L.id] = L
	for _, u in L.shop do
		u.layer = L.id
	end
end
Prestige.byId = byId

function Prestige.newState()
	local s = {}
	for _, L in Prestige.LAYERS do
		s[L.id] = { points = 0, lifetime = 0, count = 0, shop = {} }
	end
	return s
end

-- make sure saves pick up layers/shop items added later
function Prestige.ensure(data)
	data.prestige = data.prestige or Prestige.newState()
	for _, L in Prestige.LAYERS do
		local st = data.prestige[L.id] or {}
		st.points = st.points or 0
		st.lifetime = st.lifetime or 0
		st.count = st.count or 0
		st.shop = st.shop or {}
		data.prestige[L.id] = st
	end
end

local function level(data, layerId, upgradeId)
	local st = data.prestige and data.prestige[layerId]
	return st and st.shop[upgradeId] or 0
end
Prestige.level = level

---------------------------------------------------------------- cached effects

local FIELDS = { "luckLog", "cashLog", "gemLog", "rebirthGain", "keepRebirths" }
local cache = setmetatable({}, { __mode = "k" }) -- [data] = { key, effects }

-- cheap fingerprint of everything effects depend on (levels + lifetime points)
local function keyOf(data)
	local parts = {}
	for _, L in Prestige.LAYERS do
		local st = data.prestige[L.id]
		table.insert(parts, st.lifetime)
		for _, u in L.shop do
			table.insert(parts, st.shop[u.id] or 0)
		end
	end
	return table.concat(parts, ",")
end

local EMPTY = { luckLog = 0, cashLog = 0, gemLog = 0, rebirthGain = 0, keepRebirths = 0, startSpawners = 1, apMult = 1 }

function Prestige.effects(data)
	if not data.prestige then
		return EMPTY
	end
	local key = keyOf(data)
	local c = cache[data]
	if c and c.key == key then
		return c.fx
	end
	local fx = { startSpawners = 1, apMult = 1 }
	for _, f in FIELDS do
		fx[f] = 0
	end
	for _, L in Prestige.LAYERS do
		for _, u in L.shop do
			local lv = level(data, L.id, u.id)
			if lv > 0 then
				for _, f in FIELDS do
					if u[f] then
						fx[f] += lv * u[f]
					end
				end
				if u.startSpawners then
					fx.startSpawners = math.max(fx.startSpawners, u.startSpawners)
				end
				if u.apMult then
					fx.apMult *= u.apMult ^ lv
				end
			end
		end
	end
	cache[data] = { key = key, fx = fx }
	return fx
end

---------------------------------------------------------------- effects used by the economy

-- rebirths granted per rebirth click (before bulk): 1 + 0.1*lifetimeAP + echo levels
function Prestige.rebirthGainMult(data): number
	if not data.prestige then
		return 1
	end
	return 1 + byId.ascension.perPoint * data.prestige.ascension.lifetime + Prestige.effects(data).rebirthGain
end

-- core luck/cash/gem log10 added by prestige shops
function Prestige.luckLog(data): number
	return Prestige.effects(data).luckLog
end
function Prestige.cashLog(data): number
	return Prestige.effects(data).cashLog
end
function Prestige.gemLog(data): number
	return Prestige.effects(data).gemLog
end
function Prestige.startSpawners(data): number
	return Prestige.effects(data).startSpawners
end
function Prestige.keepRebirths(data): number
	return math.min(Prestige.effects(data).keepRebirths, 0.5)
end

---------------------------------------------------------------- point gain

local function sourceValue(data, L): number
	if L.source == "rebirths" then
		return data.rebirths
	elseif L.source == "ascensionLifetime" then
		return data.prestige.ascension.lifetime
	end
	return 0
end

local function gainMult(data, L): number
	local m = 1
	-- the layer above magnifies this layer's gain
	local above = Prestige.LAYERS[L.index + 1]
	if above then
		m *= 1 + above.perPoint * data.prestige[above.id].lifetime
	end
	if L.id == "ascension" then
		m *= Prestige.effects(data).apMult
	end
	return m
end

-- resource needed for this layer's next prestige (climbs like a tier)
function Prestige.requirement(data, layerId: string): number
	Prestige.ensure(data)
	local L = byId[layerId]
	return math.floor(L.need * L.growth ^ data.prestige[layerId].count + 0.5)
end

-- rune stat that boosts each layer's points (Halo/Crown -> AP, Eternity -> TrP)
local RUNE_STAT = { ascension = "ap", transcension = "trp" }

local function rawGain(data, L): number
	local stat = RUNE_STAT[L.id]
	local m = gainMult(data, L)
	if stat and data.runes then
		m = m * (1 + Runes.totals(data)[stat]) + (data.runes.carry[stat] or 0)
	end
	return m
end

-- points you'd get by prestiging this layer right now (1 x magnifiers, or 0)
function Prestige.pending(data, layerId: string): number
	Prestige.ensure(data)
	local L = byId[layerId]
	if sourceValue(data, L) < Prestige.requirement(data, layerId) then
		return 0
	end
	return math.max(1, math.floor(rawGain(data, L) + 1e-9))
end

-- after a prestige: keep the leftover fraction of rune-boosted points for next time
function Prestige.consumeCarry(data, layerId: string, pts: number)
	local stat = RUNE_STAT[layerId]
	if stat and data.runes then
		data.runes.carry[stat] = math.max(0, rawGain(data, byId[layerId]) - pts)
	end
end

---------------------------------------------------------------- shop

function Prestige.cost(data, upgradeId: string): number?
	for _, L in Prestige.LAYERS do
		for _, u in L.shop do
			if u.id == upgradeId then
				local lv = level(data, L.id, u.id)
				if u.max and lv >= u.max then
					return nil
				end
				local c = u.cost
				if u.scale == "lin" then
					c = u.cost + (u.step or 1) * lv
				elseif u.scale == "soft" then
					c = u.cost * (1 + lv) ^ (u.growth or 1)
				elseif u.scale == "exp" then
					c = u.cost * (u.growth or 2) ^ lv
				end
				return math.floor(c + 0.5), L, u
			end
		end
	end
	return nil
end

function Prestige.buy(data, upgradeId: string): boolean
	Prestige.ensure(data)
	local cost, L, u = Prestige.cost(data, upgradeId)
	if not cost then
		return false
	end
	local st = data.prestige[L.id]
	if st.points < cost then
		return false
	end
	st.points -= cost
	st.shop[u.id] = (st.shop[u.id] or 0) + 1
	return true
end

Prestige._Big = Big
return Prestige
