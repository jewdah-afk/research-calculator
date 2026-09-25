// pieces.js - the UI kit's piece table: how each final image is made from the Blender renders (out/3d/*, the metal
// and set gems) and the painters in kit.js (fills, bodies, stone, textures, glitch). build.js runs every entry in
// headless Chromium and writes out/pieces/<name>.png plus its ui.json manifest entry.
//
// Every piece is authored at 2x the 1080p display size (scale 2). Kinds:
//   slice : 9-slice (Roblox ScaleType.Slice). slice = [left, top, right, bottom] insets in image px;
//           SliceCenter = Rect(left, top, w - right, h - bottom), SliceScale = 1 / scale.
//   image : a standalone ornament shown at size / scale; anchor = the image px that sits on its reference point
//           (the frame corner, the rim centre line, the socket centre).
//   tile  : ScaleType.Tile with TileSize = size / scale (seamless).
// Atlas sprites (the VFX) are listed separately in build.js.
const PIECES = [];
const LAYER_KEYS = ['m', 'p', 'cp'];
const piece = (o) => PIECES.push(o);

// shared helpers ---------------------------------------------------------------------------------------------------
async function put3d(x, A, name, dx = 0, dy = 0) { const im = await A.img(name); x.drawImage(im, dx, dy); return im; }
function anchorOf(meta, lx = 0, ly = 0) { const [x0, , , y1] = meta.rect; return [Math.round((lx - x0) * meta.px), Math.round((y1 - ly) * meta.px)]; }
function tinted(T, k, t0 = 0.2, t1 = 0.1) {   // a card body: the layer body leaning toward its hue
  return Object.assign({}, T, { body: [KIT.mixh(T.body[0], T.hue, t0), KIT.mixh(T.body[1], T.hue, t1), T.body[2]] });
}
const WARM = { body: ['#2b1f0f', '#1b140b', '#100b06'], wash: '#ffcf6a', hue: '#ffcf6a' };
const NEUTRAL = { body: ['#1a1524', '#110e19', '#0a0810'], wash: '#9d8cff', hue: '#b9a8ff' };
const CR_POST = (x, w, h, seed, region) => {   // the corrupted treatment: cracked metal, toxic light, torn rows
  const G = UI_THEMES.cp.glitch;
  KIT.cracksOver(x, w, h, { seed, n: 6, hue: UI_THEMES.cp.hue, region });
  KIT.glitch(x.canvas, { seed: seed + 7, slices: 7, shift: 9, split: 2, blocks: 22, hue: UI_THEMES.cp.hue, alt: G.alt, cyan: G.cyan, scan: 0.1, region });
};

for (const L of LAYER_KEYS) {
  const T = UI_THEMES[L], cr = !!T.glitch;

  // panel: body + inner shadow + inlay light + the 3D rim (the frame 9-slice)
  piece({ name: `panel_${L}`, w: 256, h: 256, kind: 'slice', slice: [48, 48, 48, 48], async paint(x, A) {
    const m = await A.meta(`rim_${L}`);
    KIT.body(x, KIT.inset(m.fill, -3), T, { wash: 0, shadow: 0.75, shadowBlur: 30, glow: 0, grain: 0.03, seed: 3 });
    KIT.glowStroke(x, KIT.inset(m.fill, 16), T.hue, 3, 5, 0.55);
    KIT.glowStroke(x, KIT.inset(m.fill, 17), T.hue, 1.2, 0.6, 0.35);
    await put3d(x, A, `rim_${L}`);
    if (cr) {   // torn rows along the rim; pixel blocks only in the four unstretched corner cells of the 9-slice
      KIT.glitch(x.canvas, { seed: 77, slices: 3, shift: 5, split: 1.5, blocks: 0, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0, region: [0, 0, 256, 40] });
      KIT.glitch(x.canvas, { seed: 79, slices: 3, shift: 5, split: 0, blocks: 0, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0, region: [0, 214, 256, 40] });
      const R = rng(78);
      for (const [cx, cy] of [[0, 0], [208, 0], [0, 208], [208, 208]]) for (let i = 0; i < 4; i++) {
        x.fillStyle = KIT.c([T.hue, T.glitch.alt, T.glitch.cyan, '#fff'][Math.floor(R() * 4)], 0.85);
        x.fillRect(cx + 4 + Math.floor(R() * 20) * 2, cy + 4 + Math.floor(R() * 20) * 2, 2 + Math.floor(R() * 4) * 2, 2 + Math.floor(R() * 2) * 2);
      }
    }
  } });

  // body texture: large low-contrast crystal facets, a nebula drift of the hue, star specks (CR: scanlines + data noise)
  piece({ name: `tex_${L}`, w: 512, h: 512, kind: 'tile', async paint(x) {
    const W = 512, R = rng(L.charCodeAt(0) * 7 + 3), V = KIT.voronoiTile(W, W, 11, 40 + L.length), F = KIT.pfbm(9 + L.charCodeAt(0), 3, 4);
    const img = x.createImageData(W, W), d = img.data, H = hex(T.hue), shade = []; for (let i = 0; i < 11; i++) shade.push(R() * 2 - 1);
    for (let y = 0; y < W; y++) for (let xx = 0; xx < W; xx++) {
      const i = y * W + xx, o = i * 4, s = shade[V.id[i]], e = V.edge[i];
      const neb = Math.max(0, F(xx / W * 3, y / W * 3) + 0.1);
      let r = 0, g = 0, b = 0, a = 0;
      const add = (c, al) => { const na = al + a * (1 - al); if (na <= 0) return; r = (c[0] * al + r * a * (1 - al)) / na; g = (c[1] * al + g * a * (1 - al)) / na; b = (c[2] * al + b * a * (1 - al)) / na; a = na; };
      add(H, neb * 0.10);
      if (s > 0) add([255, 255, 255], s * 0.028); else add([0, 0, 0], -s * 0.10);
      if (e < 1.6) add(mix(H, [255, 255, 255], 0.5), (1 - e / 1.6) * 0.07);
      d[o] = r; d[o + 1] = g; d[o + 2] = b; d[o + 3] = a * 255;
    }
    x.putImageData(img, 0, 0);
    for (let i = 0; i < 70; i++) { const sx = R() * W, sy = R() * W, k = R(); blob(x, sx, sy, 0.8 + k * 1.6, mix(H, [255, 255, 255], 0.7), 0.25 + 0.5 * k); }
    for (let i = 0; i < 4; i++) sparkle(x, 30 + R() * (W - 60), 30 + R() * (W - 60), 6 + R() * 6, mix(H, [255, 255, 255], 0.6), 0.5, R());
    if (cr) {
      x.fillStyle = 'rgba(0,0,0,0.16)'; for (let y = 0; y < W; y += 4) x.fillRect(0, y, W, 1.5);
      for (let i = 0; i < 60; i++) { const bx = Math.floor(R() * 64) * 8, by = Math.floor(R() * 64) * 8; x.fillStyle = KIT.c(R() < 0.8 ? T.hue : T.glitch.alt, 0.05 + 0.07 * R()); x.fillRect(bx, by, 8 * (1 + Math.floor(R() * 4)), 4); }
      x.fillStyle = KIT.c(T.hue, 0.05); for (let gx = 0; gx < W; gx += 32) x.fillRect(gx, 0, 1, W); for (let gy = 0; gy < W; gy += 32) x.fillRect(0, gy, W, 1);
    }
  } });

  // header band: hue light from the left behind the emblem + title, fine engraved hatching, a glowing base line
  piece({ name: `header_${L}`, w: 512, h: 160, kind: 'slice', slice: [320, 40, 40, 40], async paint(x) {
    const g = x.createLinearGradient(0, 0, 512, 0);
    g.addColorStop(0, KIT.c(T.hue, 0.30)); g.addColorStop(0.45, KIT.c(T.hue, 0.12)); g.addColorStop(0.62, KIT.c(T.hue, 0.03)); g.addColorStop(1, KIT.c(T.hue, 0));
    x.fillStyle = g; x.fillRect(0, 0, 512, 160);
    const v = x.createLinearGradient(0, 0, 0, 160); v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,0.25)');
    x.fillStyle = v; x.fillRect(0, 0, 512, 160);
    x.save(); x.beginPath(); x.rect(0, 0, 512, 160); x.clip(); x.strokeStyle = 'rgba(255,255,255,0.035)'; x.lineWidth = 12;
    for (let i = -10; i < 30; i++) { x.beginPath(); x.moveTo(i * 28, 170); x.lineTo(i * 28 + 80, -10); x.stroke(); }
    x.restore();
    x.save(); x.globalCompositeOperation = 'destination-in'; const f = x.createLinearGradient(0, 0, 512, 0); f.addColorStop(0, '#000'); f.addColorStop(0.7, 'rgba(0,0,0,0.6)'); f.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = f; x.fillRect(0, 0, 512, 160); x.restore();
    const lg = x.createLinearGradient(0, 0, 512, 0); lg.addColorStop(0, KIT.c(T.hue, 1)); lg.addColorStop(0.6, KIT.c(T.hue, 0.35)); lg.addColorStop(1, KIT.c(T.hue, 0));
    KIT.blurInto(x, y => { y.fillStyle = lg; y.fillRect(0, 154, 512, 4); }, 5, 'lighter', 0.8);
    x.fillStyle = lg; x.fillRect(0, 155, 512, 2);
  } });

  for (const w of ['tl', 'tr', 'bl', 'br']) {
    piece({ name: `corner_${L}_${w}`, w: 384, h: 384, kind: 'image', async paint(x, A) {
      await put3d(x, A, `corner_${L}_${w}`);
      if (cr) CR_POST(x, 384, 384, { tl: 1, tr: 2, bl: 3, br: 4 }[w] * 13, [40, 40, 304, 304]);
    }, anchor: async A => anchorOf(await A.meta(`corner_${L}_${w}`)) });
  }
  piece({ name: `crest_${L}`, w: 320, h: 204, kind: 'image', async paint(x, A) {
    await put3d(x, A, `crest_${L}`);
    if (cr) CR_POST(x, 320, 204, 91, [20, 20, 280, 170]);
  }, anchor: async A => anchorOf(await A.meta(`crest_${L}`), 0, -0.12) });

  // emblem medallion: painted crystal dome under the 3D sunburst ring (the layer letter is a TextLabel over it)
  piece({ name: `medal_${L}`, w: 256, h: 256, kind: 'image', async paint(x, A) {
    KIT.dome(x, 128, 128, 76, T.hue, { seed: 7 });
    await put3d(x, A, `medal_${L}`);
    if (cr) CR_POST(x, 256, 256, 55, [10, 10, 236, 236]);
  }, anchor: () => [128, 128] });

  piece({ name: `socket_${L}`, w: 128, h: 128, kind: 'image', async paint(x, A) {
    KIT.dome(x, 64, 64, 35, T.hue, { seed: 9, bright: 1.15, facets: 10 });
    await put3d(x, A, `socket_${L}`);
  }, anchor: () => [64, 64] });

  // tab treatment A (active): the lit gem plate behind the active label
  piece({ name: `tabA_${L}`, w: 320, h: 96, kind: 'slice', slice: [56, 40, 56, 40], async paint(x, A) {
    const m = await A.meta(`tab_a_${L}`);
    KIT.crystalPlate(x, KIT.inset(m.fill, -1), T.hue, { seed: 4, facets: 6, sparkles: 2 });
    await put3d(x, A, `tab_a_${L}`);
    if (cr) KIT.glitch(x.canvas, { seed: 5, slices: 3, shift: 6, split: 1.5, blocks: 6, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0.12 });
  } });
  // tab treatment B (active): the raised crystal segment
  piece({ name: `tabB_${L}`, w: 256, h: 96, kind: 'slice', slice: [40, 40, 40, 40], async paint(x, A) {
    const m = await A.meta(`tab_b_${L}`);
    KIT.crystalPlate(x, KIT.inset(m.fill, -1), T.hue, { seed: 6, facets: 5, sparkles: 2, bright: 1.1 });
    await put3d(x, A, `tab_b_${L}`);
    if (cr) KIT.glitch(x.canvas, { seed: 8, slices: 3, shift: 6, split: 1.5, blocks: 6, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0.12 });
  } });
  // primary call to action (PRESTIGE / GET +1 / CORRUPT)
  piece({ name: `btn_${L}`, w: 512, h: 160, kind: 'slice', slice: [84, 60, 84, 60], async paint(x, A) {
    const m = await A.meta(`button_${L}`);
    KIT.crystalPlate(x, KIT.inset(m.fill, -2), T.hue, { seed: 12, facets: 9, sparkles: 3, bright: 1.05, deep: 0.55 });
    await put3d(x, A, `button_${L}`);
    if (cr) KIT.glitch(x.canvas, { seed: 13, slices: 4, shift: 8, split: 2, blocks: 10, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0.1 });
  } });
  // BUYABLE card plate: the layer's crystal body, slim gold rim with a glowing inlay (the socket sits on it)
  piece({ name: `card_${L}`, w: 192, h: 192, kind: 'slice', slice: [44, 44, 44, 44], async paint(x, A) {
    const m = await A.meta(`card_rim_${L}`);
    KIT.body(x, KIT.inset(m.fill, -2), tinted(T), { wash: 0.2, shadow: 0.55, shadowBlur: 18, glow: 0, grain: 0.03, seed: 5 });
    KIT.glowStroke(x, KIT.inset(m.fill, 9), T.hue, 3, 5, 0.7);
    await put3d(x, A, `card_rim_${L}`);
    if (cr) KIT.glitch(x.canvas, { seed: 17, slices: 3, shift: 4, split: 1.2, blocks: 0, hue: T.hue, alt: T.glitch.alt, cyan: T.glitch.cyan, scan: 0 });
  } });
}

// ---------------------------------------------------------------------------------------------------------- shared
piece({ name: 'card_owned', w: 192, h: 192, kind: 'slice', slice: [48, 48, 48, 48], async paint(x, A) {
  const m = await A.meta('card_gilded');
  KIT.body(x, KIT.inset(m.fill, -2), WARM, { wash: 0.16, shadow: 0.6, shadowBlur: 20, glow: 0, grain: 0.03, seed: 8 });
  KIT.glowStroke(x, KIT.inset(m.fill, 12), '#ffcf6a', 2, 4, 0.35);
  await put3d(x, A, 'card_gilded');
} });
piece({ name: 'card_locked', w: 192, h: 192, kind: 'slice', slice: [44, 44, 44, 44], async paint(x) {
  KIT.stone(x, KIT.rectPoly(2, 2, 190, 190, 16), { seed: 12, base: '#2e2a37', bevel: 14, cracks: 2 });
  x.strokeStyle = 'rgba(0,0,0,0.9)'; x.lineWidth = 2; KIT.path(x, KIT.rectPoly(1, 1, 191, 191, 16)); x.stroke();
} });
piece({ name: 'tex_stone', w: 256, h: 256, kind: 'tile', async paint(x) {
  const F = KIT.pfbm(71, 4, 5), G = KIT.pfbm(72, 16, 3), img = x.createImageData(256, 256), d = img.data;
  for (let y = 0; y < 256; y++) for (let xx = 0; xx < 256; xx++) {
    const n = F(xx / 64, y / 64), p = G(xx / 16, y / 16), o = (y * 256 + xx) * 4;
    const v = n * 0.9 + Math.max(0, -p - 0.3) * -1.2;
    d[o] = d[o + 1] = v > 0 ? 255 : 0; d[o + 2] = v > 0 ? 250 : 0; d[o + 3] = Math.min(255, Math.abs(v) * 90);
  }
  x.putImageData(img, 0, 0);
} });
for (const n of ['seal_owned', 'seal_locked', 'socket_empty', 'dock_medal', 'coin', 'portal_ring', 'divider']) {
  piece({ name: n, w: null, h: null, from3d: n, kind: n === 'divider' ? 'slice' : 'image', slice: n === 'divider' ? [96, 31, 96, 31] : undefined,
    async paint(x, A) { await put3d(x, A, n); }, anchor: async A => n === 'divider' ? undefined : anchorOf(await A.meta(n)) });
}
piece({ name: 'chain', w: 512, h: 64, kind: 'tile', async paint(x, A) { await put3d(x, A, 'chain'); } });
piece({ name: 'close_btn', w: 128, h: 128, kind: 'image', async paint(x, A) {
  await put3d(x, A, 'close_btn');
  const X = (lw, col) => { x.strokeStyle = col; x.lineWidth = lw; x.lineCap = 'round'; x.beginPath(); x.moveTo(48, 48); x.lineTo(80, 80); x.moveTo(80, 48); x.lineTo(48, 80); x.stroke(); };
  x.save(); x.translate(0, 2); X(13, 'rgba(40,0,8,0.9)'); x.restore(); X(8, '#fff');
}, anchor: () => [64, 64] });
// treatment A: the engraved gold header strip the tabs sit in (a recessed dark slot inside the gilded moulding)
piece({ name: 'tabA_strip', w: 192, h: 192, kind: 'slice', slice: [48, 48, 48, 48], async paint(x, A) {
  const m = await A.meta('card_gilded');
  const p = KIT.inset(m.fill, -2), b = KIT.bbox(p);
  KIT.withClip(x, p, () => { const g = x.createLinearGradient(0, b.y0, 0, b.y1); g.addColorStop(0, '#040308'); g.addColorStop(1, '#100d18'); x.fillStyle = g; x.fillRect(0, 0, 192, 192); });
  KIT.innerShadow(x, p, 'rgba(0,0,0,0.95)', 16, 0, 5);
  await put3d(x, A, 'card_gilded');
} });
// treatment B: the relic bar (obsidian in a slim gold frame) + the stud divider between its segments
piece({ name: 'tabB_bar', w: 192, h: 192, kind: 'slice', slice: [40, 40, 40, 40], async paint(x, A) {
  const m = await A.meta('toast_frame');
  const p = KIT.inset(m.fill, -2), b = KIT.bbox(p);
  KIT.withClip(x, p, () => { const g = x.createLinearGradient(0, b.y0, 0, b.y1); g.addColorStop(0, '#1b1724'); g.addColorStop(0.5, '#0e0b15'); g.addColorStop(1, '#07060b'); x.fillStyle = g; x.fillRect(0, 0, 192, 192); });
  KIT.innerShadow(x, p, 'rgba(0,0,0,0.8)', 12, 0, 3);
  await put3d(x, A, 'toast_frame');
} });
piece({ name: 'tabB_div', w: 24, h: 96, kind: 'image', async paint(x) {
  KIT.goldRail(x, 9, 10, 6, 76, true);
  KIT.goldBead(x, 12, 48, 7);
}, anchor: () => [12, 48] });
piece({ name: 'plaque', w: 512, h: 144, kind: 'slice', slice: [64, 40, 64, 40], async paint(x, A) {
  const m = await A.meta('plaque');
  KIT.body(x, KIT.inset(m.fill, -3), NEUTRAL, { wash: 0.1, shadow: 0.7, shadowBlur: 18, glow: 0, grain: 0.03, seed: 4 });
  await put3d(x, A, 'plaque');
} });
piece({ name: 'shelf', w: 512, h: 176, kind: 'slice', slice: [56, 40, 56, 72], async paint(x, A) {
  const m = await A.meta('shelf');
  KIT.body(x, KIT.inset(m.fill, -3), NEUTRAL, { wash: 0.1, shadow: 0.7, shadowBlur: 18, glow: 0, grain: 0.03, seed: 6 });
  await put3d(x, A, 'shelf');
} });
piece({ name: 'toast', w: 192, h: 192, kind: 'slice', slice: [40, 40, 40, 40], async paint(x, A) {
  const m = await A.meta('toast_frame');
  KIT.body(x, KIT.inset(m.fill, -2), NEUTRAL, { wash: 0.12, shadow: 0.6, shadowBlur: 16, glow: 0, grain: 0.03, seed: 2 });
  await put3d(x, A, 'toast_frame');
} });
// soft drop shadow 9-slice behind every framed surface (offset down a little by the client)
piece({ name: 'shadow', w: 128, h: 128, kind: 'slice', slice: [56, 56, 56, 56], async paint(x) {
  x.shadowColor = 'rgba(0,0,0,0.85)'; x.shadowBlur = 26; x.fillStyle = '#000';
  x.fillRect(-200 + 40, 40, 48, 48); x.shadowOffsetX = 200; x.fillRect(-200 + 40, 40, 48, 48);
} });
// white soft glow 9-slice (tinted by the client: ImageColor3 = the layer hue) for lit cards / plates
piece({ name: 'glow9', w: 128, h: 128, kind: 'slice', slice: [56, 56, 56, 56], async paint(x) {
  x.shadowColor = 'rgba(255,255,255,1)'; x.shadowBlur = 22; x.shadowOffsetX = 1000; x.fillStyle = '#fff';
  x.fillRect(40 - 1000, 40, 48, 48); x.fillRect(40 - 1000, 40, 48, 48);
} });
// secondary gold call to action (DEACTIVATE, FINISH): the CTA frame with a gold crystal fill
piece({ name: 'btn_gold', w: 512, h: 160, kind: 'slice', slice: [84, 60, 84, 60], async paint(x, A) {
  const m = await A.meta('button_p');
  KIT.crystalPlate(x, KIT.inset(m.fill, -2), '#ffbe2e', { seed: 14, facets: 9, sparkles: 2, bright: 0.9, deep: 0.5 });
  await put3d(x, A, 'button_p');
} });
