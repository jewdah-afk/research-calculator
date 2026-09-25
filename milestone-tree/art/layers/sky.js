// Parallax 0 — Sky: deep space nebula, galactic band, dust lanes, stars, the cosmic sun. Opaque, 3840x2160.
LAYERS.sky = async function () {
  const out = canvas(), o = ctx(out);
  const n1 = makeNoise(101), n2 = makeNoise(202), n3 = makeNoise(303);
  // ---- nebula at 1/3 resolution, domain-warped fbm ----
  const s = 3, w = W / s | 0, h = H / s | 0;
  const nc = canvas(w, h), nx = ctx(nc), img = nx.createImageData(w, h), d = img.data;
  const VIO = [0.70, 0.36, 1.0], MAG = [1.0, 0.18, 0.39], CYA = [0.37, 0.88, 1.0], DEEP = [0.20, 0.10, 0.55], WARM = [1.0, 0.62, 0.38];
  const sunX = 0.365, sunY = 0.2;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const u = x / w * 4.2, v = y / h * 2.36;
    const qx = fbm(n1, u, v, 4), qy = fbm(n1, u + 5.2, v + 1.3, 4);
    const rx = fbm(n2, u + 3.2 * qx + 1.7, v + 3.2 * qy + 9.2, 5), ry = fbm(n2, u + 3.2 * qx + 8.3, v + 3.2 * qy + 2.8, 4);
    const dens = clamp(rx * 1.5 + 0.35);
    // galactic band: from lower-left to upper-right, through the sun
    const bx = x / w - sunX, by = (y / h - sunY) * 0.5625;
    const along = bx * 0.86 - by * 0.5, across = bx * 0.5 + by * 0.86;
    const band = Math.exp(-Math.pow((across + 0.06 * Math.sin(along * 7)) / 0.17, 2));
    const halo = Math.exp(-Math.pow((across) / 0.42, 2));
    // dust lanes
    const dust = smooth(0.05, 0.42, fbm(n3, u * 2.2 + qx, v * 2.2 + qy, 5)) * band;
    let c = mix(VIO, MAG, clamp(qx * 1.8 + 0.35));
    c = mix(c, CYA, clamp(qy * 2.8 - 0.05) * 0.85);
    c = mix(DEEP, c, clamp(dens * 1.2));
    let I = Math.pow(dens, 2.3) * (0.07 + band * 1.45 + halo * 0.22) * (1 - 0.85 * dust);
    // sun core warmth
    const sd = Math.hypot((x / w - sunX) * 1.78, y / h - sunY);
    const core = Math.exp(-sd * sd / 0.004) * 1.6 + Math.exp(-sd * sd / 0.05) * 0.5;
    c = mix(c, WARM, clamp(core * 0.5));
    I += core * 0.35;
    // faint background glow everywhere so it never reads as flat black
    const bg = 0.012 + 0.02 * (0.5 + fbm(n3, u * 0.6, v * 0.6, 3));
    const i = (y * w + x) * 4;
    for (let k = 0; k < 3; k++) {
      const base = [0.025, 0.016, 0.06][k] + bg * DEEP[k];
      d[i + k] = clamp(1 - Math.exp(-(base + c[k] * I) * 1.6)) * 255;
    }
    d[i + 3] = 255;
  }
  nx.putImageData(img, 0, 0);
  o.imageSmoothingQuality = 'high';
  o.filter = 'blur(2px)'; o.drawImage(nc, 0, 0, W, H); o.filter = 'none';
  // fine filament detail at full res over the band (additive, faint)
  layer(out, x => {
    const fc = canvas(W / 2, H / 2), fx = ctx(fc), im = fx.createImageData(W / 2, H / 2), dd = im.data;
    for (let y = 0; y < H / 2; y++) for (let xx = 0; xx < W / 2; xx++) {
      const u = xx / (W / 2) * 9, v = y / (H / 2) * 5.06;
      const bx = xx / (W / 2) - sunX, by = (y / (H / 2) - sunY) * 0.5625;
      const across = bx * 0.5 + by * 0.86; const band = Math.exp(-Math.pow(across / 0.22, 2));
      const r = Math.pow(ridged(n2, u, v, 4), 3) * band * 0.9;
      const i = (y * W / 2 + xx) * 4; dd[i] = 190 * r; dd[i + 1] = 120 * r; dd[i + 2] = 255 * r; dd[i + 3] = 255;
    }
    fx.putImageData(im, 0, 0); x.drawImage(fc, 0, 0, W, H);
  }, { op: 'lighter', alpha: 0.55 });

  // ---- stars ----
  const r = rng(404), stars = canvas(), st = ctx(stars);
  const bandAt = (x, y) => { const bx = x / W - sunX, by = (y / H - sunY) * 0.5625; return Math.exp(-Math.pow((bx * 0.5 + by * 0.86) / 0.2, 2)); };
  for (let i = 0; i < 6500; i++) {
    let x = r() * W, y = r() * H;
    if (r() > 0.35 + bandAt(x, y) * 0.65) { x = r() * W; y = r() * H; }
    const m = Math.pow(r(), 6);             // most stars faint
    const size = 0.5 + m * 2.6;
    const t = r(); const c = t < 0.15 ? [255, 190, 150] : t < 0.35 ? [170, 200, 255] : t < 0.45 ? [230, 170, 255] : [245, 242, 255];
    st.fillStyle = rgba(c, 0.08 + m * 0.9 + r() * 0.22);
    st.beginPath(); st.arc(x, y, size, 0, 7); st.fill();
    if (m > 0.5) blob(st, x, y, size * 6, c, 0.2);
  }
  for (let i = 0; i < 26; i++) {
    const x = r() * W, y = r() * H, c = r() < 0.5 ? [220, 200, 255] : [180, 225, 255];
    sparkle(st, x, y, 14 + r() * 36, c, 0.55 + r() * 0.35, r() * 0.3);
  }
  // distant galaxies
  for (let i = 0; i < 7; i++) {
    const x = r() * W, y = r() * H, a = r() * 3, sz = 14 + r() * 26;
    st.save(); st.translate(x, y); st.rotate(a); st.scale(1, 0.35 + r() * 0.3);
    blob(st, 0, 0, sz, [200, 170, 255], 0.5); blob(st, 0, 0, sz * 0.3, [255, 240, 230], 0.9); st.restore();
  }
  o.drawImage(stars, 0, 0);
  bloom(out, stars, [3, 10], [0.3, 0.15]);

  // ---- the cosmic sun ----
  const sx = W * sunX, sy = H * sunY;
  layer(out, x => {
    blob(x, sx, sy, 520, [150, 90, 255], 0.35);
    blob(x, sx, sy, 200, [255, 190, 230], 0.5);
    blob(x, sx, sy, 70, [255, 235, 245], 1);
    blob(x, sx, sy, 26, [255, 255, 255], 1);
    // anamorphic streak + soft rays
    x.save(); x.translate(sx, sy);
    for (const [len, th, a] of [[1300, 3, 0.35], [700, 8, 0.25]]) { const gr = x.createLinearGradient(-len, 0, len, 0); gr.addColorStop(0, 'rgba(180,140,255,0)'); gr.addColorStop(0.5, `rgba(240,220,255,${a})`); gr.addColorStop(1, 'rgba(180,140,255,0)'); x.fillStyle = gr; x.beginPath(); x.ellipse(0, 0, len, th, 0, 0, 7); x.fill(); }
    const rr = rng(505);
    for (let i = 0; i < 18; i++) { const a = rr() * Math.PI * 2, len = 300 + rr() * 700, wd = 0.02 + rr() * 0.03; x.fillStyle = 'rgba(210,180,255,0.022)'; x.beginPath(); x.moveTo(0, 0); x.lineTo(Math.cos(a - wd) * len, Math.sin(a - wd) * len); x.lineTo(Math.cos(a + wd) * len, Math.sin(a + wd) * len); x.fill(); }
    x.restore();
  }, { op: 'lighter', blur: 6 });
  // vignette
  const vg = o.createRadialGradient(W / 2, H / 2, H * 0.4, W / 2, H / 2, W * 0.62);
  vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(2,1,6,0.6)'); o.fillStyle = vg; o.fillRect(0, 0, W, H);
  window.__last = out;
  return out;
};
