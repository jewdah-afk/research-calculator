// snap.js - run art/marketing/snap_mk.luau (the real client on the mock engine, with a camera) and draw its PlayerGui
// dumps in headless Chromium with port/tools/snap/page.js (served through render.js's serveRoute).
//
//   node lib/snap.js still --scene s13_none --cam 1500,1200,0.8 [--hide hud,plates] [--size 1920x1080] --out a.png
//   node lib/snap.js clip  --scene s13_none --cam "x,y,z>x,y,z" --frames 90 --fps 30 [--hide ...] --outdir dir
//
// --hide takes screen names (HudGui, TopbarGui, OverlayGui, MarkerGui, PanelGui) or the shorthands
// hud (all HUD screens but the panel), toasts (OverlayGui), plates (the node name plates), plate_<id> (one plate),
// fx (the particle fields), links.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), readline = require('readline'), { spawn } = require('child_process');
const MK = path.join(__dirname, '..'), PORT = path.join(MK, '..', '..', 'port');
const { assetMap, insets, serveRoute } = require(path.join(PORT, 'tools', 'snap', 'render.js'));

const SHORT = { hud: ['HudGui', 'TopbarGui', 'OverlayGui', 'MarkerGui'], toasts: ['OverlayGui'], topbar: ['TopbarGui'], dock: ['HudGui'] };
function hideCss(hide) {
  const rules = [];
  for (const h of hide) {
    if (h === 'plates') rules.push('[data-name="Plates"]');
    else if (h === 'fx') rules.push('[data-name="F_particles"]');
    else if (h === 'links') rules.push('[data-name="Links"]');
    else if (/^plate_/.test(h)) rules.push(`[data-name="Plate_${h.slice(6)}"]`); // one node's name plate
    else for (const n of SHORT[h] || [h]) rules.push(`.screen[data-name="${n}"]`);
  }
  return rules.length ? `${rules.join(',')}{display:none!important}` : '';
}

// stream snap_mk.luau's JSON lines; onDump(dump) is awaited in order
async function runLuau(args, onDump) {
  const luau = process.env.LUAU || 'luau';
  const child = spawn(luau, [path.join(MK, 'snap_mk.luau'), '-a', ...args], { cwd: PORT });
  const closed = new Promise(r => child.on('close', r));
  let err = '';
  child.stderr.on('data', d => { err += d; });
  const rl = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
  let n = 0;
  const other = [];
  for await (const line of rl) {
    if (line.startsWith('{"scene"')) { await onDump(JSON.parse(line)); n++; }
    else if (line.trim()) other.push(line);
  }
  const code = await closed;
  if (!n) throw new Error(`snap_mk produced no dump (exit ${code})\n${other.slice(0, 20).join('\n')}\n${err.slice(0, 2000)}`);
  return n;
}

async function openPage(browser, w, h) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  page.on('pageerror', e => console.log('pageerror', e.message));
  await page.route('http://snap.local/**', route => serveRoute(route));
  await page.goto('http://snap.local/');
  await page.addStyleTag({ content: '#hide{}' });
  return page;
}
async function drawDump(page, dump, hide) {
  const res = await page.evaluate(async ([d, a, i, css]) => {
    const r = await SNAP.draw(d, a, i);
    let st = document.getElementById('mkhide');
    if (!st) { st = document.createElement('style'); st.id = 'mkhide'; document.head.appendChild(st); }
    st.textContent = css;
    return r;
  }, [dump, assetMap(), insets(dump.w, dump.h), hideCss(hide)]);
  if (res.missing.length) console.log('missing assets', res.missing.slice(0, 6).join(' '));
  return res;
}

async function still({ scene, cam = 'keep', size = '1920x1080', hide = [], out }) {
  const [w, h] = size.split('x').map(Number);
  const browser = await chromium.launch();
  const page = await openPage(browser, w, h);
  await runLuau([scene, size, cam], async dump => {
    await drawDump(page, dump, hide);
    await page.waitForTimeout(80);
    await page.screenshot({ path: out, type: out.endsWith('.jpg') ? 'jpeg' : 'png', quality: out.endsWith('.jpg') ? 92 : undefined });
  });
  await browser.close();
  console.log(`still ${scene} ${cam} -> ${out}`);
}

async function clip({ scene, cam = 'keep', size = '1920x1080', hide = [], frames, fps, outdir }) {
  const [w, h] = size.split('x').map(Number);
  fs.mkdirSync(outdir, { recursive: true });
  const browser = await chromium.launch();
  const page = await openPage(browser, w, h);
  let i = 0;
  const t0 = Date.now();
  await runLuau([scene, size, cam, `clip:${frames}:${fps}`], async dump => {
    await drawDump(page, dump, hide);
    await page.screenshot({ path: path.join(outdir, `f${String(i).padStart(4, '0')}.jpg`), type: 'jpeg', quality: 95 });
    i++;
    if (i % 30 === 0) console.log(`  ${outdir}: ${i}/${frames} (${((Date.now() - t0) / i / 1000).toFixed(2)} s/frame)`);
  });
  await browser.close();
  console.log(`clip ${scene} ${cam} -> ${outdir} (${i} frames)`);
}

function parseArgs(argv) {
  const o = { hide: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { o._ = a; continue; }
    const k = a.slice(2), v = argv[++i];
    if (k === 'hide') o.hide = v.split(',').filter(Boolean);
    else if (k === 'frames' || k === 'fps') o[k] = +v;
    else o[k] = v;
  }
  return o;
}
if (require.main === module) {
  const o = parseArgs(process.argv.slice(2));
  (o._ === 'clip' ? clip(o) : still(o)).catch(e => { console.error(e.stack || e.message); process.exit(1); });
}
module.exports = { still, clip, runLuau, openPage, drawDump, hideCss };
