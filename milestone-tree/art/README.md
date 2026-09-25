# Map art (parallax layers)

Procedural art for the map, drawn with canvas 2D in headless Chromium (Playwright). Every layer is seeded, so a run
always makes the same image.

| layer | file | size | parallax | |
|---|---|---|---|---|
| 0 Sky | `layers/sky.js` | 3840×2160, opaque | ×0.15 | nebula (domain-warped fbm), galactic band, dust lanes, stars, the cosmic sun |
| 1 Far | `layers/far.js` | 3840×2160, transparent | ×0.35 | distant floating islands with haze, ridges, mist, ringed planet |
| 2 World | `layers/world.js` | 3840×2560, transparent | ×1.0 | the tree on its island, node sockets, the Multiverse rift, corrupted outcrop, achievement shrine |
| 3 Foreground | `layers/fg.js` | 4800×3200, transparent | ×1.25 | out-of-focus vines, ferns, bokeh |

Nodes are **not** in the art: every node sits in a socket at its world position (`NODES` in `layers/world.js`) and is
drawn live by the UI, so it can show its state.

```sh
cd art && export NODE_PATH=$(npm root -g)          # needs playwright
node render.js world                               # -> out/world.png (+ out/world_prev.png)
node compose.js out/view.png 560 1100              # what a 1920x1080 screen sees with the camera at (560,1100)
node webp.js                                       # -> out/*.webp
```

`out/` has the WebP exports and three 1920×1080 previews (`preview_*.png`). The PNGs are not committed; run
`render.js` to make them.
