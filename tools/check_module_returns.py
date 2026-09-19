#!/usr/bin/env python3
"""Gate: every ModuleScript must return exactly one non-nil value.

Roblox raises "Module code did not return exactly one value" when a
ModuleScript returns nil, and every module that requires it fails in turn. The
plain `luau` CLI tolerates a nil return, so the headless tests cannot see this:
it is green everywhere except in the running game.

Generates a Luau program that requires every ModuleScript under src/ and
asserts the result is non-nil, then runs it. Requiring them all also catches
a module that errors at load time, and a require cycle.

Usage: check_module_returns.py <src_dir>
"""
import os, subprocess, sys, tempfile


def modules(src):
    out = []
    for dirpath, _, files in os.walk(src):
        for fn in sorted(files):
            if not fn.endswith(".luau"):
                continue
            if fn.endswith(".server.luau") or fn.endswith(".client.luau"):
                continue  # Scripts and LocalScripts, not ModuleScripts
            out.append(os.path.join(dirpath, fn))
    return sorted(out)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "src"
    mods = modules(src)
    if not mods:
        print("no modules found under", src)
        return 1

    # A module that touches Roblox globals cannot be required headlessly; that is
    # not a defect. Check those statically instead: the final top-level return
    # must not be `nil`.
    ROBLOX = ("game:", "workspace", "Instance.new", "task.", "script.")
    static, loadable = [], []
    for m in mods:
        src_text = open(m).read()
        (static if any(t in src_text for t in ROBLOX) else loadable).append(m)

    bad = 0
    for m in static:
        rets = [l.strip() for l in open(m).read().splitlines()
                if l.startswith("return ")]
        if not rets:
            print("FAIL %s has no top-level return" % m); bad += 1
        elif rets[-1] in ("return nil", "return"):
            print("FAIL %s returns nil: Roblox raises \"Module code did not return "
                  "exactly one value\"" % m); bad += 1
    print("%d Roblox-dependent module(s) checked statically, %d bad" % (len(static), bad))
    if bad:
        return 1

    mods = loadable
    lines = ["local bad = 0", "local checked = 0"]
    for m in mods:
        rel = "./" + os.path.relpath(m, os.path.dirname(os.path.abspath(__file__)) + "/..")
        rel = rel[:-len(".luau")]
        lines.append("do")
        lines.append("\tlocal ok, v = pcall(function() return require(%r) end)" % rel)
        lines.append("\tchecked += 1")
        lines.append("\tif not ok then")
        lines.append("\t\tprint('FAIL %s errored on require: ' .. tostring(v))" % m)
        lines.append("\t\tbad += 1")
        lines.append("\telseif v == nil then")
        lines.append("\t\tprint('FAIL %s returned nil: Roblox raises \"Module code did not return exactly one value\"')" % m)
        lines.append("\t\tbad += 1")
        lines.append("\tend")
        lines.append("end")
    lines.append("print(string.format('%d module(s) checked, %d bad', checked, bad))")
    lines.append("if bad > 0 then error(string.format('%d module(s) do not return one non-nil value', bad), 0) end")

    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=".", delete=False) as fh:
        fh.write("\n".join(lines) + "\n")
        path = fh.name
    try:
        r = subprocess.run(["luau", path], capture_output=True, text=True)
        sys.stdout.write(r.stdout)
        if r.returncode != 0:
            sys.stdout.write(r.stderr)
        return r.returncode
    finally:
        os.unlink(path)


if __name__ == "__main__":
    sys.exit(main())
