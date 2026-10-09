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

-- placeholder ids: put rbxassetid numbers here (0 = keyboard-slice fallback)
local IDS = {
	press_down = 0, press_up = 0,                    -- the buttery keycap (two-part: thock down, softer click up)
	hover_tick = 0, tab_switch = 0, window_open = 0, window_close = 0,
	buy_ok = 0, cant_afford = 0, maxed = 0,
	level_up = 0, collect = 0, coin_land = 0,
	toast = 0, unlock = 0, molt = 0, error = 0, evolve = 0,
}
-- event -> category, base volume, base pitch, fallback (Kit.sfx name + pitch scale)
local EVENTS = {
	press_down = { "ui", 0.55, 1.0, "click" }, press_up = { "ui", 0.25, 1.25, "click" },
	hover_tick = { "ui", 0.08, 1.4, "hover" }, tab_switch = { "ui", 0.45, 1.1, "click" },
	window_open = { "ui", 0.45, 1.05, "open" }, window_close = { "ui", 0.4, 0.92, "close" },
	buy_ok = { "rewards", 0.6, 1.0, "thock" }, cant_afford = { "ui", 0.45, 1.0, "nope" }, maxed = { "rewards", 0.7, 1.3, "thock" },
	level_up = { "rewards", 0.7, 1.2, "thock" }, collect = { "rewards", 0.35, 1.0, "click" }, coin_land = { "rewards", 0.25, 1.3, "hover" },
	toast = { "messages", 0.4, 1.15, "open" }, unlock = { "messages", 0.8, 1.0, "open" }, molt = { "messages", 0.8, 0.8, "thock" },
	error = { "messages", 0.45, 0.8, "nope" }, evolve = { "messages", 0.8, 0.7, "thock" },
}
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
local function play(event, pitchMul)
	if Kit.muted then return end
	local e = EVENTS[event]; if not e then return end
	if event == "hover_tick" and not UIS.MouseEnabled then return end
	local now = os.clock()
	if last[event] and now - last[event] < 0.03 then return end
	last[event] = now
	local id = IDS[event]
	local pitch = e[3] * (pitchMul or 1) * (0.95 + math.random() * 0.1)   -- +-5 %
	if id and id > 0 then
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. id
		snd.Volume = e[2]
		snd.PlaybackSpeed = pitch
		snd.SoundGroup = group(e[1])
		snd.Parent = SoundService
		snd.Ended:Once(function() snd:Destroy() end)
		snd:Play()
	else
		Kit.sfx(e[4])
	end
end
Sfx.play = play

-- keycap: down + up (every key press calls these)
function Sfx.press() play("press_down") end
function Sfx.release() play("press_up") end
function Sfx.hover() play("hover_tick") end
function Sfx.tab() play("tab_switch") end
function Sfx.open() play("window_open") end
function Sfx.close() play("window_close") end
function Sfx.buy() play("buy_ok") end
function Sfx.deny() play("cant_afford") end
function Sfx.maxed() play("maxed") end
function Sfx.levelUp() play("level_up") end
function Sfx.toast() play("toast") end
function Sfx.unlock() play("unlock"); Sfx.duck(2.2) end
function Sfx.molt() play("molt"); Sfx.duck(1.6) end
function Sfx.evolve() play("evolve"); Sfx.duck(2.0) end
function Sfx.error() play("error") end

-- collect: pitch climbs with quick successive collects, resets after 1 s
local streak, streakAt = 0, 0
function Sfx.collect()
	local now = os.clock()
	streak = if now - streakAt < 1 then math.min(streak + 1, 12) else 0
	streakAt = now
	play("collect", 1 + streak * 0.04)
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

return Sfx
