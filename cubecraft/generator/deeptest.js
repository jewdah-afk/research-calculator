const PG = require('./planetgen.js'), fs = require('fs'), path = require('path');
const ROOT = path.dirname(__dirname);
const names = JSON.parse(fs.readFileSync(path.join(ROOT, 'planet/world.json'))).blocks.map(b => b.name).concat(['mantle_rock','ember','cobalt','core_iron','starmetal','heartstone','core_crystal']);
const ID = {}; names.forEach((n, i) => ID[n] = i);
const g = PG.create(1234, { faceSize: 16384 });
for (const d of [100, 400, 1500, 3000, 5000, 7000, 8100, 8150]) {
  const t0 = performance.now(); const r = g.deepRegion(4, 8192 - 32, 8192 - 32, d, 64, ID); const ms = performance.now() - t0;
  const cnt = {}; for (const b of r.W) cnt[names[b]] = (cnt[names[b]] || 0) + 1;
  const tot = r.W.length, top = Object.entries(cnt).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([k, v]) => k + ' ' + (100 * v / tot).toFixed(1) + '%').join(', ');
  const c = g.conditions(d + 32);
  console.log(`depth ${d}: ${c.name}, ${Math.round(c.tempC)}°C, ${c.density.toFixed(1)} g/cm3, ${c.pressureGPa.toFixed(0)} GPa | ${ms.toFixed(0)} ms | ${top}`);
}
