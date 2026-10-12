const PG = require('./planetgen.js'), MS = require('./mesher.js');
const fs = require('fs'), path = require('path');
const ROOT = path.dirname(__dirname);
const atlas = JSON.parse(fs.readFileSync(path.join(ROOT, 'world/atlas.json')));
const blocks = JSON.parse(fs.readFileSync(path.join(ROOT, 'planet/world.json'))).blocks;
const ID = {}; blocks.forEach((b, i) => ID[b.name] = i);
const info = blocks.map(b => ({ kind: b.kind, t: atlas.index[b.top] || 0, s: atlas.index[b.side] || 0, b: atlas.index[b.bottom] || 0 }));
const mesh = MS.createMesher(info, atlas);
const F = 16384, g = PG.create(1234, { faceSize: F }), n = F / 32;
let best = null;
for (let u = 4; u < n - 4; u += 16) for (let v = 4; v < n - 4; v += 16) { const c = g.columnAt(4, u * 32 + 16, v * 32 + 16); if (c.h > 20 && c.h < 90 && (!best || c.h > best.h)) best = { u, v, h: c.h }; }
let gen = 0, msh = 0, surfMax = 0, allMax = 0, surfTot = 0, cnt = 0, bands = 0;
for (let a = 0; a < 8; a++) for (let b = 0; b < 8; b++) {
  const t0 = performance.now(); const ch = g.chunk(4, best.u + a, best.v + b, ID); const t1 = performance.now();
  const sLo = ch.minH - 8 - ch.ylo, sHi = ch.maxH + 16 - ch.ylo;
  for (let y0 = 0; y0 < ch.Y; y0 += 32) {
    const m = mesh(ch, {}, y0, y0 + 32); bands++;
    allMax = Math.max(allMax, m.tris);
    if (y0 + 32 > sLo && y0 < sHi) { surfMax = Math.max(surfMax, m.tris); surfTot += m.tris; }
  }
  const t2 = performance.now(); gen += t1 - t0; msh += t2 - t1; cnt++;
}
console.log(`64 land chunks on a 16,384 planet: gen ${(gen / cnt).toFixed(1)} ms, mesh all bands ${(msh / cnt).toFixed(1)} ms per 32x32 column`);
console.log(`32x32x32 sub-chunk tris: max ${allMax} (limit 20000); surface bands avg per column ${(surfTot / cnt).toFixed(0)}, max sub-chunk ${surfMax}`);
