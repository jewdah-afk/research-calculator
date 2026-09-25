--!strict
--[[
	Ambient: the realm's living sprites (art/REALM.md 6.1, 6.2) and the corrupt blooms (5).

	    local amb = Ambient.new({ realm, layers, containers, backs, atlas, tier, reduced })
	    amb:recolor(w, C, z, V)        biome colours of the sprites with a colour object, and the blooms
	    amb:setPaused(true)            a full-screen panel covers the map: every tween paused, loops idle
	    amb:setLayerAlpha("fg", k)     the fg fade (zoom and side sheet)
	    amb:setRiftBoost(a)            the rift hover (DESIGN.md 3.11)
	    amb:destroy()

	Every sprite is built from Realm.sprites (the instances camera.js resolved; LOW uses the first count.LOW) in its
	layer's moving Sprites container, in Scale units of the layer (so it follows the container's zoom for free), and
	animated by TweenService with the closed-form curves of camera.js `channel`: sine = a reversing Sine InOut
	half-period tween, drift / scroll = a partial tween to the end then a Linear loop, pulse and flicker = a small
	loop. With reduced motion nothing moves: each sprite rests at its base (drifts frozen at their phase), and the
	groups REALM.md 9.6 lists are hidden. Without the realm atlas there are no sprites and no blooms.
]]

local TweenService = game:GetService("TweenService")

local MapCamera = require(script.Parent:WaitForChild("MapCamera"))

local Ambient = {}

type Pt = MapCamera.Pt
type Size = MapCamera.Size
type Weights = MapCamera.Weights
type Channel = MapCamera.Channel
type RGB = { number }

export type Atlas = { id: string, regions: { [string]: { number } }, k: number }
export type LayerInfo = { id: string, f: number, w: number, h: number, ax: number, ay: number }
export type Options = {
	realm: any,
	layers: { [string]: LayerInfo },
	containers: { [string]: Frame },
	backs: { [string]: Frame },
	atlas: Atlas?,
	tier: string,
	reduced: boolean,
}

type Sprite = {
	group: any,
	inst: any,
	layer: LayerInfo,
	root: GuiObject, -- the wrapper (or the hanging pivot)
	img: ImageLabel,
	colored: boolean,
	alpha: number, -- the base alpha
	boost: ImageLabel?,
}
type Bloom = { img: ImageLabel, alpha: number }

export type Ambient = {
	recolor: (self: Ambient, w: Weights, C: Pt, z: number, V: Size) -> (),
	setPaused: (self: Ambient, paused: boolean) -> (),
	setLayerAlpha: (self: Ambient, layer: string, k: number) -> (),
	setRiftBoost: (self: Ambient, a: number) -> (),
	destroy: (self: Ambient) -> (),
	count: (self: Ambient) -> number,
}

local function rgb(t: RGB): Color3
	return Color3.fromRGB(math.clamp(t[1], 0, 255), math.clamp(t[2], 0, 255), math.clamp(t[3], 0, 255))
end

function Ambient.new(o: Options): Ambient
	local sprites: { Sprite } = {}
	local blooms: { Bloom } = {}
	local tweens: { Tween } = {}
	local made: { Instance } = {}
	local alive = true
	local paused = false
	local layerAlpha: { [string]: number } = {}
	local atlas = o.atlas
	local realm = o.realm
	local B = realm.biome

	local self = {} :: Ambient

	local function region(img: ImageLabel, name: string): boolean
		if atlas == nil then return false end
		local r = atlas.regions[name]
		if r == nil then return false end
		local k = atlas.k
		img.Image = atlas.id
		img.ImageRectOffset = Vector2.new(r[1] * k, r[2] * k)
		img.ImageRectSize = Vector2.new(r[3] * k, r[4] * k)
		return true
	end
	local function play(tw: Tween, delay: number)
		table.insert(tweens, tw)
		if delay <= 0 then
			if not paused then tw:Play() end
			return
		end
		task.delay(delay, function()
			if alive and not paused then tw:Play() end
		end)
	end
	-- wait that respects pausing and destruction; false when the ambient is gone
	local function waitFor(t: number): boolean
		local left = t
		while left > 0 do
			local dt = task.wait(math.min(left, 0.5))
			if not alive then return false end
			if not paused then left -= dt end
		end
		return alive
	end

	-- ---------------------------------------------------------------------------------------------- channels
	-- sine: base +- amp; start at whichever extreme comes next (closest to the closed form), reversing Sine InOut
	local function sine(target: Instance, prop: string, at: (v: number) -> any, amp: number, period: number, phase: number)
		local tMin = ((0.75 - phase) % 1) * period
		local tMax = ((0.25 - phase) % 1) * period
		local startLow = tMin <= tMax
		local from = if startLow then -amp else amp
		local to = -from
		;(target :: any)[prop] = at(from)
		local tw = TweenService:Create(target, TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { [prop] = at(to) })
		play(tw, math.min(tMin, tMax))
	end
	-- drift / scroll: linear from `from` to `to` (or back when speed < 0), looping; begins at the phase point
	local function drift(target: Instance, prop: string, at: (v: number) -> any, from: number, to: number, speed: number, v0: number)
		if speed == 0 or from == to then
			(target :: any)[prop] = at(v0)
			return
		end
		local a, b = from, to
		if speed < 0 then a, b = to, from end
		local span = math.abs(b - a)
		local loopTime = span / math.abs(speed)
		;(target :: any)[prop] = at(v0)
		local first = TweenService:Create(target, TweenInfo.new(math.max(0.01, math.abs(b - v0) / math.abs(speed)), Enum.EasingStyle.Linear), { [prop] = at(b) })
		local loop = TweenService:Create(target, TweenInfo.new(loopTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { [prop] = at(b) })
		table.insert(tweens, loop)
		first.Completed:Connect(function(state: Enum.PlaybackState)
			if state ~= Enum.PlaybackState.Completed or not alive then return end
			;(target :: any)[prop] = at(a)
			if not paused then loop:Play() end
		end)
		play(first, 0)
	end

	-- ---------------------------------------------------------------------------------------------- one sprite
	local function build(group: any, inst: any, layer: LayerInfo, container: Frame)
		local Lw, Lh = layer.w, layer.h
		local w = inst.s
		local hangs = group.hangs == true
		local len = inst.len or inst.h or inst.s
		local h = if hangs then len else (inst.h or inst.s)
		local baseA = if inst.a ~= nil then inst.a else 1
		local rot = inst.r or 0
		local root: GuiObject
		local img = Instance.new("ImageLabel")
		img.Name = "Img"
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.Active = false
		img.ScaleType = Enum.ScaleType.Stretch
		local regionName = group.regions[(inst.t or 0) + 1] or group.regions[1]
		if not region(img, regionName) then
			img:Destroy()
			return
		end
		if hangs then
			local pivot = Instance.new("Frame")
			pivot.Name = group.name
			pivot.BackgroundTransparency = 1
			pivot.BorderSizePixel = 0
			pivot.Active = false
			pivot.AnchorPoint = Vector2.new(0.5, 0.5)
			pivot.Position = UDim2.fromScale(inst.x / Lw, inst.y / Lh)
			pivot.Size = UDim2.fromScale(w / Lw, 2 * len / Lh)
			pivot.Rotation = rot
			img.Position = UDim2.fromScale(0, 0.5)
			img.Size = UDim2.fromScale(1, 0.5)
			img.Parent = pivot
			root = pivot
		else
			local wrap = Instance.new("Frame")
			wrap.Name = group.name
			wrap.BackgroundTransparency = 1
			wrap.BorderSizePixel = 0
			wrap.Active = false
			wrap.AnchorPoint = Vector2.new(0.5, 0.5)
			wrap.Position = UDim2.fromScale(inst.x / Lw, inst.y / Lh)
			wrap.Size = UDim2.fromScale(w / Lw, h / Lh)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(1, 1)
			img.Rotation = rot
			img.Parent = wrap
			root = wrap
		end
		local colored = group.color ~= nil
		local palette = group.palette
		img.ImageColor3 = if colored then rgb(group.color.realm)
			elseif palette then rgb(palette[((inst.c or 0) % #palette) + 1])
			else Color3.new(1, 1, 1)
		img.ImageTransparency = 1 - baseA * (layerAlpha[layer.id] or 1)
		local sp: Sprite = { group = group, inst = inst, layer = layer, root = root, img = img, colored = colored, alpha = baseA }
		root.Parent = container
		table.insert(made, root)
		table.insert(sprites, sp)

		local channels: { Channel } = inst.m or {}
		local hasGrad = false
		for _, m in channels do
			if m.ch == "grad" then hasGrad = true end
		end
		local grad: UIGradient? = nil
		if hasGrad then
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(0.38, 0.4),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.62, 0.4),
				NumberSequenceKeypoint.new(1, 0.55),
			})
			g.Offset = Vector2.new(0, 0)
			g.Parent = img
			grad = g
		end
		local uiScale: UIScale? = nil
		local function scaleObj(): UIScale
			if uiScale == nil then
				local u = Instance.new("UIScale")
				u.Parent = img
				uiScale = u
			end
			return uiScale :: UIScale
		end
		-- the rift glow gets a second copy for the hover boost
		if group.name == "rift_glow" then
			local boost = img:Clone()
			boost.Name = "Boost"
			boost.AnchorPoint = Vector2.new(0.5, 0.5)
			boost.Position = UDim2.fromScale(0.5, 0.5)
			boost.Size = UDim2.fromScale(1, 1)
			boost.Rotation = 0
			boost.ImageTransparency = 1
			for _, c in boost:GetChildren() do c:Destroy() end
			boost.Parent = img
			sp.boost = boost
		end

		if o.reduced then
			-- rest at the base: alpha a, no offset, gradient offset 0, drifts frozen at their phase
			for _, m in channels do
				if m.type == "drift" then
					local v = MapCamera.channel(m, 0)
					if m.ch == "x" then
						root.Position = UDim2.fromScale((inst.x + v) / Lw, inst.y / Lh)
					elseif m.ch == "y" then
						img.Position = UDim2.fromScale(img.Position.X.Scale, img.Position.Y.Scale + v / h)
					end
				end
			end
			return
		end

		-- pulse channels share one loop (period and phase are shared); flicker channels share another
		local pulses: { Channel } = {}
		local flickers: { Channel } = {}
		for _, m in channels do
			local ty = m.type
			local period = m.period or 1
			local phase = m.phase or 0
			if ty == "pulse" then
				table.insert(pulses, m)
			elseif ty == "flicker" then
				table.insert(flickers, m)
			elseif ty == "sine" then
				local amp = m.amp or 0
				if m.ch == "x" then
					sine(root, "Position", function(v: number): any return UDim2.fromScale((inst.x + v) / Lw, inst.y / Lh) end, amp, period, phase)
				elseif m.ch == "y" then
					if hangs then
						sine(root, "Position", function(v: number): any return UDim2.fromScale(inst.x / Lw, (inst.y + v) / Lh) end, amp, period, phase)
					else
						sine(img, "Position", function(v: number): any return UDim2.fromScale(0.5, 0.5 + v / h) end, amp, period, phase)
					end
				elseif m.ch == "rot" then
					local target: GuiObject = if hangs then root else img
					sine(target, "Rotation", function(v: number): any return rot + v end, amp, period, phase)
				elseif m.ch == "scale" then
					sine(scaleObj(), "Scale", function(v: number): any return 1 + v end, amp, period, phase)
				elseif m.ch == "alpha" then
					local k = layerAlpha[layer.id] or 1
					sine(img, "ImageTransparency", function(v: number): any return 1 - math.clamp(baseA + v, 0, 1) * k end, amp, period, phase)
				end
			elseif ty == "drift" then
				local from, to, speed = m.from or 0, m.to or 0, m.speed or 0
				local v0 = MapCamera.channel(m, 0)
				if m.ch == "x" then
					drift(root, "Position", function(v: number): any return UDim2.fromScale((inst.x + v) / Lw, inst.y / Lh) end, from, to, speed, v0)
				elseif m.ch == "y" then
					if hangs then
						drift(root, "Position", function(v: number): any return UDim2.fromScale(inst.x / Lw, (inst.y + v) / Lh) end, from, to, speed, v0)
					else
						drift(img, "Position", function(v: number): any return UDim2.fromScale(0.5, 0.5 + v / h) end, from, to, speed, v0)
					end
				end
			elseif ty == "scroll" and grad then
				local g = grad :: UIGradient
				local v0 = MapCamera.channel(m, 0)
				drift(g, "Offset", function(v: number): any return Vector2.new(0, v) end, -1, 1, 2 / period, v0)
			end
		end

		if #pulses > 0 then
			local lead = pulses[1]
			local period, dur = lead.period or 1, lead.dur or 1
			local phase = lead.phase or 0
			local function apply(which: string)
				for _, m in pulses do
					local v = if which == "a" then (m.a or 0) else (m.b or 0)
					if m.ch == "x" then
						root.Position = UDim2.fromScale((inst.x + v) / Lw, inst.y / Lh)
					elseif m.ch == "y" then
						img.Position = UDim2.fromScale(img.Position.X.Scale, 0.5 + v / h)
					elseif m.ch == "alpha" then
						img.ImageTransparency = 1 - math.clamp(v, 0, 1)
					elseif m.ch == "scale" then
						scaleObj().Scale = v
					end
				end
			end
			apply("b")
			task.spawn(function()
				if not waitFor(((1 - phase) % 1) * period) then return end
				while alive do
					apply("a")
					local ease = if lead.ease == "linear" then Enum.EasingStyle.Linear else Enum.EasingStyle.Quad
					local info = TweenInfo.new(dur, ease, Enum.EasingDirection.Out)
					for _, m in pulses do
						local b = m.b or 0
						local tw: Tween? = nil
						if m.ch == "x" then
							tw = TweenService:Create(root, info, { Position = UDim2.fromScale((inst.x + b) / Lw, inst.y / Lh) })
						elseif m.ch == "y" then
							tw = TweenService:Create(img, info, { Position = UDim2.fromScale(img.Position.X.Scale, 0.5 + b / h) })
						elseif m.ch == "alpha" then
							tw = TweenService:Create(img, info, { ImageTransparency = 1 - math.clamp(b, 0, 1) })
						elseif m.ch == "scale" then
							tw = TweenService:Create(scaleObj(), info, { Scale = b })
						end
						if tw then tw:Play() end
					end
					if not waitFor(period) then return end
				end
			end)
		end

		if #flickers > 0 then
			local lead = flickers[1]
			local slot, dur = lead.slot or 3, lead.dur or 0.1
			local jitter = 0
			for _, m in flickers do
				if m.out == "jitter" then jitter = m.amp or 0 end
			end
			img.ImageTransparency = 1
			task.spawn(function()
				local rng = Random.new(lead.seed or 1)
				while alive do
					local before = rng:NextNumber() * math.max(0, slot - dur)
					if not waitFor(before) then return end
					local dx = (rng:NextNumber() - 0.5) * 2 * jitter
					root.Position = UDim2.fromScale((inst.x + dx) / Lw, inst.y / Lh)
					if palette then img.ImageColor3 = rgb(palette[rng:NextInteger(1, #palette)]) end
					img.ImageTransparency = 1 - baseA
					if not waitFor(dur) then return end
					img.ImageTransparency = 1
					if not waitFor(math.max(0, slot - dur - before)) then return end
				end
			end)
		end
	end

	-- ---------------------------------------------------------------------------------------------- build
	if atlas then
		for _, group in realm.sprites do
			if o.reduced and group.rmHide then continue end
			local layer = o.layers[group.layer]
			local container = o.containers[group.layer]
			if not layer or not container then continue end
			local n = math.min(group.count[o.tier] or 0, #group.instances)
			for i = 1, n do
				build(group, group.instances[i], layer, container)
			end
		end
		-- the corrupt blooms: behind their layer's tiles, hidden until w.corrupt > 0
		for _, b in B.corrupt.bloom do
			local layer = o.layers[b.layer]
			local back = o.backs[b.layer]
			if not layer or not back then continue end
			local img = Instance.new("ImageLabel")
			img.Name = "Bloom"
			img.BackgroundTransparency = 1
			img.BorderSizePixel = 0
			img.Active = false
			if not region(img, "glow") then
				img:Destroy()
				continue
			end
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(b.at[1] / layer.w, b.at[2] / layer.h)
			img.Size = UDim2.fromScale(b.size[1] / layer.w, b.size[2] / layer.h)
			img.ImageColor3 = rgb(b.color)
			img.ImageTransparency = 1
			img.Visible = false
			img.Parent = back
			table.insert(made, img)
			table.insert(blooms, { img = img, alpha = b.alpha })
		end
	end

	-- ---------------------------------------------------------------------------------------------- API
	local lastCorrupt = 0
	function self.recolor(_: Ambient, w: Weights, C: Pt, z: number, V: Size)
		for _, b in blooms do
			local a = b.alpha * w.corrupt
			b.img.Visible = a > 0.001
			b.img.ImageTransparency = 1 - a
		end
		for _, sp in sprites do
			if not sp.colored then continue end
			local color = sp.group.color
			local p: Pt
			if w.corrupt > 0 or lastCorrupt > 0 then
				-- the world point under the sprite's centre on screen
				local L = sp.layer
				local q = MapCamera.localToScreen(L, C, z, V, { x = sp.inst.x, y = sp.inst.y })
				p = MapCamera.screenToWorld(C, z, V, q)
			else
				p = C
			end
			local c = MapCamera.biomeSpriteColor(color, w, B, p)
			sp.img.ImageColor3 = rgb(c)
		end
		lastCorrupt = w.corrupt
	end
	function self.setPaused(_: Ambient, v: boolean)
		if v == paused then return end
		paused = v
		for _, tw in tweens do
			if v then
				tw:Pause()
			elseif tw.PlaybackState == Enum.PlaybackState.Paused then
				tw:Play()
			end
		end
	end
	function self.setLayerAlpha(_: Ambient, layer: string, k: number)
		if layerAlpha[layer] == k then return end
		layerAlpha[layer] = k
		for _, sp in sprites do
			if sp.layer.id == layer then
				sp.root.Visible = k > 0.001
				sp.img.ImageTransparency = 1 - sp.alpha * k
			end
		end
	end
	function self.setRiftBoost(_: Ambient, a: number)
		for _, sp in sprites do
			local boost = sp.boost
			if boost then
				TweenService:Create(boost, TweenInfo.new(0.2), { ImageTransparency = 1 - math.clamp(a, 0, 1) }):Play()
			end
		end
	end
	function self.count(_: Ambient): number
		return #sprites + #blooms
	end
	function self.destroy(_: Ambient)
		alive = false
		for _, tw in tweens do tw:Cancel() end
		table.clear(tweens)
		for _, inst in made do inst:Destroy() end
		table.clear(made)
		table.clear(sprites)
		table.clear(blooms)
	end
	return self
end

return Ambient
