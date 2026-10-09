"""Peckwood Ascent world generator -> src/shared/AscentData.luau

One island built for the game (concept: claude.ai/artifact/NsW1MDQEYJGtsaSDAdZYym):
  * the Park core (MapData, tiles 0..39 x 0..29) sits in a valley basin at sea level, with a lake, a river and an
    open south-east beach with a harbour
  * the 7 ring areas sit on terraces around the rim, clockwise from the south-west, each higher than the last
  * the Echo Field sits on the north summit massif, highest of all
  * trail ramps (path tiles) climb 1 stud per tile between consecutive areas; everywhere else terraces meet in cliffs
Output per region tile: "i,j,code,h,base" (code 1 grass, 2 path, 3 water, 4 alt; h = decorative hill levels;
base = terrace height in studs). Props: "area,kind,x,z,rot". Cores: absolute tile origin + base per area.
Run: python tools/ascent_gen.py   (deterministic)
"""
import math, os

PCX, PCY = 20, 15  # park centre (tile)
CORE = {  # handmade area cores (W, N) from IslandData
    "garden": (28, 22), "castle": (28, 24), "bridge": (30, 22), "forest": (28, 24),
    "mine": (28, 22), "desert": (30, 24), "expedition": (28, 24), "echo": (28, 22),
}
# angle: degrees clockwise from north (north = -j). base: terrace height in studs.
RING = [
    ("garden", 205, 8), ("castle", 240, 16), ("bridge", 275, 24), ("forest", 310, 32),
    ("mine", 345, 44), ("desert", 20, 52), ("expedition", 58, 64),
]
ECHO = ("echo", 2, 80, 104)  # id, angle, base, radius
R_RING = 60
VALLEY_R = 36

def h01(i, j, s=0.0):
    x = math.sin(i * 127.1 + j * 311.7 + s * 17.3) * 43758.5453
    return x - math.floor(x)

def vnoise(x, y, s=0.0):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a, b = h01(xi, yi, s), h01(xi + 1, yi, s)
    c, d = h01(xi, yi + 1, s), h01(xi + 1, yi + 1, s)
    return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v

def fbm(x, y, s=0.0):
    return vnoise(x, y, s) * 0.6 + vnoise(x * 2.1, y * 2.1, s + 3) * 0.3 + vnoise(x * 4.3, y * 4.3, s + 7) * 0.1

def polar(i, j):
    dx, dy = i + 0.5 - PCX, j + 0.5 - PCY
    r = math.hypot(dx, dy)
    a = (math.degrees(math.atan2(dx, -dy)) + 360) % 360
    return r, a

def at(angle, r):
    a = math.radians(angle)
    return PCX + math.sin(a) * r, PCY - math.cos(a) * r

def angdiff(a, b):
    d = (a - b + 180) % 360 - 180
    return d

# ---------------------------------------------------------------- cores (absolute origin)
cores, core_tile = {}, {}
for zid, ang, base in RING:
    cx, cy = at(ang, R_RING)
    W, N = CORE[zid]
    cores[zid] = (round(cx - W / 2), round(cy - N / 2), base)
eid, eang, ebase, er = ECHO
cx, cy = at(eang, er)
cores[eid] = (round(cx - CORE[eid][0] / 2), round(cy - CORE[eid][1] / 2), ebase)
for zid, (oi, oj, base) in cores.items():
    W, N = CORE[zid]
    for j in range(oj, oj + N):
        for i in range(oi, oi + W):
            core_tile[(i, j)] = zid
park_tiles = {(i, j) for i in range(40) for j in range(30)}

# ---------------------------------------------------------------- island mask
def island_r(a):
    # base radius with a noisy coast; the north massif bulges out behind Mine/Desert for the summit
    r = 84 + (fbm(a / 40, 1.3, 2) - 0.5) * 16
    north = max(0.0, 1 - abs(angdiff(a, eang)) / 48)
    r += north ** 1.5 * 46
    return r

def zone_of(i, j):
    """(zone id, base) for a land tile, before ramps"""
    r, a = polar(i, j)
    se = 95 <= a <= 185  # open south-east: the basin runs down to the beach
    if r < VALLEY_R + (fbm(i / 9, j / 9, 5) - 0.5) * 8 or (se and r < island_r(a)):
        return "park", 0
    if r > 86 + (fbm(i / 8, j / 8, 13) - 0.5) * 10 and abs(angdiff(a, eang)) < 44:
        return "echo", ebase
    best, bd = None, 1e9
    aw = a + (fbm(i / 11, j / 11, 9) - 0.5) * 26   # wandering borders between terraces
    for zid, ang, base in RING:
        d = abs(angdiff(aw, ang))
        if d < bd:
            best, bd = (zid, base), d
    return best

tiles = {}  # (i,j) -> dict(code,h,base,zone)
I0, I1, J0, J1 = -110, 150, -140, 120
for j in range(J0, J1):
    for i in range(I0, I1):
        # the Park box is NOT skipped: its own void edge tiles must become valley land (World keeps the Park's
        # real land on top, since handmade land always wins), otherwise a moat traps the bird
        r, a = polar(i, j)
        if r > island_r(a):
            continue
        z, base = zone_of(i, j)
        if (i, j) in core_tile:
            # inside a handmade area's box: its own land wins in World, but the box's empty edge tiles must be
            # terrace land at that area's height (otherwise every area sits in a moat)
            z = core_tile[(i, j)]
            base = cores[z][2]
        tiles[(i, j)] = {"code": 1, "h": 0, "base": base, "zone": z}

# ---------------------------------------------------------------- ramps (trail)
def stamp_path(points, base0, base1, zone, width=3):
    """lay a ramp along a polyline of tile points, base interpolated by arc length"""
    seg = []
    for k in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[k], points[k + 1]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) * 2))
        for s in range(n):
            t = s / n
            seg.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    seg.append(points[-1])
    total = sum(math.hypot(seg[k + 1][0] - seg[k][0], seg[k + 1][1] - seg[k][1]) for k in range(len(seg) - 1))
    acc = 0.0
    for k, (x, y) in enumerate(seg):
        if k:
            acc += math.hypot(x - seg[k - 1][0], y - seg[k - 1][1])
        t = acc / total if total else 1
        b = round(base0 + (base1 - base0) * t)
        for dx in range(-(width // 2), width // 2 + 1):
            for dy in range(-(width // 2), width // 2 + 1):
                key = (int(math.floor(x)) + dx, int(math.floor(y)) + dy)
                if key in park_tiles or key in core_tile:
                    continue
                c = tiles.setdefault(key, {"code": 2, "h": 0, "base": b, "zone": zone})
                c.update(code=2, h=0, base=b, zone=zone)

def ramp_len(d):
    return max(d + 4, 10)

# Park south-west edge -> Garden
gz, gang, gbase = RING[0]
stamp_path([at(gang, 24), at(gang, 30), at(gang, 30 + ramp_len(gbase)), at(gang, R_RING - 10)], 0, gbase, gz)
# consecutive ring areas: an arc across the wedge boundary at the ring radius
for k in range(len(RING) - 1):
    za, aa, ba = RING[k]
    zb, ab, bb = RING[k + 1]
    mid = aa + angdiff(ab, aa) / 2
    span = math.degrees(ramp_len(bb - ba) / (R_RING + 18)) / 2
    pts = [at(mid - span - 6, R_RING + 18), at(mid - span, R_RING + 18), at(mid + span, R_RING + 18), at(mid + span + 6, R_RING + 18)]
    stamp_path(pts, ba, bb, zb)
# Expedition -> Echo summit (the last climb)
xa, xang, xb = RING[-1]
p0 = at(xang - 10, R_RING + 18)
p1 = at(eang + 26, 92)
stamp_path([p0, at(xang - 22, 84), p1, at(eang + 12, er - 6)], xb, ebase, "echo")

# ---------------------------------------------------------------- water: Park lake, river to the SE beach
lake_c = (44, 38)
for (i, j), c in tiles.items():
    if c["zone"] != "park":
        continue
    dx, dy = (i + 0.5 - lake_c[0]) / 9, (j + 0.5 - lake_c[1]) / 6
    if dx * dx + dy * dy < 1:
        c["code"] = 3
river = [(48, 42), (56, 50), (64, 58), (72, 66), (80, 74), (90, 84)]
for k in range(len(river) - 1):
    (x0, y0), (x1, y1) = river[k], river[k + 1]
    for s in range(20):
        t = s / 20
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dx in (-1, 0, 1):
            key = (int(x) + dx, int(y))
            if key in tiles and tiles[key]["zone"] == "park":
                tiles[key]["code"] = 3
# Molt island in the lake
for i in range(42, 46):
    for j in range(37, 40):
        if (i, j) in tiles:
            tiles[(i, j)]["code"] = 1

# ---------------------------------------------------------------- portal plaza (teleporter hub) south-west of the Park
HUB = (8, 38)
for (i, j), c in tiles.items():
    if c["zone"] == "park" and (i + 0.5 - HUB[0]) ** 2 + (j + 0.5 - HUB[1]) ** 2 < 10 ** 2:
        c.update(code=2, h=0, plaza=True)

# ---------------------------------------------------------------- ground variety + decorative hills
ALT_FRAC = {"garden": 0.18, "castle": 0.35, "bridge": 0.15, "forest": 0.05, "mine": 0.7, "desert": 0.85,
            "expedition": 0.12, "echo": 0.25, "park": 0.0}
def near_core(i, j, d):
    for dx in range(-d, d + 1, 2):
        for dy in range(-d, d + 1, 2):
            if (i + dx, j + dy) in core_tile or (i + dx, j + dy) in park_tiles:
                return True
    return False
for (i, j), c in tiles.items():
    if c["code"] in (2, 3) or c.get("plaza"):
        continue
    z = c["zone"]
    n = fbm(i / 7, j / 7, 11)
    if n < ALT_FRAC[z]:
        c["code"] = 4
    r, a = polar(i, j)
    # decorative hills on the outer rim of each terrace (never next to a core or a ramp)
    if z != "park" and not near_core(i, j, 6):
        hn = fbm(i / 6, j / 6, 21)
        if hn > 0.62:
            c["h"] = min(6 if z == "echo" else 4, 1 + int((hn - 0.62) * 14))
            c["code"] = 4 if z in ("mine", "desert", "echo") else c["code"]
for key, c in tiles.items():
    if c["code"] == 2:
        c["h"] = 0
# beach: valley tiles within 4 of the sea become sand (alt)
for (i, j), c in tiles.items():
    if c["zone"] == "park" and c["code"] == 1:
        r, a = polar(i, j)
        if island_r(a) - r < 4:
            c["code"] = 4

# ---------------------------------------------------------------- props
KINDS = {
    "park": [("tree", .5), ("bush", .3), ("flowers", .2)],
    "garden": [("tree", .3), ("bush", .3), ("flowers", .4)],
    "castle": [("tree", .4), ("rock", .4), ("bush", .2)],
    "bridge": [("tree", .5), ("bush", .3), ("rock", .2)],
    "forest": [("pine", .55), ("tree", .3), ("mushroom", .15)],
    "mine": [("rock", .6), ("crystal", .25), ("pine", .15)],
    "desert": [("cactus", .6), ("rock", .3), ("palm", .1)],
    "expedition": [("palm", .4), ("tree", .35), ("bush", .25)],
    "echo": [("crystal", .5), ("rock", .3), ("flowers", .2)],
}
DENS = {"park": .05, "garden": .06, "castle": .05, "bridge": .07, "forest": .16, "mine": .06, "desert": .04,
        "expedition": .12, "echo": .05}
def path_near(i, j):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            c = tiles.get((i + dx, j + dy))
            if c and c["code"] in (2, 3):
                return True
    return False
props = []
for (i, j), c in sorted(tiles.items()):
    if c["code"] not in (1, 4) or c["h"] > 0 or path_near(i, j) or near_core(i, j, 2):
        continue
    z = c["zone"]
    if h01(i, j, 3.3) > DENS[z] * (0.6 + fbm(i / 5, j / 5, 33)):
        continue
    roll, acc = h01(i, j, 4.4), 0
    for kind, w in KINDS[z]:
        acc += w
        if roll <= acc:
            break
    if z == "park":
        r, a = polar(i, j)
        if island_r(a) - r < 6:
            kind = "palm"
    rot = round(h01(i, j, 5.5) * 6.283, 2)
    props.append(f"{z},{kind},{i + 0.5:.1f},{j + 0.5:.1f},{rot}")

# ---------------------------------------------------------------- write
regions = {}
for (i, j), c in sorted(tiles.items(), key=lambda kv: (kv[0][1], kv[0][0])):
    regions.setdefault(c["zone"], []).append(f'{i},{j},{c["code"]},{c["h"]},{c["base"]}')
out = ["--!nonstrict",
       "-- AscentData: the Peckwood Ascent world (generated by tools/ascent_gen.py, do not hand-edit).",
       "-- cores[id] = { oi, oj, base }: absolute tile origin of each handmade area + its terrace height (studs).",
       "-- regions[area] = \"i,j,code,h,base\" per tile (code 1 grass, 2 path, 3 water, 4 alt; h hill levels; base studs).",
       "-- props = \"area,kind,x,z,rot\".",
       "return {", '\tname = "Peckwood Ascent",', "\tcores = {"]
for zid, (oi, oj, base) in cores.items():
    out.append(f"\t\t{zid} = {{ {oi}, {oj}, {base} }},")
out.append("\t},")
out.append("\tregions = {")
for z, recs in regions.items():
    out.append(f'\t\t{z} = "{";".join(recs)}",')
out.append("\t},")
out.append(f'\tprops = "{";".join(props)}",')
out.append("}")
dst = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "AscentData.luau")
open(dst, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("tiles", len(tiles), "props", len(props), "bytes", os.path.getsize(dst))
for z in regions:
    print(" ", z, len(regions[z]))
print("cores", cores)

# ---------------------------------------------------------------- preview PNG (tools/ascent_preview.png)
import zlib, struct
ZC = {"park": (124, 195, 90), "garden": (242, 167, 195), "castle": (196, 189, 176), "bridge": (95, 183, 214),
      "forest": (63, 143, 69), "mine": (138, 129, 116), "desert": (230, 207, 146), "expedition": (88, 165, 72),
      "echo": (139, 123, 232)}
S3 = 3
W, H = (I1 - I0) * S3, (J1 - J0) * S3
img = [[(40, 110, 150)] * W for _ in range(H)]
def put(i, j, col):
    for y in range((j - J0) * S3, (j - J0) * S3 + S3):
        for x in range((i - I0) * S3, (i - I0) * S3 + S3):
            img[y][x] = col
def lit(col, base):
    f = 0.55 + base / 80 * 0.45
    return tuple(min(255, int(v * f)) for v in col)
for (i, j), c in tiles.items():
    col = ZC[c["zone"]]
    if c["code"] == 3: col = (90, 170, 220)
    elif c["code"] == 2: col = (225, 200, 150)
    elif c["code"] == 4: col = tuple(int(v * 0.85) for v in col)
    if c["h"] > 0: col = tuple(min(255, int(v * (1.1 + c["h"] * 0.05))) for v in col)
    put(i, j, lit(col, c["base"]))
for (i, j), z in core_tile.items():
    put(i, j, lit(tuple(min(255, v + 25) for v in ZC[z]), cores[z][2]))
for (i, j) in park_tiles:
    put(i, j, (150, 215, 110))
raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in img)
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
open(os.path.join(os.path.dirname(__file__), "ascent_preview.png"), "wb").write(png)
print("preview", W, H)
