"""List every .luau under src/ with its Studio instance path -> tools/manifest.json (for sync.luau over http :8778)."""
import json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
MAP = {'src/shared': ['ReplicatedStorage', 'Peckwood'], 'src/server': ['ServerScriptService', 'Peckwood'], 'src/client': ['StarterPlayer', 'StarterPlayerScripts', 'Peckwood']}
out = []
for rel, base in MAP.items():
    for dp, _, fs in os.walk(os.path.join(ROOT, rel)):
        sub = os.path.relpath(dp, os.path.join(ROOT, rel)).replace(os.sep, '/')
        parts = [] if sub == '.' else sub.split('/')
        for f in fs:
            if not f.endswith('.luau'): continue
            b, cls = f[:-5], 'ModuleScript'
            if b.endswith('.server'): b, cls = b[:-7], 'Script'
            elif b.endswith('.client'): b, cls = b[:-7], 'LocalScript'
            # init.luau / init.server.luau / init.client.luau: the folder itself is the script (Rojo semantics)
            path = base + parts if b == 'init' else base + parts + [b]
            out.append({'path': path, 'class': cls, 'url': (rel + '/' + '/'.join(parts + [f])).replace('//', '/')})
out.sort(key=lambda x: len(x['path']))   # parents (init scripts) before their children
json.dump(out, open(os.path.join(ROOT, 'tools', 'manifest.json'), 'w'), indent=0)
print(len(out))
