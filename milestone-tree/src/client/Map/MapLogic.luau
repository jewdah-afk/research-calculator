--!strict
--[[
	MapLogic: the pure rules behind the map widgets (DESIGN.md 3.7-3.10), kept apart from instances so the unit tests
	run them under plain luau (port/tests/unit/map_nodes.luau).

	    MapLogic.state(ms, layer)       the node state: sealed | frontier | dormant | locked | available | glow | pulse
	    MapLogic.flags(ms, layer)       { selected, challenge, infected }
	    MapLogic.rank(ms, layer)        the draw / plate priority (selected > pulse > glow > challenge > available > ...)
	    MapLogic.plateName(node)        the whole-word plate name (DESIGN.md 3.9)
	    MapLogic.unit(resource)         the short unit of a resource name ("hyper-prestige points" -> "HP")
	    MapLogic.lod(z, mode, prev)     FULL | CHIP | NONE with the +-.02 hysteresis
	    MapLogic.edges(ms, realmEdges)  the drawn connections { from, to, p, lit, secondary, infected }
	    MapLogic.markers(...)           the edge-marker candidates, pulse first, at most 4
	    MapLogic.place(items, blocked)  the greedy plate placement (collision and occlusion)

	Nothing here touches Roblox services or requires a module.
]]

-- the parts of Types.MapState / MapNode / Rect this reads (structural: the real tables fit)
export type Rect = { x: number, y: number, w: number, h: number }
type Branch = { to: string, col: string, w: number? }
-- read as: MapNode { show, dor, col?, name?, ch?, br: { Branch }?, val: { lit, glow, pulse }? },
-- MapState { inside, open?, gate?, nodes: { [string]: MapNode }, ready, canBuy } (Types.MapState passes as is)
type MapNode = any
type MapState = any

local MapLogic = {}

MapLogic.ORDER = {
	"ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex",
}
-- the Prestige Multiverse cluster; everything else is the Normal Universe
MapLogic.MULTIVERSE = { pm = true, pep = true, cp = true, cm = true, ex = true } :: { [string]: boolean }

-- plate names: whole words, the emblem symbol names the family (DESIGN.md 3.9)
MapLogic.NAMES = {
	m = "MILESTONE", mm = "META", em = "EXTRA", p = "PRESTIGE", pe = "ENERGY", sp = "SUPER", pb = "BOOST", pp = "POWER",
	se = "SUPER ENERGY", hp = "HYPER", ep = "EXOTIC", hb = "HYPER BOOST", ap = "ATOMIC", mp = "MULTIVERSE", t = "TRANSCEND",
	pep = "PRESTIGED EXOTIC", cp = "CORRUPTED", cm = "CORRUPTED MILESTONE", ex = "EXPLORE", ach = "ACHIEVEMENTS",
} :: { [string]: string }

-- the fixed unit table keyed by the resource name (the view sends the game's own words)
MapLogic.UNITS = {
	["prestige points"] = "P",
	["super-prestige points"] = "SP",
	["hyper-prestige points"] = "HP",
	["exotic prestige"] = "EP",
	["exotic prestige points"] = "EP",
	["prestige power"] = "PP",
	["atomic-prestige points"] = "AP",
	["multiverse prestige points"] = "MP",
	["transcend points"] = "TP",
	["prestige energy"] = "PE",
	["super energy"] = "SE",
	["prestige boosts"] = "PB",
	["hyper boosts"] = "HB",
	["milestones"] = "milestones",
	["meta-milestones"] = "MM",
	["extra-milestones"] = "EM",
	["fixed corruptions"] = "fixed",
	["prestige essence"] = "essence",
	["prestiged-exotic prestige points"] = "PEP",
	["corrupted milestones"] = "CM",
	["exploration points"] = "XP",
} :: { [string]: string }

-- the malware colours of infected layers (m #9f2846, p #c25757, sp rgb(238,112,112)) and the infected link colour
local INFECTED = { ["#9f2846"] = true, ["#c25757"] = true, ["#ee7070"] = true, ["#c86a6a"] = true } :: { [string]: boolean }
local function normColor(css: string?): string
	if css == nil then return "" end
	local s = string.lower((string.gsub(css, "%s", "")))
	local r, g, b = string.match(s, "^rgba?%((%d+),(%d+),(%d+)")
	if r and g and b then
		return string.format("#%02x%02x%02x", tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
	end
	return s
end
MapLogic.normColor = normColor
function MapLogic.isInfected(css: string?): boolean
	return INFECTED[normColor(css)] == true
end

-- the Figma parents: an edge from -> to makes `from` a parent of `to` (Realm.edges; ids are game ids)
export type Edge = { from: string, to: string, p: { number } }
local parentsCache: { [any]: { [string]: { string } } } = setmetatable({}, { __mode = "k" }) :: any
function MapLogic.parents(edges: { Edge }): { [string]: { string } }
	local hit = parentsCache[edges]
	if hit then return hit end
	local out: { [string]: { string } } = {}
	for _, e in edges do
		local list = out[e.to]
		if list == nil then
			list = {}
			out[e.to] = list
		end
		table.insert(list, e.from)
	end
	parentsCache[edges] = out
	return out
end

local function shown(ms: MapState, l: string): boolean
	local n = ms.nodes[l]
	return n ~= nil and n.show
end
MapLogic.shown = shown

-- sealed | frontier | dormant | locked | available | glow | pulse
function MapLogic.state(ms: MapState, layer: string, edges: { Edge }?): string
	local n = ms.nodes[layer]
	if n == nil then return "sealed" end
	if not n.show then
		-- dormant: the layer lives in the other universe (the view's `dor` is also true for untouched layers whose
		-- `unlocked` defaults to true, so it counts only once the Multiverse is revealed or entered)
		if n.dor then
			local multi = MapLogic.MULTIVERSE[layer] == true
			local inside = ms.inside == true
			local revealed = inside or (ms.gate ~= nil and ms.gate.show == true)
			if revealed and multi ~= inside then return "dormant" end
		end
		if edges then
			local uni = MapLogic.MULTIVERSE[layer] == true
			for _, p in (MapLogic.parents(edges)[layer] or {}) :: { string } do
				if (MapLogic.MULTIVERSE[p] == true) == uni and shown(ms, p) then return "frontier" end
			end
		end
		return "sealed"
	end
	local v = n.val
	if v == nil then return "available" end
	if not v.lit then return "locked" end
	if v.pulse then return "pulse" end
	if v.glow then return "glow" end
	return "available"
end

export type Flags = { selected: boolean, challenge: boolean, infected: boolean }
function MapLogic.flags(ms: MapState, layer: string): Flags
	local n = ms.nodes[layer]
	local shownNode = n ~= nil and n.show
	return {
		selected = shownNode and ms.open == layer,
		challenge = shownNode and n ~= nil and n.ch ~= nil,
		infected = shownNode and n ~= nil and MapLogic.isInfected(n.col),
	}
end

-- higher draws on top and gets its plate first
local STATE_RANK = { pulse = 60, glow = 50, available = 30, locked = 20, dormant = 10, frontier = 5, sealed = 0 } :: { [string]: number }
function MapLogic.rank(ms: MapState, layer: string, edges: { Edge }?): number
	local st = MapLogic.state(ms, layer, edges)
	local f = MapLogic.flags(ms, layer)
	local r = STATE_RANK[st] or 0
	if f.selected then r = 100 end
	if f.challenge and r < 40 and st ~= "locked" then r = 40 end
	return r
end

-- a plate name with at most ~12 characters a line (one break at the space nearest the middle)
function MapLogic.wrapName(name: string): string
	if #name <= 12 or not string.find(name, " ", 1, true) then return name end
	local best, bestD = nil :: number?, math.huge
	local mid = #name / 2
	local i = 0
	while true do
		local j = string.find(name, " ", i + 1, true)
		if j == nil then break end
		local d = math.abs(j - mid)
		if d < bestD then best, bestD = j, d end
		i = j
	end
	if best == nil then return name end
	return string.sub(name, 1, best - 1) .. "\n" .. string.sub(name, best + 1)
end

function MapLogic.plateName(node: MapNode?, layer: string): string
	if layer == "pm" then
		local sent = if node and node.name then string.upper(node.name) else "???"
		return MapLogic.wrapName(sent)
	end
	return MapLogic.wrapName(MapLogic.NAMES[layer] or string.upper((node and node.name) or layer))
end

-- the game's HTML resource name as plain words
function MapLogic.plain(s: string?): string
	if s == nil then return "" end
	local t = string.gsub(s, "<[^>]*>", "")
	t = string.gsub(t, "&nbsp;", " ")
	t = string.gsub(t, "&amp;", "&")
	t = string.gsub(t, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	return t
end
function MapLogic.unit(resource: string?): string
	local r = string.lower(MapLogic.plain(resource))
	local hit = MapLogic.UNITS[r]
	if hit then return hit end
	-- infected names keep their base unit ("infected super prestige points")
	local base = string.gsub(r, "^infected%s+", "")
	base = string.gsub(base, " ", "-", 1)
	return MapLogic.UNITS[base] or MapLogic.UNITS[string.gsub(r, "^infected%s+", "")] or r
end

-- plate level of detail (DESIGN.md 3.9); prev keeps the hysteresis
local LOD = { WIDE = { full = 0.40, chip = 0.28 }, COMPACT = { full = 0.30, chip = 0.22 } }
function MapLogic.lod(z: number, mode: string, prev: string?): string
	local t = if mode == "COMPACT" then LOD.COMPACT else LOD.WIDE
	local h = 0.02
	local full = t.full + (if prev == "FULL" then -h elseif prev ~= nil then h else 0)
	local chip = t.chip + (if prev == "FULL" or prev == "CHIP" then -h elseif prev ~= nil then h else 0)
	if z >= full then return "FULL" end
	if z >= chip then return "CHIP" end
	return "NONE"
end

-- the connections to draw: both ends shown and one of them lists the other in `br`
export type Link = { from: string, to: string, p: { number }, lit: boolean, secondary: boolean, infected: boolean }
function MapLogic.edges(ms: MapState, realmEdges: { Edge }): { Link }
	local out: { Link } = {}
	for _, e in realmEdges do
		local a, b = ms.nodes[e.from], ms.nodes[e.to]
		if a == nil or b == nil or not a.show or not b.show then continue end
		local found: Branch? = nil
		for _, br in (a.br or {}) :: { Branch } do
			if br.to == e.to then found = br end
		end
		for _, br in (b.br or {}) :: { Branch } do
			if br.to == e.from then found = br end
		end
		if found == nil then continue end
		local col = normColor(found.col)
		local toVal = b.val
		table.insert(out, {
			from = e.from,
			to = e.to,
			p = e.p,
			lit = toVal ~= nil and toVal.lit,
			secondary = col == "#7f7f7f",
			infected = INFECTED[col] == true or MapLogic.isInfected(b.col),
		})
	end
	return out
end

-- the nodes that want an edge marker, pulse first then glow, map order, at most `max`
function MapLogic.markerCandidates(ms: MapState, max: number?): { string }
	local out = {}
	for _, l in ms.ready do table.insert(out, l) end
	for _, l in ms.canBuy do table.insert(out, l) end
	local cap = max or 4
	while #out > cap do table.remove(out) end
	return out
end

-- where the ray from the centre of r (inset) toward (px, py) leaves it; nil when the point is inside
function MapLogic.edgePoint(r: Rect, px: number, py: number, inset: number): (number?, number?)
	local x0, y0, x1, y1 = r.x + inset, r.y + inset, r.x + r.w - inset, r.y + r.h - inset
	if px >= x0 and px <= x1 and py >= y0 and py <= y1 then return nil, nil end
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local dx, dy = px - cx, py - cy
	local t = math.huge
	if dx > 0 then t = math.min(t, (x1 - cx) / dx) elseif dx < 0 then t = math.min(t, (x0 - cx) / dx) end
	if dy > 0 then t = math.min(t, (y1 - cy) / dy) elseif dy < 0 then t = math.min(t, (y0 - cy) / dy) end
	if t == math.huge then return cx, cy end
	return cx + dx * t, cy + dy * t
end

-- ------------------------------------------------------------------------------------------------------ placement
local function overlap(a: Rect, b: Rect): number
	local w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
	local h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
	if w <= 0 or h <= 0 then return 0 end
	return math.min(w, h)
end
MapLogic.overlap = overlap

-- One plate: its slots in preference order (below the ring, above it) for the FULL and CHIP forms.
export type PlateItem = {
	id: string,
	rank: number,
	y: number, -- world y (the tie-break: higher on the map first)
	full: { Rect }?, -- slot rects of the FULL form (nil: FULL not wanted)
	chip: { Rect }?, -- slot rects of the CHIP form (nil: no chip)
	keep: boolean?, -- selected / hovered: never dropped for a collision
}
export type Placed = { id: string, form: string, slot: number, rect: Rect? } -- form: FULL | CHIP | NONE
-- Greedy: in priority order, the first slot of the richest form that meets no blocked rect (HUD) and overlaps no
-- placed plate by more than `slack` px; else the chip; else nothing (the plate fades out, its ring stays).
function MapLogic.place(items: { PlateItem }, blocked: { Rect }, slack: number?): { [string]: Placed }
	local s = slack or 4
	local list = table.clone(items)
	table.sort(list, function(a: PlateItem, b: PlateItem): boolean
		if a.rank ~= b.rank then return a.rank > b.rank end
		if a.y ~= b.y then return a.y < b.y end
		return a.id < b.id
	end)
	local placed: { Rect } = {}
	local out: { [string]: Placed } = {}
	local function free(r: Rect, checkPlaced: boolean): boolean
		for _, b in blocked do
			if overlap(r, b) > 0 then return false end
		end
		if checkPlaced then
			for _, p in placed do
				if overlap(r, p) > s then return false end
			end
		end
		return true
	end
	for _, it in list do
		local done = false
		for _, form in { "FULL", "CHIP" } do
			local slots = if form == "FULL" then it.full else it.chip
			if slots == nil then continue end
			for i, r in slots :: { Rect } do
				if free(r, not it.keep) then
					out[it.id] = { id = it.id, form = form, slot = i, rect = r }
					table.insert(placed, r)
					done = true
					break
				end
			end
			if done then break end
		end
		if not done then out[it.id] = { id = it.id, form = "NONE", slot = 0, rect = nil } end
	end
	return out
end

return MapLogic
