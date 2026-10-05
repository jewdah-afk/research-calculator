--!nonstrict
-- Stacked prestige layers (Ascension, Transcension, ... add more by appending to LAYERS).
--
-- Each layer:
--   * earns POINTS from the layer below's resource:  floor( (resource / need) ^ exponent * gainMult )
--   * has a PASSIVE that magnifies the layer below:  +perPoint x per lifetime point earned
--       Ascension:     rebirths per rebirth click   = 1 + 0.25 * lifetimeAP
--       Transcension:  ascension points per ascend   = 1 + 0.25 * lifetimeTrP
--     (lifetime points, so spending in the shop never weakens the passive)
--   * has its own SHOP of upgrades bought with unspent points
--   * RESETS a configurable set of lower progress
--
-- All layer effects on luck/cash are CORE progression (applied in full, not bonus-budgeted):
-- prestige layers are the backbone of the late game, like rebirths and tiers.

local Big = require(script.Parent.Big)

local Prestige = {}

Prestige.LAYERS = {
	{
		id = "ascension",
		name = "Ascension",
		point = "AP",
		-- points from rebirths: floor((rebirths / need) ^ exponent)
		source = "rebirths",
		need = 250,
		exponent = 0.5,
		perPoint = 0.25, -- +0.25x rebirths per click, per lifetime AP
		passiveTarget = "rebirthGain",
		resets = { run = true, rebirths = true, gems = true, tiers = false },
		shop = {
			{ id = "AS-LUCK", name = "Ascended Luck", desc = "x2 luck per level", cost = 1, growth = 2, luckLog = math.log10(2) },
			{ id = "AS-CASH", name = "Ascended Cash", desc = "x3 cash per level", cost = 1, growth = 2, cashLog = math.log10(3) },
			{ id = "AS-ECHO", name = "Rebirth Echo", desc = "+0.1x rebirths per click per level", cost = 2, growth = 2.5, rebirthGain = 0.1 },
			{ id = "AS-START", name = "Head Start", desc = "Start every run with 3 spawners unlocked", cost = 3, growth = 1, max = 1, startSpawners = 3 },
			{ id = "AS-GEMS", name = "Gem Vein", desc = "x2 gems per level", cost = 2, growth = 2, gemLog = math.log10(2) },
		},
	},
	{
		id = "transcension",
		name = "Transcension",
		point = "TrP",
		source = "ascensionLifetime", -- lifetime AP earned
		need = 40,
		exponent = 0.5,
		perPoint = 0.25, -- +0.25x AP per ascension, per lifetime TrP
		passiveTarget = "ascensionGain",
		resets = { run = true, rebirths = true, gems = true, tiers = true, ascension = true },
		shop = {
			{ id = "TR-SURGE", name = "AP Surge", desc = "x2 AP per ascension per level", cost = 1, growth = 3, apMult = 2 },
			{ id = "TR-LUCK", name = "Eternal Luck", desc = "x10 luck per level", cost = 1, growth = 2, luckLog = 1 },
			{ id = "TR-CASH", name = "Eternal Cash", desc = "x10 cash per level", cost = 1, growth = 2, cashLog = 1 },
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

-- sum an effect field across all shops: sum(level * field)
local function shopSum(data, field)
	local total = 0
	for _, L in Prestige.LAYERS do
		for _, u in L.shop do
			if u[field] then
				total += level(data, L.id, u.id) * u[field]
			end
		end
	end
	return total
end

---------------------------------------------------------------- effects used by the economy

-- rebirths granted per rebirth click (before bulk): 1 + 0.25*lifetimeAP + echo levels
function Prestige.rebirthGainMult(data): number
	if not data.prestige then
		return 1
	end
	local asc = data.prestige.ascension
	return 1 + byId.ascension.perPoint * asc.lifetime + shopSum(data, "rebirthGain")
end

-- core luck/cash/gem log10 added by prestige shops
function Prestige.luckLog(data): number
	return data.prestige and shopSum(data, "luckLog") or 0
end
function Prestige.cashLog(data): number
	return data.prestige and shopSum(data, "cashLog") or 0
end
function Prestige.gemLog(data): number
	return data.prestige and shopSum(data, "gemLog") or 0
end

function Prestige.startSpawners(data): number
	local best = 1
	if not data.prestige then
		return best
	end
	for _, L in Prestige.LAYERS do
		for _, u in L.shop do
			if u.startSpawners and level(data, L.id, u.id) > 0 then
				best = math.max(best, u.startSpawners)
			end
		end
	end
	return best
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
		for _, u in byId.transcension.shop do
			if u.apMult then
				m *= u.apMult ^ level(data, "transcension", u.id)
			end
		end
	end
	return m
end

-- points you'd get by prestiging this layer right now
function Prestige.pending(data, layerId: string): number
	Prestige.ensure(data)
	local L = byId[layerId]
	local v = sourceValue(data, L)
	if v < L.need then
		return 0
	end
	return math.floor((v / L.need) ^ L.exponent * gainMult(data, L))
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
				return math.floor(u.cost * u.growth ^ lv + 0.5), L, u
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
