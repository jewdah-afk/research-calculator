// render.js - render the approval samples (scenes.js) in headless Chromium.
//
//   cd art/ui && NODE_PATH=$(npm root -g) node samples/render.js [a b c d e f sheet] [--jpg]
//
// -> out/samples/<scene>.png (lossless) and, with --jpg, previews/<scene>.jpg (quality 90, what gets committed).
// Serves art/ as http://ui.local/ (the kit pieces, fonts, gem sprites and the realm backgrounds in out/bg).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const UI = path.join(__dirname, '..'), ART = path.join(UI, '..');
const SIZES = { a: [1920, 1080], b: [1920, 1080], c: [1920, 1080], d: [1920, 1080], e: [1920, 1080], f: [844, 390], sheet: [2400, 3000] };
const NAMES = { a: 'a_p_panel_tabsA', b: 'b_p_panel_tabsB', c: 'c_m_panel', d: 'd_cr_panel', e: 'e_home_hud', f: 'f_phone_p_844', sheet: 'pieces_sheet_2x' };

async function serve(page) {
  await page.route('http://ui.local/**', async r => {
    const u = new URL(r.request().url());
    const f = path.join(ART, decodeURIComponent(u.pathname));
    if (!f.startsWith(ART) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) return r.fulfill({ status: 404, body: 'missing ' + u.pathname });
    const ext = path.extname(f);
    const ct = { '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json', '.woff2': 'font/woff2', '.css': 'text/css', '.html': 'text/html', '.js': 'text/javascript' }[ext] || 'application/octet-stream';
    return r.fulfill({ contentType: ct, body: fs.readFileSync(f) });
  });
}

async function renderScene(browser, id, { jpg = false, dpr = 1 } = {}) {
  const [w, h] = SIZES[id];
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
  page.on('pageerror', e => console.log(`[${id}] pageerror`, e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log(`[${id}]`, m.text()); });
  await serve(page);
  await page.goto('http://ui.local/ui/samples/page.html');
  await page.evaluate(async id => { await O.load(); await SCENES[id](); await document.fonts.ready; }, id);
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => Promise.all([...document.images].map(im => im.complete ? 1 : new Promise(r => { im.onload = im.onerror = r; }))));
  await page.waitForTimeout(150);
  const out = path.join(UI, 'out', 'samples', NAMES[id] + '.png');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  await page.screenshot({ path: out });
  if (jpg) { fs.mkdirSync(path.join(UI, 'previews'), { recursive: true }); await page.screenshot({ path: path.join(UI, 'previews', NAMES[id] + '.jpg'), type: 'jpeg', quality: 90 }); }
  await page.close();
  console.log(`${id} -> ${path.relative(UI, out)}`);
  return out;
}

if (require.main === module) (async () => {
  const args = process.argv.slice(2), jpg = args.includes('--jpg');
  const ids = args.filter(a => !a.startsWith('--'));
  const browser = await chromium.launch();
  for (const id of (ids.length ? ids : Object.keys(SIZES))) await renderScene(browser, id, { jpg });
  await browser.close();
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
module.exports = { serve, renderScene, SIZES, NAMES };
