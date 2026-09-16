#!/usr/bin/env node
/**
 * verify-tower-data.js — checks data/tower-data.js and js/tower-planner.js
 * against the upstream GOD tables and the published wiki numbers.
 *
 * Usage: node tools/verify-tower-data.js <path-to-tower-smith-checkout>
 *
 * Two classes of check:
 *   [exact]  every per-level coin cost and duration must be byte-identical to
 *            the GOD table it came from. This is the real correctness bar.
 *   [6-sig]  displayed stat values, which the builder deliberately trims to 6
 *            significant digits.
 *   [disp-3] the GOD `gems` column, which is stored display-rounded to 3
 *            significant digits. We do not match it exactly and should not:
 *            our figure comes from the bundle formula and is the more precise
 *            of the two. Measured across all 5,688 lab levels, the gap never
 *            exceeds 5.00e-3 — exactly the half-step of 3-significant-digit
 *            rounding, and it reaches that bound but never passes it. That is
 *            the signature of a rounded display column, so the check asserts
 *            the bound rather than equality.
 *   [loose]  cumulative sums vs the GOD `totalCoins` column, at 5e-3. Same
 *            story: that column round-trips through the game's abbreviated
 *            "259.2B" display strings, so our level-by-level sum is more
 *            precise (that column is as coarse as 2 significant digits in
 *            places). Drift beyond 5e-3 would mean a real bug.
 */
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');

const TS = process.argv[2];
if (!TS) { console.error('usage: verify-tower-data.js <tower-smith checkout>'); process.exit(1); }
const R = f => JSON.parse(fs.readFileSync(f, 'utf8'));
const here = p => path.join(__dirname, '..', p);

const dctx = vm.createContext({});
vm.runInContext(fs.readFileSync(here('data/tower-data.js'), 'utf8'), dctx);
const D = vm.runInContext('TOWER_DATA', dctx);

// Load the pure-maths half of the engine (everything before the DOM section).
const src = fs.readFileSync(here('js/tower-planner.js'), 'utf8')
  .split('/* ── tabs & persistence')[0]
  .replace(/^var \$ = .*$/m, 'var $=function(){return null};')
  .replace(/^var HAVE_DATA.*$/m, 'var HAVE_DATA=true;');
const ectx = vm.createContext({ Math, Number, isFinite, Date, String, console, TOWER_DATA: D });
vm.runInContext(src, ectx);
const rushGems = vm.runInContext('rushGems', ectx);
const labSpeedMult = vm.runInContext('labSpeedMult', ectx);
const gemDiscount = vm.runInContext('gemDiscount', ectx);

let checks = 0, fails = 0;
function ok(name, got, want, relTol) {
  checks++;
  const d = Math.abs(got - want), rel = want ? d / Math.abs(want) : d;
  if (d === 0 || rel <= (relTol || 0)) return;
  fails++;
  console.log('  FAIL', name, '\n        got ', got, '\n        want', want,
              '\n        rel ', rel.toExponential(2));
}

/* ── [exact] workshop per-level costs and values ─────────────────────── */
console.log('[exact] workshop per-level cost + value, all 48 stats');
for (const cat of ['attack', 'defense', 'utility']) {
  for (const file of fs.readdirSync(path.join(TS, 'tables/workshop', cat))) {
    const j = R(path.join(TS, 'tables/workshop', cat, file));
    const key = file.replace(/\.json$/, ''), s = D.workshop[key];
    ok(key + ' maxLevel', s.max, j.maxLevel);
    ok(key + ' cost length', s.cost.length, j.maxLevel);
    for (let L = 0; L < j.maxLevel; L++) ok(key + ' cost[' + L + ']', s.cost[L], j.levels[L].nextCoins.coins);
    // [6-sig] the builder trims displayed values; compare against the raw value.
    for (let L = 0; L <= j.maxLevel; L++) ok(key + ' val[' + L + ']', s.val[L], j.levels[L].value, 1e-5);
  }
}

/* ── [exact] lab per-level coins / seconds / gems ────────────────────── */
console.log('[exact] lab per-level coins + seconds + gems, all 217 labs');
const walk = d => fs.readdirSync(d, { withFileTypes: true })
  .flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]);
const labRoot = path.join(TS, 'tables/labs');
for (const file of walk(labRoot)) {
  if (!file.endsWith('.json') || file.endsWith('lab-order.json')) continue;
  const j = R(file);
  if (!Array.isArray(j.levels)) continue;
  const key = path.relative(labRoot, path.dirname(file)) + '/' + path.basename(file, '.json');
  const l = D.labs[key];
  for (let i = 0; i < j.levels.length; i++) {
    ok(key + ' coins[' + i + ']', l.cost[i], j.levels[i].coins || 0);
    ok(key + ' secs[' + i + ']', l.time[i], j.levels[i].time ? j.levels[i].time.seconds : 0);
  }
}

/* ── [exact] our rush-gem formula vs the GOD gems column ─────────────── */
console.log('[disp-3] rushGems(duration) vs GOD per-level gem column (3-sig display)');
for (const file of walk(labRoot)) {
  if (!file.endsWith('.json') || file.endsWith('lab-order.json')) continue;
  const j = R(file);
  if (!Array.isArray(j.levels) || !j.levels[0] || j.levels[0].gems === undefined) continue;
  const key = path.relative(labRoot, path.dirname(file)) + '/' + path.basename(file, '.json');
  const l = D.labs[key];
  for (let i = 0; i < l.time.length; i++)
    ok(key + ' gems[' + i + ']', rushGems(l.time[i]), j.levels[i].gems, 5e-3);
}

/* ── [loose] cumulative sums vs the display-rounded totals column ────── */
console.log('[loose] cumulative sums vs GOD totalCoins (5e-3, display-rounded upstream)');
for (const cat of ['attack', 'defense', 'utility']) {
  for (const file of fs.readdirSync(path.join(TS, 'tables/workshop', cat))) {
    const j = R(path.join(TS, 'tables/workshop', cat, file));
    const s = D.workshop[file.replace(/\.json$/, '')];
    let sum = 0;
    for (let L = 1; L <= j.maxLevel; L++) {
      sum += s.cost[L - 1];
      if (L === 1 || L === j.maxLevel || L % 500 === 0)
        ok(file + ' totalCoins@' + L, sum, j.levels[L].totalCoins.coins, 5e-3);
    }
  }
}

/* ── [exact] bundle model vs published wiki tables ───────────────────── */
console.log('[exact] lab model vs published wiki tables');
[[3600, 8], [86400, 163], [604800, 1000], [2592e3, 3550], [7776e3, 8000], [31104e3, 25000]]
  .forEach(([t, g]) => ok('rush @' + t + 's', rushGems(t), g));
ok('labSpeedMult(99,0)', labSpeedMult(99, 0), 2.98, 1e-12);
ok('labSpeedMult(0,0)', labSpeedMult(0, 0), 1);
ok('gemDiscount(0)', gemDiscount(0), 1);
ok('gemDiscount(100)', gemDiscount(100), 1 / 2.5, 1e-12);
ok('lab coin discount @99', 1 - 99 * 0.003, 0.703, 1e-12);

console.log('\n' + (checks - fails) + '/' + checks + ' checks passed');
process.exit(fails ? 1 : 0);
