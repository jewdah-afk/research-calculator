"""Version 3: version 2 with redrawn cobble and ores.

Cobble: staggered rows of small rounded stones, each with a lit top-left rim, a dark
bottom-right rim, varied tones, and dark mortar between them.
Ores: hand-drawn nugget / crystal sprites (light from the top-left, a glint, a drop
shadow into the stone) placed at fixed, balanced spots.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "make_textures_v2.py")).read()
head, tail = src.split("TEXTURES = [", 1)

NEW = r'''
def t_stone_bricks(rng):
    # Staggered rows of stones: 4 rows, row heights vary, each row split at jittered points.
    img = blank()
    owner = -np.ones((N, N), dtype=int)
    rows = [0, 4, 8, 12, 16]
    sid = 0
    for r in range(4):
        y0, y1 = rows[r], rows[r + 1]
        off = rng.randrange(0, 5)
        cuts = []
        x = off
        while x < off + N:
            cuts.append(x)
            x += rng.choice([4, 5, 5, 6])
        for i, cx in enumerate(cuts):
            nx = cuts[i + 1] if i + 1 < len(cuts) else off + N
            for yy in range(y0, y1):
                for xx in range(cx, nx):
                    owner[yy, xx % N] = sid
            sid += 1
    tones = [STONE[rng.choice([1, 2, 2, 3, 3])] for _ in range(sid)]
    n = vnoise(rng, ((8, 1.0), (16, 0.7)))
    MORTAR = hexc("3e4044")
    for y in range(N):
        for x in range(N):
            o = owner[y, x]
            right, down = owner[y, (x + 1) % N], owner[(y + 1) % N, x]
            left, up = owner[y, (x - 1) % N], owner[(y - 1) % N, x]
            # round the corners: a pixel touching two different stones becomes mortar
            diag = owner[(y + 1) % N, (x + 1) % N]
            if right != o or down != o:
                img[y, x] = MORTAR
            elif diag != o and (owner[(y - 1) % N, (x + 1) % N] != o or owner[(y + 1) % N, (x - 1) % N] != o):
                img[y, x] = MORTAR
            elif left != o or up != o:
                img[y, x] = mix(tones[o], 1.24)  # lit rim
            elif owner[y, (x + 2) % N] != o or owner[(y + 2) % N, x] != o:
                img[y, x] = mix(tones[o], 0.8)  # shaded rim
            else:
                img[y, x] = mix(tones[o], 1.0 + (n[y, x] - 0.5) * 0.14)
    return img


def t_cobble(rng):
    # Irregular rounded stones: jittered-grid Voronoi, 13 stones of mixed size,
    # strong rim lighting, dark mortar and rounded corners where three stones meet.
    seeds = []
    for gy in range(3):
        for gx in range(3):
            seeds.append(((gx + 0.5 + (gy % 2) * 0.5) * 5.33 + rng.uniform(-1.2, 1.2),
                          (gy + 0.5) * 5.33 + rng.uniform(-1.2, 1.2)))
    seeds.append((rng.uniform(0, N), rng.uniform(0, N)))
    weight = [rng.uniform(0.8, 1.3) for _ in seeds]
    owner = np.zeros((N, N), dtype=int)
    for y in range(N):
        for x in range(N):
            best, bi = 1e9, 0
            for i, (sx, sy) in enumerate(seeds):
                dx = (x + 0.5 - sx + N / 2) % N - N / 2
                dy = (y + 0.5 - sy + N / 2) % N - N / 2
                dd = (dx * dx + dy * dy) / weight[i]
                if dd < best:
                    best, bi = dd, i
            owner[y, x] = bi
    warm = [hexc("8a8781"), hexc("7d7b77"), hexc("96938d")]
    cool = [hexc("80848a"), hexc("8d9197"), hexc("737780")]
    tones = [rng.choice(warm + cool + [STONE[2], STONE[3]]) for _ in seeds]
    n = vnoise(rng, ((8, 1.0), (16, 0.7)))
    MORTAR, MORTAR2 = hexc("3a3b3f"), hexc("4a4b50")
    img = blank()
    O = lambda x, y: owner[y % N, x % N]
    for y in range(N):
        for x in range(N):
            o = O(x, y)
            neigh = {O(x + 1, y), O(x, y + 1), O(x + 1, y + 1)}
            if O(x + 1, y) != o or O(x, y + 1) != o:
                img[y, x] = MORTAR
            elif len(neigh | {o}) > 2:
                img[y, x] = MORTAR2  # rounded corner
            elif O(x - 1, y) != o or O(x, y - 1) != o:
                img[y, x] = mix(tones[o], 1.22)
            elif O(x + 2, y) != o or O(x, y + 2) != o:
                img[y, x] = mix(tones[o], 0.82)
            else:
                img[y, x] = mix(tones[o], 1.0 + (n[y, x] - 0.5) * 0.16)
    return img


SHAPES = {
    # . = none, D = dark, M = mid, L = light, S = glint
    "lump_a": ["LLM.", "LMMD", "MMDD", ".DD."],
    "lump_b": [".LM.", "LMMD", ".MD."],
    "lump_c": ["LMM", "MMD"],
    "lump_d": ["LM.", "MMD", ".DD"],
    "nug_a": ["SL.", "LMD", ".DD"],
    "nug_b": [".SL.", "LMMD", "LMDD", ".DD."],
    "nug_c": ["SLM", "MMD"],
    "nug_d": ["LS", "MD"],
    "gem_big": ["..S..", ".LLM.", "LLMMD", ".MMD.", "..D.."],
    "gem_mid": [".S.", "LMD", ".D."],
    "gem_bar": ["SL..", "LMM.", ".MMD", "..DD"],
}


def ore(colors, layout):
    dark, mid, light, glint = (hexc(c) for c in colors)
    tone = {"D": dark, "M": mid, "L": light, "S": glint}

    def make(rng):
        img = t_stone(rng)
        for shape, (ox, oy) in layout:
            rows = SHAPES[shape]
            pts = {}
            for dy, row in enumerate(rows):
                for dx, ch in enumerate(row):
                    if ch != ".":
                        pts[(ox + dx, oy + dy)] = ch
            for (x, y) in pts:  # drop shadow into the stone, below-right
                for sx, sy in ((x + 1, y + 1), (x + 1, y), (x, y + 1)):
                    if (sx, sy) not in pts and 0 <= sx < N and 0 <= sy < N:
                        img[sy, sx] = mix(img[sy, sx], 0.68)
            for (x, y), ch in pts.items():
                img[y, x] = tone[ch]
        return img
    return make


'''

LIST = r'''TEXTURES = [
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
    ("ore_coal", "Coal ore", ore(("141518", "2b2d31", "4a4d53", "7a7e86"),
        [("lump_a", (1, 1)), ("lump_c", (10, 2)), ("lump_d", (6, 7)), ("lump_b", (1, 11)), ("lump_c", (11, 11))])),
    ("ore_iron", "Iron ore", ore(("8a5536", "c88a62", "e8b48e", "fff0e0"),
        [("nug_b", (1, 1)), ("nug_c", (10, 2)), ("nug_a", (6, 8)), ("nug_d", (2, 12)), ("nug_a", (12, 11))])),
    ("ore_gold", "Gold ore", ore(("9a6a0e", "e6b222", "ffe165", "fffbe6"),
        [("nug_b", (2, 2)), ("nug_a", (11, 1)), ("nug_c", (7, 8)), ("nug_d", (1, 12)), ("nug_b", (11, 11))])),
    ("ore_gem", "Gem ore", ore(("146c74", "2fbcc2", "8ef3ec", "ffffff"),
        [("gem_big", (1, 1)), ("gem_mid", (11, 2)), ("gem_bar", (8, 9)), ("gem_mid", (2, 11))])),
'''

tail = tail.split("\n]\n", 1)[1]
code = head + NEW + LIST + "]\n" + tail
code = code.replace('os.path.join(HERE, "v2", "tiles16")', 'os.path.join(HERE, "v3", "tiles16")')
code = code.replace('os.path.join(HERE, "v2", "tiles256")', 'os.path.join(HERE, "v3", "tiles256")')
code = code.replace("'\"v2\", \"starter_blocks_v2.png\"'", "'\"v3\", \"starter_blocks_v3.png\"'")
code = code.replace("'\"v2\", \"starter_cubes_v2.png\"'", "'\"v3\", \"starter_cubes_v3.png\"'")
code = code.replace("Version 2. Original", "Version 3. Original")
code = code.replace("fn(random.Random(2000 + i))", "fn(random.Random(SEEDS.get(key, 2000 + i)))")
code = code.replace("tex = {}", "SEEDS = {k: 2000 + j for j, k in enumerate(['grass_top','grass_side','dirt','stone','stone_bricks','gravel','sand','log_side','log_top','planks','leaves','ore_coal','ore_iron','ore_gold','ore_gem'])}\nSEEDS['cobble'] = 2031\ntex = {}")
code = code.replace("os.path.dirname(os.path.abspath(__file__))", repr(HERE))
exec(compile(code, "make_textures_v3_built", "exec"), {"__name__": "__main__"})
