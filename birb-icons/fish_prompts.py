"""Build 4x4 sheet prompts for every fish in birb-data/data/fish.json (16 per sheet, data order).
python3 birb-icons/fish_prompts.py  -> sheets/fish_prompts.json [{sheet, names, prompt}]"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
fish = json.load(open(os.path.join(HERE, '..', 'birb-data', 'data', 'fish.json')))
TYPE = {'coastal': 'coastal sea fish', 'reef': 'tropical reef fish', 'freshwater': 'freshwater lake fish', 'river': 'river fish',
        'ocean': 'big open-ocean fish', 'creature': 'cute sea creature', 'exotic_reef': 'exotic neon reef fish', 'spirit': 'ghostly translucent spirit fish with soft glow',
        'cosmic': 'cosmic fish with starry galaxy pattern', 'mechanical': 'robotic mechanical fish with bolts and gears', 'crab': 'crab or crustacean',
        'abyssal': 'deep-sea abyssal fish with bioluminescent glow', 'expedition': 'adventure fish from a fantasy dungeon', None: 'special fish'}
RAR = {'common': 'simple', 'uncommon': 'slightly fancy', 'rare': 'fancy with shiny fins', 'epic': 'epic with ornate fins and a purple sparkle',
       'legendary': 'legendary, majestic, with golden accents and a radiant aura', 'mythic': 'mythic, awe-inspiring, with a rainbow crimson aura and sparkles'}
SHAPES = ['round chubby', 'long slender', 'tall diamond-shaped', 'puffy', 'torpedo-shaped', 'flat oval', 'big-headed', 'fan-tailed']
def desc(f, i):
    fid = f['id'][5:] if f['id'].startswith('fish_') else f['id']
    words = fid.replace('_', ' ')
    shape = SHAPES[i % len(SHAPES)] + ' body, ' if f['id'].startswith('fish_') else ''
    return f"a {RAR[f['rarity']]} {words} fish ({shape}{TYPE[f.get('type')]}, main colour {f['color']})"
out = []
for s in range(0, len(fish), 16):
    grp = fish[s:s + 16]
    cells = '; '.join(f"{i + 1} {desc(f, i)}" for i, f in enumerate(grp))
    prompt = ("Game icon sheet: a strict 4x4 grid of 16 fish icons on a solid pure black background (#000000), each icon centred in its own cell "
              "with wide black gaps, nothing overlapping or touching cell edges. Every fish is a DIFFERENT, unique, recognisable design matching its name, "
              "drawn side view facing right with a big cute glossy eye. Art style: glossy chunky mobile-game icons (Brawl Stars / Clash Royale), vinyl-toy look, "
              "saturated colours, three cel bands, white glossy specular highlight top-left, thin rim light, thick even near-black outline around each silhouette. "
              "Rarer fish look more impressive. Reading order left-to-right, top-to-bottom: " + cells + ". Empty cells stay black. No text, no ground, no shadows, no scenery.")
    out.append({'sheet': f'fish_{s // 16 + 1:02d}', 'names': [f['id'] for f in grp], 'prompt': prompt})
json.dump(out, open(os.path.join(HERE, 'sheets', 'fish_prompts.json'), 'w'), indent=1)
print(len(out), max(len(o['prompt']) for o in out))
