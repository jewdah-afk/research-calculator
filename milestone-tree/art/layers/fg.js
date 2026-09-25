// Parallax 3 — Foreground (×1.25): out-of-focus vines, fern silhouettes and bokeh. Transparent, 4800x3200 (1.25 × world).
LAYERS.fg = async function () {
  W = 4800; H = 3200;
  const out = canvas(), o = ctx(out);
  const r = rng(1234);
  const LEAF = [18, 9, 34], RIMC = [170, 140, 255];

  const vine = (x, c, x0, len, sway, seed) => {
    const rr = rng(seed), pts = [];
    for (let k = 0; k <= 8; k++) pts.push([x0 + Math.sin(k * 0.7 + seed) * sway * (k / 8), -40 + len * k / 8, lerp(16, 3, k / 8)]);
    const S = spline(pts, 12);
    x.save(); x.strokeStyle = rgba(LEAF); x.lineCap = 'round';
    for (let i = 1; i < S.length; i++) { x.lineWidth = S[i].w; x.beginPath(); x.moveTo(S[i - 1].x, S[i - 1].y); x.lineTo(S[i].x, S[i].y); x.stroke(); }
    x.restore();
    for (let i = 0; i < S.length; i += 3) {
      const p = S[i]; const n = 2 + Math.floor(rr() * 3);
      for (let k = 0; k < n; k++) {
        const side = rr() < 0.5 ? -1 : 1, sz = 30 + rr() * 50 * (1 - i / S.length * 0.5), ang = Math.PI / 2 + side * (0.6 + rr() * 0.9);
        x.fillStyle = rgba(mix(LEAF, [40, 22, 76], rr() * 0.6)); leaf(x, p.x, p.y, sz, sz * 0.36, ang);
        if (rr() < 0.4) { x.fillStyle = rgba(RIMC, 0.18); leaf(x, p.x - 2, p.y - 2, sz * 0.8, sz * 0.12, ang); }
      }
      if (rr() < 0.12) blob(c, p.x + (rr() - 0.5) * 40, p.y, 10 + rr() * 10, [255, 140, 220], 0.9);
    }
  };
  const fern = (x, bx, by, h, dir, seed) => {
    const rr = rng(seed);
    for (let f = 0; f < 7; f++) {
      const a = -Math.PI / 2 + dir * (0.2 + f * 0.16) + (rr() - 0.5) * 0.2, len = h * (0.6 + rr() * 0.5);
      const pts = []; for (let k = 0; k <= 6; k++) { const t = k / 6, bend = dir * t * t * 0.9; pts.push([bx + Math.cos(a + bend) * len * t, by + Math.sin(a + bend) * len * t, lerp(10, 2, t)]); }
      const S = spline(pts, 8);
      x.strokeStyle = rgba(LEAF); x.lineCap = 'round';
      for (let i = 1; i < S.length; i++) { x.lineWidth = S[i].w; x.beginPath(); x.moveTo(S[i - 1].x, S[i - 1].y); x.lineTo(S[i].x, S[i].y); x.stroke(); }
      for (let i = 2; i < S.length; i += 2) { const p = S[i], sz = 40 * (1 - i / S.length) + 10; x.fillStyle = rgba(LEAF); leaf(x, p.x, p.y, sz, sz * 0.3, Math.atan2(p.ty, p.tx) - 1.2); leaf(x, p.x, p.y, sz, sz * 0.3, Math.atan2(p.ty, p.tx) + 1.2); }
    }
  };

  // vines hang from the top at a few places (world-aligned to sit between node columns)
  const sil = canvas(), s = ctx(sil), glow = canvas(), g = ctx(glow);
  [[300, 1100, 60], [1150, 700, 40], [2650, 900, 70], [3350, 620, 50], [4550, 1250, 80]].forEach(([x0, len, sw], i) => vine(s, g, x0, len, sw, 40 + i));
  // ferns in the bottom corners
  fern(s, 180, H + 40, 900, 1, 71); fern(s, 520, H + 60, 700, 1, 72); fern(s, 4650, H + 40, 950, -1, 73); fern(s, 4300, H + 80, 650, -1, 74);
  fern(s, 2400, H + 120, 520, 1, 75);
  o.save(); o.filter = 'blur(7px)'; o.drawImage(sil, 0, 0); o.restore();
  o.save(); o.globalCompositeOperation = 'lighter'; o.filter = 'blur(4px)'; o.drawImage(glow, 0, 0); o.restore();
  bloom(out, glow, [20, 60], [0.5, 0.4]);

  // bokeh: large soft discs with a brighter rim
  for (let i = 0; i < 70; i++) {
    const x = r() * W, y = r() * H, rad = 14 + Math.pow(r(), 2) * 60, c = [[190, 150, 255], [120, 220, 255], [255, 150, 210], [255, 220, 150]][Math.floor(r() * 4)];
    const a = 0.06 + r() * 0.12;
    const gr = o.createRadialGradient(x, y, 0, x, y, rad);
    gr.addColorStop(0, rgba(c, a * 0.6)); gr.addColorStop(0.82, rgba(c, a)); gr.addColorStop(0.92, rgba(c, a * 1.6)); gr.addColorStop(1, rgba(c, 0));
    o.save(); o.globalCompositeOperation = 'lighter'; o.fillStyle = gr; o.beginPath(); o.arc(x, y, rad, 0, 7); o.fill(); o.restore();
  }
  window.__last = out;
  return out;
};
