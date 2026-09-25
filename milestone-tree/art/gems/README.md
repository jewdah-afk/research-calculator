# Layer gems (Blender)

Faceted radiant-cut crystal gems for the 21 layers, rendered headless with Blender's Python module (bpy 4.5, Cycles CPU + OpenImageDenoise).
Optional premium node art for the map.

| File | What |
|---|---|
| `sprites/<key>.png` | 512×512 transparent sprite per layer (`m`, `mm`, `em`, `p`, … `cp` is Corrupted Prestige "CR") |
| `sprites/{m,p,t}_locked.png` | locked state: desaturated smoky glass, silver bezel |
| `sprites/{m,p,t}_ready.png` | can-prestige state: bright core and a soft rim glow (fades to transparent at the sprite edge) |
| `contact_sheet.png` | all gems on a dark background, labelled |
| `small_check.png` | every sprite at 96 px on dark, grey and light backgrounds |
| `turntable_m.mp4` | 4 s turntable of the M gem (1080×1080) |
| `LOG.md` | render timings, iteration notes, re-render commands |
| `src/` | `gem.py` (model + materials), `build.py` (renders every sprite), `post.py` (sprite finishing, sheets), `turntable.py`, `bl.py` (shared helpers) |

The view transform is Khronos PBR Neutral, not AgX: AgX shifted the layer hexes (purple went lavender-blue, yellow went beige).
Sprites are ≤1024 px, so they upload to Roblox as-is (ImageLabel, `ScaleType.Fit`).
