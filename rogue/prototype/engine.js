/* ================= WORLD ================= */
const CH=24, PAD=6, REG=64, STEP=0.5;
// materials
const M={GRASS:0,DARK:1,FLOW:2,PATH:3,SAND:4,WATER:5,STONE:6,CRYPT:7,WOOD:8,WALL:9,SNOW:10,ICE:11,LAVA:12,ASH:13,GOLDB:14,BONE:15};
const LIQUID=new Set([M.WATER,M.LAVA]);
// biomes: palette per material slot + enemy pool + weather
const BIOMES=[
 {name:'Meadow', sky:['#8fd0f5','#d2f0ff'], grass:[126,201,64], dark:[84,160,52], flow:[160,214,86], path:[226,150,74], sand:[236,205,128], water:[64,168,236], stone:[150,150,170], wall:[132,94,70], weather:'leaf',
  pool:[['twig_blight',3],['giant_fly',3],['slime_sprout',3],['flower_monster',2],['shadow_wolf',1],['mushroom_brute',1]], elite:'elite_twig_blight', mini:'bramble_golem'},
 {name:'Twilight Woods', sky:['#3b2a5c','#8a5a9c'], grass:[96,84,150], dark:[70,58,118], flow:[150,96,170], path:[214,128,70], sand:[170,140,120], water:[70,90,170], stone:[120,112,140], wall:[80,64,96], weather:'firefly',
  pool:[['ghost',3],['skeleton',3],['witch',2],['shadow_wolf',2]], elite:'witch', mini:'hornet_queen'},
 {name:'Dune Ruins', sky:['#f6c27a','#ffe9c2'], grass:[230,196,120], dark:[214,176,100], flow:[240,212,140], path:[196,140,80], sand:[245,220,150], water:[60,180,200], stone:[200,170,120], wall:[180,130,80], weather:'sand',
  pool:[['mummy',3],['cobra',3],['anubis',1],['bee_swarm',2]], elite:'anubis', mini:'anubis'},
 {name:'Frost Peak', sky:['#a8d4f0','#eef8ff'], grass:[226,238,248], dark:[196,214,232], flow:[236,244,252], path:[150,180,210], sand:[210,224,240], water:[150,210,245], stone:[150,168,190], wall:[110,140,180], weather:'snow',
  pool:[['frost_wisp',3],['frozy_cube',2],['ice_harpy',2],['slime_sprout',1]], elite:'frozy_cube', mini:'ice_harpy'},
 {name:'Coral Coast', sky:['#7ad8e8','#d6fbff'], grass:[96,206,170], dark:[60,170,150], flow:[255,140,150], path:[240,214,160], sand:[248,226,170], water:[40,170,220], stone:[230,140,140], wall:[170,110,80], weather:'bubble',
  pool:[['fishfolk',3],['crab',3],['sea_horror',1],['giant_fly',1]], elite:'sea_horror', mini:'sea_horror'},
 {name:'Hellforge', sky:['#3a0d0d','#a02818'], grass:[96,52,48], dark:[70,36,36], flow:[140,60,40], path:[60,52,56], sand:[110,70,56], water:[255,110,30], stone:[90,80,86], wall:[60,40,44], weather:'ember',
  pool:[['imp',3],['hell_critter',3],['cacodaemon',1]], elite:'cacodaemon', mini:'cacodaemon'},
];
let SEED=1337;
function hash(a,b,c){ let h=Math.imul(a|0,374761393)^Math.imul(b|0,668265263)^Math.imul(c|0,2246822519)^Math.imul(SEED,3266489917); h=Math.imul(h^(h>>>13),1274126177); return ((h^(h>>>16))>>>0)/4294967295; }
function vn(x,z,s,k){ x/=s; z/=s; const xi=Math.floor(x), zi=Math.floor(z), xf=x-xi, zf=z-zi, u=xf*xf*(3-2*xf), v=zf*zf*(3-2*zf);
  const a=hash(xi,zi,k), b=hash(xi+1,zi,k), c=hash(xi,zi+1,k), d=hash(xi+1,zi+1,k); return (a+(b-a)*u)+((c+(d-c)*u)-(a+(b-a)*u))*v; }
function fbm(x,z,s,k,o=4){ let t=0,a=1,n=0; for(let i=0;i<o;i++){ t+=a*vn(x,z,s/(1<<i),k+i*31); n+=a; a*=.5; } return t/n; }
function biomeAt(x,z){ const d=Math.hypot(x,z); if(d<70) return 0;
  const t=fbm(x,z,420,101,3), m=fbm(x,z,380,202,3), hell=fbm(x,z,600,303,2);
  if(hell>.66&&d>200) return 5; if(t<.36) return 3; if(t>.62) return m<.45?2:4; return m>.58?1:0; }
function base(x,z){ const b=biomeAt(x,z), wx=(fbm(x,z,60,7)-.5)*26, wz=(fbm(x,z,60,9)-.5)*26, e=fbm(x+wx,z+wz,90,1);
  let h=Math.max(-2,Math.min(2.5,Math.round((e-.5)*(b===3?9:7)/STEP)*STEP)), m=M.GRASS; const mo=fbm(x,z,45,3);
  if(mo>.62)m=M.DARK; else if(mo<.33)m=M.FLOW;
  const r=Math.abs(fbm(x+wx*.5,z,80,21)-.5); if(r<.015)m=M.PATH;
  const river=Math.abs(fbm(x,z+wx,160,55)-.5);
  const wl=b===4?.36:b===2?.24:.30;
  if(e<wl||river<.012){ m=b===5?M.LAVA:(b===3?M.ICE:M.WATER); h=b===3?Math.min(h,0):-1; }
  else if(e<wl+.03||river<.022) m=b===5?M.ASH:M.SAND;
  if(b===3&&h>=1.5&&m!==M.PATH) m=M.SNOW;
  return [h,m,b]; }
const KINDS=[ // per biome structure picks: [kind, weight]
 [['village',4],['crypt',3],['ruins',2],['tower',1]],
 [['graveyard',4],['crypt',4],['ruins',2]],
 [['pyramid',4],['tomb',3],['ruins',3]],
 [['icefort',4],['ruins',2],['tower',2]],
 [['docks',4],['village',3],['ruins',1]],
 [['forge',5],['ruins',2],['tower',2]]];
function structs(rx,rz){ const r=k=>hash(rx*97+k,rz*31-k,77), out=[]; if(rx===0&&rz===0) return out;
  const bx=rx*REG, bz=rz*REG, cx_=bx+14+(r(2)*36|0), cz_=bz+14+(r(3)*36|0), b=biomeAt(cx_,cz_);
  if(r(1)<.85){ const ks=KINDS[b], tot=ks.reduce((a,k)=>a+k[1],0); let v=r(4)*tot, kind=ks[0][0]; for(const k of ks){ if(v<k[1]){kind=k[0];break;} v-=k[1]; }
    out.push({t:kind,x:cx_,z:cz_,rad:6+(r(5)*5|0),dep:r(6)<.6?2:3,b,seed:r(7)}); }
  if(r(60)<.7) out.push({t:'shrine',x:bx+(r(61)*REG|0),z:bz+(r(62)*REG|0)});
  if(r(63)<.8) out.push({t:'chest',x:bx+(r(64)*REG|0),z:bz+(r(65)*REG|0)});
  return out; }
const chunks=new Map();
function genChunk(ci,cj){
  const n=CH+2*PAD, x0=ci*CH-PAD, z0=cj*CH-PAD, N=n*n, h=new Float32Array(N), m=new Int8Array(N), bio=new Int8Array(N), props=[];
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){ const [a,b,c]=base(x0+i,z0+j), q=j*n+i; h[q]=a; m[q]=b; bio[q]=c; }
  const at=(X,Z)=>{ const i=X-x0, j=Z-z0; return (i<0||j<0||i>=n||j>=n)?-1:j*n+i; };
  const prop=(X,Z,kind,extra)=>{ if(X>=ci*CH&&X<ci*CH+CH&&Z>=cj*CH&&Z<cj*CH+CH) props.push({x:X+.5,z:Z+.5,kind,...extra}); };
  const rx0=Math.floor((x0-REG)/REG), rx1=Math.floor((x0+n+REG)/REG), rz0=Math.floor((z0-REG)/REG), rz1=Math.floor((z0+n+REG)/REG);
  const blocked=new Uint8Array(N);
  for(let rx=rx0;rx<=rx1;rx++)for(let rz=rz0;rz<=rz1;rz++)for(const s of structs(rx,rz)){
    const surf=Math.max(0,base(s.x,s.z)[0]);
    const ringDo=(dir,mat1,mat2)=>{ for(let Z=s.z-s.rad-1;Z<=s.z+s.rad+1;Z++)for(let X=s.x-s.rad-1;X<=s.x+s.rad+1;X++){ const q=at(X,Z); if(q<0)continue;
        const dx=Math.abs(X-s.x), dz=Math.abs(Z-s.z), d=Math.max(dx,dz)+(dir<0?.35*Math.min(dx,dz):0); if(d>s.rad)continue;
        const ring=Math.min(s.dep+ (dir>0?2:0),Math.max(1,((s.rad-d)/(s.rad/(s.dep+(dir>0?2:0)))|0)+1)); h[q]=surf+dir*STEP*ring; m[q]=ring>=2?mat2:mat1; blocked[q]=1; } };
    if(s.t==='crypt'||s.t==='tomb'||s.t==='forge'){ ringDo(-1, s.b===5?M.ASH:M.STONE, s.b===5?M.ASH:(s.t==='tomb'?M.GOLDB:M.CRYPT));
      if(s.t==='forge'){ const q=at(s.x,s.z); for(let a=-1;a<=1;a++)for(let c=-1;c<=1;c++){ const q2=at(s.x+a,s.z+c); if(q2>=0){m[q2]=M.LAVA;} } }
      prop(s.x+s.rad-1,s.z,'torch'); prop(s.x-s.rad+1,s.z,'torch'); prop(s.x,s.z+s.rad-1,'torch'); }
    else if(s.t==='pyramid'){ ringDo(1,M.GOLDB,M.GOLDB); prop(s.x,s.z,'obelisk'); }
    else if(s.t==='village'||s.t==='docks'||s.t==='icefort'){
      const nH=s.t==='icefort'?1:2+(s.seed*3|0);
      for(let k=0;k<nH;k++){ const hr=t=>hash(s.x+k*13,s.z-k*7,t); const w=s.t==='icefort'?11:5+(hr(1)*3|0), d=s.t==='icefort'?11:4+(hr(2)*3|0);
        const hx=s.t==='icefort'?s.x-5:s.x+((hr(3)-.5)*22|0), hz=s.t==='icefort'?s.z-5:s.z+((hr(4)-.5)*22|0), door=hr(5)*4|0, fh=Math.max(0,base(hx,hz)[0]);
        for(let Z=hz;Z<hz+d;Z++)for(let X=hx;X<hx+w;X++){ const q=at(X,Z); if(q<0)continue; if(LIQUID.has(m[q])&&s.t!=='docks')continue;
          const edge=X===hx||X===hx+w-1||Z===hz||Z===hz+d-1, side=[Z===hz+d-1,Z===hz,X===hx,X===hx+w-1][door], mid=door<2?X===hx+(w>>1):Z===hz+(d>>1);
          const isWall=edge&&!(side&&mid);
          m[q]=isWall?M.WALL:(s.t==='icefort'?M.ICE:M.WOOD); h[q]=s.t==='docks'?0:fh; blocked[q]=1;
          if(isWall) prop(X,Z,'wall',{h:fh,ice:s.t==='icefort',roof:!(X===hx||X===hx+w-1)&&s.t!=='icefort'}); }
        if(s.t==='icefort') { prop(hx,hz,'tower',{h:fh}); prop(hx+w-1,hz+d-1,'tower',{h:fh}); } }
      if(s.t==='docks'){ for(let t=0;t<14;t++){ const q=at(s.x+t,s.z); if(q>=0&&LIQUID.has(m[q])){ m[q]=M.WOOD; h[q]=0; blocked[q]=1; } } } }
    else if(s.t==='graveyard'){ for(let Z=s.z-5;Z<=s.z+5;Z+=2)for(let X=s.x-6;X<=s.x+6;X+=3){ const q=at(X,Z); if(q<0||LIQUID.has(m[q]))continue; m[q]=M.DARK; blocked[q]=1; prop(X,Z,'grave'); } prop(s.x,s.z-7,'tree',{dead:1}); }
    else if(s.t==='ruins'){ for(let k=0;k<7;k++){ const X=s.x+((hash(s.x,k,1)-.5)*14|0), Z=s.z+((hash(s.z,k,2)-.5)*14|0), q=at(X,Z); if(q<0||LIQUID.has(m[q]))continue; m[q]=M.STONE; blocked[q]=1; prop(X,Z,'pillar',{tall:1+(hash(X,Z,3)*3|0)}); } }
    else if(s.t==='tower'){ prop(s.x,s.z,'tower',{h:surf}); const q=at(s.x,s.z); if(q>=0){m[q]=M.WALL;blocked[q]=1;} }
    else if(s.t==='shrine'||s.t==='chest'){ const q=at(s.x,s.z); if(q>=0&&!LIQUID.has(m[q])&&m[q]!==M.WALL){ blocked[q]=1; prop(s.x,s.z,s.t,{open:false,charge:0,sk:['fury','magnet','heal','challenge'][hash(s.x,s.z,5)*4|0]}); } }
  }
  // spawn clearing
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){ const X=x0+i,Z=z0+j; if(X*X+Z*Z<80){ const q=j*n+i; blocked[q]=1; if(LIQUID.has(m[q])){m[q]=M.GRASS;h[q]=0;} } }
  // nature props on a jittered grid
  for(let j=PAD;j<PAD+CH;j++)for(let i=PAD;i<PAD+CH;i++){ const q=j*n+i, X=x0+i, Z=z0+j; if(blocked[q])continue; const mm=m[q]; if(LIQUID.has(mm)||mm===M.PATH||mm===M.WALL)continue;
    const gx=Math.floor(X/4), gz=Math.floor(Z/4); if(((X%4+4)%4)!==(hash(gx,gz,11)*4|0)||((Z%4+4)%4)!==(hash(gx,gz,12)*4|0))continue; const v=hash(gx,gz,13), b=bio[q];
    const dens=[.5,.6,.22,.4,.35,.3][b]; if(v>dens){ if(v>.96) props.push({x:X+.5,z:Z+.5,kind:'lantern',b,v:0,hp:1}); continue; } const w=hash(gx,gz,14);
    const kind=[w<.8?'tree':'rock', w<.7?'tree':'grave', w<.5?'cactus':'rock', w<.75?'pine':'rock', w<.6?'palm':'coral', w<.5?'crystal':'rock'][b];
    props.push({x:X+.5,z:Z+.5,kind,b,v:w}); }
  // never-jump clamp (land only)
  for(let it=0;it<12;it++){ let ch=false;
    for(let j=0;j<n;j++)for(let i=0;i<n;i++){ const q=j*n+i; if(m[q]===M.WALL||LIQUID.has(m[q]))continue;
      for(let k=0;k<4;k++){ const a=i+[1,-1,0,0][k], c=j+[0,0,1,-1][k]; if(a<0||c<0||a>=n||c>=n)continue; const r=c*n+a; if(m[r]===M.WALL||LIQUID.has(m[r]))continue; if(h[q]>h[r]+STEP){h[q]=h[r]+STEP;ch=true;} } }
    if(!ch)break; }
  const H_=new Float32Array(CH*CH), M_=new Int8Array(CH*CH), B_=new Int8Array(CH*CH);
  for(let j=0;j<CH;j++)for(let i=0;i<CH;i++){ const q=(j+PAD)*n+i+PAD, o=j*CH+i; H_[o]=h[q]; M_[o]=m[q]; B_[o]=bio[q]; }
  for(const p of props){ const o=(Math.floor(p.z)-cj*CH)*CH+(Math.floor(p.x)-ci*CH); p.gh=H_[o]; }
  return {ci,cj,h:H_,m:M_,b:B_,props,born:performance.now(),img:null}; }
function chunkAt(ci,cj){ const k=ci+','+cj; let c=chunks.get(k); if(!c){ c=genChunk(ci,cj); chunks.set(k,c); } return c; }
function tile(x,z){ x=Math.floor(x); z=Math.floor(z); const ci=Math.floor(x/CH), cj=Math.floor(z/CH), c=chunkAt(ci,cj), o=(z-cj*CH)*CH+(x-ci*CH); return [c.h[o],c.m[o],c.b[o]]; }

/* ================= RENDER ================= */
const HW=9, HH=4.5, PH=4.5;                  // smaller cubits: 2x2 studs per tile
const shade=(c,k)=>`rgb(${Math.min(255,c[0]*k)|0},${Math.min(255,c[1]*k)|0},${Math.min(255,c[2]*k)|0})`;
function matCol(m,b){ const B=BIOMES[b]; switch(m){case M.GRASS:return B.grass;case M.DARK:return B.dark;case M.FLOW:return B.flow;case M.PATH:return B.path;case M.SAND:return B.sand;case M.ASH:return B.sand;
  case M.WATER:return B.water;case M.LAVA:return [255,110,30];case M.ICE:return [170,220,250];case M.STONE:return B.stone;case M.CRYPT:return [104,92,140];case M.WOOD:return [176,116,66];
  case M.WALL:return B.wall;case M.SNOW:return [244,248,255];case M.GOLDB:return [232,190,90];default:return [255,0,255];} }
const liqH=m=>m===M.ICE?0: -1.25;
const surfH=(h,m)=>(m===M.WATER||m===M.LAVA)?-1.25:h;
let CRES=1;
function buildChunkImage(c){ CRES=DPR;
  // terrain only (tops, cliff faces, ink hull) baked once per chunk
  const minS=c.ci*CH+c.cj*CH, W_=(CH*2)*HW+4, H_=(CH*2)*HH+40*PH;
  const can=document.createElement('canvas'); can.width=W_*CRES; can.height=H_*CRES; const g=can.getContext('2d'); g.scale(CRES,CRES);
  // origin: tile (ci*CH, cj*CH) top corner at (CH*HW+2, 20*PH)
  const OX=CH*HW+2, OY=20*PH;
  for(let s=0;s<2*CH-1;s++) for(let a=0;a<CH;a++){ const b=s-a; if(b<0||b>=CH)continue;
    const X=c.ci*CH+a, Z=c.cj*CH+b, o=b*CH+a, m=c.m[o], bi=c.b[o], h=surfH(c.h[o],m), col=matCol(m,bi);
    const sx=OX+(a-b)*HW, sy=OY+(a+b)*HH-h*PH/STEP;
    const [hr,mr]=tile(X+1,Z), [hl,ml]=tile(X,Z+1), dr=(h-surfH(hr,mr))*PH/STEP, dl=(h-surfH(hl,ml))*PH/STEP;
    g.strokeStyle='#14121c'; g.lineWidth=.9;
    if(dl>0){ g.fillStyle=shade(col,.7); g.beginPath(); g.moveTo(sx-HW,sy+HH); g.lineTo(sx,sy+HH*2); g.lineTo(sx,sy+HH*2+dl); g.lineTo(sx-HW,sy+HH+dl); g.closePath(); g.fill(); g.stroke(); }
    if(dr>0){ g.fillStyle=shade(col,.55); g.beginPath(); g.moveTo(sx+HW,sy+HH); g.lineTo(sx,sy+HH*2); g.lineTo(sx,sy+HH*2+dr); g.lineTo(sx+HW,sy+HH+dr); g.closePath(); g.fill(); g.stroke(); }
    const lvl=(c.h[o]+2)/STEP, k=(m===M.WATER||m===M.LAVA)?1:.9+lvl*.03;
    g.fillStyle=shade(col,k); g.beginPath(); g.moveTo(sx,sy); g.lineTo(sx+HW,sy+HH); g.lineTo(sx,sy+HH*2); g.lineTo(sx-HW,sy+HH); g.closePath(); g.fill();
    if(m===M.WATER||m===M.LAVA||m===M.ICE){ if(hash(X,Z,9)<.25){ g.strokeStyle=m===M.LAVA?'rgba(255,230,120,.7)':'rgba(255,255,255,.45)'; g.beginPath(); g.moveTo(sx-3,sy+HH); g.lineTo(sx+3,sy+HH); g.stroke(); } }
    else { for(const [u,v] of [[.25,.25],[.75,.25],[.25,.75],[.75,.75]]){ const px=sx+(u-v)*HW, py=sy+(u+v)*HH;
      g.fillStyle=shade(col,k*.72); g.beginPath(); g.ellipse(px,py+.8,HW*.17,HH*.17,0,0,7); g.fill();
      g.fillStyle=shade(col,k*1.14); g.beginPath(); g.ellipse(px,py,HW*.17,HH*.17,0,0,7); g.fill(); } }
    const [hb,mb]=tile(X-1,Z), [ha,ma]=tile(X,Z-1); g.strokeStyle='#14121c'; g.lineWidth=1.1; g.beginPath();
    if(surfH(ha,ma)<h){ g.moveTo(sx,sy); g.lineTo(sx+HW,sy+HH); } if(surfH(hb,mb)<h){ g.moveTo(sx,sy); g.lineTo(sx-HW,sy+HH); } g.stroke(); }
  c.img=can; c.ox=OX; c.oy=OY; c.iw=W_; c.ih=H_; }
function cube(x,y,w,hh,c,k=1){ cx.strokeStyle='#14121c'; cx.lineWidth=1;
  cx.fillStyle=shade(c,1.05*k); cx.beginPath(); cx.moveTo(x,y-hh-w/2); cx.lineTo(x+w,y-hh); cx.lineTo(x,y-hh+w/2); cx.lineTo(x-w,y-hh); cx.closePath(); cx.fill(); cx.stroke();
  cx.fillStyle=shade(c,.78*k); cx.beginPath(); cx.moveTo(x-w,y-hh); cx.lineTo(x,y-hh+w/2); cx.lineTo(x,y+w/2); cx.lineTo(x-w,y); cx.closePath(); cx.fill(); cx.stroke();
  cx.fillStyle=shade(c,.6*k); cx.beginPath(); cx.moveTo(x+w,y-hh); cx.lineTo(x,y-hh+w/2); cx.lineTo(x,y+w/2); cx.lineTo(x+w,y); cx.closePath(); cx.fill(); cx.stroke(); }
function drawProp(p,sx,sy,t){
  switch(p.kind){
  case 'tree': { if(p.dead){ cube(sx,sy,2,16,[90,70,60]); cube(sx+5,sy-12,1.5,6,[90,70,60]); break; } const g=p.v<.4?[78,176,72]:[58,150,64]; cube(sx,sy,2.2,9,[120,78,44]); cube(sx,sy-9,8,7,g); cube(sx,sy-16,5.5,5,g.map(q=>q*1.1)); break; }
  case 'pine': cube(sx,sy,2,6,[110,80,60]); cube(sx,sy-6,8,5,[60,130,110]); cube(sx,sy-11,6,5,[230,240,250]); cube(sx,sy-16,3.5,5,[230,240,250]); break;
  case 'palm': cube(sx,sy,1.8,16,[170,120,70]); cube(sx,sy-16,9,3,[70,190,110]); break;
  case 'cactus': cube(sx,sy,3,14,[90,170,90]); cube(sx+6,sy-8,2,6,[90,170,90]); break;
  case 'coral': cube(sx,sy,4,7,[255,120,150]); cube(sx+3,sy-7,2,5,[255,170,120]); break;
  case 'crystal': { const k=.85+.25*Math.sin(t*3+p.x); cube(sx,sy,3.5,12,[255,120,60],k); cube(sx+5,sy+2,2.5,7,[255,180,80],k); break; }
  case 'rock': cube(sx,sy,5.5,4.5,[150,152,168]); break;
  case 'grave': cube(sx,sy,3.5,9,[150,150,170]); cube(sx,sy-9,2,2,[120,120,140]); break;
  case 'pillar': for(let i=0;i<p.tall;i++) cube(sx,sy-i*9,4,9,[200,196,186]); break;
  case 'obelisk': for(let i=0;i<4;i++) cube(sx,sy-i*9,4-i*.6,9,[250,214,120]); cube(sx,sy-38,2,4,[255,255,255]); break;
  case 'torch': { cube(sx,sy,1.5,9,[110,80,60]); const f=4+Math.sin(t*12+p.x)*1.2; cx.fillStyle='#ffb23f'; cx.beginPath(); cx.arc(sx,sy-12,f,0,7); cx.fill(); cx.fillStyle='#fff1a8'; cx.beginPath(); cx.arc(sx,sy-12,f*.45,0,7); cx.fill(); break; }
  case 'wall': { const c=p.ice?[190,225,250]:BIOMES[biomeAt(p.x,p.z)].wall; cube(sx,sy+HH,HW,PH*3.2,c); if(p.roof) cube(sx,sy+HH-PH*3.2,HW*.9,2.5,[214,90,70]); break; }
  case 'tower': for(let i=0;i<5;i++) cube(sx,sy-i*9,7,9,i===4?[214,90,70]:[170,170,186]); break;
  case 'shrine': { cube(sx,sy,7,4,[170,170,186]); const k=p.used?.5:1; cx.fillStyle=p.used?'#666':({fury:'#ff6a3c',magnet:'#4aa3ff',heal:'#5be37d',challenge:'#b44cff'}[p.sk]||'#ffc93c'); cx.beginPath(); cx.arc(sx,sy-10+Math.sin(t*3)*1.5,4.5*k+2,0,7); cx.fill();
      if(p.charge>0&&!p.used){ cx.strokeStyle='#ffc93c'; cx.lineWidth=3; cx.beginPath(); cx.ellipse(sx,sy,26,13,0,-Math.PI/2,-Math.PI/2+Math.PI*2*p.charge); cx.stroke(); } break; }
  case 'lantern': if(!p.broken){ cube(sx,sy,3.5,9,[120,84,56]); const f=.7+.3*Math.sin(t*6+p.x*3); cx.fillStyle=`rgba(255,200,90,${f})`; cx.beginPath(); cx.arc(sx,sy-12,4,0,7); cx.fill(); } break;
  case 'chest': if(!p.open){ cx.drawImage(img.chest_epic,sx-13,sy-24+Math.sin(t*3+p.x)*1.5,26,26); } else cube(sx,sy,6,3,[120,90,60]); break;
  } }

const LIVE=new Set(['torch','crystal','shrine','chest','lantern']), spriteCache=new Map();
function propSprite(p){ const key=p.kind+'|'+(p.dead?1:0)+'|'+(p.v<.4?1:0)+'|'+(p.tall||0)+'|'+(p.ice?1:0)+'|'+(p.roof?1:0)+'|'+(p.kind==='wall'?biomeAt(p.x,p.z):0);
  let s=spriteCache.get(key); if(s) return s; const S=2, w=70, h=110; s=document.createElement('canvas'); s.width=w*S; s.height=h*S; const g=s.getContext('2d'); g.scale(S,S);
  const keep=cx; cx=g; drawProp(p,w/2,h-14,0); cx=keep; s.ax=w/2; s.ay=h-14; s.w=w; s.h=h; spriteCache.set(key,s); return s; }
function drawPropFast(p,sx,sy,t){ if(LIVE.has(p.kind)) return drawProp(p,sx,sy,t); const s=propSprite(p); cx.drawImage(s,sx-s.ax,sy-s.ay,s.w,s.h); }
