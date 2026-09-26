// icon.js - the Roblox game icon: the M crystal gem in a glowing conical rift ring on the void (MASTER_PLAN W8).
// Drawn on a 2D canvas in Chromium at 1024 px (the master), then icon_post.py makes icon_512.png and the preview.
//   cd art/marketing && node icon.js          -> work/icon_1024.png
// Deterministic: every star and streak comes from one seeded PRNG.
const path = require('path'), fs = require('fs');
const { withPage, setHtml, url } = require('./lib/page');
const OUT = path.join(__dirname, 'work');
const GEM = path.join(__dirname, '..', 'gems', 'sprites', 'm.png');

function draw(gemUrl) {
  const S = 1024, C = S / 2;
  const cv = document.getElementById('c'), x = cv.getContext('2d');
  let seed = 20260926;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  // palette (Realm.luau palette): void, violet, lilac, gold, cyan, crimson, magenta
  const VOID = '#07050d';
  // 1. the void: a violet core falling off to near black
  let g = x.createRadialGradient(C, C, 0, C, C, S * 0.72);
  g.addColorStop(0, '#3b1370'); g.addColorStop(0.3, '#1f0a40'); g.addColorStop(0.62, '#0d0620'); g.addColorStop(1, VOID);
  x.fillStyle = g; x.fillRect(0, 0, S, S);
  // nebula wisps (soft, off-centre, two hues)
  const blob = (bx, by, r, col, a) => {
    const b = x.createRadialGradient(bx, by, 0, bx, by, r);
    b.addColorStop(0, col.replace('A', a)); b.addColorStop(1, col.replace('A', 0));
    x.fillStyle = b; x.fillRect(0, 0, S, S);
  };
  blob(250, 230, 420, 'rgba(232,70,190,A)', 0.28);
  blob(800, 820, 420, 'rgba(95,224,255,A)', 0.16);
  blob(820, 220, 300, 'rgba(255,201,60,A)', 0.08);
  // stars
  for (let i = 0; i < 170; i++) {
    const sx = rnd() * S, sy = rnd() * S, r = 0.6 + rnd() * rnd() * 2.6, a = 0.25 + rnd() * 0.65;
    x.fillStyle = `rgba(${220 + rnd() * 35 | 0},${200 + rnd() * 55 | 0},255,${a})`;
    x.beginPath(); x.arc(sx, sy, r, 0, Math.PI * 2); x.fill();
  }
  // 2. the conical rift: nested rings shrinking toward a vanishing point a touch below centre, each a conic
  //    gradient; brighter and thicker at the mouth, fading down the throat, so the ring reads as a funnel
  const RING = 372, cy0 = C + 6;
  const conic = (rot, cx, cy, a = 1) => {
    const cg = x.createConicGradient(rot, cx, cy);
    const cols = ['#ff2e63', '#e846be', '#b35cff', '#5fe0ff', '#b35cff', '#ffc93c', '#ff5a1f', '#ff2e63'];
    cols.forEach((c, i) => cg.addColorStop(i / (cols.length - 1), c));
    return cg;
  };
  const N = 14;
  for (let i = N; i >= 1; i--) {
    const t = i / N;                               // 1 at the mouth, ~0 deep in the throat
    const r = 70 + (RING - 70) * Math.pow(t, 1.35);
    const cy = cy0 + (1 - t) * 26;                 // the throat sits a little lower: a tilted cone
    x.save();
    x.globalAlpha = 0.10 + 0.5 * Math.pow(t, 2.2);
    x.strokeStyle = conic(-1.2 + (1 - t) * 2.4, C, cy);
    x.lineWidth = 2 + 9 * t;
    x.filter = `blur(${1 + (1 - t) * 3}px)`;
    x.beginPath(); x.ellipse(C, cy, r, r * (0.98 - (1 - t) * 0.04), 0, 0, Math.PI * 2); x.stroke();
    x.restore();
  }
  // swirl streaks: log-spiral arcs pulled into the throat
  x.save();
  x.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 30; k++) {
    const a0 = rnd() * Math.PI * 2, len = 0.9 + rnd() * 1.5, r0 = RING * (0.72 + rnd() * 0.26);
    x.beginPath();
    for (let s = 0; s <= 40; s++) {
      const f = s / 40, a = a0 + f * len, r = r0 * Math.exp(-0.9 * f);
      const px = C + r * Math.cos(a), py = cy0 + r * Math.sin(a) + f * 18;
      if (!s) x.moveTo(px, py); else x.lineTo(px, py);
    }
    const hue = ['255,46,99', '179,92,255', '95,224,255', '232,70,190'][k % 4];
    x.strokeStyle = `rgba(${hue},${0.10 + rnd() * 0.22})`;
    x.lineWidth = 1.5 + rnd() * 3.5;
    x.filter = 'blur(1.5px)';
    x.stroke();
  }
  x.restore();
  // the throat's light: a bright violet-white core the gem sits in
  g = x.createRadialGradient(C, cy0 + 10, 0, C, cy0 + 10, 300);
  g.addColorStop(0, 'rgba(255,240,255,0.85)'); g.addColorStop(0.18, 'rgba(210,150,255,0.55)');
  g.addColorStop(0.5, 'rgba(140,60,230,0.18)'); g.addColorStop(1, 'rgba(90,30,180,0)');
  x.fillStyle = g; x.fillRect(0, 0, S, S);
  // 3. the rim: the mouth of the rift, a thick conic ring with a wide bloom
  const rim = (w, blur, a) => {
    x.save(); x.globalAlpha = a; x.globalCompositeOperation = 'lighter';
    x.strokeStyle = conic(-1.2, C, C); x.lineWidth = w; x.filter = `blur(${blur}px)`;
    x.beginPath(); x.arc(C, C, RING, 0, Math.PI * 2); x.stroke(); x.restore();
  };
  rim(90, 40, 0.55);
  rim(46, 14, 0.8);
  rim(26, 0, 1);
  // a white-hot inner edge (reads at 50 px as a crisp circle)
  x.save(); x.globalCompositeOperation = 'lighter'; x.strokeStyle = 'rgba(255,255,255,0.75)'; x.lineWidth = 5; x.filter = 'blur(1px)';
  x.beginPath(); x.arc(C, C, RING - 9, 0, Math.PI * 2); x.stroke(); x.restore();
  // hairline and corner-tick style marks on the ring (Sleek: 12 ticks, 3 long)
  x.save(); x.strokeStyle = 'rgba(255,255,255,0.55)'; x.lineWidth = 3;
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2, long = i % 6 === 0, r1 = RING + 28, r2 = RING + (long ? 58 : 40);
    if (!long && i % 2) continue;
    x.beginPath(); x.moveTo(C + r1 * Math.cos(a), C + r1 * Math.sin(a)); x.lineTo(C + r2 * Math.cos(a), C + r2 * Math.sin(a)); x.stroke();
  }
  x.restore();
  // debris shards drifting into the rift (small dark rocks with a lit edge)
  for (let k = 0; k < 9; k++) {
    const a = rnd() * Math.PI * 2, r = RING * (0.55 + rnd() * 0.3), s = 7 + rnd() * 12;
    const px = C + r * Math.cos(a), py = C + r * Math.sin(a);
    x.save(); x.translate(px, py); x.rotate(rnd() * 6);
    x.fillStyle = '#1a0f2e'; x.strokeStyle = 'rgba(255,120,200,0.6)'; x.lineWidth = 1.5;
    x.beginPath(); x.moveTo(-s, 0); x.lineTo(-s * 0.2, -s * 0.8); x.lineTo(s, -s * 0.2); x.lineTo(s * 0.4, s * 0.7); x.closePath(); x.fill(); x.stroke();
    x.restore();
  }
  return new Promise(res => {
    const im = new Image();
    im.onload = () => {
      // 4. the M gem: centred, about 58 % of the icon (the bezel is ~76 % of the sprite)
      const gs = 630;
      x.save(); x.shadowColor = 'rgba(20,0,40,0.9)'; x.shadowBlur = 50; x.shadowOffsetY = 14;
      x.drawImage(im, C - gs / 2, C - gs / 2 + 4, gs, gs); x.restore();
      // a second additive pass lifts the core so it glows through at small sizes
      x.save(); x.globalCompositeOperation = 'lighter'; x.globalAlpha = 0.14; x.drawImage(im, C - gs / 2, C - gs / 2 + 4, gs, gs); x.restore();
      // 5. glints: four-point stars on the bezel corners and the ring
      const glint = (gx, gy, r, a) => {
        x.save(); x.globalCompositeOperation = 'lighter'; x.globalAlpha = a;
        const gg = x.createRadialGradient(gx, gy, 0, gx, gy, r * 0.5);
        gg.addColorStop(0, 'rgba(255,255,255,1)'); gg.addColorStop(1, 'rgba(255,220,255,0)');
        x.fillStyle = gg; x.beginPath(); x.arc(gx, gy, r * 0.5, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#fff';
        for (const [dx, dy] of [[1, 0], [0, 1]]) {
          x.beginPath(); x.moveTo(gx - dx * r, gy - dy * r); x.lineTo(gx + dy * r * 0.07, gy + dx * r * 0.07);
          x.lineTo(gx + dx * r, gy + dy * r); x.lineTo(gx - dy * r * 0.07, gy - dx * r * 0.07); x.closePath(); x.fill();
        }
        x.restore();
      };
      glint(C - 226, C - 228, 70, 0.95);
      glint(C + 232, C + 224, 44, 0.8);
      glint(C + RING * Math.cos(-0.7), C + RING * Math.sin(-0.7), 60, 0.9);
      glint(C + RING * Math.cos(2.5), C + RING * Math.sin(2.5), 40, 0.7);
      // 6. a soft vignette so the corners stay dark after Roblox rounds them
      g = x.createRadialGradient(C, C, S * 0.45, C, C, S * 0.75);
      g.addColorStop(0, 'rgba(7,5,13,0)'); g.addColorStop(1, 'rgba(7,5,13,0.75)');
      x.fillStyle = g; x.fillRect(0, 0, S, S);
      res(true);
    };
    im.src = gemUrl;
  });
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  await withPage(1024, 1024, async page => {
    await setHtml(page, 'canvas{display:block}', '<canvas id="c" width="1024" height="1024"></canvas>');
    await page.evaluate(draw, url(GEM));
    const data = await page.evaluate(() => document.getElementById('c').toDataURL('image/png'));
    fs.writeFileSync(path.join(OUT, 'icon_1024.png'), Buffer.from(data.split(',')[1], 'base64'));
  });
  console.log('icon: work/icon_1024.png');
})().catch(e => { console.error(e); process.exit(1); });
