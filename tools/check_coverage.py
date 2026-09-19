#!/usr/bin/env python3
"""Reverse fidelity: every leaf number in a source JSON's `data` object must
appear in the generated module, unless it is in that module's `omitted` manifest
(paths that were null in the source and are therefore deliberately absent).

Usage: check_coverage.py <luau_dir> <json_dir>
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luau_dump

MODULES = {
    "characters.json":          "Characters",
    "core_loop.json":           "CoreLoop",
    "enemies_waves.json":       "EnemiesWaves",
    "passives_evolutions.json": "PassivesEvolutions",
    "pickups_meta.json":        "PickupsMeta",
    "weapons.json":             "Weapons",
}
DISPLAY_SCALE = 10


def leaves(o, path, acc):
    if isinstance(o, bool) or o is None:
        return acc
    if isinstance(o, (int, float)):
        acc.append((path, float(o)))
    elif isinstance(o, dict):
        for k, v in o.items():
            leaves(v, "{}.{}".format(path, k), acc)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            leaves(v, "{}[{}]".format(path, i), acc)
    return acc


def main():
    luau_dir, json_dir = sys.argv[1], sys.argv[2]
    bad = 0
    for src, mod in sorted(MODULES.items()):
        doc = json.load(open(os.path.join(json_dir, src)))
        dumped = luau_dump.load(os.path.join(luau_dir, mod + ".luau"))
        have = {round(v, 9) for _, v in leaves(dumped["data"], "data", [])}
        # the documented global rescaling: a raw value may be carried x10
        have |= {round(v * DISPLAY_SCALE, 9) for v in list(have)}
        have |= {round(v / DISPLAY_SCALE, 9) for v in list(have)}
        for path, v in leaves(doc["data"], "data", []):
            if round(v, 9) not in have:
                print("MISSING {}: {} = {} is in {} but not in {}.luau".format(mod, path, v, src, mod))
                bad += 1
    print("\n{}: {} source value(s) missing from the generated modules".format(
        "COVERAGE FAIL" if bad else "COVERAGE PASS", bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
