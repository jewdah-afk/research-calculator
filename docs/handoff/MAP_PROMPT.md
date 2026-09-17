# Map Prompt — Shark Incremental, hero-grade world

> Send with `HANDOUT.md`. This one is scoped to building the **map**.
> Quality bar: hero-grade. Every surface the player looks at should look
> deliberate. Nothing placeholder ships.

---

## Mission

Build a complete, hero-quality **ocean/reef world** for Shark Incremental in
Roblox — terrain, water, flora, lighting, atmosphere, and the whole
progression of depth zones — and build it by **actually using the
`EditableImage` and `EditableMesh` technique catalogue** in
`docs/research/40-editableimage-technique-cookbook.md` and
`docs/research/41-editablemesh-technique-cookbook.md`, not by placing stock
parts and calling it done.

**Read these before you start**, in this order: the handout, then chapters
**40** (image techniques), **41** (mesh techniques), **20** and **21** (the API
references), **23** (lighting/materials — Roblox has no custom shaders, so this
chapter *is* your art direction toolkit), and **31** (measured benchmarks and
what has actually been built before).

## Use the whole catalogue — this is the point of the task

For each technique below, either **use it** or **write one line saying why it
does not apply here.** Do not silently skip. The catalogue exists so the map
uses the full range of what these APIs can do.

### EditableImage techniques to apply

- **Procedural texture synthesis** — noise, fBm, domain warping for sand,
  sediment, rock, coral bases. Generate the tiling seabed rather than tiling
  one uploaded texture.
- **Height → normal conversion** (Sobel) — generate normal maps in Luau for
  sand ripples, rock, coral surfaces. Watch the OpenGL (+Y) convention.
- **Animated textures** — scrolling and morphing for caustics on the seabed,
  drifting plankton, current streaks. Caustics are the single highest-impact
  animated texture in an underwater scene; do them properly.
- **Flipbook generation** — bubbles, silt puffs, bioluminescent motes.
- **Image filters** — blur (use the integral-image O(1) box blur), threshold,
  posterize, and a **LUT colour grade** per depth zone so each biome reads as a
  distinct palette.
- **Palette quantization + dithering** — if any part of the map takes a
  stylised or retro treatment, do it deliberately with blue-noise or ordered
  dither, not by accident.
- **Painting / projection systems** — `DrawImageProjected` for decals: scorch,
  wear, algae growth on rock, blood in the water during feeding, territory
  marking. This is an engine-side primitive that essentially nobody uses.
- **Masked recolouring** — one coral or fish texture, many colour variants from
  a mask. Enormous asset savings.
- **Weathering and accumulation layers** — silt settling, algae spreading over
  time as a zone develops.
- **Minimap / map rendering** — generate the world map image from the actual
  terrain data, with an exploration reveal mask. Update it incrementally, never
  by full rewrite.
- **Charts and data visualisation** — depth profiles, population graphs,
  progression readouts drawn to an image rather than assembled from frames.
- **Procedural icons** — generate the zone, resource and upgrade icon set
  rather than hand-authoring hundreds of images.
- **Text to image** — Roblox exposes no font rasteriser, so if you need text
  baked into a texture, use a bitmap-font or SDF atlas. Know this before you
  plan a sign.
- **Full-screen overlay effects** — depth vignette, murk, pressure distortion
  hints, bioluminescent glow. You **cannot read the rendered frame**, so these
  are overlays, not post-processing.

### EditableMesh techniques to apply

- **Heightmap → terrain mesh** for the seabed, with chunking.
- **Gerstner wave surfaces** for the ocean top — this is the flagship use of
  live mesh mutation, and visual mutation is free. Animate by mutating.
- **Runtime sculpting** where the world deforms — trenches, feeding craters,
  burrows.
- **Deformation** — kelp and sea fans swaying on current, soft-body wobble on
  anemones, squash-and-stretch on creatures.
- **Procedural flora** — kelp via space colonisation or L-systems, coral via
  branching growth, sea fans, sponges. Generate families with parameters, not
  one-offs.
- **Tube-along-spline** with rotation-minimising frames for kelp stalks, cables,
  eels, current ribbons. Use parallel transport; naive Frenet frames corkscrew.
- **Rocks** — displaced icospheres with noise and erosion.
- **Slicing and destruction** where the fiction calls for it.
- **Voxel / marching cubes** only if caves or arches justify it — note the
  `EditableMesh` ecosystem is empty here, so you would be writing it from
  scratch.
- **Debug draw** — wireframe, normals, chunk bounds. Build this early; it pays
  for itself immediately.
- **Mesh analysis** — recompute normals correctly (area-weighted), find
  degenerate triangles, check winding.

## Hard constraints — verified, and they bite

Design to these from the first sketch, not after:

1. **Editable assets are client-side.** `Content` holding an Object does not
   replicate; a server-side one on a replicating instance renders as a
   cyan/magenta checkerboard. Replicate a **seed and parameters**, generate on
   each client. This also makes the map cheap to send.
2. **One displayed `EditableImage` updates per frame, globally.** N live
   canvases refresh at 60/N fps. **Consolidate into atlases.** This is the
   hardest wall in the whole API, harder than throughput.
3. **1024×1024 max, not resizable.** Per-pixel realtime work tops out around
   100×100 to 256×256; 512² is the outer limit (a bare full repaint at 512² is
   ~9.7 ms, 58% of a frame). Pure blitting reaches 1024². Budget accordingly.
4. **Roughly 8 live editable objects**, likely a ~32 MB shared budget between
   images and meshes. If the budget theory holds, **smaller canvases buy more
   of them** — verify this first, it shapes everything.
5. **Mutators are `Unsafe` for parallel Luau.** Compute in parallel into a
   `buffer`, commit serially in one write. Only legal pattern.
6. **Native codegen is server-only**, so client-side generation runs
   interpreted, on phones. Assume no `@native` help where you need it most.
7. **`CreateMeshPartAsync` costs ~22 ms before a single triangle.** Never bake
   per-frame. Mutate for visuals; rebake only when collision must agree.
8. **`EditableMesh` caps: 60,000 vertices / 20,000 triangles.** Chunk the
   seabed accordingly.
9. **Runtime PBR works by construction, not assignment** — build a new
   appearance with `CreateSurfaceAppearanceAsync` / `CreateDecalAsync`
   (`security: None`). You cannot write into an existing `SurfaceAppearance`'s
   map slots from a script.
10. **Three gates fail three different ways**: the verification toggle applies
    to published places, asset permissions **throw**, memory budget **returns
    `nil`**. There is no pre-check. Every creation site needs `pcall` **and** a
    nil-check **and** a degraded fallback — the engine has been reported to
    revoke access mid-operation.
11. **Beam / Trail / ParticleEmitter / Sky image sinks may silently no-op.**
    Assignment succeeds; support is undocumented. Verify each in-engine before
    building on it.

## The pipeline decision — make it explicitly

For every asset, choose and record: **plugin-time generated and uploaded**, or
**runtime generated**.

Generating in a Studio plugin at edit time, uploading with `CreateAssetAsync`,
and shipping plain asset IDs clears the verification gate, the memory budget,
the replication problem, the one-per-frame throttle and the mobile risk **all
at once**. Most of a map is static — seabed textures, rock, coral, props should
almost all go this route.

Spend the runtime budget only where content genuinely must change live: the
water surface, caustics, the exploration-reveal minimap, damage and growth
decals, per-player variation.

Produce a table of every asset with its route and the reason.

## What the map needs

- **Depth zones** that read as distinct biomes — shallows, reef, kelp forest,
  open water, trench — each with its own palette, lighting, fog density, flora
  set and sound. The player should know their depth from a screenshot.
- **A seabed** with real topography, not a plane: slopes, ridges, arches,
  trenches, scatter that follows slope and depth rules.
- **A water surface** with genuine motion, plus underwater light behaviour:
  depth-based colour absorption, god rays, caustics, particulate drift.
- **Flora and props** generated as parameterised families with variation, not
  copies.
- **Landmarks** — a handful of hero set-pieces a player navigates by and
  remembers. These carry the "hero" bar; spend disproportionate effort here.
- **Lighting and atmosphere per zone.** Read chapter 23. Raise
  `EnvironmentDiffuseScale`/`EnvironmentSpecularScale` — they default to 0, and
  that default is the mechanical reason most Roblox scenes look flat.
- **Performance tiers** that degrade gracefully on a low-end phone.

## Quality bar and verification

Hero-grade means it survives comparison, so verify it that way:

- **Blind side-by-side against a real reference.** Take a screenshot of the map
  and a screenshot of a genuinely good underwater scene, strip the labels, and
  have a critic agent that did not build it pick the better one and say why.
  Do not score against a rubric — rubric scores inflate and stop
  discriminating. Iterate until the map wins, not until a round counter expires.
- **Profile on a real low-end device**, not in Studio. Studio lies.
- **Verify every silent-failure surface**: does that sink actually accept the
  image, or did it no-op? Does the fallback path actually render?
- A screenshot of any part of the map should look intentional. If a region
  looks like placeholder geometry, it is not done.

## How to work

- Read the corpus chapters first. They are the point of the handout, and they
  contain measured numbers you will otherwise guess wrong.
- Answer the editable-budget question early with a scratch test — it changes
  the architecture.
- Build the debug-draw tooling before the content. You will need it.
- Stagger agents in batches of ~5, write files incrementally, commit per batch.
- Pair each builder with a critic that did not write the work.

**First reply: do not start building.** Confirm what you have read, state the
zone breakdown and the asset-route table you propose, name which catalogue
techniques you will use for what, and flag anything in the constraints you
think is wrong. Then start.
