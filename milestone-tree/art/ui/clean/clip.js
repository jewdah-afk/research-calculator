// clip.js - record the energy-ring clip: CLEAN.clipFrame(t) for every frame of 6 s at 30 fps in headless Chromium,
// encoded to H.264 (no audio) with the ffmpeg of imageio-ffmpeg, like the kit's clip/record.js.
//
//   cd art/ui && NODE_PATH=$(npm root -g) node clean/clip.js [--fps 30] [--only 0.3,1.2] [--ffmpeg /path/to/ffmpeg]
//
// -> clean/out/nodes_pulse.mp4 (committed; frames in clean/out/frames are scratch). --only writes stills t_<t>.png.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { openPage, settle } = require('./render.js');
const OUT = path.join(__dirname, 'out'), FR = path.join(OUT, 'frames');
const B = '/tmp/claude-0/-home-user-research-calculator/aa7dc241-c574-5f16-888c-42eeb5b35dc8/scratchpad/blender';

function ffmpegPath(argv) {   // same lookup as clip/record.js
  const i = argv.indexOf('--ffmpeg'); if (i >= 0) return argv[i + 1];
  if (process.env.FFMPEG) return process.env.FFMPEG;
  for (const py of [path.join(B, 'venv/bin/python'), 'python3']) {
    try { return execFileSync(py, ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim(); } catch (e) { /* next */ }
  }
  return 'ffmpeg';
}

(async () => {
  const argv = process.argv.slice(2);
  const fps = +(argv[argv.indexOf('--fps') + 1] || 30) || 30;
  const only = argv.includes('--only') ? argv[argv.indexOf('--only') + 1].split(',').map(Number) : null;
  const browser = await chromium.launch();
  const page = await openPage(browser, [1280, 720]);
  const { dur } = await page.evaluate(() => CLEAN.clipSetup());
  await settle(page);
  if (only) {
    for (const t of only) { await page.evaluate(t => CLEAN.clipFrame(t), t); await page.screenshot({ path: path.join(OUT, `t_${t.toFixed(2)}.png`) }); console.log('still', t); }
    await browser.close(); return;
  }
  fs.rmSync(FR, { recursive: true, force: true }); fs.mkdirSync(FR, { recursive: true });
  const N = Math.round(dur * fps), t0 = Date.now();
  for (let i = 0; i < N; i++) {
    await page.evaluate(t => CLEAN.clipFrame(t), i / fps);
    await page.screenshot({ path: path.join(FR, `f_${String(i).padStart(4, '0')}.png`) });
    if (i % 30 === 0) console.log(`frame ${i}/${N} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
  }
  await browser.close();
  const mp4 = path.join(OUT, 'nodes_pulse.mp4');
  execFileSync(ffmpegPath(argv), ['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', path.join(FR, 'f_%04d.png'),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', mp4]);
  fs.rmSync(FR, { recursive: true, force: true });
  console.log(`-> ${path.relative(path.join(__dirname, '..'), mp4)} (${(fs.statSync(mp4).size / 1048576).toFixed(2)} MB, ${N} frames)`);
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
