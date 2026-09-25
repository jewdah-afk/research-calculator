// Record the realm preview (preview/realm.html) along a scripted camera path.
//
//   node preview/record.js                      -> out/realm_preview.webm (20 s, 1920x1080, 30 fps) + out/realm_*.png (6 stills)
//   node preview/record.js --mode video         Playwright recordVideo in real time (smooth only on a GPU machine)
//   node preview/record.js --stills-only        just the 6 stills
//   node preview/record.js --serve [--port N]   serve art/ and print the simulator URL (interactive: drag, wheel, keys)
//   options: --tier HIGH|LOW  --fps 30  --seconds 20  --size 1920x1080  --out out/realm_preview.webm  --source tiles|layers
//
// The path: start at the tree base, drift up the trunk to the crown, pull out to the whole realm, pan east to the
// Multiverse rift, then push in by the corrupted outcrop. Keys are (t, x, y, z) inside the hard camera limits of a
// 1920x1080 view; x, y and ln z are interpolated with monotone cubics (no overshoot past a clamp), then hard-clamped.
//
// Frames mode (default) is deterministic: frame i is drawn at t = i / fps with the biome weights eased by exactly
// 1 / fps per frame, captured as a JPEG screenshot and piped to the ffmpeg that ships with Playwright (the same VP8
// encoder recordVideo uses, but at a high bitrate and without dropped frames). Video mode is the literal
// recordVideo capture: the page draws as fast as it can and the camera follows wall-clock time.
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path'); const http = require('http');
const { spawn } = require('child_process');

const ART = path.resolve(__dirname, '..'), OUT = path.join(ART, 'out');
const GL_ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'];
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.png': 'image/png',
  '.webp': 'image/webp', '.jpg': 'image/jpeg', '.webm': 'video/webm', '.css': 'text/css', '.md': 'text/markdown; charset=utf-8' };

/** Static server over art/ (the page fetches realm.json, the manifest, tiles and renders). */
function serve(port = 0) {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const u = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      const f = path.normalize(path.join(ART, u === '/' ? '/preview/realm.html' : u));
      if (!f.startsWith(ART) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { rsp.writeHead(404); rsp.end('not found'); return; }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'Content-Length': fs.statSync(f).size });
      if (req.method === 'HEAD') { rsp.end(); return; }
      fs.createReadStream(f).pipe(rsp);
    });
    srv.listen(port, '127.0.0.1', () => res({ url: `http://127.0.0.1:${srv.address().port}`, close: () => new Promise(r => srv.close(r)) }));
  });
}

const launch = () => chromium.launch({ args: GL_ARGS });

/** Open the simulator at a viewport. q: URL options (tier, source, nodes, rm, ...). Resolves once every texture is up. */
async function openRealm(browser, base, { w = 1920, h = 1080, dpr = 1, q = {}, context = {} } = {}) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, ...context });
  const page = await ctx.newPage();
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  const qs = new URLSearchParams({ clock: 'manual', hud: '0', ...q }).toString();
  await page.goto(`${base}/preview/realm.html?${qs}`);
  try { await page.evaluate(() => window.Realm.ready); }
  catch (e) { throw new Error('realm.html failed: ' + errs.concat(e.message).join('\n')); }
  return { ctx, page, errs };
}

// ------------------------------------------------------------------------------------------------ camera path
const KEYS = [ // t (s), x, y (world px), z
  [0.0, 1500, 1900, 1.08],     // the tree base: roots, the island's crystal lip, the lowest nodes
  [2.6, 1500, 1520, 1.02],
  [5.2, 1500, 940, 0.96],      // up the trunk to the crown
  [6.2, 1560, 880, 0.90],
  [9.2, 1920, 1280, 0.50],     // the whole realm (zMin at 1920x1080)
  [10.6, 1920, 1320, 0.50],
  [14.2, 2620, 1400, 0.80],    // east: the mood turns crimson
  [15.8, 2820, 1400, 0.95],    // the Multiverse rift
  [20.0, 3070, 1290, 1.25],    // push in by the corrupted outcrop (the camera's east limit at this zoom)
];
/** Monotone cubic (Fritsch-Carlson) through (ts, ys), zero slope at both ends. */
function monotone(ts, ys) {
  const n = ts.length, d = [], m = new Array(n).fill(0);
  for (let i = 0; i < n - 1; i++) d.push((ys[i + 1] - ys[i]) / (ts[i + 1] - ts[i]));
  for (let i = 1; i < n - 1; i++) m[i] = d[i - 1] * d[i] <= 0 ? 0 : (3 * (ts[i + 1] - ts[i - 1])) / ((2 * ts[i + 1] - ts[i] - ts[i - 1]) / d[i - 1] + (ts[i + 1] + ts[i] - 2 * ts[i - 1]) / d[i]);
  return t => {
    if (t <= ts[0]) return ys[0]; if (t >= ts[n - 1]) return ys[n - 1];
    let i = 0; while (t > ts[i + 1]) i++;
    const h = ts[i + 1] - ts[i], u = (t - ts[i]) / h, u2 = u * u, u3 = u2 * u;
    return (2 * u3 - 3 * u2 + 1) * ys[i] + (u3 - 2 * u2 + u) * h * m[i] + (-2 * u3 + 3 * u2) * ys[i + 1] + (u3 - u2) * h * m[i + 1];
  };
}
function cameraPath(keys = KEYS, seconds = 20) {
  const k = keys[keys.length - 1][0], ts = keys.map(q => q[0] * seconds / k);
  const X = monotone(ts, keys.map(q => q[1])), Y = monotone(ts, keys.map(q => q[2])), Z = monotone(ts, keys.map(q => Math.log(q[3])));
  return t => ({ x: X(t), y: Y(t), z: Math.exp(Z(t)) });
}
const STILLS = [ // name, time on the 20 s path
  ['realm_1_tree_base', 0.4], ['realm_2_trunk', 5.2], ['realm_3_overview', 9.9], ['realm_4_toward_rift', 13.4], ['realm_5_rift', 15.9], ['realm_6_outcrop', 19.9],
];

function ffmpegPath() {
  const cands = [process.env.FFMPEG];
  try { const reg = require(path.join(path.dirname(require.resolve('playwright-core/package.json')), 'lib/server/registry/index.js'));
    const e = reg.registry.findExecutable('ffmpeg'); if (e) cands.push(e.executablePath()); } catch (e) { /* older layout */ }
  const roots = [process.env.PLAYWRIGHT_BROWSERS_PATH, '/opt/pw-browsers', path.join(require('os').homedir(), '.cache/ms-playwright')].filter(Boolean);
  for (const r of roots) if (fs.existsSync(r)) for (const d of fs.readdirSync(r)) if (d.startsWith('ffmpeg')) cands.push(path.join(r, d, 'ffmpeg-linux'), path.join(r, d, 'ffmpeg-mac'), path.join(r, d, 'ffmpeg-win64.exe'));
  cands.push('ffmpeg');
  return cands.find(c => c && (c === 'ffmpeg' || fs.existsSync(c)));
}

function parse(argv) {
  const o = { mode: 'frames', tier: 'HIGH', fps: 30, seconds: 20, w: 1920, h: 1080, out: path.join(OUT, 'realm_preview.webm'), stills: true, stillsOnly: false,
    serve: false, port: 0, source: 'tiles', bitrate: '9M' };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    if (a === '--mode') o.mode = v(); else if (a === '--tier') o.tier = v().toUpperCase(); else if (a === '--fps') o.fps = +v();
    else if (a === '--seconds') o.seconds = +v(); else if (a === '--size') [o.w, o.h] = v().split('x').map(Number);
    else if (a === '--out') o.out = path.resolve(v()); else if (a === '--no-stills') o.stills = false; else if (a === '--stills-only') o.stillsOnly = true;
    else if (a === '--serve') o.serve = true; else if (a === '--port') o.port = +v(); else if (a === '--source') o.source = v();
    else if (a === '--bitrate') o.bitrate = v();
    else throw new Error('unknown argument ' + a);
  }
  return o;
}

async function stills(page, cam, o, fps) {
  // replay the path up to each still so the eased biome weights match the video frame exactly
  let i = 0; const out = [];
  const frames = STILLS.map(([name, t]) => [name, Math.round(t * o.seconds / 20 * fps)]);
  const last = Math.max(...frames.map(f => f[1]));
  for (; i <= last; i++) {
    const t = i / fps, c = cam(t);
    await page.evaluate(a => window.Realm.frame(a), { ...c, t, dt: 1 / fps, settle: i === 0 });
    for (const [name, fi] of frames) if (fi === i) {
      const f = path.join(OUT, name + '.png'); await page.screenshot({ path: f, type: 'png' }); out.push(path.relative(ART, f));
    }
  }
  return out;
}

async function recordFrames(browser, base, o) {
  const { ctx, page } = await openRealm(browser, base, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source } });
  const cam = cameraPath(KEYS, o.seconds), n = Math.round(o.seconds * o.fps), ff = ffmpegPath();
  if (!ff) throw new Error('no ffmpeg found (Playwright ships one: npx playwright install ffmpeg)');
  fs.mkdirSync(path.dirname(o.out), { recursive: true });
  const args = ['-loglevel', 'error', '-f', 'image2pipe', '-c:v', 'mjpeg', '-framerate', String(o.fps), '-i', 'pipe:0',
    '-c:v', 'vp8', '-b:v', o.bitrate, '-crf', '6', '-qmin', '0', '-qmax', '36', '-deadline', 'good', '-cpu-used', '1', '-auto-alt-ref', '1',
    '-lag-in-frames', '16', '-pix_fmt', 'yuv420p', '-r', String(o.fps), '-y', o.out];
  const enc = spawn(ff, args, { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((res, rej) => enc.on('close', c => (c ? rej(new Error('ffmpeg exit ' + c)) : res())));
  const still = new Map(STILLS.map(([name, t]) => [Math.round(t * o.seconds / 20 * o.fps), name]));
  const t0 = Date.now(), shots = [];
  for (let i = 0; i < n; i++) {
    const t = i / o.fps, c = cam(t);
    await page.evaluate(a => window.Realm.frame(a), { ...c, t, dt: 1 / o.fps, settle: i === 0 });
    const jpg = await page.screenshot({ type: 'jpeg', quality: 95 });
    if (!enc.stdin.write(jpg)) await new Promise(r => enc.stdin.once('drain', r));
    if (o.stills && still.has(i)) { const f = path.join(OUT, still.get(i) + '.png'); await page.screenshot({ path: f, type: 'png' }); shots.push(path.relative(ART, f)); }
    if (i % 60 === 0) process.stdout.write(`  frame ${i}/${n}  ${((Date.now() - t0) / 1000).toFixed(0)} s\r`);
  }
  enc.stdin.end(); await done; await ctx.close();
  console.log(`\nframes: ${n} at ${o.fps} fps in ${((Date.now() - t0) / 1000).toFixed(0)} s -> ${path.relative(ART, o.out)} (${(fs.statSync(o.out).size / 1048576).toFixed(1)} MB)`);
  return shots;
}

async function recordVideo(browser, base, o) {
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'realm-video-'));
  const { ctx, page } = await openRealm(browser, base, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source }, context: { recordVideo: { dir, size: { width: o.w, height: o.h } } } });
  const cam = cameraPath(KEYS, o.seconds);
  const start = Date.now(); let frames = 0, prev = 0;
  for (;;) {
    const t = (Date.now() - start) / 1000; if (t > o.seconds) break;
    await page.evaluate(a => window.Realm.frame(a), { ...cam(t), t, dt: t - prev, settle: frames === 0 }); prev = t; frames++;
  }
  const video = page.video(); await ctx.close();
  fs.mkdirSync(path.dirname(o.out), { recursive: true });
  await video.saveAs(o.out); fs.rmSync(dir, { recursive: true, force: true });
  console.log(`recordVideo: ${frames} frames drawn in ${o.seconds} s (${(frames / o.seconds).toFixed(1)} fps) -> ${path.relative(ART, o.out)}`);
}

async function main() {
  const o = parse(process.argv.slice(2));
  const srv = await serve(o.port);
  if (o.serve) { console.log(`realm simulator: ${srv.url}/preview/realm.html   (Ctrl+C to stop)`); return; }
  const browser = await launch();
  try {
    let shots = [];
    if (o.stillsOnly) {
      const { ctx, page } = await openRealm(browser, srv.url, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source } });
      shots = await stills(page, cameraPath(KEYS, o.seconds), o, o.fps); await ctx.close();
    } else if (o.mode === 'video') {
      await recordVideo(browser, srv.url, o);
      if (o.stills) { const { ctx, page } = await openRealm(browser, srv.url, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source } }); shots = await stills(page, cameraPath(KEYS, o.seconds), o, o.fps); await ctx.close(); }
    } else shots = await recordFrames(browser, srv.url, o);
    if (shots.length) console.log('stills: ' + shots.join(', '));
  } finally { await browser.close(); await srv.close(); }
}

module.exports = { serve, launch, openRealm, cameraPath, KEYS, STILLS, GL_ARGS };
if (require.main === module) main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
