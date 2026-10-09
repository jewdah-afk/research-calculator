"""Builds docs/build_bible/index.html (the Peckwood Build Bible page). The sound table comes straight from
roblox/tools/audio/candidates.json, so the page always matches AmbienceIds.luau. Run: python3 docs/build_bible/build.py"""
import json, os, html

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
cands = json.load(open(os.path.join(ROOT, 'roblox', 'tools', 'audio', 'candidates.json')))

USE = {
    'wind_soft': 'Bed. Always on outdoors, rises with gusts and breeze.', 'wind_gust': 'Shot. On each gust peak, max one per 8 s.',
    'leaves': 'Bed. Scales with trees within 40 studs x wind.', 'sea_shore': 'Bed. Fades in within 8 tiles of the coast.',
    'sea_far': 'Bed. Low wash everywhere, quieter on the shore.', 'birds_day': 'Bed. Day only, dawn chorus 5:00-8:30, ducks in rain.',
    'seagull': 'Shot. Near the coast by day, 3D.', 'bird_chirp': 'Shot. From the nearest tree, 3D.',
    'night_crickets': 'Bed. Night only.', 'night_owl': 'Shot. Night, far, 3D.', 'pond': '3D spot on the nearest inland water.',
    'rain_light': 'Bed. Follows the shared weather blend.', 'thunder_far': 'Shot. Only in heavy rain.',
    'cave_tone': 'Bed. Caves (full) and the Mine (low).', 'cave_drip': 'Shot. Caves and Mine, 3D around the hen.',
    'crystal_hum': 'Bed. Echo Field and crystal caves.', 'lamp_crackle': '3D spot on the 2 nearest lanterns, night only.',
    'step_grass': 'Hen footstep on grass (first 0.18 s of the take).', 'step_dirt': 'Footstep on paths and sand.',
    'step_wood': 'Footstep on decks, piers, bridges.', 'step_stone': 'Footstep in the Mine and caves.',
    'hen_cluck': 'No licensed chicken in the library. Slot stays silent until we pick or upload one.',
}

def sound_rows():
    out = []
    for slot, r in cands.items():
        p = r['picks']
        if p:
            first = p[0]
            pick = f'<code>{first["id"]}</code> {html.escape(first["name"])} <span class="dim">{first["dur"]:.1f} s · {html.escape(first["by"])}</span>'
            alt = f'{len(p) - 1} alternate{"s" if len(p) != 2 else ""}' if len(p) > 1 else 'none'
        else:
            pick, alt = '<span class="warn">empty</span>', ''
        out.append(f'<tr><td><code>{slot}</code></td><td>{r["kind"]}</td><td>{pick}</td><td class="dim">{alt}</td><td>{USE.get(slot, "")}</td></tr>')
    return '\n'.join(out)

KF = [  # golden preset, mirrors LightingPresets.golden.KF
    (0, 1.2, '3c4a78', '1e2440', '7c8cc8', '1c2850'), (5.6, 1.6, '7a6a8c', '2e2a40', 'ffb07a', 'e8a684'),
    (7, 2.6, '8c96b0', '36384a', 'ffd9a8', 'd6e0ec'), (11, 3.0, '96a6c2', '3a3e52', 'fff4e2', 'c4daf2'),
    (15, 3.0, '94a2be', '3a3e52', 'ffead0', 'cadff2'), (17.5, 3.2, '8e86a6', '33304a', 'ffa860', 'f2c49a'),
    (18.7, 2.4, '8a7ca4', '3a3456', 'ff8a5c', 'd08a86'), (20, 1.3, '3c4a78', '1e2440', '7c8cc8', '1c2850'),
]
def kf_rows():
    sw = lambda h: f'<span class="sw" style="background:#{h}"></span><code>#{h}</code>'
    return '\n'.join(f'<tr><td class="num">{int(h):02d}:{int(round((h % 1) * 60)):02d}</td><td class="num">{b}</td><td>{sw(o)}</td><td>{sw(a)}</td><td>{sw(c)}</td><td>{sw(f)}</td></tr>' for h, b, o, a, c, f in KF)

page = open(os.path.join(HERE, 'template.html')).read()
page = page.replace('<!--SOUND_ROWS-->', sound_rows()).replace('<!--KF_ROWS-->', kf_rows())
open(os.path.join(HERE, 'index.html'), 'w').write(page)
print('wrote', os.path.join(HERE, 'index.html'), len(page), 'bytes')
