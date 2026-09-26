--!strict
--[[
	BootScreen: the loading screen, from the first frame (ReplicatedFirst) until the player's game is on screen.
	No other modules: it runs before ReplicatedStorage has replicated.

	    BootScreen.show()                   build it (idempotent); Boot.client.luau calls it at once
	    BootScreen.set("Loading your save…") the status line   BootScreen.set({ done = 3, total = 9 }) the progress
	    BootScreen.hide()                   fill the line, fade out, destroy
	    BootScreen.visible()   BootScreen.claim() (the overlay drives it)   BootScreen.claimed()

	Look (Sleek, DESIGN.md Style 1): the void, a soft violet glow, four corner ticks, a diamond emblem that breathes
	and turns, THE MILESTONE TREE in tracked heavy italic caps with NG+ in the Milestone violet, a 2 px progress line
	with the % at its right, the status in caps above it, and a rotating tip under it. The progress never stalls: it
	creeps towards 90% on its own and jumps to what the game reports.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BootScreen = {}

local VOID = Color3.fromHex("05070c")
local HUE = Color3.fromHex("b35cff") -- the Milestone violet
local TEXT = Color3.fromHex("f3f6fb")
local SOFT = Color3.fromHex("aab4c4")
local MUTED = Color3.fromHex("6b7486")
local HAIR = Color3.new(1, 1, 1)

local TIPS = {
	"Tap a node on the tree to open its layer",
	"Hold a READY gem to prestige without opening the layer",
	"Locked layers say how many milestones reveal them",
	"Right-click a node (or press and hold it) to peek at it",
	"Options › Numbers switches between 1.23M and 1.23e6",
	"The game keeps running while you are away",
}

local gui: ScreenGui? = nil
local parts: { [string]: any } = {}
local status = "Loading the realm"
local target = 0
local shown = 0
local started = 0
local hiding = false
local claimed = false
local conn: RBXScriptConnection? = nil

-- tracked caps: a hair space between the letters (the engine has no letter spacing)
local function caps(s: string): string
	local out = {}
	for _, c in utf8.codes(string.upper(s)) do
		table.insert(out, utf8.char(c))
	end
	return table.concat(out, "\u{200A}")
end

local function frame(parent: Instance, name: string, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props do (f :: any)[k] = v end
	f.Parent = parent
	return f
end
local function label(parent: Instance, name: string, text: string, size: number, color: Color3, font: Font,
	props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.FontFace = font
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.TextXAlignment = Enum.TextXAlignment.Center
	for k, v in props or {} do (l :: any)[k] = v end
	l.Parent = parent
	return l
end
local function font(weight: Enum.FontWeight, italic: boolean?): Font
	return Font.fromName("Montserrat", weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

-- an L of two 2 px bars in a screen corner
local function tick(parent: Instance, name: string, ax: number, ay: number)
	local holder = frame(parent, name, {
		AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, if ax == 0 then 28 else -28, ay, if ay == 0 then 28 else -28),
		Size = UDim2.fromOffset(22, 22),
	})
	frame(holder, "H", { BackgroundTransparency = 0.55, BackgroundColor3 = HAIR, Size = UDim2.fromOffset(22, 2),
		Position = UDim2.fromScale(0, ay), AnchorPoint = Vector2.new(0, ay) })
	frame(holder, "V", { BackgroundTransparency = 0.55, BackgroundColor3 = HAIR, Size = UDim2.fromOffset(2, 22),
		Position = UDim2.fromScale(ax, 0), AnchorPoint = Vector2.new(ax, 0) })
end

local function build(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "MilestoneBoot"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 1000
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() g.ScreenInsets = Enum.ScreenInsets.None end)

	local back = frame(g, "Back", { BackgroundTransparency = 0, BackgroundColor3 = VOID, Size = UDim2.fromScale(1, 1) })
	-- a soft violet glow from the middle (a vertical fade: radial gradients are still a beta)
	local glow = frame(back, "Glow", { BackgroundTransparency = 0, BackgroundColor3 = HUE, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(1.2, 0, 0.9, 0) })
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow
	for _, t in { { "TL", 0, 0 }, { "TR", 1, 0 }, { "BL", 0, 1 }, { "BR", 1, 1 } } do
		tick(back, "Tick" .. t[1], t[2], t[3])
	end

	-- the centre column, scaled to the screen (the design is 1920 x 1080; phones keep it readable)
	local col = frame(back, "Column", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 420) })
	local scale = Instance.new("UIScale")
	scale.Parent = col
	parts.scale = scale

	-- the emblem: an outer square outline turning slowly, a diamond outline, a filled core that breathes
	local emblem = frame(col, "Emblem", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(120, 120) })
	local outer = frame(emblem, "Outer", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(84, 84) })
	local os_ = Instance.new("UIStroke")
	os_.Color = HAIR
	os_.Transparency = 0.8
	os_.Thickness = 1
	os_.Parent = outer
	local diamond = frame(emblem, "Diamond", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(62, 62), Rotation = 45 })
	local ds = Instance.new("UIStroke")
	ds.Color = HUE
	ds.Thickness = 2
	ds.Parent = diamond
	local core = frame(emblem, "Core", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26), Rotation = 45, BackgroundTransparency = 0, BackgroundColor3 = HUE })
	local cg = Instance.new("UIGradient")
	cg.Color = ColorSequence.new(Color3.fromHex("e6c8ff"), HUE)
	cg.Rotation = 90
	cg.Parent = core
	parts.outer, parts.diamond, parts.core = outer, diamond, core

	-- the title
	label(col, "Title", caps("The Milestone Tree"), 46, TEXT, font(Enum.FontWeight.Heavy, true),
		{ Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 56) })
	label(col, "Edition", caps("NG+  ·  An incremental tree"), 14, HUE, font(Enum.FontWeight.Bold),
		{ Position = UDim2.fromOffset(0, 198) })

	-- the progress: status (left) and % (right) above a 2 px line
	local bar = frame(col, "Bar", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 268),
		Size = UDim2.fromOffset(420, 40) })
	parts.status = label(bar, "Status", caps(status), 12, SOFT, font(Enum.FontWeight.Bold),
		{ Size = UDim2.new(1, -60, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
	parts.pct = label(bar, "Pct", "0%", 12, TEXT, font(Enum.FontWeight.Bold),
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 16),
			TextXAlignment = Enum.TextXAlignment.Right })
	local track = frame(bar, "Track", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 2),
		BackgroundTransparency = 0.88, BackgroundColor3 = HAIR })
	local fill = frame(track, "Fill", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = HUE })
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(HUE, Color3.fromHex("e6c8ff"))
	fg.Parent = fill
	frame(track, "CapL", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(2, 10),
		BackgroundTransparency = 0.4, BackgroundColor3 = HAIR })
	frame(track, "CapR", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(2, 10),
		BackgroundTransparency = 0.4, BackgroundColor3 = HAIR })
	parts.fill = fill

	-- the tip
	parts.tip = label(col, "Tip", "", 15, MUTED, font(Enum.FontWeight.SemiBold),
		{ Position = UDim2.fromOffset(0, 336), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true })
	return g
end

local function layout(g: ScreenGui)
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	local s = math.clamp(math.min(v.X / 1920, v.Y / 1080) * 1.25, 0.55, 2)
	if parts.scale then parts.scale.Scale = s end
	local _ = g
end

local function step()
	local g = gui
	if g == nil then return end
	local t = os.clock() - started
	-- creep to 90% on its own (fast at first), never past what the game has not confirmed
	local creep = 0.9 * (1 - math.exp(-t / 4))
	local want = if hiding then 1 else math.max(target, creep)
	shown += (want - shown) * math.min(1, 0.12)
	if parts.fill then parts.fill.Size = UDim2.fromScale(shown, 1) end
	if parts.pct then parts.pct.Text = string.format("%d%%", math.floor(shown * 100 + 0.5)) end
	-- the emblem: the outer square turns, the core breathes
	if parts.outer then parts.outer.Rotation = (t * 18) % 360 end
	if parts.core then
		local b = 0.5 + 0.5 * math.sin(t * 2.4)
		parts.core.Size = UDim2.fromOffset(24 + 6 * b, 24 + 6 * b)
		parts.core.BackgroundTransparency = 0.15 * (1 - b)
	end
	if parts.tip then
		local i = math.floor(t / 4.5) % #TIPS + 1
		local want = TIPS[i]
		if parts.tip.Text ~= want then parts.tip.Text = want end
	end
end

function BootScreen.visible(): boolean
	return gui ~= nil and not hiding
end
-- the game's overlay took over (it drives the screen from now on)
function BootScreen.claim()
	claimed = true
end
function BootScreen.claimed(): boolean
	return claimed
end

function BootScreen.show()
	if gui then return end
	local lp = Players.LocalPlayer
	if lp == nil then return end
	local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
	if pg == nil then return end
	local existing = pg:FindFirstChild("MilestoneBoot")
	if existing then existing:Destroy() end
	started = os.clock()
	shown, target, hiding = 0, 0, false
	local g = build()
	g.Parent = pg
	gui = g
	layout(g)
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() if gui then layout(gui) end end) end
	conn = RunService.Heartbeat:Connect(step)
end

-- a status string, or { done, total } for the progress (the preload count)
function BootScreen.set(data: any)
	if gui == nil or hiding then return end
	if type(data) == "string" then
		status = string.gsub(data, "[%.…]+$", "")
		if parts.status then parts.status.Text = caps(status) end
		-- each server step is further along
		target = math.max(target, 0.35)
	elseif type(data) == "table" and type(data.done) == "number" and type(data.total) == "number" then
		local p = if data.total > 0 then math.clamp(data.done / data.total, 0, 1) else 1
		target = math.max(target, 0.1 + 0.6 * p)
	end
end

function BootScreen.hide()
	local g = gui
	if g == nil or hiding then return end
	hiding = true
	target = 1
	task.delay(0.25, function()
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, d in g:GetDescendants() do
			if d:IsA("Frame") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			g:Destroy()
			if gui == g then gui = nil end
		end)
	end)
end

return BootScreen
