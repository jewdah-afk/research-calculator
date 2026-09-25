// vfx.js - the VFX sprite atlas (1024 x 1024, white / greyscale so the client tints them with ImageColor3, except
// the stone shards and chain bits, which keep their own colour). Sprites are shelf-packed with 4 px padding; build.js
// writes their rects into ui.json -> atlas.sprites (ImageRectOffset / ImageRectSize).
const VFX_SPRITES = [
  ['sweep', 128, 512, (x, w, h) => KIT.fx.sweep(x, 0, 0, w, h)],
  ['flare', 512, 96, (x, w, h) => KIT.fx.flare(x, 0, 0, w, h)],
  ['ring', 256, 256, (x, w, h) => KIT.fx.ring(x, w / 2, h / 2, w / 2 - 2, 14)],
  ['ring_thin', 256, 256, (x, w, h) => KIT.fx.ring(x, w / 2, h / 2, w / 2 - 2, 5)],
  ['glow', 128, 128, (x, w, h) => KIT.fx.glow(x, w / 2, h / 2, w / 2)],
  ['star', 128, 128, (x, w, h) => KIT.fx.star(x, w / 2, h / 2, w / 2 - 2, 4)],
  ['glint', 96, 96, (x, w, h) => { KIT.fx.star(x, w / 2, h / 2, w / 2 - 2, 4); KIT.fx.star(x, w / 2, h / 2, w * 0.28, 4, Math.PI / 4); }],
  ['streak', 256, 48, (x, w, h) => KIT.fx.streak(x, 0, 0, w, h)],
  ['shimmer', 256, 32, (x, w, h) => KIT.fx.shimmer(x, 0, 0, w, h)],
  ['ember', 32, 32, (x, w, h) => { KIT.fx.glow(x, 16, 16, 16); blob(x, 16, 16, 3, [255, 255, 255], 1); }],
  ['spark', 48, 48, (x, w, h) => { KIT.fx.glow(x, 24, 24, 24); KIT.fx.star(x, 24, 24, 20, 4); }],
  ...[0, 1, 2, 3, 4, 5].map(i => [`rune${i}`, 96, 96, (x, w, h) => KIT.fx.rune(x, w / 2, h / 2, w * 0.32, i)]),
  ...[0, 1, 2, 3, 4, 5].map(i => [`shard_stone${i}`, 64, 64, (x, w, h) => KIT.fx.shard(x, w / 2, h / 2, w * 0.42, 100 + i, 'stone')]),
  ...[0, 1, 2, 3].map(i => [`shard_crystal${i}`, 48, 80, (x, w, h) => KIT.fx.shard(x, w / 2, h / 2, w * 0.4, 200 + i, 'crystal')]),
  ['link', 72, 56, async (x, w, h, A) => { const im = await A.img('chain'); x.drawImage(im, 256 - 36, 32 - 28, 72, 56, 0, 0, 72, 56); }],
  ['link_half', 44, 56, async (x, w, h, A) => { const im = await A.img('chain'); x.drawImage(im, 256 - 36, 32 - 28, 44, 56, 0, 0, 44, 56); }],
];

async function VFX_ATLAS(A, size = 1024, pad = 4) {
  const c = canvas(size, size), x = c.getContext('2d'), rects = {};
  const list = VFX_SPRITES.slice().sort((a, b) => b[2] - a[2]);
  let cx = pad, cy = pad, row = 0;
  for (const [name, w, h, draw] of list) {
    if (cx + w + pad > size) { cx = pad; cy += row + pad; row = 0; }
    if (cy + h + pad > size) throw new Error('vfx atlas overflow at ' + name);
    const s = canvas(w, h), sx = s.getContext('2d');
    await draw(sx, w, h, A);
    x.drawImage(s, cx, cy);
    rects[name] = [cx, cy, w, h];
    cx += w + pad; row = Math.max(row, h);
  }
  return { canvas: c, rects };
}
