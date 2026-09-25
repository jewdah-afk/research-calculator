# The Realm: parallax contract

The home screen is a 2D map inside a Roblox ScreenGui. This contract turns it into a place you stand inside, the way
Terraria's backgrounds do. It uses eight depth planes, each with its own speed and atmosphere. Motion never stops
(clouds, stars, fireflies, light-falls, the rift). The mood shifts from the violet and gold Milestone Tree to the
crimson Multiverse rift as you pan.

Three files make up the contract. They are the source of truth for the layer painters, the tiler/uploader, the preview
renderer and the Roblox `Map` module:

| file | what it is |
|---|---|
| `camera.js` | The camera maths as pure functions. It is UMD: `require('./camera.js')` in node, or `<script>` in a page, which exposes `window.RealmCamera`. It also builds and checks the manifest. |
| `realm.json` | The manifest: layers, sizes, tiles, memory, atmosphere, biomes, sprites, particle fields, atlas, z-order. Hand-written inputs plus fields derived by the build. |
| `REALM.md` | This document. |

```sh
cd art
node camera.js --build    # recompute every derived field of realm.json (sizes, tiles, memory, keep-clear, instances, particles)
node camera.js --test     # ~1.98M checks: coverage brute force, identities, depth order, tiles, budget, sprites, fields, biome (exit 1 on failure)
node camera.js --report   # the table in section 1
```

Fixed by contract: the world layer stays **3840×2560 at f = 1**. `NODES` in `layers/world.js` never move. Nodes are
live UI and are never painted. `realm.json` repeats the node coordinates only as a reference for keep-clear zones.
The camera may look past the world's edges by the **pan margin** (960 × 720 world px, section 2.5), so the world art
ends inside its rect (nothing is cut by the border) and the layers behind it cover the margin.

---

## 1. The stack

| depth | id | f | content | size (local px) | res HIGH / LOW | tile (tex px) | HIGH tiles, MB | LOW tiles, MB |
|---|---|---|---|---|---|---|---|---|
| 0 | `sky` | 0.05 | deep space: nebula, stars, cosmic sun (opaque) | 2784×1616 | 0.625 / **0.25** | 870×1010 | 2×1, 6.8 | 1×1, 1.1 |
| 1 | `clouds` | 0.12 | far nebula wisps, god rays | 3040×1840 | 0.375 / **0.125** | 570×690 | 2×1, 3.0 | 1×1, 0.3 |
| 2 | `far` | 0.25 | distant hazy islands, ringed planet (painter `layers/distant.js`) | 3552×2272 | 0.5 / **0.1875** | 888×568 | 2×2, 7.8 | 1×1, 1.1 |
| 3 | `mid` | 0.45 | detailed islands, light-falls, mist bands | 4352×2928 | 0.75 / 0.375 | 816×732 | 4×3, 27.6 | 2×2, 6.9 |
| 4 | `near` | 0.7 | big floating rocks close behind the world, sparse (painter `layers/rocks.js`) | 5440×3920 | 0.45 / 0.225 | 612×882 | 4×2, 16.7 | 2×1, 4.2 |
| 5 | `world` | 1.0 | `world.js`: tree, sockets, rift, outcrop, shrine | **3840×2560** | 1 / 0.5 | 960×640 | 4×4, 37.9 | 2×2, 9.5 |
| 6 | `fg` | 1.3 | blurred framing vines, ferns, leaves (sparse) | 7600×5380 | 0.2 / 0.1 | 760×538 | 2×2, 6.3 | 1×1, 1.6 |
| 7 | `particles` | 1.6 | bokeh + dust, a sprite **field** (no baked texture) | infinite (cell 5530×3210) | atlas | – | – | – |

The layers behind and in front of the world are larger than it because the camera may look past the world's edges
by the pan margin (section 2.5) and zoom out until the whole world is on screen (section 2.4); section 2.7 derives the
sizes. The LOW res in bold is below HIGH ÷ 2 (the layer's `lowRes`, section 3). Each painter keeps its composition in the frame the
layer had before the margin (for example 3360×2160 for `mid`), centred in the new size, and carries it out into the
margin strips (section 8).

There are two more particle fields: `motesFar` at f = 0.7 (cell 5070×3420), drawn with the near rocks, and
`motesNear` at f = 1.3 (cell 5430×3060), drawn with the foreground. With them, drifting dust exists at three depths.
Every field cell is larger than any screen, so no particle ever shows twice (section 6.3).

**Totals**, counted as RGBA8 bytes of every uploaded image with gutters included:

| tier | tiles | + atlas | texture MB | if the engine keeps mips (×4/3) | budget | GUI objects (tiles + sprites + field pools + blooms) |
|---|---|---|---|---|---|---|
| HIGH | 48 | 1024² | **110.1** | 146.8 | 150 | 392 |
| LOW | 14 | 512² | **25.7** | 34.2 | 35 | 163 |

The tiler skips a tile that is fully transparent, but with the current art none is (0 of 48 HIGH, 0 of 14 LOW), so
these totals are exactly what uploads. Both tiers are near their budgets (98% each): see section 3, Memory.

"Local px" is the layer's own pixel unit: 1 local px is 1 map point on screen when the layer's zoom is 1. For the
world layer, local px are world px. A layer's texture is `size × res`, and the client scales it back up.

**Z-order** inside the MapGui, back to front (`realm.json → zOrder`):
sky tiles, sky sprites, **corrupt bloom** (clouds), clouds tiles, clouds sprites, far tiles, far sprites, mid tiles,
mid sprites, **biome wash**, **corrupt bloom** (near), near tiles, near sprites, field `motesFar`, world tiles, world
sprites, fg tiles, fg sprites, field `motesNear`, **node links, nodes**, field `particles`, **vignette**.
The foreground sits *under* the nodes, so node plates always read cleanly. The particle field sits over them but is
very faint (alpha ≤ 0.24 for bokeh) and never takes input.

---

## 2. Camera model

### 2.1 Notation

* World W = 3840×2560, world centre Wc = (1920, 1280).
* Viewport V = (V.w, V.h) in **map points**. The centre is Vc = V/2 (section 2.6 covers device pixels → map points).
* Camera: centre C in world px (the world point at the screen centre), and zoom z (screen points per world px).
* Layer L: factor f, local size (w, h), anchor A = (w/2, h/2). A is the local point that lies behind Wc when the
  camera is at Wc.

### 2.2 Placing a layer

```
layer zoom        s_L = z / (f + (1 − f) z)                    (the dolly law, see 2.3)
centre point      P_L = A + f (C − Wc)                          the local point under the screen centre
local → screen    q   = Vc + s_L (p − P_L)
container         origin O_L = Vc − s_L P_L,   on-screen size = s_L (w, h)          (camera.js layerOffset)
visible rect      [P_L − V/(2 s_L),  P_L + V/(2 s_L)]                                (camera.js visibleRect)
```

The anchor moves f times the camera's displacement from the world centre, measured in the layer's own pixels. For the
world (f = 1, A = Wc) this reduces to `P = C`, `q = Vc + z (p − C)`: a plain pan and zoom.
`screen → world` is `p = C + (q − Vc)/z`.

**Zoom about a point** (wheel at the cursor, pinch at the midpoint): the world point under S stays put.

```
Q  = C + (S − Vc)/z          C' = Q − (S − Vc)/z'                                    (camera.js zoomAt)
```

The other layers then shift by a small, depth-dependent amount. That shift is the parallax you feel while zooming.

### 2.3 Why `z / (f + (1 − f) z)` and not `z^f`

The draft spec asked for `s_L = z^f`. It matches the dolly law at z = 1 in value (1) and in slope (ds/dz = f), and
near layers zoom more than far ones in both. But `z^f` breaks depth order when zoomed out. A layer's screen speed
relative to the world is `f·s_L / z`:

* with `z^f` that is `f·z^(f−1)`. It passes 1 below `z = f^(1/(1−f))`: 0.305 for `near` and 0.234 for `mid`. Phones
  go down to z = 0.12–0.15 (0.113 with the rubber band), so the rocks *behind* the world would slide *faster* than the tree, and the eye would read
  them as in front.
* with the dolly law it is `f / (f + (1 − f) z)`: below 1 for every f < 1 and above 1 for every f > 1 at *any* zoom.

The dolly law is literally a camera moving toward a stack of planes at depths `d_world / f`.
`node camera.js --test` asserts the speed order at 400 zooms from 0.1 to 1.325.

Layer zoom and screen speed (relative to the world) for each layer:

| layer | f | z = 0.22 | z = 0.5 | z = 0.75 | z = 1 | z = 1.25 |
|---|---|---|---|---|---|---|
| sky | 0.05 | 0.849 / 0.193 | 0.952 / 0.095 | 0.984 / 0.066 | 1 / 0.05 | 1.010 / 0.040 |
| clouds | 0.12 | 0.702 / 0.383 | 0.893 / 0.214 | 0.962 / 0.154 | 1 / 0.12 | 1.025 / 0.098 |
| far | 0.25 | 0.530 / 0.602 | 0.800 / 0.400 | 0.923 / 0.308 | 1 / 0.25 | 1.053 / 0.211 |
| mid | 0.45 | 0.385 / 0.788 | 0.690 / 0.621 | 0.870 / 0.522 | 1 / 0.45 | 1.099 / 0.396 |
| near | 0.7 | 0.287 / 0.914 | 0.588 / 0.824 | 0.811 / 0.757 | 1 / 0.70 | 1.163 / 0.651 |
| world | 1 | 0.220 / 1 | 0.500 / 1 | 0.750 / 1 | 1 / 1 | 1.250 / 1 |
| fg | 1.3 | (hidden) | 0.435 / 1.130 | 0.698 / 1.209 | 1 / 1.30 | 1.351 / 1.405 |
| particles | 1.6 | (hidden) | (hidden) | 0.652 / 1.391 | 1 / 1.60 | 1.471 / 1.882 |

The deep sky barely moves or scales at all, so it reads as infinitely far away. That is the Terraria sky.

### 2.4 Zoom range: zMin(V) = max(0.96·min(V.w / 3840, V.h / 2560), V.w / 5760, V.h / 4000), zMax = 1.25

zMin is the **contain** fit times `ZOOM_OUT_FIT` = 0.96 (camera.js, realm.json `camera.zoomOutFit`): at full zoom-out
the **whole realm** is on screen at once, from the crown's top leaves to the island's roots and from the ACH shrine to
the CM outcrop, with a small border (2% of the view on the binding axis) where the layers behind show. It is capped so
the view is never wider than the world plus the pan margin on both sides (3840 + 2·960 = 5760) or taller
(2560 + 2·720 = 4000): the layers behind cover exactly that envelope (2.7). The cap binds only on screens wider than
0.96·5760/2560 ≈ 2.16:1 or narrower than 3840/(0.96·4000) = 1:1; phones up to 19.5:9 (2.164) still see everything.

```
zMin(V)   = min(zMax, max(0.96 · min(V.w/3840, V.h/2560),  V.w/(3840 + 2·960),  V.h/(2560 + 2·720)))
zCover(V) = min(zMax, max(V.w/3840, V.h/2560))       the old floor (cover fit); it now only bounds the start zoom (2.8)
```

* The start framing does not change: the start zoom keeps the cover fit as its floor (2.8), and so does the client's
  HUD-safe start (MapCamera `startFraming`). Zooming out from there reaches the whole-realm view.
* The rubber band still overshoots to 0.94·zMin and springs back (2.5).
* A higher floor (for example a "readable plates" zoom) is a client UX choice and can only *raise* zMin, which keeps
  every guarantee here.

| screen | V (map pts) | zCover (the old zMin) | zMin | binds | start zoom | world px visible at zMin | whole realm |
|---|---|---|---|---|---|---|---|
| 2560×1440 | 2560×1440 | 0.667 | 0.540 | contain | 0.823 | 4741×2667 | yes |
| 1920×1080 | 1920×1080 | 0.500 | 0.405 | contain | 0.617 | 4741×2667 | yes |
| 1366×768 | 1366×768 | 0.356 | 0.288 | contain | 0.439 | 4743×2667 | yes |
| 1024×768 (iPad) | 1024×768 | 0.300 | 0.256 | contain | 0.439 | 4000×3000 | yes |
| 844×390 (iPhone 14) | 844×390 | 0.220 | 0.147 | margin cap | 0.223 | 5760×2662 | yes |
| 667×375 (iPhone SE) | 667×375 | 0.174 | 0.141 | contain | 0.214 | 4743×2667 | yes |
| 3840×2160 px (4K) | 2560×1440 (scale 1.5) | 0.667 | 0.540 | contain | 0.823 | 4741×2667 | yes |
| 3440×1440 ultrawide | 2560×1072 (scale 1.344) | 0.667 | 0.444 | margin cap | 0.667 | 5760×2411 | 94% of the height |
| 390×844 portrait | 568×1229 (scale 0.687) | 0.480 | 0.307 | margin cap | 0.480 | 1848×4000 | the full height |

The committed stills `out/zoomout_{1920,2560,1366,844}.jpg` show the zMin view centred on the realm on four screens.

### 2.5 Clamping and the pan margin

At zoom z, half the view is `h = V/(2z)` world px. The camera may look past each edge of the world by the **pan
margin** M = (960, 720) world px (camera.js `PAN_MARGIN`, realm.json `camera.panMargin`), capped at half the view:

```
m = min(M, h)                                 per axis
centre range = [h − m, W − h + m]             (pins to the world centre if 2h > W + 2m)
```

So the visible rect may extend up to m past the world on each side, and the screen centre never leaves the world
(at high zoom the cap m = h stops the camera with the world's edge at the screen centre). The world art fades out
before its edges (`layers/world.js`, `EDGE_FADE`), so past them the layers behind show: the sky, clouds, far and mid
islands, near rocks and the foreground go on into the margin (section 8). There are two envelopes (camera.js
`panLimits`, `clampCamera`):

* **hard** (at rest): zoom in [zMin, zMax] and centre in the range above.
* **rubber band** (while a finger or wheel is still active): zoom may overshoot to `[0.94·zMin, 1.06·zMax]`, and the
  centre may overshoot by `72/z` world px (72 map points on screen) past the hard range. The displayed overshoot is
  `d·(1 − 1/(x·0.55/d + 1))` with d = 72 (`rubberBand`). On release it springs back (section 9.4).

`clampCamera(C, z, V, { margin: NO_MARGIN })` keeps the view inside the world rect; only the start camera uses it
(2.8). Travel of the camera centre around the middle of its range, before the margin (NO_MARGIN) and with it:

| screen | start zoom | travel before | travel now | zMin | travel at zMin |
|---|---|---|---|---|---|
| 2560×1440 | 0.823 | ±364 × ±405 | ±1324 × ±1125 | 0.540 | ±510 × ±667 |
| 1920×1080 | 0.617 | ±364 × ±405 | ±1324 × ±1125 | 0.405 | ±510 × ±667 |
| 1366×768 | 0.439 | ±364 × ±405 | ±1324 × ±1125 | 0.288 | ±508 × ±667 |
| 1024×768 (iPad) | 0.439 | ±753 × ±405 | ±1713 × ±1125 | 0.256 | ±880 × ±500 |
| 844×390 (iPhone 14) | 0.223 | ±26 × ±405 | ±986 × ±1125 | 0.147 | ±0 × ±669 |
| 390×844 portrait | 0.480 | ±1328 × ±0 | ±1920 × ±720 | 0.307 | ±1920 × ±0 |

(world px; the client's HUD-safe start on 1920×1080, z 0.505, went from ±20 × ±211 to ±980 × ±931.)

### 2.6 Device pixels → map points (`mapScale`)

The contract covers viewports of 568–2560 × 320–1440 map points with an aspect ratio of 0.45–3.6. The client
converts:

1. letterbox anything outside aspect [0.45, 3.6] (a black box around the map; practically only 32:9 monitors);
2. `s = max(w/2560, h/1440)` if the box is larger than 2560×1440; `s = min(w/568, h/320)` if it is smaller than
   568×320; otherwise `s = 1`;
3. `V = box / m`, with m = that s (device px per map point).

A 4K screen therefore renders the 2560×1440 layout at 1.5× device pixels. The camera maths stays in map points. The
client never puts a `UIScale` between the Box and a tile, because tile edges must land on whole device pixels (9.3).
It writes positions in **Scale units of the Box** instead: a map point q becomes `fromScale(q.x / V.w, q.y / V.h)`,
which is DPI-free. Only the tile snapping (9.3) and the node widgets' own `UIScale(m)` use m.

### 2.7 Required layer sizes: "no layer ever runs out"

Given (V, z), the largest distance from the anchor that layer f shows, in local px, is:

```
ext_x(V, z) = f · Dx + V.w / (2 s_L)          Dx = max(0, 1920 + min(960, hx) − hx) + 72/z     hx = V.w/(2z)
ext_y(V, z) = f · Dy + V.h / (2 s_L)          Dy = max(0, 1280 + min(720, hy) − hy) + 72/z     hy = V.h/(2z)
                                              (D: the largest camera offset, pan margin and rubber band included)
required    = 2 · max over the domain of ext  (+0.25%), per axis
```

The domain is every V in section 2.6, and z from `0.94·zMin(V)` to `1.325`. zMin rises with each side of V, so a side
is feasible at z with the smallest partner side the domain allows; `requiredSize()` finds the largest feasible side at
each z by bisection. Layers with `zHide` (fg, and the
particle fields) are hidden below that zoom and are only covered from there. For a fixed z, `ext` is piecewise linear
in V. The worst V is therefore an end of the feasible interval or a kink: `V = 2·M·z` (where the margin cap starts)
or `V = (W + 2M)·z` (where D reaches 0). `requiredSize()` evaluates those candidates exactly and samples z densely
(24,001 log steps). For a layer behind the world the V/(2z) terms cancel while D > 0, so the margin grows its
required half-extent by exactly f·M.

Worst cases found:

* `sky`, `clouds`, `far`, `mid`: the widest view at its rubber-band minimum for x (V.w = 2560 on a ≥ 2.16:1 screen,
  z = 0.418, where the margin cap binds) and the tallest for y (V.h = 1440 on the 0.45 portrait, z = 0.338).
* `near`: a phone-sized view at its rubber-band minimum (x: V.w = 691, z = 0.113; y: V.h = 568, z = 0.133). There the
  72-point overscroll is 540–640 world px.
* `fg`: its fade-out zoom 0.5, with the view whose half-width is exactly the margin (V.w = 960, V.h = 720): the
  largest camera offset with the smallest view.

Each size is then rounded up to whole tiles (section 3).

**Why fg and the particles fade out when zoomed out.** Near-camera layers shrink faster than the world as you zoom
out, so they need the most area exactly where they help least. Without `zHide`, fg would need 9442×6781 instead of
7594×5372 (+57% memory). Foreground clutter also ruins the overview. `fg` and `motesNear` fade in over z 0.50 → 0.62, and `particles` over 0.55 → 0.70
(`alpha = smoothstep(zHide, zShow, z)`, `Visible = false` at 0).

`node camera.js --test` brute-forces about 1.8M (C, z, V) samples. These are a grid of 2,000+ viewports × 25 zooms ×
9 camera positions at the rubber-band limits (pan margin included), 60k random samples per layer, and clamped far-out
requests. It asserts that every visible layer covers the viewport. The tightest margin is 5.3 local px, so the sizes
are tight. It also
checks that each worst case is reachable and reaches at least 99% of the required extent.

### 2.8 Start camera

The start centre is (1500, 1150), the trunk. The start zoom is `clamp(min(V.w/1500, V.h/1750), zCover, 1)`, which
frames the whole tree. Its floor is the cover fit (2.4), not zMin, so the start framing is the same as before the
full zoom-out. The start camera is clamped to the world rect, without the pan margin (camera.js
`startCamera`), so the first view shows only the world, exactly as before the margin existed; the player pans into
the margin from there. There is an intro dolly-out from `min(1.12·z, zMax)` to z over 1.6 s (quintOut). With
ReducedMotion the camera starts at z directly.

---

## 3. Tiles, gutters, memory

* **Grid.** Each layer is a uniform grid of tiles. A tile holds `tw × th` texture px of content (even, ≤ 1020) plus a
  **2 px gutter** on every side, so every image is ≤ 1024×1024. `tw/res` and `th/res` are whole local px, and the
  layer size is `nx·tw/res × ny·th/res`, which is at least the required size. The build picks (tw, th) to minimise
  texture pixels plus a per-tile cost. The world is exact: 3840×2560 = 4×4 tiles of 960×640.
* **LOW tier** = HIGH resolution ÷ 2, or the layer's own `lowRes` (sky 0.25, clouds 0.125, far 0.1875), and each
  LOW tile merges 2×2 HIGH tiles (`lowRes` must give whole texture px per HIGH cell; the build picks the tile so it
  does). With an odd count the last column or
  row is half width or height (`grid.LOW.cols/rows`).
* **Gutters.** The gutter holds the neighbouring tile's pixels (edge pixels repeated at the layer border). The client
  shows only the inside, using `ImageRectOffset = (2, 2)` and `ImageRectSize = (tw, th)`. Bilinear sampling at the
  edge then reads real neighbour colour, which avoids seams from filtering.
* **Placement.** Neighbouring tiles share their edges, and every edge sits on a whole device pixel (9.3). There is
  no overlap: a tile drawn 1 point larger blends a translucent layer's edge strip twice (a visible line on clouds and
  mist) and shifts sharp content by up to 1 px. Snapped, the tiles match a single texture exactly apart from the
  resampling.
* **Alpha bleed.** Roblox turns fully transparent pixels black on upload, and scaled edges then show a dark fringe.
  Before export, every pixel with alpha 0 gets the RGB of its nearest opaque pixel and keeps alpha 0. The sprite
  atlas gets the same treatment.
* **Empty tiles** (max alpha < 2/255) are not uploaded, and the client skips them.
* **Format**: PNG (Open Cloud does not take WebP). File names are `roblox/tiles/<TIER>/<layer>_<i>_<j>.png` (plus
  `roblox/tiles/<TIER>/atlas.png`), with i the column and j the row, both from 0. `node roblox/tile.js` writes them and
  `roblox/manifest.json`. Asset map: `out/realm_assets.json` =
  `{ "HIGH": { "<layer>": { "<i>_<j>": "rbxassetid://…" }, "atlas": "rbxassetid://…" }, "LOW": { … } }`.
* **Painting resolution.** Painters render at `size × res.HIGH`, drawing in local coordinates with
  `ctx.setTransform(res, 0, 0, res, 0, 0)`. Canvas `filter: blur(px)` ignores the transform, so multiply blur radii
  by `res`. The tiler also accepts a full-size render and downsamples it with high quality.
* **Memory** is set by pixel count (the engine transcodes to a fixed format). The totals are in section 1. The test
  checks that they fit the budget even if mip chains are kept.
* **The budgets are nearly full.** The pan margin and then the full zoom-out (2.4) grew every layer but the world
  (2.7). HIGH (desktops) has a 150 MB budget (was 120) and uses 146.8 MB with mips. LOW (phones) stays at 35 MB and
  uses 34.2. The pan margin was paid for by lowering `res.HIGH` of `fg` (0.3 → 0.2; it is blurred by 10 local px, so a
  texel of 5 local px loses little) and `near` (0.5 → 0.45; blurred by 0.9). The zoom-out was paid for on LOW by the
  deepest, softest layers only, through `lowRes`: `sky` 0.3125 → 0.25 (the bright stars are sprites), `clouds`
  0.1875 → 0.125 (blurred by 6 local px) and `far` 0.25 → 0.1875 (hazed 50%, blurred by 2.5); `mid`, `near` and the
  world keep HIGH ÷ 2. Any new or enlarged texture must be paid for the same way. `--test` fails when a budget is
  exceeded.

---

## 4. Atmospheric perspective

Farther layers are hazier, bluer, lower in contrast and softer. Nearer than the world means darker and blurred. Every
painter applies the same recipe with their layer's numbers (`realm.json → layers[].atmosphere`) as a final pass. The
world layer is the reference and gets nothing.

```
L  = luma709(c)                                   (sRGB 0..1)
c1 = L + (c − L) · saturation
c2 = luma(haze) + (c1 − luma(haze)) · contrast
k  = haze + hazeBottom · smoothstep(0.35, 1, y/h)          (a misty abyss below)
c3 = mix(c2, hazeColor(x), k)                     hazeColor → hazeRift across biomeLocal.splitX ± fadeHalfWidth
clamp luma to maxLuma, except emissive pixels (sun, light-falls, rift glow): up to emissiveMax
gaussian blur of `blur` local px, premultiplied alpha
```

| layer | haze colour → rift | haze | +bottom | sat | contrast | blur | maxLuma | emissive |
|---|---|---|---|---|---|---|---|---|
| sky | (22,14,48) → (40,12,34) | 0 | 0 | 1.0 | 1.0 | 0 | 0.72 | 0.95 |
| clouds | (72,54,150) → (120,36,80) | 0.35 | 0.10 | 0.8 | 0.55 | 6 | 0.55 | 0.70 |
| far | (66,50,138) → (110,34,72) | 0.50 | 0.20 | 0.7 | 0.55 | 2.5 | 0.50 | 0.65 |
| mid | (56,40,118) → (96,26,62) | 0.30 | 0.25 | 0.85 | 0.75 | 1 | 0.62 | 0.85 |
| near | (42,28,90) → (80,20,50) | 0.15 | 0.20 | 0.9 | 0.85 | 2.5 (depth of field) | 0.60 | 0.80 |
| world | none | 0 | 0 | 1 | 1 | 0 | 1 | 1 |
| fg | (8,4,18) → (22,4,14) shade | 0.55 | 0 | 0.6 | 0.6 | 10 (depth of field) | 0.25 | 0.60 |

The haze peaks at `far`: the islands dissolve into the violet. `sky` is deliberately clear, because space itself is
the backdrop. **Light:** the key light comes from the upper left (the cosmic sun), using world.js `LIGHT = (−0.45,
−0.62, 0.64)`, so rim light falls on up-left facing edges, warm (255,214,150). Inside the rift biome a second crimson
rim (255,46,99) lights right-facing edges.

---

## 5. Biomes: the realm, the rift and the corrupted outcrop

Panning from the tree (x < 2300) toward the rift (x > 2600) cross-fades the mood from violet and gold to crimson and
magenta. Near the CR / CM outcrop, corrupted green light bleeds into the crimson. Two weights drive it (camera.js
`biome(C, B, z, V)`, with V in map points):

```
w.rift    = smoothstep(2300, 2600, C.x)
cover     = |R ∩ view| / |view|        R = outcrop rect [3300, 3840] × [700, 1700], view = C ± V/(2z)   (viewCover)
w.corrupt = w.rift · smoothstep(0.02, 0.22, cover)
```

**Why the corrupt weight looks at the view, not the centre.** How much of the screen the outcrop fills depends on
the zoom and the screen more than on where the centre is: at the hard east limit (2.5) the camera centre is at
x = 3840 − V.w/(2z) + min(960, V.w/(2z)), 3520 on a 2560-wide screen at z 1, and the outcrop fills 15–50% of the view
(the share counts the margin past the world too). So the weight follows that share. It is 0 at the start camera and
at every overview zoom, because w.rift is 0 there, and at the east limit it reaches:

| screen | z 1 | z 1.1 | z 1.25 (zMax) |
|---|---|---|---|
| 2560×1440 | 0.69 | 0.88 | 1 |
| 1920×1080 | 1 | 1 | 1 |
| 1366×768 and smaller | 1 | 1 | 1 |

`--test` checks this for every domain viewport: the east limit near y 1250 reaches ≥ 0.9, the 1920 and 2560 screens
stay ≥ 0.6 over z 1–1.25, and the tree, the start camera and the west limit stay at 0.

The client recomputes both weights on every frame the camera moves, eases them toward their targets with τ = 0.35 s
(instantly with ReducedMotion), and writes colours only when a weight has moved by more than 0.01. The weights drive:

1. **Tile tint (multiply).** Every tile of layer L gets `ImageColor3 = mix(white, L.tint.rift, w.rift)`. The rift
   tints get stronger with distance: sky (255,196,214), clouds (255,170,196), far (255,186,205), mid (255,205,215),
   near (255,220,225), fg (255,225,230). The world is never tinted, because it is painted as it should look.
   (`tint.corrupt` and `wash.corrupt` are retired. They equal the rift values, so a consumer still on the old rule
   draws the same colours.)
2. **Biome wash.** One full-screen Frame between `mid` and `near`. Its colour is `mix((70,40,140), (150,20,60), w.rift)`
   and its alpha is `mix(0.06, 0.12, w.rift)`. It washes the whole background toward the biome's air colour, like
   Terraria's background fade.
3. **The corrupt accent is light next to the crimson, never a blend over it.** Green and crimson are complements: a
   multiply tint or a wash toward green over crimson and violet art turns the whole screen a muddy grey-mauve (the
   first version did that). So the corrupt weight never touches tile tints or the wash. It works through three local
   effects around the outcrop instead:
   * **Blooms** (`biomes.corrupt.bloom`): a large soft green glow (atlas `glow`) in the `clouds` layer (3200×3400 local
     px, colour (60,230,120), alpha 0.3) and in the `near` layer (1900×2500, (40,255,110), alpha 0.35). Each one is
     drawn *before* its layer's tiles, so clouds and rocks show against the green. The centre is `local` (derived by
     the build), which is the spot behind the outcrop focus (3620, 1180) as seen from the reference camera
     (2880, 1250, z 1): the 1920×1080 view where the accent first reaches full strength (the east limit before the
     pan margin). Further east the blooms drift a little right of the focus, which reads as the glow behind it. `ImageTransparency = 1 − alpha·w.corrupt`, and `Visible = false` at 0.
   * **Outcrop light** at a world point p: `light(p) = 1 − smoothstep(0.55, 1.25, |(p − (3620, 1180)) / (420, 650)|)`
     (camera.js `corruptLight`). It is 1 over the outcrop, CR and CM, under 0.02 at the rift centre, and 0 west of
     x 3095. For a sprite or particle, p is the world point under it on screen: `p = C + (q − Vc)/z`.
   * **Sprite colours.** Sprites with a `color` object use
     `mix(mix(realm, rift, w.rift), corrupt, w.corrupt·light(p))`. Mists, wisps, light-falls and shards near the outcrop
     on screen turn green, and the ones by the rift stay crimson. These ~33 colours depend on the camera, so the client
     rewrites them when a weight moves by more than 0.01, or when the camera has moved more than 24 map points or 2%
     of zoom since the last pass. It does this only while w.corrupt > 0, plus once when it returns to 0.
   * **Field particles.** `g = w.corrupt·light(p)` and
     `ImageColor3 = mix(mix(palette[c], kind.rift, w.rift), kind.corrupt, smoothstep(max(0, p.cg − 0.12), min(1, p.cg + 0.12), g))`.
     Each particle turns green at its own threshold `cg` (in 0.1–0.9, derived), so around the outcrop some motes are
     green and some are embers: the colours sit side by side instead of being averaged. The window is clipped to
     [0, 1], so no particle is green at g = 0 and every one is fully green at g = 1.
   * **Reference code.** camera.js `biomeTint`, `biomeWash`, `biomeSpriteColor`, `biomeFieldColor` and `bloomState`
     implement items 1–3 exactly; the preview simulator (preview/realm.html) calls them, and `--test` checks that a
     sprite is rift-coloured at the rift centre and corrupt-coloured over the outcrop, and that nothing is green at the
     tree.

**Painted biome split.** Painters also paint the rift side into each layer's art. For layer f, the biome midpoint
x = 2450 lies behind the screen centre at local `splitX = A.x + f·(2450 − 1920)`. Values are in
`layers[].biomeLocal`. Cross-fade to the rift palette over `splitX ± fadeHalfWidth`: 900 local px for the barely
moving sky, down to 150 for the world. `layers[].landmarks` gives, per layer, the local point behind the tree, crown,
island, rift, shrine and outcrop when the camera centres on them. Use it to place the rift's crimson glow in each
layer ("behind the rift").

---

## 6. Ambient motion

Nothing on the map is ever perfectly still. Two systems provide the motion:

* **Sprites** are children of a layer container, placed in layer-local px and animated by TweenService. The build
  resolves each sprite group into deterministic `instances` (`realm.json → sprites[].instances`). **LOW uses the first
  `count.LOW` instances.**
* **Particle fields** are drawn per frame by a small updater (section 6.3).

### 6.1 Sprite groups

| name | layer (f) | atlas | HIGH/LOW | size (local px) | motion |
|---|---|---|---|---|---|
| star_twinkle | sky (0.05) | star4, stardot | 72 / 28 | 10–28 | alpha sine ±0.18–0.40, 2.2–5.5 s; scale sine ±0.04–0.12, 5–11 s |
| shooting_star | sky | streak | 2 / 1 | 180–260 long, rotated 18–22° | every 19–37 s: x +520, y +180 over 0.9 s (linear), alpha 1 → 0 (quadOut) |
| nebula_wisp | clouds (0.12) | wispA–D | 7 / 4 | 1100–1900 wide, h = 0.32–0.5 w | drift +5–12 px/s across the layer (wraps); y sine ±10–24, 50–90 s; alpha sine ±0.04–0.08, 20–36 s |
| mist_far | far (0.25) | wispC/D | 5 / 3 | 1500–2600 wide, h = 0.12–0.2 w | drift ±8–16 px/s (wraps); alpha sine ±0.05–0.10, 18–30 s |
| mist_mid | mid (0.45) | wispC/D | 6 / 3 | 1400–2400 wide, h = 0.14–0.24 w | drift ±12–26 px/s (wraps); y sine ±6–14, 30–50 s |
| lightfall | mid | lightfall | 7 / 3 | 56–96 wide, len 380–620, hangs | UIGradient offset scroll every 2.4–4 s; alpha sine ±0.08–0.14, 1.3–2.1 s |
| shard_float | near (0.7) | shardA/B | 8 / 0 | 40–110 | y sine ±6–14, 5–9 s; rotation sine ±2–5°, 9–15 s |
| firefly | world | firefly | 34 / 12 | 16–28 | Lissajous: x sine ±30–90, 7–13 s; y sine ±20–60, 5–11 s; blink alpha sine ±0.30–0.42, 1.8–3.6 s |
| ember | world (rift) | ember | 20 / 8 | 10–20 | rise 14–28 px/s over 420 px (wraps); x sine ±10–26, 3–6 s; alpha locked to the rise (0 at the wrap) |
| vine_world | world | vineThin | 10 / 4 | 18–28 wide, len 110–170, hangs from limbs | sway rotation ±2.5–4°, 4.5–7.5 s |
| vine_fg | fg (1.3) | vineA/B | 12 / 0 | 150–260 wide, len 4–4.8 × wide, hangs from the canopy's underside (y 540–730, from a painted leaf knot), tips at y 1250–1880 | sway ±1.2–2.4°, 6–10 s |
| rift_glow | world | glow | 1 / 1 | 1150×1553 at (3150, 1480) | alpha 0.42 ± 0.14 and scale 1 ± 0.035, both 2.8 s in phase |
| rift_ring | world | ring | 1 / 1 | 760×1102 at (3150, 1480) | every 6 s: scale 0.55 → 1.6 and alpha 0.6 → 0 over 2.4 s (quadOut), then hidden |
| corrupt_glitch | world (outcrop) | bar | 4 / 2 | 300–520 × 3–10 | one burst per 2.2–5.5 s slot, 60–140 ms, x jitter ±18 |
| corrupt_glow | world | glow | 3 / 2 | 300–420 at cr, cm, outcrop base | alpha 0.30 ± 0.12, 2.6–3.6 s |
| crystal_glint | world | star4 | 8 / 4 | 26–40 on shrine + island crystals | every 3–6 s: alpha 0.95 → 0, scale 1.3 → 0.5 over 0.9 s |

Colours are in `realm.json`. `palette` gives fixed colours (instance field `c` is the index); `color` gives the three
biome colours (section 5).

Instance fields: `x, y` (local px, the centre; for hanging sprites, the attachment point); `s` (width, or diameter);
`h` (height when not square); `len` (hanging length); `t` (atlas index); `a` (base alpha); `r` (rotation, degrees);
`c` (palette index); `m` (motion channels).

### 6.2 Motion channels: closed forms and TweenService

Each channel `m = { ch, type, … }` is a closed form of time t. The preview renderer evaluates it with camera.js
`channel` / `spriteState`. The client plays the same curve with TweenService: native, and no per-frame Luau.
`ch ∈ x, y, rot, scale, alpha, grad`. For `alpha`, set `ImageTransparency = 1 − alpha`.

| type | value | TweenService recipe |
|---|---|---|
| `sine` (amp, period, phase) | `base + amp·sin(2π(t/period + phase))` | `TweenInfo.new(period/2, Sine, InOut, -1, true)` from `base − amp` to `base + amp`. A reversing Sine InOut half-period tween *is* this sinusoid. Start after `task.delay(((phase + 0.75) % 1)·period)`, or just a random delay. Clamp alpha end values to [0, 1]. |
| `drift` (speed, from, to, phase) | `from + ((speed·t + phase·(to − from)) mod (to − from))`, an offset from the base | `TweenInfo.new(|to − from|/|speed|, Linear, In, -1, false)` from `from` to `to` (reversed when speed < 0). Start with one partial tween from the phase point to the end. The wrap happens off-layer (wisps) or at alpha 0 (embers), so the jump is never seen. |
| `pulse` (a, b, dur, period, ease, phase) | eased `a → b` over `dur`, then hold `b` until the period ends | loop: set a, `TweenInfo.new(dur, Quad/Linear, Out)` to b, `task.wait(period − dur)`. Channels of one sprite share period and phase. |
| `scroll` (period) | UIGradient offset `−1 → 1` | `UIGradient.Offset` from (0, −1) to (0, 1), `TweenInfo.new(period, Linear, In, -1)`. Use `Rotation = 90` and a transparency sequence with a bright band in the middle. |
| `flicker` (slot, dur, seed; `out: jitter`, amp) | on for `dur` once per `slot`; jitter = random ±amp while on | Luau loop: `task.wait(rand·(slot − dur))`, show with a random x offset ±amp and a random palette colour, `task.wait(dur)`, hide, then wait for the rest of the slot. Any random schedule is fine; camera.js hashes it so previews are repeatable. |

Structure for sprites that tween two things at once:

* **Two position channels** (fireflies: x and y). A wrapper Frame sized like the sprite carries the x tween, in layer
  scale units (`Δ/w`). The ImageLabel inside it carries the y tween in wrapper scale units: `Position = (0.5,
  0.5 + dy/h_sprite)`, `AnchorPoint = (0.5, 0.5)`.
* **`scale`** goes on a `UIScale` child.
* **`rot` on hanging sprites.** A GuiObject rotates about its own centre, and descendants rotate with it. Use a pivot
  Frame of size `(w, 2·len)` with `AnchorPoint (0.5, 0.5)` at the attachment point, and tween its Rotation. The image
  fills the lower half of the pivot (`Position (0, 0.5)`, `Size (1, 0.5)`).

### 6.3 Particle fields (dust, sparks, bokeh at f = 0.7, 1.3, 1.6)

A field is a pattern that repeats every `cell` (local px) on a layer of factor f with anchor (0, 0). It has no edges
and no baked texture.

* **Drift** stays inside the cell: `x = (x0 + vx·t) mod cw + bob`. A particle leaving one cell copy is replaced by
  the next copy at exactly the same spot, so there is no seam.
* **Zoom thinning** keeps the on-screen count about constant. Particle i shows only when `z ≥ τ_i`, where
  `s(τ_i) = s(zFull)·√u_i` and the u_i are stratified. That gives
  `E[count] = V.w·V.h·n / (cell area · s(zFull)²)` for every z ≤ zFull. Each particle fades in over `[τ_i, 1.12·τ_i]`.
* **No repeats.** The cell is larger than any screen. The build derives it (`cell`, `cellWorstCase`) as the largest
  local rect any domain viewport shows at any allowed zoom where the field's alpha is at least `cellCover` = 0.25,
  plus the largest particle, rounded up to 10 px. The results are motesFar 5070×3420 (every zoom: it never fades),
  motesNear 5430×3060 (from z 0.539) and particles 5530×3210 (from z 0.599). So no particle is ever drawn twice on
  one screen. With the old 1800×1200 cell, the same bokeh pair repeated 1284 px apart at z 0.8 on 1920×1080. `--test`
  checks every domain viewport, and also checks 2,500 random cameras for a particle index drawn twice.
* **Targets at 1920×1080.** motesFar: 14 motes. motesNear: 12 motes + 3 sparks. particles: 6 bokeh + 8 dust. Counts
  scale with screen area. `perCell` follows the cell area, so the density on screen does not depend on the cell size.
* **Positions** start on a jittered grid, one particle per stratum, with the strata taken in a shuffled order. So the
  first screen is evenly filled and the thinning order does not depend on position. Each particle drifts at its own
  velocity, so within minutes this becomes a uniform scatter, and the count per screen varies a little around the
  target, as real dust does.
* **Pools** are the most sprites a screen can hold. The count in a view is a sum of independent particle copies, so
  the pool is `ceil(mean + 4σ)` at the worst domain viewport and zoom, and never less than the most found by 6,000
  random samples. The pools are motesFar 43/26, motesNear 46/23 and particles 45/21 (HIGH/LOW). `--test` confirms that
  3,000 random cameras, including 2560×1440, stay under them (peak about 80–90%). LOW uses the particles with `low: 1`.
* **Colour**: see section 5 (the rift mix, plus the corrupt threshold `cg` near the outcrop).

Per-frame algorithm (camera.js `fieldPlace` is the reference; `fieldStep` is the exact incremental form):

```
vis = smoothstep(zHide, zShow, z);  if vis == 0: hide the pool, stop
s = layerZoom(f, z);  P = f·(C − Wc);  R = P ± V/(2s)             (visible local rect)
cells i0..i1, j0..j1 covering R grown by maxSize/2 + maxBob
for each particle p (tier-filtered) with z ≥ p.tau:
    a = vis · smoothstep(p.tau, 1.12·p.tau, z) · (p.a + p.ta·sin(2π(t/p.tt + p.tp)))
    q = ((p.x + p.vx·t) mod cw + p.bx·sin(2π(t/p.bt + p.bp)),  (p.y + p.vy·t) mod ch + p.by·sin(2π(t/p.bt + p.bp + ¼)))
    for each cell (i, j): local = (i·cw + q.x, j·ch + q.y); if within R ± size/2:
        m = Vc + s·(local − P)                                          (map points)
        next pooled ImageLabel (AnchorPoint 0.5, 0.5), in Scale units of the Box (2.6):
            Position = fromScale(m.x / V.w, m.y / V.h),  Size = fromScale(p.size·s / V.w, p.size·s / V.h)
            ImageTransparency = 1 − a,  ImageColor3 = section 5 with light(C + (m − Vc)/z)
hide the unused pool entries
```

---

## 7. Readability: where the art must stay empty

Nodes sit in their painted sockets and must read at every camera position. For layer f, the spot behind (or in front
of) node N is `A + f(N − Wc) + (f − z/s)(C − N)`. When the camera is centred on N (C = N) it is exactly
`A + f(N − Wc)`, at any zoom. A node's footprint (ring + socket glow + nameplate: an ellipse rx 150, ry 170 world px,
centred 24 px below the node) scales by `z/s` into local px. `layers[].keepClear` lists two ellipses per node:

* **hard** = the footprint at alignment, at the worst zoom in [0.6, 1.25].
* **soft** = hard plus the drift of that spot while N stays in the central 30% of a 1920×1080 view.

| layer | rule (in `keepClearRule`) | hard rx×ry | soft rx×ry |
|---|---|---|---|
| sky, clouds, far | advisory: dim, low contrast. The zones collapse to the centre, so keep the centre calm. | ~180×205 | ~400×330 |
| mid | hard: only mist (alpha < 0.3), no island mass. soft: low contrast. | 171×194 | 330×283 |
| near | hard: fully empty. soft: alpha < 0.35. | 162×183 | 248×232 |
| fg | hard: fully empty. soft: alpha < 0.25. Content lives at the edges. | 168×191 | 255×240 |

Together the zones form a band behind the tree trunk and a cluster behind the rift. That is where `mid` keeps to mist,
and where `near` and `fg` stay empty. Sprites that must avoid nodes are placed by the build outside the hard zones,
checked along their whole length for hanging sprites. Thin world vines use 0.72× zones. The test re-checks every
instance.

---

## 8. Art direction per layer

The rule for "inside the realm": every depth is populated. Things pass in front of and behind the tree, the air is
never empty (dust at three depths), light moves (light-falls, rift pulse, twinkles), and distance has a colour.

* **0 sky (f 0.05)**
  * Contents: a domain-warped violet nebula with a galactic band and dust lanes, and a dense faint star field (bright
    stars are twinkle sprites). The **cosmic sun** at about (0.36 w, 0.26 h) has a warm corona. It is the key light
    for everything.
  * The rift side: the right third bleeds crimson/magenta.
  * Palette: void (7,5,13) → deep violet (32,16,70). Never pure black.
  * Feel: infinitely far.
  * Keep empty: nothing hard; the brightest knots stay out of the middle band.
* **1 clouds (f 0.12)**
  * Contents: slow transparent nebula clouds, and **crepuscular rays** fanning from the sun direction. A crimson cloud
    wall lies past `splitX`.
  * Palette: lilac (205,182,255) at 20–50% alpha.
  * Feel: a second sky that moves a little faster, so even the sky has depth.
  * Keep empty: alpha < 0.25 in the band y 0.35–0.65 h of the design frame (2784×1632, centred in the layer).
* **2 far (f 0.25)**
  * Contents: 6–10 small, hazy floating-island silhouettes and thin mist ridges at the bottom. The **ringed planet**
    and its moon hang upper right, over the rift side.
  * Palette: silhouettes 50% into haze (66,50,138), gold rim at 30%.
  * Feel: "the realm goes on forever".
  * Margin: the ridges and the misty abyss run across the whole layer; six more specks sit in the margin strips.
  * Keep empty: no island wider than 420 px.
* **3 mid (f 0.45)**
  * Contents: 4–7 detailed floating islands with rock undersides, hanging roots, glowing crystal seams and tiny trees.
    Their undersides pour **light-falls**, luminous waterfalls of light that start exactly at the `lightfall`
    instances (x, y = top, len). Horizontal mist bands sit at 55–95% height.
  * The rift side: islands cracked with crimson seams.
  * Feel: this is the layer that sells the depth, clearly crossing slower than the tree.
  * Margin: two more islands (H in the west, I on the rift side) reach into the margin strips, and the mist sea rolls
    on to the layer's bottom edge.
  * Keep empty: the trunk band stays mist-only.
* **4 near (f 0.7)**
  * Contents: 5–8 big chunky floating rocks (300–900 px) with crystal veins and a few hanging vines, rim-lit, passing
    close behind the world. One or two crimson-veined shards sit on the rift side.
  * Feel: scale and speed. Big shapes glide by just behind the tree, and small `shard_float` sprites bob among them.
  * Margin: four more rocks (N10–N13) float out in the margin strips.
  * Keep empty: every hard zone. Most tiles stay empty.
* **5 world (f 1)**: `world.js`. The focal plane: sharpest, most saturated. Everything ends inside the 3840×2560
  rect (the crown, the roots, the hanging crystals, the outcrop) and `EDGE_FADE` fades the glows out before the border,
  because the pan margin shows it.
* **6 fg (f 1.3)**
  * Contents: out-of-focus framing: vines and leaf clusters hanging from the top edge (plus the swaying `vine_fg`
    sprites), fern and root silhouettes along the bottom, a few leaves at the sides, and sparse glowing flower dots
    (the only bright bits).
  * Palette: near-black violet (18,9,34) with a faint rim.
  * Feel: you are standing inside the realm, looking through its foliage.
  * Frames: the canopy is laid out from the layer's top edge and the ground growth from its bottom edge, which are the
    edges of the pan envelope; the margin strips get more canopy, vines, fronds, brambles and crystals. Two tiers, by
    the distance d from the nearer of those edges:
    * the dense canopy and ground stay within d ≈ 930. At an N / S pan limit (z 1 on 1080p the view spans d 486–1566)
      that is under 45% of the screen height, so the limit views are framed, not walled;
    * a thin tier reaches on to d 1500–1790: long leafy vines, leafy branches, aerial roots and torn strands with
      crystal pendants hang from the canopy, and arching fern fronds, heart leaves on long petioles, reeds, flower
      stalks and brambles rise from the ground. The views inside the world meet the layer there: with the camera at
      the world's top or bottom edge the screen edge sits at d = 1026 + 0.15 V.h (1188 on 1080p) at every zoom, so the
      top and bottom of those views show foliage again, as before the pan margin: on 1920×1080, over a 7×7 grid of
      cameras inside the world at z 0.62–1.2, fg covers 3.7–5.7% of the screen on average (3.5–6.4% before the
      margin) and more than 3% at 19–23 of the 49 positions. The thin tier is opaque near that screen edge and fades
      toward its tips (alpha ~0.85 at d 1500, ~0.6 at d 1860). The `vine_fg` sprites hang in the same band.
  * Keep empty: every hard zone, and everything more than 1860 local px from the top and bottom edges.
* **7 particles (f 1.6)**: big soft bokeh (violet, gold, cyan; crimson in the rift) and dust drifting upward, all very
  faint.

The sprite atlas (`realm.json → atlas`) is one 1024² sheet, or 512² for LOW. Every region is drawn white or grey so
`ImageColor3` tints it, fades to alpha 0 within its 2 px border, and is alpha-bled. `atlas.looks` describes each
region.

---

## 9. Client contract (Roblox `Map` module)

### 9.1 GUI tree

```
MapGui (ScreenGui)  ScreenInsets = None, ZIndexBehavior = Sibling, DisplayOrder = 0, ResetOnSpawn = false
  Root (Frame, full screen, black)
    Box (Frame: the letterbox of 2.6 on whole device px, no UIScale)   -- m = mapScale.scale, V = Box size / m
      L0_sky, L1_clouds, L2_far, L3_mid     layer planes: Frame, Size = fromScale(1, 1), transparent, never moves;
                                            ClipsDescendants = false. Children, back to front (ZIndex 1, 2, 3):
          Back       (Frame, the moving layer container of 9.2; only L1_clouds and L4_near: it holds the bloom, 5)
          Tile_i_j…  (ImageLabels, whole device px, rewritten when the camera moves, 9.3)
          Sprites    (Frame, the moving layer container of 9.2; the layer's sprites inside it, in scale units)
      Wash (Frame, full Box)
      L4_near, F_motesFar (Frame, full Box), L5_world, L6_fg, F_motesNear
      Links, Nodes                          (Frames, full Box; placed with the world transform, 9.3)
      F_particles, Vignette (ImageLabel, full Box, atlas "vignette", ImageColor3 (8,4,16), ImageTransparency 0.45)
```

Siblings take `ZIndex` = their place in this list, so the order never depends on creation order. Every map object
sets `Active = false`, `Interactable = false` (or has no input), except the nodes. The HUD, panels and overlays live
in other ScreenGuis (DisplayOrder 10+), so moving the map never invalidates them.

**Box.** From `mapScale` of the viewport: `Box.Size = fromOffset(round(box.w), round(box.h))`, and
`Box.Position = fromOffset(floor((vp.X − Size.X) / 2), floor((vp.Y − Size.Y) / 2))`. Both are whole device pixels, and
then `V = Box.Size / m`. Roblox stores a UDim offset as a whole number (a fraction is dropped) and rounds a GUI
object's position and size separately. So an offset written in map points under a `UIScale` could never land on a
device pixel. That is why the Box has no UIScale: offsets are written only where whole device pixels are wanted
(tiles), and everything else uses Scale units of the Box.

### 9.2 Layer containers (every frame the camera moved)

```lua
local function layerZoom(f, z) return z / (f + (1 - f) * z) end
-- for each layer L (w, h = L.size; ax, ay = L.anchor), camera C, z; V in map points
local s  = layerZoom(L.f, z)
local ox = V.X / 2 - s * (ax + L.f * (C.X - 1920))     -- container origin O (map points)
local oy = V.Y / 2 - s * (ay + L.f * (C.Y - 1280))
Sprites.Position = UDim2.fromScale(ox / V.X, oy / V.Y)          -- Scale units of the Box: sub-pixel, DPI-free
Sprites.Size     = UDim2.fromScale(w * s / V.X, h * s / V.Y)
-- the Back container of clouds and near gets the same two writes
placeTiles(L, ox, oy, s)                                        -- 9.3
```

That is 2 writes × 8 containers (+2 Back), plus the tile writes of 9.3. Skip them all while the camera is at rest, so
the ScreenGui cache holds apart from the ambient tweens. `fg` fades with zoom without a CanvasGroup: each fg tile and
sprite gets `ImageTransparency = 1 − smoothstep(0.5, 0.62, z)·alpha` (write it only when the value changes), and the
plane is `Visible = false` at 0.

### 9.3 Tiles, sprites, nodes

**Tiles: one exact recipe.** Every tile edge is a whole device pixel, and neighbours share it. There is no overlap
and no separate rounding of position and size.

```lua
-- once per layer and tier: the column / row edges in layer-local px, from camera.js tileRects (local x, w; y, h),
-- whole numbers: xs = { 0, w_1, w_1 + w_2, …, L.size.w },  ys = { 0, …, L.size.h }
local X, Y = {}, {}
local function placeTiles(L, ox, oy, s)                -- m = device px per map point (2.6)
  for i, x in L.xs do X[i] = math.round(m * (ox + s * x)) end   -- device px from the Box's top-left corner
  for j, y in L.ys do Y[j] = math.round(m * (oy + s * y)) end
  for _, t in L.tiles do                               -- t.i, t.j from 0
    t.gui.Position = UDim2.fromOffset(X[t.i + 1], Y[t.j + 1])
    t.gui.Size     = UDim2.fromOffset(X[t.i + 2] - X[t.i + 1], Y[t.j + 2] - Y[t.j + 1])
  end
end
```

* A tile's right edge is `X[i + 1]`, the same number its right neighbour starts at, so there is no gap and no strip
  blended twice. The Box sits on a whole device pixel and nothing between it and a tile scales, so these whole
  numbers really are device pixels at any zoom and any m (0.687 on a portrait phone, 1.5 on 4K).
* The cost is 2 writes per tile per moving frame: 96 on HIGH and 28 on LOW. A tile whose rect is off screen can be
  set to `Visible = false` for that frame.
* Other properties, set once: `Image` = the asset (skip the tile if it was not uploaded), `ImageRectOffset = (2, 2)`,
  `ImageRectSize = (cw, ch)`, `ScaleType = Stretch`, `BackgroundTransparency = 1`, `BorderSizePixel = 0`,
  `ImageColor3` = the biome tint (5).
* The preview simulator and `compose.js` use this same recipe (`seams=snap`, the default). `seams=overlap` shows the
  retired 1-point overlap for comparison, and `straight=1` filters and blends straight alpha like Roblox (check 6 of 9.8).

**Sprites**: `ImageLabel` with the atlas and the `ImageRectOffset/Size` of their region (halved on LOW),
`AnchorPoint (0.5, 0.5)` (or a pivot for hanging ones), `Position = fromScale(x / w, y / h)`,
`Size = fromScale(s / w, (h or s) / h_layer)`, `Rotation = r`, and the tweens from section 6.2. All children of a
container use scale units, so they follow its zoom for free, and they stay within about half a device pixel of the
snapped tiles. The corrupt **blooms** (5) are built the same way in the `Back` container, at `bloom.layers[].local`,
with size `size`.

**Nodes** stay live UI. Place them with the world transform, `q = Vc + z·(N − C)`, as `fromScale(q.x / V.X, q.y / V.Y)`
inside the full-Box `Nodes` frame. Node widgets are authored in map points, so each one carries a `UIScale(m)`. Their
size policy (scaled with z or with a minimum) is the node widget's choice.

### 9.4 Input feel (`camera.feel`)

* **Drag.** The threshold is 6 pt (mouse) or 12 pt (touch). A press that turns into a drag never activates a node.
  Velocity is exponentially smoothed with τ 0.05 s.
* **Inertia.** On release `v *= exp(−dt/0.32)`. It stops below 6 pt/s. Flings are capped at 4500 pt/s.
* **Edges.** Rubber band while dragging (section 2.5). On release it springs back with `SmoothDamp`, smoothTime 0.18 s.
* **Wheel.** ×1.12 per notch toward a target zoom. The zoom eases in log space with τ 0.085 s, anchored at the cursor
  (`zoomAt`).
* **Pinch.** Direct, anchored at the midpoint, with a pan by the midpoint's delta. The zoom rubber band is ±6%, and it
  springs back in 0.2 s.
* **Double-tap / double-click.** ×1.6 toward the point over 0.35 s (quintOut).
* **Fly to node.** SmoothDamp on C and on log z, smoothTime 0.35 s, zoom `max(current, 0.9)`. The target is the
  hard-clamped camera `clampCamera(N, zoom, V)`, not N itself, so a node near a pan limit ends off centre instead of
  flying past the limit and springing back. With the pan margin every node, CM included, can be centred at z 0.9.
* **Gamepad.** Left stick pans at 1400 pt/s at full tilt (deadzone 0.18, curve 1.6). Triggers zoom at 1.8× per second.
* **Keyboard.** No pan keys, because the game owns letters and arrows. `-` / `=` zoom one notch when not claimed.
* **Every frame.** Clamp with `clampCamera(…, { rubber = true })` while input is active, and the hard clamp at rest.

### 9.5 Tiers

**LOW** applies when `TouchEnabled and not KeyboardEnabled`, or `GuiService.ViewportDisplaySize == Small`, or
`SavedQualityLevel ≤ 3`. **HIGH** applies otherwise. Options can override the choice. LOW means:

* the LOW tile set and the 512² atlas;
* the first `count.LOW` sprite instances;
* field particles with `low = 1`.

The rest of the map behaves the same in both tiers.

### 9.6 ReducedMotion (`GuiService.ReducedMotionEnabled`)

* **Parallax** stays. It is driven directly by the player's own input.
* **Camera.** No inertia (stop on release), a hard clamp while dragging (no rubber band), instant zoom steps, and a
  cut instead of the fly-to animation. No intro dolly.
* **Sprites.** No tweens start. Each sprite rests at its base: alpha `a`, offset 0, gradient offset 0, and a drift
  frozen at its phase.
* **Hidden with ReducedMotion:** `shooting_star`, `ember`, `rift_ring`, `corrupt_glitch`, `crystal_glint`, and the
  `motesNear` and `particles` fields. `motesFar` freezes at t = 0.
* **Biome weights** apply instantly.
* **Re-check.** Watch the property and rebuild the motion state when it changes.

### 9.7 Performance rules

* Tween only what is listed. HIGH has 208 animated sprites, up to 134 pooled field sprites and 2 blooms
  (LOW: 77 + 70 + 2). Per moving frame the Luau cost is the container writes, the tile snapping (96 writes on HIGH)
  and the field updater (about 360 particles × at most 4 cell copies).
* While a full-screen panel covers the map: `Tween:Pause()` every ambient tween, stop the field updater, and set
  `MapGui.Enabled = false`. Resume when the panel closes.
* Preload the visible tiles and the atlas (`ContentProvider:PreloadAsync`) behind the splash, farthest layers first.
* The biome colour writes are throttled (section 5).

### 9.8 Studio acceptance checks

Run these in Studio at three map scales: a 390×844 portrait phone (m 0.687), 1920×1080 (m 1) and 3840×2160
(m 1.5), using the device emulator or the window size.

1. **Seams.** Colour `Root` magenta for the test. Pan slowly and zoom through the whole range (wheel notches, pinch,
   and a slow tween of z), stopping at odd zooms. No magenta line may appear between `sky` or `world` tiles, and no
   brighter or darker line along the tile seams of `clouds`, `mid` or `near`.
2. **Whole pixels.** In a debug build, assert that every visible tile has integral `AbsolutePosition` and
   `AbsoluteSize`, and that `AbsolutePosition.X + AbsoluteSize.X` equals its right neighbour's `AbsolutePosition.X`
   (and the same for rows).
3. **Registration.** Light-fall sprites stay on their island lips within 1 px while panning, and node widgets scale
   by m (1.5 on 4K).
4. **Fields.** At z 0.62–0.8 on 1920×1080 and 2560×1440, no bokeh pattern repeats across the screen.
5. **Biome.** At the east limit on 1920×1080 and z 1 (the world's east edge at the screen centre), crimson stays saturated around the rift, and green light shows
   behind the outcrop (the blooms), green-lit mist and some green motes. At the tree nothing is green.
6. **Straight-alpha rims.** Roblox filters an image's straight (not premultiplied) alpha, so a bright pixel at low
   alpha (3–40) right against an opaque dark shape turns into a light or coloured rim one texel wide when the image is
   magnified. At z 1.25, with `Root` magenta, look along the trunk, the roots and the outcrop edges. The preview draws
   the same way with `straight=1` (`compose.js --straight`); the default preview premultiplies and hides it. Baseline
   (1920×1080, z 1.25, straight against premultiplied): the trunk has about 1,900 pixels off by more than 24/255 (at
   most 52), the roots about 570 (at most 37) and the outcrop about 20 (at most 35), all one-texel rims along branch and
   leaf edges. If the rims show in Studio, soften the glow edges in the world art (a 1–2 px alpha ramp out from the
   opaque shape, with the glow colour pulled toward the shape's colour at low alpha). Do not change the tiler: its
   alpha bleed already gives every alpha-0 pixel a colour (no black at alpha 0 in any tile) and the gutters match their
   neighbours byte for byte, so the rims come from the art itself.

---

## 10. Changing things

1. Edit the inputs in `realm.json`: f, `res.HIGH`, `zHide`/`zShow`, sprite groups, field kinds, atlas regions. If a
   camera constant changes (zMax, slack, overscroll, domain), change it in `camera.js` too; the test compares them.
2. `node camera.js --build` recomputes the sizes, tiles, memory, keep-clear zones, landmarks, instances and particles.
   It is deterministic and idempotent.
3. `node camera.js --test` must pass: coverage, tightness, depth order, tiles and budget, readability, motion, fields
   and biome.
4. If a layer size changed, repaint that layer (painters read `size`, `anchor`, `landmarks`, `biomeLocal`,
   `keepClear` and the `lightfall` instances). Layers grow around their centre, so a painter keeps its composition
   in its design frame (the size it was composed for, `frame` in `distant.js`, `mid.js`, `rocks.js`, `clouds.js` and
   `sky.js`, `F0W × F0H` in `fg.js`) translated to the centre, and fills the new strips. If the pan margin or zMin
   changes, check the composites at the new limits (`compose.js`, the `out/panroom_*.jpg` stills).

The previews follow this contract through camera.js. `preview/realm.html` is the WebGL simulator of the client, and
`compose.js` and `preview/record.js` drive it headless. It places layers with `RealmCamera.layerOffset`, tiles with
the snapped recipe of 9.3, sprites with `spriteState` and fields with `fieldPlace`, so a still matches the client.
Change the contract here first, then the simulator.
