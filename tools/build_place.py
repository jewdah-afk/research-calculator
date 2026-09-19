#!/usr/bin/env python3
"""Build a Studio-ready place from src/.

src/ uses filesystem-relative string requires (`require("../shared/Tuning")`) so
the same files run under the plain `luau` CLI for headless tests and type-check
across files. Roblox does NOT see that layout: default.project.json maps the
three source folders into three different containers, so a relative path that is
correct on disk resolves to nothing in the place.

This copies src/ to build/src, rewrites every relative require to an absolute
instance path derived from the project's own mapping, and builds the place.
src/ itself is never modified.
"""
import json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REQ = re.compile(r'require\(\s*"((?:\.\./|\./)[^"]+)"\s*\)')

SERVICE_OF = {
    "ReplicatedStorage": 'game:GetService("ReplicatedStorage")',
    "ServerScriptService": 'game:GetService("ServerScriptService")',
    "StarterPlayer": 'game:GetService("StarterPlayer")',
    "Workspace": "workspace",
    "Lighting": 'game:GetService("Lighting")',
}


def mappings(project):
    """[(src_path, roblox_expr)] from the Rojo project tree, longest path first."""
    out = []

    def walk(node, parts):
        for k, v in node.items():
            if k.startswith("$") or not isinstance(v, dict):
                continue
            here = parts + [k]
            if "$path" in v:
                svc = SERVICE_OF.get(here[0], 'game:GetService("%s")' % here[0])
                expr = ".".join([svc] + here[1:])
                out.append((v["$path"].replace("\\", "/").rstrip("/"), expr))
            else:
                walk(v, here)

    walk(project["tree"], [])
    return sorted(out, key=lambda m: -len(m[0]))


def to_instance_path(src_file, rel, maps):
    """src/server/Weapons/Whip.luau + '../../shared/Sim/Damage' -> absolute expr."""
    target = os.path.normpath(os.path.join(os.path.dirname(src_file), rel)).replace("\\", "/")
    for path, expr in maps:
        if target == path:
            return "require(%s)" % expr
        if target.startswith(path + "/"):
            rest = target[len(path) + 1:].split("/")
            return "require(%s)" % ".".join([expr] + rest)
    raise SystemExit("build_place: %s requires %r -> %s, which no project mapping covers"
                     % (src_file, rel, target))


def main():
    project = json.load(open(os.path.join(ROOT, "default.project.json")))
    maps = mappings(project)
    build_src = os.path.join(ROOT, "build", "src")
    shutil.rmtree(build_src, ignore_errors=True)
    shutil.copytree(os.path.join(ROOT, "src"), build_src)

    rewritten = 0
    for dirpath, _, files in os.walk(build_src):
        for fn in files:
            if not fn.endswith(".luau"):
                continue
            full = os.path.join(dirpath, fn)
            src_rel = "src/" + os.path.relpath(full, build_src).replace("\\", "/")
            text = open(full).read()
            new, n = REQ.subn(lambda m: to_instance_path(src_rel, m.group(1), maps), text)
            if n:
                open(full, "w").write(new)
                rewritten += n
    print("rewrote %d require(s) into instance paths" % rewritten)

    # The build project lives in build/, and Rojo resolves $path relative to the
    # project file's own directory, so the original "src/..." paths already point
    # at build/src/... and need no rewriting.
    bp = os.path.join(ROOT, "build", "place.project.json")
    json.dump(project, open(bp, "w"), indent=2)

    out = os.path.join(ROOT, "build", "SurvivorsLike.rbxl")
    subprocess.run(["rojo", "build", bp, "-o", out], cwd=ROOT, check=True)
    print("built", out)
    # Nothing may remain relative: that would silently fail in Studio.
    leftover = subprocess.run(
        ["grep", "-rn", '-E', r'require\(\s*"\.', build_src],
        capture_output=True, text=True).stdout.strip()
    if leftover:
        print("FAIL: relative requires survived the rewrite:\n" + leftover)
        return 1
    print("verified: no relative requires remain in the built tree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
