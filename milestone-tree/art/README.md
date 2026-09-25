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
node render.js sprites                             # the atlas: runs `node layers/sprites.js` -> out/sprites.png + sprites.json
node render.js near --tier LOW                     # also write out/near_LOW.png at exactly size × res.LOW
node roblox/tile.js                                # -> roblox/tiles/<TIER>/<layer>_<col>_<row>.png + roblox/manifest.json (self-checks)
node roblox/upload.js --dry-run                    # -> ../src/shared/Assets.luau with nil ids, lists what would upload
ROBLOX_CREATOR=user:<id> node roblox/upload.js     # the real upload (Open Cloud), then Assets.luau with the ids
node compose.js out/view.png --cx 1500 --cy 1150 --z 0.8        # one frame of the full stack as the client shows it (.png/.jpg/.webp)
node compose.js out/realm_overview.webp --cx 1920 --cy 1320 --z 0.5   # the committed whole-realm still
node compose.js out/edge.png --cx 1500 --cy 1300 --z 1.25 --straight   # straight-alpha filtering, as Roblox draws edges
node preview/record.js                             # -> out/realm_preview.webm (27 s, 540p) + out/realm_[1-6]_*.jpg + rest-motion report
node preview/record.js --rest-only                 # just the rest-motion report (ambient motion with the camera still)
node preview/record.js --serve                     # the interactive simulator: open the printed URL
```

**render.js** loads `lib.js`, `window.REALM` (realm.json) and the painter, calls `LAYERS[<id>]()` and saves the canvas.
Painters draw the HIGH texture (`size × res.HIGH`). After each render it checks the texture size, the keep-clear zones
(`mid` hard ≤ 0.3 alpha; `near` / `fg` hard = 0, soft < 0.35 / 0.25) and tile coverage, and prints `ok` / `WARN`.
A painter with its own node entry point (`layers/sprites.js`) is run as `node layers/<painter>.js` instead, so
`render.js sprites` and `render.js all` write exactly what that command writes: `out/sprites.png` from its
deterministic PNG encoder, `out/sprites.json` (whose `sha256` must match the PNG; render.js and tile.js check it) and
the labelled `out/sprites_prev.png`.

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
uploads and polls. `roblox/uploaded.json` records sha256 → asset id after every finished image, so re-runs upload only
what changed and an interrupted run resumes; identical PNGs upload once.

* Polls are idempotent: network errors, 429 and 5xx back off exponentially and honour `Retry-After`.
* The create is not, so it retries only where Roblox cannot have processed it: 429, 503 with `Retry-After`, or a
  network error before the connection existed (refused, DNS, connect timeout). Anything else after the body went out
  (another 5xx, a reset, a lost or unreadable response, an operation that never finishes) is **unconfirmed**: it is
  logged, recorded under `unconfirmed` in uploaded.json (with the operation id when there is one), the tile keeps
  `id = nil` and the run exits 1. The next run polls a recorded operation instead of uploading again. One without an
  operation id waits for you: find it in the Creator Dashboard by its displayName (`Realm HIGH sky_0_0`; the
  description carries the sha256 prefix) and run `--adopt HIGH/sky_0_0=<assetId>`, or `--retry-unconfirmed`.
  A plain failure (4xx, or an operation that reports an error) created nothing and is retried by the next run.
It always regenerates `src/shared/Assets.luau` (a ModuleScript: `tiers.HIGH/LOW.layers[id] = { f, w, h, tiles = { {x, y,
w, h, rw, rh, id} } }`, `sprites = { atlas ids, regions }`; `id = nil` means not uploaded yet) and
`out/realm_assets.json` (the REALM.md asset map).

**preview/realm.html** is a WebGL simulator of the client, built on the same `camera.js` maths: layer containers
(dolly-law zoom per depth), the uploaded tiles, sprites (`spriteState`), particle fields (`fieldPlace`), the fg fade,
the vignette, stand-in node plates, and the biome colours of REALM.md 5 through the camera.js helpers: tile tint and
wash from w.rift only (`biomeTint`, `biomeWash`), the two corrupt blooms at their zOrder slots (`bloomState`), and
sprite and particle colours from the outcrop light under each one (`biomeSpriteColor`, `biomeFieldColor`), so the
rift stays crimson and only the outcrop's surroundings turn green. The biome weights use the real zoom and viewport
(`biome(C, B, z, V)`). Camera feel follows `camera.feel`: drag threshold, smoothed fling, inertia, rubber band with
spring-back, wheel zoom eased in log space about the cursor, double-click zoom. Keys: H hud, N nodes, M ReducedMotion,
T tier, S tiles/full renders, B wash, G tile grid, O seam mode, K keep-clear zones, A alpha mode, 1-8 hide a depth,
P pause, R reset. Without `out/sprites.png` it paints a stand-in atlas from `atlas.looks`.

By default textures are premultiplied on upload and mipmapped: the ideal image. `straight=1` (key A,
`compose.js --straight`) draws the way a Roblox ImageLabel does: straight alpha, bilinear without mipmaps, blended with
SRC_ALPHA / ONE_MINUS_SRC_ALPHA. Bright pixels at low alpha next to an opaque dark shape then show as a one-texel light
rim, which the premultiplied preview hides (REALM.md 9.8, check 6).

**preview/record.js** flies a scripted 27 s path: a 3 s rest at the tree base → up the trunk → the whole realm → east
to the rift and a 3 s rest there → in by the corrupted outcrop and a last rest. The rests are what the player sees most:
the camera is still and only the ambient sprites move, so the video shows them unmasked, and after recording it prints
a rest-motion report per hold (the share of pixels that change by more than 8/255 over 1 s). The default mode renders
every frame deterministically (t = i / 30) at 1920×1080 and encodes it with the ffmpeg Playwright ships (VP8), scaled
to 960×540 at about 1.8 Mbps, so the committed video stays near 5 MB (`--video-size same --bitrate 8M` for a local
full-size copy). The six stills are 1920×1080 JPEGs (`--stills png` for lossless). `--mode video` is a plain Playwright
`recordVideo` capture in real time (smooth only with a GPU). The encoder and the stills write to a private temp
directory; only when ffmpeg exits 0 do the video and all six stills replace the tracked files, together (copy beside,
then an atomic rename). A failed or interrupted run leaves the previous ones untouched, and a commit taken during the
~10 minute run never sees a half-written webm. Commit `out/realm_preview.webm` and `out/realm_[1-6]_*.jpg` together.

## Notes for the client

* **Tile seams.** Place tiles by the snapped recipe of REALM.md 9.3 (the same text is in `roblox/manifest.json` →
  `about` and in `Assets.luau`): the column and row edges (`x`, `x + w`; `y`, `y + h` in layer-local px) are rounded
  to whole device pixels and each edge is shared by the two tiles that meet there. No overlap: a tile drawn 1 point
  larger blends a soft layer's edge strip twice, a faint line on clouds, mist and glows (`seams=overlap` in the
  simulator shows the retired recipe).
* **Vignette.** Sample the `vignette` region through its `sampleRect`, never its plain rect. It comes from
  `out/sprites.json` (`sampleRect`, `lowSampleRect`) and is copied into `roblox/manifest.json` (`atlas.sampleRects`,
  `atlas.lowSampleRects`) and `Assets.luau` (`sprites.sample`, HIGH px; halve it for LOW). Today it is 6 px inside the
  rect on HIGH and 3 px on LOW: the region keeps a clear 4 px gutter inside its rect (2 px on LOW) and its black runs
  2 px past the sampleRect (1 px on LOW), so, stretched over the screen, bilinear sampling at the screen edge reads
  vignette and never the gutter. Every other region fades to alpha 0 within its own 2 px border.

## What is committed

Painters, pipeline scripts, `realm.json`, `roblox/manifest.json`, `roblox/uploaded.json` (once something is
uploaded), `src/shared/Assets.luau`, `out/sprites.json`, `out/realm_assets.json` and the previews:

| preview | made by | size |
|---|---|---|
| `out/realm_preview.webm` | `node preview/record.js` (27 s, 960×540 VP8) | ~5 MB |
| `out/realm_[1-6]_*.jpg` | the same run (1920×1080 stills on the path) | ~0.3 MB each |
| `out/realm_overview.webp` | `node compose.js out/realm_overview.webp --cx 1920 --cy 1320 --z 0.5` | ~0.3 MB |
| `out/panroom_{1920,844}_*.jpg` | `compose.js --shots` at the pan envelope (REALM.md 2.5): the start view, the four corners at the start zoom, west / east / top / bottom at zMin; 1920×1080 HIGH and 844×390 LOW at dpr 2, quality 80 | ~0.1-0.2 MB each |
| `out/zoomout_{1920,2560,1366,844}.jpg` | `compose.js` at zMin centred on the realm (1920, 1280): the whole-realm view of REALM.md 2.4 on 1920×1080, 2560×1440, 1366×768 and 844×390, HIGH, quality 88 | ~0.06-0.5 MB each |

No PNG is committed (`.gitignore`): rendered layers and tiles are rebuilt byte for byte by `render.js` and `tile.js`
(compare the tile sha256 in the manifest), and the previews are compressed on purpose so a re-record adds a few MB of
history, not 40.
