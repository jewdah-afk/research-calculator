import re,os,sys
from PIL import Image, ImageDraw
S=sys.argv[1]; d=open(f"{S}/frames.bin","rb").read()
ims=[]
for m in re.finditer(rb"@@(\w+) (\d+)\n",d):
    n=m.group(1).decode(); L=int(m.group(2)); open(f"{S}/png/{n}.ppm","wb").write(d[m.end():m.end()+L]); ims.append(n)
ims.sort(); sc=3; W=96*sc; cols=5; rows=(len(ims)+cols-1)//cols
sh=Image.new("RGB",(cols*(W+8),rows*(W+22)),(30,30,30)); dr=ImageDraw.Draw(sh)
for i,n in enumerate(ims):
    im=Image.open(f"{S}/png/{n}.ppm").resize((W,W),Image.NEAREST); x,y=(i%cols)*(W+8),(i//cols)*(W+22)
    sh.paste(im,(x,y+18)); dr.text((x+2,y+3),n,fill=(255,255,255))
sh.save(f"{S}/sheet.png")
