# Cube Craft

A voxel survival game for Roblox where the world is a giant cube planet. Every face is walkable, gravity points toward the face you stand on, and the land wraps over the edges. Later: the moon and further worlds, reached by rocket (each one its own place in the experience).

## What is here

| Path | What it is |
|---|---|
| `textures/` | 42 original 32×32 block textures (no copied or traced art) |
| `atlas.png`, `atlas.json` | The same textures packed into one atlas: 64 px cells (32 px tile + 16 px wrapped border, so far-away blending never bleeds), 8 × 8 grid |
| `preview/cubecraft_world.html` | Web preview: a flat 100 × 100 test world |
| `preview/cubecraft_planet.html` | Web preview: a small cube planet (96 blocks per face, one biome per face) |
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

## Next

1. A single planet generator for 2,048-block faces: continents, oceans, erosion, mountain ridges, rivers, and biomes from temperature and humidity, the same everywhere on the cube and seamless over edges.
2. Roblox: 32 × 32 chunks as EditableMesh on the client, generated from the seed; merged box parts for collision on the server; only player edits are saved.
3. Gravity controller for walking on all faces.
