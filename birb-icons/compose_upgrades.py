"""Upgrade-row icons: the current icon + a painted badge (final/badge_*.png) on the lower right, merged into ONE
silhouette and re-ringed by clean_ring so icon and badge share the same crisp ink outline as every other icon.
Run: python3 birb-icons/compose_upgrades.py   -> final/up_<name>.png"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clean_ring

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, 'final')
SIZE, BADGE, INSET = 256, 112, 10  # badge box (px at 256) and its offset from the bottom-right corner
BASE_SCALE = 0.9                   # shrink the base a little toward the top-left so the badge has room

UPGRADES = {
    'egg_value': ('egg', 'up'), 'egg_speed': ('egg', 'speed'), 'egg_cap': ('shop_carton', 'cap'),
    'egg_mult': ('egg', 'mult'), 'hatch_speed': ('shop_hatch', 'speed'), 'basket_value': ('shop_basket', 'up'),
    'plume_value': ('plume', 'up'), 'seed_value': ('seed', 'up'), 'seed_speed': ('seed', 'speed'),
    'golden_value': ('egg_golden', 'up'), 'silo_cap': ('shop_crateL', 'cap'), 'golden_mult': ('shop_goldtouch', 'mult'),
    'mining_power': ('crow_miner', 'power'), 'ore_value': ('ore', 'up'),
    'twig_value': ('twig', 'up'), 'twig_speed': ('twig', 'speed'), 'twig_power': ('twig', 'power'),
    'echo_value': ('echo', 'up'), 'echo_cap': ('echo', 'cap'),
    'heart_value': ('stat_heart', 'up'), 'heart_regen': ('stat_heart', 'regen'), 'sword_power': ('stat_sword', 'power'),
}

def compose(name, base, badge):
    b = Image.open(os.path.join(FINAL, base + '.png')).convert('RGBA')
    s = int(SIZE * BASE_SCALE)
    out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(b.resize((s, s), Image.LANCZOS), (0, 0))
    g = Image.open(os.path.join(FINAL, 'badge_' + badge + '.png')).convert('RGBA').resize((BADGE, BADGE), Image.LANCZOS)
    out.alpha_composite(g, (SIZE - BADGE - INSET, SIZE - BADGE - INSET))
    path = os.path.join(FINAL, 'up_' + name + '.png')
    # clean_ring reads its source from final_pre_ring/, so the merged art goes there and the ringed copy to final/
    pre = os.path.join(clean_ring.BACKUP, 'up_' + name + '.png')
    os.makedirs(clean_ring.BACKUP, exist_ok=True)
    out.save(pre); out.save(path)
    clean_ring.clean(path, 'up_' + name)

if __name__ == '__main__':
    for n, (base, badge) in UPGRADES.items():
        compose(n, base, badge); print(n)
