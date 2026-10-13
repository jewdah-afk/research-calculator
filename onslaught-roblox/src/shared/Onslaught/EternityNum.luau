--!native
--!optimize 2
--[[
	EternityNum (Luau) — arbitrary-size numbers for the Birb remake.

	Same value layout as FoundForces' EternityNum: an array {sign, layer, mag}
	  {0,0,0} = 0        {1,0,10} = 10        {1,1,500} = 1e500        {1,2,500} = 1e1e500
	and the same algorithms as break_eternity.js (which EternityNum ports and which the
	original Birb uses), so results match the source game bit-for-bit on the shared ops.
	Verified against break_eternity.js: see birb-data/README.md.

	Every function accepts an EN table, a plain number, or a string ("1e500", "1ee10", "12345").
	EN values are treated as immutable: functions always return a new table.

	Extras over the original module:
	  * fast paths for plain-number math (no table churn while values stay < 9e15)
	  * buy-all helpers (geomSum / geomAfford) in closed form — O(1) instead of a loop
	  * short() suffix formatter matching the game HUD (K, M, B, T, Qa, Qi, ...)
	  * lbencode/lbdecode: order-preserving number for OrderedDataStore leaderboards
]]

export type EN = { number }

local EN = {}

local EXP_LIMIT = 9e15
local LAYER_DOWN = math.log10(9e15)
local FIRST_NEG_LAYER = 1 / 9e15
local MAX_SIG = 17
local INF = math.huge
local log10, abs, floor, sign = math.log10, math.abs, math.floor, math.sign

local function isNaN(x: number) return x ~= x end

-- Build from components and normalize (break_eternity `normalize`)
local function FC(s: number, layer: number, mag: number): EN
	if s == 0 or (mag == 0 and layer == 0) or (mag == -INF and layer > 0 and layer ~= INF) then
		return { 0, 0, 0 }
	end
	if layer == 0 and mag < 0 then mag = -mag; s = -s end
	if mag == INF or layer == INF or mag == -INF or layer == -INF then
		return { s, INF, INF }
	end
	if layer == 0 and mag < FIRST_NEG_LAYER then
		return { s, 1, log10(mag) }
	end
	local absmag, signmag = abs(mag), sign(mag)
	if absmag >= EXP_LIMIT then
		return { s, layer + 1, signmag * log10(absmag) }
	end
	while absmag < LAYER_DOWN and layer > 0 do
		layer -= 1
		if layer == 0 then
			mag = 10 ^ mag
		else
			mag = signmag * 10 ^ absmag
			absmag, signmag = abs(mag), sign(mag)
		end
	end
	if layer == 0 then
		if mag < 0 then mag = -mag; s = -s
		elseif mag == 0 then s = 0 end
	end
	if isNaN(s) or isNaN(layer) or isNaN(mag) then return { 0 / 0, 0 / 0, 0 / 0 } end
	return { s, layer, mag }
end
EN.fromComponents = FC

function EN.fromNumber(n: number): EN
	return FC(sign(n), 0, abs(n))
end

-- "123", "1.5e300", "1e1e50", "ee50" (=1e1e50), "-2.5e10"
function EN.fromString(str: string): EN
	str = str:gsub(",", ""):lower()
	local n = tonumber(str)
	if n and n ~= INF and n ~= -INF then return EN.fromNumber(n) end
	local neg = 1
	if str:sub(1, 1) == "-" then neg = -1; str = str:sub(2) end
	-- count leading e's: "ee50" -> layer bump
	local lead = 0
	while str:sub(1, 1) == "e" do lead += 1; str = str:sub(2) end
	local parts = string.split(str, "e")
	if #parts == 1 then
		local v = tonumber(parts[1]) or 0
		local r = FC(neg, 0, v)
		for _ = 1, lead do r = EN.pow10(r) end
		return r
	end
	-- a e b e c ... : evaluate right-to-left as mantissa * 10^(rest)
	local exp: EN = EN.fromNumber(tonumber(parts[#parts]) or 0)
	for i = #parts - 1, 2, -1 do
		local m = tonumber(parts[i]) or 1
		exp = EN.mul(m, EN.pow10(exp))
	end
	local mant = tonumber(parts[1]) or 1
	local r = EN.mul(mant, EN.pow10(exp))
	for _ = 1, lead do r = EN.pow10(r) end
	if neg < 0 then r = EN.neg(r) end
	return r
end

local fromString = EN.fromString

-- Coerce any input to EN
local function D(v: any): EN
	local t = type(v)
	if t == "table" then return v end
	if t == "number" then return FC(sign(v), 0, abs(v)) end
	if t == "string" then return fromString(v) end
	return { 0, 0, 0 }
end
EN.convert = D
EN.new = D

function EN.toNumber(x: any): number
	x = D(x)
	local s, l, m = x[1], x[2], x[3]
	if m == INF and l == INF then return s * INF end
	if l ~= l or l == INF then return 0 / 0 end
	if l == 0 then return s * m end
	if l == 1 then return s * 10 ^ m end
	return if m > 0 then s * INF else 0
end

local ZERO: EN = table.freeze({ 0, 0, 0 })
local ONE: EN = table.freeze({ 1, 0, 1 })
EN.ZERO, EN.ONE = ZERO, ONE

function EN.neg(x: any): EN x = D(x); return { -x[1], x[2], x[3] } end
function EN.abs(x: any): EN x = D(x); return { if x[1] == 0 then 0 else 1, x[2], x[3] } end

function EN.cmpabs(a: any, b: any): number
	a, b = D(a), D(b)
	local la = if a[3] > 0 then a[2] else -a[2]
	local lb = if b[3] > 0 then b[2] else -b[2]
	if la > lb then return 1 end
	if la < lb then return -1 end
	if a[3] > b[3] then return 1 end
	if a[3] < b[3] then return -1 end
	return 0
end

function EN.cmp(a: any, b: any): number
	a, b = D(a), D(b)
	if a[1] > b[1] then return 1 end
	if a[1] < b[1] then return -1 end
	return a[1] * EN.cmpabs(a, b)
end
local cmp = EN.cmp

-- EternityNum-style comparison names
function EN.eq(a, b) return cmp(a, b) == 0 end
function EN.me(a, b) return cmp(a, b) > 0 end      -- a > b
function EN.meeq(a, b) return cmp(a, b) >= 0 end   -- a >= b
function EN.le(a, b) return cmp(a, b) < 0 end      -- a < b
function EN.leeq(a, b) return cmp(a, b) <= 0 end   -- a <= b
function EN.between(v, a, b) return cmp(v, a) > 0 and cmp(v, b) < 0 end
function EN.max(a, b) a, b = D(a), D(b); return if cmp(a, b) >= 0 then a else b end
function EN.min(a, b) a, b = D(a), D(b); return if cmp(a, b) <= 0 then a else b end
function EN.clamp(v, lo, hi) return EN.min(EN.max(v, lo), hi) end
function EN.isZero(x) return D(x)[1] == 0 end
function EN.isNaN(x) x = D(x); return isNaN(x[1]) or isNaN(x[2]) or isNaN(x[3]) end
function EN.isInf(x) x = D(x); return x[3] == INF end

function EN.add(x: any, y: any): EN
	-- fast path: two plain numbers whose sum stays in layer 0
	if type(x) == "number" and type(y) == "number" then return EN.fromNumber(x + y) end
	local a, b = D(x), D(y)
	if a[2] == INF and b[2] == INF and a[1] == -b[1] then return { 0 / 0, 0 / 0, 0 / 0 } end
	if a[2] ~= a[2] or a[2] == INF then return a end
	if b[2] ~= b[2] or b[2] == INF then return b end
	if a[1] == 0 then return b end
	if b[1] == 0 then return a end
	if a[1] == -b[1] and a[2] == b[2] and a[3] == b[3] then return { 0, 0, 0 } end
	if a[2] >= 2 or b[2] >= 2 then
		return if EN.cmpabs(a, b) >= 0 then a else b
	end
	if EN.cmpabs(a, b) < 0 then a, b = b, a end
	if a[2] == 0 and b[2] == 0 then return EN.fromNumber(a[1] * a[3] + b[1] * b[3]) end
	local layera, layerb = a[2] * sign(a[3]), b[2] * sign(b[3])
	if layera - layerb >= 2 then return a end
	if layera == 0 and layerb == -1 then
		if abs(b[3] - log10(a[3])) > MAX_SIG then return a end
		local md = 10 ^ (log10(a[3]) - b[3])
		local mant = b[1] + a[1] * md
		return FC(sign(mant), 1, b[3] + log10(abs(mant)))
	end
	if layera == 1 and layerb == 0 then
		if abs(a[3] - log10(b[3])) > MAX_SIG then return a end
		local md = 10 ^ (a[3] - log10(b[3]))
		local mant = b[1] + a[1] * md
		return FC(sign(mant), 1, log10(b[3]) + log10(abs(mant)))
	end
	if abs(a[3] - b[3]) > MAX_SIG then return a end
	local md = 10 ^ (a[3] - b[3])
	local mant = b[1] + a[1] * md
	return FC(sign(mant), 1, b[3] + log10(abs(mant)))
end
local add = EN.add

function EN.sub(x: any, y: any): EN
	if type(x) == "number" and type(y) == "number" then return EN.fromNumber(x - y) end
	local b = D(y)
	return add(x, { -b[1], b[2], b[3] })
end

function EN.mul(x: any, y: any): EN
	if type(x) == "number" and type(y) == "number" then
		local p = x * y
		if abs(p) < EXP_LIMIT then return EN.fromNumber(p) end
	end
	local a, b = D(x), D(y)
	if a[3] == INF or b[3] == INF then
		if a[1] == 0 or b[1] == 0 then return { 0 / 0, 0 / 0, 0 / 0 } end
		return { a[1] * b[1], INF, INF }
	end
	if a[2] ~= a[2] then return a end
	if b[2] ~= b[2] then return b end
	if a[1] == 0 or b[1] == 0 then return { 0, 0, 0 } end
	if a[2] == b[2] and a[3] == -b[3] then return { a[1] * b[1], 0, 1 } end
	if not (a[2] > b[2] or (a[2] == b[2] and abs(a[3]) > abs(b[3]))) then a, b = b, a end
	if a[2] == 0 and b[2] == 0 then return EN.fromNumber(a[1] * b[1] * a[3] * b[3]) end
	if a[2] >= 3 or a[2] - b[2] >= 2 then return FC(a[1] * b[1], a[2], a[3]) end
	if a[2] == 1 and b[2] == 0 then return FC(a[1] * b[1], 1, a[3] + log10(b[3])) end
	if a[2] == 1 and b[2] == 1 then return FC(a[1] * b[1], 1, a[3] + b[3]) end
	-- a.layer == 2 and b.layer in {1,2}
	local nm = add(FC(sign(a[3]), a[2] - 1, abs(a[3])), FC(sign(b[3]), b[2] - 1, abs(b[3])))
	return FC(a[1] * b[1], nm[2] + 1, nm[1] * nm[3])
end
local mul = EN.mul

function EN.recip(x: any): EN
	x = D(x)
	if x[3] == 0 then return { 0 / 0, 0 / 0, 0 / 0 } end
	if x[3] == INF then return { 0, 0, 0 } end
	if x[2] == 0 then return FC(x[1], 0, 1 / x[3]) end
	return FC(x[1], x[2], -x[3])
end

function EN.div(x: any, y: any): EN
	if type(x) == "number" and type(y) == "number" and y ~= 0 then
		local q = x / y
		if abs(q) < EXP_LIMIT and abs(q) > FIRST_NEG_LAYER then return EN.fromNumber(q) end
	end
	return mul(x, EN.recip(y))
end

function EN.log10(x: any): EN
	x = D(x)
	if x[1] <= 0 then return { 0 / 0, 0 / 0, 0 / 0 } end
	if x[2] > 0 then return FC(sign(x[3]), x[2] - 1, abs(x[3])) end
	return FC(x[1], 0, log10(x[3]))
end

local function absLog10(x: EN): EN
	if x[1] == 0 then return { 0 / 0, 0 / 0, 0 / 0 } end
	if x[2] > 0 then return FC(sign(x[3]), x[2] - 1, abs(x[3])) end
	return FC(1, 0, log10(x[3]))
end

function EN.ln(x: any): EN
	x = D(x)
	if x[1] <= 0 then return { 0 / 0, 0 / 0, 0 / 0 } end
	if x[2] == 0 then return FC(x[1], 0, math.log(x[3])) end
	if x[2] == 1 then return FC(sign(x[3]), 0, abs(x[3]) * 2.302585092994046) end
	if x[2] == 2 then return FC(sign(x[3]), 1, abs(x[3]) + 0.36221568869946325) end
	return FC(sign(x[3]), x[2] - 1, abs(x[3]))
end

function EN.log(x: any, base: any): EN
	x, base = D(x), D(base)
	if x[1] <= 0 or base[1] <= 0 or (base[1] == 1 and base[2] == 0 and base[3] == 1) then
		return { 0 / 0, 0 / 0, 0 / 0 }
	end
	if x[2] == 0 and base[2] == 0 then return FC(x[1], 0, math.log(x[3]) / math.log(base[3])) end
	return EN.div(EN.log10(x), EN.log10(base))
end

function EN.pow10(x: any): EN
	local a = D(x)
	if a[3] == INF then return if a[1] > 0 then { 1, INF, INF } else { 0, 0, 0 } end
	if a[2] ~= a[2] or a[3] ~= a[3] then return { 0 / 0, 0 / 0, 0 / 0 } end
	if a[2] == 0 then
		local nm = 10 ^ (a[1] * a[3])
		if nm ~= INF and abs(nm) >= 0.1 then return FC(1, 0, nm) end
		if a[1] == 0 then return { 1, 0, 1 } end
		a = { a[1], a[2] + 1, log10(a[3]) }
	end
	if a[1] > 0 and a[3] >= 0 then return FC(a[1], a[2] + 1, a[3]) end
	if a[1] < 0 and a[3] >= 0 then return FC(-a[1], a[2] + 1, -a[3]) end
	return { 1, 0, 1 }
end

function EN.pow(x: any, y: any): EN
	if type(x) == "number" and type(y) == "number" and x > 0 then
		local p = x ^ y
		if p < EXP_LIMIT and p > FIRST_NEG_LAYER then return EN.fromNumber(p) end
	end
	local a, b = D(x), D(y)
	if a[1] == 0 then return if b[1] == 0 then { 1, 0, 1 } else a end
	if a[1] == 1 and a[2] == 0 and a[3] == 1 then return a end
	if b[1] == 0 then return { 1, 0, 1 } end
	if b[1] == 1 and b[2] == 0 and b[3] == 1 then return a end
	local r = EN.pow10(mul(absLog10(a), b))
	if a[1] == -1 then
		local bn = EN.toNumber(b)
		local m = abs(bn % 2) % 2
		if m == 1 then return EN.neg(r) end
		if m == 0 then return r end
		return { 0 / 0, 0 / 0, 0 / 0 }
	end
	return r
end

function EN.exp(x: any): EN
	x = D(x)
	if x[3] < 0 then return { 1, 0, 1 } end
	if x[2] == 0 and x[3] <= 709.7 then return EN.fromNumber(math.exp(x[1] * x[3])) end
	if x[2] == 0 then return FC(1, 1, x[1] * log10(math.exp(1)) * x[3]) end
	if x[2] == 1 then return FC(1, 2, x[1] * (log10(0.4342944819032518) + x[3])) end
	return FC(1, x[2] + 1, x[1] * x[3])
end

function EN.sqrt(x: any): EN
	x = D(x)
	if x[2] == 0 then return EN.fromNumber(math.sqrt(x[1] * x[3])) end
	if x[2] == 1 then return FC(1, 2, log10(x[3]) - 0.3010299956639812) end
	local r = EN.div({ x[1], x[2] - 1, x[3] }, { 1, 0, 2 })
	return FC(r[1], r[2] + 1, r[3])
end

function EN.root(x: any, n: any): EN return EN.pow(x, EN.recip(n)) end

function EN.floor(x: any): EN
	x = D(x)
	if x[3] < 0 then return if x[1] == -1 then { -1, 0, 1 } else { 0, 0, 0 } end
	if x[1] == -1 then return EN.neg(EN.ceil(EN.neg(x))) end
	if x[2] == 0 then return FC(x[1], 0, floor(x[3])) end
	return x
end

function EN.ceil(x: any): EN
	x = D(x)
	if x[3] < 0 then return if x[1] == 1 then { 1, 0, 1 } else { 0, 0, 0 } end
	if x[1] == -1 then return EN.neg(EN.floor(EN.neg(x))) end
	if x[2] == 0 then return FC(x[1], 0, math.ceil(x[3])) end
	return x
end

function EN.round(x: any): EN
	x = D(x)
	if x[3] < 0 then return { 0, 0, 0 } end
	if x[2] == 0 then return FC(x[1], 0, floor(x[3] + 0.5)) end -- JS Math.round semantics for x >= 0
	return x
end

------------------------------------------------------------------ Buy-all helpers
-- Total cost of buying `n` levels of a geometric upgrade whose next level costs
-- base * r^level, starting at `level`:   base * r^level * (r^n - 1) / (r - 1)
function EN.geomSum(base: any, r: number, level: number, n: number): EN
	if n <= 0 then return { 0, 0, 0 } end
	local first = mul(base, EN.pow(r, level))
	if r == 1 then return mul(first, n) end
	return mul(first, EN.div(EN.sub(EN.pow(r, n), 1), r - 1))
end

-- Max levels affordable with `money` (closed form, O(1)):
-- n = floor(log_r(money*(r-1)/(base*r^level) + 1))
function EN.geomAfford(money: any, base: any, r: number, level: number): number
	local first = mul(base, EN.pow(r, level))
	if cmp(money, first) < 0 then return 0 end
	if r == 1 then return EN.toNumber(EN.floor(EN.div(money, first))) end
	local inner = add(EN.div(mul(money, r - 1), first), 1)
	local n = EN.toNumber(EN.div(EN.log10(inner), log10(r)))
	n = floor(n + 1e-9)
	-- guard against float error at the boundary
	if n > 0 and cmp(EN.geomSum(base, r, level, n), money) > 0 then n -= 1 end
	return math.max(0, n)
end

------------------------------------------------------------------ Formatting
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg" }

local function trimNum(v: number, digits: number): string
	local s = string.format("%." .. digits .. "f", v)
	if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s
end

-- split a base-10 exponent into (integer exponent, mantissa string), carrying 9.999 -> 10 up
local function splitExp(e: number, d: number): (number, string)
	local ie = floor(e + 1e-9)
	local m = 10 ^ (e - ie)
	if tonumber(trimNum(m, d)) >= 10 then ie += 1; m /= 10 end
	return ie, trimNum(math.max(1, m), d)
end

-- Game-HUD style: 999, 1.5K, 23.4M, ... then 1.23e75, then e1.2e20, then "F5" (layers)
function EN.short(x: any, digits: number?): string
	x = D(x)
	local d = digits or 2
	if x[1] ~= x[1] then return "NaN" end
	if x[3] == INF then return if x[1] < 0 then "-Inf" else "Inf" end
	local neg = if x[1] < 0 then "-" else ""
	if x[2] == 0 then
		local v = x[3]
		if v < 1000 then
			return neg .. (if v == floor(v) then tostring(v) else trimNum(v, d))
		end
		local e = floor(log10(v) / 3)
		if e < #SUFFIXES then
			return neg .. trimNum(v / 10 ^ (e * 3), d) .. SUFFIXES[e + 1]
		end
	end
	if x[2] <= 1 then
		local e = if x[2] == 0 then log10(x[3]) else x[3]
		local tier = floor(e / 3)
		if tier < #SUFFIXES then
			local m = 10 ^ (e - tier * 3)
			if tonumber(trimNum(m, d)) >= 1000 and tier + 1 < #SUFFIXES then
				return neg .. trimNum(m / 1000, d) .. SUFFIXES[tier + 2]
			end
			return neg .. trimNum(m, d) .. SUFFIXES[tier + 1]
		end
		local ie, m = splitExp(e, d)
		return neg .. m .. "e" .. tostring(ie)
	end
	if x[2] == 2 then
		local ie, m = splitExp(x[3], d)
		return neg .. "e" .. m .. "e" .. tostring(ie)
	end
	return neg .. "F" .. tostring(x[2]) .. ":" .. trimNum(x[3], d)
end

-- Lossless round-trip string for saving: "sign;layer;mag"
function EN.toString(x: any): string
	x = D(x)
	return string.format("%d;%d;%.17g", x[1], x[2], x[3])
end

function EN.fromSave(s: string): EN
	local a, b, c = string.match(s, "^(%-?%d+);(%-?%d+);(.+)$")
	if a then return FC(tonumber(a) :: number, tonumber(b) :: number, tonumber(c) :: number) end
	return fromString(s)
end

-- Order-preserving encoding for OrderedDataStore (integer < 2^53). Positive values only; 0 -> 0.
-- key = (layer + t) * 1e14, where t in [0,1) is the log-position of mag inside its layer.
local LOG_EXP_LIMIT = log10(EXP_LIMIT)
local LOG_LAYER_DOWN = log10(LAYER_DOWN)
local LB_SCALE = 1e14
function EN.lbencode(x: any): number
	x = D(x)
	if x[1] <= 0 then return 0 end
	if x[3] == INF then return 2 ^ 53 - 1 end
	local layer, mag = x[2], x[3]
	local t
	if layer == 0 then
		if mag < 1 then return 0 end
		t = log10(mag) / LOG_EXP_LIMIT
	else
		if mag < LAYER_DOWN then return 0 end -- layer>=1 with negative/small mag: value < 1
		t = (log10(mag) - LOG_LAYER_DOWN) / (LOG_EXP_LIMIT - LOG_LAYER_DOWN)
	end
	return math.min(2 ^ 53 - 2, 1 + floor((layer + math.clamp(t, 0, 0.999999999999)) * LB_SCALE))
end

function EN.lbdecode(n: number): EN
	if n <= 0 then return { 0, 0, 0 } end
	local v = (n - 1) / LB_SCALE
	local layer = floor(v)
	local t = v - layer
	if layer == 0 then return FC(1, 0, 10 ^ (t * LOG_EXP_LIMIT)) end
	return FC(1, layer, 10 ^ (LOG_LAYER_DOWN + t * (LOG_EXP_LIMIT - LOG_LAYER_DOWN)))
end

------------------------------------------------------------------ Metatable sugar (opt-in)
-- local a = EN.wrap(5); local b = a * 3 + "1e400"   (uses metamethods; slower than direct calls)
local MT = {}
MT.__index = MT
local function W(v: EN) return setmetatable(table.clone(v), MT) end
MT.__add = function(a, b) return W(add(a, b)) end
MT.__sub = function(a, b) return W(EN.sub(a, b)) end
MT.__mul = function(a, b) return W(mul(a, b)) end
MT.__div = function(a, b) return W(EN.div(a, b)) end
MT.__pow = function(a, b) return W(EN.pow(a, b)) end
MT.__unm = function(a) return W(EN.neg(a)) end
MT.__eq = function(a, b) return cmp(a, b) == 0 end
MT.__lt = function(a, b) return cmp(a, b) < 0 end
MT.__le = function(a, b) return cmp(a, b) <= 0 end
MT.__tostring = function(a) return EN.short(a) end
function EN.wrap(v: any) return W(D(v)) end

return EN
