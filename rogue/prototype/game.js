/* ================= MOVEMENT HELPERS ================= */
function groundH(x,z){ const [h,m]=tile(x,z); return surfH(h,m); }
function canStep(fx_,fz_,tx,tz){ const [h1,m1]=tile(tx,tz), [h0,m0]=tile(fx_,fz_); if(m1===M.WALL)return false; if(LIQUID.has(m0)||LIQUID.has(m1))return true; return Math.abs(h1-h0)<=STEP+1e-6; }
function move(o,dx,dz){ if(canStep(o.x,o.z,o.x+dx,o.z)) o.x+=dx; if(canStep(o.x,o.z,o.x,o.z+dz)) o.z+=dz; }
/* ================= SAVE / META ================= */
const SAVE_KEY='peckwood-rogue-v3';
let save={silver:0,meta:{},chars:{birb:1},best:{},clears:{},runs:0};
try{ const s=JSON.parse(localStorage.getItem(SAVE_KEY)||'null'); if(s) save=Object.assign(save,s); }catch(e){}
function persist(){ try{ localStorage.setItem(SAVE_KEY,JSON.stringify(save)); }catch(e){} }
const $=id=>document.getElementById(id);

/* ================= INPUT ================= */
const keys={}; addEventListener('keydown',e=>{ const k=e.key.toLowerCase(); keys[k]=1; if((k==='escape'||k==='p')&&state==='play') openPause(); });
addEventListener('keyup',e=>keys[e.key.toLowerCase()]=0);
let joy=null; cv.addEventListener('pointerdown',e=>{joy={x0:e.clientX,y0:e.clientY,x:e.clientX,y:e.clientY,id:e.pointerId}; try{cv.setPointerCapture(e.pointerId);}catch(_){}} );
cv.addEventListener('pointermove',e=>{ if(joy&&e.pointerId===joy.id){joy.x=e.clientX;joy.y=e.clientY;} });
const endJoy=e=>{ if(joy&&e.pointerId===joy.id)joy=null; }; cv.addEventListener('pointerup',endJoy); cv.addEventListener('pointercancel',endJoy);

/* ================= RUN STATE ================= */
let state='title', RUN={len:1800,diff:'easy',char:'birb'};
let P,S,enemies,eshots,shots,zones,gems,pickups,fx,booms,dnums,time,kills,gold,spawnAcc,evIdx,bossDone,bossDead,lastBiome,pendingLv,banishMode,banished,dmgBy,hitCount,bloodMoon,freeze,silverEarned,minisKilled,elitesKilled;
const SM=()=>time/RUN.len*30; // story minute
function baseStats(){ return {might:1,area:1,cooldown:1,amount:0,duration:1,proj:1,speed:4.3,maxhp:120,regen:0,armor:0,magnet:3.2,luck:0,growth:1,greed:1,crit:.05,critDmg:2,revival:0,rerolls:2,banishes:1,skips:1,curse:0}; }
function recompute(){ // rebuild S from base + meta + character + tomes + items
  const hpRatio=P? P.hp/(S?S.maxhp:100):1; const T=baseStats();
  for(const m of META){ const l=save.meta[m.id]||0; if(l) m.f(T,l); }
  CHARS[RUN.char].mod(T);
  for(const k in P.tomes){ const lv=P.tomes[k]; for(let i=1;i<=lv.l;i++) TOME[k].f(T,lv.k[i-1]||1,i); }
  const I=P.items; T.armor+=(I.iron_feather||0)*.10; T.greed+=(I.golden_kernel||0)*.3+(I.point_hoard||0)*.15+(I.skull||0)*.25; T.growth+=(I.point_hoard||0)*.15+(I.skull||0)*.25;
  T.luck+=(I.clover||0)*.15; T.amount+=(I.echo_wing?1:0); T.curse+=(I.skull||0)*.25; T.revival+=(I.phoenix?1:0);
  // keep current consumables
  T.maxhp+=P.bonusHp||0; T.magnet*=P.bonusMag||1;
  if(S){ T.rerolls=S.rerolls; T.banishes=S.banishes; T.skips=S.skips; T.revivalLeft=(S.revivalLeft||0)+Math.max(0,T.revival-S.revival); }
  S=T; if(P.hp>S.maxhp) P.hp=S.maxhp; }
function newRun(){
  time=0; kills=0; gold=0; spawnAcc=0; evIdx=0; bossDone=false; bossDead=false; lastBiome=-1; pendingLv=0; banishMode=false; banished=new Set(); dmgBy={}; hitCount=0; bloodMoon=0; freeze=0; minisKilled=0; elitesKilled=0;
  P={x:.5,z:.5,y:0,hp:100,lv:1,xp:0,need:5,face:1,fx:1,fz:0,hurt:0,inv:0,slide:[0,0],weapons:{},tomes:{},items:{},buffs:{fury:0,mom:0,haste:0},focus:0,itemDmg:{}};
  S=null; recompute(); S.rerolls=baseStats().rerolls+(save.meta.reroll||0); S.banishes=1+(save.meta.banish||0); S.skips=1+(save.meta.skip||0); S.revivalLeft=S.revival; P.hp=S.maxhp;
  addWeapon(CHARS[RUN.char].weapon);
  enemies=[]; eshots=[]; shots=[]; zones=[]; gems=[]; pickups=[]; fx=[]; booms=[]; dnums=[]; chunks.clear(); renderSlots(); }

/* ================= WEAPONS ================= */
function addWeapon(k){ P.weapons[k]={k,lv:1,cd:.3,bonus:0,evo:false,t:0,hitT:new Map()}; dmgBy[k]=dmgBy[k]||0; }
function wstat(w){ const W=WEAP[w.k], s={...W.base}; for(let i=0;i<w.lv-1;i++){ const d=W.lv[i]; for(const k in d){ if(k==='cd') s.cd*=1+d[k]; else s[k]=(s[k]||0)+d[k]; } }
  s.dmg*=S.might*(1+w.bonus)*(P.buffs.fury>0?1.25:1); s.cd*=S.cooldown*(P.buffs.haste>0?1-.25*(P.items.splitter_haste||1):1)*(P.buffs.fury>0?.8:1); if(s.n!==undefined) s.n+=S.amount; if(s.r) s.r*=S.area; if(s.dur) s.dur*=S.duration; if(s.spd) s.spd*=S.proj;
  if(w.evo){ s.dmg*=1.5; } return s; }
function nearestEnemy(x,z,r,skip){ let b=null,bd=r*r; for(const e of enemies){ if(skip&&skip.has(e))continue; const d=(e.x-x)**2+(e.z-z)**2; if(d<bd){bd=d;b=e;} } return b; }
function enemiesIn(x,z,r,fn){ const r2=r*r; const c0=Math.floor((x-r)/2), c1=Math.floor((x+r)/2), d0=Math.floor((z-r)/2), d1=Math.floor((z+r)/2);
  for(let a=c0;a<=c1;a++)for(let b=d0;b<=d1;b++){ const L=grid.get(a*73856093^b*19349663); if(!L)continue; for(const e of L){ if(e.dead)continue; if((e.x-x)**2+(e.z-z)**2<r2+(e.sz/90)**2) fn(e); } } }
function randomVisibleEnemy(){ const near=enemies.filter(e=>Math.abs(e.x-P.x)<12&&Math.abs(e.z-P.z)<12); return near[Math.random()*near.length|0]; }
function fireWeapons(dt){
  for(const k in P.weapons){ const w=P.weapons[k], s=wstat(w); w.t+=dt;
    // continuous weapons
    if(k==='parrot'||k==='nest'){ const n=k==='nest'&&w.evo?Math.max(6,s.n):s.n+(w.evo?2:0); const r=(k==='parrot'&&w.evo)?s.r*(1.4+.5*Math.sin(time*2)):(k==='nest'&&w.evo?2:s.r);
      w.orbit=[]; for(let i=0;i<n;i++){ const a=time*s.spin*(k==='nest'?-1:1)+i*Math.PI*2/n; const ox=P.x+Math.cos(a)*r, oz=P.z+Math.sin(a)*r; w.orbit.push([ox,oz]);
        enemiesIn(ox,oz,.55,e=>{ const last=w.hitT.get(e)||0; if(time-last<s.cd)return; w.hitT.set(e,time); hit(e,s.dmg,k,{kb:k==='nest'?1.6:.5,fx:ox,fz:oz}); });
        if(k==='nest'&&w.evo) for(const b of eshots){ if((b.x-ox)**2+(b.z-oz)**2<.5) b.life=0; } }
      if(w.hitT.size>400) w.hitT.clear(); continue; }
    w.cd-=dt; if(w.cd>0) continue;
    if(k==='volley'){ if(w.evo){ w.cd=.32; const n=6+S.amount; for(let i=0;i<n;i++){ const a=time*2.2+i*Math.PI*2/n; shots.push({k,x:P.x,z:P.z,vx:Math.cos(a)*s.spd,vz:Math.sin(a)*s.spd,life:1.1,dmg:s.dmg,pierce:99,sp:'feather_volley'}); } continue; }
      const t=nearestEnemy(P.x,P.z,10); if(!t){w.cd=.1;continue;} w.cd=s.cd; for(let i=0;i<s.n;i++){ const a=Math.atan2(t.z-P.z,t.x-P.x)+(i-(s.n-1)/2)*.18; shots.push({k,x:P.x,z:P.z,vx:Math.cos(a)*s.spd,vz:Math.sin(a)*s.spd,life:1,dmg:s.dmg,pierce:s.pierce,sp:'feather_volley'}); } }
    else if(k==='pop'){ w.cd=w.evo?s.cd*.6:s.cd; const r=w.evo?s.r*1.5:s.r; booms.push({x:P.x,z:P.z,r,life:.35,c:'#fff1a8'}); let heals=0;
      enemiesIn(P.x,P.z,r,e=>{ hit(e,s.dmg,k,{kb:.8}); if(w.evo&&heals<6){heals++; heal(.6);} }); hitProps(P.x,P.z,r); }
    else if(k==='gull'){ w.cd=w.evo?.55:s.cd; const n=w.evo?Math.max(2,Math.ceil(s.n/2)):s.n; for(let i=0;i<n;i++){ const e=randomVisibleEnemy(); const tx=e?e.x:P.x+(Math.random()-.5)*14, tz=e?e.z:P.z+(Math.random()-.5)*14; zones.push({k,type:'gull',x:tx,z:tz,t:.45,dmg:s.dmg,r:s.r}); } }
    else if(k==='seed'){ if(w.evo){ w.cd=.7; const n=4+S.amount*2; for(let i=0;i<n;i++){ const a=i*Math.PI*2/n+time; shots.push({k,x:P.x,z:P.z,vx:Math.cos(a)*s.spd,vz:Math.sin(a)*s.spd,life:1.4,dmg:s.dmg,bounce:8,hitset:new Set(),sp:'seed_spitter'}); } continue; }
      const t=nearestEnemy(P.x,P.z,9); if(!t){w.cd=.1;continue;} w.cd=s.cd; for(let i=0;i<s.n;i++){ const a=Math.atan2(t.z-P.z,t.x-P.x)+(i-(s.n-1)/2)*.3; shots.push({k,x:P.x,z:P.z,vx:Math.cos(a)*s.spd,vz:Math.sin(a)*s.spd,life:1.4,dmg:s.dmg,bounce:s.bounce,hitset:new Set(),sp:'seed_spitter'}); } }
    else if(k==='crowpick'){ w.cd=s.cd; const full=w.evo; const fa=Math.atan2(P.fz,P.fx); fx.push({type:'swing',x:P.x,z:P.z,a:fa,arc:full?Math.PI*2:s.arc,r:s.r,life:.22});
      enemiesIn(P.x,P.z,s.r,e=>{ let da=Math.atan2(e.z-P.z,e.x-P.x)-fa; da=Math.atan2(Math.sin(da),Math.cos(da)); if(!full&&Math.abs(da)>s.arc/2)return;
        if(full&&!e.boss&&e.hp<e.max*.15){ hit(e,e.hp+1,k,{}); return; } hit(e,s.dmg,k,{kb:2.2}); }); hitProps(P.x+P.fx,P.z+P.fz,s.r*.7); }
    else if(k==='chain'){ w.cd=s.cd; const strikes=w.evo?2:1; for(let q=0;q<strikes;q++){ let cur=randomVisibleEnemy(); if(!cur)break; const seen=new Set(), pts=[[P.x,P.z]]; let d=s.dmg;
        for(let i=0;i<s.chains+(w.evo?6:0)&&cur;i++){ seen.add(cur); pts.push([cur.x,cur.z]); hit(cur,d,k,{}); if(!w.evo) d*=.85; cur=nearestEnemy(cur.x,cur.z,4,seen); } fx.push({type:'bolt',pts,life:.18,c:'#b9e6ff'}); } }
    else if(k==='egg'){ w.cd=s.cd; for(let i=0;i<s.n;i++){ const e=randomVisibleEnemy(); const tx=e?e.x:P.x+(Math.random()-.5)*8, tz=e?e.z:P.z+(Math.random()-.5)*8; zones.push({k,type:'egg',x0:P.x,z0:P.z,x:tx,z:tz,t:.6/S.proj,T:.6/S.proj,dmg:s.dmg,r:s.r,pool:w.evo}); } }
    else if(k==='tornado'){ w.cd=s.cd; for(let i=0;i<s.n;i++){ const a=Math.random()*7; zones.push({k,type:'tornado',x:P.x+Math.cos(a)*2,z:P.z+Math.sin(a)*2,vx:Math.cos(a)*2.2,vz:Math.sin(a)*2.2,t:s.dur,dmg:s.dmg,r:s.r,tick:0,follow:w.evo}); } }
  } }
function updateZones(dt){
  for(const z of zones){ z.t-=dt;
    if(z.type==='gull'&&z.t<=0){ booms.push({x:z.x,z:z.z,r:z.r,life:.3,c:'#cfe8ff'}); enemiesIn(z.x,z.z,z.r,e=>hit(e,z.dmg,z.k,{kb:1})); hitProps(z.x,z.z,z.r); }
    if(z.type==='egg'&&z.t<=0){ booms.push({x:z.x,z:z.z,r:z.r,life:.35,c:'#ffd27a'}); enemiesIn(z.x,z.z,z.r,e=>hit(e,z.dmg,z.k,{kb:1.4})); hitProps(z.x,z.z,z.r);
      if(z.pool) zones.push({k:z.k,type:'pool',x:z.x,z:z.z,t:3*S.duration,dmg:z.dmg*.25,r:z.r,tick:0}); }
    if(z.type==='pool'){ z.tick-=dt; if(z.tick<=0){ z.tick=.4; enemiesIn(z.x,z.z,z.r,e=>hit(e,z.dmg,z.k,{})); } }
    if(z.type==='tornado'){ if(z.follow){ z.vx+=(P.x-z.x)*dt*.8+(Math.random()-.5)*4*dt; z.vz+=(P.z-z.z)*dt*.8+(Math.random()-.5)*4*dt; for(const g of gems){ if((g.x-z.x)**2+(g.z-z.z)**2<4){ g.pull=1; } } }
      else { z.vx+=(Math.random()-.5)*6*dt; z.vz+=(Math.random()-.5)*6*dt; } const L=Math.hypot(z.vx,z.vz)||1; z.x+=z.vx/L*2.6*dt; z.z+=z.vz/L*2.6*dt;
      z.tick-=dt; if(z.tick<=0){ z.tick=.25; enemiesIn(z.x,z.z,z.r,e=>hit(e,z.dmg,z.k,{kb:.3})); } } }
  zones=zones.filter(z=>z.t>0); }
function updateShots(dt){
  for(const s of shots){ s.life-=dt; s.x+=s.vx*dt; s.z+=s.vz*dt; if(s.life<=0)continue;
    enemiesIn(s.x,s.z,.35,e=>{ if(s.life<=0)return; if(s.hitset&&s.hitset.has(e))return; if(s.seen&&s.seen.has(e))return; hit(e,s.dmg,s.k,{kb:.6,fx:s.x-s.vx,fz:s.z-s.vz});
      if(s.bounce!==undefined){ s.hitset.add(e); if(s.bounce-->0){ const n=nearestEnemy(s.x,s.z,5,s.hitset); if(n){ const a=Math.atan2(n.z-s.z,n.x-s.x), sp=Math.hypot(s.vx,s.vz); s.vx=Math.cos(a)*sp; s.vz=Math.sin(a)*sp; s.life=Math.max(s.life,.7); } else s.life=0; } else s.life=0; }
      else { (s.seen||(s.seen=new Set())).add(e); if(--s.pierce<=0) s.life=0; } });
    if(hash(Math.floor(s.x*2),Math.floor(s.z*2),9)<.04) hitProps(s.x,s.z,.4); }
  shots=shots.filter(s=>s.life>0); }

/* ================= DAMAGE ================= */
function hit(e,d,src,o){ if(e.dead)return; let m=1;
  if(P.items.opening_strike&&e.hp>=e.max) m+=.8*P.items.opening_strike;
  if(P.items.redline&&P.hp<S.maxhp*.4) m+=.4*P.items.redline;
  if(P.items.focused_assault) m+=Math.min(1,P.focus/10)*.3*P.items.focused_assault;
  let crit=Math.random()<S.crit; d*=m*(crit?S.critDmg:1);
  e.hp-=d; e.hit=.08; dmgBy[src]=(dmgBy[src]||0)+d;
  if(o&&o.kb&&!e.boss){ const fxx=o.fx??P.x, fzz=o.fz??P.z; const a=Math.atan2(e.z-fzz,e.x-fxx); e.kx=Math.cos(a)*o.kb*3; e.kz=Math.sin(a)*o.kb*3; }
  if(P.items.blood_beak) heal(d*.015*P.items.blood_beak);
  if(P.items.molten) e.burn=Math.max(e.burn||0,2), e.burnD=4*P.items.molten;
  hitCount++;
  if(P.items.storm_locket&&hitCount%6===0){ let cur=e, seen=new Set([e]), pts=[[e.x,e.z]]; for(let i=0;i<2;i++){ const n=nearestEnemy(cur.x,cur.z,4,seen); if(!n)break; seen.add(n); pts.push([n.x,n.z]); n.hp-=d*.6*P.items.storm_locket; n.hit=.08; cur=n; } fx.push({type:'bolt',pts,life:.15,c:'#c9a6ff'}); }
  if(P.items.splitter_haste&&hitCount%5===0) P.buffs.haste=3;
  if(dnums.length<60) dnums.push({x:e.x,z:e.z,v:Math.round(d),crit,life:.6}); }
function heal(v){ P.hp=Math.min(S.maxhp,P.hp+v); }
function hurtPlayer(d,src){ if(P.inv>0||P.hurt>0)return; (window.DT||(window.DT={}))[src||'?']=(window.DT[src||'?']||0)+d; const red=S.armor/(.75+S.armor); P.hp-=d*(1-red)*DIFF[RUN.diff].dmg; P.hurt=.45; P.focus=0; if(P.hp<=0){ if(S.revivalLeft>0){ S.revivalLeft--; P.hp=S.maxhp*.5; P.inv=2.5; banner('REVIVED','Phoenix feathers catch you','#ffb23f'); burst(P.x,P.z,'#ffb23f',40); } else endRun(false); } }

/* ================= ENEMIES / DIRECTOR ================= */
let grid=new Map();
function rebuildGrid(){ grid=new Map(); for(const e of enemies){ const k=Math.floor(e.x/2)*73856093^Math.floor(e.z/2)*19349663; let L=grid.get(k); if(!L){L=[];grid.set(k,L);} L.push(e); } }
function scaleHP(m){ return (.75+m*.11+1.2*Math.pow(m/10,2.4))*DIFF[RUN.diff].hp; }
function spawnEnemy(type,x,z,opt={}){ const d=ENEMY[type]; if(!d)return; const m=SM(); if(x===undefined){ const a=opt.ang??Math.random()*Math.PI*2, r=opt.r??(17+Math.random()*5); x=P.x+Math.cos(a)*r; z=P.z+Math.sin(a)*r; }
  if(!d[7]&&tile(x,z)[1]===M.WALL) return;
  const cursed=opt.cursed||(bloodMoon>0&&Math.random()<.4)||(Math.random()<S.curse*.2), elite=opt.elite||d[6]==='elite';
  const hp=d[0]*scaleHP(m)*(elite&&d[6]!=='elite'?6:1)*(opt.boss?1:1)*(cursed?1.5:1);
  const e={type,x,z,hp,max:hp,spd:d[1]*(opt.fast||1),dmg:d[2]*(.65+m*.05),sz:d[3]*(elite&&d[6]!=='elite'?1.35:1),xp:d[4]*(elite?6:1)*(cursed?2:1)*(1+m*.045),beh:d[5],tier:d[6],fly:!!d[7],elite,cursed,boss:d[6]==='boss'||d[6]==='mini',mini:d[6]==='mini',hit:0,cd:1+Math.random()*2,kx:0,kz:0,st:0,line:opt.line};
  enemies.push(e); return e; }
function pickFrom(arr){ return arr[Math.random()*arr.length|0]; }
function director(dt){
  const m=SM(), b=lastBiome<0?0:lastBiome, R=BIOME_ROLE[b], D=DIFF[RUN.diff];
  const maxN=Math.min(320,30+m*9)*(1+S.curse);
  let rate=(.8+m*.33+m*m*.01)*D.spawn*(bloodMoon>0?2:1)*(1+S.curse)*(m>=25&&m<30?1.6:1);
  if(freeze>0) rate=0;
  spawnAcc+=rate*dt; const minN=Math.min(maxN,12+m*5);
  if(enemies.length<minN) spawnAcc+=1;
  while(spawnAcc>=1&&enemies.length<maxN){ spawnAcc--; const r=Math.random();
    // tier mix shifts with the minute: specials from 4, brutes from 8, all tiers late
    let tier='basic'; if(r<.25) tier='swarm'; else if(m>=4&&r<.25+Math.min(.25,m*.02)) tier='special'; else if(m>=8&&r>1-Math.min(.18,(m-8)*.012)) tier='brute';
    if(m>=25&&m<30&&Math.random()<.3) tier=pickFrom(['special','brute']);
    // bias spawns toward the direction the player is moving
    const fwd=Math.atan2(P.fz,P.fx), ang=Math.random()<.45&&P.moving?fwd+(Math.random()-.5)*1.6:Math.random()*Math.PI*2;
    spawnEnemy(pickFrom(R[tier]),undefined,undefined,{ang}); }
  // scripted events
  while(evIdx<TIMELINE.length&&m>=TIMELINE[evIdx].m){ runEvent(TIMELINE[evIdx].t,R); evIdx++; }
  if(m>30&&Math.random()<dt*.05*(1+(m-30)*.1)) spawnEnemy(R.elite,undefined,undefined,{elite:true}); // endless pressure
}
function runEvent(t,R){
  const m=SM();
  if(t==='swarm'){ const a=Math.random()*Math.PI*2, dx=Math.cos(a), dz=Math.sin(a), px=-dz, pz=dx; for(let i=0;i<26;i++){ const o=(i-13)*.9; const e=spawnEnemy(pickFrom(R.swarm),P.x-dx*18+px*o,P.z-dz*18+pz*o,{fast:1.6,line:[dx,dz]}); } toast('A swarm sweeps in!','#9fd8ff'); }
  else if(t==='ring'){ const n=26+Math.round(m); for(let i=0;i<n;i++){ const a=i/n*Math.PI*2; spawnEnemy(pickFrom(R.basic),P.x+Math.cos(a)*10,P.z+Math.sin(a)*10); } toast('Surrounded!','#ff8a7a'); }
  else if(t==='rush'){ const a=Math.random()*Math.PI*2; for(let i=0;i<34;i++){ const aa=a+(Math.random()-.5)*.5, r=17+Math.random()*4; spawnEnemy(pickFrom([...R.basic,...R.special]),P.x+Math.cos(aa)*r,P.z+Math.sin(aa)*r,{fast:1.15}); } toast('A horde rushes in','#ffc93c'); }
  else if(t==='elite'){ spawnEnemy(R.elite,undefined,undefined,{elite:true}); toast('Elite incoming · drops a treasure chest','#ffc93c'); }
  else if(t==='mini'){ spawnEnemy(R.mini,undefined,undefined,{}); banner('MINIBOSS',ENEMY[R.mini]?R.mini.replace(/_/g,' ').toUpperCase():'','#ff8a3c'); }
  else if(t==='bloodmoon'){ bloodMoon=60/30*RUN.len/60; banner('BLOOD MOON','Double spawns · cursed enemies · double XP','#ff3d5a'); }
  else if(t==='everything'){ banner('EVERYTHING SPAWNS','Survive to minute 30','#ff3d7f'); }
  else if(t==='boss'){ if(!bossDone){ bossDone=true; for(const e of enemies) if(!e.boss){ e.dead=true; } enemies=enemies.filter(e=>!e.dead); spawnEnemy(R.boss,undefined,undefined,{r:10}); banner('FINAL BOSS',R.boss.replace(/_/g,' ').toUpperCase(),'#ff3d7f'); } } }
function updateEnemies(dt){
  rebuildGrid();
  for(const e of enemies){ e.hit-=dt; if(e.burn>0){ e.burn-=dt; e.hp-=e.burnD*dt; }
    if(freeze>0&&!e.boss){ continue; }
    const dx=P.x-e.x, dz=P.z-e.z, d=Math.hypot(dx,dz)||1; let vx=dx/d, vz=dz/d, sp=e.spd*(e.cursed?1.25:1);
    if(e.line){ vx=e.line[0]; vz=e.line[1]; if(d>34) e.dead=true; }
    else if(e.beh==='ranged'){ if(d<5.5){ vx=-vx*.6; vz=-vz*.6; } else if(d<8){ vx*=.15; vz*=.15; } e.cd-=dt; if(e.cd<=0&&d<11){ e.cd=3.4; const a=Math.atan2(dz,dx); eshots.push({x:e.x,z:e.z,vx:Math.cos(a)*4.2,vz:Math.sin(a)*4.2,life:3,dmg:e.dmg*.4,c:e.cursed?'#b44cff':'#ff6a3c'}); } }
    else if(e.beh==='charge'){ if(e.st>0){ e.st-=dt; if(e.st<=.0) { e.dash=.45; e.dx=vx; e.dz=vz; } vx=0; vz=0; } else if(e.dash>0){ e.dash-=dt; vx=e.dx*2.8; vz=e.dz*2.8; } else { e.cd-=dt; if(e.cd<=0&&d<7){ e.cd=3.5; e.st=.6; } } }
    else if(e.beh==='boss'){ e.cd-=dt; if(e.cd<=0){ e.cd=e.mini?3.2:2.4; const pat=Math.random();
        if(pat<.4){ const n=e.mini?12:20; for(let i=0;i<n;i++){ const a=i/n*Math.PI*2+time; eshots.push({x:e.x,z:e.z,vx:Math.cos(a)*4.2,vz:Math.sin(a)*4.2,life:4,dmg:e.dmg*.6,c:'#ff3d7f',big:1}); } }
        else if(pat<.7){ const R=BIOME_ROLE[lastBiome<0?0:lastBiome]; for(let i=0;i<(e.mini?5:9);i++) spawnEnemy(pickFrom(R.basic),e.x+(Math.random()-.5)*3,e.z+(Math.random()-.5)*3); }
        else { e.st=.7; e.dash=0; } }
      if(e.st>0){ e.st-=dt; vx=0; vz=0; if(e.st<=0){ e.dash=.6; e.dx=dx/d; e.dz=dz/d; } } else if(e.dash>0){ e.dash-=dt; vx=e.dx*3.4; vz=e.dz*3.4; } }
    // separation from neighbours (soft)
    let sx=0, sz=0, c=0; const k=Math.floor(e.x/2)*73856093^Math.floor(e.z/2)*19349663, L=grid.get(k); if(L) for(const o of L){ if(o===e||c>6)continue; const ox=e.x-o.x, oz=e.z-o.z, dd=ox*ox+oz*oz, rr=(e.sz+o.sz)/110; if(dd<rr*rr&&dd>1e-4){ const q=Math.sqrt(dd); sx+=ox/q*(rr-q); sz+=oz/q*(rr-q); c++; } }
    const [,me]=tile(e.x,e.z), wmul=(!e.fly&&LIQUID.has(me))?.5:1;
    const mx=(vx*sp*wmul+e.kx+sx*3)*dt, mz=(vz*sp*wmul+e.kz+sz*3)*dt; e.kx*=Math.pow(.02,dt); e.kz*=Math.pow(.02,dt);
    if(e.fly){ e.x+=mx; e.z+=mz; } else move(e,mx,mz);
    if(d<.5+e.sz/120) hurtPlayer(e.dmg*(e.cursed?1.3:1),e.type);
    if(!e.line&&!e.boss&&d>30){ const a=Math.atan2(P.fz,P.fx)+(Math.random()-.5)*1.4; e.x=P.x+Math.cos(a)*18; e.z=P.z+Math.sin(a)*18; } }
  for(const e of enemies) if(e.hp<=0&&!e.dead) kill(e);
  enemies=enemies.filter(e=>!e.dead);
  for(const b of eshots){ b.life-=dt; if(freeze>0)continue; b.x+=b.vx*dt; b.z+=b.vz*dt; if((b.x-P.x)**2+(b.z-P.z)**2<.3){ hurtPlayer(b.dmg,'shot'); b.life=0; } } eshots=eshots.filter(b=>b.life>0); }
function kill(e){ e.dead=true; kills++; const xp=e.xp*(bloodMoon>0?2:1);
  gems.push({x:e.x,z:e.z,v:xp}); if(Math.random()<.07*(1+S.luck)||e.elite) pickups.push({x:e.x+.3,z:e.z,t:'gold',v:Math.round((e.elite?15:2+Math.random()*3))});
  const r=Math.random(); if(r<.004) pickups.push({x:e.x,z:e.z,t:'chicken'}); else if(r<.006) pickups.push({x:e.x,z:e.z,t:'magnet'}); else if(r<.0075) pickups.push({x:e.x,z:e.z,t:'bomb'}); else if(r<.009) pickups.push({x:e.x,z:e.z,t:'clock'});
  if(P.items.hunter_momentum) P.buffs.mom=3;
  if(e.elite&&!e.boss){ elitesKilled++; pickups.push({x:e.x,z:e.z,t:'tchest'}); toast('Elite down · treasure chest!','#ffc93c'); }
  if(e.mini){ minisKilled++; pickups.push({x:e.x,z:e.z,t:'tchest',big:1}); banner('MINIBOSS DOWN','It dropped a big treasure chest','#ffb23f'); }
  if(e.boss&&!e.mini){ bossDead=true; pickups.push({x:e.x,z:e.z,t:'tchest',big:1}); setTimeout(()=>{ if(state==='play') stageClear(); },1200); }
  if(gems.length>420){ let v=0; const keep=gems.slice(-300); for(const g of gems.slice(0,-300)) v+=g.v; gems=keep; gems.push({x:P.x+4,z:P.z+4,v,big:1}); }
  burst(e.x,e.z,e.cursed?'#b44cff':'#fff1a8',e.boss?40:5); }

/* ================= PICKUPS / WORLD INTERACTION ================= */
function hitProps(x,z,r){ const ci=Math.floor(x/CH), cj=Math.floor(z/CH); for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){ const c=chunks.get((ci+a)+','+(cj+b)); if(!c)continue;
  for(const p of c.props){ if(p.kind!=='lantern'||p.broken)continue; if((p.x-x)**2+(p.z-z)**2<r*r+.3){ p.broken=true; burst(p.x,p.z,'#ffc95a',10); const q=Math.random();
    pickups.push({x:p.x,z:p.z,t:q<.3?'chicken':q<.65?'gold':q<.8?'magnet':q<.9?'bomb':'clock',v:5+(Math.random()*8|0)}); } } } }
function collect(dt){
  const mag=S.magnet;
  for(const g of gems){ const dx=P.x-g.x, dz=P.z-g.z, d=Math.hypot(dx,dz); if(d<mag||g.pull){ g.pull=1; const sp=Math.max(10,d*4); g.x+=dx/d*sp*dt; g.z+=dz/d*sp*dt; } if(d<.45){ g.dead=1; gainXp(g.v); } }
  gems=gems.filter(g=>!g.dead);
  for(const p of pickups){ const dx=P.x-p.x, dz=P.z-p.z, d=Math.hypot(dx,dz); if(d<mag*.6&&p.t!=='tchest'){ p.x+=dx/d*8*dt; p.z+=dz/d*8*dt; }
    if(d<.6){ p.dead=1;
      if(p.t==='gold'){ gold+=Math.round(p.v*S.greed); }
      else if(p.t==='chicken'){ heal(30); toast('+30 HP','#5be37d'); }
      else if(p.t==='magnet'){ for(const g of gems) g.pull=1; toast('Magnet!','#4aa3ff'); }
      else if(p.t==='bomb'){ for(const e of enemies) if(!e.boss&&Math.abs(e.x-P.x)<13&&Math.abs(e.z-P.z)<13) hit(e,e.hp+1,'bomb',{}); booms.push({x:P.x,z:P.z,r:9,life:.6,c:'#ffffff'}); toast('Kaboom!','#fff'); }
      else if(p.t==='clock'){ freeze=6; toast('Time freeze · 6s','#9fd8ff'); }
      else if(p.t==='tchest'){ openTreasure(p.big); } } }
  pickups=pickups.filter(p=>!p.dead);
  // world chests + shrines
  const c=chunkAt(Math.floor(P.x/CH),Math.floor(P.z/CH));
  for(const p of c.props){ const d2=(p.x-P.x)**2+(p.z-P.z)**2;
    if(p.kind==='chest'&&!p.open&&d2<1.3){ const price=chestPrice(); if(gold>=price){ gold-=price; p.open=true; save.chestsOpened=(save.chestsOpened||0)+1; openItemChest(p); } else if(!p.warned){ p.warned=1; toast(`Chest · needs ${price} gold`,'#ffc93c'); setTimeout(()=>p.warned=0,2000); } }
    if(p.kind==='shrine'&&!p.used){ if(d2<4){ p.charge+=dt/2.5; if(p.charge>=1){ p.used=true; useShrine(p); } } else p.charge=Math.max(0,p.charge-dt*.5); } } }
let chestsBought=0; const chestPrice=()=>Math.round((20+chestsBought*18)*(1+SM()*.04));
function useShrine(p){ burst(p.x,p.z,'#ffc93c',30);
  if(p.sk==='fury'){ P.buffs.fury=30; banner('SHRINE OF FURY','+25% damage, faster weapons for 30s','#ff6a3c'); }
  else if(p.sk==='magnet'){ for(const g of gems) g.pull=1; P.bonusMag=(P.bonusMag||1)*1.15; recompute(); banner('SHRINE OF PULL','All gems fly to you · +15% magnet','#4aa3ff'); }
  else if(p.sk==='heal'){ P.bonusHp=(P.bonusHp||0)+15; recompute(); P.hp=S.maxhp; banner('SHRINE OF LIFE','Full heal · +15 max HP','#5be37d'); }
  else { const R=BIOME_ROLE[lastBiome<0?0:lastBiome]; for(let i=0;i<3;i++) spawnEnemy(R.elite,P.x+Math.cos(i*2)*7,P.z+Math.sin(i*2)*7,{elite:true}); banner('SHRINE OF TRIALS','Three elites appear · three chests','#b44cff'); } }

/* ================= LEVEL UP ================= */
function gainXp(v){ P.xp+=v*S.growth; while(P.xp>=P.need){ P.xp-=P.need; P.lv++; P.need=Math.round(4+P.lv*2.8+Math.pow(P.lv,1.5)); pendingLv++; } if(pendingLv>0&&state==='play') showLevelUp(); }
function rollRarity(){ const r=Math.random(), luck=S.luck; let acc=0; for(let i=RAR.length-1;i>0;i--){ acc+=RAR[i][2]*(1+luck*3); if(r<acc) return i; } return 0; }
function offerPool(){ const pool=[], nW=Object.keys(P.weapons).length, nT=Object.keys(P.tomes).length;
  for(const k in WEAP){ if(banished.has(k))continue; const w=P.weapons[k]; if(w){ if(w.lv<8) pool.push({type:'w',k,wgt:3}); } else if(nW<4) pool.push({type:'w',k,wgt:1.4}); }
  for(const k in TOME){ if(banished.has(k))continue; const t=P.tomes[k]; if(t){ if(t.l<5) pool.push({type:'t',k,wgt:2.4}); } else if(nT<4) pool.push({type:'t',k,wgt:1}); }
  return pool; }
let offered=[];
function showLevelUp(){ state='levelup'; const pool=offerPool(); offered=[]; const n=3+(S.luck>=.5?1:0);
  while(offered.length<n&&pool.length){ const tot=pool.reduce((a,p)=>a+p.wgt,0); let v=Math.random()*tot, i=0; for(;i<pool.length;i++){ if(v<pool[i].wgt)break; v-=pool[i].wgt; } const o=pool.splice(Math.min(i,pool.length-1),1)[0]; o.r=rollRarity(); offered.push(o); }
  if(!offered.length) offered.push({type:'g',r:0});
  const box=$('cards'); box.innerHTML='';
  offered.forEach(o=>{ const R=RAR[o.r], b=document.createElement('button'); b.className='up'; b.style.setProperty('--r',R[1]);
    let name,ic,desc,lv,kind;
    if(o.type==='w'){ const W=WEAP[o.k], w=P.weapons[o.k]; name=W.name; ic=W.icon; kind='WEAPON'; lv=w?`LV ${w.lv} → ${w.lv+1}`:'NEW'; const nx=w?W.lv[w.lv-1]:null;
      desc=w?Object.entries(nx).map(([k,v])=>({dmg:'Damage',cd:'Cooldown',n:'Amount',pierce:'Pierce',r:'Area',bounce:'Bounces',spin:'Speed',arc:'Arc',chains:'Chains',dur:'Duration'}[k]+' '+(k==='cd'?Math.round(v*100)+'%':'+'+v))).join(' · ')+(o.r?` · +${[0,10,20,35,60,100][o.r]}% dmg`:''):W.desc; }
    else if(o.type==='t'){ const T=TOME[o.k], t=P.tomes[o.k]; name=T.name; ic=T.icon; kind='TOME'; lv=t?`LV ${t.l} → ${t.l+1}`:'NEW'; desc=T.desc+(o.r?` ×${R[3]}`:''); }
    else { name='Gold Pouch'; ic='golden'; kind='EXTRA'; lv=''; desc='+25 gold and heal 20'; }
    b.innerHTML=`<header>${R[0]}</header><small>${kind}</small><img src="${ICON[ic]}" alt=""><b>${name}</b><i>${lv}</i><span>${desc}</span>`;
    b.onclick=()=>{ if(banishMode&&o.type!=='g'){ banished.add(o.k); S.banishes--; banishMode=false; toast(name+' banished','#ff8a7a'); showLevelUp(); return; } takeOffer(o); }; box.appendChild(b); });
  $('reroll').textContent=`Reroll · ${S.rerolls}`; $('reroll').disabled=S.rerolls<=0; $('banish').textContent=banishMode?'Tap a card to banish':`Banish · ${S.banishes}`; $('banish').disabled=S.banishes<=0; $('skip').textContent=`Skip · ${S.skips}`; $('skip').disabled=S.skips<=0;
  $('lvov').hidden=false; }
function takeOffer(o){ const R=RAR[o.r];
  if(o.type==='w'){ const w=P.weapons[o.k]; if(w){ w.lv=Math.min(8,w.lv+1); } else addWeapon(o.k); P.weapons[o.k].bonus+=[0,.1,.2,.35,.6,1][o.r]; }
  else if(o.type==='t'){ const t=P.tomes[o.k]||(P.tomes[o.k]={l:0,k:[]}); t.l=Math.min(5,t.l+1); t.k.push(R[3]); recompute(); if(o.k==='maxhp') heal(20*R[3]); }
  else { gold+=25; heal(20); }
  burst(P.x,P.z,R[1],18); if(o.r>=3) banner(R[0]+'!',o.type==='w'?WEAP[o.k].name:o.type==='t'?TOME[o.k].name:'',R[1]);
  nextLv(); }
function nextLv(){ $('lvov').hidden=true; renderSlots(); pendingLv--; if(pendingLv>0) showLevelUp(); else state='play'; }
$('reroll').onclick=()=>{ if(S.rerolls>0){ S.rerolls--; banishMode=false; showLevelUp(); } };
$('banish').onclick=()=>{ if(S.banishes>0){ banishMode=!banishMode; $('banish').textContent=banishMode?'Tap a card to banish':`Banish · ${S.banishes}`; } };
$('skip').onclick=()=>{ if(S.skips>0){ S.skips--; gold+=10; heal(10); nextLv(); } };

/* ================= CHESTS ================= */
function evoReady(){ return Object.values(P.weapons).filter(w=>!w.evo&&w.lv>=8&&P.tomes[WEAP[w.k].evo.tome]); }
function openTreasure(big){ state='chest'; const n=big?5:(Math.random()<.08*(1+S.luck)?5:Math.random()<.3*(1+S.luck)?3:1); const out=[];
  for(let i=0;i<n;i++){ const ev=evoReady(); if(ev.length){ const w=ev[0]; w.evo=true; out.push({ic:WEAP[w.k].icon,name:WEAP[w.k].evo.name,desc:WEAP[w.k].evo.desc,c:'#ff3d7f',tag:'EVOLUTION'}); continue; }
    const up=[...Object.values(P.weapons).filter(w=>w.lv<8).map(w=>({w})),...Object.entries(P.tomes).filter(([k,t])=>t.l<5).map(([k,t])=>({t:k}))];
    if(up.length){ const u=pickFrom(up); if(u.w){ u.w.lv++; out.push({ic:WEAP[u.w.k].icon,name:WEAP[u.w.k].name,desc:'LV '+u.w.lv,c:'#4aa3ff',tag:'LEVEL UP'}); } else { const t=P.tomes[u.t]; t.l++; t.k.push(1); out.push({ic:TOME[u.t].icon,name:TOME[u.t].name,desc:'LV '+t.l,c:'#5be37d',tag:'LEVEL UP'}); } }
    else { const g=Math.round(40*S.greed); gold+=g; out.push({ic:'golden',name:g+' gold',desc:'Everything is maxed',c:'#ffc93c',tag:'GOLD'}); } }
  recompute(); renderSlots(); showReveal(n===5?'#ffb23f':n===3?'#b44cff':'#4aa3ff',n===5?'JACKPOT CHEST':n===3?'TRIPLE CHEST':'TREASURE CHEST',out); }
function openItemChest(p){ state='chest'; chestsBought++; const r=rollRarity(), keys=Object.keys(ITEM).filter(k=>!((k==='echo_wing'||k==='phoenix')&&P.items[k])); const k=pickFrom(keys), R=RAR[r];
  P.items[k]=(P.items[k]||0)+R[3]; recompute(); renderSlots(); burst(p.x,p.z,R[1],30);
  showReveal(R[1],R[0]+' ITEM',[{ic:ITEM[k].icon,name:ITEM[k].name,desc:ITEM[k].desc(R[3]),c:R[1],tag:R[0]}],r); }
function showReveal(col,title,list,r=2){ const ov=$('chestov'); ov.style.setProperty('--r',col); $('chestTitle').textContent=title; ov.dataset.tier=r;
  const box=$('chestList'); box.innerHTML=''; list.forEach((o,i)=>{ const d=document.createElement('div'); d.className='rw'; d.style.setProperty('--c',o.c); d.style.animationDelay=(.25+i*.18)+'s'; d.innerHTML=`<img src="${ICON[o.ic]}" alt=""><div><small>${o.tag}</small><b>${o.name}</b><span>${o.desc}</span></div>`; box.appendChild(d); });
  ov.hidden=false; ov.classList.remove('go'); void ov.offsetWidth; ov.classList.add('go'); }
$('chestOk').onclick=()=>{ $('chestov').hidden=true; state='play'; if(pendingLv>0) showLevelUp(); };

/* ================= UPDATE ================= */
function update(dt){
  time+=dt; if(freeze>0) freeze-=dt; if(bloodMoon>0) bloodMoon-=dt;
  // movement
  let ix=0, iy=0; if(keys['w']||keys['arrowup'])iy-=1; if(keys['s']||keys['arrowdown'])iy+=1; if(keys['a']||keys['arrowleft'])ix-=1; if(keys['d']||keys['arrowright'])ix+=1;
  if(joy){ const dx=joy.x-joy.x0, dy=joy.y-joy.y0, L=Math.hypot(dx,dy); if(L>8){ix=dx/Math.max(L,40);iy=dy/Math.max(L,40);} }
  const L=Math.hypot(ix,iy); P.moving=L>.05; const [,mHere,bHere]=tile(P.x,P.z); let vx=0, vz=0;
  if(window.botDir){ P.moving=true; vx=botDir[0]; vz=botDir[1]; P.fx=vx; P.fz=vz; }
  else if(P.moving){ if(L>1){ix/=L;iy/=L;} const wx=(ix/HW+iy/HH)/2, wz=(iy/HH-ix/HW)/2, n=Math.hypot(wx,wz)||1; vx=wx/n; vz=wz/n; P.fx=vx; P.fz=vz; if(Math.abs(ix)>.1)P.face=ix>0?1:-1; }
  let sp=S.speed*(window.botDir?1:Math.min(1,L||0))*(P.buffs.mom>0?1+.15*(P.items.hunter_momentum||0):1)*(P.buffs.fury>0?1.15:1);
  if(mHere===M.WATER) sp*=.42; if(mHere===M.LAVA) sp*=.5; if(mHere===M.SNOW) sp*=.8;
  if(mHere===M.ICE){ P.slide[0]+=(vx*sp*1.25-P.slide[0])*dt*1.6; P.slide[1]+=(vz*sp*1.25-P.slide[1])*dt*1.6; move(P,P.slide[0]*dt,P.slide[1]*dt); } else { P.slide=[vx*sp,vz*sp]; move(P,vx*sp*dt,vz*sp*dt); }
  if(mHere===M.LAVA) hurtPlayer(6,'lava');
  P.y+=(groundH(P.x,P.z)-P.y)*Math.min(1,dt*12);
  if(bHere!==lastBiome){ lastBiome=bHere; banner(BIOMES[bHere].name.toUpperCase(),'New biome · new enemies','#fff'); }
  const zn={[M.WATER]:'Paddling',[M.LAVA]:'Lava!',[M.ICE]:'Sliding',[M.CRYPT]:'Crypt',[M.GOLDB]:'Golden steps',[M.WOOD]:'Indoors',[M.SNOW]:'Deep snow'}[mHere];
  const zt=BIOMES[bHere].name+(zn?' · '+zn:'')+(bloodMoon>0?' · Blood Moon':isNight()?' · Night':''); if($('zone').textContent!==zt) $('zone').textContent=zt;
  // timers
  for(const k in P.buffs) P.buffs[k]-=dt; P.hurt-=dt; P.inv-=dt; P.focus+=dt; if(S.regen) heal(S.regen*dt);
  director(dt); fireWeapons(dt); updateShots(dt); updateZones(dt); updateEnemies(dt); collect(dt);
  for(const f of fx){ f.life-=dt; if(f.vx){ f.x+=f.vx*dt; f.z+=f.vz*dt; } } fx=fx.filter(f=>f.life>0); for(const b of booms) b.life-=dt; booms=booms.filter(b=>b.life>0); for(const d of dnums) d.life-=dt; dnums=dnums.filter(d=>d.life>0);
  if(chunks.size>260){ const ci=Math.floor(P.x/CH), cj=Math.floor(P.z/CH); for(const [k,v] of chunks){ if(Math.abs(v.ci-ci)>7||Math.abs(v.cj-cj)>7) chunks.delete(k); } }
}
function isNight(){ return (SM()%6)>4.4; }
function burst(x,z,c,n){ for(let i=0;i<n;i++) fx.push({type:'p',x,z,vx:(Math.random()-.5)*7,vz:(Math.random()-.5)*7,life:.6,c}); }
function banner(t,sub,c){ const el=$('banner'); el.innerHTML=t+(sub?`<small>${sub}</small>`:''); el.style.color=c||'#fff'; el.classList.add('on'); clearTimeout(banner.t); banner.t=setTimeout(()=>el.classList.remove('on'),2200); }
function toast(t,c){ const el=$('toast'); el.textContent=t; el.style.color=c||'#fff'; el.classList.add('on'); clearTimeout(toast.t); toast.t=setTimeout(()=>el.classList.remove('on'),1500); }

/* ================= RENDER ================= */
const parts=[]; for(let i=0;i<60;i++) parts.push({x:Math.random(),y:Math.random(),s:Math.random()});
function W2S(x,z,ox,oy){ return [ox+(x-z)*HW, oy+(x+z)*HH-groundH(x,z)*PH/STEP]; }
function render(){
  const bHere=tile(P.x,P.z)[2], B=BIOMES[bHere];
  const g=cx.createLinearGradient(0,0,0,H); g.addColorStop(0,B.sky[0]); g.addColorStop(1,B.sky[1]); cx.fillStyle=g; cx.fillRect(0,0,W,H);
  const ox=W/2-(P.x-P.z)*HW, oy=H/2-(P.x+P.z)*HH+P.y*PH/STEP;
  const ci=Math.floor(P.x/CH), cj=Math.floor(P.z/CH), R=Math.ceil(Math.max(W,H*2)/(CH*HW*2))+1, now=performance.now(), vis=[];
  for(let s=-2*R;s<=2*R;s++) for(let a=-R;a<=R;a++){ const b=s-a; if(Math.abs(b)>R)continue; const CI=ci+a, CJ=cj+b;
    const sx=ox+(CI*CH-CJ*CH)*HW, sy=oy+(CI*CH+CJ*CH)*HH; if(sx+CH*HW+20<0||sx-CH*HW-20>W||sy+CH*2*HH+120<0||sy-120>H)continue; const c=chunkAt(CI,CJ);
    if(c.res!==DPR) c.img=null; if(!c.img){ buildChunkImage(c); c.res=DPR; } const age=Math.min(1,(now-c.born)/550), e=1-Math.pow(1-age,3);
    if(e<1) cx.globalAlpha=e; cx.drawImage(c.img,Math.round((sx-c.ox)*DPR)/DPR,Math.round((sy-c.oy+(1-e)*60)*DPR)/DPR,c.iw,c.ih); if(e<1) cx.globalAlpha=1; vis.push(c); }
  // ground effects (under objects)
  for(const z of zones){ if(z.type==='pool'){ const [sx,sy]=W2S(z.x,z.z,ox,oy); cx.fillStyle='rgba(255,140,40,.35)'; cx.beginPath(); cx.ellipse(sx,sy,z.r*HW*1.4,z.r*HH*1.4,0,0,7); cx.fill(); }
    if(z.type==='gull'){ const [sx,sy]=W2S(z.x,z.z,ox,oy), k=z.t/.45; cx.strokeStyle='rgba(255,255,255,.75)'; cx.lineWidth=2; cx.beginPath(); cx.ellipse(sx,sy,z.r*HW*1.4*(1.2-k*.6),z.r*HH*1.4*(1.2-k*.6),0,0,7); cx.stroke(); } }
  const objs=[];
  for(const c of vis) for(const p of c.props){ const sx=ox+(p.x-p.z)*HW, sy=oy+(p.x+p.z)*HH-p.gh*PH/STEP; if(sx<-40||sx>W+40||sy<-20||sy>H+110)continue; objs.push({d:p.x+p.z,f:()=>drawPropFast(p,sx,sy,time)}); }
  objs.push({d:P.x+P.z,f:()=>drawPlayer(ox,oy)});
  for(const e of enemies){ const [sx,sy]=W2S(e.x,e.z,ox,oy); if(sx<-80||sx>W+80||sy<-120||sy>H+80)continue; objs.push({d:e.x+e.z,f:()=>drawEnemy(e,sx,sy)}); }
  for(const gm of gems){ const [sx,sy]=W2S(gm.x,gm.z,ox,oy); if(sx<-10||sx>W+10||sy<-10||sy>H+10)continue; objs.push({d:gm.x+gm.z,f:()=>{ const y=sy-6+Math.sin(time*5+gm.x)*1.5, s=gm.big?2:gm.v>=10?1.4:1;
    cx.fillStyle=gm.big?'#ff3d5a':gm.v>=10?'#5be37d':gm.v>=3?'#4aa3ff':'#5be3ff'; cx.strokeStyle='#14121c'; cx.lineWidth=1.1; cx.beginPath(); cx.moveTo(sx,y-5*s); cx.lineTo(sx+3.5*s,y); cx.lineTo(sx,y+4*s); cx.lineTo(sx-3.5*s,y); cx.closePath(); cx.fill(); cx.stroke(); }}); }
  for(const p of pickups){ const [sx,sy]=W2S(p.x,p.z,ox,oy); objs.push({d:p.x+p.z,f:()=>drawPickup(p,sx,sy)}); }
  for(const s of shots){ const [sx,sy]=W2S(s.x,s.z,ox,oy); objs.push({d:s.x+s.z,f:()=>{ cx.save(); cx.translate(sx,sy-13); cx.rotate(Math.atan2((s.vx+s.vz)*HH,(s.vx-s.vz)*HW)+Math.PI/4); cx.drawImage(img[s.sp],-10,-10,20,20); cx.restore(); }}); }
  for(const b of eshots){ const [sx,sy]=W2S(b.x,b.z,ox,oy); objs.push({d:b.x+b.z,f:()=>{ cx.fillStyle=b.c; cx.strokeStyle='#14121c'; cx.lineWidth=1.5; cx.beginPath(); cx.arc(sx,sy-10,b.big?6:4.5,0,7); cx.fill(); cx.stroke(); cx.fillStyle='#fff'; cx.beginPath(); cx.arc(sx-1.5,sy-11.5,1.5,0,7); cx.fill(); }}); }
  for(const z of zones){ if(z.type==='egg'){ const k=1-z.t/z.T, x=z.x0+(z.x-z.x0)*k, zz=z.z0+(z.z-z.z0)*k, [sx,sy]=W2S(x,zz,ox,oy), arc=Math.sin(k*Math.PI)*60; objs.push({d:x+zz,f:()=>{ cx.fillStyle='#fff6e0'; cx.strokeStyle='#14121c'; cx.lineWidth=1.5; cx.beginPath(); cx.ellipse(sx,sy-10-arc,5,6.5,0,0,7); cx.fill(); cx.stroke(); }}); }
    if(z.type==='gull'){ const [sx,sy]=W2S(z.x,z.z,ox,oy), k=z.t/.45; objs.push({d:z.x+z.z+.01,f:()=>cx.drawImage(img.gull_dive,sx-16,sy-30-k*130,32,32)}); }
    if(z.type==='tornado'){ const [sx,sy]=W2S(z.x,z.z,ox,oy); objs.push({d:z.x+z.z,f:()=>{ for(let i=0;i<6;i++){ const r=(5+i*3.2)*z.r, y=sy-i*7, a=time*9+i; cx.strokeStyle=`rgba(230,240,255,${.75-i*.08})`; cx.lineWidth=2.4; cx.beginPath(); cx.ellipse(sx+Math.sin(a)*2,y,r,r*.35,0,0,7); cx.stroke(); } }}); } }
  for(const k in P.weapons){ const w=P.weapons[k]; if(!w.orbit)continue; for(const [x,z] of w.orbit){ const [sx,sy]=W2S(x,z,ox,oy); objs.push({d:x+z,f:()=>{ if(k==='parrot'){ cx.drawImage(img.parrot,sx-13,sy-30,26,26); } else { cx.drawImage(img.shield,sx-11,sy-24,22,22); } }}); } }
  objs.sort((a,b)=>a.d-b.d); for(const o of objs) o.f();
  // overlays: booms, swings, bolts, particles, numbers
  for(const b of booms){ const [sx,sy]=W2S(b.x,b.z,ox,oy), k=1-b.life/.4; cx.strokeStyle=b.c; cx.globalAlpha=Math.max(0,b.life*2.5); cx.lineWidth=4; cx.beginPath(); cx.ellipse(sx,sy,b.r*HW*1.4*(.6+k*.6),b.r*HH*1.4*(.6+k*.6),0,0,7); cx.stroke(); cx.globalAlpha=1; }
  for(const f of fx){
    if(f.type==='swing'){ const [sx,sy]=W2S(f.x,f.z,ox,oy); cx.fillStyle=`rgba(255,255,255,${f.life*2})`; cx.beginPath(); cx.moveTo(sx,sy-6); const steps=20; for(let i=0;i<=steps;i++){ const a=f.a-f.arc/2+f.arc*i/steps, x=f.r*Math.cos(a), z=f.r*Math.sin(a); cx.lineTo(sx+(x-z)*HW, sy-6+(x+z)*HH); } cx.closePath(); cx.fill(); }
    else if(f.type==='bolt'){ cx.strokeStyle=f.c; cx.lineWidth=3; cx.shadowColor=f.c; cx.shadowBlur=8; cx.beginPath(); f.pts.forEach(([x,z],i)=>{ const [sx,sy]=W2S(x,z,ox,oy); const jx=i?(Math.random()-.5)*8:0; i?cx.lineTo(sx+jx,sy-14):cx.moveTo(sx,sy-14); }); cx.stroke(); cx.shadowBlur=0; }
    else { const [sx,sy]=W2S(f.x,f.z,ox,oy); cx.fillStyle=f.c; cx.globalAlpha=Math.max(0,f.life/.6); cx.fillRect(sx-2.5,sy-16,5,5); cx.globalAlpha=1; } }
  cx.textAlign='center'; for(const d of dnums){ const [sx,sy]=W2S(d.x,d.z,ox,oy), y=sy-30-(.6-d.life)*34; cx.font=`700 ${d.crit?17:12}px Fredoka, sans-serif`; cx.lineWidth=3; cx.strokeStyle='#0b0c10'; cx.strokeText(d.v,sx,y); cx.fillStyle=d.crit?'#ff8a3c':'#ffd54a'; cx.fillText(d.v,sx,y); }
  // weather
  const wt=B.weather; for(const p of parts){ p.y+=({snow:.0012,sand:.0004,ember:-.0016,bubble:-.001,firefly:0,leaf:.0009})[wt]||0; p.x+=({sand:.004,leaf:.0012})[wt]||Math.sin(time+p.s*9)*.0004; if(p.y>1)p.y=0; if(p.y<0)p.y=1; if(p.x>1)p.x=0;
    cx.globalAlpha=wt==='firefly'?.4+.6*Math.abs(Math.sin(time*2+p.s*20)):.75; cx.fillStyle={snow:'#fff',sand:'#f6d9a0',ember:'#ff8a3c',bubble:'#d6fbff',firefly:'#fff38a',leaf:'#7ccf54'}[wt]; cx.fillRect(p.x*W,p.y*H,wt==='sand'?4:3,wt==='sand'?1.5:3); } cx.globalAlpha=1;
  const night=bloodMoon>0?1:isNight()?Math.min(1,(SM()%6-4.4)*3,(6-SM()%6)*3):0;
  if(night>0){ const gr=cx.createRadialGradient(W/2,H/2,60,W/2,H/2,Math.max(W,H)*.7); const c=bloodMoon>0?'60,0,10':'10,12,40'; gr.addColorStop(0,`rgba(${c},0)`); gr.addColorStop(1,`rgba(${c},${.6*night})`); cx.fillStyle=gr; cx.fillRect(0,0,W,H); }
  if(freeze>0){ cx.fillStyle='rgba(150,210,255,.16)'; cx.fillRect(0,0,W,H); }
  if(P.hurt>.25){ cx.fillStyle='rgba(229,56,59,.16)'; cx.fillRect(0,0,W,H); }
  if(joy&&state==='play'){ cx.strokeStyle='rgba(255,255,255,.55)'; cx.lineWidth=3; cx.beginPath(); cx.arc(joy.x0,joy.y0,40,0,7); cx.stroke(); cx.fillStyle='rgba(255,255,255,.65)'; const dx=joy.x-joy.x0, dy=joy.y-joy.y0, L=Math.min(40,Math.hypot(dx,dy)), a=Math.atan2(dy,dx); cx.beginPath(); cx.arc(joy.x0+Math.cos(a)*L,joy.y0+Math.sin(a)*L,16,0,7); cx.fill(); }
  // boss bar
  const boss=enemies.find(e=>e.boss); $('bossbar').hidden=!boss; if(boss){ $('bossname').textContent=boss.type.replace(/_/g,' '); $('bossfill').style.width=Math.max(0,boss.hp/boss.max*100)+'%'; }
  hud(); }
function drawPickup(p,sx,sy){ const y=sy-8+Math.sin(time*4+p.x)*2;
  if(p.t==='tchest'){ cx.fillStyle='rgba(255,201,60,.35)'; cx.beginPath(); cx.ellipse(sx,sy,18,8,0,0,7); cx.fill(); cx.drawImage(img.chest_epic,sx-(p.big?18:14),y-(p.big?30:24),p.big?36:28,p.big?36:28); return; }
  const ic={gold:'golden',chicken:'heart',magnet:'magnet',bomb:'monster',clock:'clock'}[p.t]; cx.drawImage(img[ic],sx-8,y-12,16,16); }
function drawPlayer(ox,oy){ const gh=groundH(P.x,P.z), [,m]=tile(P.x,P.z), boat=m===M.WATER||m===M.LAVA, sx=ox+(P.x-P.z)*HW, sy=oy+(P.x+P.z)*HH-gh*PH/STEP;
  const bob=boat?Math.sin(time*4)*1.5:Math.abs(Math.sin(time*10))*(P.moving?2:0);
  if(P.buffs.fury>0){ cx.strokeStyle='rgba(255,106,60,.85)'; cx.lineWidth=2; cx.beginPath(); cx.ellipse(sx,sy,14+Math.sin(time*8)*2,7,0,0,7); cx.stroke(); }
  cx.fillStyle='rgba(0,0,0,.3)'; cx.beginPath(); cx.ellipse(sx,sy,9,4,0,0,7); cx.fill();
  if(boat){ cx.fillStyle=m===M.LAVA?'#555':'#8a5a32'; cx.strokeStyle='#14121c'; cx.lineWidth=1.5; cx.beginPath(); cx.moveTo(sx-17,sy-6+bob); cx.quadraticCurveTo(sx,sy+8+bob,sx+17,sy-6+bob); cx.lineTo(sx+13,sy-10+bob); cx.lineTo(sx-13,sy-10+bob); cx.closePath(); cx.fill(); cx.stroke();
    const pa=Math.sin(time*5)*6; cx.strokeStyle='#c99a5e'; cx.lineWidth=2.5; cx.beginPath(); cx.moveTo(sx+4,sy-24+bob); cx.lineTo(sx+15+pa,sy+2+bob); cx.stroke(); }
  const icon=CHARS[RUN.char].icon; if(P.inv>0&&Math.floor(time*12)%2) return;
  cx.save(); cx.translate(sx,sy-(boat?13:2)-bob); cx.scale(P.face,1); cx.drawImage(P.hurt>.3&&flash[icon]?flash[icon]:img[icon],-16,-30,32,32); cx.restore(); }
function drawEnemy(e,sx,sy){ const [,m]=tile(e.x,e.z), inW=!e.fly&&LIQUID.has(m); if(inW) sy+=5; const lift=e.fly?10+Math.sin(time*4+e.x)*3:0;
  cx.fillStyle='rgba(0,0,0,.28)'; cx.beginPath(); cx.ellipse(sx,sy,e.sz*.3,e.sz*.13,0,0,7); cx.fill();
  if(e.elite||e.boss||e.cursed){ cx.fillStyle=e.boss?'rgba(255,61,127,.3)':e.cursed?'rgba(180,76,255,.32)':'rgba(255,201,60,.3)'; cx.beginPath(); cx.ellipse(sx,sy,e.sz*.6,e.sz*.27,0,0,7); cx.fill(); }
  if(e.st>0){ cx.strokeStyle='rgba(255,60,60,.9)'; cx.lineWidth=2; cx.beginPath(); cx.ellipse(sx,sy,e.sz*.5,e.sz*.22,0,0,7); cx.stroke(); }
  cx.save(); if(inW){ cx.beginPath(); cx.rect(sx-90,sy-240,180,236); cx.clip(); }
  const flip=(P.x-e.x)-(P.z-e.z)<0; cx.translate(sx,0); if(flip) cx.scale(-1,1); if(freeze>0&&!e.boss) cx.globalAlpha=.75;
  cx.drawImage(e.hit>0&&flash[e.type]?flash[e.type]:img[e.type],-e.sz/2,sy-e.sz*.92-lift+Math.sin(time*8+e.x),e.sz,e.sz); cx.restore(); cx.globalAlpha=1;
  if(e.elite&&!e.boss){ const w=e.sz*.8; cx.fillStyle='#0f1115'; cx.fillRect(sx-w/2,sy-e.sz-8-lift,w,5); cx.fillStyle='#ffc93c'; cx.fillRect(sx-w/2,sy-e.sz-8-lift,w*Math.max(0,e.hp/e.max),5); cx.drawImage(img.crown,sx-7,sy-e.sz-24-lift,14,14); } }
let miniT=-9; const mini=$('mini'), mg=mini.getContext('2d');
function hud(){ $('hpf').style.width=Math.max(0,P.hp/S.maxhp*100)+'%'; $('hpt').textContent=Math.max(0,Math.ceil(P.hp))+' / '+Math.round(S.maxhp);
  $('xpf').style.width=Math.min(100,P.xp/P.need*100)+'%'; $('lv').textContent=P.lv;
  const mm=Math.floor(time/60), ss=Math.floor(time%60); $('tm').textContent=mm+':'+String(ss).padStart(2,'0'); $('tmsub').textContent=RUN.len===1800?'of 30:00':'quick run · '+Math.floor(SM())+' / 30';
  $('goldc').textContent=gold+' gold'; $('killc').textContent=kills+' kills';
  if(time-miniT>.4||miniT>time){ miniT=time; const Sz=46; for(let j=-Sz;j<Sz;j+=2)for(let i=-Sz;i<Sz;i+=2){ const [h,m,b]=tile(P.x+i,P.z+j); mg.fillStyle=shade(matCol(m,b),.85+h*.06); mg.fillRect(i+Sz,j+Sz,2,2); }
    for(let a=-2;a<=2;a++)for(let b=-2;b<=2;b++){ const ch=chunks.get((Math.floor(P.x/CH)+a)+','+(Math.floor(P.z/CH)+b)); if(!ch)continue; for(const p of ch.props){ if((p.kind!=='chest'||p.open)&&(p.kind!=='shrine'||p.used))continue; const X=p.x-P.x+Sz, Y=p.z-P.z+Sz; if(X<0||Y<0||X>92||Y>92)continue; mg.fillStyle=p.kind==='chest'?'#b44cff':'#ffc93c'; mg.fillRect(X-2,Y-2,4,4); } }
    for(const p of pickups){ if(p.t!=='tchest')continue; const X=p.x-P.x+Sz, Y=p.z-P.z+Sz; if(X<0||Y<0||X>92||Y>92)continue; mg.fillStyle='#ff3d7f'; mg.fillRect(X-2,Y-2,4,4); }
    mg.fillStyle='#fff'; mg.strokeStyle='#0b0c10'; mg.beginPath(); mg.arc(Sz,Sz,3,0,7); mg.fill(); mg.stroke(); } }
function renderSlots(){ const mk=(ic,lv,col,max)=>`<div class="slot" style="--r:${col}"><img src="${ICON[ic]}" alt=""><em>${lv>=max?'MAX':lv}</em></div>`;
  let h=''; for(const k in P.weapons){ const w=P.weapons[k]; h+=mk(WEAP[k].icon,w.lv,w.evo?'#ff3d7f':w.lv>=8?'#ffb23f':'#4aa3ff',8); } for(let i=Object.keys(P.weapons).length;i<4;i++) h+='<div class="slot empty"></div>';
  $('wslots').innerHTML=h; h=''; for(const k in P.tomes){ h+=mk(TOME[k].icon,P.tomes[k].l,'#5be37d',5); } for(let i=Object.keys(P.tomes).length;i<4;i++) h+='<div class="slot empty"></div>'; $('tslots').innerHTML=h; }

/* ================= PAUSE / END / TITLE ================= */
function openPause(){ if(state!=='play')return; state='pause'; const tot=Object.values(dmgBy).reduce((a,b)=>a+b,0)||1;
  let h='<h3>Weapons</h3>'; for(const k in P.weapons){ const w=P.weapons[k]; h+=`<div class="row"><img src="${ICON[WEAP[k].icon]}" alt=""><b>${w.evo?WEAP[k].evo.name:WEAP[k].name}</b><span>LV ${w.lv}${w.evo?' · EVOLVED':''}</span><em>${Math.round(dmgBy[k]||0).toLocaleString()} dmg</em></div>`; }
  h+='<h3>Tomes</h3>'; for(const k in P.tomes) h+=`<div class="row"><img src="${ICON[TOME[k].icon]}" alt=""><b>${TOME[k].name}</b><span>LV ${P.tomes[k].l}</span><em>${TOME[k].desc}</em></div>`; if(!Object.keys(P.tomes).length) h+='<p class="dim">No tomes yet.</p>';
  h+='<h3>Items</h3>'; for(const k in P.items) h+=`<div class="row"><img src="${ICON[ITEM[k].icon]}" alt=""><b>${ITEM[k].name}</b><span>×${P.items[k].toFixed(1)}</span><em>${ITEM[k].desc(P.items[k])}</em></div>`; if(!Object.keys(P.items).length) h+='<p class="dim">Open gold chests in the world to find items.</p>';
  const evo=Object.keys(P.weapons).map(k=>`${WEAP[k].name} LV 8 + ${TOME[WEAP[k].evo.tome].name} → ${WEAP[k].evo.name}`).join('<br>');
  h+=`<h3>Evolutions</h3><p class="dim">${evo}<br>Open an elite or boss chest once both are owned.</p>`;
  h+=`<h3>Stats</h3><div class="stats">${[['Max HP',Math.round(S.maxhp)],['Regen',S.regen.toFixed(1)+'/s'],['Armor',Math.round(S.armor/(.75+S.armor)*100)+'%'],['Damage','×'+S.might.toFixed(2)],['Area','×'+S.area.toFixed(2)],['Cooldown','×'+S.cooldown.toFixed(2)],['Amount','+'+S.amount],['Speed',S.speed.toFixed(1)],['Magnet',S.magnet.toFixed(1)],['Luck','+'+Math.round(S.luck*100)+'%'],['Crit',Math.round(S.crit*100)+'%'],['XP','×'+S.growth.toFixed(2)]].map(([a,b])=>`<div><span>${a}</span><b>${b}</b></div>`).join('')}</div>`;
  h+=`<p class="dim">Seed ${SEED} · ${DIFF[RUN.diff].name} · ${CHARS[RUN.char].name}</p>`;
  $('pauseBody').innerHTML=h; $('pauseov').hidden=false; }
$('pausebtn').onclick=openPause; $('resume').onclick=()=>{ $('pauseov').hidden=true; state='play'; }; $('giveup').onclick=()=>{ $('pauseov').hidden=true; endRun(false); };
function stageClear(){ state='clear'; save.clears[RUN.diff]=1; persist(); $('clearov').hidden=false; }
$('endless').onclick=()=>{ $('clearov').hidden=true; state='play'; banner('ENDLESS','The horde never stops now','#ff3d7f'); };
$('cashout').onclick=()=>{ $('clearov').hidden=true; endRun(true); };
function endRun(win){ state='end'; const m=SM(); const D=DIFF[RUN.diff];
  silverEarned=Math.round((kills/12+m*6+elitesKilled*8+minisKilled*40+(bossDead?250:0))*D.silver*(RUN.len===1800?1:.5));
  save.silver+=silverEarned; save.runs++; const bk=RUN.diff+RUN.len; if(!save.best[bk]||time>save.best[bk]) save.best[bk]=time; persist();
  $('endTitle').textContent=win?'STAGE CLEAR':'RUN OVER'; $('endTitle').style.color=win?'#ffc93c':'#fff';
  const tot=Object.values(dmgBy).reduce((a,b)=>a+b,0)||1, mm=Math.floor(time/60)+':'+String(Math.floor(time%60)).padStart(2,'0');
  let h=`<div class="tiles"><div><span>Time</span><b>${mm}</b></div><div><span>Kills</span><b>${kills.toLocaleString()}</b></div><div><span>Level</span><b>${P.lv}</b></div><div><span>Gold</span><b>${gold}</b></div></div><h3>Damage by weapon</h3>`;
  Object.entries(dmgBy).filter(([k])=>WEAP[k]).sort((a,b)=>b[1]-a[1]).forEach(([k,v],i)=>{ h+=`<div class="drow"><img src="${ICON[WEAP[k].icon]}" alt=""><div><b>${P.weapons[k]&&P.weapons[k].evo?WEAP[k].evo.name:WEAP[k].name}</b><i style="width:${v/tot*100}%;${i?'':'background:#ffb23f'}"></i></div><em>${Math.round(v).toLocaleString()}</em></div>`; });
  h+=`<div class="silver"><img src="${ICON.silver}" alt=""><div><b>+${silverEarned} silver</b><span>Wallet ${save.silver.toLocaleString()} · best ${Math.floor((save.best[bk]||0)/60)}:${String(Math.floor((save.best[bk]||0)%60)).padStart(2,'0')}</span></div></div>`;
  $('endBody').innerHTML=h; $('endov').hidden=false; $('lvov').hidden=true; $('pauseov').hidden=true; $('chestov').hidden=true; }
$('again').onclick=()=>{ $('endov').hidden=true; startRun(); }; $('tomenu').onclick=()=>{ $('endov').hidden=true; openTitle(); };
function openTitle(){ state='title'; renderTitle(); $('titleov').hidden=false; }
function renderTitle(){ $('wallet').textContent=save.silver.toLocaleString()+' silver';
  let h=''; for(const k in CHARS){ const c=CHARS[k], own=save.chars[k]; h+=`<button class="ch ${RUN.char===k?'on':''} ${own?'':'locked'}" data-k="${k}"><img src="${ICON[c.icon]}" alt=""><b>${c.name}</b><span>${WEAP[c.weapon].name}</span><span>${c.perk}</span>${own?'':`<em>${c.cost} silver</em>`}</button>`; }
  $('chars').innerHTML=h; $('chars').querySelectorAll('.ch').forEach(b=>b.onclick=()=>{ const k=b.dataset.k; if(!save.chars[k]){ if(save.silver>=CHARS[k].cost){ save.silver-=CHARS[k].cost; save.chars[k]=1; persist(); toast(CHARS[k].name+' unlocked!','#ffc93c'); } else { toast('Need '+CHARS[k].cost+' silver','#ff8a7a'); return; } } RUN.char=k; renderTitle(); });
  document.querySelectorAll('[data-diff]').forEach(b=>{ b.classList.toggle('on',b.dataset.diff===RUN.diff); b.onclick=()=>{ RUN.diff=b.dataset.diff; renderTitle(); }; });
  document.querySelectorAll('[data-len]').forEach(b=>{ b.classList.toggle('on',+b.dataset.len===RUN.len); b.onclick=()=>{ RUN.len=+b.dataset.len; renderTitle(); }; });
  $('seedtxt').textContent='World seed '+SEED; }
$('newseed').onclick=()=>{ SEED=(Math.random()*1e6)|0; chunks.clear(); spriteCache.clear(); renderTitle(); };
$('metabtn').onclick=()=>{ renderMeta(); $('metaov').hidden=false; }; $('metaclose').onclick=()=>{ $('metaov').hidden=true; renderTitle(); };
function renderMeta(){ $('metawallet').textContent=save.silver.toLocaleString()+' silver'; let h='';
  for(const m of META){ const l=save.meta[m.id]||0, max=l>=m.max, cost=metaCost(m,l); h+=`<div class="mrow"><div><b>${m.name}</b><span>${m.desc}</span><div class="pips">${Array.from({length:m.max},(_,i)=>`<i class="${i<l?'on':''}"></i>`).join('')}</div></div><button class="btn ${max?'':'gold'}" data-id="${m.id}" ${max||save.silver<cost?'disabled':''}>${max?'MAX':cost}</button></div>`; }
  $('metaList').innerHTML=h; $('metaList').querySelectorAll('button[data-id]').forEach(b=>b.onclick=()=>{ const m=META.find(x=>x.id===b.dataset.id), l=save.meta[m.id]||0, c=metaCost(m,l); if(save.silver>=c&&l<m.max){ save.silver-=c; save.meta[m.id]=l+1; persist(); renderMeta(); } }); }
function startRun(){ $('titleov').hidden=true; newRun(); state='play'; banner(BIOME_ROLE&&'MINUTE 0','Survive 30 minutes · boss at 30:00','#fff'); }
$('play').onclick=startRun;

/* ================= LOOP ================= */
let last=0; function loop(t){ const dt=Math.min(.05,(t-last)/1000||0); last=t; if(state==='play') update(dt); if(P) render(); requestAnimationFrame(loop); }
newRun(); openTitle(); requestAnimationFrame(loop);
window.dbg={get P(){return P}, get S(){return S}, biomeAt, tp(x,z){P.x=x;P.z=z;}, setT(t){time=t;}, get state(){return state}, get enemies(){return enemies}, give(k){ if(WEAP[k]){ if(P.weapons[k]) P.weapons[k].lv=8; else addWeapon(k); } renderSlots(); }};
