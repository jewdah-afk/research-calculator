"""pieces3d.py - builders for the 3D hero pieces (one function per piece kind).

Each builder takes the layer theme (relics.LAYERS[key]) and returns (objects, rect) where rect = (x0, y0, x1, y1) is
the camera frame in local units (1 u = 100 render px). Anchors (the frame corner, a socket centre...) are at known
local coordinates that build.py writes into the manifest, so the 2D side knows where to place each image.
"""
import math, random
from mathutils import Vector
import relics as R
import bl, bpy

RIM = 0.24          # the 9-slice rim moulding width (12 display px)
META = {}           # per-piece extras written into out/3d/<name>.json: fill = the polygon the 2D kit paints under the frame


def _diag(pts):
    """Reflect across the corner diagonal (top arm <-> left arm): (x, y) -> (-y, -x)."""
    return [(-p[1], -p[0], *p[2:]) for p in pts]


def _arm_poly(wo, wi, L, tip, flare=0.06):
    """Top arm + corner square + left arm as one L polygon with spear finials (CCW)."""
    c = (wi - wo) / 2          # centre offset of the arm band (y = -c on the top arm)
    top = [(L, wo), (L + 0.10, wo + flare), (tip, -c), (L + 0.10, -wi - flare), (L, -wi)]
    pts = [(-wo, wo)] + top + [(wi, -wi)]
    left = [(-y, -x) for x, y in reversed(top)]
    pts += left
    # CCW check / fix
    a = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if a > 0 else list(reversed(pts))


# the moulding profile shared by the corner arms and the 9-slice rim: (d, z), d > 0 = toward the panel interior
def moulding(w=0.40, hgt=1.0):
    k = w / 0.40
    pr = [(-0.200, 0.0), (-0.200, 0.018)]
    for i in range(0, 11):                       # outer bead: half round
        a = math.pi - math.pi * i / 10
        pr.append((-0.150 + 0.048 * math.cos(a), 0.026 + 0.04 * math.sin(a)))
    pr += [(-0.098, 0.030), (-0.090, 0.022), (0.010, 0.022), (0.018, 0.032)]        # channel (the inlay sits here)
    for i in range(0, 17):                       # inner ogee: a broad rounded roll
        a = math.pi - math.pi * i / 16
        pr.append((0.106 + 0.088 * math.cos(a), 0.034 + 0.082 * math.sin(a) ** 0.85))
    pr += [(0.198, 0.02), (0.200, 0.0)]
    return [(d * k, z * hgt) for d, z in pr]


def _spade(tipx, cy, L, wd, back=0.06):
    """A spade finial pointing +x: base at x=L, tip at tipx (2D polygon, CCW)."""
    pts = []
    for i in range(0, 25):
        t = i / 24
        x = L + (tipx - L) * t
        w = wd * math.sin(math.pi * min(1, t * 1.25)) ** 0.8 * (1 - t) ** 0.35 + 0.001
        pts.append((x, cy - w))
    top = [(x, 2 * cy - y) for x, y in reversed(pts)]
    return [(L - back, cy - 0.05)] + pts + top + [(L - back, cy + 0.05)]


def finial(m, base, ang, scale=1.0):
    """Trefoil finial pointing along angle `ang` (radians) from `base`: a spade and two curled side lobes."""
    bx, by = base
    ca, sa = math.cos(ang), math.sin(ang)
    T = lambda x, y: (bx + (x * ca - y * sa) * scale, by + (x * sa + y * ca) * scale)
    out = []
    axis = [T(0.52 * i / 30, 0) for i in range(31)]
    sw = lambda t: 0.26 * math.sin(math.pi * min(1.0, 0.18 + t * 0.95)) ** 0.9 * (1 - t) ** 0.3 + 0.004
    out.append(R.ribbon("Spade", axis, lambda t: sw(t) * scale, m, height=lambda t: (0.09 * (1 - t) ** 0.6 + 0.01) * scale))
    for side in (1, -1):
        lobe = R.catmull([T(0.02, 0.05 * side), T(0.10, 0.17 * side), T(0.22, 0.21 * side), T(0.28, 0.15 * side), T(0.22, 0.11 * side)], 8)
        out.append(R.ribbon("Lobe", lobe, lambda t: (0.075 * (1 - t) + 0.02) * scale, m))
    col = R.disc("Collar", 0.07 * scale, 0.09 * scale, m, pos=T(0.0, 0.0), z=0.02, seg=48, bevel=0.028 * scale)
    out.append(col)
    return out


def flourish(m, k=1.0):
    """Inner-corner ornament of a top-left corner: a C-scroll hanging from each arm (mirrored on the diagonal)."""
    out = []
    lead = [(1.86, -0.27), (1.64, -0.39), (1.44, -0.47), (1.30, -0.50)]
    cx, cy, r0 = 1.30, -0.685, 0.185
    spir = []
    for i in range(1, 44):
        t = i / 43 * 1.3
        a = math.pi / 2 + 2 * math.pi * t
        r = r0 * math.exp(-1.35 * t)
        spir.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts = R.catmull(lead, 8) + spir
    pts = [(x * k, y * k) for x, y in pts]
    wfn = lambda t: (0.028 + 0.085 * math.sin(math.pi * min(1.0, t * 1.55)) ** 1.2 * (1 - 0.6 * t) + 0.02 * (1 - t)) * k
    out.append(R.ribbon("ScrollA", pts, wfn, m))
    out.append(R.ribbon("ScrollB", [(-y, -x) for x, y in pts], wfn, m))
    return out


def corner(th, which="tl"):
    gold = R.gold("Gold2", th["gold"], patina=th["patina"], tarnish=th["tarnish"])
    gold_dark = R.gold("GoldDark", R.hexmix(th["gold"], "#7a4f1a", 0.35), rough=0.3, patina=th["patina"], tarnish=th["tarnish"])
    cry = R.crystal("Cry", th["crystal"], glow=1.7, L0=0.2)
    inlay = R.glowmat("Inlay", th["hue"], 2.2)
    objs = []
    L = 1.95
    c = RIM / 2                                   # arm centre line sits on the rim centre
    path = [(L, -c), (c, -c), (c, -L)]
    objs.append(R.profile_sweep("Arm", path, moulding(0.40), gold, closed=False))
    enamel = R.bl.mat("Enamel", "#05070c", rough=0.15, coat=1.0, coat_rough=0.02)
    yc = -c + 0.04                                   # channel centre (d = -0.04 -> toward the outside)
    objs.append(R.plate("EnT", [(L - 0.02, yc - 0.045), (0.3, yc - 0.045), (0.3, yc + 0.045), (L - 0.02, yc + 0.045)], 0.0, 0.03, enamel, bevel=0.0))
    objs.append(R.plate("EnL", [(-yc - 0.045, -L + 0.02), (-yc + 0.045, -L + 0.02), (-yc + 0.045, -0.3), (-yc - 0.045, -0.3)], 0.0, 0.03, enamel, bevel=0.0))
    objs.append(R.tube("InlayT", [(L - 0.05, yc, 0.03), (0.5, yc, 0.03)], 0.02, inlay))
    objs.append(R.tube("InlayL", [(-yc, -L + 0.05, 0.03), (-yc, -0.5, 0.03)], 0.02, inlay))
    # finials: collar + spade
    for swap in (False, True):
        for o in finial(gold, (L - 0.04, -c), 0.0):
            if swap:
                o.matrix_basis = R.Matrix(((0, -1, 0, 0), (-1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))) @ o.matrix_basis
            objs.append(o)
        cx, cy = (L, -c) if not swap else (c, -L)
        col = R.disc("Collar", 0.075, 0.10, gold_dark, pos=(cx, cy), z=0.02, seg=48, bevel=0.03)
        objs.append(col)
    # inner flourish: two C-scrolls (one per arm, mirrored on the diagonal) + a teardrop leaf on the diagonal
    objs += flourish(gold)
    leaf = []
    for i in range(0, 21):
        t = i / 20
        leaf.append((0.40 + 0.48 * t, -(0.40 + 0.48 * t)))
    lw = lambda t: 0.20 * math.sin(math.pi * t) ** 0.7 * (1 - 0.5 * t) + 0.01
    objs.append(R.ribbon("Leaf", leaf, lw, gold, height=lambda t: 0.09 * math.sin(math.pi * t) ** 0.5 + 0.005))
    s = bl.sphere("LeafBead", r=0.045, loc=(0.93, -0.93, 0.03), m=gold, segments=24, rings=12)
    R.own(s); bl.smooth(s, 180); objs.append(s)
    # corner boss: domed disc, bead ring, collar, set gem
    bc = (0.10, -0.10)
    objs.append(R.disc("Boss", 0.52, 0.12, gold_dark, pos=bc, z=0.0, bevel=0.05))
    objs.append(R.torus("BossCollar", 0.34, 0.032, gold, pos=bc, z=0.13))
    n = 30
    for i in range(n):
        a = 2 * math.pi * i / n
        sp = bl.sphere("Bead", r=0.026, loc=(bc[0] + 0.45 * math.cos(a), bc[1] + 0.45 * math.sin(a), 0.115), m=gold, segments=16, rings=8)
        R.own(sp); bl.smooth(sp, 180); objs.append(sp)
    objs += R.set_gem("BossGem", th["hue"], bc, 0.27, z=0.10)
    # crystal cluster growing out of the corner (outward, behind the boss)
    rnd = random.Random(7)
    spec = [(135, 1.10, 0.19, 14), (113, 0.80, 0.14, 10), (157, 0.78, 0.14, 10), (97, 0.52, 0.10, 6), (173, 0.50, 0.10, 6),
            (125, 0.60, 0.10, 18), (146, 0.58, 0.10, 18)]
    for i, (ang, ln, r, tilt) in enumerate(spec):
        a = math.radians(ang)
        d = (math.cos(a) * math.cos(math.radians(tilt)), math.sin(a) * math.cos(math.radians(tilt)), math.sin(math.radians(tilt)))
        p = R.prism(f"Cr{i}", r, ln, r * 1.7, cry, seed=i + 3)
        R.orient(p, (bc[0] - 0.02, bc[1] + 0.02, -0.14 + 0.025 * i), d, roll=rnd.random() * 3)
        objs.append(p)
    rect = (-1.0, -2.84, 2.84, 1.0)
    return objs, rect


MIRROR = {"tl": (1, 1), "tr": (-1, 1), "bl": (1, -1), "br": (-1, -1)}


def corner_at(th, which):
    objs, (x0, y0, x1, y1) = corner(th, which)
    sx, sy = MIRROR[which]
    R.mirror_objects(objs, sx, sy)
    xs = sorted((x0 * sx, x1 * sx))
    ys = sorted((y0 * sy, y1 * sy))
    return objs, (xs[0], ys[0], xs[1], ys[1])


# ================================================================================================ shared shapes
def rect_path(x0, y0, x1, y1, ch=0.0):
    """CCW closed path of a rectangle with 45-degree chamfered corners (ch = chamfer leg)."""
    if ch <= 0:
        return [(x1, y1), (x0, y1), (x0, y0), (x1, y0)]
    return [(x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch), (x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch)]


def hex_path(x0, y0, x1, y1, pt=None):
    """CCW closed path of a long hexagon with pointed ends (pt = point length, default half height)."""
    h = (y1 - y0) / 2
    pt = h if pt is None else pt
    cy = (y0 + y1) / 2
    return [(x1 - pt, y1), (x0 + pt, y1), (x0, cy), (x0 + pt, y0), (x1 - pt, y0), (x1, cy)]


def offset_path(path, d):
    """Offset a CCW closed polyline to the left (inward) by d (mitred)."""
    n = len(path)
    out = []
    for i in range(n):
        a, p, b = Vector((*path[i - 1], 0)), Vector((*path[i], 0)), Vector((*path[(i + 1) % n], 0))
        e0, e1 = (p - a).normalized(), (b - p).normalized()
        n0, n1 = Vector((-e0.y, e0.x, 0)), Vector((-e1.y, e1.x, 0))
        mv = (n0 + n1) / max(1e-4, 1 + n0.dot(n1))
        q = p + mv * d
        out.append((q.x, q.y))
    return out


def circle_path(cx, cy, r, n=160):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def framed_rim(path, w, gold, inlay=None, enamel=True, hgt=1.0):
    """A closed moulding along `path` (its centre line), optional enamel channel with a glowing inlay line."""
    objs = [R.profile_sweep("Rim", path, moulding(w, hgt), gold, closed=True)]
    k = w / 0.40
    if inlay is not None:
        dc = -0.04 * k
        if enamel:
            en = R.bl.mat("Enamel", "#05070c", rough=0.15, coat=1.0, coat_rough=0.02)
            objs.append(R.ring_plate("Enamel", offset_path(path, dc - 0.05 * k), offset_path(path, dc + 0.05 * k), 0.0, 0.022 * hgt + 0.008, en, bevel=0))
        ip = offset_path(path, dc)
        objs.append(R.tube("Inlay", [(x, y, 0.024 * hgt) for x, y in ip], 0.02 * k, inlay, cyclic=True))
    return objs


def bead_ring(m, c, r, n, br, z):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        sp = bl.sphere("Bead", r=br, loc=(c[0] + r * math.cos(a), c[1] + r * math.sin(a), z), m=m, segments=16, rings=8)
        R.own(sp)
        bl.smooth(sp, 180)
        out.append(sp)
    return out


def ring(name, c, R_, w, m, hgt=1.0):
    """A round moulding ring (profile swept on a circle of centre-line radius R_)."""
    return R.profile_sweep(name, circle_path(c[0], c[1], R_), moulding(w, hgt), m, closed=True)


def facet_slab(name, path, z0, h, m, facet=0.08):
    """A slab from a closed path with a single-segment chamfer (cut-gem facets) on its top edges."""
    ob = R.plate(name, path, z0, h, m, bevel=0)
    mod = ob.modifiers.new("Facet", "BEVEL")
    mod.width = facet
    mod.segments = 1
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(30)
    mod.use_clamp_overlap = False
    return ob


def star_pyramid(name, c, n, r_out, r_in, h, m, z=0.0, rot=90.0):
    """A faceted star: n points, raised centre (a cut-metal star relief)."""
    bm = R.bmesh.new()
    ring_ = []
    for i in range(2 * n):
        a = math.radians(rot) + math.pi * i / n
        rr = r_out if i % 2 == 0 else r_in
        ring_.append(bm.verts.new((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a), z)))
    top = bm.verts.new((c[0], c[1], z + h))
    for i in range(2 * n):
        bm.faces.new((ring_[i], ring_[(i + 1) % (2 * n)], top))
    bm.faces.new(list(reversed(ring_)))
    R.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = R._obj(name, bm, m)
    R.bl.flat(ob)
    return ob


def star_ring(name, c, n, r_out, r_in, r_hole, h, m, z=0.0, rot=90.0):
    """A hollow star (sunburst) - a flat ring between an n-point star outline and a circle - with a raised ridge."""
    bm = R.bmesh.new()
    N = 2 * n
    outer, mid, hole = [], [], []
    for i in range(N):
        a = math.radians(rot) + math.pi * i / n
        rr = r_out if i % 2 == 0 else r_in
        outer.append(bm.verts.new((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a), z)))
        rm = r_hole + (rr - r_hole) * 0.35
        mid.append(bm.verts.new((c[0] + rm * math.cos(a), c[1] + rm * math.sin(a), z + h)))
        hole.append(bm.verts.new((c[0] + r_hole * math.cos(a), c[1] + r_hole * math.sin(a), z + h * 0.6)))
    for i in range(N):
        j = (i + 1) % N
        bm.faces.new((outer[i], outer[j], mid[j], mid[i]))
        bm.faces.new((mid[i], mid[j], hole[j], hole[i]))
    R.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = R._obj(name, bm, m)
    R.bl.flat(ob)
    return ob


def T_(th):
    """Common materials of a layer theme."""
    return dict(gold=R.gold("Gold2", th["gold"], patina=th["patina"], tarnish=th["tarnish"]),
                dark=R.gold("GoldDark", R.hexmix(th["gold"], "#7a4f1a", 0.35), rough=0.3, patina=th["patina"], tarnish=th["tarnish"]),
                inlay=R.glowmat("Inlay", th["hue"], 2.2),
                cry=R.crystal("Cry", th["crystal"], glow=1.7, L0=0.2))


# ================================================================================================ layer pieces
def rim(th):
    """The panel rim 9-slice (256 px, slice 32): the corner-arm moulding around a square, glowing inlay."""
    M = T_(th)
    S = 2.56
    path = rect_path(RIM / 2, RIM / 2, S - RIM / 2, S - RIM / 2)
    META["fill"] = path
    objs = framed_rim(path, 0.28, M["gold"], M["inlay"], hgt=0.85)
    return objs, (0, 0, S, S)


def card_rim(th):
    """Buyable card rim 9-slice (192 px): slim gold with a hue inlay, chamfered corners."""
    M = T_(th)
    S, w = 1.92, 0.16
    path = rect_path(w / 2, w / 2, S - w / 2, S - w / 2, ch=0.16)
    META["fill"] = path
    return framed_rim(path, w, M["gold"], M["inlay"], hgt=0.7), (0, 0, S, S)


def crest(th):
    """Top gem crest: the layer gem in a pointed gold setting, scroll wings along the top rim, crystal fan."""
    M = T_(th)
    objs = []
    cy = -RIM / 2
    # crystal fan behind (upward)
    for i, (ang, ln, r) in enumerate([(90, 0.78, 0.13), (70, 0.55, 0.10), (110, 0.55, 0.10), (52, 0.36, 0.08), (128, 0.36, 0.08)]):
        a = math.radians(ang)
        p = R.prism(f"Fan{i}", r, ln, r * 1.7, M["cry"], seed=20 + i)
        R.orient(p, (0, cy + 0.1, -0.2 + 0.02 * i), (math.cos(a) * 0.97, math.sin(a) * 0.97, 0.24), roll=i)
        objs.append(p)
    # setting: a pointed shield + collar ring
    sh = []
    for i in range(0, 41):
        t = i / 40
        a = math.pi * 2 * t
        rx, ry = 0.50, 0.50
        x, y = rx * math.cos(a), ry * math.sin(a)
        if y < 0:
            y = y * (1.0 + 0.55 * (1 - abs(x) / rx) ** 2)
        if y > 0:
            y = y * (1.0 + 0.35 * (1 - abs(x) / rx) ** 2)
        sh.append((x, y + cy))
    objs.append(R.plate("Shield", sh[:-1], 0.0, 0.10, M["dark"], bevel=0.045, seg=4, angle=60))
    objs.append(R.torus("Collar", 0.36, 0.035, M["gold"], pos=(0, cy), z=0.11))
    objs += bead_ring(M["gold"], (0, cy), 0.44, 26, 0.022, 0.10)
    objs += R.set_gem("CrestGem", th["hue"], (0, cy), 0.30, z=0.10)
    # wings: a C-scroll each side along the rim, plus a small drop under the shield
    for side in (1, -1):
        lead = [(0.42 * side, cy + 0.02), (0.75 * side, cy + 0.06), (1.05 * side, cy + 0.04), (1.22 * side, cy - 0.04)]
        c0 = (1.20 * side, cy - 0.20)
        spir = []
        for i in range(1, 36):
            t = i / 35 * 1.2
            a = (math.pi * 0.5 - 2 * math.pi * t) if side > 0 else (math.pi * 0.5 + 2 * math.pi * t)
            rr = 0.16 * math.exp(-1.3 * t)
            spir.append((c0[0] + rr * math.cos(a), c0[1] + 0.0 + rr * math.sin(a)))
        pts = R.catmull(lead, 8) + spir
        wfn = lambda t: 0.03 + 0.07 * math.sin(math.pi * min(1.0, t * 1.5)) * (1 - 0.6 * t)
        objs.append(R.ribbon("Wing", pts, wfn, M["gold"]))
        leaf = R.catmull([(0.40 * side, cy + 0.14), (0.70 * side, cy + 0.30), (0.95 * side, cy + 0.30), (1.10 * side, cy + 0.20)], 8)
        objs.append(R.ribbon("Leaf", leaf, lambda t: 0.08 * math.sin(math.pi * t) ** 0.6 + 0.01, M["gold"]))
    drop = [(0, cy - 0.55 - 0.3 * i / 20) for i in range(21)]
    objs.append(R.ribbon("Drop", drop, lambda t: 0.14 * math.sin(math.pi * (0.15 + 0.85 * t)) ** 0.7 * (1 - t) ** 0.5 + 0.01, M["gold"]))
    return objs, (-1.6, -1.02, 1.6, 1.02)


def medal(th):
    """Emblem medallion (256 px): 24-ray gold sunburst, moulded ring, bead ring, a glowing hue crystal dome
    (lit from inside; the layer letter is drawn over it in 2D)."""
    M = T_(th)
    objs = [star_ring("Sun", (0, 0), 24, 1.22, 0.98, 0.84, 0.06, M["dark"], z=-0.02, rot=90)]
    objs.append(ring("Ring", (0, 0), 0.86, 0.26, M["gold"], hgt=1.1))
    objs += bead_ring(M["gold"], (0, 0), 0.70, 36, 0.022, 0.03)
    META["fill"] = circle_path(0, 0, 0.745, 96)
    return objs, (-1.28, -1.28, 1.28, 1.28)


def socket(th, state="lit"):
    """Card gem socket (128 px): gold claw ring + a hue cabochon (lit) / dark glass (empty)."""
    M = T_(th)
    objs = [ring("Ring", (0, 0), 0.40, 0.16, M["gold"], hgt=1.2)]
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        c = R.ribbon("Claw", [((0.25 + 0.15 * t / 10) * math.cos(a), (0.25 + 0.15 * t / 10) * math.sin(a)) for t in range(11)],
                     lambda t: 0.05 + 0.05 * t, M["gold"], z0=0.13)
        objs.append(c)
    if state == "lit":
        META["fill"] = circle_path(0, 0, 0.345, 64)
    else:
        objs.append(R.cabochon("Cab", 0.33, 0.20, R.dark_glass("Cab", "#08070d", rough=0.12), z=0.04))
    return objs, (-0.64, -0.64, 0.64, 0.64)


def tab_a(th):
    """Treatment A active: a lit gem plate (long hexagon, faceted hue crystal on black enamel, fine gold edge)."""
    M = T_(th)
    W, H = 3.2, 0.96
    path = hex_path(-W / 2 + 0.08, -H / 2 + 0.08, W / 2 - 0.08, H / 2 - 0.08, pt=0.34)
    META["fill"] = offset_path(path, 0.0)
    objs = framed_rim(path, 0.07, M["gold"], None, hgt=0.8)
    return objs, (-W / 2, -H / 2, W / 2, H / 2)


def tab_b(th):
    """Treatment B active: a raised crystal segment (chamfered slab, faceted, gold top/bottom lips)."""
    M = T_(th)
    W, H = 2.56, 0.96
    path = rect_path(-W / 2 + 0.06, -H / 2 + 0.06, W / 2 - 0.06, H / 2 - 0.06, ch=0.12)
    META["fill"] = offset_path(path, 0.0)
    objs = framed_rim(path, 0.08, M["gold"], None, hgt=0.9)
    return objs, (-W / 2, -H / 2, W / 2, H / 2)


def button(th):
    """Primary CTA 9-slice (512 x 160): gold moulding hexagon frame, faceted glowing hue crystal fill."""
    M = T_(th)
    W, H = 5.12, 1.6
    path = hex_path(-W / 2 + 0.14, -H / 2 + 0.14, W / 2 - 0.14, H / 2 - 0.14, pt=0.46)
    META["fill"] = offset_path(path, 0.0)
    objs = framed_rim(path, 0.2, M["gold"], None, hgt=1.0)
    for side in (1, -1):
        b = bl.sphere("EndBead", r=0.07, loc=(side * (W / 2 - 0.14), 0, 0.09), m=M["gold"], segments=24, rings=12)
        R.own(b); bl.smooth(b, 180); objs.append(b)
    return objs, (-W / 2, -H / 2, W / 2, H / 2)


# ================================================================================================ shared pieces
GOLD = dict(hue="#ffd34d", crystal="#ffd34d", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0)
NEUTRAL = dict(hue="#9d8cff", crystal="#9d8cff", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0)


def card_gilded():
    """Owned card rim 9-slice (192 px): a heavier gold moulding, rosettes on the chamfers."""
    M = T_(GOLD)
    S, w = 1.92, 0.22
    path = rect_path(w / 2, w / 2, S - w / 2, S - w / 2, ch=0.2)
    META["fill"] = path
    objs = framed_rim(path, w, M["gold"], None, hgt=0.9)
    for (x, y) in ((0.16, 0.16), (S - 0.16, 0.16), (0.16, S - 0.16), (S - 0.16, S - 0.16)):
        objs.append(R.disc("Ros", 0.075, 0.08, M["dark"], pos=(x, y), z=0.03, seg=48, bevel=0.03))
        objs += bead_ring(M["gold"], (x, y), 0.105, 10, 0.022, 0.05)
    return objs, (0, 0, S, S)


def stone_rim():
    """Locked card border 9-slice (192 px): chiselled dark stone bevel (the body is a tiled stone texture)."""
    S = 1.92
    st = R.stone("Stone", "#34303d", "#5f5869", scale=3.5, bump=0.9)
    outer = rect_path(0.02, 0.02, S - 0.02, S - 0.02, ch=0.16)
    inner = rect_path(0.2, 0.2, S - 0.2, S - 0.2, ch=0.1)
    ob = R.ring_plate("Chisel", outer, inner, 0.0, 0.14, st, bevel=0)
    mod = ob.modifiers.new("Chisel", "BEVEL")
    mod.width, mod.segments, mod.limit_method = 0.12, 1, "ANGLE"
    mod.angle_limit = math.radians(30)
    return [ob], (0, 0, S, S)


def seal_owned():
    """Owned seal (128 px): gold coin rim, green enamel field, a raised gold check."""
    M = T_(GOLD)
    objs = [ring("Ring", (0, 0), 0.47, 0.16, M["gold"], hgt=1.1)]
    objs.append(R.disc("Field", 0.42, 0.04, R.bl.mat("GreenEnamel", "#0f5a2a", rough=0.12, coat=1.0, coat_rough=0.03), z=0.0))
    chk = R.catmull([(-0.22, 0.02), (-0.08, -0.13), (0.23, 0.19)], 10)
    objs.append(R.ribbon("Check", chk, lambda t: 0.13 - 0.05 * t, M["gold"], z0=0.04, sharp=0.5))
    return objs, (-0.64, -0.64, 0.64, 0.64)


def seal_locked():
    """Locked seal (160 px): round carved stone, iron band, a faintly glowing rune (the chains meet here)."""
    iron = R.bl.mat("Iron", "#7a7f8c", rough=0.36, metal=1.0, noise=dict(scale=20, color_var=0.35, rough_var=0.15, bump=0.2))
    st = R.stone("Stone", "#34303d", "#5f5869", scale=4.0, bump=0.8)
    objs = [R.disc("Stone", 0.62, 0.14, st, z=0.0, bevel=0.06)]
    objs.append(R.torus("Band", 0.66, 0.06, iron, z=0.07))
    rune = R.glowmat("Rune", "#c9b8ff", 3.0)
    strokes = [[(0, 0.36), (0, -0.36)], [(0, 0.12), (0.2, 0.3)], [(0, 0.12), (-0.2, 0.3)], [(0, -0.12), (0.2, -0.3)], [(0, -0.12), (-0.2, -0.3)]]
    for i, st_ in enumerate(strokes):
        pts = [(st_[0][0] + (st_[1][0] - st_[0][0]) * t / 10, st_[0][1] + (st_[1][1] - st_[0][1]) * t / 10) for t in range(11)]
        objs.append(R.ribbon(f"Rune{i}", pts, lambda t: 0.07, rune, z0=0.135, sharp=0.2))
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        b = bl.sphere("Rivet", r=0.035, loc=(0.66 * math.cos(a), 0.66 * math.sin(a), 0.13), m=iron, segments=16, rings=8)
        R.own(b); bl.smooth(b, 180); objs.append(b)
    return objs, (-0.8, -0.8, 0.8, 0.8)


def chain():
    """Iron chain strip (512 x 64), exactly 12 links: tiles horizontally (Roblox ScaleType.Tile)."""
    iron = R.bl.mat("Iron", "#8a8f9c", rough=0.34, metal=1.0, noise=dict(scale=24, color_var=0.4, rough_var=0.18, bump=0.25))
    W, n = 5.12, 12
    pitch = W / n
    objs = []
    for i in range(-2, n + 2):
        x = i * pitch
        t = R.bl.torus("Link", R=0.118, r=0.042, seg=48, rseg=16, loc=(x, 0, 0.08), m=iron)
        t.scale = (1.9, 1.0, 1.0)
        if i % 2:
            t.rotation_euler = (math.radians(90), 0, 0)
            t.scale = (1.9, 1.0, 1.0)
        R.own(t)
        objs.append(t)
    return objs, (0, -0.32, W, 0.32)


def dock_medal():
    """HUD dock medallion (192 px): moulded gold ring, bead ring, dark crystal face with an engraved inner ring."""
    M = T_(NEUTRAL)
    objs = [ring("Ring", (0, 0), 0.80, 0.24, M["gold"], hgt=1.1)]
    objs += bead_ring(M["gold"], (0, 0), 0.645, 32, 0.02, 0.03)
    objs.append(R.cabochon("Face", 0.68, 0.12, R.dark_glass("Face", "#0a0812", rough=0.1), z=0.0))
    objs.append(R.torus("Engr", 0.55, 0.014, M["dark"], z=0.07))
    return objs, (-0.96, -0.96, 0.96, 0.96)


def coin():
    """HUD points coin (160 px): gold coin, rim ring, faceted 4-point star relief."""
    M = T_(GOLD)
    objs = [ring("Ring", (0, 0), 0.66, 0.2, M["gold"], hgt=1.2)]
    objs.append(R.cabochon("Face", 0.58, 0.10, M["dark"], z=0.0))
    objs.append(star_pyramid("Star", (0, 0), 4, 0.5, 0.15, 0.2, M["gold"], z=0.06, rot=90))
    objs += bead_ring(M["gold"], (0, 0), 0.52, 4, 0.03, 0.08)
    return objs, (-0.8, -0.8, 0.8, 0.8)


def plaque():
    """HUD points plaque 9-slice (512 x 144): long hexagon gold moulding frame, black crystal face."""
    M = T_(GOLD)
    W, H = 5.12, 1.44
    path = hex_path(-W / 2 + 0.14, -H / 2 + 0.14, W / 2 - 0.14, H / 2 - 0.14, pt=0.34)
    META["fill"] = path
    objs = framed_rim(path, 0.2, M["gold"], R.glowmat("Inlay", "#ffd34d", 1.6), hgt=1.0)
    for side in (1, -1):
        b = bl.sphere("EndBead", r=0.07, loc=(side * (W / 2 - 0.14), 0, 0.09), m=M["gold"], segments=24, rings=12)
        R.own(b); bl.smooth(b, 180); objs.append(b)
    return objs, (-W / 2, -H / 2, W / 2, H / 2)


def shelf():
    """READY gem shelf 9-slice (512 x 176): framed dark crystal backboard with a gold ledge the gems stand on."""
    M = T_(GOLD)
    W, H = 5.12, 1.76
    path = rect_path(-W / 2 + 0.12, -H / 2 + 0.2, W / 2 - 0.12, H / 2 - 0.12, ch=0.18)
    META["fill"] = path
    objs = framed_rim(path, 0.16, M["gold"], R.glowmat("Inlay", "#ffd34d", 1.4), hgt=0.9)
    ledge = [(W / 2 - 0.2, -H / 2 + 0.44), (-W / 2 + 0.2, -H / 2 + 0.44)]
    objs.append(R.profile_sweep("Ledge", ledge, moulding(0.18, 1.3), M["gold"], closed=False))
    for side in (1, -1):
        br = R.catmull([(side * (W / 2 - 0.16), -H / 2 + 0.36), (side * (W / 2 + 0.0), -H / 2 + 0.22), (side * (W / 2 - 0.06), -H / 2 + 0.08),
                        (side * (W / 2 - 0.18), -H / 2 + 0.12)], 8)
        objs.append(R.ribbon("Bracket", br, lambda t: 0.08 * (1 - 0.6 * t) + 0.02, M["gold"]))
    return objs, (-W / 2, -H / 2, W / 2, H / 2)


def portal_ring():
    """Multiverse portal frame (384 px): moulded ring, bead ring, four rift-crystal spikes, four trefoil finials."""
    th = dict(hue="#ff2e63", crystal="#ff2e63", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0)
    M = T_(th)
    objs = [ring("Ring", (0, 0), 1.36, 0.30, M["gold"], hgt=1.2)]
    objs += bead_ring(M["gold"], (0, 0), 1.16, 64, 0.022, 0.03)
    objs.append(ring("Inner", (0, 0), 1.10, 0.08, M["dark"], hgt=0.8))
    for i in range(4):
        a = math.pi / 2 * i + math.pi / 2
        p = R.prism(f"Spike{i}", 0.12, 0.34, 0.24, M["cry"], seed=40 + i)
        R.orient(p, (1.42 * math.cos(a), 1.42 * math.sin(a), -0.05), (math.cos(a), math.sin(a), 0.15), roll=i)
        objs.append(p)
        objs += R.set_gem(f"PG{i}", th["hue"], (1.36 * math.cos(a), 1.36 * math.sin(a)), 0.13, z=0.08)
    for i in range(4):
        a = math.pi / 2 * i + math.pi / 4
        objs += finial(M["gold"], (1.48 * math.cos(a), 1.48 * math.sin(a)), a, scale=0.7)
    return objs, (-1.92, -1.92, 1.92, 1.92)


def close_btn():
    """Close button (128 px): gold ring, crimson cabochon (the X is drawn in 2D)."""
    th = dict(hue="#ff3b5c", crystal="#ff3b5c", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0)
    M = T_(th)
    objs = [ring("Ring", (0, 0), 0.50, 0.18, M["gold"], hgt=1.1)]
    objs.append(R.disc("Back", 0.44, 0.02, R.bl.mat("Enamel", "#05070c", rough=0.15), z=0.0))
    objs.append(R.cabochon("Cab", 0.42, 0.22, R.crystal("Cab", "#ff3b5c", glow=1.4, L0=0.5, tint=0.3), z=0.02))
    return objs, (-0.64, -0.64, 0.64, 0.64)


def divider():
    """Header divider 9-slice (512 x 64): a gold rod with trefoil finials at both ends."""
    M = T_(GOLD)
    W = 5.12
    objs = [R.profile_sweep("Rod", [(W / 2 - 0.5, 0), (-W / 2 + 0.5, 0)], moulding(0.1, 0.8), M["gold"], closed=False)]
    objs += finial(M["gold"], (W / 2 - 0.52, 0), 0.0, scale=0.75)
    objs += finial(M["gold"], (-W / 2 + 0.52, 0), math.pi, scale=0.75)
    return objs, (-W / 2, -0.32, W / 2, 0.32)


def toast_frame():
    """Toast / tooltip 9-slice (192 px): slim gold rim, chamfered, bead knots at the corners."""
    M = T_(GOLD)
    S, w = 1.92, 0.12
    path = rect_path(w / 2 + 0.04, w / 2 + 0.04, S - w / 2 - 0.04, S - w / 2 - 0.04, ch=0.14)
    META["fill"] = path
    objs = framed_rim(path, w, M["gold"], None, hgt=0.8)
    for (x, y) in ((0.14, 0.14), (S - 0.14, 0.14), (0.14, S - 0.14), (S - 0.14, S - 0.14)):
        b = bl.sphere("Knot", r=0.06, loc=(x, y, 0.05), m=M["gold"], segments=24, rings=12)
        R.own(b); bl.smooth(b, 180); objs.append(b)
    return objs, (0, 0, S, S)


LAYER_PIECES = [
    ("rim", rim, 64), ("card_rim", card_rim, 64), ("crest", crest, 64), ("medal", medal, 96),
    ("socket", lambda th: socket(th, "lit"), 64), ("tab_a", tab_a, 64), ("tab_b", tab_b, 64), ("button", button, 64),
]
SHARED_PIECES = [
    ("card_gilded", card_gilded, 64), ("seal_owned", seal_owned, 64), ("seal_locked", seal_locked, 64),
    ("chain", chain, 48), ("dock_medal", dock_medal, 64), ("coin", coin, 64), ("plaque", plaque, 64), ("shelf", shelf, 64),
    ("portal_ring", portal_ring, 64), ("close_btn", close_btn, 64), ("divider", divider, 48), ("toast_frame", toast_frame, 48),
    ("socket_empty", lambda: socket(NEUTRAL, "empty"), 48),
]
