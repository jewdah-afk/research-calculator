// build.js - paint the UI kit: every piece of pieces.js + the VFX atlas -> out/pieces/*.png and the manifest ui.json.
//
//   cd art/ui && NODE_PATH=$(npm root -g) node build.js [name ...]      (names filter; default = everything)
//
// Needs the Blender renders in out/3d (blender/build.py) and Playwright's Chromium. Pieces are straight-alpha RGBA
// PNGs with the colour of every transparent pixel bled from its visible neighbours (roblox/tile.js alphaBleed), so
// Roblox's bilinear filtering never pulls a dark fringe into scaled edges. The encoder is deterministic.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const T = require('../roblox/tile.js');

const UI = __dirname, ART = path.join(UI, '..'), OUT = path.join(UI, 'out'), PIECES_DIR = path.join(OUT, 'pieces');
const SCALE = 2;

async function openKit(browser) {
  const page = await browser.newPage();
  page.on('console', m => console.log('[page]', m.text()));
  page.on('pageerror', e => console.log('[err]', e.message));
  await page.route('http://ui.local/**', async r => {
    const u = new URL(r.request().url());
    if (u.pathname === '/__kit') return r.fulfill({ contentType: 'text/html', body: '<html><body></body></html>' });
    const f = path.join(ART, decodeURIComponent(u.pathname));
    if (!f.startsWith(ART) || !fs.existsSync(f)) return r.fulfill({ status: 404, body: 'missing ' + u.pathname });
    const ct = f.endsWith('.png') ? 'image/png' : f.endsWith('.json') ? 'application/json' : f.endsWith('.woff2') ? 'font/woff2' : 'text/javascript';
    return r.fulfill({ contentType: ct, body: fs.readFileSync(f) });
  });
  await page.goto('http://ui.local/__kit');
  for (const s of ['lib.js', 'ui/themes.js', 'ui/kit.js', 'ui/pieces.js', 'ui/vfx.js']) await page.addScriptTag({ url: 'http://ui.local/' + s });
  await page.evaluate(() => {
    const cache = {};
    window.A = {
      img: n => cache['i' + n] || (cache['i' + n] = new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = () => rej(new Error('no 3d render ' + n)); im.src = '/ui/out/3d/' + n + '.png'; })),
      meta: n => cache['m' + n] || (cache['m' + n] = fetch('/ui/out/3d/' + n + '.json').then(r => { if (!r.ok) throw new Error('no meta ' + n); return r.json(); })),
    };
    window.__pixels = (c) => {
      const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      let s = ''; for (let i = 0; i < d.length; i += 0x8000) s += String.fromCharCode.apply(null, d.subarray(i, i + 0x8000));
      return { w: c.width, h: c.height, b64: btoa(s) };
    };
  });
  return page;
}

function savePNG(file, px) {
  let img = { width: px.w, height: px.h, data: Buffer.from(px.b64, 'base64') };
  img = T.alphaBleed(img);
  fs.writeFileSync(file, T.encodePNG(img, { alpha: true }));
  return T.sha256(fs.readFileSync(file));
}

(async () => {
  const want = process.argv.slice(2);
  fs.mkdirSync(PIECES_DIR, { recursive: true });
  const manifestFile = path.join(UI, 'ui.json');
  const old = fs.existsSync(manifestFile) ? JSON.parse(fs.readFileSync(manifestFile, 'utf8')) : null;
  const browser = await chromium.launch();
  const page = await openKit(browser);
  const names = await page.evaluate(() => PIECES.map(p => p.name));
  const pieces = {};
  const t0 = Date.now();
  for (const name of names) {
    if (want.length && !want.includes(name) && !(want.includes('vfx') && false)) { if (old && old.pieces[name]) pieces[name] = old.pieces[name]; continue; }
    const r = await page.evaluate(async name => {
      const P = PIECES.find(p => p.name === name);
      if (!P.w) { const im = await A.img(P.from3d); P.w = im.width; P.h = im.height; }
      const c = canvas(P.w, P.h), x = c.getContext('2d');
      await P.paint(x, A);
      const anchor = P.anchor ? await P.anchor(A) : undefined;
      return Object.assign(__pixels(c), { kind: P.kind, slice: P.slice, anchor });
    }, name);
    const file = `pieces/${name}.png`;
    const sha = savePNG(path.join(OUT, file), r);
    const e = { file, size: [r.w, r.h], kind: r.kind, display: [r.w / SCALE, r.h / SCALE], sha256: sha.slice(0, 16) };
    if (r.kind === 'slice') { const [l, t, rr, b] = r.slice; e.sliceCenter = [l, t, r.w - rr, r.h - b]; e.sliceScale = 1 / SCALE; }
    if (r.kind === 'tile') e.tileSize = [r.w / SCALE, r.h / SCALE];
    if (r.anchor) e.anchor = r.anchor;
    pieces[name] = e;
    console.log(`${name.padEnd(16)} ${String(r.w).padStart(4)}x${String(r.h).padEnd(4)} ${r.kind.padEnd(5)} ${e.sliceCenter ? 'SliceCenter ' + JSON.stringify(e.sliceCenter) : e.anchor ? 'anchor ' + JSON.stringify(e.anchor) : e.tileSize ? 'tile ' + JSON.stringify(e.tileSize) : ''}`);
  }
  let atlas = old && old.atlas;
  if (!want.length || want.includes('vfx')) {
    const a = await page.evaluate(async () => { const { canvas: c, rects } = await VFX_ATLAS(A); return Object.assign(__pixels(c), { rects }); });
    const sha = savePNG(path.join(OUT, 'pieces/vfx.png'), a);
    atlas = { file: 'pieces/vfx.png', size: [a.w, a.h], sha256: sha.slice(0, 16), tint: 'white sprites: tint with ImageColor3 (stone shards and chain links keep their colour)', sprites: a.rects };
    console.log(`vfx atlas ${a.w}x${a.h}: ${Object.keys(a.rects).length} sprites`);
  }
  await browser.close();
  const themes = require('./themes.js');
  const manifest = {
    about: 'TOOLING REFERENCE ONLY: the cosmic ornate art direction was rejected by the user (2026-09-25); the pieces below show the manifest format. Milestone Tree NG+ UI kit. Built by art/ui/build.js from the Blender renders (blender/build.py) and the painters (kit.js, pieces.js, vfx.js). ' +
      'Images are 2x the 1080p display size. slice: ImageLabel.ScaleType = Slice, SliceCenter = Rect.new(sliceCenter[1..4]), SliceScale = sliceScale (x the UI scale). ' +
      'image: shown at display size, anchor = the image px placed on the reference point (frame corner / rim centre line / socket centre). tile: ScaleType.Tile, TileSize = tileSize.',
    version: 1, root: 'art/ui/out/ (file paths are relative to it; build.js regenerates the PNGs, they are not committed)', scale: SCALE, layers: Object.keys(themes.UI_THEMES), themes: themes.UI_THEMES, gold: themes.UI_GOLD, pieces, atlas,
  };
  fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 1) + '\n');
  console.log(`${Object.keys(pieces).length} pieces -> ui.json (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
