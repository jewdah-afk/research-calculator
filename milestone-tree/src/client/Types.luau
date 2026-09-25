--!strict
--[[
	Types: the shapes every client module shares. The view contract of docs/design/IMPLEMENTATION_PLAN.md section 1
	(what the server sends) and the client's own records (section 2.4). No code.

	On the wire JS null arrives as a missing key (inside objects) or `false` (inside arrays), so every optional field
	is `T?` and readers treat nil, false and a missing key alike ("absent == null").
]]

export type Action = { any }
export type Rect = { x: number, y: number, w: number, h: number } -- abs space px (plan 2.9) unless a name says otherwise
export type Camera = { C: Vector2, z: number, V: Vector2, m: number } -- world px, world zoom, map points, device px per point

-- --------------------------------------------------------------------------------------------------- v.map (plan 1.2)
export type Branch = { to: string, col: string, w: number? }
export type Val = {
	t: string,
	can: boolean,
	lit: boolean,
	glow: boolean,
	pulse: boolean,
	pts: string?,
	res: string?,
	tip: string?,
	ra: Action?,
	req: string?,
	rres: string?,
	gain: string?,
	pr: number?, -- per mille (0..1000)
	tot: string?,
}
export type MapNode = {
	t: string,
	id: string,
	show: boolean,
	dor: boolean,
	unl: boolean?,
	col: string?,
	sym: string?,
	name: string?,
	st: { [string]: any }?,
	tab: string?,
	ch: number?,
	cur: boolean?,
	br: { Branch }?,
	a: Action?,
	val: Val?,
}
export type GateReq = { have: string, need: string, pr: number }
export type Gate = {
	t: string,
	show: boolean,
	inside: boolean,
	can: boolean,
	fin: boolean,
	h: string?,
	goal: string?,
	done: boolean,
	a: Action?,
	req: GateReq?,
	rs: { string },
}
export type MapState = {
	ok: boolean, -- false when the map root is missing or failed to build (then nodes is empty)
	inside: boolean,
	open: string?,
	close: Action?,
	opt: Action?,
	gate: Gate?,
	order: { string }, -- the 21 layers in the fixed map order
	nodes: { [string]: MapNode },
	ready: { string }, -- shown and pulsing (can prestige), map order
	canBuy: { string }, -- shown, glowing, not pulsing, map order
}

-- --------------------------------------------------------------------------------------------------- v.hud (plan 1.3)
export type HudWarn = { k: string, v: string, e: string }
export type HudState = {
	t: string,
	pts: string,
	name: string,
	gen: string?,
	dev: string?,
	off: string?,
	w: { HudWarn },
	wh: string?,
	x: string?,
	fr: boolean,
}

-- --------------------------------------------------------------------------------------------------- wire patch (plan 1.8)
export type Popup = {
	id: number?,
	title: string?,
	message: string?,
	type: string?,
	color: string?,
	bColor: string?,
	kind: string?, -- milestone | achievement | corruption | other (notices are kind "notice" on the client)
	layer: string?,
}
export type Patch = {
	set: { [string]: any }?,
	del: { string }?,
	full: boolean?,
	tab: string?,
	tabStyle: { [string]: string }?,
	keys: { string }?,
	ended: boolean?,
	pop: { Popup }?,
	notice: { string }?,
	save: string?, -- "saving" | "saved"
	unsaved: boolean?,
	fatal: string?,
	status: string?,
}
export type TabPatch = { set: { [string]: any }, del: { string }, full: boolean }
export type Changes = {
	full: boolean,
	map: boolean,
	hud: boolean,
	tab: boolean, -- a node under the tab root changed
	tabName: boolean, -- patch.tab moved
	keys: boolean,
	ended: boolean,
	mapIds: { [string]: true },
	tabPatch: TabPatch,
}
export type EndScreen = { win: string?, took: string?, again: Action?, keep: Action? }

-- --------------------------------------------------------------------------------------------------- client records
export type Prefs = {
	motion: string, -- SYSTEM | FULL | REDUCED
	detail: string, -- AUTO | HIGH | LOW
	labels: string, -- AUTO | ALWAYS | OFF
	size: number, -- 90 | 100 | 115
}
export type Mode = string -- "WIDE" | "MEDIUM" | "COMPACT"
export type Handle = { stop: (self: Handle) -> () }

-- the render integration (plan 2.5, 2.6)
export type SkinCtx = {
	layer: string,
	sub: string?,
	hue: Color3,
	mode: string,
	signature: any,
	act: (action: Action, hold: boolean?) -> (),
}
export type Claim = {
	update: (self: Claim, store: any) -> (),
	destroy: (self: Claim) -> (),
}
export type ClaimMatch = { cn: string, ci: number?, sub: string?, depth: number? }
export type ClaimRule = {
	match: ClaimMatch,
	make: (ph: Frame, id: string, store: any, ctx: SkinCtx) -> Claim,
}
export type Signature = {
	layers: { string },
	cta: string?,
	subRow: string?,
	corrupted: boolean?,
	hug: boolean?,
	order: { string }?,
	hero: ((hero: Frame, store: any, ctx: SkinCtx) -> ())?,
	accent: ((sheet: Frame, ctx: SkinCtx) -> ())?,
	claims: { ClaimRule }?,
	skin: ((rec: any, n: any, ctx: SkinCtx) -> boolean)?,
}

return {}
