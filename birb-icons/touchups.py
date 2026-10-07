"""Small hand additions on top of the cut icons. Run after cut_sheet.py (and seed.py)."""
import os
from PIL import Image, ImageDraw
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final')

def fish_mouth():
    """Goldfish 'o' mouth at the nose (the sheet's fish had none)."""
    p = os.path.join(D, 'fish.png'); im = Image.open(p).convert('RGBA')
    k = 4; big = im.resize((im.width * k, im.height * k), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    cx, cy = 230 * k, 140 * k                      # just under the nose tip, facing right
    d.ellipse([cx - 13 * k, cy - 11 * k, cx + 9 * k, cy + 11 * k], fill=(11, 12, 16, 255))          # ink rim
    d.ellipse([cx - 10 * k, cy - 8 * k, cx + 6 * k, cy + 8 * k], fill=(255, 150, 120, 255))         # lips
    d.ellipse([cx - 6 * k, cy - 4.5 * k, cx + 3 * k, cy + 4.5 * k], fill=(120, 22, 30, 255))        # open mouth
    d.ellipse([cx - 8 * k, cy - 7 * k, cx - 3 * k, cy - 3 * k], fill=(255, 220, 205, 255))          # lip shine
    big.resize(im.size, Image.LANCZOS).save(p)

fish_mouth()
print('touchups done')
