--!nocheck
--[[
	Core/Audio on the mock engine (tests/mock.luau + tests/engine.luau, whose AudioPlayer / Sound log every Play):
	the bus graph, voice pools within 32 (PC) / 16 (phone) voices, per-cue cooldowns, rate caps and voice caps (hover
	never stacks), variants without immediate repeats, the buy combo ladder, bus volumes from Prefs (live), silence
	with nil asset ids, the Sound fallback and the no-audio path, loops, the first-prestige decision, and the cues read
	from the view (a purchase seen in the next patch, a layer that woke).

	Run from port/: python3 tools/wrap_scripts.py && luau tests/unit/audio.luau
]]
local M = require("../mock")
local E = require("../engine")(M)

local failures, checks = 0, 0
local function check(ok, what)
	checks += 1
	if ok then print("  ok    " .. what) else failures += 1; print("  FAIL  " .. what) end
end

local game = M.game
local SoundService = game:GetService("SoundService")
local client = E.buildClient()
local Audio = M.require(client.Core.Audio)
local Prefs = M.require(client.Core.Prefs)
local IDS = M.require(game:GetService("ReplicatedStorage").MilestoneTree.AudioIds)
local errors0 = M.errors or 0

local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep(v) end
	return o
end
-- the real map with every sheet id set (whatever moderation says today)
local function withIds()
	local t = deep(IDS)
	for k, s in t.sheets do s.id = "rbxassetid://" .. (1000 + #k); s.review = nil end
	return t
end
local function withoutIds()
	local t = deep(IDS)
	for _, s in t.sheets do s.id = nil; s.review = nil end
	return t
end
local function fresh(o)
	Audio.reset()
	E.audio.plays = {}
	M.now += 10
	Audio.start(o)
	Audio.setLive(true)
end
local function advance(s) M.now += s end
local function plays(class)
	local n = 0
	for _, p in E.audio.plays do if class == nil or p.class == class then n += 1 end end
	return n
end

-- ------------------------------------------------------------------------------------------------------ the graph
print("== the graph (Audio API)")
fresh({ ids = withIds(), seed = 3, phone = false })
check(Audio.mode == "api", "the wired Audio API is used when the engine has it (" .. Audio.mode .. ")")
local root = SoundService:FindFirstChild("MT_Audio")
check(root ~= nil, "the graph lives in SoundService.MT_Audio")
for _, n in { "Output", "Limiter", "Master", "UI", "Impacts", "Ambience", "Music", "Duck", "UiKey" } do
	check(root and root:FindFirstChild(n) ~= nil, "node " .. n)
end
local function wiresFrom(name)
	local out = {}
	for _, w in root[name]:GetChildren() do
		if w.__class == "Wire" then table.insert(out, w) end
	end
	return out
end
local sideImpacts, sideUi = false, false
for _, w in wiresFrom("Impacts") do if w.TargetInstance == root.Duck and w.TargetName == "Sidechain" then sideImpacts = true end end
for _, w in wiresFrom("UiKey") do if w.TargetInstance == root.Duck and w.TargetName == "Sidechain" then sideUi = true end end
check(sideImpacts and sideUi, "Impacts and the UI key feed the duck's Sidechain pin")
local ambToDuck = false
for _, w in wiresFrom("Ambience") do if w.TargetInstance == root.Duck and w.TargetName == nil then ambToDuck = true end end
check(ambToDuck, "the Ambience bus runs through the duck")
check(root.Limiter.MaxLevel == -1, "the master limiter sits at -1 dB")
local st = Audio.stats()
check(st.voices.ui == 24 and st.voices.fx == 6, "PC pools: 24 UI + 6 impact voices")
Audio.loop("portal_loop", 1)
Audio.loop("ambience", 1)
for _ = 1, 30 do Audio.step(0.05); advance(0.05) end
st = Audio.stats()
check(st.total <= 32, "PC: at most 32 voices with both loops (" .. st.total .. ")")

-- ------------------------------------------------------------------------------------------------------ gating
print("== gating, cooldowns and caps")
fresh({ ids = withIds(), seed = 3 })
Audio.setLive(false)
check(not Audio.play("press"), "nothing plays before the realm is live (boot)")
Audio.setLive(true)
check(Audio.play("hover"), "hover plays")
check(not Audio.play("hover"), "hover again at once: the cooldown drops it")
advance(0.08)
check(Audio.play("hover"), "hover after its cooldown plays")
advance(0.08)
check(not Audio.play("hover"), "a third overlapping hover is dropped (hover never stacks: 2 voices)")
check(Audio.playing("hover") == 2, "two hover voices at most (" .. Audio.playing("hover") .. ")")
advance(0.5)
-- hover spam: a pointer sweeping across cards for 2 s (a MouseEnter every 20 ms)
local ok, most = 0, 0
for _ = 1, 100 do
	if Audio.play("hover") then ok += 1 end
	most = math.max(most, Audio.playing("hover"))
	advance(0.02)
end
check(most <= 2, "hover spam stays within 2 voices (" .. most .. ")")
check(ok <= 14, "hover spam: at most 7 a second get through (" .. ok .. " in 2 s)")
-- press rate cap: 12 a second
advance(1)
ok = 0
for _ = 1, 40 do
	if Audio.play("press") then ok += 1 end
	advance(0.025)
end
check(ok <= 12, "press: at most 12 in any second (" .. ok .. " in 1 s)")
check(Audio.playing("press") <= 3, "press: at most 3 voices")
-- the pool never grows: a burst of everything
advance(1)
for _ = 1, 60 do
	for _, n in { "press", "tab", "buy", "toast", "error", "panel_open", "panel_close", "unlock", "prestige_small" } do Audio.play(n) end
	advance(0.03)
end
st = Audio.stats()
check(st.busy.ui <= 24 and st.busy.fx <= 6, "a burst never exceeds the pools (ui " .. st.busy.ui .. ", fx " .. st.busy.fx .. ")")

-- ------------------------------------------------------------------------------------------------------ variants
print("== variants")
fresh({ ids = withIds(), seed = 11 })
local seen, repeats, last = {}, 0, nil
for _ = 1, 60 do
	if Audio.play("hover") then
		local v = Audio.last.variant
		if v == last then repeats += 1 end
		seen[v] = true
		last = v
	end
	advance(0.3)
end
local nSeen = 0
for _ in seen do nSeen += 1 end
check(repeats == 0, "hover never repeats a variant twice in a row")
check(nSeen == #IDS.sounds.hover.regions, "every hover variant comes up (" .. nSeen .. ")")
local speeds = {}
for _, p in E.audio.plays do if p.speed then speeds[p.speed] = true end end
local nSpeeds = 0
local worst = 0
for s in speeds do
	nSpeeds += 1
	worst = math.max(worst, math.abs(s - 1))
end
check(worst <= 0.0061, "hover pitch jitter stays within 10 cents (" .. string.format("%.4f", worst) .. ")")
check(nSpeeds > 1, "the pitch varies from play to play")
-- the buy ladder: buys in quick succession climb, a pause starts again
local ladder = {}
for _ = 1, 6 do
	if Audio.play("buy") then table.insert(ladder, Audio.last.variant) end
	advance(0.2)
end
check(table.concat(ladder, ",") == "1,2,3,4,3,4", "the buy combo climbs its variants (" .. table.concat(ladder, ",") .. ")")
advance(1)
Audio.play("buy")
check(Audio.last.variant == 1, "after a pause the ladder starts again")
-- regions come from AudioIds
local p = E.audio.plays[#E.audio.plays]
local r = IDS.sounds.buy.regions[1]
check(p.region and math.abs(p.region.Min - r[1]) < 1e-9 and math.abs(p.region.Max - (r[1] + r[2])) < 1e-9, "a cue plays its PlaybackRegion")

-- ------------------------------------------------------------------------------------------------------ volumes
print("== volumes from Prefs")
fresh({ ids = withIds() })
root = SoundService:FindFirstChild("MT_Audio")
Prefs.set("sfx", 50)
check(math.abs(Audio.volumes.UI - 0.25) < 1e-9 and math.abs(root.UI.Volume - 0.25) < 1e-9, "sfx 50 -> UI fader .25 (perceptual curve), live")
check(math.abs(root.UI.Volume - 0.25) < 1e-9 and math.abs(root.Impacts.Volume - 0.25) < 1e-9, "the UI and Impacts faders follow sfx")
Prefs.set("ambience", 0)
check(root.Ambience.Volume == 0, "ambience 0 mutes the Ambience bus")
Prefs.set("music", 100)
check(math.abs(root.Music.Volume - Audio.BASE.Music) < 1e-9, "music 100 -> the Music bus at its base level")
Prefs.set("sfx", 70)
Prefs.set("ambience", 60)
Prefs.set("music", 60)

-- ------------------------------------------------------------------------------------------------------ nil ids
print("== nil ids: silent")
fresh({ ids = withoutIds() })
check(Audio.mode == "api", "the graph still builds")
local any = false
for _, n in { "hover", "press", "tab", "buy", "toast", "error", "panel_open", "panel_close", "unlock", "prestige_small", "prestige_big" } do
	if Audio.play(n) then any = true end
	advance(0.5)
end
Audio.loop("ambience", 1)
Audio.loop("portal_loop", 1)
for _ = 1, 20 do Audio.step(0.1); advance(0.1) end
check(not any and plays() == 0, "no cue and no loop plays without ids")
check(Audio.stats().total == 0, "no voice is made without ids")
fresh({ ids = {} })
check(not Audio.play("press") and not Audio.prestige("m", true), "a broken AudioIds table is silent too")

-- ------------------------------------------------------------------------------------------------------ fallbacks
print("== fallbacks")
fresh({ ids = withIds(), force = "sound" })
check(Audio.mode == "sound", "forced: the legacy Sound fallback")
root = SoundService:FindFirstChild("MT_Audio")
check(root and root:FindFirstChild("Master") and root.Master:FindFirstChild("UI") and root.Master.UI.__class == "SoundGroup", "SoundGroups Master > UI ...")
check(root.Master.Ambience:FindFirstChild("Duck") and root.Master.Ambience.Duck.SideChain == root.Master.Impacts, "the Ambience group ducks under Impacts")
check(Audio.play("press") and plays("Sound") == 1, "a cue plays on a Sound")
check(E.audio.plays[1].region ~= nil, "the Sound plays its region")
Audio.loop("ambience", 1)
for _ = 1, 10 do Audio.step(0.1); advance(0.1) end
check(plays("Sound") == 2 and E.audio.plays[2].loop ~= nil, "the ambience loops on a Sound (LoopRegion)")
E.audio.api = false
fresh({ ids = withIds() })
check(Audio.mode == "sound", "no Audio API in the engine: the Sound fallback")
E.audio.sound = false
fresh({ ids = withIds() })
check(Audio.mode == "off" and not Audio.play("press"), "no audio at all: off and silent")
Audio.loop("ambience", 1)
Audio.step(0.1)
check(SoundService:FindFirstChild("MT_Audio") == nil, "off leaves nothing behind")
E.audio.api, E.audio.sound = true, true

-- ------------------------------------------------------------------------------------------------------ phone
print("== phone budget")
fresh({ ids = withIds(), phone = true })
Audio.loop("portal_loop", 1)
Audio.loop("ambience", 1)
for _ = 1, 30 do Audio.step(0.05); advance(0.05) end
for _ = 1, 40 do
	for _, n in { "press", "tab", "buy", "toast", "unlock", "prestige_small" } do Audio.play(n) end
	advance(0.03)
end
st = Audio.stats()
check(st.total <= 16, "phone: at most 16 voices with both loops (" .. st.total .. ")")

-- ------------------------------------------------------------------------------------------------------ loops
print("== loops")
fresh({ ids = withIds() })
Audio.loop("portal_loop", 1)
Audio.step(0.1)
local lp = E.audio.plays[#E.audio.plays]
local pr = IDS.sounds.portal_loop.regions[1]
check(lp and lp.loop and math.abs(lp.loop.Min - pr[1]) < 1e-9 and math.abs(lp.loop.Max - (pr[1] + pr[2])) < 1e-9, "the portal loop plays its one-period LoopRegion")
for _ = 1, 20 do Audio.step(0.1) end
check(math.abs(Audio.loopLevel("portal_loop") - 1) < 1e-9, "it fades in to full")
Audio.loop("portal_loop", 0)
local stops0 = E.audio.stops
for _ = 1, 20 do Audio.step(0.1) end
check(Audio.loopLevel("portal_loop") == 0 and E.audio.stops > stops0, "it fades out and stops")
Audio.loop("portal_loop", 0 / 0)
Audio.step(0.1)
check(Audio.loopLevel("portal_loop") == 0, "a NaN level is treated as 0")

-- ------------------------------------------------------------------------------------------------------ prestige
print("== the first prestige")
fresh({ ids = withIds() })
check(not Prefs.seen("hp"), "hp has not prestiged yet")
Audio.prestige("hp")
check(Audio.last and Audio.last.name == "prestige_big", "the first prestige of a layer is the big one")
check(Prefs.seen("hp"), "and it is remembered (Prefs.seenPrestige)")
advance(2)
Audio.prestige("hp")
check(Audio.last.name == "prestige_small", "the next one is small")
advance(2)
check(Prefs.claimFirstPrestige("ep") == true and Prefs.claimFirstPrestige("ep") == false, "claimFirstPrestige answers true once")
Audio.prestige("ep", true)
check(Audio.last.name == "prestige_big", "a caller can hand over the decision it already made")

-- ------------------------------------------------------------------------------------------------------ view cues
print("== cues from the view")
fresh({ ids = withIds() })
local store = { tab = "p", nodes = {
	["tab.3.1"] = { t = "btn", k = "upg", cls = "can", a = { "upg", "p", 11 } },
	["tab.3.2"] = { t = "btn", k = "buy", cls = "can", lv = "3", a = { "buy", "p", 11 } },
	["tab.3.3"] = { t = "btn", k = "upg", cls = "can", a = { "upg", "p", 12 } },
} }
function store.get(s, id) return s.nodes[id] end
local buyStarts = {}
for _, r in IDS.sounds.buy.regions do buyStarts[r[1]] = true end
local function nBuys()
	local n = 0
	for _, p in E.audio.plays do if p.region and buyStarts[p.region.Min] then n += 1 end end
	return n
end
Audio.expectBuy({ "upg", "p", 11 }, store)
check(Audio.pendingBuys() == 1, "a sent purchase is remembered, not played")
check(nBuys() == 0, "no buy sound on the click")
Audio.afterPatch(store)
check(nBuys() == 0, "a patch that did not change the button: no buy sound")
store.nodes["tab.3.1"] = { t = "btn", k = "upg", cls = "bought", a = { "upg", "p", 11 } }
advance(0.1)
check(Audio.afterPatch(store) == 1 and nBuys() == 1, "the button turned bought in a later patch: buy plays")
-- a buyable: its level moved
Audio.expectBuy({ "buy", "p", 11 }, store)
store.nodes["tab.3.2"] = { t = "btn", k = "buy", cls = "can", lv = "4", a = { "buy", "p", 11 } }
advance(0.1)
check(Audio.afterPatch(store) == 1, "a buyable whose level rose was bought")
-- automation: a button that changes with no purchase sent stays quiet
store.nodes["tab.3.3"] = { t = "btn", k = "upg", cls = "bought", a = { "upg", "p", 12 } }
check(Audio.afterPatch(store) == 0, "an upgrade bought by automation plays nothing")
-- a purchase the server refused: nothing, and it is forgotten after 2 s
store.nodes["tab.3.3"] = { t = "btn", k = "upg", cls = "can", a = { "upg", "p", 12 } }
Audio.expectBuy({ "upg", "p", 12 }, store)
advance(2.5)
store.nodes["tab.3.3"] = { t = "btn", k = "upg", cls = "bought", a = { "upg", "p", 12 } }
check(Audio.afterPatch(store) == 0 and Audio.pendingBuys() == 0, "a purchase not seen within 2 s is dropped")
-- a locked button is not a purchase; a non-buy action is ignored
store.nodes["tab.3.3"] = { t = "btn", k = "upg", cls = "locked", a = { "upg", "p", 12 } }
Audio.expectBuy({ "upg", "p", 12 }, store)
Audio.expectBuy({ "tab", "p" }, store)
check(Audio.pendingBuys() == 0, "locked buttons and other actions are not remembered")
-- the panel moved to another layer: the pending purchase is dropped
store.nodes["tab.3.3"] = { t = "btn", k = "upg", cls = "can", a = { "upg", "p", 12 } }
Audio.expectBuy({ "upg", "p", 12 }, store)
store.tab = "m"
store.nodes["tab.3.3"] = nil
check(Audio.afterPatch(store) == 0, "a button gone with the tab is not a purchase")

-- layers that wake
local function ms(inside, lit)
	local nodes = {}
	for l, on in lit do nodes[l] = { show = on ~= "hidden", val = { lit = on == true } } end
	return { ok = true, inside = inside, nodes = nodes }
end
check(#Audio.observeMap(ms(false, { m = true, p = false, sp = "hidden" })) == 0, "the first map only sets the baseline")
local woke = Audio.observeMap(ms(false, { m = true, p = true, sp = "hidden" }))
check(#woke == 1 and woke[1] == "p", "p unlocked: it woke")
check(Audio.last and Audio.last.name == "unlock", "and unlock plays")
advance(1)
check(#Audio.observeMap(ms(true, { m = false, p = false, sp = true, pm = true })) == 0, "crossing the universe resets the baseline (no unlock)")
check(#Audio.observeMap(ms(true, { m = false, p = false, sp = true, pm = true, cp = true })) == 1, "then a new layer wakes again")
check(#Audio.observeMap({ ok = false }) == 0, "a map that is not ready is ignored")

-- the click of a view button
advance(1)
Audio.pressFor({ cls = "locked" })
check(Audio.last.name == "error", "a locked button answers with the soft error")
advance(1)
Audio.pressFor({ cls = "can" })
check(Audio.last.name == "press", "any other button clicks")

check((M.errors or 0) == errors0, "no script errors")
print(string.format("audio: %d checks, %d failed", checks, failures))
if failures > 0 then error("audio: " .. failures .. " FAILED", 0) end
