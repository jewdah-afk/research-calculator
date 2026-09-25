// Builds random but plausible game states (saves) + action scripts, from the game's own layer definitions.
// usage: node gen_states.js N seed > states.json
const G=require('./jsgame')();const c=G.ctx;
const N=+process.argv[2]||50; let s=+process.argv[3]||1;
const r=()=>{s=(s*16807)%2147483647;return (s-1)/2147483646};
const pick=a=>a[Math.floor(r()*a.length)];
const plain=o=>c.isPlainObject(o);
const layers=Object.keys(c.layers).filter(l=>!l.endsWith('-tab')&&l!=='ach'||l==='ach');
const states=[];
for(let n=0;n<N;n++){
  const stage=r();                       // 0 = start of game, 1 = end
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
  states.push({seed: 1000+n, save: JSON.stringify(p), acts, stage});
}
console.log(JSON.stringify(states));
