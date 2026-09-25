// Record the realm preview (preview/realm.html) along a scripted camera path.
//
//   node preview/record.js                      -> out/realm_preview.webm (27 s, drawn at 1920x1080, encoded at 960x540, 30 fps)
//                                                  + out/realm_[1-6]_*.jpg (six 1920x1080 stills) + the rest-motion report
//   node preview/record.js --mode video         Playwright recordVideo in real time (smooth only on a GPU machine)
//   node preview/record.js --stills-only        just the 6 stills (and the rest-motion report)
//   node preview/record.js --rest-only          just the rest-motion report
//   node preview/record.js --serve [--port N]   serve art/ and print the simulator URL (interactive: drag, wheel, keys)
//   options: --tier HIGH|LOW  --fps 30  --seconds 27 (rescales the path)  --size 1920x1080 (drawn)  --video-size 960x540
//            (encoded; `same` keeps the drawn size)  --bitrate 1.8M  --stills jpg|png  --out out/realm_preview.webm
//            --source tiles|layers  --workers 2 (browsers drawing frames in parallel)  --no-stills  --no-rest-check
//
// The path: rest at the tree base, drift up the trunk to the crown, pull out to the whole realm, pan east to the
// Multiverse rift and rest there, then push in by the corrupted outcrop and rest. Keys are (t, x, y, z) inside the hard
// camera limits of a 1920x1080 view; x, y and ln z are interpolated with monotone cubics (no overshoot past a clamp,
// and a repeated key is an exact hold), then hard-clamped. The holds are where the player spends most of the time: the
// camera is still, so only the ambient motion moves (twinkles, fireflies, wisps, light-fall shimmer, the rift pulse and
// ring, glitch bars). After recording, the rest-motion report measures it on each hold: the share of pixels that
// change by more than 8/255 (and 24/255) over 1 s with the camera still.
//
// Frames mode (default) is deterministic: frame i is drawn at t = i / fps with the biome weights eased by exactly
// 1 / fps per frame (precomputed, so several browsers can draw frames in parallel), read back from the canvas as a
// JPEG and piped to the ffmpeg that ships with Playwright (VP8, the only encoder it has), which downscales to the
// video size. The committed preview is small on purpose (about 5 MB; REALM.md reviews use the stills for detail).
// Video mode is the literal recordVideo capture: the page draws as fast as it can and the camera follows wall-clock
// time.
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
const KEYS = [ // t (s), x, y (world px), z. A repeated key is a rest hold: the camera stands still, the ambient motion plays
  [0.0, 1500, 1900, 1.08],     // the tree base: roots, the island's crystal lip, the lowest nodes
  [3.0, 1500, 1900, 1.08],     //   rest: fireflies, twinkles, light-fall shimmer, wisps
  [5.6, 1500, 1520, 1.02],
  [8.2, 1500, 940, 0.96],      // up the trunk to the crown
  [9.2, 1560, 880, 0.90],
  [12.2, 1920, 1280, 0.50],    // the whole realm (zMin at 1920x1080)
  [13.6, 1920, 1320, 0.50],
  [17.2, 2620, 1400, 0.80],    // east: the mood turns crimson
  [18.8, 2820, 1400, 0.95],    // the Multiverse rift
  [21.8, 2820, 1400, 0.95],    //   rest: the rift pulse and shock ring, crimson wisps, embers
  [25.6, 3070, 1290, 1.25],    // push in by the corrupted outcrop (the camera's east limit at this zoom)
  [27.0, 3070, 1290, 1.25],    //   rest: glitch bars, green motes
];
const PATH_SECONDS = KEYS[KEYS.length - 1][0];
/** The rest holds of the path: [start, end, label] in path seconds (consecutive identical keys). */
const HOLDS = KEYS.slice(1).map((q, i) => [KEYS[i], q]).filter(([a, b]) => a[1] === b[1] && a[2] === b[2] && a[3] === b[3])
  .map(([a, b]) => [a[0], b[0], a[1] < 2300 ? 'tree base' : a[3] > 1.1 ? 'outcrop' : 'rift']);
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
function cameraPath(keys = KEYS, seconds = PATH_SECONDS) {
  const k = keys[keys.length - 1][0], ts = keys.map(q => q[0] * seconds / k);
  const X = monotone(ts, keys.map(q => q[1])), Y = monotone(ts, keys.map(q => q[2])), Z = monotone(ts, keys.map(q => Math.log(q[3])));
  return t => ({ x: X(t), y: Y(t), z: Math.exp(Z(t)) });
}
const STILLS = [ // name, time on the path (path seconds)
  ['realm_1_tree_base', 1.5], ['realm_2_trunk', 8.2], ['realm_3_overview', 12.9], ['realm_4_toward_rift', 16.4], ['realm_5_rift', 20.3], ['realm_6_outcrop', 26.5],
];
const pathTime = (t, o) => t * o.seconds / PATH_SECONDS;   // path seconds -> seconds of this recording

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
  const o = { mode: 'frames', tier: 'HIGH', fps: 30, seconds: PATH_SECONDS, w: 1920, h: 1080, vw: 960, vh: 540, out: path.join(OUT, 'realm_preview.webm'),
    stills: true, stillsOnly: false, restOnly: false, stillFormat: 'jpg', restCheck: true, serve: false, port: 0, source: 'tiles', bitrate: '1.8M', workers: 2 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    if (a === '--mode') o.mode = v(); else if (a === '--tier') o.tier = v().toUpperCase(); else if (a === '--fps') o.fps = +v();
    else if (a === '--seconds') o.seconds = +v(); else if (a === '--size') [o.w, o.h] = v().split('x').map(Number);
    else if (a === '--video-size') { const q = v(); [o.vw, o.vh] = q === 'same' ? [0, 0] : q.split('x').map(Number); }
    else if (a === '--out') o.out = path.resolve(v()); else if (a === '--no-stills') o.stills = false; else if (a === '--stills-only') o.stillsOnly = true;
    else if (a === '--stills') { o.stillFormat = v().toLowerCase(); if (!['jpg', 'png'].includes(o.stillFormat)) throw new Error('--stills jpg|png'); }
    else if (a === '--no-rest-check') o.restCheck = false; else if (a === '--rest-only') o.restOnly = true;
    else if (a === '--serve') o.serve = true; else if (a === '--port') o.port = +v(); else if (a === '--source') o.source = v();
    else if (a === '--bitrate') o.bitrate = v(); else if (a === '--workers') o.workers = Math.max(1, +v());
    else throw new Error('unknown argument ' + a);
  }
  if (!o.vw) [o.vw, o.vh] = [o.w, o.h];
  return o;
}

/** The eased biome weights of every frame, exactly as the page eases them (tau 0.35 s, settled on frame 0), so frames
 *  can be drawn in any order by several browsers. */
function biomeSeries(cam, n, fps, V = { w: 1920, h: 1080 }) {
  const RC = require(path.join(ART, 'camera.js')), B = JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8')).biomes;
  const out = []; let w = null; const a = 1 - Math.exp(-(1 / fps) / 0.35);
  for (let i = 0; i < n; i++) {
    const c = cam(i / fps), tgt = RC.biome(RC.clampCamera(c, c.z, RC.mapScale(V)), B);
    w = w ? { rift: w.rift + (tgt.rift - w.rift) * a, corrupt: w.corrupt + (tgt.corrupt - w.corrupt) * a } : tgt;
    out.push(w);
  }
  return out;
}
const frameArgs = (cam, W, i, fps) => ({ ...cam(i / fps), t: i / fps, w: W[i] });

const stillMime = o => (o.stillFormat === 'png' ? 'image/png' : 'image/jpeg');
async function stills(page, cam, o, fps) {
  const out = [], W = biomeSeries(cam, Math.round(o.seconds * fps) + 1, fps, { w: o.w, h: o.h });
  for (const [name, t] of STILLS) {
    const i = Math.round(pathTime(t, o) * fps);
    const url = await page.evaluate(([a, mime]) => { window.Realm.frame(a); return document.getElementById('gl').toDataURL(mime, 0.9); }, [frameArgs(cam, W, i, fps), stillMime(o)]);
    const f = path.join(OUT, name + '.' + o.stillFormat); fs.writeFileSync(f, Buffer.from(url.split(',')[1], 'base64')); out.push(path.relative(ART, f));
  }
  return out;
}

async function recordFrames(browser, base, o) {
  const cam = cameraPath(KEYS, o.seconds), n = Math.round(o.seconds * o.fps), ff = ffmpegPath(), W = biomeSeries(cam, n, o.fps, { w: o.w, h: o.h });
  if (!ff) throw new Error('no ffmpeg found (Playwright ships one: npx playwright install ffmpeg)');
  fs.mkdirSync(path.dirname(o.out), { recursive: true });
  // constrained quality: CRF 10 with the bitrate as the ceiling (soft art at 540p looks clean well under it)
  const scale = o.vw !== o.w || o.vh !== o.h ? ['-vf', `scale=${o.vw}:${o.vh}:flags=lanczos`] : [];
  const args = ['-loglevel', 'error', '-f', 'image2pipe', '-c:v', 'mjpeg', '-framerate', String(o.fps), '-i', 'pipe:0', ...scale,
    '-c:v', 'vp8', '-b:v', o.bitrate, '-crf', '10', '-qmin', '2', '-qmax', '40', '-deadline', 'good', '-cpu-used', '1', '-auto-alt-ref', '1', '-arnr-maxframes', '7',
    '-arnr-strength', '3', '-threads', '3', '-lag-in-frames', '25', '-g', String(o.fps * 5), '-pix_fmt', 'yuv420p', '-r', String(o.fps), '-y', o.out];
  const enc = spawn(ff, args, { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((res, rej) => enc.on('close', c => (c ? rej(new Error('ffmpeg exit ' + c)) : res())));
  const still = new Map(STILLS.map(([name, t]) => [Math.round(pathTime(t, o) * o.fps), name]));
  const t0 = Date.now(), shots = [], ready = new Map();
  let next = 0, drawn = 0;
  const flush = async () => { // frames reach the encoder in order, whichever worker drew them
    while (ready.has(next)) { const jpg = ready.get(next); ready.delete(next); next++; if (!enc.stdin.write(jpg)) await new Promise(r => enc.stdin.once('drain', r)); }
  };
  // one browser per worker (each has its own GPU process, which is where the drawing happens); frame i -> worker i % N
  const workers = await Promise.all(Array.from({ length: o.workers }, async (_, k) => {
    const b = k === 0 ? browser : await launch();
    const { ctx, page } = await openRealm(b, base, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source } });
    return { b, ctx, page, own: k > 0 };
  }));
  let flushing = Promise.resolve();
  await Promise.all(workers.map(async ({ page }, k) => {
    for (let i = k; i < n; i += o.workers) {
      while (i - next > 6 * o.workers) await new Promise(r => setTimeout(r, 20));   // keep the reorder buffer small
      const png = o.stills && still.has(i);
      // draw + read back in one call (a page screenshot would add a compositor pass: ~1.5x slower on SwiftShader)
      const url = await page.evaluate(([a, png, mime]) => { window.Realm.frame(a); const cv = document.getElementById('gl');
        return [cv.toDataURL('image/jpeg', 0.95), png ? cv.toDataURL(mime, 0.9) : null]; }, [frameArgs(cam, W, i, o.fps), png, stillMime(o)]);
      ready.set(i, Buffer.from(url[0].split(',')[1], 'base64'));
      if (png) { const f = path.join(OUT, still.get(i) + '.' + o.stillFormat); fs.writeFileSync(f, Buffer.from(url[1].split(',')[1], 'base64')); shots.push(path.relative(ART, f)); }
      flushing = flushing.then(flush);
      if (++drawn % 30 === 0) process.stdout.write(`  frame ${drawn}/${n}  ${((Date.now() - t0) / 1000).toFixed(0)} s\r`);
    }
  }));
  await flushing; await flush();
  enc.stdin.end(); await done;
  for (const w of workers) { await w.ctx.close(); if (w.own) await w.b.close(); }
  console.log(`\nframes: ${n} at ${o.fps} fps, drawn at ${o.w}x${o.h} in ${((Date.now() - t0) / 1000).toFixed(0)} s (${o.workers} workers) -> ${path.relative(ART, o.out)} ` +
    `${o.vw}x${o.vh} (${(fs.statSync(o.out).size / 1048576).toFixed(1)} MB)`);
  return shots.sort();
}

/** Rest-motion report: on each hold of the path, with the camera still and the biome weights settled, the share of
 *  pixels whose colour changes by more than 8/255 (and 24/255) over 1 s: the ambient motion alone. Up to three pairs
 *  per hold, 0.5 s apart. */
async function restCheck(page, o) {
  const cam = cameraPath(KEYS, o.seconds), n = Math.round(o.seconds * o.fps), W = biomeSeries(cam, n, o.fps, { w: o.w, h: o.h }), out = [];
  for (const [a, b, label] of HOLDS) {
    const t0 = pathTime(a, o), t1 = pathTime(b, o), pairs = [];
    // start 0.5 s into the hold (the biome weights ease with tau 0.35 s), less on a short hold; the last frame is n - 1
    const lead = Math.min(0.5, Math.max(0, (t1 - t0 - 1) / 2)), last = (n - 1) / o.fps;
    for (let s = t0 + lead; s + 1 <= Math.min(t1, last) + 1e-9 && pairs.length < 3; s += 0.5) pairs.push([Math.round(s * o.fps), Math.round((s + 1) * o.fps)]);
    if (!pairs.length) continue;
    // the settled biome weights of the held camera: the steady state at rest, so only the ambient motion differs
    const RC = require(path.join(ART, 'camera.js')), B = JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8')).biomes, c0 = cam(t0);
    const settled = RC.biome(RC.clampCamera(c0, c0.z, RC.mapScale({ w: o.w, h: o.h })), B);
    const r = [];
    for (const [i, j] of pairs) r.push(await page.evaluate(([A, B]) => {
      const cv = document.getElementById('gl');
      const grab = () => { const c = document.createElement('canvas'); c.width = cv.width; c.height = cv.height; const g = c.getContext('2d', { willReadFrequently: true }); g.drawImage(cv, 0, 0); return g.getImageData(0, 0, c.width, c.height).data; };
      window.Realm.frame(A); const P = grab(); window.Realm.frame(B); const Q = grab();
      let n8 = 0, n24 = 0; const N = P.length / 4;
      for (let k = 0; k < P.length; k += 4) { const d = Math.max(Math.abs(P[k] - Q[k]), Math.abs(P[k + 1] - Q[k + 1]), Math.abs(P[k + 2] - Q[k + 2])); if (d > 8) n8++; if (d > 24) n24++; }
      return [n8 / N, n24 / N];
    }, [{ ...frameArgs(cam, W, i, o.fps), w: settled }, { ...frameArgs(cam, W, j, o.fps), w: settled }]));
    const mean = k => r.reduce((s, v) => s + v[k], 0) / r.length, max = k => Math.max(...r.map(v => v[k]));
    const c = cam(t0);
    out.push({ label, t: [+t0.toFixed(2), +t1.toFixed(2)], cam: { x: Math.round(c.x), y: Math.round(c.y), z: +c.z.toFixed(2) }, over8: +mean(0).toFixed(4), over8max: +max(0).toFixed(4), over24: +mean(1).toFixed(4) });
  }
  console.log('rest motion (camera still, 1 s apart):');
  for (const q of out) console.log(`  ${q.label.padEnd(9)} ${q.t[0]}-${q.t[1]} s  C (${q.cam.x}, ${q.cam.y}) z ${q.cam.z}:  ${(100 * q.over8).toFixed(2)}% of pixels change > 8/255 ` +
    `(max ${(100 * q.over8max).toFixed(2)}%), ${(100 * q.over24).toFixed(2)}% > 24/255`);
  return out;
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
    let shots = [], page = null, ctx = null;
    const open = async () => { if (!page) ({ ctx, page } = await openRealm(browser, srv.url, { w: o.w, h: o.h, q: { tier: o.tier, source: o.source } })); return page; };
    if (o.restOnly) o.restCheck = true;
    else if (o.stillsOnly) shots = await stills(await open(), cameraPath(KEYS, o.seconds), o, o.fps);
    else if (o.mode === 'video') {
      await recordVideo(browser, srv.url, o);
      if (o.stills) shots = await stills(await open(), cameraPath(KEYS, o.seconds), o, o.fps);
    } else shots = await recordFrames(browser, srv.url, o);
    if (shots.length) console.log('stills: ' + shots.join(', ') + ` (${(shots.reduce((a, f) => a + fs.statSync(path.join(ART, f)).size, 0) / 1048576).toFixed(1)} MB)`);
    if (o.restCheck) await restCheck(await open(), o);
    if (ctx) await ctx.close();
  } finally { await browser.close(); await srv.close(); }
}

module.exports = { serve, launch, openRealm, cameraPath, KEYS, HOLDS, STILLS, PATH_SECONDS, GL_ARGS };
if (require.main === module) main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
