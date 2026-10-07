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
    # label the WHOLE sheet, then give each piece to the cell holding its centre: icons that poke past
    # their cell (hook eyes, rod tips) stay whole instead of being sliced at the cell line
    # art vs background: the sheet background is pure black, so anything above ~14 is art (this keeps dark fins,
    # black fish and the art's own outline; a higher cut-off used to eat dark parts of the silhouette)
    full = nd.binary_opening(src.max(2) > 14, iterations=1)
    lab, n = nd.label(full)
    sizes = nd.sum(full, lab, range(1, n + 1)); cents = nd.center_of_mass(full, lab, range(1, n + 1))
    owner = {}
    objs = nd.find_objects(lab)
    split = set()          # pieces wider/taller than a cell are two icons glued by a glow: split those at the cell lines
    for k, ((cy_, cx_), sz) in enumerate(zip(cents, sizes)):
        ys_, xs_ = objs[k]
        if (ys_.stop - ys_.start) > 1.15 * ch or (xs_.stop - xs_.start) > 1.15 * cw:
            split.add(k + 1); continue
        owner.setdefault(min(rows - 1, int(cy_ // ch)) * cols + min(cols - 1, int(cx_ // cw)), []).append((k + 1, sz))
    for i, name in enumerate(names):
        if name == '-': continue
        keep = name.endswith('!'); name = name.rstrip('!')
        r0, c0 = (i // cols) * ch, (i % cols) * cw
        cellmask = np.zeros(full.shape, bool); cellmask[r0:r0 + ch, c0:c0 + cw] = True
        parts = owner.get(i, [])
        m = np.zeros(full.shape, bool)
        if parts:
            big = max(s for _, s in parts)
            m = np.isin(lab, [k for k, s in parts if s > 0.01 * big])
        if split:
            m |= np.isin(lab, list(split)) & cellmask
        lab2, n2 = nd.label(m)               # keep the main body plus any real detail pieces
        if n2 > 1:
            sz2 = nd.sum(m, lab2, range(1, n2 + 1))
            m = np.isin(lab2, [k + 1 for k, v in enumerate(sz2) if v > 0.01 * sz2.max()])
        m = nd.binary_fill_holes(nd.binary_closing(m, iterations=2))
        q = src
        ys, xs = np.nonzero(m)
        ext = max(np.ptp(ys), np.ptp(xs))
        ring = max(3.0, ext * 0.022)                  # ~6px at 256 after scaling
        pad = int(ext * 0.08)
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
