# Roblox Mastery Corpus — Editable Images & Meshes, and Everything Around Them

**Goal:** total command of building things inside Roblox `EditableImage` and
`EditableMesh` — and of Roblox game development generally — at the highest
level achievable. Not one genre. Any game, built properly.

Each chapter is a standalone deep reference written by a dedicated research
agent working against live primary sources. Roblox's editable-asset APIs
change fast, so every chapter is instructed to verify against current
documentation and to flag explicitly what it could not confirm.

---

## Part I — The editable-asset core

The heart of the corpus: total command of runtime-generated geometry and imagery.

| # | Chapter | Covers |
|---|---------|--------|
| 20 | EditableImage API reference | Verified API surface, buffer layout, permission model, draw ops, every `Content` sink |
| 21 | EditableMesh API reference | Id-based vertex/face/UV model, limits, `CreateMeshPartAsync`, queries |
| 40 | EditableImage technique cookbook | Painting, canvases, minimaps, filters, software rendering, texture synthesis |
| 41 | EditableMesh technique cookbook | Deformation, destruction, voxels, slicing, procedural objects, debug draw |

## Part II — Engine mastery

| # | Chapter | Covers |
|---|---------|--------|
| 22 | Luau performance engineering | `buffer`, native codegen, parallel Luau, task scheduler, profiling |
| 23 | Rendering, lighting, materials | Art direction with no shader access; SurfaceAppearance; post effects |
| 43 | 3D math toolkit | CFrame, quaternions, splines, geometry queries, springs, easing |
| 44 | Physics, characters, hit detection | Constraints, network ownership, custom controllers, lag compensation |
| 45 | VFX and game feel | Particles, beams, trails, screen shake, hit stop, sound, juice |
| 49 | AI and NPC behavior | Pathfinding, behavior trees, utility AI, steering, crowds at scale |
| 24 | World representation & budgets | Terrain vs Parts vs mesh chunks; real device budgets |
| 32 | Units, animation & crowds | Skinned meshes, animation cost, rendering many agents |

## Part III — Pipeline and craft

| # | Chapter | Covers |
|---|---------|--------|
| 26 | Asset pipeline & tooling | Open Cloud, moderation, Rojo/Wally/Lune, asset manifests |
| 27 | Blender → Roblox | Import limits, scale/axis conventions, PBR, skinning, LOD |
| 30 | Studio plugin development | Building custom authoring tools; the undo contract |
| 25 | UI construction | Flex layout, 9-slice, ViewportFrame, atlases, dense interfaces |
| 48 | Procedural generation toolkit | Dungeons, WFC, erosion, L-systems, loot, names, solvability |

## Part IV — Engineering a real game

| # | Chapter | Covers |
|---|---------|--------|
| 46 | Code architecture & frameworks | Knit/Matter/Flamework/ECS compared; project structure; testing |
| 28 | Networking & data architecture | Bit-packing, DataStore limits, replication, filtered state |
| 47 | Security & anti-exploit | Threat model, server authority, validation, information leakage |
| 50 | Optimization & shipping | MicroProfiler, budgets, memory leaks, streaming, ship checklist |
| 29 | Camera & input | Custom camera rigs, picking math, cross-platform input |

## Part V — Platform and business

| # | Chapter | Covers |
|---|---------|--------|
| 42 | Genre atlas | What every genre needs technically; where the white space is |
| 34 | Platform reality | Device mix, audience, performance ceilings, honest scoping |
| 51 | Live ops, analytics & growth | Discovery algorithm, funnel metrics, monetization, the honest picture |

## Part VI — Platform-agnostic foundations

Technique chapters commissioned before the Roblox target was known. The
algorithms transfer; the API-specific sections (WebGL, three.js, browser
canvas) are background, not direction.

| # | Chapter | Covers |
|---|---------|--------|
| 01 | Raster formats & layered editing | Blend modes, color space, dithering, quantization, pixel algorithms |
| 02 | SVG & vector authoring | Bézier math, path ops, rasterization |
| 03 | Procedural texture generation | Noise, fBm, domain warping, tiling, PBR map synthesis |
| 04 | Mesh data structures | Half-edge, attributes, normals, subdivision |
| 05 | 3D file formats | glTF, FBX, USD, OBJ — what preserves editability |
| 06 | Realtime rendering techniques | Terrain splatting, water, LOD (technique reference) |
| 07 | Hex grids & tilemaps | Complete hex math, pathfinding, chunking, autotiling |
| 08 | Civ V art pipeline | A case study in shipping a large art pipeline |
| 09 | Procedural world generation | Tectonics, erosion, rivers, biomes |
| 10 | Sprite & atlas pipelines | Bin packing, autotiling, 9-slice, SDF/MSDF |
| 11 | Mesh generation algorithms | Triangulation, extrusion, marching cubes, simplification |

---

---

## Status (2026-09-17)

**Written — 18,473 lines across 9 chapters:**

| # | Chapter | Lines |
|---|---------|-------|
| 40 | EditableImage technique cookbook | 2,309 |
| 41 | EditableMesh technique cookbook | 2,714 |
| 42 | Roblox genre atlas | 937 |
| 43 | 3D math toolkit | 3,021 |
| 46 | Code architecture & frameworks | 1,458 |
| 47 | Security & anti-exploit | 1,104 |
| 48 | Procedural generation toolkit | 2,480 |
| 49 | AI & NPC behavior | 2,850 |
| 51 | Live ops, analytics & growth | 1,505 |

**Pending — 11 chapters.** Their agents were terminated mid-flight by an
account rate limit, not by any problem with the research:

20 EditableImage API reference · 21 EditableMesh API reference ·
22 Luau performance engineering · 23 Rendering, lighting & materials ·
24 World building & budgets · 25 UI construction · 26 Asset pipeline & tooling ·
31 Prior art & benchmarks · 44 Physics, characters & hit detection ·
45 VFX & game feel · 50 Optimization & shipping

Chapters 20 and 21 are the two most load-bearing and should be written first.

## Research method notes

`create.roblox.com`, `devforum.roblox.com` and `luau.org` are unreachable from
this environment's network policy. All API claims were instead verified against
the authoritative upstream sources, which are reachable:

- **`github.com/Roblox/creator-docs`** — the generated reference YAML that the
  Creator Hub pages are built from. Higher fidelity than the rendered pages:
  full parameter lists, defaults, verbatim behavioral prose, and thread-safety
  metadata.
- **`github.com/luau-lang/luau`** — the `/docs` and `/rfcs` trees, plus VM
  headers for ground truth on value representations.

DevForum figures could only be reached through search-result summaries and are
flagged second-hand throughout. Treat every community performance number as
unmeasured until reproduced.

## The gate you must clear before any of this ships

`EditableImage` and `EditableMesh` **fail by default in published experiences.**
The creator must be 13+ age verified **and** ID verified, then enable
**Mesh / Image APIs** on the Creator Dashboard. Loading an *existing* asset
additionally requires that the asset be owned by or shared with the game owner,
the Studio user, or — for client-side use — the logged-in player, or owned by a
group where one of them holds an edit-permission role.
