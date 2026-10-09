--!nonstrict
-- Vfx: client VFX engine for Peckwood (cel / toy-diorama style). See HANDOUT.md "VFX (claude/peckwood-vfx)".
--
--   Vfx.play(name, where, opts?) -> handle?   where = Vector3 | CFrame | BasePart | Model | Attachment
--       opts: rarity ("Common".."Mythic" | 1-6), color (Color3 | hex | palette name), scale, follow (Instance or
--       () -> Vector3), force (play even if textures are missing), onDone, + per-effect fields (see each effect)
--   Vfx.can(name)            true when the effect's key textures are uploaded (callers keep a fallback otherwise)
--   Vfx.stop(handle)         end an effect early (clears its particles, returns its pieces to the pools)
--   Vfx.shake / Vfx.push / Vfx.flash   camera feel (CamFx), Vfx.camera(cf, fov, dt) is the hook Main calls
--   Vfx.register(name, def)  def = { run = function(fx, cf, opts), cap = n, needs = { texture keys } }
--
-- Effects are timelines run by ONE RenderStepped connection that exists only while an effect is alive (no per-frame
-- work when idle). Every render piece comes from the Layers pools and goes back when the effect ends. Counts scale
-- with the player's graphics quality; concurrent effects are capped per effect and in total.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")

local VfxAssets = require(RS:WaitForChild("Peckwood"):WaitForChild("VfxAssets"))
local Layers = require(script:WaitForChild("Layers"))
local Palette = require(script:WaitForChild("Palette"))
local CamFx = require(script:WaitForChild("CamFx"))
local MeshFx = require(script:WaitForChild("MeshFx"))

local Vfx = {}
Vfx.Layers = Layers
Vfx.Palette = Palette
Vfx.CamFx = CamFx
Vfx.MeshFx = MeshFx
Vfx.MAX_ACTIVE = 48
-- size multiplier = clamp(camera distance / 290, 1, 2.4) (QA 2026-10-09: an Epic hatch reads right at zoom 7)
Vfx.VIEW_REF, Vfx.VIEW_MAX = 290, 2.4

local defs = {}
local active = {}
local conn: RBXScriptConnection? = nil

-- ---------------------------------------------------------------- graphics quality
-- 1 on high, ~0.7 on medium, ~0.4 on low; Automatic counts as medium-high. Bursts call fx:n(count).
local quality = 0.8
local function readQuality()
	local ok, lvl = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
	if not ok or lvl == nil or lvl == Enum.SavedQualitySetting.Automatic then
		quality = 0.8
		return
	end
	local n = lvl.Value
	quality = if n <= 3 then 0.4 elseif n <= 6 then 0.7 else 1
end
readQuality()
pcall(function()
	UserSettings():GetService("UserGameSettings"):GetPropertyChangedSignal("SavedQualityLevel"):Connect(readQuality)
end)
function Vfx.quality(): number return quality end
function Vfx.count(n: number, essential: boolean?): number
	local c = math.floor(n * quality + 0.5)
	return if essential then math.max(1, c) else c
end

-- ---------------------------------------------------------------- the effect object (fx) effects are written against
local Fx = {}
Fx.__index = Fx

local function toCFrame(where: any): CFrame
	local t = typeof(where)
	if t == "CFrame" then return where end
	if t == "Vector3" then return CFrame.new(where) end
	if t == "Instance" then
		if where:IsA("Attachment") then return CFrame.new(where.WorldPosition) end
		if where:IsA("BasePart") then return CFrame.new(where.Position) end
		if where:IsA("Model") then return CFrame.new(where:GetPivot().Position) end
	end
	return CFrame.new()
end

-- current origin (follows opts.follow if given)
function Fx:pos(): Vector3 return self.cf.Position end

function Fx:col(role: any): Color3 return Palette.color(self.pal, role) end

function Fx:n(count: number, essential: boolean?): number return Vfx.count(count, essential) end

-- schedule fn at effect time t (effect time pauses during hit-stop)
function Fx:at(t: number, fn: () -> ())
	local ev = self.events
	local i = #ev
	while i > 0 and ev[i][1] > t do i -= 1 end
	if i < self.ev - 1 then i = self.ev - 1 end -- never insert behind what already ran
	table.insert(ev, i + 1, { t, fn })
	if t > self.life then self.life = t end
end

-- per-frame function(t, dt) while it returns nothing; return true to stop it
function Fx:tick(fn: (number, number) -> boolean?)
	table.insert(self.tickers, fn)
end

function Fx:extend(t: number)
	if t > self.life then self.life = t end
end

function Fx:cleanup(fn: () -> ())
	table.insert(self.cleanups, fn)
end

-- Emit n particles of `spec` at `where` (Vector3 / CFrame; a CFrame's +Y is the emission direction).
-- One emitter per spec (or per ov.tag) per effect, so repeated bursts reuse it. Returns the emitter entry or nil.
function Fx:emitter(spec, ov)
	local key = (ov and ov.tag) or spec
	local e = self.emitters[key]
	if e == false then return nil end
	if e then return e end
	e = Layers.getEmitter()
	if not e then return nil end
	e.noHold = spec.noHold == true -- hero flashes keep playing through the hit-stop
	if not Layers.applyEmitter(e, spec, self.colorOf, (ov and ov.scale or 1) * (spec.noScale and 1 or self.scale), ov) then
		Layers.putEmitter(e)
		self.emitters[key] = false
		return nil
	end
	self.emitters[key] = e
	return e
end

function Fx:emit(spec, where: any, n: number, ov)
	if n <= 0 then return nil end
	local e = self:emitter(spec, ov)
	if not e then return nil end
	local att: Attachment, pe: ParticleEmitter = e.att, e.pe
	att.WorldCFrame = if typeof(where) == "CFrame" then where else CFrame.new(where :: Vector3)
	pe:Emit(n)
	self:extend(self.t + (ov and ov.life and (type(ov.life) == "table" and ov.life[2] or ov.life) or Layers.maxLife(spec)) + 0.05)
	return e
end

-- emit 1 particle along each of n random directions on a sphere (biased up by `lift`): a radial burst. This is the
-- Sphere-surface-outward shape without a shape Part (an invisible Part would hide the Occluded ink Highlights).
function Fx:emitSphere(spec, centre: Vector3, n: number, lift: number?, ov)
	for _ = 1, n do
		local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1 + (lift or 0), math.random() * 2 - 1)
		if d.Magnitude < 1e-3 then d = Vector3.yAxis end
		self:emit(spec, Layers.upTo(centre, d), 1, ov)
	end
end

-- emit 1 particle along each of n directions spread round a horizontal circle (tilted up by `up`): a radial ring
function Fx:emitRadial(spec, centre: Vector3, n: number, up: number?, ov, jitter: number?)
	local a0 = math.random() * math.pi * 2
	for i = 1, n do
		local a = a0 + i / n * math.pi * 2 + (math.random() - 0.5) * (jitter or 0.3)
		local dir = Vector3.new(math.cos(a), up or 0.2, math.sin(a))
		self:emit(spec, Layers.upTo(centre, dir), 1, ov)
	end
end

-- a beam between two points. Returns a handle { beam, a0, a1, set(p0, p1, w0, w1?) } or nil
function Fx:beam(spec, p0: Vector3, p1: Vector3)
	local b = Layers.getBeam()
	if not b then return nil end
	local a0, a1 = Layers.getAtt(), Layers.getAtt()
	if not (a0 and a1) or not Layers.applyBeam(b, spec, self.colorOf) then
		Layers.putBeam(b)
		if a0 then Layers.putAtt(a0) end
		if a1 then Layers.putAtt(a1) end
		return nil
	end
	a0.WorldCFrame = CFrame.new(p0)
	a1.WorldCFrame = CFrame.new(p1)
	b.Attachment0 = a0
	b.Attachment1 = a1
	table.insert(self.beams, b)
	table.insert(self.atts, a0)
	table.insert(self.atts, a1)
	local h = { beam = b, a0 = a0, a1 = a1 }
	function h.set(q0: Vector3?, q1: Vector3?, w0: number?, w1: number?)
		if q0 then a0.WorldCFrame = CFrame.new(q0) end
		if q1 then a1.WorldCFrame = CFrame.new(q1) end
		if w0 then b.Width0 = w0; b.Width1 = w1 or w0 end
	end
	return h
end

-- animate one pooled mesh shape (Vfx/MeshFx: Creator Store mesh assets, 0 EditableMeshes) for `life` seconds.
-- Returns a handle, or nil when the mesh is not available (not loaded / failed / capped): the caller then plays its
-- particle layer instead.
--   at       Vector3 | () -> Vector3        where it sits (a function follows a moving subject)
--   face     "camera" (billboard: a "plane" shape faces the camera, then leans by `tilt` about its X)
--            | "flat" (a "plane" shape lies on the ground) | "up" (dome / tornado / wall stand on their axis)
--   tilt, yaw  billboard lean (rad); roll = start angle; spin, spinEnd = rad/s (eases from spin to spinEnd)
--   r = { from, to } radius in studs (half the in-plane extent), eased by rEase ("out") over rInT of the life (0.6)
--   z = { from, to } studs along the normal / axis (thickness for plane shapes, HEIGHT for up shapes), eased by zEase
--       ("in"): shrinking it is the "fade by thinning"; or zFn(u, r) -> studs; nil keeps the mesh's proportion
--   xy(u) -> (xMul, yMul) squash of the in-plane directions (thin a crescent out, sweep a star gleam)
--   lift = keep its bottom on `at` (ground pieces); color = palette role; material (Neon)
--   alpha = { { u, transparency }, ... } hard steps
function Fx:mesh(kind: string, a)
	local p = MeshFx.get(kind)
	if not p then return nil end
	table.insert(self.meshParts, { kind = kind, part = p })
	p.Material = a.material or Enum.Material.Neon
	p.Color = self:col(a.color or "mid")
	p.Transparency = 1
	local corr = MeshFx.corr(kind)
	local up = a.face == "up"
	local t0 = self.t
	local life = a.life or 0.5
	local spin = a.roll or math.random() * math.pi * 2
	local w0, w1 = a.spin or 0, a.spinEnd or a.spin or 0
	local alpha = a.alpha or { { 0, 0 }, { 0.7, 0.45 }, { 0.88, 1 } }
	local rE = Layers.EASE[a.rEase or "out"] or Layers.EASE.out
	local zE = Layers.EASE[a.zEase or "in"] or Layers.EASE["in"]
	local rr, zz = a.r or { 1, 1 }, a.z
	local function step(t: number, dt: number): boolean?
		local u = math.clamp((t - t0) / life, 0, 1)
		local r = math.max(0.01, rr[1] + (rr[2] - rr[1]) * rE(math.clamp(u / (a.rInT or 0.6), 0, 1)))
		local z = nil
		if a.zFn then z = a.zFn(u, r) elseif zz then z = zz[1] + (zz[2] - zz[1]) * zE(u) end
		if z then z = math.max(z, 0.01) end
		spin += (w0 + (w1 - w0) * Layers.EASE.out2(u)) * dt
		local tr = 1
		for _, k in alpha do
			if u >= k[1] then tr = k[2] end
		end
		local xm, ym = 1, 1
		if a.xy then xm, ym = a.xy(u) end
		local size = MeshFx.sizeFor(kind, 2 * r, z, xm, ym)
		local pos = if type(a.at) == "function" then a.at() else a.at
		local cf
		if a.face == "camera" then
			local cam = workspace.CurrentCamera
			local cp = if cam then cam.CFrame.Position else pos + Vector3.new(0, 30, 24)
			cf = CFrame.lookAt(pos, cp) * CFrame.Angles(0, 0, spin) * CFrame.Angles(a.tilt or 0, a.yaw or 0, 0)
		elseif a.face == "flat" then
			cf = CFrame.new(pos) * CFrame.Angles(0, spin, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		else
			cf = CFrame.new(pos) * CFrame.Angles(0, spin, 0)
		end
		if a.lift then cf += Vector3.new(0, MeshFx.halfAxis(kind, size), 0) end
		p.Size = size
		p.CFrame = cf * corr
		p.Transparency = tr
		if u >= 1 then
			p.Transparency = 1
			p.CFrame = CFrame.new(0, -25000, 0) -- park now: an invisible mesh must not sit in front of outlined models
			return true
		end
		return nil
	end
	step(self.t, 0)
	self:tick(step)
	self:extend(self.t + life)
	return { part = p, up = up }
end

function Fx:light(pos: Vector3, color: any, range: number, brightness: number)
	local e = Layers.getLight()
	if not e then return nil end
	e.att.WorldCFrame = CFrame.new(pos)
	local l: PointLight = e.light
	l.Color = self:col(color)
	l.Range = range
	l.Brightness = brightness
	l.Enabled = true
	table.insert(self.lights, e)
	return e
end

function Fx:trail(spec)
	local e = Layers.getTrail()
	if not e then return nil end
	local tr: Trail = e.trail
	local id = spec.tex and VfxAssets.id(spec.tex)
	tr.Texture = id or ""
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.FaceCamera = true
	tr.Lifetime = spec.life or 0.3
	tr.MinLength = 0.05
	tr.Color = Layers.asColor(spec.color or "mid", self.colorOf)
	tr.Transparency = spec.trans or NumberSequence.new(0)
	tr.WidthScale = spec.widthScale or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	tr.LightEmission = spec.light or 0
	tr.LightInfluence = spec.lightInf or 0
	pcall(function() tr.Brightness = spec.bright or 1 end)
	tr:Clear()
	table.insert(self.trails, e)
	return e
end

function Fx:ball(color: any, material: Enum.Material?)
	local p = Layers.getBall()
	if not p then return nil end
	p.Material = material or Enum.Material.Neon
	p.Color = self:col(color)
	table.insert(self.balls, p)
	return p
end

-- hit-stop: freeze this effect (timeline, tickers and its particles) for d real seconds; the camera keeps shaking
function Fx:hitstop(d: number)
	if d <= 0 then return end
	self.hold = math.max(self.hold, d)
	for _, e in self.emitters do
		if e and not e.noHold then e.pe.TimeScale = 0 end
	end
end

function Fx:shake(amp: number, dur: number?) CamFx.shake(amp, dur) end
function Fx:flash(color: any, strength: number, dur: number?) CamFx.flash(self:col(color), strength, dur) end
function Fx:push(target: Vector3, amount: number, inT: number, hold: number, outT: number, pull: number?)
	CamFx.push(target, amount, inT, hold, outT, pull)
end

-- push-in that frames `target` with about `halfH` studs above and below it at the current zoom; returns the FOV
-- fraction used (clamped to minA..maxA). Effects call it before sizing so fx.view can follow the pushed framing.
function Fx:frame(target: Vector3, halfH: number, minA: number, maxA: number, inT: number, hold: number, outT: number, pull: number?): number
	local fov = CamFx.baseFov or 11
	local d = math.max(1, self.camDist)
	local need = 2 * math.deg(math.atan(halfH / d))
	local amount = math.clamp(1 - need / fov, minA, maxA)
	CamFx.push(target, amount, inT, hold, outT, pull or 0.8)
	return amount
end

-- the camera-distance size multiplier for a given distance (Vfx.VIEW_REF / VIEW_MAX)
function Fx:viewFor(dist: number): number
	return math.clamp(dist / Vfx.VIEW_REF, 1, Vfx.VIEW_MAX)
end

-- ---------------------------------------------------------------- scheduler
local function release(fx, clear: boolean)
	for _, e in fx.emitters do
		if e then Layers.putEmitter(e, clear) end
	end
	for _, b in fx.beams do Layers.putBeam(b) end
	for _, a in fx.atts do Layers.putAtt(a) end
	for _, e in fx.lights do Layers.putLight(e) end
	for _, e in fx.trails do Layers.putTrail(e) end
	for _, p in fx.balls do Layers.putBall(p) end
	for _, m in fx.meshParts do MeshFx.put(m.kind, m.part) end
	fx.emitters, fx.beams, fx.atts, fx.lights, fx.trails, fx.balls, fx.meshParts = {}, {}, {}, {}, {}, {}, {}
	for _, fn in fx.cleanups do
		local ok, err = pcall(fn)
		if not ok then warn("[Vfx] cleanup " .. fx.name .. ": " .. tostring(err)) end
	end
	fx.cleanups = {}
end

local function finish(fx, early: boolean)
	if fx.dead then return end
	fx.dead = true
	local ok, err = pcall(release, fx, early) -- a broken piece must never take the scheduler down
	if not ok then warn("[Vfx] release " .. fx.name .. ": " .. tostring(err)) end
	if fx.opts.onDone then task.spawn(fx.opts.onDone, early) end
end

local function step(dt: number)
	for i = #active, 1, -1 do
		local fx = active[i]
		if fx.dead then
			table.remove(active, i)
			continue
		end
		if fx.follow then
			local ok, p = pcall(fx.follow)
			if ok and typeof(p) == "Vector3" then fx.cf = CFrame.new(p) end
		end
		if fx.hold > 0 then
			fx.hold -= dt
			if fx.hold <= 0 then
				for _, e in fx.emitters do
					if e then e.pe.TimeScale = e.ts end
				end
			end
			continue
		end
		fx.t += dt
		local ev = fx.events
		while fx.ev <= #ev and ev[fx.ev][1] <= fx.t do
			local f = ev[fx.ev][2]
			fx.ev += 1
			local ok, err = pcall(f)
			if not ok then warn("[Vfx] " .. fx.name .. ": " .. tostring(err)) end
			if fx.dead then break end
		end
		if fx.dead then continue end
		for k = #fx.tickers, 1, -1 do
			local ok, res = pcall(fx.tickers[k], fx.t, dt)
			if not ok then
				warn("[Vfx] " .. fx.name .. " tick: " .. tostring(res))
				table.remove(fx.tickers, k)
			elseif res == true then
				table.remove(fx.tickers, k)
			end
		end
		if fx.t >= fx.life and fx.ev > #ev and #fx.tickers == 0 then
			finish(fx, false)
			table.remove(active, i)
		end
	end
	if #active == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

-- ---------------------------------------------------------------- public API
function Vfx.register(name: string, def)
	defs[name] = def
end

function Vfx.names(): { string }
	local out = {}
	for n in defs do table.insert(out, n) end
	table.sort(out)
	return out
end

function Vfx.can(name: string): boolean
	local def = defs[name]
	if not def then return false end
	for _, key in def.needs or {} do
		if not VfxAssets.has(key) then return false end
	end
	return true
end

function Vfx.play(name: string, where: any, options: { [string]: any }?)
	local def = defs[name]
	if not def then
		warn("[Vfx] unknown effect " .. tostring(name))
		return nil
	end
	local opts: { [string]: any } = options or {}
	if not opts.force and not Vfx.can(name) then return nil end
	local n, oldest = 0, nil
	for _, fx in active do
		if fx.name == name and not fx.dead then
			n += 1
			oldest = oldest or fx
		end
	end
	if def.cap and n >= def.cap then
		if def.replaceOldest and oldest then Vfx.stop(oldest) else return nil end
	end
	if #active >= Vfx.MAX_ACTIVE then return nil end
	local pal = Palette.get(opts.palette or opts.rarity or opts.color or def.palette or "Common")
	local fx = setmetatable({
		name = name, opts = opts, pal = pal, scale = opts.scale or 1, tier = pal.tier or 1,
		t = 0, life = 0, hold = 0, ev = 1, events = {}, tickers = {}, cleanups = {},
		emitters = {}, beams = {}, atts = {}, lights = {}, trails = {}, balls = {}, meshParts = {}, dead = false,
		cf = toCFrame(where),
	}, Fx)
	if opts.rarity then fx.tier = Palette.tier(opts.rarity) end
	-- readable at any zoom: hero sizes follow the camera distance (effects may re-derive it after a push-in)
	local cam = workspace.CurrentCamera
	CamFx.readBase()
	fx.camDist = if cam then (cam.CFrame.Position - fx.cf.Position).Magnitude else Vfx.VIEW_REF
	fx.view = opts.view or fx:viewFor(fx.camDist)
	fx.colorOf = function(role) return Palette.color(fx.pal, role) end -- effects may swap fx.pal at the start of run
	local f = opts.follow
	if typeof(f) == "Instance" then
		fx.follow = function() return toCFrame(f).Position end
	elseif type(f) == "function" then
		fx.follow = f
	end
	local ok, err = pcall(def.run, fx, fx.cf, opts)
	if not ok then
		warn("[Vfx] " .. name .. " failed to start: " .. tostring(err))
		finish(fx, true)
		return nil
	end
	table.insert(active, fx)
	if not conn then conn = RunService.RenderStepped:Connect(step) end
	return fx
end

function Vfx.stop(fx)
	if not fx or fx.dead then return end
	finish(fx, true)
end

function Vfx.stopAll()
	for _, fx in active do finish(fx, true) end
end

function Vfx.activeCount(): number
	local n = 0
	for _, fx in active do if not fx.dead then n += 1 end end
	return n
end

Vfx.shake = CamFx.shake
Vfx.push = CamFx.push
Vfx.flash = CamFx.flash
-- (kept for old call sites: the camera feel now runs from CamFx's own render step, so this is a passthrough)
function Vfx.camera(cf: CFrame, fov: number, _dt: number?): (CFrame, number)
	return cf, fov
end

-- warm the texture cache so the first effect does not pop in
function Vfx.preload()
	local ids = VfxAssets.all()
	if #ids == 0 then return end
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(ids) end) end)
end

-- ---------------------------------------------------------------- effects
local Effects = script:WaitForChild("Effects")
for _, m in Effects:GetChildren() do
	if m:IsA("ModuleScript") then
		local ok, def = pcall(require, m)
		if ok and type(def) == "table" and def.run then
			Vfx.register(def.name or m.Name, def)
		else
			warn("[Vfx] effect module " .. m.Name .. " failed: " .. tostring(def))
		end
	end
end

-- Main.client.luau calls this once: preload + hook-ups + the dev preview (_G.__vfx)
function Vfx.start(remotes: Instance?)
	Vfx.preload()
	MeshFx.warm() -- Creator Store mesh shapes, loaded in the background (particles cover until they exist)
	local ok, err = pcall(function() require(script:WaitForChild("Hooks")).start(Vfx, remotes) end)
	if not ok then warn("[Vfx] hooks: " .. tostring(err)) end
end

return Vfx
