# Every distinct HTML string in a view dump (view_js.js output) as a Luau table: python3 tools/html_cases.py dump.txt out.luau
import json, sys
seen, out = set(), []
def walk(x):
    if isinstance(x, dict):
        for k, v in x.items():
            if k in ('h', 'tip', 'title', 'body') and isinstance(v, str):
                if v not in seen: seen.add(v); out.append(v)
            else: walk(v)
    elif isinstance(x, list):
        for y in x: walk(y)
for line in open(sys.argv[1], encoding='utf-8'):
    if line.startswith('{') or line.startswith('['):
        try: walk(json.loads(line))
        except ValueError: pass
def lit(s):
    # a Luau long string: its level must not appear in the text (or right after it), and a leading newline
    # would be dropped, so it gets one more
    level = 1
    while (']' + '=' * level + ']') in s + ']': level += 1
    return '[' + '=' * level + '[' + ('\n' if s.startswith('\n') else '') + s + ']' + '=' * level + ']'
open(sys.argv[2], 'w', encoding='utf-8').write('return {\n' + ',\n'.join(lit(s) for s in out) + '\n}\n')
print(len(out), 'html strings')
