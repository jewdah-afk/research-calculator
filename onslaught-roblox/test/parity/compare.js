// node compare.js js.jsonl lua.jsonl : first divergence per scenario
const fs = require("fs");
const load = f => fs.readFileSync(f, "utf8").trim().split("\n").filter(Boolean).map(l => JSON.parse(l));
const A = load(process.argv[2]), B = load(process.argv[3]);
const norm = v => (Array.isArray(v) && v.length === 0) ? {} : v;
function eq(a, b) {
  a = norm(a); b = norm(b);
  if (typeof a === "number" && typeof b === "number") return a === b;
  if (typeof a !== "object" || a === null) return a === b;
  const ks = new Set([...Object.keys(a), ...Object.keys(b || {})]);
  for (const k of ks) if (!eq(a[k], (b || {})[k])) return false;
  return true;
}
const by = L => { const m = {}; for (const r of L) (m[r.sc] = m[r.sc] || []).push(r); return m; };
const a = by(A), b = by(B);
let bad = 0;
for (const sc of Object.keys(a)) {
  const x = a[sc], y = b[sc] || [];
  let i = 0;
  for (; i < Math.min(x.length, y.length); i++) if (!eq(x[i], y[i])) break;
  if (i === x.length && x.length === y.length) { console.log("OK  ", sc.padEnd(24), x.length, "checkpoints, end", JSON.stringify({ t: x[i - 1].t, w: x[i - 1].w, k: x[i - 1].k })); continue; }
  bad++;
  console.log("DIFF", sc, "at checkpoint", i, "of", x.length, "/", y.length);
  if (i > 0) console.log("  prev js ", JSON.stringify(x[i - 1]));
  console.log("  js ", JSON.stringify(x[i])); console.log("  lua", JSON.stringify(y[i]));
}
process.exit(bad ? 1 : 0);
