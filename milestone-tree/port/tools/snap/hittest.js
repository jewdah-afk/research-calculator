// hittest.js - which object takes a click at each map node's centre, the way the engine picks it: the topmost
// Active object (buttons are Active) that is not under Interactable = false. A node whose own Hit button does not
// win is reported with the object that took the click.
//
//   cd port && NODE_PATH=$(npm root -g) node tools/snap/hittest.js [scene] [WxH]
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const path = require('path');
const R = require('./render.js');
const PORT = path.join(__dirname, '..', '..');

(async () => {
  const scene = process.argv[2] || 'home', size = process.argv[3] || '1920x1080';
  const text = execFileSync(process.env.LUAU || 'luau', ['tools/snap/snap.luau', '-a', scene, size], { cwd: PORT, maxBuffer: 1 << 28 }).toString();
  const dump = JSON.parse(text.split('\n').find(l => l.startsWith('{"scene"')));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: dump.w, height: dump.h } });
  await page.route('http://snap.local/**', r => R.serveRoute(r));
  await page.goto('http://snap.local/');
  await page.evaluate(([d, a, i]) => SNAP.draw(d, a, i), [dump, R.assetMap(), R.insets(dump.w, dump.h)]);
  const res = await page.evaluate(() => {
    const pathOf = e => { const n = []; for (let x = e; x && x.dataset && x.dataset.name; x = x.parentElement) n.unshift(x.dataset.name); return n.join('/'); };
    const out = [];
    for (const hit of document.querySelectorAll('[data-name="Hit"]')) {
      const node = hit.closest('[data-name^="Node_"]');
      if (!node || getComputedStyle(hit).display === 'none' || hit.offsetParent === null) continue;
      const r = hit.getBoundingClientRect();
      if (r.width < 1) continue;
      const x = r.left + r.width / 2, y = r.top + r.height / 2;
      if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) continue;
      const stack = document.elementsFromPoint(x, y);
      const winner = stack.find(e => e.dataset && e.dataset.active === '1' && !e.closest('[data-noint="1"]'));
      out.push({ node: node.dataset.name, ok: winner === hit, size: Math.round(r.width), by: winner ? pathOf(winner) : '(nothing: the map)' });
    }
    // every other button on screen (panel, HUD, overlays): does a click at its centre reach it?
    for (const b of document.querySelectorAll('[data-active="1"]')) {
      if (b.closest('[data-name^="Node_"]')) continue;
      if (b.closest('[data-noint="1"]') || b.offsetParent === null || getComputedStyle(b).visibility === 'hidden') continue;
      const r = b.getBoundingClientRect();
      if (r.width < 4 || r.height < 4) continue;
      const x = r.left + r.width / 2, y = r.top + r.height / 2;
      if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) continue;
      const winner = document.elementsFromPoint(x, y).find(e => e.dataset && e.dataset.active === '1' && !e.closest('[data-noint="1"]'));
      const ok = winner === b || (winner && b.contains(winner));
      out.push({ node: pathOf(b), ok, size: Math.round(r.width), by: winner ? pathOf(winner) : '(nothing)', button: true });
    }
    return out;
  });
  const nodes = res.filter(r => !r.button), buttons = res.filter(r => r.button);
  for (const r of nodes) console.log(`${r.ok ? 'ok  ' : 'BLOCKED'} ${r.node.padEnd(10)} hit ${r.size}px ${r.ok ? '' : 'by ' + r.by}`);
  console.log(`${nodes.filter(r => r.ok).length}/${nodes.length} nodes take their own click`);
  for (const r of buttons) if (!r.ok) console.log(`BLOCKED button ${r.node}  by ${r.by}`);
  console.log(`${buttons.filter(r => r.ok).length}/${buttons.length} other buttons take their own click`);
  await browser.close();
})();
