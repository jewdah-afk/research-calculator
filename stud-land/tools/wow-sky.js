// Sky and sea layer check: god rays, aurora, shooting star (and tapping it), the sea serpent (and
// tapping it), a milestone takeover and bloom on Ultra. Also checks that every sound id the game
// uses exists in the audio catalog. Fails on any page error. Usage:
//   NODE_PATH=$(npm root -g) [FONT_DIR=...] [CHROMIUM=...] node tools/wow-sky.js <out dir>
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');
const USED = [...new Set(fs.readdirSync(path.join(__dirname, '..', 'js')).filter(f => f.endsWith('.js') && f !== 'audio.js')
  .flatMap(f => [...fs.readFileSync(path.join(__dirname, '..', 'js', f), 'utf8').matchAll(/(?:sfx|snd)\('([a-zA-Z]+)'/g)].map(m => m[1])))];
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
  const missing = await page.evaluate((used) => { const have = new Set(AUDIO.CATALOG.map(e => e.id)); return { sounds: used.filter(u => !have.has(u)), haptics: ['buy', 'maxed', 'big'].filter(h => !HAPTIC.CATALOG.some(e => e.id === h)), catalog: AUDIO.CATALOG.length }; }, USED);
  console.log('sound ids used', USED.length, 'missing', JSON.stringify(missing));
  const shot = (n) => page.screenshot({ path: path.join(OUT, `sky-${n}.png`) });
  const waitT = (s) => page.evaluate((s) => new Promise(r => { const t0 = WORLD.R.T; const f = () => WORLD.R.T - t0 >= s ? r() : requestAnimationFrame(f); f(); }), s);
  await page.evaluate(() => { for (let i = 0; i < 14; i++) ACTIONS.maxNextPlot(); });
  await waitT(4); await page.waitForFunction(() => !document.body.classList.contains('cine') && !WORLD.FXD.inHero(), null, { timeout: 60000 }); await waitT(5);
  await page.evaluate(() => { HUD.closeSheet(); ENVFX.set('clear', 1e9); WORLD.cam.tx = -4; WORLD.cam.ty = 6; WORLD.cam.tZoom = 0.55; FX.play('godRays', { force: true }); }); await waitT(2); await shot('1-godrays');
  await page.evaluate(() => { FX.play('aurora', { force: true }); }); await waitT(2); await shot('2-aurora');
  await page.evaluate(() => { FX.play('shootingStar', { force: true }); }); await waitT(0.45); await shot('3-shooting-star');
  // tap the star through the real input path (centre of its hit box, found right after launch)
  const find = (type) => page.evaluate((type) => { let sx = 0, sy = 0, n = 0; for (let y = 0; y < WORLD.H; y += 6) for (let x = 0; x < WORLD.W; x += 6) { const h = WORLD.pick(x, y); if (h && h.type === type) { sx += x; sy += y; n++; } } return n ? [sx / n, sy / n] : null; }, type);
  await page.evaluate(() => SKY.launchStar(true));
  const sp = await find('star');
  if (sp) await page.mouse.click(sp[0], sp[1]);
  await waitT(0.3);
  await page.evaluate(() => { WORLD.env.tod = 11; WORLD.cam.tZoom = 0.8; }); await waitT(1.5); await page.evaluate(() => { FX.play('seaSerpent', { force: true }); }); await waitT(4.5); await shot('4-serpent');
  const sp2 = await find('serpent');
  if (sp2) await page.mouse.click(sp2[0], sp2[1]);
  await waitT(0.6); await shot('5-serpent-tapped');
  await page.evaluate(() => { FX.play('milestone', { e: 6, force: true }); }); await page.waitForTimeout(700); await shot('6-milestone');
  await page.waitForTimeout(2000);
  await page.evaluate(() => { WORLD.perf.locked = true; FX.play('bloom', { force: true }); WORLD.env.tod = 22; WORLD.cam.tZoom = 0.8; }); await waitT(2); await shot('7-bloom-night');
  await page.evaluate(() => { WORLD.setQuality('high'); }); await waitT(1); await shot('8-no-bloom-night');
  await page.waitForTimeout(1500);
  const info = await page.evaluate(() => ({ starTapped: !!(META.state().counters.wishes), serpentTapped: !!(META.state().counters.serpents), badges: Object.keys(META.state().badges).filter(k => ['wish', 'serpent', 'aurora'].includes(k)) }));
  console.log('tap targets found', !!sp, !!sp2, JSON.stringify(info));
  await browser.close();
  console.log(errors.length ? errors.slice(0, 20).join('\n') : 'no page errors');
  process.exit(errors.some(e => e.startsWith('pageerror')) || missing.sounds.length ? 1 : 0);
})();
