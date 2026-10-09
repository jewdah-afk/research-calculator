--!nonstrict
-- CompanionsBoard: the COMPANIONS list as a pull-down classroom map (a window shade on a roller bar), hanging under
-- the COMPANIONS [TAB] header at the top-right of the game area.
--   board    a steel sheet a little wider than the header; the companion rows sit on it
--   roller   a squared wooden rod with metal end caps along the board's bottom edge, a soft shadow under it and a
--            brass pull ring hanging from its centre. Closed, the rod rests tucked under the header with the ring
--            showing (the pull affordance).
--   drop     the roller falls with a gravity ease (fast, then decelerating), the sheet unrolls behind it with a slight
--            vertical stretch at the start, rows fade in only as the roller uncovers them, a ~6 px elastic bounce at
--            the bottom and the pull ring swings. Sound: board_roll_down.
--   roll up  spring loaded: the roller accelerates up, rows vanish as it passes them, it overshoots into the header,
--            settles with a small bounce and snaps shut. Sounds: board_roll_up, then board_clack on the snap.
-- Everything is a TweenService tween on ONE size (the track's height drives the clip, the sheet and the roller) plus
-- per-row cover fades with computed delays: no per-frame Lua, no layout rebuilds while it moves.
local TweenService = game:GetService("TweenService")
local Sfx = require(script.Parent.Sfx)
local Motion = require(script.Parent.Motion)
local Kit = require(script.Parent.Kit)

local Board = {}
Board.__index = Board

-- geometry (design px of the HUD component, before the HUD scale)
local ROW_H, ROW_GAP, PAD, SIDE = 52, 6, 8, 6
local ROD_H, CAP_W, CAP_H = 12, 12, 18
local DROP_EXTRA = 6           -- the elastic overshoot at the bottom
local ROD_BELOW = 6            -- the rod hangs this far below the sheet's bottom edge
-- timings (seconds) and eases
Board.T = {
	drop = 0.34,     -- Quad Out: fast fall, decelerating
	bounce1 = 0.12,  -- Sine InOut: overshoot +6 -> -2
	bounce2 = 0.10,  -- Sine Out: -2 -> rest
	stretch = 0.20,  -- sheet stretch 1.05 -> 1 at the start of the drop
	rowFade = 0.12,  -- a row's cover fades as the roller passes it
	up = 0.26,       -- Quad In: spring-loaded roll up
	over = 0.06,     -- roller overshoot 5 px into the header
	settle = 0.16,   -- Back Out settle of the roller, then the clack
	swing = { 0.12, 0.18, 0.14, 0.12 },   -- pull ring: +14 deg, -9, +4, 0
}

local INK = Color3.fromHex("0b0c10")
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function grad(f, cols)
	local ks = {}
	for i, c in cols do table.insert(ks, ColorSequenceKeypoint.new((i - 1) / (#cols - 1), Color3.fromHex(c))) end
	return new("UIGradient", { Color = ColorSequence.new(ks), Rotation = 90 }, f)
end
local function corner(f, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, f) end
local function inkStroke(f, w) return new("UIStroke", { Thickness = w, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter }, f) end

-- parent: the companions group (HUD design space); x, y: where the sheet starts (under the header); w: header width
-- onToggle(): asked when the ring is pulled
function Board.new(parent, x, y, w, onToggle, Icons)
	local self = setmetatable({ open = false, H = 0, rows = {}, covers = {}, tweens = {}, token = 0 }, Board)
	local W = w + 2 * SIDE
	self.W = W
	-- the track's height is the ONE tweened value: the clip fills it, the roller rides its bottom edge
	local track = new("Frame", { Name = "board", BackgroundTransparency = 1, Position = UDim2.fromOffset(x - SIDE, y), Size = UDim2.fromOffset(W, 0), ZIndex = 1 }, parent)
	local clip = new("Frame", { Name = "clip", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 1 }, track)
	-- the sheet: dark steel board (lattice texture, inner ink edge, a lit top line)
	local sheet = new("Frame", { Name = "sheet", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(W, 0), ZIndex = 1 }, clip)
	grad(sheet, { "2b3442", "1a2029" })
	corner(sheet, 3)
	local st = inkStroke(sheet, 2.5)
	pcall(function() st.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
	if Icons and Icons["ui/lattice"] then
		local tex = new("ImageLabel", { Name = "lattice", BackgroundTransparency = 1, Image = Icons["ui/lattice"], ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(30, 30), ImageTransparency = 0.94, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, sheet)
		corner(tex, 3)
	end
	local rowsHolder = new("Frame", { Name = "rows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2000), ZIndex = 2 }, clip)
	-- roller: rod + caps + shadow, centred on the track's bottom edge (+ ROD_BELOW)
	local roller = new("Frame", { Name = "roller", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, ROD_BELOW),
		Size = UDim2.fromOffset(W + 2 * CAP_W, CAP_H), ZIndex = 3 }, track)
	if Icons and Icons["ui/shadow"] then
		new("ImageLabel", { Name = "shadow", BackgroundTransparency = 1, Image = Icons["ui/shadow"], ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(128, 128, 128, 128),
			SliceScale = 0.12, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 2),
			Size = UDim2.new(1, -8, 0, 20), ZIndex = 1 }, roller)
	end
	local rod = new("Frame", { Name = "rod", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * CAP_W + 4, 0, ROD_H), ZIndex = 2 }, roller)
	grad(rod, { "e8bb84", "b77a45", "6a3a1a" })
	corner(rod, 3)
	inkStroke(rod, 2.5)
	new("Frame", { Name = "highlight", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 1.5), ZIndex = 3 }, rod)
	for i, ax in { 0, 1 } do
		local cap = new("Frame", { Name = "cap " .. i, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(ax, 0.5),
			Position = UDim2.fromScale(ax, 0.5), Size = UDim2.fromOffset(CAP_W, CAP_H), ZIndex = 4 }, roller)
		grad(cap, { "d7dde7", "8a94a6", "4a5262" })
		corner(cap, 3)
		inkStroke(cap, 2.5)
		new("Frame", { Name = "highlight", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0, 1.5), ZIndex = 5 }, cap)
	end
	-- pull ring: a pivot square centred on the rod's middle (GUI rotation pivots on the centre), string + brass ring below
	local pivot = new("Frame", { Name = "pull ring", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(68, 68), ZIndex = 1 }, roller)
	new("Frame", { Name = "string", BorderSizePixel = 0, BackgroundColor3 = INK, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, ROD_H / 2 - 1),
		Size = UDim2.fromOffset(3, 11), ZIndex = 1 }, pivot)
	local ring = new("Frame", { Name = "ring", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, ROD_H / 2 + 9),
		Size = UDim2.fromOffset(20, 20), ZIndex = 2 }, pivot)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	new("UIStroke", { Thickness = 6, Color = INK }, ring)
	local brass = new("Frame", { Name = "brass", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, ring)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, brass)
	new("UIStroke", { Thickness = 2.5, Color = Color3.fromHex("ffd36b") }, brass)
	-- the ring is a key (Motion.key: hover, press-in, sounds); a generous hit around it
	local ringHit = new("TextButton", { Name = "pull", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, ROD_H / 2), Size = UDim2.fromOffset(40, 34), ZIndex = 5 }, pivot)
	Motion.key(ring, "toggle", { hit = ringHit, onActivate = function() if onToggle then onToggle() end end })
	self.track, self.clip, self.sheet, self.rowsHolder, self.roller, self.pivot = track, clip, sheet, rowsHolder, roller, pivot
	return self
end

-- footprint below the sheet's top edge when closed (the tucked rod and the hanging ring): what sits under the header
function Board.closedFootprint() return ROD_BELOW + ROD_H / 2 + 9 + 20 + 2 end

local function play(self, inst, t, props, style, dir, delay)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	table.insert(self.tweens, tw)
	tw:Play()
	return tw
end
local function cancelAll(self)
	for _, t in self.tweens do t:Cancel() end
	table.clear(self.tweens)
end

-- the rows on the board (Figma companion rows, in order); a cover per row hides it until the roller passes
function Board:setRows(rows)
	for _, c in self.covers do c:Destroy() end
	table.clear(self.covers)
	self.rows = rows
	for i, r in rows do
		r.Parent = self.rowsHolder
		r.Position = UDim2.fromOffset(SIDE, PAD + (i - 1) * (ROW_H + ROW_GAP))
		local cover = new("Frame", { Name = "board cover", BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex("1f2630"), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 950 }, r)
		corner(cover, 3)
		self.covers[i] = cover
	end
	self.H = if #rows > 0 then PAD + #rows * ROW_H + (#rows - 1) * ROW_GAP + PAD else 0
	self.sheet.Size = UDim2.fromOffset(self.W, self.H)
	if self.open and not self.moving then self.track.Size = UDim2.fromOffset(self.W, self.H) end
end

function Board:swing()
	local seq = { 14, -9, 4, 0 }
	local i = 0
	local function step()
		i += 1
		if i > #seq then return end
		local t = play(self, self.pivot, Board.T.swing[i], { Rotation = seq[i] }, Enum.EasingStyle.Sine, if i == 1 then Enum.EasingDirection.Out else Enum.EasingDirection.InOut)
		t.Completed:Once(function(st) if st == Enum.PlaybackState.Completed then step() end end)
	end
	step()
end

function Board:setOpen(on, animate)
	if on == self.open then return end
	self.open = on
	self.token += 1
	local token = self.token
	cancelAll(self)
	local W, H = self.W, self.H
	self.pivot.Rotation = 0
	self.roller.Position = UDim2.new(0.5, 0, 1, ROD_BELOW)
	if not animate or Kit.reduced() or H <= 0 then
		self.moving = false
		self.track.Size = UDim2.fromOffset(W, if on then H else 0)
		self.sheet.Size = UDim2.fromOffset(W, H)
		for _, c in self.covers do c.BackgroundTransparency = if on then 1 else 0 end
		return
	end
	self.moving = true
	if on then
		Sfx.board("roll_down")
		local T = Board.T.drop
		local Hx = H + DROP_EXTRA
		for i, r in self.rows do
			local cover = self.covers[i]
			cover.BackgroundTransparency = 0
			-- Quad Out: h(t) = Hx (1 - (1 - t/T)^2) -> the roller passes a row's middle at t = T (1 - sqrt(1 - y/Hx))
			local y = r.Position.Y.Offset + ROW_H * 0.55
			local t = T * (1 - math.sqrt(math.max(0, 1 - math.clamp(y / Hx, 0, 1))))
			play(self, cover, Board.T.rowFade, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, t)
		end
		-- the sheet stretches a little as it starts to unroll, then relaxes
		self.sheet.Size = UDim2.fromOffset(W, H * 1.05)
		play(self, self.sheet, Board.T.stretch, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local a = play(self, self.track, T, { Size = UDim2.fromOffset(W, Hx) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		a.Completed:Once(function(st)
			if st ~= Enum.PlaybackState.Completed or self.token ~= token then return end
			self:swing()
			local b = play(self, self.track, Board.T.bounce1, { Size = UDim2.fromOffset(W, H - 2) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			b.Completed:Once(function(st2)
				if st2 ~= Enum.PlaybackState.Completed or self.token ~= token then return end
				local c = play(self, self.track, Board.T.bounce2, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				c.Completed:Once(function() if self.token == token then self.moving = false end end)
			end)
		end)
	else
		Sfx.board("roll_up")
		local T = Board.T.up
		local H0 = math.max(1, self.track.Size.Y.Offset)
		for i, r in self.rows do
			local cover = self.covers[i]
			-- Quad In: h(t) = H0 (1 - (t/T)^2) -> the roller passes a row's middle at t = T sqrt(1 - y/H0)
			local y = r.Position.Y.Offset + ROW_H * 0.45
			local t = T * math.sqrt(math.max(0, 1 - math.clamp(y / H0, 0, 1)))
			play(self, cover, 0.07, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, t)
		end
		local a = play(self, self.track, T, { Size = UDim2.fromOffset(W, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		a.Completed:Once(function(st)
			if st ~= Enum.PlaybackState.Completed or self.token ~= token then return end
			-- a slight overshoot into the header, a settle bounce of the roller, and the clack as it snaps shut
			local o = play(self, self.roller, Board.T.over, { Position = UDim2.new(0.5, 0, 1, ROD_BELOW - 5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			o.Completed:Once(function(st2)
				if st2 ~= Enum.PlaybackState.Completed or self.token ~= token then return end
				Sfx.board("clack")
				local s = play(self, self.roller, Board.T.settle, { Position = UDim2.new(0.5, 0, 1, ROD_BELOW) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				s.Completed:Once(function() if self.token == token then self.moving = false end end)
			end)
		end)
	end
end

return Board
