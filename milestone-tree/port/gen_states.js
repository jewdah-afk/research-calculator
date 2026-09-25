// Builds random but plausible game states (saves) + action scripts, from the game's own layer definitions.
// usage: node gen_states.js N seed [--mv K] > states.json
//   --mv K appends K saves inside the Prestige Multiverse (mp challenge 21) after the N regular ones, drawn from the
//   same random stream after them, so the first N states do not change

const G=require('./jsgame')();const c=G.ctx;
const N=+process.argv[2]||50; let s=+process.argv[3]||1;
const r=()=>{s=(s*16807)%2147483647;return (s-1)/2147483646};
const pick=a=>a[Math.floor(r()*a.length)];
const plain=o=>c.isPlainObject(o);
const layers=Object.keys(c.layers).filter(l=>!l.endsWith('-tab')&&l!=='ach'||l==='ach');
const MV=process.argv[4]==='--mv'?(+process.argv[5]||0):0;
const states=[];
function makeState(n, stage){             // stage: 0 = start of game, 1 = end
  const p=c.getStartPlayer();
  const bigE=Math.pow(10, stage*9);       // scale of exponents
  const mag=()=>{ const u=r(); if(u<0.1) return '0'; if(u<0.4) return String(Math.pow(10,r()*15)); if(u<0.85) return '1e'+Math.floor(r()*bigE*2+1); return 'e'+(r()*bigE*1e3).toExponential(4) };
  for(const l of layers){ const L=c.layers[l]; const pl=p[l]; if(!pl) continue;
    for(const k in pl){ if(pl[k] instanceof c.Decimal && r()<0.7) pl[k]=new c.Decimal(mag()); }
    if(pl.points!==undefined) { pl.best=pl.points.max(pl.best||0); if(pl.total) pl.total=pl.total.max(pl.points); }
    const prob=Math.min(1,stage*1.3)*r();
    if(L.upgrades){ pl.upgrades=[]; for(const id in L.upgrades) if(plain(L.upgrades[id]) && r()<prob) pl.upgrades.push(Number(id)); }
    if(L.buyables){ for(const id in L.buyables) if(plain(L.buyables[id]) && r()<prob) pl.buyables[id]=new c.Decimal(Math.floor(Math.pow(10,r()*3*stage))); }
    if(L.challenges){ for(const id in L.challenges) if(plain(L.challenges[id]) && r()<prob) pl.challenges[id]=Math.floor(r()*6*stage); }
    if(L.milestones && pl.milestones){ pl.milestones=[]; const ids=Object.keys(L.milestones).filter(k=>plain(L.milestones[k])); const cut=Math.floor(ids.length*prob); for(let i=0;i<cut;i++) pl.milestones.push(Number(ids[i])); }
  }
  // milestone count drives almost everything
  const m=Math.floor(stage*235); p.m.points=new c.Decimal(m); p.m.best=new c.Decimal(m);
  p.m.milestones=[]; for(let i=0;i<Math.min(m,c.layers.m.milestones.length);i++) p.m.milestones.push(i);
  p.mm.points=new c.Decimal(Math.floor(stage*40)); p.mm.best=p.mm.points;
  p.points=new c.Decimal(mag());
  // sometimes sit inside a challenge
  if(r()<0.35){ const cl=layers.filter(l=>c.layers[l].challenges); const l=pick(cl); const ids=Object.keys(c.layers[l].challenges).filter(k=>plain(c.layers[l].challenges[k])); if(ids.length) p[l].activeChallenge=Number(pick(ids)); }
  // actions
  const acts=[];
  for(let i=0;i<12;i++){ const u=r(); const l=pick(layers); const L=c.layers[l];
    if(u<0.35) acts.push(['tick',l,pick([0.05,0.5,5,60])]);
    else if(u<0.5) acts.push(['reset',l,0]);
    else if(u<0.7 && L.upgrades){ const ids=Object.keys(L.upgrades).filter(k=>plain(L.upgrades[k])); if(ids.length) acts.push(['upg',l,Number(pick(ids))]); }
    else if(u<0.85 && L.buyables){ const ids=Object.keys(L.buyables).filter(k=>plain(L.buyables[k])); if(ids.length) acts.push(['buy',l,Number(pick(ids))]); }
    else if(u<0.92 && L.challenges){ const ids=Object.keys(L.challenges).filter(k=>plain(L.challenges[k])); if(ids.length) acts.push(['chal',l,Number(pick(ids))]); }
    else if(L.clickables){ const ids=Object.keys(L.clickables).filter(k=>plain(L.clickables[k])); if(ids.length) acts.push(['click',l,Number(pick(ids))]); }
  }
  acts.push(['tick','m',1]);
  return {p, acts, stage};
}
for(let n=0;n<N;n++){ const st=makeState(n, r()); states.push({seed: 1000+n, save: JSON.stringify(st.p), acts: st.acts, stage: st.stage}); }
// inside the Prestige Multiverse: the rift's layers (pm, pep, cp, cm, ex) shown, cp's hard drives filled in. Entering
// resets the tree's layers, so these start from a new game with moderate numbers (random extremes there can send the
// game's own loops spinning).
const D=x=>new c.Decimal(x);
const ten=(a,b)=>D(Math.pow(10,a+r()*(b-a)));
for(let k=0;k<MV;k++){
  const p=c.getStartPlayer();
  const mb=185+Math.floor(r()*51); p.m.points=D(mb); p.m.best=D(mb);
  p.m.milestones=[]; for(let i=0;i<Math.min(mb,c.layers.m.milestones.length);i++) p.m.milestones.push(i);
  p.mm.points=D(30+Math.floor(r()*10)); p.mm.best=p.mm.points; p.em.best=D(Math.floor(r()*20));
  p.points=ten(0,20);
  p.mp.unlocked=true; p.mp.activeChallenge=21; p.mp.points=ten(0,6); p.mp.best=p.mp.points;
  for(const id of ['11','12','13','21','22']) p.mp.buyables[id]=D(Math.floor(r()*5));
  const pb=10+Math.floor(r()*31); p.pm.unlocked=true; p.pm.points=D(pb); p.pm.best=D(pb); p.pm.essence=ten(0,30);
  p.pep.unlocked=true; p.pep.points=ten(0,10); p.pep.best=p.pep.points.max(5); p.pep.buyables[11]=D(Math.floor(r()*4));
  p.m.pseudoBuys=['9']; for(const id of ['4','14','15']) if(r()<0.5) p.m.pseudoBuys.push(id);
  p.ex.unlocked=true; p.ex.zone='a'; p.ex.points=D(Math.floor(r()*4)); p.ex.best=p.ex.points; p.ex.total=p.ex.points;   // the grid is drawn cell by cell up to a size from ex points
  p.ex.buyables[11]=D(Math.floor(r()*4)); p.ex.buyables[12]=D(Math.floor(r()*4)); p.ex.buyables[13]=D(0); p.ex.buyables[14]=D(0);
  p.cp.unlocked=true; p.cp.points=ten(0,3); p.cp.best=p.cp.points; p.cp.formatted=ten(0,3); p.cp.totalCorrupt=Math.floor(r()*20);
  p.cm.unlocked=r()<0.5; p.cm.points=D(Math.floor(r()*4)); p.cm.best=p.cm.points;
  const lit=[];
  for(const id in p.cp.grid){ const lv=r()<0.4?0:1+Math.floor(r()*8); p.cp.grid[id]={level:lv,active:false,fixed:false,type:r()<0.5?'div':'pm',cautPower:r()<0.2?1:0}; if(lv>0&&Math.floor(+id/100)<=4&&(+id%100)<=4) lit.push(+id); }
  if(lit.length){ p.cp.grid[lit[Math.floor(r()*lit.length)]].active=true; const div=lit.filter(id=>!p.cp.grid[id].active&&p.cp.grid[id].type=='div'); if(div.length) p.cp.trojanChosen=div[Math.floor(r()*div.length)]; }
  if(r()<0.5) p.pm.activeChallenge=r()<0.5?12:13;     // trapped in the Normal Universe: the tree layers show inside
  p.tab=pick(['none','pm','pep','cp','ex']);
  // presses on the rift's layers
  const acts=[];
  for(let i=0;i<8;i++){ const u=r(); const l=pick(['mp','pm','pep','cp','cm','ex']); const L=c.layers[l];
    if(u<0.35) acts.push(['tick',l,pick([0.05,0.5,5])]);
    else if(u<0.5) acts.push(['reset',l,0]);
    else if(u<0.75 && L.upgrades){ const ids=Object.keys(L.upgrades).filter(k=>plain(L.upgrades[k])); if(ids.length) acts.push(['upg',l,Number(pick(ids))]); }
    else if(L.buyables){ const ids=Object.keys(L.buyables).filter(k=>plain(L.buyables[k])); if(ids.length) acts.push(['buy',l,Number(pick(ids))]); }
  }
  acts.push(['tick','pm',1]);
  states.push({seed: 1000+N+k, save: JSON.stringify(p), acts, stage: 1, mv: true});
}
console.log(JSON.stringify(states));
