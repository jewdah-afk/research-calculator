// node art/vector/embed.mjs docs/preview.html : replaces the IMG map with the vector set
import { ICONS } from './icons.mjs';
import { readFileSync, writeFileSync } from 'node:fs';
const f = process.argv[2], s = readFileSync(f, 'utf8');
const map = Object.fromEntries(Object.entries(ICONS).map(([k, v]) => [k, 'data:image/svg+xml;base64,' + Buffer.from(v).toString('base64')]));
const out = s.replace(/^const IMG=\{.*\};?$/m, () => 'const IMG=' + JSON.stringify(map) + ';');
if (out === s) throw new Error('IMG line not found');
writeFileSync(f, out);
