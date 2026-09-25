// node crop.js in.png out.png x y w h [bg]  -> crop (composited on bg colour or on a sky png)
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const [i,o,x,y,w,h,bg]=process.argv.slice(2);const b=await chromium.launch();const p=await b.newPage();
const d='data:image/png;base64,'+fs.readFileSync(i).toString('base64');const bgd=bg&&bg.endsWith('.png')?'data:image/png;base64,'+fs.readFileSync(bg).toString('base64'):null;
const url=await p.evaluate(async([d,x,y,w,h,bg,bgd])=>{const L=s=>new Promise(r=>{const im=new Image();im.onload=()=>r(im);im.src=s});const im=await L(d);const c=document.createElement('canvas');c.width=w;c.height=h;const t=c.getContext('2d');t.fillStyle=bg&&!bgd?bg:'#07050d';t.fillRect(0,0,w,h);if(bgd){const s=await L(bgd);t.drawImage(s,-x,-y,s.width*(3840/s.width),s.height*(2160/s.height));}t.drawImage(im,-x,-y);return c.toDataURL()},[d,+x,+y,+w,+h,bg,bgd]);
fs.writeFileSync(o,Buffer.from(url.split(',')[1],'base64'));await b.close()})();
