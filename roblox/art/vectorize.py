# Flat "vector" look: posterize each render to a few flat tones (shadow / base / light / highlight),
# smooth edges, then thick dark outline + drop like the UI text.
import os,sys,colorsys
from PIL import Image, ImageFilter, ImageChops
src,dst=sys.argv[1],sys.argv[2]; os.makedirs(dst,exist_ok=True)
def flat(im):
    im=im.filter(ImageFilter.MedianFilter(5))
    px=im.load(); W,H=im.size
    for y in range(H):
        for x in range(W):
            r,g,b,a=px[x,y]
            if a<30: px[x,y]=(0,0,0,0); continue
            h,l,s=colorsys.rgb_to_hls(r/255,g/255,b/255)
            # 4 bands of lightness, saturation pushed up
            if l>0.9: L=0.97
            elif l>0.62: L=0.7
            elif l>0.38: L=0.52
            else: L=0.32
            s=min(1,s*1.35) if L<0.95 else s*0.3
            rr,gg,bb=colorsys.hls_to_rgb(h,L,s)
            px[x,y]=(int(rr*255),int(gg*255),int(bb*255),255)
    return im.filter(ImageFilter.ModeFilter(5))
for f in sorted(os.listdir(src)):
    if not f.endswith('.png'): continue
    im=flat(Image.open(os.path.join(src,f)).convert('RGBA'))
    W,H=im.size; pad=26
    big=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0)); big.alpha_composite(im,(pad,pad))
    a=big.getchannel('A').point(lambda v:255 if v>40 else 0)
    ring=a.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(1.2)).point(lambda v:255 if v>110 else int(v*2.3))
    drop=Image.new('L',ring.size,0); drop.paste(ring,(0,8)); drop=ImageChops.lighter(drop,ring)
    ink=Image.new('RGBA',big.size,(11,12,16,255)); ink.putalpha(drop)
    out=Image.new('RGBA',big.size,(0,0,0,0)); out.alpha_composite(ink); out.alpha_composite(big)
    out=out.crop(out.getbbox()); s=max(out.size); sq=Image.new('RGBA',(s,s),(0,0,0,0)); sq.alpha_composite(out,((s-out.width)//2,(s-out.height)//2))
    sq.resize((256,256),Image.LANCZOS).save(os.path.join(dst,f))
