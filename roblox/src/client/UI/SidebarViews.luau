--!nonstrict
-- SidebarViews: the sidebar's NEST and MINE tabs (Birb shows those upgrades inside the sidebar, mine_tab_mine.jpg /
-- nest_tab_nest.jpg). Figma has no frame for them, so they are generated from the Figma SEEDS view (Shop_Seeds,
-- 260:4544): same header, tab bar and card, with the tab bar's active key moved to NEST / MINE, the card re-labelled
-- (live currency, per-second rate, two stats, a key that opens the full window) and the upgrade list filled with
-- the live twig / mine upgrades by the shop binder. Pure layout tables: Render builds them like any Figma frame.
local Layouts = script.Parent.Figma.Layouts
local TextService = game:GetService("TextService")

local SidebarViews = {}

local VIEWS = {
	Shop_Nest = { tab = "NEST", icon = "twig", cardIcon = "nest", title = "TWIGS", desc = "Peck trees in the Forest. Twigs build the Nest and its buildings.",
		key = "btn/open nest", keyText = "NEST", stats = { "TWIGS / SEC", "NEST TIER", "PECK RATE" },
		footer = "Twig upgrades stay through Molt and Evolve." },
	Shop_Mine = { tab = "MINE", icon = "pickaxe", cardIcon = "ore", title = "BRUTE ORE", desc = "The Crow mines Brute Ore in the Mine while you play.",
		key = "btn/open mine", keyText = "MINE", stats = { "ORE / SEC", "AREA", "CROW LV" },
		footer = "Mine upgrades reset on Evolve. Crow rebirbs stay." },
}
SidebarViews.VIEWS = VIEWS

local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
end
local function find(n, name)
	if n.n == name then return n end
	for _, c in n.k or {} do
		local r = find(c, name)
		if r then return r end
	end
	return nil
end
local function textW(s, size)
	local ok, v = pcall(function() return TextService:GetTextSize(s, math.floor(size * 0.96 + 0.5), Enum.Font.FredokaOne, Vector2.new(10000, 1000)).X end)
	return if ok then v else #s * size * 0.6
end
-- an icon + label pair centred in a box of width w
local function centre(icon, text, w, label, iconName)
	text.tx = label; text.n = label
	text.w = math.ceil(textW(label, text.fs)) + 4
	if icon then
		icon.icon = iconName; icon.n = "ico/" .. iconName
		local gw = icon.w + 5 + text.w - 4
		icon.x = (w - gw) / 2
		text.x = icon.x + icon.w + 5
	else
		text.x = (w - text.w) / 2
	end
end
local function kids(n, t)
	local icon, text
	for _, c in n.k or {} do
		if c.t == "I" and not icon then icon = c end
		if c.t == "T" and not text then text = c end
	end
	return icon, text
end

local cache = {}
function SidebarViews.layout(name)
	local v = VIEWS[name]
	if not v then return nil end
	if cache[name] then return cache[name] end
	local src = require(Layouts.Shop_Seeds)
	local L = { P = deep(src.P), root = deep(src.root), id = src.id .. "/" .. name, name = "Window / Shop · " .. v.tab }
	L.root.n = L.name
	-- tab bar: this view's tab becomes the active key, SEEDS a plain tab in the old slot
	local tabs = find(L.root, "drawer tabs")
	local active = find(tabs, "tab/SEEDS (active)")
	local plain = find(tabs, "tab/" .. v.tab)
	active.x, plain.x = plain.x, active.x
	active.n = "tab/" .. v.tab .. " (active)"
	local face = find(active, "face")
	local ai, at = kids(face)
	centre(ai, at, face.w, v.tab, v.icon)
	plain.n = "tab/SEEDS"
	local pi, pt = kids(plain)
	centre(pi, pt, plain.w, "SEEDS", "seed")
	-- the card: currency, description, a key to the full window, three stats
	local card = find(L.root, "seeds card")
	card.n = "sidebar card"
	for _, c in card.k do
		if c.n == "icon well" then
			local ic = c.k[1]; ic.icon = v.cardIcon; ic.n = "ico/" .. v.cardIcon
		elseif c.t == "T" and c.fs == 20 then c.tx = v.title; c.n = "title"; c.w = math.ceil(textW(v.title, 20)) + 6
		elseif c.t == "T" and c.fs == 36 then c.tx = "0"; c.n = "value"; c.w = 230
		elseif c.t == "T" and c.fs == 13 then c.tx = v.desc; c.n = "desc"
		elseif c.n == "btn/auto-buy (off)" then
			c.n = v.key
			local kf = find(c, "face")
			local keep = {}
			for _, kc in kf.k do
				if kc.t == "T" then
					kc.tx = v.keyText; kc.n = v.keyText; kc.w = math.ceil(textW(v.keyText, kc.fs)) + 4
					kc.x = (kf.w - 22 - 6 - kc.w) / 2
					table.insert(keep, kc)
				elseif kc.t ~= "G" then table.insert(keep, kc) end
			end
			-- an arrow out to the full window (glyph drawn, never typed)
			local tx
			for _, kc in keep do if kc.t == "T" then tx = kc end end
			table.insert(keep, { t = "G", n = "glyph/right", x = (tx and tx.x + tx.w + 4) or (kf.w - 30), y = (kf.h - 18) / 2, w = 18, h = 18, c = true,
				kind = "right", col = "ffffff", ink = 6.5, lw = 3 })
			kf.k = keep
		end
	end
	local si = 0
	for _, c in card.k do
		if c.n and string.sub(c.n, 1, 5) == "stat/" then
			si += 1
			c.n = "stat/" .. v.stats[si]
			for _, t in c.k do if t.fs == 12 then t.tx = v.stats[si]; t.n = v.stats[si] elseif t.t == "T" then t.n = "stat value"; t.tx = "-" end end
		end
	end
	for _, c in L.root.k do
		if c.t == "T" and string.find(c.tx or "", "^Evolving resets") then c.tx = v.footer; c.n = "footer" end
	end
	cache[name] = L
	return L
end

return SidebarViews
