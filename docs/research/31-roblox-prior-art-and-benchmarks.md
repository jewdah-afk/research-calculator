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

#### 4.0.1 Measured Luau primitive costs

Mean ns/op under the unit inference above. All rows `[SOURCE-READ]` from
`roblox-benchmarks-data/src/summary.csv`, with `[INFERRED]` unit scaling.

| ns/op | Operations at that cost |
| --- | --- |
| **18.9 – 19.8** | `local` write (18.9), `local` read (19.5), `if`-based min/max (19.8) |
| **20.9 – 23.0** | call a local function (21.1), call a function held in a local var (20.9), float/int add (21.4/21.5), divide/subtract/multiply (21.4/21.5/21.8), `%` (22.1), `math.exp` (22.1), **`Vector3` add/sub/mul/div (22.4/22.9/23.0/22.5)** |
| **23.3 – 24.2** | `if`-based clamp (23.3), `<` `>` `<=` `>=` (23.6), table array read (24.2) |
| **25.0 – 26.5** | `math.round`/`sqrt`/`ceil`/`floor` (25.0–25.2), `math.max`/`min` function form (25.4/25.5), `math.floor` via `%` (25.5), table array write (25.6), `~=`/`==` (26.2/26.5) |
| **27.3 – 28.8** | `typeof`/`type` (27.3), **every `bit32` op** — `band`/`bor`/`bxor`/`test`/shifts/rotates/`byteswap`/leading-and-trailing-zero counts (27.4–28.8), `math.clamp` function form (27.8) |
| **32.0 – 33.3** | `bit32.extract` (32.0), `Vector3.new` (32.1), `assert` (33.3) |
| **33.4 – 34.0** | **`buffer.read*` — u8, u16, u32, i8, i16, i32, f32, f64 — flat across all widths** |
| **36.9 – 37.4** | **`buffer.write*` — u8, u16, u32, i8, i16, i32, f32, f64 — flat across all widths**; default-argument function call (37.8) |
| **42.7 – 49.4** | method call on a class (42.7), `buffer.len` (44.1), function stored in a table (44.1), **metatable method dispatch (49.4)** |
| **56.2 – 64.6** | **`Vector2` add (56.2)**, `buffer.writestring` (59.4), `buffer.copy` (60.0), `buffer.fill` (60.0), `buffer.readbits` (58.5), `buffer.writebits` (61.8), **`math.noise` 1D/2D/3D (62.7/62.6/64.6)** |
| **114 – 205** | `buffer.readstring` (114.3), `buffer.create` (168.8), `buffer.fromstring` (177.8), `buffer.tostring` (205.3) |


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

The hard numeric limits are consolidated in the **Benchmark table** below; this subsection records
the *documented rules* that are not single numbers. All read from the `Roblox/creator-docs` GitHub
mirror (https://github.com/Roblox/creator-docs), since `create.roblox.com` is 403-blocked here.

- **`EditableImage`** — max **1024×1024**; `Size` is `ReadOnly` (resize = new image +
  `DrawImageTransformed` + `Destroy`); origin top-left `(0,0)`, bottom-right `(Size.X-1, Size.Y-1)`;
  **only one displayed image updates per frame** — "if you update three `EditableImage` objects
  which are currently being displayed, it will take three frames for all of them to be updated."
- **`EditableMesh`** — **60,000 vertices / 20,000 triangles**; exceeding either **throws**;
  `FixedSize = true` by default from `CreateEditableMeshAsync`; split per-face-corner attributes;
  counter-clockwise winding is front-facing; visual edits are immediate, **collision and fluid
  geometry only refresh through `CreateMeshPartAsync` + `ApplyMesh`**, which the docs say to call
  "at the end of a conceptual edit, not after individual calls."
- **Budgets** — client-side editable memory budget is **strict**; **server, Studio and plugins are
  unlimited**; `CreateEditableImage`/`CreateEditableMesh` **return `nil`** (they do not throw) when
  it is exhausted; `CreateMeshPartAsync` fails if the server storage budget is exhausted.
  Multi-referencing one editable onto several `Content` properties reduces budget pressure.
- **Frame and scene budgets** — 60 fps ⇒ **16.67 ms/frame**; baseline device: **< 1,000 draw calls
  and < 1,000,000 triangles**; physics can be forced to **240 Hz** (4× per frame).
- **Draw-call instancing rule** — meshes collapse into one draw call when `MeshContent` matches
  **and** `SurfaceAppearance`s are identical, or (absent those) `TextureContent`s are identical, or
  (absent both) materials are identical. Decals, textures and particles "don't batch well."
- **`CollisionFidelity`** — `Box` has the lowest memory overhead; `Default` and `Precise` "consume
  significantly more memory."
- **`EncodingService`** — Zstd only; compression levels **−7 … 22** (default 1); `thread_safety:
  Safe`, so usable from parallel code. Also `Base64Encode/Decode`, `ComputeBufferHash`,
  `ComputeStringHash`.
- **Parallel Luau** — `require()` is **illegal** in a desynchronised phase; scripts in the *same*
  Actor run serially w.r.t. each other, so you need **many** Actors ("even if the device has fewer
  cores than Actors, the granularity allows for more efficient load balancing"); any API member
  without a declared thread-safety level defaults to **Unsafe**; parallel scripts generally cannot
  write to the data model; `SharedTable` is send-without-copy, atomic, immediately visible to all
  actors, and clones with structural sharing. Roblox's own worked example in that page is
  **server-side procedural terrain generation** across cloned Actor workers.
- **Profiling** — Developer Console memory categories: `GraphicsTexture`, `GraphicsMeshParts`,
  `GraphicsParts`, `GraphicsTerrain`, `GraphicsSpatialHash`, `LuaHeap`, `InstanceCount`,
  `PlaceScriptMemory`, `PhysicsParts`. **Render Stats** (<kbd>Shift</kbd>+<kbd>F2</kbd>) → Timing
  gives live draw calls. **Studio's device emulator is not accurate for memory** (it runs client
  *and* server in one process).

### 4.2 `[COMMUNITY, SECOND-HAND]` — developer-reported numbers

**Treat every one of these as a claim, not a measurement.** They reached me only through
web-search result summaries; `devforum.roblox.com` is 403-blocked here, so I could not verify the
device, the engine version, or the methodology. Full values and source URLs are in the
**Benchmark table** below. The headline claims:

- **`EditableImage` client budget: 32 MB total; ≈1 MB per 512×512 image** — devforum/4389575.
- **8 live editable objects on the client**, reported for both classes — devforum/3683517, /4219561.
- **`CreateMeshPartAsync`: ≈22 ms fixed + ≈0.27 ms per 1,000 triangles**, even with
  `CollisionFidelity.Box` and `CanCollide = false` — devforum/4752538. **The single most important
  second-hand number in this chapter.**
- **`EditableImage` can be *created* up to 2048² in Studio/plugin code, but `WritePixelsBuffer` is
  capped at 1024²** — devforum/4568767.
- **"Roblox limits updates to 1 redraw per frame, so 10 images take 10 frames to render"** —
  devforum/3066757, which independently matches the documented rule.
- **Shipped real-time resolutions: 100×100 (RetroRaster, ">60 fps mid-range PC"; raycaster with
  interlacing), 320×240 with a 160×120 fast path (plumber N64 emulator).**
- **A path tracer claiming 30–60 fps with real-time reflections — resolution unstated**, which
  makes the claim unusable. Note this pattern: **community numbers routinely omit resolution,
  device and engine version.**
- **Asset triangle caps: 21,000 per uploaded `MeshPart`; 4,000 per UGC accessory; 10,000 per
  avatar mesh; 20,000 per environment mesh.** Cloud LOD generates **3–4 levels at 25–75%
  reduction** — **for uploaded assets only**, never for a runtime `EditableMesh`.
- **`break-core/DrawTriangle`**, uniquely, publishes its method *and* its numbers: 5,000 randomly
  positioned triangles on a 512×512 `EditableImage`, timed for both implementations —
  **145.65 µs/triangle** for the community scanline rasteriser versus **319.02 µs/triangle** for
  Roblox's built-in. That is the gold standard for how a community benchmark should be reported,
  and it is `[SOURCE-READ]` rather than second-hand because the README is on GitHub.

### 4.3 `[INFERRED]` — arithmetic on the above

All derived figures are consolidated in the **Benchmark table** below with their inputs. Two
derivations deserve calling out here because they change design decisions:

- **The "8 editable objects" limit and the "32 MB budget" are the same fact.** A 1024×1024 RGBA
  buffer is 1024 · 1024 · 4 = **4 MiB**; 32 MB ÷ 4 MiB = **8**. The community's reported 512×512
  figure (≈1 MB) matches 512 · 512 · 4 = 1 MiB exactly, which **cross-validates both reports**.
  **Consequence: the cap is on bytes, not objects — smaller canvases should buy you more of them.**
  Verify this first; it is the highest-leverage unknown in the whole chapter.
- **FastCanvas costs 2× its framebuffer in memory** (`Grid` + the pre-baked `ClearingGrid`, both
  `W·H·4`). At 1024² that is **8 MiB — one quarter of the entire 32 MB editable budget for a
  single canvas.** The O(log n) `Clear()` is not free; it is paid for in RAM.
- **Mesh bakes are self-limiting.** At ≈27.4 ms per `CreateMeshPartAsync` on a max-size mesh, and
  allowing it no more than 25% of frame time, you get roughly **9 bakes per second — and every one
  is still a visible hitch.** Any design that re-bakes geometry per frame is arithmetically dead.

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

---

## 5. Known limitations, bugs and gaps

### 5.1 What these APIs structurally cannot do

| Limitation | Detail | Confidence |
| --- | --- | --- |
| **No GPU compute of any kind** | There is no compute-shader, no fragment-shader and no GPU buffer API. Every pixel and every vertex you generate is computed by Luau on the CPU. The "shader" systems in the community (Lightspeed, OSGL's shader callbacks, `Roblox-Canvas`'s `draw*` shader functions) are **software** shaders — a Luau function called per pixel. | `[INFERRED]` from the absence of any such API in `creator-docs` |
| **`EditableImage` cannot be resized** | `Size` is `ReadOnly`. To resize or crop you must create a new image and `DrawImageTransformed()` into it, then `Destroy()` the old one. | `[DOCUMENTED]` |
| **One displayed `EditableImage` updates per frame** | N on-screen canvases refresh at 60/N fps. This is the hardest ceiling in the whole API. | `[DOCUMENTED]` |
| **No bulk mesh write** | `EditableMesh` has no `WriteVerticesBuffer` analogue to `WritePixelsBuffer`. Geometry is built one call at a time across the Luau↔C++ boundary. | `[DOCUMENTED]` (by absence in `EditableMesh.yaml`) |
| **No public triangle rasteriser** | `EditableImage` exposes `DrawCircle`, `DrawLine`, `DrawRectangle`, `DrawImage`, `DrawImageTransformed`, `DrawImageProjected`, `SampleImageProjected` — **but no `DrawTriangle`.** A private/undocumented one exists and is reported as slow and un-updated "in years". | `[DOCUMENTED]` + `[SOURCE-READ]` (https://github.com/break-core/DrawTriangle) |
| **`EditableImage`/`EditableMesh` do not replicate** | Server→client replication of editable content is not supported; you generate on the client, or you send parameters and regenerate. | `[COMMUNITY, SECOND-HAND]` (https://github.com/plainenglishh/remote-image-library README) |
| **No runtime CSG, no LOD generation, no mesh decimation** | Cloud LOD only runs on *uploaded* assets, so a procedurally generated mesh has no LODs. | `[COMMUNITY, SECOND-HAND]` + `[INFERRED]` |
| **Collision/fluid geometry only refreshes via `CreateMeshPartAsync` + `ApplyMesh`** | `MeshPart.MeshContent` is not assignable and `ApplyMesh()` does not accept `Content`. The ~22 ms cost is therefore unavoidable today. | `[DOCUMENTED]` + `[COMMUNITY, SECOND-HAND]` |
| **Gated behind identity verification** | 13+ **and** ID-verified, plus "Enable Mesh / Image APIs" in the Creator Dashboard, or these APIs fail in published experiences. **This gates your whole product on one person's identity verification.** | `[DOCUMENTED]` |
| **Asset permissions are enforced** | `CreateEditableImageAsync`/`CreateEditableMeshAsync` only load assets owned by, or explicitly shared with, the experience owner / Studio user / logged-in player / a group with edit rights. Otherwise they throw. | `[DOCUMENTED]` |

### 5.2 Commonly reported breakage

| Report | Source | Confidence |
| --- | --- | --- |
| **"EditableMesh / EditableImage randomly becomes inaccessible at runtime despite being enabled"** — *"the engine intermittently revokes access to these APIs mid-operation on both the server and client with no configuration change on our end."* Reported June 2026. **This is the most serious reported bug in the space: it is not a code error you can prevent, so every call site needs a failure path.** | https://devforum.roblox.com/t/editablemesh-editableimage-randomly-becomes-inaccessible-at-runtime-despite-being-enabled/4702613 | `[COMMUNITY, SECOND-HAND]` |
| "EditableMesh is not accessible. Go to the Security Tab in Game Settings to enable this API." raised despite the toggle being on | https://devforum.roblox.com/t/editablemesh-is-not-accessible-go-to-the-security-tab-in-game-settings-to-enable-this-api/3822516 · https://devforum.roblox.com/t/editableimage-giving-error-of-not-being-enabled-despite-being-enabled/3895593 | `[COMMUNITY, SECOND-HAND]` |
| "Creating 2 or more `EditableImage`s will sometimes cause one not to render" | https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561 | `[COMMUNITY, SECOND-HAND]` |
| **`Texture` instances don't work on `EditableMesh`es** | https://devforum.roblox.com/t/texture-instances-dont-work-on-editablemeshes/3635698 | `[COMMUNITY, SECOND-HAND]` |
| "EditableImage buffer not updating correctly" | https://devforum.roblox.com/t/editableimage-buffer-not-updating-correctly/3275528 | `[COMMUNITY, SECOND-HAND]` |
| No way to release an `EditableImage`'s CPU-side buffer once the image is static — the memory stays charged against the 32 MB budget | https://devforum.roblox.com/t/add-a-way-to-discard-editableimage-buffer-after-it%E2%80%99s-no-longer-being-edited/3639808 · https://devforum.roblox.com/t/reducing-memory-consumption-of-editableimage-once-static/3639609 | `[COMMUNITY, SECOND-HAND]` |
| Developer Console / performance stats reported showing **up to 3×** real memory usage | https://devforum.roblox.com/t/dev-console-performance-stats-showing-up-to-3x-the-memory-usage/3581410 | `[COMMUNITY, SECOND-HAND]` |
| Roblox-owned and Marketplace assets cannot be loaded into editables | https://devforum.roblox.com/t/allow-editableimage-and-editablemesh-to-be-called-on-assets-owned-by-roblox-and-everything-found-in-the-marketplace/4514845 | `[COMMUNITY, SECOND-HAND]` |

**Defensive pattern this implies.** Every editable creation site should be:
`pcall` **and** `nil`-check **and** a degraded fallback path that keeps the experience playable —
because creation can fail from budget exhaustion (`nil`), from the security toggle (throw), and,
per the June 2026 report, spontaneously at runtime. OSGL's `Result` type with
`NotEnoughMemory` / `APINotEnabled` / `WindowDimensionsOutOfBounds` variants is the right shape.
`[SOURCE-READ]` + `[DOCUMENTED]` + `[COMMUNITY, SECOND-HAND]`

### 5.3 What stale tutorials get wrong

1. **`EditableImage:WritePixels()` / `ReadPixels()` (table-based) were *removed*, not deprecated.**
   They vanished between engine versions ~601 (Nov 2023) and ~648 (Oct 2024); calling them errors.
   **Any tutorial showing a table of numbers instead of a `buffer` is dead code.** Use
   `WritePixelsBuffer` / `ReadPixelsBuffer`. `[COMMUNITY, SECOND-HAND]`
2. **`editableImage.Parent = imageLabel` is the old pattern.** The current pattern is
   `imageLabel.ImageContent = Content.fromObject(editableImage)` — and equivalently
   `MeshPart.TextureContent`, `Decal.TextureContent`, `SurfaceAppearance.ColorMapContent`.
   `[DOCUMENTED]` + `[SOURCE-READ]` (all three canvas libraries use `Content.fromObject`)
3. **Tutorials that create one `EditableImage` per sprite/tile will hit the 8-object budget
   instantly.** The correct model is one canvas, many sprites blitted into its buffer.
   `[INFERRED]` from `[COMMUNITY, SECOND-HAND]` budget
4. **CanvasDraw 1.x/2.x tutorials describe a completely different engine** — v1 used one `Frame`
   per pixel; v2 used `Frame`s with `UIGradient`s packing ~10 pixels each. Only **v3/v4 use
   `EditableImage`**. Version-check any CanvasDraw material you find. `[COMMUNITY, SECOND-HAND]`
5. **"Just use `task.desynchronize()` to make it parallel" is wrong twice over:** scripts in the
   *same* Actor still run serially, and `require()` is illegal in a parallel phase. You need
   multiple Actors and all `require`s hoisted into the serial phase. `[DOCUMENTED]`
6. **`Vector2` "because it's 2D" is a pessimisation** — `Vector3` is ~2.5× faster. `[INFERRED]`

### 5.4 What Roblox has signalled

| Signal | Detail | Confidence |
| --- | --- | --- |
| **Shared-asset editing shipped (2026-04-15)** | *"You can now load and edit any asset into EditableMesh / EditableImage if they are explicitly shared with you / your group; you no longer have to be the owner."* Applies at runtime **and** in Studio. This materially widens collaborative and UGC workflows. | https://devforum.roblox.com/t/editablemesh-and-editableimage-now-support-shared-assets/4578818 `[COMMUNITY, SECOND-HAND]` |
| **Ongoing improvement cadence** | A stream of announcements: "Introducing in-experience Mesh & Image APIs [Studio Beta]" → "[Studio Beta] Updates" → "[Studio Beta] Major updates" → "[Client Beta] now available in published experiences" → "EditableMesh and EditableImage Improvements" (Jul 2025) → shared assets (Apr 2026). **These APIs are actively invested in, not abandoned.** | https://devforum.roblox.com/t/editablemesh-and-editableimage-improvements/3818624 and siblings `[COMMUNITY, SECOND-HAND]` |
| **Roblox's product framing** | *"Creators can now add Editable Mesh & Image APIs to published experiences. Empowering users to intuitively sculpt, paint, and create assets — all without technical skills or leaving the experience."* — i.e. Roblox's intended use-case is **UGC creation tools**, not software renderers. Budgets are sized for that. | https://x.com/Roblox/status/1859359050326213031 `[COMMUNITY, SECOND-HAND]` |
| **`DrawImageProjected` / `SampleImageProjected` exist and are underused** | Projects one `EditableImage` through an `EditableMesh` onto another `EditableImage`, with a full projector config (`Direction`, `Position`, `Size`, `Up`) and brush config (`Decal`, `AlphaBlendType`, `ColorBlendType`, `FadeAngle`, `BlendIntensity`). **This is a first-party, engine-side decal/spray-paint/damage-mapping primitive** — no third-party project I found uses it. | `EditableImage.yaml` `[DOCUMENTED]` |
| **Open feature requests to watch** | Raise the client editable limit (https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561); raise `WritePixelsBuffer` past 1024² for plugins (https://devforum.roblox.com/t/allow-editableimagewritepixelsbuffer-to-go-up-to-2048x2048-for-plugins/4568767); higher resolution + memory limit (https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575); apply baked mesh Content without a lag spike (https://devforum.roblox.com/t/allow-applying-baked-mesh-content-to-a-meshpart-without-a-lag-spike/4752538); discard the CPU buffer of a static image (https://devforum.roblox.com/t/add-a-way-to-discard-editableimage-buffer-after-it%E2%80%99s-no-longer-being-edited/3639808). **If any of these land, several conclusions in this chapter change.** | `[COMMUNITY, SECOND-HAND]` |

---

## Reusable libraries table

"Maintained?" is judged on the latest push date I observed (September 2026) and on whether the
project has CI/tests/packaging. Licences marked **⚠** need a decision before shipping.

| Name | What it does | URL | License | Maintained? |
| --- | --- | --- | --- | --- |
| **FastCanvas** | Minimal `buffer`→`EditableImage` canvas; the core under CanvasDraw | https://github.com/Ethanthegrand/FastCanvas | **⚠ none declared** | Yes — header dated 2026-07-09 |
| **CanvasDraw** | Full 2D graphics lib: shapes, textured triangles, bitmap fonts, image IO, zstd persistence | https://github.com/Ethanthegrand/CanvasDraw | **⚠ "Copyright © 2022–2026", no OSS licence** | Yes — v4.20.2, 2026-07-09 |
| **OSGL** | Typed, `Result`-returning graphics lib; Window/Texture/Bitmap/Video/Font | https://github.com/osgl-rbx/osgl | **⚠ custom "OSGL LICENSE" (non-OSI)** | Yes — v1.6.x, tests + plugin + docs |
| **Ro2DEngine (Ro2D)** | 2D software render + physics engine: dirty-region uploads, buffer pooling, Actor-parallel band rasterising, SDF primitives, asset compiler | https://github.com/nrmu9/Ro2DEngine | **MIT** | Yes — 2026-09-14, CI releases |
| **Roblox-Canvas** | Canvas algorithms with a `draw*` (shader callback) / `fill*` (fast path) split | https://github.com/ElixNoir/Roblox-Canvas | **MIT** | Partly — author calls it WIP |
| **EditableImageBlur** | In-place Gaussian-approx blur on a pixel `buffer`; never touches `EditableImage` | https://github.com/boatbomber/EditableImageBlur | **MPL-2.0** | Yes — 2026-08-10, Wally |
| **remote-image-library** | PNG decode from URL / binary string / pixel array → `EditableImage`; HTTP queueing | https://github.com/plainenglishh/remote-image-library | not declared **⚠** | Stale but the PNG decoder is the value |
| **DrawTriangle** | Fast scanline triangle rasteriser for `EditableImage`, with a published benchmark | https://github.com/break-core/DrawTriangle | **MIT** | Yes — 2026-03-16 |
| **LuauImageParser** | Strict-Luau pixel-data → `EditableImage` via `WritePixelsBuffer`, with a Cloudflare Worker | https://github.com/Metatable-Games/LuauImageParser | **MIT** | 2025-03-31 |
| **editable-clothing-util** | Classic Shirt/Pants → `EditableImage`, apply per `BodyPartR15`, skin-tone baking | https://github.com/nightcycle/editable-clothing-util | **Apache-2.0** | 2024-08-12 |
| **luau_term** | xterm terminal emulator; Roblox-free core, RGBA bitmap output, Lune-tested | https://github.com/mokiros/luau_term | see repo | Yes |
| **plumber** | N64 emulator in Roblox; software rasteriser → `EditableImage` at 320×240 | https://github.com/yoits9090/plumber | **MIT** | Yes — 2026-08-13 |
| **DissolveEffect** | Pixel dissolve with glow edges and noise distortion | https://github.com/Y-Workplace/DissolveEffect | **MIT** | 2026-06-18 |
| **RBLX-EditableMesh-Water-FirstPerson** | Pooled world-aligned `EditableMesh` chunk LOD ocean with shared deterministic wave field | https://github.com/Smurfis/RBLX-EditableMesh-Water-FirstPerson | **⚠ none declared** | Yes — 2026-09-17 |
| **Liquid-Simulation** | WebGL Water ported to `EditableMesh` | https://github.com/Y-Workplace/Liquid-Simulation | **⚠ none** | 2026-07-01 |
| **RTerrainGenerator** | Terrain + rivers + lakes + forests from exponentially-distributed Perlin with domain warping | https://github.com/TheArturZh/RTerrainGenerator | **MIT** (attribution expected) | Reference-quality |
| **Roblox-Terrain-Generator** | Terrain framework; smooth + bloxel; plugin or realtime client-side | https://github.com/tiffany352/Roblox-Terrain-Generator | **MIT** | No — explicit WIP/reference |
| **Fast-Noise** | 9 noise types (Perlin/Value/FBM/Billow/Ridged/Worley/Voronoi/Turbulence/DomainWarp), 2D+3D, `--!strict --!native --!optimize 2` | https://github.com/writebits/Fast-Noise | **MIT** | Yes |
| **Squash** | Comprehensive SerDes for bandwidth/space minimisation | https://github.com/Data-Oriented-House/Squash | see repo | Yes — docs site, Wally |
| **ByteNet** | Buffer-serialising networking library, strict Luau | https://github.com/ffrostfall/ByteNet | **MIT** | 2025-08-01 |
| **RbxUtil** | ~23 Wally modules: BufferUtil, Stream, Ser, Signal, Concur, Option, Quaternion, Spring, PID, Comm, Component… | https://github.com/Sleitnick/RbxUtil | **MIT** | Yes — CI + docs green |
| **LuaEncode** | Fast table serialisation for pure Luau / Lua 5.1+ | https://github.com/chadhyatt/LuaEncode | **MIT** | 2026-03-11 |
| **Janitor** | Cleanup/lifecycle object | https://github.com/howmanysmall/Janitor | **MIT** | Yes — 2026-07-28 |
| **roblox-lua-promise** | Promise/A+ for Luau | https://github.com/evaera/roblox-lua-promise | see repo | Yes — ecosystem standard |
| **SignalPlus** | Very fast signal implementation | https://github.com/AlexanderLindholt/SignalPlus | **MIT** | Yes — 2026-09-05 |
| **ProfileStore** | DataStore wrapper: session locking, auto-save, dupe prevention | https://github.com/MadStudioRoblox/ProfileStore | see repo | Yes |
| **Lapis** | DataStore abstraction: session locking, validation, migrations, throttling, immutability, save batching | https://github.com/nezuo/lapis | see repo | Yes |
| **React-lua / core-packages** | React port; used by Roblox internally | https://github.com/jsdotlua/CorePackages | see repo | Yes |
| **Fusion** | Reactive Luau state/UI, portable beyond Roblox | https://github.com/Elttob/Fusion | see repo | Yes |
| **Vide** | Fine-grained reactive UI | https://github.com/centau/vide | **MIT** | Yes — 2026-08-05 |
| **Iris** | Dear-ImGui-style immediate-mode GUI — best pick for procedural-gen debug panels | https://github.com/SirMallard/Iris | **MIT** | Yes — 2026-09-04 |
| **TextPlus** | Efficient robust text rendering | https://github.com/AlexanderLindholt/TextPlus | **MIT** | Yes — 2026-09-14 |
| **jecs** | Archetype/SoA ECS; claims 800k entities @ 60 fps | https://github.com/Ukendio/jecs | see repo | Yes |
| **ecr** | Sparse-set ECS | https://github.com/centau/ecr | **MIT** | Yes — 2026-09-03 |
| **Matter** | ECS with strong debugger | https://github.com/matter-ecs/matter | see repo | Yes |
| **Knit** | Game framework, most-starred | https://github.com/Sleitnick/Knit | **MIT** | **No — last push 2024-07-31** |
| **sift** | Immutable data for Luau | https://github.com/cxmeel/sift | **MIT** | 2026-03-26 |
| **llama** | Immutable data (predecessor to sift) | https://github.com/freddylist/llama | **MIT** | **No — 2022** |
| **rbxts-octo-tree** | Octree spatial index (`topRegionSize` 512) | https://github.com/Sleitnick/rbxts-octo-tree | see repo | Yes |
| **sayhisam1/Octree** | Octree with radius + nearest-neighbour search | https://github.com/sayhisam1/Octree | see repo | Stale |
| **QuickZone** | Physics-free high-performance spatial queries | https://github.com/LDGerrits/QuickZone | **MIT** | Yes — 2026-09-11 |
| **Nature2D** | 2D physics engine for Roblox | https://github.com/jaipack17/Nature2D | **MIT** | 2025-12-11 |
| **Gizmo2D** | Visual debugging for GUIs | https://github.com/jaipack17/Gizmo2D | see repo | — |
| **orbitlib** | Two-body orbital mechanics | https://github.com/daftcube/orbitlib | **⚠ AGPL-3.0** | **No — 2022** |
| **Jumper** | Grid pathfinding, pure Lua, multiple algorithms | https://github.com/Yonaba/Jumper | see repo | No — but portable |
| **a-star-lua** | Minimal dependency-free A* | https://github.com/lance0805/a-star-lua | see repo | No |
| **jest-lua** | Jest for Luau; used by Roblox internally | https://github.com/jsdotlua/jest-lua | see repo | Yes |
| **roblox-benchmarks** | CI-driven low-level Luau benchmark suite + data + dashboard | https://github.com/nightcycle/roblox-benchmarks | see repo | Yes |
| **luau-roblox** | Read/write `.rbxl`/`.rbxm` from Luau | https://github.com/Scythe-Technology/luau-roblox | **MIT** | 2026-08-19 |
| **VectorFlow** | Real-time Blender ↔ Roblox Studio sync | https://github.com/RullzVyline/VectorFlow | **MIT** | 2026-03-29 |
| **Wally** | Package manager | https://github.com/UpliftGames/wally | **MIT** | Yes |
| **Rojo** | Filesystem ↔ Studio sync | https://rojo.space | **MPL-2.0** | Yes |
| **OpenRoblox** | Curated index of Roblox tools/libraries | https://github.com/officialmmt/OpenRoblox | see repo | Yes |

---

## Benchmark table

| Metric | Value | Confidence | Source |
| --- | --- | --- | --- |
| `EditableImage` max size | 1024 × 1024 | `[DOCUMENTED]` | `creator-docs` `EditableImage.yaml` |
| `EditableImage` displayed updates | 1 per frame, per image | `[DOCUMENTED]` | ″ |
| `EditableImage` resizable? | No — `Size` is read-only | `[DOCUMENTED]` | ″ |
| `EditableMesh` max vertices | 60,000 | `[DOCUMENTED]` | `EditableMesh.yaml` |
| `EditableMesh` max triangles | 20,000 | `[DOCUMENTED]` | ″ |
| Over-limit behaviour | error thrown | `[DOCUMENTED]` | ″ |
| Editable creation on budget exhaustion | returns `nil` | `[DOCUMENTED]` | `AssetService.yaml` |
| Frame budget @ 60 fps | 16.67 ms | `[DOCUMENTED]` | `performance-optimization/design.md` |
| Draw-call budget, baseline device | < 1,000 | `[DOCUMENTED]` | ″ |
| Triangle budget, baseline device | < 1,000,000 | `[DOCUMENTED]` | ″ |
| Max physics step rate | 240 Hz (4× per frame) | `[DOCUMENTED]` | `performance-optimization/improve.md` |
| Zstd compression levels | −7 … 22 (default 1) | `[DOCUMENTED]` | `EncodingService.yaml` |
| `EditableImage` total client memory budget | **32 MB** | `[COMMUNITY, SECOND-HAND]` | devforum/4389575 |
| Memory per 512×512 `EditableImage` | ≈ 1 MB | `[COMMUNITY, SECOND-HAND]` | ″ |
| Memory per 1024×1024 RGBA buffer | 4 MiB | `[INFERRED]` | 1024·1024·4 |
| Live editable objects on client | **8** | `[COMMUNITY, SECOND-HAND]` | devforum/3683517, /4219561 |
| ⇒ 32 MB ÷ 4 MiB | **= 8 — the count limit *is* the memory limit** | `[INFERRED]` | above two rows |
| `CreateMeshPartAsync` fixed cost | ≈ 22 ms (even `Box` + `CanCollide=false`) | `[COMMUNITY, SECOND-HAND]` | devforum/4752538 |
| `CreateMeshPartAsync` marginal cost | ≈ 0.27 ms / 1k triangles | `[COMMUNITY, SECOND-HAND]` | ″ |
| `CreateMeshPartAsync` on a 20k-tri mesh | ≈ 27.4 ms ⇒ 1.6 dropped frames | `[INFERRED]` | ″ |
| Custom scanline `DrawTriangle` (`--!native`) | **145.65 µs / triangle** (5,000 tris, 512², 0.4369 s) | `[SOURCE-READ]` | github.com/break-core/DrawTriangle |
| Roblox built-in `DrawTriangle` | **319.02 µs / triangle** (same harness, 0.9571 s) | `[SOURCE-READ]` | ″ |
| ⇒ community rasteriser speed-up | 2.19× | `[INFERRED]` | ″ |
| ⇒ textured triangles per frame @ 60 fps | ≈ 114 (custom) / ≈ 52 (built-in) | `[INFERRED]` | ″ |
| `EditableImage` `DrawRectangle` | median 9.62 µs; mean 25.87 µs; p90 73.2 µs; max 436.8 µs | `[SOURCE-READ]` + `[INFERRED]` unit | roblox-benchmarks-data `summary.csv` |
| `EditableImage` `DrawLine` | median 0.37 µs; mean 0.49 µs; p90 0.96 µs; max 7.91 µs | ″ | ″ |
| ⇒ `DrawRectangle` calls per frame | ≈ 1,730 at median; ≈ 228 at p90 | `[INFERRED]` | ″ |
| ⇒ `DrawLine` calls per frame | ≈ 44,800 at median; ≈ 17,300 at p90 | `[INFERRED]` | ″ |
| `buffer.write*` (any width) | ≈ 36.9–37.4 ns | `[SOURCE-READ]` + `[INFERRED]` unit | ″ |
| `buffer.read*` (any width) | ≈ 33.4–34.0 ns | ″ | ″ |
| ⇒ packed-u32 pixel write vs 4× u8 | ≈ 4× faster | `[INFERRED]` | ″ |
| `buffer.copy` / `fill` fixed cost | ≈ 60 ns | ″ | ″ |
| ⇒ doubling span-fill vs naive, 1024 px | 0.6 µs vs 37.8 µs ⇒ **≈ 63×** | `[INFERRED]` | ″ + FastCanvas source |
| `buffer.writebits` / `readbits` | 61.8 / 58.5 ns (≈1.7× aligned) | ″ | ″ |
| `buffer.create` | ≈ 168.8 ns | ″ | ″ |
| `buffer.tostring` / `fromstring` / `readstring` | 205.3 / 177.8 / 114.3 ns | ″ | ″ |
| `buffer.len` | ≈ 44.1 ns (hoist it) | ″ | ″ |
| `math.noise` 1D/2D/3D | 62.7 / 62.6 / 64.6 ns | ″ | ″ |
| ⇒ 1-octave noise over 1024² | ≈ 65.6 ms | `[INFERRED]` | ″ |
| ⇒ 4-octave FBM over 1024² | ≈ 262 ms | `[INFERRED]` | ″ |
| `Vector3` add vs `Vector2` add | 22.4 ns vs 56.2 ns ⇒ **2.5× faster** | `[SOURCE-READ]` + `[INFERRED]` | ″ |
| local function call vs metatable method | 21.1 ns vs 49.4 ns ⇒ **2.3×** | ″ | ″ |
| table array write vs `buffer.writeu32` (non-native) | 25.6 ns vs 36.9 ns — **tables win without `--!native`** | ″ | ″ |
| Native codegen effect on `buffer` | *"zero overhead … just as fast, if not faster, than tables"* | `[DOCUMENTED]` | Roblox native-code-gen docs |
| Full per-pixel repaint, 256² | ≈ 2.4 ms (15% of a frame) | `[INFERRED]` | 65,536 × 36.9 ns |
| Full per-pixel repaint, 512² | ≈ 9.7 ms (58% of a frame) | `[INFERRED]` | 262,144 × 36.9 ns |
| Full per-pixel repaint, 1024² | ≈ 38.7 ms (**2.3 frames**) | `[INFERRED]` | 1,048,576 × 36.9 ns |
| Shipped realtime raytracer resolution | 100 × 100, "well above 60 FPS, mid-range PC" | `[COMMUNITY, SECOND-HAND]` | ethanthegrand.itch.io/retroraster |
| Shipped N64-emulator framebuffer | 320 × 240 (160 × 120 fast path) | `[SOURCE-READ]` | github.com/yoits9090/plumber |
| Shipped raycaster resolution | 100 × 100, interlaced | `[COMMUNITY, SECOND-HAND]` | devforum/3609143 |
| Ro2D example internal resolution | 1024 × 576 (sprite-based, not per-pixel shading) | `[SOURCE-READ]` | github.com/nrmu9/Ro2DEngine |
| Path tracer claim | 30–60 fps, **resolution unstated** | `[COMMUNITY, SECOND-HAND]` | devforum/3066757 |
| `WritePixelsBuffer` cap vs creation cap | write ≤ 1024²; creation up to 2048² in Studio/plugin | `[COMMUNITY, SECOND-HAND]` | devforum/4568767 |
| N on-screen canvases refresh rate | 60 / N fps each | `[DOCUMENTED]` + `[INFERRED]` | `EditableImage.yaml` |
| Max triangles live in `EditableMesh` form | 8 × 20,000 = 160,000 (16% of scene budget) | `[INFERRED]` | doc limits + community count |
| Safe voxel chunk size vs 20k cap | 16³ safe; 32³ not | `[INFERRED]` | greedy-mesh arithmetic |
| `MeshPart` uploaded-asset triangle cap | 21,000 | `[COMMUNITY, SECOND-HAND]` | alpha3d.io |
| UGC accessory triangle cap | 4,000 | `[COMMUNITY, SECOND-HAND]` | nilo.io |
| Avatar / environment mesh import caps | 10,000 / 20,000 | `[COMMUNITY, SECOND-HAND]` | nilo.io |
| Cloud LOD levels / reduction | 3–4 levels, 25–75% reduction (uploaded assets only) | `[COMMUNITY, SECOND-HAND]` | creation.dev |
| jecs ECS iteration | 800,000 entities @ 60 fps | `[SOURCE-READ]` (self-reported) | github.com/Ukendio/jecs |
| Octree default top-region size | 512³ | `[COMMUNITY, SECOND-HAND]` | rbxts-octo-tree |
| Marching-cubes editable terrain (pre-EditableMesh) | 60 fps with neighbour-updating chunks | `[COMMUNITY, SECOND-HAND]` | devforum/602593 |

---

## Sources

**Source code and data fetched and read directly** (`[SOURCE-READ]`) — all via `raw.githubusercontent.com`:
[FastCanvas `FastCanvas.luau`](https://github.com/Ethanthegrand/FastCanvas) (465 lines, read in full) ·
[CanvasDraw v4.20.2 `src/init.luau`](https://github.com/Ethanthegrand/CanvasDraw) (3,746 lines, read in part) ·
[OSGL v1.6.2 `src/init.luau`, `DrawableObject/window.luau`, `DrawableObject/windowBase.luau`, `LICENSE`](https://github.com/osgl-rbx/osgl) ·
[Ro2DEngine](https://github.com/nrmu9/Ro2DEngine) ·
[break-core/DrawTriangle](https://github.com/break-core/DrawTriangle) (benchmark method + results) ·
[boatbomber/EditableImageBlur](https://github.com/boatbomber/EditableImageBlur) ·
[plainenglishh/remote-image-library](https://github.com/plainenglishh/remote-image-library) ·
[ElixNoir/Roblox-Canvas](https://github.com/ElixNoir/Roblox-Canvas) ·
[mokiros/luau_term](https://github.com/mokiros/luau_term) ·
[yoits9090/plumber](https://github.com/yoits9090/plumber) ·
[nightcycle/editable-clothing-util](https://github.com/nightcycle/editable-clothing-util) ·
[Metatable-Games/LuauImageParser](https://github.com/Metatable-Games/LuauImageParser) ·
[TheArturZh/RTerrainGenerator](https://github.com/TheArturZh/RTerrainGenerator) ·
[tiffany352/Roblox-Terrain-Generator](https://github.com/tiffany352/Roblox-Terrain-Generator) ·
[Smurfis/RBLX-EditableMesh-Water-FirstPerson](https://github.com/Smurfis/RBLX-EditableMesh-Water-FirstPerson) ·
[writebits/Fast-Noise](https://github.com/writebits/Fast-Noise) ·
[Data-Oriented-House/Squash](https://github.com/Data-Oriented-House/Squash) ·
[Sleitnick/RbxUtil](https://github.com/Sleitnick/RbxUtil) ·
[MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) ·
[nezuo/lapis](https://github.com/nezuo/lapis) ·
[jsdotlua/jest-lua](https://github.com/jsdotlua/jest-lua) ·
[Ukendio/jecs](https://github.com/Ukendio/jecs) ·
[Elttob/Fusion](https://github.com/Elttob/Fusion) ·
[evaera/roblox-lua-promise](https://github.com/evaera/roblox-lua-promise) ·
**[nightcycle/roblox-benchmarks](https://github.com/nightcycle/roblox-benchmarks)** and
**[roblox-benchmarks-data `src/summary.csv`](https://raw.githubusercontent.com/nightcycle/roblox-benchmarks-data/main/src/summary.csv)** (downloaded and analysed; ~60 benchmark rows — the numeric backbone of §4.0).

**Roblox documentation**, read from the [`Roblox/creator-docs`](https://github.com/Roblox/creator-docs) GitHub mirror (`[DOCUMENTED]`):
`reference/engine/classes/EditableImage.yaml` · `EditableMesh.yaml` · `AssetService.yaml` · `EncodingService.yaml` ·
`reference/engine/enums/CompressionAlgorithm.yaml` · `performance-optimization/design.md` · `performance-optimization/improve.md` ·
`scripting/multithreading.md` · `studio/optimization/memory-usage.md` · `avatar/in-experience-creation.md`.

**DevForum threads reached only through web-search result summaries** (`[COMMUNITY, SECOND-HAND]`) — `devforum.roblox.com` returns 403 from this environment, so **none of these were opened**:

- Libraries & demos: [OSGL 3066757](https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757) · [CanvasDraw 1624633](https://devforum.roblox.com/t/canvasdraw-a-fast-and-powerful-graphics-library-draw-pixels-lines-triangles-readmodify-image-data-and-much-more/1624633) · [Ro2D 4634716](https://devforum.roblox.com/t/open-source-ro2d-a-high-performance-2d-software-rendering-physics-engine-editableimage/4634716) · [Radius 3547307](https://devforum.roblox.com/t/radius-native-physically-based-and-performant-pathtracing-open-source/3547307) · [Piotrekstel path tracer 4568087](https://devforum.roblox.com/t/path-tracer-with-nee-and-mispiotrekstels-path-tracer/4568087) · [BloxPT 1363731](https://devforum.roblox.com/t/bloxpt-pathtracer-open-source/1363731) · [Raycast renderer 3609143](https://devforum.roblox.com/t/a-renderer-using-raycasting-open-source/3609143) · [PixelRasterizer 3881135](https://devforum.roblox.com/t/editableimage-pixelrasterizer-real-time-2d-pixel-grid-system-with-dynamic-lighting-editableimage-rendering/3881135) · [Lightspeed shaders 2762254](https://devforum.roblox.com/t/lightspeed-shader-system-using-editableimage/2762254) · [EditableImage guide 3858566](https://devforum.roblox.com/t/a-complete-guide-to-editableimages/3858566) · [Wyreframe 4178859](https://devforum.roblox.com/t/wyreframe-wireframe-rendering-module/4178859) · [MeshCreator 2788604](https://devforum.roblox.com/t/meshcreator-edit-meshes-easily-with-free-plugin/2788604) · [ActorGroup2 3412330](https://devforum.roblox.com/t/actorgroup2-asynchronous-parallel-luau-made-easy/3412330)
- Limits, budgets & performance: [memory/resolution request 4389575](https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575) (**32 MB budget; ≈1 MB per 512²**) · [baked-mesh lag spike 4752538](https://devforum.roblox.com/t/allow-applying-baked-mesh-content-to-a-meshpart-without-a-lag-spike/4752538) (**22 ms + 0.27 ms/1k tri**) · [8-mesh limit 3683517](https://devforum.roblox.com/t/bypassing-8-editablemesh-limit-on-client/3683517) · [remove client limit 4219561](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561) · [budget reached 3469104](https://devforum.roblox.com/t/editable-mesh-memory-budget-reached/3469104) · [creation failure 3490799](https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799) · [2048² WritePixelsBuffer 4568767](https://devforum.roblox.com/t/allow-editableimagewritepixelsbuffer-to-go-up-to-2048x2048-for-plugins/4568767) · [discard static buffer 3639808](https://devforum.roblox.com/t/add-a-way-to-discard-editableimage-buffer-after-it%E2%80%99s-no-longer-being-edited/3639808) · [reduce static memory 3639609](https://devforum.roblox.com/t/reducing-memory-consumption-of-editableimage-once-static/3639609) · [dev-console 3× memory bug 3581410](https://devforum.roblox.com/t/dev-console-performance-stats-showing-up-to-3x-the-memory-usage/3581410)
- Bugs: [randomly inaccessible 4702613](https://devforum.roblox.com/t/editablemesh-editableimage-randomly-becomes-inaccessible-at-runtime-despite-being-enabled/4702613) · [not accessible despite enabled 3822516](https://devforum.roblox.com/t/editablemesh-is-not-accessible-go-to-the-security-tab-in-game-settings-to-enable-this-api/3822516) / [3895593](https://devforum.roblox.com/t/editableimage-giving-error-of-not-being-enabled-despite-being-enabled/3895593) · [Texture instances 3635698](https://devforum.roblox.com/t/texture-instances-dont-work-on-editablemeshes/3635698) · [buffer not updating 3275528](https://devforum.roblox.com/t/editableimage-buffer-not-updating-correctly/3275528) · [Roblox-owned assets 4514845](https://devforum.roblox.com/t/allow-editableimage-and-editablemesh-to-be-called-on-assets-owned-by-roblox-and-everything-found-in-the-marketplace/4514845)
- Announcements: [shared assets 4578818](https://devforum.roblox.com/t/editablemesh-and-editableimage-now-support-shared-assets/4578818) · [improvements 3818624](https://devforum.roblox.com/t/editablemesh-and-editableimage-improvements/3818624) · [client beta 3267293](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293) · [studio beta 2725284](https://devforum.roblox.com/t/introducing-in-experience-mesh-image-apis-studio-beta/2725284) / [3225681](https://devforum.roblox.com/t/studio-beta-major-updates-to-in-experience-mesh-image-apis/3225681) / [3172217](https://devforum.roblox.com/t/studio-beta-updates-to-in-experience-mesh-image-apis/3172217)
- Mesh & terrain technique: [marching cubes 602593](https://devforum.roblox.com/t/marching-cubes-voxel-terrain-with-tools/602593) · [chunk via EditableMesh 3386346](https://devforum.roblox.com/t/generating-a-chunk-using-editablemesh/3386346) · [parallel terrain 4582100](https://devforum.roblox.com/t/procedural-terrain-generation-using-editablemeshes-in-parrallel/4582100) · [greedy meshing 1139881](https://devforum.roblox.com/t/greedy-meshing-voxels/1139881) / [452717](https://devforum.roblox.com/t/consume-everything-how-greedy-meshing-works/452717) / [octree+greedy 3505477](https://devforum.roblox.com/t/octree-and-greedy-meshing-voxel-simulation/3505477) · [mesh voxelizer 4523856](https://devforum.roblox.com/t/mesh-voxelizer-meshpart-%E2%86%92-voxels/4523856) · [destruction 3158370](https://devforum.roblox.com/t/creating-a-destruction-system-using-editable-meshes/3158370) · [deformation 3393375](https://devforum.roblox.com/t/editable-mesh-deformation/3393375) · [JONSWAP ocean 3661760](https://devforum.roblox.com/t/jonswap-ocean-liquid/3661760) · [Gerstner ocean 3562339](https://devforum.roblox.com/t/simulated-ocean-with-editablemesh/3562339) · [skinned-mesh water 3144149](https://devforum.roblox.com/t/realistic-water-simulation-script-skinned-mesh-free-open-source/3144149) · [polygonal terrain 753007](https://devforum.roblox.com/t/procedural-polygonal-terrain-generation-make-low-poly-terrain-with-ease/753007) · [EZ Pathfinding V5 1533902](https://devforum.roblox.com/t/ez-pathfinding-v5/1533902)

**Other web sources** (`[COMMUNITY, SECOND-HAND]`):
[RetroRaster](https://ethanthegrand.itch.io/retroraster) (100×100 @ >60 fps) ·
[MeshPart polygon limit](https://www.alpha3d.io/knowledge-base/roblox-meshpart-polygon-limit) ·
[accessory limits](https://nilo.io/articles/roblox-polygon-limits-accessories) ·
[custom meshes / LOD](https://nilo.io/articles/advanced-roblox-custom-meshes) ·
[cloud LOD & mesh streaming](https://www.creation.dev/learn/roblox-mesh-streaming-cloud-lod-optimization-guide) ·
[shared-assets explainer](https://www.creation.dev/learn/editable-mesh-image-shared-assets-roblox-2026) ·
[Roblox product framing](https://x.com/Roblox/status/1859359050326213031) ·
[unofficial API ref — EditableImage](https://robloxapi.github.io/ref/class/EditableImage.html) / [EditableMesh](https://robloxapi.github.io/ref/class/EditableMesh.html) ·
[CPU caching, buffers & native codegen](https://ffrostfall.net/stuff/list/cpu-caching-buffers-native-codegen/) ·
[Luau performance](https://luau.org/performance/) (site 403-blocked; search summary only) ·
[Sleitnick/rbxts-octo-tree](https://github.com/Sleitnick/rbxts-octo-tree) · [sayhisam1/Octree](https://github.com/sayhisam1/Octree) · [Nevermore Octree](https://quenty.github.io/NevermoreEngine/api/Octree/) ·
[Yonaba/Jumper](https://github.com/Yonaba/Jumper) · [lance0805/a-star-lua](https://github.com/lance0805/a-star-lua) ·
[YetAnotherNet buffer compression](https://yetanotherclown.github.io/YetAnotherNet/docs/getting-started/buffer-compression/) ·
[officialmmt/OpenRoblox](https://github.com/officialmmt/OpenRoblox) · [UpliftGames/wally](https://github.com/UpliftGames/wally) · [Rojo](https://rojo.space).

**Blocked from this environment and therefore absent:** `create.roblox.com`, `devforum.roblox.com`,
`luau.org`, `wally.run`, and the authenticated GitHub REST API (`api.github.com/repos/…`,
`/git/trees/…`, `/search/code`). Working: `raw.githubusercontent.com`, `github.com` HTML, and
`api.github.com/search/repositories`.

---

## The honest assessment

### What the evidence genuinely supports

**1. A single, modest-resolution, fully software-rendered 2D canvas at 60 fps. Confidently.**
This is the best-evidenced capability on the platform. Two mature libraries, an N64 emulator, a
terminal emulator, several raytracers and a 2D physics engine all ship it. The supported envelope
is **one `EditableImage` of 100×100 to roughly 256×256 with full per-pixel work, or up to
1024×576 if most pixels are blitted sprites rather than shaded**. `[SOURCE-READ]` + `[INFERRED]`

**2. Runtime texture generation and painting, at any resolution up to 1024², as long as it is
not per-frame.** Generating a texture once — a painted skin, a procedural material, a stamped
decal, a baked minimap — is comfortably affordable. It is *animating* a 1024² canvas that is not.
`[INFERRED]` from the 38.7 ms full-repaint figure.

**3. Player-facing creation tools: sculpting, painting, avatar customisation.** This is what
Roblox built the APIs for, documents end-to-end, and monetises through `AvatarCreationService`.
`WrapDeformer` + a cage `EditableMesh` is a real, supported character-deformation path.
`[DOCUMENTED]`

**4. Deformation of a bounded set of meshes — water surfaces, cloth, morphs, dents.** Position-only
edits on `FixedSize` meshes are cheap and reflect immediately without re-baking. The water
projects prove this pattern at scale with pooled chunks. `[DOCUMENTED]` + `[SOURCE-READ]`

**5. Offline-authored, runtime-assembled content.** Compile assets to Luau modules or compressed
buffers (`EncodingService` zstd), ship them, decode at runtime. Ro2D's `png2lua`/`bake_font`
pipeline and CanvasDraw's zstd `ImageData` both do this and it sidesteps every budget.
`[SOURCE-READ]`

### Where the real walls are

| Wall | Why it's a wall |
| --- | --- |
| **One displayed `EditableImage` update per frame** | Not a performance issue you can optimise around — it is an engine scheduling rule. A multi-canvas UI refreshes at 60/N fps. `[DOCUMENTED]` |
| **32 MB / ~8 live editable objects on the client** | Caps *architecture*, not just speed. You cannot hold a world of editable chunks; you must bake and release. `[COMMUNITY, SECOND-HAND]` + `[INFERRED]` |
| **~22 ms per `CreateMeshPartAsync`** | The only way to refresh collision, and it costs more than a frame. Streaming destructible geometry is out. `[COMMUNITY, SECOND-HAND]` |
| **20,000 triangles per `EditableMesh`** | A hard error. ~16³ voxels per chunk. `[DOCUMENTED]` |
| **No GPU compute** | Every pixel and vertex is CPU-side Luau. Parallel Luau across Actors is the only scaling lever, and it costs a serial merge phase. `[INFERRED]` |
| **Identity gating** | 13+, ID-verified, dashboard toggle. A business dependency on a personal verification, plus a reported bug where access is revoked mid-session. `[DOCUMENTED]` + `[COMMUNITY, SECOND-HAND]` |
| **Mobile is the real target, and it is much weaker** | Roblox's own docs: *"PCs are affected by these budgets much less than mobile and console, so developers often get surprised."* Every community number above was measured on a PC. `[DOCUMENTED]` |

### Ambitious ideas the evidence does NOT support

- **A full-screen software renderer at 1024×1024, 60 fps.** A bare buffer fill of that canvas is
  ~2.3 frames before any shading. No project has ever shipped it. The N64 emulator chose 320×240.
  `[INFERRED]` + `[SOURCE-READ]`
- **Real-time path tracing at useful resolution.** The most credible number is 100×100. The
  best-engineered attempt (Radius, built on parallel Luau + OSGL) has been **deprecated by its
  own author**. Take that as a data point, not an accident. `[COMMUNITY, SECOND-HAND]`
- **A Minecraft-scale destructible voxel world on `EditableMesh`.** 20k triangles/chunk × ~8 live
  editables × 22 ms per bake makes streaming chunk updates arithmetically impossible at
  interactive rates. **No open-source project has done it, which after this much searching is
  itself strong evidence.** `[INFERRED]`
- **Server-authoritative procedural content pushed to clients as editables.** Editables don't
  replicate. Send seeds and parameters; regenerate per client. `[COMMUNITY, SECOND-HAND]`
- **Runtime CSG, runtime LOD, runtime mesh decimation.** No library, no engine API, no prior art.
  If you need these, you are writing computational-geometry research code in Luau. `[INFERRED]`
- **Many independent animated canvases** — minimaps, portraits, screens, scopes — all live at
  once. The per-frame update rule and the 32 MB budget both forbid it. Composite into **one**
  canvas instead. `[DOCUMENTED]` + `[INFERRED]`

### The absences, stated plainly

Absence of prior art is a finding. After ~30 searches and direct reads of every repository I could
reach, **the following do not exist as open-source Roblox projects**: a marching-cubes or dual-
contouring `EditableMesh` library; a greedy-meshing `EditableMesh` library; a runtime CSG library;
a mesh decimation / LOD library; a mesh-chunk streaming manager; a destruction library; a minimap
generator; a general image-filter/convolution library beyond boatbomber's blur; a general 3D
geometry kernel; and **any published, reproducible benchmark suite for `EditableMesh` at all.**

The `EditableImage` half of this API pair has a healthy ecosystem. The `EditableMesh` half has
Roblox's own avatar sample, some ocean simulations, and not much else. If this team builds
mesh-side infrastructure, it is building it alone — which is both the cost and, if it is any good,
the opportunity.

### The three things to do first

1. **Build the measurement harness** (§4.4). Every ceiling in this chapter is either documented
   (and therefore an engine rule, not a target) or second-hand (and therefore unverified). One
   engineer-day on a low-end phone converts this chapter from research into fact.
2. **Write the pixel layer against a bare `buffer`**, using the §1.1 convention, with `--!native`
   and `--!optimize 2`. Then FastCanvas, OSGL, or your own code are interchangeable adapters —
   which also resolves the licence problem, since the two best libraries are **not** OSI-licensed.
3. **Design for one canvas and one baked mesh at a time**, with pooling and explicit `Destroy()`,
   from the first commit. Retrofitting an ~8-object budget onto a system that assumed unlimited
   editables is a rewrite, not a refactor.
