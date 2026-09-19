#!/usr/bin/env python3
"""AC-28: regenerating from unchanged JSON must be byte-identical, and every
number must be formatted canonically (no 6.500000000001, no 1e-05).

Usage: check_determinism.py <luau_dir> <json_dir>
"""
import filecmp, os, re, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_luau_data import MODULES

GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_luau_data.py")
BAD_NUM = re.compile(r"-?\d+\.\d*(?:0{6,}|9{6,})\d*|[0-9](?:[eE][-+]?\d+)")


def main():
    luau_dir, json_dir = sys.argv[1], sys.argv[2]
    bad = 0
    tmp = tempfile.mkdtemp(prefix="gen-a-")
    tmp2 = tempfile.mkdtemp(prefix="gen-b-")
    try:
        for out in (tmp, tmp2):
            subprocess.run([sys.executable, GEN, json_dir, out],
                           check=True, stdout=subprocess.DEVNULL)
        for name in sorted(MODULES.values()):
            f = name + ".luau"
            a, b, live = os.path.join(tmp, f), os.path.join(tmp2, f), os.path.join(luau_dir, f)
            if not filecmp.cmp(a, b, shallow=False):
                print("NONDETERMINISTIC: two generator runs differ for " + f); bad += 1
            if not os.path.exists(live) or not filecmp.cmp(a, live, shallow=False):
                print("STALE: %s differs from a fresh generation (regenerate it)" % f); bad += 1
            src = open(a).read()
            src = re.sub(r"--\[\[.*?\]\]", " ", src, flags=re.S)
            src = re.sub(r"--[^\n]*", " ", src)
            src = re.sub(r'"(?:[^"\\]|\\.)*"', " ", src)
            for m in BAD_NUM.finditer(src):
                print("NON-CANONICAL NUMBER in %s: %s" % (f, m.group())); bad += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(tmp2, ignore_errors=True)
    print("\n%s: %d determinism problem(s)" % ("DETERMINISM FAIL" if bad else "DETERMINISM PASS", bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
