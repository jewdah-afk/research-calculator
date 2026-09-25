--!nocheck
-- JSRT: the small slice of JavaScript semantics the transpiled Milestone Tree NG+ needs, plus a break_eternity-style
-- Decimal built on TowerNum. Every JS function value takes `this` as its first parameter.
-- array lengths, key order and key caches are shared by every instance (arrays stay arrays across instances)
local SHARED_LEN = setmetatable({}, { __mode = "k" })
local SHARED_ORDER = setmetatable({}, { __mode = "k" })
local SHARED_KC = setmetatable({}, { __mode = "k" })
return function(TN, BEcore)

local huge, floor, abs, fmod = math.huge, math.floor, math.abs, math.fmod
local sfmt, ssub, sfind, srep, sbyte, schar, slower, supper = string.format, string.sub, string.find, string.rep, string.byte, string.char, string.lower, string.upper
local tinsert, tsort, tconcat, tclear = table.insert, table.sort, table.concat, table.clear

local JS = {}
local LEN = SHARED_LEN     -- array -> length (arrays are 0-based)
local ORDER = SHARED_ORDER   -- object -> string keys in insertion order
local KC = SHARED_KC      -- object -> cached for-in key list (dropped when a key appears/disappears)
JS.LEN, JS.ORDER = LEN, ORDER
JS.NOW = 1.7e12

-- ------------------------------------------------------------------ Decimal (break_eternity API over TowerNum)
local DMT = {}
local DP = {}                                    -- Decimal methods
JS.DMT = DMT
local function isD(x) return type(x) == "table" and getmetatable(x) == DMT end
JS.isD = isD

local parseStr   -- break_eternity's fromString, defined with the other Decimal methods below
local function V(x)
	local t = type(x)
	if t == "number" then return x end
	if t == "table" then
		if getmetatable(x) == DMT then return x.v end
		if rawget(x, "l") ~= nil and rawget(x, "m") ~= nil then return x end   -- a raw TowerNum value
		return 0
	end
	if t == "string" then return (parseStr(x)) end
	return 0
end
-- A NaN carries break_eternity's own components (NaN, 0, NaN), so every operation on it goes through BEcore and
-- answers like the web game (0 * NaN is 0 there; a NaN from x / 0 or log(0) is the layer-NaN kind that stays NaN).
local function mk(v)
	if v ~= v then return setmetatable({ v = v, be = BEcore.NN(0 / 0, 0, 0 / 0) }, DMT) end
	return setmetatable({ v = v }, DMT)
end
local function D(x)
	if isD(x) then local r = mk(x.v); r.be = x.be; return r end
	if type(x) == "string" then local v, be = parseStr(x); local r = mk(v); r.be = be; return r end
	if x == huge or x == -huge then
		local r = mk(x); r.be = BEcore.fromNumber(x); return r      -- break_eternity's layer-1 Infinity
	end
	return mk(V(x))
end
JS.D = function(x) return D(x) end
JS.V = V

-- break_eternity normal form (sign, layer, mag) for the few places that read the fields directly
local EXP_LIMIT = 9e15
local function comps(v)
	if type(v) == "number" then
		if v ~= v then return 0 / 0, 0, 0 / 0 end
		local s = if v > 0 then 1 elseif v < 0 then -1 else 0
		local a = abs(v)
		if a == huge then return s, huge, huge end
		if a < EXP_LIMIT then
			if a < 1 / 9e15 and a > 0 then return s, 1, math.log10(a) end   -- break_eternity's first negative layer
			return s, 0, a
		end
		return s, 1, math.log10(a)
	end
	if v.h ~= nil then return (if v.m < 0 then -1 else 1), huge, huge end
	-- towers {l, m}: l < 0 is the reciprocal 1 / (l-tall tower of m); break_eternity writes that as a negative mag
	local s = if v.m < 0 then -1 else 1
	local l, m = v.l, abs(v.m)
	if l < 0 then l = -l; m = -m end
	while m >= EXP_LIMIT or m <= -EXP_LIMIT do
		l += 1
		m = if m < 0 then -math.log10(-m) else math.log10(m)
	end
	return s, l, m
end
JS.comps = comps
-- method lookups go straight to DP; the break_eternity fields (sign/layer/mag/e/m) are read through JS.P
local function dprop(self, k)
	local be = self.be
	if be then
		if k == "sign" then return be.s elseif k == "layer" then return be.l elseif k == "mag" then return be.m end
	end
	if k == "sign" or k == "layer" or k == "mag" then
		local s, l, m = comps(self.v)
		return if k == "sign" then s elseif k == "layer" then l else m
	end
	if k == "e" or k == "exponent" then
		local s, l, m = comps(self.v)
		if l == 0 then if m == 0 then return 0 end return floor(math.log10(m)) end
		if l == 1 then return floor(m) end
		if l == 2 then return floor(10 ^ m) end
		return huge
	end
	if k == "m" or k == "mantissa" then
		local s, l, m = comps(self.v)
		if l == 0 then
			if m == 0 then return 0 end
			local e = floor(math.log10(m))
			return s * (m / 10 ^ e)
		end
		if l == 1 then return s * 10 ^ (m % 1) end
		return s
	end
	return nil
end
DMT.__index = DP
function JS.P(o, k)
	if type(o) == "table" and getmetatable(o) == DMT then return dprop(o, k) end
	if o == nil then error("Cannot read properties of undefined (reading '" .. k .. "')", 2) end
	if type(o) ~= "table" then return nil end
	return o[k]
end
DMT.__tostring = function(self) return DP.toString(self) end
DMT.__eq = function(a, b) return TN.eq(a.v, b.v) end
DMT.__lt = function(a, b) return TN.lt(V(a), V(b)) end
DMT.__le = function(a, b) return TN.le(V(a), V(b)) end
DMT.__unm = function(a) return mk(TN.neg(a.v)) end

-- ---- break_eternity compatibility -------------------------------------------------------------------------------
-- The game ships an old break_eternity. TowerNum does the arithmetic; where that old version answers differently the
-- game's own answer is reproduced:
--   * new Decimal(Infinity), Decimal.dInf and anything computed from them go through BEcore (a line-for-line port of
--     the old library). E.g. new Decimal(Infinity) ranks BELOW every number from ee15.95 up, so Infinity-cost upgrades
--     become affordable at ee16, and paying that cost leaves the currency unchanged, exactly like the web game.
--   * NaN compares like the old library: gte / lte are true, gt / lt / eq false
--   * log10 / ln / log2 / log of 0 or a negative, x/0 and 1/0 are NaN (not -Infinity / Infinity)
--   * pow of a negative base is |base|^b, negated only for odd integer powers; 0^b is 0 for any b ~= 0
--   * floor / ceil / round / trunc act on the magnitude and keep the sign (floor(-2.5) = -2)
--   * slog is the old linear-approximation version
local BEc = BEcore
local function special(b)
	local t = type(b)
	if t == "table" then return getmetatable(b) == DMT and b.be ~= nil end
	if t == "number" then return b == huge or b == -huge or b ~= b end
	return false
end
local function tri(x)
	if isD(x) then
		if x.be then return x.be end
		local s, l, m = comps(x.v)
		return BEc.NN(s, l, m)
	end
	if type(x) == "number" then return BEc.fromNumber(x) end
	return tri(D(x))
end
local function triToTN(t)
	if t.s == 0 then return 0 end
	if t.l == 0 then return t.s * t.m end
	-- layer l, mag m: 10^(sign(m) * (l-1 tall tower of |m|))
	local x = abs(t.m)
	for _ = 1, t.l - 1 do x = TN.exp10(x) end
	if t.m < 0 then x = TN.neg(x) end
	x = TN.exp10(x)
	if t.s < 0 then x = TN.neg(x) end
	return x
end
local function fromTri(t)
	if BEc.finite(t.l) and BEc.finite(t.m) and t.s == t.s then return mk(triToTN(t)) end
	local d = mk(if t.s ~= t.s or t.l ~= t.l or t.m ~= t.m then 0 / 0 elseif t.s < 0 then -huge elseif t.s > 0 then huge else 0 / 0)
	d.be = t
	return d
end
local function nanL() return fromTri(BEc.NN(0 / 0, 0 / 0, 0 / 0)) end   -- break_eternity's layer-NaN (x / 0, log of 0)
JS.tri, JS.fromTri = tri, fromTri
local function bv_(b)
	local t = type(b)
	if t == "table" and getmetatable(b) == DMT then return b.v end
	if t == "number" then return b end
	return V(b)
end
local tnge, tngt, tnle, tnlt, tneq, tncmp = TN.ge, TN.gt, TN.le, TN.lt, TN.eq, TN.cmp
function DP.gte(a, b)
	if a.be or special(b) then return BEc.gte(tri(a), tri(b)) end
	local av, v = a.v, bv_(b)
	if tnge(av, v) then return true end
	return av ~= av or v ~= v
end
function DP.lte(a, b)
	if a.be or special(b) then return BEc.lte(tri(a), tri(b)) end
	local av, v = a.v, bv_(b)
	if tnle(av, v) then return true end
	return av ~= av or v ~= v
end
function DP.gt(a, b)
	if a.be or special(b) then return BEc.gt(tri(a), tri(b)) end
	local av, v = a.v, bv_(b)
	if av ~= av or v ~= v then return false end    -- TowerNum would rank NaN below towers
	return tngt(av, v)
end
function DP.lt(a, b)
	if a.be or special(b) then return BEc.lt(tri(a), tri(b)) end
	local av, v = a.v, bv_(b)
	if av ~= av or v ~= v then return false end
	return tnlt(av, v)
end
function DP.eq(a, b)
	if a.be or special(b) then return BEc.eq(tri(a), tri(b)) end
	return tneq(a.v, bv_(b))
end
function DP.neq(a, b) return not DP.eq(a, b) end
function DP.cmp(a, b)
	local av, v = a.v, bv_(b)
	if a.be or special(b) or av ~= av or v ~= v then return BEc.cmp(tri(a), tri(b)) end
	return tncmp(av, v)
end
DP.compare = DP.cmp
function DP.max(a, b) if DP.lt(a, b) then return D(b) end return a end
function DP.min(a, b) if DP.gt(a, b) then return D(b) end return a end
function DP.clamp(a, lo, hi) return DP.min(DP.max(a, lo), hi) end
function DP.clampMin(a, lo) return DP.max(a, lo) end
function DP.clampMax(a, hi) return DP.min(a, hi) end
local tnadd, tnsub, tnmul, tndiv = TN.add, TN.sub, TN.mul, TN.div
function DP.add(a, b) if a.be or special(b) then return fromTri(BEc.add(tri(a), tri(b))) end return mk(tnadd(a.v, V(b))) end
function DP.sub(a, b) if a.be or special(b) then return fromTri(BEc.sub(tri(a), tri(b))) end return mk(tnsub(a.v, V(b))) end
function DP.mul(a, b) if a.be or special(b) then return fromTri(BEc.mul(tri(a), tri(b))) end return mk(tnmul(a.v, V(b))) end
function DP.div(a, b)
	if a.be or special(b) then return fromTri(BEc.div(tri(a), tri(b))) end
	local av, bv = a.v, V(b)
	if bv == 0 then return nanL() end
	if type(av) == "number" and type(bv) == "number" and bv < EXP_LIMIT and bv > -EXP_LIMIT then
		local r = av * (1 / bv)      -- break_eternity divides as a * (1/b)
		if r < EXP_LIMIT and r > -EXP_LIMIT then return mk(r) end
	end
	return mk(tndiv(av, bv))
end
DP.plus, DP.minus, DP.times, DP.dividedBy, DP.divide, DP.multiply = DP.add, DP.sub, DP.mul, DP.div, DP.div, DP.mul
local function recipV(v)
	if v == 0 then return 0 / 0 end
	return TN.recip(v)
end
function DP.recip(a) if a.be then return fromTri(BEc.recip(a.be)) end if a.v == 0 then return nanL() end return mk(recipV(a.v)) end
DP.reciprocal = DP.recip
local powV
function powV(av, bv)
	if av == 0 then if bv == 0 then return 1 end return av end
	if av == 1 then return av end
	if bv == 0 then return 1 end
	if bv == 1 then return av end
	if bv ~= bv or av ~= av then return 0 / 0 end
	if type(av) == "number" and type(bv) == "number" and av > 0 and bv < EXP_LIMIT and bv > -EXP_LIMIT then
		-- the old library always goes through logs: 10^(log10(a) * b). Same rounding as the web game.
		local x = math.log10(av) * bv
		if x < EXP_LIMIT and x > -EXP_LIMIT then
			local r = 10 ^ x
			if r == r and r ~= huge and r > 0.1 then return r end
			return fromTri(BEc.pow10(BEc.fromNumber(x))).v
		end
	end
	if type(av) == "number" and av < 0 then
		local r = powV(-av, bv)
		if abs(fmod(TN.toNumber(bv), 2)) == 1 then return TN.neg(r) end
		return r
	end
	if type(av) == "table" and av.h == nil and av.m < 0 then
		local r = TN.pow(TN.neg(av), bv)
		if abs(fmod(TN.toNumber(bv), 2)) == 1 then return TN.neg(r) end
		return r
	end
	return TN.pow(av, bv)
end
JS.powV = powV
function DP.pow(a, b) if a.be or special(b) then return fromTri(BEc.pow(tri(a), tri(b))) end return mk(powV(a.v, V(b))) end
function DP.pow_base(a, b) if a.be or special(b) then return fromTri(BEc.pow(tri(b), tri(a))) end return mk(powV(V(b), a.v)) end
function DP.root(a, n)
	if a.be or special(n) or V(n) == 0 then return fromTri(BEc.root(tri(a), tri(n))) end
	return mk(powV(a.v, recipV(V(n))))
end
function DP.cbrt(a) if a.be then return fromTri(BEc.pow(a.be, BEc.fromNumber(1 / 3))) end return mk(powV(a.v, 1 / 3)) end
function DP.sqrt(a)
	if a.be then return fromTri(BEc.sqrt(a.be)) end
	local v = a.v
	if type(v) == "number" and v ~= 0 and v < 1 / 9e15 and v > -1 / 9e15 then return fromTri(BEc.sqrt(tri(a))) end   -- old library: NaN
	if type(v) == "number" and v < 0 then
		if v > -EXP_LIMIT then return mk(0 / 0) end
		return mk(TN.sqrt(-v))               -- layer 1: the sign is dropped
	end
	if type(v) == "table" and v.h == nil and v.m < 0 then
		local s, l = comps(v)
		local r = TN.sqrt(TN.neg(v))
		if l >= 2 then return mk(TN.neg(r)) end
		return mk(r)
	end
	return mk(TN.sqrt(v))
end
local function positive(v)
	if type(v) == "number" then return v > 0 end
	return v.m > 0
end
function DP.log10(a) if a.be then return fromTri(BEc.log10(a.be)) end if not positive(a.v) then return nanL() end return mk(TN.log10(a.v)) end
function DP.ln(a) if a.be then return fromTri(BEc.ln(a.be)) end if not positive(a.v) then return nanL() end return mk(TN.ln(a.v)) end
function DP.log2(a) if a.be then return fromTri(BEc.log2(a.be)) end if not positive(a.v) then return nanL() end return mk(TN.log2(a.v)) end
local function logV(av, bv)
	if not positive(av) or not positive(bv) or bv == 1 then return 0 / 0 end
	if type(av) == "number" and type(bv) == "number" and av < EXP_LIMIT and bv < EXP_LIMIT then
		return math.log(av) / math.log(bv)
	end
	return TN.div(TN.log10(av), TN.log10(bv))
end
function DP.log(a, base)
	if a.be or special(base) then return fromTri(BEc.log(tri(a), tri(base))) end
	local bv = V(base)
	if not positive(a.v) or not positive(bv) or bv == 1 then return nanL() end
	return mk(logV(a.v, bv))
end
function DP.exp(a)
	if a.be then return fromTri(BEc.exp(a.be)) end
	local v = a.v
	if type(v) == "number" and v <= 709.7 and v >= -709.7 then return mk(math.exp(v)) end
	return fromTri(BEc.exp(tri(a)))
end
local function magRound(a, f, bef)
	if a.be then return fromTri(bef(a.be)) end
	local v = a.v
	if type(v) ~= "number" then
		local s, l, m = comps(v)
		if m < 0 then return mk(0) end      -- tiny (1e-9e15 and below)
		return a
	end
	if v ~= v then return a end
	local m = abs(v)
	if m >= EXP_LIMIT then return a end
	if m < 1 / 9e15 then return mk(0) end
	local r = f(m)
	if v < 0 then r = -r end
	return mk(r)
end
function DP.floor(a) return magRound(a, floor, BEc.floor) end
function DP.ceil(a) return magRound(a, math.ceil, BEc.ceil) end
function DP.round(a) return magRound(a, function(m) return floor(m + 0.5) end, BEc.round) end
function DP.trunc(a) return magRound(a, floor, BEc.floor) end
function DP.abs(a) if a.be then return fromTri(BEc.abs(a.be)) end return mk(TN.abs(a.v)) end
function DP.neg(a) if a.be then return fromTri(BEc.neg(a.be)) end return mk(TN.neg(a.v)) end
DP.negate = DP.neg
function DP.mod(a, b) return mk(TN.mod(a.v, V(b))) end
function DP.tetrate(a, h, payload)
	if h == nil then h = 2 end
	if payload ~= nil and not TN.eq(V(payload), 1) then
		local x = V(payload)
		for _ = 1, floor(TN.toNumber(V(h))) do x = powV(a.v, x) end
		return mk(x)
	end
	return mk(TN.tetrate(a.v, V(h)))
end
function DP.slog(a, base)
	-- the old break_eternity: linear critical section, done on components so every case matches
	local copy = tri(a)
	if copy.m < 0 then return mk(-1) end
	local b = if base == nil then BEc.fromNumber(10) else tri(base)
	local result = 0
	if copy.l - b.l > 3 then
		local loss = copy.l - b.l - 3
		result += loss
		copy = BEc.NN(copy.s, copy.l - loss, copy.m)
	end
	for _ = 1, 100 do
		if BEc.lt(copy, BEc.NN(0, 0, 0)) then
			copy = BEc.pow(b, copy)
			result -= 1
		elseif BEc.lte(copy, BEc.NN(1, 0, 1)) then
			return fromTri(BEc.fromNumber(result + BEc.toNumber(copy) - 1))
		else
			result += 1
			copy = BEc.log(copy, b)
		end
	end
	return fromTri(BEc.fromNumber(result))
end

-- new Decimal(string): the game's break_eternity fromString, step for step. The game leans on its leniency: a number
-- that became a string by accident ("0.02" + a Decimal is "0.021", then "0.0210.02") still reads as its longest
-- numeric prefix (0.021), and text that is no number at all reads as 0, never NaN.
local function jsParseFloat(str_)
	local rest = string.match(str_, "^%s*(.*)$")
	local sign = ssub(rest, 1, 1)
	if sign == "+" or sign == "-" then rest = ssub(rest, 2) else sign = "" end
	if ssub(rest, 1, 8) == "Infinity" then return if sign == "-" then -huge else huge end
	local num = string.match(rest, "^%d+%.?%d*") or string.match(rest, "^%.%d+")
	if num == nil then return 0 / 0 end
	local e = string.match(ssub(rest, #num + 1), "^[eE][%+%-]?%d+")
	local n = tonumber(num .. (e or ""))
	if sign == "-" then n = -n end
	return n
end
JS.parseFloat = jsParseFloat
local function jsSplit(str_, sep)
	local parts, init = {}, 1
	while true do
		local a, b = sfind(str_, sep, init, true)
		if a == nil then parts[#parts + 1] = ssub(str_, init); return parts end
		parts[#parts + 1] = ssub(str_, init, a - 1)
		init = b + 1
	end
end
local function jsFinite(x) return x == x and x ~= huge and x ~= -huge end
local function replaceFirst(str_, a, b)
	local i, j = sfind(str_, a, 1, true)
	if i == nil then return str_ end
	return ssub(str_, 1, i - 1) .. b .. ssub(str_, j + 1)
end
local function tetratedTri(base, height, payload)
	return tri(DP.tetrate(mk(base), height, if payload == 1 then nil else payload))
end
local function beFromString(value)
	value = replaceFirst(value, ",", "")                  -- IGNORE_COMMAS
	local parts = jsSplit(value, "^^^")                   -- x^^^y
	if #parts == 2 then
		local base, height = jsParseFloat(parts[1]), jsParseFloat(parts[2])
		if jsFinite(base) and jsFinite(height) then return tri(mk(TN.pentate(base, height))) end
	end
	parts = jsSplit(value, "^^")                          -- x^^y[;payload]
	if #parts == 2 then
		local base, height = jsParseFloat(parts[1]), jsParseFloat(parts[2])
		local payload = 1
		local hp = jsSplit(parts[2], ";")
		if #hp == 2 then payload = jsParseFloat(hp[2]); if not jsFinite(payload) then payload = 1 end end
		if jsFinite(base) and jsFinite(height) then return tetratedTri(base, height, payload) end
	end
	parts = jsSplit(value, "^")                           -- x^y
	if #parts == 2 then
		local base, exponent = jsParseFloat(parts[1]), jsParseFloat(parts[2])
		if jsFinite(base) and jsFinite(exponent) then return tri(DP.pow(mk(base), exponent)) end
	end
	value = slower(string.match(value, "^%s*(.-)%s*$"))
	for _, sep in { "pt", "p" } do                        -- X pt Y / XpY: 10^^X with payload Y
		parts = jsSplit(value, sep)
		if #parts == 2 then
			local height = jsParseFloat(parts[1])
			local payload = jsParseFloat(replaceFirst(replaceFirst(parts[2], "(", ""), ")", ""))
			if not jsFinite(payload) then payload = 1 end
			if jsFinite(height) then return tetratedTri(10, height, payload) end
		end
	end
	parts = jsSplit(value, "e")
	local ecount = #parts - 1
	if ecount == 0 then
		local n = jsParseFloat(value)
		if jsFinite(n) then return BEc.fromNumber(n) end
	elseif ecount == 1 then
		local n = jsParseFloat(value)
		if jsFinite(n) and n ~= 0 then return BEc.fromNumber(n) end
	end
	local t = BEc.NN(0, 0, 0)
	local newparts = jsSplit(value, "e^")                 -- (e^N)X
	if #newparts == 2 then
		t.s = if ssub(newparts[1], 1, 1) == "-" then -1 else 1
		local np = newparts[2]
		for i = 1, #np do
			local c = sbyte(np, i)
			if not ((c >= 43 and c <= 57) or c == 101) then
				t.l = jsParseFloat(ssub(np, 1, i - 1))
				t.m = jsParseFloat(ssub(np, i + 1))
				if t.l == huge or t.l == -huge then return BEc.NN(0 / 0, 0 / 0, 0 / 0) end   -- the web game hangs here
				return BEc.normalize(t)
			end
		end
	end
	if ecount < 1 then return BEc.NN(0, 0, 0) end
	local mantissa = jsParseFloat(parts[1])
	if mantissa == 0 then return BEc.NN(0, 0, 0) end
	local exponent = jsParseFloat(parts[#parts])
	if ecount >= 2 then
		local me = jsParseFloat(parts[#parts - 1])
		if jsFinite(me) then
			exponent *= (if me > 0 then 1 elseif me < 0 then -1 else me)
			exponent += (if me > 0 then 1 elseif me < 0 then -1 else me) * math.log10(abs(me))
		end
	end
	if not jsFinite(mantissa) then
		t.s = if parts[1] == "-" then -1 else 1
		t.l = ecount
		t.m = exponent
	elseif ecount == 1 then
		t.s = if mantissa > 0 then 1 elseif mantissa < 0 then -1 else mantissa
		t.l = 1
		t.m = exponent + math.log10(abs(mantissa))
	else
		t.s = if mantissa > 0 then 1 elseif mantissa < 0 then -1 else mantissa
		t.l = ecount
		if ecount == 2 then return BEc.mul(BEc.FC(1, 2, exponent), BEc.fromNumber(mantissa)) end
		t.m = exponent
	end
	return BEc.normalize(t)
end
-- strings the game parses are mostly constants ("ee9", "1e1000") read every tick: remember what they came to
local STRCACHE, strCount = {}, 0
function parseStr(x)
	local c = STRCACHE[x]
	if c == nil then
		local t = beFromString(x)
		local d = fromTri(t)
		c = { d.v, d.be }
		if strCount > 4096 then table.clear(STRCACHE); strCount = 0 end
		STRCACHE[x] = c
		strCount += 1
	end
	return c[1], c[2]
end
JS.beFromString = beFromString
function DP.lambertw(a) return mk(TN.lambertw(a.v)) end
function DP.toNumber(a) if a.be then return BEcore.toNumber(a.be) end return TN.toNumber(a.v) end
function DP.sign_(a) return TN.sign(a.v) end
function DP.isNan(a) return TN.isNaN(a.v) end
function DP.isFinite(a) return not TN.isNaN(a.v) and not TN.isInf(a.v) end
function DP.valueOf(a) return DP.toString(a) end
function DP.toJSON(a) return DP.toString(a) end
function DP.fromValue(a, x) a.v = V(x); return a end

-- ------------------------------------------------------------------ JS number -> string
local function jsExp(x) -- shortest round-trip digits + decimal exponent
	-- 15 significant digits always land on the shortest form when they round-trip; else 16, else 17
	for _, p in { 15, 16, 17 } do
		local s = sfmt("%." .. (p - 1) .. "e", x)
		if p == 17 or tonumber(s) == x then
			local mant, ex = string.match(s, "^%-?([%d%.]+)e([%+%-]%d+)$")
			return (string.gsub(mant, "%.", "")), tonumber(ex)
		end
	end
	return "0", 0
end
local INTSTR = {}
local function numToString(x)
	if x == floor(x) and x < 1e15 and x > -1e15 then   -- integers (the common case)
		if x >= 0 and x < 100000 then
			local c = INTSTR[x]
			if c == nil then c = sfmt("%d", x); INTSTR[x] = c end
			return c
		end
		return sfmt("%d", x)
	end
	if x ~= x then return "NaN" end
	if x == huge then return "Infinity" end
	if x == -huge then return "-Infinity" end
	if x == 0 then return "0" end
	local neg = x < 0
	if neg then x = -x end
	local digits, e = jsExp(x)
	digits = string.gsub(digits, "0+$", "")
	if digits == "" then digits = "0" end
	local k, n = #digits, e + 1
	local s
	if k <= n and n <= 21 then s = digits .. srep("0", n - k)
	elseif 0 < n and n <= 21 then s = ssub(digits, 1, n) .. "." .. ssub(digits, n + 1)
	elseif -6 < n and n <= 0 then s = "0." .. srep("0", -n) .. digits
	else
		local es = (if n - 1 >= 0 then "+" else "-") .. tostring(abs(n - 1))
		if k == 1 then s = digits .. "e" .. es else s = ssub(digits, 1, 1) .. "." .. ssub(digits, 2) .. "e" .. es end
	end
	return if neg then "-" .. s else s
end
JS.numToString = numToString

local function toFixed(x, f)
	f = floor(f or 0)
	if x ~= x then return "NaN" end
	if abs(x) >= 1e21 then return numToString(x) end
	local s = sfmt("%." .. f .. "f", x)
	-- JS picks the larger n on an exact tie; C rounds ties to even
	local scaled = abs(x) * 10 ^ f
	if scaled - floor(scaled) == 0.5 and scaled < 2 ^ 52 then
		local up = (floor(scaled) + 1) / 10 ^ f
		s = sfmt("%." .. f .. "f", if x < 0 then -up else up)
	end
	if s == "-0" or string.match(s, "^%-0%.?0*$") then s = ssub(s, 2) end
	return s
end
JS.toFixed = toFixed
local function toPrecision(x, p)
	if x ~= x then return "NaN" end
	if abs(x) == huge then return numToString(x) end
	p = floor(p)
	if x == 0 then return if p > 1 then "0." .. srep("0", p - 1) else "0" end
	local s = sfmt("%." .. (p - 1) .. "e", x)
	local sign, mant, ex = string.match(s, "^(%-?)([%d%.]+)e([%+%-]%d+)$")
	local e = tonumber(ex)
	local digits = string.gsub(mant, "%.", "")
	if e < -6 or e >= p then
		return sign .. ssub(digits, 1, 1) .. (if p > 1 then "." .. ssub(digits, 2) else "") .. "e" .. (if e >= 0 then "+" else "-") .. abs(e)
	end
	if e >= 0 then
		local ip = ssub(digits, 1, e + 1)
		local fp = ssub(digits, e + 2)
		return sign .. ip .. (if #fp > 0 then "." .. fp else "")
	end
	return sign .. "0." .. srep("0", -e - 1) .. digits
end
JS.toPrecision = toPrecision

function DP.toString(a)
	local s, l, m = comps(a.v)
	if s ~= s then return "NaN" end
	if l == huge then return if s < 0 then "-Infinity" else "Infinity" end
	if l == 0 then
		if (m < 1e21 and m > 1e-7) or m == 0 then return numToString(s * m) end
		return numToString(dprop(a, "m")) .. "e" .. numToString(dprop(a, "e"))
	end
	if l == 1 then return numToString(dprop(a, "m")) .. "e" .. numToString(dprop(a, "e")) end
	if l <= 5 then return (if s == -1 then "-" else "") .. srep("e", l) .. numToString(m) end
	return (if s == -1 then "-" else "") .. "(e^" .. l .. ")" .. numToString(m)
end
local function decimalPlaces(v, places)
	local len = places + 1
	local numDigits = math.ceil(math.log10(abs(v)))
	local rounded = math.floor(v * 10 ^ (len - numDigits) + 0.5) * 10 ^ (numDigits - len)
	return toFixed(rounded, math.max(len - numDigits, 0))
end
function DP.toStringWithDecimalPlaces(a, places)
	local s, l, m = comps(a.v)
	if l == 0 then
		if (m < 1e21 and m > 1e-7) or m == 0 then return toFixed(s * m, places) end
		return decimalPlaces(dprop(a, "m"), places) .. "e" .. decimalPlaces(dprop(a, "e"), places)
	end
	if l == 1 then return decimalPlaces(dprop(a, "m"), places) .. "e" .. decimalPlaces(dprop(a, "e"), places) end
	if l <= 5 then return (if s == -1 then "-" else "") .. srep("e", l) .. decimalPlaces(m, places) end
	return (if s == -1 then "-" else "") .. "(e^" .. l .. ")" .. decimalPlaces(m, places)
end
function DP.toFixed(a, places)
	local s, l, m = comps(a.v)
	if l == 0 then return toFixed(s * m, places) end
	return DP.toStringWithDecimalPlaces(a, places)
end
function DP.toPrecision(a, places)
	local e = dprop(a, "e")
	if e <= -7 then return DP.toStringWithDecimalPlaces(a, places - 1) end
	if places > e then return DP.toFixed(a, places - e - 1) end
	return DP.toStringWithDecimalPlaces(a, places - 1)
end

-- static Decimal
local Decimal = {}
JS.Decimal = Decimal
for _, name in { "add", "sub", "mul", "div", "pow", "max", "min", "cmp", "gte", "gt", "lte", "lt", "eq", "log", "root", "tetrate", "slog", "plus", "minus", "times" } do
	Decimal[name] = function(a, ...) return DP[name](D(a), ...) end
end
for _, name in { "log10", "ln", "log2", "exp", "sqrt", "cbrt", "floor", "ceil", "round", "abs", "neg", "recip", "toNumber" } do
	Decimal[name] = function(a) return DP[name](D(a)) end
end
Decimal.fromValue = function(x) return D(x) end
Decimal.fromNumber = Decimal.fromValue
Decimal.fromString = Decimal.fromValue
Decimal.dZero, Decimal.dOne, Decimal.dTen = mk(0), mk(1), mk(10)
Decimal.dInf, Decimal.dNegInf, Decimal.dNaN = mk(huge), mk(-huge), mk(0 / 0)
Decimal.dInf.be = BEcore.NN(1, huge, huge)
Decimal.dNegInf.be = BEcore.NN(-1, huge, huge)
Decimal.dNegOne = mk(-1)
Decimal.affordGeometricSeries = function(res, start, ratio, cur) return mk(TN.affordGeometricSeries(V(res), V(start), V(ratio), V(cur))) end
Decimal.sumGeometricSeries = function(n, start, ratio, cur) return mk(TN.sumGeometricSeries(V(n), V(start), V(ratio), V(cur))) end
Decimal.affordArithmeticSeries = function(res, start, add, cur) return mk(TN.affordArithmeticSeries(V(res), V(start), V(add), V(cur))) end
Decimal.sumArithmeticSeries = function(n, start, add, cur) return mk(TN.sumArithmeticSeries(V(n), V(start), V(add), V(cur))) end
Decimal.isNaN = function(x) return TN.isNaN(V(x)) end

-- ------------------------------------------------------------------ JS core semantics
-- JS null: a real value (object keys can hold it, unlike nil). Falsy, == undefined, typeof "object".
local NULL = setmetatable({}, { __index = function() return nil end, __tostring = function() return "null" end, __jsnull = true })
JS.NULL = NULL
function JS.isnil(x) return x == nil or x == NULL end
function JS.t(x)
	if x == nil or x == false or x == 0 or x == "" or x == NULL then return false end
	if x ~= x then return false end
	return true
end
local truthy = JS.t

function JS.k(k)
	local t = type(k)
	if t == "number" then return k end
	if t == "string" then
		-- canonical integer strings ("0", "11", "-3", no leading zeros) are number keys
		local b = sbyte(k, 1)
		if b and ((b >= 49 and b <= 57) or (b == 48 and #k == 1) or (b == 45 and #k > 1 and sbyte(k, 2) ~= 48)) and #k <= 15
			and not sfind(k, "[^%d]", if b == 45 then 2 else 1) then
			return tonumber(k)
		end
		return k
	end
	if k == nil then return "undefined" end
	if t == "boolean" then return tostring(k) end
	if isD(k) then return JS.k(DP.toString(k)) end
	if t == "table" and LEN[k] then return JS.k(JS.str(k)) end   -- obj[[14]] is obj["14"]
	return k
end

-- loop guards the transpiler puts in (see js2lua guard / forStmt)
function JS.runaway() error("the game got stuck in a loop that never ends", 2) end
function JS.cap(s, l, step)
	if type(s) == "number" and type(l) == "number" and (l - s) / step > 5e6 then JS.runaway() end
	return l
end

function JS.len(x)
	local n = LEN[x]
	if n then return n end
	local t = type(x)
	if t == "string" then return utf8.len(x) or #x end
	if t == "table" then return rawget(x, "length") end
	if t == "function" then return 0 end
	error("Cannot read properties of " .. tostring(x) .. " (reading 'length')", 2)
end
function JS.setlen(a, n)
	KC[a] = nil
	local cur = LEN[a]
	if cur then for i = n, cur - 1 do a[i] = nil end LEN[a] = n return end
	a.length = n
end

function JS.A(n, ...)
	local t = {}
	for i = 1, n do t[i - 1] = (select(i, ...)) end
	LEN[t] = n
	return t
end
local function newArr(list, n) -- 1-based lua list -> JS array
	local t = {}
	n = n or #list
	for i = 1, n do t[i - 1] = list[i] end
	LEN[t] = n
	return t
end
JS.newArr = newArr
local function toList(a) -- JS array -> 1-based list
	local n = LEN[a] or 0
	local l = table.create(n)
	for i = 0, n - 1 do l[i + 1] = a[i] end
	return l, n
end
JS.toList = toList
function JS.isArray(x) return LEN[x] ~= nil end

function JS.O(t, order)
	if order then ORDER[t] = table.clone(order) end
	return t
end
function JS.set(o, k, v)
	local n = LEN[o]
	if n and type(k) == "number" then
		if k >= n then LEN[o] = k + 1 end
		if (rawget(o, k) == nil) ~= (v == nil) then KC[o] = nil end
		o[k] = v
		return
	end
	if type(o) == "table" and (rawget(o, k) == nil) ~= (v == nil) then KC[o] = nil end
	if type(k) == "string" and v ~= nil and rawget(o, k) == nil and type(o) == "table" then
		local ord = ORDER[o]
		if not ord then ord = {}; ORDER[o] = ord end
		ord[#ord + 1] = k
	end
	o[k] = v
end
JS.setk = JS.set

local function sortedKeys(o)
	local nums, strs, seen = {}, {}, {}
	local ord = ORDER[o]
	if ord then
		for _, k in ord do
			if not seen[k] and rawget(o, k) ~= nil then seen[k] = true; strs[#strs + 1] = k end
		end
	end
	local rest = {}
	for k, v in pairs(o) do
		local tk = type(k)
		if tk == "number" then nums[#nums + 1] = k
		elseif tk == "string" and not seen[k] then rest[#rest + 1] = k end
	end
	tsort(nums)
	tsort(rest)
	local out = nums
	for _, k in strs do out[#out + 1] = k end
	for _, k in rest do out[#out + 1] = k end
	return out
end
function JS.keylist(o)
	if o == nil then return {} end
	if type(o) == "string" then local l = {}; for i = 0, #o - 1 do l[i + 1] = i end return l end
	if type(o) ~= "table" or isD(o) then return {} end
	return sortedKeys(o)
end
-- for-in over an array skips an index that is gone by the time the loop gets to it (the game splices arrays while
-- it walks them, e.g. adjustPopupTime); objects keep the fast path
local function liveIdx(st, i)
	local c, a = st[1], st[2]
	while true do
		i += 1
		local k = c[i]
		if k == nil then return nil end
		if type(k) == "number" then
			if k < (LEN[a] or 0) then return i, k end
		elseif rawget(a, k) ~= nil then return i, k end
	end
end
function JS.keys(o)
	if type(o) == "table" then
		local c = KC[o]
		if c == nil then c = JS.keylist(o); KC[o] = c end
		if LEN[o] then return liveIdx, { c, o }, 0 end
		return ipairs(c)
	end
	return ipairs(JS.keylist(o))
end
JS.KC = KC
function JS.vals(o)
	local n = LEN[o]
	if n then local l = {}; for i = 0, n - 1 do l[i + 1] = o[i] end return ipairs(l) end
	if type(o) == "string" then local l = {}; for i = 1, #o do l[i] = ssub(o, i, i) end return ipairs(l) end
	error("not iterable")
end

local function str(x)
	local t = type(x)
	if t == "string" then return x end
	if x == NULL then return "null" end
	if t == "number" then return numToString(x) end
	if x == nil then return "undefined" end
	if t == "boolean" then return if x then "true" else "false" end
	if t == "function" then return "function" end
	if isD(x) then return DP.toString(x) end
	if LEN[x] then
		local l, n = toList(x)
		for i = 1, n do l[i] = if l[i] == nil then "" else str(l[i]) end
		return tconcat(l, ",", 1, n)
	end
	if t == "table" and rawget(x, "toString") then return x:toString() end
	return "[object Object]"
end
JS.str = str

local function tonum(x)
	local t = type(x)
	if t == "number" then return x end
	if t == "string" then
		local s = string.match(x, "^%s*(.-)%s*$")
		if s == "" then return 0 end
		if s == "Infinity" or s == "+Infinity" then return huge end
		if s == "-Infinity" then return -huge end
		local n = tonumber(s)
		if n == nil or string.find(s, "^0[xX]") == nil and string.find(s, "[^%d%.eE%+%-]") then return if n and not string.find(s, "[^%d%.eE%+%-xX]") then n else 0 / 0 end
		return n
	end
	if t == "boolean" then return if x then 1 else 0 end
	if x == nil then return 0 / 0 end
	if x == NULL then return 0 end
	if isD(x) then return tonum(DP.toString(x)) end
	if LEN[x] then local n = LEN[x]; if n == 0 then return 0 end if n == 1 then return tonum(x[0]) end end
	return 0 / 0
end
JS.tonum = tonum

function JS.add(a, b)
	local ta, tb = type(a), type(b)
	if ta == "number" and tb == "number" then return a + b end
	if ta == "string" or tb == "string" or ta == "table" or tb == "table" then return str(a) .. str(b) end
	return tonum(a) + tonum(b)
end

function JS.eq(a, b)
	if a == b then return true end
	if (a == nil or a == NULL) and (b == nil or b == NULL) then return true end
	local ta, tb = type(a), type(b)
	if ta == tb then return false end
	if (ta == "number" and tb == "string") or (ta == "string" and tb == "number") then return tonum(a) == tonum(b) end
	-- a Decimal against a primitive compares its valueOf (its string), as JS does (pm's exponent: points == 14)
	if ta == "table" and (tb == "number" or tb == "string") and isD(a) then return JS.eq(DP.toString(a), b) end
	if tb == "table" and (ta == "number" or ta == "string") and isD(b) then return JS.eq(a, DP.toString(b)) end
	return false
end

function JS.cmp(a, op, b)
	if type(a) == "string" and type(b) == "string" then
		if op == "<" then return a < b elseif op == ">" then return a > b elseif op == "<=" then return a <= b else return a >= b end
	end
	local x, y = tonum(a), tonum(b)
	if op == "<" then return x < y elseif op == ">" then return x > y elseif op == "<=" then return x <= y else return x >= y end
end

function JS.typeof(x)
	local t = type(x)
	if t == "nil" then return "undefined" end
	if t == "table" then
		local mt = getmetatable(x)
		if mt and mt.__call and mt.__jsfunc then return "function" end
		return "object"
	end
	return t
end

function JS.has(o, k) if type(o) ~= "table" then return false end return o[JS.k(k)] ~= nil end
function JS.and_(a, f) if truthy(a) then return f() end return a end
function JS.or_(a, f) if truthy(a) then return a end return f() end
function JS.nc(a, f) if a == nil or a == NULL then return f() end return a end

function JS.mc(o, k, ...)
	local f = o[k]
	if f == nil then error("TypeError: " .. str(k) .. " is not a function", 2) end
	return f(o, ...)
end

-- ------------------------------------------------------------------ regex (only the two this game uses)
function JS.re(p, flags) return { __re = p, flags = flags } end
local function commafy(s) -- /(\d)(?=(\d\d\d)+(?!\d))/g -> "$1,"
	local out, n = {}, #s
	-- apply to every digit run
	local i = 1
	while i <= n do
		local a, b = sfind(s, "%d+", i)
		if not a then out[#out + 1] = ssub(s, i); break end
		out[#out + 1] = ssub(s, i, a - 1)
		local run = ssub(s, a, b)
		local L = #run
		local parts = {}
		local first = L % 3
		if first == 0 then first = 3 end
		parts[1] = ssub(run, 1, first)
		for j = first + 1, L, 3 do parts[#parts + 1] = ssub(run, j, j + 2) end
		out[#out + 1] = tconcat(parts, ",")
		i = b + 1
	end
	return tconcat(out)
end

-- ------------------------------------------------------------------ builtin methods (array / string / number / function)
local function stableSort(list, n, cmp)
	-- merge sort (JS sort is stable)
	if n < 2 then return list end
	local tmp = table.create(n)
	local width = 1
	local src, dst = list, tmp
	while width < n do
		local i = 1
		while i <= n do
			local mid = math.min(i + width, n + 1)
			local hi = math.min(i + 2 * width, n + 1)
			local a, b, k = i, mid, i
			while a < mid and b < hi do
				if cmp(src[b], src[a]) then dst[k] = src[b]; b += 1 else dst[k] = src[a]; a += 1 end
				k += 1
			end
			while a < mid do dst[k] = src[a]; a += 1; k += 1 end
			while b < hi do dst[k] = src[b]; b += 1; k += 1 end
			i += 2 * width
		end
		src, dst = dst, src
		width *= 2
	end
	return src
end

local AM = {}  -- array methods
function AM.push(a, ...) KC[a] = nil;
	local n = LEN[a]
	for i = 1, select("#", ...) do a[n] = (select(i, ...)); n += 1 end
	LEN[a] = n
	return n
end
function AM.pop(a) KC[a] = nil; local n = LEN[a]; if n == 0 then return nil end local v = a[n - 1]; a[n - 1] = nil; LEN[a] = n - 1; return v end
function AM.shift(a) KC[a] = nil;
	local n = LEN[a]; if n == 0 then return nil end
	local v = a[0]
	for i = 1, n - 1 do a[i - 1] = a[i] end
	a[n - 1] = nil; LEN[a] = n - 1
	return v
end
function AM.unshift(a, ...) KC[a] = nil;
	local c = select("#", ...)
	local n = LEN[a]
	for i = n - 1, 0, -1 do a[i + c] = a[i] end
	for i = 1, c do a[i - 1] = (select(i, ...)) end
	LEN[a] = n + c
	return n + c
end
-- a number also finds its string: the port's for-in keys are numbers where JS has strings (a milestone's this.id is
-- 3, JS "3"), and the game looks those ids up in lists of strings (player.m.pseudoBuys.includes(this.id))
function AM.includes(a, v)
	local n = LEN[a]
	local vs = if type(v) == "number" then str(v) else nil
	for i = 0, n - 1 do
		local x = a[i]
		if x == v or (x ~= x and v ~= v) or (vs ~= nil and x == vs) then return true end
	end
	return false
end
function AM.indexOf(a, v) local n = LEN[a]; for i = 0, n - 1 do if a[i] == v then return i end end return -1 end
function AM.lastIndexOf(a, v) for i = LEN[a] - 1, 0, -1 do if a[i] == v then return i end end return -1 end
function AM.join(a, sep)
	if sep == nil then sep = "," end
	local l, n = toList(a)
	for i = 1, n do l[i] = if l[i] == nil then "" else str(l[i]) end
	return tconcat(l, sep, 1, n)
end
AM.toString = function(a) return AM.join(a) end
local function relIdx(i, n, def)
	if i == nil then return def end
	i = tonum(i)
	if i ~= i then return 0 end
	i = if i < 0 then math.max(n + i, 0) else math.min(i, n)
	return floor(i)
end
function AM.slice(a, s, e)
	local n = LEN[a]
	s, e = relIdx(s, n, 0), relIdx(e, n, n)
	local out, k = {}, 0
	for i = s, e - 1 do out[k] = a[i]; k += 1 end
	LEN[out] = math.max(k, 0)
	return out
end
function AM.splice(a, s, dc, ...) KC[a] = nil;
	local n = LEN[a]
	s = relIdx(s, n, 0)
	if dc == nil then dc = n - s end
	dc = math.max(0, math.min(floor(tonum(dc)), n - s))
	local removed = {}
	for i = 0, dc - 1 do removed[i] = a[s + i] end
	LEN[removed] = dc
	local ins = select("#", ...)
	local l = toList(a)
	local nl = {}
	for i = 1, s do nl[#nl + 1] = l[i] end
	for i = 1, ins do nl[#nl + 1] = (select(i, ...)) end
	for i = s + dc + 1, n do nl[#nl + 1] = l[i] end
	local nn = s + ins + (n - s - dc)
	for i = 0, math.max(n, nn) - 1 do a[i] = nl[i + 1] end
	LEN[a] = nn
	return removed
end
function AM.sort(a, cmpf) KC[a] = nil;
	local l, n = toList(a)
	local less
	if cmpf then less = function(x, y) return tonum(cmpf(nil, x, y)) < 0 end
	else less = function(x, y) return str(x) < str(y) end end
	l = stableSort(l, n, less)
	for i = 1, n do a[i - 1] = l[i] end
	return a
end
function AM.reverse(a) KC[a] = nil; local l, n = toList(a); for i = 1, n do a[i - 1] = l[n - i + 1] end return a end
function AM.map(a, f) local n = LEN[a]; local out = {}; for i = 0, n - 1 do out[i] = f(nil, a[i], i, a) end LEN[out] = n; return out end
function AM.filter(a, f) local n = LEN[a]; local out, k = {}, 0; for i = 0, n - 1 do if truthy(f(nil, a[i], i, a)) then out[k] = a[i]; k += 1 end end LEN[out] = k; return out end
function AM.forEach(a, f) local n = LEN[a]; for i = 0, n - 1 do f(nil, a[i], i, a) end end
function AM.find(a, f) local n = LEN[a]; for i = 0, n - 1 do if truthy(f(nil, a[i], i, a)) then return a[i] end end return nil end
function AM.findIndex(a, f) local n = LEN[a]; for i = 0, n - 1 do if truthy(f(nil, a[i], i, a)) then return i end end return -1 end
function AM.some(a, f) local n = LEN[a]; for i = 0, n - 1 do if truthy(f(nil, a[i], i, a)) then return true end end return false end
function AM.every(a, f) local n = LEN[a]; for i = 0, n - 1 do if not truthy(f(nil, a[i], i, a)) then return false end end return true end
function AM.reduce(a, f, ...)
	local n = LEN[a]
	local i, acc = 0, nil
	if select("#", ...) > 0 then acc = (...) else acc = a[0]; i = 1 end
	while i < n do acc = f(nil, acc, a[i], i, a); i += 1 end
	return acc
end
function AM.concat(a, ...)
	local l, n = toList(a)
	for j = 1, select("#", ...) do
		local b = select(j, ...)
		if LEN[b] then local bl, bn = toList(b); for i = 1, bn do n += 1; l[n] = bl[i] end
		else n += 1; l[n] = b end
	end
	return newArr(l, n)
end
function AM.fill(a, v, s, e) KC[a] = nil; local n = LEN[a]; s, e = relIdx(s, n, 0), relIdx(e, n, n); for i = s, e - 1 do a[i] = v end return a end

local SM = {}  -- string methods
local function plainFind(s, sub, init) return sfind(s, sub, init, true) end
function SM.includes(s, sub) return plainFind(s, str(sub), 1) ~= nil end
function SM.indexOf(s, sub, from) local a = plainFind(s, str(sub), (from or 0) + 1); return if a then a - 1 else -1 end
function SM.startsWith(s, p) return ssub(s, 1, #p) == p end
function SM.endsWith(s, p) return p == "" or ssub(s, -#p) == p end
function SM.toUpperCase(s) return supper(s) end
function SM.toLowerCase(s) return slower(s) end
function SM.trim(s) return (string.match(s, "^%s*(.-)%s*$")) end
function SM.charAt(s, i) i = floor(tonum(i or 0)); return ssub(s, i + 1, i + 1) end
function SM.charCodeAt(s, i) return sbyte(s, floor(tonum(i or 0)) + 1) or (0 / 0) end
function SM.rep(s, n) return srep(s, floor(tonum(n))) end
SM["repeat"] = SM.rep
function SM.slice(s, a, b)
	local n = #s
	a, b = relIdx(a, n, 0), relIdx(b, n, n)
	if b <= a then return "" end
	return ssub(s, a + 1, b)
end
function SM.substring(s, a, b)
	local n = #s
	a = math.max(0, math.min(floor(tonum(a or 0)), n)); b = if b == nil then n else math.max(0, math.min(floor(tonum(b)), n))
	if a > b then a, b = b, a end
	return ssub(s, a + 1, b)
end
function SM.substr(s, a, len) local n = #s; a = relIdx(a, n, 0); len = if len == nil then n - a else floor(len); return ssub(s, a + 1, a + len) end
function SM.padStart(s, len, fill) fill = fill or " "; while #s < len do s = fill .. s end return ssub(s, -len) end
function SM.padEnd(s, len, fill) fill = fill or " "; while #s < len do s = s .. fill end return ssub(s, 1, len) end
function SM.toString(s) return s end
SM.valueOf = SM.toString
function SM.split(s, sep)
	if sep == nil then return newArr({ s }, 1) end
	local out = {}
	if sep == "" then for i = 1, #s do out[i] = ssub(s, i, i) end return newArr(out, #s) end
	local i = 1
	while true do
		local a, b = plainFind(s, sep, i)
		if not a then out[#out + 1] = ssub(s, i); break end
		out[#out + 1] = ssub(s, i, a - 1)
		i = b + 1
	end
	return newArr(out, #out)
end
function SM.replace(s, pat, rep)
	if type(pat) == "table" and pat.__re then
		if pat.__re == "(\\d)(?=(\\d\\d\\d)+(?!\\d))" then return commafy(s) end
		if pat.__re == "([^(?:e|F)]*)$" then
			-- '-$1': put a minus in front of the trailing run of characters that are none of ( ? : e | F )
			local i = #s
			while i >= 1 do
				local c = ssub(s, i, i)
				if c == "(" or c == "?" or c == ":" or c == "e" or c == "|" or c == "F" or c == ")" then break end
				i -= 1
			end
			return ssub(s, 1, i) .. "-" .. ssub(s, i + 1)
		end
		error("unsupported regex " .. pat.__re)
	end
	pat = str(pat)
	local a, b = plainFind(s, pat, 1)
	if not a then return s end
	local r = if type(rep) == "function" then str(rep(nil, pat)) else str(rep)
	return ssub(s, 1, a - 1) .. r .. ssub(s, b + 1)
end
function SM.concat(s, ...) local out = s; for i = 1, select("#", ...) do out ..= str((select(i, ...))) end return out end

local NM = {}  -- number methods
NM.toFixed = function(x, f) return toFixed(x, f) end
NM.toPrecision = function(x, p) if p == nil then return numToString(x) end return toPrecision(x, p) end
NM.toString = function(x, radix)
	if radix == nil or radix == 10 then return numToString(x) end
	local n, digits, neg = floor(abs(x)), {}, x < 0
	if n == 0 then return "0" end
	local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
	while n > 0 do local d = n % radix; tinsert(digits, 1, ssub(chars, d + 1, d + 1)); n = floor(n / radix) end
	return (if neg then "-" else "") .. tconcat(digits)
end
NM.toLocaleString = function(x) return commafy(numToString(x)) end
NM.valueOf = function(x) return x end

local FM = {}  -- function methods
function FM.bind(f, thisArg, ...)
	local bound = table.pack(...)
	if bound.n == 0 then return function(_, ...) return f(thisArg, ...) end end
	return function(_, ...)
		local args = table.pack(...)
		local all = table.create(bound.n + args.n)
		for i = 1, bound.n do all[i] = bound[i] end
		for i = 1, args.n do all[bound.n + i] = args[i] end
		return f(thisArg, table.unpack(all, 1, bound.n + args.n))
	end
end
function FM.call(f, thisArg, ...) return f(thisArg, ...) end
function FM.apply(f, thisArg, arr) if arr == nil then return f(thisArg) end local l, n = toList(arr); return f(thisArg, table.unpack(l, 1, n)) end
FM.toString = function() return "function" end

function JS.m(o, name, ...)
	local t = type(o)
	if t == "table" then
		if LEN[o] then
			local f = AM[name]
			if f then return f(o, ...) end
		end
		local mt = getmetatable(o)
		if mt == DMT then
			local f = DP[name]
			if f then return f(o, ...) end
			error("Decimal has no method " .. name, 2)
		end
		local f = rawget(o, name)
		if f ~= nil then return f(o, ...) end
		if name == "hasOwnProperty" then return rawget(o, JS.k((...))) ~= nil end
		if name == "toString" then return str(o) end
		if name == "valueOf" then return o end
		if name == "toFixed" or name == "toPrecision" then return NM[name](tonum(o), ...) end
		error("TypeError: o." .. name .. " is not a function", 2)
	elseif t == "string" then
		local f = SM[name]
		if f then return f(o, ...) end
	elseif t == "number" then
		local f = NM[name]
		if f then return f(o, ...) end
	elseif t == "function" then
		local f = FM[name]
		if f then return f(o, ...) end
	elseif t == "boolean" then
		if name == "toString" then return str(o) end
	end
	error("TypeError: " .. str(o) .. "." .. name .. " is not a function", 2)
end

-- ------------------------------------------------------------------ globals the game touches
local G = {}
JS.G = G

local function callable(tbl, f) tbl.__jsfunc = true; return setmetatable(tbl, { __call = f, __jsfunc = true }) end

local seed = 12345
local JMath = {
	PI = math.pi, E = math.exp(1), LN10 = math.log(10), LN2 = math.log(2), LOG10E = 1 / math.log(10), LOG2E = 1 / math.log(2), SQRT2 = math.sqrt(2),
	floor = function(x) return floor(tonum(x)) end,
	ceil = function(x) return math.ceil(tonum(x)) end,
	round = function(x) x = tonum(x); return floor(x + 0.5) end,
	trunc = function(x) x = tonum(x); if x < 0 then return math.ceil(x) end return floor(x) end,
	abs = function(x) return abs(tonum(x)) end,
	sign = function(x) x = tonum(x); if x > 0 then return 1 elseif x < 0 then return -1 end return x end,
	pow = function(a, b) a, b = tonum(a), tonum(b); if b ~= b then return 0 / 0 end if b == 0 then return 1 end return a ^ b end,
	sqrt = function(x) x = tonum(x); if x < 0 then return 0 / 0 end return math.sqrt(x) end,
	cbrt = function(x) x = tonum(x); if x < 0 then return -((-x) ^ (1 / 3)) end return x ^ (1 / 3) end,
	exp = function(x) return math.exp(tonum(x)) end,
	log = function(x) x = tonum(x); if x < 0 then return 0 / 0 end return math.log(x) end,
	log10 = function(x) x = tonum(x); if x < 0 then return 0 / 0 end return math.log10(x) end,
	log2 = function(x) x = tonum(x); if x < 0 then return 0 / 0 end return math.log(x, 2) end,
	sin = function(x) return math.sin(tonum(x)) end, cos = function(x) return math.cos(tonum(x)) end, tan = function(x) return math.tan(tonum(x)) end,
	atan = function(x) return math.atan(tonum(x)) end, atan2 = function(y, x) return math.atan2(tonum(y), tonum(x)) end,
	hypot = function(a, b) return math.sqrt(tonum(a) ^ 2 + tonum(b) ^ 2) end,
	max = function(...)
		local r = -huge
		for i = 1, select("#", ...) do local v = tonum((select(i, ...))); if v ~= v then return 0 / 0 end if v > r then r = v end end
		return r
	end,
	min = function(...)
		local r = huge
		for i = 1, select("#", ...) do local v = tonum((select(i, ...))); if v ~= v then return 0 / 0 end if v < r then r = v end end
		return r
	end,
	random = function() seed = fmod(seed * 1103515245 + 12345, 2147483648); return seed / 2147483648 end,
}
JS.Math = JMath
function JS.seed(s) seed = s end

local Date = { now = function() return JS.NOW end }
JS.DateCtor = Date

local Object = {
	keys = function(o) local l = JS.keylist(o); for i, k in l do l[i] = if type(k) == "number" then numToString(k) else k end return newArr(l, #l) end,
	values = function(o) local l = JS.keylist(o); for i, k in l do l[i] = o[k] end return newArr(l, #l) end,
	entries = function(o) local l = JS.keylist(o); for i, k in l do l[i] = JS.A(2, if type(k) == "number" then numToString(k) else k, o[k]) end return newArr(l, #l) end,
	assign = function(t, ...)
		for i = 1, select("#", ...) do
			local s = select(i, ...)
			if s ~= nil then for _, k in JS.keylist(s) do JS.set(t, k, s[k]) end end
		end
		return t
	end,
	freeze = function(o) return o end,
	getOwnPropertyNames = function(o) return G.Object.keys(o) end,
}

local function isNaNf(x) local n = tonum(x); return n ~= n end
local Number = callable({
	isFinite = function(x) return type(x) == "number" and x == x and abs(x) ~= huge end,
	isNaN = function(x) return type(x) == "number" and x ~= x end,
	isInteger = function(x) return type(x) == "number" and x == floor(x) and abs(x) ~= huge end,
	parseFloat = function(x) return G.parseFloat(nil, x) end,
	MAX_VALUE = 1.7976931348623157e308, MIN_VALUE = 5e-324, MAX_SAFE_INTEGER = 9007199254740991, EPSILON = 2 ^ -52,
	POSITIVE_INFINITY = huge, NEGATIVE_INFINITY = -huge, NaN = 0 / 0,
}, function(_, _this, x) if x == nil then return 0 end return tonum(x) end)
local String = callable({}, function(_, _this, x) return str(x) end)
local Boolean = callable({}, function(_, _this, x) return truthy(x) end)
local Array = callable({ isArray = function(x) return LEN[x] ~= nil end, from = function(x) local l, n = toList(x); return newArr(l, n) end },
	function(_, _this, n) local a = {}; LEN[a] = n or 0; return a end)

-- JSON (save strings)
local function jsonEnc(v, out)
	local t = type(v)
	if v == nil or v == NULL then out[#out + 1] = "null"
	elseif t == "boolean" then out[#out + 1] = tostring(v)
	elseif t == "number" then out[#out + 1] = if v ~= v or abs(v) == huge then "null" else numToString(v)
	elseif t == "string" then out[#out + 1] = '"' .. string.gsub(v, '[%c"\\]', function(c)
			if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n"
			elseif c == "\t" then return "\\t" elseif c == "\r" then return "\\r" elseif c == "\b" then return "\\b" elseif c == "\f" then return "\\f" end
			return sfmt("\\u%04x", sbyte(c))
		end) .. '"'
	elseif isD(v) then jsonEnc(DP.toString(v), out)
	elseif LEN[v] then
		out[#out + 1] = "["
		for i = 0, LEN[v] - 1 do if i > 0 then out[#out + 1] = "," end jsonEnc(v[i], out) end
		out[#out + 1] = "]"
	elseif t == "table" then
		out[#out + 1] = "{"
		local first = true
		for _, k in JS.keylist(v) do
			local x = v[k]
			if x ~= nil and type(x) ~= "function" then
				if not first then out[#out + 1] = "," end
				first = false
				jsonEnc(if type(k) == "number" then numToString(k) else k, out)
				out[#out + 1] = ":"
				jsonEnc(x, out)
			end
		end
		out[#out + 1] = "}"
	else out[#out + 1] = "null" end
end
local JSON = {
	stringify = function(v) local out = {}; jsonEnc(v, out); return tconcat(out) end,
	parse = function(s)
		local pos = 1
		local function ws() pos = sfind(s, "[^%s]", pos) or #s + 1 end
		local val
		local function strv()
			local out = {}
			pos += 1
			while true do
				local c = ssub(s, pos, pos)
				if c == '"' then pos += 1; break end
				if c == "\\" then
					local e = ssub(s, pos + 1, pos + 1)
					if e == "u" then out[#out + 1] = utf8.char(tonumber(ssub(s, pos + 2, pos + 5), 16)); pos += 6
					else out[#out + 1] = ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[e] or e; pos += 2 end
				else out[#out + 1] = c; pos += 1 end
			end
			return tconcat(out)
		end
		function val()
			ws()
			local c = ssub(s, pos, pos)
			if c == "{" then
				local o = {}
				pos += 1; ws()
				if ssub(s, pos, pos) == "}" then pos += 1 return o end
				while true do
					ws()
					local k = JS.k(strv())
					ws(); pos += 1
					JS.set(o, k, val())
					ws()
					local d = ssub(s, pos, pos); pos += 1
					if d == "}" then return o end
				end
			elseif c == "[" then
				local l = {}
				pos += 1; ws()
				if ssub(s, pos, pos) == "]" then pos += 1 return newArr(l, 0) end
				local n = 0
				while true do
					n += 1; l[n] = val(); ws()
					local d = ssub(s, pos, pos); pos += 1
					if d == "]" then return newArr(l, n) end
				end
			elseif c == '"' then return strv()
			elseif ssub(s, pos, pos + 3) == "true" then pos += 4 return true
			elseif ssub(s, pos, pos + 4) == "false" then pos += 5 return false
			elseif ssub(s, pos, pos + 3) == "null" then pos += 4 return NULL
			else
				local a, b = sfind(s, "^%-?[%d%.eE%+%-]+", pos)
				pos = b + 1
				return tonumber(ssub(s, a, b))
			end
		end
		return val()
	end,
}

local stub
stub = setmetatable({}, { __index = function() return stub end, __call = function() return stub end, __newindex = function() end })

G.Math, G.Decimal, G.Object, G.JSON, G.Number, G.String, G.Boolean, G.Array, G.Date = JMath, Decimal, Object, JSON, Number, String, Boolean, Array, Date
G.console = { log = function(...) print(...) end, warn = function(...) print(...) end, error = function(...) print(...) end }
G.isNaN = function(_, x) return isNaNf(x) end
G.isFinite = function(_, x) local n = tonum(x); return n == n and abs(n) ~= huge end
G.parseFloat = function(_, x)
	if type(x) == "number" then return x end
	return jsParseFloat(str(x))
end
G.parseInt = function(_, x) local n = G.parseFloat(nil, x); if n ~= n then return n end return if n < 0 then math.ceil(n) else floor(n) end
G.localStorage = { getItem = function() return nil end, setItem = function() end, removeItem = function() end }
G.document, G.window, G.navigator = stub, stub, stub
G.Vue = { set = function(o, k, v) JS.set(o, k, v) end, component = function() end, delete = function(o, k) o[k] = nil end }
G.setInterval = function() return 0 end
G.setTimeout = function() return 0 end
G.clearInterval = function() end
G.alert = function() end
G.confirm = function() return true end
G.prompt = function() return nil end

function JS.new(C, ...)
	if C == Date then return { getTime = function() return JS.NOW end } end
	if C == Decimal then return D((...)) end
	if C == Array then return Array(nil, ...) end
	if type(C) == "function" then local o = {}; C(o, ...); return o end
	error("cannot construct")
end
function JS.instanceof(x, C)
	if x == nil or x == NULL then return false end
	if C == Decimal then return isD(x) end
	if C == Array then return LEN[x] ~= nil end
	if C == Object then return type(x) == "table" end
	return false
end

Object.name, Decimal.name, Array.name, Number.name, String.name, Boolean.name = "Object", "Decimal", "Array", "Number", "String", "Boolean"
local FunctionCtor = { name = "Function" }
function JS.get(o, k)
	local t = type(o)
	if k == "constructor" then
		if t == "function" then return FunctionCtor end
		if t == "number" then return Number end
		if t == "string" then return String end
		if t == "boolean" then return Boolean end
		if t ~= "table" then return nil end
		if isD(o) then return Decimal end
		if LEN[o] then return Array end
		local c = rawget(o, "constructor")
		if c ~= nil then return c end
		return Object
	end
	if t == "function" then return FM[k] end
	if t ~= "table" then return nil end
	return o[k]
end

-- ------------------------------------------------------------------ environment for the transpiled chunks
local ENV = setmetatable({}, { __index = G })
ENV.JS = JS
ENV.math = math
ENV.bit32 = bit32
ENV.pcall = pcall
ENV.error = error
ENV.type = type
ENV.print = print
JS.ENV = ENV

-- TMT helpers whose JS versions depend on JS object internals
function JS.overrides()
	ENV.isFunction = function(_, f) return type(f) == "function" end
	ENV.isPlainObject = function(_, o) return type(o) == "table" and getmetatable(o) == nil and LEN[o] == nil end
	-- native versions of two per-tick TMT walkers (same behaviour, no JS-emulation overhead)
	local function updateTempData(_, layerData, tmpData, funcsData, useThis)
		for _, item in JS.keys(funcsData) do
			ENV.item = item
			local ld = layerData[item]
			local tl = type(ld)
			if tl == "table" then
				if LEN[ld] then
					if item ~= "tabFormat" and item ~= "content" then updateTempData(nil, ld, tmpData[item], funcsData[item], useThis) end
				elseif getmetatable(ld) == nil then
					updateTempData(nil, ld, tmpData[item], funcsData[item], useThis)
				end
			elseif tl == "function" and type(tmpData[item]) ~= "function" then
				local value
				if useThis ~= nil then value = ld(useThis) else value = ld(layerData) end
				JS.set(tmpData, item, value)
			end
		end
	end
	ENV.updateTempData = updateTempData
	local function NaNcheck(_, data)
		for _, item in JS.keys(data) do
			local v = data[item]
			if v == nil or v == NULL then
			elseif LEN[v] then NaNcheck(nil, v)
			elseif v ~= v or (isD(v) and TN.isNaN(v.v)) then
				if not ENV.NaNalert then
					ENV.NaNalert = true
					print("NaN in player: '" .. str(item) .. "'")
					return
				end
			elseif isD(v) then
			elseif type(v) == "table" and getmetatable(v) == nil then NaNcheck(nil, v)
			end
		end
	end
	ENV.NaNcheck = NaNcheck
	ENV.toNumber = function(_, x)   -- utils.js: Decimals convert, numbers stay, anything else goes through parseFloat
		if isD(x) then return DP.toNumber(x) end
		if type(x) == "number" then return x end
		return G.parseFloat(nil, x)
	end
end

return JS
end
