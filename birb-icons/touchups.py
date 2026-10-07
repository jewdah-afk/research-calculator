"""Small hand additions on top of the cut icons. Run after cut_sheet.py (and seed.py)."""
import os
from PIL import Image, ImageDraw
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final')

def fish_mouth():
    """Simple goldfish smile: a short curved ink line under the eye, near the nose."""
    p = os.path.join(D, 'fish.png'); im = Image.open(p).convert('RGBA')
    k = 4; big = im.resize((im.width * k, im.height * k), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    cx, cy, r = 220 * k, 132 * k, 15 * k          # smile arc centre, facing right
    d.arc([cx - r, cy - r, cx + r, cy + r], start=15, end=115, fill=(11, 12, 16, 255), width=4 * k)
    big.resize(im.size, Image.LANCZOS).save(p)

fish_mouth()
print('touchups done')
