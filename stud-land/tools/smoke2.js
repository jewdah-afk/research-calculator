// Smoke test for the v2 systems: walk mode, photo mode, FX Lab (plays every catalog effect),
// badges, codes, stats, weather, and walk controls on a phone. Fails on any page error.
// Usage: NODE_PATH=$(npm root -g) [FONT_DIR=...] node tools/smoke2.js <out dir>
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');

async function open(browser, viewport, touch) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: touch ? 2 : 1, hasTouch: !!touch, isMobile: !!touch });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text()); });
  if (process.env.FONT_DIR) {
    const map = Object.fromEntries(fs.readFileSync(path.join(process.env.FONT_DIR, 'map.txt'), 'utf8').trim().split('\n').map(l => l.split(' ')));
    await page.route(/fonts\.googleapis\.com/, r => r.fulfill({ status: 200, contentType: 'text/css', body: fs.readFileSync(path.join(process.env.FONT_DIR, 'fonts.css'), 'utf8') }));
    await page.route(/fonts\.gstatic\.com/, r => { const f = map[r.request().url()]; return f ? r.fulfill({ status: 200, contentType: 'font/woff2', body: fs.readFileSync(path.join(process.env.FONT_DIR, '..', f)) }) : r.abort(); });
  }
  await page.goto(URL);
  await page.waitForSelector('#tPlay:not([disabled])');
  await page.click('#tPlay', { force: true });
  await page.evaluate(() => { if (typeof CINE !== 'undefined' && CINE.on) CINE.skip(); }); // the first-play intro is covered by tools/wow.js
  await page.evaluate(() => { WORLD.perf.locked = true; });
  await page.waitForTimeout(1200);
  return { page, errors, ctx };
}
const shot = (page, name) => page.screenshot({ path: path.join(OUT, name + '.png') });

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const all = [];
  {
    const { page, errors } = await open(browser, { width: 1280, height: 720 });
    await page.evaluate(() => { HUD.toast = () => {}; for (let i = 0; i < 14; i++) ACTIONS.maxNextPlot(); ACTIONS.focusPlot('0,0'); WORLD.env.tod = 9; WORLD.cam.tZoom = 1.05; });
    await page.waitForTimeout(2500); await shot(page, 'v2-01-home-day');
    // walk mode: enter, walk right and up, try to use
    await page.keyboard.press('v'); await page.waitForTimeout(600);
    await page.keyboard.down('d'); await page.waitForTimeout(900); await page.keyboard.up('d');
    await page.keyboard.down('w'); await page.waitForTimeout(700); await page.keyboard.up('w');
    await page.keyboard.press('e'); await page.waitForTimeout(700); await shot(page, 'v2-02-walk');
    const walk = await page.evaluate(() => ({ x: WALK.A.x.toFixed(2), y: WALK.A.y.toFixed(2), near: WALK.A.near && WALK.A.near.id, dist: WALK.A.dist.toFixed(1) }));
    console.log('walk', JSON.stringify(walk));
    await page.keyboard.press('v');
    // code bricks: collect all via the API and redeem
    await page.evaluate(() => { for (const s of META_SPOTS) META.collect(s.id); });
    await page.waitForTimeout(1500);
    await page.click('#tCodes'); await page.waitForTimeout(400);
    await page.fill('.redeem input', 'studcity'); await page.click('.redeem .lab-play'); await page.waitForTimeout(900); await shot(page, 'v2-03-codes');
    await page.click('#panelX');
    await page.click('#tBadges'); await page.waitForTimeout(400); await shot(page, 'v2-04-badges'); await page.click('#panelX');
    await page.click('#hero'); await page.waitForTimeout(600); await shot(page, 'v2-05-stats'); await page.click('#panelX');
    // machine card data tab
    await page.evaluate(() => { const n = HUD.focus.upgrades.find(n => getLevel(n.id) > 0 && getLevel(n.id) < getMaxLevel(n)) || HUD.focus.upgrades[2]; HUD.openNode(n.id); });
    await page.waitForTimeout(400); await shot(page, 'v2-06-card-info');
    await page.click('.sh-tabs button[data-t="data"]'); await page.waitForTimeout(300); await shot(page, 'v2-07-card-data');
    await page.click('.sh-tabs button[data-t="info"]'); await page.evaluate(() => HUD.closeSheet());
    // FX Lab: open, play every world effect, visit every tab
    await page.click('#dvLab'); await page.waitForTimeout(400);
    const n = await page.evaluate(async () => { let k = 0; for (const e of FX.CATALOG) { try { FX.play(e.id, { force: true, ...(e.id === 'reset' ? { node: TREE_NODES.find(n => n.type === 'reset'), gain: 5, resetIds: new Set() } : {}), ...(e.id === 'plotBuilt' ? { plot: PLOTS.get('0,0') } : {}), node: e.id === 'reset' ? TREE_NODES.find(n => n.type === 'reset') : HUD.focus.upgrades[0] }); k++; } catch (err) { console.error('fx ' + e.id + ' ' + err.message); } } return k; });
    console.log('fx played', n);
    await page.waitForTimeout(700); await shot(page, 'v2-08-lab-world');
    for (const t of ['ui', 'sound', 'haptic', 'systems', 'export']) { await page.evaluate((t) => { [...document.querySelectorAll('#drawerTabs button')].find(b => b.textContent === ({ ui: 'UI MOTION', sound: 'SOUND', haptic: 'HAPTICS', systems: 'SYSTEMS', export: 'EXPORT' })[t]).click(); }, t); await page.waitForTimeout(250); }
    await shot(page, 'v2-09-lab-export');
    const json = await page.evaluate(() => LAB.catalogJSON().length);
    console.log('catalog json bytes', json);
    await page.evaluate(() => LAB.close());
    // weather states
    for (const [w, tod, name] of [['storm', 14, 'v2-10-storm'], ['fog', 7, 'v2-11-fog'], ['snow', 23, 'v2-12-snow'], ['clear', 18.3, 'v2-13-dusk']]) {
      await page.evaluate(([w, tod]) => { ENVFX.set(w, 1e9); ENVFX.W.cur = { ...ENVFX.KINDS[w] }; WORLD.env.tod = tod; }, [w, tod]);
      if (w === 'storm') await page.evaluate(() => FX.play('lightning', { force: true }));
      await page.waitForTimeout(900); await shot(page, name);
    }
    // photo mode
    await page.keyboard.press('p'); await page.waitForTimeout(400);
    await page.click('#pbFilter button[data-f="warm"]'); await page.waitForTimeout(300); await shot(page, 'v2-14-photo');
    await page.click('#pbSnap'); await page.waitForTimeout(600); await shot(page, 'v2-15-snap');
    await page.evaluate(() => document.querySelector('#modal button.big').click()); await page.click('#pbExit');
    await page.click('#tSet'); await page.waitForTimeout(300); await shot(page, 'v2-16-settings'); await page.click('#panelX');
    // everything maxed, ultra, from far
    await page.evaluate(() => { for (let i = 0; i < 50; i++) ACTIONS.maxNextPlot(); WORLD.setQuality('ultra'); document.body.classList.add('tilt'); ENVFX.set('clear', 1e9); ENVFX.W.cur = { ...ENVFX.KINDS.clear }; WORLD.env.tod = 11; ACTIONS.focusPlot('3,1'); WORLD.cam.tZoom = 0.62; });
    await page.waitForTimeout(2500); await shot(page, 'v2-17-ultra');
    const badges = await page.evaluate(() => Object.keys(META.state().badges).length);
    console.log('badges', badges);
    all.push(...errors);
  }
  {
    const { page, errors } = await open(browser, { width: 390, height: 844 }, true);
    await page.evaluate(() => { HUD.toast = () => {}; for (let i = 0; i < 6; i++) ACTIONS.maxNextPlot(); ACTIONS.focusPlot('0,0'); });
    await page.waitForTimeout(1500); await shot(page, 'v2-20-phone');
    await page.tap('#btnWalk'); await page.waitForTimeout(800); await shot(page, 'v2-21-phone-walk');
    all.push(...errors);
  }
  await browser.close();
  const bad = all.filter(e => !/Failed to load resource|fonts\.g/.test(e));
  console.log(bad.length ? 'ERRORS:\n' + [...new Set(bad)].join('\n') : 'no page errors');
})();
