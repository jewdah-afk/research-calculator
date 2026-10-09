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

-- placeholder ids: put rbxassetid numbers here (0 = keyboard-slice fallback). The dev Sound Board (UI/SoundBoard)
-- auditions candidates through play() and applies picks live with Sfx.setId; its COPY TABLE prints this table.
local IDS = {
	press_down = 0, press_up = 0,                    -- the buttery keycap (two-part: thock down, softer click up)
	hover_tick = 0, tab_switch = 0, window_open = 0, window_close = 0,
	buy_ok = 0, purchase_big = 0, cant_afford = 0, denied = 0, maxed = 0,
	level_up = 0, collect = 0, coin_land = 0,
	toast = 0, unlock = 0, molt = 0, error = 0, evolve = 0,
	board_roll_down = 0, board_roll_up = 0, board_clack = 0,
	toggle_on = 0, toggle_off = 0, slider_tick = 0, scroll_tick = 0,
	row_select = 0, dropdown_open = 0, dropdown_close = 0,
}
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
	-- the COMPANIONS board (pull-down map): a soft zip each way and a clack when it snaps shut
	board_roll_down = { "ui", 0.4, 0.85, "open" }, board_roll_up = { "ui", 0.4, 1.15, "close" }, board_clack = { "ui", 0.5, 0.75, "thock" },
	toggle_on = { "ui", 0.45, 1.2, "click" }, toggle_off = { "ui", 0.4, 0.9, "click" },
	slider_tick = { "ui", 0.12, 1.5, "hover" }, scroll_tick = { "ui", 0.05, 1.6, "hover" },
	row_select = { "ui", 0.3, 1.1, "click" }, dropdown_open = { "ui", 0.35, 1.05, "open" }, dropdown_close = { "ui", 0.3, 0.95, "close" },
}
Sfx.ORDER = { "press_down", "press_up", "hover_tick", "tab_switch", "window_open", "window_close", "row_select", "dropdown_open", "dropdown_close",
	"toggle_on", "toggle_off", "slider_tick", "scroll_tick", "board_roll_down", "board_roll_up", "board_clack", "buy_ok", "purchase_big", "cant_afford",
	"denied", "maxed", "level_up", "collect", "coin_land", "toast", "unlock", "molt", "evolve", "error" }
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
local function play(event, pitchMul, idOverride)
	if Kit.muted then return end
	local e = EVENTS[event]; if not e then return end
	if (event == "hover_tick" or event == "scroll_tick") and not UIS.MouseEnabled then return end
	local now = os.clock()
	if not idOverride and last[event] and now - last[event] < (if event == "scroll_tick" then 0.07 else 0.03) then return end
	last[event] = now
	local id = idOverride or IDS[event]
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
-- audition a candidate id through the real path (category, volume, pitch rules); apply a pick live
function Sfx.audition(event, id) play(event, 1, id) end
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

return Sfx
