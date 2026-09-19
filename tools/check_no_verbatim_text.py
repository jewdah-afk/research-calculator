#!/usr/bin/env python3
"""Gate: no verbatim shipped game text in the modules that ship into Studio.

Mechanics, stats and formulas are not copyrightable and are carried through in
full. Prose lifted from the shipped game files is creative expression: it stays
in research/vs/*.json as reference and must never reach src/shared/Data, where a
UI could render it.

Two checks:
  1. None of the known prose keys appears in a generated module.
  2. No string in a generated module matches, normalised, a prose string in the
     source JSON -- catching the same text reintroduced under a different key.

Usage: check_no_verbatim_text.py <luau_dir> <json_dir>
Exit 0 = clean, 1 = verbatim text found.
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luau_dump

PROSE_KEYS = ("description", "inGameDescription", "tips", "behavior")
MODULES = {
    "characters.json": "Characters", "core_loop.json": "CoreLoop",
    "enemies_waves.json": "EnemiesWaves", "passives_evolutions.json": "PassivesEvolutions",
    "pickups_meta.json": "PickupsMeta", "weapons.json": "Weapons",
}
# Short strings collide by coincidence (ids, single words); only compare real prose.
MIN_LEN = 25

norm = lambda s: re.sub(r"\s+", " ", s).strip().lower()


def walk(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk(v, "{}.{}".format(path, k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, "{}[{}]".format(path, i))
    else:
        yield path, o


def main():
    if len(sys.argv) < 3:
        print(__doc__); return 2
    luau_dir, json_dir = sys.argv[1], sys.argv[2]
    bad = 0
    for src, mod in sorted(MODULES.items()):
        doc = json.load(open(os.path.join(json_dir, src)))
        dumped = luau_dump.load(os.path.join(luau_dir, mod + ".luau"))

        prose = {norm(v) for p, v in walk(doc)
                 if isinstance(v, str) and len(v) >= MIN_LEN
                 and p.rsplit(".", 1)[-1].split("[")[0] in PROSE_KEYS}

        for path, v in walk(dumped):
            leaf = path.rsplit(".", 1)[-1].split("[")[0]
            if leaf in PROSE_KEYS:
                print("VERBATIM KEY {}: {} is a prose key and must not ship".format(mod, path))
                bad += 1
            elif isinstance(v, str) and len(v) >= MIN_LEN and norm(v) in prose:
                print("VERBATIM TEXT {}: {} reproduces shipped prose: {!r}".format(
                    mod, path, v[:70]))
                bad += 1

    print("\n{}: {} verbatim shipped string(s) in the shipping modules".format(
        "VERBATIM FAIL" if bad else "VERBATIM PASS", bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
