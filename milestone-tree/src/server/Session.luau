--!nocheck
--[[
	Session: one player's Milestone Tree NG+ game. Pure Luau (no Roblox services), so the same code runs in the
	server's per-player Actor and in the command-line tests.

	    local s = Session.new(deps, saveJson?, optionsJson?, nowMs)
	    s:tick(nowMs)                 -- the page's 50 ms interval body (offline time, updateTemp, gameLoop, ...)
	    s:act(action, nowMs, hold)    -- a button press; only actions that are on the player's screen are run
	    local patch = s:view()        -- what changed on the player's screen since the last view (see below)
	    local save, opts = s:save()   -- JSON strings for the DataStore (nil while the game holds a NaN)

	deps = { TN = TowerNum, JSRT = the JSRT factory, BEcore = BEcore, chunks = { function... } in load order }

	A view patch is { set = { [id] = node }, del = { id... }, tab = name, tabStyle = css, keys = { hotkey... },
	ended = bool, pop = { popup... }, full = true on the first patch }. Nodes are the view builder's (rbx/view.js)
	flattened: a container's c lists its children's ids; ids are paths ("tab.3.1") and the three roots are
	"menu", "head" and "tab".
]]

local Session = {}
Session.__index = Session

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64INV = {}
for i = 1, 64 do B64INV[string.byte(B64, i)] = i - 1 end

local function b64encode(s: string): string
	local out = table.create(math.ceil(#s / 3) * 4)
	for i = 1, #s, 3 do
		local a, b, c = string.byte(s, i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2, c3, c4 = bit32.extract(n, 18, 6), bit32.extract(n, 12, 6), bit32.extract(n, 6, 6), bit32.extract(n, 0, 6)
		table.insert(out, string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
			.. (if b then string.sub(B64, c3 + 1, c3 + 1) else "=") .. (if c then string.sub(B64, c4 + 1, c4 + 1) else "="))
	end
	return table.concat(out)
end
local function b64decode(s: string): string?
	s = string.gsub(s, "[^%w%+/=]", "")
	local out = {}
	local bits, nbits = 0, 0
	for i = 1, #s do
		local ch = string.byte(s, i)
		if ch == 61 then break end -- "="
		local v = B64INV[ch]
		if v == nil then return nil end
		bits = bit32.bor(bit32.lshift(bits, 6), v)
		nbits += 6
		if nbits >= 8 then
			nbits -= 8
			table.insert(out, string.char(bit32.band(bit32.rshift(bits, nbits), 255)))
		end
		bits = bit32.band(bits, 0xFFFF)
	end
	return table.concat(out)
end
Session.b64encode, Session.b64decode = b64encode, b64decode

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

-- ------------------------------------------------------------------------------------------------------ lifecycle
function Session.new(deps, saveJson: string?, optionsJson: string?, nowMs: number)
	local self = setmetatable({}, Session)
	self.deps = deps
	self.prev = {}          -- id -> signature of what the client has
	self.allowed = {}       -- action key -> true, for what is on screen
	self.lastPopup = 0
	self.errors = 0
	self.notices = {}       -- messages for the player (import failed, NaN recovered...)
	self.hardResetArmed = 0
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
	ENV.rbx_boot(nil, saveJson or "", optionsJson or "")
	self.JS, self.ENV = JS, ENV
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
	JS.NOW = nowMs
	local ok, err = pcall(ENV.rbx_tick, nil)
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
	elseif name == "hardReset" or name == "playAgain" then
		if name == "hardReset" and nowMs - self.hardResetArmed > 5000 then
			self.hardResetArmed = nowMs
			table.insert(self.notices, "Press Hard Reset again within 5 seconds to wipe your progress.")
			return true
		end
		self.hardResetArmed = 0
		local _, opts = self:save()
		self:_start(nil, opts, nowMs)
		self.goodSave, self.goodOptions = self:save()
		self.wantSave = true
		table.insert(self.notices, "Your progress was reset.")
		return true
	elseif name == "export" then
		self.exportText = self:export()
		return true
	elseif name == "import" then
		self.wantImport = true
		return true
	end
	local ok, err = pcall(self.ENV.rbx_do, nil, toJS(self.JS, { "opt", name }))
	return ok, if ok then nil else tostring(err)
end

-- the web game's export string: base64 of the player JSON (its Import accepts it back)
function Session:export(): string?
	local s = self:save()
	if s == nil then return nil end
	return b64encode(s)
end

-- a save string from the web game (Export, or the localStorage value) or from export(); JSON works too
function Session:import(text: string, nowMs: number): (boolean, string?)
	if type(text) ~= "string" or #text < 2 or #text > 3000000 then return false, "That is not a save." end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local json = if string.sub(text, 1, 1) == "{" then text else b64decode(text)
	if json == nil or string.sub(json, 1, 1) ~= "{" then return false, "That is not a save." end
	local okParse, parsed = pcall(self.JS.G.JSON.parse, json)
	if not okParse or type(parsed) ~= "table" or parsed.points == nil then return false, "That is not a save for this game." end
	local oldSave, oldOpts = self:save()
	local ok, err = pcall(self._start, self, json, oldOpts, nowMs)
	if ok then
		ok, err = pcall(self.tick, self, nowMs)
		if ok and self.ENV.NaNalert then ok, err = false, "the save holds invalid values" end
	end
	if not ok then
		self:_start(oldSave, oldOpts, nowMs)
		return false, "That save could not be loaded (" .. tostring(err) .. ")."
	end
	self.goodSave, self.goodOptions = self:save()
	self.wantSave = true
	table.insert(self.notices, "Save imported.")
	return true
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
	local p = if v then plain(JS, v) else { menu = { t = "col", c = {} }, head = { t = "html", h = "" }, tab = { t = "html", h = "The page failed to draw." } }
	local hk = {}
	for _, k in p.keys or {} do hk[k] = true end
	self.hotkeys = hk

	local flat = {}
	flatten(p.menu, "menu", flat)
	flatten(p.head, "head", flat)
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
	if self.exportText then
		patch.export = self.exportText
		self.exportText = nil
	end
	if self.wantImport then
		patch.askImport = true
		self.wantImport = nil
	end
	return patch, any
end

-- the client lost its copy (rejoined the UI): the next view sends everything
function Session:resetView()
	self.prev = {}
end

return Session
