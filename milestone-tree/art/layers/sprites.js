// The ambient sprite atlas (REALM.md sections 6 and 8; realm.json atlas): one 1024x1024 sheet with every animated
// piece the Roblox client tweens. That covers cloud wisps and mist bands, hanging vines, a light-fall streak, the
// rift glow and shock ring, bokeh discs, stars, fireflies, embers, motes, sparks, the glitch bar, floating shards, a
// shooting star and the screen vignette. Every region is drawn white or grey, so ImageColor3 tints it. It stays
// inside its own rect (realm.json atlas.regions) and fades to alpha 0 within its 2 px border. The vignette is the one
// exception: it runs to the edge of its rect, and the client samples it inset by 2 px (sprites.json sampleRect). Soft
// pieces are pre-blurred. All maths runs in float, premultiplied. Transparent pixels are alpha-bled per region, so
// scaled edges never fringe dark. LOW is the same sheet at half size (roblox/tile.js makes it with a 2x premultiplied
// box filter), so every rect is even and halves exactly.
//
//   node render.js sprites        -> out/sprites.png (+ out/sprites_prev.png), like any painter
//   node layers/sprites.js        -> out/sprites.png, out/sprites.json (rects for HIGH and LOW), out/sprites_prev.png
//                                    (a labelled sheet) and the atlas checks
//
// The PNG comes from a WebGL canvas (premultipliedAlpha: false), so the bled colour of alpha-0 pixels survives
// export. A 2D canvas stores premultiplied colour and would write them black.
(function () {
  'use strict';
  // ---- contract snapshot (realm.json atlas). window.REALM wins when a pipeline injects the manifest.
  const SNAP = {
    file: 'sprites.png', size: [1024, 1024], lowSize: [512, 512], padding: 2,
    regions: {
      wispA: [0, 0, 512, 256], wispB: [512, 0, 512, 256], wispC: [0, 256, 512, 192], wispD: [512, 256, 512, 192],
      vineA: [0, 448, 128, 576], vineB: [128, 448, 128, 576], vineThin: [256, 448, 64, 576], lightfall: [320, 448, 96, 576],
      glow: [416, 448, 256, 256], ring: [672, 448, 256, 256], bokehA: [416, 704, 128, 128], bokehB: [544, 704, 128, 128],
      vignette: [672, 704, 256, 256], star4: [416, 832, 64, 64], stardot: [480, 832, 32, 32], firefly: [512, 832, 48, 48],
      ember: [560, 832, 32, 32], mote: [592, 832, 16, 16], spark: [608, 832, 32, 32], bar: [416, 896, 256, 16],
      shardA: [416, 912, 96, 96], shardB: [512, 912, 96, 96], streak: [672, 960, 256, 32],
    },
  };
  // how the client anchors each region (AnchorPoint / pivot, REALM.md 6.2 and 9.3); every region not listed is centred
  const PIVOT = { vineA: [0.5, 0], vineB: [0.5, 0], vineThin: [0.5, 0], lightfall: [0.5, 0] };
  const EDGE_EXTEND = { vignette: true };   // regions that run to their edge (sampled inset by the padding)

  // ============================================================================================ page side (Chromium)
  function pageSide() {
    const REALM = window.REALM && window.REALM.atlas ? window.REALM : null;
    const ATLAS = REALM ? REALM.atlas : SNAP;
    const [AW, AH] = ATLAS.size, PAD = ATLAS.padding;
    const LD = (() => { const d = Math.hypot(-0.45, -0.62); return [-0.45 / d, -0.62 / d]; })();          // toward the key light
    const L3 = (() => { const v = [-0.45, -0.62, 0.64], d = Math.hypot(...v); return v.map(a => a / d); })();
    const sm = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
    const g2 = (d2, s) => Math.exp(-d2 / (2 * s * s));
    const screen = (...a) => 1 - a.reduce((p, v) => p * (1 - clamp(v)), 1);

    // ---- premultiplied float buffers { w, h, d: Float32Array(w * h * 4) }
    const buf = (w, h) => ({ w, h, d: new Float32Array(w * h * 4) });
    /** Analytic region: fn(x, y) -> [lum, alpha] at a sample point (pixel centres at +0.5), ss x ss supersampled. */
    function field(w, h, fn, ss = 4) {
      const B = buf(w, h), d = B.d, inv = 1 / (ss * ss);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        let L = 0, A = 0;
        for (let j = 0; j < ss; j++) for (let i = 0; i < ss; i++) { const r = fn(x + (i + 0.5) / ss, y + (j + 0.5) / ss); L += r[0] * r[1]; A += r[1]; }
        const o = (y * w + x) * 4; d[o] = d[o + 1] = d[o + 2] = L * inv; d[o + 3] = A * inv;
      }
      return B;
    }
    /** Canvas-drawn region at ss x supersampling, box-filtered down in premultiplied space. */
    function drawn(w, h, ss, draw) {
      const c = document.createElement('canvas'); c.width = w * ss; c.height = h * ss;
      const x = c.getContext('2d', { willReadFrequently: true }); x.setTransform(ss, 0, 0, ss, 0, 0); x.lineCap = 'round'; x.lineJoin = 'round';
      draw(x, w, h);
      const s = x.getImageData(0, 0, w * ss, h * ss).data, B = buf(w, h), d = B.d, k = 1 / (ss * ss * 255), W2 = w * ss;
      for (let y = 0; y < h; y++) for (let x0 = 0; x0 < w; x0++) {
        let r = 0, g = 0, b = 0, a = 0;
        for (let j = 0; j < ss; j++) for (let i = 0; i < ss; i++) {
          const o = ((y * ss + j) * W2 + x0 * ss + i) * 4, al = s[o + 3] / 255; r += s[o] * al; g += s[o + 1] * al; b += s[o + 2] * al; a += s[o + 3];
        }
        const o = (y * w + x0) * 4; d[o] = r * k; d[o + 1] = g * k; d[o + 2] = b * k; d[o + 3] = a * k;
      }
      return B;
    }
    /** Separable gaussian (premultiplied, zero outside). */
    function blur(B, sigma) {
      if (sigma <= 0) return B;
      const { w, h, d } = B, r = Math.ceil(sigma * 3), K = [];
      let sum = 0; for (let i = -r; i <= r; i++) { const v = Math.exp(-i * i / (2 * sigma * sigma)); K.push(v); sum += v; }
      for (let i = 0; i < K.length; i++) K[i] /= sum;
      const t = new Float32Array(d.length);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 4; c++) {
        let v = 0; for (let i = -r; i <= r; i++) { const xx = x + i; if (xx >= 0 && xx < w) v += d[(y * w + xx) * 4 + c] * K[i + r]; }
        t[(y * w + x) * 4 + c] = v;
      }
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 4; c++) {
        let v = 0; for (let i = -r; i <= r; i++) { const yy = y + i; if (yy >= 0 && yy < h) v += t[(yy * w + x) * 4 + c] * K[i + r]; }
        d[(y * w + x) * 4 + c] = v;
      }
      return B;
    }
    /** Zero the outer `b` px ring (the contract's transparent border). */
    function border(B, b = PAD) {
      const { w, h, d } = B;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (x < b || y < b || x >= w - b || y >= h - b) d.fill(0, (y * w + x) * 4, (y * w + x) * 4 + 4);
      return B;
    }
    /** +-1 LSB triangular dither on alpha (colour kept), so wide soft gradients never band when magnified. */
    function dither(B, seed) {
      const r = rng(seed), d = B.d;
      for (let o = 0; o < d.length; o += 4) {
        const a = d[o + 3]; if (a <= 0 || a >= 1) continue;
        const a2 = clamp(a + (r() + r() - 1) / 255), s = a2 / a; d[o] *= s; d[o + 1] *= s; d[o + 2] *= s; d[o + 3] = a2;
      }
      return B;
    }

    // ================================================================ painters (all white / grey)
    // ---- cloud wisps: a soft envelope times domain-warped fbm detail, turned into alpha as optical depth
    //      (1 - exp(-k D)), so cores are dense and fringes feather out. Lit from the upper left: brighter where the
    //      density falls off toward the light, greyer undersides. A: long torn streak. B: billowing cloud.
    //      C: mist band. D: a band broken into drifting patches. Pre-blurred.
    function wisp(w, h, seed, kind, sigma) {
      const n1 = makeNoise(seed), n2 = makeNoise(seed + 17), n3 = makeNoise(seed + 31), rr = rng(seed + 5);
      const SS = 2, W2 = w * SS, H2 = h * SS, m = sigma * 3 + PAD + 3, D = new Float32Array(W2 * H2);
      const blobs = [];
      if (kind === 'B') for (let k = 0; k < 9; k++) { const u = -0.72 + k * 0.18 + (rr() - 0.5) * 0.08; blobs.push([u, -0.02 - 0.34 * Math.pow(Math.cos(u * 1.6), 2) * (0.6 + rr() * 0.5), 0.2 + rr() * 0.14]); }
      const patches = kind === 'D' ? [[-0.62, 0.3, 0.06], [0.02, 0.36, -0.1], [0.62, 0.26, 0.08]] : null;
      const shape = (u, v) => {
        const qu = u + 0.12 * fbm(n1, u * 1.6 + 3.1, v * 1.6, 4), qv = v + 0.2 * fbm(n1, u * 1.6 - 7.3, v * 1.6 + 5.2, 4);
        const au = Math.abs(qu);
        if (kind === 'A') {
          const cv = 0.16 * Math.sin(qu * 1.9 + 0.8) - 0.08 * qu;
          const th = 0.46 * (0.75 + 0.5 * (0.5 + fbm(n2, qu * 1.4, 2.2, 3))) * Math.pow(Math.max(0, 1 - au * au), 0.5);
          const env = Math.exp(-Math.pow(au / 0.9, 6)) * Math.exp(-Math.pow((qv - cv) / Math.max(th, 1e-3), 2));
          const fil = ridged(n3, qu * 1.7 + 4, qv * 5.2, 4), tear = sm(-0.25, 0.3, fbm(n2, qu * 3.2 + 5, qv * 4.5, 4));
          return env * clamp(0.2 + 1.35 * fil) * (0.4 + 0.6 * tear);
        }
        if (kind === 'B') {
          let env = 0;
          for (const [cu, cv, r] of blobs) env = Math.max(env, Math.exp(-(((qu - cu) / (r * 1.3)) ** 2 + ((qv - cv) / r) ** 2)));
          env = Math.max(env, Math.exp(-((qu / 0.92) ** 6 + ((qv - 0.2) / 0.26) ** 2)));
          env *= sm(0.62, 0.4, qv);                                       // flattish base
          const puff = 0.55 + 0.75 * fbm(n3, qu * 3.4, qv * 3.4, 5), wisp = 0.8 + 0.4 * fbm(n2, qu * 2, qv * 8, 3);
          return env * clamp(puff) * wisp;
        }
        const cv = 0.07 * Math.sin(qu * 2.4 + 1.1);
        const th = 0.34 * (0.7 + 0.6 * (0.5 + fbm(n2, qu * 2, 7.7, 3)));
        let env = Math.exp(-Math.pow(au / 0.93, 8)) * Math.exp(-Math.pow((qv - cv) / th, 2));
        if (patches) { env = 0; for (const [pu, pw, pv] of patches) env = Math.max(env, Math.exp(-Math.pow((qu - pu) / pw, 4)) * Math.exp(-Math.pow((qv - cv - pv) / (th * 0.9), 2))); }
        const streak = 0.45 + 0.9 * fbm(n3, qu * 1.8, qv * 11, 5);
        return env * clamp(streak) * (0.7 + 0.3 * sm(-0.3, 0.3, fbm(n2, qu * 4, qv * 3, 3)));
      };
      for (let j = 0; j < H2; j++) for (let i = 0; i < W2; i++) {
        const x = (i + 0.5) / SS, y = (j + 0.5) / SS;
        D[j * W2 + i] = Math.max(0, shape((x - w / 2) / (w / 2 - m), (y - h / 2) / (h / 2 - m)));
      }
      const at2 = (i, j) => D[clamp(Math.round(j), 0, H2 - 1) * W2 + clamp(Math.round(i), 0, W2 - 1)];
      const off = 9 * SS, k = kind === 'B' ? 3.2 : 2.6;
      const B = buf(w, h), d = B.d;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        let L = 0, A = 0;
        for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
          const I = x * SS + i, J = y * SS + j, dd = D[J * W2 + I];
          const a = 0.9 * (1 - Math.exp(-k * dd * dd * 1.6 - k * 0.2 * dd)) / (1 - Math.exp(-k * 1.8));
          if (a <= 0.001) continue;
          const lit = clamp(0.5 + 2.4 * (dd - at2(I + LD[0] * off, J + LD[1] * off)));
          const vy = (y - h / 2) / (h / 2);
          const lum = clamp(0.5 + 0.42 * lit - 0.1 * vy + 0.08 * clamp(dd), 0.4, 1);
          L += lum * Math.min(a, 0.9); A += Math.min(a, 0.9);
        }
        const o = (y * w + x) * 4; d[o] = d[o + 1] = d[o + 2] = L / (SS * SS); d[o + 3] = A / (SS * SS);
      }
      blur(B, sigma);
      let mx = 0; for (let o = 3; o < d.length; o += 4) mx = Math.max(mx, d[o]);
      if (mx > 0) { const k = 0.9 / mx; for (let o = 0; o < d.length; o++) d[o] *= k; }   // contract: alpha peak 0.9
      return dither(border(B), seed + 99);
    }

    // ---- leaves for the vines (leaf frame: base at 0, pointing +x)
    function leafPath(c, len, wid, bend) {
      const ty = bend * len;
      c.beginPath(); c.moveTo(0, 0);
      c.bezierCurveTo(len * 0.18, -wid * 1.25, len * 0.62, -wid * 1.15 + ty * 0.45, len, ty);
      c.bezierCurveTo(len * 0.62, wid * 1.15 + ty * 0.45, len * 0.18, wid * 1.25, 0, 0);
      c.closePath();
    }
    const grey = (v, a = 1) => `rgba(${Math.round(v * 255)},${Math.round(v * 255)},${Math.round(v * 255)},${a})`;
    /** A leaf in grey with a lit rim along the edge that faces the key light. */
    function leafGrey(c, x, y, ang, len, wid, bend, lum) {
      c.save(); c.translate(x, y); c.rotate(ang);
      leafPath(c, len, wid, bend); c.fillStyle = grey(lum); c.fill();
      c.save(); leafPath(c, len, wid, bend); c.clip();
      const dl = [LD[0] * Math.cos(-ang) - LD[1] * Math.sin(-ang), LD[0] * Math.sin(-ang) + LD[1] * Math.cos(-ang)];
      const g = c.createLinearGradient(len / 2 + dl[0] * len * 0.55, dl[1] * len * 0.55, len / 2, 0);
      g.addColorStop(0, grey(1, 0.9)); g.addColorStop(1, grey(1, 0));
      c.strokeStyle = g; c.lineWidth = Math.max(1.5, wid * 0.3); leafPath(c, len, wid, bend); c.stroke();
      c.strokeStyle = grey(lum * 0.7, 0.8); c.lineWidth = Math.max(0.8, wid * 0.08);
      c.beginPath(); c.moveTo(len * 0.05, 0); c.quadraticCurveTo(len * 0.55, bend * len * 0.3, len * 0.92, bend * len * 0.85); c.stroke();
      c.restore(); c.restore();
    }
    function stemGrey(c, S, lum) { c.fillStyle = grey(lum); poly(c, outline(S)); c.fill(); }

    /** Hanging vine for the fg (top-centre = attachment). B carries hanging bell flowers and a second tendril. */
    function vine(w, h, seed, variant) {
      return border(blur(drawn(w, h, 3, (c) => {
        const r = rng(seed), N = makeNoise(seed), m = 12;
        const pts = [];
        for (let k = 0; k <= 12; k++) { const t = k / 12; pts.push([w / 2 + 16 * N(t * 2.6, 1.3) * Math.min(1, t * 3) + 7 * Math.sin(t * 7 + seed), -4 + t * (h - 40), lerp(9, 2.6, Math.pow(t, 0.85))]); }
        const S = spline(pts, 14);
        stemGrey(c, S, 0.66);
        let side = r() < 0.5 ? -1 : 1;
        for (let s = 22; s < S.len - 16; s += 17 + r() * 10) {
          const i = S.findIndex(p => p.s >= s), p = S[i], t = s / S.len;
          side = -side;
          let len = lerp(50, 24, t) * (0.8 + r() * 0.35);
          const ang = Math.PI / 2 + side * (0.55 + r() * 0.55);
          // keep the leaf (and its blur) inside the region
          for (let k = 0; k < 6; k++) { const tx = p.x + Math.cos(ang) * len; if (tx > m && tx < w - m) break; len *= 0.82; }
          leafGrey(c, p.x, p.y, ang, len, len * 0.3, -0.14 * side, 0.78 + r() * 0.2);
          if (variant === 'B' && r() < 0.18 && t > 0.25) {   // a short tendril curl off the stem
            c.strokeStyle = grey(0.7); c.lineWidth = 1.6; c.beginPath();
            for (let k = 0; k <= 16; k++) { const a = k / 16 * Math.PI * 1.6, rr = 9 * (1 - k / 20); const px = p.x - side * 6 + Math.cos(a) * rr * -side, py = p.y + 8 + Math.sin(a) * rr; k ? c.lineTo(px, py) : c.moveTo(px, py); }
            c.stroke();
          }
        }
        const e = S[S.length - 1];
        if (variant === 'A') {           // a curling tip
          c.strokeStyle = grey(0.72); c.lineWidth = 2.4; c.beginPath();
          for (let k = 0; k <= 30; k++) { const a = k / 30 * Math.PI * 2.2 + 1.2, rr = 11 * (1 - k / 34); const px = e.x + Math.cos(a) * rr, py = e.y + 10 + Math.sin(a) * rr; k ? c.lineTo(px, py) : c.moveTo(px, py); }
          c.stroke();
        } else {                         // three hanging bell flowers
          for (let k = 0; k < 3; k++) {
            const bx = e.x + (k - 1) * 11, by = e.y + 4 + (k === 1 ? 14 : 4);
            c.strokeStyle = grey(0.7); c.lineWidth = 1.3; c.beginPath(); c.moveTo(e.x, e.y); c.quadraticCurveTo(bx, e.y, bx, by); c.stroke();
            c.fillStyle = grey(0.95); c.beginPath(); c.moveTo(bx - 5, by + 9); c.quadraticCurveTo(bx - 6, by - 1, bx, by - 1); c.quadraticCurveTo(bx + 6, by - 1, bx + 5, by + 9);
            c.quadraticCurveTo(bx, by + 6, bx - 5, by + 9); c.fill();
          }
        }
      }), 3));
    }
    /** Thin tendril for the world's limbs: crisp, 2-3 leaves, a glowing bud at the tip. */
    function vineThin(w, h, seed) {
      return border(drawn(w, h, 4, (c) => {
        const r = rng(seed), N = makeNoise(seed);
        const pts = [];
        for (let k = 0; k <= 10; k++) { const t = k / 10; pts.push([w / 2 + 7 * N(t * 2.2, 4.4) * Math.min(1, t * 2.5) + 3 * Math.sin(t * 6), -2 + t * (h - 44), lerp(4.2, 1.8, t)]); }
        const S = spline(pts, 16);
        stemGrey(c, S, 0.84);
        [[0.3, -1], [0.52, 1], [0.74, -1]].forEach(([t, side]) => {
          const p = S[Math.round(t * (S.length - 1))], len = 22 + r() * 4;
          leafGrey(c, p.x, p.y, Math.PI / 2 + side * 0.95, len, 7.5, -0.12 * side, 0.9);
        });
        const e = S[S.length - 1];
        const gr = c.createRadialGradient(e.x, e.y + 8, 0, e.x, e.y + 8, 16);
        gr.addColorStop(0, grey(1, 0.75)); gr.addColorStop(0.35, grey(1, 0.3)); gr.addColorStop(1, grey(1, 0));
        c.fillStyle = gr; c.beginPath(); c.arc(e.x, e.y + 8, 16, 0, Math.PI * 2); c.fill();
        c.fillStyle = grey(1); c.beginPath(); c.ellipse(e.x, e.y + 8, 4.2, 5.4, 0, 0, Math.PI * 2); c.fill();
      }));
    }

    /** Light-fall: a luminous column of light-water, bright core, strands, fading over its lower 30%. */
    function lightfall(w, h, seed) {
      const n = makeNoise(seed), cx = w / 2;
      return dither(border(field(w, h, (x, y) => {
        const t = y / h, spread = 1 + 0.45 * t;
        const dx = (x - cx - 2.5 * n(t * 3, 1.5)) / spread;
        const strands = 0.72 + 0.28 * n(dx / 3.2, t * 5 + 2) + 0.12 * n(dx / 1.4, t * 11);
        const core = g2(dx * dx, 4.2), body = g2(dx * dx, 11), halo = g2(dx * dx, 22);
        const top = sm(0, 10, y), fade = 1 - sm(0.68, 0.995, t), win = sm(46, 38, Math.abs(x - cx));
        const a = clamp((0.9 * core + 0.55 * body * strands + 0.22 * halo) * top * fade * win);
        return [clamp(0.84 + 0.16 * core), a];
      }, 3)), seed);
    }
    /** Radial glow: a soft core in a wide halo, 1 at the centre, 0 at the edge. */
    const glow = (w, h) => dither(border(field(w, h, (x, y) => {
      const r = Math.hypot(x - w / 2, y - h / 2) / (w / 2 - PAD - 1);
      if (r >= 1) return [1, 0];
      const win = Math.pow(1 - r * r, 2);
      return [1, win * (0.42 * g2(r * r, 0.2) + 0.58 * g2(r * r, 0.46))];
    }, 2)), 7);
    /** Shock ring: radius 0.42, width ~0.05 of the region, a sharper outer front and a faint inner wake. */
    const ring = (w, h) => dither(border(field(w, h, (x, y) => {
      const d = Math.hypot(x - w / 2, y - h / 2), R = 0.42 * w, e = d - R;
      const a = e > 0 ? g2(e * e, 0.018 * w) : g2(e * e, 0.03 * w);
      const wake = e < 0 ? 0.1 * sm(0.18 * w, R, d) : 0;
      return [1, clamp(screen(a, wake) * sm(w / 2 - PAD, w / 2 - PAD - 6, d))];
    }, 4)), 8);
    /** Out-of-focus disc (A) and its hexagonal-aperture twin (B): flat interior 0.55, brighter rim 0.9, soft edge. */
    function bokeh(w, h, hex) {
      const R = w / 2 - PAD - 3.5;
      const ax = [0, 1, 2].map(k => { const a = Math.PI / 6 + k * Math.PI / 3; return [Math.cos(a), Math.sin(a)]; });
      return border(field(w, h, (x, y) => {
        const px = x - w / 2, py = y - h / 2;
        let d, Rr = R;
        if (hex) { Rr = R * Math.cos(Math.PI / 6); d = Math.pow(ax.reduce((s, n) => s + Math.pow(Math.abs(px * n[0] + py * n[1]), 10), 0), 1 / 10); }
        else d = Math.hypot(px, py);
        const edge = 1 - sm(Rr - 1.5, Rr + 1.5, d);
        const rim = sm(Rr - (hex ? 6.5 : 5.5), Rr - 1.2, d), rings = 0.006 * Math.sin(d / Rr * 13);
        return [1, edge * (0.53 + 0.04 * d / Rr + rings + (hex ? 0.27 : 0.35) * rim)];
      }, 4));
    }
    /** Vignette: black, alpha 0 inside radius 0.55 (of the half size) to 1 in the corners. Runs to its edge. */
    const vignette = (w, h) => dither(field(w, h, (x, y) => {
      const u = (x - w / 2) / (w / 2), v = (y - h / 2) / (h / 2), r = Math.hypot(u, v);
      return [0, Math.pow(sm(0.55, 1.414, r), 1.15)];
    }, 2), 9);
    /** 4-point sparkle with long thin rays and shorter diagonals (the lib.js sparkle look). */
    function sparkleField(w, h, len, thick, core, diag = 0.5) {
      return border(field(w, h, (x, y) => {
        const px = x - w / 2, py = y - h / 2, d2 = px * px + py * py;
        const ray = (a, b, L, k) => { const t = Math.abs(a) / L; if (t >= 1) return 0; const s = thick * (0.45 + 0.8 * (1 - t)); return k * Math.pow(1 - t, 1.6) * g2(b * b, s); };
        const q = (px + py) * Math.SQRT1_2, r2 = (px - py) * Math.SQRT1_2;
        const a = screen(ray(px, py, len, 1), ray(py, px, len, 1), ray(q, r2, len * 0.55, diag), ray(r2, q, len * 0.55, diag),
          g2(d2, core), 0.4 * g2(d2, core * 2.8));
        return [1, a * sm(w / 2 - PAD, w / 2 - PAD - 3, Math.sqrt(d2))];
      }, 4));
    }
    const dotField = (w, h, core, halo, haloA, lumHalo = 1) => border(field(w, h, (x, y) => {
      const d2 = (x - w / 2) ** 2 + (y - h / 2) ** 2, c = g2(d2, core);
      return [clamp(lumHalo + (1 - lumHalo) * c), screen(c, haloA * g2(d2, halo)) * sm(w / 2 - PAD, w / 2 - PAD - 2.5, Math.sqrt(d2))];
    }, 4));
    /** Ember: a hot point low in the region with a short upward smear, like a tiny rising flame. */
    const ember = (w, h) => border(field(w, h, (x, y) => {
      const hx = w / 2, hy = h * 0.6, dx = x - hx, dy = y - hy, d2 = dx * dx + dy * dy;
      const t = clamp((hy - y) / 15), wob = 0.8 * Math.sin(t * 5);
      const smear = y < hy ? 0.75 * Math.pow(1 - t, 1.4) * g2((dx - wob * t) ** 2, 1.9 * (1 - t) + 0.45) : 0;
      const c = g2(d2, 1.7), halo = 0.35 * g2(d2, 3.6);
      return [clamp(0.82 + 0.18 * c), screen(c, smear, halo) * sm(w / 2 - PAD, w / 2 - PAD - 3, Math.sqrt(d2) * 0.8)];
    }, 4));
    /** Glitch bar: hard top and bottom edges, soft ends, broken into segments like a failing scanline. */
    function bar(w, h, seed) {
      const r = rng(seed), cuts = [];
      let x = 10 + r() * 20; while (x < w - 20) { cuts.push([x, 1 + r() * 3.5, 0.75 + r() * 0.25]); x += 18 + r() * 42; }
      return border(field(w, h, (x, y) => {
        if (y < PAD || y >= h - PAD) return [1, 0];
        let lum = 1, a = sm(PAD, PAD + 22, x) * sm(w - PAD, w - PAD - 22, x);
        for (const [cx, gw, l] of cuts) { if (x >= cx && x < cx + gw) a *= 0.12; if (x >= cx) lum = l; }
        if (y < PAD + 2 || y >= h - PAD - 2) lum *= 1.0; else lum *= 0.9;
        return [lum, a];
      }, 4));
    }
    /** Shooting star: bright head on the right, tapering tail fading to the left. */
    const streak = (w, h) => border(field(w, h, (x, y) => {
      const hx = w - PAD - 16, hy = h / 2, dy = y - hy, t = clamp((hx - x) / (hx - PAD - 4));
      const wid = 2.4 * Math.pow(1 - t, 0.9) + 0.5;
      const tail = x <= hx ? Math.pow(1 - t, 1.7) * g2(dy * dy, wid) : 0;
      const d2 = (x - hx) ** 2 + dy * dy, head = g2(d2, 2.2), halo = 0.45 * g2(d2, 5.5);
      return [1, screen(tail * 0.9, head, halo) * sm(h / 2 - PAD, h / 2 - PAD - 3, Math.abs(dy)) * sm(w - PAD, w - PAD - 3, x)];
    }, 4));
    /** Floating shard: a faceted rock lit from the upper left with a glowing crystal vein; A chunky, B tall. */
    function shard(w, h, seed, variant) {
      return border(blur(drawn(w, h, 4, (c) => {
        const r = rng(seed);
        const out = variant === 'A'
          ? [[13, 38], [26, 22], [48, 15], [70, 19], [84, 33], [80, 47], [66, 61], [55, 83], [44, 72], [27, 60]]
          : [[36, 9], [55, 13], [70, 32], [68, 55], [56, 86], [45, 74], [30, 52], [27, 28]];
        const apex = variant === 'A' ? [43, 36] : [47, 38], H = variant === 'A' ? 24 : 20;
        // facets: triangles apex -> edge, shaded by their normal against the key light
        for (let i = 0; i < out.length; i++) {
          const p = out[i], q = out[(i + 1) % out.length];
          const e1 = [p[0] - apex[0], p[1] - apex[1], -H], e2 = [q[0] - apex[0], q[1] - apex[1], -H];
          let n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
          if (n[2] < 0) n = n.map(v => -v);
          const nl = Math.hypot(...n); n = n.map(v => v / nl);
          const lit = Math.max(0, n[0] * L3[0] + n[1] * L3[1] + n[2] * L3[2]);
          const lower = clamp(((p[1] + q[1]) / 2 - apex[1]) / 40);
          c.fillStyle = grey(clamp(0.2 + 0.72 * Math.pow(lit, 1.3) - 0.08 * lower + (r() - 0.5) * 0.05));
          c.beginPath(); c.moveTo(...apex); c.lineTo(...p); c.lineTo(...q); c.closePath(); c.fill();
          c.strokeStyle = c.fillStyle; c.lineWidth = 0.6; c.stroke();
        }
        // rim on the edges whose outward normal faces the light
        for (let i = 0; i < out.length; i++) {
          const p = out[i], q = out[(i + 1) % out.length], nx = q[1] - p[1], ny = -(q[0] - p[0]), nl = Math.hypot(nx, ny);
          const f = (nx * LD[0] + ny * LD[1]) / nl;
          if (f > 0.2) { c.strokeStyle = grey(1, clamp(f * 1.1)); c.lineWidth = 1.6; c.beginPath(); c.moveTo(...p); c.lineTo(...q); c.stroke(); }
        }
        // crystal vein: glow, then a bright core line
        const vein = variant === 'A' ? [[27, 44], [37, 50], [45, 47], [53, 57], [60, 55], [66, 50]] : [[44, 24], [47, 36], [44, 47], [49, 58], [51, 70]];
        c.save(); c.beginPath(); c.moveTo(...out[0]); out.slice(1).forEach(p => c.lineTo(...p)); c.closePath(); c.clip();
        c.filter = `blur(${2.5 * c.getTransform().a}px)`; c.strokeStyle = grey(1, 0.75); c.lineWidth = 5; c.beginPath(); c.moveTo(...vein[0]); vein.slice(1).forEach(p => c.lineTo(...p)); c.stroke();
        c.filter = 'none'; c.strokeStyle = grey(1); c.lineWidth = 1.6; c.beginPath(); c.moveTo(...vein[0]); vein.slice(1).forEach(p => c.lineTo(...p)); c.stroke();
        c.restore();
        // a small crystal cluster breaking out of the top (A) or the side (B)
        const cl = variant === 'A' ? [[56, 19, -1.2, 13, 5], [63, 21, -0.75, 10, 4], [50, 18, -1.75, 8, 3.5]] : [[66, 40, -0.35, 13, 5], [68, 48, 0.1, 9, 4]];
        for (const [x, y, a, len, wd] of cl) {
          c.save(); c.translate(x, y); c.rotate(a);
          c.beginPath(); c.moveTo(0, -wd / 2); c.lineTo(len * 0.75, -wd / 2); c.lineTo(len, 0); c.lineTo(len * 0.75, wd / 2); c.lineTo(0, wd / 2); c.closePath();
          c.fillStyle = grey(0.95); c.fill();
          c.beginPath(); c.moveTo(0, 0); c.lineTo(len, 0); c.lineTo(len * 0.75, wd / 2); c.lineTo(0, wd / 2); c.closePath(); c.fillStyle = grey(0.62); c.fill();
          c.restore();
        }
      }), 0.45));
    }

    // ================================================================ assembly
    const PAINT = {
      wispA: (w, h) => wisp(w, h, 2101, 'A', 6), wispB: (w, h) => wisp(w, h, 2203, 'B', 7),
      wispC: (w, h) => wisp(w, h, 2307, 'C', 6), wispD: (w, h) => wisp(w, h, 2409, 'D', 6),
      vineA: (w, h) => vine(w, h, 2501, 'A'), vineB: (w, h) => vine(w, h, 2603, 'B'), vineThin: (w, h) => vineThin(w, h, 2707),
      lightfall: (w, h) => lightfall(w, h, 2801), glow, ring, bokehA: (w, h) => bokeh(w, h, false), bokehB: (w, h) => bokeh(w, h, true),
      vignette, star4: (w, h) => sparkleField(w, h, w / 2 - PAD - 2, 1.05, 1.5), stardot: (w, h) => dotField(w, h, 1.25, 3.1, 0.42),
      firefly: (w, h) => dotField(w, h, 1.8, 6.5, 0.62, 0.9), ember, mote: (w, h) => dotField(w, h, 1.45, 2.7, 0.5),
      spark: (w, h) => sparkleField(w, h, w / 2 - PAD - 1.5, 0.8, 1.1, 0.35), bar: (w, h) => bar(w, h, 2903),
      shardA: (w, h) => shard(w, h, 3001, 'A'), shardB: (w, h) => shard(w, h, 3103, 'B'), streak,
    };
    /** Render every region into the sheet: premultiplied float -> straight RGBA8, alpha-bled per region. */
    function build() {
      const t0 = performance.now(), sheet = new Float32Array(AW * AH * 4), stats = {};
      for (const [name, [rx, ry, rw, rh]] of Object.entries(ATLAS.regions)) {
        const paint = PAINT[name];
        if (!paint) { console.log('sprites: no painter for region', name); continue; }
        const B = paint(rw, rh);
        if (B.w !== rw || B.h !== rh) throw new Error(`sprites: ${name} painted ${B.w}x${B.h}, region is ${rw}x${rh}`);
        let maxA = 0, borderA = 0;
        for (let y = 0; y < rh; y++) for (let x = 0; x < rw; x++) {
          const s = (y * rw + x) * 4, o = ((ry + y) * AW + rx + x) * 4;
          for (let k = 0; k < 4; k++) sheet[o + k] = B.d[s + k];
          maxA = Math.max(maxA, B.d[s + 3]);
          if (x < PAD || y < PAD || x >= rw - PAD || y >= rh - PAD) borderA = Math.max(borderA, B.d[s + 3]);
        }
        stats[name] = { maxAlpha: +maxA.toFixed(3), borderAlpha: +borderA.toFixed(4) };
      }
      const px = new Uint8Array(AW * AH * 4);
      for (let i = 0; i < AW * AH; i++) {
        const o = i * 4, a = sheet[o + 3], a8 = Math.round(clamp(a) * 255);
        if (a8 === 0) { px[o] = px[o + 1] = px[o + 2] = 255; continue; }
        px[o] = Math.round(clamp(sheet[o] / a) * 255); px[o + 1] = Math.round(clamp(sheet[o + 1] / a) * 255);
        px[o + 2] = Math.round(clamp(sheet[o + 2] / a) * 255); px[o + 3] = a8;
      }
      for (const r of Object.values(ATLAS.regions)) bleed(px, AW, r);
      console.log(`sprites: ${Object.keys(stats).length} regions in ${Math.round(performance.now() - t0)} ms`);
      return { px, stats };
    }
    /** Alpha bleed inside one region: every alpha-0 pixel takes the colour of its nearest visible pixel (8-neighbour
     *  BFS), alpha stays 0. A region with no visible pixel keeps white. */
    function bleed(px, W, [rx, ry, rw, rh]) {
      const n = rw * rh, seen = new Uint8Array(n), q = new Int32Array(n); let qt = 0;
      for (let y = 0; y < rh; y++) for (let x = 0; x < rw; x++) { const i = y * rw + x; if (px[((ry + y) * W + rx + x) * 4 + 3] > 0) { seen[i] = 1; q[qt++] = i; } }
      for (let qh = 0; qh < qt; qh++) {
        const i = q[qh], x = i % rw, y = (i / rw) | 0, so = ((ry + y) * W + rx + x) * 4;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy; if ((!dx && !dy) || nx < 0 || ny < 0 || nx >= rw || ny >= rh) continue;
          const k = ny * rw + nx; if (seen[k]) continue; seen[k] = 1; q[qt++] = k;
          const o = ((ry + ny) * W + rx + nx) * 4; px[o] = px[so]; px[o + 1] = px[so + 1]; px[o + 2] = px[so + 2];
        }
      }
    }
    /** A canvas whose PNG export keeps straight RGBA, including the colour of alpha-0 pixels. */
    function straightCanvas(px, w, h) {
      const c = document.createElement('canvas'); c.width = w; c.height = h;
      const gl = c.getContext('webgl', { premultipliedAlpha: false, preserveDrawingBuffer: true, alpha: true, antialias: false });
      const sh = (t, s) => { const o = gl.createShader(t); gl.shaderSource(o, s); gl.compileShader(o); return o; };
      const pr = gl.createProgram();
      gl.attachShader(pr, sh(gl.VERTEX_SHADER, 'attribute vec2 p;varying vec2 u;void main(){u=p*0.5+0.5;gl_Position=vec4(p,0,1);}'));
      gl.attachShader(pr, sh(gl.FRAGMENT_SHADER, 'precision highp float;varying vec2 u;uniform sampler2D t;void main(){gl_FragColor=texture2D(t,vec2(u.x,1.0-u.y));}'));
      gl.linkProgram(pr); gl.useProgram(pr);
      gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, px);
      for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
      gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer()); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
      const loc = gl.getAttribLocation(pr, 'p'); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      gl.viewport(0, 0, w, h); gl.disable(gl.BLEND); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      return c;
    }
    /** A labelled review sheet: each region over dark violet with its outline and name, plus tinted swatches. */
    function previewSheet(px) {
      const s = 1.5, c = document.createElement('canvas'); c.width = AW * s; c.height = AH * s;
      const x = c.getContext('2d'); x.fillStyle = '#120a22'; x.fillRect(0, 0, c.width, c.height);
      const src = document.createElement('canvas'); src.width = AW; src.height = AH;
      const id = new ImageData(new Uint8ClampedArray(px.buffer.slice(0)), AW, AH); src.getContext('2d').putImageData(id, 0, 0);
      x.imageSmoothingQuality = 'high'; x.drawImage(src, 0, 0, AW * s, AH * s);
      x.font = '12px sans-serif'; x.textBaseline = 'top';
      for (const [name, [rx, ry, rw, rh]] of Object.entries(ATLAS.regions)) {
        x.strokeStyle = 'rgba(95,224,255,0.45)'; x.lineWidth = 1; x.strokeRect(rx * s + 0.5, ry * s + 0.5, rw * s - 1, rh * s - 1);
        x.fillStyle = 'rgba(0,0,0,0.55)'; const tw = x.measureText(name).width; x.fillRect(rx * s + 2, ry * s + 2, tw + 6, 15);
        x.fillStyle = '#ffe07a'; x.fillText(name, rx * s + 5, ry * s + 3);
      }
      return c.toDataURL('image/png');
    }

    window.SpriteAtlas = { build, straightCanvas, previewSheet, size: [AW, AH] };
    if (typeof LAYERS !== 'undefined') LAYERS.sprites = async function () {
      const { px } = build(), c = straightCanvas(px, AW, AH);
      window.__last = c;
      return c;
    };
  }

  // ============================================================================================ node side
  function nodeMain() {
    const fs = require('fs'), path = require('path'), zlib = require('zlib'), crypto = require('crypto');
    const ART = path.resolve(__dirname, '..'), OUT = path.join(ART, 'out');
    const R = JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8'));
    const A = R.atlas || SNAP;
    let chromium; try { ({ chromium } = require('playwright')); } catch (e) { console.error('needs playwright: export NODE_PATH=$(npm root -g)'); process.exit(2); }
    const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
    const crc32 = b => { let c = 0xffffffff; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
    const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, 'ascii'), data]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, cr]); };
    /** RGBA8 PNG, per-row filter chosen by minimum sum of absolute differences, deflate level 9. Deterministic. */
    function encodePNG(px, w, h) {
      const stride = w * 4, raw = Buffer.alloc((stride + 1) * h), row = Buffer.alloc(stride);
      for (let y = 0; y < h; y++) {
        let best = null, bestSum = Infinity, bestF = 0;
        for (let f = 0; f < 5; f++) {
          let sum = 0;
          for (let x = 0; x < stride; x++) {
            const v = px[y * stride + x], a = x >= 4 ? px[y * stride + x - 4] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= 4 && y ? px[(y - 1) * stride + x - 4] : 0;
            let p = v;
            if (f === 1) p = v - a; else if (f === 2) p = v - b; else if (f === 3) p = v - ((a + b) >> 1);
            else if (f === 4) { const q = a + b - c, pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); p = v - (pa <= pb && pa <= pc ? a : pb <= pc ? b : c); }
            row[x] = p & 255; sum += row[x] < 128 ? row[x] : 256 - row[x];
          }
          if (sum < bestSum) { bestSum = sum; bestF = f; best = Buffer.from(row); }
        }
        raw[y * (stride + 1)] = bestF; best.copy(raw, y * (stride + 1) + 1);
      }
      const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
      return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
    }
    (async () => {
      const b = await chromium.launch({ args: ['--js-flags=--max-old-space-size=4096'] }), p = await b.newPage();
      p.on('console', m => console.log('[page]', m.text())); p.on('pageerror', e => console.log('[err]', e.message));
      await p.setContent('<html><body></body></html>');
      await p.evaluate(realm => { window.REALM = realm; }, R);
      await p.addScriptTag({ content: fs.readFileSync(path.join(ART, 'lib.js'), 'utf8') });
      await p.addScriptTag({ content: fs.readFileSync(__filename, 'utf8') });
      const res = await p.evaluate(() => { const r = SpriteAtlas.build(); let s = ''; const u = r.px; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return { b64: btoa(s), stats: r.stats, prev: SpriteAtlas.previewSheet(r.px) }; });
      await b.close();
      const [W, H] = A.size, px = Buffer.from(res.b64, 'base64');
      if (px.length !== W * H * 4) throw new Error('bad atlas size ' + px.length);
      const png = encodePNG(px, W, H);
      fs.mkdirSync(OUT, { recursive: true });
      fs.writeFileSync(path.join(OUT, A.file || 'sprites.png'), png);
      fs.writeFileSync(path.join(OUT, 'sprites_prev.png'), Buffer.from(res.prev.split(',')[1], 'base64'));
      // ---- sprites.json: the rects the client feeds to ImageRectOffset / ImageRectSize, per tier
      // realm.json atlas.looks keys name one region ("glow"), a letter range ("wispA-D") or alternatives ("vineA/B")
    const lookFor = name => {
      for (const [k, v] of Object.entries(A.looks || {})) {
        if (k === name) return v;
        let m = /^([a-z]+)([A-Z])-([A-Z])$/.exec(k);
        if (m && name.startsWith(m[1]) && name.length === m[1].length + 1 && name.slice(-1) >= m[2] && name.slice(-1) <= m[3]) return v;
        m = /^([a-z]+)([A-Z](?:\/[A-Z])+)$/.exec(k);
        if (m && name.startsWith(m[1]) && m[2].split('/').includes(name.slice(m[1].length))) return v;
      }
      return null;
    };
    const half = r => r.map(v => v / 2), inset = r => [r[0] + A.padding, r[1] + A.padding, r[2] - 2 * A.padding, r[3] - 2 * A.padding];
      const regions = {};
      for (const [name, r] of Object.entries(A.regions)) {
        const o = { rect: r, lowRect: half(r), pivot: PIVOT[name] || [0.5, 0.5] };
        if (EDGE_EXTEND[name]) { o.edge = 'extend'; o.sampleRect = inset(r); o.lowSampleRect = half(inset(r)).map((v, i) => i < 2 ? Math.ceil(v) : Math.floor(v)); }
        else o.edge = 'transparent';
        const look = lookFor(name); if (look) o.look = look;
        o.maxAlpha = res.stats[name] ? res.stats[name].maxAlpha : 0;
        regions[name] = o;
      }
      const json = {
        about: 'Sprite atlas rects (generated by layers/sprites.js from realm.json atlas). HIGH uses `rect` on `file`; LOW uses `lowRect` on the half-size sheet roblox/tile.js makes from it. ImageRectOffset = rect[0..1], ImageRectSize = rect[2..3]. Every region is white/grey (tint with ImageColor3) and transparent in its 2 px border, except edge "extend" regions, which the client samples with sampleRect. pivot = AnchorPoint (hanging sprites attach at their top centre).',
        file: A.file || 'sprites.png', size: A.size, lowSize: A.lowSize || half(A.size), padding: A.padding,
        sha256: crypto.createHash('sha256').update(png).digest('hex'), regions,
      };
      fs.writeFileSync(path.join(OUT, 'sprites.json'), JSON.stringify(json, null, 1).replace(/\[\n\s+([^\[\]{}]*?)\n\s+\]/g, (m, g) => '[' + g.replace(/\s*\n\s*/g, ' ') + ']') + '\n');
      // ---- checks
      let bad = 0;
      for (const [name, s] of Object.entries(res.stats)) {
        const okB = EDGE_EXTEND[name] || s.borderAlpha === 0, okA = s.maxAlpha > 0.05;
        if (!okB || !okA) bad++;
        console.log(`  ${okB && okA ? 'ok  ' : 'WARN'} ${name.padEnd(9)} max alpha ${s.maxAlpha.toFixed(3)}  border ${EDGE_EXTEND[name] ? 'extends (sampled inset)' : s.borderAlpha === 0 ? 'transparent' : 'NOT transparent ' + s.borderAlpha}`);
      }
      let black = 0; for (let i = 0; i < W * H; i++) if (px[i * 4 + 3] === 0 && px[i * 4] + px[i * 4 + 1] + px[i * 4 + 2] === 0) black++;
      const vg = A.regions.vignette, vgPx = vg ? vg[2] * vg[3] : 0;
      console.log(`  ${black <= vgPx ? 'ok  ' : 'WARN'} alpha bleed: ${black} transparent-black pixels (the black vignette owns up to ${vgPx})`);
      console.log(`sprites -> out/${json.file} ${W}x${H} (${(png.length / 1024).toFixed(0)} KB), out/sprites.json (${Object.keys(regions).length} regions), out/sprites_prev.png${bad ? `  ${bad} WARN` : ''}`);
    })().catch(e => { console.error(e.stack || e.message); process.exit(1); });
  }

  if (typeof window !== 'undefined' && typeof document !== 'undefined') pageSide();
  else if (typeof require === 'function' && typeof module === 'object' && require.main === module) nodeMain();
})();
