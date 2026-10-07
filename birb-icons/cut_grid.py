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
# only these keep see-through holes (frame centre, hook eyes, gaps between rod and line); everything else is a
# solid sticker, so dark mouths and bodies on fish are never punched out
OPEN_HOLES = ('avatar_frame', 'hook_', 'lure_', 'rod_')

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
    cell_of = lambda cy_, cx_: min(rows - 1, int(cy_ // ch)) * cols + min(cols - 1, int(cx_ // cw))
    main = {}              # biggest piece per cell = the icon body
    for k, ((cy_, cx_), sz) in enumerate(zip(cents, sizes)):
        ys_, xs_ = objs[k]
        if (ys_.stop - ys_.start) > 1.15 * ch or (xs_.stop - xs_.start) > 1.15 * cw:
            split.add(k + 1); continue
        c_ = cell_of(cy_, cx_)
        if sz > main.get(c_, (0, 0))[1]: main[c_] = (k + 1, sz)
    # every other piece (flame tips, sparkles, bobbers) joins the NEAREST icon body, not whichever cell its centre is in
    body = np.zeros(full.shape, np.int32)
    for c_, (k, _) in main.items(): body[lab == k] = c_ + 1
    if split:                  # a cell whose icon is glued to a neighbour: seed its body from the glued piece's core inside that cell
        glued = nd.binary_erosion(np.isin(lab, list(split)), iterations=6)
        for c_ in range(rows * cols):
            if c_ in main: continue
            r0, c0 = (c_ // cols) * ch, (c_ % cols) * cw
            seed = np.zeros(full.shape, bool); seed[r0 + ch // 6:r0 + ch * 5 // 6, c0 + cw // 6:c0 + cw * 5 // 6] = True
            body[glued & seed & (body == 0)] = c_ + 1
    _, (iy, ix) = nd.distance_transform_edt(body == 0, return_indices=True)
    nearest = body[iy, ix]
    for k, sz in enumerate(sizes):
        if k + 1 in split: continue
        ys_, xs_ = np.nonzero(lab[objs[k]] == k + 1)
        c_ = int(np.bincount(nearest[objs[k]][ys_, xs_]).argmax()) - 1
        owner.setdefault(c_, []).append((k + 1, sz))
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
        if split:                            # glued pieces: each pixel goes to the icon body nearest to it
            m |= np.isin(lab, list(split)) & (nearest == i + 1)
        lab2, n2 = nd.label(m)               # keep the main body plus any real detail pieces
        if n2 > 1:
            sz2 = nd.sum(m, lab2, range(1, n2 + 1))
            bk = int(np.argmax(sz2)); by, bx = nd.find_objects(lab2)[bk]
            my, mx = 0.1 * (by.stop - by.start), 0.1 * (bx.stop - bx.start)
            c2 = nd.center_of_mass(m, lab2, range(1, n2 + 1))
            # keep detail pieces (sparkles, bobbers) only if they sit within the body's own area, so stray flame
            # tips or glow from a neighbouring icon are dropped
            m = np.isin(lab2, [k + 1 for k, v in enumerate(sz2) if v > 0.01 * sz2.max() and
                               by.start - my <= c2[k][0] <= by.stop + my and bx.start - mx <= c2[k][1] <= bx.stop + mx])
        m = nd.binary_closing(m, iterations=2)
        filled = nd.binary_fill_holes(m); hl, hn = nd.label(filled & ~m)
        for h in range(1, hn + 1):          # enclosed dark details stay filled; listed items keep real see-through holes
            hole = hl == h
            if name.startswith(OPEN_HOLES) and hole.sum() > 400 and (src.max(2)[hole] < 14).mean() > 0.6: filled &= ~hole
        m = filled
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
        if not name.startswith(OPEN_HOLES):   # pockets the outline closes over (between claws, fins) are sealed in ink
            pocket = nd.binary_fill_holes(alpha > 0.5) & (alpha <= 0.5)
            alpha[pocket] = 1; rgb[pocket] = INK
        img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
        os.makedirs(out, exist_ok=True)
        Image.fromarray(img, 'RGBA').resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(out, name + '.png'))
        print(name, side)

if __name__ == '__main__':
    cut(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:])
