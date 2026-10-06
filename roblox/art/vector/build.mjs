// node art/vector/build.mjs  ->  art/icons/*.png (256px), art/icons_sheet.png
import { ICONS } from './icons.mjs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(process.env.NODE_PATH ? join(process.env.NODE_PATH, 'x') : import.meta.url);
const { chromium } = require('playwright');
const b = await chromium.launch();
const p = await b.newPage({ deviceScaleFactor: 2 });
for (const [k, s] of Object.entries(ICONS)) {
  await p.setContent(`<body style="margin:0;background:transparent">${s}</body>`);
  await p.locator('svg').screenshot({ path: join(here, '../icons', k + '.png'), omitBackground: true });
}
const names = Object.keys(ICONS);
await p.setViewportSize({ width: 1180, height: 100 });
await p.setContent(`<body style="margin:0;padding:20px;background:#2e3036;display:grid;grid-template-columns:repeat(8,128px);gap:16px">
${names.map(k => `<div>${ICONS[k]}</div>`).join('')}
<div style="grid-column:1/-1;display:flex;gap:10px;align-items:center;background:#3a3c43;padding:10px;border-radius:8px">
${names.map(k => ICONS[k].replace('width="128" height="128"', 'width="24" height="24"')).join('')}</div></body>`);
await p.screenshot({ path: join(here, '../icons_sheet.png'), fullPage: true });
await b.close();
console.log('built', names.length);
