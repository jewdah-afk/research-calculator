"""Inline every image in ./assets as a data URI -> worlds_hero.html (one self-contained file for the Artifact).
Usage: python build.py"""
import base64, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'worlds_hero.src.html'), encoding='utf-8').read()
assets = {}
for f in sorted(os.listdir(os.path.join(HERE, 'assets'))):
    if f.endswith('.webp'):
        assets[f[:-5]] = 'data:image/webp;base64,' + base64.b64encode(open(os.path.join(HERE, 'assets', f), 'rb').read()).decode()
assert src.count('const A = /*ASSETS*/null') == 1
out = src.replace('const A = /*ASSETS*/null', 'const A = ' + json.dumps(assets, separators=(',', ':')), 1)
open(os.path.join(HERE, 'worlds_hero.html'), 'w', encoding='utf-8').write(out)
print(f'{len(assets)} assets, {len(out) / 1e6:.2f} MB')
