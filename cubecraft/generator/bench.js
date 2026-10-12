const PG = require('./planetgen.js'), MS = require('./mesher.js');
const fs = require('fs'), path = require('path');
const ROOT = path.dirname(__dirname);
const atlas = JSON.parse(fs.readFileSync(path.join(ROOT, 'world/atlas.json')));
const blocks = JSON.parse(fs.readFileSync(path.join(ROOT, 'planet/world.json'))).blocks;
const ID = {}; blocks.forEach((b, i) => ID[b.name] = i);
const info = blocks.map(b => ({ kind: b.kind, t: atlas.index[b.top] || 0, s: atlas.index[b.side] || 0, b: atlas.index[b.bottom] || 0 }));
const mesh = MS.createMesher(info, atlas);
const F = +(process.argv[2] || 16384);
const g = PG.create(1234, { faceSize: F });
const n = F / 32;
function run(label, f, cu, cv) {
  const t0 = performance.now();
  const ch = g.chunk(f, cu, cv, ID);
  const t1 = performance.now();
  const m = mesh(ch, {});
  const t2 = performance.now();
  return { label, gen: t1 - t0, mesh: t2 - t1, tris: m.tris, dims: `${ch.SX}x${ch.SZ}x${ch.Y}`, h: `${ch.minH}..${ch.maxH}` };
}
// warm up
run('warm', 4, 10, 10);
const rows = [];
// a 6x6 patch of interior chunks somewhere with land
let best = null;
for (let u = 0; u < n; u += Math.max(1, n >> 5)) for (let v = 0; v < n; v += Math.max(1, n >> 5)) { const c = g.columnAt(4, u * 32 + 16, v * 32 + 16); if (c.h > 20 && c.h < 80 && (!best || c.h > best.h)) best = { u, v, h: c.h }; }
for (let a = 0; a < 6; a++) for (let b = 0; b < 6; b++) rows.push(run('land', 4, best.u + a, best.v + b));
const avg = (k) => (rows.reduce((s, r) => s + r[k], 0) / rows.length).toFixed(1);
console.log(`F=${F} interior land chunks x${rows.length}: gen ${avg('gen')} ms, mesh ${avg('mesh')} ms, tris ${avg('tris')}, e.g. dims ${rows[0].dims}`);
const maxT = Math.max(...rows.map(r => r.tris)); console.log('max tris in one chunk', maxT, '(EditableMesh limit 20000)');
console.log('edge chunk', JSON.stringify(run('edge', 4, n - 1, best.v)));
console.log('corner chunk', JSON.stringify(run('corner', 4, n - 1, n - 1)));
// seam check: heights of +Y face column at u=F-1 vs +X face column next to that edge
const fY = 4, fX = 1;
let worst = 0;
for (let k = 0; k < 2000; k++) {
  const v = Math.floor(Math.random() * F);
  const a = g.columnAt(fY, F - 1, v);
  const L = g.locate(...(() => { const p = [0, 0, 0]; g.basePoint(fY, F - 1 + 1, v, p); return p; })());
  const b = g.columnAt(L.f, Math.round(L.u), Math.round(L.v));
  worst = Math.max(worst, Math.abs(a.h - b.h));
}
console.log('worst height step across an edge (2000 samples):', worst.toFixed(2));
