--!strict
--[[
	Rich: text helpers (DESIGN.md 9).

	    Rich.caps("ready")                   "R E A D Y" with U+200A hair spaces (Roblox has no letter-spacing)
	    Rich.html(html, 13, "p", preLine)   the game's HTML as RichText, game colours remapped (DESIGN.md 11.2)
	    Rich.fit(label, { 56, 48, 40 }, w)  the first size whose text fits the width (display roles only)
	    Rich.num("+e1.073e25 prestige points", { size = 17 })
	                                         numeral runs stay in the label's Sarpanch face, words and units become a
	                                         Montserrat Bold run, exponent markers dim (DESIGN.md 9.9)
	    Rich.pct(0.4) -> "40%"               0 decimals from 10%, 1 below (DESIGN.md 9.9)
	    Rich.short("+e483,525,689") -> "+e4.84e8"   the short form for narrow chips and pills (DESIGN.md 9.9)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Html = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Html"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Rich = {}

Rich.HAIR = utf8.char(0x200A)
-- switch off if the hair space renders as tofu (plan risk R10): caps then use plain upper case
Rich.useHair = true

-- upper case with a hair space between letters (spaces stay spaces)
function Rich.caps(s: string): string
	local up = string.upper(s)
	if not Rich.useHair then return up end
	local out = {}
	local prevLetter = false
	for _, cp in utf8.codes(up) do
		local ch = utf8.char(cp)
		local letter = ch ~= " " and ch ~= "\n"
		if letter and prevLetter then table.insert(out, Rich.HAIR) end
		table.insert(out, ch)
		prevLetter = letter
	end
	return table.concat(out)
end

-- the game's HTML -> RichText at a base size, with the colour remap of the layer
function Rich.html(html: string?, base: number, layer: string?, preLine: boolean?): string
	return Html.rich(html, base, preLine, Theme.remapper(layer))
end

-- the game's HTML as plain text (tooltips, plates)
function Rich.plain(html: string?): string
	return Html.plain(html)
end

-- step-fit: the first size in `sizes` (largest first) at which the label's text is at most maxW wide
function Rich.fit(l: TextLabel, sizes: { number }, maxW: number)
	for i, size in sizes do
		l.TextSize = size
		if i == #sizes or l.TextBounds.X <= maxW then return end
	end
end

-- ------------------------------------------------------------------------------------------------------ numbers
-- DESIGN.md 9.9: re-typeset a game-formatted number string; format() output is never recomputed
Rich.THIN = utf8.char(0x2009)
-- switch off if the thin space renders as tofu (plan risk R10): units then follow a normal space
Rich.useThin = true
Rich.MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local DIGIT0, DIGIT9 = 48, 57
local function isDigit(cp: number?): boolean
	return cp ~= nil and cp >= DIGIT0 and cp <= DIGIT9
end
local function isLetter(cp: number?): boolean
	return cp ~= nil and ((cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122))
end
local E, PLUS, MINUS, UMINUS, TIMES, DOT, COMMA, PCT, X, CARET, SPACE, SLASH = 101, 43, 45, 0x2212, 0xD7, 46, 44, 37, 120, 94, 32, 47
-- an exponent marker: e followed by a digit, or by a sign and a digit
local function expAt(cps: { number }, i: number): boolean
	if cps[i] ~= E then return false end
	local n = cps[i + 1]
	if isDigit(n) then return true end
	return (n == PLUS or n == MINUS) and isDigit(cps[i + 2])
end
-- a numeral run may start here: a digit, an exponent marker, or a sign / × / ^ in front of one
local function startsNumber(cps: { number }, i: number): boolean
	local c = cps[i]
	if isDigit(c) or expAt(cps, i) then
		-- not inside a word such as "C21", "type2" or the zone id "a-02"
		local prev = cps[i - 1]
		if prev == MINUS and isLetter(cps[i - 2]) then return false end
		return not isLetter(prev) and not isDigit(prev)
	end
	if c == PLUS or c == MINUS or c == UMINUS or c == TIMES or c == CARET then
		local prev = cps[i - 1]
		if isLetter(prev) or isDigit(prev) then return false end -- "a-02" is a word
		return isDigit(cps[i + 1]) or expAt(cps, i + 1)
	end
	return false
end

local function escape(t: string): string
	return (string.gsub(string.gsub(string.gsub(t, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
local function chars(cps: { number }, a: number, b: number): string
	local out = table.create(b - a + 1)
	for i = a, b do table.insert(out, utf8.char(cps[i])) end
	return table.concat(out)
end

-- percentages: 0 decimals from 10%, 1 below; "100%" only at 1 (have >= need)
function Rich.pct(p: number): string
	if p >= 1 then return "100%" end
	local v = math.max(0, p) * 100
	if v >= 10 then return string.format("%d%%", math.min(99, math.floor(v))) end
	local t = math.floor(v * 10) / 10
	if t == math.floor(t) then return string.format("%d%%", t) end
	return string.format("%.1f%%", t)
end

export type NumOpts = {
	size: number?, -- the label's TextSize: word runs are set at .85 of it (at least the small role's size)
	unit: Color3?, -- word-run colour (default: soft); ignored when onFill
	onFill: boolean?, -- on a bright fill / well: word runs keep the label colour at alpha .8
}
-- a game number string -> RichText (the label keeps its Sarpanch FontFace and RichText = true)
function Rich.num(s: string, o: NumOpts?): string
	local opts: NumOpts = o or {}
	local cps: { number } = {}
	for _, cp in utf8.codes(s) do table.insert(cps, cp) end
	local n = #cps
	local wordOpen: string
	do
		local attrs = { string.format('family="%s" weight="700"', Rich.MONTSERRAT) }
		-- words at .85 of the number, never under the mixed-case floor (the small role's size, DESIGN.md 9.5)
		if opts.size then
			local wsize = math.max(math.floor(opts.size * 0.85 + 0.5), Theme.size("small"))
			table.insert(attrs, string.format('size="%d"', wsize))
		end
		if opts.onFill then
			table.insert(attrs, 'transparency="0.2"')
		else
			table.insert(attrs, string.format('color="#%s"', Theme.toHex(opts.unit or Theme.C.soft)))
		end
		wordOpen = "<font " .. table.concat(attrs, " ") .. ">"
	end
	local out: { string } = {}
	local i = 1
	local afterNumber = false
	while i <= n do
		if startsNumber(cps, i) then
			-- one numeral run
			local a = i
			local j = i
			local parts: { string } = {}
			local plainPct = true
			while j <= n do
				local c = cps[j]
				if isDigit(c) then
					table.insert(parts, utf8.char(c))
				elseif (c == DOT or c == COMMA or c == SLASH) and isDigit(cps[j + 1]) and j > a then
					-- "1,329,005", "6.424", "164/185"
					table.insert(parts, utf8.char(c))
					if c ~= DOT then plainPct = false end
				elseif expAt(cps, j) then
					table.insert(parts, '<font transparency="0.3">e</font>')
					plainPct = false
				elseif j == a and (c == PLUS or c == MINUS or c == UMINUS or c == CARET) then
					table.insert(parts, utf8.char(c))
					plainPct = false
				elseif c == TIMES and (j == a or isDigit(cps[j - 1])) then
					-- "× e2.296e21": a thin space between the sign and an exponent
					table.insert(parts, utf8.char(c))
					if cps[j + 1] == E and Rich.useThin then table.insert(parts, Rich.THIN) end
					plainPct = false
				elseif (c == PCT or c == X) and isDigit(cps[j - 1]) and not isLetter(cps[j + 1]) then
					table.insert(parts, utf8.char(c))
					j += 1
					break
				else
					break
				end
				j += 1
			end
			local run = table.concat(parts)
			local last = cps[j - 1]
			-- "63.000%" -> "63%", "4.2%" (DESIGN.md 9.9 rule 3)
			if last == PCT and plainPct then
				local v = tonumber(chars(cps, a, j - 2))
				if v then run = Rich.pct(v / 100) end
			end
			table.insert(out, run)
			afterNumber = true
			i = j
		else
			-- one word run (up to the next number)
			local a = i
			local j = i
			while j <= n and not startsNumber(cps, j) do j += 1 end
			local b = j - 1
			local lead = ""
			if afterNumber and cps[a] == SPACE and Rich.useThin then
				lead = Rich.THIN
				a += 1
			end
			local word = if a <= b then chars(cps, a, b) else ""
			if string.find(word, "%S") then
				table.insert(out, lead .. wordOpen .. escape(word) .. "</font>")
			else
				table.insert(out, lead .. escape(word))
			end
			afterNumber = false
			i = j
		end
	end
	return table.concat(out)
end

-- DESIGN.md 9.9 rule 5: exponent runs with >= 7 digits step to the short form of the same value in narrow slots
-- ("+e483,525,689" -> "+e4.84e8", "1e1,234,567" -> "e1.23e6"); everything else is returned unchanged
function Rich.short(s: string): string
	local sign, mant, expo, rest = string.match(s, "^([%+%-]?)([%d%.]*)e([%d,]+)(.*)$")
	if sign == nil or mant == nil or expo == nil or rest == nil then return s end
	local digits = string.gsub(expo, ",", "")
	if #digits < 7 then return s end
	local e = tonumber(digits)
	if e == nil then return s end
	local m = if mant ~= "" then tonumber(mant) else nil
	-- mant e N (N >= 1e6) is 10^(N + log10 mant); a leading "e" means 10^N already
	local power = e + (if m and m > 0 then math.log10(m) else 0)
	local p = math.floor(math.log10(power))
	local head = power / 10 ^ p
	if head >= 9.995 then
		head /= 10
		p += 1
	end
	return string.format("%se%.2fe%d%s", sign, head, p, rest)
end

return Rich
