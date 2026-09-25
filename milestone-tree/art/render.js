// Render a painted layer (layers/*.js) in headless Chromium.
//
//   node render.js <layer> [scale]            -> out/<layer>.png + out/<layer>_prev.png   (the painter's own output, as before)
//   node render.js <layer> --tier HIGH|LOW    -> also out/<id>_<TIER>.png at exactly size x res[TIER] (realm.json)
//   node render.js all [--tier ...]           every realm.json layer that has a painter, back to front (+ the sprite atlas)
//   node render.js <layer> --no-render        only re-run the contract checks on the existing out/<layer>.png
//
// <layer> is a realm.json id (sky, clouds, far, mid, near, world, fg), a painter file name (distant, rocks), or any
// LAYERS.<key> a painter registers (sprites). The page gets lib.js, window.REALM (realm.json) and window.REALM_TIER, then
// the painter; LAYERS[<key>]() returns the canvas. Painters draw the HIGH texture (size x res.HIGH); LOW is a 2x
// premultiplied box downsample of it (exactly what roblox/tile.js does). [scale] is accepted for old callers and ignored.
// After rendering, the contract checks from REALM.md 3 and 7 run: texture size, keep-clear zones (hard / soft alpha
// limits per layer), empty tiles. They warn; they never fail the render.
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
const T = require('./roblox/tile.js');

const ART = __dirname, OUT = path.join(ART, 'out');
const R = JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8'));

function parse(argv) {
  const o = { names: [], tiers: [], render: true, prev: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--tier') o.tiers.push(...argv[++i].toUpperCase().split(','));
    else if (a.startsWith('--tier=')) o.tiers.push(...a.slice(7).toUpperCase().split(','));
    else if (a === '--no-render') o.render = false;
    else if (a === '--no-prev') o.prev = false;
    else if (/^[\d.]+$/.test(a)) { /* legacy [scale]: painters own their resolution now */ }
    else o.names.push(a);
  }
  for (const t of o.tiers) if (!['HIGH', 'LOW'].includes(t)) throw new Error('--tier must be HIGH or LOW');
  return o;
}

/** name -> { key (LAYERS key to call), file (painter), layer (realm.json entry or null), out (output basename) } */
function resolve(name, idx) {
  const byId = R.layers.find(l => l.id === name);
  const byFile = R.layers.find(l => l.file && path.basename(l.file, '.js') === name);
  let layer = byId || byFile || null;
  // a painter file named <name>.js that registers the key of a realm layer (distant.js registers LAYERS.far)
  const own = path.join(ART, 'layers', name + '.js');
  if (!layer && fs.existsSync(own)) {
    const src = fs.readFileSync(own, 'utf8');
    layer = R.layers.find(l => new RegExp(`LAYERS\\s*\\.\\s*${l.id}\\s*=(?!=)`).test(src)) || null;
  }
  const keys = [name, layer && layer.id].filter(Boolean);
  let file = null, key = null;
  if (fs.existsSync(own)) { file = own; key = keys.find(k => (idx[k] || []).includes(name + '.js')) || name; }
  if (!file && layer && layer.file && fs.existsSync(path.join(ART, layer.file))) { file = path.join(ART, layer.file); key = layer.id; }
  if (!file) for (const k of keys) if (idx[k]) { file = path.join(ART, 'layers', idx[k][0]); key = k; break; }
  if (!file) throw new Error(`no painter for "${name}": expected layers/${name}.js or a file registering LAYERS.${layer ? layer.id : name}`);
  return { key, file, layer, out: name };
}

async function paint(browser, job) {
  const page = await browser.newPage();
  page.on('console', m => console.log('[page]', m.text()));
  page.on('pageerror', e => console.log('[err]', e.message));
  await page.setContent('<html><body></body></html>');
  await page.evaluate(([realm, tier]) => { window.REALM = realm; window.REALM_TIER = tier; }, [R, 'HIGH']);
  await page.addScriptTag({ content: fs.readFileSync(path.join(ART, 'lib.js'), 'utf8') });
  await page.addScriptTag({ content: fs.readFileSync(job.file, 'utf8') });
  const t0 = Date.now();
  const url = await page.evaluate(async k => {
    if (typeof LAYERS[k] !== 'function') throw new Error('LAYERS.' + k + ' is not registered');
    const c = await LAYERS[k](); window.__last = window.__last || c;
    return (c || window.__last).toDataURL('image/png');
  }, job.key);
  await page.close();
  return { buf: Buffer.from(url.split(',')[1], 'base64'), ms: Date.now() - t0 };
}

function preview(img, file) {
  const w = 1600, h = Math.round(1600 * img.height / img.width), s = T.resample(img, w, h), bg = [7, 5, 13];
  for (let i = 0; i < w * h; i++) {
    const o = i * 4, a = s.data[o + 3] / 255;
    for (let k = 0; k < 3; k++) s.data[o + k] = Math.round(s.data[o + k] * a + bg[k] * (1 - a));
    s.data[o + 3] = 255;
  }
  T.writePNG(file, s, { alpha: false });
}

/** REALM.md 3 + 7 checks on a HIGH texture. Returns lines to print. */
function contractChecks(L, img) {
  const msg = [], [tw, th] = L.grid.HIGH.texture, s = L.res.HIGH;
  if (img.width !== tw || img.height !== th) msg.push(`WARN size ${img.width}x${img.height}; the contract texture is ${tw}x${th} (size ${L.size.join('x')} x res ${s})` +
    (Math.abs(img.width / img.height - tw / th) < 0.004 ? ' - same aspect, the tiler will resample it' : ' - WRONG ASPECT, the tiler will skip this layer'));
  else msg.push(`ok   size ${tw}x${th}`);
  if (Math.abs(img.width / img.height - tw / th) > 0.004) return msg;
  const k = img.width / L.size[0];                     // texture px per local px
  const rule = { mid: { hard: 0.3 }, near: { hard: 0.004, soft: 0.35 }, fg: { hard: 0.004, soft: 0.25 } }[L.id];
  if (rule && L.keepClear) {
    for (const kind of ['hard', 'soft']) {
      if (rule[kind] == null) continue;
      let worst = 0, where = null;
      for (const [node, cx, cy, rx, ry] of L.keepClear[kind]) {
        const x0 = Math.max(0, Math.floor((cx - rx) * k)), x1 = Math.min(img.width - 1, Math.ceil((cx + rx) * k));
        const y0 = Math.max(0, Math.floor((cy - ry) * k)), y1 = Math.min(img.height - 1, Math.ceil((cy + ry) * k));
        for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
          const u = (x / k - cx) / rx, v = (y / k - cy) / ry; if (u * u + v * v > 1) continue;
          const a = img.data[(y * img.width + x) * 4 + 3] / 255;
          if (a > worst) { worst = a; where = node; }
        }
      }
      msg.push(`${worst <= rule[kind] ? 'ok  ' : 'WARN'} keep-clear ${kind}: max alpha ${worst.toFixed(3)} (limit ${rule[kind]})${worst > rule[kind] ? ' behind node ' + where : ''}`);
    }
  }
  if (!L.opaque) {
    const rects = require('./camera.js').tileRects(L, 'HIGH'); let empty = 0;
    if (img.width === tw) for (const r of rects) if (T.maxAlpha(img, r.tex.x, r.tex.y, r.tex.w, r.tex.h) < 2) empty++;
    let cover = 0; for (let i = 3; i < img.data.length; i += 4) if (img.data[i] >= 2) cover++;
    msg.push(`info coverage ${(100 * cover / (img.width * img.height)).toFixed(1)}% of pixels visible, ${empty}/${rects.length} HIGH tiles empty`);
  } else {
    let hole = 0; for (let i = 3; i < img.data.length; i += 4) if (img.data[i] !== 255) hole++;
    msg.push(`${hole ? 'WARN' : 'ok  '} opaque layer: ${hole} non-opaque pixels`);
  }
  return msg;
}

(async () => {
  const opt = parse(process.argv.slice(2));
  if (!opt.names.length) { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(0, 14).join('\n')); process.exit(2); }
  const idx = T.painterIndex();
  let names = opt.names;
  if (names.includes('all')) {
    names = R.layers.map(l => l.id).filter(id => { try { resolve(id, idx); return true; } catch (e) { console.log('skip', id + ':', e.message); return false; } });
    if (idx.sprites) names.push('sprites'); else if (idx.atlas) names.push('atlas');
  }
  const jobs = names.map(n => resolve(n, idx));
  fs.mkdirSync(OUT, { recursive: true });
  let browser = null;
  for (const job of jobs) {
    const pngFile = path.join(OUT, job.out + '.png');
    let img;
    if (opt.render) {
      browser = browser || await chromium.launch({ args: ['--js-flags=--max-old-space-size=4096'] });
      const { buf, ms } = await paint(browser, job);
      fs.writeFileSync(pngFile, buf);
      img = T.decodePNG(buf);
      console.log(`${job.out} rendered in ${ms} ms (${path.relative(ART, job.file)} LAYERS.${job.key}) -> out/${job.out}.png ${img.width}x${img.height}`);
    } else {
      const src = (job.layer && T.sourceCandidates(job.layer.id, R, idx)[0]) || pngFile;
      img = T.readPNG(src);
      console.log(`${job.out}: ${path.relative(ART, src)} ${img.width}x${img.height}`);
    }
    if (opt.prev) preview(img, path.join(OUT, job.out + '_prev.png'));
    const L = job.layer;
    if (L) for (const line of contractChecks(L, img)) console.log('  ' + line);
    else if (job.key === 'sprites' || job.key === 'atlas') console.log(`  ${img.width === R.atlas.size[0] && img.height === R.atlas.size[1] ? 'ok  ' : 'WARN'} atlas ${img.width}x${img.height} (contract ${R.atlas.size.join('x')})`);
    for (const tier of opt.tiers) {
      if (!L) { console.log(`  --tier ignored for ${job.out}: not a realm.json layer`); continue; }
      const [tw, th] = L.grid[tier].texture;
      let hi = img.width === L.grid.HIGH.texture[0] && img.height === L.grid.HIGH.texture[1] ? img : T.resample(img, ...L.grid.HIGH.texture);
      const out = tier === 'HIGH' ? hi : T.resample(hi, tw, th);
      const f = path.join(OUT, `${L.id}_${tier}.png`);
      T.writePNG(f, out, { alpha: L.opaque ? false : 'auto' });
      console.log(`  ${tier} texture ${tw}x${th} -> out/${L.id}_${tier}.png`);
    }
  }
  if (browser) await browser.close();
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
