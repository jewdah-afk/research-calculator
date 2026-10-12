# Cube Craft

A voxel survival game for Roblox where the world is a giant cube planet. Every face is walkable, gravity points toward the face you stand on, and the land wraps over the edges. Later: the moon and further worlds, reached by rocket (each one its own place in the experience).

## What is here

| Path | What it is |
|---|---|
| `textures/` | 49 original 32×32 block textures (no copied or traced art) |
| `atlas.png`, `atlas.json` | The same textures packed into one atlas: 64 px cells (32 px tile + 16 px wrapped border, so far-away blending never bleeds), 8 × 8 grid |
| `preview/cubecraft_world.html` | Web preview: a flat 100 × 100 test world |
| `preview/cubecraft_planet.html` | Web preview: a small cube planet (96 blocks per face, one biome per face) |
| `preview/cubecraft_generator.html` | Web preview of the real generator: map of the whole 2,048-per-face planet for any seed, tap a spot to build it in 3D |
| `preview/cubecraft_explorer.html` | **The planet explorer.** Globe view of the whole cube, and a ground view that streams 32 × 32 chunks around you on background threads and carries you over the edges. Sizes 2,048 to 65,536 blocks per face. **Core** view: a slice through the whole planet, a depth slider, the conditions at that depth, and a cut-away of the blocks there |
| `generator/planetgen.js` | **The planet generator.** One deterministic algorithm for the whole cube (see below). Written to port line for line to Luau |
| `generator/mesher.js` | Turns a chunk's blocks into triangles, skipping hidden faces, with corner shading. Splits each chunk into 32-block-tall pieces |
| `generator/worker.js` | Background thread: builds and meshes chunks, the distant-land sheet and the globe |
| `screens/` | Screenshots from the previews |
| `tools/` | The Python and JS that made all of the above (see below) |

## Tools

These scripts expect to sit together in one working folder with `world/`, `planet/`, `v3/`, `shots/` and `vendor/` beside them (three.js r128 and its OrbitControls go in `vendor/` for local screenshots).

- `make_textures*.py`: texture generations (v1 to v3, then 32×32). `make_blocks_more.py` builds the final set and the atlas.
- `worldgen.py`, `build_viewer.py`, `viewer_template.html`: the flat test world and its viewer.
- `cubegen.py`, `build_planet.py`, `planet_template.html`: the cube planet prototype and its viewer.
- `shoot*.js`: Playwright screenshot helpers.

## Texture rules learned so far

- Natural blocks (stone, dirt, grass, sand, snow, clay, slate) use a flat base tone plus small, crisp clusters of close tones. No soft blobs: they look cloudy up close and repeat on a visible grid.
- Every ore is drawn on the exact stone (or slate) texture so ore blocks blend into the wall. Deep ores use slate.
- Stone blends into slate over a few layers with dithering.
- The viewer uses nearest filtering up close and mipmaps at a distance, which removes the far-away shimmer.

## The generator (`generator/planetgen.js`)

- Every column is generated from 3D noise sampled at its point on the base cube, so all six faces follow the same rules and the land joins up over the edges (height jump across an edge is about one block, the same as between any two neighbouring columns).
- Terrain: continentalness (ocean to inland), erosion (rugged to flat), ridge noise (mountain ranges), small hills, and rivers carved where a slow noise crosses zero. A light domain warp keeps coastlines from looking like plain noise.
- Biomes come from temperature and humidity (temperature drops with height): ocean, deep ocean, frozen ocean, river, beach, plains, flower meadow, forest, birch forest, taiga, savanna, desert, volcanic, snowy plains, snowy taiga, snowy peaks and stony peaks.
- Underground: dirt or sand layers, sandstone under deserts, stone, then slate below -44 with a dithered blend; cheese caves and winding tunnels; lava lakes deep down; coal, iron, gold and gem veins that get rarer with depth (about 2.6%, 1%, 0.3% and 0.1% of stone), using slate variants in slate.
- `chunk(face, cu, cv, ids)` returns the blocks for one 32 × 32 chunk plus a 1-block ring of its neighbours (so faces between chunks are skipped and shading matches). This is the function the Roblox chunk builder will call. Edge chunks reach past the face edge to hold this face's share of the land above the edge.
- Cube geometry: every block belongs to the face whose axis it is furthest along (`locate`), so the six faces fit together with no gaps or doubled blocks. `walkTo` unfolds a walk over an edge onto the next face.
- Speed: caves are sampled every 4 blocks and blended; ores are short random-walk veins scattered per 16-block cell; continents and climate zones scale with the planet size.
- **The interior** (`conditions`, `deepBlock`, `deepRegion`): layers are cube-shaped shells down to the centre (depth = R − max(|x|,|y|,|z|)). Each depth has a temperature, rock density, pressure and the gear needed, and its own rock, caves and ores:

  | Layer | Depth (16,384 planet) | Rock | Temperature | Density | Pressure | Ores | Gear |
  |---|---|---|---|---|---|---|---|
  | Crust | 0–44 | stone | 15–150 °C | 2.6–2.8 | to 1 GPa | coal, iron | none |
  | Deep crust | 44–410 | slate | 150–600 °C | 2.9–3.2 | to 8 GPa | iron, gold, gem | mining lamp |
  | Mantle | 410–3,686 | mantle rock, magma pockets | 600–3,700 °C | 3.4–5.6 | to 136 GPa | ember, cobalt | heat suit 1 |
  | Outer core | 3,686–6,554 | core iron in seas of molten metal | 3,700–5,000 °C | 9.9–12.2 | to 330 GPa | starmetal | heat suit 2 + pressure rig |
  | Inner core | 6,554–8,192 | heartstone | 5,000–5,600 °C | 12.8–13.1 | to 364 GPa | core crystal | core suit |

  The very centre is a hollow chamber lined with core crystal. Layer depths scale with planet size (the deep crust ends at 5%, the mantle at 45%, the outer core at 80% of the way down). Numbers follow Earth's real profile.
- `node deeptest.js` prints the conditions and block mix at depths from crust to core.
- `node bench2.js` times chunk building and meshing on a 16,384 planet and reports triangles per 32 × 32 × 32 piece.

### Measured (one CPU core, Node)

| Planet | Build one 32 × 32 chunk column | Mesh it | Triangles in the biggest 32 × 32 × 32 piece |
|---|---|---|---|
| 16,384 per face | about 13 ms | about 16 ms | about 13,800 (EditableMesh limit is 20,000) |

## Next

1. Level of detail for chunks beyond the nearest ring (fewer triangles far away).
2. Roblox: 32 × 32 × 32 chunk pieces as EditableMesh on the client, generated from the seed; merged box parts for collision on the server; only player edits are saved.
3. Gravity controller for walking on all faces.
