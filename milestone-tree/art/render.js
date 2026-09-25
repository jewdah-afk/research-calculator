// usage: node render.js <layer> [scale]  -> out/<layer>.png (+ preview)
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');
(async()=>{const layer=process.argv[2];const b=await chromium.launch({args:['--js-flags=--max-old-space-size=4096']});
const p=await b.newPage();p.on('console',m=>console.log('[page]',m.text()));p.on('pageerror',e=>console.log('[err]',e.message));
await p.setContent('<html><body></body></html>');
await p.addScriptTag({content:fs.readFileSync(path.join(__dirname,'lib.js'),'utf8')});
await p.addScriptTag({content:fs.readFileSync(path.join(__dirname,'layers',layer+'.js'),'utf8')});
const t0=Date.now();
const url=await p.evaluate(async(l)=>{const c=await LAYERS[l]();return c.toDataURL('image/png')},layer);
fs.mkdirSync(path.join(__dirname,'out'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'out',layer+'.png'),Buffer.from(url.split(',')[1],'base64'));
const prev=await p.evaluate(async(l)=>{const src=window.__last;const c=document.createElement('canvas');c.width=1600;c.height=Math.round(1600*src.height/src.width);const x=c.getContext('2d');x.fillStyle='#07050d';x.fillRect(0,0,c.width,c.height);x.drawImage(src,0,0,c.width,c.height);return c.toDataURL('image/png')},layer);
fs.writeFileSync(path.join(__dirname,'out',layer+'_prev.png'),Buffer.from(prev.split(',')[1],'base64'));
console.log(layer,'rendered in',Date.now()-t0,'ms');await b.close()})();
