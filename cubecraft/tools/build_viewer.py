"""Packs the world + atlas into one self-contained viewer page (cubecraft_world.html),
plus a local copy (viewer_local.html) that loads three.js from vendor/ for screenshots."""
import os
import json
import base64
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WD = os.path.join(HERE, "world")
meta = json.load(open(os.path.join(WD, "world.json")))
atlas = json.load(open(os.path.join(WD, "atlas.json")))
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
png = base64.b64encode(open(os.path.join(WD, "atlas.png"), "rb").read()).decode()

# camera views, from the generated world
W3 = W.reshape(X, Z, Y)
top = np.array([[int(np.nonzero(W3[x, z])[0][-1]) for z in range(Z)] for x in range(X)])
hx, hz, hf = meta["house"]
peak = np.unravel_index(np.argmax(top), top.shape)
sand_top = np.zeros((X, Z), dtype=bool)
names = [b["name"] for b in meta["blocks"]]
for x in range(X):
    for z in range(Z):
        sand_top[x, z] = names[W3[x, z, top[x, z]]] in ("sand", "cactus") and top[x, z] > meta["sea"] + 1
dx, dz = np.nonzero(sand_top)
desert = (int(dx.mean()), int(dz.mean())) if len(dx) else (75, 20)
def view(target, yaw_deg, pitch_deg, dist):
    """Camera looking at target from a yaw/pitch/distance, lifted clear of the terrain."""
    import math
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    tx, ty, tz = target
    px = tx + dist * math.cos(pitch) * math.cos(yaw)
    pz = tz + dist * math.cos(pitch) * math.sin(yaw)
    py = ty + dist * math.sin(pitch)
    # clear every column along the sight line (and around the camera) by a margin
    lift = 0.0
    for i in range(8, 41):  # skip the stretch right next to the target
        f = i / 40
        sx, sz = tx + (px - tx) * f, tz + (pz - tz) * f
        sy = ty + (py - ty) * f
        ix, iz = int(round(sx)), int(round(sz))
        if 0 <= ix < X and 0 <= iz < Z:
            need = top[max(0, ix - 1):ix + 2, max(0, iz - 1):iz + 2].max() + 2.5
            lift = max(lift, (need - sy) / f)
    py = float(py + lift)
    return {"pos": [round(px, 1), round(py, 1), round(pz, 1)], "target": [round(tx, 1), round(ty, 1), round(tz, 1)]}


mx, mz = int(peak[0]), int(peak[1])
views = {
    "overview": {"pos": [-48, 102, 148], "target": [50, 18, 50]},
    "house": view((hx + 3.5, hf + 3, hz + 3), 105, 26, 24),
    "mountains": view((mx, int(top[peak]) - 6, mz), 215, 26, 48),
    "desert": view((desert[0], int(top[desert]) + 1, desert[1]), 300, 30, 40),
    "lake": view((32, 20, 52), 215, 46, 40),
}
blocks = []
for b in meta["blocks"]:
    blocks.append({"kind": b["kind"],
                   "t": atlas["index"].get(b["top"], 0) if b["top"] else 0,
                   "s": atlas["index"].get(b["side"], 0) if b["side"] else 0,
                   "b": atlas["index"].get(b["bottom"], 0) if b["bottom"] else 0})

TEMPLATE = open(os.path.join(HERE, "viewer_template.html")).read()
page = (TEMPLATE.replace("__RLE__", rle).replace("__ATLAS__", png)
        .replace("__META__", json.dumps({"X": X, "Z": Z, "Y": Y, "cols": atlas["cols"], "rows": atlas["rows"], "tile": atlas["tile"], "pad": atlas["pad"], "cell": atlas["cell"],
                                         "blocks": blocks, "views": views})))
open(os.path.join(HERE, "cubecraft_world.html"), "w").write(page)
local = ("<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" +
         page.replace("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js", "vendor/three.min.js")
             .replace("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js", "vendor/OrbitControls.js") +
         "</body></html>")
open(os.path.join(HERE, "viewer_local.html"), "w").write(local)
print("page bytes", len(page), "views", views)
