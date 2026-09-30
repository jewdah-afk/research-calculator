// Stud City Incremental: the city grows up around you. All cosmetic, driven only by how many plots
// are built (never by or into the game math).
//   tiers      Village (1 to 4 plots), Town (5 to 11), City (12 to 23), Metropolis (24 and up).
//              Each new tier gets one hero celebration (saved, so it never repeats) and a badge.
//   sign       a giant STUD CITY sign on a brick hill behind Stud Square. It starts as STUD and gains
//              a letter per plot built until it is complete; at night the letters chase-light.
//   downtown   a skyline islet behind the sign: 2 towers at Town, 5 at City, 9 at Metropolis, with a
//              live billboard, lit windows at night and searchlights at Metropolis.
//   express    the Stud Express, an elevated train loop around everything you have built (Town and up).
//   traffic    little cars on the long bridge to the Red canyon plots.
const CITY = (() => {
    const R = WORLD.R;
    const TIERS = [
        { id: 'village', min: 0, title: 'STUD VILLAGE', short: 'VILLAGE' },
        { id: 'town', min: 5, title: 'STUD TOWN', short: 'TOWN' },
        { id: 'city', min: 12, title: 'STUD CITY', short: 'CITY' },
        { id: 'metro', min: 24, title: 'STUD METROPOLIS', short: 'METROPOLIS' },
    ];
    function tierIndex(n = R.builtCache().size) { let t = 0; for (let i = 0; i < TIERS.length; i++) if (n >= TIERS[i].min) t = i; return t; }
    function tier() { return TIERS[tierIndex()]; }
    const X = () => { try { return META.state(); } catch (e) { return {}; } };

    // ---------- sound helper: use the new id when the audio engine has it, else a fallback ----------
    let ids = null;
    function snd(id, x, y, opts, fallback) {
        if (typeof AUDIO === 'undefined') return;
        if (!ids) ids = new Set((AUDIO.CATALOG || []).map(e => e.id));
        if (ids.has(id)) FX.sfx(id, x, y, opts); else if (fallback) FX.sfx(fallback, x, y, opts);
    }

    // ---------- geometry helpers ----------
    const DIAG = [Math.SQRT1_2, -Math.SQRT1_2], BACK = [-Math.SQRT1_2, -Math.SQRT1_2];
    const at = (c, dd, db) => [c[0] + DIAG[0] * dd + BACK[0] * db, c[1] + DIAG[1] * dd + BACK[1] * db];
    // An oriented box (for things that turn, like train cars). u is the unit heading.
    function obox(x, y, z, ux, uy, hl, hw, h, col, opt = {}) {
        const vx = -uy, vy = ux;
        const cs = [[x - ux * hl - vx * hw, y - uy * hl - vy * hw], [x + ux * hl - vx * hw, y + uy * hl - vy * hw], [x + ux * hl + vx * hw, y + uy * hl + vy * hw], [x - ux * hl + vx * hw, y - uy * hl + vy * hw]];
        const nrm = [[-vx, -vy], [ux, uy], [vx, vy], [-ux, -uy]];
        const bot = cs.map(c => R.P(c[0], c[1], z)), top = cs.map(c => R.P(c[0], c[1], z + h));
        const lw = opt.lw || Math.max(1, 1.3 * R.cam.zoom);
        const faces = [];
        for (let i = 0; i < 4; i++) {
            const [nx, ny] = nrm[i]; const nv = nx * R.sinA + ny * R.cosA; if (nv <= 0.001) continue;
            const nu = nx * R.cosA - ny * R.sinA; const j = (i + 1) % 4;
            const f = [bot[i], bot[j], top[j], top[i]];
            R.poly(f, R.tone(col, nu < 0 ? -0.12 : -0.3), R.INK, lw);
            faces.push({ i, j, cs, long: i === 0 || i === 2 });
        }
        R.poly(top, opt.topCol || col, R.INK, lw);
        return { top, faces, cs };
    }
    // Points along a face (a,b corners) at fraction u and height z, for windows and trims.
    const along = (cs, i, j, u, z) => R.P(cs[i][0] + (cs[j][0] - cs[i][0]) * u, cs[i][1] + (cs[j][1] - cs[i][1]) * u, z);
    function quad(cs, i, j, u0, u1, z0, z1, fill) { R.poly([along(cs, i, j, u0, z0), along(cs, i, j, u1, z0), along(cs, i, j, u1, z1), along(cs, i, j, u0, z1)], fill); }
    function hash(a, b, c, d) { const s = Math.sin(a * 12.99 + b * 78.23 + c * 37.71 + d * 4.13) * 43758.5; return s - Math.floor(s); }

    // =====================================================================================
    // SIGN: STUD CITY on a brick hill behind Stud Square
    // =====================================================================================
    const HC = [-12, -12];
    const WORD = 'STUD CITY';
    const LETTERS = [...WORD].map((ch, i) => { const [x, y] = at(HC, (i - 4) * 0.6, 0); return { ch, i, x, y, h: 0.32 + 0.5 * Math.sin(Math.PI * (i + 0.5) / 9), tilt: (hash(i, 1, 2, 3) - 0.5) * 0.12, t0: -99 }; });
    let shownLetters = -1;
    function letterCount() { return Math.min(8, 3 + R.builtCache().size); }
    function syncLetters(silent) {
        const n = letterCount(); if (n === shownLetters) return;
        const prev = shownLetters; shownLetters = n;
        if (silent || prev < 0) return;
        let k = 0;
        for (const L of LETTERS) { if (L.ch === ' ') continue; if (k >= prev && k < n) { L.t0 = R.T + (k - prev) * 0.25; setTimeout(() => { R.puff(L.x, L.y, 0.2 + L.h, '#ffffff'); snd('letterDrop', L.x, L.y, { vol: 0.6 }, 'buy'); }, 700 + (k - prev) * 250); } k++; }
    }
    function drawHillColumn(L) {
        R.box(L.x, L.y, -0.12, 0.5, 0.5, 0.3, '#8d8f93', { topCol: '#e3cf94' });
        R.box(L.x, L.y, 0.18, 0.34, 0.34, L.h, '#4cbf56', { topCol: L.i % 2 ? '#63d06a' : '#57c75f', seams: 2 });
    }
    function drawLetter(L, idx) {
        if (L.ch === ' ' || idx >= shownLetters) return;
        const g = R.g, K = R.K, night = R.env.night;
        const t = R.T - L.t0; if (t < 0) return;
        const k = Math.min(1, t / 0.7); const drop = (1 - R.easeOutBounce(k)) * 3;
        const z = 0.18 + L.h;
        const base = R.P(L.x, L.y, z + drop);
        const size = 1.0 * K * R.ZH; if (size < 5) return;
        // two posts behind the letter
        g.strokeStyle = R.INK; g.lineWidth = Math.max(1, size * 0.06);
        g.beginPath(); g.moveTo(base[0] - size * 0.18, base[1]); g.lineTo(base[0] - size * 0.18, base[1] - size * 0.35); g.moveTo(base[0] + size * 0.18, base[1]); g.lineTo(base[0] + size * 0.18, base[1] - size * 0.35); g.stroke();
        const chase = night > 0.2 ? 0.5 + 0.5 * Math.max(0, Math.cos(R.T * 3 - idx * 0.8)) : 0;
        if (night > 0.2) {
            g.save(); g.globalCompositeOperation = 'lighter'; g.globalAlpha = night * (0.25 + 0.5 * chase);
            const r = size * 1.1; g.drawImage(R.glowSprite('#ffe28a'), base[0] - r, base[1] - size * 0.6 - r * 0.8, r * 2, r * 1.6); g.restore();
            R.light([L.x, L.y, z + 0.5, '#ffe28a', 0.5 + 0.4 * chase]);
        }
        g.save(); g.translate(base[0], base[1] - size * 0.14); g.rotate(L.tilt);
        g.font = `${Math.round(size)}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'alphabetic';
        g.lineJoin = 'round'; g.lineWidth = Math.max(2, size * 0.16); g.strokeStyle = R.INK;
        const ex = Math.max(1, size * 0.05);
        g.fillStyle = night > 0.3 ? '#b99a45' : '#aab6c2'; g.strokeText(L.ch, ex, ex * 1.4); g.fillText(L.ch, ex, ex * 1.4);
        g.strokeText(L.ch, 0, 0);
        g.fillStyle = night > 0.2 ? mixHex('#ffffff', '#fff0a8', chase) : '#ffffff'; g.fillText(L.ch, 0, 0);
        g.restore();
    }
    function mixHex(a, b, t) { const pa = [1, 3, 5].map(i => parseInt(a.slice(i, i + 2), 16)), pb = [1, 3, 5].map(i => parseInt(b.slice(i, i + 2), 16)); return `rgb(${pa.map((v, i) => Math.round(v + (pb[i] - v) * t)).join(',')})`; }

    // =====================================================================================
    // DOWNTOWN: skyline islet behind the sign, a live billboard, searchlights
    // =====================================================================================
    const DC = at(HC, 0, 4.6), DH = 2.7;
    // [along the sign, back from it, half width, height, colour, tier needed]
    const TOWERS = [
        [0, 0.6, 0.45, 5.2, '#5fa8d3', 1], [-1.4, 0.2, 0.38, 3.4, '#e8f1fb', 1],
        [1.5, -0.1, 0.36, 3.0, '#ffd23f', 2], [-0.6, -0.9, 0.3, 2.2, '#ff7a59', 2], [0.8, 1.4, 0.34, 4.2, '#8a4fe0', 2],
        [-1.9, 1.3, 0.3, 2.8, '#39d98a', 3], [1.9, 1.2, 0.3, 3.6, '#4aa8ff', 3], [0.9, -1.0, 0.26, 1.8, '#e8453c', 3], [-0.4, 1.9, 0.32, 4.8, '#2c3e66', 3],
    ].map(([dd, db, hw, h, col, need], i) => { const [x, y] = at(DC, dd, db); return { i, x, y, hw, h, col, need, t0: -99 }; });
    const BOARD = at(DC, -0.2, -2.05);
    let shownTier = -1;
    function syncTowers(silent) {
        const t = tierIndex(); if (t === shownTier) return;
        const prev = shownTier; shownTier = t;
        if (silent || prev < 0) return;
        let k = 0;
        for (const tw of TOWERS) if (tw.need > prev && tw.need <= t) { tw.t0 = R.T + 0.9 + k * 0.35; k++; }
    }
    function towerGrow(tw) { const t = R.T - tw.t0; if (t < 0) return 0; const k = Math.min(1, t / 1.4); return 1 - Math.pow(1 - k, 3); }
    function drawDowntownPlate() {
        if (shownTier < 1) return;
        const s = R.P(DC[0], DC[1], 0); if (!R.onScreen(s[0], s[1], 6 * R.K)) return;
        const g = R.g, K = R.K;
        // shallows, then a concrete islet with a road grid
        const sh = [[DC[0] - DH - 0.3, DC[1] - DH - 0.3], [DC[0] + DH + 0.3, DC[1] - DH - 0.3], [DC[0] + DH + 0.3, DC[1] + DH + 0.3], [DC[0] - DH - 0.3, DC[1] + DH + 0.3]].map(c => R.P(c[0], c[1], 0));
        R.poly(sh, R.env.night > 0.5 ? 'rgba(60,120,160,0.35)' : 'rgba(150,240,235,0.42)');
        R.box(DC[0], DC[1], -0.1, DH, DH, 0.4, '#8b96a3', { topCol: '#a9b2bc', seams: 2 });
        if (K < 20) return;
        g.strokeStyle = 'rgba(40,44,60,0.45)'; g.lineWidth = Math.max(2, 0.14 * K); g.lineCap = 'butt';
        g.beginPath();
        for (const u of [-1.1, 0.35]) { const a = R.P(DC[0] + u, DC[1] - DH + 0.15, 0.3), b = R.P(DC[0] + u, DC[1] + DH - 0.15, 0.3); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); const c = R.P(DC[0] - DH + 0.15, DC[1] + u, 0.3), d = R.P(DC[0] + DH - 0.15, DC[1] + u, 0.3); g.moveTo(c[0], c[1]); g.lineTo(d[0], d[1]); }
        g.stroke();
        // sun shadows of the towers on the islet
        const sun = R.sun; if (sun.alpha > 0.01) {
            g.save(); const pc = [[DC[0] - DH, DC[1] - DH], [DC[0] + DH, DC[1] - DH], [DC[0] + DH, DC[1] + DH], [DC[0] - DH, DC[1] + DH]].map(c => R.P(c[0], c[1], 0.3));
            g.beginPath(); g.moveTo(pc[0][0], pc[0][1]); for (let i = 1; i < 4; i++) g.lineTo(pc[i][0], pc[i][1]); g.closePath(); g.clip();
            g.beginPath();
            for (const tw of TOWERS) {
                if (tw.need > shownTier) continue; const h = tw.h * towerGrow(tw) * 0.5; if (h <= 0) continue;
                const ox = -sun.x * h * sun.len, oy = -sun.y * h * sun.len;
                const c = [[tw.x - tw.hw, tw.y - tw.hw], [tw.x + tw.hw, tw.y - tw.hw], [tw.x + tw.hw, tw.y + tw.hw], [tw.x - tw.hw, tw.y + tw.hw]];
                const hl = R.hull(c.concat(c.map(q => [q[0] + ox, q[1] + oy])));
                const s0 = R.P(hl[0][0], hl[0][1], 0.3); g.moveTo(s0[0], s0[1]); for (let j = 1; j < hl.length; j++) { const q = R.P(hl[j][0], hl[j][1], 0.3); g.lineTo(q[0], q[1]); } g.closePath();
            }
            g.fillStyle = `rgba(20,16,60,${sun.alpha})`; g.fill(); g.restore();
        }
    }
    function drawTower(tw) {
        const k = towerGrow(tw); if (k <= 0) return;
        const g = R.g, K = R.K, night = R.env.night, h = tw.h * k, z0 = 0.3;
        const s = R.P(tw.x, tw.y, z0); if (!R.onScreen(s[0], s[1] - h * K, h * K + 2 * K)) return;
        if (k < 1 && Math.random() < 0.5 * R.FXD.amount()) R.puff(tw.x + (Math.random() - 0.5) * tw.hw * 2, tw.y + (Math.random() - 0.5) * tw.hw * 2, z0, '#d8dde3');
        R.box(tw.x, tw.y, z0, tw.hw, tw.hw, h, tw.col, { topCol: R.tone(tw.col, 0.1) });
        if (K < 16) return;
        const cs = [[tw.x - tw.hw, tw.y - tw.hw], [tw.x + tw.hw, tw.y - tw.hw], [tw.x + tw.hw, tw.y + tw.hw], [tw.x - tw.hw, tw.y + tw.hw]];
        const floors = Math.max(2, Math.floor(h / 0.3));
        for (const [a, b, nx, ny] of R.EDGES) {
            const nv = nx * R.sinA + ny * R.cosA; if (nv <= 0.001) continue;
            // window bands: dark glass by day, a scatter of lit rooms at night
            for (let f = 0; f < floors; f++) {
                const za = z0 + h * (f + 0.25) / floors, zb = z0 + h * (f + 0.75) / floors;
                if (night > 0.25) { for (let c = 0; c < 3; c++) { const lit = hash(tw.i, a, f, c) < 0.35 + 0.35 * night; quad(cs, a, b, 0.12 + c * 0.27, 0.32 + c * 0.27, za, zb, lit ? '#ffe39a' : 'rgba(20,24,50,0.55)'); } }
                else quad(cs, a, b, 0.1, 0.9, za, zb, 'rgba(20,40,80,0.22)');
            }
            if (night <= 0.25) { g.save(); g.globalAlpha = 0.35; quad(cs, a, b, 0.62, 0.72, z0, z0 + h, '#ffffff'); g.restore(); }
        }
        if (k < 1) return;
        // roof: antenna with an aviation light on the tall ones, a helipad on the tallest
        const top = R.P(tw.x, tw.y, z0 + h);
        if (tw.h >= 3.4) {
            const ant = R.P(tw.x, tw.y, z0 + h + 0.6);
            g.strokeStyle = R.INK; g.lineWidth = Math.max(1.5, 0.05 * K); g.beginPath(); g.moveTo(top[0], top[1]); g.lineTo(ant[0], ant[1]); g.stroke();
            const blink = Math.sin(R.T * 3 + tw.i) > 0.3;
            g.fillStyle = blink ? '#ff3b3b' : '#8a2020'; g.beginPath(); g.arc(ant[0], ant[1], Math.max(2, 0.05 * K), 0, 7); g.fill();
            if (blink && night > 0.2) R.light([tw.x, tw.y, z0 + h + 0.6, '#ff4d4d', 0.6]);
        }
        if (tw.i === 0 && K > 26) { g.strokeStyle = '#ffffff'; g.lineWidth = Math.max(1, 0.03 * K); g.beginPath(); g.ellipse(top[0], top[1], tw.hw * 0.6 * K, tw.hw * 0.6 * K * R.SQ, 0, 0, 7); g.stroke(); g.fillStyle = '#ffffff'; g.font = `700 ${Math.round(0.28 * K)}px Fredoka, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('H', top[0], top[1]); }
        if (night > 0.3) R.light([tw.x, tw.y, z0 + h * 0.6, '#ffe39a', 0.5]);
    }
    function drawBillboard() {
        if (shownTier < 1) return;
        const g = R.g, K = R.K; const [x, y] = BOARD;
        const legB = R.P(x, y, 0.3), legT = R.P(x, y, 1.35);
        if (!R.onScreen(legB[0], legB[1], 3 * K)) return;
        const w = 2.7 * K * 0.72, h = 0.95 * K;
        g.strokeStyle = R.INK; g.lineWidth = Math.max(2, 0.06 * K);
        g.beginPath(); g.moveTo(legB[0] - w * 0.3, legB[1]); g.lineTo(legT[0] - w * 0.3, legT[1]); g.moveTo(legB[0] + w * 0.3, legB[1]); g.lineTo(legT[0] + w * 0.3, legT[1]); g.stroke();
        const bx = legT[0] - w / 2, by = legT[1] - h;
        R.roundRect(bx, by, w, h, Math.max(3, 0.08 * K), R.env.night > 0.3 ? '#fff6d8' : '#fffaf0', R.INK, Math.max(2, 0.05 * K));
        R.roundRect(bx + w * 0.03, by + h * 0.08, w * 0.94, h * 0.34, Math.max(2, 0.05 * K), '#ffd23f', null, 0);
        if (K >= 18) {
            g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = R.INK;
            g.font = `${Math.round(h * 0.26)}px "Luckiest Guy", sans-serif`; g.fillText(TIERS[shownTier].title, legT[0], by + h * 0.26);
            const rate = typeof calculateGainRate === 'function' ? calculateGainRate('P') : 0;
            g.font = `700 ${Math.round(h * 0.24)}px Fredoka, sans-serif`; g.fillText(`+${formatNum(rate)} ${curName('P')}/s`, legT[0], by + h * 0.7);
        }
        if (R.env.night > 0.2) { R.light([x, y, 1.6, '#fff1c0', 1.1]); }
    }
    function drawSearchlights() {
        if (shownTier < 3 || R.env.night < 0.2 || R.DIRECTOR.mode === 'minimal') return;
        const g = R.g, H = R.H;
        const tall = TOWERS.filter(t => t.h >= 4.2 && towerGrow(t) >= 1);
        g.save(); g.globalCompositeOperation = 'lighter';
        tall.forEach((tw, k) => {
            const s = R.P(tw.x, tw.y, 0.3 + tw.h); if (!R.onScreen(s[0], s[1], R.W)) return;
            const a = -Math.PI / 2 + 0.6 * Math.sin(R.T * 0.33 + k * 2.1), L = H * 1.3, sp = 0.05;
            const gr = g.createLinearGradient(s[0], s[1], s[0] + Math.cos(a) * L, s[1] + Math.sin(a) * L);
            gr.addColorStop(0, `rgba(255,250,220,${0.3 * R.env.night})`); gr.addColorStop(1, 'rgba(255,250,220,0)');
            g.fillStyle = gr; g.beginPath(); g.moveTo(s[0], s[1]); g.lineTo(s[0] + Math.cos(a - sp) * L, s[1] + Math.sin(a - sp) * L); g.lineTo(s[0] + Math.cos(a + sp) * L, s[1] + Math.sin(a + sp) * L); g.closePath(); g.fill();
        });
        g.restore();
    }

    // =====================================================================================
    // STUD EXPRESS: elevated loop around the built city
    // =====================================================================================
    const TZ = 1.1, THW = 0.2, TTH = 0.12, PAD = 0.9, RAD = 1.3;
    const track = { key: '', pts: [], len: [], L: 0 };
    function buildTrack() {
        const b = R.worldBounds;
        const x0 = Math.min(b.x0 - PAD, -4.4), y0 = Math.min(b.y0 - PAD, -4.4), x1 = b.x1 + PAD, y1 = b.y1 + PAD;
        const key = [x0, y0, x1, y1].join(','); if (key === track.key) return; track.key = key;
        const pts = [];
        const seg = (ax, ay, bx, by) => { const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay) / 0.5)); for (let i = 0; i < n; i++) pts.push([ax + (bx - ax) * i / n, ay + (by - ay) * i / n]); };
        const arc = (cx, cy, a0) => { for (let i = 0; i < 5; i++) { const a = a0 + (Math.PI / 2) * i / 5; pts.push([cx + Math.cos(a) * RAD, cy + Math.sin(a) * RAD]); } };
        seg(x0 + RAD, y0, x1 - RAD, y0); arc(x1 - RAD, y0 + RAD, -Math.PI / 2);
        seg(x1, y0 + RAD, x1, y1 - RAD); arc(x1 - RAD, y1 - RAD, 0);
        seg(x1 - RAD, y1, x0 + RAD, y1); arc(x0 + RAD, y1 - RAD, Math.PI / 2);
        seg(x0, y1 - RAD, x0, y0 + RAD); arc(x0 + RAD, y0 + RAD, Math.PI);
        const len = [0]; for (let i = 1; i <= pts.length; i++) { const a = pts[i - 1], c = pts[i % pts.length]; len.push(len[i - 1] + Math.hypot(c[0] - a[0], c[1] - a[1])); }
        track.pts = pts; track.len = len; track.L = len[len.length - 1];
    }
    function trackAt(s) {
        const L = track.L; s = ((s % L) + L) % L;
        let lo = 0, hi = track.pts.length; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (track.len[m] <= s) lo = m; else hi = m; }
        const a = track.pts[lo], b = track.pts[(lo + 1) % track.pts.length]; const u = (s - track.len[lo]) / (track.len[lo + 1] - track.len[lo] || 1);
        const dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
        return [a[0] + dx * u, a[1] + dy * u, dx / d, dy / d];
    }
    function drawTrackSeg(a, b, pillar) {
        const g = R.g, K = R.K;
        const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1, nx = -dy / L * THW, ny = dx / L * THW;
        if (pillar) R.box(a[0], a[1], -0.05, 0.07, 0.07, TZ - TTH + 0.05, '#c3c9cf', { topCol: '#d5dade' });
        const A1 = [a[0] + nx, a[1] + ny], A2 = [a[0] - nx, a[1] - ny], B1 = [b[0] + nx, b[1] + ny], B2 = [b[0] - nx, b[1] - ny];
        const front = (nx * R.sinA + ny * R.cosA) > 0 ? [A1, B1] : [A2, B2];
        const P = (q, z) => R.P(q[0], q[1], z);
        const lw = Math.max(1, 1.2 * R.cam.zoom);
        R.poly([P(front[0], TZ), P(front[1], TZ), P(front[1], TZ - TTH), P(front[0], TZ - TTH)], '#6f7780');
        R.poly([P(A1, TZ), P(B1, TZ), P(B2, TZ), P(A2, TZ)], '#9aa3ad');
        g.strokeStyle = R.INK; g.lineWidth = lw; g.beginPath();
        const f0 = P(front[0], TZ), f1 = P(front[1], TZ), f2 = P(front[1], TZ - TTH), f3 = P(front[0], TZ - TTH);
        g.moveTo(f0[0], f0[1]); g.lineTo(f1[0], f1[1]); g.moveTo(f3[0], f3[1]); g.lineTo(f2[0], f2[1]);
        const back = front[0] === A1 ? [A2, B2] : [A1, B1]; const k0 = P(back[0], TZ), k1 = P(back[1], TZ); g.moveTo(k0[0], k0[1]); g.lineTo(k1[0], k1[1]);
        g.stroke();
        if (K < 24) return;
        // sleeper and two rails
        const m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
        const s1 = R.P(m[0] + nx * 0.75, m[1] + ny * 0.75, TZ), s2 = R.P(m[0] - nx * 0.75, m[1] - ny * 0.75, TZ);
        g.strokeStyle = '#8a5a3a'; g.lineWidth = Math.max(1.5, 0.06 * K); g.beginPath(); g.moveTo(s1[0], s1[1]); g.lineTo(s2[0], s2[1]); g.stroke();
        g.strokeStyle = '#4a4f57'; g.lineWidth = Math.max(1, 0.03 * K); g.beginPath();
        for (const o of [0.45, -0.45]) { const r1 = R.P(a[0] + nx * o, a[1] + ny * o, TZ + 0.01), r2 = R.P(b[0] + nx * o, b[1] + ny * o, TZ + 0.01); g.moveTo(r1[0], r1[1]); g.lineTo(r2[0], r2[1]); }
        g.stroke();
    }
    const TRAIN = [{ col: '#e8453c', hl: 0.45, loco: true }, { col: '#4aa8ff', hl: 0.36 }, { col: '#ffd23f', hl: 0.36 }, { col: '#39d98a', hl: 0.36 }];
    const train = { s: 0, speed: 2.2, visible: false, lastWhistle: -99, puffT: 0, chugT: 0 };
    function carPositions() {
        const out = []; let back = 0;
        for (const c of TRAIN) { const s = train.s - back - c.hl; const [x, y, ux, uy] = trackAt(s); out.push({ c, x, y, ux, uy }); back += c.hl * 2 + 0.08; }
        return out;
    }
    function drawCar(o) {
        const g = R.g, K = R.K, night = R.env.night, { c, x, y, ux, uy } = o;
        obox(x, y, TZ, ux, uy, c.hl * 0.94, 0.15, 0.06, '#2b2b33');
        const body = obox(x, y, TZ + 0.06, ux, uy, c.hl, 0.18, c.loco ? 0.24 : 0.28, c.col, { topCol: c.loco ? R.tone(c.col, 0.1) : '#f1f3f5' });
        for (const f of body.faces) {
            if (!f.long || K < 20) continue;
            const n = c.loco ? 1 : 3;
            for (let w = 0; w < n; w++) { const u0 = c.loco ? 0.08 : 0.1 + w * 0.29, u1 = u0 + (c.loco ? 0.22 : 0.2); quad(f.cs, f.i, f.j, u0, u1, TZ + 0.16, TZ + 0.28, night > 0.3 ? '#ffe39a' : '#bfe3ff'); }
        }
        if (c.loco) {
            // cab at the back, chimney at the front
            obox(x - ux * c.hl * 0.55, y - uy * c.hl * 0.55, TZ + 0.3, ux, uy, c.hl * 0.4, 0.17, 0.16, '#1b1530', { topCol: '#3b3450' });
            const cx = x + ux * c.hl * 0.55, cy = y + uy * c.hl * 0.55;
            obox(cx, cy, TZ + 0.3, ux, uy, 0.06, 0.06, 0.14, '#2b2b33');
            if (R.FXD.amount() > 0 && train.puffT <= 0) { train.puffT = 0.14; R.puff(cx, cy, TZ + 0.5, '#f4f4f4'); }
            if (night > 0.2) { const hx = x + ux * (c.hl + 0.05), hy = y + uy * (c.hl + 0.05); R.light([hx, hy, TZ + 0.2, '#fff1a8', 1.2, true]); }
        } else if (night > 0.3) R.light([x, y, TZ + 0.25, '#ffe39a', 0.45, true]);
    }

    // =====================================================================================
    // TRAFFIC: cars on the long bridge (3,0 to 5,0)
    // =====================================================================================
    const BR = { x0: 12.5 + 5 - R.INSET, x1: 22.5 + R.INSET };
    const cars = [0, 1, 2, 3].map(i => ({ lane: i % 2 ? 1 : -1, x: BR.x0 + (i * 1.37) % (BR.x1 - BR.x0), v: 0.9 + (i % 3) * 0.25, col: ['#e8453c', '#4aa8ff', '#ffd23f', '#ffffff'][i] }));
    function drawBridgeCar(c) {
        const len = BR.x1 - BR.x0, u = (c.x - BR.x0) / len;
        const alpha = Math.min(1, u / 0.06, (1 - u) / 0.06); if (alpha <= 0) return;
        const y = c.lane * 0.22, dir = c.lane < 0 ? 1 : -1;
        R.g.globalAlpha = alpha;
        obox(c.x, y, R.TOP, dir, 0, 0.17, 0.1, 0.1, c.col, { topCol: R.tone(c.col, 0.12) });
        obox(c.x - dir * 0.02, y, R.TOP + 0.1, dir, 0, 0.09, 0.085, 0.07, '#bfe3ff', { topCol: R.tone(c.col, 0.2) });
        R.g.globalAlpha = 1;
        if (R.env.night > 0.3) R.light([c.x + dir * 0.2, y, R.TOP + 0.08, '#fff1a8', 0.7, true]);
    }

    // =====================================================================================
    // update, tier celebration and wiring
    // =====================================================================================
    let checkT = 0, pending = -1;
    function update(dt) {
        const built = R.builtCache();
        if (built.size >= TIERS[1].min) { buildTrack(); train.s += train.speed * dt; train.puffT -= dt; }
        for (const c of cars) { c.x += c.v * dt * (c.lane < 0 ? 1 : -1); if (c.x > BR.x1) c.x = BR.x0; if (c.x < BR.x0) c.x = BR.x1; }
        checkT += dt; if (checkT < 0.4) return; checkT = 0;
        syncLetters(false); syncTowers(false);
        const x = X(); const t = tierIndex();
        if (x.tierMax === undefined) x.tierMax = t;
        if (t > x.tierMax) { x.tierMax = t; pending = t; }
        if (pending >= 0 && !R.FXD.inHero() && !(typeof CINE !== 'undefined' && CINE.on)) {
            const quiet = typeof GAME !== 'undefined' && (GAME.sim || GAME.speed >= 10);
            if (!quiet) FX.play('cityTier', { tier: pending, force: true });
            pending = -1;
        }
        const lab = document.querySelector('#mmWrap .mm-label'); if (lab && lab.textContent !== TIERS[t].short) lab.textContent = TIERS[t].short;
        // whistle when the train comes into view
        if (built.size >= TIERS[1].min) {
            const [px, py] = trackAt(train.s); const s = R.P(px, py, TZ); const vis = R.onScreen(s[0], s[1], -40);
            if (vis && !train.visible && R.T - train.lastWhistle > 30) { train.lastWhistle = R.T; snd('whistle', px, py, { vol: 0.5 }); }
            train.visible = vis;
            if (vis && R.K > 30 && (train.chugT -= 0.4) <= 0) { train.chugT = 0.8; snd('chug', px, py, { vol: 0.18 }); }
        }
    }
    function celebrate(c) {
        const t = TIERS[c.tier == null ? tierIndex() : c.tier];
        const cam = R.cam, prev = { x: cam.x, y: cam.y, z: cam.tZoom };
        // pull back to show the whole city, including downtown and the sign
        const b = R.worldBounds; const xs = [b.x0, b.x1, DC[0] - DH, HC[0]], ys = [b.y0, b.y1, DC[1] - DH, HC[1]];
        const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
        const corners = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
        const u = corners.map(([x, y]) => x * R.cosA - y * R.sinA), v = corners.map(([x, y]) => (x * R.sinA + y * R.cosA) * R.SQ);
        const fit = Math.min(R.W / ((Math.max(...u) - Math.min(...u)) * 64), R.H / ((Math.max(...v) - Math.min(...v) + 3) * 64));
        cam.tx = (x0 + x1) / 2; cam.ty = (y0 + y1) / 2; cam.tZoom = Math.max(0.18, Math.min(0.9, fit * 0.92));
        FX.letterbox(3600); document.body.classList.add('cine'); setTimeout(() => document.body.classList.remove('cine'), 4100);
        if (typeof CINE !== 'undefined' && CINE.caption) { CINE.caption('YOUR CITY GREW INTO', t.title); setTimeout(() => CINE.caption('', ''), 3400); }
        snd('tierUp', undefined, undefined, { vol: 0.9 }, 'plotBuilt');
        if (typeof AUDIO !== 'undefined' && AUDIO.stinger && !(ids && ids.has('tierUp'))) AUDIO.stinger('plot');
        FX.haptic('big');
        const keys = [...R.builtCache()]; for (let i = 0; i < 7; i++) { const p = PLOTS.get(keys[(Math.random() * keys.length) | 0]); setTimeout(() => FX.launchFireworks(p.x0 + 2.5, p.y0 + 2.5, 3), 500 + i * 260); }
        setTimeout(() => FX.throwConfetti(110), 700);
        setTimeout(() => { for (const tw of TOWERS) if (R.T - tw.t0 < 3) snd('towerRise', tw.x, tw.y, { vol: 0.6 }, 'rise'); }, 900);
        setTimeout(() => { if (typeof CINE !== 'undefined' && CINE.on) return; cam.tx = prev.x; cam.ty = prev.y; cam.tZoom = prev.z; }, 4200);
    }
    FX.def({
        id: 'cityTier', name: 'City grows a tier', tier: 'hero', category: 'City', trigger: 'Built plots reach 5 (Town), 12 (City) or 24 (Metropolis), once per save',
        durationMs: 4200, sound: 'tierUp stinger, towerRise per new tower, fireworks', haptic: 'big',
        desc: 'The camera pulls all the way back to show the whole archipelago, cinema bars slide in, "YOUR CITY GREW INTO / STUD TOWN" slams in, fireworks go up across your plots, confetti falls, and new skyscrapers grow out of the downtown islet one after another. Then the camera flies back to where you were.',
        spec: { tiers: 'Village 1 to 4 plots, Town 5 to 11, City 12 to 23, Metropolis 24+', camera: 'fit every built plot + downtown + sign, 92% of the screen, zoom 0.18 to 0.9, back after 4.2 s', towers: 'Town 2, City +3, Metropolis +4; each grows over 1.4 s (cubic out), 0.35 s apart, starting 0.9 s in', fireworks: '7 volleys of 3 rockets on random built plots, 260 ms apart', confetti: 110, saved: 'META tierMax, so each tier celebrates once' },
        roblox: 'Server counts built plots and sets a TierIndex attribute on the player; the client listens and plays: Camera to Scriptable, tween out to a CFrame that frames the island bounds (compute from the plot parts), ScreenGui caption with UIScale Back Out, Firework parts with Trails, then tween each skyscraper Model from Size Y 0 (scale with PivotTo + ScaleTo) over 1.4 s. Award a Badge per tier with BadgeService.',
        run: celebrate,
    });
    FX.def({
        id: 'studExpress', name: 'Stud Express train', tier: 'ambient', category: 'City', trigger: 'Always from Town (5 plots)',
        durationMs: 0, sound: 'whistle when it comes into view (30 s cooldown), chug while close', haptic: 'none',
        desc: 'A four car train (red engine with a black cab, then blue, yellow and green cars) runs an elevated loop around everything you have built, puffing smoke. At night the windows glow and the headlight reflects on the water. The track re-lays itself when the city grows.',
        spec: { track: 'rounded rectangle 0.9 u outside the built bounds (never closer than -4.4 to clear the lighthouse), corners r 1.3, deck 0.4 u wide at z 1.1, pillars every 2 u', speed: '2.2 u/s', cars: 'engine 0.9 u, cars 0.72 u, gap 0.08 u', smoke: 'one puff per 0.14 s from the chimney' },
        roblox: 'Track: a Beam-free approach is simplest, a chain of anchored Parts (deck + rails) generated from the plot bounds. Train: a Model per car moved on the client every Heartbeat with CFrame.lookAt along the sampled path (no physics). Smoke ParticleEmitter on the chimney, SpotLight headlight at night, a Sound for the whistle with RollOffMode InverseTapered.',
        run() { const [x, y] = trackAt(train.s); R.cam.tx = x; R.cam.ty = y; },
    });
    FX.def({
        id: 'citySign', name: 'STUD CITY sign', tier: 'support', category: 'City', trigger: 'A letter lands each time a plot is built, until STUD CITY is complete',
        durationMs: 700, sound: 'letterDrop', haptic: 'none',
        desc: 'A giant sign on a brick hill behind Stud Square. It starts as STUD; every plot you build drops the next letter in with a bounce and a puff. At night the letters glow and a chase light runs along them.',
        spec: { letters: '1 u tall, 0.6 u apart, each tilted up to 3.4 deg, on two posts', drop: '3 u with easeOutBounce over 0.7 s', night: 'glow 1.1x letter size, chase cos(3t - 0.8 i)' },
        roblox: 'Each letter is a MeshPart (or SurfaceGui TextLabel on a Part) with a Neon material variant at night; drop with a Bounce tween. Chase lights: loop the letters and tween Material/Color with a phase offset.',
        run() { R.cam.tx = HC[0]; R.cam.ty = HC[1]; for (const L of LETTERS) L.t0 = R.T + L.i * 0.12; },
    });
    FX.def({
        id: 'downtown', name: 'Downtown skyline', tier: 'ambient', category: 'City', trigger: 'Town and up',
        durationMs: 0, sound: 'towerRise when a tower grows', haptic: 'none',
        desc: 'A concrete islet behind the sign fills with skyscrapers as the city grows: glass bands by day, a scatter of lit rooms at night, blinking red aviation lights, a helipad on the tallest, a billboard with your live Studs per second and, at Metropolis, three searchlights sweeping the night sky.',
        spec: { towers: '9 total, 1.8 to 5.2 u tall', windows: 'bands every 0.3 u; at night 35% to 70% lit (fixed per window)', searchlights: 'additive 0.05 rad cones, 1.3 x screen height, sweep 0.6 rad at 0.33 rad/s', billboard: 'tier name + live Studs/s' },
        roblox: 'Towers are Models with a Glass material and a SurfaceGui or Decal window pattern; at night swap to a Neon window texture. Searchlights: a SpotLight plus a Beam from the roof with LightEmission 1, rotated by a script. Billboard: SurfaceGui with a TextLabel updated every second.',
        run() { R.cam.tx = DC[0]; R.cam.ty = DC[1]; if (R.env.night < 0.5) R.env.tod = 22; },
    });

    WORLD.use('update', update);
    WORLD.use('underPlates', () => {
        drawDowntownPlate();
        // shadow of the elevated track on the sea
        if (R.builtCache().size >= TIERS[1].min && track.pts.length && R.sun.alpha > 0.02 && R.K >= 14) {
            const g = R.g, ox = -R.sun.x * TZ * R.sun.len * 0.5, oy = -R.sun.y * TZ * R.sun.len * 0.5;
            g.strokeStyle = `rgba(10,40,80,${R.sun.alpha * 0.6})`; g.lineWidth = THW * 2 * R.K * 0.8; g.lineJoin = 'round'; g.beginPath();
            track.pts.forEach((q, i) => { const s = R.P(q[0] + ox, q[1] + oy, 0); if (i) g.lineTo(s[0], s[1]); else g.moveTo(s[0], s[1]); }); g.closePath(); g.stroke();
        }
    });
    WORLD.use('items', (items) => {
        const K = R.K;
        // sign hill and letters
        for (let i = 0; i < LETTERS.length; i++) { const L = LETTERS[i]; const s = R.P(L.x, L.y, 0); if (!R.onScreen(s[0], s[1], 3 * K)) continue; const idx = LETTERS.slice(0, i).filter(q => q.ch !== ' ').length; items.push({ d: R.depth(L.x, L.y), draw() { drawHillColumn(L); drawLetter(L, idx); } }); }
        // downtown
        if (shownTier >= 1) {
            for (const tw of TOWERS) if (tw.need <= shownTier) items.push({ d: R.depth(tw.x, tw.y), draw() { drawTower(tw); } });
            items.push({ d: R.depth(BOARD[0], BOARD[1]), draw: drawBillboard });
        }
        // express
        if (R.builtCache().size >= TIERS[1].min && track.pts.length) {
            const pts = track.pts, n = pts.length;
            for (let i = 0; i < n; i++) {
                const a = pts[i], b = pts[(i + 1) % n];
                const m = R.P((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, TZ); if (!R.onScreen(m[0], m[1], K + 20)) continue;
                items.push({ d: R.depth((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), draw() { drawTrackSeg(a, b, i % 4 === 0); } });
            }
            for (const o of carPositions()) { const s = R.P(o.x, o.y, TZ); if (!R.onScreen(s[0], s[1], K * 2)) continue; items.push({ d: R.depth(o.x, o.y) + 0.3, draw() { drawCar(o); } }); }
        }
        // bridge traffic
        if (R.builtCache().has('3,0') && R.builtCache().has('5,0') && K >= 18) for (const c of cars) { const s = R.P(c.x, 0, R.TOP); if (!R.onScreen(s[0], s[1], K)) continue; items.push({ d: R.depth(c.x, c.lane * 0.22) + 0.05, draw() { drawBridgeCar(c); } }); }
    });
    WORLD.use('post', drawSearchlights);

    // badges for each tier (cosmetic)
    if (typeof META !== 'undefined' && META.BADGES) {
        META.BADGES.push(
            { id: 'tierTown', name: 'Town Charter', desc: 'Grow your village into Stud Town (5 plots)', icon: '⌂', test: () => tierIndex() >= 1 },
            { id: 'tierCity', name: 'City Lights', desc: 'Grow into Stud City (12 plots)', icon: '◆', test: () => tierIndex() >= 2 },
            { id: 'tierMetro', name: 'Metropolis', desc: 'Grow into Stud Metropolis (24 plots)', icon: '♜', test: () => tierIndex() >= 3 },
        );
    }
    function init() { syncLetters(true); syncTowers(true); const x = X(); if (x.tierMax === undefined) x.tierMax = tierIndex(); }
    return { TIERS, tier, tierIndex, init, celebrate, obox, get train() { return train; }, LETTERS, TOWERS };
})();
