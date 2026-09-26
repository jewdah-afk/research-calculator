--!nocheck
--[[
	Session: one player's Milestone Tree NG+ game. Pure Luau (no Roblox services), so the same code runs in the
	server's per-player Actor and in the command-line tests.

	    local s = Session.new(deps, saveJson?, optionsJson?, nowMs)
	    s:tick(nowMs)                 -- the page's 50 ms interval body (offline time, updateTemp, gameLoop, ...)
	    s:act(action, nowMs, hold)    -- a button press; only actions that are on the player's screen are run
	    local patch = s:view()        -- what changed on the player's screen since the last view (see below)
	    local save, opts = s:save()   -- JSON strings for the DataStore (nil while the game holds a NaN)

	deps = { TN = TowerNum, JSRT = the JSRT factory, BEcore = BEcore, chunks = { function... } in load order,
	         Fast = Runtime/Fast (optional: native per-tick overrides) }

	A view patch is { set = { [id] = node }, del = { id... }, tab = name, tabStyle = css, keys = { hotkey... },
	ended = bool, full = true on the first patch } plus, once each when they happen: pop = { popup... },
	notice = { text... }, save = "saving" | "saved" (set by the Worker). Nodes are the view builder's (rbx/view.js) flattened: a container's c lists its
	children's ids; ids are paths ("tab.3.1"). The roots are "map" (the realm map: 21 layer nodes then the gate, so
	"map.N" never moves), "hud" and "tab" (the open panel; tab = "none" while the map is alone).
]]

local Session = {}
Session.__index = Session

-- JS value -> plain Luau (1-based arrays, string keys) that RemoteEvents carry
local function plain(JS, x)
	if x == JS.NULL then return nil end   -- JS null is a sentinel table
	local t = type(x)
	if t ~= "table" then
		if t == "number" and x ~= x then return "NaN" end
		return x
	end
	if JS.isD(x) then return JS.str(x) end
	local n = JS.LEN[x]
	if n then
		local out = table.create(n)
		for i = 0, n - 1 do
			local v = plain(JS, x[i])
			if v == nil then v = false end
			out[i + 1] = v
		end
		return out
	end
	local out = {}
	for k, v in x do
		local tk = type(k)
		if (tk == "string" or tk == "number") and type(v) ~= "function" then
			local pv = plain(JS, v)
			if pv ~= nil then out[if tk == "number" then JS.str(k) else k] = pv end
		end
	end
	return out
end
Session.plain = plain

-- a stable text form of an action (arrays nest: ["click", "sp", [14]])
local function actionKey(a): string
	if type(a) ~= "table" then return tostring(a) end
	local parts = table.create(#a)
	for i, v in a do parts[i] = if type(v) == "table" then "[" .. actionKey(v) .. "]" else tostring(v) end
	return table.concat(parts, "\31")
end
Session.actionKey = actionKey

-- deterministic text form of a flattened node, for change detection
local function sig(v): string
	local t = type(v)
	if t ~= "table" then return tostring(v) end
	local keys = {}
	for k in v do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = table.create(#keys)
	for i, k in keys do parts[i] = tostring(k) .. "=" .. sig(v[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function flatten(node, id: string, out: { [string]: any })
	if type(node) ~= "table" then node = { t = "html", h = "" } end
	local entry = {}
	for k, v in node do
		if k ~= "c" then entry[k] = v end
	end
	local kids = node.c
	if type(kids) == "table" then
		local ids = table.create(#kids)
		local n = 0
		for _, child in kids do
			if type(child) == "table" then
				n += 1
				local cid = id .. "." .. n
				ids[n] = cid
				flatten(child, cid, out)
			end
		end
		entry.c = ids
	end
	out[id] = entry
end

local function toJS(JS, v)
	if type(v) ~= "table" then return v end
	local n = #v
	local l = table.create(n)
	for i = 1, n do l[i] = toJS(JS, v[i]) end
	return JS.newArr(l, n)
end

-- ------------------------------------------------------------------------------------------------------ notation
-- The player's number notation (the Options setting; not part of the game save). SCIENTIFIC is the game's own
-- format(). SUFFIX shows 1,000 to 1e303 as 1.23K ... 4.56NoNog (the readable -illion names), and from there suffixes
-- the exponent with 4 figures: 1e23,537 -> e23.54K, e1,329,005 -> e1.329M, e1.080e25 -> e10.80Sp (close costs stay
-- apart: e10.93K vs e10.92K). Numbers under 1,000, exponents under 1,000 (2.19e500) and the F (tetration) range keep
-- the game's format.
local FIRST = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local UNITS = { "", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local TENS = { "", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog" }
local HUNDREDS = { "", "Ce", "Dce", "Tce", "Qace", "Qice", "Sxce", "Spce", "Occe", "Noce" }
-- the suffix of 1e(3k), k >= 1 (k = 1: K, k = 2: M ... k = 100: NoNog)
local function suffix(k: number): string
	if k <= 10 then return FIRST[k] end
	local n = k - 1 -- the -illion index: 1e(3n + 3)
	return UNITS[n % 10 + 1] .. TENS[math.floor(n / 10) % 10 + 1] .. HUNDREDS[math.floor(n / 100) % 10 + 1]
end
Session.suffix = suffix
local MAX_K = 100 -- 1e300 (NoNog) is the last suffix; past it the exponent takes the suffix
-- m in [1, 1000) with `sig` significant figures ("1.23" / "12.3" / "123", or 4: "1.234" / "12.34" / "123.4"); nil
-- when it rounds up to 1000
local function mantissa(m: number, sig: number): string?
	local d = if m < 10 then sig - 1 elseif m < 100 then sig - 2 else sig - 3
	local s = string.format("%." .. math.max(0, d) .. "f", m)
	if tonumber(s) :: number >= 1000 then return nil end
	return s
end
local function suffixFormatter(JS, orig)
	local D = JS.D
	-- d >= 1000 below 1e303 as mantissa + suffix; nil when it is out of that range
	local function suffixed(d, sig: number): string?
		if d:lt(1000) or d:gte("1e303") then return nil end
		local e = math.floor(d:log10():toNumber() + 1e-9)
		local k = math.floor(e / 3)
		local m = d:div(D(10):pow(3 * k)):toNumber()
		local s = mantissa(m, sig)
		if s == nil then
			k += 1
			s = mantissa(m / 1000, sig) or "1"
		end
		if k > MAX_K then return nil end
		return s .. suffix(k)
	end
	local function fmt(this, decimal, precision, small)
		local d = D(decimal)
		local sign = JS.tonum(JS.P(d, "sign"))
		if sign ~= sign or sign == 0 then return orig(this, decimal, precision, small) end
		if sign < 0 then return "-" .. fmt(this, d:neg(), precision, small) end
		if d:lt(1000) or d:gte("eeee1000") then return orig(this, decimal, precision, small) end
		local s = suffixed(d, 3)
		if s then return s end
		-- past 1e303: the exponent, suffixed with 4 figures (and again for its own exponent, far enough up)
		local E = d:log10()
		if E:lt(1000) then return orig(this, decimal, precision, small) end
		local es = suffixed(E, 4)
		if es then return "e" .. es end
		return "e" .. fmt(this, E, precision, small)
	end
	return fmt
end

function Session:setNotation(mode: string?)
	local ENV = self.ENV
	self.notation = mode
	if ENV == nil then return end
	local orig = rawget(ENV, "__formatOrig") or ENV.format
	rawset(ENV, "__formatOrig", orig)
	ENV.format = if mode == "SUFFIX" then suffixFormatter(self.JS, orig) else orig
	self.prev = {} -- every number on screen is sent again in the new notation
end

-- ------------------------------------------------------------------------------------------------------ perks
-- the player's game passes (Main/Shop): { speed = 2? }. Speed is the game's own devSpeed (every tick's time counts
-- speed times, offline catch-up too); without the pass devSpeed is cleared.
function Session:setPerks(perks: { [string]: any }?)
	self.perks = perks or {}
	self:_applyPerks()
end
function Session:_applyPerks()
	local ENV, JS = self.ENV, self.JS
	if ENV == nil or ENV.player == nil then return end
	local sp = self.perks and self.perks.speed
	JS.setk(ENV.player, "devSpeed", if type(sp) == "number" and sp > 1 then sp else nil)
end
-- a Time Warp (a developer product): seconds of progress fed through the next ticks the way the game catches up
-- offline time (a tenth of what is left each tick, at least a second), so it is done in about 3 s
function Session:addWarp(seconds: number)
	self.warp = (self.warp or 0) + math.max(0, seconds)
end

-- ------------------------------------------------------------------------------------------------------ lifecycle
function Session.new(deps, saveJson: string?, optionsJson: string?, nowMs: number)
	local self = setmetatable({}, Session)
	self.deps = deps
	self.prev = {}          -- id -> signature of what the client has
	self.allowed = {}       -- action key -> true, for what is on screen
	self.lastPopup = 0
	self.errors = 0
	self.notices = {}       -- messages for the player (NaN recovered...)
	self.saveEvent = nil    -- "saving" / "saved", set by the Worker, sent once
	self:_start(saveJson, optionsJson, nowMs)
	self.goodSave, self.goodOptions = self:save()
	return self
end

function Session:_start(saveJson: string?, optionsJson: string?, nowMs: number)
	local d = self.deps
	local JS = d.JSRT(d.TN, d.BEcore)
	local ENV = JS.ENV
	JS.NOW = nowMs
	JS.seed(math.random(1, 2147483646))
	for _, f in d.chunks do
		setfenv(f, ENV)
		f()
	end
	JS.overrides()
	if d.Fast then d.Fast(JS, ENV) end -- native versions of the hottest per-tick game functions (Runtime/Fast)
	ENV.rbx_boot(nil, saveJson or "", optionsJson or "")
	self.JS, self.ENV = JS, ENV
	if self.notation then self:setNotation(self.notation) end
	if self.perks then self:_applyPerks() end
	self.prev = {}
	self.lastPopup = 0
	-- popups that were on screen when the game was saved are not news
	local pops = ENV.activePopups
	if pops and JS.LEN[pops] then
		for i = 0, JS.LEN[pops] - 1 do self.lastPopup = math.max(self.lastPopup, (pops[i].id or 0) + 1) end
	end
end

-- back to the last good save (the page's "refresh and you will be un-NaNed")
function Session:_recover(nowMs: number, why: string)
	table.insert(self.notices, why)
	self:_start(self.goodSave, self.goodOptions, nowMs)
end

function Session:tick(nowMs: number): boolean
	local JS, ENV = self.JS, self.ENV
	-- a Time Warp: this tick's clock runs ahead by a slice of it; the game's clock (player.time) is set back to the
	-- real time afterwards, so only this tick's elapsed time grows
	-- (it waits while the game still catches up offline time: that code takes max(remain / 10, this tick's time),
	-- so a slice would count twice)
	local extra = 0
	local w = self.warp
	if w and w > 0 and ENV.player and ENV.player.offTime == nil then
		extra = math.min(w, math.max(w / 10, 1))
		self.warp = w - extra
		if self.warp <= 0.001 then
			self.warp = 0
			self.wantSave = true
		end
	end
	JS.NOW = nowMs + extra * 1000
	local ok, err = pcall(ENV.rbx_tick, nil)
	if extra > 0 and ENV.player then
		JS.NOW = nowMs
		JS.setk(ENV.player, "time", nowMs)
	end
	if not ok then
		self.errors += 1
		self.lastError = tostring(err)
		if self.errors >= 3 then
			self.errors = 0
			self:_recover(nowMs, "The game hit an error and went back to your last save: " .. tostring(err))
		end
		return false
	end
	self.errors = 0
	if ENV.NaNalert then
		self:_recover(nowMs, "An invalid value (NaN) appeared, so the game went back to your last save.")
		return false
	end
	return true
end

-- ---------------------------------------------------------------------------------------------------------- actions
local HOLD_KIND = { click = "hold", grid = "gridHold", buy = "buy" }

function Session:act(a, nowMs: number, hold: boolean?): (boolean, string?)
	if type(a) ~= "table" or type(a[1]) ~= "string" or #a > 4 then return false, "bad action" end
	for _, v in a do
		local tv = type(v)
		if tv ~= "string" and tv ~= "number" and tv ~= "table" then return false, "bad action" end
		if tv == "string" and #v > 200 then return false, "bad action" end
	end
	local key = actionKey(a)
	if a[1] == "key" then
		if not self.hotkeys or not self.hotkeys[a[2]] then return false, "not a hotkey" end
	elseif not self.allowed[key] then
		return false, "not on screen"
	end
	if a[1] == "opt" then return self:_option(a[2], nowMs) end
	local JS, ENV = self.JS, self.ENV
	JS.NOW = nowMs
	local call = a
	if hold then
		local k = HOLD_KIND[a[1]]
		if not k then return false, "not holdable" end
		call = { k, a[2], a[3] }
	end
	local ok, err = pcall(ENV.rbx_do, nil, toJS(JS, call))
	if not ok then return false, tostring(err) end
	return true
end

function Session:_option(name: string, nowMs: number): (boolean, string?)
	if name == "save" then
		self.wantSave = true
		table.insert(self.notices, "Game saved.")
		return true
	elseif name == "playAgain" then
		-- the end screen's Play Again: a fresh game, the options kept (saves live in Roblox, so there is no
		-- export, import or hard reset)
		local _, opts = self:save()
		self:_start(nil, opts, nowMs)
		self.goodSave, self.goodOptions = self:save()
		self.wantSave = true
		return true
	end
	local ok, err = pcall(self.ENV.rbx_do, nil, toJS(self.JS, { "opt", name }))
	return ok, if ok then nil else tostring(err)
end

-- ------------------------------------------------------------------------------------------------------------ saves
function Session:save(): (string?, string?)
	local ok, r = pcall(self.ENV.rbx_saveData, nil)
	if not ok or r == nil or r == self.JS.NULL then return nil, nil end
	return r[0], r[1]
end

-- remember the current state as the one to fall back to; returns what to write to the DataStore
function Session:checkpoint(): (string?, string?)
	local s, o = self:save()
	if s then self.goodSave, self.goodOptions = s, o end
	return s, o
end

-- ------------------------------------------------------------------------------------------------------------- view
function Session:view(): any
	local JS, ENV = self.JS, self.ENV
	local ok, v = pcall(ENV.rbx_view, nil)
	if not ok then
		self.lastError = tostring(v)
		v = nil
	end
	local allowed = {}
	local acts = ENV.rbx_actions
	if acts and JS.LEN[acts] then
		for i = 0, JS.LEN[acts] - 1 do allowed[actionKey(plain(JS, acts[i]))] = true end
	end
	self.allowed = allowed
	local p = if v then plain(JS, v) else {
		map = { t = "map", inside = false, c = {} }, hud = { t = "hud", pts = "?", name = "points", fr = false },
		tab = { t = "html", h = "The page failed to draw." }, tabName = "none",
	}
	local hk = {}
	for _, k in p.keys or {} do hk[k] = true end
	self.hotkeys = hk

	local flat = {}
	flatten(p.map, "map", flat)
	flatten(p.hud, "hud", flat)
	flatten(p.tab, "tab", flat)
	local set, del = {}, {}
	local prev = self.prev
	local nextSig = {}
	local any = false
	for id, e in flat do
		local s = sig(e)
		nextSig[id] = s
		if prev[id] ~= s then set[id] = e; any = true end
	end
	for id in prev do
		if nextSig[id] == nil then table.insert(del, id); any = true end
	end
	local full = next(prev) == nil
	self.prev = nextSig

	local patch = { set = set, del = del, tab = p.tabName, tabStyle = p.tabStyle, keys = p.keys, ended = p.ended, full = full or nil }
	-- popups raised since the last view
	local okp, pops = pcall(ENV.rbx_popups, nil, self.lastPopup)
	if okp and pops and JS.LEN[pops] and JS.LEN[pops] > 0 then
		local list = plain(JS, pops)
		for _, pp in list do self.lastPopup = math.max(self.lastPopup, (pp.id or 0) + 1) end
		patch.pop = list
	end
	if #self.notices > 0 then
		patch.notice = self.notices
		self.notices = {}
	end
	if self.saveEvent then
		patch.save = self.saveEvent
		self.saveEvent = nil
	end
	return patch, any
end

-- the client lost its copy (rejoined the UI): the next view sends everything
function Session:resetView()
	self.prev = {}
end

return Session
