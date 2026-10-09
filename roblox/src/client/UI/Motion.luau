--!nonstrict
-- Motion: the Figma shared motion language (HANDOUT section 4 + the MOTION line of every spec card), all on
-- TweenService and event driven. Nothing here runs per frame while the UI is idle: ambient loops are engine tweens
-- that start when a window becomes visible and are cancelled when it hides.
--   open      scale 0.86 -> 1.04 -> 1 (320 ms) flying out of the HUD button that opened it; rows cascade 40 ms
--   close     rows collapse in reverse, then the window fades + shrinks into its button; small sparkle burst
--   tabs      no re-pop: old content fades out / new fades in (120 ms, 8 px slide toward the tab), the active tab
--             pill springs to its new slot, rows cascade (the window frame never moves)
--   idle      header gloss sweep every 4.5 s (one tweened gradient offset), sparkles twinkle, header glow breathes
--             over 2.8 s, hero icons bob +-3 px. Only on the open window.
--   feedback  buy squash 0.94 -> release 1.06, value pop, bar tween, currency fly-in; can't afford shake + red
--             flash; maxed gold pop + sparkle burst + shimmer; molt / evolve reset moments
-- Fades use a CanvasGroup only for the length of the transition (wrap -> tween -> unwrap), never at rest.
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))
local Kit = require(script.Parent.Kit)

local Motion = {}

local function reduced() return Kit.reduced() end
Motion.reduced = reduced
local function tw(inst, t, props, style, dir, rep, rev, delay)
	local tween = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, rep or 0, rev or false, delay or 0), props)
	tween:Play()
	return tween
end
Motion.tw = tw

-- top-left of a GuiObject in its parent's offset space (keys are centre-anchored for the squash)
function Motion.topLeft(inst)
	return Vector2.new(inst.Position.X.Offset - inst.AnchorPoint.X * inst.Size.X.Offset, inst.Position.Y.Offset - inst.AnchorPoint.Y * inst.Size.Y.Offset)
end

-- ---------------------------------------------------------------- transient CanvasGroup (fades)
-- wrap a centre-anchored frame (window inner / variant root) so its whole tree can fade; margin keeps drop shadows
function Motion.wrap(inst, margin)
	margin = margin or 48
	local cg = Instance.new("CanvasGroup")
	cg.Name = "fade"
	cg.BackgroundTransparency = 1
	cg.BorderSizePixel = 0
	cg.ZIndex = inst.ZIndex
	cg.Size = UDim2.fromOffset(inst.Size.X.Offset + 2 * margin, inst.Size.Y.Offset + 2 * margin)
	local tl = Motion.topLeft(inst)
	cg.Position = UDim2.fromOffset(tl.X - margin, tl.Y - margin)
	if inst.Position.X.Scale ~= 0 or inst.Position.Y.Scale ~= 0 then
		cg.AnchorPoint = Vector2.new(0.5, 0.5)
		cg.Position = UDim2.new(inst.Position.X.Scale, inst.Position.X.Offset, inst.Position.Y.Scale, inst.Position.Y.Offset)
	end
	cg.Parent = inst.Parent
	local home = { parent = inst.Parent, pos = inst.Position, anchor = inst.AnchorPoint }
	inst.Parent = cg
	inst.AnchorPoint = Vector2.new(0.5, 0.5)
	inst.Position = UDim2.new(0.5, 0, 0.5, 0)
	return cg, function()
		if inst.Parent == cg then
			inst.Parent = home.parent
			inst.AnchorPoint = home.anchor
			inst.Position = home.pos
		end
		cg:Destroy()
	end
end

-- ---------------------------------------------------------------- rows: cascade in / collapse out
local ROW_PREFIX = { "row/", "card/", "stat card/", "offer ", "accepted ", "buff " }
local function isRow(d)
	if not d:IsA("GuiObject") then return false end
	local n = d.Name
	for _, p in ROW_PREFIX do if string.sub(n, 1, #p) == p then return true end end
	return false
end
function Motion.rows(root, max)
	local list = {}
	for _, d in root:GetDescendants() do
		if isRow(d) and d.Visible then
			table.insert(list, d)
			if #list >= (max or 14) then break end
		end
	end
	return list
end
function Motion.cascade(root, dir)
	if reduced() then return end
	dir = dir or 1
	for i, d in Motion.rows(root) do
		local home = d:GetAttribute("homePos") or d.Position
		d:SetAttribute("homePos", home)
		d.Position = home + UDim2.fromOffset(18 * dir, 0)
		tw(d, 0.24, { Position = home }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.04 * i)
		task.delay(0.04 * i + 0.3, function() if d.Parent then d:SetAttribute("homePos", nil) end end)
	end
end
-- reverse order, quick slide out (close)
function Motion.collapse(root)
	if reduced() then return 0 end
	local rows = Motion.rows(root)
	local n = #rows
	for i = n, 1, -1 do
		local d = rows[i]
		local home = d:GetAttribute("homePos") or d.Position
		d:SetAttribute("homePos", home)
		tw(d, 0.1, { Position = home + UDim2.fromOffset(22, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.02 * (n - i))
	end
	return math.min(0.18, 0.02 * n + 0.1)
end
function Motion.restoreRows(root)
	for _, d in root:GetDescendants() do
		local home = d:GetAttribute("homePos")
		if home then d.Position = home; d:SetAttribute("homePos", nil) end
	end
end

-- ---------------------------------------------------------------- window open / close
-- rec: { holder, inner, pop (UIScale on inner), fit (UIScale on holder) }; from / to: design-px points (or nil)
local function offsetTo(rec, pt)
	if not pt then return UDim2.new(0.5, 0, 0.5, 0) end
	local h = rec.holder
	local s = rec.fit.Scale
	local centre = Vector2.new(h.AbsolutePosition.X + h.AbsoluteSize.X / 2, h.AbsolutePosition.Y + h.AbsoluteSize.Y / 2)
	local canvasScale = rec.canvasScale and rec.canvasScale() or 1
	local d = (pt * canvasScale - centre) / math.max(0.01, canvasScale * s)
	return UDim2.new(0.5, d.X, 0.5, d.Y)
end
function Motion.open(rec, fromPt, root)
	rec.popCount = (rec.popCount or 0) + 1
	if rec.closing then rec.closing(); rec.closing = nil end
	if reduced() then rec.pop.Scale = 1; rec.inner.Position = UDim2.new(0.5, 0, 0.5, 0); return end
	rec.pop.Scale = 0.86
	rec.inner.Position = offsetTo(rec, fromPt)
	tw(rec.inner, 0.26, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local up = tw(rec.pop, 0.2, { Scale = 1.04 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	up.Completed:Once(function(st)
		if st == Enum.PlaybackState.Completed then tw(rec.pop, 0.12, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut) end
	end)
	if root then Motion.cascade(root) end
end
function Motion.close(rec, toPt, root, done, burstParent, burstPt)
	if reduced() then done(); return end
	local wait = if root then Motion.collapse(root) else 0
	local finished = false
	local cg, unwrap
	local function finish()
		if finished then return end
		finished = true
		if unwrap then unwrap() end
		rec.pop.Scale = 1
		rec.inner.Position = UDim2.new(0.5, 0, 0.5, 0)
		if root then Motion.restoreRows(root) end
		done()
	end
	rec.closing = finish
	task.delay(wait, function()
		if finished then return end
		cg, unwrap = Motion.wrap(rec.inner, 48)
		tw(cg, 0.18, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(rec.pop, 0.18, { Scale = 0.45 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if toPt then tw(rec.inner, 0.18, { Position = offsetTo(rec, toPt) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
		task.delay(0.19, function()
			if burstParent and burstPt then Motion.burst(burstParent, burstPt, 5, 26) end
			finish()
		end)
	end)
end

-- ---------------------------------------------------------------- tabs: crossfade + pill spring (no re-pop)
function Motion.crossfade(oldRoot, newRoot, dir, done)
	if reduced() or not oldRoot then
		if oldRoot then oldRoot.Visible = false end
		newRoot.Visible = true
		done()
		return function() end
	end
	newRoot.Visible = true
	local cgOld, unOld = Motion.wrap(oldRoot, 48)
	local cgNew, unNew = Motion.wrap(newRoot, 48)
	cgNew.GroupTransparency = 1
	local slideFrom = cgNew.Position
	cgNew.Position = slideFrom + UDim2.fromOffset(8 * dir, 0)
	tw(cgOld, 0.12, { GroupTransparency = 1 })
	tw(cgNew, 0.12, { GroupTransparency = 0 })
	tw(cgNew, 0.16, { Position = slideFrom }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		unOld(); unNew()
		oldRoot.Visible = false
		done()
	end
	task.delay(0.17, finish)
	return finish
end
-- the selected tab pill springs from where the old one was
function Motion.springTab(newActive, oldPos)
	if reduced() or not (newActive and oldPos) then return end
	local home = newActive.Position
	newActive.Position = oldPos
	tw(newActive, 0.22, { Position = home }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- ---------------------------------------------------------------- idle (open window only)
-- returns a stop function; every loop is an engine tween (no Lua per frame)
function Motion.idle(root, header)
	if reduced() then return function() end end
	local tweens, restore = {}, {}
	local function keep(t) table.insert(tweens, t) end
	-- header gloss sweep: one gradient band, its Offset tweened across every 4.5 s
	if header then
		local sweep = header:FindFirstChild("gloss sweep")
		if not sweep then
			sweep = Instance.new("Frame")
			sweep.Name = "gloss sweep"
			sweep.BackgroundColor3 = Color3.new(1, 1, 1)
			sweep.BorderSizePixel = 0
			sweep.Size = UDim2.fromScale(1, 1)
			sweep.ZIndex = 90
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.44, 1), NumberSequenceKeypoint.new(0.5, 0.62),
				NumberSequenceKeypoint.new(0.53, 0.8), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) })
			-- ~22 deg in pixels on a wide header (the gradient rotates in the frame's UV space)
			local w, h = math.max(1, header.Size.X.Offset), math.max(1, header.Size.Y.Offset)
			g.Rotation = math.deg(math.atan2(h * math.sin(math.rad(22)), w * math.cos(math.rad(22))))
			g.Parent = sweep
			sweep.Parent = header
		end
		local g = sweep:FindFirstChildOfClass("UIGradient")
		g.Offset = Vector2.new(-1.1, 0)
		keep(tw(g, 0.9, { Offset = Vector2.new(1.1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 3.6))
		-- the header glow breathes over 2.8 s
		local glow = header:FindFirstChild("glow")
		if glow then
			restore[glow] = { BackgroundTransparency = glow.BackgroundTransparency }
			keep(tw(glow, 1.4, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))
		end
	end
	-- sparkles twinkle, hero icons bob +-3 px (staggered)
	local bobbed = 0
	for _, d in root:GetDescendants() do
		if d:IsA("ImageLabel") then
			if d.Name == "fx/sparkle" then
				restore[d] = { Size = d.Size, Rotation = d.Rotation, ImageTransparency = d.ImageTransparency }
				local t = 1.1 + math.random() * 1.2
				keep(tw(d, t, { Size = UDim2.fromOffset(d.Size.X.Offset * 0.7, d.Size.Y.Offset * 0.7), Rotation = 18, ImageTransparency = math.min(1, d.ImageTransparency + 0.35) },
					Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, math.random() * 0.8))
			elseif bobbed < 2 and string.sub(d.Name, 1, 4) == "ico/" and d.Size.X.Offset >= 96 then
				bobbed += 1
				restore[d] = { Position = d.Position }
				keep(tw(d, 0.8, { Position = d.Position - UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, bobbed * 0.4))
			end
		end
	end
	return function()
		for _, t in tweens do t:Cancel() end
		for inst, props in restore do for k, v in props do inst[k] = v end end
		local sweep = header and header:FindFirstChild("gloss sweep")
		if sweep then sweep:FindFirstChildOfClass("UIGradient").Offset = Vector2.new(-1.1, 0) end
	end
end

-- ---------------------------------------------------------------- feedback
local function scaleOf(inst)
	local s = inst:FindFirstChild("Squash")
	if not s then
		s = Instance.new("UIScale"); s.Name = "Squash"; s.Parent = inst
	end
	return s
end
function Motion.squash(inst) if not reduced() then tw(scaleOf(inst), 0.06, { Scale = 0.94 }) end end
function Motion.unsquash(inst) if not reduced() then tw(scaleOf(inst), 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end end
-- confirmed purchase: the key releases with a 1.06 overshoot
function Motion.release(inst)
	if reduced() or not inst then return end
	local s = scaleOf(inst)
	s.Scale = 1.06
	tw(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end
function Motion.pop(inst, from) Kit.pop(inst, from or 1.15) end
-- red flash on a cost label (can't afford)
function Motion.flashText(label, hex)
	if not label then return end
	local base = label:GetAttribute("flashBase") or label.TextColor3
	label:SetAttribute("flashBase", base)
	label.TextColor3 = Color3.fromHex(hex or "ff4d4d")
	local t = tw(label, 0.35, { TextColor3 = base }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12)
	t.Completed:Once(function(st) if st == Enum.PlaybackState.Completed then label:SetAttribute("flashBase", nil) end end)
end
-- small 4-point sparkle burst at a point of `parent` (UI images, cleaned up after)
function Motion.burst(parent, pos, n, size)
	if reduced() or not parent then return end
	for i = 1, n or 6 do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = Icons["ui/sparkle"]
		img.ImageColor3 = Color3.fromHex(if i % 2 == 0 then "fff3b0" else "ffffff")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		local s = (size or 22) * (0.6 + math.random() * 0.6)
		img.Size = UDim2.fromOffset(s, s)
		img.Position = UDim2.fromOffset(pos.X, pos.Y)
		img.ZIndex = 200
		img.Parent = parent
		local a = (i / (n or 6)) * math.pi * 2 + math.random()
		local r = 26 + math.random() * 26
		tw(img, 0.45, { Position = UDim2.fromOffset(pos.X + math.cos(a) * r, pos.Y + math.sin(a) * r), ImageTransparency = 1, Rotation = 90, Size = UDim2.fromOffset(s * 0.4, s * 0.4) },
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.5, function() img:Destroy() end)
	end
end
-- a "+N" / "+1 LV" floater that rises and fades
function Motion.floater(parent, pos, text, hex, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	l.TextSize = size or 22
	l.Text = text
	l.TextColor3 = Color3.fromHex(hex or "9dffae")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(240, (size or 22) + 8)
	l.Position = UDim2.fromOffset(pos.X, pos.Y)
	l.ZIndex = 210
	local st = Instance.new("UIStroke")
	st.Thickness = math.max(1.5, (size or 22) * 0.1)
	st.Color = Color3.fromHex("0b0c10")
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = l
	l.Parent = parent
	local rise = tw(l, 0.7, { Position = UDim2.fromOffset(pos.X, pos.Y - 46) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	tw(l, 0.3, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45)
	tw(st, 0.3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45)
	task.delay(0.8, function() l:Destroy() end)
	return rise
end
-- odometer roll of a numeric label: from -> to over 350 ms with the given formatter (event driven, ends by itself)
function Motion.roll(label, from: number, to: number, fmt, onStep)
	if reduced() or from == to or from ~= from or to ~= to or math.abs(to) == math.huge or math.abs(from) == math.huge then
		label.Text = fmt(to); if onStep then onStep(fmt(to)) end
		return
	end
	local nv = label:FindFirstChild("roll")
	if nv then nv:Destroy() end
	nv = Instance.new("NumberValue")
	nv.Name = "roll"
	nv.Value = from
	nv.Parent = label
	nv.Changed:Connect(function(v)
		local s = fmt(v)
		label.Text = s
		if onStep then onStep(s) end
	end)
	local t = tw(nv, 0.35, { Value = to }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	t.Completed:Once(function() if nv.Parent then label.Text = fmt(to); if onStep then onStep(fmt(to)) end; nv:Destroy() end end)
end
-- the ONE attention target: a soft breathing glow behind a key (returns stop)
function Motion.breathe(keyInst, hex)
	if reduced() or not keyInst then return function() end end
	local glow = keyInst:FindFirstChild("attention glow")
	if not glow then
		glow = Instance.new("ImageLabel")
		glow.Name = "attention glow"
		glow.BackgroundTransparency = 1
		glow.Image = Icons["ui/glow"]
		glow.ScaleType = Enum.ScaleType.Slice
		glow.SliceCenter = Rect.new(128, 128, 128, 128)
		glow.SliceScale = 0.25
		glow.ImageColor3 = Color3.fromHex(hex or "7dff86")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.new(1, 28, 1, 28)
		glow.ZIndex = 0
		glow.Parent = keyInst
	end
	glow.ImageTransparency = 0.82
	local t = tw(glow, 1.3, { ImageTransparency = 0.55 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	return function() t:Cancel(); glow.ImageTransparency = 1 end
end
-- a one-off shimmer across a bar / plate (maxed)
function Motion.shimmer(frame)
	if reduced() or not frame then return end
	local s = Instance.new("Frame")
	s.Name = "shimmer"
	s.BackgroundColor3 = Color3.new(1, 1, 1)
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.ZIndex = 80
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) })
	g.Rotation = 20
	g.Offset = Vector2.new(-1, 0)
	g.Parent = s
	s.Parent = frame
	tw(g, 0.6, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.delay(0.65, function() s:Destroy() end)
end
-- maxed: gold plate pops in with sparkles, the bar shimmers
function Motion.maxed(plate, bar, burstParent, burstPt)
	if plate then Kit.pop(plate, 1.2) end
	Motion.shimmer(bar)
	if burstParent and burstPt then Motion.burst(burstParent, burstPt, 6, 24) end
end
-- Evolve: the feed rows wilt brown and fall away, then come back
function Motion.wilt(rows)
	if reduced() then return end
	for i, r in rows do
		local home = r.Position
		local brown = Instance.new("Frame")
		brown.Name = "wilt"
		brown.BackgroundColor3 = Color3.fromHex("6a3a1a")
		brown.BackgroundTransparency = 1
		brown.BorderSizePixel = 0
		brown.Size = UDim2.fromScale(1, 1)
		brown.ZIndex = 150
		brown.Parent = r
		tw(brown, 0.25, { BackgroundTransparency = 0.35 })
		tw(r, 0.45, { Position = home + UDim2.fromOffset(0, 40), Rotation = (i % 2 == 0) and 5 or -5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25 + i * 0.06)
		task.delay(0.9 + i * 0.06, function()
			if not r.Parent then return end
			r.Rotation = 0
			r.Position = home + UDim2.fromOffset(0, -16)
			brown:Destroy()
			tw(r, 0.3, { Position = home }, Enum.EasingStyle.Back)
		end)
	end
end

return Motion
