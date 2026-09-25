# Tree gems: render log

Headless Blender 4.5.14 (bpy), Cycles CPU (4 shared cores, load average 4 to 15 from other jobs during the runs), OpenImageDenoise, adaptive sampling. One scene (`gems.blend`); between sprites only material and world-tint values change (`gem.set_look`), with persistent data on so the BVH is reused.

## Iteration history (tests in `tests/`)

| Pass | What | Res / spp | Time per render |
|---|---|---|---|
| a | blockout: radiant cut (brilliant crown, 73 facets), gold bezel, emissive core sphere | 256 / 32 | 5 to 7 s |
| b-c | core sphere read as a pearl: replaced by a radial volume-emission glow; hue-calibrated absorption | 200-256 / 24-32 | 2 to 11 s |
| d-e | AgX shifted #b35cff to lavender-blue and #ffe93a to beige: switched the view to Khronos PBR Neutral for colour fidelity | 200 / 24 | 4 to 8 s |
| f-h | pastel wash traced to uniform volume glow; component renders (glow / env / reflections only) | 200-300 / 24 | 1 to 6 s |
| g | world seen by transmission rays tinted with the layer colour: brilliance keeps the exact hue | 200 / 24 | 4 to 10 s |
| i-m | localised glow core, neutral + luminance-scaled absorption (yellow no longer olive), locked/ready looks | 256-300 / 24 | 4 to 7 s |
| n | 512 quality check; post: bloom + star sparkles + prestige rim glow + alpha bleed | 512 / 64 | 22 to 28 s |
| q-u | oranges peachy: dome luminance soft-compressed (x/(x+0.6)) before tinting, warm-hue amber drift | 200-256 / 24 | 4 to 6 s |
| w | glow depth and size (z -0.24, r 0.5); sparkle anchors moved to the bezel glints | 320 / 32 | 4 to 8 s |

## Final sprites (`out/gems/`, 512x512 RGBA)

Render: 64 spp max, adaptive threshold 0.015, OIDN, bounces total 24 / glossy 12 / transmission 16. Post (`post.py`): numpy, about 2 s each.

| Sprite | Colour | State | Render s | Post s |
|---|---|---|---|---|
| m | `#b35cff` | base | 96.1 | 1.8 |
| pe | `#ff9a2e` | base | 101.6 | 1.8 |
| t | `#ffe93a` | base | 119.4 | 1.9 |
| m_locked | `#b35cff` | locked | 47.2 | 1.5 |
| m_ready | `#b35cff` | ready | 22.2 | 1.6 |
| mm | `#d17aff` | base | 34.9 | 1.8 |
| em | `#e88af2` | base | 35.1 | 1.6 |
| p | `#6fc3ff` | base | 35.7 | 1.8 |
| sp | `#5fe0ff` | base | 24.1 | 1.7 |
| pb | `#57e0b0` | base | 30.6 | 1.6 |
| pp | `#ff4d6d` | base | 33.7 | 1.6 |
| se | `#ff6a1f` | base | 29.3 | 1.6 |
| hp | `#7fd9ff` | base | 30.0 | 1.7 |
| ep | `#9be02c` | base | 33.0 | 1.6 |
| hb | `#6dffb0` | base | 88.5 | 2.3 |
| ap | `#8ff3f3` | base | 108.2 | 1.9 |
| mp | `#ff5a1f` | base | 93.4 | 1.9 |
| pm | `#ff2e63` | base | 94.0 | 1.6 |
| pep | `#f2b04d` | base | 104.3 | 2.1 |
| cp | `#39ff14` | base | 100.2 | 1.8 |
| cm | `#1fbf4a` | base | 42.1 | 1.7 |
| ex | `#45e07f` | base | 29.5 | 1.6 |
| ach | `#ffc93c` | base | 28.1 | 1.6 |
| p_locked | `#6fc3ff` | locked | 45.5 | 1.4 |
| p_ready | `#6fc3ff` | ready | 24.4 | 1.6 |
| t_locked | `#ffe93a` | locked | 62.7 | 1.5 |
| t_ready | `#ffe93a` | ready | 30.9 | 1.7 |

Total sprite render time: 25.4 min for 27 sprites.

## Turntable (`out/turntable_m.mp4`)

- render all frames: 720x720, 12 spp max (adaptive 0.03), OIDN: 832 s (96 raw frames on disk)
- post + encode: upscale to 1080, bloom, glint-driven sparkles, cosmic backdrop, H.264 yuv420p crf 16, 96 frames @ 24 fps: 232 s

## Notes

- View transform: AgX (the pipeline default) was tested first but shifted the layer hues (#b35cff to lavender-blue, #ffe93a to beige, oranges to peach). The sprites use Khronos PBR Neutral, which keeps sRGB brand colours while still rolling off highlights.
- Colour logic lives in `gem.set_look`: rays leaving the crystal by refraction see the dome tinted with the layer colour (soft-compressed), a radial volume emission gives the inner glow, and neutral absorption adds depth (yellows drift to amber instead of olive). First-surface glints and the gold bezel stay white.
- Post (`post.py`): bloom on near-white pixels only, 4-point star sparkles at fixed glint anchors (the same on every colour), a layer-coloured rim halo under the ready state (faded to 0 at the sprite border), then colour bleed into fully transparent pixels so bilinear filtering and mipmaps never pull in black (no dark fringe).
- Framing: every sprite has the same camera; the bezel spans x 62-449 and y 64-443 of 512, centred, leaving room for the ready halo.
- Re-render one colour: `venv/bin/python build.py --only pp,m:ready` (about 25 to 100 s each, depending on CPU load). Re-finish without rendering: `post.py sprite out/raw/m.png out/gems/m.png '#b35cff' base`. Sheets: `post.py sheets`. Turntable: `turntable.py render 720 12` then `turntable.py post`.

