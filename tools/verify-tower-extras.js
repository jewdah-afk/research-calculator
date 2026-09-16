#!/usr/bin/env node
/**
 * verify-tower-extras.js — checks data/tower-extras.js against its sources.
 * Usage: node tools/verify-tower-extras.js <tower-smith checkout> <unified-tools checkout>
 *
 * Same conventions as verify-tower-data.js: [exact] means byte-identical to the
 * source table. The vault block is deliberately NOT checked against a GOD table
 * because upstream has none — it is screenshot-transcribed, and we only assert
 * its internal consistency (the cumulative `total` chain along each parent path).
 */
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const TS = process.argv[2], UT = process.argv[3];
if (!TS || !UT) { console.error('usage: verify-tower-extras.js <tower-smith> <unified-tools>'); process.exit(1); }
const read = f => JSON.parse(fs.readFileSync(f, 'utf8'));

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'data', 'tower-extras.js'), 'utf8'), ctx);
const X = vm.runInContext('TOWER_EXTRAS', ctx);

let checks = 0, fails = 0;
function ok(name, got, want, relTol) {
  checks++;
  const d = Math.abs(got - want), rel = want ? d / Math.abs(want) : d;
  if (d === 0 || rel <= (relTol || 0)) return;
  fails++;
  console.log('  FAIL', name, '\n        got ', got, '\n        want', want);
}
function eq(name, got, want) {
  checks++;
  if (JSON.stringify(got) === JSON.stringify(want)) return;
  fails++;
  console.log('  FAIL', name, '\n        got ', JSON.stringify(got), '\n        want', JSON.stringify(want));
}

/* [exact] enhancements */
console.log('[exact] workshop enhancements: 18 stats, cost + value');
const enhBase = path.join(TS, 'tables/workshop/enhancements');
for (const cat of fs.readdirSync(enhBase)) {
  for (const file of fs.readdirSync(path.join(enhBase, cat))) {
    const j = read(path.join(enhBase, cat, file));
    const s = X.enhancements[cat + '/' + file.replace(/\.json$/, '')];
    ok(file + ' maxLevel', s.max, j.maxLevel);
    for (let L = 0; L < j.maxLevel; L++) ok(file + ' cost[' + L + ']', s.cost[L], j.levels[L].nextCoins.coins);
    for (let L = 0; L <= j.maxLevel; L++) ok(file + ' val[' + L + ']', s.val[L], j.levels[L].value, 1e-5);
  }
}

/* [exact] in-run cash */
console.log('[exact] in-run cash curves, 48 stats');
for (const cat of ['attack', 'defense', 'utility']) {
  for (const file of fs.readdirSync(path.join(TS, 'tables/workshop', cat))) {
    const j = read(path.join(TS, 'tables/workshop', cat, file));
    const key = file.replace(/\.json$/, ''), arr = X.cash[key];
    if (!arr) continue;
    for (let L = 0; L < j.maxLevel; L++) ok(key + ' cash[' + L + ']', arr[L], j.levels[L].nextCash.cash);
  }
}

/* [exact] guardians */
console.log('[exact] guardian chips + slot costs');
for (const file of fs.readdirSync(path.join(TS, 'tables/guardians/chips'))) {
  const j = read(path.join(TS, 'tables/guardians/chips', file));
  const c = X.guardians.chips[j.chipId];
  for (const [tk, t] of Object.entries(j.tracks || {})) {
    ok(j.chipId + '/' + tk + ' max', c.tracks[tk].max, t.maxLevel);
    for (let i = 0; i < t.levels.length; i++)
      ok(j.chipId + '/' + tk + ' total[' + i + ']', c.tracks[tk].total[i], t.levels[i].totalCost || 0);
  }
}
eq('guardian slot costs', X.guardians.slots,
   read(path.join(TS, 'tables/guardians/slot-unlock-costs.json')).slots);

/* [exact] UW / bots / cards against the unified-tools consts */
console.log('[exact] UW stones, bots, cards');
function utConst(file, name) {
  const c = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(UT, 'The Tower Tool', 'js', file), 'utf8'), c);
  return vm.runInContext(name, c);
}
eq('UW unlock costs', X.uw.unlockCosts, utConst('uw-stone-calc.js', 'UW_UNLOCK_COSTS'));
eq('UW plus unlock costs', X.uw.plusUnlockCosts, utConst('uw-stone-calc.js', 'UW_PLUS_UNLOCK_COSTS'));
eq('UW order', X.uw.order, utConst('uw-stone-calc.js', 'UW_ORDER'));
eq('UW data', X.uw.data, utConst('uw-stone-calc.js', 'UW_DATA'));
const TMB = utConst('tower-module-bot-data.js', 'TMB_DATA');
eq('module level rows', X.modulesBots.modules.levelRows, TMB.levelWikiRows);
eq('module rarity maxLevel', X.modulesBots.modules.rarityMaxLevel, TMB.rarity.maxLevel);
eq('bot order', X.modulesBots.bots.order, TMB.bots.order);
eq('card slot gem costs', X.cards.slotGemCosts, utConst('tower-game-data.js', 'CARD_DATA').slotGemCosts);

/* [published] cross-checks against the figures the wikis publish */
console.log('[published] wiki-published ladders');
eq('UW purchase ladder', X.uw.unlockCosts, [5, 50, 150, 300, 800, 1250, 1750, 2400, 3000]);
// bots: 100 medals at level 1, +40/level, 9,600 cumulative to level 20
const bm = l => X.modulesBots.bots.costModel.base + X.modulesBots.bots.costModel.step * l;
ok('bot level 1 medals', bm(1), 100);
ok('bot level 20 medals', bm(20), 860);
let botTotal = 0; for (let l = 1; l <= 20; l++) botTotal += bm(l);
ok('bot cumulative to 20', botTotal, 9600);
// card slots: 21 purchasable slots beyond the first, 48,400 gems
const slots = X.cards.slotGemCosts;
ok('card slots 2..21 gem total', slots.slice(0, 21).reduce((a, b) => a + b, 0), 48400);

/* [internal] vault — no GOD table upstream, so check its own cumulative chain */
console.log('[internal] vault cumulative key chain (no GOD table upstream)');
const byId = new Map(X.vault.nodes.map(n => [n.id, n]));
let chainChecked = 0;
for (const n of X.vault.nodes) {
  if (n.total === null) continue;
  let sum = 0, cur = n, guard = 0;
  while (cur && guard++ < 200) { sum += cur.keyCost; cur = cur.parent ? byId.get(cur.parent) : null; }
  ok('vault ' + n.id + ' total', sum, n.total);
  chainChecked++;
}
eq('vault tier cost multiplier', X.vault.tierCostMultiplier, [0, 1, 2, 4]);
console.log('        (' + chainChecked + ' nodes had a published cumulative to check)');

console.log('\n' + (checks - fails) + '/' + checks + ' checks passed');
process.exit(fails ? 1 : 0);
