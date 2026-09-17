# The Roblox 3D Math Toolkit: CFrame, Vector3, Quaternions, Splines, and Numerics

Everything hard in Roblox Studio — procedural mesh generation, camera rigs, IK, VFX,
projectile physics, path following — bottoms out in the same small pile of 3D math.
This chapter makes that pile total: what the engine actually gives you (verified against
`Roblox/creator-docs`, the repository the Creator Hub reference is generated from, and
against the Luau VM headers), and what you have to write yourself.

Every API signature below was read out of the generated reference YAML, not from memory.
Where a thing does **not** exist (and several things people "remember" do not), it is
called out explicitly.

---

## TL;DR for builders

- **A `CFrame` is a 3×4 matrix**: a 3×3 rotation matrix plus a translation column. World
  space is **right-handed** with **+X right, +Y up, +Z backward** — so *forward is −Z*,
  which is exactly why `LookVector == -ZVector`.
- **`GetComponents()` returns `x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22`** —
  position first, then the 3×3 in **row-major** order. The *columns* are the basis
  vectors: col 0 = `RightVector`, col 1 = `UpVector`, col 2 = `ZVector` = `-LookVector`.
- **`cf1 * cf2` applies `cf2` in `cf1`'s local space, and is not commutative.**
  `part.CFrame * CFrame.new(0, 0, -5)` moves 5 studs *forward for the part*;
  `CFrame.new(0, 0, -5) * part.CFrame` moves 5 studs along *world* −Z and then rotates.
- **`cf1:Inverse() * cf2` is the one idiom that solves most problems.** It is the
  transform of `cf2` expressed in `cf1`'s frame — welds, relative offsets, "where is the
  mouse relative to the gun", recording and replaying animations, all of it.
- **`CFrame.Angles` is `fromEulerAnglesXYZ` (Rx·Ry·Rz); `fromOrientation` is
  `fromEulerAnglesYXZ` (Ry·Rx·Rz).** `BasePart.Orientation` is **degrees in YXZ order**.
  Mixing the two conventions is the single most common "my rotation is wrong" bug.
- **Gimbal lock is concrete, not abstract**: with XYZ order, once the middle (Y) angle hits
  ±90° the matrix depends only on `rx + rz`. You lose a degree of freedom and
  `:ToEulerAnglesXYZ()` cannot recover what you put in. Store rotations as CFrames or
  quaternions; use Euler angles only at the UI boundary.
- **`CFrame:Lerp` slerps the rotation** (constant angular speed, shortest arc) and lerps
  the position. That is why it never "spins the long way" and why it beats interpolating
  Euler angles.
- **`Vector3.Unit` on a zero vector returns NaN** — documented, not a rumor. Every
  normalization of a vector that *could* be zero needs a magnitude guard.
- **Naive `x = x:Lerp(target, 0.1)` per frame is a frame-rate-dependent bug.** Use
  `alpha = 1 - math.exp(-k * dt)` (or `1 - 2^(-dt/halfLife)`), which makes the decay
  invariant to frame rate.
- **`Random` has no `NextGaussian`.** It has `NextInteger`, `NextNumber`, `NextUnitVector`,
  `Shuffle`, `Clone`. Write Box–Muller yourself — and guard `log(0)`, because
  `NextNumber()` is documented as **inclusive of both 0 and 1**.
- **`Random:NextUnitVector()` is documented as uniform over the unit sphere** — use it
  instead of the naive "three randoms then normalize", which is biased toward cube
  diagonals.
- **`math.noise` is Perlin**, deterministic, returns *about* −1..1 (not guaranteed),
  returns exactly **0 at integer coordinates**, and **repeats with period 256 per axis**.
- **Roblox stores transforms as 32-bit floats even though Luau numbers are doubles.**
  Float32 ULP is ~`x * 2^-23`: ~0.002 studs at 16k, ~0.125 studs at 1M, and **1.0 stud at
  8,388,608** — past which positions are integers only. Keep gameplay near the origin.
- **Rotation matrices drift.** `BasePart.CFrame` re-orthonormalizes on assignment, but
  other CFrame-consuming APIs do not — call `:Orthonormalize()` on any CFrame you build
  by repeated multiplication.
- **Two built-ins most people miss**: `CFrame.fromRotationBetweenVectors(from, to)`
  (shortest-arc rotation, no quaternion math needed) and `TweenService:SmoothDamp`
  (a real critically-damped spring, returns `(newValue, newVelocity)`).

---

## 1. CFrame fundamentals

### 1.1 What a CFrame actually is

A `CFrame` ("coordinate frame") is a rigid-body transform: a rotation **R** (3×3,
orthonormal, determinant +1) and a translation **p** (3×1), stored together as a 3×4
matrix. Transforming a point is:

```
world = R * local + p
```

Laid out, with the component names Roblox uses:

```
        | R00  R01  R02 |   | x |
  cf =  | R10  R11  R12 | , | y |
        | R20  R21  R22 |   | z |
```

The docs state this directly: "`CFrame` stores 3D rotation data in a 3×3 **rotation
matrix**. These values are returned by the `CFrame:GetComponents()` function after the
`x`, `y` and `z` positional values."

### 1.2 The component order — verified exactly

```lua
local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()
```

Position first (3 values), then the nine rotation entries in **row-major** order.
`CFrame:components()` is an alias for the same thing. The 12-argument constructor
`CFrame.new(x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22)` takes them back in the
same order — `GetComponents` is documented as "the reverse of the 12-argument
`CFrame.new()` constructor", so this round-trips exactly:

```lua
local function roundTrip(cf: CFrame): CFrame
	return CFrame.new(cf:GetComponents())
end
```

### 1.3 Basis vectors are the matrix *columns*

This is the part people get backwards. `GetComponents` hands you the matrix row by row,
but the direction vectors are the **columns**:

| Column | Entries | Property |
|---|---|---|
| 0 | `R00, R10, R20` | `RightVector` (= `XVector`) |
| 1 | `R01, R11, R21` | `UpVector` (= `YVector`) |
| 2 | `R02, R12, R22` | `ZVector` = **`-LookVector`** |

The reference makes the negation explicit: `LookVector` is "equivalent to the negated
`ZVector` or the negated third column of the rotation matrix." For an identity CFrame,
`cf.LookVector` prints `(-0, -0, -1)` and `cf.ZVector` prints `(0, 0, 1)`.

```lua
local function basis(cf: CFrame)
	local _, _, _, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()
	local right = Vector3.new(R00, R10, R20)  -- == cf.RightVector
	local up    = Vector3.new(R01, R11, R21)  -- == cf.UpVector
	local back  = Vector3.new(R02, R12, R22)  -- == cf.ZVector == -cf.LookVector
	return right, up, back
end
```

Because **R** is orthonormal, these three are mutually perpendicular unit vectors, and
`R⁻¹ = Rᵀ` — which is why extracting the columns is the same as "rows of the inverse",
and why `:Inverse()` is cheap (the docs describe it as "transposing the rotation matrix").

### 1.4 Handedness and axis convention

Roblox world space is **right-handed**:

- **+X** is right (the reference calls it the "left-right (east-west) direction")
- **+Y** is up ("up-down (vertical)")
- **+Z** is *backward*; forward is **−Z**

Two independent confirmations in the reference:
`Vector3.FromNormalId(Enum.NormalId.Front)` returns `(0, 0, -1)`, and
`Vector3.new(1,0,0):Cross(Vector3.new(0,1,0))` returns `(0, 0, 1)` — i.e. **X × Y = +Z**,
the right-hand rule. `fromAxisAngle` confirms the rotation sign convention: "A positive
angle represents a counter-clockwise rotation when looking from the tip of the axis vector
toward the origin (right-hand rule)."

Practical consequence: **a part's "front" face points along `-Z` in its own space.** To
move a part forward by its own nose, you multiply by `CFrame.new(0, 0, -distance)`.

```lua
-- Move forward 5 studs along the part's own facing
part.CFrame = part.CFrame * CFrame.new(0, 0, -5)
-- Identical:
part.CFrame = part.CFrame + part.CFrame.LookVector * 5
```

Those two are *not* generally identical, by the way — the first is a local-space
translation, the second a world-space one. They coincide here only because
`cf * CFrame.new(v)` has position `cf.Position + R*v`, and `R * (0,0,-5)` is exactly
`5 * LookVector`. Keep that distinction in mind; §3 formalizes it.

### 1.5 Why composition is not commutative

Matrix multiplication is not commutative, and CFrames are matrices. Concretely,
`A * B` means "apply B's transform *inside* A's frame":

```
(A * B).R = A.R * B.R
(A * B).p = A.R * B.p + A.p
```

So:

```lua
local A = CFrame.new(10, 0, 0)                          -- pure translation
local B = CFrame.Angles(0, math.rad(90), 0)             -- pure yaw

print((A * B).Position)  --> 10, 0, 0   (rotate in place at x=10)
print((B * A).Position)  --> 0, 0, -10  (rotate the translation itself)
```

`A * B` rotates the object where it stands. `B * A` takes the offset `(10,0,0)`, rotates
*that* by 90° about Y, and lands at `(0, 0, -10)`. Same two ingredients, different result.

The mnemonic: **right-multiply to act in local space, left-multiply to act in world
space.** Every "my part orbits when I wanted it to spin" bug is this.

The engine's operator table, verified:

| Expression | Result | Meaning |
|---|---|---|
| `CFrame * CFrame` | `CFrame` | Composition; "applies the right operand's transform in the left operand's local space". Equivalent to `:ToWorldSpace()`. |
| `CFrame * Vector3` | `Vector3` | Point from object space to world space (rotation **and** translation). Equivalent to `:PointToWorldSpace()`. |
| `CFrame + Vector3` | `CFrame` | Translate in **world** space; orientation untouched. |
| `CFrame - Vector3` | `CFrame` | `CFrame + (-v)`. |

Note the asymmetry that trips people up: `cf + v` is a **world**-space offset, while
`cf * CFrame.new(v)` is a **local**-space offset.

---

## 2. CFrame construction

### 2.1 `CFrame.new` — every overload

| Call | Result |
|---|---|
| `CFrame.new()` | Identity at origin. Same as `CFrame.identity`. |
| `CFrame.new(pos: Vector3)` | Position `pos`, identity rotation. |
| `CFrame.new(pos: Vector3, lookAt: Vector3)` | Positioned at `pos`, facing `lookAt`, assuming `(0,1,0)` up. **Legacy** — superseded by `CFrame.lookAt`. |
| `CFrame.new(x, y, z)` | Position, identity rotation. |
| `CFrame.new(x, y, z, qX, qY, qZ, qW)` | Position + **quaternion**. Note the **W is last**. |
| `CFrame.new(x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22)` | Position + explicit row-major 3×3. |

Two details worth pinning down:

- The quaternion overload "is expected to be of unit length to represent a valid rotation.
  If this isn't the case, the quaternion will be normalized." So you may pass an
  unnormalized quaternion and the engine fixes it — convenient after a slerp.
- The legacy two-Vector3 overload carries its own documented warning: "At high pitch angles
  (around 82 degrees), you may experience numerical instability… Additionally, if `lookAt`
  is directly above `pos` (pitch angle of 90 degrees), the 'up' vector switches to the X
  axis." That is a real, documented behavioral discontinuity — don't build a camera on it.

### 2.2 `CFrame.lookAt` and the up-vector degeneracy

```lua
CFrame.lookAt(at: Vector3, lookAt: Vector3, up: Vector3?) -- up defaults to Vector3.yAxis
CFrame.lookAlong(at: Vector3, direction: Vector3, up: Vector3?) -- == lookAt(at, at + direction)
```

`lookAlong` is the one you want when you already have a direction vector; it saves you the
`at + dir` and is documented as exactly equivalent.

**The degeneracy.** A look-at basis is built like this:

```
back  = (at - target).Unit          -- +Z of the result
right = up:Cross(back).Unit
newUp = back:Cross(right)
```

When the view direction is parallel to `up`, `up:Cross(back)` is the **zero vector**, and
`.Unit` of a zero vector is **NaN** (documented on `Vector3.Unit`). Your CFrame becomes
all-NaN and everything downstream silently corrupts. Looking straight up or straight down
with the default `up = (0,1,0)` is exactly this case.

**The fix**: detect near-parallel and swap in a different up. Never "nudge the direction",
which produces a visible hitch — swap the reference axis instead.

```lua
local EPS = 1e-4

--[[
	A lookAt that never produces NaN and never hitches.
	`up` is a *preference*; if the direction is nearly parallel to it we fall back
	to a perpendicular reference axis chosen from the direction's smallest component.
]]
local function safeLookAlong(at: Vector3, direction: Vector3, up: Vector3?): CFrame
	local mag = direction.Magnitude
	if mag < EPS then
		return CFrame.new(at) -- no direction at all: keep identity rotation
	end
	local dir = direction / mag
	local reference = up or Vector3.yAxis

	if math.abs(dir:Dot(reference)) > 1 - EPS then
		-- Degenerate. Pick the world axis least aligned with `dir`.
		local ax, ay, az = math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z)
		if ax <= ay and ax <= az then
			reference = Vector3.xAxis
		elseif ay <= az then
			reference = Vector3.yAxis
		else
			reference = Vector3.zAxis
		end
	end

	return CFrame.lookAlong(at, dir, reference)
end
```

For a **camera**, the usual production fix is different and better: don't feed a look-at a
direction at all. Track yaw and pitch as scalars, clamp pitch to ±(89°), and compose:

```lua
local function cameraCFrame(focus: Vector3, yaw: number, pitch: number, dist: number): CFrame
	pitch = math.clamp(pitch, math.rad(-89), math.rad(89))
	local rot = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0) -- YXZ = yaw, then pitch: no roll
	return CFrame.new(focus) * rot * CFrame.new(0, 0, dist)
end
```

This can never gimbal-lock in practice because the clamp keeps you off the singularity,
and it can never roll, because `fromEulerAnglesYXZ` with `rz = 0` has no roll term.

### 2.3 `CFrame.fromMatrix`

```lua
CFrame.fromMatrix(pos: Vector3, vX: Vector3, vY: Vector3, vZ: Vector3?)
```

`vX` is the `RightVector`, `vY` is the `UpVector`, `vZ` is **`-LookVector`**. If you omit
`vZ`, the docs say the third column is computed as `vX:Cross(vY).Unit`.

This is the constructor for "I have a basis, make me a frame" — surface alignment, custom
camera rigs, mesh frames. It is also the escape hatch the reference itself recommends when
`CFrame.new(pos, lookAt)` gets numerically unstable.

**Caveat**: `fromMatrix` does not force orthonormality for you beyond that cross product.
If `vX` and `vY` are not perpendicular, you get a skewed frame. Orthonormalize first:

```lua
-- Gram-Schmidt: trust vY (the up/normal), fix vX against it.
local function frameFromUpAndHint(pos: Vector3, up: Vector3, forwardHint: Vector3): CFrame
	local y = up.Unit
	local z = -forwardHint          -- we want LookVector == forwardHint, so ZVector = -hint
	local x = y:Cross(z)
	if x.Magnitude < 1e-6 then      -- hint parallel to up: pick anything perpendicular
		x = y:Cross(Vector3.xAxis)
		if x.Magnitude < 1e-6 then
			x = y:Cross(Vector3.zAxis)
		end
	end
	x = x.Unit
	z = x:Cross(y)                  -- re-derive so the basis is exactly orthonormal
	return CFrame.fromMatrix(pos, x, y, z)
end
```

### 2.4 The rotation-order trap

All of these produce a **rotation-only** CFrame (position `(0,0,0)`) from three radian
angles. They differ *only* in the order the axis rotations are composed:

| Constructor | Equivalent composition | Notes |
|---|---|---|
| `CFrame.fromEulerAnglesXYZ(rx, ry, rz)` | `Rx * Ry * Rz` | |
| `CFrame.Angles(rx, ry, rz)` | `Rx * Ry * Rz` | Documented as "equivalent to `fromEulerAnglesXYZ`". |
| `CFrame.fromEulerAnglesYXZ(rx, ry, rz)` | `Ry * Rx * Rz` | Argument order is still **x, y, z** even though the composition is Y-first. |
| `CFrame.fromOrientation(rx, ry, rz)` | `Ry * Rx * Rz` | Documented as "equivalent to `fromEulerAnglesYXZ`". |
| `CFrame.fromEulerAngles(rx, ry, rz, order?)` | per `Enum.RotationOrder`, **default `XYZ`** | The general form. |

The reference spells the XYZ equivalence out:

```lua
-- These two are the same rotation:
local a = CFrame.fromEulerAngles(rx, ry, rz) -- default XYZ
local b = CFrame.fromEulerAngles(rx, 0, 0)
	* CFrame.fromEulerAngles(0, ry, 0)
	* CFrame.fromEulerAngles(0, 0, rz)
```

and the YXZ one:

```lua
local a = CFrame.fromEulerAnglesYXZ(rx, ry, rz)
local b = CFrame.fromEulerAngles(0, ry, 0)
	* CFrame.fromEulerAngles(rx, 0, 0)
	* CFrame.fromEulerAngles(0, 0, rz)
```

`Enum.RotationOrder` has all six permutations: `XYZ` (0), `XZY` (1), `YZX` (2), `YXZ` (3),
`ZXY` (4), `ZYX` (5).

**The trap in production.** `BasePart.Orientation` is documented as *degrees*, applied in
**Y ⟩ X ⟩ Z** order — Tait-Bryan yaw/pitch/roll. The same doc warns that this "differs
from the `CFrame.Angles()` constructor which applies rotations in a different order." So:

```lua
-- WRONG: mixing conventions
part.CFrame = CFrame.new(part.Position)
	* CFrame.Angles(math.rad(o.X), math.rad(o.Y), math.rad(o.Z)) -- XYZ

-- RIGHT: Orientation is YXZ
part.CFrame = CFrame.new(part.Position)
	* CFrame.fromOrientation(math.rad(o.X), math.rad(o.Y), math.rad(o.Z)) -- YXZ
```

Rule of thumb: **`fromOrientation`/`ToOrientation` round-trip with `BasePart.Orientation`;
`Angles`/`ToEulerAnglesXYZ` round-trip with each other.** Never cross the streams.

### 2.5 `fromAxisAngle`, `fromRotationBetweenVectors`, `identity`

```lua
CFrame.fromAxisAngle(v: Vector3, r: number) -- axis normalized internally; position (0,0,0)
CFrame.fromRotationBetweenVectors(from: Vector3, to: Vector3) -- shortest-arc; position (0,0,0)
CFrame.identity -- constant
```

`fromAxisAngle` is the constructor you want for "spin about this arbitrary axis" — turrets
about a hinge, a wheel about its own axle, parallel transport (§4.6). The axis "is
normalized internally, so it does not need to be unit length", which saves a `.Unit` and
its `sqrt`.

`fromRotationBetweenVectors` is a genuinely underused built-in: "the shortest-arc rotation
that aligns vector `from` with vector `to`. The input vectors do not need to be unit
length; they are normalized internally." This is §4.5's quaternion formula done for you in
C++. Use it for surface alignment, RMF stepping, and "swing this bone to point at that".

`CFrame.identity` is a constant, not a method — `CFrame.identity`, never
`CFrame.identity()`. It exists so you can avoid allocating an identity in a hot loop and
so that reduce/fold over CFrames has a clean seed:

```lua
local function composeAll(frames: {CFrame}): CFrame
	local acc = CFrame.identity
	for _, cf in frames do
		acc = acc * cf
	end
	return acc
end
```

---

## 3. CFrame algebra — the patterns that solve 90% of problems

### 3.1 The four space-conversion methods

All four are documented with exact equivalences, which is the best way to remember them:

| Method | Equivalent to | Translation applied? |
|---|---|---|
| `cf:PointToWorldSpace(v)` | `cf * v` | Yes |
| `cf:PointToObjectSpace(v)` | `cf:Inverse() * v` | Yes |
| `cf:VectorToWorldSpace(v)` | `(cf - cf.Position) * v` | **No** — rotation only |
| `cf:VectorToObjectSpace(v)` | `(cf:Inverse() - cf:Inverse().Position) * v` | **No** — rotation only |

All four are **variadic**: they take `Tuple<Vector3>` and return `Tuple<Vector3>`. That
matters for performance — one call, many points:

```lua
local a, b, c = part.CFrame:PointToWorldSpace(
	Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
)
```

**Point vs Vector is the distinction that bites.** A *point* is a location and must be
translated; a *direction*, *velocity*, *normal*, or *offset* is not a location and must
**not** be translated. Using `PointToObjectSpace` on a velocity gives you nonsense that
happens to look correct while the part sits at the origin.

```lua
-- Is the target in front of me, in MY frame?
local local_ = myPart.CFrame:PointToObjectSpace(target.Position)
local inFront = local_.Z < 0                      -- forward is -Z
local toTheRight = local_.X > 0

-- What is the target's velocity in MY frame? (a direction → Vector, not Point)
local relVel = myPart.CFrame:VectorToObjectSpace(target.AssemblyLinearVelocity)
```

`ToWorldSpace` / `ToObjectSpace` are the CFrame-valued twins, also variadic:

```lua
cf:ToWorldSpace(other)   -- == cf * other
cf:ToObjectSpace(other)  -- == cf:Inverse() * other
```

### 3.2 `cf1:Inverse() * cf2` — the relative-transform idiom

This is the single most valuable expression in the whole API. It answers:
**"what transform takes me from `cf1` to `cf2`?"** — expressed in `cf1`'s own coordinates.

```lua
local rel = cf1:Inverse() * cf2   -- identical to cf1:ToObjectSpace(cf2)
-- and the inverse operation:
local cf2Again = cf1 * rel
```

Three things fall out of it immediately.

**Welding without a Weld.** Capture the offset once, reapply forever:

```lua
local offset = base.CFrame:Inverse() * attachment.CFrame
-- later, every frame:
attachment.CFrame = base.CFrame * offset
```

**Recording and replaying motion rig-independently.** Store `offset` per frame instead of
world CFrames and the playback works wherever the rig is standing.

**Measuring.** `rel.Position.Magnitude` is the distance; `rel.Position` is the offset in
`cf1`'s axes; and the rotation part of `rel` is the relative orientation, which you can
read as an angle with `cf1:AngleBetween(cf2)` (documented to return radians in `[0, π]`,
ignoring position entirely).

```lua
local function isFacing(observer: CFrame, target: Vector3, fovDegrees: number): boolean
	local toTarget = target - observer.Position
	if toTarget.Magnitude < 1e-6 then return true end
	return observer.LookVector:Angle(toTarget) <= math.rad(fovDegrees * 0.5)
end
```

### 3.3 Local versus global offsets

```lua
-- LOCAL: 5 studs along the part's own up axis, whatever way it is tipped
part.CFrame = part.CFrame * CFrame.new(0, 5, 0)

-- GLOBAL: 5 studs along world +Y, regardless of orientation
part.CFrame = part.CFrame + Vector3.new(0, 5, 0)

-- LOCAL rotation: spin around its OWN Y
part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(15), 0)

-- GLOBAL rotation about its own position: spin around WORLD Y, in place
local p = part.Position
part.CFrame = CFrame.new(p) * CFrame.Angles(0, math.rad(15), 0) * CFrame.new(-p) * part.CFrame
```

That last one deserves unpacking, because it is the general **"rotate about an arbitrary
pivot"** sandwich:

```
T(pivot) · R · T(-pivot) · M
```

Translate the pivot to the origin, rotate, translate back, then apply to whatever you had.

```lua
--[[ Rotate `cf` about `pivot` by `rotation` (a rotation-only CFrame), in world space. ]]
local function rotateAbout(cf: CFrame, pivot: Vector3, rotation: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot) * cf
end
```

### 3.4 Orbiting a point

Orbiting is the pivot sandwich with the radius baked into a local offset — cleaner and
drift-free because you rebuild it from scratch each frame rather than accumulating:

```lua
local RunService = game:GetService("RunService")

local center = Vector3.new(0, 10, 0)
local radius, speed = 20, math.rad(45) -- radians per second
local theta = 0

RunService.Heartbeat:Connect(function(dt)
	theta += speed * dt
	-- Rebuild from theta. No accumulated matrix error, and no re-orthonormalization needed.
	part.CFrame = CFrame.new(center)
		* CFrame.Angles(0, theta, 0)
		* CFrame.new(0, 0, -radius)  -- -Z so the part also FACES the direction of travel
end)
```

Building it as `CFrame.new(center) * CFrame.Angles(0, theta, 0) * CFrame.new(0, 0, -radius)`
gives you orientation for free: the part's `LookVector` points radially outward from the
centre, and its `RightVector` lies along the orbit tangent (anti-parallel to the direction
of travel for increasing `theta` — negate it if you need the actual velocity direction). If
you want the part to *face* the centre instead, use `CFrame.new(0, 0, radius)`.

For a **tilted** orbit, rotate the whole plane rather than fighting Euler angles:

```lua
local planeTilt = CFrame.fromAxisAngle(Vector3.xAxis, math.rad(23.4))
part.CFrame = CFrame.new(center) * planeTilt * CFrame.Angles(0, theta, 0) * CFrame.new(0, 0, -radius)
```

### 3.5 Building a CFrame from a surface normal

This is the workhorse for decals, footprints, spider-legs, wall-running, and placing
anything on terrain. A raycast gives you a `Position` and a `Normal`; you need a full
frame. The normal only constrains *one* axis, so you must supply a second hint to pin down
the remaining spin.

```lua
--[[
	Build a CFrame sitting on a surface.
	- position: the contact point
	- normal:   the surface normal (becomes UpVector)
	- forwardHint: desired facing; its component along the normal is removed.
	Returns nil if the hint is degenerate (parallel to the normal) and no fallback works.
]]
local function frameOnSurface(position: Vector3, normal: Vector3, forwardHint: Vector3): CFrame
	local up = normal.Unit
	-- Reject the hint onto the tangent plane: f_tangent = f - (f·n)n
	local forward = forwardHint - up * forwardHint:Dot(up)
	if forward.Magnitude < 1e-5 then
		-- Hint was parallel to the normal; pick any tangent direction.
		forward = up:Cross(Vector3.xAxis)
		if forward.Magnitude < 1e-5 then
			forward = up:Cross(Vector3.zAxis)
		end
	end
	forward = forward.Unit
	local right = forward:Cross(up)          -- right-handed: f × u = r  (since x × y = z, and z = -look)
	return CFrame.fromMatrix(position, right, up, -forward)
end

-- Usage: stamp a decal part flat on whatever is below, keeping the caster's facing.
local result = workspace:Raycast(origin, Vector3.new(0, -50, 0), params)
if result then
	local cf = frameOnSurface(result.Position, result.Normal, character.PrimaryPart.CFrame.LookVector)
	decal.CFrame = cf * CFrame.new(0, decal.Size.Y * 0.5, 0)  -- lift by half thickness
end
```

The `-forward` in `fromMatrix` is not a typo: `fromMatrix`'s third argument is `vZ`, which
is `-LookVector`. Pass `-forward` and the resulting `cf.LookVector` equals `forward`.

**The alternative one-liner**, now that `fromRotationBetweenVectors` exists — rotate the
object's current up onto the surface normal, preserving as much of its existing
orientation as possible (this is the "minimum twist" answer, and it is usually what you
actually want for a walking creature):

```lua
local function alignUpTo(cf: CFrame, normal: Vector3): CFrame
	local swing = CFrame.fromRotationBetweenVectors(cf.UpVector, normal.Unit)
	return CFrame.new(cf.Position) * swing * cf.Rotation
end
```

`cf.Rotation` is documented as "a copy of the `CFrame` with the positional component set
to `(0, 0, 0)`" — the clean way to isolate orientation.

### 3.6 Aligning one object to another's surface

Putting object B flush against face F of object A is a pure local-space problem: work in
A's frame, where the face is axis-aligned.

```lua
--[[ Place `mover` flush against the +X face of `anchor`, centred. ]]
local function snapToFace(anchor: BasePart, mover: BasePart, faceNormalLocal: Vector3)
	local halfA = anchor.Size * 0.5
	local halfB = mover.Size * 0.5
	-- Distance from anchor centre to the face, plus half of mover along the same axis.
	local offset = faceNormalLocal * (halfA:Dot(faceNormalLocal:Abs()) + halfB:Dot(faceNormalLocal:Abs()))
	mover.CFrame = anchor.CFrame * CFrame.new(offset)
end

snapToFace(anchor, mover, Vector3.xAxis)   -- flush on anchor's +X face
snapToFace(anchor, mover, -Vector3.yAxis)  -- flush underneath
```

`Vector3:Abs()` (verified: "returns a new vector from the absolute values of the
original's components") makes `halfA:Dot(n:Abs())` pick out the half-extent along the
chosen axis regardless of sign — a small trick worth keeping.

---

## 4. Rotation deep dive

### 4.1 Gimbal lock, concretely

Gimbal lock is not a mystical property of 3D space; it is a property of the *parametrization*.
Any three-angle sequence loses a degree of freedom when the **middle** rotation reaches
±90°, because the first and third axes become collinear.

Take `CFrame.Angles(a, b, c)` = `Rx(a)·Ry(b)·Rz(c)`, and set `b = π/2`. Writing
`Ry(π/2) = [[0,0,1],[0,1,0],[-1,0,0]]` and multiplying out:

```
Rx(a)·Ry(π/2)·Rz(c) =
  [      0             0          1  ]
  [  sin(a+c)     cos(a+c)        0  ]
  [ -cos(a+c)     sin(a+c)        0  ]
```

Every entry depends only on **`a + c`**. The X and Z rotations have collapsed into one
knob. You can verify it live:

```lua
local A = CFrame.Angles(math.rad(30), math.rad(90), 0)
local B = CFrame.Angles(0,             math.rad(90), math.rad(30))
print(A:FuzzyEq(B))  --> true  -- two different inputs, one rotation

-- And the decomposition cannot tell you which you meant:
print(math.deg(select(1, A:ToEulerAnglesXYZ())), math.deg(select(3, A:ToEulerAnglesXYZ())))
-- some (rx, rz) pair summing to 30, not necessarily (30, 0)
```

The reference acknowledges this on both decomposers: the returned angles "are approximate
and subject to gimbal lock near pitch angles of ±90 degrees."

Practical consequences:

1. **Never store a rotation as Euler angles** if it will be composed, interpolated, or
   accumulated. Store the CFrame. Euler angles are an input/display format.
2. **Clamp your pitch** to ±89° in camera and turret code. That is the industry-standard
   fix and it costs nothing.
3. **Choose the order so the singularity is somewhere you never go.** For a first-person
   camera, YXZ (yaw-pitch-roll) puts the singularity at "looking straight up/down", which
   you clamp away. XYZ would put it at yaw = 90°, which you visit constantly.

### 4.2 `ToEulerAnglesXYZ` / `ToOrientation` and their limits

```lua
cf:ToEulerAnglesXYZ()            --> rx, ry, rz (radians), XYZ order
cf:ToEulerAnglesYXZ()            --> rx, ry, rz (radians), YXZ order
cf:ToOrientation()               --> alias of ToEulerAnglesYXZ
cf:ToEulerAngles(order?)         --> order defaults to Enum.RotationOrder.XYZ
cf:ToAxisAngle()                 --> Vector3 (unit axis), number (radians)
```

Beyond gimbal lock, the other limitation is **non-uniqueness**: a given rotation has
infinitely many Euler triples (add 2π to any of them; or flip all three in the mirrored
branch). `ToEulerAnglesXYZ` returns *one* canonical branch. So this is **false**:

```lua
-- NOT guaranteed:
local rx, ry, rz = someCF:ToEulerAnglesXYZ()
assert(CFrame.Angles(rx, ry, rz) == someCF)   -- the ROTATION matches, the NUMBERS may not
```

The rotation round-trips (up to float error). The *numbers* do not. If you show Euler
angles in a UI and read them back, the user will see values jump — that is expected and
correct, not a bug to chase.

`ToAxisAngle` is the better decomposition when you want a *scalar measure* of rotation:

```lua
local axis, angle = (a:Inverse() * b):ToAxisAngle()
print(math.deg(angle), axis)  -- "how far, and about what, from a to b"
```

though `a:AngleBetween(b)` is more direct if you only need the magnitude.

### 4.3 Quaternions — the math

A **unit quaternion** encodes a rotation of θ about unit axis **k** as

```
q = (x, y, z, w) = (k.x·sin(θ/2), k.y·sin(θ/2), k.z·sin(θ/2), cos(θ/2))
```

with `x² + y² + z² + w² = 1`. Roblox's constructor takes them in
**`CFrame.new(px, py, pz, qX, qY, qZ, qW)`** order — position first, then the vector part,
then **W last**. This is verified from the reference; it is the opposite of the `(w, x, y, z)`
convention many maths texts and some other engines use, so a quaternion copied from a
paper needs its components reordered.

**Double cover.** `q` and `-q` represent the *same* rotation. That single fact is why
slerp needs the sign check in §4.4 and why naive quaternion comparison fails.

**Composition** (`q1` then `q2` applied afterwards is `q2 * q1`; Hamilton product):

```lua
type Quat = {x: number, y: number, z: number, w: number}

local function qMul(a: Quat, b: Quat): Quat
	return {
		x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
		w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
	}
end
```

**Conjugate and inverse.** `q* = (-x, -y, -z, w)`. For a *unit* quaternion,
`q⁻¹ = q*` — no division needed, which is a large part of why quaternions are cheap.
For a non-unit quaternion, `q⁻¹ = q* / |q|²`.

```lua
local function qConj(q: Quat): Quat return {x = -q.x, y = -q.y, z = -q.z, w = q.w} end
local function qDot(a: Quat, b: Quat): number return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w end

local function qNormalize(q: Quat): Quat
	local m = math.sqrt(qDot(q, q))
	if m < 1e-12 then return {x = 0, y = 0, z = 0, w = 1} end
	return {x = q.x/m, y = q.y/m, z = q.z/m, w = q.w/m}
end
```

**Quaternion → CFrame** is free, because the engine normalizes for you:

```lua
local function cframeFromQuat(pos: Vector3, q: Quat): CFrame
	return CFrame.new(pos.X, pos.Y, pos.Z, q.x, q.y, q.z, q.w)
end
```

**CFrame → quaternion.** Roblox exposes no `ToQuaternion`. Two routes:

*Route A — via the documented axis-angle decomposition (short, safe, slightly slower):*

```lua
local function quatFromCFrame(cf: CFrame): Quat
	local axis, angle = cf:ToAxisAngle()
	local h = angle * 0.5
	local s = math.sin(h)
	return {x = axis.X * s, y = axis.Y * s, z = axis.Z * s, w = math.cos(h)}
end
```

*Route B — Shepperd's trace method, straight off the matrix (no trig, numerically stable
because it always divides by the largest component):*

```lua
local function quatFromCFrameFast(cf: CFrame): Quat
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cf:GetComponents()
	local tr = m00 + m11 + m22
	if tr > 0 then
		local s = math.sqrt(tr + 1) * 2          -- s = 4w
		return {w = 0.25 * s, x = (m21 - m12)/s, y = (m02 - m20)/s, z = (m10 - m01)/s}
	elseif m00 > m11 and m00 > m22 then
		local s = math.sqrt(1 + m00 - m11 - m22) * 2   -- s = 4x
		return {w = (m21 - m12)/s, x = 0.25 * s, y = (m01 + m10)/s, z = (m02 + m20)/s}
	elseif m11 > m22 then
		local s = math.sqrt(1 + m11 - m00 - m22) * 2   -- s = 4y
		return {w = (m02 - m20)/s, x = (m01 + m10)/s, y = 0.25 * s, z = (m12 + m21)/s}
	else
		local s = math.sqrt(1 + m22 - m00 - m11) * 2   -- s = 4z
		return {w = (m10 - m01)/s, x = (m02 + m20)/s, y = (m12 + m21)/s, z = 0.25 * s}
	end
end

-- Sanity check: a 90° yaw should give (0, √½, 0, √½)
local q = quatFromCFrameFast(CFrame.Angles(0, math.rad(90), 0))
print(q.x, q.y, q.z, q.w)  --> ~0, ~0.7071, ~0, ~0.7071
```

Branching on the largest diagonal element is not optional. The `tr > 0` branch divides by
`4w`; if the rotation is near 180°, `w ≈ 0` and that branch loses all precision. The other
three branches cover the cases where `x`, `y`, or `z` is dominant.

**Rotating a vector by a quaternion** without building a matrix (the compact form):

```lua
-- v' = v + 2 * cross(qv, cross(qv, v) + w*v)
local function qRotate(q: Quat, v: Vector3): Vector3
	local qv = Vector3.new(q.x, q.y, q.z)
	local t = qv:Cross(v) + v * q.w
	return v + qv:Cross(t) * 2
end
```

In practice, though: if you have a `CFrame`, `cf:VectorToWorldSpace(v)` is faster than any
Luau-level quaternion code, because it runs in C++. Reach for explicit quaternions when you
need slerp control the engine doesn't give you, need to *store* rotations compactly
(4 floats vs 12), or need to average many rotations.

### 4.4 Slerp vs lerp, and what `CFrame:Lerp` actually does

**`CFrame:Lerp(goal, alpha)` lerps the position and slerps the rotation.** Verified,
word for word: "The positional component is interpolated linearly while the rotational
component is interpolated using spherical linear interpolation (slerp), producing a
constant-speed rotation along the shortest arc."

Three things that buys you, all of which you would have to rebuild by hand otherwise:

1. **Constant angular speed.** A naive lerp of quaternion components followed by
   normalization ("nlerp") traces the same *path* but at a non-constant rate — it
   accelerates through the middle. Visible on long rotations, invisible on short ones.
2. **Shortest arc.** It never takes the 350° route when 10° would do. That is the double-cover
   sign check, handled for you.
3. **No Euler interpolation artifacts.** Interpolating Euler triples independently produces
   wobble and can pass through gimbal-locked configurations.

The formula it implements, for reference:

```
slerp(q0, q1, t):
  d = dot(q0, q1)
  if d < 0 then q1 = -q1; d = -d end        -- shortest arc (double cover)
  if d > 0.9995 then return normalize(lerp(q0, q1, t)) end  -- near-parallel: lerp is safe & avoids /sin(0)
  θ = acos(clamp(d, -1, 1))
  return (sin((1-t)·θ)·q0 + sin(t·θ)·q1) / sin(θ)
```

```lua
local function qSlerp(a: Quat, b: Quat, t: number): Quat
	local d = qDot(a, b)
	if d < 0 then
		b = {x = -b.x, y = -b.y, z = -b.z, w = -b.w}
		d = -d
	end
	if d > 0.9995 then
		return qNormalize({
			x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t,
			z = a.z + (b.z - a.z) * t, w = a.w + (b.w - a.w) * t,
		})
	end
	local theta = math.acos(math.clamp(d, -1, 1))
	local s = math.sin(theta)
	local w0, w1 = math.sin((1 - t) * theta) / s, math.sin(t * theta) / s
	return {
		x = a.x*w0 + b.x*w1, y = a.y*w0 + b.y*w1,
		z = a.z*w0 + b.z*w1, w = a.w*w0 + b.w*w1,
	}
end
```

The `d > 0.9995` early-out is not a nicety — as `θ → 0`, `sin(θ) → 0` and you divide by
zero. Never omit it.

**When `CFrame:Lerp` is *not* what you want**: when the positional path should be curved
(use a spline, §7), or when you want to slerp the rotation but hold the position (use
`a.Rotation:Lerp(b.Rotation, t) + a.Position`).

### 4.5 Shortest-arc rotation between two vectors

Given unit vectors **a** and **b**, the rotation taking **a** to **b** along the shortest
arc is the quaternion

```
q = normalize( (a × b, 1 + a·b) )
```

i.e. vector part `a × b`, scalar part `1 + a·b`. The derivation: the half-angle identities
give `sin(θ/2)·k = (a × b) / (2cos(θ/2))` and `cos(θ/2) = √((1 + a·b)/2)`; scaling away the
common factor leaves the form above, which normalization fixes up.

```lua
local function shortestArc(from: Vector3, to: Vector3): CFrame
	local a, b = from.Unit, to.Unit
	local d = a:Dot(b)

	if d > 1 - 1e-6 then
		return CFrame.identity                      -- already aligned
	end
	if d < -1 + 1e-6 then
		-- ANTIPARALLEL: a × b is zero and the shortest arc is ambiguous (any axis ⟂ a works).
		local axis = a:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-6 then
			axis = a:Cross(Vector3.yAxis)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end

	local c = a:Cross(b)
	-- CFrame.new's quaternion overload normalizes internally, so we can pass it unnormalized.
	return CFrame.new(0, 0, 0, c.X, c.Y, c.Z, 1 + d)
end
```

**Or just use the built-in**: `CFrame.fromRotationBetweenVectors(from, to)` does this in
C++ and normalizes the inputs for you. The manual version above is worth keeping for two
reasons: it documents the antiparallel case explicitly (where "shortest arc" is genuinely
undefined — the set of valid answers is a whole circle of axes), and it is the building
block for a **constrained** swing where you want to pick a *specific* axis rather than
whatever the engine picks.

The matrix form, for completeness — **Rodrigues' rotation formula**, rotating **v** about
unit axis **k** by θ:

```
v_rot = v·cos θ + (k × v)·sin θ + k·(k·v)·(1 − cos θ)
```

```lua
local function rodrigues(v: Vector3, k: Vector3, theta: number): Vector3
	local c, s = math.cos(theta), math.sin(theta)
	return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c))
end
```

### 4.6 Rotation-minimizing frames (parallel transport)

**The problem.** You are sweeping a tube along a curve, or running a camera down a rail.
At each sample you need a full frame, not just a tangent. The obvious approach —
`CFrame.lookAt(point, point + tangent)` at every sample — fails in two ways: it **flips**
violently when the tangent crosses the reference up vector, and it introduces **twist**
that makes an extruded tube visibly corkscrew even though the curve doesn't.

**The fix.** Don't construct each frame independently. *Transport* the previous frame
forward by the minimum rotation that carries the old tangent onto the new one. That
rotation is exactly the shortest arc of §4.5, and the resulting sequence is a
**rotation-minimizing frame** (RMF): zero twist about the tangent, by construction.

```lua
--[[
	Build rotation-minimizing frames along a sampled curve.
	`points`  : {Vector3}  positions along the curve
	`tangents`: {Vector3}  unit tangent at each point
	`initialUp`: hint for the very first frame only
	Returns {CFrame}, one per point, with LookVector == tangent.
]]
local function rotationMinimizingFrames(points: {Vector3}, tangents: {Vector3}, initialUp: Vector3): {CFrame}
	local n = #points
	local frames = table.create(n)

	-- Seed frame: any valid frame whose LookVector is tangents[1].
	local t0 = tangents[1].Unit
	local up = initialUp - t0 * initialUp:Dot(t0)     -- reject the hint onto the normal plane
	if up.Magnitude < 1e-5 then
		up = t0:Cross(Vector3.xAxis)
		if up.Magnitude < 1e-5 then up = t0:Cross(Vector3.zAxis) end
	end
	up = up.Unit
	local right = t0:Cross(up)                         -- t × u; with look = -Z this gives a right-handed basis
	frames[1] = CFrame.fromMatrix(points[1], right, up, -t0)

	for i = 2, n do
		local prevT = tangents[i - 1].Unit
		local currT = tangents[i].Unit
		-- The minimum rotation carrying prevT onto currT — this is the whole algorithm.
		local swing = CFrame.fromRotationBetweenVectors(prevT, currT)
		local prev = frames[i - 1]
		local carried = swing * prev.Rotation
		frames[i] = CFrame.fromMatrix(
			points[i], carried.RightVector, carried.UpVector, carried.ZVector
		):Orthonormalize()   -- see §10.3: this runs in a loop, so drift is real
	end

	return frames
end
```

**The double-reflection method** (Wang, Jüttler, Zheng & Liu, 2008) is the higher-accuracy
variant used in CAD. It is two Householder reflections per step instead of one rotation,
and is O(h⁴) accurate versus the projection method's O(h²):

```lua
--[[ One double-reflection step: carry reference vector r from (x0,t0) to (x1,t1). ]]
local function rmfStep(x0: Vector3, t0: Vector3, r0: Vector3, x1: Vector3, t1: Vector3): Vector3
	local v1 = x1 - x0
	local c1 = v1:Dot(v1)
	if c1 < 1e-12 then return r0 end
	local rL = r0 - v1 * (2 / c1 * v1:Dot(r0))   -- reflect r0 across the plane ⟂ v1
	local tL = t0 - v1 * (2 / c1 * v1:Dot(t0))   -- reflect t0 the same way
	local v2 = t1 - tL
	local c2 = v2:Dot(v2)
	if c2 < 1e-12 then return rL end
	return (rL - v2 * (2 / c2 * v2:Dot(rL))).Unit -- reflect again so tL lands exactly on t1
end
```

**Closing the loop.** If the curve is closed, the transported frame will generally not
match the starting frame — there is a residual twist angle (the holonomy). Fix it by
measuring the mismatch and distributing it linearly:

```lua
local function closeFrames(frames: {CFrame}, tangents: {Vector3}): {CFrame}
	local n = #frames
	local startUp = frames[1].UpVector
	local endUp = frames[n].UpVector
	local axis = tangents[n].Unit
	-- Signed angle from endUp back to startUp, measured about the tangent.
	local residual = endUp:Angle(startUp, axis)
	for i = 1, n do
		local t = (i - 1) / (n - 1)
		local correction = CFrame.fromAxisAngle(tangents[i].Unit, residual * t)
		frames[i] = CFrame.new(frames[i].Position) * correction * frames[i].Rotation
	end
	return frames
end
```

Note the use of the **signed** `Vector3:Angle(other, axis)` overload — documented as
returning `[-π, π]`, "positive when the rotation from `self` to `other` follows the
right-hand rule around `axis`". Without the axis argument you would only get the magnitude
and would correct in the wrong direction half the time.

---

## 5. Vector math you must own

### 5.1 Dot product — three jobs

`a:Dot(b)` = `a.X*b.X + a.Y*b.Y + a.Z*b.Z` = `|a||b|cos θ`.

**(1) Angle.** `math.acos(a.Unit:Dot(b.Unit))` — but prefer `a:Angle(b)`, which is the
documented API, doesn't require unit inputs, and doesn't blow up on `acos` domain error
when float rounding pushes the dot to 1.0000001.

**(2) Projection onto a direction.** The scalar projection of `a` onto unit `n` is `a:Dot(n)`.
Use it as a *coordinate*: "how far along this axis am I?"

**(3) Side of a plane / in-front test.** With plane normal `n` through point `p`,
`(q - p):Dot(n)` is **signed distance** if `n` is unit: positive in front, negative behind,
zero on the plane. This is the cheapest test in 3D and it should be your first reach:

```lua
local function signedDistanceToPlane(q: Vector3, planePoint: Vector3, planeNormal: Vector3): number
	return (q - planePoint):Dot(planeNormal)   -- planeNormal must be unit
end

-- "Is the enemy in my forward hemisphere?" — no acos, no normalization, no sqrt:
local inFront = (enemy.Position - me.Position):Dot(me.CFrame.LookVector) > 0
```

### 5.2 Cross product — normal, torque, handedness

`a:Cross(b)` is perpendicular to both, with magnitude `|a||b|sin θ` (the area of the
parallelogram they span), oriented by the **right-hand rule** — verified:
`(1,0,0):Cross((0,1,0))` is `(0,0,1)` and the reverse is `(0,0,-1)`.

Uses:
- **Surface normal from a triangle**: `(b - a):Cross(c - a)`. Its magnitude is *twice the
  triangle's area* — a free area computation, and a free degeneracy test (near-zero
  magnitude means collinear vertices).
- **Torque / angular velocity**: `τ = r × F`, `v = ω × r`.
- **Handedness / winding test**: the sign of `n:Dot(a:Cross(b))` tells you whether `b` is
  counter-clockwise from `a` when viewed down `n`. That is the barycentric edge test in §6.5.
- **Parallelism test**: `a:Cross(b).Magnitude < ε` means parallel or antiparallel.

### 5.3 Projection, rejection, reflection

```lua
-- Component of a ALONG b (b need not be unit)
local function project(a: Vector3, b: Vector3): Vector3
	local bb = b:Dot(b)
	if bb < 1e-12 then return Vector3.zero end
	return b * (a:Dot(b) / bb)
end

-- Component of a PERPENDICULAR to b. project + reject == a, always.
local function reject(a: Vector3, b: Vector3): Vector3
	return a - project(a, b)
end

-- Mirror d across the plane with unit normal n.  r = d - 2(d·n)n
-- For a bounce, d is the INCOMING direction and the result points away from the surface.
local function reflect(d: Vector3, n: Vector3): Vector3
	return d - n * (2 * d:Dot(n))
end

-- Bounce with energy loss and separated normal/tangent restitution:
local function bounce(velocity: Vector3, normal: Vector3, restitution: number, friction: number): Vector3
	local vn = normal * velocity:Dot(normal)   -- normal component
	local vt = velocity - vn                   -- tangential component
	return vt * (1 - friction) - vn * restitution
end
```

`reject` is what you use to **constrain motion to a plane** (sliding along a wall), and it
is what `frameOnSurface` in §3.5 used to flatten a facing hint onto a surface.

### 5.4 Normalization and the zero-vector trap

The reference is explicit: "If the vector has a magnitude of `0` (i.e. all components are
zero), the resulting `Unit` vector will have `NaN` components. Check `Magnitude` before
using `Unit` when the vector may be zero-length."

NaN does not throw. It propagates silently through every subsequent operation, corrupts a
CFrame, gets assigned to a part, and surfaces three systems later as "the part vanished".
Guard at the source:

```lua
local function safeUnit(v: Vector3, fallback: Vector3?): Vector3
	local m = v.Magnitude
	if m < 1e-9 then return fallback or Vector3.zero end
	return v / m
end
```

**`.Unit` costs a `sqrt` and a divide**, and it is recomputed on *every access* — it is a
derived property, not a cached field. So this is two square roots:

```lua
local bad = (a.Unit:Dot(b)) + (a.Unit:Dot(c))   -- .Unit evaluated twice
local u = a.Unit                                 -- hoist it
local good = u:Dot(b) + u:Dot(c)
```

Better still: **avoid normalizing at all.** Most comparisons can be done on squared
magnitudes:

```lua
-- SLOW: two sqrt
if (a - b).Magnitude < range then ... end
-- FAST: no sqrt
local d = a - b
if d:Dot(d) < range * range then ... end
```

Sorting by distance? Sort by `d:Dot(d)`. Monotone transform, identical ordering, no sqrt.

### 5.5 The rest of the Vector3 surface

| Member | Notes |
|---|---|
| `Vector3.zero`, `.one`, `.xAxis`, `.yAxis`, `.zAxis` | Constants; no allocation, no `.new` call. |
| `Vector3.FromNormalId(normalId)`, `.FromAxis(axis)` | `NormalId.Front` → `(0,0,-1)`; `Axis.X` → `(1,0,0)`. |
| `:Abs()`, `:Ceil()`, `:Floor()`, `:Sign()` | Component-wise. `:Sign()` gives −1/0/1 per component. |
| `:Max(v)`, `:Min(v)` | Component-wise max/min. The AABB clamp primitive. |
| `:Lerp(goal, alpha)` | `alpha` is documented as **not** clamped to `[0,1]` — extrapolation works. |
| `:FuzzyEq(other, epsilon?)` | Default `1e-5`. Per-component with a **hybrid epsilon that scales relative to component magnitude** — so it stays meaningful at 10,000 studs, unlike a fixed epsilon. |
| `:Angle(other, axis?)` | Unsigned `[0, π]` without `axis`; **signed `[-π, π]` with it**. |
| `+ - * /` and `//` | All component-wise between two Vector3s, or with a scalar. `//` is component-wise floor division. |

Component-wise `*` and `/` between two Vector3s are worth internalizing: they are how you
do per-axis scaling and the elegant slab test in §6.4.

```lua
-- Component-wise scale (NOT a dot product):
local scaled = size * Vector3.new(2, 1, 0.5)
-- Grid snap, all three axes at once:
local snapped = (pos / grid):Floor() * grid
```

### 5.6 The Luau native `vector` type

Luau has a `vector` **primitive** — not a table, not a userdata. Verified from the Luau VM
headers (`VM/include/luaconf.h`): `LUA_VECTOR_SIZE` defaults to `3`, and `LUA_VECTOR_TYPE`
is **`float`** unless `LUA_VECTOR_DOUBLE` is set. So a Luau vector is three 32-bit floats
living inline in the value, with no heap allocation.

The `vector` library (verified members): `vector.zero`, `vector.one`, `vector.create(x, y, z?)`,
`vector.magnitude`, `vector.normalize`, `vector.cross`, `vector.dot`,
`vector.angle(v1, v2, axis?)`, `vector.floor`, `vector.ceil`, `vector.abs`, `vector.sign`,
`vector.clamp(v, min, max)`, `vector.lerp(v1, v2, alpha)`, `vector.max(...)`, `vector.min(...)`.
Components read as `v.x` or `v.X` (and `y`/`Y`, `z`/`Z`); values are **immutable**, so you
cannot write to a component.

The Roblox reference itself nudges you toward it: "Alternatively to `Vector3`, consider
using the methods and properties of the `vector` library."

**Why it's faster.** Historically Vector3 was heap-allocated — every intermediate in
`a + b * c` allocated and pressured the GC. As a native value type, arithmetic compiles to
SIMD-friendly inline operations with zero allocations, and the library functions have
fastcall slots in the VM. For tight numeric loops (mesh generation, particle systems,
per-frame physics over thousands of elements) this is the difference between a frame budget
and a stutter.

```lua
-- Native-vector inner loop: no allocations, no method dispatch.
local function centroid(points: {vector}): vector
	local acc = vector.zero
	for i = 1, #points do
		acc += points[i]
	end
	return acc / #points
end
```

Two practical cautions:
- `vector.max`/`vector.min` are **variadic** (`max(a, b, c, ...)`), unlike `Vector3:Max(v)`
  which takes one argument — so the call shapes differ when you port code.
- `vector.normalize` has the same zero-vector NaN behavior: documented as "If the input
  vector has zero magnitude, the result contains `nan` components." Guard it the same way.
- Components are `float` while Luau `number` is `double`. Round-tripping a double through a
  vector component loses bits — see §10.1.

---

## 6. Geometry queries

Roblox gives you `workspace:Raycast(origin, direction, params)`, plus `Blockcast`,
`Spherecast`, `Shapecast`, `GetPartBoundsInBox`, `GetPartBoundsInRadius` and
`GetPartsInPart`. Use them whenever the thing you are testing against is a real `BasePart`
— they run in C++ against the broadphase. Write the code below for the cases the engine
does not cover: procedural geometry, `EditableMesh` triangles, UI-space math, custom
spatial structures, and prediction where you must not touch the physics world.

Note `workspace:Raycast(origin, direction, ...)` takes a **direction whose magnitude is the
maximum distance** — not a unit vector plus a range. `Camera:ViewportPointToRay` returns a
**unit** ray ("only one stud long"), so you must scale it (§11.8).

### 6.1 Ray–plane

Plane: points **q** with `(q − p₀)·n = 0`. Ray: `o + t·d`.

```
t = ((p₀ − o) · n) / (d · n)
```

```lua
local function rayPlane(o: Vector3, d: Vector3, p0: Vector3, n: Vector3): number?
	local denom = d:Dot(n)
	if math.abs(denom) < 1e-8 then return nil end   -- parallel (or in-plane)
	local t = (p0 - o):Dot(n) / denom
	if t < 0 then return nil end                     -- behind the origin
	return t
end
```

The `denom` guard is the whole game: without it, a ray parallel to the plane gives `±inf`
or `NaN`. Note this returns hits on the **back** face too; if you want front-face only,
require `denom < 0` (ray travelling against the normal).

### 6.2 Ray–sphere

With **unit** `d`, let `m = o − c`, `b = m·d`, `c₀ = m·m − r²`. Then
`disc = b² − c₀`, and the near hit is `t = −b − √disc`.

```lua
local function raySphere(o: Vector3, d: Vector3, center: Vector3, radius: number): number?
	local m = o - center                 -- d MUST be unit for this form
	local b = m:Dot(d)
	local c0 = m:Dot(m) - radius * radius
	if c0 > 0 and b > 0 then return nil end  -- outside and pointing away: early out
	local disc = b * b - c0
	if disc < 0 then return nil end          -- misses
	local t = -b - math.sqrt(disc)
	if t < 0 then t = -b + math.sqrt(disc) end  -- origin inside: take the far root
	return t >= 0 and t or nil
end
```

The `c0 > 0 and b > 0` early-out (outside the sphere, moving away) rejects the majority of
candidates without a square root.

### 6.3 Ray–triangle: Möller–Trumbore

The standard. No precomputed plane equation, and it hands you the **barycentric
coordinates** for free, which is what you need for UVs and vertex attributes (§6.5).

```lua
--[[ Returns t, u, v  (hit point = o + t*d = (1-u-v)*v0 + u*v1 + v*v2), or nil. ]]
local function rayTriangle(o: Vector3, d: Vector3, v0: Vector3, v1: Vector3, v2: Vector3)
	local EPS = 1e-8
	local e1 = v1 - v0
	local e2 = v2 - v0
	local h = d:Cross(e2)
	local a = e1:Dot(h)
	if math.abs(a) < EPS then return nil end   -- ray parallel to the triangle plane
	-- For BACK-FACE CULLING, replace the line above with: if a < EPS then return nil end
	local f = 1 / a
	local s = o - v0
	local u = f * s:Dot(h)
	if u < 0 or u > 1 then return nil end
	local q = s:Cross(e1)
	local v = f * d:Dot(q)
	if v < 0 or u + v > 1 then return nil end
	local t = f * e2:Dot(q)
	if t < EPS then return nil end             -- behind the origin
	return t, u, v
end
```

### 6.4 Ray–AABB: the slab method

Treat the box as three pairs of parallel planes ("slabs"). The ray enters at the largest of
the three near-hits and exits at the smallest of the three far-hits; if entry ≤ exit, it hits.

Vector3's component-wise arithmetic makes this nearly branch-free:

```lua
local function rayAABB(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3): (number?, number?)
	local inv = Vector3.one / d            -- component-wise; ±inf for zero components is CORRECT
	local t1 = (bmin - o) * inv
	local t2 = (bmax - o) * inv
	local lo = t1:Min(t2)
	local hi = t1:Max(t2)
	local tmin = math.max(lo.X, lo.Y, lo.Z)
	local tmax = math.min(hi.X, hi.Y, hi.Z)
	if tmax < 0 or tmin > tmax then return nil end
	return tmin, tmax
end
```

**The IEEE detail that makes this work — and the one case it breaks.** A zero component of
`d` gives `inv = ±inf`, and `finite * inf = ±inf`, which correctly says "never enters /
never exits this slab". But if the origin is *exactly* on a slab boundary, you get
`0 * inf = NaN`, and `math.max`/`math.min` with NaN are unspecified. `Vector3:Min`/`:Max`
are also not documented for NaN inputs. If your rays can start exactly on box faces, nudge
the origin by an epsilon or handle the zero-`d` axes explicitly.

For an **OBB** (an arbitrarily rotated part), don't write new code — transform the ray into
the box's local space where it is axis-aligned again:

```lua
local function rayOBB(o: Vector3, d: Vector3, cf: CFrame, size: Vector3)
	local lo = cf:PointToObjectSpace(o)     -- point: translated
	local ld = cf:VectorToObjectSpace(d)    -- direction: NOT translated
	local h = size * 0.5
	return rayAABB(lo, ld, -h, h)           -- t is in the same units either way
end
```

### 6.5 Barycentric coordinates and attribute interpolation

For triangle (A, B, C) and point P in its plane, barycentric coordinates `(u, v, w)` satisfy
`P = u·A + v·B + w·C` with `u + v + w = 1`. **P is inside the triangle iff all three are ≥ 0.**

```lua
local function barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3): (number, number, number)
	local v0, v1, v2 = b - a, c - a, p - a
	local d00 = v0:Dot(v0)
	local d01 = v0:Dot(v1)
	local d11 = v1:Dot(v1)
	local d20 = v2:Dot(v0)
	local d21 = v2:Dot(v1)
	local denom = d00 * d11 - d01 * d01
	if math.abs(denom) < 1e-12 then return 1, 0, 0 end  -- degenerate triangle
	local v = (d11 * d20 - d01 * d21) / denom
	local w = (d00 * d21 - d01 * d20) / denom
	return 1 - v - w, v, w
end

local function pointInTriangle(p, a, b, c): boolean
	local u, v, w = barycentric(p, a, b, c)
	return u >= 0 and v >= 0 and w >= 0
end
```

**This is how you find the UV at a raycast hit.** Möller–Trumbore already returned `(u, v)`
with the convention `P = (1−u−v)·V0 + u·V1 + v·V2`, so:

```lua
local t, u, v = rayTriangle(origin, dir, p0, p1, p2)
if t then
	local w = 1 - u - v
	local uvAtHit = uv0 * w + uv1 * u + uv2 * v      -- Vector2 attributes
	local normalAtHit = (n0 * w + n1 * u + n2 * v).Unit  -- smooth (Phong) normal
	local colorAtHit = c0 * w + c1 * u + c2 * v
end
```

Any per-vertex attribute — UV, normal, colour, bone weight, terrain material blend —
interpolates with the same three weights. This is the entire basis of rasterization, and in
Roblox it is how you sample an `EditableMesh` at a raycast hit.

### 6.6 Closest points

```lua
-- Closest point on segment AB to P, and the clamped parameter t ∈ [0,1].
local function closestOnSegment(p: Vector3, a: Vector3, b: Vector3): (Vector3, number)
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom < 1e-12 then return a, 0 end
	local t = math.clamp((p - a):Dot(ab) / denom, 0, 1)
	return a + ab * t, t
end

-- Closest point on an AABB to P — component-wise clamp, that's all.
local function closestOnAABB(p: Vector3, bmin: Vector3, bmax: Vector3): Vector3
	return p:Max(bmin):Min(bmax)
end

-- Closest point on an OBB: clamp in the box's own frame.
local function closestOnOBB(p: Vector3, cf: CFrame, size: Vector3): Vector3
	local h = size * 0.5
	local local_ = cf:PointToObjectSpace(p)
	return cf * local_:Max(-h):Min(h)
end

-- Sphere vs AABB overlap falls straight out of closestOnAABB:
local function sphereAABB(center: Vector3, radius: number, bmin: Vector3, bmax: Vector3): boolean
	local d = center - closestOnAABB(center, bmin, bmax)
	return d:Dot(d) <= radius * radius
end
```

**Closest point on a triangle** (Ericson's region-based method — handles all seven Voronoi
regions: three vertices, three edges, the face):

```lua
local function closestOnTriangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3): Vector3
	local ab, ac, ap = b - a, c - a, p - a
	local d1, d2 = ab:Dot(ap), ac:Dot(ap)
	if d1 <= 0 and d2 <= 0 then return a end                       -- vertex region A

	local bp = p - b
	local d3, d4 = ab:Dot(bp), ac:Dot(bp)
	if d3 >= 0 and d4 <= d3 then return b end                      -- vertex region B

	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then                        -- edge region AB
		return a + ab * (d1 / (d1 - d3))
	end

	local cp = p - c
	local d5, d6 = ab:Dot(cp), ac:Dot(cp)
	if d6 >= 0 and d5 <= d6 then return c end                      -- vertex region C

	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then                        -- edge region AC
		return a + ac * (d2 / (d2 - d6))
	end

	local va = d3 * d6 - d5 * d4
	if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then          -- edge region BC
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	end

	local denom = 1 / (va + vb + vc)                               -- face region
	return a + ab * (vb * denom) + ac * (vc * denom)
end
```

### 6.7 Overlap tests and the separating axis theorem

```lua
local function sphereSphere(c1: Vector3, r1: number, c2: Vector3, r2: number): boolean
	local d = c1 - c2
	local rr = r1 + r2
	return d:Dot(d) <= rr * rr          -- squared: no sqrt
end

local function aabbAABB(minA, maxA, minB, maxB): boolean
	return minA.X <= maxB.X and maxA.X >= minB.X
		and minA.Y <= maxB.Y and maxA.Y >= minB.Y
		and minA.Z <= maxB.Z and maxA.Z >= minB.Z
end

-- Plane from 3 points. Returns unit normal and the plane constant d, where n·x = d.
local function planeFrom3(a: Vector3, b: Vector3, c: Vector3): (Vector3?, number?)
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-9 then return nil, nil end   -- collinear
	n = n.Unit
	return n, n:Dot(a)
end
```

**SAT for two OBBs.** Two convex shapes are disjoint iff some axis separates their
projections. For two boxes the candidate set is 15 axes: A's three face normals, B's three,
and the nine pairwise cross products of their edge directions.

```lua
--[[ Do two oriented boxes overlap?  Each is a CFrame + full Size. ]]
local function obbOverlap(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): boolean
	local EPS = 1e-6
	local hA, hB = sizeA * 0.5, sizeB * 0.5
	local axesA = {cfA.RightVector, cfA.UpVector, cfA.ZVector}
	local axesB = {cfB.RightVector, cfB.UpVector, cfB.ZVector}
	local hAv = {hA.X, hA.Y, hA.Z}
	local hBv = {hB.X, hB.Y, hB.Z}
	local t = cfB.Position - cfA.Position

	local function separated(axis: Vector3): boolean
		if axis.Magnitude < EPS then return false end  -- parallel edges: degenerate axis, skip
		local n = axis.Unit
		local ra = hAv[1]*math.abs(n:Dot(axesA[1])) + hAv[2]*math.abs(n:Dot(axesA[2])) + hAv[3]*math.abs(n:Dot(axesA[3]))
		local rb = hBv[1]*math.abs(n:Dot(axesB[1])) + hBv[2]*math.abs(n:Dot(axesB[2])) + hBv[3]*math.abs(n:Dot(axesB[3]))
		return math.abs(t:Dot(n)) > ra + rb
	end

	for i = 1, 3 do
		if separated(axesA[i]) then return false end
		if separated(axesB[i]) then return false end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(axesA[i]:Cross(axesB[j])) then return false end
		end
	end
	return true
end
```

The `axis.Magnitude < EPS` skip is the classic SAT bug: when the boxes share a parallel
edge direction, the cross product is zero, `.Unit` is NaN, and every subsequent comparison
returns false — silently reporting "overlapping" for boxes that are far apart. Skipping
degenerate axes is safe because the parallel case is already covered by the six face normals.

For real `BasePart`s, `workspace:GetPartsInPart(part, params)` does this in C++ against the
broadphase. Write SAT only for shapes the engine doesn't know about.

---

## 7. Curves and paths

### 7.1 Bézier curves

**Explicit forms** (P₀…P₃ control points, `t ∈ [0,1]`):

```
Linear:     B(t) = (1−t)P₀ + tP₁
Quadratic:  B(t) = (1−t)²P₀ + 2(1−t)t·P₁ + t²P₂
Cubic:      B(t) = (1−t)³P₀ + 3(1−t)²t·P₁ + 3(1−t)t²·P₂ + t³P₃
```

**Derivatives** (the tangent — this is what gives you orientation along the path):

```
Quadratic:  B'(t) = 2(1−t)(P₁−P₀) + 2t(P₂−P₁)
Cubic:      B'(t) = 3(1−t)²(P₁−P₀) + 6(1−t)t(P₂−P₁) + 3t²(P₃−P₂)
Cubic:      B''(t) = 6(1−t)(P₂−2P₁+P₀) + 6t(P₃−2P₂+P₁)
```

Note `B'(0) = 3(P₁−P₀)` and `B'(1) = 3(P₃−P₂)` — the tangent at each end points at the
adjacent control point. That is how you make two Bézier segments join smoothly: keep
`P₂, P₃` of one and `P₀, P₁` of the next collinear with equal spacing (C¹ continuity).

```lua
local function bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	local uu, tt = u * u, t * t
	return p0 * (uu * u) + p1 * (3 * uu * t) + p2 * (3 * u * tt) + p3 * (tt * t)
end

local function bezier3Tangent(p0, p1, p2, p3, t: number): Vector3
	local u = 1 - t
	return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
end
```

**De Casteljau's algorithm** — repeated lerping. Slower than the explicit polynomial but
numerically stabler, works for any degree, and *splits* the curve for free (the intermediate
points are the control points of the two halves), which is how adaptive subdivision works.

```lua
local function deCasteljau(points: {Vector3}, t: number): Vector3
	local pts = table.clone(points)
	for level = #pts - 1, 1, -1 do
		for i = 1, level do
			pts[i] = pts[i]:Lerp(pts[i + 1], t)
		end
	end
	return pts[1]
end
```

### 7.2 Arc-length parameterization — the constant-speed problem

**The problem.** `t` is *not* distance. Feeding `t = elapsed / duration` into a Bézier
makes the object crawl where control points cluster and sprint where they spread. On any
curve with unequal control-point spacing this is immediately visible.

**The solution.** Build a lookup table mapping `t → cumulative arc length`, then invert it
by binary search plus linear interpolation.

```lua
local LUT = {}
LUT.__index = LUT

function LUT.new(evaluate: (number) -> Vector3, samples: number?)
	local n = samples or 128
	local ts, lengths = table.create(n + 1), table.create(n + 1)
	local total = 0
	local prev = evaluate(0)
	ts[1], lengths[1] = 0, 0
	for i = 1, n do
		local t = i / n
		local p = evaluate(t)
		total += (p - prev).Magnitude    -- chord length approximates arc length
		ts[i + 1], lengths[i + 1] = t, total
		prev = p
	end
	return setmetatable({ts = ts, lengths = lengths, total = total, evaluate = evaluate}, LUT)
end

--[[ Map a normalized DISTANCE s ∈ [0,1] to the curve parameter t. ]]
function LUT:tAtDistance(s: number): number
	local target = math.clamp(s, 0, 1) * self.total
	local lengths = self.lengths
	local lo, hi = 1, #lengths
	while lo < hi do                                 -- binary search for the bracketing sample
		local mid = (lo + hi) // 2
		if lengths[mid] < target then lo = mid + 1 else hi = mid end
	end
	if lo == 1 then return self.ts[1] end
	local l0, l1 = lengths[lo - 1], lengths[lo]
	local span = l1 - l0
	local frac = span > 1e-9 and (target - l0) / span or 0
	return self.ts[lo - 1] + (self.ts[lo] - self.ts[lo - 1]) * frac
end

--[[ Constant-speed position: pass normalized distance, not raw t. ]]
function LUT:pointAtDistance(s: number): Vector3
	return self.evaluate(self:tAtDistance(s))
end
```

Accuracy is `O(1/n²)` in the sample count because chords undercut arcs. 128 samples is
plenty for gameplay; use Gauss–Legendre quadrature on `|B'(t)|` if you need CAD accuracy.

### 7.3 Catmull-Rom — the right default for "a path through my points"

Bézier control points are *not on the curve*, which makes authoring a path through known
waypoints painful. **Catmull-Rom splines interpolate their control points** — the curve
passes exactly through each one — and are C¹ continuous. That is almost always what you
want for a rail, a patrol route, or a camera path.

**Uniform form** (segment between P₁ and P₂, using P₀ and P₃ as neighbours):

```
P(t) = 0.5·( (2P₁)
           + (−P₀ + P₂)·t
           + (2P₀ − 5P₁ + 4P₂ − P₃)·t²
           + (−P₀ + 3P₁ − 3P₂ + P₃)·t³ )
```

```lua
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return (p1 * 2
		+ (p2 - p0) * t
		+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
		+ (-p0 + p1 * 3 - p2 * 3 + p3) * t3) * 0.5
end

local function catmullRomTangent(p0, p1, p2, p3, t: number): Vector3
	local t2 = t * t
	return ((p2 - p0)
		+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (2 * t)
		+ (-p0 + p1 * 3 - p2 * 3 + p3) * (3 * t2)) * 0.5
end
```

**Why you should usually use the *centripetal* variant instead.** Uniform Catmull-Rom
develops **cusps and self-intersections** when control points are unevenly spaced —
specifically, when two points are close together relative to their neighbours, the curve
loops back on itself. The fix (Yuksel et al.) is to parameterize by
`tᵢ₊₁ = tᵢ + |Pᵢ₊₁ − Pᵢ|^α` with **α = 0.5** (centripetal). α = 0 is uniform, α = 1 is
chordal. Centripetal is *proven* to never cusp or self-intersect.

```lua
--[[ Centripetal Catmull-Rom via the Barry-Goldman pyramid. alpha: 0=uniform, 0.5=centripetal, 1=chordal. ]]
local function catmullRomAlpha(p0, p1, p2, p3, t: number, alpha: number?): Vector3
	local a = alpha or 0.5
	local function knot(ti: number, pa: Vector3, pb: Vector3): number
		return ti + ((pb - pa).Magnitude) ^ a
	end
	local t0 = 0
	local t1 = knot(t0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	if t1 - t0 < 1e-9 or t2 - t1 < 1e-9 or t3 - t2 < 1e-9 then
		return p1:Lerp(p2, t)      -- coincident points: fall back to a straight line
	end
	local tt = t1 + (t2 - t1) * math.clamp(t, 0, 1)

	local a1 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	local a2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	local a3 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	local b1 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	local b2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))
end
```

**Endpoints.** A Catmull-Rom segment needs a point on each side, so an open path of N points
yields N−1 segments only if you invent phantom endpoints. The standard choices are
reflection (`P₋₁ = 2P₀ − P₁`) or duplication (`P₋₁ = P₀`). Reflection preserves the
direction of the curve at the ends; duplication flattens it. For a **closed loop**, wrap the
indices instead.

### 7.4 Hermite and B-splines

**Hermite** takes two points and two *tangents* — the right form when you already know the
velocities (joining an in-flight object to a path, or blending animation).

```
h₀₀ = 2t³ − 3t² + 1      h₁₀ = t³ − 2t² + t
h₀₁ = −2t³ + 3t²         h₁₁ = t³ − t²
P(t) = h₀₀·P₀ + h₁₀·m₀ + h₀₁·P₁ + h₁₁·m₁
```

```lua
local function hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return p0 * (2*t3 - 3*t2 + 1) + m0 * (t3 - 2*t2 + t) + p1 * (-2*t3 + 3*t2) + m1 * (t3 - t2)
end
```

Catmull-Rom *is* Hermite with `mᵢ = (Pᵢ₊₁ − Pᵢ₋₁)/2`. Knowing that lets you convert freely.

**Uniform cubic B-spline** — C² continuous (curvature-continuous, so no visible "corner" in
the *acceleration*) but does **not** pass through its control points. Use it when smoothness
matters more than exact waypoints: camera dollies, terrain ridges, smoothing noisy input.

```
P(t) = (1/6)·[ (−P₀ + 3P₁ − 3P₂ + P₃)t³ + (3P₀ − 6P₁ + 3P₂)t² + (−3P₀ + 3P₂)t + (P₀ + 4P₁ + P₂) ]
```

```lua
local function bspline(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return ((-p0 + p1*3 - p2*3 + p3) * t3
		+ (p0*3 - p1*6 + p2*3) * t2
		+ (-p0*3 + p2*3) * t
		+ (p0 + p1*4 + p2)) * (1/6)
end
```

**Choosing**: waypoints must be hit → **centripetal Catmull-Rom**. Designer drags handles →
**Bézier**. Maximum smoothness, waypoints are hints → **B-spline**. Known endpoint
velocities → **Hermite**.

### 7.5 Moving along a path at constant speed with correct orientation

Everything combines here: arc-length reparameterization for constant speed, the derivative
for the tangent, and rotation-minimizing frames for twist-free orientation.

```lua
local RunService = game:GetService("RunService")

local Path = {}
Path.__index = Path

function Path.new(waypoints: {Vector3}, closed: boolean?)
	local self = setmetatable({points = waypoints, closed = closed or false}, Path)
	self.lut = LUT.new(function(t) return self:_raw(t) end, 256)
	return self
end

-- Evaluate the whole multi-segment spline at t ∈ [0,1] (uniform in segment index, not distance).
function Path:_raw(t: number): Vector3
	local pts = self.points
	local n = #pts
	local segments = self.closed and n or (n - 1)
	local scaled = math.clamp(t, 0, 1) * segments
	local i = math.min(math.floor(scaled), segments - 1)
	local localT = scaled - i

	local function at(k: number): Vector3
		if self.closed then return pts[(k % n) + 1] end
		return pts[math.clamp(k + 1, 1, n)]
	end
	return catmullRomAlpha(at(i - 1), at(i), at(i + 1), at(i + 2), localT, 0.5)
end

function Path:positionAtDistance(s: number): Vector3
	return self:_raw(self.lut:tAtDistance(s))
end

-- Finite-difference tangent in DISTANCE space, so it is already unit-ish and constant-speed.
function Path:tangentAtDistance(s: number): Vector3
	local h = 1e-3
	local a = self:positionAtDistance(math.clamp(s - h, 0, 1))
	local b = self:positionAtDistance(math.clamp(s + h, 0, 1))
	local d = b - a
	return d.Magnitude > 1e-9 and d.Unit or Vector3.zAxis
end

--[[ Drive a part along the path at `speed` studs/second, twist-free. ]]
function Path:drive(part: BasePart, speed: number)
	local travelled = 0
	local frameUp = Vector3.yAxis       -- carried reference vector (parallel transport)
	local prevTangent = self:tangentAtDistance(0)

	return RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt
		local s = (travelled / self.lut.total) % 1
		local pos = self:positionAtDistance(s)
		local tan = self:tangentAtDistance(s)

		-- Transport the up vector rather than recomputing it: no flip, no corkscrew.
		frameUp = (CFrame.fromRotationBetweenVectors(prevTangent, tan) * frameUp).Unit
		frameUp = (frameUp - tan * frameUp:Dot(tan)).Unit   -- re-orthogonalize against drift
		prevTangent = tan

		local right = tan:Cross(frameUp)
		part.CFrame = CFrame.fromMatrix(pos, right, frameUp, -tan):Orthonormalize()
	end)
end
```

Two details that make this production-grade rather than demo-grade: the up vector is
**transported**, not recomputed (so it cannot flip when the path goes vertical), and it is
**re-orthogonalized and the frame orthonormalized** every step (so accumulated float error
cannot skew the basis — §10.3).

---

## 8. Interpolation and easing

### 8.1 The primitives

```lua
math.lerp(a, b, t)                        -- a + (b - a) * t;  t is NOT clamped
math.map(x, inMin, inMax, outMin, outMax) -- linear remap
math.clamp(x, min, max)                   -- max must be >= min
```

`math.lerp` and `math.map` are real, verified library functions — don't hand-roll them. The
one you *do* hand-roll is inverse lerp:

```lua
local function invLerp(a: number, b: number, x: number): number
	if math.abs(b - a) < 1e-12 then return 0 end
	return (x - a) / (b - a)
end

-- math.map(x, a, b, c, d) == math.lerp(c, d, invLerp(a, b, x))
```

**Smoothstep** and **smootherstep** — ease-in-out curves with zero first (and for
smoother, second) derivative at both ends:

```
smoothstep(t)   = t²(3 − 2t)          = 3t² − 2t³
smootherstep(t) = t³(6t² − 15t + 10)  = 6t⁵ − 15t⁴ + 10t³
```

```lua
local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp(invLerp(a, b, x), 0, 1)
	return t * t * (3 - 2 * t)
end

local function smootherstep(a: number, b: number, x: number): number
	local t = math.clamp(invLerp(a, b, x), 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end
```

Smootherstep's continuous second derivative matters when the *acceleration* is visible —
camera moves, large UI transitions. For a 0.2-second fade, nobody can tell.

### 8.2 Frame-rate-independent smoothing — the important one

**The bug.** This is everywhere in Roblox code:

```lua
RunService.RenderStepped:Connect(function()
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.1)  -- WRONG
end)
```

Each frame it removes 10% of the remaining gap, so after `n` frames the remaining fraction
is `0.9ⁿ`. At 60 fps, one second leaves `0.9⁶⁰ ≈ 0.0018`. At 144 fps, one second leaves
`0.9¹⁴⁴ ≈ 3×10⁻⁷`. The camera is **dramatically tighter on a fast machine** — the same code
feels different on every device, and a frame hitch makes it lurch.

**The fix.** Exponential decay: the fraction remaining after time `dt` should be `e^(−k·dt)`,
so the alpha to feed a lerp is its complement.

```
alpha = 1 − exp(−k · dt)
```

`k` is a rate in units of 1/second: larger is snappier. Because
`e^(−k·t₁)·e^(−k·t₂) = e^(−k·(t₁+t₂))`, the result after one second is identical whether you
took one step, sixty, or a hundred and forty-four. That is exactly the property the naive
form lacks.

```lua
--[[ Frame-rate-independent exponential smoothing. `k` = responsiveness (1/s). ]]
local function damp(current: number, target: number, k: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-k * dt))
end

-- Same alpha works for any type with a Lerp:
local function dampCFrame(current: CFrame, target: CFrame, k: number, dt: number): CFrame
	return current:Lerp(target, 1 - math.exp(-k * dt))
end

--[[ Half-life form — far easier to tune, because the parameter is a time you can feel. ]]
local function dampHalfLife(current: number, target: number, halfLife: number, dt: number): number
	return current + (target - current) * (1 - 2 ^ (-dt / halfLife))
end
```

The half-life form is the one to standardize on in a codebase: "the camera closes half the
remaining distance every 0.08 s" is a sentence a designer can reason about; "k = 8.66" is not.
(They are the same thing: `k = ln2 / halfLife`.)

**Two remaining caveats.** Exponential smoothing never *arrives* — it approaches
asymptotically, so add a snap threshold if you need exact arrival. And it has no momentum,
so it can never overshoot; if you want overshoot, you want a spring.

### 8.3 Springs

A damped harmonic oscillator, integrated with **semi-implicit (symplectic) Euler** — update
velocity first, *then* use the new velocity to update position. That ordering is what makes
it stable; explicit Euler (position first) gains energy and eventually explodes.

```lua
local Spring = {}
Spring.__index = Spring

--[[
	stiffness: spring constant k (higher = faster)
	damping:   damping ratio ζ.  ζ<1 underdamped (overshoots/oscillates),
	                             ζ=1 critically damped (fastest with NO overshoot),
	                             ζ>1 overdamped (sluggish, no overshoot).
]]
function Spring.new(position: Vector3, stiffness: number, dampingRatio: number)
	return setmetatable({
		position = position, velocity = Vector3.zero, target = position,
		stiffness = stiffness, dampingRatio = dampingRatio,
	}, Spring)
end

function Spring:step(dt: number): Vector3
	-- c = 2ζ√k  for unit mass; ζ = 1 gives c = 2√k, the critically damped case.
	local c = 2 * self.dampingRatio * math.sqrt(self.stiffness)

	-- SUBSTEP: explicit integration is unstable when stiffness*dt² gets large.
	-- Cap the step at ~1/60 s so a frame hitch cannot detonate the spring.
	local steps = math.max(1, math.ceil(dt / (1 / 60)))
	local h = dt / steps
	for _ = 1, steps do
		local accel = (self.target - self.position) * self.stiffness - self.velocity * c
		self.velocity += accel * h        -- velocity FIRST
		self.position += self.velocity * h -- then position, using the NEW velocity
	end
	return self.position
end
```

**Critical damping** is `ζ = 1`, i.e. `c = 2√(k·m)`. It is the fastest approach with no
overshoot, and it is the right default for cameras, UI, and anything that should feel
"solid". Use `ζ ≈ 0.6–0.8` for a bit of life (weapon sway, hit reactions) and `ζ > 1` only
when you want deliberate sluggishness.

**The built-in.** `TweenService:SmoothDamp` is a real critically-damped spring, verified:

```lua
TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)
--> newValue, newVelocity
```

It "simulat[es] a critically damped spring", supports `number`, `Vector2`, `Vector3` and
`CFrame`, and **you must feed `newVelocity` back in on the next call** — the velocity is
the spring's state. `smoothTime` is "the duration over which the total smoothing operation
should take place… smaller values result in quicker smoothing", `maxSpeed` defaults to
`math.huge` (unclamped), and `dt` defaults to the engine's current delta time.

```lua
local vel = Vector3.zero
RunService.Heartbeat:Connect(function(dt)
	local newPos
	newPos, vel = TweenService:SmoothDamp(part.Position, target, vel, 0.25, nil, dt)
	part.Position = newPos
end)
```

Prefer this over a hand-rolled spring when critical damping is what you want: it runs in
C++, it is unconditionally stable, and `maxSpeed` gives you a clean velocity clamp.

### 8.4 TweenService and the easing matrix

```lua
TweenInfo.new(
	time: number = 1,
	easingStyle: Enum.EasingStyle = Enum.EasingStyle.Quad,
	easingDirection: Enum.EasingDirection = Enum.EasingDirection.Out,
	repeatCount: number = 0,
	reverses: boolean = false,
	delayTime: number = 0
)
TweenService:Create(instance, tweenInfo, propertyTable) --> Tween
TweenService:GetValue(alpha, easingStyle, easingDirection) --> number  (alpha clamped to [0,1])
```

Tweenable types include `number`, `boolean`, `CFrame`, `Rect`, `Color3`, `UDim`, `UDim2`,
`Vector2`, `Vector2int16`, `Vector3`, and `EnumItem`. Two tweens targeting the **same
property** conflict: "the initial tween will be cancelled and overwritten by the most recent
tween."

**`Enum.EasingStyle`** (verified values, with what each actually looks like):

| Style | Value | Character |
|---|---|---|
| `Linear` | 0 | Constant speed. Mechanical; correct for conveyor belts, wrong for almost everything else. |
| `Sine` | 1 | Gentlest ease. The safe default for UI. |
| `Quad` | 3 | Slightly sharper than Sine. TweenInfo's default style. |
| `Cubic` | 10 | Sharper than Quad. |
| `Quart` | 4 | Sharper than Cubic. |
| `Quint` | 5 | Sharper than Quart. |
| `Exponential` | 8 | "The sharpest curve". Near-instant start/end. |
| `Circular` | 9 | Circular arc: "acceleration is more sudden and deceleration more gradual" than Quint/Exponential. |
| `Back` | 2 | Overshoots slightly, then settles. Anticipation. |
| `Bounce` | 6 | Bounces several times before settling. |
| `Elastic` | 7 | Rubber-band overshoot, oscillating. |

**`Enum.EasingDirection`**: `In` (0) applies the style forward, `Out` (1) in reverse,
`InOut` (2) "forward for the first half and in reverse for the second half."

The rule that actually matters: **`Out` for things entering or responding to the user**
(fast start, gentle settle — feels responsive), **`In` for things leaving**, **`InOut` for
things moving between two resting states** (a camera, a door).

**`TweenService:GetValue` is the sleeper API.** It gives you Roblox's easing curves as a
pure function, so you can use them in code you drive yourself — on a spline, on a shader
parameter, on anything `Tween` can't touch:

```lua
local t = math.clamp(elapsed / duration, 0, 1)
local eased = TweenService:GetValue(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
part.CFrame = path:positionAtDistance(eased)   -- eased travel along a spline
```

### 8.5 Custom easing functions

When you need a curve Roblox doesn't ship — or want it without a service call:

```lua
local Ease = {}

function Ease.inQuad(t: number) return t * t end
function Ease.outQuad(t: number) return t * (2 - t) end
function Ease.inOutQuad(t: number)
	return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

function Ease.outBack(t: number, overshoot: number?)
	local s = overshoot or 1.70158
	local u = t - 1
	return u * u * ((s + 1) * u + s) + 1
end

function Ease.outElastic(t: number, period: number?)
	if t == 0 or t == 1 then return t end
	local p = period or 0.3
	return 2 ^ (-10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

function Ease.outBounce(t: number)
	local n, d = 7.5625, 2.75
	if t < 1 / d then return n * t * t
	elseif t < 2 / d then t -= 1.5 / d; return n * t * t + 0.75
	elseif t < 2.5 / d then t -= 2.25 / d; return n * t * t + 0.9375
	else t -= 2.625 / d; return n * t * t + 0.984375 end
end

--[[ Turn any In-style easing into Out and InOut. This is the general identity:
     out(t) = 1 - f(1 - t);  inOut(t) = f(2t)/2 for t<0.5, else 1 - f(2-2t)/2 ]]
function Ease.reverse(f: (number) -> number): (number) -> number
	return function(t) return 1 - f(1 - t) end
end

function Ease.mirror(f: (number) -> number): (number) -> number
	return function(t)
		if t < 0.5 then return f(2 * t) * 0.5 end
		return 1 - f(2 - 2 * t) * 0.5
	end
end
```

Those last two are worth memorizing — `Out` and `InOut` are *always* mechanical transforms
of `In`, which is exactly what `Enum.EasingDirection` is doing internally.

---

## 9. Randomness

### 9.1 `Random` vs `math.random`

`math.random` is a single global generator. Verified: "Internally, this uses a 32-bit PCG
(Permuted Congruential Generator)". `math.randomseed(x)` reseeds it globally — which is the
problem: **every seeded system in your game shares one stream**, so adding a `math.random`
call anywhere shifts every other system's output. Reproducibility dies.

`Random` objects are independent streams. Use them for anything that must be deterministic.

```lua
Random.new(seed: number?)             -- no seed: internal entropy source
r:NextInteger(min, max)               -- INCLUSIVE both ends; args truncated toward zero;
                                      -- if min > max the two are swapped rather than erroring
r:NextNumber()                        -- uniform over [0, 1]  — INCLUSIVE of BOTH endpoints
r:NextNumber(min, max)                -- uniform over [min, max], inclusive
r:NextUnitVector()                    -- "uniformly distributed over the unit sphere"
r:Shuffle(tb)                         -- in-place Fisher-Yates on the ARRAY PART
r:Clone()                             -- copy of the state; advances independently thereafter
```

**There is no `Random:NextGaussian`.** The member list above is complete. If you need a
normal distribution, write it (§9.3).

**Seeding.** "If you provide a seed, it should be within the range
[-9007199254740991, 9007199254740991], and `Random` will round it down to the nearest
integer. So seeds of 0, 0.99, and `math.random()` all produce identical generators."
That last clause is a real footgun: `Random.new(math.random())` is `Random.new(0)`, because
`math.random()` returns a value in `[0, 1)` which truncates to 0. Use
`Random.new(math.random(1, 2^31))` — which is exactly what the docs recommend ("If you need
to generate a seed and store it for later retrieval, use `math.random(max)`").

**`Random:Clone` is the tool for deterministic branching.** Fork the stream to explore a
possibility without disturbing the main sequence:

```lua
local master = Random.new(worldSeed)
local terrainRng = Random.new(master:NextInteger(1, 2^31))   -- derive independent sub-streams
local lootRng    = Random.new(master:NextInteger(1, 2^31))
-- Now adding loot rolls can never perturb terrain generation.
```

**`Shuffle` determinism**: "The shuffle is defined to be a Fisher-Yates shuffle so the number
of `NextInteger` calls is guaranteed to be consistent between engine versions for a given
size of table." That is a genuine stability guarantee — a seeded shuffle will replay
identically after an engine update. It "throws an error" on `nil` holes in the array part.

For reference, the manual version (needed when shuffling something that isn't a clean array,
or when you want to shuffle indices without touching data):

```lua
local function fisherYates<T>(t: {T}, rng: Random)
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)      -- j must be able to equal i, or the shuffle is biased
		t[i], t[j] = t[j], t[i]
	end
end
```

The classic bug is `rng:NextInteger(1, i - 1)`, which makes it impossible for an element to
stay put and produces a measurably non-uniform permutation.

### 9.2 Uniform sampling of shapes

**On a sphere.** Use `NextUnitVector()` — documented as uniform over the unit sphere.

The naive method — `Vector3.new(rng:NextNumber(-1,1), rng:NextNumber(-1,1), rng:NextNumber(-1,1)).Unit`
— is **biased**: it samples a cube and projects onto the sphere, concentrating points toward
the eight cube-corner directions (the corner is √3 ≈ 1.73 away, the face centre 1.0, so
corner directions capture more volume). Its variants:

```lua
-- Correct manual method 1: rejection sampling (unbiased, ~52% acceptance)
local function randomUnitVectorRejection(rng: Random): Vector3
	while true do
		local v = Vector3.new(rng:NextNumber(-1,1), rng:NextNumber(-1,1), rng:NextNumber(-1,1))
		local m2 = v:Dot(v)
		if m2 > 1e-9 and m2 <= 1 then return v / math.sqrt(m2) end
	end
end

-- Correct manual method 2: Archimedes' theorem — z uniform, azimuth uniform. No rejection.
local function randomUnitVectorArchimedes(rng: Random): Vector3
	local z = rng:NextNumber(-1, 1)
	local phi = rng:NextNumber(0, 2 * math.pi)
	local r = math.sqrt(math.max(0, 1 - z * z))
	return Vector3.new(r * math.cos(phi), r * math.sin(phi), z)
end
```

Method 2 works because the projection of a sphere onto its axis is uniform — the "z slice"
has constant area density. It is the reason a globe's map bands are equal-area in the
Lambert projection.

**Inside a sphere.** The naive `direction * rng:NextNumber(0, R)` is biased toward the
**centre**, because a shell at radius `r` has volume `∝ r²`. The cube root fixes it:

```lua
local function randomInSphere(rng: Random, radius: number): Vector3
	return rng:NextUnitVector() * (radius * rng:NextNumber() ^ (1/3))
end

-- Inside a disc (for spawn rings, AoE): square root, because area ∝ r²  →  r ∝ √u
local function randomInDisc(rng: Random, radius: number): Vector3
	local r = radius * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber(0, 2 * math.pi)
	return Vector3.new(r * math.cos(a), 0, r * math.sin(a))
end
```

General rule: to sample uniformly in `d` dimensions radially, use `u^(1/d)`.

**In a triangle** — the "fold" trick. Sample the unit square, then reflect the half that
lands outside the triangle back inside:

```lua
local function randomInTriangle(rng: Random, a: Vector3, b: Vector3, c: Vector3): Vector3
	local u, v = rng:NextNumber(), rng:NextNumber()
	if u + v > 1 then u, v = 1 - u, 1 - v end     -- fold the far half back
	return a + (b - a) * u + (c - a) * v
end
```

To scatter over a **mesh**, pick the triangle with probability proportional to its area
(`(b-a):Cross(c-a).Magnitude * 0.5`) using the weighted selection below, then sample within it.

### 9.3 Gaussian via Box–Muller

Given `u₁, u₂` independent uniform on `(0, 1]`:

```
z₀ = √(−2 ln u₁) · cos(2π u₂)
z₁ = √(−2 ln u₁) · sin(2π u₂)
```

Both `z₀` and `z₁` are standard normal and independent, so cache the spare.

```lua
local Gaussian = {}
Gaussian.__index = Gaussian

function Gaussian.new(rng: Random)
	return setmetatable({rng = rng, spare = nil}, Gaussian)
end

function Gaussian:next(mean: number?, sd: number?): number
	local mu, sigma = mean or 0, sd or 1
	if self.spare then
		local z = self.spare
		self.spare = nil
		return mu + sigma * z
	end
	-- CRITICAL: NextNumber() is documented as INCLUSIVE of 0, and log(0) = -inf.
	local u1 = self.rng:NextNumber()
	while u1 <= 0 do u1 = self.rng:NextNumber() end
	local u2 = self.rng:NextNumber()
	local r = math.sqrt(-2 * math.log(u1))
	local theta = 2 * math.pi * u2
	self.spare = r * math.sin(theta)
	return mu + sigma * (r * math.cos(theta))
end
```

That `u1 <= 0` loop is not defensive paranoia. Roblox's `NextNumber()` is explicitly
documented as returning a value in `[0, 1]` **inclusive of both endpoints**, unlike
`math.random()` which is documented as "inclusive of `0` but exclusive of `1`". Hit the
zero and you get `-inf` → `NaN` propagating into a position.

Note also: Box–Muller's tails are truncated at roughly ±6σ by float precision. For gameplay
that is a feature, not a bug — but clamp explicitly if a wild sample would break something.

### 9.4 Weighted selection and the alias method

**Linear scan** — O(n) per sample, O(1) setup. Correct choice for small or frequently
changing weight tables:

```lua
local function weightedPick<T>(rng: Random, items: {T}, weights: {number}): T
	local total = 0
	for _, w in weights do total += w end
	local roll = rng:NextNumber() * total
	local acc = 0
	for i, w in weights do
		acc += w
		if roll <= acc then return items[i] end
	end
	return items[#items]    -- float-rounding fallback; do not omit
end
```

**Vose's alias method** — O(n) setup, **O(1) per sample**. Use it when you sample a fixed
distribution thousands of times (particle types, loot tables, procedural tile selection).

```lua
local Alias = {}
Alias.__index = Alias

function Alias.new(weights: {number})
	local n = #weights
	local total = 0
	for _, w in weights do total += w end

	local prob, alias = table.create(n), table.create(n)
	local scaled = table.create(n)
	local small, large = {}, {}
	for i = 1, n do
		scaled[i] = weights[i] * n / total
		if scaled[i] < 1 then table.insert(small, i) else table.insert(large, i) end
	end

	while #small > 0 and #large > 0 do
		local s = table.remove(small)
		local l = table.remove(large)
		prob[s], alias[s] = scaled[s], l
		scaled[l] = scaled[l] + scaled[s] - 1     -- move the deficit onto the large bucket
		if scaled[l] < 1 then table.insert(small, l) else table.insert(large, l) end
	end
	while #large > 0 do local l = table.remove(large); prob[l], alias[l] = 1, l end
	while #small > 0 do local s = table.remove(small); prob[s], alias[s] = 1, s end

	return setmetatable({prob = prob, alias = alias, n = n}, Alias)
end

function Alias:sample(rng: Random): number
	local i = rng:NextInteger(1, self.n)          -- pick a bucket
	return rng:NextNumber() < self.prob[i] and i or self.alias[i]  -- then a coin flip inside it
end
```

The idea: n buckets each of height 1, each holding at most two outcomes. One integer roll
picks a bucket, one float roll picks which of its two outcomes. Constant time regardless of
how many outcomes exist.

### 9.5 `math.noise` — exactly what it is

Verified, in full:

- **Algorithm**: Perlin noise. `math.noise(x, y?, z?)`; omitted arguments are treated as 0,
  so `math.noise(1.158)` ≡ `math.noise(1.158, 0, 0)`.
- **Range**: "most often between the range of `-1` to `1` (inclusive) but sometimes may be
  outside that range; if the interval is critical to you, use `math.clamp(noise, -1, 1)`".
  **The range is not guaranteed.** Clamp if you are indexing an array with it.
- **Practical amplitude**: "For fractional values of `x`, `y`, and `z`, the return value will
  gradually fluctuate between `-0.5` and `0.5`." So the *typical* excursion is about half
  the nominal range — scale accordingly rather than assuming full ±1.
- **Integer inputs return exactly 0.** `math.noise(3, 5, 2) == 0`. This is intrinsic to
  Perlin (lattice points are where the gradients are anchored). If you sample on integer
  coordinates you will get a field of zeros — **always offset and scale your inputs.**
- **Period 256 per axis**: "`math.noise(x, y, z)` and `math.noise(x + 256, y, z)` return
  identical values." Any world larger than 256 units in noise space tiles visibly. Scale
  your coordinates so the feature you care about fits inside that window, or sum octaves at
  irrational frequency ratios to hide the repeat.
- **Deterministic and unseedable**: "`math.noise(1.158, 5.723)` will always return
  `0.48397532105446`". There is no seed parameter — the only way to vary the field is to
  **offset the sample coordinates**.

```lua
--[[ Fractal Brownian motion: the standard way to turn one octave into terrain. ]]
local function fbm(x: number, z: number, octaves: number, lacunarity: number?, gain: number?): number
	local lac = lacunarity or 2.0345   -- deliberately irrational-ish: hides the period-256 tiling
	local g = gain or 0.5
	local sum, amp, freq, norm = 0, 1, 1, 0
	for _ = 1, octaves do
		sum += math.noise(x * freq, z * freq) * amp
		norm += amp
		amp *= g
		freq *= lac
	end
	return sum / norm            -- normalized back to roughly the single-octave range
end

--[[ "Seeding": offset the sample point. There is no seed argument. ]]
local function seededNoise(seed: number, x: number, z: number): number
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-1000, 1000), rng:NextNumber(-1000, 1000)
	return math.noise(x + ox, z + oz)
end
```

For **Ridged** noise use `1 - math.abs(n)`; for **turbulence** sum `math.abs(n)` per octave.
Both are one-line variants of `fbm` and both are how mountain ridges and cloud wisps are made.

---

## 10. Numerical care

### 10.1 Two float widths, and where they meet

Luau `number` is a **double** (64-bit): "around 15 digits of precision". But the engine
stores transforms as **single-precision floats** — the reference's `float` type is "a
single-precision (32-bit) floating-point number", and Luau's native `vector` is
`LUA_VECTOR_TYPE = float` (verified in the VM headers).

So every value that crosses into `BasePart.CFrame`, `Position`, `Size`, or a `Vector3`
component is **rounded to 24 significant bits**. Compute in doubles; expect float32 on
readback.

```lua
local p = Vector3.new(1/3, 0, 0)
print(string.format("%.17f", p.X))  -- NOT 0.33333333333333331; it's the float32 nearest
```

Float32 ULP is about `x · 2⁻²³`:

| Distance from origin | Approximate ULP |
|---|---|
| 100 studs | ~0.0000076 studs |
| 1,000 | ~0.000061 |
| 16,384 (2¹⁴) | ~0.00195 |
| 131,072 (2¹⁷) | ~0.0156 |
| 1,048,576 (2²⁰) | ~0.125 |
| **8,388,608 (2²³)** | **1.0 — integers only beyond here** |

Symptoms as you go out: physics jitter, camera shake, animation stepping, rounding of small
offsets to nothing. Community bug reports put visible degradation around the tens of
thousands of studs, well before the theoretical limit.

Mitigations: keep gameplay near the origin; use a **floating origin** (periodically recentre
the world and the camera); compute *relative* offsets rather than differences of two large
absolute positions (`(a - b)` catastrophically cancels when `a ≈ b` and both are huge).

Verified limits worth knowing: `BasePart.Size` dimensions "can be as low as `0.001` and as
high as `2048`", and "Size dimensions below `0.05` will be **physically** simulated as if
the part's dimensions are `0.05`" while rendering the true size.

### 10.2 Epsilon comparisons

Never `==` on floats. Never a fixed absolute epsilon on values whose scale you don't control.

```lua
local function nearlyEqual(a: number, b: number, eps: number?): boolean
	local e = eps or 1e-5
	local diff = math.abs(a - b)
	if diff <= e then return true end                      -- absolute: handles values near 0
	return diff <= e * math.max(math.abs(a), math.abs(b))  -- relative: handles large values
end
```

The engine gives you this for free on the datatypes, and it does the hybrid correctly:

- `Vector3:FuzzyEq(other, epsilon?)` — default `1e-5`; "per-component using a hybrid epsilon
  that scales relative to the magnitude of each component, making it suitable for both small
  and large values."
- `CFrame:FuzzyEq(other, epsilon?)` — default `1e-5`; position compared component-wise,
  "rotation uses a fast approximation of the angle difference."

Use them. Hand-rolled epsilon comparison on CFrames is almost always wrong because people
compare the twelve components independently, which is not a meaningful rotation metric —
`a:AngleBetween(b)` is.

### 10.3 Rotation drift and re-orthonormalization

Every `CFrame * CFrame` rounds. Multiply thousands of times and the 3×3 stops being
orthonormal: the axes drift out of perpendicular and off unit length, and the transform
starts to shear and scale. Visually: a part slowly squashing, a mesh skewing, an arm
stretching.

The reference tells you exactly where the risk is: `CFrame:Orthonormalize()` "Returns an
orthonormalized copy… The `BasePart.CFrame` property automatically applies
orthonormalization, but other APIs which take `CFrame`s do not, so this method is
occasionally necessary when incrementally updating a `CFrame` and using it with them."

So: assigning to `part.CFrame` cleans up after you. Feeding the same accumulated CFrame into
`Motor6D.Transform`, `Bone.Transform`, `AlignOrientation`, a `WorldPivot`, an `EditableMesh`
vertex transform, or your own maths does **not**.

```lua
-- BAD: error compounds forever
local cf = CFrame.identity
RunService.Heartbeat:Connect(function(dt)
	cf = cf * CFrame.Angles(0, dt, 0)
	motor.Transform = cf                 -- no auto-orthonormalization here
end)

-- GOOD (a): periodic cleanup
	cf = (cf * CFrame.Angles(0, dt, 0)):Orthonormalize()

-- BEST (b): don't accumulate. Track the scalar and rebuild.
local angle = 0
RunService.Heartbeat:Connect(function(dt)
	angle = (angle + dt) % (2 * math.pi)
	motor.Transform = CFrame.Angles(0, angle, 0)   -- exact every frame; also wraps cleanly
end)
```

Option (b) is strictly better where it applies: no drift *and* no orthonormalization cost.
Accumulate CFrames only when the motion genuinely has no closed form.

Manual Gram-Schmidt, if you need it somewhere `Orthonormalize` can't reach:

```lua
local function orthonormalize(cf: CFrame): CFrame
	local up = cf.UpVector.Unit
	local look = cf.LookVector
	local right = look:Cross(up).Unit    -- perpendicular to up by construction
	local newLook = up:Cross(right)      -- perpendicular to both by construction
	return CFrame.fromMatrix(cf.Position, right, up, -newLook)
end
```

### 10.4 Degrees versus radians

Every angle in the Roblox math and CFrame APIs is in **radians**: `math.sin/cos/tan/asin/
acos/atan/atan2`, all `CFrame.Angles`/`fromEulerAngles*`/`fromAxisAngle` constructors, all
`ToEulerAngles*`/`ToAxisAngle`/`AngleBetween` decompositions, `Vector3:Angle`.

Every angle in the **property** surface is in **degrees**: `BasePart.Orientation` ("the
part's rotation in degrees"), `BasePart.Rotation` ("in degrees for the three axes"), and
UI/constraint properties like `UIGradient.Rotation`, `HingeConstraint` angle limits,
`Camera.FieldOfView`.

Adopt a naming discipline and the whole class of bug disappears:

```lua
local MAX_PITCH_DEG = 89
local MAX_PITCH_RAD = math.rad(MAX_PITCH_DEG)

local function spinRad(part: BasePart, radians: number) ... end
local function spinDeg(part: BasePart, degrees: number) return spinRad(part, math.rad(degrees)) end
```

Suffix every angle variable and constant with `Deg` or `Rad`. `math.rad` converts degrees→
radians; `math.deg` converts radians→degrees. Also available: `math.pi`, `math.tau`
(= 2π, verified), `math.e`, `math.phi`, `math.sqrt2`.

### 10.5 NaN: sources and detection

NaN is *contagious* and *silent*. Every comparison with it is false — including `nan == nan`.
Roblox surfaces `math.nan` as a constant and warns: "Comparing directly to `math.nan` will
always return false; use `math.isnan()` instead."

**Sources, in rough order of how often they actually happen:**

1. `Vector3.Unit` / `vector.normalize` on a zero vector. Documented.
2. `CFrame.lookAt` with the direction parallel to `up` (via the zero cross product). §2.2.
3. `math.acos(x)` with `|x| > 1` from float rounding on a dot product of "unit" vectors.
   Always `math.acos(math.clamp(d, -1, 1))`.
4. `0/0` — including `inf * 0` in the slab test (§6.4).
5. `math.sqrt` of a slightly negative discriminant that should have been exactly zero.
   Clamp: `math.sqrt(math.max(0, disc))`.
6. `math.log(0)` → `-inf`, then `-inf * 0` → NaN. Box–Muller, §9.3.
7. Division by an accumulated-to-zero magnitude in a spring or steering loop.

**Detection and containment:**

```lua
math.isnan(x)      -- true iff x is NaN
math.isinf(x)      -- true iff ±math.huge
math.isfinite(x)   -- "neither NaN nor positive or negative infinity"

local function vectorIsFinite(v: Vector3): boolean
	return math.isfinite(v.X) and math.isfinite(v.Y) and math.isfinite(v.Z)
end

--[[ Assert at the WRITE boundary. NaN caught here names the system that produced it;
     NaN caught three systems later names nobody. ]]
local function setCFrameChecked(part: BasePart, cf: CFrame)
	local x, y, z = cf.X, cf.Y, cf.Z
	if not (math.isfinite(x) and math.isfinite(y) and math.isfinite(z)) then
		warn(`[math] non-finite CFrame for {part:GetFullName()}; ignoring`, debug.traceback())
		return
	end
	part.CFrame = cf
end
```

Guard at every boundary where a computed transform enters the engine. That one habit turns
"the character teleported to nowhere and the server errored ten seconds later" into a single
warning with a stack trace pointing at the actual culprit.

---

## Recipes

### R1. A look-at that never flips

The two-line version of §2.2, for the common case where you control the yaw/pitch state:

```lua
--[[ Yaw/pitch look-at. Cannot gimbal-lock (pitch is clamped) and cannot roll (rz = 0). ]]
local function aimAt(from: Vector3, to: Vector3, maxPitchDeg: number?): CFrame
	local d = to - from
	local flat = Vector3.new(d.X, 0, d.Z)
	local horiz = flat.Magnitude
	if horiz < 1e-6 then
		-- Target is directly above or below: preserve the previous yaw rather than snapping.
		horiz = 1e-6
	end
	local yaw = math.atan2(-d.X, -d.Z)               -- -Z is forward, hence the negations
	local pitch = math.atan2(d.Y, horiz)
	local limit = math.rad(maxPitchDeg or 89)
	pitch = math.clamp(pitch, -limit, limit)
	return CFrame.new(from) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
end
```

For the general case (arbitrary up vectors, surface-relative aiming), use `safeLookAlong`
from §2.2.

### R2. Smooth follow camera

Exponential damping on position (frame-rate independent, §8.2) and slerp on rotation via
`CFrame:Lerp` (§4.4). Separate rates, because position and rotation want different feels.

```lua
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local POS_HALFLIFE = 0.10   -- seconds to close half the positional gap
local ROT_HALFLIFE = 0.06   -- rotation should lead position slightly: snappier

RunService:BindToRenderStep("FollowCam", Enum.RenderPriority.Camera.Value, function(dt)
	local subject = workspace.CurrentCamera.CameraSubject
	if not subject or not subject.Parent then return end

	local targetCF = CFrame.lookAt(
		subject.Position + Vector3.new(0, 4, 0) - camera.CFrame.LookVector * 12,
		subject.Position + Vector3.new(0, 2, 0)
	)

	local aPos = 1 - 2 ^ (-dt / POS_HALFLIFE)
	local aRot = 1 - 2 ^ (-dt / ROT_HALFLIFE)

	local pos = camera.CFrame.Position:Lerp(targetCF.Position, aPos)
	local rot = camera.CFrame.Rotation:Lerp(targetCF.Rotation, aRot)  -- slerped
	camera.CFrame = rot + pos
end)
```

`rot + pos` works because `CFrame + Vector3` translates in world space and `rot` has zero
position — so the sum is exactly "this rotation, at that point."

For a springy camera with overshoot, swap the position damp for `TweenService:SmoothDamp`
(§8.3) and keep the slerp for rotation.

### R3. Arcing projectile: solve for launch velocity

**Given target and flight time** — this is the one you want, because flight time is a
gameplay parameter you can tune, and the solution is exact and has no failure case.

From `p₁ = p₀ + v·T + ½·a·T²`, solve for **v**:

```
v = (p₁ − p₀ − ½·a·T²) / T
```

```lua
--[[ Velocity that carries a projectile from `from` to `to` in exactly `time` seconds. ]]
local function launchVelocity(from: Vector3, to: Vector3, time: number, gravity: number?): Vector3
	assert(time > 0, "flight time must be positive")
	local g = gravity or workspace.Gravity           -- studs/s², positive magnitude
	local a = Vector3.new(0, -g, 0)
	return (to - from - a * (0.5 * time * time)) / time
end

-- Aim at a MOVING target by predicting where it will be (first-order lead):
local function launchVelocityLeading(from: Vector3, target: BasePart, time: number): Vector3
	local predicted = target.Position + target.AssemblyLinearVelocity * time
	return launchVelocity(from, predicted, time)
end
```

**Given a fixed launch speed** — the classic ballistics problem, which *can* fail. With
horizontal distance `d`, height difference `h`, speed `s`, gravity `g`:

```
tan θ = ( s² ± √(s⁴ − g(g·d² + 2h·s²)) ) / (g·d)
```

The `+` root is the **high arc** (lobbed, mortar); the `−` root is the **low arc** (direct,
fast). A negative discriminant means the target is out of range at that speed.

```lua
--[[ Returns lowArcVelocity, highArcVelocity — or nil if out of range. ]]
local function ballisticVelocities(from: Vector3, to: Vector3, speed: number, gravity: number?)
	local g = gravity or workspace.Gravity
	local delta = to - from
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local d = flat.Magnitude
	local h = delta.Y

	if d < 1e-6 then                                  -- straight up/down: degenerate
		return Vector3.new(0, speed, 0), Vector3.new(0, speed, 0)
	end

	local s2 = speed * speed
	local disc = s2 * s2 - g * (g * d * d + 2 * h * s2)
	if disc < 0 then return nil end                   -- unreachable at this speed

	local root = math.sqrt(disc)
	local dir = flat / d
	local function build(tanTheta: number): Vector3
		local theta = math.atan(tanTheta)
		return dir * (speed * math.cos(theta)) + Vector3.new(0, speed * math.sin(theta), 0)
	end
	return build((s2 - root) / (g * d)), build((s2 + root) / (g * d))
end
```

To **draw the arc** (a trajectory preview line), just evaluate the closed form — never
simulate:

```lua
local function trajectoryPoint(from: Vector3, v: Vector3, t: number, gravity: number?): Vector3
	local g = gravity or workspace.Gravity
	return from + v * t + Vector3.new(0, -g, 0) * (0.5 * t * t)
end
```

### R4. Homing and steering

Two layers, and the distinction matters: **steering** shapes velocity (Reynolds-style
forces); a **turn-rate clamp** enforces a physical maximum agility. Real homing needs both.

```lua
--[[ Seek: accelerate toward the target, capped. Classic Reynolds steering. ]]
local function seek(position: Vector3, velocity: Vector3, target: Vector3,
                    maxSpeed: number, maxForce: number): Vector3
	local toTarget = target - position
	if toTarget.Magnitude < 1e-6 then return Vector3.zero end
	local desired = toTarget.Unit * maxSpeed
	local steering = desired - velocity
	if steering.Magnitude > maxForce then
		steering = steering.Unit * maxForce
	end
	return steering                        -- an ACCELERATION: integrate it, don't assign it
end

--[[ Turn-rate clamp: rotate `current` toward `desired` by at most `maxTurnRad`.
     This is the shortest-arc rotation (§4.5) with the angle limited. ]]
local function turnToward(current: Vector3, desired: Vector3, maxTurnRad: number): Vector3
	local a, b = current.Unit, desired.Unit
	local angle = a:Angle(b)
	if angle <= maxTurnRad or angle ~= angle then return b end   -- (angle ~= angle catches NaN)
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-6 then
		-- Exactly antiparallel: any perpendicular axis is valid; pick a stable one.
		axis = a:Cross(Vector3.yAxis)
		if axis.Magnitude < 1e-6 then axis = a:Cross(Vector3.xAxis) end
	end
	return (CFrame.fromAxisAngle(axis.Unit, maxTurnRad) * a).Unit
end

--[[ A homing missile: constant speed, limited agility, arrives without orbiting. ]]
local function stepMissile(missile: BasePart, target: Vector3, speed: number,
                            turnRateRadPerSec: number, dt: number)
	local dir = turnToward(missile.CFrame.LookVector, target - missile.Position,
		turnRateRadPerSec * dt)
	missile.CFrame = CFrame.lookAlong(missile.Position + dir * speed * dt, dir)
end
```

The turn-rate clamp is what stops a missile from snapping instantly onto the target (which
looks wrong and is unfun). It also produces the characteristic "miss and loop back" when
the target is too agile — emergent, not scripted.

### R5. Surface alignment for a walking creature

One raycast gives you a normal but reacts to every pebble. Sample several points under the
footprint and average, weighting the centre:

```lua
local function groundFrame(position: Vector3, facing: Vector3, footprint: number,
                            params: RaycastParams): CFrame?
	local half = footprint * 0.5
	local offsets = {
		Vector3.zero,
		Vector3.new( half, 0,  half), Vector3.new(-half, 0,  half),
		Vector3.new( half, 0, -half), Vector3.new(-half, 0, -half),
	}
	local weights = {2, 1, 1, 1, 1}        -- centre counts double: less foot-wobble

	local normalSum, pointSum, total = Vector3.zero, Vector3.zero, 0
	for i, off in offsets do
		local hit = workspace:Raycast(position + off + Vector3.new(0, 3, 0),
			Vector3.new(0, -10, 0), params)
		if hit then
			local w = weights[i]
			normalSum += hit.Normal * w
			pointSum += hit.Position * w
			total += w
		end
	end
	if total == 0 then return nil end      -- airborne

	local normal = normalSum / total
	if normal.Magnitude < 1e-5 then return nil end
	normal = normal.Unit

	-- Reject the facing onto the ground plane so the creature leans with the slope.
	local forward = facing - normal * facing:Dot(normal)
	if forward.Magnitude < 1e-5 then return nil end
	forward = forward.Unit
	local right = forward:Cross(normal)
	return CFrame.fromMatrix(pointSum / total, right, normal, -forward)
end
```

Then **damp** toward that frame rather than snapping to it (§8.2) — instant alignment reads
as robotic, and a 0.08 s half-life reads as a creature adjusting its footing:

```lua
local aligned = groundFrame(pos, facing, 3, params)
if aligned then
	root.CFrame = root.CFrame:Lerp(aligned, 1 - 2 ^ (-dt / 0.08))
end
```

Clamp the maximum slope you will align to (`normal:Dot(Vector3.yAxis) > math.cos(math.rad(50))`)
or the creature will happily stand sideways on a wall.

### R6. Snapping to a grid

```lua
local function snap(x: number, grid: number): number
	return math.round(x / grid) * grid
end

--[[ Snap a position to a world grid, optionally offset (e.g. half-grid for cell centres). ]]
local function snapVector(v: Vector3, grid: Vector3, offset: Vector3?): Vector3
	local o = offset or Vector3.zero
	local shifted = (v - o) / grid                       -- component-wise divide
	return Vector3.new(math.round(shifted.X), math.round(shifted.Y), math.round(shifted.Z)) * grid + o
end

--[[ Snap a rotation to the nearest N-th of a turn about Y — the placement-tool standard. ]]
local function snapYaw(cf: CFrame, divisions: number): CFrame
	local _, y = cf:ToEulerAnglesYXZ()                   -- YXZ: y is clean yaw
	local step = (2 * math.pi) / divisions
	return CFrame.new(cf.Position) * CFrame.fromEulerAnglesYXZ(0, math.round(y / step) * step, 0)
end
```

`math.round` is verified to round **away from zero** at midpoints (`0.5 → 1`, `-0.5 → -1`),
which is what you want for symmetric grids — `math.floor(x + 0.5)` is subtly asymmetric for
negative coordinates and will misplace objects west/south of the origin.

For a building system, snap the object's **corner or footprint**, not its centre, or
odd-sized parts will land half-off the grid:

```lua
local half = part.Size * 0.5
local snappedMin = snapVector(part.Position - half, Vector3.one * 4)
part.Position = snappedMin + half
```

### R7. Orbiting with damping

Damp the *angle*, not the position — that way the object always travels along the orbit
circle instead of cutting a chord across it.

```lua
local Orbit = {}
Orbit.__index = Orbit

function Orbit.new(center: Vector3, radius: number, halfLife: number)
	return setmetatable({
		center = center, radius = radius, halfLife = halfLife,
		yaw = 0, pitch = 0, targetYaw = 0, targetPitch = 0, targetRadius = radius,
	}, Orbit)
end

--[[ Shortest-path angular difference, wrapped to (-π, π]. Without this, going from
     350° to 10° takes the 340° route. ]]
local function angleDelta(from: number, to: number): number
	local d = (to - from) % (2 * math.pi)
	if d > math.pi then d -= 2 * math.pi end
	return d
end

function Orbit:step(dt: number): CFrame
	local a = 1 - 2 ^ (-dt / self.halfLife)
	self.yaw += angleDelta(self.yaw, self.targetYaw) * a
	self.pitch += (math.clamp(self.targetPitch, math.rad(-80), math.rad(80)) - self.pitch) * a
	self.radius += (self.targetRadius - self.radius) * a
	return CFrame.new(self.center)
		* CFrame.fromEulerAnglesYXZ(self.pitch, self.yaw, 0)
		* CFrame.new(0, 0, self.radius)
end
```

The `angleDelta` wrap is the whole recipe. Every "my camera spun all the way around when I
crossed north" bug is a missing modular wrap on an angle difference.

### R8. Screen position to world ray

```lua
local camera = workspace.CurrentCamera

--[[ Cast from a screen point. `x, y` are in CoreUI-inset coordinates — the ones that
     match GuiObject.AbsolutePosition and UserInputService mouse position. ]]
local function castFromScreen(x: number, y: number, range: number, params: RaycastParams)
	local unitRay = camera:ScreenPointToRay(x, y)        -- UNIT ray: 1 stud long
	return workspace:Raycast(unitRay.Origin, unitRay.Direction * range, params)
end

--[[ Cast from the exact centre of the viewport (a crosshair). ]]
local function castFromCrosshair(range: number, params: RaycastParams)
	local vp = camera.ViewportSize / 2
	local unitRay = camera:ViewportPointToRay(vp.X, vp.Y, 0)
	return workspace:Raycast(unitRay.Origin, unitRay.Direction * range, params)
end
```

**The two things that go wrong here.**

*First*, `workspace:Raycast(origin, direction, params)` treats the **magnitude of `direction`
as the maximum distance** — it is not a unit direction plus a separate range argument. Both
camera methods return "a unit `Ray`… it is only one stud long", so a raycast with the raw
`unitRay.Direction` searches exactly one stud and finds nothing. Multiply.

*Second*, the two camera methods use **different coordinate systems**, and the reference is
emphatic about it:

- `ScreenPointToRay(x, y, depth?)` — **accounts for the GUI inset** (the top bar). `(0,0)` is
  the top-left *below* the top bar. This is the `CoreUISafeInsets` system, which is what
  `GuiObject.AbsolutePosition` uses. **Use this for mouse and UI coordinates.**
- `ViewportPointToRay(x, y, depth?)` — **does not** account for the CoreUI inset (it does
  account for `DeviceSafeInsets`). `(0,0)` is the top-left *of the Roblox top bar*. This is
  the system `Camera.ViewportSize` is in. **Use this for viewport-relative math** like a
  centred crosshair.

Mix them up and everything is offset vertically by the top-bar height — a bug that looks
like "my aiming is slightly high" and survives a long time because it is small and constant.

Both carry the same caveat: they "only work for the `Workspace.CurrentCamera` camera. Other
cameras, such as those you create for a `ViewportFrame`, have an initial viewport size of
`(1, 1)`" and will return wrong directions.

**Going the other way** — world to screen:

```lua
local screenPos, onScreen = camera:WorldToViewportPoint(worldPosition)
if onScreen and screenPos.Z > 0 then              -- Z is depth; <= 0 means BEHIND the camera
	billboard.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
end
```

The `screenPos.Z > 0` check is mandatory: for points behind the camera the projection still
returns finite X/Y (mirrored through the origin), so without it your marker appears on the
wrong side of the screen when you turn away. `WorldToScreenPoint` is the GUI-inset twin,
matching `ScreenPointToRay`.

---

## Sources

All API signatures, parameter defaults, return orders, and quoted behavioral notes were
verified against the generated reference YAML in `Roblox/creator-docs` (the source the
Creator Hub reference pages are built from) and, for the Luau VM details, the Luau source.

**Roblox Creator Documentation** (`create.roblox.com/docs`, source of record:
`github.com/Roblox/creator-docs`):

- CFrame — https://create.roblox.com/docs/reference/engine/datatypes/CFrame
  ([source YAML](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/CFrame.yaml))
- Vector3 — https://create.roblox.com/docs/reference/engine/datatypes/Vector3
  ([source YAML](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/Vector3.yaml))
- Vector2 — https://create.roblox.com/docs/reference/engine/datatypes/Vector2
- Ray — https://create.roblox.com/docs/reference/engine/datatypes/Ray
- Region3 — https://create.roblox.com/docs/reference/engine/datatypes/Region3
- Random — https://create.roblox.com/docs/reference/engine/datatypes/Random
  ([source YAML](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/Random.yaml))
- TweenInfo — https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo
- `math` library — https://create.roblox.com/docs/reference/engine/libraries/math
  ([source YAML](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/libraries/math.yaml))
- `vector` library — https://create.roblox.com/docs/reference/engine/libraries/vector
- TweenService (incl. `GetValue`, `SmoothDamp`) — https://create.roblox.com/docs/reference/engine/classes/TweenService
- Camera (`ScreenPointToRay`, `ViewportPointToRay`, `WorldToViewportPoint`, `WorldToScreenPoint`) — https://create.roblox.com/docs/reference/engine/classes/Camera
- WorldRoot (`Raycast`, `Blockcast`, `Spherecast`, `Shapecast`, `GetPartsInPart`) — https://create.roblox.com/docs/reference/engine/classes/WorldRoot
- BasePart (`CFrame`, `Orientation`, `Rotation`, `Size` limits) — https://create.roblox.com/docs/reference/engine/classes/BasePart
- `Enum.EasingStyle` — https://create.roblox.com/docs/reference/engine/enums/EasingStyle
- `Enum.EasingDirection` — https://create.roblox.com/docs/reference/engine/enums/EasingDirection
- `Enum.RotationOrder` — https://create.roblox.com/docs/reference/engine/enums/RotationOrder
- CFrames guide — https://create.roblox.com/docs/workspace/cframes
- Numbers (double vs float, int) — https://create.roblox.com/docs/luau/numbers

**Luau** (`luau.org`; source of record: `github.com/luau-lang`):

- Standard library / `vector` — https://luau.org/library
- Vector library RFC — https://rfcs.luau.org/vector-library.html
- `LUA_VECTOR_SIZE` = 3 and `LUA_VECTOR_TYPE` = `float` — https://github.com/luau-lang/luau/blob/master/VM/include/luaconf.h
- `lua_pushvector` / `lua_tovector` — https://github.com/luau-lang/luau/blob/master/VM/include/lua.h

**Roblox DevForum** (technique threads and community resources):

- Native Luau Vector3 Beta (value type, SIMD, allocation removal) — https://devforum.roblox.com/t/native-luau-vector3-beta/1180548
- A Couple of Advanced CFrame Tricks — https://devforum.roblox.com/t/a-couple-of-advanced-cframe-tricks/337682
- Frame rate independent lerp? — https://devforum.roblox.com/t/frame-rate-independent-lerp/352375
- Creating Framerate-Independent / Discretized Iterative Lerp + Slerp — https://devforum.roblox.com/t/creating-framerate-independentdiscretized-iterative-lerp-slerp/3455078
- How to actually create frame independant lerping — https://devforum.roblox.com/t/how-to-actually-create-frame-independant-lerping/3228324
- Catmull-Rom Spline Class (Superior to Bezier Curve) — https://devforum.roblox.com/t/catmull-rom-spline-class-superior-to-bezier-curve/1827910
- CRSplineModules (smooth curve through control points) — https://devforum.roblox.com/t/catmull-rom-spline-module-smooth-curve-that-goes-through-control-points/1568205
- `CatRom` (arc-length / unit-speed reparameterization) — https://github.com/ecurtiss/CatRom
- Loss of precision at distances far from origin — https://devforum.roblox.com/t/loss-of-precision-causes-game-breaking-issues-at-distances-far-from-origin/202782
- Maximum distance from origin before things get glitchy — https://devforum.roblox.com/t/maximum-distance-from-origin-before-things-get-glitchy/1651347
- `CFrame.lookAt()` up-vector / twisting threads — https://devforum.roblox.com/t/cframelookat-but-prevent-twisting-and-breaking/1881589 · https://devforum.roblox.com/t/cframelookat-up-value-ant-like-wall-crawling/2925323

**Algorithms** (standard references for the maths, not Roblox-specific):

- Möller & Trumbore, *Fast, Minimum Storage Ray/Triangle Intersection* (1997)
- Ericson, *Real-Time Collision Detection* (2004) — closest-point-on-triangle regions, slab method, SAT for OBBs
- Wang, Jüttler, Zheng & Liu, *Computation of Rotation Minimizing Frames* (ACM TOG, 2008) — the double-reflection method in §4.6
- Yuksel, Schaefer & Keyser, *Parameterization and Applications of Catmull–Rom Curves* (2011) — the centripetal (α = ½) variant and its no-cusp guarantee
- Shoemake, *Animating Rotation with Quaternion Curves* (SIGGRAPH 1985) — slerp
- Shepperd, *Quaternion from Rotation Matrix* (1978) — the branch-on-largest-diagonal extraction in §4.3
- Box & Muller, *A Note on the Generation of Random Normal Deviates* (1958)
- Vose, *A Linear Algorithm for Generating Random Numbers with a General Distribution* (1991) — the alias method
- Reynolds, *Steering Behaviors for Autonomous Characters* (1999) — seek/arrive in R4
- Fernando, *Improved Lerp Smoothing* — https://www.gamedeveloper.com/programming/improved-lerp-smoothing-
