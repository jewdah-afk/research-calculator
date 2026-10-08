const { chromium } = require('playwright');
const OUT = process.argv[2], URL = process.argv[3], ONLY = process.argv[4];
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1600, height: 1100 } });
  p.setDefaultTimeout(240000);
  await p.goto(URL, { waitUntil: 'load', timeout: 120000 });
  await p.waitForTimeout(6000);
  await p.addStyleTag({ content: '#toast,#hud{display:none!important}' });
  const box = await (await p.$('#stage')).boundingBox();
  const ev = (f, a) => p.evaluate(f, a);
  const place = (k) => ev(k => { if (flight) { controls.target.copy(flight.to); camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(new THREE.Spherical(flight.r1, flight.p1, flight.a1))); flight = null; }
    const off = camera.position.clone().sub(controls.target); const sph = new THREE.Spherical().setFromVector3(off); sph.radius *= k; sph.phi = 0.42; camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(sph)); camera.fov = 54; camera.updateProjectionMatrix(); controls.update(); }, k);
  const shot = async n => { await p.screenshot({ path: `${OUT}/${n}.jpg`, type: 'jpeg', quality: 86, clip: box }); console.log(n); };
  const LV = await ev(() => LEVELS);
  await ev(() => { hour = 11; applyHour(11); });
  for (const n of LV) { if (ONLY && +ONLY !== n) continue; await ev(n => { resetTo(n); camTop(); }, n); await place(0.4); await shot(`world_step_${String(n).padStart(2,'0')}`); }
  if (!ONLY) { await ev(() => { hour = 1; applyHour(1); }); await shot('world_night'); await ev(() => { hour = 18.5; applyHour(18.5); }); await shot('world_golden'); }
  await b.close();
})();
