// City layer check: grows a save through the tiers and captures the tier celebration, the Stud
// Express, the STUD CITY sign and downtown by day and night. Fails on any page error. Usage:
//   NODE_PATH=$(npm root -g) [FONT_DIR=...] [CHROMIUM=...] node tools/wow-city.js <out dir>
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  if (process.env.FONT_DIR) {
    const map = Object.fromEntries(fs.readFileSync(path.join(process.env.FONT_DIR, 'map.txt'), 'utf8').trim().split('\n').map(l => l.split(' ')));
    await page.route(/fonts\.googleapis\.com/, r => r.fulfill({ status: 200, contentType: 'text/css', body: fs.readFileSync(path.join(process.env.FONT_DIR, 'fonts.css'), 'utf8') }));
    await page.route(/fonts\.gstatic\.com/, r => { const f = map[r.request().url()]; return f ? r.fulfill({ status: 200, contentType: 'font/woff2', body: fs.readFileSync(path.join(process.env.FONT_DIR, '..', f)) }) : r.abort(); });
  }
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text()); });
  await page.goto(URL);
  await page.waitForSelector('#tPlay:not([disabled])');
  await page.evaluate(() => { WORLD.perf.locked = true; });
  await page.click('#tPlay', { force: true });
  await page.evaluate(() => CINE.skip());
  const shot = (n) => page.screenshot({ path: path.join(OUT, `city-${n}.png`) });
  const waitT = (s) => page.evaluate((s) => new Promise(r => { const t0 = WORLD.R.T; const f = () => WORLD.R.T - t0 >= s ? r() : requestAnimationFrame(f); f(); }), s);
  // grow to Town: the tier celebration plays once the last plot's hero moment ends
  let n = 0;
  while (await page.evaluate(() => WORLD.R.builtCache().size) < 5 && n++ < 20) { await page.evaluate(() => ACTIONS.maxNextPlot()); await waitT(0.4); }
  await page.waitForFunction(() => document.getElementById('letterbox').classList.contains('on') && CITY.tierIndex() === 1, null, { timeout: 60000 }).catch(() => { });
  await waitT(2.6); await shot('1-town-celebration');
  await waitT(3); await page.evaluate(() => { WORLD.env.tod = 16; FX.play('studExpress', { force: true }); WORLD.cam.tZoom = 0.9; }); await waitT(2); await shot('2-express');
  await page.evaluate(() => { FX.play('citySign', { force: true }); WORLD.cam.tZoom = 0.75; }); await waitT(2.5); await shot('3-sign-town');
  // grow to Metropolis
  await page.evaluate(() => { for (let i = 0; i < 40; i++) ACTIONS.maxNextPlot(); });
  await page.waitForFunction(() => CITY.tierIndex() === 3, null, { timeout: 60000 });
  await page.waitForFunction(() => document.getElementById('letterbox').classList.contains('on'), null, { timeout: 60000 }).catch(() => { });
  await waitT(3); await shot('4-metro-celebration');
  await waitT(3);
  await page.evaluate(() => { WORLD.env.tod = 13; FX.play('downtown', { force: true }); WORLD.env.tod = 13; WORLD.cam.tZoom = 0.6; }); await waitT(2); await shot('5-downtown-day');
  await page.evaluate(() => { WORLD.env.tod = 22; }); await waitT(1.5); await shot('6-downtown-night');
  await page.evaluate(() => { WORLD.cam.tZoom = 0.32; WORLD.cam.tx = 6; WORLD.cam.ty = -4; }); await waitT(2); await shot('7-skyline-night-wide');
  await page.evaluate(() => { WORLD.env.tod = 18.3; WORLD.cam.tZoom = 0.9; ACTIONS.focusPlot('4,0'); }); await waitT(2); await shot('8-bridge-dusk');
  await page.evaluate(() => { WORLD.env.tod = 12; WORLD.cam.tZoom = 0.26; WORLD.cam.tx = 12; WORLD.cam.ty = 0; }); await waitT(2); await shot('9-whole-day');
  const info = await page.evaluate(() => ({ tier: CITY.tier().title, tierMax: META.state().tierMax, badges: Object.keys(META.state().badges).filter(k => k.startsWith('tier')) }));
  console.log(JSON.stringify(info));
  await browser.close();
  console.log(errors.length ? errors.slice(0, 20).join('\n') : 'no page errors');
  process.exit(errors.some(e => e.startsWith('pageerror')) ? 1 : 0);
})();
