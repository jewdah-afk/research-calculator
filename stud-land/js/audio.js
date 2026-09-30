// All sound is synthesized with WebAudio (no files). Buses: sfx, ui, ambient, each under master.
// The effects director ducks ambient during hero moments. Buys climb a pitch ladder
// (a semitone per quick buy, same idea as the original freqMultiplier 1.06).
const AUDIO = (() => {
    let ctx = null, master, sfx, ui, amb, noiseBuf, started = false;
    const st = { muted: false, volume: 0.8, ladder: 0, lastBuy: 0, night: 0, rain: 0 };
    const now = () => ctx.currentTime;

    function init() {
        if (ctx) return;
        const AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return;
        ctx = new AC();
        master = ctx.createGain(); master.gain.value = st.muted ? 0 : st.volume;
        const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 4;
        master.connect(comp); comp.connect(ctx.destination);
        sfx = ctx.createGain(); sfx.gain.value = 0.9; sfx.connect(master);
        ui = ctx.createGain(); ui.gain.value = 0.7; ui.connect(master);
        amb = ctx.createGain(); amb.gain.value = 0.55; amb.connect(master);
        noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
        const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    function unlock() {
        init(); if (!ctx) return;
        if (ctx.state === 'suspended') ctx.resume();
        if (!started) { started = true; startAmbient(); }
    }
    function env(g, t, a, peak, dec, end = 0.0001) {
        g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(peak, t + a);
        g.gain.exponentialRampToValueAtTime(end, t + a + dec);
    }
    function tone(freq, type, t, a, peak, dec, bus = sfx, detune = 0) {
        const o = ctx.createOscillator(), g = ctx.createGain();
        o.type = type; o.frequency.setValueAtTime(freq, t); o.detune.value = detune;
        env(g, t, a, peak, dec); o.connect(g); g.connect(bus); o.start(t); o.stop(t + a + dec + 0.05);
        return o;
    }
    function noise(t, dur, peak, filterType, f0, f1, q = 1, bus = sfx) {
        const s = ctx.createBufferSource(); s.buffer = noiseBuf; s.loop = true;
        const f = ctx.createBiquadFilter(); f.type = filterType; f.Q.value = q;
        f.frequency.setValueAtTime(f0, t); if (f1) f.frequency.exponentialRampToValueAtTime(f1, t + dur);
        const g = ctx.createGain(); env(g, t, Math.min(0.01, dur / 4), peak, dur);
        s.connect(f); f.connect(g); g.connect(bus); s.start(t, Math.random()); s.stop(t + dur + 0.05);
    }
    const ok = () => ctx && started && !st.muted;

    // Brick snap: a click transient plus a short pitched knock. Quick buys climb a semitone each.
    function buy(big = false) {
        if (!ok()) return;
        const t = now(), ms = performance.now();
        st.ladder = ms - st.lastBuy < 900 ? Math.min(st.ladder + 1, 14) : 0; st.lastBuy = ms;
        const f = 520 * Math.pow(1.0595, st.ladder);
        noise(t, 0.035, 0.5, 'bandpass', 3800, 0, 2.5);
        tone(f, 'triangle', t, 0.004, big ? 0.35 : 0.22, 0.12);
        tone(f * 2, 'sine', t + 0.01, 0.004, 0.08, 0.08);
    }
    function autoTick() { if (!ok()) return; const t = now(); noise(t, 0.02, 0.08, 'bandpass', 5200, 0, 3, ui); }
    function maxed() {
        if (!ok()) return;
        const t = now();
        [0, 4, 7, 12].forEach((s, i) => tone(784 * Math.pow(1.0595, s), 'sine', t + i * 0.06, 0.005, 0.18, 0.5));
        tone(1568, 'triangle', t + 0.26, 0.005, 0.08, 0.7);
    }
    function tap() { if (!ok()) return; const t = now(); tone(880, 'sine', t, 0.003, 0.12, 0.06, ui); tone(1320, 'sine', t + 0.02, 0.003, 0.05, 0.05, ui); }
    function deny() { if (!ok()) return; const t = now(); tone(220, 'square', t, 0.004, 0.06, 0.12, ui); tone(180, 'square', t + 0.08, 0.004, 0.06, 0.14, ui); }
    function open() { if (!ok()) return; const t = now(); tone(660, 'sine', t, 0.004, 0.1, 0.09, ui); tone(990, 'sine', t + 0.05, 0.004, 0.08, 0.1, ui); }
    function close() { if (!ok()) return; const t = now(); tone(740, 'sine', t, 0.004, 0.08, 0.08, ui); tone(520, 'sine', t + 0.05, 0.004, 0.07, 0.1, ui); }
    function whoosh() { if (!ok()) return; noise(now(), 0.7, 0.35, 'bandpass', 300, 3200, 1.2); }
    function boom() { if (!ok()) return; const t = now(); const o = tone(120, 'sine', t, 0.005, 0.6, 0.6); o.frequency.exponentialRampToValueAtTime(38, t + 0.6); noise(t, 0.4, 0.25, 'lowpass', 900, 120, 0.7); }
    function reset() { if (!ok()) return; whoosh(); setTimeout(boom, 380); const t = now() + 0.55; [0, 5, 9, 12, 16].forEach((s, i) => tone(392 * Math.pow(1.0595, s), 'triangle', t + i * 0.07, 0.005, 0.12, 0.6)); }
    function splash() { if (!ok()) return; const t = now(); noise(t, 0.6, 0.3, 'lowpass', 2400, 300, 0.8); noise(t + 0.05, 0.25, 0.12, 'highpass', 3000, 0, 0.7); }
    // Plot built: bricks raining in (a burst of snaps) then a fanfare.
    function plotBuilt() {
        if (!ok()) return;
        const t = now();
        for (let i = 0; i < 16; i++) { const tt = t + i * 0.045 + Math.random() * 0.02; noise(tt, 0.03, 0.25, 'bandpass', 3000 + Math.random() * 2500, 0, 2.5); }
        const f = t + 0.8;
        [[0, 4, 7], [5, 9, 12], [7, 11, 14], [12, 16, 19]].forEach((ch, i) => ch.forEach(s => tone(262 * Math.pow(1.0595, s), 'triangle', f + i * 0.16, 0.01, 0.12, i === 3 ? 1.4 : 0.3)));
        tone(1046, 'sine', f + 0.5, 0.01, 0.1, 1.5);
        duck(2.2);
    }
    function whale() { if (!ok()) return; const t = now(); const o = tone(180, 'sine', t, 0.4, 0.14, 1.6, amb); o.frequency.linearRampToValueAtTime(260, t + 0.9); o.frequency.linearRampToValueAtTime(150, t + 2); setTimeout(splash, 1200); }
    function duck(sec) { if (!ctx) return; const t = now(); amb.gain.cancelScheduledValues(t); amb.gain.setValueAtTime(amb.gain.value, t); amb.gain.linearRampToValueAtTime(0.18, t + 0.12); amb.gain.linearRampToValueAtTime(0.55, t + sec); }

    // Ambient bed: sea wash, a soft chord pad, birds by day and crickets by night.
    let seaGain, padNodes = [], chordIdx = 0;
    const CHORDS = [[0, 4, 7, 11], [5, 9, 12, 16], [9, 12, 16, 19], [7, 11, 14, 17]];
    function startAmbient() {
        const s = ctx.createBufferSource(); s.buffer = noiseBuf; s.loop = true;
        const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 520;
        seaGain = ctx.createGain(); seaGain.gain.value = 0.05;
        const lfo = ctx.createOscillator(); lfo.frequency.value = 0.11; const lg = ctx.createGain(); lg.gain.value = 0.035;
        lfo.connect(lg); lg.connect(seaGain.gain); lfo.start();
        s.connect(f); f.connect(seaGain); seaGain.connect(amb); s.start();
        const padBus = ctx.createGain(); padBus.gain.value = 0.05;
        const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 900; lp.Q.value = 0.3;
        padBus.connect(lp); lp.connect(amb);
        for (let i = 0; i < 4; i++) {
            const o = ctx.createOscillator(); o.type = 'triangle'; o.detune.value = (i - 1.5) * 4;
            const g = ctx.createGain(); g.gain.value = 0.25; o.connect(g); g.connect(padBus); o.start();
            padNodes.push(o);
        }
        setChord(); setInterval(setChord, 9000);
        setInterval(ambientTick, 700);
    }
    function setChord() {
        const ch = CHORDS[chordIdx++ % CHORDS.length], t = now();
        const base = st.night > 0.5 ? 110 : 130.81;
        padNodes.forEach((o, i) => o.frequency.setTargetAtTime(base * Math.pow(1.0595, ch[i]), t, 1.2));
    }
    function ambientTick() {
        if (!ok()) return;
        const t = now();
        if (st.night < 0.5) {
            if (Math.random() < 0.18) { const f = 2400 + Math.random() * 1600; const n = 2 + (Math.random() * 3 | 0); for (let i = 0; i < n; i++) { const o = tone(f, 'sine', t + i * 0.11, 0.01, 0.025, 0.08, amb); o.frequency.exponentialRampToValueAtTime(f * (1.25 + Math.random() * 0.3), t + i * 0.11 + 0.08); } }
        } else if (Math.random() < 0.5) {
            for (let i = 0; i < 3; i++) tone(4400 + Math.random() * 300, 'sine', t + i * 0.05, 0.004, 0.012, 0.03, amb);
        }
        if (st.rain > 0.05 && Math.random() < 0.9) noise(t, 0.7, 0.05 * st.rain, 'highpass', 1800, 0, 0.5, amb);
    }
    function setNight(v) { st.night = v; }
    function setRain(v) { st.rain = v; }
    function setMuted(m) { st.muted = m; if (master) master.gain.setTargetAtTime(m ? 0 : st.volume, now(), 0.05); }
    function setVolume(v) { st.volume = v; if (master && !st.muted) master.gain.setTargetAtTime(v, now(), 0.05); }
    return { unlock, buy, autoTick, maxed, tap, deny, open, close, reset, splash, plotBuilt, whale, duck, setNight, setRain, setMuted, setVolume, st };
})();

// Haptics: short, meaningful pulses only (buy, max, plot built). Off in Minimal effects mode.
const HAPTIC = {
    on: true,
    pulse(p) { if (!this.on || !navigator.vibrate) return; try { navigator.vibrate(p); } catch (e) { } },
    buy() { this.pulse(8); }, maxed() { this.pulse([12, 40, 18]); }, big() { this.pulse([20, 60, 20, 60, 40]); },
};
