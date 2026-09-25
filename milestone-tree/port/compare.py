# Compare JS and Luau dumps: python3 compare.py fz_js.txt fz_lua.txt [tol]
import sys, re, math, collections
def load(fn):
    secs = {}; cur = None
    for line in open(fn, encoding='utf-8', errors='replace'):
        line = line.rstrip('\n')
        if line.startswith('##'):
            parts = line[2:].split(' ')
            cur = ' '.join(parts[:2]); secs[cur] = {'__status': ' '.join(parts[2:])}
        elif line.startswith('-- '): continue
        elif cur is not None and '=' in line:
            k, v = line.split('=', 1); secs[cur][k] = v
        elif cur is not None and '#' in line:
            k, v = line.rsplit('#', 1); secs[cur][k + '#len'] = v
    return secs
TOL = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-9
def num(s):
    try: return float(s)
    except: return None
INTRE = re.compile(r'^[SN](-?\d+)$')
def canon_inf(v):
    if v in ('D1:3:Infinity', 'D1:2:Infinity', 'D1:1:Infinity', 'D1:0:Infinity', 'N' + 'Infinity'): return 'D1:inf'
    return v
def close(a, b):
    if a == b: return True
    if a in ('nil', '<none>') and b in ('nil', '<none>'): return True
    ma, mb = INTRE.match(a), INTRE.match(b)
    if ma and mb and ma.group(1) == mb.group(1): return True   # "11" vs 11: JS for-in keys are strings, the port keeps numbers
    a, b = canon_inf(a), canon_inf(b)
    if a == b: return True
    if a.startswith('N') and b.startswith('N'):
        x, y = num(a[1:]), num(b[1:])
        if x is None or y is None: return False
        if math.isnan(x) and math.isnan(y): return True
        return abs(x - y) <= TOL * max(1.0, abs(x), abs(y))
    if a.startswith('D') and b.startswith('D'):
        pa, pb = a[1:].split(':'), b[1:].split(':')
        if len(pa) == 3 and len(pb) == 3 and pa[0] == pb[0]:
            la, lb = int(pa[1]), int(pb[1]); x, y = float(pa[2]), float(pb[2])
            if la == lb: return abs(x - y) <= TOL * max(1.0, abs(x), abs(y)) or (la == 0 and abs(x-y) <= TOL*max(abs(x),abs(y)))
            # values right at the 1e15 boundary between two forms
            def up(l, v): return (l + 1, math.log10(v)) if v > 0 else (l, v)
            if la + 1 == lb: la, x = up(la, x)
            elif lb + 1 == la: lb, y = up(lb, y)
            return la == lb and abs(x - y) <= TOL * max(1.0, abs(x), abs(y))
    return False
js, lu = load(sys.argv[1]), load(sys.argv[2])
bad = collections.Counter(); examples = {}; nsec = 0; ncmp = 0; status = []
def pat(p): return re.sub(r'\[\d+\]', '[]', p)
for sec in js:
    if sec not in lu: status.append(f'{sec}: missing in lua ({js[sec]["__status"]})'); continue
    a, b = js[sec], lu[sec]
    if a['__status'] or b['__status']:
        if a['__status'] != b['__status']: status.append(f'{sec}: js[{a["__status"]}] lua[{b["__status"]}]')
        continue
    nsec += 1
    for k in set(a) | set(b):
        if k == '__status': continue
        ncmp += 1
        va, vb = a.get(k, '<none>'), b.get(k, '<none>')
        if not close(va, vb):
            p = pat(k); bad[p] += 1
            if p not in examples: examples[p] = (sec, k, va[:90], vb[:90])
print(f'sections compared {nsec}, values {ncmp}, mismatching values {sum(bad.values())} in {len(bad)} paths')
for s in status[:20]: print('  STATUS', s)
for p, n in bad.most_common(int(sys.argv[4]) if len(sys.argv) > 4 else 40):
    sec, k, va, vb = examples[p]; print(f'{n:5d} {p}\n        [{sec}] js={va}\n        {" "*len(sec)}  lua={vb}')
