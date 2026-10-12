"""Version 2 of the starter block set: smoother tileable noise, softer grass edges,
shaded cobble, organic log rings and embedded, shiny ores. All original; seeded.
Reuses the cube/scene/sheet rendering from make_textures.py."""
import os
import random
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
N = 16


def hexc(h, a=255):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a], dtype=np.uint8)


def pal(*hs):
    return [hexc(h) for h in hs]


def blank():
    return np.zeros((N, N, 4), dtype=np.uint8)


def vnoise(rng, octaves=((4, 1.0), (8, 0.6), (16, 0.4)), gx=None):
    """Tileable value noise on the 16x16 grid, normalised to 0..1."""
    out = np.zeros((N, N))
    for g, amp in octaves:
        gw = gx or g
        grid = np.array([[rng.random() for _ in range(gw)] for _ in range(g)])
        for y in range(N):
            for x in range(N):
                fx, fy = x * gw / N, y * g / N
                x0, y0 = int(fx) % gw, int(fy) % g
                x1, y1 = (x0 + 1) % gw, (y0 + 1) % g
                tx, ty = fx - int(fx), fy - int(fy)
                tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
                a = grid[y0, x0] * (1 - tx) + grid[y0, x1] * tx
                b = grid[y1, x0] * (1 - tx) + grid[y1, x1] * tx
                out[y, x] += amp * (a * (1 - ty) + b * ty)
    out -= out.min()
    return out / out.max()


def tone_map(n, tones, cuts):
    """tones dark->light; cuts are quantiles splitting the noise into len(tones) bands."""
    qs = np.quantile(n, cuts)
    idx = np.searchsorted(qs, n)
    img = blank()
    for y in range(N):
        for x in range(N):
            img[y, x] = tones[idx[y, x]]
    return img


def mix(c, f):
    o = c.astype(float)
    o[:3] = np.clip(o[:3] * f, 0, 255)
    return o.astype(np.uint8)


# ---------- palettes (ours) ----------
DIRT = pal("5f402a", "6f4b31", "7e573a", "8d6443", "9b714d")
GRASS = pal("4a8530", "579539", "64a442", "71b24b", "84c35a")
STONE = pal("6b6d71", "797b7f", "86888c", "929599", "a2a5a9")
SAND = pal("cbbb85", "d7c890", "e0d29c", "e8dba8", "f0e6bb")
LEAF = pal("2f5f22", "3a702a", "468233", "52933c", "66a94b")
BARK = pal("4b331d", "5a3e24", "68492b", "775533")
WOOD = pal("94683a", "a67945", "b78a52", "c79b60", "d6ab70")


def t_dirt(rng):
    img = tone_map(vnoise(rng), DIRT, [0.1, 0.32, 0.64, 0.9])
    for _ in range(4):  # little pebbles
        x, y = rng.randrange(N), rng.randrange(N - 1)
        img[y, x] = hexc("aa8767")
        img[y + 1, x] = hexc("553a26")
    return img


def t_grass_top(rng):
    img = tone_map(vnoise(rng, ((4, 0.8), (8, 0.6), (16, 0.7))), GRASS, [0.1, 0.33, 0.66, 0.9])
    for _ in range(9):  # blade tips
        x, y = rng.randrange(N), rng.randrange(N - 1)
        img[y, x] = hexc("93d266")
        img[y + 1, x] = GRASS[1]
    return img


def t_grass_side(rng):
    img = t_dirt(rng)
    g = t_grass_top(random.Random(rng.random()))
    depth = 3
    for x in range(N):
        depth = max(2, min(5, depth + rng.choice([-1, 0, 0, 1])))
        d = depth + (rng.randrange(2, 4) if rng.random() < 0.18 else 0)  # occasional drip
        img[:d, x] = g[:d, x]
        img[d - 1, x] = mix(g[d - 1, x], 0.82)  # darker underside of the turf
        if d < N:
            img[d, x] = hexc("4d3421")  # shadow on the dirt
    return img


def t_stone(rng):
    img = tone_map(vnoise(rng, ((4, 1.0), (8, 0.7), (16, 0.35))), STONE, [0.08, 0.28, 0.72, 0.94])
    for _ in range(3):
        x, y = rng.randrange(N - 1), rng.randrange(N - 1)
        img[y, x] = STONE[0]
        img[y, x + 1] = mix(STONE[0], 0.9)
    return img


def t_cobble(rng):
    seeds = [(rng.uniform(0, N), rng.uniform(0, N)) for _ in range(8)]
    base = [STONE[rng.randrange(1, 4)] for _ in seeds]
    owner = np.zeros((N, N), dtype=int)
    rel = np.zeros((N, N))
    for y in range(N):
        for x in range(N):
            best, bi, bdx, bdy = 1e9, 0, 0, 0
            for i, (sx, sy) in enumerate(seeds):
                dx = (x - sx + N / 2) % N - N / 2
                dy = (y - sy + N / 2) % N - N / 2
                dd = dx * dx + dy * dy
                if dd < best:
                    best, bi, bdx, bdy = dd, i, dx, dy
            owner[y, x] = bi
            rel[y, x] = bdx + bdy
    n = vnoise(rng, ((8, 1.0), (16, 0.6)))
    img = blank()
    for y in range(N):
        for x in range(N):
            o = owner[y, x]
            c = base[o]
            f = 1.0 + (n[y, x] - 0.5) * 0.12
            if rel[y, x] < -2.2:
                f *= 1.12
            elif rel[y, x] > 2.2:
                f *= 0.86
            img[y, x] = mix(c, f)
            if owner[y, (x + 1) % N] != o or owner[(y + 1) % N, x] != o:
                img[y, x] = hexc("4f5155")
    return img


def t_log_side(rng):
    n = vnoise(rng, ((16, 1.0), (16, 0.3)), gx=None)
    cols = [rng.randrange(1, 4) for _ in range(N)]
    img = blank()
    for x in range(N):
        for y in range(N):
            t = cols[x] + (1 if n[y, x] > 0.75 else 0) - (1 if n[y, x] < 0.2 else 0)
            img[y, x] = BARK[max(0, min(3, t))]
    for _ in range(6):  # grooves with a lit edge
        x = rng.randrange(N)
        y0 = rng.randrange(N)
        for y in range(y0, y0 + rng.randrange(3, 8)):
            img[y % N, x] = hexc("362313")
            img[y % N, (x + 1) % N] = BARK[3]
    return img


def t_log_top(rng):
    n = vnoise(rng, ((4, 1.0), (8, 0.5)))
    c = 7.5
    img = blank()
    for y in range(N):
        for x in range(N):
            edge = min(x, y, N - 1 - x, N - 1 - y)
            if edge == 0:
                img[y, x] = BARK[(x * 3 + y) % 3]
            elif edge == 1:
                img[y, x] = WOOD[0]
            else:
                r = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 + n[y, x] * 1.4
                img[y, x] = WOOD[3] if int(r * 0.85) % 2 == 0 else WOOD[2]
    img[7:9, 7:9] = WOOD[1]
    return img


def t_planks(rng):
    img = blank()
    n = vnoise(rng, ((4, 1.0), (16, 0.5)), gx=None)
    for b in range(4):
        tone = 1 + b % 3
        seam = rng.randrange(3, 13)
        for y in range(b * 4, b * 4 + 4):
            for x in range(N):
                t = tone + (1 if n[y, x] > 0.8 else 0) - (1 if n[y, x] < 0.15 else 0)
                img[y, x] = WOOD[max(0, min(4, t))]
        img[b * 4, :] = [mix(WOOD[min(4, tone + 1)], 1.0)] * N
        img[b * 4 + 3, :] = hexc("6a4a28")
        img[b * 4:b * 4 + 3, seam] = hexc("7a5631")
        img[b * 4 + 1:b * 4 + 3, (seam + 1) % N] = WOOD[min(4, tone + 1)]
    return img


def t_leaves(rng):
    n = vnoise(rng, ((4, 0.7), (8, 0.8), (16, 0.6)))
    img = tone_map(n, LEAF, [0.14, 0.38, 0.66, 0.9])
    holes = np.quantile(n, 0.1)
    for y in range(N):
        for x in range(N):
            if n[y, x] <= holes:
                img[y, x] = 0
    return img


def t_sand(rng):
    img = tone_map(vnoise(rng, ((4, 0.6), (8, 0.5), (16, 0.8))), SAND, [0.08, 0.3, 0.7, 0.93])
    for _ in range(6):
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = hexc("b4a372")
    return img


def pebble(img, rng, cx, cy, size, mid, dark, light):
    pts = {(cx % N, cy % N)}
    while len(pts) < size:
        x, y = rng.choice(sorted(pts))
        dx, dy = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1)])
        pts.add(((x + dx) % N, (y + dy) % N))
    for (x, y) in pts:
        img[y, x] = mid
    for (x, y) in pts:
        if ((x + 1) % N, y) not in pts or (x, (y + 1) % N) not in pts:
            img[y, x] = dark
        if ((x - 1) % N, y) not in pts and (x, (y - 1) % N) not in pts:
            img[y, x] = light
    return pts


def t_gravel(rng):
    img = tone_map(vnoise(rng, ((8, 1.0), (16, 0.8))), pal("57524e", "625c57", "6e6762"), [0.3, 0.7])
    kinds = [("8f8983", "5f5955", "b4ada5"), ("85725f", "5a4a3c", "a8927b"), ("7f8186", "55575c", "a7a9ae")]
    for _ in range(11):
        m, d, l = rng.choice(kinds)
        pebble(img, rng, rng.randrange(N), rng.randrange(N), rng.randrange(4, 8), hexc(m), hexc(d), hexc(l))
    return img


def ore(mid, dark, light, sparkle, clusters, size):
    def make(rng):
        img = t_stone(rng)
        spots = [(3, 3), (11, 3), (4, 11), (12, 11), (8, 7)]
        rng.shuffle(spots)
        for cx, cy in spots[:clusters]:
            cx += rng.randrange(-1, 2)
            cy += rng.randrange(-1, 2)
            pts = {(cx, cy)}
            target = rng.randrange(*size)
            while len(pts) < target:
                x, y = rng.choice(sorted(pts))
                dx, dy = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)])
                if 0 <= x + dx < N and 0 <= y + dy < N:
                    pts.add((x + dx, y + dy))
            for (x, y) in pts:  # embedded: a shadow in the stone below-right
                for sx, sy in ((x + 1, y + 1), (x + 1, y), (x, y + 1)):
                    if 0 <= sx < N and 0 <= sy < N and (sx, sy) not in pts:
                        img[sy, sx] = mix(img[sy, sx], 0.72)
            for (x, y) in pts:
                img[y, x] = hexc(mid)
            for (x, y) in pts:
                if (x + 1, y) not in pts and (x, y + 1) not in pts:
                    img[y, x] = hexc(dark)
                elif (x - 1, y) not in pts and (x, y - 1) not in pts:
                    img[y, x] = hexc(light)
            top = min(pts, key=lambda p: (p[0] + p[1]))
            img[top[1], top[0]] = hexc(sparkle)
        return img
    return make


TEXTURES = [
    ("grass_top", "Grass (top)", t_grass_top),
    ("grass_side", "Grass (side)", t_grass_side),
    ("dirt", "Dirt", t_dirt),
    ("stone", "Stone", t_stone),
    ("cobble", "Cobble", t_cobble),
    ("gravel", "Gravel", t_gravel),
    ("sand", "Sand", t_sand),
    ("log_side", "Log (bark)", t_log_side),
    ("log_top", "Log (top)", t_log_top),
    ("planks", "Planks", t_planks),
    ("leaves", "Leaves", t_leaves),
    ("ore_coal", "Coal ore", ore("2e3034", "17181b", "4a4d52", "6a6e74", 4, (5, 9))),
    ("ore_iron", "Iron ore", ore("c98c66", "8f5b3e", "e9b590", "fbe0c8", 4, (5, 9))),
    ("ore_gold", "Gold ore", ore("e7b92c", "9c6f12", "ffe066", "fffbe0", 4, (5, 9))),
    ("ore_gem", "Gem ore", ore("37c3c6", "16767d", "8ff4ee", "ffffff", 3, (4, 8))),
]

TILES = os.path.join(HERE, "v2", "tiles16")
BIG = os.path.join(HERE, "v2", "tiles256")
os.makedirs(TILES, exist_ok=True)
os.makedirs(BIG, exist_ok=True)

tex = {}
for i, (key, _, fn) in enumerate(TEXTURES):
    im = Image.fromarray(fn(random.Random(2000 + i)), "RGBA")
    tex[key] = im
    im.save(os.path.join(TILES, key + ".png"))
    im.resize((256, 256), Image.NEAREST).save(os.path.join(BIG, key + ".png"))

# Reuse the v1 renderer (cube, scene, sheet) with these textures.
src = open(os.path.join(HERE, "make_textures.py")).read()
render = src[src.index("# ---------- isometric cube rendering"):]
render = render.replace('"starter_blocks.png"', '"v2", "starter_blocks_v2.png"')
render = render.replace('"starter_cubes.png"', '"v2", "starter_cubes_v2.png"')
render = render.replace("Original 16x16 set, drawn from scratch. Shown at 8x.", "Version 2. Original 16x16 set, drawn from scratch. Shown at 8x.")
g = dict(globals())
g["OUT"] = HERE
g["ImageDraw"] = __import__("PIL.ImageDraw", fromlist=["ImageDraw"])
g["ImageFont"] = __import__("PIL.ImageFont", fromlist=["ImageFont"])
exec(render, g)
