// node art/vector/embed.mjs docs/preview.html : embeds art/icons/ui/*.png (128px) into the page's IMG map
import { ICONS } from './icons.mjs';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const dir = join(dirname(fileURLToPath(import.meta.url)), '../icons/ui');
const f = process.argv[2], s = readFileSync(f, 'utf8');
const map = Object.fromEntries(Object.keys(ICONS).map(k => [k, 'data:image/png;base64,' + readFileSync(join(dir, k + '.png')).toString('base64')]));
const out = s.replace(/^const IMG=\{.*\};?$/m, () => 'const IMG=' + JSON.stringify(map) + ';');
if (out === s) throw new Error('IMG line not found');
writeFileSync(f, out);
