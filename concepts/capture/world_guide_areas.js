const { chromium } = require('playwright');
const fs = require('fs');
const OUT = process.argv[2], URL = process.argv[3];
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1600, height: 1100 } });
  p.setDefaultTimeout(240000);
  p.on('pageerror', e => console.log('ERR', String(e).slice(0,200)));
  await p.goto(URL, { waitUntil: 'load', timeout: 120000 });
  await p.waitForTimeout(6000);
  await p.evaluate(() => { const real = performance.now.bind(performance); window.__frozen = null; performance.now = () => (window.__frozen ?? real()); window.__real = real; });
  await p.addStyleTag({ content: '#toast,#hud{display:none!important}' });
  const box = await (await p.$('#stage')).boundingBox();
  const ev = (f, a) => p.evaluate(f, a);
  const snap = () => ev(() => { if (flight) { controls.target.copy(flight.to); const sph = new THREE.Spherical(flight.r1, flight.p1, flight.a1); camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(sph)); controls.update(); flight = null; } });
  const shot = async (name, force) => { const f = `${OUT}/${name}.jpg`; if (!force && fs.existsSync(f)) { console.log('skip', name); return; } const t0 = Date.now(); await p.screenshot({ path: f, type: 'jpeg', quality: 86, clip: box }); console.log(name, Date.now() - t0); };
  const setHour = h => ev(h => { hour = h; applyHour(h); }, h);
  const fly = (a, d, pol) => ev(([a, d, pol]) => flyTo(new THREE.Vector3(wx(a.cx), 0, wz(a.cz)), d, pol, 0), [a, d, pol]).then(snap);
  const isl = await ev(() => ISL.map(x => ({ id: x.id, n: x.n, cx: x.cx, cz: x.cz })));
  const LV = await ev(() => LEVELS);
  await setHour(11);
  for (const n of LV) { await ev(n => { resetTo(n); camTop(); }, n); await snap(); await shot(`world_step_${String(n).padStart(2,'0')}`, false); }
  await setHour(1); await shot('world_night', true);
  await setHour(18.5); await shot('world_golden', false);
  for (let k = 0; k < isl.length; k++) {
    const a = isl[k];
    await ev(() => resetTo(LEVELS[LEVELS.length-1]));
    await setHour(11); await fly(a, 300, 0.95); await shot(`${a.id}_day`, true);
    await setHour(1); await shot(`${a.id}_night`, true);
    await setHour(11); await fly(a, 620, 0.62); await shot(`${a.id}_context`, true);
    if (k > 0) {
      await ev(n => resetTo(n), isl[k-1].n);
      await fly(a, 420, 0.8); await shot(`${a.id}_before`, true);
      await ev(() => { window.__frozen = window.__real(); });
      await ev(n => unlock(n), a.n); await ev(() => { flight = null; }); await fly(a, 420, 0.8);
      const adv = s => ev(s => { window.__frozen += s * 1000; }, s);
      await adv(0.5); await p.waitForTimeout(300); await shot(`${a.id}_unlock_a`, true);
      await adv(0.7); await p.waitForTimeout(300); await shot(`${a.id}_unlock_b`, true);
      await adv(6); await p.waitForTimeout(300); await shot(`${a.id}_after`, true);
      await ev(() => { window.__frozen = null; });
    }
  }
  console.log('DONE');
  await b.close();
})();
