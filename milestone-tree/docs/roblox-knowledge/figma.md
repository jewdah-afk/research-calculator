# Figma for game UI and art: knowledge base (state as of September 2026)

Part of the Milestone Tree NG+ "fat library". Topic: **everything Figma can do (2025–2026) for a high-end game UI and
art pipeline**, the Figma MCP server this project's agents can drive, the best game UI work made in Figma, and how
Figma can go deeper into this project (cosmic neon incremental, painted parallax realm, ornate relic UI in dark crystal
and gold). It ends with ranked, costed opportunities.

**How claims are tagged**

| Tag | Meaning |
|---|---|
| **[V]** | From an official Figma source: help center, Figma blog, release notes, or developer docs |
| **[MCP]** | Observed directly through the Figma MCP server in this session (2026-09-25): a tool schema, a skill file, or a read-only call result |
| **[BETA]** | Open beta, closed beta or waitlist. Behaviour, limits and pricing can still change |
| **[C]** | Third-party or community source (reviews, blogs, forum), not confirmed by Figma |
| **[U]** | Unverified. My inference or design advice; test before relying on it |

Plan context: the account is **jwda (jacoblsattler@gmail.com), Professional plan, Full seat, team admin**, plan key
`team::1657975936717760073` [MCP]. Several Figma features are gated by plan; the Pro-plan consequences are called out
where they matter.

---

## 0. The facts that matter most

1. **Figma now has programmable GPU shaders.** Shader *fills* (generate pixels) and shader *effects* (transform the
   layer beneath) are WebGPU programs written in **WGSL** inside a TypeScript `main.ts` with `setup()` / `render()`
   and `defineProperties()` controls. They stack with native effects, can be saved as styles and published to a
   library, are keyframeable in Motion, and since **2026-09-01** can be animated, react to the mouse, be published to
   the Community, and have their code read and downloaded [V][BETA]. The MCP server can **create and update** them
   (`create_shader` / `update_shader`) and **read the source of all 35 first-party shaders** (`get_shader`) [MCP].
2. **Figma Motion (open beta since 2026-06-24) is a real keyframe timeline** in design files: animation styles,
   manual keyframes, cubic and spring easing, motion variables (easing and timing), animated components, shader
   properties as tracks, and export to **MP4, WebM, GIF and animated SVG** (Lottie announced). Dev Mode copies the
   motion as CSS, JSON, React or motion.dev code [V][BETA]. Through MCP, `get_motion_context` returns keyframe tracks,
   easing curves and CSS/motion.dev snippets, and `export_video` renders an MP4 server-side (5–60 fps, up to 4096 px
   per side, polled as a job) [MCP].
3. **Figma Weave** (Weavy, acquired Oct 2025, ~$200M) is a node-based canvas over image, video, audio, 3D and LLM
   models (Nano Banana family, Imagen, Seedream, FLUX, Ideogram, Recraft, GPT image; Veo, Kling, Runway, Seedance,
   Luma, LTX, Wan; Rodin, Hunyuan 3D, Trellis, Meshy, SAM 3D) plus editing nodes (inpaint, outpaint, **Topaz
   upscale, Relight, Z-depth**, mask extraction, compositor, painter) [V][C]. Curated **Weave tools run inside Figma
   Design** on Pro and above (open beta, free during beta) [V][BETA]. The MCP server can list and run Weave tools and
   run models directly, **but every run is cost-gated** and this account **is not linked to Weave yet** [MCP].
4. **The Variables REST API is Enterprise-only.** On our Pro plan we cannot `GET/POST /v1/files/:key/variables`.
   Token sync must go through the Plugin API: the MCP (`use_figma`, `get_variable_defs`), a private generative
   plugin, or a token plugin with Git sync [V].
5. **Pro plan limits that shape the design system:** 10 variable modes per collection (Org 20); extended collections
   are Enterprise-only; Code Connect is Organization/Enterprise-only (and has no Luau parser anyway) [V]. We have 21
   layer hues, so "one mode per layer" does not fit in one collection (section 5.1).
6. **Native materials got much richer in 2025–2026:** Glass (light angle, intensity, refraction, depth, dispersion,
   frost, splay; out of beta Jan 2026), noise (mono/duo/multi), texture, progressive blur, up to 8 drop and 8 inner
   shadows per layer, 16 blend modes including Plus lighter (additive), pattern fills, and Figma Draw brushes,
   dynamic and variable-width strokes [V][C].
7. **Nothing Figma renders is live in Roblox.** Roblox GUI composites with plain alpha-over (no blend modes), caps GUI
   textures at 1024², and has no live blur, noise or refraction (see `ui-tech.md` 0.4, `platform.md`). Every Figma
   material must be **baked** to straight-alpha PNGs (or flipbooks, or video) and re-assembled with 9-slice,
   `ImageColor3`, UIGradient, UIStroke and UIShadow. Figma is the look-dev and spec tool; the bake is the product.
8. **Shader code is portable.** Because a Figma shader is plain WebGPU/WGSL with a tiny host contract, the same code
   can run in our headless-Chromium art pipeline (`art/render.js` already drives Playwright) to bake deterministic
   textures and flipbooks at any resolution [U]. This is the single most useful bridge between "live Figma
   look-dev" and "shippable Roblox asset".
9. **AI credits:** a Pro Full seat gets 3,000 Figma AI credits per month (Dev/Collab/View seats 500). The agent,
   agent-built shaders and plugins, motion generation, Weave tools, code layers and 3D transforms will consume
   credits after their betas; *using* shaders never does [V]. Weave's own plans (credits separate from Figma's) run
   Free 150 / Starter $24 1,500 / Pro $45 4,000 / Team $60 per seat 4,500 credits per month [C].
10. **MCP budget:** a Pro Full seat gets **200 read calls/day and 15/min** on the Figma MCP server; write tools (and
    `whoami`, `create_new_file`, `add_code_connect_map`) do not count [V].

---

## 1. Our file today, as the MCP server sees it

File `o9LP1hGo5A8exWLR28mASJ` [MCP]:

| Page (id) | Contents |
|---|---|
| Cover `0:1` | empty canvas |
| Foundations `2:2` | frame `3:2` (1920×1500): 21 layer chips (`Chip/M` … `Chip/★`, hex + `layer/<id>` labels), 5 state swatches (`state/bought`, `state/locked`, `state/complete`, `state/danger`, layer hue), a type ramp (Montserrat Black Italic 72/44, Sarpanch Black 56, Montserrat ExtraBold 16), 4 treatments (Bevel panel, Neon rim, Glass, Corrupted) |
| Components `2:3` | component sets: Map Node `4:40` (Locked / Available / Can Prestige / Selected), Prestige Button `4:47`, Tab `4:55`, Toggle `4:62`, Resource Header `4:63`, Tooltip `4:68`, Popup `4:91` (Milestone / Achievement / Corruption / Notice), Upgrade `5:47`, Perk Upgrade `5:58`, Milestone `5:75`, Buyable `5:112`, Challenge `5:173`, Achievement `5:180`, Corruption Tile `5:193` |
| Map `2:4` | 4 parallax frames: Sky ×0.15 (3840×2160), Far islands ×0.35, **World ×1.0 (3840×2560: art halves, 23 connection frames with glow/core/hot vectors, 21 `Node/*` instances)**, Foreground ×1.25 (4800×3200) |
| Screens `2:5`, Overlays `2:6` | empty (DESIGN.md Q-F1: code-first mockups; pushing them here is a planned follow-up) |

Observations:

- **The Map page lags the realm contract.** Figma has 4 planes (0.15 / 0.35 / 1.0 / 1.25); `art/realm.json` now has
  7 painted planes plus particles (sky 0.05, clouds 0.12, far 0.25, mid 0.45, near 0.7, world 1, fg 1.3, particles
  1.6). Node positions still agree (Figma `Node/M` centre 1500,1910 vs realm `m` 1500,1900; the 10 px is the widget
  anchor) [MCP].
- **`get_variable_defs` returned `{}` for the Foundations frame `3:2` and the Map Node variant `4:11`**, although the
  Foundations subtitle says every colour is a variable. Either the fills are raw hex or the tool does not see the
  bindings; a read-only `use_figma` listing of `figma.variables.getLocalVariableCollectionsAsync()` settles it
  before any token pipeline work [MCP][U].
- `get_metadata` with no node id listed only `Cover`; the other pages resolve when asked by id [MCP]. Treat the
  page listing as unreliable and keep page ids in docs (`2:2`–`2:6`).
- **Eight unrelated community libraries are subscribed** (Material 3 Design Kit, Simple Design System, iOS/iPadOS 26
  and 27, macOS 26 and 27, watchOS 26, visionOS 26). They pollute `search_design_system` and the Figma agent's
  grounding; remove them [MCP].
- No shaders are used in the file yet (`list_file_shaders` → none) and the account's generative-plugin library is
  empty [MCP].
- Visual read of the screenshots: the World frame already sells "cosmic neon" (glowing tree, rift, floating islands).
  The components are clean "modern neon glass" (Montserrat italic, rounded plates, soft outer glows). They are **not
  yet the planned relic direction** (dark crystal, gold filigree, per-layer bespoke frames): no metal, no ornament,
  no material texture, a single light direction is not enforced. That gap is where Figma's 2026 tools help most.

---

## 2. Figma's feature set (2025–2026) that matters for high-end game UI and art

### 2.1 Variables and tokens [V]

- **Types:** colour, number, string, boolean, plus (2026) **easing and timing** variables for motion (Plugin API
  update 133, 2026-08-05) and **composed colours** that keep a colour and a separately authored opacity together
  (`VariableComposedColor`, `COLOR_OPACITY` scope, update 139, 2026-09-17). Opacity variables can be aliased and
  applied at scale (2026-09-03).
- **Modes:** Starter 4 → **Professional 10**, Organization 20 modes per collection (Schema 2025). **Extended
  collections** (inherit a parent system and override per brand) are **Enterprise-only**.
- **Scopes** restrict where a variable appears (fill, stroke, text fill, gap, radius, effect, font…); **code syntax**
  stores a per-platform name (Web/Android/iOS) on each variable, which we can abuse to hold the Luau path
  (`Theme.C.panel`) [U].
- **Prototyping logic:** set-variable actions, **conditionals (if/else)**, **multiple actions per trigger**, and
  **expressions** (string concatenation, arithmetic, boolean logic). One frame plus variables can simulate a whole
  currency/upgrade loop.
- Motion variables: switching a mode at page level re-times every animation that references it ("snappy" vs
  "cinematic" motion modes).

### 2.2 Layout and components [V]

- **Auto layout** (horizontal, vertical, **grid**, wrap; **vertical wrap** 2026-09-25; `SPACE_EVENLY` /
  `SPACE_AROUND` 2026-08-31), min/max sizes, absolute children. Grid auto layout (Config 2025) spans rows and columns.
- **Component properties:** variant, boolean, text, instance swap, preferred values, and **slots** (open beta
  2026-03-05, **GA 2026-06-10**): a slot is a child frame of a component with freeform content; options include
  `minChildren`, `maxChildren`, `displayEmptyByDefault`, `stretchChildOnInsert`, `allowPreferredValuesOnly`.
  Slots let one "Relic Frame" component take any body content without detaching.
- **Interactive components** switch variants on hover/press/click inside prototypes.
- Text: variable fonts (`FontVariationSettings`, 2026-09-03), `textWrapStyle` balance/pretty (2026-08-14), text on
  a path (Draw).

### 2.3 Paint, effects and blend modes [V]

| Capability | Details | Roblox translation |
|---|---|---|
| Fills | solid, linear / radial / angular / diamond gradients, image (fill, fit, crop, tile), **video** (paid), **pattern** (Draw), **noise fill**, **shader fill** | linear → UIGradient; radial/conical → UIGradient v2 (Studio beta); everything else baked |
| Drop shadow | up to **8** per layer, x/y, blur, spread, colour | UIShadow (shapes only, ≤ 100 on screen) or baked glow sprites |
| Inner shadow | up to **8** per layer | baked (bevels, rims) |
| Layer blur | uniform or **progressive** (1 per layer) | baked |
| Background blur | uniform or progressive (1 per layer) | no live blur; pre-blurred realm copy (`ui-tech.md` idea 13) |
| Noise | **mono / duo / multi**, size x/y, density (≤ 2 per layer) | baked grain |
| Texture | size x/y, radius, clip to shape (1 per layer) | baked |
| **Glass** | light angle, light intensity, **refraction, depth, dispersion (chromatic), frost, splay** (1 per layer); out of beta 2026-01-27 [C for date] | baked crystal plates; the dispersion rim is the "relic crystal" look |
| Blend modes | 16 on layers, fills and effects: darken, multiply, **plus darker**, colour burn, lighten, screen, **plus lighter (additive)**, colour dodge, overlay, soft/hard light, difference, exclusion, hue, saturation, colour, luminosity | **none in Roblox GUI** (alpha-over only); additive exists only in 3D (`LightEmission = 1`). Bake, or move the glow to 3D |
| Shader effect / fill | custom WebGPU, stackable, keyframeable (section 3.2) | bake (PNG, flipbook, video) |

Render order inside one layer: layer blur, noise and texture render before strokes and inner shadows.

### 2.4 Figma Draw (illustration inside Design files) [V]

Brushes (calligraphic and custom, with texture), **dynamic strokes** (wiggle frequency/amount), **variable-width
strokes** with width profiles (Plugin API can set profiles since update 123, 2026-01), pattern fill, text on a path,
shape builder, lasso, pencil, texture and noise effects, and (2026-08-24) **erase and drag-to-fill for vectors**.
Good enough for **vector filigree, runes, sigils and ornament linework**; not a painting app (no raster brush engine,
no layers-of-pixels workflow). Painted art still comes from our procedural painters, Blender, or AI.

### 2.5 Figma Motion [V][BETA]

- Motion mode per top-level frame: a timeline in seconds, scrub, auto-keyframe, time-based comments.
- **Animation styles** (Fade, Move, Scale… stackable, sequencable; custom styles "coming soon") and **manual
  keyframes** on transforms, opacity, corner radius, stroke weight, auto-layout spacing/padding, path trim start/end,
  width/height, **fill and stroke colours**, and **effect fields** (shadow offset/radius/spread/colour, glass
  refraction/dispersion/splay, noise size/density…) [MCP skill].
- Easing: ease in/out/in-out, back variants, custom cubic Bézier, spring presets (Gentle, Quick, Bouncy, Slow),
  custom spring (`bounce` 0–1), and **Hold** (step) [MCP skill].
- **Every exposed shader property is keyframeable** — a static shader becomes an animation by keyframing its
  controls.
- Motion variables and **animated components** (motion travels with the component through libraries).
- Export: **MP4, WebM, GIF, animated SVG** (Lottie in development). Above **1920×1080 or 30 fps needs a paid plan**
  (we have one). Dev Mode: CSS, JSON, React and motion.dev code.
- **3D transforms** (rotate frames, vectors and text on the z-axis with live preview, CSS export via MCP) are on a
  **waitlist**.

### 2.6 Prototyping [V]

Smart animate (matches layers by name; position, size, rotation, opacity, colour), interactive components,
variables + conditionals + expressions, multiple actions, overlays, scroll/overflow and sticky, **video in
prototypes** (mp4/mov H.264 or webm VP8, ≤ 100 MB, paid teams; autoplay/loop/mute on arrival), gamepad and keyboard
triggers (community files show gamepad-driven prototypes [C]). The Figma mobile app mirrors prototypes on a phone —
useful for testing thumb reach on the COMPACT layout.

### 2.7 AI inside Figma [V][BETA]

- **Figma agent** (open beta, Full seats on paid plans; free during beta): works in Design files; custom **skills**
  (reusable slash commands, shareable with the team), **connectors** (MCP: GitHub, Atlassian, Slack, Notion, Hex),
  attachments (files, PDFs, images, code), web search; builds components, motion, **shaders** and **generative
  plugins** from prompts. FigJam and Slides versions are on a waitlist.
- **Image tools** (paid plans): make an image (model picker; Gemini/Imagen family and Nano Banana are reported
  [C]), edit with prompt, remove background, expand, **boost resolution**, erase object, isolate object (select an
  area → new image layer). Batch background removal and boost exist.
- **Weave tools in Design** (open beta 2026-06-24, Pro/Org/Ent Full seats, free during beta): 30+ curated
  workflows at launch (generate mockup, **transfer style**, replace background, **change lighting**, text to vector
  illustration, apply colour palette, texturize, material extraction, on-brand icons); the Community can publish
  Weave tools since 2026-09-16.
- **Figma Make** (prompt → working React app; Make kits bring libraries, tokens and npm packages since 2026-03-26;
  public npm packages such as three.js work; visual editing and annotations 2026-09-24).
- **Code layers** (closed beta): a live React component as a canvas layer, convertible to/from design layers,
  importable from GitHub.
- **Generative plugins** (open beta): the agent writes a Figma-hosted plugin with a native-looking PropsKit UI;
  publishable to the organization or Community since 2026-09-01.

### 2.8 Other Figma products [V][C]

| Product | What it gives a game team |
|---|---|
| **Figma Sites** | publish a site from frames (scroll/parallax interactions, CMS, code layers, video 300 MB/file and 1 GB/site on paid plans, **10 custom domains on Pro**) [C for limits] — a landing page, wiki or patch-notes site that reuses the game's library |
| **Figma Buzz** | template-driven marketing assets; **bulk create** from a CSV/XLSX (text and image columns, image URLs), grid view for localized variants — thumbnails, ad sets, social posts at scale |
| **Figma Slides** | pitch/devlog decks from the same library |
| **FigJam** | flows, tutorial state diagrams (the MCP `generate_diagram` writes Mermaid flowcharts, state and sequence diagrams, Gantt, ERD into FigJam) |
| **Figma Weave** | the node canvas behind Weave tools; a **Figma node** (2026-09-17) pulls Design frames into Weave workflows with fonts and styles intact |

### 2.9 Dev Mode, Code Connect and the MCP server [V]

- Dev Mode: inspect, ready-for-dev statuses, the Motion tab (timeline inspection, code copy). Shaders have **no Dev
  Mode appearance** yet.
- **Code Connect** maps components to code snippets; **Organization/Enterprise only**, no plans for Pro. Its
  framework-agnostic template files could emit Luau strings, but we cannot use it on Pro.
- The remote **MCP server** is GA for all seats and plans (Schema 2025); section 3 documents it.

### 2.10 Plugin API: what code can generate inside Figma [V]

- Nodes of every design type, auto layout, components/variants/slots, variables (full CRUD), styles, text with any
  installed font, vectors via **vector networks** or `createNodeFromSvg`, variable-width stroke profiles.
- **Images:** `figma.createImage(bytes)` from PNG/JPG/GIF bytes. A plugin's UI iframe has full browser APIs, so it
  can render procedural textures with Canvas 2D, WebGL or WebGPU and hand the bytes to the sandbox [U from the
  documented iframe/sandbox split]. (The MCP `use_figma` runtime blocks `createImageAsync` and `setPluginData`
  [MCP]; use `upload_assets` for images there.)
- **Shaders** (update 130, 2026-06-23): `figma.listAvailableShaders()`, `figma.importShaderById()`, and paints /
  effects of `{ type: 'SHADER', properties: {...} }` (`ShaderPaint`, `ShaderEffect`).
- **Motion** (update 130/132): animation styles, manual keyframe tracks, `timelines`, `setTimelineDuration`,
  `figma.motion.playheadPosition` (read-only), spring conversion.
- **Video export** (update 131, 2026-07-16): `exportAsync` with `ExportSettingsMP4` / `WEBM` (fps, quality preset,
  size constraint) and `GIF` (fps, loop count) on an animated top-level frame; returns a `Uint8Array`.
- Classic plugins still use `exportAsync` for PNG/JPG/SVG/PDF of any node.

### 2.11 REST API and webhooks [V]

| Endpoint | Use for us | Limits |
|---|---|---|
| `GET /v1/images/:key?ids=…&format=png&scale=2` | render components/frames to PNG/JPG/SVG/PDF in CI | scale 0.01–4; images over **32 MP are scaled down**; Tier 1 (**15/min on Pro**) |
| `GET /v1/files/:key` (+ `/nodes`) | read the document tree, `geometry=paths` for vectors (edge curves!), plugin data, branch data | Tier 1 |
| `GET /v1/files/:key/images` | original image fills | URLs expire within **14 days**; Tier 2 (50/min) |
| Variables `GET local/published`, `POST` | token sync | **Enterprise only** — unavailable to us |
| Components / styles, version history, comments, dev resources | library audits, changelogs | Tier 2–3 |
| **Webhooks v2** | `FILE_UPDATE` (after 30 min of inactivity), `FILE_VERSION_UPDATE` (named version), `LIBRARY_PUBLISH` (split per asset type), `FILE_COMMENT`, `FILE_DELETE`, `DEV_MODE_STATUS_UPDATE`, `PING`; attach to a team, project or single file (since 2025-05-28) | needs a public HTTPS endpoint |

Pro Full/Dev seat rate limits: Tier 1 15/min, Tier 2 50/min, Tier 3 100/min (View/Collab seats are far lower).

---

## 3. The Figma MCP server in this session (hands-on)

### 3.1 Tool inventory [MCP]

| Tool | What it does | Kind / cost |
|---|---|---|
| `whoami` | handle, email, plans + keys, seats | free (not rate-counted) |
| `get_metadata` | XML tree of a node/page (ids, types, names, boxes) | read |
| `get_design_context` | reference code + screenshot + asset URLs for a node (needs the `figma-design-to-code` skill) | read |
| `get_screenshot` | PNG of a node, `maxDimension` up to 65536, returned as a short-lived URL | read |
| `get_variable_defs` | variables bound under a node | read |
| `get_libraries`, `search_design_system` | subscribed libraries; search components/variables/styles | read |
| `download_assets` | a node's export render (png/jpg/svg/pdf, scale ≤ 4) + up to 20 raw source images + up to 20 SVGs | read |
| `upload_assets` | up to 60 single-use upload URLs per call; PNG/JPG/GIF/WebP ≤ 10 MB (optionally as fills on given nodes), **SVG imported as editable vectors** | write |
| `use_figma` | run Plugin API JavaScript in the file (needs the `figma-use` skill; motion needs `figma-use-motion`) | write |
| `get_motion_context` | keyframe tracks, easing curves, pre-computed CSS `@keyframes` and motion.dev snippets, `timelineCohorts` (recursive option) | read |
| `export_video` | server-rendered **MP4** of a top-level animated frame; `fps` 5–60, `quality` low/medium/high, `constraint` SCALE/WIDTH/HEIGHT (clamped to 10× / **4096 px**), `ttlSeconds` 30 s–7 d; long renders return a `jobId` to poll | read; slow, "expensive" |
| `list_shaders`, `get_shader`, `list_file_shaders` | account-library shaders (incl. 35 first-party) and their source | read |
| `create_shader`, `update_shader` | author a shader (needs the `figma-shaders` skill) | write; agent/AI credits after beta [V] |
| `list_generative_plugins`, `get_generative_plugin`, `create_generative_plugin`, `update_generative_plugin` | author Figma-hosted plugins | write |
| `weave_list_tools`, `weave_get_tool_inputs`, `weave_run_tool`, `weave_get_tool_run_output`, `weave_cancel_tool_run` | published Weave workflows | runs spend Weave credits; **explicit approval required** |
| `weave_find_model`, `weave_run_model`, `weave_get_model_run_output` | run a single Weave model directly (e.g. "nano banana 2", "veo 3") | same gating |
| `weave_upload_asset` | in-chat file picker for image/video/audio/3D inputs | — |
| `generate_diagram`, `get_figjam` | Mermaid → FigJam; read FigJam | write / read |
| `create_new_file` | new Design, FigJam or Slides file in drafts or a project | write |
| Code Connect tools | component ↔ code mappings | Org/Ent only |

Skills served by the server (`skill://index.json`): figma-use, figma-use-motion, figma-shaders,
figma-generative-plugins, figma-generate-library, figma-generate-design, figma-design-to-code,
figma-implement-motion, figma-code-connect, figma-create-new-file, figma-generate-diagram, figma-use-figjam,
figma-use-slides, figma-swiftui [MCP].

### 3.2 Shaders: the runtime contract [MCP]

From the `figma-shaders` skill and the first-party sources:

- **Two kinds.** `effect` samples `frame.input` (premultiplied alpha in and out); `fill` has no input and outputs
  straight alpha. The kind cannot change on update.
- **Module shape.** `main.ts` exports `default function Effect() {}`, `setup(device, frame)` and `render(device,
  frame)`, and calls `defineProperties(Effect, {...})` at module scope. The only import allowed is
  `defineProperties` from `figma:shaders`; **no module-scope `let`/`const`/`var`**.
- **Real WebGPU.** `device` is a `GPUDevice`: any number of render or **compute** passes, intermediate textures
  (first-party shaders use `r16float` masks and `rgba8unorm` intermediates), samplers, mip chains. WGSL starts with
  `diagnostic(off,derivative_uniformity);`, entry points `vs_main` / `fs_main`, uniforms padded to 16 bytes,
  pipelines cached per `frame.output.format`.
- **Frame inputs:** `frame.input`, `frame.output` (width, height, format), `frame.params`, `frame.state` (persistent
  bag), `frame.time` (ms, absolute), `frame.deltaTime`, `frame.frame`, `frame.mousePosition` (layer pixels).
  `metadata.isAnimated` / `usesMouse` must match the source.
- **Sandbox:** no DOM, `fetch`, timers, console, `Float64Array` or `Float16Array`.
- **Controls** (render as native Figma UI): boolean, string, number slider or input (with unit), numeric select
  (dropdowns must be numeric), colour (RGBA 0–1), **gradient (2–8 stops)**, point, point-radius, point-point-line,
  point-angle-radius, colour-point. Percent units keep geometry resize-relative.
- **Workflow:** `whoami` → `create_shader(name, description, planKey, kind)` makes a scaffold → `get_shader` →
  write the full `main.ts` → `update_shader(files:[{path:"main.ts"}], commitMessage, metadata)`; on a build error
  fix once and retry once. Try-link:
  `https://www.figma.com/file/new?try-tool-resource-content-id=<id>&try-tool-resource-type=gen_effect|gen_fill&type=design&mode=design`.
- **Product limits [V]:** only **one animated or interactive shader plays per page** at a time (Play button above
  the layer); edit access required; no Dev Mode appearance; export = PNG of a fixed frame, MP4 through Motion, and
  the raw JS/WGSL code (MCP, code viewer; the blog also says HTML and React export).
- **Colour depth [U]:** the output format is whatever Figma hands the shader, and the first-party Bloom and
  Chromatic metal run their intermediates in `rgba8unorm`, so treat shader output as **8-bit LDR**. No HDR export.

**First-party library (35 shaders, owner "figma")** and what each is good for here:

| Shader | Kind | Use for Milestone Tree |
|---|---|---|
| **Nebula** | fill | layered star fields + Perlin nebula clouds, 3 colours, star density, seed, centre, and a **`travel` 0–1 control that loops seamlessly** (0 and 1 render identically) → keyframe travel 0→1 = a perfect looping sky flipbook or VideoFrame loop |
| **Light rays** | effect, animated | volumetric rays from a point-angle-radius source, luma/alpha threshold, two tints, **edge glow** (multi-pass `r16float` blur) → god rays through the tree canopy, prestige burst, rift light |
| **Bloom** | effect | threshold, intensity, softness, tint, vignette, spotlight mask (half/quarter-res blur) → pre-bloomed node glows, hero text |
| **Chromatic metal** | effect | derives a height field from the layer's blurred alpha + noise, maps it through an **8-stop gradient** with repeats, RGB split, roughness → with a gold ramp it turns any vector ornament into **molten gold filigree** |
| **Glowing particles** | effect | bokeh particles seeded from the bright areas of the image → sparkle dressing on gems and nodes |
| Shape-based particles | effect, mouse | particle system with velocity fields that follow the pointer → hover juice exploration |
| Moving blobs | effect, animated | simplex-noise refraction/displacement, dispersion → the Multiverse rift surface, corruption goo |
| Pattern refraction | effect | refraction through lenticular/zigzag/wave patterns with IOR dispersion and frost → **faceted crystal** glass |
| Water caustic | fill | shimmering caustics → light-fall pools, crystal interiors |
| Clouds | fill | sky gradient, coverage, density, warp → cloud-plane look-dev |
| Fractal noise | fill | static layered noise → grain, masks, dirt maps |
| Mesh gradient / Moving gradient | fill | 16-point bicubic mesh; animated 3D mesh gradient → plate bodies, aurora backdrops |
| Glowing wave | fill, animated | glowing sine wave → energy links, loaders |
| Gradient map / Duotone / Channel mixer / Color adjust / Filter presets | effect | grading (OKLab gradient map!) → unify the realm grade, per-layer tints |
| Lens distortion / Warp / Pixel stretch / Slice shift / CRT Screen / Halftone / Dither / Pixelate | effect | chromatic aberration, glitch, scanlines → the **corrupted layer** treatment |
| Outlines (JFA SDF rings) / Colored edges (Sobel) | effect | multi-ring outlines, rim light on silhouettes → node rings, rune glow |
| Gooey merge | effect | metaball merge → liquid mana, corruption spread |
| Bokeh blur | effect | highlight discs → foreground depth of field look-dev |
| Hatching, Moire, Concentric patterns, Pattern grid | effect/fill | ornament backgrounds, engraved metal hatching |

### 3.3 Generative plugins [MCP]

Scaffold (`create_generative_plugin`) → read `manifest.json`, `ui.html`, `code.ts` → replace `code.ts` and `ui.html`
(`update_generative_plugin`; the manifest and file set are fixed). UI must be functional (PropsKit web components:
`fig-slider`, `fig-input-color`, `fig-input-gradient`, `fig-input-palette`, `fig-joystick`, `fig-image upload`,
`fig-input-file`…), dynamic-page-safe async APIs, bounded work, relaunch data, **no secrets and no authenticated
network calls** (plugin source is readable). Plugins are Figma-hosted and available in all the user's files;
organization/Community publishing since 2026-09-01 [V]. Try-link type `gen_tool`.

### 3.4 Motion through MCP [MCP]

- Authoring is `use_figma` with the motion API (`applyManualKeyframeTrack`, `applyAnimationStyle`,
  `setTimelineDuration`, `figma.motion.figmaAnimationStyles()`), gated by a user feature flag (`metronome`); if the
  API throws "not a supported API", motion is not enabled for that user. **Animate descendants, never the
  top-level frame itself**; the timeline belongs to the top-level frame.
- Transform tracks compose with the resting transform (translation additive, scale multiplicative); opacity, radius,
  size, stroke and spacing are absolute. Fill/stroke colour tracks index into the paint array (solid paints only);
  effect tracks index into `node.effects` with allowed fields `OFFSET_X/Y`, `RADIUS`, `SPREAD`, `COLOR`,
  `REFRACTION_RADIUS`, `SPECULAR_ANGLE/INTENSITY`, `CHROMATIC_ABERRATION`, `SPLAY`, `REFRACTION_INTENSITY`,
  `START_RADIUS`, `NOISE_SIZE_X/Y`, `DENSITY`, `EFFECT_OPACITY`, `SECONDARY_COLOR`.
- `get_screenshot` shows only the resting state. To check motion, `export_video` small (`WIDTH` 320–768, `fps` 5–10,
  `quality: low`), then pull frames locally with `ffmpeg -ss <t>`.
- `get_motion_context` is the handoff: tracks + easing + CSS/motion.dev snippets, which we can translate to Luau.

### 3.5 Weave through MCP [MCP]

- `weave_list_tools` / `weave_find_model` currently answer: *"You haven't linked your Figma account to Weave yet.
  Open https://app.weavy.ai/settings?section=profile … link your Figma account."* Linking is the first step.
- Runs are **quote-then-approve**: a call without `acknowledgedCost` returns `inputs_required` or
  `cost_confirmation_required`; the agent must show the cost and get an explicit Approve/Cancel before re-calling
  with the quoted cost, **every run**. Dynamic-cost tools confirm with `-1`. `numberOfRuns` 1–10; iterator inputs run
  once per item. Inputs: text, integer, boolean, select, seed, image, video, audio, 3D, colour; image/video by https
  URL or `weave_upload_asset`. Outputs come back as downloadable URLs with type, size and format.
- Weave FAQ: Weave and Figma credits are separate; the products are billed separately for now; Weave tools inside
  Figma Design are free during the open beta [V].

### 3.6 Budget and etiquette

200 reads/day and 15 reads/min on Pro (section 0.10). This research used ~20 reads. Batch reads, prefer
`get_metadata` over `get_design_context` for structure, and keep `export_video` renders small and rare.

---

## 4. The best of the best: premium game UI made in Figma

### 4.1 Reference sources

- **Game UI Database 2.0** — 1,300+ games and 55,000+ screens, filterable by screen type (skill tree, title, player
  menus, settings), material, colour and animation. The benchmark library for "what AAA does" [C].
- **Figma Community files worth dissecting:** *Final Fantasy VII Remake UI Kit and Prototypes*; *Game UI – Reward
  Screen Dark Fantasy* (carved stone, ornate metal, JRPG reward popup); *Game UI Dark Fantasy RPG*; *Games UI/UX
  Elements Library 10,000+* (econev); *FUI / HUD Elements*; *Clash of Clans – UI Components*; *League of Legends
  Interface*; *Genshin Impact Web UI*; *Game UI Wireframe Kit* and *Game UX Kit* for flows; *Glass effect
  playground* and *Linear dodge/linear burn (plus lighter/darker)* for material technique [C].
- **Kits sold with a Figma → engine pipeline:** *Dark Gold RPG — Idle Game UI Kit* (itch.io; 8 colour variables
  recolour the kit, 30+ components, documented 9-slice borders, @1x/@2x/@3x PNG, Unity package, 8 Lottie
  animations under 5 KB) — the closest commercial analogue to our "dark + gold idle" target [C].
- **Case studies:** MY.GAMES *Rush Royale* moved its UI team from Photoshop to Figma (sprite component library, a
  9-slice plugin mirroring Unity's slicing, fewer routine hand-offs, but artists missed painting directly in the
  layout) [C]; Riot's *Play* interaction design system and several Riot client/League UI studies on Behance (Alena
  Eresko, "Riot Games Platform UI") [C]; *STAR WARS Jedi: Survivor* skill-tree case study (Behance) [C].
- **Roblox-specific bridges:** FigBloxUI, Figblox, Figma to Roblox UI, FigToRbx, GuiForge, RoImport (Figma frames →
  Roblox GUI instances + images) [C]. None handles AAA materials; they are layout movers.

### 4.2 What makes the premium ones look premium (and how to do it in Figma)

1. **Material stacks, not flat fills.** Each plate is 5–9 layers: dark body gradient, inner shadow (top-left
   highlight / bottom-right occlusion), a 1 px hairline highlight stroke, a metal rim (angular gradient for
   anisotropic gold), inset ornament, grain/noise at 2–4 %, a soft outer glow, and a specular glint. Figma: stacked
   fills + up to 8 inner shadows + noise/texture + Plus lighter glints; now also **Chromatic metal** for the rim and
   **Glass** for crystal insets.
2. **One light direction** (our key light is the cosmic sun, upper left, per `art/README.md`). Every bevel, glint and
   drop shadow agrees. Figma: put the light angle in number variables and bind shadow offsets / glass light angle to
   them (effect fields are bindable to variables [U: verify which effect fields accept bindings]).
3. **Ornament grammar.** Corners carry the detail (so 9-slice works), edges are plain repeatable bands, centres are
   empty. Per-tier escalation (common → legendary) adds filigree, gems, then animated light. Figma: component set
   `Frame/<layer>/<tier>` with slots for content.
4. **Hierarchy through value, not hue.** Neon hues sit on near-black bodies; gold is reserved for "earned/valuable".
   Our Foundations already do this (layer hue + state swatches).
5. **Typography with treatment.** Display type with gradient fill, heavy stroke, hard offset shadow, and a subtle
   inner highlight; tabular digits for counters. Figma: text styles + effect styles; Roblox: UIGradient + UIStroke +
   a shadow clone (`ui-tech.md` 8).
6. **Motion is part of the spec.** Premium kits ship Lottie or timelines with the components (the Dark Gold kit's 8
   Lottie files). Figma Motion now makes this native.
7. **Prototypes with real state.** Variables + conditionals so reviewers feel costs, locks and unlock beats.
8. **Engine-honest export.** 9-slice metadata, white-tintable masks, @2x masters, alpha bleeding, atlas budgets. Our
   `art/ui/build.js` already bleeds alpha; the Figma side must emit the same contract.

### 4.3 Honest limits

Figma is vector- and UI-first. It is excellent for frames, ornaments, tokens, layout, motion specs, and (now)
shader-based materials and look-dev. It is **not** a painting tool, has no HDR pipeline, and its effects do not
exist in Roblox. AAA teams pair it with painting/3D tools; our equivalents are the procedural painters, Blender and
(optionally) Weave.

---

## 5. Pipeline: Figma as a deeper part of this project

Today (DESIGN.md Q-F1): code-first mockups are the source of truth; Figma holds Foundations, Components and a Map
snapshot; node geometry and edge control points came from Figma. Proposed split:

| Concern | Source of truth | Direction |
|---|---|---|
| Colour/type/spacing/motion tokens | **Figma variables** | Figma → `Theme.luau` (generated) |
| Component anatomy, states, 9-slice insets | **Figma components** | Figma → `art/ui` manifest |
| Painted realm layers | `art/` painters (deterministic) | art → Figma (upload for look-dev) |
| Materials (gold, crystal, glass, glow) | **Figma shaders + effects** (look-dev) | Figma → bake harness → PNG/flipbook |
| Motion (prestige, unlock, weather, tutorial) | **Figma Motion** | Figma → `Motion.luau` spec tables + MP4 references |
| Trailer, thumbnails, store art | Figma Motion / Buzz / Weave | Figma → Roblox Creator Hub |

### 5.1 Tokens: Figma variables ↔ `src/client/Core/Theme.luau`

- **Collections** (Pro: ≤ 10 modes each):
  - `Base` (1 mode): `void`, `deep`, `panel`, `panel2`, `panel3`, `stroke`, `strokeHi`, text roles, state colours —
    exactly `Theme.C`.
  - `Layer` — 21 layers do not fit in 10 modes. Either (a) store each layer as variables (`layer/m/hue`,
    `layer/m/hueHi`, `layer/m/hueDeep`, `layer/m/body0..2`, `layer/m/text`, `layer/m/soft`, mirroring
    `art/ui/themes.js`) and use a component **variant property `Layer`**; or (b) split into `Layer A` / `Layer B` /
    `Layer C` collections of ≤ 10 modes with an identical variable set. (a) is simpler and matches `Theme.hue(layer)`.
  - `Tier` (HIGH / LOW / COMPACT modes): radii, stroke widths, glow sizes, type sizes (mirrors Layout modes).
  - `Motion` (Snappy / Cinematic / Reduced modes): easing and timing variables (2026-08 types).
  - `Material`: gold ramp (`UI_GOLD` hi/light/mid/low/deep/ink), crystal, light angle.
- Put the Luau path in each variable's **code syntax** field (`Theme.C.panel`) so the generator needs no mapping
  table [U].
- **Pro-plan route (no Variables REST):** a small script run by an agent: `use_figma` (read-only) returns
  `getLocalVariableCollectionsAsync()` + values per mode as JSON → a Node script writes
  `src/client/Core/ThemeTokens.luau` (generated, never hand-edited) → `Theme.luau` requires it → a check fails CI if
  the generated file differs. Alternatives: a private generative plugin with an "Export tokens JSON" button (file
  download), or Tokens Studio with GitHub sync [C]. Reverse direction (code → Figma) is the same `use_figma` with
  `setValueForMode`.
- `Theme.lift/shade/mix` are "the Figma formulas" (DESIGN.md): keep derived colours derived in Luau; only primitives
  and semantic aliases live in Figma.

### 5.2 Ornate relic frames and cards

- **Anatomy** (one component set per frame family): `Body` (dark crystal gradient, tintable), `Rim` (gold, *not*
  tinted), `Ornament/corners` ×4 (gold filigree vectors + Chromatic metal), `Crystal inset` (Glass effect, layer
  hue), `Glow` (layer hue), and a **slot** for content. Variant properties: `Layer` (21 or per-family motif:
  amethyst, ice, corrupt…), `State` (Can / Bought / Locked / Maxed / Selected), `Tier` (common → mythic), `Size`.
- **Export contract to Roblox:** per frame, export (a) a white/grey **tint mask** PNG for `ImageColor3` layer
  tinting, (b) an untinted **gold** PNG, (c) an optional **glow** PNG, all @2x, with the 9-slice insets stored in the
  component description or a naming convention (`slice=48,48,48,48`). Pull with `GET /v1/images?scale=2` (REST,
  PAT) or `download_assets` (MCP), then run the existing alpha-bleed + atlas packing in `art/ui/build.js`. Keep every
  image ≤ 1024².
- **Why split gold from body:** `ImageColor3` multiplies; a single tinted image cannot keep gold gold on a purple
  layer. Two stacked ImageLabels (tinted body + untinted gold) keep the metal constant across all 21 hues.
- **Relic cards:** the same system plus a foil pass (Pattern refraction or Chromatic metal with a rainbow ramp,
  keyframed), a rarity light sweep (Light rays with `travel`-style keyframes) and a reveal motion spec.

### 5.3 Shader-generated textures for Roblox (the bake harness)

1. Look-dev in Figma: apply first-party or custom shaders to real frames (layer chips, realm renders uploaded via
   `upload_assets`), tune controls live.
2. Read the exact source with `get_shader` / `list_file_shaders` (file-pinned versions) and record the chosen
   control values.
3. Bake in our pipeline: a ~100-line host page for Playwright that provides `defineProperties`, a `frame` object
   (input texture from a PNG, output canvas, params, time) and calls `setup`/`render` in headless Chromium with
   WebGPU enabled (Linux: `--enable-unsafe-webgpu --enable-features=Vulkan --use-vulkan=swiftshader
   --use-webgpu-adapter=swiftshader`, software but deterministic [C]). Output: PNG stills, 8×8 flipbook sheets, or
   frame sequences, through the same `tile.js` checks.
4. Cheap path without a harness: Figma export PNG (fixed frame) or Motion → `export_video` MP4 → ffmpeg → frames.

[U] Check the licence/terms before shipping baked output of Figma's *first-party* shader code outside Figma; our
own shaders (authored via `create_shader`) are ours.

### 5.4 Cinematic VFX as flipbooks and video

- Animate shader controls or layers in Motion (e.g. Nebula `travel` 0→1 for a seamless loop; Light rays speed and
  intensity; Moving blobs for the rift surface; Bloom intensity pulse), export with `export_video` at 30 fps.
- ffmpeg slices frames into Roblox sheets: **8×8 of 128² per 1024² sheet** for UI flipbooks (stepped at 24–30 fps via
  `ImageRectOffset`), or custom grids for `ParticleEmitter` (≤ 30 fps, grid 1–64 per axis) (`ui-tech.md` 5.4,
  `rendering-3d.md`).
- **Alpha:** MP4 has no alpha. For glows, render on black and either (a) use it on 3D particles with
  `LightEmission = 1` (additive, black disappears), or (b) derive alpha from luminance (un-premultiply from black) in
  ffmpeg for GUI use [U]. For hard-edged FX, prefer PNG stills from the bake harness.
- Full-motion backdrop: a looped MP4 in a `VideoFrame` (no alpha, 2,000 Robux per upload, ID-verified owner;
  `ui-tech.md` idea 12).

### 5.5 Motion specs → `src/client/Core/Motion.luau`

- Author prestige, layer unlock, weather transitions and tutorial beats as Figma Motion timelines on real
  components; bind timings to `Motion` variables.
- `get_motion_context(recursive)` → JSON tracks → generator emits Luau tables
  `{ target = "Glow", prop = "ImageTransparency", t0 = 0.12, t1 = 0.42, from = 1, to = 0.2, ease = "Quint/Out" }`
  that `Motion.tween` replays. Easing map: Figma `EASE_OUT` → `Enum.EasingStyle.Cubic` Out; `EASE_IN_AND_OUT_BACK` →
  `Back` InOut; `CUSTOM_CUBIC_BEZIER` → nearest `EasingStyle` or a sampled curve through `TweenService:GetValue`
  lookup; springs (`bounce`) → the spr-style springs already planned; `HOLD` → a step.
- Respect `Motion.luau` rules: only Position, Size, Rotation, UIScale, transparencies and UIGradient Offset/Rotation
  are tweened; everything else (colour, blur, shader controls) becomes baked frames or state swaps.
- Every spec also gets a small MP4 reference (`export_video`, WIDTH 768, fps 30) committed next to the spec for
  QA side-by-side with Studio recordings.

### 5.6 Tutorial and flow prototypes

- FigJam flow of the onboarding (via `generate_diagram`, stateDiagram-v2) linked to DESIGN.md.
- One prototype frame with variables (`points`, `milestones`, `hasPrestiged`) and conditionals that mirrors the real
  first 10 minutes; test on phones with the Figma app; iterate copy and highlight rings before any Luau.

### 5.7 Marketing and store assets

- Thumbnails and icon: master frames in Figma (icon 512², thumbnails 16:9 1920×1080 [U: confirm current Creator Hub
  specs]), built from the library so they match the game; Buzz bulk-create for A/B and localized variants.
- Key art: composite the realm layers in Figma, upscale/relight with Weave (paid credits), finish with shaders
  (Bloom, Light rays, Color adjust).
- Trailer shots: Motion scenes that pan across the World frame with parallax planes moving by their `f` factors,
  exported as MP4 (in-app export above 1080p/30 fps is allowed on our paid plan; MCP export up to 4096 px).
- Landing page / wiki / patch notes on Figma Sites from the same library.

### 5.8 Automation hooks

- Webhook `LIBRARY_PUBLISH` or `FILE_VERSION_UPDATE` on the file → a tiny public endpoint (e.g. a serverless
  function) → GitHub `repository_dispatch` → a job that pulls tokens/frames and opens a PR. Simpler first step: run
  the sync on demand by an agent, or on a schedule.
- Guard rails: named versions in Figma per release; the generated Luau and PNGs are the reviewed artefacts.

---

## 6. Figma ↔ Roblox translation table

| Figma | Roblox equivalent | Notes |
|---|---|---|
| Auto layout H/V | `UIListLayout` (+ `UIFlexItem`) | gaps and padding map 1:1 in scaled units |
| Grid auto layout | `UIGridLayout` / `UITableLayout` | no row/column spans |
| Min/max size | `UISizeConstraint`, `UITextSizeConstraint` | |
| Corner radius (per corner) | `UICorner` (per-corner live) | UICorner clipping needs a CanvasGroup |
| Stroke inside/center/outside, multiple | `UIStroke` v2 (position, several per object) | < 300 on screen |
| Drop shadow (shapes) | `UIShadow` | ≤ 100 on screen, no text/alpha-shaped shadows |
| Linear gradient | `UIGradient` | live |
| Radial / angular gradient | `UIGradient` Radial / Conical | **Studio beta**, needs a kill switch |
| Inner shadow, noise, texture, glass, blur, blend modes, shaders | — | **bake** |
| Text styles | `FontFace` + `TextSize` + `LineHeight` via `Theme.text` | Montserrat and Sarpanch ship with Roblox |
| Variables + modes | `Theme.luau` tables; StyleSheet token attributes (`"$Gold"`) | themes = swappable token sets |
| Interactive components (hover/press) | StyleSheet `:Hover` / `:Press` + Styling Transitions | native, no Lua connections |
| Smart animate / Motion | `TweenService`, springs, `Motion.luau` | tween only the allowed properties |
| Video fill | `VideoFrame` | no alpha; 2,000 Robux per upload |
| Image fill ≤ any size | `ImageLabel` ≤ 1024² per image | tile or atlas above that |

---

## 7. Opportunities for Milestone Tree

Ranked by visual/production impact. Cost: **S** < 1 day, **M** 2–5 days, **L** > 1 week. Money is noted where a
feature spends credits or Robux. Risk = technical or visual risk.

| # | Idea | Needs | Cost | Risk |
|---|---|---|---|---|
| 1 | **Relic material system**: gold filigree (Draw vectors + **Chromatic metal** with a gold 8-stop ramp), dark crystal bodies (**Glass** + Pattern refraction), per-layer motif inserts; a `Relic Frame` component set (Layer × State × Tier × Size, content slot) that replaces today's flat plates | Figma Draw, shaders (free to use), `use_figma` for bulk variants, export contract of 5.2 | L | Med (bake fidelity; keep gold untinted) |
| 2 | **Custom shader suite** authored for us: *Relic Crystal* (facets + dispersion + inner caustic), *Neon Filament* (white core, tinted halo, flicker), *Corruption* (slice shift + RGB split + scanline, keyed to `cp`), *Cosmic Dust* fill in realm palette, *Rune Ignite* (SDF outline sweep) — all parameterized, animated, keyframeable | `create_shader`/`update_shader` + figma-shaders skill; AI credits after beta | M | Med (WGSL build errors; one playing shader per page) |
| 3 | **Shader bake harness** in `art/`: run Figma WGSL shaders in headless Chromium (SwiftShader WebGPU) to bake deterministic PNGs and flipbooks at HIGH/LOW, checked by `tile.js` | Playwright (present), a `figma:shaders` shim, `get_shader` source | M | Med (software WebGPU speed; licence of first-party code) |
| 4 | **Cinematic flipbook VFX from Motion**: prestige burst (Light rays + Bloom pulse), rift surface (Moving blobs), rune ignition, coin spin, weather overlays → `export_video` → ffmpeg → 8×8 sheets for UI and custom grids for ParticleEmitters | Motion (open beta, `metronome` flag), `export_video`, ffmpeg | M | Med (no alpha in MP4 → additive or luma-alpha; 1024² cap) |
| 5 | **Token pipeline** Figma variables → generated `ThemeTokens.luau` with a CI diff check; Base / Layer / Tier / Motion / Material collections; Luau paths in code syntax | `use_figma` read-only, a Node generator | S–M | Low (Pro: no Variables REST; bind the Foundations fills first) |
| 6 | **Motion spec library → Luau**: prestige, layer unlock, milestone pop, weather, tutorial beats authored in Figma Motion with motion variables; `get_motion_context` → Luau spec tables + MP4 references | Motion, `get_motion_context`, generator in `art/` | M | Med (fidelity of easing mapping; property whitelist) |
| 7 | **Weave art pipeline**: Figma frame → Weave (Figma node) → style transfer to keep 21 layer motifs consistent, **Topaz upscale**, **Relight** to the cosmic key light, **Z-depth** to split paintings into parallax planes, **image → 3D** (Rodin/Hunyuan/Trellis) for relic gem meshes → Roblox MeshPart | Link the Weave account; Weave credits (Pro $45 / 4,000 per month [C]) or free Weave tools in Figma during beta; approval per run | M | Med–High (determinism, style drift, asset licensing/ToS) |
| 8 | **Relic cards with foil**: rarity tiers, animated foil and light sweep, reveal timeline; one system for challenges, perks and achievements | #1 + #2 + Motion | M | Low–Med |
| 9 | **Realm look-dev board**: upload the 7 current realm renders (`upload_assets`) as "Realm v2" with the real `f` factors; grade live with Gradient map (OKLab), Color adjust, Bloom, Light rays, Lens distortion; port the chosen grade into the painters or `ColorCorrection` | `upload_assets`, first-party shaders | S | Low (also fixes the stale 4-plane Map page) |
| 10 | **Trailer and store kit**: parallax camera moves across the World frame as Motion scenes, prestige moments recorded as MP4 (up to 4096 px via MCP), thumbnails and icon from the library, Buzz bulk variants, Weave video b-roll (Veo/Kling) | Motion, `export_video`, Buzz; Weave credits for AI video | M | Low (video models cost credits fast) |
| 11 | **"Roblox Export" generative plugin**: select components → 9-slice PNG masks + gold + glow @2x, a JSON manifest (slice insets, token refs, UIStroke/UIGradient params) in the `art/ui/ui.json` shape | `create_generative_plugin` + PropsKit; file download from the UI iframe | M | Med (big exports need chunking) |
| 12 | **"Relic Forge" generative plugin**: procedural ornament generator (symmetric filigree curves, per-motif stems, gem sockets, stroke-width profiles) that writes editable vectors into the frame components | generative plugin, vector networks | M | Med (taste; keep a human pass) |
| 13 | **Playable tutorial prototype**: one-frame variables/conditionals simulation of the first 10 minutes + FigJam state diagram; test on phones | variables, prototyping, `generate_diagram` | M | Low |
| 14 | **Snapshot parity check**: compare Studio snapshot renders (`MT_Snapshot` mode) against `get_screenshot` of the matching Figma frames; flag drift in colour, spacing and state | MCP reads (mind 200/day), an image diff script | S–M | Low |
| 15 | **Economy/skill-tree sim in Figma Make or code layers**: a React + three.js realm preview wired to the real formulas for balancing sessions and stakeholder demos | Make (credits), code layers (closed beta, waitlist) | M | Med (beta access) |
| 16 | **Figma Sites landing page / wiki / patch notes** from the same library, with scroll parallax of the realm | Sites (open beta), 10 custom domains on Pro [C] | S–M | Low |
| 17 | **3D-tilted relic cards and HUD mockups** with native 3D transforms + Motion, exported to CSS for web marketing | 3D transforms waitlist | S (once available) | Med (beta) |
| 18 | **File hygiene**: remove the 8 unrelated community libraries, bind Foundations/Components fills to variables, fill Screens `2:5` / Overlays `2:6` from the code-first mockups, name versions per release | `use_figma`, `get_libraries` | S | Low |

**Order of attack:** 18 → 5 → 9 (cheap, unblock everything) → 1 + 2 (the visual leap) → 3 + 4 (make it shippable) →
6 → 8 → 11 → 7/10 (credits) → the rest.

---

## Sources

Figma official:
- Config 2026 recap: https://www.figma.com/blog/config-2026-recap/ · What's new from Config 2026: https://help.figma.com/hc/en-us/articles/39582753756695-What-s-new-from-Config-2026 · Forum announcement: https://forum.figma.com/product-updates-3/everything-announced-at-config-2026-55221
- Shaders: https://help.figma.com/hc/en-us/articles/41175721167767-Use-shaders-in-designs · Behind the build (generative plugins and shaders): https://www.figma.com/blog/how-we-built-generative-plugins-and-shaders/ · Agent custom tools and skills: https://www.figma.com/blog/agent-custom-tools-context-skills/
- Motion: https://www.figma.com/blog/introducing-figma-motion/ · Export animations: https://help.figma.com/hc/en-us/articles/41307983648407-Export-animations-from-Figma · Workflow lab (Motion, Weave, shaders): https://help.figma.com/hc/en-us/articles/42847574436119-Workflow-lab-New-tools-more-expression-with-Figma-Motion-Figma-Weave-and-shaders
- Weave: https://www.figma.com/blog/connecting-figma-and-weave/ · https://help.figma.com/hc/en-us/articles/40779260614935-Use-Weave-tools-in-Figma · https://help.figma.com/hc/en-us/articles/35965787376919-Figma-Weave-FAQ · https://weave.figma.com/ · https://www.figma.com/blog/try-these-5-weave-tools-and-share-your-own/
- Code layers: https://www.figma.com/blog/code-on-the-figma-canvas/
- Release notes: https://www.figma.com/release-notes/
- AI credits: https://help.figma.com/hc/en-us/articles/35865276858647-Manage-AI-credits · AI images: https://help.figma.com/hc/en-us/articles/24004542669463-Make-or-edit-an-image-with-AI
- Schema 2025 (modes, extended collections, slots, MCP GA, Code Connect UI): https://help.figma.com/hc/en-us/articles/35794667554839-What-s-new-from-Schema-2025 · Slots: https://www.figma.com/blog/supercharge-your-design-system-with-slots/
- Effects: https://help.figma.com/hc/en-us/articles/360041488473-Apply-effects-to-layers · Blend modes: https://help.figma.com/hc/en-us/articles/360040667874-Apply-blend-modes-to-layers-fills-and-effects · Plus lighter/darker: https://forum.figma.com/t/launched-plus-lighter-and-plus-darker-blending-modes/685
- Draw: https://www.figma.com/blog/introducing-figma-draw/ · https://help.figma.com/hc/en-us/articles/31440438150935-Draw-with-illustration-tools
- Prototyping: https://help.figma.com/hc/en-us/articles/15253194385943-Use-expressions-in-prototypes · https://help.figma.com/hc/en-us/articles/15253220891799-Multiple-actions-and-conditionals · Video in prototypes: https://help.figma.com/hc/en-us/articles/8878274530455-Use-videos-in-prototypes
- Buzz bulk create: https://help.figma.com/hc/en-us/articles/31271824185623-Bulk-create-assets-in-Figma-Buzz · Sites custom domains: https://help.figma.com/hc/en-us/articles/31414274019863-Manage-a-custom-domain-for-your-site · Make kits: https://help.figma.com/hc/en-us/articles/39241689698839-Get-started-with-Make-kits
- Code Connect: https://help.figma.com/hc/en-us/articles/23920389749655-Code-Connect
- Plugin API updates (130 shaders+motion, 131 video export, 133 easing/timing variables, 138 variable fonts, 139 composed colours): https://developers.figma.com/docs/plugins/updates/ · https://developers.figma.com/docs/plugins/updates/2026/06/23/version-1-update-130 · https://developers.figma.com/docs/plugins/updates/2026/07/16/version-1-update-131
- REST: https://developers.figma.com/docs/rest-api/file-endpoints/ · Variables (Enterprise): https://developers.figma.com/docs/rest-api/variables-endpoints · Rate limits: https://developers.figma.com/docs/rest-api/rate-limits · Webhooks: https://developers.figma.com/docs/rest-api/webhooks-events
- MCP server rate limits: https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/
- MCP skills read in this session: `skill://index.json`, `skill://figma/figma-shaders/SKILL.md` (+ `references/authoring.md`), `skill://figma/figma-use-motion/SKILL.md` (+ `motion-patterns.md`, `motion-easing.md`), `skill://figma/figma-generative-plugins/SKILL.md` (+ `references/authoring.md`), `skill://figma/figma-use/SKILL.md`; first-party shader sources via `get_shader` (Nebula, Light rays, Bloom, Chromatic metal)

Third-party / community:
- Weave models, nodes and pricing: https://ai-deck.app/blog/weavy/ · https://note.com/momotaro_ai/n/nadf8304c32a1 · https://uxmagic.ai/blog/figma-weave-review · acquisition: https://www.techbuzz.ai/articles/figma-acquires-weavy-launches-ai-canvas-platform-figma-weave
- Glass GA date and parameters: https://alternativeto.net/news/2025/7/figma-introduces-glass-effect-and-interactive-playground-for-design · https://www.figma.com/community/file/1522715486231239473/glass-effect-playground
- Figma pricing and credits commentary: https://www.banani.co/blog/figma-pricing-and-credits
- Headless WebGPU (SwiftShader): https://developer.chrome.com/docs/web-platform/webgpu/troubleshooting-tips · https://vgpu.sh/docs/guides/agent-browser-webgpu
- Game UI references: https://www.gameuidatabase.com/ · https://www.figma.com/community/file/1369518749890343037/final-fantasy-vii-remake-ui-kit-and-prototypes · https://www.figma.com/community/file/1595482490378786626/game-ui-reward-screen-dark-fantasy · https://www.figma.com/community/file/1615676025515807988/game-ui-dark-fantasy-rpg · https://www.figma.com/community/file/1401135710750637762/games-ui-ux-elements-library-10-000-by-econev · https://www.figma.com/community/file/1469700654678880114/fui-hud-elements · https://www.figma.com/community/file/1494318627282443370/clash-of-clans-ui-components-design · https://vexlo-studio.itch.io/dark-gold-idle-ui-kit
- Case studies: Rush Royale (MY.GAMES): https://medium.com/my-games-company/photoshop-to-figma-how-the-rush-royale-ui-team-changed-its-workflow-25638f710a63 · Riot interaction design: https://www.protopie.io/blog/revolutionizing-game-ux-ui-design-riot-games · https://www.behance.net/gallery/206725853/Game-UI-League-of-Legends-Riot-Games · https://www.behance.net/gallery/160914131/Riot-Games-Platform-UI
- 9-slice plugins: https://www.figma.com/community/plugin/1219930483320755221/9-slice-scaling-new · https://www.figma.com/community/plugin/1648271016651889574/9-slice-forge
- Figma → Roblox: https://figbloxui.dev/ · https://devforum.roblox.com/t/guiforge-roblox-ui-editorfigma-export/4834077 · https://www.figma.com/community/plugin/1625120906985444796/figblox
