// kit.js - the shared 2D painters of the UI kit (canvas 2D in headless Chromium; loaded after art/lib.js and themes.js).
// The metal and set gems come from the Blender renders (blender/*); everything that has to stay flat, stretch in a
// 9-slice or carry a layer's own light is painted here: crystal fills lit from within, domes, panel / card bodies with
// inner shadow and inlay glow, carved stone, seamless textures, glitch / crack post for the corrupted layer, and the
// VFX sprites. All painters are seeded (lib.js rng), so a build is reproducible.
const KIT = (() => {
  const K = {};
  K.c = (h, a = 1) => rgba(hex(h), a);
  K.mixh = (a, b, t) => { const m = mix(hex(a), hex(b), t); return '#' + m.map(v => Math.round(v).toString(16).padStart(2, '0')).join(''); };
  K.path = (x, pts) => { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) x.lineTo(pts[i][0], pts[i][1]); x.closePath(); };
  K.bbox = pts => { let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); } return { x0, y0, x1, y1, w: x1 - x0, h: y1 - y0, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2 }; };
  K.rectPoly = (x0, y0, x1, y1, ch = 0) => ch ? [[x0 + ch, y0], [x1 - ch, y0], [x1, y0 + ch], [x1, y1 - ch], [x1 - ch, y1], [x0 + ch, y1], [x0, y1 - ch], [x0, y0 + ch]] : [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
  // offset a closed polygon (any winding) inward by d (mitred)
  K.inset = (pts, d) => {
    let a = 0; for (let i = 0; i < pts.length; i++) { const p = pts[i], q = pts[(i + 1) % pts.length]; a += p[0] * q[1] - q[0] * p[1]; }
    const s = a > 0 ? 1 : -1, n = pts.length, out = [];
    for (let i = 0; i < n; i++) {
      const A = pts[(i - 1 + n) % n], P = pts[i], B = pts[(i + 1) % n];
      let e0 = [P[0] - A[0], P[1] - A[1]], e1 = [B[0] - P[0], B[1] - P[1]];
      const l0 = Math.hypot(...e0) || 1, l1 = Math.hypot(...e1) || 1; e0 = [e0[0] / l0, e0[1] / l0]; e1 = [e1[0] / l1, e1[1] / l1];
      const n0 = [-e0[1] * s, e0[0] * s], n1 = [-e1[1] * s, e1[0] * s];
      const k = 1 + n0[0] * n1[0] + n0[1] * n1[1];
      out.push([P[0] + (n0[0] + n1[0]) / Math.max(k, 1e-3) * d, P[1] + (n0[1] + n1[1]) / Math.max(k, 1e-3) * d]);
    }
    return out;
  };
  K.scalePoly = (pts, k, ox = 0, oy = 0) => pts.map(([x, y]) => [x * k + ox, y * k + oy]);

  // ---------------------------------------------------------------------------------------------- noise (tileable)
  // periodic gradient noise: lattice wraps every `period` cells, so textures built from it tile seamlessly
  K.pnoise = (seed, period) => {
    const r = rng(seed), g = [];
    for (let i = 0; i < period * period; i++) { const a = r() * Math.PI * 2; g.push([Math.cos(a), Math.sin(a)]); }
    const G = (i, j) => g[((j % period + period) % period) * period + ((i % period + period) % period)];
    const f = t => t * t * t * (t * (t * 6 - 15) + 10);
    return (x, y) => {
      const X = Math.floor(x), Y = Math.floor(y), xf = x - X, yf = y - Y;
      const d = (i, j) => { const q = G(X + i, Y + j); return q[0] * (xf - i) + q[1] * (yf - j); };
      const u = f(xf), v = f(yf);
      return lerp(lerp(d(0, 0), d(1, 0), u), lerp(d(0, 1), d(1, 1), u), v) * 1.4;
    };
  };
  K.pfbm = (seed, period, oct = 4) => {
    const ns = []; for (let o = 0; o < oct; o++) ns.push(K.pnoise(seed + o * 101, period << o));
    return (x, y) => { let s = 0, a = 0.5, f = 1; for (let o = 0; o < oct; o++) { s += a * ns[o](x * f, y * f); f *= 2; a *= 0.5; } return s; };
  };
  // periodic voronoi over a w x h tile: returns per-pixel {cell id, f1, f2}
  K.voronoiTile = (w, h, n, seed) => {
    const r = rng(seed), P = [];
    for (let i = 0; i < n; i++) P.push([r() * w, r() * h, r()]);
    const id = new Int16Array(w * h), edge = new Float32Array(w * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      let d1 = 1e18, d2 = 1e18, best = 0;
      for (let i = 0; i < n; i++) for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) {
        const dx = x - (P[i][0] + ox * w), dy = y - (P[i][1] + oy * h), d = dx * dx + dy * dy;
        if (d < d1) { d2 = d1; d1 = d; best = i; } else if (d < d2) d2 = d;
      }
      id[y * w + x] = best; edge[y * w + x] = Math.sqrt(d2) - Math.sqrt(d1);
    }
    return { id, edge, P };
  };

  // ---------------------------------------------------------------------------------------------- compositing helpers
  K.canvas = (w, h) => canvas(Math.ceil(w), Math.ceil(h));
  K.withClip = (x, pts, fn) => { x.save(); K.path(x, pts); x.clip(); fn(); x.restore(); };
  // inner shadow of a polygon: a big frame outside it casts a blurred shadow inward (clipped to the polygon)
  K.innerShadow = (x, pts, color, blur, dx = 0, dy = 0) => {
    const b = K.bbox(pts), m = blur * 4 + 50;
    x.save(); K.path(x, pts); x.clip();
    x.shadowColor = color; x.shadowBlur = blur; x.shadowOffsetX = dx; x.shadowOffsetY = dy;
    x.beginPath(); x.rect(b.x0 - m, b.y0 - m, b.w + 2 * m, b.h + 2 * m);
    const q = pts.slice().reverse(); x.moveTo(q[0][0], q[0][1]); for (let i = 1; i < q.length; i++) x.lineTo(q[i][0], q[i][1]); x.closePath();
    x.fillStyle = '#000'; x.fill('evenodd');
    x.restore();
  };
  K.blurInto = (x, draw, blur, op = 'source-over', alpha = 1) => {
    const c = K.canvas(x.canvas.width, x.canvas.height), y = c.getContext('2d'); draw(y);
    x.save(); x.globalCompositeOperation = op; x.globalAlpha = alpha; x.filter = `blur(${blur}px)`; x.drawImage(c, 0, 0); x.restore();
  };
  K.glowStroke = (x, pts, color, width, blur, alpha = 1, op = 'lighter') => K.blurInto(x, y => { K.path(y, pts); y.strokeStyle = color; y.lineWidth = width; y.lineJoin = 'round'; y.stroke(); }, blur, op, alpha);

  // ---------------------------------------------------------------------------------------------- bodies
  // the panel / card body: base gradient, hue wash, faint grain, inner shadow and a hairline of inlay light inside the rim
  K.body = (x, pts, T, { wash = 0.12, shadow = 0.7, shadowBlur = 26, glow = 0.45, glowW = 2.5, grain = 0.05, seed = 1, warm = false } = {}) => {
    const b = K.bbox(pts);
    K.withClip(x, pts, () => {
      const g = x.createLinearGradient(0, b.y0, 0, b.y1);
      g.addColorStop(0, T.body[0]); g.addColorStop(0.45, T.body[1]); g.addColorStop(1, T.body[2]);
      x.fillStyle = g; x.fillRect(b.x0, b.y0, b.w, b.h);
      if (wash) {
        const r = x.createRadialGradient(b.x0 + b.w * 0.18, b.y0, 0, b.x0 + b.w * 0.18, b.y0, Math.max(b.w, b.h) * 0.9);
        r.addColorStop(0, K.c(T.wash, wash)); r.addColorStop(1, K.c(T.wash, 0));
        x.fillStyle = r; x.fillRect(b.x0, b.y0, b.w, b.h);
      }
      if (grain) {
        const R = rng(seed), img = x.getImageData(Math.floor(b.x0), Math.floor(b.y0), Math.ceil(b.w), Math.ceil(b.h)), d = img.data;
        for (let i = 0; i < d.length; i += 4) { const v = (R() - 0.5) * 255 * grain; d[i] += v; d[i + 1] += v; d[i + 2] += v; }
        x.putImageData(img, Math.floor(b.x0), Math.floor(b.y0));
      }
    });
    if (shadow) K.innerShadow(x, pts, `rgba(0,0,0,${shadow})`, shadowBlur);
    if (glow) K.withClip(x, pts, () => K.glowStroke(x, K.inset(pts, 1), K.c(T.hue, 1), glowW * 2, glowW * 2.2, glow));
  };

  // a crystal plate lit from within (tabs, buttons): vertical light, big crystalline facets, a lit top edge, a glossy
  // streak and a few sparkles; the gold frame is drawn over it
  K.crystalPlate = (x, pts, hueHex, { seed = 3, bright = 1, facets = 7, streak = true, sparkles = 3, deep = 0.62 } = {}) => {
    const b = K.bbox(pts), R = rng(seed), H = hex(hueHex);
    K.withClip(x, pts, () => {
      const g = x.createLinearGradient(0, b.y0, 0, b.y1);
      g.addColorStop(0, rgba(mix(H, [255, 255, 255], 0.55 * bright), 1));
      g.addColorStop(0.22, rgba(mix(H, [255, 255, 255], 0.18 * bright), 1));
      g.addColorStop(0.55, rgba(H, 1));
      g.addColorStop(1, rgba(mix(H, [0, 0, 0], deep), 1));
      x.fillStyle = g; x.fillRect(b.x0, b.y0, b.w, b.h);
      // facets: wedges between points on the top and bottom edges, alternately lit / shadowed
      const xs = [b.x0 - b.h]; for (let i = 1; i < facets; i++) xs.push(b.x0 + b.w * (i / facets) + (R() - 0.5) * b.w / facets * 0.8); xs.push(b.x1 + b.h);
      for (let i = 0; i < xs.length - 1; i++) {
        const t0 = xs[i], t1 = xs[i + 1], sk = (R() - 0.5) * b.h * 1.2;
        x.beginPath(); x.moveTo(t0, b.y0); x.lineTo(t1, b.y0); x.lineTo(t1 + sk, b.y1); x.lineTo(t0 + sk * 0.6, b.y1); x.closePath();
        const lit = i % 2 === 0;
        const fg = x.createLinearGradient(0, b.y0, 0, b.y1);
        fg.addColorStop(0, lit ? 'rgba(255,255,255,0.16)' : 'rgba(0,0,0,0.0)');
        fg.addColorStop(1, lit ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.16)');
        x.fillStyle = fg; x.fill();
        x.strokeStyle = 'rgba(255,255,255,0.10)'; x.lineWidth = 1; x.beginPath(); x.moveTo(t1, b.y0); x.lineTo(t1 + sk, b.y1); x.stroke();
      }
      // table: the brighter band a third of the way down (light caught in the crystal)
      const tb = x.createLinearGradient(0, b.y0, 0, b.y1);
      tb.addColorStop(0.18, 'rgba(255,255,255,0)'); tb.addColorStop(0.34, `rgba(255,255,255,${0.16 * bright})`); tb.addColorStop(0.5, 'rgba(255,255,255,0)');
      x.fillStyle = tb; x.fillRect(b.x0, b.y0, b.w, b.h);
      if (streak) {   // diagonal gloss streak on the left
        x.save(); x.translate(b.x0 + b.w * 0.22, b.cy); x.rotate(-0.5);
        const sg = x.createLinearGradient(-b.h * 0.5, 0, b.h * 0.5, 0);
        sg.addColorStop(0, 'rgba(255,255,255,0)'); sg.addColorStop(0.5, 'rgba(255,255,255,0.22)'); sg.addColorStop(1, 'rgba(255,255,255,0)');
        x.fillStyle = sg; x.fillRect(-b.h * 0.5, -b.h * 2, b.h, b.h * 4); x.restore();
      }
    });
    K.innerShadow(x, pts, rgba(mix(H, [0, 0, 0], 0.8), 0.9), Math.max(4, b.h * 0.14), 0, -Math.max(2, b.h * 0.05));
    K.withClip(x, pts, () => {   // lit top lip
      const top = K.inset(pts, 2.5);
      x.save(); x.beginPath();
      for (let i = 0; i < top.length; i++) { const p = top[i], q = top[(i + 1) % top.length]; if (Math.abs(p[1] - q[1]) < 0.5 && p[1] < b.cy) { x.moveTo(p[0], p[1]); x.lineTo(q[0], q[1]); } }
      x.strokeStyle = 'rgba(255,255,255,0.85)'; x.lineWidth = 1.6; x.stroke(); x.restore();
    });
    for (let i = 0; i < sparkles; i++) sparkle(x, b.x0 + b.w * (0.15 + 0.7 * R()), b.y0 + b.h * (0.2 + 0.25 * R()), b.h * (0.12 + 0.08 * R()), [255, 255, 255], 0.9, R());
  };

  // a domed crystal (emblem, sockets): radial light off-centre, star facets, caustic crescent, specular
  K.dome = (x, cx, cy, r, hueHex, { seed = 5, bright = 1, facets = 12 } = {}) => {
    const H = hex(hueHex), R = rng(seed);
    x.save(); x.beginPath(); x.arc(cx, cy, r, 0, Math.PI * 2); x.clip();
    const g = x.createRadialGradient(cx + r * 0.18, cy + r * 0.24, r * 0.05, cx, cy, r);
    g.addColorStop(0, rgba(mix(H, [255, 255, 255], 0.6 * bright), 1));
    g.addColorStop(0.35, rgba(mix(H, [255, 255, 255], 0.12), 1));
    g.addColorStop(0.75, rgba(mix(H, [0, 0, 0], 0.35), 1));
    g.addColorStop(1, rgba(mix(H, [0, 0, 0], 0.72), 1));
    x.fillStyle = g; x.fillRect(cx - r, cy - r, 2 * r, 2 * r);
    for (let i = 0; i < facets; i++) {   // star-cut facets
      const a0 = (i / facets) * Math.PI * 2 + 0.2, a1 = ((i + 1) / facets) * Math.PI * 2 + 0.2;
      x.beginPath(); x.moveTo(cx + r * 0.08 * Math.cos(a0 + 1), cy + r * 0.08 * Math.sin(a0 + 1));
      x.lineTo(cx + r * 1.1 * Math.cos(a0), cy + r * 1.1 * Math.sin(a0)); x.lineTo(cx + r * 1.1 * Math.cos(a1), cy + r * 1.1 * Math.sin(a1)); x.closePath();
      x.fillStyle = i % 2 ? `rgba(255,255,255,${0.05 + 0.05 * R()})` : `rgba(0,0,0,${0.06 + 0.06 * R()})`; x.fill();
    }
    // caustic crescent (light focused through the dome, opposite the key light)
    x.globalCompositeOperation = 'lighter';
    const cg = x.createRadialGradient(cx + r * 0.25, cy + r * 0.45, r * 0.1, cx + r * 0.25, cy + r * 0.45, r * 0.7);
    cg.addColorStop(0, rgba(mix(H, [255, 255, 255], 0.3), 0.55)); cg.addColorStop(1, rgba(H, 0));
    x.fillStyle = cg; x.beginPath(); x.arc(cx, cy, r, 0.1 * Math.PI, 0.9 * Math.PI); x.arc(cx + r * 0.05, cy - r * 0.2, r * 0.95, 0.9 * Math.PI, 0.1 * Math.PI, true); x.fill();
    x.globalCompositeOperation = 'source-over';
    // rim darkening
    const rg = x.createRadialGradient(cx, cy, r * 0.78, cx, cy, r);
    rg.addColorStop(0, 'rgba(0,0,0,0)'); rg.addColorStop(1, rgba(mix(H, [0, 0, 0], 0.85), 0.7));
    x.fillStyle = rg; x.fillRect(cx - r, cy - r, 2 * r, 2 * r);
    // specular: soft window reflection upper-left + a sharp glint
    x.save(); x.translate(cx - r * 0.34, cy - r * 0.4); x.rotate(-0.6);
    const sg = x.createRadialGradient(0, 0, 0, 0, 0, r * 0.42);
    sg.addColorStop(0, 'rgba(255,255,255,0.85)'); sg.addColorStop(0.5, 'rgba(255,255,255,0.25)'); sg.addColorStop(1, 'rgba(255,255,255,0)');
    x.scale(1, 0.55); x.fillStyle = sg; x.beginPath(); x.arc(0, 0, r * 0.42, 0, Math.PI * 2); x.fill(); x.restore();
    blob(x, cx - r * 0.42, cy - r * 0.46, r * 0.09, [255, 255, 255], 0.95);
    x.restore();
  };

  // carved stone slab: fbm grain, chisel bevel lit from the upper left, cracks, dust in the pores
  K.stone = (x, pts, { seed = 11, base = '#2d2935', bevel = 16, cracks = 3, light = 1 } = {}) => {
    const b = K.bbox(pts), R = rng(seed), N = makeNoise(seed), B = hex(base);
    K.withClip(x, pts, () => {
      const X0 = Math.floor(b.x0), Y0 = Math.floor(b.y0), W = Math.ceil(b.w) + 1, Hh = Math.ceil(b.h) + 1;
      const img = x.createImageData(W, Hh), d = img.data;
      for (let y = 0; y < Hh; y++) for (let xx = 0; xx < W; xx++) {
        const u = (X0 + xx) / 38, v = (Y0 + y) / 38;
        const n = fbm(N, u, v, 5) * 0.6 + fbm(N, u * 4 + 7, v * 4, 3) * 0.25;
        const pore = Math.max(0, -fbm(N, u * 9 + 3, v * 9 - 5, 2) - 0.25) * 1.6;
        const k = 1 + n * 0.55 - pore * 0.5;
        const o = (y * W + xx) * 4;
        d[o] = B[0] * k; d[o + 1] = B[1] * k; d[o + 2] = B[2] * k * 1.04; d[o + 3] = 255;
      }
      x.putImageData(img, X0, Y0);
      // chisel bevel: one flat facet per edge, shaded by its normal against a light from the upper left
      const inner = K.inset(pts, bevel);
      let area = 0; for (let i = 0; i < pts.length; i++) { const p = pts[i], q = pts[(i + 1) % pts.length]; area += p[0] * q[1] - q[0] * p[1]; }
      for (let i = 0; i < pts.length; i++) {
        const j = (i + 1) % pts.length, p = pts[i], q = pts[j];
        let nx = q[1] - p[1], ny = -(q[0] - p[0]); const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l; if (area < 0) { nx = -nx; ny = -ny; }
        const lit = -(nx * -0.6 + ny * -0.8);          // outward normal facing the light (up-left) -> bright
        x.beginPath(); x.moveTo(p[0], p[1]); x.lineTo(q[0], q[1]); x.lineTo(inner[j][0], inner[j][1]); x.lineTo(inner[i][0], inner[i][1]); x.closePath();
        x.fillStyle = lit < 0 ? `rgba(255,248,240,${0.22 * light * -lit})` : `rgba(0,0,0,${0.45 * lit})`;
        x.fill();
      }
      x.strokeStyle = 'rgba(255,255,255,0.08)'; x.lineWidth = 1; K.path(x, inner); x.stroke();
      // cracks: jagged random walks from an edge
      for (let c = 0; c < cracks; c++) {
        let px = b.x0 + b.w * (0.15 + 0.7 * R()), py = R() < 0.5 ? b.y0 : b.y1, ang = py === b.y0 ? Math.PI / 2 : -Math.PI / 2;
        ang += (R() - 0.5) * 0.9;
        const seg = [[px, py]], L = b.h * (0.3 + 0.35 * R());
        for (let s = 0; s < L; s += 6) { ang += (R() - 0.5) * 0.9; px += Math.cos(ang) * 6; py += Math.sin(ang) * 6; seg.push([px, py]); }
        x.lineJoin = 'round';
        x.beginPath(); seg.forEach((p, i) => i ? x.lineTo(p[0] + 1, p[1] + 1) : x.moveTo(p[0] + 1, p[1] + 1)); x.strokeStyle = 'rgba(255,240,230,0.14)'; x.lineWidth = 1.2; x.stroke();
        x.beginPath(); seg.forEach((p, i) => i ? x.lineTo(p[0], p[1]) : x.moveTo(p[0], p[1])); x.strokeStyle = 'rgba(6,4,10,0.85)'; x.lineWidth = 1.6; x.stroke();
      }
    });
    K.innerShadow(x, pts, 'rgba(0,0,0,0.55)', 10, 0, 0);
  };

  // ---------------------------------------------------------------------------------------------- small painted gold
  K.goldBead = (x, cx, cy, r) => {
    const g = x.createRadialGradient(cx - r * 0.35, cy - r * 0.4, r * 0.05, cx, cy, r);
    g.addColorStop(0, UI_GOLD.hi); g.addColorStop(0.35, UI_GOLD.light); g.addColorStop(0.7, UI_GOLD.low); g.addColorStop(1, UI_GOLD.ink);
    x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, Math.PI * 2); x.fill();
  };
  K.goldRail = (x, x0, y0, w, h, vertical = false) => {   // a small rounded rod (cross-section gradient)
    const g = vertical ? x.createLinearGradient(x0, 0, x0 + w, 0) : x.createLinearGradient(0, y0, 0, y0 + h);
    g.addColorStop(0, UI_GOLD.ink); g.addColorStop(0.2, UI_GOLD.low); g.addColorStop(0.42, UI_GOLD.hi); g.addColorStop(0.6, UI_GOLD.mid); g.addColorStop(1, UI_GOLD.deep);
    x.fillStyle = g; x.fillRect(x0, y0, w, h);
  };

  // ---------------------------------------------------------------------------------------------- corrupted post
  // cracks in the metal with the toxic light seeping out (drawn only over existing pixels)
  K.cracksOver = (x, w, h, { seed = 21, n = 5, hue = '#39ff14', region = null } = {}) => {
    const R = rng(seed), crack = K.canvas(w, h), c = crack.getContext('2d');
    const box = region || [0, 0, w, h];
    for (let i = 0; i < n; i++) {
      let px = box[0] + R() * box[2], py = box[1] + R() * box[3], ang = R() * Math.PI * 2;
      const seg = [[px, py]], L = 20 + R() * 60;
      for (let s = 0; s < L; s += 4) { ang += (R() - 0.5) * 1.1; px += Math.cos(ang) * 4; py += Math.sin(ang) * 4; seg.push([px, py]);
        if (R() < 0.08) { let bx = px, by = py, ba = ang + (R() < 0.5 ? 1 : -1) * 0.9; c.beginPath(); c.moveTo(bx, by); for (let k = 0; k < 4; k++) { ba += (R() - 0.5); bx += Math.cos(ba) * 4; by += Math.sin(ba) * 4; c.lineTo(bx, by); } c.strokeStyle = '#000'; c.lineWidth = 1; c.stroke(); } }
      c.beginPath(); seg.forEach((p, k) => k ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1])); c.strokeStyle = '#000'; c.lineWidth = 1.8; c.lineJoin = 'round'; c.stroke();
    }
    // glow from the cracks (hue), then the dark crack line, both clipped to the piece's own alpha
    const glow = K.canvas(w, h), gx = glow.getContext('2d');
    gx.filter = 'blur(3px)'; gx.drawImage(crack, 0, 0); gx.filter = 'none';
    gx.globalCompositeOperation = 'source-in'; gx.fillStyle = hue; gx.fillRect(0, 0, w, h);
    x.save(); x.globalCompositeOperation = 'source-atop';
    x.globalAlpha = 0.95; x.drawImage(glow, 0, 0); x.drawImage(glow, 0, 0);
    x.globalAlpha = 1; x.drawImage(crack, 0, 0);
    x.restore();
  };
  // glitch: horizontal slice offsets, a chromatic split (the alt / cyan channels), pixel blocks, scanlines
  K.glitch = (cv, { seed = 31, slices = 9, shift = 10, split = 3, blocks = 26, hue = '#39ff14', alt = '#ff2e63', cyan = '#2ef2ff', scan = 0.12, region = null } = {}) => {
    const w = cv.width, h = cv.height, R = rng(seed), src = K.canvas(w, h), s = src.getContext('2d');
    s.drawImage(cv, 0, 0);
    const x = cv.getContext('2d');
    const tint = (col) => { const c = K.canvas(w, h), y = c.getContext('2d'); y.drawImage(src, 0, 0); y.globalCompositeOperation = 'source-in'; y.fillStyle = col; y.fillRect(0, 0, w, h); return c; };
    const A = tint(alt), C = tint(cyan);
    x.clearRect(0, 0, w, h);
    x.globalAlpha = 0.55; x.drawImage(A, -split, 0); x.drawImage(C, split, 0); x.globalAlpha = 1;
    x.drawImage(src, 0, 0);
    const reg = region || [0, 0, w, h];
    for (let i = 0; i < slices; i++) {        // torn rows
      const y0 = reg[1] + R() * reg[3], hh = 2 + R() * 7, dx = (R() - 0.5) * 2 * shift;
      x.clearRect(0, y0, w, hh); x.drawImage(src, 0, y0, w, hh, dx, y0, w, hh);
      if (R() < 0.5) { x.save(); x.globalCompositeOperation = 'source-atop'; x.fillStyle = K.c(R() < 0.5 ? hue : alt, 0.35); x.fillRect(0, y0, w, hh); x.restore(); }
    }
    const d = s.getImageData(0, 0, w, h).data;
    for (let i = 0; i < blocks; i++) {        // pixel blocks near content
      const bx = Math.floor(reg[0] + R() * reg[2]), by = Math.floor(reg[1] + R() * reg[3]);
      if (d[(by * w + bx) * 4 + 3] < 40) continue;
      const bs = 2 + Math.floor(R() * 5) * 2;
      x.fillStyle = K.c([hue, hue, alt, '#ffffff', cyan][Math.floor(R() * 5)], 0.75 + 0.25 * R());
      x.fillRect(bx, by, bs, Math.max(2, bs / 2));
    }
    if (scan) {
      x.save(); x.globalCompositeOperation = 'source-atop'; x.fillStyle = `rgba(0,0,0,${scan})`;
      for (let y = 0; y < h; y += 4) x.fillRect(0, y, w, 1.5);
      x.restore();
    }
  };

  // ---------------------------------------------------------------------------------------------- VFX sprites (white)
  K.fx = {
    glow(x, cx, cy, r) {
      const g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
      for (let i = 0; i <= 10; i++) { const t = i / 10; g.addColorStop(t, `rgba(255,255,255,${Math.exp(-t * t * 4.5) * (1 - t)})`); }
      x.fillStyle = g; x.fillRect(cx - r, cy - r, 2 * r, 2 * r);
    },
    ring(x, cx, cy, r, w) {
      const g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
      const a = (r - w * 2.5) / r, b = (r - w) / r;
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(Math.max(0, a - 0.25), 'rgba(255,255,255,0)'); g.addColorStop(a, 'rgba(255,255,255,0.18)');
      g.addColorStop(b, 'rgba(255,255,255,1)'); g.addColorStop(Math.min(1, b + (1 - b) * 0.6), 'rgba(255,255,255,0.2)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = g; x.fillRect(cx - r, cy - r, 2 * r, 2 * r);
    },
    star(x, cx, cy, r, rays = 4, rot = 0) {
      x.save(); x.translate(cx, cy); x.rotate(rot);
      for (let k = 0; k < rays; k++) {
        x.rotate(Math.PI * 2 / rays * (k ? 1 : 0));
        const len = k % 2 ? r * 0.6 : r;
        const g = x.createLinearGradient(-len, 0, len, 0);
        g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,1)'); g.addColorStop(1, 'rgba(255,255,255,0)');
        x.fillStyle = g; x.beginPath(); x.ellipse(0, 0, len, r * 0.05, 0, 0, Math.PI * 2); x.fill();
      }
      x.restore();
      K.fx.glow(x, cx, cy, r * 0.35);
    },
    streak(x, x0, y0, w, h) {
      const g = x.createLinearGradient(x0, 0, x0 + w, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.75, 'rgba(255,255,255,0.9)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = g; x.beginPath(); x.ellipse(x0 + w / 2, y0 + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2); x.fill();
    },
    flare(x, x0, y0, w, h) {
      const cx = x0 + w / 2, cy = y0 + h / 2;
      const g = x.createLinearGradient(x0, 0, x0 + w, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,1)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = g; x.beginPath(); x.ellipse(cx, cy, w / 2, h * 0.08, 0, 0, Math.PI * 2); x.fill();
      x.globalAlpha = 0.5; x.beginPath(); x.ellipse(cx, cy, w * 0.3, h * 0.3, 0, 0, Math.PI * 2); x.fill(); x.globalAlpha = 1;
      K.fx.glow(x, cx, cy, h * 0.5);
    },
    sweep(x, x0, y0, w, h) {   // a soft vertical light band (rotated / moved by the client)
      const g = x.createLinearGradient(x0, 0, x0 + w, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.42, 'rgba(255,255,255,0.55)'); g.addColorStop(0.5, 'rgba(255,255,255,1)');
      g.addColorStop(0.58, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      x.fillStyle = g; x.fillRect(x0, y0, w, h);
      const v = x.createLinearGradient(0, y0, 0, y0 + h); v.addColorStop(0, 'rgba(0,0,0,1)'); v.addColorStop(0.15, 'rgba(0,0,0,0)'); v.addColorStop(0.85, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,1)');
      x.save(); x.globalCompositeOperation = 'destination-out'; x.fillStyle = v; x.fillRect(x0, y0, w, h); x.restore();
    },
    shimmer(x, x0, y0, w, h) {  // rim shimmer mask: a bright core fading both ways (UIGradient-style offset drives it)
      const g = x.createLinearGradient(x0, 0, x0 + w, 0);
      for (let i = 0; i <= 20; i++) { const t = i / 20; g.addColorStop(t, `rgba(255,255,255,${Math.exp(-Math.pow((t - 0.5) / 0.14, 2))})`); }
      x.fillStyle = g; x.fillRect(x0, y0, w, h);
    },
    rune(x, cx, cy, r, id) {
      const S = [
        [[[0, -1], [0, 1]], [[0, -0.3], [0.55, -0.85]], [[0, -0.3], [-0.55, -0.85]], [[0, 0.3], [0.55, 0.85]], [[0, 0.3], [-0.55, 0.85]]],
        [[[-0.5, -1], [-0.5, 1]], [[-0.5, -1], [0.5, -0.4]], [[0.5, -0.4], [-0.5, 0.2]]],
        [[[0, -1], [0.7, 0], [0, 1], [-0.7, 0], [0, -1]], [[-0.4, 0.55], [-0.7, 1]], [[0.4, 0.55], [0.7, 1]]],
        [[[-0.6, -1], [0.6, 1]], [[0.6, -1], [-0.6, 1]], [[-0.8, 0], [0.8, 0]]],
        [[[0, -1], [0, 1]], [[-0.6, -0.6], [0, -1], [0.6, -0.6]], [[-0.5, 0.2], [0.5, 0.2]]],
        [[[-0.6, 1], [-0.6, -1], [0.6, 1], [0.6, -1]]],
      ][id % 6];
      const draw = (lw, col) => { x.strokeStyle = col; x.lineWidth = lw; x.lineCap = 'round'; x.lineJoin = 'round';
        for (const st of S) { x.beginPath(); st.forEach(([u, v], i) => i ? x.lineTo(cx + u * r, cy + v * r) : x.moveTo(cx + u * r, cy + v * r)); x.stroke(); } };
      x.save(); x.filter = `blur(${r * 0.12}px)`; draw(r * 0.34, 'rgba(255,255,255,0.6)'); x.restore();
      draw(r * 0.14, 'rgba(255,255,255,1)');
    },
    shard(x, cx, cy, r, seed, kind = 'stone') {
      const R = rng(seed), n = 5 + Math.floor(R() * 3), pts = [];
      for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2 + R() * 0.6; const rr = r * (0.45 + 0.55 * R()) * (i % 2 ? 1 : 0.8); pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * (kind === 'crystal' ? 1.7 : 1)]); }
      K.path(x, pts);
      if (kind === 'stone') {
        const g = x.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
        g.addColorStop(0, '#8d8599'); g.addColorStop(0.45, '#4a4455'); g.addColorStop(1, '#1d1a22');
        x.fillStyle = g; x.fill(); x.strokeStyle = 'rgba(255,255,255,0.25)'; x.lineWidth = 1; x.stroke();
      } else {
        const g = x.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
        g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.5, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0.85)');
        x.fillStyle = g; x.fill();
        x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); x.lineTo(cx, cy); x.lineTo(pts[Math.floor(n / 2)][0], pts[Math.floor(n / 2)][1]);
        x.strokeStyle = 'rgba(255,255,255,0.9)'; x.lineWidth = 1; x.stroke();
      }
    },
  };
  return K;
})();
