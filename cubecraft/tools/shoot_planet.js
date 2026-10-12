const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  page.on('console', m => console.log('console:', m.text()));
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto('file://' + path.join(__dirname, 'planet_local.html'));
  await page.waitForFunction(() => window.cc && window.cc.ready, null, { timeout: 120000 });
  await page.waitForTimeout(1500);
  for (const v of (process.argv[2] || 'planet,grass,forest,desert,snow,ocean,volcano,edge').split(',')) {
    await page.evaluate((v) => window.cc.setView(v, true), v);
    await page.waitForTimeout(700);
    await page.screenshot({ path: path.join(__dirname, 'shots', 'planet_' + v + '.png') });
  }
  await browser.close();
})();
