// realm25.js - a look preview of the 2.5D realm (MASTER_PLAN W2) next to today's flat map, from the same art and the
// same camera maths (camera.js layerOffset), so the only difference is what a 3D scene adds: depth of field per plane,
// bloom from the bright (HDR) sources, glowing gems, particles living at real depths, and a colour grade.
// It approximates Roblox's post chain in Canvas 2D; the real answer is the Studio spike behind Flags.REALM3D.
//
//   cd art && NODE_PATH=$(npm root -g) node preview/realm25.js [--out DIR] [--clip]
//   -> DIR/realm_now.jpg, realm_25d.jpg, realm_compare.jpg (+ realm_25d.mp4 with --clip; needs imageio-ffmpeg)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ART = path.resolve(__dirname, '..');
const CAM = require(path.join(ART, 'camera.js'));
const REALM = require(path.join(ART, 'realm.json'));
const MAN = require(path.join(ART, 'roblox', 'manifest.json'));
const NODE_ATLAS = require(path.join(ART, 'gems', 'node_atlas.json'));

const HUES = { m: '#b35cff', mm: '#d17aff', em: '#e88af2', p: '#6fc3ff', pe: '#ff9a2e', sp: '#5fe0ff', pb: '#57e0b0', pp: '#ff4d6d',
  se: '#ff6a1f', hp: '#7fd9ff', ep: '#9be02c', hb: '#6dffb0', ap: '#8ff3f3', mp: '#ff5a1f', t: '#ffe93a', ach: '#ffc93c' };
// the tree's nodes as in the approved home stills (states from the S13 save): ready / buy / idle / locked
const STATE = { m: 'idle', mm: 'ready', p: 'idle', pe: 'buy', sp: 'buy', pb: 'locked', pp: 'idle', se: 'buy', hp: 'idle', ep: 'ready',
  hb: 'locked', ap: 'idle', mp: 'ready', t: 'idle', ach: 'idle' };

const PAGE = `<!doctype html><html><body style="margin:0;background:#000"><canvas id="c" width="1920" height="1080"></canvas><script>
const V = { w: 1920, h: 1080 };
const img = {};
function load(k, url) { return new Promise(r => { const i = new Image(); i.onload = () => { img[k] = i; r(); }; i.src = url; }); }
function off(w = V.w, h = V.h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function rng(s) { return () => { s |= 0; s = s + 0x6D2B79F5 | 0; let t = Math.imul(s ^ s >>> 15, 1 | s); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const rgba = (h, a) => { const [r, g, b] = hex(h); return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')'; };

// motes: the same seeded set in both modes; in 2.5D each lives at its own depth (parallax, size, focus blur)
const R = rng(7), MOTES = [];
for (let i = 0; i < 320; i++) MOTES.push({ x: R() * 3840, y: R() * 2560, f: 0.3 + R() * 1.4, s: 0.6 + R() * 1.6, ph: R() * 6.28, hue: R() < 0.55 ? '#ffd9a8' : R() < 0.5 ? '#b9a8ff' : '#9fe8ff', sp: 4 + R() * 10 });

window.draw = async function (o) {
  const { layers, C, z, t, deep, nodes, atlasRects, ringR } = o;
  const out = document.getElementById('c'), X = out.getContext('2d');
  X.fillStyle = '#05030b'; X.fillRect(0, 0, V.w, V.h);
  // per-plane focus blur (px) in 2.5D: the world plane is in focus, depth softens the rest, the foreground most
  const BLUR = { sky: 1.2, clouds: 1.6, far: 1.3, mid: 0.7, near: 0.5, world: 0, fg: 6 };
  const worldCanvas = off();
  for (const L of layers) {
    const c = off(), x = c.getContext('2d');
    x.drawImage(img[L.id], L.ox, L.oy, L.w, L.h);
    if (L.id === 'world') {
      // the nodes sit in the world plane: crystal + energy ring (2.5D: the gem also lights its socket)
      for (const n of nodes) {
        const s = L.scale, px = L.ox + n.x * s, py = L.oy + n.y * s, R = 66 * s, G = 128 * s;
        const hue = n.hue, st = n.st;
        if (deep && st !== 'locked') {
          const g = x.createRadialGradient(px, py, 0, px, py, R * 1.6);
          g.addColorStop(0, rgba(hue, st === 'ready' ? 0.55 : 0.35)); g.addColorStop(1, rgba(hue, 0));
          x.globalCompositeOperation = 'lighter'; x.fillStyle = g; x.beginPath(); x.arc(px, py, R * 1.6, 0, 6.29); x.fill();
          x.globalCompositeOperation = 'source-over';
        }
        const r = atlasRects[st === 'locked' ? n.key + '_locked' : n.key] || atlasRects[n.key];
        x.drawImage(img.atlas, r[0], r[1], r[2], r[3], px - G / 2, py - G / 2, G, G);
        const ring = st === 'locked' ? '#a39cb3' : hue;
        x.lineWidth = Math.max(1.2, (st === 'ready' ? 3 : 2) * s);
        x.strokeStyle = rgba(ring, st === 'locked' ? 0.35 : 0.9);
        if (deep && st !== 'locked') { x.shadowColor = hue; x.shadowBlur = 14 * s; }
        x.beginPath(); x.arc(px, py, R, 0, 6.29); x.stroke(); x.shadowBlur = 0;
        if (st === 'buy') { // the comet on the ring
          const a = t / 1.5 * 6.283 - 1.57; x.strokeStyle = '#ffffff'; x.lineWidth = 3 * s;
          x.beginPath(); x.arc(px, py, R, a - 0.9, a); x.stroke();
        }
      }
    }
    if (deep && BLUR[L.id]) { const b = off(); const bx = b.getContext('2d'); bx.filter = 'blur(' + BLUR[L.id] + 'px)'; bx.drawImage(c, 0, 0); X.drawImage(b, 0, 0); }
    else X.drawImage(c, 0, 0);
    if (L.id === 'world') worldCanvas.getContext('2d').drawImage(c, 0, 0);
    // motes that live between this plane and the next (2.5D) or all on one sheet above the world (flat)
    const next = layers[layers.indexOf(L) + 1];
    const lo = L.f, hi = next ? next.f : 9;
    const mc = off(), m = mc.getContext('2d');
    let any = false;
    for (const q of MOTES) {
      const f = deep ? q.f : 1.6;
      if (deep ? !(f >= lo && f < hi) : L.id !== 'world') continue;
      any = true;
      const k = CamLayerZoom(f, z), cx = V.w / 2 + k * (q.x - C.x) + Math.sin(t * 0.7 + q.ph) * q.sp, cy = V.h / 2 + k * (q.y - C.y) - (t * q.sp) % 60;
      if (cx < -40 || cy < -40 || cx > V.w + 40 || cy > V.h + 40) continue;
      const size = deep ? q.s * 1.8 * Math.min(1.6, Math.pow(f, 1.2)) : 1.8, blurDepth = deep ? Math.abs(f - 1) * 2.6 : 0;
      const tw = (0.55 + 0.45 * Math.sin(t * 2.3 + q.ph * 3)) * (deep && f > 1.2 ? 0.55 : 1);
      const g = m.createRadialGradient(cx, cy, 0, cx, cy, size * (3 + blurDepth));
      g.addColorStop(0, rgba('#ffffff', 0.9 * tw)); g.addColorStop(0.25, rgba(q.hue, 0.55 * tw)); g.addColorStop(1, rgba(q.hue, 0));
      m.fillStyle = g; m.beginPath(); m.arc(cx, cy, size * (3 + blurDepth), 0, 6.29); m.fill();
    }
    if (any) { X.globalCompositeOperation = 'lighter'; X.drawImage(mc, 0, 0); X.globalCompositeOperation = 'source-over'; }
  }
  if (!deep) return;
  // bloom: bright pixels (the HDR sources in the plan: light-falls, the sun, the rift, gems, rings) spread light
  const sw = 480, sh = 270, small = off(sw, sh), sx = small.getContext('2d');
  sx.drawImage(out, 0, 0, sw, sh);
  const id = sx.getImageData(0, 0, sw, sh), d = id.data;
  for (let i = 0; i < d.length; i += 4) {
    const l = (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255, k = Math.max(0, (l - 0.64) / 0.36);
    d[i] *= k; d[i + 1] *= k; d[i + 2] *= k;
  }
  sx.putImageData(id, 0, 0);
  X.globalCompositeOperation = 'lighter';
  for (const [b, a] of [[3, 0.5], [9, 0.42], [22, 0.36]]) {
    const bc = off(), bx = bc.getContext('2d'); bx.filter = 'blur(' + b + 'px)'; bx.imageSmoothingQuality = 'high'; bx.drawImage(small, 0, 0, V.w, V.h);
    X.globalAlpha = a; X.drawImage(bc, 0, 0);
  }
  X.globalAlpha = 1; X.globalCompositeOperation = 'source-over';
  // grade: a touch more contrast and saturation, cooler shadows, and a vignette
  const g2 = off(), gx = g2.getContext('2d'); gx.filter = 'contrast(1.08) saturate(1.12)'; gx.drawImage(out, 0, 0);
  X.drawImage(g2, 0, 0);
  const vg = X.createRadialGradient(V.w / 2, V.h / 2, V.h * 0.35, V.w / 2, V.h / 2, V.h * 0.95);
  vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(4,2,12,0.55)');
  X.fillStyle = vg; X.fillRect(0, 0, V.w, V.h);
};
</script></body></html>`;

function layerZoomSrc() { return `function CamLayerZoom(f, z) { return (${CAM.layerZoom.toString()})(f, z); }`; }

async function main() {
  const args = process.argv.slice(2);
  const oi = args.indexOf('--out'), out = oi >= 0 ? args[oi + 1] : path.join(ART, 'out');
  fs.mkdirSync(out, { recursive: true });
  const V = { w: 1920, h: 1080 };
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.route('http://p.local/**', r => {
    const u = new URL(r.request().url());
    if (u.pathname === '/') return r.fulfill({ contentType: 'text/html', body: PAGE.replace('<script>', '<script>' + layerZoomSrc() + '\n') });
    const f = path.join(ART, decodeURIComponent(u.pathname));
    return fs.existsSync(f) ? r.fulfill({ body: fs.readFileSync(f), contentType: 'image/png' }) : r.fulfill({ status: 404, body: '' });
  });
  await page.goto('http://p.local/');
  const Ls = MAN.tiers.HIGH.layers.filter(l => l.id !== 'particles');
  for (const l of Ls) await page.evaluate(([k, u]) => load(k, u), [l.id, '/' + l.source]);
  await page.evaluate(() => load('atlas', '/gems/out/node_atlas.png'));
  const nodes = Object.entries(REALM.nodes).filter(([k]) => STATE[k]).map(([k, p]) => ({ key: k, x: p[0], y: p[1], hue: HUES[k], st: STATE[k] }));

  async function frame(C, z, t, deep, file) {
    const layers = Ls.map(l => {
      const L = { f: l.f, w: l.size[0], h: l.size[1], ax: l.anchor[0], ay: l.anchor[1] };
      const o = CAM.layerOffset(L, C, z, V);
      // the foreground fades out below its zoom (zHide / zShow), as in the client
      if (l.zShow && z < l.zShow) return null;
      return { id: l.id, f: l.f, ox: o.x, oy: o.y, w: o.w, h: o.h, scale: o.scale };
    }).filter(Boolean);
    await page.evaluate(a => draw(a), { layers, C, z, t, deep, nodes, atlasRects: Object.fromEntries(Object.entries(NODE_ATLAS.rects)), ringR: NODE_ATLAS.ringR });
    await page.screenshot({ path: file, type: file.endsWith('.png') ? 'png' : 'jpeg', quality: file.endsWith('.png') ? undefined : 90 });
  }
  const C0 = CAM.startCamera(V);
  const C = { x: C0.x - 60, y: C0.y - 40 }, z = C0.z * 1.05;
  const now = path.join(out, 'realm_now.jpg'), d25 = path.join(out, 'realm_25d.jpg');
  await frame(C, z, 1.2, false, now);
  await frame(C, z, 1.2, true, d25);
  console.log('stills', now, d25);
  if (args.includes('--clip')) {
    const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'r25-')), n = 96, fps = 24;
    for (let i = 0; i < n; i++) {
      const u = i / (n - 1), e = u * u * (3 - 2 * u);
      // a slow drift and push-in: the depth reads in the motion (planes and motes slide at their own speeds)
      const Ci = { x: C.x - 160 + 320 * e, y: C.y + 40 - 80 * e }, zi = z * (1 + 0.12 * e);
      await frame(Ci, zi, i / fps, true, path.join(dir, `f${String(i).padStart(4, '0')}.jpg`));
    }
    const ff = execFileSync('python3', ['-c', 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim();
    const mp4 = path.join(out, 'realm_25d.mp4');
    execFileSync(ff, ['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', path.join(dir, 'f%04d.jpg'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '21',
      '-vf', 'scale=1280:-2', mp4]);
    fs.rmSync(dir, { recursive: true, force: true });
    console.log('clip', mp4);
  }
  await browser.close();
}
main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
