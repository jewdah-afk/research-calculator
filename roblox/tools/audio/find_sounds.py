"""Pick licensed Creator Store sounds for every ambience / footstep slot (tools/audio/find_sounds.py).
Searches the Roblox toolbox (audio = category 3) through the session proxy, keeps only free sounds from verified
licensed libraries, checks duration against the slot (loops long, one-shots short) and writes the top picks to
src/client/AmbienceIds.luau + tools/audio/candidates.json. Re-run any time; the owner picks by ear in Studio."""
import json, re, sys, time, urllib.parse, urllib.request, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LICENSED = {'ProSoundEffects', 'APM Music', 'Roblox', 'Monstercat', 'SoundsOfRoblox'}
# slot: (queries, min s, max s, kind)  kind: bed (looping layer) | shot (one-shot, randomised)
SLOTS = {   # slot: (queries, min s, max s, kind, must-match regex on the title, must-not regex)
    'wind_soft':     (['wind ambience', 'light breeze', 'wind meadow', 'wind field', 'wind gentle'], 20, 900, 'bed', r'wind|breeze', r'stream|engine|interior|storm|howl|attic|fire|leaves|window|plasma|vocal|lips'),
    'wind_gust':     (['wind gust', 'wind gusts', 'wind'], 1.5, 20, 'shot', r'wind', r'engine|car|instrument|chime|vocal|lips|mouth'),
    'leaves':        (['leaves rustle wind', 'trees rustling', 'foliage rustle', 'forest wind leaves'], 10, 900, 'bed', r'leaves|leaf|rustl|foliage|tree', r'step|walk|footstep'),
    'sea_shore':     (['gentle waves shore', 'waves lapping beach', 'waves beach', 'surf beach gentle', 'ocean waves'], 20, 900, 'bed', r'wave|surf|shore|beach|lap', r'boat|stern|harbor|engine|storm|heavy|big|impact'),
    'sea_far':       (['ocean surf', 'surf', 'ocean', 'waves crashing', 'sea shore'], 20, 900, 'bed', r'surf|ocean|sea\b|waves', r'boat|engine|harbor|underwater|stern'),
    'birds_day':     (['birds chirping', 'birdsong', 'morning birds', 'meadow birds', 'countryside birds'], 20, 900, 'bed', r'bird', r'city|traffic|neighborhood|cricket|desert'),
    'seagull':       (['seagull', 'seagulls', 'gull call'], 0.5, 10, 'shot', r'gull', r''),
    'bird_chirp':    (['bird chirp', 'songbird', 'bird tweet', 'bird call', 'sparrow', 'finch'], 0.3, 5, 'shot', r'bird|sparrow|finch|robin|wren|cockatiel', r'robot|servo|toy|alien|electronic|goat|hawk|screech'),
    'night_crickets':(['crickets', 'crickets night', 'night insects'], 20, 900, 'bed', r'cricket|katydid', r'jungle|bird|city|desert'),
    'night_owl':     (['owl hoot', 'owl'], 0.5, 8, 'shot', r'owl', r''),
    'pond':          (['babbling brook', 'small stream', 'water trickle', 'creek'], 10, 900, 'bed', r'brook|stream|trickle|creek|pond', r'heavy|rapids|sewer'),
    'rain_light':    (['light rain', 'rain on leaves', 'gentle rain', 'rain ambience'], 20, 900, 'bed', r'rain', r'heavy|fire|storm|car|roof|tin|thunder'),
    'thunder_far':   (['distant thunder', 'thunder rumble', 'thunder'], 2, 25, 'shot', r'thunder', r''),
    'cave_tone':     (['cave ambience', 'cavern', 'cave', 'underground', 'cave drips', 'mine ambience'], 15, 900, 'bed', r'cave|cavern|underground|grotto|mine shaft', r'engine|machine'),
    'cave_drip':     (['water drip', 'water drop', 'drip cave'], 0.15, 4, 'shot', r'drip|drop', r'faucet|sink|tap|bucket|mouth'),
    'crystal_hum':   (['magical shimmer', 'magic sparkle loop', 'crystal hum', 'magic ambience', 'shimmer pad'], 5, 900, 'bed', r'shimmer|sparkl|magic|crystal|ethereal|harmonic|glow', r'hit|impact|whoosh|cast'),
    'lamp_crackle':  (['fire crackle small', 'campfire', 'torch fire', 'candle'], 5, 900, 'bed', r'crackl|campfire|torch|candle|fireplace', r'rain of fire|explosion|gun'),
    'step_grass':    (['tip toe onto grass', 'footsteps grass', 'grass'], 0.08, 4, 'shot', r'grass', r'cut|mow|blade|soccer|ball'),
    'step_dirt':     (['rock hits dirt', 'dirt impact', 'gravel impact', 'sand impact'], 0.08, 4, 'shot', r'dirt|gravel|sand', r'heavy|big|explosion|shovel|body'),
    'step_wood':     (['wood muted thud', 'wood tap', 'wood knock light', 'wood grab muted thuds'], 0.08, 4, 'shot', r'wood', r'crack|splinter|heavy|break|falls|bicycle'),
    'step_stone':    (['pebble tap', 'stone tap', 'rock tap', 'small rock hit'], 0.08, 4, 'shot', r'pebble|stone|rock', r'heavy|big|explosion|slide|avalanche|music'),
    'hen_cluck':     (['chicken cluck', 'chicken', 'chickens', 'hen clucking', 'farm chicken'], 0.2, 6, 'shot', r'chicken|\bhen|cluck|poultry', r'rubber|toy'),
}

def get(url):
    for a in range(4):
        try:
            with urllib.request.urlopen(url, timeout=25) as r: return json.load(r)
        except Exception as e:
            time.sleep(2 ** a)
    return None

def duration(desc):
    m = re.search(r'Duration:\s*([\d.]+)\s*seconds', desc or '')
    if m: return float(m.group(1))
    m = re.search(r'Duration:\s*(\d+):(\d+)', desc or '')
    return int(m.group(1)) * 60 + int(m.group(2)) if m else None

def search(q, n=60):
    d = get('https://apis.roblox.com/toolbox-service/v1/marketplace/3?' + urllib.parse.urlencode({'keyword': q, 'limit': n}))
    return [x['id'] for x in (d or {}).get('data', [])]

def details(ids):
    out = []
    for k in range(0, len(ids), 30):
        d = get('https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=' + ','.join(map(str, ids[k:k + 30])))
        out += (d or {}).get('data', [])
    return out

result = {}
for slot, (queries, lo, hi, kind, must, mustnot) in SLOTS.items():
    seen, picks = set(), []
    for q in queries:
        ids = [i for i in search(q) if i not in seen]; seen.update(ids)
        for it in details(ids):
            a, c = it['asset'], it['creator']
            if c['name'] not in LICENSED or not c.get('isVerifiedCreator'): continue
            if not it.get('fiatProduct', {}).get('isFree', True): continue
            ad = a.get('audioDetails') or {}
            text = a['name'].lower()   # titles only: tags are too loose (a saxophone tagged "chicken")
            if not re.search(must, text) or (mustnot and re.search(mustnot, text)): continue
            dur = duration(a.get('description'))
            if dur is None or not (lo <= dur <= hi): continue
            picks.append({'id': a['id'], 'name': a['name'], 'by': c['name'], 'dur': dur, 'q': q})
        if len(picks) >= 8: break
    # one-shots: shortest clean takes first; beds: longest first (fewer audible loop seams)
    picks.sort(key=lambda p: -p['dur'] if kind == 'bed' else p['dur'])
    result[slot] = {'kind': kind, 'picks': picks[:4]}
    print(f"{slot:15s} {len(picks):2d} found  " + ' | '.join(f"{p['id']} {p['name'][:40]} ({p['dur']:.1f}s)" for p in picks[:4]), flush=True)

json.dump(result, open(os.path.join(ROOT, 'tools', 'audio', 'candidates.json'), 'w'), indent=1)
lines = ['--!strict', '-- AmbienceIds: GENERATED by tools/audio/find_sounds.py (licensed Creator Store sounds, free, verified',
         '-- libraries only). [1] is used; the rest are alternates for the owner to audition in Studio. 0 = slot empty (silent).',
         'return {']
for slot, r in result.items():
    ids = [p['id'] for p in r['picks']] or [0]
    names = ' | '.join(f"{p['name']} {p['dur']:.1f}s" for p in r['picks'][:2]) or 'none found'
    lines.append(f"\t{slot} = {{ {', '.join(map(str, ids))} }},   -- {r['kind']}: {names}")
lines.append('}')
open(os.path.join(ROOT, 'src', 'client', 'AmbienceIds.luau'), 'w').write('\n'.join(lines) + '\n')
