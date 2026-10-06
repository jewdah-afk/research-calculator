--!nonstrict
-- The Rune Altar's in-world UI (client-only, nothing replicated):
--   * a floating rune crystal above the pedestal
--   * three panels around it, like a shop display:
--       left   ATTRIBUTES (luck, bulk, speed, clone, tickrate) + STATISTICS (opened, rolls, pad time, ...)
--       centre [EVOLUTION] STARTER RUNE + every rune with its odds at your current luck
--       right  LAST DROP + MILESTONES + PAD TIME progress
--   * panels fade in when you walk onto the pad and fade out when you leave
--   * every opening: crystal flashes the best rune's colour and spins, a shockwave ring rolls
--     out, the rune's name floats up; Echo or rarer also fires a light beam into the sky

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Runes = require(Shared.Runes)
local Unlocks = require(Shared.Unlocks)
local F = require(Shared.OrbFormulas)

local AltarUI = {}

local SHOW_DISTANCE = 26
local FONT = Enum.Font.FredokaOne
local PURPLE_EDGE = Color3.fromRGB(227, 166, 255)
-- one colour per stat, everywhere (see docs/UI_STYLE.md "Stat colours")
local SC = {
	luck = Color3.fromRGB(76, 240, 90), bulk = Color3.fromRGB(255, 72, 72), speed = Color3.fromRGB(58, 168, 255),
	clone = Color3.fromRGB(255, 216, 74), tick = Color3.fromRGB(196, 125, 255), opened = Color3.fromRGB(92, 242, 255),
	found = Color3.fromRGB(255, 138, 61), pad = Color3.fromRGB(255, 177, 58), milestone = Color3.fromRGB(255, 92, 170),
}

local folder, center, crystal, light
local panels = {} -- { group = CanvasGroup, ... }
local labels = {} -- named TextLabels we refresh
local visible = 0
local kick = 0
local data
local lastDrop

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function label(parent, name, size, color, order)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -16, 0, size + 8)
	t.Font = FONT
	t.TextSize = size
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.RichText = true
	t.Text = ""
	t.LayoutOrder = order
	t.Parent = parent
	labels[name] = t
	return t
end

local function box(parent, title, height, order)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(18, 6, 26)
	f.BackgroundTransparency = 0.08
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = f
	local inner = Instance.new("UIStroke")
	inner.Thickness = 1
	inner.Color = PURPLE_EDGE
	inner.Transparency = 0.6
	inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 10, 48), Color3.fromRGB(10, 4, 18))
	grad.Rotation = 90
	grad.Parent = f
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = f
	if title then
		label(f, title .. "_title", 30, Color3.new(1, 1, 1), 0).Text = title
	end
	return f
end

-- a world panel: transparent part + SurfaceGui + CanvasGroup (so it can fade as one)
local function worldPanel(name, size, cf, pxPerStud)
	local p = part({ Name = name, Size = Vector3.new(size.X, size.Y, 0.2), CFrame = cf, Transparency = 1 })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = pxPerStud
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Parent = p
	local g = Instance.new("CanvasGroup")
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromScale(1, 1)
	g.GroupTransparency = 1
	g.Parent = sg
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = g
	table.insert(panels, g)
	return g
end

---------------------------------------------------------------- build

function AltarUI.init(world: Instance)
	local pos = Unlocks.byId.runes.pos
	center = Vector3.new(pos[1], 0, pos[2])
	folder = Instance.new("Folder")
	folder.Name = "RuneAltarUI"
	folder.Parent = workspace
	-- panels stand behind the altar and each one turns to face a player standing in front of it
	-- (front = towards the plaza centre)
	local base = CFrame.lookAt(center, Vector3.new(0, 0, center.Z + 60))
	local viewer = (base * CFrame.new(0, 14, -40)).Position
	-- viewer's left is the altar's local +X (the viewer faces the other way)
	local function at(x, y, z)
		local p = (base * CFrame.new(x, y, z)).Position
		return CFrame.lookAt(p, Vector3.new(viewer.X, p.Y, viewer.Z))
	end

	crystal = part({ Name = "Crystal", Size = Vector3.new(4, 4, 4), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, CFrame = CFrame.new(center + Vector3.new(0, 11, 0)) })
	light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 18, 2, crystal.Color
	light.Parent = crystal

	-- left: attributes + statistics
	local left = worldPanel("Left", Vector2.new(18, 26), at(25, 25, 2), 24)
	local attr = box(left, "ATTRIBUTES", 250, 1)
	for i, n in { "a_luck", "a_bulk", "a_speed", "a_clone", "a_tick", "a_auto" } do
		label(attr, n, 22, Color3.new(1, 1, 1), i)
	end
	local stats = box(left, "STATISTICS", 340, 2)
	for i, n in { "s_opened", "s_rolls", "s_padlbl", "s_pad", "s_disc", "s_ms", "s_evo" } do
		label(stats, n, n == "s_pad" and 34 or 22, Color3.new(1, 1, 1), i)
	end

	-- centre: title + odds
	local mid = worldPanel("Centre", Vector2.new(26, 30), at(0, 30, 6), 22)
	local odds = box(mid, nil, 640, 1)
	label(odds, "c_evo", 28, PURPLE_EDGE, 1)
	label(odds, "c_title", 60, Color3.fromRGB(120, 220, 255), 2).Text = "STARTER"
	label(odds, "c_title2", 76, Color3.new(1, 1, 1), 3).Text = "RUNE"
	label(odds, "c_bulk", 30, Color3.fromRGB(255, 214, 74), 4)
	for i = 1, #Runes.LIST do
		label(odds, "c_rune" .. i, 28, Color3.new(1, 1, 1), 10 + i)
	end

	-- right: last drop + milestones + pad time
	local right = worldPanel("Right", Vector2.new(18, 26), at(-25, 25, 2), 24)
	local drop = box(right, "LAST DROP", 120, 1)
	label(drop, "d_name", 30, Color3.new(1, 1, 1), 1)
	local ms = box(right, "MILESTONES", 250, 2)
	for i = 1, 4 do
		label(ms, "m_" .. i, 20, Color3.new(1, 1, 1), i)
	end
	local pt = box(right, "PAD TIME", 200, 3)
	label(pt, "p_next", 26, Color3.fromRGB(255, 214, 74), 1)
	label(pt, "p_at", 20, Color3.fromRGB(185, 176, 216), 2)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0.85, 0, 0, 18)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.LayoutOrder = 3
	bar.Parent = pt
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(92, 242, 255)
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	labels.p_fill = fill
	label(pt, "p_count", 22, Color3.fromRGB(124, 255, 91), 4)

	RunService.Heartbeat:Connect(AltarUI._step)
end

---------------------------------------------------------------- refresh (on every state push + once a second for the timer)

local function short(n)
	return F.format(n)
end

function AltarUI.refresh(d)
	data = d
	if not (folder and d and d.runes) then
		return
	end
	local sess = d._session or {}
	local st = Runes.stats(d, sess.hasPass)
	local s = d.runes
	local L = labels
	L.a_luck.Text = string.format("x%.2f RUNE LUCK", st.luck)
	L.a_luck.TextColor3 = SC.luck
	L.a_bulk.Text = "x" .. short(st.bulk) .. " RUNE BULK"
	L.a_bulk.TextColor3 = SC.bulk
	L.a_speed.Text = string.format("x%.2f RUNE SPEED", st.rate / Runes.BASE_RATE)
	L.a_speed.TextColor3 = SC.speed
	L.a_clone.Text = string.format("%d%% CLONE · +%d COPIES", math.floor(st.clone * 100 + 0.5), st.cloneAmount)
	L.a_clone.TextColor3 = SC.clone
	L.a_tick.Text = string.format("x%.2f TICKRATE", st.tickrate)
	L.a_tick.TextColor3 = SC.tick
	L.a_auto.Text = sess.hasPass and "AUTO-ROLL x2 (PASS)" or (sess.onPad and "AUTO-ROLL ON PAD" or "STEP ON THE PAD")
	L.a_auto.TextColor3 = PURPLE_EDGE

	local found = 0
	for i = 1, #Runes.LIST do
		if (s.counts[i] or 0) > 0 then
			found += 1
		end
	end
	L.s_opened.Text = short(s.opened) .. " OPENED"
	L.s_rolls.Text = short(s.rolls) .. " ROLLS"
	L.s_opened.TextColor3, L.s_rolls.TextColor3 = SC.opened, SC.opened
	L.s_padlbl.Text = "PAD TIME"
	L.s_disc.Text = found .. "/" .. #Runes.LIST .. " DISCOVERED"
	L.s_disc.TextColor3 = SC.found
	L.s_ms.Text = st.openMilestones .. " OPENING · " .. st.ballMilestones .. " ORB MILESTONES"
	L.s_ms.TextColor3 = SC.milestone
	L.s_evo.Text = "EVOLUTION: " .. string.upper(Runes.evolution(st.openMilestones))
	L.s_evo.TextColor3 = Color3.fromRGB(255, 79, 122)

	L.c_evo.Text = "[" .. string.upper(Runes.evolution(st.openMilestones)) .. "]"
	L.c_bulk.Text = string.format("%s BULK · %.2f/s", short(st.bulk), st.rate)
	for i, r in Runes.LIST do
		local p = math.min(1, st.luck / r.oneIn)
		local odds = if i == 1 then "BASE" elseif p >= 0.01 then string.format(p >= 0.1 and "%.1f%%" or "%.2f%%", p * 100) else "1/" .. short(1 / p)
		local got = (s.counts[i] or 0) > 0
		L["c_rune" .. i].Text = (got and string.upper(r.name) or "???") .. " | " .. odds
		L["c_rune" .. i].TextColor3 = got and rgb(r.color) or Color3.fromRGB(138, 128, 152)
	end

	if lastDrop then
		local r = Runes.LIST[lastDrop]
		L.d_name.Text = "◆ " .. string.upper(r.name)
		L.d_name.TextColor3 = rgb(r.color)
	else
		L.d_name.Text = "-"
	end
	for k = 1, 4 do
		local n = st.openMilestones + k - 1
		local done = k == 1 and st.openMilestones > 0
		local idx = if done then st.openMilestones else n + 1
		L["m_" .. k].Text = string.format('#%d | %s OPENS  <font color="%s">%s</font>', idx, short(Runes.milestone(idx)), done and "#7cff5b" or "#8a8098", done and "UNLOCKED" or "LOCKED")
	end
	AltarUI.tickTimer()
end

function AltarUI.tickTimer()
	local d = data
	if not (d and d.runes and labels.s_pad) then
		return
	end
	local secs = d.runes.padSeconds
	labels.s_pad.Text = string.format("%dh %dm %ds", secs // 3600, (secs // 60) % 60, secs % 60)
	labels.s_pad.TextColor3 = SC.pad
	local nextPT, prev
	local count = 0
	for _, p in Runes.PLAYTIME do
		if secs >= p.minutes * 60 then
			count += 1
			prev = p
		elseif not nextPT then
			nextPT = p
		end
	end
	if nextPT then
		local what = nextPT.bulkAdd and ("+" .. nextPT.bulkAdd .. " BULK") or nextPT.bulk and ("x" .. nextPT.bulk .. " BULK") or ("x" .. nextPT.luck .. " LUCK")
		labels.p_next.Text = "NEXT: " .. what
		labels.p_next.TextColor3 = nextPT.luck and SC.luck or SC.bulk
		labels.p_at.Text = "at " .. (nextPT.minutes >= 60 and (nextPT.minutes / 60 .. "h") or (nextPT.minutes .. "m")) .. " on the pad"
		local from = prev and prev.minutes * 60 or 0
		labels.p_fill.Size = UDim2.fromScale(math.clamp((secs - from) / (nextPT.minutes * 60 - from), 0, 1), 1)
	else
		labels.p_next.Text = "ALL PAD BONUSES DONE"
		labels.p_at.Text = ""
		labels.p_fill.Size = UDim2.fromScale(1, 1)
	end
	labels.p_count.Text = count .. "/" .. #Runes.PLAYTIME .. " UNLOCKED"
end

---------------------------------------------------------------- opening effect

local function shockwave(color, big)
	local ring = part({ Name = "Shock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
	local r = big and 80 or 34
	local tw = TweenService:Create(ring, TweenInfo.new(big and 1.1 or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, r, r), Transparency = 1 })
	tw.Completed:Once(function()
		ring:Destroy()
	end)
	tw:Play()
end

local function beam(color)
	local b = part({ Name = "Beam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(160, 4.4, 4.4), CFrame = CFrame.new(center + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.25 })
	local tw = TweenService:Create(b, TweenInfo.new(1.6), { Size = Vector3.new(160, 1, 1), Transparency = 1 })
	tw.Completed:Once(function()
		b:Destroy()
	end)
	tw:Play()
end

local function riser(r)
	local a = part({ Name = "Riser", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(center + Vector3.new(math.random(-4, 4), 18, math.random(-4, 4))) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 44)
	bb.MaxDistance = 120
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.TextColor3 = rgb(r.color)
	t.Text = "◆ " .. r.name
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(1.6), { StudsOffset = Vector3.new(0, 14, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		a:Destroy()
	end)
end

local lastFx = 0
function AltarUI.opened(best: number)
	local r = Runes.LIST[best]
	if not (r and folder) then
		return
	end
	lastDrop = best
	local color = rgb(r.color)
	crystal.Color, light.Color = color, color
	kick = 1
	-- throttle the ring/riser so fast auto-roll never floods the scene; rares always play
	local now = os.clock()
	if best >= 6 or now - lastFx > 0.35 then
		lastFx = now
		shockwave(color, best >= 6)
		riser(r)
		if best >= 6 then
			beam(color)
		end
	end
	if labels.d_name then
		labels.d_name.Text = "◆ " .. string.upper(r.name)
		labels.d_name.TextColor3 = color
	end
end

---------------------------------------------------------------- per frame

local spin, timerAcc = 0, 0
function AltarUI._step(dt)
	if not crystal then
		return
	end
	local t = os.clock()
	spin += dt * (1.2 + kick * 8)
	kick = math.max(0, kick - dt * 2.5)
	crystal.CFrame = CFrame.new(center + Vector3.new(0, 11 + math.sin(t * 2) * 0.8 + kick * 2, 0)) * CFrame.Angles(math.rad(45), spin, math.rad(45))
	crystal.Size = Vector3.one * 4 * (1 + kick * 0.35)
	light.Brightness = 2 + kick * 6
	-- fade panels in when you're close
	local ch = Players.LocalPlayer.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local near = hrp and (Vector2.new(hrp.Position.X - center.X, hrp.Position.Z - center.Z)).Magnitude < SHOW_DISTANCE
	visible += ((near and 1 or 0) - visible) * math.min(1, dt * 5)
	for _, g in panels do
		g.GroupTransparency = 1 - visible
		g.Visible = visible > 0.02
	end
	timerAcc += dt
	if timerAcc >= 1 and visible > 0.02 then
		timerAcc = 0
		AltarUI.tickTimer()
	end
end

return AltarUI
