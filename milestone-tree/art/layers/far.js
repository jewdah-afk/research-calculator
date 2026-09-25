// Parallax 1 — Far: distant floating islands, ridges and mist, a ringed planet. Transparent, 3840x2160.
LAYERS.far = async function () {
  const out = canvas(), o = ctx(out);
  const glow = canvas(), g = ctx(glow);
  const HAZE = [58, 40, 110];

  // ---- ringed planet (upper right, where the sky is darkest) ----
  {
    const px = 3180, py = 330, pr = 150;
    const ring = (front) => {
      o.save(); o.translate(px, py); o.rotate(-0.32); o.scale(1, 0.24);
      o.beginPath(); o.rect(-800, front ? 0 : -800, 1600, 800); o.clip();
      for (let i = 0; i < 26; i++) { const rr = pr * 1.35 + i * 7.5; o.strokeStyle = `rgba(${200 - i * 3},${170 + (i % 5) * 8},255,${0.05 + (i % 3 === 0 ? 0.18 : 0.08) * (1 - i / 30)})`; o.lineWidth = 5; o.beginPath(); o.arc(0, 0, rr, 0, 7); o.stroke(); }
      o.restore();
    };
    ring(false);
    blob(o, px, py, pr * 1.9, [150, 110, 255], 0.22);
    const sg = o.createRadialGradient(px - pr * 0.45, py - pr * 0.5, pr * 0.1, px, py, pr);
    sg.addColorStop(0, '#f2c6ff'); sg.addColorStop(0.35, '#b47af0'); sg.addColorStop(0.8, '#4a2590'); sg.addColorStop(1, '#1d0c40');
    o.fillStyle = sg; o.beginPath(); o.arc(px, py, pr, 0, 7); o.fill();
    // bands
    o.save(); o.beginPath(); o.arc(px, py, pr, 0, 7); o.clip();
    const n = makeNoise(12);
    for (let i = 0; i < 18; i++) { const y = py - pr + i * pr / 9; o.fillStyle = `rgba(${i % 2 ? 60 : 255},${i % 2 ? 20 : 200},${i % 2 ? 120 : 255},0.07)`; o.beginPath(); for (let x = px - pr; x <= px + pr; x += 8) { const yy = y + 6 * n(x / 60, i); x === px - pr ? o.moveTo(x, yy) : o.lineTo(x, yy); } o.lineTo(px + pr, y + 10); o.lineTo(px - pr, y + 10); o.fill(); }
    // terminator shadow
    const tg = o.createLinearGradient(px - pr, py - pr, px + pr, py + pr); tg.addColorStop(0.45, 'rgba(8,3,20,0)'); tg.addColorStop(0.85, 'rgba(8,3,20,0.85)'); o.fillStyle = tg; o.fillRect(px - pr, py - pr, pr * 2, pr * 2);
    o.restore();
    o.strokeStyle = 'rgba(230,200,255,0.55)'; o.lineWidth = 2; o.beginPath(); o.arc(px, py, pr, Math.PI * 0.95, Math.PI * 1.7); o.stroke();
    ring(true);
    // small moon
    const mg = o.createRadialGradient(2940, 520, 4, 2950, 530, 34); mg.addColorStop(0, '#9fe6ff'); mg.addColorStop(1, '#1b2c60');
    o.fillStyle = mg; o.beginPath(); o.arc(2950, 530, 34, 0, 7); o.fill(); blob(g, 2950, 530, 70, [120, 200, 255], 0.25);
  }

  // ---- distant ridges and mist along the bottom ----
  const ridge = (base, amp, scale, seed, top, bot, rimA) => {
    const n = makeNoise(seed), pts = [];
    for (let x = 0; x <= W; x += 6) pts.push([x, base - amp * ridged(n, x / scale, seed * 0.1, 5)]);
    o.save(); o.beginPath(); o.moveTo(0, H); pts.forEach(p => o.lineTo(p[0], p[1])); o.lineTo(W, H); o.closePath();
    const gr = o.createLinearGradient(0, base - amp, 0, H); gr.addColorStop(0, top); gr.addColorStop(1, bot); o.fillStyle = gr; o.fill(); o.restore();
    o.save(); o.beginPath(); pts.forEach((p, i) => i ? o.lineTo(p[0], p[1]) : o.moveTo(p[0], p[1])); o.strokeStyle = `rgba(190,160,255,${rimA})`; o.lineWidth = 2; o.stroke(); o.restore();
  };
  ridge(1760, 420, 900, 31, 'rgba(46,30,96,0.9)', 'rgba(20,10,44,1)', 0.35);
  // mist between ridges
  { const mg = o.createLinearGradient(0, 1500, 0, 2000); mg.addColorStop(0, 'rgba(120,80,220,0)'); mg.addColorStop(1, 'rgba(120,80,220,0.28)'); o.fillStyle = mg; o.fillRect(0, 1500, W, 660); }
  ridge(1980, 300, 600, 47, 'rgba(26,14,56,1)', 'rgba(10,5,24,1)', 0.25);
  { const mg = o.createLinearGradient(0, 1850, 0, H); mg.addColorStop(0, 'rgba(90,50,180,0)'); mg.addColorStop(1, 'rgba(90,50,180,0.35)'); o.fillStyle = mg; o.fillRect(0, 1850, W, 310); }

  // ---- floating islands ----
  const isle = (cx, top, hw, depth, haze, seed, opts = {}) => {
    const c = canvas(), x = ctx(c), n = makeNoise(seed), r = rng(seed);
    const pts = [];
    for (let i = 0; i <= 40; i++) { const t = i / 40, xx = cx - hw + t * hw * 2, e = Math.sin(Math.PI * t); pts.push([xx, top + (1 - Math.pow(e, 0.3)) * hw * 0.12 + hw * 0.03 * n(xx / 60, 2)]); }
    for (let i = 60; i >= 0; i--) { const t = i / 60, xx = cx - hw * 0.97 + t * hw * 1.94; const prof = Math.pow(1 - Math.pow(Math.abs(2 * t - 1), 1.6), 1.3); pts.push([xx, top + hw * 0.06 + depth * prof * (0.75 + 0.35 * (0.5 + fbm(n, xx / (hw * 0.4), 7, 3)))]); }
    poly(x, pts); const gr = x.createLinearGradient(0, top, 0, top + depth); gr.addColorStop(0, '#4b3190'); gr.addColorStop(0.1, '#2a1858'); gr.addColorStop(1, '#0e0722'); x.fillStyle = gr; x.fill();
    x.save(); x.clip(); for (let i = 0; i < 18; i++) { const y = top + r() * depth, x0 = cx - hw + r() * hw * 2; x.strokeStyle = 'rgba(8,4,20,0.5)'; x.lineWidth = 1 + r() * 2; x.beginPath(); x.moveTo(x0, y); for (let k = 1; k < 10; k++) x.lineTo(x0 + k * hw * 0.06, y + 5 * n(k, y)); x.stroke(); }
    const sh = x.createLinearGradient(cx - hw, 0, cx + hw, 0); sh.addColorStop(0, 'rgba(170,140,255,0.16)'); sh.addColorStop(1, 'rgba(0,0,0,0.45)'); x.fillStyle = sh; x.fillRect(cx - hw, top - 20, hw * 2, depth + 40); x.restore();
    // top rim + moss glow
    x.save(); poly(x, pts); x.clip(); for (let i = 0; i < 40; i++) { const p = pts[i]; const mg = x.createLinearGradient(0, p[1], 0, p[1] + hw * 0.1); mg.addColorStop(0, 'rgba(170,130,255,0.55)'); mg.addColorStop(1, 'rgba(170,130,255,0)'); x.fillStyle = mg; x.fillRect(p[0], p[1] - 3, pts[i + 1][0] - p[0] + 1, hw * 0.12); } x.restore();
    x.beginPath(); for (let i = 0; i <= 40; i++) i ? x.lineTo(...pts[i]) : x.moveTo(...pts[i]); x.strokeStyle = opts.moss || 'rgba(190,160,255,0.8)'; x.lineWidth = Math.max(1.2, hw / 110); x.stroke();
    for (let i = 0; i < hw * 0.5; i++) { const p = pts[1 + Math.floor(r() * 38)], hh = hw * (0.01 + Math.pow(r(), 2) * 0.05); x.strokeStyle = 'rgba(70,46,130,0.9)'; x.lineWidth = Math.max(0.8, hw / 200); x.beginPath(); x.moveTo(p[0], p[1] + 1); x.lineTo(p[0] + (r() - 0.5) * hh * 0.6, p[1] - hh); x.stroke(); }
    // silhouettes on top: little trees or crystals
    for (let i = 0; i < (opts.trees || 0); i++) {
      const p = pts[5 + Math.floor(r() * 30)], th = hw * (0.12 + r() * 0.18);
      x.strokeStyle = '#1a0f36'; x.lineWidth = th * 0.08; x.beginPath(); x.moveTo(p[0], p[1]); x.lineTo(p[0], p[1] - th * 0.6); x.stroke();
      x.fillStyle = '#231446'; for (let k = 0; k < 5; k++) { x.beginPath(); x.arc(p[0] + (r() - 0.5) * th * 0.5, p[1] - th * (0.6 + r() * 0.35), th * (0.2 + r() * 0.15), 0, 7); x.fill(); }
      if (opts.lit) { blob(x, p[0], p[1] - th * 0.75, th * 0.5, hex(opts.lit), 0.35); }
    }
    for (let i = 0; i < (opts.crystals || 0); i++) {
      const p = pts[4 + Math.floor(r() * 32)], ch = hw * (0.08 + r() * 0.14), cw = ch * 0.3, a = (r() - 0.5) * 0.6, col = hex(opts.cc || 'b35cff');
      x.save(); x.translate(p[0], p[1] + 2); x.rotate(a); x.beginPath(); x.moveTo(-cw / 2, 0); x.lineTo(-cw / 2, -ch * 0.75); x.lineTo(0, -ch); x.lineTo(cw / 2, -ch * 0.75); x.lineTo(cw / 2, 0); x.closePath();
      const cg = x.createLinearGradient(0, 0, 0, -ch); cg.addColorStop(0, rgba(mix(col, [20, 10, 40], 0.6))); cg.addColorStop(1, rgba(mix(col, [255, 255, 255], 0.4))); x.fillStyle = cg; x.fill(); x.restore();
      blob(g, p[0], p[1] - ch * 0.7, ch * 0.8, col, 0.28 * (1 - haze));
    }
    // falling light stream
    if (opts.fall) {
      const fx = cx + hw * opts.fall, fy = top + depth * 0.4, fh = depth * 2.4;
      const fg = g.createLinearGradient(0, fy, 0, fy + fh); fg.addColorStop(0, `rgba(140,220,255,${0.4 * (1 - haze)})`); fg.addColorStop(0.5, `rgba(140,220,255,${0.12 * (1 - haze)})`); fg.addColorStop(1, 'rgba(140,220,255,0)');
      g.save(); g.filter = 'blur(6px)'; g.fillStyle = fg; for (let k = 0; k < 3; k++) { const wv = hw * (0.05 - k * 0.012); g.beginPath(); g.moveTo(fx - wv * 0.3, fy); g.quadraticCurveTo(fx - wv, fy + fh * 0.5, fx - wv * 1.6, fy + fh); g.lineTo(fx + wv * 1.6, fy + fh); g.quadraticCurveTo(fx + wv, fy + fh * 0.5, fx + wv * 0.3, fy); g.fill(); } g.restore();
      // mist puff where it leaves the rock
      blob(g, fx, fy + fh * 0.9, hw * 0.3, [140, 200, 255], 0.08 * (1 - haze));
      blob(g, fx, fy + 4, hw * 0.08, [140, 220, 255], 0.4 * (1 - haze));
    }
    // dangling roots
    for (let i = 0; i < hw / 30; i++) { const t = 0.2 + r() * 0.6, p = pts[41 + Math.floor((1 - t) * 60)]; const l = depth * (0.2 + r() * 0.5); x.strokeStyle = 'rgba(20,10,44,0.9)'; x.lineWidth = Math.max(1, hw / 160); x.beginPath(); x.moveTo(p[0], p[1] - 4); x.quadraticCurveTo(p[0] + (r() - 0.5) * 20, p[1] + l * 0.5, p[0] + (r() - 0.5) * 30, p[1] + l); x.stroke(); }
    // atmospheric perspective
    x.globalCompositeOperation = 'source-atop'; x.fillStyle = rgba(HAZE, haze); x.fillRect(0, 0, W, H);
    o.drawImage(c, 0, 0);
  };
  // far, hazy ones first
  isle(1060, 470, 70, 110, 0.62, 5, { crystals: 3 });
  isle(2330, 1180, 90, 130, 0.6, 6, { trees: 2 });
  isle(620, 1250, 60, 90, 0.66, 7, {});
  isle(3560, 820, 80, 120, 0.6, 8, { crystals: 2, cc: 'ff4d6d' });
  isle(2700, 250, 60, 90, 0.66, 9, {});
  // mid
  isle(330, 820, 170, 260, 0.26, 10, { trees: 3, lit: '9be02c' });
  isle(2080, 560, 200, 280, 0.24, 11, { crystals: 5, cc: '5fe0ff' });
  isle(3350, 1400, 230, 300, 0.2, 12, { crystals: 6, cc: 'ff9a2e' });
  isle(1250, 1330, 150, 210, 0.3, 13, { trees: 2, lit: 'ffe93a' });
  isle(2800, 900, 140, 200, 0.32, 14, { crystals: 4, cc: 'e88af2' });
  // a distant tiny archipelago
  [[1640, 270, 44], [860, 1020, 40], [3000, 1690, 56]].forEach(([x0, y0, hw], i) => isle(x0, y0, hw, hw * 1.1, 0.68, 30 + i, {}));

  // drifting dust motes
  const r = rng(71);
  for (let i = 0; i < 260; i++) { const x0 = r() * W, y0 = r() * H * 0.85; blob(g, x0, y0, 3 + r() * 5, [190, 160, 255], 0.25); }
  o.save(); o.globalCompositeOperation = 'lighter'; o.drawImage(glow, 0, 0); o.restore();
  bloom(out, glow, [8, 30], [0.4, 0.3]);
  window.__last = out;
  return out;
};
