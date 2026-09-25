# Rebuilds game-js/ (the web game's JavaScript, one file per original source file) from the single-file HTML build
# of The Milestone Tree NG+. Each inline <script> is recognised by its content, so a newer build of the page works
# as long as its files keep their shape.
#   python3 port/tools/extract_html.py milestone-tree-ng.html game-js
# The single-file build inlines three images; they are put back as the paths the original files use
# (resources/*.png, zones/*.svg) so the transpiled game refers to them the same way.
import re, sys, os

SIGNS = [  # (pattern at the start of the script, file)
    (r'^\s*/\*!\s*\n?\s*\*\s*Vue\.js', None),
    (r'^\s*\(function \(global, factory\)', 'technical/break_eternity.js'),
    (r'^\s*let modInfo = \{', 'mod.js'),
    (r'^\s*window\.ZONE_SVG\s*=', 'zone_svg.js'),
    (r'^\s*var modal = \{', 'technical/modal.js'),
    (r'^\s*var tmp = \{\}', 'technical/temp.js'),
    (r'^\s*function prestigeButtonText\(', 'technical/displays.js'),
    (r'^\s*var player;', 'game.js'),
    (r'^\s*// \*+ Big Feature related', 'utils.js'),
    (r'^\s*function hasUpgrade\(', 'utils/easyAccess.js'),
    (r'^\s*var systemComponents = \{', 'components.js'),
    (r'^\s*var app;\s*\n\s*function loadVue', 'technical/loader_v.js'),
    (r'^\s*var canvas;', 'technical/canvas.js'),
    (r'^\s*var particles = \{\}', 'technical/particleSystem.js'),
    (r'^\s*function addCommas\(', 'utils/NumberFormating.js'),
    (r'^\s*// \*+ Options \*+', 'utils/options.js'),
    (r'^\s*// \*+ Save stuff \*+', 'utils/save.js'),
    (r'^\s*// \*+ Themes \*+', 'utils/themes.js'),
    (r'^\s*var layoutInfo = \{', 'tree.js'),
]

def name_for(src):
    for pat, f in SIGNS:
        if re.search(pat, src[:400]):
            return f
    m = re.search(r'addLayer\("([\w-]+)"', src)
    if m:
        return 'technical/layerSupport.js' if m.group(1) == 'info-tab' else 'layers/%s.js' % m.group(1)
    return '__unknown'

def restore(f, s):
    if f == 'layers/cp.js':
        s = re.sub(r'url\("data:image/png;base64,[A-Za-z0-9+/=]+"\)', 'url("resources/corrupt_active.png")', s, count=1)
        s = re.sub(r'return "data:image/png;base64,[A-Za-z0-9+/=]+"', 'return "resources/warning.png"', s, count=1)
    if f == 'layers/ex.js':
        s = s.replace("${ZONE_SVG[player.ex.zone+'-'+player.ex.points.min(checkIfMaxExploreBonus())+'.svg']}",
                      'zones/${player.ex.zone}-${player.ex.points.min(checkIfMaxExploreBonus())}.svg')
    return s

html = open(sys.argv[1], encoding='utf-8').read()
out = sys.argv[2]
seen = {}
for src in re.findall(r'<script>(.*?)</script>', html, re.S):
    f = name_for(src)
    if f is None:
        continue
    if f == '__unknown':
        print('unrecognised script:', src[:80].replace('\n', ' '))
        continue
    if f in seen:
        print('two scripts look like', f)
    seen[f] = True
    p = os.path.join(out, f)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w', encoding='utf-8').write(restore(f, src))
print('wrote', len(seen), 'files to', out)
