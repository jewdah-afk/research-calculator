// Parallax depth 4, `near` (f = 0.7): big floating rocks passing close behind the world. Eight chunky, faceted rocks
// (earth chunks with moss and hanging roots, bare boulders with crystal clusters, crimson-veined shards on the rift
// side, a corrupted green shard by the outcrop), rim-lit from the upper left, slightly out of focus. They sit at the
// edges of the typical views so they frame the tree instead of covering nodes: every hard keep-clear zone stays
// fully empty (alpha 0) and every soft zone below 0.35. Most of the layer is transparent (most tiles get dropped).
// Painted at full local size 3800x2752, output at res.HIGH 0.5 -> 1900x1376 (realm.json layers[near]).
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
      b.drawImage(upBlur(c, w * q, h * q, o.blur || 5), 0, 0);
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
      b.drawImage(upBlur(c, w * q, h * q, o.blur || 6), 0, 0);
    }

    // ---------------------------------------------------------------- the atmosphere pass (REALM.md section 4)
    // base: colour art; emis: light that may exceed maxLuma (up to emissiveMax). Both get the same colour recipe;
    // the light is then screened over the base (premultiplied), the luma limit follows the local emissive share,
    // and the whole layer gets a premultiplied gaussian blur of `blur` local px (edges clamped, see padBlur).
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

  // ---- contract snapshot (realm.json layers[near]); repaint if `node camera.js --build` changes it
  // blur 0.9 (was 2.5): this plane sits between mid and the focal world, so it must be sharper than mid (1.5) and far (3)
  const CFG = {
    size: [3800, 2752], res: 0.5, splitX: 2271, fade: 375,
    atm: { hazeColor: [42, 28, 90], hazeRift: [80, 20, 50], haze: 0.15, hazeBottom: 0.2, saturation: 0.9, contrast: 0.85, blur: 0.9, maxLuma: 0.6, emissiveMax: 0.8 },
    hard: [['m', 1606, 1826.8, 162, 183], ['mm', 1382, 1868.8, 162, 183], ['em', 1830, 1868.8, 162, 183], ['p', 1606, 1602.8, 162, 183], ['pe', 1284, 1406.8, 162, 183], ['sp', 1487, 1371.8, 162, 183], ['pb', 1725, 1371.8, 162, 183], ['pp', 1928, 1406.8, 162, 183], ['se', 1361, 1182.8, 162, 183], ['hp', 1606, 1147.8, 162, 183], ['ep', 1851, 1182.8, 162, 183], ['hb', 1382, 958.8, 162, 183], ['ap', 1606, 923.8, 162, 183], ['mp', 1830, 958.8, 162, 183], ['t', 1606, 720.8, 162, 183], ['pm', 2761, 1588.8, 162, 183], ['pep', 2509, 1322.8, 162, 183], ['cr', 3013, 1336.8, 162, 183], ['cm', 3139, 1147.8, 162, 183], ['ex', 2761, 1042.8, 162, 183], ['ach', 920, 916.8, 162, 183]],
    softR: [248, 232], // soft zones: same centres, rx x ry
  };
  const [W, H] = CFG.size;
  const K = KIT, { mk, cx2, col, mixc } = K;
  const riftW = x => smooth(CFG.splitX - CFG.fade, CFG.splitX + CFG.fade, x);
  const SOFT = CFG.hard.map(z => [z[0], z[1], z[2], CFG.softR[0], CFG.softR[1]]);

  // kind: 'earth' (a mini-island: flat mossy top, roots, a lumpy hanging belly), 'boulder' (rounded and faceted, crystal
  // cluster underneath), 'slab' (a tipped flat shard), 'shard' (tall, veined). tilt rotates the whole silhouette (rad).
  // subs: fused chunks [dx, dy, w, h] as fractions of the rock; earth chunks hang under the belly (no side shelf),
  // boulder chunks fuse on top as a second rounded lump.
  const ROCKS = [
    { id: 'N1', kind: 'earth', cx: 470, cy: 1960, w: 780, h: 480, seed: 501, corners: 11, taper: 0.55, flat: 0.9, tilt: 0.05, spike: [30, 90],
      subs: [[-0.1, 0.34, 0.34, 0.6], [0.2, 0.26, 0.24, 0.5]], crystals: [[250, -1, 5, 70, [179, 92, 255]]] },
    { id: 'N2', kind: 'boulder', cx: 385, cy: 520, w: 470, h: 390, seed: 502, corners: 15, taper: 0.16, flat: 0.05, boxy: 2.0, jitter: 0.1, tilt: -0.32,
      subs: [], crystals: [[520, 0.2, 6, 80, [95, 224, 255]]] },
    { id: 'N3', kind: 'slab', cx: 1240, cy: 318, w: 560, h: 190, seed: 503, corners: 8, taper: 0.3, flat: 0, boxy: 2.8, jitter: 0.16, tilt: 0.21,
      subs: [], crystals: [[1010, 0.1, 4, 60, [179, 92, 255]]] },
    { id: 'N9', kind: 'earth', cx: 2480, cy: 560, w: 600, h: 320, seed: 509, corners: 10, taper: 0.5, flat: 0.8, tilt: -0.08, spike: [-20, 70],
      subs: [[0.12, 0.36, 0.32, 0.6]], crystals: [[2660, -1, 5, 64, [255, 46, 99]]] },
    { id: 'N5', kind: 'earth', cx: 2660, cy: 2090, w: 740, h: 430, seed: 505, corners: 11, taper: 0.55, flat: 0.85, tilt: 0.06, spike: [40, 100],
      subs: [[-0.16, 0.3, 0.3, 0.55], [0.18, 0.36, 0.22, 0.48]], crystals: [[2430, -1, 6, 76, [232, 70, 190]]] },
    { id: 'N4', kind: 'shard', cx: 3640, cy: 1240, w: 420, h: 680, seed: 504, corners: 8, taper: 0.5, flat: 0.1, boxy: 2.2, tilt: 0.2, corrupt: true,
      subs: [], crystals: [[3520, -1, 6, 90, [57, 255, 20]]] },
    { id: 'N6', kind: 'boulder', cx: 1700, cy: 2410, w: 740, h: 400, seed: 506, corners: 16, taper: 0.2, flat: 0.1, boxy: 2.1, jitter: 0.1, tilt: 0.1,
      subs: [[0.34, -0.14, 0.42, 0.6]], crystals: [[1960, 0.5, 4, 56, [95, 224, 255]]] },
    { id: 'N7', kind: 'shard', cx: 2290, cy: 1740, w: 170, h: 240, seed: 507, corners: 7, taper: 0.7, flat: 0.3, boxy: 2.0, tilt: -0.42, spike: [10, 70],
      subs: [], crystals: [[2290, -1, 3, 46, [255, 46, 99]]] },
  ];
  // true when a hanging tip at (x, y) would reach into a hard zone (+40 px) or deep into a soft one
  const clearOf = (x, y) => CFG.hard.some(z => K.inEllipse(x, y, z, 40)) || SOFT.some(z => K.inEllipse(x, y, z, -60));
  const rot = (pts, cx, cy, a) => { const c = Math.cos(a), s2 = Math.sin(a); return pts.map(([x, y]) => [cx + (x - cx) * c - (y - cy) * s2, cy + (x - cx) * s2 + (y - cy) * c]); };

  // top and bottom silhouette lines of a mass (every 3 px)
  function lines(M) {
    const top = [], bot = [];
    for (let x = 2; x < M.w - 2; x += 3) {
      let y0 = -1, y1 = -1;
      for (let y = 0; y < M.h; y++) if (M.A[y * M.w + x] >= 0.5) { if (y0 < 0) y0 = y; y1 = y; }
      if (y0 >= 0) { top.push([M.x + x, M.y + y0]); bot.push([M.x + x, M.y + y1]); }
    }
    return { top, bot };
  }

  function paintRock(Rk, b, e) {
    const r = rng(Rk.seed * 11 + 3), rw = riftW(Rk.cx), corrupt = !!Rk.corrupt;
    const tilt = Rk.tilt || 0, round = Rk.kind === 'boulder';
    const P = rot(K.rock({ cx: Rk.cx, cy: Rk.cy, w: Rk.w, h: Rk.h, seed: Rk.seed, corners: Rk.corners, taper: Rk.taper, flat: Rk.flat, jitter: Rk.jitter || 0.2, boxy: Rk.boxy || 3.2, spike: Rk.spike }), Rk.cx, Rk.cy, tilt);
    // fused chunks: hanging lobes under an earth belly, a second rounded lump on a boulder
    const polys = [P];
    (Rk.subs || []).forEach(([dx, dy, fw, fh], k) => {
      const sw = Rk.w * fw, sh = Rk.h * fh, hang = dy > 0;
      polys.push(rot(K.rock({ cx: Rk.cx + dx * Rk.w, cy: Rk.cy + dy * Rk.h, w: sw, h: sh, seed: Rk.seed * 7 + k, corners: round ? 12 : 7, taper: hang ? 0.65 : 0.2,
        flat: round ? 0.05 : 0.2, jitter: round ? 0.12 : 0.28, boxy: round ? 2.0 : 2.4, spike: hang ? [(r() - 0.5) * sw * 0.2, sh * (0.3 + r() * 0.35)] : null }), Rk.cx, Rk.cy, tilt));
    });
    const earth = Rk.kind === 'earth', fs = Math.min(Rk.w, Rk.h);
    const M = K.mass({
      polys, poly: P, seed: Rk.seed, pad: 14, openTop: earth, openTopMax: 90, bevel: 14, dome: fs * 0.4, domeK: 0.75, bump: 6, bumpScale: 36,
      flutes: earth ? 12 : round ? 0 : 5, facet: fs * (Rk.kind === 'shard' ? 0.3 : round ? 0.26 : 0.34), facetTilt: round ? 0.3 : Rk.kind === 'slab' ? 0.36 : 0.32, crackW: 3, crack: round ? 0.25 : 0.35,
      cyl: { cx: Rk.cx, hw: Rk.w / 2, k: round ? 0.6 : 0.45, down: earth ? 0.45 : 0.25 },
      strata: earth ? { period: 30, lw: 0.08, dark: 0.3, warp: 10, wl: 140, tilt: 0.04 } : null,
      pal: { dark: [2, 1, 8], base: [34, 18, 74], soil: [24, 12, 40], moss: rw > 0.5 ? [96, 36, 104] : [56, 44, 140], mossRift: [110, 34, 96], rim: [215, 195, 255], key: [255, 196, 160], bounce: [110, 70, 220] },
      soil: earth ? 34 : 0, moss: earth ? 14 : round ? 9 : 0, amb: 0.03, gamma: 2.0, rimW: 5, rimK: 1.2, keyK: 0.34, bounceK: 0.45, ao: 0.55, riftW: (X) => riftW(X), riftRimK: 0.8,
      warm: 1, warmW: 4,
    });
    b.drawImage(M.c, M.x, M.y); if (M.e) e.drawImage(M.e, M.x, M.y);
    const L = lines(M), top = L.top, bot = L.bot.filter(p => p[1] > Rk.cy);
    // seams: crystal veins through the rock
    const vc = corrupt ? [57, 255, 20] : mixc(r() < 0.5 ? [180, 110, 255] : [95, 200, 255], [255, 60, 110], rw);
    const src = bot[Math.floor(bot.length * (0.3 + r() * 0.4))] || [Rk.cx, Rk.cy];
    K.seams(b, e, P, src[0], src[1] - 8, { seed: Rk.seed + 5, n: Rk.kind === 'shard' ? 4 : 2, dir: -Math.PI / 2 - 0.3, fan: 1.6, len: Rk.h * 0.55, w: 3, color: vc, glow: 6, jit: 0.45, branch: 0.12, a: 0.85 });
    if (corrupt) K.seams(b, e, P, Rk.cx + Rk.w * 0.15, Rk.cy + Rk.h * 0.2, { seed: Rk.seed + 6, n: 2, dir: -Math.PI / 2, fan: 1.6, len: Rk.h * 0.45, w: 2.4, color: [255, 46, 99], glow: 5, jit: 0.45 });
    // hanging roots and vines under earth chunks, crystals under boulders
    if (earth) {
      for (let k = 0; k < 16; k++) {
        const p = bot[Math.floor(r() * bot.length)]; if (!p) break;
        let len = 50 + r() * r() * 280; const wd = 6 + r() * 8;
        while (len > 40 && clearOf(p[0], p[1] + len)) len *= 0.8;
        K.root(b, e, p[0], p[1] - 8, len, wd, Rk.seed * 31 + k, { twigs: r() < 0.6 ? 2 : 0, color: [6, 3, 14], rim: mixc([120, 100, 200], [200, 70, 110], rw * 0.7), bulb: r() < 0.25 ? mixc([130, 220, 255], [255, 80, 130], rw) : null });
      }
      for (let k = 0; k < 5; k++) { const p = bot[Math.floor(r() * bot.length)]; let vl = 110 + r() * 220; if (p) while (vl > 60 && clearOf(p[0], p[1] + vl)) vl *= 0.8; if (p) K.vine(b, e, p[0], p[1] - 6, vl, Rk.seed * 57 + k, { w: 4, leafLen: 22, color: [10, 5, 22], leaf: [18, 10, 40], leafRim: [110, 90, 190], bud: r() < 0.6 ? (rw > 0.5 ? [255, 90, 150] : [150, 230, 255]) : null }); }
      const tp = top.filter(p => p[1] < Rk.cy - Rk.h * 0.1);
      K.grass(b, e, tp, Rk.seed + 5, { density: 1.2, h: 18, w: 1.8, color: [20, 12, 44], moss: rw > 0.5 ? [150, 60, 120] : [90, 76, 190], flowers: Math.round(tp.length / 14),
        flowerCols: rw > 0.5 ? [[255, 80, 140], [255, 150, 90]] : [[255, 120, 200], [120, 230, 255], [255, 220, 120]], mossLine: rw > 0.5 ? [255, 110, 170] : [175, 150, 255], mossA: 0.6 });
      // one or two small bushes / a young tree
      for (let k = 0; k < 2; k++) { const p = tp[Math.floor(tp.length * (0.25 + 0.5 * r()))]; if (p) K.tree(b, e, p[0], p[1] + 4, 90 + r() * 70, Rk.seed * 17 + k, { kind: rw > 0.6 ? 'dead' : null, bark: [10, 5, 22], leaf: [30, 18, 64], rim: rw > 0.5 ? [255, 150, 190] : [210, 185, 255], glow: rw > 0.5 ? [[255, 80, 130]] : [[255, 201, 60], [95, 224, 255]], glowN: 1 }); }
    } else {
      for (let k = 0; k < 4; k++) { const p = bot[Math.floor(r() * bot.length)]; if (p) K.crystal(b, e, p[0], p[1] - 6, 26 + r() * 40, 9 + r() * 8, Math.PI + (r() - 0.5) * 0.8, vc, 1, 0.7); }
      for (let k = 0; k < 3; k++) { const p = bot[Math.floor(r() * bot.length)]; let rl = 40 + r() * 110; if (p) while (rl > 30 && clearOf(p[0], p[1] + rl)) rl *= 0.8; if (p) K.root(b, e, p[0], p[1] - 6, rl, 5 + r() * 5, Rk.seed * 41 + k, { color: [6, 3, 14], rim: [120, 100, 200] }); }
    }
    // crystal clusters growing out of the rock: [x, side (-1 top, 0..1 fraction up the left/right), n, size, colour]
    for (const [x, where, n, size, c] of Rk.crystals || []) {
      if (where < 0) { const p = top.reduce((a, q) => Math.abs(q[0] - x) < Math.abs(a[0] - x) ? q : a, top[0]); K.crystals(b, e, p[0], p[1] + 8, n, size, c, Rk.seed * 13 + x, { glow: 0.8, fan: corrupt ? 1.5 : 1 }); }
      else { const p = bot.reduce((a, q) => Math.abs(q[0] - x) < Math.abs(a[0] - x) ? q : a, bot[0] || [x, Rk.cy]); K.crystals(b, e, p[0], p[1] - 10, n, size, c, Rk.seed * 13 + x, { glow: 0.8, dir: Math.PI, fan: 1.1 }); }
    }
    // corrupted: RGB-split glitch slabs and scanlines
    if (corrupt) {
      for (let k = 0; k < 5; k++) {
        const p = top[Math.floor(top.length * (0.15 + 0.7 * r()))]; if (!p) continue;
        const h = 60 + r() * 110, w = 14 + r() * 18, a = (r() - 0.5) * 0.5, sh = [[-w / 2, 0], [-w / 2, -h * 0.78], [0, -h], [w / 2, -h * 0.7], [w / 2, 0]];
        b.save(); b.translate(p[0], p[1] + 8); b.rotate(a);
        b.save(); b.translate(4, 0); poly(b, sh); b.fillStyle = col([255, 46, 99], 0.5); b.fill(); b.restore();
        b.save(); b.translate(-4, 0); poly(b, sh); b.fillStyle = col([60, 220, 255], 0.35); b.fill(); b.restore();
        poly(b, sh); const g = b.createLinearGradient(0, 0, 0, -h); g.addColorStop(0, col([8, 50, 24])); g.addColorStop(1, col([80, 240, 110])); b.fillStyle = g; b.fill();
        b.restore();
        e.save(); e.translate(p[0], p[1] + 8); e.rotate(a); poly(e, sh); e.fillStyle = col([57, 255, 20], 0.28); e.fill(); e.restore();
      }
      for (let k = 0; k < 7; k++) { const y = Rk.cy - Rk.h * 0.3 + r() * Rk.h * 0.6, x = Rk.cx - Rk.w * 0.4 + r() * Rk.w * 0.6; e.fillStyle = col(r() < 0.6 ? [57, 255, 20] : [255, 46, 99], 0.3); e.fillRect(x, y, 40 + r() * 100, 2 + r() * 3); }
    }
    // small debris drifting with the rock
    for (let k = 0; k < 5; k++) {
      const a = r() * Math.PI * 2, d = 0.62 + r() * 0.3, x = Rk.cx + Math.cos(a) * Rk.w * d, y = Rk.cy + Math.sin(a) * Rk.h * d * 0.9, sz = 14 + r() * 34;
      if (CFG.hard.some(z => K.inEllipse(x, y, z, 60)) || SOFT.some(z => K.inEllipse(x, y, z, 30))) continue;
      const Q = K.rock({ cx: x, cy: y, w: sz * 1.3, h: sz, seed: Rk.seed * 3 + k, corners: 7, taper: 0.5, jitter: 0.3 });
      const m = K.mass({ poly: Q, seed: Rk.seed * 3 + k, pad: 6, bevel: 5, dome: sz * 0.5, domeK: 0.8, bump: 2, facet: 14, facetTilt: 0.45, pal: { dark: [2, 1, 8], base: [34, 18, 74], rim: [215, 195, 255] }, amb: 0.03, gamma: 2, rimW: 2.5, rimK: 1.1, riftW: X => riftW(X), warm: 0.9, warmW: 2.5 });
      b.drawImage(m.c, m.x, m.y); if (m.e) e.drawImage(m.e, m.x, m.y);
    }
  }

  LAYERS.rocks = LAYERS.near = async function () {
    const t0 = performance.now();
    const base = mk(W, H), b = cx2(base), emis = mk(W, H), e = cx2(emis);
    for (const Rk of ROCKS) paintRock(Rk, b, e);
    // before the erase: a rock that reaches into a hard zone would get an elliptical bite; report it
    { const pre = K.zoneMax(base, CFG.hard, 14), bit = Object.entries(pre).filter(([, v]) => v > 0.02);
      console.log('near rocks reaching into hard zones (+14 px) before the erase:', bit.length ? JSON.stringify(bit) : 'none'); }
    const lit = window.__islandsNoAtmosphere ? K.atmosphere(base, emis, { atm: { ...CFG.atm, haze: 0, hazeBottom: 0, saturation: 1, contrast: 1, blur: 0, maxLuma: 1, emissiveMax: 1 }, splitX: CFG.splitX, fade: CFG.fade })
      : K.atmosphere(base, emis, { atm: CFG.atm, splitX: CFG.splitX, fade: CFG.fade });
    // After the atmosphere pass (so the emissive light and the blur are included): soft zones fade to <= 0.28 alpha with
    // a feathered edge (roots and vines recede into the haze); hard zones are erased with a margin for the downsample.
    { const lx = cx2(lit), m = mk(W, H), mx = cx2(m); mx.fillStyle = '#000'; mx.fillRect(0, 0, W, H); mx.globalCompositeOperation = 'destination-out';
      for (const z of SOFT) { mx.save(); mx.translate(z[1], z[2]); mx.scale(z[3] + 44, z[4] + 44); const g = mx.createRadialGradient(0, 0, 0, 0, 0, 1); g.addColorStop(0, 'rgba(0,0,0,0.72)'); g.addColorStop(0.9, 'rgba(0,0,0,0.72)'); g.addColorStop(1, 'rgba(0,0,0,0)'); mx.fillStyle = g; mx.beginPath(); mx.arc(0, 0, 1, 0, 7); mx.fill(); mx.restore(); }
      lx.save(); lx.globalCompositeOperation = 'destination-in'; lx.drawImage(m, 0, 0); lx.restore();
      lx.save(); lx.globalCompositeOperation = 'destination-out'; lx.fillStyle = '#000'; for (const z of CFG.hard) { lx.beginPath(); lx.ellipse(z[1], z[2], z[3] + 8, z[4] + 8, 0, 0, 7); lx.fill(); } lx.restore(); }
    const hz = K.zoneMax(lit, CFG.hard), sz = K.zoneMax(lit, SOFT);
    console.log('near hard zones max alpha (must be 0):', Math.max(...Object.values(hz)), ' soft zones max (< 0.35):', Math.max(...Object.values(sz)), JSON.stringify(Object.entries(sz).filter(([, v]) => v >= 0.35)));
    const out = K.downsample(lit, Math.round(W * CFG.res), Math.round(H * CFG.res));
    console.log('near (rocks)', out.width + 'x' + out.height, Math.round(performance.now() - t0) + ' ms');
    window.__last = out;
    return out;
  };
})();
