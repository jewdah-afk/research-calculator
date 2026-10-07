import json,sys,os
p='figma_ids.json'; d=json.load(open(p)) if os.path.exists(p) else {}
for k,v in json.loads(sys.stdin.read()).items(): d[k.split('/assets/figma/')[1][:-4]]=v
json.dump(d,open(p,'w'),indent=0,sort_keys=True); print(len(d))
