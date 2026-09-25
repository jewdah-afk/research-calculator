// Parallax depth 3, `mid` (f = 0.45): the layer that sells the depth. Seven detailed floating islands (lit rock
// undersides, hanging roots, glowing crystal seams, tiny trees) pour luminous light-falls from the lightfall sprite
// anchors, over horizontal mist bands at 55-95 % of the height. No two share a silhouette: a broken twin pouring from
// its cleft, a natural arch pouring from its keystone, a ruined colonnade under a rock needle, three plain slabs, and
// the corrupted island. The rift side (right) is cracked with crimson seams; the corrupted island sits where the
// clamped east-limit cameras see it (under the outcrop's tip), lit green from above. The trunk band and the rift
// cluster (the hard keep-clear zones) hold mist only.
// The composition is designed in a 3360x2160 frame (the layer before the pan margin, REALM.md 2.5) centred in the
// layer (size from realm.json, 4128x2736); two more islands (H west, I on the rift side) and the mist banks carry it out
// into the margin strips. Transparent. Painted at full local size, output at res.HIGH 0.75 -> 3096x2052.
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
    // the warm rim is painted more saturated than KEY: the atmosphere pass (desaturate, lower contrast, haze) pulls it
    // back toward (255, 214, 150) on screen
    const WARM = [255, 180, 84];
    const mk = (w, h) => { const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h)); return c; };
    const cx2 = (c, read) => c.getContext('2d', read ? { willReadFrequently: true } : undefined);
    const luma = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const col = (c, a = 1) => `rgba(${Math.round(c[0])},${Math.round(c[1])},${Math.round(c[2])},${a})`;
    const mixc = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    const inEllipse = (x, y, z, grow = 0) => { const dx = (x - z[1]) / (z[3] + grow), dy = (y - z[2]) / (z[4] + grow); return dx * dx + dy * dy < 1; };

    // ---------------------------------------------------------------- gaussian blur with clamped edges
    // Canvas blur treats pixels outside the canvas as transparent, so alpha falls off at the layer border and a dim strip
    // slides in at the screen edge during overscroll. Pad by 3 sigma with the edge pixels replicated, blur, crop.
    function padCanvas(src, p) {
      const w = src.width, h = src.height, t = mk(w + 2 * p, h + 2 * p), tx = cx2(t);
      tx.imageSmoothingEnabled = false;
      tx.drawImage(src, p, p);
      tx.drawImage(src, 0, 0, 1, h, 0, p, p, h); tx.drawImage(src, w - 1, 0, 1, h, w + p, p, p, h);
      tx.drawImage(src, 0, 0, w, 1, p, 0, w, p); tx.drawImage(src, 0, h - 1, w, 1, p, h + p, w, p);
      tx.drawImage(src, 0, 0, 1, 1, 0, 0, p, p); tx.drawImage(src, w - 1, 0, 1, 1, w + p, 0, p, p);
      tx.drawImage(src, 0, h - 1, 1, 1, 0, h + p, p, p); tx.drawImage(src, w - 1, h - 1, 1, 1, w + p, h + p, p, p);
      return t;
    }
    function padBlur(src, px) {
      const p = Math.ceil(px * 3) + 2, t = padCanvas(src, p), o = mk(src.width, src.height), ox = cx2(o);
      ox.filter = `blur(${px}px)`; ox.drawImage(t, -p, -p); ox.filter = 'none';
      return o;
    }
    // a low-res layer-sized canvas scaled up to w x h and blurred with clamped edges
    function upBlur(c, w, h, px) {
      const u = mk(w, h), ux = cx2(u); ux.imageSmoothingQuality = 'high'; ux.drawImage(c, 0, 0, w, h);
      return padBlur(u, px);
    }

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
      // warm key-light rim (REALM.md 4, 255,214,150 from the upper left): a thin emissive line on up-left facing edges and
      // grass lips, so it survives the layer's haze; S.warm = strength (far 0.3, mid 0.6, near 1). Crossfades to the
      // crimson rim inside the rift biome.
      const WS = S.warm || 0, ww = S.warmW || 2, WC = S.warmCol || WARM, wr = WS > 0 ? new ImageData(w, h) : null, wd = wr ? wr.data : null;
      let warmAny = false;
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
        // rims: key light from the upper left; crimson from the right inside the rift biome. With a warm rim, the outermost
        // px belong to it: the broad base rim steps back there so the thin gold line reads on a dark edge, not over lilac.
        const wm = wd ? a * (0.75 * (1 - at(x + L2[0] * ww, y + L2[1] * ww)) + 0.25 * (1 - at(x + L2[0] * ww * 2.2, y + L2[1] * ww * 2.2))) : 0;
        const rk = a * (0.65 * (1 - at(x + L2[0] * rimW, y + L2[1] * rimW)) + 0.35 * (1 - at(x + L2[0] * rimW * 2.4, y + L2[1] * rimW * 2.4)));
        const rc = P.rim || LILAC, rs = (S.rimK == null ? 0.7 : S.rimK) * (1 - 0.45 * rw) * (1 - 0.75 * wm * (1 - rw));
        R += rc[0] * rk * rs; G += rc[1] * rk * rs; B += rc[2] * rk * rs;
        if (rw > 0) {
          const rr = a * (1 - at(x + rimW * 1.2, y - rimW * 0.3)) * rw * (S.riftRimK == null ? 0.6 : S.riftRimK);
          R += CRIMSON[0] * rr; G += CRIMSON[1] * rr; B += CRIMSON[2] * rr;
        }
        const o4 = i * 4;
        if (wm > 0.02) { // the lit edge itself turns warm (base), and the emissive line glows over it
          const wc = mixc(WC, CRIMSON, rw), br = WS * wm * (0.72 + 0.28 * (0.5 + 0.5 * nX(X / 34, Y / 34))), tk = clamp(br * 0.8);
          R += (wc[0] * 0.85 - R) * tk; G += (wc[1] * 0.85 - G) * tk; B += (wc[2] * 0.85 - B) * tk;
          wd[o4] = wc[0]; wd[o4 + 1] = wc[1]; wd[o4 + 2] = wc[2]; wd[o4 + 3] = clamp(br) * 255; warmAny = true;
        }
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
      if (warmAny) {
        const wc = mk(w, h); cx2(wc).putImageData(wr, 0, 0);
        if (!e) e = mk(w, h);
        const ex = cx2(e); ex.save(); ex.globalCompositeOperation = 'lighter'; ex.drawImage(wc, 0, 0); ex.restore();
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
      if (e && o.mossLine) { // soft glowing moss line along the lit top edge (mossDy px under the lip, below the warm rim)
        const md = o.mossDy == null ? 1 : o.mossDy; e.save(); e.lineCap = 'round';
        for (let i = 0; i < top.length - 1; i++) {
          const k = 0.5 + 0.5 * Math.sin(i * 0.37 + seed) * Math.sin(i * 0.11 + seed * 2);
          e.strokeStyle = col(o.mossLine, (0.08 + 0.3 * k * k) * (o.mossA || 1)); e.lineWidth = 3 + 3 * k; e.beginPath(); e.moveTo(top[i][0], top[i][1] + md); e.lineTo(top[i + 1][0], top[i + 1][1] + md); e.stroke();
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
    // o.x0, o.y0: the (drawing-space) point of the canvas' top-left corner (default 0, 0); o.w x o.h: the area covered
    function cloudBank(b, o) {
      const q = o.q || 4, w = Math.ceil(o.w / q), h = Math.ceil(o.h / q), c = mk(w, h), x = cx2(c, true), im = x.createImageData(w, h), d = im.data;
      const x0 = o.x0 || 0, y0 = o.y0 || 0;
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
        const X = x0 + i * q, Y = y0 + j * q;
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
      b.drawImage(upBlur(c, w * q, h * q, o.blur || 5), x0, y0);
    }

    // ---------------------------------------------------------------- mist band (low-res noise, stretched)
    function mistBand(b, o) {
      const q = 4, w = Math.ceil(o.w / q), h = Math.ceil(o.h / q), c = mk(w, h), x = cx2(c, true), im = x.createImageData(w, h), d = im.data;
      const n = makeNoise(o.seed), n2 = makeNoise(o.seed + 7), x0 = o.x0 || 0, y0 = o.y0 || 0;
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const X = x0 + i * q, Y = y0 + j * q;
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
      b.drawImage(upBlur(c, w * q, h * q, o.blur || 6), x0, y0);
    }

    // ---------------------------------------------------------------- the atmosphere pass (REALM.md section 4)
    // base: colour art; emis: light that may exceed maxLuma (up to emissiveMax). Both get the same colour recipe;
    // the light is then screened over the base (premultiplied), the luma limit follows the local emissive share,
    // and the whole layer gets a premultiplied gaussian blur of `blur` local px (edges clamped, see padBlur).
    // T.splitX is in canvas px; the haze-bottom ramp runs over rows T.hy0 .. T.hy0 + T.hh (default: the whole canvas).
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
        const k = A.haze + A.hazeBottom * smooth(0.35, 1, (y - (T.hy0 || 0)) / (T.hh || h));
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
      return A.blur ? padBlur(base, A.blur) : base;
    }

    function downsample(src, w, h) {
      // every step scales an edge-replicated copy, so the border texels keep their alpha (no dim strip at the layer edge)
      const step = (c, tw, th) => {
        const p = Math.ceil(2 * c.width / tw) + 2, t = padCanvas(c, p), o = mk(tw, th), x = cx2(o), sx = tw / c.width, sy = th / c.height;
        x.imageSmoothingQuality = 'high'; x.drawImage(t, -p * sx, -p * sy, t.width * sx, t.height * sy); return o;
      };
      let c = src;
      while (c.width / 2 >= w * 1.02) c = step(c, Math.round(c.width / 2), Math.round(c.height / 2));
      if (c.width === w && c.height === h) return c;
      return step(c, w, h);
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

    return { LV, L2, KEY, WARM, LILAC, CRIMSON, padCanvas, padBlur, upBlur, mk, cx2, luma, col, mixc, inEllipse, edt, bbox, mass, island, rock, crystal, crystals, seams, root, vine, tree, grass, lightfall, mistBand, cloudBank, atmosphere, downsample, zoneMax };
  })();
  // ================================================================ ISLAND KIT (end)

  // ---- contract snapshot (realm.json layers[mid], sprites[lightfall]); repaint if `node camera.js --build` changes them
  // blur 1.5 (was 1): softness grows with distance behind the focal plane (near 0.9 < mid 1.5 < far 3)
  const CFG = {
    frame: [3360, 2160], size: [4128, 2736], res: 0.75, splitX: 1918.5, fade: 563,   // splitX, falls, hard: design frame
    atm: { hazeColor: [56, 40, 118], hazeRift: [96, 26, 62], haze: 0.3, hazeBottom: 0.25, saturation: 0.85, contrast: 0.75, blur: 1.5, maxLuma: 0.62, emissiveMax: 0.85 },
    // sprites[lightfall].instances: x, y = top of the fall (the lip), s = sprite width, len = length
    falls: [[1916, 236, 80, 380], [2286, 1536, 81, 420], [376, 1206, 63.9, 520], [2816, 356, 58, 560], [1186, 1616, 77.2, 380], [596, 316, 74, 620], [3036, 1306, 64.4, 480]],
    hard: [['m', 1491, 1369.8, 171, 194], ['mm', 1347, 1396.8, 171, 194], ['em', 1635, 1396.8, 171, 194], ['p', 1491, 1225.8, 171, 194], ['pe', 1284, 1099.8, 171, 194], ['sp', 1414.5, 1077.3, 171, 194], ['pb', 1567.5, 1077.3, 171, 194], ['pp', 1698, 1099.8, 171, 194], ['se', 1333.5, 955.8, 171, 194], ['hp', 1491, 933.3, 171, 194], ['ep', 1648.5, 955.8, 171, 194], ['hb', 1347, 811.8, 171, 194], ['ap', 1491, 789.3, 171, 194], ['mp', 1635, 811.8, 171, 194], ['t', 1491, 658.8, 171, 194], ['pm', 2233.5, 1216.8, 171, 194], ['pep', 2071.5, 1045.8, 171, 194], ['cr', 2395.5, 1054.8, 171, 194], ['cm', 2476.5, 933.3, 171, 194], ['ex', 2233.5, 865.8, 171, 194], ['ach', 1050, 784.8, 171, 194]],
  };
  // the layer grew around the design frame (the pan margin): paint in design coordinates, translated to the centre
  const RL = typeof window !== 'undefined' && window.REALM && window.REALM.layers && window.REALM.layers.find(l => l.id === 'mid');
  if (RL) { CFG.size = RL.size; CFG.res = RL.res.HIGH; }
  const [W0, H0] = CFG.frame, [W, H] = CFG.size, OX = (W - W0) / 2, OY = (H - H0) / 2;
  const toCanvas = zs => zs.map(z => [z[0], z[1] + OX, z[2] + OY, z[3], z[4]]);   // design-frame zones -> canvas px
  const K = KIT, { mk, cx2, col, mixc } = K;
  const riftW = x => smooth(CFG.splitX - CFG.fade, CFG.splitX + CFG.fade, x);
  const FALL = { realm: [222, 204, 255], rift: [255, 150, 196], corrupt: [178, 255, 196] };
  const fallCol = (x, corrupt) => corrupt ? FALL.corrupt : mixc(FALL.realm, FALL.rift, riftW(x));
  const fall = i => { const [x, y, s, len] = CFG.falls[i]; return { x, y, s, len }; };
  const WARM = { warm: 1, warmW: 3.5 }; // thin warm key-light rim; after this layer's haze and blur it reads at ~60% of near's

  // Island specs. xL/xR/top: the grassy top line; lobes: hanging cones {x, y tip, w half-width}; the fall anchor is
  // the lip (a flat notch) at the lightfall instance. Positions keep every island out of the hard zones.
  // Three islands keep the plain slab (A, D, B: far up or half behind the rift). The four the camera sees most each
  // break it, so the layer never reads as one stamp repeated:
  //   F  broken twin: a crack splits the slab from the top, the right half has slumped, and the light pours out of the
  //      cleft between two hanging fangs instead of off a lobe tip
  //   C  natural arch: the light pours from the keystone down through the arch
  //   E  a ruined colonnade at the foot of a rock needle, a gold relic light between the columns; the fall spills off
  //      the island's right edge
  //   G  the corrupted island (below)
  // G is placed for the cameras that actually see the corrupt biome. The camera cannot centre on the outcrop: at the
  // hard east limit it stops at (2880, y, z 1) and (3072, y, z 1.25) on 1920x1080 and (3294, y, z 1.25) on 1366x768,
  // where this layer shows local x <= 3072 (1920) and <= 2920 (1366), and the world outcrop covers the right third of
  // the screen. Projected with camera.js localToScreen, the band x 2570-2900, y 1330-1440 is clear of the world at
  // (2880, 1250, z 1), (2880, 1480, z 1), (3072, 1320, z 1.25) and (3294, 1320, z 1.25), right under the outcrop's
  // lower tip. G1, the corrupted main mass, fills that band; G2, a raised block (the tall step), holds the fall-6 lip at
  // its left edge and sits off screen there. The green is light, not paint: dark rock with a green rim on the edges
  // that face the outcrop (up), green veins and crystals, and debris the corruption lifts off the top.
  const ISLES = [
    { id: 'F', fall: 5, xL: 235, xR: 915, top: 40, tilt: 0.02, thick: 46, seed: 301, lobes: [{ x: 330, y: 238, w: 96 }, { x: 852, y: 226, w: 66 }, { x: 440, y: 200, w: 120 }],
      shape: 'twin', crack: 600, crystals: [[860, 5, 40, [95, 224, 255]], [300, 3, 26, [179, 92, 255]]], trees: [[420, 92], [700, 62, null, 0.12]], roots: 16 },
    { id: 'A', fall: 0, xL: 1712, xR: 2120, top: 20, tilt: -0.01, thick: 40, seed: 302, lobes: [{ x: 1795, y: 176, w: 95 }, { x: 2045, y: 190, w: 85 }],
      crystals: [[2050, 4, 40, [95, 224, 255]]], trees: [[1790, 70]], roots: 10 },
    { id: 'D', fall: 3, xL: 2540, xR: 3130, top: 120, tilt: -0.03, thick: 44, seed: 303, lobes: [{ x: 2655, y: 310, w: 115 }, { x: 2995, y: 336, w: 135 }],
      crystals: [[2640, 5, 48, [232, 70, 190]], [3070, 3, 30, [255, 46, 99]]], trees: [[2880, 84, 'dead']], roots: 14 },
    { id: 'C', fall: 2, xL: 118, xR: 700, top: 1085, tilt: 0.02, thick: 58, seed: 304, shape: 'arch',
      lobes: [{ x: 196, y: 1478, w: 44, p: 1.6 }, { x: 262, y: 1446, w: 30, p: 1.7 }, { x: 548, y: 1512, w: 56, p: 1.6 }, { x: 636, y: 1450, w: 34, p: 1.7 }],
      crystals: [[196, 5, 50, [179, 92, 255]], [660, 3, 30, [95, 224, 255]]], trees: [[560, 104], [626, 62], [372, 50]], roots: 16 },
    { id: 'E', fall: 4, xL: 780, xR: 1212, top: 1506, tilt: 0.09, thick: 40, seed: 305, lobes: [{ x: 960, y: 1760, w: 175, p: 1.05 }, { x: 850, y: 1660, w: 70 }], anchorSlope: 1.6,
      needle: { x: 822, w: 76, h: 350, lean: -0.05 }, ruin: true, crystals: [], trees: [[1122, 50]], roots: 12 },
    { id: 'B', fall: 1, xL: 2150, xR: 2560, top: 1420, tilt: -0.075, thick: 40, seed: 306, lobes: [{ x: 2385, y: 1690, w: 160 }, { x: 2512, y: 1585, w: 62 }],
      crystals: [[2488, 6, 52, [255, 46, 99]], [2350, 3, 30, [232, 70, 190]]], trees: [[2420, 76, 'dead']], roots: 14 },
    { id: 'G', fall: 6, seed: 307, corrupt: true, xL: 2600, xR: 3330, top: 1300, tilt: -0.03, thick: 38, jag: 1.4, roots: 16, shape: 'step', step: [2930, 2962, 128],
      lobes: [{ x: 2685, y: 1478, w: 92, p: 1.15 }, { x: 2828, y: 1532, w: 118, p: 1.2 }, { x: 2925, y: 1425, w: 42, p: 1.6 }, { x: 3165, y: 1420, w: 125 }, { x: 3292, y: 1335, w: 55 }],
      crystals: [[2664, 5, 44, [57, 255, 20]], [2792, 7, 66, [57, 255, 20]], [2904, 4, 36, [31, 191, 74]], [3232, 4, 42, [57, 255, 20]], [3000, 3, 28, [255, 46, 99]]],
      trees: [[3120, 70, 'dead']],
      fragments: [[2698, 1226, 34, 0.35], [2772, 1180, 22, -0.25], [2846, 1216, 15, 0.6], [2735, 1148, 10, 0.1]] },
    // out at the west and east edges of the design frame, reaching into the pan margin (no light-fall: plain slabs)
    { id: 'H', xL: -250, xR: 190, top: 560, tilt: 0.03, thick: 44, seed: 308, lobes: [{ x: -150, y: 776, w: 105 }, { x: 70, y: 742, w: 90 }, { x: -30, y: 700, w: 60 }],
      crystals: [[-60, 4, 40, [95, 224, 255]], [150, 3, 26, [179, 92, 255]]], trees: [[-170, 86], [40, 58]], roots: 14 },
    { id: 'I', xL: 3250, xR: 3660, top: 660, tilt: -0.04, thick: 42, seed: 309, lobes: [{ x: 3340, y: 870, w: 100 }, { x: 3560, y: 900, w: 120 }],
      crystals: [[3300, 5, 44, [232, 70, 190]], [3600, 3, 30, [255, 46, 99]]], trees: [[3470, 78, 'dead']], roots: 14 },
  ];

  // An island() outline with its top and underside remapped: fTop / fUnder (x, y) -> y (either may be null).
  function reshape(S, fTop, fUnder) {
    const topY = fTop ? (x => fTop(x, S.topY(x))) : S.topY;
    const top = S.top.map(([x]) => [x, topY(x)]);
    const under = S.under.map(([x, y]) => [x, Math.max(topY(x) + 0.5, fUnder ? fUnder(x, y) : y)]);
    const underY = x => Math.max(topY(x) + 0.5, fUnder ? fUnder(x, S.underY(x)) : S.underY(x));
    return { ...S, poly: [...top, ...under], top, under, topY, underY };
  }
  // F: a crack from the top at `crack` splits the slab, the right half has slumped; under the lip two fangs hang and
  // the cleft between them opens downward (walls sloping out), so the light pours from inside the island
  function twinShape(I, F, S) {
    const XC = I.crack, nh = Math.max(14, F.s * 0.3), n = makeNoise(I.seed + 40);
    const slump = x => x > XC ? 7 + (x - XC) * 0.06 : 0;
    const fTop = (x, y) => y + slump(x) + 170 * Math.pow(Math.max(0, 1 - Math.abs(x - XC) / 30), 1.25);
    const fUnder = (x, y) => {
      const d = Math.abs(x - F.x); if (d <= nh) return F.y;
      y += slump(x);
      if (d < 175) y = Math.max(y, F.y + 175 * (1 - Math.pow(d / 175, 2.4)) + 16 * n(x / 17, 2.2) * (d / 175));
      return Math.min(y, F.y + (d - nh) * 1.45 + 6 * n(x / 9, 7.1));
    };
    return reshape(S, fTop, fUnder);
  }
  // G: the right part is a raised block (a tall step facing the key light); the fall-6 lip is a crack in the block's
  // underside whose mouth widens downward
  function stepShape(I, F, S) {
    const [x0, x1, hgt] = I.step, nh = Math.max(14, F.s * 0.3), n = makeNoise(I.seed + 42);
    const fTop = (x, y) => y - hgt * smooth(x0, x1, x + 6 * n(1.3, (y - I.top) / 18));
    const fUnder = (x, y) => { const d = Math.abs(x - F.x); if (d <= nh) return F.y; return d < 70 ? Math.min(y, F.y + (d - nh) * 0.9 + 3 * n(x / 8, 4.4)) : y; };
    return reshape(S, fTop, fUnder);
  }
  // C: two fat legs under the slab and an arch cut between them; the keystone is the lip
  function archShape(I, F, S) {
    const nh = Math.max(14, F.s * 0.3), R = 92, RV = 128, n = makeNoise(I.seed + 41), base = I.top + I.thick + 4;
    const leg = (x, x0, x1, yb) => { if (x <= x0 || x >= x1) return -1e9; const u = Math.abs(2 * (x - x0) / (x1 - x0) - 1); return yb - (yb - base) * Math.pow(u, 3.2); };
    const fUnder = (x, y) => {
      const d = Math.abs(x - F.x); if (d <= nh) return F.y;
      y = Math.max(y, leg(x, 122, 420, 1392 + 22 * fbm(n, x / 38, 3.3, 2)), leg(x, 330, 694, 1420 + 24 * fbm(n, x / 38, 5.1, 2)));
      if (d < R) y = Math.min(y, F.y + RV * (1 - Math.sqrt(1 - (d / R) * (d / R))) + 3 * n(x / 7, 1.1));
      return y;
    };
    return reshape(S, null, fUnder);
  }
  // a rock needle rising from (bx, by): ledges on the flanks, a crooked tip
  function needle(bx, by, w, h, lean, seed) {
    const r = rng(seed), L = [], Rt = [], N = 14;
    for (let i = 0; i < N; i++) {
      const t = i / N, y = by - h * t, cx = bx + lean * h * t * t + (t > 0.8 ? (t - 0.8) * h * 0.12 : 0);
      const half = (w / 2) * Math.pow(1 - t, 0.8) * (0.9 + 0.2 * r()) + 2;
      const lk = i % 4 === 1 ? w * 0.16 * r() : 0, rk = i % 5 === 3 ? w * 0.13 * r() : 0;
      L.push([cx - half - lk, y + (r() - 0.5) * 5]); Rt.push([cx + half + rk, y + (r() - 0.5) * 7]);
    }
    const tip = [bx + lean * h + h * 0.024, by - h];
    return [...L, tip, ...Rt.reverse()];
  }
  // a classical column: plinth, drum shaft, capital; a broken one ends in a jagged break
  function columnPoly(x, yb, h, w, seed, broken) {
    const r = rng(seed), hw = w / 2, pl = hw * 1.35, ca = hw * 1.3, yt = yb - h;
    const left = [[x - pl, yb + 10], [x - pl, yb - 5], [x - hw, yb - 8]], right = [[x + hw, yb - 8], [x + pl, yb - 5], [x + pl, yb + 10]];
    let top;
    if (broken) { top = []; for (let i = 0; i <= 5; i++) top.push([x - hw + (2 * hw * i) / 5, yt + (i === 0 || i === 5 ? 4 : 0) + (r() - 0.35) * w * 0.8]); }
    else top = [[x - hw, yt + 9], [x - ca, yt + 7], [x - ca, yt], [x + ca, yt], [x + ca, yt + 7], [x + hw, yt + 9]];
    return [...left, ...top, ...right];
  }
  const rot = (pts, cx, cy, a) => pts.map(([x, y]) => [cx + (x - cx) * Math.cos(a) - (y - cy) * Math.sin(a), cy + (x - cx) * Math.sin(a) + (y - cy) * Math.cos(a)]);
  const STONE = { dark: [10, 6, 24], base: [132, 110, 186], rim: [255, 226, 190], key: [255, 214, 150], bounce: [120, 90, 230] };
  // E: a broken colonnade (two standing columns under a cracked lintel, a snapped column, a stump, a fallen drum) and a
  // gold relic crystal hovering in the doorway, its light on the column faces
  function ruin(b, e, chk, S, I) {
    const stone = (poly, seed, extra = {}) => {
      const M = K.mass({ poly, seed, pad: 6, bevel: 3, dome: 10, domeK: 0.5, bump: 1.5, bumpScale: 12, facet: 22, facetTilt: 0.25, crackW: 1.2, crack: 0.25,
        strata: { period: 17, lw: 0.08, dark: 0.45, warp: 1, wl: 60, tilt: 0 }, pal: STONE, amb: 0.1, gamma: 1.4, rimW: 2, rimK: 0.8, keyK: 0.6, bounceK: 0.35, ao: 0.3,
        riftW: () => 0, warm: 1, warmW: 2.5, ...extra });
      b.drawImage(M.c, M.x, M.y); if (M.e) e.drawImage(M.e, M.x, M.y); chk.drawImage(M.c, M.x, M.y);
      return M;
    };
    const yb = x => S.topY(x) + 2;
    const cols = [[902, 98, 17, false], [956, 112, 17, false], [1016, 60, 16, true], [1062, 30, 16, true]];
    cols.forEach(([x, h, w, br], k) => stone(columnPoly(x, yb(x), h, w, I.seed * 11 + k, br), I.seed * 13 + k));
    // lintel over the first two, cracked through and sagging at its right end
    const ly = yb(902) - 112, lint = [[884, ly - 1], [930, ly - 3], [933, ly + 9], [886, ly + 11]], lint2 = rot([[936, ly - 4], [986, ly - 6], [986, ly + 7], [937, ly + 8]], 936, ly, 0.11);
    stone(lint, I.seed * 17); stone(lint2, I.seed * 17 + 1);
    // a fallen drum and a toppled shaft lying on the grass
    stone(rot([[1080, yb(1080) - 12], [1128, yb(1128) - 16], [1130, yb(1130) - 2], [1082, yb(1082) + 2]], 1100, yb(1100), -0.05), I.seed * 19);
    stone(rot([[846, yb(846) - 10], [870, yb(870) - 12], [872, yb(872)], [848, yb(848) + 1]], 860, yb(860), 0.3), I.seed * 19 + 1);
    // the relic: a gold crystal hovering in the doorway, and its light on the inner column faces and the ground
    const rx = 929, ry = yb(929) - 58;
    blob(e, rx, ry, 46, [255, 201, 60], 0.28); blob(e, rx, yb(929) - 4, 30, [255, 190, 90], 0.22);
    K.crystal(b, e, rx, ry + 12, 24, 9, 0, [255, 214, 120], 1, 1);
    K.crystal(b, e, rx - 7, ry + 10, 12, 5, -0.5, [255, 201, 60], 1, 0.7); K.crystal(b, e, rx + 7, ry + 10, 13, 5, 0.45, [255, 201, 60], 1, 0.7);
    for (const [x, s] of [[911, 1], [947, -1]]) { const g = e.createLinearGradient(x, 0, x + s * 10, 0); g.addColorStop(0, col([255, 201, 90], 0.5)); g.addColorStop(1, col([255, 201, 90], 0)); e.fillStyle = g; e.fillRect(Math.min(x, x + s * 10), ry - 40, 10, 86); }
  }

  // emissive rim for a light other than the key light (the outcrop's green from above, the rift's crimson from the
  // left): mask pixels whose neighbour toward the light lies outside the silhouette. Bright on dark reads as light.
  function dirRim(e, M, dir, w, color, k, o = {}) {
    const { A } = M, W2 = M.w, H2 = M.h, dl = Math.hypot(dir[0], dir[1]), ux = dir[0] / dl, uy = dir[1] / dl, n = makeNoise(o.seed || 5);
    const at = (x, y) => { x = Math.round(x); y = Math.round(y); return x < 0 || y < 0 || x >= W2 || y >= H2 ? 0 : A[y * W2 + x]; };
    const im = new ImageData(W2, H2), dd = im.data;
    for (let y = 0; y < H2; y++) for (let x = 0; x < W2; x++) {
      const a = A[y * W2 + x]; if (a <= 0) continue;
      let v = a * (0.7 * (1 - at(x + ux * w, y + uy * w)) + 0.3 * (1 - at(x + ux * w * 2.6, y + uy * w * 2.6)));
      if (v <= 0.01) continue;
      if (o.region) v *= o.region(x + M.x, y + M.y);
      v *= 0.72 + 0.28 * (0.5 + 0.5 * n((x + M.x) / 21, (y + M.y) / 21));
      const i = (y * W2 + x) * 4; dd[i] = color[0]; dd[i + 1] = color[1]; dd[i + 2] = color[2]; dd[i + 3] = clamp(v * k) * 255;
    }
    const c = mk(W2, H2); cx2(c).putImageData(im, 0, 0);
    e.save(); e.globalCompositeOperation = 'lighter'; e.drawImage(c, M.x, M.y);
    if (o.glow) { e.filter = `blur(${o.glow}px)`; e.globalAlpha = o.glowK || 0.6; e.drawImage(c, M.x, M.y); }
    e.restore();
  }
  // a fracture splitting the rock open: a dark gap (base) that tapers upward, green light inside it (emissive)
  function fracture(b, e, clip, pts, w) {
    const S2 = spline(pts.map(([x, y], i) => [x, y, w * (1 - (i / (pts.length - 1)) * 0.85)]), 8), O = outline(S2);
    b.save(); poly(b, clip); b.clip(); poly(b, O); b.fillStyle = col([3, 2, 8], 0.95); b.fill(); b.restore();
    e.save(); poly(e, clip); e.clip();
    e.filter = 'blur(7px)'; poly(e, O); e.fillStyle = col(GREEN, 0.55); e.fill(); e.lineWidth = 6; e.strokeStyle = col(GREEN, 0.35); e.stroke();
    e.filter = 'none'; const O2 = outline(S2.map(p => ({ ...p, w: p.w * 0.35 }))); poly(e, O2); e.fillStyle = col([190, 255, 200], 0.95); e.fill();
    e.restore();
  }
  const GREEN = [57, 255, 20], GREEN2 = [31, 191, 74], UP_OUTCROP = [0.18, -1]; // the outcrop's light in this layer comes from above

  function paintIsland(I, b, e, chk) {
    const F = I.fall != null ? fall(I.fall) : null, rw = riftW((I.xL + I.xR) / 2), R = rng(I.seed * 7 + 1), corrupt = !!I.corrupt;
    const shapes = (I.parts || [I]).map(P => {
      const withLip = F && P.anchor !== false;
      let S = K.island({ xL: P.xL, xR: P.xR, top: P.top, tilt: P.tilt, thick: P.thick, seed: P.seed || I.seed, lobes: P.lobes, droop: P.droop == null ? 0.08 : P.droop, jag: P.jag,
        anchor: withLip ? { x: F.x, y: F.y, nh: Math.max(14, F.s * 0.3), slope: P.anchorSlope || I.anchorSlope || 1.3 } : null });
      if (I.shape === 'twin') S = twinShape(I, F, S);
      if (I.shape === 'arch') S = archShape(I, F, S);
      if (I.shape === 'step') S = stepShape(I, F, S);
      return S;
    });
    // top / underside lookups over every part (the higher top where parts overlap)
    const topY = x => { let y = 1e9; for (const S of shapes) if (x >= S.top[0][0] - 0.5 && x <= S.top[S.top.length - 1][0] + 0.5) y = Math.min(y, S.topY(x)); return y < 1e9 ? y : shapes[0].topY(x); };
    const yTop = Math.min(...shapes.map(S => Math.min(...S.top.map(p => p[1])))), yBot = Math.max(...shapes.map(S => Math.max(...S.under.map(p => p[1]))));
    const polys = shapes.map(S => S.poly);
    let spire = null;
    if (I.needle) { const Nd = I.needle; spire = needle(Nd.x, topY(Nd.x) + 22, Nd.w, Nd.h, Nd.lean, I.seed + 90); polys.push(spire); }
    const pal = corrupt ? { dark: [3, 2, 9], base: [56, 34, 78], soil: [38, 24, 52], moss: [50, 110, 64], mossRift: [50, 110, 64], rim: [190, 140, 180], key: [255, 206, 140], bounce: [90, 50, 130] }
      : { dark: [6, 3, 18], base: [100, 58, 196], soil: [78, 42, 104], moss: rw > 0.5 ? [160, 80, 180] : [118, 96, 235], mossRift: [180, 70, 150], rim: [245, 212, 205], key: [255, 206, 140], bounce: [120, 80, 230] };
    const veins = corrupt ? { th: 0.12, patch: 150, scale: 55, width: 0.03, alpha: 0.8, glow: 3, glowK: 0.8, color: () => GREEN, region: (X, Y, yn) => (X < 2975 ? 1 : 0.4) * smooth(0.12, 0.4, yn) } : null;
    const M = K.mass({
      polys, poly: shapes[0].poly, seed: I.seed, pad: 12, openTop: true, openTopMax: 70, bevel: 9, dome: 110, domeK: 0.8, bump: 4, bumpScale: 30, flutes: 10, facet: corrupt ? 70 : 120, facetTilt: corrupt ? 0.3 : 0.16, crackW: 1.5, crack: corrupt ? 0.3 : 0.12,
      cyl: { cx: (I.xL + I.xR) / 2, hw: (I.xR - I.xL) / 2, k: 0.55, down: 0.5 },
      strata: { period: 22, lw: 0.1, dark: 0.3, warp: 8, wl: 110, tilt: 0.03 }, pal, veins,
      soil: 30, moss: 12, amb: corrupt ? 0.05 : 0.07, gamma: 1.5, rimW: 3, rimK: corrupt ? 0.35 : 1.0, keyK: corrupt ? 0.32 : 0.75, bounceK: 0.5, ao: 0.55, yTop, yBot,
      riftW: (X) => riftW(X), riftRimK: corrupt ? 0.2 : 0.7, ...WARM, ...(corrupt ? { warm: 0.4 } : {}),
    });
    b.drawImage(M.c, M.x, M.y); if (M.e) e.drawImage(M.e, M.x, M.y); chk.drawImage(M.c, M.x, M.y);
    if (corrupt) {
      // the outcrop's green light on every up-facing edge, the rift's crimson on the left-facing ones
      dirRim(e, M, UP_OUTCROP, 4, GREEN, 0.95, { glow: 5, glowK: 0.7, seed: I.seed });
      dirRim(e, M, [-1, -0.25], 3, [255, 46, 99], 0.5, { glow: 3, glowK: 0.5, seed: I.seed + 1 });
    }
    if (I.shape === 'arch') { // the fall's light on the arch intrados
      const nh = Math.max(14, F.s * 0.3), c2 = fallCol(F.x, false);
      e.save(); poly(e, shapes[0].poly); e.clip(); e.filter = 'blur(6px)'; e.strokeStyle = col(c2, 0.55); e.lineWidth = 9; e.beginPath();
      for (let d = -92; d <= 92; d += 2) { const x = F.x + d, y = Math.abs(d) <= nh ? F.y : F.y + 128 * (1 - Math.sqrt(1 - (d / 92) * (d / 92))); d === -92 ? e.moveTo(x, y + 60) : e.lineTo(x, y); }
      e.lineTo(F.x + 92, F.y + 190); e.stroke(); e.restore();
    }
    if (I.shape === 'twin') { // light leaking up the crack from the lip
      const XC = I.crack; e.save(); e.filter = 'blur(4px)';
      const g = e.createLinearGradient(0, topY(XC - 30), 0, F.y); g.addColorStop(0, col([205, 180, 255], 0)); g.addColorStop(0.5, col([205, 180, 255], 0.35)); g.addColorStop(1, col([222, 204, 255], 0.6));
      e.strokeStyle = g; e.lineWidth = 4; e.beginPath(); e.moveTo(XC, shapes[0].topY(XC) - 4); e.lineTo(XC - 2, (shapes[0].topY(XC) + F.y) / 2); e.lineTo(F.x, F.y); e.stroke(); e.restore();
    }
    // crystal seams spreading up from the lip into the rock: the light comes from inside the island
    if (F) {
      const sc = corrupt ? GREEN : mixc([200, 130, 255], [255, 60, 110], rw), shapeL = shapes.find(S => F.x >= S.top[0][0] && F.x <= S.top[S.top.length - 1][0]) || shapes[0];
      K.seams(b, e, shapeL.poly, F.x, F.y - 6, { seed: I.seed + 77, n: 3, dir: -Math.PI / 2, fan: 1.6, len: (F.y - shapeL.topY(F.x)) * 0.55, w: 1.6, color: sc, glow: 3, a: 0.7, branch: 0.06 });
    }
    if (corrupt) {
      const S1 = shapes[0], yb1 = Math.max(...S1.under.map(p => p[1]));
      fracture(b, e, S1.poly, [[2833, 1528], [2826, 1490], [2838, 1458], [2818, 1420], [2826, 1392], [2808, 1356], [2814, 1330]], 6);
      K.seams(b, e, S1.poly, 3170, 1400, { seed: I.seed + 79, n: 3, dir: -Math.PI / 2, fan: 1.6, len: 120, w: 1.6, color: [255, 46, 99], glow: 4 });
    }
    // hanging roots and vines from the underside (never across the fall)
    const under = [].concat(...shapes.map(S => S.under.filter(p => (!F || Math.abs(p[0] - F.x) > F.s * 1.1) && p[1] - S.topY(p[0]) > (I.thick || 40) * 0.9)));
    for (let k = 0; k < I.roots; k++) {
      const p = under[Math.floor(R() * under.length)]; if (!p) break;
      const depth = p[1] - topY(p[0]), len = 24 + R() * (30 + depth * 0.8), wd = 2 + R() * 3.5;
      const bulb = R() < (corrupt ? 0.45 : 0.3) ? (corrupt ? GREEN : mixc([120, 220, 255], [255, 80, 130], rw)) : null;
      const ro = { twigs: R() < 0.5 ? 1 : 0, bulb, color: [12, 7, 26], rim: corrupt ? [120, 255, 150] : mixc([170, 140, 255], [255, 90, 130], rw * 0.6) };
      K.root(b, e, p[0], p[1] - 5, len, wd, I.seed * 31 + k, ro); K.root(chk, null, p[0], p[1] - 5, len, wd, I.seed * 31 + k, ro);
      if (R() < 0.3) { const q = under[Math.floor(R() * under.length)]; K.vine(b, e, q[0], q[1] - 4, 50 + R() * 90, I.seed * 57 + k, { w: 1.5, leafLen: 8, leaf: [30, 18, 60], bud: R() < 0.5 ? (corrupt ? GREEN : rw > 0.5 ? [255, 90, 150] : [150, 230, 255]) : null }); }
    }
    // small crystals flanking the lip (the light's source), angled away from the fall
    if (F) {
      const fc = corrupt ? [110, 255, 140] : mixc([200, 160, 255], [255, 90, 150], rw);
      const uY = x => { let y = -1e9; for (const S of shapes) if (x >= S.under[S.under.length - 1][0] && x <= S.under[0][0]) y = Math.max(y, S.underY(x)); return y; };
      for (const side of [-1, 1]) for (let k = 0; k < 2; k++) {
        const x = F.x + side * (F.s * (0.42 + k * 0.28) + R() * 6), y = uY(x) - 4;
        if (y < -1e8) continue;
        K.crystal(b, e, x, y, 10 + R() * 16 - k * 3, 4 + R() * 3, Math.PI + side * (0.35 + R() * 0.3), fc, 1, 0.8);
      }
    }
    // top: ruin, grass, flowers, glowing moss line, crystals, tiny trees
    if (I.ruin) ruin(b, e, chk, shapes[0], I);
    for (const [x, n, size, c] of I.crystals) K.crystals(b, e, x, topY(x) + 5, n, size, c, I.seed * 13 + x, { glow: corrupt ? 0.95 : 0.75, fan: corrupt ? 1.4 : 0.9 });
    for (const [x, h, kind, lean] of I.trees) {
      const glow = corrupt ? [GREEN] : rw > 0.5 ? [[255, 80, 130], [255, 150, 90]] : [[255, 201, 60], [95, 224, 255], [255, 120, 200]];
      for (const q of [b, e]) { q.save(); if (lean) { q.translate(x, topY(x) + 3); q.rotate(lean); q.translate(-x, -topY(x) - 3); } }
      K.tree(b, e, x, topY(x) + 3, h, I.seed * 17 + x, { kind, bark: [18, 10, 36], leaf: [40, 26, 84], rim: rw > 0.5 ? [255, 150, 190] : [205, 180, 255], glow });
      b.restore(); e.restore();
    }
    for (const S of shapes) {
      const topPts = S.top.slice(2, -2).filter(p => !I.crack || Math.abs(p[0] - I.crack) > 18);
      K.grass(b, e, topPts, I.seed + 5, { density: 1.8, h: 12, color: corrupt ? [34, 26, 50] : [50, 32, 100], moss: corrupt ? [90, 200, 110] : rw > 0.5 ? [230, 100, 170] : [160, 140, 255], flowers: Math.round((S.top[S.top.length - 1][0] - S.top[0][0]) / 55),
        flowerCols: corrupt ? [GREEN, [255, 46, 99]] : rw > 0.5 ? [[255, 80, 140], [255, 150, 90], [232, 70, 190]] : [[255, 120, 200], [120, 230, 255], [255, 220, 120], [190, 140, 255]],
        mossLine: corrupt ? [120, 255, 150] : rw > 0.5 ? [255, 110, 170] : [175, 150, 255], mossA: 0.8, mossDy: 5 });
    }
    if (corrupt) paintCorrupt(I, b, e, chk, shapes, topY, R);
    // floating debris around the island (the corrupted one has its own torn-off fragments)
    if (!corrupt) for (let k = 0; k < 5; k++) {
      const side = R() < 0.5 ? -1 : 1, x = (side < 0 ? I.xL : I.xR) + side * (10 + R() * 100), y = yTop + 60 + R() * (yBot - yTop) * 0.8, sz = 8 + R() * 26;
      if (CFG.hard.some(z => K.inEllipse(x, y, z, sz + 16))) continue; // debris never drifts into a keep-clear zone
      const P = K.rock({ cx: x, cy: y, w: sz * 1.3, h: sz, seed: I.seed * 3 + k, corners: 7, taper: 0.5, jitter: 0.3 });
      const m = K.mass({ poly: P, seed: I.seed * 3 + k, pad: 6, bevel: 4, dome: sz * 0.5, domeK: 0.8, bump: 2, facet: 12, facetTilt: 0.4, pal: { dark: [8, 4, 20], base: [92, 64, 160], rim: [225, 200, 255] }, amb: 0.1, rimW: 2, rimK: 0.9, riftW: X => riftW(X), ...WARM, warmW: 2 });
      b.drawImage(m.c, m.x, m.y); if (m.e) e.drawImage(m.e, m.x, m.y); chk.drawImage(m.c, m.x, m.y);
    }
    return shapes[0];
  }

  // G's corruption: green glitch shards (hard slabs with an RGB-split edge) rising from cracks, rock torn off the top
  // and lifted toward the outcrop, a few scanline glitches, and the light those crystals throw into the air around them
  function paintCorrupt(I, b, e, chk, shapes, topY, R) {
    const S1 = shapes[0];
    for (const [x, y, s, a] of I.fragments) {
      const P = rot(K.rock({ cx: x, cy: y, w: s * 1.6, h: s, seed: I.seed * 5 + x, corners: 6, taper: 0.25, flat: 0.3, jitter: 0.35, spike: [s * 0.1, s * 0.55] }), x, y, a);
      const m = K.mass({ poly: P, seed: I.seed * 5 + x, pad: 8, bevel: 4, dome: s * 0.5, domeK: 0.8, bump: 2, facet: 14, facetTilt: 0.45, crack: 0.3,
        pal: { dark: [5, 3, 12], base: [70, 42, 100], rim: [200, 150, 190] }, amb: 0.06, rimW: 2, rimK: 0.4, riftW: X => riftW(X), riftRimK: 0.2, warm: 0.4, warmW: 2 });
      b.drawImage(m.c, m.x, m.y); if (m.e) e.drawImage(m.e, m.x, m.y); chk.drawImage(m.c, m.x, m.y);
      dirRim(e, m, UP_OUTCROP, 3, GREEN, 1, { glow: 4, glowK: 0.8, seed: x });
      blob(e, x, y + s * 0.2, s * 0.9, GREEN, 0.1);
      // the torn underside still glows where it broke away
      e.save(); e.filter = 'blur(2px)'; e.strokeStyle = col([150, 255, 170], 0.7); e.lineWidth = 1.6; e.beginPath(); e.moveTo(x - s * 0.5, y + s * 0.25); e.lineTo(x - s * 0.1, y + s * 0.45); e.lineTo(x + s * 0.35, y + s * 0.3); e.stroke(); e.restore();
    }
    // glitch shards on G1 and on the step
    const xs = [2632, 2718, 2756, 2860, 2934, 2958];
    xs.forEach((x, k) => {
      const y = topY(x) + 4, h = (k === 4 ? 70 : 30 + R() * 46), w = 8 + R() * 10, a = (R() - 0.5) * 0.5 + (k === 4 ? -0.25 : 0);
      const sh = [[-w / 2, 0], [-w / 2, -h * 0.78], [0, -h], [w / 2, -h * 0.7], [w / 2, 0]];
      b.save(); b.translate(x, y); b.rotate(a);
      b.save(); b.translate(2.5, 0); poly(b, sh); b.fillStyle = col([255, 46, 99], 0.45); b.fill(); b.restore();
      b.save(); b.translate(-2.5, 0); poly(b, sh); b.fillStyle = col([60, 220, 255], 0.3); b.fill(); b.restore();
      poly(b, sh); const g = b.createLinearGradient(0, 0, 0, -h); g.addColorStop(0, col([6, 40, 20])); g.addColorStop(1, col([80, 240, 110])); b.fillStyle = g; b.fill();
      b.restore();
      e.save(); e.translate(x, y); e.rotate(a); poly(e, sh); e.fillStyle = col(GREEN, 0.28); e.fill();
      e.strokeStyle = col([200, 255, 210], 0.8); e.lineWidth = 1.2; e.beginPath(); e.moveTo(-w / 2, -h * 0.78); e.lineTo(0, -h); e.stroke(); e.restore();
      blob(e, x, y - h * 0.55, h * 0.6, GREEN, 0.12);
    });
    // scanline glitches across the corrupted mass
    const yb1 = Math.max(...S1.under.map(p => p[1]));
    for (let k = 0; k < 4; k++) { const y = S1.topY(2780) + 10 + R() * (yb1 - S1.topY(2780)) * 0.7, x = 2610 + R() * 300; e.fillStyle = col(R() < 0.65 ? GREEN : [255, 46, 99], 0.28); e.fillRect(x, y, 26 + R() * 70, 1.5 + R() * 2); }
    // the crystals' light in the air over the island (small and local: the rock itself stays dark)
    blob(e, 2792, topY(2792) - 34, 120, GREEN, 0.07);
  }

  LAYERS.mid = async function () {
    const t0 = performance.now();
    const base = mk(W, H), b = cx2(base), emis = mk(W, H), e = cx2(emis), chkC = mk(W, H), chk = cx2(chkC);
    for (const q of [b, e, chk]) q.translate(OX, OY);
    const area = { x0: -OX, y0: -OY, w: W, h: H };   // the mist covers the whole layer, margin strips included
    // mist that must stay under 0.3 inside the hard zones
    const cap = (X, Y) => { for (const z of CFG.hard) if (K.inEllipse(X, Y, z, 30)) return 0.26; return 1; };
    // back cloud banks (behind the islands): billowy, lit on top from the upper left
    K.cloudBank(b, { ...area, seed: 11, lit: [215, 195, 255], shade: [52, 36, 112], blur: 5, litK: 5, cap,
      bands: [{ y: 1330, h: 120, a: 0.28, sx: 380, sy: 90, th: 0.25, wob: 50, fall: 0.2 }, { y: 1640, h: 200, a: 0.45, sx: 460, sy: 110, th: 0.15, wob: 70 }, { y: 1900, h: 260, a: 0.6, sx: 520, sy: 130, th: 0.05, wob: 90 }] });
    // faint high veils near the top islands
    K.mistBand(b, { ...area, seed: 12, color: [175, 155, 240], blur: 10, cap,
      bands: [{ y: 430, h: 80, a: 0.14, sx: 500, sy: 70, th: 0.2, wob: 50 }, { y: 820, h: 60, a: 0.1, sx: 450, sy: 60, th: 0.25, wob: 40 }] });
    // islands
    for (const I of ISLES) paintIsland(I, b, e, chk);
    // light-falls from the lightfall anchors
    CFG.falls.forEach(([x, y, s, len], i) => {
      const I = ISLES.find(q => q.fall === i);
      K.lightfall(b, e, x, y, s, len, fallCol(x, I && I.corrupt), 900 + i, { spread: 2.5, mist: I && I.corrupt ? [190, 255, 210] : mixc([205, 190, 255], [255, 170, 205], riftW(x)) });
    });
    // front cloud banks: the lowest bank rolls over the island bottoms and the light-fall mist
    // (the last band rolls on under the design frame to the bottom of the margin strip: its fade starts past the layer)
    K.cloudBank(b, { ...area, seed: 13, lit: [220, 200, 255], shade: [50, 34, 108], blur: 4, litK: 5, cap,
      bands: [{ y: 1790, h: 140, a: 0.32, sx: 360, sy: 80, th: 0.3, wob: 60, fall: 0.2 }, { y: 2040, h: 240, a: 0.7, sx: 520, sy: 120, th: 0.05, wob: 80 },
        { y: 2330, h: 260, a: 0.72, sx: 520, sy: 120, th: 0.05, wob: 80, fall: 1.05 }] });
    // keep-clear check: island mass (not mist, not light) must stay out of the hard zones
    // every light-fall must start at a rock lip: rock just above the anchor, open air just below it
    { const d = cx2(chkC, true).getImageData(0, 0, W, H).data, A = (x, y) => d[(Math.round(y + OY) * W + Math.round(x + OX)) * 4 + 3] / 255;
      const lips = CFG.falls.map(([x, y]) => [x, y, A(x, y - 4), A(x, y + 4)]).filter(q => q[2] < 0.5 || q[3] > 0.5);
      console.log('mid light-fall lips:', lips.length ? 'MISPLACED ' + JSON.stringify(lips) : 'all 7 at their anchors'); }
    const zm = K.zoneMax(chkC, toCanvas(CFG.hard), 0), bad = Object.entries(zm).filter(([, v]) => v > 0.02);
    console.log('mid hard-zone island alpha max:', bad.length ? JSON.stringify(bad) : 'clear');
    const fr = { splitX: CFG.splitX + OX, fade: CFG.fade, hy0: OY, hh: H0 };   // the atmosphere runs in canvas px
    const lit = window.__islandsNoAtmosphere ? K.atmosphere(base, emis, { atm: { ...CFG.atm, haze: 0, hazeBottom: 0, saturation: 1, contrast: 1, blur: 0, maxLuma: 1, emissiveMax: 1 }, ...fr }) : K.atmosphere(base, emis, { atm: CFG.atm, ...fr });
    const zm2 = K.zoneMax(lit, toCanvas(CFG.hard), 0);
    console.log('mid hard-zone total alpha max (mist/light allowed < 0.3):', Math.max(...Object.values(zm2)).toFixed(3), JSON.stringify(Object.entries(zm2).filter(([, v]) => v >= 0.3)));
    const out = K.downsample(lit, Math.round(W * CFG.res), Math.round(H * CFG.res));
    console.log('mid', out.width + 'x' + out.height, Math.round(performance.now() - t0) + ' ms');
    window.__last = out;
    return out;
  };
})();
