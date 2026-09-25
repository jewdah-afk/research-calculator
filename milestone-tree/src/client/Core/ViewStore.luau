--!strict
--[[
	ViewStore: the client's copy of the view (plan 1.8, 2.4). Pure data: no Roblox services, no instances.

	    local store = ViewStore.new()
	    local changes = store:apply(patch)      -- full clears everything; del then set; returns what changed per root
	    store:map()                             -- MapState, rebuilt only after the map root changed
	    store:hud(), store:endScreen(), store:get(id), store:kids(id)

	Nodes arrive flattened: ids are paths ("map.3.1"), a container's `c` lists its children's ids, and the roots are
	"map", "hud" and "tab". The map list is fixed (all 21
	layers in ORDER, then the gate), but this reads nodes by their `t` / `id`, never by position.
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type Patch = Types.Patch
type Changes = Types.Changes
type MapState = Types.MapState
type MapNode = Types.MapNode
type Val = Types.Val
type Gate = Types.Gate
type HudState = Types.HudState
type EndScreen = Types.EndScreen
type Action = Types.Action

export type Store = {
	nodes: { [string]: any },
	tab: string,
	keys: { [string]: true },
	ended: boolean,
	tabStyle: { [string]: string },
	_map: MapState?,
	_hud: HudState?,
	_hudDirty: boolean,
	apply: (self: Store, patch: Patch) -> Changes,
	get: (self: Store, id: string) -> any?,
	kids: (self: Store, id: string) -> { string },
	map: (self: Store) -> MapState,
	hud: (self: Store) -> HudState?,
	endScreen: (self: Store) -> EndScreen?,
}

local ViewStore = {}

-- the fixed map order (plan 1.2): ids map.1 .. map.21, the gate is map.22
local ORDER: { string } = table.freeze({
	"ach", "m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex",
})
ViewStore.ORDER = ORDER

-- nil, false and a missing key all mean "none"
local function truthy(v: any): boolean
	return v ~= nil and v ~= false
end
local function str(v: any): string?
	return if type(v) == "string" then v elseif type(v) == "number" then tostring(v) else nil
end
local function num(v: any): number?
	return if type(v) == "number" then v else nil
end
local function action(v: any): Action?
	return if type(v) == "table" and #v > 0 then v else nil
end
local function rootOf(id: string): string
	local dot = string.find(id, ".", 1, true)
	return if dot then string.sub(id, 1, dot - 1) else id
end

local function emptyMap(): MapState
	return { ok = false, inside = false, open = nil, close = nil, opt = nil, gate = nil, order = ORDER, nodes = {}, ready = {}, canBuy = {} }
end

local function readVal(n: any): Val
	return {
		t = "val",
		can = truthy(n.can),
		lit = truthy(n.lit),
		glow = truthy(n.glow),
		pulse = truthy(n.pulse),
		pts = str(n.pts),
		res = str(n.res),
		tip = str(n.tip),
		ra = action(n.ra),
		req = str(n.req),
		rres = str(n.rres),
		gain = str(n.gain),
		pr = num(n.pr),
		tot = str(n.tot),
	}
end

local function readGate(self: Store, n: any): Gate
	local req: Types.GateReq? = nil
	if type(n.req) == "table" then
		req = { have = str(n.req.have) or "0", need = str(n.req.need) or "185", pr = num(n.req.pr) or 0 }
	end
	local rs: { string } = {}
	if type(n.rs) == "table" then
		for _, l in n.rs do
			if type(l) == "string" then table.insert(rs, l) end
		end
	end
	return {
		t = "gate",
		show = truthy(n.show),
		inside = truthy(n.inside),
		can = truthy(n.can),
		fin = truthy(n.fin),
		h = str(n.h),
		goal = str(n.goal),
		done = truthy(n.done),
		a = action(n.a),
		req = req,
		rs = rs,
	}
end

local function readNode(self: Store, n: any): MapNode
	local node: MapNode = {
		t = "node",
		id = n.id,
		show = truthy(n.show),
		dor = truthy(n.dor),
		unl = if n.unl ~= nil then truthy(n.unl) else nil,
		col = str(n.col),
		sym = str(n.sym),
		name = str(n.name),
		st = if type(n.st) == "table" then n.st else nil,
		tab = str(n.tab),
		ch = num(n.ch),
		cur = if n.cur ~= nil then truthy(n.cur) else nil,
		br = nil,
		a = action(n.a),
		val = nil,
	}
	if type(n.br) == "table" then
		local br = {}
		for _, b in n.br do
			if type(b) == "table" and type(b.to) == "string" then
				table.insert(br, { to = b.to, col = str(b.col) or "#ffffff", w = num(b.w) })
			end
		end
		node.br = br
	end
	if type(n.c) == "table" then
		for _, cid in n.c do
			local child = if type(cid) == "string" then self.nodes[cid] else nil
			if type(child) == "table" and child.t == "val" then
				node.val = readVal(child)
				break
			end
		end
	end
	return node
end

local function buildMap(self: Store): MapState
	local root = self.nodes.map
	if type(root) ~= "table" or root.t ~= "map" then return emptyMap() end
	local ms = emptyMap()
	ms.ok = true
	ms.inside = truthy(root.inside)
	ms.open = str(root.open)
	ms.close = action(root.close)
	ms.opt = action(root.opt)
	for _, cid in (if type(root.c) == "table" then root.c else {}) :: { any } do
		local n = if type(cid) == "string" then self.nodes[cid] else nil
		if type(n) ~= "table" then continue end
		if n.t == "node" and type(n.id) == "string" then
			ms.nodes[n.id] = readNode(self, n)
		elseif n.t == "gate" then
			ms.gate = readGate(self, n)
		end
	end
	for _, l in ORDER do
		local n = ms.nodes[l]
		local v = if n and n.show then n.val else nil
		if v then
			if v.pulse then
				table.insert(ms.ready, l)
			elseif v.glow then
				table.insert(ms.canBuy, l)
			end
		end
	end
	return ms
end

local function buildHud(self: Store): HudState?
	local n = self.nodes.hud
	if type(n) ~= "table" or n.t ~= "hud" then return nil end
	local w: { Types.HudWarn } = {}
	if type(n.w) == "table" then
		for _, x in n.w do
			if type(x) == "table" and type(x.k) == "string" then
				table.insert(w, { k = x.k, v = str(x.v) or "", e = str(x.e) or "" })
			end
		end
	end
	return {
		t = "hud",
		pts = str(n.pts) or "0",
		name = str(n.name) or "points",
		gen = str(n.gen),
		dev = str(n.dev),
		off = str(n.off),
		w = w,
		wh = str(n.wh),
		x = str(n.x),
		fr = truthy(n.fr),
	}
end

function ViewStore.new(): Store
	local self = {
		nodes = {},
		tab = "none",
		keys = {},
		ended = false,
		tabStyle = {},
		_map = nil,
		_hud = nil,
		_hudDirty = true,
	} :: Store

	function self.apply(s: Store, patch: Patch): Changes
		local changes: Changes = {
			full = patch.full == true,
			map = false,
			hud = false,
			tab = false,
			tabName = false,
			keys = false,
			ended = false,
			mapIds = {},
			tabPatch = { set = {}, del = {}, full = patch.full == true },
		}
		local function touch(id: string)
			local r = rootOf(id)
			if r == "map" then
				changes.map = true
				changes.mapIds[id] = true
			elseif r == "hud" then
				changes.hud = true
			elseif r == "tab" then
				changes.tab = true
			end
		end
		if patch.full then
			table.clear(s.nodes)
			changes.map, changes.hud, changes.tab = true, true, true
		end
		if type(patch.del) == "table" then
			for _, id in patch.del do
				if type(id) ~= "string" then continue end
				s.nodes[id] = nil
				touch(id)
				if rootOf(id) == "tab" then table.insert(changes.tabPatch.del, id) end
			end
		end
		if type(patch.set) == "table" then
			for id, n in patch.set do
				if type(id) ~= "string" then continue end
				s.nodes[id] = n
				touch(id)
				if rootOf(id) == "tab" then changes.tabPatch.set[id] = n end
			end
		end
		if type(patch.tab) == "string" and patch.tab ~= s.tab then
			s.tab = patch.tab
			changes.tabName = true
		end
		if type(patch.keys) == "table" then
			local k: { [string]: true } = {}
			for _, name in patch.keys do
				if type(name) == "string" then k[name] = true end
			end
			s.keys = k
			changes.keys = true
		end
		if patch.ended ~= nil then
			local e = patch.ended == true
			if e ~= s.ended then changes.ended = true end
			s.ended = e
		end
		if type(patch.tabStyle) == "table" then s.tabStyle = patch.tabStyle end
		if changes.map then s._map = nil end
		if changes.hud then s._hudDirty = true end
		return changes
	end

	function self.get(s: Store, id: string): any?
		return s.nodes[id]
	end

	function self.kids(s: Store, id: string): { string }
		local n = s.nodes[id]
		if type(n) == "table" and type(n.c) == "table" then return n.c end
		return {}
	end

	function self.map(s: Store): MapState
		local m = s._map
		if m == nil then
			m = buildMap(s)
			s._map = m
		end
		return m :: MapState
	end

	function self.hud(s: Store): HudState?
		if s._hudDirty then
			s._hud = buildHud(s)
			s._hudDirty = false
		end
		return s._hud
	end

	-- the end screen (plan 1.5): the tab root carries win / took; its two buttons carry the opt actions
	function self.endScreen(s: Store): EndScreen?
		if not s.ended then return nil end
		local root = s.nodes.tab
		if type(root) ~= "table" then return nil end
		local out: EndScreen = { win = str(root.win), took = str(root.took), again = nil, keep = nil }
		local function walk(id: string, depth: number)
			if depth > 6 then return end
			local n = s.nodes[id]
			if type(n) ~= "table" then return end
			local a = action(n.a)
			if a and a[1] == "opt" then
				if a[2] == "playAgain" then
					out.again = a
				elseif a[2] == "keepGoing" then
					out.keep = a
				end
			end
			if type(n.c) == "table" then
				for _, cid in n.c do
					if type(cid) == "string" then walk(cid, depth + 1) end
				end
			end
		end
		walk("tab", 0)
		return out
	end

	return self
end

return ViewStore
