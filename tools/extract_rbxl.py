#!/usr/bin/env python3
"""Extract every script from a binary .rbxl into a Rojo-style folder tree (read-only reference).

Usage: pip install lz4 zstandard && python3 tools/extract_rbxl.py <place.rbxl> <out_dir>

Naming follows Rojo conventions:
  Script -> Name.server.lua   LocalScript -> Name.client.lua   ModuleScript -> Name.lua
  A script with script descendants becomes a folder with init(.server/.client).lua.
Only ancestors of scripts are emitted. Duplicate sibling names get a " (2)", " (3)" suffix.
Also writes <out_dir>/_instance_tree.txt (every instance: path<TAB>ClassName).
"""
import os, struct, sys
import lz4.block, zstandard

SCRIPT_EXT = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}
INIT = {"Script": "init.server.lua", "LocalScript": "init.client.lua", "ModuleScript": "init.lua"}


def _interleaved(b, n):
    out = []
    for i in range(n):
        v = (b[i] << 24) | (b[n + i] << 16) | (b[2 * n + i] << 8) | b[3 * n + i]
        out.append((v >> 1) ^ -(v & 1))
    return out


def _refs(b, n):
    acc, out = 0, []
    for x in _interleaved(b, n):
        acc += x
        out.append(acc)
    return out


def parse(path):
    d = open(path, "rb").read()
    assert d[:8] == b"<roblox!", "not a binary Roblox place"
    pos = 32
    classes, cls, props, parent = {}, {}, {"Name": {}, "Source": {}}, {}
    while pos < len(d):
        name = d[pos:pos + 4]
        clen, ulen = struct.unpack("<II", d[pos + 4:pos + 12])
        pos += 16
        if clen == 0:
            data = d[pos:pos + ulen]; pos += ulen
        else:
            raw = d[pos:pos + clen]; pos += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                data = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                data = lz4.block.decompress(raw, uncompressed_size=ulen)
        if name == b"END\0":
            break
        if name == b"INST":
            cid, l = struct.unpack("<II", data[:8])
            cn = data[8:8 + l].decode()
            p = 8 + l + 1
            n, = struct.unpack("<I", data[p:p + 4])
            r = _refs(data[p + 4:p + 4 + 4 * n], n)
            classes[cid] = r
            for x in r:
                cls[x] = cn
        elif name == b"PROP":
            cid, l = struct.unpack("<II", data[:8])
            pn = data[8:8 + l].decode()
            p = 8 + l
            if data[p] == 1 and pn in props:  # String type
                p += 1
                for ref in classes[cid]:
                    sl, = struct.unpack("<I", data[p:p + 4])
                    props[pn][ref] = data[p + 4:p + 4 + sl].decode("utf-8", "replace")
                    p += 4 + sl
        elif name == b"PRNT":
            n, = struct.unpack("<I", data[1:5])
            c = _refs(data[5:5 + 4 * n], n)
            pr = _refs(data[5 + 4 * n:5 + 8 * n], n)
            parent.update(zip(c, pr))
    return cls, props["Name"], props["Source"], parent


def safe(s):
    return "".join("_" if ch in '<>:"/\\|?*' else ch for ch in s).strip() or "_"


def main(src, out):
    cls, names, sources, parent = parse(src)
    children = {}
    for c, p in parent.items():
        children.setdefault(p, []).append(c)

    has_script = {}
    def mark(r):
        kid_hits = [mark(c) for c in children.get(r, [])]  # visit every child (no short-circuit)
        v = cls.get(r) in SCRIPT_EXT or any(kid_hits)
        has_script[r] = v
        return v
    roots = [r for r in cls if parent.get(r, -1) == -1]
    for r in roots:
        mark(r)

    count = 0
    def emit(r, dirpath, used):
        nonlocal count
        base = safe(names.get(r, cls[r]))
        k = used.get(base, 0) + 1; used[base] = k
        if k > 1:
            base = f"{base} ({k})"
        kids = [c for c in children.get(r, []) if has_script.get(c)]
        c = cls[r]
        if c in SCRIPT_EXT and not kids:
            open(os.path.join(dirpath, base + SCRIPT_EXT[c]), "w").write(sources.get(r, ""))
            count += 1
            return
        sub = os.path.join(dirpath, base)
        os.makedirs(sub, exist_ok=True)
        if c in SCRIPT_EXT:
            open(os.path.join(sub, INIT[c]), "w").write(sources.get(r, ""))
            count += 1
        u = {}
        for ch in sorted(kids, key=lambda x: names.get(x, "")):
            emit(ch, sub, u)

    os.makedirs(out, exist_ok=True)
    u = {}
    for r in sorted(roots, key=lambda x: names.get(x, "")):
        if has_script.get(r):
            emit(r, out, u)

    def path(r):
        p = []
        while r != -1 and r in cls:
            p.append(names.get(r, cls[r])); r = parent.get(r, -1)
        return "/".join(reversed(p))
    with open(os.path.join(out, "_instance_tree.txt"), "w") as f:
        for line in sorted(f"{path(r)}\t{cls[r]}" for r in cls):
            f.write(line + "\n")
    print(f"{count} scripts, {len(cls)} instances -> {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
