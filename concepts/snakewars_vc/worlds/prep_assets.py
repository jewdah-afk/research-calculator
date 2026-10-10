"""Prepare the Worlds prototype's images as small .webp files in ./assets (flat, one file per asset key).
The page (worlds_hero.src.html) loads assets/<key>.webp; build.py inlines the same files as data URIs.

Sources (nothing here is re-rendered):
  --scenery  dir with <world>_{far,mid,fg}.png from tools/boss3d/scenery.py (rendered at 800x360, 8 samples)
  --sw       the snakewars-25d repo (owner icons, egg renders)
  guardians  ../3d/bosses/<id>_look.png + <id>_still.png (tools/boss3d/guardian.py)
  before     ../before/*.png (current Figma frames + the hub backdrop)
Usage: python prep_assets.py --scenery <dir> --sw <snakewars-25d>"""
import argparse, os, colorsys
from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser(); ap.add_argument('--scenery', required=True); ap.add_argument('--sw', required=True)
a = ap.parse_args()
OUT = os.path.join(HERE, 'assets'); os.makedirs(OUT, exist_ok=True)
BOSS = os.path.join(HERE, '..', '3d', 'bosses'); BEFORE = os.path.join(HERE, '..', 'before')

def save(im, key, q=84, lossless=False):
    p = os.path.join(OUT, key + '.webp'); im.save(p, 'WEBP', quality=q, method=6, lossless=lossless); return os.path.getsize(p)

def fit(im, size):
    im = im.copy(); im.thumbnail((size, size), Image.LANCZOS); return im

def void_azure(im):
    """The Void renders clipped the azure tier colour (#4FA8FF, emission > 1) toward cyan. Teal/cyan is Starfall's, so
    shift those pixels back to the azure hue (212 deg); value and alpha stay."""
    arr = np.asarray(im.convert('RGBA')).astype(np.float32) / 255
    rgb = arr[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx); m = d > 1e-6
    hr = (mx == r) & m; hg = (mx == g) & m & ~hr; hb = m & ~hr & ~hg
    h[hr] = ((g - b)[hr] / d[hr]) % 6; h[hg] = (b - r)[hg] / d[hg] + 2; h[hb] = (r - g)[hb] / d[hb] + 4
    h = h * 60
    sel = (h > 165) & (h < 205) & (s > .18)
    nh = 212 / 60; ns = np.clip(s * 1.15, 0, 1); v = mx
    c = v * ns; x = c * (1 - abs(nh % 2 - 1)); m0 = v - c          # hue 212 lies in sector 3 (180-240): (0, x, c)
    out = rgb.copy(); out[..., 0] = np.where(sel, m0, r); out[..., 1] = np.where(sel, x + m0, g); out[..., 2] = np.where(sel, c + m0, b)
    arr[..., :3] = out
    return Image.fromarray((arr * 255 + .5).astype(np.uint8), 'RGBA')

total = 0
# scenery layers
for w in ('meadow', 'tidepool', 'crystal', 'frost', 'magma', 'void', 'candy', 'starfall', 'core'):
    for L in ('far', 'mid', 'fg'):
        im = Image.open(os.path.join(a.scenery, f'{w}_{L}.png')).convert('RGBA')
        if w == 'void': im = void_azure(im)
        if L != 'far' and im.getchannel('A').getbbox() is None: continue        # empty foreground layer: skip
        total += save(im.convert('RGB') if L == 'far' else im, f'scn_{w}_{L}', q=86)
# guardian look-around flipbooks (17 frames, 5 cols, yaw -40..+40) at 288 px cells, and the stills
for g in ('oakcoil', 'coralcrown', 'prismara', 'blizzara', 'ignis', 'voidwarden'):
    sh = Image.open(os.path.join(BOSS, f'{g}_look.png')).convert('RGBA')
    total += save(sh.resize((5 * 288, 4 * 288), Image.LANCZOS), f'look_{g}', q=88)
    st = Image.open(os.path.join(BOSS, f'{g}_still.png')).convert('RGBA')
    total += save(fit(st, 320), f'still_{g}', q=88)
# Void Warden head crop for the rail (the Void has no egg)
st = Image.open(os.path.join(BOSS, 'voidwarden_still.png')).convert('RGBA'); bb = st.getchannel('A').getbbox()
x0, y0, x1, y1 = bb; side = int((x1 - x0) * .78); cx = (x0 + x1) // 2
total += save(fit(st.crop((cx - side // 2, y0, cx + side // 2, y0 + side)), 192), 'ico_warden', q=88)
# egg renders (Candy Canyon has no egg yet: season_s2 stands in, PLACEHOLDER, same as the Figma file)
for k, src in (('sprout', 'sprout'), ('tide', 'tide'), ('crystal', 'crystal'), ('frostbite', 'frostbite'), ('magma', 'magma'),
               ('candy', 'season_s2'), ('starfall', 'starfall'), ('core', 'core')):
    im = Image.open(os.path.join(a.sw, 'assets', 'eggs', 'previews', f'{src}_thumb.png')).convert('RGBA')
    total += save(fit(im, 288), f'egg_{k}', q=88)
# owner icons (3D-style renders, assets/icons)
for k in ('trophy', 'worlds', 'lock', 'check', 'crown', 'close', 'plus', 'length', 'skins', 'star', 'clock', 'flag'):
    im = Image.open(os.path.join(a.sw, 'assets', 'icons', f'{k}_256.png' if os.path.exists(os.path.join(a.sw, 'assets', 'icons', f'{k}_256.png')) else f'{k}.png')).convert('RGBA')
    total += save(fit(im, 128), f'ico_{k}', q=90)
# hub backdrops (dimmed behind the popup) and the BEFORE frames
total += save(Image.open(os.path.join(BEFORE, 'hud_hub_desktop.png')).convert('RGB'), 'hub_desktop', q=78)
total += save(Image.open(os.path.join(BEFORE, 'hud_hub_phone_v2.png')).convert('RGB'), 'hub_phone', q=78)
total += save(Image.open(os.path.join(BEFORE, 'worlds_desktop.png')).convert('RGB'), 'before_desktop', q=82)
total += save(Image.open(os.path.join(BEFORE, 'worlds_phone.png')).convert('RGB'), 'before_phone', q=88)
print(f'{len(os.listdir(OUT))} files, {total / 1e6:.2f} MB')
