const PG = require('./planetgen.js');
const g = PG.create(1234, { faceSize: 2048 });
const S = 112, want = JSON.parse(process.argv[2]);
const out = {};
for (const [name, must] of Object.entries(want)) {
  let best = null;
  for (let f = 0; f < 6; f++) for (let u = 64; u < 2048 - S - 64; u += 80) for (let v = 64; v < 2048 - S - 64; v += 80) {
    const cnt = {};
    for (let a = 0; a < S; a += 14) for (let b = 0; b < S; b += 14) { const c = g.columnAt(f, u + a, v + b); cnt[c.biome] = (cnt[c.biome] || 0) + 1; }
    let score = 0; for (const m of must) score += Math.min(cnt[m] || 0, 20);
    score += Object.keys(cnt).length * 0.5;
    if (!best || score > best.s) best = { s: score, f, u, v, cnt };
  }
  out[name] = best;
}
console.log(JSON.stringify(out));
