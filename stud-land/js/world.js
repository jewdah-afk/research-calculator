// Stud Land world: an isometric LEGO archipelago drawn on one canvas.
// Every Upgrade Land baseplate is an island plot. Every upgrade is a brick machine standing on its
// original tree coordinate, and it grows a brick per step of level. Nothing here changes game math:
// it only reads state and listens to engine events.
const INK = '#1b1530';
const WORLD = (() => {
    const cv = document.getElementById('world');
    const G = cv.getContext('2d', { alpha: false });
    let g = G; // swapped to an offscreen context while baking sprites
    let W = 0, H = 0, DPR = 1;
    const BASE = 64, ZH = 0.82, SQ = 0.5, TOP = 0.34, INSET = 0.16;
    const cam = { x: 0, y: 0, zoom: 1, angle: 0, tAngle: 0, tZoom: 1, tx: null, ty: null, nudgeX: 0, nudgeY: 0, kick: 0 };
    let cosA = 1, sinA = 0, K = BASE;
    let T = 0, dtS = 0.016;
    const env = { tod: 10, dayLen: 12 * 60, night: 0, rain: 0, rainUntil: 0, nextRain: 240, rainbow: 0, wind: 0.25 };
    const DIRECTOR = { mode: 'full', heroUntil: 0, sup: [], flashes: [], dim: 0 };
    let hits = [];
    const dbg = { on: false, last: null };
    let ZB = 0.34; // base height of the item being drawn: plate top, or the water for a plot not built yet
    let selectedId = null;
    let hoverKey = null;
    const lights = [];

    // ---------- projection ----------
    function setupFrame() { const phi = cam.angle + Math.PI / 4; cosA = Math.cos(phi); sinA = Math.sin(phi); K = BASE * cam.zoom; }
    function P(x, y, z) {
        const dx = x - cam.x, dy = y - cam.y;
        return [W / 2 + (dx * cosA - dy * sinA) * K + cam.nudgeX, H / 2 + (dx * sinA + dy * cosA) * K * SQ - z * K * ZH + cam.nudgeY];
    }
    function depth(x, y) { return (x - cam.x) * sinA + (y - cam.y) * cosA; }
    function unproject(sx, sy, z = TOP) {
        const u = (sx - W / 2 - cam.nudgeX) / K, v = (sy - H / 2 - cam.nudgeY + z * K * ZH) / (K * SQ);
        return [cam.x + u * cosA + v * sinA, cam.y - u * sinA + v * cosA];
    }
    function onScreen(sx, sy, m) { return sx > -m && sx < W + m && sy > -m && sy < H + m; }

    // ---------- color cache ----------
    const _tone = new Map();
    function tone(hex, amt) { const k = hex + amt; let v = _tone.get(k); if (!v) { v = shade(hex, amt); _tone.set(k, v); } return v; }

    // ---------- effects director (attention budget) ----------
    function nowMs() { return performance.now(); }
    const FXD = {
        amount() { return DIRECTOR.mode === 'full' ? 1 : DIRECTOR.mode === 'reduced' ? 0.45 : 0; },
        hero(ms) { const n = nowMs(); if (n < DIRECTOR.heroUntil) return false; DIRECTOR.heroUntil = n + ms; return true; },
        inHero() { return nowMs() < DIRECTOR.heroUntil; },
        support() { const n = nowMs(); DIRECTOR.sup = DIRECTOR.sup.filter(t => n - t < 250); if (DIRECTOR.sup.length >= 3) return false; DIRECTOR.sup.push(n); return true; },
        flash() { if (DIRECTOR.mode !== 'full') return false; const n = nowMs(); DIRECTOR.flashes = DIRECTOR.flashes.filter(t => n - t < 1000); if (DIRECTOR.flashes.length >= 2) return false; DIRECTOR.flashes.push(n); return true; },
        shake(a) { if (DIRECTOR.mode !== 'full') return; cam.kick = Math.min(1, cam.kick + a); },
    };

    // ---------- plot state ----------
    const plotAnim = new Map();       // key -> {t0} build animation
    const nodeAnim = new Map();       // id -> {t0, kind, from}
    const lastCount = new Map();      // id -> brick count drawn last frame
    const textures = new Map();
    let builtCache = new Set();
    function builtPlots() { return builtCache; }
    function refreshBuilt() {
        const s = new Set();
        for (const p of PLOTS.values()) if (plotIsBuilt(p)) s.add(p.key);
        builtCache = s; ghostAt = -1;
    }
    let ghostCache = new Map(), ghostAt = -1;
    function plotVisibleGhost(p) {
        if (T - ghostAt > 0.25) { ghostCache = new Map(); ghostAt = T; }
        let v = ghostCache.get(p.key);
        if (v === undefined) { v = ghostCheck(p); ghostCache.set(p.key, v); }
        return v;
    }
    function ghostCheck(p) {
        if (builtCache.has(p.key)) return false;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (builtCache.has((p.gx + dx) + ',' + (p.gy + dy))) return true;
        if (p.key === '5,0' && builtCache.has('3,0')) return true;
        return p.nodes.some(n => isNodeUnlocked(n));
    }

    // ---------- top textures ----------
    const THEMES = {
        meadow: { base: '#4cbf56', alt: '#63d06a', pad: '#3a9a44', extra: 'flowers' },
        lab: { base: '#e8f1fb', alt: '#d4e6f7', pad: '#b9d3ee', extra: 'grid' },
        factory: { base: '#9aa3ad', alt: '#b3bac2', pad: '#7d858e', extra: 'hazard' },
        energy: { base: '#ffb347', alt: '#ffc46b', pad: '#e8912a', extra: 'bolts' },
        studio: { base: '#c79bf2', alt: '#d8b6f7', pad: '#a878db', extra: 'confetti' },
        gold: { base: '#f7cf4a', alt: '#ffe07a', pad: '#d9ab22', extra: 'shine' },
        gym: { base: '#cfd6de', alt: '#e2e7ec', pad: '#aab4bf', extra: 'lanes' },
        mill: { base: '#57d8cd', alt: '#7fe4db', pad: '#35b3a8', extra: 'grid' },
        sky: { base: '#f2f7ff', alt: '#ffffff', pad: '#d6e4f7', extra: 'clouds' },
        path: { base: '#ffbf5a', alt: '#ffd18a', pad: '#e59a2c', extra: 'lanes' },
        grove: { base: '#5aa84a', alt: '#73bd5e', pad: '#8a5a2f', extra: 'leaves' },
        sun: { base: '#f5d55a', alt: '#ffe78a', pad: '#d9a826', extra: 'flowers' },
        portal: { base: '#5b1a3a', alt: '#74244d', pad: '#3d0f26', extra: 'runes' },
        yard: { base: '#6f8fd9', alt: '#8aa6e6', pad: '#4f6fbf', extra: 'grid' },
        mine: { base: '#8d8f93', alt: '#a3a5a9', pad: '#6d6f73', extra: 'ore' },
        gem: { base: '#55607a', alt: '#6a7690', pad: '#3f4860', extra: 'gems' },
        deep: { base: '#3b3444', alt: '#4b4356', pad: '#2a2431', extra: 'lava' },
        finale: { base: '#f4f4f4', alt: '#ffffff', pad: '#d9d9e0', extra: 'checker' },
        cosmos: { base: '#2c2f55', alt: '#3b3f70', pad: '#1e2040', extra: 'stars' },
        market: { base: '#58c27d', alt: '#78d396', pad: '#3a9b5c', extra: 'awning' },
        forge: { base: '#6b4b1e', alt: '#83602a', pad: '#4a3212', extra: 'lava' },
        night: { base: '#2d2d36', alt: '#3a3a46', pad: '#1d1d24', extra: 'stars' },
        canyon: { base: '#d9573f', alt: '#e8735a', pad: '#a83a26', extra: 'bands' },
        bay: { base: '#9be39b', alt: '#b8efb8', pad: '#6fc46f', extra: 'flowers' },
        cash: { base: '#2f8f4f', alt: '#3fa862', pad: '#1f6b39', extra: 'bills' },
        lagoon: { base: '#dedde8', alt: '#efeef6', pad: '#bdbccb', extra: 'loops' },
        beach: { base: '#f7dca0', alt: '#fbe8bd', pad: '#e3bf73', extra: 'shells' },
        cookie: { base: '#c68c52', alt: '#d6a26b', pad: '#9c6632', extra: 'chips' },
        tent: { base: '#e0a066', alt: '#ebb783', pad: '#b87a40', extra: 'stripes' },
        soon: { base: '#dddddd', alt: '#eeeeee', pad: '#cccccc', extra: 'none' },
    };
    function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
    function hashKey(k) { let h = 2166136261; for (const c of k) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }
    function makeTexture(p) {
        const TPU = 64, S = 5 * TPU, th = THEMES[p.theme] || THEMES.meadow;
        const c = document.createElement('canvas'); c.width = c.height = S;
        const t = c.getContext('2d'); const r = rng(hashKey(p.key));
        t.fillStyle = th.base; t.fillRect(0, 0, S, S);
        // flat tile patches
        for (let i = 0; i < 7; i++) { t.fillStyle = th.alt; const w = (1 + (r() * 3 | 0)) * 16, h = (1 + (r() * 3 | 0)) * 16; t.fillRect((r() * 20 | 0) * 16, (r() * 20 | 0) * 16, w, h); }
        extras(t, th.extra, S, r, th);
        // conveyor belts between unlocked machines (flat tiles, baked; they only change on unlock)
        const belts = [];
        for (const n of p.nodes) {
            if (!isNodeUnlocked(n)) continue;
            for (const [rx, ry] of (n.reqs || [])) {
                if (plotKeyOf(rx, ry) !== p.key) continue;
                belts.push([(rx - p.x0) * TPU, (ry - p.y0) * TPU, (n.coords[0] - p.x0) * TPU, (n.coords[1] - p.y0) * TPU]);
            }
        }
        t.lineCap = 'round';
        t.strokeStyle = 'rgba(27,21,48,0.6)'; t.lineWidth = 0.18 * TPU;
        t.beginPath(); for (const [a, b, c, d] of belts) { t.moveTo(a, b); t.lineTo(c, d); } t.stroke();
        t.strokeStyle = 'rgba(255,210,63,0.9)'; t.lineWidth = 0.05 * TPU; t.setLineDash([0.07 * TPU, 0.12 * TPU]);
        t.beginPath(); for (const [a, b, c, d] of belts) { t.moveTo(a, b); t.lineTo(c, d); } t.stroke();
        t.setLineDash([]); t.lineCap = 'butt';
        const onBelt = (x, y) => belts.some(([a, b, c, d]) => { const dx = c - a, dy = d - b, L = dx * dx + dy * dy || 1; let u = ((x - a) * dx + (y - b) * dy) / L; u = Math.max(0, Math.min(1, u)); return Math.hypot(a + dx * u - x, b + dy * u - y) < 0.12 * TPU; });
        // machine pads (flat tiles, no studs)
        const pads = [];
        for (const n of p.nodes) {
            const lx = (n.coords[0] - p.x0) * TPU, ly = (n.coords[1] - p.y0) * TPU;
            const half = (n.height === 0.5 ? 0.22 : 0.4) * TPU;
            pads.push([lx - half, ly - half, half * 2]);
            t.fillStyle = th.pad; t.fillRect(lx - half, ly - half, half * 2, half * 2);
            t.strokeStyle = 'rgba(0,0,0,0.18)'; t.lineWidth = 2; t.strokeRect(lx - half + 1, ly - half + 1, half * 2 - 2, half * 2 - 2);
        }
        // studs, 4 per unit
        const pitch = TPU / 4, rad = pitch * 0.3;
        for (let i = 0; i < 20; i++) for (let j = 0; j < 20; j++) {
            const x = i * pitch + pitch / 2, y = j * pitch + pitch / 2;
            if (pads.some(([px, py, s]) => x > px && x < px + s && y > py && y < py + s) || onBelt(x, y)) continue;
            // translucent layers, so a stud takes the colour of whatever is under it
            t.fillStyle = 'rgba(0,0,0,0.24)'; t.beginPath(); t.arc(x + 1.6, y + 1.8, rad, 0, 7); t.fill();
            t.fillStyle = 'rgba(0,0,0,0.10)'; t.beginPath(); t.arc(x, y, rad, 0, 7); t.fill();
            t.fillStyle = 'rgba(255,255,255,0.22)'; t.beginPath(); t.arc(x - 0.6, y - 0.8, rad * 0.8, 0, 7); t.fill();
            t.fillStyle = 'rgba(255,255,255,0.5)'; t.beginPath(); t.arc(x - rad * 0.35, y - rad * 0.4, rad * 0.28, 0, 7); t.fill();
        }
        return c;
    }
    function extras(t, kind, S, r, th) {
        const U = S / 5;
        t.save();
        if (kind === 'grid') { t.strokeStyle = 'rgba(40,90,160,0.25)'; t.lineWidth = 2; for (let i = 0; i <= 5; i++) { t.beginPath(); t.moveTo(i * U, 0); t.lineTo(i * U, S); t.stroke(); t.beginPath(); t.moveTo(0, i * U); t.lineTo(S, i * U); t.stroke(); } }
        else if (kind === 'flowers') { for (let i = 0; i < 26; i++) { const x = r() * S, y = r() * S; t.fillStyle = ['#ff6b8a', '#ffd23f', '#ffffff', '#9b7bff'][i % 4]; for (let k = 0; k < 5; k++) { t.beginPath(); t.arc(x + Math.cos(k * 1.26) * 4, y + Math.sin(k * 1.26) * 4, 3.2, 0, 7); t.fill(); } t.fillStyle = '#ffb300'; t.beginPath(); t.arc(x, y, 2.4, 0, 7); t.fill(); } }
        else if (kind === 'hazard') { t.fillStyle = '#ffd23f'; t.fillRect(0, 0, S, 14); t.fillRect(0, S - 14, S, 14); t.fillStyle = INK; for (let x = -14; x < S; x += 28) { t.beginPath(); t.moveTo(x, 0); t.lineTo(x + 14, 0); t.lineTo(x + 28, 14); t.lineTo(x + 14, 14); t.fill(); t.beginPath(); t.moveTo(x, S - 14); t.lineTo(x + 14, S - 14); t.lineTo(x + 28, S); t.lineTo(x + 14, S); t.fill(); } }
        else if (kind === 'bolts') { t.fillStyle = 'rgba(255,255,255,0.35)'; for (let i = 0; i < 5; i++) { const x = r() * S, y = r() * S; t.beginPath(); t.moveTo(x, y); t.lineTo(x + 12, y + 18); t.lineTo(x + 4, y + 18); t.lineTo(x + 14, y + 38); t.lineTo(x - 4, y + 14); t.lineTo(x + 4, y + 14); t.fill(); } }
        else if (kind === 'confetti') { for (let i = 0; i < 60; i++) { t.fillStyle = ['#ff6b8a', '#ffd23f', '#4aa8ff', '#39d98a', '#fff'][i % 5]; t.save(); t.translate(r() * S, r() * S); t.rotate(r() * 3); t.fillRect(-4, -2, 8, 4); t.restore(); } }
        else if (kind === 'shine') { const gr = t.createLinearGradient(0, 0, S, S); gr.addColorStop(0.3, 'rgba(255,255,255,0)'); gr.addColorStop(0.5, 'rgba(255,255,255,0.35)'); gr.addColorStop(0.7, 'rgba(255,255,255,0)'); t.fillStyle = gr; t.fillRect(0, 0, S, S); }
        else if (kind === 'lanes') { t.strokeStyle = 'rgba(255,255,255,0.55)'; t.lineWidth = 4; t.setLineDash([16, 12]); for (let i = 1; i < 5; i++) { t.beginPath(); t.moveTo(i * U, 0); t.lineTo(i * U, S); t.stroke(); } }
        else if (kind === 'clouds') { t.fillStyle = 'rgba(160,190,230,0.35)'; for (let i = 0; i < 6; i++) { const x = r() * S, y = r() * S; for (let k = 0; k < 4; k++) { t.beginPath(); t.arc(x + k * 12, y + (k % 2) * 6, 14, 0, 7); t.fill(); } } }
        else if (kind === 'leaves') { for (let i = 0; i < 40; i++) { t.fillStyle = i % 3 ? 'rgba(40,110,40,0.5)' : 'rgba(170,220,90,0.6)'; t.beginPath(); t.ellipse(r() * S, r() * S, 7, 4, r() * 3, 0, 7); t.fill(); } }
        else if (kind === 'runes') { t.strokeStyle = 'rgba(255,90,140,0.45)'; t.lineWidth = 4; t.beginPath(); t.arc(S / 2, S / 2, S * 0.36, 0, 7); t.stroke(); t.beginPath(); t.arc(S / 2, S / 2, S * 0.22, 0, 7); t.stroke(); for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; t.beginPath(); t.moveTo(S / 2 + Math.cos(a) * S * 0.22, S / 2 + Math.sin(a) * S * 0.22); t.lineTo(S / 2 + Math.cos(a) * S * 0.36, S / 2 + Math.sin(a) * S * 0.36); t.stroke(); } }
        else if (kind === 'ore') { for (let i = 0; i < 30; i++) { t.fillStyle = ['#e0a15a', '#d7d7d7', '#ffd23f', '#3b6cf0'][i % 4]; t.beginPath(); t.arc(r() * S, r() * S, 3 + r() * 3, 0, 7); t.fill(); } }
        else if (kind === 'gems') { for (let i = 0; i < 22; i++) { t.fillStyle = ['#22d3ee', '#2563eb', '#a855f7'][i % 3]; const x = r() * S, y = r() * S; t.beginPath(); t.moveTo(x, y - 7); t.lineTo(x + 6, y); t.lineTo(x, y + 7); t.lineTo(x - 6, y); t.fill(); } }
        else if (kind === 'lava') { t.strokeStyle = 'rgba(255,120,30,0.8)'; t.lineWidth = 4; t.lineCap = 'round'; for (let i = 0; i < 8; i++) { let x = r() * S, y = r() * S; t.beginPath(); t.moveTo(x, y); for (let k = 0; k < 4; k++) { x += (r() - 0.5) * 60; y += (r() - 0.5) * 60; t.lineTo(x, y); } t.stroke(); } }
        else if (kind === 'checker') { t.fillStyle = 'rgba(0,0,0,0.08)'; for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) if ((i + j) % 2) t.fillRect(i * U, j * U, U, U); }
        else if (kind === 'stars') { for (let i = 0; i < 50; i++) { t.fillStyle = `rgba(255,255,255,${0.3 + r() * 0.6})`; t.beginPath(); t.arc(r() * S, r() * S, 1 + r() * 2, 0, 7); t.fill(); } }
        else if (kind === 'awning') { for (let i = 0; i < 10; i++) { t.fillStyle = i % 2 ? '#ffffff' : '#e8453c'; t.fillRect(i * S / 10, 0, S / 10, 18); } }
        else if (kind === 'bands') { for (let i = 0; i < 6; i++) { t.fillStyle = i % 2 ? 'rgba(120,20,10,0.25)' : 'rgba(255,200,150,0.18)'; t.fillRect(0, i * S / 6 + (r() - 0.5) * 10, S, S / 12); } }
        else if (kind === 'bills') { for (let i = 0; i < 14; i++) { t.save(); t.translate(r() * S, r() * S); t.rotate(r() * 3); t.fillStyle = '#b9f5b9'; t.fillRect(-12, -6, 24, 12); t.fillStyle = '#2f8f4f'; t.font = 'bold 10px sans-serif'; t.textAlign = 'center'; t.textBaseline = 'middle'; t.fillText('$', 0, 0); t.restore(); } }
        else if (kind === 'loops') { t.strokeStyle = 'rgba(150,120,255,0.35)'; t.lineWidth = 5; for (let i = 0; i < 4; i++) { const x = r() * S, y = r() * S; t.beginPath(); t.ellipse(x - 10, y, 10, 7, 0, 0, 7); t.ellipse(x + 10, y, 10, 7, 0, 0, 7); t.stroke(); } }
        else if (kind === 'shells') { for (let i = 0; i < 14; i++) { t.fillStyle = ['#ffb6c9', '#ffffff', '#ffd9a0'][i % 3]; t.beginPath(); t.arc(r() * S, r() * S, 5, Math.PI, 0); t.fill(); } }
        else if (kind === 'chips') { for (let i = 0; i < 40; i++) { t.fillStyle = '#4a2a12'; t.beginPath(); t.arc(r() * S, r() * S, 3 + r() * 2, 0, 7); t.fill(); } }
        else if (kind === 'stripes') { for (let i = 0; i < 10; i++) if (i % 2) { t.fillStyle = 'rgba(255,255,255,0.25)'; t.fillRect(0, i * S / 10, S, S / 10); } }
        t.restore();
    }
    let texBudget = 1;
    function textureFor(p) {
        let e = textures.get(p.key);
        const sig = p.nodes.reduce((a, n) => a + (isNodeUnlocked(n) ? 1 : 0), 0);
        if (!e || (e.sig !== sig && texBudget > 0)) { texBudget--; e = { c: makeTexture(p), sig }; textures.set(p.key, e); }
        return e.c;
    }

    // ---------- primitive drawing ----------
    function poly(pts, fill, stroke, lw) {
        g.beginPath(); g.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length; i++) g.lineTo(pts[i][0], pts[i][1]);
        g.closePath();
        if (fill) { g.fillStyle = fill; g.fill(); }
        if (stroke) { g.strokeStyle = stroke; g.lineWidth = lw; g.stroke(); }
    }
    const EDGES = [[0, 1, 0, -1], [1, 2, 1, 0], [2, 3, 0, 1], [3, 0, -1, 0]];
    // Axis-aligned box: sides that face the camera, then top. Returns screen bbox.
    function box(cx, cy, z, hw, hd, h, col, opt = {}) {
        const cs = [[cx - hw, cy - hd], [cx + hw, cy - hd], [cx + hw, cy + hd], [cx - hw, cy + hd]];
        const bot = cs.map(c => P(c[0], c[1], z)), top = cs.map(c => P(c[0], c[1], z + h));
        const lw = opt.lw !== undefined ? opt.lw : Math.max(1, 1.6 * cam.zoom);
        const ink = opt.ink === undefined ? INK : opt.ink;
        for (const [a, b, nx, ny] of EDGES) {
            const nv = nx * sinA + ny * cosA; if (nv <= 0.001) continue;
            const nu = nx * cosA - ny * sinA;
            const f = [bot[a], bot[b], top[b], top[a]];
            poly(f, opt.alpha ? null : tone(col, nu < 0 ? -0.12 : -0.3), ink, lw);
            if (opt.alpha) { g.globalAlpha = opt.alpha; poly(f, tone(col, nu < 0 ? -0.12 : -0.3)); g.globalAlpha = 1; }
            if (opt.seams && h > 0.2) {
                g.strokeStyle = 'rgba(0,0,0,0.28)'; g.lineWidth = Math.max(1, cam.zoom);
                const n = opt.seams;
                for (let i = 1; i < n; i++) {
                    const zz = z + h * i / n; const p1 = P(cs[a][0], cs[a][1], zz), p2 = P(cs[b][0], cs[b][1], zz);
                    g.beginPath(); g.moveTo(p1[0], p1[1]); g.lineTo(p2[0], p2[1]); g.stroke();
                }
            }
        }
        if (opt.alpha) { g.globalAlpha = opt.alpha; poly(top, opt.topCol || col); g.globalAlpha = 1; poly(top, null, ink, lw); }
        else poly(top, opt.topCol || col, ink, lw);
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const q of top.concat(bot)) { if (q[0] < x0) x0 = q[0]; if (q[0] > x1) x1 = q[0]; if (q[1] < y0) y0 = q[1]; if (q[1] > y1) y1 = q[1]; }
        return [x0, y0, x1, y1];
    }
    function stud(x, y, z, r, col) {
        const b = P(x, y, z), t = P(x, y, z + r * 0.8);
        const rx = r * K, ry = r * K * SQ;
        g.fillStyle = tone(col, -0.3); g.beginPath(); g.ellipse(b[0], b[1], rx, ry, 0, 0, 7); g.fill();
        g.fillRect(b[0] - rx, t[1], rx * 2, b[1] - t[1]);
        g.fillStyle = tone(col, 0.12); g.beginPath(); g.ellipse(t[0], t[1], rx, ry, 0, 0, 7); g.fill();
        if (K > 70) { g.strokeStyle = INK; g.lineWidth = Math.max(0.8, cam.zoom * 0.9); g.stroke(); }
    }

    // ---------- plates ----------
    function plateCorners(p, z, inset = INSET) {
        const a = p.x0 + inset, b = p.y0 + inset, c = p.x0 + 5 - inset, d = p.y0 + 5 - inset;
        return [P(a, b, z), P(c, b, z), P(c, d, z), P(a, d, z)];
    }
    function drawPlate(p, built) {
        const cx = p.x0 + 2.5, cy = p.y0 + 2.5;
        const c = P(cx, cy, 0); if (!onScreen(c[0], c[1], 5 * K + 60)) return;
        if (!built) return drawGhost(p);
        const an = plotAnim.get(p.key); let dz = 0, sc = 1;
        if (an) {
            const t = (T - an.t0);
            if (t > 1.6) plotAnim.delete(p.key);
            else { const k = Math.min(1, t / 0.9); dz = (1 - easeOutBounce(k)) * 6; sc = 0.6 + 0.4 * Math.min(1, t / 0.5); }
        }
        const th = THEMES[p.theme] || THEMES.meadow;
        const inset = INSET + (1 - sc) * 2.5;
        // underwater silhouette and foam
        if (!an) {
            g.globalAlpha = 0.35; poly(plateCorners(p, -0.45, INSET - 0.18), '#0d4f6e'); g.globalAlpha = 1;
            const f = plateCorners(p, 0, INSET - 0.07);
            g.setLineDash([6 * cam.zoom, 9 * cam.zoom]); g.lineDashOffset = -T * 14 * cam.zoom;
            poly(f, null, 'rgba(255,255,255,0.7)', Math.max(1.2, 2.4 * cam.zoom)); g.setLineDash([]);
        }
        // slab sides (two brick courses) with seam
        const cs = [[p.x0 + inset, p.y0 + inset], [p.x0 + 5 - inset, p.y0 + inset], [p.x0 + 5 - inset, p.y0 + 5 - inset], [p.x0 + inset, p.y0 + 5 - inset]];
        const lw = Math.max(1.2, 2.2 * cam.zoom);
        for (const [a, b, nx, ny] of EDGES) {
            const nv = nx * sinA + ny * cosA; if (nv <= 0.001) continue;
            const nu = nx * cosA - ny * sinA;
            const q = [P(cs[a][0], cs[a][1], dz - 0.22), P(cs[b][0], cs[b][1], dz - 0.22), P(cs[b][0], cs[b][1], dz + TOP), P(cs[a][0], cs[a][1], dz + TOP)];
            poly(q, tone(th.base, nu < 0 ? -0.22 : -0.4), INK, lw);
            const m1 = P(cs[a][0], cs[a][1], dz + TOP * 0.35), m2 = P(cs[b][0], cs[b][1], dz + TOP * 0.35);
            g.strokeStyle = 'rgba(0,0,0,0.25)'; g.lineWidth = Math.max(1, cam.zoom); g.beginPath(); g.moveTo(m1[0], m1[1]); g.lineTo(m2[0], m2[1]); g.stroke();
        }
        // textured top via affine transform
        const tex = textureFor(p); const TPU = 64;
        const o = P(p.x0, p.y0, dz + TOP);
        const s = sc; const ox = p.x0 + 2.5 - 2.5 * s, oy = p.y0 + 2.5 - 2.5 * s; const o2 = P(ox, oy, dz + TOP);
        g.save();
        g.beginPath(); const tp = plateCorners(p, dz + TOP, inset); g.moveTo(tp[0][0], tp[0][1]); for (let i = 1; i < 4; i++) g.lineTo(tp[i][0], tp[i][1]); g.closePath(); g.clip();
        g.setTransform(DPR * K * cosA / TPU * s, DPR * K * SQ * sinA / TPU * s, -DPR * K * sinA / TPU * s, DPR * K * SQ * cosA / TPU * s, DPR * o2[0], DPR * o2[1]);
        g.imageSmoothingEnabled = true;
        g.drawImage(tex, 0, 0);
        g.setTransform(DPR, 0, 0, DPR, 0, 0);
        g.restore();
        poly(plateCorners(p, dz + TOP, inset), null, INK, lw);
        if (hoverKey === p.key) { g.globalAlpha = 0.18 + 0.08 * Math.sin(T * 4); poly(plateCorners(p, dz + TOP, inset), '#ffffff'); g.globalAlpha = 1; }
        if (p.key === '7,2') { g.save(); g.globalCompositeOperation = 'lighter'; poly(plateCorners(p, dz + TOP, inset), null, `rgba(255,80,40,${0.45 + 0.25 * Math.sin(T * 2.5)})`, Math.max(2, 5 * cam.zoom)); g.restore(); }
        void o;
    }
    function drawGhost(p) {
        const z = 0.02;
        const pts = plateCorners(p, z);
        g.globalAlpha = 0.16; poly(pts, p.soon ? '#ffffff' : '#bfe3ff'); g.globalAlpha = 1;
        g.save(); g.setLineDash([8 * cam.zoom, 8 * cam.zoom]); g.lineDashOffset = T * 10;
        poly(pts, null, 'rgba(255,255,255,0.85)', Math.max(1, 2 * cam.zoom)); g.restore();
        g.strokeStyle = 'rgba(255,255,255,0.22)'; g.lineWidth = 1;
        for (let i = 1; i < 5; i++) {
            let a = P(p.x0 + i, p.y0 + INSET, z), b = P(p.x0 + i, p.y0 + 5 - INSET, z); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
            a = P(p.x0 + INSET, p.y0 + i, z); b = P(p.x0 + 5 - INSET, p.y0 + i, z); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
        }
    }
    function drawBridges() {
        for (const key of builtCache) {
            const p = PLOTS.get(key);
            for (const [dx, dy] of [[1, 0], [0, 1]]) {
                const q = PLOTS.get((p.gx + dx) + ',' + (p.gy + dy));
                if (!q || !builtCache.has(q.key)) continue;
                const mx = dx ? p.x0 + 5 : p.x0 + 2.5, my = dy ? p.y0 + 5 : p.y0 + 2.5;
                const sp = P(mx, my, TOP); if (!onScreen(sp[0], sp[1], K)) continue;
                const hw = dx ? INSET + 0.08 : 0.42, hd = dy ? INSET + 0.08 : 0.42;
                box(mx, my, TOP - 0.1, hw, hd, 0.1, '#b07a45', { topCol: '#c98f55' });
            }
        }
        if (builtCache.has('3,0') && builtCache.has('5,0')) {
            for (let x = 12.5 + 5 - INSET; x < 22.5 + INSET; x += 0.5) box(x + 0.25, 0, TOP - 0.1, 0.26, 0.45, 0.1, '#9aa3ad', { topCol: x % 1 ? '#b3bac2' : '#c3c9cf' });
        }
    }

    // ---------- sprite cache ----------
    // A machine looks the same wherever it stands, so while the camera is still each look
    // (colour, bricks, maxed, trim) is drawn once into an offscreen canvas and stamped after that.
    // All sprites share one atlas canvas, so the GPU can batch the stamps.
    const sprites = new Map(); let spriteView = '';
    const ATLAS = { c: null, g: null, x: 0, y: 0, row: 0, S: 2048 };
    function atlasReset() {
        if (!ATLAS.c) { ATLAS.c = document.createElement('canvas'); ATLAS.c.width = ATLAS.c.height = ATLAS.S; ATLAS.g = ATLAS.c.getContext('2d'); }
        ATLAS.g.setTransform(1, 0, 0, 1, 0, 0); ATLAS.g.clearRect(0, 0, ATLAS.S, ATLAS.S);
        ATLAS.x = ATLAS.y = ATLAS.row = 0; sprites.clear();
    }
    function atlasAlloc(w, h) {
        if (w > ATLAS.S || h > ATLAS.S) return null;
        if (ATLAS.x + w > ATLAS.S) { ATLAS.x = 0; ATLAS.y += ATLAS.row + 2; ATLAS.row = 0; }
        if (ATLAS.y + h > ATLAS.S) return null;
        const r = [ATLAS.x, ATLAS.y]; ATLAS.x += w + 2; ATLAS.row = Math.max(ATLAS.row, h); return r;
    }
    function camStill() { return Math.abs(cam.zoom - cam.tZoom) < 1e-3 && Math.abs(cam.angle - cam.tAngle) < 1e-3; }
    function stamp(key, x, y, z, ext, drawFn) {
        const vk = cam.angle.toFixed(4) + '|' + K.toFixed(3) + '|' + DPR;
        if (vk !== spriteView || !ATLAS.c) { atlasReset(); spriteView = vk; }
        const base = P(x, y, z);
        let sp = sprites.get(key);
        if (!sp) {
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
            for (const dx of [-ext.hw, ext.hw]) for (const dy of [-ext.hw, ext.hw]) for (const dz of [0, ext.h]) {
                const q = P(x + dx, y + dy, z + dz); x0 = Math.min(x0, q[0]); x1 = Math.max(x1, q[0]); y0 = Math.min(y0, q[1]); y1 = Math.max(y1, q[1]);
            }
            const m = 5, ox = base[0] - x0 + m, oy = base[1] - y0 + m, w = Math.ceil(x1 - x0 + m * 2), h = Math.ceil(y1 - y0 + m * 2);
            const wp = Math.ceil(w * DPR), hp = Math.ceil(h * DPR);
            let at = atlasAlloc(wp, hp);
            if (!at) { atlasReset(); at = atlasAlloc(wp, hp); if (!at) return drawFn(); }
            const saved = g; g = ATLAS.g;
            g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.beginPath(); g.rect(at[0], at[1], wp, hp); g.clip();
            g.setTransform(DPR, 0, 0, DPR, at[0] + (ox - base[0]) * DPR, at[1] + (oy - base[1]) * DPR);
            drawFn();
            g.restore(); g = saved;
            sp = { ax: at[0], ay: at[1], wp, hp, ox, oy, w: wp / DPR, h: hp / DPR }; sprites.set(key, sp);
        }
        g.drawImage(ATLAS.c, sp.ax, sp.ay, sp.wp, sp.hp, base[0] - sp.ox, base[1] - sp.oy, sp.w, sp.h);
        return [base[0] - sp.ox + 5, base[1] - sp.oy + 5, base[0] - sp.ox + sp.w - 5, base[1] - sp.oy + sp.h - 5];
    }

    // ---------- machines ----------
    function nodeKind(n) {
        if (n.type === 'reset') return 'portal';
        if (n.type === 'info') return 'sign';
        const e = n.effects || [];
        if (e.some(x => x.type === 'automation')) return 'robot';
        if (e.some(x => x.type === 'max_level_mod')) return 'antenna';
        if (e.some(x => x.type === 'reset_gain_mult' || x.type === 'reset_gain_add')) return 'star';
        if (e.some(x => x.type === 'base_gain' || x.type === 'base_gain_raw')) return 'producer';
        return 'gear';
    }
    const TRIM = { green: '#39d98a', orange: '#ff9a2e', ornage: '#ff9a2e', red: '#ff4d4d', blue: '#4aa8ff' };
    function bricksFor(lvl, max) { if (lvl <= 0) return 0; if (lvl >= max) return 5; return 1 + Math.min(3, Math.floor(4 * Math.pow(lvl / max, 0.6))); }
    function drawMachine(n, it) {
        const [x, y] = n.coords; const small = n.height === 0.5;
        const hw = small ? 0.17 : 0.3; const bh = small ? 0.1 : 0.14;
        const lvl = it.lvl, max = it.max;
        const kind = it.kind;
        const col = curHex(n.costCurrency || 'P');
        const count = bricksFor(lvl, it.cap || max);
        const prev = lastCount.get(n.id);
        if (prev !== undefined && count > prev) nodeAnim.set(n.id, { t0: T, kind: 'grow' });
        lastCount.set(n.id, count);
        let sq = 1, drop = 0;
        const an = nodeAnim.get(n.id);
        if (an) {
            const t = T - an.t0;
            if (t > 0.9) nodeAnim.delete(n.id);
            else if (an.kind === 'grow' || an.kind === 'buy') { sq = 1 + 0.28 * Math.exp(-t * 7) * Math.sin(t * 28); drop = an.kind === 'grow' ? Math.max(0, 1 - t / 0.18) * 1.2 : 0; }
            else if (an.kind === 'reset') sq = Math.min(1, t / 0.6);
        }
        const LOD = K < 34, STUDS = K >= 40;
        let bb;
        if (count === 0) {
            // blueprint hologram: not bought yet
            const bob = Math.sin(T * 2.4 + x * 1.3 + y) * 0.03;
            const holo = () => box(x, y, ZB + 0.02 + bob, hw, hw, bh * 1.2, '#63b3ff', { alpha: 0.35, ink: 'rgba(170,220,255,0.95)', lw: Math.max(1, 1.4 * cam.zoom), topCol: '#9fd0ff' });
            bb = camStill() ? stamp('h' + small, x, y, ZB + 0.02 + bob, { hw, h: bh * 1.2 }, holo) : holo();
            if (!LOD) { const c = P(x, y, ZB + bh * 1.2 + 0.05 + bob); g.fillStyle = 'rgba(255,255,255,0.9)'; g.font = `${Math.max(10, 0.34 * K) | 0}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('+', c[0], c[1] - 0.08 * K); }
        } else {
            const h = count * bh * sq;
            const zBase = ZB + drop;
            const maxed = lvl >= max;
            const ztop = zBase + h;
            const trim = TRIM[n.borderColor];
            const body = () => {
                const b = box(x, y, zBase, hw * (2 - sq) ** 0.5, hw * (2 - sq) ** 0.5, h, col, { seams: K < 44 ? 0 : count, topCol: maxed ? '#ffd23f' : tone(col, 0.1) });
                // trim band on the top edge (the original border colour)
                if (trim && !LOD) box(x, y, ztop - 0.05, hw + 0.005, hw + 0.005, 0.05, trim, { lw: 0.8 });
                if (STUDS) {
                    const sr = small ? 0.05 : 0.075, off = small ? 0.08 : 0.135;
                    const sc2 = maxed ? '#ffd23f' : tone(col, 0.1);
                    const pts = [[x - off, y - off], [x + off, y - off], [x - off, y + off], [x + off, y + off]].sort((a, b) => depth(a[0], a[1]) - depth(b[0], b[1]));
                    for (const [sx, sy] of pts) stud(sx, sy, ztop, sr, sc2);
                    if (kind === 'producer') box(x + hw * 0.45, y - hw * 0.45, ztop, 0.06, 0.06, 0.22, '#6b6f78', { lw: 0.8 });
                }
                return b;
            };
            bb = (camStill() && sq === 1 && drop === 0) ? stamp(`m${col}${count}${maxed ? 1 : 0}${trim || ''}${small ? 1 : 0}${kind === 'producer' ? 'p' : ''}`, x, y, zBase, { hw: hw + 0.02, h: h + 0.32 }, body) : body();
            // moving accents (gears, arms, flags) only where you are looking
            if (STUDS && (it.focus || K > 80)) accent(n, kind, x, y, ztop, hw, it);
            if (maxed && DIRECTOR.mode !== 'minimal') {
                const s = P(x, y, ztop + 0.25); const tw = (Math.sin(T * 3 + x * 7 + y * 3) + 1) / 2;
                if (tw > 0.85) sparkle(s[0] + (x % 1) * 6, s[1], (tw - 0.85) * 60 * cam.zoom);
            }
            if (env.night > 0.25 && !small && it.focus) lights.push([x, y, zBase + h * 0.6, maxed ? '#ffd23f' : (kind === 'producer' ? col : '#ffd9a0'), kind === 'producer' || maxed ? 0.75 : 0.45]);
        }
        return bb;
    }
    function accent(n, kind, x, y, z, hw, it) {
        if (kind === 'producer') {
            const cx = x + hw * 0.45, cy = y - hw * 0.45;
            if (it.active && Math.random() < 0.02 * FXD.amount() * dtS * 60) puff(cx, cy, z + 0.25, curHex(it.prodCur || 'P'));
        } else if (kind === 'gear') {
            const c = P(x, y, z + 0.14); const r = 0.1 * K; const a = T * (it.active ? 2 : 0.3);
            g.save(); g.translate(c[0], c[1]); g.scale(1, SQ * 1.2); g.rotate(a);
            g.fillStyle = '#c9ced6'; g.strokeStyle = INK; g.lineWidth = Math.max(0.8, cam.zoom);
            g.beginPath(); for (let i = 0; i < 16; i++) { const rr = i % 2 ? r : r * 1.3; const aa = i * Math.PI / 8; g.lineTo(Math.cos(aa) * rr, Math.sin(aa) * rr); } g.closePath(); g.fill(); g.stroke();
            g.fillStyle = INK; g.beginPath(); g.arc(0, 0, r * 0.35, 0, 7); g.fill(); g.restore();
        } else if (kind === 'robot') {
            const a = P(x, y, z), b = P(x + Math.sin(T * 2 + x) * 0.15, y, z + 0.35);
            g.strokeStyle = INK; g.lineWidth = Math.max(1, 2 * cam.zoom); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
            const on = Math.sin(T * 6 + x) > 0; g.fillStyle = on ? '#ff4d4d' : '#6b1a1a'; g.beginPath(); g.arc(b[0], b[1], Math.max(2, 0.06 * K), 0, 7); g.fill();
            if (on && env.night > 0.2) lights.push([x, y, z + 0.35, '#ff4d4d', 0.4]);
        } else if (kind === 'antenna') {
            const a = P(x, y, z), b = P(x, y, z + 0.45);
            g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.6 * cam.zoom); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
            const w = Math.sin(T * 3 + y) * 0.2;
            g.fillStyle = '#ff4d8a'; g.beginPath(); g.moveTo(b[0], b[1]); g.lineTo(b[0] + 0.22 * K, b[1] + (0.06 + w * 0.1) * K); g.lineTo(b[0], b[1] + 0.14 * K); g.closePath(); g.fill(); g.stroke();
        } else if (kind === 'star') {
            const c = P(x, y, z + 0.28 + Math.sin(T * 2 + x) * 0.04);
            drawStar(c[0], c[1], 0.13 * K, '#ffd23f', T);
        }
    }
    function drawStar(x, y, r, col, rot) {
        g.save(); g.translate(x, y); g.rotate(rot * 0.6);
        g.beginPath(); for (let i = 0; i < 10; i++) { const rr = i % 2 ? r * 0.45 : r; const a = i * Math.PI / 5 - Math.PI / 2; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); }
        g.closePath(); g.fillStyle = col; g.fill(); g.strokeStyle = INK; g.lineWidth = Math.max(1, r * 0.18); g.stroke(); g.restore();
    }
    function sparkle(x, y, s) {
        g.save(); g.globalCompositeOperation = 'lighter'; g.fillStyle = 'rgba(255,240,180,0.95)';
        g.beginPath(); g.moveTo(x, y - s); g.lineTo(x + s * 0.2, y - s * 0.2); g.lineTo(x + s, y); g.lineTo(x + s * 0.2, y + s * 0.2); g.lineTo(x, y + s); g.lineTo(x - s * 0.2, y + s * 0.2); g.lineTo(x - s, y); g.lineTo(x - s * 0.2, y - s * 0.2); g.closePath(); g.fill(); g.restore();
    }
    function drawPortal(n, it) {
        const [x, y] = n.coords; const col = curHex(n.targetCurrency); const ready = it.gain > 0;
        const along = Math.abs(sinA) > Math.abs(cosA);
        const dx = along ? 0 : 0.34, dy = along ? 0.34 : 0;
        const b1 = box(x - dx, y - dy, ZB, 0.11, 0.11, 0.85, '#8a8f99');
        const b2 = box(x + dx, y + dy, ZB, 0.11, 0.11, 0.85, '#8a8f99');
        const lin = box(x, y, ZB + 0.85, along ? 0.13 : 0.47, along ? 0.47 : 0.13, 0.16, col, { topCol: tone(col, 0.2) });
        const c = P(x, y, ZB + 0.44);
        const r = 0.3 * K;
        g.save(); g.translate(c[0], c[1]);
        const grd = g.createRadialGradient(0, 0, 1, 0, 0, r);
        grd.addColorStop(0, ready ? '#ffffff' : 'rgba(255,255,255,0.3)'); grd.addColorStop(0.5, hexA(col, ready ? 0.85 : 0.35)); grd.addColorStop(1, hexA(col, 0));
        g.fillStyle = grd; g.beginPath(); g.ellipse(0, 0, r * 0.62, r * 1.05, 0, 0, 7); g.fill();
        if (ready && DIRECTOR.mode !== 'minimal') {
            g.globalCompositeOperation = 'lighter';
            for (let i = 0; i < 6; i++) { const a = T * 2.2 + i * Math.PI / 3; g.fillStyle = hexA(col, 0.8); g.beginPath(); g.arc(Math.cos(a) * r * 0.5, Math.sin(a) * r * 0.85, Math.max(1.5, 0.035 * K), 0, 7); g.fill(); }
        }
        g.restore();
        if (env.night > 0.2 || ready) lights.push([x, y, ZB + 0.44, col, ready ? 1 : 0.4]);
        return [Math.min(b1[0], b2[0], lin[0]), Math.min(b1[1], b2[1], lin[1]), Math.max(b1[2], b2[2], lin[2]), Math.max(b1[3], b2[3])];
    }
    function drawSignpost(n) {
        const [x, y] = n.coords;
        const a = P(x, y, ZB), b = P(x, y, ZB + 0.6);
        g.strokeStyle = INK; g.lineWidth = Math.max(2, 0.07 * K); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
        g.strokeStyle = '#8a5a2f'; g.lineWidth = Math.max(1, 0.045 * K); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
        const w = 0.46 * K, h = 0.3 * K;
        roundRect(b[0] - w / 2, b[1] - h, w, h, 4 * cam.zoom, '#fff4d6', INK, Math.max(1.2, 1.8 * cam.zoom));
        g.fillStyle = INK; g.font = `${Math.max(9, 0.24 * K) | 0}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('?', b[0], b[1] - h / 2 + 1);
        return [b[0] - w / 2, b[1] - h, b[0] + w / 2, a[1]];
    }
    function roundRect(x, y, w, h, r, fill, stroke, lw) {
        g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
        if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = lw; g.stroke(); }
    }
    // Conveyor links from each requirement to the node (same-plot only), flowing when the source is built.
    // Belts are baked into the floor texture; only the focused plot gets studs riding along them.
    function drawLinks(p) {
        if (K < 40 || p.key !== focusedKey || DIRECTOR.mode === 'minimal') return;
        const c = P(p.x0 + 2.5, p.y0 + 2.5, TOP); if (!onScreen(c[0], c[1], 3.8 * K)) return;
        let segs = p._links;
        if (!segs) {
            segs = [];
            for (const n of p.nodes) for (const [rx, ry] of (n.reqs || [])) if (plotKeyOf(rx, ry) === p.key) segs.push([n, rx, ry]);
            p._links = segs;
        }
        g.fillStyle = '#ffd23f'; g.strokeStyle = INK; g.lineWidth = 1;
        const r = Math.max(1.5, 0.045 * K);
        g.beginPath();
        for (const [n, rx, ry] of segs) {
            if (getLevel(n.id) <= 0 || !isNodeUnlocked(n)) continue;
            const u = (T * 0.45 + (rx * 7 + ry * 3) * 0.13) % 1;
            const q = P(rx + (n.coords[0] - rx) * u, ry + (n.coords[1] - ry) * u, TOP + 0.03);
            g.moveTo(q[0] + r, q[1]); g.ellipse(q[0], q[1], r, r * 0.7, 0, 0, 7);
        }
        g.fill(); g.stroke();
    }

    // ---------- life: minifigs, builder, birds, boat, whale, clouds ----------
    const figs = [];
    const builder = { x: 0.5, y: 1.2, tx: 0.5, ty: 1.2, hop: 0, hammer: 0, face: 1, target: null, walk: 0 };
    const FIG_COLORS = ['#e8453c', '#3b82f6', '#22c55e', '#ffd23f', '#a855f7', '#ff9a2e', '#ffffff'];
    function freeCells(p) {
        if (p._free) return p._free;
        const out = [];
        for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) {
            const x = p.x0 + i + 0.5, y = p.y0 + j + 0.5;
            if (!p.nodes.some(n => Math.abs(n.coords[0] - x) < 0.5 && Math.abs(n.coords[1] - y) < 0.5)) out.push([x, y]);
        }
        if (!out.length) out.push([p.x0 + 0.3, p.y0 + 0.3], [p.x0 + 4.7, p.y0 + 4.7]);
        return (p._free = out);
    }
    function syncFigs() {
        const want = Math.min(34, builtCache.size * 2);
        const keys = [...builtCache];
        while (figs.length < want && keys.length) {
            const k = keys[figs.length % keys.length]; const p = PLOTS.get(k);
            const fc = freeCells(p); const [x, y] = fc[(Math.random() * fc.length) | 0];
            figs.push({ plot: k, x, y, tx: x, ty: y, wait: Math.random() * 3, col: FIG_COLORS[figs.length % FIG_COLORS.length], hat: Math.random() < 0.4, walk: 0, carry: Math.random() < 0.3 });
        }
    }
    function updateFigs(dt) {
        for (const f of figs) {
            const dx = f.tx - f.x, dy = f.ty - f.y, d = Math.hypot(dx, dy);
            if (d < 0.05) {
                f.wait -= dt;
                if (f.wait <= 0) { const fc = freeCells(PLOTS.get(f.plot)); const c = fc[(Math.random() * fc.length) | 0]; f.tx = c[0] + (Math.random() - 0.5) * 0.4; f.ty = c[1] + (Math.random() - 0.5) * 0.4; f.wait = 1 + Math.random() * 4; }
            } else { const s = Math.min(d, 0.7 * dt); f.x += dx / d * s; f.y += dy / d * s; f.walk += dt * 10; }
        }
        const bd = Math.hypot(builder.tx - builder.x, builder.ty - builder.y);
        if (bd > 0.05) {
            const sp = bd > 5 ? 9 : 2.4;
            const s = Math.min(bd, sp * dt); builder.x += (builder.tx - builder.x) / bd * s; builder.y += (builder.ty - builder.y) / bd * s; builder.walk += dt * 14;
            builder.hop = bd > 5 ? Math.abs(Math.sin(bd * 0.6)) * 1.2 : 0;
        } else { builder.hop = 0; if (builder.hammer > 0) builder.hammer -= dt; }
    }
    function drawFig(f, isBuilder) {
        const z = TOP + (f.hop || 0);
        const base = P(f.x, f.y, z); const s = K / 64;
        if (!onScreen(base[0], base[1], 40)) return;
        const sw = Math.sin(f.walk) * 2.2 * s;
        g.fillStyle = 'rgba(0,0,0,0.25)'; const sh = P(f.x, f.y, TOP); g.beginPath(); g.ellipse(sh[0], sh[1], 5 * s, 2.5 * s, 0, 0, 7); g.fill();
        g.lineWidth = Math.max(1, 1.2 * s); g.strokeStyle = INK;
        // legs
        g.fillStyle = isBuilder ? '#3b5bdb' : '#2b3a67';
        g.fillRect(base[0] - 3.6 * s, base[1] - 8 * s + sw * 0.3, 3.2 * s, 8 * s); g.strokeRect(base[0] - 3.6 * s, base[1] - 8 * s + sw * 0.3, 3.2 * s, 8 * s);
        g.fillRect(base[0] + 0.4 * s, base[1] - 8 * s - sw * 0.3, 3.2 * s, 8 * s); g.strokeRect(base[0] + 0.4 * s, base[1] - 8 * s - sw * 0.3, 3.2 * s, 8 * s);
        // torso
        g.fillStyle = isBuilder ? '#ff9a2e' : f.col;
        g.beginPath(); g.moveTo(base[0] - 4.6 * s, base[1] - 8 * s); g.lineTo(base[0] + 4.6 * s, base[1] - 8 * s); g.lineTo(base[0] + 3.6 * s, base[1] - 16 * s); g.lineTo(base[0] - 3.6 * s, base[1] - 16 * s); g.closePath(); g.fill(); g.stroke();
        // head
        g.fillStyle = '#ffd23f'; g.beginPath(); g.ellipse(base[0], base[1] - 20 * s, 3.8 * s, 4 * s, 0, 0, 7); g.fill(); g.stroke();
        g.fillStyle = INK; g.fillRect(base[0] - 1.8 * s, base[1] - 21 * s, 1 * s, 1.4 * s); g.fillRect(base[0] + 0.8 * s, base[1] - 21 * s, 1 * s, 1.4 * s);
        if (isBuilder || f.hat) {
            g.fillStyle = isBuilder ? '#ffd23f' : '#e8453c';
            g.beginPath(); g.ellipse(base[0], base[1] - 23.2 * s, 5.2 * s, 2 * s, 0, 0, 7); g.fill(); g.stroke();
            g.beginPath(); g.ellipse(base[0], base[1] - 24.6 * s, 3.6 * s, 2.8 * s, 0, Math.PI, 0); g.fill(); g.stroke();
        }
        if (f.carry && !isBuilder) { g.fillStyle = '#ffd23f'; g.beginPath(); g.arc(base[0] + 5 * s, base[1] - 12 * s, 2.6 * s, 0, 7); g.fill(); g.stroke(); }
        if (isBuilder && builder.hammer > 0) {
            const a = Math.sin(T * 26) * 0.9;
            g.save(); g.translate(base[0] + 4 * s, base[1] - 13 * s); g.rotate(-0.6 + a);
            g.fillStyle = '#8a5a2f'; g.fillRect(0, -1 * s, 9 * s, 2 * s); g.fillStyle = '#9aa3ad'; g.fillRect(8 * s, -3 * s, 3 * s, 6 * s); g.strokeRect(8 * s, -3 * s, 3 * s, 6 * s); g.restore();
            if (Math.random() < 0.3 * FXD.amount()) spark(builder.x + 0.2, builder.y, TOP + 0.3);
        }
    }
    function sendBuilder(x, y) { builder.tx = x + 0.45; builder.ty = y + 0.45; builder.hammer = 1.1; }

    const birds = Array.from({ length: 5 }, (_, i) => ({ a: i * 1.3, r: 6 + i * 1.7, s: 0.12 + i * 0.02, z: 3.5 + i * 0.4 }));
    const clouds = Array.from({ length: 7 }, (_, i) => ({ x: -20 + i * 11, y: -15 + ((i * 37) % 30), z: 4.6 + (i % 3) * 0.5, s: 1 + (i % 3) * 0.4 }));
    const boat = { t: 0 };
    const whale = { next: 90, t0: -99, x: 0, y: 0 };
    let worldBounds = { x0: -7.5, y0: -7.5, x1: 7.5, y1: 12.5 };
    function computeBounds() {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const k of builtCache) { const p = PLOTS.get(k); x0 = Math.min(x0, p.x0); y0 = Math.min(y0, p.y0); x1 = Math.max(x1, p.x0 + 5); y1 = Math.max(y1, p.y0 + 5); }
        if (x0 < 1e9) worldBounds = { x0, y0, x1, y1 };
    }
    function boatPos() {
        if (!builtCache.size) return null;
        const b = worldBounds; const pad = 1.4;
        const w = b.x1 - b.x0 + pad * 2, h = b.y1 - b.y0 + pad * 2, per = 2 * (w + h);
        boat.t = (boat.t + dtS * 0.8) % per;
        let d = boat.t, x, y, dir;
        if (d < w) { x = b.x0 - pad + d; y = b.y0 - pad; dir = [1, 0]; }
        else if ((d -= w) < h) { x = b.x1 + pad; y = b.y0 - pad + d; dir = [0, 1]; }
        else if ((d -= h) < w) { x = b.x1 + pad - d; y = b.y1 + pad; dir = [-1, 0]; }
        else { d -= w; x = b.x0 - pad; y = b.y1 + pad - d; dir = [0, -1]; }
        return { x, y, dir, d: depth(x, y) };
    }
    function drawBoat(bp) {
        const { x, y, dir } = bp;
        const s = P(x, y, 0); if (!onScreen(s[0], s[1], 80)) return;
        // wake
        g.strokeStyle = 'rgba(255,255,255,0.5)'; g.lineWidth = Math.max(1, 2 * cam.zoom);
        const w1 = P(x - dir[0] * 1.2 - dir[1] * 0.3, y - dir[1] * 1.2 - dir[0] * 0.3, 0), w2 = P(x - dir[0] * 1.2 + dir[1] * 0.3, y - dir[1] * 1.2 + dir[0] * 0.3, 0);
        g.beginPath(); g.moveTo(w1[0], w1[1]); g.lineTo(s[0], s[1]); g.lineTo(w2[0], w2[1]); g.stroke();
        const bob = Math.sin(T * 2) * 0.03;
        box(x, y, bob, dir[0] ? 0.42 : 0.2, dir[1] ? 0.42 : 0.2, 0.16, '#e8453c', { topCol: '#c98f55' });
        box(x, y, 0.16 + bob, 0.03, 0.03, 0.55, '#8a5a2f', { lw: 0.8 });
        const m = P(x, y, 0.45 + bob), m2 = P(x + dir[0] * 0.35, y + dir[1] * 0.35, 0.3 + bob), m3 = P(x, y, 0.72 + bob);
        poly([m3, m2, m], '#ffffff', INK, Math.max(1, 1.2 * cam.zoom));
        if (env.night > 0.3) lights.push([x, y, 0.3, '#ffd27a', 0.6]);
    }
    function drawWhale() {
        if (T > whale.next && builtCache.size > 0 && !FXD.inHero()) {
            const b = worldBounds; const side = Math.random() < 0.5;
            whale.x = side ? b.x0 - 3 : b.x1 + 3; whale.y = b.y0 + Math.random() * (b.y1 - b.y0);
            whale.t0 = T; whale.next = T + 150 + Math.random() * 150; AUDIO.whale();
        }
        const t = T - whale.t0; if (t > 7) return;
        const up = Math.sin(Math.min(1, t / 7) * Math.PI);
        const s = P(whale.x, whale.y, -0.6 + up * 0.75); if (!onScreen(s[0], s[1], 120)) return;
        const r = 0.9 * K;
        g.fillStyle = '#3d6fb3'; g.strokeStyle = INK; g.lineWidth = Math.max(1.4, 2 * cam.zoom);
        g.beginPath(); g.ellipse(s[0], s[1], r, r * 0.42, 0, Math.PI, 0); g.fill(); g.stroke();
        g.fillStyle = '#ffffff'; g.beginPath(); g.arc(s[0] + r * 0.45, s[1] - r * 0.16, r * 0.06, 0, 7); g.fill();
        if (t > 1.5 && t < 4.5 && Math.random() < 0.6 * FXD.amount()) { const sp = unproject(s[0], s[1] - r * 0.4, 0); spawn({ x: sp[0], y: sp[1], z: up * 0.6 + 0.4, vx: (Math.random() - 0.5) * 0.8, vy: (Math.random() - 0.5) * 0.8, vz: 3 + Math.random() * 2, life: 1.2, col: Math.random() < 0.3 ? '#ffd23f' : '#d9f4ff', size: 0.07, grav: 7 }); }
    }
    function drawBirds() {
        if (env.night > 0.6) return;
        g.strokeStyle = 'rgba(27,21,48,0.8)'; g.lineWidth = Math.max(1, 1.6 * cam.zoom);
        const cx = (worldBounds.x0 + worldBounds.x1) / 2, cy = (worldBounds.y0 + worldBounds.y1) / 2;
        for (const b of birds) {
            b.a += b.s * dtS;
            const s = P(cx + Math.cos(b.a) * b.r, cy + Math.sin(b.a) * b.r * 0.8, b.z);
            const f = Math.sin(T * 9 + b.r) * 4 * cam.zoom; const w = 7 * cam.zoom;
            g.beginPath(); g.moveTo(s[0] - w, s[1] - f); g.quadraticCurveTo(s[0] - w * 0.4, s[1] - 2, s[0], s[1]); g.quadraticCurveTo(s[0] + w * 0.4, s[1] - 2, s[0] + w, s[1] - f); g.stroke();
        }
    }
    function drawClouds(shadowOnly) {
        for (const c of clouds) {
            if (!shadowOnly) { c.x += env.wind * dtS; if (c.x > worldBounds.x1 + 14) c.x = worldBounds.x0 - 14; }
            if (shadowOnly) {
                if (env.night > 0.5) continue;
                const s = P(c.x + 1, c.y + 1, TOP); g.fillStyle = 'rgba(20,40,80,0.07)';
                g.beginPath(); g.ellipse(s[0], s[1], 1.3 * c.s * K, 1.3 * c.s * K * SQ, 0, 0, 7); g.fill();
            } else {
                const s = P(c.x, c.y, c.z + TOP); if (!onScreen(s[0], s[1], 300)) continue;
                const r = 0.55 * c.s * K;
                g.fillStyle = env.night > 0.5 ? 'rgba(170,180,220,0.4)' : 'rgba(255,255,255,0.7)';
                g.strokeStyle = 'rgba(27,21,48,0.25)'; g.lineWidth = 2;
                g.beginPath();
                g.arc(s[0] - r, s[1], r * 0.7, 0, 7); g.arc(s[0], s[1] - r * 0.4, r, 0, 7); g.arc(s[0] + r * 1.1, s[1], r * 0.75, 0, 7);
                g.fill();
            }
        }
    }

    // ---------- plot ambience ----------
    // Each theme breathes a little: embers over lava and the Red canyon, sparks at the battery farm,
    // petals on meadows, bubbles by the water plots, twinkles on gems. Budgeted by the director.
    const AMB = {
        energy: ['spark', '#fff27a'], forge: ['ember', '#ff8a2a'], canyon: ['ember', '#ff5a3a'], deep: ['ember', '#ff6a2a'],
        portal: ['mote', '#ff6fb0'], cosmos: ['mote', '#c9b8ff'], night: ['twinkle', '#ffffff'], gem: ['twinkle', '#7fe8ff'],
        gold: ['twinkle', '#fff1a0'], mine: ['dust', '#d8d0c0'], meadow: ['petal', '#ffffff'], bay: ['petal', '#ffd1e8'],
        sun: ['petal', '#ffe45c'], grove: ['petal', '#9ad86a'], beach: ['bubble', '#dff6ff'], lagoon: ['bubble', '#e9e2ff'],
        lab: ['bubble', '#bfe0ff'], studio: ['petal', '#ff9ad0'], cookie: ['dust', '#e2b98a'], market: ['twinkle', '#b9f5b9'],
    };
    function ambientTick(dt) {
        const amt = FXD.amount(); if (!amt || K < 22) return;
        for (const k of builtCache) {
            const p = PLOTS.get(k); const a = AMB[p.theme]; if (!a) continue;
            const c = P(p.x0 + 2.5, p.y0 + 2.5, TOP); if (!onScreen(c[0], c[1], 2.5 * K)) continue;
            if (Math.random() > dt * 3 * amt) continue;
            const x = p.x0 + 0.3 + Math.random() * 4.4, y = p.y0 + 0.3 + Math.random() * 4.4;
            const [kind, col] = a;
            if (kind === 'ember') spawn({ x, y, z: TOP + 0.1, vx: env.wind * 0.3, vy: 0, vz: 0.5 + Math.random() * 0.6, life: 2.4, col, size: 0.03, grav: -0.1, add: true, fade: true, stud: false });
            else if (kind === 'spark') spawn({ x, y, z: TOP + 0.3 + Math.random() * 0.5, vx: (Math.random() - 0.5) * 3, vy: (Math.random() - 0.5) * 3, vz: 1.5, life: 0.35, col, size: 0.025, grav: 6, add: true, stud: false });
            else if (kind === 'mote') spawn({ x, y, z: TOP + 0.2, vx: Math.cos(T + x) * 0.3, vy: Math.sin(T + y) * 0.3, vz: 0.35, life: 3, col, size: 0.035, grav: 0, add: true, fade: true, stud: false });
            else if (kind === 'twinkle') spawn({ x, y, z: TOP + 0.05 + Math.random() * 0.6, vx: 0, vy: 0, vz: 0, life: 0.7, col, size: 0.1, grav: 0, twinkle: true, stud: false });
            else if (kind === 'dust') spawn({ x, y, z: TOP + 0.05, vx: env.wind * 0.4, vy: 0, vz: 0.15, life: 2, col, size: 0.05, grav: 0, fade: true, grow: 1.2, stud: false });
            else if (kind === 'petal') spawn({ x, y, z: TOP + 1.2 + Math.random(), vx: env.wind * 0.8 + 0.2, vy: 0.15, vz: -0.25, life: 4, col, size: 0.035, grav: 0, petal: true, stud: false });
            else if (kind === 'bubble') { const e = Math.random() < 0.5; spawn({ x: e ? p.x0 + 0.05 : x, y: e ? y : p.y0 + 4.95, z: 0.02, vx: 0, vy: 0, vz: 0.12, life: 1.6, col, size: 0.04, grav: 0, fade: true, ringlet: true, stud: false }); }
        }
    }
    // Lighthouse on its own little rock off Stud Square; its beam sweeps the sea at night.
    function drawLighthouse() {
        const x = -3.55, y = -3.55;
        const s0 = P(x, y, 0); if (!onScreen(s0[0], s0[1], 4 * K)) return;
        g.globalAlpha = 0.35; g.fillStyle = '#0d4f6e'; g.beginPath(); g.ellipse(s0[0], s0[1] + 0.1 * K, 0.65 * K, 0.65 * K * SQ, 0, 0, 7); g.fill(); g.globalAlpha = 1;
        box(x, y, -0.1, 0.42, 0.42, 0.3, '#8d8f93', { topCol: '#a3a5a9' });
        for (let i = 0; i < 4; i++) box(x, y, 0.2 + i * 0.28, 0.2 - i * 0.02, 0.2 - i * 0.02, 0.28, i % 2 ? '#e8453c' : '#ffffff');
        box(x, y, 1.32, 0.16, 0.16, 0.22, '#ffd23f', { alpha: 0.85 });
        box(x, y, 1.54, 0.2, 0.2, 0.08, '#e8453c');
        const lamp = P(x, y, 1.43);
        if (env.night > 0.15) {
            lights.push([x, y, 1.43, '#fff1a8', 1.4]);
            const a = T * 0.9; const L = 9 * K, spread = 0.12;
            g.save(); g.globalCompositeOperation = 'lighter';
            const gr = g.createLinearGradient(lamp[0], lamp[1], lamp[0] + Math.cos(a) * L, lamp[1] + Math.sin(a) * L * SQ);
            gr.addColorStop(0, `rgba(255,245,190,${0.5 * env.night})`); gr.addColorStop(1, 'rgba(255,245,190,0)');
            g.fillStyle = gr; g.beginPath(); g.moveTo(lamp[0], lamp[1]);
            g.lineTo(lamp[0] + Math.cos(a - spread) * L, lamp[1] + Math.sin(a - spread) * L * SQ);
            g.lineTo(lamp[0] + Math.cos(a + spread) * L, lamp[1] + Math.sin(a + spread) * L * SQ); g.closePath(); g.fill();
            g.restore();
        }
        const f = P(x, y, 0);
        g.setLineDash([5 * cam.zoom, 7 * cam.zoom]); g.lineDashOffset = -T * 12 * cam.zoom; g.strokeStyle = 'rgba(255,255,255,0.7)'; g.lineWidth = Math.max(1, 2 * cam.zoom);
        g.beginPath(); g.ellipse(f[0], f[1], 0.62 * K, 0.62 * K * SQ, 0, 0, 7); g.stroke(); g.setLineDash([]);
        hits.push({ type: 'lighthouse', x0: lamp[0] - 20, y0: lamp[1] - 30, x1: lamp[0] + 20, y1: s0[1] });
    }
    // Brick Grove Falls pours off the side that faces the camera.
    function drawWaterfall(p) {
        let best = null;
        const cs = [[p.x0 + INSET, p.y0 + INSET], [p.x0 + 5 - INSET, p.y0 + INSET], [p.x0 + 5 - INSET, p.y0 + 5 - INSET], [p.x0 + INSET, p.y0 + 5 - INSET]];
        for (const [a, b, nx, ny] of EDGES) { const nv = nx * sinA + ny * cosA; if (!best || nv > best.nv) best = { a, b, nv, nx, ny }; }
        const A = cs[best.a], B = cs[best.b];
        const t0 = 0.35, t1 = 0.65;
        const p1 = [A[0] + (B[0] - A[0]) * t0, A[1] + (B[1] - A[1]) * t0], p2 = [A[0] + (B[0] - A[0]) * t1, A[1] + (B[1] - A[1]) * t1];
        const q = [P(p1[0], p1[1], TOP), P(p2[0], p2[1], TOP), P(p2[0], p2[1], -0.05), P(p1[0], p1[1], -0.05)];
        poly(q, 'rgba(90,190,255,0.92)', INK, Math.max(1, 1.6 * cam.zoom));
        g.save(); g.beginPath(); g.moveTo(q[0][0], q[0][1]); for (let i = 1; i < 4; i++) g.lineTo(q[i][0], q[i][1]); g.closePath(); g.clip();
        g.strokeStyle = 'rgba(255,255,255,0.75)'; g.lineWidth = Math.max(1, 2 * cam.zoom);
        const h = (q[3][1] - q[0][1]); const off = (T * 60 * cam.zoom) % 18;
        for (let i = 0; i < 6; i++) { const u = (i + 0.5) / 6; const x = q[0][0] + (q[1][0] - q[0][0]) * u, y0 = q[0][1] + (q[1][1] - q[0][1]) * u; g.setLineDash([8 * cam.zoom, 10 * cam.zoom]); g.lineDashOffset = -off - i * 5; g.beginPath(); g.moveTo(x, y0); g.lineTo(x, y0 + h + 4); g.stroke(); }
        g.restore(); g.setLineDash([]);
        const m = P((p1[0] + p2[0]) / 2 + best.nx * 0.25, (p1[1] + p2[1]) / 2 + best.ny * 0.25, 0);
        g.fillStyle = 'rgba(255,255,255,0.8)'; for (let i = 0; i < 5; i++) { const a = T * 3 + i * 1.3; g.beginPath(); g.arc(m[0] + Math.cos(a) * 0.35 * K, m[1] + Math.sin(a * 1.3) * 0.08 * K, Math.max(2, 0.07 * K * (1 + Math.sin(a * 2) * 0.3)), 0, 7); g.fill(); }
    }

    // ---------- particles ----------
    const parts = []; const MAXP = 700;
    function spawn(p) { if (parts.length >= MAXP) return; p.t = 0; parts.push(p); }
    function burst(x, y, z, col, n, speed = 2.2, opts = {}) {
        n = Math.round(n * FXD.amount()); for (let i = 0; i < n; i++) {
            const a = Math.random() * Math.PI * 2, s = speed * (0.4 + Math.random() * 0.8);
            spawn({ x, y, z, vx: Math.cos(a) * s * 0.5, vy: Math.sin(a) * s * 0.5, vz: 2 + Math.random() * 2.5, life: 0.9 + Math.random() * 0.5, col, size: opts.size || 0.075, grav: 9, stud: opts.stud !== false });
        }
    }
    function puff(x, y, z, col) { spawn({ x, y, z, vx: env.wind * 0.3, vy: 0, vz: 0.6, life: 1.6, col, size: 0.05, grav: 0, fade: true, stud: false, grow: 1.5 }); }
    function spark(x, y, z) { spawn({ x, y, z, vx: (Math.random() - 0.5) * 2, vy: (Math.random() - 0.5) * 2, vz: 1 + Math.random() * 2, life: 0.35, col: '#fff3a0', size: 0.03, grav: 6, add: true, stud: false }); }
    function ring(x, y, z, col, r1 = 2, life = 0.7) { spawn({ ring: true, x, y, z, r1, life, col, vx: 0, vy: 0, vz: 0, grav: 0 }); }
    function floatText(x, y, z, text, col, big = false) { spawn({ text, x, y, z, vx: 0, vy: 0, vz: 0.9, grav: 0, life: big ? 1.6 : 1.1, col, big }); }
    function updateParts(dt) {
        for (let i = parts.length - 1; i >= 0; i--) {
            const p = parts[i]; p.t += dt;
            if (p.t >= p.life) { parts[i] = parts[parts.length - 1]; parts.pop(); continue; }
            p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt; p.vz -= (p.grav || 0) * dt;
            if (p.bounce && p.z < TOP && p.vz < 0) { p.z = TOP; p.vz *= -0.35; p.vx *= 0.6; p.vy *= 0.6; }
        }
    }
    function drawParts() {
        for (const p of parts) {
            const s = P(p.x, p.y, p.z); if (!onScreen(s[0], s[1], 60)) continue;
            const k = p.t / p.life;
            if (p.ring) {
                g.strokeStyle = hexA(p.col, 1 - k); g.lineWidth = Math.max(1.5, 4 * cam.zoom * (1 - k));
                g.beginPath(); g.ellipse(s[0], s[1], p.r1 * k * K, p.r1 * k * K * SQ, 0, 0, 7); g.stroke(); continue;
            }
            if (p.text) {
                const a = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3; g.globalAlpha = a;
                const fs = Math.round((p.big ? 26 : 17) * Math.min(1.3, Math.max(0.8, cam.zoom)));
                g.font = `${fs}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
                g.lineWidth = fs * 0.22; g.strokeStyle = INK; g.lineJoin = 'round'; g.strokeText(p.text, s[0], s[1]); g.fillStyle = p.col; g.fillText(p.text, s[0], s[1]); g.globalAlpha = 1; continue;
            }
            const r = Math.max(1.2, p.size * K * (p.grow ? 1 + k * p.grow : 1));
            g.globalAlpha = p.fade ? (1 - k) * 0.7 : (k > 0.75 ? (1 - k) * 4 : 1);
            if (p.add) g.globalCompositeOperation = 'lighter';
            if (p.twinkle) { g.globalAlpha = 1; const a = Math.sin(k * Math.PI); g.globalCompositeOperation = 'source-over'; sparkle(s[0], s[1], r * 1.4 * a); g.globalAlpha = 1; continue; }
            if (p.petal) { g.save(); g.translate(s[0] + Math.sin(T * 3 + p.x * 9) * 4, s[1]); g.rotate(T * 2 + p.y); g.fillStyle = p.col; g.beginPath(); g.ellipse(0, 0, r * 1.4, r * 0.7, 0, 0, 7); g.fill(); g.restore(); g.globalAlpha = 1; continue; }
            if (p.ringlet) { g.strokeStyle = p.col; g.lineWidth = 1.2; g.beginPath(); g.ellipse(s[0], s[1], r * (1 + k * 2), r * (1 + k * 2) * SQ, 0, 0, 7); g.stroke(); g.globalAlpha = 1; continue; }
            if (p.stud) {
                g.fillStyle = tone(p.col, -0.3); g.beginPath(); g.ellipse(s[0], s[1] + r * 0.35, r, r * 0.7, 0, 0, 7); g.fill();
                g.fillStyle = p.col; g.beginPath(); g.ellipse(s[0], s[1], r, r * 0.7, 0, 0, 7); g.fill();
                g.strokeStyle = INK; g.lineWidth = Math.max(0.8, r * 0.25); g.stroke();
            } else if (p.brick) {
                g.fillStyle = p.col; g.fillRect(s[0] - r, s[1] - r * 0.7, r * 2, r * 1.4); g.strokeStyle = INK; g.lineWidth = Math.max(0.8, r * 0.2); g.strokeRect(s[0] - r, s[1] - r * 0.7, r * 2, r * 1.4);
            } else { g.fillStyle = p.col; g.beginPath(); g.arc(s[0], s[1], r, 0, 7); g.fill(); }
            g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
        }
    }
    // screen-space coins that fly into the HUD counter (or out of it)
    const flyers = [];
    function fly(fromX, fromY, toX, toY, col, n, delay = 0) {
        n = Math.round(n * FXD.amount());
        for (let i = 0; i < n; i++) flyers.push({ fx: fromX + (Math.random() - 0.5) * 30, fy: fromY + (Math.random() - 0.5) * 30, tx: toX, ty: toY, t: -delay - i * 0.04, life: 0.7, col });
    }
    function drawFlyers(dt) {
        for (let i = flyers.length - 1; i >= 0; i--) {
            const f = flyers[i]; f.t += dt; if (f.t > f.life) { flyers.splice(i, 1); continue; }
            if (f.t < 0) continue; const k = f.t / f.life, e = k * k * (3 - 2 * k);
            const x = f.fx + (f.tx - f.fx) * e, y = f.fy + (f.ty - f.fy) * e - Math.sin(k * Math.PI) * 80;
            const r = 7 * (1 - k * 0.4);
            g.fillStyle = f.col; g.strokeStyle = INK; g.lineWidth = 2; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); g.stroke();
        }
    }

    // ---------- sky, sea, night ----------
    const SKY = [[0, '#0b1033', '#1c2a5e'], [4.5, '#141a4d', '#2a3570'], [6, '#4b4a9e', '#ff9e7a'], [7.5, '#6ec6ff', '#d8f1ff'], [16.5, '#58b8ff', '#cdeeff'], [18.5, '#5b4a9e', '#ffb36b'], [20, '#1d2360', '#3b3a7a'], [24, '#0b1033', '#1c2a5e']];
    function lerpHex(a, b, t) { const pa = parseInt(a.slice(1), 16), pb = parseInt(b.slice(1), 16); const r = ((pa >> 16) & 255) + ((((pb >> 16) & 255) - ((pa >> 16) & 255)) * t), gg = ((pa >> 8) & 255) + ((((pb >> 8) & 255) - ((pa >> 8) & 255)) * t), bb = (pa & 255) + (((pb & 255) - (pa & 255)) * t); return `rgb(${r | 0},${gg | 0},${bb | 0})`; }
    function skyAt(h) { for (let i = 0; i < SKY.length - 1; i++) { if (h >= SKY[i][0] && h <= SKY[i + 1][0]) { const t = (h - SKY[i][0]) / (SKY[i + 1][0] - SKY[i][0]); return [lerpHex(SKY[i][1], SKY[i + 1][1], t), lerpHex(SKY[i][2], SKY[i + 1][2], t)]; } } return [SKY[0][1], SKY[0][2]]; }
    function nightAt(h) { if (h >= 7.5 && h <= 16.5) return 0; if (h >= 20.5 || h <= 4.5) return 1; if (h < 7.5) return 1 - (h - 4.5) / 3; return (h - 16.5) / 4; }
    const stars = Array.from({ length: 90 }, () => [Math.random(), Math.random() * 0.6, Math.random() * 1.5 + 0.5, Math.random() * 6]);
    // The whole view is sea. It mirrors the sky: turquoise by day, warm at dawn and dusk,
    // deep navy with star glints at night.
    function drawSky() {
        const [top, bot] = skyAt(env.tod);
        const dayTop = lerpHex('#2aa9c9', '#0a2a48', env.night), dayBot = lerpHex('#4fd0e0', '#123d63', env.night);
        const warm = Math.max(0, 1 - Math.abs(env.tod - 6.2) / 1.6) + Math.max(0, 1 - Math.abs(env.tod - 18.6) / 1.6);
        const gr = g.createLinearGradient(0, 0, 0, H);
        gr.addColorStop(0, warm > 0 ? mix(dayTop, top, warm * 0.5) : dayTop);
        gr.addColorStop(1, warm > 0 ? mix(dayBot, bot, warm * 0.45) : dayBot);
        g.fillStyle = gr; g.fillRect(0, 0, W, H);
        if (env.night > 0.05) {
            for (const s of stars) { const a = env.night * (0.35 + 0.35 * Math.sin(T * 1.5 + s[3])); g.fillStyle = `rgba(230,240,255,${a})`; g.fillRect(s[0] * W, s[1] / 0.6 * H, s[2], s[2] * 0.6); }
        }
        if (env.rainbow > 0) {
            g.save(); g.globalAlpha = Math.min(1, env.rainbow) * 0.4; g.lineWidth = 12;
            ['#ff4d4d', '#ff9a2e', '#ffd23f', '#39d98a', '#4aa8ff', '#a855f7'].forEach((c, i) => { g.strokeStyle = c; g.beginPath(); g.arc(W * 0.62, H * 0.9, H * 0.75 - i * 12, Math.PI * 1.08, Math.PI * 1.92); g.stroke(); });
            g.restore();
        }
    }
    function mix(a, b, t) { const pa = a.match(/\d+/g).map(Number), pb = b.startsWith('#') ? [parseInt(b.slice(1, 3), 16), parseInt(b.slice(3, 5), 16), parseInt(b.slice(5, 7), 16)] : b.match(/\d+/g).map(Number); return `rgb(${pa.map((v, i) => (v + (pb[i] - v) * t) | 0).join(',')})`; }
    function drawSea() {
        // moving sparkle strokes on the water, anchored to the world so they turn with the camera
        const step = 2.5, t = T * 0.35;
        const c0 = unproject(0, 0, 0), c1 = unproject(W, 0, 0), c2 = unproject(0, H, 0), c3 = unproject(W, H, 0);
        const xs = [c0[0], c1[0], c2[0], c3[0]], ys = [c0[1], c1[1], c2[1], c3[1]];
        const x0 = Math.floor(Math.min(...xs) / step) * step, x1 = Math.max(...xs), y0 = Math.floor(Math.min(...ys) / step) * step, y1 = Math.max(...ys);
        if ((x1 - x0) * (y1 - y0) / (step * step) > 1600) return;
        g.strokeStyle = env.night > 0.5 ? 'rgba(160,190,255,0.25)' : 'rgba(255,255,255,0.5)'; g.lineWidth = Math.max(1, 1.6 * cam.zoom); g.lineCap = 'round';
        g.beginPath();
        for (let x = x0; x <= x1; x += step) for (let y = y0; y <= y1; y += step) {
            const ph = Math.sin(x * 12.9898 + y * 78.233) * 43758.5; const r = ph - Math.floor(ph);
            const a = Math.sin(t * 3 + r * 6.28);
            if (a < 0.55) continue;
            const s = P(x + r * 2, y + ((r * 7) % 1) * 2 + Math.sin(t + r) * 0.2, 0);
            const L = 0.28 * K * (a - 0.5);
            g.moveTo(s[0] - L, s[1]); g.lineTo(s[0] + L, s[1]);
        }
        g.stroke(); g.lineCap = 'butt';
    }
    const _glow = new Map();
    function glowSprite(col) {
        let c = _glow.get(col); if (c) return c;
        c = document.createElement('canvas'); c.width = c.height = 96; const t = c.getContext('2d');
        const gr = t.createRadialGradient(48, 48, 0, 48, 48, 48); gr.addColorStop(0, hexA(col, 0.95)); gr.addColorStop(0.35, hexA(col, 0.35)); gr.addColorStop(1, hexA(col, 0));
        t.fillStyle = gr; t.fillRect(0, 0, 96, 96); _glow.set(col, c); return c;
    }
    function drawNight() {
        const n = env.night + env.rain * 0.25;
        if (n > 0.01) { g.fillStyle = `rgba(12,18,60,${0.42 * n})`; g.fillRect(0, 0, W, H); }
        if (env.night < 0.15 && lights.every(l => l[4] < 1)) { lights.length = 0; return; }
        g.save(); g.globalCompositeOperation = 'lighter';
        let nl = 0;
        for (const [x, y, z, col, str] of lights) {
            if (nl > 90) break;
            const s = P(x, y, z); if (!onScreen(s[0], s[1], 80)) continue;
            nl++;
            const r = (0.55 + 0.25 * str) * K; const a = Math.min(1, Math.max(env.night, str >= 1 ? 0.5 : 0) * 0.6 * str);
            g.globalAlpha = a; g.drawImage(glowSprite(col), s[0] - r, s[1] - r * 0.8, r * 2, r * 1.6);
        }
        g.globalAlpha = 1;
        // fireflies over built plots
        if (env.night > 0.4 && DIRECTOR.mode !== 'minimal') {
            let i = 0;
            for (const k of builtCache) {
                const p = PLOTS.get(k); if (i++ > 14) break;
                for (let j = 0; j < 3; j++) {
                    const ph = hashKey(k + j) % 1000 / 159;
                    const x = p.x0 + 2.5 + Math.sin(T * 0.3 + ph) * 2.2, y = p.y0 + 2.5 + Math.cos(T * 0.23 + ph * 2) * 2.2;
                    const s = P(x, y, TOP + 0.6 + Math.sin(T + ph) * 0.3); const a = (Math.sin(T * 3 + ph * 5) + 1) / 2 * env.night;
                    g.fillStyle = `rgba(210,255,120,${a})`; g.beginPath(); g.arc(s[0], s[1], 2.4 * Math.max(0.7, cam.zoom), 0, 7); g.fill();
                }
            }
        }
        g.restore();
        lights.length = 0;
    }
    const drops = [];
    function drawRain(dt) {
        if (env.rain <= 0.01) return;
        const want = Math.floor(160 * env.rain * Math.max(0.3, FXD.amount()));
        while (drops.length < want) drops.push({ x: Math.random() * W, y: Math.random() * H, v: 700 + Math.random() * 300 });
        if (drops.length > want) drops.length = want;
        g.strokeStyle = 'rgba(200,220,255,0.55)'; g.lineWidth = 1.2; g.beginPath();
        for (const d of drops) { d.y += d.v * dt; d.x -= d.v * dt * 0.15; if (d.y > H) { d.y = -10; d.x = Math.random() * (W + 100); } g.moveTo(d.x, d.y); g.lineTo(d.x + 3, d.y - 14); }
        g.stroke();
    }

    // ---------- plot signs (the per plot total/s header) ----------
    let signInfo = new Map();
    function drawSigns() {
        const zs = Math.min(1.15, Math.max(0.72, cam.zoom));
        const items = [];
        for (const p of PLOTS.values()) {
            const built = builtCache.has(p.key);
            if (!built && !plotVisibleGhost(p)) continue;
            // far edge midpoint (smallest depth), lifted
            let best = null;
            for (const [ex, ey] of [[p.x0 + 2.5, p.y0 + 0.4], [p.x0 + 4.6, p.y0 + 2.5], [p.x0 + 2.5, p.y0 + 4.6], [p.x0 + 0.4, p.y0 + 2.5]]) { const d = depth(ex, ey); if (!best || d < best[2]) best = [ex, ey, d]; }
            const s = P(best[0], best[1], TOP + (built ? 1.5 : 0.9));
            if (!onScreen(s[0], s[1], 200)) continue;
            items.push({ p, s, built, d: best[2] });
        }
        // Keep the view readable: when signs collide, the focused plot wins, then built plots,
        // then whichever sits nearer the middle of the screen.
        const focusKey = focusedKey;
        const scored = items.map(it => ({ it, pr: (it.p.key === focusKey ? 0 : it.built ? 1 : 2) * 1e6 + Math.hypot(it.s[0] - W / 2, it.s[1] - H / 2) }));
        scored.sort((a, b) => a.pr - b.pr);
        const kept = [], boxes = [];
        const bw = 190 * zs, bh = 58 * zs;
        for (const { it } of scored) {
            const r = [it.s[0] - bw / 2, it.s[1] - bh, it.s[0] + bw / 2, it.s[1]];
            if (boxes.some(b => r[0] < b[2] - 12 && r[2] > b[0] + 12 && r[1] < b[3] - 6 && r[3] > b[1] + 6)) continue;
            boxes.push(r); kept.push(it);
        }
        kept.sort((a, b) => a.d - b.d);
        for (const it of kept) drawSign(it, zs);
    }
    let focusedKey = null;
    const signCache = new Map();
    function drawSign(it, zs) {
        const { p, s, built } = it; const info = signInfo.get(p.key) || {};
        const key = [p.key, built ? 1 : 0, info.rateText, info.lockText, info.frac !== undefined ? info.frac.toFixed(2) : '', info.ready, zs.toFixed(2), SHOW_UL_NAMES ? 1 : 0].join('|');
        let e = signCache.get(p.key);
        if (!e || e.key !== key) {
            // measure and bake once per content change
            const saved = g; const probe = document.createElement('canvas'); const W0 = Math.ceil(420 * zs), H0 = Math.ceil(130 * zs);
            probe.width = W0 * DPR; probe.height = H0 * DPR; g = probe.getContext('2d'); g.setTransform(DPR, 0, 0, DPR, 0, 0);
            const ax = W0 / 2, ay = H0 - 30 * zs;
            const r = drawSignRaw({ p, s: [ax, ay], built }, zs, info);
            g = saved;
            e = { key, c: probe, ax, ay, W0, H0, r: [r[0] - ax, r[1] - ay, r[2] - ax, r[3] - ay] };
            signCache.set(p.key, e);
        }
        const faded = !built ? 0.9 : 1; if (faded < 1) g.globalAlpha = faded;
        g.drawImage(e.c, s[0] - e.ax, s[1] - e.ay, e.W0, e.H0); g.globalAlpha = 1;
        hits.push({ type: 'plot', key: p.key, x0: s[0] + e.r[0], y0: s[1] + e.r[1], x1: s[0] + e.r[2], y1: s[1] + e.r[3] });
    }
    function drawSignRaw(it, zs, info) {
        const { p, s, built } = it;
        const pad = 10 * zs, fs1 = Math.round(17 * zs), fs2 = Math.round(15 * zs);
        const title = p.name.toUpperCase();
        let line2, line2col = '#ffffff';
        if (p.soon) line2 = 'COMING SOON';
        else if (!built) line2 = info.lockText || 'LOCKED';
        else line2 = info.rateText || '';
        g.font = `${fs1}px "Luckiest Guy", sans-serif`; const w1 = g.measureText(title).width;
        g.font = `600 ${fs2}px "Fredoka", sans-serif`; const w2 = g.measureText(line2).width;
        const w = Math.max(w1, w2) + pad * 2 + (built ? 0 : 20 * zs), h = built ? (fs1 + fs2 + pad * 2.2 + 8 * zs) : (fs1 + fs2 + pad * 2);
        const x = s[0] - w / 2, y = s[1] - h;
        // pole
        if (built) { g.strokeStyle = INK; g.lineWidth = 3 * zs; g.beginPath(); g.moveTo(s[0], s[1]); g.lineTo(s[0], s[1] + 26 * zs); g.stroke(); }
        // shadow then body
        roundRect(x + 3 * zs, y + 4 * zs, w, h, 9 * zs, 'rgba(27,21,48,0.35)');
        roundRect(x, y, w, h, 9 * zs, built ? '#fffaf0' : 'rgba(225,240,255,0.95)', INK, 3 * zs);
        // color tab
        g.save(); g.beginPath(); g.rect(x, y, w, fs1 + pad * 0.9); g.clip();
        roundRect(x, y, w, h, 9 * zs, p.color); g.restore();
        g.strokeStyle = INK; g.lineWidth = 2 * zs; g.beginPath(); g.moveTo(x, y + fs1 + pad * 0.9); g.lineTo(x + w, y + fs1 + pad * 0.9); g.stroke();
        roundRect(x, y, w, h, 9 * zs, null, INK, 3 * zs);
        g.textAlign = 'center'; g.textBaseline = 'middle';
        g.font = `${fs1}px "Luckiest Guy", sans-serif`; g.lineJoin = 'round';
        g.lineWidth = 4 * zs; g.strokeStyle = INK; g.strokeText(title, s[0], y + (fs1 + pad * 0.9) / 2 + 1); g.fillStyle = '#ffffff'; g.fillText(title, s[0], y + (fs1 + pad * 0.9) / 2 + 1);
        g.font = `700 ${fs2}px "Fredoka", sans-serif`;
        g.fillStyle = built ? INK : '#2a4a78';
        const ly = y + fs1 + pad * 0.9 + fs2 / 2 + pad * 0.55;
        if (!built && !p.soon) { drawLock(x + pad + 6 * zs, ly, 7 * zs); g.textAlign = 'left'; g.fillText(line2, x + pad + 18 * zs, ly); g.textAlign = 'center'; }
        else g.fillText(line2, s[0], ly);
        void line2col;
        if (built && info.frac !== undefined) {
            const bx = x + pad, bw = w - pad * 2, by = ly + fs2 / 2 + 5 * zs, bh = 7 * zs;
            roundRect(bx, by, bw, bh, bh / 2, '#e3dccb', INK, 1.5 * zs);
            if (info.frac > 0) roundRect(bx, by, Math.max(bh, bw * info.frac), bh, bh / 2, info.frac >= 1 ? '#ffd23f' : '#39d98a', INK, 1.5 * zs);
            if (info.ready) { const bxx = x + w - 6 * zs, byy = y + 4 * zs; g.fillStyle = '#ff4d4d'; g.beginPath(); g.arc(bxx, byy, 9 * zs, 0, 7); g.fill(); g.strokeStyle = INK; g.lineWidth = 2 * zs; g.stroke(); g.fillStyle = '#fff'; g.font = `${Math.round(11 * zs)}px "Luckiest Guy", sans-serif`; g.fillText(info.ready > 9 ? '9+' : String(info.ready), bxx, byy + 1); }
        }
        if (p.key === '7,2') {
            const tx = x - 8 * zs, ty = y - 12 * zs, tw = 96 * zs, th2 = 20 * zs;
            g.save(); g.translate(tx, ty); g.rotate(-0.12);
            roundRect(0, 0, tw, th2, 5 * zs, '#ff4d4d', INK, 2.5 * zs);
            g.fillStyle = '#fff'; g.font = `${Math.round(12 * zs)}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('NEW UPDATE', tw / 2, th2 / 2 + 1);
            g.restore();
        }
        return [x, y, x + w, y + h + 20];
    }
    function drawLock(x, y, r) {
        g.strokeStyle = '#2a4a78'; g.lineWidth = r * 0.35; g.beginPath(); g.arc(x, y - r * 0.4, r * 0.55, Math.PI, 0); g.stroke();
        g.fillStyle = '#2a4a78'; g.fillRect(x - r * 0.8, y - r * 0.4, r * 1.6, r * 1.2);
    }

    // ---------- frame ----------
    // If a device cannot hold the frame rate, drop the canvas resolution a step (never the math).
    const perf = { ema: 16, slowFor: 0, cap: 2 };
    function adapt(dt) {
        perf.ema += (dt * 1000 - perf.ema) * 0.05;
        if (perf.ema > 30 && perf.cap > 1) { perf.slowFor += dt; if (perf.slowFor > 3) { perf.cap = Math.max(1, perf.cap - 0.5); perf.slowFor = 0; perf.ema = 16; resize(); } }
        else perf.slowFor = 0;
    }
    function resize() {
        DPR = Math.min(window.devicePixelRatio || 1, W * H > 1.2e6 ? 1.5 : 2, perf.cap);
        W = cv.clientWidth; H = cv.clientHeight;
        cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
    }
    function draw(dt, state) {
        T += dt; dtS = dt; adapt(dt);
        // camera easing
        cam.angle += (cam.tAngle - cam.angle) * Math.min(1, dt * 8);
        cam.zoom += (cam.tZoom - cam.zoom) * Math.min(1, dt * 10);
        if (cam.tx !== null) { cam.x += (cam.tx - cam.x) * Math.min(1, dt * 4); cam.y += (cam.ty - cam.y) * Math.min(1, dt * 4); if (Math.hypot(cam.tx - cam.x, cam.ty - cam.y) < 0.01) cam.tx = cam.ty = null; }
        cam.kick *= Math.pow(0.02, dt);
        cam.nudgeX = (Math.random() - 0.5) * 14 * cam.kick; cam.nudgeY = (Math.random() - 0.5) * 10 * cam.kick;
        // environment
        env.tod = (env.tod + dt * 24 / env.dayLen) % 24; env.night = nightAt(env.tod);
        if (T > env.nextRain && env.rain === 0 && env.rainUntil === 0) { env.rainUntil = T + 45 + Math.random() * 30; }
        if (env.rainUntil) { env.rain = Math.min(1, env.rain + dt * 0.2); if (T > env.rainUntil) { env.rainUntil = 0; env.nextRain = T + 300 + Math.random() * 300; env.rainbowPending = env.night < 0.3; } }
        else if (env.rain > 0) { env.rain = Math.max(0, env.rain - dt * 0.15); if (env.rain === 0 && env.rainbowPending) { env.rainbow = 40; env.rainbowPending = false; } }
        if (env.rainbow > 0) env.rainbow = Math.max(0, env.rainbow - dt);
        AUDIO.setNight(env.night); AUDIO.setRain(env.rain);

        setupFrame(); texBudget = 1;
        g.setTransform(DPR, 0, 0, DPR, 0, 0);
        hits = [];
        const prof = dbg.on ? {} : null; let pt = performance.now();
        const mark = (k) => { if (!prof) return; const n = performance.now(); prof[k] = (prof[k] || 0) + n - pt; pt = n; };
        drawSky(); mark('sky');
        drawSea(); mark('sea');
        // pass A: plates
        const plist = [...PLOTS.values()].filter(p => builtCache.has(p.key) || plotVisibleGhost(p));
        plist.sort((a, b) => depth(a.x0 + 2.5, a.y0 + 2.5) - depth(b.x0 + 2.5, b.y0 + 2.5));
        const bp = boatPos();
        let boatDone = false, whaleDone = false;
        const wd = depth(whale.x, whale.y);
        for (const p of plist) {
            const d = depth(p.x0 + 2.5, p.y0 + 2.5);
            if (!whaleDone && wd < d - 2.5) { drawWhale(); whaleDone = true; }
            if (!boatDone && bp && bp.d < d - 2.5) { drawBoat(bp); boatDone = true; }
            drawPlate(p, builtCache.has(p.key));
            if (p.key === '2,2' && builtCache.has(p.key) && !plotAnim.has(p.key)) drawWaterfall(p);
        }
        if (!whaleDone) drawWhale();
        if (!boatDone && bp) drawBoat(bp);
        drawLighthouse(); mark('plates');
        drawBridges();
        for (const p of plist) if (builtCache.has(p.key) && !plotAnim.has(p.key)) drawLinks(p);
        drawClouds(true); mark('links');
        // pass B: everything standing up, sorted by depth
        const items = [];
        const margin = 3 * K;
        for (const p of plist) {
            if (plotAnim.has(p.key)) continue;
            const built = builtCache.has(p.key);
            const c = P(p.x0 + 2.5, p.y0 + 2.5, 0); if (!onScreen(c[0], c[1], 3.6 * K + margin)) continue;
            for (const n of p.nodes) {
                if (!isNodeUnlocked(n)) continue;
                items.push({ n, ghost: !built, d: depth(n.coords[0], n.coords[1]) });
            }
            if (built) for (const cx of [0.35, 4.65]) { const ly = p.y0 + 4.65, lx = p.x0 + cx; items.push({ lamp: true, x: lx, y: ly, d: depth(lx, ly) }); }
        }
        for (const f of figs) if (builtCache.has(f.plot)) items.push({ fig: f, d: depth(f.x, f.y) });
        items.push({ fig: builder, builder: true, d: depth(builder.x, builder.y) });
        items.sort((a, b) => a.d - b.d); mark('collect');
        for (const it of items) {
            if (it.fig) { drawFig(it.fig, it.builder); continue; }
            if (it.lamp) { drawLamp(it.x, it.y); continue; }
            const n = it.n;
            const s = P(n.coords[0], n.coords[1], 0); if (!onScreen(s[0], s[1], 2 * K)) continue;
            const st = state(n);
            ZB = it.ghost ? 0.04 : TOP;
            let bb;
            if (n.type === 'reset') bb = drawPortal(n, st);
            else if (n.type === 'info') bb = drawSignpost(n);
            else bb = drawMachine(n, st);
            if (bb) {
                hits.push({ type: 'node', id: n.id, x0: bb[0] - 4, y0: bb[1] - 6, x1: bb[2] + 4, y1: bb[3] + 4 });
                if (n.id === selectedId) { g.save(); g.setLineDash([6, 5]); g.lineDashOffset = -T * 30; g.strokeStyle = '#ffffff'; g.lineWidth = 3; g.strokeRect(bb[0] - 6, bb[1] - 6, bb[2] - bb[0] + 12, bb[3] - bb[1] + 12); g.restore(); }
                if (st.best) arrow((bb[0] + bb[2]) / 2, bb[1] - 8, true);
                else if (st.afford && st.focus && K > 30) arrow((bb[0] + bb[2]) / 2, bb[1] - 4, false);
                if (K > 88 && n.type === 'upgrade' && st.lvl > 0) levelTag((bb[0] + bb[2]) / 2, bb[3] + 2, st.lvl, st.max);
            }
        }
        mark('items');
        ambientTick(dt); updateParts(dt); updateFigs(dt);
        drawParts(); mark('parts');
        drawClouds(false);
        drawBirds();
        drawNight(); mark('night');
        drawRain(dt);
        drawSigns(); mark('signs');
        drawFlyers(dt);
        if (prof) dbg.last = prof;
    }
    function drawLamp(x, y) {
        const a = P(x, y, TOP), b = P(x, y, TOP + 0.75);
        const s = P(x, y, 0); if (!onScreen(s[0], s[1], 40)) return;
        g.strokeStyle = INK; g.lineWidth = Math.max(2, 0.06 * K); g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
        g.fillStyle = env.night > 0.3 ? '#fff1a8' : '#e9e9e9'; g.beginPath(); g.arc(b[0], b[1], Math.max(2.5, 0.08 * K), 0, 7); g.fill(); g.lineWidth = Math.max(1, cam.zoom * 1.4); g.stroke();
        if (env.night > 0.2) lights.push([x, y, TOP + 0.75, '#ffd27a', 1.3]);
    }
    function arrow(x, y, big) {
        const b = Math.abs(Math.sin(T * (big ? 5 : 3))) * (big ? 8 : 4);
        const s = (big ? 1.2 : 0.7) * Math.min(1.2, Math.max(0.7, cam.zoom));
        g.save(); g.translate(x, y - b); g.scale(s, s);
        g.beginPath(); g.moveTo(-9, -18); g.lineTo(9, -18); g.lineTo(9, -8); g.lineTo(15, -8); g.lineTo(0, 6); g.lineTo(-15, -8); g.lineTo(-9, -8); g.closePath();
        g.fillStyle = big ? '#ffd23f' : '#39d98a'; g.fill(); g.strokeStyle = INK; g.lineWidth = 3; g.stroke(); g.restore();
    }
    function levelTag(x, y, lvl, max) {
        const t = lvl >= max ? 'MAX' : `${formatNum(lvl)}/${formatNum(max)}`;
        g.font = `700 13px "Fredoka", sans-serif`; const w = g.measureText(t).width + 12;
        roundRect(x - w / 2, y, w, 18, 9, lvl >= max ? '#ffd23f' : '#ffffff', INK, 2);
        g.fillStyle = INK; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(t, x, y + 9.5);
    }
    function easeOutBounce(x) { const n1 = 7.5625, d1 = 2.75; if (x < 1 / d1) return n1 * x * x; if (x < 2 / d1) return n1 * (x -= 1.5 / d1) * x + 0.75; if (x < 2.5 / d1) return n1 * (x -= 2.25 / d1) * x + 0.9375; return n1 * (x -= 2.625 / d1) * x + 0.984375; }

    // ---------- events from the game ----------
    function onBuy(e) {
        const n = e.node; const [x, y] = n.coords;
        if (e.isAutomated) {
            if (FXD.support() && Math.random() < 0.35) { burst(x, y, TOP + 0.6, curHex(n.costCurrency), 2, 1.2); }
            return;
        }
        nodeAnim.set(n.id, { t0: T, kind: 'buy' });
        if (FXD.support()) {
            burst(x, y, TOP + 0.7, curHex(n.costCurrency), 7 + Math.min(10, e.bought));
            floatText(x, y, TOP + 1.3, `+${formatNum(e.bought)} LV`, '#ffffff');
        }
        sendBuilder(x, y);
        if (e.newLevel >= getMaxLevel(n)) {
            ring(x, y, TOP + 0.05, '#ffd23f', 1.8, 0.8);
            burst(x, y, TOP + 0.9, '#ffd23f', 14, 2.8);
            floatText(x, y, TOP + 1.8, 'MAXED!', '#ffd23f', true);
            if (FXD.flash()) flashScreen('rgba(255,230,120,0.18)');
        }
    }
    function onReset(e) {
        FXD.hero(1400); FXD.shake(0.6);
        for (const id of e.resetIds) {
            const n = NODE_MAP.get(id); if (!n || !builtCache.has(plotKeyOf(n.coords[0], n.coords[1]))) continue;
            if (Math.random() < 0.5 * FXD.amount()) for (let i = 0; i < 2; i++) spawn({ x: n.coords[0], y: n.coords[1], z: TOP + 0.4, vx: (Math.random() - 0.5) * 2, vy: (Math.random() - 0.5) * 2, vz: 2 + Math.random() * 2, life: 1.2, col: curHex(n.costCurrency || 'P'), size: 0.09, grav: 9, brick: true, bounce: true });
            nodeAnim.set(id, { t0: T + Math.random() * 0.3, kind: 'reset' });
            lastCount.set(id, 0);
        }
        const [x, y] = e.node.coords;
        ring(x, y, TOP + 0.1, curHex(e.node.targetCurrency), 6, 1.1);
        ring(x, y, TOP + 0.1, '#ffffff', 3.5, 0.8);
        burst(x, y, TOP + 0.8, curHex(e.node.targetCurrency), 26, 3.2);
        floatText(x, y, TOP + 2, `+${formatNum(e.gain)} ${curName(e.node.targetCurrency)}`, curHex(e.node.targetCurrency), true);
        if (FXD.flash()) flashScreen(hexA(curHex(e.node.targetCurrency), 0.28));
    }
    function onPlotBuilt(p, focus) {
        plotAnim.set(p.key, { t0: T });
        textureFor(p);
        refreshBuilt(); computeBounds(); syncFigs();
        const cx = p.x0 + 2.5, cy = p.y0 + 2.5;
        if (focus) { cam.tx = cx; cam.ty = cy; }
        setTimeout(() => {
            FXD.shake(0.8);
            ring(cx, cy, 0.05, '#ffffff', 5, 1);
            for (let i = 0; i < 30 * FXD.amount(); i++) spawn({ x: cx + (Math.random() - 0.5) * 5, y: cy + (Math.random() - 0.5) * 5, z: 0.1, vx: (Math.random() - 0.5), vy: (Math.random() - 0.5), vz: 2 + Math.random() * 3, life: 0.9, col: '#d9f4ff', size: 0.06, grav: 9 });
            AUDIO.splash();
        }, 650);
        // bricks rain onto the new plot
        for (let i = 0; i < 40 * FXD.amount(); i++) {
            spawn({ x: cx + (Math.random() - 0.5) * 4.6, y: cy + (Math.random() - 0.5) * 4.6, z: 6 + Math.random() * 5, vx: 0, vy: 0, vz: -2, life: 2.4, col: [p.color, '#ffd23f', '#ffffff', '#e8453c', '#4aa8ff'][i % 5], size: 0.1, grav: 7, brick: true, bounce: true });
        }
    }
    function celebrate(nodes) {
        const list = nodes.slice(0, 40);
        list.forEach((n, i) => setTimeout(() => {
            nodeAnim.set(n.id, { t0: T, kind: 'buy' });
            if (FXD.amount() > 0) burst(n.coords[0], n.coords[1], TOP + 0.7, curHex(n.costCurrency), 4, 1.8);
            if (i % 4 === 0) AUDIO.buy(true);
        }, i * 45));
        if (list.length) { const n = list[list.length - 1]; sendBuilder(n.coords[0], n.coords[1]); }
    }
    let flashEl = null;
    function flashScreen(col) { if (!flashEl) flashEl = document.getElementById('flash'); if (!flashEl) return; flashEl.style.background = col; flashEl.classList.remove('go'); void flashEl.offsetWidth; flashEl.classList.add('go'); }

    function pick(x, y) { for (let i = hits.length - 1; i >= 0; i--) { const h = hits[i]; if (x >= h.x0 && x <= h.x1 && y >= h.y0 && y <= h.y1) return h; } return null; }
    function screenOf(x, y, z = TOP + 0.6) { setupFrame(); return P(x, y, z); }
    function focusPlot() { const [x, y] = unproject(W / 2, H / 2); return PLOTS.get(plotKeyOf(x, y)); }
    function init() { resize(); refreshBuilt(); computeBounds(); syncFigs(); for (const k of builtCache) textureFor(PLOTS.get(k)); }
    return {
        cam, env, DIRECTOR, FXD, init, resize, draw, pick, unproject, screenOf, focusPlot, refreshBuilt, builtPlots, onBuy, onReset, onPlotBuilt, fly, flashScreen,
        setSelected(id) { selectedId = id; }, setHover(k) { hoverKey = k; }, setFocus(k) { focusedKey = k; }, setSignInfo(m) { signInfo = m; }, get W() { return W; }, get H() { return H; }, get K() { return K; },
        computeBounds, syncFigs, sendBuilder, burst, floatText, ring, TOP, nodeKind, celebrate, dbg,
    };
})();
