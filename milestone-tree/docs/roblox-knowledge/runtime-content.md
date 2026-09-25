# Runtime-generated content and heavy compute on Roblox (2025–2026)

This file covers EditableImage, EditableMesh, the `buffer` and `vector` libraries, native code generation, Parallel Luau,
and a cookbook of procedural and fractal techniques that run in Luau at a known cost. The last section is a list of
concrete ideas for The Milestone Tree NG+.

State of knowledge: **2026-09-25**. Tags on each claim:

| tag | meaning |
|---|---|
| **[API]** | Checked against the local API dump `scratchpad/tools/globalTypes.d.luau` (Sept 2026). |
| **[DOC]** | Official creator docs (`Roblox/creator-docs` main branch, fetched 2026-09-25). |
| **[ANN]** | An official Roblox DevForum announcement. The date is given. |
| **[COMM]** | A community DevForum post or thread. Treat it as field evidence, not a spec. |
| **[BENCH]** | Measured here with the Luau CLI (`luau -O2`, and `--codegen` for native) on a 2.8 GHz Xeon core. This is **not** the Roblox client. |
| **[EST]** | An estimate or an unverified claim. Test it in Studio **and** on a phone before relying on it. |

---

## 0. The 14 facts that shape every design decision

1. **The creator is gated, the players are not.** A published experience can use EditableImage and EditableMesh only
   when its owner (the group owner, for group games) is **13+ age-verified and ID-verified** and has turned on
   **Enable Mesh / Image APIs**. The docs now put that toggle in the Creator Dashboard. The 2024 announcements put it
   under Studio › Game Settings › Security › "Allow Mesh / Image APIs". Players need nothing. Studio works without the
   toggle. Facial or video age estimation alone does **not** unlock the APIs (a request thread was still open in
   Jan 2026). [DOC][ANN 2024-11-20][COMM]
2. **Max EditableImage size is 1024×1024.** `CreateEditableImage()` defaults to 512×512. The Size is read-only, so you
   resize by creating a new image. [DOC]
3. **Client memory budget: about 32 MB, shared by images and meshes.** When it runs out, the create calls **return
   `nil`** rather than throwing. The community measured the budget at about 32 MB, which is about 8 full-size 1024²
   RGBA images. Meshes draw from the same pool, which is about 480k vertices or 160k triangles, the size of 8 full
   meshes. Server, Studio and plugins are unlimited. [DOC][COMM 2025–2026]
4. **Only ONE displayed EditableImage is refreshed per frame.** If three displayed images change in the same frame,
   all three take three frames to show. You should therefore put every animated surface into **one atlas image**.
   [DOC]
5. **No replication.** An editable object made on the server shows up on clients as an unusable placeholder. Generate
   on the client. [ANN][COMM]
6. **Native code generation (`--!native`) does not run on the Roblox client** (except possibly Android, see §4.3).
   Client per-pixel code therefore runs in the **interpreter**, which is 2–10× slower than the native numbers people
   quote. **Studio play-solo runs native**, so Studio flatters you. One author measured 130–150 fps in Studio against
   60 fps on the client (Jan 2026). [DOC][COMM]
7. **`WritePixelsBuffer` and every `Draw*` call are thread-Unsafe.** `ReadPixelsBuffer` is Safe. Do the math in
   parallel, then call `task.synchronize()`, then write. [DOC]
8. **Pixel format is RGBA8, top-left origin, and the `buffer` is little-endian.** One u32 is therefore
   `r + g*0x100 + b*0x10000 + a*0x1000000`. A written hex literal reads `0xAABBGGRR`, not `0xRRGGBBAA` as one
   community guide says. [DOC][BENCH verified byte order]
9. **Engine draw calls are C++.** A full-image fade (`DrawRectangle` with a transparency), a resample
   (`DrawImageTransformed`) or an additive composite (`ImageCombineType.Add`) costs about nothing next to a Luau loop
   over the same pixels. Use them instead of per-pixel Luau wherever possible. [DOC][EST for exact cost]
10. **`math.noise` is the fastest noise in the interpreter.** It ran at 17k calls/ms, about 2.8× faster than a
    hand-written value noise. Arithmetic packing is about 3× faster than `bit32` packing. [BENCH]
11. **Low-frequency content can be tiny.** Nebulae, glows and auras rendered at 128–256² and stretched with bilinear
    `ResampleMode.Default` look the same as full-resolution ones. Keep crisp lines and text in vector UI (Path2D,
    TextLabel). [EST, standard graphics practice]
12. **EditableMesh limits: 60,000 vertices and 20,000 triangles per mesh.** Quads count as 2 triangles. Batch APIs
    (`BatchAdd`, `BatchSetValues`…) reached full release on 2026-09-15 and are about 8× faster than per-call loops.
    Query methods are now safe to call in parallel. [DOC][ANN 2026-09-15]
13. **Collision is rebuilt only by `CreateMeshPartAsync` or `ApplyMesh`.** Visual vertex edits show up immediately.
    [DOC]
14. **Runtime SurfaceAppearance textures are heavy.** `AssetService:CreateSurfaceAppearanceAsync` (published since
    2026-01-26) takes EditableImage maps, but it builds no mipmaps and applies no compression. The announcement says
    that makes them up to 12× heavier on the GPU than Studio-authored textures. [ANN]

---

## 1. Access, policy and a safe capability probe

| question | answer | tag |
|---|---|---|
| Who must be verified? | The experience owner (for a group game, the group owner): 13+ and ID-verified, plus the toggle. | DOC, ANN |
| Do players need anything? | No. | ANN |
| Studio without verification? | Yes: edit mode, play-solo and plugins all work. Only published experiences are gated. | ANN |
| Failure mode when the toggle is off | Calls throw ("…is not accessible. Go to the Security Tab in Game Settings to enable this API."). | COMM thread title |
| Failure mode when the budget is exhausted | `CreateEditableImage` / `CreateEditableMesh` / `*Async` return `nil`. | DOC |
| Loading existing assets | `CreateEditableImageAsync` / `CreateEditableMeshAsync` load an asset only if the experience owner, the Studio user, the local player (client side) or a group they can edit through owns it or has it shared. Otherwise they throw. **`rbxthumb://` URIs are allowed**, so avatar headshots can become EditableImages. | DOC |
| Screenshots into EditableImage | Blocked (CaptureService content cannot be loaded). | COMM (boyned blog) |
| Publishing user art | `AssetService:PromptCreatePlatformContentAsync` publishes an EditableImage as a new asset. | DOC |

Capability probe (add to `Theme.caps`, the same pattern as UIShadow and Path2D):

```lua
local AssetService = game:GetService("AssetService")

local function probeEditable(): boolean
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(4, 4) })
	end)
	if ok and img then
		img:Destroy()
		return true
	end
	return false -- toggle off / unverified owner / budget gone → use baked PNG fallbacks
end
```

Always treat a later `nil` from a create call as possible too. The budget is dynamic per device.

---

## 2. EditableImage

### 2.1 Creation [API][DOC]

| call | notes |
|---|---|
| `AssetService:CreateEditableImage(options?)` | `options.Size: Vector2`, default 512×512, max 1024×1024. Returns `nil` over budget. Not yielding. |
| `AssetService:CreateEditableImageAsync(content: Content, options?)` | Yields. `Content.fromUri("rbxassetid://…")`, `Content.fromAssetId(id)`, `rbxthumb://…`, or `Content.fromObject(otherEditableImage)` to clone. No options are supported yet. |
| `AssetService:CreateEditableImageFromDownloadAsync(url)` | **[API] only.** It is undocumented and probably restricted. Do not plan on it. |
| `EditableImage:Destroy()` | Frees the memory immediately. Do it for every image you stop showing. |

`EditableImage` inherits from **`Object`, not `Instance`**. It has no Parent, and one image can be referenced by many
properties at once ("multi-referencing"). [ANN 2024-10]

### 2.2 Displaying it: `Content.fromObject(img)` [API][DOC][COMM]

| property | EditableImage works? | notes |
|---|---|---|
| `ImageLabel.ImageContent`, `ImageButton.ImageContent` (+Hover/Pressed) | **Yes** | This is the main path for UI. `ResampleMode` is `Default` (bilinear) or `Pixelated`. `ScaleType`, `SliceCenter`, `TileSize`, `ImageRectOffset`/`ImageRectSize` and `ImageColor3`/`ImageTransparency` all apply. [EST: ImageRect and 9-slice on editable content should behave as on assets; verify.] |
| `MeshPart.TextureContent` | **Yes** | Its UVs come from the mesh. |
| `Decal.ColorMapContent` (+ Normal/Metalness/Roughness/EmissiveMask) | Yes | Script-writable. Or use `AssetService:CreateDecalAsync({TextureContent=…, NormalMapContent=…})`, which accepts **only** EditableImage content. `ComposeDecalAsync` layers up to 8 PBR sets, but those are asset IDs. |
| `SurfaceAppearance.*MapContent` | Only through `AssetService:CreateSurfaceAppearanceAsync({ColorMap, NormalMap, MetalnessMap, RoughnessMap, EmissiveMask})` | Direct property writes are **PluginSecurity**. The maps cannot be swapped after creation. There are no mipmaps and no compression (up to 12× the GPU memory). EmissiveMask is listed in the current docs but was not in the Aug-2025 announcement, so verify it. |
| `ImageHandleAdornment.ImageContent` | Probably | [EST] |
| `Sky.Skybox*Content`, `SunTextureContent`, `MoonTextureContent` | **No** | A bug report says it renders nothing or reverts to the default. [COMM] |
| `ParticleEmitter`/`Beam`/`Trail.TextureContent` | Not documented | The docs mention asset URIs only. [EST: assume no] |
| `ViewportFrame` contents | Unknown | [EST] |

Multi-reference trick: **one** EditableImage drives many ImageLabels, each showing a different
`ImageRectOffset`/`ImageRectSize` window. This is the atlas that works around the one-update-per-frame rule (§2.6).

### 2.3 Pixel I/O [API][DOC][BENCH]

```lua
img:WritePixelsBuffer(position: Vector2, size: Vector2, buf: buffer)  -- #buf must be size.X*size.Y*4
local b = img:ReadPixelsBuffer(position: Vector2, size: Vector2)       -- returns a new buffer (Safe in parallel)
```

* Bytes are R, G, B, A with alpha 255 meaning opaque. The origin (0,0) is top-left.
* Sub-rectangles are allowed. Write **only the dirty rows or tile**. `buffer.copy` of a 512×32 strip took 1.7 µs [BENCH],
  so slicing a strip out of a full-frame buffer costs nothing.
* Packing: `local px = r + g*0x100 + b*0x10000 + a*0x1000000` then `buffer.writeu32(buf, i*4, px)`. That is one call
  instead of four, **2.4× faster** than 4× `writeu8` when interpreted, and it beats `bit32.bor/lshift` by about 3×
  [BENCH].
* `ReadPixels`/`WritePixels` (tables of floats) were **removed** in the Oct-2024 overhaul. Old tutorials using them are
  stale. [ANN]

### 2.4 Draw methods (all in C++, all **Unsafe** in parallel) [API][DOC]

| method | signature (API dump) | notes |
|---|---|---|
| `DrawRectangle` | `(position, size, color: Color3, transparency, combineType)` | Full-image fade: draw black with transparency 0.85–0.95 once per frame to make **trails**. |
| `DrawCircle` | `(center, radius, color, transparency, combineType, antiAliasing?)` | AA is on by default. Good for soft stamps and particles. |
| `DrawLine` | `(p1, p2, color, transparency, combineType, antiAliasing?)` | **It has no thickness.** For thick or glowing strokes, stamp circles or a brush image. |
| `DrawTriangle` | `(p1, p2, p3, color, transparency)` | **[API] only, not in the docs.** It may be new or unreleased. Verify before use. |
| `DrawImage` | `(position, image: EditableImage, combineType)` | Blit. |
| `DrawImageTransformed` | `(position, scale: Vector2, rotation (deg), image, options?)` | `options = {CombineType = Enum.ImageCombineType.AlphaBlend, SamplingMode = Enum.ResamplerMode.Default\|Pixelated, PivotPoint = Vector2}`. This is the resize, rotate and crop tool (crop = PivotPoint offset into a smaller destination). |
| `DrawImageProjected` | `(mesh: EditableMesh, projection {Direction, Position, Size, Up: Vector3}, brush {AlphaBlendType, ColorBlendType, Decal: EditableImage, FadeAngle 0–90, BlendIntensity 0–1})` | Projects a decal into a mesh's texture through its UVs ("paint on a 3D object"). |
| `SampleImageProjected` | `(mesh, sourceTexture: EditableImage, projectionConfig, brushConfig)` | The inverse: reads the mesh texture back into a flat image. It uses the closest surface that faces the projector. |

### 2.5 Blend and sampling enums [API][DOC]

* `Enum.ImageCombineType`:
  * `AlphaBlend` (the default; the destination colour affects the result);
  * `BlendSourceOver`;
  * `Overwrite`;
  * **`Add`** (source RGB is scaled by source alpha, and the alphas add);
  * `Multiply`;
  * **`Subtract`**;
  * `NormalMapBlend` (alpha-blends, then renormalises RGB as a tangent-space normal).
* `Enum.ImageAlphaType`: `Default`, `LockCanvasAlpha`, `LockCanvasColor`. These apply to the projected brush.
* `Enum.AntiAliasing`: `Enabled` / `Disabled`.
* `Enum.ResamplerMode`: `Default` (bilinear) / `Pixelated` (nearest). It is used for `ImageLabel.ResampleMode` and
  for `DrawImageTransformed`.

**`Add` is the neon workhorse.** Additive stamping of soft dots gives the hot-core, cool-halo look of light, and the
engine does it.

### 2.6 Limits and gotchas

| limit | value | tag |
|---|---|---|
| Max size | 1024×1024. Plugins can create 2048² but cannot Read/WritePixelsBuffer above 1024². | DOC, COMM |
| Client budget | About 32 MB of editables, shared with meshes. `nil` on exhaustion. It is dynamic per device, so a low-end phone may get less. | COMM, DOC |
| Memory per image | W×H×4 bytes: 256² = 256 KB, 512² = 1 MB, 1024² = 4 MB. A static image still costs its full size, since there is no "freeze/compress". | COMM |
| Display refresh | **1 displayed image updated per frame.** More images mean more frames of latency. | DOC |
| Replication | None. | ANN |
| Mipmaps | None, so a large image drawn small shimmers. Keep the source near its on-screen size or pre-blur it. | EST |
| Old Android GLES2 | About 2% of devices may not render editables correctly (client-beta notes). | ANN 2024 |

---

## 3. EditableMesh

### 3.1 Creation, display and limits [API][DOC]

```lua
local mesh = AssetService:CreateEditableMesh()                                -- empty, never FixedSize; nil over budget
local fromAsset = AssetService:CreateEditableMeshAsync(Content.fromAssetId(id)) -- FixedSize = true by default
local editable = AssetService:CreateEditableMeshAsync(Content.fromAssetId(id), { FixedSize = false })
local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
	CollisionFidelity = Enum.CollisionFidelity.Box,   -- also RenderFidelity, FluidFidelity
})                                                    -- yields; throws on failure → pcall
existingPart:ApplyMesh(part)                          -- re-links an existing MeshPart and rebuilds collision
```

* The limits are **60,000 vertices and 20,000 triangles**. Exceeding them throws. `FixedSize` meshes (from assets)
  cannot add or remove elements but use less memory.
* The model uses stable IDs, with **per-face-corner** normals, UVs and colours. A shared vertex can carry split
  attributes (hard edges, UV seams). Always iterate over `GetVertices()` and `GetFaces()`, because IDs have holes.
* Vertex colours come from `AddColor(color, alpha)`. Transparent vertex colours need the MeshPart itself to be
  partially transparent (client-beta notes).
* `MeshPart.TextureContent = Content.fromObject(editableImage)` gives a runtime texture on runtime geometry.

### 3.2 2026 upgrades [ANN]

| date | change |
|---|---|
| 2025-07-16 | Clone through `CreateEditableMeshAsync(Content.fromObject(mesh))`. Added the vertex-face getters and setters (`Get/SetVertexFaceColor/Normal/UV`), `GetFacesWith*`, `GetVerticesWith*` and `GetVertexColors/Normals/UVs/Faces`. Fixed occlusion culling of EditableMesh-backed parts. |
| 2025 (Studio beta) | Skinning (`AddBone`, `SetVertexBones`, `SetVertexBoneWeights`) and FACS poses. |
| **2026-09-15 full release** | Batch APIs: `BatchAdd(Enum.MeshAttribute.X, data[, alphas])`, `BatchSetValues(ids, values)`, `BatchGetValues`, `BatchRemove`, `BatchSetFaceAttributes`, `BatchSetVertexFaceAttributes`, `BatchGet*Attributes` and `Clear()`. They are **about 8× faster** than singular calls in loops. **All query methods are parallel-safe** (about 2× read throughput). Mutators stay serial. Skinned meshes are not batched or parallel. |
| 2026-09-23 Studio beta | **Quads**: `AddFace({v1, v2, v3, v4})`, with a smart diagonal in `Triangulate()`. Each quad counts as 2 triangles. |

`BatchAdd` data formats:

* Vertex and Normal take `{Vector3}`.
* UV takes `{Vector2}`.
* Color takes `{Color3}` plus `{number}` alphas.
* Face takes `{{v, v, v}, …}`.

`BatchSetValues(normalIds, nil)` resets normals to auto-computed. [DOC]

### 3.3 Per-frame animation: what the field reports

* Ocean with 6 Gerstner waves on tiled meshes, frustum and distance culling: **about 2 ms/frame client-side on a
  Ryzen 5 7520U**. Vertex colours added 2–4 ms. That was before batch APIs existed. [COMM]
* Another ocean with 12 Gerstner waves: about 2 ms. Others lerp far vertices instead of updating them every frame.
  [COMM]
* Rule of thumb [EST]:
  * budget a few thousand `SetPosition` calls per ms in the interpreter;
  * use `BatchSetValues` (a Luau array build plus one C++ call) for anything above about 500 vertices;
  * update normals only every few frames, or let them auto-compute.

### 3.4 Known issues [ANN 2024][COMM]

* Flat axis-aligned planes can render wrong.
* Frustum-culling glitches were reported early (occlusion culling was fixed in Jul 2025).
* `Texture` instances don't work on EditableMesh parts.
* [EST] The bounds and `MeshSize` of the part are computed at `CreateMeshPartAsync`. For "growing" geometry, create
  the part with the vertices at their **final** extents and animate them from there, or rebuild with `ApplyMesh` when
  the bounds change. Verify this.

---

## 4. The compute stack

### 4.1 `buffer` [BENCH][DOC]

The library covers:

* `create`, `fromstring`, `tostring`, `len`, `copy`, `fill`;
* `read`/`write` for `i8`/`u8`/`i16`/`u16`/`i32`/`u32`/`f32`/`f64`;
* `readstring`/`writestring`;
* `readbits`/`writebits`.

(The CLI build also has `readinteger`/`writeinteger`, which may not be on Roblox yet.) Buffers are fixed-size,
little-endian and bounds-checked. Buffer calls are **fastcall builtins**: a local alias
(`local wu32 = buffer.writeu32`) and a direct call ran at the same speed.

| op (256² = 65,536 px) | interpreter | native |
|---|---|---|
| Fill with `writeu32`, flat loop | 0.84 ms (78k px/ms) | 0.21 ms |
| Fill with `writeu32`, 2-D loop and index math | 1.61 ms (41k px/ms) | 0.22 ms |
| Fill with 4× `writeu8` | 3.86 ms (17k px/ms) | 0.22 ms |
| Same data into a Lua table (the old WritePixels style) | 2.59 ms | 0.56 ms |
| `buffer.fill` / `buffer.copy` 256 KB | ~0 / 6 µs | same |

Use `f32` buffers for simulation state (reaction-diffusion, flame histograms), `u8` fields for palette-cycled scalar
fields, and RGBA `u32` for output.

### 4.2 `vector` [BENCH][EST]

The Luau `vector` library has `create`, `magnitude`, `normalize`, `dot`, `cross`, `floor`, `ceil`, `abs`, `sign`,
`clamp`, `min`, `max`, `angle`, `lerp`, `zero` and `one`. The value type is unboxed, so there is no heap allocation.
In Roblox, `Vector3` is built on this type [EST: confirm with `typeof(vector.create(1,2,3))`]. `Vector2` and `Color3`
are **userdata allocations**, so never create them per pixel. A table per pixel cost 2.8 ms per 256² [BENCH].

Raymarching with vectors ran within about 10% of scalar code in both modes. Use vectors for readability in 3-D code
and scalars in hot 2-D loops.

### 4.3 Native code generation: where it runs

| context | native? | tag |
|---|---|---|
| Server `Script` with `--!native` or `@native` | **Yes** (x64 and ARM64) | DOC |
| Studio (including LocalScripts in play-solo) | **Yes**, which makes Studio benchmarks misleading | COMM |
| **Roblox client (desktop, iOS, console)** | **No.** The docs say "server-side scripts" and the FAQ says "looking into more platforms". | DOC, ANN |
| Android client | On the roadmap as "native Android code generation", slipped to mid/late 2026. A 2026-09-03 forum post claims it is enabled on Android. | secondary (roadmap summary), COMM, unconfirmed |

Consequences:

1. Design every client effect around the **interpreter column** below.
2. Measure client cost in Studio by removing `--!native` (or with the CLI `luau -O2`), then on a real phone with the
   MicroProfiler.
3. Keeping `--!native` in client modules is harmless and future-proof. Type-annotate hot functions (`: number`,
   `: buffer`, `: vector`), because native code specialises on annotations while the interpreter ignores them.
4. Native limits: 64K instructions per block, 32K blocks per function, 1M instructions per script, plus a global
   native-memory cap. [DOC]

### 4.4 Parallel Luau for pixels [API][DOC][COMM]

The model:

* Scripts under different **`Actor`s** run on worker threads during the parallel phase.
* `task.desynchronize()` or `RBXScriptSignal:ConnectParallel(fn)` / `Actor:BindToMessageParallel(topic, fn)` enter
  that phase. `task.synchronize()` returns to serial.
* `require()` is not allowed while desynchronized.
* `Actor:SendMessage` arguments are **copied** and functions cannot be sent. Send small per-frame parameters, not
  buffers.
* `SharedTable` values may be boolean, number, vector, string, SharedTable or "serializable data types". Buffers are
  not listed, so don't plan on sharing a pixel buffer that way.

Thread safety that matters here:

| member | safety |
|---|---|
| `EditableImage.Size` | ReadSafe |
| `EditableImage:ReadPixelsBuffer` | Safe |
| `EditableImage:WritePixelsBuffer`, all `Draw*` | **Unsafe** (serial only) |
| `AssetService:CreateEditable*` | Unsafe |
| EditableMesh query methods (`Get*`, `BatchGet*`, `RaycastLocal`, `FindClosest*`) | Safe (since 2026-09) |
| EditableMesh mutators (`Add*`, `Set*`, `Batch{Add,Set,Remove}`) | Unsafe |

The pattern that works (community guide, Jul 2025): **horizontal strips**. Each worker Actor owns rows `[y0, y0+n)`
and a private strip buffer. Every frame it computes in parallel, then synchronizes and writes its own sub-rect.
Everything goes into **one** EditableImage, which keeps you inside the one-image-per-frame rule.

```lua
-- Worker: a Script with RunContext = Client (or a LocalScript in PlayerScripts), cloned into each Actor
local actor = script:GetActor()
local img: EditableImage?, W, y0, rows, strip
actor:BindToMessage("Init", function(image, w, startY, nRows)
	img, W, y0, rows = image, w, startY, nRows
	strip = buffer.create(w * nRows * 4)
end)
actor:BindToMessageParallel("Frame", function(t: number)
	if not strip then return end
	for y = 0, rows - 1 do
		local row = y * W
		for x = 0, W - 1 do
			-- pure math only in here; no Instance writes, no Draw*
			local c = math.floor((math.sin(x * 0.07 + t) * 0.5 + 0.5) * 255)
			buffer.writeu32(strip, (row + x) * 4, c + 60 * 0x100 + 255 * 0x10000 + 0xFF000000)
		end
	end
	task.synchronize()
	local image = img :: EditableImage -- avoid a line starting with "(" (Luau ambiguous-call error)
	image:WritePixelsBuffer(Vector2.new(0, y0), Vector2.new(W, rows), strip)
end)
```

Caveats:

* A 2024 author said that after the Object refactor "there is no way to share the image across multiple actors". The
  2025 guide passes the EditableImage straight through `SendMessage` and writes it from each worker. Re-verify on the
  current client. [COMM]
* Wait for the workers to bind before sending `Init`, using an attribute or a ready message back. [EST]
* More actors is not always faster. Clamp workers to the row count and tune per device. [COMM]
* Field result: a 64×64 raycast minimap refreshed every frame at 60 fps with 8 threads cost about 6 ms total and was
  raycast-bound. [COMM]
* Mobile has 4–8 cores, but LITTLE cores are slow. Expect about 2–3× speed-up, not 8×. [EST]

### 4.5 Micro-benchmarks [BENCH]

Setup: 2.8 GHz Xeon core, `luau -O2` (interpreter, which approximates the Roblox client) and `luau -O2 --codegen`
(native, which approximates the server and Studio). A 2024–2025 mid-range phone is **roughly 2–4× slower** than the
interpreter column [EST]. The scripts are in the session scratchpad (`bench/*.luau`) and are easy to re-run.

| kernel (output to RGBA u32 buffer) | size | interp ms | interp px/ms | native ms |
|---|---|---|---|---|
| Palette-cycle remap (u8 field → LUT → RGBA) | 128² / 256² | 0.59 / 2.40 | 27.8k | 0.12 / 0.46 |
| Plasma, 4× `sin` + palette LUT | 64² / 128² / 256² | 0.59 / 2.32 / 9.80 | 6.9k | 0.22 / 0.91 / 3.58 |
| Interlaced plasma, ¼ of 128² | 4,096 px | 0.57 | 7.2k | 0.24 |
| `math.noise`, 1 call per px | 256² | 3.8 | 17k | 3.1 |
| Hand-written value noise (hoisted, inlined hash) | 256² | 10.7 | 6.1k | 2.4 |
| fBm, 5 octaves of `math.noise` | 256² | 25.4 | 2.6k | 17.6 |
| Domain-warped fBm (3 × fBm5 = 15 noise calls) | 256² | 79.8 | 821 | 71.0 |
| Mandelbrot, smooth colour, maxIter 64 | 256² | 46.2 | 1.4k | 13.2 |
| Mandelbrot, smooth colour, maxIter 256 | 256² | 114.7 | 571 | 28.8 |
| Raw escape-time iterations | 10 M iter | 224 | **45k iter/ms** | 67 (150k/ms) |
| Voronoi F1/F2 (3×3 cells, hashed) | 256² | 64.3 | 1.0k | 12.3 |
| Metaballs, 8 balls | 256² | 29.7 | 2.2k | 4.2 |
| SDF raymarch, 64 steps + 6-tap normal | 128² / 256² | 36.5 / 151 | 450 | 13.2 / 53 |
| Separable box blur r = 4, RGBA, 2 passes | 256² | 29.3 | 2.2k | 4.5 |
| Gray-Scott reaction-diffusion, 1 step (f32) | 128² | 2.59 | 6.3k | 0.23 |
| Chaos game / flame, 4 maps + colour | 500k pts | 69.6 | **7.2k pts/ms** | 17.2 |
| Flame tone-map (log density + gamma + LUT) | 256² | 2.28 | 28.7k | 0.56 |
| Curl-noise advection (4 `math.noise` each) | 5,000 particles | 1.33 | 3.8k p/ms | 1.05 |
| L-system expand, 5 generations (`gsub`) | 88,940 chars | 0.28 | — | 0.28 |
| L-system turtle → segment list | 88,940 chars | 8.4 | — | 5.1 |
| Bloom: threshold + 4×4 downsample 256→64 | 256² | 5.7 | 11.6k | 0.58 |
| Bloom: 2-pass blur r = 3 at 64² | 64² | 4.0 | 1.0k | 0.51 |
| Bloom: bilinear upsample + add (**do this in the engine instead**) | 256² | 19.6 | 3.3k | 1.8 |
| Packing 1M px: arithmetic vs `bit32` | 1 M | 24 vs 70 | — | — |

Takeaways:

* Native helps pure arithmetic 3–13× (buffer fills, blur, reaction-diffusion) but barely helps `math.noise`-bound
  work, which is already C.
* In the **interpreter**, lean on C builtins (`math.noise`, `buffer.copy`, Draw calls) and look-up tables.
* Palette cycling is 20–40× cheaper than recomputing a field.

### 4.6 Per-frame budget calculator (client, interpreter)

Frame = 16.7 ms at 60 fps. The Milestone Tree already spends it on UI layout and rendering, so give procedural work a
**2 ms slice on desktop and 1 ms on phones**. Read it with `os.clock()` and shrink the slice if the frame time rises.
The mobile columns below are ÷6: half the slice at a third of the speed [EST].

| kernel | desktop px/frame (2 ms) | ≈ square | phone px/frame (1 ms) | ≈ square | 256² finished in (desktop / phone) |
|---|---|---|---|---|---|
| Palette-cycle remap | 55k | 236² | 9.3k | 96² | 1 frame / 7 frames |
| Plasma-class shader (4 trig) | 14k | 117² | 2.3k | 48² | 5 / 28 frames |
| Reaction-diffusion step | 12.6k | 112² | 2.1k | 46² | — |
| fBm5 nebula | 5.2k | 72² | 870 | 29² | 13 frames (0.2 s) / 75 (1.3 s) |
| Domain-warped nebula | 1.6k | 40² | 270 | 16² | 40 frames (0.7 s) / 240 (4 s) |
| Mandelbrot (≈64 iter) | 2.8k | 53² | 470 | 22² | 23 frames / 140 frames |
| Voronoi crystal | 2.0k | 45² | 340 | 18² | 33 / 190 frames |
| SDF raymarch (64 steps) | 900 | 30² | 150 | 12² | 73 frames (1.2 s) / 440 (7 s) |
| Flame points | 14k pts | — | 2.4k pts | — | 1 M pts in 70 frames / 420 frames |

**The main lesson:** on the client, an expensive field is something you *compute once, progressively*, then
*animate cheaply* (palette cycling, UV drift, parallax, UIGradient, rotation). Real-time per-frame shading is limited
to about 48–117² of cheap maths, stretched with bilinear filtering.

---

## 5. Progressive and incremental rendering strategies

1. **Time-sliced row or tile scheduler** (the core loop). Shade rows until `os.clock()` passes the slice, then
   `WritePixelsBuffer` **only those rows**.

```lua
--!strict
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local W, H = 256, 256
local img = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) }) -- after a pcall'd caps probe
local frame = buffer.create(W * H * 4)
local nextRow, SLICE = 0, 0.002          -- seconds; 0.001 on LOW tier

local function shadeRow(y: number)
	local row = y * W
	for x = 0, W - 1 do
		local r, g, b = x, y, 160 -- replace with the generator (integers 0..255)
		buffer.writeu32(frame, (row + x) * 4, r + g * 0x100 + b * 0x10000 + 0xFF000000)
	end
end

RunService.Heartbeat:Connect(function()
	if not img or nextRow >= H then return end
	local y0, t0 = nextRow, os.clock()
	repeat shadeRow(nextRow); nextRow += 1 until nextRow >= H or os.clock() - t0 > SLICE
	local n = nextRow - y0
	-- WritePixelsBuffer wants exactly W*n*4 bytes; pool these by n in production (or use fixed-height tiles)
	local exact = buffer.create(W * n * 4)
	buffer.copy(exact, 0, frame, y0 * W * 4, W * n * 4)
	img:WritePixelsBuffer(Vector2.new(0, y0), Vector2.new(W, n), exact)
end)
```

2. **Coarse-to-fine refinement** (Adam7-like). Pass 1 shades one pixel per 8×8 block and fills the block with
   `DrawRectangle` or a buffer fill. Passes 2–4 halve the block size. The picture exists after about 1/64 of the work
   and then sharpens, which reads as intentional ("the realm resolves").
3. **Interlacing.** Render every k-th row and column per frame with a rotating phase (RbxShader's
   `DualAxisInterlacing`). You get the full animation rate at 1/4 of the cost, with slight shimmer.
4. **Temporal accumulation.** Chaos-game flames, DLA crystals and path-traced gems keep adding samples into f32 or u32
   histograms across frames. Re-tone-map every N frames. The image "develops" like a photograph.
5. **Low-res plus GPU upscale.** Render at 64–256² and set `ImageLabel.ResampleMode = Default` (bilinear) at full
   size. For crisp pixel art use `Pixelated`. Up-scaling is free on the GPU. Never up-sample in Luau (19.6 ms/256²
   [BENCH]).
6. **Compute once, animate cheap.** Store a u8 scalar field (iteration count, warp value, Voronoi distance). Animate
   by:
   * rotating a 256-entry palette LUT (0.6 ms per 128², interpreted);
   * panning `ImageRectOffset`;
   * layering two copies at different scales and speeds;
   * tweening `ImageColor3`/`ImageTransparency`;
   * a `UIGradient` overlay.
7. **Engine-side passes.**
   * Fades use `DrawRectangle` with a transparency.
   * Downsample and upsample use `DrawImageTransformed` with `scale`.
   * Glow composites use `CombineType = Add`.
   * Masks use `Multiply`.
   * Trails come from never clearing, only fading.
8. **Atlas plus one-update-per-frame scheduler.** Put every animated surface in one 1024² (or 1024×512) atlas and
   show windows of it with `ImageRectOffset`/`Size`. A central scheduler decides which image, if any, is written each
   frame. Static images are written once.
9. **Bake-vs-runtime rule.**
   * If every player sees the same picture, **bake it offline** and upload a PNG. That gives full resolution,
     compression and mipmaps, and needs no ID gate.
   * Use runtime generation only when it is *per-player* (seeded by save or progress), *animated* or *interactive*.
   * The same Luau generator runs in the local CLI, so offline fallbacks can match the runtime look.
10. **Server-side compute (niche).** The server is native and has no editable budget.
    * Compute on the server, `EncodingService:CompressBuffer(buf, Enum.CompressionAlgorithm.Zstd)`, send the buffer
      over a RemoteEvent, then `WritePixelsBuffer` on the client. [API][DOC]
    * This suits one-off rewards for weak phones. It does not suit per-frame content, because remotes are sized for
      KB/s. [EST]

---

## 6. Technique cookbook

Costs below are client interpreter figures (§4.5).

### 6.1 Escape-time fractals: Mandelbrot, Julia, Burning Ship

* Iteration: `z = z² + c`.
  * Mandelbrot: `z0 = 0` and `c = pixel`.
  * Julia: `z0 = pixel` and `c` is constant. Animate it with `c = 0.7885·e^{iθ}`.
  * Burning Ship: `z = (|Re z| + i|Im z|)² + c`.
* **Smooth colouring:** with bailout `|z|² > 256`, `μ = n + 1 − log2(log|z|)` gives continuous bands. Index a cosine
  palette LUT (Inigo Quilez's `a + b·cos(2π(c·t + d))`) with `μ·k`.
* **Orbit traps** give the neon-filament look. Track `min(dist(z, trap))` over the orbit, where the trap is a point, a
  line (`|Im z|`), a circle (`||z| − r|`) or a cross. Colour is `exp(−k·minDist)`. On black this makes glowing
  threads, which suit the cosmic neon style.
* **Distance estimation** gives razor-thin crisp edges. Carry `dz = 2·z·dz + 1`, then `DE = |z|·log|z| / |dz|`, and
  shade `clamp(DE/pixelSize)`. It costs about 1.5× the plain iteration.
* **Speed-ups** (interior points are the costliest, since they run maxIter):
  * cardioid test `q = (x−¼)² + y²; q(q + x − ¼) ≤ y²/4`;
  * period-2 bulb `(x+1)² + y² ≤ 1/16`;
  * periodicity check every 20 iterations;
  * keep maxIter at 48–96 for UI art.
* **Budget:** 45k iterations/ms. A 128² Julia averaging 30 iterations is about 11 ms. Animated Julia is therefore
  about 96² with ¼ interlacing (~1.5 ms/frame desktop). A static 256² piece takes about 25 frames.
* **Infinite-zoom illusion:** pre-render 3–4 zoom levels into atlas regions. Cross-fade and scale ImageLabels on the
  GPU while the next level renders.

```lua
-- inner loop, scalars only; LUT is a 256-entry u32 palette buffer
local zr, zi, n, trap = 0.0, 0.0, 0, 1e9
while n < MAXI do
	local zr2, zi2 = zr * zr, zi * zi
	if zr2 + zi2 > 256 then break end
	zi = 2 * zr * zi + ci
	zr = zr2 - zi2 + cr
	local d = math.abs(zi) -- line trap on the real axis
	if d < trap then trap = d end
	n += 1
end
local mu = n < MAXI and (n + 1 - math.log(math.log(zr*zr + zi*zi) * 0.5) / 0.6931) or 0
local glow = math.exp(-12 * trap)
```

### 6.2 IFS and fractal flames (the "Electric Sheep" look)

* The chaos game: pick a random affine map `(a..f)` by weight, then apply a **variation** to it:
  * linear;
  * sinusoidal `(sin x, sin y)`;
  * spherical `p/r²`;
  * swirl `(x sin r² − y cos r², x cos r² + y sin r²)`;
  * horseshoe;
  * julia (√ with random branch).
* Blend a colour coordinate `c = (c + c_map)/2` and accumulate hits in a histogram.
* Tone-map with **log density** `α = (log(1+hits)/log(1+max))^(1/γ)` and colour = LUT(avg c)·α. Log density is what
  gives flames their silky gradients.
* Budget: 7.2k points/ms. A good 256² flame needs 1–5 M points, which is 70–350 frames at 2 ms. **Accumulate across
  frames** and re-tone-map every 15 frames (2.3 ms each). Show it developing.
* Symmetry (add rotated copies of each point) multiplies density for free. Seeding by player or layer gives unique art.

### 6.3 L-systems and space colonisation (literal skill-tree growth)

* **L-system:** axiom plus rules, for example `F → FF+[+F−F−F]−[−F+F+F]` at 22.5°. Expansion is almost free (0.28 ms
  for 89k symbols). A turtle turns the string into segments (8 ms for 89k; a UI tree needs a few thousand).
  Stochastic rules seeded by UserId make the tree unique. Give each segment a **birth time** equal to its depth or
  string index, then reveal segments progressively to animate growth.
* **Space colonisation** (Runions et al.) fits a tree that should reach **specific points**:
  * scatter attractors, for example the unlocked node positions plus jitter;
  * each iteration, every attractor pulls its nearest branch tip within a radius;
  * tips grow one step toward the average pull;
  * remove attractors once they are reached.
  Result: organic branches that genuinely grow *to* the milestones, not only along pre-drawn edges. With 200
  attractors and 2k segments this costs a few ms per iteration and runs once per unlock.
* **Rendering options:**
  * (a) Crisp vector: `Path2D` with control points from the generated polyline (Path2D is already in the design,
    about 4×23 strokes). No thickness per segment.
  * (b) Glow: stamp soft circles or brushes along segments into a **low-res** EditableImage with `CombineType.Add`,
    stretched under the vector layer. A blurry glow is fine at low resolution.
  * (c) 3-D: EditableMesh ribbons or tubes, 2 triangles per segment for ribbons and about 12 for tubes, so the 20k
    triangle cap allows about 1,600 tube segments. Grow them with `BatchSetValues`.

### 6.4 Domain-warped fBm nebulae

* The formula (Inigo Quilez): `q = fbm(p)`, `r = fbm(p + 4q)`, `v = fbm(p + 4r)`. Colour mixes a 3-stop palette
  using `v`, `|q|` and `r.x`. This produces the painted, swirling look.
* Cost: 15–25 noise calls per pixel, 821 px/ms, so 256² takes about 40 frames desktop and about 4 s on a phone,
  progressive.
* **Animate cheaply:**
  * store `v` as u8 and palette-cycle it;
  * slowly pan two layers with different `ImageRectOffset` speeds (parallax inside the sky);
  * re-render a new "weather" state progressively every minute and cross-fade the two images.
* Add stars as UI sprites or a separate sparse buffer pass. High-frequency detail should not come from the low-res
  field.

### 6.5 Curl-noise flow fields

* Velocity = `(∂n/∂y, −∂n/∂x)` of a noise field. It is divergence-free, so particles swirl without clumping, like
  smoke or aurora.
* 5,000 particles cost 1.3 ms. Draw each as one additive pixel or small `DrawCircle`, and fade the whole image with one
  `DrawRectangle` per frame, which leaves luminous streamlines.
* [EST] The per-particle `DrawCircle` call overhead is unknown. For thousands of particles, write pixels into a buffer
  and blit, or do only hundreds of Draw calls.

### 6.6 Reaction-diffusion (Gray-Scott)

* `A' = A + (Da∇²A − AB² + f(1−A))`, `B' = B + (Db∇²B + AB² − (k+f)B)`.
* The `f`/`k` pairs give spots (0.035/0.065), coral (0.055/0.062), mitosis (0.0367/0.0649) and worms (0.078/0.061).
* 6.3k cells/ms interpreted. It needs 4–20 steps per frame to evolve visibly, so run it at **64²** (0.65 ms/step) and
  upscale bilinear. That looks like living alien tissue or circuitry: ideal "corruption" and "malware" signatures.

### 6.7 Voronoi crystals

* Hash-jittered cell points with F1 and F2 distances:
  * `F2 − F1` gives bright crystal edges;
  * cell id gives facet colour;
  * `F1` gives a bevel.
* 1k px/ms, so 128² takes 16 ms. Compute once and store `(edge, id)` as 2 u8 channels. Animate by shifting the facet
  palette over time (a "light sweep" across facets = LUT rotation keyed by id).

### 6.8 SDF raymarching into an EditableImage

* Sphere-trace a signed distance field and shade with 4–6-tap normals, soft shadows and AO.
* 450 px/ms with 64 steps: **real-time only at about 48–64² with interlacing** (a 64² frame costs about 9 ms
  interpreted). A 256² "hero" render takes about 150 ms, sliced over about 75 frames.
* To go faster:
  * use 24–40 steps;
  * over-relaxed stepping (ω ≈ 1.6);
  * bounding spheres per object;
  * early-out on a background mask;
  * a half-res coarse pass then full-res only on hit pixels;
  * tetrahedral normals (4 taps).
* Best use: one-off renders of 3-D gems or crystals per node, cached in an atlas.

### 6.9 Metaballs

* Field `Σ rᵢ²/d²`; the threshold gives the blob and the raw field gives the glow. 2.2k px/ms, so render at 64²
  (1.9 ms) and let bilinear stretching produce soft, merging neon auras (ideal around READY nodes).

### 6.10 Bloom and blur on the CPU

* A pure-Luau bloom costs about 30 ms at 256², mostly in the up-sample. Instead:
  1. `DrawImageTransformed` the source into a 64² image with `scale = 0.25` (engine downsample);
  2. blur the 64² image in Luau (about 4 ms with r = 3; less with a sliding-window box blur);
  3. show it in a stretched ImageLabel **behind** the sharp one (GPU bilinear = free extra blur).
* For UI glows, the existing `UIShadow` and `glow_*` sprite recipes (DESIGN §13 R2, R4) are cheaper still.

---

## 7. Community showcase ledger

| project | what | numbers and lessons | tag |
|---|---|---|---|
| **RbxShader** (AnotherSubatomo) | Shadertoy-style fragment shader engine: parallel Luau, multipass buffers, `DualAxisInterlacing` | Studio 130–150 fps vs client 60 fps (Jan 2026 reply). The native-in-Studio trap. | COMM |
| "Fragment Shaders in Roblox!" (Apr 2024) | Dispatcher plus draw threads, tiles; Mandelbrot zoom and scrolling Perlin | The author later called the multi-actor approach infeasible after the Object refactor. | COMM |
| Realtime minimap (EditableImage + Parallel Luau) | 64² top-down raycast map | 60 fps, about 6 ms, 8 threads, raycast-bound. Suggests spreading work across frames. | COMM |
| Realtime raytracer in parallel (2025) | Real-time raytraced scene | Moving from DrawRectangle to buffers "improved performance significantly". Renders ¼ of pixels per frame. Abandoned over ID-verification and ToS worries. | COMM |
| Optimised EditableMesh ocean | 6 Gerstner waves, tiled meshes | About 2 ms on a low-power Ryzen, plus 2–4 ms with vertex colours. Frustum and distance culling. Wanted bulk vertex APIs, which now exist. | COMM |
| Simulated / FFT oceans | Gerstner and FFT water | Multithreading, frustum culling, distant vertices lerped rather than updated every frame. | COMM |
| CanvasDraw / OSGL (Ethanthegrand14 and others) | Graphics libraries on EditableImage | OSGL notes "1 redraw per frame" across multiple images. | COMM |
| EditableImage and EditableMesh use-case showcase | Julia set, cellular automata, chaos equations, audio-driven mesh, volumetric fog renderer | Proofs of concept; no numbers. | COMM |
| "A complete guide to EditableImages" (Jul 2025) | Tutorial | u32 packing, row `buffer.copy`, strip actors writing after `task.synchronize()`, lazy texture loading. Video via an external server (500 HTTP req/min limit). | COMM |
| Drawing games | Multiplayer canvases | Manual replication: server `ReadPixelsBuffer`, send the buffer, client `WritePixelsBuffer`. | COMM |
| Memory reports | — | 5–6 × 1024² hit the budget (about 25 MB). "32 MB and 1024×1024". "8 editables", 480k vertices / 160k triangles. A 512² static drawing is about 1 MB per client with no compression. | COMM |
| Custom fractal viewer (2023, pre-EditableImage) | Up to 1200×900 fractals | Its tile cache used 10+ GB of RAM. Budget your caches. | COMM |

---

## 8. Pitfalls checklist

* [ ] `pcall` every create call **and** check for `nil`. Keep a baked PNG fallback for every procedural surface.
* [ ] Never create editables on the server for display.
* [ ] Only one animated EditableImage on screen at a time, or one atlas. Static images are written once.
* [ ] `Destroy()` images when a panel closes. Don't count on garbage collection for budget accounting.
* [ ] No `Vector2.new`, `Color3.new` or table creation per pixel. Use scalars, LUTs and u32 packing.
* [ ] Measure without native code (`luau -O2`, or remove `--!native` in Studio) and on a real phone
      (MicroProfiler, Ctrl+F6).
* [ ] Slice work with `os.clock()`. Pause generators while the map is hidden (COMPACT full-screen sheet →
      `MapGui.Enabled = false`, DESIGN §17).
* [ ] Keep EditableImage sources near their on-screen size (no mipmaps).
* [ ] `ReducedMotion` should stop palette cycling and flow fields, leaving the last frame static.
* [ ] Keep a deterministic seed (UserId, layer id, prestige count) in the save, not pixels. Regenerate on join.

---

## 9. Opportunities for Milestone Tree

The realm is UI (MapGui with L0_sky … F_motesNear layers on a 3840×2560 world). Editables therefore mostly mean
**EditableImage inside ImageLabels**, with EditableMesh reserved for set pieces.

Memory plan: all the ideas below together use about 7–9 MB of the roughly 32 MB budget:

* sky 512² (1 MB);
* glow and aura atlas 512² (1 MB);
* panel and material atlas 1024² (4 MB);
* flame 256² (0.25 MB);
* portal 128² (64 KB);
* gem atlas 512² (1 MB).

Every idea is gated by `Theme.caps.editable`. Every fallback is a baked PNG made **by the same Luau generator**
offline.

| # | idea | how | cost (client, interpreted) | risk and limits | mobile / fallback |
|---|---|---|---|---|---|
| 1 | **Living nebula sky** (L0_sky / Wash) | Domain-warped fBm, per-layer hue `c`, 256² (HIGH) or 128² (LOW), progressive coarse-to-fine behind the splash. Stored as a u8 field and palette-cycled, with slow `ImageRectOffset` drift for parallax inside the layer. A new "weather" is re-rendered and cross-faded every few minutes. | About 40 frames at 2 ms to build; then 0.6 ms per animated frame (128²) | Soft at 256² stretched to 3840 world px, which is fine for low-frequency sky. Keep stars and painted detail in the existing tiles. | Phone: 128², cycling at 20 Hz. Fallback: the current painted sky tiles. |
| 2 | **The tree that grows itself** | Space colonisation with attractors at each **unlocked** node plus jitter, seeded by UserId. On unlock, new branches grow toward the new node over about 2 s: vector strokes via Path2D and a low-res additive glow in the glow atlas. | Generation a few ms per unlock (one-off); growth reveal ≈ 0 (reveal by birth time) | Path2D stroke count (DESIGN §18 is already verifying about 90 strokes). Branch geometry must avoid node plates. | Phone: fewer branches and no glow layer. Fallback: the static Figma connections. |
| 3 | **Julia-set Multiverse rift / portal** | Animated Julia with `c(t)` on a slow circle and an orbit-trap filament glow. 96² with ¼ interlacing, stretched and masked by a circular UIGradient. | About 1.5 ms/frame desktop | Needs the one animated atlas slot while visible. | Phone: 64², or a static DE render palette-cycled. Fallback: portal sprite plus conical ring (R6). |
| 4 | **Prestige = photographic flame** | On prestige, a fractal flame seeded by `(layer, prestigeCount)` "develops" behind the hero for about 1–3 s (accumulation at 14k points/frame, tone-map every 15 frames). It is the player's unique memento, kept in the layer panel. | 2 ms/frame while developing; then static | Flames need variety tuning. Pick 6–8 curated variation sets per signature. | Phone: 128² and fewer points (still pretty). Fallback: a pre-baked flame per layer. |
| 5 | **Crystal panel frames** | A Voronoi `F2−F1` crystal material per layer signature, computed once into the 1024² panel atlas. The open panel's region gets a facet-by-facet light sweep via LUT rotation keyed by cell id. | 16 ms per 128² tile, sliced once; sweep 0.5 ms/frame for the open panel only | One panel is open at a time, so it fits the one-update rule. 21 tiles of 192² fit in 1024². | Phone: static crystal, sweep off. Fallback: the bevel recipe (R1). |
| 6 | **Corruption that spreads** (Corrupted / Malware layers) | Gray-Scott at 64², 4 steps/frame, seeded where the player clicked INFECT. Coral or worm patterns crawl across the hero and are tinted by a LUT. | About 2.6 ms/frame desktop | Only while those panels are open. | Phone: 48², 2 steps. Fallback: a flipbook sprite. |
| 7 | **21 procedural layer signatures** | One parametric generator (noise type, warp, palette, symmetry, fractal type) producing a unique 128² texture per layer for the hero, nameplate backing and gem inlay. Generated at join over about 1–2 s, then static (21 × 64 KB = 1.3 MB). | One-off: about 60–200 frames of 2 ms, background | Keep text contrast (DESIGN §9.7 backings). | Phone: 64² per layer. Fallback: baked PNGs from the same seeds. |
| 8 | **Personal sigil and holo-portrait** | An L-system or IFS emblem seeded by UserId for the end screen and profile. `CreateEditableImageAsync(Content.fromUri("rbxthumb://type=AvatarHeadShot&id=…&w=150&h=150"))` → posterise, add scanlines and neon edge (Sobel), then `Add` a glow. | About 5–10 ms total, one-off | rbxthumb loading is allowed per the docs. Verify the thumbnail URI format and moderation expectations. | Fallback: a plain headshot in a neon frame. |
| 9 | **Milestone crystal (DLA)** | A diffusion-limited-aggregation crystal where each milestone adds N particles. Seed and count live in the save and regrow deterministically on join. It grows visibly on the Milestone panel. | Fast DLA (spawn near the cluster): about 0.5–2 ms per particle batch | Many milestones means many particles, so cap or log-scale them. | Phone: a smaller canvas. Fallback: a static crystal sprite. |
| 10 | **Curl-noise mote fields** (F_motesFar/Near) | 2–5k particles advected by curl noise, drawn additively into a 256² trail buffer with a per-frame engine fade. Aurora-like streamlines drift behind the tree and react to camera pan (offset the noise). | About 1.3 ms plus drawing (pixel writes, not Draw calls) | Uses the animated atlas slot. It competes with the portal, so run only one of them at a time. | Phone: 800 particles at 128², or the existing sprite motes. |
| 11 | **Raymarched gem nodes** | Each node's gem rendered once at unlock: an SDF faceted crystal with fake refraction (a normal-driven palette) and iridescence, 64² into a 512² gem atlas. The hover state re-renders one gem with the light direction following the mouse at ¼ interlacing. | About 9 ms per gem, sliced over 5 frames; hover 2 ms/frame | Hover animation uses the animated slot. | Phone: no hover re-render. Fallback: the node sprites. |
| 12 | **READY aura field** | A metaball field around READY nodes (the field *merges* when nodes are close), rendered at 64² over the visible map rect and stretched under Nodes, updated at 10–15 Hz as the camera moves. | About 1.9 ms per update | Mapping map to screen coordinates on pan and zoom. Update only when the camera or READY set changes (the DESIGN "0 writes at rest" rule). | Fallback: the radial gradient R7. |
| 13 | **Prestige-hold zoom** | During the 0.6–1.2 s hold, pre-render 3 Mandelbrot or Burning Ship zoom levels into the atlas. On release, play an "infinite zoom" by scaling and cross-fading the ImageLabels on the GPU. | About 3 × 25 frames, started when the hold begins | The hold may be too short on phones, so start at hover or READY. | Fallback: the existing prestige juice (§5.4). |
| 14 | **NG+ reveal set piece in 3-D** | An EditableMesh tube tree (L-system or space colonisation, ≤ 1,600 segments) growing in Workspace behind a transparent UI moment (the camera is already Scriptable) or in a ViewportFrame [EST: verify EditableMesh in ViewportFrame]. Its texture is an EditableImage flame with emissive-looking colours; growth uses `BatchSetValues`. | Growth about 1 ms/frame with batching; one-off build | 20k-triangle cap. Mesh bounds on growth (§3.4). Uses mesh budget. | Fallback: a pre-rendered video or flipbook, or a 2-D version (idea 2). |
| 15 | **Server-baked reward art** (optional) | For big milestones, the server (native, unlimited budget) renders a 512² flame, Zstd-compresses it and sends it once, and the client writes it. Offloads low-end phones. | Server-side; client ≈ one `WritePixelsBuffer` | Bandwidth spike (roughly 100–400 KB compressed [EST]). Only one-off. | Fallback: client generation at 128². |
| 16 | **Offline bake pipeline** (enabler) | Run the exact generators with the local `luau` CLI (or Lune) at 2048² and 4K, and upload the results as the LOW-tier and no-editables fallback, plus marketing art. This guarantees visual parity when the ID gate or the budget fails. | Build time only | Keep generators pure (buffer in, buffer out) so they run in both places. | This *is* the fallback. |

**Suggested order:**

1. Idea 16 (pipeline and pure generators).
2. The §5.1 scheduler and atlas.
3. Idea 1 (sky).
4. Idea 2 (growing tree).
5. Idea 3 (portal).
6. Idea 4 (flame memento).
7. The rest as polish.

Before any of it, confirm that the owner account is ID-verified and turn the toggle on. Otherwise every item ships as
its fallback.

---

## 10. Sources

* Docs: [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) ·
  [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) ·
  [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService) ·
  [Native code generation](https://create.roblox.com/docs/luau/native-code-gen) ·
  [Parallel Luau](https://create.roblox.com/docs/scripting/multithreading) ·
  [creator-docs YAML (EditableImage)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml)
* Announcements:
  * [Studio Beta updates (2024-09-25)](https://devforum.roblox.com/t/studio-beta-updates-to-in-experience-mesh-image-apis/3172217)
  * [Major updates (2024-10-23)](https://devforum.roblox.com/t/studio-beta-major-updates-to-in-experience-mesh-image-apis/3225681)
  * [Client Beta (2024-11-20)](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293)
  * [Improvements (2025-07-16)](https://devforum.roblox.com/t/editablemesh-and-editableimage-improvements/3818624)
  * [SurfaceAppearance build-a-texture (2025-08 / 2026-01)](https://devforum.roblox.com/t/in-experience-build-a-texture-editableimage-support-for-surfaceappearance/3866947)
  * [Batching and parallel queries (2026-09-15)](https://devforum.roblox.com/t/studio-beta-editablemesh-batching-apis-parallel-queries/4779401)
  * [Quads (2026-09-23)](https://devforum.roblox.com/t/studio-beta-quad-support-for-editablemesh-apis/4890142)
  * [Native codegen preview update](https://devforum.roblox.com/t/luau-native-code-generation-preview-update/2961746)
* Community:
  * [Enable --!native for clients](https://devforum.roblox.com/t/enable-native-for-clients/3170510)
  * [Native in Studio but not client](https://devforum.roblox.com/t/native-codegen-works-in-localscripts-in-studio-but-not-in-the-client/2710130)
  * [Budget error thread](https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799)
  * [Remove editable limit](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561)
  * [Higher resolution and memory limit](https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575)
  * [Static memory](https://devforum.roblox.com/t/reducing-memory-consumption-of-editableimage-once-static/3639609)
  * [Sky content bug](https://devforum.roblox.com/t/suntexturecontent-and-moontexturecontent-and-all-skys-side-content-does-not-work/4656314)
  * [Video age verification request](https://devforum.roblox.com/t/allow-video-age-verified-users-to-access-editableimagemesh-apis/4098817)
  * [Complete guide](https://devforum.roblox.com/t/a-complete-guide-to-editableimages/3858566)
  * [Write in parallel](https://devforum.roblox.com/t/how-to-write-to-an-editableimage-in-parallel/3638723)
  * [RbxShader](https://github.com/AnotherSubatomo/RbxShader) and its [forum thread](https://devforum.roblox.com/t/rbxshader-a-robust-shader-engine-for-everyone/2965460)
  * [Fragment shaders](https://devforum.roblox.com/t/fragment-shaders-in-roblox/2908995)
  * [Minimap](https://devforum.roblox.com/t/realtime-minimap-using-editableimage-parallel-luau/2776543)
  * [Raytracer](https://devforum.roblox.com/t/realtime-raytracer-ran-in-parallel/3478308)
  * [EditableMesh ocean](https://devforum.roblox.com/t/optimized-editablemesh-ocean-project/3236817)
  * [Simulated ocean](https://devforum.roblox.com/t/simulated-ocean-with-editablemesh/3562339)
  * [Use-case showcase](https://devforum.roblox.com/t/showcase-feedback-editableimages-editablemesh-use-cases/3537501)
  * [Fractal viewer](https://devforum.roblox.com/t/custom-fractal-viewer-fractal-image-generator-in-roblox/2580257)
  * [CanvasDraw](https://github.com/Ethanthegrand/CanvasDraw)
  * [OSGL](https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757)
  * [boyned: "I cannot use EditableImages"](https://blog.boyned.com/articles/i-cannot-use-editable-images/)
  * [Spring 2026 roadmap summary (third party)](https://www.bloxbot.ai/guide/roblox-spring-2026-creator-roadmap)
* Techniques: Inigo Quilez (domain warping, cosine palettes, SDF and distance estimation) · Draves and Reckase,
  "The Fractal Flame Algorithm" · Runions et al., "Modeling Trees with a Space Colonization Algorithm" · Pearson,
  "Complex Patterns in a Simple System" (Gray-Scott) · Bridson, "Curl-Noise for Procedural Fluid Flow".
