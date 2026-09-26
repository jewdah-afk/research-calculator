--!strict
--[[
	Motion: every UI animation goes through here (DESIGN.md 8, plan 2.8).

	    Motion.reduced()                      the Options Motion override, else GuiService.ReducedMotionEnabled;
	                                          always true in snapshot mode (LocalPlayer attribute MT_Snapshot)
	    Motion.tween(inst, info, goals, key)  keyed: a new tween of the same key cancels the old one. Over budget
	                                          (6 running in HudGui / TopbarGui, 40 elsewhere; the map is not
	                                          counted) or with reduced motion, the end state is set at once and
	                                          nil is returned. `always` keeps functional tweens under reduced motion.
	    Motion.pop / bump / flash             small UIScale / transparency accents
	    Motion.loop(owner, fn)                fn(dt) every frame while owner is visible; stops when owner is gone
	    Motion.now(), Motion.step(dt)         the clock (7.0 in snapshot mode); step is called by App every frame

	Tween only Position, Size, Rotation, UIScale, transparencies and UIGradient Offset / Rotation.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(script.Parent:WaitForChild("Signal"))
local Prefs = require(script.Parent:WaitForChild("Prefs"))

type Handle = Types.Handle

local Motion = {}

Motion.BUDGET_HUD = 6
Motion.BUDGET_UI = 40
Motion.changed = Signal.new() :: Signal.Signal<boolean>

-- ------------------------------------------------------------------------------------------------------ reduced
local function snapshot(): boolean
	local lp = Players.LocalPlayer
	return lp ~= nil and lp:GetAttribute("MT_Snapshot") == true
end
Motion.snapshot = snapshot

local function compute(): boolean
	if snapshot() then return true end
	local m = Prefs.get().motion
	if m == "REDUCED" then return true end
	if m == "FULL" then return false end
	return GuiService.ReducedMotionEnabled
end
local reducedNow: boolean? = nil
local watching = false
local function refresh()
	local r = compute()
	if r ~= reducedNow then
		local first = reducedNow == nil
		reducedNow = r
		if not first then Motion.changed:Fire(r) end
	end
end
local function watch()
	if watching then return end
	watching = true
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refresh)
	Prefs.changed:Connect(function(key: string)
		if key == "motion" then refresh() end
	end)
	local lp = Players.LocalPlayer
	if lp then lp:GetAttributeChangedSignal("MT_Snapshot"):Connect(refresh) end
end
function Motion.reduced(): boolean
	if reducedNow == nil then
		watch()
		refresh()
	end
	return reducedNow == true
end

function Motion.now(): number
	if snapshot() then return 7.0 end
	return os.clock()
end

-- ------------------------------------------------------------------------------------------------------ tweens
local running: { [string]: number } = { hud = 0, ui = 0, map = 0 }
local keyed: { [string]: Tween } = {}

local function poolOf(inst: Instance): string
	local gui = inst:FindFirstAncestorWhichIsA("ScreenGui")
	if gui == nil then return "ui" end
	local n = gui.Name
	if n == "HudGui" or n == "TopbarGui" then return "hud" end
	if n == "MapGui" then return "map" end
	return "ui"
end
local function limit(pool: string): number
	if pool == "hud" then return Motion.BUDGET_HUD end
	if pool == "map" then return math.huge end
	return Motion.BUDGET_UI
end
local function setGoals(inst: Instance, goals: { [string]: any })
	for k, v in goals do
		pcall(function() (inst :: any)[k] = v end)
	end
end

function Motion.tween(inst: Instance, info: TweenInfo, goals: { [string]: any }, key: string?, always: boolean?): Tween?
	if key then
		local old = keyed[key]
		if old then
			keyed[key] = nil
			old:Cancel()
		end
	end
	local pool = poolOf(inst)
	if (Motion.reduced() and not always) or running[pool] >= limit(pool) or inst.Parent == nil then
		setGoals(inst, goals)
		return nil
	end
	local ok, tw = pcall(TweenService.Create, TweenService, inst, info, goals)
	if not ok then
		setGoals(inst, goals)
		return nil
	end
	local tween = tw :: Tween
	running[pool] += 1
	local done = false
	tween.Completed:Once(function()
		if done then return end
		done = true
		running[pool] = math.max(0, running[pool] - 1)
		if key and keyed[key] == tween then keyed[key] = nil end
	end)
	if key then keyed[key] = tween end
	tween:Play()
	return tween
end

-- a UIScale child of a GuiObject (created on first use)
local function scaleOf(inst: GuiObject): UIScale
	local s = inst:FindFirstChild("MotionScale")
	if s and s:IsA("UIScale") then return s end
	local u = Instance.new("UIScale")
	u.Name = "MotionScale"
	u.Parent = inst
	return u
end
Motion.scaleOf = scaleOf

-- pop in: 0 -> 1.15 -> 1 (0.25 s Back Out)
function Motion.pop(inst: GuiObject)
	local s = scaleOf(inst)
	if Motion.reduced() then
		s.Scale = 1
		return
	end
	s.Scale = 0
	Motion.tween(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }, nil)
end
-- a small bump: 1 + amount -> 1
function Motion.bump(inst: GuiObject, amount: number?)
	if Motion.reduced() then return end
	-- a UIScale grows an item's footprint in its parent's list / grid (the row reflows): flash those instead
	local parent = inst.Parent
	if parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		Motion.flash(inst)
		return
	end
	local s = scaleOf(inst)
	s.Scale = 1 + (amount or 0.06)
	Motion.tween(s, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }, nil)
end
-- a white flash over the object (the colour flash reduced motion keeps). An object that lays out its own children
-- (a card with a UIListLayout) flashes its outline instead: a flash Frame inside it would be one more list item, as
-- tall as the card, and under AutomaticSize the card would grow with it without end
function Motion.flash(inst: GuiObject)
	if inst:FindFirstChildWhichIsA("UIGridStyleLayout") then
		local old = inst:FindFirstChild("MotionFlash")
		if old then old:Destroy() end
		local st = inst:FindFirstChild("Border") or inst:FindFirstChildWhichIsA("UIStroke")
		if st == nil or not st:IsA("UIStroke") then return end
		local stroke = st :: UIStroke
		-- the resting look, kept across flashes that overlap (a tween in flight is not the resting value)
		local t0 = stroke:GetAttribute("FlashT0")
		local c0 = stroke:GetAttribute("FlashC0")
		if type(t0) ~= "number" or typeof(c0) ~= "Color3" then
			t0, c0 = stroke.Transparency, stroke.Color
			stroke:SetAttribute("FlashT0", t0)
			stroke:SetAttribute("FlashC0", c0)
		end
		stroke.Transparency = 0
		stroke.Color = Color3.new(1, 1, 1)
		local tw = Motion.tween(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = t0 :: number, Color = c0 :: Color3 }, "outline:" .. inst:GetFullName(), true)
		local function done()
			stroke:SetAttribute("FlashT0", nil)
			stroke:SetAttribute("FlashC0", nil)
		end
		-- cleared however the tween ends (a newer flash that cancels this one has already read the resting look)
		if tw then tw.Completed:Once(done) else done() end
		return
	end
	local f = inst:FindFirstChild("MotionFlash") :: Frame?
	if f == nil then
		local nf = Instance.new("Frame")
		nf.Name = "MotionFlash"
		nf.Size = UDim2.fromScale(1, 1)
		nf.BackgroundColor3 = Color3.new(1, 1, 1)
		nf.BorderSizePixel = 0
		nf.ZIndex = 50
		nf.Active = false
		local corner = inst:FindFirstChildWhichIsA("UICorner")
		if corner then corner:Clone().Parent = nf end
		nf.Parent = inst
		f = nf
	end
	local frame = f :: Frame
	frame.BackgroundTransparency = 0.55
	Motion.tween(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 },
		nil, true)
end

-- ------------------------------------------------------------------------------------------------------ loops
type Loop = { owner: GuiObject, fn: (dt: number) -> (), alive: boolean }
local loops: { Loop } = {}

function Motion.loop(owner: GuiObject, fn: (dt: number) -> ()): Handle
	local l: Loop = { owner = owner, fn = fn, alive = true }
	table.insert(loops, l)
	local h = {} :: Handle
	function h.stop(_: Handle)
		l.alive = false
	end
	return h
end

-- called once a frame by App (after the map); runs the Luau-driven fills and loops
function Motion.step(dt: number)
	local i = 1
	while i <= #loops do
		local l = loops[i]
		if not l.alive or l.owner.Parent == nil then
			table.remove(loops, i)
			continue
		end
		if l.owner.Visible then
			local ok, err = pcall(function(): any
				l.fn(dt)
				return nil
			end)
			if not ok then
				l.alive = false
				task.spawn(function() error(err, 0) end)
			end
		end
		i += 1
	end
end

return Motion
