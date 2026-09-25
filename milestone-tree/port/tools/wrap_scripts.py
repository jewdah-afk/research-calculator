# Wraps the Roblox project's scripts as `return function() <source> end` modules in data/wrap/, so the mock
# engine (tests/mock.luau) can run them with their own `script`, `game` and `require`.
import os, re
root = os.path.join(os.path.dirname(__file__), '..', '..', 'src')
out = os.path.join(os.path.dirname(__file__), '..', 'data', 'wrap')
n = 0
listing = []
for d, _, files in os.walk(root):
    for f in files:
        if not f.endswith('.luau') or os.path.basename(d) == 'Game':
            continue
        src = open(os.path.join(d, f), encoding='utf-8').read()
        src = re.sub(r'^export type', 'type', src, flags=re.M)
        rel = os.path.relpath(os.path.join(d, f), root)
        name = re.sub(r'\.(server|client)\.luau$', '.luau', rel)
        p = os.path.join(out, name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'w', encoding='utf-8').write('--!nocheck\nreturn function(...)\n' + src + '\nend\n')
        n += 1
        tag = re.search(r'\.(server|client)\.luau$', rel)
        listing.append(re.sub(r'\.luau$', '', name).replace(os.sep, '/') + ('.' + tag.group(1) if tag else ''))
# the list of wrapped files (the tests build the client's folders from it); stale files from renamed or deleted
# scripts are left out
listing.sort()
open(os.path.join(out, 'files.luau'), 'w', encoding='utf-8').write('return {\n' + ''.join('\t"%s",\n' % x for x in listing) + '}\n')
print('wrapped', n, 'scripts into data/wrap')
