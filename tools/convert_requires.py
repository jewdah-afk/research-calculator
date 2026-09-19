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


def _rel_chain(parts):
    expr = "script.Parent"
    for p in parts:
        if p == ".":
            continue
        if p == "..":
            expr += ".Parent"
        else:
            expr += "." + p
    return expr


def convert(path_expr: str, file_dir: str = None, root: str = None) -> str:
    """Rewrite one string require.

    A require that stays inside the script's own `$path` root (shared, server
    or client) becomes a script.Parent chain. One that leaves that root cannot
    be expressed that way -- the roots are mounted under different services --
    so a path landing in shared/ maps to the ReplicatedStorage.Shared mount
    declared in default.project.json.
    """
    parts = path_expr.split("/")
    if file_dir is not None and root is not None:
        rel = os.path.relpath(file_dir, root).replace(os.sep, "/")
        here = [] if rel == "." else rel.split("/")
        segs = list(here)
        for p in parts:
            if p == ".":
                continue
            if p == "..":
                if segs:
                    segs.pop()
            else:
                segs.append(p)
        own_root = here[0] if here else None
        if segs and segs[0] != own_root:
            if segs[0] == "shared":
                tail = "".join("." + s for s in segs[1:])
                return 'require(game:GetService("ReplicatedStorage").Shared%s)' % tail
    return "require(%s)" % _rel_chain(parts)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    n = 0
    for f in glob.glob(os.path.join(root, "**", "*.luau"), recursive=True):
        s = open(f).read()
        t, k = PAT.subn(lambda m: convert(m.group(1), os.path.dirname(f), root), s)
        if k:
            open(f, "w").write(t); n += k
    print("rewrote %d require(s) under %s" % (n, root))

if __name__ == "__main__":
    main()
