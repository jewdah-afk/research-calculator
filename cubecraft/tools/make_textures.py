"""Original 16x16 starter block textures for the voxel game, plus a preview sheet.

Every texture is generated here from our own palettes and patterns (seeded, so it is
reproducible). Nothing is copied or traced from another game's files.
"""
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(OUT, "tiles16")
BIG = os.path.join(OUT, "tiles256")
os.makedirs(TILES, exist_ok=True)
os.makedirs(BIG, exist_ok=True)

N = 16


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return tuple(max(0, min(255, int(round(v * f)))) for v in c[:3]) + (c[3],)


def blank():
    return np.zeros((N, N, 4), dtype=np.uint8)


def noise_fill(img, pal, rng, weights=None, clump=0.55):
    """Fill with palette noise that clumps into 2-3 px patches, so it reads as chunky pixel art."""
    k = len(pal)
    weights = weights or [1] * k
    idx = np.zeros((N, N), dtype=int)
    for y in range(N):
        for x in range(N):
            if x > 0 and rng.random() < clump * 0.5:
                idx[y, x] = idx[y, x - 1]
            elif y > 0 and rng.random() < clump * 0.5:
                idx[y, x] = idx[y - 1, x]
            else:
                idx[y, x] = rng.choices(range(k), weights)[0]
    for y in range(N):
        for x in range(N):
            img[y, x] = pal[idx[y, x]]
    return img


def blob(img, rng, cx, cy, cells, pal_dark, pal_mid, pal_light):
    """A small ore/pebble cluster: a solid body, a dark lower-right rim and one highlight."""
    pts = {(cx, cy)}
    while len(pts) < cells:
        x, y = rng.choice(sorted(pts))
        dx, dy = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        nx, ny = x + dx, y + dy
        if 0 <= nx < N and 0 <= ny < N:
            pts.add((nx, ny))
    for (x, y) in pts:
        img[y, x] = pal_mid
    for (x, y) in pts:
        if (x + 1, y) not in pts and (x, y + 1) not in pts:
            img[y, x] = pal_dark
        elif (x, y + 1) not in pts and rng.random() < 0.5:
            img[y, x] = pal_dark
    top = min(pts, key=lambda p: (p[1], p[0]))
    img[top[1], top[0]] = pal_light
    if len(pts) > 5:
        second = sorted(pts, key=lambda p: (p[1] + p[0]))[1]
        img[second[1], second[0]] = pal_light
    return pts


# ---------- palettes (our own) ----------
DIRT = [hexc("7d5538"), hexc("8c6142"), hexc("6c482f"), hexc("9b6e4a")]
GRASS = [hexc("5a9a3c"), hexc("6aab45"), hexc("4f8a34"), hexc("7bbd52")]
STONE = [hexc("888a8d"), hexc("7a7c80"), hexc("94969a"), hexc("6d6f73")]
SAND = [hexc("dccd98"), hexc("e6d8a5"), hexc("cfbf88"), hexc("eadfb4")]
BARK = [hexc("6a4a2c"), hexc("5a3d23"), hexc("7b5835")]
WOOD = [hexc("b88a52"), hexc("a77b47"), hexc("c79a60")]
LEAF = [hexc("3f7a2e"), hexc("4b8c35"), hexc("356a27"), hexc("5aa03e")]


def t_dirt(rng):
    img = noise_fill(blank(), DIRT, rng, [4, 3, 2, 1])
    for _ in range(4):
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = hexc("a98060")
    return img


def t_grass_top(rng):
    img = noise_fill(blank(), GRASS, rng, [4, 3, 2, 1])
    for _ in range(10):
        x, y = rng.randrange(N), rng.randrange(N - 1)
        img[y, x] = hexc("8fd060")
        img[y + 1, x] = hexc("4f8a34")
    return img


def t_grass_side(rng):
    img = t_dirt(rng)
    g = t_grass_top(random.Random(rng.random()))
    for x in range(N):
        depth = 3 + rng.choice([0, 0, 1, 1, 2])
        img[:depth, x] = g[:depth, x]
        img[depth, x] = hexc("3f6f2a")  # dark lip where grass meets dirt
    return img


def t_stone(rng):
    img = noise_fill(blank(), STONE, rng, [4, 3, 2, 2], clump=0.7)
    for _ in range(3):  # short hairline cracks
        x, y = rng.randrange(1, N - 4), rng.randrange(1, N - 2)
        for i in range(rng.randrange(2, 5)):
            img[y, min(N - 1, x + i)] = hexc("5c5e62")
            if rng.random() < 0.4:
                y = min(N - 1, y + 1)
    return img


def t_cobble(rng):
    # Voronoi cells = rounded stones, with dark mortar lines and a lit upper-left edge.
    seeds = [(rng.uniform(0, N), rng.uniform(0, N)) for _ in range(9)]
    tones = [rng.choice(STONE[:3]) for _ in seeds]
    img = blank()
    owner = np.zeros((N, N), dtype=int)
    for y in range(N):
        for x in range(N):
            d = [min(abs(x - sx), N - abs(x - sx)) ** 2 + min(abs(y - sy), N - abs(y - sy)) ** 2 for sx, sy in seeds]
            owner[y, x] = int(np.argmin(d))
    for y in range(N):
        for x in range(N):
            o = owner[y, x]
            r, d = owner[y, (x + 1) % N], owner[(y + 1) % N, x]
            l, u = owner[y, (x - 1) % N], owner[(y - 1) % N, x]
            if r != o or d != o:
                img[y, x] = hexc("4e5054")
            elif l != o or u != o:
                img[y, x] = shade(tones[o], 1.18)
            else:
                img[y, x] = tones[o]
    return img


def t_log_side(rng):
    img = blank()
    for x in range(N):
        col = BARK[x % 3 if rng.random() < 0.7 else rng.randrange(3)]
        for y in range(N):
            img[y, x] = col
    for _ in range(5):  # vertical grooves
        x = rng.randrange(N)
        y0 = rng.randrange(N)
        for y in range(y0, min(N, y0 + rng.randrange(3, 8))):
            img[y, x] = hexc("402a17")
    return img


def t_log_top(rng):
    img = blank()
    c = (N - 1) / 2
    for y in range(N):
        for x in range(N):
            r = max(abs(x - c), abs(y - c))  # square rings suit the pixel grid
            if r > 6.6:
                img[y, x] = BARK[(x + y) % 3]
            else:
                ring = int(r + rng.random() * 0.4)
                img[y, x] = WOOD[2] if ring % 2 == 0 else WOOD[1]
    img[7:9, 7:9] = hexc("8e683a")
    return img


def t_planks(rng):
    img = blank()
    for b in range(4):
        tone = WOOD[b % 3]
        seam = rng.randrange(3, 13)
        for y in range(b * 4, b * 4 + 4):
            for x in range(N):
                img[y, x] = shade(tone, 1 + rng.uniform(-0.05, 0.05))
        img[b * 4 + 3, :] = hexc("6f4f2a")  # gap under each board
        img[b * 4: b * 4 + 3, seam] = hexc("7f5c33")  # board end
        img[b * 4, :] = shade(tone, 1.12)  # lit top edge
        for _ in range(2):  # grain
            gx = rng.randrange(N - 3)
            gy = b * 4 + rng.randrange(1, 3)
            img[gy, gx:gx + 3] = shade(tone, 0.88)
    return img


def t_leaves(rng):
    img = noise_fill(blank(), LEAF, rng, [3, 3, 2, 1], clump=0.4)
    for _ in range(26):  # see-through gaps
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = (0, 0, 0, 0)
    for _ in range(6):
        x, y = rng.randrange(N), rng.randrange(N)
        if img[y, x][3]:
            img[y, x] = hexc("74b850")
    return img


def t_sand(rng):
    img = noise_fill(blank(), SAND, rng, [4, 3, 2, 1], clump=0.3)
    for _ in range(5):
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = hexc("b9a874")
    return img


def t_gravel(rng):
    img = noise_fill(blank(), [hexc("7d7772"), hexc("6e6863")], rng, clump=0.3)
    tones = [(hexc("5a5450"), hexc("98918a"), hexc("bab2a8")),
             (hexc("5b4d42"), hexc("8a7766"), hexc("a8927e")),
             (hexc("4f5156"), hexc("85878c"), hexc("a9abb0"))]
    for _ in range(9):
        d, m, l = rng.choice(tones)
        blob(img, rng, rng.randrange(N), rng.randrange(N), rng.randrange(3, 6), d, m, l)
    return img


def ore(dark, mid, light, clusters=4, size=(6, 10)):
    def make(rng):
        img = t_stone(rng)
        spots = [(3, 3), (11, 4), (5, 11), (12, 12), (8, 7)]
        rng.shuffle(spots)
        for cx, cy in spots[:clusters]:
            blob(img, rng, cx + rng.randrange(-1, 2), cy + rng.randrange(-1, 2), rng.randrange(*size),
                 hexc(dark), hexc(mid), hexc(light))
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
    ("ore_coal", "Coal ore", ore("1e1f22", "34363a", "55585e", clusters=5)),
    ("ore_iron", "Iron ore", ore("8a5a3c", "c98d68", "f0c4a2")),
    ("ore_gold", "Gold ore", ore("a8781a", "e8bb2e", "fff09a")),
    ("ore_gem", "Gem ore", ore("1d7f86", "3fc9c9", "c8fff6", clusters=3, size=(5, 9))),
]

tex = {}
for i, (key, _, fn) in enumerate(TEXTURES):
    arr = fn(random.Random(1000 + i))
    im = Image.fromarray(arr, "RGBA")
    tex[key] = im
    im.save(os.path.join(TILES, key + ".png"))
    im.resize((256, 256), Image.NEAREST).save(os.path.join(BIG, key + ".png"))


# ---------- isometric cube rendering ----------
def face(canvas, texim, O, A, B, f):
    t = np.asarray(texim).astype(float)
    t[..., :3] *= f
    t = np.clip(t, 0, 255).astype(np.uint8)
    H, W = canvas.shape[:2]
    xs = np.arange(W) + 0.5
    ys = np.arange(H) + 0.5
    X, Y = np.meshgrid(xs, ys)
    M = np.array([[A[0], B[0]], [A[1], B[1]]], dtype=float)
    inv = np.linalg.inv(M)
    px, py = X - O[0], Y - O[1]
    u = inv[0, 0] * px + inv[0, 1] * py
    v = inv[1, 0] * px + inv[1, 1] * py
    m = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    ui = np.clip((u * N).astype(int), 0, N - 1)
    vi = np.clip((v * N).astype(int), 0, N - 1)
    src = t[vi, ui]
    m = m & (src[..., 3] > 0)
    canvas[m] = src[m]


def cube(top, side, s):
    c = np.zeros((2 * s, 2 * s, 4), dtype=np.uint8)
    h = s / 2
    face(c, tex[top], (0, h), (s, -h), (s, h), 1.0)
    face(c, tex[side], (0, h), (s, h), (0, s), 0.80)
    face(c, tex[side], (s, s), (s, -h), (0, s), 0.62)
    return Image.fromarray(c, "RGBA")


def font(sz, bold=True):
    p = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    return ImageFont.truetype(p, sz)


BG = (22, 24, 30, 255)
INK = (236, 238, 242, 255)
MUTED = (150, 156, 168, 255)

# ---------- mini world scene ----------
def scene():
    s = 40
    rng = random.Random(7)
    W, D = 9, 9
    heights = [[0] * D for _ in range(W)]
    for x in range(W):
        for y in range(D):
            heights[x][y] = 2 + (1 if x + y > 7 else 0) + (1 if x > 5 and y < 4 else 0) + (1 if x > 6 and y < 2 else 0)
    blocks = {}
    for x in range(W):
        for y in range(D):
            h = heights[x][y]
            for z in range(h):
                if z == h - 1:
                    blocks[(x, y, z)] = ("grass_top", "grass_side") if not (x < 3 and y > 5) else ("sand", "sand")
                elif z == h - 2:
                    blocks[(x, y, z)] = ("dirt", "dirt") if not (x < 3 and y > 5) else ("sand", "sand")
                else:
                    pick = rng.random()
                    o = "stone"
                    if pick < 0.08:
                        o = "ore_coal"
                    elif pick < 0.13:
                        o = "ore_iron"
                    elif pick < 0.16:
                        o = "ore_gold"
                    elif pick < 0.18:
                        o = "ore_gem"
                    blocks[(x, y, z)] = (o, o)
    # make the exposed front faces show some ore
    blocks[(8, 3, 0)] = ("ore_gem", "ore_gem")
    blocks[(5, 8, 0)] = ("ore_gold", "ore_gold")
    blocks[(8, 6, 1)] = ("ore_iron", "ore_iron")
    blocks[(2, 8, 0)] = ("ore_coal", "ore_coal")
    # a tree
    tx, ty = 3, 3
    base = heights[tx][ty]
    for z in range(base, base + 4):
        blocks[(tx, ty, z)] = ("log_top", "log_side")
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for z in (base + 3, base + 4):
                if (dx, dy) != (0, 0) or z == base + 4:
                    blocks[(tx + dx, ty + dy, z)] = ("leaves", "leaves")
    # a little plank hut corner and cobble path
    for z in range(heights[6][6], heights[6][6] + 2):
        blocks[(6, 6, z)] = ("planks", "planks")
        blocks[(6, 7, z)] = ("planks", "planks")
    blocks[(7, 6, heights[7][6])] = ("cobble", "cobble")
    blocks[(5, 4, heights[5][4])] = ("gravel", "gravel")

    cache = {}
    Wc, Hc = 2 * s * (W + D) // 2 + 2 * s, s * (W + D) // 2 + s * 9
    canvas = Image.new("RGBA", (Wc, Hc), (0, 0, 0, 0))
    ox, oy = s * D, s * 6
    for (x, y, z) in sorted(blocks, key=lambda p: (p[0] + p[1], p[2], p[0])):
        key = blocks[(x, y, z)]
        if key not in cache:
            cache[key] = cube(key[0], key[1], s)
        sx = ox + (x - y) * s - s
        sy = oy + (x + y) * s // 2 - z * s
        canvas.alpha_composite(cache[key], (sx, sy))
    return canvas.crop(canvas.getbbox())


# ---------- sheet ----------
cell, gap, pad = 128, 36, 56
cols = 5
rows = (len(TEXTURES) + cols - 1) // cols
world = scene()
grid_w = cols * cell + (cols - 1) * gap
sheet_w = pad * 2 + grid_w + 60 + world.width
grid_h = rows * (cell + 34) + (rows - 1) * 18
sheet_h = max(pad * 2 + 90 + grid_h, pad * 2 + 90 + world.height)
sheet = Image.new("RGBA", (sheet_w, sheet_h), BG)
d = ImageDraw.Draw(sheet)
d.text((pad, pad - 6), "Starter blocks", font=font(40), fill=INK)
d.text((pad, pad + 44), "Original 16x16 set, drawn from scratch. Shown at 8x.", font=font(18, False), fill=MUTED)

for i, (key, label, _) in enumerate(TEXTURES):
    r, c = divmod(i, cols)
    x = pad + c * (cell + gap)
    y = pad + 90 + r * (cell + 34 + 18)
    if key == "leaves":  # checker behind so the gaps read as see-through
        for yy in range(0, cell, 16):
            for xx in range(0, cell, 16):
                col = (60, 64, 72, 255) if (xx // 16 + yy // 16) % 2 else (44, 47, 54, 255)
                d.rectangle([x + xx, y + yy, x + xx + 15, y + yy + 15], fill=col)
    sheet.alpha_composite(tex[key].resize((cell, cell), Image.NEAREST), (x, y))
    d.text((x, y + cell + 8), label, font=font(17), fill=INK)

wx = pad + grid_w + 60
wy = pad + 90 + max(0, (grid_h - world.height) // 2)
sheet.alpha_composite(world, (wx, wy))
sheet.convert("RGB").save(os.path.join(OUT, "starter_blocks.png"))

# separate big cube lineup
s = 96
keys = [("grass_top", "grass_side"), ("log_top", "log_side"), ("planks", "planks"), ("cobble", "cobble"),
        ("ore_gold", "ore_gold"), ("ore_gem", "ore_gem")]
line = Image.new("RGBA", (pad * 2 + len(keys) * (2 * s) + (len(keys) - 1) * 40, 2 * s + pad * 2), BG)
for i, (t, sd) in enumerate(keys):
    line.alpha_composite(cube(t, sd, s), (pad + i * (2 * s + 40), pad))
line.convert("RGB").save(os.path.join(OUT, "starter_cubes.png"))
print("ok")
