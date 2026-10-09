"""Reassemble the exporter's PWX slices from Claude Code session transcripts into out/<root>.json.

usage: python collect.py <dir-with-jsonl> [<dir> ...]
Every tool_result whose text starts with "PWX|<root>|<part>|<nparts>|" is a slice; a root is complete when all
parts are present. Writes out/<root with : replaced by ->.json ({d, t}) and prints what is missing."""
import glob, json, os, sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
parts = {}  # root -> {part: text}, nparts


def texts(obj):
    if isinstance(obj, dict):
        if obj.get("type") == "tool_result":
            c = obj.get("content")
            if isinstance(c, str):
                yield c
            elif isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "text":
                        yield x.get("text", "")
        for v in obj.values():
            if isinstance(v, (dict, list)):
                yield from texts(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from texts(v)


def scan(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if "PWX|" not in line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            for t in texts(d):
                t = t.strip()
                if t.startswith('"'):
                    try:
                        t = json.loads(t)
                    except Exception:
                        continue
                if not t.startswith("PWX|"):
                    continue
                _, root, part, n, data = t.split("|", 4)
                e = parts.setdefault(root, {"n": int(n), "p": {}})
                e["p"][int(part)] = data


for d in sys.argv[1:]:
    for p in glob.glob(os.path.join(d, "**", "*.jsonl"), recursive=True) + glob.glob(os.path.join(d, "**", "*.output"), recursive=True):
        scan(p)

done, missing = [], []
for root, e in sorted(parts.items()):
    have = sorted(e["p"])
    if have == list(range(e["n"])):
        s = "".join(e["p"][i] for i in have)
        try:
            obj = json.loads(s)
        except Exception as ex:
            missing.append(f"{root}: bad json {ex}")
            continue
        with open(os.path.join(OUT, root.replace(":", "-") + ".json"), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False)
        done.append(root)
    else:
        missing.append(f"{root}: have {have} of {e['n']}")
print("complete:", len(done), " ".join(done))
print("incomplete:", "\n  ".join(missing) if missing else "none")
