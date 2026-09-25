--!nocheck
-- BEcore: a line-for-line port of the component maths in the game's bundled break_eternity.js.
-- JSRT uses it only when a value is one of break_eternity's special forms (new Decimal(Infinity), Decimal.dInf,
-- and whatever arithmetic on them produces), where the old library's answers differ from any "correct" answer
-- and the game depends on them (e.g. Infinity-cost upgrades count as affordable once you have ee16).
-- Values are triples { s = sign, l = layer, m = mag }.
local abs, floor, log10, huge = math.abs, math.floor, math.log10, math.huge
local EXP_LIMIT = 9e15
local LAYER_DOWN = math.log10(9e15)
local FIRST_NEG_LAYER = 1 / 9e15
local MAX_SIG = 17

local BE = {}
local function sgn(x) if x > 0 then return 1 elseif x < 0 then return -1 elseif x == 0 then return 0 end return x end
local function finite(x) return x == x and x ~= huge and x ~= -huge end
local function pow10(x) return 10 ^ x end
BE.finite = finite

local function NN(s, l, m) return { s = s, l = l, m = m } end
local function normalize(t)
	if t.s == 0 or (t.m == 0 and t.l == 0) then t.s, t.m, t.l = 0, 0, 0; return t end
	if t.l == 0 and t.m < 0 then t.m = -t.m; t.s = -t.s end
	if t.l == 0 and t.m < FIRST_NEG_LAYER then t.l += 1; t.m = log10(t.m); return t end
	local absmag, signmag = abs(t.m), sgn(t.m)
	if absmag >= EXP_LIMIT then
		t.l += 1; t.m = signmag * log10(absmag); return t
	end
	while absmag < LAYER_DOWN and t.l > 0 do
		t.l -= 1
		if t.l == 0 then t.m = pow10(t.m)
		else t.m = signmag * pow10(absmag); absmag = abs(t.m); signmag = sgn(t.m) end
	end
	if t.l == 0 then
		if t.m < 0 then t.m = -t.m; t.s = -t.s
		elseif t.m == 0 then t.s = 0 end
	end
	return t
end
local function FC(s, l, m) return normalize(NN(s, l, m)) end
BE.NN, BE.FC, BE.normalize = NN, FC, normalize

local NaN = 0 / 0
local function dNaN() return NN(NaN, NaN, NaN) end
function BE.fromNumber(x)
	return normalize(NN(sgn(x), 0, abs(x)))
end

function BE.cmpabs(a, b)
	local la = if a.m > 0 then a.l else -a.l
	local lb = if b.m > 0 then b.l else -b.l
	if la > lb then return 1 end
	if la < lb then return -1 end
	if a.m > b.m then return 1 end
	if a.m < b.m then return -1 end
	return 0
end
function BE.cmp(a, b)
	if a.s > b.s then return 1 end
	if a.s < b.s then return -1 end
	return a.s * BE.cmpabs(a, b)
end
function BE.lt(a, b) return BE.cmp(a, b) == -1 end
function BE.gt(a, b) return BE.cmp(a, b) == 1 end
function BE.lte(a, b) return not BE.gt(a, b) end
function BE.gte(a, b) return not BE.lt(a, b) end
function BE.eq(a, b) return a.s == b.s and a.l == b.l and a.m == b.m end

function BE.neg(a) return NN(-a.s, a.l, a.m) end
function BE.abs(a) return NN(if a.s == 0 then 0 else 1, a.l, a.m) end

function BE.add(a0, b0)
	if not finite(a0.l) then return a0 end
	if not finite(b0.l) then return b0 end
	if a0.s == 0 then return b0 end
	if b0.s == 0 then return a0 end
	if a0.s == -b0.s and a0.l == b0.l and a0.m == b0.m then return NN(0, 0, 0) end
	if a0.l >= 2 or b0.l >= 2 then
		if BE.cmpabs(a0, b0) < 0 then return b0 end
		return a0
	end
	local a, b
	if BE.cmpabs(a0, b0) > 0 then a, b = a0, b0 else a, b = b0, a0 end
	if a.l == 0 and b.l == 0 then return BE.fromNumber(a.s * a.m + b.s * b.m) end
	local layera = a.l * sgn(a.m)
	local layerb = b.l * sgn(b.m)
	if layera - layerb >= 2 then return a end
	if layera == 0 and layerb == -1 then
		if abs(b.m - log10(a.m)) > MAX_SIG then return a end
		local magdiff = pow10(log10(a.m) - b.m)
		local mantissa = b.s + a.s * magdiff
		return FC(sgn(mantissa), 1, b.m + log10(abs(mantissa)))
	end
	if layera == 1 and layerb == 0 then
		if abs(a.m - log10(b.m)) > MAX_SIG then return a end
		local magdiff = pow10(a.m - log10(b.m))
		local mantissa = b.s + a.s * magdiff
		return FC(sgn(mantissa), 1, log10(b.m) + log10(abs(mantissa)))
	end
	if abs(a.m - b.m) > MAX_SIG then return a end
	local magdiff = pow10(a.m - b.m)
	local mantissa = b.s + a.s * magdiff
	return FC(sgn(mantissa), 1, b.m + log10(abs(mantissa)))
end
function BE.sub(a, b) return BE.add(a, BE.neg(b)) end

function BE.mul(a0, b0)
	if not finite(a0.l) then return a0 end
	if not finite(b0.l) then return b0 end
	if a0.s == 0 or b0.s == 0 then return NN(0, 0, 0) end
	if a0.l == b0.l and a0.m == -b0.m then return NN(a0.s * b0.s, 0, 1) end
	local a, b
	if a0.l > b0.l or (a0.l == b0.l and abs(a0.m) > abs(b0.m)) then a, b = a0, b0 else a, b = b0, a0 end
	if a.l == 0 and b.l == 0 then return BE.fromNumber(a.s * b.s * a.m * b.m) end
	if a.l >= 3 or (a.l - b.l >= 2) then return FC(a.s * b.s, a.l, a.m) end
	if a.l == 1 and b.l == 0 then return FC(a.s * b.s, 1, a.m + log10(b.m)) end
	if a.l == 1 and b.l == 1 then return FC(a.s * b.s, 1, a.m + b.m) end
	if (a.l == 2 and b.l == 1) or (a.l == 2 and b.l == 2) then
		local nm = BE.add(FC(sgn(a.m), a.l - 1, abs(a.m)), FC(sgn(b.m), b.l - 1, abs(b.m)))
		return FC(a.s * b.s, nm.l + 1, nm.s * nm.m)
	end
	return dNaN()   -- break_eternity throws here; nothing in the game reaches it
end
function BE.recip(a)
	if a.m == 0 then return dNaN() end
	if a.l == 0 then return FC(a.s, 0, 1 / a.m) end
	return FC(a.s, a.l, -a.m)
end
function BE.div(a, b) return BE.mul(a, BE.recip(b)) end

function BE.absLog10(a)
	if a.s == 0 then return dNaN() end
	if a.l > 0 then return FC(sgn(a.m), a.l - 1, abs(a.m)) end
	return FC(1, 0, log10(a.m))
end
function BE.log10(a)
	if a.s <= 0 then return dNaN() end
	if a.l > 0 then return FC(sgn(a.m), a.l - 1, abs(a.m)) end
	return FC(a.s, 0, log10(a.m))
end
function BE.ln(a)
	if a.s <= 0 then return dNaN() end
	if a.l == 0 then return FC(a.s, 0, math.log(a.m)) end
	if a.l == 1 then return FC(sgn(a.m), 0, abs(a.m) * 2.302585092994046) end
	if a.l == 2 then return FC(sgn(a.m), 1, abs(a.m) + 0.36221568869946325) end
	return FC(sgn(a.m), a.l - 1, abs(a.m))
end
function BE.log2(a)
	if a.s <= 0 then return dNaN() end
	if a.l == 0 then return FC(a.s, 0, math.log(a.m, 2)) end
	if a.l == 1 then return FC(sgn(a.m), 0, abs(a.m) * 3.321928094887362) end
	if a.l == 2 then return FC(sgn(a.m), 1, abs(a.m) + 0.5213902276543247) end
	return FC(sgn(a.m), a.l - 1, abs(a.m))
end
function BE.log(a, base)
	if a.s <= 0 then return dNaN() end
	if base.s <= 0 then return dNaN() end
	if base.s == 1 and base.l == 0 and base.m == 1 then return dNaN() end
	if a.l == 0 and base.l == 0 then return FC(a.s, 0, math.log(a.m) / math.log(base.m)) end
	return BE.div(BE.log10(a), BE.log10(base))
end

function BE.pow10(a)
	if not finite(a.l) or not finite(a.m) then return dNaN() end
	if a.l == 0 then
		local nm = 10 ^ (a.s * a.m)
		if finite(nm) and abs(nm) > 0.1 then return FC(1, 0, nm) end
		if a.s == 0 then return NN(1, 0, 1) end
		a = NN(a.s, a.l + 1, log10(a.m))
	end
	if a.s > 0 and a.m > 0 then return FC(a.s, a.l + 1, a.m) end
	if a.s < 0 and a.m > 0 then return FC(-a.s, a.l + 1, -a.m) end
	return NN(1, 0, 1)
end
function BE.toNumber(a)
	if not finite(a.l) then return NaN end
	if a.l == 0 then return a.s * a.m end
	if a.l == 1 then return a.s * 10 ^ a.m end
	if a.m > 0 then return if a.s > 0 then huge else -huge end
	return 0
end
function BE.pow(a, b)
	if a.s == 0 then if BE.eq(b, NN(0, 0, 0)) or b.s == 0 then return NN(1, 0, 1) end return a end
	if a.s == 1 and a.l == 0 and a.m == 1 then return a end
	if b.s == 0 then return NN(1, 0, 1) end
	if b.s == 1 and b.l == 0 and b.m == 1 then return a end
	local result = BE.pow10(BE.mul(BE.absLog10(a), b))
	if a.s == -1 and abs(math.fmod(BE.toNumber(b), 2)) == 1 then return BE.neg(result) end
	return result
end
function BE.root(a, b) return BE.pow(a, BE.recip(b)) end
function BE.sqrt(a)
	if a.l == 0 then local x = a.s * a.m; return BE.fromNumber(if x < 0 then NaN else math.sqrt(x)) end
	if a.l == 1 then return FC(1, 2, log10(a.m) - 0.3010299956639812) end
	local r = BE.div(NN(a.s, a.l - 1, a.m), NN(1, 0, 2))
	r = NN(r.s, r.l + 1, r.m)
	return normalize(r)
end
local function magRound(a, f)
	if a.m < 0 then return NN(0, 0, 0) end
	if a.l == 0 then return FC(a.s, 0, f(a.m)) end
	return a
end
function BE.floor(a) return magRound(a, floor) end
function BE.ceil(a) return magRound(a, math.ceil) end
function BE.round(a) return magRound(a, function(m) return floor(m + 0.5) end) end
function BE.exp(a)
	if a.m < 0 then return NN(1, 0, 1) end
	if a.l == 0 and a.m <= 709.7 then return BE.fromNumber(math.exp(a.s * a.m)) end
	if a.l == 0 then return FC(1, 1, a.s * log10(math.exp(1)) * a.m) end
	if a.l == 1 then return FC(1, 2, a.s * (log10(0.4342944819032518) + a.m)) end
	return FC(1, a.l + 1, a.s * a.m)
end
function BE.max(a, b) if BE.lt(a, b) then return b end return a end
function BE.min(a, b) if BE.gt(a, b) then return b end return a end

return BE
