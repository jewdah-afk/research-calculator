# Cut the painted icon sheet (art/source/icon_sheet.png) into transparent PNGs.
# python3 art/cut_icons.py art/source/icon_sheet.png <out dir>; then art/export_icons.py makes the 512/128 sizes.
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage as nd
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
img = Image.open(src).convert('RGB'); im = np.asarray(img).astype(int)
bg = np.array([25, 33, 42]); dist = np.abs(im - bg).sum(2)
NAMES = ['coin','cash','gem','robux','players','stopwatch','orb','ghost',
         'bolt_blue','rune_bulk','magnifier','camera','lock','check','star_gold','dice',
         'clone','clover','anvil','gift','arrow_r','arrow_l','rune0','rune1',
         'rune2','rune3','rune4','rune5','rune6','rune7','rune8','rune9']
ROWS = [(0, 182), (150, 356), (330, 522), (500, 684)]   # loose bands; labels are dropped below
COLW = 1844 / 8; X0 = 30
fgall = dist > 20
for idx, name in enumerate(NAMES):
    r, c = divmod(idx, 8)
    y0, y1 = ROWS[r]
    # column window from the detected layout (icons sit ~215px apart starting near x=58)
    xs = [(50, 250), (240, 450), (470, 660), (680, 870), (900, 1085), (1115, 1300), (1335, 1520), (1555, 1745)][c]
    sub = fgall[y0:y1, xs[0]:xs[1]]
    lab, n = nd.label(sub)
    sizes = nd.sum(sub, lab, range(1, n + 1))
    main = np.argmax(sizes) + 1
    keep = lab == main
    # trim a label fused to the bottom: a sudden width drop in the last ~26 rows
    rows = keep.sum(1); full = rows.max(); ys_ = np.where(rows > 0)[0]; bot = ys_.max()
    for y in range(bot - 1, max(ys_.min(), bot - 26), -1):
        if rows[y] - rows[y + 1] > .35 * full and rows[y + 1] < .45 * full:
            keep[y + 1:] = False; break
    if name in ('clover', 'dice', 'lock'):   # label fused through a tapering edge
        ys2 = np.where(keep.any(1))[0]; keep[ys2.max() - 17:] = False
    my, _ = np.where(keep); mt, mb = my.min(), my.max()
    # keep sparkles and small parts that sit close to the main body
    near = nd.binary_dilation(keep, iterations=14)
    for k in range(1, n + 1):
        if k == main or sizes[k - 1] <= 25 or not (near & (lab == k)).any(): continue
        ky, _ = np.where(lab == k)
        if ky.min() > mb - 6 or ky.max() < mt + 6: continue   # a label below or above the icon
        keep |= lab == k
    keep = nd.binary_fill_holes(keep)
    # soft edge: inner ring fades by colour distance from the background
    d = dist[y0:y1, xs[0]:xs[1]]
    edge = keep & ~nd.binary_erosion(keep)
    a = keep.astype(float)
    a[edge] = np.clip((d[edge] - 20) / 40, .35, 1)
    ys, xs_ = np.where(keep)
    t, b_, l, rr = ys.min(), ys.max() + 1, xs_.min(), xs_.max() + 1
    rgb = np.asarray(img)[y0:y1, xs[0]:xs[1]][t:b_, l:rr]
    rgba = np.dstack([rgb, (a[t:b_, l:rr] * 255).astype(np.uint8)])
    piece = Image.fromarray(rgba, 'RGBA')
    S = int(max(piece.size) * 1.08) + 4
    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    canvas.paste(piece, ((S - piece.width) // 2, (S - piece.height) // 2))
    canvas.save(f'{out}/{name}.png')
    print(name, piece.size, 'touches window edge' if (t == 0 or l == 0 or rr == sub.shape[1] or b_ == sub.shape[0]) else '')
