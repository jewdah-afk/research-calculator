// record.js - render the prestige clip: every frame of clip.js in headless Chromium, the UI sounds mixed on the
// same timeline (CLIP.EVENTS), encoded to H.264 + AAC with the ffmpeg bundled in imageio-ffmpeg.
//
//   cd art/ui && NODE_PATH=$(npm root -g) node clip/record.js [--fps 30] [--only 3.0,3.1] [--ffmpeg /path/to/ffmpeg]
//
// -> previews/prestige_clip.mp4 (+ out/clip/frames/*.jpg, out/clip/mix.wav). --only renders just those times as PNG
// stills into out/clip/ (to look at single moments).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { serve } = require('../samples/render.js');
const UI = path.join(__dirname, '..'), OUT = path.join(UI, 'out', 'clip');
const B = '/tmp/claude-0/-home-user-research-calculator/aa7dc241-c574-5f16-888c-42eeb5b35dc8/scratchpad/blender';

function ffmpegPath(argv) {
  const i = argv.indexOf('--ffmpeg'); if (i >= 0) return argv[i + 1];
  if (process.env.FFMPEG) return process.env.FFMPEG;
  for (const py of [path.join(B, 'venv/bin/python'), 'python3']) {
    try { return execFileSync(py, ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim(); } catch (e) { /* next */ }
  }
  return 'ffmpeg';
}

// ------------------------------------------------------------------------------------------------ audio
function readWav(f) {
  const b = fs.readFileSync(f); let o = 12, fmt = null, data = null;
  while (o < b.length) { const id = b.toString('ascii', o, o + 4), n = b.readUInt32LE(o + 4); if (id === 'fmt ') fmt = { ch: b.readUInt16LE(o + 10), sr: b.readUInt32LE(o + 12), bits: b.readUInt16LE(o + 22) }; if (id === 'data') data = b.subarray(o + 8, o + 8 + n); o += 8 + n + (n & 1); }
  if (!fmt || fmt.bits !== 16) throw new Error('16-bit wav expected: ' + f);
  const n = data.length / 2 / fmt.ch, L = new Float32Array(n), R = new Float32Array(n);
  for (let i = 0; i < n; i++) { L[i] = data.readInt16LE(i * 2 * fmt.ch) / 32768; R[i] = data.readInt16LE(i * 2 * fmt.ch + (fmt.ch > 1 ? 2 : 0)) / 32768; }
  return { sr: fmt.sr, L, R };
}
function mix(events, dur, file) {
  const sr = 48000, n = Math.round(dur * sr), L = new Float32Array(n), R = new Float32Array(n);
  for (const [name, at] of events) {
    const w = readWav(path.join(UI, 'sfx', name + '.wav')); if (w.sr !== sr) throw new Error('48 kHz expected');
    const o = Math.round(at * sr);
    for (let i = 0; i < w.L.length && o + i < n; i++) { L[o + i] += w.L[i]; R[o + i] += w.R[i]; }
  }
  let pk = 0; for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(L[i]), Math.abs(R[i]));
  const g = Math.min(1, 0.891 / pk);                    // peak <= -1 dBFS
  const fade = Math.round(0.25 * sr);
  const buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
  buf.writeUInt32LE(sr, 24); buf.writeUInt32LE(sr * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    const f = i > n - fade ? (n - i) / fade : 1;
    buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(L[i] * g * f * 32767))), 44 + i * 4);
    buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(R[i] * g * f * 32767))), 46 + i * 4);
  }
  fs.writeFileSync(file, buf);
  return 20 * Math.log10(pk * g);
}

(async () => {
  const argv = process.argv.slice(2);
  const fps = +(argv[argv.indexOf('--fps') + 1] || 30) || 30;
  const only = argv.includes('--only') ? argv[argv.indexOf('--only') + 1].split(',').map(Number) : null;
  fs.mkdirSync(path.join(OUT, 'frames'), { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  page.on('pageerror', e => console.log('pageerror', e.message));
  await serve(page);
  await page.goto('http://ui.local/ui/samples/page.html');
  await page.addScriptTag({ url: 'http://ui.local/ui/clip/clip.js' });
  await page.addScriptTag({ url: 'http://ui.local/lib.js' });
  const meta = await page.evaluate(async () => { await O.load(); await CLIP.setup(); await document.fonts.ready; return { dur: CLIP.DURATION, events: CLIP.EVENTS }; });
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => Promise.all([...document.images].map(im => im.complete ? 1 : new Promise(r => { im.onload = im.onerror = r; }))));
  if (only) {
    for (const t of only) { await page.evaluate(t => CLIP.frame(t), t); await page.screenshot({ path: path.join(OUT, `t_${t.toFixed(2)}.png`) }); console.log('still', t); }
    await browser.close(); return;
  }
  const N = Math.round(meta.dur * fps), t0 = Date.now();
  for (let i = 0; i < N; i++) {
    await page.evaluate(t => CLIP.frame(t), i / fps);
    await page.screenshot({ path: path.join(OUT, 'frames', `f_${String(i).padStart(4, '0')}.jpg`), type: 'jpeg', quality: 94 });
    if (i % 30 === 0) console.log(`frame ${i}/${N} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
  }
  await browser.close();
  const wav = path.join(OUT, 'mix.wav');
  const pk = mix(meta.events, meta.dur, wav);
  console.log(`audio mix: ${meta.events.length} cues, peak ${pk.toFixed(1)} dBFS`);
  const ff = ffmpegPath(argv), mp4 = path.join(UI, 'previews', 'prestige_clip.mp4');
  execFileSync(ff, ['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', path.join(OUT, 'frames', 'f_%04d.jpg'), '-i', wav,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-shortest', mp4]);
  console.log(`-> ${path.relative(UI, mp4)} (${(fs.statSync(mp4).size / 1048576).toFixed(1)} MB)`);
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
