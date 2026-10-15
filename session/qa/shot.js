const { chromium } = require('playwright');
(async () => { const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(()=>chromium.launch());
 const p = await b.newPage({ viewport: { width: 1200, height: 900 } });
 const errs=[]; p.on('pageerror', e=>errs.push(e.message));
 await p.goto('file:///home/user/research-calculator/ideas/algorithm-lab.html');
 for (let y=0;y<16000;y+=700){ await p.evaluate(v=>window.scrollTo(0,v), y); await p.waitForTimeout(500); }
 await p.evaluate(()=>window.scrollTo(0,0)); await p.waitForTimeout(800);
 await p.screenshot({ path: 'lab2.png', fullPage: true }); console.log('errors', errs); await b.close(); })();
