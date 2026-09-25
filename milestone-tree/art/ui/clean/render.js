// render.js - render the clean-direction option boards in headless Chromium (serving art/ through the samples
// tooling's serve(), so the kit fonts, the gem sprites and the realm backgrounds in art/ui/out/bg load as they do there).
//
//   cd art/ui && NODE_PATH=$(npm root -g) node clean/render.js [scene ...]      (default: every scene, board last)
//
// -> clean/out/<name>.png (lossless, gitignored) and/or <name>.jpg (quality 90, committed previews).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const { serve } = require('../samples/render.js');
const OUT = path.join(__dirname, 'out');

const SCENES = {};
for (const n of [1, 2, 3, 4]) {
  SCENES[`style${n}_p_panel`] = { size: [1920, 1080], call: ['panel', n], png: true, jpg: true };
  SCENES[`style${n}_home_hud`] = { size: [1920, 1080], call: ['hud', n], jpg: true };
}
SCENES.nodes_compare = { size: [1920, 1160], call: ['nodes'], jpg: true };
SCENES.style_board = { size: [2560, 1584], call: ['board'], jpg: true };

async function openPage(browser, [w, h]) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  page.on('pageerror', e => console.log('pageerror', e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning' || m.type() === 'log') console.log('[page]', m.text()); });
  await serve(page);
  await page.goto('http://ui.local/ui/clean/page.html');
  await page.evaluate(() => K.load());
  return page;
}
async function settle(page) {
  await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(im => im.complete ? 1 : new Promise(r => { im.onload = im.onerror = r; }))); });
  await page.waitForTimeout(120);
}

async function render(browser, name) {
  const S = SCENES[name]; if (!S) throw new Error('no scene ' + name);
  const page = await openPage(browser, S.size);
  await page.evaluate(async ([fn, ...args]) => { await CLEAN[fn](...args); }, S.call);
  await settle(page);
  fs.mkdirSync(OUT, { recursive: true });
  if (S.png) await page.screenshot({ path: path.join(OUT, name + '.png') });
  if (S.jpg) await page.screenshot({ path: path.join(OUT, name + '.jpg'), type: 'jpeg', quality: 90 });
  await page.close();
  console.log(name);
}

if (require.main === module) (async () => {
  const want = process.argv.slice(2);
  const names = want.length ? want : Object.keys(SCENES).filter(n => n !== 'style_board').concat('style_board');
  const browser = await chromium.launch();
  for (const n of names) await render(browser, n);
  await browser.close();
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
module.exports = { openPage, settle, SCENES };
