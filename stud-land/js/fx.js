// Stud City Incremental effects catalog.
// Every visual effect in the game is declared here once: what triggers it, its tier in the attention
// budget, timings, particle counts, easing, the sound and haptic it pairs with, and how to build it in
// Roblox. The game calls FX.play(id, ctx); the FX Lab (dev bar) lists the catalog and plays any entry.
//
// Tiers (the attention budget):
//   hero     one at a time, 1.2 to 2.5 s, may use camera, letterbox, hit-stop, flash (flash limited to 2/s)
//   support  at most 3 starts per 250 ms, under 1 s, never moves the camera
//   ambient  background life, always yields: skipped in Minimal, thinned in Reduced and on low quality
const FX = (() => {
    const R = WORLD.R;
    const CATALOG = [], byId = {};
    function def(e) { CATALOG.push(e); byId[e.id] = e; }
    const quiet = () => typeof GAME !== 'undefined' && (GAME.sim || GAME.speed >= 10);

    // Sound and haptic helpers: pan follows where the effect happens on screen.
    function sfx(id, x, y, opts = {}) {
        if (typeof AUDIO === 'undefined') return;
        let pan = 0;
        if (x !== undefined) { const s = R.P(x, y, R.TOP); pan = AUDIO.panFor ? AUDIO.panFor(s[0], R.W) : 0; }
        if (AUDIO.play) AUDIO.play(id, { pan, ...opts });
        else if (AUDIO[id]) AUDIO[id](opts.big);
    }
    function haptic(id) { if (typeof HAPTIC === 'undefined') return; if (HAPTIC.play) HAPTIC.play(id); else if (HAPTIC[id]) HAPTIC[id](); }
    function play(id, ctx = {}) {
        const e = byId[id]; if (!e) return false;
        if (e.tier === 'hero' && !ctx.force && !R.FXD.hero(e.durationMs)) return false;
        if (e.tier === 'support' && !ctx.force && !R.FXD.support()) { if (e.fallback) e.fallback(ctx); return false; }
        if (e.tier === 'ambient' && R.FXD.amount() === 0 && !ctx.force) return false;
        try { e.run(ctx); } catch (err) { console.warn('fx', id, err); }
        return true;
    }
    // A place to show an effect when the Lab has nothing selected: the middle of the screen.
    function here(ctx) {
        if (ctx.node) return ctx.node.coords;
        if (ctx.x !== undefined) return [ctx.x, ctx.y];
        const c = R.unproject(R.W / 2, R.H / 2); return c;
    }
    let flashEl = null, boxEl = null;
    function letterbox(ms) { if (!boxEl) boxEl = document.getElementById('letterbox'); if (!boxEl || R.DIRECTOR.mode !== 'full') return; boxEl.classList.add('on'); setTimeout(() => boxEl.classList.remove('on'), ms); }
    function flash(col) { if (!R.FXD.flash()) return; R.flashScreen(col); }
    function zoomPunch(a) { if (R.DIRECTOR.mode !== 'full') return; R.cam.zoom *= 1 + a; }

    // ---------------- drones (automation) ----------------
    // Each automated purchase sends a little drone from the automation machine that owns the rule
    // to the machine it bought. Capped at 14 in the air; extra buys get a small puff instead.
    const TARGET_SRC = new Map();
    if (typeof AUTOMATION_INDEX !== 'undefined') for (const a of AUTOMATION_INDEX) for (const t of a.targets) if (!TARGET_SRC.has(t)) TARGET_SRC.set(t, a.nodeId);
    const drones = [];
    function launchDrone(n) {
        const src = NODE_MAP.get(TARGET_SRC.get(n.id));
        const [x1, y1] = n.coords;
        let x0, y0;
        if (src) [x0, y0] = src.coords; else { x0 = x1 + 3; y0 = y1 - 3; }
        if (Math.hypot(x1 - x0, y1 - y0) < 0.5) { x0 += 1.5; y0 -= 1.5; }
        drones.push({ x0, y0, x1, y1, t: 0, life: 0.9 + Math.hypot(x1 - x0, y1 - y0) * 0.08, col: curHex(n.costCurrency || 'P'), n, dropped: false });
    }
    function updateDrones(dt) {
        for (let i = drones.length - 1; i >= 0; i--) {
            const d = drones[i]; d.t += dt;
            if (!d.dropped && d.t >= d.life) { d.dropped = true; R.nodeAnim.set(d.n.id, { t0: R.T, kind: 'buy' }); R.puff(d.x1, d.y1, R.TOP + 0.6, d.col); if (Math.random() < 0.3) sfx('drone', d.x1, d.y1, { vol: 0.5 }); }
            if (d.t >= d.life + 0.8) drones.splice(i, 1);
        }
    }
    function drawDrones() {
        const g = R.g, K = R.K;
        for (const d of drones) {
            const out = d.t > d.life; const k = out ? Math.min(1, (d.t - d.life) / 0.8) : Math.min(1, d.t / d.life);
            const e = k * k * (3 - 2 * k);
            const x = out ? d.x1 + (d.x1 - d.x0) * 0.4 * e : d.x0 + (d.x1 - d.x0) * e;
            const y = out ? d.y1 + (d.y1 - d.y0) * 0.4 * e : d.y0 + (d.y1 - d.y0) * e;
            const z = R.TOP + 1.1 + Math.sin(k * Math.PI) * (out ? 0.8 : 0.9) + Math.sin(R.T * 9 + d.x0) * 0.03;
            const s = R.P(x, y, z); if (!R.onScreen(s[0], s[1], 40)) continue;
            const sh = R.P(x, y, R.TOP); g.fillStyle = 'rgba(0,0,0,0.18)'; g.beginPath(); g.ellipse(sh[0], sh[1], 0.14 * K, 0.07 * K, 0, 0, 7); g.fill();
            const w = 0.2 * K;
            g.strokeStyle = INK; g.lineWidth = Math.max(1, 1.4 * R.cam.zoom);
            // rotor blur, body, blinking light, and the brick it carries until the drop
            g.fillStyle = 'rgba(220,230,240,0.55)'; g.beginPath(); g.ellipse(s[0] - w * 0.7, s[1] - w * 0.35, w * 0.45, w * 0.12, 0, 0, 7); g.ellipse(s[0] + w * 0.7, s[1] - w * 0.35, w * 0.45, w * 0.12, 0, 0, 7); g.fill();
            g.fillStyle = '#e8edf3'; g.beginPath(); g.roundRect ? g.roundRect(s[0] - w * 0.55, s[1] - w * 0.3, w * 1.1, w * 0.5, w * 0.15) : g.rect(s[0] - w * 0.55, s[1] - w * 0.3, w * 1.1, w * 0.5); g.fill(); g.stroke();
            g.fillStyle = Math.sin(R.T * 12 + d.x0) > 0 ? '#ff4d4d' : '#39d98a'; g.beginPath(); g.arc(s[0], s[1] - w * 0.05, Math.max(1.5, w * 0.1), 0, 7); g.fill();
            if (!d.dropped) { g.fillStyle = d.col; g.fillRect(s[0] - w * 0.25, s[1] + w * 0.22, w * 0.5, w * 0.3); g.strokeRect(s[0] - w * 0.25, s[1] + w * 0.22, w * 0.5, w * 0.3); }
            if (R.env.night > 0.3) R.light([x, y, z, '#ff6b6b', 0.35]);
        }
    }

    // ---------------- fireworks (sky layer) ----------------
    const rockets = [];
    function launchFireworks(x, y, n = 5) {
        for (let i = 0; i < n; i++) rockets.push({ x: x + (Math.random() - 0.5) * 3, y: y + (Math.random() - 0.5) * 3, z: R.TOP, vz: 5.2 + Math.random() * 1.6, t: -i * 0.28, col: ['#ff4d4d', '#ffd23f', '#39d98a', '#4aa8ff', '#ff7ae0', '#ffffff'][(Math.random() * 6) | 0] });
    }
    function updateRockets(dt) {
        for (let i = rockets.length - 1; i >= 0; i--) {
            const r = rockets[i]; r.t += dt; if (r.t < 0) continue;
            r.z += r.vz * dt; r.vz -= 4.2 * dt;
            if (Math.random() < 0.6) R.spawn({ x: r.x, y: r.y, z: r.z, vx: 0, vy: 0, vz: -0.2, life: 0.35, col: '#fff3c4', size: 0.025, grav: 0, add: true, fade: true, stud: false });
            if (r.vz <= 0.4) {
                const n = Math.round(26 * Math.max(0.3, R.FXD.amount()));
                for (let k = 0; k < n; k++) { const a = k / n * 6.283, e = (Math.random() - 0.5) * 1.2; R.spawn({ x: r.x, y: r.y, z: r.z, vx: Math.cos(a) * 2.2, vy: Math.sin(a) * 2.2, vz: e * 2.2, life: 1.1, col: r.col, size: 0.04, grav: 1.6, add: true, fade: true, stud: false }); }
                R.ring(r.x, r.y, r.z, r.col, 1.6, 0.5);
                sfx('fireworks', r.x, r.y, { vol: 0.7 });
                rockets.splice(i, 1);
            }
        }
    }

    // ---------------- screen confetti (UI layer) ----------------
    const confetti = [];
    function throwConfetti(n = 70, x = null) {
        n = Math.round(n * Math.max(0.3, R.FXD.amount()));
        for (let i = 0; i < n; i++) confetti.push({ x: x === null ? Math.random() * R.W : x + (Math.random() - 0.5) * 120, y: -20 - Math.random() * 120, vx: (Math.random() - 0.5) * 120, vy: 80 + Math.random() * 160, r: Math.random() * 6, vr: (Math.random() - 0.5) * 10, w: 6 + Math.random() * 6, col: ['#ff4d4d', '#ffd23f', '#39d98a', '#4aa8ff', '#ff7ae0', '#ffffff'][i % 6], t: 0 });
    }
    function drawConfetti(dt) {
        const g = R.g;
        for (let i = confetti.length - 1; i >= 0; i--) {
            const c = confetti[i]; c.t += dt; c.x += (c.vx + Math.sin(c.t * 4 + i) * 40) * dt; c.y += c.vy * dt; c.r += c.vr * dt;
            if (c.y > R.H + 30 || c.t > 5) { confetti.splice(i, 1); continue; }
            g.save(); g.translate(c.x, c.y); g.rotate(c.r); g.scale(1, Math.abs(Math.sin(c.t * 6 + i))); g.fillStyle = c.col; g.fillRect(-c.w / 2, -c.w / 4, c.w, c.w / 2); g.restore();
        }
    }

    // ---------------- lightning bolt (sky layer) ----------------
    const bolts = [];
    function drawBolts(dt) {
        const g = R.g;
        for (let i = bolts.length - 1; i >= 0; i--) {
            const b = bolts[i]; b.t += dt; if (b.t > 0.35) { bolts.splice(i, 1); continue; }
            const top = R.P(b.x, b.y, 9), bot = R.P(b.x, b.y, 0);
            g.save(); g.globalCompositeOperation = 'lighter'; g.strokeStyle = `rgba(230,240,255,${1 - b.t / 0.35})`; g.lineWidth = 3; g.lineJoin = 'round';
            g.beginPath(); g.moveTo(top[0], top[1]);
            for (let k = 1; k <= 8; k++) { const u = k / 8; g.lineTo(top[0] + (bot[0] - top[0]) * u + b.jag[k] * 24, top[1] + (bot[1] - top[1]) * u); }
            g.stroke(); g.lineWidth = 8; g.strokeStyle = `rgba(160,190,255,${0.35 * (1 - b.t / 0.35)})`; g.stroke(); g.restore();
        }
    }

    // ---------------- income pops (ambient) ----------------
    let popClock = 0;
    function incomePops(dt) {
        popClock += dt; if (popClock < 2.6) return; popClock = 0;
        if (quiet() || R.FXD.amount() === 0 || R.K < 30) return;
        const info = typeof GAME !== 'undefined' ? GAME.signInfo : null; if (!info) return;
        const cands = [];
        for (const k of R.builtCache()) {
            const p = PLOTS.get(k); const i = info.get(k); if (!i || !i.popCur) continue;
            const s = R.P(p.x0 + 2.5, p.y0 + 2.5, R.TOP); if (!R.onScreen(s[0], s[1], -40)) continue;
            cands.push([Math.hypot(s[0] - R.W / 2, s[1] - R.H / 2), p, i]);
        }
        cands.sort((a, b) => a[0] - b[0]);
        for (const [, p, i] of cands.slice(0, 4)) {
            const amount = calculateGainRate(i.popCur) * 2.6; if (!(amount > 0)) continue;
            const x = p.x0 + 1 + Math.random() * 3, y = p.y0 + 1 + Math.random() * 3;
            R.floatText(x, y, R.TOP + 1.1, '+' + formatNum(amount), curHex(i.popCur));
        }
    }

    // ---------------- portal ready pings (ambient) ----------------
    const readyState = new Map(); let readyClock = 0;
    function portalPings(dt) {
        readyClock += dt; if (readyClock < 0.5) return; readyClock = 0;
        if (quiet()) return;
        for (const n of TREE_NODES) {
            if (n.type !== 'reset' || !isNodeUnlocked(n) || !R.builtCache().has(plotKeyOf(n.coords[0], n.coords[1]))) continue;
            const ready = getEffectiveResetGain(n) > 0; const was = readyState.get(n.id);
            readyState.set(n.id, ready);
            if (ready && was === false) play('portalReady', { node: n });
        }
    }

    WORLD.use('update', (dt) => { updateDrones(dt); updateRockets(dt); incomePops(dt); portalPings(dt); });
    WORLD.use('afterItems', () => drawDrones());
    WORLD.use('sky', () => drawBolts(R.dt));
    WORLD.use('ui', () => drawConfetti(R.dt));
    WORLD.use('grow', (n) => play('grow', { node: n }));

    // ======================= CATALOG =======================
    def({
        id: 'buy', name: 'Brick snap (buy)', tier: 'support', category: 'Gameplay', trigger: 'Player buys levels on a machine',
        durationMs: 900, sound: 'buy (pitch climbs a semitone per quick buy)', haptic: 'buy',
        desc: 'The machine squashes and springs back, studs pop out in its currency colour, "+N LV" floats up, coins fly from the counter into it and the builder runs over to hammer.',
        spec: { squash: 'scale = 1 + 0.28 * e^(-7t) * sin(28t), t in s, 0.9 s', particles: '7 + min(10, levels) studs, speed 2.2 world u/s, up 2 to 4.5, gravity 9, life 0.9 to 1.4 s', text: '+N LV, Luckiest Guy 17 px, ink stroke 22%, rises 0.9 u/s, fades last 30%', coins: '4 coins, 0.7 s, smoothstep path with 80 px arc' },
        roblox: 'TweenService on a NumberValue driving the model scale (Enum.EasingStyle.Elastic, Out, 0.5 s). ParticleEmitter:Emit(8) with a stud decal, Speed 6 to 10, Acceleration (0,-40,0), Lifetime 0.8 to 1.2. BillboardGui TextLabel "+N LV" with UIStroke 3 px, tween Position up 2 studs and TextTransparency to 1. Coins: ImageLabels in a ScreenGui tweened from the counter to the machine screen point (WorldToViewportPoint).',
        run(c) {
            const n = c.node; const [x, y] = n.coords;
            R.nodeAnim.set(n.id, { t0: R.T, kind: 'buy' });
            R.burst(x, y, R.TOP + 0.7, curHex(n.costCurrency), 7 + Math.min(10, c.bought || 1));
            R.floatText(x, y, R.TOP + 1.3, `+${formatNum(c.bought || 1)} LV`, '#ffffff');
            R.sendBuilder(x, y);
            if (c.fromEl) { const r = c.fromEl.getBoundingClientRect(); const s = R.P(x, y, R.TOP + 0.6); R.fly(r.left + r.width / 2, r.top + r.height / 2, s[0], s[1], curHex(n.costCurrency), 4); }
            sfx('buy', x, y, { big: c.big }); haptic('buy');
        },
        fallback(c) { R.nodeAnim.set(c.node.id, { t0: R.T, kind: 'buy' }); },
    });
    def({
        id: 'grow', name: 'New brick lands', tier: 'support', category: 'Gameplay', trigger: 'A machine reaches its next brick (every quarter of its level cap)',
        durationMs: 500, sound: 'tick', haptic: 'none',
        desc: 'The new top brick drops in from above, lands with a dust ring and the machine squashes on impact.',
        spec: { drop: '1.2 world units in 0.18 s (linear), then the squash curve from Brick snap', dust: 'ring radius 0 to 0.9 u in 0.45 s, white 60%', bricks: '1 + floor(4 * (level/cap)^0.6), 5 at max' },
        roblox: 'Clone a brick Part above the model, tween CFrame down 0.18 s (Quad In), on arrival play a ring ParticleEmitter (Shape Disc, Speed 0, Size tween 0 to 3) and a short squash tween on the model.',
        run(c) { const [x, y] = c.node.coords; setTimeout(() => { R.ring(x, y, R.TOP + 0.02, '#ffffff', 0.9, 0.45); }, 180); sfx('tick', x, y, { vol: 0.5 }); },
    });
    def({
        id: 'maxed', name: 'Machine maxed', tier: 'support', category: 'Gameplay', trigger: 'A machine reaches its max level',
        durationMs: 1200, sound: 'maxed + stinger max', haptic: 'maxed',
        desc: 'A gold shockwave rings the machine, gold studs burst out, "MAXED!" pops above it and its top turns gold for good with a slow twinkle.',
        spec: { ring: 'gold #ffd23f, radius 0 to 1.8 u, 0.8 s, stroke 4 px fading', burst: '14 gold studs, speed 2.8', text: 'MAXED!, 26 px, 1.6 s', flash: 'screen tint rgba(255,230,120,0.18), 0.38 s, only if under 2 flashes this second', after: 'gold top and studs, twinkle sparkle every few seconds' },
        roblox: 'Gold Highlight (FillTransparency 1, OutlineColor gold) for 1 s, a Beam or ring ParticleEmitter for the shockwave, ParticleEmitter burst 14 gold studs, BillboardGui text pop (UIScale 0 to 1.2 to 1, Back easing). Swap the top brick Material to Neon or a gold colour permanently.',
        run(c) {
            const [x, y] = c.node.coords;
            R.ring(x, y, R.TOP + 0.05, '#ffd23f', 1.8, 0.8); R.burst(x, y, R.TOP + 0.9, '#ffd23f', 14, 2.8);
            R.floatText(x, y, R.TOP + 1.8, 'MAXED!', '#ffd23f', true);
            flash('rgba(255,230,120,0.18)');
            sfx('maxed', x, y); if (AUDIO.stinger) AUDIO.stinger('max'); haptic('maxed');
        },
    });
    def({
        id: 'autoBuy', name: 'Automation drone', tier: 'ambient', category: 'Gameplay', trigger: 'An automation rule buys a level for you',
        durationMs: 1700, sound: 'drone (quiet, 30% of buys)', haptic: 'none',
        desc: 'A small drone lifts off from the Robo Works machine that owns the rule, carries a brick in the currency colour to the target machine, drops it and flies on.',
        spec: { path: 'smoothstep from source to target, height 1.1 u plus a sine arc of 0.9 u, then drifts off 40% further in 0.8 s', budget: 'max 14 drones in the air, extra buys only puff', look: 'white body, two rotor blurs, red/green blinking light at 12 Hz, shadow on the ground' },
        roblox: 'Pool of 14 drone models. Tween along a Bezier (compute points per frame with RunService.Heartbeat), AlignPosition not needed. Attach a small PointLight at night. When the pool is empty, play only a puff ParticleEmitter on the target.',
        run(c) { if (drones.length < 14) launchDrone(c.node); else R.puff(c.node.coords[0], c.node.coords[1], R.TOP + 0.6, curHex(c.node.costCurrency || 'P')); },
    });
    def({
        id: 'reset', name: 'Rebuild (reset)', tier: 'hero', category: 'Gameplay', trigger: 'Player holds REBUILD on a portal',
        durationMs: 1600, sound: 'reset (whoosh, boom, rising chord) + crumble + stinger reset', haptic: 'big',
        desc: 'Everything the rebuild wipes crumbles into bricks that get sucked into the portal, the world freezes for a beat, then a shockwave and a burst in the new currency colour pay out.',
        spec: { hitstop: '90 ms at 4% speed', shake: 'camera kick 0.6, decays to 2% per second', crumble: '2 bricks per wiped machine (budget 50%), fly to the portal over 0.7 s', rings: 'currency colour radius 6 u 1.1 s, white 3.5 u 0.8 s', burst: '26 studs, speed 3.2', text: '+gain currency, 26 px, 1.6 s', flash: 'currency colour 28% alpha, limited', zoom: 'punch +6% zoom, eases back' },
        roblox: 'Sequence in a single coroutine: set workspace time scale feel with a 0.09 s pause on tweens, Camera shake via a spring on CFrame offset, crumble: clone bricks from each wiped model and tween them to the portal (Quad In), then a ring Beam and ParticleEmitter burst. ColorCorrection TintColor pulse to the currency colour and back over 0.4 s.',
        run(c) {
            const n = c.node; const [x, y] = n.coords; const col = curHex(n.targetCurrency);
            R.hitstop(90); R.FXD.shake(0.6); zoomPunch(0.06);
            let k = 0;
            for (const id of (c.resetIds || [])) {
                const m = NODE_MAP.get(id); if (!m || !R.builtCache().has(plotKeyOf(m.coords[0], m.coords[1]))) continue;
                R.nodeAnim.set(id, { t0: R.T + Math.random() * 0.3, kind: 'reset' }); R.lastCount.set(id, 0);
                if (Math.random() < 0.5 * R.FXD.amount() && k++ < 60) {
                    const dx = x - m.coords[0], dy = y - m.coords[1];
                    R.spawn({ x: m.coords[0], y: m.coords[1], z: R.TOP + 0.4, vx: dx / 0.7, vy: dy / 0.7, vz: 2.2, life: 0.7, col: curHex(m.costCurrency || 'P'), size: 0.09, grav: 6, brick: true });
                }
            }
            setTimeout(() => {
                R.ring(x, y, R.TOP + 0.1, col, 6, 1.1); R.ring(x, y, R.TOP + 0.1, '#ffffff', 3.5, 0.8);
                R.burst(x, y, R.TOP + 0.8, col, 26, 3.2);
                R.floatText(x, y, R.TOP + 2, `+${formatNum(c.gain)} ${curName(n.targetCurrency)}`, col, true);
                flash(hexA(col, 0.28));
            }, 650);
            sfx('reset', x, y); if (AUDIO.stinger) AUDIO.stinger('reset'); haptic('big');
        },
    });
    def({
        id: 'plotBuilt', name: 'New plot built', tier: 'hero', category: 'Gameplay', trigger: 'A plot is built (its baseplate would show in Upgrade Land)',
        durationMs: 2400, sound: 'rise, then a tick per tile climbing half a semitone each (12 over the plate), splash + plotBuilt fanfare on landing, stinger plot', haptic: 'big',
        desc: 'Cinema bars slide in and the camera flies to the plot. The island builds itself: 25 tiles fall from the sky in a spiral from the centre, each landing with a puff and a click that climbs in pitch. When the last tile lands the plate slams, a shockwave rolls out over the sea, the machines pop up one by one, fireworks go up (at night) and a NEW PLOT banner slams in.',
        spec: { letterbox: 'bars 9% of height, slide 0.35 s, hold 2.2 s', camera: 'fly to plot centre, exponential ease 4/s', tiles: '25 tiles, spiral order from the centre, 35 ms apart, fall 6 u with gravity 44 u/s2, 0.18 u bounce over 0.16 s', tileLanding: 'puff in the theme colour + tick at -3 + 0.5 semitones per tile (every tile on high, every 2nd on medium, none on low)', slam: 'after the last tile + 0.75 s: shake 0.8, hit-stop 80 ms, white ring 5 u + currency ring 3.5 u, 30 droplets', machines: 'pop in 60 ms steps, cubic overshoot to 1.1 then settle over 0.4 s', fireworks: '5 rockets at night, 26 sparks each', banner: 'NEW PLOT! 64 px + name 36 px, cubic-bezier(.2,1.6,.4,1) 0.5 s, out at 2.4 s', confetti: '70 pieces from the top of the screen' },
        roblox: 'Letterbox: two Frames tweened in from screen edges. Camera: CameraType Scriptable, tween CFrame to a preset angle over the plot, restore after. Tiles: the baseplate is 25 Parts; each starts 6 studs x 4 up, anchored, and a task.delay(i * 0.035) TweenService tween with Quad In easing drops it, then a short Back Out bounce; play a Sound with PlaybackSpeed 0.8 + i * 0.05 on each landing. On the last one: Camera shake module, a ring ParticleEmitter burst on the water, and a Scale tween (Back Out) on each machine model.',
        run(c) {
            const p = c.plot; const cx = p.x0 + 2.5, cy = p.y0 + 2.5;
            R.plotAnim.set(p.key, { t0: R.T, delay: c.delay || 0, fx: true }); R.textureFor(p); R.refreshBuilt(); R.computeBounds(); R.syncFigs();
            if (c.focus !== false) { R.cam.tx = cx; R.cam.ty = cy; }
            letterbox(2300); zoomPunch(0.05);
            sfx('rise', cx, cy);
            if (R.env.night > 0.35) setTimeout(() => launchFireworks(cx, cy, 5), 1800);
            setTimeout(() => throwConfetti(70), 1300);
            sfx('plotBuilt', cx, cy); if (AUDIO.stinger) AUDIO.stinger('plot'); haptic('big');
        },
    });
    // Each tile of an assembling plate lands: a puff of theme dust and a click that climbs in pitch.
    // Clicks are rate limited so many plates assembling at once (the intro) stay a rattle, not a roar.
    let lastTick = 0, lastSlam = 0;
    WORLD.use('tile', (p, o) => {
        const th = R.THEMES[p.theme] || R.THEMES.meadow;
        const x = p.x0 + o.i + 0.5, y = p.y0 + o.j + 0.5;
        if (R.FXD.amount() > 0.3 && (!o.quiet || o.k % 4 === 0)) { R.puff(x, y, R.TOP, th.alt); if (o.k % 3 === 0) R.burst(x, y, R.TOP + 0.05, th.base, 3, 1.2); }
        const every = R.Q.name === 'low' ? 0 : R.Q.name === 'medium' ? 2 : 1, now = performance.now();
        if (every && o.k % every === 0 && !quiet() && now - lastTick > 28) { lastTick = now; sfx('tick', x, y, { vol: o.quiet ? 0.25 : 0.45, pitch: -3 + o.k * 0.5 }); }
    });
    // The whole plate has landed: the slam. Quiet plates (the intro ripple) get a ring and a small splash.
    WORLD.use('assembled', (p, an) => {
        const cx = p.x0 + 2.5, cy = p.y0 + 2.5;
        if (quiet()) return;
        const now = performance.now();
        if (an && an.quiet || now - lastSlam < 350) { R.ring(cx, cy, 0.05, '#ffffff', 4, 0.8); if (now - lastSlam > 120) { lastSlam = now; sfx('splash', cx, cy, { vol: 0.35 }); } return; }
        lastSlam = now;
        R.FXD.shake(0.8); R.hitstop(80);
        R.ring(cx, cy, 0.05, '#ffffff', 5, 1); R.ring(cx, cy, 0.06, p.color || '#ffd23f', 3.5, 0.8);
        for (let i = 0; i < 30 * R.FXD.amount(); i++) R.spawn({ x: cx + (Math.random() - 0.5) * 5.4, y: cy + (Math.random() - 0.5) * 5.4, z: 0.1, vx: (Math.random() - 0.5), vy: (Math.random() - 0.5), vz: 2 + Math.random() * 3, life: 0.9, col: '#d9f4ff', size: 0.06, grav: 9 });
        sfx('splash', cx, cy); sfx('buy', cx, cy, { big: true });
        haptic('big');
    });
    def({
        id: 'maxPlot', name: 'Plot maxed (dev)', tier: 'support', category: 'Gameplay', trigger: 'MAX NEXT PLOT in the dev bar',
        durationMs: 1800, sound: 'buy x every 4th machine, maxed', haptic: 'maxed',
        desc: 'Machines pop one after another in 45 ms steps with small stud bursts, like a wave of purchases rolling across the plot.',
        spec: { stagger: '45 ms per machine, max 40', burst: '4 studs each, speed 1.8' },
        roblox: 'task.delay per machine with 0.045 s steps; reuse the Brick snap tween and a 4 particle burst.',
        run(c) {
            const list = (c.nodes || []).slice(0, 40);
            list.forEach((n, i) => setTimeout(() => { R.nodeAnim.set(n.id, { t0: R.T, kind: 'buy' }); if (R.FXD.amount() > 0) R.burst(n.coords[0], n.coords[1], R.TOP + 0.7, curHex(n.costCurrency), 4, 1.8); if (i % 4 === 0) sfx('buy', n.coords[0], n.coords[1], { big: true }); }, i * 45));
            if (list.length) { const n = list[list.length - 1]; R.sendBuilder(n.coords[0], n.coords[1]); }
            sfx('maxed'); haptic('maxed');
        },
    });
    def({
        id: 'portalReady', name: 'Portal ready ping', tier: 'ambient', category: 'Gameplay', trigger: 'A rebuild portal starts paying more than 0',
        durationMs: 800, sound: 'tick', haptic: 'none',
        desc: 'A soft ring pulses out of the portal once, and from then on its spiral spins faster and brighter with motes falling inward.',
        spec: { ring: 'currency colour, radius 1.4 u, 0.8 s', spiral: '3 arms, 14 segments, spin 0.8 rad/s idle, 3 rad/s ready', motes: '6 motes spiralling inward at 0.8 turns/s' },
        roblox: 'Portal: a Beam spiral (CurveSize) on rotating Attachments, speed driven by a NumberValue; one ring ParticleEmitter burst when it becomes ready.',
        run(c) { const [x, y] = c.node.coords; R.ring(x, y, R.TOP + 0.44, curHex(c.node.targetCurrency), 1.4, 0.8); sfx('tick', x, y, { vol: 0.4 }); },
    });
    def({
        id: 'newCurrency', name: 'New currency found', tier: 'support', category: 'Gameplay', trigger: 'A currency is discovered for the first time',
        durationMs: 1000, sound: 'coin', haptic: 'buy',
        desc: 'A column of light rises from the focused plot and a ring of coins in the new colour spins out; the HUD toast names it.',
        spec: { beam: 'light column 3 u tall, 0.9 s fade', coins: '12 studs in a ring, speed 2' },
        roblox: 'A Beam from a ground Attachment to one 20 studs up with LightEmission 1, tween Transparency to 1. ParticleEmitter burst of 12 coins with SpreadAngle 360 on the horizontal plane.',
        run(c) {
            const [x, y] = here(c); const col = curHex(c.key || 'P');
            for (let i = 0; i < 12 * R.FXD.amount(); i++) { const a = i / 12 * 6.283; R.spawn({ x, y, z: R.TOP + 0.4, vx: Math.cos(a) * 2, vy: Math.sin(a) * 2, vz: 2.6, life: 1, col, size: 0.08, grav: 7 }); }
            for (let i = 0; i < 10; i++) R.spawn({ x: x + (Math.random() - 0.5) * 0.3, y: y + (Math.random() - 0.5) * 0.3, z: R.TOP + i * 0.3, vx: 0, vy: 0, vz: 1.4, life: 0.9, col, size: 0.09, grav: 0, add: true, fade: true, stud: false });
            sfx('coin', x, y);
        },
    });
    def({
        id: 'codeFound', name: 'Hidden code brick found', tier: 'support', category: 'Gameplay', trigger: 'Tapping or walking into a hidden golden code brick',
        durationMs: 1200, sound: 'codeFound + stinger code', haptic: 'maxed',
        desc: 'The golden brick bursts into sparkles, its letter floats up big, and the letter flies into the CODES tile.',
        spec: { burst: '18 gold sparkles + 10 studs', text: 'the letter, 26 px gold, 1.6 s', flight: 'one coin to the CODES tile, 0.7 s' },
        roblox: 'ProximityPrompt or Touched on the brick, then ParticleEmitter burst (Sparkles texture), a BillboardGui letter pop and a ScreenGui ImageLabel tweened to the codes button.',
        run(c) {
            const [x, y] = here(c);
            for (let i = 0; i < 18 * Math.max(0.4, R.FXD.amount()); i++) R.spawn({ x, y, z: R.TOP + 0.3, vx: (Math.random() - 0.5) * 3, vy: (Math.random() - 0.5) * 3, vz: 1 + Math.random() * 3, life: 0.9, col: '#fff1a0', size: 0.1, grav: 3, twinkle: true, stud: false });
            R.burst(x, y, R.TOP + 0.3, '#ffd23f', 10, 2.4);
            R.floatText(x, y, R.TOP + 1.2, c.letter || '?', '#ffd23f', true);
            const tile = document.getElementById('tCodes');
            if (tile) { const r = tile.getBoundingClientRect(); const s = R.P(x, y, R.TOP + 0.5); R.fly(s[0], s[1], r.left + r.width / 2, r.top + r.height / 2, '#ffd23f', 1); }
            sfx('codeFound', x, y); if (AUDIO.stinger) AUDIO.stinger('code'); haptic('maxed');
        },
    });
    def({
        id: 'achievement', name: 'Badge unlocked', tier: 'support', category: 'UI', trigger: 'An achievement condition becomes true',
        durationMs: 2600, sound: 'achievement + stinger achievement', haptic: 'maxed',
        desc: 'Confetti falls from the top of the screen while the badge card slides down, tilts in with a bounce and rests for 2.6 s.',
        spec: { card: 'slide from -120 px, cubic-bezier(.2,1.6,.4,1) 0.5 s, rotate -4 deg to 0', confetti: '50 pieces, flutter scaleY by |sin(6t)|' },
        roblox: 'ScreenGui Frame with UIScale and Rotation tweened (Back, Out). Confetti: ImageLabels spawned at the top with random velocity, updated on RenderStepped, destroyed off screen.',
        run(c) { throwConfetti(50); sfx('achievement'); if (AUDIO.stinger) AUDIO.stinger('achievement'); haptic('maxed'); },
    });
    def({
        id: 'incomePop', name: 'Income pops', tier: 'ambient', category: 'Gameplay', trigger: 'Every 2.6 s for up to 4 built plots nearest the middle of the screen',
        durationMs: 1100, sound: 'none', haptic: 'none',
        desc: 'Small "+amount" numbers in the plot currency colour float up from the islands, so production is visible without reading the HUD.',
        spec: { text: '17 px, currency colour, ink stroke, rises 0.9 u/s, 1.1 s', amount: 'rate x 2.6 s of the plot headline currency', budget: '4 per wave, skipped at x10 speed and in sims' },
        roblox: 'BillboardGui pooled per plot (AlwaysOnTop false, MaxDistance 200), tween StudsOffset up and TextTransparency.',
        run(c) { const [x, y] = here(c); R.floatText(x, y, R.TOP + 1.1, '+' + formatNum(c.amount || 1234), curHex(c.key || 'P')); },
    });
    def({
        id: 'fireworks', name: 'Fireworks', tier: 'support', category: 'World', trigger: 'New plot at night, or on demand',
        durationMs: 2500, sound: 'fireworks per burst', haptic: 'none',
        desc: 'Rockets climb with a spark trail and burst into rings of coloured sparks that fall slowly.',
        spec: { rockets: '5, 0.28 s apart, launch speed 5.2 to 6.8 u/s, gravity 4.2', burst: '26 sparks at apex, speed 2.2, gravity 1.6, additive, 1.1 s', trail: 'spark every frame with 60% chance, 0.35 s' },
        roblox: 'Rocket Part with a Trail, burst via ParticleEmitter (LightEmission 1, Drag 2, Acceleration down 5). PointLight flash on burst at night.',
        run(c) { const [x, y] = here(c); launchFireworks(x, y, c.n || 5); },
    });
    def({
        id: 'lightning', name: 'Lightning strike', tier: 'support', category: 'Weather', trigger: 'Random during storms (every 6 to 18 s)',
        durationMs: 400, sound: 'lightning crack, then thunder after 0.3 to 1.8 s by distance', haptic: 'none',
        desc: 'A jagged white bolt hits the sea, the screen flashes blue-white (never more than twice a second) and thunder rolls after a delay.',
        spec: { bolt: '8 segments with random 24 px jag, 0.35 s fade, additive with 8 px blue glow', flash: 'rgba(200,220,255,0.35), limited', thunder: 'delay 0.3 s + distance x 1.5 s' },
        roblox: 'Neon Part segments or a Beam with a lightning texture, 0.1 s visible. Lighting.Brightness spike tween 0.2 s. Thunder Sound with delay by distance. Respect a reduced flashing setting.',
        run(c) {
            const [x, y] = c.x !== undefined ? [c.x, c.y] : (() => { const b = R.worldBounds; return [b.x0 - 2 + Math.random() * (b.x1 - b.x0 + 4), b.y0 - 2 + Math.random() * (b.y1 - b.y0 + 4)]; })();
            bolts.push({ x, y, t: 0, jag: Array.from({ length: 9 }, (_, i) => i === 0 || i === 8 ? 0 : (Math.random() - 0.5)) });
            flash('rgba(200,220,255,0.35)');
            sfx('lightning', x, y); const d = Math.random();
            setTimeout(() => { if (AUDIO.thunder) AUDIO.thunder(d); }, 300 + d * 1500);
        },
    });
    def({
        id: 'splash', name: 'Water splash', tier: 'support', category: 'World', trigger: 'Island lands, whale dives, avatar jumps in the shallows',
        durationMs: 900, sound: 'splash', haptic: 'none',
        desc: 'A white ring spreads on the water and droplets jump up and fall back.',
        spec: { ring: 'white, radius 2 u, 0.7 s', droplets: '16, up 2 to 5 u/s, gravity 9, light blue' },
        roblox: 'ParticleEmitter on a water-level Attachment (Shape Disc for the ring, droplets with Acceleration down), Sound splash.',
        run(c) { const [x, y] = here(c); R.ring(x, y, 0.02, '#ffffff', 2, 0.7); for (let i = 0; i < 16 * R.FXD.amount(); i++) R.spawn({ x: x + (Math.random() - 0.5), y: y + (Math.random() - 0.5), z: 0.05, vx: (Math.random() - 0.5), vy: (Math.random() - 0.5), vz: 2 + Math.random() * 3, life: 0.9, col: '#d9f4ff', size: 0.06, grav: 9 }); sfx('splash', x, y); },
    });
    def({
        id: 'confetti', name: 'Screen confetti', tier: 'support', category: 'UI', trigger: 'New plot, badges',
        durationMs: 3500, sound: 'none', haptic: 'none',
        desc: 'Paper rectangles fall from the top of the screen, fluttering by squashing on one axis.',
        spec: { pieces: '70 (scaled by effects setting)', motion: 'vy 80 to 240 px/s, sideways sway 40 px/s at 4 Hz, spin up to 5 rad/s' },
        roblox: 'Pooled ImageLabels in a ScreenGui, updated on RenderStepped; flutter by tweening Size.Y between 0.1 and 1.',
        run() { throwConfetti(70); },
    });
    def({
        id: 'shockwave', name: 'Shockwave ring', tier: 'support', category: 'World', trigger: 'Used inside Rebuild, Maxed and Plot built',
        durationMs: 800, sound: 'none', haptic: 'none',
        desc: 'A flat ellipse on the ground grows from nothing and thins out.',
        spec: { ring: 'radius r1 x t, stroke max(1.5, 4 x zoom x (1 - t)), alpha 1 - t' },
        roblox: 'A thin cylinder MeshPart or a Beam loop, tween Size up and Transparency to 1.',
        run(c) { const [x, y] = here(c); R.ring(x, y, R.TOP + 0.05, '#ffffff', 3, 0.8); },
    });
    // Ambient entries document what the world does on its own; the Lab can force one.
    const ambient = (id, name, trigger, desc, spec, roblox, run) => def({ id, name, tier: 'ambient', category: 'World', trigger, durationMs: 0, sound: '-', haptic: 'none', desc, spec, roblox, run: run || (() => { }) });
    ambient('themeParticles', 'Plot ambience particles', 'Always, per plot theme, about 3 per second per visible plot', 'Embers rise over lava and the Red canyon, sparks jump at the battery farm, petals drift on meadows, bubbles pop at the water edge of beach plots, gems twinkle.',
        { kinds: 'ember, spark, mote, twinkle, dust, petal, bubble', budget: 'rate x effects amount, skipped below zoom 0.35' }, 'One ParticleEmitter per plot with Rate 2 to 4, texture per theme, LightEmission 1 for embers and motes, disabled when the plot is off screen (use a distance check).');
    ambient('hologram', 'Blueprint holograms', 'Machines you can see but have not bought', 'A translucent blue box bobs gently with a white + above it.', { bob: '0.03 u at 2.4 rad/s', alpha: '35% fill, light blue ink' }, 'ForceField material or Glass with Transparency 0.6, a SelectionBox, BillboardGui "+" and a sine bob on the pivot.');
    ambient('bestBuy', 'Best buy arrow', 'The cheapest affordable machine (share of wallet) on the focused plot', 'A yellow arrow bounces over it; other affordable machines on that plot get a small green one.', { bounce: '|sin(5t)| x 8 px', size: '1.2x for best, 0.7x for others' }, 'BillboardGui ImageLabel arrow with a bounce tween, only one "best" at a time.');
    ambient('drones', 'Drones in the air', 'Automation', 'See Automation drone.', {}, 'See autoBuy.');
    ambient('whale', 'Whale', 'Every 150 to 300 s, off the island edge', 'A whale back rises from the sea, spouts studs and dives.', { rise: '7 s sine arc', spout: 'studs, 60% chance per frame between 1.5 and 4.5 s' }, 'Animated MeshPart moved on a sine, ParticleEmitter spout, Sound.');
    ambient('boat', 'Boat and wake', 'Always', 'A little sailboat circles the whole archipelago leaving a V wake.', { speed: '0.8 u/s around the bounds + 1.4 u' }, 'Model on a path with TweenService or PathfindingService-free waypoints, a Trail for the wake.');
    ambient('lighthouse', 'Lighthouse beam', 'At night', 'A beam sweeps the sea from the lighthouse off Stud Square.', { sweep: '0.9 rad/s, length 9 u, spread 0.12 rad, additive' }, 'SpotLight in the lamp room rotating with a Motor6D or CFrame tween, plus a Beam with LightEmission.');
    ambient('fireflies', 'Fireflies', 'At night', 'Yellow-green dots wander over each built plot and pulse.', { count: '3 per plot, first 15 plots' }, 'ParticleEmitter with LightEmission 1, Rate 3, Speed 0.2, Lifetime 4, only at night (ClockTime check).');
    ambient('caustics', 'Water caustics', 'Daytime, high quality', 'A tiling light pattern drifts on the sea in two layers.', { tile: '256 px, 38 bright curves', layers: '2, drifting opposite, 7% additive' }, 'A water Texture with animated OffsetStudsU/V on two SurfaceAppearance or Texture layers, or Terrain water with WaterWaveSize.');
    ambient('shadows', 'Sun shadows', 'Always (quality medium and up)', 'Every machine throws a shadow that swings and stretches with the sun, long at dawn and dusk, faint moon shadows at night.', { length: 'min(2.4, 0.55 / tan(elevation x 1.2))', alpha: '20% day, 7% x night' }, 'Lighting.ClockTime drives real shadows in Roblox (Lighting.GlobalShadows, ShadowSoftness 0.2). Future lighting on high-end, ShadowMap elsewhere.');

    // ---------------- UI motion catalog (demoed in the FX Lab) ----------------
    const UI_MOTION = [
        { id: 'uiPress', name: 'Button press', spec: 'translateY(3px), drop shadow 3px to 0, 60 ms', roblox: 'On MouseButton1Down tween Position +3 px and UIStroke/shadow Frame offset to 0 (0.06 s, Quad Out); reverse on up.' },
        { id: 'uiPanel', name: 'Panel open', spec: 'scale 0.94 to 1 and opacity 0 to 1, 200 ms ease-out', roblox: 'UIScale 0.94 to 1 + CanvasGroup GroupTransparency 1 to 0, TweenInfo 0.2 Quad Out.' },
        { id: 'uiSheet', name: 'Machine card slide', spec: 'desktop slides 16 px from the right, phone rises 16 px from the bottom, 180 ms', roblox: 'Tween Position offset, 0.18 s Quad Out.' },
        { id: 'uiToast', name: 'Toast', spec: 'in: 10 px drop + fade 220 ms, out after 2.6 s: 8 px up + fade 300 ms; max 4 stacked', roblox: 'UIListLayout container; tween each toast in and out, destroy after.' },
        { id: 'uiBanner', name: 'Big banner', spec: 'scale 0.3 to 1 with -6 deg to 0, cubic-bezier(.2,1.6,.4,1) 500 ms, second line 120 ms later, out 400 ms', roblox: 'UIScale with EasingStyle.Back Out (overshoot), Rotation tween; second label delayed 0.12 s.' },
        { id: 'uiBadge', name: 'Badge pulse', spec: 'scale 1 to 1.18 to 1 in the last 20% of a 1.6 s loop', roblox: 'Looping tween with DelayTime, or a Heartbeat sine gated to one pulse per 1.6 s.' },
        { id: 'uiHold', name: 'Hold to confirm', spec: 'white fill grows 0 to 100% width over 700 ms (1200 ms to wipe); release cancels', roblox: 'Frame Size tween on InputBegan, cancel on InputEnded; fire at completion.' },
        { id: 'uiTicker', name: 'Counter ticker', spec: 'shown value eases 25% of the gap per frame toward the real value; drops snap instantly', roblox: 'Heartbeat lerp of a displayed number, format each frame; snap on spend.' },
        { id: 'uiRate', name: 'Rate pill bump', spec: 'when the rate rises, scale 1.15 and back in 250 ms, green flash', roblox: 'UIScale tween Back Out 0.25 s when the rate goes up.' },
    ];
    return { play, def, CATALOG, byId, UI_MOTION, sfx, haptic, launchFireworks, throwConfetti, drones, letterbox, flash };
})();
