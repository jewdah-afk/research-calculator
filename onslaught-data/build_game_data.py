"""Build game.json: the code-authoritative data both remakes run on.

defaults.json mirrors ModDefaults.as, which the original only applies when a mod is on.
The values below are the ones the turret classes and GameManager actually use (see MECHANICS.md).

Usage: python3 build_game_data.py
"""
import copy
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
d = json.loads((here / "defaults.json").read_text())
maps = json.loads((here / "maps.json").read_text())

T = copy.deepcopy(d["turrets"])
# code values that differ from ModDefaults
T["TurretBlue"]["upgrade_damage"]["amount"][7] = 18400
T["TurretFusion"]["weapon_damage"] = 1000000
T["TurretRed"]["weapon_must_face"] = False
T["TurretYellow"]["weapon_must_face"] = False

KIND = {
    "Blue": "TurretBlue", "Green": "TurretGreen", "Red": "TurretRed", "Yellow": "TurretYellow",
    "RangeUp": "TurretRangeUp", "DamageUp": "TurretDamageUp", "RateUpExchange": "TurretRateUpExchange",
    "RangeUpExchange": "TurretRangeUpExchange", "RateUp": "TurretRateUp", "DamageUpBig": "TurretDamageUpBig",
    "DamageUpBigExchange": "TurretDamageUpBigExchange", "Sniper": "TurretSniper", "Fusion": "TurretFusion",
    "Railgun": "TurretRailgun", "Targeter": "TurretTargeter", "Combonly": "TurretCombonly",
}
# GameManager.turrets_cost / turrets_unlock (no mod)
COST = {"Blue": 10, "Green": 15, "Red": 20, "Yellow": 50, "RangeUp": 2000, "DamageUp": 5000, "RateUpExchange": 1200,
        "RangeUpExchange": 1000, "RateUp": 3000, "DamageUpBig": 8500, "DamageUpBigExchange": 3500, "Targeter": 1400,
        "Sniper": 12000, "Fusion": 12000, "Railgun": 12000, "Combonly": 5000}
UNLOCK = {"RangeUp": 300, "DamageUp": 450, "RateUpExchange": 550, "RangeUpExchange": 700, "RateUp": 850,
          "DamageUpBig": 1000, "DamageUpBigExchange": 1100, "Targeter": 1200, "Sniper": 1300, "Fusion": 1400,
          "Railgun": 1500, "Combonly": 1600}
LABEL = {"Blue": "Blue Cannon", "Green": "Green Laser", "Red": "Red Rocket", "Yellow": "Yellow Tazer",
         "RangeUp": "Range Enhancer", "DamageUp": "Damage Enhancer", "RateUpExchange": "Rate Exchanger",
         "RangeUpExchange": "Range Exchanger", "RateUp": "Rate Enhancer", "DamageUpBig": "Big Damage Enhancer",
         "DamageUpBigExchange": "Big Damage Exchanger", "Sniper": "Sniper", "Fusion": "Fusion Cannon",
         "Railgun": "Railgun", "Targeter": "Targeter", "Combonly": "Combonly"}
KEYS = {"Blue": "1", "Green": "2", "Red": "3", "Yellow": "4", "RangeUp": "5", "DamageUp": "6", "RateUpExchange": "7",
        "RangeUpExchange": "8", "DamageUpBigExchange": "9", "RateUp": "!", "DamageUpBig": "@", "Targeter": "$",
        "Sniper": "%", "Fusion": "^", "Railgun": "&", "Combonly": "*"}


def up(v):
    return {"cost": list(v["cost"]), "amount": list(v["amount"])} if v else {"cost": [], "amount": []}


turrets = {}
for k, src in KIND.items():
    s = T.get(src, {})
    t = {
        "label": LABEL[k], "key": KEYS[k], "cost": COST[k], "unlock": UNLOCK.get(k, 0),
        "damage": s.get("weapon_damage", 0), "range": s.get("weapon_range", 80), "rate": s.get("weapon_rate", 0),
        "poison": s.get("weapon_poison", 0), "rotate": s.get("weapon_rotate", 270),
        "mustFace": s.get("weapon_must_face", True),
        "up": {"damage": up(s.get("upgrade_damage")), "range": up(s.get("upgrade_range")), "rate": up(s.get("upgrade_rate"))},
        "freak": bool(s.get("freak_capable", False)),
        "freakLevel": {"damage": s.get("freak_level_damage", 4), "range": s.get("freak_level_range", 0), "rate": s.get("freak_level_rate", 4)},
        "modifiable": s.get("modify_possible", True), "comboNever": s.get("combo_never", False),
        "type": "weapon",
    }
    if k.startswith(("Range", "Damage", "Rate")):
        t.update(type="modifier", modifiable=False, comboNever=True, damage=0, rate=0, mustFace=False,
                 modify={"damage": s.get("modify_up_damage", 0), "range": s.get("modify_up_range", 0), "rate": s.get("modify_up_rate", 0),
                         "damage_mult": s.get("modify_up_damage_mult", 0), "range_mult": s.get("modify_up_range_mult", 0),
                         "rate_mult": s.get("modify_up_rate_mult", 0)})
    if k in ("Sniper", "Fusion", "Railgun"):
        t.update(modifiable=False, comboNever=True, freak=False, rotate=90, mustFace=True)
    turrets[k] = t

turrets["Targeter"].update(type="targeter", damage=0, range=120, rate=240, rotate=360, mustFace=True, comboNever=True,
                           up={"damage": up(None), "range": {"cost": [250, 350, 500, 700], "amount": [140, 170, 200, 230]}, "rate": up(None)})
turrets["Combonly"].update(type="combonly", damage=0, range=300, rate=250, rotate=270, mustFace=True, comboNever=True,
                           up={"damage": up(None), "range": up(None), "rate": up(None)})

challenges = [
    {"name": "Warmup", "difficulty": "easy", "objective": None, "cash": 30, "timelimit": 60, "turretlimit": None, "wavesize": "10", "wavespeed": "60"},
    {"name": "Threetown", "difficulty": "easy", "objective": "w,300", "cash": 30, "timelimit": None, "turretlimit": None, "wavesize": "10", "wavespeed": "60"},
    {"name": "Spiffles", "difficulty": "hard", "objective": "w,100", "cash": 30, "timelimit": 1200, "turretlimit": None, "wavesize": "10", "wavespeed": "60"},
    {"name": "Limitations", "difficulty": "medium", "objective": "w,300", "cash": 30, "timelimit": None, "turretlimit": 15, "wavesize": "10", "wavespeed": "60"},
    {"name": "Problem3", "difficulty": "easy", "objective": "k,3000", "cash": 3000, "timelimit": 1200, "turretlimit": None, "wavesize": "3", "wavespeed": "90"},
    {"name": "Bounce", "difficulty": "medium", "objective": "k,4000", "cash": 3000, "timelimit": 1200, "turretlimit": None, "wavesize": "10,9,8,7,6,5,4,3,2,1", "wavespeed": "60"},
    {"name": "Bludgeon", "difficulty": "hard", "objective": None, "cash": 30, "timelimit": 900, "turretlimit": 15, "wavesize": "1", "wavespeed": "90"},
    {"name": "Longshine", "difficulty": "medium", "objective": "k,1000", "cash": 500, "timelimit": None, "turretlimit": 10, "wavesize": "1,2,3", "wavespeed": "60"},
    {"name": "Speedshine", "difficulty": "medium", "objective": "k,1000", "cash": 500, "timelimit": None, "turretlimit": 10, "wavesize": "1,2,3", "wavespeed": "120"},
    {"name": "Hardshine", "difficulty": "hard", "objective": "k,1000", "cash": 500, "timelimit": None, "turretlimit": 10, "wavesize": "1,2,3", "wavespeed": "120"},
    {"name": "Duration", "difficulty": "hard", "objective": "w,500", "cash": 30, "timelimit": 1800, "turretlimit": None, "wavesize": "10", "wavespeed": "60"},
    {"name": "Clockers", "difficulty": "hard", "objective": None, "cash": 30, "timelimit": 1200, "turretlimit": 8, "wavesize": "10,10,10,1", "wavespeed": "90"},
    {"name": "Ripples", "difficulty": "medium", "objective": "w,500", "cash": 30, "timelimit": 1800, "turretlimit": None, "wavesize": "10", "wavespeed": "60,40"},
    {"name": "Smollocks", "difficulty": "hard", "objective": "w,500", "cash": 30, "timelimit": 1800, "turretlimit": 15, "wavesize": "10", "wavespeed": "60,40"},
]

gs = d["game_settings"]
game = {
    "version": "2350-gaby",
    "turrets": turrets,
    "buildOrder": ["Blue", "Green", "Red", "Yellow", "RangeUp", "DamageUp", "RateUpExchange", "RangeUpExchange", "RateUp",
                   "DamageUpBig", "DamageUpBigExchange", "Targeter", "Sniper", "Fusion", "Railgun", "Combonly"],
    "combos": d["combos"],
    "hpRate": {k: {"wave": gs["attacker_hp_rate_" + k]["wave"], "rate": gs["attacker_hp_rate_" + k]["rate"]} for k in ("easy", "medium", "hard", "extreme")},
    "speed": {"easy": 60, "medium": 60, "hard": 80, "extreme": 80},
    "startingCash": {"easy": 30, "medium": 30, "hard": 30, "extreme": 30, "sandbox": 100000, "sandbox2": 1000000},
    "settings": {"waveSpacing": 20000, "waveSize": 10, "attackerSpacing": 700, "attackerEnergy": 10, "lives": 10,
                 "resale": 0.7, "moveCost": 500, "comboRange": 70, "linkMult": 1.25},
    "blasts": {"tiny": [60, 70], "small": [70, 100], "medium": [80, 160], "large": [80, 190], "huge": [90, 250],
               "poison": [80, 190], "bfg": [80, 190], "shockwave": [105, 200]},
    "challenges": challenges,
    "maps": maps,
    "mapOrder": ["map1", "map2", "map3", "map4", "map5", "map6", "map7", "map8", "map9", "map10", "map11", "map12"],
}
(here / "game.json").write_text(json.dumps(game, indent=1))
print("wrote game.json:", len(turrets), "turrets,", len(game["combos"]), "combos,", len(challenges), "challenges,", len(maps), "maps")
