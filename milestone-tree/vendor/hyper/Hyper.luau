--!strict
--!native
--!optimize 2
--[==[
	Hyper — a Luau port of PowiainaNum.js 0.2.30 (numbers up to {10,9e15,1,1,1,2}).

	VALUES
	    A Hyper value is a plain table (no metatable, no methods):
	        { s  = sign: 1 or -1, and 0 for zero and NaN (exactly PN's `sign`),
	          y  = layer (PN's `layer`, a non-negative integer),
	          sm = small (PN's `small`: the value is the reciprocal of what the array describes),
	          a  = { op, op, ... } }        -- PN's `array`, same order: a[1] is PN's array[0] (the base)
	    and each op is { ar = arrow, ex = expans, me = megota, re = repeat }. PN's per-operator `valuereplaced`
	    is written by PN but never read by any PN code path, so it is not carried.
	    Nothing here mutates a value it is given: every function returns a new value or one of its inputs
	    unchanged, so values can be shared and cached freely (do not mutate them yourself). Constants
	    (Hyper.ZERO, Hyper.ONE, ...) are frozen.

	    Wherever PN accepts a PowiainaNum-coercible argument, these functions accept a Hyper value, a Luau number,
	    a string (anything PN's constructor parses: "123", "1e114514", "eee5", "(10^^^)^114514 e1919810",
	    "10{!}e5", "10{1,2}5", "10{1,514,114}5", "/1e5", "P^3 10", "(e^5)3", "5PT3", "J^3 5", "PN10{2}5",
	    "l0 s1 a[10,[114,514,1919,810]]", ...), or an object form (Hyper.from).

	API (a, b, ...: Hyper | number | string | object form)
	    convert     from fromNumber fromString(PN constructor: NaN if malformed) parse(nil if malformed)
	                fromObject normalize toString toJSON toNumber isHyper getOperator setOperator getOperatorIndex
	    arithmetic  abs neg rec add sub mul div mod pow pow10 pow_base root sqrt cbrt exp
	                log10 log(a, base = e) ln log2 logBase pLog10 floor ceil round trunc
	    compare     cmp(=compare) eq neq lt lte gt gte cmpabs max min maxabs minabs clamp clampMin clampMax
	                maxN minN eq_tolerance
	    predicates  isNaN isZero isFinite isInfi isInfiNaN isInt ispos isneg sign
	    special     factorial gamma lambertw(a, principal = true)
	    hyper       tetrate(a, h, payload) tetrate_10 slog(a, base = 10) ssqrt iteratedlog(a, n, base)
	                arrow(a, arrows, b, payload) chain pentate hexate anyarrow_log(a, arrows, base)
	                arrow_height_inverse penta_log omegalog(a, base, eps) arrFrac
	                expansion expansionArrow(a, arrows, b) multiExpansion powerExpansion expansion_log_inner
	                expansion_log2(a, arrows, base) omega2log arrw2Frac explosion megotion powiaination
	                BEAF(base, power, arrow, expans, megota, powiaina, ...) BEAF_core grahalFunction
	    series      affordGeometricSeries sumGeometricSeries affordArithmeticSeries sumArithmeticSeries
	    bridging    tetr10(x) = the PN value of 10^^x; slogOf(h) = PN's slog(h, 10) as a number
	    Not ported: sin cos tan cot sec csc (by request), fromBigInt (Luau has no BigInt), hyper() (returns
	    functions; use arrow), the arr01 getter.

	SEMANTICS
	    A line-by-line port: normal form (normalize), control flow, loop limits, the order of floating point
	    operations, error cases, and even PN's in-place aliasing *inside* one call (slog() rewrites its receiver
	    and pentation relies on that) are reproduced; a few hot paths (add/sub/mul/pow10/log10/toString/cmp on
	    plain and [r, (10^)^k] shapes) use exact re-derivations of PN's decisions instead of the generic code.
	    The reference is PN with its shared-mutable-state bugs removed (hyper/pnref.mjs): stock PN mutates its
	    static constants (add() writes into PowiainaNum.NaN) and its arrow/BEAF memo caches hand out objects that
	    callers then modify, so stock PN's answers depend on what was computed before. Hyper has no such state.
	    Errors PN throws (lambertw failing to converge, anyarrow_log with > 2^53 arrows, ...) are raised with
	    error(); malformed strings give NaN from the constructor forms exactly like `new PowiainaNum(str)`.

	    Deliberate deviations, all where PN never returns or effectively never returns:
	      * normalize() gives up after NORMALIZE_CAP passes and yields NaN. PN loops forever instead, e.g. on a
	        single negative repeat (fromObject {{0,-5}}, "/-1", "10{!,!}5", a break_eternity object with a
	        negative mag): it keeps flipping `small`.
	      * arrow() with a non-integer arrow count and other > base: PN's arrowpsdInv recurses on identical
	        arguments until the JS stack overflows (RangeError). Hyper raises that error immediately.
	      * Work budget: PN caps each loop at 100 passes but nests them once per arrow level, so some inputs
	        (e.g. expansion_log2 or omegalog with bases below 1, deep hexation of numbers near 1) run for minutes
	        or effectively forever. Each public call gets FUEL_MAX = 4e6 work units (hyper-operator loop passes
	        and recursive calls, normalize passes and copies weighted by operator count, number conversions)
	        and raises "Hyper: work budget exceeded ..." when they run out. Over 300k differential cases the
	        largest need of an input PN finishes within 1 s was 2.04e6 units (0.5 s); inputs PN did not finish
	        within 1 s end within 3.3 s (luau -O2, interpreted, on a slow test machine).
	    Strings are parsed in linear time (PN is quadratic or worse on some long strings: its validation regex
	    backtracks and it re-slices the input on every token); results are identical. The J/K/L/M/N shorthands
	    are not expanded (each stands for a 5-7 character operator), and a long operator prefix is kept as
	    parallel arrays until normalize's first sort-and-merge has shrunk it, so no table is made per operator.

	FLOATING POINT
	    Luau's math.log10/log/exp/^ come from the platform C library, V8's from its fdlibm port. Both are within
	    an ulp but not always the same ulp, so a repeat that went through them can differ from PN's in the last
	    bits. A few PN algorithms amplify that noise without bound (they take fractional parts of huge doubles
	    level after level, e.g. arrow(15, 61, 2.5)); there PN's own lower operators change completely under a
	    1-ulp change of any libm result, and only the top operators are meaningful. hyper/diff.luau measures
	    this against PN itself, see its header.
]==]

local Hyper = {}

local floor, ceil, mabs, log10, mlog, mexp, fmod = math.floor, math.ceil, math.abs, math.log10, math.log, math.exp, math.fmod
local huge = math.huge
local NAN = 0 / 0
local tinsert, tremove, tmove, tconcat, tfreeze = table.insert, table.remove, table.move, table.concat, table.freeze
local sbyte, ssub, srep, sfind, smatch, sformat = string.byte, string.sub, string.rep, string.find, string.match, string.format
local tostr = tostring

local MSI = 9007199254740991
local MSI_LOG10 = 15.954589770191003
local MSI_REC = 1.1102230246251568e-16
local LONG_STRING_MIN_LENGTH = 17
local EXP_E_REC = 1.444667861009766
local MATH_E = 2.718281828459045
local OMEGA = 0.56714329040978387299997
local LOG10_MAX_VALUE = 308.25471555991675 -- Math.log10(Number.MAX_VALUE)
local MAXOPS = 100
local PN_ERR = "[PowiainaNum 0.2 error]"
local NORMALIZE_CAP = 1000
-- the fix to PN's shrinking normalize at MAXOPS (see normalize); off = PN exactly (the differential harness uses
-- it to prove the fix is the only difference)
local CAP_FIX = true
local capFixHits = 0
local Hyper_setCapFix = function(on: boolean)
	CAP_FIX = on
end
local Hyper_capFixHits = function(reset: boolean?): number
	local n = capFixHits
	if reset then capFixHits = 0 end
	return n
end
Hyper.NORMALIZE_CAP = NORMALIZE_CAP

-- Work budget (see the header): every public function starts with FUEL_MAX units.
local FUEL_MAX = 4000000
local fuel = FUEL_MAX
function Hyper._setFuelMax(n: number)
	FUEL_MAX = n
end
local function burn(w: number?)
	fuel -= w or 1
	if fuel < 0 then
		error("Hyper: work budget exceeded (PowiainaNum takes an impractically long time on this input)")
	end
end
local function refuel()
	fuel = FUEL_MAX
end
function Hyper._fuelUsed(): number
	return FUEL_MAX - fuel
end
function Hyper._refuel()
	fuel = FUEL_MAX
end

export type Op = { ar: number, ex: number, me: number, re: number }
export type Hyper = { s: number, y: number, sm: boolean, a: { Op } }

--------------------------------------------------------------------------------------------------------------
-- JS number semantics helpers
--------------------------------------------------------------------------------------------------------------

local function isFin(x: number): boolean
	return x == x and x ~= huge and x ~= -huge
end

local function isInteger(x: number): boolean -- Number.isInteger
	return x == x and x ~= huge and x ~= -huge and floor(x) == x
end

local function jpow(a: number, b: number): number -- Math.pow
	if b ~= b then
		return NAN
	end
	if (b == huge or b == -huge) and (a == 1 or a == -1) then
		return NAN
	end
	return a ^ b
end

local function jround(x: number): number -- Math.round
	if x ~= x or x == huge or x == -huge then
		return x
	end
	local r = floor(x)
	if x - r >= 0.5 then
		r += 1
	end
	if r == 0 and (x < 0 or 1 / x < 0) then
		return -0.0
	end
	return r
end

local function jtrunc(x: number): number
	if x >= 0 then
		return floor(x)
	end
	return ceil(x)
end

local function truthy(v: any): boolean -- JS truthiness for numbers / nil
	return v ~= nil and v ~= 0 and v == v and v ~= false
end

-- Number.prototype.toString(): Luau's tostring already produces the shortest round-trip digits; re-layout them
-- the way ECMAScript's Number::toString does.
local function numstr(x: number): string
	if x ~= x then
		return "NaN"
	end
	if x == 0 then
		return "0"
	end
	if x == huge then
		return "Infinity"
	end
	if x == -huge then
		return "-Infinity"
	end
	if x < 0 then
		return "-" .. numstr(-x)
	end
	local s = tostr(x)
	if not sfind(s, "e", 1, true) then
		-- Luau prints fixed notation only inside JS's fixed range (1e-6 <= x < 1e21), with the same digits
		return s
	end
	local mant, ex = smatch(s, "^([%d%.]+)[eE]([%+%-]?%d+)$")
	local e: number
	if mant then
		e = tonumber(ex) :: number
	else
		mant = s
		e = 0
	end
	local dot = sfind(mant :: string, ".", 1, true)
	local ip, fp
	if dot then
		ip = ssub(mant :: string, 1, dot - 1)
		fp = ssub(mant :: string, dot + 1)
	else
		ip = mant :: string
		fp = ""
	end
	local digits = ip .. fp
	local n = #ip + e
	local lz = #(smatch(digits, "^0*") :: string)
	if lz > 0 then
		digits = ssub(digits, lz + 1)
		n -= lz
	end
	digits = smatch(digits, "^(.-)0*$") :: string
	local k = #digits
	if k <= n and n <= 21 then
		return digits .. srep("0", n - k)
	elseif 0 < n and n <= 21 then
		return ssub(digits, 1, n) .. "." .. ssub(digits, n + 1)
	elseif -6 < n and n <= 0 then
		return "0." .. srep("0", -n) .. digits
	end
	local ee = n - 1
	local es = if ee < 0 then "-" .. sformat("%d", -ee) else "+" .. sformat("%d", ee)
	if k == 1 then
		return digits .. "e" .. es
	end
	return ssub(digits, 1, 1) .. "." .. ssub(digits, 2) .. "e" .. es
end
Hyper._numstr = numstr

-- ECMAScript WhiteSpace + LineTerminator at byte i (UTF-8); returns its byte length or 0.
local function wsLen(s: string, i: number): number
	local b = sbyte(s, i)
	if b == nil then
		return 0
	end
	if b == 32 or (b >= 9 and b <= 13) then
		return 1
	end
	if b < 0xC2 then
		return 0
	end
	local b1, b2 = sbyte(s, i + 1, i + 2)
	if b == 0xC2 then
		return if b1 == 0xA0 then 2 else 0
	elseif b == 0xE1 then
		return if b1 == 0x9A and b2 == 0x80 then 3 else 0
	elseif b == 0xE2 then
		if b1 == 0x80 and b2 and ((b2 >= 0x80 and b2 <= 0x8A) or b2 == 0xA8 or b2 == 0xA9 or b2 == 0xAF) then
			return 3
		end
		if b1 == 0x81 and b2 == 0x9F then
			return 3
		end
		return 0
	elseif b == 0xE3 then
		return if b1 == 0x80 and b2 == 0x80 then 3 else 0
	elseif b == 0xEF then
		return if b1 == 0xBB and b2 == 0xBF then 3 else 0
	end
	return 0
end

-- line terminator (for regex `.`): \n \r U+2028 U+2029 ; returns byte length or 0
local function ltLen(s: string, i: number): number
	local b = sbyte(s, i)
	if b == 10 or b == 13 then
		return 1
	end
	if b == 0xE2 then
		local b1, b2 = sbyte(s, i + 1, i + 2)
		if b1 == 0x80 and (b2 == 0xA8 or b2 == 0xA9) then
			return 3
		end
	end
	return 0
end

local function isDigit(b: number?): boolean
	return b ~= nil and b >= 48 and b <= 57
end

local jsNumber: (string) -> number
do
local function jsTrim(s: string): string
	local n = #s
	local i = 1
	while i <= n do
		local l = wsLen(s, i)
		if l == 0 then
			break
		end
		i += l
	end
	local j = n
	while j >= i do
		local b = sbyte(s, j)
		if b == 32 or (b >= 9 and b <= 13) then
			j -= 1
		elseif j - 1 >= i and wsLen(s, j - 1) == 2 then
			j -= 2
		elseif j - 2 >= i and wsLen(s, j - 2) == 3 then
			j -= 3
		else
			break
		end
	end
	return ssub(s, i, j)
end


-- exact binary/octal/hex digit string -> correctly rounded double
local function radixToNumber(d: string, bitsPer: number): number
	local n = #d
	local i = 1
	while i <= n and sbyte(d, i) == 48 do
		i += 1
	end
	if i > n then
		return 0
	end
	-- collect bits
	local bits: { number } = table.create((n - i + 1) * bitsPer) :: { number }
	for k = i, n do
		local c = sbyte(d, k) :: number
		local v
		if c <= 57 then
			v = c - 48
		elseif c >= 97 then
			v = c - 87
		else
			v = c - 55
		end
		for sh = bitsPer - 1, 0, -1 do
			bits[#bits + 1] = bit32.extract(v, sh, 1)
		end
	end
	local p = 1
	while bits[p] == 0 do
		p += 1
	end
	local total = #bits - p + 1
	if total <= 53 then
		local v = 0
		for k = p, #bits do
			v = v * 2 + bits[k]
		end
		return v
	end
	local m = 0
	for k = p, p + 52 do
		m = m * 2 + bits[k]
	end
	local guard = bits[p + 53]
	local sticky = 0
	for k = p + 54, #bits do
		if bits[k] == 1 then
			sticky = 1
			break
		end
	end
	if guard == 1 and (sticky == 1 or m % 2 == 1) then
		m += 1
	end
	local ex = total - 53
	if ex > 1100 then
		return huge
	end
	return m * 2 ^ ex
end

-- Number(string)
function jsNumber(s: string): number
	-- plain decimal digits (with an optional point): the C parser rounds exactly like ECMAScript
	if sfind(s, "^%d*%.?%d*$") and sfind(s, "%d") then
		return tonumber(s) :: number
	end
	local t = jsTrim(s)
	local n = #t
	if n == 0 then
		return 0
	end
	local b1, b2 = sbyte(t, 1, 2)
	if b1 == 48 and n >= 3 and b2 then
		local bp = 0
		local pat = ""
		if b2 == 120 or b2 == 88 then
			bp = 4
			pat = "^[0-9a-fA-F]+$"
		elseif b2 == 111 or b2 == 79 then
			bp = 3
			pat = "^[0-7]+$"
		elseif b2 == 98 or b2 == 66 then
			bp = 1
			pat = "^[01]+$"
		end
		if bp > 0 then
			local d = ssub(t, 3)
			if not sfind(d, pat) then
				return NAN
			end
			return radixToNumber(d, bp)
		end
	end
	local sign = 1
	local k = 1
	if b1 == 43 then
		k = 2
	elseif b1 == 45 then
		sign = -1
		k = 2
	end
	local rest = if k == 1 then t else ssub(t, k)
	if rest == "Infinity" then
		return sign * huge
	end
	-- StrUnsignedDecimalLiteral: digits [. digits] | . digits, then optional exponent
	local rn = #rest
	local i = 1
	local nd = 0
	while i <= rn and isDigit(sbyte(rest, i)) do
		i += 1
		nd += 1
	end
	if sbyte(rest, i) == 46 then
		i += 1
		while i <= rn and isDigit(sbyte(rest, i)) do
			i += 1
			nd += 1
		end
	end
	if nd == 0 then
		return NAN
	end
	local c = sbyte(rest, i)
	if c == 101 or c == 69 then
		i += 1
		c = sbyte(rest, i)
		if c == 43 or c == 45 then
			i += 1
		end
		local ed = 0
		while i <= rn and isDigit(sbyte(rest, i)) do
			i += 1
			ed += 1
		end
		if ed == 0 then
			return NAN
		end
	end
	if i <= rn then
		return NAN
	end
	local v = tonumber(rest)
	if v == nil then
		return NAN
	end
	return sign * v
end
end
Hyper._jsNumber = jsNumber

-- String.prototype.repeat count semantics; nil means RangeError
local function jsRepeat(s: string, n: number): string?
	if n ~= n then
		n = 0
	end
	local c = jtrunc(n)
	if c < 0 or c == huge then
		return nil
	end
	return srep(s, c)
end

--------------------------------------------------------------------------------------------------------------
-- A tiny regex -> lazy DFA compiler (full-match only). Used for PN's validation regexes, so a hostile string
-- is checked in linear time with one table lookup per byte.
--------------------------------------------------------------------------------------------------------------

-- PN's J/K/L/M/N shorthands and the operator text each one stands for
local LETTER_REP: { [string]: string } = { J = "10{!}", K = "10{1,2}", L = "10{2,2}", M = "10{!,2}", N = "10{1,!}" }

local reIsPowiainaNum: (string) -> boolean
-- the same test on the string with every J/K/L/M/N replaced by its LETTER_REP text (without building it)
local reIsPowiainaNumL: (string) -> boolean
local reBE: (string) -> boolean
local reZero: (string) -> boolean
do
local function compileRegex(pat: string): ((string) -> boolean, (string) -> boolean)
	local pos = 1
	local n = #pat
	local cls: { [number]: { [number]: boolean } } = {}
	local out: { [number]: number } = {}
	local eps: { [number]: { number } } = {}
	local ns = 0
	local function newState(): number
		ns += 1
		eps[ns] = {}
		return ns
	end
	local function classOf(set: { [number]: boolean })
		local s = newState()
		local e = newState()
		cls[s] = set
		out[s] = e
		return s, e
	end
	local DIG = {}
	for b = 48, 57 do
		DIG[b] = true
	end
	local parseAlt: () -> (number, number)
	local function parseAtom(): (number, number)
		local c = ssub(pat, pos, pos)
		if c == "(" then
			pos += 1
			local s, e = parseAlt()
			assert(ssub(pat, pos, pos) == ")", "regex: missing )")
			pos += 1
			return s, e
		elseif c == "[" then
			pos += 1
			local neg = false
			if ssub(pat, pos, pos) == "^" then
				neg = true
				pos += 1
			end
			local set = {}
			local first = true
			while first or ssub(pat, pos, pos) ~= "]" do
				first = false
				local ch = ssub(pat, pos, pos)
				local lo: number
				if ch == "\\" then
					local e2 = ssub(pat, pos + 1, pos + 1)
					pos += 2
					if e2 == "d" then
						for b = 48, 57 do
							set[b] = true
						end
						continue
					end
					lo = sbyte(e2) :: number
				else
					lo = sbyte(ch) :: number
					pos += 1
				end
				if ssub(pat, pos, pos) == "-" and ssub(pat, pos + 1, pos + 1) ~= "]" then
					local hi = sbyte(pat, pos + 1) :: number
					pos += 2
					for b = lo, hi do
						set[b] = true
					end
				else
					set[lo] = true
				end
			end
			pos += 1
			if neg then
				local s2 = {}
				for b = 0, 255 do
					if not set[b] then
						s2[b] = true
					end
				end
				set = s2
			end
			return classOf(set)
		elseif c == "\\" then
			local e2 = ssub(pat, pos + 1, pos + 1)
			if e2 == "d" then
				pos += 2
				return classOf(DIG)
			elseif e2 == "x" then
				local v = tonumber(ssub(pat, pos + 2, pos + 3), 16) :: number
				pos += 4
				return classOf({ [v] = true })
			end
			pos += 2
			return classOf({ [sbyte(e2) :: number] = true })
		elseif c == "." then
			pos += 1
			local set = {}
			for b = 0, 255 do
				if b ~= 10 and b ~= 13 then
					set[b] = true
				end
			end
			return classOf(set)
		end
		pos += 1
		return classOf({ [sbyte(c) :: number] = true })
	end
	local function parseRepeat(): (number, number)
		local s, e = parseAtom()
		while true do
			local q = ssub(pat, pos, pos)
			if q == "*" then
				pos += 1
				local s2, e2 = newState(), newState()
				table.insert(eps[s2], s)
				table.insert(eps[s2], e2)
				table.insert(eps[e], s)
				table.insert(eps[e], e2)
				s, e = s2, e2
			elseif q == "+" then
				pos += 1
				local e2 = newState()
				table.insert(eps[e], s)
				table.insert(eps[e], e2)
				e = e2
			elseif q == "?" then
				pos += 1
				local s2, e2 = newState(), newState()
				table.insert(eps[s2], s)
				table.insert(eps[s2], e2)
				table.insert(eps[e], e2)
				s, e = s2, e2
			else
				break
			end
		end
		return s, e
	end
	local function parseConcat(): (number, number)
		local s = newState()
		local e = s
		while pos <= n do
			local c = ssub(pat, pos, pos)
			if c == "|" or c == ")" then
				break
			end
			if c == "$" and pos == n then
				pos += 1
				break
			end
			local s2, e2 = parseRepeat()
			table.insert(eps[e], s2)
			e = e2
		end
		return s, e
	end
	function parseAlt(): (number, number)
		local s, e = parseConcat()
		if ssub(pat, pos, pos) ~= "|" then
			return s, e
		end
		local S, E = newState(), newState()
		table.insert(eps[S], s)
		table.insert(eps[e], E)
		while ssub(pat, pos, pos) == "|" do
			pos += 1
			local s2, e2 = parseConcat()
			table.insert(eps[S], s2)
			table.insert(eps[e2], E)
		end
		return S, E
	end
	if ssub(pat, 1, 1) == "^" then
		pos = 2
	end
	local start, accept = parseAlt()
	assert(pos > n, "regex: trailing input")

	-- lazy DFA
	local byKey: { [string]: any } = {}
	local function closure(list: { number })
		local seen = {}
		local stack = table.clone(list)
		local res = {}
		while #stack > 0 do
			local st = table.remove(stack) :: number
			if not seen[st] then
				seen[st] = true
				res[#res + 1] = st
				for _, t in eps[st] do
					if not seen[t] then
						stack[#stack + 1] = t
					end
				end
			end
		end
		table.sort(res)
		local key = table.concat(res, ",")
		local d = byKey[key]
		if d then
			return d
		end
		local acc = false
		local charStates = {}
		for _, st in res do
			if st == accept then
				acc = true
			end
			if cls[st] then
				charStates[#charStates + 1] = st
			end
		end
		d = { t = {}, acc = acc, cs = charStates, m = {} }
		byKey[key] = d
		return d
	end
	local startD = closure({ start })
	local DEAD = false
	local function step(d, b: number)
		local nxt = {}
		for _, st in d.cs do
			if cls[st][b] then
				nxt[#nxt + 1] = out[st]
			end
		end
		local r
		if #nxt == 0 then
			r = DEAD
		else
			r = closure(nxt)
		end
		d.t[b] = r
		return r
	end
	-- state after the whole LETTER_REP text of letter byte b (cached per state)
	local function macro(d, b: number)
		local r = d.m[b]
		if r ~= nil then
			return r
		end
		local rep = LETTER_REP[string.char(b)]
		local cur = d
		for k = 1, #rep do
			local c = sbyte(rep, k) :: number
			local nx = cur.t[c]
			if nx == nil then
				nx = step(cur, c)
			end
			cur = nx
			if nx == false then
				break
			end
		end
		d.m[b] = cur
		return cur
	end
	local function matchLetters(s: string): boolean
		local d = startD
		for k = 1, #s do
			local b = sbyte(s, k) :: number
			local nx
			if b >= 74 and b <= 78 then
				nx = macro(d, b)
			else
				nx = d.t[b]
				if nx == nil then
					nx = step(d, b)
				end
			end
			if nx == false then
				return false
			end
			d = nx
		end
		return d.acc
	end
	local function match(s: string): boolean
		local d = startD
		local n = #s
		local i = 1
		-- eight bytes per string.byte call
		while i + 7 <= n do
			local b1, b2, b3, b4, b5, b6, b7, b8 = sbyte(s, i, i + 7)
			local nx = d.t[b1] or step(d, b1 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b2] or step(d, b2 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b3] or step(d, b3 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b4] or step(d, b4 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b5] or step(d, b5 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b6] or step(d, b6 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b7] or step(d, b7 :: number)
			if nx == false then
				return false
			end
			d = nx
			nx = d.t[b8] or step(d, b8 :: number)
			if nx == false then
				return false
			end
			d = nx
			i += 8
		end
		for k = i, n do
			local b = sbyte(s, k) :: number
			local nx = d.t[b]
			if nx == nil then
				nx = step(d, b)
			end
			if nx == false then
				return false
			end
			d = nx
		end
		return d.acc
	end
	return match, matchLetters
end

reIsPowiainaNum, reIsPowiainaNumL = compileRegex(
	[==[^(PN)?[\/\-\+]*(Infinity|NaN|(P+|P\^\d+ )?(10(\^+|\{([1-9]\d*|!)(,([1-9]\d*|!))?(,[1-9]\d*)?\})|\(10(\^+|\{([1-9]\d*|!)(,([1-9]\d*|!))?(,[1-9]\d*)?\})\)\^[1-9]\d*\x20*)*((\d+(\.\d*)?|\d*\.\d+)?([Ee][-\+]*))*(0|\d+(\.\d*)?|\d*\.\d+))$]==]
)
reBE = (compileRegex([==[^((\d+(\.\d*)?|\d*\.\d+)?([EeFf]([-\+]?)))*(0|\d+(\.\d*)?|\d*\.\d+)$]==]))
reZero = (compileRegex([==[^((0)|(0*\.0+e\d+)|(0*\.0*))$]==]))
end

--------------------------------------------------------------------------------------------------------------
-- Values, operators
--------------------------------------------------------------------------------------------------------------

local function newOp(r: number, a: number, e: number, m: number): Op
	return { ar = a, ex = e, me = m, re = r }
end

local function clone(x: Hyper): Hyper
	local src = x.a
	local n = #src
	burn(n)
	local arr: { Op } = table.create(n) :: { Op }
	for i = 1, n do
		local o = src[i]
		arr[i] = { ar = o.ar, ex = o.ex, me = o.me, re = o.re }
	end
	return { s = x.s, y = x.y, sm = x.sm, a = arr }
end

local function mkNaN(): Hyper
	return { s = 0, y = 0, sm = false, a = { newOp(NAN, 0, 1, 1) } }
end
local function mkZero(): Hyper
	return { s = 0, y = 0, sm = true, a = { newOp(huge, 0, 1, 1) } }
end
local function mkOne(): Hyper
	return { s = 1, y = 0, sm = false, a = { newOp(1, 0, 1, 1) } }
end
local function mkPosInf(): Hyper
	return { s = 1, y = 0, sm = false, a = { newOp(huge, 0, 1, 1) } }
end
local function mkNegInf(): Hyper
	return { s = -1, y = 0, sm = false, a = { newOp(huge, 0, 1, 1) } }
end

local function deepFreeze(x: Hyper): Hyper
	for _, o in x.a do
		tfreeze(o)
	end
	tfreeze(x.a)
	return tfreeze(x)
end

-- compareTuples on (megota, expans, arrow)
local function cmpLevel(a1: number, a2: number, a3: number, b1: number, b2: number, b3: number): number
	if a1 < b1 then
		return -1
	end
	if a1 > b1 then
		return 1
	end
	if a2 < b2 then
		return -1
	end
	if a2 > b2 then
		return 1
	end
	if a3 < b3 then
		return -1
	end
	if a3 > b3 then
		return 1
	end
	return 0
end

-- PowiainaNum.opGetOperatorIndex, returned as the *JS* (0-based, possibly x.5) index
local function opIndex(arr: { Op }, arrow: number, expans: number, megota: number): number
	for i = 1, #arr do
		local o = arr[i]
		local c = cmpLevel(o.me, o.ex, o.ar, megota, expans, arrow)
		if c == 0 then
			return i - 1
		end
		if c == 1 then
			return i - 1.5
		end
	end
	return #arr - 0.5
end

local function getOp(arr: { Op }, arrow: number, expans: number?, megota: number?): number
	local idx = opIndex(arr, arrow, expans or 1, megota or 1)
	if floor(idx) ~= idx then
		return 0
	end
	local o = arr[idx + 1]
	if o == nil then
		return 0
	end
	return o.re
end

local function setOp(arr: { Op }, val: number, arrow: number, expans: number?, megota: number?)
	local e = expans or 1
	local m = megota or 1
	local idx = opIndex(arr, arrow, e, m)
	local o = if floor(idx) == idx then arr[idx + 1] else nil
	if o == nil then
		local at = ceil(idx)
		if at < 0 then
			at = 0
		end
		tinsert(arr, at + 1, newOp(val, arrow, e, m))
		return
	end
	o.re = val
	if val == 0 then
		tremove(arr, idx + 1)
	end
end

-- stable sort by (megota, expans, arrow) (JS Array.prototype.sort is stable)
local function sortOps(arr: { Op })
	local n = #arr
	if n < 2 then
		return
	end
	if n <= 24 then
		for i = 2, n do
			local v = arr[i]
			local j = i - 1
			local w = arr[j]
			if cmpLevel(w.me, w.ex, w.ar, v.me, v.ex, v.ar) > 0 then
				repeat
					arr[j + 1] = w
					j -= 1
					if j < 1 then
						break
					end
					w = arr[j]
				until cmpLevel(w.me, w.ex, w.ar, v.me, v.ex, v.ar) <= 0
				arr[j + 1] = v
			end
		end
		return
	end
	do
		local sorted = true
		local w = arr[1]
		for i = 2, n do
			local v = arr[i]
			if cmpLevel(w.me, w.ex, w.ar, v.me, v.ex, v.ar) > 0 then
				sorted = false
				break
			end
			w = v
		end
		if sorted then
			return
		end
	end
	-- bottom-up merge sort (stable)
	local src = arr
	local dst: { Op } = table.create(n) :: { Op }
	local width = 1
	while width < n do
		local lo = 1
		while lo <= n do
			local mid = math.min(lo + width, n + 1)
			local hi = math.min(lo + 2 * width, n + 1)
			local i, j, k = lo, mid, lo
			while i < mid and j < hi do
				local a, b = src[i], src[j]
				if cmpLevel(a.me, a.ex, a.ar, b.me, b.ex, b.ar) <= 0 then
					dst[k] = a
					i += 1
				else
					dst[k] = b
					j += 1
				end
				k += 1
			end
			while i < mid do
				dst[k] = src[i]
				i += 1
				k += 1
			end
			while j < hi do
				dst[k] = src[j]
				j += 1
				k += 1
			end
			lo = hi
		end
		src, dst = dst, src
		width *= 2
	end
	if src ~= arr then
		for i = 1, n do
			arr[i] = src[i]
		end
	end
end

-- merge adjacent equal operators from index 2 on (normalize's merge loop / mergeSameArrays), in one pass.
local function mergeSame(arr: { Op }): boolean
	local n = #arr
	if n < 3 then
		return false
	end
	local w = 2
	local merged = false
	for i = 3, n do
		local q, r = arr[w], arr[i]
		if q.ar == r.ar and q.ex == r.ex and q.me == r.me then
			q.re += r.re
			merged = true
		else
			w += 1
			arr[w] = r
		end
	end
	for i = w + 1, n do
		arr[i] = nil
	end
	return merged
end

local function isNaNv(x: Hyper): boolean
	local r = x.a[1].re
	return r ~= r or r == nil
end

-- Is normalize(x) certainly a no-op? (fast path; false means "maybe not")
local function isNormalFast(x: Hyper): boolean
	local arr = x.a
	local n = #arr
	local b = arr[1]
	if b == nil or b.ar ~= 0 or b.ex ~= 1 or b.me ~= 1 or x.s == nil then
		return false
	end
	local r = b.re
	if n == 1 then
		if x.y ~= 0 then
			return false
		end
		if r ~= r then
			return true
		end
		return r >= 1 and r <= MSI and not (r == 1 and x.sm)
	elseif n == 2 then
		local o = arr[2]
		if o.ar ~= 1 or o.ex ~= 1 or o.me ~= 1 then
			return false
		end
		local q = o.re
		return r >= MSI_LOG10 and r <= MSI and q >= 1 and q <= MSI and floor(q) == q and x.y ~= nil
	end
	return false
end

-- Simple normal-form shapes: n = 1 for [r] (a plain double, or its reciprocal if small), n = 2 for
-- [r, (10^)^k]. Returns 0 when v is not such a value (or is NaN); the fast paths below re-derive PN's
-- decisions for these shapes with plain number comparisons (the generic code handles everything else).
local function nfShape(v: Hyper): (number, number, number)
	local arr = v.a
	local b = arr[1]
	if b == nil or b.ar ~= 0 or b.ex ~= 1 or b.me ~= 1 or v.s == nil then
		return 0, 0, 0
	end
	local r = b.re
	local n = #arr
	if n == 1 then
		if v.y ~= 0 or not (r >= 1 and r <= MSI) or (r == 1 and v.sm) then
			return 0, 0, 0
		end
		return 1, r, 0
	elseif n == 2 then
		local o = arr[2]
		if o.ar ~= 1 or o.ex ~= 1 or o.me ~= 1 or v.y == nil then
			return 0, 0, 0
		end
		local q = o.re
		if r >= MSI_LOG10 and r <= MSI and q >= 1 and q <= MSI and floor(q) == q then
			return 2, r, q
		end
	end
	return 0, 0, 0
end

-- PN normalize(), in place, returns x.
-- skipFirst: the checks before the loop and the first pass's sort and merge were already done by the caller
-- (the parser's array form of them, for strings with many operators), which says whether that merge merged.
local function normalize(x: Hyper, skipFirst: boolean?, firstMerged: boolean?): Hyper
	local arr = x.a
	if not skipFirst then
	if isNormalFast(x) then
		return x
	end
	if x.s == nil then
		x.s = 0
	end
	if x.y == nil then
		x.y = 0
	end
	for i = 1, #arr do
		if arr[i].re == huge then
			x.a = { newOp(huge, 0, 1, 1) }
			x.y = 0
			return x
		end
	end
	for i = 2, #arr do
		local e = arr[i]
		if e.ar == nil then
			e.ar = 0
		end
		if e.ex == nil then
			e.ex = 1
		end
		if e.me == nil then
			e.me = 1
		end
		local ea, er, ee, em = e.ar, e.re, e.ex, e.me
		if ea ~= ea or er ~= er or er == nil or ee ~= ee or em ~= em then
			x.a = { newOp(NAN, 0, 1, 1) }
			return x
		end
		if not isFin(er) or not isFin(em) then
			x.a = { newOp(huge, 0, 1, 1) }
			return x
		end
		if not isInteger(ea) then
			e.ar = floor(ea)
		end
		if not isInteger(er) then
			e.re = floor(er)
		end
		if not isInteger(ee) then
			e.ex = floor(ee)
		end
		if not isInteger(em) then
			e.me = floor(em)
		end
	end
	if #arr == 0 then
		x.sm = not x.sm
		x.a = { newOp(huge, 0, 1, 1) }
	end
	end
	local iter = 0
	local renormalize
	repeat
		iter += 1
		if skipFirst and iter == 1 then
			renormalize = firstMerged == true
			arr = x.a
		else
			burn(#x.a)
			if iter > NORMALIZE_CAP then
				x.a = { newOp(NAN, 0, 1, 1) }
				return x
			end
			renormalize = false
			arr = x.a
			sortOps(arr)
			if mergeSame(arr) then
				renormalize = true
			end
		end
		do
			-- drop zero-repeat operators, turn {0, e>=2} into {!, e-1} (one compacting pass)
			local n = #arr
			local w = 1
			for j = 2, n do
				local b = arr[j]
				if not (b.ar ~= 0 and (b.re == 0 or b.re == nil)) then
					if b.ar == 0 and b.ex >= 2 then
						b.ar = huge
						b.ex = b.ex - 1
					end
					w += 1
					arr[w] = b
				end
			end
			for j = w + 1, n do
				arr[j] = nil
			end
		end
		if #arr >= 2 and arr[1].re < MSI and arr[2].ar == 1 and arr[2].ex >= 2 then
			local b0 = arr[1].re
			local o1 = arr[2]
			if b0 == 0 then
				arr[1] = newOp(1, 0, 1, 1)
				o1.re -= 1
			elseif b0 == 1 then
				arr[1] = newOp(10, 0, 1, 1)
				o1.re -= 1
			elseif b0 == 2 then
				arr[1] = newOp(10, 0, 1, 1)
				tinsert(arr, 2, newOp(10, 10, o1.ex - 1, o1.me))
				arr[3].re -= 1
			else
				local n1 = newOp(10, 10, o1.ex - 1, o1.me)
				local n2 = newOp(b0 - 2, huge, o1.ex - 1, o1.me)
				arr[1] = newOp(10, 0, 1, 1)
				tinsert(arr, 2, n2)
				tinsert(arr, 2, n1)
				arr[3].re -= 1
			end
			renormalize = true
		end
		if #arr > MAXOPS then
			local n = #arr
			local cnt = n - MAXOPS
			tmove(arr, 2 + cnt, n, 2)
			for k = n - cnt + 1, n do
				arr[k] = nil
			end
		end
		if #arr >= 2 and arr[2].ar == 1 and arr[2].re >= 1 and arr[1].re < MSI_LOG10 then
			setOp(arr, arr[2].re - 1, 1, 1, 1)
			setOp(arr, jpow(10, arr[1].re), 0, 1, 1)
			renormalize = true
		end
		local b0 = arr[1].re
		if b0 > MSI and isFin(b0) then
			setOp(arr, getOp(arr, 1, 1, 1) + 1, 1, 1, 1)
			setOp(arr, log10(arr[1].re), 0, 1, 1)
			renormalize = true
		end
		local last = arr[#arr]
		local lay = x.y
		if last.me > MSI then
			x.y = lay + 1
			x.a = { newOp(last.me, 0, 1, 1) }
			arr = x.a
			renormalize = true
		elseif truthy(lay) and #arr == 1 and arr[1].ar == 0 then
			x.y = lay - 1
			x.a = { newOp(10, 0, 1, 1), newOp(1, 10, 10, arr[1].re) }
			arr = x.a
			renormalize = true
		end
		if #arr == 1 and arr[1].re < 1 then
			arr[1].re = 1 / arr[1].re
			x.sm = not x.sm
			renormalize = true
		end
		if #arr == 1 and arr[1].re == 1 and x.sm then
			x.sm = false
			renormalize = true
		end
		if #arr >= 2 and not isFin(arr[2].ar) then
			local o = arr[2]
			if o.re > 1 then
				arr[#arr + 1] = newOp(o.re - 1, huge, o.ex, o.me)
				o.re = 1
				o.ar = arr[1].re
				arr[1].re = 10
			else
				o.ar = arr[1].re
				arr[1].re = 10
			end
		end
		if #arr >= 2 and arr[2].ar >= MSI and isFin(arr[2].ar) then
			local o = arr[2]
			arr[1].re = o.ar
			arr[2] = newOp(1, huge, o.ex, o.me)
		end
		-- (#arr < MAXOPS: deliberate fix. PN expands here even when the array is already at MAXOPS operators, so
		-- the cap above then drops the lowest one and every normalize() - so every operation - makes a full
		-- array smaller: "J998" loses a step each time. A full array is left as it is instead.)
		if CAP_FIX and #arr >= MAXOPS and arr[2].ar >= 2 and arr[1].re < MSI and isFin(arr[2].ar) then
			capFixHits += 1                               -- PN would have expanded (and then shrunk) here
		end
		if #arr >= 2 and (#arr < MAXOPS or not CAP_FIX) and arr[2].ar >= 2 and arr[1].re < MSI and isFin(arr[2].ar) then
			local o = arr[2]
			local x2, y2, z2 = arr[1].re, o.ar, o.re
			arr[1].re = 10
			tinsert(arr, 3, newOp(z2 - 1, y2, o.ex, o.me))
			arr[2] = newOp(x2 - 1, y2 - 1, o.ex, o.me)
		end
		while #arr >= 2 and arr[1].re == 1 and truthy(arr[2].re) do
			if arr[2].re > 1 then
				arr[2].re -= 1
			else
				tremove(arr, 2)
			end
			arr[1].re = 10
			renormalize = true
		end
		if
			#arr >= 2
			and #arr < MAXOPS
			and arr[1].re < MSI
			and arr[2].ar >= 2
			and arr[2].re > 1
			and isFin(arr[2].ar)
		then
			local o = arr[2]
			o.re -= 1
			tinsert(arr, 2, newOp(arr[1].re - 1, o.ar - 1, o.ex, o.me))
			arr[1].re = 10
			renormalize = true
		end
		if #arr >= 2 and arr[2].re > MSI and arr[2].ar ~= huge then
			local o = arr[2]
			o.ar += 1
			arr[1].re = o.re
			o.re = 1
			renormalize = true
		end
		if #arr >= 2 and arr[2].re > MSI and arr[2].ar == huge then
			local o = arr[2]
			o.ar = 1
			o.ex += 1
			arr[1].re = o.re
			o.re = 1
			renormalize = true
		end
	until not renormalize
	return x
end

--------------------------------------------------------------------------------------------------------------
-- comparison
--------------------------------------------------------------------------------------------------------------

-- PN compare() on (sign, small, array) views (so abs()/rec() comparisons need no copy)
local function cmpCore(xs: number, xsm: boolean, xa: { Op }, os: number, osm: boolean, oa: { Op }): number
	local r1, r2 = xa[1].re, oa[1].re
	if r1 ~= r1 or r2 ~= r2 or r1 == nil or r2 == nil then
		return 2
	end
	if xs < os then
		return -1
	end
	if xs > os then
		return 1
	end
	local allneg = xs == -1 and os == -1
	if xsm and not osm then
		return if allneg then 1 else -1
	end
	if osm and not xsm then
		return if allneg then -1 else 1
	end
	local rr = 1
	if xsm and osm then
		rr = -1
	end
	if allneg then
		rr = -rr
	end
	local nx, no = #xa, #oa
	local i = 0
	local result = 0
	while nx - i >= 1 and no - i >= 1 do
		local p, q = xa[nx - i], oa[no - i]
		local pr, qr = p.re, q.re
		if pr == huge and qr == huge then
			if xsm == osm then
				return 0
			end
			return if osm then 1 else -1
		end
		if pr == huge then
			result = 1
			break
		end
		if qr == huge then
			result = -1
			break
		end
		local a, b = p.me, q.me
		if a < b then
			result = -1
			break
		elseif a > b then
			result = 1
			break
		end
		a, b = p.ex, q.ex
		if a < b then
			result = -1
			break
		elseif a > b then
			result = 1
			break
		end
		a, b = p.ar, q.ar
		if a < b then
			result = -1
			break
		elseif a > b then
			result = 1
			break
		end
		if pr < qr then
			result = -1
			break
		elseif pr > qr then
			result = 1
			break
		end
		i += 1
	end
	return result * rr + 0
end

local function absS(s: number): number
	if s < 0 then
		return -s
	end
	return s
end

-- compare of |x| and |y| for nfShape values (small flags equal), before the small reversal
local function magNF(xn: number, xr: number, xk: number, yn: number, yr: number, yk: number): number
	if xn ~= yn then
		return if xn < yn then -1 else 1
	end
	if xn == 2 then
		if xk < yk then
			return -1
		elseif xk > yk then
			return 1
		end
	end
	if xr < yr then
		return -1
	elseif xr > yr then
		return 1
	end
	return 0
end

local function cmp(x: Hyper, o: Hyper): number
	return cmpCore(x.s, x.sm, x.a, o.s, o.sm, o.a)
end
local function cmpAbs(x: Hyper, o: Hyper): number -- x.abs().cmp(o)
	return cmpCore(absS(x.s), x.sm, x.a, o.s, o.sm, o.a)
end
local function cmpAbsAbs(x: Hyper, o: Hyper): number -- x.abs().cmp(o.abs())
	return cmpCore(absS(x.s), x.sm, x.a, absS(o.s), o.sm, o.a)
end
local function gteC(c: number): boolean
	return c == 0 or c == 1
end

-- which object would PowiainaNum.max(x, y) copy (read-only use); K_NEG_INF if neither
local KK: { [string]: Hyper } = {} -- less-used constants (keeps the main chunk under 200 locals)
local K_NEG_INF: Hyper
local K_POS_INF: Hyper
local function maxPick(x: Hyper, y: Hyper): Hyper
	local m = K_NEG_INF
	if cmp(m, x) == -1 then
		m = x
	end
	if cmp(m, y) == -1 then
		m = y
	end
	return m
end
local function minPick(x: Hyper, y: Hyper): Hyper
	local m = K_POS_INF
	if cmp(m, x) == 1 then
		m = x
	end
	if cmp(m, y) == 1 then
		m = y
	end
	return m
end

--------------------------------------------------------------------------------------------------------------
-- predicates / simple unary
--------------------------------------------------------------------------------------------------------------

local function isZero(x: Hyper): boolean
	return (x.sm and not isFin(x.a[1].re)) == true
end
local function isFiniteV(x: Hyper): boolean
	return (x.sm or isFin(x.a[1].re)) == true and not isNaNv(x)
end
local function isInfi(x: Hyper): boolean
	return not x.sm and not isFin(x.a[1].re)
end
local function isInfiNaN(x: Hyper): boolean
	return isInfi(x) or isNaNv(x)
end

local function fromNumber(x: number): Hyper
	burn(1)
	if x ~= x then
		return mkNaN()
	end
	local sign
	if x < 0 then
		sign = -1
	elseif x == 0 then
		return mkZero()
	else
		sign = 1
	end
	local y = mabs(x)
	if y == huge then
		return { s = sign, y = 0, sm = false, a = { newOp(huge, 0, 1, 1) } }
	elseif y >= MSI_REC and y < 1 then
		return { s = sign, y = 0, sm = true, a = { newOp(1 / y, 0, 1, 1) } }
	elseif y < MSI_REC then
		return { s = sign, y = 0, sm = true, a = { newOp(-log10(y), 0, 1, 1), newOp(1, 1, 1, 1) } }
	elseif y <= MSI then
		return { s = sign, y = 0, sm = false, a = { newOp(y, 0, 1, 1) } }
	end
	return { s = sign, y = 0, sm = false, a = { newOp(log10(y), 0, 1, 1), newOp(1, 1, 1, 1) } }
end

local K_1: Hyper

local function isInt(x: Hyper): boolean
	if isZero(x) then
		return true
	end
	if not x.sm and isInteger(x.a[1].re) then
		return true
	end
	return gteC(cmpAbs(x, KK.HALFMSI))
end

local function absv(x: Hyper): Hyper
	local o = clone(x)
	if o.s < 0 then
		o.s = -o.s
	end
	return o
end
local function negv(x: Hyper): Hyper
	local o = clone(x)
	o.s = o.s * -1
	return normalize(o)
end
local function recv(x: Hyper): Hyper
	local o = clone(x)
	o.sm = not o.sm
	return o
end

--------------------------------------------------------------------------------------------------------------
-- string parsing (fromString)
--------------------------------------------------------------------------------------------------------------

-- forward declarations for the numeric core
local N: (any) -> Hyper
local add: (Hyper, any) -> Hyper
local sub: (Hyper, any) -> Hyper
local mul: (Hyper, any) -> Hyper
local div: (Hyper, any) -> Hyper
local pow10: (Hyper) -> Hyper
local pow: (Hyper, any) -> Hyper
local log10m: (Hyper) -> Hyper
local logm: (Hyper, any) -> Hyper
local floorv: (Hyper) -> Hyper
local roundv: (Hyper) -> Hyper
local fromObject: (any) -> Hyper?


local function toNumber(x: Hyper): number
	-- JS: if (this.sign == -1) return -this.neg().toNumber(); if (this.small) return 1 / this.rec().toNumber();
	local s = x.s
	local sm = x.sm
	local arr = x.a
	local neg = false
	if s == -1 then
		if isNormalFast(x) then
			neg = true
			s = 1
		else
			return -toNumber(negv(x))
		end
	end
	local inv = false
	if sm then
		inv = true
		sm = false
	end
	local v: number
	local o1 = arr[1]
	if #arr == 1 and o1.ar == 0 and o1.ex == 1 and o1.me == 1 then
		v = o1.re -- compare(x, e308.25) is -1 or NaN here, never >= 0
	elseif gteC(cmpCore(s, sm, arr, KK.E308.s, KK.E308.sm, KK.E308.a)) then
		v = huge
	elseif #arr == 1 then
		v = arr[1].re
	else
		local o = arr[2]
		if #arr == 2 and o.ar == 1 and o.ex == 1 and o.me == 1 and o.re == 1 then
			v = jpow(10, arr[1].re)
		else
			v = NAN
		end
	end
	if inv then
		v = 1 / v
	end
	if neg then
		v = -v
	end
	return v
end

local fromStringImpl: (string) -> Hyper?
local fromObjectImpl: (any) -> Hyper?
do
local function startsWith(s: string, p: string): boolean
	return ssub(s, 1, #p) == p
end

-- JS substring(start[, end]) with 0-based indices
local function jsub(s: string, a: number, b: number?): string
	local n = #s
	local e = if b == nil then n else b
	if a ~= a then
		a = 0
	end
	if e ~= e then
		e = 0
	end
	a = math.clamp(jtrunc(a), 0, n)
	e = math.clamp(jtrunc(e), 0, n)
	if a > e then
		a, e = e, a
	end
	return ssub(s, a + 1, e)
end

-- JS indexOf (0-based, -1 if absent)
local function jindexOf(s: string, p: string): number
	local i = sfind(s, p, 1, true)
	if i == nil then
		return -1
	end
	return i - 1
end

-- /^.*e-.*(e|\^).*/.test(s): an "e-" and, after it, an "e" or "^", all before the first line terminator
local function testEMinusPattern(s: string): boolean
	local i = sfind(s, "e-", 1, true)
	if i == nil then
		return false
	end
	local lineEnd = sfind(s, "[\n\r]") or (#s + 1)
	local u = sfind(s, "\226\128[\168\169]")
	if u and u < lineEnd then
		lineEnd = u
	end
	if i + 1 >= lineEnd then
		return false
	end
	local j = sfind(s, "[e%^]", i + 2)
	return j ~= nil and j < lineEnd
end

-- replaceETo10: /\(e\^(\d+)\)/g -> "(10^)^$1 ", then /(\d+)[Pp][Tt]/g -> "(10^)^$1 "
local function replaceETo10(s: string): string
	local n = #s
	if sfind(s, "(e^", 1, true) then
		local buf = {}
		local last = 1
		local i = 1
		while i <= n do
			if sbyte(s, i) == 40 and sbyte(s, i + 1) == 101 and sbyte(s, i + 2) == 94 and isDigit(sbyte(s, i + 3)) then
				local j = i + 3
				while j <= n and isDigit(sbyte(s, j)) do
					j += 1
				end
				if sbyte(s, j) == 41 then
					buf[#buf + 1] = ssub(s, last, i - 1)
					buf[#buf + 1] = "(10^)^" .. ssub(s, i + 3, j - 1) .. " "
					last = j + 1
					i = j + 1
					continue
				end
			end
			i += 1
		end
		buf[#buf + 1] = ssub(s, last)
		s = tconcat(buf)
		n = #s
	end
	if sfind(s, "[Pp][Tt]") then
		local buf = {}
		local last = 1
		local i = 1
		while i <= n do
			if isDigit(sbyte(s, i)) then
				local j = i
				while j <= n and isDigit(sbyte(s, j)) do
					j += 1
				end
				local c1, c2 = sbyte(s, j, j + 1)
				if (c1 == 80 or c1 == 112) and (c2 == 84 or c2 == 116) then
					buf[#buf + 1] = ssub(s, last, i - 1)
					buf[#buf + 1] = "(10^)^" .. ssub(s, i, j - 1) .. " "
					last = j + 2
					i = j + 2
				else
					i = j
				end
			else
				i += 1
			end
		end
		buf[#buf + 1] = ssub(s, last)
		s = tconcat(buf)
	end
	return s
end

local function removeCommasOutsideBraces(s: string): string
	if not sfind(s, ",", 1, true) then
		return s
	end
	-- "inside" runs from a "{" to the next "}" (or the end): if no comma is left once those are cut out,
	-- nothing is removed. A J/K/L/M/N letter stands for "10{...}", whose commas are inside and which ends
	-- with a "}", so it counts as a "}".
	local outside = string.gsub(string.gsub(s, "{[^}J-N]*[}J-N]", ""), "{[^}J-N]*$", "")
	if not sfind(outside, ",", 1, true) then
		return s
	end
	local buf = {}
	local inBraces = false
	local last = 1
	local i = sfind(s, "[{},J-N]")
	while i do
		local c = sbyte(s, i)
		if c == 123 then
			inBraces = true
		elseif c ~= 44 then
			inBraces = false
		elseif not inBraces then
			buf[#buf + 1] = ssub(s, last, i - 1)
			last = i + 1
		end
		i = sfind(s, "[{},J-N]", i + 1)
	end
	buf[#buf + 1] = ssub(s, last)
	return tconcat(buf)
end

-- /(e+-)(\d+(.\d+)?)/ : returns length of group 1 and group 2, or nil
local function matchEMinus(s: string): (number?, string?)
	local n = #s
	local i = 1
	while i <= n do
		if sbyte(s, i) == 101 then
			local j = i
			while j <= n and sbyte(s, j) == 101 do
				j += 1
			end
			if sbyte(s, j) == 45 then
				local k = j + 1
				local d = k
				while d <= n and isDigit(sbyte(s, d)) do
					d += 1
				end
				if d > k then
					local g2end = d - 1
					if d <= n and ltLen(s, d) == 0 then
						-- `.` matches one UTF-16 unit; our inputs here are ASCII (BE_REGEX passed)
						local d2 = d + 1
						while d2 <= n and isDigit(sbyte(s, d2)) do
							d2 += 1
						end
						if d2 > d + 1 then
							g2end = d2 - 1
						end
					end
					return j - i + 1, ssub(s, k, g2end)
				end
			end
			i = j
		else
			i += 1
		end
	end
	return nil, nil
end

local function countLeadingZerosAfterDecimal(s: string): number
	if sbyte(s, 1) ~= 48 or sbyte(s, 2) ~= 46 then
		return 0
	end
	local i = 3
	while sbyte(s, i) == 48 do
		i += 1
	end
	local b = sbyte(s, i)
	if b ~= nil and b >= 49 and b <= 57 then
		return i - 3
	end
	return 0
end

local function searchNonZeroDigit(s: string): number -- s.search(/[1-9]/)
	local i = sfind(s, "[1-9]")
	if i == nil then
		return -1
	end
	return i - 1
end

local function log10LongString(s: string): number
	return log10(jsNumber(ssub(s, 1, LONG_STRING_MIN_LENGTH))) + (#s - LONG_STRING_MIN_LENGTH)
end

------------------------------------------------------------------ JSON (for the 0.1.x "l.. s.. a[...]" form)
local JNULL = table.freeze({})
local JARR = {} -- tag key for arrays
local JOBJ = {} -- tag key for objects

-- JSON.parse, iterative (arbitrarily deep nesting is fine). Arrays are { [JARR] = true, n = count, ... },
-- objects { [JOBJ] = true, f = fields }, null is JNULL. Returns ok, value.
local function jsonStr(s: string, i: number): (string?, number)
	-- s[i] == '"'
	local buf = {}
	i += 1
	local n = #s
	while true do
		-- the next quote, backslash or control character (an anchored greedy run is faster than a class search)
		local _, e0 = sfind(s, '^[^%z\1-\31"\\]*', i)
		local j = (e0 :: number) + 1
		if j > n then
			return nil, i
		end
		if j > i then
			buf[#buf + 1] = ssub(s, i, j - 1)
		end
		local c = sbyte(s, j)
		if c == 34 then
			return tconcat(buf), j + 1
		elseif c ~= 92 then
			return nil, j -- raw control character
		end
		local e = sbyte(s, j + 1)
		if e == 34 then
			buf[#buf + 1] = '"'
		elseif e == 92 then
			buf[#buf + 1] = "\\"
		elseif e == 47 then
			buf[#buf + 1] = "/"
		elseif e == 98 then
			buf[#buf + 1] = "\b"
		elseif e == 102 then
			buf[#buf + 1] = "\f"
		elseif e == 110 then
			buf[#buf + 1] = "\n"
		elseif e == 114 then
			buf[#buf + 1] = "\r"
		elseif e == 116 then
			buf[#buf + 1] = "\t"
		elseif e == 117 then
			local h = ssub(s, j + 2, j + 5)
			if not smatch(h, "^%x%x%x%x$") then
				return nil, j
			end
			buf[#buf + 1] = utf8.char(tonumber(h, 16) :: number)
			j += 4
		else
			return nil, j
		end
		i = j + 2
	end
end

-- index of the first non-JSON-whitespace byte at or after i
local function skipWS(s: string, i: number): number
	local c = sbyte(s, i)
	if c == 32 or c == 9 or c == 10 or c == 13 then
		return (select(2, sfind(s, "^[ \t\n\r]*", i)) :: number) + 1
	end
	return i
end

local function jsonParse(s: string): (boolean, any)
	local n = #s
	local i = skipWS(s, 1)
	local stack = {}
	local keys = {}
	local value: any
	while true do
		-- parse one value at i (whitespace already skipped)
		local c = sbyte(s, i)
		if c == 91 or c == 123 then
			local isArr = c == 91
			local node = if isArr then { [JARR] = true, n = 0 } else { [JOBJ] = true, f = {} }
			i += 1
			local d = sbyte(s, i)
			if d == 32 or d == 9 or d == 10 or d == 13 then
				i = skipWS(s, i)
				d = sbyte(s, i)
			end
			if (isArr and d == 93) or (not isArr and d == 125) then
				value = node
				i += 1
			elseif isArr then
				stack[#stack + 1] = node
				-- fast path for the common case, an array of small integers: read "n, n, ..." in place until
				-- something else comes (that value is then parsed the general way)
				local closed = false
				while d == 45 or (d ~= nil and d >= 48 and d <= 57) do
					local d0 = if d == 45 then i + 1 else i
					local j = d0
					local v = 0
					local b = sbyte(s, j)
					while b ~= nil and b >= 48 and b <= 57 do
						v = v * 10 + (b - 48)
						j += 1
						b = sbyte(s, j)
					end
					if j == d0 or j - d0 > 15 or b == 46 or b == 101 or b == 69 then
						break -- (not a short integer: the general code parses it, or rejects it)
					end
					if sbyte(s, d0) == 48 and j > d0 + 1 then
						return false, nil -- leading zero
					end
					local nn = node.n + 1
					node.n = nn
					node[nn] = if d == 45 then -v else v
					i = j
					if b == 32 or b == 9 or b == 10 or b == 13 then
						i = skipWS(s, i)
						b = sbyte(s, i)
					end
					if b == 44 then
						i += 1
						d = sbyte(s, i)
						if d == 32 or d == 9 or d == 10 or d == 13 then
							i = skipWS(s, i)
							d = sbyte(s, i)
						end
					elseif b == 93 then
						i += 1
						closed = true
						break
					else
						return false, nil
					end
				end
				if not closed then
					continue
				end
				stack[#stack] = nil
				value = node
			else
				if d ~= 34 then
					return false, nil
				end
				local k, ni = jsonStr(s, i)
				if k == nil then
					return false, nil
				end
				i = skipWS(s, ni)
				if sbyte(s, i) ~= 58 then
					return false, nil
				end
				i = skipWS(s, i + 1)
				stack[#stack + 1] = node
				keys[#stack] = k
				continue
			end
		elseif c == 34 then
			local v, ni = jsonStr(s, i)
			if v == nil then
				return false, nil
			end
			value = v
			i = ni
		elseif c == 45 or (c ~= nil and c >= 48 and c <= 57) then
			-- -?\d+ read in place; up to 15 digits with no fraction or exponent is the value itself
			local d0 = if c == 45 then i + 1 else i
			local j = d0
			local v = 0
			local b = sbyte(s, j)
			while b ~= nil and b >= 48 and b <= 57 do
				v = v * 10 + (b - 48)
				j += 1
				b = sbyte(s, j)
			end
			if j == d0 then
				return false, nil
			end
			if sbyte(s, d0) == 48 and j > d0 + 1 then
				return false, nil -- leading zero
			end
			if j - d0 <= 15 and b ~= 46 and b ~= 101 and b ~= 69 then
				value = if c == 45 then -v else v
				i = j
			else
				local e = j - 1
				if b == 46 then
					local _, e2 = sfind(s, "^%d+", e + 2)
					if e2 == nil then
						return false, nil
					end
					e = e2
				end
				local x = sbyte(s, e + 1)
				if x == 101 or x == 69 then
					local _, e3 = sfind(s, "^[%+%-]?%d+", e + 2)
					if e3 == nil then
						return false, nil
					end
					e = e3
				end
				value = tonumber(ssub(s, i, e))
				i = e + 1
			end
		elseif ssub(s, i, i + 3) == "true" then
			value = true
			i += 4
		elseif ssub(s, i, i + 4) == "false" then
			value = false
			i += 5
		elseif ssub(s, i, i + 3) == "null" then
			value = JNULL
			i += 4
		else
			return false, nil
		end
		-- attach the value to the enclosing containers, closing as many as end here
		while true do
			local d = sbyte(s, i)
			if d == 32 or d == 9 or d == 10 or d == 13 then
				i = skipWS(s, i)
				d = sbyte(s, i)
			end
			local top = stack[#stack]
			if top == nil then
				if i <= n then
					return false, nil
				end
				return true, value
			end
			if top[JARR] then
				top.n += 1
				top[top.n] = value
			else
				top.f[keys[#stack]] = value
			end
			if d == 44 then
				i += 1
				local w = sbyte(s, i)
				if w == 32 or w == 9 or w == 10 or w == 13 then
					i = skipWS(s, i)
				end
				if top[JOBJ] then
					if sbyte(s, i) ~= 34 then
						return false, nil
					end
					local k, ni = jsonStr(s, i)
					if k == nil then
						return false, nil
					end
					i = skipWS(s, ni)
					if sbyte(s, i) ~= 58 then
						return false, nil
					end
					i = skipWS(s, i + 1)
					keys[#stack] = k
				end
				break -- next value
			elseif (d == 93 and top[JARR]) or (d == 125 and top[JOBJ]) then
				i += 1
				stack[#stack] = nil
				value = top
			else
				return false, nil
			end
		end
	end
end

-- /l(\d+)\s+s(\d+)\s+a(\[.*\])/ ; returns l digits, s digits, json text or nil. The group ends at the last "]"
-- before the first line terminator after the "[" (`.` stops there); that line end and its last "]" are found
-- once per line, so this is linear however many "l" candidates fail.
local function matchLegacy(s: string): (string?, string?, string?)
	local n = #s
	local lineEnd, lastRB = 0, -1
	local nextNL, nextCR, nextLS, nextPS = 0, 0, 0, 0
	local p = sfind(s, "l", 1, true)
	while p do
		local i = p + 1
		local d1 = i
		while isDigit(sbyte(s, i)) do
			i += 1
		end
		if i == d1 then
			p = sfind(s, "l", p + 1, true)
			continue
		end
		local g1 = ssub(s, d1, i - 1)
		local w = i
		while true do
			local l = wsLen(s, i)
			if l == 0 then
				break
			end
			i += l
		end
		if i == w or sbyte(s, i) ~= 115 then
			p = sfind(s, "l", p + 1, true)
			continue
		end
		i += 1
		local d2 = i
		while isDigit(sbyte(s, i)) do
			i += 1
		end
		if i == d2 then
			p = sfind(s, "l", p + 1, true)
			continue
		end
		local g2 = ssub(s, d2, i - 1)
		w = i
		while true do
			local l = wsLen(s, i)
			if l == 0 then
				break
			end
			i += l
		end
		if i == w or sbyte(s, i) ~= 97 or sbyte(s, i + 1) ~= 91 then
			p = sfind(s, "l", p + 1, true)
			continue
		end
		local lb = i + 1
		if lb + 1 >= lineEnd then
			-- (plain finds, much faster than a character class on long strings; each terminator's next position
			-- is kept, so every search moves forward only)
			if nextNL <= lb then
				nextNL = sfind(s, "\n", lb + 1, true) or (n + 1)
			end
			if nextCR <= lb then
				nextCR = sfind(s, "\r", lb + 1, true) or (n + 1)
			end
			if nextLS <= lb then
				nextLS = sfind(s, "\226\128\168", lb + 1, true) or (n + 1)
			end
			if nextPS <= lb then
				nextPS = sfind(s, "\226\128\169", lb + 1, true) or (n + 1)
			end
			lineEnd = math.min(nextNL, nextCR, nextLS, nextPS)
			lastRB = -1
			for k = lineEnd - 1, lb + 1, -1 do
				if sbyte(s, k) == 93 then
					lastRB = k
					break
				end
			end
		end
		if lastRB <= lb then
			p = sfind(s, "l", p + 1, true)
			continue
		end
		return g1, g2, ssub(s, lb, lastRB)
	end
	return nil, nil, nil
end

local function jIsArray(v: any): boolean
	return type(v) == "table" and v[JARR] == true
end
-- String(array) for loose == "x" comparison
local function jArrayToString(v: any): string
	local parts = {}
	for i = 1, v.n do
		local e = v[i]
		if e == JNULL or e == nil then
			parts[i] = ""
		elseif type(e) == "number" then
			parts[i] = numstr(e)
		elseif type(e) == "string" then
			parts[i] = e
		elseif type(e) == "boolean" then
			parts[i] = tostr(e)
		elseif jIsArray(e) then
			parts[i] = jArrayToString(e)
		else
			parts[i] = "[object Object]"
		end
	end
	return tconcat(parts, ",")
end
local function jLooseEqX(v: any): boolean
	if v == "x" then
		return true
	end
	if jIsArray(v) then
		return jArrayToString(v) == "x"
	end
	return false
end

------------------------------------------------------------------ fromString
-- JS `t.substring(a, b)` where t = s from byte `pos` on (no copy of t)
local function jsubRel(s: string, pos: number, a: number, b: number): string
	local L = #s - pos + 1
	if a ~= a then
		a = 0
	end
	if b ~= b then
		b = 0
	end
	a = math.clamp(jtrunc(a), 0, L)
	b = math.clamp(jtrunc(b), 0, L)
	if a > b then
		a, b = b, a
	end
	return ssub(s, pos + a, pos + b - 1)
end

-- Number(s[i..j]) for a brace field / repeat count: "!" is Infinity (brace fields only reach here after the
-- regex check); short digit runs are summed exactly, anything else goes through the full Number().
local function braceField(s: string, i: number, j: number, bang: boolean): number
	if bang and i == j and sbyte(s, i) == 33 then
		return huge
	end
	if j >= i and j - i < 15 then
		local v = 0
		for k = i, j do
			local d = (sbyte(s, k) :: number) - 48
			if d < 0 or d > 9 then
				return jsNumber(ssub(s, i, j))
			end
			v = v * 10 + d
		end
		return v
	end
	return jsNumber(ssub(s, i, j))
end

-- Operator stack used while parsing. It is kept as parallel arrays so that a string with 100k operators
-- allocates no table per operator: entry j has level id SL[j] and repeat SR[j], and the top entry n is PN's
-- array[1] (PN's frequent array.splice(1, 0, op) is a push). The base, PN's array[0], is kept apart.
-- Levels (arrow, expans, megota) are interned per parse in a LevelStore: level id -> L[3id-2], L[3id-1], L[3id];
-- id 1 is (1, 1, 1). Lookup is a linear search while there are few levels, then a nested map.
-- pg[j] is the nearest index below j whose operator level is strictly greater than entry j's (0 if none). A
-- scan for "the first operator from the top with level >= target" can then jump over every operator that is
-- not higher than one already passed, which keeps PN's getOperatorIndex scans cheap even for adversarial
-- strings.
type LevelStore = {
	L: { number },
	map: { [number]: { [number]: { [number]: number } } }?,
	n: number,
}
local function newLevelStore(): LevelStore
	return { L = { 1, 1, 1 }, map = nil, n = 1 }
end
local NO_LEVELS: LevelStore = table.freeze(newLevelStore()) :: any -- (never written)
local LEVEL_SCAN_MAX = 8
local function lvIntern(lv: LevelStore, a: number, e: number, m: number): number
	local L = lv.L
	local n = lv.n
	if a ~= a or e ~= e or m ~= m then
		-- (a NaN field equals nothing: a fresh id, never a table key)
		n += 1
		lv.n = n
		L[3 * n - 2], L[3 * n - 1], L[3 * n] = a, e, m
		return n
	end
	local map = lv.map
	if map == nil then
		for id = 1, n do
			local k = 3 * id
			if L[k - 2] == a and L[k - 1] == e and L[k] == m then
				return id
			end
		end
		if n < LEVEL_SCAN_MAX then
			n += 1
			lv.n = n
			L[3 * n - 2], L[3 * n - 1], L[3 * n] = a, e, m
			return n
		end
		local mp: { [number]: { [number]: { [number]: number } } } = {}
		for id = 1, n do
			local k = 3 * id
			local ia, ie, im = L[k - 2], L[k - 1], L[k]
			if ia == ia and ie == ie and im == im then
				local t1 = mp[im]
				if t1 == nil then
					t1 = {}
					mp[im] = t1
				end
				local t2 = t1[ie]
				if t2 == nil then
					t2 = {}
					t1[ie] = t2
				end
				t2[ia] = id
			end
		end
		lv.map = mp
		map = mp
	end
	local mp = map :: { [number]: { [number]: { [number]: number } } }
	local t1 = mp[m]
	if t1 == nil then
		t1 = {}
		mp[m] = t1
	end
	local t2 = t1[e]
	if t2 == nil then
		t2 = {}
		t1[e] = t2
	end
	local id = t2[a]
	if id == nil then
		n += 1
		lv.n = n
		id = n
		t2[a] = n
		L[3 * n - 2], L[3 * n - 1], L[3 * n] = a, e, m
	end
	return id
end

local function stPush(SL: { number }, SR: { number }, pg: { number }, lv: LevelStore, n: number, id: number, r: number): number
	local L = lv.L
	local a, e, m = L[3 * id - 2], L[3 * id - 1], L[3 * id]
	local j = n
	while j > 0 do
		local o = SL[j]
		if o ~= id and cmpLevel(L[3 * o], L[3 * o - 1], L[3 * o - 2], m, e, a) > 0 then
			break
		end
		j = pg[j]
	end
	n += 1
	SL[n] = id
	SR[n] = r
	pg[n] = j
	return n
end
-- insert an entry at stack index q (1 <= q <= n + 1)
local function stInsertAt(SL: { number }, SR: { number }, pg: { number }, lv: LevelStore, n: number, q: number, id: number, r: number): number
	local L = lv.L
	for i = n, q, -1 do
		SL[i + 1] = SL[i]
		SR[i + 1] = SR[i]
	end
	SL[q] = id
	SR[q] = r
	n += 1
	for i = q, n do
		local oi = SL[i]
		local a, e, m = L[3 * oi - 2], L[3 * oi - 1], L[3 * oi]
		local j = i - 1
		while j > 0 do
			local o = SL[j]
			if o ~= oi and cmpLevel(L[3 * o], L[3 * o - 1], L[3 * o - 2], m, e, a) > 0 then
				break
			end
			j = pg[j]
		end
		pg[i] = j
	end
	return n
end

-- opGetOperatorIndex over [base] ++ (stack from the top), as PN's JS index
local function stIndex(
	bA: number,
	bE: number,
	bM: number,
	SL: { number },
	pg: { number },
	lv: LevelStore,
	n: number,
	arrow: number,
	expans: number,
	megota: number
): number
	local c = cmpLevel(bM, bE, bA, megota, expans, arrow)
	if c == 0 then
		return 0
	elseif c == 1 then
		return -0.5
	end
	local L = lv.L
	local j = n
	while j > 0 do
		local o = SL[j]
		c = cmpLevel(L[3 * o], L[3 * o - 1], L[3 * o - 2], megota, expans, arrow)
		if c == 0 then
			return n - j + 1
		elseif c == 1 then
			return n - j + 0.5
		end
		j = pg[j]
	end
	return n + 0.5
end
-- getOperator(arrow)
local function stGetOp(
	bA: number,
	bE: number,
	bM: number,
	bR: number,
	SL: { number },
	SR: { number },
	pg: { number },
	lv: LevelStore,
	n: number,
	arrow: number
): number
	local d = stIndex(bA, bE, bM, SL, pg, lv, n, arrow, 1, 1)
	if floor(d) ~= d then
		return 0
	end
	if d == 0 then
		return bR
	end
	return SR[n - d + 1]
end

-- The operators a letter stands for (all of them take PN's generic "insert at the front" branch), by byte - 73
local LETTER_AR: { number } = { huge, 1, 2, huge, 1 }
local LETTER_EX: { number } = { 1, 2, 2, 2, huge }
local function expandLetters(s: string): string
	return (string.gsub(s, "[J-N]", LETTER_REP))
end

-- comparator for normalizeParsed's table.sort of level ids (module-level, so no closure per call)
local EMPTY_NUMS: { number } = table.freeze({} :: { number }) -- (never written)
local BK_L: { number } = EMPTY_NUMS
local function levelLess(p: number, q: number): boolean
	return cmpLevel(BK_L[3 * p], BK_L[3 * p - 1], BK_L[3 * p - 2], BK_L[3 * q], BK_L[3 * q - 1], BK_L[3 * q - 2]) < 0
end

-- The first normalize(x) of a parsed value whose operator array is given as level ids SL and repeats SR of
-- length cnt >= 3, in reverse (PN index i is k = cnt + 1 - i; the base is k = cnt): normalize's checks before
-- its loop and the first pass's stable sort and merge of equal neighbours are done here on the arrays (the same
-- comparisons and additions, in the same order), so only the merged operators become tables; the rest of
-- normalize then runs as usual. The stable sort is a bucket sort by level id: O(cnt + d log d) for d levels.
local function normalizeParsed(x: Hyper, cnt: number, SL: { number }, SR: { number }, lv: LevelStore)
	local L = lv.L
	local nLv = lv.n
	-- Levels read from a string are integers or infinities (floor leaves them alone) and never NaN; anything
	-- else takes normalize's own path.
	local badMegota = false
	for id = 1, nLv do
		local a, e, m = L[3 * id - 2], L[3 * id - 1], L[3 * id]
		if floor(a) ~= a or floor(e) ~= e or floor(m) ~= m then
			local arr = table.create(cnt) :: { Op }
			for i = 1, cnt do
				local k = cnt + 1 - i
				local o = SL[k]
				arr[i] = newOp(SR[k], L[3 * o - 2], L[3 * o - 1], L[3 * o])
			end
			x.a = arr
			normalize(x)
			return
		end
		if m == huge or m == -huge then
			badMegota = true
		end
	end
	-- One pass in PN order: any repeat of +inf makes the value +inf (normalize's first loop); otherwise the first
	-- operator from PN index 2 on with a NaN repeat gives NaN and the first with a non-finite repeat or megota
	-- gives +inf (its second loop, which also floors the repeats); and is the array already sorted?
	local fail = 0
	local sorted = true
	for k = cnt, 1, -1 do
		local r = SR[k]
		if r == huge then
			x.a = { newOp(huge, 0, 1, 1) }
			x.y = 0
			return
		end
		if k < cnt then
			if fail == 0 then
				if r ~= r then
					fail = 1
				elseif r == -huge or (badMegota and (L[3 * SL[k]] == huge or L[3 * SL[k]] == -huge)) then
					fail = 2
				else
					SR[k] = floor(r)
				end
			end
			if sorted then
				local p, q = SL[k + 1], SL[k]
				if p ~= q and cmpLevel(L[3 * p], L[3 * p - 1], L[3 * p - 2], L[3 * q], L[3 * q - 1], L[3 * q - 2]) > 0 then
					sorted = false
				end
			end
		end
	end
	if fail == 1 then
		x.a = { newOp(NAN, 0, 1, 1) }
		return
	elseif fail == 2 then
		x.a = { newOp(huge, 0, 1, 1) }
		return
	end
	burn(cnt)
	local perm: { number } = EMPTY_NUMS
	if not sorted then
		local count = table.create(nLv, 0) :: { number }
		for k = 1, cnt do
			local id = SL[k]
			count[id] += 1
		end
		local ids = {}
		for id = 1, nLv do
			if count[id] > 0 then
				ids[#ids + 1] = id
			end
		end
		BK_L = L
		table.sort(ids, levelLess)
		BK_L = EMPTY_NUMS
		local start = count -- reused: start position of each level's run
		local acc = 1
		for j = 1, #ids do
			local id = ids[j]
			local c = count[id]
			start[id] = acc
			acc += c
		end
		perm = table.create(cnt) :: { number }
		for k = cnt, 1, -1 do
			local id = SL[k]
			local s = start[id]
			perm[s] = k
			start[id] = s + 1
		end
	end
	-- mergeSame from PN index 2 on
	local out: { Op } = {}
	local k1 = if sorted then cnt else perm[1]
	local o1 = SL[k1]
	out[1] = newOp(SR[k1], L[3 * o1 - 2], L[3 * o1 - 1], L[3 * o1])
	local k2 = if sorted then cnt - 1 else perm[2]
	local qid, qr = SL[k2], SR[k2]
	local no = 1
	local merged = false
	for i = 3, cnt do
		local k = if sorted then cnt + 1 - i else perm[i]
		local id = SL[k]
		if id == qid then
			qr += SR[k]
			merged = true
		else
			no += 1
			out[no] = newOp(qr, L[3 * qid - 2], L[3 * qid - 1], L[3 * qid])
			qid, qr = id, SR[k]
		end
	end
	no += 1
	out[no] = newOp(qr, L[3 * qid - 2], L[3 * qid - 1], L[3 * qid])
	x.a = out
	normalize(x, true, merged)
end

-- parsed operator arrays up to this length are simply built as tables and normalized
local PARSE_TABLE_MAX = 32

local function fromStringCoreImpl(input0: string): Hyper?
	local input = input0
	local x = mkNaN() -- new PowiainaNum(NaN)
	if startsWith(input, "PN") then
		input = ssub(input, 3)
	end
	if input == "NaN" then
		return mkNaN()
	end
	-- PN now expands the J/K/L/M/N shorthands (X^n -> (text)^n, then X -> text, e.g. L -> "10{2,2}"), which
	-- can make the string 7 times longer. Hyper keeps the letters: X^n becomes "(X)^n", which expands to the
	-- same text, and every later step treats each letter as the text it stands for (see LETTER_REP).
	local letters = sfind(input, "[J-N]") ~= nil
	if letters and sfind(input, "[J-N]%^%d") then
		input = string.gsub(input, "([J-N])%^(%d)", "(%1)^%2")
	end
	if testEMinusPattern(input) then
		input = "/10^" .. ssub(input, (jindexOf(input, "e-")) + 1)
		if letters then
			letters = sfind(input, "[J-N]") ~= nil
		end
	end
	-- (a string with a letter expands to one with a "{", which is never a number)
	local res = if letters then NAN else jsNumber(input)
	if res == res then
		local a = false
		if res == 0 then
			if reZero(input) then
				a = true
			end
		else
			a = true
		end
		if not a then
			local m = jindexOf(input, "e")
			local exponent = jsub(input, (if m == -1 then #input else m) + 1)
			local mantissa = if m == -1 then input else jsub(input, 0, m)
			local me0, me1 = 0, 0
			me1 = jsNumber(if exponent ~= "" then exponent else "0")
			if jsNumber(mantissa) >= 1 then
				local log10mant = if #mantissa >= LONG_STRING_MIN_LENGTH
					then log10LongString(mantissa)
					else log10(jsNumber(mantissa))
				local log10int = floor(log10mant)
				local log10float = log10mant - log10int
				me0 = jpow(10, log10float)
				me1 += log10int
			else
				local zeros = countLeadingZerosAfterDecimal(mantissa)
				mantissa = jsub(mantissa, searchNonZeroDigit(mantissa))
				mantissa = ssub(mantissa, 1, 1) .. "." .. jsub(mantissa, 1)
				zeros += 1
				me0 = jsNumber(mantissa)
				me1 += -zeros
			end
			-- PowiainaNum.pow(10, -me1 - 1).mul(Math.pow(me0, -1) * 10).rec()
			return recv(mul(pow(fromNumber(10), -me1 - 1), jpow(me0, -1) * 10))
		end
		if isFin(res) and a then
			return fromNumber(jsNumber(input))
		end
	end
	-- legacy 0.1.x format (the letters never produce an l, s or a)
	if sfind(input, "l", 1, true) and sfind(input, "s", 1, true) and sfind(input, "a", 1, true) then
		if letters then
			input = expandLetters(input)
		end
		local g1, g2, js = matchLegacy(input)
		local lValue, sValue, arr
		local ok = false
		if g1 then
			local okj, v = jsonParse(js :: string)
			if okj then
				ok = true
				lValue = jsNumber(g1 :: string)
				sValue = jsNumber(g2 :: string)
				arr = v
			end
		end
		if not ok or (sValue ~= 0 and sValue ~= 1 and sValue ~= -1) then
			return nil
		end
		local xo = fromObject(arr)
		if xo == nil then
			return nil
		end
		xo.y = lValue :: number
		xo.s = sValue :: number
		xo.sm = false
		normalize(xo)
		return xo
	end
	-- (neither replacement below can match across a letter or inside the text it stands for)
	input = replaceETo10(input)
	input = removeCommasOutsideBraces(input)
	if not (if letters then reIsPowiainaNumL(input) else reIsPowiainaNum(input)) then
		return nil
	end
	local negateIt = false
	local recipIt = false
	local c0 = sbyte(input, 1)
	if c0 == 45 or c0 == 43 then
		local numSigns = (sfind(input, "[^%-%+]") or 0) - 1
		local signs = jsub(input, 0, numSigns)
		local cnt = 0
		for k = 1, #signs do
			if sbyte(signs, k) == 45 then
				cnt += 1
			end
		end
		negateIt = cnt % 2 == 1
		input = jsub(input, numSigns)
	end
	if sbyte(input, 1) == 47 then
		local numSigns = (sfind(input, "[^/]") or 0) - 1
		local signs = jsub(input, 0, numSigns)
		recipIt = #signs % 2 == 1
		input = jsub(input, numSigns)
	end
	-- a long operator array left for normalizeParsed
	local bigCnt = 0
	local bigL: { number }, bigR: { number }, bigLv: LevelStore? = EMPTY_NUMS, EMPTY_NUMS, nil
	if input == "NaN" then
		x.a = { newOp(NAN, 0, 1, 1) }
	elseif input == "Infinity" then
		x.s = 1
		x.a = { newOp(huge, 0, 1, 1) }
	else
		x.s = 1
		if sbyte(input, 1) == 80 then -- 'P'
			if sbyte(input, 2) == 94 then
				local rest = ssub(input, 3)
				local k = sfind(rest, "[^0-9]")
				local a3 = (if k then k - 1 else -1) + 2
				x.y = jsNumber(jsub(input, 2, a3))
				input = jsub(input, a3 + 1)
			else
				local k = sfind(input, "[^P]")
				local a3 = if k then k - 1 else -1
				x.y = a3
				input = jsub(input, a3)
			end
		end
		-- Operator prefix. A cursor walks `input` (PN re-slices the string every step); the base operator is
		-- (bA, bE, bM, bR) and the others are on the stack (see stPush).
		local bA, bE, bM, bR = 0, 1, 1, 0
		-- (the level store and the stack are made at the first operator: most strings have none)
		local lv: LevelStore = NO_LEVELS
		local ID111 = -1
		local letterId: { number } = EMPTY_NUMS
		local SL: { number }, SR: { number }, pg: { number } = EMPTY_NUMS, EMPTY_NUMS, EMPTY_NUMS
		local n = 0
		local pos = 1
		local nIn = #input
		while pos <= nIn do
			local b = sbyte(input, pos) :: number
			if b >= 74 and b <= 78 and sbyte(input, pos + 1) ~= 41 then
				-- A run of letters with no ")^count" after them: each one is PN's generic branch with c = 1
				-- (stPush, inlined).
				if lv == NO_LEVELS then
					lv = newLevelStore()
					ID111 = 1
					SL, SR, pg = {}, {}, {}
				end
				if letterId == EMPTY_NUMS then
					letterId = table.create(5, 0) :: { number }
				end
				-- pg of a letter pushed here is the latest position in this run of a higher letter (by level
				-- J < K < L < M < N), or else the walk below the run, done once per letter per run.
				local L = lv.L
				local n0 = n
				local p2, p3, p4, p5 = 0, 0, 0, 0
				local q1, q2, q3, q4, q5 = -1, -1, -1, -1, -1
				local nb = sbyte(input, pos + 1) :: number
				repeat
					local li = b - 73
					local id = letterId[li]
					if id == 0 then
						id = lvIntern(lv, LETTER_AR[li], LETTER_EX[li], 1)
						letterId[li] = id
					end
					local w
					if li == 1 then
						w = math.max(p2, p3, p4, p5)
					elseif li == 2 then
						w = math.max(p3, p4, p5)
					elseif li == 3 then
						w = math.max(p4, p5)
					elseif li == 4 then
						w = p5
					else
						w = 0
					end
					if w == 0 then
						w = if li == 1 then q1 elseif li == 2 then q2 elseif li == 3 then q3 elseif li == 4 then q4 else q5
						if w < 0 then
							local a, e = L[3 * id - 2], L[3 * id - 1]
							local j = n0
							while j > 0 do
								local o = SL[j]
								if o ~= id then
									-- cmpLevel(L[3 * o], L[3 * o - 1], L[3 * o - 2], 1, e, a) > 0
									local om = L[3 * o]
									if om > 1 then
										break
									elseif not (om < 1) then
										local oe = L[3 * o - 1]
										if oe > e then
											break
										elseif not (oe < e) and L[3 * o - 2] > a then
											break
										end
									end
								end
								j = pg[j]
							end
							w = j
							if li == 1 then
								q1 = j
							elseif li == 2 then
								q2 = j
							elseif li == 3 then
								q3 = j
							elseif li == 4 then
								q4 = j
							else
								q5 = j
							end
						end
					end
					n += 1
					SL[n] = id
					SR[n] = 1
					pg[n] = w
					if li == 2 then -- (no letter is lower than J, so J's positions are never read)
						p2 = n
					elseif li == 3 then
						p3 = n
					elseif li == 4 then
						p4 = n
					elseif li == 5 then
						p5 = n
					end
					pos += 1
					b = nb
					if b == nil or b < 74 or b > 78 then
						break
					end
					nb = sbyte(input, pos + 1) :: number
				until nb == 41
				continue
			end
			-- /^(\(?10[\^\{])/
			local p = pos
			if b == 40 then
				p += 1
				b = sbyte(input, p) :: number
			end
			local arrows: number, expans: number?, megota: number?
			if b ~= nil and b >= 74 and b <= 78 then
				-- a letter: "10{...}" with fixed fields
				arrows = LETTER_AR[b - 73]
				expans = LETTER_EX[b - 73]
				megota = 1
				pos = p + 1
			else
				local q2 = sbyte(input, p + 2)
				if not (b == 49 and sbyte(input, p + 1) == 48 and (q2 == 94 or q2 == 123)) then
					break
				end
				pos = p
				if q2 == 94 then
					local k = sfind(input, "[^%^]", pos + 2)
					local a3 = if k then k - (pos + 2) else -1
					arrows = a3
					pos += a3 + 2
				else
					local close = sfind(input, "}", pos, true)
					if close == nil then
						break -- unreachable for regex-checked input (PN would spin forever here)
					end
					local a3 = close - pos
					-- input.substring(3, a3).split(",") then Number(): the regex allows at most 3 fields, each a
					-- digit run or "!"; read them in place
					local e = close - 1
					local k = pos + 3
					local s1 = k
					while k <= e and sbyte(input, k) ~= 44 do
						k += 1
					end
					arrows = braceField(input, s1, k - 1, true)
					if k <= e then
						k += 1
						local s2 = k
						while k <= e and sbyte(input, k) ~= 44 do
							k += 1
						end
						expans = braceField(input, s2, k - 1, true)
						if k <= e then
							k += 1
							local s3 = k
							while k <= e and sbyte(input, k) ~= 44 do
								k += 1
							end
							megota = braceField(input, s3, k - 1, false)
						else
							megota = 1
						end
					else
						expans = 1
						megota = 1
					end
					if a3 + 1 > 0 then
						pos += a3 + 1
					end
				end
			end
			if lv == NO_LEVELS then
				lv = newLevelStore()
				ID111 = 1
				SL, SR, pg = {}, {}, {}
			end
			local c
			if sbyte(input, pos) == 41 then
				-- ")^count ": Number(text from 2 past the ")" to the next space). A letter in that text makes it
				-- NaN (its expansion has a "{"); so does one right after the ")" (the "10{..." left after
				-- skipping one character still has its "{").
				local sp = sfind(input, " ", pos, true)
				local a3 = if sp then sp - pos else -1
				if sp == nil then
					c = jsNumber(jsubRel(input, pos, 2, a3))
				else
					local b1 = sbyte(input, pos + 1)
					if b1 ~= nil and b1 >= 74 and b1 <= 78 then
						c = NAN
					else
						c = braceField(input, pos + 2, sp - 1, false)
					end
				end
				pos += a3 + 1
			else
				c = 1
			end
			if arrows == 1 and expans == 1 and megota == 1 then
				if n > 0 and SL[n] == ID111 then
					SR[n] += c
				else
					n = stPush(SL, SR, pg, lv, n, ID111, c)
				end
			elseif arrows == 2 and expans == 1 and megota == 1 then
				local has1 = n > 0 and SL[n] == ID111
				local a3 = if has1 then SR[n] else 0
				local bb = bR
				if bb >= 1e10 then
					a3 += 1
				end
				if bb >= 10 then
					a3 += 1
				end
				bR = a3
				if has1 then
					n -= 1
				end
				local d = stIndex(bA, bE, bM, SL, pg, lv, n, 2, 1, 1)
				if floor(d) == d then
					if d == 0 then
						bR += c
					else
						SR[n - d + 1] += c
					end
				else
					local at = ceil(d)
					if at <= 0 then
						n = stPush(SL, SR, pg, lv, n, lvIntern(lv, bA, bE, bM), bR)
						bA, bE, bM, bR = 2, 1, 1, c
					else
						n = stInsertAt(SL, SR, pg, lv, n, n - at + 2, lvIntern(lv, 2, 1, 1), c)
					end
				end
			elseif isFin(arrows) and expans == 1 and megota == 1 then
				local a3 = stGetOp(bA, bE, bM, bR, SL, SR, pg, lv, n, arrows - 1)
				local bb = stGetOp(bA, bE, bM, bR, SL, SR, pg, lv, n, arrows - 2)
				if bb >= 10 then
					a3 += 1
				end
				local d = stIndex(bA, bE, bM, SL, pg, lv, n, arrows, 1, 1)
				local cnt = ceil(d) - 1
				if cnt > 0 then
					n -= math.min(cnt, n)
				end
				bR = a3
				if floor(d) == d then
					if n == 0 then
						error("Hyper: malformed operator string") -- PN: x.array[1] is undefined (TypeError)
					end
					SR[n] += c
				else
					n = stPush(SL, SR, pg, lv, n, lvIntern(lv, arrows, 1, 1), c)
				end
			else
				n = stPush(SL, SR, pg, lv, n, lvIntern(lv, arrows, expans or 1, megota or 1), c)
			end
		end
		-- mantissa / exponent tail: /[Ee]/ separated parts, processed right to left. (It holds a letter only
		-- after a ")^count" with no space after it, where PN keeps the rest of the string.)
		local rest = if pos <= nIn then ssub(input, pos) else ""
		if letters and sfind(rest, "[J-N]") then
			rest = expandLetters(rest)
		end
		local seps = {}
		do
			local k = sfind(rest, "[eE]")
			while k do
				seps[#seps + 1] = k
				k = sfind(rest, "[eE]", k + 1)
			end
		end
		local nparts = #seps + 1
		local nRest = #rest
		local b0, b1 = bR, 0
		for i = nparts, 1, -1 do
			local st = if i == 1 then 1 else seps[i - 1] + 1
			local en = if i == nparts then nRest else seps[i] - 1
			if b0 < MSI_LOG10 and b1 == 0 then
				b0 = 10 ^ b0
			else
				b1 += 1
			end
			if st > en then
				-- empty part: Number("") is never used; the log10 term is 0
				if b1 == 1 then
					b0 += 0
				end
			else
				local part = ssub(rest, st, en)
				local dp = sfind(part, ".", 1, true)
				local intPartLen = if dp == nil then #part else dp - 1
				if b1 == 0 then
					if intPartLen >= LONG_STRING_MIN_LENGTH then
						b0 = log10(b0) + log10LongString(ssub(part, 1, intPartLen))
						b1 = 1
					else
						b0 *= jsNumber(part)
					end
				else
					local d
					if intPartLen >= LONG_STRING_MIN_LENGTH then
						d = log10LongString(ssub(part, 1, intPartLen))
					else
						d = log10(jsNumber(part))
					end
					if b1 == 1 then
						b0 += d
					elseif b1 == 2 and b0 < MSI_LOG10 + log10(d) then
						b0 += log10(1 + 10 ^ (log10(d) - b0))
					end
				end
			end
			if b0 < MSI_LOG10 and b1 ~= 0 then
				b0 = 10 ^ b0
				b1 -= 1
			elseif b0 > MSI then
				b0 = log10(b0)
				b1 += 1
			end
		end
		bR = b0
		if truthy(b1) then
			if n > 0 and SL[n] == ID111 then
				SR[n] += b1
			else
				if lv == NO_LEVELS then
					lv = newLevelStore()
					ID111 = 1
					SL, SR, pg = {}, {}, {}
				end
				n += 1
				SL[n], SR[n] = ID111, b1
			end
		end
		-- PN's array: the base, then the stack from the top
		local cnt = n + 1
		if cnt <= PARSE_TABLE_MAX then
			local L = lv.L
			local arr = table.create(cnt) :: { Op }
			arr[1] = newOp(bR, bA, bE, bM)
			for k = 1, n do
				local o = SL[n - k + 1]
				arr[k + 1] = newOp(SR[n - k + 1], L[3 * o - 2], L[3 * o - 1], L[3 * o])
			end
			x.a = arr
		else
			-- the base goes on top of the stack, so PN index i is stack index cnt + 1 - i
			SL[cnt], SR[cnt] = lvIntern(lv, bA, bE, bM), bR
			bigCnt, bigL, bigR, bigLv = cnt, SL, SR, lv
		end
	end
	if negateIt then
		x.s = x.s * -1
	end
	if recipIt then
		x.sm = not x.sm
	end
	if bigCnt > 0 then
		normalizeParsed(x, bigCnt, bigL, bigR, bigLv :: LevelStore)
	else
		normalize(x)
	end
	normalize(x)
	return x
end

-- PowiainaNum.fromString (BE-style pre-step, then fromString_core); nil = PN throws
function fromStringImpl(input: string): Hyper?
	if reBE(input) then
		local es, g2 = matchEMinus(input)
		if es then
			input = "/" .. srep("e", es - 1) .. (g2 :: string)
		end
	end
	return fromStringCoreImpl(input)
end

------------------------------------------------------------------ fromObject
-- Accepts: JSON-parsed arrays (legacy path) and Lua object forms. Returns nil when PN would throw.
local function luaIsArray(v: any): boolean
	return type(v) == "table" and v.a == nil and v.array == nil and v.mag == nil and v[JOBJ] == nil
end
local function aLen(v: any): number
	if v[JARR] then
		return v.n
	end
	return #v
end
local function isNum(v: any): boolean
	return type(v) == "number"
end

function fromObjectImpl(v: any): Hyper?
	if type(v) ~= "table" then
		return nil
	end
	-- Hyper value / PN-like object: resetFromObject (copy, no normalize)
	if v.a ~= nil then
		return clone(v)
	end
	if v.array ~= nil then
		local src = v.array
		local arr: { Op } = table.create(#src) :: { Op }
		for i, o in src do
			arr[i] = { ar = o.arrow, ex = o.expans, me = o.megota, re = o["repeat"] }
		end
		return ({ s = v.sign, y = v.layer, sm = v.small, a = arr } :: any) :: Hyper
	end
	-- isIBreakEternity
	if isNum(v.mag) and isNum(v.layer) and isNum(v.sign) then
		local res2 = fromNumber(1)
		local layer = v.layer
		local mag = v.mag
		if layer >= MSI then
			res2.a = { newOp(log10(layer), 0, 1, 1), newOp(1, 1, 1, 1), newOp(1, 2, 1, 1) }
		elseif layer >= 1 then
			res2.a = { newOp(mabs(mag), 0, 1, 1), newOp(layer, 1, 1, 1) }
		else
			res2.a = { newOp(mag, 0, 1, 1) }
		end
		res2.sm = mag < 0
		normalize(res2)
		return res2
	end
	local isArr = v[JARR] == true or luaIsArray(v)
	if not isArr then
		return { s = 0, y = 0, sm = false, a = {} }
	end
	local n = aLen(v)
	-- isExpantaNumArray
	local expanta = true
	for i = 1, n do
		local p = v[i]
		if not (type(p) == "table" and (p[JARR] or luaIsArray(p)) and aLen(p) == 2 and isNum(p[1]) and isNum(p[2])) then
			expanta = false
			break
		end
	end
	if expanta then
		local arr: { Op } = table.create(n) :: { Op }
		for i = 1, n do
			arr[i] = { ar = v[i][1], ex = 1, me = 1, re = v[i][2] }
		end
		return { s = 1, y = 0, sm = false, a = arr }
	end
	-- isPowiainaNum01XArray
	local x01 = isNum(v[1])
	if x01 then
		for i = 2, n do
			local b = v[i]
			if not (type(b) == "table" and (b[JARR] or luaIsArray(b)) and aLen(b) == 4) then
				x01 = false
				break
			end
			local four = isNum(b[1]) and isNum(b[2]) and isNum(b[3]) and isNum(b[4])
			local firstX = b[1] == "x" and isNum(b[2]) and isNum(b[3]) and isNum(b[4])
			local thirdX = isNum(b[1]) and isNum(b[2]) and jLooseEqX(b[3]) and isNum(b[4])
			if not four and not firstX and not thirdX then
				x01 = false
				break
			end
		end
	end
	if x01 then
		local arr = { newOp(v[1], 0, 1, 1) }
		for i = 2, n do
			local b = v[i]
			local ar = if b[1] == "x" then huge else b[1]
			local ex = if b[3] == "x" then huge elseif isNum(b[3]) then b[3] else NAN
			arr[2] = newOp(b[2], ar, ex, b[4])
		end
		return { s = 1, y = 0, sm = false, a = arr }
	end
	-- resetFromObject(array) returns early: obj.array stays []
	return { s = 0, y = 0, sm = false, a = {} }
end
fromObject = fromObjectImpl
end

-- new PowiainaNum(string) results, shared and frozen (parsing is a pure function of the string)
local parseCache: { [string]: Hyper } = {}
local parseCacheN = 0
local function parseShared(s: string): Hyper
	local v = parseCache[s]
	if v then
		return v
	end
	local r = fromStringImpl(s)
	if r == nil then
		r = mkNaN()
	end
	v = deepFreeze(r :: Hyper)
	if #s <= 200 then
		if parseCacheN >= 512 then
			parseCache = {}
			parseCacheN = 0
		end
		parseCache[s] = v
		parseCacheN += 1
	end
	return v
end
local clearMsiCache: () -> ()
function Hyper._clearParseCache() -- (for timing tests, and the harness's rerun with the MAXOPS fix off)
	parseCache = {}
	parseCacheN = 0
	clearMsiCache()
end
-- new PowiainaNum(string): a private, mutable copy
local function fromStringCtor(s: string): Hyper
	return clone(parseShared(s))
end

N = function(v: any): Hyper
	local t = type(v)
	if t == "table" then
		if v.a ~= nil then
			return clone(v)
		end
		local r = fromObjectImpl(v)
		if r == nil then
			return mkNaN()
		end
		return r
	elseif t == "number" then
		return fromNumber(v)
	elseif t == "string" then
		return fromStringCtor(v)
	end
	return mkNaN()
end

-- read-only coercion: a Hyper value is used as is
local function R(v: any): Hyper
	local t = type(v)
	if t == "table" and v.a ~= nil then
		return v
	elseif t == "string" then
		return parseShared(v)
	end
	return N(v)
end

--------------------------------------------------------------------------------------------------------------
-- constants
--------------------------------------------------------------------------------------------------------------

local function K(v: any): Hyper
	return deepFreeze(N(v))
end
K_NEG_INF = deepFreeze(mkNegInf())
K_POS_INF = deepFreeze(mkPosInf())
local K_ZERO = deepFreeze(mkZero())
local K_ONE = deepFreeze(mkOne())
KK.NAN = deepFreeze(mkNaN())
local K_0 = K_ZERO
K_1 = K(1)
KK.n2 = K(2)
KK.n3 = K(3)
KK.n4 = K(4)
KK.n10 = K(10)
KK.n24 = K(24)
KK.M1 = K(-1)
KK.M2 = K(-2)
local K_MSI = K(MSI)
KK.HALFMSI = K(MSI / 2)
KK.n9E15 = K(9e15)
KK.n308 = K(308.25471555991675)
KK.NMSI_REC = K(MSI_REC) -- fromNumber(MSI_REC)
KK.MSI_REC = deepFreeze({ s = 1, y = 0, sm = true, a = { newOp(MSI, 0, 1, 1) } }) -- PowiainaNum.MSI_REC
local K_E_MSI = deepFreeze({ s = 1, y = 0, sm = false, a = { newOp(MSI, 0, 1, 1), newOp(1, 1, 1, 1) } })
KK.EE_MSI = deepFreeze({ s = 1, y = 0, sm = false, a = { newOp(MSI, 0, 1, 1), newOp(2, 1, 1, 1) } })
KK.E_MSI_REC = deepFreeze({ s = 1, y = 0, sm = true, a = { newOp(MSI, 0, 1, 1), newOp(1, 1, 1, 1) } })
local K_TETRATED_MSI =
	deepFreeze({ s = 1, y = 0, sm = false, a = { newOp(1e10, 0, 1, 1), newOp(MSI - 2, 1, 1, 1) } })
KK.PENTATED_MSI = deepFreeze({ s = 1, y = 0, sm = false, a = { newOp(10, 0, 1, 1), newOp(MSI - 1, 2, 1, 1) } })
KK.EXPEREC = K(EXP_E_REC)
KK.INV_EXPEREC = K(1 / EXP_E_REC)
KK.NEG_INV_E = K(-0.3678794411710499)
KK.n1EM300 = K("1e-300")
KK.EEE15 = K("eee15")
KK.E308 = K("e308.25471555991675")
KK.OMEGALOG_CAP = K("10{1,2}e15.954589770191003")
KK.EXP12_MSI = K("10{1,2}" .. MSI)
KK.EXP22_MSI = K("10{2,2}" .. MSI)
KK.ARROWMSI_10 = K("10{" .. MSI .. "}10")
KK.OMEGA2LOG_CAP = K("10{1,3}e15.954589770191003")

-- "10{a,e,m}9007199254740991" parsed; a/e may be huge for "!". Cached (read-only, frozen).
local msiCache: { [number]: { [number]: { [number]: Hyper } } } = {}
local msiCacheN = 0
clearMsiCache = function()
	msiCache = {}
	msiCacheN = 0
end
local function msiFormK(a: number, e: number, m: number): Hyper
	local c1 = msiCache[m]
	if c1 == nil then
		c1 = {}
		msiCache[m] = c1
	end
	local c2 = c1[e]
	if c2 == nil then
		c2 = {}
		c1[e] = c2
	end
	local v = c2[a]
	if v then
		return v
	end
	local x = { s = 1, y = 0, sm = false, a = { newOp(MSI, 0, 1, 1), newOp(1, a, e, m) } }
	normalize(x)
	normalize(x)
	v = deepFreeze(x)
	if msiCacheN > 4096 then
		msiCache = {}
		msiCacheN = 0
	else
		c2[a] = v
		msiCacheN += 1
	end
	return v
end
local function validBrace(v: number): boolean -- String(v) matches [1-9]\d*
	return v == v and v >= 1 and v < 1e21 and floor(v) == v
end
-- PowiainaNum.arrowMSI(n) = new PN("10{" + n + "}" + MSI)
local function arrowMSI(n: number): Hyper
	if not validBrace(n) then
		return KK.NAN
	end
	return msiFormK(n, 1, 1)
end
-- PowiainaNum.arrowexpansMSI(n) = new PN("10{" + n + ",2}" + MSI)
local function arrowexpansMSI(n: number): Hyper
	if not validBrace(n) then
		return KK.NAN
	end
	return msiFormK(n, 2, 1)
end
-- BEAF getMSIForm(arrow, expans, megota)
local function getMSIForm(arrow: number, expans: number, megota: number): Hyper
	local a, e, m = arrow, expans, megota
	if a == 0 and e > 1 then
		a, e = huge, e - 1
	elseif a == 0 and e == 1 and m > 1 then
		a, e, m = 1, huge, m - 1
	end
	-- infToBang: !isFinite(x) -> "!"
	if not isFin(a) then
		a = huge
	elseif not validBrace(a) then
		return KK.NAN
	end
	if not isFin(e) then
		e = huge
	elseif not validBrace(e) then
		return KK.NAN
	end
	if not validBrace(m) then
		return KK.NAN
	end
	return msiFormK(a, e, m)
end

--------------------------------------------------------------------------------------------------------------
-- arithmetic core (literal port; `this` is the first parameter and may be mutated exactly where PN does)
--------------------------------------------------------------------------------------------------------------

local function eqK(x: Hyper, k: Hyper): boolean
	return cmp(x, k) == 0
end

-- PN's `new PowiainaNum(other)` where the copy is only read (and returned at most): reuse a Hyper value,
-- and copy it only when it is returned (`own`).
local function coerceRO(v: any): (Hyper, boolean)
	if type(v) == "table" and v.a ~= nil then
		return v, false
	end
	return N(v), true
end

-- v.eq(+Infinity) / v.eq(-Infinity) without building the constant (same result as PN's compare)
local function eqInf(v: Hyper, sgn: number): boolean
	local a = v.a
	local r = a[1].re
	if r ~= r or r == nil or v.s ~= sgn or v.sm ~= false then
		return false
	end
	return a[#a].re == huge
end

local R0_MSI_REC: number = KK.NMSI_REC.a[1].re -- base of fromNumber(MSI_REC) (it is small)

-- toNumber() of an nfShape value
local function toNumNF(s: number, sm: boolean, n: number, r: number, k: number): number
	local v
	if n == 1 then
		v = r
	elseif k > 1 or r >= LOG10_MAX_VALUE then
		v = huge
	else
		v = jpow(10, r)
	end
	if sm then
		v = 1 / v
	end
	if s == -1 then
		v = -v
	end
	return v
end

-- add() for two nfShape values (x already normal). Returns nil when the generic path must run.
-- y enters with sign ys (sub passes -y.s: PN adds a negated copy); returning "y" returns that value.
local function retY(y: any, ys: number, yFresh: boolean): Hyper
	if type(y) == "number" then
		-- a plain number operand: PN would return its fromNumber copy (with the sign it was added with)
		return fromNumber(if (y < 0) == (ys < 0) then y else -y)
	end
	if ys == y.s then
		return if yFresh then y else clone(y)
	end
	local c = clone(y)
	c.s = ys
	return c
end

-- fromNumber(v)'s shape as nfShape would report it: sign, small, n, r, k (n = 0: not such a shape)
local function numShape(v: number): (number, boolean, number, number, number)
	if v ~= v or v == 0 or v == huge or v == -huge then
		return 0, false, 0, 0, 0
	end
	local s = if v < 0 then -1 else 1
	local y = mabs(v)
	if y >= MSI_REC and y < 1 then
		local r = 1 / y
		if r <= MSI then
			return s, true, 1, r, 0
		end
	elseif y < MSI_REC then
		local r = -log10(y)
		if r >= MSI_LOG10 and r <= MSI then
			return s, true, 2, r, 1
		end
	elseif y <= MSI then
		if y >= 1 then
			return s, false, 1, y, 0
		end
	else
		local r = log10(y)
		if r >= MSI_LOG10 then
			return s, false, 2, r, 1
		end
	end
	return 0, false, 0, 0, 0
end

local function addNF(x: Hyper, y: any, yFresh: boolean, xn: number, xr: number, xk: number, yn: number, yr: number, yk: number, ys: number, ysm: boolean): Hyper?
	local xs = x.s
	local xsm = x.sm == true
	local mc -- sign of |x| - |y|
	if xsm ~= ysm then
		mc = if xsm then -1 else 1
	else
		mc = magNF(xn, xr, xk, yn, yr, yk)
		if xsm then
			mc = -mc
		end
	end
	if xs == -ys and mc == 0 then
		return mkZero()
	end
	-- |x| < MSI and |y| < MSI and |x| >= MSI_REC and |y| >= MSI_REC
	if
		(xsm or (xn == 1 and xr < MSI))
		and (ysm or (yn == 1 and yr < MSI))
		and (not xsm or (xn == 1 and xr <= R0_MSI_REC))
		and (not ysm or (yn == 1 and yr <= R0_MSI_REC))
	then
		return fromNumber(toNumNF(xs, xsm, xn, xr, xk) + toNumNF(ys, ysm, yn, yr, yk))
	end
	-- beyond e9e15 (or below its reciprocal): the bigger magnitude wins
	if (xn == 2 and xk > 1) or (yn == 2 and yk > 1) then
		if mc < 0 then
			return retY(y, ys, yFresh)
		end
		return x
	end
	if xs == -1 then
		return nil
	end
	local aIsX = mc > 0
	local as, asm, an, ar, ak, bs, bsm, bn, br, bk
	if aIsX then
		as, asm, an, ar, ak = xs, xsm, xn, xr, xk
		bs, bsm, bn, br, bk = ys, ysm, yn, yr, yk
	else
		as, asm, an, ar, ak = ys, ysm, yn, yr, yk
		bs, bsm, bn, br, bk = xs, xsm, xn, xr, xk
	end
	local temp = toNumNF(as, asm, an, ar, ak) + toNumNF(bs, bsm, bn, br, bk)
	if isFin(temp) and temp ~= 0 then
		return fromNumber(temp)
	end
	if not asm and not bsm and an == 1 and bn == 1 and as == bs then
		return fromNumber((ar + br) * as)
	end
	local alog10 = (if asm then -1 else 1) * (if an == 2 then ar else log10(ar))
	local blog10 = (if bsm then -1 else 1) * (if bn == 2 then br else log10(br))
	if alog10 - blog10 > MSI_LOG10 then
		if aIsX then
			return x
		end
		return retY(y, ys, yFresh)
	end
	local offset = -floor(alog10)
	local resultLogarithm = 0
	local signMult = 1
	local off = as * jpow(10, alog10 + offset) + bs * jpow(10, blog10 + offset)
	if off > 0 then
		resultLogarithm = log10(off) - offset
	end
	if off < 0 then
		resultLogarithm = log10(-off) - offset
		signMult = -1
	end
	if off == 0 then
		return mkZero()
	end
	local arr
	if resultLogarithm > MSI_LOG10 or resultLogarithm < -MSI_LOG10 then
		arr = { newOp(resultLogarithm, 0, 1, 1), newOp(1, 1, 1, 1) }
	else
		arr = { newOp(jpow(10, mabs(resultLogarithm)), 0, 1, 1) }
	end
	return { s = signMult, y = 0, sm = resultLogarithm < 0, a = arr }
end

add = function(this: Hyper, other: any): Hyper
	local x = normalize(this)
	if type(other) == "number" then
		local xn, xr, xk = nfShape(x)
		if xn ~= 0 then
			local ys, ysm, yn, yr, yk = numShape(other)
			if yn ~= 0 then
				local r = addNF(x, other, true, xn, xr, xk, yn, yr, yk, ys, ysm)
				if r then
					return r
				end
			end
		end
	end
	local y, yFresh = coerceRO(other)
	local xn, xr, xk = nfShape(x)
	if xn ~= 0 then
		local yn, yr, yk = nfShape(y)
		if yn ~= 0 then
			local r = addNF(x, y, yFresh, xn, xr, xk, yn, yr, yk, y.s, y.sm == true)
			if r then
				return r
			end
		end
	end
	if (eqInf(x, 1) and eqInf(y, -1)) or (eqInf(x, -1) and eqInf(y, 1)) then
		return mkNaN()
	end
	if not isFiniteV(x) then
		return x
	end
	if not isFiniteV(y) then
		return if yFresh then y else clone(y)
	end
	if isZero(x) then
		return if yFresh then y else clone(y)
	end
	if isZero(y) then
		return x
	end
	local xs, ys = x.s, y.s
	if xs == -ys and cmpAbsAbs(x, y) == 0 then
		return mkZero()
	end
	if cmpAbs(x, K_MSI) == -1 and cmpAbs(y, K_MSI) == -1 then
		if gteC(cmpAbs(x, KK.NMSI_REC)) and gteC(cmpAbs(y, KK.NMSI_REC)) then
			return fromNumber(toNumber(x) + toNumber(y))
		end
	end
	if
		cmpAbs(x, KK.E_MSI_REC) == -1
		or cmpAbs(x, K_E_MSI) == 1
		or cmpAbs(y, KK.E_MSI_REC) == -1
		or cmpAbs(y, K_E_MSI) == 1
	then
		-- a2 = x.maxabs(y) = PowiainaNum.max(|x|, |y|)
		local ms, msm, ma = -1, false, K_NEG_INF.a
		local xas, yas = absS(xs), absS(ys)
		if cmpCore(ms, msm, ma, xas, x.sm, x.a) == -1 then
			ms, msm, ma = xas, x.sm, x.a
		end
		if cmpCore(ms, msm, ma, yas, y.sm, y.a) == -1 then
			ms, msm, ma = yas, y.sm, y.a
		end
		if cmpCore(xas, x.sm, x.a, ms, msm, ma) == 0 then
			return x
		end
		return if yFresh then y else clone(y)
	end
	if xs == -1 then
		return negv(add(negv(x), negv(y)))
	end
	local a, b
	if cmpAbsAbs(x, y) > 0 then
		a, b = x, y
	else
		b, a = x, y
	end
	local temp = toNumber(a) + toNumber(b)
	if isFin(temp) and temp ~= 0 then
		return fromNumber(temp)
	end
	local signMult = 1
	local aa, ba = a.a, b.a
	local a2 = aa[2]
	local b2 = ba[2]
	local a2r = if a2 then a2.re else nil
	local b2r = if b2 then b2.re else nil
	if not a.sm and not b.sm and not truthy(a2r) and not truthy(b2r) and a.s == b.s then
		return fromNumber((aa[1].re + ba[1].re) * a.s)
	end
	local alog10 = (if a.sm then -1 else 1) * (if truthy(a2r) then aa[1].re else log10(aa[1].re))
	local blog10 = (if b.sm then -1 else 1) * (if truthy(b2r) then ba[1].re else log10(ba[1].re))
	if alog10 - blog10 > MSI_LOG10 then
		if a == y and not yFresh then
			return clone(y)
		end
		return a
	end
	local offset = -floor(alog10)
	local resultLogarithm = 0
	local off = a.s * jpow(10, alog10 + offset) + b.s * jpow(10, blog10 + offset)
	if off > 0 then
		resultLogarithm = log10(off) - offset
	end
	if off < 0 then
		resultLogarithm = log10(-off) - offset
		signMult *= -1
	end
	if off == 0 then
		return mkZero()
	end
	local arr
	if resultLogarithm > MSI_LOG10 or resultLogarithm < -MSI_LOG10 then
		arr = { newOp(resultLogarithm, 0, 1, 1), newOp(1, 1, 1, 1) }
	else
		arr = { newOp(jpow(10, mabs(resultLogarithm)), 0, 1, 1) }
	end
	return { s = signMult, y = 0, sm = resultLogarithm < 0, a = arr }
end

sub = function(this: Hyper, a: any): Hyper
	if type(a) == "number" then
		local xn, xr, xk = nfShape(this)
		if xn ~= 0 then
			local ys, ysm, yn, yr, yk = numShape(a)
			if yn ~= 0 then
				local r = addNF(this, a, true, xn, xr, xk, yn, yr, yk, -ys, ysm)
				if r then
					return r
				end
			end
		end
	end
	local y = R(a)
	local xn, xr, xk = nfShape(this)
	if xn ~= 0 then
		local yn, yr, yk = nfShape(y)
		if yn ~= 0 then
			-- this is already normal (normalize would not touch it); add the negation of y without copying it
			local r = addNF(this, y, false, xn, xr, xk, yn, yr, yk, -y.s, y.sm == true)
			if r then
				return r
			end
		end
	end
	return add(this, negv(y))
end

-- log10m(absv(x)) with a single copy
local function log10abs(x: Hyper): Hyper
	local s = absS(x.s)
	if isZero(x) then
		return mkNegInf()
	end
	if x.sm then
		local c = clone(x)
		c.s = s
		c.sm = not c.sm
		return negv(log10m(c))
	end
	local arr = x.a
	if #arr == 1 then
		return fromNumber(log10(arr[1].re))
	end
	if s == x.s then
		-- sign already non-negative: log10m(x) computes the same (and copies whenever it would return x)
		local r = log10m(x)
		if r == x then
			return clone(x)
		end
		return r
	end
	local c = clone(x)
	c.s = s
	if gteC(cmpCore(s, x.sm, arr, K_TETRATED_MSI.s, K_TETRATED_MSI.sm, K_TETRATED_MSI.a)) then
		return c
	end
	c.a[2].re = c.a[2].re - 1
	normalize(c)
	return c
end

mul = function(x: Hyper, other: any): Hyper
	if type(other) == "number" then
		local xn, xr, xk = nfShape(x)
		if xn ~= 0 then
			local ys, ysm, yn, yr, yk = numShape(other)
			if yn ~= 0 then
				local t = toNumNF(x.s, x.sm == true, xn, xr, xk) * toNumNF(ys, ysm, yn, yr, yk)
				if isFin(t) and t ~= 0 then
					return fromNumber(t)
				end
			end
		end
	end
	local y, yFresh = coerceRO(other)
	local xn, xr, xk = nfShape(x)
	if xn ~= 0 then
		local yn, yr, yk = nfShape(y)
		if yn ~= 0 then
			-- finite, non-zero, not NaN: straight to PN's number path
			local t = toNumNF(x.s, x.sm == true, xn, xr, xk) * toNumNF(y.s, y.sm == true, yn, yr, yk)
			if isFin(t) and t ~= 0 then
				return fromNumber(t)
			end
			local r = pow10(add(log10abs(x), log10abs(y)))
			r.s = x.s * y.s
			return r
		end
	end
	if (eqInf(x, 1) and eqInf(y, -1)) or (eqInf(y, 1) and eqInf(x, -1)) then
		return mkNegInf()
	end
	if (isInfiNaN(x) and isZero(y)) or (isInfiNaN(y) and isZero(x)) then
		return mkNaN()
	end
	if eqInf(x, -1) and eqInf(y, -1) then
		return mkPosInf()
	end
	if not isFiniteV(x) then
		return x
	end
	if not isFiniteV(y) then
		return if yFresh then y else clone(y)
	end
	if isZero(x) or isZero(y) then
		return mkZero()
	end
	local t = toNumber(x) * toNumber(y)
	if isFin(t) and t ~= 0 then
		return fromNumber(t)
	end
	local r = pow10(add(log10abs(x), log10abs(y)))
	r.s = x.s * y.s
	return r
end

div = function(this: Hyper, other: any): Hyper
	return mul(this, recv(N(other)))
end

local function mod(this: Hyper, xv: any): Hyper
	local other = N(xv)
	local division = div(this, other)
	local fl = floorv(division)
	return mul(sub(division, fl), other)
end

pow10 = function(this: Hyper): Hyper
	if this.s == 1 and not this.sm then
		local n, r, k = nfShape(this)
		if n == 1 then
			if r < LOG10_MAX_VALUE then
				return fromNumber(jpow(10, r))
			end
			return { s = 1, y = 0, sm = this.sm, a = { newOp(r, 0, 1, 1), newOp(1, 1, 1, 1) } }
		elseif n == 2 and k < MSI - 2 and this.y == 0 then
			return { s = 1, y = 0, sm = this.sm, a = { newOp(r, 0, 1, 1), newOp(k + 1, 1, 1, 1) } }
		end
	end
	if not isFiniteV(this) then
		return this
	end
	if this.s < 0 then
		local o = clone(this)
		o.s *= -1
		return recv(pow10(o))
	end
	if cmp(this, KK.n308) == -1 then
		return fromNumber(jpow(10, toNumber(this)))
	end
	if this.sm then
		if cmp(this, KK.MSI_REC) == -1 then
			return mkOne()
		end
		return fromNumber(jpow(10, jpow(this.a[1].re, -1)))
	end
	local o = clone(this)
	if cmp(o, K_TETRATED_MSI) == 1 then
		return o
	end
	local a1 = o.a[2]
	local r: number = if a1 then a1.re else 0
	setOp(o.a, r + 1, 1, 1, 1)
	normalize(o)
	return o
end

pow = function(this: Hyper, xv: any): Hyper
	local other, oFresh = coerceRO(xv)
	if eqK(this, K_1) then
		return mkOne()
	end
	if not isFiniteV(other) then
		return if oFresh then other else clone(other)
	end
	if not isFiniteV(this) then
		return this
	end
	if eqK(this, KK.n10) then
		return pow10(other)
	end
	if other.s < 0 then
		return recv(pow(this, negv(other)))
	end
	if this.s < 0 then
		if not isInt(other) then
			if other.sm then
				if eqK(div(recv(other), 2), K_1) then
					return negv(pow(negv(this), other))
				end
			end
			return mkNaN()
		end
		local r = pow(absv(this), other)
		local a = roundv(mod(other, 2))
		if eqK(a, K_0) or eqK(a, KK.n2) then
			r.s = 1
		else
			r.s = -1
		end
		return r
	end
	local a = toNumber(this)
	local b = toNumber(other)
	local t = jpow(a, b)
	if isFin(t) and t ~= 0 then
		return fromNumber(t)
	end
	if isZero(this) and isZero(other) then
		return mkOne()
	end
	if isZero(this) then
		return mkZero()
	end
	if isZero(other) then
		return mkOne()
	end
	if cmp(this, K_0) == 1 then
		return pow10(mul(log10m(this), other))
	elseif eqK(mod(recv(other), 2), K_1) then
		return negv(pow10(mul(log10m(negv(this)), other)))
	end
	return mkNaN()
end


local function pow_base(this: Hyper, x: any): Hyper
	local a = N(x)
	return pow(a, this)
end
local function root(this: Hyper, x: any): Hyper
	return pow(this, recv(N(x)))
end
local function sqrtv(this: Hyper): Hyper
	return pow(this, 0.5)
end
local function cbrtv(this: Hyper): Hyper
	return mul(root(absv(this), 3), this.s)
end

log10m = function(this: Hyper): Hyper
	if this.s < 0 then
		return mkNaN()
	end
	if isZero(this) then
		return mkNegInf()
	end
	if this.sm then
		local x = clone(this)
		x.sm = not x.sm
		return negv(log10m(x))
	end
	local arr = this.a
	if #arr == 1 then
		return fromNumber(log10(arr[1].re))
	end
	if #arr == 2 and this.y == 0 then
		-- [r, (10^)^k] in normal form below TETRATED_MSI: drop one 10^ (what clone + decrement + normalize gives)
		local b, o = arr[1], arr[2]
		local r, k = b.re, o.re
		if
			b.ar == 0 and b.ex == 1 and b.me == 1 and o.ar == 1 and o.ex == 1 and o.me == 1
			and r >= MSI_LOG10 and r <= MSI and k >= 1 and k < MSI - 2 and floor(k) == k
		then
			if k == 1 then
				return { s = this.s, y = 0, sm = this.sm, a = { newOp(r, 0, 1, 1) } }
			end
			return { s = this.s, y = 0, sm = this.sm, a = { newOp(r, 0, 1, 1), newOp(k - 1, 1, 1, 1) } }
		end
	end
	if gteC(cmp(this, K_TETRATED_MSI)) then
		return this
	end
	local x = clone(this)
	x.a[2].re = x.a[2].re - 1
	normalize(x)
	return x
end

logm = function(this: Hyper, base: any): Hyper
	if base == nil then
		base = MATH_E
	end
	local other = N(base)
	return div(log10m(this), log10m(other))
end

local function expv(this: Hyper): Hyper
	return pow_base(this, MATH_E)
end
-- PowiainaNum.exp(x)
local function expS(x: any): Hyper
	return pow(fromNumber(MATH_E), x)
end

floorv = function(this: Hyper): Hyper
	if isInt(this) then
		return this
	end
	if this.sm then
		if this.s == 1 then
			return mkZero()
		end
		return negv(mkOne())
	end
	local r = absv(this)
	local g = getOp(r.a, 0)
	r.a[1].re = if this.s == 1 then floor(g) else ceil(g)
	r.s = this.s
	return r
end

local function ceilv(this: Hyper): Hyper
	if isInt(this) then
		return this
	end
	if this.sm then
		if this.s == 1 then
			return mkOne()
		end
		return mkZero()
	end
	local r = absv(this)
	local g = getOp(r.a, 0)
	r.a[1].re = if this.s == 1 then ceil(g) else floor(g)
	r.s = this.s
	return r
end

roundv = function(this: Hyper): Hyper
	if isInt(this) then
		return this
	end
	if this.sm then
		if this.s == 1 then
			local c = cmpCore(this.s, not this.sm, this.a, KK.n2.s, KK.n2.sm, KK.n2.a)
			if c == -1 or c == 0 then
				return mkOne()
			end
			return mkZero()
		else
			local c = cmpCore(absS(this.s), not this.sm, this.a, KK.n2.s, KK.n2.sm, KK.n2.a)
			if c == -1 or c == 0 then
				return mkZero()
			end
			return negv(mkOne())
		end
	end
	local r = absv(this)
	r.a[1].re = jround(r.a[1].re)
	r.s = this.s
	return r
end

local function truncv(this: Hyper): Hyper
	if gteC(cmp(this, K_0)) then
		return floorv(this)
	end
	return ceilv(this)
end

--------------------------------------------------------------------------------------------------------------
-- gamma / factorial / lambertw
--------------------------------------------------------------------------------------------------------------

local function f_gamma(n: number): number
	if not isFin(n) then
		return n
	end
	if n < -50 then
		if n == jtrunc(n) then
			return -huge
		end
		return 0
	end
	local scal1 = 1
	while n < 10 do
		scal1 = scal1 * n
		n += 1
	end
	n -= 1
	local l = 0.9189385332046727
	l = l + (n + 0.5) * mlog(n)
	l = l - n
	local n2 = n * n
	local np = n
	l = l + 1 / (12 * np)
	np = np * n2
	l = l - 1 / (360 * np)
	np = np * n2
	l = l + 1 / (1260 * np)
	np = np * n2
	l = l - 1 / (1680 * np)
	np = np * n2
	l = l + 1 / (1188 * np)
	np = np * n2
	l = l - 691 / (360360 * np)
	np = np * n2
	l = l + 7 / (1092 * np)
	np = np * n2
	l = l - 3617 / (122400 * np)
	return mexp(l) / scal1
end

local function gamma(this: Hyper): Hyper
	if this.sm then
		return recv(this)
	end
	local c = cmp(this, K_MSI)
	if c == -1 or c == 0 then
		if cmp(this, KK.n24) == -1 then
			return fromNumber(f_gamma(this.s * this.a[1].re))
		end
		local t = this.a[1].re - 1
		local l = 0.9189385332046727
		l = l + (t + 0.5) * mlog(t)
		l = l - t
		local n2 = t * t
		local np = t
		local lm = 12 * np
		local adj = 1 / lm
		local l2 = l + adj
		if l2 == l then
			return expS(l)
		end
		l = l2
		np = np * n2
		lm = 360 * np
		adj = 1 / lm
		l2 = l - adj
		if l2 == l then
			return expS(l)
		end
		l = l2
		np = np * n2
		lm = 1260 * np
		local lt = 1 / lm
		l = l + lt
		np = np * n2
		lm = 1680 * np
		lt = 1 / lm
		l = l - lt
		return expS(l)
	elseif c == 1 then
		return expS(mul(this, sub(logm(this), 1)))
	end
	return expS(this)
end

local function factorial(this: Hyper): Hyper
	if cmpAbs(this, K_MSI) == -1 then
		return gamma(add(this, 1))
	elseif cmpAbs(this, K_E_MSI) == -1 then
		return expS(mul(this, sub(log10m(this), 1)))
	end
	return expS(this)
end

local function f_lambertw(z: number, tol: number, principal: boolean): number
	local w
	if not isFin(z) then
		return z
	end
	if principal then
		if z == 0 then
			return z
		end
		if z == 1 then
			return OMEGA
		end
		if z < 10 then
			w = 0
		else
			w = mlog(z) - mlog(mlog(z))
		end
	else
		if z == 0 then
			return -huge
		end
		if z <= -0.1 then
			w = -2
		else
			w = mlog(-z) - mlog(-mlog(-z))
		end
	end
	for _ = 1, 100 do
		local wn = (z * mexp(-w) + w * w) / (w + 1)
		if mabs(wn - w) < tol * mabs(wn) then
			return wn
		end
		w = wn
	end
	error("Iteration failed to converge: " .. numstr(z))
end

local toStringSafe: (Hyper) -> string

local function d_lambertw(z0: any, tol: number, principal: boolean): Hyper
	local z = N(z0)
	local w
	if not isFiniteV(z) then
		return z
	end
	if principal then
		if eqK(z, K_ZERO) then
			return z
		end
		if eqK(z, K_ONE) then
			return fromNumber(OMEGA)
		end
		w = logm(N(z))
	else
		if eqK(z, K_ZERO) then
			return mkNegInf()
		end
		w = logm(N(negv(z)))
	end
	for _ = 1, 100 do
		local ew = expv(negv(w))
		local wewz = sub(w, mul(z, ew))
		local t1 = add(w, mkOne())
		local t2 = add(w, 2)
		local t3 = mul(t2, wewz)
		local t4 = mul(fromNumber(2), w)
		local t5 = add(t4, 2)
		local dd = sub(t1, div(t3, t5))
		if eqK(dd, K_ZERO) then
			return w
		end
		local wn = sub(w, div(wewz, dd))
		local lhs = absv(N(sub(wn, w)))
		local rhs = mul(absv(N(wn)), tol)
		if cmp(lhs, rhs) == -1 then
			return wn
		end
		w = wn
	end
	error("Iteration failed to converge: " .. toStringSafe(z))
end

local lambertw: (Hyper, boolean?) -> Hyper
lambertw = function(this: Hyper, princ: boolean?): Hyper
	local principal = if princ == nil then true else princ
	if cmp(this, KK.NEG_INV_E) == -1 then
		return mkNaN()
	elseif principal then
		if cmpAbs(this, KK.n1EM300) == -1 then
			return N(this)
		elseif this.sm then
			return fromNumber(f_lambertw(toNumber(this), 1e-10, true))
		elseif cmp(this, K_MSI) == -1 then
			return fromNumber(f_lambertw(this.s * this.a[1].re, 1e-10, true))
		elseif cmp(this, KK.EEE15) == -1 then
			return d_lambertw(this, 1e10, true)
		end
		return logm(this)
	else
		if this.s == -1 then
			return mkNaN()
		end
		if cmp(this, KK.n9E15) == -1 then
			return fromNumber(f_lambertw(this.s * this.a[1].re, 1e-10, false))
		elseif cmp(this, K_E_MSI) == -1 then
			return d_lambertw(this, 1e-10, false)
		end
		return negv(lambertw(recv(negv(this)), true))
	end
end

--------------------------------------------------------------------------------------------------------------
-- tetration family
--------------------------------------------------------------------------------------------------------------

local tetrate: (Hyper, any, any) -> Hyper
local slog: (Hyper, any) -> Hyper

tetrate = function(this: Hyper, other2: any, payload0: any): Hyper
	local t = this
	local other = N(other2)
	local payl = N(if payload0 == nil then 1 else payload0)
	if isNaNv(t) or isNaNv(other) or isNaNv(payl) then
		return mkNaN()
	end
	if eqK(t, K_1) then
		return mkOne()
	end
	if cmp(payl, K_ONE) ~= 0 and gteC(cmp(t, KK.EXPEREC)) then
		other = add(other, slog(payl, t))
	end
	local negln
	if isInfi(other) and other.s > 0 then
		if gteC(cmp(t, KK.EXPEREC)) then
			return mkPosInf()
		end
		negln = negv(logm(this))
		return div(lambertw(negln), negln)
	end
	local c = cmp(other, KK.M2)
	if c == -1 or c == 0 then
		return mkNaN()
	end
	if isZero(t) then
		if isZero(other) then
			return mkNaN()
		end
		if gteC(cmp(other, KK.HALFMSI)) or fmod(toNumber(other), 2) == 0 then
			return mkZero()
		end
		return mkOne()
	end
	if eqK(t, K_ONE) then
		if eqK(other, KK.M1) then
			return mkNaN()
		end
		return mkOne()
	end
	if eqK(other, KK.M1) then
		return mkZero()
	end
	if eqK(other, K_ZERO) then
		return mkOne()
	end
	if eqK(other, K_ONE) then
		return t
	end
	if eqK(other, KK.n2) then
		return pow(t, t)
	end
	if eqK(t, KK.n2) then
		if eqK(other, KK.n3) then
			return fromNumber(16)
		end
		if eqK(other, KK.n4) then
			return fromNumber(65536)
		end
	end
	local m = maxPick(t, other)
	if cmp(m, KK.PENTATED_MSI) == 1 then
		return clone(m)
	end
	if cmp(m, K_TETRATED_MSI) == 1 or cmp(other, K_MSI) == 1 then
		if cmp(this, KK.EXPEREC) == -1 then
			negln = negv(logm(t))
			return div(lambertw(negln), negln)
		end
		local j = add(slog(t, 10), other)
		setOp(j.a, getOp(j.a, 2) + 1, 2)
		normalize(j)
		return j
	end
	local y = toNumber(other)
	local f = floor(y)
	local r = pow(t, y - f)
	local l = mkNaN()
	local i = 0
	local w = K_E_MSI
	while f ~= 0 and cmp(r, w) == -1 and i < 100 do
		burn()
		if f > 0 then
			r = pow(t, r)
			if eqK(l, r) then
				f = 0
				break
			end
			l = r
			f -= 1
		else
			r = logm(r, t)
			if eqK(l, r) then
				f = 0
				break
			end
			l = r
			f += 1
		end
		i += 1
	end
	if i == 100 or cmp(this, KK.EXPEREC) == -1 then
		f = 0
	end
	setOp(r.a, getOp(r.a, 1) + f, 1)
	normalize(r)
	return r
end

slog = function(this: Hyper, base0: any): Hyper
	local base = if base0 == nil then 10 else base0
	local x = this
	local b = N(base)
	if isInfiNaN(x) then
		return x
	end
	if isNaNv(b) then
		return b
	end
	if isInfi(b) then
		return mkZero()
	end
	if isZero(x) then
		return mkOne()
	end
	if eqK(x, K_ONE) then
		return mkZero()
	end
	if cmp(x, b) == 0 then
		return mkOne()
	end
	if cmp(b, KK.EXPEREC) == -1 then
		local a = tetrate(b, huge, nil)
		if cmp(x, a) == 0 then
			return mkPosInf()
		end
		if cmp(x, a) == 1 then
			return mkNaN()
		end
	end
	if cmp(maxPick(x, b), KK.PENTATED_MSI) == 1 then
		if cmp(x, b) == 1 then
			return x
		end
		return mkZero()
	end
	if cmp(maxPick(x, b), K_TETRATED_MSI) == 1 then
		if cmp(x, b) == 1 then
			setOp(x.a, getOp(x.a, 2) - 1, 2)
			normalize(x)
			return sub(x, getOp(x.a, 1))
		end
	end
	if cmp(x, K_ZERO) == -1 then
		return sub(pow(b, x), 2)
	end
	local r = 0
	local t = getOp(x.a, 1) - getOp(b.a, 1)
	if t > 3 then
		local l = t - 3
		r += l
		setOp(x.a, getOp(x.a, 1) - l, 1)
	end
	for _ = 1, 100 do
		burn()
		if cmp(x, K_ZERO) == -1 then
			x = pow(N(base), x)
			r -= 1
		else
			local c = cmp(x, K_1)
			if c == -1 or c == 0 then
				return fromNumber(r + toNumber(x) - 1)
			end
			r += 1
			x = logm(N(x), base)
		end
	end
	if cmp(x, KK.n10) == 1 then
		return fromNumber(r)
	end
	return mkNaN()
end

local function ssqrt(this: Hyper): Hyper
	local x = this
	if cmp(x, KK.INV_EXPEREC) == -1 then
		return mkNaN()
	end
	if not isFiniteV(x) then
		return x
	end
	if cmp(x, K_TETRATED_MSI) == 1 then
		return x
	end
	if cmp(x, KK.EE_MSI) == 1 then
		setOp(x.a, getOp(x.a, 1) - 1, 1)
		return x
	end
	local l = logm(x)
	return div(l, lambertw(l))
end

local function iteratedlog(this: Hyper, other2: any, base2: any): Hyper
	if other2 == nil then
		other2 = 1
	end
	if base2 == nil then
		base2 = 10
	end
	local t = this
	local base = N(base2)
	local other = N(other2)
	if isZero(other) then
		return t
	end
	if eqK(other, K_ONE) then
		return logm(t, base)
	end
	return tetrate(base, sub(slog(t, base), other), nil)
end

--------------------------------------------------------------------------------------------------------------
-- arrows
--------------------------------------------------------------------------------------------------------------

local arrowCall: (Hyper, any, any, any, number?) -> Hyper
local anyarrowLog: (Hyper, any, any, number?) -> Hyper
local arrFrac: (any, any) -> Hyper
local omegalog: (Hyper, any, number?) -> Hyper

local function upgrade2(ops: { Op }, base: number)
	local o = ops[2]
	o.ar += 1
	ops[1].re = o.re + log10(base)
	o.re = 1
end

local function higherOmegaLevel(op: Op?): (number, number, number)
	if op == nil then
		error("TypeError: Cannot read properties of undefined (reading 'expans')")
	end
	if not isFin(op.ex) then
		return op.me, op.ex, op.ar
	elseif not isFin(op.ar) then
		return op.me, op.ex, op.ar
	end
	return op.me, op.ex, huge
end
local function opLevel(op: Op?): (number, number, number)
	if op == nil then
		return 0, 0, 0
	end
	return op.me, op.ex, op.ar
end

-- PowiainaNum.omegacollect (mutates and returns ops)
local function omegacollect(ops: { Op }): { Op }
	local maxWhile = 1000000
	while maxWhile ~= 0 do
		maxWhile -= 1
		local base = ops[1].re
		if base >= 10 then
			ops[1].re = log10(base)
			setOp(ops, getOp(ops, 1, 1, 1) + 1, 1, 1, 1)
		else
			local o2 = ops[2]
			if #ops <= 2 and (if o2 then o2.re else nil) == 1 then
				return ops
			end
			local h1, h2, h3 = higherOmegaLevel(o2)
			local l1, l2, l3 = opLevel(ops[3])
			local nextisOmega = cmpLevel(h1, h2, h3, l1, l2, l3) <= 0
			o2 = o2 :: Op
			if nextisOmega and o2.re == 1 and isFin(o2.ar) and o2.ar >= 3 then
				ops[1].re = o2.ar - 1 + mlog(ops[1].re / 2) / mlog(5)
				ops[2] = newOp(1, huge, o2.ex, o2.me)
				mergeSame(ops)
			elseif isFin(o2.ar) then
				local changed = true
				if o2.re >= 2 then
					upgrade2(ops, base)
				elseif nextisOmega and o2.ar < 3 then
					upgrade2(ops, base)
				elseif base ~= 1 then
					upgrade2(ops, base)
				else
					local o3 = ops[3]
					local m1, m2, m3 = opLevel(o3)
					if cmpLevel(h1, h2, h3, m1, m2, m3) == 1 then
						if o3 == nil then
							error("TypeError: Cannot read properties of undefined (reading 'arrow')")
						end
						if o2.ar == o3.ar then
							changed = false
						end
						o2.ar = o3.ar
					else
						changed = false
					end
				end
				if mergeSame(ops) then
					changed = true
				end
				if not changed then
					-- nothing can change any more: PN spins the remaining iterations and returns ops as is
					return ops
				end
			else
				local infRepeat = o2.re
				local baseAfter = infRepeat + log10(base)
				ops[2] = newOp(1, 1, o2.ex + 1, o2.me)
				ops[1].re = baseAfter
				mergeSame(ops)
			end
		end
	end
	return ops
end

local function looseEq10(v: any): boolean -- JS `v == 10`
	local t = type(v)
	if t == "number" then
		return v == 10
	elseif t == "string" then
		return jsNumber(v) == 10
	elseif t == "table" and v.a ~= nil then
		return jsNumber((toStringSafe :: (Hyper) -> string)(v)) == 10
	end
	return false
end

local function pentateS(x: any, other: any, payload: any): Hyper
	return arrowCall(N(x), 3, other, payload, nil)
end

omegalog = function(this: Hyper, bbase0: any, eps0: number?): Hyper
	local bbase = if bbase0 == nil then 10 else bbase0
	local EPSILON = if eps0 == nil then 1e-6 else eps0
	local target = this
	local dis = target
	if isInfiNaN(dis) then
		return dis
	end
	if gteC(cmp(dis, KK.OMEGALOG_CAP)) then
		return dis
	end
	local base = N(bbase)
	if getOp(dis.a, huge) >= 1 then
		setOp(dis.a, getOp(dis.a, huge) - 1, huge, 1, 1)
		return dis
	end
	if cmp(target, pentateS(base, 2, nil)) == -1 then
		return anyarrowLog(N(target), 3, base, nil)
	end
	if looseEq10(bbase) then
		local src = target.a
		local cl: { Op } = table.create(#src) :: { Op }
		for i, o in src do
			cl[i] = { ar = o.ar, ex = o.ex, me = o.me, re = o.re }
		end
		local result = omegacollect(cl)
		return fromNumber(result[2].ar - 1 + mlog(result[1].re / 2) / mlog(5))
	end
	local left, right = 2, 9007199254740991
	local result = NAN
	while left <= right do
		burn()
		local mid = floor((left + right) / 2)
		local comparison = cmp(arrFrac(base, mid), target)
		if comparison == 0 then
			return fromNumber(mid)
		elseif comparison < 0 then
			result = mid
			left = mid + 1
		else
			right = mid - 1
		end
		if mabs(left - right) <= EPSILON then
			return fromNumber(mid)
		end
	end
	return fromNumber(result)
end

local arrowpsd: (any, any, any) -> Hyper

arrowCall = function(t: Hyper, arrows2: any, other2: any, payload2: any, depth0: number?): Hyper
	local arrows = N(arrows2)
	if cmp(arrows, K_ZERO) == -1 then
		return mkNaN()
	end
	if not isInt(arrows) then
		return arrowpsd(t, arrows, other2)
	end
	if eqK(arrows, K_0) then
		return mul(t, other2)
	end
	if eqK(arrows, K_1) then
		return pow(t, other2)
	end
	if eqK(arrows, KK.n2) then
		return tetrate(t, other2, nil)
	end
	burn()
	local depth = if depth0 == nil then 0 else depth0
	local other = N(other2)
	local payload = N(if payload2 == nil then 1 else payload2)
	local calcBase
	if isNaNv(t) or isNaNv(other) or isNaNv(payload) then
		return mkNaN()
	end
	if cmp(other, K_ZERO) == -1 then
		return mkNaN()
	end
	if eqK(t, K_ZERO) then
		if eqK(other, K_ONE) then
			return mkZero()
		end
		return mkNaN()
	end
	if cmp(payload, K_ONE) ~= 0 then
		other = add(other, anyarrowLog(payload, arrows, t, nil))
	end
	if eqK(t, K_ONE) then
		return mkOne()
	end
	if eqK(other, K_ZERO) then
		return mkOne()
	end
	if eqK(other, K_ONE) then
		return t
	end
	if cmp(arrows, K_MSI) == 1 then
		calcBase = arrows
		setOp(calcBase.a, getOp(calcBase.a, huge) + 1, huge)
		return calcBase
	end
	local arrowsNum = toNumber(arrows)
	if eqK(other, KK.n2) then
		return arrowCall(t, arrowsNum - 1, t, payload, depth + 1)
	end
	if cmp(maxPick(t, other), arrowMSI(arrowsNum + 1)) == 1 then
		return clone(maxPick(t, other))
	end
	if cmp(t, arrowMSI(arrowsNum)) == 1 or cmp(other, K_MSI) == 1 then
		if cmp(t, arrowMSI(arrowsNum)) == 1 then
			calcBase = t
			setOp(calcBase.a, getOp(calcBase.a, arrowsNum) - 1, arrowsNum)
			normalize(calcBase)
		elseif cmp(t, arrowMSI(arrowsNum - 1)) == 1 then
			calcBase = fromNumber(getOp(t.a, arrowsNum - 1))
		else
			calcBase = mkZero()
		end
		local j = add(calcBase, other)
		setOp(j.a, getOp(j.a, arrowsNum) + 1, arrowsNum)
		normalize(j)
		return j
	end
	if depth >= MAXOPS + 10 then
		return { s = 1, y = 0, sm = false, a = { newOp(10, 0, 1, 1), newOp(1, arrowsNum, 1, 1) } }
	end
	local y = toNumber(other)
	local f = floor(y)
	local arrows_m1 = sub(arrows, mkOne())
	calcBase = arrowCall(t, arrows_m1, y - f, payload, depth + 1)
	local i = 0
	local m = arrowMSI(arrowsNum - 1)
	while f ~= 0 and cmp(calcBase, m) == -1 and i < 100 do
		burn()
		if f > 0 then
			calcBase = arrowCall(t, arrows_m1, calcBase, payload, depth + 1)
			f -= 1
		end
		i += 1
	end
	if i == 100 then
		f = 0
	end
	setOp(calcBase.a, getOp(calcBase.a, arrowsNum - 1) + f, arrowsNum - 1)
	normalize(calcBase)
	return calcBase
end

anyarrowLog = function(this: Hyper, arrow2: any, base: any, depth0: number?): Hyper
	local x = this
	local arrow = N(arrow2)
	local arrowsNum = toNumber(arrow)
	if cmp(arrow, K_MSI) == 1 then
		error(PN_ERR .. "Not implemented")
	end
	if not isInt(arrow) or cmp(arrow, K_0) == -1 then
		return mkNaN()
	end
	if eqK(arrow, K_0) then
		return div(x, base)
	end
	if eqK(arrow, K_1) then
		return logm(x, base)
	end
	if eqK(arrow, KK.n2) then
		return slog(x, base)
	end
	if isInfiNaN(x) then
		return x
	end
	burn()
	local depth = if depth0 == nil then 0 else depth0
	local b = N(base)
	if isNaNv(b) then
		return b
	end
	if isInfi(b) then
		return mkZero()
	end
	if isZero(x) then
		return mkOne()
	end
	if eqK(x, K_ONE) then
		return mkZero()
	end
	if cmp(x, b) == 0 then
		return mkOne()
	end
	if cmp(maxPick(x, b), arrowMSI(arrowsNum + 1)) == 1 then
		if cmp(x, b) == 1 then
			return x
		end
		return mkZero()
	end
	if cmp(maxPick(x, b), arrowMSI(arrowsNum)) == 1 then
		if cmp(x, b) == 1 then
			setOp(x.a, getOp(x.a, arrowsNum) - 1, arrowsNum)
			normalize(x)
			return sub(x, getOp(x.a, arrowsNum - 1))
		end
	end
	if cmp(x, K_ZERO) == -1 then
		return mkNaN()
	end
	local r = 0
	local distanceLayerOf = getOp(x.a, arrowsNum) - getOp(b.a, arrowsNum)
	if distanceLayerOf > 3 then
		local l = distanceLayerOf - 3
		r += l
		setOp(x.a, getOp(x.a, arrowsNum) - l, arrowsNum)
	end
	for _ = 1, 100 do
		burn()
		if cmp(x, K_ZERO) == -1 then
			x = arrowCall(x, arrowsNum - 1, base, nil, nil)
			r -= 1
		else
			local c = cmp(x, K_1)
			if c == -1 or c == 0 then
				return fromNumber(r + toNumber(x) - 1)
			end
			r += 1
			x = anyarrowLog(x, arrowsNum - 1, base, depth + 1)
		end
	end
	if cmp(x, KK.n10) == 1 then
		return fromNumber(r)
	end
	return mkNaN()
end

-- PowiainaNum.arrow(x, z, y)
local function arrowS(x: any, z: any, y: any): Hyper
	return arrowCall(N(x), z, y, nil, nil)
end

arrFrac = function(base: any, height: any): Hyper
	if cmp(R(height), KK.n2) == -1 then
		return pentateS(base, height, nil)
	end
	local b = N(base)
	local h = N(height)
	local recv0 = N(b)
	local arrows = N(add(floorv(h), 1)) -- arrow() copies its argument before the call argument is evaluated
	local other = mul(pow(div(b, 2), sub(h, floorv(h))), 2)
	return arrowCall(recv0, arrows, other, nil, nil)
end

local function arrFracParaInv(x: any, y: any, res2: any): Hyper
	local lhs = pow(N(x), add(sub(N(res2), y), 1))
	return mul(lhs, pow(fromNumber(2), sub(N(y), res2)))
end

local function arrFracPara(x: any, y: any, z: any): Hyper
	local lg2 = logm(fromNumber(2), x)
	local lhs = sub(N(y), 1)
	return add(lhs, div(sub(logm(N(z), x), lg2), sub(fromNumber(1), lg2)))
end

local function arrowpsdInv(base: any, height: any, res4: any): Hyper
	local x = N(base)
	local y = N(height)
	local z = N(res4)
	if cmp(z, x) == 1 then
		-- PN recurses here with the same z > x at every level until the JS stack overflows (RangeError).
		error("RangeError: Maximum call stack size exceeded (PowiainaNum arrowpsdInv never terminates for z > base)")
	end
	return arrFracParaInv(x, y, omegalog(N(z), toNumber(x), nil))
end

arrowpsd = function(base: any, height: any, other: any): Hyper
	local x = N(base)
	local y = N(height)
	local z = N(other)
	if isInt(y) then
		return arrowS(x, y, z)
	end
	if cmp(z, x) == 1 then
		local anylog2 = arrowpsdInv(x, y, z)
		error("unreachable") -- arrowpsdInv always throws when z > x
		return anylog2
	end
	return arrFrac(x, arrFracPara(x, y, z))
end

--------------------------------------------------------------------------------------------------------------
-- expansion family
--------------------------------------------------------------------------------------------------------------

local expansion: (Hyper, any) -> Hyper
local expansionArrowCall: (Hyper, any, any, number?) -> Hyper
local expansionLog2Call: (Hyper, any, any, number?) -> Hyper

expansion = function(this: Hyper, other2: any): Hyper
	local other = N(other2)
	local t = this
	if cmp(other, K_ZERO) == -1 then
		return mkNaN()
	end
	if eqK(other, K_ONE) then
		return this
	end
	if eqK(this, K_ONE) then
		return mkOne()
	end
	if eqK(this, KK.n2) then
		return fromNumber(4)
	end
	if eqK(other, K_0) then
		return mkOne()
	end
	if cmp(other, K_0) == 1 and cmp(other, K_1) == -1 and not isInt(other) then
		return pow(t, other)
	end
	if cmp(other, K_1) == 1 and cmp(other, KK.n2) == -1 and not isInt(other) then
		local _y = pow_base(sub(other, 1), t)
		if cmp(_y, KK.n2) == -1 then
			return arrowS(t, 3, _y)
		end
		return arrFrac(t, _y)
	end
	local calcBase
	if cmp(t, KK.EXP12_MSI) == 1 or cmp(other, K_MSI) == 1 then
		if cmp(t, KK.EXP12_MSI) == 1 then
			calcBase = clone(t)
			setOp(calcBase.a, getOp(calcBase.a, 1, 2) - 1, 1, 2)
			normalize(calcBase)
		elseif cmp(t, KK.ARROWMSI_10) == 1 then
			calcBase = fromNumber(getOp(t.a, huge))
		else
			calcBase = mkZero()
		end
		local j = add(calcBase, other)
		setOp(j.a, getOp(j.a, 1, 2) + 1, 1, 2)
		normalize(j)
		return j
	end
	local y = toNumber(other) - 1
	local f = floor(y)
	calcBase = expansion(N(t), 1 + y - f)
	local i = 0
	local m = KK.OMEGALOG_CAP
	while f ~= 0 and cmp(calcBase, m) == -1 and i < 100 do
		burn()
		if f > 0 then
			calcBase = arrFrac(t, calcBase)
			f -= 1
		end
		i += 1
	end
	setOp(calcBase.a, getOp(calcBase.a, huge) + f, huge)
	normalize(calcBase)
	return calcBase
end

expansionArrowCall = function(t: Hyper, arrow2: any, other2: any, depth0: number?): Hyper
	local arrow = N(arrow2)
	if cmp(arrow, K_0) == -1 or not isInt(arrow) then
		return mkNaN()
	end
	if eqK(arrow, K_0) then
		return arrowCall(t, other2, t, nil, nil)
	end
	if eqK(arrow, K_1) then
		return expansion(t, other2)
	end
	burn()
	local arrows = arrow
	local depth = if depth0 == nil then 0 else depth0
	local other = N(other2)
	local r
	if isNaNv(t) or isNaNv(other) then
		return mkNaN()
	end
	if cmp(other, K_ZERO) == -1 then
		return mkNaN()
	end
	if eqK(t, K_ZERO) then
		if eqK(other, K_ONE) then
			return mkZero()
		end
		return mkNaN()
	end
	if eqK(t, K_ONE) then
		return mkOne()
	end
	if eqK(other, K_ZERO) then
		return mkOne()
	end
	if eqK(other, K_ONE) then
		return t
	end
	if cmp(arrows, K_MSI) == 1 then
		r = arrows
		setOp(r.a, getOp(r.a, huge, 2) + 1, huge, 2)
		return r
	end
	local arrowsNum = toNumber(arrows)
	if eqK(other, KK.n2) then
		return expansionArrowCall(t, arrowsNum - 1, t, depth + 1)
	end
	if cmp(maxPick(t, other), arrowexpansMSI(arrowsNum + 1)) == 1 then
		return clone(maxPick(t, other))
	end
	if cmp(t, arrowexpansMSI(arrowsNum)) == 1 or cmp(other, K_MSI) == 1 then
		if cmp(t, arrowexpansMSI(arrowsNum)) == 1 then
			r = clone(t)
			setOp(r.a, getOp(r.a, arrowsNum, 2) - 1, arrowsNum, 2)
			normalize(r)
		elseif cmp(t, arrowexpansMSI(arrowsNum - 1)) == 1 then
			r = fromNumber(getOp(t.a, arrowsNum - 1, 2))
		else
			r = mkZero()
		end
		local j = add(r, other)
		setOp(j.a, getOp(j.a, arrowsNum, 2) + 1, arrowsNum, 2)
		normalize(j)
		return j
	end
	if depth >= MAXOPS + 10 then
		return { s = 1, y = 0, sm = false, a = { newOp(10, 0, 1, 1), newOp(1, arrowsNum, 2, 1) } }
	end
	local y = toNumber(other)
	local f = floor(y)
	local arrows_m1 = sub(arrows, mkOne())
	r = expansionArrowCall(t, arrows_m1, y - f, depth + 1)
	local i = 0
	local m = arrowexpansMSI(arrowsNum - 1)
	while f ~= 0 and cmp(r, m) == -1 and i < 100 do
		burn()
		if f > 0 then
			r = expansionArrowCall(t, arrows_m1, r, depth + 1)
			f -= 1
		end
		i += 1
	end
	if i == 100 then
		f = 0
	end
	setOp(r.a, getOp(r.a, arrowsNum - 1, 2) + f, arrowsNum - 1, 2)
	normalize(r)
	return r
end

local function expansionLogInner(this: Hyper, base2: any): Hyper
	local t = this
	local base = N(base2)
	if eqK(base, KK.n2) and cmp(t, KK.n4) == 1 then
		return mkNaN()
	end
	if gteC(cmp(t, KK.EXP22_MSI)) then
		return t
	end
	if gteC(cmp(t, KK.EXP12_MSI)) then
		setOp(t.a, getOp(t.a, 1, 2) - 1, 1, 2)
		return t
	end
	local r = 0
	local x = t
	local more = 0
	if getOp(x.a, huge) >= 10 then
		more = getOp(x.a, huge) - 10
		setOp(x.a, 10, huge)
	end
	for _ = 1, 100 do
		burn()
		if cmp(x, K_ZERO) == -1 then
			x = arrFrac(base, x)
			r -= 1
		else
			local c = cmp(x, K_1)
			if c == -1 or c == 0 then
				return fromNumber(r + toNumber(x) - 1 + more)
			end
			r += 1
			x = omegalog(x, toNumber(base), nil)
		end
	end
	if cmp(x, KK.n10) == 1 then
		return fromNumber(r + more)
	end
	return add(x, more)
end

expansionLog2Call = function(this: Hyper, arrow2: any, base: any, depth0: number?): Hyper
	local x = clone(this)
	local arrow = N(arrow2)
	local arrowsNum = toNumber(arrow)
	if cmp(arrow, K_MSI) == 1 then
		error(PN_ERR .. "Not implemented")
	end
	if not isInt(arrow) or cmp(arrow, K_1) == -1 then
		return mkNaN()
	end
	if eqK(arrow, K_1) then
		return expansionLogInner(x, base)
	end
	if isInfiNaN(x) then
		return x
	end
	burn()
	local depth = if depth0 == nil then 0 else depth0
	local b = N(base)
	if isNaNv(b) then
		return b
	end
	if isInfi(b) then
		return mkZero()
	end
	if isZero(x) then
		return mkOne()
	end
	if eqK(x, K_ONE) then
		return mkZero()
	end
	if cmp(x, b) == 0 then
		return mkOne()
	end
	if cmp(maxPick(x, b), arrowexpansMSI(arrowsNum + 1)) == 1 then
		if cmp(x, b) == 1 then
			return x
		end
		return mkZero()
	end
	if cmp(maxPick(x, b), arrowexpansMSI(arrowsNum)) == 1 then
		if cmp(x, b) == 1 then
			setOp(x.a, getOp(x.a, arrowsNum, 2) - 1, arrowsNum, 2)
			normalize(x)
			return sub(x, getOp(x.a, arrowsNum - 1, 2))
		end
	end
	if cmp(x, K_ZERO) == -1 then
		return mkNaN()
	end
	local r = 0
	local distanceLayerOf = getOp(x.a, arrowsNum, 2) - getOp(b.a, arrowsNum, 2)
	if distanceLayerOf > 3 then
		local l = distanceLayerOf - 3
		r += l
		setOp(x.a, getOp(x.a, arrowsNum, 2) - l, arrowsNum, 2)
	end
	for _ = 1, 100 do
		burn()
		if cmp(x, K_ZERO) == -1 then
			x = expansionArrowCall(x, arrowsNum - 1, base, nil)
			r -= 1
		else
			local c = cmp(x, K_1)
			if c == -1 or c == 0 then
				return fromNumber(r + toNumber(x) - 1)
			end
			r += 1
			x = expansionLog2Call(x, arrowsNum - 1, base, depth + 1)
		end
	end
	if cmp(x, KK.n10) == 1 then
		return fromNumber(r)
	end
	return mkNaN()
end

local function arrw2Frac(base: any, height: any): Hyper
	if cmp(R(height), KK.n2) == -1 then
		return expansionArrowCall(N(base), 3, height, nil)
	end
	local b = N(base)
	local h = N(height)
	local recv0 = N(b)
	local arrows = N(add(floorv(h), 1))
	local other = mul(pow(div(b, 2), sub(h, floorv(h))), 2)
	return expansionArrowCall(recv0, arrows, other, nil)
end

local function omega2log(this: Hyper, bbase0: any, eps0: number?): Hyper
	local bbase = if bbase0 == nil then 10 else bbase0
	local EPSILON = if eps0 == nil then 1e-6 else eps0
	local target = this
	local dis = clone(target)
	if isInfiNaN(dis) then
		return dis
	end
	if gteC(cmp(dis, KK.OMEGA2LOG_CAP)) then
		return dis
	end
	N(bbase)
	if getOp(dis.a, huge, 2) >= 1 then
		setOp(dis.a, getOp(dis.a, huge) - 1, huge, 2, 1)
		return dis
	end
	if cmp(target, expansionArrowCall(N(bbase), 3, 2, nil)) == -1 then
		return expansionLog2Call(N(target), 3, bbase, nil)
	end
	if looseEq10(bbase) then
		local src = target.a
		local cl: { Op } = table.create(#src) :: { Op }
		for i, o in src do
			cl[i] = { ar = o.ar, ex = o.ex, me = o.me, re = o.re }
		end
		local result = omegacollect(cl)
		return fromNumber(result[2].ar - 1 + mlog(result[1].re / 2) / mlog(5))
	end
	local left, right = 2, 9007199254740991
	local result = NAN
	while left <= right do
		burn()
		local mid = floor((left + right) / 2)
		local comparison = cmp(arrw2Frac(bbase, mid), target)
		if comparison == 0 then
			return fromNumber(mid)
		elseif comparison < 0 then
			result = mid
			left = mid + 1
		else
			right = mid - 1
		end
		if mabs(left - right) <= EPSILON then
			return fromNumber(mid)
		end
	end
	return fromNumber(result)
end

--------------------------------------------------------------------------------------------------------------
-- BEAF
--------------------------------------------------------------------------------------------------------------

local BEAF_core: (any, any, any, any, any, any, number?) -> Hyper
BEAF_core = function(base2: any, power2: any, arrow2: any, expans2: any, megota2: any, powiaina2: any, depth0: number?): Hyper
	if arrow2 == nil then
		arrow2 = 1
	end
	if expans2 == nil then
		expans2 = 1
	end
	if megota2 == nil then
		megota2 = 1
	end
	if powiaina2 == nil then
		powiaina2 = 1
	end
	local depth = if depth0 == nil then 0 else depth0
	local base = N(base2)
	local power = N(power2)
	if eqK(base, K_1) then
		return fromNumber(1)
	end
	if eqK(power, K_1) then
		return N(base)
	end
	if isZero(power) then
		return fromNumber(1)
	end
	if cmp(base, K_0) == -1 then
		return mkNaN()
	end
	if gteC(cmp(R(powiaina2), KK.n3)) then
		return mkPosInf()
	end
	local ra0, ra1, ra2, ra3 = R(arrow2), R(expans2), R(megota2), R(powiaina2)
	if eqK(ra0, K_0) and eqK(ra1, K_1) and eqK(ra2, K_1) then
		return mul(base, power)
	end
	if eqK(ra0, K_1) and eqK(ra1, K_1) and eqK(ra2, K_1) then
		return pow(base, power)
	end
	if eqK(ra0, KK.n2) and eqK(ra1, K_1) and eqK(ra2, K_1) and eqK(ra3, K_1) then
		return tetrate(base, power, nil)
	end
	if eqK(ra1, K_1) and eqK(ra2, K_1) and eqK(ra3, K_1) then
		return arrowCall(base, N(arrow2), power, nil, nil)
	end
	if eqK(ra1, KK.n2) and eqK(ra2, K_1) and eqK(ra3, K_1) then
		return expansionArrowCall(base, N(arrow2), power, nil)
	end
	local arrow = toNumber(N(arrow2))
	local expans = N(expans2)
	local megota = N(megota2)
	local powiaina = N(powiaina2)
	if eqK(powiaina, KK.n2) then
		if arrow ~= 1 then
			return mkPosInf()
		end
		if cmp(expans, K_1) ~= 0 then
			return mkPosInf()
		end
		if cmp(megota, K_1) ~= 0 then
			return mkPosInf()
		end
		if gteC(cmp(power, K_MSI)) then
			return mkPosInf()
		end
		local r = fromNumber(10)
		r.y = toNumber(power)
		normalize(r)
		return r
	end
	if cmp(megota, K_MSI) == 1 then
		local temp = N(megota)
		temp.y += 1
		normalize(temp)
		return temp
	end
	burn()
	local t = base
	local arrows = N(N(arrow2))
	local other = N(power)
	local r
	if isNaNv(t) or isNaNv(other) then
		return mkNaN()
	end
	if cmp(other, K_ZERO) == -1 then
		return mkNaN()
	end
	if eqK(t, K_ZERO) then
		if eqK(other, K_ONE) then
			return mkZero()
		end
		return mkNaN()
	end
	if eqK(t, K_ONE) then
		return mkOne()
	end
	if eqK(other, K_ZERO) then
		return mkOne()
	end
	if eqK(other, K_ONE) then
		return t
	end
	if eqK(arrows, K_0) then
		return BEAF_core(t, t, power, sub(expans, 1), megota, powiaina2, depth + 1)
	end
	if eqK(expans, K_0) then
		return BEAF_core(t, t, t, power, sub(megota, 1), powiaina2, depth + 1)
	end
	if eqK(megota, K_0) then
		return BEAF_core(t, t, t, t, expans, sub(N(powiaina2), 1), depth + 1)
	end
	if cmp(megota, K_MSI) == 1 then
		error("Not implemeneted")
	end
	if cmp(expans, K_MSI) == 1 then
		r = N(expans)
		local mg = toNumber(megota)
		setOp(r.a, getOp(r.a, 1, huge, mg) + 1, 1, huge, mg)
		return r
	end
	if cmp(arrows, K_MSI) == 1 then
		r = clone(arrows)
		local en, mg = toNumber(expans), toNumber(megota)
		setOp(r.a, getOp(r.a, huge, en, mg) + 1, huge, en, mg)
		return r
	end
	local arrowsNum = toNumber(arrows)
	if eqK(other, KK.n2) then
		return BEAF_core(t, t, arrowsNum - 1, expans, megota, powiaina2, depth + 1)
	end
	local en, mn = toNumber(expans), toNumber(megota)
	if cmp(maxPick(t, other), getMSIForm(arrowsNum + 1, en, mn)) == 1 then
		return clone(maxPick(t, other))
	end
	if cmp(t, getMSIForm(arrowsNum + 1, en, mn)) == 1 or cmp(other, K_MSI) == 1 then
		if cmp(t, getMSIForm(arrowsNum, en, mn)) == 1 then
			r = clone(t)
			setOp(r.a, getOp(r.a, arrowsNum, en, mn) - 1, arrowsNum, en, mn)
			normalize(r)
		elseif cmp(t, getMSIForm(arrowsNum - 1, en, mn)) == 1 then
			r = fromNumber(getOp(t.a, arrowsNum - 1, en, mn))
		else
			r = mkZero()
		end
		local j = add(r, other)
		setOp(j.a, getOp(j.a, arrowsNum, en, mn) + 1, arrowsNum, en, mn)
		normalize(j)
		return j
	end
	if depth >= MAXOPS + 10 then
		return { s = 1, y = 0, sm = false, a = { newOp(10, 0, 1, 1), newOp(1, arrowsNum, en, mn) } }
	end
	local y = toNumber(other)
	local f = floor(y)
	local arrows_m1 = sub(arrows, mkOne())
	r = BEAF_core(t, y - f, arrows_m1, expans, megota, powiaina, depth + 1)
	local i = 0
	local m = getMSIForm(arrowsNum - 1, en, mn)
	while f ~= 0 and cmp(r, m) == -1 and i < 100 do
		burn()
		if f > 0 then
			r = BEAF_core(t, r, arrows_m1, expans, megota, powiaina, depth + 1)
			f -= 1
		end
		i += 1
	end
	if i == 100 then
		f = 0
	end
	setOp(r.a, getOp(r.a, arrowsNum - 1, en, mn) + f, arrowsNum - 1, en, mn)
	normalize(r)
	return r
end

local function ga(v: any): Hyper -- BEAF getArgs
	if v ~= nil then
		return N(v)
	end
	return fromNumber(1)
end

local function BEAF(...: any): Hyper
	local n = select("#", ...)
	local a1, a2, a3, a4, a5, a6 = ...
	if eqK(ga(a1), K_1) then
		return fromNumber(1)
	end
	if eqK(ga(a2), K_1) then
		return N(ga(a1))
	end
	if eqK(ga(a6), KK.n2) and (gteC(cmp(ga(a5), KK.n2)) or gteC(cmp(ga(a4), KK.n2)) or gteC(cmp(ga(a3), KK.n2))) then
		return mkPosInf()
	end
	for i = 7, n do
		local v = select(i, ...)
		if cmp(N(v), K_1) == 1 then
			return mkPosInf()
		end
	end
	return BEAF_core(ga(a1), ga(a2), ga(a3), ga(a4), ga(a5), ga(a6), 0)
end

--------------------------------------------------------------------------------------------------------------
-- series helpers (break_eternity)
--------------------------------------------------------------------------------------------------------------

local function maxS(a: any, b: any): Hyper -- PowiainaNum.max(a, b)
	local m = mkNegInf()
	if cmp(m, R(a)) == -1 then
		m = N(a)
	end
	if cmp(m, R(b)) == -1 then
		m = N(b)
	end
	return m
end
local function minS(a: any, b: any): Hyper -- PowiainaNum.min(a, b)
	local m = mkPosInf()
	if cmp(m, R(a)) == 1 then
		m = N(a)
	end
	if cmp(m, R(b)) == 1 then
		m = N(b)
	end
	return m
end

local function affordGeometricSeriesCore(res: Hyper, start: Hyper, ratio: Hyper, owned: any, protect: boolean?): Hyper
	local withNaNProtect = if protect == nil then true else protect
	local actualStart = mul(start, pow(ratio, owned))
	local q = div(res, actualStart)
	local q2 = mul(q, sub(ratio, 1))
	local q3 = add(q2, 1)
	local q4 = maxS(q3, if withNaNProtect then 1 else -huge)
	local q5 = log10m(q4)
	return floorv(div(q5, log10m(ratio)))
end

local function sumGeometricSeriesCore(numItems: any, start: Hyper, ratio: Hyper, owned: any): Hyper
	local a = mul(start, pow(ratio, owned))
	local b = mul(a, sub(fromNumber(1), pow(ratio, numItems)))
	return div(b, sub(fromNumber(1), ratio))
end

local function affordArithmeticSeriesCore(res: Hyper, start: Hyper, addv: Hyper, owned: Hyper): Hyper
	local actualStart = add(start, mul(owned, addv))
	local b = sub(actualStart, div(addv, 2))
	local b2 = pow(b, 2)
	local nb = negv(b)
	local inner = sqrtv(add(b2, mul(mul(addv, res), 2)))
	return floorv(div(add(nb, inner), addv))
end

local function sumArithmeticSeriesCore(numItems: Hyper, start: Hyper, addv: Hyper, owned: Hyper): Hyper
	local actualStart = add(start, mul(owned, addv))
	local half = div(numItems, 2)
	local t1 = mul(actualStart, 2)
	local t2 = mul(sub(numItems, 1), addv)
	return mul(half, add(t1, t2))
end

--------------------------------------------------------------------------------------------------------------
-- toString
--------------------------------------------------------------------------------------------------------------

local function toStringCore(x: Hyper): string?
	if #x.a == 0 then
		return nil
	end
	local sg = x.s
	if (sg == 1 or sg == -1) and x.y == 0 then
		-- plain / [r, (10^)^k] shapes: what the generic code below produces for them
		local n, r, k = nfShape(x)
		if n ~= 0 then
			local body
			if n == 1 then
				body = numstr(r)
			elseif k < 5 then
				body = srep("e", k) .. numstr(r)
			else
				body = "(10{1})^" .. numstr(k) .. " " .. numstr(r)
			end
			if x.sm then
				body = "/" .. body
			end
			if sg == -1 then
				body = "-" .. body
			end
			return body
		end
	end
	if isNaNv(x) then
		return "NaN"
	end
	if x.s == -1 then
		return "-" .. toStringSafe(negv(x))
	end
	if x.sm then
		if isZero(x) then
			return "0"
		end
		return "/" .. toStringSafe(recv(x))
	end
	if isInfi(x) then
		return "Infinity"
	end
	local buf = {}
	local L = x.y
	if truthy(L) then
		if L < 3 then
			local r = jsRepeat("P", L)
			if r == nil then
				return nil
			end
			buf[1] = r
		else
			buf[1] = "P^" .. numstr(L) .. " "
		end
	end
	local arr = x.a
	for i = #arr, 1, -1 do
		local o = arr[i]
		local ar, ex, me, re = o.ar, o.ex, o.me, o.re
		if ar == 1 and ex == 1 and me == 1 and re < 5 then
			local r = jsRepeat("e", re)
			if r == nil then
				return nil
			end
			buf[#buf + 1] = r
		elseif ar == 0 and ex == 1 and me == 1 then
			buf[#buf + 1] = numstr(re)
		else
			local c = "10{"
				.. (if ar == huge then "!" else numstr(ar))
				.. (if ex > 1 or me > 1 then "," .. (if ex == huge then "!" else numstr(ex)) else "")
				.. (if me > 1 then "," .. numstr(me) else "")
				.. "}"
			if re > 1 then
				buf[#buf + 1] = "(" .. c .. ")^" .. numstr(re) .. " "
			else
				buf[#buf + 1] = c
			end
		end
	end
	return tconcat(buf)
end
toStringSafe = function(x: Hyper): string
	local r = toStringCore(x)
	if r == nil then
		return "NaN"
	end
	return r
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--
-- Inputs are never written to. Functions that PN implements by mutating their receiver (add/sub normalize it,
-- slog/tetrate/arrow/... edit it in place) get a private copy, exactly like PN's static wrappers
-- (`PowiainaNum.add(t, o)` = `new PowiainaNum(t).add(o)`). Read-only ones use the input directly and may
-- return it unchanged.
--------------------------------------------------------------------------------------------------------------

do
-- receiver for add/sub: normalize() is applied to it in place, so copy unless it is already in normal form
local function recvNorm(a: any): Hyper
	if type(a) == "table" and a.a ~= nil then
		if isNormalFast(a) then
			return a
		end
		return clone(a)
	end
	return N(a)
end

--- Converts a number, string or object form into a Hyper value. A Hyper value is returned unchanged.
--- Object forms (as PowiainaNum.fromObject): an ExpantaNum array of pairs {{arrow, repeat}, ...}; a 0.1.x
--- array {base, {arrow|"x", repeat, expans|"x", megota}, ...}; a break_eternity {sign=, layer=, mag=};
--- a PowiainaNum-like {array={{arrow=,expans=,megota=,repeat=}}, small=, sign=, layer=}.
--- Like PN, object forms are copied but not normalized.
function Hyper.from(v: any): Hyper
	refuel()
	return R(v)
end
Hyper.fromNumber = fromNumber
--- PowiainaNum constructor semantics: malformed strings give NaN.
function Hyper.fromString(s: string): Hyper
	refuel()
	return parseShared(s) -- frozen, shared by every parse of the same (short) string
end
--- PowiainaNum.fromString semantics: returns nil (PN throws) for malformed strings.
function Hyper.parse(s: string): Hyper?
	refuel()
	return fromStringImpl(s)
end
function Hyper.fromObject(o: any): Hyper
	refuel()
	return N(o)
end
function Hyper.normalize(v: any): Hyper
	refuel()
	return normalize(N(v))
end
function Hyper.toString(v: any): string
	refuel()
	return toStringSafe(R(v))
end
function Hyper.toJSON(v: any): string
	refuel()
	return "PN" .. toStringSafe(R(v))
end
function Hyper.toNumber(v: any): number
	refuel()
	return toNumber(R(v))
end
function Hyper.isHyper(v: any): boolean
	refuel()
	return type(v) == "table" and type(v.a) == "table" and type(v.s) == "number"
end

-- basic arithmetic
function Hyper.abs(a: any): Hyper
	refuel()
	return absv(R(a))
end
function Hyper.neg(a: any): Hyper
	refuel()
	return negv(R(a))
end
function Hyper.rec(a: any): Hyper
	refuel()
	return recv(R(a))
end
Hyper.recip = Hyper.rec
function Hyper.add(a: any, b: any): Hyper
	refuel()
	return add(recvNorm(a), b)
end
Hyper.plus = Hyper.add
function Hyper.sub(a: any, b: any): Hyper
	refuel()
	return sub(recvNorm(a), b)
end
Hyper.minus = Hyper.sub
function Hyper.mul(a: any, b: any): Hyper
	refuel()
	return mul(R(a), b)
end
Hyper.times = Hyper.mul
function Hyper.div(a: any, b: any): Hyper
	refuel()
	return div(R(a), b)
end
Hyper.divide = Hyper.div
function Hyper.mod(a: any, b: any): Hyper
	refuel()
	return mod(N(a), b)
end
function Hyper.pow(a: any, b: any): Hyper
	refuel()
	return pow(R(a), b)
end
function Hyper.pow10(a: any): Hyper
	refuel()
	return pow10(R(a))
end
--- b ^ a (PN: a.pow_base(b))
function Hyper.pow_base(a: any, b: any): Hyper
	refuel()
	return pow(N(b), a)
end
function Hyper.root(a: any, b: any): Hyper
	refuel()
	return root(R(a), b)
end
function Hyper.sqrt(a: any): Hyper
	refuel()
	return sqrtv(R(a))
end
function Hyper.cbrt(a: any): Hyper
	refuel()
	return cbrtv(R(a))
end
function Hyper.log10(a: any): Hyper
	refuel()
	return log10m(R(a))
end
--- log(a, base = e)
function Hyper.log(a: any, base: any): Hyper
	refuel()
	return logm(R(a), base)
end
function Hyper.ln(a: any): Hyper
	refuel()
	return logm(R(a))
end
function Hyper.log2(a: any): Hyper
	refuel()
	return logm(R(a), 2)
end
function Hyper.logBase(a: any, base: any): Hyper
	refuel()
	return logm(R(a), base)
end
function Hyper.pLog10(a: any): Hyper
	refuel()
	local x = R(a)
	if x.s < 0 then
		return mkZero()
	end
	return log10m(x)
end
function Hyper.exp(a: any): Hyper
	refuel()
	return expS(a)
end

-- comparison
function Hyper.cmp(a: any, b: any): number
	refuel()
	return cmp(R(a), R(b))
end
Hyper.compare = Hyper.cmp
function Hyper.eq(a: any, b: any): boolean
	refuel()
	return cmp(R(a), R(b)) == 0
end
Hyper.equals = Hyper.eq
function Hyper.neq(a: any, b: any): boolean
	refuel()
	return cmp(R(a), R(b)) ~= 0
end
Hyper.notEquals = Hyper.neq
function Hyper.lt(a: any, b: any): boolean
	refuel()
	return cmp(R(a), R(b)) == -1
end
function Hyper.lte(a: any, b: any): boolean
	refuel()
	local c = cmp(R(a), R(b))
	return c == -1 or c == 0
end
function Hyper.gt(a: any, b: any): boolean
	refuel()
	return cmp(R(a), R(b)) == 1
end
function Hyper.gte(a: any, b: any): boolean
	refuel()
	local c = cmp(R(a), R(b))
	return c == 0 or c == 1
end
function Hyper.cmpabs(a: any, b: any): number
	refuel()
	return cmpAbsAbs(R(a), R(b))
end
local function maxPub(a: any, b: any): Hyper
	refuel()
	local x, y = R(a), R(b)
	local m = maxPick(x, y)
	if m == K_NEG_INF then
		return mkNegInf()
	end
	return m
end
local function minPub(a: any, b: any): Hyper
	refuel()
	local x, y = R(a), R(b)
	local m = minPick(x, y)
	if m == K_POS_INF then
		return mkPosInf()
	end
	return m
end
Hyper.max = maxPub
Hyper.min = minPub
Hyper.clampMin = maxPub
Hyper.clampMax = minPub
function Hyper.clamp(a: any, lo: any, hi: any): Hyper
	refuel()
	return minPub(maxPub(a, lo), hi)
end
function Hyper.maxabs(a: any, b: any): Hyper
	refuel()
	return maxS(absv(R(a)), absv(R(b)))
end
function Hyper.minabs(a: any, b: any): Hyper
	refuel()
	return minS(absv(R(a)), absv(R(b)))
end
--- PN.max/min over any number of arguments
function Hyper.maxN(...: any): Hyper
	refuel()
	local m = mkNegInf()
	for i = 1, select("#", ...) do
		local v = R((select(i, ...)))
		if cmp(m, v) == -1 then
			m = v
		end
	end
	return m
end
function Hyper.minN(...: any): Hyper
	refuel()
	local m = mkPosInf()
	for i = 1, select("#", ...) do
		local v = R((select(i, ...)))
		if cmp(m, v) == 1 then
			m = v
		end
	end
	return m
end
function Hyper.eq_tolerance(a: any, b: any, tolerance: number?): boolean
	refuel()
	local tol = if tolerance == nil then 1e-7 else tolerance
	local this = N(a)
	local dec = N(b)
	local lhs = sub(this, dec)
	local rhs = mul(maxS(this, dec), tol)
	local c = cmp(lhs, rhs)
	return c == -1 or c == 0
end

-- rounding
function Hyper.floor(a: any): Hyper
	refuel()
	return floorv(R(a))
end
function Hyper.ceil(a: any): Hyper
	refuel()
	return ceilv(R(a))
end
function Hyper.round(a: any): Hyper
	refuel()
	return roundv(R(a))
end
function Hyper.trunc(a: any): Hyper
	refuel()
	return truncv(R(a))
end

-- predicates
function Hyper.isNaN(a: any): boolean
	refuel()
	return isNaNv(R(a))
end
function Hyper.isZero(a: any): boolean
	refuel()
	return isZero(R(a))
end
function Hyper.isFinite(a: any): boolean
	refuel()
	return isFiniteV(R(a))
end
function Hyper.isInfi(a: any): boolean
	refuel()
	return isInfi(R(a))
end
Hyper.isInfinite = Hyper.isInfi
function Hyper.isInfiNaN(a: any): boolean
	refuel()
	return isInfiNaN(R(a))
end
function Hyper.isInt(a: any): boolean
	refuel()
	return isInt(R(a))
end
function Hyper.ispos(a: any): boolean
	refuel()
	return R(a).s > 0
end
function Hyper.isneg(a: any): boolean
	refuel()
	return R(a).s < 0
end
function Hyper.sign(a: any): number
	refuel()
	return R(a).s
end

-- special functions
function Hyper.factorial(a: any): Hyper
	refuel()
	return factorial(N(a))
end
function Hyper.gamma(a: any): Hyper
	refuel()
	return gamma(N(a))
end
function Hyper.lambertw(a: any, principal: boolean?): Hyper
	refuel()
	return lambertw(N(a), principal)
end

-- tetration family
function Hyper.tetrate(a: any, height: any, payload: any): Hyper
	refuel()
	return tetrate(N(a), height, payload)
end
Hyper.tetr = Hyper.tetrate
function Hyper.tetrate_10(height: any): Hyper
	refuel()
	return tetrate(fromNumber(10), height, nil)
end
function Hyper.slog(a: any, base: any): Hyper
	refuel()
	return slog(N(a), base)
end
function Hyper.ssqrt(a: any): Hyper
	refuel()
	return ssqrt(N(a))
end
function Hyper.iteratedlog(a: any, times: any, base: any): Hyper
	refuel()
	return iteratedlog(N(a), times, base)
end

-- arrows
--- a {arrows} other (PN: a.arrow(arrows)(other, payload))
function Hyper.arrow(a: any, arrows: any, other: any, payload: any): Hyper
	refuel()
	return arrowCall(N(a), arrows, other, payload, nil)
end
function Hyper.chain(a: any, other: any, arrows: any): Hyper
	refuel()
	return arrowCall(N(a), arrows, other, nil, nil)
end
function Hyper.pentate(a: any, other: any, payload: any): Hyper
	refuel()
	return arrowCall(N(a), 3, other, payload, nil)
end
Hyper.pent = Hyper.pentate
function Hyper.hexate(a: any, other: any, payload: any): Hyper
	refuel()
	return arrowCall(N(a), 4, other, payload, nil)
end
--- x such that base {arrows} x = a (PN: a.anyarrow_log(arrows)(base))
function Hyper.anyarrow_log(a: any, arrows: any, base: any): Hyper
	refuel()
	return anyarrowLog(N(a), arrows, base, nil)
end
Hyper.arrow_height_inverse = Hyper.anyarrow_log
function Hyper.penta_log(a: any, base: any): Hyper
	refuel()
	return anyarrowLog(N(a), 3, if base == nil then 10 else base, nil)
end
function Hyper.omegalog(a: any, base: any, epsilon: number?): Hyper
	refuel()
	return omegalog(N(a), base, epsilon)
end
function Hyper.arrFrac(base: any, height: any): Hyper
	refuel()
	return arrFrac(base, height)
end

-- expansion family
function Hyper.expansion(a: any, other: any): Hyper
	refuel()
	return expansion(N(a), other)
end
function Hyper.expansionArrow(a: any, arrows: any, other: any): Hyper
	refuel()
	return expansionArrowCall(N(a), arrows, other, nil)
end
function Hyper.multiExpansion(a: any, other: any): Hyper
	refuel()
	return expansionArrowCall(N(a), 2, other, nil)
end
function Hyper.powerExpansion(a: any, other: any): Hyper
	refuel()
	return expansionArrowCall(N(a), 3, other, nil)
end
function Hyper.expansion_log_inner(a: any, base: any): Hyper
	refuel()
	return expansionLogInner(N(a), base)
end
function Hyper.expansion_log2(a: any, arrows: any, base: any): Hyper
	refuel()
	return expansionLog2Call(N(a), arrows, base, nil)
end
Hyper.arrow_w2_height_inverse = Hyper.expansion_log2
function Hyper.omega2log(a: any, base: any, epsilon: number?): Hyper
	refuel()
	return omega2log(N(a), base, epsilon)
end
function Hyper.arrw2Frac(base: any, height: any): Hyper
	refuel()
	return arrw2Frac(base, height)
end
function Hyper.explosion(a: any, other: any): Hyper
	refuel()
	return BEAF(a, other, 1, 3)
end
function Hyper.megotion(a: any, other: any): Hyper
	refuel()
	return BEAF(a, other, 1, 1, 2)
end
function Hyper.powiaination(a: any, other: any): Hyper
	refuel()
	return BEAF(a, other, 1, 1, 1, 2)
end
--- BEAF array {base, power, arrow, expans, megota, powiaina, ...}
function Hyper.BEAF(...: any): Hyper
	refuel()
	return BEAF(...)
end
function Hyper.BEAF_core(base: any, power: any, arrow: any, expans: any, megota: any, powiaina: any): Hyper
	refuel()
	return BEAF_core(base, power, arrow, expans, megota, powiaina, 0)
end
function Hyper.grahalFunction(layers2: any): Hyper
	refuel()
	local layers = N(layers2)
	if not isInt(layers) or cmp(layers, K_0) == -1 or isNaNv(layers) then
		return mkNaN()
	end
	if eqK(layers, K_1) then
		return fromStringCtor("10^^^(10^)^7625597484984 3638334640023.7783")
	end
	local c = cmp(layers, K_MSI)
	if c == -1 or c == 0 then
		return fromStringCtor("(10{!})^" .. numstr(toNumber(layers)) .. " 10^^^(10^)^7625597484984 3638334640023.7783")
	end
	return BEAF(3, layers, 1, 2)
end

-- series (break_eternity)
function Hyper.affordGeometricSeries(resources: any, priceStart: any, priceRatio: any, currentOwned: any): Hyper
	refuel()
	return affordGeometricSeriesCore(N(resources), N(priceStart), N(priceRatio), currentOwned, true)
end
function Hyper.sumGeometricSeries(numItems: any, priceStart: any, priceRatio: any, currentOwned: any): Hyper
	refuel()
	return sumGeometricSeriesCore(numItems, N(priceStart), N(priceRatio), currentOwned)
end
function Hyper.affordArithmeticSeries(resources: any, priceStart: any, priceAdd: any, currentOwned: any): Hyper
	refuel()
	return affordArithmeticSeriesCore(N(resources), N(priceStart), N(priceAdd), N(currentOwned))
end
function Hyper.sumArithmeticSeries(numItems: any, priceStart: any, priceAdd: any, currentOwned: any): Hyper
	refuel()
	return sumArithmeticSeriesCore(N(numItems), N(priceStart), N(priceAdd), N(currentOwned))
end

-- operators
function Hyper.getOperator(a: any, arrow: number, expans: number?, megota: number?): number
	refuel()
	return getOp(R(a).a, arrow, expans, megota)
end
--- returns a copy of `a` with that operator's repeat set (PN setOperator, which does not normalize)
function Hyper.setOperator(a: any, val: number, arrow: number, expans: number?, megota: number?): Hyper
	refuel()
	local x = N(a)
	setOp(x.a, val, arrow, expans, megota)
	return x
end
function Hyper.getOperatorIndex(a: any, arrow: number, expans: number?, megota: number?): number
	refuel()
	return opIndex(R(a).a, arrow, expans or 1, megota or 1)
end

--------------------------------------------------------------------------------------------------------------
-- Bridging helpers for a 10^^x based library
--------------------------------------------------------------------------------------------------------------

--- The PN value of 10^^x (PowiainaNum.tetrate(10, x)) for a real x >= 0.
function Hyper.tetr10(x: number): Hyper
	refuel()
	return tetrate(fromNumber(10), x, nil)
end

--- The real height x with h = 10^^x, as PowiainaNum's slog(10) computes it, converted to a number
--- (so +inf past 10^^1.8e308, and NaN where PN's slog is NaN).
function Hyper.slogOf(h: any): number
	refuel()
	return toNumber(slog(N(h), 10))
end

-- constants (frozen; PN's static constants)
Hyper.ZERO = K_ZERO
Hyper.ONE = K_ONE
Hyper.NaN = KK.NAN
Hyper.POSITIVE_INFINITY = K_POS_INF
Hyper.NEGATIVE_INFINITY = K_NEG_INF
Hyper.MSI = K_MSI
Hyper.MSI_REC = KK.MSI_REC
Hyper.E_MSI = K_E_MSI
Hyper.EE_MSI = KK.EE_MSI
Hyper.E_MSI_REC = KK.E_MSI_REC
Hyper.TETRATED_MSI = K_TETRATED_MSI
Hyper.PENTATED_MSI = KK.PENTATED_MSI
Hyper.TRITRI = deepFreeze({
	s = 1,
	y = 0,
	sm = false,
	a = { newOp(3638334640023.7783, 0, 1, 1), newOp(7625587484984, 1, 1, 1) },
})
Hyper.GRAHAMS_NUMBER = K("(10{!})^63 10^^^(10^)^7625597484984 3638334640023.7783")
Hyper.E = K(MATH_E)
Hyper.LN2 = K(0.6931471805599453)
Hyper.LN10 = K(2.302585092994046)
Hyper.LOG2E = K(1.4426950408889634)
Hyper.LOG10E = K(0.4342944819032518)
Hyper.PI = K(3.141592653589793)
Hyper.SQRT1_2 = K(0.7071067811865476)
Hyper.SQRT2 = K(1.4142135623730951)
Hyper.maxOps = MAXOPS
Hyper._setCapFix = Hyper_setCapFix
Hyper._capFixHits = Hyper_capFixHits

end
return Hyper
