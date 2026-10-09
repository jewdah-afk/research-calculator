--!nonstrict
-- FKit: Luau port of docs/figma/kit.js (the recipes every Figma window was built from), for the few screens that
-- have no squared Figma frame yet (Profile, Settings, Teleport, Offline, Leaderboards) and for runtime pieces
-- (drawer pull tab, list rows cloned from data). Same numbers as the kit, so code-built pieces match by construction.
--   KEY / BTN  game Kit.button recipe: ink body r4 -> lip (face x0.58, shifted down D) -> face r2.5 + stripes 12 % +
--              gloss cap (.45 -> .04 on the upper 42 %); press = whole key drops by D, lip hidden
--   STEEL      dark steel plate (ink 2, lattice 6 %, 1.5 px top highlight, soft shadow)
--   WELL       recessed value field (ink 1.5, inner shadow)
--   CHIP       steel mini cost chip · BAR progress bar · T title text · BODY normal text (1.2 outline + 1 px drop)
--   WINDOW     square-top window: themed header (clone of the Figma header), 44 px close key at (W-54, 10), 4 px outline
local Render = require(script.Parent.Render)
local IconAlias = require(script.Parent.IconAlias)
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))

local FKit = {}
local C = Render.C

FKit.PAL = {
	green = { "9dff8a", "3fcf4a", "1e8a2a" }, blue = { "8fd8ff", "3a9cf0", "1f5fb4" }, gold = { "ffe58a", "f2b331", "b86e0c" },
	red = { "ff9a8a", "ec4a3c", "a8201a" }, violet = { "e3c2ff", "a466f5", "6a2fc4" }, teal = { "8af0dc", "2fb39c", "17705f" },
	cyan = { "9cecff", "2fb8e8", "13739e" }, pink = { "ffc2e1", "e8649f", "9e2a62" }, amber = { "ffd36b", "e89a1e", "9c5a08" },
	brown = { "e0b07a", "a8683a", "6a3a1a" }, olive = { "d8ef7a", "86b832", "4c7418" }, stone = { "c3cad6", "808a9c", "4a5262" },
	grey = { "7a8496", "4f5868", "343b47" }, steel = { "566174", "394252", "262c37" },
}
FKit.THEME = {
	seeds = { "3f9a2a", "7fe05a", "c8ff9a" }, mine = { "2b3a8f", "4fd2ff", "ffc22e" }, fishing = { "13739e", "2fb8e8", "9cecff" },
	aquarium = { "17507a", "2fa8c8", "8af0dc" }, market = { "9c5a08", "e89a1e", "ffe08a" }, gold = { "b86e0c", "f2b331", "ffe58a" },
	archivist = { "4a1f8a", "a466f5", "ffc2e1" }, desert = { "a8640a", "e8a42a", "ffe08a" }, crow = { "262c37", "566174", "c3cad6" },
	nest = { "6a3a1a", "a8683a", "e0b07a" }, expedition = { "a8201a", "ec4a3c", "ffb08a" }, echo = { "9e2a62", "e8649f", "ffc2e1" },
}

local TextService = game:GetService("TextService")
-- measured width of Fredoka One text at a Figma size (the renderer draws fs x 0.96)
function FKit.textW(s: string, size: number): number
	local ok, v = pcall(function() return TextService:GetTextSize(s, math.floor(size * 0.96 + 0.5), Enum.Font.FredokaOne, Vector2.new(10000, 10000)).X end)
	return if ok then v else #s * size * 0.6
end
local textW = FKit.textW

local function shade(hex, k)
	local c = C(hex)
	return string.format("%02x%02x%02x", math.floor(c.R * 255 * k), math.floor(c.G * 255 * k), math.floor(c.B * 255 * k))
end
local function vgrad(cols, k, a)
	local st = {}
	for i, h in cols do st[i] = { (i - 1) / (#cols - 1), if k then shade(h, k) else h, a or 1 } end
	return { "g", 90, st }
end
FKit.vgrad = vgrad

-- tiny layout builder: everything below goes through Render so the look is identical to the generated windows
local function node(t, name, x, y, w, h, extra)
	local n = { t = t, n = name, x = x, y = y, w = w, h = h }
	if extra then for k, v in extra do n[k] = v end end
	return n
end
FKit.node = node

-- a mini layout: P (style table) + helpers to intern styles
function FKit.layout()
	local L = { P = {}, map = {} }
	function L.style(v)
		local key = game:GetService("HttpService"):JSONEncode(v)
		local i = L.map[key]
		if not i then table.insert(L.P, v); i = #L.P; L.map[key] = i end
		return i
	end
	return L
end

-- ---------------------------------------------------------------- node recipes (return layout nodes)
function FKit.KEYn(L, name, x, y, w, h, cols, o)
	o = o or {}
	local D = o.d or 6
	local fh = h - 6 - D
	local face = node("F", "face", 3, 3, w - 6, fh, { r = 2.5, c = true, f = L.style({ vgrad(cols), { "t", "stripes", 32, 0.12 } }), k = {
		node("F", "gloss cap", 3, 2, w - 12, math.floor(fh * 0.42), { r = 2, f = L.style({ { "g", 90, { { 0, "ffffff", o.gloss or 0.45 }, { 1, "ffffff", 0.04 } } } }) }),
	} })
	local key = node("F", name, x, y, w, h, { key = D, k = {
		node("F", "ink body", 0, 0, w, h, { r = o.r or 4, f = L.style({ { "s", "0b0c10", 1 } }) }),
		node("F", "lip", 3, 3 + D, w - 6, fh, { r = 2.5, f = L.style({ vgrad(cols, 0.58) }) }),
		face,
	} })
	if o.shadow ~= false then key.e = L.style({ { "d", 0, 4, 8, "000000", 0.35, 0 } }) end
	return key, face
end
function FKit.Tn(L, s, size, o)
	o = o or {}
	local tw = o.w or math.ceil(textW(s, size)) + 4
	return node("T", o.name or s, o.x or 0, o.y or 0, tw, o.h or math.ceil(size * 1.22), {
		tx = s, fs = size, ax = o.ax or "L", ay = "C", tf = L.style({ { "s", o.col or "ffffff", 1 } }),
		sw = o.sw or math.max(1.3, math.floor(size * 0.1 * 10 + 0.5) / 10), sh = { 0, o.sh or math.max(1, math.floor(size * 0.08 + 0.5)) },
	})
end
function FKit.BODYn(L, s, size, o)
	o = o or {}
	o.col = o.col or "c9d2e3"; o.sw = 1.2; o.sh = 1
	return FKit.Tn(L, s, size, o)
end
function FKit.ICOn(name, s, x, y, L)
	return node("I", "ico/" .. name, x, y, s, s, { icon = name, e = L and L.style({ { "d", 0, 1.5, 0, "0b0c10", 0.5, 0 } }) or nil })
end
function FKit.BTNn(L, name, x, y, w, h, cols, label, o)
	o = o or {}
	local key, face = FKit.KEYn(L, name, x, y, w, h, cols, o)
	local D = o.d or 6
	local fh = h - 6 - D
	local size = o.size or math.floor(fh * 0.5 + 0.5)
	local iw = if o.icon then math.floor(size * 1.35 + 0.5) else 0
	local tw = if label then math.ceil(textW(label, size)) else 0
	local gap = if o.icon and label then 8 else 0
	local x0 = (face.w - (iw + gap + tw)) / 2
	if o.icon then table.insert(face.k, FKit.ICOn(o.icon, iw, x0, (fh - iw) / 2, L)); x0 += iw + gap end
	if label then
		local t = FKit.Tn(L, label, size, { x = x0, w = tw + 6, col = o.textCol })
		t.y = math.floor((fh - t.h) / 2 + 0.5)
		table.insert(face.k, t)
	end
	if o.glyph then
		local gs = o.glyphSize or math.floor(fh * 0.6)
		table.insert(face.k, node("G", "glyph/" .. o.glyph, (face.w - gs) / 2, (fh - gs) / 2, gs, gs, { kind = o.glyph, col = "ffffff", ink = 7.5, lw = 3.6 }))
	end
	return key
end
function FKit.STEELn(L, name, x, y, w, h, o)
	o = o or {}
	return node("F", name, x, y, w, h, { r = o.r or 4, c = o.clip, f = L.style({ vgrad(o.cols or { "303a49", "1d232d" }), { "t", "lattice", 30.1, 0.06 } }),
		s = L.style({ "0b0c10", 1, o.sw or 2, "I" }), e = L.style({ { "d", 0, 4, 10, "000000", 0.38, 0 } }), k = {
			node("F", "top highlight", 4, o.sw or 2, w - 8, 1.5, { r = 1, f = L.style({ { "s", "e5d1ff", 0.2 } }) }),
		} })
end
function FKit.WELLn(L, name, x, y, w, h, o)
	o = o or {}
	return node("F", name, x, y, w, h, { r = o.r or 3, c = o.clip, f = L.style({ { "s", o.col or "0a0e14", o.op or 0.8 } }),
		s = L.style({ "0b0c10", 1, 1.5, "I" }), e = L.style({ { "i", 0, 2, 3, "000000", 0.6, 0 } }), k = {} })
end
function FKit.BARn(L, name, x, y, w, h, pct, cols, label)
	local b = node("F", name, x, y, w, h, { r = 3, c = true, f = L.style({ { "s", "0f1115", 1 } }), s = L.style({ "0b0c10", 1, 1.5, "I" }),
		e = L.style({ { "i", 0, 2, 0, "000000", 0.6, 0 } }), k = {
			node("F", "fill", 0, 0, math.max(0, math.floor(w * pct + 0.5)), h, { f = L.style({ vgrad(cols), { "g", 90, { { 0, "ffffff", 0.35 }, { 0.5, "ffffff", 0 }, { 1, "ffffff", 0 } } } }) }),
		} })
	if label then
		local t = FKit.Tn(L, label, math.min(15, h - 7), { w = w, ax = "C", sw = 1.3, sh = 1 })
		t.y = math.floor((h - t.h) / 2 + 0.5)
		table.insert(b.k, t)
	end
	return b
end
function FKit.CHIPn(L, name, x, y, icon, value, o)
	o = o or {}
	local size = o.size or 13
	local H, is, padL, gap, padR = size + 9, size + 3, 6, 5, 8
	local tw = math.ceil(textW(value, size))
	local W = math.ceil((if icon then padL + is + gap else 8) + tw + padR)
	local c = node("F", name, x, y, W, H, { r = 3, f = L.style({ { "g", 90, { { 0, "333c4a", 1 }, { 1, "171c24", 1 } } }, { "t", "lattice", 30.1, 0.05 } }),
		s = L.style({ "0b0c10", 1, 2, "I" }), e = L.style({ { "d", 0, 2, 0, "0b0c10", 1, 0 }, { "d", 0, 4, 6, "000000", 0.35, 0 } }), k = {
			node("F", "top highlight", 4, 2, W - 8, 1.5, { r = 1, f = L.style({ { "s", "ffffff", 0.14 } }) }),
		} })
	local xx = 8
	if icon then table.insert(c.k, FKit.ICOn(icon, is, padL, math.floor((H - is) / 2), L)); xx = padL + is + gap end
	local t = FKit.Tn(L, value, size, { x = xx, w = tw + 4, col = o.col, sw = 1.2, sh = 1 })
	t.y = math.floor((H - t.h) / 2)
	table.insert(c.k, t)
	return c
end

-- ---------------------------------------------------------------- square-top window
-- The header is the Figma header itself (taken from the generated Mine window), re-themed and re-titled.
local MINE = require(script.Parent.Layouts.Mine_Shop)
local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
end
function FKit.WINDOWn(L, name, W, H, theme, title)
	local th = FKit.THEME[theme] or FKit.THEME.mine
	-- copy the window shell + header from the Mine layout, remapping its style ids into L
	local src = MINE.root
	local remap = {}
	local function re(i)
		if not i then return nil end
		if not remap[i] then remap[i] = L.style(deep(MINE.P[i])) end
		return remap[i]
	end
	local function copy(n)
		local o = {}
		for k, v in n do
			if k == "f" or k == "s" or k == "e" or k == "tf" then o[k] = re(v)
			elseif k == "k" then o.k = {}; for i, c in v do o.k[i] = copy(c) end
			else o[k] = deep(v) end
		end
		return o
	end
	local win = node("F", name, 0, 0, W, H, { f = re(src.f), s = re(src.s), e = re(src.e), k = {} })
	local head = copy(src.k[1])
	head.w = W
	head.f = L.style({ { "g", 20, { { 0, th[1], 1 }, { 0.11, th[1], 1 }, { 0.5, th[2], 1 }, { 0.89, th[3], 1 }, { 1, th[3], 1 } } },
		{ "g", 90, { { 0, "ffffff", 0.38 }, { 0.45, "ffffff", 0 }, { 0.6, "000000", 0 }, { 1, "000000", 0.42 } } }, { "t", "halftone", 38.4, 0.08 }, { "t", "lattice", 43, 0.35 } })
	for _, ch in head.k do
		if ch.n == "glow" then ch.w = W; ch.f = L.style({ { "g", 90, { { 0, th[2], 0 }, { 1, th[2], 0.55 } } } })
		elseif ch.n == "depth band" then ch.w = W; ch.f = L.style({ { "g", 90, { { 0, shade(th[1], 0.45), 1 }, { 1, shade(th[1], 0.45), 1 } } } })
		elseif ch.n == "bevel" or ch.n == "ink" then ch.w = W
		elseif ch.n == "dome" then ch.w = W + 80; ch.x = -40
		elseif ch.n == "spec" then ch.x = W / 2 - 180
		elseif ch.n == "fx/sparkle" then ch.x += (W - 1100)
		elseif ch.n == "sweep" or ch.n == "sweep2" then ch.x += math.max(0, W / 2 - 550)
		elseif ch.t == "T" then
			ch.tx = title; ch.n = title
			ch.w = math.ceil(textW(title, ch.fs)) + 8
			ch.x = (W - ch.w) / 2; ch.ax = "C"
		end
	end
	table.insert(win.k, head)
	local close = FKit.KEYn(L, "btn/close", W - 54, 10, 44, 44, FKit.PAL.red, { d = 5 })
	table.insert(close.k[3].k, node("G", "glyph/x", 8, 5.5, 22, 22, { kind = "x", col = "ffffff", ink = 7.5, lw = 3.6 }))
	table.insert(win.k, close)
	return win
end
-- OUTLINE: call last (continuous 4 px ink outline over everything, header included)
function FKit.OUTLINEn(L, win)
	table.insert(win.k, node("F", "window outline", 0, 0, win.w, win.h, { s = L.style({ "0b0c10", 1, 4, "I" }) }))
end
-- segmented tab bar (tabs = { {label, icon, active, locked} })
function FKit.TABSn(L, x, y, w, tabs)
	local bar = node("F", "tabs (segmented)", x, y, w, 56, { r = 4, f = L.style({ { "s", "0d1219", 1 }, { "t", "lattice", 30.1, 0.06 } }),
		s = L.style({ "0b0c10", 1, 1.75, "I" }), e = L.style({ { "i", 0, 3, 4, "000000", 0.7, 0 } }), k = {} })
	local tw = (w - 12 - (#tabs - 1) * 2) / #tabs
	for i, t in tabs do
		local tx = 6 + (i - 1) * (tw + 2)
		if t.active then
			local k = FKit.BTNn(L, "tab/" .. t.label .. " (active)", tx, 5, tw, 46, t.cols or FKit.PAL.green, t.label, { d = 4, shadow = false, icon = t.icon, size = 19 })
			table.insert(bar.k, k)
		else
			local g = node("F", "tab/" .. t.label .. (if t.locked then " (locked)" else ""), tx, 5, tw, 46, { k = {} })
			local lw = math.ceil(textW(t.label, 18))
			local iw = if t.icon then 28 else 0
			local x0 = (tw - (iw + (if iw > 0 then 8 else 0) + lw)) / 2
			if t.icon then local ic = FKit.ICOn(t.icon, 28, x0, 9, L); ic.o = if t.locked then 0.45 else 0.8; table.insert(g.k, ic) end
			table.insert(g.k, FKit.Tn(L, t.label, 18, { x = x0 + iw + (if iw > 0 then 8 else 0), y = 11, w = lw + 6, col = "8d94a3", sw = 1.2, sh = 1 }))
			table.insert(bar.k, g)
		end
	end
	return bar
end

-- build a hand-made layout (root node + its style table) through the same renderer
function FKit.build(L, root, parent)
	return Render.build({ P = L.P, root = root }, parent, root)
end

FKit.icon = IconAlias.id
FKit.Icons = Icons
return FKit
