// NODE_PATH=<dir with playwright> node art/vector/build.mjs
//   art/icons/<name>.png     512px, for Roblox Decals
//   art/icons/ui/<name>.png  128px, embedded in docs/preview.html
//   art/icons_sheet.png      review sheet: every icon large, then at UI sizes on tiles
// Fails if any icon's pixels reach the outer 2% of its canvas (clipping).
import { ICONS } from './icons.mjs';
import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(process.env.NODE_PATH ? join(process.env.NODE_PATH, 'x') : import.meta.url);
const { chromium } = require('playwright');
const out = join(here, 'out'), ui = join(out, 'ui');
mkdirSync(ui, { recursive: true });

const b = await chromium.launch();
const p = await b.newPage();
const names = Object.keys(ICONS);
const bad = [];
for (const k of names) {
  for (const [px, dir] of [[512, out], [128, ui]]) {
    await p.setContent(`<body style="margin:0;background:transparent">${ICONS[k].replace('width="128" height="128"', `width="${px}" height="${px}"`)}</body>`);
    await p.locator('svg').screenshot({ path: join(dir, k + '.png'), omitBackground: true });
  }
  // clipping check: bounding box of visible pixels at 512px
  const bb = await p.evaluate(async svg => {
    const img = new Image(); img.src = 'data:image/svg+xml;base64,' + btoa(svg); await img.decode();
    const c = document.createElement('canvas'); c.width = c.height = 512; const g = c.getContext('2d'); g.drawImage(img, 0, 0, 512, 512);
    const d = g.getImageData(0, 0, 512, 512).data; let x0 = 512, y0 = 512, x1 = 0, y1 = 0;
    for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) if (d[(y * 512 + x) * 4 + 3] > 8) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    return [x0, y0, x1, y1];
  }, ICONS[k].replace('width="128" height="128"', 'width="512" height="512"'));
  if (bb[0] < 10 || bb[1] < 10 || bb[2] > 501 || bb[3] > 501) bad.push(`${k} ${bb}`);
}

const tile = (c, k, s) => `<div style="width:${s + 8}px;height:${s + 8}px;display:grid;place-items:center;border-radius:7px;border:2.5px solid ${c};background:radial-gradient(circle at 50% 38%,#fff 0,${c}44 45%,${c}88 100%);box-shadow:0 0 0 2px #0008">${ICONS[k].replace('width="128" height="128"', `width="${s}" height="${s}"`)}</div>`;
await p.setViewportSize({ width: 1400, height: 100 });
await p.setContent(`<body style="margin:0;padding:20px;background:#2e3036;font:600 13px sans-serif;color:#b9bdc8">
<div style="display:grid;grid-template-columns:repeat(8,160px);gap:12px">${names.map(k => `<div style="text-align:center">${ICONS[k].replace('width="128" height="128"', 'width="160" height="160"')}<div>${k}</div></div>`).join('')}</div>
<div style="margin-top:20px;display:flex;flex-wrap:wrap;gap:12px;align-items:center;background:#3a3c43;padding:14px;border-radius:10px">
${names.map(k => tile('#9aa0ab', k, 44)).join('')}</div>
<div style="margin-top:12px;display:flex;flex-wrap:wrap;gap:10px;align-items:center;background:#3a3c43;padding:14px;border-radius:10px">
${names.map(k => ICONS[k].replace('width="128" height="128"', 'width="18" height="18"')).join('')}</div></body>`);
await p.screenshot({ path: join(here, 'out/sheet.png'), fullPage: true });
await b.close();
console.log('built', names.length, 'icons');
if (bad.length) { console.error('CLIPPING:\n' + bad.join('\n')); process.exit(1); }
