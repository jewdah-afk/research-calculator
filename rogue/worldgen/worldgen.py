"""Peckwood Rogue world generator, reference prototype (Python, not game code).

Proves the algorithm the Roblox version will port:
  * infinite, seeded, chunked world (CHUNK x CHUNK tiles); any chunk can be generated alone and still matches its
    neighbours exactly, because everything is a pure function of (seed, world x, world z)
  * terraced height in 0.5 steps, with a hard WALKABLE rule: two neighbouring walkable tiles never differ by more
    than 0.5, so the player never needs to jump
  * "below" zones (crypts / bunkers / sunken ruins): the floor steps down -0.5 per ring, changes material, and is
    entered by ramps
  * structures (houses, ruins, shrines, chest pads) placed per REGION with a hash, so a house that crosses a chunk edge
    is identical from both sides
  * props scattered on a jittered grid (cheap Poisson-disc)
Run:  python3 rogue/worldgen/worldgen.py [seed]   -> writes previews to design/rogue-ui/worldgen/
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw

CHUNK = 64            # tiles per chunk side (one tile = one 4x4-stud plate in game)
REGION = 128          # structure placement cell (2x2 chunks)
STEP = 0.5            # height quantum (studs-high units)
HMIN, HMAX = -2.0, 2.0

# ---------- deterministic hashing / noise (all functions of seed + world coords) ----------
def h32(*v):
    x = 0x9E3779B1
    for a in v:
        x ^= (int(a) & 0xFFFFFFFF) + 0x7F4A7C15 + ((x << 6) & 0xFFFFFFFF) + (x >> 2)
        x = (x * 0x85EBCA6B) & 0xFFFFFFFF
        x ^= x >> 13
    return x

def rand01(*v):
    return h32(*v) / 0xFFFFFFFF

def value_noise(seed, X, Z, scale):
    x, z = X / scale, Z / scale
    xi, zi = np.floor(x).astype(np.int64), np.floor(z).astype(np.int64)
    xf, zf = x - xi, z - zi
    u, v = xf * xf * (3 - 2 * xf), zf * zf * (3 - 2 * zf)
    def g(ix, iz):
        k = (ix * 73856093) ^ (iz * 19349663) ^ (seed * 83492791)
        k = (k ^ (k >> 13)) * 1274126177
        return ((k ^ (k >> 16)) & 0xFFFF) / 0xFFFF
    a, b = g(xi, zi), g(xi + 1, zi)
    c, d = g(xi, zi + 1), g(xi + 1, zi + 1)
    return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v

def fbm(seed, X, Z, scale, oct=4):
    s, amp, tot = 0.0, 1.0, 0.0
    for o in range(oct):
        s = s + amp * value_noise(seed + o * 101, X, Z, scale / (2 ** o)); tot += amp; amp *= 0.5
    return s / tot

# ---------- materials ----------
GRASS, PATH, SAND, WATER, STONE, CRYPT, WOOD, WALL, FLOWERS, DARKGRASS = range(10)
WALKABLE = {GRASS, PATH, SAND, STONE, CRYPT, WOOD, FLOWERS, DARKGRASS}
MAT_COL = {GRASS: (126, 201, 64), DARKGRASS: (88, 160, 52), FLOWERS: (150, 205, 80), PATH: (226, 150, 74),
           SAND: (236, 205, 128), WATER: (64, 168, 236), STONE: (150, 150, 168), CRYPT: (96, 86, 128),
           WOOD: (170, 112, 64), WALL: (120, 92, 70)}

def base_terrain(seed, x0, z0, n):
    """Height + material for an n x n window starting at world tile (x0, z0)."""
    X, Z = np.meshgrid(np.arange(x0, x0 + n), np.arange(z0, z0 + n))
    # domain warp for organic shapes
    wx = (fbm(seed + 7, X, Z, 90) - 0.5) * 40
    wz = (fbm(seed + 9, X, Z, 90) - 0.5) * 40
    e = fbm(seed, X + wx, Z + wz, 140)                          # elevation 0..1
    hgt = np.clip(np.round(((e - 0.5) * 7) / STEP) * STEP, HMIN, HMAX)
    mat = np.full((n, n), GRASS, np.int8)
    moist = fbm(seed + 3, X, Z, 70)
    mat[moist > 0.62] = DARKGRASS
    mat[(moist < 0.33)] = FLOWERS
    # paths: thin ridged noise lines
    # lakes in the lowest ground (not walkable, act as natural walls)
    lake = e < 0.24
    mat[lake] = WATER; hgt[lake] = HMIN
    mat[(e >= 0.24) & (e < 0.27)] = SAND
    return X, Z, hgt, mat

# ---------- region structures ----------
def region_structures(seed, rx, rz):
    """Deterministic list of structures whose anchor lies in region (rx, rz)."""
    out = []
    r = lambda k: rand01(seed, rx, rz, k)
    bx, bz = rx * REGION, rz * REGION
    kind = r(1)
    if kind < 0.45:          # sunken crypt / bunker: rings step down
        out.append(('below', bx + 20 + int(r(2) * 70), bz + 20 + int(r(3) * 70), 10 + int(r(4) * 8), 2 if r(5) < 0.6 else 3))
    elif kind < 0.8:         # village: 2-4 houses
        cx, cz = bx + 24 + int(r(6) * 70), bz + 24 + int(r(7) * 70)
        for i in range(2 + int(r(8) * 3)):
            out.append(('house', cx + int((r(10 + i) - 0.5) * 34), cz + int((r(20 + i) - 0.5) * 34), 6 + int(r(30 + i) * 3), 5 + int(r(40 + i) * 3), int(r(50 + i) * 4)))
    if r(60) < 0.7:
        out.append(('shrine', bx + int(r(61) * REGION), bz + int(r(62) * REGION)))
    for i in range(1 + int(r(70) * 3)):
        out.append(('chest', bx + int(r(71 + i) * REGION), bz + int(r(81 + i) * REGION)))
    return out

def anchor(seed, rx, rz):
    """Main point of interest of a region (first structure), used to route roads between regions."""
    s = region_structures(seed, rx, rz)
    return (s[0][1], s[0][2]) if s else (rx * REGION + REGION // 2, rz * REGION + REGION // 2)

def roads(seed, X, Z, mat):
    """Roads join each region's anchor to its east and south neighbours: a wobbly 3-wide line, same from any chunk."""
    x0, z0, n = int(X[0, 0]), int(Z[0, 0]), X.shape[0]
    for rx in range((x0 - REGION) // REGION - 1, (x0 + n) // REGION + 2):
        for rz in range((z0 - REGION) // REGION - 1, (z0 + n) // REGION + 2):
            ax, az = anchor(seed, rx, rz)
            for nx_, nz_ in ((rx + 1, rz), (rx, rz + 1)):
                if rand01(seed, rx, rz, nx_, nz_, 99) < 0.25: continue      # some links missing = less grid-like
                bx, bz = anchor(seed, nx_, nz_)
                L = int(max(abs(bx - ax), abs(bz - az))) + 1
                for t in range(L + 1):
                    f = t / L
                    wob = math.sin(f * math.pi) * (rand01(seed, rx, rz, nx_, 7) - 0.5) * 30
                    px_ = ax + (bx - ax) * f + (-(bz - az) / max(L, 1)) * wob
                    pz_ = az + (bz - az) * f + ((bx - ax) / max(L, 1)) * wob
                    for ox in (-1, 0, 1):
                        for oz in (-1, 0, 1):
                            cx_, cz_ = int(round(px_)) + ox - x0, int(round(pz_)) + oz - z0
                            if 0 <= cx_ < n and 0 <= cz_ < n and mat[cz_, cx_] != WATER:
                                mat[cz_, cx_] = PATH

def stamp(seed, X, Z, hgt, mat, prop):
    x0, z0, n = int(X[0, 0]), int(Z[0, 0]), X.shape[0]
    rx0, rz0 = (x0 - REGION) // REGION, (z0 - REGION) // REGION
    rx1, rz1 = (x0 + n + REGION) // REGION, (z0 + n + REGION) // REGION
    for rx in range(rx0, rx1 + 1):
        for rz in range(rz0, rz1 + 1):
            for s in region_structures(seed, rx, rz):
                if s[0] == 'below':
                    _, cx, cz, rad, depth = s
                    d = np.maximum(np.abs(X - cx), np.abs(Z - cz)) + 0.35 * np.minimum(np.abs(X - cx), np.abs(Z - cz))
                    inside = d <= rad
                    surf = np.where(inside, np.round(hgt[np.clip(cz - z0, 0, n - 1), np.clip(cx - x0, 0, n - 1)] / STEP) * STEP, 0)
                    ring = np.clip(((rad - d) / (rad / depth)).astype(int) + 1, 1, depth)
                    floor = np.clip(surf - STEP * ring, HMIN, HMAX)
                    hgt[inside] = floor[inside]
                    prop[inside] = 0                      # below zones are clear arenas (decor comes from the zone kit)
                    mat[inside] = np.where(ring[inside] >= 2, CRYPT, STONE)
                    # four ramps: a straight corridor of PATH from the rim to the floor, stepped 0.5 per tile
                    for ang in range(4):
                        dx, dz = [(1, 0), (-1, 0), (0, 1), (0, -1)][ang]
                        for t in range(rad + 3):
                            tx, tz = cx + dx * t, cz + dz * t
                            for w in (-1, 0, 1):
                                ax, az = tx - x0 + (w if dz else 0), tz - z0 + (w if dx else 0)
                                if 0 <= ax < n and 0 <= az < n and mat[az, ax] != WATER:
                                    mat[az, ax] = STONE if mat[az, ax] in (CRYPT, STONE) else PATH
                elif s[0] == 'house':
                    _, hx, hz, w, d, door = s
                    for zz in range(hz, hz + d):
                        for xx in range(hx, hx + w):
                            ax, az = xx - x0, zz - z0
                            if not (0 <= ax < n and 0 <= az < n) or mat[az, ax] == WATER: continue
                            edge = xx in (hx, hx + w - 1) or zz in (hz, hz + d - 1)
                            dside = [(zz == hz + d - 1), (zz == hz), (xx == hx), (xx == hx + w - 1)][door]
                            mid = (xx == hx + w // 2) if door < 2 else (zz == hz + d // 2)
                            mat[az, ax] = WALL if (edge and not (dside and mid)) else WOOD
                            hgt[az, ax] = hgt[np.clip(hz - z0, 0, n - 1), np.clip(hx - x0, 0, n - 1)]
                else:
                    _, sx, sz = s
                    ax, az = sx - x0, sz - z0
                    if 0 <= ax < n and 0 <= az < n and mat[az, ax] in WALKABLE:
                        prop[az, ax] = 2 if s[0] == 'shrine' else 3

def enforce_walkable(hgt, mat, iters=12):
    """Clamp so 4-neighbour walkable tiles differ by <= STEP. Cliffs only survive next to water or walls."""
    walk = np.isin(mat, list(WALKABLE))
    for _ in range(iters):
        changed = False
        for dz, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nb = np.roll(np.roll(hgt, dz, 0), dx, 1); nw = np.roll(np.roll(walk, dz, 0), dx, 1)
            too_high = walk & nw & (hgt > nb + STEP)
            if too_high.any():
                hgt[too_high] = nb[too_high] + STEP; changed = True
        if not changed: break
    return hgt

def props_layer(seed, X, Z, mat):
    prop = np.zeros(X.shape, np.int8)
    cell = 5
    gx, gz = X // cell, Z // cell
    jx = (np.vectorize(lambda a, b: rand01(seed, a, b, 1))(gx, gz) * cell).astype(int)
    jz = (np.vectorize(lambda a, b: rand01(seed, a, b, 2))(gx, gz) * cell).astype(int)
    pick = np.vectorize(lambda a, b: rand01(seed, a, b, 3))(gx, gz)
    hit = ((X % cell) == jx) & ((Z % cell) == jz) & (pick < 0.55) & np.isin(mat, [GRASS, DARKGRASS, FLOWERS])
    prop[hit] = 1                                    # tree / rock / bush (variant chosen by hash in game)
    return prop

def chunk(seed, cx, cz):
    """Generate one chunk. Pads by 8 tiles so the walkable clamp sees neighbours, then crops: seam-free."""
    pad = 8
    X, Z, hgt, mat = base_terrain(seed, cx * CHUNK - pad, cz * CHUNK - pad, CHUNK + 2 * pad)
    roads(seed, X, Z, mat)
    prop = props_layer(seed, X, Z, mat)
    stamp(seed, X, Z, hgt, mat, prop)
    hgt = enforce_walkable(hgt, mat)
    # spawn clearing at world origin
    d = np.hypot(X, Z); clear = d < 10
    prop[clear] = 0; mat[clear & (mat == WATER)] = GRASS
    s = slice(pad, pad + CHUNK)
    return hgt[s, s], mat[s, s], prop[s, s]

# ---------- preview render: studded, hull-outlined, cel-shaded look ----------
def render(seed, cx0, cz0, nx, nz, px, path, studs=True):
    H = np.zeros((nz * CHUNK, nx * CHUNK)); Mt = np.zeros_like(H, dtype=np.int8); P = np.zeros_like(Mt)
    for i in range(nx):
        for j in range(nz):
            h, m, p = chunk(seed, cx0 + i, cz0 + j)
            H[j * CHUNK:(j + 1) * CHUNK, i * CHUNK:(i + 1) * CHUNK] = h
            Mt[j * CHUNK:(j + 1) * CHUNK, i * CHUNK:(i + 1) * CHUNK] = m
            P[j * CHUNK:(j + 1) * CHUNK, i * CHUNK:(i + 1) * CHUNK] = p
    rows, cols = H.shape
    img = Image.new('RGB', (cols * px, rows * px)); dr = ImageDraw.Draw(img)
    for z in range(rows):
        for x in range(cols):
            m = int(Mt[z, x]); base = np.array(MAT_COL[m], float)
            band = 0.86 + 0.07 * (H[z, x] / STEP)                     # cel band per 0.5 step
            if m == WATER: band = 1.0
            c = tuple(np.clip(base * band, 0, 255).astype(int))
            dr.rectangle([x * px, z * px, x * px + px - 1, z * px + px - 1], fill=c)
            if studs and px >= 6 and m not in (WATER,):
                r = px * 0.28; cxp, czp = x * px + px / 2, z * px + px / 2
                hi = tuple(min(255, int(v * 1.12)) for v in c); lo = tuple(int(v * 0.8) for v in c)
                dr.ellipse([cxp - r, czp - r + 1, cxp + r, czp + r + 1], fill=lo)
                dr.ellipse([cxp - r, czp - r, cxp + r, czp + r - 1], fill=hi)
    # hull outline wherever height changes (the ink line that sells the cel look) + cliff shadow
    ink = (24, 22, 34)
    for z in range(rows):
        for x in range(cols):
            if x + 1 < cols and H[z, x] != H[z, x + 1]:
                dr.line([(x + 1) * px, z * px, (x + 1) * px, (z + 1) * px], fill=ink, width=max(1, px // 4))
            if z + 1 < rows and H[z, x] != H[z + 1, x]:
                dr.line([x * px, (z + 1) * px, (x + 1) * px, (z + 1) * px], fill=ink, width=max(1, px // 4))
            if Mt[z, x] == WALL:
                dr.rectangle([x * px, z * px, x * px + px - 1, z * px + px - 1], fill=(92, 64, 48), outline=ink)
    for z in range(rows):
        for x in range(cols):
            p = P[z, x]
            if p:
                cxp, czp = x * px + px / 2, z * px + px / 2; r = px * (0.9 if p == 1 else 1.3)
                col = {1: (46, 128, 52), 2: (255, 196, 64), 3: (176, 76, 255)}[int(p)]
                dr.ellipse([cxp - r, czp - r, cxp + r, czp + r], fill=col, outline=ink, width=max(1, px // 5))
    # chunk borders (debug)
    for i in range(1, nx):
        dr.line([i * CHUNK * px, 0, i * CHUNK * px, rows * px], fill=(255, 255, 255), width=1)
    for j in range(1, nz):
        dr.line([0, j * CHUNK * px, cols * px, j * CHUNK * px], fill=(255, 255, 255), width=1)
    img.save(path)
    return H, Mt

def check(seed, cx0, cz0, nx, nz):
    """QA: max height jump between walkable neighbours across the whole window (must be <= STEP)."""
    worst = 0.0
    big = {}
    for i in range(nx):
        for j in range(nz):
            big[(i, j)] = chunk(seed, cx0 + i, cz0 + j)
    H = np.block([[big[(i, j)][0] for i in range(nx)] for j in range(nz)])
    M = np.block([[big[(i, j)][1] for i in range(nx)] for j in range(nz)])
    W = np.isin(M, list(WALKABLE))
    for a, b, wa, wb in ((H[:, :-1], H[:, 1:], W[:, :-1], W[:, 1:]), (H[:-1, :], H[1:, :], W[:-1, :], W[1:, :])):
        dif = np.abs(a - b)[wa & wb]
        worst = max(worst, float(dif.max()) if dif.size else 0)
    return worst, float(W.mean())

def area(seed, wx0, wz0, w, d):
    """Any world window, stitched from whole chunks (proves seams are invisible)."""
    c0x, c0z = wx0 // CHUNK, wz0 // CHUNK; c1x, c1z = (wx0 + w - 1) // CHUNK, (wz0 + d - 1) // CHUNK
    rowsH, rowsM, rowsP = [], [], []
    for cz in range(c0z, c1z + 1):
        hs, ms, ps = zip(*[chunk(seed, cx, cz) for cx in range(c0x, c1x + 1)])
        rowsH.append(np.hstack(hs)); rowsM.append(np.hstack(ms)); rowsP.append(np.hstack(ps))
    H, M, P = np.vstack(rowsH), np.vstack(rowsM), np.vstack(rowsP)
    ox, oz = wx0 - c0x * CHUNK, wz0 - c0z * CHUNK
    return H[oz:oz + d, ox:ox + w], M[oz:oz + d, ox:ox + w], P[oz:oz + d, ox:ox + w]

def find_structure(seed, kind='below', search=4):
    for rx in range(-search, search + 1):
        for rz in range(-search, search + 1):
            for s_ in region_structures(seed, rx, rz):
                if s_[0] == kind: return s_
    return None

def render_iso(seed, cx, cz, path, tile=22, zoom_window=None, world=None):
    """2.5D look test: each tile is a plate, stacked by height in 0.5 steps (each step = one plate), with studs,
    3-tone cel shading (top / left side / right side), ink hull outlines and simple voxel props."""
    h, m, p = area(seed, *world) if world else chunk(seed, cx, cz)
    if zoom_window: (a0, a1, b0, b1) = zoom_window; h, m, p = h[b0:b1, a0:a1], m[b0:b1, a0:a1], p[b0:b1, a0:a1]
    rows, cols = h.shape
    hw, hh = tile, tile // 2              # iso half sizes
    plate = tile * 0.42                   # pixel height of one 0.5 step
    W = (cols + rows) * hw + 40; Hh = (cols + rows) * hh + int(10 * plate) + 200
    img = Image.new('RGB', (W, Hh), (150, 206, 245)); dr = ImageDraw.Draw(img)
    ox, oy = rows * hw + 20, int(6 * plate) + 120
    ink = (22, 20, 32)
    def P(x, z, y):                       # world tile corner -> screen
        return (ox + (x - z) * hw, oy + (x + z) * hh - y * plate / STEP)
    def shade(c, k): return tuple(int(max(0, min(255, v * k))) for v in c)
    base_y = HMIN - STEP
    for s_ in range(rows + cols - 1):     # painter's order: back to front by x+z
        for z in range(rows):
            x = s_ - z
            if not (0 <= x < cols): continue
            mt = int(m[z, x]); y = h[z, x] if mt != WATER else -0.75
            c = MAT_COL[mt]
            top = [P(x, z, y), P(x + 1, z, y), P(x + 1, z + 1, y), P(x, z + 1, y)]
            # side faces down to the lowest level so steps read as solid plates
            left = [P(x, z + 1, y), P(x + 1, z + 1, y), P(x + 1, z + 1, base_y), P(x, z + 1, base_y)]
            right = [P(x + 1, z, y), P(x + 1, z + 1, y), P(x + 1, z + 1, base_y), P(x + 1, z, base_y)]
            dr.polygon(left, fill=shade(c, 0.72)); dr.polygon(right, fill=shade(c, 0.56))
            if mt == WALL:
                wy = y + 1.5
                t2 = [P(x, z, wy), P(x + 1, z, wy), P(x + 1, z + 1, wy), P(x, z + 1, wy)]
                dr.polygon([P(x, z + 1, wy), P(x + 1, z + 1, wy), P(x + 1, z + 1, y), P(x, z + 1, y)], fill=shade(c, 0.78), outline=ink)
                dr.polygon([P(x + 1, z, wy), P(x + 1, z + 1, wy), P(x + 1, z + 1, y), P(x + 1, z, y)], fill=shade(c, 0.6), outline=ink)
                dr.polygon(t2, fill=shade((214, 90, 70), 1.0), outline=ink)
                continue
            dr.polygon(top, fill=c if mt != WATER else (84, 182, 240))
            # ink hull: outline only where the neighbour is lower (silhouette edges), like a toon outline shader
            nb_r = h[z, x + 1] if x + 1 < cols else -9; nb_l = h[z + 1, x] if z + 1 < rows else -9
            if nb_l < y or z + 1 >= rows: dr.line([top[3], top[2]], fill=ink, width=2)
            if nb_r < y or x + 1 >= cols: dr.line([top[1], top[2]], fill=ink, width=2)
            if (z > 0 and h[z - 1, x] < y) or z == 0: dr.line([top[0], top[1]], fill=ink, width=2)
            if (x > 0 and h[z, x - 1] < y) or x == 0: dr.line([top[0], top[3]], fill=ink, width=2)
            if mt != WATER:               # one stud per tile (in game: 4x4 studs per tile, LOD'd)
                sx, sy = P(x + 0.5, z + 0.5, y)
                rx_, ry_ = hw * 0.32, hh * 0.32
                dr.ellipse([sx - rx_, sy - ry_ + 2, sx + rx_, sy + ry_ + 2], fill=shade(c, 0.7))
                dr.ellipse([sx - rx_, sy - ry_ - 1, sx + rx_, sy + ry_ - 1], fill=shade(c, 1.12))
            pr = int(p[z, x])
            if pr == 1:                   # voxel tree: trunk + 2 stacked canopy cubes
                tx, ty = P(x + 0.5, z + 0.5, y)
                dr.rectangle([tx - 3, ty - plate * 3, tx + 3, ty], fill=(110, 70, 40), outline=ink)
                for k, sz in ((0, 1.0), (1, 0.7)):
                    cyy = ty - plate * (3 + k * 2.2); r = hw * 0.9 * sz
                    dr.polygon([(tx, cyy - r * 0.6), (tx + r, cyy), (tx, cyy + r * 0.6), (tx - r, cyy)], fill=(70, 170, 70), outline=ink)
                    dr.polygon([(tx - r, cyy), (tx, cyy + r * 0.6), (tx, cyy + r * 0.6 + plate * 1.6), (tx - r, cyy + plate * 1.6)], fill=(52, 132, 54), outline=ink)
                    dr.polygon([(tx + r, cyy), (tx, cyy + r * 0.6), (tx, cyy + r * 0.6 + plate * 1.6), (tx + r, cyy + plate * 1.6)], fill=(40, 108, 44), outline=ink)
            elif pr in (2, 3):
                tx, ty = P(x + 0.5, z + 0.5, y); col = (255, 196, 64) if pr == 2 else (176, 76, 255)
                dr.ellipse([tx - hw * 0.7, ty - plate * 3, tx + hw * 0.7, ty], fill=col, outline=ink, width=2)
    img.save(path)

if __name__ == '__main__':
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1337
    out = os.path.join(os.path.dirname(__file__), '..', '..', 'design', 'rogue-ui', 'worldgen')
    os.makedirs(out, exist_ok=True)
    render(seed, -2, -2, 4, 4, 4, os.path.join(out, f'world_{seed}_4x4chunks.png'), studs=False)
    render(seed, 0, 0, 1, 1, 14, os.path.join(out, f'chunk_{seed}_0_0_studded.png'))
    render_iso(seed, 0, -1, os.path.join(out, f'iso_{seed}_chunk.png'), tile=18)
    b = find_structure(seed, 'below')
    if b:
        _, bx, bz, rad, dep = b
        render_iso(seed, 0, 0, os.path.join(out, f'iso_{seed}_below_zone.png'), tile=30, world=(bx - rad - 8, bz - rad - 8, 2 * rad + 16, 2 * rad + 16))
    # seam test: chunk (1,0) generated alone must equal the right half of a 2x1 render
    a = chunk(seed, 1, 0)[0]; b = chunk(seed, 1, 0)[0]
    worst, walk = check(seed, -2, -2, 4, 4)
    print(f'seed {seed}: deterministic={np.array_equal(a, b)}  max walkable step={worst}  walkable={walk:.0%}')
