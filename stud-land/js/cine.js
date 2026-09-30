// Stud City Incremental cinematics. Two scripted camera pieces, both pure presentation:
//   intro  the first time you press play: you dive through clouds, the city builds itself tile by tile
//          around Stud Square, the builder parachutes in, and the HUD slams into place.
//   tour   photo mode: the camera flies a path over every plot you have built with a location card.
// Nothing here reads or writes game math. Timings live in SPEC so the FX Lab and the Roblox build
// use the same numbers.
const CINE = (() => {
    const R = WORLD.R;
    const $ = (id) => document.getElementById(id);
    const S = { on: null, t0: 0, fresh: false, beam: null, capAt: {}, shots: [], last: -1 };
    const SPEC = {
        cloudsPart: '0.5 s to 2.7 s, 34 cloud cards pushed out from the centre and scaled 1 to 1.7, alpha fades over the last 30%',
        camera: '6.2 s, zoom 0.2 to 1.12 x default, angle -1.25 rad to 0, 7 u sideways to the plot, ease in-out cubic, then settles to default zoom in 0.3 s',
        city: 'Stud Square tiles start at 2.3 s; every other built plot starts 0.32 s later per plot of distance (a ripple)',
        builder: 'parachute from 8 u, falls 1.25 u/s, sways 0.15 u/s, lands at about 6.4 s',
        beam: 'blueprint column 6 u tall over the first machine from 4.3 s until it is bought or 12 s after the HUD lands',
        hud: 'on landing + 0.25 s: hero drops from above, tiles slide in from the right 70 ms apart, zone bar rises, dock slides in, 0.5 s each with overshoot',
        caption: '"SOMEWHERE IN THE BRICK SEA" 0.5 s to 2.6 s, then "WELCOME TO / STUD CITY" 4.2 s to 6.4 s',
        tour: '3.6 s per plot: 1.3 s smoothstep flight, then a slow push in (0.95 to 1.2 x) while the camera orbits at 0.1 rad/s',
    };
    const ease = (k) => k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
    const smooth = (k) => k * k * (3 - 2 * k);
    const clamp01 = (x) => Math.max(0, Math.min(1, x));
    const dz = () => (typeof defaultZoom === 'function' ? defaultZoom() : 1);

    // ---------- caption card ----------
    function caption(kicker, title) {
        const c = $('cineCap'); if (!c) return;
        if (!kicker && !title) { c.classList.remove('on'); return; }
        c.querySelector('.ck').textContent = kicker || ''; c.querySelector('.ct').textContent = title || '';
        c.classList.toggle('no-title', !title);
        c.classList.remove('on'); void c.offsetWidth; c.classList.add('on');
    }

    // ---------- cloud cards ----------
    // Pre-rendered once: puffy clouds with a chunky ink rim and a cool underside, like the UI panels.
    let sprites = null; const cards = [];
    function makeClouds() {
        if (sprites) return;
        let seed = 7; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
        // four shapes, each in a near (white) and a far (cooler, darker) tone for depth
        const shapes = [0, 1, 2, 3].map(() => {
            const blobs = []; const n = 6 + ((rnd() * 3) | 0);
            for (let i = 0; i < n; i++) { const u = i / (n - 1); blobs.push([100 + u * 320, 200 - Math.sin(u * Math.PI) * (40 + rnd() * 50), 44 + Math.sin(u * Math.PI) * 46 + rnd() * 16]); }
            blobs.push([260, 200, 96], [180, 210, 70], [340, 210, 70]);
            return blobs;
        });
        const paint = (blobs, far) => {
            const c = document.createElement('canvas'); c.width = 520; c.height = 340; const t = c.getContext('2d');
            const all = (fn) => { t.beginPath(); for (const [x, y, r] of blobs) { t.moveTo(x + r, y); t.arc(x, y, r, 0, 7); } fn(); };
            t.strokeStyle = far ? '#3b4f7a' : '#1b1530'; t.lineWidth = 10; t.lineJoin = 'round'; all(() => t.stroke());
            const gr = t.createLinearGradient(0, 70, 0, 310);
            gr.addColorStop(0, far ? '#e9f1fa' : '#ffffff'); gr.addColorStop(0.55, far ? '#d2e1f1' : '#f4f8fc'); gr.addColorStop(1, far ? '#9fb9d8' : '#bcd3ea');
            t.fillStyle = gr; all(() => t.fill());
            t.fillStyle = far ? 'rgba(255,255,255,0.55)' : 'rgba(255,255,255,0.9)';
            for (const [x, y, r] of blobs.slice(0, -3)) { t.beginPath(); t.ellipse(x - r * 0.25, y - r * 0.35, r * 0.35, r * 0.18, -0.4, 0, 7); t.fill(); }
            return c;
        };
        sprites = shapes.map(b => paint(b, false)).concat(shapes.map(b => paint(b, true)));
        for (let i = 0; i < 34; i++) { const a = i * 2.39996, r = 0.08 + Math.sqrt(i / 34) * 0.78; cards.push({ x: Math.cos(a) * r, y: Math.sin(a) * r * 0.85, s: 0.9 + ((i * 7) % 5) * 0.14, v: (i % 4) + (i % 2 ? 4 : 0), flip: i % 3 === 0 }); }
        cards.sort((a, b) => (b.v >= 4) - (a.v >= 4) || a.y - b.y); // far tone first
    }
    function drawClouds(t) {
        const g = R.g, W = R.W, H = R.H;
        const k = ease(clamp01((t - 0.5) / 2.2));
        if (k >= 1) return;
        // white-out at the very start hides the empty sea before the city exists
        const haze = 1 - clamp01((t - 0.2) / 1.2);
        if (haze > 0) { const hg = g.createLinearGradient(0, 0, 0, H); hg.addColorStop(0, `rgba(120,200,235,${haze})`); hg.addColorStop(1, `rgba(190,232,248,${haze})`); g.fillStyle = hg; g.fillRect(0, 0, W, H); }
        const L = Math.max(W, H);
        g.save();
        for (const c of cards) {
            const push = 1 + k * 2.4, sc = c.s * (1 + k * 0.7) * L / 900;
            const x = W / 2 + c.x * W * 0.62 * push, y = H / 2 + c.y * H * 0.7 * push + k * 40;
            const a = k > 0.7 ? 1 - (k - 0.7) / 0.3 : 1; if (a <= 0) continue;
            g.globalAlpha = a; const sp = sprites[c.v], w = sp.width * sc, h = sp.height * sc;
            if (c.flip) { g.save(); g.translate(x, y); g.scale(-1, 1); g.drawImage(sp, -w / 2, -h / 2, w, h); g.restore(); }
            else g.drawImage(sp, x - w / 2, y - h / 2, w, h);
        }
        g.restore();
    }

    // ---------- blueprint beam ----------
    function drawBeam() {
        const b = S.beam; if (!b) return;
        const n = b.node, t = R.T - b.t0;
        if (t < 0) return;
        if (R.T > b.until || (typeof getLevel === 'function' && getLevel(n.id) > 0)) { S.beam = null; return; }
        const g = R.g, K = R.K, [x, y] = n.coords;
        const a = Math.min(1, t / 0.4) * (R.T > b.until - 1 ? b.until - R.T : 1);
        const base = R.P(x, y, R.TOP), top = R.P(x, y, R.TOP + 6);
        const w = 0.42 * K;
        g.save(); g.globalCompositeOperation = 'lighter';
        const gr = g.createLinearGradient(0, top[1], 0, base[1]);
        gr.addColorStop(0, 'rgba(74,168,255,0)'); gr.addColorStop(0.7, `rgba(74,168,255,${0.28 * a})`); gr.addColorStop(1, `rgba(170,215,255,${0.55 * a})`);
        g.fillStyle = gr; g.fillRect(base[0] - w / 2, top[1], w, base[1] - top[1]);
        g.fillStyle = `rgba(255,255,255,${0.35 * a})`; g.fillRect(base[0] - w * 0.12, top[1], w * 0.24, base[1] - top[1]);
        // rising grid ticks inside the column
        g.strokeStyle = `rgba(200,230,255,${0.6 * a})`; g.lineWidth = Math.max(1, R.cam.zoom * 1.5);
        for (let i = 0; i < 6; i++) { const u = ((t * 0.5 + i / 6) % 1); const yy = base[1] - u * (base[1] - top[1]); g.globalAlpha = (1 - u); g.beginPath(); g.moveTo(base[0] - w / 2, yy); g.lineTo(base[0] + w / 2, yy); g.stroke(); }
        g.globalAlpha = 1;
        // ground ring pulses
        for (let i = 0; i < 2; i++) { const u = (t * 0.8 + i * 0.5) % 1; g.strokeStyle = `rgba(120,190,255,${(1 - u) * 0.8 * a})`; g.lineWidth = Math.max(1.5, 3 * R.cam.zoom); g.beginPath(); g.ellipse(base[0], base[1], (0.3 + u * 0.9) * K, (0.3 + u * 0.9) * K * R.SQ, 0, 0, 7); g.stroke(); }
        g.restore();
    }
    function beamOn(node, delay, holdFor) { if (!node) return; S.beam = { node, t0: R.T + delay, until: R.T + delay + holdFor }; }
    function firstMachine(p) {
        const ups = p.nodes.filter(n => n.type === 'upgrade' && isNodeUnlocked(n));
        return ups.find(n => canAfford(n)) || ups[0] || null;
    }

    // ---------- intro ----------
    function intro(opts = {}) {
        if (S.on) stop();
        const home = PLOTS.get('0,0'); const cx = home.x0 + 2.5, cy = home.y0 + 2.5;
        if (R.DIRECTOR.mode === 'minimal') { hudIn(true); return; }
        makeClouds();
        S.on = 'intro'; R.view.signs = false; S.t0 = R.T; S.fresh = !!opts.fresh; S.capAt = {}; S.landed = false;
        document.body.classList.add('intro'); document.body.classList.remove('hud-in');
        $('letterbox') && $('letterbox').classList.add('on');
        // the camera starts high above, turned and off to the side
        const cam = R.cam; const z1 = dz();
        S.cam = { x0: cx + 4.5, y0: cy - 6.5, x1: cx, y1: cy, z0: 0.2, z1: z1 * 1.12, a0: -1.25, a1: 0 };
        cam.tx = cam.ty = null;
        // every built plot rebuilds itself, rippling out from Stud Square
        for (const k of R.builtCache()) {
            const p = PLOTS.get(k); const d = Math.hypot(p.x0 - home.x0, p.y0 - home.y0) / 5;
            R.plotAnim.set(k, { t0: R.T, delay: 2.3 + d * 0.32, quiet: k !== '0,0', intro: true });
        }
        // the builder parachutes down from above the clouds, onto a free cell near the centre
        const fc = R.freeCells(home).slice().sort((a, b) => Math.hypot(a[0] - cx - 1, a[1] - cy - 1) - Math.hypot(b[0] - cx - 1, b[1] - cy - 1))[0] || [cx + 1, cy + 1];
        const B = R.builder; B.x = B.tx = fc[0]; B.y = B.ty = fc[1]; B.chute = true; B.hop = 8;
        S.beam = null;
        if (S.fresh) beamOn(firstMachine(home), 4.3, 30);
        FX.sfx('camWhoosh');
        if (typeof AUDIO !== 'undefined' && AUDIO.stinger) setTimeout(() => S.on === 'intro' && AUDIO.stinger('plot'), 3900);
        const sk = $('cineSkip'); if (sk) { sk.classList.add('on'); sk.onclick = () => skip(); }
    }
    function updateIntro() {
        const t = R.T - S.t0, cam = R.cam, c = S.cam;
        if (!S.landed) {
            const k = ease(clamp01((t - 0.3) / 6.2));
            cam.x = c.x0 + (c.x1 - c.x0) * k; cam.y = c.y0 + (c.y1 - c.y0) * k;
            cam.zoom = cam.tZoom = c.z0 + (c.z1 - c.z0) * k;
            cam.angle = cam.tAngle = c.a0 + (c.a1 - c.a0) * k;
        }
        if (t > 0.5 && !S.capAt.a) { S.capAt.a = 1; caption('SOMEWHERE IN THE BRICK SEA', ''); }
        if (t > 2.6 && !S.capAt.b) { S.capAt.b = 1; caption('', ''); }
        if (t > 4.2 && !S.capAt.c) { S.capAt.c = 1; caption(S.fresh ? 'WELCOME TO' : 'WELCOME BACK TO', tierName()); }
        // safety: if the builder never lands (hit-stop storms, tab in background) finish anyway
        if (t > 9 && !S.landed) landed();
    }
    function tierName() { return typeof CITY !== 'undefined' && CITY.tier ? CITY.tier().title : 'STUD CITY'; }
    function landed() {
        if (S.on !== 'intro' || S.landed) return;
        S.landed = true; const B = R.builder;
        B.chute = false; B.hop = 0;
        R.ring(B.x, B.y, R.TOP + 0.02, '#ffffff', 1.1, 0.6); R.burst(B.x, B.y, R.TOP + 0.1, '#e8453c', 8, 1.6);
        FX.sfx('buy', B.x, B.y, { big: true }); FX.haptic('buy');
        R.cam.tZoom = dz();
        setTimeout(() => { caption('', ''); hudIn(false); }, 250);
    }
    function hudIn(instant) {
        const b = document.body;
        b.classList.remove('intro');
        $('letterbox') && $('letterbox').classList.remove('on');
        const sk = $('cineSkip'); if (sk) sk.classList.remove('on');
        if (!instant) {
            b.classList.add('hud-in');
            [0, 90, 180, 270, 360].forEach((d, i) => setTimeout(() => FX.sfx('tick', undefined, undefined, { vol: 0.5, pitch: 0.9 + i * 0.12 }), d));
            setTimeout(() => FX.sfx('camWhoosh', undefined, undefined, { vol: 0.5 }), 60);
            setTimeout(() => b.classList.remove('hud-in'), 1500);
        }
        const fresh = S.fresh;
        S.on = null; R.view.signs = true;
        try { META.state().introSeen = true; } catch (e) { }
        setTimeout(() => {
            const gd = $('guide'); if (gd) { gd.classList.remove('pulse'); void gd.offsetWidth; gd.classList.add('pulse'); }
            if (fresh && typeof HUD !== 'undefined') HUD.toast('Tap the glowing blueprint to build your first machine!', '#fff3b0');
        }, instant ? 300 : 900);
    }
    function skip() {
        if (S.on !== 'intro') return;
        for (const [k, an] of [...R.plotAnim.entries()]) if (an.intro) R.plotAnim.delete(k);
        const B = R.builder; B.chute = false; B.hop = 0;
        const c = S.cam; R.cam.x = c.x1; R.cam.y = c.y1; R.cam.angle = R.cam.tAngle = 0; R.cam.zoom = R.cam.tZoom = dz();
        caption('', '');
        S.landed = true; hudIn(true);
        if (S.fresh) beamOn(firstMachine(PLOTS.get('0,0')), 0, 14);
    }

    // ---------- tour ----------
    function tour() {
        if (S.on) return;
        const keys = [...R.builtCache()]; if (!keys.length) return;
        // nearest neighbour path starting from the plot in view
        const here = R.unproject(R.W / 2, R.H / 2);
        const left = keys.map(k => PLOTS.get(k)); const path = [];
        let px = here[0], py = here[1];
        while (left.length) { let bi = 0, bd = 1e9; left.forEach((p, i) => { const d = Math.hypot(p.x0 + 2.5 - px, p.y0 + 2.5 - py); if (d < bd) { bd = d; bi = i; } }); const p = left.splice(bi, 1)[0]; path.push(p); px = p.x0 + 2.5; py = p.y0 + 2.5; }
        S.on = 'tour'; R.view.signs = false; S.t0 = R.T; S.shots = path.slice(0, 16); S.last = -1; S.a0 = R.cam.angle; S.from = [R.cam.x, R.cam.y]; S.z = dz();
        document.body.classList.add('touring', 'photo-clean');
        $('letterbox') && $('letterbox').classList.add('on');
        setTimeout(() => { window.addEventListener('pointerdown', stopTour, { once: true }); }, 60);
    }
    const SHOT = 3.6, FLY = 1.3;
    function updateTour() {
        const t = R.T - S.t0, i = Math.floor(t / SHOT), cam = R.cam;
        if (i >= S.shots.length) { stopTour(); return; }
        const p = S.shots[i], u = t - i * SHOT;
        const prev = i === 0 ? S.from : [S.shots[i - 1].x0 + 2.5, S.shots[i - 1].y0 + 2.5];
        const k = smooth(clamp01(u / FLY));
        cam.tx = cam.ty = null;
        cam.x = prev[0] + (p.x0 + 2.5 - prev[0]) * k; cam.y = prev[1] + (p.y0 + 2.5 - prev[1]) * k;
        const push = 0.95 + 0.25 * smooth(clamp01((u - FLY * 0.6) / (SHOT - FLY * 0.6)));
        cam.zoom = cam.tZoom = S.z * (k < 1 ? 0.8 + 0.15 * Math.abs(Math.cos(k * Math.PI)) : 1) * push;
        cam.angle = cam.tAngle = S.a0 + t * 0.1;
        if (i !== S.last) { S.last = i; caption(`${i + 1} / ${S.shots.length}`, p.name.toUpperCase()); FX.sfx('camWhoosh', undefined, undefined, { vol: 0.35 }); }
    }
    function stopTour() {
        if (S.on !== 'tour') return;
        S.on = null; R.view.signs = true; caption('', '');
        window.removeEventListener('pointerdown', stopTour);
        document.body.classList.remove('touring', 'photo-clean');
        $('letterbox') && $('letterbox').classList.remove('on');
        const cam = R.cam; cam.tAngle = Math.round(cam.angle / (Math.PI / 2)) * (Math.PI / 2); cam.tZoom = dz();
    }
    function stop() { if (S.on === 'intro') skip(); else if (S.on === 'tour') stopTour(); }

    // ---------- wiring ----------
    WORLD.use('update', () => { if (S.on === 'intro') updateIntro(); else if (S.on === 'tour') updateTour(); });
    WORLD.use('afterItems', () => drawBeam());
    WORLD.use('post', () => { if (S.on === 'intro') drawClouds(R.T - S.t0); });
    WORLD.use('landed', () => landed());
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S.on) stop(); });

    // FX Lab entries so the cinematics are documented and replayable like every other effect.
    if (FX.def) {
        FX.def({
            id: 'introCinematic', name: 'First play intro', tier: 'hero', category: 'Cinematic', trigger: 'TAP TO PLAY on a new save (REPLAY INTRO in Settings)',
            durationMs: 7200, sound: 'camWhoosh, tile ticks climbing in pitch, stinger plot, buy on landing, 5 ticks as the HUD lands', haptic: 'buy on landing',
            desc: 'You dive through a layer of cartoon clouds that part around the camera. The city builds itself: Stud Square first, then every plot you own in a ripple outward, 25 tiles each. The builder parachutes onto Stud Square, and the moment his boots touch down the HUD slams in piece by piece. A blueprint beam marks your first machine. SKIP or Esc jumps to the end.',
            spec: SPEC,
            roblox: 'A LocalScript sequence with Camera.CameraType = Scriptable and TweenService on Camera.CFrame (Cubic InOut 6.2 s) from a high, rotated CFrame to the gameplay CFrame. Clouds: 20 to 30 ImageLabels in a ScreenGui tweened outward and scaled up (or big Parts with a cloud mesh just in front of the camera). Tiles: tween each baseplate Part down with task.delay. Builder: a parachute Model welded to the character, lowered with a LinearVelocity, removed on Humanoid.StateChanged Landed. HUD: every top level Frame starts off screen and tweens in with Back Out, 0.07 s apart. Save IntroSeen in the profile.',
            run() { intro({ fresh: false }); },
        });
        FX.def({
            id: 'tourCinematic', name: 'Photo mode tour', tier: 'hero', category: 'Cinematic', trigger: 'TOUR in photo mode',
            durationMs: 3600, sound: 'camWhoosh per shot', haptic: 'none',
            desc: 'The camera flies from plot to plot along a nearest-neighbour path (up to 16), pulling back while it travels and pushing in slowly while it holds, orbiting the whole time. Each plot gets a location card. Tap or Esc stops it.',
            spec: { shot: SPEC.tour, path: 'nearest neighbour from the plot in view, 16 plots max', card: 'kicker n / total, title plot name' },
            roblox: 'Build the path on the client, then for each plot TweenService the Camera.CFrame (Sine InOut 1.3 s) to a CFrame looking at the plot centre from the iso angle, then a slow 2.3 s Linear tween closer. Hide the ScreenGui except a caption Frame. Stop on any InputBegan.',
            run() { if (typeof UIX !== 'undefined' && !UIX.photo.on) UIX.photo.enter(); tour(); },
        });
    }
    return { intro, tour, stop, skip, caption, SPEC, get on() { return S.on; } };
})();
