--!nonstrict
-- LayoutPatches: small, explicit edits to generated Figma layouts for Birb features the frames do not have yet
-- (QA round 1, section B). Each patch gets a deep copy of the layout and returns it; WindowManager applies it once.
--   Fishing_Collection  Birb's filter bar: RARITIES / TYPES / LOCATIONS / BUFFS dropdowns on one row, then Search,
--                       the count, SAFE SELL and RESET on a second row; the grid starts under them
--   Aquarium_Biomes     TYPES + STATUS dropdowns beside DONATE ALL (Birb win_aquarium.jpg)
--   Parrot_Upgrade      the 7-step SPEND row is quieter: smaller steel keys
local TextService = game:GetService("TextService")

local Patches = {}

local function find(n, name)
	if n.n == name then return n end
	for _, c in n.k or {} do
		local r = find(c, name)
		if r then return r end
	end
	return nil
end
local function parentOf(root, node)
	for _, c in root.k or {} do
		if c == node then return root end
		local r = parentOf(c, node)
		if r then return r end
	end
	return nil
end
local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
end
local function textW(s, size)
	local ok, v = pcall(function() return TextService:GetTextSize(s, math.floor(size * 0.96 + 0.5), Enum.Font.FredokaOne, Vector2.new(10000, 1000)).X end)
	return if ok then v else #s * size * 0.6
end
-- a dropdown plate (a Figma filter plate copied): label + down glyph at the right
local function plate(template, name, x, y, w, label)
	local p = deep(template)
	p.n = name; p.x = x; p.y = y; p.w = w
	for _, c in p.k do
		if c.t == "T" then c.tx = label; c.n = label; c.w = math.min(w - 44, math.ceil(textW(label, c.fs)) + 4)
		elseif c.t == "G" then c.x = w - 30 end
	end
	return p
end
local function scaleTree(n, k)
	n.w *= k; n.h *= k
	for _, c in n.k or {} do
		c.x *= k; c.y *= k
		if c.fs then c.fs *= k end
		scaleTree(c, k)
	end
end

Patches.Fishing_Collection = function(L)
	local root = L.root
	local rar, typ = find(root, "filter/rarity"), find(root, "filter/type")
	if not (rar and typ) then return L end
	local Y1, Y2, H = 272, 324, 44
	local x0, x1 = 16, 786
	local w4 = (x1 - x0 - 3 * 8) / 4
	local template = deep(typ)
	local new = {
		plate(template, "filter/rarity", x0, Y1, w4, "RARITIES"),
		plate(template, "filter/type", x0 + (w4 + 8), Y1, w4, "TYPES"),
		plate(template, "filter/location", x0 + 2 * (w4 + 8), Y1, w4, "LOCATIONS"),
		plate(template, "filter/buffs", x0 + 3 * (w4 + 8), Y1, w4, "BUFFS"),
	}
	-- search: a plate with a muted placeholder (the binder puts a TextBox over it)
	local search = plate(template, "filter/search", x0, Y2, 262, "Search...")
	local keep = {}
	for _, c in search.k do if c.t == "T" then table.insert(keep, c) end end
	search.k = keep
	table.insert(new, search)
	local out = {}
	for _, c in root.k do
		if c ~= rar and c ~= typ then table.insert(out, c) end
		if c == typ then for _, n in new do table.insert(out, n) end end
	end
	root.k = out
	-- count + label, SAFE SELL and a steel RESET key on the second row
	for _, c in root.k do
		if c.t == "T" and c.y == 284 then c.x = 292; c.y = Y2 + 12 end
		if c.t == "T" and c.y == 285 then c.x = 339; c.y = Y2 + 13 end
	end
	local safe = find(root, "btn/safe sell")
	if safe then
		safe.x = 486; safe.y = Y2
		local reset = deep(safe)
		reset.n = "btn/reset"; reset.x = 672; reset.w = 114
		for _, c in reset.k do
			if c.n == "ink body" then c.w = 114 elseif c.n == "lip" or c.n == "face" then c.w = 108 end
			if c.n == "lip" then c.f = find(safe, "lip").f end
		end
		local face = find(reset, "face")
		local fk = {}
		for _, c in face.k do
			if c.n == "gloss cap" then c.w = 102; table.insert(fk, c)
			elseif c.t == "T" then c.tx = "RESET"; c.n = "RESET"; c.w = math.ceil(textW("RESET", c.fs)) + 4; c.x = (108 - c.w) / 2; table.insert(fk, c) end
		end
		face.k = fk
		table.insert(root.k, reset)
	end
	-- the grid starts under the second row
	local grid = find(root, "fish grid")
	if grid then
		local dy = (Y2 + H + 12) - grid.y
		grid.y += dy; grid.h -= dy
	end
	return L
end

Patches.Aquarium_Biomes = function(L)
	local tb = find(L.root, "toolbar")
	local st = tb and find(tb, "dropdown/status")
	local don = tb and find(tb, "btn/donate all")
	if not (st and don) then return L end
	-- TYPES | STATUS | DONATE ALL after the "42/55 housed" note
	local typ = plate(st, "dropdown/types", 166, st.y, 92, "TYPES")
	local stat = plate(st, "dropdown/status", 264, st.y, 98, "STATUS")
	for i, c in tb.k do if c == st then tb.k[i] = stat end end
	table.insert(tb.k, typ)
	don.x = 368; don.w = 126
	for _, c in don.k do
		if c.n == "ink body" then c.w = 126 elseif c.n == "lip" or c.n == "face" then c.w = 120 end
	end
	local face = find(don, "face")
	for _, c in face.k do
		if c.n == "gloss cap" then c.w = 114
		elseif c.t == "T" then c.w = 112; c.x = 4; c.ax = "C" end
	end
	return L
end

Patches.Parrot_Upgrade = function(L)
	-- quieter SPEND amounts: keys at 80 %, centred in their row, the selected ring follows
	local row = find(L.root, "spend amount")
	if not row then return L end
	local k = 0.8
	local x = 96
	local ringFor
	for _, c in row.k do
		if c.n and string.sub(c.n, 1, 7) == "amount/" then
			scaleTree(c, k)
			if c.key then c.key = math.max(2, math.floor(c.key * k + 0.5)) end
			c.x = x; c.y = (row.h - c.h) / 2
			x += c.w + 6
			if string.find(c.n, "selected") then ringFor = c end
		end
	end
	local ring = find(row, "selected ring")
	if ring and ringFor then ring.x = ringFor.x - 3; ring.y = ringFor.y - 3; ring.w = ringFor.w + 6; ring.h = ringFor.h + 6 end
	return L
end

-- footer strips: one height (40) in every window (QA: some were 28 / 36 px on screen)
local function footer40(L, y)
	local f = find(L.root, "footer")
	if not f or f.h == 40 then return L end
	local dy = (40 - f.h) / 2
	f.y = y or f.y; f.h = 40
	for _, c in f.k or {} do c.y += dy end
	return L
end
local base = Patches.Fishing_Collection
Patches.Fishing_Collection = function(L) return footer40(base(L), 808) end
Patches.Fishing_Equipment = function(L) return footer40(L, 808) end
Patches.Fishing_Fishdex = function(L) return footer40(L, 808) end
Patches.Crow = function(L) return footer40(L, 768) end

Patches.find, Patches.parentOf = find, parentOf
return Patches
