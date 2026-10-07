"""Cut a generated NxM icon sheet (black background) into final/<name>.png with the uniform ink ring.
Run: python3 birb-icons/cut_grid.py <sheet.png> <cols> <rows> name1 name2 ...   (reading order; '-' skips a cell;
     a trailing '!' on a name keeps the icon's drawn size relative to its cell, for size tiers like tanks)
Same ring method as cut_sheet.py; the ring scales with the cell size so every icon gets the same outline weight at 256px."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
INK = np.array([11, 12, 16])
SIZE = 256

def cut(sheet, cols, rows, names, out=os.path.join(HERE, 'final')):
    src = np.asarray(Image.open(sheet).convert('RGB')).astype(float)
    H, W = src.shape[:2]; ch, cw = H // rows, W // cols
    for i, name in enumerate(names):
        if name == '-': continue
        keep = name.endswith('!'); name = name.rstrip('!')
        q = src[(i // cols) * ch:(i // cols + 1) * ch, (i % cols) * cw:(i % cols + 1) * cw]
        m = nd.binary_opening(q.max(2) > 40, iterations=1)
        lab, n = nd.label(m); sizes = nd.sum(m, lab, range(1, n + 1))
        big = int(np.argmax(sizes)) + 1
        edge_ids = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        # drop specks and bits of neighbouring icons that cross into this cell (they touch the cell edge)
        m = np.isin(lab, [k + 1 for k, s in enumerate(sizes) if s > 0.01 * sizes.max() and (k + 1 == big or k + 1 not in edge_ids)])
        m = nd.binary_fill_holes(nd.binary_closing(m, iterations=2))
        ys, xs = np.nonzero(m)
        ext = max(np.ptp(ys), np.ptp(xs))
        ring = max(3.0, ext * 0.022)                  # ~6px at 256 after scaling
        pad = int(ext * 0.05)
        side = ext + 2 * (int(ring) + pad)
        if keep: ring = max(3.0, max(ch, cw) * 0.022); side = int(max(ch, cw) * 1.0) + 2 * int(ring)
        cy, cx = (ys.min() + ys.max()) // 2, (xs.min() + xs.max()) // 2
        y0, x0 = cy - side // 2, cx - side // 2
        cm = np.zeros((side, side), bool); cc = np.zeros((side, side, 3))
        cm[ys - y0, xs - x0] = True; cc[ys - y0, xs - x0] = q[ys, xs]
        dist = nd.distance_transform_edt(~cm)
        alpha = np.clip(ring + 0.5 - dist, 0, 1)
        rgb = np.where((dist > 0)[..., None], INK, cc)
        edge = (dist > 0) & (dist < 1.5); rgb[edge] = cc[edge] * 0.35 + INK * 0.65
        img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
        os.makedirs(out, exist_ok=True)
        Image.fromarray(img, 'RGBA').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(out, name + '.png'))
        print(name, side)

if __name__ == '__main__':
    cut(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:])
