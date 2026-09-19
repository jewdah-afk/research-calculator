#!/usr/bin/env python3
"""Fallback: rewrite string requires to Instance-path requires, in place.

Source uses Roblox's string-path requires (`require("./Sibling")`,
`require("../Data/Weapons")`) so the same files run under the plain `luau`
CLI for headless tests and type-check across files. If a Studio place does not
resolve string requires, run this over a COPY of src/ and sync that instead:

    cp -r src /tmp/src-instance && python3 tools/convert_requires.py /tmp/src-instance

Never run it on src/ itself; the tests and analyzer need the string form.
"""
import re, sys, os, glob

PAT = re.compile(r'require\(\s*"((?:\.\./|\./)[^"]+)"\s*\)')

def convert(path_expr: str) -> str:
    parts = path_expr.split("/")
    expr = "script.Parent"
    for p in parts:
        if p == ".":
            continue
        if p == "..":
            expr += ".Parent"
        else:
            expr += "." + p
    return "require(%s)" % expr

def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    n = 0
    for f in glob.glob(os.path.join(root, "**", "*.luau"), recursive=True):
        s = open(f).read()
        t, k = PAT.subn(lambda m: convert(m.group(1)), s)
        if k:
            open(f, "w").write(t); n += k
    print("rewrote %d require(s) under %s" % (n, root))

if __name__ == "__main__":
    main()
