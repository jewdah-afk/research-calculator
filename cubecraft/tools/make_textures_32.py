"""32x32 version of the starter set: same look and palettes as the 16x16 v3 set,
redrawn at double resolution with extra detail (not upscaled). All original; seeded."""
import os
import random
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
N = 32
OUTDIR = os.path.join(HERE, "v3_32")
os.makedirs(os.path.join(OUTDIR, "tiles32"), exist_ok=True)
os.makedirs(os.path.join(OUTDIR, "tiles256"), exist_ok=True)


def hexc(h, a=255):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a], dtype=np.uint8)


def pal(*hs):
    return [hexc(h) for h in hs]


def blank():
    return np.zeros((N, N, 4), dtype=np.uint8)


def mix(c, f):
    o = c.astype(float)
    o[:3] = np.clip(o[:3] * f, 0, 255)
    return o.astype(np.uint8)


def vnoise(rng, octaves=((4, 1.0), (8, 0.6), (16, 0.4), (32, 0.25))):
    out = np.zeros((N, N))
    for g, amp in octaves:
        grid = rng_grid(rng, g)
        fx = np.arange(N) * g / N
        x0 = fx.astype(int) % g
        x1 = (x0 + 1) % g
        tx = fx - fx.astype(int)
        tx = tx * tx * (3 - 2 * tx)
        for y in range(N):
            fy = y * g / N
            y0, y1 = int(fy) % g, (int(fy) + 1) % g
            ty = fy - int(fy)
            ty = ty * ty * (3 - 2 * ty)
            a = grid[y0, x0] * (1 - tx) + grid[y0, x1] * tx
            b = grid[y1, x0] * (1 - tx) + grid[y1, x1] * tx
            out[y] += amp * (a * (1 - ty) + b * ty)
    out -= out.min()
    return out / out.max()


def rng_grid(rng, g):
    return np.array([[rng.random() for _ in range(g)] for _ in range(g)])


def tone_map(n, tones, cuts):
    qs = np.quantile(n, cuts)
    idx = np.searchsorted(qs, n)
    img = blank()
    for y in range(N):
        for x in range(N):
            img[y, x] = tones[idx[y, x]]
    return img


DIRT = pal("5a3c27", "674530", "744f37", "82593e", "906446", "9d704f")
GRASS = pal("467f2e", "518d35", "5d9b3d", "69a945", "76b64e", "88c55e")
STONE = pal("66686c", "727478", "7e8084", "8a8c90", "96989c", "a4a7ab")
SAND = pal("c6b580", "d2c28b", "dccd97", "e4d6a2", "ebdfae", "f2e8c0")
LEAF = pal("2c5a20", "366a27", "417b2f", "4c8b37", "589a40", "6db04f")
BARK = pal("452f1a", "523921", "5f4227", "6c4c2e", "7a5735")
WOOD = pal("8f6437", "a07342", "b0834e", "bf925a", "cda166", "d9af74")


def t_dirt(rng):
    img = tone_map(vnoise(rng), DIRT, [0.08, 0.25, 0.48, 0.72, 0.92])
    kinds = [("a8876a", "8a6a4e", "4f3624"), ("9a9088", "7a706a", "4a403a"), ("b39374", "94755a", "5a4030")]
    for _ in range(9):  # varied pebbles: lit top, body, shadow
        l, m, d = (hexc(c) for c in rng.choice(kinds))
        w = rng.choice([1, 2, 2, 3])
        h = rng.choice([1, 2])
        x, y = rng.randrange(N - w), rng.randrange(N - h - 1)
        img[y:y + h, x:x + w] = m
        img[y, x] = l
        img[y + h, x:x + w] = d
    for _ in range(14):  # single grit pixels
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = DIRT[rng.choice([0, 5])]
    return img


def t_grass_top(rng):
    img = tone_map(vnoise(rng, ((4, 0.7), (8, 0.6), (16, 0.6), (32, 0.5))), GRASS, [0.08, 0.25, 0.5, 0.75, 0.93])
    for _ in range(34):  # blades: light tip over a dark root
        x, y = rng.randrange(N), rng.randrange(N - 3)
        img[y, x] = hexc("9ad86c")
        img[y + 1, x] = GRASS[4]
        img[y + 2, x] = GRASS[1]
    return img


def t_grass_side(rng):
    img = t_dirt(rng)
    g = t_grass_top(random.Random(rng.random()))
    depth = 6
    for x in range(N):
        depth = max(4, min(9, depth + rng.choice([-1, 0, 0, 0, 1])))
        d = depth + (rng.randrange(3, 7) if rng.random() < 0.14 else 0)
        img[:d, x] = g[:d, x]
        img[d - 1, x] = mix(g[d - 1, x], 0.8)
        img[d, x] = hexc("4a3220")
        if d + 1 < N:
            img[d + 1, x] = mix(img[d + 1, x], 0.85)
    return img


def t_stone(rng):
    img = tone_map(vnoise(rng, ((4, 1.0), (8, 0.7), (16, 0.4), (32, 0.2))), STONE, [0.06, 0.2, 0.45, 0.75, 0.94])
    for _ in range(7):  # small dark specks, 1-2 px
        x, y = rng.randrange(N - 1), rng.randrange(N)
        img[y, x] = STONE[0]
        if rng.random() < 0.5:
            img[y, x + 1] = STONE[1]
    return img


def t_sand(rng):
    img = tone_map(vnoise(rng, ((4, 0.6), (8, 0.5), (16, 0.6), (32, 0.6))), SAND, [0.06, 0.22, 0.5, 0.78, 0.95])
    for _ in range(18):
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = hexc("ae9c6b")
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


def t_gravel(rng):
    img = tone_map(vnoise(rng, ((8, 1.0), (16, 0.8), (32, 0.5))), pal("524d49", "5d5753", "68625d", "736c66"), [0.25, 0.5, 0.75])
    kinds = [("8f8983", "5e5854", "b8b0a8"), ("85725f", "584839", "ab957e"), ("7f8186", "53555a", "abadb2"), ("98928b", "68625d", "c4bcb3")]
    for _ in range(34):
        m, d, l = rng.choice(kinds)
        pebble(img, rng, rng.randrange(N), rng.randrange(N), rng.randrange(7, 16), hexc(m), hexc(d), hexc(l))
    return img


def t_log_side(rng):
    n = vnoise(rng, ((8, 1.0), (32, 0.4)))
    strips = []
    while len(strips) < N:
        w = rng.choice([2, 2, 3])
        t = rng.randrange(1, 4)
        strips += [t] * w
    img = blank()
    for x in range(N):
        for y in range(N):
            t = strips[x] + (1 if n[y, x] > 0.78 else 0) - (1 if n[y, x] < 0.18 else 0)
            img[y, x] = BARK[max(0, min(4, t))]
    for _ in range(11):  # grooves with a lit right edge
        x = rng.randrange(N)
        y0 = rng.randrange(N)
        ln = rng.randrange(6, 16)
        for y in range(y0, y0 + ln):
            img[y % N, x] = hexc("33200f")
            img[y % N, (x + 1) % N] = BARK[4]
            if rng.random() < 0.12:
                x = (x + rng.choice([-1, 1])) % N
    return img


def t_log_top(rng):
    n = vnoise(rng, ((4, 1.0), (8, 0.5), (16, 0.25)))
    c = (N - 1) / 2
    img = blank()
    for y in range(N):
        for x in range(N):
            edge = min(x, y, N - 1 - x, N - 1 - y)
            if edge <= 1:
                img[y, x] = BARK[(x * 3 + y) % 4]
            elif edge == 2:
                img[y, x] = BARK[0]
            elif edge == 3:
                img[y, x] = WOOD[0]
            else:
                r = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 + n[y, x] * 2.4
                band = int(r * 0.62) % 3
                img[y, x] = [WOOD[4], WOOD[3], WOOD[2]][band]
    img[14:18, 15:17] = WOOD[1]
    img[15:17, 14:18] = WOOD[1]
    return img


def t_planks(rng):
    img = blank()
    n = vnoise(rng, ((4, 1.0), (32, 0.5)))
    for b in range(4):
        y0 = b * 8
        tone = [2, 3, 1, 3][b]
        seam = rng.randrange(6, 26)
        for y in range(y0, y0 + 8):
            for x in range(N):
                t = tone + (1 if n[y, x] > 0.8 else 0) - (1 if n[y, x] < 0.15 else 0)
                img[y, x] = WOOD[max(0, min(5, t))]
        for _ in range(4):  # grain streaks
            gy = y0 + rng.randrange(2, 6)
            gx = rng.randrange(N)
            for i in range(rng.randrange(5, 12)):
                img[gy, (gx + i) % N] = WOOD[max(0, tone - 1)]
        if rng.random() < 0.6:  # a knot
            kx, ky = rng.randrange(3, N - 4), y0 + 3
            img[ky:ky + 2, kx:kx + 3] = WOOD[0]
            img[ky, kx + 1] = hexc("6b4a28")
        img[y0, :] = WOOD[min(5, tone + 2)]
        img[y0 + 1, :] = [mix(WOOD[min(5, tone + 1)], 1.0)] * N
        img[y0 + 6, :] = [mix(WOOD[tone], 0.9)] * N
        img[y0 + 7, :] = hexc("5f4224")
        img[y0:y0 + 7, seam] = hexc("6f4f2c")
        img[y0 + 1:y0 + 7, (seam + 1) % N] = WOOD[min(5, tone + 2)]
        img[y0 + 2, seam - 3:seam - 1] = hexc("4b3420")  # nail heads
        img[y0 + 2, (seam + 3) % N] = hexc("4b3420")
    return img


def t_leaves(rng):
    n = vnoise(rng, ((4, 0.6), (8, 0.8), (16, 0.7), (32, 0.4)))
    img = tone_map(n, LEAF, [0.12, 0.3, 0.52, 0.74, 0.92])
    holes = np.quantile(n, 0.09)
    for y in range(N):
        for x in range(N):
            if n[y, x] <= holes:
                img[y, x] = 0
    for _ in range(26):  # small lit leaf tips
        x, y = rng.randrange(N - 1), rng.randrange(N - 1)
        if img[y, x][3] and img[y + 1, x + 1][3]:
            img[y, x] = hexc("86c463")
            img[y + 1, x + 1] = LEAF[1]
    return img


def owner_map(seeds, weights):
    owner = np.zeros((N, N), dtype=int)
    for y in range(N):
        for x in range(N):
            best, bi = 1e9, 0
            for i, (sx, sy) in enumerate(seeds):
                dx = (x + 0.5 - sx + N / 2) % N - N / 2
                dy = (y + 0.5 - sy + N / 2) % N - N / 2
                dd = (dx * dx + dy * dy) / weights[i]
                if dd < best:
                    best, bi = dd, i
            owner[y, x] = bi
    return owner


def stones(owner, tones, n, mortar, mortar2, rim=2, pits=None, rng=None):
    O = lambda x, y: owner[y % N, x % N]
    img = blank()
    for y in range(N):
        for x in range(N):
            o = O(x, y)
            neigh = {O(x + 1, y), O(x, y + 1), O(x + 1, y + 1)}
            if O(x + 1, y) != o or O(x, y + 1) != o:
                img[y, x] = mortar
            elif len(neigh | {o}) > 2 or O(x + 2, y + 2) != o and (O(x + 2, y) != o and O(x, y + 2) != o):
                img[y, x] = mortar2
            elif O(x - 1, y) != o or O(x, y - 1) != o:
                img[y, x] = mix(tones[o], 1.26)
            elif rim > 1 and (O(x - 2, y) != o or O(x, y - 2) != o):
                img[y, x] = mix(tones[o], 1.12)
            elif O(x + 2, y) != o or O(x, y + 2) != o:
                img[y, x] = mix(tones[o], 0.78)
            elif rim > 1 and (O(x + 3, y) != o or O(x, y + 3) != o):
                img[y, x] = mix(tones[o], 0.88)
            else:
                img[y, x] = mix(tones[o], 1.0 + (n[y, x] - 0.5) * 0.18)
    if rng is not None:
        for _ in range(pits or 0):  # tiny pits in the stone faces
            x, y = rng.randrange(N), rng.randrange(N)
            if img[y, x][0] > 90:
                img[y, x] = mix(img[y, x], 0.75)
    return img


def t_cobble(rng):
    seeds = []
    for gy in range(4):
        for gx in range(4):
            seeds.append(((gx + 0.5 + (gy % 2) * 0.5) * 8 + rng.uniform(-2.4, 2.4),
                          (gy + 0.5) * 8 + rng.uniform(-2.2, 2.2)))
    seeds.append((rng.uniform(0, N), rng.uniform(0, N)))
    weights = [rng.uniform(0.75, 1.35) for _ in seeds]
    warm = [hexc("8a8781"), hexc("7d7b77"), hexc("96938d")]
    cool = [hexc("80848a"), hexc("8d9197"), hexc("737780")]
    tones = [rng.choice(warm + cool + [STONE[2], STONE[3]]) for _ in seeds]
    return stones(owner_map(seeds, weights), tones, vnoise(rng, ((8, 1.0), (16, 0.7), (32, 0.5))),
                  hexc("37383c"), hexc("47484d"), pits=26, rng=rng)


def t_stone_bricks(rng):
    owner = np.zeros((N, N), dtype=int)
    sid = 0
    for r in range(4):
        off = [0, 8, 3, 11][r]
        x = off
        while x < off + N:
            w = rng.choice([12, 14, 16])
            for yy in range(r * 8, r * 8 + 8):
                for xx in range(x, min(x + w, off + N)):
                    owner[yy, xx % N] = sid
            sid += 1
            x += w
    tones = [STONE[rng.choice([2, 3, 3, 4])] for _ in range(sid)]
    img = blank()
    n = vnoise(rng, ((8, 1.0), (32, 0.5)))
    O = lambda x, y: owner[y % N, x % N]
    for y in range(N):
        for x in range(N):
            o = O(x, y)
            if O(x + 1, y) != o or O(x, y + 1) != o:
                img[y, x] = hexc("3c3d41")
            elif O(x - 1, y) != o or O(x, y - 1) != o:
                img[y, x] = mix(tones[o], 1.22)
            elif O(x + 2, y) != o or O(x, y + 2) != o:
                img[y, x] = mix(tones[o], 0.8)
            else:
                img[y, x] = mix(tones[o], 1.0 + (n[y, x] - 0.5) * 0.16)
    for _ in range(4):  # a few chips
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = mix(img[y, x], 0.7)
    return img


def nugget(img, cx, cy, rx, ry, kind, tones, rng):
    dark, mid, light, glint = tones
    pts = {}
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if not (0 <= x < N and 0 <= y < N):
                continue
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if kind == "gem":
                inside = abs(dx) + abs(dy) <= 1.0
            elif kind == "lump":
                inside = 0.55 * max(abs(dx), abs(dy)) + 0.5 * (abs(dx) + abs(dy)) * 0.9 <= 0.92 + rng.uniform(-0.08, 0.08)
            else:
                inside = dx * dx + dy * dy <= 1.0 + rng.uniform(-0.12, 0.06)
            if inside:
                pts[(x, y)] = (dx, dy)
    for (x, y) in pts:  # drop shadow into the stone
        for sx, sy in ((x + 1, y + 1), (x + 1, y), (x, y + 1), (x + 2, y + 2)):
            if (sx, sy) not in pts and 0 <= sx < N and 0 <= sy < N:
                img[sy, sx] = mix(img[sy, sx], 0.7)
    best, bp = -9, None
    for (x, y), (dx, dy) in pts.items():
        if kind == "gem":
            if dx < 0 and dy < 0:
                c = light
            elif dx >= 0 and dy >= 0:
                c = dark
            elif dx >= 0:
                c = mid
            else:
                c = mix(mid, 0.88)
            if abs(dx) + abs(dy) > 0.78 and (dx > 0 or dy > 0):
                c = mix(dark, 0.85)
        else:
            lit = -(dx + dy) / 1.414
            edge = (x + 1, y) not in pts or (x, y + 1) not in pts
            c = light if lit > 0.3 else dark if lit < -0.35 else mid
            if edge and lit < 0.3:
                c = mix(dark, 0.9)
        img[y, x] = c
        score = -(dx + dy) - 0.6 * (dx * dx + dy * dy)
        if score > best:
            best, bp = score, (x, y)
    if bp:
        x, y = bp
        img[y, x] = glint
        if kind != "lump" and x + 1 < N and (x + 1, y) in pts:
            img[y, x + 1] = mix(glint, 0.92)


def ore(colors, layout, kind):
    tones = tuple(hexc(c) for c in colors)

    def make(rng):
        img = t_stone(rng)
        for (cx, cy, rx, ry) in layout:
            nugget(img, cx, cy, rx, ry, kind, tones, rng)
        return img
    return make


LAYOUT_A = [(6, 6, 3.2, 2.8), (9, 8.5, 2.2, 2.0), (23, 5, 2.6, 2.4), (16, 16, 3.0, 2.6), (7, 25, 2.6, 2.4),
            (25, 23, 3.2, 2.8), (22, 26, 2.0, 1.8)]
LAYOUT_GEM = [(7, 7, 4.2, 4.2), (24, 6, 2.8, 2.8), (18, 20, 3.6, 3.6), (6, 25, 2.6, 2.6), (27, 26, 2.2, 2.2)]

TEXTURES = [
    ("grass_top", "Grass (top)", t_grass_top),
    ("grass_side", "Grass (side)", t_grass_side),
    ("dirt", "Dirt", t_dirt),
    ("stone", "Stone", t_stone),
    ("cobble", "Cobble", t_cobble),
    ("stone_bricks", "Stone bricks", t_stone_bricks),
    ("gravel", "Gravel", t_gravel),
    ("sand", "Sand", t_sand),
    ("log_side", "Log (bark)", t_log_side),
    ("log_top", "Log (top)", t_log_top),
    ("planks", "Planks", t_planks),
    ("leaves", "Leaves", t_leaves),
    ("ore_coal", "Coal ore", ore(("141518", "2b2d31", "4c4f55", "80848c"), LAYOUT_A, "lump")),
    ("ore_iron", "Iron ore", ore(("8a5536", "c88a62", "e8b48e", "fff0e0"), LAYOUT_A, "nug")),
    ("ore_gold", "Gold ore", ore(("9a6a0e", "e6b222", "ffe165", "fffbe6"), LAYOUT_A, "nug")),
    ("ore_gem", "Gem ore", ore(("146c74", "2fbcc2", "8ef3ec", "ffffff"), LAYOUT_GEM, "gem")),
]

tex = {}
for i, (key, _, fn) in enumerate(TEXTURES):
    im = Image.fromarray(fn(random.Random(5000 + i)), "RGBA")
    tex[key] = im
    im.save(os.path.join(OUTDIR, "tiles32", key + ".png"))
    im.resize((256, 256), Image.NEAREST).save(os.path.join(OUTDIR, "tiles256", key + ".png"))

# Reuse the v1 renderer (cube, scene, sheet) at N=32.
src = open(os.path.join(HERE, "make_textures.py")).read()
render = src[src.index("# ---------- isometric cube rendering"):]
render = render.replace('"starter_blocks.png"', '"v3_32", "starter_blocks_32.png"')
render = render.replace('"starter_cubes.png"', '"v3_32", "starter_cubes_32.png"')
render = render.replace("Original 16x16 set, drawn from scratch. Shown at 8x.", "32x32 set, drawn from scratch. Shown at 4x.")
render = render.replace("for yy in range(0, cell, 16):", "for yy in range(0, cell, 16):")
g = dict(globals())
g["OUT"] = HERE
g["ImageDraw"] = __import__("PIL.ImageDraw", fromlist=["ImageDraw"])
g["ImageFont"] = __import__("PIL.ImageFont", fromlist=["ImageFont"])
exec(render, g)
