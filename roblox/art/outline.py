# silhouette outline: dilate alpha into a thick black edge + a small drop, icon on top
import os,sys
from PIL import Image, ImageFilter, ImageChops
src,dst=sys.argv[1],sys.argv[2]; os.makedirs(dst,exist_ok=True)
for f in os.listdir(src):
    if not f.endswith('.png'): continue
    im=Image.open(os.path.join(src,f)).convert('RGBA')
    W,H=im.size; pad=24
    big=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0)); big.alpha_composite(im,(pad,pad))
    a=big.getchannel('A').point(lambda v:255 if v>40 else 0)
    ring=a.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(1.2)).point(lambda v:255 if v>110 else int(v*2.3))
    drop=Image.new('L',ring.size,0); drop.paste(ring,(0,6)); drop=ImageChops.lighter(drop,ring)
    ink=Image.new('RGBA',big.size,(11,12,16,255)); ink.putalpha(drop)
    out=Image.new('RGBA',big.size,(0,0,0,0)); out.alpha_composite(ink); out.alpha_composite(big)
    out=out.crop(out.getbbox()); s=max(out.size); sq=Image.new('RGBA',(s,s),(0,0,0,0)); sq.alpha_composite(out,((s-out.width)//2,(s-out.height)//2))
    sq.resize((256,256),Image.LANCZOS).save(os.path.join(dst,f))
