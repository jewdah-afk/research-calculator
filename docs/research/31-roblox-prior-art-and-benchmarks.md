# Prior Art, Open-Source Libraries, and Real Measured Benchmarks for Roblox Runtime Content Generation

> **Chapter status:** archaeology. Everything below is evidence collected from public sources
> (GitHub source code, Wally registry, web-search summaries of DevForum threads, Roblox's own
> documentation as mirrored in the `Roblox/creator-docs` GitHub repository). The goal is that
> this team **reuses rather than reinvents**, and that its performance expectations rest on
> measured numbers rather than hope.
>
> **Confidence markers used throughout:**
> - `[DOCUMENTED]` — Roblox's own documentation or Roblox-authored source, read directly
>   (via the `Roblox/creator-docs` GitHub mirror, since `create.roblox.com` is unreachable here).
> - `[SOURCE-READ]` — I fetched and read the actual open-source code. Highest confidence for
>   *architecture* claims; the code is the artifact.
> - `[COMMUNITY, SECOND-HAND]` — reported by developers on the DevForum / YouTube / blogs, reaching
>   me only through web-search result summaries. `devforum.roblox.com` is 403-blocked from this
>   environment, so **I could not open the original threads**. Treat every number as a claim, not
>   a measurement, and re-measure before you bet on it.
> - `[INFERRED]` — my own arithmetic on top of the above. The inputs are cited; the output is mine.
>
> **Sources that were blocked (403) and are therefore absent:** `create.roblox.com`,
> `devforum.roblox.com`, `luau.org`. Where a Roblox doc claim appears below it came from the
> `Roblox/creator-docs` GitHub repository, which is the same content under an open license.

---

## TL;DR

- **Do not write another pixel canvas.** Two mature, readable, open-source EditableImage canvas
  libraries already exist and have independently converged on the same architecture:
  [FastCanvas / CanvasDraw](https://github.com/Ethanthegrand/FastCanvas) (Ethanthegrand) and
  [OSGL](https://github.com/osgl-rbx/osgl) (saaawdust). I read both source trees. `[SOURCE-READ]`
- **The convergent architecture is: one flat Luau `buffer` of RGBA-u8, indexed
  `(x + (y-1) * width) * 4`, written with a single `buffer.writeu32` per pixel, flushed to the
  GPU with exactly one `EditableImage:WritePixelsBuffer(Vector2.zero, size, buf)` per frame.**
  Both libraries do this; neither calls a per-pixel Roblox API. Copy this shape. `[SOURCE-READ]`
- **FastCanvas's fill trick is the single most reusable micro-optimisation found:** to fill a
  horizontal span, write one u32 pixel then repeatedly `buffer.copy` the region onto itself,
  **doubling the copied length each iteration**. An N-pixel span costs `ceil(log2(N))` copies
  instead of N writes. It uses the same trick to build a clear-colour scanline, then row-copies
  that scanline down a whole pre-baked "clearing grid" so `Canvas:Clear()` is one `buffer.copy`.
  `[SOURCE-READ]`
- **Hard documented image ceiling: `EditableImage` is capped at 1024×1024 and cannot be
  resized**, and — the constraint that actually bites — **only ONE displayed `EditableImage` is
  updated per frame.** Three on-screen canvases take three frames to all refresh. `[DOCUMENTED]`
- **Hard documented mesh ceiling: 60,000 vertices and 20,000 triangles per `EditableMesh`.**
  Exceeding it errors rather than degrading. `[DOCUMENTED]`
- **There is also a separate, much tighter client-side *instance count* budget**, widely reported
  by developers as roughly **8 editable objects live on the client at once**, enforced by a
  "device-specific editable memory budget" that Roblox documents but never publishes a number
  for. `CreateEditableImage`/`CreateEditableMesh` return `nil` when it's exhausted — so every
  creation call needs a `nil` check, not just a `pcall`. `[DOCUMENTED]` + `[COMMUNITY, SECOND-HAND]`
- **Realistic realtime software-rendering resolution is 100×100 to roughly 256×256**, not
  1024×1024. The most credible community claim — a fully textured multi-threaded raytracer —
  reports "well above 60 FPS on a mid-range computer at **100×100**". Full-screen per-pixel work
  at 1024×1024 is ~107× more pixels than that and is not supported by any evidence found.
  `[COMMUNITY, SECOND-HAND]` + `[INFERRED]`
- **Path tracers, raycasters and software 3D renderers on EditableImage all exist** (Radius,
  BloxPT, Piotrekstel's path tracer, RetroRaster, Ro2D, luau_term, a full N64 emulator). They
  are proof the technique works and simultaneously proof of where the ceiling is: every one of
  them runs at low resolution, accumulates over frames, or both. `[COMMUNITY, SECOND-HAND]`
- **The reusable-library ecosystem is mature for *infrastructure* and thin for *procedural
  generation*.** Promise, Janitor/Trove, Signal, React-lua/Fusion, ProfileStore, Wally, TestEZ /
  Jest-lua are all production-grade and maintained. Noise, marching cubes, geometry kernels,
  spatial partitioning and runtime CSG are **not** — you will write those yourself.
- **Notable absences of prior art, each a finding in its own right:** no open-source
  marching-cubes-on-EditableMesh library, no runtime CSG library, no LOD/decimation library, no
  mesh-streaming/chunk manager, and no published, reproducible benchmark suite for either API.
- **Almost every performance number in this chapter is second-hand.** The DevForum is the only
  place these numbers live, it is 403-blocked from this environment, and even at source the
  numbers are self-reported, un-versioned, and rarely state a device. **Budget one engineer-day
  to build your own measurement harness before committing to any architecture.**
- **The real wall is not pixel throughput.** Luau `buffer` writes are fast enough. The walls are
  (a) one display update per frame, (b) the ~8-object editable budget, (c) 20k triangles per
  mesh, (d) no GPU compute of any kind — every pixel and every vertex is computed on the CPU, on
  the main thread or in `task.desynchronize`d Actors. `[DOCUMENTED]` + `[INFERRED]`
- **`CreateMeshPartAsync` + `ApplyMesh` is the expensive call in mesh work, not the geometry
  edits.** Roblox's own docs say to call it once at the end of a conceptual edit, not after each
  mutation, because it recalculates collision and fluid geometry. `[DOCUMENTED]`
- **Parallel Luau (Actors + `task.desynchronize`) is the accepted way to scale**, and the
  serious renderers use it — but `EditableImage` writes are not parallel-safe from desynchronised
  code in the obvious way; the community pattern is to compute into per-Actor `buffer`s and
  `buffer.copy` them into the master buffer on the serial phase. `[COMMUNITY, SECOND-HAND]`

---

## 1. EditableImage in the wild

The `EditableImage` ecosystem is the *healthier* of the two. There are at least two serious,
maintained, general-purpose canvas libraries, a long tail of renderers built on top of them, and
a handful of single-purpose utilities. I read source for the significant ones.

### 1.1 The convergent architecture (read this before anything else)

Every serious EditableImage project I opened uses the same four-part shape. This is not
coincidence; it is what the API forces.

1. **One flat `buffer` of RGBA-u8.** `buffer.create(width * height * 4)`. Not a table of tables,
   not a table of `Color3`. The buffer *is* the framebuffer.
2. **A closed-form index function.** Both major libraries use
   `(x + (y - 1) * width) * 4 - 4` — i.e. 1-based `x`/`y` mapped to a 0-based byte offset.
3. **One `buffer.writeu32` per pixel, not four `writeu8`.** RGBA is packed little-endian into a
   single 32-bit word: `bit32.bor(bit32.lshift(a,24), bit32.lshift(b,16), bit32.lshift(g,8), r)`.
   One buffer call instead of four is the single largest constant-factor win in the inner loop.
4. **Exactly one `EditableImage:WritePixelsBuffer(Vector2.zero, size, buf)` per frame**, at the
   end. No per-pixel engine calls exist in the hot path at all.

`[SOURCE-READ]` — verified in both
[FastCanvas.luau](https://raw.githubusercontent.com/Ethanthegrand/FastCanvas/main/FastCanvas.luau)
and [OSGL `windowBase.luau`](https://raw.githubusercontent.com/osgl-rbx/osgl/main/src/DrawableObject/windowBase.luau).

**Take-away for this team:** write your renderer against a plain `buffer` with this exact index
convention. Then the choice of canvas library is a 20-line adapter, and you can swap or drop it.

---

### 1.2 FastCanvas — the minimal reference implementation

| Field | Value |
| --- | --- |
| What it is | A ~465-line single-file pixel canvas: buffer in, `EditableImage` out. The rendering core that CanvasDraw is built on. |
| URL | https://github.com/Ethanthegrand/FastCanvas — source: [`FastCanvas.luau`](https://raw.githubusercontent.com/Ethanthegrand/FastCanvas/main/FastCanvas.luau) |
| Author | Ethanthegrand14 (`@Ethanthegrand`) |
| Created / last updated | 2023-11-09 / 2026-07-09 (header comment in source) |
| Stars | ~3 (it is the quiet engine under CanvasDraw's ~hundreds of DevForum pages) |
| License | Not declared in the repo — **treat as all-rights-reserved and ask before shipping.** `[SOURCE-READ]` |
| Confidence | `[SOURCE-READ]` — read in full |

**Architecture, as actually written:**

- File begins `--!native`. The whole module is compiled with Luau native codegen. `[SOURCE-READ]`
- `FastCanvas.new(Width, Height, CanvasParent?, Blur?)` is a **closure-based object**, not a
  metatable class. Every method is a fresh closure that captures `Grid`, `Width`, `Height`.
  This trades per-instance memory for eliminating `self` indirection and metatable `__index`
  lookups in the inner loop. That is a deliberate, defensible choice for a pixel API.
- Three buffers are allocated up front:
  - `Grid` — the live framebuffer, `W*H*4` bytes.
  - `ClearingGrid` — a **pre-baked, full-size copy of the clear colour**, also `W*H*4`.
  - `CurrentClearRGBA` — a 4-byte scratch holding the packed clear colour.
- `Canvas:Clear()` is therefore literally one call: `buffer.copy(Grid, 0, ClearingGrid, 0)`.
  Clearing a 1024×1024 canvas is a single 4 MB memcpy rather than a million Luau iterations.
  **Cost: 2× the framebuffer memory, permanently.** `[SOURCE-READ]`

**The doubling-copy span fill — the most transferable trick in this chapter.**

`Canvas:SetBufferLine(ColourU32, X1, X2, Y)` fills a horizontal run of pixels. Instead of looping,
it writes *one* u32 and then repeatedly copies the already-written region onto the region
immediately after it, doubling the length written each round:

```lua
buffer.writeu32(Grid, StartIndex, ColourU32)

local SizeStep = 4
while SizeStep < Length do
    local Count = SizeStep
    local Remaining = Length - SizeStep
    if Count > Remaining then Count = Remaining end
    buffer.copy(Grid, StartIndex + SizeStep, Grid, StartIndex, Count)
    SizeStep += Count
end
```

An N-pixel span costs `ceil(log2(N))` `buffer.copy` calls instead of N `buffer.writeu32` calls.
For a 1024-pixel scanline that is **10 copies instead of 1024 writes**. `[SOURCE-READ]`

`Canvas:SetClearRGBA()` uses the same trick to build one clear-coloured scanline, then does
`Height - 1` row copies to fill `ClearingGrid`. `[SOURCE-READ]`

**Blitting.** `Canvas:SetBuffer(buf, X, Y, BW, BH)` clips the source rect against the canvas
bounds first, then copies **one row at a time** with `buffer.copy` — never per pixel. The
unclipped fast path degenerates to a single whole-buffer `buffer.copy`. `Canvas:GetBuffer()` is the
exact mirror image. `[SOURCE-READ]`

**Render.** The entire flush is:

```lua
function Canvas:Render()
    EditableImage:WritePixelsBuffer(Origin, Resolution, Grid)
end
```

`Origin` and `Resolution` are hoisted to upvalues at construction so no `Vector2.new` allocation
happens per frame. `[SOURCE-READ]`

**Failure handling worth copying.** `AssetService:CreateEditableImage` is checked for `nil`, not
just wrapped in `pcall`:

```lua
local EditableImage = AssetService:CreateEditableImage({Size = Resolution})
if not EditableImage then
    warn("Failed to create Canvas due to EditableImage memory limit being hit!")
    return nil
end
```

This matches the documented contract — creation returns `nil` when the device editable-memory
budget is exhausted, it does not throw. `[SOURCE-READ]` + `[DOCUMENTED]`

**Parent flexibility.** The canvas will attach itself to a `GuiObject` (via a generated
`ImageLabel` + `UIAspectRatioConstraint`, with `ResampleMode = Pixelated` unless `Blur`),
a `Decal`/`Texture`/`MeshPart` (`TextureContent`), or a `SurfaceAppearance` (`ColorMapContent`).
That `SurfaceAppearance.ColorMapContent` path is the interesting one — it means a runtime-generated
texture can flow through the PBR pipeline, not just be a flat unlit image. `[SOURCE-READ]`

**`Canvas:Resize()` is a lie in the useful sense:** `EditableImage.Size` is read-only, so resize
creates a *new* `EditableImage`, destroys the old one, and reallocates both buffers. Do not call
it per frame. `[SOURCE-READ]` + `[DOCUMENTED]`

**What to take:** the doubling span fill, the pre-baked clearing grid, the row-wise clipped blit,
the packed-u32 pixel write, and the `nil`-check on creation. Those five ideas are most of the
performance of a software renderer on this platform.

---

### 1.3 CanvasDraw — the batteries-included layer

| Field | Value |
| --- | --- |
| What it is | A ~3,750-line full 2D graphics library on top of FastCanvas: lines, circles, rects, triangles, **textured triangles**, distorted quads, rotated images, sprite-sheet rects, bitmap text with 7 fonts, flood fill, alpha-blending modes, image load/save/compress. |
| URL | https://github.com/Ethanthegrand/CanvasDraw · DevForum thread `devforum.roblox.com/t/1624633` · API docs thread `devforum.roblox.com/t/2017699` |
| Version read | **4.20.2**, header dated 2026-07-09 `[SOURCE-READ]` |
| License | Header says `Copyright © 2022 - 2026 | CanvasDraw`; **no OSS licence file in the repo.** Ask the author before shipping. `[SOURCE-READ]` |
| Maintained? | Yes — very actively; the DevForum thread runs 26+ pages. `[SOURCE-READ]` + `[COMMUNITY, SECOND-HAND]` |

**Architecture notes from the source:**

- Also `--!native`. Also closure-based canvas objects. `[SOURCE-READ]`
- **It owns the frame loop.** `Canvas.AutoUpdateConnection = RunService.Heartbeat:Connect(...)`
  calls `Canvas:Render()` at most once per Heartbeat, gated by `Canvas.AutoRenderFpsLimit`
  (0 = uncapped). It clamps the frame-delta accumulator at `0.2` s so a hitch can't cause a
  render storm. If you have your own scheduler, set `AutoRender = false` and drive `:Render()`
  yourself. `[SOURCE-READ]`
- **Scanline-oriented interior.** The private `DrawScanline(StartX, EndX, Y, R, G, B, A, U32)`
  helper is what triangles, circles and rects all funnel into. It hoists `Canvas.Buffer`,
  `RowBase = (Y-1) * ResX * 4`, and the 0–255 channel values out of the loop before writing —
  the source comment says it explicitly: *"Y doesn't change per scanline so hoist it, raw bytes
  beats /255 round trip"*. `[SOURCE-READ]`
- **Alpha blending is opt-out for speed.** `AlphaBlendingMode` defaults to `Replace` (1), and the
  API doc in-file warns that `Normal` (0) and `AddAlpha` (2) are slower because they force
  per-pixel read-modify-write. Default to `Replace` unless you need blending. `[SOURCE-READ]`
- **Flood fill is a buffer-backed BFS**, not recursion: an `i32`-pair queue in a `buffer`, a
  `seenBuffer` of `u8` flags sized to the canvas, and **geometric queue growth** (allocate
  `2×`, `buffer.copy` the old contents in) when the frontier overruns. Its own docs still say
  *"this function is not very fast! Do not use for real-time rendering."* `[SOURCE-READ]`
- **Compression uses Roblox's *native* zstd**, which is a significant and under-advertised
  platform capability: `EncodingService:CompressBuffer(buf, Enum.CompressionAlgorithm.Zstd, level)`
  with `level` from −7 to 22, and `EncodingService:DecompressBuffer(...)`. CanvasDraw uses it for
  DataStore-friendly image persistence. **This is a general-purpose tool — use it for any binary
  payload, not just images.** `[SOURCE-READ]`
- **Image loading** goes `AssetService:CreateEditableImageAsync(ImageContent)` →
  `EditableImage:ReadPixelsBuffer(Vector2.zero, size)` → keep the buffer, discard the editable.
  `GetImageDataFromTextureId(id, MaxWidth?, MaxHeight?)` rescales on load to respect a budget.
  There is an explicit `Slowload` option that yields and decompresses in chunks *"to avoid lag
  spikes on the client with large images (recommended for images above 1024×1024)"* — an
  acknowledgement that a single large decode blows a frame. `[SOURCE-READ]`
- **It reads OSGL texture modules too** — the two ecosystems interoperate at the asset level.
  `[SOURCE-READ]`

**Capability that matters for 3D work:** `Canvas:DrawTexturedTriangle(A, B, C, UV1, UV2, UV3,
ImageData, Brightness?)` and `Canvas:DrawDistortedImage(A, B, C, D, ImageData, Brightness?)`
exist and are documented as *"intended for 3D rendering"*. If you want a software 3D rasteriser,
the triangle-with-UVs primitive is already written. `[SOURCE-READ]`

**What to take:** the scanline helper's hoisting pattern; `Replace` blending by default; the
buffer-backed BFS with geometric growth as a template for *any* flood/frontier algorithm;
and `EncodingService` zstd for persistence.

---

### 1.4 OSGL — the typed, `Result`-returning alternative

| Field | Value |
| --- | --- |
| What it is | "Open-Source Graphical Library" — a modular, strongly-typed EditableImage graphics library. Modules: `Window`, `Texture`, `Bitmap`, `Video`, `Font`, `color`, `Enum`. |
| URL | https://github.com/osgl-rbx/osgl · DevForum thread https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757 |
| Version read | **v1.6.2** (header), LICENSE file header reads `OSGL LICENSE v1.6.15` `[SOURCE-READ]` |
| Stars | ~25 `[SOURCE-READ]` |
| License | **A custom, non-OSI licence**, not MIT. Permits use, modification, distribution and commercial use; forbids repackaging/selling OSGL directly and claiming authorship of the core library. Legally usable for a game; **not** an OSI-approved licence, so if your org has a licence allowlist this will need an exception. `[SOURCE-READ]` |
| Maintained? | Yes. Has `aftman.toml`, `wally.project.json`, `moonwave.toml` (docs site), `tests/`, `examples/`, a Studio `plugin/`, and `.stylua.toml`. This is the most professionally-packaged of the three. `[SOURCE-READ]` |

**Architecture, as actually written:**

- Modules open with **`--!optimize 2`** *and* **`--!native`** — OSGL turns on both the optimiser
  level and native codegen, where FastCanvas/CanvasDraw only set `--!native`. `[SOURCE-READ]`
- **Errors are values, not exceptions.** `Window.from()` returns a `Result<Window, WindowError>`
  with `:Unwrap()`, and the error enum distinguishes
  `WindowDimensionsOutOfBounds`, `InvalidCreationInstance`, `NotEnoughMemory`, and `APINotEnabled`.
  `[SOURCE-READ]`
- **It hard-codes the documented 1024 limit** as a validation bound, which independently confirms
  the ceiling: `if not width or not height or width < 1 or width > 1024 or height < 1 or height > 1024 then return result.new(false, WindowError.WindowDimensionsOutOfBounds) end` `[SOURCE-READ]`
- **It probes for the security toggle at creation time** with a deliberate 1-pixel write, and
  string-matches the engine's error text to produce a clean `APINotEnabled` result:

  ```lua
  local ok, err = pcall(function()
      return EditableImage:WritePixelsBuffer(Vector2.zero, Vector2.one, buffer.create(4))
  end)
  if not ok and err == "EditableImage is not accessible. Go to the Security Tab in Game Settings to enable this API." then
      return result.new(false, oEnum.WindowError.APINotEnabled)
  end
  ```

  That is a genuinely useful diagnostic and also a warning: **OSGL is string-matching an engine
  error message.** If Roblox rewords it, this detection silently breaks. `[SOURCE-READ]`
- **Multi-surface windows are first-class.** `Window.new(editableImage, renderers)` takes a *list*
  of drawable instances and assigns the same `Content.fromObject(editableImage)` to each one's
  appropriate content property, with `AddRenderers`/`RemoveRenderers` to change the set at
  runtime. This is exactly the "multi-referencing" memory optimisation Roblox's own docs
  recommend — one editable image displayed on many surfaces costs one budget slot.
  `[SOURCE-READ]` + `[DOCUMENTED]`
- **Two render paths:** `Render()` writes the buffer and returns; `RenderTargetFPS()` writes the
  buffer, measures elapsed time, and `task.wait(1/targetFPS - 1/fps)` if it is running ahead of
  `self.targetFPS` (default 60). A frame limiter built into the library. `[SOURCE-READ]`
- `Window.fromAssetId(assetId)` builds a window from an existing image asset via
  `Content.fromAssetId`. `[SOURCE-READ]`
- `GetRelativeMousePosition(window, imageBase)` maps screen-space mouse into canvas pixel
  coordinates — the boring-but-essential piece every paint/UI project re-derives. `[SOURCE-READ]`
- It has a **`Video`** module and a **`Font`** module, i.e. playback of pre-encoded frame data and
  bitmap text are solved problems here. `[SOURCE-READ]`

**Reported ceilings (second-hand).** The OSGL DevForum thread is the single richest source of
community performance claims for EditableImage, and two claims recur:
- *"EditableImages are limited to 1024×1024; you can use multiple images connected together,
  **but Roblox limits updates to 1 redraw per frame, so 10 images take 10 frames to render.**"*
  `[COMMUNITY, SECOND-HAND]` — and this matches Roblox's own docs exactly, so it is credible.
- *"You can make semi-realtime pathtracers achieving 30–60 FPS with realtime reflections"* —
  resolution unstated, which makes the number nearly useless. `[COMMUNITY, SECOND-HAND]`

**What to take:** the `Result` error model (`nil`-return + budget exhaustion is a *normal*
outcome on this platform, not an exception); multi-surface windows for budget efficiency; the
built-in frame limiter; and `--!optimize 2` alongside `--!native`.

---

### 1.5 The renderers and demos built on top

These are the "can it be done" evidence. Each entry's resolution is the number that matters.

| Project | What it is | URL | Resolution / perf claimed | Code / licence | Confidence |
| --- | --- | --- | --- | --- | --- |
| **plumber** | **A full Nintendo 64 emulator inside Roblox.** R4300 interpreter, Fast3D + Goddard microcode software rasterisers with texture mapping and a depth buffer, 16-voice audio HLE, boots Super Mario 64 (EU) to gameplay. | https://github.com/yoits9090/plumber | **Software framebuffer at 320×240, with a 160×120 fast path**, presented via `EditableImage:WritePixelsBuffer()` each frame. Ships `docs/runtime-profiling.md`. | **MIT**, TypeScript+Luau, Rojo 7.7.0 via rokit | `[SOURCE-READ]` (README) |
| **RetroRaster** | Multi-threaded textured raytracer, by the CanvasDraw author. | https://ethanthegrand.itch.io/retroraster | *"well above 60 FPS on a mid-range computer at **100×100**"* | itch.io, licence unclear | `[COMMUNITY, SECOND-HAND]` |
| **Ro2D** | "High-Performance 2D Software Rendering & Physics Engine". Draws to `EditableImage` through contiguous memory buffers rather than Frames/ImageLabels. | https://devforum.roblox.com/t/open-source-ro2d-a-high-performance-2d-software-rendering-physics-engine-editableimage/4634716 (2026-05-13) | No numbers published in search summaries. | "Open source" per title; repo not located | `[COMMUNITY, SECOND-HAND]` |
| **Radius** | Physically-based path tracer using **parallel Luau + OSGL**. | https://devforum.roblox.com/t/radius-native-physically-based-and-performant-pathtracing-open-source/3547307 | — | Open source; **author has deprecated it** | `[COMMUNITY, SECOND-HAND]` |
| **Piotrekstel's Path Tracer** | Path tracer with diffuse/glossy/metallic/dielectric BSDFs, **Next Event Estimation and Multiple Importance Sampling**. | https://devforum.roblox.com/t/path-tracer-with-nee-and-mispiotrekstels-path-tracer/4568087 | — | Community resource | `[COMMUNITY, SECOND-HAND]` |
| **BloxPT** | Open-source path tracer: aperture/focal-length camera, BSDF node mixing, global illumination with caustics. | https://devforum.roblox.com/t/bloxpt-pathtracer-open-source/1363731 | — | Open source | `[COMMUNITY, SECOND-HAND]` |
| **Editable-Image-raycaster** | Port of 3DSage's classic raycaster engine, with textured walls. | https://github.com/TateoDev/Editable-Image-raycaster | — | **No licence file** | `[SOURCE-READ]` (README) |
| **A renderer using raycasting** | Raycaster projecting to `EditableImage` with adjustable interlacing. | https://devforum.roblox.com/t/a-renderer-using-raycasting-open-source/3609143 | **100×100**, interlaced | Open source | `[COMMUNITY, SECOND-HAND]` |
| **luau_term** | xterm-compatible terminal emulator. **Core is Roblox-free Luau** and runs under Lune; `src/canvas/bitmap.luau` renders to an RGBA buffer that drops straight into `EditableImage`. | https://github.com/mokiros/luau_term | 80×30 character grid in the example | Has a `tests/` suite run under Lune | `[SOURCE-READ]` (README) |
| **PixelRasterizer** | Real-time 2D pixel grid with dynamic lighting on EditableImage. | https://devforum.roblox.com/t/editableimage-pixelrasterizer-real-time-2d-pixel-grid-system-with-dynamic-lighting-editableimage-rendering/3881135 | — | Community resource | `[COMMUNITY, SECOND-HAND]` |
| **Lightspeed Shader System** | Fragment-shader-style system over EditableImage. | https://devforum.roblox.com/t/lightspeed-shader-system-using-editableimage/2762254 | — | Community resource | `[COMMUNITY, SECOND-HAND]` |
| **Y-Workplace/DissolveEffect** | Pixel-based dissolve with glowing edges and noise distortion. | https://github.com/Y-Workplace/DissolveEffect | — | **MIT** | `[SOURCE-READ]` (metadata) |
| **video-to-roblox** | Offline tool: MP4 → bit-packed frames for Roblox playback. | https://github.com/DeepXx86/video-to-roblox | — | No licence | `[SOURCE-READ]` (metadata) |

**The pattern across all of them:** *nothing* runs full-screen per-pixel at 1024×1024. The
credible real-time numbers sit at **100×100 to 320×240**. A full N64 emulator — arguably the most
compute-heavy EditableImage project in existence — chose **320×240 with a 160×120 fast path**.
Treat that as the practical envelope. `[INFERRED]` from `[SOURCE-READ]` + `[COMMUNITY, SECOND-HAND]`

---

### 1.6 Single-purpose utilities worth taking as-is

**boatbomber/EditableImageBlur** — https://github.com/boatbomber/EditableImageBlur

The cleanest small library in this space and a model for how to write one.

- *"This is a **pure buffer-manipulation library: it never touches an `EditableImage` itself**.
  Read the pixels, blur the buffer in place, and write it back."* `[SOURCE-READ]`
- API is two functions: `Blur(config)` and `BlurAsync(config)`, both mutating
  `config.pixelBuffer` in place and returning nothing. Config is
  `{pixelBuffer, width, height, blurRadius}`.
- **Licence: MPL-2.0.** Installable from Wally: `EditableImageBlur = "boatbomber/editableimageblur@1.0.0"`.
- Last pushed 2026-08-10; ~28 stars. `[SOURCE-READ]`

**Why this matters beyond blurring:** it demonstrates the correct seam for this whole domain.
*Image operations should take a `buffer` + dimensions and mutate in place.* They should not know
about `EditableImage`, `AssetService`, budgets, or frames. Write every filter this team needs to
that signature and they become testable outside Roblox (see luau_term running under Lune).

**plainenglishh/remote-image-library** — https://github.com/plainenglishh/remote-image-library

- Decodes **PNG** from remote URLs, binary strings, or pixel arrays into an `EditableImage`.
- Has **HTTP request queuing to avoid rate limits** and an overridable `http_get_async` so you can
  route through your own proxy. Works server-side and client-side. `[SOURCE-READ]`
- Its own README carries a TOS warning and notes that as of its writing **EditableImages do not
  replicate across the server→client boundary** — still true and still a common trap. `[SOURCE-READ]`
- Value to this team is mostly the **PNG decoder**, which is a non-trivial piece of code you do
  not want to write.

**ElixNoir/Roblox-Canvas** — https://github.com/ElixNoir/Roblox-Canvas — MIT, Luau.
A third canvas library with an unusual and genuinely interesting design philosophy, quoted from
its README: *"Functions prefixed with `draw` will always take a function to use as a **shader**
... Functions prefixed with `fill` will not use shaders and will often be faster."* A clean
naming convention separating the shader-callback path from the fast constant-colour path. Author
describes it as a work in progress and "mildly sloppy"; the **MIT licence** makes it the most
freely-reusable of the canvas libraries even so. `[SOURCE-READ]`

**Notable gaps in section 1.** Despite searching, I found **no** dedicated open-source Roblox
**minimap generator** on EditableImage, and **no** general image-filter/convolution kernel library
beyond boatbomber's blur. Those are small enough to write; just know that nothing is waiting for
you.

---

## 2. EditableMesh in the wild

`EditableMesh` prior art is **much thinner than `EditableImage` prior art.** That asymmetry is
itself the headline finding of this section. There is no mesh equivalent of CanvasDraw or OSGL —
no general-purpose, maintained, open-source geometry library that the community has converged on.
What exists is a scatter of single-purpose projects, plus Roblox's own first-party sample code.

**Why the asymmetry, most likely:** `EditableImage` gives you a *bulk* write
(`WritePixelsBuffer`), so Luau does all the work in a `buffer` and hands the engine one blob.
`EditableMesh` has **no bulk-write equivalent** — geometry is built with per-vertex and per-face
calls (`AddVertex`, `AddTriangle`, `SetPosition`, `SetFaceUVs`, …), each of which crosses the
Luau↔C++ boundary. That makes mesh construction fundamentally chattier and harder to make fast,
and it discourages library-building. `[INFERRED]` from `[DOCUMENTED]` API shape.

### 2.1 The documented contract (read this first)

From `Roblox/creator-docs` `EditableMesh.yaml`, read directly: `[DOCUMENTED]`

- **Limit: 60,000 vertices and 20,000 triangles per `EditableMesh`.** *"Attempting to add too many
  vertices or triangles will cause an error."* — a hard error, not degradation.
- **Stable IDs, not indices.** Vertex/normal/UV/colour/face IDs remain valid when other elements
  are removed, so the ID space is sparse with holes. **You must iterate `GetVertices()` /
  `GetFaces()`, not a numeric range.** `IdDebugString()` exists for debugging.
- **Fixed-size is the default when loading an asset.** `CreateEditableMeshAsync(content)` returns a
  `FixedSize = true` mesh: *"more efficient in terms of memory but you cannot change the number of
  vertices, faces, or attributes. Only the values of vertex attributes and positions can be
  edited."* Pass `{FixedSize = false}` to get a mutable-topology mesh — at a memory cost.
  `CreateEditableMesh()` (blank) is always `FixedSize = false`.
- **Split vertex attributes.** Normals, UVs and colours are *per-face-corner* IDs, not per-vertex,
  so two adjacent faces can share a position but have different normals (sharp edges) or different
  UVs (seams). This is the same model as a GPU vertex buffer with splits, and it is the part that
  most trips people up.
- **Winding determines facing** — front is visible when vertices go counter-clockwise.
- **Visual updates are free; collision updates are not.** *"Visual changes to the mesh will always
  be immediately reflected by the engine, without the need to call
  `AssetService:CreateMeshPartAsync()`."* To refresh **collision and fluid geometry** you must call
  `CreateMeshPartAsync()` then `MeshPart:ApplyMesh()`, and the docs explicitly say: *"It's
  generally recommended to do this at the end of a conceptual edit, not after individual calls to
  methods that manipulate geometry."*
- **Creation returns `nil` on budget exhaustion**, same as images: *"The new `EditableMesh`, or
  `nil` if the device-specific editable memory budget is exhausted."* `CreateMeshPartAsync` also
  documents that *"if the server storage budget is exhausted during this call, the creation
  fails."*
- **`FindVerticesWithinSphere()` and `GetAdjacentVertices()` / `GetAdjacentTriangles()` exist** —
  the engine gives you a spatial query and adjacency traversal for free. Do not write your own
  vertex k-d tree before checking whether `FindVerticesWithinSphere` is enough.
- Gating is identical to `EditableImage`: **13+, ID-verified, and "Enable Mesh / Image APIs"
  toggled on in the Creator Dashboard**, or it fails in published experiences.

### 2.2 Roblox's own first-party prior art: in-experience avatar creation

The single most authoritative `EditableMesh` reference implementation is Roblox's own.

| Field | Value |
| --- | --- |
| What it is | Roblox's documented pipeline for letting *players* sculpt and texture avatar bodies in-experience and publish them to their inventory. |
| URL | https://github.com/Roblox/creator-docs/blob/main/content/en-us/avatar/in-experience-creation.md · live demo: https://www.roblox.com/games/124012682058672/Roblox-Avatar-Creator |
| Confidence | `[DOCUMENTED]` — read the markdown source directly |

**What it demonstrates that nothing else does:**

- The **three-API combination**: `EditableImage` for texture editing, `EditableMesh` for geometry,
  and **`WrapDeformer`** for *"maintaining skinning and FACS data during mesh edits."* If you
  deform a rigged character mesh directly you destroy its skinning; the sanctioned pattern is to
  edit the **invisible outer cage mesh** and let `WrapDeformer` propagate the deformation to the
  skinned render mesh. This is non-obvious and is the correct answer to "how do I deform a
  character at runtime?".

  ```lua
  local wrapDeformer = Instance.new("WrapDeformer")
  wrapDeformer.Parent = meshPart
  local cageEditableMesh = AssetService:CreateEditableMeshAsync(
      Content.fromUri(wrapTarget.CageMeshId), { FixedSize = true })
  wrapDeformer:SetCageMeshContent(Content.fromObject(cageEditableMesh))
  ```

- **`FixedSize = true` used deliberately everywhere** in the sample, including for rigid meshes —
  Roblox's own code treats mutable topology as the exception, not the default.
- The rigid path — `CreateEditableMeshAsync(fromUri(meshPart.MeshId), {FixedSize = true})` →
  `CreateMeshPartAsync(fromObject(editableMesh))` → copy size/position/texture → `ApplyMesh` — is
  the canonical "load, edit, re-bake" loop.
- It also establishes that there is a **commercial** path: `AvatarCreationService`, avatar creation
  tokens purchased with Robux, Marketplace commissions to the experience owner. If runtime content
  generation is ever meant to be monetised, this is the only sanctioned rail.

**Take:** if your project touches characters, start from this document, not from a DevForum thread.

### 2.3 Water and ocean simulation — the most developed EditableMesh niche

This is, surprisingly, where the best `EditableMesh` engineering lives.

**Smurfis/RBLX-EditableMesh-Water-FirstPerson** — https://github.com/Smurfis/RBLX-EditableMesh-Water-FirstPerson

| Field | Value |
| --- | --- |
| What it is | A performance-focused first-person water system: multiple water bodies at different elevations, dry/exclusion volumes for caves, foam/splash/ripple/shoreline, buoyancy and wave-driven physics, shared water queries for swimming. |
| Stars / licence | 0 stars, **no licence declared** (so: read it, don't copy it). Lua. Actively pushed (latest 2026-09-17). |
| Confidence | `[SOURCE-READ]` (README via GitHub page) |

**The architecture is the value here**, and it is a template for *any* large procedural surface:

- Stated design principle: ***"The camera decides where rendering work is spent; the camera does
  not rotate the water itself."*** World-aligned geometry, camera-driven work allocation. This is
  the right instinct — camera-locked meshes swim and shimmer.
- **World-aligned, pooled `EditableMesh` chunks.** Chunks are *pooled and reused*, not created and
  destroyed — which is the only sane response to a hard ~8-object editable budget and a 22 ms
  `CreateMeshPartAsync` cost.
- **Camera position prioritises which chunks receive updates and at what LOD.** So the update
  budget, not just the triangle budget, is spent by distance.
- **A shared deterministic wave field** drives both visual deformation and object interaction, so
  physics and rendering cannot disagree.
- Chunks are instantiated from a `SurfaceAppearance` template so PBR settings come along for free.

**No performance numbers, triangle counts or chunk dimensions are published.** `[SOURCE-READ]`

Related, all `[COMMUNITY, SECOND-HAND]`:

| Project | URL | Note |
| --- | --- | --- |
| Y-Workplace/Liquid-Simulation | https://github.com/Y-Workplace/Liquid-Simulation | *"WebGL Water — ported to Roblox EditableMesh."* Luau, **no licence**, 0 stars, last push 2026-07-01. A direct port of the classic Evan Wallace WebGL water demo. |
| JONSWAP Ocean / Liquid | https://devforum.roblox.com/t/jonswap-ocean-liquid/3661760 | Ocean using the JONSWAP spectral density model with multiple simulation modes over `EditableMesh` parts. |
| Simulated Ocean with EditableMesh | https://devforum.roblox.com/t/simulated-ocean-with-editablemesh/3562339 | Gerstner-wave ocean, released publicly. |
| Realistic Water Simulation (skinned mesh) | https://devforum.roblox.com/t/realistic-water-simulation-script-skinned-mesh-free-open-source/3144149 | The *pre-EditableMesh* approach — skinned mesh deformation. Worth knowing as the fallback. |

### 2.4 Terrain and voxels

**The finding here is negative and important: I could not locate a single open-source
marching-cubes or greedy-meshing implementation that targets `EditableMesh`.** Community threads
show people *attempting* it; no maintained library resulted.

What does exist:

| Project | URL | What it is | Licence | Confidence |
| --- | --- | --- | --- | --- |
| **TheArturZh/RTerrainGenerator** | https://github.com/TheArturZh/RTerrainGenerator | Procedural terrain generator that **deliberately avoids Roblox's built-in Terrain**. Generates heightmap terrain **plus rivers, lakes and forests**, using **exponentially-distributed Perlin noise with domain warping**. Rojo project with a Makefile build; prebuilt `.rbxlx`/`.rbxm` in Releases. | **MIT** (with a clearly-explained attribution expectation) | `[SOURCE-READ]` |
| **tiffany352/Roblox-Terrain-Generator** | https://github.com/tiffany352/Roblox-Terrain-Generator | Terrain generator *framework*. Author's own warning: *"very much a work in progress ... exists mostly as a reference that others can use for their own code, rather than as a production ready terrain generator."* Goals: very fast; smooth terrain primary, bloxel Part terrain supported; plugin pre-generation **or real-time client-side generation.** | **MIT** | `[SOURCE-READ]` |
| Marching Cubes Voxel Terrain with Tools | https://devforum.roblox.com/t/marching-cubes-voxel-terrain-with-tools/602593 | Real-time editable marching-cubes terrain, **reported running at 60 fps** with chunks that update their neighbours. Predates `EditableMesh`. | — | `[COMMUNITY, SECOND-HAND]` |
| Octree AND Greedy Meshing Voxel Simulation | https://devforum.roblox.com/t/octree-and-greedy-meshing-voxel-simulation/3505477 | Octree + greedy meshing voxel demo. | — | `[COMMUNITY, SECOND-HAND]` |
| Greedy Meshing Voxels / "Consume everything" tutorial | https://devforum.roblox.com/t/greedy-meshing-voxels/1139881 · https://devforum.roblox.com/t/consume-everything-how-greedy-meshing-works/452717 | The community's reference explanations of greedy meshing on Roblox. | — | `[COMMUNITY, SECOND-HAND]` |
| Mesh Voxelizer (MeshPart → Voxels) | https://devforum.roblox.com/t/mesh-voxelizer-meshpart-%E2%86%92-voxels/4523856 | Plugin converting MeshParts to voxels with greedy meshing. | — | `[COMMUNITY, SECOND-HAND]` |
| Procedural terrain generation using EditableMeshes in parallel | https://devforum.roblox.com/t/procedural-terrain-generation-using-editablemeshes-in-parrallel/4582100 | Thread specifically on driving `EditableMesh` terrain from parallel Luau Actors. | — | `[COMMUNITY, SECOND-HAND]` |
| Generating a chunk using EditableMesh | https://devforum.roblox.com/t/generating-a-chunk-using-editablemesh/3386346 | Chunk-per-`EditableMesh` rendering to replace per-voxel Parts, with hidden-face culling discussion. | — | `[COMMUNITY, SECOND-HAND]` |
| Procedural Polygonal Terrain Generation | https://devforum.roblox.com/t/procedural-polygonal-terrain-generation-make-low-poly-terrain-with-ease/753007 | Low-poly terrain generator. | — | `[COMMUNITY, SECOND-HAND]` |

**Arithmetic you should do before designing a voxel system.** With the documented 20,000-triangle
cap and greedy meshing, a chunk is roughly 16×16×16 voxels before you risk the cap on
worst-case (checkerboard) content: a fully-exposed 16³ chunk face-set is 16·16·6 = 1,536 quads =
3,072 triangles at best, but pathological interiors can multiply that by 4–6×. With the ~8-object
client budget, **you cannot have 8+ chunks live as separate `EditableMesh` objects at once** —
you must bake each chunk to a `MeshPart` via `CreateMeshPartAsync` and release the editable.
`[INFERRED]` from `[DOCUMENTED]` limits.

### 2.5 Deformation, destruction, CSG, wireframe, LOD

| Topic | What exists | Confidence |
| --- | --- | --- |
| **Character deformation** | `WrapDeformer` + cage `EditableMesh`, per Roblox's own avatar docs (§2.2). This is the sanctioned path and there is no third-party library. | `[DOCUMENTED]` |
| **Destruction** | Only DevForum discussion: https://devforum.roblox.com/t/creating-a-destruction-system-using-editable-meshes/3158370 . The reported technique is to **delete the vertices inside a hitbox** — which requires `FixedSize = false` and therefore the expensive memory mode, and leaves you to cap the hole yourself. **No open-source destruction library exists.** | `[COMMUNITY, SECOND-HAND]` |
| **Generic deformation** | https://devforum.roblox.com/t/editable-mesh-deformation/3393375 . Discussion only. | `[COMMUNITY, SECOND-HAND]` |
| **Wireframe / debug draw** | **Wyreframe** — a wireframe rendering module: https://devforum.roblox.com/t/wyreframe-wireframe-rendering-module/4178859 . Also **jaipack17/Gizmo2D** (https://github.com/jaipack17/Gizmo2D) for GUI-space visual debugging. Community consensus is that real wireframes come from `LineHandleAdornment` or `EditableMesh`, not from a render mode. | `[COMMUNITY, SECOND-HAND]` |
| **Runtime CSG** | **Nothing.** No open-source runtime CSG on `EditableMesh` was found. Roblox's legacy `Geometry`/`SolidModel` CSG API is a separate, unrelated system. This is a genuine gap. | `[INFERRED]` from absence |
| **LOD / decimation** | **Nothing at the library level.** Roblox instead does **cloud-generated LOD**: on upload, Roblox's servers generate 3–4 progressively simpler versions per `MeshPart`, reported to reduce polygon counts by **25–75%** while preserving silhouette, UVs and material boundaries. **A runtime-generated `EditableMesh` does not go through that pipeline**, so a procedural mesh has *no* LODs unless you build them. | `[COMMUNITY, SECOND-HAND]` for the 25–75% figure (https://www.creation.dev/learn/roblox-mesh-streaming-cloud-lod-optimization-guide); the *absence* is `[INFERRED]` |
| **Blender ↔ Studio live sync** | **RullzVyline/VectorFlow** — https://github.com/RullzVyline/VectorFlow — MIT, Python, real-time Blender↔Roblox Studio sync. Useful for an authoring workflow, not a runtime one. | `[SOURCE-READ]` (metadata) |
| **Runtime asset import** | **gigabyteworkstation/gta5-roblox-vehicles** — https://github.com/gigabyteworkstation/gta5-roblox-vehicles — Rust backend streaming external meshes/textures into Roblox at runtime through a Luau `EditableMesh` client. No licence. Legally fraught, but architecturally it is a proof that **a server-side mesh pipeline feeding `EditableMesh` over HTTP works.** | `[SOURCE-READ]` (metadata) |
| **Mesh editing plugin** | **MeshCreator** — https://devforum.roblox.com/t/meshcreator-edit-meshes-easily-with-free-plugin/2788604 — free plugin to create/modify meshes in Studio via `EditableMesh`. Studio-time, unlimited memory, so it sidesteps the client budget entirely. | `[COMMUNITY, SECOND-HAND]` |

### 2.6 The cost model for mesh work

Two numbers dominate everything in this section and both come from outside Roblox's docs:

- **`AssetService:CreateMeshPartAsync()` costs a reported fixed ~22 ms plus ~0.27 ms per 1,000
  triangles — *even with* `CollisionFidelity.Box` and `CanCollide = false`.**
  Source: https://devforum.roblox.com/t/allow-applying-baked-mesh-content-to-a-meshpart-without-a-lag-spike/4752538
  (2026-07-23). `[COMMUNITY, SECOND-HAND]`
  **At 60 fps a frame is 16.67 ms, so the *fixed* cost alone blows a frame** before a single
  triangle is counted. A 20,000-triangle mesh would be ≈ 22 + 5.4 = **27.4 ms**. `[INFERRED]`
- The same thread's framing — that there is **no way to apply baked mesh `Content` to a `MeshPart`
  without going through `CreateMeshPartAsync`**, because `MeshPart.MeshContent` is not assignable
  and `MeshPart:ApplyMesh()` does not accept `Content` — means **this cost is unavoidable** today.
  `[COMMUNITY, SECOND-HAND]`

**Design consequence:** budget *one* `CreateMeshPartAsync` call per frame at most, amortise it,
and never call it in a loop over chunks. Pool `MeshPart`s and `EditableMesh`es. Do visual-only
edits (which are free and immediate) as often as you like; re-bake collision rarely.
`[INFERRED]` from `[DOCUMENTED]` + `[COMMUNITY, SECOND-HAND]`

