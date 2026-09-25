--!strict
--[[
	Signatures: the per-layer plug-ins of the panel template (plan 2.6, DESIGN.md 6) and the default one.

	    Signatures.register(sig)     a sibling module (Signatures/<X>.luau, packages J1 / J2) registers its tables
	    Signatures.get(key)          the signature of a layer ("m", "p", ..., "options-tab"); the default when none
	    Signatures.title(key, node)  the panel title, CTA word, sub-row line, tree row and short unit helpers the
	    Signatures.cta(key) ...      default signature uses (client labels, never game data: plan P10)

	Every sibling ModuleScript is required once, on the first get(): J1 and J2 add files and never edit this one.
	A signature that fails to load is skipped (with a warning), so one bad file never blanks a panel.

	A signature table (Types.Signature):
	    layers     { "m", "mm" }        the keys it serves
	    cta        "GET +1 MILESTONE"   the CTA word (default: the table below)
	    subRow     "The root of the tree"   the sentence-case line next to the ROW chip
	    corrupted  true                 the D 5.2 corrupted treatment (cp, cm)
	    hug        true                 the sheet hugs its content (min 560 du)
	    order      { "milestones", ... } section order override, by cn
	    hero       fn(hero, store, ctx) adds the hero idea after the default hero drew (called on every update)
	    accent     fn(sheet, ctx)       watermark / tile / rim variant (called when the panel opens or relayouts)
	    claims     { {match = {cn, ci?, sub?, depth?}, make = fn(ph, id, store, ctx) -> Claim} }
	    skin       fn(rec, n, ctx) -> boolean   a per-layer skin that runs before the default skins; true = handled
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type Signature = Types.Signature

-- the context every skin, claim and hero hook receives (a superset of Types.SkinCtx)
export type Ctx = {
	layer: string, -- the panel key: a layer id or "options-tab"
	sub: string?, -- the current subtab ("Main", "Upgrades", ...)
	hue: Color3,
	mode: string, -- Layout.mode
	signature: any,
	act: (action: Types.Action, hold: boolean?) -> (),
	store: any, -- the ViewStore
	render: any, -- the Renderer (skins look up parent records through render.recs)
	s: number, -- Layout.s
	contentW: number, -- the body's content width (du)
	cardW: number, -- the upgrade card width (du)
	corrupted: boolean,
	detail: (card: any) -> (), -- the touch detail sheet (panel.detail)
	firstSeen: (key: string) -> boolean, -- true the first time an animation key is seen since the panel opened
	cache: { [string]: any }, -- per-apply memo (fresh for every Render apply)
	scroll: ScrollingFrame, -- the body's scrolling frame (virtual lists follow it)
}

local Signatures = {}

-- ------------------------------------------------------------------------------------------------------ labels
-- panel titles (the map node's name is the fallback; pm keeps its masked name as sent)
local TITLE: { [string]: string } = {
	m = "Milestone", mm = "Meta Milestone", em = "Extra Milestone", p = "Prestige", pe = "Prestige Energy",
	sp = "Super Prestige", pb = "Prestige Boost", pp = "Prestige Power", se = "Super Energy", hp = "Hyper Prestige",
	ep = "Exotic Prestige", hb = "Hyper Boost", ap = "Atomic Prestige", mp = "Multiverse", t = "Transcend",
	ach = "Achievements", pep = "Prestiged Exotic", cp = "Corrupted Prestige", cm = "Corrupted Milestone",
	ex = "Exploration", ["options-tab"] = "Options",
}
-- the CTA word (plan P10: a label, not game data)
local CTA: { [string]: string } = {
	m = "GET +1 MILESTONE", mm = "GET +1", em = "GET +1", pm = "GET +1", cm = "GET +1",
	pe = "COLLECT", se = "COLLECT", ex = "EXPLORE", cp = "CORRUPT",
	pb = "GET", hb = "GET", mp = "GET", pep = "GET",
}
-- the sentence-case line of the sub row
local SUBROW: { [string]: string } = {
	m = "The root of the tree", mm = "Resets for meta milestones", em = "Resets for extra milestones",
	p = "Resets for prestige points", pe = "Collects prestige energy", sp = "Resets for super prestige points",
	pb = "Resets for prestige boosts", pp = "Resets for prestige power", se = "Collects super energy",
	hp = "Resets for hyper prestige points", ep = "Resets for exotic prestige points", hb = "Resets for hyper boosts",
	ap = "Resets for atomic prestige points", mp = "Resets for multiverse points", t = "Resets for transcend points",
	ach = "Your trophies", pm = "Resets for prestige milestones", pep = "Resets for prestiged exotic points",
	cp = "Corrupts prestige points", cm = "Resets for corrupted milestones", ex = "Explores the zones",
	["options-tab"] = "Your save and this device",
}
-- the game's tree rows (layers/*.js `row`); "side" layers have no chip
local ROW: { [string]: number } = {
	m = 0, pm = 0, mm = 1, p = 1, cm = 1, cp = 1, pep = 1, em = 2, pe = 2, sp = 2, pb = 2, pp = 2, ex = 2,
	se = 3, hp = 3, ep = 3, hb = 4, ap = 4, mp = 4, t = 5,
}
-- short units for resource names (the client's abbreviation table, plan 1.13)
local UNIT: { [string]: string } = {
	["prestige points"] = "PP", ["super-prestige points"] = "SP", ["hyper-prestige points"] = "HP",
	["exotic prestige points"] = "EP", ["atomic-prestige points"] = "AP", ["multiverse prestige points"] = "MP",
	["transcend points"] = "TP", ["prestige energy"] = "PE", ["super energy"] = "SE", ["prestige power"] = "PW",
	["prestige boosts"] = "PB", ["hyper boosts"] = "HB", ["prestiged-exotic prestige points"] = "PEP",
	["exploration points"] = "EX", ["prestige essence"] = "PE", ["prestige essences"] = "PE",
	["corruption essences"] = "CE", ["corrupted milestones"] = "CM", ["milestones"] = "M",
	["meta-milestones"] = "MM", ["extra-milestones"] = "EM", ["points"] = "points",
}

function Signatures.title(key: string, node: any?): string
	if key == "pm" and node and type(node.name) == "string" then return node.name end
	return TITLE[key] or (if node and type(node.name) == "string" then node.name else string.upper(key))
end
function Signatures.row(key: string): number?
	return ROW[key]
end
-- a resource name -> its short unit ("prestige points" -> "PP"); the name itself when unknown
function Signatures.unit(res: string?): string
	if type(res) ~= "string" then return "" end
	local k = string.lower((string.gsub(string.gsub(res, "<[^>]*>", ""), "^%s+", "")))
	k = string.gsub(k, "%s+$", "")
	return UNIT[k] or k
end

-- ------------------------------------------------------------------------------------------------------ registry
local registry: { [string]: Signature } = {}
local loaded = false

local DEFAULT: Signature = {
	layers = {},
	cta = nil,
	subRow = nil,
	corrupted = nil,
	hug = nil,
	order = nil,
	hero = nil,
	accent = nil,
	claims = nil,
	skin = nil,
}
Signatures.DEFAULT = DEFAULT

function Signatures.register(sig: Signature)
	if type(sig) ~= "table" or type(sig.layers) ~= "table" then return end
	for _, l in sig.layers do
		if type(l) == "string" then registry[l] = sig end
	end
end

-- require every sibling once (auto-registration); a module may return a Signature or a list of them
local function loadAll()
	if loaded then return end
	loaded = true
	for _, m in script.Parent:GetChildren() do
		if m ~= script and m:IsA("ModuleScript") then
			local ok, res = pcall(require, m)
			if not ok then
				warn("[MilestoneTree] signature " .. m.Name .. " failed to load: " .. tostring(res))
				continue
			end
			if type(res) == "table" then
				local r: any = res
				if type(r.layers) == "table" then
					Signatures.register(r)
				else
					for _, s in r do
						if type(s) == "table" and type(s.layers) == "table" then Signatures.register(s) end
					end
				end
			end
		end
	end
end

function Signatures.get(key: string): Signature
	loadAll()
	return registry[key] or DEFAULT
end

-- the CTA word of a layer: the signature's, else the default table, else PRESTIGE
function Signatures.cta(key: string): string
	local sig = Signatures.get(key)
	return sig.cta or CTA[key] or "PRESTIGE"
end
function Signatures.subRow(key: string): string?
	local sig = Signatures.get(key)
	return sig.subRow or SUBROW[key]
end
-- corrupted treatment: the signature's flag, else cp / cm
function Signatures.corrupted(key: string): boolean
	local sig = Signatures.get(key)
	if sig.corrupted ~= nil then return sig.corrupted == true end
	return key == "cp" or key == "cm"
end

return Signatures
