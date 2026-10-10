"""Header v2 (owner 2026-10-10): apply the Figma header fix to the generated layouts without a full re-export.
Mirrors exactly what was done to every `header` in Figma (UI v2 page): remove `depth band`, `bevel`, `swoosh`;
`ink` = full-width 4 px solid #0b0c10 at the bottom; `glow` runs y 18 .. H-4; one `top highlight` (2 px white @0.35,
inset 4); the title centred in the band above the ink. A later full re-export produces the same nodes. Idempotent."""
import glob, os, re

LAY = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'client', 'UI', 'Figma', 'Layouts')

def add_style(src, style):
    """append a style to the P table, return its 1-based index (reuses an identical one)"""
    m = re.search(r'\n P = \{', src)
    start = m.end() - 1
    depth, i = 0, start
    while True:   # find the matching close brace of P
        c = src[i]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: break
        elif c == '"':
            i = src.index('"', i + 1)
        i += 1
    body = src[start + 1:i]
    # split top-level entries
    entries, d, cur, k = [], 0, '', 0
    while k < len(body):
        c = body[k]
        if c == '"':
            j = body.index('"', k + 1); cur += body[k:j + 1]; k = j + 1; continue
        if c == '{': d += 1
        if c == '}': d -= 1
        if c == ',' and d == 0: entries.append(cur); cur = ''
        else: cur += c
        k += 1
    if cur.strip(): entries.append(cur)
    if style in entries: return src, entries.index(style) + 1
    return src[:i] + ',' + style + src[i:], len(entries) + 1

def fix(path):
    src = open(path).read()
    m = re.search(r'\{t="F",n="header",x=0,y=0,w=([\d.]+),h=([\d.]+),', src)
    if not m: return None
    W, H = float(m.group(1)), float(m.group(2))
    blk = src[m.start():m.start() + 3000]
    if 'n="depth band"' not in blk and re.search(r'n="ink",x=0,y=[\d.]+,w=[\d.]+,h=4,', blk):
        return 'already'
    src, ink_s = add_style(src, '{{"s","0b0c10",1}}')
    src, hi_s = add_style(src, '{{"s","ffffff",0.35}}')
    hs = src.index('{t="F",n="header",x=0,y=0,')   # re-find: add_style shifted offsets
    hs = src.rfind('\n', 0, hs) + 1
    # header block = from header start to its closing "}}," (children end); work line by line inside it
    lines = src[hs:].split('\n')
    out, n, inside = [], 0, True
    for ln in lines:
        if not inside: out.append(ln); continue
        if n > 0 and ln.startswith('  {') and not ln.startswith('   '):   # next sibling of header: header ended
            inside = False; out.append(ln); continue
        n += 1
        if re.search(r'n="(depth band|bevel|swoosh)"', ln):
            continue
        if 'n="ink"' in ln:
            ln = re.sub(r'\{t="F",n="ink",[^}]*\}', '{t="F",n="top highlight",x=4,y=4,w=%g,h=2,f=%d},\n   {t="F",n="ink",x=0,y=%g,w=%g,h=4,f=%d}' % (W - 8, hi_s, H - 4, W, ink_s), ln)
        elif 'n="glow"' in ln:
            ln = re.sub(r'y=[\d.]+,w=[\d.]+,h=[\d.]+', 'y=18,w=%g,h=%g' % (W, H - 22), ln, count=1)
        elif re.search(r'\{t="T",', ln) and 'fs=' in ln:
            hh = float(re.search(r',h=([\d.]+)', ln).group(1))
            ln = re.sub(r',y=[\d.]+,', ',y=%d,' % round((H - 4 - hh) / 2), ln, count=1)
        out.append(ln)
    new = src[:hs] + '\n'.join(out)
    open(path, 'w').write(new)
    return 'fixed'

for p in sorted(glob.glob(os.path.join(LAY, '*.luau'))):
    r = fix(p)
    if r: print(r, os.path.basename(p))
