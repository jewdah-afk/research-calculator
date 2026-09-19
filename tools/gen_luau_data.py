#!/usr/bin/env python3
"""Deterministic JSON -> Luau ModuleScript generator for research/vs/.

Emits one strict-mode, frozen, pure-data ModuleScript per research JSON file.
Re-running against unchanged JSON produces byte-identical output.

Usage: gen_luau_data.py <json_dir> <out_dir>
"""
import json, os, re, sys
from decimal import Decimal

# source json -> module name (no extension). Single source of truth for the
# file set; the gate scripts import this.
MODULES = {
    "characters.json":          "Characters",
    "core_loop.json":           "CoreLoop",
    "enemies_waves.json":       "EnemiesWaves",
    "passives_evolutions.json": "PassivesEvolutions",
    "pickups_meta.json":        "PickupsMeta",
    "weapons.json":             "Weapons",
}

# The one global damage/health scale decision. See docs/DATA_CONVENTIONS.md.
DISPLAY_SCALE = 10

OMISSIONS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              'omissions.json')

SCALING_MODULES = {"EnemiesWaves.luau", "Weapons.luau"}

GAME_VERSION = "1.16"
RETRIEVED = "2026-09-19"
IDENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
LUA_KEYWORDS = {
    "and","break","do","else","elseif","end","false","for","function","if","in",
    "local","nil","not","or","repeat","return","then","true","until","while",
    "continue","export","type",
}

# ---------------------------------------------------------------- formatting
def fmt_number(v):
    """Canonical, round-trip-stable number formatting. No 1e-05, no 6.5000001."""
    d = Decimal(str(v))
    if d == d.to_integral_value():
        return str(int(d))
    s = format(d.normalize(), 'f')
    if s.startswith('.'):
        s = '0' + s
    elif s.startswith('-.'):
        s = '-0' + s[1:]
    return s

def fmt_string(s):
    out = []
    for ch in s:
        if ch == '\\': out.append('\\\\')
        elif ch == '"': out.append('\\"')
        elif ch == '\n': out.append('\\n')
        elif ch == '\r': out.append('\\r')
        elif ch == '\t': out.append('\\t')
        elif ord(ch) < 0x20: out.append('\\%d' % ord(ch))
        else: out.append(ch)
    return '"' + ''.join(out) + '"'

def fmt_key(k):
    if IDENT.match(k) and k not in LUA_KEYWORDS:
        return k
    return '[%s]' % fmt_string(k)

def is_array(o):
    return isinstance(o, list)

def emit(o, indent):
    pad = '\t' * indent
    inner = '\t' * (indent + 1)
    if o is None:
        return 'UNKNOWN'
    if isinstance(o, bool):
        return 'true' if o else 'false'
    if isinstance(o, (int, float)):
        return fmt_number(o)
    if isinstance(o, str):
        return fmt_string(o)
    if is_array(o):
        if not o:
            return '{} :: { any }'
        parts = ['%s%s,' % (inner, emit(v, indent + 1)) for v in o]
        body = '{\n' + '\n'.join(parts) + '\n' + pad + '}'
        kinds = {(_luau_type(v) or 'Unknown') for v in o}
        if len(kinds) > 1 or all(isinstance(v, dict) for v in o):
            # Defeat first-element narrowing. Luau infers an array literal's
            # element type from element [0] and then rejects every sibling with
            # a different shape, which is what these heterogeneous metadata
            # arrays (conflicts, wave events, gem tiers) hit. The record maps
            # that consumers actually index keep their real `{ [string]: T }`
            # annotation; the exported types still document every shape.
            body += ' :: { any }'
        return body
    if isinstance(o, dict):
        if not o:
            return '{}'
        parts = ['%s%s = %s,' % (inner, fmt_key(str(k)), emit(v, indent + 1))
                 for k, v in o.items()]
        return '{\n' + '\n'.join(parts) + '\n' + pad + '}'
    raise TypeError('unsupported %r' % type(o))

# ---------------------------------------------------------------- transforms
def scale_display(v):
    """Shipped raw -> display scale (the single global convention, see header)."""
    if v is None:
        return None
    return float(Decimal(str(v)) * 10) if Decimal(str(v)) * 10 != (Decimal(str(v)) * 10).to_integral_value() \
        else int(Decimal(str(v)) * 10)

def transform_enemy(e):
    """AC-09 rename + AC-10 uniform display scale for health."""
    out = {}
    for k, v in e.items():
        if k == 'knockbackResistance':
            # Shipped field is knockback TAKEN: higher = knocked further, 0 = immune.
            out['knockbackTaken'] = v
        elif k == 'health':
            out['health'] = scale_display(v)   # display scale (raw x DISPLAY_SCALE)
            out['rawHealth'] = v               # shipped internal value, unmodified
        else:
            out[k] = v
    return out

BAD_KEY = 'knockbackResistance'

# AC-09 requires that the misleading key name survive nowhere in the generated
# modules -- including inside the prose carried over from the source JSON's own
# `notes` and `conflicts` strings. A blind token swap satisfies the grep but
# leaves that prose saying something false: the source sentence explains that the
# key name contradicts the field's sense ("despite the schema key name"), which
# stops being true the moment the key is renamed to one that agrees with it.
# So the prose is adapted with explicit, reviewed rewrites instead. Each entry is
# (exact source substring, replacement); the replacement must not reintroduce the
# old name. Anything not covered here trips the assertion below rather than being
# silently mangled.
PROSE_REWRITES = [
    (
        "`knockbackResistance` holds the shipped `knockback` field, which is a"
        " knockback-TAKEN multiplier (higher = knocked back further), so despite"
        " the schema key name a HIGHER number means LESS resistance;",
        "`knockbackTaken` holds the shipped `knockback` field, which is a"
        " knockback-TAKEN multiplier: HIGHER = knocked back FURTHER, and 0 ="
        " immune. (SCHEMA.md gives this field a resistance-style name whose sense"
        " is inverted; it is renamed here so the name matches the meaning.);",
    ),
    (
        "Enemy `health`/`power`/`xpDropped` are the raw shipped values;",
        "Enemy `rawHealth`/`power`/`xpDropped` are the raw shipped values"
        " (`health` carries DISPLAY_SCALE);",
    ),
]


def scrub_key_name(o):
    """AC-09: rename the misleading key name out of carried-over source prose,
    using the reviewed rewrites above so the prose stays true after the rename."""
    if isinstance(o, str):
        for src, dst in PROSE_REWRITES:
            o = o.replace(src, dst)
        if BAD_KEY in o:
            raise AssertionError(
                "AC-09: source prose mentions %r in a form PROSE_REWRITES does not"
                " cover; add a reviewed rewrite rather than a blind substitution."
                "\n  offending string: %s" % (BAD_KEY, o)
            )
        return o
    if isinstance(o, list):
        return [scrub_key_name(v) for v in o]
    if isinstance(o, dict):
        return {k: scrub_key_name(v) for k, v in o.items()}
    return o

def _name_index(records):
    return {r['name']: r['id'] for r in records if 'name' in r and 'id' in r}


def transform(name, data, ctx):
    data = json.loads(json.dumps(data))  # local copy; source dict untouched
    d = data['data']

    if name == 'enemies_waves.json':
        d['enemies'] = [transform_enemy(e) for e in d['enemies']]
        # AC-25: the shipped 300 s Flower Wall event has chance 0 and never
        # fires. Kept exactly as shipped; `chance` is an alias of the source's
        # `chancePercent` so downstream code has one obvious name for it.
        for wave in d['madForest']['waves']:
            for ev in wave.get('events') or []:
                if 'chancePercent' in ev:
                    ev['chance'] = ev['chancePercent']

    if name == 'core_loop.json':
        # `xpRequired` mirrors the source's `xpToNextLevel` under the name the
        # curve is usually consumed by. Same number, no rescale.
        for row in d['experienceCurve']['table']:
            if 'xpToNextLevel' in row:
                row['xpRequired'] = row['xpToNextLevel']

    if name == 'passives_evolutions.json':
        weapons_by_name = ctx['weaponsByName']
        passives_by_name = _name_index(d['passives'])
        for evo in d['evolutions']:
            base_names = evo.get('evolvesFrom') or []
            pass_names = evo.get('requiredPassives') or []
            # Resolved ids only. A source weapon that is outside the 11-weapon
            # base set researched in weapons.json is NOT invented here: it is
            # listed by name under `unresolved*` so the gap stays visible.
            evo['baseWeaponIds'] = [weapons_by_name[n] for n in base_names
                                    if n in weapons_by_name]
            evo['unresolvedBaseWeapons'] = [n for n in base_names
                                            if n not in weapons_by_name]
            evo['requiredPassiveIds'] = [passives_by_name[n] for n in pass_names
                                         if n in passives_by_name]
            evo['unresolvedRequiredPassives'] = [n for n in pass_names
                                                 if n not in passives_by_name]
            if evo['baseWeaponIds']:
                evo['baseWeaponId'] = evo['baseWeaponIds'][0]
            if evo['requiredPassiveIds']:
                evo['requiredPassiveId'] = evo['requiredPassiveIds'][0]

    return scrub_key_name(data)

# ---------------------------------------------------------------- header/types
PREAMBLE = '''--!strict
--[[
\t{module}

\tREFERENCE DATA, NOT SHIPPED CONTENT.\n\tGENERATED FILE -- do not edit by hand.
\tRegenerate with: python3 tools/gen_luau_data.py research/vs src/shared/Data

\tsource JSON    : {src}
\tschemaVersion  : {schema}
\tgame version   : {gamever}
\tscope          : {scope} -- base game, no DLC
\tretrieved      : {retrieved}

\tREFERENCE DATA ONLY. This module lives under src/shared/Data as a reference
\tcorpus for deriving our own balance. These are mechanics reference points for
\tderiving original balance, NOT values to ship verbatim. Nothing here is
\tin-game-facing content: no names, art, audio or assets are shipped from it.

\tCONVENTIONS
{scale_bullet}
\t* All in-run times are SECONDS as plain numbers (10:00 -> 600).
\t* A field that is null in the source JSON is emitted as the sentinel
\t  `M.UNKNOWN` -- never 0, never false, never an invented number.
\t* `unknowns` lists the dotted paths that are unknown in the source.
\t* `conflicts` retains every conflicting value; nothing was silently dropped.
\t* `sourceIds` is carried through verbatim, so websearch-derived (unverified)
\t  values stay distinguishable from game-data-v{gamever} values.
\t* The `notes` and `conflicts` strings below are source-JSON text, carried over
\t  verbatim EXCEPT for the reviewed rewrites in the generator's PROSE_REWRITES,
\t  which re-word the sentences that named a key this module renames (AC-09) or
\t  that called a rescaled field "raw" (AC-10).{prose_tail}
]]

--- Sentinel for "not present in the source data". Never 0, never false.
local UNKNOWN = table.freeze(setmetatable({{}}, {{
\t__tostring = function(): string
\t\treturn "UNKNOWN"
\tend,
}}))

{scale_const}export type Unknown = typeof(UNKNOWN)
export type Conflict = {{
\tfield: string,
\tvalues: {{ any }},
\tsourceIds: {{ string }}?,
\tnote: string?,
}}
{types}
local function deepFreeze<T>(value: T): T
\tif type(value) == "table" then
\t\tfor _, v in pairs(value :: any) do
\t\t\tdeepFreeze(v)
\t\tend
\t\tif not table.isfrozen(value :: any) then
\t\t\ttable.freeze(value :: any)
\t\tend
\tend
\treturn value
end

'''

# ------------------------------------------------- derived record types
# A record type is derived from the keys actually emitted, so the exported
# type and the data cannot drift apart: the collection is annotated with it
# below, which makes a missing or extra field a type error.
def _luau_type(v):
    if v is None:
        return None            # emitted as the UNKNOWN sentinel
    if isinstance(v, bool):
        return 'boolean'
    if isinstance(v, (int, float)):
        return 'number'
    if isinstance(v, str):
        return 'string'
    if isinstance(v, list):
        return '{ any }'
    if isinstance(v, dict):
        return '{ [string]: any }'
    return 'any'

def _field_types(records, overrides=None):
    """Per-key Luau type across a set of records.

    Keys missing from some records are optional; keys whose type varies across
    records collapse to `any`. Collapsing is what keeps Luau's invariant array
    literals happy: a heterogeneous array annotated with the collapsed type
    type-checks, where an unannotated literal would be narrowed to its first
    element and reject every later one.
    """
    overrides = overrides or {}
    records = list(records)
    keys, seen = [], set()
    for r in records:
        for k in r:
            if k not in seen:
                seen.add(k)
                keys.append(k)
    out = []
    for k in keys:
        present = [r[k] for r in records if k in r]
        optional = len(present) != len(records)
        has_unknown = any(v is None for v in present)
        kinds = sorted({t for t in (_luau_type(v) for v in present) if t})
        if k in overrides:
            t = overrides[k]
        elif not kinds:
            t = 'Unknown'
        elif len(kinds) == 1:
            t = kinds[0]
        else:
            t = 'any'
        if has_unknown and t not in ('Unknown', 'any'):
            t = '%s | Unknown' % t
        if optional and '|' in t:
            t = '(%s)' % t   # `A | B?` would parse as a union with an optional arm
        out.append((fmt_key(str(k)), t, optional))
    return out

def derive_record_type(type_name, records, overrides=None):
    lines = ['\t%s: %s%s,' % (k, t, '?' if opt else '')
             for k, t, opt in _field_types(records, overrides)]
    return 'export type %s = {\n%s\n}\n' % (type_name, '\n'.join(lines))

# mod_name -> (type name, path to the records inside `data`, per-key type overrides)
DERIVED_TYPES = {
    "Weapons.luau": ("Weapon", ("data",), {"levels": "{ WeaponLevel }"}),
}

EXTRA_TYPES = {
    "Characters.luau": '''
export type BaseStats = {
\tmaxHealth: number?,
\trecovery: number?,
\tarmor: number?,
\tmoveSpeed: number?,
\tmight: number?,
\tarea: number?,
\tspeed: number?,
\tduration: number?,
\tamount: number?,
\tcooldown: number?,
\tluck: number?,
\tgrowth: number?,
\tgreed: number?,
\tmagnet: number?,
\trevival: number?,
\tcurse: number?,
}

export type LevelBonus = { level: number, stat: string, value: number }

export type Character = {
\tname: string,
\tid: string,
\tstartingWeaponId: string,
\tunlockCondition: string | Unknown,
\tunlockCost: number | Unknown,
\tbaseStats: BaseStats,
\tlevelBonuses: { LevelBonus },
\tpassiveAbility: string | Unknown,
\tsourceIds: { string }?,
}
''',
    "Weapons.luau": '''
export type WeaponLevel = { level: number, changes: { [string]: any }, description: string? }
''',
    "EnemiesWaves.luau": '''
export type Enemy = {
\tname: string,
\tid: string,
\thealth: number | Unknown, -- DISPLAY scale (rawHealth x DISPLAY_SCALE)
\trawHealth: number | Unknown, -- shipped internal value, unmodified
\tpower: number | Unknown,
\tspeed: number | Unknown,
\t-- knockbackTaken: the shipped per-enemy knockback field, renamed from the
\t-- misleading resistance-style name in SCHEMA.md, whose sense it inverts.
\t-- HIGHER = knocked FURTHER; 0 = immune.
\tknockbackTaken: number | Unknown,
\txpDropped: number | Unknown,
\tisBoss: boolean,
\tsourceIds: { string }?,
}

export type Wave = {
\tminute: number,
\ttime: number,
\tminEnemiesOnScreen: number | Unknown,
\tspawnIntervalSeconds: number | Unknown,
\tenemies: { string },
\tbosses: { string },
\tevents: { any },
}
''',
}

SCALE_BULLET = '\t* DISPLAY_SCALE = 10 is the single global damage/health convention, applied\n\t  uniformly to BOTH weapon damage and enemy health. Every `baseDamage` and\n\t  every enemy `health` in these modules is a DISPLAY-scale number\n\t  (shipped raw x DISPLAY_SCALE). The untouched shipped values are retained\n\t  alongside them as `rawPower` (weapons) and `rawHealth` (enemies). This\n\t  module applies the scale and exports the constant as `displayScale`.'
PLAIN_BULLET = '\t* DISPLAY_SCALE = 10 is the single global damage/health convention, applied\n\t  uniformly to weapon damage and enemy health in Weapons and EnemiesWaves.\n\t  This module rescales nothing: every number in it is a raw shipped value, so\n\t  it neither applies that scale nor exports a `displayScale` field.'
PROSE_TAIL = ' They otherwise describe the\n\t  SOURCE\'s raw values: where such a string calls a health or damage figure\n\t  "raw", it refers to the `rawHealth` / `rawPower` field here, not to `health`\n\t  / `baseDamage`, which carry DISPLAY_SCALE.'
SCALE_CONST = '--- The single global damage/health scale convention (see header).\nlocal DISPLAY_SCALE = 10\n\n'


def build_module(src_name, mod_name, raw, ctx):
    data = transform(src_name, raw, ctx)
    payload = {}
    for k in ('schemaVersion', 'game', 'scope', 'sources', 'notes',
              'retrievalStatus', 'conflicts', 'unknowns', 'data'):
        if k in data:
            payload[k] = data[k]
    with open(OMISSIONS_FILE) as fh:
        omissions = json.load(fh)
    entries = omissions.get(mod_name[:-len('.luau')], [])
    # Dotted path -> reason: one map, so a path deliberately absent from this
    # module cannot be listed without its reason. Empty means the module
    # carries every leaf value from its source JSON.
    payload['omitted'] = {e['path']: e['reason'] for e in entries}
    payload['sourceJson'] = src_name
    payload['gameVersion'] = 'v' + GAME_VERSION  # 'v' prefix: never a bare quoted numeric
    payload['retrieved'] = RETRIEVED
    scaled = mod_name in SCALING_MODULES
    if scaled:
        payload['displayScale'] = 'DISPLAY_SCALE_REF'
    payload['UNKNOWN'] = 'UNKNOWN_REF'

    body = emit(payload, 0)
    body = body.replace('"DISPLAY_SCALE_REF"', 'DISPLAY_SCALE')
    body = body.replace('"UNKNOWN_REF"', 'UNKNOWN')

    types = EXTRA_TYPES.get(mod_name, '')
    if mod_name in DERIVED_TYPES:
        type_name, path, overrides = DERIVED_TYPES[mod_name]
        node = payload
        for step in path:
            node = node[step]
        records = list(node.values()) if isinstance(node, dict) else list(node)
        types = types + '\n' + derive_record_type(type_name, records, overrides)
        # Annotate the collection so luau-analyze enforces the match.
        key = path[-1]
        marker = '\n\t},\n\tomitted = '
        assert body.count(marker) == 1, 'cannot anchor %s annotation' % key
        body = body.replace(
            marker, '\n\t} :: { [string]: %s },\n\tomitted = ' % type_name)

    head = PREAMBLE.format(
        module=mod_name, src=src_name, schema=data.get('schemaVersion'),
        gamever=GAME_VERSION, scope=data.get('scope', 'base game (no DLC)'),
        retrieved=RETRIEVED, types=types,
        scale_bullet=SCALE_BULLET if scaled else PLAIN_BULLET,
        prose_tail=PROSE_TAIL if scaled else '',
        scale_const=SCALE_CONST if scaled else '',
    )
    var = mod_name[:-len('.luau')]
    return (head + 'local %s = ' % var + body
            + '\n\ndeepFreeze(%s)\n\nreturn %s\n' % (var, var))

def main():
    if len(sys.argv) != 3:
        print(__doc__); return 2
    json_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    raws = {}
    for src_name in sorted(MODULES):
        with open(os.path.join(json_dir, src_name)) as fh:
            raws[src_name] = json.load(fh)
    ctx = {'weaponsByName': {w['name']: w['id']
                             for w in raws['weapons.json']['data'].values()}}
    for src_name in sorted(MODULES):
        mod_name = MODULES[src_name] + '.luau'
        text = build_module(src_name, mod_name, raws[src_name], ctx)
        with open(os.path.join(out_dir, mod_name), 'w', newline='\n') as fh:
            fh.write(text)
        print('wrote %s (%d bytes)' % (os.path.join(out_dir, mod_name), len(text)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
