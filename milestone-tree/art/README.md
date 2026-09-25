# Map art: the Realm (parallax layers)

The home screen is a draggable, zoomable 2D map inside a Roblox ScreenGui. Eight depth planes, each with its own
speed and atmosphere, make it feel like a place you stand inside (the Terraria trick). `REALM.md` is the contract;
`realm.json` + `camera.js` are its machine-readable half. Every layer is procedural canvas 2D, drawn in headless
Chromium (Playwright) and seeded, so a run always makes the same image.

| depth | id | f | painter | content |
|---|---|---|---|---|
| 0 | `sky` | 0.05 | `layers/sky.js` | deep space: nebula, stars, the cosmic sun (the key light, upper left). Opaque |
| 1 | `clouds` | 0.12 | `layers/clouds.js` | far nebula clouds, god rays, the crimson cloud wall |
| 2 | `far` | 0.25 | `layers/distant.js` | hazy distant islands, the ringed planet |
| 3 | `mid` | 0.45 | `layers/mid.js` | detailed islands, light-falls, mist bands |
| 4 | `near` | 0.7 | `layers/rocks.js` | big floating rocks passing close behind the world |
| 5 | `world` | 1 | `layers/world.js` | the tree, sockets, the Multiverse rift, the corrupted outcrop, the shrine (3840×2560) |
| 6 | `fg` | 1.3 | `layers/fg.js` | out-of-focus framing foliage (fades out below zoom 0.62) |
| 7 | `particles` | 1.6 | – | bokeh + dust: a sprite field, no texture |

Plus the ambient sprites (twinkles, wisps, light-fall shimmer, fireflies, embers, vines, the rift pulse, glitches) and
three dust fields, all from one sprite atlas (`out/sprites.png`, 1024², regions in `realm.json → atlas`).

Nodes are **not** in the art: every node sits in a socket at its world position (`NODES` in `layers/world.js`, repeated
in `realm.json → nodes`) and is drawn live by the UI, so it can show its state. Node positions and the world size are
a contract with the game UI and Figma.

## Pipeline

```sh
cd art && export NODE_PATH=$(npm root -g)          # needs playwright (Chromium + its ffmpeg)

node camera.js --test                              # the contract: coverage, depth order, tiles, budget, sprites
node render.js all                                 # every painter -> out/<layer>.png + out/<layer>_prev.png, with contract checks
node render.js mid                                 # one layer (ids, painter names like `distant`, or `sprites` all work)
node render.js near --tier LOW                     # also write out/near_LOW.png at exactly size × res.LOW
node roblox/tile.js                                # -> roblox/tiles/<TIER>/<layer>_<col>_<row>.png + roblox/manifest.json (self-checks)
node roblox/upload.js --dry-run                    # -> ../src/shared/Assets.luau with nil ids, lists what would upload
ROBLOX_CREATOR=user:<id> node roblox/upload.js     # the real upload (Open Cloud), then Assets.luau with the ids
node compose.js out/view.png --cx 1500 --cy 1150 --z 0.8        # one frame of the full stack as the client shows it
node preview/record.js                             # -> out/realm_preview.webm (20 s camera path) + out/realm_[1-6]_*.png
node preview/record.js --serve                     # the interactive simulator: open the printed URL
```

**render.js** loads `lib.js`, `window.REALM` (realm.json) and the painter, calls `LAYERS[<id>]()` and saves the canvas.
Painters draw the HIGH texture (`size × res.HIGH`). After each render it checks the texture size, the keep-clear zones
(`mid` hard ≤ 0.3 alpha; `near` / `fg` hard = 0, soft < 0.35 / 0.25) and tile coverage, and prints `ok` / `WARN`.

**roblox/tile.js** turns each render into Roblox images (REALM.md section 3):

* HIGH = the render (a full-size or other-scale render with the right aspect is resampled, premultiplied area filter);
  LOW = HIGH ÷ 2 (premultiplied 2×2 box, what a mip level does). Opaque layers are forced to alpha 255.
* Tiles follow `camera.js tileRects`: the content rect plus a 2 px gutter holding the neighbours' pixels (the edge
  repeated at the layer border). Every image is ≤ 1024².
* Alpha bleed: every alpha-0 pixel gets the colour of the visible pixels nearest to it (a push-pull pyramid in
  premultiplied space, so it is smooth and never picks up the noise of near-invisible pixels); alpha stays 0. Roblox
  filters in straight alpha, so without this every scaled edge would get a dark fringe.
* Tiles whose content has max alpha < 2/255 are dropped. PNG encoding is deterministic, so the same art gives the same
  sha256 and `upload.js` skips it.
* `--check` (also run after every tiling) re-reads every tile and verifies size, gutter pixels, content against the
  source, no transparent black next to content, full coverage and the texture budget.

**roblox/upload.js** uploads with `POST https://apis.roblox.com/assets/v1/assets` (multipart `request` + `fileContent`)
and polls `GET /assets/v1/operations/<id>` for the asset id. The API key header is injected by the network proxy for
apis.roblox.com, so the script needs none (it sends `ROBLOX_API_KEY` as `x-api-key` only if that variable is set).
The creator is `ROBLOX_CREATOR` (`user:<id>` or `group:<id>`). One rate limiter (`--rpm`, default 50/min) covers
uploads and polls; 429 / 5xx back off exponentially and honour `Retry-After`. `roblox/uploaded.json` records
sha256 → asset id after every finished image, so re-runs upload only what changed and an interrupted run resumes.
It always regenerates `src/shared/Assets.luau` (a ModuleScript: `tiers.HIGH/LOW.layers[id] = { f, w, h, tiles = { {x, y,
w, h, rw, rh, id} } }`, `sprites = { atlas ids, regions }`; `id = nil` means not uploaded yet) and
`out/realm_assets.json` (the REALM.md asset map).

**preview/realm.html** is a WebGL simulator of the client, built on the same `camera.js` maths: layer containers
(dolly-law zoom per depth), the uploaded tiles, sprites (`spriteState`), particle fields (`fieldPlace`), biome tint,
wash and sprite colours, the fg fade, the vignette, and stand-in node plates. Camera feel follows `camera.feel`: drag
threshold, smoothed fling, inertia, rubber band with spring-back, wheel zoom eased in log space about the cursor,
double-click zoom. Keys: H hud, N nodes, M ReducedMotion, T tier, S tiles/full renders, B wash, G tile grid, O seam
mode, K keep-clear zones, 1-8 hide a depth, P pause, R reset. Without `out/sprites.png` it paints a stand-in atlas
from `atlas.looks`.

**preview/record.js** flies a scripted path (tree base → up the trunk → the whole realm → east to the rift → in by the
corrupted outcrop). The default mode renders every frame deterministically (t = i / 30) and encodes it with the ffmpeg
Playwright ships; `--mode video` is a plain Playwright `recordVideo` capture in real time (smooth only with a GPU).

## Notes for the client

* **Tile seams.** Draw tiles with their edges on whole device pixels, shared by neighbours (the simulator's default,
  `seams=snap`). The 1-point overlap in REALM.md 9.3 blends translucent pixels twice, which shows as a faint line at
  every tile seam of a soft layer (clouds, mist, glows); `seams=overlap` in the simulator shows it.
* **Vignette.** Sample the `vignette` region 3 px inside its rect: the atlas keeps a clear 2 px border around every
  region, which stretched over the whole screen becomes a light frame.

## What is committed

Painters, pipeline scripts, `realm.json`, `roblox/manifest.json`, `roblox/uploaded.json` (once something is
uploaded), `src/shared/Assets.luau` and the previews. Rendered PNGs and the tiles are not committed: `render.js` and
`tile.js` rebuild them byte for byte (compare the tile sha256 in the manifest).
