"""Cube planet prototype: a cube whose six faces each carry a biome, with gravity pointing toward
the cube's centre on each face. Terrain wraps continuously over edges (heights come from 3D noise
sampled on the base cube, and biome parameters blend near edges).
Writes planet/world.bin (uint8, index = (x*D + z)*D + y) and planet/world.json."""
import os
import json
import random
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "planet")
os.makedirs(OUT, exist_ok=True)

R = 48            # half-width of the base cube: each face is 96 x 96 blocks
H = 20            # tallest terrain above the base
D = 2 * (R + H + 2)
C = (D - 1) / 2
rng = random.Random(77)

src = open(os.path.join(HERE, "worldgen.py")).read()
BLOCKS = eval(src[src.index("BLOCKS = [") + len("BLOCKS = "):src.index("]\nID") + 1])
BLOCKS += [("lava", "lava", "lava", "lava", "lava"), ("ash", "ash", "ash", "ash", "solid")]
ID = {b[0]: i for i, b in enumerate(BLOCKS)}

# ---------- coordinates (array axes: 0 = x, 1 = z, 2 = y) ----------
ix, iz, iy = np.indices((D, D, D), dtype=np.float32)
rx, ry, rz = ix - C, iy - C, iz - C
ax, ay, az = np.abs(rx), np.abs(ry), np.abs(rz)
m = np.maximum(np.maximum(ax, ay), az)
# face id: 0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z
axis = np.where((ax >= ay) & (ax >= az), 0, np.where(ay >= az, 1, 2))
sign_pos = np.where(axis == 0, rx > 0, np.where(axis == 1, ry > 0, rz > 0))
face = (axis * 2 + (~sign_pos)).astype(np.int8)
d = m - R                                   # height above the base plane of this voxel's face
scale = R / np.maximum(m, 1e-3)
px, py, pz = rx * scale, ry * scale, rz * scale   # projection onto the base cube (continuous over edges)


def hash3(gx, gy, gz, seed):
    h = (gx * 374761393 + gy * 668265263 + gz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 65535.0


def vnoise3(x, y, z, cell, seed):
    fx, fy, fz = x / cell, y / cell, z / cell
    x0, y0, z0 = np.floor(fx).astype(np.int64), np.floor(fy).astype(np.int64), np.floor(fz).astype(np.int64)
    tx, ty, tz = fx - x0, fy - y0, fz - z0
    tx, ty, tz = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty), tz * tz * (3 - 2 * tz)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (tx if dx else 1 - tx) * (ty if dy else 1 - ty) * (tz if dz else 1 - tz)
                out = out + w * hash3(x0 + dx + 1000, y0 + dy + 1000, z0 + dz + 1000, seed)
    return out


def fbm3(x, y, z, cell, seed, oct=4):
    tot, amp, norm = 0, 1.0, 0
    for o in range(oct):
        tot = tot + amp * vnoise3(x, y, z, cell / 2 ** o, seed + o)
        norm += amp
        amp *= 0.5
    return tot / norm


# per-face biome: base height, amplitude, sea level, ridge (0..1)
BIOME = {
    0: ("desert", 5, 10, 2, 0.0),
    1: ("snowy", 6, 15, 3, 0.7),
    2: ("grass", 5, 12, 4, 0.15),
    3: ("volcano", 3, 8, 4, 0.4),
    4: ("forest", 6, 11, 4, 0.15),
    5: ("ocean", 0, 11, 6, 0.2),
}
# blend weights per face, so terrain parameters meet smoothly at the edges
wsum = np.zeros_like(m)
P = {k: np.zeros_like(m) for k in ("base", "amp", "sea", "ridge")}
for f, (name, base, amp, sea, ridge) in BIOME.items():
    a, s = f // 2, (1 if f % 2 == 0 else -1)
    comp = (px, py, pz)[a] * s / R
    w = np.clip((comp - 0.72) / 0.28, 0, 1) ** 2
    wsum += w
    for k, v in (("base", base), ("amp", amp), ("sea", sea), ("ridge", ridge)):
        P[k] += w * v
for k in P:
    P[k] /= np.maximum(wsum, 1e-6)

n1 = fbm3(px, py, pz, 26, 11)
n2 = fbm3(px, py, pz, 14, 23, 3)
ridged = 1 - np.abs(2 * n2 - 1)
hn = n1 * (1 - P["ridge"]) + (0.5 * n1 + 0.6 * ridged ** 2) * P["ridge"]
height = P["base"] + P["amp"] * (hn - 0.3) * 1.6
# volcano: a cone with a crater in the middle of the -y face
on_v = face == 3
vr = np.sqrt(px ** 2 + pz ** 2)
cone = np.clip(19 - vr * 0.62, 0, None)
crater = vr < 7
height = np.where(on_v, np.maximum(height, np.where(crater, 11 + (vr / 7) * 4, cone + (n2 - 0.5) * 3)), height)
height = np.minimum(height, H - 1)
sea = P["sea"]
crater_lava = on_v & crater & (d > height) & (d <= 13.5)

solid = d <= height
depth = height - d
W = np.zeros((D, D, D), dtype=np.uint8)

# layers toward the centre
W[solid] = ID["stone"]
deep = solid & (m < R * 0.62 + (n2 - 0.5) * 6)
W[deep] = ID["slate"]
mix = solid & ~deep & (m < R * 0.62 + 3)
W[mix & (np.random.default_rng(5).random(W.shape) < 0.45)] = ID["slate"]

beach = (height <= sea + 1.2)
for f, (name, *_rest) in BIOME.items():
    on = solid & (face == f)
    top = on & (depth < 1)
    sub = on & (depth >= 1) & (depth < 4)
    if name == "desert":
        W[top | sub] = ID["sand"]
        W[on & (depth >= 4) & (depth < 9)] = ID["sandstone"]
    elif name == "snowy":
        W[sub] = ID["dirt"]
        W[top] = ID["snow_grass"]
        W[top & (height > 11)] = ID["snow"]
        W[(top | sub) & (height > 15) & (ridged > 0.92)] = ID["stone"]
    elif name == "volcano":
        W[top | sub] = ID["ash"]
        W[top & (n2 > 0.7)] = ID["slate"]
        # glowing lava cracks running down the slopes
        W[top & (np.abs(n1 - 0.5) < 0.018) & (height > sea + 1)] = ID["lava"]
    elif name == "ocean":
        W[sub] = ID["sand"]
        W[top] = np.where(height[top] > sea[top] + 2.5, ID["grass"], ID["sand"])
        W[sub & (height > sea + 3.5)] = ID["dirt"]
    else:
        W[sub] = ID["dirt"]
        W[top] = ID["grass"]
        W[(top | sub) & beach] = ID["sand"]
    under = on & (height < sea) & (depth < 2)
    W[under] = ID["sand"] if name != "volcano" else ID["ash"]

liquid = ~solid & (d <= sea) & (d > -R)
W[liquid & (face != 3)] = ID["water"]
W[liquid & (face == 3)] = ID["lava"]
W[crater_lava] = ID["lava"]

# ---------- ore veins ----------
UP = {0: (1, 0, 0), 1: (-1, 0, 0), 2: (0, 1, 0), 3: (0, -1, 0), 4: (0, 0, 1), 5: (0, 0, -1)}
stone_like = np.argwhere((W == ID["stone"]) | (W == ID["slate"]))
for name, count, size in (("coal", 900, (5, 11)), ("iron", 600, (4, 8)), ("gold", 260, (3, 7)), ("gem", 140, (2, 6))):
    for _ in range(count):
        x, z, y = stone_like[rng.randrange(len(stone_like))]
        if name in ("gold", "gem") and m[x, z, y] > R - (2 if name == "gold" else 6):
            continue
        for _ in range(rng.randrange(*size)):
            if 0 <= x < D and 0 <= z < D and 0 <= y < D:
                b = W[x, z, y]
                if b == ID["stone"]:
                    W[x, z, y] = ID[name]
                elif b == ID["slate"]:
                    W[x, z, y] = ID["slate_" + name]
            k = rng.randrange(6)
            x += (1, -1, 0, 0, 0, 0)[k]
            z += (0, 0, 1, -1, 0, 0)[k]
            y += (0, 0, 0, 0, 1, -1)[k]

# ---------- surface features (trees, plants), grown along each face's up direction ----------
def up_of(x, z, y):
    return UP[int(face[x, z, y])]


def put(x, z, y, b, only_air=True):
    if 0 <= x < D and 0 <= z < D and 0 <= y < D and (not only_air or W[x, z, y] == 0):
        W[x, z, y] = ID[b]


def tangents(u):
    ux, uy, uz = u
    if ux:
        return (0, 1, 0), (0, 0, 1)
    if uy:
        return (1, 0, 0), (0, 0, 1)
    return (1, 0, 0), (0, 1, 0)


def offs(p, u, t1, t2, du, a, b):
    return (p[0] + u[0] * du + t1[0] * a + t2[0] * b,
            p[1] + u[2] * du + t1[2] * a + t2[2] * b,
            p[2] + u[1] * du + t1[1] * a + t2[1] * b)


def tree(p, u, log, leaves, th):
    t1, t2 = tangents(u)
    for i in range(1, th + 1):
        put(*offs(p, u, t1, t2, i, 0, 0), log, only_air=False)
    for du, rad in ((th - 1, 2), (th, 2), (th + 1, 1), (th + 2, 1)):
        for a in range(-rad, rad + 1):
            for b in range(-rad, rad + 1):
                if rad == 2 and abs(a) == 2 and abs(b) == 2 and rng.random() < 0.7:
                    continue
                if du == th + 2 and abs(a) + abs(b) == 2:
                    continue
                put(*offs(p, u, t1, t2, du, a, b), leaves)


def spruce(p, u):
    t1, t2 = tangents(u)
    th = rng.randrange(6, 9)
    for i in range(1, th + 1):
        put(*offs(p, u, t1, t2, i, 0, 0), "spruce_log", only_air=False)
    radii = [3, 2, 3, 2, 1, 2, 1, 0, 0][-(th - 1):]
    for i, rad in enumerate(radii):
        du = 3 + i
        for a in range(-rad, rad + 1):
            for b in range(-rad, rad + 1):
                if abs(a) + abs(b) <= rad + (1 if rad >= 2 else 0):
                    put(*offs(p, u, t1, t2, du, a, b), "spruce_leaves")
    put(*offs(p, u, t1, t2, th + 1, 0, 0), "spruce_leaves")


occ = np.zeros((D, D, D), dtype=bool)


def claim(x, z, y, r=3):
    occ[max(0, x - r):x + r + 1, max(0, z - r):z + r + 1, max(0, y - r):y + r + 1] = True

house = None
for f, (name, *_r) in BIOME.items():
    a = f // 2
    sh = -1 if f % 2 == 0 else 1          # step toward "below" along the axis
    above = np.roll(W, sh, axis=(0, 2, 1)[a])
    surf = np.argwhere((W != 0) & (face == f) & (above == 0) & (W != ID["water"]) & (W != ID["lava"]))
    rng.shuffle(surf := [tuple(map(int, s)) for s in surf])
    u = UP[f]
    if name == "grass":  # small house near the centre of the top face
        best = None
        for (x, z, y) in surf:
            if abs(x - C) < 14 and abs(z - C) < 14 and W[x, z, y] == ID["grass"]:
                best = (x, z, y)
                break
        house = best
    for (x, z, y) in surf:
        b = W[x, z, y]
        if occ[x, z, y]:
            continue
        r = rng.random()
        ux, uz, uy = x + u[0], z + u[2], y + u[1]
        if name in ("grass", "forest", "ocean") and b == ID["grass"]:
            dens = {"grass": 0.006, "forest": 0.05, "ocean": 0.03}[name]
            if r < dens:
                birch = name == "forest" and rng.random() < 0.45
                tree((x, z, y), u, "birch_log" if birch else "log", "birch_leaves" if birch else "leaves", rng.randrange(4, 7))
                claim(x, z, y)
            elif r < dens + 0.22:
                q = rng.random()
                put(ux, uz, uy, "tall_grass" if q < 0.78 else "flower_red" if q < 0.89 else "flower_yellow")
        elif name == "snowy" and b in (ID["snow_grass"], ID["snow"]) and r < 0.03:
            spruce((x, z, y), u)
            claim(x, z, y)
        elif name == "desert" and b == ID["sand"] and r < 0.02:
            for i in range(1, rng.randrange(3, 5)):
                put(*offs((x, z, y), u, (0, 0, 0), (0, 0, 0), i, 0, 0), "cactus")
            claim(x, z, y)

# house on the top face (+y): flatten a pad, then build
if house:
    hx, hz, hy = house
    hw, hd = 7, 6
    for x in range(hx - 1, hx + hw + 1):
        for z in range(hz - 1, hz + hd + 5):
            for y in range(hy + 1, hy + 14):
                if face[x, z, y] == 2:
                    W[x, z, y] = 0
            for y in range(int(C + R), hy + 1):
                if W[x, z, y] == 0:
                    W[x, z, y] = ID["dirt"]
            W[x, z, hy] = ID["grass"]
    f0 = hy
    for x in range(hx, hx + hw):
        for z in range(hz, hz + hd):
            W[x, z, f0] = ID["cobble"]
            ex, ez = x in (hx, hx + hw - 1), z in (hz, hz + hd - 1)
            for y in range(f0 + 1, f0 + 5):
                if ex and ez:
                    W[x, z, y] = ID["log"]
                elif ex or ez:
                    W[x, z, y] = ID["cobble"] if y == f0 + 1 else ID["planks"]
            if (ez and not ex and x in (hx + 1, hx + hw - 2)) or (ex and not ez and z == hz + hd // 2):
                W[x, z, f0 + 2] = ID["glass"]
            if z == hz + hd - 1 and x == hx + hw // 2:
                W[x, z, f0 + 1] = 0
                W[x, z, f0 + 2] = 0
    for layer in range(3):
        y = f0 + 5 + layer
        for x in range(hx - 1 + layer, hx + hw + 1 - layer):
            for z in range(hz - 1 + layer, hz + hd + 1 - layer):
                W[x, z, y] = ID["bricks"] if layer < 2 else ID["stone_bricks"]
    for y in range(f0 + 5, f0 + 10):
        W[hx + hw - 2, hz + 1, y] = ID["stone_bricks"]
    for z in range(hz + hd, hz + hd + 4):
        W[hx + hw // 2, z, f0] = ID["cobble"]

W.tofile(os.path.join(OUT, "world.bin"))
json.dump({"X": D, "Z": D, "Y": D, "R": R, "C": C, "house": list(map(int, house)) if house else None,
           "blocks": [{"name": b[0], "top": b[1], "side": b[2], "bottom": b[3], "kind": b[4]} for b in BLOCKS]},
          open(os.path.join(OUT, "world.json"), "w"), indent=1)
counts = np.bincount(W.ravel(), minlength=len(BLOCKS))
print("D", D, "house", house)
print({BLOCKS[i][0]: int(c) for i, c in enumerate(counts) if c and BLOCKS[i][0] in ("water", "lava", "grass", "sand", "snow", "ash", "log", "spruce_log", "cactus", "birch_log", "tall_grass")})
