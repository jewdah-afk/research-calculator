#!/usr/bin/env python3
"""Deterministic fidelity gate.

Every numeric literal in a generated Luau module must exist somewhere in its
source JSON. Catches transcription drift, unit mix-ups and invented values --
the failure modes that LLM review is worst at spotting and that quietly
corrupt balance data.

Usage: check_luau_fidelity.py <luau_dir> <json_dir> [--map Mod.luau=source.json]
Exit 0 = clean, 1 = drift found.
"""
import json, re, sys, os, glob
from decimal import Decimal

NUM = re.compile(r'-?\d+\.?\d*(?:[eE][-+]?\d+)?')
# Structural/idiomatic values that legitimately appear in code without being data.
ALLOW = {Decimal(x) for x in ('0', '1', '-1', '2', '100')}

def nums_in_json(o, acc):
    if isinstance(o, bool) or o is None: return acc
    if isinstance(o, (int, float)):
        acc.add(Decimal(str(o)))
        # tolerate documented rescalings (x10 display scale, ms<->s)
        for f in (10, 1000):
            acc.add(Decimal(str(o)) * f); acc.add(Decimal(str(o)) / f)
    elif isinstance(o, dict):
        for v in o.values(): nums_in_json(v, acc)
        for k in o.keys():
            if re.fullmatch(r'-?\d+\.?\d*', str(k)): acc.add(Decimal(str(k)))
    elif isinstance(o, list):
        for v in o: nums_in_json(v, acc)
    return acc

def strip_noise(src):
    src = re.sub(r'--\[\[.*?\]\]', ' ', src, flags=re.S)   # block comments
    src = re.sub(r'--[^\n]*', ' ', src)                     # line comments
    src = re.sub(r'"(?:[^"\\]|\\.)*"', ' ', src)            # strings
    src = re.sub(r"'(?:[^'\\]|\\.)*'", ' ', src)
    return src

def main():
    if len(sys.argv) < 3:
        print(__doc__); return 2
    luau_dir, json_dir = sys.argv[1], sys.argv[2]
    explicit = {}
    for a in sys.argv[3:]:
        if a.startswith('--map='): k, _, v = a[6:].partition('='); explicit[k] = v

    pool = set()
    per_source = {}
    for jf in glob.glob(os.path.join(json_dir, '*.json')):
        try: d = json.load(open(jf))
        except Exception as e:
            print(f"GATE FAIL: {jf} is not valid JSON: {e}"); return 1
        s = nums_in_json(d, set()); per_source[os.path.basename(jf)] = s; pool |= s

    files = glob.glob(os.path.join(luau_dir, '**', '*.lua'), recursive=True) + \
            glob.glob(os.path.join(luau_dir, '**', '*.luau'), recursive=True)
    if not files:
        print(f"GATE FAIL: no Luau files under {luau_dir}"); return 1

    bad = 0
    for f in sorted(files):
        allowed = pool
        mapped = explicit.get(os.path.basename(f))
        if mapped and mapped in per_source: allowed = per_source[mapped]
        src = strip_noise(open(f).read())
        for ln, line in enumerate(src.split('\n'), 1):
            for m in NUM.finditer(line):
                try: v = Decimal(m.group())
                except Exception: continue
                if v in ALLOW or v in allowed: continue
                print(f"DRIFT {f}:{ln}: value {m.group()} is not present in the source data"
                      + (f" ({mapped})" if mapped else ""))
                bad += 1
    print(f"\n{'GATE FAIL' if bad else 'GATE PASS'}: {bad} unsourced numeric literal(s) across {len(files)} file(s)")
    return 1 if bad else 0

if __name__ == '__main__': sys.exit(main())
