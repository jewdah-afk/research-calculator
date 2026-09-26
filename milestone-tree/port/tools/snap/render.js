// render.js - draw snap.luau dumps in headless Chromium and save a JPG (or PNG) per scene.
//
//   cd port && export NODE_PATH=$(npm root -g)
//   node tools/snap/render.js data/snap/home.json out.jpg        one dump
//   node tools/snap/render.js --scenes home,panel_p [--out DIR]  run snap.luau for each scene, then draw them
//
// Asset ids resolve through art/roblox/uploaded.json (the realm tiles and atlas: run `node roblox/tile.js` in art/
// once so the files exist), art/ui/uploaded.json when present, art/products (the shop icons), and art/gems (the gem sprites) by file name.
// Unknown ids are listed after the run and drawn as nothing (like an id the engine cannot load).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const PORT = path.join(__dirname, '..', '..'), ART = path.join(PORT, '..', 'art');

function assetMap() {
  const map = {};
  const add = (id, file) => { if (id && file && fs.existsSync(file)) map['rbxassetid://' + String(id).replace(/^rbxassetid:\/\//, '')] = 'http://snap.local/f/' + encodeURIComponent(file); };
  for (const [manifest, base] of [[path.join(ART, 'roblox', 'uploaded.json'), path.join(ART, 'roblox')], [path.join(ART, 'ui', 'uploaded.json'), path.join(ART, 'ui')], [path.join(ART, 'gems', 'uploaded.json'), path.join(ART, 'gems')], [path.join(ART, 'substance', 'uploaded.json'), path.join(ART, 'substance')], [path.join(ART, 'products', 'uploaded.json'), path.join(ART, 'products')]]) {
    if (!fs.existsSync(manifest)) continue;
    const j = JSON.parse(fs.readFileSync(manifest, 'utf8'));
    for (const a of Object.values(j.assets || j)) if (a && a.assetId && a.file) add(a.assetId, path.join(base, a.file));
  }
  return map;
}
// the ScreenInsets rects at 1920 x 1080 (x, y, w, h): the Roblox top bar is 58 tall; its buttons take the corners
function insets(w, h) {
  return { None: [0, 0, w, h], DeviceSafeInsets: [0, 0, w, h], CoreUISafeInsets: [0, 58, w, h - 58], TopbarSafeInsets: [136, 0, w - 136 - 76, 58] };
}

function serveRoute(route) {
  const u = new URL(route.request().url());
  let file;
  if (u.pathname === '/') return route.fulfill({ contentType: 'text/html', body: PAGE });
  if (u.pathname.startsWith('/f/')) file = decodeURIComponent(u.pathname.slice(3));
  else if (u.pathname.startsWith('/fonts/')) file = path.join(ART, 'ui', 'fonts', path.basename(u.pathname));
  else if (u.pathname === '/page.js') file = path.join(__dirname, 'page.js');
  if (!file || !fs.existsSync(file)) return route.fulfill({ status: 404, body: '' });
  return route.fulfill({ body: fs.readFileSync(file), contentType: file.endsWith('.js') ? 'text/javascript' : file.endsWith('.woff2') ? 'font/woff2' : 'image/png' });
}

async function draw(browser, dump, out) {
  const page = await browser.newPage({ viewport: { width: dump.w, height: dump.h } });
  page.on('pageerror', e => console.log('pageerror', e.message));
  await page.route('http://snap.local/**', route => serveRoute(route));
  await page.goto('http://snap.local/');
  const res = await page.evaluate(([d, a, i]) => SNAP.draw(d, a, i), [dump, assetMap(), insets(dump.w, dump.h)]);
  await page.waitForTimeout(100);
  const jpg = out.endsWith('.jpg');
  await page.screenshot({ path: out, type: jpg ? 'jpeg' : 'png', quality: jpg ? 90 : undefined });
  await page.close();
  return res;
}

const FONTS = [
  ['Montserrat', 600, 'normal', 'montserrat-latin-600-normal'], ['Montserrat', 700, 'normal', 'montserrat-latin-700-normal'],
  ['Montserrat', 700, 'italic', 'montserrat-latin-700-italic'], ['Montserrat', 800, 'normal', 'montserrat-latin-800-normal'],
  ['Montserrat', 800, 'italic', 'montserrat-latin-800-italic'], ['Montserrat', 900, 'normal', 'montserrat-latin-900-normal'],
  ['Montserrat', 900, 'italic', 'montserrat-latin-900-italic'], ['Sarpanch', '100 900', 'normal', 'sarpanch-latin-700-normal'],
  ['RobotoMono', '100 600', 'normal', 'roboto-mono-latin-500-normal'], ['RobotoMono', '700 900', 'normal', 'roboto-mono-latin-700-normal'],
];
const PAGE = `<!doctype html><html><head><meta charset="utf-8"><style>
${FONTS.map(([f, w, s, file]) => `@font-face{font-family:${f};font-weight:${w};font-style:${s};src:url(/fonts/${file}.woff2)}`).join('\n')}
html,body{margin:0;background:#000}*{box-sizing:border-box}.g{margin:0}.tx{font-kerning:normal}
</style></head><body><div id="root"></div><script src="/page.js"></script></body></html>`;

// a clip: one snap.luau run with a pinned clock per frame, drawn on one page (images stay cached), cropped, encoded
// to H.264 MP4 with the ffmpeg from `pip install imageio-ffmpeg`
async function clip(browser, scene, size, n, fps, crop, out) {
  const [w, h] = size.split('x').map(Number);
  const text = execFileSync(process.env.LUAU || 'luau', ['tools/snap/snap.luau', '-a', scene, size, `clip:${n}:${fps}`], { cwd: PORT, maxBuffer: 1 << 30 }).toString();
  const dumps = text.split('\n').filter(l => l.startsWith('{"scene"'));
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
  await page.route('http://snap.local/**', route => serveRoute(route));
  await page.goto('http://snap.local/');
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'snapclip-'));
  for (let i = 0; i < dumps.length; i++) {
    await page.evaluate(([d, a, ins]) => SNAP.draw(d, a, ins), [JSON.parse(dumps[i]), assetMap(), insets(w, h)]);
    await page.screenshot({ path: path.join(dir, `f${String(i).padStart(4, '0')}.png`), clip: crop });
  }
  await page.close();
  const ff = execFileSync('python3', ['-c', 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim();
  execFileSync(ff, ['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', path.join(dir, 'f%04d.png'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    '-crf', '20', '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', out]);
  fs.rmSync(dir, { recursive: true, force: true });
  console.log(`${scene}: ${out} (${dumps.length} frames)`);
}

async function main() {
  const args = process.argv.slice(2);
  const browser = await chromium.launch();
  const ci = args.indexOf('--clip');
  if (ci >= 0) {
    // --clip scene:frames:fps:x,y,w,h out.mp4 [--size WxH]
    const [scene, n, fps, box] = args[ci + 1].split(':');
    const [x, y, cw, ch] = box.split(',').map(Number);
    const vi = args.indexOf('--size');
    await clip(browser, scene, vi >= 0 ? args[vi + 1] : '1920x1080', +n, +fps, { x, y, width: cw, height: ch }, args[ci + 2]);
    await browser.close();
    return;
  }
  const si = args.indexOf('--scenes');
  if (si >= 0) {
    const oi = args.indexOf('--out'), outDir = oi >= 0 ? args[oi + 1] : path.join(PORT, 'data', 'snap');
    const vi = args.indexOf('--size'), size = vi >= 0 ? args[vi + 1] : '1920x1080';
    fs.mkdirSync(outDir, { recursive: true });
    for (const scene of args[si + 1].split(',')) {
      const json = execFileSync(process.env.LUAU || 'luau', ['tools/snap/snap.luau', '-a', scene, size], { cwd: PORT, maxBuffer: 1 << 28 }).toString();
      const line = json.split('\n').find(l => l.startsWith('{"scene"'));
      if (!line) { console.log(json.slice(0, 2000)); throw new Error('no dump for ' + scene); }
      const dump = JSON.parse(line);
      const out = path.join(outDir, `${scene}${size === '1920x1080' ? '' : '_' + size}.jpg`);
      const res = await draw(browser, dump, out);
      console.log(`${scene}: ${out}  (script errors ${dump.errors}; missing assets ${res.missing.length}${res.missing.length ? ': ' + res.missing.slice(0, 6).join(' ') : ''})`);
    }
  } else {
    const dump = JSON.parse(fs.readFileSync(args[0], 'utf8'));
    const res = await draw(browser, dump, args[1] || 'snap.jpg');
    console.log('missing assets', res.missing);
  }
  await browser.close();
}
if (require.main === module) main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
module.exports = { assetMap, insets, serveRoute };
