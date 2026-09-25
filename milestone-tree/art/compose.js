// Composite the whole realm stack as the Roblox client would show it, at one camera (C, z) and viewport V.
//
//   node compose.js out.png --cx 1500 --cy 1150 --z 0.8 [--vw 1920 --vh 1080] [--tier HIGH|LOW] [--t 0]
//                           [--source tiles|layers] [--seams snap|overlap] [--nodes 0] [--rm] [--straight] [--dpr 1] [--quality 90]
//   node compose.js out.png camX camY [w h]        old form: a w x h view at zoom 1 whose top-left is world (camX, camY)
//
// It opens preview/realm.html headless and draws one deterministic frame, so the placement is exactly the client's:
// RealmCamera.layerOffset for the eight layers (dolly-law zoom per depth), sprites from spriteState at time --t, the
// particle fields, biome tint / wash (settled at the target weights), fg fade, vignette, and stand-in node plates.
// --source tiles (default when roblox/manifest.json exists) draws the uploaded tiles inside their gutters, placed by the
// snapped recipe of REALM.md 9.3 (a seam check; --seams overlap shows the retired 1-point overlap). --source layers
// draws the full renders. The camera is hard-clamped like the client. --straight draws what Roblox draws at transparent
// edges: straight-alpha textures, bilinear without mipmaps, SRC_ALPHA blending (REALM.md 9.8); the default is premultiplied.
// Several shots in one run: --shots shots.json   ([{ "out": "a.png", "cx": .., "cy": .., "z": .., "t": .. }, ...])
// The format follows the extension: .png (lossless), .jpg (--quality, default 90) or .webp (--quality, default 90;
// what the committed previews use, e.g. out/realm_overview.webp).
const fs = require('fs'); const path = require('path');
const { serve, launch, openRealm } = require('./preview/record.js');

function parse(argv) {
  const o = { out: null, cx: null, cy: null, z: null, vw: 1920, vh: 1080, tier: 'HIGH', t: 0, source: fs.existsSync(path.join(__dirname, 'roblox/manifest.json')) ? 'tiles' : 'layers', nodes: '1', rm: false, straight: false, dpr: 1, shots: null, seams: 'snap', quality: 90 };
  const pos = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const [k, inline] = a.slice(2).split('=');
      if (k === 'rm') { o.rm = true; continue; }
      if (k === 'straight') { o.straight = true; continue; }
      const v = inline != null ? inline : argv[++i];
      if (['cx', 'cy', 'z', 'vw', 'vh', 't', 'dpr', 'quality'].includes(k)) o[k] = +v; else if (k in o) o[k] = v; else throw new Error('unknown option --' + k);
    } else pos.push(a);
  }
  o.out = pos[0] || o.out;
  if (pos.length >= 3 && o.cx == null) { // legacy: top-left camera at zoom 1
    const [, x, y, w = 1920, h = 1080] = pos.map(Number); o.vw = w; o.vh = h; o.z = 1; o.cx = x + w / 2; o.cy = y + h / 2;
  }
  o.tier = o.tier.toUpperCase();
  return o;
}

async function main() {
  const o = parse(process.argv.slice(2));
  const shots = o.shots ? JSON.parse(fs.readFileSync(o.shots, 'utf8')) : [{ out: o.out, cx: o.cx, cy: o.cy, z: o.z, t: o.t }];
  if (!shots.every(s => s.out)) { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(0, 16).join('\n')); process.exit(2); }
  const srv = await serve(), browser = await launch();
  try {
    const { ctx, page, errs } = await openRealm(browser, srv.url, { w: o.vw, h: o.vh, dpr: o.dpr,
      q: { tier: o.tier, source: o.source, nodes: o.nodes, rm: o.rm ? '1' : '0', seams: o.seams, straight: o.straight ? '1' : '0' } });
    for (const s of shots) {
      const st = await page.evaluate(a => window.Realm.frame(a), { x: s.cx, y: s.cy, z: s.z, t: s.t || 0, settle: true });
      fs.mkdirSync(path.dirname(path.resolve(s.out)), { recursive: true });
      const ext = path.extname(s.out).toLowerCase(), q = Math.min(100, Math.max(1, s.quality || o.quality));
      if (ext === '.jpg' || ext === '.jpeg') await page.screenshot({ path: s.out, type: 'jpeg', quality: q });
      else if (ext === '.webp') {   // the GL canvas keeps its drawing buffer: encode it straight to WebP
        const url = await page.evaluate(q => document.getElementById('gl').toDataURL('image/webp', q / 100), q);
        if (!url.startsWith('data:image/webp')) throw new Error('this Chromium cannot encode WebP');
        fs.writeFileSync(s.out, Buffer.from(url.split(',')[1], 'base64'));
      } else await page.screenshot({ path: s.out, type: 'png' });
      console.log(`${s.out} (${(fs.statSync(s.out).size / 1024).toFixed(0)} KB): C (${st.C.x.toFixed(0)}, ${st.C.y.toFixed(0)}) z ${st.z.toFixed(3)}  rift ${st.w.rift.toFixed(2)} corrupt ${st.w.corrupt.toFixed(2)}${st.straight ? '  straight alpha' : ''}  ` +
        `${st.draws} draws  ${st.layers.map(l => l.id + ':' + (l.mode === 'tiles' ? l.tiles : l.mode)).join(' ')}  atlas ${st.atlas}`);
    }
    const real = errs.filter(e => !/status of 404/.test(e));   // optional files (out/sprites.png) probe with HEAD
    if (real.length) console.log('page errors:\n' + real.join('\n'));
    await ctx.close();
  } finally { await browser.close(); await srv.close(); }
}
main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
