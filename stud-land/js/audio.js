// Stud City Incremental sound engine. Everything is synthesized live with WebAudio: no files, no libraries.
// Signal flow: voice -> [distance lowpass] -> [stereo pan] -> bus duck gain -> bus volume -> master
//              -> tame EQ (highshelf -4 dB at 7 kHz) -> DynamicsCompressor -> speakers.
// Each bus volume also feeds one shared procedural convolution reverb (send per bus, ui stays dry).
// Buses: music, sfx, ui, ambient. AUDIO.CATALOG documents every sound (synthesis spec + Roblox recipe)
// for the in-game FX Lab and for the Roblox rebuild. AUDIO.ROBLOX holds the global mixing setup.
// The public API is the return statement near the bottom of the AUDIO block.
const AUDIO = (() => {
    const W = typeof window !== 'undefined' ? window : null;
    const msNow = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const mtof = m => 440 * Math.pow(2, (m - 69) / 12);
    const R = (a, b) => a + Math.random() * (b - a);
    const num = (x, d) => (x != null && Number.isFinite(+x) ? +x : d);   // bad input (NaN, strings) never reaches an AudioParam
    const SEMI = 1.0595;        // buy ladder ratio: one semitone per quick buy
    const MASTER_TRIM = 0.7;    // headroom: setVolume(1) still leaves room for the compressor
    // Bus trims keep the mix balanced when every user slider is at 1. wet = reverb send level.
    const BUS = { music: { trim: 0.5, wet: 0.3 }, sfx: { trim: 0.9, wet: 0.14 }, ui: { trim: 0.65, wet: 0 }, ambient: { trim: 0.6, wet: 0.4 } };
    const DUCK = { music: 0.45, ambient: 0.3 };   // how far duck() pulls each bus down
    const AMB = 2.5;   // level of beds and layer events (theme layers, sea, crickets, rain, wind) on the ambient bus
    let ctx = null, started = false, master, comp, revIn, white, pink, brown;
    const bus = {}, vol = {}, snd = {}, timers = [];
    const st = {
        muted: false, volume: 0.8, bus: { music: 1, sfx: 1, ui: 1, ambient: 1 },
        ladder: 0, lastBuy: 0, night: 0, rain: 0, wind: 0, storm: false, theme: 'meadow',
        intensity: 0.55, seed: (Math.random() * 1e9) | 0, lastStep: 0.5,
    };
    const now = () => ctx.currentTime;
    const ok = () => !!ctx && started && !st.muted;

    // ---------- Core graph ----------
    function biquad(type, f, q) { const b = ctx.createBiquadFilter(); b.type = type; b.frequency.value = f; if (q != null) b.Q.value = q; return b; }
    function init() {
        if (ctx || !W) return;
        const AC = W.AudioContext || W.webkitAudioContext; if (!AC) return;
        try { ctx = new AC({ latencyHint: 'interactive' }); } catch (e) { ctx = null; return; }
        master = ctx.createGain(); master.gain.value = st.muted ? 0 : st.volume * MASTER_TRIM;
        const tame = ctx.createBiquadFilter(); tame.type = 'highshelf'; tame.frequency.value = 7000; tame.gain.value = -4;
        comp = ctx.createDynamicsCompressor();
        comp.threshold.value = -18; comp.knee.value = 12; comp.ratio.value = 3.5; comp.attack.value = 0.004; comp.release.value = 0.25;
        master.connect(tame); tame.connect(comp); comp.connect(ctx.destination);
        white = makeNoise('white'); pink = makeNoise('pink'); brown = makeNoise('brown');
        // Shared reverb: highpass before (no mud), lowpass after (no fizz).
        revIn = ctx.createGain();
        const rev = ctx.createConvolver(); rev.buffer = makeImpulse(2.2);
        const hp = biquad('highpass', 180, 0.7), lp = biquad('lowpass', 5200, 0.7);
        revIn.connect(hp); hp.connect(rev); rev.connect(lp); lp.connect(master);
        for (const k in BUS) {
            bus[k] = ctx.createGain(); vol[k] = ctx.createGain(); vol[k].gain.value = BUS[k].trim * st.bus[k];
            bus[k].connect(vol[k]); vol[k].connect(master);
            if (BUS[k].wet) { snd[k] = ctx.createGain(); snd[k].gain.value = BUS[k].wet; vol[k].connect(snd[k]); snd[k].connect(revIn); }
        }
    }
    // Noise buffers are built once (3 s mono, seamless loop via crossfaded ends) and looped with random offsets.
    function makeNoise(kind) {
        const sr = ctx.sampleRate, n = sr * 3, F = 2048, tmp = new Float32Array(n + F);
        let b0 = 0, b1 = 0, b2 = 0, last = 0, peak = 0;
        for (let i = 0; i < n + F; i++) {
            const w = Math.random() * 2 - 1;
            if (kind === 'white') tmp[i] = w;
            else if (kind === 'pink') { b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913; tmp[i] = b0 + b1 + b2 + w * 0.1848; }
            else { last = (last + 0.02 * w) / 1.02; tmp[i] = last; }
        }
        const b = ctx.createBuffer(1, n, sr), d = b.getChannelData(0);
        for (let i = 0; i < n; i++) { d[i] = i < F ? tmp[i] * (i / F) + tmp[n + i] * (1 - i / F) : tmp[i]; peak = Math.max(peak, Math.abs(d[i])); }
        for (let i = 0; i < n; i++) d[i] *= 0.9 / peak;
        return b;
    }
    // Reverb impulse: stereo decaying noise, 12 ms predelay, one-pole lowpass that darkens toward the tail.
    function makeImpulse(sec) {
        const sr = ctx.sampleRate, n = (sr * sec) | 0, pre = (sr * 0.012) | 0, b = ctx.createBuffer(2, n, sr);
        for (let c = 0; c < 2; c++) {
            const d = b.getChannelData(c); let lp = 0;
            for (let i = pre; i < n; i++) {
                const x = (i - pre) / (n - pre);
                lp += (0.55 - 0.4 * x) * ((Math.random() * 2 - 1) - lp);
                d[i] = lp * Math.pow(1 - x, 2) * Math.exp(-3 * x);
            }
        }
        return b;
    }
    // Click free parameter moves: hold the current value, then ramp.
    function hold(p, t) { if (p.cancelAndHoldAtTime) p.cancelAndHoldAtTime(t); else { p.cancelScheduledValues(t); p.setValueAtTime(p.value, t); } }
    function fadeTo(p, v, t, dur) { hold(p, t); p.linearRampToValueAtTime(v, t + dur); }

    // ---------- Voice limiter ----------
    // Every one-shot gets a voice: its own gain, optional distance lowpass + reverb send, optional panner.
    // At the cap the oldest voice fades out in 20 ms and is stopped (stolen). Low priority sounds (ambient
    // events, footsteps, autoTick, hover) are skipped instead of stealing when the pool is nearly full.
    const voices = { max: 24, list: [], stolen: 0, skipped: 0, get active() { return this.list.length; } };
    function voice(dest, o, low) {
        o = o || {};
        if (low && voices.list.length >= voices.max - 6) { voices.skipped++; return null; }
        while (voices.list.length >= voices.max) steal(voices.list[0]);
        const t = now(), out = ctx.createGain(), dist = clamp(num(o.dist, 0), 0, 1), pan = clamp(num(o.pan, 0), -1, 1);
        const v = { out, nodes: [out], src: [], srcs: 0, end: t + 0.2, t0: t, rate: Math.pow(2, clamp(num(o.pitch, 0), -24, 24) / 12) * clamp(num(o.rate, 1), 0.25, 4), pool: true };
        out.gain.value = clamp(num(o.vol, 1), 0, 2) * (1 - 0.7 * dist);
        let head = out;
        if (dist > 0.02) { const f = biquad('lowpass', 700 + 15000 * Math.pow(1 - dist, 2.5), 0.5); head.connect(f); head = f; v.nodes.push(f); }
        if (pan && ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = pan; head.connect(p); head = p; v.nodes.push(p); }
        head.connect(dest);
        if (dist > 0.05) { const s = ctx.createGain(); s.gain.value = dist * 0.5; head.connect(s); s.connect(revIn); v.nodes.push(s); }
        voices.list.push(v);
        return v;
    }
    // Register a source on a voice or sink; its private nodes are disconnected when it ends.
    function track(v, src, nodes, end) {
        if (v.src) { v.src.push(src); v.srcs++; if (end > v.end) v.end = end; }
        src.onended = () => {
            try { src.disconnect(); nodes.forEach(n => n.disconnect()); } catch (e) { }
            if (v.pool && --v.srcs <= 0) release(v);
        };
    }
    function release(v) {
        if (v.dead) return; v.dead = true;
        const i = voices.list.indexOf(v); if (i >= 0) voices.list.splice(i, 1);
        v.nodes.forEach(n => { try { n.disconnect(); } catch (e) { } });
    }
    function steal(v) {
        const i = voices.list.indexOf(v); if (i >= 0) voices.list.splice(i, 1);
        voices.stolen++;
        const t = now(); fadeTo(v.out.gain, 0, t, 0.02);
        v.src.forEach(s => { try { s.stop(t + 0.03); } catch (e) { } });
        if (!v.srcs) release(v);
    }
    const done = v => { if (v && !v.srcs) release(v); };
    const sink = out => ({ out, rate: 1 });   // unpooled destination for music notes

    // ---------- Synth building blocks (all envelopes ramp, so nothing clicks) ----------
    const nyq = f => clamp(f, 20, ctx.sampleRate * 0.45);
    function env(p, t, a, peak, dec) {
        a = Math.max(0.002, a);
        p.setValueAtTime(0.0001, t); p.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a);
        p.exponentialRampToValueAtTime(0.0001, t + a + dec);
    }
    // Oscillator with an exponential envelope. x: { to: glide target Hz, gt: glide time, det: cents, lp: lowpass Hz, q }
    function tone(v, f, type, t, a, peak, dec, x) {
        x = x || {};
        const o = ctx.createOscillator(), g = ctx.createGain(), nodes = [g];
        o.type = type; o.frequency.setValueAtTime(nyq(f * v.rate), t);
        if (x.to) o.frequency.exponentialRampToValueAtTime(nyq(x.to * v.rate), t + (x.gt || a + dec));
        if (x.det) o.detune.value = x.det;
        env(g.gain, t, a, peak, dec);
        let head = o;
        if (x.lp) { const f2 = biquad('lowpass', x.lp, x.q || 0.7); o.connect(f2); head = f2; nodes.push(f2); }
        head.connect(g); g.connect(v.out);
        const end = t + Math.max(0.002, a) + dec + 0.03;
        o.start(t); o.stop(end); track(v, o, nodes, end);
        return o;
    }
    // Filtered noise burst. Filter sweeps f0 -> f1 over the burst. x: { buf, a: attack }
    function noise(v, t, dur, peak, type, f0, f1, q, x) {
        x = x || {};
        const s = ctx.createBufferSource(); s.buffer = x.buf || white; s.loop = true;
        const f = biquad(type, nyq(f0 * v.rate), q || 1), g = ctx.createGain(), a = x.a || Math.min(0.006, dur / 4);
        f.frequency.setValueAtTime(nyq(f0 * v.rate), t);
        if (f1) f.frequency.exponentialRampToValueAtTime(nyq(f1 * v.rate), t + a + dur);
        env(g.gain, t, a, peak, dur);
        s.connect(f); f.connect(g); g.connect(v.out);
        const end = t + a + dur + 0.03;
        s.start(t, Math.random() * 2.5); s.stop(end); track(v, s, [f, g], end);
    }
    // Two operator FM for bells, glass and metal. ratio = modulator/carrier, idx = depth in multiples of f.
    function fm(v, f, ratio, idx, t, a, peak, dec) {
        const c = ctx.createOscillator(), m = ctx.createOscillator(), mg = ctx.createGain(), g = ctx.createGain(), fr = nyq(f * v.rate);
        c.frequency.setValueAtTime(fr, t); m.frequency.setValueAtTime(nyq(fr * ratio), t);
        mg.gain.setValueAtTime(fr * idx, t); mg.gain.exponentialRampToValueAtTime(Math.max(1, fr * idx * 0.03), t + a + dec * 0.6);
        m.connect(mg); mg.connect(c.frequency); c.connect(g); g.connect(v.out);
        env(g.gain, t, a, peak, dec);
        const end = t + Math.max(0.002, a) + dec + 0.03;
        c.start(t); m.start(t); c.stop(end); m.stop(end);
        track(v, c, [g], end); track(v, m, [mg], end);
    }
    // Endless looped sources for beds (ambience layers). They live until the sink's sources are stopped.
    function loopSrc(s, buf, type, f, q, g) {
        const src = ctx.createBufferSource(); src.buffer = buf; src.loop = true;
        const fl = biquad(type, nyq(f * (s.rate || 1)), q), gn = ctx.createGain(); gn.gain.value = g;
        src.connect(fl); fl.connect(gn); gn.connect(s.out); src.start(now(), R(0, 2.5));
        track(s, src, [fl, gn], Infinity);
        return { f: fl, g: gn };
    }
    function loopOsc(s, type, f, g, lp) {
        const o = ctx.createOscillator(), gn = ctx.createGain(), nodes = [gn]; o.type = type; o.frequency.value = f * (s.rate || 1); gn.gain.value = g;
        let head = o; if (lp) { const fl = biquad('lowpass', lp, 0.7); o.connect(fl); head = fl; nodes.push(fl); }
        head.connect(gn); gn.connect(s.out); o.start();
        track(s, o, nodes, Infinity);
        return { g: gn, o };
    }
    function lfo(s, hz, depth, param) {
        const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.value = hz; g.gain.value = depth;
        o.connect(g); g.connect(param); o.start(); track(s, o, [g], Infinity);
    }
    // Marimba / kalimba mallet: sine fundamental, short 4x overtone (the wooden tonk), soft triangle octave.
    function mallet(v, f, t, peak, dec, bright) {
        const b = bright == null ? 1 : bright;
        tone(v, f, 'sine', t, 0.003, peak, dec);
        tone(v, f * 4, 'sine', t, 0.002, peak * 0.2 * b, 0.06);
        tone(v, f * 2, 'triangle', t, 0.004, peak * 0.1, dec * 0.35, { lp: 3500 });
    }
    function kalimba(v, f, t, peak) { tone(v, f, 'sine', t, 0.002, peak, 0.75); tone(v, f * 5.4, 'sine', t, 0.001, peak * 0.1, 0.03); }
    // Sustained tone: linear attack, hold, release. x: { from: start Hz (scoop up or down to f), st: scoop time,
    // lp or bp: filter Hz, q, vib: [rate Hz, depth cents] }
    function sus(v, type, f, t, a, hold, rel, peak, x) {
        x = x || {};
        const o = ctx.createOscillator(), g = ctx.createGain(), nodes = [g], fr = nyq(f * v.rate), end = t + a + hold + rel + 0.03;
        o.type = type; o.frequency.setValueAtTime(x.from ? nyq(x.from * v.rate) : fr, t);
        if (x.from) o.frequency.exponentialRampToValueAtTime(fr, t + (x.st || a));
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + a); g.gain.setValueAtTime(peak, t + a + hold); g.gain.linearRampToValueAtTime(0, t + a + hold + rel);
        let head = o;
        if (x.lp || x.bp) { const fl = biquad(x.bp ? 'bandpass' : 'lowpass', nyq((x.bp || x.lp) * v.rate), x.q || 0.7); o.connect(fl); head = fl; nodes.push(fl); }
        head.connect(g); g.connect(v.out);
        if (x.vib) { const l = ctx.createOscillator(), lg = ctx.createGain(); l.frequency.value = x.vib[0]; lg.gain.value = x.vib[1]; l.connect(lg); lg.connect(o.detune); l.start(t); l.stop(end); track(v, l, [lg], end); }
        o.start(t); o.stop(end); track(v, o, nodes, end);
        return o;
    }
    // Soft brass: two saws 10 cents apart through a lowpass that opens on the attack (the bwah), capped at 4 kHz.
    function brass(v, f, t, len, peak) {
        const fr = nyq(f * v.rate), g = ctx.createGain(), lp = biquad('lowpass', fr * 1.5, 1.1), end = t + len + 0.6;
        lp.frequency.setValueAtTime(nyq(fr * 1.5), t); lp.frequency.exponentialRampToValueAtTime(Math.min(4000, fr * 6), t + 0.08); lp.frequency.exponentialRampToValueAtTime(Math.min(2600, fr * 3), t + 0.45);
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + 0.04); g.gain.setTargetAtTime(peak * 0.7, t + 0.05, 0.2); g.gain.setTargetAtTime(0, t + len, 0.08);
        lp.connect(g); g.connect(v.out);
        [-5, 5].forEach((d, i) => { const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(fr, t); o.detune.value = d; o.connect(lp); o.start(t); o.stop(end); track(v, o, i ? [lp, g] : [], end); });
    }

    // ---------- One-shot sounds. def(id, bus, fn(v, t, opts), { low, duck, after }) ----------
    const SFX = {};
    const def = (id, b, fn, x) => { SFX[id] = Object.assign({ bus: b, fn }, x || {}); };

    // Brick snap: plastic click, tiny body thump, pitched knock. Quick buys climb a semitone ladder.
    function snap(v, t, big) {
        const ms = msNow();
        st.ladder = ms - st.lastBuy < 900 ? Math.min(st.ladder + 1, 14) : 0; st.lastBuy = ms;
        const f = 523.25 * Math.pow(SEMI, st.ladder);
        noise(v, t, 0.028, 0.3, 'bandpass', 3400, 0, 2.2);
        tone(v, 170, 'sine', t, 0.002, 0.2, 0.05, { to: 90 });
        tone(v, f, 'triangle', t + 0.004, 0.003, big ? 0.28 : 0.19, 0.13, { lp: 3200 });
        tone(v, f * 2, 'sine', t + 0.012, 0.003, 0.05, 0.08);
        if (big) tone(v, f * 1.5, 'sine', t + 0.05, 0.004, 0.07, 0.3);
    }
    def('buy', 'sfx', (v, t, o) => snap(v, t, !!o.big));   // play('buy', { big: true }) equals play('buyBig')
    def('buyBig', 'sfx', (v, t) => snap(v, t, true));
    def('autoTick', 'ui', (v, t) => noise(v, t, 0.018, 0.07, 'bandpass', 5000, 0, 3), { low: true });
    def('maxed', 'sfx', (v, t) => {
        [0, 4, 7, 12].forEach((s, i) => mallet(v, 784 * Math.pow(SEMI, s), t + i * 0.06, 0.15, 0.5));
        fm(v, 1568, 3.01, 0.5, t + 0.26, 0.005, 0.05, 0.9);
    });
    // Bricks raining onto a new plot; the musical fanfare is the 'plot' stinger on the next beat.
    def('plotBuilt', 'sfx', (v, t) => {
        for (let i = 0; i < 16; i++) {
            const tt = t + i * 0.045 + R(0, 0.02);
            noise(v, tt, 0.028, R(0.12, 0.24), 'bandpass', R(2600, 4800), 0, 2.4);
            if (i % 3 === 0) tone(v, R(380, 700), 'triangle', tt, 0.002, 0.06, 0.07, { lp: 2400 });
        }
        tone(v, 110, 'sine', t + 0.72, 0.003, 0.25, 0.25, { to: 55 });
    }, { duck: 2.2, after: () => stinger('plot', 0.7) });
    const whoosh = (v, t) => noise(v, t, 0.7, 0.3, 'bandpass', 300, 3200, 1.2, { buf: pink, a: 0.2 });
    const boom = (v, t) => { tone(v, 120, 'sine', t, 0.005, 0.5, 0.6, { to: 38 }); noise(v, t, 0.4, 0.22, 'lowpass', 900, 120, 0.7, { buf: brown }); };
    function crumble(v, t) {
        for (let i = 0; i < 26; i++) {
            const k = i / 26, tt = t + Math.pow(k, 1.6) * 1.1 + R(0, 0.04);
            noise(v, tt, R(0.02, 0.05), 0.3 * (1 - k * 0.6) * R(0.6, 1), 'bandpass', R(1800, 4400) - k * 800, 0, 2.2);
            if (i % 2 === 0) tone(v, R(300, 700), 'triangle', tt, 0.002, 0.08, 0.06, { lp: 2000 });
        }
        noise(v, t, 1.0, 0.16, 'lowpass', 500, 120, 0.7, { buf: brown, a: 0.05 });
    }
    def('crumble', 'sfx', crumble);
    def('reset', 'sfx', (v, t) => { crumble(v, t); whoosh(v, t); boom(v, t + 0.38); }, { duck: 2.6, after: () => stinger('reset', 0.5) });
    // Plot island rising out of the sea: swelling rumble, rising sub, trickles, a settle thunk.
    def('rise', 'sfx', (v, t) => {
        noise(v, t, 1.0, 0.16, 'lowpass', 180, 700, 0.9, { buf: brown, a: 0.9 });
        tone(v, 55, 'sine', t, 1.0, 0.16, 0.9, { to: 110, gt: 1.7 });
        for (let i = 0; i < 7; i++) { const f = R(420, 900); tone(v, f, 'sine', t + 0.9 + R(0, 0.8), 0.003, 0.04, 0.05, { to: f * 2, gt: 0.04 }); }
        tone(v, 110, 'sine', t + 1.8, 0.002, 0.3, 0.25, { to: 60 });
        noise(v, t + 1.8, 0.03, 0.18, 'bandpass', 2500, 0, 2);
    });
    def('coin', 'sfx', (v, t) => {
        tone(v, 988, 'square', t, 0.002, 0.08, 0.07, { lp: 3000 });
        tone(v, 1319, 'square', t + 0.07, 0.002, 0.09, 0.35, { lp: 3200 });
        tone(v, 2638, 'sine', t + 0.07, 0.002, 0.02, 0.25);
    });
    def('codeFound', 'sfx', (v, t) => {
        [72, 74, 76, 79, 81, 84].forEach((m, i) => mallet(v, mtof(m), t + i * 0.05, 0.1, 0.4));
        fm(v, mtof(84), 3.5, 0.35, t + 0.32, 0.01, 0.07, 1.4);
        noise(v, t + 0.1, 0.8, 0.015, 'bandpass', 5000, 8000, 1, { a: 0.2 });
    });
    def('achievement', 'sfx', (v, t) => {
        fm(v, 784, 3.5, 0.5, t, 0.004, 0.1, 0.9); fm(v, 1046.5, 3.5, 0.5, t + 0.12, 0.004, 0.12, 1.3);
        for (let i = 0; i < 6; i++) tone(v, i % 2 ? 2349 : 2093, 'sine', t + 0.3 + i * 0.05, 0.003, 0.018 * (1 - i / 7), 0.08);
        mallet(v, 523.25, t + 0.12, 0.08, 0.6);
    });
    // Tiny robot drone: detuned saws through a resonant bandpass, fast buzz tremolo, doppler wobble.
    def('drone', 'sfx', (v, t) => {
        const g = ctx.createGain(), bp = biquad('bandpass', 1100 * v.rate, 2.5), end = t + 1.0;
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.05, t + 0.15); g.gain.setValueAtTime(0.05, t + 0.7); g.gain.linearRampToValueAtTime(0, t + 0.95);
        bp.connect(g); g.connect(v.out);
        [190, 193.5].forEach((f, i) => { const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(f * v.rate, t); o.frequency.linearRampToValueAtTime(f * v.rate * 0.94, end); o.connect(bp); o.start(t); o.stop(end); track(v, o, i ? [bp, g] : [], end); });
        const l = ctx.createOscillator(), lg = ctx.createGain(); l.frequency.value = 26; lg.gain.value = 0.02;
        l.connect(lg); lg.connect(g.gain); l.start(t); l.stop(end); track(v, l, [lg], end);
    });
    def('splash', 'sfx', (v, t) => {
        noise(v, t, 0.6, 0.28, 'lowpass', 2400, 300, 0.8, { buf: pink });
        noise(v, t + 0.05, 0.25, 0.08, 'bandpass', 3500, 0, 0.8);
        for (let i = 0; i < 4; i++) { const f = R(400, 800); tone(v, f, 'sine', t + 0.2 + R(0, 0.4), 0.003, 0.03, 0.05, { to: f * 2, gt: 0.04 }); }
    });
    def('whale', 'ambient', (v, t) => {
        const o = tone(v, 180, 'sine', t, 0.4, 0.14, 1.6); o.frequency.linearRampToValueAtTime(260 * v.rate, t + 0.9); o.frequency.linearRampToValueAtTime(150 * v.rate, t + 2);
        const h = tone(v, 360, 'sine', t + 0.1, 0.4, 0.03, 1.4); h.frequency.linearRampToValueAtTime(520 * v.rate, t + 0.95); h.frequency.linearRampToValueAtTime(300 * v.rate, t + 2);
        SFX.splash.fn(v, t + 1.2);
    });

    // UI: short, soft, dry.
    def('tap', 'ui', (v, t) => { tone(v, 880, 'sine', t, 0.003, 0.11, 0.06); tone(v, 1320, 'sine', t + 0.02, 0.003, 0.04, 0.05); });
    def('tick', 'ui', (v, t) => { noise(v, t, 0.012, 0.05, 'bandpass', 2600, 0, 4); tone(v, 1250, 'sine', t, 0.002, 0.03, 0.025); });
    def('hover', 'ui', (v, t) => tone(v, 1400, 'sine', t, 0.006, 0.018, 0.035, { to: 1520 }), { low: true });
    def('toggle', 'ui', (v, t, o) => {
        const up = o.on !== false;
        noise(v, t, 0.01, 0.07, 'bandpass', 3000, 0, 3);
        tone(v, up ? 600 : 900, 'sine', t, 0.003, 0.08, 0.05); tone(v, up ? 900 : 600, 'sine', t + 0.045, 0.003, 0.08, 0.07);
    });
    def('open', 'ui', (v, t) => { tone(v, 660, 'sine', t, 0.004, 0.09, 0.09); tone(v, 990, 'sine', t + 0.05, 0.004, 0.07, 0.1); noise(v, t, 0.12, 0.02, 'bandpass', 1200, 3000, 1, { buf: pink }); });
    def('close', 'ui', (v, t) => { tone(v, 740, 'sine', t, 0.004, 0.08, 0.08); tone(v, 520, 'sine', t + 0.05, 0.004, 0.07, 0.1); noise(v, t, 0.1, 0.018, 'bandpass', 2600, 1000, 1, { buf: pink }); });
    def('stamp', 'ui', (v, t) => {
        tone(v, 150, 'sine', t, 0.002, 0.3, 0.28, { to: 48, gt: 0.2 });
        noise(v, t, 0.06, 0.28, 'lowpass', 2400, 400, 0.7);
        tone(v, 330, 'triangle', t, 0.002, 0.07, 0.1, { lp: 1200 });
        noise(v, t + 0.02, 0.18, 0.04, 'bandpass', 900, 300, 1.2, { buf: pink });
    });
    def('deny', 'ui', (v, t) => { tone(v, 220, 'square', t, 0.004, 0.05, 0.12, { lp: 1100 }); tone(v, 175, 'square', t + 0.09, 0.004, 0.05, 0.15, { lp: 900 }); });
    def('error', 'ui', (v, t) => [330, 294, 247].forEach((f, i) => tone(v, f, 'triangle', t + i * 0.085, 0.004, 0.09, 0.12, { lp: 1600 })));

    // World one-shots.
    def('shutter', 'sfx', (v, t) => {
        noise(v, t, 0.012, 0.3, 'bandpass', 2800, 0, 1.5); tone(v, 140, 'sine', t, 0.002, 0.14, 0.05, { to: 80 });
        noise(v, t + 0.07, 0.02, 0.24, 'bandpass', 1900, 0, 1.5); tone(v, 120, 'sine', t + 0.07, 0.002, 0.11, 0.05, { to: 70 });
        noise(v, t + 0.1, 0.18, 0.035, 'bandpass', 1200, 2400, 3);
    });
    def('camWhoosh', 'sfx', (v, t) => {
        noise(v, t, 0.55, 0.5, 'bandpass', 260, 2200, 1.4, { buf: pink, a: 0.22 });
        noise(v, t + 0.1, 0.4, 0.06, 'bandpass', 2500, 5000, 0.8, { a: 0.2 });
    });
    function crack(v, t, lvl) {
        noise(v, t, 0.12, 0.3 * lvl, 'highpass', 1800, 0, 0.7);
        for (let i = 0; i < 9; i++) noise(v, t + R(0, 0.3), R(0.006, 0.02), R(0.05, 0.14) * lvl, 'bandpass', R(2000, 6000), 0, 2);
        tone(v, 90, 'sine', t, 0.002, 0.3 * lvl, 0.4, { to: 40 });
    }
    def('lightning', 'ambient', (v, t) => crack(v, t, 1));
    // Thunder: distance 0..1 delays it (sound travel), darkens it, lengthens the roll. Close ones crack first.
    def('thunder', 'ambient', (v, t, o) => {
        const d = clamp(num(o.distance, 0.4), 0, 1), tt = t + d * 1.8, lvl = 0.5 * (1 - d * 0.65);
        if (d < 0.35) crack(v, t, 1 - d * 2);
        noise(v, tt, 2.5 + d * 2, lvl * 0.55, 'lowpass', 900 - d * 600, 90, 0.7, { buf: brown, a: 0.05 + d * 0.4 });
        for (let i = 0; i < 5; i++) noise(v, tt + R(0.2, 2.2), R(0.3, 0.8), lvl * R(0.15, 0.35), 'lowpass', R(250, 500), 80, 0.8, { buf: brown, a: 0.1 });
        tone(v, 60, 'sine', tt, 0.02, lvl * 0.4, 1.5, { to: 35 });
    });
    def('foghorn', 'ambient', (v, t) => {
        const g = ctx.createGain(), lp = biquad('lowpass', 480, 1.5), end = t + 2.5;
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.07, t + 0.35); g.gain.setValueAtTime(0.07, t + 1.6); g.gain.linearRampToValueAtTime(0, t + 2.4);
        lp.connect(g); g.connect(v.out);
        [[98, 'sawtooth'], [98.7, 'sawtooth'], [49, 'sine']].forEach(([f, ty], i) => {
            const o = ctx.createOscillator(); o.type = ty; o.frequency.setValueAtTime(f * v.rate, t); o.frequency.setValueAtTime(f * v.rate, t + 1.6); o.frequency.linearRampToValueAtTime(f * v.rate * 0.94, t + 2.4);
            o.connect(lp); o.start(t); o.stop(end); track(v, o, i === 2 ? [lp, g] : [], end);
        });
    });
    const gullCall = (v, t) => {
        const n = 2 + (Math.random() * 2 | 0), f = R(1200, 1500);
        for (let i = 0; i < n; i++) {
            const tt = t + i * R(0.28, 0.36), o = tone(v, f, 'triangle', tt, 0.02, 0.05, 0.24, { lp: 2600 });
            o.frequency.exponentialRampToValueAtTime(f * 1.5 * v.rate, tt + 0.07); o.frequency.exponentialRampToValueAtTime(f * 0.85 * v.rate, tt + 0.24);
            noise(v, tt, 0.18, 0.01, 'bandpass', 2000, 1400, 3);
        }
    };
    def('gull', 'ambient', gullCall);
    def('fireworks', 'sfx', (v, t) => {
        tone(v, 700, 'sine', t, 0.05, 0.02, 0.75, { to: 1900, gt: 0.8 });
        noise(v, t, 0.8, 0.02, 'bandpass', 1500, 4000, 1, { buf: pink, a: 0.3 });
        const p = t + 0.85;
        noise(v, p, 0.3, 0.26, 'lowpass', 2200, 300, 0.7, { buf: pink }); tone(v, 90, 'sine', p, 0.003, 0.24, 0.4, { to: 40 });
        for (let i = 0; i < 24; i++) noise(v, p + 0.1 + R(0, 1.2), R(0.006, 0.015), R(0.03, 0.08), 'bandpass', R(3000, 6000), 0, 2);
    });
    const bubbleSet = (v, t, n, lvl, span) => { for (let i = 0; i < n; i++) { const f = R(380, 950); tone(v, f, 'sine', t + R(0, span), 0.003, lvl, 0.05, { to: f * R(1.8, 2.4), gt: 0.045 }); } };
    def('bubbles', 'sfx', (v, t) => bubbleSet(v, t, 9, 0.06, 0.9));

    // Wow layer: city growth, the Stud Express train, sky and sea set pieces.
    def('whistle', 'sfx', (v, t) => {
        [[494, 0.05], [587, 0.045]].forEach(([f, p]) => {   // B4 + D5: a warm two chime steam whistle
            sus(v, 'triangle', f, t + 0.03, 0.14, 0.5, 0.25, p, { from: f * 0.96, st: 0.18, lp: 2400, vib: [5.5, 6] });
            sus(v, 'sine', f * 2, t + 0.03, 0.14, 0.5, 0.25, p * 0.25, { from: f * 1.92, st: 0.18 });
        });
        noise(v, t, 0.3, 0.05, 'bandpass', 1500, 900, 1.2, { buf: pink, a: 0.03 });   // breathy steam attack
        noise(v, t + 0.05, 0.8, 0.02, 'bandpass', 3000, 2000, 0.8, { a: 0.15 });      // hiss under the tone
    });
    def('chug', 'sfx', (v, t) => {
        const k = R(0.9, 1.1);   // repeats never match exactly
        noise(v, t, 0.11, 0.2 * k, 'lowpass', 1400 * k, 350, 0.8, { buf: pink, a: 0.008 });
        noise(v, t, 0.05, 0.035 * k, 'bandpass', 2600 * k, 0, 1, { a: 0.004 });
        tone(v, 70, 'sine', t, 0.004, 0.06 * k, 0.08);
    }, { low: true });
    // City tier up: brass arpeggio C E G C, then a held C major chord with timpani, sparkle and a cymbal swell.
    // Always in C major, which also sits inside the night key (A minor is its relative minor).
    function tierFn(v, t) {
        const s = 0.13, hit = t + 4 * s;
        [60, 64, 67, 72].forEach((m, i) => brass(v, mtof(m), t + i * s, s * 0.9, 0.055));
        [48, 60, 64, 67, 72].forEach(m => brass(v, mtof(m), hit, 1.45, 0.035));
        tone(v, 65.4, 'sine', hit, 0.005, 0.25, 0.9, { to: 60 });
        noise(v, t, 1.6, 0.045, 'bandpass', 7000, 5000, 0.6, { a: 0.52 });
        [84, 88, 91, 96].forEach((m, i) => mallet(v, mtof(m), hit + i * 0.06, 0.05, 0.5));
    }
    def('tierUp', 'sfx', tierFn, { duck: 2.5 });
    def('letterDrop', 'sfx', (v, t) => {
        const k = R(0.95, 1.05);
        tone(v, 130 * k, 'sine', t, 0.002, 0.26, 0.2, { to: 55 });
        noise(v, t, 0.03, 0.22, 'bandpass', 1800 * k, 0, 1.5);
        tone(v, 240 * k, 'triangle', t, 0.002, 0.1, 0.12, { lp: 900 });
        for (let i = 0; i < 3; i++) noise(v, t + R(0.04, 0.09), 0.012, 0.05, 'bandpass', 3000, 0, 2);
    });
    def('towerRise', 'sfx', (v, t) => {
        noise(v, t, 0.8, 0.16, 'lowpass', 150, 600, 0.9, { buf: brown, a: 0.6 });
        tone(v, 45, 'sine', t, 0.6, 0.16, 0.75, { to: 90, gt: 1.3 });
        [72, 74, 76, 79, 81, 84, 86, 88].forEach((m, i) => fm(v, mtof(m), 3.01, 0.3, t + 0.35 + i * 0.11, 0.004, 0.03 + i * 0.003, 0.35));
        noise(v, t + 0.3, 1.0, 0.012, 'bandpass', 3000, 7000, 1, { a: 0.4 });
    });
    def('shootingStar', 'ambient', (v, t) => {
        tone(v, 2600, 'sine', t, 0.05, 0.03, 0.7, { to: 1500, gt: 0.7, lp: 5000 });
        for (let i = 0; i < 8; i++) fm(v, 3000 - i * 150, 3.01, 0.25, t + 0.06 + i * 0.08, 0.002, 0.02 * (1 - i / 10), 0.25);
        noise(v, t, 0.6, 0.008, 'bandpass', 6000, 3000, 1, { a: 0.2 });
    });
    def('serpent', 'sfx', (v, t) => {
        [[70, 0.12], [105, 0.05]].forEach(([f, p]) => {   // playful rawr: rises, then sinks, with a growl wobble
            const o = sus(v, 'sawtooth', f, t, 0.25, 0.45, 0.35, p, { from: f * 0.8, st: 0.35, lp: 520, q: 4, vib: [22, 30] });
            o.frequency.linearRampToValueAtTime(f * 1.3 * v.rate, t + 0.5); o.frequency.linearRampToValueAtTime(f * 0.85 * v.rate, t + 1.0);
        });
        noise(v, t, 0.7, 0.15, 'bandpass', 300, 1200, 1.2, { buf: pink, a: 0.3 });
        noise(v, t + 0.8, 0.7, 0.1, 'lowpass', 1600, 300, 0.8, { buf: pink, a: 0.05 });
        bubbleSet(v, t + 0.8, 12, 0.05, 0.75);
    });
    // Milestone (1K, 1M, 1B...): ta-ta-taaa on G G C, then E5 held over a C major chord.
    def('milestone', 'sfx', (v, t) => {
        [67, 67, 72].forEach((m, i) => brass(v, mtof(m), t + i * 0.12, 0.09, 0.05));
        brass(v, mtof(76), t + 0.36, 1.0, 0.055);
        [60, 64, 67].forEach(m => brass(v, mtof(m), t + 0.36, 1.0, 0.03));
        tone(v, 65.4, 'sine', t + 0.36, 0.005, 0.2, 0.8, { to: 60 });
        [88, 91, 96].forEach((m, i) => mallet(v, mtof(m), t + 0.4 + i * 0.06, 0.04, 0.5));
    }, { duck: 1.8 });
    def('searchlight', 'ambient', (v, t) => {
        sus(v, 'sawtooth', 60, t, 0.2, 0.5, 0.3, 0.005, { lp: 300 });
        sus(v, 'sine', 120, t, 0.2, 0.5, 0.3, 0.004);
    });

    // Footsteps: tiny random pitch, length and level changes, never the same random twice in a row.
    function stepVar() {
        let r; do r = Math.random(); while (Math.abs(r - st.lastStep) < 0.18);
        st.lastStep = r;
        return { f: Math.pow(2, (r * 3 - 1.5) / 12), l: R(0.85, 1.15), g: R(0.8, 1.2) };
    }
    const STEP = {
        grass(v, t, r) { noise(v, t, 0.07 * r.l, 0.12, 'bandpass', 2200 * r.f, 1400 * r.f, 0.9, { a: 0.008 }); noise(v, t + 0.012, 0.05, 0.04, 'highpass', 3500 * r.f, 0, 0.7); tone(v, 90 * r.f, 'sine', t, 0.004, 0.05, 0.05); },
        stone(v, t, r) { noise(v, t, 0.025, 0.15, 'bandpass', 1900 * r.f, 0, 1.8); tone(v, 190 * r.f, 'sine', t, 0.002, 0.12, 0.06, { to: 120 * r.f }); },
        metal(v, t, r) { noise(v, t, 0.02, 0.09, 'bandpass', 3200 * r.f, 0, 2); fm(v, 540 * r.f, 2.76, 1.2, t, 0.002, 0.045, 0.16); tone(v, 110 * r.f, 'sine', t, 0.002, 0.1, 0.05); },
        sand(v, t, r) { noise(v, t, 0.11 * r.l, 0.09, 'bandpass', 3800 * r.f, 2600 * r.f, 0.8, { a: 0.02 }); noise(v, t, 0.06, 0.05, 'lowpass', 600 * r.f, 0, 0.7, { buf: pink }); },
        wood(v, t, r) { tone(v, 210 * r.f, 'triangle', t, 0.002, 0.1, 0.07, { lp: 1400 }); tone(v, 420 * r.f, 'sine', t, 0.002, 0.04, 0.04); noise(v, t, 0.03, 0.09, 'bandpass', 950 * r.f, 0, 2.5); },
        water(v, t, r) { noise(v, t, 0.18 * r.l, 0.15, 'lowpass', 1800 * r.f, 350, 0.8, { a: 0.01, buf: pink }); tone(v, 520 * r.f, 'sine', t + 0.03, 0.004, 0.04, 0.05, { to: 1100 * r.f }); noise(v, t + 0.02, 0.1, 0.025, 'bandpass', 3000 * r.f, 0, 1); },
    };
    for (const k in STEP) def('step_' + k, 'sfx', (v, t) => { const r = stepVar(); v.out.gain.value *= r.g * 0.8; STEP[k](v, t, r); }, { low: true });

    // ---------- Ambience ----------
    // Always on: sea wash bed and night crickets (outdoor themes). Each theme maps to one or two layer kinds
    // that crossfade over about 3 s. A layer has an optional endless bed(sink) and sporadic events ev(v, t)
    // at `rate` per second. Events go through the voice pool as low priority, spread in pan and distance.
    const bird = (v, t) => {
        const f = R(1900, 3100), n = 2 + (Math.random() * 4 | 0), sp = R(0.08, 0.14);
        for (let i = 0; i < n; i++) tone(v, f * R(0.95, 1.05), 'sine', t + i * sp, 0.01, 0.03, 0.07, { to: f * R(1.2, 1.5), gt: 0.06 });
    };
    const bee = (v, t) => {
        const o = tone(v, 210, 'sawtooth', t, 0.4, 0.012, 1.2, { lp: 900 });
        o.frequency.linearRampToValueAtTime(R(190, 240) * v.rate, t + 0.8); o.frequency.linearRampToValueAtTime(R(200, 230) * v.rate, t + 1.6);
    };
    const cricket = (v, t) => { const f = R(3900, 4300); for (let k = 0; k < 2; k++) for (let i = 0; i < 3; i++) tone(v, f, 'sine', t + k * 0.28 + i * 0.045, 0.004, 0.012, 0.025); };
    const owl = (v, t) => { tone(v, 390, 'sine', t, 0.05, 0.04, 0.35, { to: 360, lp: 900 }); tone(v, 380, 'sine', t + 0.55, 0.05, 0.035, 0.45, { to: 340, lp: 900 }); };
    const glint = (v, t) => { const f = R(2000, 2800); fm(v, f, 3.01, 0.3, t, 0.002, 0.014, 0.6); fm(v, f * 1.5, 3.01, 0.3, t + 0.07, 0.002, 0.008, 0.5); };
    const LAYERS = {
        meadow: { rate: 0.35, day: true, ev(v, t) { if (Math.random() < 0.85) bird(v, t); else bee(v, t); } },
        lab: { rate: 0.6, bed(s) { const n = loopSrc(s, white, 'bandpass', 1400, 4, 0.01); lfo(s, 0.23, 0.006, n.g.gain); }, ev(v, t) { bubbleSet(v, t, 2 + (Math.random() * 3 | 0), 0.035, 0.4); } },
        factory: {
            rate: 0.4,
            bed(s) { loopSrc(s, brown, 'lowpass', 140, 0.8, 0.06); const h = loopOsc(s, 'sine', 55, 0.01); lfo(s, 1.5, 0.006, h.g.gain); },
            ev(v, t) {
                if (Math.random() < 0.2) { noise(v, t, R(0.5, 0.9), 0.025, 'highpass', 2500, 0, 0.7, { a: 0.08 }); return; }
                fm(v, R(260, 520), 2.76, R(1.5, 3), t, 0.002, 0.035, R(0.25, 0.5));
                noise(v, t, 0.03, 0.05, 'bandpass', 2400, 0, 2); tone(v, 90, 'sine', t, 0.002, 0.07, 0.08);
            },
        },
        energy: {
            rate: 0.15,
            bed(s) { const a = loopOsc(s, 'sawtooth', 60, 0.006, 380); loopOsc(s, 'sine', 120, 0.008); lfo(s, 0.3, 0.003, a.g.gain); },
            ev(v, t) { const n = 3 + (Math.random() * 5 | 0); for (let i = 0; i < n; i++) noise(v, t + R(0, 0.18), R(0.004, 0.012), R(0.03, 0.07), 'bandpass', R(2500, 6000), 0, 3); },
        },
        lava: {
            rate: 1.4,
            bed(s) { const w = loopSrc(s, pink, 'bandpass', 450, 1.2, 0.05); lfo(s, 0.06, 220, w.f.frequency); lfo(s, 0.11, 0.025, w.g.gain); loopSrc(s, brown, 'lowpass', 90, 0.7, 0.04); },
            ev(v, t) {
                if (Math.random() < 0.08) { tone(v, R(70, 110), 'sine', t, 0.02, 0.1, 0.25, { to: R(150, 220), gt: 0.2 }); return; }
                const n = 1 + (Math.random() * 3 | 0); for (let i = 0; i < n; i++) noise(v, t + R(0, 0.12), R(0.004, 0.012), R(0.02, 0.06), 'bandpass', R(900, 3500), 0, 1.5);
            },
        },
        surf: {
            rate: 0.16,
            bed(s) { loopSrc(s, brown, 'lowpass', 650, 0.5, 0.02); },
            ev(v, t) {
                if (Math.random() < 0.06 && st.night < 0.5) { gullCall(v, t); return; }
                noise(v, t, 2.6, 0.08, 'lowpass', 1500, 300, 0.6, { buf: pink, a: 1.2 });
                noise(v, t + 1.0, 1.4, 0.02, 'bandpass', 3200, 1800, 0.7, { a: 0.3 });
            },
        },
        shimmer: {
            rate: 0.12,
            bed(s) {
                loopOsc(s, 'sine', 130.81, 0.012); loopOsc(s, 'sine', 131.4, 0.01); loopOsc(s, 'triangle', 196, 0.006, 900);
                const a = loopOsc(s, 'sine', 1046.5, 0.0025), b = loopOsc(s, 'sine', 1568, 0.0015);
                lfo(s, 0.4, 0.0025, a.g.gain); lfo(s, 0.27, 0.0015, b.g.gain);
            },
            ev(v, t) { fm(v, mtof([84, 86, 88, 91, 93][Math.random() * 5 | 0]), 3.01, 0.4, t, 0.01, 0.02, 2.2); },
        },
        mine: {
            rate: 0.5,
            bed(s) { loopSrc(s, brown, 'lowpass', 110, 0.6, 0.03); },
            ev(v, t) {
                if (Math.random() < 0.7) { tone(v, R(700, 1100), 'sine', t, 0.002, 0.05, 0.03, { to: R(1600, 2400), gt: 0.03 }); tone(v, R(1300, 1900), 'sine', t + 0.02, 0.003, 0.02, 0.2); return; }
                const n = 2 + (Math.random() * 3 | 0);
                for (let i = 0; i < n; i++) { const tt = t + i * 0.5; noise(v, tt, 0.02, 0.12, 'bandpass', 3000, 0, 3); fm(v, 1300, 2.3, 0.6, tt, 0.001, 0.03, 0.1); }
            },
        },
        market: {
            rate: 2.2,
            bed(s) { const n = loopSrc(s, pink, 'bandpass', 700, 1.2, 0.012); lfo(s, 0.5, 0.005, n.g.gain); },
            ev(v, t) {
                noise(v, t, R(0.12, 0.35), R(0.015, 0.03), 'bandpass', R(350, 1100), R(350, 1100), R(4, 7), { buf: pink, a: 0.04 });
                if (Math.random() < 0.5) noise(v, t + R(0.15, 0.3), R(0.1, 0.25), R(0.01, 0.025), 'bandpass', R(400, 1000), R(400, 1000), R(4, 7), { buf: pink, a: 0.04 });
            },
        },
        sky: {
            rate: 0.1,
            bed(s) { const w = loopSrc(s, pink, 'bandpass', 1100, 0.8, 0.035); lfo(s, 0.08, 400, w.f.frequency); lfo(s, 0.13, 0.02, w.g.gain); },
            ev(v, t) { noise(v, t, R(1.5, 2.5), 0.05, 'bandpass', 500, 1400, 0.7, { buf: pink, a: 0.8 }); },
        },
        night: { rate: 0.8, ev(v, t) { if (Math.random() < 0.8) cricket(v, t); else owl(v, t); } },
        sparkle: { rate: 0.18, ev: glint },
        stream: {
            rate: 3,
            bed(s) { loopSrc(s, white, 'bandpass', 1100, 0.6, 0.012); loopSrc(s, pink, 'lowpass', 700, 0.5, 0.02); },
            ev(v, t) { tone(v, R(500, 1300), 'sine', t, 0.004, 0.012, 0.04, { to: R(1400, 2200), gt: 0.03 }); },
        },
    };
    const THEMES = {
        meadow: 'meadow', lab: 'lab', factory: 'factory', energy: 'energy', studio: 'meadow', gold: 'sparkle+meadow', gym: 'meadow',
        mill: 'stream', sky: 'sky', path: 'meadow', grove: 'meadow+stream', sun: 'meadow', portal: 'shimmer', yard: 'factory',
        mine: 'mine', gem: 'mine+sparkle', deep: 'mine+lava', finale: 'shimmer+sparkle', cosmos: 'shimmer', market: 'market',
        forge: 'lava+factory', night: 'night', canyon: 'lava', bay: 'surf', cash: 'market+sparkle', lagoon: 'surf', beach: 'surf',
        cookie: 'market', tent: 'market',
    };
    const INDOOR = { mine: 1, gem: 1, deep: 1, portal: 1, cosmos: 1 };   // no sea, no crickets, muffled rain
    const amb = { layers: {}, sea: null, base: null, rain: null, wind: null, windN: null, nextThunder: 0 };
    function sub(g) { const n = ctx.createGain(); n.gain.value = g; n.connect(bus.ambient); return { out: n, g: n, rate: 1, src: [] }; }
    function killSink(x) { x.src.forEach(s => { try { s.stop(); } catch (e) { } }); setTimeout(() => { try { x.g.disconnect(); } catch (e) { } }, 200); }
    function startAmbient() {
        amb.sea = sub(AMB); amb.base = sub(AMB);
        const n = loopSrc(amb.sea, brown, 'lowpass', 460, 0.5, 0.035);
        lfo(amb.sea, 0.085, 0.02, n.g.gain); lfo(amb.sea, 0.05, 140, n.f.frequency);
        applyTheme();
    }
    function applyTheme() {
        const want = THEMES[st.theme].split('+'), t = now(), L = amb.layers;
        for (const k in L) if (!want.includes(k)) { const x = L[k]; delete L[k]; fadeTo(x.g.gain, 0, t, 2.5); setTimeout(() => killSink(x), 3000); }
        for (const k of want) if (!L[k]) {
            const x = sub(0); if (LAYERS[k].bed) LAYERS[k].bed(x);
            x.g.gain.setValueAtTime(0, t); x.g.gain.linearRampToValueAtTime(AMB, t + 3); L[k] = x;
        }
        fadeTo(amb.sea.g.gain, AMB * (INDOOR[st.theme] ? 0.15 : want.includes('surf') ? 0.6 : 1), t, 3);
        amb.applied = st.theme;
    }
    // Fire `rate` events per second (Poisson-ish) over one 200 ms tick into dest.
    function fire(fn, rate, dest) {
        for (let x = rate * 0.2; x > 0; x--) {
            if (Math.random() >= x) continue;
            const v = voice(dest, { pan: R(-0.7, 0.7), dist: R(0.15, 0.6) }, true); if (!v) return;
            fn(v, now() + R(0.01, 0.19)); done(v);
        }
    }
    function rainBed(s) { loopSrc(s, pink, 'bandpass', 2400, 0.35, 0.12); loopSrc(s, brown, 'lowpass', 300, 0.6, 0.06); }
    function windBed(s) { return loopSrc(s, pink, 'bandpass', 500, 0.9, 0.1); }
    function ambTick() {
        if (!ctx || ctx.state !== 'running' || st.muted) return;
        const t = now(), n = st.night, ind = !!INDOOR[st.theme];
        for (const v of voices.list.slice()) if (v.end < t - 1.5) release(v);   // safety sweep
        if (!ind && n > 0.3) fire(cricket, 0.9 * n, amb.base.out);
        for (const k in amb.layers) { const d = LAYERS[k]; if (d.ev) fire(d.ev, d.rate * (d.day ? 1 - 0.9 * n : 1), amb.layers[k].out); }
        // Weather: rain and wind beds are created the first time they are needed, then just faded.
        const r = st.rain * (ind ? 0.35 : 1) + (st.storm ? 0.25 : 0);
        if (r > 0.01 && !amb.rain) { amb.rain = sub(0); rainBed(amb.rain); }
        if (amb.rain) amb.rain.g.gain.setTargetAtTime(AMB * Math.min(1, r), t, 0.8);
        if (r > 0.1 && !ind) fire((v, tt) => tone(v, R(1200, 2600), 'sine', tt, 0.002, 0.01, 0.03, { to: R(2000, 3500) }), r * 4, amb.base.out);
        const w = st.wind + (st.storm ? 0.4 : 0);
        if (w > 0.01 && !amb.wind) { amb.wind = sub(0); amb.windN = windBed(amb.wind); }
        if (amb.wind && Math.random() < 0.25) { amb.wind.g.gain.setTargetAtTime(AMB * Math.min(1.2, w) * R(0.55, 1.1), t, 0.6); amb.windN.f.frequency.setTargetAtTime(R(300, 1000), t, 0.8); }
        if (st.storm && t > amb.nextThunder) { amb.nextThunder = t + R(9, 26); play('thunder', { distance: R(0.15, 1) }); }
        if (M.on) { M.lp.frequency.setTargetAtTime(6500 - 2900 * n, t, 1); M.padLP.frequency.setTargetAtTime(1400 - 500 * n, t, 1); }
    }

    // ---------- Generative music: toy lo-fi, 92 bpm, 16th note grid, lookahead scheduler ----------
    // Day: C major pentatonic melody over I vi IV V style chords. Night: A dorian chords (D9, Bm7 carry the
    // dorian F#) with an A minor pentatonic melody. Sections are 8 bars: chords from one or two seeded 4 bar
    // progressions, melody phrases A A' B A'' (2 bars each), so it varies but still sounds composed.
    // Layers (fade in by intensity): pad always, bass, mel (marimba), drums (brushed hat, brush, soft kick), arp (kalimba).
    const MUSIC = {
        bpm: 92, stepsPerBar: 16, sectionBars: 8, swing: 0.28, lookahead: 0.12, tickMs: 25,
        day: {
            root: 60, scale: [0, 2, 4, 7, 9],
            chords: { I: [0, [0, 4, 7, 14]], ii: [2, [0, 3, 7, 10]], iii: [4, [0, 3, 7, 10]], IV: [5, [0, 4, 7, 11]], V: [7, [0, 4, 7, 9]], Vsus: [7, [0, 5, 7, 10]], vi: [9, [0, 3, 7, 10]] },
            progs: [['I', 'vi', 'IV', 'V'], ['IV', 'V', 'iii', 'vi'], ['I', 'iii', 'IV', 'Vsus'], ['vi', 'IV', 'I', 'V'], ['I', 'IV', 'ii', 'Vsus'], ['IV', 'I', 'ii', 'V']],
        },
        night: {
            root: 57, scale: [0, 3, 5, 7, 10],
            chords: { i: [0, [0, 3, 7, 10, 14]], ii: [2, [0, 3, 7, 10]], bIII: [3, [0, 4, 7, 11]], IV: [5, [0, 4, 7, 10, 14]], v: [7, [0, 3, 7, 10]], bVII: [10, [0, 4, 7, 11]] },
            progs: [['i', 'IV', 'i', 'v'], ['bIII', 'bVII', 'i', 'IV'], ['i', 'ii', 'bIII', 'IV'], ['i', 'bVII', 'IV', 'i'], ['bIII', 'IV', 'i', 'i']],
        },
        layers: { pad: [0, 0], bass: [0.1, 0.3], mel: [0.3, 0.5], drums: [0.55, 0.75], arp: [0.8, 0.95] },
    };
    const SPB = 60 / MUSIC.bpm / 4;   // seconds per 16th
    const M = { on: false, next: 0, step: 0, sb: 8, sec: 0, mode: 'day', chords: [], chord: null, phr: [], lay: {}, tgt: {}, mix: null, lp: null, padLP: null, bassPat: 0, arpI: 0, lastSting: {} };
    function rng32(a) { return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
    const smooth = (x, a, b) => (b <= a ? 1 : clamp((x - a) / (b - a), 0, 1));
    const degMidi = (K, d) => { const n = K.scale.length, o = Math.floor(d / n); return K.root + 12 + K.scale[((d % n) + n) % n] + 12 * o; };
    function chordOf(mode, name) { const K = MUSIC[mode], c = K.chords[name], r = K.root + c[0]; return { root: r, iv: c[1], pcs: c[1].map(i => (r + i) % 12) }; }
    function voicing(ch) { const out = []; ch.iv.forEach(i => { let m = ch.root + 12 + i; while (m >= 76) m -= 12; while (m < 55) m += 12; if (!out.includes(m)) out.push(m); }); return out.sort((a, b) => a - b); }
    const bassRoot = ch => { let b = (ch.root % 12) + 36; if (b < 38) b += 12; return b; };
    function snapChord(m, pcs) { if (pcs.includes(m % 12)) return m; for (const d of [1, -1, 2, -2]) if (pcs.includes((m + d + 120) % 12)) return m + d; return m; }
    const CELLS = [[0], [0, 2], [2], [0, 3], [], [0, 2, 3], [0], [0, 2]];   // 16th offsets inside a beat
    const MOVES = [-2, -1, -1, 0, 1, 1, 1, 2, -3, 3];
    function phrase(r) {
        const out = new Array(32).fill(null); let d = 2 + (r() * 3 | 0);
        for (let b = 0; b < 8; b++) {
            let cell = CELLS[r() * CELLS.length | 0];
            if (b === 6 && r() < 0.5) cell = [0];          // a longer note...
            if (b === 7 && r() < 0.65) cell = [];          // ...then a breath at the end of the phrase
            for (const o of cell) { d = clamp(d + MOVES[r() * MOVES.length | 0], -2, 6); out[b * 4 + o] = { d, v: o ? R(0.6, 0.8) : R(0.8, 1), k: r() }; }
        }
        return out;
    }
    const BASS_PATS = [{ 0: [0, 6], 8: [7, 4] }, { 0: [0, 3], 6: [7, 1], 8: [0, 3], 14: [12, 1] }, { 0: [0, 5], 10: [7, 2], 12: [0, 2] }];
    function newSection() {
        M.sec++; M.sb = 0;
        const K = MUSIC[M.mode], r = rng32(st.seed + M.sec * 7919);
        const p1 = K.progs[r() * K.progs.length | 0], p2 = r() < 0.5 ? p1 : K.progs[r() * K.progs.length | 0];
        M.chords = p1.concat(p2);
        const A = phrase(r), B = phrase(r), V = phrase(r), A2 = A.slice(), A3 = A.slice();
        for (let i = 24; i < 32; i++) A2[i] = V[i];                                           // A': new ending
        let last = -1;
        for (let i = 0; i < 32; i++) if (A3[i]) { A3[i] = Object.assign({}, A3[i], { d: A3[i].d + (i < 16 ? 0 : 1) }); last = i; }
        if (last >= 0) A3[last] = Object.assign({}, A3[last], { d: K.scale.length, v: 0.85, k: 0 });   // A'': lifted, ends on the tonic
        M.phr = [A, A2, B, A3]; M.bassPat = r() * BASS_PATS.length | 0; M.arpI = 0;
    }
    function startMusic() {
        M.mix = ctx.createGain(); M.lp = biquad('lowpass', 6500, 0.5); M.mix.connect(M.lp); M.lp.connect(bus.music);
        for (const k in MUSIC.layers) { const g = ctx.createGain(); g.gain.value = 0; g.connect(M.mix); M.lay[k] = g; }
        M.padLP = biquad('lowpass', 1400, 0.4); M.padLP.connect(M.lay.pad);
        M.on = true; M.next = now() + 0.1; M.step = 0; M.sb = 8; setLayers(true);
    }
    function setLayers(snap) {
        const t = now();
        for (const k in M.lay) {
            const [a, b] = MUSIC.layers[k], v = k === 'pad' ? 1 : smooth(st.intensity, a, b); M.tgt[k] = v;
            if (snap) M.lay[k].gain.setValueAtTime(v, t); else M.lay[k].gain.setTargetAtTime(v, t, 0.9);
        }
    }
    const live = k => M.tgt[k] > 0.01 || M.lay[k].gain.value > 0.01;
    function musicTick() {
        if (!M.on || !ctx || ctx.state !== 'running') return;
        const t = now();
        if (M.next < t - 0.25) M.next = t + 0.05;   // after a stall resync instead of bursting notes
        while (M.next < t + MUSIC.lookahead) { step(M.step, M.next); M.next += SPB; M.step++; }
    }
    function bar(t) {
        const want = st.night > 0.6 ? 'night' : st.night < 0.4 ? 'day' : M.mode;
        M.sb++;
        if (M.sb >= MUSIC.sectionBars || want !== M.mode) { M.mode = want; newSection(); }
        M.chord = chordOf(M.mode, M.chords[M.sb]);
        if (!st.muted && st.bus.music > 0) voicing(M.chord).forEach(m => padNote(sink(M.padLP), m, t, SPB * 16, 0.028));
    }
    function step(s, t) {
        const sb = s % 16;
        if (sb === 0) bar(t);
        if (st.muted || st.bus.music <= 0) return;
        const tt = t + (sb % 4 === 2 ? SPB * MUSIC.swing : sb % 2 ? SPB * 0.12 : 0), ch = M.chord, n = st.night, K = MUSIC[M.mode];
        if (live('bass')) { const p = BASS_PATS[M.bassPat][sb]; if (p) bassNote(sink(M.lay.bass), bassRoot(ch) + p[0], tt, p[1] * SPB * 0.95, sb ? 0.75 : 1); }
        if (live('mel')) {
            const ps = (M.sb % 2) * 16 + sb, e = M.phr[M.sb >> 1][ps], dens = 0.45 + 0.55 * smooth(st.intensity, 0.3, 0.8);
            if (e && (e.k < dens || ps % 8 === 0)) {
                let m = degMidi(K, e.d); if (ps % 8 === 0) m = snapChord(m, ch.pcs);
                mallet(sink(M.lay.mel), mtof(m), tt + R(-0.006, 0.006), 0.12 * e.v, 0.85, 1 - 0.6 * n);
            }
        }
        if (live('drums')) {
            const d = sink(M.lay.drums), hv = 1 - 0.45 * n;
            if (sb % 2 === 0) hat(d, tt, (sb % 4 === 2 ? 1 : 0.55) * hv);
            else if (st.intensity > 0.9 && Math.random() < 0.5) hat(d, tt, 0.3 * hv);
            if (sb === 4 || sb === 12) brush(d, tt, 1);
            if (sb === 0 || sb === 10) kick(d, tt, sb ? 0.7 : 1);
        }
        if (live('arp') && sb % 2 === 0 && Math.random() < 0.8) {
            const vc = voicing(ch).map(m => m + 12), i = M.arpI++ % (vc.length * 2 - 2 || 1), idx = i < vc.length ? i : vc.length * 2 - 2 - i;
            kalimba(sink(M.lay.arp), mtof(vc[clamp(idx, 0, vc.length - 1)]), tt, 0.045);
        }
    }
    // Instruments. Pads: triangle + sine, slightly detuned, 0.9 s swell, long release so chords crossfade.
    function padNote(v, m, t, len, peak) {
        const f = mtof(m) * (v.rate || 1), g = ctx.createGain(), a = ctx.createOscillator(), b = ctx.createOscillator(), end = t + len + 2.6;
        a.type = 'triangle'; b.type = 'sine'; a.frequency.value = f; b.frequency.value = f; a.detune.value = -7; b.detune.value = 6;
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + 0.9); g.gain.setValueAtTime(peak, t + len); g.gain.setTargetAtTime(0, t + len, 0.5);
        a.connect(g); b.connect(g); g.connect(v.out); a.start(t); b.start(t); a.stop(end); b.stop(end);
        track(v, a, [], end); track(v, b, [g], end);
    }
    // Round bass: sine plus a quiet triangle, lowpassed at 520 Hz, quick pluck then soft sustain.
    function bassNote(v, m, t, len, vel) {
        const f = mtof(m) * (v.rate || 1), g = ctx.createGain(), a = ctx.createOscillator(), b = ctx.createOscillator(), bg = ctx.createGain(), lp = biquad('lowpass', 520, 0.6), end = t + len + 0.6;
        a.type = 'sine'; b.type = 'triangle'; a.frequency.value = f; b.frequency.value = f; bg.gain.value = 0.35;
        b.connect(bg); bg.connect(lp); a.connect(lp); lp.connect(g); g.connect(v.out);
        g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.24 * vel, t + 0.012); g.gain.setTargetAtTime(0.13 * vel, t + 0.03, 0.18); g.gain.setTargetAtTime(0, t + len, 0.07);
        a.start(t); b.start(t); a.stop(end); b.stop(end); track(v, a, [lp, g], end); track(v, b, [bg], end);
    }
    const hat = (v, t, vel) => noise(v, t, 0.05, 0.035 * vel, 'bandpass', 6500, 0, 0.8, { a: 0.004 });
    const brush = (v, t, vel) => noise(v, t, 0.16, 0.03 * vel, 'bandpass', 2600, 1800, 0.6, { a: 0.01, buf: pink });
    const kick = (v, t, vel) => tone(v, 110, 'sine', t, 0.003, 0.18 * vel, 0.22, { to: 46, gt: 0.09 });

    // ---------- Stingers: in-key flourishes on the sfx bus, quantized to the next beat of the music clock ----------
    // Notes are [scale degree, time in beats, velocity, decay s]. Degree 5 = tonic an octave up (pentatonic).
    const STING = {
        plot: { dur: 2.4, bloom: 1.5, notes: [[0, 0, 0.8], [1, 0.25, 0.8], [2, 0.5, 0.85], [3, 0.75, 0.85], [4, 1, 0.9], [5, 1.25, 0.95], [7, 1.5, 1, 1.6]] },
        reset: { dur: 2.8, bloom: 2, notes: [[7, 0, 0.9], [5, 0.5, 0.85], [4, 1, 0.8], [2, 1.5, 0.8], [0, 2, 0.95, 1.8]] },
        max: { dur: 1.4, notes: [[2, 0, 0.7], [5, 0.5, 1, 1.3], [7, 0.5, 0.5, 1.3]] },
        code: { dur: 2, notes: [[1, 0, 0.7], [3, 0.25, 0.7], [2, 0.5, 0.75], [4, 0.75, 0.8], [6, 1, 0.9, 1.5]], trill: [8, 9] },
        achievement: { dur: 2.2, bloom: 1, notes: [[0, 0, 0.8], [2, 0.33, 0.8], [4, 0.66, 0.85], [5, 1, 1, 1.4], [7, 1, 0.6, 1.4]], trill: [10, 11] },
        tier: { dur: 2.5, fn: tierFn },   // same sound as play('tierUp'), but on the beat
    };
    function stingNotes(v, S, t) {
        if (S.fn) return S.fn(v, t);
        const K = MUSIC[M.mode], beat = SPB * 4;
        S.notes.forEach(([d, b, vel, dec]) => { const f = mtof(degMidi(K, d)); mallet(v, f, t + b * beat, 0.11 * vel, dec || 0.5); if (dec) fm(v, f, 3.5, 0.3, t + b * beat, 0.005, 0.03 * vel, dec); });
        if (S.bloom != null) {
            const ch = chordOf(M.mode, M.mode === 'day' ? 'I' : 'i'), tb = t + S.bloom * beat;
            voicing(ch).forEach(m => padNote(v, m, tb, 0.9, 0.03));
            bassNote(v, bassRoot(ch), tb, 1.0, 0.7);
        }
        if (S.trill) for (let i = 0; i < 8; i++) tone(v, mtof(degMidi(K, S.trill[i % 2])), 'sine', t + beat * 1.25 + i * SPB * 0.5, 0.003, 0.02 * (1 - i / 9), 0.1);
    }
    function stinger(kind, minDelay) {
        const S = STING[kind]; if (!S || !ok()) return false;
        // The same stinger twice within 2 s (for example plotBuilt() plus an explicit stinger('plot')) plays once.
        if (now() - (M.lastSting[kind] || -9) < 2) return false;
        M.lastSting[kind] = now();
        let t = now() + (minDelay || 0) + 0.02;
        if (M.on && ctx.state === 'running' && st.bus.music > 0) { let s = M.step, tt = M.next; while (s % 4 || tt < t) { s++; tt += SPB; } t = tt; }
        const v = voice(bus.sfx, {}); if (!v) return false;
        stingNotes(v, S, t); done(v); duck(S.dur, t);
        return true;
    }
    for (const k in STING) def('stinger_' + k, 'sfx', () => { }, { after: () => stinger(k) });

    // ---------- FX Lab previews: music layers and ambience layers as finite one-shots ----------
    function preview(v, t, dur, bed, ev, rate) {
        if (bed) bed(v);
        const beds = v.src.slice();
        if (ev) { const n = clamp(Math.round(rate * dur * 1.5), 3, 14); for (let i = 0; i < n; i++) ev(v, t + 0.2 + Math.random() * (dur - 0.8)); }
        const g = v.out.gain, base = g.value * AMB;
        g.setValueAtTime(0, t); g.linearRampToValueAtTime(base, t + 0.4); g.setValueAtTime(base, t + dur - 0.6); g.linearRampToValueAtTime(0, t + dur);
        beds.forEach(s => { try { s.stop(t + dur + 0.05); } catch (e) { } });
        v.end = t + dur + 0.1;
    }
    const PREV_MUSIC = {
        pads(v, t) { ['I', 'IV'].forEach((c, i) => voicing(chordOf(M.mode, M.mode === 'day' ? c : ['i', 'IV'][i])).forEach(m => padNote(v, m, t + i * SPB * 16, SPB * 16, 0.035))); },
        marimba(v, t) { const K = MUSIC[M.mode], p = phrase(rng32(st.seed)); p.forEach((e, i) => { if (e) mallet(v, mtof(degMidi(K, e.d)), t + i * SPB, 0.12 * e.v, 0.85); }); },
        bass(v, t) { const ch = chordOf(M.mode, M.mode === 'day' ? 'I' : 'i'); for (let b = 0; b < 2; b++) for (const k in BASS_PATS[1]) { const p = BASS_PATS[1][k]; bassNote(v, bassRoot(ch) + p[0], t + (b * 16 + +k) * SPB, p[1] * SPB, 0.9); } },
        drums(v, t) { for (let s = 0; s < 32; s++) { const sb = s % 16, tt = t + s * SPB + (sb % 4 === 2 ? SPB * MUSIC.swing : 0); if (sb % 2 === 0) hat(v, tt, sb % 4 === 2 ? 1 : 0.55); if (sb === 4 || sb === 12) brush(v, tt, 1); if (sb === 0 || sb === 10) kick(v, tt, 1); } },
        arp(v, t) { const vc = voicing(chordOf(M.mode, M.mode === 'day' ? 'I' : 'i')).map(m => m + 12); for (let i = 0; i < 16; i++) kalimba(v, mtof(vc[[0, 1, 2, 3, 2, 1][i % 6] % vc.length]), t + i * SPB * 2, 0.05); },
    };
    for (const k in PREV_MUSIC) def('music_' + k, 'music', PREV_MUSIC[k]);
    const AMB_PREV = {
        sea: v => { const n = loopSrc(v, brown, 'lowpass', 460, 0.5, 0.05); lfo(v, 0.3, 0.02, n.g.gain); },
        rain: rainBed, wind: s => { const w = windBed(s); lfo(s, 0.2, 300, w.f.frequency); },
        storm: s => { rainBed(s); windBed(s); },
    };
    def('amb_sea', 'ambient', (v, t) => preview(v, t, 4, AMB_PREV.sea));
    def('amb_crickets', 'ambient', (v, t) => preview(v, t, 4, null, cricket, 1.2));
    def('amb_rain', 'ambient', (v, t) => preview(v, t, 4, AMB_PREV.rain, (x, tt) => tone(x, R(1200, 2600), 'sine', tt, 0.002, 0.01, 0.03, { to: R(2000, 3500) }), 3));
    def('amb_wind', 'ambient', (v, t) => preview(v, t, 4, AMB_PREV.wind));
    def('amb_storm', 'ambient', (v, t) => preview(v, t, 5, AMB_PREV.storm), { after: () => play('thunder', { distance: 0.35 }) });
    for (const k in LAYERS) def('amb_' + k, 'ambient', (v, t) => preview(v, t, 4, LAYERS[k].bed, LAYERS[k].ev, LAYERS[k].rate));

    // ---------- CATALOG: every sound, for the FX Lab and as the Roblox rebuild reference ----------
    // Fields: id, name, category, desc, spec (how it is synthesized here), roblox (how to rebuild it),
    // api (how game code triggers it), bus (web bus it plays on). Every id is playable with AUDIO.play(id).
    const CATALOG = [];
    const cat = (category, id, name, desc, spec, roblox, api) => CATALOG.push({ id, name, category, desc, spec, roblox, api: api || "AUDIO.play('" + id + "')" });
    const STEP_VAR = 'Every step gets a fresh random pitch (plus or minus 1.5 semitones, never within 0.18 of the previous roll), length (0.85 to 1.15x) and level (0.8 to 1.2x).';
    const STEP_RBX = 'Record 4 variations, pick randomly without repeating the last one, PlaybackSpeed random 0.92 to 1.08, Volume random 0.2 to 0.3, SoundGroup SFX, 3D Sound on the character feet. Map Humanoid.FloorMaterial to the surface.';

    cat('Gameplay', 'buy', 'Brick snap', 'A plastic brick snapping into place when the player buys one upgrade level.',
        'Bandpass white noise click (3.4 kHz, Q 2.2, 28 ms) + sine thump 170 to 90 Hz (50 ms) + triangle knock at 523 Hz x 1.0595^step through a 3.2 kHz lowpass (3 ms attack, 130 ms decay) + quiet sine octave (80 ms). step rises by 1 for each buy within 900 ms of the previous one, capped at 14, and resets after 900 ms idle.',
        'Record a real brick snap (two bricks pressed together, trimmed to 80 to 120 ms). SoundGroup SFX, Volume 0.5. Pitch ladder: PlaybackSpeed = 1.0595^step (step +1 per buy inside 0.9 s, max 14, reset after 0.9 s idle), or PitchShiftSoundEffect.Octave = 1.0595^step to keep the length. EqualizerSoundEffect HighGain -3 dB. No reverb.',
        "AUDIO.buy(false) or AUDIO.play('buy', { big: false })");
    cat('Gameplay', 'buyBig', 'Brick snap (final level)', 'A fuller brick snap for the buy that completes an upgrade.',
        'Same as buy (shares the same pitch ladder; also reached with play(buy, { big: true })) with a louder knock (0.28 instead of 0.19) and a sine fifth (1.5x) 50 ms later with a 300 ms decay.',
        'Same brick snap asset on the same ladder plus a layered soft glockenspiel note a fifth above (PlaybackSpeed x1.5 of the ladder value). SoundGroup SFX, Volume 0.6.',
        'AUDIO.buy(true)');
    cat('Gameplay', 'autoTick', 'Automation tick', 'A very quiet tick for purchases made by automation, so idle progress is audible but never tiring.',
        'Bandpass white noise at 5 kHz, Q 3, 18 ms, peak 0.07, on the ui bus. Low priority: skipped when the voice pool is nearly full. The game throttles it to one per 180 ms.',
        'Tiny plastic tick (a fingernail on a brick). SoundGroup UI, Volume 0.12, PlaybackSpeed random 0.95 to 1.05. Throttle to one per 0.18 s.',
        'AUDIO.autoTick()');
    cat('Gameplay', 'maxed', 'Upgrade maxed', 'A bright rising arpeggio when an upgrade reaches its max level.',
        'Four mallet notes (sine + short 4x overtone + triangle octave) on G5, B5, D6, G6, 60 ms apart, 500 ms decay, then an FM bell on G6 (ratio 3.01, index 0.5, 0.9 s).',
        'One marimba or glockenspiel sample at C5 played 4 times 0.06 s apart with PlaybackSpeed 1.498, 1.888, 2.245, 2.997 (G5 B5 D6 G6), then a small bell. SoundGroup SFX, Volume 0.45, ReverbSoundEffect WetLevel -14 dB.',
        'AUDIO.maxed()');
    cat('Gameplay', 'plotBuilt', 'Plot built', 'A shower of bricks landing as a new plot is built, followed by the plot fanfare on the next beat.',
        '16 bandpass noise snaps (2.6 to 4.8 kHz, 28 ms) 45 ms apart with jitter, every third with a triangle knock (380 to 700 Hz), then a sine thump 110 to 55 Hz at 0.72 s. Calls stinger(plot) at least 0.7 s later and ducks music and ambience for 2.2 s.',
        'Brick pour recording (a handful of bricks dropped on a baseplate, about 0.8 s) plus a low thump. SoundGroup SFX, Volume 0.6. Then start stinger_plot on the next music beat. Duck the Music group to 45% and Ambient to 30% for 2.2 s with TweenService.',
        'AUDIO.plotBuilt()');
    cat('Gameplay', 'reset', 'Prestige reset', 'Bricks collapse, a whoosh sweeps up, a deep boom lands, then the reset stinger resolves it.',
        'crumble + pink noise bandpass sweep 300 to 3200 Hz over 0.7 s + boom at 0.38 s (sine 120 to 38 Hz over 0.6 s and brown noise lowpass 900 to 120 Hz). Calls stinger(reset) at least 0.5 s later and ducks music and ambience for 2.6 s.',
        'Layer three Sounds: brick collapse (see crumble), an air whoosh and a sub boom (Volume 0.7, EqualizerSoundEffect LowGain +4 dB). SoundGroup SFX. Then stinger_reset on the next beat. Duck Music and Ambient for 2.6 s.',
        'AUDIO.reset()');
    cat('Gameplay', 'crumble', 'Bricks crumble', 'A pile of bricks tumbling apart.',
        '26 bandpass noise clicks (1.8 to 4.4 kHz, 20 to 50 ms) whose spacing stretches over 1.1 s (time = k^1.6) while pitch and level fall; every second one adds a triangle knock (300 to 700 Hz). Under it a brown noise rumble, lowpass 500 to 120 Hz for 1 s.',
        'Record plastic bricks spilling out of a tub onto a table (about 1.2 s). SoundGroup SFX, Volume 0.55, PlaybackSpeed random 0.95 to 1.05, ReverbSoundEffect WetLevel -16 dB.');
    cat('Gameplay', 'rise', 'Plot island rises', 'A plot island rising out of the water and settling into place.',
        'Brown noise lowpass sweeping 180 to 700 Hz with a 0.9 s swell, a sine 55 to 110 Hz rising over 1.7 s, seven bubble blips (420 to 900 Hz doubling in 40 ms) after 0.9 s, then a settle thunk at 1.8 s (sine 110 to 60 Hz + 2.5 kHz noise click).',
        'Stone grinding rumble with a PlaybackSpeed tween 0.8 to 1.1 over 1.8 s, water trickles, and a heavy thunk at the end. SoundGroup SFX, Volume 0.55, EqualizerSoundEffect HighGain -6 dB.');
    cat('Gameplay', 'coin', 'Coin', 'A soft retro coin pickup.',
        'Square waves through a 3 kHz lowpass: B5 (988 Hz, 70 ms) then E6 (1319 Hz, 350 ms decay) 70 ms later, plus a quiet sine E7 sparkle.',
        'Two note coin (B5 then E6) from a soft square synth with a lowpass so it is never piercing. SoundGroup SFX, Volume 0.35. For coin streams raise PlaybackSpeed by 1.0595 per coin inside 0.3 s, up to +7 steps.');
    cat('Gameplay', 'codeFound', 'Code found', 'A magical glissando when the player finds a secret code.',
        'Six mallet notes C5 D5 E5 G5 A5 C6, 50 ms apart (0.4 s decay), a held FM bell on C6 (ratio 3.5, 1.4 s) and a faint white noise shimmer bandpassed 5 to 8 kHz.',
        'Harp or celesta glissando up the C major pentatonic (about 1.5 s). SoundGroup SFX, Volume 0.5, ReverbSoundEffect WetLevel -10 dB, DecayTime 2.2. Add stinger_code for big discoveries.');
    cat('Gameplay', 'achievement', 'Achievement', 'Two bell dings and a sparkle trill for unlocking an achievement.',
        'FM bells (ratio 3.5, index 0.5) on G5 then C6 120 ms apart (0.9 s and 1.3 s decay), a soft mallet C5 underneath, then six alternating sine sparkles C7 and D7 50 ms apart, fading out.',
        'Two glockenspiel notes G5 and C6 plus a short high sparkle of tiny bells. SoundGroup SFX, Volume 0.5, ReverbSoundEffect WetLevel -12 dB. Add stinger_achievement for major ones.');
    cat('Gameplay', 'drone', 'Automation drone', 'The tiny buzz of an automation drone flying past.',
        'Two sawtooths 190 and 193.5 Hz (slow beating) through a bandpass 1.1 kHz Q 2.5, pitch sliding down 6% over 1 s like a doppler pass, 26 Hz buzz tremolo, 0.15 s fade in, 0.25 s fade out, peak 0.03.',
        'Small fan or electric toothbrush buzz (or a bandpassed saw). Looped Sound parented to the drone model: RollOffMode InverseTapered, RollOffMinDistance 6, RollOffMaxDistance 60. SoundGroup SFX, Volume 0.25, PlaybackSpeed 1.0 easing to 0.94 as it flies away.');
    cat('Gameplay', 'splash', 'Splash', 'A water splash when something lands in the sea.',
        'Pink noise lowpass sweeping 2.4 kHz to 300 Hz over 0.6 s, a white noise spray bandpass 3.5 kHz for 0.25 s, and four bubble blips (sine 400 to 800 Hz, doubling in 40 ms).',
        'Medium splash recording (about 0.7 s). SoundGroup SFX, Volume 0.5, PlaybackSpeed random 0.9 to 1.1, 3D Sound at the splash position.',
        'AUDIO.splash()');
    cat('Gameplay', 'whale', 'Whale', 'A distant whale call rolling over the sea, ending in a splash.',
        'Sine 180 to 260 to 150 Hz over 2 s (0.4 s attack) with a quieter partial 360 to 520 to 300 Hz, then the splash 1.2 s in. Ambient bus, so it is reverb wet.',
        'Soft whale song clip (2 s) plus the splash. SoundGroup Ambient, Volume 0.4, ReverbSoundEffect WetLevel -6 dB, EqualizerSoundEffect HighGain -8 dB so it sounds far away.',
        'AUDIO.whale()');
    cat('Gameplay', 'tierUp', 'City tier up', 'A big 2.5 s celebration when the city grows a tier (Village, Town, City, Metropolis).',
        'Soft brass (two saws 10 cents apart, lowpass opening from 1.5x to 6x the pitch, capped at 4 kHz) plays C4 E4 G4 C5 as 0.13 s steps, then a held C major chord (C3 C4 E4 G4 C5, 1.45 s) with a sine timpani 65 Hz, a white noise cymbal swell (bandpass 7 to 5 kHz, 0.52 s rise into the chord, 1.6 s decay) and mallet sparkles C6 E6 G6 C7. Always C major, which also fits the night key. Ducks music and ambience 2.5 s.',
        'Render one 2.5 s brass fanfare (French horn or soft trumpet section) with a cymbal swell and timpani hit. SoundGroup SFX, Volume 0.7, ReverbSoundEffect WetLevel -8 dB, DecayTime 2.2. Duck Music to 45% and Ambient to 30% for 2.5 s. For the on-beat version wait for the next music beat (see stinger_tier).',
        "AUDIO.play('tierUp') (immediate) or AUDIO.stinger('tier') (on the next beat)");
    cat('Gameplay', 'letterDrop', 'Sign letter drop', 'A chunky plastic thunk when a giant sign letter lands.',
        'Sine 130 to 55 Hz (0.2 s, peak 0.26), bandpass noise click 1.8 kHz (30 ms), hollow triangle 240 Hz through a 900 Hz lowpass (0.12 s) and three tiny 3 kHz rattles at 40 to 90 ms. Each call shifts pitch randomly by up to 5% so a word of letters never repeats exactly.',
        'Large hollow plastic thunk (drop a big DUPLO brick or plastic box lid on a table, about 0.25 s). SoundGroup SFX, Volume 0.55, PlaybackSpeed random 0.95 to 1.05 per letter, EqualizerSoundEffect LowGain +3 dB. Play once per letter as it lands.');
    cat('Gameplay', 'towerRise', 'Tower rise', 'A skyscraper growing out of the ground with a rising rumble and an ascending shimmer.',
        'Brown noise lowpass sweeping 150 to 600 Hz (0.6 s swell, 0.8 s decay), sine 45 to 90 Hz rising over 1.3 s, eight FM glints (ratio 3.01) climbing the C pentatonic from C5 to E6, 0.11 s apart from 0.35 s, and a faint white noise shimmer sweeping 3 to 7 kHz. About 1.4 s.',
        'Stone grinding rumble with PlaybackSpeed tweened 0.8 to 1.2 over 1.4 s, plus a rising chime run (glockenspiel C5 sample stepped up the pentatonic). SoundGroup SFX, Volume 0.5, EqualizerSoundEffect HighGain -4 dB. 3D Sound at the tower base.');
    cat('Gameplay', 'milestone', 'Number milestone', 'A short triumphant fanfare for passing a number milestone such as 1K, 1M or 1B.',
        'Soft brass ta-ta-taaa on G4 G4 C5 (0.12 s apart), then E5 held 1 s over a brass C major chord (C4 E4 G4), a sine timpani 65 Hz and three mallet sparkles E6 G6 C7. About 1.8 s. Ducks music and ambience 1.8 s.',
        'Render a 1.8 s brass fanfare (triplet pickup into a held major chord). SoundGroup SFX, Volume 0.6, ReverbSoundEffect WetLevel -10 dB. Duck Music and Ambient for 1.8 s.');

    cat('UI', 'tap', 'Tap', 'A soft pop for buttons and taps.',
        'Sine 880 Hz (3 ms attack, 60 ms decay) + sine 1320 Hz 20 ms later (50 ms). Dry ui bus.',
        'Short soft pop or bubble click (about 70 ms). SoundGroup UI, Volume 0.3, no effects.', 'AUDIO.tap()');
    cat('UI', 'tick', 'Tick', 'A soft tick for small UI changes such as scroll snaps, steppers and counters.',
        'Bandpass noise 2.6 kHz, Q 4, 12 ms + sine 1250 Hz, 25 ms.',
        'Tiny plastic tick. SoundGroup UI, Volume 0.2, PlaybackSpeed random 0.97 to 1.03.');
    cat('UI', 'hover', 'Hover', 'A barely audible cue when the pointer moves onto a button (desktop only).',
        'Sine 1400 rising to 1520 Hz, 6 ms attack, 35 ms decay, peak 0.018. Low priority.',
        'Very soft high blip. SoundGroup UI, Volume 0.08. Skip on touch devices. Rate limit to one per 0.08 s.');
    cat('UI', 'toggle', 'Toggle', 'A two note switch click that rises when turning on and falls when turning off.',
        'Noise click 3 kHz (10 ms) + sine 600 then 900 Hz 45 ms apart; reversed (900 then 600) when opts.on is false.',
        'Light switch click plus two soft blips. SoundGroup UI, Volume 0.3. Off state: same asset at PlaybackSpeed 0.85.',
        "AUDIO.play('toggle', { on: true })");
    cat('UI', 'open', 'Panel open', 'A sheet or panel sliding open.',
        'Sine 660 Hz then 990 Hz 50 ms later (about 90 ms each) with a faint pink noise swish bandpassed 1.2 to 3 kHz.',
        'Soft upward blip plus a paper swish. SoundGroup UI, Volume 0.3.', 'AUDIO.open()');
    cat('UI', 'close', 'Panel close', 'A sheet or panel closing.',
        'Sine 740 Hz then 520 Hz 50 ms later with a faint swish sweeping 2.6 to 1 kHz.',
        'The open asset played at PlaybackSpeed 0.8, Volume 0.28, SoundGroup UI.', 'AUDIO.close()');
    cat('UI', 'stamp', 'Stamp', 'A heavy UI slam for big confirmations such as prestige ready or reward claimed.',
        'Sine 150 to 48 Hz over 0.2 s (280 ms decay), white noise lowpass 2.4 kHz to 400 Hz for 60 ms, triangle 330 Hz body, pink noise bandpass 900 to 300 Hz tail.',
        'Rubber stamp or book slam. SoundGroup UI, Volume 0.5, EqualizerSoundEffect LowGain +3 dB.');
    cat('UI', 'deny', 'Deny', 'Two low soft bonks when the player cannot afford something.',
        'Square 220 Hz then 175 Hz 90 ms later, each through a lowpass (1.1 kHz and 900 Hz), 120 to 150 ms decay.',
        'Two soft low wooden bonks. SoundGroup UI, Volume 0.3. Never a harsh buzzer.', 'AUDIO.deny()');
    cat('UI', 'error', 'Error', 'Three falling notes for a failed action such as a wrong code.',
        'Triangles 330, 294, 247 Hz, 85 ms apart, lowpass 1.6 kHz, 120 ms decay.',
        'Marimba C5 sample at PlaybackSpeed 0.630, 0.561, 0.472 (E4 D4 B3), 0.085 s apart. SoundGroup UI, Volume 0.3.');

    cat('World', 'shutter', 'Camera shutter', 'The camera shutter for photo mode.',
        'Two mechanical clicks 70 ms apart (bandpass noise 2.8 kHz and 1.9 kHz, 12 to 20 ms, each with a sine thump 140 to 80 Hz) and a short film advance whirr (bandpass noise 1.2 to 2.4 kHz, Q 3, 180 ms).',
        'Real camera shutter recording. SoundGroup SFX, Volume 0.45.');
    cat('World', 'camWhoosh', 'Camera fly', 'An air swoosh when the camera flies to a new spot.',
        'Pink noise bandpass sweeping 260 Hz to 2.2 kHz (Q 1.4, 220 ms attack, 550 ms) plus a faint white noise air layer sweeping 2.5 to 5 kHz.',
        'Soft air whoosh. SoundGroup SFX, Volume 0.3, PlaybackSpeed by fly distance (0.9 short, 1.1 long).');
    cat('World', 'lightning', 'Lightning crack', 'The sharp crack of a close lightning strike.',
        'Highpassed white noise burst (1.8 kHz, 120 ms), nine random crackles within 0.3 s (bandpass 2 to 6 kHz, 6 to 20 ms) and a sine thump 90 to 40 Hz. Ambient bus.',
        'Lightning crack recording. SoundGroup Ambient, Volume 0.6, synced with the flash.');
    cat('World', 'thunder', 'Thunder', 'Thunder whose delay, brightness and roll depend on distance.',
        'distance d (0..1, default 0.4) delays the roll by d x 1.8 s; below 0.35 a lightning crack plays first. Roll: brown noise lowpass (900 - 600d) Hz sweeping to 90 Hz for 2.5 + 2d s, five random rumble bursts, and a sine 60 to 35 Hz swell. Level 0.5 x (1 - 0.65d).',
        'Two recordings (close crack plus roll, distant roll). SoundGroup Ambient. Start distance x 1.8 s after the flash. Volume 0.7 close down to 0.25 far; far ones add EqualizerSoundEffect HighGain -12 dB, MidGain -4 dB. ReverbSoundEffect WetLevel -6 dB.',
        "AUDIO.thunder(distance) or AUDIO.play('thunder', { distance })");
    cat('World', 'foghorn', 'Foghorn', 'The lighthouse foghorn, deep and distant.',
        'Sawtooths 98 and 98.7 Hz plus a sine 49 Hz through a lowpass 480 Hz Q 1.5; 0.35 s swell, hold to 1.6 s, fade out by 2.4 s while pitch sags 6%. Ambient bus.',
        'Foghorn or ship horn recording as a 3D Sound on the lighthouse. SoundGroup Ambient, Volume 0.4, EqualizerSoundEffect HighGain -10 dB, ReverbSoundEffect WetLevel -4 dB, DecayTime 3.');
    cat('World', 'gull', 'Seagull', 'Seagulls calling over the beach.',
        '2 or 3 calls about 0.3 s apart: triangle 1.2 to 1.5 kHz rising 1.5x in 70 ms then falling to 0.85x, lowpass 2.6 kHz, with a faint raspy bandpass noise.',
        'Gull call recordings (3 or 4 variations). SoundGroup Ambient, Volume 0.2, PlaybackSpeed random 0.9 to 1.1. Day only.');
    cat('World', 'fireworks', 'Fireworks', 'A firework whistle, burst and sparkling crackle.',
        'Launch: quiet sine 700 Hz to 1.9 kHz over 0.8 s with a pink noise hiss. Burst at 0.85 s: pink noise lowpass 2.2 kHz to 300 Hz + sine 90 to 40 Hz boom. Then 24 tiny bandpass crackles (3 to 6 kHz) over 1.2 s.',
        'Firework launch, burst and crackle recordings. SoundGroup SFX, Volume 0.5, ReverbSoundEffect WetLevel -6 dB, PlaybackSpeed random 0.9 to 1.1 per rocket.');
    cat('World', 'bubbles', 'Bubbles', 'A burst of little bubbles for fish tanks, lagoons and the lab.',
        'Nine sine blips over 0.9 s, each 380 to 950 Hz gliding up about 2x in 45 ms, 50 ms decay.',
        'Bubble pop recording. SoundGroup SFX, Volume 0.35.');
    cat('World', 'whistle', 'Train whistle', 'The Stud Express steam whistle as the train passes.',
        'Two chimes B4 (494 Hz) and D5 (587 Hz): each a triangle through a 2.4 kHz lowpass plus a quiet sine octave, scooping up 4% into pitch over 0.18 s, 5.5 Hz vibrato (6 cents), 0.14 s attack, 0.5 s hold, 0.25 s release. A breathy pink noise burst (bandpass 1.5 kHz to 900 Hz) starts it and a soft steam hiss (3 to 2 kHz) runs under it. About 0.9 s.',
        'Steam locomotive whistle recording (two chime, about 1 s), or two sine plus noise layers. 3D Sound on the locomotive so it pans and fades naturally: RollOffMode InverseTapered, RollOffMaxDistance 150. SoundGroup SFX, Volume 0.5, ReverbSoundEffect WetLevel -6 dB. For a doppler feel tween PlaybackSpeed 1.03 to 0.97 as it passes.');
    cat('World', 'chug', 'Train chug', 'One soft train chuff, meant to be repeated while the train moves.',
        'Pink noise lowpass sweeping 1.4 kHz to 350 Hz (8 ms attack, 110 ms), a small bandpass 2.6 kHz puff and a 70 Hz sine thump. Level and filter vary randomly by 10% per call. Low priority in the voice pool. Repeat 2 to 6 times per second depending on train speed, accent every fourth with vol 1 and the rest with vol 0.6.',
        'Record one steam chuff (or filtered noise burst, about 0.12 s). Looped chug pattern on the locomotive (3D Sound), PlaybackSpeed scaled with train speed (0.8 to 1.3). SoundGroup SFX, Volume 0.35, EqualizerSoundEffect HighGain -6 dB.');
    cat('World', 'shootingStar', 'Shooting star', 'A soft, high sparkle sweep for a shooting star at night.',
        'Sine gliding 2.6 kHz down to 1.5 kHz over 0.7 s through a 5 kHz lowpass (peak 0.03), eight tiny FM glints (ratio 3.01) stepping down from 3 kHz, 80 ms apart, fading out, and a faint noise sweep 6 to 3 kHz. About 0.8 s, ambient bus, quiet.',
        'Soft downward chime glissando with a light sparkle (render about 0.8 s). SoundGroup Ambient, Volume 0.15, ReverbSoundEffect WetLevel -4 dB. Night only.');
    cat('World', 'serpent', 'Sea serpent', 'A deep, playful sea creature roar and whoosh with a bubbly tail.',
        'Sawtooths 70 and 105 Hz through a resonant 520 Hz lowpass (Q 4) with a 22 Hz growl wobble (30 cents): pitch rises 0.8x to 1.3x over 0.5 s then sinks to 0.85x by 1 s, 0.25 s attack, 0.45 s hold, 0.35 s release. A pink noise whoosh (bandpass 300 to 1200 Hz), then a watery lowpass wash and twelve bubble blips from 0.8 s. About 1.6 s.',
        'Layer a friendly cartoon monster roar (pitched down, rounded with EqualizerSoundEffect HighGain -10 dB), a water whoosh and a bubble tail. SoundGroup SFX, Volume 0.55, ReverbSoundEffect WetLevel -6 dB. 3D Sound on the serpent.');
    cat('World', 'searchlight', 'Searchlight hum', 'A very quiet low electric hum while a searchlight sweeps.',
        'Sawtooth 60 Hz through a 300 Hz lowpass (peak 0.005) plus a sine 120 Hz (0.004), 0.2 s fade in, 0.5 s hold, 0.3 s fade out. About 1 s, ambient bus.',
        'Low electrical hum loop on the searchlight part (3D Sound, RollOffMaxDistance 40). SoundGroup Ambient, Volume 0.1, EqualizerSoundEffect HighGain -12 dB.');
    cat('World', 'step_grass', 'Footstep: grass', 'A soft footstep on grass.',
        'White noise bandpass sweeping 2.2 to 1.4 kHz (70 ms, 8 ms attack), a faint highpass rustle and a 90 Hz sine thud. ' + STEP_VAR, STEP_RBX + ' Grass, LeafyGrass, Ground.', "AUDIO.footstep('grass')");
    cat('World', 'step_stone', 'Footstep: stone', 'A footstep on stone or on bare plastic studs.',
        'Bandpass noise click 1.9 kHz (25 ms) and a sine knock 190 to 120 Hz (60 ms). ' + STEP_VAR, STEP_RBX + ' Plastic, SmoothPlastic, Slate, Concrete, Brick, Cobblestone.', "AUDIO.footstep('stone')");
    cat('World', 'step_metal', 'Footstep: metal', 'A footstep on a metal plate.',
        'Bandpass noise tick 3.2 kHz, an inharmonic FM clink (540 Hz, ratio 2.76, 160 ms) and a 110 Hz thud. ' + STEP_VAR, STEP_RBX + ' Metal, DiamondPlate, CorrodedMetal.', "AUDIO.footstep('metal')");
    cat('World', 'step_sand', 'Footstep: sand', 'A soft, hissy footstep on sand.',
        'White noise bandpass 3.8 to 2.6 kHz with a slow 20 ms attack (110 ms) plus pink noise lowpass 600 Hz. ' + STEP_VAR, STEP_RBX + ' Sand, Sandstone.', "AUDIO.footstep('sand')");
    cat('World', 'step_wood', 'Footstep: wood', 'A hollow footstep on wooden planks.',
        'Triangle 210 Hz through a 1.4 kHz lowpass (70 ms), sine 420 Hz (40 ms) and bandpass noise 950 Hz Q 2.5. ' + STEP_VAR, STEP_RBX + ' Wood, WoodPlanks.', "AUDIO.footstep('wood')");
    cat('World', 'step_water', 'Footstep: water', 'A splashy step in shallow water.',
        'Pink noise lowpass 1.8 kHz to 350 Hz (180 ms), a small bubble glide 520 to 1100 Hz and a faint 3 kHz spray. ' + STEP_VAR, STEP_RBX + ' Water (Humanoid in shallow water).', "AUDIO.footstep('water')");

    cat('Music', 'music_pads', 'Music: pads', 'Warm chord pads, the always-on base layer of the music.',
        'Per chord tone a triangle (-7 cents) and a sine (+6 cents), 0.9 s linear swell, held for the bar (2.6 s at 92 bpm), 0.5 s time constant release so chords crossfade. Voiced between G3 and E5, through a lowpass 1.4 kHz (900 Hz at night) and the music lowpass (6.5 kHz, 3.6 kHz at night).',
        'Render pad stems (8 bar loops at 92 bpm, day and night versions) or use a soft sustained pad sample per note. SoundGroup Music, Volume 0.35, ReverbSoundEffect WetLevel -8 dB, EqualizerSoundEffect HighGain -6 dB.',
        'Starts with AUDIO.unlock(). AUDIO.setMusicIntensity(0) leaves pads only.');
    cat('Music', 'music_marimba', 'Music: marimba melody', 'The toy marimba melody made of seeded phrases in A A2 B A3 form.',
        'Mallet voice (sine fundamental 0.85 s decay, 4x sine overtone 60 ms, triangle octave). The melody walks the pentatonic scale (moves of -3 to +3 degrees), strong beats snap to chord tones, 16th grid with 28% swing on offbeat 8ths and 6 ms timing jitter, density rises with intensity. Fades in between intensity 0.3 and 0.5; darker (less overtone) at night.',
        'One marimba or kalimba sample at C5; pitch each note with PlaybackSpeed = 2^((midi - 72) / 12). Schedule from a Luau sequencer on beat time (92 bpm, 16th = 0.163 s). SoundGroup Music, Volume 0.4, ReverbSoundEffect WetLevel -10 dB.',
        'AUDIO.setMusicIntensity(0.5)');
    cat('Music', 'music_bass', 'Music: bass', 'A round, soft bass following the chord roots.',
        'Sine plus a quiet triangle (0.35) through a 520 Hz lowpass, 12 ms attack, sustain sinking to about half (0.18 s time constant), 70 ms release. Roots folded into D2 to C#3; three seeded patterns (root and fifth, octave pickup). Fades in between intensity 0.1 and 0.3.',
        'Soft sine bass sample at C2 with PlaybackSpeed per semitone. SoundGroup Music, Volume 0.5, EqualizerSoundEffect HighGain -10 dB, no reverb.',
        'AUDIO.setMusicIntensity(0.3)');
    cat('Music', 'music_drums', 'Music: brushed kit', 'A brushed lo-fi kit: soft hat, brush snare and a gentle kick.',
        'Hat: white noise bandpass 6.5 kHz Q 0.8, 50 ms, on 8ths with offbeat accent (16th ghosts above intensity 0.9). Brush: pink noise bandpass 2.6 to 1.8 kHz, 160 ms, on beats 2 and 4. Kick: sine 110 to 46 Hz in 90 ms, 220 ms decay, on steps 0 and 10. Hats 45% quieter at night. Fades in between intensity 0.55 and 0.75.',
        'Three short samples (brushed hat, brush snare swirl, soft felt kick). SoundGroup Music, Volume 0.3, EqualizerSoundEffect HighGain -4 dB. Delay offbeat 8ths by 28% of a 16th for the lazy swing.',
        'AUDIO.setMusicIntensity(0.75)');
    cat('Music', 'music_arp', 'Music: kalimba arpeggio', 'A sparkly kalimba arpeggio that joins at full intensity.',
        'Kalimba voice (sine 0.75 s + 5.4x partial 30 ms) playing chord tones an octave above the pads in an up and down pattern on 8ths, 80% note probability. Fades in between intensity 0.8 and 0.95.',
        'Kalimba sample at C5, PlaybackSpeed per semitone. SoundGroup Music, Volume 0.25, ReverbSoundEffect WetLevel -8 dB.',
        'AUDIO.setMusicIntensity(1)');
    const STING_RBX = 'Repeated calls of the same stinger within 2 s play once. Render day (C major) and night (A minor) versions. Start on the next music beat: wait beat - (clock % beat) with beat = 0.652 s. SoundGroup SFX, Volume 0.6, ReverbSoundEffect WetLevel -10 dB. Duck Music to 45% and Ambient to 30% while it plays.';
    cat('Music', 'stinger_plot', 'Stinger: plot', 'Plot fanfare: a fast rising pentatonic run that blooms into the tonic chord.',
        'Mallet 16ths on scale degrees 0 1 2 3 4 5, then degree 7 held with a bell layer (1.6 s); at beat 1.5 a tonic pad chord and bass root. Quantized to the next beat, key follows day or night mode, ducks music and ambience 2.4 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('plot') (AUDIO.plotBuilt() already calls it)");
    cat('Music', 'stinger_reset', 'Stinger: reset', 'Reset flourish: a descending run that resolves warmly on the tonic.',
        'Degrees 7 5 4 2 as 8ths then degree 0 held (1.8 s bell) with a tonic pad chord and bass at beat 2. Quantized, ducks 2.8 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('reset') (AUDIO.reset() already calls it)");
    cat('Music', 'stinger_max', 'Stinger: max', 'A quick ta-da for big max moments such as maxing a whole plot.',
        'Degree 2 then degree 5 with a softer degree 7 harmony (1.3 s bell). Quantized, ducks 1.4 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('max') (AUDIO.maxed() does not call it)");
    cat('Music', 'stinger_code', 'Stinger: code', 'A curious, twinkly motif for discovering a code or secret.',
        'Degrees 1 3 2 4 as 16ths then degree 6 held (1.5 s), plus a soft 8 note trill on degrees 8 and 9. Quantized, ducks 2 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('code')");
    cat('Music', 'stinger_achievement', 'Stinger: achievement', 'Achievement fanfare: a bouncy triad and a held octave with sparkle.',
        'Degrees 0 2 4 in a triplet feel, then degrees 5 and 7 together held (1.4 s), a tonic pad bloom at beat 1 and a trill on degrees 10 and 11. Quantized, ducks 2.2 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('achievement')");
    cat('Music', 'stinger_tier', 'Stinger: tier', 'The city tier up fanfare, started on the next music beat.',
        'The tierUp sound (brass arpeggio, held C major chord, timpani, cymbal swell, sparkles), quantized to the next beat. Ducks music and ambience 2.5 s. sfx bus.',
        STING_RBX, "AUDIO.stinger('tier')");

    const AMB_RBX = ' SoundGroup Ambient. Crossfade layers over 3 s with TweenService when the focused plot changes theme.';
    cat('Ambience', 'amb_sea', 'Sea wash', 'A gentle sea wash under everything outdoors.',
        'Brown noise lowpass 460 Hz (Q 0.5) at 0.035 with a 0.085 Hz level LFO (about 12 s waves, depth 0.02) and a 0.05 Hz cutoff LFO (140 Hz). Level x0.15 on underground themes, x0.6 on surf themes.',
        'Seamless ocean wash loop (30 s or longer). Volume 0.25, EqualizerSoundEffect HighGain -10 dB. Tween to 0.05 on mine, gem, deep, portal and cosmos plots.' + AMB_RBX,
        'Always on after AUDIO.unlock()');
    cat('Ambience', 'amb_crickets', 'Night crickets', 'Crickets on outdoor plots at night.',
        'Chirps of 3 sine pulses (3.9 to 4.3 kHz, 25 ms, 45 ms apart), twice per event, at 0.9 x night events per second once night > 0.3, random pan and distance.',
        'Looped cricket bed with Volume = 0.2 x night (tweened). Mute underground.' + AMB_RBX, 'AUDIO.setNight(0..1)');
    cat('Ambience', 'amb_rain', 'Rain', 'Rain on the island, from drizzle to downpour.',
        'Pink noise bandpass 2.4 kHz (Q 0.35) + brown noise lowpass 300 Hz at level = rain (x0.35 underground), plus sine droplet plinks 1.2 to 2.6 kHz at 4 x rain per second.',
        'Light and heavy rain loops crossfaded by rain amount, Volume 0.4 x rain. Underground: EqualizerSoundEffect HighGain -12 dB and Volume x0.35.' + AMB_RBX,
        'AUDIO.setWeather({ rain: 0..1 }) or AUDIO.setRain(v)');
    cat('Ambience', 'amb_wind', 'Wind', 'Wind that gusts and wanders.',
        'Pink noise bandpass Q 0.9 whose center wanders 300 to 1000 Hz and whose level wanders 0.55 to 1.1x about every 0.8 s; level = wind (+0.4 in storms).',
        'Wind loop, Volume 0.3 x wind; every 1 to 2 s tween PlaybackSpeed (0.9 to 1.1) and Volume randomly for gusts.' + AMB_RBX, 'AUDIO.setWeather({ wind: 0..1 })');
    cat('Ambience', 'amb_storm', 'Storm', 'A storm: heavier rain, strong wind and thunder at random distances.',
        'Adds 0.25 to the rain level and 0.4 to wind, and fires thunder (distance 0.15 to 1) every 9 to 26 s.',
        'Enable the rain and wind loops at high volume and schedule thunder every 9 to 26 s with a random distance.' + AMB_RBX, 'AUDIO.setWeather({ storm: true })');
    const L_DOC = {
        meadow: ['Meadow', 'Birdsong by day and the odd bumblebee.', 'Events 0.35/s scaled by (1 - 0.9 x night): 85% bird (2 to 5 sine chirps 1.9 to 3.1 kHz gliding up 1.2 to 1.5x, 70 ms), 15% bee (sawtooth 210 Hz lowpass 900 Hz, 1.6 s, wandering pitch).', 'Birdsong one-shots (6 or more variations) fired about 0.3 per second by day from 3D emitters around the plot, Volume 0.15.'],
        lab: ['Lab', 'Bubbling beakers over a soft simmer.', 'Bed: white noise bandpass 1.4 kHz Q 4 at 0.01 with a 0.23 Hz level LFO. Events 0.6/s: 2 to 4 bubble blips (sine 380 to 950 Hz gliding up about 2x).', 'Bubbling beaker loop as a 3D Sound on the lab props, Volume 0.2.'],
        factory: ['Factory', 'Distant metal clanks, steam hiss and a low machine rumble.', 'Bed: brown noise lowpass 140 Hz (0.06) + sine 55 Hz with 1.5 Hz tremolo. Events 0.4/s: FM clank (carrier 260 to 520 Hz, ratio 2.76, index 1.5 to 3, 0.25 to 0.5 s) + noise tick + 90 Hz thump, or (20%) a highpass steam hiss 0.5 to 0.9 s.', 'Factory room tone loop plus random metal clank one-shots (5 variations) every 1 to 4 s, Volume 0.2, EqualizerSoundEffect HighGain -6 dB.'],
        energy: ['Energy', 'An electric hum with occasional zaps.', 'Bed: sawtooth 60 Hz lowpass 380 Hz (0.006) with 0.3 Hz tremolo + sine 120 Hz (0.008). Events 0.15/s: 3 to 7 tiny bandpass crackles (2.5 to 6 kHz, 4 to 12 ms) within 0.18 s.', 'Transformer hum loop (Volume 0.15) plus electric zap one-shots every 5 to 10 s (Volume 0.2).'],
        lava: ['Lava and desert wind', 'Lava crackle over a dry desert wind (forge, deep, canyon).', 'Bed: pink noise bandpass 450 Hz Q 1.2 with a 0.06 Hz cutoff LFO (220 Hz) and 0.11 Hz level LFO, plus brown noise lowpass 90 Hz. Events 1.4/s: 1 to 3 pops (bandpass 0.9 to 3.5 kHz, 4 to 12 ms) or (8%) a lava blorp (sine 70 to 110 Hz gliding up to 150 to 220 Hz).', 'Fire crackle loop (Volume 0.2) plus a desert wind loop (Volume 0.2) and rare lava bubble one-shots.'],
        surf: ['Surf', 'Gentle surf with the odd gull (beach, bay, lagoon).', 'Bed: brown noise lowpass 650 Hz (0.02). Events 0.16/s: wave = pink noise lowpass 1.5 kHz to 300 Hz with a 1.2 s swell and 2.6 s decay plus a foam hiss 3.2 to 1.8 kHz; by day 6% of events are gull calls.', 'Gentle shore wave loop (Volume 0.3) plus gull one-shots by day.'],
        shimmer: ['Shimmer drone', 'A shimmering, slowly beating drone with glassy chimes (portal, cosmos, finale).', 'Bed: sines 130.81 and 131.4 Hz (0.6 Hz beating), triangle 196 Hz lowpass 900 Hz, high sines 1046.5 and 1568 Hz with 0.4 and 0.27 Hz tremolo. Events 0.12/s: FM chime (ratio 3.01, index 0.4, 2.2 s) on C6 D6 E6 G6 A6.', 'Sustained synth drone loop in C (Volume 0.2) plus glass chime one-shots, ReverbSoundEffect WetLevel -4 dB, DecayTime 3.'],
        mine: ['Mine', 'Water drips and distant pickaxe taps in a cave.', 'Bed: brown noise lowpass 110 Hz (0.03). Events 0.5/s: 70% drip (sine 0.7 to 1.1 kHz gliding to 1.6 to 2.4 kHz in 30 ms plus a 0.2 s ring), 30% 2 to 4 pick taps 0.5 s apart (3 kHz noise tick + FM ping 1.3 kHz ratio 2.3).', 'Cave room tone loop plus drip and pickaxe one-shots, ReverbSoundEffect WetLevel -2 dB, DecayTime 2.5.'],
        market: ['Market murmur', 'A distant crowd murmur (market, cash, cookie, tent).', 'Bed: pink noise bandpass 700 Hz Q 1.2 (0.012) with a 0.5 Hz level LFO. Events 2.2/s: vowel-like pink noise bursts through a narrow bandpass (Q 4 to 7) sliding between 350 and 1100 Hz, 0.12 to 0.35 s, sometimes a second syllable.', 'Distant crowd walla loop with no intelligible words, Volume 0.2, EqualizerSoundEffect HighGain -8 dB.'],
        sky: ['Sky wind', 'High, airy wind with slow gusts.', 'Bed: pink noise bandpass 1.1 kHz Q 0.8 (0.035) with a 0.08 Hz cutoff LFO (400 Hz) and a 0.13 Hz level LFO. Events 0.1/s: gust swells (bandpass 500 to 1400 Hz, 0.8 s attack).', 'High wind loop, Volume 0.25, plus gust one-shots.'],
        night: ['Night plot', 'Steady crickets and a far owl.', 'Events 0.8/s: 80% cricket chirps, 20% owl (two sine hoots 390 and 380 Hz gliding down, lowpass 900 Hz).', 'Cricket loop (Volume 0.2) plus owl one-shots every 20 to 40 s.'],
        sparkle: ['Sparkle', 'Little glints of magic (gold, gem, cash, finale).', 'Events 0.18/s: FM glint (2 to 2.8 kHz, ratio 3.01, index 0.3, 0.6 s) and a softer fifth above 70 ms later.', 'Tiny chime one-shots every 3 to 8 s, Volume 0.1, ReverbSoundEffect WetLevel -4 dB.'],
        stream: ['Brook', 'A babbling brook (mill, grove).', 'Bed: white noise bandpass 1.1 kHz Q 0.6 (0.012) + pink noise lowpass 700 Hz (0.02). Events 3/s: tiny sine blips 0.5 to 1.3 kHz gliding up to 1.4 to 2.2 kHz.', 'Brook loop as a 3D Sound on the water, Volume 0.25.'],
    };
    for (const k in L_DOC) {
        const th = Object.keys(THEMES).filter(x => THEMES[x].split('+').includes(k)), d = L_DOC[k];
        cat('Ambience', 'amb_' + k, 'Theme: ' + d[0], d[1], d[2] + ' Crossfades in over 3 s. Themes: ' + th.join(', ') + '.', d[3] + AMB_RBX,
            "AUDIO.setTheme('" + th[0] + "')");
    }
    CATALOG.forEach(e => { e.bus = SFX[e.id] ? SFX[e.id].bus : 'sfx'; });

    // Global mixing recipe for the Roblox rebuild.
    const ROBLOX = {
        soundGroups: 'SoundService: SoundGroup Master (Volume 0.56 = default volume 0.8 x trim 0.7) with child SoundGroups parented under it: Music 0.5, SFX 0.9, UI 0.65, Ambient 0.6 (user sliders multiply these). On Master: CompressorSoundEffect Threshold -18, Ratio 3.5, Attack 0.004, Release 0.25, GainMakeup 0, and EqualizerSoundEffect HighGain -4, MidGain 0, LowGain 0.',
        reverb: 'One ReverbSoundEffect per group: Music WetLevel -10 dB, Ambient -8 dB, SFX -16 dB, UI none. DecayTime 2.2, Density 0.8, Diffusion 0.9, DryLevel 0.',
        ducking: 'duck(sec): tween Music group Volume to 45% and Ambient to 30% in 0.15 s, hold for 40% of sec, then return to 100% by sec. Used by plotBuilt (2.2 s), reset (2.6 s) and stingers.',
        voices: 'Cap at 24 simultaneous one-shots: keep a list of playing Sounds and Stop() the oldest when full; skip ambient events, footsteps, autoTick and hover when 18 or more are playing.',
        pitch: 'Semitone ladder: PlaybackSpeed = 1.0595^n (or PitchShiftSoundEffect.Octave to keep length). Pitched instruments need one sample at C5: PlaybackSpeed = 2^((midi - 72) / 12).',
        spatial: 'The web draft pans with AUDIO.panFor(screenX, width) and fakes distance with lowpass, level and extra reverb. In Roblox parent Sounds to parts and use RollOffMode InverseTapered instead.',
        music: 'Either render 5 stems (pads, bass, marimba, drums, arp) as 8 bar loops per mode at 92 bpm and fade stem volumes by intensity, or port the sequencer: a Heartbeat loop scheduling 16ths from os.clock with a 0.1 s lookahead. Day key C major pentatonic, night A dorian / A minor pentatonic, switching at a bar line.',
        haptics: 'See HAPTIC.CATALOG for HapticService recipes.',
    };

    // ---------- Public API ----------
    function unlock() {
        init(); if (!ctx) return;
        if (ctx.state === 'suspended' && !st.muted) ctx.resume().catch(() => { });
        if (started) return;
        started = true;
        startAmbient(); startMusic();
        if (st.muted) ctx.suspend().catch(() => { });   // muted before the first gesture: stay silent and idle
        timers.push(setInterval(musicTick, MUSIC.tickMs), setInterval(ambTick, 200));
    }
    // play(id, { pan: -1..1, vol: 0..1, pitch: semitones, rate: frequency multiplier, dist: 0..1 }) -> true if it sounded.
    function play(id, o) {
        const e = SFX[id]; if (!e || !ok()) return false;
        o = o || {};
        const v = voice(bus[e.bus], o, e.low); if (!v) return false;
        try { e.fn(v, now() + 0.005, o); } finally { done(v); }
        if (e.duck) duck(e.duck);
        if (e.after) e.after(o);
        return true;
    }
    // duck(sec, at): pull music and ambience down, hold, and recover by `sec`. at = optional start time.
    function duck(sec, at) {
        if (!ctx) return;
        const t = Math.max(now(), at || 0), s = Math.max(0.3, sec || 1);
        for (const k in DUCK) {
            const p = bus[k].gain; hold(p, t);
            p.linearRampToValueAtTime(DUCK[k], t + 0.15); p.linearRampToValueAtTime(DUCK[k], t + Math.max(0.2, s * 0.4)); p.linearRampToValueAtTime(1, t + s);
        }
    }
    function setWeather(w) {
        w = w || {};
        if (w.rain != null) st.rain = clamp(+w.rain || 0, 0, 1);
        if (w.wind != null) st.wind = clamp(+w.wind || 0, 0, 1);
        if (w.storm != null) { if (w.storm && !st.storm && ctx) amb.nextThunder = now() + R(2, 6); st.storm = !!w.storm; }
    }
    // Both are cheap to call every frame: nothing happens unless the value really changes.
    function setTheme(k) { st.theme = THEMES[k] ? k : 'meadow'; if (started && ctx && amb.applied !== st.theme) applyTheme(); }
    function setMusicIntensity(v) { v = clamp(+v || 0, 0, 1); if (Math.abs(v - st.intensity) < 0.01 && M.on) return; st.intensity = v; if (M.on) setLayers(false); }
    function setMuted(m) {
        st.muted = !!m; if (!ctx) return;
        fadeTo(master.gain, st.muted ? 0 : st.volume * MASTER_TRIM, now(), st.muted ? 0.015 : 0.08);
        if (st.muted) setTimeout(() => { if (st.muted && ctx.state === 'running') ctx.suspend().catch(() => { }); }, 80);   // save battery
        else if (ctx.state === 'suspended' && started) ctx.resume().catch(() => { });
    }
    function setVolume(v) { st.volume = clamp(+v || 0, 0, 1); if (master && !st.muted) fadeTo(master.gain, st.volume * MASTER_TRIM, now(), 0.05); }
    function setBusVolume(b, v) {
        if (b === 'master') return setVolume(v);
        if (!(b in st.bus)) return;
        st.bus[b] = clamp(+v || 0, 0, 1);
        if (vol[b]) fadeTo(vol[b].gain, BUS[b].trim * st.bus[b], now(), 0.05);
    }
    const getBusVolume = b => (b === 'master' ? st.volume : st.bus[b]);
    const panFor = (x, w) => (w > 0 && Number.isFinite(x) ? clamp(((x / w) * 2 - 1) * 0.8, -0.8, 0.8) : 0);
    const footstep = (surface, o) => play('step_' + (STEP[surface] ? surface : 'stone'), o);

    return {
        // legacy calls used by the current game
        unlock, buy: big => play(big ? 'buyBig' : 'buy'), autoTick: () => play('autoTick'), maxed: () => play('maxed'),
        tap: () => play('tap'), deny: () => play('deny'), open: () => play('open'), close: () => play('close'),
        reset: () => play('reset'), splash: () => play('splash'), plotBuilt: () => play('plotBuilt'), whale: () => play('whale'),
        duck, setNight: v => { st.night = clamp(+v || 0, 0, 1); }, setRain: v => setWeather({ rain: v }), setMuted, setVolume, st,
        // new
        play, stinger: kind => stinger(kind), setWeather, thunder: d => play('thunder', { distance: d }), footstep, setTheme,
        setMusicIntensity, setBusVolume, getBusVolume, panFor, voices, CATALOG, THEMES, MUSIC, ROBLOX,
        BUSES: Object.keys(BUS), get ctx() { return ctx; }, get started() { return started; },
    };
})();

// Haptics: short, meaningful pulses only. Off in Minimal effects mode (HUD sets HAPTIC.on).
// pattern is a navigator.vibrate pattern in ms (on, off, on, ...). roblox is the HapticService recipe:
// HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, strength), wait, then SetMotor(..., 0).
// Check HapticService:IsVibrationSupported / IsMotorSupported first; on mobile use Enum.VibrationMotor.Small.
const HAPTIC = {
    on: true,
    CATALOG: [
        { id: 'tap', pattern: 5, when: 'Light confirmation for important buttons only (not every tap).', roblox: 'Motor Small, strength 0.2, 0.03 s.' },
        { id: 'buy', pattern: 8, when: 'Each manual upgrade buy.', roblox: 'Motor Small, strength 0.3, 0.05 s.' },
        { id: 'maxed', pattern: [12, 40, 18], when: 'An upgrade reaches max level.', roblox: 'Motor Small 0.5 for 0.06 s, off 0.04 s, Motor Large 0.3 for 0.08 s.' },
        { id: 'big', pattern: [20, 60, 20, 60, 40], when: 'Plot built or prestige reset.', roblox: 'Motor Large 0.6 for 0.1 s, off 0.06 s, Large 0.6 for 0.1 s, off 0.06 s, Large 0.8 for 0.2 s.' },
        { id: 'deny', pattern: [6, 30, 6], when: 'Cannot afford or action refused.', roblox: 'Motor Small 0.25 for 0.03 s twice, 0.03 s apart.' },
        { id: 'coin', pattern: 6, when: 'Coin or pickup collected (rate limit to one per 0.1 s).', roblox: 'Motor Small, strength 0.2, 0.03 s.' },
        { id: 'stamp', pattern: 25, when: 'Heavy UI confirmation (stamp sound).', roblox: 'Motor Large, strength 0.5, 0.08 s.' },
        { id: 'codeFound', pattern: [10, 40, 10, 40, 30], when: 'Secret code discovered.', roblox: 'Motor Small 0.4 for 0.05 s twice (0.04 s gaps), then Large 0.5 for 0.12 s.' },
        { id: 'achievement', pattern: [15, 50, 25], when: 'Achievement unlocked.', roblox: 'Motor Small 0.5 for 0.06 s, off 0.05 s, Large 0.4 for 0.1 s.' },
        { id: 'rise', pattern: [10, 30, 15, 30, 20, 30, 40], when: 'Plot island rising (a growing rumble).', roblox: 'Motor Large ramping 0.2 to 0.7 over 1.5 s (update each Heartbeat), then 0.' },
        { id: 'thunder', pattern: [40, 30, 80], when: 'Close thunder only (distance < 0.35).', roblox: 'Motor Large 0.7 for 0.1 s, off 0.05 s, Large 0.4 for 0.3 s.' },
        { id: 'tierUp', pattern: [30, 60, 30, 60, 90], when: 'City grows a tier.', roblox: 'Motor Large 0.5 for 0.12 s, off 0.06 s, Large 0.5 for 0.12 s, off 0.06 s, Large 0.9 for 0.3 s.' },
        { id: 'milestone', pattern: [15, 40, 15, 40, 40], when: 'Number milestone passed (1K, 1M, 1B...).', roblox: 'Motor Small 0.5 for 0.05 s twice (0.04 s gaps), then Large 0.5 for 0.12 s.' },
        { id: 'letterDrop', pattern: 12, when: 'Each giant sign letter landing.', roblox: 'Motor Large, strength 0.4, 0.05 s.' },
    ],
    pulse(p) { if (!this.on || typeof navigator === 'undefined' || !navigator.vibrate) return; try { navigator.vibrate(p); } catch (e) { } },
    play(id) { const e = this.CATALOG.find(x => x.id === id); if (e) this.pulse(e.pattern); },
    buy() { this.play('buy'); }, maxed() { this.play('maxed'); }, big() { this.play('big'); },
};
if (typeof module !== 'undefined' && module.exports) module.exports = { AUDIO, HAPTIC };
