// Wow layer check: plays the first-play intro on a fresh save and captures its beats, then the
// photo tour, and fails on any page error. Usage:
//   NODE_PATH=$(npm root -g) [FONT_DIR=...] [CHROMIUM=...] node tools/wow.js <out dir> [phone]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const PHONE = process.argv[3] === 'phone';
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const viewport = PHONE ? { width: 844, height: 390 } : { width: 1280, height: 720 };
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: PHONE ? 2 : 1, hasTouch: PHONE });
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
  const tag = PHONE ? 'phone' : 'desk';
  const shot = (n) => page.screenshot({ path: path.join(OUT, `${tag}-intro-${n}.png`) });
  // capture by intro time (world T), since the headless frame rate is low
  const at = async (sec, n) => { await page.waitForFunction((s) => CINE.on !== 'intro' || WORLD.R.T - window.__t0 >= s, sec, { timeout: 60000 }).catch(() => { }); await shot(n); };
  await page.evaluate(() => { window.__t0 = WORLD.R.T; });
  await at(0.4, '1-clouds'); await at(1.6, '2-parting'); await at(2.9, '3-tiles'); await at(3.8, '4-ripple'); await at(4.6, '5-welcome'); await at(5.8, '6-parachute');
  await page.waitForFunction(() => document.body.classList.contains('hud-in') || !CINE.on, null, { timeout: 60000 }).catch(() => { });
  await page.waitForTimeout(250); await shot('7-hud-slam');
  await page.waitForTimeout(2500); await shot('8-ready');
  const ok = await page.evaluate(() => ({ intro: CINE.on, introSeen: META.state().introSeen, hud: getComputedStyle(document.getElementById('hud')).opacity }));
  console.log('after intro', JSON.stringify(ok));
  // tour over a built-up save
  await page.evaluate(() => { for (let i = 0; i < 24; i++) ACTIONS.maxNextPlot(); });
  await page.waitForTimeout(3000);
  await page.evaluate(() => { UIX.photo.enter(); CINE.tour(); window.__t0 = WORLD.R.T; });
  await page.waitForFunction(() => WORLD.R.T - window.__t0 > 2.4, null, { timeout: 60000 }); await page.screenshot({ path: path.join(OUT, `${tag}-tour-1.png`) });
  await page.waitForFunction(() => WORLD.R.T - window.__t0 > 6.2, null, { timeout: 60000 }); await page.screenshot({ path: path.join(OUT, `${tag}-tour-2.png`) });
  await page.evaluate(() => CINE.stop());
  await page.evaluate(() => UIX.photo.exit());
  // replay intro on the built-up save: the whole city ripples back together
  await page.evaluate(() => { WORLD.cam.tZoom = 0.5; CINE.intro({ fresh: false }); window.__t0 = WORLD.R.T; });
  await page.waitForFunction(() => WORLD.R.T - window.__t0 > 3.6, null, { timeout: 60000 }); await page.screenshot({ path: path.join(OUT, `${tag}-replay-ripple.png`) });
  await page.waitForFunction(() => WORLD.R.T - window.__t0 > 5.2, null, { timeout: 60000 }); await page.screenshot({ path: path.join(OUT, `${tag}-replay-welcome.png`) });
  await page.evaluate(() => CINE.skip());
  await page.waitForTimeout(800);
  await browser.close();
  console.log(errors.length ? errors.join('\n') : 'no page errors');
  process.exit(errors.some(e => e.startsWith('pageerror')) ? 1 : 0);
})();
