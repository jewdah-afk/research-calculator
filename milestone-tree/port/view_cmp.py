# Compare view dumps: python3 view_cmp.py js.txt lua.txt [max]
import sys, json, re, collections
def load(fn):
    secs = {}; cur = None
    for line in open(fn, encoding='utf-8', errors='replace'):
        line = line.rstrip('\n')
        if line.startswith('##'): cur = line[2:]; secs[cur] = []
        elif line.startswith('-- '): continue
        elif cur is not None: secs[cur].append(line)
    return secs
NUM = re.compile(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?')
# per-mille progress values (floored from a float ratio): a last-digit float difference can move them by one
PERMILLE = {'pr', 'gp', 'bp'}
noise = collections.Counter()
def walk(a, b, path, out):
    if type(a) != type(b): out.append((path, repr(a)[:120], repr(b)[:120])); return
    if isinstance(a, dict):
        for k in list(a.keys()) + [k for k in b.keys() if k not in a]:
            if k not in a or k not in b: out.append((path + '.' + k, repr(a.get(k))[:120], repr(b.get(k))[:120]))
            else: walk(a[k], b[k], path + '.' + k, out)
        if [k for k in a.keys() if k in b] != [k for k in b.keys() if k in a]: out.append((path + ' keyorder', str(list(a.keys())), str(list(b.keys()))))
    elif isinstance(a, list):
        if len(a) != len(b): out.append((path + '#', str(len(a)), str(len(b))))
        for i in range(min(len(a), len(b))): walk(a[i], b[i], path + '[' + str(i) + ']', out)
    elif a != b:
        key = path.rsplit('.', 1)[-1]
        if key in PERMILLE and isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and abs(a - b) <= 1:
            noise[re.sub(r'\[\d+\]', '[]', path)] += 1; return
        out.append((path, repr(a)[:160], repr(b)[:160]))
js, lu = load(sys.argv[1]), load(sys.argv[2])
bad = collections.Counter(); ex = {}; n = 0
for sec in js:
    if sec not in lu: print('missing in lua:', sec); continue
    n += 1
    ja, la = js[sec], lu[sec]
    for i in range(max(len(ja), len(la))):
        x = ja[i] if i < len(ja) else 'null'; y = la[i] if i < len(la) else 'null'
        if x == y: continue
        try: A, B = json.loads(x), json.loads(y)
        except Exception as e: bad['<unparsable>'] += 1; ex.setdefault('<unparsable>', (sec, x[:100], y[:100])); continue
        out = []; walk(A, B, '', out)
        for p, va, vb in out:
            key = re.sub(r'\[\d+\]', '[]', p); bad[key] += 1; ex.setdefault(key, (sec, va, vb))
print(f'sections {n}, differing values {sum(bad.values())} in {len(bad)} paths')
if noise: print(f'per-mille noise (within 1): {sum(noise.values())} values in {len(noise)} paths: ' + ', '.join(sorted(noise)[:8]))
for k, c in bad.most_common(int(sys.argv[3]) if len(sys.argv) > 3 else 40):
    sec, va, vb = ex[k]; print(f'{c:5d} {k}\n        [{sec}]\n        js ={va}\n        lua={vb}')
