// video.js - the Roblox video preview (silent, 1920 x 1080, 30 fps, ~25 s): real-client clips from snap_mk.luau
// with scripted camera dollies, then video_post.py crossfades them, softens the panel-open cut and lays the end card.
//   cd art/marketing && node video.js [--force] [--only name,name] [--jobs 3]   -> out/video_preview.mp4
// Segment frames are cached in work/video/<name>/ (a segment re-renders only when its spec changes or with --force).
const path = require('path'), fs = require('fs'), { execFileSync } = require('child_process');
const { clip } = require('./lib/snap');
const { withPage, setHtml } = require('./lib/page');
const { CSS, logoHtml } = require('./thumbs');
const WORK = path.join(__dirname, 'work', 'video');

// cam: "x,y,z>x,y,z" (world px and map zoom, smoothstep over the segment); zMin at 1920 x 1080 is 0.405
const FPS = 30;
const SEGMENTS = [
  // the hook: close on the glowing gems, pulling back to the whole tree
  { name: 's1_hook', scene: 's13_none', cam: '1500,1560,1.25>1470,1160,0.58', frames: 165, hide: ['hud'] },
  // the HUD fades in; points and node values climb while the camera eases in
  { name: 's2_numbers', scene: 's13_none', cam: '1470,1160,0.6>1420,1210,0.74', frames: 150, hide: [] },
  // tap the Prestige node: the P panel opens beside the map strip (tap at frame 36)
  { name: 's3_panel', scene: 'open_p@36', cam: 'keep', frames: 165, hide: ['toasts'], tapAt: 36 },
  // inside the Prestige Multiverse: glide across to the rift and into it
  { name: 's4_rift', scene: 's19mv_none', cam: '2480,1120,0.62>3110,1380,1.05', frames: 180, hide: ['hud', 'plate_pm'] },
  // the finale: pull back from the tree to the whole realm; the end card fades in over the last 2 s
  { name: 's5_realm', scene: 's13_none', cam: '1500,1300,0.95>1920,1280,0.405', frames: 165, hide: ['hud'] },
];
const XFADE = 15; // frames of crossfade between segments
const ENDCARD = 60; // frames the end card takes to fade in (then holds)

function specKey(s) { return JSON.stringify([s.scene, s.cam, s.frames, s.hide, FPS]); }
function cached(s) {
  const dir = path.join(WORK, s.name), key = path.join(dir, 'spec.json');
  if (!fs.existsSync(key) || fs.readFileSync(key, 'utf8') !== specKey(s)) return false;
  return fs.readdirSync(dir).filter(f => f.endsWith('.jpg')).length === s.frames;
}

async function renderSegment(s) {
  const dir = path.join(WORK, s.name);
  fs.rmSync(dir, { recursive: true, force: true });
  await clip({ scene: s.scene, cam: s.cam, frames: s.frames, fps: FPS, hide: s.hide, outdir: dir });
  fs.writeFileSync(path.join(dir, 'spec.json'), specKey(s));
}

async function endCard() {
  // the logo lockup on a transparent 1920 x 1080 plate (video_post.py fades it in over a darkened realm)
  const out = path.join(WORK, 'endcard.png');
  await withPage(1920, 1080, async page => {
    await setHtml(page, CSS + `html,body{background:transparent!important}
      .end{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;
        background:radial-gradient(ellipse 46% 30% at 50% 50%,rgba(7,5,13,.82) 0%,rgba(7,5,13,.55) 55%,rgba(7,5,13,0) 100%)}
      .end .logo{position:relative}
      .end .rule{position:relative;left:0;width:900px;margin-top:40px;background:linear-gradient(90deg,rgba(179,92,255,0),#b35cff,rgba(179,92,255,0))}
      .end .rule:before{display:none}`,
    `<div class="end" style="--acc:#b35cff">${logoHtml(84, 0, 0)}<div class="rule"></div></div>`);
    await page.screenshot({ path: out, omitBackground: true });
  });
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const oi = args.indexOf('--only'), only = oi >= 0 ? args[oi + 1].split(',') : null;
  const ji = args.indexOf('--jobs'), jobs = ji >= 0 ? +args[ji + 1] : 3;
  fs.mkdirSync(WORK, { recursive: true });
  const todo = SEGMENTS.filter(s => (only ? only.includes(s.name) : true) && (force || only || !cached(s)));
  console.log(`segments to render: ${todo.map(s => s.name).join(', ') || 'none (cached)'}`);
  // a small pool: each job is one Chromium + one luau process
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(jobs, todo.length) }, async () => {
    while (next < todo.length) await renderSegment(todo[next++]);
  }));
  await endCard();
  const plan = { fps: FPS, xfade: XFADE, endcard: ENDCARD, segments: SEGMENTS.map(s => ({ name: s.name, frames: s.frames, tapAt: s.tapAt })) };
  fs.writeFileSync(path.join(WORK, 'plan.json'), JSON.stringify(plan, null, 1));
  execFileSync('python3', [path.join(__dirname, 'video_post.py')], { stdio: 'inherit' });
}
if (require.main === module) main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
