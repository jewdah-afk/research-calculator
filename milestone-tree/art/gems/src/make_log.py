"""make_log.py - write out/LOG.md from the render timing logs + the iteration notes."""
import os, sys, csv, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from post import TREE
OUT = os.path.join(HERE, "out")

rows = {}
p = os.path.join(OUT, "LOG_sprites.tsv")
if os.path.exists(p):
    for r in csv.reader(open(p), delimiter="\t"):
        rows[r[1]] = r                      # latest render of each sprite wins
tt = {}
p = os.path.join(OUT, "LOG_turntable.json")
if os.path.exists(p):
    tt = json.load(open(p))

L = []
L.append("# Tree gems: render log\n")
L.append("Headless Blender 4.5.14 (bpy), Cycles CPU (4 shared cores, load average 4 to 15 from other jobs during the "
         "runs), OpenImageDenoise, adaptive sampling. One scene (`gems.blend`); between sprites only material and "
         "world-tint values change (`gem.set_look`), with persistent data on so the BVH is reused.\n")
L.append("## Iteration history (tests in `tests/`)\n")
L.append("| Pass | What | Res / spp | Time per render |")
L.append("|---|---|---|---|")
hist = [
    ("a", "blockout: radiant cut (brilliant crown, 73 facets), gold bezel, emissive core sphere", "256 / 32", "5 to 7 s"),
    ("b-c", "core sphere read as a pearl: replaced by a radial volume-emission glow; hue-calibrated absorption", "200-256 / 24-32", "2 to 11 s"),
    ("d-e", "AgX shifted #b35cff to lavender-blue and #ffe93a to beige: switched the view to Khronos PBR Neutral for colour fidelity", "200 / 24", "4 to 8 s"),
    ("f-h", "pastel wash traced to uniform volume glow; component renders (glow / env / reflections only)", "200-300 / 24", "1 to 6 s"),
    ("g", "world seen by transmission rays tinted with the layer colour: brilliance keeps the exact hue", "200 / 24", "4 to 10 s"),
    ("i-m", "localised glow core, neutral + luminance-scaled absorption (yellow no longer olive), locked/ready looks", "256-300 / 24", "4 to 7 s"),
    ("n", "512 quality check; post: bloom + star sparkles + prestige rim glow + alpha bleed", "512 / 64", "22 to 28 s"),
    ("q-u", "oranges peachy: dome luminance soft-compressed (x/(x+0.6)) before tinting, warm-hue amber drift", "200-256 / 24", "4 to 6 s"),
    ("w", "glow depth and size (z -0.24, r 0.5); sparkle anchors moved to the bezel glints", "320 / 32", "4 to 8 s"),
]
for h in hist:
    L.append(f"| {h[0]} | {h[1]} | {h[2]} | {h[3]} |")
L.append("\n## Final sprites (`out/gems/`, 512x512 RGBA)\n")
L.append("Render: 64 spp max, adaptive threshold 0.015, OIDN, bounces total 24 / glossy 12 / transmission 16. "
         "Post (`post.py`): numpy, about 2 s each.\n")
L.append("| Sprite | Colour | State | Render s | Post s |")
L.append("|---|---|---|---|---|")
tot = 0.0
for name, r in rows.items():
    L.append(f"| {name} | `{TREE[name.split('_')[0]]}` | {r[2]} | {r[5]} | {r[6]} |")
    tot += float(r[5])
L.append(f"\nTotal sprite render time: {tot / 60:.1f} min for {len(rows)} sprites.\n")
if tt:
    L.append("## Turntable (`out/turntable_m.mp4`)\n")
    for k, v in tt.items():
        L.append(f"- {k}: {v}")
    L.append("")
L.append("## Notes\n")
L += [
    "- View transform: AgX (the pipeline default) was tested first but shifted the layer hues (#b35cff to "
    "lavender-blue, #ffe93a to beige, oranges to peach). The sprites use Khronos PBR Neutral, which keeps sRGB "
    "brand colours while still rolling off highlights.",
    "- Colour logic lives in `gem.set_look`: rays leaving the crystal by refraction see the dome tinted with the layer "
    "colour (soft-compressed), a radial volume emission gives the inner glow, and neutral absorption adds depth "
    "(yellows drift to amber instead of olive). First-surface glints and the gold bezel stay white.",
    "- Post (`post.py`): bloom on near-white pixels only, 4-point star sparkles at fixed glint anchors (the same on "
    "every colour), a layer-coloured rim halo under the ready state (faded to 0 at the sprite border), then colour "
    "bleed into fully transparent pixels so bilinear filtering and mipmaps never pull in black (no dark fringe).",
    "- Framing: every sprite has the same camera; the bezel spans x 62-449 and y 64-443 of 512, centred, leaving "
    "room for the ready halo.",
    "- Re-render one colour: `venv/bin/python build.py --only pp,m:ready` (about 25 to 100 s each, depending on CPU "
    "load). Re-finish without rendering: `post.py sprite out/raw/m.png out/gems/m.png '#b35cff' base`. Sheets: "
    "`post.py sheets`. Turntable: `turntable.py render 720 12` then `turntable.py post`.",
    "",
]
open(os.path.join(OUT, "LOG.md"), "w").write("\n".join(L) + "\n")
print("wrote", os.path.join(OUT, "LOG.md"))
