"""Small hand additions on top of the cut icons. Run after cut_sheet.py (and seed.py)."""
import os
from PIL import Image, ImageDraw
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final')

def fish_mouth():
    """Goldfish smile: a curved ink line that starts IN the head outline at the nose and curves back into the face."""
    p = os.path.join(D, 'fish.png'); im = Image.open(p).convert('RGBA')
    import numpy as np
    a = np.asarray(im)[..., 3]
    y0 = 140                                                   # row just below the eye
    ex = int(np.nonzero(a[y0] > 200)[0].max())                 # outer edge of the outline at that row
    k = 4; big = im.resize((im.width * k, im.height * k), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    P0, C, P2 = (ex - 4, y0 - 1), (ex - 10, y0 + 9), (ex - 22, y0 + 3)   # start inside the outline ring
    pts = [((1-t)**2*P0[0] + 2*(1-t)*t*C[0] + t*t*P2[0], (1-t)**2*P0[1] + 2*(1-t)*t*C[1] + t*t*P2[1]) for t in [i/24 for i in range(25)]]
    pts = [(x * k, y * k) for x, y in pts]
    w = 5 * k
    d.line(pts, fill=(11, 12, 16, 255), width=w, joint='curve')
    for x, y in (pts[0], pts[-1]): d.ellipse([x - w/2, y - w/2, x + w/2, y + w/2], fill=(11, 12, 16, 255))
    big.resize(im.size, Image.LANCZOS).save(p)

fish_mouth()
print('touchups done')
