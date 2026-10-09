--!nonstrict
-- Vfx/Layers: the pooled render pieces behind every effect, the recipes that configure them, and curve helpers.
--
-- Everything hangs off ONE tiny anchored part ("PeckwoodVfx", 0.05 studs, Transparency 1) at the world origin:
-- attachments are moved with WorldCFrame, emitters fire with Emit(n) (Rate 0, so they cost nothing between bursts),
-- beams/trails/lights live on those attachments. No big invisible parts anywhere (they would hide the Occluded ink
-- Highlights behind them). Ball parts (domes) are parked far below the map when free.
--
-- An emitter is only handed out again after its particles have died (the owning effect releases it at its end), so
-- reconfiguring a pooled emitter never restyles live particles.
local RS = game:GetService("ReplicatedStorage")
local VfxAssets = require(RS:WaitForChild("Peckwood"):WaitForChild("VfxAssets"))

local Layers = {}

local FAR = CFrame.new(0, -25000, 0)
local NONE = Enum.ParticleFlipbookLayout.None
local ORIENT = {
	face = Enum.ParticleOrientation.FacingCamera,
	faceUp = Enum.ParticleOrientation.FacingCameraWorldUp,
	flat = Enum.ParticleOrientation.VelocityPerpendicular, -- tiny upward speed: the sprite lies flat on the ground
	vel = Enum.ParticleOrientation.VelocityParallel,
}

-- caps (live, across all effects); a layer that cannot get a piece is skipped, never errors
Layers.MAX = { emit = 160, att = 96, beam = 96, light = 10, ball = 10, trail = 12 }
local live = { emit = 0, att = 0, beam = 0, light = 0, ball = 0, trail = 0 }
local free = { emit = {}, att = {}, beam = {}, light = {}, ball = {}, trail = {} }

-- ---------------------------------------------------------------- root
local rootPart: BasePart? = nil
local partsFolder: Folder? = nil
function Layers.root(): BasePart
	if rootPart and rootPart.Parent then return rootPart end
	local p = Instance.new("Part")
	p.Name = "PeckwoodVfx"
	p.Size = Vector3.one * 0.05
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.CFrame = CFrame.new()
	p.Parent = workspace
	rootPart = p
	-- a pool whose root vanished is stale
	for k in free do free[k] = {} end
	for k in live do live[k] = 0 end
	return p
end
local function folder(): Folder
	if partsFolder and partsFolder.Parent then return partsFolder end
	local f = Instance.new("Folder")
	f.Name = "PeckwoodVfxParts"
	f.Parent = workspace
	partsFolder = f
	return f
end

-- ---------------------------------------------------------------- curves
-- seq(t0, v0, t1, v1, ...) -> NumberSequence (or seq(v) for a constant)
function Layers.seq(...: number): NumberSequence
	local a = { ... }
	if #a == 1 then return NumberSequence.new(a[1]) end
	local k = table.create(#a // 2)
	for i = 1, #a - 1, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(k)
end

local EASE = {
	lin = function(t) return t end,
	out = function(t) return 1 - (1 - t) ^ 3 end,
	out2 = function(t) return 1 - (1 - t) ^ 2 end,
	["in"] = function(t) return t * t end,
	inout = function(t) return t * t * (3 - 2 * t) end,
	back = function(t) local c1 = 1.7; return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end,
}
Layers.EASE = EASE

-- an eased v0 -> v1 curve baked into n + 1 keypoints (a NumberSequence is linear between at most 20 keys)
function Layers.curve(v0: number, v1: number, style: string?, n: number?): NumberSequence
	local f = EASE[style or "out"] or EASE.out
	local nk: number = math.clamp(n or 10, 1, 19)
	local k = table.create(nk + 1)
	for i = 0, nk do
		local t = i / nk
		table.insert(k, NumberSequenceKeypoint.new(t, math.max(0, v0 + (v1 - v0) * f(t))))
	end
	return NumberSequence.new(k)
end

-- cel "stepped fade": fully visible, then hard steps (no smooth ramp) e.g. steps({0.6, 0.45}, {0.8, 1})
function Layers.steps(...: { number }): NumberSequence
	local pts = { ... }
	local k = { NumberSequenceKeypoint.new(0, 0) }
	local prev = 0
	for _, p in pts do
		local t, v = p[1], p[2]
		table.insert(k, NumberSequenceKeypoint.new(t, prev))
		table.insert(k, NumberSequenceKeypoint.new(math.min(0.999, t + 0.004), v))
		prev = v
	end
	table.insert(k, NumberSequenceKeypoint.new(1, prev))
	return NumberSequence.new(k)
end

local function scaleSeq(s: NumberSequence, k: number): NumberSequence
	if k == 1 then return s end
	local out = table.create(#s.Keypoints)
	for _, kp in s.Keypoints do table.insert(out, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k)) end
	return NumberSequence.new(out)
end
Layers.scaleSeq = scaleSeq

local function asSeq(v: any, k: number?): NumberSequence
	local s = if typeof(v) == "NumberSequence" then v else NumberSequence.new(v or 1)
	return if k then scaleSeq(s, k) else s
end
local function asRange(v: any, k: number?): NumberRange
	k = k or 1
	if type(v) == "table" then return NumberRange.new(v[1] * k, (v[2] or v[1]) * k) end
	return NumberRange.new((v or 0) * k)
end

-- colour: a role / Color3 / hex, or a list { role, role, ... } = hard-stepped colour over life (cel), a
-- ColorSequence as is, or function(colorOf) -> ColorSequence (e.g. Layers.colorSteps with custom switch times)
local function asColor(v: any, colorOf: (any) -> Color3): ColorSequence
	if typeof(v) == "ColorSequence" then return v end
	if type(v) == "function" then return v(colorOf) end
	if type(v) == "table" then
		local n = #v
		if n == 1 then return ColorSequence.new(colorOf(v[1])) end
		local k = {}
		for i, role in v do
			local c = colorOf(role)
			local t0 = (i - 1) / n
			local t1 = i / n
			table.insert(k, ColorSequenceKeypoint.new(if i == 1 then 0 else t0 + 0.002, c))
			table.insert(k, ColorSequenceKeypoint.new(if i == n then 1 else t1, c))
		end
		return ColorSequence.new(k)
	end
	return ColorSequence.new(colorOf(v))
end
Layers.asColor = asColor

-- stepped colour with custom switch times: colorSteps(colorOf, {role, t}, {role, t}, ..., lastRole)
function Layers.colorSteps(colorOf, ...): ColorSequence
	local a = { ... }
	local k = {}
	local t0 = 0
	for i, p in a do
		local role, t = p, 1
		if type(p) == "table" then role, t = p[1], p[2] end
		if i == #a then t = 1 end
		local c = colorOf(role)
		table.insert(k, ColorSequenceKeypoint.new(t0, c))
		table.insert(k, ColorSequenceKeypoint.new(t, c))
		t0 = math.min(t + 0.002, 1)
	end
	return ColorSequence.new(k)
end

local function setBrightness(inst, v)
	pcall(function() inst.Brightness = v end)
end

-- ---------------------------------------------------------------- emitters
-- spec fields: tex (VfxAssets key), size (NumberSequence | number), life {min, max}, speed {min, max}, drag, accel,
-- spread (deg, number or {x, y}), rot {min, max}, rotSpeed {min, max}, trans (NumberSequence), color (see asColor),
-- light (LightEmission), lightInf (LightInfluence, default 0 = flat unlit cel colour), bright (Brightness), z (ZOffset),
-- squash, orient ("face" | "faceUp" | "flat" | "vel"), tilt (flat layers' spread, deg), fps {min, max} (Loop
-- flipbooks), startRandom, timeScale, mode (override FlipbookMode), dir (Enum.NormalId, default Top)
function Layers.maxLife(spec): number
	local l = spec.life or 1
	return if type(l) == "table" then (l[2] or l[1]) else l
end

local function newEmitter()
	local att = Instance.new("Attachment")
	att.Name = "VfxEmit"
	att.Parent = Layers.root()
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Enabled = true
	pe.LockedToPart = false
	pe.VelocityInheritance = 0
	pe.Parent = att
	return { att = att, pe = pe, ts = 1 }
end

function Layers.getEmitter()
	local e = table.remove(free.emit)
	if e and e.pe.Parent then live.emit += 1; return e end
	if live.emit >= Layers.MAX.emit then return nil end
	live.emit += 1
	return newEmitter()
end

function Layers.putEmitter(e, clear: boolean?)
	live.emit = math.max(0, live.emit - 1)
	local pe: ParticleEmitter = e.pe
	if clear then pe:Clear() end
	pe.TimeScale = 1
	if e.att.Parent then table.insert(free.emit, e) end
end

-- configure a pooled emitter from a spec. sc scales Size (and Speed when spec.speedScales); returns false when the
-- texture is not uploaded (the caller drops the layer)
function Layers.applyEmitter(e, spec, colorOf, sc: number?, ov): boolean
	local id = VfxAssets.id(spec.tex)
	if not id then return false end
	sc = sc or 1
	ov = ov or {}
	local pe: ParticleEmitter = e.pe
	local t = VfxAssets.tex[spec.tex]
	pe.Texture = id
	if t.layout then
		pe.FlipbookLayout = t.layout
		pe.FlipbookMode = spec.mode or t.mode
		if spec.fps then pe.FlipbookFramerate = asRange(spec.fps) end
		pe.FlipbookStartRandom = spec.startRandom == true
		pe.FlipbookBlendFrames = false
	else
		pe.FlipbookLayout = NONE
	end
	local orient = ov.orient or spec.orient or "face"
	pe.Orientation = ORIENT[orient] or ORIENT.face
	pe.Size = asSeq(ov.size or spec.size, sc)
	pe.Transparency = asSeq(ov.trans or spec.trans or 0)
	pe.Lifetime = asRange(ov.life or spec.life or 1)
	pe.Squash = asSeq(spec.squash or 0)
	pe.Rotation = asRange(spec.rot or { 0, 360 })
	pe.RotSpeed = asRange(spec.rotSpeed or 0)
	pe.Drag = spec.drag or 0
	pe.Acceleration = ov.accel or spec.accel or Vector3.zero
	pe.EmissionDirection = spec.dir or Enum.NormalId.Top
	if orient == "flat" then
		pe.Speed = NumberRange.new(0.0003)
		local tilt = spec.tilt or 2
		pe.SpreadAngle = Vector2.new(tilt, tilt)
		pe.Acceleration = Vector3.zero
		pe.Drag = 0
	else
		pe.Speed = asRange(ov.speed or spec.speed or 0, if spec.speedScales then sc else 1)
		local sp = ov.spread or spec.spread or 0
		pe.SpreadAngle = if type(sp) == "table" then Vector2.new(sp[1], sp[2]) else Vector2.new(sp, sp)
	end
	pe.Color = asColor(ov.color or spec.color or "mid", colorOf)
	pe.LightEmission = spec.light or 0
	pe.LightInfluence = spec.lightInf or 0
	setBrightness(pe, spec.bright or 1)
	pe.ZOffset = spec.z or 0
	e.ts = spec.timeScale or 1
	pe.TimeScale = e.ts
	return true
end

-- ---------------------------------------------------------------- plain attachments (beam / ring anchors)
function Layers.getAtt(): Attachment?
	local a = table.remove(free.att)
	if a and a.Parent then live.att += 1; return a end
	if live.att >= Layers.MAX.att then return nil end
	live.att += 1
	a = Instance.new("Attachment")
	a.Name = "VfxAnchor"
	a.Parent = Layers.root()
	return a
end
function Layers.putAtt(a: Attachment)
	live.att = math.max(0, live.att - 1)
	if a.Parent then table.insert(free.att, a) end
end

-- ---------------------------------------------------------------- beams
-- spec fields: tex (optional; a missing upload draws a solid beam unless texRequired), texMode, texLen, texSpeed,
-- face (FaceCamera, default true), segments, color, trans, light, lightInf, bright, z
function Layers.getBeam(): Beam?
	local b = table.remove(free.beam)
	if b and b.Parent then live.beam += 1; return b end
	if live.beam >= Layers.MAX.beam then return nil end
	live.beam += 1
	b = Instance.new("Beam")
	b.Enabled = false
	b.Parent = Layers.root()
	return b
end
function Layers.putBeam(b: Beam)
	live.beam = math.max(0, live.beam - 1)
	b.Enabled = false -- (attachments stay referenced; a disabled beam draws nothing and they are re-set on reuse)
	if b.Parent then table.insert(free.beam, b) end
end

function Layers.applyBeam(b: Beam, spec, colorOf): boolean
	local id = spec.tex and VfxAssets.id(spec.tex)
	if spec.tex and spec.texRequired and not id then return false end
	b.Texture = id or ""
	b.TextureMode = spec.texMode or Enum.TextureMode.Wrap
	b.TextureLength = spec.texLen or 1
	b.TextureSpeed = spec.texSpeed or 0
	b.FaceCamera = spec.face ~= false
	b.Segments = spec.segments or 1
	b.Color = asColor(spec.color or "mid", colorOf)
	b.Transparency = asSeq(spec.trans or 0)
	b.LightEmission = spec.light or 0
	b.LightInfluence = spec.lightInf or 0
	setBrightness(b, spec.bright or 1)
	b.ZOffset = spec.z or 0
	b.CurveSize0 = 0
	b.CurveSize1 = 0
	b.Width0 = 0
	b.Width1 = 0
	b.Enabled = true
	return true
end

-- ---------------------------------------------------------------- lights
function Layers.getLight()
	local e = table.remove(free.light)
	if e and e.att.Parent then live.light += 1; return e end
	if live.light >= Layers.MAX.light then return nil end
	live.light += 1
	local att = Instance.new("Attachment")
	att.Name = "VfxLight"
	att.Parent = Layers.root()
	local l = Instance.new("PointLight")
	l.Shadows = false
	l.Enabled = false
	l.Parent = att
	return { att = att, light = l }
end
function Layers.putLight(e)
	live.light = math.max(0, live.light - 1)
	local l: PointLight = e.light
	l.Enabled = false
	l.Brightness = 0
	if e.att.Parent then table.insert(free.light, e) end
end

-- ---------------------------------------------------------------- trails (a pair of attachments + Trail)
function Layers.getTrail()
	local e = table.remove(free.trail)
	if e and e.trail.Parent then live.trail += 1; return e end
	if live.trail >= Layers.MAX.trail then return nil end
	live.trail += 1
	local a0 = Instance.new("Attachment")
	a0.Name = "VfxTrail0"
	a0.Parent = Layers.root()
	local a1 = Instance.new("Attachment")
	a1.Name = "VfxTrail1"
	a1.Parent = Layers.root()
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Enabled = false
	tr.Parent = Layers.root()
	return { a0 = a0, a1 = a1, trail = tr }
end
function Layers.putTrail(e)
	live.trail = math.max(0, live.trail - 1)
	local tr: Trail = e.trail
	tr.Enabled = false
	tr:Clear()
	if e.trail.Parent then table.insert(free.trail, e) end
end

-- ---------------------------------------------------------------- ball parts (domes / flash spheres)
function Layers.getBall(): BasePart?
	local p = table.remove(free.ball)
	if p and p.Parent then live.ball += 1; return p end
	if live.ball >= Layers.MAX.ball then return nil end
	live.ball += 1
	p = Instance.new("Part")
	p.Name = "VfxBall"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.CFrame = FAR
	p.Parent = folder()
	return p
end
function Layers.putBall(p: BasePart)
	live.ball = math.max(0, live.ball - 1)
	p.Transparency = 1
	p.CFrame = FAR -- parked far away: an invisible ball must never sit in front of an outlined model
	if p.Parent then table.insert(free.ball, p) end
end

-- ---------------------------------------------------------------- helpers
-- a CFrame at pos whose +Y (an emitter's Top direction) points along dir
function Layers.upTo(pos: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-4 then return CFrame.new(pos) end
	dir = dir.Unit
	local ref = if math.abs(dir.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local right = ref:Cross(dir).Unit
	return CFrame.fromMatrix(pos, right, dir)
end

-- a flat attachment frame for beam rings: Axis (X) = +Z (tangent at the ring's -X / +X points), up = world up
function Layers.ringFrame(pos: Vector3): CFrame
	return CFrame.fromMatrix(pos, Vector3.zAxis, Vector3.yAxis)
end

-- NumberSequence that shows a beam from its start to progress p (0..1), hidden after: draws a line "in"
function Layers.trace(p: number, base: number?): NumberSequence
	local b: number = base or 0
	if p <= 0.002 then return NumberSequence.new(1) end
	if p >= 0.996 then return NumberSequence.new(b) end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, b),
		NumberSequenceKeypoint.new(p, b),
		NumberSequenceKeypoint.new(p + 0.003, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function Layers.stats()
	return table.clone(live)
end

return Layers
