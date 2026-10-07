import json,sys,os
p='asset_ids.json'; d=json.load(open(p)) if os.path.exists(p) else {}
new=json.loads(sys.stdin.read())
for k,v in new.items(): d[k.split(':8799/')[1][:-4]]=v
json.dump(d,open(p,'w'),indent=0,sort_keys=True); print(len(d))
