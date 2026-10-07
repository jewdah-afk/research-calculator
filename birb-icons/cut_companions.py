"""Cut a 2x2 generated sheet into final/*.png with the same ink ring as cut_sheet.py.
Run: python3 birb-icons/cut_companions.py            (companions_sheet.png: sparrow, seagull / dove, redpanda)
     python3 birb-icons/cut_companions.py fishing    (fishing_sheet.png: moneta, rod / bait, aquarium)"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
INK = np.array([11, 12, 16])
RING, PAD, SIZE = 10.0, 24, 256          # ring scaled for this sheet's larger icons (~450px vs ~260px)
SHEETS = {'companions': ['sparrow', 'seagull', 'dove', 'redpanda'], 'fishing': ['moneta', 'rod', 'bait', 'aquarium']}
which = sys.argv[1] if len(sys.argv) > 1 else 'companions'
NAMES = {n: (i % 2, i // 2) for i, n in enumerate(SHEETS[which])}

src = np.asarray(Image.open(os.path.join(HERE, which + '_sheet.png')).convert('RGB')).astype(float)
H, W = src.shape[:2]
for name, (qx, qy) in NAMES.items():
    q = src[qy * H // 2:(qy + 1) * H // 2, qx * W // 2:(qx + 1) * W // 2]
    m = nd.binary_opening(q.max(2) > 40, iterations=2)
    lab, n = nd.label(m); sizes = nd.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 0.02 * sizes.max()])
    m = nd.binary_fill_holes(nd.binary_closing(m, iterations=3))
    ys, xs = np.nonzero(m)
    side = max(np.ptp(ys), np.ptp(xs)) + 2 * (int(RING) + PAD)
    cy, cx = (ys.min() + ys.max()) // 2, (xs.min() + xs.max()) // 2
    cm = np.zeros((side, side), bool); cc = np.zeros((side, side, 3))
    y0, x0 = cy - side // 2, cx - side // 2
    cm[ys - y0, xs - x0] = True; cc[ys - y0, xs - x0] = q[ys, xs]
    dist = nd.distance_transform_edt(~cm)
    alpha = np.clip(RING + 0.5 - dist, 0, 1)
    rgb = np.where((dist > 0)[..., None], INK, cc)
    edge = (dist > 0) & (dist < 1.5); rgb[edge] = cc[edge] * 0.35 + INK * 0.65
    img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    Image.fromarray(img, 'RGBA').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(HERE, 'final', name + '.png'))
    print(name, side)
