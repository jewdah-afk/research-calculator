// UI extras: minimap, photo mode, title screen, colour grading, weather button.
const UIX = (() => {
    const R = WORLD.R;
    // ---------------- minimap ----------------
    // Same rotation as the camera, fixed scale, the whole archipelago. Tap to fly there.
    const mm = { s: 1, cx: 17.5, cy: 2.5, ox: 0, oy: 0 };
    function mmProject(x, y) {
        const phi = R.cam.angle + Math.PI / 4, c = Math.cos(phi), s = Math.sin(phi);
        const dx = x - mm.cx, dy = y - mm.cy;
        return [mm.ox + (dx * c - dy * s) * mm.s, mm.oy + (dx * s + dy * c) * 0.5 * mm.s];
    }
    function mmUnproject(px, py) {
        const phi = R.cam.angle + Math.PI / 4, c = Math.cos(phi), s = Math.sin(phi);
        const u = (px - mm.ox) / mm.s, v = (py - mm.oy) / (0.5 * mm.s);
        return [mm.cx + u * c + v * s, mm.cy - u * s + v * c];
    }
    function drawMinimap() {
        const cv = document.getElementById('minimap'); if (!cv || !cv.offsetParent) return;
        const dpr = Math.min(2, window.devicePixelRatio || 1), W0 = 180, H0 = 132;
        if (cv.width !== W0 * dpr) { cv.width = W0 * dpr; cv.height = H0 * dpr; }
        const g = cv.getContext('2d'); g.setTransform(dpr, 0, 0, dpr, 0, 0);
        const night = R.env.night;
        g.fillStyle = night > 0.5 ? '#123d63' : '#2aa9c9'; g.fillRect(0, 0, W0, H0);
        // fit every plot that exists on the map
        mm.s = 1; mm.ox = 0; mm.oy = 0;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const p of PLOTS.values()) for (const [x, y] of [[p.x0, p.y0], [p.x0 + 5, p.y0], [p.x0, p.y0 + 5], [p.x0 + 5, p.y0 + 5]]) { const q = mmProject(x, y); x0 = Math.min(x0, q[0]); x1 = Math.max(x1, q[0]); y0 = Math.min(y0, q[1]); y1 = Math.max(y1, q[1]); }
        mm.s = Math.min((W0 - 16) / (x1 - x0), (H0 - 16) / (y1 - y0));
        mm.ox = W0 / 2 - (x0 + x1) / 2 * mm.s; mm.oy = H0 / 2 - (y0 + y1) / 2 * mm.s;
        const built = R.builtCache();
        for (const p of PLOTS.values()) {
            const b = built.has(p.key), ghost = !b && R.plotVisibleGhost(p);
            if (!b && !ghost) continue;
            const q = [[p.x0 + 0.3, p.y0 + 0.3], [p.x0 + 4.7, p.y0 + 0.3], [p.x0 + 4.7, p.y0 + 4.7], [p.x0 + 0.3, p.y0 + 4.7]].map(([x, y]) => mmProject(x, y));
            g.beginPath(); g.moveTo(q[0][0], q[0][1]); for (let i = 1; i < 4; i++) g.lineTo(q[i][0], q[i][1]); g.closePath();
            if (b) { g.fillStyle = p.color; g.fill(); g.strokeStyle = INK; g.lineWidth = 1.2; g.stroke(); }
            else { g.setLineDash([2, 2]); g.strokeStyle = 'rgba(255,255,255,0.8)'; g.lineWidth = 1; g.stroke(); g.setLineDash([]); }
            if (typeof HUD !== 'undefined' && HUD.focus === p) { g.strokeStyle = '#fff'; g.lineWidth = 2; g.stroke(); }
        }
        // camera viewport
        const corners = [[0, 0], [R.W, 0], [R.W, R.H], [0, R.H]].map(([sx, sy]) => mmProject(...R.unproject(sx, sy)));
        g.beginPath(); g.moveTo(corners[0][0], corners[0][1]); for (let i = 1; i < 4; i++) g.lineTo(corners[i][0], corners[i][1]); g.closePath();
        g.fillStyle = 'rgba(255,255,255,0.15)'; g.fill(); g.strokeStyle = '#fff'; g.lineWidth = 1.5; g.stroke();
        if (typeof WALK !== 'undefined' && WALK.on) { const a = mmProject(WALK.A.x, WALK.A.y); g.fillStyle = '#ffd23f'; g.strokeStyle = INK; g.lineWidth = 1.5; g.beginPath(); g.arc(a[0], a[1], 3.5, 0, 7); g.fill(); g.stroke(); }
    }
    function bindMinimap() {
        const cv = document.getElementById('minimap'); if (!cv) return;
        cv.addEventListener('pointerdown', (e) => {
            const r = cv.getBoundingClientRect(); const z = r.width / 180;
            const [x, y] = mmUnproject((e.clientX - r.left) / z, (e.clientY - r.top) / z);
            if (typeof WALK !== 'undefined' && WALK.on) return;
            R.cam.tx = x; R.cam.ty = y; FX.sfx('camWhoosh', undefined, undefined, { vol: 0.5 }); if (!AUDIO.play) AUDIO.tap();
        });
    }

    // ---------------- photo mode ----------------
    const photo = {
        on: false, prevTilt: false,
        enter() {
            if (typeof WALK !== 'undefined' && WALK.on) WALK.exit();
            HUD.closeSheet(); HUD.closePanel();
            this.on = true; this.prevTilt = document.body.classList.contains('tilt');
            document.body.classList.add('photo', 'tilt');
            document.getElementById('pbTime').value = R.env.tod.toFixed(1);
            document.getElementById('pbTilt').textContent = 'TILT: ON';
            this.dayLen = R.env.dayLen; R.env.dayLen = 1e9;           // freeze the clock while framing
            AUDIO.open();
        },
        exit() {
            this.on = false; document.body.classList.remove('photo', 'photo-clean');
            document.body.classList.toggle('tilt', this.prevTilt || !!SETTINGS.get('tilt'));
            document.getElementById('world').className = '';
            R.env.dayLen = this.dayLen || SETTINGS.get('dayLen') * 60;
            AUDIO.close();
        },
        snap() {
            const src = document.getElementById('world');
            const c = document.createElement('canvas'); c.width = src.width; c.height = src.height; const g = c.getContext('2d');
            const f = src.className; const filt = { 'f-warm': 'sepia(.22) saturate(1.25) hue-rotate(-8deg)', 'f-cool': 'saturate(1.1) hue-rotate(12deg) brightness(1.03)', 'f-vivid': 'saturate(1.45) contrast(1.08)', 'f-noir': 'grayscale(1) contrast(1.2)' }[f];
            if (filt) g.filter = filt;
            g.drawImage(src, 0, 0); g.filter = 'none';
            const vg = g.createRadialGradient(c.width / 2, c.height * 0.55, c.height * 0.3, c.width / 2, c.height * 0.55, c.width * 0.7);
            vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(10,8,40,0.38)'); g.fillStyle = vg; g.fillRect(0, 0, c.width, c.height);
            g.font = `${Math.round(c.height * 0.035)}px "Luckiest Guy", sans-serif`; g.textAlign = 'right'; g.textBaseline = 'bottom'; g.lineWidth = c.height * 0.008; g.strokeStyle = INK; g.fillStyle = '#fff';
            g.strokeText('STUD CITY INCREMENTAL', c.width - 20, c.height - 16); g.fillText('STUD CITY INCREMENTAL', c.width - 20, c.height - 16);
            let url = ''; try { url = c.toDataURL('image/png'); } catch (e) { }
            R.flashScreen('rgba(255,255,255,0.8)'); FX.sfx('shutter'); if (!AUDIO.play) AUDIO.tap();
            META.bump('photos');
            if (!url) return;
            HUD.modal(`<div class="mh"><div class="t">SNAPSHOT</div><div class="s">Saved in this preview. Use DOWNLOAD to keep it.</div></div>
              <div style="padding:0 14px"><img src="${url}" alt="Snapshot" style="width:100%;border:3px solid #1b1530;border-radius:12px;display:block"></div>
              <div class="mfoot" style="padding-bottom:0"><a class="big" style="text-align:center;text-decoration:none" download="stud-city.png" href="${url}"><span>DOWNLOAD</span></a></div>`, [['CLOSE', 'max', null]]);
        },
    };
    function bindPhoto() {
        const $ = (id) => document.getElementById(id);
        $('pbTime').oninput = (e) => { R.env.tod = Number(e.target.value); };
        $('pbFilter').querySelectorAll('button').forEach(b => b.onclick = () => { $('pbFilter').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b)); $('world').className = b.dataset.f === 'none' ? '' : 'f-' + b.dataset.f; AUDIO.tap(); });
        $('pbTilt').onclick = () => { const on = !document.body.classList.contains('tilt'); document.body.classList.toggle('tilt', on); $('pbTilt').textContent = 'TILT: ' + (on ? 'ON' : 'OFF'); AUDIO.tap(); };
        $('pbHud').onclick = () => { document.body.classList.add('photo-clean'); setTimeout(() => window.addEventListener('pointerdown', () => document.body.classList.remove('photo-clean'), { once: true }), 50); };
        $('pbSnap').onclick = () => photo.snap();
        $('pbExit').onclick = () => photo.exit();
        $('pbTour').onclick = () => { if (typeof CINE !== 'undefined') CINE.tour(); };
    }

    // ---------------- colour grade ----------------
    // A soft-light layer tinted by time of day: warm at dawn and dusk, cool blue at night.
    function grade() {
        const el = document.getElementById('grade'); if (!el) return;
        if (!SETTINGS.get('grade')) { el.style.opacity = 0; return; }
        const t = R.env.tod; let col = 'rgb(255,255,255)', a = 0;
        if (t > 5 && t < 8.5) { col = '#ff9a5a'; a = 0.45 * (1 - Math.abs(t - 6.6) / 1.9); }
        else if (t > 16.5 && t < 20) { col = '#ff6a8a'; a = 0.5 * (1 - Math.abs(t - 18.4) / 1.9); }
        else if (R.env.night > 0.5) { col = '#3a4aff'; a = 0.28 * R.env.night; }
        el.style.background = col; el.style.opacity = Math.max(0, a).toFixed(2);
    }

    // ---------------- title screen ----------------
    const COLORS = ['#e8453c', '#ffd23f', '#4aa8ff', '#39d98a', '#ff9a2e', '#a855f7'];
    const TIPS = ['Laying the baseplates...', 'Tip: hold BUY to keep buying.', 'Tip: golden code bricks hide on the islands.', 'Tip: press V to walk around your city.', 'Tip: the dev bar can max the next plot for you.', 'Tip: the FX Lab shows every effect and how to build it in Roblox.', 'Tip: at night the lighthouse keeper has a secret.'];
    function buildLogo() {
        const mk = (row, text, small) => { const r = document.getElementById(row); let i = 0; for (const ch of text) { const b = document.createElement('span'); b.className = 'brick' + (ch === ' ' ? ' space' : ''); b.textContent = ch; b.style.background = COLORS[(i * 7 + (small ? 3 : 0)) % COLORS.length]; b.style.animationDelay = (0.05 + i * 0.07 + (small ? 0.5 : 0)) + 's'; r.appendChild(b); i++; } };
        mk('tRow1', 'STUD CITY', false); mk('tRow2', 'INCREMENTAL', true);
    }
    function titleProgress(p, tip) { const b = document.getElementById('tBar'); if (b) b.style.width = Math.round(p * 100) + '%'; if (tip) document.getElementById('tTip').textContent = tip; }
    function titleReady(onPlay) {
        const btn = document.getElementById('tPlay'); btn.disabled = false; titleProgress(1, TIPS[1 + ((Math.random() * (TIPS.length - 1)) | 0)]);
        let n = 0; const iv = setInterval(() => { document.getElementById('tTip').textContent = TIPS[1 + (n++ % (TIPS.length - 1))]; }, 2600);
        const go = () => { clearInterval(iv); btn.onclick = null; window.removeEventListener('keydown', key); AUDIO.unlock(); document.getElementById('title').classList.add('gone'); setTimeout(() => document.getElementById('title').remove(), 700); onPlay(); };
        const key = (e) => { if (e.key === 'Enter' || e.key === ' ') go(); };
        btn.onclick = go; window.addEventListener('keydown', key);
    }

    // ---------------- weather button ----------------
    const WEATHER = ['auto', 'clear', 'rain', 'storm', 'fog', 'snow'];
    let wIdx = 0;
    function cycleWeather() {
        wIdx = (wIdx + 1) % WEATHER.length; const k = WEATHER[wIdx];
        if (k === 'auto') ENVFX.set('clear', 20); else { if (!R.Q.weather) { WORLD.setQuality('medium'); } ENVFX.set(k, 1e9); if (k === 'snow' || k === 'fog') { } }
        document.getElementById('dvWeather').textContent = 'WEATHER: ' + k.toUpperCase(); AUDIO.tap();
    }

    let t = 0;
    function tick(dt) { t += dt; if (t > 0.25) { t = 0; drawMinimap(); grade(); } }
    function init() { bindMinimap(); bindPhoto(); document.getElementById('dvWeather').onclick = cycleWeather; }
    return { init, tick, drawMinimap, photo, buildLogo, titleProgress, titleReady };
})();
