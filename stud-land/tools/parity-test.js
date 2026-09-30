// Parity test: runs the original Upgrade Land page and the Stud Land engine side by side in
// headless Chromium with a seeded Math.random and a fake clock, applies the same actions to
// both, and compares every currency and every level exactly after every step.
//
// Usage:  NODE_PATH=$(npm root -g) node tools/parity-test.js <path to original upgtree index.html>
const path = require('path');
const { chromium } = require('playwright');

const ORIGINAL = path.resolve(process.argv[2] || '../upgtree/index.html');
const OURS = path.resolve(__dirname, 'parity.html');

// Seeded RNG + fake clock + frozen frame loop, installed before any page script runs.
const INIT = (seed) => `
  (function(){
    let s = ${seed} >>> 0;
    window.__reseed = (v) => { s = v >>> 0; };
    Math.random = function(){ s |= 0; s = s + 0x6D2B79F5 | 0; let t = Math.imul(s ^ s >>> 15, 1 | s);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
    window.__t = 0;
    const realNow = performance.now.bind(performance);
    performance.now = () => window.__t;
    window.requestAnimationFrame = () => 0;
    window.cancelAnimationFrame = () => {};
    window.setInterval = () => 0;
    try { localStorage.clear(); } catch(e) {}
  })();`;

async function openOriginal(browser, seed) {
  const page = await browser.newPage();
  await page.route(/cdn\.tailwindcss\.com/, r => r.fulfill({ status: 200, contentType: 'text/javascript', body: '' }));
  await page.route(/unpkg\.com\/lucide/, r => r.fulfill({ status: 200, contentType: 'text/javascript', body: 'window.lucide={createIcons(){}};' }));
  await page.addInitScript(INIT(seed));
  await page.goto('file://' + ORIGINAL);
  await page.waitForFunction(() => typeof tickGame === 'function' && typeof TREE_NODES !== 'undefined');
  // The original redraws its currency bar inside executeReset and addCurrencyToOrder. Drawing the
  // bar evaluates gain formulas, so it pulls extra Math.random values (copper, alpha crits,
  // customers...) in an order that depends on the UI. The odds are unchanged, but the random
  // stream shifts, so the harness turns the bar off to compare the math draw for draw.
  await page.evaluate(() => { renderCurrencyBar = function () {}; });
  return page;
}
async function openOurs(browser, seed) {
  const page = await browser.newPage();
  await page.addInitScript(INIT(seed));
  await page.goto('file://' + OURS);
  await page.waitForFunction(() => window.__engineReady === true);
  return page;
}

// The same action script runs in both pages. `isOriginal` only changes how the tick is called.
const STEP = (isOriginal) => `(function(args){
  const { ticks, buyEvery, resetEvery, mode } = args;
  buyMode = mode;
  for (let i = 0; i < ticks; i++) {
    window.__t += 100;
    ${isOriginal ? 'tickGame(100);' : 'tickGame(100, window.__t);'}
    if (i % buyEvery === 0) {
      for (const n of TREE_NODES) { if (n.type === 'upgrade' && isNodeUnlocked(n)) buyUpgrade(n.id); }
    }
    if (resetEvery && i % resetEvery === resetEvery - 1) {
      for (const n of TREE_NODES) { if (n.type === 'reset' && isNodeUnlocked(n) && getEffectiveResetGain(n) > 0) executeReset(n); }
    }
  }
  return JSON.stringify({ c: gameState.currencies, l: gameState.levels, d: gameState.discoveredCurrencies });
})`;

// Put both games in the same advanced state: every node at a seeded level, every currency seeded.
const SEED_STATE = `(function(seed){
  let s = seed >>> 0; const r = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
  gameState.levels = {};
  for (const n of TREE_NODES) {
    if (n.type !== 'upgrade') continue;
    const cap = Math.min(n.maxLevel || 1, 60);
    gameState.levels[n.id] = r() < 0.85 ? Math.max(1, Math.floor(r() * cap) + 1) : 0;
  }
  for (const k of Object.keys(CURRENCIES)) gameState.currencies[k] = Math.pow(10, r() * 40);
  gameState.discoveredCurrencies = Object.keys(CURRENCIES);
  gameState.currencyOrder = Object.keys(CURRENCIES);
  clearCaches(true);
  return true;
})`;

function diff(a, b, where) {
  const A = JSON.parse(a), B = JSON.parse(b);
  const out = [];
  for (const sec of ['c', 'l']) {
    const keys = new Set([...Object.keys(A[sec]), ...Object.keys(B[sec])]);
    for (const k of keys) {
      const x = A[sec][k] ?? 0, y = B[sec][k] ?? 0;
      const same = (x === y) || (Number.isNaN(x) && Number.isNaN(y));
      if (!same) out.push(`${where} ${sec === 'c' ? 'currency' : 'level'} ${k}: original=${x} ours=${y}`);
    }
  }
  return out;
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const scenarios = [
    { name: 'fresh start, x1 buys', seed: 1, fromSeedState: false, rounds: 60, ticks: 50, buyEvery: 5, resetEvery: 0, mode: 1 },
    { name: 'fresh start, MAX buys + resets', seed: 2, fromSeedState: false, rounds: 60, ticks: 50, buyEvery: 3, resetEvery: 40, mode: 'MAX' },
    { name: 'late game state A', seed: 7, fromSeedState: true, rounds: 40, ticks: 10, buyEvery: 2, resetEvery: 7, mode: 'MAX' },
    { name: 'late game state B', seed: 99, fromSeedState: true, rounds: 40, ticks: 10, buyEvery: 3, resetEvery: 0, mode: 10 },
    { name: 'late game state C', seed: 2026, fromSeedState: true, rounds: 40, ticks: 10, buyEvery: 1, resetEvery: 5, mode: 5 },
  ];
  let failures = 0;
  for (const sc of scenarios) {
    const o = await openOriginal(browser, sc.seed);
    const u = await openOurs(browser, sc.seed);
    if (sc.fromSeedState) { await o.evaluate(`${SEED_STATE}(${sc.seed})`); await u.evaluate(`${SEED_STATE}(${sc.seed})`); }
    // The original page draws random background stars and news on load; reseed so both
    // games start the action script from the same point in the random sequence.
    await o.evaluate(`window.__reseed(${sc.seed * 7919})`); await u.evaluate(`window.__reseed(${sc.seed * 7919})`);
    let bad = [];
    for (let r = 0; r < sc.rounds && bad.length === 0; r++) {
      const args = JSON.stringify({ ticks: sc.ticks, buyEvery: sc.buyEvery, resetEvery: sc.resetEvery, mode: sc.mode });
      const a = await o.evaluate(`${STEP(true)}(${args})`);
      const b = await u.evaluate(`${STEP(false)}(${args})`);
      bad = diff(a, b, `round ${r + 1}`);
    }
    const final = JSON.parse(await u.evaluate('JSON.stringify({P: gameState.currencies.P, lv: Object.values(gameState.levels).reduce((s,v)=>s+v,0), cur: gameState.discoveredCurrencies.length})'));
    if (bad.length) { failures++; console.log(`FAIL  ${sc.name}`); bad.slice(0, 12).forEach(l => console.log('   ' + l)); }
    else console.log(`PASS  ${sc.name}  (${sc.rounds * sc.ticks} ticks, P=${final.P.toExponential(4)}, total levels ${final.lv}, currencies ${final.cur})`);
    await o.close(); await u.close();
  }
  await browser.close();
  console.log(failures ? `\n${failures} scenario(s) differ` : '\nAll scenarios match the original exactly.');
  process.exit(failures ? 1 : 0);
})();
