#!/usr/bin/env node
/* roblox/tile.js: cut the rendered realm layers into Roblox-ready tiles (REALM.md section 3).
 *
 *   node roblox/tile.js                     every baked layer in realm.json + the sprite atlas, both tiers
 *   node roblox/tile.js --layers sky,world  only these (the other manifest entries are kept)
 *   node roblox/tile.js --tier LOW          only one tier
 *   node roblox/tile.js --check             re-read the written tiles and verify them against the sources (exit 1 on failure)
 *
 * Input   out/<id>.png, or out/<painter file>.png (whichever is newer): the painter's HIGH texture (size x res.HIGH).
 *         A full-size render (size x 1), or any render with the layer's aspect ratio, is resampled to the HIGH texture
 *         (premultiplied area filter). out/sprites.png is the 1024x1024 sprite atlas (realm.json atlas.file).
 * Output  roblox/tiles/<TIER>/<layer>_<col>_<row>.png and roblox/tiles/<TIER>/atlas.png, and roblox/manifest.json.
 *
 * Per tier: LOW = HIGH downsampled 2x in premultiplied space (the exact box filter a mip level uses). Each tile is its
 * content rect (camera.js tileRects) plus a 2 px gutter copied from the neighbouring pixels (edge pixels repeated at
 * the layer border), so bilinear sampling at a tile edge reads real neighbour colour. Every fully transparent pixel
 * gets a colour bled in from the nearest visible pixels (alpha stays 0): Roblox samples straight alpha, so without it
 * transparent black would fringe every scaled edge. Tiles whose content has max alpha < 2/255 are dropped.
 * Output is deterministic (same inputs -> byte-identical PNGs -> same sha256), so upload.js can skip what it already
 * uploaded.
 *
 * Also a library: render.js and compose.js use decodePNG / encodePNG / resample / alphaBleed.
 */
'use strict';
const fs = require('fs'), path = require('path'), zlib = require('zlib'), crypto = require('crypto');

const ART = path.resolve(__dirname, '..');
const OUT = path.join(ART, 'out');
const ROBLOX = __dirname;
const TILE_DIR = path.join(ROBLOX, 'tiles');
const MANIFEST = path.join(ROBLOX, 'manifest.json');
const TIERS = ['HIGH', 'LOW'];

// ==================================================================================================== PNG codec
const SIG = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
function crc32(buf) {
  if (typeof zlib.crc32 === 'function') return zlib.crc32(buf) >>> 0;
  let c = 0xffffffff; for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
const paeth = (a, b, c) => { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); return pa <= pb && pa <= pc ? a : pb <= pc ? b : c; };

/** PNG -> { width, height, data: Uint8Array RGBA8 (straight alpha) }. 8/16-bit grey, RGB, palette, grey+alpha, RGBA;
 *  palette and grey also at 1/2/4 bits. Not interlaced. */
function decodePNG(buf) {
  if (!Buffer.isBuffer(buf)) buf = Buffer.from(buf);
  if (buf.length < 8 || !buf.subarray(0, 8).equals(SIG)) throw new Error('not a PNG');
  let off = 8, w = 0, h = 0, bd = 8, ct = 6, il = 0, plte = null, trns = null; const idat = [];
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off), type = buf.toString('latin1', off + 4, off + 8), data = buf.subarray(off + 8, off + 8 + len);
    off += 12 + len;
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bd = data[8]; ct = data[9]; il = data[12]; }
    else if (type === 'PLTE') plte = data;
    else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
  }
  if (il) throw new Error('interlaced PNG is not supported');
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[ct];
  if (!ch) throw new Error('bad PNG colour type ' + ct);
  const bits = ch * bd, bpp = Math.max(1, bits >> 3), stride = (w * bits + 7) >> 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const px = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], src = y * (stride + 1) + 1, dst = y * stride, up = dst - stride;
    if (f === 0) raw.copy(px, dst, src, src + stride);
    else if (f === 1) for (let i = 0; i < stride; i++) px[dst + i] = raw[src + i] + (i >= bpp ? px[dst + i - bpp] : 0);
    else if (f === 2) for (let i = 0; i < stride; i++) px[dst + i] = raw[src + i] + (y ? px[up + i] : 0);
    else if (f === 3) for (let i = 0; i < stride; i++) px[dst + i] = raw[src + i] + (((i >= bpp ? px[dst + i - bpp] : 0) + (y ? px[up + i] : 0)) >> 1);
    else if (f === 4) for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? px[dst + i - bpp] : 0, b = y ? px[up + i] : 0, c = y && i >= bpp ? px[up + i - bpp] : 0;
      px[dst + i] = raw[src + i] + paeth(a, b, c);
    }
    else throw new Error('bad PNG filter ' + f);
  }
  const out = new Uint8Array(w * h * 4);
  if (bd === 8 && ct === 6) { out.set(px); return { width: w, height: h, data: out }; }
  if (bd === 8 && ct === 2 && !trns) {
    for (let i = 0, n = w * h; i < n; i++) { out[i * 4] = px[i * 3]; out[i * 4 + 1] = px[i * 3 + 1]; out[i * 4 + 2] = px[i * 3 + 2]; out[i * 4 + 3] = 255; }
    return { width: w, height: h, data: out };
  }
  const sample = (y, i) => { // i-th sample of row y, scaled to 8 bits
    if (bd === 8) return px[y * stride + i];
    if (bd === 16) return px[y * stride + 2 * i];
    const per = 8 / bd, byte = px[y * stride + Math.floor(i / per)], shift = 8 - bd * (i % per + 1), v = (byte >> shift) & ((1 << bd) - 1);
    return ct === 3 ? v : Math.round(v * 255 / ((1 << bd) - 1));
  };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const o = (y * w + x) * 4;
    if (ct === 6) { for (let k = 0; k < 4; k++) out[o + k] = sample(y, x * 4 + k); }
    else if (ct === 2) { for (let k = 0; k < 3; k++) out[o + k] = sample(y, x * 3 + k); out[o + 3] = 255;
      if (trns && trns.length >= 6 && bd === 8 && out[o] === trns[1] && out[o + 1] === trns[3] && out[o + 2] === trns[5]) out[o + 3] = 0; }
    else if (ct === 0) { const g = sample(y, x); out[o] = out[o + 1] = out[o + 2] = g; out[o + 3] = 255; }
    else if (ct === 4) { const g = sample(y, x * 2); out[o] = out[o + 1] = out[o + 2] = g; out[o + 3] = sample(y, x * 2 + 1); }
    else if (ct === 3) { const i = sample(y, x); out[o] = plte[i * 3]; out[o + 1] = plte[i * 3 + 1]; out[o + 2] = plte[i * 3 + 2]; out[o + 3] = trns && i < trns.length ? trns[i] : 255; }
  }
  return { width: w, height: h, data: out };
}

/** RGBA8 -> PNG buffer. alpha: 'auto' writes RGB when every pixel is opaque. Per-row adaptive filter (minimum sum of
 *  absolute differences), zlib level 7 (level 9 is 5x slower for 2% smaller files): deterministic. Straight alpha: bled colours survive. */
function encodePNG(img, { alpha = 'auto', level = 7 } = {}) {
  const { width: w, height: h, data } = img;
  let hasA = alpha === true;
  if (alpha === 'auto') for (let i = 3; i < data.length; i += 4) if (data[i] !== 255) { hasA = true; break; }
  const ch = hasA ? 4 : 3, stride = w * ch;
  const raw = Buffer.alloc(h * (stride + 1));
  let prev = Buffer.alloc(stride), cur = Buffer.alloc(stride);
  const cand = [0, 1, 2, 3, 4].map(() => Buffer.alloc(stride));
  for (let y = 0; y < h; y++) {
    for (let x = 0, o = y * w * 4; x < w; x++, o += 4) for (let k = 0; k < ch; k++) cur[x * ch + k] = data[o + k];
    let best = 0, bestSum = Infinity;
    for (let f = 0; f < 5; f++) {
      const c = cand[f]; let sum = 0, i = 0;
      // one specialised loop per filter type (the generic form is ~5x slower); `v < 128 ? v : 256 - v` = |signed byte|
      if (f === 0) for (; i < stride; i++) { const v = cur[i]; c[i] = v; sum += v < 128 ? v : 256 - v; }
      else if (f === 1) { for (; i < ch; i++) { const v = cur[i]; c[i] = v; sum += v < 128 ? v : 256 - v; }
        for (; i < stride && sum < bestSum; i++) { const v = (cur[i] - cur[i - ch]) & 255; c[i] = v; sum += v < 128 ? v : 256 - v; } }
      else if (f === 2) for (; i < stride && sum < bestSum; i++) { const v = (cur[i] - (y ? prev[i] : 0)) & 255; c[i] = v; sum += v < 128 ? v : 256 - v; }
      else if (f === 3) for (; i < stride && sum < bestSum; i++) { const v = (cur[i] - (((i >= ch ? cur[i - ch] : 0) + (y ? prev[i] : 0)) >> 1)) & 255; c[i] = v; sum += v < 128 ? v : 256 - v; }
      else for (; i < stride && sum < bestSum; i++) {
        const a = i >= ch ? cur[i - ch] : 0, b = y ? prev[i] : 0, cc = y && i >= ch ? prev[i - ch] : 0;
        const v = (cur[i] - paeth(a, b, cc)) & 255; c[i] = v; sum += v < 128 ? v : 256 - v;
      }
      if (i === stride && sum < bestSum) { bestSum = sum; best = f; }   // a filter that stopped early lost
    }
    raw[y * (stride + 1)] = best; cand[best].copy(raw, y * (stride + 1) + 1);
    const t = prev; prev = cur; cur = t;
  }
  const chunk = (type, body) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(body.length);
    const tb = Buffer.concat([Buffer.from(type, 'latin1'), body]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(tb));
    return Buffer.concat([len, tb, crc]);
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = hasA ? 6 : 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const z = zlib.deflateSync(raw, { level, memLevel: 9 });
  return Buffer.concat([SIG, chunk('IHDR', ihdr), chunk('IDAT', z), chunk('IEND', Buffer.alloc(0))]);
}

const readPNG = f => decodePNG(fs.readFileSync(f));
const writePNG = (f, img, o) => { const b = encodePNG(img, o); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, b); return b; };
const sha256 = b => crypto.createHash('sha256').update(b).digest('hex');

// ==================================================================================================== pixel ops
/** Straight RGBA8 -> premultiplied Float32 (rgb in 0..255 times alpha in 0..1, alpha in 0..1). */
function premul(img) {
  const d = img.data, n = img.width * img.height, P = new Float32Array(n * 4);
  for (let i = 0; i < n; i++) { const o = i * 4, a = d[o + 3] / 255; P[o] = d[o] * a; P[o + 1] = d[o + 1] * a; P[o + 2] = d[o + 2] * a; P[o + 3] = a; }
  return P;
}
function unpremul(P, w, h) {
  const n = w * h, d = new Uint8Array(n * 4);
  for (let i = 0; i < n; i++) {
    const o = i * 4, a = P[o + 3], A = Math.round(Math.min(1, Math.max(0, a)) * 255);
    d[o + 3] = A;
    if (A > 0) for (let k = 0; k < 3; k++) d[o + k] = Math.min(255, Math.max(0, Math.round(P[o + k] / a)));
  }
  return { width: w, height: h, data: d };
}
/** Separable weights mapping n source px onto m output px. Downscale: exact area coverage (a box the size of one
 *  output px). Upscale: bilinear. */
function axisWeights(n, m) {
  const out = [], s = n / m;
  for (let i = 0; i < m; i++) {
    const ws = [];
    if (s >= 1) {
      const a = i * s, b = (i + 1) * s;
      for (let j = Math.floor(a); j < Math.min(n, Math.ceil(b)); j++) { const w = Math.min(b, j + 1) - Math.max(a, j); if (w > 1e-9) ws.push([j, w / s]); }
    } else {
      const x = (i + 0.5) * s - 0.5, j0 = Math.floor(x), t = x - j0;
      ws.push([Math.min(n - 1, Math.max(0, j0)), 1 - t], [Math.min(n - 1, Math.max(0, j0 + 1)), t]);
    }
    out.push(ws);
  }
  return out;
}
/** High-quality resample of a straight RGBA8 image to (w2, h2), in premultiplied space (no dark halos). */
function resample(img, w2, h2) {
  const { width: w, height: h } = img;
  if (w === w2 && h === h2) return { width: w, height: h, data: new Uint8Array(img.data) };
  const P = premul(img), wx = axisWeights(w, w2), wy = axisWeights(h, h2);
  const T = new Float32Array(w2 * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w2; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (const [j, wt] of wx[x]) { const o = (y * w + j) * 4; r += P[o] * wt; g += P[o + 1] * wt; b += P[o + 2] * wt; a += P[o + 3] * wt; }
    const o = (y * w2 + x) * 4; T[o] = r; T[o + 1] = g; T[o + 2] = b; T[o + 3] = a;
  }
  const Q = new Float32Array(w2 * h2 * 4);
  for (let y = 0; y < h2; y++) for (const [j, wt] of wy[y]) {
    const so = j * w2 * 4, dO = y * w2 * 4;
    for (let k = 0; k < w2 * 4; k++) Q[dO + k] += T[so + k] * wt;
  }
  return unpremul(Q, w2, h2);
}

/** Alpha bleed: every pixel with alpha 0 gets the colour of the visible pixels nearest to it; alpha stays 0 and
 *  visible pixels are untouched. Push-pull on a premultiplied pyramid: each level is composited over the upsampled
 *  coarser one, so the colour next to an edge is that edge's colour and it fades smoothly (no Voronoi seams, small
 *  PNGs) into the colour of whatever lies farther away. Near-invisible pixels (alpha 1-2) only contribute by their
 *  alpha, so their quantisation noise never spreads. */
function alphaBleed(img) {
  const { width: w, height: h, data: d } = img;
  let any = false, holes = false;
  for (let i = 3; i < d.length; i += 4) { if (d[i]) any = true; else holes = true; if (any && holes) break; }
  if (!any || !holes) return img;
  const levels = [{ w, h, P: premul(img) }];
  while (levels[levels.length - 1].w > 1 || levels[levels.length - 1].h > 1) {
    const L = levels[levels.length - 1], w2 = Math.ceil(L.w / 2), h2 = Math.ceil(L.h / 2), P2 = new Float32Array(w2 * h2 * 4);
    for (let y = 0; y < h2; y++) for (let x = 0; x < w2; x++) {
      let n = 0; const o = (y * w2 + x) * 4;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const sx = 2 * x + dx, sy = 2 * y + dy; if (sx >= L.w || sy >= L.h) continue;
        const s = (sy * L.w + sx) * 4; P2[o] += L.P[s]; P2[o + 1] += L.P[s + 1]; P2[o + 2] += L.P[s + 2]; P2[o + 3] += L.P[s + 3]; n++;
      }
      P2[o] /= n; P2[o + 1] /= n; P2[o + 2] /= n; P2[o + 3] /= n;
    }
    levels.push({ w: w2, h: h2, P: P2 });
  }
  // pull: F_k = P_k + (1 - A_k) * bilinear_up(F_{k+1})
  let F = levels[levels.length - 1].P;
  for (let k = levels.length - 2; k >= 0; k--) {
    const L = levels[k], C = levels[k + 1], G = new Float32Array(L.w * L.h * 4);
    for (let y = 0; y < L.h; y++) {
      const fy = Math.min(C.h - 1, Math.max(0, (y + 0.5) / 2 - 0.5)), y0 = Math.floor(fy), y1 = Math.min(C.h - 1, y0 + 1), ty = fy - y0;
      for (let x = 0; x < L.w; x++) {
        const fx = Math.min(C.w - 1, Math.max(0, (x + 0.5) / 2 - 0.5)), x0 = Math.floor(fx), x1 = Math.min(C.w - 1, x0 + 1), tx = fx - x0;
        const o = (y * L.w + x) * 4, a = L.P[o + 3], k1 = 1 - a;
        const o00 = (y0 * C.w + x0) * 4, o10 = (y0 * C.w + x1) * 4, o01 = (y1 * C.w + x0) * 4, o11 = (y1 * C.w + x1) * 4;
        for (let c = 0; c < 4; c++) {
          const up = (F[o00 + c] * (1 - tx) + F[o10 + c] * tx) * (1 - ty) + (F[o01 + c] * (1 - tx) + F[o11 + c] * tx) * ty;
          G[o + c] = L.P[o + c] + k1 * up;
        }
      }
    }
    F = G;
  }
  const out = new Uint8Array(d);
  for (let i = 0; i < w * h; i++) {
    const o = i * 4; if (d[o + 3]) continue;
    const a = F[o + 3];
    if (a > 1e-7) for (let c = 0; c < 3; c++) out[o + c] = Math.min(255, Math.max(0, Math.round(F[o + c] / a)));
  }
  return { width: w, height: h, data: out };
}

/** Sub-image [x, x + w) x [y, y + h) of img with a g px gutter around it: pixels outside the image repeat its edge. */
function cutWithGutter(img, x, y, w, h, g) {
  const W = w + 2 * g, H = h + 2 * g, out = new Uint8Array(W * H * 4), src = img.data, iw = img.width, ih = img.height;
  for (let v = 0; v < H; v++) {
    const sy = Math.min(ih - 1, Math.max(0, y + v - g));
    for (let u = 0; u < W; u++) {
      const sx = Math.min(iw - 1, Math.max(0, x + u - g)), s = (sy * iw + sx) * 4, o = (v * W + u) * 4;
      out[o] = src[s]; out[o + 1] = src[s + 1]; out[o + 2] = src[s + 2]; out[o + 3] = src[s + 3];
    }
  }
  return { width: W, height: H, data: out };
}
function maxAlpha(img, x = 0, y = 0, w = img.width, h = img.height) {
  let m = 0;
  for (let v = y; v < y + h; v++) for (let u = x; u < x + w; u++) { const a = img.data[(v * img.width + u) * 4 + 3]; if (a > m) m = a; if (m === 255) return m; }
  return m;
}
function pasteRGBA(dst, src, x, y) {
  for (let v = 0; v < src.height; v++) dst.data.set(src.data.subarray(v * src.width * 4, (v + 1) * src.width * 4), ((y + v) * dst.width + x) * 4);
}
/** true when some alpha-0 pixel of the rect is black while a visible, non-black pixel is within 2 px (not alpha-bled;
 *  black content such as the vignette may keep black neighbours) */
function blackNextToContent(img, x, y, w, h) {
  const d = img.data, W = img.width;
  for (let v = y; v < y + h; v++) for (let u = x; u < x + w; u++) {
    const o = (v * W + u) * 4; if (d[o + 3] || d[o] + d[o + 1] + d[o + 2]) continue;
    for (let dv = -2; dv <= 2; dv++) for (let du = -2; du <= 2; du++) {
      const qu = u + du, qv = v + dv; if (qu < x || qv < y || qu >= x + w || qv >= y + h) continue;
      const q = (qv * W + qu) * 4; if (d[q + 3] && d[q] + d[q + 1] + d[q + 2] > 24) return true;
    }
  }
  return false;
}
function forceOpaque(img) { for (let i = 3; i < img.data.length; i += 4) img.data[i] = 255; return img; }

// ==================================================================================================== sources
const loadRealm = () => JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8'));
/** Painter files that register LAYERS.<id> (the realm.json file name may be stale: distant.js paints `far`). */
function painterIndex() {
  const idx = {}, dir = path.join(ART, 'layers');
  for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
    if (!f.endsWith('.js')) continue;
    const src = fs.readFileSync(path.join(dir, f), 'utf8');
    for (const m of src.matchAll(/LAYERS\s*(?:\.\s*([A-Za-z_$][\w$]*)|\[\s*['"]([^'"]+)['"]\s*\])\s*=(?!=)/g)) {
      const k = m[1] || m[2]; (idx[k] = idx[k] || []).push(f);
    }
  }
  return idx;
}
/** Candidate render files for a layer (or 'sprites'), newest first. */
function sourceCandidates(id, R, idx = painterIndex()) {
  const names = new Set([id]);
  const L = R && R.layers.find(l => l.id === id);
  if (L && L.file) names.add(path.basename(L.file, '.js'));
  for (const f of idx[id] || []) names.add(path.basename(f, '.js'));
  if (id === 'sprites' && R && R.atlas && R.atlas.file) names.add(path.basename(R.atlas.file, '.png'));
  return [...names].map(n => path.join(OUT, n + '.png')).filter(f => fs.existsSync(f))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
}
/** The HIGH texture of a layer: the render as is, or resampled when it is a full-size / other-scale render. */
function highTexture(L, file) {
  const img = readPNG(file), [tw, th] = L.grid.HIGH.texture, note = [];
  if (img.width === tw && img.height === th) return { img, note: 'exact' };
  const ar = img.width / img.height, want = tw / th;
  if (Math.abs(ar / want - 1) > 0.004)
    throw new Error(`${path.relative(ART, file)} is ${img.width}x${img.height} (aspect ${ar.toFixed(4)}); layer ${L.id} needs ${tw}x${th} ` +
      `(size ${L.size.join('x')} x res ${L.res.HIGH}), aspect ${want.toFixed(4)}. Repaint it at the contract size.`);
  note.push(`resampled ${img.width}x${img.height} -> ${tw}x${th}`);
  return { img: resample(img, tw, th), note: note.join(', ') };
}

// ==================================================================================================== tiling
function tileLayer(L, tier, texture, { write = true } = {}) {
  const rects = require(path.join(ART, 'camera.js')).tileRects(L, tier), g = L.tiles.gutter, tiles = [];
  for (const r of rects) {
    const file = `tiles/${tier}/${L.id}_${r.i}_${r.j}.png`;
    const base = { i: r.i, j: r.j, local: r.local, rectOffset: r.rectOffset, rectSize: [r.tex.w, r.tex.h], tex: [r.tex.x, r.tex.y] };
    const ma = maxAlpha(texture, r.tex.x, r.tex.y, r.tex.w, r.tex.h);
    if (ma < 2) { tiles.push({ ...base, empty: true, file: null }); continue; }
    const img = cutWithGutter(texture, r.tex.x, r.tex.y, r.tex.w, r.tex.h, g);
    if (img.width > 1024 || img.height > 1024) throw new Error(`${file} is ${img.width}x${img.height} > 1024`);
    const buf = write ? writePNG(path.join(ROBLOX, file), img, { alpha: L.opaque ? false : 'auto' }) : encodePNG(img);
    tiles.push({ ...base, empty: false, file, image: [img.width, img.height], bytes: buf.length, sha256: sha256(buf), maxAlpha: ma });
  }
  return tiles;
}

function tierTexture(L, tier, hi) {
  if (tier === 'HIGH') return hi;
  const [tw, th] = L.grid.LOW.texture;
  return resample(hi, tw, th);
}

function run(argv) {
  const opt = { layers: null, tiers: TIERS, check: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--layers') opt.layers = argv[++i].split(',');
    else if (a === '--tier') opt.tiers = [argv[++i].toUpperCase()];
    else if (a === '--check') opt.check = true;
    else if (a === '-h' || a === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); return 0; }
    else { console.error('unknown argument ' + a); return 2; }
  }
  const R = loadRealm();
  if (opt.check) return check(R) ? 0 : 1;
  const idx = painterIndex();
  const old = fs.existsSync(MANIFEST) ? JSON.parse(fs.readFileSync(MANIFEST, 'utf8')) : null;
  const want = id => !opt.layers || opt.layers.includes(id);
  const man = {
    about: 'Generated by `node roblox/tile.js` (REALM.md section 3). Tiles are PNG, <= 1024 px: the content rect plus a 2 px gutter ' +
      'holding the neighbours\' pixels. Client (REALM.md 9.3): ImageRectOffset = rectOffset (the gutter), ImageRectSize = rectSize, and the ' +
      'tile covers `local` (layer-local px) in a layer container of `size`. Place tiles by the snapped recipe: the column / row edges ' +
      '(local.x and local.x + local.w, local.y and local.y + local.h) are rounded to whole device pixels and each edge is shared by the two ' +
      'neighbours, so there is no gap and no overlap. Empty tiles (file null) are not uploaded. Atlas: regions in HIGH px (halve them for ' +
      'the LOW sheet); a region listed in sampleRects (lowSampleRects on LOW) is sampled through that inset rect instead of its own.',
    realmVersion: R.version, gutter: R.tiling.gutter, version: null, tiers: {}, atlas: null, budget: {},
  };
  for (const tier of TIERS) man.tiers[tier] = { layers: [] };
  const t0 = Date.now();
  for (const L of R.layers.filter(l => l.kind === 'baked')) {
    const keep = tier => old && old.tiers[tier] && old.tiers[tier].layers.find(x => x.id === L.id);
    if (!want(L.id)) { for (const tier of TIERS) if (keep(tier)) man.tiers[tier].layers.push(keep(tier)); continue; }
    const cands = sourceCandidates(L.id, R, idx);
    const entry = tier => ({ id: L.id, depth: L.depth, f: L.f, size: L.size, anchor: L.anchor, scale: L.grid[tier].scale,
      texture: L.grid[tier].texture, opaque: !!L.opaque, zHide: L.zHide || 0, zShow: L.zShow || 0, tint: L.tint,
      grid: [L.grid[tier].nx, L.grid[tier].ny] });
    if (!cands.length) {
      console.log(`  ${L.id.padEnd(7)} MISSING: no out/${L.id}.png (render it: node render.js ${L.id})`);
      for (const tier of TIERS) man.tiers[tier].layers.push({ ...entry(tier), missing: true, source: null, tiles: [] });
      continue;
    }
    let hi;
    try { hi = highTexture(L, cands[0]); }
    catch (e) {
      console.log(`  ${L.id.padEnd(7)} SKIPPED: ${e.message}`);
      for (const tier of TIERS) man.tiers[tier].layers.push({ ...entry(tier), missing: true, error: e.message, source: path.relative(ART, cands[0]), tiles: [] });
      continue;
    }
    if (L.opaque) forceOpaque(hi.img);
    for (const tier of TIERS) {
      if (!opt.tiers.includes(tier)) { if (keep(tier)) man.tiers[tier].layers.push(keep(tier)); continue; }
      removeStale(tier, L.id);
      const tex = alphaBleed(tierTexture(L, tier, hi.img));
      if (L.opaque) forceOpaque(tex);
      const tiles = tileLayer(L, tier, tex);
      const srcBuf = fs.readFileSync(cands[0]);
      man.tiers[tier].layers.push({ ...entry(tier), source: path.relative(ART, cands[0]), sourceSha256: sha256(srcBuf), sourceNote: hi.note, tiles });
      const kept = tiles.filter(t => !t.empty);
      console.log(`  ${L.id.padEnd(7)} ${tier.padEnd(4)} ${String(kept.length).padStart(2)}/${tiles.length} tiles  ${(kept.reduce((a, t) => a + t.bytes, 0) / 1048576).toFixed(2).padStart(6)} MB png  from ${path.relative(ART, cands[0])} (${hi.note})`);
    }
  }
  // ---- sprite atlas: bled per region (a region must only ever sample its own colour); an 'extend' region (the
  // vignette) runs to its rect edge and is sampled through its sampleRect (out/sprites.json from layers/sprites.js)
  const aCands = sourceCandidates('sprites', R, idx);
  const A = R.atlas;
  if (aCands.length) {
    const img = readPNG(aCands[0]);
    const metaFile = path.join(OUT, path.basename(aCands[0], '.png') + '.json');
    const meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, 'utf8')) : null;
    const sample = {}, lowSample = {}, srcSha = sha256(fs.readFileSync(aCands[0]));
    if (meta && meta.regions) for (const [k, r] of Object.entries(meta.regions)) if (r.sampleRect) {
      sample[k] = r.sampleRect; lowSample[k] = r.lowSampleRect || [Math.ceil(r.sampleRect[0] / 2), Math.ceil(r.sampleRect[1] / 2), Math.floor(r.sampleRect[2] / 2), Math.floor(r.sampleRect[3] / 2)];
    }
    // sprites.json is written with the PNG by `node layers/sprites.js` (render.js sprites runs it): a mismatch means
    // the atlas was re-rendered some other way and its sampleRects may be stale
    if (!meta) console.log(`  atlas   WARN no ${path.relative(ART, metaFile)}: run \`node render.js sprites\` (the vignette sampleRect comes from it)`);
    else if (meta.sha256 && meta.sha256 !== srcSha) console.log(`  atlas   WARN ${path.relative(ART, metaFile)} sha256 ${meta.sha256.slice(0, 8)} does not match ${path.relative(ART, aCands[0])} (${srcSha.slice(0, 8)}): re-render with \`node render.js sprites\``);
    if (img.width !== A.size[0] || img.height !== A.size[1]) console.log(`  atlas   SKIPPED: ${path.relative(ART, aCands[0])} is ${img.width}x${img.height}, the contract says ${A.size.join('x')}`);
    else {
      man.atlas = { source: path.relative(ART, aCands[0]), sourceSha256: srcSha, regions: A.regions, sampleRects: sample, lowSampleRects: lowSample, tiers: {} };
      for (const tier of TIERS) {
        const [w, h] = tier === 'HIGH' ? A.size : A.lowSize, k = w / A.size[0];
        const tex = tier === 'HIGH' ? { width: w, height: h, data: new Uint8Array(img.data) } : resample(img, w, h);
        let bled = 0;
        for (const [, r] of Object.entries(A.regions)) {
          const [x, y, rw, rh] = r.map(v => Math.round(v * k));
          if (tier === 'HIGH' && !blackNextToContent(tex, x, y, rw, rh)) continue;   // the painter already bled it: keep its pixels
          pasteRGBA(tex, alphaBleed(cutWithGutter(tex, x, y, rw, rh, 0)), x, y); bled++;
        }
        const file = `tiles/${tier}/atlas.png`, buf = writePNG(path.join(ROBLOX, file), tex, { alpha: true });
        man.atlas.tiers[tier] = { file, image: [w, h], scale: k, bytes: buf.length, sha256: sha256(buf) };
        console.log(`  atlas   ${tier.padEnd(4)} ${w}x${h}  ${(buf.length / 1048576).toFixed(2)} MB png  from ${path.relative(ART, aCands[0])} (${bled} regions bled here)`);
      }
    }
  } else {
    console.log(`  atlas   MISSING: no out/${A.file} (the client falls back to no ambient sprites until it exists)`);
    if (old && old.atlas) man.atlas = old.atlas;
  }
  // ---- budget (RGBA8 bytes of every uploaded image, gutters included)
  for (const tier of TIERS) {
    let bytes = 0, n = 0, dropped = 0;
    for (const L of man.tiers[tier].layers) for (const t of L.tiles) { if (t.empty) { dropped++; continue; } bytes += t.image[0] * t.image[1] * 4; n++; }
    const at = man.atlas && man.atlas.tiers[tier]; if (at) bytes += at.image[0] * at.image[1] * 4;
    const mb = bytes / 1048576, budget = R.tiers[tier].budgetMB;
    man.budget[tier] = { images: n + (at ? 1 : 0), droppedEmpty: dropped, textureMB: +mb.toFixed(2), withMipsMB: +(mb * 4 / 3).toFixed(2), budgetMB: budget, ok: mb * 4 / 3 <= budget };
    console.log(`  budget  ${tier.padEnd(4)} ${n} tiles + ${at ? 1 : 0} atlas (${dropped} empty dropped): ${mb.toFixed(1)} MB, ${(mb * 4 / 3).toFixed(1)} MB with mips, budget ${budget} MB ${man.budget[tier].ok ? 'OK' : 'OVER'}`);
  }
  const hashes = [];
  for (const tier of TIERS) for (const L of man.tiers[tier].layers) for (const t of L.tiles) if (t.sha256) hashes.push(t.sha256);
  if (man.atlas) for (const tier of TIERS) if (man.atlas.tiers[tier]) hashes.push(man.atlas.tiers[tier].sha256);
  man.version = sha256(Buffer.from(hashes.join('\n'))).slice(0, 12);
  fs.writeFileSync(MANIFEST, JSON.stringify(man, null, 1) + '\n');
  console.log(`manifest ${path.relative(ART, MANIFEST)}  version ${man.version}  (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
  return check(R) ? 0 : 1;
}

function removeStale(tier, id) {
  const dir = path.join(TILE_DIR, tier);
  if (!fs.existsSync(dir)) return;
  for (const f of fs.readdirSync(dir)) if (new RegExp(`^${id}_\\d+_\\d+\\.png$`).test(f)) fs.unlinkSync(path.join(dir, f));
}

// ==================================================================================================== verification
/** Re-read every tile: size <= 1024, image = rect + gutters, content matches the tier texture exactly, gutters hold the
 *  neighbours' pixels, no alpha-0 pixel next to content is black, the layout covers the layer with no gap. */
function check(R) {
  if (!fs.existsSync(MANIFEST)) { console.log('check: no manifest'); return false; }
  const man = JSON.parse(fs.readFileSync(MANIFEST, 'utf8')), RC = require(path.join(ART, 'camera.js'));
  let checks = 0, fails = 0;
  const ok = (c, m) => { checks++; if (!c) { fails++; if (fails < 30) console.log('  FAIL', m); } };
  for (const tier of TIERS) for (const E of man.tiers[tier].layers) {
    if (E.missing) continue;
    const L = R.layers.find(l => l.id === E.id), g = L.tiles.gutter;
    ok(JSON.stringify(E.size) === JSON.stringify(L.size), `${E.id} size matches realm.json`);
    // layout: local rects tile the layer exactly
    let area = 0;
    for (const t of E.tiles) area += t.local.w * t.local.h;
    ok(Math.abs(area - L.size[0] * L.size[1]) < 1e-6, `${tier} ${E.id} tiles cover the layer (${area} vs ${L.size[0] * L.size[1]})`);
    const rects = RC.tileRects(L, tier);
    ok(rects.length === E.tiles.length, `${tier} ${E.id} tile count`);
    // rebuild the tier texture from the tiles (inner rects) and compare against a fresh cut of the source
    const src = fs.existsSync(path.join(ART, E.source)) ? readPNG(path.join(ART, E.source)) : null;
    if (!src || sha256(fs.readFileSync(path.join(ART, E.source))) !== E.sourceSha256) { console.log(`  note: ${E.source} changed since tiling; skipping pixel checks for ${tier} ${E.id}`); continue; }
    let hi = src.width === L.grid.HIGH.texture[0] ? src : resample(src, ...L.grid.HIGH.texture);
    if (L.opaque) forceOpaque(hi);
    let tex = tier === 'HIGH' ? hi : resample(hi, ...L.grid.LOW.texture);
    if (L.opaque) forceOpaque(tex);
    for (const t of E.tiles) {
      const r = rects.find(q => q.i === t.i && q.j === t.j);
      ok(r && r.tex.w === t.rectSize[0] && r.tex.h === t.rectSize[1], `${tier} ${E.id} ${t.i},${t.j} rect`);
      if (t.empty) { ok(maxAlpha(tex, r.tex.x, r.tex.y, r.tex.w, r.tex.h) < 2, `${tier} ${E.id} ${t.i},${t.j} empty really empty`); continue; }
      const buf = fs.readFileSync(path.join(ROBLOX, t.file));
      ok(sha256(buf) === t.sha256, `${t.file} sha256`);
      const img = decodePNG(buf);
      ok(img.width === r.tex.w + 2 * g && img.height === r.tex.h + 2 * g && img.width <= 1024 && img.height <= 1024, `${t.file} dims ${img.width}x${img.height}`);
      let bad = 0, black = 0, badA = 0;
      for (let v = 0; v < img.height; v++) for (let u = 0; u < img.width; u++) {
        const sx = Math.min(tex.width - 1, Math.max(0, r.tex.x + u - g)), sy = Math.min(tex.height - 1, Math.max(0, r.tex.y + v - g));
        const s = (sy * tex.width + sx) * 4, o = (v * img.width + u) * 4, a = tex.data[s + 3];
        if (img.data[o + 3] !== a) badA++;
        else if (a > 0 && (img.data[o] !== tex.data[s] || img.data[o + 1] !== tex.data[s + 1] || img.data[o + 2] !== tex.data[s + 2])) bad++;
        if (a === 0 && img.data[o] + img.data[o + 1] + img.data[o + 2] === 0) {
          // transparent black is only acceptable where no visible pixel is within 2 px
          let near = false;
          for (let dv = -2; dv <= 2 && !near; dv++) for (let du = -2; du <= 2; du++) {
            const qu = u + du, qv = v + dv; if (qu < 0 || qv < 0 || qu >= img.width || qv >= img.height) continue;
            if (img.data[(qv * img.width + qu) * 4 + 3] > 0) { near = true; break; }
          }
          if (near) black++;
        }
      }
      ok(badA === 0 && bad === 0, `${t.file}: ${badA} alpha / ${bad} colour mismatches vs the tier texture (content + gutter)`);
      ok(black === 0, `${t.file}: ${black} transparent-black pixels next to content (alpha bleed)`);
    }
  }
  if (man.atlas) for (const tier of TIERS) {
    const at = man.atlas.tiers[tier]; if (!at) continue;
    const buf = fs.readFileSync(path.join(ROBLOX, at.file));
    ok(sha256(buf) === at.sha256, `${at.file} sha256`);
    const img = decodePNG(buf); ok(img.width === at.image[0] && img.height === at.image[1], `${at.file} dims`);
    for (const [k, r] of Object.entries(man.atlas.regions)) {
      const [x, y, w, h] = r.map(v => Math.round(v * at.scale));
      ok(!blackNextToContent(img, x, y, w, h), `${at.file} region ${k}: transparent black next to content (alpha bleed)`);
    }
  }
  for (const tier of TIERS) ok(man.budget[tier].ok, `${tier} texture budget ${man.budget[tier].withMipsMB} <= ${man.budget[tier].budgetMB} MB`);
  console.log(`check: ${checks - fails}/${checks} passed${fails ? ` (${fails} FAILED)` : ''}`);
  return fails === 0;
}

module.exports = { decodePNG, encodePNG, readPNG, writePNG, resample, alphaBleed, premul, unpremul, cutWithGutter, maxAlpha, sha256, pasteRGBA, blackNextToContent,
  painterIndex, sourceCandidates, highTexture, loadRealm, ART, OUT, MANIFEST };

if (require.main === module) process.exit(run(process.argv.slice(2)));
