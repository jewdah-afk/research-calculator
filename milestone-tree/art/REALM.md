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
node camera.js --test     # ~1.87M checks: coverage brute force, identities, depth order, tiles, budget, sprites, fields (exit 1 on failure)
node camera.js --report   # the table in section 1
```

Fixed by contract: the world layer stays **3840×2560 at f = 1**. `NODES` in `layers/world.js` never move. Nodes are
live UI and are never painted. `realm.json` repeats the node coordinates only as a reference for keep-clear zones.

---

## 1. The stack

| depth | id | f | content | size (local px) | res HIGH / LOW | tile (tex px) | HIGH tiles, MB | LOW tiles, MB |
|---|---|---|---|---|---|---|---|---|
| 0 | `sky` | 0.05 | deep space: nebula, stars, cosmic sun (opaque) | 2656×1536 | 0.625 / 0.3125 | 830×960 | 2×1, 6.1 | 1×1, 1.5 |
| 1 | `clouds` | 0.12 | far nebula wisps, god rays | 2784×1632 | 0.375 / 0.1875 | 522×612 | 2×1, 2.5 | 1×1, 0.6 |
| 2 | `far` | 0.25 | distant hazy islands, ringed planet | 3008×1836 | 0.5 / 0.25 | 752×918 | 2×1, 5.3 | 1×1, 1.3 |
| 3 | `mid` | 0.45 | detailed islands, light-falls, mist bands | 3360×2160 | 0.75 / 0.375 | 840×810 | 3×2, 15.7 | 2×1, 3.9 |
| 4 | `near` | 0.7 | big floating rocks close behind the world (sparse) | 3800×2752 | 0.5 / 0.25 | 950×688 | 2×2, 10.1 | 1×1, 2.5 |
| 5 | `world` | 1.0 | `world.js`: tree, sockets, rift, outcrop, shrine | **3840×2560** | 1 / 0.5 | 960×640 | 4×4, 37.9 | 2×2, 9.5 |
| 6 | `fg` | 1.3 | blurred framing vines, ferns, leaves (sparse) | 5240×3640 | 0.3 / 0.15 | 786×546 | 2×2, 6.6 | 1×1, 1.7 |
| 7 | `particles` | 1.6 | bokeh + dust, a sprite **field** (no baked texture) | infinite (cell 1800×1200) | atlas | – | – | – |

There are two more particle fields: `motesFar` at f = 0.7, drawn with the near rocks, and `motesNear` at f = 1.3,
drawn with the foreground. With them, drifting dust exists at three depths.

**Totals**, counted as RGBA8 bytes of every uploaded image with gutters included:

| tier | tiles | + atlas | texture MB | if the engine keeps mips (×4/3) | budget | GUI objects (tiles + sprites + field pools) |
|---|---|---|---|---|---|---|
| HIGH | 36 | 1024² | **88.2** | 117.7 | 120 | 323 |
| LOW | 11 | 512² | **22.1** | 29.4 | 35 | 135 |

The tiler drops fully transparent tiles, which are common in `near` and `fg`, so the real numbers are lower.

"Local px" is the layer's own pixel unit: 1 local px is 1 map point on screen when the layer's zoom is 1. For the
world layer, local px are world px. A layer's texture is `size × res`, and the client scales it back up.

**Z-order** inside the MapGui, back to front (`realm.json → zOrder`):
sky tiles, sky sprites, clouds tiles, clouds sprites, far tiles, far sprites, mid tiles, mid sprites, **biome wash**,
near tiles, near sprites, field `motesFar`, world tiles, world sprites, fg tiles, fg sprites, field `motesNear`,
**node links, nodes**, field `particles`, **vignette**.
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
  go down to z = 0.17–0.22, so the rocks *behind* the world would slide *faster* than the tree, and the eye would read
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

### 2.4 Zoom range: zMin(V) = max(V.w / 3840, V.h / 2560), zMax = 1.25

zMin is the **cover** fit: the smallest zoom at which the world still fills the viewport. On screens wider than 3:2
the whole world *width* fits, so every node from the shrine (x 520) to CM (x 3690) is on screen at once, and you pan
only vertically. On narrower screens (4:3 iPad, portrait windows) the whole *height* fits.

* A lower zoom would show past the world's painted edges on both sides and make clamping ambiguous. The world layer
  is transparent there, and its content stops at the edge.
* A higher floor (for example a "readable plates" zoom) is a client UX choice and can only *raise* zMin, which keeps
  every guarantee here.

| screen | V (map pts) | zMin | fits | start zoom | world visible at zMin |
|---|---|---|---|---|---|
| 2560×1440 | 2560×1440 | 0.667 | width | 0.823 | 3840×2160 |
| 1920×1080 | 1920×1080 | 0.500 | width | 0.617 | 3840×2160 |
| 1366×768 | 1366×768 | 0.356 | width | 0.439 | 3840×2159 |
| 1024×768 (iPad) | 1024×768 | 0.300 | height | 0.439 | 3413×2560 |
| 844×390 (iPhone 14) | 844×390 | 0.220 | width | 0.223 | 3840×1774 |
| 667×375 (iPhone SE) | 667×375 | 0.174 | width | 0.214 | 3840×2159 |
| 3840×2160 px (4K) | 2560×1440 (scale 1.5) | 0.667 | width | 0.823 | 3840×2160 |
| 3440×1440 ultrawide | 2560×1072 (scale 1.344) | 0.667 | width | 0.667 | 3840×1607 |
| 390×844 portrait | 568×1229 (scale 0.687) | 0.480 | height | 0.480 | 1183×2560 |

### 2.5 Clamping

At zoom z, half the view is `h = V/(2z)` world px. On each axis the camera centre may range over `[h, W − h]`. If the
view is wider than the world on that axis (only possible during the rubber band), it pins to the world centre. There
are two envelopes (camera.js `panLimits`, `clampCamera`):

* **hard** (at rest): zoom in [zMin, zMax] and centre in the range above. The visible world rect always stays inside
  the world.
* **rubber band** (while a finger or wheel is still active): zoom may overshoot to `[0.94·zMin, 1.06·zMax]`, and the
  centre may overshoot by `72/z` world px (72 map points on screen). The displayed overshoot is
  `d·(1 − 1/(x·0.55/d + 1))` with d = 72 (`rubberBand`). On release it springs back (section 9.4).

### 2.6 Device pixels → map points (`mapScale`)

The contract covers viewports of 568–2560 × 320–1440 map points with an aspect ratio of 0.45–3.6. The client
converts:

1. letterbox anything outside aspect [0.45, 3.6] (a black box around the map; practically only 32:9 monitors);
2. `s = max(w/2560, h/1440)` if the box is larger than 2560×1440; `s = min(w/568, h/320)` if it is smaller than
   568×320; otherwise `s = 1`;
3. a `UIScale` of `s` on the map root, and `V = box / s`.

A 4K screen therefore renders the 2560×1440 layout at 1.5× device pixels. Nothing else in the client needs to know
about DPI.

### 2.7 Required layer sizes: "no layer ever runs out"

Given (V, z), the largest distance from the anchor that layer f shows, in local px, is:

```
ext_x(V, z) = f · Dx + V.w / (2 s_L)          Dx = max(0, 1920 − V.w/(2z)) + 72/z     (max camera offset, rubber band included)
ext_y(V, z) = f · Dy + V.h / (2 s_L)          Dy = max(0, 1280 − V.h/(2z)) + 72/z
required    = 2 · max over the domain of ext  (+0.25%), per axis
```

The domain is every V in section 2.6, and z from `0.94·zMin(V)` to `1.325`. Layers with `zHide` (fg, and the
particle fields) are hidden below that zoom and are only covered from there. For a fixed z, `ext` is piecewise linear
in V. The worst V is therefore an end of the feasible interval or the kink `V = 3840·z`. `requiredSize()` evaluates
those candidates exactly and samples z densely (24,001 log steps).

Worst cases found:

* `sky`, `clouds`, `far`, `mid`: a 2560×1440 view at its rubber-band minimum (z = 0.627 for x; z = 0.529 with
  V.h = 1440 for y).
* `near` (y): a phone-sized view at its rubber-band minimum (z = 0.139). There the 72-point overscroll is 518 world
  px.
* `fg`: its fade-out zoom 0.5, with the widest viewport that can reach it.

Each size is then rounded up to whole tiles (section 3).

**Why fg and the particles fade out when zoomed out.** Near-camera layers shrink faster than the world as you zoom
out, so they need the most area exactly where they help least. Without `zHide`, fg would need 6503×4786 instead of
5209×3616 (+80% memory). Foreground clutter also ruins the overview. `fg` and `motesNear` fade in over z 0.50 → 0.62, and `particles` over 0.55 → 0.70
(`alpha = smoothstep(zHide, zShow, z)`, `Visible = false` at 0).

`node camera.js --test` brute-forces about 1.8M (C, z, V) samples. These are a grid of 2,000+ viewports × 25 zooms ×
9 camera positions at the rubber-band limits, 60k random samples per layer, and clamped far-out requests. It asserts
that every visible layer covers the viewport. The tightest margin is 2.7 local px, so the sizes are tight. It also
checks that each worst case is reachable and reaches at least 99% of the required extent.

### 2.8 Start camera

The start centre is (1500, 1150), the trunk. The start zoom is `clamp(min(V.w/1500, V.h/1750), zMin, 1)`, which
frames the whole tree. There is an intro dolly-out from `min(1.12·z, zMax)` to z over 1.6 s (quintOut). With
ReducedMotion the camera starts at z directly.

---

## 3. Tiles, gutters, memory

* **Grid.** Each layer is a uniform grid of tiles. A tile holds `tw × th` texture px of content (even, ≤ 1020) plus a
  **2 px gutter** on every side, so every image is ≤ 1024×1024. `tw/res` and `th/res` are whole local px, and the
  layer size is `nx·tw/res × ny·th/res`, which is at least the required size. The build picks (tw, th) to minimise
  texture pixels plus a per-tile cost. The world is exact: 3840×2560 = 4×4 tiles of 960×640.
* **LOW tier** = HIGH resolution ÷ 2, and each LOW tile merges 2×2 HIGH tiles. With an odd count the last column or
  row is half width or height (`grid.LOW.cols/rows`).
* **Gutters.** The gutter holds the neighbouring tile's pixels (edge pixels repeated at the layer border). The client
  shows only the inside, using `ImageRectOffset = (2, 2)` and `ImageRectSize = (tw, th)`. Bilinear sampling at the
  edge then reads real neighbour colour, which avoids seams from filtering. Each tile is also drawn **1 map point
  wider and taller** (not the last column or row), which avoids seams from pixel rounding. The overlap covers
  duplicated content, so it is invisible.
* **Alpha bleed.** Roblox turns fully transparent pixels black on upload, and scaled edges then show a dark fringe.
  Before export, every pixel with alpha 0 gets the RGB of its nearest opaque pixel and keeps alpha 0. The sprite
  atlas gets the same treatment.
* **Empty tiles** (max alpha < 2/255) are not uploaded, and the client skips them.
* **Format**: PNG (Open Cloud does not take WebP). File names are `out/tiles/<TIER>/<layer>_<i>_<j>.png`, with i the
  column and j the row, both from 0. Asset map: `out/realm_assets.json` =
  `{ "HIGH": { "<layer>": { "<i>_<j>": "rbxassetid://…" }, "atlas": "rbxassetid://…" }, "LOW": { … } }`.
* **Painting resolution.** Painters render at `size × res.HIGH`, drawing in local coordinates with
  `ctx.setTransform(res, 0, 0, res, 0, 0)`. Canvas `filter: blur(px)` ignores the transform, so multiply blur radii
  by `res`. The tiler also accepts a full-size render and downsamples it with high quality.
* **Memory** is set by pixel count (the engine transcodes to a fixed format). The totals are in section 1. The test
  checks that they fit the budget even if mip chains are kept.

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

## 5. Biomes: the realm and the rift

Panning from the tree (x < 2300) toward the rift (x > 2600) cross-fades the mood. Two weights come from the camera
centre (camera.js `biome`):

```
w.rift    = smoothstep(2300, 2600, C.x)
w.corrupt = smoothstep(3300, 3600, C.x) · (1 − smoothstep(350, 700, |C.y − 1250|))      (the CR/CM outcrop)
```

The client eases both toward these targets with τ = 0.35 s, instantly with ReducedMotion. It writes colours only when
a weight has moved by more than 0.01. The weights drive three things:

1. **Tile tint (multiply).** Every tile of layer L gets
   `ImageColor3 = mix(mix(white, L.tint.rift, w.rift), L.tint.corrupt, 0.5·w.corrupt)`. The rift tints get stronger
   with distance: sky (255,196,214), clouds (255,170,196), far (255,186,205), mid (255,205,215), near (255,220,225),
   fg (255,225,230). The world is never tinted, because it is painted as it should look.
2. **Biome wash.** One full-screen Frame between `mid` and `near`. Its colour is
   `mix(mix((70,40,140), (150,20,60), w.rift), (30,160,60), 0.35·w.corrupt)` and its alpha is
   `mix(0.06, 0.12, w.rift)`. It washes the whole background toward the biome's air colour, like Terraria's
   background fade.
3. **Sprite colours.** Sprites with a `color` object use `mix(mix(realm, rift, w.rift), corrupt, 0.5·w.corrupt)`. Field
   particles use `mix(palette[c], kind.rift, w.rift)`.

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
| vine_fg | fg (1.3) | vineA/B | 6 / 0 | 160–300 wide, len 3.2–5 × wide, hangs from the top edge | sway ±1.2–2.4°, 6–10 s |
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
* **Targets at 1920×1080.** motesFar: 14 motes. motesNear: 12 motes + 3 sparks. particles: 6 bokeh + 8 dust. Counts
  scale with screen area.
* **Pools** (the most sprites ever on screen, sampled over the whole domain): motesFar 30/18, motesNear 33/18,
  particles 30/12 (HIGH/LOW). LOW uses the particles with `low: 1`.

Per-frame algorithm (camera.js `fieldPlace` is the reference; `fieldStep` is the exact incremental form):

```
vis = smoothstep(zHide, zShow, z);  if vis == 0: hide the pool, stop
s = layerZoom(f, z);  P = f·(C − Wc);  R = P ± V/(2s)             (visible local rect)
cells i0..i1, j0..j1 covering R grown by maxSize/2 + maxBob
for each particle p (tier-filtered) with z ≥ p.tau:
    a = vis · smoothstep(p.tau, 1.12·p.tau, z) · (p.a + p.ta·sin(2π(t/p.tt + p.tp)))
    q = ((p.x + p.vx·t) mod cw + p.bx·sin(2π(t/p.bt + p.bp)),  (p.y + p.vy·t) mod ch + p.by·sin(2π(t/p.bt + p.bp + ¼)))
    for each cell (i, j): local = (i·cw + q.x, j·ch + q.y); if within R ± size/2:
        next pooled ImageLabel: Position = Vc + s·(local − P), Size = p.size·s, ImageTransparency = 1 − a
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
  * Keep empty: alpha < 0.25 in the band y 0.35–0.65 h.
* **2 far (f 0.25)**
  * Contents: 6–10 small, hazy floating-island silhouettes and thin mist ridges at the bottom. The **ringed planet**
    and its moon hang upper right, over the rift side.
  * Palette: silhouettes 50% into haze (66,50,138), gold rim at 30%.
  * Feel: "the realm goes on forever".
  * Keep empty: no island wider than 420 px.
* **3 mid (f 0.45)**
  * Contents: 4–7 detailed floating islands with rock undersides, hanging roots, glowing crystal seams and tiny trees.
    Their undersides pour **light-falls**, luminous waterfalls of light that start exactly at the `lightfall`
    instances (x, y = top, len). Horizontal mist bands sit at 55–95% height.
  * The rift side: islands cracked with crimson seams.
  * Feel: this is the layer that sells the depth, clearly crossing slower than the tree.
  * Keep empty: the trunk band stays mist-only.
* **4 near (f 0.7)**
  * Contents: 5–8 big chunky floating rocks (300–900 px) with crystal veins and a few hanging vines, rim-lit, passing
    close behind the world. One or two crimson-veined shards sit on the rift side.
  * Feel: scale and speed. Big shapes glide by just behind the tree, and small `shard_float` sprites bob among them.
  * Keep empty: every hard zone. Most tiles stay empty.
* **5 world (f 1)**: `world.js` unchanged. The focal plane: sharpest, most saturated.
* **6 fg (f 1.3)**
  * Contents: out-of-focus framing: vines and leaf clusters hanging from the top edge (plus the swaying `vine_fg`
    sprites), fern and root silhouettes along the bottom, a few leaves at the sides, and sparse glowing flower dots
    (the only bright bits).
  * Palette: near-black violet (18,9,34) with a faint rim.
  * Feel: you are standing inside the realm, looking through its foliage.
  * Keep empty: every hard zone, and the middle 60% of the height except faint leaf tips.
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
    Box (Frame, letterbox from mapScale, centred) + UIScale(mapScale.scale)        -- V = Box size in map points
      L0_sky, L1_clouds, L2_far, L3_mid        (layer containers: Frame, transparent, ClipsDescendants = false)
      Wash (Frame, full Box)
      L4_near, F_motesFar (Frame, full Box), L5_world, L6_fg, F_motesNear
      Links, Nodes                              (same transform as L5_world)
      F_particles, Vignette (ImageLabel, full Box, atlas "vignette", ImageColor3 (8,4,16), ImageTransparency 0.45)
```

Every map object sets `Active = false`, `Interactable = false` (or has no input), except the nodes. The HUD, panels
and overlays live in other ScreenGuis (DisplayOrder 10+), so moving the map never invalidates them.

### 9.2 Layer containers (every frame the camera moved)

```lua
local function layerZoom(f, z) return z / (f + (1 - f) * z) end
-- for each layer L (w, h = L.size; ax, ay = L.anchor):
local s  = layerZoom(L.f, z)
local px = ax + L.f * (C.X - 1920)
local py = ay + L.f * (C.Y - 1280)
container.Position = UDim2.fromOffset(V.X / 2 - s * px, V.Y / 2 - s * py)
container.Size     = UDim2.fromOffset(w * s, h * s)
```

That is 2 writes × 8 containers. Skip them while the camera is at rest, so the ScreenGui cache holds apart from the
ambient tweens. `fg` fades with zoom without a CanvasGroup: each fg tile and sprite gets
`ImageTransparency = 1 − smoothstep(0.5, 0.62, z)·alpha` (write it only when the value changes), and the container
is `Visible = false` at 0.

### 9.3 Tiles and sprites (created once)

* **Tile (i, j)** of tier T (from camera.js `tileRects`): an `ImageLabel` with `Image` = the asset (skip it if it was
  not uploaded), `ImageRectOffset = (2, 2)`, `ImageRectSize = (cw, ch)`,
  `Position = UDim2.fromScale(lx / w, ly / h)`, and
  `Size = UDim2.new(lw / w, lastCol and 0 or 1, lh / h, lastRow and 0 or 1)` (the 1-point overlap).
  `BackgroundTransparency = 1`, `ScaleType = Stretch`, `ImageColor3` = the biome tint.
* **Sprites**: `ImageLabel` with the atlas and the `ImageRectOffset/Size` of their region (halved on LOW),
  `AnchorPoint (0.5, 0.5)` (or a pivot for hanging ones), `Position = fromScale(x / w, y / h)`,
  `Size = fromScale(s / w, (h or s) / h_layer)`, `Rotation = r`, and the tweens from section 6.2. All children use
  scale units, so they follow the container's zoom for free.
* **Nodes** stay live UI. Place them with the world transform, `q = Vc + z·(N − C)`. Their size policy (scaled with z
  or with a minimum) is the node widget's choice.

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
* **Fly to node.** SmoothDamp on C and on log z, smoothTime 0.35 s, zoom `max(current, 0.9)`.
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

* Tween only what is listed. HIGH has 194 animated sprites plus up to 93 pooled field sprites (LOW: 76 + 48). Per frame the Luau cost
  is the container writes plus the field updater.
* While a full-screen panel covers the map: `Tween:Pause()` every ambient tween, stop the field updater, and set
  `MapGui.Enabled = false`. Resume when the panel closes.
* Preload the visible tiles and the atlas (`ContentProvider:PreloadAsync`) behind the splash, farthest layers first.
* The biome colour writes are throttled (section 5).

---

## 10. Changing things

1. Edit the inputs in `realm.json`: f, `res.HIGH`, `zHide`/`zShow`, sprite groups, field kinds, atlas regions. If a
   camera constant changes (zMax, slack, overscroll, domain), change it in `camera.js` too; the test compares them.
2. `node camera.js --build` recomputes the sizes, tiles, memory, keep-clear zones, landmarks, instances and particles.
   It is deterministic and idempotent.
3. `node camera.js --test` must pass: coverage, tightness, depth order, tiles and budget, readability, motion, fields
   and biome.
4. If a layer size changed, repaint that layer (painters read `size`, `anchor`, `landmarks`, `biomeLocal`,
   `keepClear` and the `lightfall` instances).

`compose.js` predates this contract. It uses a top-left camera with no zoom. Previews should place layers with
`RealmCamera.layerOffset`, sprites with `spriteState` and fields with `fieldPlace`, so they match the client exactly.
