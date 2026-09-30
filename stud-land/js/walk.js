// Walk mode: spawn your own minifig and explore the built islands in real time.
// Movement is screen relative (up on the stick is up on screen), unbuilt plots are invisible walls,
// machines, portals and props block you, and the nearest thing you can use shows a proximity prompt
// (the Roblox ProximityPrompt pattern): E or the action button uses it, holding E keeps buying.
const WALK = (() => {
    const R = WORLD.R;
    const A = { on: false, x: 0, y: 0, z: 0, vz: 0, face: 1, walk: 0, moving: false, sprint: false, near: null, target: null, stepT: 0, bumpT: 0, lastPlot: null, dist: 0 };
    const keys = new Set();
    const joy = { x: 0, y: 0, active: false };
    const SPEED = 3.4, SPRINT = 1.6, RADIUS = 0.14, REACH = 0.95;
    let prevZoom = 1;

    // ---------- walkable space ----------
    function onPlot(x, y) {
        const p = PLOTS.get(plotKeyOf(x, y)); if (!p || !R.builtCache().has(p.key)) return null;
        const m = R.INSET + RADIUS * 0.6;
        return (x > p.x0 + m && x < p.x0 + 5 - m && y > p.y0 + m && y < p.y0 + 5 - m) ? p : null;
    }
    function onBridge(x, y) {
        const b = R.builtCache();
        for (const k of b) {
            const p = PLOTS.get(k);
            if (b.has((p.gx + 1) + ',' + p.gy) && Math.abs(x - (p.x0 + 5)) < R.INSET + 0.3 && Math.abs(y - (p.y0 + 2.5)) < 0.36) return true;
            if (b.has(p.gx + ',' + (p.gy + 1)) && Math.abs(y - (p.y0 + 5)) < R.INSET + 0.3 && Math.abs(x - (p.x0 + 2.5)) < 0.36) return true;
        }
        if (b.has('3,0') && b.has('5,0') && x > 17.2 && x < 22.8 && Math.abs(y) < 0.38) return true;
        return false;
    }
    function blockers(x, y) {
        const out = [];
        const key = plotKeyOf(x, y); const p = PLOTS.get(key);
        if (p) {
            for (const n of p.nodes) {
                if (!isNodeUnlocked(n)) continue;
                if (n.type === 'upgrade' && getLevel(n.id) <= 0) continue; // holograms are walk-through
                const small = n.height === 0.5;
                if (n.type === 'reset') { out.push({ x: n.coords[0], y: n.coords[1], r: 0.2, sq: false }); continue; }
                out.push({ x: n.coords[0], y: n.coords[1], r: n.type === 'info' ? 0.08 : small ? 0.17 : 0.3, sq: n.type !== 'info' });
            }
            if (typeof PROPS !== 'undefined' && R.Q.props) for (const o of PROPS.obstacles(key)) out.push({ ...o, sq: false });
        }
        return out;
    }
    function hits(x, y) {
        for (const b of blockers(x, y)) {
            if (b.sq) { if (Math.abs(x - b.x) < b.r + RADIUS && Math.abs(y - b.y) < b.r + RADIUS) return true; }
            else if (Math.hypot(x - b.x, y - b.y) < b.r + RADIUS) return true;
        }
        return false;
    }
    const free = (x, y) => (onPlot(x, y) || onBridge(x, y)) && !hits(x, y);
    function lockedReason(x, y) {
        const p = PLOTS.get(plotKeyOf(x, y)); if (!p || R.builtCache().has(p.key)) return null;
        const info = typeof GAME !== 'undefined' && GAME.signInfo.get(p.key);
        return `${p.name}: ${(info && info.lockText) || 'not built yet'}`;
    }

    // ---------- enter / exit ----------
    function enter() {
        const f = (typeof HUD !== 'undefined' && HUD.focus) || PLOTS.get('0,0');
        const p = R.builtCache().has(f.key) ? f : PLOTS.get('0,0');
        const cells = R.freeCells(p).filter(([x, y]) => free(x, y));
        const [x, y] = cells[0] || [p.x0 + 2.5, p.y0 + 2.5];
        Object.assign(A, { on: true, x, y, z: 0, vz: 0, target: null, lastPlot: p.key });
        prevZoom = R.cam.tZoom; R.cam.tZoom = Math.max(1.25, R.cam.tZoom);
        document.body.classList.add('walking');
        FX.play('splash', { x, y, force: true });
        if (typeof META !== 'undefined') META.bump('walkSessions', 1);
    }
    function exit() { A.on = false; A.target = null; R.cam.tZoom = prevZoom; document.body.classList.remove('walking'); keys.clear(); joy.x = joy.y = 0; }
    function toggle() { if (A.on) exit(); else enter(); AUDIO.tap(); return A.on; }

    // ---------- input ----------
    window.addEventListener('keydown', (e) => {
        if (!A.on || (e.target && e.target.tagName === 'INPUT')) return;
        const k = e.key.toLowerCase();
        if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'shift'].includes(k)) { keys.add(k); e.preventDefault(); }
        if (k === ' ') { jump(); e.preventDefault(); }
        if (k === 'e' && !e.repeat) startUse();
    });
    window.addEventListener('keyup', (e) => { const k = e.key.toLowerCase(); keys.delete(k); if (k === 'e') stopUse(); });
    window.addEventListener('blur', () => { keys.clear(); stopUse(); });
    function bindTouch() {
        const pad = document.getElementById('joy'), knob = document.getElementById('joyKnob'); if (!pad) return;
        let id = null, cx = 0, cy = 0;
        pad.addEventListener('pointerdown', (e) => { id = e.pointerId; pad.setPointerCapture(id); const r = pad.getBoundingClientRect(); cx = r.left + r.width / 2; cy = r.top + r.height / 2; joy.active = true; move(e); });
        const move = (e) => { if (e.pointerId !== id) return; const R0 = 46; let dx = e.clientX - cx, dy = e.clientY - cy; const d = Math.hypot(dx, dy); if (d > R0) { dx *= R0 / d; dy *= R0 / d; } joy.x = dx / R0; joy.y = dy / R0; knob.style.transform = `translate(${dx}px, ${dy}px)`; };
        pad.addEventListener('pointermove', move);
        const end = (e) => { if (e.pointerId !== id) return; id = null; joy.x = joy.y = 0; joy.active = false; knob.style.transform = ''; };
        pad.addEventListener('pointerup', end); pad.addEventListener('pointercancel', end);
        const act = document.getElementById('btnAct'), jmp = document.getElementById('btnJump');
        act.addEventListener('pointerdown', (e) => { e.preventDefault(); startUse(); }); ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => act.addEventListener(ev, stopUse));
        jmp.addEventListener('pointerdown', (e) => { e.preventDefault(); jump(); });
    }
    function jump() { if (A.z <= 0.001) { A.vz = 3.6; if (typeof AUDIO !== 'undefined') FX.sfx('hover', A.x, A.y); } }
    // Tap to walk: the renderer picks first; a tap on open ground walks there.
    function tapTo(sx, sy) { const [x, y] = R.unproject(sx, sy); A.target = [x, y]; }

    // ---------- use (proximity prompt) ----------
    let useTimer = 0, useHeld = false, useCount = 0;
    function startUse() { if (useHeld) return; useHeld = true; useCount = 0; doUse(); useTimer = 0.32; }
    function stopUse() { useHeld = false; }
    function doUse() {
        const t = A.near; if (!t) { AUDIO.deny(); return; }
        if (t.kind === 'code') { META.collect(t.id); return; }
        if (t.kind === 'node') {
            const n = NODE_MAP.get(t.id);
            if (n.type === 'upgrade') { ACTIONS.buy(n.id, buyMode); useCount++; }
            else { HUD.openNode(n.id); useHeld = false; }
        }
    }
    function nearest() {
        let best = null, bd = REACH;
        const key = plotKeyOf(A.x, A.y); const p = PLOTS.get(key);
        if (p && R.builtCache().has(key)) for (const n of p.nodes) {
            if (!isNodeUnlocked(n)) continue;
            const d = Math.hypot(n.coords[0] - A.x, n.coords[1] - A.y); if (d < bd) { bd = d; best = { kind: 'node', id: n.id, x: n.coords[0], y: n.coords[1] }; }
        }
        if (typeof META !== 'undefined') for (const c of META.visibleCodes()) {
            const d = Math.hypot(c.x - A.x, c.y - A.y); if (d < 0.38) { META.collect(c.id); continue; }
            if (d < bd) { bd = d; best = { kind: 'code', id: c.id, x: c.x, y: c.y }; }
        }
        return best;
    }
    function promptText(t) {
        if (!t) return null;
        if (t.kind === 'code') return ['PICK UP', 'Golden brick'];
        const n = NODE_MAP.get(t.id);
        if (n.type === 'reset') return ['REBUILD', curName(n.targetCurrency)];
        if (n.type === 'info') return ['READ', n.code || 'Sign'];
        const lvl = getLevel(n.id), max = getMaxLevel(n);
        if (lvl >= max) return ['MAXED', n.name.slice(0, 22)];
        const pv = previewBuy(n, buyMode);
        return [pv.levels ? `BUY +${formatNum(pv.levels)}` : 'NEED ' + formatNum(Math.max(0, pv.firstCost - getCurr(n.costCurrency))), `${n.code || n.id}  ${formatNum(pv.levels ? pv.cost : pv.firstCost)} ${curName(n.costCurrency)}`];
    }

    // ---------- update ----------
    const SURF = { meadow: 'grass', grove: 'grass', bay: 'grass', sun: 'grass', studio: 'grass', sky: 'grass', gold: 'stone', mine: 'stone', gem: 'stone', portal: 'stone', canyon: 'stone', deep: 'stone', path: 'stone', night: 'stone', cosmos: 'stone', lagoon: 'stone', factory: 'metal', lab: 'metal', energy: 'metal', yard: 'metal', mill: 'metal', cash: 'metal', finale: 'metal', gym: 'metal', beach: 'sand', cookie: 'sand', tent: 'sand', market: 'wood', forge: 'stone' };
    function update(dt) {
        if (!A.on) return;
        const c = R.cosA, s = R.sinA;
        let ix = joy.x, iy = joy.y;
        if (keys.has('a') || keys.has('arrowleft')) ix -= 1; if (keys.has('d') || keys.has('arrowright')) ix += 1;
        if (keys.has('w') || keys.has('arrowup')) iy -= 1; if (keys.has('s') || keys.has('arrowdown')) iy += 1;
        let wx = ix * c + iy * s, wy = -ix * s + iy * c;
        if (A.target && !ix && !iy) { const dx = A.target[0] - A.x, dy = A.target[1] - A.y, d = Math.hypot(dx, dy); if (d < 0.08) A.target = null; else { wx = dx / d; wy = dy / d; } }
        else if (ix || iy) A.target = null;
        const mag = Math.hypot(wx, wy);
        A.sprint = keys.has('shift');
        A.moving = mag > 0.05;
        if (A.moving) {
            const sp = SPEED * (A.sprint ? SPRINT : 1) * Math.min(1, mag) * dt;
            wx /= mag; wy /= mag;
            const nx = A.x + wx * sp, ny = A.y + wy * sp;
            if (free(nx, ny)) { A.x = nx; A.y = ny; }
            else if (free(nx, A.y)) A.x = nx;
            else if (free(A.x, ny)) A.y = ny;
            else {
                A.target = null;
                const why = lockedReason(nx + wx * 0.4, ny + wy * 0.4);
                if (why && R.T - A.bumpT > 1.5) { A.bumpT = R.T; R.floatText(A.x, A.y, R.TOP + 1.3, 'LOCKED', '#ff9aa0'); HUD.toast(why); AUDIO.deny(); }
            }
            A.dist += sp;
            const scrX = wx * c - wy * s; if (Math.abs(scrX) > 0.05) A.face = scrX > 0 ? 1 : -1;
            A.walk += dt * (A.sprint ? 18 : 12);
            A.stepT -= dt;
            if (A.stepT <= 0 && A.z <= 0.01) {
                A.stepT = A.sprint ? 0.22 : 0.32;
                const p = PLOTS.get(plotKeyOf(A.x, A.y)); const surf = onBridge(A.x, A.y) && !onPlot(A.x, A.y) ? 'wood' : (p && SURF[p.theme]) || 'grass';
                if (typeof AUDIO !== 'undefined' && AUDIO.footstep) AUDIO.footstep(surf);
                R.spawn({ x: A.x, y: A.y, z: R.TOP + 0.02, vx: -wx * 0.3, vy: -wy * 0.3, vz: 0.2, life: 0.5, col: surf === 'sand' ? '#f0d59a' : surf === 'grass' ? '#bfe8a8' : '#d8d8d8', size: 0.04, grav: 0, fade: true, grow: 1.5, stud: false });
                trail();
            }
        }
        A.vz -= 12 * dt; A.z = Math.max(0, A.z + A.vz * dt); if (A.z === 0) A.vz = 0;
        const key = plotKeyOf(A.x, A.y); if (key !== A.lastPlot && R.builtCache().has(key)) { A.lastPlot = key; HUD.focus = PLOTS.get(key); if (typeof META !== 'undefined') META.visit(key); }
        // camera follows with a little look-ahead
        R.cam.tx = A.x + wx * 0.6; R.cam.ty = A.y + wy * 0.6;
        A.near = nearest();
        if (useHeld) { useTimer -= dt; if (useTimer <= 0) { doUse(); useTimer = Math.max(0.08, 0.2 - useCount * 0.01); } }
        const act = document.getElementById('btnAct'); if (act) { const pt = promptText(A.near); act.textContent = pt ? pt[0] : 'USE'; act.classList.toggle('dim', !pt); }
    }
    function trail() {
        const t = typeof META !== 'undefined' ? META.cosmetic('trail') : 'none';
        if (t === 'studs') R.spawn({ x: A.x, y: A.y, z: R.TOP + 0.1, vx: 0, vy: 0, vz: 0.6, life: 0.8, col: '#ffd23f', size: 0.05, grav: 2 });
        else if (t === 'sparkles') R.spawn({ x: A.x, y: A.y, z: R.TOP + 0.3, vx: 0, vy: 0, vz: 0.2, life: 0.6, col: '#fff1a0', size: 0.08, grav: 0, twinkle: true, stud: false });
        else if (t === 'bubbles') R.spawn({ x: A.x, y: A.y, z: R.TOP + 0.4, vx: 0, vy: 0, vz: 0.5, life: 1, col: '#bfe0ff', size: 0.05, grav: 0, fade: true, ringlet: true, stud: false });
        else if (t === 'flames') R.spawn({ x: A.x, y: A.y, z: R.TOP + 0.1, vx: 0, vy: 0, vz: 0.8, life: 0.6, col: '#ff8a2a', size: 0.04, grav: -0.2, add: true, fade: true, stud: false });
    }

    // ---------- draw ----------
    function drawAvatar() {
        const g = R.g, base = R.P(A.x, A.y, R.TOP + A.z), k = R.K / 64 * 1.25;
        const sh = R.P(A.x, A.y, R.TOP); g.fillStyle = 'rgba(0,0,0,0.28)'; g.beginPath(); g.ellipse(sh[0], sh[1], 6.5 * k * (1 - A.z * 0.2), 3.2 * k * (1 - A.z * 0.2), 0, 0, 7); g.fill();
        const cos = typeof META !== 'undefined' ? META.cosmetics() : {};
        const sw = A.moving ? Math.sin(A.walk) * 2.4 * k : 0;
        g.save(); g.translate(base[0], base[1]); g.scale(A.face, 1);
        g.lineWidth = Math.max(1, 1.3 * k); g.strokeStyle = INK;
        g.fillStyle = cos.legs || '#2b3a67';
        g.fillRect(-3.8 * k, -8 * k + sw * 0.35, 3.4 * k, 8 * k); g.strokeRect(-3.8 * k, -8 * k + sw * 0.35, 3.4 * k, 8 * k);
        g.fillRect(0.4 * k, -8 * k - sw * 0.35, 3.4 * k, 8 * k); g.strokeRect(0.4 * k, -8 * k - sw * 0.35, 3.4 * k, 8 * k);
        g.fillStyle = cos.torso || '#4aa8ff';
        g.beginPath(); g.moveTo(-4.8 * k, -8 * k); g.lineTo(4.8 * k, -8 * k); g.lineTo(3.8 * k, -16.5 * k); g.lineTo(-3.8 * k, -16.5 * k); g.closePath(); g.fill(); g.stroke();
        // arms swing opposite to legs
        g.fillStyle = cos.torso || '#4aa8ff'; g.save(); g.translate(4.4 * k, -15.5 * k); g.rotate(-sw * 0.08); g.fillRect(-1.2 * k, 0, 2.4 * k, 6 * k); g.strokeRect(-1.2 * k, 0, 2.4 * k, 6 * k); g.restore();
        g.fillStyle = '#ffd23f'; g.beginPath(); g.ellipse(0, -21 * k, 4 * k, 4.2 * k, 0, 0, 7); g.fill(); g.stroke();
        g.fillStyle = INK; g.fillRect(0.4 * k, -22 * k, 1.1 * k, 1.5 * k); g.fillRect(2.6 * k, -22 * k, 1.1 * k, 1.5 * k);
        g.beginPath(); g.arc(1.8 * k, -19.6 * k, 1.4 * k, 0.2, 2.9); g.stroke();
        const hat = cos.hat || 'hardhat';
        if (hat === 'hardhat') { g.fillStyle = '#ffd23f'; g.beginPath(); g.ellipse(0, -24.4 * k, 5.6 * k, 2 * k, 0, 0, 7); g.fill(); g.stroke(); g.beginPath(); g.ellipse(0, -25.8 * k, 3.9 * k, 3 * k, 0, Math.PI, 0); g.fill(); g.stroke(); }
        else if (hat === 'crown') { g.fillStyle = '#ffd23f'; g.beginPath(); g.moveTo(-4 * k, -24 * k); g.lineTo(-4 * k, -29 * k); g.lineTo(-2 * k, -26.5 * k); g.lineTo(0, -30 * k); g.lineTo(2 * k, -26.5 * k); g.lineTo(4 * k, -29 * k); g.lineTo(4 * k, -24 * k); g.closePath(); g.fill(); g.stroke(); }
        else if (hat === 'cap') { g.fillStyle = '#e8453c'; g.beginPath(); g.ellipse(0, -25 * k, 4.2 * k, 3 * k, 0, Math.PI, 0); g.fill(); g.stroke(); g.fillRect(0, -25.2 * k, 6 * k, 1.4 * k); g.strokeRect(0, -25.2 * k, 6 * k, 1.4 * k); }
        else if (hat === 'wizard') { g.fillStyle = '#6b4bd6'; g.beginPath(); g.moveTo(-5 * k, -24 * k); g.lineTo(5 * k, -24 * k); g.lineTo(1 * k, -34 * k); g.closePath(); g.fill(); g.stroke(); g.fillStyle = '#ffd23f'; g.beginPath(); g.arc(0, -28 * k, 1 * k, 0, 7); g.fill(); }
        else if (hat === 'pirate') { g.fillStyle = INK; g.beginPath(); g.ellipse(0, -25 * k, 6 * k, 2.8 * k, 0, Math.PI, 0); g.fill(); g.fillStyle = '#ffffff'; g.beginPath(); g.arc(0, -26 * k, 0.9 * k, 0, 7); g.fill(); }
        g.restore();
        // name tag
        const tag = (typeof META !== 'undefined' && META.cosmetic('name')) || 'YOU';
        g.font = `${Math.round(12 * Math.max(0.8, R.cam.zoom))}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.lineWidth = 3; g.strokeStyle = INK; g.strokeText(tag, base[0], base[1] - 38 * k); g.fillStyle = '#ffffff'; g.fillText(tag, base[0], base[1] - 38 * k);
        if (R.env.night > 0.3) R.light([A.x, A.y, R.TOP + 0.4, '#ffe39a', 0.6]);
    }
    function drawPrompt() {
        const t = A.near, pt = promptText(t); if (!pt) return;
        const g = R.g, s = R.P(t.x, t.y, R.TOP + 1.2); const zs = Math.min(1.2, Math.max(0.85, R.cam.zoom));
        g.font = `${Math.round(15 * zs)}px "Luckiest Guy", sans-serif`; const w1 = g.measureText(pt[0]).width;
        g.font = `700 ${Math.round(12 * zs)}px "Fredoka", sans-serif`; const w2 = g.measureText(pt[1]).width;
        const key = 34 * zs, w = Math.max(w1, w2) + key + 22 * zs, h = 44 * zs, x = s[0] - w / 2, y = s[1] - h - Math.abs(Math.sin(R.T * 3)) * 3;
        R.roundRect(x + 2, y + 3, w, h, 10 * zs, 'rgba(27,21,48,0.35)');
        R.roundRect(x, y, w, h, 10 * zs, '#fffaf0', INK, 3);
        const held = useHeld && t.kind === 'node';
        R.roundRect(x + 7 * zs, y + 7 * zs, key - 4 * zs, h - 14 * zs, 7 * zs, held ? '#39d98a' : '#ffd23f', INK, 2.5);
        g.fillStyle = INK; g.font = `${Math.round(17 * zs)}px "Luckiest Guy", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.fillText(matchMedia('(pointer: coarse)').matches ? '●' : 'E', x + 7 * zs + (key - 4 * zs) / 2, y + h / 2 + 1);
        g.textAlign = 'left'; g.font = `${Math.round(15 * zs)}px "Luckiest Guy", sans-serif`; g.fillText(pt[0], x + key + 10 * zs, y + 15 * zs);
        g.font = `700 ${Math.round(12 * zs)}px "Fredoka", sans-serif`; g.fillStyle = '#6b6480'; g.fillText(pt[1], x + key + 10 * zs, y + 31 * zs);
    }
    WORLD.use('update', update);
    WORLD.use('items', (items) => { if (A.on) items.push({ d: R.depth(A.x, A.y) + 0.01, draw: drawAvatar }); });
    WORLD.use('ui', () => { if (A.on) drawPrompt(); });
    return { A, get on() { return A.on; }, toggle, enter, exit, tapTo, bindTouch, free };
})();
