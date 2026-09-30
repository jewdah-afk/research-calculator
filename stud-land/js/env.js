// Weather director and ambient life around the islands. The renderer core only knows env.rain and
// env.wind; this module decides the weather, ramps it, and adds storms, fog, snow, sky visitors and
// sea life through the world hooks. All of it is presentation only.
const ENVFX = (() => {
    const R = WORLD.R, env = R.env;
    env.nextRain = Infinity;                 // the core's simple rain timer is replaced by this director
    const W = { kind: 'clear', target: { rain: 0, storm: 0, fog: 0, snow: 0 }, cur: { rain: 0, storm: 0, fog: 0, snow: 0 }, until: 90, nextBolt: 0, gust: 0 };
    const KINDS = {
        clear: { rain: 0, storm: 0, fog: 0, snow: 0 },
        rain: { rain: 1, storm: 0, fog: 0, snow: 0 },
        storm: { rain: 1, storm: 1, fog: 0, snow: 0 },
        fog: { rain: 0, storm: 0, fog: 1, snow: 0 },
        snow: { rain: 0, storm: 0, fog: 0.3, snow: 1 },
    };
    function pick() {
        const r = Math.random(), dawn = env.tod > 4.5 && env.tod < 9.5, night = env.night > 0.6;
        if (dawn && r < 0.35) return 'fog';
        if (night && r < 0.12) return 'snow';
        if (r < 0.58) return 'clear';
        if (r < 0.85) return 'rain';
        return 'storm';
    }
    function set(kind, secs) {
        W.kind = kind; W.target = { ...KINDS[kind] }; W.until = R.T + (secs || (kind === 'clear' ? 180 + Math.random() * 240 : 50 + Math.random() * 60));
        if (kind === 'clear' && W.cur.rain > 0.5 && env.night < 0.3) W.rainbowPending = true;
    }
    function update(dt) {
        if (!R.Q.weather) { W.target = { ...KINDS.clear }; }
        else if (R.T > W.until) set(W.kind === 'clear' ? pick() : 'clear');
        for (const k of Object.keys(W.cur)) { const d = W.target[k] - W.cur[k]; W.cur[k] += Math.sign(d) * Math.min(Math.abs(d), dt / 18); }
        env.rain = Math.max(W.cur.rain, W.cur.snow * 0.15);
        // wind: slow drift plus gusts, stronger in storms
        W.gust += (Math.random() - 0.5) * dt * 0.6; W.gust *= Math.pow(0.5, dt);
        env.wind = 0.2 + 0.25 * Math.sin(R.T * 0.03) + W.cur.storm * 0.8 + W.gust;
        if (W.rainbowPending && W.cur.rain < 0.05) { env.rainbow = 40; W.rainbowPending = false; }
        if (env.rainbow > 0) env.rainbow = Math.max(0, env.rainbow - dt);
        if (W.cur.storm > 0.6 && R.T > W.nextBolt) { W.nextBolt = R.T + 6 + Math.random() * 12; if (typeof FX !== 'undefined') FX.play('lightning', { force: true }); }
        if (typeof AUDIO !== 'undefined' && AUDIO.setWeather) AUDIO.setWeather({ rain: W.cur.rain, storm: W.cur.storm > 0.5, wind: Math.min(1, env.wind) });
        env.fog = W.cur.fog; env.snow = W.cur.snow; env.storm = W.cur.storm;
    }

    // ---------- fog banks: soft puffs that drift low over the water and islands ----------
    let fogSprite = null;
    function fogPuff() {
        if (fogSprite) return fogSprite;
        const c = document.createElement('canvas'); c.width = c.height = 128; const t = c.getContext('2d');
        const gr = t.createRadialGradient(64, 64, 4, 64, 64, 64); gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
        t.fillStyle = gr; t.fillRect(0, 0, 128, 128); return (fogSprite = c);
    }
    const banks = Array.from({ length: 18 }, (_, i) => ({ u: (i * 0.618) % 1, v: (i * 0.377) % 1, s: 3 + (i % 4) }));
    function drawFog() {
        if (W.cur.fog < 0.02) return;
        const g = R.g, b = R.worldBounds, sp = fogPuff();
        g.save(); g.globalAlpha = 0.38 * W.cur.fog;
        for (const f of banks) {
            f.u = (f.u + R.dt * 0.004 * (0.5 + env.wind)) % 1;
            const x = b.x0 - 6 + f.u * (b.x1 - b.x0 + 12), y = b.y0 - 6 + f.v * (b.y1 - b.y0 + 12);
            const s = R.P(x, y, 0.4); const r = f.s * R.K;
            if (!R.onScreen(s[0], s[1], r)) continue;
            g.drawImage(sp, s[0] - r, s[1] - r * 0.45, r * 2, r * 0.9);
        }
        g.restore();
        g.fillStyle = `rgba(230,240,250,${0.18 * W.cur.fog})`; g.fillRect(0, 0, R.W, R.H);
    }
    // ---------- snow ----------
    const flakes = [];
    function drawSnow(dt) {
        const want = Math.floor(140 * W.cur.snow * Math.max(0.3, R.FXD.amount()));
        while (flakes.length < want) flakes.push({ x: Math.random() * R.W, y: Math.random() * R.H, v: 30 + Math.random() * 40, r: 1 + Math.random() * 2.2, p: Math.random() * 6 });
        if (flakes.length > want) flakes.length = want;
        if (!flakes.length) return;
        const g = R.g; g.fillStyle = 'rgba(255,255,255,0.9)'; g.beginPath();
        for (const f of flakes) { f.y += f.v * dt; f.x += (Math.sin(R.T + f.p) * 15 + env.wind * 30) * dt; if (f.y > R.H) { f.y = -5; f.x = Math.random() * R.W; } g.moveTo(f.x + f.r, f.y); g.arc(f.x, f.y, f.r, 0, 7); }
        g.fill();
    }
    // ---------- storm tint ----------
    function drawStormTint() { if (W.cur.storm > 0.02) { R.g.fillStyle = `rgba(20,24,50,${0.34 * W.cur.storm})`; R.g.fillRect(0, 0, R.W, R.H); } }

    // ---------- sky visitors ----------
    const sky = { balloon: null, plane: null, nextBalloon: 60, nextPlane: 150 };
    function spawnVisitor(kind) {
        const b = R.worldBounds; const y = b.y0 + Math.random() * (b.y1 - b.y0);
        const o = { x: b.x0 - 10, y, x1: b.x1 + 10, t: 0 };
        if (kind === 'balloon') { o.speed = 0.35; o.z = 5 + Math.random(); sky.balloon = o; }
        else { o.speed = 2.4; o.z = 6.5; sky.plane = o; if (typeof FX !== 'undefined') FX.sfx('camWhoosh', undefined, undefined, { vol: 0.3 }); }
    }
    function updateSky(dt) {
        if (!R.builtCache().size) return;
        if (!sky.balloon && R.T > sky.nextBalloon) spawnVisitor('balloon');
        if (!sky.plane && R.T > sky.nextPlane && env.night < 0.5) spawnVisitor('plane');
        for (const k of ['balloon', 'plane']) {
            const o = sky[k]; if (!o) continue;
            o.x += o.speed * dt * (k === 'balloon' ? 0.5 + env.wind : 1); o.t += dt;
            if (o.x > o.x1) { sky[k] = null; if (k === 'balloon') sky.nextBalloon = R.T + 180 + Math.random() * 120; else sky.nextPlane = R.T + 360 + Math.random() * 240; }
        }
    }
    function drawSkyVisitors() {
        const g = R.g, K = R.K;
        const bl = sky.balloon;
        if (bl) {
            const z = bl.z + Math.sin(bl.t * 0.8) * 0.15; const s = R.P(bl.x, bl.y, z);
            if (R.onScreen(s[0], s[1], 80)) {
                const r = 0.55 * K;
                const sh = R.P(bl.x, bl.y, R.TOP); g.fillStyle = 'rgba(0,0,0,0.08)'; g.beginPath(); g.ellipse(sh[0], sh[1], r * 0.6, r * 0.3, 0, 0, 7); g.fill();
                g.strokeStyle = INK; g.lineWidth = Math.max(1.4, 2 * R.cam.zoom);
                const cols = ['#ff4d4d', '#ffd23f', '#ff4d4d', '#ffd23f', '#ff4d4d'];
                for (let i = 0; i < 5; i++) { g.fillStyle = cols[i]; g.beginPath(); g.ellipse(s[0], s[1], r * (1 - i * 0.2), r * 1.1, 0, -Math.PI / 2, Math.PI / 2); g.ellipse(s[0], s[1], r * (1 - i * 0.2), r * 1.1, 0, Math.PI / 2, Math.PI * 1.5); g.fill(); }
                g.beginPath(); g.ellipse(s[0], s[1], r, r * 1.1, 0, 0, 7); g.stroke();
                g.beginPath(); g.moveTo(s[0] - r * 0.5, s[1] + r * 0.9); g.lineTo(s[0] - r * 0.22, s[1] + r * 1.55); g.moveTo(s[0] + r * 0.5, s[1] + r * 0.9); g.lineTo(s[0] + r * 0.22, s[1] + r * 1.55); g.stroke();
                g.fillStyle = '#b07a45'; g.fillRect(s[0] - r * 0.25, s[1] + r * 1.55, r * 0.5, r * 0.35); g.strokeRect(s[0] - r * 0.25, s[1] + r * 1.55, r * 0.5, r * 0.35);
                if (env.night > 0.3) R.light([bl.x, bl.y, z - 0.4, '#ffb347', 0.8]);
            }
        }
        const pl = sky.plane;
        if (pl) {
            const s = R.P(pl.x, pl.y, pl.z); const k = K / 64;
            if (R.onScreen(s[0], s[1], 300)) {
                g.strokeStyle = INK; g.lineWidth = 2;
                // banner on a rope behind the plane
                const bx = s[0] - 190 * k, by = s[1] + 6 * k + Math.sin(R.T * 6) * 2;
                g.beginPath(); g.moveTo(s[0] - 16 * k, s[1]); g.lineTo(bx + 150 * k, by); g.stroke();
                const txt = 'STUD CITY INCREMENTAL'; g.font = `${Math.round(13 * k)}px "Luckiest Guy", sans-serif`; const tw = g.measureText(txt).width + 16 * k;
                g.fillStyle = '#fffaf0'; g.beginPath(); g.moveTo(bx + 150 * k - tw, by - 10 * k); for (let i = 0; i <= 8; i++) g.lineTo(bx + 150 * k - tw + tw * i / 8, by - 10 * k + Math.sin(R.T * 7 + i) * 2); g.lineTo(bx + 150 * k, by + 10 * k); for (let i = 8; i >= 0; i--) g.lineTo(bx + 150 * k - tw + tw * i / 8, by + 10 * k + Math.sin(R.T * 7 + i) * 2); g.closePath(); g.fill(); g.stroke();
                g.fillStyle = INK; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(txt, bx + 150 * k - tw / 2, by + 1);
                // plane
                g.fillStyle = '#e8453c'; g.beginPath(); g.ellipse(s[0], s[1], 20 * k, 6 * k, 0, 0, 7); g.fill(); g.stroke();
                g.fillStyle = '#ffd23f'; g.beginPath(); g.moveTo(s[0] - 4 * k, s[1]); g.lineTo(s[0] + 4 * k, s[1] - 14 * k); g.lineTo(s[0] + 10 * k, s[1] - 14 * k); g.lineTo(s[0] + 6 * k, s[1]); g.closePath(); g.fill(); g.stroke();
                g.beginPath(); g.moveTo(s[0] - 18 * k, s[1]); g.lineTo(s[0] - 22 * k, s[1] - 9 * k); g.lineTo(s[0] - 15 * k, s[1] - 2 * k); g.closePath(); g.fill(); g.stroke();
                g.strokeStyle = 'rgba(27,21,48,0.5)'; g.beginPath(); g.moveTo(s[0] + 21 * k, s[1] - 7 * k * Math.sin(R.T * 40)); g.lineTo(s[0] + 21 * k, s[1] + 7 * k * Math.sin(R.T * 40)); g.stroke();
            }
        }
    }

    // ---------- sea life ----------
    const fish = { next: 8, list: [] };
    function updateFish(dt) {
        if (R.T > fish.next && R.builtCache().size && R.FXD.amount() > 0) {
            fish.next = R.T + 4 + Math.random() * 7;
            const b = R.worldBounds; const side = (Math.random() * 4) | 0;
            const x = side === 0 ? b.x0 - 0.8 : side === 1 ? b.x1 + 0.8 : b.x0 + Math.random() * (b.x1 - b.x0);
            const y = side === 2 ? b.y0 - 0.8 : side === 3 ? b.y1 + 0.8 : b.y0 + Math.random() * (b.y1 - b.y0);
            const a = Math.random() * 6.28;
            fish.list.push({ x, y, dx: Math.cos(a), dy: Math.sin(a), t: 0, col: ['#ff9a2e', '#ffd23f', '#ff6b8a'][(Math.random() * 3) | 0] });
            R.ring(x, y, 0.02, '#ffffff', 0.6, 0.5);
        }
        for (let i = fish.list.length - 1; i >= 0; i--) { const f = fish.list[i]; f.t += dt; if (f.t > 0.9) { R.ring(f.x + f.dx * 0.9, f.y + f.dy * 0.9, 0.02, '#ffffff', 0.6, 0.5); fish.list.splice(i, 1); } }
    }
    function drawFish() {
        const g = R.g;
        for (const f of fish.list) {
            const u = f.t / 0.9; const s = R.P(f.x + f.dx * u, f.y + f.dy * u, Math.sin(u * Math.PI) * 0.9); const r = 0.1 * R.K;
            if (!R.onScreen(s[0], s[1], 40)) continue;
            const ang = Math.atan2(f.dy * R.SQ, f.dx) - (u - 0.5) * 1.6;
            g.save(); g.translate(s[0], s[1]); g.rotate(ang); g.fillStyle = f.col; g.strokeStyle = INK; g.lineWidth = 1.4;
            g.beginPath(); g.ellipse(0, 0, r * 1.4, r * 0.6, 0, 0, 7); g.fill(); g.stroke();
            g.beginPath(); g.moveTo(-r * 1.3, 0); g.lineTo(-r * 2.1, -r * 0.6); g.lineTo(-r * 2.1, r * 0.6); g.closePath(); g.fill(); g.stroke(); g.restore();
        }
    }
    function buoySpots() { const b = R.worldBounds; return [[b.x0 - 1.2, b.y0 + 2], [b.x1 + 1.2, b.y1 - 2], [b.x0 + 3, b.y1 + 1.3], [b.x1 - 3, b.y0 - 1.3]]; }
    function drawBuoys() {
        if (!R.builtCache().size) return;
        for (const [x, y] of buoySpots()) {
            const bob = Math.sin(R.T * 1.8 + x) * 0.04; const s = R.P(x, y, 0); if (!R.onScreen(s[0], s[1], 40)) continue;
            R.box(x, y, -0.05 + bob, 0.09, 0.09, 0.18, '#ff4d4d', { lw: 1.2 }); R.box(x, y, 0.13 + bob, 0.06, 0.06, 0.12, '#ffffff', { lw: 1.2 });
            const on = Math.sin(R.T * 3 + x) > 0.6; if (on) { const c = R.P(x, y, 0.3 + bob); R.g.fillStyle = '#fff1a8'; R.g.beginPath(); R.g.arc(c[0], c[1], 2.5, 0, 7); R.g.fill(); if (env.night > 0.2) R.light([x, y, 0.3, '#fff1a8', 0.7, true]); }
        }
    }
    const ducks = { a: 0 };
    function drawDucks() {
        const home = PLOTS.get('0,0'); if (!home || !R.builtCache().has('0,0')) return;
        ducks.a += R.dt * 0.12;
        for (let i = 0; i < 3; i++) {
            const a = ducks.a - i * 0.09, x = home.x0 + 2.5 + Math.cos(a) * 3.3, y = home.y0 + 2.5 + Math.sin(a) * 3.3;
            const s = R.P(x, y, 0.03 + Math.sin(R.T * 3 + i) * 0.01); if (!R.onScreen(s[0], s[1], 30)) continue;
            const r = (i ? 0.07 : 0.1) * R.K, g = R.g; const dir = -Math.sin(a) * R.cosA - Math.cos(a) * R.sinA > 0 ? 1 : -1;
            g.fillStyle = i ? '#ffe45c' : '#ffffff'; g.strokeStyle = INK; g.lineWidth = 1.2;
            g.beginPath(); g.ellipse(s[0], s[1], r * 1.2, r * 0.6, 0, 0, 7); g.fill(); g.stroke();
            g.beginPath(); g.arc(s[0] + dir * r * 0.9, s[1] - r * 0.7, r * 0.45, 0, 7); g.fill(); g.stroke();
            g.fillStyle = '#ff9a2e'; g.beginPath(); g.moveTo(s[0] + dir * r * 1.3, s[1] - r * 0.75); g.lineTo(s[0] + dir * r * 1.75, s[1] - r * 0.6); g.lineTo(s[0] + dir * r * 1.3, s[1] - r * 0.5); g.fill();
        }
    }

    WORLD.use('update', (dt) => { update(dt); updateSky(dt); updateFish(dt); });
    WORLD.use('underPlates', () => { drawBuoys(); drawDucks(); drawFish(); });
    WORLD.use('afterItems', () => drawFog());
    WORLD.use('sky', () => drawSkyVisitors());
    WORLD.use('post', () => { drawStormTint(); drawSnow(R.dt); });
    return { W, set, KINDS, sky, spawnVisitor };
})();
