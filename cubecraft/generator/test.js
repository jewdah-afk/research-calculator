const PG = require('./planetgen.js');
const seed = +(process.argv[2] || 1234);
const g = PG.create(seed, { faceSize: 2048 });
const counts = {}; let n = 0, hs = [];
let t0 = Date.now();
const RES = 128;
for (let f = 0; f < 6; f++) for (let i = 0; i < RES; i++) for (let j = 0; j < RES; j++) {
  const c = g.columnAt(f, (i + 0.5) * 2048 / RES, (j + 0.5) * 2048 / RES);
  counts[c.biome] = (counts[c.biome] || 0) + 1; n++; hs.push(c.h);
}
console.log('map samples ms', Date.now() - t0);
hs.sort((a, b) => a - b);
console.log('height p5/p50/p95/max', hs[(n * .05) | 0].toFixed(1), hs[(n * .5) | 0].toFixed(1), hs[(n * .95) | 0].toFixed(1), hs[n - 1].toFixed(1));
console.log(Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([k, v]) => k + ' ' + (100 * v / n).toFixed(1) + '%').join(', '));
// edge continuity: +Z (f0) right edge u=2047 vs +X (f1) left edge u=0, same v
let maxd = 0;
for (let v = 0; v < 2048; v += 16) maxd = Math.max(maxd, Math.abs(g.columnAt(0, 2047, v).h - g.columnAt(1, 0, v).h));
console.log('max height jump across +Z/+X edge', maxd.toFixed(2));
// +Y bottom edge (v=2047) vs +Z top edge (v=0)
maxd = 0;
for (let u = 0; u < 2048; u += 16) maxd = Math.max(maxd, Math.abs(g.columnAt(4, u, 2047).h - g.columnAt(0, u, 0).h));
console.log('max height jump across +Y/+Z edge', maxd.toFixed(2));
// region timing + block mix
const names = ['air','grass','dirt','stone','cobble','stone_bricks','gravel','sand','log','planks','leaves','coal','iron','gold','gem','snow_grass','water','clay','slate','birch_log','birch_leaves','spruce_log','spruce_leaves','cactus','sandstone','bricks','glass','tall_grass','flower_red','flower_yellow','snow','slate_coal','slate_iron','slate_gold','slate_gem','lava','ash'];
const ID = {}; names.forEach((k, i) => ID[k] = i);
t0 = Date.now();
const r = g.region(4, 1000, 1000, 112, ID);
console.log('region 112 ms', Date.now() - t0, 'Y', r.Y, 'h', r.minH, r.maxH);
const bc = new Array(names.length).fill(0); for (const b of r.W) bc[b]++;
const stoneish = bc[ID.stone] + bc[ID.slate] + bc[ID.coal] + bc[ID.iron] + bc[ID.gold] + bc[ID.gem] + bc[ID.slate_coal] + bc[ID.slate_iron] + bc[ID.slate_gold] + bc[ID.slate_gem];
for (const o of ['coal','iron','gold','gem']) console.log(o, ((bc[ID[o]] + bc[ID['slate_' + o]]) / stoneish * 100).toFixed(2) + '% of stone');
console.log('air underground-ish (caves) share:', bc[0], 'lava', bc[ID.lava], 'water', bc[ID.water], 'trees', bc[ID.log] + bc[ID.birch_log] + bc[ID.spruce_log]);
// find a land region with mixed biomes on +Y and test it
let best = null;
for (let u = 64; u < 1984; u += 64) for (let v = 64; v < 1984; v += 64) {
  const set = new Set(); let land = 0;
  for (let a = 0; a < 112; a += 16) for (let b = 0; b < 112; b += 16) { const c = g.columnAt(4, u + a, v + b); set.add(c.biome); if (c.h > 2) land++; }
  const score = set.size + land / 10;
  if (!best || score > best.s) best = { s: score, u, v, set: [...set] };
}
console.log('best +Y region', best.u, best.v, best.set.join(','));
t0 = Date.now();
const r2 = g.region(4, best.u, best.v, 112, ID);
console.log('land region ms', Date.now() - t0, 'Y', r2.Y, 'h', r2.minH, r2.maxH);
const bc2 = new Array(names.length).fill(0); for (const b of r2.W) bc2[b]++;
const st2 = ['stone','slate','coal','iron','gold','gem','slate_coal','slate_iron','slate_gold','slate_gem'].reduce((s, k) => s + bc2[ID[k]], 0);
for (const o of ['coal','iron','gold','gem']) console.log(o, ((bc2[ID[o]] + bc2[ID['slate_' + o]]) / st2 * 100).toFixed(2) + '%');
console.log('trees', bc2[ID.log] + bc2[ID.birch_log] + bc2[ID.spruce_log], 'cactus', bc2[ID.cactus], 'plants', bc2[ID.tall_grass] + bc2[ID.flower_red] + bc2[ID.flower_yellow], 'lava', bc2[ID.lava]);
