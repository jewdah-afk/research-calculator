#!/usr/bin/env python3
"""Run every frontier QA script under the Luau interpreter and with native codegen.

Usage: python3 run.py [--luau PATH] [script.luau ...]
Writes PNG frames to qa/out/, a timing table to qa/out/RESULTS.md, and exits 1 on any failed check.
"""
import argparse
import glob
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")


def parse(stream: bytes):
    times, checks, images, done = [], [], [], None
    i = 0
    n = len(stream)
    while i < n:
        j = stream.find(b"\n", i)
        if j < 0:
            j = n
        line = stream[i:j]
        i = j + 1
        if not line.startswith(b"@@"):
            continue
        parts = line.decode("utf-8", "replace").split(" ")
        tag = parts[0]
        if tag == "@@TIME":
            times.append((parts[1], float(parts[2]), int(parts[3])))
        elif tag == "@@CHECK":
            checks.append((parts[1], parts[2], " ".join(parts[3:])))
        elif tag == "@@IMG":
            name, w, h, nb = parts[1], int(parts[2]), int(parts[3]), int(parts[4])
            images.append((name, w, h, stream[i:i + nb]))
            i += nb + 1
        elif tag == "@@DONE":
            done = int(parts[1])
    return times, checks, images, done


def run(luau: str, script: str, native: bool):
    args = [luau] + (["--codegen"] if native else []) + ["-O2", os.path.basename(script)]
    p = subprocess.run(args, cwd=os.path.dirname(script), capture_output=True, timeout=900)
    return p.returncode, p.stdout, p.stderr.decode("utf-8", "replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default=os.environ.get("LUAU", "luau"))
    ap.add_argument("scripts", nargs="*")
    a = ap.parse_args()
    scripts = a.scripts or sorted(glob.glob(os.path.join(HERE, "test_*.luau")))
    os.makedirs(OUT, exist_ok=True)
    failed = False
    rows = []
    for s in scripts:
        s = os.path.abspath(s)
        res = {}
        for native in (False, True):
            code, out, err = run(a.luau, s, native)
            times, checks, images, done = parse(out)
            mode = "native" if native else "interp"
            if code != 0 or done is None:
                failed = True
                print(f"[{mode}] {os.path.basename(s)} CRASHED (exit {code})\n{err[-2000:]}")
                continue
            for name, status, detail in checks:
                if status != "ok":
                    failed = True
                    print(f"[{mode}] FAIL {name}: {detail}")
            if not native:
                for name, w, h, raw in images:
                    Image.frombytes("RGBA", (w, h), raw).save(os.path.join(OUT, f"{name}.png"))
                print(f"{os.path.basename(s)}: {len(checks)} checks, {len(images)} images")
            for name, ms, iters in times:
                res.setdefault(name, {})[mode] = ms
        for name, d in res.items():
            rows.append((os.path.basename(s), name, d.get("interp"), d.get("native")))
    # Merge into RESULTS.md: rows from scripts not run this time are kept.
    path = os.path.join(OUT, "RESULTS.md")
    ran = {os.path.basename(s) for s in scripts}
    kept = []
    if os.path.exists(path):
        for line in open(path).read().splitlines()[2:]:
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) == 4 and cells[0] not in ran:
                kept.append(line)
    fmt = lambda v: "-" if v is None else f"{v:.3f}"
    new = [f"| {s} | {name} | {fmt(i)} | {fmt(nt)} |" for s, name, i, nt in rows]
    with open(path, "w") as f:
        f.write("| Script | Measure | Interpreter ms | Native ms |\n|---|---|---|---|\n")
        f.write("\n".join(sorted(kept + new)) + "\n")
    for s, name, i, nt in rows:
        fmt = lambda v: "-" if v is None else f"{v:8.3f}"
        print(f"  {name:40s} interp {fmt(i)} ms   native {fmt(nt)} ms")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
