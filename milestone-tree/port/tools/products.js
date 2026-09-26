// products.js - create the game passes and developer products of src/shared/Products.luau on Roblox (Open Cloud)
// and write their ids back into that file.
//
//   cd port && node tools/products.js --universe 10767974455 [--dry-run]
//
// The API key (the proxy injects it for apis.roblox.com) needs the "game-pass" and "developer-product" read + write
// permissions for the experience (Creator Dashboard > Open Cloud > API Keys > the key > Access Permissions).
// Items that already have an id are skipped; an item whose name already exists on the experience is adopted (no
// duplicate). Icons: art/products/<key>.png (tools/product_icons.js).
if (!process.env.NODE_USE_ENV_PROXY) {
  // Node's fetch ignores HTTPS_PROXY unless this is set: run again with it
  const r = require('child_process').spawnSync(process.execPath, process.argv.slice(1), { stdio: 'inherit', env: { ...process.env, NODE_USE_ENV_PROXY: '1' } });
  process.exit(r.status ?? 1);
}
const fs = require('fs'), path = require('path');
const LUAU = path.join(__dirname, '..', '..', 'src', 'shared', 'Products.luau');
const ICONS = path.join(__dirname, '..', '..', 'art', 'products');
const API = 'https://apis.roblox.com';

const args = process.argv.slice(2);
const uni = args[args.indexOf('--universe') + 1];
const dry = args.includes('--dry-run');
if (!/^\d+$/.test(uni || '')) { console.error('usage: node tools/products.js --universe <id> [--dry-run]'); process.exit(2); }

// the items as written in Products.luau: { key, kind: pass | product, name, price, blurb, id }
function items() {
  const src = fs.readFileSync(LUAU, 'utf8');
  const out = [];
  const re = /\{ key = "(\w+)", id = (nil|\d+), name = "([^"]+)", price = (\d+)[^}]*?blurb = "([^"]+)"/g;
  const passesAt = src.indexOf('Products.passes'), productsAt = src.indexOf('Products.products');
  for (let m; (m = re.exec(src));) {
    out.push({ key: m[1], id: m[2] === 'nil' ? null : +m[2], name: m[3].replace(' · ', ' - '), price: +m[4], blurb: m[5],
      kind: m.index > productsAt ? 'product' : m.index > passesAt ? 'pass' : null });
  }
  return out.filter(i => i.kind);
}
function writeId(key, id) {
  const src = fs.readFileSync(LUAU, 'utf8');
  const next = src.replace(new RegExp(`(\\{ key = "${key}", id = )(nil|\\d+)`), `$1${id}`);
  if (next === src) throw new Error('could not write the id of ' + key);
  fs.writeFileSync(LUAU, next);
}

async function call(method, url, body) {
  const res = await fetch(url, { method, body });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { }
  if (!res.ok) throw new Error(`${method} ${url} -> ${res.status} ${text.slice(0, 400)}`);
  return json;
}
// the experience's existing passes / products (name -> id)
async function existing(kind) {
  const names = {};
  const base = kind === 'pass' ? `${API}/game-passes/v1/universes/${uni}/game-passes/creator`
    : `${API}/developer-products/v2/universes/${uni}/developer-products/creator`;
  let cursor = '';
  for (let page = 0; page < 20; page++) {
    const j = await call('GET', base + (cursor ? `?pageToken=${encodeURIComponent(cursor)}` : ''));
    const list = j.gamePasses || j.developerProducts || j.data || [];
    for (const it of list) names[it.name] = it.gamePassId || it.productId || it.id;
    cursor = j.nextPageToken || '';
    if (!cursor) break;
  }
  return names;
}
async function create(it) {
  const form = new FormData();
  form.append('name', it.name);
  form.append('description', it.blurb);
  form.append('price', String(it.price));
  form.append('isForSale', 'true');
  const icon = path.join(ICONS, it.key + '.png');
  if (fs.existsSync(icon)) form.append('imageFile', new Blob([fs.readFileSync(icon)], { type: 'image/png' }), it.key + '.png');
  const url = it.kind === 'pass' ? `${API}/game-passes/v1/universes/${uni}/game-passes`
    : `${API}/developer-products/v2/universes/${uni}/developer-products`;
  const j = await call('POST', url, form);
  const id = j && (j.gamePassId || j.productId || j.id);
  if (!id) throw new Error('no id in the answer: ' + JSON.stringify(j).slice(0, 300));
  return id;
}

(async () => {
  const list = items();
  console.log(`${list.length} items in Products.luau (universe ${uni})${dry ? ' - dry run' : ''}`);
  const have = { pass: null, product: null };
  let failed = 0;
  for (const it of list) {
    if (it.id) { console.log(`  = ${it.key}: already ${it.id}`); continue; }
    try {
      if (have[it.kind] === null) have[it.kind] = await existing(it.kind);
      let id = have[it.kind][it.name];
      if (id) console.log(`  ~ ${it.key}: "${it.name}" exists on the experience (${id}), adopted`);
      else if (dry) { console.log(`  + ${it.key}: would create ${it.kind} "${it.name}" for R$ ${it.price}`); continue; }
      else { id = await create(it); console.log(`  + ${it.key}: created ${it.kind} ${id} "${it.name}" R$ ${it.price}`); }
      writeId(it.key, id);
    } catch (e) {
      failed++;
      console.error(`  ! ${it.key}: ${e.message}`);
    }
  }
  if (failed) { console.error(`${failed} failed`); process.exit(1); }
})();
