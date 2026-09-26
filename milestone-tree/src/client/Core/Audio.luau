--!strict
--[[
	Audio: the game's sound (MASTER_PLAN 2.6, W6 part 1). Client only; App starts it once. Everything is safe to call
	at any time: before start, with missing asset ids, or with no audio API at all, a cue simply stays silent.

	    Audio.start(o?)                 probe the engine, build the bus graph and the voice pools, follow Prefs
	    Audio.play(name, o?) -> bool    a one-shot cue ("hover", "press", "tab", "panel_open", "panel_close", "buy",
	                                    "toast", "error", "unlock", "prestige_small", "prestige_big");
	                                    o: volume (x), pitch (x), variant (1..n)
	    Audio.pressFor(node)            the click of a view button: "press", or "error" on a locked one
	    Audio.loop(name, level)         a loop ("portal_loop", "ambience") fades toward level 0..1 (0 stops it)
	    Audio.prestige(layer, first?)   the big (first time) or small prestige; first defaults to the one decision,
	                                    Prefs.claimFirstPrestige(layer)
	    Audio.expectBuy(action, store)  a purchase was sent: remember its button (upg / buy actions only)
	    Audio.afterPatch(store)         after a view patch: a remembered purchase whose button changed plays "buy"
	    Audio.observeMap(ms)            after a map change: a layer that woke plays "unlock" (-> the layers)
	    Audio.setLive(on)               cues play only once the realm is on screen (not during boot)
	    Audio.step(dt)                  every frame (the loop fades)
	    Audio.mode                      "api" (the wired Audio API) | "sound" (legacy Sound fallback) | "off"

	The graph (api):
	    UI voices ------> UI fader -------+---------------------------------> Master -> Limiter (-1 dB) -> Output
	                                      +-> UiKey (x0.35) -> Duck.Sidechain
	    Impact voices --> Impacts fader --+-> Master, and -> Duck.Sidechain
	    Ambience loops -> Ambience fader -+-> Duck (AudioCompressor) -> Master
	    (music stems) --> Music fader ----+
	The sound fallback: the same buses as nested SoundGroups (Master > UI, Impacts, Ambience, Music) and a
	CompressorSoundEffect on Ambience and Music keyed by Impacts.

	Voices: round-robin pools of players, one per sheet (ui: the UI bus, fx: Impacts), at most 32 voices on a PC and 16
	on a phone, loops included. Each cue has a RULE: a cooldown, a rate cap (plays in any 1 s), a voice cap, a pitch
	jitter and a priority. A cue past its voice cap steals its own oldest voice, except hover, which is dropped (hover
	spam never stacks). A full pool steals the lowest-priority busy voice, never a higher one. Variants are random with
	no immediate repeat; buy climbs its variants while purchases follow each other (the combo ladder).

	Volumes come from Prefs (music, sfx, ambience: 0..100) through a perceptual curve (v / 100)^2 and follow
	Prefs.changed live. Asset ids come from shared/AudioIds (generated; nil = silent). In Studio, the LocalPlayer
	attribute MT_ForceCaps "all" or "AudioApi" forces the sound fallback and "Audio" turns sound off.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Prefs = require(script.Parent:WaitForChild("Prefs"))

local Audio = {}

export type Rule = {
	pool: string, -- "ui" | "fx"
	cooldown: number, -- seconds between two plays of this cue
	rate: number, -- at most this many plays in any 1 s
	voices: number, -- at most this many at once
	steal: boolean, -- past `voices`: restart its oldest voice (true) or drop the new play (false)
	jitter: number, -- PlaybackSpeed +- (a fraction: .006 = 10 cents)
	priority: number, -- a full pool steals only voices of a lower or equal priority
	gain: number,
	ladder: boolean?, -- variants climb while plays follow each other (buy)
}

Audio.RULES = {
	hover = { pool = "ui", cooldown = 0.075, rate = 7, voices = 2, steal = false, jitter = 0.006, priority = 1, gain = 1 },
	press = { pool = "ui", cooldown = 0.04, rate = 12, voices = 3, steal = true, jitter = 0.02, priority = 4, gain = 1 },
	tab = { pool = "ui", cooldown = 0.06, rate = 8, voices = 2, steal = true, jitter = 0.006, priority = 3, gain = 1 },
	panel_open = { pool = "ui", cooldown = 0.12, rate = 4, voices = 2, steal = true, jitter = 0, priority = 5, gain = 1 },
	panel_close = { pool = "ui", cooldown = 0.12, rate = 4, voices = 2, steal = true, jitter = 0, priority = 5, gain = 1 },
	buy = { pool = "ui", cooldown = 0.06, rate = 9, voices = 6, steal = true, jitter = 0.004, priority = 6, gain = 1, ladder = true },
	toast = { pool = "ui", cooldown = 0.25, rate = 3, voices = 2, steal = true, jitter = 0, priority = 5, gain = 1 },
	error = { pool = "ui", cooldown = 0.25, rate = 3, voices = 1, steal = true, jitter = 0.01, priority = 6, gain = 1 },
	unlock = { pool = "fx", cooldown = 0.8, rate = 2, voices = 2, steal = true, jitter = 0, priority = 8, gain = 1 },
	prestige_small = { pool = "fx", cooldown = 0.35, rate = 3, voices = 2, steal = true, jitter = 0, priority = 8, gain = 1 },
	prestige_big = { pool = "fx", cooldown = 1.5, rate = 1, voices = 1, steal = true, jitter = 0, priority = 10, gain = 1 },
} :: { [string]: Rule }

-- voices per pool (loops: the two loop players); 32 on a PC, 16 on a phone (MASTER_PLAN 5.1)
Audio.BUDGET = {
	pc = { ui = 24, fx = 6, loops = 2 },
	phone = { ui = 11, fx = 3, loops = 2 },
} :: { [string]: { [string]: number } }
-- the mix: each bus's level at 100 % (the user's slider scales it)
Audio.BASE = { UI = 1, Impacts = 1, Ambience = 0.6, Music = 0.8 } :: { [string]: number }
-- each loop's level at level 1
Audio.LOOP_GAIN = { portal_loop = 0.8, ambience = 1 } :: { [string]: number }
Audio.LADDER_GAP = 0.45 -- buys closer than this climb the ladder

Audio.mode = "off" :: string
Audio.live = false
Audio.phone = false
Audio.volumes = { UI = 0, Impacts = 0, Ambience = 0, Music = 0 } :: { [string]: number }
Audio.last = nil :: { name: string, variant: number, speed: number, volume: number }?

type Voice = { inst: Instance, pool: string, name: string?, busyUntil: number, startedAt: number, priority: number }
type Loop = { name: string, inst: Instance?, level: number, target: number, playing: boolean }

local started = false
local ids: any = nil
local root: Instance? = nil
local buses: { [string]: Instance } = {}
local pools: { [string]: { Voice } } = {}
local loops: { [string]: Loop } = {}
local lastAt: { [string]: number } = {}
local recent: { [string]: { number } } = {}
local lastVariant: { [string]: number } = {}
local ladder = { step = -1, at = -math.huge }
local pending: { [string]: { at: number, cls: any, lv: any, tab: any } } = {}
local awakePrev: { [string]: boolean }? = nil
local insidePrev: boolean? = nil
local rng: Random = nil :: any -- made at start (so requiring this module needs no engine globals)
local clock: () -> number = os.clock
local conns: { any } = {} -- Signal connections (Prefs.changed)

-- ------------------------------------------------------------------------------------------------------ helpers
local function isStudio(): boolean
	local ok, v = pcall(function(): boolean
		return RunService:IsStudio()
	end)
	return ok and v == true
end

-- the asset of a sheet: its approved id; in Studio a sheet still in review is tried too (its owner can hear it)
local function idOf(sheet: string): string?
	local s = ids and ids.sheets and ids.sheets[sheet]
	if type(s) ~= "table" then return nil end
	if type(s.id) == "string" and s.id ~= "" then return s.id end
	if type(s.review) == "string" and s.review ~= "" and isStudio() then return s.review end
	return nil
end

local function curve(v: any): number
	local x = math.clamp((tonumber(v) or 0) / 100, 0, 1)
	return x * x
end

local function forced(): string?
	if not isStudio() then return nil end
	local lp = Players.LocalPlayer
	local v = if lp then lp:GetAttribute("MT_ForceCaps") else nil
	if type(v) ~= "string" then return nil end
	for name in string.gmatch(v, "[%w]+") do
		if name == "Audio" then return "off" end
		if name == "all" or name == "AudioApi" then return "sound" end
	end
	return nil
end

local function detectPhone(): boolean
	local phone = false
	pcall(function()
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then phone = true end
		if GuiService.ViewportDisplaySize == Enum.DisplaySize.Small then phone = true end
	end)
	return phone
end

local function loadIds(): any
	local ok, t = pcall(function(): any
		local shared = ReplicatedStorage:FindFirstChild("MilestoneTree")
		if shared == nil then shared = ReplicatedStorage:WaitForChild("MilestoneTree", 5) end
		if shared == nil then return nil end
		local mod = shared:FindFirstChild("AudioIds")
		if mod == nil then mod = shared:WaitForChild("AudioIds", 5) end
		if mod == nil or not mod:IsA("ModuleScript") then return nil end
		return (require :: any)(mod)
	end)
	if ok and type(t) == "table" and type(t.sounds) == "table" and type(t.sheets) == "table" then return t end
	return nil
end

-- ------------------------------------------------------------------------------------------------------ probes
local function probeApi(): boolean
	return pcall(function()
		local p = Instance.new("AudioPlayer") :: any
		local f = Instance.new("AudioFader") :: any
		local w = Instance.new("Wire") :: any
		w.SourceInstance = p
		w.TargetInstance = f
		assert(typeof(p.Play) == "function" and typeof(p.Stop) == "function", "no AudioPlayer methods")
		p.PlaybackRegion = NumberRange.new(0, 1)
		f.Volume = 1
		local c = Instance.new("AudioCompressor") :: any
		local l = Instance.new("AudioLimiter") :: any
		local o = Instance.new("AudioDeviceOutput") :: any
		for _, x in { w, p, f, c, l, o } do x:Destroy() end
	end)
end

local function probeSound(): boolean
	return pcall(function()
		local s = Instance.new("Sound") :: any
		local g = Instance.new("SoundGroup") :: any
		s.SoundGroup = g
		assert(typeof(s.Play) == "function" and typeof(s.Stop) == "function", "no Sound methods")
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(0, 1)
		s:Destroy()
		g:Destroy()
	end)
end

-- ------------------------------------------------------------------------------------------------------ the graph
local POOL_BUS: { [string]: string } = { ui = "UI", fx = "Impacts" } -- each pool's sheet name and bus

local function node(class: string, name: string, props: { [string]: any }?): Instance
	local inst = Instance.new(class :: any) :: any
	inst.Name = name
	for k, v in (props or {}) :: { [string]: any } do inst[k] = v end
	inst.Parent = root
	return inst
end

local function wire(src: Instance, dst: Instance, pin: string?): Instance
	local w = Instance.new("Wire") :: any
	w.Name = "To" .. dst.Name .. (pin or "")
	w.SourceInstance = src
	w.TargetInstance = dst
	if pin then w.TargetName = pin end
	w.Parent = src
	return w
end

local function newRoot(): Instance
	local old = SoundService:FindFirstChild("MT_Audio")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "MT_Audio"
	f.Parent = SoundService
	return f
end

local function buildApi(budget: { [string]: number })
	root = newRoot()
	pcall(function() (SoundService :: any).DefaultListenerLocation = (Enum :: any).ListenerLocation.None end)
	local out = node("AudioDeviceOutput", "Output")
	local limiter = node("AudioLimiter", "Limiter", { MaxLevel = -1, Release = 0.08 })
	local master = node("AudioFader", "Master", { Volume = 1 })
	for _, b in { "UI", "Impacts", "Ambience", "Music" } do buses[b] = node("AudioFader", b, { Volume = 0 }) end
	local duck = node("AudioCompressor", "Duck", { Threshold = -30, Ratio = 4, Attack = 0.01, Release = 0.6, MakeupGain = 0 })
	local key = node("AudioFader", "UiKey", { Volume = 0.35 })
	wire(buses.UI, master)
	wire(buses.UI, key)
	wire(key, duck, "Sidechain")
	wire(buses.Impacts, master)
	wire(buses.Impacts, duck, "Sidechain")
	wire(buses.Ambience, duck)
	wire(buses.Music, duck)
	wire(duck, master)
	wire(master, limiter)
	wire(limiter, out)
	for pool, bus in POOL_BUS do
		local id = idOf(pool)
		local list: { Voice } = {}
		if id then
			for i = 1, budget[pool] or 0 do
				local p = node("AudioPlayer", pool .. "_" .. i, { AutoLoad = true, Looping = false, Volume = 1 }) :: any
				p.Asset = id
				wire(p, buses[bus])
				table.insert(list, { inst = p, pool = pool, name = nil, busyUntil = -math.huge, startedAt = -math.huge, priority = 0 })
			end
		end
		pools[pool] = list
	end
end

local function buildSound(budget: { [string]: number })
	root = newRoot()
	local master = node("SoundGroup", "Master", { Volume = 1 })
	for _, b in { "UI", "Impacts", "Ambience", "Music" } do
		local g = Instance.new("SoundGroup") :: any
		g.Name = b
		g.Volume = 0
		g.Parent = master
		buses[b] = g
	end
	for _, b in { "Ambience", "Music" } do
		pcall(function()
			local c = Instance.new("CompressorSoundEffect") :: any
			c.Name = "Duck"
			c.Threshold = -30
			c.Ratio = 4
			c.Attack = 0.01
			c.Release = 0.6
			c.SideChain = buses.Impacts
			c.Parent = buses[b]
		end)
	end
	for pool, bus in POOL_BUS do
		local id = idOf(pool)
		local list: { Voice } = {}
		if id then
			for i = 1, budget[pool] or 0 do
				local s = node("Sound", pool .. "_" .. i, { SoundGroup = buses[bus], Looped = false, Volume = 1 }) :: any
				s.SoundId = id
				s.PlaybackRegionsEnabled = true
				table.insert(list, { inst = s, pool = pool, name = nil, busyUntil = -math.huge, startedAt = -math.huge, priority = 0 })
			end
		end
		pools[pool] = list
	end
end

local function setVolume(bus: string, v: number)
	Audio.volumes[bus] = v
	local b: Instance? = buses[bus]
	if b == nil then return end
	pcall(function() (b :: any).Volume = v end)
end

local function applyVolumes()
	local p = Prefs.get() :: any
	local base = Audio.BASE
	setVolume("UI", base.UI * curve(p.sfx))
	setVolume("Impacts", base.Impacts * curve(p.sfx))
	setVolume("Ambience", base.Ambience * curve(p.ambience))
	setVolume("Music", base.Music * curve(p.music))
end

-- ------------------------------------------------------------------------------------------------------ start
export type StartOptions = {
	ids: any?, -- an AudioIds table (tests); default: shared/AudioIds
	force: string?, -- "api" | "sound" | "off"
	phone: boolean?,
	clock: (() -> number)?,
	seed: number?,
}

-- tear everything down (tests; a second start rebuilds)
function Audio.reset()
	for _, c in conns do c:Disconnect() end
	table.clear(conns)
	if root then (root :: Instance):Destroy() end
	root = nil
	table.clear(buses)
	table.clear(pools)
	table.clear(loops)
	table.clear(lastAt)
	table.clear(recent)
	table.clear(lastVariant)
	table.clear(pending)
	ladder.step, ladder.at = -1, -math.huge
	awakePrev, insidePrev = nil, nil
	started = false
	Audio.mode = "off"
	Audio.live = false
	Audio.last = nil
end

function Audio.start(o: StartOptions?)
	if started then return end
	started = true
	local opts: StartOptions = o or {}
	if opts.clock then clock = opts.clock :: () -> number else clock = os.clock end
	rng = if opts.seed then Random.new(opts.seed) else Random.new()
	ids = if opts.ids ~= nil then opts.ids else loadIds()
	Audio.phone = if opts.phone ~= nil then opts.phone == true else detectPhone()
	local budget = Audio.BUDGET[if Audio.phone then "phone" else "pc"]
	local want = opts.force or forced()
	local mode = "off"
	if want ~= "off" and want ~= "sound" and probeApi() then
		mode = if pcall(buildApi, budget) then "api" else "off"
	end
	if mode == "off" and want ~= "off" then
		if root then (root :: Instance):Destroy() end
		root = nil
		table.clear(buses)
		table.clear(pools)
		if probeSound() then mode = if pcall(buildSound, budget) then "sound" else "off" end
	end
	if mode == "off" and root then
		(root :: Instance):Destroy()
		root = nil
		table.clear(buses)
		table.clear(pools)
	end
	Audio.mode = mode
	applyVolumes()
	table.insert(conns, Prefs.changed:Connect(function(key: string)
		if key == "sfx" or key == "music" or key == "ambience" then applyVolumes() end
	end))
end

function Audio.setLive(on: boolean)
	Audio.live = on
end

-- ------------------------------------------------------------------------------------------------------ one-shots
local function pickVariant(name: string, n: number): number
	if n <= 1 then return 1 end
	local last = lastVariant[name]
	local k = rng:NextInteger(1, if last then n - 1 else n)
	if last and k >= last then k += 1 end
	return k
end

-- the combo ladder: 1, 2, .. n while buys follow each other, then the top two alternate
local function ladderVariant(n: number, now: number): number
	if now - ladder.at < Audio.LADDER_GAP then ladder.step += 1 else ladder.step = 0 end
	ladder.at = now
	local s = ladder.step
	if s < n then return s + 1 end
	return if (s - n) % 2 == 0 then math.max(1, n - 1) else n
end

local function startVoice(v: Voice, a: number, len: number, speed: number, volume: number): boolean
	return pcall(function()
		local p = v.inst :: any
		if Audio.mode == "api" then
			if p.IsReady == false then error("not loaded") end
			if p.IsPlaying then p:Stop() end
			p.Looping = false
			p.PlaybackRegion = NumberRange.new(a, a + len)
			p.TimePosition = a
			p.PlaybackSpeed = speed
			p.Volume = volume
			p:Play()
		else
			if p.IsPlaying then p:Stop() end
			p.Looped = false
			p.PlaybackRegion = NumberRange.new(a, a + len)
			p.TimePosition = a
			p.PlaybackSpeed = speed
			p.Volume = volume
			p:Play()
		end
	end)
end

export type PlayOptions = { volume: number?, pitch: number?, variant: number? }

function Audio.play(name: string, o: PlayOptions?): boolean
	if not started or not Audio.live or Audio.mode == "off" then return false end
	local rule = Audio.RULES[name]
	local snd = ids and ids.sounds and ids.sounds[name]
	if rule == nil or type(snd) ~= "table" or snd.loop or type(snd.regions) ~= "table" or #snd.regions == 0 then return false end
	if idOf(snd.sheet) == nil then return false end
	local pool = pools[rule.pool]
	if pool == nil or #pool == 0 then return false end
	local now = clock()
	if now - (lastAt[name] or -math.huge) < rule.cooldown then return false end
	local list = recent[name]
	if list == nil then
		list = {}
		recent[name] = list
	end
	while #list > 0 and now - list[1] >= 1 do table.remove(list, 1) end
	if #list >= rule.rate then return false end
	-- a voice: past the cue's own cap, its oldest (or drop); else a free one; else the weakest busy one
	local mine, oldestMine, free, weakest = 0, nil :: Voice?, nil :: Voice?, nil :: Voice?
	for _, v in pool do
		local busy = v.busyUntil > now
		if busy and v.name == name then
			mine += 1
			if oldestMine == nil or v.startedAt < (oldestMine :: Voice).startedAt then oldestMine = v end
		elseif not busy then
			if free == nil then free = v end
		elseif v.priority <= rule.priority then
			local w = weakest
			if w == nil or v.priority < w.priority or (v.priority == w.priority and v.startedAt < w.startedAt) then weakest = v end
		end
	end
	local voice: Voice?
	if mine >= rule.voices then
		if not rule.steal then return false end
		voice = oldestMine
	else
		voice = free or weakest or (if rule.steal then oldestMine else nil)
	end
	if voice == nil then return false end
	local opts: PlayOptions = o or {}
	local n = #snd.regions
	local k = opts.variant or (if rule.ladder then ladderVariant(n, now) else pickVariant(name, n))
	k = math.clamp(math.floor(k), 1, n)
	local region = snd.regions[k]
	if type(region) ~= "table" then return false end
	local a, len = tonumber(region[1]) or 0, tonumber(region[2]) or 0
	if len <= 0 then return false end
	local speed = (opts.pitch or 1) * (1 + rule.jitter * (2 * rng:NextNumber() - 1))
	local volume = math.clamp((opts.volume or 1) * rule.gain * 10 ^ ((rng:NextNumber() - 0.5) * 1.2 / 20), 0, 4)
	local v = voice :: Voice
	if not startVoice(v, a, len, speed, volume) then return false end
	v.name, v.busyUntil, v.startedAt, v.priority = name, now + len / math.max(speed, 0.01) + 0.02, now, rule.priority
	lastAt[name] = now
	lastVariant[name] = k
	table.insert(list, now)
	Audio.last = { name = name, variant = k, speed = speed, volume = volume }
	return true
end

-- the click of a view button (Render): a locked one answers with the soft "no"
function Audio.pressFor(n: any): boolean
	local cls = if type(n) == "table" then n.cls else nil
	if cls == "locked" or cls == "plocked" then return Audio.play("error", { volume = 0.8 }) end
	return Audio.play("press")
end

function Audio.prestige(layer: string?, first: boolean?): boolean
	local big = first
	if big == nil then big = layer ~= nil and Prefs.claimFirstPrestige(layer :: string) end
	return Audio.play(if big then "prestige_big" else "prestige_small")
end

-- ------------------------------------------------------------------------------------------------------ loops
local function loopInst(name: string, snd: any): Instance?
	local sheet = snd.sheet
	local id = idOf(sheet)
	if id == nil or root == nil or Audio.mode == "off" then return nil end
	local ok, inst = pcall(function(): Instance
		if Audio.mode == "api" then
			local p = node("AudioPlayer", "Loop_" .. name, { AutoLoad = true, Looping = true, Volume = 0 }) :: any
			p.Asset = id
			wire(p, buses.Ambience)
			return p
		end
		local s = node("Sound", "Loop_" .. name, { SoundGroup = buses.Ambience, Looped = true, Volume = 0 }) :: any
		s.SoundId = id
		s.PlaybackRegionsEnabled = true
		return s
	end)
	return if ok then inst else nil
end

function Audio.loop(name: string, level: number)
	local l = loops[name]
	if l == nil then
		l = { name = name, inst = nil, level = 0, target = 0, playing = false }
		loops[name] = l
	end
	(l :: Loop).target = math.clamp(if level == level then level else 0, 0, 1)
end

function Audio.loopLevel(name: string): number
	local l = loops[name]
	return if l then l.level else 0
end

local function stepLoop(l: Loop, dt: number)
	local target = if Audio.live then l.target else 0
	local rate = if target > l.level then dt / 1.2 else dt / 0.8
	if math.abs(target - l.level) <= rate then l.level = target elseif target > l.level then l.level += rate else l.level -= rate end
	if not started or Audio.mode == "off" then return end
	local snd = ids and ids.sounds and ids.sounds[l.name]
	if type(snd) ~= "table" or type(snd.regions) ~= "table" or #snd.regions == 0 then return end
	if l.level > 0 and not l.playing then
		if l.inst == nil then l.inst = loopInst(l.name, snd) end
		local inst = l.inst
		if inst == nil then return end
		local region = snd.regions[1]
		if type(region) ~= "table" then return end
		local a, len = tonumber(region[1]) or 0, tonumber(region[2]) or 0
		l.playing = pcall(function()
			local p = inst :: any
			p.PlaybackRegion = NumberRange.new(a, a + len)
			p.LoopRegion = NumberRange.new(a, a + len)
			if Audio.mode == "api" then p.Looping = true else p.Looped = true end
			p.TimePosition = a
			p:Play()
		end)
	end
	local inst = l.inst
	if inst == nil or not l.playing then return end
	pcall(function() (inst :: any).Volume = l.level * (Audio.LOOP_GAIN[l.name] or 1) end)
	if l.level <= 0 then
		pcall(function() (inst :: any):Stop() end)
		l.playing = false
	end
end

function Audio.step(dt: number)
	for _, l in loops do stepLoop(l, dt) end
end

-- ------------------------------------------------------------------------------------------------------ cues from the view
local BUY_VERBS = { upg = true, buy = true } :: { [string]: boolean }

local function sameAction(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do
		if tostring(a[i]) ~= tostring(b[i]) then return false end
	end
	return true
end

-- a purchase was sent (the press, not the result): remember what its button looked like
function Audio.expectBuy(a: any, store: any)
	if type(a) ~= "table" or not BUY_VERBS[a[1]] or type(store) ~= "table" or type(store.nodes) ~= "table" then return end
	for id, n in store.nodes do
		if type(id) == "string" and string.sub(id, 1, 4) == "tab." and type(n) == "table" and n.t == "btn" and sameAction(n.a, a) then
			if n.cls == "can" then pending[id] = { at = clock(), cls = n.cls, lv = n.lv, tab = store.tab } end
			return
		end
	end
end

-- after a patch: a remembered button that is now bought, changed level, or left the same tab was a purchase that
-- went through. A button that only turned locked (spent elsewhere), a new tab, or 2 s of nothing: no sound.
function Audio.afterPatch(store: any): number
	local now = clock()
	local bought = 0
	local okStore = type(store) == "table" and type(store.get) == "function"
	for id, p in pending do
		local n = if okStore then store:get(id) else nil
		if now - p.at > 2 or not okStore or store.tab ~= p.tab then
			pending[id] = nil
		elseif type(n) ~= "table" or n.cls == "bought" or (p.lv ~= nil and n.lv ~= p.lv) then
			pending[id] = nil
			bought += 1
		end
	end
	if bought > 0 then Audio.play("buy") end
	return bought
end

function Audio.pendingBuys(): number
	local n = 0
	for _ in pending do n += 1 end
	return n
end

-- a layer is awake when its node shows and is unlocked (or has no value yet)
local function awake(n: any): boolean
	if type(n) ~= "table" or not n.show then return false end
	local v = n.val
	return v == nil or v.lit == true
end

-- after a map change: layers that woke since the last map play "unlock". The first view and a universe change only
-- set the baseline (many nodes change there at once, and none of them woke).
function Audio.observeMap(ms: any): { string }
	local woke: { string } = {}
	if type(ms) ~= "table" or not ms.ok or type(ms.nodes) ~= "table" then return woke end
	local now: { [string]: boolean } = {}
	for layer, n in ms.nodes do
		if type(layer) == "string" then now[layer] = awake(n) end
	end
	local prev = awakePrev
	if prev == nil or insidePrev ~= ms.inside then
		awakePrev, insidePrev = now, ms.inside
		return woke
	end
	for layer, on in now do
		if on and not (prev :: { [string]: boolean })[layer] and layer ~= "ach" then table.insert(woke, layer) end
	end
	awakePrev = now
	if #woke > 0 then Audio.play("unlock") end
	return woke
end

-- ------------------------------------------------------------------------------------------------------ tests
function Audio.stats(): { mode: string, voices: { [string]: number }, busy: { [string]: number }, total: number, instances: number }
	local now = clock()
	local voices, busy, total = {}, {}, 0
	for pool, list in pools do
		voices[pool] = #list
		local b = 0
		for _, v in list do
			if v.busyUntil > now then b += 1 end
		end
		busy[pool] = b
		total += #list
	end
	for _, l in loops do
		if l.inst then total += 1 end
	end
	return { mode = Audio.mode, voices = voices, busy = busy, total = total, instances = if root then #(root :: Instance):GetDescendants() else 0 }
end

-- how many voices are playing `name` right now
function Audio.playing(name: string): number
	local now = clock()
	local n = 0
	for _, list in pools do
		for _, v in list do
			if v.name == name and v.busyUntil > now then n += 1 end
		end
	end
	return n
end

return Audio
