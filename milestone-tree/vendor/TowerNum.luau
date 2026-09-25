--!native
--!optimize 2
--!strict
--[[
	TowerNum — big (and tiny) numbers for Luau, as fast as Luau goes: plain doubles, then towers of tens as tall as
	a double counts (10^^9e15), then the hyper tier all the way up to PowiainaNum's {10, 9e15, 1, 1, 1, 2}
	(pentation, 10{n}x arrows, expansion, multi-expansion, explosion, megotion), and the reciprocals of all of it.

	WHAT A TOWERNUM IS
	    A TowerNum is one of
	      * a plain Luau number (everything a double holds: 5.6e-309 .. 1.8e308),
	      * a TOWER, the table { l = layer, m = mag }, once the value no longer fits in a double:
	          layer >= 1   the value is  sign(mag) * 10^10^...^|mag|        with `layer` tens    (huge)
	          layer <= -1  the value is  sign(mag) / 10^10^...^|mag|        with `-layer` tens   (tiny)
	        up to 9,007,199,254,740,991 tens (2^53 - 1, the most a double counts exactly), or
	      * a HYPER value { l = +-2^62, m = +-1e300, h = <Hyper value> } past that: h is a PowiainaNum value
	        (TowerNum.Hyper, a tested port of PowiainaNum.js), l and m only say "past every tower" and the sign.
	    Small and medium values therefore cost exactly what a number costs: no table, no garbage, native maths.
	    Every function takes any kind (and strings, see TowerNum.from) and returns the canonical kind back.
	    Values are never changed after they are made: share them freely. When an answer IS one of the inputs
	    (a tower plus something too small to move it, a layer-2 tower times a double, the bigger of two), that
	    same table comes back, so a steady-state game tick allocates nothing it does not have to.

	    Canonical towers: |mag| >= LOG_MAX (308.25...), i.e. a table exists only when the value is past 1.8e308 or
	    under 5.6e-309 (1 / 1.8e308), and each layer's mag is past what the layer below could hold. So the value's
	    size orders by layer (hyper-tiny < -2 < -1 < plain < 1 < 2 < hyper) and then by mag, and comparing is a
	    layer and a mag check. Zero, infinities and NaN are always plain numbers.

	WHY { l, m } AND NO METATABLE
	    Measured (Luau -O2, native): a two-field table allocates in ~40 ns, a three-field one ~45 ns and either with
	    setmetatable ~60 ns — the allocation IS the cost of a tower op. So the sign lives in the mag, and towers have
	    no operator overloads: use the functions (a + b on two towers is an error, not a wrong answer). The fields
	    are named rather than [1], [2] so a tower can never be mistaken for a game's own two-element array.
	    The hyper tier sits behind the checks the tower paths already make (its layer is past every tower's), so
	    it costs the number and tower paths nothing.

	THE API (a, b: TowerNum | number | string)
	    arithmetic   add sub mul div pow neg abs recip sqrt cbrt root exp exp10 ln log10 log2 log(a, base)
	                 floor ceil round mod(only for plain numbers) max min clamp factorial gamma lambertw
	    towers+      tetrate10(h) slog10(a) tetrate(a, h, payload?) slog(a, base?) ssqrt arrow(a, n, b)
	                 pentate hexate anyarrowLog pentaLog iteratedLog expansion expansionArrow multiExpansion
	                 powerExpansion explosion megotion powiaination
	    buying       affordGeometricSeries sumGeometricSeries affordArithmeticSeries sumArithmeticSeries
	    comparing    cmp(a, b) -> -1 | 0 | 1   eq lt le gt ge   isZero isNaN isInf isTower isHyper sign
	    converting   from(x) toNumber(a) (clamps to +-inf / 0)   encode(a) / decode(v) (DataStore-safe)
	                 fromEN(t) / toEN(a) (EternityNum { Sign, Layer, Exp } tables)   sortKey(a) (OrderedDataStore)
	                 toHyper(a) / fromHyper(h) (PowiainaNum values)
	    showing      format(a, opts?) — see the FORMAT section; short(a) = format(a)

	SAFE WITH PLAYER INPUT
	    from/decode read any string in linear time (strings over 20,000 characters are refused), never recurse
	    on input, and give back a canonical value or a clean error. Nothing here touches a service, the network,
	    loadstring or the environment.

	Numbers past 1.8e308 need these functions: 1e308 * 10 with plain `*` is still inf.
]]

local TowerNum = {}

local log10, floor, abs, huge = math.log10, math.floor, math.abs, math.huge
local sfmt, srep, tostr = string.format, string.rep, tostring
local sfind, ssub, sbyte, sgsub, smatch = string.find, string.sub, string.byte, string.gsub, string.match

local MAX = 1.7976931348623157e308          -- the largest double
local LOG_MAX = 308.25471555991675          -- log10(MAX): a layer's mag at or past this belongs one layer out
local TINY = 5.562684646268003e-309         -- 1 / MAX: below it a value is a tiny tower
local LOG10E = 0.4342944819032518            -- log10(e)
local LN10 = 2.302585092994046               -- ln(10)
local PREC = 17                              -- past 10^17 x, adding x to anything changes nothing a double sees
local SWALLOW = LOG_MAX + PREC               -- a layer-1 mag past this swallows every plain number whole
local exp, ln = math.exp, math.log
local MSI = 9007199254740991                 -- the tallest tower (2^53 - 1 tens); a layer count past it is hyper

-- log10(1 + 10^d) and log10(1 - 10^d) for d <= 0 (the correction when two powers of ten are added or subtracted)
local function lg1p(d: number): number
	return ln(1 + exp(d * LN10)) / LN10
end
local function lg1m(d: number): number
	return ln(1 - exp(d * LN10)) / LN10
end

TowerNum.VERSION = "2.0.0"
TowerNum.MAX_NUMBER = MAX
TowerNum.MIN_NUMBER = TINY
TowerNum.LOG_MAX = LOG_MAX

type Tower = { l: number, m: number }
export type TowerNum = number | Tower

-- ------------------------------------------------------------------------------------------------------------
-- triples: the general paths work on (s, l, m) held in locals — sign, layer (negative = tiny), magnitude m >= 0 —
-- and only make a table at the very end, when the answer really is a tower. (0, 0, 0) is zero; (s, huge, huge) is
-- infinity. The public functions run hand-written fast paths first and fall back to these for the rare shapes.
-- ------------------------------------------------------------------------------------------------------------

-- canonical form: move layers inwards while the mag fits a layer closer to plain
local function norm(s: number, l: number, m: number): (number, number, number)
	if s == 0 then return 0, 0, 0 end
	if l > 0 then
		while m < LOG_MAX do
			if l == 1 then
				if m <= -LOG_MAX then return s, -1, -m end  -- 10^m with m past -308: a tiny one
				return s, 0, 10 ^ m
			end
			l -= 1
			m = 10 ^ m
		end
	elseif l < 0 then
		while m < LOG_MAX do
			if l == -1 then
				if m <= -LOG_MAX then return s, 1, -m end   -- 1 / 10^m with m past -308: a huge one
				return s, 0, 10 ^ -m
			end
			l += 1
			m = 10 ^ m
		end
	end
	return s, l, m
end

local growHyper: (number, number, number) -> TowerNum   -- set with the hyper tier (below)

local function build(s: number, l: number, m: number): TowerNum
	if l == 0 then return s * m end
	if l == huge then return s * huge end
	if l > MSI or l < -MSI then return growHyper(s, l, m) end
	return { l = l, m = s * m }
end

local fromAny: (any) -> TowerNum                 -- TowerNum.from, set below

local function tri(x: any): (number, number, number)
	if type(x) == "number" then
		if x > 0 then
			if x == huge then return 1, huge, huge end
			return 1, 0, x
		elseif x < 0 then
			if x == -huge then return -1, huge, huge end
			return -1, 0, -x
		end
		return 0, 0, 0                               -- zero (NaN is caught before it gets here)
	elseif type(x) == "table" then
		if x.h ~= nil then error("TowerNum: internal error, a hyper value reached a tower-only path", 2) end
		local m = x.m
		if m > 0 then return 1, x.l, m end
		return -1, x.l, -m
	end
	local v = fromAny(x)
	if type(v) == "table" then
		if v.h ~= nil then error("TowerNum: internal error, a hyper value reached a tower-only path", 2) end
		local m = v.m
		if m > 0 then return 1, v.l, m end
		return -1, v.l, -m
	end
	if v > 0 then return 1, (if v == huge then huge else 0), (if v == huge then huge else v) end
	if v < 0 then return -1, (if v == -huge then huge else 0), (if v == -huge then huge else -v) end
	return 0, 0, 0
end

-- ------------------------------------------------------------------------------------------------------------
-- the HYPER tier: past 10^^MSI (a tower of 9,007,199,254,740,991 tens) a value becomes { l = HL, m = +-HM, h = H }
-- where H is a Hyper value (a PowiainaNum port, up to {10, 9e15, 1, 1, 1, 2}); its reciprocals have l = -HL.
-- HL is further out than any tower layer, so every fast path that orders by layer (compare, add, "the bigger
-- one swallows the smaller") is already right; the few places that would do arithmetic on the layer or the mag
-- send hyper values here instead. Everything that makes one is canonical: fromH turns a Hyper result that fits
-- a double or a tower back into one.
-- ------------------------------------------------------------------------------------------------------------

local HL = 4611686018427387904               -- 2^62: the layer a hyper value reports (past every tower's)
local HM = 1e300                             -- the mag a hyper value reports (only its sign means anything)
TowerNum.MAX_LAYER = MSI

local Hyper: any
do
	local scr: any = script                      -- nil outside Roblox (the standalone Luau tests)
	if scr ~= nil then
		local m = scr:FindFirstChild("Hyper") or scr:WaitForChild("Hyper", 10)
		if m == nil then error("TowerNum needs its Hyper module: a ModuleScript named Hyper inside TowerNum") end
		Hyper = require(m :: any)
	else
		Hyper = (require :: any)("./hyper/Hyper")
	end
end
TowerNum.Hyper = Hyper

local function wrapH(h: any): TowerNum
	return { l = if h.sm then -HL else HL, m = if h.s < 0 then -HM else HM, h = h } :: any
end

-- a Hyper value -> the canonical TowerNum (a double, a tower, or a hyper value)
local function fromH(h: any): TowerNum
	local s = h.s
	local a = h.a
	local base = a[1].re
	if base ~= base then return base end
	if s == 0 then return 0 end
	if base == huge then return s * huge end
	if h.y ~= 0 then return wrapH(h) end
	local k, z = 0, 0
	for i = 2, #a do
		local op = a[i]
		if op.re ~= 0 then
			if op.ex ~= 1 or op.me ~= 1 then return wrapH(h) end
			if op.ar == 1 then
				k += op.re
			elseif op.ar == 0 then
				z += op.re                                -- 10{0}x = 10x: a factor of 10^re, applied first
			else
				return wrapH(h)
			end
		end
	end
	if k > MSI then return wrapH(h) end
	if z ~= 0 then
		local lb = log10(base) + z
		if k == 0 and lb < LOG_MAX then
			base = 10 ^ lb
		else
			base = lb
			k += 1
		end
	end
	if k == 0 then return if h.sm then s / base else s * base end
	-- (10^)^k base: a tower of k tens over base (or its reciprocal)
	local ns, nl, nm = norm(s, if h.sm then -k else k, base)
	if nl == 0 then return ns * nm end
	return { l = nl, m = ns * nm }
end

-- a triple -> a Hyper value (the layer may be past MSI: that is how a tower grows into the hyper tier)
local function triToH(s: number, l: number, m: number): any
	if s == 0 then return Hyper.from(0) end
	if l == huge then return Hyper.from(s * huge) end
	if l == 0 then return Hyper.from(s * m) end
	local k, b = if l < 0 then -l else l, m
	if b > MSI then b = log10(b); k += 1 end
	return Hyper.normalize({ s = s, y = 0, sm = l < 0, a = { { ar = 0, ex = 1, me = 1, re = b }, { ar = 1, ex = 1, me = 1, re = k } } })
end

-- any TowerNum (or anything from() reads) -> a Hyper value
local function toH(x: any): any
	if type(x) == "number" then return Hyper.from(x) end
	if type(x) == "table" then
		local h = x.h
		if h ~= nil then return h end
		local m = x.m
		if x.l ~= nil and m ~= nil and x.s == nil then
			return triToH(if m > 0 then 1 else -1, x.l, if m > 0 then m else -m)
		end
	end
	return toH(fromAny(x))
end

growHyper = function(s: number, l: number, m: number): TowerNum
	return fromH(triToH(s, l, m))
end

TowerNum.toHyper = toH        -- any TowerNum -> its Hyper (PowiainaNum) value
TowerNum.fromHyper = fromH    -- a Hyper value -> the canonical TowerNum

-- a tower (or hyper value) times -1
local function negT(t: any): TowerNum
	local h = t.h
	if h ~= nil then return wrapH(Hyper.neg(h)) end
	return { l = t.l, m = -t.m }
end

local function isH(x: any): boolean
	return type(x) == "table" and x.h ~= nil
end

-- strings and foreign tables -> canonical values (so the slow paths can see a hyper value for what it is)
local function res(x: any): any
	if type(x) == "number" then return x end
	if type(x) == "table" and (x.h ~= nil or (x.l ~= nil and x.m ~= nil and x.s == nil)) then return x end
	return fromAny(x)
end

-- the hyper tier's own arithmetic: TowerNum values in, the canonical TowerNum out
local function hyp1(f: any, a: any): TowerNum
	return fromH(f(toH(a)))
end
local function hyp2(f: any, a: any, b: any): TowerNum
	return fromH(f(toH(a), toH(b)))
end

-- is |(l1, m1)| bigger than |(l2, m2)|? Layers order the size (tiny < plain < huge); within a tiny layer a
-- bigger mag is a smaller value
local function magGreater(l1: number, m1: number, l2: number, m2: number): boolean
	if l1 ~= l2 then return l1 > l2 end
	if l1 < 0 then return m1 < m2 end
	return m1 > m2
end

-- log10 of a magnitude, as a signed triple (the magnitude must not be zero)
local function logTri(l: number, m: number): (number, number, number)
	if l == 0 then
		local v = log10(m)
		if v > 0 then return 1, 0, v elseif v < 0 then return -1, 0, -v end
		return 0, 0, 0
	elseif l == huge then
		return 1, huge, huge
	elseif l == 1 then
		return 1, 0, m
	elseif l > 1 then
		return 1, l - 1, m
	elseif l == -1 then
		return -1, 0, m
	end
	return -1, -l - 1, m
end

-- 10^(s * value of (l, m)), as a triple
local function expTri(s: number, l: number, m: number): (number, number, number)
	if s == 0 then return 1, 0, 1 end
	if l == 0 then
		local v = s * m
		if v >= LOG_MAX then return 1, 1, v end
		if v <= -LOG_MAX then return 1, -1, -v end
		return 1, 0, 10 ^ v
	end
	if l < 0 then return 1, 0, 1 end                -- 10 to a tiny power is 1 to every digit a double has
	if l == huge then
		if s > 0 then return 1, huge, huge end
		return 0, 0, 0
	end
	if s > 0 then return 1, l + 1, m end
	return 1, -(l + 1), m
end

-- a + b on triples
local function addTri(s1: number, l1: number, m1: number, s2: number, l2: number, m2: number): (number, number, number)
	if s1 == 0 then return s2, l2, m2 end
	if s2 == 0 then return s1, l1, m1 end
	if magGreater(l2, m2, l1, m1) then
		s1, l1, m1, s2, l2, m2 = s2, l2, m2, s1, l1, m1
	end
	-- (1) is the bigger one now
	if l1 == huge then
		if l2 == huge and s1 ~= s2 then return 0, 0, 0 / 0 end
		return s1, l1, m1
	end
	if l1 >= 2 then
		if l2 == l1 and m2 == m1 and s2 ~= s1 then return 0, 0, 0 end
		return s1, l1, m1
	end
	if l1 == 1 then
		if l2 < 0 then return s1, l1, m1 end
		local e2 = if l2 == 1 then m2 else log10(m2)
		local d = e2 - m1
		if d < -PREC then return s1, l1, m1 end
		if s1 == s2 then
			return s1, 1, m1 + lg1p(d)
		end
		if d == 0 then return 0, 0, 0 end
		return norm(s1, 1, m1 + lg1m(d))
	end
	if l1 == 0 then
		if l2 == 0 then
			local v = s1 * m1 + s2 * m2
			if v > MAX or v < -MAX then                   -- two numbers past the top together: one layer up
				return s1, 1, log10(m1) + log10(1 + m2 / m1)
			end
			if v > 0 then return 1, 0, v elseif v < 0 then return -1, 0, -v end
			return 0, 0, 0
		end
		-- a number plus a tiny one: only a number near the bottom of the doubles can feel it
		if l2 == -1 and m1 < 1e-290 then
			local v = s1 * m1 + s2 * 10 ^ -m2
			if v > 0 then return 1, 0, v elseif v < 0 then return -1, 0, -v end
			return 0, 0, 0
		end
		return s1, l1, m1
	end
	-- both tiny, (1) the bigger: 1/10^m1 and 1/10^m2 with m1 <= m2 (same layer) or (2) a layer further in
	if l1 <= -2 or l2 < l1 then
		if l2 == l1 and m2 == m1 and s2 ~= s1 then return 0, 0, 0 end
		return s1, l1, m1
	end
	local d = m1 - m2                                 -- <= 0
	if d < -PREC then return s1, l1, m1 end
	if s1 == s2 then
		return norm(s1, -1, m1 - lg1p(d))
	end
	if d == 0 then return 0, 0, 0 end
	return norm(s1, -1, m1 - lg1m(d))
end

-- a * b on triples
local function mulTri(s1: number, l1: number, m1: number, s2: number, l2: number, m2: number): (number, number, number)
	if s1 == 0 or s2 == 0 then return 0, 0, 0 end
	local s = s1 * s2
	if l1 == huge or l2 == huge then return s, huge, huge end
	if l1 == 0 and l2 == 0 then
		local r = m1 * m2
		if r <= MAX and r >= TINY then return s, 0, r end
		local e = log10(m1) + log10(m2)
		if e >= LOG_MAX then return s, 1, e end
		if e <= -LOG_MAX then return s, -1, -e end
		return s, 0, r
	end
	-- 10^(log a + log b)
	local as, al, am = logTri(l1, m1)
	local bs, bl, bm = logTri(l2, m2)
	local ts, tl, tm = addTri(as, al, am, bs, bl, bm)
	local es, el, em = expTri(ts, tl, tm)
	if es == 0 then return 0, 0, 0 end
	return s, el, em
end

-- a / b on triples (b ~= 0)
local function divTri(s1: number, l1: number, m1: number, s2: number, l2: number, m2: number): (number, number, number)
	if s1 == 0 then return 0, 0, 0 end
	local s = s1 * s2
	if l2 == huge then
		if l1 == huge then return 0, 0, 0 / 0 end
		return 0, 0, 0
	end
	if l1 == huge then return s, huge, huge end
	if l1 == 0 and l2 == 0 then
		local r = m1 / m2
		if r <= MAX and r >= TINY then return s, 0, r end
		local e = log10(m1) - log10(m2)
		if e >= LOG_MAX then return s, 1, e end
		if e <= -LOG_MAX then return s, -1, -e end
		return s, 0, r
	end
	local as, al, am = logTri(l1, m1)
	local bs, bl, bm = logTri(l2, m2)
	local ts, tl, tm = addTri(as, al, am, -bs, bl, bm)
	local es, el, em = expTri(ts, tl, tm)
	if es == 0 then return 0, 0, 0 end
	return s, el, em
end

-- magnitude of a^b for a > 0 (b any sign): 10^(log10(a) * b)
local function powMagTri(l1: number, m1: number, s2: number, l2: number, m2: number): (number, number, number)
	local as, al, am = logTri(l1, m1)
	local ps, pl, pm = mulTri(as, al, am, s2, l2, m2)
	return expTri(ps, pl, pm)
end

-- the general path for any two inputs (strings, NaN, the rare shapes): triples in, canonical value out
local function slowAdd(a: any, b: any, flip: number): TowerNum
	a, b = res(a), res(b)
	if (type(a) == "number" and a ~= a) or (type(b) == "number" and b ~= b) then return 0 / 0 end
	if isH(a) or isH(b) then return hyp2(if flip > 0 then Hyper.add else Hyper.sub, a, b) end
	local s1, l1, m1 = tri(a)
	local s2, l2, m2 = tri(b)
	return build(addTri(s1, l1, m1, flip * s2, l2, m2))
end
local function slowMul(a: any, b: any): TowerNum
	a, b = res(a), res(b)
	if (type(a) == "number" and a ~= a) or (type(b) == "number" and b ~= b) then return 0 / 0 end
	if isH(a) or isH(b) then return hyp2(Hyper.mul, a, b) end
	local s1, l1, m1 = tri(a)
	local s2, l2, m2 = tri(b)
	return build(mulTri(s1, l1, m1, s2, l2, m2))
end
local function slowDiv(a: any, b: any): TowerNum
	a, b = res(a), res(b)
	if (type(a) == "number" and a ~= a) or (type(b) == "number" and b ~= b) then return 0 / 0 end
	if isH(a) or isH(b) then return hyp2(Hyper.div, a, b) end
	local s1, l1, m1 = tri(a)
	local s2, l2, m2 = tri(b)
	if s2 == 0 then
		if s1 == 0 then return 0 / 0 end
		return s1 * huge
	end
	return build(divTri(s1, l1, m1, s2, l2, m2))
end

-- ------------------------------------------------------------------------------------------------------------
-- the fast paths. `t` is always a canonical tower here; `st` flips its sign (sub) without allocating first.
-- ------------------------------------------------------------------------------------------------------------

-- tower (times st) + number
local function addTN(t: Tower, st: number, x: number): TowerNum
	if x ~= x then return x end
	if x == huge or x == -huge then return x end
	local l, m = t.l, t.m
	if l < 0 then
		-- a tiny one plus a number: the number, unless it is itself down among the denormals
		if x == 0 then
			if st > 0 then return t end
			return negT(t)
		end
		if abs(x) >= 1e-290 then return x end
		return slowAdd(x, t, st)
	end
	if x == 0 or l >= 2 then
		if st > 0 then return t end
		return negT(t)
	end
	m *= st
	-- layer 1: |t| = 10^|m| >= 1.8e308 > |x|, so d <= 0
	local am = abs(m)
	local d = log10(abs(x)) - am
	if d < -PREC then
		if st > 0 then return t end
		return { l = 1, m = m }
	end
	if (m > 0) == (x > 0) then
		return { l = 1, m = if m > 0 then am + lg1p(d) else -(am + lg1p(d)) }
	end
	local nm = am + lg1m(d)
	if nm >= LOG_MAX then return { l = 1, m = if m > 0 then nm else -nm } end
	local v = 10 ^ nm
	return if m > 0 then v else -v
end

-- tower a + tower b (times sb)
local function addTT(a: Tower, b: Tower, sb: number): TowerNum
	local al, bl = a.l, b.l
	if al < 0 or bl < 0 then return slowAdd(a, b, sb) end
	local am, bm = a.m, b.m * sb
	local aa, ba = abs(am), abs(bm)
	local big, bigM, bigA, smallM, smallA, smallL = a, am, aa, bm, ba, bl
	local bigL = al
	if bl > al or (bl == al and ba > aa) then
		big, bigM, bigA, bigL, smallM, smallA, smallL = b, bm, ba, bl, am, aa, al
	end
	if bigL >= 2 or smallL < bigL then
		if smallL == bigL and smallA == bigA and (smallM > 0) ~= (bigM > 0) then return 0 end
		if big == b and sb < 0 then return negT(big) end
		return big
	end
	-- both layer 1
	local d = smallA - bigA
	if d < -PREC then
		if big == b and sb < 0 then return { l = 1, m = bigM } end
		return big
	end
	if (bigM > 0) == (smallM > 0) then
		local nm = bigA + lg1p(d)
		return { l = 1, m = if bigM > 0 then nm else -nm }
	end
	if d == 0 then return 0 end
	local nm = bigA + lg1m(d)
	if nm >= LOG_MAX then return { l = 1, m = if bigM > 0 then nm else -nm } end
	local v = 10 ^ nm
	return if bigM > 0 then v else -v
end

-- tower * number (x ~= 0, finite, not NaN), or tower / number with inv = true
local function mulTN(t: Tower, x: number, inv: boolean): TowerNum
	local l, m = t.l, t.m
	if l >= 2 or l <= -2 then
		if x > 0 then return t end
		return negT(t)
	end
	local ax = abs(x)
	local am = abs(m)
	local lx = if inv then -log10(ax) else log10(ax)
	local neg = (m > 0) ~= (x > 0)
	if l == 1 then
		local nm = am + lx
		if nm >= LOG_MAX then return { l = 1, m = if neg then -nm else nm } end
		local v = 10 ^ nm
		return if neg then -v else v
	end
	-- l == -1: the value is 10^-am
	local e = lx - am
	if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
	if e >= LOG_MAX then return { l = 1, m = if neg then -e else e } end
	local v = 10 ^ e
	return if neg then -v else v
end

-- ------------------------------------------------------------------------------------------------------------
-- arithmetic
-- ------------------------------------------------------------------------------------------------------------

function TowerNum.add(a: any, b: any): TowerNum
	if type(a) == "number" then
		if type(b) == "number" then
			local r = a + b
			if r <= MAX and r >= -MAX then return r end
			if r ~= r or a == huge or a == -huge or b == huge or b == -huge then return r end
			-- two finite doubles past the top together
			local x, y = abs(a), abs(b)
			if x < y then x, y = y, x end
			local e = log10(x) + log10(1 + y / x)
			return { l = 1, m = if r > 0 then e else -e }
		elseif type(b) == "table" then
			-- a tower of 2+ tens, or one tall enough that no double reaches 17 digits of it: b as it is
			local bl, bm = b.l, b.m
			if bl >= 2 or (bl == 1 and (bm > SWALLOW or bm < -SWALLOW)) then
				if a == a and a ~= huge and a ~= -huge then return b end
			end
			if a ~= a then return a end
			return addTN(b, 1, a)
		end
	elseif type(a) == "table" then
		if type(b) == "number" then
			local al, am = a.l, a.m
			if al >= 2 or (al == 1 and (am > SWALLOW or am < -SWALLOW)) then
				if b == b and b ~= huge and b ~= -huge then return a end
			end
			return addTN(a, 1, b)
		end
		if type(b) == "table" then
			local al, bl = a.l, b.l
			if al == 1 and bl == 1 then
				-- both layer 1: the one 17+ digits of exponent ahead is the answer, untouched
				local am, bm = a.m, b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if aa - ba > PREC then return a end
				if ba - aa > PREC then return b end
				-- close enough to touch: 10^A +- 10^B = 10^(A + log10(1 +- 10^(B - A))), inline (no second call)
				local bigM, bigA, smallM, smallA = am, aa, bm, ba
				if ba > aa then bigM, bigA, smallM, smallA = bm, ba, am, aa end
				local d = smallA - bigA
				if (bigM > 0) == (smallM > 0) then
					local nm = bigA + lg1p(d)
					return { l = 1, m = if bigM > 0 then nm else -nm }
				end
				if d == 0 then return 0 end
				local nm = bigA + lg1m(d)
				if nm >= LOG_MAX then return { l = 1, m = if bigM > 0 then nm else -nm } end
				local v = 10 ^ nm
				return if bigM > 0 then v else -v
			elseif al > 0 and bl > 0 then
				if al ~= bl then return if al > bl then a else b end
				if al == HL then return hyp2(Hyper.add, a, b) end
				-- the same layer, 2 or more: the bigger mag is the answer (only an exact opposite cancels)
				local am, bm = a.m, b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if aa > ba then return a end
				if ba > aa then return b end
				return if (am > 0) == (bm > 0) then a else 0
			elseif al == -1 and bl == -1 then
				-- two tiny ones: the one 17+ digits of exponent LESS tiny is the answer
				local am, bm = a.m, b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if ba - aa > PREC then return a end
				if aa - ba > PREC then return b end
			end
			return addTT(a, b, 1)
		end
	end
	return slowAdd(a, b, 1)
end

function TowerNum.sub(a: any, b: any): TowerNum
	if type(a) == "number" then
		if type(b) == "number" then
			local r = a - b
			if r <= MAX and r >= -MAX then return r end
			if r ~= r or a == huge or a == -huge or b == huge or b == -huge then return r end
			local x, y = abs(a), abs(b)
			if x < y then x, y = y, x end
			local e = log10(x) + log10(1 + y / x)
			return { l = 1, m = if r > 0 then e else -e }
		elseif type(b) == "table" then
			if a ~= a then return a end
			return addTN(b, -1, a)
		end
	elseif type(a) == "table" then
		if type(b) == "number" then
			local al, am = a.l, a.m
			if al >= 2 or (al == 1 and (am > SWALLOW or am < -SWALLOW)) then
				if b == b and b ~= huge and b ~= -huge then return a end
			end
			return addTN(a, 1, -b)
		end
		if type(b) == "table" then
			local al, bl = a.l, b.l
			if al == 1 and bl == 1 then
				local am, bm = a.m, -b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if aa - ba > PREC then return a end
				if ba - aa > PREC then return { l = 1, m = bm } end
				-- close enough to touch: 10^A +- 10^B = 10^(A + log10(1 +- 10^(B - A))), inline (no second call)
				local bigM, bigA, smallM, smallA = am, aa, bm, ba
				if ba > aa then bigM, bigA, smallM, smallA = bm, ba, am, aa end
				local d = smallA - bigA
				if (bigM > 0) == (smallM > 0) then
					local nm = bigA + lg1p(d)
					return { l = 1, m = if bigM > 0 then nm else -nm }
				end
				if d == 0 then return 0 end
				local nm = bigA + lg1m(d)
				if nm >= LOG_MAX then return { l = 1, m = if bigM > 0 then nm else -nm } end
				local v = 10 ^ nm
				return if bigM > 0 then v else -v
			elseif al > 0 and bl > 0 then
				if al > bl then return a end
				if bl > al then return negT(b) end
				if al == HL then return hyp2(Hyper.sub, a, b) end
				local am, bm = a.m, -b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if aa > ba then return a end
				if ba > aa then return { l = bl, m = bm } end
				return if (am > 0) == (bm > 0) then a else 0
			elseif al == -1 and bl == -1 then
				local am, bm = a.m, -b.m
				local aa = if am > 0 then am else -am
				local ba = if bm > 0 then bm else -bm
				if ba - aa > PREC then return a end
				if aa - ba > PREC then return { l = -1, m = bm } end
			end
			return addTT(a, b, -1)
		end
	end
	return slowAdd(a, b, -1)
end

function TowerNum.mul(a: any, b: any): TowerNum
	if type(a) == "number" then
		if type(b) == "number" then
			local r = a * b
			if r <= MAX and r >= -MAX and (r >= TINY or r <= -TINY) then return r end
			if r ~= r or a == 0 or b == 0 or a == huge or a == -huge or b == huge or b == -huge then return r end
			-- past the top, or under the bottom (where the double would lose digits, then hit 0)
			local e = log10(abs(a)) + log10(abs(b))
			local neg = (a > 0) ~= (b > 0)
			if e >= LOG_MAX then return { l = 1, m = if neg then -e else e } end
			if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
			return r
		elseif type(b) == "table" then
			if a ~= a or a == 0 or a == huge or a == -huge then
				if a == 0 or a ~= a then return if a == 0 then 0 else a end
				return if (a > 0) == (b.m > 0) then huge else -huge
			end
			return mulTN(b, a, false)
		end
	elseif type(a) == "table" then
		if type(b) == "number" then
			if b ~= b or b == 0 or b == huge or b == -huge then
				if b == 0 or b ~= b then return if b == 0 then 0 else b end
				return if (b > 0) == (a.m > 0) then huge else -huge
			end
			return mulTN(a, b, false)
		elseif type(b) == "table" then
			local al, bl = a.l, b.l
			if (al == 1 or al == -1) and (bl == 1 or bl == -1) then
				-- exponents add: log10|a| = al * |am|, log10|b| = bl * |bm|
				local am, bm = a.m, b.m
				local x = if am > 0 then am else -am
				local y = if bm > 0 then bm else -bm
				local neg = (am > 0) ~= (bm > 0)
				if al == bl then
					local e = x + y
					if e <= MAX then return { l = al, m = if neg then -e else e } end
					if x < y then x, y = y, x end
					e = log10(x) + log10(1 + y / x)         -- the sum itself overflowed
					return { l = 2 * al, m = if neg then -e else e }
				end
				local e = if al > 0 then x - y else y - x   -- opposite signs: a difference, never an overflow
				if e >= LOG_MAX then return { l = 1, m = if neg then -e else e } end
				if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
				local v = 10 ^ e
				return if neg then -v else v
			end
			if al > 0 and bl > 0 then
				-- a layer-2+ tower times anything smaller: 10^10^m x 10^E = 10^10^(m + log10(1 + E / 10^m)),
				-- which a double only sees when E is within 17 digits of 10^m
				local am, bm = a.m, b.m
				local neg = (am > 0) ~= (bm > 0)
				local big, bigL, bigA, smL, smA = a, al, abs(am), bl, abs(bm)
				if bl > al or (bl == al and smA > bigA) then
					big, bigL, bigA, smL, smA = b, bl, abs(bm), al, abs(am)
				end
				if bigL == HL then
					-- a hyper value times anything a tower can hold: the hyper value; two of them: the hyper tier
					if smL == HL then return hyp2(Hyper.mul, a, b) end
					if neg == (big.m < 0) then return big end
					return negT(big)
				end
				if bigL == 2 then
					-- the smaller one's log10 as a log10 of its own: layer 1 -> log10(mag), layer 2 -> its mag
					local e = if smL == 1 then log10(smA) else smA
					local d = e - bigA
					if d < -PREC then
						if neg == (big.m < 0) then return big end
						return { l = 2, m = if neg then -bigA else bigA }
					end
					local nm = bigA + lg1p(d)
					return { l = 2, m = if neg then -nm else nm }
				end
				if neg == (big.m < 0) then return big end
				return { l = bigL, m = if neg then -bigA else bigA }
			end
		end
	end
	return slowMul(a, b)
end

function TowerNum.div(a: any, b: any): TowerNum
	if type(a) == "number" then
		if type(b) == "number" then
			local r = a / b
			if r <= MAX and r >= -MAX and (r >= TINY or r <= -TINY) then return r end
			if r ~= r or a == 0 or b == 0 or a == huge or a == -huge or b == huge or b == -huge then return r end
			local e = log10(abs(a)) - log10(abs(b))
			local neg = (a > 0) ~= (b > 0)
			if e >= LOG_MAX then return { l = 1, m = if neg then -e else e } end
			if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
			return r
		elseif type(b) == "table" then
			if a ~= a then return a end
			if a == 0 then return 0 end
			if a == huge or a == -huge then return if (a > 0) == (b.m > 0) then huge else -huge end
			local bl, bm = b.l, b.m
			local neg = (a > 0) ~= (bm > 0)
			if bl == HL then return hyp2(Hyper.div, a, b) end
			if bl >= 2 then
				-- a / 10^10^m: 10^(log10 a - 10^m), and 10^m dwarfs log10 a: the reciprocal tower
				return { l = -bl, m = if neg then -abs(bm) else abs(bm) }
			elseif bl == 1 then
				local e = log10(abs(a)) - abs(bm)
				if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
				local v = 10 ^ e
				return if neg then -v else v
			end
		end
	elseif type(a) == "table" then
		if type(b) == "number" then
			if b ~= b then return b end
			if b == 0 then return if a.m > 0 then huge else -huge end
			if b == huge or b == -huge then return 0 end
			return mulTN(a, b, true)
		elseif type(b) == "table" then
			local al, bl = a.l, b.l
			if (al == 1 or al == -1) and (bl == 1 or bl == -1) then
				-- exponents subtract: log10|a| = al * |am|, log10|b| = bl * |bm|
				local am, bm = a.m, b.m
				local x = if am > 0 then am else -am
				local y = if bm > 0 then bm else -bm
				local neg = (am > 0) ~= (bm > 0)
				if al ~= bl then
					local e = x + y                          -- huge / tiny or tiny / huge: the sizes add
					local sl = al                            -- the answer is on a's side
					if e <= MAX then return { l = sl, m = if neg then -e else e } end
					if x < y then x, y = y, x end
					e = log10(x) + log10(1 + y / x)
					return { l = 2 * sl, m = if neg then -e else e }
				end
				local e = if al > 0 then x - y else y - x
				if e >= LOG_MAX then return { l = 1, m = if neg then -e else e } end
				if e <= -LOG_MAX then return { l = -1, m = if neg then e else -e } end
				local v = 10 ^ e
				return if neg then -v else v
			end
			-- the same layer, 2 or more: 10^10^A / 10^10^B, one side dwarfs the other unless A and B are close
			if al == bl and al >= 2 then
				if al == HL then return hyp2(Hyper.div, a, b) end
				local am, bm = a.m, b.m
				local x = if am > 0 then am else -am
				local y = if bm > 0 then bm else -bm
				local neg = (am > 0) ~= (bm > 0)
				if x - y > PREC then
					if neg == (am < 0) then return a end
					return { l = al, m = -am }
				end
				if y - x > PREC then return { l = -al, m = if neg then -y else y } end
			end
			-- a layer-2+ tower over something a layer or more below it: the tower, as it is
			if al >= 2 and bl > 0 and bl < al - 1 then
				local neg = (a.m > 0) ~= (b.m > 0)
				if neg == (a.m < 0) then return a end
				return negT(a)
			end
		end
	end
	return slowDiv(a, b)
end

function TowerNum.pow(a: any, b: any): TowerNum
	if type(a) == "number" then
		if type(b) == "number" then
			local r = a ^ b
			if r <= MAX and r >= -MAX and (r >= TINY or r <= -TINY) then return r end
			if r ~= r or a == 0 or a == huge or a == -huge or b == huge or b == -huge then return r end
			if a > 0 then
				-- a finite positive base past the top or under the bottom: 10^(b log10 a)
				local e = b * log10(a)
				if e >= LOG_MAX then
					if e <= MAX then return { l = 1, m = e } end
					return { l = 2, m = log10(abs(b)) + log10(abs(log10(a))) }   -- e itself overflowed
				end
				if e <= -LOG_MAX then
					if e >= -MAX then return { l = -1, m = -e } end
					return { l = -2, m = log10(abs(b)) + log10(abs(log10(a))) }
				end
				return r
			end
		end
	elseif type(a) == "table" and type(b) == "number" then
		local l, m = a.l, a.m
		if l == -1 and m > 0 and b == b and b ~= huge and b ~= -huge then
			if b == 0 then return 1 end
			local e = -m * b                                -- log10 of the answer
			if e >= LOG_MAX then
				if e <= MAX then return { l = 1, m = e } end
				return { l = 2, m = log10(m) + log10(-b) }
			end
			if e <= -LOG_MAX then
				if e >= -MAX then return { l = -1, m = -e } end
				return { l = -2, m = log10(m) + log10(b) }
			end
			return 10 ^ e
		end
		if l > 0 and m > 0 and b == b and b ~= huge and b ~= -huge then
			if b == 0 then return 1 end
			if l == 1 then
				local e = m * b
				if e >= LOG_MAX then
					if e <= MAX then return { l = 1, m = e } end
					return { l = 2, m = log10(m) + log10(b) }           -- e itself overflowed
				end
				if e <= -LOG_MAX then
					if e >= -MAX then return { l = -1, m = -e } end
					return { l = -2, m = log10(m) + log10(-b) }
				end
				return 10 ^ e
			elseif b > 0 then
				-- layer 2: 10^10^m to the b = 10^10^(m + log10 b) (m dwarfs log10 b unless b is huge or tiny)
				if l == 2 then
					local nm = m + log10(b)
					if nm >= LOG_MAX then return { l = 2, m = nm } end
					return { l = 1, m = 10 ^ nm }
				end
				return a                                    -- layer 3+: nothing a double can hold moves it
			end
		end
	end
	a, b = res(a), res(b)
	if (type(a) == "number" and a ~= a) or (type(b) == "number" and b ~= b) then return 0 / 0 end
	if isH(a) or isH(b) then return hyp2(Hyper.pow, a, b) end
	local s1, l1, m1 = tri(a)
	local s2, l2, m2 = tri(b)
	if s2 == 0 then return 1 end
	if s1 == 0 then return if s2 > 0 then 0 else huge end
	local sign = 1
	if s1 < 0 then
		-- a negative base needs a whole exponent; a tower exponent is even
		if l2 == 0 then
			local e = s2 * m2
			if e % 1 ~= 0 then return 0 / 0 end
			if e % 2 == 1 then sign = -1 end
		elseif l2 < 0 then
			return 0 / 0                                    -- a tiny exponent is never whole
		end
	end
	local s, l, m = powMagTri(l1, m1, s2, l2, m2)
	if s == 0 then return 0 end
	return build(sign, l, m)
end

function TowerNum.neg(a: any): TowerNum
	if type(a) == "number" then return -a end
	if type(a) == "table" then
		local l = a.l
		if l ~= HL and l ~= -HL then return { l = l, m = -a.m } end
		return negT(a)
	end
	return TowerNum.neg(res(a))
end

function TowerNum.abs(a: any): TowerNum
	if type(a) == "number" then return abs(a) end
	if type(a) == "table" then
		local m = a.m
		if m > 0 then return a end
		local l = a.l
		if l ~= HL and l ~= -HL then return { l = l, m = -m } end
		return negT(a)
	end
	return TowerNum.abs(res(a))
end

function TowerNum.recip(a: any): TowerNum
	return TowerNum.div(1, a)
end

-- 10^a
function TowerNum.exp10(a: any): TowerNum
	if type(a) == "number" then
		if a < LOG_MAX and a > -LOG_MAX then return 10 ^ a end
		if a ~= a then return a end
		if a == huge then return huge end
		if a == -huge then return 0 end
		if a > 0 then return { l = 1, m = a } end
		return { l = -1, m = -a }
	end
	if type(a) == "table" then
		local l, m = a.l, a.m
		if l < 0 then return 1 end
		if l >= MSI then return hyp1(Hyper.pow10, a) end    -- the tallest tower and past it: the hyper tier
		if m > 0 then return { l = l + 1, m = m } end
		return { l = -(l + 1), m = -m }
	end
	return TowerNum.exp10(res(a))
end
TowerNum.pow10 = TowerNum.exp10

-- e^a
function TowerNum.exp(a: any): TowerNum
	if type(a) == "number" and a < 709.78 and a > -708 then return math.exp(a) end
	return TowerNum.exp10(TowerNum.mul(a, LOG10E))
end

function TowerNum.log10(a: any): TowerNum
	if type(a) == "number" then return log10(a) end
	if type(a) == "table" then
		local l, m = a.l, a.m
		if m < 0 then return 0 / 0 end
		if l == 1 then return m end
		if l > MSI or l < -MSI then return hyp1(Hyper.log10, a) end
		if l > 1 then return { l = l - 1, m = m } end
		if l == -1 then return -m end
		return { l = -l - 1, m = -m }                             -- log10 of 1 / 10^10^m = -(10^m)
	end
	return TowerNum.log10(res(a))
end

function TowerNum.ln(a: any): TowerNum
	if type(a) == "number" then return math.log(a) end
	return TowerNum.mul(TowerNum.log10(a), LN10)
end

function TowerNum.log2(a: any): TowerNum
	if type(a) == "number" then return math.log(a, 2) end
	return TowerNum.div(TowerNum.log10(a), 0.3010299956639812)
end

-- log of a in any base (base defaults to e)
function TowerNum.log(a: any, base: any?): TowerNum
	if base == nil then return TowerNum.ln(a) end
	if type(a) == "number" and type(base) == "number" then return math.log(a, base) end
	return TowerNum.div(TowerNum.log10(a), TowerNum.log10(base))
end

function TowerNum.sqrt(a: any): TowerNum
	if type(a) == "number" then return math.sqrt(a) end
	return TowerNum.pow(a, 0.5)
end

function TowerNum.cbrt(a: any): TowerNum
	if type(a) == "number" then return if a < 0 then -((-a) ^ (1 / 3)) else a ^ (1 / 3) end
	return TowerNum.pow(a, 1 / 3)
end

function TowerNum.root(a: any, n: any): TowerNum
	return TowerNum.pow(a, TowerNum.recip(n))
end

-- a huge tower is past 2^53, so already whole; a tiny one sits between -1 and 1
function TowerNum.floor(a: any): TowerNum
	if type(a) == "number" then return floor(a) end
	if type(a) == "table" then
		if a.l > 0 then return a end
		return if a.m > 0 then 0 else -1
	end
	return TowerNum.floor(fromAny(a))
end
function TowerNum.ceil(a: any): TowerNum
	if type(a) == "number" then return math.ceil(a) end
	if type(a) == "table" then
		if a.l > 0 then return a end
		return if a.m > 0 then 1 else 0
	end
	return TowerNum.ceil(fromAny(a))
end
function TowerNum.round(a: any): TowerNum
	if type(a) == "number" then return floor(a + 0.5) end
	if type(a) == "table" then
		if a.l > 0 then return a end
		return 0
	end
	return TowerNum.round(fromAny(a))
end

-- a mod b, meaningful for plain numbers only (a tower mod anything has no digits left to keep): 0
function TowerNum.mod(a: any, b: any): TowerNum
	if type(a) == "number" and type(b) == "number" then return a % b end
	return 0
end

-- ------------------------------------------------------------------------------------------------------------
-- comparing
-- ------------------------------------------------------------------------------------------------------------

local function cmp(a: any, b: any): number
	if type(a) == "number" then
		if type(b) == "number" then
			return if a < b then -1 elseif a > b then 1 else 0
		elseif type(b) == "table" then
			if b.l > 0 then
				if a == huge then return 1 elseif a == -huge then return -1 end
				return if b.m > 0 then -1 else 1
			end
			-- a tiny one: every nonzero number is further from 0
			if b.m > 0 then return if a > 0 then 1 else -1 end
			return if a < 0 then -1 else 1
		end
	elseif type(a) == "table" then
		if type(b) == "table" then
			-- inlined: this is the hottest tower path in a game (every "can I afford it")
			local am, bm = a.m, b.m
			local al, bl = a.l, b.l
			if am > 0 then
				if bm < 0 then return 1 end
				if al ~= bl then return if al > bl then 1 else -1 end
				if am == bm then return if a.h == nil then 0 else Hyper.cmp(a.h, b.h) end
				if al > 0 then return if am > bm then 1 else -1 end
				return if am < bm then 1 else -1
			end
			if bm > 0 then return -1 end
			if al ~= bl then return if al > bl then -1 else 1 end
			if am == bm then return if a.h == nil then 0 else Hyper.cmp(a.h, b.h) end
			if al > 0 then return if am > bm then 1 else -1 end
			return if am < bm then 1 else -1
		end
		if type(b) == "number" then
			if a.l > 0 then
				if b == huge then return -1 elseif b == -huge then return 1 end
				return if a.m > 0 then 1 else -1
			end
			if a.m > 0 then return if b > 0 then -1 else 1 end
			return if b < 0 then 1 else -1
		end
	end
	if (type(a) == "number" and a ~= a) or (type(b) == "number" and b ~= b) then return 0 end
	return cmp(res(a), res(b))                        -- strings and foreign tables: read, then the paths above
end
TowerNum.cmp = cmp

function TowerNum.eq(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then return a == b end
	return cmp(a, b) == 0
end
function TowerNum.lt(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then return a < b end
	if type(a) == "table" and type(b) == "table" then
		local am, bm = a.m, b.m
		local al, bl = a.l, b.l
		local c
		if am > 0 then
			if bm < 0 then c = 1
			elseif al ~= bl then c = if al > bl then 1 else -1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		else
			if bm > 0 then c = -1
			elseif al ~= bl then c = if al > bl then -1 else 1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		end
		return c < 0
	end
	return cmp(a, b) < 0
end
function TowerNum.le(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then return a <= b end
	if type(a) == "table" and type(b) == "table" then
		local am, bm = a.m, b.m
		local al, bl = a.l, b.l
		local c
		if am > 0 then
			if bm < 0 then c = 1
			elseif al ~= bl then c = if al > bl then 1 else -1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		else
			if bm > 0 then c = -1
			elseif al ~= bl then c = if al > bl then -1 else 1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		end
		return c <= 0
	end
	return cmp(a, b) <= 0
end
function TowerNum.gt(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then return a > b end
	if type(a) == "table" and type(b) == "table" then
		local am, bm = a.m, b.m
		local al, bl = a.l, b.l
		local c
		if am > 0 then
			if bm < 0 then c = 1
			elseif al ~= bl then c = if al > bl then 1 else -1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		else
			if bm > 0 then c = -1
			elseif al ~= bl then c = if al > bl then -1 else 1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		end
		return c > 0
	end
	return cmp(a, b) > 0
end
function TowerNum.ge(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then return a >= b end
	if type(a) == "table" and type(b) == "table" then
		local am, bm = a.m, b.m
		local al, bl = a.l, b.l
		local c
		if am > 0 then
			if bm < 0 then c = 1
			elseif al ~= bl then c = if al > bl then 1 else -1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		else
			if bm > 0 then c = -1
			elseif al ~= bl then c = if al > bl then -1 else 1
			elseif am == bm then c = if a.h == nil then 0 else Hyper.cmp(a.h, b.h)
			elseif al > 0 then c = if am > bm then 1 elseif am < bm then -1 else 0
			else c = if am < bm then 1 elseif am > bm then -1 else 0 end
		end
		return c >= 0
	end
	return cmp(a, b) >= 0
end
function TowerNum.max(a: any, b: any): TowerNum
	if type(a) == "number" and type(b) == "number" then return if a >= b then a else b end
	local r = if cmp(a, b) >= 0 then a else b
	return if type(r) == "string" then fromAny(r) else r
end
function TowerNum.min(a: any, b: any): TowerNum
	if type(a) == "number" and type(b) == "number" then return if a <= b then a else b end
	local r = if cmp(a, b) <= 0 then a else b
	return if type(r) == "string" then fromAny(r) else r
end
function TowerNum.clamp(a: any, lo: any, hi: any): TowerNum
	return TowerNum.min(TowerNum.max(a, lo), hi)
end

function TowerNum.sign(a: any): number
	if type(a) == "number" then return if a > 0 then 1 elseif a < 0 then -1 else 0 end
	if type(a) == "table" and a.m ~= nil then return if a.m > 0 then 1 else -1 end
	return TowerNum.sign(res(a))
end
function TowerNum.isZero(a: any): boolean
	if type(a) == "number" then return a == 0 end
	if type(a) == "table" and a.m ~= nil then return false end
	return TowerNum.isZero(res(a))
end
function TowerNum.isNaN(a: any): boolean return type(a) == "number" and a ~= a end
function TowerNum.isInf(a: any): boolean
	return type(a) == "number" and (a == huge or a == -huge)
end
function TowerNum.isTower(a: any): boolean return type(a) == "table" end
-- past a tower of 9,007,199,254,740,991 tens (or the reciprocal of one): the hyper tier
function TowerNum.isHyper(a: any): boolean return type(a) == "table" and a.h ~= nil end

-- ------------------------------------------------------------------------------------------------------------
-- towers of tens: tetrate10(h) = 10^^h, slog10(a) = how tall a tower of tens a is (the inverse)
-- Between whole heights the tower grows linearly in its top exponent (10^^h = 10^h for 0 <= h < 1).
-- ------------------------------------------------------------------------------------------------------------

function TowerNum.tetrate10(h: any): TowerNum
	if type(h) ~= "number" then
		h = res(h)
		if type(h) ~= "number" then
			if h.m < 0 then return 0 end
			if h.l < 0 then return 10 ^ TowerNum.toNumber(h) end        -- a tiny height: 10^^h = 10^h ~ 1
			return hyp1(function(x) return Hyper.tetrate(10, x) end, h)
		end
	end
	if h ~= h then return h end
	if h < 0 then return 0 end
	if h == huge then return huge end
	if h > MSI then return fromH(Hyper.tetr10(h)) end
	local whole = floor(h)
	return build(norm(1, whole, 10 ^ (h - whole)))
end

function TowerNum.slog10(a: any): number
	if type(a) == "number" and a ~= a then return a end
	a = res(a)
	if isH(a) then
		if a.m < 0 then return 0 / 0 end
		if a.l < 0 then return -1 end
		return Hyper.slogOf(a.h)
	end
	local s, l, m = tri(a)
	if s <= 0 then return if s == 0 then -huge else 0 / 0 end
	if l == huge then return huge end
	if l < 0 then return -1 end                       -- (0, 1) sits between 10^^-1 = 0 and 10^^0 = 1
	local y, k = m, l
	if y < 1 then return y - 1 + k end                -- only on layer 0
	while y >= 10 do
		y = log10(y)
		k += 1
	end
	return k + log10(y)
end

-- ------------------------------------------------------------------------------------------------------------
-- the operators past powers, all the way up (PowiainaNum's hierarchy, to {10, 9e15, 1, 1, 1, 2}):
--   tetrate(a, h, payload?)   a^^h (payload^ ... : a^a^...^payload)       slog(a, base = 10)   ssqrt(a)
--   arrow(a, n, b)            a{n}b, n up-arrows (n = 1 is a^b, 2 a^^b, 3 a^^^b ...)
--   pentate(a, b) = a^^^b     hexate(a, b) = a^^^^b      anyarrowLog(a, n, base) (the inverse of arrow)
--   expansion(a, b) = a{{1}}b   expansionArrow(a, n, b) = a{{n}}b   multiExpansion   powerExpansion
--   explosion(a, b)   megotion(a, b)   powiaination(a, b)   iteratedLog(a, times, base)
--   factorial(a) gamma(a) lambertw(a)
--   affordGeometricSeries / sumGeometricSeries / affordArithmeticSeries / sumArithmeticSeries
--       (resources, priceStart, priceRatioOrAdd, owned): "buy max" for costs that grow by x or by + each level
-- Every argument can be any TowerNum (or a number or string); arrow counts are plain numbers.
-- ------------------------------------------------------------------------------------------------------------

local function hArg(x: any): any
	if x == nil or type(x) == "number" or type(x) == "boolean" then return x end
	return toH(x)
end
local function hOut(r: any): TowerNum
	if type(r) == "number" then return r end
	return fromH(r)
end
local function hyperOp(f: any): (...any) -> TowerNum
	return function(a: any, b: any?, c: any?, d: any?): TowerNum
		return hOut(f(hArg(a), hArg(b), hArg(c), hArg(d)))
	end
end
TowerNum.tetrate = hyperOp(Hyper.tetrate)
TowerNum.slog = hyperOp(function(a, base) return Hyper.slog(a, if base == nil then 10 else base) end)
TowerNum.ssqrt = hyperOp(Hyper.ssqrt)
TowerNum.iteratedLog = hyperOp(Hyper.iteratedlog)
TowerNum.arrow = hyperOp(Hyper.arrow)
TowerNum.pentate = hyperOp(Hyper.pentate)
TowerNum.hexate = hyperOp(Hyper.hexate)
TowerNum.anyarrowLog = hyperOp(Hyper.anyarrow_log)
TowerNum.pentaLog = hyperOp(Hyper.penta_log)
TowerNum.expansion = hyperOp(Hyper.expansion)
TowerNum.expansionArrow = hyperOp(Hyper.expansionArrow)
TowerNum.multiExpansion = hyperOp(Hyper.multiExpansion)
TowerNum.powerExpansion = hyperOp(Hyper.powerExpansion)
TowerNum.explosion = hyperOp(Hyper.explosion)
TowerNum.megotion = hyperOp(Hyper.megotion)
TowerNum.powiaination = hyperOp(Hyper.powiaination)
TowerNum.lambertw = hyperOp(Hyper.lambertw)
TowerNum.affordGeometricSeries = hyperOp(Hyper.affordGeometricSeries)
TowerNum.sumGeometricSeries = hyperOp(Hyper.sumGeometricSeries)
TowerNum.affordArithmeticSeries = hyperOp(Hyper.affordArithmeticSeries)
TowerNum.sumArithmeticSeries = hyperOp(Hyper.sumArithmeticSeries)

-- factorial and gamma: a table for 0! .. 170!, Lanczos for the rest of the doubles, Stirling past them (towers
-- included, in log space), the hyper tier's own past 10^^MSI
local FACT: { number } = { 1 }
for i = 1, 170 do FACT[i + 1] = FACT[i] * i end
local LANCZOS = { 0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
	-176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7 }
local HALF_LN_2PI = 0.9189385332046728
local PI = math.pi
local function lanczos(x: number): number   -- Gamma(x) for x >= 0.5
	x -= 1
	local sum = LANCZOS[1]
	for i = 1, 8 do sum += LANCZOS[i + 1] / (x + i) end
	local t = x + 7.5
	return 2.5066282746310002 * t ^ (x + 0.5) * exp(-t) * sum
end
-- log10 Gamma(x) for x >= 10 (Stirling with four terms: ~1e-17 relative there)
local function lgamma10(x: number): number
	local x2 = x * x
	local ln = (x - 0.5) * ln(x) - x + HALF_LN_2PI + 1 / (12 * x) - 1 / (360 * x * x2) + 1 / (1260 * x2 * x2 * x)
	return ln * LOG10E
end
function TowerNum.gamma(a: any): TowerNum
	if type(a) == "number" then
		if a ~= a or a == -huge then return 0 / 0 end
		if a == huge then return huge end
		if a <= 0 and a == floor(a) then return 0 / 0 end          -- the poles
		if a < 0.5 then
			-- reflection: Gamma(x) Gamma(1 - x) = pi / sin(pi x)
			local g = TowerNum.gamma(1 - a)
			local sp = math.sin(PI * a)
			return TowerNum.div(PI / sp, g)
		end
		if a == floor(a) and a <= 171 then return FACT[a] end
		if a <= 141 then return lanczos(a) end
		if a <= 171.62 then
			-- step down under 141 (where Lanczos' powers still fit) and multiply back up
			local v, p = a, 1
			while v > 141 do
				v -= 1
				p *= v
			end
			local g = lanczos(v) * p
			if g < MAX then return g end
		end
		return TowerNum.exp10(lgamma10(a))
	end
	a = res(a)
	if type(a) == "number" then return TowerNum.gamma(a) end
	if isH(a) or a.m < 0 then return hyp1(Hyper.gamma, a) end
	if a.l < 0 then return TowerNum.recip(a) end                    -- Gamma(tiny) = 1 / tiny
	-- a tower: log10 Gamma(x) = x (log10 x - log10 e) to every digit a double keeps
	return TowerNum.exp10(TowerNum.mul(a, TowerNum.sub(TowerNum.log10(a), LOG10E)))
end
function TowerNum.factorial(a: any): TowerNum
	if type(a) == "number" then
		if a >= 0 and a <= 170 and a == floor(a) then return FACT[a + 1] end
		return TowerNum.gamma(a + 1)
	end
	return TowerNum.gamma(TowerNum.add(a, 1))
end

-- ------------------------------------------------------------------------------------------------------------
-- converting and storing
-- ------------------------------------------------------------------------------------------------------------

-- the plain number (+-inf past 1.8e308, +-0 under 5.6e-309)
function TowerNum.toNumber(a: any): number
	if type(a) == "number" then return a end
	local v = if type(a) == "table" then a else fromAny(a)
	if type(v) == "number" then return v end
	if v.l > 0 then return if v.m > 0 then huge else -huge end
	return if v.m > 0 then 0 else -0
end

local SUFFIX_INDEX: { [string]: number } = {}   -- filled in with the formatter's suffixes (below)
local parseString: (string) -> TowerNum

-- 10^ applied k times (k whole, >= 0): the e's in front of "eee5" and the k of "(e^k)5". A number or a negative
-- turns into a positive tower within a few steps; from then on it is one layer count.
local function addLayers(v: TowerNum, k: number): TowerNum
	while k > 0 do
		if type(v) == "table" then
			local l, m = v.l, v.m
			if m > 0 and l >= 1 then
				if (v :: any).h == nil and l + k <= MSI then return { l = l + k, m = m } end
				return fromH(Hyper.tetrate(10, k, toH(v)))
			end
		elseif v ~= v then
			return v
		end
		v = TowerNum.exp10(v)
		k -= 1
	end
	return v
end

-- a run of decimal digits ("12.5", "-0.0003", "1000...0" with 400 zeros) -> its value, exactly as far as a double
-- goes, even when the digits run past 1.8e308 or under 5.6e-309
local function decimal(tok: string): TowerNum?
	local n = tonumber(tok)
	if n == nil or not sfind(tok, "^[%+%-]?%d*%.?%d*$") then return nil end
	if n ~= 0 and n < huge and n > -huge then
		if n > TINY or n < -TINY then return n end
	elseif n == 0 and not sfind(tok, "[1-9]") then
		return n
	end
	-- too many digits for a double: read the first 17 significant ones and count where the point is
	local neg = sbyte(tok, 1) == 45
	local digits = sgsub(tok, "[^%d%.]", "")
	local dot = sfind(digits, ".", 1, true)
	local intLen = if dot then dot - 1 else #digits
	local all = sgsub(digits, "%.", "")
	local first = sfind(all, "[1-9]")
	if not first then return 0 end
	local mant = tonumber("0." .. ssub(all, first, first + 16)) :: number
	local e = intLen - first + 1                    -- value = 0.mant * 10^e
	local v = TowerNum.mul(mant, TowerNum.exp10(e))
	return if neg then TowerNum.neg(v) else v
end

-- "a e b e c ..." (empty = 1, so "ee5" and "1ee5" work) = a * 10^(b * 10^(c ...)), worked from the right, so
-- 100,000 e's is 100,000 cheap steps rather than 100,000 nested calls
local function chain(str: string): TowerNum?
	if sfind(str, "E", 1, true) then str = sgsub(str, "E", "e") end
	local parts = string.split(str, "e")
	local n = #parts
	local last = parts[n]
	if last == "" then return nil end
	local v = decimal(last)
	if v == nil then return nil end
	local lead = 0
	while lead < n - 1 and parts[lead + 1] == "" do lead += 1 end
	for i = n - 1, lead + 1, -1 do
		local p = parts[i]
		v = TowerNum.exp10(v :: TowerNum)
		if p ~= "" then
			local mant = decimal(p)
			if mant == nil then return nil end
			v = TowerNum.mul(mant, v)
		end
	end
	return addLayers(v :: TowerNum, lead)
end

-- every operator a real one (PN's parser can produce a negative repeat from input like "K.9")
local function wellFormed(h: any): boolean
	local a = h.a
	for i = 2, #a do
		local op = a[i]
		local re, ar = op.re, op.ar
		if not (re >= 0 and ar >= 0 and op.ex >= 1 and op.me >= 1) then return false end
	end
	return true
end

local parseHyperCode: (string) -> TowerNum?          -- TowerNum.encode's hyper format, set below

local MAX_STRING = 20000                        -- no number needs more; bounds the work any input can cause
parseString = function(x: string): TowerNum
	if #x > MAX_STRING then error("TowerNum.from: string longer than " .. MAX_STRING .. " characters", 3) end
	-- "1.5e5000" / "2e-400": one match, straight to the tower
	local mant, ex = smatch(x, "^(%d+%.?%d*)[eE]([%+%-]?%d+)$")
	if mant then
		local mn, en = tonumber(mant) :: number, tonumber(ex) :: number
		if mn > 0 and mn < huge and en < 1e15 and en > -1e15 then
			local e = log10(mn) + en
			if e >= LOG_MAX then return { l = 1, m = e } end
			if e <= -LOG_MAX then return { l = -1, m = -e } end
			return 10 ^ e
		end
	end
	local str = x
	if sfind(str, "[%s,_]") then str = sgsub(str, "[%s,_]", "") end
	local neg = false
	local c = sbyte(str, 1)
	if c == 45 or c == 43 then                        -- "-" / "+"
		neg = c == 45
		str = ssub(str, 2)
		c = sbyte(str, 1)
	end
	local v: TowerNum? = nil
	if c == 84 then                                   -- "T": TowerNum.encode's own "Ts;l;m"
		local ss, ll, mm = smatch(str, "^T(%-?%d+);([%-%d%.e%+inf]+);(.+)$")
		local s1, l1, m1 = tonumber(ss), tonumber(ll), tonumber(mm)
		if s1 and l1 and m1 then v = build(norm(s1, l1, m1)) end
	elseif c == 72 then                               -- "H": a hyper value's code
		v = parseHyperCode(str)
	elseif ssub(str, 1, 4) == "10^^" and sbyte(str, 5) ~= 94 then
		local okH, h = pcall(fromAny, ssub(str, 5))
		if okH then v = TowerNum.tetrate10(h) end
	elseif ssub(str, 1, 3) == "(e^" then              -- (e^k)rest
		local k, rest = smatch(str, "^%(e%^(%d+)%)(.+)$")
		local kn = tonumber(k)
		if kn and rest then
			local okR, r = pcall(fromAny, rest)
			if okR then v = addLayers(r, kn) end
		end
	elseif sfind(str, "^[%d%.eE%+%-]+$") then
		v = chain(str)
	else
		local num, suf = smatch(str, "^([%d%.]+)(%a+)$")
		local k = suf and SUFFIX_INDEX[suf]
		local nn = num and tonumber(num)
		if nn and k then v = TowerNum.mul(nn, TowerNum.exp10(3 * k)) end
	end
	if v ~= nil then return if neg then TowerNum.neg(v) else v end
	-- everything PowiainaNum reads, as written: "10^^^5", "10{7}1e300", "J^3 5", "10{1,2}5", "/10{3}8" ...
	local h = Hyper.parse(x)
	if h ~= nil and h.a[1].re == h.a[1].re then
		-- PN's parser can leave a form its own arithmetic rewrites, and PN's normalize can need a second pass
		local okN, hn = pcall(Hyper.normalize, h)
		if okN then okN, hn = pcall(Hyper.normalize, hn) end
		if okN and wellFormed(hn) then return fromH(hn) end
	end
	error("TowerNum.from: cannot read " .. (if #x > 60 then ssub(x, 1, 60) .. "..." else x), 3)
end

-- anything -> TowerNum: numbers, towers, EternityNum tables, break_eternity-style tables, and strings:
--   "123", "1.5e300", "1.5e1000", "1e-5000", "e1e1000" (10^(1e1000)), "ee5.5", "(e^7)1.5e9", "10^^5.5", "2.5Qa",
--   "1.2K"
function TowerNum.from(x: any): TowerNum
	local t = type(x)
	if t == "number" then return x end
	if t == "table" then
		if x.h ~= nil then return x end                  -- a hyper value
		if x.a ~= nil and x.y ~= nil then return fromH(Hyper.normalize(Hyper.normalize(x))) end   -- a raw Hyper value
		if x.s ~= nil and x.l ~= nil and x.m ~= nil then return build(norm(x.s, x.l, x.m)) end   -- an older keyed form
		local l, m = x.l, x.m
		if l ~= nil and m ~= nil then                  -- a tower already (canonicalised, in case it was hand-made)
			if m ~= m then return m end
			if l ~= 0 and abs(m) >= LOG_MAX then return x end
			return build(norm(if m > 0 then 1 elseif m < 0 then -1 else 0, l, abs(m)))
		end
		if x.Sign ~= nil then return TowerNum.fromEN(x) end
		if x.sign ~= nil and x.layer ~= nil then       -- break_eternity { sign, layer, mag }: a negative mag on
			local sgn, lay, mag = x.sign, x.layer, x.mag   -- a layer >= 1 is a reciprocal
			if sgn == 0 then return 0 end
			if lay == 0 then return sgn * mag end
			if mag ~= mag then return mag end
			if mag < 0 then return build(norm(sgn, -lay, -mag)) end
			return build(norm(sgn, lay, mag))
		end
		error("TowerNum.from: unknown table", 2)
	end
	if t == "string" then
		-- the common case first: anything a double holds, straight from tonumber
		local n = tonumber(x)
		if n ~= nil then
			if n == n and n < huge and n > -huge then
				if n > TINY or n < -TINY then return n end
				if n == 0 and not sfind(x, "[1-9]") then return n end
			elseif n ~= n or sfind(x, "[Ii][Nn][Ff]") then
				return n                                  -- "nan", "inf", "-Infinity" as written
			end
		end
		return parseString(x :: string)
	end
	error("TowerNum.from: cannot read a " .. t, 2)
end
TowerNum.new = TowerNum.from
fromAny = TowerNum.from

-- DataStore-safe: a number stays a number, a tower becomes a short string ("T1;2;350.2461..."). decode reads
-- both back (and EternityNum tables, and the strings from() reads).
function TowerNum.encode(a: any): number | string
	if type(a) == "number" then
		if a ~= a or a == huge or a == -huge then return tostr(a) end   -- JSON has no inf / nan
		return a
	end
	if type(a) ~= "table" then
		a = res(a)
		if type(a) == "number" then return TowerNum.encode(a) end
	end
	local h = a.h
	if h ~= nil then
		-- "H<sign>;<layer>;<small>;<arrow>:<expans>:<megota>:<repeat>;..." with every number to 17 digits
		local ops = table.create(#h.a)
		for i, op in h.a do ops[i] = sfmt("%.17g:%.17g:%.17g:%.17g", op.ar, op.ex, op.me, op.re) end
		return sfmt("H%d;%.17g;%d;", h.s, h.y, if h.sm then 1 else 0) .. table.concat(ops, ";")
	end
	local s, l, m = tri(a)
	return sfmt("T%d;%.17g;%.17g", s, l, m)
end

local MAX_CODE_OPS = 512                           -- far more than any normal form holds; bounds decode's work
parseHyperCode = function(str: string): TowerNum?
	local parts = string.split(ssub(str, 2), ";")
	local n = #parts
	if n < 4 or n > MAX_CODE_OPS + 3 then return nil end
	local sg, y, sm = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
	if not (sg and y and sm) or (sg ~= 1 and sg ~= -1 and sg ~= 0) or y ~= floor(y) or y < 0 or y > MSI then return nil end
	local ops = table.create(n - 3)
	for i = 4, n do
		local ar, ex, me, re = smatch(parts[i], "^([^:]+):([^:]+):([^:]+):([^:]+)$")
		local a1, e1, m1, r1 = tonumber(ar), tonumber(ex), tonumber(me), tonumber(re)
		if not (a1 and e1 and m1 and r1) then return nil end
		if a1 ~= a1 or e1 ~= e1 or m1 ~= m1 or r1 ~= r1 or a1 < 0 or e1 < 1 or m1 < 1 or r1 < 0 then return nil end
		ops[i - 3] = { ar = a1, ex = e1, me = m1, re = r1 }
	end
	local ok, h = pcall(Hyper.normalize, { s = sg, y = y, sm = sm == 1, a = ops })
	if ok then ok, h = pcall(Hyper.normalize, h) end
	if not ok then return nil end
	return fromH(h)
end
function TowerNum.decode(v: any): TowerNum
	if type(v) == "string" then
		if v == "inf" then return huge elseif v == "-inf" then return -huge elseif v == "nan" or v == "-nan" then return 0 / 0 end
	end
	return TowerNum.from(v)
end

-- EternityNum { Sign, Layer, Exp } (value = Sign * 10^10^...^Exp with Layer tens; a negative Exp on a layer >= 1
-- is a reciprocal)
function TowerNum.fromEN(t: any): TowerNum
	local sgn, lay, ex = t.Sign, t.Layer, t.Exp
	if sgn == 0 or ex == 0 then return 0 end
	if lay == huge or ex == huge then return sgn * huge end
	if lay == 0 then return sgn * ex end
	if ex < 0 then return build(norm(sgn, -lay, -ex)) end
	return build(norm(sgn, lay, ex))
end
function TowerNum.toEN(a: any): { Sign: number, Layer: number, Exp: number }
	a = res(a)
	if isH(a) then
		-- EternityNum's own tallest: a tower as many tens high as a double counts (past that, its infinity)
		local s = if a.m > 0 then 1 else -1
		local hh = if s > 0 then a.h else Hyper.neg(a.h)
		if a.l < 0 then hh = Hyper.rec(hh) end
		local x = Hyper.slogOf(hh)
		if a.l < 0 then
			if x ~= x or x == huge then return { Sign = s, Layer = 0, Exp = 0 } end
			local w = floor(x)
			return { Sign = s, Layer = w, Exp = -(10 ^ (x - w)) }
		end
		if x ~= x or x == huge then return { Sign = s, Layer = huge, Exp = 1 } end
		local w = floor(x)
		return { Sign = s, Layer = w, Exp = 10 ^ (x - w) }
	end
	local s, l, m = tri(a)
	if s == 0 then return { Sign = 0, Layer = 0, Exp = 0 } end
	if l == huge then return { Sign = s, Layer = huge, Exp = 1 } end
	local inv = l < 0
	if inv then l = -l end
	-- EternityNum keeps each layer's Exp under 1e10
	while m >= 1e10 do
		m = log10(m)
		l += 1
	end
	if inv then return { Sign = s, Layer = l, Exp = -m } end
	if l == 0 and m < 1e-10 then return { Sign = s, Layer = 1, Exp = log10(m) } end
	return { Sign = s, Layer = l, Exp = m }
end

-- an integer that sorts like the value, for OrderedDataStore leaderboards (values >= 1; 0 below that).
-- Resolution: 1e-10 of a tower level, so 1.5e20 and 1.6e20 differ, while 1e1000 and 1.01e1000 do not.
-- Keys stay under 2^63 (OrderedDataStore's limit):
--   [0, 1e18)      towers up to 1e8 tens, 1e-10 of a level apart (unchanged from 1.0)
--   [1e18, 2e18)   up to the tallest tower, by the log of the height
--   [2e18, 3e18)   the hyper tier's towers of towers (10^^x up to x = 1.8e308), by the log of the height
--   [3e18, 8e18)   everything above, band by band (pentation 10^^^x, 10{4}x, ..., 10{!}x, expansions,
--                  multi-expansions, ...), ordered but coarse: two values in the same band may share a key
local function compress(v: number): number return v / (v + 1) end
local function hyperKey(h: any): number
	local a = h.a
	local top = a[#a]
	if h.y > 0 then return 7.5e18 + floor(compress(h.y) * 4.9e17) end
	if top.me > 1 then return 7e18 + floor(compress(top.me) * 4.9e17) end
	if top.ex > 1 then return 6.5e18 + floor(compress(top.ex) * 4.9e17) end
	local n = top.ar
	if n == huge then return 6.1e18 + floor(compress(top.re) * 3.9e17) end
	if n <= 2 then
		local x = Hyper.slogOf(h)
		if x == huge then return 3e18 - 1 end
		return 2e18 + floor(math.max(0, log10(x) - 15) / 294 * 1e18)
	end
	if n <= 32 then return 3e18 + (n - 3) * 1e17 + floor(compress(top.re) * 9.9e16) end
	return 6e18 + floor(compress(log10(n)) * 9.9e16)
end
function TowerNum.sortKey(a: any): number
	a = res(a)
	if type(a) == "number" and (a ~= a or a <= 0) then return 0 end
	if a == huge then return 9e18 end                 -- past everything
	if TowerNum.sign(a) <= 0 then return 0 end
	if isH(a) then
		if a.l < 0 then return 0 end
		return hyperKey(a.h)
	end
	local h = TowerNum.slog10(a)
	if h < 0 then return 0 end
	if h < 1e8 then return floor(h * 1e10) end
	return 1e18 + floor((log10(h) - 8) * 1e17)
end
-- the smallest value with that key (exact below 3e18, the bottom of the band above)
function TowerNum.fromSortKey(k: number): TowerNum
	if k < 1e18 then return TowerNum.tetrate10(k / 1e10) end
	if k < 2e18 then return TowerNum.tetrate10(10 ^ ((k - 1e18) / 1e17 + 8)) end
	if k < 3e18 then return TowerNum.tetrate10(10 ^ ((k - 2e18) / 1e18 * 294 + 15)) end
	if k < 6e18 then return fromH(Hyper.arrow(10, 3 + (k - 3e18) // 1e17, 10)) end
	return fromH(Hyper.from("10{!}10"))
end

-- ------------------------------------------------------------------------------------------------------------
-- FORMAT: TowerNum.format(a, opts?) — one call, a readable string for any size.
--
--   < 1,000                    123.45          (up to `digits` decimals, trailing zeros dropped)
--   < 10^(3 * #suffixes + 3)   1.50M, 45.2Qa   (short-scale suffixes, `digits` decimals, never rounded up)
--   < 10^(1e9)                 1.23e45,678     (scientific, the exponent grouped with commas)
--   bigger                     e1.23T, ee4.56Qa, eee7.89e123   ("e" = ten to the power of what follows)
--   more than `maxE` e's       (e^12)3.45K
--   taller than 1e6 tens       10^^1.23M       (the height of the tower of tens)
--
--   opts = {
--     digits    = 2,            decimals shown on mantissas
--     notation  = "suffix",     "suffix" | "scientific" | "engineering" (exponents in steps of 3)
--     suffixes  = { ... },      your own list, suffixes[k] for 10^(3k) (k = 1 is thousands); the default runs to
--                               Centillion (10^303); past the end of the list, scientific takes over
--     maxE      = 3,            e's written out before switching to (e^k)
--     commas    = true,         commas in plain numbers (12,345) and exponents
--   }
-- ------------------------------------------------------------------------------------------------------------

local UNITS = { "", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local TENS = { "", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog" }
local FIRST = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local DEFAULT_SUFFIXES: { string } = {}
for k = 1, 101 do                                 -- 10^3 .. 10^303 (Centillion)
	if k <= 10 then
		DEFAULT_SUFFIXES[k] = FIRST[k]
	elseif k == 101 then
		DEFAULT_SUFFIXES[k] = "Ce"
	else
		local n = k - 1                               -- the n-illion
		DEFAULT_SUFFIXES[k] = UNITS[n % 10 + 1] .. TENS[n // 10 % 10 + 1]
	end
end
TowerNum.SUFFIXES = DEFAULT_SUFFIXES
for k, s in DEFAULT_SUFFIXES do SUFFIX_INDEX[s] = k end

type Opts = { digits: number?, notation: string?, suffixes: { string }?, maxE: number?, commas: boolean? }

-- digit strings made once, so the common shapes are a table lookup and one concatenation instead of a
-- string.format: INT[n + 1] = "n" and PAD3[n + 1] = "00n" for 0..999; FRAC[d][f + 1] = ".ff" (d decimals) and
-- TRIM[d][f + 1] the same without its trailing zeros
local INT: { string } = table.create(1000)
local PAD3: { string } = table.create(1000)
for i = 0, 999 do
	INT[i + 1] = sfmt("%d", i)
	PAD3[i + 1] = sfmt("%03d", i)
end
local FRAC: { { string } } = {}
local TRIM: { { string } } = {}
for d = 1, 3 do
	local f, t = table.create(10 ^ d), table.create(10 ^ d)
	for i = 0, 10 ^ d - 1 do
		local str = sfmt("%0" .. d .. "d", i)
		f[i + 1] = "." .. str
		local k = #str
		while k > 0 and sbyte(str, k) == 48 do k -= 1 end
		t[i + 1] = if k == 0 then "" else "." .. ssub(str, 1, k)
	end
	FRAC[d], TRIM[d] = f, t
end

-- 1234567 -> "1,234,567" (whole numbers only)
local function commas(n: number): string
	if n >= 0 and n < 1e9 then
		if n < 1000 then return INT[n + 1] end
		if n < 1e6 then return INT[n // 1000 + 1] .. "," .. PAD3[n % 1000 + 1] end
		return INT[n // 1e6 + 1] .. "," .. PAD3[(n // 1000) % 1000 + 1] .. "," .. PAD3[n % 1000 + 1]
	end
	local s = sfmt("%d", n)
	local len = #s
	if len <= 3 then return s end
	local head = len % 3
	if head == 0 then head = 3 end
	local parts = { s:sub(1, head) }
	for i = head + 1, len, 3 do
		parts[#parts + 1] = s:sub(i, i + 2)
	end
	return table.concat(parts, ",")
end

-- 10^d for the decimal counts format takes (0..15), made once
local P10: { [number]: number } = {}
for d = 0, 15 do P10[d] = 10 ^ d end

-- "%.<d>f" format strings, made once
local FIXED: { string } = {}
for d = 0, 20 do FIXED[d + 1] = "%." .. d .. "f" end
local function fixedFmt(digits: number): string
	return FIXED[digits + 1] or ("%." .. digits .. "f")
end

-- the whole number ti (a value times 10^digits) written with `digits` decimals: exactly string.format("%.<d>f",
-- ti / 10^digits), from the tables when it is under 1000
local function fixedDigits(ti: number, digits: number, p: number): string
	local ip = ti // p
	if ip < 1000 and digits <= 3 then
		if digits == 0 then return INT[ip + 1] end
		return INT[ip + 1] .. FRAC[digits][ti - ip * p + 1]
	end
	return sfmt(fixedFmt(digits), ti / p)
end

-- a mantissa cut (not rounded) to `digits` decimals: 999.999 never shows as 1000.00
local function cut(v: number, digits: number): string
	local p = P10[digits] or 10 ^ digits
	return fixedDigits(floor(v * p * (1 + 1e-12)), digits, p)
end

local function plain(v: number, digits: number, useCommas: boolean): string
	local p = P10[digits] or 10 ^ digits
	local ti = floor(v * p * (1 + 1e-12))
	local ip = ti // p
	local fp = ti - ip * p
	if ip < 1000 and digits <= 3 then
		if fp == 0 or digits == 0 then return INT[ip + 1] end
		return INT[ip + 1] .. TRIM[digits][fp + 1]
	end
	local t = ti / p
	if t == floor(t) then
		return if useCommas then commas(t) else sfmt("%d", t)
	end
	local s = sfmt(fixedFmt(digits), t)
	local i = #s
	while string.byte(s, i) == 48 do i -= 1 end      -- trailing zeros (a decimal point always precedes them)
	return string.sub(s, 1, i)
end

-- a value given as its log10 E (E >= 3, finite): suffix / scientific / engineering
local function fromLog(E: number, o: Opts): string
	local digits = o.digits :: number
	local e = floor(E + 1e-12)
	if o.notation == "suffix" then
		local k = e // 3
		local list = o.suffixes :: { string }
		if k >= 1 and k <= #list then
			local mant = 10 ^ (E - 3 * k)
			local p = P10[digits] or 10 ^ digits
			local ti = floor(mant * p * (1 + 1e-12))
			if ti >= 1000 * p and list[k + 1] then
				return cut(mant / 1000, digits) .. list[k + 1]
			end
			return fixedDigits(ti, digits, p) .. list[k]
		end
	end
	if o.notation == "engineering" then
		local k = e - e % 3
		return cut(10 ^ (E - k), digits) .. "e" .. (if o.commas then commas(k) else sfmt("%d", k))
	end
	local mant = 10 ^ (E - e)
	if mant >= 10 then mant /= 10; e += 1 end
	return cut(mant, digits) .. "e" .. (if o.commas then commas(e) else sfmt("%d", e))
end

-- something written as a number with no "e" in front: a double, or a tower one layer up with a modest exponent
local SCI_LIMIT = 1e9
local formatHyper: (any, Opts, Opts?) -> string
local function writeNumber(v: number, o: Opts): string
	if v < 1000 then
		if v > 0 and v < 1e-3 then
			local e = floor(log10(v))
			return cut(v / 10 ^ e, o.digits :: number) .. "e" .. e
		end
		return plain(v, o.digits :: number, o.commas == true)
	end
	return fromLog(log10(v), o)
end

-- the hyper tier, written the way googologists do, highest operator first:
--   10^^1.23Qa (a tower 1.23e15+ tens tall), 10^^^5.00, (10^^^)^3 10^^1.5e20, 10{7}12.0, 10{!}3.00, 10{2,3}8.00 ...
local function opName(op: any): string
	local ar, ex, me = op.ar, op.ex, op.me
	local arS = if ar == huge then "!" else sfmt("%.17g", ar)
	if ex == 1 and me == 1 then
		if ar == 2 then return "^^" elseif ar == 3 then return "^^^" elseif ar == 4 then return "^^^^" end
		return "{" .. arS .. "}"
	end
	local exS = if ex == huge then "!" else sfmt("%.17g", ex)
	if me == 1 then return "{" .. arS .. "," .. exS .. "}" end
	return "{" .. arS .. "," .. exS .. "," .. (if me == huge then "!" else sfmt("%.17g", me)) .. "}"
end
local MAX_GROUPS = 3
formatHyper = function(h: any, o: Opts, opts: Opts?): string
	local sign = if h.s < 0 then "-" else ""
	if h.sm then
		return sign .. "1 / " .. formatHyper(Hyper.rec(Hyper.abs(h)), o, opts)
	end
	if h.y > 0 then return sign .. Hyper.toString(Hyper.abs(h)) end
	local a = h.a
	local parts = {}
	local i = #a
	local groups = 0
	while i >= 2 do
		local op = a[i]
		if op.re ~= 0 and not (op.ar <= 1 and op.ex == 1 and op.me == 1) then
			groups += 1
			if groups > MAX_GROUPS then
				parts[#parts + 1] = "..."
				return sign .. table.concat(parts, " ")
			end
			local r = op.re
			if r == 1 then
				parts[#parts + 1] = "10" .. opName(op)
			else
				parts[#parts + 1] = "(10" .. opName(op) .. ")^" .. writeNumber(r, o)
			end
		elseif op.re ~= 0 then
			break
		end
		i -= 1
	end
	-- what is left under the operators: an ordinary tower (or number), written as one
	local rest = table.move(a, 1, i, 1, table.create(i))
	local tail = fromH({ s = 1, y = 0, sm = false, a = rest })
	if type(tail) == "table" and tail.h ~= nil then return sign .. Hyper.toString(Hyper.abs(h)) end
	local body = TowerNum.format(tail, opts)
	-- "10^^" followed directly by its height reads best without a space
	local n = #parts
	if n > 0 then
		local lastP = parts[n]
		if sfind(lastP, "^10[%^{]") and not sfind(lastP, "^%(") then
			parts[n] = lastP .. body
			return sign .. table.concat(parts, " ")
		end
	end
	parts[n + 1] = body
	return sign .. table.concat(parts, " ")
end

local DEFAULT_OPTS: Opts = { digits = 2, notation = "suffix", suffixes = DEFAULT_SUFFIXES, maxE = 3, commas = true }

function TowerNum.format(a: any, opts: Opts?): string
	local o: Opts = DEFAULT_OPTS
	if opts then
		local d = opts.digits or 2
		if type(d) ~= "number" or d ~= d then d = 2 end
		d = if d < 0 then 0 elseif d > 15 then 15 else floor(d)
		o = {
			digits = d, notation = opts.notation or "suffix", suffixes = opts.suffixes or DEFAULT_SUFFIXES,
			maxE = opts.maxE or 3, commas = if opts.commas == nil then true else opts.commas,
		}
	end
	if type(a) == "number" then
		-- plain numbers straight through (the common case: no triple, no table)
		if a > 0 then
			if a < huge then return writeNumber(a, o) end
			return "Infinity"
		elseif a < 0 then
			if a > -huge then return "-" .. writeNumber(-a, o) end
			return "-Infinity"
		elseif a == 0 then
			return "0"
		end
		return "NaN"
	end
	if type(a) ~= "table" then a = res(a) end
	if type(a) == "table" and a.h ~= nil then return formatHyper(a.h, o, opts) end
	local s, l, m = tri(a)
	if s == 0 then return "0" end
	local sign = if s < 0 then "-" else ""
	if l == huge then return sign .. "Infinity" end
	if l == 0 then return sign .. writeNumber(m, o) end
	if l < 0 then
		-- tiny: 1.23e-4,567 while the exponent is modest, else 1 / (the huge one)
		if l == -1 and m < SCI_LIMIT then
			local E = -m
			local e = floor(E + 1e-12)
			local mant = 10 ^ (E - e)
			if mant >= 10 then mant /= 10; e += 1 end
			return sign .. cut(mant, o.digits :: number) .. "e-" .. (if o.commas then commas(-e) else sfmt("%d", -e))
		end
		return sign .. "1 / " .. TowerNum.format({ l = -l, m = m }, opts)
	end
	-- peel e's until what is left can be written as a number: a double, or 10^E with E < SCI_LIMIT
	if l > 1e6 then
		return sign .. "10^^" .. writeNumber(TowerNum.slog10({ l = l, m = m }), o)   -- the height of |a|
	end
	local k = 0
	while l > 1 or (l == 1 and m >= SCI_LIMIT) do
		if l == 1 then
			l = 0                                        -- the exponent itself, a plain number
		else
			l -= 1
		end
		k += 1
	end
	local body = if l == 0 then writeNumber(m, o) else fromLog(m, o)
	if k == 0 then return sign .. body end
	if k <= (o.maxE :: number) then return sign .. srep("e", k) .. body end
	return sign .. "(e^" .. k .. ")" .. body
end
TowerNum.short = TowerNum.format
TowerNum.toString = TowerNum.format

TowerNum.ZERO = 0
TowerNum.ONE = 1
TowerNum.INF = huge

return TowerNum
