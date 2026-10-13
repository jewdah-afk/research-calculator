import re, json, sys
src = sys.argv[1]
md = open(src + '/mods/ModDefaults.as').read()
cb = open(src + '/Combos.as').read()
def val(v):
    v = v.strip()
    v = re.sub(r'new Object\((.*)\)$', r'\1', v)
    v = re.sub(r'([{,])(\w+):', r'\1"\2":', v)
    return json.loads(v)
out = {"turrets": {}, "game_settings": {}, "combos": {}}
for name, key, v in re.findall(r'this\.(Turret\w+)\.(\w+) = (.+?);\n', md):
    out["turrets"].setdefault(name, {})[key] = val(v)
for key, v in re.findall(r'_loc2_\.(\w+) = (.+?);\n', md.split('function initManagers')[1].split('this.GameSettings')[0]):
    out["game_settings"][key] = val(v)
for block in cb.split('_loc1_ = new ComboData();')[1:]:
    d = {k: val(v) for k, v in re.findall(r'_loc1_\.(\w+) = (.+?);', block)}
    name = re.search(r'combo_data\.(\w+) = _loc1_', block).group(1)
    out["combos"][name] = d
json.dump(out, open(sys.argv[2], 'w'), indent=1)
print(len(out["turrets"]), len(out["game_settings"]), len(out["combos"]))
