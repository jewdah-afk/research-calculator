// Stud City Incremental sky and sea spectacle. Rare and time-of-day moments that make the world feel
// alive; all cosmetic and budgeted by the effects director.
//   godRays       warm light shafts at sunrise and sunset
//   aurora        green and violet ribbons reflected on the night sea
//   shootingStar  a streak across the night every 8 to 16 s; tap it to make a wish (badge)
//   seaSerpent    every 6 to 10 minutes a brick sea serpent swims past the city; tap it (badge)
//   milestone     full-screen takeover the first time Studs pass 1K, 1M, 1B ... a googol
//   bloom         Ultra quality: bright things glow
const SKY = (() => {
    const R = WORLD.R;
    const $ = (id) => document.getElementById(id);
    let ids = null;
    function snd(id, x, y, opts, fallback) {
        if (typeof AUDIO === 'undefined') return;
        if (!ids) ids = new Set((AUDIO.CATALOG || []).map(e => e.id));
        if (ids.has(id)) FX.sfx(id, x, y, opts); else if (fallback) FX.sfx(fallback, x, y, opts);
    }
    const X = () => { try { return META.state(); } catch (e) { return { counters: {} }; } };
    const bump = (k) => { try { META.bump(k); } catch (e) { } };
    const quiet = () => typeof GAME !== 'undefined' && (GAME.sim || GAME.speed >= 10);
    const cineOn = () => typeof CINE !== 'undefined' && CINE.on;
    const smooth = (k) => { k = Math.max(0, Math.min(1, k)); return k * k * (3 - 2 * k); };

    // =====================================================================================
    // GOD RAYS at golden hour
    // =====================================================================================
    function golden() { const t = R.env.tod; return Math.max(0, 1 - Math.abs(t - 7.0) / 1.3) + Math.max(0, 1 - Math.abs(t - 18.2) / 1.3); }
    // Where the sun sits in screen space: off the top edge on the side it shines from (shadows fall along -sun).
    function sunScreen() { const su = R.sun.x * R.cosA - R.sun.y * R.sinA; return [R.W * (0.5 + Math.max(-0.7, Math.min(0.7, su * 0.9))), -R.H * 0.2]; }
    function rayStrength() { if (R.DIRECTOR.mode === 'minimal' || R.Q.name === 'low') return 0; return golden() * (1 - R.env.rain) * (1 - (R.env.storm || 0)); }
    function drawGodRays() {
        const k = rayStrength(); if (k < 0.02) return;
        const g = R.g, W = R.W, H = R.H, [sx, sy] = sunScreen();
        const col = R.env.tod < 12 ? [255, 226, 160] : [255, 178, 110];
        const toC = Math.atan2(H * 0.6 - sy, W / 2 - sx);
        g.save(); g.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 7; i++) {
            const a = toC + (i - 3) * 0.14 + Math.sin(R.T * 0.07 + i) * 0.03, sp = 0.045 + 0.03 * ((i * 7) % 3);
            const al = 0.15 * k * (0.5 + 0.5 * Math.sin(R.T * 0.35 + i * 1.7));
            const L = H * 1.6;
            const gr = g.createLinearGradient(sx, sy, sx + Math.cos(a) * L, sy + Math.sin(a) * L);
            gr.addColorStop(0, `rgba(${col},${al})`); gr.addColorStop(0.6, `rgba(${col},${al * 0.45})`); gr.addColorStop(1, `rgba(${col},0)`);
            g.fillStyle = gr; g.beginPath(); g.moveTo(sx, sy); g.lineTo(sx + Math.cos(a - sp) * L, sy + Math.sin(a - sp) * L); g.lineTo(sx + Math.cos(a + sp) * L, sy + Math.sin(a + sp) * L); g.closePath(); g.fill();
        }
        // soft glare where the sun would be, just off screen
        const r = H * 1.05, gl = g.createRadialGradient(sx, sy, 0, sx, sy, r);
        gl.addColorStop(0, `rgba(${col},${0.3 * k})`); gl.addColorStop(1, `rgba(${col},0)`);
        g.fillStyle = gl; g.fillRect(sx - r, sy - r, r * 2, r * 2);
        g.restore();
    }
    // The sea at golden hour: a warm reflection of the low sun and a glitter path running from it
    // toward the viewer. Drawn on the water, under the islands.
    function drawSunsetSea() {
        const k = rayStrength(); if (k < 0.02) return;
        const g = R.g, W = R.W, H = R.H, [sx, sy] = sunScreen();
        const morning = R.env.tod < 12;
        // paint the water: hot near the sun, pink through the middle, violet far away
        const lg = g.createLinearGradient(sx, sy, W - sx * 0.3, H * 1.1);
        lg.addColorStop(0, morning ? `rgba(255,196,120,${0.62 * k})` : `rgba(255,140,70,${0.66 * k})`);
        lg.addColorStop(0.45, morning ? `rgba(255,150,150,${0.4 * k})` : `rgba(226,86,120,${0.5 * k})`);
        lg.addColorStop(1, morning ? `rgba(120,150,220,${0.25 * k})` : `rgba(64,44,120,${0.45 * k})`);
        g.fillStyle = lg; g.fillRect(0, 0, W, H);
        g.save(); g.globalCompositeOperation = 'lighter';
        const r = Math.max(W, H) * 0.65, gr = g.createRadialGradient(sx, sy, 0, sx, sy, r);
        gr.addColorStop(0, `rgba(255,220,150,${0.4 * k})`); gr.addColorStop(1, 'rgba(255,220,150,0)');
        g.fillStyle = gr; g.fillRect(0, 0, W, H);
        // glitter path
        const ex = W * 0.5 + (W * 0.5 - sx) * 0.2, ey = H * 1.05;
        g.fillStyle = 'rgb(255,226,170)';
        for (let i = 0; i < 90; i++) {
            const h1 = Math.sin(i * 12.9898) * 43758.5, h2 = Math.sin(i * 78.233) * 12345.6;
            const t = h1 - Math.floor(h1), j = (h2 - Math.floor(h2)) - 0.5;
            const fl = Math.sin(R.T * (4 + (i % 5)) + i * 1.3); if (fl < 0.3) continue;
            const x = sx + (ex - sx) * t + j * (40 + t * 260), y = sy + (ey - sy) * t;
            const w = (6 + t * 22) * (fl - 0.3), hh = 1.5 + t * 1.5;
            g.globalAlpha = 0.55 * k * (1 - t * 0.5); g.fillRect(x - w / 2, y, w, hh);
        }
        g.restore();
    }

    // =====================================================================================
    // AURORA reflected on the sea
    // =====================================================================================
    let auroraForce = 0, auroraSeen = false;
    function auroraLevel() {
        const n = R.env.night; if (n < 0.5) return auroraForce > R.T ? 1 : 0;
        const night = Math.floor((performance.now() / 1000 + R.env.tod * 0) / 1);
        void night;
        const wave = 0.55 + 0.45 * Math.sin(R.T * 0.013 + 1.3);
        return Math.max(auroraForce > R.T ? 1 : 0, Math.min(1, (n - 0.5) * 2) * wave);
    }
    function drawAurora() {
        const lv = auroraLevel(); if (lv < 0.05 || R.Q.name === 'low' || R.DIRECTOR.mode === 'minimal') return;
        const g = R.g, K = R.K, cx = R.cam.x, cy = R.cam.y;
        const span = Math.max(R.W, R.H) / K * 1.6;
        g.save(); g.globalCompositeOperation = 'lighter'; g.lineCap = 'round'; g.lineJoin = 'round';
        const sc = span / 12;
        const bands = [['#39ffb0', 0, 1], ['#7af5ff', 3.6 * sc, 0.75], ['#b27aff', -3.8 * sc, 0.65], ['#39ffb0', 7.4 * sc, 0.6], ['#b27aff', -7.8 * sc, 0.5]];
        for (const [col, off, str] of bands) {
            const pts = [];
            for (let u = -span; u <= span; u += Math.max(0.6, span / 40)) {
                // ribbons run along screen-horizontal and follow the view, like a reflection of the sky
                const o = off + Math.sin(u * 0.18 + R.T * 0.15 + off) * 1.6 * sc;
                pts.push(R.P(cx + u * 0.7071 - o * 0.7071, cy - u * 0.7071 - o * 0.7071, 0));
            }
            for (const [w, a] of [[2.4, 0.05], [1.1, 0.09], [0.3, 0.16]]) {
                g.strokeStyle = col; g.globalAlpha = a * lv * str; g.lineWidth = w * K * Math.max(1, sc * 0.8);
                g.beginPath(); pts.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.stroke();
            }
        }
        // shimmering curtain streaks
        g.globalAlpha = 0.1 * lv; g.strokeStyle = '#9dffd6'; g.lineWidth = Math.max(1, 0.05 * K); g.beginPath();
        for (let i = 0; i < 26; i++) {
            const u = -span + (i / 25) * span * 2, ph = Math.sin(R.T * 1.3 + i * 2.1);
            if (ph < 0.2) continue;
            const wx = cx + u * 0.7071 + Math.sin(u * 0.18 + R.T * 0.15) * 1.6 * -0.7071, wy = cy - u * 0.7071 + Math.sin(u * 0.18 + R.T * 0.15) * 1.6 * -0.7071;
            const a = R.P(wx, wy, 0), b = R.P(wx - 0.7071 * 1.2, wy - 0.7071 * 1.2, 0); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]);
        }
        g.stroke();
        g.restore();
        if (lv > 0.6 && !auroraSeen) { auroraSeen = true; bump('auroras'); }
    }

    // =====================================================================================
    // SHOOTING STARS (tap to wish)
    // =====================================================================================
    const star = { next: 12, on: null };
    function launchStar(force) {
        const W = R.W, H = R.H, left = Math.random() < 0.5;
        const a = (left ? 0.35 : Math.PI - 0.35) + (Math.random() - 0.5) * 0.3;
        star.on = { x: W * (left ? 0.1 + Math.random() * 0.4 : 0.5 + Math.random() * 0.4), y: H * (0.08 + Math.random() * 0.25), vx: Math.cos(a) * 820, vy: Math.sin(a) * 820, t: 0, life: 1.1, hit: false };
        if (force || Math.random() < 0.5) snd('shootingStar', undefined, undefined, { vol: 0.35 });
    }
    function updateStar(dt) {
        if (star.on) { star.on.t += dt; if (star.on.t > star.on.life) star.on = null; return; }
        if (R.env.night < 0.6 || R.DIRECTOR.mode === 'minimal' || cineOn()) { star.next = R.T + 6; return; }
        if (R.T > star.next) { star.next = R.T + 8 + Math.random() * 8; launchStar(false); }
    }
    function drawStar() {
        const s = star.on; if (!s) return;
        const g = R.g, k = s.t / s.life, fade = k < 0.15 ? k / 0.15 : k > 0.75 ? (1 - k) / 0.25 : 1;
        const hx = s.x + s.vx * s.t, hy = s.y + s.vy * s.t, tl = 170, len = Math.hypot(s.vx, s.vy);
        const tx = hx - s.vx / len * tl, ty = hy - s.vy / len * tl;
        g.save(); g.globalCompositeOperation = 'lighter';
        const gr = g.createLinearGradient(hx, hy, tx, ty); gr.addColorStop(0, `rgba(255,255,240,${0.9 * fade})`); gr.addColorStop(1, 'rgba(160,200,255,0)');
        g.strokeStyle = gr; g.lineWidth = 3; g.lineCap = 'round'; g.beginPath(); g.moveTo(hx, hy); g.lineTo(tx, ty); g.stroke();
        g.globalAlpha = fade; g.drawImage(R.glowSprite('#fff6c8'), hx - 22, hy - 18, 44, 36);
        g.fillStyle = '#ffffff'; g.beginPath(); g.arc(hx, hy, 2.6, 0, 7); g.fill();
        g.restore();
        // the whole streak is tappable, so a tap that lands a frame late still counts
        if (!s.hit) for (let i = 0; i < 5; i++) { const px = hx - s.vx / len * i * 45, py = hy - s.vy / len * i * 45; R.hit({ type: 'star', x0: px - 48, y0: py - 48, x1: px + 48, y1: py + 48 }); }
    }
    function wish() {
        const s = star.on; if (!s || s.hit) return; s.hit = true;
        const hx = s.x + s.vx * s.t, hy = s.y + s.vy * s.t; const w = R.unproject(hx, hy, R.TOP);
        R.burst(w[0], w[1], R.TOP + 1, '#fff6c8', 18, 2.6);
        bump('wishes'); snd('shootingStar', undefined, undefined, { vol: 0.8, pitch: 5 }, 'coin'); FX.sfx('coin');
        if (typeof HUD !== 'undefined') HUD.toast('You caught a shooting star and made a wish!', '#e6e0ff');
    }

    // =====================================================================================
    // BRICK SEA SERPENT
    // =====================================================================================
    const serp = { next: 420 + Math.random() * 180, on: null };
    const SEG = 7, GAP = 0.5;
    // Blocked water: built plots (with a margin), the downtown islet and the sign hill.
    function blocked(x, y) {
        const k = plotKeyOf(x, y); const p = PLOTS.get(k);
        if (p && R.builtCache().has(k) && x > p.x0 - 0.45 && x < p.x0 + 5.45 && y > p.y0 - 0.45 && y < p.y0 + 5.45) return true;
        for (const [dx, dy] of [[0.6, 0], [-0.6, 0], [0, 0.6], [0, -0.6]]) { const q = PLOTS.get(plotKeyOf(x + dx, y + dy)); if (q && R.builtCache().has(q.key) && x + dx > q.x0 && x + dx < q.x0 + 5 && y + dy > q.y0 && y + dy < q.y0 + 5) return true; }
        if (x > -18.5 && x < -9 && y > -18.5 && y < -9) return true;
        return false;
    }
    // Pick the longest straight run of open sea that is on screen, along either axis.
    function startSerpent() {
        if (!R.builtCache().size) return;
        const W = R.W, H = R.H, m = 70;
        const cs = [R.unproject(m, m, 0), R.unproject(W - m, m, 0), R.unproject(m, H - m, 0), R.unproject(W - m, H - m, 0)];
        const x0 = Math.min(...cs.map(c => c[0])), x1 = Math.max(...cs.map(c => c[0])), y0 = Math.min(...cs.map(c => c[1])), y1 = Math.max(...cs.map(c => c[1]));
        const vis = (x, y) => { const s = R.P(x, y, 0); return s[0] > m && s[0] < W - m && s[1] > m + 40 && s[1] < H - m - 60; };
        let best = null;
        for (const horiz of [true, false]) {
            const [a0, a1, b0, b1] = horiz ? [y0, y1, x0, x1] : [x0, x1, y0, y1];
            for (let c = Math.ceil(a0 * 2) / 2; c <= a1; c += 0.5) {
                let run = null;
                for (let u = b0; u <= b1 + 0.25; u += 0.25) {
                    const [x, y] = horiz ? [u, c] : [c, u];
                    const ok = u <= b1 && vis(x, y) && !blocked(x, y);
                    if (ok) { if (!run) run = { s: u }; run.e = u; }
                    else if (run) { if (!best || run.e - run.s > best.len) best = { horiz, c, s: run.s, e: run.e, len: run.e - run.s }; run = null; }
                }
            }
        }
        let path;
        if (best && best.len >= 5) path = { horiz: best.horiz, c: best.c, s: best.s + 0.5, e: best.e - 0.5 };
        else { const b = R.worldBounds; path = { horiz: true, c: b.y1 + 2.8, s: R.cam.x - 8, e: R.cam.x + 8 }; }
        const dir = Math.random() < 0.5 ? 1 : -1;
        const side = { p: path.horiz ? (u) => [u, path.c] : (u) => [path.c, u], horiz: path.horiz };
        const len = Math.min(18, path.e - path.s) + SEG * GAP;
        serp.on = { side, u0: dir > 0 ? path.s : path.e, dir, t: 0, dur: len / 1.1, speed: 1.1, splashed: new Set(), roared: false, tapped: false };
    }
    function serpPos(o, i) {
        const u = o.u0 + o.dir * (o.t * o.speed - i * GAP);
        const [x, y] = o.side.p(u);
        const w = Math.sin(R.T * 2 - i * 0.8) * 0.18; // sideways wiggle
        return o.side.horiz ? [x, y + w] : [x + w, y];
    }
    function updateSerpent(dt) {
        const o = serp.on;
        if (!o) { if (R.T > serp.next && !cineOn() && !R.FXD.inHero() && R.DIRECTOR.mode !== 'minimal') { serp.next = R.T + 360 + Math.random() * 240; startSerpent(); } return; }
        o.t += dt; if (o.t > o.dur) { serp.on = null; return; }
        const [hx, hy] = serpPos(o, 0); const s = R.P(hx, hy, 0);
        if (!o.roared && o.t > 1.2 && R.onScreen(s[0], s[1], 0)) { o.roared = true; snd('serpent', hx, hy, { vol: 0.8 }, 'foghorn'); }
    }
    function emergence(o) { return smooth(o.t / 1.4) * smooth((o.dur - o.t) / 1.4); }
    function segHeight(o, i) { const e = emergence(o); if (i === 0) return (0.32 + 0.06 * Math.sin(R.T * 3)) * e; return Math.max(0, Math.sin(R.T * 2.4 - i * 0.95)) * 0.42 * e; }
    function drawSeg(o, i) {
        const g = R.g, K = R.K; const [x, y] = serpPos(o, i); const h = segHeight(o, i);
        const s = R.P(x, y, 0); if (!R.onScreen(s[0], s[1], 2 * K)) return;
        if (h < 0.03 && i > 0) { g.strokeStyle = 'rgba(255,255,255,0.5)'; g.lineWidth = Math.max(1, 0.04 * K); g.beginPath(); g.ellipse(s[0], s[1], 0.22 * K, 0.11 * K, 0, 0, 7); g.stroke(); o.splashed.delete(i); return; }
        if (!o.splashed.has(i) && h > 0.05) { o.splashed.add(i); if (R.FXD.amount() > 0.3) R.burst(x, y, 0.1, '#d9f4ff', 5, 1.4); }
        const head = i === 0, hw = head ? 0.26 : 0.2 - i * 0.012;
        // foam collar where the body meets the water
        g.fillStyle = 'rgba(255,255,255,0.55)'; g.beginPath(); g.ellipse(s[0], s[1], (hw + 0.12) * K, (hw + 0.12) * K * R.SQ, 0, 0, 7); g.fill();
        const col = i % 2 ? '#2fb36a' : '#3cc47a';
        R.box(x, y, -0.25, hw, hw, 0.25 + h, col, { topCol: R.tone(col, 0.12) });
        if (!head) { R.box(x, y, h, 0.05, 0.05, 0.12, '#ffd23f'); return; }
        // head: horns, eyes on the camera side, a tongue now and then
        R.box(x - 0.14, y - 0.14, h, 0.04, 0.04, 0.16, '#ffd23f'); R.box(x + 0.14, y - 0.14, h, 0.04, 0.04, 0.16, '#ffd23f');
        const e1 = R.P(x - 0.12, y + 0.26, h - 0.08), e2 = R.P(x + 0.26, y - 0.12, h - 0.08);
        for (const e of [e1, e2]) { g.fillStyle = '#ffffff'; g.strokeStyle = R.INK; g.lineWidth = Math.max(1, 0.025 * K); g.beginPath(); g.arc(e[0], e[1], 0.07 * K, 0, 7); g.fill(); g.stroke(); const blink = (R.T % 3.5) < 0.12; g.fillStyle = R.INK; g.beginPath(); if (blink) g.rect(e[0] - 0.06 * K, e[1] - 1, 0.12 * K, 2); else g.arc(e[0] + 0.015 * K, e[1] + 0.01 * K, 0.035 * K, 0, 7); g.fill(); }
        if ((R.T % 2.2) < 0.35) { const m = R.P(x + 0.2, y + 0.2, h - 0.2); g.strokeStyle = '#e8453c'; g.lineWidth = Math.max(1.5, 0.04 * K); g.beginPath(); g.moveTo(m[0], m[1]); g.lineTo(m[0] + 0.12 * K, m[1] + 0.1 * K); g.stroke(); }
        const top = R.P(x, y, h + 0.25); R.hit({ type: 'serpent', x0: top[0] - 0.6 * K, y0: top[1] - 0.4 * K, x1: top[0] + 0.6 * K, y1: s[1] + 0.3 * K });
    }
    function tapSerpent() {
        const o = serp.on; if (!o || o.tapped) return; o.tapped = true;
        const [x, y] = serpPos(o, 0);
        bump('serpents'); FX.play('splash', { x, y, force: true }); snd('serpent', x, y, { vol: 1, pitch: 3 }, 'foghorn');
        if (typeof HUD !== 'undefined') HUD.toast('The brick serpent winks at you and dives.', '#c8ffd9');
        o.dur = Math.min(o.dur, o.t + 1.6);
    }

    // =====================================================================================
    // MILESTONE TAKEOVERS
    // =====================================================================================
    const MS = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 50, 75, 100, 150, 200, 250, 300];
    const WORDS = { 3: 'ONE THOUSAND', 6: 'ONE MILLION', 9: 'ONE BILLION', 12: 'ONE TRILLION', 15: 'ONE QUADRILLION', 18: 'ONE QUINTILLION', 21: 'ONE SEXTILLION', 24: 'ONE SEPTILLION', 27: 'ONE OCTILLION', 30: 'ONE NONILLION', 33: 'ONE DECILLION', 100: 'ONE GOOGOL' };
    let msCheck = 0, msPending = -1, msTimer = 0;
    function reached() { const p = typeof getCurr === 'function' ? getCurr('P') : 0; if (!(p > 0)) return 0; const e = Math.floor(Math.log10(p) + 1e-9); let best = 0; for (const m of MS) if (e >= m) best = m; return best; }
    function checkMilestone(dt) {
        msCheck += dt; if (msCheck < 0.5) return; msCheck = 0;
        const x = X(); const r = reached();
        if (x.milestone === undefined) { x.milestone = r; return; }
        if (r > x.milestone) { x.milestone = r; msPending = r; }
        if (msPending > 0 && !R.FXD.inHero() && !cineOn()) { if (!quiet()) FX.play('milestone', { e: msPending, force: true }); msPending = -1; }
    }
    function showMilestone(c) {
        const e = c.e || 6; const el = $('milestone'); if (!el) return;
        el.querySelector('.ms-n').textContent = WORDS[e] || formatNum(Math.pow(10, e));
        el.querySelector('.ms-c').textContent = curName('P').toUpperCase();
        el.classList.remove('on'); void el.offsetWidth; el.classList.add('on');
        clearTimeout(msTimer); msTimer = setTimeout(() => el.classList.remove('on'), 2300);
        snd('milestone', undefined, undefined, { vol: 0.9 }, 'achievement'); FX.haptic('big');
        setTimeout(() => FX.throwConfetti(80), 150);
        R.FXD.shake(0.4);
        // a fountain of coins from the Studs counter
        const hero = $('heroIcon'); if (hero && R.FXD.amount() > 0) {
            const r0 = hero.getBoundingClientRect();
            for (let i = 0; i < 16; i++) {
                const d = document.createElement('i'); d.className = 'ms-coin'; d.style.left = (r0.left + r0.width / 2) + 'px'; d.style.top = (r0.top + r0.height / 2) + 'px';
                d.style.setProperty('--dx', ((Math.random() - 0.3) * 520) + 'px'); d.style.setProperty('--dy', (80 + Math.random() * 320) + 'px'); d.style.animationDelay = (i * 25) + 'ms';
                document.body.appendChild(d); setTimeout(() => d.remove(), 1500);
            }
        }
    }

    // =====================================================================================
    // BLOOM (Ultra)
    // =====================================================================================
    let bc = null, bx = null, bloomOK = null;
    function bloom(cv) {
        if (R.Q.name !== 'ultra' || R.DIRECTOR.mode === 'minimal') return;
        if (bloomOK === null) { const t = document.createElement('canvas').getContext('2d'); bloomOK = 'filter' in t; if (bloomOK) { t.filter = 'blur(2px)'; bloomOK = t.filter === 'blur(2px)'; } }
        if (!bloomOK) return;
        const w = Math.max(1, Math.round(cv.width / 4)), h = Math.max(1, Math.round(cv.height / 4));
        if (!bc) { bc = document.createElement('canvas'); bx = bc.getContext('2d'); }
        if (bc.width !== w || bc.height !== h) { bc.width = w; bc.height = h; }
        // keep only the bright parts (contrast crush), blur them, and add them back on top
        bx.globalCompositeOperation = 'copy'; bx.filter = 'brightness(0.72) contrast(2.6) saturate(1.3) blur(3px)';
        bx.drawImage(cv, 0, 0, w, h); bx.filter = 'none';
        const g = R.g; g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'lighter';
        g.globalAlpha = 0.16 + 0.26 * R.env.night; g.drawImage(bc, 0, 0, cv.width, cv.height); g.restore();
    }

    // =====================================================================================
    // wiring, catalog, badges
    // =====================================================================================
    WORLD.use('update', (dt) => { updateStar(dt); updateSerpent(dt); checkMilestone(dt); });
    WORLD.use('underPlates', () => { drawSunsetSea(); drawAurora(); });
    WORLD.use('items', (items) => { const o = serp.on; if (!o) return; for (let i = SEG - 1; i >= 0; i--) { const [x, y] = serpPos(o, i); items.push({ d: R.depth(x, y) + 0.01 * i, draw() { drawSeg(o, i); } }); } });
    WORLD.use('post', () => { drawGodRays(); drawStar(); });
    WORLD.use('bloom', bloom);
    function tap(h) { if (h.type === 'star') { wish(); return true; } if (h.type === 'serpent') { tapSerpent(); return true; } return false; }

    FX.def({ id: 'godRays', name: 'God rays', tier: 'ambient', category: 'Sky', trigger: 'Sunrise (around 7:00) and sunset (around 18:12), medium quality and up',
        durationMs: 0, sound: '-', haptic: 'none',
        desc: 'Seven warm light shafts fan out from the side the sun is on, slowly breathing and drifting, with a soft glare at their source. The sea answers: a warm reflection of the low sun and a glitter path of flickering highlights running toward you, under the islands. Morning is pale gold, evening is orange. Rain and storms switch it all off.',
        spec: { strength: 'triangle peaks 1.3 h either side of 7:00 and 18:12', shafts: '7, 0.14 rad apart, 0.09 to 0.15 rad wide, 1.6 x screen height', alpha: '15% x strength x breathing 0.5 to 1', glare: 'radial 1.05 x screen height at the source, 30%', sea: 'painted gradient from the sun (orange 66%) through pink (50%) to violet (45%), additive sun glow 0.65 x screen at 40%, glitter path of 90 flickering dashes from the sun toward the bottom of the screen', colour: 'morning rgb(255,226,160), evening rgb(255,178,110)' },
        roblox: 'Lighting.SunRays (Intensity 0.1 to 0.25, Spread 0.6) driven by ClockTime, plus Atmosphere Haze and Glare that peak at golden hour. For stylised shafts, a few large Beam parts with LightEmission 1 angled from the sun direction. The water glitter comes free with Terrain water and a low sun; for part water, a glossy SurfaceAppearance or a sparkle ParticleEmitter strip aligned to the sun.',
        run() { R.env.tod = 18.2; } });
    FX.def({ id: 'aurora', name: 'Aurora on the sea', tier: 'ambient', category: 'Sky', trigger: 'Late night, waxes and wanes over about 8 minutes',
        durationMs: 0, sound: '-', haptic: 'none',
        desc: 'Five soft ribbons (green, cyan, violet) reflected on the night sea, waving slowly, with shimmering curtain streaks. They sit under the islands, like a reflection of the sky you cannot see.',
        spec: { bands: '5 ribbons spread over the view (green, cyan, violet, green, violet at 100% to 50%); 3 passes each (2.4, 1.1, 0.3 u wide at 5%, 9%, 16%)', motion: 'sine 0.18 rad/u, drifting 0.15 rad/s', level: 'night above 0.5, x a slow 0.45 to 1 wave' },
        roblox: 'Large flat Beams (or a SurfaceGui on a water-level Part) with LightEmission 1, TextureSpeed for drift and a green to violet ColorSequence; fade in with ClockTime. Real sky version: a Sky with a custom aurora texture layer.',
        run() { R.env.tod = 23; auroraForce = R.T + 30; } });
    FX.def({ id: 'shootingStar', name: 'Shooting star', tier: 'ambient', category: 'Sky', trigger: 'Night, every 8 to 16 s',
        durationMs: 1100, sound: 'shootingStar (half the time)', haptic: 'none',
        desc: 'A bright streak crosses the upper part of the screen. Tap it before it fades to make a wish: a burst of sparkles, a coin chime and the Make a Wish badge.',
        spec: { speed: '820 px/s at 0.35 rad from horizontal', tail: '170 px gradient', life: '1.1 s, fades in 15%, out last 25%', hitbox: 'five 96 px squares along the head and tail, so late taps still count' },
        roblox: 'A Part with a Trail (Lifetime 0.3, LightEmission 1) tweened across the sky far from the camera, or a ScreenGui ImageLabel streak. ClickDetector (or a GUI button on the head) awards the badge.',
        run() { if (R.env.night < 0.6) R.env.tod = 22.5; launchStar(true); } });
    FX.def({ id: 'seaSerpent', name: 'Brick sea serpent', tier: 'support', category: 'Sea', trigger: 'Every 6 to 10 minutes, through open sea in view',
        durationMs: 14500, sound: 'serpent when it first shows, again when tapped', haptic: 'none',
        desc: 'A green brick serpent with yellow spines swims past: its head rides above the water, its body arches out in humps that roll backwards, each one breaking the surface with a little splash and a foam collar. It blinks and flicks a red tongue. Tap it and it winks and dives (Serpent Spotter badge).',
        spec: { body: '7 segments 0.5 u apart, humps sin(2.4t - 0.95 i) x 0.42 u', speed: '1.1 u/s for about 16 u', path: 'the longest straight run of open, on-screen sea (0.45 u clear of plots), up to 18 u; if none, 2.8 u off the city edge', emerge: '1.4 s smoothstep in and out' },
        roblox: 'A Model of 7 brick segments; each Heartbeat set every segment CFrame from a path and a sine for height (below the water surface when negative). Splash ParticleEmitter at the surface crossing. ClickDetector on the head.',
        run() { serp.on = null; startSerpent(); } });
    FX.def({ id: 'milestone', name: 'Milestone takeover', tier: 'hero', category: 'Gameplay', trigger: 'Studs pass 1K, 1M, 1B ... 1e33, then 1e50, 1e75, a googol, 1e150 ... 1e300 for the first time',
        durationMs: 2300, sound: 'milestone fanfare', haptic: 'big',
        desc: 'The screen takes a breath: a spinning sunburst, MILESTONE in small letters, then the number in words (ONE MILLION) slams in with STUDS under it. Coins spray out of the Studs counter, confetti falls and the camera shakes a little.',
        spec: { burst: 'conic sunburst 130vmin, 12 rays, 10 s per turn, fades out at 2.3 s', number: '76 px (48 px on phones), cubic-bezier(.2,1.6,.4,1) 0.5 s', coins: '16 from the Studs icon, 25 ms apart, 1.1 s arcs', saved: 'META milestone, highest exponent reached' },
        roblox: 'ScreenGui with an ImageLabel sunburst (Rotation tween, looping), TextLabels with UIStroke and a UIScale Back Out tween, 16 coin ImageLabels tweened along Bezier arcs toward the counter. Store MilestoneBest in the profile.',
        run(c) { showMilestone(c); } });
    FX.def({ id: 'bloom', name: 'Bloom (Ultra)', tier: 'ambient', category: 'Render', trigger: 'Quality set to Ultra',
        durationMs: 0, sound: '-', haptic: 'none',
        desc: 'Bright things glow: lit windows, lamps, the lighthouse, sunny rooftops. The frame is shrunk to a quarter, contrast-crushed so only highlights survive, blurred, and added back on top. Stronger at night.',
        spec: { buffer: '1/4 resolution', filter: 'brightness 0.72, contrast 2.6, saturate 1.3, blur 3 px', blend: 'additive, 16% by day up to 42% at night' },
        roblox: 'Lighting.Bloom (Intensity 0.6, Size 24, Threshold 1.2 by day; lower Threshold at night) plus Neon material on lights. Only enable on the High graphics tier via a client check of UserGameSettings.SavedQualityLevel.',
        run() { WORLD.setQuality('ultra'); try { SETTINGS.set('quality', 'ultra'); } catch (e) { } } });

    if (typeof META !== 'undefined' && META.BADGES) {
        const c = (k) => (X().counters || {})[k] || 0;
        META.BADGES.push(
            { id: 'wish', name: 'Make a Wish', desc: 'Tap a shooting star', icon: '✶', test: () => c('wishes') >= 1 },
            { id: 'serpent', name: 'Serpent Spotter', desc: 'Tap the brick sea serpent', icon: '§', test: () => c('serpents') >= 1 },
            { id: 'aurora', name: 'Northern Lights', desc: 'See a bright aurora on the sea', icon: '≈', test: () => c('auroras') >= 1 },
        );
    }
    return { tap, launchStar, startSerpent, showMilestone, golden, get serpent() { return serp.on; } };
})();
