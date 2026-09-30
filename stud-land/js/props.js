// Themed props: set dressing placed on the free cells of every built plot. Placement is seeded by the
// plot key, so the same plot always looks the same. Static parts are stamped from the sprite atlas while
// the camera is still; moving parts (blades, flags, water, carts) draw live and only on screen.
// Props cast shadows, block walking avatars, and never affect game math.
const PROPS = (() => {
    const R = WORLD.R;
    const K = () => R.K;
    // ---------- primitives ----------
    function cyl(x, y, z, r, h, col, lw) {
        const g = R.g, b = R.P(x, y, z), t = R.P(x, y, z + h), rx = r * K(), ry = rx * R.SQ;
        g.lineWidth = lw || Math.max(1, 1.4 * R.cam.zoom); g.strokeStyle = INK;
        g.fillStyle = R.tone(col, -0.22);
        g.beginPath(); g.ellipse(b[0], b[1], rx, ry, 0, 0, Math.PI); g.lineTo(t[0] - rx, t[1]); g.ellipse(t[0], t[1], rx, ry, 0, Math.PI, 0, true); g.closePath(); g.fill(); g.stroke();
        g.fillStyle = R.tone(col, 0.05); g.beginPath(); g.ellipse(t[0], t[1], rx, ry, 0, 0, 7); g.fill(); g.stroke();
        return [b[0] - rx, t[1] - ry, b[0] + rx, b[1] + ry];
    }
    function cone(x, y, z, r, h, col) {
        const g = R.g, b = R.P(x, y, z), t = R.P(x, y, z + h), rx = r * K(), ry = rx * R.SQ;
        g.lineWidth = Math.max(1, 1.4 * R.cam.zoom); g.strokeStyle = INK;
        g.fillStyle = R.tone(col, -0.12);
        g.beginPath(); g.moveTo(b[0] - rx, b[1]); g.ellipse(b[0], b[1], rx, ry, 0, Math.PI, 0, true); g.lineTo(t[0], t[1]); g.closePath(); g.fill(); g.stroke();
        g.fillStyle = R.tone(col, 0.12); g.beginPath(); g.moveTo(t[0], t[1]); g.lineTo(b[0] - rx * 0.2, b[1] + ry * 0.6); g.lineTo(b[0] - rx * 0.85, b[1] + ry * 0.3); g.closePath(); g.fill();
    }
    function ball(x, y, z, r, col) {
        const g = R.g, c = R.P(x, y, z), rr = r * K();
        g.fillStyle = col; g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.4 * R.cam.zoom);
        g.beginPath(); g.arc(c[0], c[1], rr, 0, 7); g.fill(); g.stroke();
        g.fillStyle = R.tone(col, -0.2); g.beginPath(); g.arc(c[0] + rr * 0.15, c[1] + rr * 0.2, rr * 0.8, 0.2, 2.6); g.fill();
        g.fillStyle = 'rgba(255,255,255,0.45)'; g.beginPath(); g.ellipse(c[0] - rr * 0.35, c[1] - rr * 0.4, rr * 0.3, rr * 0.18, -0.6, 0, 7); g.fill();
    }
    function line(x1, y1, z1, x2, y2, z2, col, w) { const g = R.g, a = R.P(x1, y1, z1), b = R.P(x2, y2, z2); g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'round'; g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); g.lineCap = 'butt'; }
    function pole(x, y, z, h) { line(x, y, z, x, y, z + h, INK, Math.max(2, 0.06 * K())); line(x, y, z, x, y, z + h, '#9aa3ad', Math.max(1, 0.035 * K())); }
    function flag(x, y, z, col, w) {
        const g = R.g, a = R.P(x, y, z), k = K(); const wave = Math.sin(R.T * 5 + x * 3) * 0.06 * k;
        g.fillStyle = col; g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.2 * R.cam.zoom);
        g.beginPath(); g.moveTo(a[0], a[1]); g.quadraticCurveTo(a[0] + w * k * 0.5, a[1] - wave + 2, a[0] + w * k, a[1] + wave * 0.5 + 0.02 * k); g.lineTo(a[0] + w * k, a[1] + 0.2 * k + wave * 0.5); g.quadraticCurveTo(a[0] + w * k * 0.5, a[1] + 0.2 * k - wave, a[0], a[1] + 0.2 * k); g.closePath(); g.fill(); g.stroke();
    }
    const box = (x, y, z, hw, hd, h, col, o) => R.box(x, y, z, hw, hd, h, col, o);

    // ---------- prop types ----------
    // each: r (footprint radius for walking), h (height for shadows), draw (static, stampable), anim (live part)
    const T = {
        treeRound: { r: 0.22, h: 1.0, draw(x, y, z) { cyl(x, y, z, 0.06, 0.35, '#8a5a2f'); ball(x, y, z + 0.55, 0.26, '#3fae4a'); ball(x + 0.12, y - 0.05, z + 0.72, 0.17, '#57c65f'); } },
        treePine: { r: 0.2, h: 1.1, draw(x, y, z) { cyl(x, y, z, 0.05, 0.2, '#7a4a24'); cone(x, y, z + 0.18, 0.26, 0.45, '#2f8f47'); cone(x, y, z + 0.45, 0.2, 0.4, '#3aa556'); cone(x, y, z + 0.7, 0.13, 0.35, '#4cbf66'); } },
        bush: { r: 0.18, h: 0.3, draw(x, y, z) { ball(x - 0.07, y, z + 0.12, 0.14, '#3a9a44'); ball(x + 0.08, y + 0.03, z + 0.13, 0.15, '#4cbf56'); } },
        flowerbed: { r: 0.25, h: 0.15, draw(x, y, z) { box(x, y, z, 0.25, 0.14, 0.1, '#8a5a2f', { topCol: '#5a3a1a' }); for (let i = 0; i < 4; i++) ball(x - 0.18 + i * 0.12, y, z + 0.16, 0.05, ['#ff6b8a', '#ffd23f', '#ffffff', '#9b7bff'][i]); } },
        bench: { r: 0.22, h: 0.25, draw(x, y, z) { box(x, y, z + 0.1, 0.22, 0.08, 0.05, '#b07a45'); box(x - 0.17, y, z, 0.03, 0.06, 0.1, INK); box(x + 0.17, y, z, 0.03, 0.06, 0.1, INK); box(x, y - 0.07, z + 0.15, 0.22, 0.02, 0.12, '#b07a45'); } },
        crate: { r: 0.17, h: 0.3, draw(x, y, z) { box(x, y, z, 0.15, 0.15, 0.28, '#c98f55', { topCol: '#d9a36b' }); } },
        crates: { r: 0.25, h: 0.5, draw(x, y, z) { box(x - 0.1, y, z, 0.13, 0.13, 0.25, '#c98f55'); box(x + 0.14, y + 0.05, z, 0.11, 0.11, 0.22, '#b07a45'); box(x - 0.05, y, z + 0.25, 0.11, 0.11, 0.22, '#d9a36b'); } },
        barrel: { r: 0.14, h: 0.3, draw(x, y, z) { cyl(x, y, z, 0.12, 0.3, '#3a73c9'); } },
        pipes: { r: 0.25, h: 0.5, draw(x, y, z) { cyl(x - 0.12, y, z, 0.07, 0.45, '#9aa3ad'); cyl(x + 0.1, y + 0.05, z, 0.07, 0.3, '#b3bac2'); box(x, y, z + 0.28, 0.2, 0.05, 0.06, '#ffd23f'); } },
        chimney: { r: 0.18, h: 0.9, draw(x, y, z) { box(x, y, z, 0.15, 0.15, 0.85, '#b8513d', { seams: 4 }); box(x, y, z + 0.85, 0.18, 0.18, 0.06, '#6b6f78'); }, anim(x, y, z) { if (Math.random() < 0.06 * R.FXD.amount()) R.spawn({ x, y, z: z + 0.95, vx: R.env.wind * 0.4, vy: 0, vz: 0.5, life: 2.4, col: '#c9ced6', size: 0.07, grav: 0, fade: true, grow: 2.5, stud: false }); } },
        turbine: { r: 0.12, h: 1.3, draw(x, y, z) { cyl(x, y, z, 0.05, 1.05, '#f4f4f4'); box(x, y, z + 1.05, 0.06, 0.1, 0.08, '#e8edf3'); }, anim(x, y, z) { rotor(x, y, z + 1.09, 0.45, 3, R.T * 2.4, '#ffffff'); } },
        solar: { r: 0.25, h: 0.3, draw(x, y, z) { box(x, y, z, 0.03, 0.03, 0.18, INK); const g = R.g; const q = [R.P(x - 0.25, y - 0.12, z + 0.3), R.P(x + 0.25, y - 0.12, z + 0.3), R.P(x + 0.25, y + 0.12, z + 0.16), R.P(x - 0.25, y + 0.12, z + 0.16)]; R.poly(q, '#2a4fa0', INK, Math.max(1, 1.4 * R.cam.zoom)); g.strokeStyle = 'rgba(160,200,255,0.6)'; g.lineWidth = 1; for (let i = 1; i < 4; i++) { const a = [q[0][0] + (q[1][0] - q[0][0]) * i / 4, q[0][1] + (q[1][1] - q[0][1]) * i / 4], b = [q[3][0] + (q[2][0] - q[3][0]) * i / 4, q[3][1] + (q[2][1] - q[3][1]) * i / 4]; g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); } } },
        dish: { r: 0.2, h: 0.7, draw(x, y, z) { box(x, y, z, 0.12, 0.12, 0.3, '#d6dbe2'); }, anim(x, y, z) { const a = Math.sin(R.T * 0.5 + x) * 0.8; const c = R.P(x, y, z + 0.55); const g = R.g, k = K(); g.save(); g.translate(c[0], c[1]); g.rotate(a * 0.3); g.fillStyle = '#f4f6f9'; g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.4 * R.cam.zoom); g.beginPath(); g.ellipse(0, 0, 0.26 * k, 0.16 * k, a, 0, 7); g.fill(); g.stroke(); g.beginPath(); g.moveTo(0, 0); g.lineTo(Math.cos(a) * 0.12 * k, -0.18 * k); g.stroke(); g.restore(); } },
        antenna: { r: 0.1, h: 1.4, draw(x, y, z) { line(x - 0.1, y, z, x, y, z + 1.3, INK, 2); line(x + 0.1, y, z, x, y, z + 1.3, INK, 2); line(x - 0.06, y, z + 0.4, x + 0.06, y, z + 0.8, INK, 1.2); }, anim(x, y, z) { const on = Math.sin(R.T * 4 + x) > 0.3; const c = R.P(x, y, z + 1.32); R.g.fillStyle = on ? '#ff4d4d' : '#6b1a1a'; R.g.beginPath(); R.g.arc(c[0], c[1], Math.max(2, 0.05 * K()), 0, 7); R.g.fill(); if (on && R.env.night > 0.2) R.light([x, y, z + 1.32, '#ff4d4d', 0.5]); } },
        beaker: { r: 0.12, h: 0.35, draw(x, y, z) { cyl(x, y, z, 0.1, 0.25, '#7fe0ff'); cyl(x, y, z + 0.25, 0.04, 0.1, '#bfefff'); }, anim(x, y, z) { if (Math.random() < 0.04 * R.FXD.amount()) R.spawn({ x, y, z: z + 0.36, vx: 0, vy: 0, vz: 0.4, life: 1.2, col: '#bff6ff', size: 0.03, grav: 0, fade: true, ringlet: true, stud: false }); if (R.env.night > 0.3) R.light([x, y, z + 0.15, '#7fe0ff', 0.5]); } },
        easel: { r: 0.15, h: 0.6, draw(x, y, z) { line(x - 0.1, y, z, x, y, z + 0.55, '#8a5a2f', 2.5); line(x + 0.1, y, z, x, y, z + 0.55, '#8a5a2f', 2.5); box(x, y + 0.02, z + 0.22, 0.14, 0.02, 0.26, '#ffffff'); const c = R.P(x, y + 0.04, z + 0.35); R.g.fillStyle = '#ff6b8a'; R.g.beginPath(); R.g.arc(c[0] - 3, c[1], 3, 0, 7); R.g.fill(); R.g.fillStyle = '#4aa8ff'; R.g.beginPath(); R.g.arc(c[0] + 3, c[1] + 2, 3, 0, 7); R.g.fill(); } },
        spotlight: { r: 0.12, h: 0.5, draw(x, y, z) { cyl(x, y, z, 0.1, 0.06, '#3a3a46'); box(x, y, z + 0.06, 0.02, 0.02, 0.28, INK); cyl(x, y, z + 0.34, 0.09, 0.14, '#ffd23f'); }, anim(x, y, z) { if (R.env.night > 0.25) R.light([x, y, z + 0.5, '#fff1a8', 1]); } },
        balloons: { r: 0.12, h: 1.2, draw() { }, anim(x, y, z) { const b = Math.sin(R.T * 1.6 + x * 2) * 0.05; [['#ff4d4d', -0.12, 0.95], ['#ffd23f', 0.1, 1.05], ['#4aa8ff', 0, 1.2]].forEach(([c, dx, h]) => { line(x, y, z, x + dx, y, z + h + b - 0.12, 'rgba(27,21,48,0.6)', 1); ball(x + dx, y, z + h + b, 0.1, c); }); } },
        statue: { r: 0.2, h: 1, draw(x, y, z) { box(x, y, z, 0.2, 0.2, 0.25, '#d6dbe2', { seams: 2 }); box(x, y, z + 0.25, 0.1, 0.06, 0.22, '#ffd23f'); box(x, y, z + 0.47, 0.13, 0.07, 0.2, '#ffd23f'); ball(x, y, z + 0.78, 0.09, '#ffd23f'); } },
        trophy: { r: 0.15, h: 0.7, draw(x, y, z) { box(x, y, z, 0.14, 0.14, 0.18, '#3a3a46'); cyl(x, y, z + 0.18, 0.03, 0.18, '#ffd23f'); cyl(x, y, z + 0.36, 0.13, 0.22, '#ffd23f'); }, anim(x, y, z) { const tw = (Math.sin(R.T * 2 + x * 5) + 1) / 2; if (tw > 0.9) { const c = R.P(x, y, z + 0.62); R.sparkle(c[0], c[1], (tw - 0.9) * 90 * R.cam.zoom); } } },
        fountain: { r: 0.3, h: 0.5, draw(x, y, z) { cyl(x, y, z, 0.3, 0.12, '#cfd6de'); cyl(x, y, z + 0.1, 0.24, 0.02, '#63b3ff'); cyl(x, y, z + 0.1, 0.05, 0.3, '#cfd6de'); }, anim(x, y, z) { if (Math.random() < 0.5 * R.FXD.amount()) { const a = Math.random() * 6.28; R.spawn({ x, y, z: z + 0.42, vx: Math.cos(a) * 0.4, vy: Math.sin(a) * 0.4, vz: 1.2, life: 0.55, col: '#cfeaff', size: 0.025, grav: 5, stud: false }); } } },
        dumbbell: { r: 0.2, h: 0.2, draw(x, y, z) { line(x - 0.15, y, z + 0.08, x + 0.15, y, z + 0.08, INK, 3); cyl(x - 0.16, y, z, 0.07, 0.16, '#3a3a46'); cyl(x + 0.16, y, z, 0.07, 0.16, '#3a3a46'); } },
        flagpole: { r: 0.08, h: 1.3, draw(x, y, z) { cyl(x, y, z, 0.08, 0.05, '#6b6f78'); pole(x, y, z, 1.25); }, anim(x, y, z) { flag(x, y, z + 1.2, '#ff4d4d', 0.4); } },
        cone: { r: 0.1, h: 0.25, draw(x, y, z) { box(x, y, z, 0.1, 0.1, 0.03, '#ff9a2e'); cone(x, y, z + 0.03, 0.08, 0.22, '#ff9a2e'); } },
        windmill: { r: 0.2, h: 1.2, draw(x, y, z) { box(x, y, z, 0.2, 0.2, 0.7, '#f4f1e8', { seams: 3 }); cone(x, y, z + 0.7, 0.26, 0.28, '#b8513d'); }, anim(x, y, z) { rotor(x, y + 0.22, z + 0.7, 0.5, 4, R.T * 1.2, '#c98f55', true); } },
        stump: { r: 0.14, h: 0.15, draw(x, y, z) { cyl(x, y, z, 0.12, 0.13, '#8a5a2f'); } },
        mushroom: { r: 0.14, h: 0.35, draw(x, y, z) { cyl(x, y, z, 0.05, 0.18, '#f4efe0'); cone(x, y, z + 0.16, 0.17, 0.16, '#e8453c'); ball(x - 0.05, y, z + 0.25, 0.025, '#ffffff'); } },
        sunflower: { r: 0.12, h: 0.9, draw(x, y, z) { line(x, y, z, x, y, z + 0.75, '#3a9a44', Math.max(2, 0.04 * K())); }, anim(x, y, z) { const sway = Math.sin(R.T * 1.5 + x) * 0.03; const c = R.P(x + sway, y, z + 0.8), k = K(); const g = R.g; g.fillStyle = '#ffd23f'; g.strokeStyle = INK; g.lineWidth = 1; for (let i = 0; i < 8; i++) { const a = i * 0.785 + R.T * 0.2; g.beginPath(); g.ellipse(c[0] + Math.cos(a) * 0.1 * k, c[1] + Math.sin(a) * 0.1 * k, 0.06 * k, 0.03 * k, a, 0, 7); g.fill(); g.stroke(); } g.fillStyle = '#6b3a12'; g.beginPath(); g.arc(c[0], c[1], 0.06 * k, 0, 7); g.fill(); g.stroke(); } },
        beehive: { r: 0.14, h: 0.4, draw(x, y, z) { box(x, y, z, 0.02, 0.02, 0.15, INK); for (let i = 0; i < 3; i++) cyl(x, y, z + 0.15 + i * 0.07, 0.12 - i * 0.03, 0.07, '#ffb300'); }, anim(x, y, z) { if (Math.random() < 0.05 * R.FXD.amount()) R.spawn({ x, y, z: z + 0.25, vx: (Math.random() - 0.5) * 0.8, vy: (Math.random() - 0.5) * 0.8, vz: 0.2, life: 1.4, col: '#1b1530', size: 0.02, grav: 0, stud: false }); } },
        obelisk: { r: 0.15, h: 1.2, draw(x, y, z) { box(x, y, z, 0.14, 0.14, 0.9, '#3a2a44', { seams: 3 }); cone(x, y, z + 0.9, 0.12, 0.25, '#3a2a44'); }, anim(x, y, z) { const c = R.P(x, y, z + 0.5); R.g.save(); R.g.globalCompositeOperation = 'lighter'; R.g.fillStyle = `rgba(255,90,170,${0.5 + 0.4 * Math.sin(R.T * 3 + x)})`; R.g.beginPath(); R.g.arc(c[0], c[1], 0.06 * K(), 0, 7); R.g.fill(); R.g.restore(); R.light([x, y, z + 0.5, '#ff5aa0', 0.6]); } },
        crystal: { r: 0.15, h: 0.6, draw(x, y, z) { cone(x, y, z, 0.1, 0.55, '#7fe8ff'); cone(x + 0.1, y + 0.05, z, 0.06, 0.32, '#a7f0ff'); cone(x - 0.09, y + 0.03, z, 0.05, 0.25, '#5fd4f0'); }, anim(x, y, z) { R.light([x, y, z + 0.3, '#7fe8ff', 0.55]); } },
        rock: { r: 0.2, h: 0.3, draw(x, y, z) { ball(x, y, z + 0.1, 0.17, '#8d8f93'); ball(x + 0.14, y + 0.06, z + 0.06, 0.1, '#a3a5a9'); } },
        minecart: { r: 0.3, h: 0.3, draw(x, y, z) { line(x - 0.45, y, z + 0.01, x + 0.45, y, z + 0.01, '#6b4b1e', Math.max(2, 0.05 * K())); line(x - 0.45, y + 0.08, z + 0.01, x + 0.45, y + 0.08, z + 0.01, '#6b4b1e', Math.max(2, 0.05 * K())); }, anim(x, y, z) { const u = Math.sin(R.T * 0.7 + x) * 0.3; box(x + u, y + 0.04, z + 0.03, 0.14, 0.09, 0.15, '#6b6f78'); ball(x + u - 0.05, y + 0.04, z + 0.2, 0.05, '#ffd23f'); ball(x + u + 0.05, y + 0.03, z + 0.2, 0.05, '#22d3ee'); } },
        lantern: { r: 0.08, h: 0.6, draw(x, y, z) { pole(x, y, z, 0.5); box(x, y, z + 0.45, 0.06, 0.06, 0.1, '#ffd27a', { alpha: 0.9 }); }, anim(x, y, z) { if (R.env.night > 0.2) R.light([x, y, z + 0.5, '#ffb347', 1.1]); } },
        lava: { r: 0.3, h: 0.05, draw(x, y, z) { const g = R.g, c = R.P(x, y, z + 0.01), rx = 0.3 * K(); g.fillStyle = '#3a2a1a'; g.beginPath(); g.ellipse(c[0], c[1], rx * 1.1, rx * 0.55 * 1.1, 0, 0, 7); g.fill(); g.fillStyle = '#ff6a1a'; g.beginPath(); g.ellipse(c[0], c[1], rx, rx * 0.5, 0, 0, 7); g.fill(); }, anim(x, y, z) { const c = R.P(x, y, z + 0.01), rx = 0.3 * K(); const g = R.g; g.save(); g.globalCompositeOperation = 'lighter'; g.fillStyle = `rgba(255,220,80,${0.3 + 0.2 * Math.sin(R.T * 2 + x)})`; g.beginPath(); g.ellipse(c[0], c[1], rx * 0.6, rx * 0.3, 0, 0, 7); g.fill(); g.restore(); if (Math.random() < 0.08 * R.FXD.amount()) R.spawn({ x: x + (Math.random() - 0.5) * 0.4, y: y + (Math.random() - 0.5) * 0.2, z: z + 0.02, vx: 0, vy: 0, vz: 0.8, life: 0.5, col: '#ffb347', size: 0.035, grav: 3, add: true, stud: false }); R.light([x, y, z + 0.1, '#ff6a1a', 0.8]); } },
        checkflag: { r: 0.1, h: 1.2, draw(x, y, z) { pole(x, y, z, 1.15); }, anim(x, y, z) { flag(x, y, z + 1.1, '#ffffff', 0.4); const c = R.P(x, y, z + 1.1), k = K(); R.g.fillStyle = INK; for (let i = 0; i < 4; i++) R.g.fillRect(c[0] + i * 0.1 * k, c[1] + (i % 2) * 0.1 * k, 0.1 * k, 0.1 * k); } },
        telescope: { r: 0.15, h: 0.6, draw(x, y, z) { line(x - 0.1, y, z, x, y, z + 0.35, INK, 2); line(x + 0.1, y, z, x, y, z + 0.35, INK, 2); line(x - 0.15, y, z + 0.3, x + 0.18, y, z + 0.55, '#c9ced6', Math.max(4, 0.09 * K())); } },
        stall: { r: 0.3, h: 0.7, draw(x, y, z) { box(x, y, z, 0.28, 0.16, 0.3, '#c98f55'); box(x - 0.25, y - 0.14, z + 0.3, 0.02, 0.02, 0.3, INK); box(x + 0.25, y - 0.14, z + 0.3, 0.02, 0.02, 0.3, INK); for (let i = 0; i < 5; i++) box(x - 0.24 + i * 0.12, y, z + 0.6, 0.06, 0.2, 0.05, i % 2 ? '#ffffff' : '#e8453c'); ball(x - 0.1, y - 0.1, z + 0.34, 0.05, '#ff4d4d'); ball(x + 0.05, y - 0.1, z + 0.34, 0.05, '#ffd23f'); ball(x + 0.17, y - 0.08, z + 0.34, 0.05, '#39d98a'); } },
        anvil: { r: 0.18, h: 0.3, draw(x, y, z) { box(x, y, z, 0.1, 0.08, 0.12, '#3a3a46'); box(x, y, z + 0.12, 0.2, 0.1, 0.1, '#4a4a56'); }, anim(x, y, z) { if (Math.random() < 0.02 * R.FXD.amount()) for (let i = 0; i < 5; i++) R.spark(x, y, z + 0.25); } },
        cactus: { r: 0.12, h: 0.7, draw(x, y, z) { cyl(x, y, z, 0.08, 0.6, '#3aa556'); cyl(x + 0.12, y, z + 0.25, 0.05, 0.22, '#3aa556'); cyl(x - 0.12, y, z + 0.35, 0.05, 0.18, '#3aa556'); } },
        arch: { r: 0.35, h: 0.9, draw(x, y, z) { box(x - 0.3, y, z, 0.1, 0.12, 0.7, '#c9573f', { seams: 3 }); box(x + 0.3, y, z, 0.1, 0.12, 0.7, '#c9573f', { seams: 3 }); box(x, y, z + 0.7, 0.4, 0.12, 0.14, '#d9674f'); } },
        palm: { r: 0.15, h: 1.2, draw(x, y, z) { for (let i = 0; i < 5; i++) cyl(x + i * 0.02, y, z + i * 0.18, 0.06, 0.18, i % 2 ? '#a0703a' : '#8a5a2f', 1); }, anim(x, y, z) { const c = R.P(x + 0.1, y, z + 0.95), k = K(), g = R.g; const sw = Math.sin(R.T * 1.3 + x) * 0.15; g.strokeStyle = INK; g.lineWidth = 1.2; g.fillStyle = '#3aa556'; for (let i = 0; i < 6; i++) { const a = i * 1.047 + sw; g.beginPath(); g.moveTo(c[0], c[1]); g.quadraticCurveTo(c[0] + Math.cos(a) * 0.3 * k, c[1] + Math.sin(a) * 0.12 * k - 0.15 * k, c[0] + Math.cos(a) * 0.45 * k, c[1] + Math.sin(a) * 0.2 * k + 0.05 * k); g.quadraticCurveTo(c[0] + Math.cos(a) * 0.25 * k, c[1] + Math.sin(a) * 0.12 * k, c[0], c[1]); g.fill(); g.stroke(); } ball(x + 0.1, y, z + 0.92, 0.05, '#6b3a12'); } },
        umbrella: { r: 0.25, h: 0.7, draw(x, y, z) { pole(x, y, z, 0.6); cone(x, y, z + 0.52, 0.3, 0.14, '#ff6b8a'); } },
        sandcastle: { r: 0.22, h: 0.4, draw(x, y, z) { box(x, y, z, 0.2, 0.2, 0.15, '#e8c98a'); box(x - 0.12, y - 0.12, z + 0.15, 0.06, 0.06, 0.14, '#f0d59a'); box(x + 0.12, y + 0.12, z + 0.15, 0.06, 0.06, 0.14, '#f0d59a'); box(x, y, z + 0.15, 0.08, 0.08, 0.2, '#f0d59a'); } },
        moneybag: { r: 0.15, h: 0.35, draw(x, y, z) { ball(x, y, z + 0.14, 0.14, '#c9a36b'); cyl(x, y, z + 0.26, 0.04, 0.06, '#8a5a2f'); const c = R.P(x, y, z + 0.14); R.g.fillStyle = '#2f8f4f'; R.g.font = `${Math.max(8, 0.14 * K()) | 0}px "Luckiest Guy"`; R.g.textAlign = 'center'; R.g.textBaseline = 'middle'; R.g.fillText('$', c[0], c[1]); } },
        vault: { r: 0.25, h: 0.6, draw(x, y, z) { box(x, y, z, 0.25, 0.2, 0.55, '#6b6f78', { seams: 2 }); const c = R.P(x, y + 0.2, z + 0.28), k = K(); R.g.strokeStyle = '#ffd23f'; R.g.lineWidth = 2; R.g.beginPath(); R.g.ellipse(c[0], c[1], 0.12 * k, 0.12 * k, 0, 0, 7); R.g.stroke(); } },
        loopring: { r: 0.25, h: 0.9, draw(x, y, z) { box(x, y, z, 0.15, 0.15, 0.1, '#bdbccb'); }, anim(x, y, z) { const c = R.P(x, y, z + 0.5), k = K(), g = R.g; const a = R.T * 1.4; g.strokeStyle = '#9b7bff'; g.lineWidth = Math.max(3, 0.07 * k); g.beginPath(); g.ellipse(c[0], c[1], 0.35 * k * Math.abs(Math.cos(a)) + 2, 0.35 * k, 0, 0, 7); g.stroke(); g.strokeStyle = '#ff9df2'; g.beginPath(); g.ellipse(c[0], c[1], 0.35 * k, 0.35 * k * Math.abs(Math.sin(a)) + 2, 0, 0, 7); g.stroke(); } },
        cookie: { r: 0.3, h: 0.2, draw(x, y, z) { cyl(x, y, z, 0.3, 0.1, '#d6a26b'); for (let i = 0; i < 6; i++) { const c = R.P(x + Math.cos(i * 1.1) * 0.18, y + Math.sin(i * 1.1) * 0.15, z + 0.1); R.g.fillStyle = '#4a2a12'; R.g.beginPath(); R.g.arc(c[0], c[1], Math.max(1.5, 0.03 * K()), 0, 7); R.g.fill(); } } },
        milk: { r: 0.12, h: 0.45, draw(x, y, z) { cyl(x, y, z, 0.1, 0.4, '#f4f4f4'); cyl(x, y, z + 0.3, 0.1, 0.02, '#ffffff'); } },
        circus: { r: 0.35, h: 0.9, draw(x, y, z) { cyl(x, y, z, 0.32, 0.35, '#ffffff'); cone(x, y, z + 0.35, 0.36, 0.4, '#e8453c'); pole(x, y, z + 0.72, 0.2); } },
    };
    function rotor(x, y, z, r, n, a, col, wide) {
        const c = R.P(x, y, z), k = K(), g = R.g;
        g.save(); g.translate(c[0], c[1]); g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.2 * R.cam.zoom); g.fillStyle = col;
        for (let i = 0; i < n; i++) { const b = a + i * 6.283 / n; g.save(); g.rotate(b); g.beginPath(); g.moveTo(0, 0); g.lineTo(r * k, -(wide ? 0.08 : 0.04) * k); g.lineTo(r * k, (wide ? 0.08 : 0.04) * k); g.closePath(); g.fill(); g.stroke(); g.restore(); }
        g.fillStyle = '#6b6f78'; g.beginPath(); g.arc(0, 0, Math.max(2, 0.05 * k), 0, 7); g.fill(); g.stroke(); g.restore();
    }
    const THEME_PROPS = {
        meadow: ['treeRound', 'treeRound', 'bush', 'flowerbed', 'bench', 'treePine'], lab: ['dish', 'antenna', 'beaker', 'crate', 'beaker'],
        factory: ['chimney', 'pipes', 'crates', 'barrel'], energy: ['turbine', 'solar', 'turbine', 'barrel'], studio: ['easel', 'spotlight', 'balloons'],
        gold: ['statue', 'trophy', 'fountain'], gym: ['dumbbell', 'flagpole', 'cone'], mill: ['windmill', 'crate', 'flowerbed'], sky: ['balloons', 'flagpole', 'bench'],
        path: ['cone', 'bush', 'bench', 'lantern'], grove: ['treePine', 'treeRound', 'stump', 'mushroom', 'treePine'], sun: ['sunflower', 'sunflower', 'beehive', 'bush'],
        portal: ['obelisk', 'crystal', 'rock'], yard: ['crates', 'barrel', 'crate'], mine: ['minecart', 'rock', 'lantern'], gem: ['crystal', 'crystal', 'rock'],
        deep: ['lava', 'rock', 'lantern'], finale: ['checkflag', 'trophy', 'statue'], cosmos: ['crystal', 'telescope', 'obelisk'], market: ['stall', 'crates', 'barrel'],
        forge: ['anvil', 'lava', 'chimney'], night: ['lantern', 'lantern', 'treePine'], canyon: ['cactus', 'rock', 'arch', 'cactus'], bay: ['palm', 'umbrella', 'bush'],
        cash: ['moneybag', 'vault', 'crate'], lagoon: ['loopring', 'rock', 'palm'], beach: ['palm', 'umbrella', 'sandcastle'], cookie: ['cookie', 'milk', 'bush'],
        tent: ['circus', 'flagpole', 'balloons'],
    };
    // ---------- placement ----------
    const placed = new Map();
    function propsFor(p) {
        let list = placed.get(p.key); if (list) return list;
        list = [];
        const kinds = THEME_PROPS[p.theme] || THEME_PROPS.meadow;
        const r = R.rng(R.hashKey(p.key + 'props'));
        const taken = new Set((typeof META_SPOTS !== 'undefined' ? META_SPOTS : []).filter(s => s.plot === p.key).map(s => s.cell));
        R.freeCells(p).forEach(([x, y], i) => {
            if (taken.has(i) || r() < 0.28) return;
            const type = kinds[(r() * kinds.length) | 0];
            list.push({ type, x: x + (r() - 0.5) * 0.3, y: y + (r() - 0.5) * 0.3, def: T[type] });
        });
        placed.set(p.key, list); return list;
    }
    function obstacles(key) { const p = PLOTS.get(key); if (!p) return []; return propsFor(p).map(o => ({ x: o.x, y: o.y, r: o.def.r })); }
    WORLD.use('shadows', (p) => { if (!R.Q.props) return; for (const o of propsFor(p)) R.shadow(o.x, o.y, o.def.r * 0.7, o.def.r * 0.7, o.def.h * 0.8); });
    WORLD.use('items', (items, plist) => {
        if (!R.Q.props || R.K < 18) return;
        for (const p of plist) {
            if (!R.builtCache().has(p.key) || R.plotAnim.has(p.key)) continue;
            const c = R.P(p.x0 + 2.5, p.y0 + 2.5, 0); if (!R.onScreen(c[0], c[1], 4 * R.K)) continue;
            for (const o of propsFor(p)) {
                const d = o.def;
                items.push({ d: R.depth(o.x, o.y), draw() {
                    const s = R.P(o.x, o.y, R.TOP); if (!R.onScreen(s[0], s[1], 2 * R.K)) return;
                    if (R.camStill() && d.h > 0) R.stamp('p' + o.type, o.x, o.y, R.TOP, { hw: d.r + 0.25, h: d.h + 0.3 }, () => d.draw(o.x, o.y, R.TOP));
                    else d.draw(o.x, o.y, R.TOP);
                    if (d.anim && R.K >= 26) d.anim(o.x, o.y, R.TOP);
                } });
            }
        }
    });
    return { TYPES: T, THEME_PROPS, propsFor, obstacles, cyl, cone, ball, flag, rotor };
})();
