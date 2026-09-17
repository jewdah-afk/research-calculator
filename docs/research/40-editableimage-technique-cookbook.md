# The EditableImage Technique Cookbook

*Runtime-generated and runtime-modified images in Roblox Studio: what to build, how the algorithm works, what it costs, and which genres it serves.*

This chapter is the **applications** half of the EditableImage story. The raw API reference lives in its own chapter; here the API only appears inside working code. Every signature below was checked against the `Roblox/creator-docs` YAML source on `main` (the same source that renders `create.roblox.com/docs`) in September 2026, because this API has changed shape repeatedly — `ReadPixels`/`WritePixels` (table-based) gave way to `ReadPixelsBuffer`/`WritePixelsBuffer`, and assignment moved from `Parent`-ing the instance to the `Content` datatype.

**Verification status legend used throughout:**
- **[DOC]** — quoted or derived from official `creator-docs` YAML/Markdown.
- **[CODE]** — read from published open-source Luau (repo cited).
- **[COMM]** — community report (devforum/itch). Treated as a claim, not a measurement, unless a method is given.
- **[UNVERIFIED]** — my own reasoning or arithmetic. Flagged so you can test it yourself.

> **Research access caveat, stated up front:** `create.roblox.com`, `devforum.roblox.com`, `robloxapi.github.io` and `itch.io` were all blocked by the network egress proxy from this environment. Official API facts were therefore taken from the **`Roblox/creator-docs` GitHub mirror**, which is the upstream source of the docs site and is authoritative. DevForum content was reachable only through search-engine summarization, not direct page reads — so **every devforum-sourced number below is second-hand and marked [COMM]**. Do not put a [COMM] number in a design doc without re-measuring. I could not find a single rigorous, reproducible, published microbenchmark (ms/frame with stated hardware and method) for EditableImage anywhere. That absence is itself a finding: **the community operates on FPS anecdotes, not frame-time data.**

---

## TL;DR for builders

- **The hard ceiling is not pixels, it's presentation.** [DOC] *"Only a single `EditableImage` can be updated per frame on the display side... if you update three `EditableImage` objects which are currently being displayed, it will take three frames for all of them to be updated."* Architect for **one visible canvas**, not many. This single sentence invalidates most naive designs.
- **1024×1024 is the wall.** [DOC] `Size` is read-only and *"The maximum size is 1024×1024."* There is no resize; you create a new image and `DrawImageTransformed` the old one into it.
- **Never think in pixels; think in `buffer`s.** `ReadPixelsBuffer`/`WritePixelsBuffer` move RGBA bytes. All real work happens in Luau `buffer` memory, and you push to the image once per frame. Per-pixel API calls are the classic beginner disaster.
- **`buffer.copy` doubling is the fastest fill in Luau.** Write one pixel, then repeatedly copy the filled prefix onto itself — O(log n) calls instead of O(n) writes. [CODE] This is exactly what `FastCanvas` does.
- **You cannot read the rendered frame.** No screen-space post-processing. `CaptureService` output cannot be turned into an `EditableImage` at runtime [COMM]. Everything "post-process" is a *fake* drawn into a full-screen `ImageLabel`.
- **For painting on meshes, prefer `DrawImageProjected` over hand-rolled UV math.** It handles UV seams and wrapping that a raycast→UV lookup cannot. Hand-rolled UV painting produces visible tears across UV islands.
- **`RaycastLocal` and `FindClosestPointOnSurface` return their tuples in *different orders*.** [DOC] `(point, faceId, barycentric)` vs `(faceId, point, barycentric)`. This is a live footgun.
- **Accumulate paint by writing, never by read-modify-write of the whole buffer.** Keep the canvas in a Luau buffer you own; the `EditableImage` is a write-only display target. A full `ReadPixelsBuffer` every splat is the #1 paint-system performance bug.
- **Sync strokes, not pixels.** A 1024² canvas is 4 MB; a stroke is ~10 bytes. Compress strokes into a `buffer` and replay deterministically on every client.
- **Memory is a budget you *will* exhaust.** [DOC] *"EditableImage has strict client-side memory budgets, although the server, Studio, and plugins operate with unlimited memory."* Creation returns `nil` on exhaustion — **always nil-check**. [COMM] reports cluster around a ~32 MB client budget and developers hitting it after ~5–8 images.
- **Software rendering is real but lives at 100×100–200×200.** [COMM] The best-known raytracer (RetroRaster) runs "18 FPS to well over 150 FPS" at **100×100**. That is the honest ceiling for per-pixel-per-frame work.
- **`--!native` and Parallel Luau are the two multipliers that matter.** But `WritePixelsBuffer` is **not thread-safe** — parallel actors compute into buffers, and a serial pass does the single write.
- **There is no font rasterizer.** Text means a bitmap glyph atlas or an SDF atlas you ship yourself. Budget for it early; it is the most commonly underestimated piece.
- **Runtime PBR now exists.** [DOC] `AssetService:CreateSurfaceAppearanceAsync` accepts `ColorMap`/`NormalMap`/`RoughnessMap`/`MetalnessMap`/`EmissiveMask` — but *"the `EditableImage` assigned to each map cannot be reassigned or swapped after the `SurfaceAppearance` is created."*

---

## 0. Ground truth: the six calls everything is built on

Enough API to make the rest of the chapter runnable. All **[DOC]**.

```lua
local AssetService = game:GetService("AssetService")

-- Create blank (default 512x512; Size option sets dimensions). Returns nil if budget exhausted.
local img: EditableImage? = AssetService:CreateEditableImage({ Size = Vector2.new(512, 512) })
assert(img, "EditableImage budget exhausted")

-- Create from an existing texture (yields). Accepts rbxassetid:// and rbxthumb://.
local fromAsset = AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://123456789"))

-- Display it. `Content.fromObject` is the modern binding; parenting the instance is the old way.
imageLabel.ImageContent   = Content.fromObject(img)   -- ImageLabel / ImageButton
meshPart.TextureContent   = Content.fromObject(img)   -- MeshPart
decal.TextureContent      = Content.fromObject(img)   -- Decal / Texture

-- Pixel transfer. RGBA, one byte per channel, row-major.
local buf: buffer = img:ReadPixelsBuffer(Vector2.zero, img.Size)
img:WritePixelsBuffer(Vector2.zero, img.Size, buf)

-- Reclaim memory immediately.
img:Destroy()
```

**Signatures you will actually type** (exact, from the YAML):

| Call | Signature |
|---|---|
| `ReadPixelsBuffer` | `(position: Vector2, size: Vector2) -> buffer` |
| `WritePixelsBuffer` | `(position: Vector2, size: Vector2, buffer: buffer) -> ()` |
| `DrawRectangle` | `(position: Vector2, size: Vector2, color: Color3, transparency: number, combineType: Enum.ImageCombineType)` |
| `DrawCircle` | `(center: Vector2, radius: number, color: Color3, transparency: number, combineType, antiAliasing: Enum.AntiAliasing = Enabled)` |
| `DrawLine` | `(p1: Vector2, p2: Vector2, color: Color3, transparency: number, combineType, antiAliasing = Enabled)` — **one pixel thick** |
| `DrawImage` | `(position: Vector2, image: EditableImage, combineType)` |
| `DrawImageTransformed` | `(position: Vector2, scale: Vector2, rotation: number, image: EditableImage, options: {CombineType?, SamplingMode?, PivotPoint?})` |
| `DrawImageProjected` | `(mesh: EditableMesh, projection: {Direction, Position, Size, Up}, brushConfig: {Decal, ColorBlendType, AlphaBlendType, FadeAngle, BlendIntensity})` |

`Enum.ImageCombineType`: `BlendSourceOver`(1), `Overwrite`(2), `Add`(3), `Multiply`(4), `AlphaBlend`(5), `NormalMapBlend`(6), `Subtract`(7). The existence of **`NormalMapBlend`** — *"blends... then renormalizes the resulting RGB values"* — is a strong hint that Roblox intends you to composite normal maps at runtime.

`Enum.ImageAlphaType`: `Default`(1), `LockCanvasAlpha`(2), `LockCanvasColor`(3). `LockCanvasAlpha` is how you paint color without eating a mask; `LockCanvasColor` is how you carve a mask without touching color.

**The buffer layout.** [DOC] *"Each number in the buffer is a single byte, with pixels stored in a sequence of four bytes (red, green, blue, and alpha)."* So for a `W`-wide image:

```lua
local function index(x: number, y: number, W: number): number   -- 0-based x,y
    return (y * W + x) * 4
end
```

Two access idioms, and the choice matters:

```lua
-- Per-channel: readable, 4 calls.
buffer.writeu8(buf, i,     r)
buffer.writeu8(buf, i + 1, g)
buffer.writeu8(buf, i + 2, b)
buffer.writeu8(buf, i + 3, a)

-- Packed u32: 1 call. Little-endian, so byte order is R,G,B,A -> A<<24 | B<<16 | G<<8 | R.
local rgba = bit32.bor(bit32.lshift(a,24), bit32.lshift(b,16), bit32.lshift(g,8), r)
buffer.writeu32(buf, i, rgba)
```

[CODE] `FastCanvas` uses exactly this packing (`Ethanthegrand/FastCanvas`, `FastCanvas.luau`):

```lua
function Canvas:SetRGBA(X, Y, R, G, B, A)
    buffer.writeu32(Grid, GetGridIndex(X, Y), bit32bor(
        bit32lshift(A * 255, 24),
        bit32lshift(B * 255, 16),
        bit32lshift(G * 255, 8),
        R * 255)
    )
end
```

**Use `u32` whenever you write a whole pixel.** It is one bounds-check and one store instead of four.

---

## 1. Painting and marking systems

**Genres:** shooters (bullet holes, scorch), horror (blood, grime), Splatoon-likes, vehicle/graffiti sandboxes, survival (dirt, snow, mud), tycoon/decorating, art games.

### 1.1 The central problem: from a world hit to a pixel

You raycast, you get a `RaycastResult` with `.Position`, `.Normal`, `.Instance`. You now need the **texel** under that point. There are three routes, and they are not equivalent.

#### Route A — Planar projection onto a flat part (easy, limited)

For an axis-aligned face of a `Part`, this is just a change of basis. Cheap, exact, no mesh data needed.

```lua
-- Map a world point on a flat face to UV in [0,1]^2, given the face's CFrame and size.
local function worldToFaceUV(faceCF: CFrame, faceSize: Vector2, worldPos: Vector3): Vector2
    local lp = faceCF:PointToObjectSpace(worldPos)          -- local space of the face
    local u = (lp.X / faceSize.X) + 0.5
    local v = 0.5 - (lp.Y / faceSize.Y)                     -- flip: image Y grows downward
    return Vector2.new(u, v)
end

local function uvToPixel(uv: Vector2, imgSize: Vector2): (number, number)
    return math.floor(uv.X * imgSize.X), math.floor(uv.Y * imgSize.Y)
end
```

This is the whole trick behind wall-graffiti games. It fails the moment the surface is a mesh.

#### Route B — `EditableMesh` raycast → barycentric UV interpolation (exact, fiddly)

[DOC] `EditableMesh:RaycastLocal(origin, direction)` returns *"the point of intersection, face ID, and barycentric coordinates."* Combine with `GetFaceVertices`, `GetVertexFaceUV`, `GetUV`.

```lua
-- Returns UV (Vector2) at a world-space hit on a MeshPart backed by an EditableMesh, or nil.
local function uvAtWorldHit(meshPart: MeshPart, em: EditableMesh, origin: Vector3, dir: Vector3): Vector2?
    -- RaycastLocal works in the mesh's LOCAL object space.
    local lOrigin = meshPart.CFrame:PointToObjectSpace(origin)
    local lDir    = meshPart.CFrame:VectorToObjectSpace(dir)

    -- NOTE ORDER: (point, faceId, barycentric)
    local _point, faceId, bary = em:RaycastLocal(lOrigin, lDir)
    if not faceId then return nil end

    local verts = em:GetFaceVertices(faceId)            -- {vId1, vId2, vId3}
    local uv1 = em:GetUV(em:GetVertexFaceUV(verts[1], faceId))
    local uv2 = em:GetUV(em:GetVertexFaceUV(verts[2], faceId))
    local uv3 = em:GetUV(em:GetVertexFaceUV(verts[3], faceId))
    if not (uv1 and uv2 and uv3) then return nil end

    -- Barycentric interpolation: bary.X/Y/Z are the weights of vert 1/2/3.
    return uv1 * bary.X + uv2 * bary.Y + uv3 * bary.Z
end
```

> **Footgun [DOC]:** `FindClosestPointOnSurface` returns *"the face ID, point on the mesh in local object space, and the barycentric coordinate"* — **faceId first**. `RaycastLocal` returns **point first**. Mixing them up silently gives you a `Vector3` where you expected an integer.

**Why Route B is not enough on its own.** A brush is a *disc* in world space, but a disc in world space is an arbitrarily distorted blob in UV space, and it may straddle several UV islands. Stamping an axis-aligned square at the interpolated UV produces (a) stretching wherever texel density varies, and (b) a hard cut at every UV seam. You can fix this by walking neighbouring faces and re-projecting per-face — which is precisely reimplementing decal projection by hand.

#### Route C — `DrawImageProjected` (the intended answer)

[DOC] Roblox shipped `DrawImageProjected(mesh, projection, brushConfig)` for exactly this, announced Jan 2025 as *"Projecting decals to EditableMesh"* [COMM]. It projects a source image through a box-shaped projector onto the mesh's surface and writes the result into the destination image **in UV space**, handling the seam/island problem for you.

```lua
local AssetService = game:GetService("AssetService")

-- One-time setup per paintable mesh.
local em  = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId))
local tex = AssetService:CreateEditableImageAsync(Content.fromUri(meshPart.TextureID))
meshPart.TextureContent = Content.fromObject(tex)

-- Brush stamp (small: 64x64 is what Roblox's own reference tool uses).
local brush = AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://SPLAT_ID"))

local function stamp(worldPos: Vector3, worldNormal: Vector3, radius: number, tint: Color3)
    -- Projector frame in the mesh's LOCAL space.
    local localPos = meshPart.CFrame:PointToObjectSpace(worldPos)
    local localDir = meshPart.CFrame:VectorToObjectSpace(-worldNormal)  -- pointing INTO the surface

    -- Any stable 'up' not parallel to the direction. Randomise for splatter variety.
    local ref = math.abs(localDir.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
    local up  = localDir:Cross(ref):Cross(localDir).Unit

    tex:DrawImageProjected(em, {
        Position  = localPos - localDir * radius,   -- pull back so the box straddles the surface
        Direction = localDir,
        Up        = up,
        Size      = Vector3.new(radius * 2, radius * 2, radius * 4), -- X,Y = footprint; Z = depth
    }, {
        Decal          = brush,
        ColorBlendType = Enum.ImageCombineType.BlendSourceOver,
        AlphaBlendType = Enum.ImageAlphaType.Default,
        FadeAngle      = 60,    -- degrees; fades out on faces steeply angled to the projector
        BlendIntensity = 1,
    })
end
```

**`FadeAngle` is the quality knob.** [DOC] It fades the stamp based on the angle between the surface normal and the projector. Without it, a projector punches straight through a cylinder and paints the far side too — the classic decal-projection artifact. `180` disables fading.

**`Size.Z` is the projection depth** — make it comfortably larger than the local surface relief, but *not* so large that it reaches unrelated geometry behind.

[CODE] Roblox's own reference implementation (`Roblox/avatar`, `ReferenceBodyCreator/.../Brushes/ProjectionBrush.lua` + `TextureManipulation/TextureUtils.lua`) does exactly this and adds three production details worth copying:
1. **Two textures, not one**: a **64×64 circle** for dabs and a **4×4 line** texture stretched between the previous and current cast points, so fast mouse movement leaves a continuous stroke instead of dotted stamps.
2. **OBB pre-test**: `Utils.TestOBBCollision()` between each candidate `MeshPart` and the projector box, so a stroke across a scene only calls `DrawImageProjected` on meshes the projector actually touches. **This is the scalability trick for multi-part painting.**
3. **Two-pass transparency**: paint at full alpha into a scratch `EditableImage`, scale that image's alpha, then composite with `BlendSourceOver`. Doing it in one pass makes overlapping dabs within a single stroke compound their opacity, which looks wrong.

### 1.2 Accumulating paint without re-reading the buffer

The naive splat loop is:

```lua
-- ANTI-PATTERN. Do not do this.
local buf = img:ReadPixelsBuffer(Vector2.zero, img.Size)  -- 4 MB copy at 1024x1024
-- ...modify a 32x32 region...
img:WritePixelsBuffer(Vector2.zero, img.Size, buf)        -- 4 MB copy back
```

At 1024², that is **8 MB of memory traffic to change 4 KB of pixels** — a 2000× amplification.

**The discipline: you own the canvas; the image is a write-only sink.**

```lua
local W, H = 1024, 1024
local canvas = buffer.create(W * H * 4)   -- authoritative CPU-side copy, 4 MB
local img = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })

-- Dirty rectangle accumulated across the frame.
local dx0, dy0, dx1, dy1 = math.huge, math.huge, -math.huge, -math.huge

local function markDirty(x0, y0, x1, y1)
    if x0 < dx0 then dx0 = x0 end
    if y0 < dy0 then dy0 = y0 end
    if x1 > dx1 then dx1 = x1 end
    if y1 > dy1 then dy1 = y1 end
end

-- Stamp a soft circular splat straight into `canvas` (source-over, premultiplied-free).
local function splat(cx, cy, radius, r, g, b, strength)
    local x0 = math.max(0, cx - radius); local x1 = math.min(W - 1, cx + radius)
    local y0 = math.max(0, cy - radius); local y1 = math.min(H - 1, cy + radius)
    local r2 = radius * radius
    for y = y0, y1 do
        local row = y * W * 4
        local dy = y - cy
        for x = x0, x1 do
            local dx = x - cx
            local d2 = dx*dx + dy*dy
            if d2 <= r2 then
                -- Soft falloff: 1 at centre, 0 at rim.
                local a = (1 - d2 / r2) * strength
                local i = row + x * 4
                local sr = buffer.readu8(canvas, i)
                local sg = buffer.readu8(canvas, i + 1)
                local sb = buffer.readu8(canvas, i + 2)
                buffer.writeu8(canvas, i,     sr + (r - sr) * a)
                buffer.writeu8(canvas, i + 1, sg + (g - sg) * a)
                buffer.writeu8(canvas, i + 2, sb + (b - sb) * a)
                buffer.writeu8(canvas, i + 3, 255)
            end
        end
    end
    markDirty(x0, y0, x1, y1)
end

-- Once per frame: push ONLY the dirty rect.
local function flush()
    if dx1 < dx0 then return end                       -- nothing changed
    local w, h = dx1 - dx0 + 1, dy1 - dy0 + 1
    local sub = buffer.create(w * h * 4)
    for row = 0, h - 1 do
        buffer.copy(sub, row * w * 4, canvas, ((dy0 + row) * W + dx0) * 4, w * 4)
    end
    img:WritePixelsBuffer(Vector2.new(dx0, dy0), Vector2.new(w, h), sub)
    dx0, dy0, dx1, dy1 = math.huge, math.huge, -math.huge, -math.huge
end
```

**Cost model** [UNVERIFIED — arithmetic, measure on target hardware]: a 32-radius splat touches ~3200 pixels ≈ 3200 iterations of a ~10-op inner loop. Dozens of splats per frame is comfortable. A full 1024² rewrite is 1,048,576 iterations — **three orders of magnitude more**, and will not fit in a frame in interpreted Luau.

**When the dirty rect degenerates.** Two splats in opposite corners produce a dirty rect covering the whole canvas. Fix with **tiles**: split the canvas into 64×64 or 128×128 tiles, mark tiles dirty, and flush each dirty tile with its own `WritePixelsBuffer`. Bounded worst case, and it composes with the per-frame presentation limit (flush at most N tiles per frame, queue the rest).

### 1.3 The Splatoon problem: team coverage scoring

You need *coverage percentage per team*, and you must not scan 1 M pixels to get it.

**Technique: maintain the count incrementally, in the splat loop.** Keep a separate 1-byte-per-pixel **owner map** (0 = unpainted, 1..N = team). Every time you overwrite a texel, decrement the old owner's counter and increment the new one.

```lua
local owner = buffer.create(W * H)      -- 1 MB at 1024x1024
local counts = table.create(8, 0)
counts[1] = 0 -- team 1 ... etc.

local function paintTexel(i1: number, team: number)   -- i1 = y*W + x
    local prev = buffer.readu8(owner, i1)
    if prev == team then return end
    if prev ~= 0 then counts[prev] -= 1 end
    counts[team] += 1
    buffer.writeu8(owner, i1, team)
end
```

Coverage is then `counts[team] / (W*H)` in **O(1)**, no scan ever. This is the single most important optimisation in a coverage game — the alternative (periodic full scans) costs a million reads per scan.

**Resolution tiering for coverage.** You do not need the owner map at visual resolution. Run the owner/score map at **256×256** (65 KB) while the visible paint texture runs at 1024². Scoring accuracy of 1/65536 is far beyond what players can perceive.

### 1.4 Dirt, snow and footprints (accumulation and decay)

These are **subtractive masks**, not color. Keep an 8-bit coverage mask, and drive a `SurfaceAppearance` from it.

```lua
-- Footprint: subtract snow coverage in a foot-shaped stamp.
local function footprint(cx, cy, w, h)
    for y = cy - h, cy + h do
        for x = cx - w, cx + w do
            local i = y * W + x
            local v = buffer.readu8(mask, i)
            buffer.writeu8(mask, i, v > 40 and (v - 40) or 0)
        end
    end
end

-- Global decay (snow refilling). Run on a slow cadence over a rolling slice of rows.
local decayRow = 0
local function decayStep(rowsPerFrame: number)
    for _ = 1, rowsPerFrame do
        local base = decayRow * W
        for x = 0, W - 1 do
            local i = base + x
            local v = buffer.readu8(mask, i)
            if v < 255 then buffer.writeu8(mask, i, v + 1) end
        end
        decayRow = (decayRow + 1) % H
    end
end
```

`decayStep(8)` at 60 fps sweeps a 512-row image every ~1.07 s while touching only 8×512 = 4096 texels per frame. **This "rolling slice" pattern is the general answer to any whole-image operation that does not need to complete this frame** — it turns an O(N) spike into an O(N/k) steady cost.

### 1.5 Genre notes

| Effect | Best route | Resolution | Notes |
|---|---|---|---|
| Bullet holes on flat walls | Route A + tile flush | 512² per wall | Cheapest of all; replaces per-hole `Decal` + invisible part, which [COMM] is a known draw-call/overdraw problem |
| Blood on characters | `DrawImageProjected` | 256²–512² per char | `FadeAngle ~70` to avoid painting through limbs |
| Graffiti sandbox | Route A + stroke sync | 1024² per wall | See §2 for networking |
| Splatoon coverage | Route C visual + 256² owner map | dual-res | O(1) scoring via §1.3 |
| Scorch marks | Route A, `Multiply` combine | 512² | `Multiply` darkens without needing to read the base |
| Mud/snow footprints | 8-bit mask → `SurfaceAppearance` | 512² | Rolling-slice decay |

---

## 2. Canvas and drawing games

**Genres:** Pictionary/Gartic clones, art sandboxes, classroom/roleplay whiteboards, pixel-art MMOs (r/place clones), tabletop map annotation, level editors.

### 2.1 Brush engine

A brush is a **stamp function** plus a **spacing rule**. The naive approach (stamp once per input event) produces dotted lines at high mouse speed, because input events are sparse relative to motion.

```lua
-- Distance-based stamping: emit dabs every `spacing` pixels along the segment.
local carry = 0
local function strokeSegment(x0, y0, x1, y1, spacing, stampFn)
    local dx, dy = x1 - x0, y1 - y0
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1e-4 then stampFn(x0, y0); return end
    local ux, uy = dx / len, dy / len
    local t = -carry
    while t <= len do
        if t >= 0 then stampFn(x0 + ux * t, y0 + uy * t) end
        t += spacing
    end
    carry = (len + carry) % spacing
end
```

`carry` preserves sub-spacing phase across segments — without it, short segments each restart the dab rhythm and the stroke visibly clumps at input samples.

**Soft brush with opacity accumulation.** The correct model: a stroke has a *maximum* opacity; dabs within one stroke must not compound past it. Use a **per-stroke alpha accumulation buffer**.

```lua
-- strokeAlpha: 8-bit, cleared at stroke start. Records max coverage reached this stroke.
local strokeAlpha = buffer.create(W * H)

local function softDab(cx, cy, radius, hardness, flow)
    local r2 = radius * radius
    local inner = radius * hardness
    for y = math.max(0, cy - radius), math.min(H - 1, cy + radius) do
        local dy = y - cy
        for x = math.max(0, cx - radius), math.min(W - 1, cx + radius) do
            local dx = x - cx
            local d2 = dx*dx + dy*dy
            if d2 <= r2 then
                local d = math.sqrt(d2)
                -- Smooth falloff from `inner` to `radius`.
                local a = d <= inner and 1 or (1 - (d - inner) / (radius - inner))
                a = a * a * (3 - 2 * a)          -- smoothstep
                local want = math.floor(a * flow * 255)
                local i = y * W + x
                if want > buffer.readu8(strokeAlpha, i) then
                    buffer.writeu8(strokeAlpha, i, want)   -- max(), not +=
                end
            end
        end
    end
end

-- On stroke END (or per frame for live preview), composite strokeAlpha over the canvas.
local function commitStroke(r, g, b, opacity)
    for i1 = 0, W * H - 1 do
        local a = buffer.readu8(strokeAlpha, i1)
        if a > 0 then
            local a01 = (a / 255) * opacity
            local i = i1 * 4
            local sr = buffer.readu8(canvas, i)
            local sg = buffer.readu8(canvas, i + 1)
            local sb = buffer.readu8(canvas, i + 2)
            buffer.writeu32(canvas, i, bit32.bor(
                bit32.lshift(255, 24),
                bit32.lshift(math.floor(sb + (b - sb) * a01), 16),
                bit32.lshift(math.floor(sg + (g - sg) * a01), 8),
                math.floor(sr + (r - sr) * a01)))
        end
    end
    buffer.fill(strokeAlpha, 0, 0)
end
```

`commitStroke` as written is a full-canvas scan — acceptable once per stroke-end, **not** per frame. For live preview, track the stroke's bounding box and composite only that.

**Input smoothing with Catmull–Rom.** Raw pointer samples are polygonal. Fit a spline through the last four points and stamp along it:

```lua
local function catmullRom(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2*p0 - 5*p1 + 4*p2 - p3) * t2 +
        (-p0 + 3*p1 - 3*p2 + p3) * t3
    )
end

-- Stamp along the p1->p2 span of the spline.
local function strokeSpline(p0, p1, p2, p3, stampFn, steps)
    for s = 0, steps do
        local t = s / steps
        local p = catmullRom(p0, p1, p2, p3, t)
        stampFn(p.X, p.Y)
    end
end
```

Catmull–Rom passes through its control points (unlike a B-spline), which is what you want for drawing — the line goes where the user pointed.

### 2.2 Flood fill

[CODE] OSGL (`osgl-rbx/osgl`, `src/draw/floodFill.luau`) uses the right algorithm: **iterative, stack-based, 4-way, span-filling**, comparing packed `u32` colors. It explicitly *"uses horizontal spans to minimize stack operations."* Recursion is wrong here — a 1024² fill can nest a million deep and blow the Luau stack.

```lua
local function floodFill(buf: buffer, W: number, H: number, sx: number, sy: number, newColor: number)
    local target = buffer.readu32(buf, (sy * W + sx) * 4)
    if target == newColor then return end

    local stack = { sx, sy }
    while #stack > 0 do
        local y = table.remove(stack)
        local x = table.remove(stack)

        -- Walk left to the start of the span.
        while x > 0 and buffer.readu32(buf, (y * W + x - 1) * 4) == target do x -= 1 end

        local spanAbove, spanBelow = false, false
        local idx = (y * W + x) * 4
        while x < W and buffer.readu32(buf, idx) == target do
            buffer.writeu32(buf, idx, newColor)

            if y > 0 then
                local up = buffer.readu32(buf, ((y - 1) * W + x) * 4) == target
                if up and not spanAbove then
                    stack[#stack + 1] = x; stack[#stack + 1] = y - 1; spanAbove = true
                elseif not up then spanAbove = false end
            end
            if y < H - 1 then
                local dn = buffer.readu32(buf, ((y + 1) * W + x) * 4) == target
                if dn and not spanBelow then
                    stack[#stack + 1] = x; stack[#stack + 1] = y + 1; spanBelow = true
                elseif not dn then spanBelow = false end
            end

            x += 1; idx += 4
        end
    end
end
```

**Cost** [UNVERIFIED]: O(filled pixels), ~4–6 buffer ops each. A full-canvas 1024² fill is ~1 M iterations — **budget a frame or more for it**. Either run it across frames (pop a bounded number of spans per frame and flush) or cap fill area. **Tolerance-based fill** (matching within a threshold rather than exactly) requires unpacking channels and costs ~3× more per pixel.

### 2.3 Undo

Two designs, and the right answer is usually the hybrid.

| | Tile snapshots | Command replay |
|---|---|---|
| Memory | 16 KB/tile at 64² RGBA × touched tiles × depth | ~16–32 B per stroke |
| Undo cost | O(touched tiles) — instant | O(strokes since last keyframe) — can be seconds |
| Redo | Trivial | Trivial |
| Network | Heavy | Free (you already send strokes) |
| Non-determinism risk | None | Any brush change breaks history |

**Hybrid (recommended):** command log + periodic tile keyframes.

```lua
local TILE = 64
local TX, TY = W // TILE, H // TILE

-- Before a stroke modifies a tile for the first time in this stroke, snapshot it.
local function snapshotTile(tx, ty): buffer
    local b = buffer.create(TILE * TILE * 4)
    for row = 0, TILE - 1 do
        buffer.copy(b, row * TILE * 4, canvas, (((ty * TILE + row) * W) + tx * TILE) * 4, TILE * 4)
    end
    return b
end

local undoStack = {}   -- each entry: { [tileKey] = buffer }

local function beginStroke() undoStack[#undoStack + 1] = {} end

local function touchTile(tx, ty)
    local top = undoStack[#undoStack]
    local key = ty * TX + tx
    if not top[key] then top[key] = snapshotTile(tx, ty) end
end

local function undo()
    local top = table.remove(undoStack)
    if not top then return end
    for key, b in top do
        local tx, ty = key % TX, key // TX
        for row = 0, TILE - 1 do
            buffer.copy(canvas, (((ty * TILE + row) * W) + tx * TILE) * 4, b, row * TILE * 4, TILE * 4)
        end
        markTileDirty(tx, ty)
    end
end
```

A typical stroke touches 4–20 tiles → **64–320 KB per undo level**. Twenty levels ≈ 1.3–6.4 MB. That is real memory against a constrained budget; cap undo depth and consider snapshotting at 8-bit palette indices instead of RGBA (4× saving) if your canvas is palettised.

### 2.4 Networking: send strokes, not pixels

A 1024² RGBA canvas is **4 MB**. A stroke is a handful of numbers. The ratio decides the architecture.

**Wire format.** Pack into a `buffer` and send that; Roblox serializes `buffer` efficiently and it avoids per-field table overhead.

```lua
-- 12 bytes per stroke segment batch header + 4 bytes per point.
-- Coordinates quantised to 12 bits each (0..4095) -> fits 1024 canvas with 4x sub-pixel precision.
local function encodeStroke(points, color24, brushId, size8): buffer
    local n = #points // 2
    local b = buffer.create(8 + n * 3)
    buffer.writeu32(b, 0, color24)            -- 0xRRGGBB (top byte free for flags)
    buffer.writeu8(b, 4, brushId)
    buffer.writeu8(b, 5, size8)
    buffer.writeu16(b, 6, n)
    local o = 8
    for i = 1, n do
        local x = math.clamp(points[i*2-1], 0, 1023)
        local y = math.clamp(points[i*2],   0, 1023)
        -- 10 bits x + 10 bits y = 20 bits -> 3 bytes (4 bits spare)
        local packed = bit32.bor(bit32.lshift(math.floor(x), 10), math.floor(y))
        buffer.writeu8(b, o,     bit32.band(bit32.rshift(packed, 16), 0xFF))
        buffer.writeu8(b, o + 1, bit32.band(bit32.rshift(packed, 8),  0xFF))
        buffer.writeu8(b, o + 2, bit32.band(packed, 0xFF))
        o += 3
    end
    return b
end
```

**~3 bytes per point.** A 200-point stroke is **~600 bytes**. Against 4 MB of pixels that is a **~7000× reduction** [UNVERIFIED — arithmetic].

**Further compression, in order of value:**
1. **Delta-encode points.** Consecutive points are close; store `dx,dy` as signed bytes with an escape for large jumps. Typical strokes drop to **~2 bytes/point**.
2. **Douglas–Peucker simplification** before sending. Drop points that lie within ε of the line between neighbours. At ε=1 px this typically removes 50–80% of samples from a smoothed stroke with no visible change [UNVERIFIED].
3. **Batch per tick.** One remote fire per `Heartbeat` carrying all of that tick's points, not one per input event.

**Architecture.** Server holds the authoritative **stroke log**, not the pixels. Late joiners receive the log (or a compacted keyframe + log tail) and replay it locally. Replay must be **deterministic**: same brush code, same spacing, same rounding on every client. Any floating-point path that differs between platforms will drift — quantise brush positions to integers before stamping.

**Server-side canvas?** Only if you need server-authoritative pixel reads (e.g. anti-griefing scans, or persisting a PNG). [DOC] the server has *"unlimited memory"* for editables, so a server canvas is feasible — but it costs you a full parallel simulation. Prefer storing the stroke log in `DataStore` (compact, replayable) over storing pixels.

**Moderation.** A shared drawing canvas is a UGC surface. Strokes are not text-filterable. Standard practice is per-player stroke attribution (so a canvas can be selectively rolled back) plus rate limiting. Treat this as a design requirement, not an afterthought.

---

## 3. Minimaps and map rendering

**Genres:** open world, MOBA, extraction shooters, dungeon crawlers, tycoons, racing, horror.

### 3.1 Top-down map generation

Two sources of truth, with very different costs.

**(a) Bake once from geometry.** At load, iterate parts and rasterize their footprints. One-time cost, zero per-frame cost.

```lua
local function worldToMap(wx, wz, originX, originZ, scale, mapW, mapH)
    return math.floor((wx - originX) * scale), math.floor((wz - originZ) * scale)
end

local function bakeParts(parts, buf, W, H, originX, originZ, scale)
    for _, p in parts do
        local cf, sz = p.CFrame, p.Size
        -- Axis-aligned approximation: fine for most level geometry.
        local x0, y0 = worldToMap(cf.X - sz.X/2, cf.Z - sz.Z/2, originX, originZ, scale, W, H)
        local x1, y1 = worldToMap(cf.X + sz.X/2, cf.Z + sz.Z/2, originX, originZ, scale, W, H)
        local c = p.Color
        local rgba = bit32.bor(bit32.lshift(255,24),
            bit32.lshift(math.floor(c.B*255),16),
            bit32.lshift(math.floor(c.G*255),8),
            math.floor(c.R*255))
        for y = math.max(0,y0), math.min(H-1,y1) do
            local base = (y * W) * 4
            for x = math.max(0,x0), math.min(W-1,x1) do
                buffer.writeu32(buf, base + x*4, rgba)
            end
        end
    end
end
```

Sort parts by `Position.Y` ascending before baking so taller geometry overwrites lower — a free painter's algorithm.

**(b) Raycast-sample each frame.** [COMM] This is what the "Realtime minimap using EditableImage & Parallel Luau" project does: cast a grid of downward rays around the player, read the hit part's color/material, write to the image — and multithread the raycasting with Parallel Luau. This gives you a live map that reflects destruction and moving geometry, at the cost of N raycasts/frame.

**Budget** [UNVERIFIED]: a 64×64 sample grid is **4096 raycasts/frame**. That is heavy for one thread and the reason the cited project reached for actors. Mitigate by (i) sampling on a coarse grid and bilinearly upscaling, (ii) re-sampling only 1/4 of the grid per frame in a rotating pattern (temporal amortisation), (iii) only re-sampling near the player and keeping a baked map for the rest.

### 3.2 Fog of war / exploration mask

The correct structure is **two images**: a static baked map, and an 8-bit exploration mask composited over it — or, cheaper, an `ImageLabel` of the map with a second `ImageLabel` of the mask on top using the alpha channel.

```lua
local MW, MH = 256, 256
local fog = buffer.create(MW * MH * 4)
buffer.fill(fog, 0, 0)
for i = 0, MW*MH - 1 do buffer.writeu8(fog, i*4 + 3, 255) end   -- opaque black everywhere

-- Reveal a disc. Permanent exploration: alpha only ever decreases.
local function reveal(cx, cy, radius, softness)
    local r2 = radius * radius
    local x0, x1 = math.max(0, cx-radius), math.min(MW-1, cx+radius)
    local y0, y1 = math.max(0, cy-radius), math.min(MH-1, cy+radius)
    for y = y0, y1 do
        local dy = y - cy
        for x = x0, x1 do
            local dx = x - cx
            local d2 = dx*dx + dy*dy
            if d2 <= r2 then
                local t = math.sqrt(d2) / radius
                local a = math.floor(math.clamp((t - (1 - softness)) / softness, 0, 1) * 255)
                local i = (y * MW + x) * 4 + 3
                if a < buffer.readu8(fog, i) then buffer.writeu8(fog, i, a) end   -- min()
            end
        end
    end
    markDirty(x0, y0, x1, y1)
end
```

**The `min()` is what makes exploration permanent** and makes the operation idempotent — you can call `reveal` every frame from the player's position with no accumulation artifacts and no need to track where you've been.

**Cost**: a radius-20 reveal is ~1250 texels/frame. Negligible. At 256² the whole fog buffer is 256 KB.

**Two-layer fog (explored vs. currently visible)**, the MOBA standard: keep `explored` (8-bit, permanent, `min()`) and `visible` (8-bit, cleared and rebuilt each frame from unit vision). Render `explored` at 50% brightness and `visible` at 100%. Rebuilding `visible` each frame means clearing — use `buffer.fill(visible, 0, 0)`, which is a single memset, not a loop.

### 3.3 Radar blips and the incremental-update discipline

Blips move every frame, so you cannot bake them. But you must not redraw the map to move them.

**Three-layer composition, cheapest first:**
1. **Map layer** — `EditableImage`, written once.
2. **Fog layer** — `EditableImage`, dirty-rect updates.
3. **Blips** — **not an image at all.** Use real `ImageLabel`/`Frame` instances positioned with `UDim2`. Ten to fifty blips as UI instances cost far less than rewriting an image region per blip per frame, and you get free rotation, tweening and `ZIndex`.

**This is the key architectural insight for minimaps: use EditableImage for what is genuinely per-pixel and irregular (terrain, fog), and use ordinary UI instances for what is sparse and moving (blips, icons, labels).** Developers routinely over-apply EditableImage here and pay for it.

If blips must be in the image (e.g. hundreds of them, or you need them baked into a screenshot), restore-then-draw:

```lua
-- Keep a copy of the clean background under each blip; restore before moving.
local restores = {}   -- [blipId] = {x, y, w, h, buffer}

local function clearBlips()
    for _, r in restores do
        for row = 0, r.h - 1 do
            buffer.copy(canvas, ((r.y + row) * W + r.x) * 4, r.buf, row * r.w * 4, r.w * 4)
        end
    end
    table.clear(restores)
end
```

### 3.4 Dungeon maps that reveal as you walk

Grid-based dungeons are the easy case: the map is a **tile index array**, and the image is a *render* of it. Re-render only tiles whose visibility changed.

```lua
local CELL = 8   -- pixels per dungeon cell
local seen = {}  -- [cellKey] = true

local function revealCell(cx, cy)
    local key = cy * dungeonW + cx
    if seen[key] then return end
    seen[key] = true
    local tile = dungeonTiles[key]
    blitTile(canvas, W, cx * CELL, cy * CELL, tileAtlas, tile, CELL)
    markDirty(cx * CELL, cy * CELL, cx * CELL + CELL - 1, cy * CELL + CELL - 1)
end
```

Cost per newly revealed cell: `CELL²` = 64 texel copies. A player revealing 5 cells/second costs 320 texels/second. **This is essentially free** and is why dungeon-crawler maps should always be tile-driven rather than raycast-sampled.

### 3.5 Heatmaps of player activity

Accumulate into a **float-ish 16-bit buffer**, then colour-map on display.

```lua
local heat = buffer.create(MW * MH * 2)   -- u16 per cell

local function addHeat(cx, cy, radius, amount)
    for y = math.max(0,cy-radius), math.min(MH-1,cy+radius) do
        for x = math.max(0,cx-radius), math.min(MW-1,cx+radius) do
            local dx, dy = x-cx, y-cy
            local d2 = dx*dx + dy*dy
            if d2 <= radius*radius then
                local i = (y * MW + x) * 2
                local v = buffer.readu16(heat, i) + math.floor(amount * (1 - d2/(radius*radius)))
                buffer.writeu16(heat, i, math.min(v, 65535))
            end
        end
    end
end

-- Colour-map on a slow cadence (heatmaps do not need 60 Hz).
local GRADIENT = { {0,0,255}, {0,255,255}, {0,255,0}, {255,255,0}, {255,0,0} }
local function renderHeat(maxV)
    for i1 = 0, MW*MH - 1 do
        local t = buffer.readu16(heat, i1*2) / maxV
        t = math.clamp(t, 0, 1) * (#GRADIENT - 1)
        local lo = math.floor(t); local hi = math.min(lo + 1, #GRADIENT - 1); local f = t - lo
        local a, b = GRADIENT[lo+1], GRADIENT[hi+1]
        buffer.writeu32(canvas, i1*4, bit32.bor(
            bit32.lshift(200, 24),
            bit32.lshift(math.floor(a[3] + (b[3]-a[3])*f), 16),
            bit32.lshift(math.floor(a[2] + (b[2]-a[2])*f), 8),
            math.floor(a[1] + (b[1]-a[1])*f)))
    end
end
```

Render the heatmap **once per second or on demand**, never per frame — a 256² colour-map pass is 65 K iterations, fine occasionally, wasteful at 60 Hz.

---

## 4. Procedural texture synthesis at runtime

**Genres:** survival/crafting, sci-fi, roguelikes with generated items, vehicle customisation, military shooters (camo), anything with "every run looks different."

### 4.1 Value/fractal noise

`math.noise(x, y, z)` is Roblox's built-in Perlin. Critically, **it returns ~0 at integer coordinates** — you must feed it fractional inputs or your texture will be flat grey.

```lua
-- Fractal Brownian Motion: octaves of noise at doubling frequency, halving amplitude.
local function fbm(x, y, seed, octaves, lacunarity, gain)
    local sum, amp, freq, norm = 0, 1, 1, 0
    for _ = 1, octaves do
        sum  += math.noise(x * freq, y * freq, seed) * amp
        norm += amp
        amp  *= gain
        freq *= lacunarity
    end
    return sum / norm            -- roughly -0.5..0.5
end

local function generateNoiseTexture(buf, W, H, scale, seed, octaves)
    for y = 0, H - 1 do
        local ny = y / W * scale       -- divide by W (not H) to keep aspect square
        local row = y * W * 4
        for x = 0, W - 1 do
            local v = fbm(x / W * scale, ny, seed, octaves, 2, 0.5)
            local c = math.clamp(math.floor((v + 0.5) * 255), 0, 255)
            buffer.writeu32(buf, row + x*4,
                bit32.bor(bit32.lshift(255,24), bit32.lshift(c,16), bit32.lshift(c,8), c))
        end
    end
end
```

**Cost** [UNVERIFIED]: 4 octaves × 1 `math.noise` each = 4 noise calls/pixel. At 256² that is **262,144 noise calls**. `math.noise` is a C function but not free. **Generate procedural textures at load or over multiple frames — never per frame.** Use the rolling-slice pattern from §1.4.

### 4.2 Tileable noise

The standard trick: sample noise on a **torus** by mapping the 2D texture coordinates onto two circles in 4D. Roblox's `math.noise` is 3D, so you get a tileable-in-one-axis approximation cheaply, or blend four offset copies for a true 2D tile:

```lua
-- Blend-based tiling: 4 samples, seamless but slightly lower contrast.
local function tileableNoise(x, y, W, H, scale, seed)
    local fx, fy = x / W, y / H
    local a = fbm(fx * scale,             fy * scale,             seed, 4, 2, 0.5)
    local b = fbm((fx - 1) * scale,       fy * scale,             seed, 4, 2, 0.5)
    local c = fbm(fx * scale,             (fy - 1) * scale,       seed, 4, 2, 0.5)
    local d = fbm((fx - 1) * scale,       (fy - 1) * scale,       seed, 4, 2, 0.5)
    local wx, wy = fx, fy
    return a * (1-wx) * (1-wy) + b * wx * (1-wy) + c * (1-wx) * wy + d * wx * wy
end
```

4× the noise cost. Worth it only when the texture genuinely tiles across large surfaces.

### 4.3 Camo generator

Camo is **threshold bands of noise**, painted in a palette, with a blob-smoothing pass.

```lua
local PALETTE = {
    {60, 70, 45}, {95, 105, 70}, {45, 50, 38}, {130, 125, 95},
}

local function generateCamo(buf, W, H, seed, scale)
    local n = #PALETTE
    for y = 0, H - 1 do
        local row = y * W * 4
        for x = 0, W - 1 do
            -- Two noise fields: one picks the band, one warps it for organic edges.
            local warp = fbm(x/W * scale * 3, y/H * scale * 3, seed + 99, 2, 2, 0.5) * 0.15
            local v = fbm(x/W * scale + warp, y/H * scale + warp, seed, 3, 2, 0.5) + 0.5
            local band = math.clamp(math.floor(v * n) + 1, 1, n)
            local c = PALETTE[band]
            buffer.writeu32(buf, row + x*4, bit32.bor(
                bit32.lshift(255,24), bit32.lshift(c[3],16), bit32.lshift(c[2],8), c[1]))
        end
    end
end
```

**Domain warping** (`warp` above) is what separates convincing camo from obvious noise bands. It's one extra fbm call per pixel and is the highest-value addition here.

For **digital/pixel camo**, quantise coordinates before sampling: `fbm(math.floor(x/8)*8/W * scale, ...)`.

### 4.4 Weathering and wear layers

Wear is a **mask driven by geometry-ish heuristics**, composited between a clean and a worn texture.

```lua
-- Edge wear: more wear where a supplied curvature/AO map is bright; plus noise for irregularity.
local function applyWear(clean, worn, out, aoMask, W, H, amount, seed)
    for i1 = 0, W*H - 1 do
        local x, y = i1 % W, i1 // W
        local ao = buffer.readu8(aoMask, i1) / 255
        local n = fbm(x/W * 12, y/H * 12, seed, 3, 2, 0.5) + 0.5
        local w = math.clamp((ao * n * 2 - (1 - amount)) * 3, 0, 1)
        local i = i1 * 4
        for ch = 0, 2 do
            local a = buffer.readu8(clean, i + ch)
            local b = buffer.readu8(worn,  i + ch)
            buffer.writeu8(out, i + ch, math.floor(a + (b - a) * w))
        end
        buffer.writeu8(out, i + 3, 255)
    end
end
```

Cheaper alternative that avoids a second full texture: use `DrawImage` with `Enum.ImageCombineType.Multiply` to darken, and `Subtract` to erode — both operate without you reading the destination at all.

### 4.5 Normal map from a height image (Sobel)

This is the one piece of maths worth writing out exactly. Sobel gives you the height gradient; the normal is the gradient turned into a vector and renormalised.

Sobel kernels:

```
Gx = [ -1  0  +1 ]      Gy = [ -1 -2 -1 ]
     [ -2  0  +2 ]           [  0  0  0 ]
     [ -1  0  +1 ]           [ +1 +2 +1 ]
```

```lua
-- height: buffer, 1 byte per pixel (grayscale). out: RGBA normal map buffer.
-- strength: higher = more pronounced bumps (typical 1..8).
local function heightToNormal(height: buffer, out: buffer, W: number, H: number, strength: number)
    local function h(x, y)
        -- Clamp at borders (avoids seams better than wrapping for non-tiling textures).
        x = math.clamp(x, 0, W - 1); y = math.clamp(y, 0, H - 1)
        return buffer.readu8(height, y * W + x) / 255
    end

    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local tl, t, tr = h(x-1, y-1), h(x, y-1), h(x+1, y-1)
            local l,  _, r  = h(x-1, y  ), 0,         h(x+1, y  )
            local bl, b, br = h(x-1, y+1), h(x, y+1), h(x+1, y+1)

            local gx = (tr + 2*r + br) - (tl + 2*l + bl)
            local gy = (bl + 2*b + br) - (tl + 2*t + tr)

            -- Normal in tangent space. Z is the "flatness" term.
            local nx, ny, nz = -gx * strength, -gy * strength, 1.0
            local inv = 1 / math.sqrt(nx*nx + ny*ny + nz*nz)
            nx, ny, nz = nx * inv, ny * inv, nz * inv

            -- Encode [-1,1] -> [0,255].
            local i = (y * W + x) * 4
            buffer.writeu32(out, i, bit32.bor(
                bit32.lshift(255, 24),
                bit32.lshift(math.floor((nz * 0.5 + 0.5) * 255), 16),
                bit32.lshift(math.floor((ny * 0.5 + 0.5) * 255), 8),
                math.floor((nx * 0.5 + 0.5) * 255)))
        end
    end
end
```

**Sign conventions matter.** Roblox uses OpenGL-style tangent-space normal maps (green = +Y up). If your bumps look inverted, flip `ny`. Test with a hemisphere before committing.

**Cost** [UNVERIFIED]: 8 height reads + ~15 arithmetic ops + 1 write per pixel. At 256² ≈ 65 K pixels ≈ **~1.5 M operations**. This is a load-time or background-task operation, not a per-frame one.

**Feeding it to the renderer** [DOC]:

```lua
local sa = AssetService:CreateSurfaceAppearanceAsync({
    ColorMap     = Content.fromObject(colorImg),
    NormalMap    = Content.fromObject(normalImg),
    RoughnessMap = Content.fromObject(roughImg),
    MetalnessMap = Content.fromObject(metalImg),
})
sa.Parent = meshPart
```

> **[DOC] Hard constraint:** *"the `EditableImage` assigned to each map cannot be reassigned or swapped after the `SurfaceAppearance` is created."* You may keep drawing **into** those images, but you cannot point the SurfaceAppearance at a different image later. Design your material slots up front.

---

## 5. Character and avatar customization

**Genres:** RPGs, fashion/dress-up, battle royales with skins, team shooters, social hangouts.

### 5.1 Composing a skin from layered parts

The pattern is a **layer stack**, composited into one `EditableImage` per character. Because `DrawImage` composites image→image on the engine side, you often need **zero Luau pixel loops**.

```lua
local function composeSkin(layers, W, H): EditableImage
    local out = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
    if not out then return nil end
    for _, layer in layers do
        -- layer = { image = EditableImage, blend = Enum.ImageCombineType }
        out:DrawImage(Vector2.zero, layer.image, layer.blend or Enum.ImageCombineType.BlendSourceOver)
    end
    return out
end
```

**This is dramatically faster than doing it in Luau** — `DrawImage` is a native composite. Reach for `WritePixelsBuffer` only when you need per-pixel logic the enum blends cannot express.

### 5.2 Recolouring by mask

The standard technique: ship **one grayscale base texture** plus a **region mask** where each region is a flat, exact colour key. Recolour by matching the key.

[CODE] This is exactly what Roblox's own `TextureUtils.lua` does (`Roblox/avatar`): `computePbrRegionMask` builds a 1-byte-per-pixel mask by comparing region-map pixels against a target colour, downsampling larger region maps to the PBR texture dimensions using stride arithmetic; `PerformRegionColor` then *"matches pixels against a region's target color, then overwrites RGB while preserving alpha semantics."*

```lua
-- regionMap: RGBA buffer with flat key colours. base: grayscale RGBA. out: RGBA.
local function recolorRegion(regionMap, base, out, W, H, keyR, keyG, keyB, tint: Color3)
    local tr, tg, tb = tint.R, tint.G, tint.B
    for i1 = 0, W*H - 1 do
        local i = i1 * 4
        if buffer.readu8(regionMap, i)     == keyR
        and buffer.readu8(regionMap, i + 1) == keyG
        and buffer.readu8(regionMap, i + 2) == keyB then
            -- Multiply the grayscale luminance by the tint: preserves shading detail.
            local lum = buffer.readu8(base, i) / 255
            buffer.writeu32(out, i, bit32.bor(
                bit32.lshift(buffer.readu8(base, i + 3), 24),
                bit32.lshift(math.floor(lum * tb * 255), 16),
                bit32.lshift(math.floor(lum * tg * 255), 8),
                math.floor(lum * tr * 255)))
        end
    end
end
```

**Why multiply rather than replace:** the grayscale base carries the fabric weave, stitching and ambient occlusion. Multiplying keeps all of it. Replacing gives you flat plastic.

**Precompute the mask once.** Comparing three channels per pixel per recolour is wasteful when the region map never changes. Build an index buffer at load (`1 byte per pixel = region id`), then recolouring is one read + one compare:

```lua
local regionId = buffer.create(W * H)    -- built once at load
-- ...then per recolour:
for i1 = 0, W*H - 1 do
    if buffer.readu8(regionId, i1) == wantedRegion then ... end
end
```

### 5.3 Decals and logos on clothing

For a flat UV region (a shirt front), `DrawImageTransformed` does it with no maths:

```lua
skin:DrawImageTransformed(
    Vector2.new(256, 180),          -- position on the texture
    Vector2.new(0.5, 0.5),          -- scale
    math.rad(4),                    -- rotation
    logoImage,
    {
        CombineType  = Enum.ImageCombineType.BlendSourceOver,
        SamplingMode = Enum.ResamplerMode.Default,   -- bilinear; Pixelated for nearest-neighbour
        PivotPoint   = Vector2.new(logoImage.Size.X/2, logoImage.Size.Y/2),
    }
)
```

For a logo that must **wrap around a curved surface**, use `DrawImageProjected` (§1.1 Route C) instead — that is its purpose.

### 5.4 Per-player unique textures without uploading assets

This is EditableImage's strongest structural advantage: **a generated texture needs no moderation round-trip and no asset ID.**

```lua
-- Deterministic per-player livery from their UserId. Same input -> same output on every client.
local function generateLivery(userId: number, W: number, H: number): EditableImage
    local rng  = Random.new(userId)
    local hue  = rng:NextNumber()
    local img  = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
    if not img then return nil end

    local buf = buffer.create(W * H * 4)
    local base = Color3.fromHSV(hue, 0.6, 0.85)
    generateCamo(buf, W, H, userId % 100000, 6)   -- from §4.3, palette derived from `base`
    img:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), buf)
    return img
end
```

**Because it is a pure function of `UserId`, every client generates the same texture independently — zero network cost.** That is the pattern: *replicate the seed, not the pixels.*

**Budget warning.** This is where the memory budget bites hardest. One 512² texture per player is 1 MB; a 30-player server is 30 MB and [COMM] the client budget is reported around 32 MB. **Mitigations, in order:**
1. Generate only for characters within render distance; `Destroy()` when they leave. [DOC] *"Destroys the contents of the image, immediately reclaiming used memory."*
2. Drop to 256² (256 KB) for distant/non-focal characters.
3. Share one atlas: pack several players' liveries into a single 1024² image and give each a UV sub-rect. This also **sidesteps the one-update-per-frame limit**, because all of them live in one image.

Option 3 is the professional answer and is worth designing for from the start.

---

## 6. Image processing and filters

All of these are **buffer→buffer** transforms. The shared skeleton:

```lua
local function forEachPixel(src, dst, W, H, fn)
    for y = 0, H - 1 do
        local row = y * W * 4
        for x = 0, W - 1 do
            local i = row + x * 4
            local r = buffer.readu8(src, i)
            local g = buffer.readu8(src, i + 1)
            local b = buffer.readu8(src, i + 2)
            local a = buffer.readu8(src, i + 3)
            local nr, ng, nb, na = fn(r, g, b, a, x, y)
            buffer.writeu32(dst, i, bit32.bor(
                bit32.lshift(na, 24), bit32.lshift(nb, 16), bit32.lshift(ng, 8), nr))
        end
    end
end
```

**Always write to a separate destination buffer for neighbourhood filters.** In-place convolution reads already-modified neighbours and produces smearing.

### 6.1 Box blur — separable, O(1) per pixel via running sum

A naive r-radius box blur is O(r²) per pixel. Separating into horizontal + vertical passes gives O(r). A **running sum** gives O(1) — independent of radius.

```lua
-- Horizontal pass with a sliding window. Radius-independent cost.
local function boxBlurH(src, dst, W, H, r)
    local n = r * 2 + 1
    for y = 0, H - 1 do
        local row = y * W * 4
        local sr, sg, sb, sa = 0, 0, 0, 0
        -- Prime the window: clamp-extend the left edge.
        for k = -r, r do
            local x = math.clamp(k, 0, W - 1)
            local i = row + x * 4
            sr += buffer.readu8(src, i);     sg += buffer.readu8(src, i + 1)
            sb += buffer.readu8(src, i + 2); sa += buffer.readu8(src, i + 3)
        end
        for x = 0, W - 1 do
            local o = row + x * 4
            buffer.writeu32(dst, o, bit32.bor(
                bit32.lshift(sa // n, 24), bit32.lshift(sb // n, 16),
                bit32.lshift(sg // n, 8),  sr // n))
            -- Slide: add the incoming pixel, remove the outgoing one.
            local addX = math.clamp(x + r + 1, 0, W - 1)
            local subX = math.clamp(x - r,     0, W - 1)
            local ai, si = row + addX * 4, row + subX * 4
            sr += buffer.readu8(src, ai)     - buffer.readu8(src, si)
            sg += buffer.readu8(src, ai + 1) - buffer.readu8(src, si + 1)
            sb += buffer.readu8(src, ai + 2) - buffer.readu8(src, si + 2)
            sa += buffer.readu8(src, ai + 3) - buffer.readu8(src, si + 3)
        end
    end
end
-- boxBlurV is the same with the row/column roles swapped (stride W*4 instead of 4).
```

**Three box blurs ≈ one Gaussian.** This is the standard approximation and is what you should ship: `boxBlurH/V` three times with radii chosen per Kovesi's formula is visually indistinguishable from a true Gaussian at a fraction of the cost.

**Cost** [UNVERIFIED]: 2 passes × W×H × ~12 buffer ops = **~25 M ops at 1024²**, ~1.6 M at 256². **Blur at low resolution.** [COMM] the standard advice from the Roblox blur discussions is exactly this: downscale to ½×½, blur, upscale. That is a **4× saving** and is essentially free visually, because blur destroys high frequencies anyway.

### 6.2 Integral image (summed-area table)

If you need **many different box sizes** over the same image (e.g. variable-radius bokeh, adaptive thresholding), build a summed-area table once and get any rectangle's sum in 4 lookups.

```lua
-- SAT for one channel. Use f64 via a table or u32 buffer (W*H*255 < 2^32 for W*H < 16.8M -> safe at 1024^2).
local function buildSAT(src, W, H, channel): buffer
    local sat = buffer.create(W * H * 4)     -- u32 per cell
    for y = 0, H - 1 do
        local rowSum = 0
        for x = 0, W - 1 do
            rowSum += buffer.readu8(src, (y * W + x) * 4 + channel)
            local above = y > 0 and buffer.readu32(sat, ((y-1) * W + x) * 4) or 0
            buffer.writeu32(sat, (y * W + x) * 4, rowSum + above)
        end
    end
    return sat
end

-- Sum over inclusive rect [x0,y0]..[x1,y1] in O(1).
local function satSum(sat, W, x0, y0, x1, y1)
    local function at(x, y)
        if x < 0 or y < 0 then return 0 end
        return buffer.readu32(sat, (y * W + x) * 4)
    end
    return at(x1, y1) - at(x0 - 1, y1) - at(x1, y0 - 1) + at(x0 - 1, y0 - 1)
end
```

**Build cost is one full pass; query cost is 4 reads.** Worth it only when you will make many queries — for a single uniform blur, the running-sum box blur above is strictly better (no 4 MB extra buffer per channel).

### 6.3 Sharpen, edge detect, emboss (3×3 convolution)

```lua
local KERNELS = {
    sharpen  = { 0,-1, 0, -1, 5,-1,  0,-1, 0},
    edge     = {-1,-1,-1, -1, 8,-1, -1,-1,-1},
    emboss   = {-2,-1, 0, -1, 1, 1,  0, 1, 2},
    blur3    = { 1, 1, 1,  1, 1, 1,  1, 1, 1},
}

local function convolve3x3(src, dst, W, H, k, divisor, offset)
    divisor = divisor or 1
    offset  = offset  or 0
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local ar, ag, ab = 0, 0, 0
            local ki = 1
            for dy = -1, 1 do
                local sy = math.clamp(y + dy, 0, H - 1)
                for dx = -1, 1 do
                    local sx = math.clamp(x + dx, 0, W - 1)
                    local i = (sy * W + sx) * 4
                    local w = k[ki]; ki += 1
                    if w ~= 0 then
                        ar += buffer.readu8(src, i)     * w
                        ag += buffer.readu8(src, i + 1) * w
                        ab += buffer.readu8(src, i + 2) * w
                    end
                end
            end
            local o = (y * W + x) * 4
            buffer.writeu32(dst, o, bit32.bor(
                bit32.lshift(buffer.readu8(src, o + 3), 24),
                bit32.lshift(math.clamp(ab // divisor + offset, 0, 255), 16),
                bit32.lshift(math.clamp(ag // divisor + offset, 0, 255), 8),
                math.clamp(ar // divisor + offset, 0, 255)))
        end
    end
end
```

**Cost** [UNVERIFIED]: 9 taps × 3 channels = 27 reads/pixel worst case. At 256² ≈ **1.8 M reads**. The `if w ~= 0` guard matters a lot for sparse kernels like `sharpen` (4 zeros of 9).

[COMM] A community module "Image processing through a Kernel (Convolution)" exists on the devforum and reports testing kernel sizes above 3×3; the general community verdict on blur-class effects is that they are *"quite laggy"* at full resolution — consistent with the arithmetic above.

### 6.4 Threshold, posterize, grayscale

Trivially cheap, ~5 ops/pixel. These are the filters you *can* afford per frame at moderate resolution.

```lua
local function luminance(r, g, b) return 0.2126*r + 0.7152*g + 0.0722*b end

local function threshold(r, g, b, a, _, _, t)
    local v = luminance(r, g, b) >= t and 255 or 0
    return v, v, v, a
end

local function posterize(r, g, b, a, levels)
    local step = 255 / (levels - 1)
    local function q(c) return math.floor(math.floor(c / step + 0.5) * step) end
    return q(r), q(g), q(b), a
end
```

### 6.5 Palette quantization + Floyd–Steinberg dithering

The retro look, and also a **4× memory win** if you store the canvas as palette indices.

```lua
local function nearestPaletteIndex(palette, r, g, b)
    local best, bestD = 1, math.huge
    for i, c in palette do
        local dr, dg, db = r - c[1], g - c[2], b - c[3]
        local d = dr*dr + dg*dg + db*db
        if d < bestD then bestD, best = d, i end
    end
    return best
end

-- Floyd-Steinberg: push quantization error to not-yet-visited neighbours.
--        *   7/16
--  3/16 5/16 1/16
local function ditherFS(src, dst, W, H, palette)
    -- Work in a float error buffer to avoid clipping artifacts.
    local err = table.create(W * H * 3, 0)
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local i  = (y * W + x) * 4
            local ei = (y * W + x) * 3
            local r = math.clamp(buffer.readu8(src, i)     + err[ei + 1], 0, 255)
            local g = math.clamp(buffer.readu8(src, i + 1) + err[ei + 2], 0, 255)
            local b = math.clamp(buffer.readu8(src, i + 2) + err[ei + 3], 0, 255)

            local pi = nearestPaletteIndex(palette, r, g, b)
            local c  = palette[pi]
            local er, eg, eb = r - c[1], g - c[2], b - c[3]

            buffer.writeu32(dst, i, bit32.bor(
                bit32.lshift(buffer.readu8(src, i + 3), 24),
                bit32.lshift(c[3], 16), bit32.lshift(c[2], 8), c[1]))

            local function spread(nx, ny, f)
                if nx < 0 or nx >= W or ny >= H then return end
                local ni = (ny * W + nx) * 3
                err[ni + 1] += er * f; err[ni + 2] += eg * f; err[ni + 3] += eb * f
            end
            spread(x + 1, y,     7/16)
            spread(x - 1, y + 1, 3/16)
            spread(x,     y + 1, 5/16)
            spread(x + 1, y + 1, 1/16)
        end
    end
end
```

**Cost** [UNVERIFIED]: dominated by `nearestPaletteIndex` — **O(palette size) per pixel**. A 16-colour palette at 256² is 16 × 65 K = **1 M distance computations**. For anything real-time, replace the linear search with a **precomputed 32³ lookup cube** (32 KB, indexed by `r>>3, g>>3, b>>3`), turning it into one buffer read:

```lua
local lut = buffer.create(32 * 32 * 32)   -- build once
local function lutIndex(r, g, b)
    return buffer.readu8(lut, ((r // 8) * 32 * 32) + ((g // 8) * 32) + (b // 8))
end
```

**Ordered (Bayer) dithering** is the cheaper alternative — no error propagation, so it parallelises and has no serial dependency:

```lua
local BAYER4 = {0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5}
local function bayerThreshold(x, y) return (BAYER4[(y % 4) * 4 + (x % 4) + 1] / 16 - 0.5) * 255 end
```

**Bayer dithering is parallel-safe; Floyd–Steinberg is not** (each pixel depends on its predecessors). If you plan to move quantization into Parallel Luau, you must use ordered dithering.

### 6.6 LUT colour grading

The professional way to do colour grading: bake the whole transform into a 3D lookup table, stored as a 2D strip image.

```lua
-- A 16x16x16 LUT laid out as a 256x16 strip: 16 tiles of 16x16, tile index = blue slice.
local function applyLUT(src, dst, lutBuf, W, H, lutSize)
    local tiles = lutSize                      -- 16
    local lutW  = lutSize * tiles              -- 256
    for i1 = 0, W*H - 1 do
        local i = i1 * 4
        local r = buffer.readu8(src, i)
        local g = buffer.readu8(src, i + 1)
        local b = buffer.readu8(src, i + 2)

        local bi = math.floor(b / 255 * (lutSize - 1) + 0.5)      -- blue slice (nearest)
        local lx = bi * lutSize + math.floor(r / 255 * (lutSize - 1) + 0.5)
        local ly = math.floor(g / 255 * (lutSize - 1) + 0.5)
        local li = (ly * lutW + lx) * 4

        buffer.writeu32(dst, i, bit32.bor(
            bit32.lshift(buffer.readu8(src, i + 3), 24),
            bit32.lshift(buffer.readu8(lutBuf, li + 2), 16),
            bit32.lshift(buffer.readu8(lutBuf, li + 1), 8),
            buffer.readu8(lutBuf, li)))
    end
end
```

**~8 ops/pixel regardless of grade complexity.** This is the single best-value filter in the chapter: arbitrarily complex colour science at constant cost. Nearest-slice sampling shows banding on gradients; trilinear interpolation between slices fixes it at ~3× the cost.

**Authoring**: generate the neutral LUT strip, grade it in any external tool, upload as an asset, load with `CreateEditableImageAsync`.

### 6.7 Chromatic aberration and pixelation

```lua
-- Chromatic aberration: sample R and B channels at radially offset positions.
local function chromaticAberration(src, dst, W, H, strength)
    local cx, cy = W / 2, H / 2
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local dx, dy = (x - cx) / cx, (y - cy) / cy
            local ox, oy = dx * strength, dy * strength
            local function sample(sx, sy, ch)
                sx = math.clamp(math.floor(sx), 0, W - 1)
                sy = math.clamp(math.floor(sy), 0, H - 1)
                return buffer.readu8(src, (sy * W + sx) * 4 + ch)
            end
            local i = (y * W + x) * 4
            buffer.writeu32(dst, i, bit32.bor(
                bit32.lshift(255, 24),
                bit32.lshift(sample(x - ox, y - oy, 2), 16),   -- B pulled in
                bit32.lshift(buffer.readu8(src, i + 1), 8),    -- G unshifted
                sample(x + ox, y + oy, 0)))                    -- R pushed out
        end
    end
end
```

**Pixelation** is best done for free: set `ImageLabel.ResampleMode = Enum.ResamplerMode.Pixelated` and render into a *small* EditableImage. [CODE] `FastCanvas` does exactly this. **Do not simulate pixelation by block-averaging a large image — just use a small image.** A 128×128 canvas shown at 1024 px is 64× cheaper than a 1024² canvas.

---

## 7. Software rendering inside an image — the real ceiling

This is where the performance envelope gets established. The honest summary: **the community has built impressive things, and they all run at roughly 100×100 to 200×200.**

### 7.1 What has actually been achieved

| Project | What it is | Resolution | Reported performance | Source |
|---|---|---|---|---|
| **RetroRaster** (Ethanthegrand) | Multithreaded textured raytracer that pixelates the live Roblox scene: skyboxes, textures, reflections, transparency, shading, fog, PointLight/SpotLight, motion blur | **100×100** | [COMM] *"18 FPS to well over 150 FPS"*; *"as high as 150 to even as high as 240+ FPS at 100x100 depending on the complexity of your game, your device and your render settings"* | devforum 2954915; itch devlogs |
| **Raycasting renderer** (open source) | Wolfenstein-style raycaster with textures + interlacing | **100×100** | [COMM] not stated numerically | devforum 3609143 |
| **Realtime Raytracer ran in parallel** | Parallel Luau + EditableImage raytracer | not stated | [COMM] "realtime" | devforum 3478308 |
| **Lightspeed Shader System** | Per-pixel shader framework: interlaced rendering, dynamic resolution, precomputed non-ΔT maths, `--!native` | configurable | [COMM] *"up to 20X faster than manual calculation"*; **broken by the 2025 EditableImage API change** | devforum 2762254 |
| **OSGL** (osgl-rbx) | General graphics library: shapes, textures, fonts, video, flood fill, polygons, triangles | configurable | [COMM] *"semi-realtime pathtracers achieving 30-60 FPS with realtime reflections"* | github.com/osgl-rbx/osgl |
| **Ro2D** | 2D software renderer + physics engine, "contiguous memory buffers instead of ImageLabels or Frames" | configurable | [COMM] no numbers published | devforum 4634716 |
| **CanvasDraw / FastCanvas** (Ethanthegrand) | The de-facto standard canvas library; `FastCanvas` is the buffer core | configurable | [CODE] `--!native`, u32 packing, doubling-copy clear | github.com/Ethanthegrand/CanvasDraw |
| **EditableImage Baked Lighting** | Raytraced GI + soft shadows, **baked** not realtime | lightmap | [COMM] offline bake | devforum 3191321 |

**The pattern is unmistakable: 100×100 = 10,000 pixels is the realtime per-pixel budget.** At 60 fps that is 600 K pixel-shading operations per second in Luau. Every project that needed more resolution either (a) dropped framerate, (b) interlaced, or (c) went offline/baked.

### 7.2 Wolfenstein-style raycaster

The classic DDA raycaster is the best fit for EditableImage because **it computes one value per screen column, not per pixel** — then fills a vertical span with `buffer.copy`.

```lua
local MAP = { ... }        -- MAP[y][x], 0 = empty
local W, H = 160, 100

local function renderColumn(buf, x, camX, camY, rayDirX, rayDirY)
    local mapX, mapY = math.floor(camX), math.floor(camY)
    local deltaX = rayDirX == 0 and math.huge or math.abs(1 / rayDirX)
    local deltaY = rayDirY == 0 and math.huge or math.abs(1 / rayDirY)

    local stepX, sideX, stepY, sideY
    if rayDirX < 0 then stepX, sideX = -1, (camX - mapX) * deltaX
    else                stepX, sideX =  1, (mapX + 1 - camX) * deltaX end
    if rayDirY < 0 then stepY, sideY = -1, (camY - mapY) * deltaY
    else                stepY, sideY =  1, (mapY + 1 - camY) * deltaY end

    -- DDA: step through grid cells until a wall.
    local hit, side = false, 0
    while not hit do
        if sideX < sideY then sideX += deltaX; mapX += stepX; side = 0
        else                  sideY += deltaY; mapY += stepY; side = 1 end
        if MAP[mapY] and MAP[mapY][mapX] and MAP[mapY][mapX] > 0 then hit = true end
    end

    -- Perpendicular distance avoids fisheye.
    local dist = side == 0 and (sideX - deltaX) or (sideY - deltaY)
    local lineH = math.floor(H / dist)
    local y0 = math.max(0, (H - lineH) // 2)
    local y1 = math.min(H - 1, (H + lineH) // 2)

    -- Shade: darker on Y-facing walls, distance fog.
    local shade = (side == 1 and 0.7 or 1.0) * math.clamp(1 - dist / 20, 0.15, 1)
    local c = math.floor(200 * shade)
    local rgba = bit32.bor(bit32.lshift(255,24), bit32.lshift(c,16), bit32.lshift(c,8), c)

    for y = y0, y1 do
        buffer.writeu32(buf, (y * W + x) * 4, rgba)
    end
end
```

**Cost** [UNVERIFIED]: 160 columns × (~10 DDA steps + ~50 span writes) ≈ **160 × 60 = 9,600 operations** for walls. This is *far* cheaper than per-pixel raytracing — the DDA raycaster is the one 3D technique that genuinely fits in a Roblox frame budget at playable resolution. **If you want 3D-in-an-image, start here, not with a raytracer.**

Textured walls multiply the span cost by a texture lookup per pixel (~3×). Floor/ceiling casting is per-pixel and roughly doubles total cost again.

### 7.3 Mandelbrot / fractal renderer

Embarrassingly parallel, fixed cost per pixel, and a good calibration workload.

```lua
local function mandelbrot(buf, W, H, cx, cy, scale, maxIter)
    for py = 0, H - 1 do
        local y0 = (py - H/2) / (H/2) * scale + cy
        local row = py * W * 4
        for px = 0, W - 1 do
            local x0 = (px - W/2) / (W/2) * scale + cx
            local x, y, it = 0, 0, 0
            while x*x + y*y <= 4 and it < maxIter do
                x, y = x*x - y*y + x0, 2*x*y + y0
                it += 1
            end
            local c = it == maxIter and 0 or math.floor(it / maxIter * 255)
            buffer.writeu32(buf, row + px*4,
                bit32.bor(bit32.lshift(255,24), bit32.lshift(c,16), bit32.lshift(c//2,8), c))
        end
    end
end
```

**Cost**: `W × H × avgIter` complex multiplications. At 256² with `maxIter=100` and ~30 average iterations, that is **~2 M iterations** — comfortably a multi-frame job, not a per-frame one. Fractals are the ideal candidate for **progressive refinement**: render every 4th row this frame, fill in over 4 frames.

### 7.4 Particle simulation drawn to a buffer

Here EditableImage genuinely beats the alternative. 5,000 `Frame` instances is impossible; 5,000 particles splatted into a buffer is routine.

```lua
local N = 5000
local px, py = buffer.create(N * 4), buffer.create(N * 4)  -- f32
local vx, vy = buffer.create(N * 4), buffer.create(N * 4)

local function stepParticles(dt, W, H, buf)
    buffer.fill(buf, 0, 0)                                  -- single memset clear
    for i = 0, N - 1 do
        local o = i * 4
        local x = buffer.readf32(px, o) + buffer.readf32(vx, o) * dt
        local y = buffer.readf32(py, o) + buffer.readf32(vy, o) * dt
        buffer.writef32(vy, o, buffer.readf32(vy, o) + 200 * dt)   -- gravity
        if y >= H then y = H - 1; buffer.writef32(vy, o, -buffer.readf32(vy, o) * 0.5) end
        buffer.writef32(px, o, x); buffer.writef32(py, o, y)

        local ix, iy = math.floor(x), math.floor(y)
        if ix >= 0 and ix < W and iy >= 0 and iy < H then
            buffer.writeu32(buf, (iy * W + ix) * 4, 0xFFFFFFFF)
        end
    end
end
```

**Cost** [UNVERIFIED]: ~15 ops × 5000 = **75 K ops/frame**, plus one `buffer.fill`. That fits a frame easily. **Particle sims are the best value-per-cost software-rendering application of EditableImage.**

### 7.5 The performance ceiling, stated plainly

Combining the community evidence with the arithmetic above:

| Work per pixel | Realistic max resolution @ 60 fps | Evidence |
|---|---|---|
| Nothing (blit/copy a prepared buffer) | **1024×1024** | `buffer.copy` is memcpy; `WritePixelsBuffer` is the bottleneck, not Luau |
| ~5 ops (LUT grade, threshold, tint) | **~256×256** | [UNVERIFIED] ~330 K ops/frame |
| ~25 ops (box blur, 3×3 convolution) | **~128×128** | [UNVERIFIED] ~410 K ops/frame |
| Per-pixel 3D shading (raytracing) | **~100×100** | [COMM] RetroRaster, multiple raycasters |
| Per-column 3D (DDA raycaster) | **~160×100** | [UNVERIFIED] arithmetic; consistent with community projects |

**The universal escape hatch is resolution, and it is very effective** because EditableImage output is upscaled by the renderer for free. Halving resolution quarters the cost and, with `ResamplerMode.Pixelated`, often *improves* the aesthetic.

---

## 8. UI and data visualization

### 8.1 When to use EditableImage for UI (and when not to)

**Use it when:** the output is genuinely per-pixel and irregular — a waveform, a heatmap, a smooth radial gradient, a plotted function, a generated icon.

**Do not use it when:** the output is rectangles and text. `Frame`s and `TextLabel`s are GPU-composited, support `UICorner`/`UIGradient`/`UIStroke`, scale with resolution, and cost you nothing in Luau. **A bar chart should be `Frame`s.** A 10,000-point scatter plot should be an EditableImage.

The dividing line is roughly **50–100 elements**. Below it, instances win on both performance and flexibility. Above it, the image wins.

### 8.2 Line chart / waveform

```lua
-- Bresenham line into a buffer. `DrawLine` exists but is 1px and goes through the API each call.
local function drawLine(buf, W, H, x0, y0, x1, y1, rgba)
    x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
    local dx = math.abs(x1 - x0); local sx = x0 < x1 and 1 or -1
    local dy = -math.abs(y1 - y0); local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        if x0 >= 0 and x0 < W and y0 >= 0 and y0 < H then
            buffer.writeu32(buf, (y0 * W + x0) * 4, rgba)
        end
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err += dy; x0 += sx end
        if e2 <= dx then err += dx; y0 += sy end
    end
end

local function plotSeries(buf, W, H, values, minV, maxV, rgba)
    local n = #values
    local prevX, prevY
    for i = 1, n do
        local x = (i - 1) / (n - 1) * (W - 1)
        local y = (1 - (values[i] - minV) / (maxV - minV)) * (H - 1)
        if prevX then drawLine(buf, W, H, prevX, prevY, x, y, rgba) end
        prevX, prevY = x, y
    end
end
```

**Scrolling waveform trick.** Do not redraw the whole plot each frame. Shift the buffer left by one column with a single `buffer.copy` and draw only the new column:

```lua
local function scrollLeft(buf, W, H, cols)
    for y = 0, H - 1 do
        local row = y * W * 4
        buffer.copy(buf, row, buf, row + cols * 4, (W - cols) * 4)
        -- clear the newly exposed right edge
        buffer.fill(buf, row + (W - cols) * 4, 0, cols * 4)
    end
end
```

**Cost**: `H` copies of `(W-cols)*4` bytes — a few hundred microseconds at 256 wide [UNVERIFIED]. This makes real-time oscilloscopes and spectrum analysers practical.

### 8.3 Progress rings

```lua
local function drawRing(buf, W, H, cx, cy, rOuter, rInner, fraction, rgba)
    local maxAng = fraction * math.pi * 2
    local r2o, r2i = rOuter * rOuter, rInner * rInner
    for y = math.max(0, cy - rOuter), math.min(H - 1, cy + rOuter) do
        for x = math.max(0, cx - rOuter), math.min(W - 1, cx + rOuter) do
            local dx, dy = x - cx, y - cy
            local d2 = dx*dx + dy*dy
            if d2 <= r2o and d2 >= r2i then
                -- Angle measured clockwise from 12 o'clock.
                local ang = math.atan2(dx, -dy)
                if ang < 0 then ang += math.pi * 2 end
                if ang <= maxAng then
                    buffer.writeu32(buf, (y * W + x) * 4, rgba)
                end
            end
        end
    end
end
```

Anti-alias by supersampling the boundary: test 4 sub-positions per edge pixel and blend by the fraction inside. Roughly doubles the cost for a large visual gain.

### 8.4 Text rendering — the hard problem

**Confirmed constraint:** Roblox exposes **no font rasterizer** to Luau. There is no API that turns a `Font` into glyph bitmaps. You cannot draw `TextLabel` output into an `EditableImage`. This is the single biggest gap in the API for UI work.

Three workarounds, in increasing order of quality and effort:

**(a) Bitmap font atlas — the standard answer.**

Ship a PNG of all glyphs plus a metrics table (`.fnt`-style: per-glyph x, y, width, height, xoffset, yoffset, xadvance). Load the PNG with `CreateEditableImageAsync` and blit rectangles.

```lua
-- metrics[char] = {x=, y=, w=, h=, xoff=, yoff=, adv=}
local function drawText(dstBuf, dstW, dstH, atlasBuf, atlasW, metrics, text, penX, penY, rgba)
    for i = 1, #text do
        local ch = text:sub(i, i)
        local m = metrics[ch]
        if ch == "\n" then penX = 0; penY += metrics.lineHeight
        elseif m then
            for gy = 0, m.h - 1 do
                local sy = m.y + gy
                local dy = penY + m.yoff + gy
                if dy >= 0 and dy < dstH then
                    for gx = 0, m.w - 1 do
                        local dx = penX + m.xoff + gx
                        if dx >= 0 and dx < dstW then
                            -- Atlas alpha is the coverage mask; colour comes from `rgba`.
                            local a = buffer.readu8(atlasBuf, ((sy * atlasW) + m.x + gx) * 4 + 3)
                            if a > 0 then
                                local di = (dy * dstW + dx) * 4
                                if a == 255 then
                                    buffer.writeu32(dstBuf, di, rgba)
                                else
                                    -- Blend for antialiased edges.
                                    local f = a / 255
                                    local sr = bit32.band(rgba, 0xFF)
                                    local sg = bit32.band(bit32.rshift(rgba, 8), 0xFF)
                                    local sb = bit32.band(bit32.rshift(rgba, 16), 0xFF)
                                    local br = buffer.readu8(dstBuf, di)
                                    local bg = buffer.readu8(dstBuf, di + 1)
                                    local bb = buffer.readu8(dstBuf, di + 2)
                                    buffer.writeu8(dstBuf, di,     br + (sr - br) * f)
                                    buffer.writeu8(dstBuf, di + 1, bg + (sg - bg) * f)
                                    buffer.writeu8(dstBuf, di + 2, bb + (sb - bb) * f)
                                end
                            end
                        end
                    end
                end
            end
            penX += m.adv
        end
    end
    return penX, penY
end
```

**Cost** [UNVERIFIED]: a 12×16 glyph is 192 texel tests. A 40-character line ≈ **7,700 tests**. Fine for labels, **expensive for paragraphs** — budget ~10 K–20 K texels per line of text.

[CODE] OSGL's `src/font.luau` takes this approach but stores **per-glyph bitmaps rather than one atlas**, packing width/height into a single u32 via `bit32.extract(size, 0, 16)` / `bit32.extract(size, 16, 16)`, and draws pixel-by-pixel where the glyph bit is `1`. Its spacing is fixed (`self.spacing`, default 5) with no kerning pairs. Its own limitation, observable in the code: **per-pixel drawing with no batching, suitable for small text rather than high-volume rendering.**

**Improvement over OSGL's approach:** store glyphs in one atlas and use `buffer.copy` per glyph *row* when the glyph is opaque (no alpha blending). That converts an inner loop of `m.w` tests into one memcpy — typically **5–10× faster** for pixel fonts [UNVERIFIED].

**(b) SDF (signed distance field) atlas — scalable, better quality.**

Store distance-to-edge instead of coverage. One atlas renders at any size with crisp edges.

```lua
-- Sample the SDF and threshold with a smooth edge. `spread` is the SDF's distance range.
local function sdfCoverage(d, smoothing)          -- d in 0..1, 0.5 = on the edge
    return math.clamp((d - (0.5 - smoothing)) / (2 * smoothing), 0, 1)
end
```

Costs one extra multiply-add per texel over a bitmap font and gives you free outlines (threshold at a second, lower value) and glows. **Generating** the SDF requires an offline tool (msdfgen or similar) — you cannot make it at runtime.

**(c) Pre-rendered glyph sheets from `TextLabel`s — not viable at runtime.**

The tempting idea is to render text with a real `TextLabel`, screenshot it, and read it back. **This does not work**: see §9 — `CaptureService` output cannot become an `EditableImage` at runtime [COMM]. You *can* do this **in Studio/plugin context** to build your atlas offline, then ship the result. That is the recommended authoring pipeline.

**Practical recommendation:** for most games, **overlay a real `TextLabel` on top of the `ImageLabel`** rather than rendering text into the image. You keep Roblox's font rendering, localisation and text filtering, and pay nothing. Render text *into* the image only when it must be part of the pixels (baked into a texture on a mesh, or exported).

### 8.5 Generating a UI atlas at runtime

Pack procedurally generated icons into one image and address them with `ImageRectOffset`/`ImageRectSize` on ordinary `ImageLabel`s.

```lua
local ATLAS = 1024
local atlas = AssetService:CreateEditableImage({ Size = Vector2.new(ATLAS, ATLAS) })
local cursorX, cursorY, rowH = 0, 0, 0

local function addIcon(iconBuf, w, h): (Vector2, Vector2)
    if cursorX + w > ATLAS then cursorX = 0; cursorY += rowH; rowH = 0 end
    local pos = Vector2.new(cursorX, cursorY)
    atlas:WritePixelsBuffer(pos, Vector2.new(w, h), iconBuf)
    cursorX += w
    rowH = math.max(rowH, h)
    return pos, Vector2.new(w, h)
end

-- Usage:
local off, size = addIcon(myIconBuffer, 64, 64)
label.ImageContent    = Content.fromObject(atlas)
label.ImageRectOffset = off
label.ImageRectSize   = size
```

**This is the most important structural pattern in the whole chapter for UI.** It converts N EditableImages into **one**, which:
- collapses N units of memory budget into one,
- **completely sidesteps the one-update-per-frame limit** (all icons update in a single image update),
- and lets the GPU batch all those `ImageLabel`s into fewer draw calls.

[COMM] There is an open feature request — *"Allow EditableImage to efficiently use regions from a shared image atlas"* — which confirms both that this pattern is what developers want and that the ergonomics around it are currently manual.

---

## 9. Screen-space and camera effects

### 9.1 You cannot read the rendered frame. Stated plainly.

**There is no API to read the rendered framebuffer into an `EditableImage`.** This is a hard limitation, and it means:

- No true post-processing (no real bloom, real depth-of-field, real SSAO, real motion blur from the actual frame).
- No screen-space reflections.
- No "screenshot the game world onto a TV in-game."
- No reading what a `ViewportFrame` rendered.

[COMM] The specific failure people hit: the pipeline `CaptureService:CaptureScreenshot()` → `rbxtemp://` id → `AssetService:CreateEditableImageAsync()` **is refused at runtime**, with the error *"AssetService:CreateEditableImageAsync cannot currently create editable image from temporary texture id."* Edit-mode capture on the same machine works, which is why this trips people up — it works in Studio and fails in a live session. There is an open feature request ("Possible to make EditableImages support CaptureService?") confirming it is not currently possible.

> **Treat this as permanent for planning purposes.** If your design requires reading rendered pixels, redesign it.

### 9.2 What you CAN do: overlay effects

Everything below is a **full-screen `ImageLabel` drawn over the game**, containing an EditableImage you generate. You are compositing *on top of* the frame, not processing it.

```lua
local overlay = Instance.new("ImageLabel")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 1
overlay.ResampleMode = Enum.ResamplerMode.Default
overlay.ZIndex = 100
overlay.Parent = screenGui

local OW, OH = 256, 144      -- LOW resolution: it is stretched to the whole screen
local fx = AssetService:CreateEditableImage({ Size = Vector2.new(OW, OH) })
overlay.ImageContent = Content.fromObject(fx)
```

**Overlay resolution should be low.** A full-screen effect stretched from 256×144 is visually fine for scanlines, vignettes and grain — and is **~28× cheaper** than 1080p-equivalent [UNVERIFIED].

### 9.3 CRT / scanlines / VHS

```lua
local function renderCRT(buf, W, H, t)
    for y = 0, H - 1 do
        -- Scanline darkening: every other line, plus a slow rolling bright band.
        local scan = (y % 2 == 0) and 0 or 60
        local roll = math.sin((y / H + t * 0.15) * math.pi * 2) * 10
        local row = y * W * 4
        for x = 0, W - 1 do
            -- Vignette: darken toward the edges.
            local dx, dy = (x / W - 0.5) * 2, (y / H - 0.5) * 2
            local vig = math.clamp((dx*dx + dy*dy) * 0.5, 0, 1)
            local a = math.clamp(scan + roll + vig * 120, 0, 255)
            buffer.writeu32(buf, row + x * 4, bit32.bor(bit32.lshift(math.floor(a), 24), 0))
        end
    end
end
```

Black with varying **alpha** — the game shows through. For **VHS**, add horizontal jitter: shift whole rows by a noise-driven offset using `buffer.copy`, and add a chroma-shifted ghost by drawing a second, offset, tinted copy.

```lua
-- Per-row horizontal jitter (VHS tracking error). Cheap: one copy per row.
local function jitterRows(buf, W, H, t)
    for y = 0, H - 1 do
        local n = math.noise(y * 0.3, t * 4)
        if math.abs(n) > 0.35 then
            local shift = math.floor(n * 6)
            local row = y * W * 4
            if shift > 0 then
                buffer.copy(buf, row + shift * 4, buf, row, (W - shift) * 4)
            elseif shift < 0 then
                buffer.copy(buf, row, buf, row - shift * 4, (W + shift) * 4)
            end
        end
    end
end
```

### 9.4 Damage vignette

The most common practical use, and it is cheap because it is **radial and static per health value** — regenerate only when health changes, not every frame.

```lua
local function renderDamageVignette(buf, W, H, intensity)
    local cx, cy = W / 2, H / 2
    local maxD = math.sqrt(cx*cx + cy*cy)
    for y = 0, H - 1 do
        local row = y * W * 4
        for x = 0, W - 1 do
            local dx, dy = x - cx, y - cy
            local d = math.sqrt(dx*dx + dy*dy) / maxD
            -- Sharp falloff: only the outer ~35% is affected.
            local a = math.clamp((d - 0.65) / 0.35, 0, 1) ^ 1.5 * intensity
            buffer.writeu32(buf, row + x * 4, bit32.bor(
                bit32.lshift(math.floor(a * 255), 24),
                0, 0, 180))                                  -- dark red
        end
    end
end
```

**Regenerate on health change only.** A pulsing vignette can pulse via `ImageLabel.ImageTransparency` (free, GPU-side) rather than redrawing pixels.

### 9.5 Night vision and thermal

**Critical caveat:** because you cannot read the frame, you cannot *actually* recolour the scene. What you can do:

- **Night vision**: a green overlay (`ImageLabel` with `ImageColor3` green, `Multiply`-ish look) + procedural noise/grain in the EditableImage + a lens-circle vignette. Combine with `ColorCorrectionEffect` (`TintColor` green, boosted `Brightness`) and `Lighting.Ambient` changes, which **are** real post-effects the engine provides.
- **Thermal**: genuinely not achievable as a screen-space filter. The practical approach is **object-space**: swap materials/colours on characters to a heat palette via `Highlight` instances, set `Lighting` to flat, and overlay EditableImage-generated grain and a scanning bar.

**The correct mental model: EditableImage supplies the *grain, edges, and UI furniture* of the effect; `Lighting` post-effects and `Highlight` instances supply the *recolouring*.**

### 9.6 Static/noise/grain generation

```lua
-- Precompute several noise frames at init, then cycle them. Far cheaper than generating per frame.
local NOISE_FRAMES = 8
local noiseFrames = {}
for f = 1, NOISE_FRAMES do
    local b = buffer.create(OW * OH * 4)
    for i1 = 0, OW*OH - 1 do
        local v = math.random(0, 255)
        buffer.writeu32(b, i1*4, bit32.bor(bit32.lshift(v // 4, 24),
            bit32.lshift(v,16), bit32.lshift(v,8), v))
    end
    noiseFrames[f] = b
end

local frame = 1
RunService.RenderStepped:Connect(function()
    frame = frame % NOISE_FRAMES + 1
    fx:WritePixelsBuffer(Vector2.zero, Vector2.new(OW, OH), noiseFrames[frame])
end)
```

**Precomputing and cycling is the general pattern for any animated effect with a short loop.** Generation cost moves to load time; runtime cost is a single `WritePixelsBuffer`.

---

## 10. Animation

### 10.1 The frame-budget maths

This is the number every builder needs. At 60 fps you have **16.67 ms**; at 30 fps, **33.3 ms**. A realistic budget for image work is **2–4 ms** — the rest belongs to the game.

Pixel counts:

| Resolution | Pixels | RGBA bytes |
|---|---|---|
| 64×64 | 4,096 | 16 KB |
| 128×128 | 16,384 | 64 KB |
| 256×256 | 65,536 | 256 KB |
| 512×512 | 262,144 | 1 MB |
| 1024×1024 | 1,048,576 | 4 MB |

[UNVERIFIED — order-of-magnitude reasoning, verify with `os.clock()` on target hardware] Interpreted Luau does roughly **10–50 M simple operations per second** in a tight buffer loop; `--!native` improves this substantially. If a per-pixel operation costs ~10 ops, a 2 ms budget buys roughly **20 K–100 K pixels of work per frame**. That lands on:

| Budget | Full-rewrite resolution @ 60 fps | @ 30 fps |
|---|---|---|
| Trivial per-pixel (~5 ops) | **~128×128 to 256×256** | ~256×256 to 362×362 |
| Moderate (~15 ops) | **~96×96 to 160×160** | ~136×136 to 226×226 |
| Heavy (~50 ops, 3D shading) | **~64×64 to 100×100** | ~90×90 to 140×140 |
| Pure `buffer.copy` blit | **1024×1024** (limited by `WritePixelsBuffer`, not Luau) | 1024×1024 |

**This table matches the community evidence in §7.1**, which is the strongest confirmation available in the absence of published microbenchmarks.

### 10.2 Flipbook generation and playback

Generate the frames once, then playback is pure `buffer.copy`.

```lua
-- Generate N frames of a procedural loop at init.
local FRAMES, FW, FH = 16, 128, 128
local frames = table.create(FRAMES)
for f = 1, FRAMES do
    local b = buffer.create(FW * FH * 4)
    generateFireFrame(b, FW, FH, (f - 1) / FRAMES)   -- see 10.3
    frames[f] = b
end

-- Playback: one memcpy + one WritePixelsBuffer per frame. Essentially free.
local img = AssetService:CreateEditableImage({ Size = Vector2.new(FW, FH) })
local t, fps = 0, 12
RunService.Heartbeat:Connect(function(dt)
    t += dt
    local f = math.floor(t * fps) % FRAMES + 1
    img:WritePixelsBuffer(Vector2.zero, Vector2.new(FW, FH), frames[f])
end)
```

**Memory**: 16 frames × 128² × 4 B = **1 MB**. That is a meaningful fraction of the budget — prefer fewer, larger-step frames with interpolation, or a smaller resolution.

**Sprite-sheet packing.** To animate via `ImageRectOffset` on an ordinary `ImageLabel` instead (zero per-frame Luau cost), pack the frames into one image:

```lua
-- 4x4 grid of 128x128 frames in one 512x512 image.
local sheet = AssetService:CreateEditableImage({ Size = Vector2.new(512, 512) })
for f = 1, 16 do
    local col, row = (f - 1) % 4, (f - 1) // 4
    sheet:WritePixelsBuffer(Vector2.new(col * 128, row * 128), Vector2.new(128, 128), frames[f])
end
label.ImageContent = Content.fromObject(sheet)
-- Then per frame: label.ImageRectOffset = Vector2.new(col*128, row*128)  -- no image update at all!
```

**This is strictly better than rewriting the image each frame**: it costs zero image updates, so it does not consume your one-update-per-frame budget, and it works for many animated elements simultaneously.

### 10.3 Procedural fire

```lua
-- Classic "fire" cellular automaton: heat rises with random decay.
local heat = buffer.create(FW * FH)      -- 8-bit heat field
local FIRE_PALETTE = {}                  -- 256 entries, black -> red -> orange -> yellow -> white
for i = 0, 255 do
    local t = i / 255
    local r = math.clamp(t * 3, 0, 1)
    local g = math.clamp(t * 3 - 1, 0, 1)
    local b = math.clamp(t * 3 - 2, 0, 1)
    FIRE_PALETTE[i] = bit32.bor(bit32.lshift(math.floor(t * 255), 24),
        bit32.lshift(math.floor(b*255),16), bit32.lshift(math.floor(g*255),8), math.floor(r*255))
end

local function fireStep(buf, W, H)
    -- Seed the bottom row with random heat.
    local base = (H - 1) * W
    for x = 0, W - 1 do
        buffer.writeu8(heat, base + x, math.random(180, 255))
    end
    -- Propagate upward with lateral spread and decay.
    for y = 0, H - 2 do
        local row, below = y * W, (y + 1) * W
        for x = 0, W - 1 do
            local l = buffer.readu8(heat, below + math.max(0, x - 1))
            local c = buffer.readu8(heat, below + x)
            local r = buffer.readu8(heat, below + math.min(W - 1, x + 1))
            local v = (l + c + c + r) // 4 - math.random(0, 3)
            if v < 0 then v = 0 end
            buffer.writeu8(heat, row + x, v)
            buffer.writeu32(buf, (row + x) * 4, FIRE_PALETTE[v])
        end
    end
end
```

**Cost** [UNVERIFIED]: ~12 ops × W×H. At 128×128 = **~200 K ops/frame** — borderline at 60 fps, comfortable at 30 fps or at 64×64. **Run procedural fire at 64×64 and let `ResamplerMode.Pixelated` do the rest**; the aesthetic suits it.

### 10.4 Scrolling and morphing textures

**Scrolling costs nothing if you do it right** — do not rewrite pixels, offset the UV:

```lua
-- FREE: the engine does the scroll.
texture.OffsetStudsU += dt * 0.5
-- or for UI:
label.ImageRectOffset = Vector2.new(scrollX % texWidth, 0)
```

Use EditableImage scrolling only when the content itself changes. If you must scroll pixels (e.g. an infinite generated strip), use `buffer.copy` to shift and generate only the newly exposed edge — the pattern from §8.2.

**Morphing** between two textures is a lerp, and it is one of the cheaper per-pixel operations:

```lua
local function morph(a, b, out, W, H, t)
    local it = 1 - t
    for i1 = 0, W*H*4 - 1 do
        buffer.writeu8(out, i1, buffer.readu8(a, i1) * it + buffer.readu8(b, i1) * t)
    end
end
```

~5 ops per **byte** (4× per pixel). At 256² that is **~1.3 M ops** — do it at 128² or across frames.

---

## Performance discipline

### The cost model: three distinct costs

Conflating these is the root of most EditableImage performance problems.

**1. Read cost — `ReadPixelsBuffer`.** Allocates and copies. A full 1024² read is a **4 MB allocation plus 4 MB copy, every call**, plus GC pressure. **Rule: read at most once, at initialisation. Never in a loop, never per frame.** Keep your own authoritative buffer.

**2. Write cost — `WritePixelsBuffer`.** Copies your bytes into the engine's image and marks it dirty. Proportional to the region size, so **write dirty rectangles, not whole images**. [COMM] described as *"kind of slow"* and a cause of frame drops when called at a fixed high rate — consistent with it being a memcpy plus a texture-upload scheduling operation.

**3. Draw cost — `DrawImage`/`DrawCircle`/`DrawRectangle`/`DrawImageProjected`.** Native engine-side operations. **Per call, these are much faster than the equivalent Luau loop**, but each is an API boundary crossing. `DrawCircle` for 10,000 particles is 10,000 crossings and will be slower than one Luau loop. **Heuristic: use Draw* for tens of large operations; use buffer loops for thousands of small ones.**

**4. The presentation cost — the one-per-frame limit.** [DOC] This is not a cost you can optimise, it is a scheduling constraint: *"if you update three `EditableImage` objects which are currently being displayed, it will take three frames for all of them to be updated."* **Consolidate into one image (atlas) or accept 1/N update rate.**

### Chunked and tiled updates

The general structure for any large canvas:

```lua
local TILE = 64
local TX, TY = W // TILE, H // TILE
local dirtyTiles = {}          -- set of tile keys
local MAX_TILES_PER_FRAME = 8  -- bound the worst case

local function markTileDirty(tx, ty) dirtyTiles[ty * TX + tx] = true end

local function flushTiles()
    local sent = 0
    for key in dirtyTiles do
        if sent >= MAX_TILES_PER_FRAME then break end
        local tx, ty = key % TX, key // TX
        local sub = buffer.create(TILE * TILE * 4)
        for row = 0, TILE - 1 do
            buffer.copy(sub, row * TILE * 4,
                canvas, (((ty * TILE + row) * W) + tx * TILE) * 4, TILE * 4)
        end
        img:WritePixelsBuffer(Vector2.new(tx * TILE, ty * TILE), Vector2.new(TILE, TILE), sub)
        dirtyTiles[key] = nil
        sent += 1
    end
end
```

**`MAX_TILES_PER_FRAME` is your safety valve.** It converts an unbounded spike (someone flood-fills the canvas) into a bounded per-frame cost with a graceful visual catch-up. **Every production canvas should have this.**

Note: multiple `WritePixelsBuffer` calls to *the same* image within one frame are fine — the one-per-frame limit is about **distinct images being presented**, not about the number of write calls.

### Resolution tiers

Pick resolution from **screen coverage and update frequency**, not from "what looks nice":

| Use | Resolution | Rationale |
|---|---|---|
| Full-screen overlay effect | 256×144 | Stretched; high frequency detail invisible |
| Minimap | 256×256 | Small on screen |
| Character texture (near) | 512×512 | 1 MB each — budget-limited |
| Character texture (far) | 128×128 | 64 KB; swap by distance |
| Shared drawing canvas | 1024×1024 | Players inspect it closely |
| Wall graffiti | 512×512 | Viewed at a distance |
| Software 3D render | 100×100–160×120 | The per-pixel ceiling |
| Procedural fire/water | 64×64 | Upscaled with `Pixelated` |

### Double buffering

Only necessary when generation spans multiple frames and you cannot show a partial result.

```lua
local front = AssetService:CreateEditableImage({ Size = sz })
local backBuf = buffer.create(W * H * 4)   -- CPU-side back buffer: cheap
-- ...generate into backBuf across several frames...
-- When complete, present in one call:
front:WritePixelsBuffer(Vector2.zero, sz, backBuf)
```

**Use a CPU-side back buffer, not a second `EditableImage`.** A second image costs memory budget *and* a presentation slot; a second `buffer` costs only RAM. This is an important distinction — classic double-buffering intuition leads people to allocate two images, which is exactly wrong here.

### Spreading work across frames

```lua
local function makeSliceWorker(totalRows, rowsPerFrame, rowFn, onDone)
    local row = 0
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local budget = math.min(rowsPerFrame, totalRows - row)
        for _ = 1, budget do rowFn(row); row += 1 end
        if row >= totalRows then conn:Disconnect(); if onDone then onDone() end end
    end)
end

-- Generate a 512x512 procedural texture over ~16 frames without a hitch.
makeSliceWorker(512, 32, generateRow, function()
    img:WritePixelsBuffer(Vector2.zero, Vector2.new(512, 512), buf)
end)
```

**Adaptive variant** — scale the slice to the measured frame time:

```lua
local rowsPerFrame = 32
RunService.Heartbeat:Connect(function(dt)
    if dt > 1/50 then rowsPerFrame = math.max(4, rowsPerFrame - 4)
    elseif dt < 1/58 then rowsPerFrame = math.min(128, rowsPerFrame + 4) end
end)
```

This is the single most robust technique for keeping heavy image work off the frame-time graph, and it generalises to every O(N) operation in this chapter.

### Does any of it parallelise?

**Partially, and with a hard rule.**

- **`WritePixelsBuffer` is not thread-safe.** [COMM] It is tagged unsafe, and the community consensus in "How to write to an EditableImage in parallel" is that it cannot be called from a desynchronised context.
- **`buffer` operations are parallel-safe.** Actors can compute into buffers all they like.

**The working pattern:**

```lua
-- In each Actor's script (parallel): compute a horizontal band into a shared buffer.
task.desynchronize()
for y = bandStart, bandEnd do
    for x = 0, W - 1 do
        buffer.writeu32(sharedBuf, (y * W + x) * 4, shade(x, y))
    end
end
task.synchronize()
-- Signal completion; the serial coordinator does the single write.
```

The coordinator waits for all bands, then performs **one** `WritePixelsBuffer` on the serial thread.

[COMM] This is how the "Realtime Raytracer ran in parallel" and "Realtime minimap using EditableImage & Parallel Luau" projects work, and RetroRaster is described as *"multi-threaded."* [DOC] Roblox's own guidance: *"For the best performance, use more Actors, as even if the device has fewer cores than Actors, the granularity allows for more efficient load balancing between the cores."*

**Caveat:** actor communication has overhead. Parallelism pays off for heavy per-pixel work (raytracing, raycast sampling), not for cheap operations where the sync cost dominates.

### `--!native` and micro-optimisation

[CODE] `FastCanvas` opens with `--!native`, and [COMM] Lightspeed lists *"compiles to machine code with `--!native`"* among the reasons for its claimed 20× speedup. **Put `--!native` at the top of every module containing a hot pixel loop.** It is the cheapest optimisation available.

Supporting micro-optimisations, in rough order of value:

1. **Localise everything hot**: `local readu8, writeu32 = buffer.readu8, buffer.writeu32`.
2. **`u32` over four `u8`** for whole-pixel writes (§0).
3. **Hoist row offsets** out of the inner loop (`local row = y * W * 4`).
4. **`buffer.fill` for clears** — one memset, not a loop.
5. **The doubling-copy fill** for a repeated pattern. [CODE] `FastCanvas`:

```lua
-- Fill a scanline with a colour in O(log n) buffer.copy calls instead of O(n) writes.
buffer.writeu32(ClearingGrid, 0, ClearColU32)
local SizeStep = 4
while SizeStep < Length do
    local Count = math.min(SizeStep, Length - SizeStep)
    buffer.copy(ClearingGrid, SizeStep, ClearingGrid, 0, Count)
    SizeStep += Count
end
-- Then replicate the scanline down the image, one copy per row.
for Y = 1, Height - 1 do
    buffer.copy(ClearingGrid, Y * Width * 4, ClearingGrid, 0, Length)
end
-- Clear is then a single full-buffer copy:
function Canvas:Clear() buffer.copy(Grid, 0, ClearingGrid, 0) end
```

This is the best single idiom in the chapter. `Canvas:Clear()` for a 1024² canvas becomes **one 4 MB memcpy**, versus a million `writeu32` calls.

6. **Avoid `Color3` in hot loops** — it allocates. Pass raw numbers.
7. **Avoid closures per pixel** — inline the work.

### Memory discipline

[DOC] *"EditableImage has strict client-side memory budgets, although the server, Studio, and plugins operate with unlimited memory."* Creation returns `nil` on exhaustion.

[COMM] Reported figures — **all second-hand, treat as approximate**: a ~**32 MB** client budget; developers hitting the limit after ~**5–6** images; a reported cap of **8** simultaneous editables (images + meshes). There is an active feature request for a higher limit (128 MB, 2048²/4096²).

**Rules:**

```lua
local img = AssetService:CreateEditableImage({ Size = sz })
if not img then
    -- ALWAYS handle this. Degrade gracefully: lower resolution, or fall back to a static asset.
    img = AssetService:CreateEditableImage({ Size = sz / 2 })
end
```

1. **Always nil-check.** A missing check is a silent crash on low-end devices only.
2. **`Destroy()` aggressively.** [DOC] It *"immediately reclaims used memory."* Destroy character textures when players leave range.
3. **Budget in bytes**: `W × H × 4`. Ten 512² images = 10 MB. Plan before you build.
4. **Atlas instead of multiplying images** (§8.5) — the single highest-leverage memory decision.
5. [COMM] There is a known ask ("Add a way to discard EditableImage buffer after it's no longer being edited") for freeing the CPU-side copy of a now-static image. **No such API exists**, so a finished, static image still costs its full budget. The workaround for a truly finished texture is to upload it via `AssetService:CreateAssetAsync` and reference the resulting asset id — at the cost of moderation and a network round-trip.

### The mobile ceiling

[UNVERIFIED — no published mobile-specific EditableImage benchmark exists; this is reasoned guidance, and the most important thing to actually measure yourself.] Mobile is where designs break, for three compounding reasons:

1. **Single-thread performance** is roughly **2–4× lower** than desktop. Everything in §10.1 shrinks accordingly.
2. **Memory budgets are device-specific** [DOC] and lower on mobile — the `nil` return from `CreateEditableImage` is a *mobile* failure mode more than a desktop one.
3. **Thermal throttling** means a technique that passes a 30-second test degrades after 10 minutes of play.

**Practical mobile rules:**

```lua
-- Tier off a cheap capability probe. Do NOT use only UserInputService.TouchEnabled.
local function pickTier(): number
    local mem = game:GetService("Stats"):GetTotalMemoryUsageMb()
    local touch = game:GetService("UserInputService").TouchEnabled
    if touch then return 1 end          -- conservative
    return 2
end

local RES = { [1] = Vector2.new(128,128), [2] = Vector2.new(512,512) }
```

- Halve resolution on touch devices; quarter the per-frame work budget.
- Prefer **precomputed/cycled** content (§9.6) over per-frame generation.
- Prefer **sprite-sheet `ImageRectOffset` animation** (§10.2) over image rewrites — it is free on all devices.
- Test the `nil` path. It is not hypothetical.

---

## Benchmark table

**Read this table with the caveat at the top of the chapter.** Entries marked **[COMM]** are second-hand community reports gathered via search summarization (devforum was not directly reachable) with no stated methodology or hardware. Entries marked **[UNVERIFIED]** are my own arithmetic from operation counts. **No rigorous published microbenchmark for EditableImage was found.** Measure on your target devices with `os.clock()` before committing.

| Technique | Resolution | Cost / result | Source & confidence |
|---|---|---|---|
| **Presentation limit** | any | **1 displayed image updated per frame**; 3 images → 3 frames | [DOC] `EditableImage.yaml` |
| **Max image size** | — | **1024×1024**, `Size` read-only, no resize | [DOC] `EditableImage.yaml` |
| **Default image size** | — | 512×512 when `Size` omitted | [DOC] `AssetService.yaml` |
| **Memory per image** | 512² / 1024² | **1 MB / 4 MB** uncompressed RGBA | [UNVERIFIED] arithmetic; [COMM] corroborates "512×512 ≈ 1 MB" |
| **Client memory budget** | — | ~**32 MB**; limit hit after ~5–6 images; reported cap of 8 editables | [COMM] devforum 4389575, 3490799, 4219561 |
| **Server / Studio / plugin budget** | — | **unlimited** | [DOC] `EditableImage.yaml` |
| **RetroRaster** (textured multithreaded raytracer of live scene) | **100×100** | **18 FPS → 150+ FPS**; "240+ FPS at 100×100" on capable machines/settings | [COMM] devforum 2954915 + itch devlogs |
| **Raycasting renderer** (textured, interlaced) | **100×100** | playable; no numbers given | [COMM] devforum 3609143 |
| **OSGL pathtracer** | not stated | **30–60 FPS** "semi-realtime with realtime reflections" | [COMM] devforum 3066757 |
| **Lightspeed Shader System** | configurable | **"up to 20× faster"** than naive per-pixel; `--!native` + interlacing + dynamic res. **Broken by the 2025 API change** | [COMM] devforum 2762254 |
| **Naive per-pixel iteration (pre-buffer API)** | 640×360 (230,400 px) | **"seconds"** to iterate | [COMM] devforum 2737792 — historical, table-based API; buffers are far faster |
| **`WritePixelsBuffer` at high fixed rate** | not stated | "kind of slow"; causes frame drops | [COMM] devforum 3638723 |
| **Blur at full resolution** | not stated | "quite laggy"; standard fix is ½×½ downscale then upscale (**4× saving**) | [COMM] devforum 2825247 / 2828242 |
| **Full 1024² rewrite** | 1024×1024 | 1,048,576 px × ~10 ops = **~10 M ops** — will not fit a 60 fps frame in Luau | [UNVERIFIED] arithmetic |
| **Dirty-rect splat** (r=32) | 1024² canvas | ~3,200 px touched = **~32 K ops** — dozens per frame OK | [UNVERIFIED] arithmetic |
| **`buffer.copy` doubling clear** | 1024² | **~10 `buffer.copy` calls** for a scanline + 1023 row copies; `Clear()` = 1× 4 MB memcpy | [CODE] `FastCanvas.luau` |
| **Separable box blur (running sum)** | 256² | 2 passes × 65 K px × ~12 ops = **~1.6 M ops** | [UNVERIFIED] arithmetic |
| **3×3 convolution** | 256² | 27 reads/px × 65 K = **~1.8 M reads** | [UNVERIFIED] arithmetic |
| **Sobel normal map** | 256² | 8 reads + ~15 ops/px = **~1.5 M ops** — load-time job | [UNVERIFIED] arithmetic |
| **fBm noise, 4 octaves** | 256² | **262,144 `math.noise` calls** — load-time job | [UNVERIFIED] arithmetic |
| **Floyd–Steinberg, 16-colour linear search** | 256² | **~1 M distance computations**; LUT cube reduces to 1 read/px | [UNVERIFIED] arithmetic |
| **LUT colour grade** | 256² | **~8 ops/px ≈ 520 K ops** — cheapest useful filter | [UNVERIFIED] arithmetic |
| **DDA raycaster (walls only)** | 160×100 | ~160 cols × ~60 ops = **~9.6 K ops** — cheapest 3D technique by far | [UNVERIFIED] arithmetic |
| **Particle sim → buffer** | 5,000 particles | ~15 ops each = **~75 K ops/frame** + 1 `buffer.fill` | [UNVERIFIED] arithmetic |
| **Procedural fire automaton** | 128×128 | ~12 ops × 16 K px = **~200 K ops/frame** — borderline at 60 fps; use 64² | [UNVERIFIED] arithmetic |
| **Bitmap font glyph blit** | 12×16 glyph | **192 texel tests/glyph**; 40-char line ≈ **7.7 K tests** | [UNVERIFIED] arithmetic |
| **Stroke network payload** | 200-point stroke | **~600 B** (3 B/pt) vs **4 MB** full canvas = **~7000× reduction** | [UNVERIFIED] arithmetic |
| **Coverage scoring (owner map)** | 1024² | **O(1)** per query via incremental counters vs 1 M-read scan | [UNVERIFIED] design |
| **Sprite-sheet `ImageRectOffset` animation** | any | **zero image updates**; does not consume the per-frame slot | [DOC] + [UNVERIFIED] |
| **CaptureService → EditableImage at runtime** | — | **Refused**: *"cannot currently create editable image from temporary texture id"* | [COMM] devforum 3652078, 3629937; GitHub revvy02/rodeo#17 |
| **Roblox reference brush textures** | 64×64 circle, 4×4 line | Roblox's own painting tool's stamp sizes | [CODE] `Roblox/avatar` TextureUtils.lua |

---

## Cross-cutting notes for other chapters

- **API reference chapter**: must carry the exact `DrawImageProjected`/`SampleImageProjected` dictionary keys, the `Enum.AntiAliasing` parameter on `DrawCircle`/`DrawLine`, the `RaycastLocal` vs `FindClosestPointOnSurface` tuple-order discrepancy, and `CreateSurfaceAppearanceAsync`'s "cannot be reassigned after creation" rule.
- **Performance/optimisation chapter**: the one-update-per-frame presentation limit and the CPU-back-buffer-not-second-image rule belong there too.
- **Networking chapter**: the "replicate the seed, not the pixels" and "send strokes, not pixels" patterns generalise well beyond images.
- **EditableMesh chapter**: `DrawImageProjected` couples the two APIs; a paint system needs both, and `FixedSize` mesh options affect the memory budget shared with images.

---

## Sources

**Official documentation (via the `Roblox/creator-docs` GitHub mirror — `create.roblox.com` was egress-blocked):**
- EditableImage API — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml
- EditableMesh API — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableMesh.yaml
- AssetService API — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AssetService.yaml
- ImageCombineType enum — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/ImageCombineType.yaml
- ImageAlphaType enum — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/ImageAlphaType.yaml
- Avatar in-experience creation — https://github.com/Roblox/creator-docs/blob/main/content/en-us/avatar/in-experience-creation.md
- Parallel Luau / multithreading — https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/multithreading.md
- Rendered doc pages (for reference): https://create.roblox.com/docs/reference/engine/classes/EditableImage · https://create.roblox.com/docs/reference/engine/classes/AssetService · https://create.roblox.com/docs/avatar/in-experience-creation

**Open-source code read directly:**
- Roblox's own reference painting tool (ProjectionBrush, TextureUtils, ImageEditActions) — https://github.com/Roblox/avatar (`ReferenceBodyCreator/ReplicatedStorage/Modules/`)
- FastCanvas (buffer core; `--!native`, u32 packing, doubling-copy clear) — https://github.com/Ethanthegrand/FastCanvas
- CanvasDraw (graphics library built on FastCanvas) — https://github.com/Ethanthegrand/CanvasDraw
- OSGL — Open Source Graphical Library (fonts, flood fill, shapes, video) — https://github.com/osgl-rbx/osgl · docs: https://osgl-rbx.github.io/osgl/
- rodeo issue documenting the CaptureService→EditableImage refusal — https://github.com/revvy02/rodeo/issues/17
- Valve-style decal projection in Roblox (pre-`DrawImageProjected` approach) — https://github.com/sammygrey/Decal-Projection

**DevForum threads (content accessed via search summarization only — devforum.roblox.com was egress-blocked; all numbers second-hand):**
- A complete guide to EditableImages — https://devforum.roblox.com/t/a-complete-guide-to-editableimages/3858566
- Introducing in-experience Mesh & Image APIs [Studio Beta] — https://devforum.roblox.com/t/introducing-in-experience-mesh-image-apis-studio-beta/2725284
- [Studio Beta] Updates to In-experience Mesh & Image APIs (ReadPixelsBuffer/WritePixelsBuffer) — https://devforum.roblox.com/t/studio-beta-updates-to-in-experience-mesh-image-apis/3172217
- [Client Beta] In-experience Mesh & Image APIs now available in published experiences — https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293
- [Update] Projecting decals to EditableMesh! (`DrawImageProjected`) — https://devforum.roblox.com/t/update-projecting-decals-to-editablemesh/3386639
- EditableMesh and EditableImage Improvements — https://devforum.roblox.com/t/editablemesh-and-editableimage-improvements/3818624
- In-Experience Build-a-Texture: EditableImage Support for SurfaceAppearance — https://devforum.roblox.com/t/in-experience-build-a-texture-editableimage-support-for-surfaceappearance/3866947
- [Studio Beta] EditableMesh Batching APIs & Parallel Queries — https://devforum.roblox.com/t/studio-beta-editablemesh-batching-apis-parallel-queries/4779401
- RetroRaster — https://devforum.roblox.com/t/retroraster-the-real-time-raytracing-solution-for-pixelating-roblox/2954915 · devlogs https://ethanthegrand.itch.io/retroraster/devlog
- A renderer using raycasting (open source) — https://devforum.roblox.com/t/a-renderer-using-raycasting-open-source/3609143
- Fully Textured Real-Time 3D Raycaster Engine — https://devforum.roblox.com/t/fully-textured-real-time-3d-raycaster-engine-in-roblox/1907614
- Realtime Raytracer ran in parallel — https://devforum.roblox.com/t/realtime-raytracer-ran-in-parallel/3478308
- EditableImage Baked Lighting (Raytraced GI + Soft Shadows) — https://devforum.roblox.com/t/editableimage-baked-lighting-raytraced-global-illumination-soft-shadows/3191321
- Lightspeed Shader System using EditableImage — https://devforum.roblox.com/t/lightspeed-shader-system-using-editableimage/2762254
- RbxShader: A robust shader engine — https://devforum.roblox.com/t/rbxshader-a-robust-shader-engine-for-everyone/2965460
- [Open Source] Ro2D: 2D Software Rendering & Physics Engine — https://devforum.roblox.com/t/open-source-ro2d-a-high-performance-2d-software-rendering-physics-engine-editableimage/4634716
- OSGL — EditableImage graphics library — https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757
- CanvasDraw — https://devforum.roblox.com/t/canvasdraw-a-powerful-pixel-based-graphics-library-draw-pixels-lines-triangles-readmodify-image-data-and-much-more/1624633
- [EditableImage] PixelRasterizer — https://devforum.roblox.com/t/editableimage-pixelrasterizer-real-time-2d-pixel-grid-system-with-dynamic-lighting-editableimage-rendering/3881135
- Realtime minimap using EditableImage & Parallel Luau — https://devforum.roblox.com/t/realtime-minimap-using-editableimage-parallel-luau/2776543
- Use of EditableImage for efficiently painting on large surfaces globally using regular RayCasts — https://devforum.roblox.com/t/use-of-editableimage-for-efficiently-painting-on-large-surfaces-globally-using-regular-raycasts/3673162
- Creating a splat map of sorts (similar to Splatoon's paint map) — https://devforum.roblox.com/t/creating-a-splat-map-of-sortssimilar-to-splatoons-paint-map/2009601
- How to view UV of an EditableMesh and apply textures to individual faces — https://devforum.roblox.com/t/how-to-view-uv-of-an-editablemesh-and-apply-textures-to-individual-faces/3389242
- How to write to an EditableImage in parallel — https://devforum.roblox.com/t/how-to-write-to-an-editableimage-in-parallel/3638723
- Speeding up thousands of iterations (Image API) — https://devforum.roblox.com/t/speeding-up-thousands-of-iterations-image-api/2737792
- Image processing through a Kernel (Convolution) — https://devforum.roblox.com/t/image-processing-through-a-kernel-convolution/2814816
- EditableImage Image Blur Module — https://devforum.roblox.com/t/editableimage-image-blur-module/2828242
- Image blur in roblox! — https://devforum.roblox.com/t/image-blur-in-roblox/2825247
- Efficient EditableImage Rendering for Operating System Simulation — https://devforum.roblox.com/t/efficient-editableimage-rendering-for-operating-system-simulation/3129441
- Reducing Memory Consumption of EditableImage Once Static? — https://devforum.roblox.com/t/reducing-memory-consumption-of-editableimage-once-static/3639609
- Add a way to discard EditableImage buffer after it's no longer being edited — https://devforum.roblox.com/t/add-a-way-to-discard-editableimage-buffer-after-it%E2%80%99s-no-longer-being-edited/3639808
- EditableImage higher resolution and memory limit — https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575
- Failed to create empty EditableImage ... memory budget limits — https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799
- Remove Editable Mesh/Image limit on the client — https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561
- Allow EditableImage to efficiently use regions from a shared image atlas — https://devforum.roblox.com/t/allow-editableimage-to-efficiently-use-regions-from-a-shared-image-atlas/4631268
- Allow WritePixelsBuffer() to go up to 2048x2048 for plugins — https://devforum.roblox.com/t/allow-editableimagewritepixelsbuffer-to-go-up-to-2048x2048-for-plugins/4568767
- Possible to make EditableImages support CaptureService? — https://devforum.roblox.com/t/possible-to-make-editableimages-support-captureservice/3652078
- CaptureScreenshot to EditableImage / Image — https://devforum.roblox.com/t/capturescreenshot-to-editableimage-image/3629937
- EditableImage API and SurfaceAppearance Runtime Compatibility — https://devforum.roblox.com/t/editableimage-api-and-surfaceappearance-runtime-compatibility/4651983
- BitmapFontKit – Pixel-Perfect Bitmap Text Rendering — https://devforum.roblox.com/t/bitmapfontkit-%E2%80%93-pixel-perfect-bitmap-text-rendering-for-roblox-ui/3820973
- V1.0 DrawBoard | Share your canvas — https://devforum.roblox.com/t/v10-drawboard-share-your-canvas/2923128
- Fog of War Integration into a Minimap — https://devforum.roblox.com/t/fog-of-war-integration-into-a-minimap/2908907
- Graph Module – Easily draw graphs of your data (boatbomber) — https://devforum.roblox.com/t/graph-module-easily-draw-graphs-of-your-data/828982
- I cannot use EditableImages (boyned) — https://blog.boyned.com/articles/i-cannot-use-editable-images/ *(egress-blocked; listed for follow-up)*

**Background references:**
- Flood fill (scanline/span algorithm) — https://lodev.org/cgtutor/floodfill.html
- Bitmap font generation in games — https://kircode.com/en/post/bitmap-font-generation-in-games
- Fast real-time GPU-based image blur algorithms (Intel; box-blur/SAT background) — https://www.intel.com/content/www/us/en/developer/articles/technical/an-investigation-of-fast-real-time-gpu-based-image-blur-algorithms.html
