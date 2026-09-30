// Smoke test: loads the game in headless Chromium, drives the dev bar and the HUD, fails on any
// page error, and saves screenshots. Usage:
//   NODE_PATH=$(npm root -g) [FONT_DIR=<dir with fonts.css and map.txt>] node tools/smoke.js <out dir>
const path = require('path');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');

async function run(name, viewport, script) {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: viewport.width < 800 ? 2 : 1, hasTouch: viewport.width < 800 });
  const page = await ctx.newPage();
  // Serve Google Fonts from a local cache (FONT_DIR, see README) so screenshots use the real fonts.
  if (process.env.FONT_DIR) {
    const fs = require('fs');
    const map = Object.fromEntries(fs.readFileSync(path.join(process.env.FONT_DIR, 'map.txt'), 'utf8').trim().split('\n').map(l => l.split(' ')));
    await page.route(/fonts\.googleapis\.com/, r => r.fulfill({ status: 200, contentType: 'text/css', body: fs.readFileSync(path.join(process.env.FONT_DIR, 'fonts.css'), 'utf8') }));
    await page.route(/fonts\.gstatic\.com/, r => { const f = map[r.request().url()]; return f ? r.fulfill({ status: 200, contentType: 'font/woff2', body: fs.readFileSync(path.join(process.env.FONT_DIR, '..', f)) }) : r.abort(); });
  }
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text()); });
  await page.goto(URL);
  await page.waitForFunction(() => typeof GAME !== 'undefined' && document.getElementById('heroNum').textContent !== '');
  if (name === 'desk') { await page.waitForTimeout(600); await page.screenshot({ path: path.join(OUT, 'desk-00-title.png') }); }
  await page.waitForSelector('#tPlay:not([disabled])');
  await page.click('#tPlay', { force: true });
  await page.evaluate(() => { WORLD.perf.locked = true; }); // headless renders on the CPU; keep HIGH for screenshots
  await page.waitForTimeout(1500);
  await script(page, (n) => page.screenshot({ path: path.join(OUT, `${name}-${n}.png`) }));
  await browser.close();
  return errors;
}
const clickNode = async (page, id) => {
  const pt = await page.evaluate((id) => { const n = NODE_MAP.get(id); const s = WORLD.screenOf(n.coords[0], n.coords[1], WORLD.TOP + 0.2); return s; }, id);
  await page.mouse.click(pt[0], pt[1]);
};

(async () => {
  const all = [];
  all.push(...await run('desk', { width: 1280, height: 720 }, async (page, shot) => {
    await shot('01-fresh');
    await clickNode(page, '#1'); await page.waitForTimeout(300); await shot('02-sheet');
    await page.click('#shBuy'); await page.waitForTimeout(500); await shot('03-bought');
    for (let i = 0; i < 3; i++) { await page.click('#dvMax'); await page.waitForTimeout(900); }
    await shot('04-max3');
    for (let i = 0; i < 5; i++) { await page.click('#dvMax'); await page.waitForTimeout(700); }
    await page.waitForTimeout(1500); await shot('05-max8');
    await page.evaluate(() => { WORLD.cam.tZoom = 0.45; }); await page.waitForTimeout(900); await shot('06-zoomout');
    await page.evaluate(() => { WORLD.env.tod = 21.5; }); await page.waitForTimeout(700); await shot('07-night');
    await page.evaluate(() => { WORLD.env.tod = 18.4; WORLD.cam.tAngle = Math.PI / 2; WORLD.cam.tZoom = 1.1; }); await page.waitForTimeout(1200); await shot('08-dusk-rotated');
    await page.evaluate(() => { HUD.closeSheet(); for (let i = 0; i < 60; i++) ACTIONS.maxNextPlot(); ACTIONS.focusPlot('7,2'); WORLD.env.tod = 12; WORLD.cam.tAngle = 0; WORLD.cam.tZoom = 0.95; });
    await page.waitForTimeout(2500); await shot('08b-red-canyon');
    await page.evaluate(() => { ACTIONS.focusPlot('2,2'); }); await page.waitForTimeout(1800); await shot('08c-falls');
    await page.evaluate(() => { WORLD.env.tod = 22; ACTIONS.focusPlot('0,0'); WORLD.cam.tZoom = 0.8; }); await page.waitForTimeout(1800); await shot('08d-night-home');
    await page.evaluate(() => { WORLD.env.tod = 13; WORLD.cam.tZoom = 0.3; WORLD.cam.tx = 15; WORLD.cam.ty = 2.5; }); await page.waitForTimeout(2200); await shot('08e-whole-map');
    await page.evaluate(() => { WORLD.cam.tZoom = 1; ACTIONS.focusPlot('0,1'); }); await page.waitForTimeout(1500);
    await page.click('#tReset'); await page.waitForTimeout(400); await shot('09-rebuild');
    await page.click('#panelX'); await page.click('#tIndex'); await page.waitForTimeout(400); await shot('10-plots');
    await page.click('#panelX'); await page.click('#dvTimeline'); await page.waitForTimeout(400); await shot('11-timeline');
    await page.click('#panelX'); await page.click('#dvAway'); await page.waitForTimeout(600); await shot('12-offline');
    await page.keyboard.press('Escape'); await page.click('#modal .big');
    await page.click('#tSet'); await page.waitForTimeout(300); await shot('13-settings');
    await page.click('#panelX');
    const perf = await page.evaluate(async () => { const t = []; let last = performance.now(); for (let i = 0; i < 60; i++) { await new Promise(r => requestAnimationFrame(r)); const n = performance.now(); t.push(n - last); last = n; } t.sort((a, b) => a - b); return { median: t[30], p90: t[54] }; });
    console.log('desktop frame ms', JSON.stringify(perf));
  }));
  all.push(...await run('sim', { width: 1280, height: 720 }, async (page, shot) => {
    await clickNode(page, '#1'); await page.waitForTimeout(200); await page.click('#shBuy'); await page.keyboard.press('Escape');
    await page.click('#dvSim'); await page.waitForTimeout(1500); await shot('01-simming');
    await page.waitForFunction(() => !GAME.sim, null, { timeout: 120000 });
    await page.waitForTimeout(1200); await shot('02-sim-done');
    const r = await page.evaluate(() => JSON.stringify(SAVE_META().sims)); console.log('sims', r);
  }));
  all.push(...await run('phone', { width: 390, height: 844 }, async (page, shot) => {
    await shot('01-fresh');
    for (let i = 0; i < 4; i++) { await page.click('#dvMax'); await page.waitForTimeout(800); }
    await page.waitForTimeout(1200); await shot('02-max4');
    await clickNode(page, 'R1'); await page.waitForTimeout(400); await shot('03-sheet');
  }));
  all.push(...await run('land', { width: 844, height: 390 }, async (page, shot) => {
    for (let i = 0; i < 4; i++) { await page.click('#dvMax'); await page.waitForTimeout(800); }
    await page.waitForTimeout(1200); await shot('01-max4');
  }));
  const bad = all.filter(e => !/Failed to load resource|fonts\.g/.test(e));
  console.log(bad.length ? 'ERRORS:\n' + [...new Set(bad)].join('\n') : 'no page errors');
})();
