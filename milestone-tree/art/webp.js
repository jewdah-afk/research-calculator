const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage();
for(const n of ['sky','far','world','fg']){const d='data:image/png;base64,'+fs.readFileSync('out/'+n+'.png').toString('base64');
const [w,j]=await p.evaluate(async d=>{const im=await new Promise(r=>{const i=new Image();i.onload=()=>r(i);i.src=d});const c=document.createElement('canvas');c.width=im.width;c.height=im.height;c.getContext('2d').drawImage(im,0,0);return [c.toDataURL('image/webp',0.93),c.toDataURL('image/jpeg',0.93)]},d);
fs.writeFileSync('out/'+n+'.webp',Buffer.from(w.split(',')[1],'base64'));if(n==='sky')fs.writeFileSync('out/sky.jpg',Buffer.from(j.split(',')[1],'base64'));}
await b.close()})();
