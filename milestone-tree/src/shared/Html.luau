--!strict
--[[
	Html: the game's HTML strings -> Roblox RichText, plus the CSS pieces the UI needs (colours, lengths).

	The web game writes its text as HTML for a browser: <br>, <h2>/<h3> (inline in this game's CSS), <b>, <i>,
	<span style="color: ...; font-size: ...; text-shadow: ...">, <hr>, <div style=...>, a few gradient-text classes
	and one <svg> (the exploration map). Html.rich turns that into RichText at a given base text size; Html.split
	pulls <svg> blocks out first so the UI can draw them.
]]

local Html = {}

-- ---------------------------------------------------------------------------------------------------------- colours
local NAMED: { [string]: string } = {
	aliceblue = "f0f8ff", antiquewhite = "faebd7", aqua = "00ffff", aquamarine = "7fffd4", azure = "f0ffff",
	beige = "f5f5dc", bisque = "ffe4c4", black = "000000", blanchedalmond = "ffebcd", blue = "0000ff",
	blueviolet = "8a2be2", brown = "a52a2a", burlywood = "deb887", cadetblue = "5f9ea0", chartreuse = "7fff00",
	chocolate = "d2691e", coral = "ff7f50", cornflowerblue = "6495ed", cornsilk = "fff8dc", crimson = "dc143c",
	cyan = "00ffff", darkblue = "00008b", darkcyan = "008b8b", darkgoldenrod = "b8860b", darkgray = "a9a9a9",
	darkgreen = "006400", darkgrey = "a9a9a9", darkkhaki = "bdb76b", darkmagenta = "8b008b",
	darkolivegreen = "556b2f", darkorange = "ff8c00", darkorchid = "9932cc", darkred = "8b0000",
	darksalmon = "e9967a", darkseagreen = "8fbc8f", darkslateblue = "483d8b", darkslategray = "2f4f4f",
	darkslategrey = "2f4f4f", darkturquoise = "00ced1", darkviolet = "9400d3", deeppink = "ff1493",
	deepskyblue = "00bfff", dimgray = "696969", dimgrey = "696969", dodgerblue = "1e90ff", firebrick = "b22222",
	floralwhite = "fffaf0", forestgreen = "228b22", fuchsia = "ff00ff", gainsboro = "dcdcdc", ghostwhite = "f8f8ff",
	gold = "ffd700", goldenrod = "daa520", gray = "808080", green = "008000", greenyellow = "adff2f",
	grey = "808080", honeydew = "f0fff0", hotpink = "ff69b4", indianred = "cd5c5c", indigo = "4b0082",
	ivory = "fffff0", khaki = "f0e68c", lavender = "e6e6fa", lavenderblush = "fff0f5", lawngreen = "7cfc00",
	lemonchiffon = "fffacd", lightblue = "add8e6", lightcoral = "f08080", lightcyan = "e0ffff",
	lightgoldenrodyellow = "fafad2", lightgray = "d3d3d3", lightgreen = "90ee90", lightgrey = "d3d3d3",
	lightpink = "ffb6c1", lightsalmon = "ffa07a", lightseagreen = "20b2aa", lightskyblue = "87cefa",
	lightslategray = "778899", lightslategrey = "778899", lightsteelblue = "b0c4de", lightyellow = "ffffe0",
	lime = "00ff00", limegreen = "32cd32", linen = "faf0e6", magenta = "ff00ff", maroon = "800000",
	mediumaquamarine = "66cdaa", mediumblue = "0000cd", mediumorchid = "ba55d3", mediumpurple = "9370db",
	mediumseagreen = "3cb371", mediumslateblue = "7b68ee", mediumspringgreen = "00fa9a",
	mediumturquoise = "48d1cc", mediumvioletred = "c71585", midnightblue = "191970", mintcream = "f5fffa",
	mistyrose = "ffe4e1", moccasin = "ffe4b5", navajowhite = "ffdead", navy = "000080", oldlace = "fdf5e6",
	olive = "808000", olivedrab = "6b8e23", orange = "ffa500", orangered = "ff4500", orchid = "da70d6",
	palegoldenrod = "eee8aa", palegreen = "98fb98", paleturquoise = "afeeee", palevioletred = "db7093",
	papayawhip = "ffefd5", peachpuff = "ffdab9", peru = "cd853f", pink = "ffc0cb", plum = "dda0dd",
	powderblue = "b0e0e6", purple = "800080", rebeccapurple = "663399", red = "ff0000", rosybrown = "bc8f8f",
	royalblue = "4169e1", saddlebrown = "8b4513", salmon = "fa8072", sandybrown = "f4a460", seagreen = "2e8b57",
	seashell = "fff5ee", sienna = "a0522d", silver = "c0c0c0", skyblue = "87ceeb", slateblue = "6a5acd",
	slategray = "708090", slategrey = "708090", snow = "fffafa", springgreen = "00ff7f", steelblue = "4682b4",
	tan = "d2b48c", teal = "008080", thistle = "d8bfd8", tomato = "ff6347", turquoise = "40e0d0",
	violet = "ee82ee", wheat = "f5deb3", white = "ffffff", whitesmoke = "f5f5f5", yellow = "ffff00",
	yellowgreen = "9acd32",
}

-- the page's gradient-text classes (style.css), drawn in one colour from each gradient
local CLASS_COLOR: { [string]: string } = {
	pr = "8bb4ce", sr = "78c0d4", hr = "77cde2", ps = "bd3c3e", spark = "ff9100", corr = "35f704", ef = "81b31f",
	pmr = "e75d7d", mr = "f35319", exf = "5dd182", pef = "ebae4d", link = "41f5f5",
}
local CLASS_SIZE: { [string]: number } = { pr = 18, sr = 18, hr = 18, ps = 18, spark = 18, corr = 18, ef = 18, pmr = 18, mr = 18, exf = 18, pef = 18, link = 20 }

local function clamp255(x: number): number
	return math.clamp(math.floor(x + 0.5), 0, 255)
end

-- CSS colour -> "rrggbb", alpha (0..1); nil when it is not a colour this understands
function Html.hex(css: string?): (string?, number)
	if css == nil then return nil, 1 end
	local s = string.lower((string.gsub(css, "^%s+", "")))
	s = string.gsub(s, "%s*!important%s*$", "")
	s = string.gsub(s, "%s+$", "")
	if NAMED[s] then return NAMED[s], 1 end
	if s == "transparent" then return "000000", 0 end
	local h = string.match(s, "^#(%x+)$")
	if h then
		if #h == 3 or #h == 4 then
			local a = if #h == 4 then tonumber(string.sub(h, 4, 4) .. string.sub(h, 4, 4), 16) :: number / 255 else 1
			return string.sub(h, 1, 1):rep(2) .. string.sub(h, 2, 2):rep(2) .. string.sub(h, 3, 3):rep(2), a
		elseif #h == 6 then
			return h, 1
		elseif #h == 8 then
			return string.sub(h, 1, 6), (tonumber(string.sub(h, 7, 8), 16) :: number) / 255
		end
		return nil, 1
	end
	local fn, args = string.match(s, "^(rgba?)%s*%((.-)%)")
	if fn then
		local parts = {}
		for p in string.gmatch(args :: string, "[^,%s/]+") do table.insert(parts, p) end
		if #parts < 3 then return nil, 1 end
		local rgb = {}
		for i = 1, 3 do
			local p = parts[i]
			local pct = string.match(p, "^([%d%.]+)%%$")
			rgb[i] = if pct then clamp255((tonumber(pct) or 0) * 2.55) else clamp255(tonumber(p) or 0)
		end
		local a = 1
		if parts[4] then
			local pct = string.match(parts[4], "^([%d%.]+)%%$")
			a = if pct then (tonumber(pct) or 100) / 100 else (tonumber(parts[4]) or 1)
		end
		return string.format("%02x%02x%02x", rgb[1], rgb[2], rgb[3]), math.clamp(a, 0, 1)
	end
	-- gradients and "2px solid red": the first colour in them
	local first = string.match(s, "#%x%x%x%x?%x?%x?%x?%x?") or string.match(s, "rgba?%b()")
	if first and first ~= s then return Html.hex(first) end
	for word in string.gmatch(s, "%a+") do
		if NAMED[word] then return NAMED[word], 1 end
	end
	return nil, 1
end

-- CSS colour -> Color3, transparency (0 = opaque); nil when not a colour
function Html.color(css: string?): (Color3?, number)
	local h, a = Html.hex(css)
	if h == nil then return nil, 0 end
	return Color3.fromHex(h), 1 - a
end

-- all the colours in a CSS value, in order (for gradients): { { colour, stop 0..1 or nil } }
function Html.gradient(css: string): { { c: Color3, stop: number? } }
	local out = {}
	local body = string.match(css, "gradient%s*(%b())")
	if not body then return out end
	body = string.sub(body, 2, -2)
	-- split on commas outside parentheses
	local parts, depth, cur = {}, 0, {}
	for ch in string.gmatch(body, ".") do
		if ch == "(" then depth += 1 elseif ch == ")" then depth -= 1 end
		if ch == "," and depth == 0 then table.insert(parts, table.concat(cur)); cur = {} else table.insert(cur, ch) end
	end
	table.insert(parts, table.concat(cur))
	for _, p in parts do
		local c = Html.color(p)
		if c then
			local pct = string.match(p, "([%-%d%.]+)%%%s*$")
			local px = string.match(p, "([%-%d%.e%+]+)px%s*$")
			table.insert(out, { c = c, stop = if pct then (tonumber(pct) or 0) / 100 else nil, px = if px then tonumber(px) else nil })
		end
	end
	return out
end

-- CSS length -> pixels ("12px", "1.5em", "50%" of base, plain numbers); nil otherwise
function Html.px(css: string?, base: number?): number?
	if css == nil then return nil end
	local s = string.lower(css)
	local n, unit = string.match(s, "^%s*([%-%d%.e%+]+)%s*([%a%%]*)")
	local v = tonumber(n)
	if v == nil then return nil end
	if unit == "" or unit == "px" then return v end
	if unit == "em" or unit == "rem" then return v * (base or 16) end
	if unit == "%" then return if base then v * base / 100 else nil end
	if unit == "pt" then return v * 4 / 3 end
	if unit == "vw" then return v * 12.8 end
	if unit == "vh" then return v * 7.2 end
	return nil
end

-- "a: b; c: d" -> { a = "b", c = "d" }
function Html.style(css: string?): { [string]: string }
	local out = {}
	if not css then return out end
	for decl in string.gmatch(css, "[^;]+") do
		local k, v = string.match(decl, "^%s*([%w%-]+)%s*:%s*(.-)%s*$")
		if k and v and v ~= "" then out[string.lower(k)] = v end
	end
	return out
end

-- -------------------------------------------------------------------------------------------------------- entities
local ENT: { [string]: string } = {
	nbsp = " ", amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", times = "×", divide = "÷", rarr = "→",
	larr = "←", uarr = "↑", darr = "↓", harr = "↔", middot = "·", bull = "•", hellip = "…", mdash = "—", ndash = "–",
	deg = "°", plusmn = "±", infin = "∞", copy = "©", reg = "®", trade = "™", laquo = "«", raquo = "»", sup2 = "²",
	sup3 = "³", frac12 = "½", frac14 = "¼", frac34 = "¾", le = "≤", ge = "≥", ne = "≠", asymp = "≈", micro = "µ",
	para = "¶", sect = "§", euro = "€", pound = "£", yen = "¥", cent = "¢", star = "☆",
}
local function decode(s: string): string
	return (string.gsub(s, "&(#?[xX]?%w+);", function(e: string): string
		local whole = "&" .. e .. ";"   -- an unknown entity stays as it was written
		local hex = string.match(e, "^#[xX](%x+)$")
		if hex then local n = tonumber(hex, 16); return if n and n < 0x110000 then utf8.char(n) else whole end
		local dec = string.match(e, "^#(%d+)$")
		if dec then local n = tonumber(dec); return if n and n < 0x110000 then utf8.char(n) else whole end
		return ENT[e] or whole
	end))
end
Html.decode = decode

local function esc(s: string): string
	return (string.gsub(s, "[&<>\"']", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }))
end
Html.escape = esc

-- ------------------------------------------------------------------------------------------------------- converter
local BLOCK = { div = true, p = true, table = true, tr = true, ul = true, ol = true, li = true, center = true, h1 = false }
local HEAD_EM = { h1 = 2, h2 = 1.5, h3 = 1.17, h4 = 1, h5 = 0.83, h6 = 0.67 }
local VOID = { br = true, hr = true, img = true, input = true, meta = true, link = true, wbr = true, col = true }

type Frame = { tag: string, close: string, size: number, block: boolean }

local function attrs(s: string): { [string]: string }
	local out: { [string]: string } = {}
	for k, _, v in string.gmatch(s, "([%w%-:]+)%s*=%s*([\"'])(.-)%2") do out[string.lower(k)] = v :: string end
	for k, v in string.gmatch(s, "([%w%-:]+)%s*=%s*([^%s\"'>]+)") do
		if out[string.lower(k)] == nil then out[string.lower(k)] = v :: string end
	end
	return out
end

local HR_LINE = string.rep("─", 18)

--[[
	Html.rich(html, base, preLine) -> RichText
	  base      the text size the HTML's plain text is drawn at (the page's px); sizes in em/% scale from it
	  preLine   keep newlines (TMT's buyable/clickable displays use white-space: pre-line); spaces still collapse
]]
local cache: { [string]: string } = {}
local cacheN = 0
function Html.rich(html: string?, base: number?, preLine: boolean?): string
	if html == nil or html == "" then return "" end
	local b = base or 14
	local key = html .. "\0" .. b .. (if preLine then "p" else "")
	local hit = cache[key]
	if hit then return hit end

	local out: { string } = {}
	local stack: { Frame } = {}
	local size = b
	local atLineStart = true
	local pendingSpace = false

	local function emit(s: string)
		table.insert(out, s)
	end
	local function newline()
		emit("\n")
		atLineStart = true
		pendingSpace = false
	end
	local function text(t: string)
		t = decode(t)
		if preLine then
			t = string.gsub(t, "\r\n?", "\n")
			local first = true
			for line in string.gmatch(t .. "\n", "(.-)\n") do
				if not first then newline() end
				first = false
				local l = string.gsub(line, "[ \t\f\v]+", " ")
				if l ~= "" then
					if atLineStart then l = string.gsub(l, "^ ", "") end
					if l ~= "" then emit(esc(l)); atLineStart = false end
				end
			end
			return
		end
		t = string.gsub(t, "%s+", " ")
		if t == "" then return end
		if string.sub(t, 1, 1) == " " then
			if not atLineStart then pendingSpace = true end
			t = string.sub(t, 2)
		end
		if t == "" then return end
		local trailing = string.sub(t, -1) == " "
		if trailing then t = string.sub(t, 1, -2) end
		if pendingSpace then emit(" ") end
		emit(esc(t))
		atLineStart = false
		pendingSpace = trailing
	end
	local function open(tag: string, a: { [string]: string })
		local st = Html.style(a.style)
		local opens, closes = {}, {}
		local nsize = size
		local isBlock = BLOCK[tag] == true
		if HEAD_EM[tag] then
			nsize = size * HEAD_EM[tag]
			table.insert(opens, "<b>"); table.insert(closes, 1, "</b>")
		elseif tag == "b" or tag == "strong" then
			table.insert(opens, "<b>"); table.insert(closes, 1, "</b>")
		elseif tag == "i" or tag == "em" then
			table.insert(opens, "<i>"); table.insert(closes, 1, "</i>")
		elseif tag == "u" then
			table.insert(opens, "<u>"); table.insert(closes, 1, "</u>")
		elseif tag == "s" or tag == "strike" or tag == "del" then
			table.insert(opens, "<s>"); table.insert(closes, 1, "</s>")
		elseif tag == "sup" or tag == "sub" or tag == "small" then
			nsize = size * 0.8
		elseif tag == "big" then
			nsize = size * 1.2
		end
		if st.display == "block" or st.display == "flex" or string.find(st.display or "", "^flex") then isBlock = true end
		local cls = a.class
		local color: string? = nil
		if cls then
			for c in string.gmatch(cls, "%S+") do
				if CLASS_COLOR[c] then color = CLASS_COLOR[c] end
				if CLASS_SIZE[c] then nsize = CLASS_SIZE[c] * b / 14 end
			end
		end
		if a.color and tag ~= "hr" then color = (Html.hex(a.color)) or color end
		local transp = 0
		if st.color then
			local h, al = Html.hex(st.color)
			if h then color = h; transp = 1 - al end
		end
		if st["font-size"] then
			local px = Html.px(st["font-size"], size)
			if px then nsize = px * b / 14 end
		end
		if st["font-weight"] == "bold" or tonumber(st["font-weight"] or "") and (tonumber(st["font-weight"] or "") :: number) >= 600 then
			table.insert(opens, "<b>"); table.insert(closes, 1, "</b>")
		end
		if st["font-style"] == "italic" then
			table.insert(opens, "<i>"); table.insert(closes, 1, "</i>")
		end
		if st["text-decoration"] and string.find(st["text-decoration"], "underline") then
			table.insert(opens, "<u>"); table.insert(closes, 1, "</u>")
		end
		if st["text-decoration"] and string.find(st["text-decoration"], "line%-through") then
			table.insert(opens, "<s>"); table.insert(closes, 1, "</s>")
		end
		-- text-shadow glow -> a soft stroke in the shadow's colour
		if st["text-shadow"] then
			local sh = Html.hex(st["text-shadow"])
			if sh then
				table.insert(opens, string.format('<stroke color="#%s" thickness="1" transparency="0.55">', sh))
				table.insert(closes, 1, "</stroke>")
			end
		end
		nsize = math.clamp(nsize, 6, 100)
		local fontAttr = {}
		if color then table.insert(fontAttr, string.format('color="#%s"', color)) end
		if transp > 0 then table.insert(fontAttr, string.format('transparency="%.2f"', transp)) end
		if math.abs(nsize - size) > 0.01 then table.insert(fontAttr, string.format('size="%d"', math.floor(nsize + 0.5))) end
		if #fontAttr > 0 then
			table.insert(opens, 1, "<font " .. table.concat(fontAttr, " ") .. ">")
			table.insert(closes, "</font>")
		end
		if isBlock and not atLineStart then newline() end
		if pendingSpace and #opens > 0 then emit(" "); pendingSpace = false end
		for _, o in opens do emit(o) end
		table.insert(stack, { tag = tag, close = table.concat(closes), size = size, block = isBlock })
		size = nsize
	end
	local function close(tag: string)
		-- close up to the matching tag (HTML error recovery); a stray closing tag is ignored
		local at = nil
		for i = #stack, 1, -1 do
			if stack[i].tag == tag then at = i; break end
		end
		if at == nil then return end
		for i = #stack, at, -1 do
			local f = table.remove(stack) :: Frame
			emit(f.close)
			size = f.size
			if f.block and not atLineStart then newline() end
		end
	end

	local pos, n = 1, #html
	while pos <= n do
		local lt = string.find(html, "<", pos, true)
		if lt == nil then
			text(string.sub(html, pos))
			break
		end
		if lt > pos then text(string.sub(html, pos, lt - 1)) end
		local gt = string.find(html, ">", lt + 1, true)
		if gt == nil then
			text(string.sub(html, lt))
			break
		end
		local inner = string.sub(html, lt + 1, gt - 1)
		pos = gt + 1
		local closing, tag, rest = string.match(inner, "^%s*(/?)%s*([%w]+)(.*)$")
		if tag == nil then
			if string.sub(inner, 1, 3) ~= "!--" then text("<" .. inner .. ">") end
			if string.sub(inner, 1, 3) == "!--" then
				local e = string.find(html, "-->", lt, true)
				if e then pos = e + 3 end
			end
		else
			tag = string.lower(tag)
			if closing == "/" then
				if not VOID[tag] then close(tag) end
			elseif tag == "br" then
				newline()
			elseif tag == "hr" then
				if not atLineStart then newline() end
				local a = attrs(rest or "")
				local h = Html.hex(a.color) or "4f4f4f"
				emit(string.format('<font color="#%s">%s</font>', h, HR_LINE))
				newline()
			elseif tag == "img" or tag == "input" or tag == "svg" then
				-- nothing to draw here (svg blocks are split out by Html.split)
			elseif tag == "style" or tag == "script" then
				local e = string.find(string.lower(html), "</" .. tag, pos, true)
				pos = if e then (string.find(html, ">", e, true) or n) + 1 else n + 1
			else
				open(tag, attrs(rest or ""))
				if string.sub(rest or "", -1) == "/" then close(tag) end
			end
		end
	end
	for i = #stack, 1, -1 do emit(stack[i].close) end
	-- trailing newlines only add blank space under a label
	local s = table.concat(out)
	s = string.gsub(s, "\n+$", "")
	if cacheN > 2000 then table.clear(cache); cacheN = 0 end
	cache[key] = s
	cacheN += 1
	return s
end

-- text without any markup (tooltips on small screens, logs)
function Html.plain(html: string?): string
	if html == nil then return "" end
	local s = string.gsub(html, "<[bB][rR]%s*/?>", "\n")
	s = string.gsub(s, "<[^>]*>", "")
	return decode(s)
end

-- ----------------------------------------------------------------------------------------------------------- <svg>
export type SvgText = { x: number, y: number, text: string, color: string?, size: number }
export type Svg = { w: number, h: number, bg: string?, texts: { SvgText } }

local function parseSvg(open: string, body: string): Svg
	local a = attrs(open)
	local st = Html.style(a.style)
	local bg = if st.background then string.match(st.background, "url%(%s*[\"']?(.-)[\"']?%s*%)") else nil
	local svg: Svg = { w = tonumber(a.width) or 300, h = tonumber(a.height) or 150, bg = bg :: string?, texts = {} }
	for tattrs, content in string.gmatch(body, "<text([^>]*)>(.-)</text>") do
		local ta = attrs(tattrs)
		table.insert(svg.texts, {
			x = tonumber(ta.x) or 0, y = tonumber(ta.y) or 0, text = decode(content :: string),
			color = Html.hex(ta.fill), size = Html.px(ta["font-size"], 16) or 16,
		})
	end
	return svg
end

-- html -> { string | Svg }: the HTML around each <svg> block, and the blocks parsed
function Html.split(html: string): { any }
	local parts: { any } = {}
	local pos = 1
	while true do
		local a, b, openAttrs = string.find(html, "<svg([^>]*)>", pos)
		if a == nil then break end
		local e = b :: number
		local c, d = string.find(html, "</svg>", e + 1, true)
		table.insert(parts, string.sub(html, pos, a - 1))
		table.insert(parts, parseSvg(openAttrs :: string, string.sub(html, e + 1, (c or #html + 1) - 1)) :: any)
		pos = if d then d + 1 else #html + 1
	end
	table.insert(parts, string.sub(html, pos))
	return parts
end

return Html
