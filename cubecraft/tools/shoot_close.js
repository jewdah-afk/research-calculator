const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto('file://' + path.join(__dirname, 'viewer_local.html'));
  await page.waitForFunction(() => window.cc && window.cc.ready, null, { timeout: 120000 });
  await page.evaluate(() => { document.querySelector('.hud').hidden = true; document.querySelector('.hint').hidden = true; });
  const shots = {
    close_boundary: [[107, 13, 52], [100, 12, 52]],
    close_stone: [[107, 21, 30], [100, 20, 30]],
    edge_wide: [[128, 22, 60], [100, 14, 50]],
  };
  for (const [name, [pos, target]] of Object.entries(shots)) {
    await page.evaluate(([p, t]) => window.cc.look(p, t), [pos, target]);
    await page.waitForTimeout(600);
    await page.screenshot({ path: path.join(__dirname, 'shots', name + '.png') });
  }
  await browser.close();
})();
