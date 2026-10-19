# Frontier: EditableImage and EditableMesh at the limit

This builds past the research on `claude/editable-images-meshes-research-sg5aws` (API docs 20/21, perf 22, cookbooks 40/41) and the PixelFX library. Every module is pure Luau and runs headless. Only the clearly marked adapter functions touch Roblox.

## The walls, and what gets around each one
| Wall (from the research) | Module that gets around it |
|---|---|
| Only **one EditableImage refreshes per frame** | `Atlas` packs many surfaces into one page; `Uploader` picks which page to send each frame |
| Client editable **memory budget is small and unpublished** (about 32 MB reported), and late allocations fail or render black | `ImagePool`: a pool keyed by size, our own byte cap, and evict-and-retry when the engine returns nil |
| **4–6 ms of script per frame** (2 ms on low-end mobile) | `IndexedFrame` (1 byte per pixel, dirty 16×16 tiles); sleeping chunks in `FallingSand`; checkerboard rendering in `VoxelSpace` |
| **`Content.fromObject` doesn't replicate** | `Snapshot`: palette index → RLE → zstd hook, chunked for DataStore, for saves and late joiners |
| **`CreateMeshPartAsync` costs about 22 ms**, and collision only updates on rebuild | `HeightfieldMesh` does incremental vertex updates for visuals only; `ContourMesh` rebuilds just one tile per carve |
| **20k triangles / 60k vertices per mesh** | Chunked meshes with LOD, geomorphing and skirts; tiled contour meshes |

## Modules
| File | What it is |
|---|---|
| `Atlas.luau` | Shelf-packed atlas pages, with free-slot reuse, merging of empty shelves, edge-copied gutters, and `imageRect`/`uvRect` per region |
| `Uploader.luau` | Per-frame upload scheduler. Score = visibility weight × staleness. Sends only the dirty rect, and splits oversized rects into bands under a byte cap |
| `ImagePool.luau` | EditableImage pool with a byte budget and evict-then-retry on nil |
| `IndexedFrame.luau` | Palette-indexed framebuffer: colour cycling, dirty tiles, packs exact-size regions for `WritePixelsBuffer` |
| `Snapshot.luau` | Lossless canvas snapshot codec (RLE + optional zstd) plus DataStore chunking |
| `fx/RadianceCascades.luau` | 2D global illumination: soft shadows, penumbrae, colour bleed. Uses an exact distance transform (Felzenszwalb), or JFA |
| `fx/VoxelSpace.luau` | Comanche-style heightmap terrain with procedural maps, fog and sky, and an optional checkerboard mode |
| `fx/SpriteStack.luau` | 3D-looking objects from stacked 2D slices, with procedural voxel models and drop shadows |
| `fx/FallingSand.luau` | Noita-style sandbox (sand, water, stone, wood, fire, smoke) on IndexedFrame, with 64×64 chunks that sleep |
| `mesh/HeightfieldMesh.luau` | Paint-to-geometry terrain. A height image becomes chunked meshes with LOD, geomorphing and skirts; a brush stroke updates only the vertices it touched |
| `mesh/ContourMesh.luau` | Destructible 2D terrain. A mask goes through marching squares, RDP simplification, earcut caps (holes included) and extruded walls; a carve rebuilds one tile |
| `studio/Bench.client.luau` | **Run this in Studio.** Measures what can't be measured headless (below) |
| `studio/AtlasDemo.client.luau` | 48 animated tiles from one EditableImage, all refreshing every frame |

## Headless results (Linux cloud box, ms per call; native = `luau --codegen`)
Full table: `qa/out/RESULTS.md`. Images: `qa/out/*.png`. There are 91 checks, and all pass in both modes.

| Measure | Interp | Native |
|---|---|---|
| Atlas: write 64 × 64² surfaces + pack the upload | 0.78 | 0.37 |
| IndexedFrame: full resolve 256×144 / 8 dirty tiles | 0.91 / 0.06 | 0.13 / 0.013 |
| Snapshot: encode / decode 512² | 1.8 / 0.17 | 0.57 / 0.06 |
| Falling sand step 320×180: active / settled | 2.3 / 0.02 | 0.82 / 0.009 |
| Voxel Space 320×180: full / checkerboard | 8.4 / 4.3 | 1.6 / 0.9 |
| Sprite stack: 20 objects 320×180 | 28.7 | 5.2 |
| Radiance cascades: 128² / 256² spacing 4 / 256² full | 105 / 114 / 428 | 35 / 37 / 148 |
| Heightfield: chunk build (8.7k tris) / 8×8 brush incremental / morph 64 chunks | 4.3 / 0.12 / 7.5 | 2.3 / 0.05 / 1.6 |
| Contour: carve + rebuild one tile | 0.44 | 0.14 |

What the numbers mean:
- **Fit every frame:** Voxel Space, falling sand, sprite stacking, the atlas and uploader, incremental sculpting, and carving.
- **Radiance cascades do not fit every frame at these sizes.** The light-leak fix (bilinear fix plus a line-of-sight weight) costs about 2.5× the plain merge. Use it in one of these ways:
  - recompute when lights or walls change, and reuse the result;
  - spread the cascades across frames (not built yet);
  - run it in parallel Actors.
- **These are desktop timings.** Phones will be slower. The research says client-side native codegen is unconfirmed, and `Bench` answers that.

## Only Roblox can answer these (run `studio/Bench.client.luau`)
Put `Bench` in StarterPlayerScripts, with `NativeProbe` and `PlainProbe` as child ModuleScripts. Press Play and read the on-screen report. It measures:
1. `WritePixelsBuffer` / `ReadPixelsBuffer` cost and MB/s, from 64² up to 1024².
2. **Whether native codegen runs on the client**: the same loop with and without `--!native`.
3. **The real editable budget**: it creates 256² images until nil, then checks the budget comes back after destroying them.
4. EditableMesh build cost, the per-frame cost of moving every vertex, and `CreateMeshPartAsync` cost at about 1k, 5k and 20k triangles.
5. **Whether bones animate an EditableMesh**: does `CreateMeshPartAsync` produce `Bone` instances, and does the strip sway with `Bone.Transform` and with `SetBoneCFrame`? If it does, big meshes can deform with almost no Luau cost.

## Unverified adapter assumptions
- **Mesh adapters:**
  - whether `BatchAdd` creates default per-corner attributes (the adapter reassigns every corner, then calls `RemoveUnused`);
  - whether colour alpha 1 means opaque;
  - UV V origin (we pass `1 - v`);
  - `CreateMeshPartAsync` re-centring (parts are placed at the origin plus `GetCenter()`);
  - `Clear()` only works on non-FixedSize meshes.
- **Image:** whether straight alpha is right for every sink.

## Running the tests
```
cd frontier/qa
LUAU=/path/to/luau python3 run.py            # all tests, interpreter + native, PNGs to out/
LUAU=/path/to/luau python3 run.py test_core.luau
```
The Luau CLI comes from github.com/luau-lang/luau/releases (`luau-ubuntu.zip`).

## Next
1. Run `Bench` once on PC and once on a phone, and record the numbers here.
2. Spread radiance cascades across frames (upper cascades every N frames) and run them on parallel Actors.
3. Build one showcase scene per area in Studio:
   - **image:** falling sand lit by radiance cascades, through the atlas and uploader;
   - **mesh:** paint-to-terrain, with collision rebuilt when a stroke ends.
