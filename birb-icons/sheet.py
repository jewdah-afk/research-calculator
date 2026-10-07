"""Contact sheet of renders on the UI's dark panel colour, for review."""
import sys, glob, os
from PIL import Image
d = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'renders')
fs = sorted(glob.glob(d + '/*.png')) if len(sys.argv) < 3 else [f'{d}/{n}.png' for n in sys.argv[2:]]
S = 200; cols = min(6, len(fs)); rows = (len(fs) + cols - 1) // cols
im = Image.new('RGBA', (cols * (S + 20) + 20, rows * (S + 20) + 20), (43, 33, 22, 255))
for i, f in enumerate(fs):
    t = Image.open(f).resize((S, S), Image.LANCZOS)
    im.paste(t, (20 + (i % cols) * (S + 20), 20 + (i // cols) * (S + 20)), t)
im.save(sys.argv[1]); print(len(fs))
