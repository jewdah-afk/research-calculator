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

---

## 3. Reusable Luau libraries

The infrastructure layer of the Roblox ecosystem is genuinely mature. The *procedural-generation*
layer is not. This section separates the two so you know where to shop and where to build.

> **Sourcing note:** `wally.run` is **egress-blocked** from this environment, so I could not read
> the registry directly. Wally package coordinates below come from the libraries' own READMEs,
> which is a stronger source anyway. Install with Wally
> (https://github.com/UpliftGames/wally) unless noted.

### 3.1 The one platform capability nobody advertises: native compression and hashing

`EncodingService` is a first-party Roblox service that most developers do not know exists, and it
removes the need for a third-party compression library entirely. `[DOCUMENTED]`

- `EncodingService:CompressBuffer(input: buffer, algorithm, compressionLevel: int = 1): buffer`
  — *"For `Enum.CompressionAlgorithm.Zstd`, the allowed compression values are **from −7 to 22
  inclusive**."* `Zstd` is currently the **only** member of `Enum.CompressionAlgorithm`.
- `EncodingService:DecompressBuffer(...)`
- `EncodingService:Base64Encode` / `Base64Decode`
- `EncodingService:ComputeBufferHash` / `ComputeStringHash` (cryptographic hashes)
- **`thread_safety: Safe`** — usable from parallel code.

Source: https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EncodingService.yaml
and `.../enums/CompressionAlgorithm.yaml` `[DOCUMENTED]`

CanvasDraw already relies on this for DataStore-friendly image persistence. `[SOURCE-READ]`
**Take:** for any binary payload — heightmaps, chunk data, saved canvases, replay buffers — use
`EncodingService` + `buffer` and do not write or import an LZW/deflate module.

### 3.2 Procedural generation — thin, but one strong find

**writebits/Fast-Noise** — https://github.com/writebits/Fast-Noise — **MIT** — `[SOURCE-READ]`

The best noise library found, and the only one with an architecture worth documenting:

- **9 noise types**: Perlin, Value, FBM, Billow, Ridged (multifractal), Worley/cellular, Voronoi,
  Turbulence, Domain Warp. 2D **and** 3D for all of them.
- **Built with `--!strict`, `--!native` *and* `--!optimize 2`** — the same triple that OSGL uses.
- One module per noise type (`Perlin.lua`, `Worley.lua`, `DomainWarp.lua`, …) plus an
  `Examples/TerrainGenerator.lua`.
- Fully typed, fully seedable, configurable octaves/lacunarity/persistence.
- Its own performance guidance: **use `.create()` to pre-configure a generator; cache samplers
  rather than constructing per frame; reduce octaves; prefer Value noise over Perlin when quality
  is not critical.** `[SOURCE-READ]`

Worth knowing that **`math.noise`** is built into Roblox (Perlin, 1D/2D/3D) and needs no library
at all for simple cases. `[DOCUMENTED]`

Beyond noise, procedural generation is a build-it-yourself area. The two terrain projects in §2.4
(`TheArturZh/RTerrainGenerator`, MIT; `tiffany352/Roblox-Terrain-Generator`, MIT) are *reference
implementations*, not dependencies. `RTerrainGenerator`'s technique — **exponentially-distributed
Perlin noise with domain warping**, yielding rivers/lakes/forests, not just a heightfield — is the
most transferable idea in either. `[SOURCE-READ]`

**No maintained Luau library was found for:** marching cubes, dual contouring, greedy meshing,
Poisson-disc sampling, wave-function collapse, Delaunay/Voronoi *meshing* (as opposed to Voronoi
*noise*), convex hulls, or mesh boolean operations. `[INFERRED]` from absence.

### 3.3 Spatial partitioning and queries

| Library | Note |
| --- | --- |
| **Sleitnick/rbxts-octo-tree** (https://github.com/Sleitnick/rbxts-octo-tree) | Octree. `topRegionSize` defaults to **512** (512×512×512 top-level regions). Has `ChangeNodePosition`, but the docs warn it is *"a fairly expensive operation ... usually beneficial to keep most nodes as static as possible."* Explicit framing: Roblox's own `GetPartBoundsInRadius` is generalised; a purpose-built octree beats it for specific use-cases. `[COMMUNITY, SECOND-HAND]` |
| **sayhisam1/Octree** (https://github.com/sayhisam1/Octree) | Pure-Lua octree for Roblox with radius search and nearest-neighbour queries. `[COMMUNITY, SECOND-HAND]` |
| **Quenty/NevermoreEngine `Octree`** (https://quenty.github.io/NevermoreEngine/api/Octree/) | Octree inside the large Nevermore monorepo. `[COMMUNITY, SECOND-HAND]` |
| **LDGerrits/QuickZone** (https://github.com/LDGerrits/QuickZone) | *"High-performance, physics-free spatial query library."* MIT, Luau, ~51 stars, pushed 2026-09-11. The freshest option. `[SOURCE-READ]` (metadata) |
| **`EditableMesh:FindVerticesWithinSphere()`** | Built into the engine — check this before importing a spatial structure for mesh work. `[DOCUMENTED]` |

### 3.4 Serialization, buffers and networking

| Library | Note |
| --- | --- |
| **Data-Oriented-House/Squash** (https://github.com/Data-Oriented-House/Squash) | *"A simple but comprehensive SerDes library for Roblox, aimed at minimizing bandwidth and saving space."* Docs at https://data-oriented-house.github.io/Squash/ . Wally: `data-oriented-house/squash`. Single-file `src/init.lua` copy-paste also supported. **The most complete SerDes library found.** `[SOURCE-READ]` |
| **ffrostfall/ByteNet** (https://github.com/ffrostfall/ByteNet) | MIT, Luau, ~181 stars. Networking library that serialises Luau data into `buffer`s and deserialises at the far end. Strict Luau, roblox-ts support. Last push 2025-08-01. `[SOURCE-READ]` (metadata) |
| **Sleitnick/RbxUtil → `BufferUtil`, `Stream`, `Ser`** | `BufferUtil = "sleitnick/buffer-util@0.3.2"`; `Stream = "sleitnick/stream@0.1.1"` (*"Stream abstraction wrapper around buffers"*); `Ser = "sleitnick/ser@1.0.5"`. `[SOURCE-READ]` |
| **chadhyatt/LuaEncode** (https://github.com/chadhyatt/LuaEncode) | MIT. *"Fast table serialization library for pure Luau/Lua 5.1+."* Human-readable/table-literal output rather than binary. `[SOURCE-READ]` (metadata) |
| **YetAnotherNet** (https://yetanotherclown.github.io/YetAnotherNet/) | Auto-compresses into buffers; internal Ser/Des for all Luau datatypes and most Roblox datatypes. `[COMMUNITY, SECOND-HAND]` |

### 3.5 Lifecycle, signals, promises, async

| Library | Note |
| --- | --- |
| **howmanysmall/Janitor** (https://github.com/howmanysmall/Janitor) | MIT, Luau, ~149 stars, pushed 2026-07-28. The de-facto cleanup object. `[SOURCE-READ]` (metadata) |
| **Sleitnick/Trove** (in RbxUtil) | The other common cleanup helper; ships as an RbxUtil module. `[SOURCE-READ]` |
| **evaera/roblox-lua-promise** (https://github.com/evaera/roblox-lua-promise) | Promise/A+-style promises. Docs: https://eryn.io/roblox-lua-promise/ . Wally: `evaera/promise`. The ecosystem standard; Lapis and others are built on it. `[SOURCE-READ]` |
| **AlexanderLindholt/SignalPlus** (https://github.com/AlexanderLindholt/SignalPlus) | MIT, *"exceptionally fast signal library for Luau"*, ~37 stars, pushed 2026-09-05. `[SOURCE-READ]` (metadata) |
| **Sleitnick/RbxUtil → `Signal`, `Concur`, `Option`, `Sequent`** | `Signal = "sleitnick/signal@2.0.3"`, `Concur = "sleitnick/concur@0.1.2"` (concurrent task handler), `Option = "sleitnick/option@1.0.5"`. `[SOURCE-READ]` |
| **ActorGroup2** (https://devforum.roblox.com/t/actorgroup2-asynchronous-parallel-luau-made-easy/3412330) | *"Asynchronous parallel Luau made easy."* The only parallel-Luau worker-pool helper surfaced. `[COMMUNITY, SECOND-HAND]` |

### 3.6 Data and persistence

| Library | Note |
| --- | --- |
| **MadStudioRoblox/ProfileStore** (https://github.com/MadStudioRoblox/ProfileStore) | The successor to ProfileService, by loleris. Single ModuleScript. **Session locking** across servers via DataStore + MessagingService, auto-save, dupe prevention. Author is explicit: *"ProfileStore is not designed (and never will be) for in-game leaderboards or any kind of global state."* Wally: `2jammers/profilestore`. `[SOURCE-READ]` |
| **nezuo/lapis** (https://github.com/nezuo/lapis) | The strongest alternative and arguably the better-engineered one: session locking, **schema validation**, **migrations**, retries, DataStore budget throttling, Promise-based API, **deep-frozen immutable documents by default**, **save batching** (pending `save()`/`close()` merged into one request), 5-minute auto-save, `BindToClose`. `[SOURCE-READ]` |

### 3.7 UI frameworks

| Library | Note |
| --- | --- |
| **jsdotlua / core-packages React-lua** (https://github.com/jsdotlua/CorePackages · Wally `core-packages/react-roblox`) | A real port of React. **Roblox itself ships it in their apps and core scripts.** The safest large-project choice. `[COMMUNITY, SECOND-HAND]` |
| **Elttob/Fusion** (https://github.com/Elttob/Fusion) | *"Futuristic Luau for every universe"* — reactive state/UI, batteries-included on Roblox but portable to plain Luau. `[SOURCE-READ]` |
| **centau/vide** (https://github.com/centau/vide) | MIT, ~324 stars, pushed 2026-08-05. *"A reactive Luau library for creating UI."* Solid-style fine-grained reactivity. `[SOURCE-READ]` (metadata) |
| **SirMallard/Iris** (https://github.com/SirMallard/Iris) | MIT, ~349 stars, pushed 2026-09-04. **Immediate-mode GUI based on Dear ImGui.** For a procedural-generation team this is the highest-value UI pick: debug panels and parameter sliders in three lines, no state plumbing. `[SOURCE-READ]` (metadata) |
| **AlexanderLindholt/TextPlus** (https://github.com/AlexanderLindholt/TextPlus) | MIT, ~31 stars, pushed 2026-09-14. Efficient text rendering. `[SOURCE-READ]` (metadata) |
| **latte-soft/lucide-roblox** (https://github.com/latte-soft/lucide-roblox) | Lucide icon set for Roblox. `[SOURCE-READ]` (metadata) |

### 3.8 Architecture: ECS, frameworks, immutable data

| Library | Note |
| --- | --- |
| **Ukendio/jecs** (https://github.com/Ukendio/jecs) | *"Just a stupidly fast Entity Component System."* Archetype/SoA column-major storage, entity relationships as first-class, type-safe Luau, zero dependencies, unit-tested in CI. **Claims: "Iterate 800,000 entities at 60 frames per second."** `[SOURCE-READ]` — self-reported benchmark. |
| **centau/ecr** (https://github.com/centau/ecr) | MIT, ~60 stars, pushed 2026-09-03. Sparse-set ECS for Luau. `[SOURCE-READ]` (metadata) |
| **matter-ecs/matter** (https://github.com/matter-ecs/matter) | ECS with a strong debugger; CI + docs workflows. `[SOURCE-READ]` |
| **Sleitnick/Knit** (https://github.com/Sleitnick/Knit) | MIT, ~630 stars — the most-starred Roblox framework — but **last pushed 2024-07-31**. Widely used, effectively in maintenance. Treat as legacy. `[SOURCE-READ]` (metadata) |
| **cxmeel/sift** (https://github.com/cxmeel/sift) | MIT, ~92 stars. Immutable data library for Luau. Successor in spirit to `freddylist/llama` (MIT, last pushed **2022** — dead). `[SOURCE-READ]` (metadata) |
| **Sleitnick/RbxUtil** (https://github.com/Sleitnick/RbxUtil) | A monorepo of ~23 independently-Wally-published modules: `Comm`, `Component`, `Concur`, `EnumList`, `Input`, `Loader`, `Net`, `Option`, `PID`, **`Quaternion`**, `Query`, `Ser`, `Shake`, `Signal`, `Silo`, **`Spring`** (critically-damped), `Stream`, `Streamable`, `Symbol`, `BufferUtil`, `Find`, `Log`, `Sequent`. CI and docs badges green. **Best single source for small utilities.** `[SOURCE-READ]` |

### 3.9 Maths, physics, geometry

| Library | Note |
| --- | --- |
| **RbxUtil `Quaternion`** (https://github.com/Sleitnick/RbxUtil/blob/main/modules/quaternion/init.luau) | `sleitnick/quaternion@0.2.3`. The only maintained quaternion type found. `[SOURCE-READ]` |
| **RbxUtil `Spring`** | `sleitnick/spring@1.0.0`, critically-damped spring. `[SOURCE-READ]` |
| **jaipack17/Nature2D** (https://github.com/jaipack17/Nature2D) | MIT, Lua, ~182 stars, pushed 2025-12-11. 2D physics engine for Roblox (verlet/constraint style, UI-space). `[SOURCE-READ]` (metadata) |
| **daftcube/orbitlib** (https://github.com/daftcube/orbitlib) | Two-body orbital mechanics. **AGPL-3.0** — viral licence, last pushed 2022. Probably unusable commercially. `[SOURCE-READ]` (metadata) |
| **Ro2DEngine built-ins** | AABB collision, radial/orbital physics, gravity, SDF circles/lines — MIT, see §1.5/§4. `[SOURCE-READ]` |
| **Nothing found** | No maintained general 3D geometry kernel (plane/ray/triangle intersection, convex hull, polygon triangulation, mesh boolean). This is the biggest single gap in the maths ecosystem. `[INFERRED]` |

### 3.10 Pathfinding

Roblox ships `PathfindingService` (navmesh-based) for the common case. Beyond it:

| Library | Note |
| --- | --- |
| **Yonaba/Jumper** (https://github.com/Yonaba/Jumper) | Grid-based pathfinding in **pure Lua**, framework-agnostic, multiple search algorithms, chaining API. Not Roblox-specific and not recently maintained, but it ports cleanly. `[COMMUNITY, SECOND-HAND]` |
| **lance0805/a-star-lua** (https://github.com/lance0805/a-star-lua) | Minimal dependency-free A* taking a node table, start/goal and a `valid neighbour` function. Good starting point for a custom graph. `[COMMUNITY, SECOND-HAND]` |
| **EZ Pathfinding V5** (https://devforum.roblox.com/t/ez-pathfinding-v5/1533902) | OOP Roblox pathfinding module. `[COMMUNITY, SECOND-HAND]` |

### 3.11 Testing and tooling

| Tool | Note |
| --- | --- |
| **jsdotlua/jest-lua** (https://github.com/jsdotlua/jest-lua) | *"Roblox uses Jest Lua internally for testing their apps, in-game core scripts, built-in Roblox Studio plugins, as well as libraries like Roact Navigation. This library should be considered battle-tested and ready for production use."* Wally dev-dependency `jsdotlua/jest-globals`. **Roblox-only today** — it cannot yet run under Lune. `[SOURCE-READ]` |
| **Lune** (used by `mokiros/luau_term` for its test suite) | Standalone Luau runtime. If you keep your generation code free of Roblox globals, you can unit-test it **outside Studio** — luau_term proves this is practical. `[SOURCE-READ]` |
| **Rojo** (https://rojo.space) + **rokit**/**aftman** | Filesystem↔Studio sync and toolchain pinning. Every serious project in this chapter uses them. `[SOURCE-READ]` |
| **Wally** (https://github.com/UpliftGames/wally) | Cargo-inspired package manager. Registry front-end `wally.run` was unreachable from here. `[COMMUNITY, SECOND-HAND]` |
| **Scythe-Technology/luau-roblox** (https://github.com/Scythe-Technology/luau-roblox) | MIT, ~30 stars. Luau library to read/write Roblox place and model files — useful for offline asset pipelines. `[SOURCE-READ]` (metadata) |
| **officialmmt/OpenRoblox** (https://github.com/officialmmt/OpenRoblox) | A maintained index of Roblox tools and libraries — a good place to look next. `[COMMUNITY, SECOND-HAND]` |

---

## 4. Benchmarks — every concrete number I could find

This is the section the chapter exists for. Read the confidence markers; they are load-bearing.

### 4.0 The single best benchmark source found: `nightcycle/roblox-benchmarks`

- Repo: https://github.com/nightcycle/roblox-benchmarks
- Data: https://github.com/nightcycle/roblox-benchmarks-data (`src/summary.csv`, ~18 KB; `src/all.csv`, ~40 MB)
- Dashboard: https://nightcycle.github.io/roblox-benchmarks/
- Confidence: `[SOURCE-READ]` — **I downloaded and analysed `summary.csv` directly.**

**Why it is credible:** it is CI-driven, not hand-rolled. Benchmarks are Luau modules declaring
typed parameters, a body, a repeat count and a sample count; a GitHub Action builds an `.rbxl`,
publishes it, runs **50 separate Luau execution sessions** to de-skew, appends per-sample rows to
CSV, and a Lune script summarises. It credits boatbomber's `Benchmarker` plugin as its ancestor.

**Its own caveat, which I am repeating because it matters:** *"these benchmarks ought to be used
for their **comparative** value (X is faster than Y) rather than as an exact speed (X takes 20
microseconds)."* They also run **on a Roblox server**, not on a player device, and — importantly
for us — **the benchmark modules are `--!strict` but not `--!native`.**

**Unit inference.** The CSV does not document its unit. Across ~60 rows the only internally
consistent reading is that **the value divided by 1,000 is nanoseconds per operation**
(e.g. `math.noise(x,y)` → 62.6 ns; `buffer.writeu32` → 36.9 ns; an `EditableImage` rectangle draw
→ 9.6 µs median). Any other scaling produces physically impossible results. I use that reading
below and mark every derived figure `[INFERRED]`.

#### 4.0.1 Measured Luau primitive costs (mean, ns/op under the inference above)

| Operation | ns/op | Confidence |
| --- | --- | --- |
| `local` variable write | 18.9 | `[SOURCE-READ]` + `[INFERRED]` unit |
| `local` variable read | 19.5 | ″ |
| `if`-based max / min | 19.8 / 19.8 | ″ |
| call a local function | 21.1 | ″ |
| float add / integer add | 21.4 / 21.5 | ″ |
| divide / subtract / multiply (number) | 21.4 / 21.5 / 21.8 | ″ |
| `math.exp` | 22.1 | ″ |
| **Vector3 add / sub / mul / div** | **22.4 / 22.9 / 23.0 / 22.5** | ″ |
| `if`-based clamp | 23.3 | ″ |
| comparison operators (`<`,`>`,`<=`,`>=`) | 23.6 | ″ |
| table array read | 24.2 | ″ |
| `math.round` / `math.sqrt` / `math.ceil` / `math.floor` | 25.0 / 25.2 / 25.2 / 25.2 | ″ |
| `math.max` / `math.min` (function form) | 25.4 / 25.5 | ″ |
| table array write | 25.6 | ″ |
| `==` / `~=` | 26.5 / 26.2 | ″ |
| `typeof` / `type` | 27.3 / 27.3 | ″ |
| all `bit32` ops (`band`, `bor`, `bxor`, shifts, rotates, counts) | 27.4 – 28.8 | ″ |
| `math.clamp` (function form) | 27.8 | ″ |
| `bit32.extract` | 32.0 | ″ |
| `Vector3.new` | 32.1 | ″ |
| `assert` | 33.3 | ″ |
| **`buffer.read*` — u8, u16, u32, i8, i16, i32, f32, f64** | **33.4 – 34.0 (flat)** | ″ |
| **`buffer.write*` — u8, u16, u32, i16, f32, f64, i8, i32** | **36.9 – 37.4 (flat)** | ″ |
| default-argument function call | 37.8 | ″ |
| function stored in a table | 44.1 | ″ |
| `buffer.len` | 44.1 | ″ |
| method call on a class | 42.7 | ″ |
| **metatable method dispatch** | **49.4** | ″ |
| **`math.noise` 1D / 2D / 3D** | **62.7 / 62.6 / 64.6** | ″ |
| `buffer.readbits` / `writebits` | 58.5 / 61.8 | ″ |
| `buffer.copy` / `buffer.fill` / `buffer.writestring` | 60.0 / 60.0 / 59.4 | ″ |
| **`Vector2` add** | **56.2** | ″ |
| `buffer.readstring` | 114.3 | ″ |
| `buffer.create` | 168.8 | ″ |
| `buffer.fromstring` | 177.8 | ″ |
| `buffer.tostring` | 205.3 | ″ |

#### 4.0.2 The seven conclusions that fall out of that table

1. **`buffer` read/write cost is flat across widths.** A `writeu8` costs the same ~37 ns as a
   `writeu32`. **Therefore packing RGBA into one u32 write is a straight ~4× win over four u8
   writes** — which is exactly what FastCanvas, CanvasDraw and OSGL all do. This is the numeric
   justification for the convergent architecture in §1.1. `[INFERRED]` from `[SOURCE-READ]`
2. **`Vector3` is ~2.5× faster than `Vector2`** (22.4 ns vs 56.2 ns per add). `Vector3` is a
   native Luau value type; `Vector2` is not. **In hot loops, use `Vector3` with `z = 0` instead of
   `Vector2`.** `[INFERRED]` from `[SOURCE-READ]`
3. **Metatable dispatch costs ~2.3× a local function call** (49.4 vs 21.1 ns). This is why both
   major canvas libraries build closure-based objects instead of `setmetatable` classes.
   `[INFERRED]` from `[SOURCE-READ]`
4. **`buffer.copy` has a ~60 ns fixed cost.** Combined with the ~37 ns per-pixel write, FastCanvas's
   doubling span-fill for a 1024-pixel scanline costs ≈ 10 × 60 ns = **0.6 µs** versus
   1024 × 36.9 ns = **37.8 µs** for the naive loop — a **~63× speed-up**, and the gap widens with
   span length. `[INFERRED]` from `[SOURCE-READ]`
5. **Bit-packed buffer fields cost ~1.7× aligned ones** (`writebits` 61.8 vs `writeu32` 36.9).
   Don't bit-pack in the inner loop; pack at the serialisation boundary instead.
6. **`buffer.create` (169 ns) and the string conversions (114–205 ns) are 3–6× a scalar op.**
   Allocate buffers once and pool them; never `buffer.tostring` per frame.
7. **`math.noise` costs ~63 ns regardless of dimension** — roughly 1.7× a `buffer.write`. A
   1024×1024 single-octave noise field is ≈ 1M × 63 ns = **66 ms**; 4 octaves ≈ **264 ms**.
   Noise generation is not a per-frame operation at image resolution. `[INFERRED]`

#### 4.0.3 Measured `EditableImage` draw costs — the only real EditableImage benchmark found

These rows are `client/instance/editable-image/...`, run with `repeats = 1` over ~9,990 samples
across 10 runs. They measure Roblox's **built-in** `EditableImage` draw methods.

| Metric | min | p10 | **median** | mean | p90 | p99 | max | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `EditableImage` **DrawRectangle** | 0.042 µs | 0.44 µs | **9.62 µs** | 25.87 µs | 73.2 µs | 172.6 µs | 436.8 µs | `[SOURCE-READ]` + `[INFERRED]` unit |
| `EditableImage` **DrawLine** | 0.015 µs | 0.10 µs | **0.37 µs** | 0.49 µs | 0.96 µs | 2.33 µs | 7.91 µs | ″ |

**The distribution is the finding, not the median.** DrawRectangle's standard deviation
(37.4 µs) is **larger than its mean** (25.9 µs) and its max is **10,500× its min**. Cost scales
with the rectangle's area and the parameters were randomised, so this is a cost *curve*, not a
cost. Any "EditableImage is fast/slow" claim that quotes a single number is meaningless.

**Frame budgets derived from those medians** (60 fps ⇒ 16.67 ms/frame), assuming nothing else
runs in the frame:

| Budget | At median | At p90 | Confidence |
| --- | --- | --- | --- |
| Built-in `DrawRectangle` calls per frame | ≈ **1,730** | ≈ **228** | `[INFERRED]` |
| Built-in `DrawLine` calls per frame | ≈ **44,800** | ≈ **17,300** | `[INFERRED]` |
| Raw `buffer.writeu32` pixel writes per frame | ≈ **451,000** | — | `[INFERRED]` (16.67 ms ÷ 36.9 ns) |
| ⇒ full-canvas repaints per frame at 256×256 (65,536 px) | ≈ **6.9** | — | `[INFERRED]` |
| ⇒ full-canvas repaints per frame at 512×512 (262,144 px) | ≈ **1.7** | — | `[INFERRED]` |
| ⇒ full-canvas repaints per frame at 1024×1024 (1,048,576 px) | ≈ **0.43** | — | `[INFERRED]` |

**Read the last three rows carefully.** Writing every pixel of a 1024×1024 canvas *once*, with
zero shading maths and nothing else in the frame, takes roughly **2.3 frames** at the measured
non-native `buffer.write` rate. A 512×512 full repaint consumes **~58% of a 60 fps frame** before
you compute a single colour. **512×512 is the outer limit for a full per-pixel repaint per frame,
and 256×256 is the comfortable one.** That is independently consistent with every shipped project
in §1.5 (100×100 … 320×240). `[INFERRED]`

*Caveat that cuts the other way:* the benchmark suite is **not `--!native`**. Roblox's own native
codegen docs state that *"with native code generation, there is zero overhead to using the buffer
library, making it just as fast, if not faster, than tables."* Real canvas libraries all set
`--!native`, so their per-pixel cost is plausibly lower than 36.9 ns. **Re-measure with
`--!native` on your target device before trusting the ceilings above.** `[DOCUMENTED]` +
`[INFERRED]`

---

### 4.1 `[DOCUMENTED]` — Roblox's own numbers

| Metric | Value | Source |
| --- | --- | --- |
| `EditableImage` maximum size | **1024 × 1024**, read-only, cannot be resized | `EditableImage.yaml` §`Size` |
| `EditableImage` displayed-update rate | **1 per frame**. "If you update three `EditableImage` objects which are currently being displayed, it will take three frames for all of them to be updated." | `EditableImage.yaml` §Update Limitations |
| `EditableImage` coordinate origin | top-left `(0,0)`; bottom-right `(Size.X-1, Size.Y-1)` | `EditableImage.yaml` |
| `EditableMesh` maximum vertices | **60,000** | `EditableMesh.yaml` §Limitations |
| `EditableMesh` maximum triangles | **20,000** | `EditableMesh.yaml` §Limitations |
| Behaviour on exceeding either | **throws an error** | `EditableMesh.yaml` |
| `CreateEditableImage` / `CreateEditableMesh` on budget exhaustion | **returns `nil`** (does not throw) | `AssetService.yaml` |
| `CreateMeshPartAsync` on server-storage-budget exhaustion | **creation fails** | `AssetService.yaml` |
| Editable memory budget scope | **client-side budget is strict; server, Studio and plugins have unlimited memory** | `EditableImage.yaml` / `EditableMesh.yaml` §Memory Limits |
| Frame budget at 60 FPS | **16.67 ms** ("Even seemingly minor per-frame calculations can use a significant portion of that budget.") | `performance-optimization/design.md` |
| **Draw-call budget, baseline device** | **< 1,000 draw calls** | `performance-optimization/design.md` |
| **Triangle budget, baseline device** | **< 1,000,000 triangles** | `performance-optimization/design.md` |
| Physics step rate at max | `240 Hz` — "forces all physics assemblies to step at 240 Hz (four times per frame)" | `performance-optimization/improve.md` |
| Zstd compression levels | **−7 … 22 inclusive**, default 1 | `EncodingService.yaml` |
| Instancing rule (draw-call batching) | Meshes collapse into one draw call when `MeshContent` matches **and** `SurfaceAppearance`s are identical, or (absent those) `TextureContent`s are identical, or (absent both) materials are identical | `performance-optimization/improve.md` §Draw calls |
| Objects that batch badly | decals, textures, particles — *"don't batch well and introduce additional draw calls"* | `performance-optimization/improve.md` |
| `CollisionFidelity` memory | `Box` lowest; `Default` and `Precise` *"consume significantly more memory"* | `performance-optimization/improve.md` §Physics memory usage |
| Parallel Luau: `require()` in a parallel phase | **not allowed** — require in serial first | `scripting/multithreading.md` |
| Parallel Luau: actors on one script | scripts in the *same* Actor always run serially w.r.t. each other — **you need multiple Actors** | `scripting/multithreading.md` |
| Parallel Luau: default thread-safety | **Unsafe** if an API member does not declare a level | `scripting/multithreading.md` |
| Parallel Luau: data-model writes | scripts in parallel *generally cannot write to the data model* | `scripting/multithreading.md` |
| `SharedTable` semantics | no copy on send; **atomic, immediately visible to all actors**; clone uses structural sharing | `scripting/multithreading.md` |
| Actor count guidance | *"For the best performance, use more Actors. Even if the device has fewer cores than Actors, the granularity allows for more efficient load balancing."* | `scripting/multithreading.md` |
| `EncodingService` thread safety | `Safe` — callable from parallel code | `EncodingService.yaml` |
| Dev-console memory categories relevant here | `GraphicsTexture`, `GraphicsMeshParts`, `GraphicsParts`, `GraphicsTerrain`, `GraphicsSpatialHash`, `LuaHeap`, `InstanceCount`, `PlaceScriptMemory`, `PhysicsParts` | `studio/optimization/memory-usage.md`, `performance-optimization/improve.md` |
| Studio device emulator accuracy | **not accurate for memory** — Studio runs client *and* server | `performance-optimization/design.md` |

All of the above were read from the `Roblox/creator-docs` GitHub mirror at
https://github.com/Roblox/creator-docs (the `create.roblox.com` rendering of the same content is
403-blocked from this environment).

---

### 4.2 `[COMMUNITY, SECOND-HAND]` — developer-reported numbers

**Treat every row as a claim.** These reached me only via web-search result summaries; the
DevForum is 403-blocked here, so I could not read the original posts, verify the device, the
Roblox version, or the methodology.

| Metric | Reported value | Source thread |
| --- | --- | --- |
| **`EditableImage` total client memory budget** | **32 MB** | https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575 |
| **Memory per 512×512 `EditableImage`** | **≈ 1 MB** uncompressed buffer | ″ |
| **Live editable objects on client** | **8** (reported for both `EditableImage` *and* `EditableMesh`) | https://devforum.roblox.com/t/bypassing-8-editablemesh-limit-on-client/3683517 · https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561 |
| **`CreateMeshPartAsync` fixed cost** | **≈ 22 ms**, even with `CollisionFidelity.Box` and `CanCollide = false` | https://devforum.roblox.com/t/allow-applying-baked-mesh-content-to-a-meshpart-without-a-lag-spike/4752538 |
| **`CreateMeshPartAsync` marginal cost** | **≈ 0.27 ms per 1,000 triangles** | ″ |
| **Custom `DrawTriangle` (scanline, `--!native`)** | **145.65 µs per triangle** — 5,000 random triangles on a 512×512 `EditableImage` in 0.4369 s | https://github.com/break-core/DrawTriangle `[SOURCE-READ]` — README states the method in full |
| **Roblox's built-in/private `DrawTriangle`** | **319.02 µs per triangle** — same harness, 0.9571 s | ″ |
| ⇒ speed-up of the community implementation | **2.19×** | `[INFERRED]` |
| **Author's note on why** | *"To make this function extremely fast, native codegen was used. **Without it, it would actually run slower than the original.**"* | ″ |
| **`WritePixelsBuffer` size cap vs creation cap** | `EditableImage` can be *created* up to **2048×2048 in Studio via command bar / plugin code**, but **`WritePixelsBuffer` is limited to 1024×1024** | https://devforum.roblox.com/t/allow-editableimagewritepixelsbuffer-to-go-up-to-2048x2048-for-plugins/4568767 |
| **Multi-canvas refresh** | *"Roblox limits updates to 1 redraw per frame, so 10 images take 10 frames to render"* | https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757 |
| **Real-time raytracer, textured, multi-threaded** | *"well above 60 FPS on a mid-range computer at **100×100**"* (RetroRaster) | https://ethanthegrand.itch.io/retroraster |
| **Path tracer with real-time reflections** | *"30–60 FPS"*, **resolution not stated** | https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757 |
| **N64 emulator framebuffer** | **320×240**, with a **160×120 fast path** | https://github.com/yoits9090/plumber `[SOURCE-READ]` |
| **Raycaster renderer** | **100×100** with adjustable interlacing | https://devforum.roblox.com/t/a-renderer-using-raycasting-open-source/3609143 |
| **Ro2D example fixed internal resolution** | **1024×576** (sprite/tile 2D, not per-pixel shading) | https://github.com/nrmu9/Ro2DEngine `[SOURCE-READ]` |
| **Marching-cubes editable terrain** | *"60 fps"* with neighbour-updating chunks (pre-`EditableMesh`) | https://devforum.roblox.com/t/marching-cubes-voxel-terrain-with-tools/602593 |
| **`MeshPart` hard triangle limit (uploaded assets)** | **21,000** triangles per `MeshPart` in Studio | https://www.alpha3d.io/knowledge-base/roblox-meshpart-polygon-limit |
| **UGC accessory triangle cap** | **4,000** triangles per mesh (hats, hair, gear) | ″ · https://nilo.io/articles/roblox-polygon-limits-accessories |
| **Avatar / character mesh import limit** | **10,000** triangles; **environment meshes up to 20,000** | https://nilo.io/articles/advanced-roblox-custom-meshes |
| **Cloud LOD generation** | **3–4** progressively simpler versions per uploaded `MeshPart`, **25–75%** polygon reduction, preserving silhouette/UVs/material boundaries | https://www.creation.dev/learn/roblox-mesh-streaming-cloud-lod-optimization-guide |
| **ECS iteration throughput (jecs)** | *"Iterate **800,000 entities at 60 frames per second**"* | https://github.com/Ukendio/jecs `[SOURCE-READ]` (self-reported) |
| **Octree default top region** | `topRegionSize = 512` ⇒ 512×512×512 top-level regions | https://github.com/Sleitnick/rbxts-octo-tree |
| **Dev-console memory over-reporting bug** | dev console / performance stats reported showing **up to 3×** actual memory usage | https://devforum.roblox.com/t/dev-console-performance-stats-showing-up-to-3x-the-memory-usage/3581410 |

---

### 4.3 `[INFERRED]` — arithmetic on the above

Every input is cited; the arithmetic is mine.

| Derived figure | Working | Value |
| --- | --- | --- |
| Bytes in a 1024×1024 RGBA buffer | 1024 × 1024 × 4 | **4,194,304 B = 4 MiB** |
| Bytes in a 512×512 RGBA buffer | 512 × 512 × 4 | **1 MiB** — matches the community "≈1 MB per 512×512" report exactly, which **cross-validates both figures** |
| **Why the "8 editable objects" limit exists** | 32 MB budget ÷ 4 MiB per 1024² image | **= 8.** The reported 32 MB budget and the reported count-of-8 are **the same fact**. The limit is a *memory* limit that presents as a count limit when every object is max-size. **⇒ Smaller canvases should buy you more of them.** |
| FastCanvas memory overhead | `Grid` + `ClearingGrid`, both `W*H*4` | **2× framebuffer**, i.e. **8 MiB** at 1024² — **one-quarter of the entire 32 MB editable budget for a single canvas** |
| Naive vs doubling scanline fill, 1024 px | 1024 × 36.9 ns vs ⌈log₂1024⌉ × 60 ns | **37.8 µs vs 0.6 µs ⇒ ~63×** |
| Full-repaint cost, 256×256 | 65,536 × 36.9 ns | **2.4 ms — 15% of a 60 fps frame** |
| Full-repaint cost, 512×512 | 262,144 × 36.9 ns | **9.7 ms — 58% of a frame** |
| Full-repaint cost, 1024×1024 | 1,048,576 × 36.9 ns | **38.7 ms — 2.3 frames** |
| Single-octave `math.noise` over 1024² | 1,048,576 × 62.6 ns | **65.6 ms** |
| 4-octave FBM over 1024² | 4 × 65.6 ms | **262 ms — a quarter-second hitch** |
| `CreateMeshPartAsync` on a max-size mesh | 22 ms + 20 × 0.27 ms | **27.4 ms ⇒ 1.6 frames dropped per bake** |
| Mesh bakes affordable per second at 60 fps, using ≤ 25% of frame time | (16.67 × 0.25) ms/frame ÷ 27.4 ms | **≈ 0.15 bakes/frame ⇒ ~9 per second, and every one of them is still a visible hitch** |
| Max triangles addressable across the client editable budget | 8 objects × 20,000 tri | **160,000 triangles live in `EditableMesh` form at once** — 16% of the 1,000,000-triangle scene budget |
| Voxel chunk sizing against the 20k-triangle cap | fully-exposed 16³ chunk ≈ 16·16·6 = 1,536 quads = 3,072 tri (best case); pathological interiors 4–6× | **16³ is safe; 32³ is not** |
| Built-in `DrawTriangle` triangles per frame | 16.67 ms ÷ 319 µs | **≈ 52** |
| `break-core/DrawTriangle` triangles per frame | 16.67 ms ÷ 145.6 µs | **≈ 114** |
| ⇒ software 3D at 60 fps | ~100 textured triangles per frame is the built-in-rasteriser ceiling | **a software 3D scene must be ≲ 100 triangles, or you must write your own rasteriser into a `buffer`** |
| Multi-canvas refresh rate | 1 displayed update/frame, N canvases | **each canvas refreshes at 60/N fps**; 4 canvases ⇒ 15 fps each |

---

### 4.4 What is *not* measured anywhere — build your own harness

Nobody has published: `WritePixelsBuffer` throughput as a function of region size; `ReadPixelsBuffer`
cost; `EditableMesh` `AddVertex`/`AddTriangle` per-call cost; `EditableMesh` construction time for
a full 20k-triangle mesh; memory actually consumed by an `EditableMesh` at a given vertex count;
`FixedSize = true` vs `false` memory delta; per-device-tier variation for any of it; or the
`--!native` speed-up factor for a real pixel loop.

**Build this before you commit to an architecture.** The shape that works:

1. Copy `nightcycle/roblox-benchmarks`' method — N repeats inside a sample, many samples, several
   sessions, report percentiles not means.
2. Run on **at least one low-end mobile device**, because Roblox's own docs warn that *"PCs are
   affected by these budgets much less than mobile and console, so developers often get surprised
   when they take their game to device."* `[DOCUMENTED]`
3. Measure with `--!native` **on and off** — `break-core/DrawTriangle` reports that native codegen
   is the difference between beating and losing to Roblox's built-in. `[SOURCE-READ]`
4. Watch `GraphicsTexture`, `GraphicsMeshParts`, `LuaHeap` and `InstanceCount` in the Developer
   Console, and remember the reported **3× over-reporting bug**. `[DOCUMENTED]` + `[COMMUNITY]`
5. Use **Render Stats** (<kbd>Shift</kbd>+<kbd>F2</kbd>) → **Timing** for live draw-call counts.
   `[DOCUMENTED]`

