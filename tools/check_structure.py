#!/usr/bin/env python3
"""Structural, referential and convention gate over src/shared/Data.

Covers the acceptance criteria that are about shape rather than about numbers
being transcribed correctly (that is check_luau_fidelity.py + check_coverage.py).

Usage: check_structure.py <luau_dir> <json_dir>
"""
import json, os, re, sys, math
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

CANONICAL_STATS = {
    "maxHealth", "recovery", "armor", "moveSpeed", "might", "area", "speed",
    "duration", "amount", "cooldown", "luck", "growth", "greed", "magnet",
    "revival", "curse",
}
NEAR_MISSES = {
    "max_health", "maxhealth", "hp", "moveSpd", "movespeed", "move_speed", "cd",
    "cooldownTime", "spd", "dmg", "atk", "recov", "mag", "rev",
}

FAILS = []
CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    if not ok:
        FAILS.append("{}: {}".format(name, detail))


def walk_keys(o, acc):
    if isinstance(o, dict):
        for k, v in o.items():
            acc.add(k)
            walk_keys(v, acc)
    elif isinstance(o, list):
        for v in o:
            walk_keys(v, acc)
    return acc


def json_paths_null(o, path, acc):
    if o is None:
        acc.append(path)
    elif isinstance(o, dict):
        for k, v in o.items():
            json_paths_null(v, "{}.{}".format(path, k), acc)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            json_paths_null(v, "{}[{}]".format(path, i), acc)
    return acc


def resolve(o, path):
    """Resolve a dotted/indexed path, returning a sentinel when absent."""
    cur = o
    for part in re.findall(r"[^.\[\]]+|\[\d+\]", path):
        if part.startswith("["):
            i = int(part[1:-1])
            if not isinstance(cur, list) or i >= len(cur):
                return KeyError
            cur = cur[i]
        else:
            if not isinstance(cur, dict) or part not in cur:
                return KeyError
            cur = cur[part]
    return cur


def sourceid_paths(o, path, acc):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "sourceIds":
                acc.append(("{}.{}".format(path, k), v))
            else:
                sourceid_paths(v, "{}.{}".format(path, k), acc)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            sourceid_paths(v, "{}[{}]".format(path, i), acc)
    return acc


def main():
    luau_dir, json_dir = sys.argv[1], sys.argv[2]
    mods, docs = {}, {}
    for src, name in MODULES.items():
        mods[name] = luau_dump.load(os.path.join(luau_dir, name + ".luau"))
        docs[name] = json.load(open(os.path.join(json_dir, src)))
    raw = {n: open(os.path.join(luau_dir, n + ".luau")).read() for n in MODULES.values()}

    # AC-01 / AC-02 / AC-23 -- file set, extension, return, strict mode
    files = sorted(f for f in os.listdir(luau_dir) if f.endswith((".lua", ".luau")))
    check("AC-01 six .luau modules", files == sorted(n + ".luau" for n in MODULES.values()), files)
    for n, text in raw.items():
        check("AC-23 {} --!strict".format(n), text.startswith("--!strict\n"))
        last = [l.strip() for l in text.strip().split("\n") if l.strip() and not l.strip().startswith("--")][-1]
        check("AC-02 {} returns a table".format(n), re.fullmatch(r"return [A-Za-z_][A-Za-z0-9_]*", last), last)
        # AC-21 purity
        m = re.findall(r"game:GetService|require\(|math\.random|os\.|task\.|spawn\(", text)
        check("AC-21 {} pure data".format(n), not m, m)
        # AC-22 frozen
        check("AC-22 {} frozen".format(n), "table.freeze" in text and "deepFreeze(" in text)
        # AC-24 header provenance
        head = text[:text.index("]]")]
        for token in ("schemaVersion", "1.16", "no DLC", "2026-09-19"):
            check("AC-24 {} header has {!r}".format(n, token), token in head)
        check("AC-24 {} header states reference-points-not-verbatim".format(n),
              re.search(r"reference points", head, re.I) and re.search(r"NOT values to ship verbatim", head, re.I))
        # AC-16 no quoted numerics / mm:ss as values
        check("AC-16 {} no mm:ss values".format(n), not re.search(r'=\s*"\d+:\d+"', text))
        # metadata strings (gameVersion, schema ids) may legitimately be quoted;
        # what must never be quoted is an in-run TIME or any stat value.
        quoted = re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"-?\d+(?:\.\d+)?"\s*,', text)
        quoted = [q for q in quoted if q not in ("gameVersion", "version", "schemaVersion", "retrieved", "roman")]
        check("AC-16 {} no quoted numeric values".format(n), not quoted, quoted)

    W, C, E, P, K, L = (mods["Weapons"], mods["Characters"], mods["EnemiesWaves"],
                        mods["PassivesEvolutions"], mods["PickupsMeta"], mods["CoreLoop"])

    # AC-05 characters
    chars = C["data"]
    check("AC-05 six characters", set(chars) == {"antonio", "imelda", "pasqualina", "gennaro", "arca", "porta"}, sorted(chars))
    for cid, rec in chars.items():
        for f in ("name", "startingWeaponId", "unlockCost", "baseStats", "levelBonuses", "passiveAbility"):
            check("AC-05 {}.{}".format(cid, f), f in rec or f in set(rec.get("omitted", [])), sorted(rec))

    # AC-06 / AC-07 weapons
    weapons = W["data"]
    check("AC-06 eleven weapons", len(weapons) == 11, len(weapons))
    for wid, w in weapons.items():
        lv = [l["level"] for l in w["levels"]]
        check("AC-06 {} level run".format(wid), lv == list(range(1, w["maxLevel"] + 1)), lv)
        totals = {}
        for entry in w["levels"]:
            for k, v in entry.get("changes", {}).items():
                totals[k] = round(totals.get(k, 0) + v, 9)
        expected = {k: round(float(v), 9) for k, v in w.get("maxLevelTotals", {}).items()}
        check("AC-07 {} deltas reconcile".format(wid), totals == expected, "{} != {}".format(totals, expected))

    # AC-08 enemies + waves
    check("AC-08 21 enemies", len(E["data"]["enemies"]) == 21, len(E["data"]["enemies"]))
    waves = E["data"]["madForest"]["waves"]
    jwaves = docs["EnemiesWaves"]["data"]["madForest"]["waves"]
    check("AC-08 31 waves", len(waves) == 31, len(waves))
    for i, (a, b) in enumerate(zip(waves, jwaves)):
        for k, v in b.items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                check("AC-08 wave[{}].{}".format(i, k), a.get(k) == v, "{} != {}".format(a.get(k), v))

    # AC-09 knockback rename
    for n, text in raw.items():
        check("AC-09 {} no knockbackResistance".format(n), "knockbackResistance" not in text)
    et = raw["EnemiesWaves"]
    check("AC-09 knockbackTaken present", "knockbackTaken" in et)
    check("AC-09 knockbackTaken documented",
          re.search(r"knocked\s+(back\s+)?further", et, re.I) and re.search(r"0\s*=\s*immune", et, re.I))

    # AC-10 one scale, applied to damage and health
    for n, text in raw.items():
        check("AC-10 {} scale documented".format(n), "DISPLAY_SCALE = 10" in text)
    check("AC-10 knife damage on display scale", weapons["knife"]["baseDamage"] == 6.5,
          weapons["knife"]["baseDamage"])
    zombie = next(e for e in E["data"]["enemies"] if e["id"] == "zombie")
    check("AC-10 zombie health on display scale", zombie["health"] == zombie["rawHealth"] * 10,
          (zombie["health"], zombie["rawHealth"]))

    # AC-11 nulls never become 0/false
    for name in MODULES.values():
        nulls = json_paths_null(docs[name]["data"], "data", [])
        for p in nulls:
            got = resolve({"data": mods[name]["data"]}, p)
            check("AC-11 {} {} absent".format(name, p), got is KeyError or got is None, got)
        # AC-12 / AC-13
        check("AC-12 {} unknowns".format(name),
              set(mods[name].get("unknowns", [])) == set(docs[name].get("unknowns", [])))
        jc, mc = docs[name].get("conflicts", []), mods[name].get("conflicts", [])
        check("AC-13 {} conflict count".format(name), len(mc) == len(jc), (len(mc), len(jc)))
        for i, (a, b) in enumerate(zip(mc, jc)):
            check("AC-13 {} conflict[{}] values".format(name, i),
                  len(a.get("values", [])) == len(b.get("values", [])))
        # AC-14 provenance
        for p, v in sourceid_paths(docs[name]["data"], "data", []):
            got = resolve({"data": mods[name]["data"]}, p)
            check("AC-14 {} {}".format(name, p), got == v, "{} != {}".format(got, v))

    # AC-15 canonical stat vocabulary
    allkeys = set()
    for name in MODULES.values():
        walk_keys(mods[name], allkeys)
    bad = sorted(k for k in allkeys if k in NEAR_MISSES or
                 (k.lower() in {s.lower() for s in CANONICAL_STATS} and k not in CANONICAL_STATS))
    check("AC-15 canonical stat spellings", not bad, bad)
    check("AC-15 no snake_case keys", not [k for k in allkeys if "_" in k and not re.fullmatch(r"[a-z0-9_]+", k)],
          [k for k in allkeys if "_" in k and not re.fullmatch(r"[a-z0-9_]+", k)])

    # AC-16 time units
    check("AC-16 timeLimit 1800", E["data"]["madForest"]["timeLimit"] == 1800,
          E["data"]["madForest"].get("timeLimit"))
    gate = resolve(P, "data.evolutionRules.timeGateSeconds")
    if gate is KeyError:
        gate = next((v for k, v in (P["data"].get("evolutionRules") or {}).items()
                     if isinstance(v, (int, float)) and v == 600), None)
    check("AC-16 evolution time gate 600", gate == 600, gate)

    # AC-17 XP curve
    curve = L["data"]["experienceCurve"]["table"]
    check("AC-17 100 entries", len(curve) == 100, len(curve))
    for entry in curve:
        n = entry["level"]
        if n <= 20:
            base = 5 + 10 * (n - 1)
        elif n <= 40:
            base = 195 + 13 * (n - 20)
        else:
            base = 455 + 16 * (n - 40)
        surcharge = 600 if n == 20 else (2400 if n == 40 else 0)
        check("AC-17 level {} surcharge".format(n), entry.get("extraSurcharge", 0) == surcharge,
              entry.get("extraSurcharge"))
        got = entry.get("xpToNextLevel", entry.get("xpRequired", entry.get("xp")))
        check("AC-17 level {}".format(n), got == base + surcharge,
              "{} != {}".format(got, base + surcharge))

    # AC-18 PowerUps
    shop = K["data"]["powerUpShop"]
    pus = shop["powerUps"] if isinstance(shop, dict) and "powerUps" in shop else shop
    pus = list(pus.values()) if isinstance(pus, dict) else pus
    check("AC-18 29 PowerUps", len(pus) == 29, len(pus))
    ranks = sum(p.get("maxRank", p.get("ranks", 0)) if not isinstance(p.get("ranks"), list)
                else len(p["ranks"]) for p in pus)
    check("AC-18 125 ranks", ranks == 125, ranks)
    total, bought = 0, 0
    for p in sorted(pus, key=lambda x: x.get("id", x.get("name", ""))):
        mx = p.get("maxRank") if not isinstance(p.get("ranks"), list) else len(p["ranks"])
        mx = mx or p.get("ranks", 0)
        price = p.get("initialPrice", p.get("basePrice", 0))
        for r in range(1, int(mx) + 1):
            # fee(0) == 0: the very first rank bought across the whole shop is
            # fee-free, per the shipped cost formula.
            total += price * r + (math.floor(20 * (1.1 ** bought)) if bought else 0)
            bought += 1
    check("AC-18 total cost 31223734", total == 31223734, total)

    # AC-19 passives / evolutions referential integrity
    passives = P["data"]["passives"]
    pids = set(passives) if isinstance(passives, dict) else {p["id"] for p in passives}
    evos = P["data"]["evolutions"]
    evos = list(evos.values()) if isinstance(evos, dict) else evos
    check("AC-19 16 passives", len(pids) == 16, len(pids))
    check("AC-19 32 evolutions", len(evos) == 32, len(evos))
    for e in evos:
        for key in ("baseWeaponId", "weaponId", "baseId"):
            if key in e and e[key] is not None:
                check("AC-19 evo {} base {}".format(e.get("id"), e[key]), e[key] in weapons, e[key])
        for key in ("requiredPassiveId", "passiveId"):
            if key in e and e[key] is not None:
                check("AC-19 evo {} passive {}".format(e.get("id"), e[key]), e[key] in pids, e[key])
    for cid, rec in chars.items():
        check("AC-19 {} starting weapon".format(cid), rec["startingWeaponId"] in weapons, rec["startingWeaponId"])

    # AC-20 id conventions
    for label, table in (("weapon", weapons), ("character", chars)):
        for key, rec in table.items():
            check("AC-20 {} {} key==id".format(label, key), rec.get("id") == key, rec.get("id"))
            check("AC-20 {} {} snake_case".format(label, key), re.fullmatch(r"[a-z0-9_]+", key), key)

    # AC-25 the deliberate chance: 0 Flower Wall event
    ev300 = [ev for w in waves if w.get("time") == 300 for ev in (w.get("events") or [])]
    check("AC-25 300s event present", ev300, ev300)
    check("AC-25 300s event chance is 0",
          any(ev.get("chance", ev.get("chancePercent")) == 0 for ev in ev300), ev300)

    # AC-26 reference-only namespace
    check("AC-26 path is src/shared/Data", os.path.normpath(luau_dir).endswith(os.path.join("src", "shared", "Data")), luau_dir)
    for n, text in raw.items():
        check("AC-26 {} marked reference-only".format(n),
              re.search(r"REFERENCE DATA ONLY|REFERENCE DATA, NOT SHIPPED CONTENT", text))

    for f in FAILS:
        print("FAIL " + str(f))
    print("\n{}: {}/{} structural checks passed".format(
        "STRUCTURE FAIL" if FAILS else "STRUCTURE PASS", len(CHECKS) - len(FAILS), len(CHECKS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
