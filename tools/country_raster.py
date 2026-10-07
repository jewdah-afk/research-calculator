import json, math
from PIL import Image, ImageDraw
d=json.load(open('c50.json'))
tf=d['transform']; sc,tr=tf['scale'],tf['translate']
arcs=[]
for a in d['arcs']:
    x=y=0; pts=[]
    for dx,dy in a: x+=dx; y+=dy; pts.append((x*sc[0]+tr[0], y*sc[1]+tr[1]))
    arcs.append(pts)
def ring(idx):
    out=[]
    for k in idx:
        p=arcs[k] if k>=0 else arcs[~k][::-1]
        out.extend(p if not out else p[1:])
    return out
C={ "United States of America":("usa","USA",-77.04,38.9,(-125,-66,24,50)), "Brazil":("brazil","Brazil",-47.9,-15.8,None), "United Kingdom":("uk","United Kingdom",-0.13,51.5,None),
 "Canada":("canada","Canada",-75.7,45.4,(-141,-52,41,70)), "Mexico":("mexico","Mexico",-99.13,19.43,None), "Germany":("germany","Germany",13.4,52.52,None), "France":("france","France",2.35,48.86,(-6,10,41,52)),
 "Philippines":("philippines","Philippines",120.98,14.6,None), "Indonesia":("indonesia","Indonesia",106.85,-6.2,None), "Australia":("australia","Australia",149.13,-35.28,None),
 "Spain":("spain","Spain",-3.7,40.42,(-10,5,35,44.5)), "Italy":("italy","Italy",12.5,41.9,None), "Japan":("japan","Japan",139.69,35.69,(128,146,30,46)), "Turkey":("turkey","Turkey",32.86,39.93,None),
 "Poland":("poland","Poland",21.01,52.23,None), "Netherlands":("netherlands","Netherlands",4.9,52.37,(3,8,50,54)), "South Korea":("korea","South Korea",126.98,37.57,(125,130,33,39)),
 "Thailand":("thailand","Thailand",100.5,13.75,None), "Argentina":("argentina","Argentina",-58.38,-34.6,(-74,-53,-56,-21)), "Vietnam":("vietnam","Vietnam",105.85,21.03,None) }
TARGET=13000
out={}
for g in d['objects']['countries']['geometries']:
    nm=g['properties']['name']
    if nm not in C: continue
    cid,label,clon,clat,bb=C[nm]
    polys=g['arcs'] if g['type']=='MultiPolygon' else [g['arcs']]
    rings=[]
    for P in polys:
        outer=ring(P[0])
        if bb:
            cx=sum(p[0] for p in outer)/len(outer); cy=sum(p[1] for p in outer)/len(outer)
            if not(bb[0]<=cx<=bb[1] and bb[2]<=cy<=bb[3]): continue
        rings.append([outer]+[ring(h) for h in P[1:]])
    lats=[p[1] for R in rings for p in R[0]]; lons=[p[0] for R in rings for p in R[0]]
    lat0=(min(lats)+max(lats))/2; k=math.cos(math.radians(lat0))
    proj=lambda p:(p[0]*k,-p[1])
    xs=[proj(p)[0] for R in rings for p in R[0]]; ys=[proj(p)[1] for R in rings for p in R[0]]
    x0,x1,y0,y1=min(xs),max(xs),min(ys),max(ys)
    # find scale so land ~= TARGET tiles
    def draw(s):
        W=int((x1-x0)*s)+3; H=int((y1-y0)*s)+3
        im=Image.new('L',(W,H),0); dr=ImageDraw.Draw(im)
        for R in rings:
            dr.polygon([((proj(p)[0]-x0)*s+1,(proj(p)[1]-y0)*s+1) for p in R[0]],fill=1)
            for h in R[1:]: dr.polygon([((proj(p)[0]-x0)*s+1,(proj(p)[1]-y0)*s+1) for p in h],fill=0)
        return im
    s=10
    for _ in range(30):
        im=draw(s); n=sum(im.getdata())
        s*=math.sqrt(TARGET/max(1,n))
    im=draw(s); W,H=im.size; px=im.load()
    # drop tiny islets (< 25 tiles) via flood fill
    seen=set(); keep=set()
    for y in range(H):
        for x in range(W):
            if px[x,y] and (x,y) not in seen:
                comp=[(x,y)]; seen.add((x,y)); q=[(x,y)]
                while q:
                    a,b=q.pop()
                    for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
                        n2=(a+dx,b+dy)
                        if 0<=n2[0]<W and 0<=n2[1]<H and px[n2] and n2 not in seen: seen.add(n2); q.append(n2); comp.append(n2)
                if len(comp)>=25: keep.update(comp)
    rows=[''.join('1' if (x,y) in keep else '0' for x in range(W)) for y in range(H)]
    cx,cy=proj((clon,clat)); cap=[round((cx-x0)*s+1),round((cy-y0)*s+1)]
    out[cid]={"name":label,"W":W,"H":H,"rows":rows,"cap":cap,"n":len(keep)}
    print(cid,W,H,len(keep))
json.dump(out,open('countries.json','w'),separators=(',',':'))
