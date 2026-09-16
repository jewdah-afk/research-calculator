#!/usr/bin/env node
/**
 * build-tower-extras.js — regenerates data/tower-extras.js: every upgrade system
 * that build-tower-data.js does not already cover.
 *
 * Usage: node tools/build-tower-extras.js <tower-smith checkout> <unified-tools checkout>
 *
 * Sources, per block (see research/THE-TOWER-SOURCES.md):
 *   enhancements  tower-smith/tables/workshop/enhancements/  (GOD tables, exact)
 *   cash          tower-smith/tables/workshop/{cat}/*.json   (the nextCash column
 *                 we dropped from the coin build — the in-run battle upgrades)
 *   guardians     tower-smith/tables/guardians/              (GOD tables, exact)
 *   vault         tower-smith/src/data/vaultTrees.ts         (transcribed from
 *                 screenshots upstream — NOT GOD data, flagged `sourced:"weak"`)
 *   uw            unified-tools js/uw-stone-calc.js          (stone costs)
 *   modules/bots  unified-tools js/tower-module-bot-data.js
 *   cards         unified-tools js/tower-game-data.js
 *   labValues     unified-tools js/lab-values.js — per-level lab EFFECT sizes.
 *                 Note the GOD lab tables give exact cost and time but their
 *                 `value` column is only the level index, so effect magnitudes
 *                 have to come from the wiki's Value column. That is a Tier C
 *                 source, so this block is tagged sourced:"wiki" and covers 161
 *                 of 217 labs — the rest have no published effect curve.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const TS = process.argv[2], UT = process.argv[3];
if (!TS || !UT) {
  console.error('usage: build-tower-extras.js <tower-smith checkout> <unified-tools checkout>');
  process.exit(1);
}
const read = f => JSON.parse(fs.readFileSync(f, 'utf8'));
const UTJS = p => path.join(UT, 'The Tower Tool', 'js', p);

// Pull named consts out of one of the unified-tools data files by running it.
function utConsts(file, names) {
  const ctx = vm.createContext({});
  vm.runInContext(fs.readFileSync(UTJS(file), 'utf8'), ctx, { filename: file });
  const out = {};
  for (const n of names) {
    try { out[n] = vm.runInContext(n, ctx); }
    catch (e) { throw new Error(file + ' has no const ' + n); }
  }
  return out;
}

const trim = x => (typeof x !== 'number' || !isFinite(x) || Number.isInteger(x))
  ? x : Number(x.toPrecision(6));

/* ── Workshop Enhancements: 18 stats, exact cost + value ─────────────── */
function enhancements() {
  const out = {};
  const base = path.join(TS, 'tables/workshop/enhancements');
  for (const cat of fs.readdirSync(base)) {
    for (const file of fs.readdirSync(path.join(base, cat))) {
      const j = read(path.join(base, cat, file));
      out[cat + '/' + file.replace(/\.json$/, '')] = {
        n: j.name,
        c: cat,
        max: j.maxLevel,
        cost: j.levels.map(l => (l.nextCoins ? l.nextCoins.coins : 0)).slice(0, j.maxLevel),
        val: j.levels.map(l => trim(l.value))
      };
    }
  }
  return out;
}

/* ── In-run cash cost per workshop stat ──────────────────────────────── */
function cash() {
  const out = {};
  for (const cat of ['attack', 'defense', 'utility']) {
    for (const file of fs.readdirSync(path.join(TS, 'tables/workshop', cat))) {
      const j = read(path.join(TS, 'tables/workshop', cat, file));
      const arr = j.levels.map(l => (l.nextCash ? l.nextCash.cash : 0)).slice(0, j.maxLevel);
      if (arr.some(x => x > 0)) out[file.replace(/\.json$/, '')] = arr;
    }
  }
  return out;
}

/* ── Guardians: chip tracks + slot unlock costs ──────────────────────── */
function guardians() {
  const chips = {};
  const dir = path.join(TS, 'tables/guardians/chips');
  for (const file of fs.readdirSync(dir)) {
    const j = read(path.join(dir, file));
    const tracks = {};
    for (const [tk, t] of Object.entries(j.tracks || {})) {
      tracks[tk] = {
        max: t.maxLevel,
        // stored as cumulative totalCost upstream; keep both views
        total: t.levels.map(l => l.totalCost || 0),
        val: t.levels.map(l => trim(l.value))
      };
    }
    chips[j.chipId] = { n: j.name, tracks: tracks };
  }
  return { chips: chips, slots: read(path.join(TS, 'tables/guardians/slot-unlock-costs.json')).slots };
}

/* ── Vault: Power + Harmony trees (weakly sourced, see header) ───────── */
// vaultTrees.ts is TypeScript with no runtime imports, so we strip the types in
// a child node process (--experimental-strip-types) and read the JSON back.
function vault() {
  const os = require('os'), cp = require('child_process');
  const tmp = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'vault-')), 'vaultTrees.ts');
  fs.writeFileSync(tmp, fs.readFileSync(path.join(TS, 'src/data/vaultTrees.ts'), 'utf8')
    .replace(/^import type .*$/m, 'type StringId = string;'));

  const script =
    'import(process.argv[1]).then(m => process.stdout.write(JSON.stringify({' +
    'nodes: m.VAULT_NODES, mult: m.VAULT_TIER_COST_MULTIPLIER,' +
    't2: m.VAULT_TIER2_REQ_T1, t3a: m.VAULT_TIER3_REQ_T1, t3b: m.VAULT_TIER3_REQ_T2})))';
  const res = cp.execFileSync(process.execPath,
    ['--experimental-strip-types', '--no-warnings', '-e', script, tmp],
    { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  fs.rmSync(path.dirname(tmp), { recursive: true, force: true });
  const m = JSON.parse(res);

  return {
    sourced: 'weak',
    note: 'Transcribed upstream from in-game screenshots + community tables, not GOD data.',
    tierCostMultiplier: m.mult,
    tier2ReqT1: m.t2, tier3ReqT1: m.t3a, tier3ReqT2: m.t3b,
    nodes: m.nodes.map(n => ({
      id: n.id, tree: n.tree, column: n.column, order: n.order, icon: n.iconId,
      label: n.valueLabel, keyCost: n.keyCost, total: n.total, parent: n.parentId,
      oneLevelOnly: !!n.oneLevelOnly, kind: n.kind, tierGate: n.tierGate || null
    }))
  };
}

/* ── Ultimate Weapons: stone costs ───────────────────────────────────── */
function uw() {
  const c = utConsts('uw-stone-calc.js',
    ['UW_DATA', 'UW_VALS', 'UW_ORDER', 'UW_UNLOCK_COSTS', 'UW_PLUS_UNLOCK_COSTS']);
  return {
    order: c.UW_ORDER,
    // stones to own your Nth ultimate weapon, by purchase count
    unlockCosts: c.UW_UNLOCK_COSTS,
    plusUnlockCosts: c.UW_PLUS_UNLOCK_COSTS,
    // per weapon: upgrades[stat][level] = cumulative stones at that level
    data: c.UW_DATA,
    vals: c.UW_VALS
  };
}

/* ── Modules + Bots ──────────────────────────────────────────────────── */
function modulesBots() {
  const { TMB_DATA: T } = utConsts('tower-module-bot-data.js', ['TMB_DATA']);
  return {
    modules: {
      levelRows: T.levelWikiRows,        // marginal/total shards + coins by level
      rarityMaxLevel: T.rarity.maxLevel,
      rarityLabel: T.rarity.label,
      chassis: T.chassis,
      effectCount: T.GAME_MODULE_EFFECT_COUNT,
      idByInfoIndex: T.moduleInfoIndexToId,
      effects: T.effectResolved
    },
    bots: {
      order: T.bots.order,
      upgradeOrder: T.bots.upgradeOrder,
      // medals for bot level n, linear: 60 + 40n (100 at level 1)
      costModel: { base: 60, step: 40, formula: '60 + 40*level' },
      specialUnlockStones: T.bots.specialUnlockStones,
      specialByBot: T.bots.specialByBot
    }
  };
}

/* ── Lab effect magnitudes (wiki-sourced, weaker than the GOD tables) ─── */
function labValues() {
  const { LAB_VALUES: V } = utConsts('lab-values.js', ['LAB_VALUES']);
  const out = {};
  for (const [name, arr] of Object.entries(V)) {
    // Entries look like "1.02", "0.50%", "$100", "-1%", "19.00" or "Unlocked".
    let unit = 'num';
    const nums = arr.map(raw => {
      const s = String(raw).trim();
      if (/^unlocked$/i.test(s)) { unit = 'flag'; return 1; }
      if (s.endsWith('%')) unit = 'pct';
      else if (s.startsWith('$')) unit = 'cash';
      const n = parseFloat(s.replace(/[$,%\s]/g, ''));
      return isFinite(n) ? n : null;
    });
    out[name] = { unit: unit, v: nums };
  }
  return { sourced: 'wiki', note: 'Per-level lab effect sizes from the vault-net wiki Value column, not GOD data.', labs: out };
}

/* ── Cards ───────────────────────────────────────────────────────────── */
function cards() {
  const { CARD_DATA: C } = utConsts('tower-game-data.js', ['CARD_DATA']);
  return { order: C.order, maxStars: C.maxStars, slotGemCosts: C.slotGemCosts, cards: C.cards };
}

const data = {
  generated: new Date().toISOString().slice(0, 10),
  enhancements: enhancements(),
  cash: cash(),
  guardians: guardians(),
  vault: vault(),
  uw: uw(),
  modulesBots: modulesBots(),
  cards: cards(),
  labValues: labValues()
};

const dest = path.join(__dirname, '..', 'data', 'tower-extras.js');
fs.writeFileSync(dest,
  '// GENERATED by tools/build-tower-extras.js — do not hand-edit.\n' +
  '// Sources: TowerSmith GOD tables + The Tower Unified Tools (both CC BY-NC-SA 4.0).\n' +
  '// The `vault` block is marked sourced:"weak" — transcribed from screenshots upstream.\n' +
  'const TOWER_EXTRAS = ' + JSON.stringify(data) + ';\n');

console.log('wrote', dest, (fs.statSync(dest).size / 1024).toFixed(0) + 'KB');
console.log('  enhancements:', Object.keys(data.enhancements).length, 'stats,',
  Object.values(data.enhancements).reduce((a, s) => a + s.max, 0), 'levels');
console.log('  cash curves :', Object.keys(data.cash).length, 'stats');
console.log('  guardians   :', Object.keys(data.guardians.chips).length, 'chips');
console.log('  vault nodes :', data.vault.nodes.length, '(weakly sourced)');
console.log('  uw          :', data.uw.order.length, 'weapons');
console.log('  bots        :', data.modulesBots.bots.order.length);
console.log('  cards       :', data.cards.cards.length);
console.log('  lab effects :', Object.keys(data.labValues.labs).length, 'labs (wiki-sourced)');
