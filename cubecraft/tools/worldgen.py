"""Generates a 100x100 voxel world (seeded) with plains, forest, desert, snowy mountains,
a lake with beaches, underground layers with ore veins, trees, plants and a small house.
Writes world/world.bin (uint8, index = (x*Z + z)*Y + y) and world/world.json."""
import os
import json
import random
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "world")
X, Z, Y = 100, 100, 64
SEA = 20
SEED = 1234
rng = random.Random(SEED)
nrng = np.random.default_rng(SEED)

# id: (name, top, side, bottom, kind)
BLOCKS = [
    ("air", None, None, None, "air"),
    ("grass", "grass_top", "grass_side", "dirt", "solid"),
    ("dirt", "dirt", "dirt", "dirt", "solid"),
    ("stone", "stone", "stone", "stone", "solid"),
    ("cobble", "cobble", "cobble", "cobble", "solid"),
    ("stone_bricks", "stone_bricks", "stone_bricks", "stone_bricks", "solid"),
    ("gravel", "gravel", "gravel", "gravel", "solid"),
    ("sand", "sand", "sand", "sand", "solid"),
    ("log", "log_top", "log_side", "log_top", "solid"),
    ("planks", "planks", "planks", "planks", "solid"),
    ("leaves", "leaves", "leaves", "leaves", "leaves"),
    ("coal", "ore_coal", "ore_coal", "ore_coal", "solid"),
    ("iron", "ore_iron", "ore_iron", "ore_iron", "solid"),
    ("gold", "ore_gold", "ore_gold", "ore_gold", "solid"),
    ("gem", "ore_gem", "ore_gem", "ore_gem", "solid"),
    ("snow_grass", "snow", "snow_side", "dirt", "solid"),
    ("water", "water", "water", "water", "water"),
    ("clay", "clay", "clay", "clay", "solid"),
    ("slate", "slate", "slate", "slate", "solid"),
    ("birch_log", "birch_top", "birch_side", "birch_top", "solid"),
    ("birch_leaves", "birch_leaves", "birch_leaves", "birch_leaves", "leaves"),
    ("spruce_log", "spruce_top", "spruce_side", "spruce_top", "solid"),
    ("spruce_leaves", "spruce_leaves", "spruce_leaves", "spruce_leaves", "leaves"),
    ("cactus", "cactus_top", "cactus_side", "cactus_top", "solid"),
    ("sandstone", "sandstone_top", "sandstone_side", "sandstone_top", "solid"),
    ("bricks", "bricks", "bricks", "bricks", "solid"),
    ("glass", "glass", "glass", "glass", "glass"),
    ("tall_grass", "tall_grass", "tall_grass", "tall_grass", "plant"),
    ("flower_red", "flower_red", "flower_red", "flower_red", "plant"),
    ("flower_yellow", "flower_yellow", "flower_yellow", "flower_yellow", "plant"),
    ("snow", "snow", "snow", "snow", "solid"),
    ("slate_coal", "ore_coal_slate", "ore_coal_slate", "ore_coal_slate", "solid"),
    ("slate_iron", "ore_iron_slate", "ore_iron_slate", "ore_iron_slate", "solid"),
    ("slate_gold", "ore_gold_slate", "ore_gold_slate", "ore_gold_slate", "solid"),
    ("slate_gem", "ore_gem_slate", "ore_gem_slate", "ore_gem_slate", "solid"),
]
ID = {b[0]: i for i, b in enumerate(BLOCKS)}


def noise2(scale, seed, octaves=4):
    r = np.random.default_rng(seed)
    out = np.zeros((X, Z))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = scale / (2 ** o)
        gw = int(X / s) + 3
        grid = r.random((gw, gw))
        xs = np.arange(X) / s
        zs = np.arange(Z) / s
        x0 = xs.astype(int)
        z0 = zs.astype(int)
        tx = xs - x0
        tz = zs - z0
        tx = tx * tx * (3 - 2 * tx)
        tz = tz * tz * (3 - 2 * tz)
        a = grid[np.ix_(x0, z0)] * (1 - tx)[:, None] + grid[np.ix_(x0 + 1, z0)] * tx[:, None]
        b = grid[np.ix_(x0, z0 + 1)] * (1 - tx)[:, None] + grid[np.ix_(x0 + 1, z0 + 1)] * tx[:, None]
        out += amp * (a * (1 - tz)[None, :] + b * tz[None, :])
        total += amp
        amp *= 0.5
    return out / total


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


xx, zz = np.meshgrid(np.arange(X), np.arange(Z), indexing="ij")
base = noise2(36, 1)
detail = noise2(12, 2, 3)
# one mountain range inside the map (north-east), not against the edge
md = ((xx - 68) ** 2 + (zz - 74) ** 2 * 0.8) / (2 * 15.0 ** 2)
mount = np.exp(-md) * (0.55 + 0.7 * noise2(14, 3, 3))
height = 24 + (base - 0.5) * 14 + (detail - 0.5) * 5 + mount * 30
# a lake, west of centre
lake_d = np.sqrt((xx - 30) ** 2 + (zz - 52) ** 2 * 1.3)
height -= np.clip(1 - lake_d / 19, 0, 1) ** 0.9 * 16
height = np.clip(np.round(height), 4, Y - 12).astype(int)

temp = 0.55 * noise2(44, 4, 3) + 0.45 * (1 - zz / Z) + (xx / X) * 0.12
moist = 0.7 * noise2(40, 5, 3) + 0.3 * (1 - xx / X)
biome = np.full((X, Z), "plains", dtype=object)
for x in range(X):
    for z in range(Z):
        h = height[x, z]
        if h > 33 or temp[x, z] < 0.3:
            biome[x, z] = "snowy"
        elif temp[x, z] > 0.64 and moist[x, z] < 0.46:
            biome[x, z] = "desert"
        elif moist[x, z] > 0.56:
            biome[x, z] = "forest"

W = np.zeros((X, Z, Y), dtype=np.uint8)
slate_top = (8 + noise2(10, 6, 2) * 6).astype(int)


def slope(x, z):
    h = height[x, z]
    m = 0
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, nz = x + dx, z + dz
        if 0 <= nx < X and 0 <= nz < Z:
            m = max(m, abs(height[nx, nz] - h))
    return m


for x in range(X):
    for z in range(Z):
        h = height[x, z]
        b = biome[x, z]
        W[x, z, :h + 1] = ID["stone"]
        W[x, z, :slate_top[x, z]] = ID["slate"]
        for i, chance in enumerate((0.7, 0.45, 0.22, 0.08)):  # blend stone into slate over a few layers
            yy = slate_top[x, z] + i
            if yy < h - 4 and rng.random() < chance:
                W[x, z, yy] = ID["slate"]
        for i, chance in enumerate((0.25, 0.1)):  # a few stone pockets just below the line
            yy = slate_top[x, z] - 1 - i
            if yy > 0 and rng.random() < chance:
                W[x, z, yy] = ID["stone"]
        W[x, z, 0] = ID["slate"]
        under = h < SEA
        beach = SEA - 2 <= h <= SEA + 1 and lake_d[x, z] < 19
        steep = slope(x, z) >= 3
        if under:
            pick = rng.random()
            top = ID["sand"] if pick < 0.55 else ID["gravel"] if pick < 0.8 else ID["clay"]
            W[x, z, h] = top
            W[x, z, max(1, h - 2):h] = ID["sand"] if top == ID["sand"] else ID["dirt"]
            W[x, z, h + 1:SEA + 1] = ID["water"]
        elif b == "desert" or beach:
            W[x, z, h - 3:h + 1] = ID["sand"]
            if b == "desert":
                W[x, z, max(1, h - 7):h - 3] = ID["sandstone"]
        elif mount[x, z] > 0.42 and h >= 33:
            # rocky mountain: bare stone, snow caps up high
            if h >= 44 or (h >= 41 and rng.random() < 0.5):
                W[x, z, h] = ID["snow"]
            elif rng.random() < 0.12:
                W[x, z, h] = ID["gravel"]
        elif steep and b != "forest":
            if b == "snowy" and h > 40:
                W[x, z, h] = ID["snow"]
        else:
            W[x, z, h - 3:h] = ID["dirt"]
            W[x, z, h] = ID["snow_grass"] if b == "snowy" else ID["grass"]
            if b == "snowy" and h > 44:
                W[x, z, h] = ID["snow"]

# ore veins (only replace stone / slate)
def veins(name, count, size, ymax, ymin=1):
    for _ in range(count):
        x, z = rng.randrange(X), rng.randrange(Z)
        top = min(ymax, height[x, z] - 2)
        if top <= ymin:
            continue
        y = rng.randrange(ymin, top)
        for _ in range(rng.randrange(*size)):
            if 0 <= x < X and 0 <= z < Z and 0 < y < Y and W[x, z, y] in (ID["stone"], ID["slate"]):
                deep = W[x, z, y] == ID["slate"] and ("slate_" + name) in ID
                W[x, z, y] = ID["slate_" + name] if deep else ID[name]
            d = rng.randrange(6)
            x += (1, -1, 0, 0, 0, 0)[d]
            z += (0, 0, 1, -1, 0, 0)[d]
            y += (0, 0, 0, 0, 1, -1)[d]


veins("coal", 520, (5, 11), 60)
veins("iron", 330, (4, 8), 40)
veins("gold", 120, (3, 7), 22)
veins("gem", 70, (2, 6), 13)
# gravel and clay pockets
veins("gravel", 120, (6, 14), 40)

# ---------- house ----------
best, hx, hz = 1e9, 50, 40
for cx in range(42, 66):
    for cz in range(30, 56):
        patch = height[cx - 2:cx + 10, cz - 2:cz + 13]
        if any(b not in ("plains",) for b in biome[cx - 2:cx + 10, cz - 2:cz + 13].ravel()):
            continue
        if patch.min() <= SEA + 1:
            continue
        v = patch.max() - patch.min() + abs(cx - 52) * 0.05 + abs(cz - 42) * 0.05
        if v < best:
            best, hx, hz = v, cx, cz
hw, hd = 7, 6
floor = int(np.median(height[hx:hx + hw, hz:hz + hd]))
house_cells = set()
for x in range(hx - 1, hx + hw + 1):
    for z in range(hz - 1, hz + hd + 6):
        if 0 <= x < X and 0 <= z < Z:
            h = height[x, z]
            if h > floor:
                W[x, z, floor + 1:] = 0
            for y in range(h + 1, floor + 1):
                W[x, z, y] = ID["dirt"]
            W[x, z, floor] = ID["grass"]
            height[x, z] = floor
for x in range(hx, hx + hw):
    for z in range(hz, hz + hd):
        house_cells.add((x, z))
        W[x, z, floor] = ID["cobble"]
        edge_x = x in (hx, hx + hw - 1)
        edge_z = z in (hz, hz + hd - 1)
        for y in range(floor + 1, floor + 5):
            if edge_x and edge_z:
                W[x, z, y] = ID["log"]
            elif edge_x or edge_z:
                W[x, z, y] = ID["planks"]
        mid_x = x == hx + hw // 2
        mid_z = z == hz + hd // 2
        if (edge_z and not edge_x and x in (hx + 1, hx + hw - 2)) or (edge_x and not edge_z and mid_z):
            W[x, z, floor + 2] = ID["glass"]
        # door on the south side (z = hz + hd - 1)
        if z == hz + hd - 1 and mid_x:
            W[x, z, floor + 1] = 0
            W[x, z, floor + 2] = 0
for x in range(hx, hx + hw):  # cobble band at the base of the walls
    for z in range(hz, hz + hd):
        if (x in (hx, hx + hw - 1) or z in (hz, hz + hd - 1)) and W[x, z, floor + 1] == ID["planks"]:
            W[x, z, floor + 1] = ID["cobble"]
# stepped roof of bricks
for layer in range(3):
    y = floor + 5 + layer
    for x in range(hx - 1 + layer, hx + hw + 1 - layer):
        for z in range(hz - 1 + layer, hz + hd + 1 - layer):
            if layer == 0 or x in (hx - 1 + layer, hx + hw - layer) or z in (hz - 1 + layer, hz + hd - layer) or layer == 2:
                W[x, z, y] = ID["bricks"] if layer < 2 else ID["stone_bricks"]
for y in range(floor + 5, floor + 10):  # chimney
    W[hx + hw - 2, hz + 1, y] = ID["stone_bricks"]
# path from the door, south
px = hx + hw // 2
for z in range(hz + hd, min(Z, hz + hd + 6)):
    W[px, z, floor] = ID["gravel"] if z % 3 == 0 else ID["cobble"]
    house_cells.add((px, z))

# ---------- trees and plants ----------
occupied = np.zeros((X, Z), dtype=bool)
for (x, z) in house_cells:
    occupied[max(0, x - 2):x + 3, max(0, z - 2):z + 3] = True


def top_y(x, z):
    col = W[x, z]
    nz = np.nonzero(col)[0]
    return int(nz[-1]) if len(nz) else 0


def can_grow(x, z, r):
    if x - r < 0 or z - r < 0 or x + r >= X or z + r >= Z:
        return False
    return not occupied[x - r:x + r + 1, z - r:z + r + 1].any()


def blob_tree(x, z, log, leaves, th):
    y0 = top_y(x, z) + 1
    if y0 + th + 3 >= Y:
        return
    for y in range(y0, y0 + th):
        W[x, z, y] = ID[log]
    top = y0 + th - 1
    for dy, rad in ((-2, 2), (-1, 2), (0, 1), (1, 1)):
        for dx in range(-rad, rad + 1):
            for dz in range(-rad, rad + 1):
                if rad == 2 and abs(dx) == 2 and abs(dz) == 2 and rng.random() < 0.7:
                    continue
                if rad == 1 and dy == 1 and abs(dx) + abs(dz) == 2:
                    continue
                cx, cz, cy = x + dx, z + dz, top + dy
                if W[cx, cz, cy] == 0:
                    W[cx, cz, cy] = ID[leaves]
    occupied[x - 2:x + 3, z - 2:z + 3] = True


def spruce(x, z):
    y0 = top_y(x, z) + 1
    th = rng.randrange(6, 10)
    if y0 + th + 2 >= Y:
        return
    for y in range(y0, y0 + th):
        W[x, z, y] = ID["spruce_log"]
    radii = []
    r = 0
    for i in range(th - 1):
        radii.append(r)
        r = r + 1 if r < (3 if i > 3 else 2) and i % 2 == 0 else max(0, r - 1) if i % 2 else r
    radii = list(reversed([0, 1, 1, 2, 1, 2, 3, 2, 3][:th - 1]))
    for i, rad in enumerate(radii):
        y = y0 + 2 + i
        for dx in range(-rad, rad + 1):
            for dz in range(-rad, rad + 1):
                if abs(dx) + abs(dz) > rad + (1 if rad >= 2 else 0):
                    continue
                cx, cz = x + dx, z + dz
                if 0 <= cx < X and 0 <= cz < Z and y < Y and W[cx, cz, y] == 0:
                    W[cx, cz, y] = ID["spruce_leaves"]
    W[x, z, y0 + th] = ID["spruce_leaves"]
    W[x, z, min(Y - 1, y0 + th + 1)] = ID["spruce_leaves"]
    occupied[x - 2:x + 3, z - 2:z + 3] = True


cells = [(x, z) for x in range(X) for z in range(Z)]
rng.shuffle(cells)
for (x, z) in cells:
    t = top_y(x, z)
    surf = W[x, z, t]
    b = biome[x, z]
    if surf == ID["grass"]:
        p = rng.random()
        if b == "forest" and p < 0.07 and can_grow(x, z, 2):
            if rng.random() < 0.4:
                blob_tree(x, z, "birch_log", "birch_leaves", rng.randrange(5, 8))
            else:
                blob_tree(x, z, "log", "leaves", rng.randrange(4, 7))
        elif b == "plains" and p < 0.008 and can_grow(x, z, 2):
            blob_tree(x, z, "log", "leaves", rng.randrange(4, 6))
        elif p < (0.2 if b == "plains" else 0.1) and not occupied[x, z]:
            q = rng.random()
            W[x, z, t + 1] = ID["tall_grass"] if q < 0.8 else ID["flower_red"] if q < 0.9 else ID["flower_yellow"]
    elif surf == ID["snow_grass"]:
        if rng.random() < 0.035 and can_grow(x, z, 2):
            spruce(x, z)
    elif surf == ID["sand"] and b == "desert" and t > SEA + 1:
        if rng.random() < 0.012 and can_grow(x, z, 1):
            for y in range(t + 1, t + 1 + rng.randrange(2, 5)):
                W[x, z, y] = ID["cactus"]
            occupied[x - 1:x + 2, z - 1:z + 2] = True

os.makedirs(OUT, exist_ok=True)
W.tofile(os.path.join(OUT, "world.bin"))
json.dump({"X": X, "Z": Z, "Y": Y, "sea": SEA, "house": [int(hx), int(hz), int(floor)],
           "blocks": [{"name": b[0], "top": b[1], "side": b[2], "bottom": b[3], "kind": b[4]} for b in BLOCKS]},
          open(os.path.join(OUT, "world.json"), "w"), indent=1)
counts = {BLOCKS[i][0]: int(c) for i, c in enumerate(np.bincount(W.ravel(), minlength=len(BLOCKS))) if c}
print("house at", hx, hz, "floor", floor)
print({k: counts[k] for k in sorted(counts, key=lambda k: -counts[k])})
from collections import Counter
print(Counter(biome.ravel()))
