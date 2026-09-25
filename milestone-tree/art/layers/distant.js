// Parallax depth 2, `far` (f = 0.25): the realm goes on forever. Many small hazy floating-island silhouettes at
// several sub-depths (the farthest nearly dissolved into the violet), far ridgelines sinking into a misty abyss at the
// bottom, and the ringed planet with its moon hanging upper right over the rift side. Strong atmospheric haze.
// Keep-clear (advisory): no island wider than 420 local px and none centred on a soft zone, so the centre stays calm.
// Painted at full local size 3008x1836, output at res.HIGH 0.5 -> 1504x918 (realm.json layers[far]).
// This file replaces the old layers/far.js; it registers LAYERS.distant and, for the manifest id, LAYERS.far.
(function () {
  // ================================================================ ISLAND KIT (begin)
  // Shared by layers/distant.js, layers/mid.js and layers/rocks.js. render.js loads one layer file per page, so each
  // file carries an identical copy of this block; edit it in one place and copy it to the other two.
  // Everything is drawn in layer-local px at full size (1 local px = 1 canvas px), then the REALM.md section 4
  // atmosphere pass runs, then the result is downsampled to size x res.HIGH.
  const KIT = (() => {
    const LV = (() => { const v = [-0.45, -0.62, 0.64], d = Math.hypot(...v); return v.map(a => a / d); })();
    const L2 = (() => { const d = Math.hypot(LV[0], LV[1]); return [LV[0] / d, LV[1] / d]; })();
    const KEY = [255, 214, 150], LILAC = [205, 182, 255], CRIMSON = [255, 46, 99];
    const mk = (w, h) => { const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h)); return c; };
    const cx2 = (c, read) => c.getContext('2d', read ? { willReadFrequently: true } : undefined);
    const luma = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const col = (c, a = 1) => `rgba(${Math.round(c[0])},${Math.round(c[1])},${Math.round(c[2])},${a})`;
    const mixc = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    const inEllipse = (x, y, z, grow = 0) => { const dx = (x - z[1]) / (z[3] + grow), dy = (y - z[2]) / (z[4] + grow); return dx * dx + dy * dy < 1; };

    // ---------------------------------------------------------------- exact euclidean distance transform
    // (Felzenszwalb & Huttenlocher). mask >= 0.5 is inside; returns the distance of every pixel to the outside.
    function edt(A, w, h) {
      const INF = 1e20, n = Math.max(w, h), f = new Float64Array(n), d = new Float64Array(n), v = new Int32Array(n), z = new Float64Array(n + 1);
      const g = new Float64Array(w * h);
      for (let i = 0; i < w * h; i++) g[i] = A[i] >= 0.5 ? INF : 0;
      const pass = (len) => {
        let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
        for (let q = 1; q < len; q++) {
          let s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
          while (s <= z[k]) { k--; s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]); }
          k++; v[k] = q; z[k] = s; z[k + 1] = INF;
        }
        k = 0;
        for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]; }
      };
      for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) f[y] = g[y * w + x]; pass(h); for (let y = 0; y < h; y++) g[y * w + x] = d[y]; }
      const out = new Float32Array(w * h);
      for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) f[x] = g[y * w + x]; pass(w); for (let x = 0; x < w; x++) out[y * w + x] = Math.sqrt(d[x]); }
      return out;
    }

    function bbox(pts, pad) {
      let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
      for (const p of pts) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
      x0 = Math.floor(x0 - pad); y0 = Math.floor(y0 - pad);
      return { x: x0, y: y0, w: Math.ceil(x1 + pad) - x0, h: Math.ceil(y1 + pad) - y0 };
    }

    // ---------------------------------------------------------------- lit mass
    // A silhouette polygon becomes a lit, textured rock: the silhouette is inflated into a height field (round bevel
    // + dome from the distance transform), broken into tilted facets (jittered Voronoi), lit by the key light
    // (world.js LIGHT, upper left) with a warm rim on up-left edges, a crimson rim on right edges inside the rift,
    // bounce light from below, strata, cracks, moss on up-facing edges and glowing crystal seams (emissive).
    function mass(S) {
      const polys = S.polys || [S.poly];
      const bb = bbox([].concat(...polys), S.pad || 16), w = bb.w, h = bb.h, N = w * h;
      const mc = mk(w, h), mx = cx2(mc, true);
      mx.translate(-bb.x, -bb.y); mx.fillStyle = '#fff'; for (const q of polys) { poly(mx, q); mx.fill(); }
      const md = mx.getImageData(0, 0, w, h).data, A = new Float32Array(N);
      for (let i = 0; i < N; i++) A[i] = md[i * 4 + 3] / 255;
      // openTop: the top edge is not an edge for the height field, so the cliff under the grass faces the viewer
      // (lit by the cylinder term) instead of bulging upward like a pillow
      let D;
      if (S.openTop) {
        const A2 = new Float32Array(A);
        for (let x = 0; x < w; x++) { let y0 = -1; for (let y = 0; y < h; y++) if (A[y * w + x] >= 0.5) { y0 = y; break; } if (y0 > 0) for (let y = 0; y < y0; y++) A2[y * w + x] = 1; }
        for (let x = 0; x < w; x++) A2[x] = 0; // keep a border so the transform is finite
        const D2 = edt(A2, w, h); D = new Float32Array(N); const D0 = edt(A, w, h);
        for (let i = 0; i < N; i++) D[i] = A[i] > 0 ? Math.max(D0[i], Math.min(D2[i], D0[i] + (S.openTopMax || 60))) : 0;
      } else D = edt(A, w, h);
      const r = rng(S.seed), nB = makeNoise(S.seed + 1), nV = makeNoise(S.seed + 2), nS = makeNoise(S.seed + 3), nX = makeNoise(S.seed + 4), nP = makeNoise(S.seed + 5);
      const P = S.pal;
      // facets
      const fc = S.facet || 0; let gw = 0, gh = 0, cells = null;
      if (fc) {
        gw = Math.ceil(w / fc) + 2; gh = Math.ceil(h / fc) + 2; cells = new Float32Array(gw * gh * 5);
        for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) {
          const k = (j * gw + i) * 5, a = r() * Math.PI * 2, m = (S.facetTilt || 0.4) * (0.35 + 0.65 * r());
          cells[k] = (i - 1 + 0.12 + 0.76 * r()) * fc; cells[k + 1] = (j - 1 + 0.12 + 0.76 * r()) * fc;
          cells[k + 2] = Math.cos(a) * m; cells[k + 3] = Math.sin(a) * m * 0.8 - 0.12 * m; cells[k + 4] = r() * 2 - 1;
        }
      }
      // distance below the top surface, per column (for moss and soil bands)
      const y0c = new Int32Array(w).fill(-1);
      for (let x = 0; x < w; x++) for (let y = 0; y < h; y++) if (A[y * w + x] >= 0.5) { y0c[x] = y; break; }
      const yTop = S.yTop != null ? S.yTop : bb.y, yBot = S.yBot != null ? S.yBot : bb.y + bb.h;
      // height: round bevel + dome from the distance transform, bumps, vertical flutes on the underside
      const R1 = S.bevel || 12, R2 = S.dome || Math.min(w, h) * 0.3, dk = S.domeK == null ? 0.5 : S.domeK;
      const bump = S.bump == null ? 6 : S.bump, bs = S.bumpScale || 40, FL = S.flutes || 0, nF = makeNoise(S.seed + 6);
      const H = new Float32Array(N);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const i = y * w + x, d = D[i]; if (d <= 0) continue;
        const t1 = Math.min(d, R1) / R1, t2 = Math.min(d, R2) / R2, X = x + bb.x, Y = y + bb.y;
        let hv = R1 * Math.sqrt(1 - (1 - t1) * (1 - t1)) + dk * R2 * Math.sqrt(1 - (1 - t2) * (1 - t2)) +
          bump * fbm(nB, X / bs, Y / bs, 4) * Math.min(1, d / R1);
        if (FL) hv += FL * fbm(nF, X / 15, Y / 240, 3) * smooth(0.15, 0.55, (Y - yTop) / Math.max(1, yBot - yTop)) * Math.min(1, d / R1);
        H[i] = hv;
      }
      const at = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : A[(y | 0) * w + (x | 0)];
      const out = new ImageData(w, h), od = out.data, em = new ImageData(w, h), ed = em.data;
      const riftW = S.riftW || (() => 0), rimW = S.rimW || 5, moss = S.moss || 0;
      const V = S.veins, ST = S.strata;
      let emis = false;
      for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
        const i = y * w + x, a = A[i]; if (a <= 0) continue;
        const X = x + bb.x, Y = y + bb.y, d = D[i];
        let nx = -(H[i + 1] - H[i - 1]) * 0.5, ny = -(H[i + w] - H[i - w]) * 0.5, nz = 1;
        let fsh = 0, edge = 1;
        if (cells) {
          const ci = Math.floor(x / fc) + 1, cj = Math.floor(y / fc) + 1; let d1 = 1e9, d2 = 1e9, k1 = 0;
          for (let jj = cj - 1; jj <= cj + 1; jj++) for (let ii = ci - 1; ii <= ci + 1; ii++) {
            if (ii < 0 || jj < 0 || ii >= gw || jj >= gh) continue;
            const k = (jj * gw + ii) * 5, dx = cells[k] - x, dy = cells[k + 1] - y, dd = dx * dx + dy * dy;
            if (dd < d1) { d2 = d1; d1 = dd; k1 = k; } else if (dd < d2) d2 = dd;
          }
          const wgt = Math.min(1, d / (R1 * 1.2));
          nx += cells[k1 + 2] * wgt; ny += cells[k1 + 3] * wgt; fsh = cells[k1 + 4];
          edge = smooth(0, S.crackW || 2.5, Math.sqrt(d2) - Math.sqrt(d1));
        }
        if (S.cyl) { const C = S.cyl, u = clamp(((x + bb.x) - C.cx) / C.hw, -1.2, 1.2); nx += C.k * u; ny += (C.down || 0) * smooth(0.1, 1, (y + bb.y - yTop) / Math.max(1, yBot - yTop)); }
        const nl = Math.hypot(nx, ny, nz); nx /= nl; ny /= nl; nz /= nl;
        const ndl = nx * LV[0] + ny * LV[1] + nz * LV[2];
        const lam = Math.max(0, ndl), amb = S.amb == null ? 0.12 : S.amb, lit = amb + (1 - amb) * Math.pow(lam, S.gamma || 1.35);
        let v = 1 + 0.16 * fbm(nV, X / 70, Y / 70, 3) + 0.06 * fsh;
        let line = 0;
        if (ST) {
          const sy = Y + ST.warp * fbm(nS, X / ST.wl, Y / ST.wl, 3) + ST.tilt * X; const ph = sy / ST.period, fr = ph - Math.floor(ph);
          v *= 1 + 0.12 * Math.sin(ph * 2.3 + 1.7 * Math.floor(ph));
          line = (1 - smooth(0, ST.lw, fr)) * ST.dark * smooth(4, 10, d);
        }
        const rw = riftW(X, Y), dTop = y0c[x] >= 0 ? y - y0c[x] : 1e9;
        let base = P.base;
        if (S.soil) { const sk = (1 - smooth(S.soil * 0.55, S.soil, dTop + S.soil * 0.35 * fbm(nX, X / 45, 1.7, 2))); if (sk > 0) base = mixc(base, P.soil, sk); }
        const dark = P.dark;
        let R = dark[0] + (base[0] * v - dark[0]) * lit, G = dark[1] + (base[1] * v - dark[1]) * lit, B = dark[2] + (base[2] * v - dark[2]) * lit;
        const key = Math.pow(lam, S.keyPow || 6) * (S.keyK == null ? 0.35 : S.keyK), kc = P.key || KEY;
        R += kc[0] * key; G += kc[1] * key; B += kc[2] * key;
        const bo = Math.max(0, ny) * (S.bounceK == null ? 0.25 : S.bounceK), bc = mixc(P.bounce || [120, 80, 220], CRIMSON, rw * 0.8);
        R += bc[0] * bo * 0.35; G += bc[1] * bo * 0.35; B += bc[2] * bo * 0.35;
        const yn = (Y - yTop) / Math.max(1, yBot - yTop), ao = 1 - (S.ao == null ? 0.45 : S.ao) * smooth(0.15, 1, yn);
        let k = ao * (1 - (S.crack == null ? 0.35 : S.crack) * (1 - edge)) * (1 - line);
        R *= k; G *= k; B *= k;
        if (moss && dTop < moss * 1.2) {
          const mk2 = a * (1 - smooth(moss * 0.45, moss * 1.2, dTop + 3 * nX(X / 25, 3.3)));
          if (mk2 > 0) {
            const mc2 = mixc(P.moss, P.mossRift || P.moss, rw), ml = 0.5 + 0.75 * lam;
            R += (mc2[0] * ml - R) * mk2; G += (mc2[1] * ml - G) * mk2; B += (mc2[2] * ml - B) * mk2;
          }
        }
        // rims: key light from the upper left; crimson from the right inside the rift biome
        const rk = a * (0.65 * (1 - at(x + L2[0] * rimW, y + L2[1] * rimW)) + 0.35 * (1 - at(x + L2[0] * rimW * 2.4, y + L2[1] * rimW * 2.4)));
        const rc = P.rim || LILAC, rs = (S.rimK == null ? 0.7 : S.rimK) * (1 - 0.45 * rw);
        R += rc[0] * rk * rs; G += rc[1] * rk * rs; B += rc[2] * rk * rs;
        if (rw > 0) {
          const rr = a * (1 - at(x + rimW * 1.2, y - rimW * 0.3)) * rw * (S.riftRimK == null ? 0.6 : S.riftRimK);
          R += CRIMSON[0] * rr; G += CRIMSON[1] * rr; B += CRIMSON[2] * rr;
        }
        const o4 = i * 4;
        od[o4] = clamp(R, 0, 255); od[o4 + 1] = clamp(G, 0, 255); od[o4 + 2] = clamp(B, 0, 255); od[o4 + 3] = a * 255;
        // glowing crystal seams
        if (V && d > 3) {
          const patch = smooth(V.th, V.th + 0.12, fbm(nP, X / V.patch, Y / V.patch, 2)) * (V.region ? V.region(X, Y, yn) : 1);
          if (patch > 0.001) {
            const f = Math.abs(fbm(nX, X / V.scale + 11.3, Y / V.scale - 4.1, 3));
            const ln = (1 - smooth(0, V.width, f)) * patch * smooth(3, 7, d);
            if (ln > 0.01) {
              const vc = V.color(X, Y);
              ed[o4] = vc[0]; ed[o4 + 1] = vc[1]; ed[o4 + 2] = vc[2]; ed[o4 + 3] = clamp(ln * V.alpha) * 255; emis = true;
              const dk2 = 1 - 0.5 * ln; od[o4] *= dk2; od[o4 + 1] *= dk2; od[o4 + 2] *= dk2;
            }
          }
        }
      }
      const c = mk(w, h); cx2(c).putImageData(out, 0, 0);
      let e = null;
      if (emis) {
        e = mk(w, h); const ex = cx2(e); ex.putImageData(em, 0, 0);
        const g = mk(w, h), gx = cx2(g); gx.filter = `blur(${V.glow || 5}px)`; gx.drawImage(e, 0, 0);
        ex.globalCompositeOperation = 'lighter'; ex.globalAlpha = V.glowK || 0.9; ex.drawImage(g, 0, 0); ex.drawImage(g, 0, 0);
      }
      return { c, e, x: bb.x, y: bb.y, w, h, A, D };
    }

    // ---------------------------------------------------------------- floating island outline
    // Flat, grassy top line; the underside is a union of hanging lobes (cones) with stalactite jag. An `anchor`
    // lobe ends in a flat notch exactly at (x, y): the lip a light-fall pours from.
    function island(o) {
      const n = makeNoise(o.seed), cx = (o.xL + o.xR) / 2, hw = (o.xR - o.xL) / 2;
      const tt = x => clamp((x - o.xL) / (2 * hw));
      const topY = x => {
        const e = Math.sin(Math.PI * tt(x));
        return o.top + (o.tilt || 0) * (x - cx) + (1 - Math.pow(e, 0.3)) * hw * (o.droop == null ? 0.1 : o.droop) +
          (o.rough == null ? 1 : o.rough) * (2.5 * n(x / 29, 1.3) + 0.045 * hw * fbm(n, x / (hw * 0.5), 7.7, 3) * e);
      };
      const jagA = o.jag == null ? 1 : o.jag;
      const underY = x => {
        const t0 = topY(x), e = Math.sin(Math.PI * tt(x));
        let y = t0 + o.thick * Math.pow(e, 0.6);
        for (const L of o.lobes) {
          const dd = Math.abs(x - L.x) / L.w; if (dd >= 1) continue;
          const base = t0 + o.thick * Math.pow(e, 0.6), depth = L.y - base;
          let ly = L.y - depth * Math.pow(dd, L.p || 1.25);
          const j = (0.06 * n(x / 13, L.y * 0.01) + 0.1 * Math.max(0, n(x / 41, 3.1 + L.x * 0.001)) + 0.05 * fbm(n, x / 90, 9.2, 2)) * depth * jagA * (1 - dd * 0.5);
          ly += j; y = Math.max(y, ly);
        }
        if (o.anchor) {
          const Q = o.anchor, d = Math.abs(x - Q.x);
          if (d <= Q.nh) y = Q.y;
          else {
            const base = t0 + o.thick * Math.pow(e, 0.6), ya = Q.y - (d - Q.nh) * (Q.slope || 1.4) + 0.05 * n(x / 11, 5.5) * (Q.y - base);
            if (ya > y) y = Math.min(ya, Q.y);
          }
        }
        return y;
      };
      const top = [], under = [];
      const step = o.step || 3;
      for (let x = o.xL; x <= o.xR + 0.01; x += step) top.push([x, topY(x)]);
      for (let x = o.xR; x >= o.xL - 0.01; x -= step) under.push([x, Math.max(topY(x) + 0.5, underY(x))]);
      if (o.anchor) { // make sure the notch reads flat and exactly at the anchor
        const Q = o.anchor; for (const p of under) if (Math.abs(p[0] - Q.x) <= Q.nh) p[1] = Q.y;
      }
      return { poly: [...top, ...under], top, under, topY, underY, cx, hw };
    }

    // ---------------------------------------------------------------- chunky floating rock outline
    function rock(o) {
      const r = rng(o.seed), n = makeNoise(o.seed + 9), K = o.corners || 9, pts = [];
      const a0 = r() * Math.PI * 2;
      const corners = [];
      for (let k = 0; k < K; k++) {
        const a = a0 + (k + (r() - 0.5) * 0.55) / K * Math.PI * 2;
        const c = Math.cos(a), s = Math.sin(a), e = o.boxy || 3.2;
        const rr = 1 / Math.pow(Math.pow(Math.abs(c), e) + Math.pow(Math.abs(s), e), 1 / e);
        let x = c * rr * o.w / 2, y = s * rr * o.h / 2;
        if (y > 0) x *= 1 - (o.taper || 0.4) * (y / (o.h / 2)); // narrower underside
        if (y < 0) y *= 1 - (o.flat || 0) * 0.45;              // flatter top
        const j = 1 + (r() - 0.5) * (o.jitter || 0.22);
        corners.push([o.cx + x * j, o.cy + y * j]);
      }
      if (o.spike) { // a hanging point under the rock
        let best = 0; corners.forEach((p, i) => { if (p[1] > corners[best][1]) best = i; });
        corners[best] = [corners[best][0] + o.spike[0], corners[best][1] + o.spike[1]];
      }
      for (let k = 0; k < K; k++) {
        const p = corners[k], q = corners[(k + 1) % K], len = Math.hypot(q[0] - p[0], q[1] - p[1]), m = Math.max(2, Math.ceil(len / 6));
        const nx = -(q[1] - p[1]) / len, ny = (q[0] - p[0]) / len;
        for (let i = 0; i < m; i++) {
          const t = i / m, x = p[0] + (q[0] - p[0]) * t, y = p[1] + (q[1] - p[1]) * t;
          const env = Math.sin(Math.PI * t);
          const dsp = env * (0.04 * len * fbm(n, x / 90, y / 90, 3) + 2.2 * n(x / 9, y / 9)) + (1 - env) * 1.2 * n(x / 7, y / 7);
          pts.push([x + nx * dsp, y + ny * dsp]);
        }
      }
      return pts;
    }

    // ---------------------------------------------------------------- details
    function crystal(b, e, x, y, h, w, ang, c, a = 1, glow = 0.5) {
      b.save(); b.translate(x, y); b.rotate(ang);
      const tip = -h, sh = h * 0.22, D = [16, 8, 30];
      const L = [[-w / 2, 0], [-w / 2, tip + sh], [0, tip], [0, 0]], R = [[0, 0], [0, tip], [w / 2, tip + sh], [w / 2, 0]];
      poly(b, L); let g = b.createLinearGradient(-w / 2, 0, 0, tip); g.addColorStop(0, col(mixc(c, D, 0.5), a)); g.addColorStop(1, col(mixc(c, [255, 255, 255], 0.5), a)); b.fillStyle = g; b.fill();
      poly(b, R); g = b.createLinearGradient(w / 2, 0, 0, tip); g.addColorStop(0, col(mixc(c, D, 0.82), a)); g.addColorStop(1, col(mixc(c, D, 0.25), a)); b.fillStyle = g; b.fill();
      b.strokeStyle = col(mixc(c, [255, 255, 255], 0.75), 0.85 * a); b.lineWidth = Math.max(0.8, w * 0.07); b.beginPath(); b.moveTo(0, -h * 0.05); b.lineTo(0, tip); b.stroke();
      b.restore();
      if (e && glow > 0) {
        e.save(); e.translate(x, y); e.rotate(ang); e.fillStyle = col(c, 0.35 * glow); poly(e, [...L, ...R]); e.fill(); e.restore();
        const tx = x + Math.sin(ang) * h * 0.85, ty = y - Math.cos(ang) * h * 0.85;
        blob(e, tx, ty, h * 0.55, c, 0.4 * glow); blob(e, tx, ty, h * 0.12, [255, 255, 255], 0.5 * glow);
      }
    }
    function crystals(b, e, x, y, n, size, c, seed, o = {}) {
      const r = rng(seed), items = [];
      for (let i = 0; i < n; i++) items.push([x + (r() - 0.5) * size * (o.spread || 1.3), y + r() * size * 0.08, size * (0.35 + r() * 0.7), (r() - 0.5) * (o.fan || 1) + (o.dir || 0)]);
      items.sort((p, q) => q[2] - p[2]);
      items.forEach(it => crystal(b, e, it[0], it[1], it[2], it[2] * (o.thin || 0.28), it[3], c, o.a == null ? 1 : o.a, o.glow == null ? 0.6 : o.glow));
    }
    // glowing crystal seams: branching crack paths (a random walk with angular turns) from a source point, clipped to
    // a polygon; a dark crack in the rock (base) with a bright core and glow (emissive)
    function seams(b, e, clip, sx, sy, o) {
      const r = rng(o.seed), paths = [];
      const walk = (x, y, ang, len, wd, depth) => {
        const pts = [[x, y]]; let L = 0;
        const jit = o.jit == null ? 0.55 : o.jit, br = o.branch == null ? 0.09 : o.branch;
        while (L < len) { const st = 8 + r() * 18; ang += (r() - 0.5) * jit; x += Math.cos(ang) * st; y += Math.sin(ang) * st; L += st; pts.push([x, y]);
          if (depth < 1 && r() < br) walk(x, y, ang + (r() < 0.5 ? -1 : 1) * (0.5 + r() * 0.5), len * (0.25 + r() * 0.3), wd * 0.6, depth + 1); }
        paths.push([pts, wd]);
      };
      for (let k = 0; k < o.n; k++) walk(sx + (r() - 0.5) * (o.spread || 10), sy, o.dir + (r() - 0.5) * (o.fan || 1.6), o.len * (0.5 + r() * 0.6), o.w || 2, 0);
      const draw = (x, style, wmul, a) => { x.save(); poly(x, clip); x.clip(); x.lineCap = 'round'; x.lineJoin = 'round';
        for (const [pts, wd] of paths) { x.strokeStyle = style; x.globalAlpha = a; x.lineWidth = wd * wmul; x.beginPath(); pts.forEach((p, i) => i ? x.lineTo(p[0], p[1]) : x.moveTo(p[0], p[1])); x.stroke(); }
        x.restore(); };
      draw(b, col([6, 3, 14]), 2.2, 0.8);
      e.save(); e.filter = `blur(${o.glow || 4}px)`; draw(e, col(o.color), 3, 0.5 * (o.a || 1)); e.restore();
      draw(e, col(mixc(o.color, [255, 255, 255], 0.3)), 1, 0.85 * (o.a || 1));
    }
    // tapered hanging root: dark, with a faint lit left edge; optional glowing bulb at the tip
    function root(b, e, x, y, len, wd, seed, o = {}) {
      const r = rng(seed), pts = [];
      const sway = (r() - 0.5) * len * 0.35, curl = (r() - 0.5) * len * 0.2;
      for (let i = 0; i <= 5; i++) { const t = i / 5; pts.push([x + sway * t * t + curl * Math.sin(t * 3.1), y + len * t, wd * (1 - t * 0.92)]); }
      const S = spline(pts, 10), O = outline(S);
      poly(b, O); b.fillStyle = col(o.color || [18, 10, 36], o.a == null ? 1 : o.a); b.fill();
      pathAlong(b, S, -0.7, 0, 0.85); b.strokeStyle = col(o.rim || [150, 120, 230], 0.35 * (o.a == null ? 1 : o.a)); b.lineWidth = Math.max(0.7, wd * 0.18); b.stroke();
      if (o.twigs) for (let k = 0; k < o.twigs; k++) {
        const p = at(S, 0.25 + r() * 0.5), l = len * (0.12 + r() * 0.2), s = r() < 0.5 ? -1 : 1;
        b.strokeStyle = col(o.color || [18, 10, 36], 0.9); b.lineWidth = Math.max(0.6, wd * 0.25);
        b.beginPath(); b.moveTo(p.x, p.y); b.quadraticCurveTo(p.x + s * l * 0.5, p.y + l * 0.2, p.x + s * l * 0.6, p.y + l * 0.9); b.stroke();
      }
      if (o.bulb && e) { const p = S[S.length - 1]; blob(e, p.x, p.y + 2, wd * 3.2, o.bulb, 0.55); blob(e, p.x, p.y + 2, wd * 0.9, [255, 255, 255], 0.8); }
      return S;
    }
    // hanging vine with small leaves
    function vine(b, e, x, y, len, seed, o = {}) {
      const r = rng(seed), pts = [], sw = (r() - 0.5) * len * 0.25;
      for (let i = 0; i <= 6; i++) { const t = i / 6; pts.push([x + sw * Math.sin(t * 2.2) + (r() - 0.5) * 4, y + len * t, (o.w || 2.4) * (1 - t * 0.6)]); }
      const S = spline(pts, 12); pathAlong(b, S, 0); b.strokeStyle = col(o.color || [24, 14, 46], 0.95); b.lineWidth = o.w || 2.4; b.stroke();
      const lc = o.leaf || [40, 24, 76], lr = o.leafRim || [170, 140, 255];
      for (let t = 0.08; t < 1; t += 0.05 + r() * 0.06) {
        const p = at(S, t), s = r() < 0.5 ? -1 : 1, l = (o.leafLen || 12) * (0.6 + r() * 0.6) * (1 - t * 0.3);
        b.fillStyle = col(mixc(lc, lr, r() * 0.25)); leaf(b, p.x, p.y, l, l * 0.38, s < 0 ? Math.PI * 0.75 + (r() - 0.5) * 0.5 : Math.PI * 0.25 + (r() - 0.5) * 0.5);
      }
      if (o.bud && e) { const p = S[S.length - 1]; blob(e, p.x, p.y + 3, 9, o.bud, 0.7); blob(e, p.x, p.y + 3, 2.5, [255, 255, 255], 0.9); }
    }
    // a small tree like the Milestone Tree: curved trunk, a canopy of round leaf masses rim-lit from the upper left,
    // a few glowing leaves. kind 'dead': bare, thorny branches.
    function tree(b, e, x, y, h, seed, o = {}) {
      const r = rng(seed), bark = o.bark || [26, 15, 50], lf = o.leaf || [44, 26, 88], rim = o.rim || [190, 160, 255];
      const lean = (r() - 0.5) * 0.3, tw = Math.max(1.6, h * 0.075);
      const tp = [[x, y + 3, tw * 1.3], [x + lean * h * 0.15, y - h * 0.3, tw * 0.85], [x + lean * h * 0.45 + (r() - 0.5) * h * 0.08, y - h * 0.62, tw * 0.5]];
      const S = spline(tp, 10);
      poly(b, outline(S)); b.fillStyle = col(bark); b.fill();
      pathAlong(b, S, -0.75, 0, 1); b.strokeStyle = col(rim, 0.35); b.lineWidth = Math.max(0.6, tw * 0.22); b.stroke();
      const top = S[S.length - 1];
      const branch = (x0, y0, x1, y1, wd) => { b.strokeStyle = col(bark); b.lineWidth = wd; b.lineCap = 'round'; b.beginPath(); b.moveTo(x0, y0); b.quadraticCurveTo((x0 + x1) / 2 + (r() - 0.5) * h * 0.1, (y0 + y1) / 2 - h * 0.05, x1, y1); b.stroke(); };
      if (o.kind === 'dead') {
        for (let k = 0; k < 6; k++) {
          const t = 0.45 + r() * 0.5, p = at(S, t), s2 = k % 2 ? 1 : -1, l = h * (0.18 + r() * 0.22);
          const ex = p.x + s2 * l * (0.6 + r() * 0.4), ey = p.y - l * (0.5 + r() * 0.6);
          branch(p.x, p.y, ex, ey, Math.max(0.7, tw * 0.45));
          branch(ex, ey, ex + s2 * l * 0.3, ey - l * 0.35, Math.max(0.5, tw * 0.25));
          if (e && o.glow && r() < 0.6) blob(e, ex, ey, 2 + h * 0.03, o.glow[0], 0.8);
        }
        return;
      }
      // canopy: a lumpy dome of leaf masses (like the Milestone Tree's clusters), wider than tall
      const blobs = [], nb = 5 + Math.floor(r() * 3), ccx = top.x, ccy = top.y - h * 0.06;
      for (let k = 0; k < nb; k++) {
        const a = -Math.PI * (0.06 + 0.88 * k / (nb - 1)) + (r() - 0.5) * 0.25, rr = h * (0.12 + r() * 0.08);
        const bx = ccx + Math.cos(a) * h * 0.3, by = ccy + Math.sin(a) * h * 0.17 + h * 0.04;
        if (k % 2 === 0) branch(top.x, top.y + h * 0.12, bx, by + rr * 0.3, Math.max(0.8, tw * 0.4));
        blobs.push([bx, by, rr]);
      }
      blobs.push([ccx - h * 0.1, ccy - h * 0.02, h * 0.19], [ccx + h * 0.1, ccy + h * 0.01, h * 0.18], [ccx, ccy - h * 0.1, h * 0.17]);
      const off = [-L2[0], -L2[1]];
      // lit crescent: rim-coloured discs under dark discs shifted away from the light
      for (const [bx, by, rr] of blobs) { b.fillStyle = col(mixc(lf, rim, 0.55)); b.beginPath(); b.arc(bx, by, rr, 0, 7); b.fill(); }
      for (const [bx, by, rr] of blobs) { b.fillStyle = col(lf); b.beginPath(); b.arc(bx + off[0] * rr * 0.2, by + off[1] * rr * 0.2, rr * 0.97, 0, 7); b.fill(); }
      for (const [bx, by, rr] of blobs) { const g = b.createRadialGradient(bx + off[0] * rr * 0.4, by + off[1] * rr * 0.4, rr * 0.1, bx, by, rr * 1.1); g.addColorStop(0, col([6, 3, 14], 0.45)); g.addColorStop(1, col([6, 3, 14], 0)); b.fillStyle = g; b.beginPath(); b.arc(bx, by, rr, 0, 7); b.fill(); }
      // leaves breaking the outline
      for (const [bx, by, rr] of blobs) {
        const nl = Math.round(rr * 1.4 + 6);
        for (let i = 0; i < nl; i++) {
          const a = r() * Math.PI * 2, px = bx + Math.cos(a) * rr * (0.85 + r() * 0.25), py = by + Math.sin(a) * rr * (0.85 + r() * 0.25);
          const litk = clamp(-(Math.cos(a) * L2[0] + Math.sin(a) * L2[1]) * -1);
          b.fillStyle = col(mixc(lf, rim, clamp(0.6 * (Math.cos(a) * L2[0] + Math.sin(a) * L2[1]))), 0.95);
          leaf(b, px, py, rr * (0.3 + r() * 0.2), rr * 0.13, a + (r() - 0.5) * 0.8);
        }
        if (e && o.glow) for (let i = 0; i < (o.glowN == null ? 2 : o.glowN); i++) { const a = r() * 7, d = r() * rr * 0.9; const gc = o.glow[Math.floor(r() * o.glow.length)]; blob(e, bx + Math.cos(a) * d, by + Math.sin(a) * d, rr * 0.22 + 1.5, gc, 0.55); blob(e, bx + Math.cos(a) * d, by + Math.sin(a) * d, 1.2, [255, 255, 255], 0.7); }
      }
    }
    function grass(b, e, top, seed, o = {}) {
      const r = rng(seed), gc = o.color || [60, 38, 112], mc = o.moss || [150, 120, 255];
      const n = Math.floor(top.length * (o.density || 2));
      for (let i = 0; i < n; i++) {
        const p = top[1 + Math.floor(r() * (top.length - 2))], hh = (o.h || 10) * (0.3 + Math.pow(r(), 2) * 1.2), lean = (r() - 0.5) * hh * 0.6;
        b.strokeStyle = col(mixc(gc, mc, r() * 0.6), 0.9); b.lineWidth = o.w || 1.2;
        b.beginPath(); b.moveTo(p[0], p[1] + 2); b.quadraticCurveTo(p[0] + lean * 0.3, p[1] - hh * 0.6, p[0] + lean, p[1] - hh); b.stroke();
      }
      if (e && o.flowers) for (let i = 0; i < o.flowers; i++) {
        const p = top[2 + Math.floor(r() * (top.length - 4))], c = o.flowerCols[Math.floor(r() * o.flowerCols.length)], hh = 3 + r() * (o.h || 10);
        b.strokeStyle = col([50, 30, 96], 0.9); b.lineWidth = 1; b.beginPath(); b.moveTo(p[0], p[1] + 1); b.lineTo(p[0] + (r() - 0.5) * 4, p[1] - hh); b.stroke();
        blob(e, p[0], p[1] - hh, 4 + r() * 3, c, 0.85); blob(e, p[0], p[1] - hh, 1.4, [255, 255, 255], 0.9);
      }
      if (e && o.mossLine) { // soft glowing moss line along the lit top edge
        e.save(); e.lineCap = 'round';
        for (let i = 0; i < top.length - 1; i++) {
          const k = 0.5 + 0.5 * Math.sin(i * 0.37 + seed) * Math.sin(i * 0.11 + seed * 2);
          e.strokeStyle = col(o.mossLine, (0.08 + 0.3 * k * k) * (o.mossA || 1)); e.lineWidth = 3 + 3 * k; e.beginPath(); e.moveTo(top[i][0], top[i][1] + 1); e.lineTo(top[i + 1][0], top[i + 1][1] + 1); e.stroke();
        }
        e.restore();
      }
    }

    // ---------------------------------------------------------------- light-fall
    // A luminous waterfall of light: a soft widening body, many swaying strands whose brightness clumps along their
    // length (the shimmer), spray droplets off the edges, a halo, a bright lip, and a wide flat cloud of mist where it
    // dissolves (mist goes to the base canvas, the light scattered in it to emissive). Never a straight pole.
    function lightfall(b, e, ax, ay, s, len, c, seed, o = {}) {
      const r = rng(seed), n = makeNoise(seed);
      const w = s * 8, hgt = len + s * 3, x0 = ax - w / 2, y0 = ay - s;
      const L = mk(w, hgt), lx = cx2(L); lx.translate(-x0, -y0);
      const w0 = s * 0.55, w1 = s * (o.spread || 2.4), NS = o.strands || 40, fade = o.fade || 0.92;
      const edgeX = (t, side) => ax + side * 0.5 * (w0 + (w1 - w0) * Math.pow(t, 0.75)) + s * 0.18 * n(t * 2.5, side * 3.1) * t;
      // body
      { lx.beginPath(); for (let i = 0; i <= 30; i++) { const t = i / 30; lx.lineTo(edgeX(t, -1), ay + t * len * fade); } for (let i = 30; i >= 0; i--) { const t = i / 30; lx.lineTo(edgeX(t, 1), ay + t * len * fade); } lx.closePath();
        const g = lx.createLinearGradient(0, ay, 0, ay + len * fade); g.addColorStop(0, col(c, 0.3 * (o.bodyA || 1))); g.addColorStop(0.2, col(c, 0.13 * (o.bodyA || 1))); g.addColorStop(0.7, col(c, 0.05 * (o.bodyA || 1))); g.addColorStop(1, col(c, 0)); lx.fillStyle = g; lx.fill(); }
      lx.lineCap = 'round';
      for (let k = 0; k < NS; k++) {
        const u = ((k + 0.5 + (r() - 0.5) * 0.9) / NS - 0.5) * 2, lk = (0.5 + r() * 0.5) * fade, ph = r(), fq = 0.5 + r() * 1.2, amp = s * (0.06 + r() * 0.16);
        const core = 1 - Math.abs(u) * 0.7, a0 = (0.2 + 0.55 * r()) * core;
        const pts = [];
        for (let i = 0; i <= 28; i++) {
          const t = i / 28, yy = ay + t * len * lk;
          const half = 0.5 * (w0 + (w1 - w0) * Math.pow(t * lk / fade, 0.75));
          pts.push([ax + u * half + amp * Math.pow(t, 1.3) * Math.sin(Math.PI * 2 * (t * fq + ph)), yy]);
        }
        const g = lx.createLinearGradient(0, ay, 0, ay + len * lk);
        for (let q = 0; q <= 12; q++) { const t = q / 12; const br = Math.pow(clamp(0.5 + 0.6 * n(t * 5.3 + k * 0.37, k * 1.7 + 3)), 1.5); g.addColorStop(t, col(mixc(c, [255, 255, 255], 0.45 * (1 - t)), a0 * Math.pow(1 - t, 0.8) * br)); }
        lx.strokeStyle = g; lx.lineWidth = s * (0.025 + r() * 0.05) * (k % 4 === 0 ? 1.8 : 1);
        lx.beginPath(); pts.forEach((p, i) => i ? lx.lineTo(p[0], p[1]) : lx.moveTo(p[0], p[1])); lx.stroke();
      }
      // spray droplets off the edges
      for (let k = 0; k < (o.drops || 40); k++) {
        const t = 0.15 + Math.pow(r(), 0.7) * 0.8, side = r() < 0.5 ? -1 : 1, xx = edgeX(t, side) + side * s * r() * 0.5 * t, yy = ay + t * len * fade;
        lx.fillStyle = col(mixc(c, [255, 255, 255], 0.4), (0.25 + 0.5 * r()) * (1 - t)); lx.beginPath(); lx.ellipse(xx, yy, 0.6 + r() * 1.2, 1.2 + r() * 3, 0, 0, 7); lx.fill();
      }
      const halo = mk(w, hgt), hx = cx2(halo); hx.filter = `blur(${s * 0.5}px)`; hx.drawImage(L, 0, 0);
      e.save(); e.globalCompositeOperation = 'lighter';
      e.globalAlpha = o.haloK || 0.85; e.drawImage(halo, x0, y0);
      e.globalAlpha = o.bodyK || 0.95; e.filter = `blur(${Math.max(0.5, s * 0.01)}px)`; e.drawImage(L, x0, y0); e.filter = 'none';
      e.restore();
      // the lip: a glowing slit in the rock where the light spills out
      e.save(); e.translate(ax, ay); e.scale(1, 0.28); blob(e, 0, 0, w0 * 0.9, c, 0.8); blob(e, 0, 0, w0 * 0.45, [255, 255, 255], 0.85); e.restore();
      blob(e, ax, ay + s * 0.3, s * 1.1, c, 0.25);
      // mist: a wide, flat, torn cloud where the fall dissolves
      const my = ay + len * (o.mistAt || 0.9), mw = s * (o.mistW || 5), mh = s * 0.9;
      const M = mk(mw * 2.6, mh * 5), mx = cx2(M), mx0 = ax - mw * 1.3, my0 = my - mh * 2.5;
      mx.translate(-mx0, -my0);
      for (let i = 0; i < 34; i++) {
        const u = (r() - 0.5) * 2, px = ax + u * mw * (0.35 + 0.65 * r()), py = my + (r() - 0.5) * mh * 0.9 - (1 - Math.abs(u)) * mh * 0.5, rr = mh * (0.35 + r() * 0.6) * (1.1 - Math.abs(u) * 0.5);
        mx.save(); mx.translate(px, py); mx.scale(2.4, 1); blob(mx, 0, 0, rr, o.mist || [200, 185, 255], (0.07 + r() * 0.08) * (o.mistK || 1)); mx.restore();
      }
      b.save(); b.filter = `blur(${s * 0.1}px)`; b.drawImage(M, mx0, my0); b.restore();
      e.save(); e.globalAlpha = 0.45; e.filter = `blur(${s * 0.25}px)`; e.drawImage(M, mx0, my0); e.restore();
    }

    // ---------------------------------------------------------------- cloud banks
    // Billowy banks with a defined top edge, lit from the key light direction (density sampled toward the light),
    // denser and darker below. Rendered at 1/4 resolution and blurred up. `cap(X, Y)` limits the alpha.
    function cloudBank(b, o) {
      const q = o.q || 4, w = Math.ceil(o.w / q), h = Math.ceil(o.h / q), c = mk(w, h), x = cx2(c, true), im = x.createImageData(w, h), d = im.data;
      const n = makeNoise(o.seed), n2 = makeNoise(o.seed + 7), n3 = makeNoise(o.seed + 3);
      const dens = (X, Y, B) => {
        const ytop = B.y - B.h * 0.5 + B.wob * fbm(n2, X / B.sx * 0.6, B.y * 0.003, 3);
        const prof = smooth(ytop - B.h * 0.1, ytop + B.h * 0.35, Y) * (1 - smooth(B.y + B.h * (B.fall == null ? 0.3 : B.fall), B.y + B.h * 1.1, Y));
        if (prof <= 0) return 0;
        const qx = fbm(n3, X / B.sx, Y / B.sy, 2);
        const t = fbm(n, X / B.sx + 0.9 * qx + B.y * 0.013, Y / B.sy + 0.9 * qx, 4);
        return prof * (0.55 + 0.9 * t);
      };
      const dl = o.dl || 14;
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const X = i * q, Y = j * q;
        let a = 0, litv = 0;
        for (const B of o.bands) {
          if (Y < B.y - B.h * 0.5 - B.wob - 20 || Y > B.y + B.h * 1.2) continue;
          const dd = dens(X, Y, B);
          const av = smooth(B.th, B.th + 0.35, dd) * B.a;
          if (av <= a * 0.5) continue;
          const dt = dens(X + L2[0] * dl, Y + L2[1] * dl, B);
          const lv = clamp(0.4 + (dd - dt) * (o.litK || 4));
          if (av > a) { litv = lv; } a = Math.max(a, av);
        }
        if (o.cap) a = Math.min(a, o.cap(X, Y));
        const cc = mixc(o.shade, o.lit, litv), k = (j * w + i) * 4;
        d[k] = cc[0]; d[k + 1] = cc[1]; d[k + 2] = cc[2]; d[k + 3] = a * 255;
      }
      x.putImageData(im, 0, 0);
      b.save(); b.imageSmoothingQuality = 'high'; b.filter = `blur(${o.blur || 5}px)`; b.drawImage(c, 0, 0, w * q, h * q); b.restore();
    }

    // ---------------------------------------------------------------- mist band (low-res noise, stretched)
    function mistBand(b, o) {
      const q = 4, w = Math.ceil(o.w / q), h = Math.ceil(o.h / q), c = mk(w, h), x = cx2(c, true), im = x.createImageData(w, h), d = im.data;
      const n = makeNoise(o.seed), n2 = makeNoise(o.seed + 7);
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const X = i * q, Y = j * q;
        let a = 0;
        for (const B of o.bands) {
          const wob = B.wob * fbm(n2, X / 900, B.y * 0.01, 2);
          const v = Math.exp(-Math.pow((Y - B.y - wob) / (B.h * 0.5), 2));
          if (v < 0.01) continue;
          const t = fbm(n, X / B.sx + B.y * 0.013, (Y - wob) / B.sy, 4);
          a = Math.max(a, v * smooth(B.th, B.th + 0.45, t + 0.25) * B.a);
        }
        if (o.cap) a = Math.min(a, o.cap(X, Y));
        const k = (j * w + i) * 4; d[k] = o.color[0]; d[k + 1] = o.color[1]; d[k + 2] = o.color[2]; d[k + 3] = a * 255;
      }
      x.putImageData(im, 0, 0);
      b.save(); b.imageSmoothingQuality = 'high'; b.filter = `blur(${o.blur || 6}px)`; b.drawImage(c, 0, 0, w * q, h * q); b.restore();
    }

    // ---------------------------------------------------------------- the atmosphere pass (REALM.md section 4)
    // base: colour art; emis: light that may exceed maxLuma (up to emissiveMax). Both get the same colour recipe;
    // the light is then screened over the base (premultiplied), the luma limit follows the local emissive share,
    // and the whole layer gets a premultiplied gaussian blur of `blur` local px.
    function atmosphere(base, emis, T) {
      const w = base.width, h = base.height, A = T.atm, bx = cx2(base, true);
      const bI = bx.getImageData(0, 0, w, h), bd = bI.data, eI = emis ? cx2(emis, true).getImageData(0, 0, w, h) : null, edd = eI ? eI.data : null;
      const hzR = new Float32Array(w), hzG = new Float32Array(w), hzB = new Float32Array(w), hzL = new Float32Array(w);
      for (let x = 0; x < w; x++) {
        const t = smooth(T.splitX - T.fade, T.splitX + T.fade, x), c = mixc(A.hazeColor, A.hazeRift, t);
        hzR[x] = c[0] / 255; hzG[x] = c[1] / 255; hzB[x] = c[2] / 255; hzL[x] = luma(hzR[x], hzG[x], hzB[x]);
      }
      const sat = A.saturation, con = A.contrast, maxL = A.maxLuma, emax = A.emissiveMax;
      const tr = (r, g, b, x, k, out) => {
        const L = luma(r, g, b); let r1 = L + (r - L) * sat, g1 = L + (g - L) * sat, b1 = L + (b - L) * sat;
        const lh = hzL[x]; r1 = lh + (r1 - lh) * con; g1 = lh + (g1 - lh) * con; b1 = lh + (b1 - lh) * con;
        out[0] = r1 + (hzR[x] - r1) * k; out[1] = g1 + (hzG[x] - g1) * k; out[2] = b1 + (hzB[x] - b1) * k;
      };
      const c1 = [0, 0, 0], c2 = [0, 0, 0];
      for (let y = 0; y < h; y++) {
        const k = A.haze + A.hazeBottom * smooth(0.35, 1, y / h);
        for (let x = 0; x < w; x++) {
          const i = (y * w + x) * 4, ba = bd[i + 3] / 255, ea = edd ? edd[i + 3] / 255 : 0;
          if (ba <= 0 && ea <= 0) continue;
          let pr = 0, pg = 0, pb = 0;
          if (ba > 0) {
            tr(bd[i] / 255, bd[i + 1] / 255, bd[i + 2] / 255, x, k, c1);
            const L = luma(c1[0], c1[1], c1[2]); if (L > maxL) { const s = maxL / L; c1[0] *= s; c1[1] *= s; c1[2] *= s; }
            pr = c1[0] * ba; pg = c1[1] * ba; pb = c1[2] * ba;
          }
          let oa = ba;
          if (ea > 0) {
            tr(edd[i] / 255, edd[i + 1] / 255, edd[i + 2] / 255, x, k * (T.emisHaze == null ? 1 : T.emisHaze), c2);
            const L = luma(c2[0], c2[1], c2[2]); if (L > emax) { const s = emax / L; c2[0] *= s; c2[1] *= s; c2[2] *= s; }
            const er = clamp(c2[0]) * ea, eg = clamp(c2[1]) * ea, eb = clamp(c2[2]) * ea;
            pr = pr + er - pr * er; pg = pg + eg - pg * eg; pb = pb + eb - pb * eb; oa = ba + ea - ba * ea;
          }
          if (oa <= 0) continue;
          let r = pr / oa, g = pg / oa, b = pb / oa;
          const lim = maxL + (emax - maxL) * clamp(ea * 2.2 / Math.max(oa, 1e-3)), L = luma(r, g, b);
          if (L > lim) { const s = lim / L; r *= s; g *= s; b *= s; }
          bd[i] = clamp(r) * 255; bd[i + 1] = clamp(g) * 255; bd[i + 2] = clamp(b) * 255; bd[i + 3] = clamp(oa) * 255;
        }
      }
      bx.putImageData(bI, 0, 0);
      if (!A.blur) return base;
      const out = mk(w, h), ox = cx2(out); ox.filter = `blur(${A.blur}px)`; ox.drawImage(base, 0, 0);
      return out;
    }

    function downsample(src, w, h) {
      let c = src;
      while (c.width / 2 >= w * 1.02) { const n2 = mk(Math.round(c.width / 2), Math.round(c.height / 2)), x = cx2(n2); x.imageSmoothingQuality = 'high'; x.drawImage(c, 0, 0, n2.width, n2.height); c = n2; }
      if (c.width === w && c.height === h) return c;
      const o = mk(w, h), x = cx2(o); x.imageSmoothingQuality = 'high'; x.drawImage(c, 0, 0, w, h); return o;
    }

    // max alpha of a canvas inside a set of keep-clear ellipses ([name, cx, cy, rx, ry], layer-local px)
    function zoneMax(c, zones, grow = 0) {
      const w = c.width, h = c.height, d = cx2(c, true).getImageData(0, 0, w, h).data, out = {};
      for (const z of zones) {
        let m = 0;
        const x0 = Math.max(0, Math.floor(z[1] - z[3] - grow)), x1 = Math.min(w - 1, Math.ceil(z[1] + z[3] + grow));
        const y0 = Math.max(0, Math.floor(z[2] - z[4] - grow)), y1 = Math.min(h - 1, Math.ceil(z[2] + z[4] + grow));
        for (let y = y0; y <= y1; y += 2) for (let x = x0; x <= x1; x += 2) if (inEllipse(x, y, z, grow)) m = Math.max(m, d[(y * w + x) * 4 + 3]);
        out[z[0]] = +(m / 255).toFixed(3);
      }
      return out;
    }

    return { LV, L2, KEY, LILAC, CRIMSON, mk, cx2, luma, col, mixc, inEllipse, edt, bbox, mass, island, rock, crystal, crystals, seams, root, vine, tree, grass, lightfall, mistBand, cloudBank, atmosphere, downsample, zoneMax };
  })();
  // ================================================================ ISLAND KIT (end)

  // ---- contract snapshot (realm.json layers[far]); repaint if `node camera.js --build` changes it
  const CFG = {
    size: [3008, 1836], res: 0.5, splitX: 1636.5, fade: 713,
    atm: { hazeColor: [66, 50, 138], hazeRift: [110, 34, 72], haze: 0.5, hazeBottom: 0.2, saturation: 0.7, contrast: 0.55, blur: 2.5, maxLuma: 0.5, emissiveMax: 0.65 },
    soft: [['m', 1399, 1079, 395, 324], ['mm', 1319, 1094, 395, 324], ['em', 1479, 1094, 395, 324], ['p', 1399, 999, 395, 324], ['pe', 1284, 929, 395, 324], ['sp', 1356.5, 916.5, 395, 324], ['pb', 1441.5, 916.5, 395, 324], ['pp', 1514, 929, 395, 324], ['se', 1311.5, 849, 395, 324], ['hp', 1399, 836.5, 395, 324], ['ep', 1486.5, 849, 395, 324], ['hb', 1319, 769, 395, 324], ['ap', 1399, 756.5, 395, 324], ['mp', 1479, 769, 395, 324], ['t', 1399, 684, 395, 324], ['pm', 1811.5, 994, 395, 324], ['pep', 1721.5, 899, 395, 324], ['cr', 1901.5, 904, 395, 324], ['cm', 1946.5, 836.5, 395, 324], ['ex', 1811.5, 799, 395, 324], ['ach', 1154, 754, 395, 324]],
    rift: [1811.5, 968], // landmarks.rift: the local point behind the rift
  };
  const [W, H] = CFG.size;
  const K = KIT, { mk, cx2, col, mixc } = K;
  const riftW = x => smooth(CFG.splitX - CFG.fade, CFG.splitX + CFG.fade, x);
  const HAZE = x => mixc(CFG.atm.hazeColor, CFG.atm.hazeRift, riftW(x));

  // islands: centre x, top y, width (<= 420), depth, extra haze (sub-depth), shape and details.
  // shapes vary the silhouette: cone (one main hanging cone), twin (two cones), mesa (wide, shallow, many drips),
  // spire (a rock column rising from the top), tilt (tipped island), arch (a hole through it)
  const ISLES = [
    { x: 500, top: 450, w: 300, d: 200, hz: 0.1, seed: 201, shape: 'twin', trees: [[-40, 46], [50, 30]], fall: 0.14, sats: 2 },
    { x: 330, top: 985, w: 360, d: 250, hz: 0.0, seed: 202, shape: 'spire', fall: -0.22, crystals: [179, 92, 255], sats: 3 },
    { x: 640, top: 1455, w: 240, d: 120, hz: 0.18, seed: 203, shape: 'mesa', trees: [[20, 34]] },
    { x: 1180, top: 238, w: 210, d: 150, hz: 0.3, seed: 204, shape: 'tilt', crystals: [95, 224, 255], sats: 1 },
    { x: 1720, top: 282, w: 170, d: 130, hz: 0.38, seed: 205, shape: 'cone', trees: [[0, 26]] },
    { x: 2560, top: 800, w: 300, d: 210, hz: 0.08, seed: 206, shape: 'twin', crystals: [255, 46, 99], dead: true, fall: 0.2, sats: 2 },
    { x: 2500, top: 1405, w: 400, d: 170, hz: 0.05, seed: 207, shape: 'mesa', crystals: [232, 70, 190], spires: 3, dead: true, sats: 2 },
    { x: 1450, top: 1540, w: 280, d: 170, hz: 0.2, seed: 208, shape: 'cone', trees: [[-50, 36], [30, 44]], fall: 0.25 },
    { x: 2060, top: 1520, w: 200, d: 150, hz: 0.28, seed: 209, shape: 'tilt', crystals: [255, 90, 150] },
    { x: 930, top: 1540, w: 230, d: 160, hz: 0.25, seed: 210, shape: 'arch' },
  ];
  const SPECKS = [[990, 370, 70], [2250, 380, 60], [230, 1330, 90], [2760, 1060, 80], [1700, 1620, 60], [2840, 300, 56], [150, 560, 64], [2900, 1560, 76], [720, 700, 44], [2700, 640, 40]];

  function subCanvas(x0, y0, w, h) { const c = mk(w, h), x = cx2(c); x.translate(-x0, -y0); return { c, x, x0, y0 }; }
  function commit(dst, sub, hz, hc) {
    if (hz > 0) { const x = sub.x; x.save(); x.setTransform(1, 0, 0, 1, 0, 0); x.globalCompositeOperation = 'source-atop'; x.fillStyle = col(hc, hz); x.fillRect(0, 0, sub.c.width, sub.c.height); x.restore(); }
    dst.drawImage(sub.c, sub.x0, sub.y0);
  }

  function paintIsle(I, b, e) {
    const r = rng(I.seed * 5 + 1), rw = riftW(I.x), hw = I.w / 2;
    const sh = I.shape || 'cone';
    // bellies: rounded (p < 1) main lobes ending in narrow stalactite tips (p > 1)
    const belly = (x, d, w) => [{ x, y: I.top + d * 0.78, w, p: 0.62 }, { x: x + (r() - 0.5) * w * 0.3, y: I.top + d, w: w * 0.28, p: 1.5 }];
    let lobes, tilt = (r() - 0.5) * 0.06, thick = I.d * 0.22;
    if (sh === 'twin') lobes = [...belly(I.x - hw * 0.36, I.d, hw * 0.55), ...belly(I.x + hw * 0.4, I.d * 0.72, hw * 0.5)];
    else if (sh === 'mesa') { lobes = []; for (let k = 0; k < 5; k++) lobes.push(...belly(I.x - hw * 0.72 + k * hw * 0.36 + (r() - 0.5) * 10, I.d * (0.5 + r() * 0.5), hw * (0.22 + r() * 0.08))); thick = I.d * 0.35; }
    else if (sh === 'tilt') { lobes = [...belly(I.x + hw * 0.12, I.d, hw * 0.78)]; tilt = r() < 0.5 ? 0.2 : -0.2; }
    else lobes = [...belly(I.x + (r() - 0.5) * hw * 0.2, I.d, hw * 0.7), ...belly(I.x - hw * 0.55, I.d * 0.55, hw * 0.3), ...belly(I.x + hw * 0.58, I.d * 0.6, hw * 0.28)];
    const S = K.island({ xL: I.x - hw, xR: I.x + hw, top: I.top, tilt, thick, seed: I.seed, lobes, droop: 0.1, jag: 0.8, step: 2 });
    const yTop = Math.min(...S.top.map(p => p[1])), yBot = Math.max(...S.under.map(p => p[1]));
    const x0 = Math.floor(I.x - hw - 140), y0 = Math.floor(I.top - 160), sb = subCanvas(x0, y0, I.w + 280, I.d + 700), se = subCanvas(x0, y0, I.w + 280, I.d + 700);
    const polys = [S.poly];
    if (sh === 'spire') { // a cluster of jagged rock pinnacles rising from the island
      for (let k = 0; k < 3; k++) {
        const bx = I.x + hw * (0.05 + k * 0.22) - hw * 0.2, by = S.topY(bx) + 8, ht = I.d * (0.75 - k * 0.2) * (0.8 + r() * 0.3), bw = hw * (0.2 - k * 0.03);
        polys.push([[bx - bw, by], [bx - bw * 0.7, by - ht * 0.35], [bx - bw * 0.5, by - ht * 0.42], [bx - bw * 0.25, by - ht * 0.8], [bx, by - ht], [bx + bw * 0.2, by - ht * 0.72], [bx + bw * 0.55, by - ht * 0.5], [bx + bw * 0.6, by - ht * 0.3], [bx + bw, by]]);
      }
    }
    const M = K.mass({ polys, poly: S.poly, seed: I.seed, pad: 8, openTop: true, openTopMax: 40, bevel: 5, dome: 50, domeK: 0.7, bump: 2, bumpScale: 20, flutes: 5, crack: 0,
      cyl: { cx: I.x, hw, k: 0.5, down: 0.5 }, strata: { period: 14, lw: 0.1, dark: 0.25, warp: 5, wl: 70, tilt: 0.03 },
      pal: { dark: [14, 8, 34], base: [70, 50, 140], soil: [60, 38, 96], moss: [120, 100, 220], mossRift: [190, 80, 150], rim: [255, 214, 150], bounce: [120, 90, 230] },
      soil: 12, moss: 6, amb: 0.12, gamma: 1.3, rimW: 2.5, rimK: 0.55, keyK: 0.35, bounceK: 0.4, ao: 0.45, yTop, yBot, riftW: X => riftW(X), riftRimK: 0.8 });
    sb.x.drawImage(M.c, M.x, M.y);
    if (I.arch) { // a hole through the island: an arch silhouette
      sb.x.save(); sb.x.globalCompositeOperation = 'destination-out'; sb.x.beginPath(); sb.x.ellipse(I.x + hw * 0.1, I.top + I.d * 0.55, hw * 0.28, I.d * 0.3, 0, 0, 7); sb.x.fill(); sb.x.restore();
      sb.x.strokeStyle = col([255, 214, 150], 0.3); sb.x.lineWidth = 2; sb.x.beginPath(); sb.x.ellipse(I.x + hw * 0.1, I.top + I.d * 0.55, hw * 0.28, I.d * 0.3, 0, Math.PI * 0.95, Math.PI * 1.6); sb.x.stroke();
    }
    // top: grass fringe, silhouette trees, crystal spires
    K.grass(sb.x, null, S.top.slice(2, -2), I.seed + 3, { density: 0.9, h: 6, w: 1, color: [56, 40, 110], moss: [140, 120, 240] });
    for (const [dx, h] of I.trees || []) K.tree(sb.x, null, I.x + dx, S.topY(I.x + dx) + 2, h, I.seed * 9 + dx, { kind: I.dead ? 'dead' : null, bark: [24, 14, 50], leaf: [40, 28, 84], rim: [230, 200, 190] });
    if (I.spires) for (let k = 0; k < I.spires; k++) {
      const x = I.x + (k - (I.spires - 1) / 2) * hw * 0.32 + (r() - 0.5) * 10, y = S.topY(x) + 3, h = 30 + r() * 45, w = 7 + r() * 7;
      sb.x.fillStyle = col([34, 22, 70]); sb.x.beginPath(); sb.x.moveTo(x - w / 2, y); sb.x.lineTo(x - w * 0.2, y - h); sb.x.lineTo(x + w * 0.15, y - h * 0.9); sb.x.lineTo(x + w / 2, y); sb.x.fill();
      sb.x.strokeStyle = col([255, 214, 150], 0.35); sb.x.lineWidth = 1.2; sb.x.beginPath(); sb.x.moveTo(x - w / 2, y); sb.x.lineTo(x - w * 0.2, y - h); sb.x.stroke();
    }
    if (I.crystals) K.crystals(sb.x, se.x, I.x + (r() - 0.5) * hw * 0.6, S.topY(I.x) + 3, 3, 26, I.crystals, I.seed * 3, { glow: 0.6 });
    // a few hanging roots
    const under = S.under.filter(p => p[1] - S.topY(p[0]) > I.d * 0.3);
    for (let k = 0; k < 7; k++) { const p = under[Math.floor(r() * under.length)]; if (p) K.root(sb.x, null, p[0], p[1] - 3, 16 + r() * 50, 2.2 + r() * 2, I.seed * 19 + k, { color: [20, 12, 44], rim: [150, 120, 230] }); }
    // satellite rocks drifting beside the island
    for (let k = 0; k < (I.sats || 0); k++) {
      const side = k % 2 ? 1 : -1, sz = 12 + r() * 26, x = I.x + side * (hw + 20 + r() * 60), y = I.top + I.d * (0.2 + r() * 0.6);
      const Q = K.rock({ cx: x, cy: y, w: sz * 1.4, h: sz, seed: I.seed * 7 + k, corners: 6, taper: 0.6, flat: 0.5, jitter: 0.3 });
      const m = K.mass({ poly: Q, seed: I.seed * 7 + k, pad: 5, bevel: 3, dome: sz * 0.5, domeK: 0.7, bump: 1, crack: 0, cyl: { cx: x, hw: sz * 0.7, k: 0.5 },
        pal: { dark: [14, 8, 34], base: [70, 50, 140], rim: [255, 214, 150] }, amb: 0.12, rimW: 2, rimK: 0.55, riftW: X => riftW(X) });
      sb.x.drawImage(m.c, m.x, m.y);
    }
    // a faint distant light-fall
    if (I.fall != null) {
      const fx = I.x + I.fall * I.w, fy = S.underY(fx) - 2;
      K.lightfall(sb.x, se.x, fx, fy, 16, 150 + r() * 120, mixc([225, 210, 255], [255, 160, 200], rw), I.seed + 50, { spread: 2.2, strands: 16, drops: 8, mistW: 4, haloK: 0.7, mistK: 0.8 });
    }
    commit(b, sb, I.hz, HAZE(I.x));
    commit(e, se, I.hz * 0.5, [0, 0, 0]);
    return { S, yBot };
  }

  function paintSpeck([x, top, w], b, i) {
    const r = rng(700 + i), hw = w / 2;
    const lobes = [{ x: x + (r() - 0.5) * hw * 0.5, y: top + w * (0.4 + r() * 0.3), w: hw * 0.7, p: 1.1 }, { x: x + (r() < 0.5 ? -1 : 1) * hw * 0.5, y: top + w * (0.2 + r() * 0.15), w: hw * 0.35 }];
    const S = K.island({ xL: x - hw, xR: x + hw, top, tilt: (r() - 0.5) * 0.2, thick: w * 0.1, seed: 700 + i, lobes, droop: 0.12, jag: 1.4, step: 1.5 });
    const sb = subCanvas(Math.floor(x - hw - 20), Math.floor(top - 40), w + 40, w + 90);
    const M = K.mass({ poly: S.poly, seed: 700 + i, pad: 4, openTop: true, bevel: 3, dome: w * 0.25, domeK: 0.7, bump: 1, crack: 0, cyl: { cx: x, hw, k: 0.5, down: 0.5 },
      pal: { dark: [20, 12, 44], base: [74, 56, 146], moss: [120, 100, 220], rim: [255, 214, 150] }, moss: 3, amb: 0.2, rimW: 1.5, rimK: 0.5, riftW: X => riftW(X) });
    sb.x.drawImage(M.c, M.x, M.y);
    if (r() < 0.6) K.tree(sb.x, null, x + (r() - 0.5) * hw * 0.6, S.topY(x) + 1, w * 0.35, 800 + i, { kind: riftW(x) > 0.6 ? 'dead' : null, bark: [30, 20, 60], leaf: [50, 36, 100], rim: [230, 200, 190] });
    commit(b, sb, 0.4 + r() * 0.15, HAZE(x));
  }

  function paintPlanet(b, e) {
    const px = 2420, py = 430, pr = 125, tilt = -0.32, rw = riftW(px);
    const ringRange = [1.42, 2.35];
    const ring = (front) => {
      b.save(); b.translate(px, py); b.rotate(tilt); b.scale(1, 0.26);
      b.beginPath(); b.rect(-pr * 3, front ? 0 : -pr * 3, pr * 6, pr * 3); b.clip();
      const n = makeNoise(88);
      for (let i = 0; i < 90; i++) {
        const t = i / 89, rr = pr * (ringRange[0] + (ringRange[1] - ringRange[0]) * t);
        const gap = Math.abs(t - 0.62) < 0.035 ? 0.15 : 1, dens = (0.35 + 0.65 * (0.5 + 0.5 * n(t * 18, 1.3))) * gap * Math.sin(Math.PI * Math.min(1, t * 1.05));
        const c = mixc([230, 205, 255], [255, 190, 170], t * 0.6);
        b.strokeStyle = col(c, 0.13 * dens); b.lineWidth = pr * (ringRange[1] - ringRange[0]) / 89 * 1.6; b.beginPath(); b.arc(0, 0, rr, 0, 7); b.stroke();
        e.save(); e.translate(px, py); e.rotate(tilt); e.scale(1, 0.26); e.beginPath(); e.rect(-pr * 3, front ? 0 : -pr * 3, pr * 6, pr * 3); e.clip(); e.strokeStyle = col(c, 0.3 * dens * (front ? 1 : 0.55)); e.lineWidth = pr * (ringRange[1] - ringRange[0]) / 89 * 1.6; e.beginPath(); e.arc(0, 0, rr, 0, 7); e.stroke(); e.restore();
      }
      b.restore();
    };
    // atmosphere glow
    blob(e, px, py, pr * 1.9, mixc([200, 170, 255], [255, 140, 190], rw), 0.12);
    ring(false);
    // body
    b.save(); b.beginPath(); b.arc(px, py, pr, 0, 7); b.clip();
    const bg = b.createLinearGradient(px, py - pr, px, py + pr);
    bg.addColorStop(0, col([200, 150, 235])); bg.addColorStop(0.5, col([170, 110, 200])); bg.addColorStop(1, col([120, 70, 170])); b.fillStyle = bg; b.fillRect(px - pr, py - pr, 2 * pr, 2 * pr);
    const n = makeNoise(12);
    b.translate(px, py); b.rotate(tilt);
    for (let i = 0; i < 40; i++) {
      const y = -pr + (i + 0.5) * pr * 2 / 40, a = 0.08 + 0.1 * (0.5 + 0.5 * n(i * 0.7, 3.1));
      b.fillStyle = col(i % 3 === 0 ? [255, 210, 230] : i % 3 === 1 ? [110, 60, 160] : [220, 150, 200], a);
      b.beginPath(); for (let x = -pr; x <= pr; x += 6) { const yy = y + 4 * n(x / 40, i * 1.3); x === -pr ? b.moveTo(x, yy) : b.lineTo(x, yy); } b.lineTo(pr, y + pr / 20 + 4); b.lineTo(-pr, y + pr / 20 + 4); b.closePath(); b.fill();
    }
    b.setTransform(1, 0, 0, 1, 0, 0);
    // lit from the upper left (the cosmic sun): terminator towards the lower right
    const tg = b.createRadialGradient(px - pr * 0.55, py - pr * 0.6, pr * 0.2, px - pr * 0.2, py - pr * 0.2, pr * 1.75);
    tg.addColorStop(0, 'rgba(255,240,220,0.5)'); tg.addColorStop(0.3, 'rgba(255,220,220,0.05)'); tg.addColorStop(0.62, 'rgba(10,4,24,0.7)'); tg.addColorStop(1, 'rgba(6,2,16,0.97)');
    b.fillStyle = tg; b.fillRect(px - pr, py - pr, 2 * pr, 2 * pr);
    // ring shadow across the body
    b.save(); b.translate(px, py); b.rotate(tilt); b.scale(1, 0.26); b.strokeStyle = 'rgba(12,5,26,0.45)'; b.lineWidth = pr * 0.5; b.beginPath(); b.arc(0, -pr * 0.35, pr * 1.9, Math.PI * 0.1, Math.PI * 0.9); b.stroke(); b.restore();
    b.restore();
    // lit limb (emissive) and a crimson glint from the rift below
    e.save(); e.lineCap = 'round';
    e.strokeStyle = col([255, 230, 210], 0.75); e.lineWidth = 4; e.beginPath(); e.arc(px, py, pr - 2, Math.PI * 0.95, Math.PI * 1.62); e.stroke();
    { const lg = e.createRadialGradient(px - pr * 0.5, py - pr * 0.55, 2, px - pr * 0.3, py - pr * 0.3, pr * 1.1); lg.addColorStop(0, col([255, 235, 225], 0.8)); lg.addColorStop(0.5, col([235, 185, 235], 0.3)); lg.addColorStop(1, col([200, 150, 230], 0)); e.save(); e.beginPath(); e.arc(px, py, pr, 0, 7); e.clip(); e.fillStyle = lg; e.fillRect(px - pr, py - pr, 2 * pr, 2 * pr); e.restore(); }
    e.strokeStyle = col([255, 80, 130], 0.35 * (0.5 + rw * 0.5)); e.lineWidth = 2.5; e.beginPath(); e.arc(px, py, pr - 1.5, Math.PI * 0.35, Math.PI * 0.75); e.stroke();
    e.restore();
    ring(true);
    // moon, lit from the upper left
    const mx = 2130, my = 240, mr = 26;
    b.save(); b.beginPath(); b.arc(mx, my, mr, 0, 7); b.clip();
    const mg = b.createRadialGradient(mx - mr * 0.5, my - mr * 0.5, 2, mx, my, mr * 1.1); mg.addColorStop(0, col([220, 235, 255])); mg.addColorStop(0.5, col([130, 150, 220])); mg.addColorStop(1, col([30, 26, 70])); b.fillStyle = mg; b.fillRect(mx - mr, my - mr, 2 * mr, 2 * mr);
    for (let i = 0; i < 6; i++) { const r2 = rng(40 + i); blob(b, mx + (r2() - 0.5) * mr, my + (r2() - 0.5) * mr, 3 + r2() * 6, [40, 36, 90], 0.35); }
    b.restore();
    blob(e, mx, my, mr * 2.4, [150, 180, 255], 0.14);
  }

  function paintRidges(b, e) {
    // far ridgelines, lowest last (nearest), each sinking into a bright misty abyss
    const ridge = (base, amp, scale, seed, c0, c1, rimA, fadeTo) => {
      const n = makeNoise(seed), pts = [];
      for (let x = -10; x <= W + 10; x += 4) {
        const big = 0.5 + 0.5 * fbm(n, x / (scale * 2.6), 2.2, 3), peaks = Math.pow(ridged(n, x / scale, seed * 0.1, 5), 1.6);
        pts.push([x, base - amp * (0.25 + 0.75 * big) * (0.35 + 0.9 * peaks) - amp * 0.1 * n(x / 40, 7)]);
      }
      b.save(); b.beginPath(); b.moveTo(-10, H); pts.forEach(p => b.lineTo(p[0], p[1])); b.lineTo(W + 10, H); b.closePath();
      const g = b.createLinearGradient(0, base - amp, 0, H); g.addColorStop(0, col(c0, 0.85)); g.addColorStop(0.35, col(c1, 0.55)); g.addColorStop(1, col(c1, fadeTo)); b.fillStyle = g; b.fill(); b.restore();
      b.save(); b.beginPath(); pts.forEach((p, i) => i ? b.lineTo(p[0], p[1]) : b.moveTo(p[0], p[1])); b.strokeStyle = col([255, 214, 150], rimA); b.lineWidth = 1.5; b.stroke(); b.restore();
      // pinpoint lights on the ridge: distant crystal groves
      const r = rng(seed + 1);
      for (let i = 0; i < 16; i++) { const p = pts[Math.floor(r() * pts.length)]; const c = r() < 0.5 ? [180, 140, 255] : r() < 0.5 ? [95, 224, 255] : [255, 201, 60]; const cc = mixc(c, [255, 70, 120], riftW(p[0]) * 0.8); blob(e, p[0], p[1] + 6 + r() * 30, 3 + r() * 3, cc, 0.7); }
      return pts;
    };
    ridge(1640, 200, 420, 31, [92, 74, 164], [84, 66, 156], 0.14, 0.0);
    ridge(1760, 170, 300, 47, [70, 54, 136], [62, 46, 124], 0.2, 0.0);
  }

  LAYERS.distant = LAYERS.far = async function () {
    const t0 = performance.now();
    const base = mk(W, H), b = cx2(base), emis = mk(W, H), e = cx2(emis);
    paintPlanet(b, e);
    paintRidges(b, e);
    SPECKS.forEach((s, i) => paintSpeck(s, b, i));
    // islands, farthest (most haze) first
    [...ISLES].sort((p, q) => q.hz - p.hz).forEach(I => paintIsle(I, b, e));
    // readability: island centres off the soft zones, widths <= 420
    const bad = ISLES.filter(I => CFG.soft.some(z => K.inEllipse(I.x, I.top + I.d * 0.4, z)) || I.w > 420).map(I => I.seed);
    const badS = SPECKS.filter(s => CFG.soft.some(z => K.inEllipse(s[0], s[1], z)));
    console.log('far islands centred on soft zones / too wide:', bad.length || badS.length ? JSON.stringify([bad, badS]) : 'none');
    const lit = window.__islandsNoAtmosphere ? K.atmosphere(base, emis, { atm: { ...CFG.atm, haze: 0, hazeBottom: 0, saturation: 1, contrast: 1, blur: 0, maxLuma: 1, emissiveMax: 1 }, splitX: CFG.splitX, fade: CFG.fade })
      : K.atmosphere(base, emis, { atm: CFG.atm, splitX: CFG.splitX, fade: CFG.fade, emisHaze: 0.45 });
    const out = K.downsample(lit, Math.round(W * CFG.res), Math.round(H * CFG.res));
    console.log('far (distant)', out.width + 'x' + out.height, Math.round(performance.now() - t0) + ' ms');
    window.__last = out;
    return out;
  };
})();
