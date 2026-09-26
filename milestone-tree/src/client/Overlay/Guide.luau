--!strict
--[[
	Guide: the first-run tutorial (8 steps). Each step names what to press (a spotlight around it, a gold hairline and
	a card beside it) and moves on by itself when the game shows it was done, so it never blocks: the dim is click-
	through and SKIP is always there. The next step lives in Prefs.tut (8 = done or skipped); Options › Tutorial ›
	Replay starts it again. A player further along than a step skips it.

	    local g = Guide.new(root)
	    g:update(ctx)      every patch and a few times a second (targets move with the camera)
	    g:hide()           g.destroy

	ctx (App): { ms = MapState?, panel = open layer key?, milestones = number, pShown, pOwned (Prestige Points > 0),
	             mCan (M can reset), rect = function(target) -> ARect? (abs) }. Targets: "capsule", "node:<layer>",
	             "cta" (the panel's big action), "ready" (the READY tray), or nil (the card alone, lower centre).

	Steps:  1 points grow · 2 open M · 3 first milestone · 4 keep going (5 reveal a layer) · 5 open Prestige ·
	        6 prestige · 7 upgrades (NEXT) · 8 the READY tray (DONE)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Prefs = require(Core:WaitForChild("Prefs"))
local Rich = require(Core:WaitForChild("Rich"))
local Sleek = require(Core:WaitForChild("Sleek"))
local Motion = require(Core:WaitForChild("Motion"))
local Kit = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Kit"))

type ARect = { x: number, y: number, w: number, h: number }
export type Ctx = {
	panel: string?,
	milestones: number,
	pShown: boolean,
	pOwned: boolean,
	mCan: boolean,
	rect: (target: string) -> ARect?,
}
type Step = {
	title: string,
	body: string,
	target: string?,
	done: (c: Ctx) -> boolean, -- the step is behind the player: move on
	next: string?, -- a button that moves on (the steps nothing in the game confirms)
}

local GOLD = Color3.fromHex("ffc93c")
local DONE = 8

local STEPS: { Step } = {
	{ title = "Welcome to the tree", target = "capsule",
		body = "Your points grow on their own. Everything in the game is bought with them, starting with Milestones.",
		done = function(c) return c.milestones >= 1 end, next = "Next" },
	{ title = "Open the Milestone layer", target = "node:m",
		body = "Tap the violet M crystal. Each crystal on the tree is a layer.",
		done = function(c) return c.panel == "m" or c.milestones >= 1 end },
	{ title = "Get your first Milestone", target = "cta",
		body = "Press the big button when it lights up. Milestones never reset.",
		done = function(c) return c.milestones >= 1 end },
	{ title = "Milestones boost everything", target = nil,
		body = "Every Milestone makes the next one come sooner. Reach 5 Milestones to reveal a new layer.",
		done = function(c) return c.pShown end },
	{ title = "A new layer: Prestige", target = "node:p",
		body = "Tap the Prestige crystal to open it.",
		done = function(c) return c.panel == "p" or c.pOwned end },
	{ title = "Prestige", target = "cta",
		body = "Prestige trades your points for Prestige Points. When a layer says READY, it is worth doing.",
		done = function(c) return c.pOwned end },
	{ title = "Upgrades", target = nil,
		body = "Spend Prestige Points on the upgrade cards below. Each one multiplies your progress.",
		done = function() return false end, next = "Next" },
	{ title = "The READY tray", target = "ready",
		body = "When layers are READY, their gems line up here. Hold a gem to prestige without opening the layer. Have fun!",
		done = function() return false end, next = "Done" },
}

export type Guide = {
	frame: Frame,
	update: (self: Guide, ctx: Ctx) -> (),
	hide: (self: Guide) -> (),
	step: (self: Guide) -> number,
	destroy: (self: Guide) -> (),
}

local Guide = {}

function Guide.new(root: GuiObject): Guide
	local self = {} :: Guide
	local f = Kit.frame(root, "Guide", 40)
	f.Size = UDim2.fromScale(1, 1)
	f.Visible = false
	self.frame = f

	-- the dim around the target: four click-through panes and a gold hairline ring
	local dim = Kit.frame(f, "Dim", 40)
	dim.Size = UDim2.fromScale(1, 1)
	pcall(function() dim.Interactable = false end)
	local panes: { Frame } = {}
	for i = 1, 4 do
		local p = Kit.frame(dim, "Pane" .. i, 40)
		p.BackgroundColor3 = Color3.new(0, 0, 0)
		p.BackgroundTransparency = 0.5
		panes[i] = p
	end
	local ring = Kit.frame(dim, "Ring", 41)
	local rs = Kit.stroke(ring, 2, GOLD, 1, "Hair")
	rs.LineJoinMode = Enum.LineJoinMode.Miter
	Sleek.ticks(ring, { len = 12, th = 2, out = 4, color = GOLD, alpha = 1, z = 42 })

	-- the card
	local card = Kit.frame(f, "Card", 45)
	card.Size = UDim2.fromOffset(420, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Active = true
	Sleek.plate(card, { alpha = 0.96, line = 0.7 })
	Sleek.accent(card, GOLD, 18, 60, { name = "TopAccent" })
	Kit.pad(card, 18, 20, 16, 20)
	Kit.list(card, "y", 8, Enum.HorizontalAlignment.Left)
	local stepL = Kit.label(card, "Step", "caps", "", GOLD)
	stepL.LayoutOrder = 1
	stepL.Size = UDim2.new(1, 0, 0, 16)
	stepL.TextXAlignment = Enum.TextXAlignment.Left
	stepL.RichText = true
	local title = Kit.label(card, "Title", "section", "", Color3.new(1, 1, 1))
	title.LayoutOrder = 2
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local body = Kit.label(card, "Body", "body", "", Theme.C.soft)
	body.LayoutOrder = 3
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	local row = Kit.frame(card, "Buttons", 45)
	row.LayoutOrder = 4
	row.Size = UDim2.new(1, 0, 0, 44)
	Kit.list(row, "x", 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local skip = Kit.action(row, "Skip", Rich.caps("Skip tutorial"), { style = "quiet", h = 40 })
	skip.LayoutOrder = 1
	local nextB, nextL = Kit.action(row, "Next", Rich.caps("Next"), { style = "gold", h = 40 })
	nextB.LayoutOrder = 2

	local shown = 0 -- the step on screen (0: none)
	local lastCtx: Ctx? = nil
	local replaying = false -- Options › Tutorial › Replay was pressed this session
	Prefs.changed:Connect(function(key: string)
		if key == "tut" and Prefs.get().tut == 0 then replaying = true end
	end)

	local function setStep(n: number)
		Prefs.set("tut", math.clamp(n, 0, DONE))
	end
	skip.Activated:Connect(function() setStep(DONE) end)
	nextB.Activated:Connect(function()
		local cur = Prefs.get().tut
		setStep(cur + 1)
		if lastCtx then self:update(lastCtx) end
	end)

	local function place(target: ARect?)
		local s = Layout.s
		local ra = root.AbsolutePosition
		local W, H = root.AbsoluteSize.X / s, root.AbsoluteSize.Y / s
		local cw, ch = 420, math.max(card.AbsoluteSize.Y / s, 150)
		if target == nil then
			for _, p in panes do p.Visible = false end
			ring.Visible = false
			card.Position = UDim2.fromOffset((W - cw) / 2, H - ch - 150)
			return
		end
		-- the target in root du, padded
		local pad = 10
		local x, y = (target.x - ra.X) / s - pad, (target.y - ra.Y) / s - pad
		local w, h = target.w / s + 2 * pad, target.h / s + 2 * pad
		ring.Visible = true
		ring.Position = UDim2.fromOffset(x, y)
		ring.Size = UDim2.fromOffset(w, h)
		-- the dim: above, below, left, right of the hole
		local rects = { { 0, 0, W, y }, { 0, y + h, W, H - y - h }, { 0, y, x, h }, { x + w, y, W - x - w, h } }
		for i, r in rects do
			local p = panes[i]
			p.Visible = r[3] > 0 and r[4] > 0
			p.Position = UDim2.fromOffset(r[1], r[2])
			p.Size = UDim2.fromOffset(math.max(0, r[3]), math.max(0, r[4]))
		end
		-- the card: below the target when it fits, else above; kept on screen
		local cx = math.clamp(x + w / 2 - cw / 2, 16, W - cw - 16)
		local cy = if y + h + 16 + ch < H - 16 then y + h + 16 else y - ch - 16
		cy = math.clamp(cy, 16, H - ch - 16)
		card.Position = UDim2.fromOffset(cx, cy)
	end

	function self.step(_: Guide): number
		return Prefs.get().tut
	end

	function self.update(_: Guide, c: Ctx)
		lastCtx = c
		local prefs = Prefs.get()
		local n = prefs.tut
		if prefs.guide == "OFF" then n = DONE end
		-- a player well into the game (an old save) is past the whole tutorial, unless they asked for it again
		if c.milestones >= 12 and not replaying then n = DONE end
		-- steps the player is already past move on by themselves (one per update, so a new game shows each)
		while n < DONE and STEPS[n + 1].done(c) do
			n += 1
		end
		if n ~= prefs.tut and prefs.guide ~= "OFF" then setStep(n) end
		if n >= DONE then
			if f.Visible then f.Visible = false end
			shown = 0
			return
		end
		local st = STEPS[n + 1]
		local target = if st.target then c.rect(st.target) else nil
		if shown ~= n + 1 then
			shown = n + 1
			stepL.Text = Rich.caps(string.format("Tutorial  ·  %d / %d", n + 1, DONE))
			title.Text = st.title
			body.Text = st.body
			nextB.Visible = st.next ~= nil
			nextL.Text = Rich.caps(st.next or "Next")
			f.Visible = true
			local sc = Motion.scaleOf(card)
			sc.Scale = 0.96
			Motion.tween(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }, "guideCard")
		end
		place(target)
	end

	function self.hide(_: Guide)
		f.Visible = false
		shown = 0
	end

	function self.destroy(_: Guide)
		f:Destroy()
	end
	return self
end

return Guide
