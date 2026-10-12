"""Packs the world + atlas into one self-contained viewer page (cubecraft_world.html),
plus a local copy (viewer_local.html) that loads three.js from vendor/ for screenshots."""
import os
import json
import base64
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WD = os.path.join(HERE, "planet")
AD = os.path.join(HERE, "world")
meta = json.load(open(os.path.join(WD, "world.json")))
atlas = json.load(open(os.path.join(AD, "atlas.json")))
X, Z, Y = meta["X"], meta["Z"], meta["Y"]
W = np.fromfile(os.path.join(WD, "world.bin"), dtype=np.uint8)

# run-length encode: (value, run) byte pairs, runs up to 255
out = bytearray()
i, n = 0, len(W)
flat = W.tobytes()
while i < n:
    v = flat[i]
    j = i + 1
    while j < n and flat[j] == v and j - i < 255:
        j += 1
    out += bytes((v, j - i))
    i = j
rle = base64.b64encode(bytes(out)).decode()
png = base64.b64encode(open(os.path.join(AD, "atlas.png"), "rb").read()).decode()

# camera views around the cube planet
import math
C, R = meta["C"], meta["R"]


def vw(n, t, out=78, side=58, lift=0):
    tgt = [C + n[i] * (R + 6) for i in range(3)]
    pos = [C + n[i] * (R + out) + t[i] * side for i in range(3)]
    pos[1] += lift
    return {"pos": [round(v, 1) for v in pos], "target": [round(v, 1) for v in tgt]}


views = {
    "planet": {"pos": [C + 190, C + 150, C - 195], "target": [C, C, C]},
    "grass": vw((0, 1, 0), (0, 0, 1)),
    "forest": vw((0, 0, 1), (0.8, 0.55, 0)),
    "desert": vw((1, 0, 0), (0, 0.55, 0.8)),
    "snow": vw((-1, 0, 0), (0, 0.55, 0.8)),
    "ocean": vw((0, 0, -1), (0.8, 0.55, 0)),
    "volcano": vw((0, -1, 0), (0, 0, 1)),
    "edge": {"pos": [C + R + 55, C + R + 45, C + 70], "target": [C + R, C + R, C + 10]},
}
blocks = []
for b in meta["blocks"]:
    blocks.append({"kind": b["kind"],
                   "t": atlas["index"].get(b["top"], 0) if b["top"] else 0,
                   "s": atlas["index"].get(b["side"], 0) if b["side"] else 0,
                   "b": atlas["index"].get(b["bottom"], 0) if b["bottom"] else 0})

TEMPLATE = open(os.path.join(HERE, "planet_template.html")).read()
page = (TEMPLATE.replace("__RLE__", rle).replace("__ATLAS__", png)
        .replace("__META__", json.dumps({"X": X, "Z": Z, "Y": Y, "cols": atlas["cols"], "rows": atlas["rows"], "tile": atlas["tile"], "pad": atlas["pad"], "cell": atlas["cell"],
                                         "blocks": blocks, "views": views})))
open(os.path.join(HERE, "cubecraft_planet.html"), "w").write(page)
local = ("<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" +
         page.replace("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js", "vendor/three.min.js")
             .replace("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js", "vendor/OrbitControls.js") +
         "</body></html>")
open(os.path.join(HERE, "planet_local.html"), "w").write(local)
print("page bytes", len(page), "views", views)
