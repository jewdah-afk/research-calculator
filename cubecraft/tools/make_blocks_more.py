"""Builds the full 32x32 block set: the 16 starter blocks (from make_textures_32.py, same seeds)
plus new blocks for biomes, building and plants. Writes tiles and a texture atlas."""
import os
import json
import random
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "make_textures_32.py")).read()
head = src.split("\ntex = {}")[0]
g = {"__file__": os.path.join(HERE, "make_textures_32.py"), "__name__": "blocks32"}
exec(head, g)
N = g["N"]
hexc, pal, blank, mix, vnoise, tone_map = g["hexc"], g["pal"], g["blank"], g["mix"], g["vnoise"], g["tone_map"]
STONE, SAND, DIRT, WOOD = g["STONE"], g["SAND"], g["DIRT"], g["WOOD"]



# ---------- smoothing: calm the fine pixel contrast, keep the big colour patches ----------
def smooth_arr(a, k, r=2):
    """Pull each pixel toward its local (tileable) average: c' = mean + (c - mean) * k.
    Transparent pixels are ignored, so leaves and plants keep their edges."""
    rgb = a[..., :3].astype(float)
    alpha = (a[..., 3] > 0).astype(float)
    acc = np.zeros_like(rgb)
    wsum = np.zeros(alpha.shape)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            acc += np.roll(np.roll(rgb * alpha[..., None], dy, 0), dx, 1)
            wsum += np.roll(np.roll(alpha, dy, 0), dx, 1)
    mean = acc / np.maximum(wsum, 1e-6)[..., None]
    out = a.copy()
    out[..., :3] = np.clip(mean + (rgb - mean) * k, 0, 255).astype(np.uint8)
    out[a[..., 3] == 0] = a[a[..., 3] == 0]
    return out


def smoothed(fn, k):
    def wrapped(rng):
        return smooth_arr(fn(rng), k)
    wrapped.__name__ = fn.__name__
    return wrapped




# ---------- crisp natural blocks: a flat base tone plus small clusters of close tones ----------
# This is what keeps a wall of stone looking like one continuous rock: few tones, close together,
# crisp pixels, no soft blobs that repeat on a grid. Every pattern wraps, so blocks join seamlessly.
def crisp(rng, base, dark, light, darker, lighter, n=(20, 14, 8, 4), size=(2, 8), horiz=False):
    img = np.empty((N, N, 4), dtype=np.uint8)
    img[:] = hexc(base)

    def cluster(col, lo, hi):
        x, y = rng.randrange(N), rng.randrange(N)
        for _ in range(rng.randrange(lo, hi)):
            img[y % N, x % N] = col
            if horiz:
                x += 1 if rng.random() < 0.88 else 0
                if rng.random() < 0.12:
                    y += rng.choice((-1, 1))
            else:
                d = rng.randrange(4)
                x += (1, -1, 0, 0)[d]
                y += (0, 0, 1, -1)[d]

    for _ in range(n[1]):
        cluster(hexc(light), *size)
    for _ in range(n[0]):
        cluster(hexc(dark), *size)
    for _ in range(n[2]):
        cluster(hexc(darker), 1, 4)
    for _ in range(n[3]):
        cluster(hexc(lighter), 1, 3)
    return img


STONE_SEED, SLATE_SEED = 7001, 7002


def c_stone(rng=None):
    # fixed seed: the plain stone block and every stone ore share exactly this base
    return crisp(random.Random(STONE_SEED), "85888c", "797c80", "909397", "6a6d71", "9c9fa3",
                 n=(24, 16, 9, 5), size=(2, 9))


def c_slate(rng=None):
    return crisp(random.Random(SLATE_SEED), "5a5c65", "50525b", "64666f", "45474f", "6f717a",
                 n=(28, 18, 12, 4), size=(3, 11), horiz=True)


def c_dirt(rng):
    return crisp(rng, "7a5538", "6c4b31", "876041", "5b3f29", "987052", n=(22, 14, 9, 6), size=(2, 7))


def c_grass_top(rng):
    return crisp(rng, "62a13f", "589537", "6cae48", "4d8930", "7cbc55", n=(24, 18, 8, 12), size=(2, 6))


def c_sand(rng):
    return crisp(rng, "dbcc97", "d1c18b", "e4d6a5", "c3b27b", "eee3b8", n=(20, 14, 9, 6), size=(2, 6))


g["t_stone"], g["t_dirt"], g["t_grass_top"], g["t_sand"] = c_stone, c_dirt, c_grass_top, c_sand


def ore_on(base_fn, colors, layout, kind):
    tones = tuple(hexc(c) for c in colors)

    def make(rng):
        img = base_fn().copy()
        for (cx, cy, rx, ry) in layout:
            g["nugget"](img, cx, cy, rx, ry, kind, tones, rng)
        return img
    return make


ORES = {
    "coal": (("141518", "2b2d31", "4c4f55", "80848c"), "LAYOUT_A", "lump"),
    "iron": (("8a5536", "c88a62", "e8b48e", "fff0e0"), "LAYOUT_A", "nug"),
    "gold": (("9a6a0e", "e6b222", "ffe165", "fffbe6"), "LAYOUT_A", "nug"),
    "gem": (("146c74", "2fbcc2", "8ef3ec", "ffffff"), "LAYOUT_GEM", "gem"),
}

SMOOTH_K = {"t_gravel": 0.62,
            "t_leaves": 0.55, "t_log_side": 0.72, "t_log_top": 0.8, "t_planks": 0.8, "t_cobble": 0.82,
            "t_stone_bricks": 0.85}
for _name, _k in SMOOTH_K.items():
    g[_name] = smoothed(g[_name], _k)
# rebuild the starter list so it points at the smoothed versions (ores and grass_side pick up the
# smoothed stone / dirt / grass automatically, since they look those up at call time)
_swap = {"t_stone": c_stone, "t_dirt": c_dirt, "t_grass_top": c_grass_top, "t_sand": c_sand}
_rebuilt = []
for (k, l, f) in g["TEXTURES"]:
    if k.startswith("ore_"):
        cols_, lay, kind_ = ORES[k[4:]]
        f = ore_on(c_stone, cols_, g[lay], kind_)
    elif f.__name__ in _swap:
        f = _swap[f.__name__]
    elif f.__name__ in SMOOTH_K:
        f = g[f.__name__]
    _rebuilt.append((k, l, f))
g["TEXTURES"] = _rebuilt

OUT = os.path.join(HERE, "world")
os.makedirs(os.path.join(OUT, "tiles32"), exist_ok=True)

SNOW = pal("c9d6e0", "d6e1ea", "e2eaf1", "ecf2f7", "f5f8fb", "ffffff")
WATER = pal("1f4f8f", "245a9c", "2a65a8", "3171b3", "3a7ebf", "4f93cf")
CLAY = pal("8f96a3", "99a0ad", "a2a9b6", "abb2bf", "b5bcc8")
SLATE = pal("3c3d44", "45464e", "4e4f58", "585a63", "63656e")
BIRCH = pal("d9d3c4", "e3ddcf", "ece7da", "f4f0e6")
SPRUCE_BARK = pal("3b2614", "47301a", "533920", "5f4226", "6b4b2c")
CACTUS = pal("2f6b2a", "377a31", "3f8838", "489640", "56a64c")
BRICK = pal("8a3b2c", "9b4433", "a94d3a", "b85a45", "c66a52")


def t_snow(rng):
    img = tone_map(vnoise(rng, ((4, 0.6), (8, 0.5), (16, 0.4), (32, 0.3))), SNOW, [0.06, 0.2, 0.45, 0.72, 0.94])
    for _ in range(10):
        x, y = rng.randrange(N), rng.randrange(N)
        img[y, x] = hexc("ffffff")
    return img


def t_snow_side(rng):
    img = g["t_dirt"](rng)
    s = t_snow(random.Random(rng.random()))
    depth = 7
    for x in range(N):
        depth = max(5, min(10, depth + rng.choice([-1, 0, 0, 1])))
        d = depth + (rng.randrange(2, 5) if rng.random() < 0.12 else 0)
        img[:d, x] = s[:d, x]
        img[d - 1, x] = mix(s[d - 1, x], 0.86)
        img[d, x] = hexc("4a3220")
    return img


def t_water(rng):
    img = tone_map(vnoise(rng, ((4, 0.8), (8, 0.7), (16, 0.4))), WATER, [0.08, 0.25, 0.5, 0.75, 0.92])
    for _ in range(9):  # ripple highlights
        x, y = rng.randrange(N - 6), rng.randrange(N)
        ln = rng.randrange(3, 7)
        img[y, x:x + ln] = hexc("7fb6e6")
        img[(y + 1) % N, x + 1:x + ln - 1] = WATER[1]
    return img


def t_clay(rng):
    return tone_map(vnoise(rng, ((4, 1.0), (8, 0.5), (32, 0.25))), CLAY, [0.12, 0.38, 0.66, 0.9])


def t_slate(rng):
    img = tone_map(vnoise(rng, ((4, 0.7), (8, 0.6), (32, 0.6))), SLATE, [0.1, 0.32, 0.64, 0.9])
    for y in range(3, N, 7):  # faint layering
        off = rng.randrange(N)
        for i in range(rng.randrange(8, 18)):
            img[y, (off + i) % N] = SLATE[0]
    return img


def t_birch_side(rng):
    n = vnoise(rng, ((8, 1.0), (32, 0.4)))
    img = tone_map(n, BIRCH, [0.15, 0.5, 0.85])
    for _ in range(16):  # dark horizontal marks
        x, y = rng.randrange(N - 6), rng.randrange(N)
        ln = rng.randrange(2, 7)
        img[y, x:x + ln] = hexc("2e2a26")
        if rng.random() < 0.5 and y + 1 < N:
            img[y + 1, x + 1:x + ln - 1] = hexc("5a544d")
    return img


def t_birch_top(rng):
    img = g["t_log_top"](rng)
    pale = pal("c9b48a", "d6c39a", "e0cfa8", "e9dab6", "f0e3c2", "f6ecd0")
    src_w = WOOD
    for y in range(N):
        for x in range(N):
            c = img[y, x]
            for i, w in enumerate(src_w):
                if (c[:3] == w[:3]).all():
                    img[y, x] = pale[i]
    edge = lambda x, y: min(x, y, N - 1 - x, N - 1 - y)
    for y in range(N):
        for x in range(N):
            if edge(x, y) <= 2:
                img[y, x] = BIRCH[(x + y) % 4] if (x * 7 + y * 3) % 9 else hexc("2e2a26")
    return img


def leaves_like(tones):
    def make(rng):
        n = vnoise(rng, ((4, 0.6), (8, 0.8), (16, 0.7), (32, 0.4)))
        img = tone_map(n, tones, [0.12, 0.3, 0.52, 0.74, 0.92])
        holes = np.quantile(n, 0.09)
        img[n <= holes] = 0
        for _ in range(24):
            x, y = rng.randrange(N - 1), rng.randrange(N - 1)
            if img[y, x][3] and img[y + 1, x + 1][3]:
                img[y, x] = mix(tones[5], 1.15)
                img[y + 1, x + 1] = tones[1]
        return img
    return make


def t_spruce_side(rng):
    n = vnoise(rng, ((8, 1.0), (32, 0.4)))
    img = blank()
    strips = []
    while len(strips) < N:
        strips += [rng.randrange(1, 4)] * rng.choice([2, 3])
    for x in range(N):
        for y in range(N):
            t = strips[x] + (1 if n[y, x] > 0.78 else 0) - (1 if n[y, x] < 0.2 else 0)
            img[y, x] = SPRUCE_BARK[max(0, min(4, t))]
    for _ in range(14):  # flaky plates
        x, y = rng.randrange(N - 3), rng.randrange(N - 2)
        img[y, x:x + 3] = SPRUCE_BARK[4]
        img[y + 1, x:x + 3] = SPRUCE_BARK[0]
    return img


def t_spruce_top(rng):
    img = g["t_log_top"](rng)
    dark = pal("6e4c2a", "7c5732", "8a633b", "976e43", "a4794b", "b0844f")
    for y in range(N):
        for x in range(N):
            c = img[y, x]
            for i, w in enumerate(WOOD):
                if (c[:3] == w[:3]).all():
                    img[y, x] = dark[i]
            for i, b in enumerate(g["BARK"]):
                if (c[:3] == b[:3]).all():
                    img[y, x] = SPRUCE_BARK[i]
    return img


def t_cactus_side(rng):
    img = tone_map(vnoise(rng, ((8, 1.0), (32, 0.4))), CACTUS, [0.15, 0.4, 0.7, 0.92])
    for x in range(N):
        if x % 8 in (0, 7):
            img[:, x] = CACTUS[0]
        elif x % 8 in (1,):
            img[:, x] = [mix(c, 1.0) for c in [CACTUS[4]] * N]
    for y in range(2, N, 5):  # spines
        for x in range(3 + (y // 5) % 2 * 4, N, 8):
            img[y, x] = hexc("f1ecd2")
            img[y, (x + 1) % N] = hexc("1e4a1b")
    return img


def t_cactus_top(rng):
    img = tone_map(vnoise(rng, ((8, 1.0), (32, 0.4))), CACTUS, [0.15, 0.4, 0.7, 0.92])
    c = (N - 1) / 2
    for y in range(N):
        for x in range(N):
            r = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if r > 14:
                img[y, x] = CACTUS[0]
            elif int(r) % 5 == 0:
                img[y, x] = CACTUS[1]
    img[15:17, 15:17] = hexc("f1ecd2")
    return img


def t_sandstone_side(rng):
    img = tone_map(vnoise(rng, ((4, 0.6), (32, 0.6))), SAND, [0.1, 0.3, 0.6, 0.85, 0.96])
    for y in range(N):
        band = (y // 4) % 3
        for x in range(N):
            img[y, x] = mix(img[y, x], [0.95, 0.9, 1.0][band])
    for y in (7, 15, 23, 31):
        img[y, :] = mix(SAND[0], 0.85)
        if y - 1 >= 0:
            img[y - 1, :] = [mix(c, 0.95) for c in img[y - 1, :]]
    img[0:2, :] = SAND[4]
    return img


def t_sandstone_top(rng):
    img = tone_map(vnoise(rng, ((4, 0.6), (8, 0.5), (32, 0.4))), SAND, [0.1, 0.3, 0.6, 0.85, 0.96])
    img[0, :] = SAND[0]
    img[:, 0] = SAND[0]
    img[N - 1, :] = mix(SAND[0], 0.85)
    img[:, N - 1] = mix(SAND[0], 0.85)
    return img


def t_bricks(rng):
    img = blank()
    n = vnoise(rng, ((8, 1.0), (32, 0.6)))
    for r in range(4):
        off = 0 if r % 2 == 0 else 8
        y0 = r * 8
        for b in range(-1, 3):
            x0 = off + b * 16
            tone = BRICK[rng.randrange(1, 5)]
            for y in range(y0, y0 + 8):
                for x in range(x0, x0 + 16):
                    xx = x % N
                    if y == y0 + 7 or x == x0 + 15:
                        img[y, xx] = hexc("c9bfb1")  # mortar
                    elif y == y0 + 6 or x == x0 + 14:
                        img[y, xx] = mix(tone, 0.78)
                    elif y == y0 or x == x0:
                        img[y, xx] = mix(tone, 1.15)
                    else:
                        img[y, xx] = mix(tone, 1.0 + (n[y, xx] - 0.5) * 0.2)
    return img


def t_glass(rng):
    img = np.zeros((N, N, 4), dtype=np.uint8)
    img[..., :3] = (210, 235, 245)
    img[..., 3] = 38
    frame = hexc("dbe8ee")
    img[0, :] = frame
    img[:, 0] = frame
    img[N - 1, :] = hexc("9fb3bd")
    img[:, N - 1] = hexc("9fb3bd")
    for i in range(6):  # glints
        for k in range(3):
            x, y = 6 + i + k * 1, 6 + i
            if x < N and y < N:
                img[y, x] = (255, 255, 255, 170)
    for i in range(3):
        img[20 + i, 20 + i:23 + i] = (255, 255, 255, 140)
    return img


def t_tall_grass(rng):
    img = np.zeros((N, N, 4), dtype=np.uint8)
    for _ in range(11):
        x = rng.randrange(2, N - 2)
        h = rng.randrange(10, 26)
        lean = rng.choice([-1, 0, 1])
        for i in range(h):
            yy = N - 1 - i
            xx = x + (lean * i) // 9
            if 0 <= xx < N:
                t = i / h
                img[yy, xx] = hexc("4b8b33") if t < 0.4 else hexc("63a843") if t < 0.85 else hexc("8fcf62")
    return img


def flower(petal, petal_dark, center):
    def make(rng):
        img = np.zeros((N, N, 4), dtype=np.uint8)
        cx = 15
        for y in range(14, N):  # stem
            img[y, cx] = hexc("3f7d2b")
        img[22, cx + 1:cx + 4] = hexc("4f9535")  # leaf
        img[23, cx + 2:cx + 5] = hexc("3f7d2b")
        img[25, cx - 3:cx] = hexc("4f9535")
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                if dx * dx + dy * dy <= 16 and not (dx * dx + dy * dy <= 2):
                    c = petal if dx + dy < 2 else petal_dark
                    img[11 + dy, cx + dx] = c
        img[10:13, cx - 1:cx + 2] = center
        img[10, cx - 1] = mix(center, 1.2)
        return img
    return make


t_snow = lambda rng: crisp(rng, "edf2f6", "e1e8ee", "f6f9fb", "d3dce4", "ffffff", n=(18, 12, 5, 6), size=(2, 7))
t_water = smoothed(t_water, 0.6)
t_clay = lambda rng: crisp(rng, "a2a9b5", "979ea9", "acb3bf", "8b929e", "b7bec9", n=(16, 12, 5, 3), size=(2, 8))
t_slate = c_slate
t_birch_side = smoothed(t_birch_side, 0.82)
t_spruce_side = smoothed(t_spruce_side, 0.72)
t_cactus_side = smoothed(t_cactus_side, 0.82)
_leaves_like = leaves_like
leaves_like = lambda tones: smoothed(_leaves_like(tones), 0.55)

NEW = [
    ("snow", "Snow", t_snow),
    ("snow_side", "Snowy grass (side)", t_snow_side),
    ("water", "Water", t_water),
    ("clay", "Clay", t_clay),
    ("slate", "Slate", t_slate),
    ("birch_side", "Birch log", t_birch_side),
    ("birch_top", "Birch log (top)", t_birch_top),
    ("birch_leaves", "Birch leaves", leaves_like(pal("4f7f2c", "5c8f33", "6a9e3b", "78ad44", "87bb4f", "9cc95e"))),
    ("spruce_side", "Spruce log", t_spruce_side),
    ("spruce_top", "Spruce log (top)", t_spruce_top),
    ("spruce_leaves", "Spruce needles", leaves_like(pal("1f3f2b", "264a32", "2d5539", "356141", "3d6d49", "4a7d55"))),
    ("cactus_side", "Cactus", t_cactus_side),
    ("cactus_top", "Cactus (top)", t_cactus_top),
    ("sandstone_side", "Sandstone", t_sandstone_side),
    ("sandstone_top", "Sandstone (top)", t_sandstone_top),
    ("bricks", "Bricks", t_bricks),
    ("glass", "Glass", t_glass),
    ("tall_grass", "Tall grass", t_tall_grass),
    ("flower_red", "Red flower", flower(hexc("e0413a"), hexc("a82a26"), hexc("2b2216"))),
    ("flower_yellow", "Yellow flower", flower(hexc("ffd23a"), hexc("d9a51c"), hexc("c9781a"))),
    ("lava", "Lava", lambda rng: crisp(rng, "e2560e", "c9450b", "f37a1c", "a8320a", "ffc83c", n=(22, 24, 10, 16), size=(3, 11))),
    ("ash", "Ash", lambda rng: crisp(rng, "5e5a5a", "534f4f", "6a6666", "474343", "777373", n=(22, 16, 8, 6), size=(2, 8))),
    ("ore_coal_slate", "Deep coal ore", ore_on(c_slate, ("101114", "26282c", "5a5d64", "8c9098"), g["LAYOUT_A"], "lump")),
    ("ore_iron_slate", "Deep iron ore", ore_on(c_slate, *ORES["iron"][:1], g["LAYOUT_A"], "nug")),
    ("ore_gold_slate", "Deep gold ore", ore_on(c_slate, *ORES["gold"][:1], g["LAYOUT_A"], "nug")),
    ("ore_gem_slate", "Deep gem ore", ore_on(c_slate, *ORES["gem"][:1], g["LAYOUT_GEM"], "gem")),
]

tex, labels = {}, {}
for i, (key, label, fn) in enumerate(g["TEXTURES"]):
    tex[key] = fn(random.Random(5000 + i))
    labels[key] = label
for j, (key, label, fn) in enumerate(NEW):
    tex[key] = fn(random.Random(6000 + j))
    labels[key] = label

keys = list(tex)
COLS = 8
PAD = 16
CELL = N + 2 * PAD
rows = 8
atlas = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
index = {}
for i, k in enumerate(keys):
    im = Image.fromarray(tex[k], "RGBA")
    im.save(os.path.join(OUT, "tiles32", k + ".png"))
    padded = np.pad(tex[k], ((PAD, PAD), (PAD, PAD), (0, 0)), mode="wrap")
    atlas.paste(Image.fromarray(padded, "RGBA"), ((i % COLS) * CELL, (i // COLS) * CELL))
    index[k] = i
atlas.save(os.path.join(OUT, "atlas.png"))
json.dump({"tile": N, "pad": PAD, "cell": CELL, "cols": COLS, "rows": rows, "index": index, "labels": labels},
          open(os.path.join(OUT, "atlas.json"), "w"), indent=1)

# preview sheet of the new blocks
from PIL import ImageDraw, ImageFont
F = lambda s, b=True: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if b else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", s)
cell, gap, pad, cols = 128, 32, 48, 5
r = (len(NEW) + cols - 1) // cols
W = pad * 2 + cols * cell + (cols - 1) * gap
H = pad * 2 + 70 + r * (cell + 52)
sheet = Image.new("RGBA", (W, H), (22, 24, 30, 255))
d = ImageDraw.Draw(sheet)
d.text((pad, pad - 8), "New blocks", font=F(32), fill=(236, 238, 242))
d.text((pad, pad + 34), "20 more 32x32 blocks for biomes, building and plants.", font=F(17, False), fill=(150, 156, 168))
for i, (k, label, _) in enumerate(NEW):
    rr, cc = divmod(i, cols)
    x, y = pad + cc * (cell + gap), pad + 70 + rr * (cell + 52)
    if tex[k][..., 3].min() < 255:
        for yy in range(0, cell, 16):
            for xx in range(0, cell, 16):
                d.rectangle([x + xx, y + yy, x + xx + 15, y + yy + 15], fill=(60, 64, 72) if (xx // 16 + yy // 16) % 2 else (44, 47, 54))
    t = Image.fromarray(tex[k], "RGBA").resize((cell, cell), Image.NEAREST)
    sheet.alpha_composite(t, (x, y))
    d.text((x, y + cell + 8), label, font=F(16), fill=(236, 238, 242))
sheet.convert("RGB").save(os.path.join(OUT, "new_blocks.png"))
print(len(keys), "blocks")
