const { chromium } = require('playwright');
(async () => { const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
 const p = await b.newPage({ viewport: { width: 1200, height: 900 } }); const errs=[]; p.on('pageerror', e=>errs.push(e.message));
 await p.goto('file:///home/user/research-calculator/ideas/algorithm-lab.html');
 const cards = await p.$$('.card');
 for (let k = 50; k < 100; k += 5) { await cards[k].scrollIntoViewIfNeeded(); await p.waitForTimeout(2500); }
 const shots = [];
 for (let k = 50; k < 100; k++) { const c = await cards[k].$('canvas'); await c.screenshot({ path: `p${k}.png` }); }
 console.log('errors', errs); await b.close(); })();
