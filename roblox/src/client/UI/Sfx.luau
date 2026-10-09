--!nonstrict
-- Sfx: every UI sound, one function per event. Ids live in ONE table (IDS) so the real sounds can be picked from
-- Roblox's licensed audio library in Studio and dropped in without touching any caller. While an id is 0 the event
-- falls back to Kit's keyboard slice at a pitch that suits it, so the game is never silent.
--   rules: +-5 % random pitch on repeats; a volume hierarchy (UI quieter than rewards); one SoundGroup per
--   category (Settings volume sliders); collect pitch climbs with quick successive collects (resets after 1 s);
--   coin_land climbs through a fly-in sequence; music ducks under big moments.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Kit = require(script.Parent.Kit)

local Sfx = {}

-- sound ids (0 = keyboard-slice fallback). PROVISIONAL: the first licensed candidate of each event (UI/SfxCandidates:
-- Pro Sound Effects / Roblox UI pack / APM) until the owner picks by ear on the dev Sound Board (UI/SoundBoard), whose
-- COPY TABLE prints this table with the picks.
local IDS = {
	press_down = 9120917438,
	press_up = 15675032796,
	hover_tick = 9113873378,
	tab_switch = 15675037413,
	window_open = 15675024286,
	window_close = 15675081158,
	row_select = 15675059323,
	dropdown_open = 15675046931,
	dropdown_close = 15675028888,
	toggle_on = 9119717523,
	toggle_off = 9119717529,
	slider_tick = 9117043852,
	scroll_tick = 9117044346,
	board_roll_down = 9116480637,
	board_roll_up = 9114451733,
	board_clack = 9120917861,
	buy_ok = 9126073644,
	purchase_big = 9048764562,
	cant_afford = 9120917609,
	denied = 0,
	maxed = 9126073064,
	level_up = 9048764475,
	collect = 9112751731,
	coin_land = 9126076118,
	toast = 9125397272,
	unlock = 9040476898,
	island_unlock = 9048764753,
	molt = 9114369862,
	evolve = 9125635297,
	collect_layer_a = 9114231992,   -- egg pickup layer A: a real eggshell tap (Eggs Break 3)
	collect_layer_b = 9117019900,   -- egg pickup layer B: the butter, a soft round pop (Mouth Pop Thudding 3)
	egg_hatch_crack = 9114231988,
	hatch_reveal = 9116394545,
	error = 15675075163,
}
-- optional start offset per id (seconds into the file: library files often hold several takes); default 0
local START = {}
-- max play length per category (long tails fade out over the last 25 % and stop); an event can override it
local MAXLEN = { ui = 0.35, rewards = 1.2, messages = 3, music = 0 }
local EVENT_MAXLEN = {}
-- LAYERED events: several short sounds stacked into one (owner: "egg like but buttery"). A layer is
--   { idKey (an IDS entry, so the Sound Board can swap it) | id, start (s), len (s, faded over its last 30 %),
--     vol, pitch (or pitch = { min, max } random), delay (s), eq = { high, mid, low } dB (EqualizerSoundEffect) }
-- One random +-pitchVary per play is shared by every layer; the event's pitchMul (collect combo) scales them all.
local WARM = { -9, -2, 3 }    -- no harsh crack, a round body
local LAYERS = {
	collect = { pitchVary = 0.04, layers = {
		{ idKey = "collect_layer_a", start = 0, len = 0.12, vol = 0.3, pitch = { 1.1, 1.25 }, delay = 0, eq = WARM },
		{ idKey = "collect_layer_b", start = 0, len = 0.25, vol = 0.4, pitch = 1, delay = 0.007, eq = WARM },
	} },
}
Sfx.LAYERS = LAYERS
Sfx.START, Sfx.MAXLEN, Sfx.EVENT_MAXLEN = START, MAXLEN, EVENT_MAXLEN
-- event -> category, base volume, base pitch, fallback (Kit.sfx name + pitch scale)
local EVENTS = {
	press_down = { "ui", 0.55, 1.0, "click" }, press_up = { "ui", 0.25, 1.25, "click" },
	hover_tick = { "ui", 0.08, 1.4, "hover" }, tab_switch = { "ui", 0.45, 1.1, "click" },
	window_open = { "ui", 0.45, 1.05, "open" }, window_close = { "ui", 0.4, 0.92, "close" },
	buy_ok = { "rewards", 0.6, 1.0, "thock" }, purchase_big = { "rewards", 0.75, 0.9, "thock" },
	cant_afford = { "ui", 0.45, 1.0, "nope" }, denied = { "ui", 0.4, 0.9, "nope" }, maxed = { "rewards", 0.7, 1.3, "thock" },
	level_up = { "rewards", 0.7, 1.2, "thock" }, collect = { "rewards", 0.35, 1.0, "click" }, coin_land = { "rewards", 0.25, 1.3, "hover" },
	toast = { "messages", 0.4, 1.15, "open" }, unlock = { "messages", 0.8, 1.0, "open" }, molt = { "messages", 0.8, 0.8, "thock" },
	error = { "messages", 0.45, 0.8, "nope" }, evolve = { "messages", 0.8, 0.7, "thock" },
	island_unlock = { "messages", 0.8, 1.0, "open" },
	collect_layer_a = { "rewards", 0.3, 1.0, "click" }, collect_layer_b = { "rewards", 0.4, 1.0, "click" }, egg_hatch_crack = { "rewards", 0.6, 1.0, "thock" }, hatch_reveal = { "rewards", 0.7, 1.2, "open" },
	-- the COMPANIONS board (pull-down map): a soft zip each way and a clack when it snaps shut
	board_roll_down = { "ui", 0.4, 0.85, "open" }, board_roll_up = { "ui", 0.4, 1.15, "close" }, board_clack = { "ui", 0.5, 0.75, "thock" },
	toggle_on = { "ui", 0.45, 1.2, "click" }, toggle_off = { "ui", 0.4, 0.9, "click" },
	slider_tick = { "ui", 0.12, 1.5, "hover" }, scroll_tick = { "ui", 0.05, 1.6, "hover" },
	row_select = { "ui", 0.3, 1.1, "click" }, dropdown_open = { "ui", 0.35, 1.05, "open" }, dropdown_close = { "ui", 0.3, 0.95, "close" },
}
Sfx.ORDER = { "press_down", "press_up", "hover_tick", "tab_switch", "window_open", "window_close", "row_select", "dropdown_open", "dropdown_close", "toggle_on", "toggle_off", "slider_tick", "scroll_tick", "board_roll_down", "board_roll_up", "board_clack", "buy_ok", "purchase_big", "cant_afford", "denied", "maxed", "level_up", "collect", "collect_layer_a", "collect_layer_b", "coin_land", "toast", "unlock", "island_unlock", "molt", "evolve", "egg_hatch_crack", "hatch_reveal", "error" }
-- volume hierarchy: UI quietest, rewards louder, big-moment messages loudest; music ducks under big moments
local CATEGORY = { ui = 0.8, rewards = 1.0, messages = 1.0, music = 0.6 }
Sfx.IDS, Sfx.EVENTS, Sfx.CATEGORY = IDS, EVENTS, CATEGORY

local groups = {}
local function group(cat)
	local g = groups[cat]
	if g and g.Parent then return g end
	g = SoundService:FindFirstChild("Peckwood" .. cat)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = "Peckwood" .. cat
		g.Volume = CATEGORY[cat] or 1
		g.Parent = SoundService
	end
	groups[cat] = g
	return g
end
-- Settings: category volumes 0..1
function Sfx.setVolume(cat, v)
	CATEGORY[cat] = v
	group(cat).Volume = v
end

local last = {}
-- one layer of a layered event: its own sound, warm EQ, trimmed length with a fade, optional delay
local function playLayer(layer, cat, speed, idOverride)
	local id = idOverride or layer.id or IDS[layer.idKey]
	if not id or id <= 0 then return end
	local function go()
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. id
		snd.Volume = layer.vol or 0.4
		snd.PlaybackSpeed = speed
		snd.TimePosition = layer.start or START[id] or 0
		snd.SoundGroup = group(cat)
		if layer.eq then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.HighGain, eq.MidGain, eq.LowGain = layer.eq[1], layer.eq[2], layer.eq[3]
			eq.Parent = snd
		end
		snd.Parent = SoundService
		snd.Ended:Once(function() if snd.Parent then snd:Destroy() end end)
		snd:Play()
		local len = (layer.len or 0.3) / math.max(0.25, speed)
		task.delay(len * 0.7, function()
			if not snd.Parent then return end
			local t = TweenService:Create(snd, TweenInfo.new(len * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 })
			t.Completed:Once(function() if snd.Parent then snd:Stop(); snd:Destroy() end end)
			t:Play()
		end)
	end
	if layer.delay and layer.delay > 0 then task.delay(layer.delay, go) else go() end
end
local function playLayered(event, pitchMul, opts)
	local L = LAYERS[event]
	local e = EVENTS[event]
	local vary = 1 + (math.random() * 2 - 1) * (L.pitchVary or 0.04)
	for i, layer in L.layers do
		local p = layer.pitch or 1
		if type(p) == "table" then p = p[1] + math.random() * (p[2] - p[1]) end
		local extra = opts and opts.layerPitch and opts.layerPitch[i] or 1
		playLayer(layer, e[1], p * vary * (pitchMul or 1) * extra, opts and opts.ids and opts.ids[i])
	end
end
Sfx.playLayered = playLayered

local function play(event, pitchMul, idOverride)
	if Kit.muted then return end
	if LAYERS[event] and not idOverride then
		local e0 = EVENTS[event]; if not e0 then return end
		local now0 = os.clock()
		if last[event] and now0 - last[event] < 0.03 then return end
		last[event] = now0
		playLayered(event, pitchMul)
		return
	end
	local e = EVENTS[event]; if not e then return end
	if (event == "hover_tick" or event == "scroll_tick") and not UIS.MouseEnabled then return end
	local now = os.clock()
	if not idOverride and last[event] and now - last[event] < (if event == "scroll_tick" then 0.07 else 0.03) then return end
	last[event] = now
	local id = idOverride or IDS[event]
	local vary = 0.95 + math.random() * 0.1   -- +-5 %
	if id and id > 0 then
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. id
		snd.Volume = e[2]
		snd.PlaybackSpeed = (pitchMul or 1) * vary
		snd.TimePosition = START[id] or 0
		snd.SoundGroup = group(e[1])
		snd.Parent = SoundService
		snd.Ended:Once(function() snd:Destroy() end)
		snd:Play()
		-- cap the length: the last quarter fades out, then it stops (long library tails never run on)
		local maxLen = EVENT_MAXLEN[event] or MAXLEN[e[1]] or 0
		if maxLen > 0 then
			task.delay(maxLen * 0.75, function()
				if not snd.Parent then return end
				local t = TweenService:Create(snd, TweenInfo.new(maxLen * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 })
				t.Completed:Once(function() if snd.Parent then snd:Stop(); snd:Destroy() end end)
				t:Play()
			end)
		end
	else
		Kit.sfx(e[4])
	end
end
Sfx.play = play
-- audition a candidate id through the real path (category, volume, pitch rules); apply a pick live
function Sfx.audition(event, id)
	for ev, L in LAYERS do
		for i, layer in L.layers do
			if layer.idKey == event then
				local ids = {}
				ids[i] = id
				playLayered(ev, 1, { ids = ids })
				return
			end
		end
	end
	play(event, 1, id)
end
function Sfx.setId(event, id) if EVENTS[event] then IDS[event] = id end end
-- the IDS table as Luau source (Sound Board "COPY TABLE")
function Sfx.dump()
	local lines = { "local IDS = {" }
	for _, ev in Sfx.ORDER do table.insert(lines, string.format("\t%s = %d,", ev, IDS[ev] or 0)) end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

-- keycap: down + up (every key press calls these)
function Sfx.press() play("press_down") end
function Sfx.release() play("press_up") end
function Sfx.hover() play("hover_tick") end
function Sfx.tab() play("tab_switch") end
function Sfx.open() play("window_open") end
function Sfx.close() play("window_close") end
function Sfx.buy() play("buy_ok") end
function Sfx.deny() play("cant_afford") end
function Sfx.denied() play("denied") end
function Sfx.purchaseBig() play("purchase_big") end
function Sfx.rowSelect() play("row_select") end
function Sfx.dropdown(open) play(if open then "dropdown_open" else "dropdown_close") end
function Sfx.toggle(on) play(if on then "toggle_on" else "toggle_off") end
function Sfx.sliderTick() play("slider_tick") end
function Sfx.scrollTick() play("scroll_tick") end
function Sfx.board(kind) play("board_" .. kind) end   -- roll_down / roll_up / clack
function Sfx.islandUnlock() play("island_unlock"); Sfx.duck(2.4) end
function Sfx.hatchCrack() play("egg_hatch_crack") end
function Sfx.hatchReveal() play("hatch_reveal") end
function Sfx.maxed() play("maxed") end
function Sfx.levelUp() play("level_up") end
function Sfx.toast() play("toast") end
function Sfx.unlock() play("unlock"); Sfx.duck(2.2) end
function Sfx.molt() play("molt"); Sfx.duck(1.6) end
function Sfx.evolve() play("evolve"); Sfx.duck(2.0) end
function Sfx.error() play("error") end

-- collect: pitch climbs with quick successive collects, resets after 1 s
local streak, streakAt = 0, 0
function Sfx.collect(golden)
	if Kit.muted then return end
	local now = os.clock()
	streak = if now - streakAt < 1 then math.min(streak + 1, 12) else 0
	streakAt = now
	if golden then
		playLayered("collect", 1 + streak * 0.04, { layerPitch = { 1, 1.12 } })
		playLayer({ id = IDS.buy_ok, start = 0, len = 0.25, vol = 0.12, delay = 0.02, eq = WARM }, "rewards", 1.05)
	else
		play("collect", 1 + streak * 0.04)
	end
end
-- coin_land: the i-th icon of a fly-in sequence lands a little higher
function Sfx.coinLand(i) play("coin_land", 1 + (i or 0) * 0.06) end

-- music duck under big moments (any Sound in the Peckwoodmusic group)
local duckTween
function Sfx.duck(seconds)
	local g = group("music")
	if duckTween then duckTween:Cancel() end
	g.Volume = CATEGORY.music * 0.35
	duckTween = TweenService:Create(g, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds or 1.5), { Volume = CATEGORY.music })
	duckTween:Play()
end

-- dev Sound Board picks: saved by the server in a dev DataStore key and sent back as a player attribute (JSON
-- { event = id }); applied live, so every caller plays the picked sound at once
task.spawn(function()
	local plr = game:GetService("Players").LocalPlayer
	if not plr then return end
	local function apply()
		local raw = plr:GetAttribute("PeckwoodSfxPicks")
		if typeof(raw) ~= "string" or raw == "" then return end
		local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
		if ok and type(t) == "table" then
			for ev, id in t do if EVENTS[ev] and tonumber(id) then IDS[ev] = tonumber(id) end end
		end
	end
	apply()
	plr:GetAttributeChangedSignal("PeckwoodSfxPicks"):Connect(apply)
end)

-- preload every chosen id at startup so the first press is never silent
task.spawn(function()
	local list = {}
	for _, id in IDS do if id > 0 then table.insert(list, "rbxassetid://" .. id) end end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)

return Sfx
