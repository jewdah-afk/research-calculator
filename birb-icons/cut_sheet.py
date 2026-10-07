"""Cut the approved icon sheet into transparent PNGs with a uniform ink outline.

The sheet has a flat (10,11,12) background and black outlines. Per icon we take the coloured
interior (non-dark pixels, holes filled so pupils/stripes stay), then rebuild the outline as a
fixed-width ring (distance transform, anti-aliased) so every icon has the same outline weight,
including where neighbouring icons touched on the sheet.
Run: python3 birb-icons/cut_sheet.py <sheet.png>
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage as nd

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final')
INK = np.array([11, 12, 16])       # #0B0C10-ish, matches the UI ink
RING = 6.0                         # outline width in source px
PAD = 14                           # transparent padding around each icon in source px
SIZE = 256

# icon boxes on the sheet (x0, y0, x1, y1); interiors are assigned to the box holding their centroid
BOXES = {
    'clock': (40, 0, 300, 225), 'crow': (320, 0, 590, 228), 'crown': (610, 0, 880, 230), 'echo': (900, 0, 1200, 230),
    'fish': (1200, 0, 1500, 230), 'golden': (1510, 0, 1844, 232),
    'goldore': (40, 225, 300, 435), 'heart': (320, 232, 590, 428), 'index': (610, 232, 880, 432), 'magnet': (900, 232, 1200, 430),
    'monster': (1200, 230, 1500, 432), 'mushroom': (1510, 232, 1844, 423),
    'nest': (0, 435, 300, 605), 'ore': (320, 428, 590, 613), 'parrot': (610, 432, 880, 625), 'pickaxe': (900, 430, 1200, 612),
    'plume': (1200, 432, 1500, 612), 'popcorn': (1510, 423, 1844, 612),
    'seed': (0, 605, 300, 763), 'shield': (320, 613, 590, 853), 'skill': (610, 612, 880, 853), 'sword': (900, 612, 1200, 853),
    'twig': (1200, 612, 1500, 853), 'wing': (1510, 612, 1844, 853), 'wood': (0, 763, 300, 853),
}

def hull_fill(m):
    from scipy.spatial import ConvexHull
    from PIL import ImageDraw
    pts = np.argwhere(m)[:, ::-1]; h = pts[ConvexHull(pts).vertices]
    im = Image.new('1', (m.shape[1], m.shape[0])); ImageDraw.Draw(im).polygon([tuple(p) for p in h], fill=1)
    return np.asarray(im).astype(bool)

def book_shape(m):
    """Straighten the book's wobbly cover: hull of the body (rows wider than half the max), ribbon kept as drawn."""
    w = m.sum(1); rows = np.nonzero(w > 0.5 * w.max())[0]
    body = m.copy(); body[:rows.min()] = False; body[rows.max() + 1:] = False
    return hull_fill(body) | m

def mushroom_shape(m):
    """Clip the cap to a smooth dome so the top spot doesn't bulge out of the silhouette."""
    w = m.sum(1); cy = int(np.argmax(w)); xs = np.nonzero(m[cy])[0]; cx = (xs.min() + xs.max()) / 2; rx = (xs.max() - xs.min()) / 2
    ys, xs_all = np.nonzero(m); top = {}
    for x, y in zip(xs_all, ys):
        if y < cy and (x not in top or y < top[x]): top[x] = y
    r = []
    for x, y in top.items():
        u = (x - cx) / rx
        if 0.45 < abs(u) < 0.9: r.append((cy - y) / np.sqrt(1 - u * u))
    ry = np.median(r)
    Y, X = np.mgrid[0:m.shape[0], 0:m.shape[1]]
    dome = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0
    return m & ((Y >= cy) | dome)

SHAPE = {'index': book_shape, 'mushroom': mushroom_shape, 'seed': hull_fill}   # seed: just fill the notch the log cut
BAND = {}
ERASE = {}
ERASE_SRC = {}
# twig: the crossing branch pokes out left of the main branch; cut it along the main branch's edge (x = 1293 + (y - 712))
DIAG_CUT = {'twig': (1280, 720, 750, lambda y: 1293 + (y - 712))}
CLOSE = {'crown': 1, 'nest': 1, 'twig': 1}
OPEN = {'parrot': 4}
CAP = {}
STRETCH = {'wood': (1.0, 1.32)}   # (x, y) un-squash for icons squeezed on the sheet   # icon -> cap depth as a fraction of the cut width

def cap_bottom(m, src, depth):
    """Close a flat-cut bottom with a half-ellipse and fill it with the nearest interior colours."""
    ys, xs = np.nonzero(m); yb = ys.max()
    row = np.nonzero(m[yb - 2])[0]; xl, xr = row.min(), row.max()
    cx, rx = (xl + xr) / 2, (xr - xl) / 2 + 1; ry = rx * depth
    Y, X = np.mgrid[0:m.shape[0], 0:m.shape[1]]
    t = (Y - (yb - 3)) / ry                                  # rounded-point tip: width shrinks with sqrt-ish falloff
    cap = (Y >= yb - 3) & (t <= 1) & (np.abs(X - cx) / rx <= (1 - np.clip(t, 0, 1)) ** 0.7)
    m2 = m | cap
    from scipy.spatial import ConvexHull                  # seed is convex: fill its hull to remove notches
    from PIL import ImageDraw
    pts = np.argwhere(m2)[:, ::-1]; hull = pts[ConvexHull(pts).vertices]
    hi = Image.new('1', (m.shape[1], m.shape[0])); ImageDraw.Draw(hi).polygon([tuple(p) for p in hull], fill=1)
    m2 = np.asarray(hi).astype(bool)
    core = nd.binary_erosion(m, iterations=6)               # sample colours away from the old dark edge
    idx = nd.distance_transform_edt(~core, return_distances=False, return_indices=True)
    fill = src.copy(); new = m2 & ~core & (Y > yb - 30)
    fill[new] = src[idx[0][new], idx[1][new]]
    return m2, fill

src = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
bgd = np.abs(src - [10, 11, 12]).max(2)
inside = src.max(2) > 34                       # coloured interior (outline + bg are darker)
inside = nd.binary_opening(inside, iterations=1)
lab, n = nd.label(inside)
cents = nd.center_of_mass(inside, lab, range(1, n + 1))
sizes = nd.sum(inside, lab, range(1, n + 1))

os.makedirs(OUT, exist_ok=True)
for name, (x0, y0, x1, y1) in BOXES.items():
    keep = [i + 1 for i, ((cy, cx), s) in enumerate(zip(cents, sizes)) if s > 12 and x0 <= cx < x1 and y0 <= cy < y1]
    m = np.isin(lab, keep)
    for x0_, y0_, x1_, y1_ in ERASE_SRC.get(name, []): m[y0_:y1_, x0_:x1_] = False
    if name in DIAG_CUT:
        xa, ya, yb_, edge = DIAG_CUT[name]
        for yy in range(ya, yb_): m[yy, xa:int(edge(yy))] = False
    m = nd.binary_closing(m, iterations=CLOSE.get(name, 2))
    # fill holes = enclosed interior details (pupils, dark stripes) -- but never background showing through a gap
    filled = nd.binary_fill_holes(m)
    hole = filled & ~m
    hl, hn = nd.label(hole)
    for i in range(1, hn + 1):
        h = hl == i
        if (bgd[h] < 8).mean() > 0.35:      # mostly sheet background -> keep it transparent
            filled &= ~h
    m = filled
    if name in OPEN:                        # shave thin stray bits (stray strokes on the sheet)
        m = nd.binary_opening(m, iterations=OPEN[name])
    if name in SHAPE:
        m0 = m; m = SHAPE[name](m)
        core = nd.binary_erosion(m0, iterations=4)
        idx = nd.distance_transform_edt(~core, return_distances=False, return_indices=True)
        src_shape = src.copy(); add = m & ~core
        src_shape[add] = src[idx[0][add], idx[1][add]]
    else:
        src_shape = src
    if name in CAP:                                   # this icon was cut flat where it overlapped another on the sheet
        m, src_fill = cap_bottom(m, src_shape, CAP[name])
    else:
        src_fill = src_shape
    ys, xs = np.nonzero(m)
    by0, by1 = ys.min() - int(RING) - PAD, ys.max() + int(RING) + PAD + 1
    bx0, bx1 = xs.min() - int(RING) - PAD, xs.max() + int(RING) + PAD + 1
    # square canvas
    side = max(by1 - by0, bx1 - bx0); cy, cx = (by0 + by1) // 2, (bx0 + bx1) // 2
    Y0, X0 = cy - side // 2, cx - side // 2
    canvas_m = np.zeros((side, side), bool); canvas_c = np.zeros((side, side, 3))
    sy0, sx0 = max(0, Y0), max(0, X0); sy1, sx1 = min(src.shape[0], Y0 + side), min(src.shape[1], X0 + side)
    canvas_m[sy0 - Y0:sy1 - Y0, sx0 - X0:sx1 - X0] = m[sy0:sy1, sx0:sx1]
    canvas_c[sy0 - Y0:sy1 - Y0, sx0 - X0:sx1 - X0] = src_fill[sy0:sy1, sx0:sx1]
    if name in STRETCH:                                    # resample interior, then the ring is rebuilt at full width
        kx, ky = STRETCH[name]
        yy, xx = np.nonzero(canvas_m)                      # crop to the icon first so padding isn't stretched/doubled
        canvas_m = canvas_m[yy.min():yy.max() + 1, xx.min():xx.max() + 1]; canvas_c = canvas_c[yy.min():yy.max() + 1, xx.min():xx.max() + 1]
        H, W = canvas_m.shape
        nh, nw = int(H * ky), int(W * kx)
        cm = np.asarray(Image.fromarray(canvas_m.astype(np.uint8) * 255).resize((nw, nh), Image.BILINEAR)) > 127
        cc = np.asarray(Image.fromarray(canvas_c.astype(np.uint8)).resize((nw, nh), Image.LANCZOS)).astype(float)
        side = max(nh, nw) + 2 * (int(RING) + PAD)
        canvas_m = np.zeros((side, side), bool); canvas_c = np.zeros((side, side, 3))
        oy, ox = (side - nh) // 2, (side - nw) // 2
        canvas_m[oy:oy + nh, ox:ox + nw] = cm; canvas_c[oy:oy + nh, ox:ox + nw] = cc
    for fx0, fy0, fx1, fy1 in ERASE.get(name, []):       # remove stray bits, boxes in canvas fractions
        H, W = canvas_m.shape
        canvas_m[int(fy0 * H):int(fy1 * H), int(fx0 * W):int(fx1 * W)] = False
    for (ax, ay, bx, by, hw, t0, t1) in BAND.get(name, []):  # straight band along a limb, recoloured from nearest pixels
        H, W = canvas_m.shape; Y, X = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
        dx, dy = bx - ax, by - ay; L = np.hypot(dx, dy)
        t = ((X - ax) * dx + (Y - ay) * dy) / L ** 2
        d = np.abs((X - ax) * dy - (Y - ay) * dx) / L
        side = (X - ax) * dy - (Y - ay) * dx                   # >0 = left of the axis
        band = (t > t0) & (t < t1) & (d < hw)
        nub = (t > t0) & (t < t1) & (d >= hw) & (d < hw + 0.07) & (side > 0)
        canvas_m &= ~nub
        sh = -0.22                                              # copy a clean stretch from further up the limb
        yy, xx = np.nonzero(band)
        sy = np.clip(((yy / H) + sh * dy) * H, 0, H - 1).astype(int); sx = np.clip(((xx / W) + sh * dx) * W, 0, W - 1).astype(int)
        canvas_c[yy, xx] = canvas_c[sy, sx]
        canvas_m |= band
    dist = nd.distance_transform_edt(~canvas_m)               # px distance outside the interior
    alpha = np.clip(RING + 0.5 - dist, 0, 1)
    ring = (dist > 0.0)
    rgb = np.where(ring[..., None], INK, canvas_c)
    # soft blend at the interior edge so the original anti-aliasing to the outline is kept
    edge = (dist > 0) & (dist < 1.2)
    rgb[edge] = (canvas_c[edge] * 0.35 + INK * 0.65)
    img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    Image.fromarray(img, 'RGBA').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))
    print(name, len(keep), side)
