// node compose.js out.png camX camY [w h]  — composite sky/far/world(/fg) as the player would see it
// camera = world-space top-left of a 1920x1080 view; layer offset = cam * factor
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const [o,cx,cy,w=1920,h=1080]=process.argv.slice(2);const b=await chromium.launch();const p=await b.newPage();
const L=['sky','far','world','fg'].filter(n=>fs.existsSync('out/'+n+'.png')).map(n=>[n,'data:image/png;base64,'+fs.readFileSync('out/'+n+'.png').toString('base64')]);
const F={sky:0.15,far:0.35,world:1,fg:1.25};
const url=await p.evaluate(async([L,F,cx,cy,w,h])=>{const load=s=>new Promise(r=>{const im=new Image();im.onload=()=>r(im);im.src=s});
const c=document.createElement('canvas');c.width=w;c.height=h;const t=c.getContext('2d');t.fillStyle='#05030b';t.fillRect(0,0,w,h);
for(const [n,d] of L){const im=await load(d);const f=F[n];
 // each layer is sized so that panning the world across its range pans the layer across its own range
 t.drawImage(im,-cx*f- (n==='fg'? 0:0),-cy*f);}
return c.toDataURL()},[L,F,+cx,+cy,+w,+h]);
fs.writeFileSync(o,Buffer.from(url.split(',')[1],'base64'));await b.close()})();
