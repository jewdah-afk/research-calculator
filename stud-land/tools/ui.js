// UI check: captures every HUD piece, panel, card and overlay on desktop, phone portrait and phone
// landscape, and fails on any page error. Usage:
//   NODE_PATH=$(npm root -g) [FONT_DIR=...] [CHROMIUM=...] node tools/ui.js <out dir> [desk|phone|land]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const OUT = path.resolve(process.argv[2] || 'shots');
const ONLY = process.argv[3];
const URL = 'file://' + path.resolve(__dirname, '..', 'index.html');
const VIEWS = { desk: { width: 1280, height: 720 }, phone: { width: 390, height: 844 }, land: { width: 844, height: 390 } };
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const errors = [];
  for (const [tag, viewport] of Object.entries(VIEWS)) {
    if (ONLY && ONLY !== tag) continue;
    const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
    const mobile = tag !== 'desk';
    const ctx = await browser.newContext({ viewport, deviceScaleFactor: mobile ? 2 : 1, hasTouch: mobile, isMobile: mobile });
    const page = await ctx.newPage();
    if (process.env.FONT_DIR) {
      const map = Object.fromEntries(fs.readFileSync(path.join(process.env.FONT_DIR, 'map.txt'), 'utf8').trim().split('\n').map(l => l.split(' ')));
      await page.route(/fonts\.googleapis\.com/, r => r.fulfill({ status: 200, contentType: 'text/css', body: fs.readFileSync(path.join(process.env.FONT_DIR, 'fonts.css'), 'utf8') }));
      await page.route(/fonts\.gstatic\.com/, r => { const f = map[r.request().url()]; return f ? r.fulfill({ status: 200, contentType: 'font/woff2', body: fs.readFileSync(path.join(process.env.FONT_DIR, '..', f)) }) : r.abort(); });
    }
    page.on('pageerror', e => errors.push(tag + ' pageerror: ' + e.message));
    page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(tag + ' ' + m.type() + ': ' + m.text()); });
    await page.goto(URL);
    await page.waitForSelector('#tPlay:not([disabled])');
    await page.waitForTimeout(1600);
    await page.screenshot({ path: path.join(OUT, `${tag}-00-title.png`) });
    await page.evaluate(() => { WORLD.perf.locked = true; });
    await page.click('#tPlay', { force: true });
    await page.evaluate(() => CINE.skip());
    await page.waitForTimeout(1200);
    const shot = (n) => page.screenshot({ path: path.join(OUT, `${tag}-${n}.png`) });
    // a mid-game save so every panel has content
    await page.evaluate(() => { const x = META.state(); x.tierMax = 3; x.milestone = 300; for (let i = 0; i < 7; i++) ACTIONS.maxNextPlot(); META.secret('WHALE'); });
    await page.waitForFunction(() => !document.body.classList.contains('cine') && !WORLD.FXD.inHero(), null, { timeout: 60000 }).catch(() => { });
    await page.evaluate(() => { ACTIONS.focusPlot('0,0'); WORLD.env.tod = 11; });
    await page.waitForTimeout(2600);
    await shot('01-hud');
    await page.evaluate(() => { const n = PLOTS.get('0,0').upgrades.find(n => isNodeUnlocked(n) && getLevel(n.id) < getMaxLevel(n)) || PLOTS.get('0,0').upgrades[0]; HUD.openNode(n.id); });
    await page.waitForTimeout(500); await shot('02-card');
    await page.evaluate(() => HUD.closeSheet());
    for (const [k, n] of [['reset', '03-rebuild'], ['index', '04-plots'], ['badges', '05-badges'], ['codes', '06-codes'], ['settings', '07-settings'], ['stats', '08-stats'], ['timeline', '09-timeline'], ['help', '10-help']]) {
      await page.evaluate((k) => HUD.openPanel(k), k); await page.waitForTimeout(450); await shot(n);
    }
    await page.evaluate(() => { HUD.openPanel('codes'); const b = document.getElementById('panelBody'); b.scrollTop = b.scrollHeight; }); await page.waitForTimeout(500); await shot('11-codes-wardrobe');
    await page.evaluate(() => HUD.closePanel());
    await page.evaluate(() => ACTIONS.away(1)); await page.waitForTimeout(600); await shot('12-offline');
    await page.evaluate(() => document.querySelector('#modal button.big').click());
    await page.evaluate(() => { HUD.toast('Maxed Stud Square: +469 levels on 12 machines', '#fff3b0'); HUD.toast('New: Loops', '#e6f4ff'); HUD.banner('Robo Works'); document.getElementById('badgePop').querySelector('.bp-name').textContent = 'Island Hopper'; document.getElementById('badgePop').classList.add('show'); });
    await page.waitForTimeout(700); await shot('13-toasts-banner-badge');
    await page.waitForTimeout(2600);
    await page.evaluate(() => { document.getElementById('badgePop').classList.remove('show'); LAB.show(); }); await page.waitForTimeout(500); await shot('14-lab');
    await page.evaluate(() => [...document.querySelectorAll('#drawerTabs button')].find(b => b.textContent === 'UI KIT').click()); await page.waitForTimeout(500); await shot('14b-kit');
    await page.evaluate(() => { LAB.close(); UIX.photo.enter(); }); await page.waitForTimeout(500); await shot('15-photo');
    await page.evaluate(() => { UIX.photo.exit(); WALK.enter(); }); await page.waitForTimeout(800); await shot('16-walk');
    await page.evaluate(() => WALK.exit());
    await browser.close();
  }
  console.log(errors.length ? errors.slice(0, 30).join('\n') : 'no page errors');
  process.exit(errors.some(e => e.includes('pageerror')) ? 1 : 0);
})();
