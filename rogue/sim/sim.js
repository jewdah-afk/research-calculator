// headless balance simulator: kiting bot, auto-picks first card, plays full runs
const {chromium}=require('playwright');
const diff=process.argv[2]||'easy', len=+(process.argv[3]||1800), runs=+(process.argv[4]||3);
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});const p=await b.newPage({viewport:{width:390,height:800}});
const errs=[];p.on('pageerror',e=>errs.push(e.message));
await p.goto('file://'+require('path').resolve(__dirname,'../../design/rogue-ui/peckwood-rogue-prototype.html')+'');await p.waitForTimeout(800);
const res=[];
for(let r=0;r<runs;r++){
 const out=await p.evaluate(([diff,len,r])=>{ SEED=1000+r*77; window.DT={}; RUN.diff=diff; RUN.len=len; RUN.char='birb'; chunks.clear(); startRun();
   const log=[]; let ang=0, lastM=-1; window.botDir=[1,0];
   for(let step=0;step<len*30+2700;step++){
     if(state==='levelup'){ const sc=o=>o.type==='w'?(P.weapons[o.k]?10:(Object.keys(P.weapons).length<3?6:2)):o.type==='t'?({might:8,cooldown:8,maxhp:7,armor:7,area:6,amount:7,regen:5}[o.k]||3)+(P.tomes[o.k]?2:0):0; const o=offered.slice().sort((a,b)=>sc(b)+b.r-sc(a)-a.r)[0]; takeOffer(o); continue; }
     if(state==='chest'){ document.getElementById('chestOk').click(); continue; }
     if(state==='clear'){ document.getElementById('cashout').click(); }
     if(state!=='play') break;
     // smarter bot: score 16 directions by threat, terrain and gems
     if(step%3===0){ let best=null,bs=-1e9; for(let i=0;i<16;i++){ const a=i/16*Math.PI*2, dx=Math.cos(a), dz=Math.sin(a); let sc=0, ok=true;
       for(const t of [.8,1.6,2.4]){ const x=P.x+dx*t, z=P.z+dz*t, [h,mm]=tile(x,z); if(mm===M.WALL||mm===M.LAVA||mm===M.WATER){ ok=false; break; } }
       if(!ok){ sc-=50; }
       const x=P.x+dx*1.6, z=P.z+dz*1.6; for(const e of enemies){ const d2=(e.x-x)**2+(e.z-z)**2; if(d2<36) sc-=(e.boss?12:3)/(d2+.3); }
       for(const q of eshots){ const d2=(q.x-x)**2+(q.z-z)**2; if(d2<6) sc-=4/(d2+.2); }
       for(const q of gems){ const d2=(q.x-x)**2+(q.z-z)**2; if(d2<64) sc+=(q.v)/(d2+4)*1.2; }
       for(const q of pickups){ const d2=(q.x-x)**2+(q.z-z)**2; if(d2<100) sc+=6/(d2+2); }
       sc-=Math.hypot(x,z)>60?.02*(Math.hypot(x,z)-60):0; // stay near home biome
       sc+=Math.cos(a-ang)*.25; if(sc>bs){bs=sc;best=a;} } ang=best; window.botDir=[Math.cos(best),Math.sin(best)]; }
     update(1/30);
     const m=Math.floor(SM()); if(m!==lastM&&m%5===0){ lastM=m; log.push(`m${m}:lv${P.lv} hp${Math.round(P.hp)} n${enemies.length} k${kills}`); }
   }
   window.botDir=null;
   return {time:Math.round(time), m:+SM().toFixed(1), lv:P.lv, kills, weapons:Object.entries(P.weapons).map(([k,w])=>k+w.lv+(w.evo?'E':'')).join(','), tomes:Object.entries(P.tomes).map(([k,t])=>k+t.l).join(','), boss:bossDead, state, dt:Object.entries(window.DT).sort((a,b)=>b[1]-a[1]).slice(0,4).map(([k,v])=>k+':'+Math.round(v)).join(' '), log:log.join(' | ')};
 },[diff,len,r]);
 res.push(out); console.log(JSON.stringify(out));
}
console.log('errs',errs.slice(0,5)); await b.close();})();
