# Civ-V-Grade Content in Roblox — Research Corpus

Goal: author content inside Roblox `EditableImage` and `EditableMesh` at a
Sid Meier's Civilization V quality bar — a large, dynamic, editable hex world
with a dense illustrated UI.

Each chapter is a standalone deep reference written by a dedicated research
agent against live primary sources. Roblox's editable-asset APIs change fast,
so every chapter flags what it could not verify.

## Part I — Roblox platform (the load-bearing chapters)

| # | Chapter | Covers |
|---|---------|--------|
| 20 | [EditableImage API](20-roblox-editableimage-api.md) | Full verified API, buffer layout, permissions, draw ops, Content sinks |
| 21 | [EditableMesh API](21-roblox-editablemesh-api.md) | Id-based data model, limits, CreateMeshPartAsync, queries, recipes |
| 22 | [Luau performance](22-luau-performance-engineering.md) | buffers, native codegen, parallel Luau, task scheduler, profiling |
| 23 | [Rendering, lighting, materials](23-roblox-rendering-lighting-materials.md) | No-shader art direction, SurfaceAppearance, fog of war options |
| 24 | [World representation & budgets](24-roblox-world-representation-and-budgets.md) | Terrain vs Parts vs EditableMesh chunks; real device budgets |
| 25 | [UI for strategy games](25-roblox-ui-for-strategy-games.md) | Flex layout, 9-slice, ViewportFrame, tech tree, minimap, atlases |
| 26 | [Asset pipeline & tooling](26-roblox-asset-pipeline-and-tooling.md) | Open Cloud, moderation, Rojo/Wally/Lune, asset manifests |
| 27 | [Blender → Roblox](27-blender-to-roblox-mesh-pipeline.md) | Import limits, scale/axis conventions, PBR, skinning, LOD |
| 28 | [Networking & data architecture](28-roblox-networking-and-data-architecture.md) | Tile bit-packing, DataStore limits, turn loop, fog-of-war replication |
| 29 | [Camera & input](29-roblox-camera-and-input-for-strategy.md) | RTS camera rig, zoom-to-cursor, pixel→hex picking, mobile gestures |
| 30 | [Studio plugin development](30-roblox-studio-plugin-development.md) | Custom hex map editor, texture lab, undo contract |
| 31 | [Prior art & benchmarks](31-roblox-prior-art-and-benchmarks.md) | What the community has already built; real measured numbers |
| 32 | [Units, animation & crowds](32-roblox-units-animation-and-crowds.md) | Skinned meshes, the 200-unit problem, strategic-view billboards |
| 33 | [Civ V game systems](33-civ5-game-systems-and-data-model.md) | Real formulas, the XML/SQL data-driven pattern, a minimal ruleset |
| 34 | [Platform reality & scoping](34-roblox-platform-reality-and-scoping.md) | Device mix, audience, discovery, an honest feasibility call |

## Part II — Platform-agnostic foundations

Technique chapters that apply regardless of engine. Written before the Roblox
target was known, so their API-specific sections (WebGL, three.js, browser
canvas) are background rather than direction — the algorithms transfer, the
APIs do not.

| # | Chapter | Covers |
|---|---------|--------|
| 01 | [Raster formats & layered editing](01-raster-image-formats-and-layered-editing.md) | Blend modes, color space, dithering, quantization, pixel algorithms |
| 02 | [SVG & vector authoring](02-svg-and-vector-authoring.md) | Bézier math, path ops, rasterization, procedural vector art |
| 03 | [Procedural texture generation](03-procedural-texture-generation.md) | Noise, fBm, domain warping, tiling, PBR map synthesis |
| 04 | [Mesh data structures](04-mesh-data-structures-and-editable-topology.md) | Half-edge, attributes, normals, subdivision, non-destructive stacks |
| 05 | [3D file formats](05-3d-file-formats-and-interchange.md) | glTF, FBX, USD, OBJ — what preserves editability |
| 06 | [Realtime rendering techniques](06-browser-realtime-rendering.md) | Terrain splatting, water, fog of war, LOD (technique reference) |
| 07 | [Hex grids & tilemaps](07-hex-grids-and-tilemaps.md) | Complete hex math, pathfinding, chunking, autotiling |
| 08 | [Civ V art pipeline](08-civ5-art-pipeline-and-modding.md) | How Civ V was actually built: GR2, DDS, ArtDefines, atlases |
| 09 | [Procedural world generation](09-procedural-world-generation.md) | Tectonics, erosion, rivers, biomes, Civ V's map scripts |
| 10 | [Sprite & atlas pipelines](10-sprite-tileset-and-atlas-pipelines.md) | Bin packing, autotiling, 9-slice, SDF/MSDF, icon sets |
| 11 | [Mesh generation algorithms](11-mesh-generation-algorithms.md) | Triangulation, extrusion, marching cubes, simplification, trees/buildings |

## Status

Research in progress. Chapters land as their agents complete.
