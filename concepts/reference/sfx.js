// ---------------------------------------------------------------- Peckwood SFX: the "buttery keycap" kit, synthesized
// Every UI sound is built from one keycap model: a soft top-click (filtered noise), a short pitched body that drops into
// place (the thock), and a warm case resonance, all through a gentle low-pass so nothing is harsh. Variants change the
// pitch, weight and tail. Bigger moments add marimba notes, shimmer and swells built from the same parts.
const SFX = (() => {
  let ctx = null, master = null, muted = false, vol = 0.8;
  const noiseBuf = {};
  function init(c) {
    ctx = c || ctx || new (window.AudioContext || window.webkitAudioContext)();
    if (!master) { master = ctx.createGain(); master.gain.value = vol;
      const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 7200; lp.Q.value = 0.4;
      const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 3; comp.attack.value = 0.002; comp.release.value = 0.12;
      master.connect(lp); lp.connect(comp); comp.connect(ctx.destination); }
    return ctx;
  }
  function noise(len) { const k = Math.round(len * 100); if (noiseBuf[k] && noiseBuf[k].ctx === ctx) return noiseBuf[k].b;
    const b = ctx.createBuffer(1, Math.max(1, Math.floor(ctx.sampleRate * len)), ctx.sampleRate), d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; noiseBuf[k] = { b, ctx }; return b; }
  const R = (a, b) => a + Math.random() * (b - a);
  function env(g, t, a, peak, dec) { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(peak, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + dec); }
  function nz(t, { type = "bandpass", f = 3000, q = 0.8, a = 0.001, peak = 0.3, dec = 0.02, len = 0.2, f2 = null, out = master }) {
    const s = ctx.createBufferSource(); s.buffer = noise(len); const fl = ctx.createBiquadFilter(); fl.type = type; fl.frequency.setValueAtTime(f, t); fl.Q.value = q;
    if (f2) fl.frequency.exponentialRampToValueAtTime(f2, t + a + dec);
    const g = ctx.createGain(); env(g, t, a, peak, dec); s.connect(fl); fl.connect(g); g.connect(out); s.start(t); s.stop(t + a + dec + 0.05); }
  function tone(t, { f = 200, f0 = null, type = "sine", a = 0.002, peak = 0.3, dec = 0.06, drop = 0.015, out = master }) {
    const o = ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(f0 || f, t); if (f0) o.frequency.exponentialRampToValueAtTime(f, t + drop);
    const g = ctx.createGain(); env(g, t, a, peak, dec); o.connect(g); g.connect(out); o.start(t); o.stop(t + a + dec + 0.05); }
  // the keycap: click + thock + case
  function key(t, { pitch = 170, weight = 1, bright = 1, tail = 1, v = 1 } = {}) {
    const p = pitch * R(0.96, 1.04);
    nz(t, { type: "highpass", f: 2600 * bright, q: 0.5, peak: 0.16 * v * bright, dec: 0.006, len: 0.05 });          // top click
    nz(t + 0.001, { type: "bandpass", f: 4200 * bright, q: 2.2, peak: 0.07 * v, dec: 0.012, len: 0.05 });          // keycap edge
    tone(t, { f: p, f0: p * 1.55, peak: 0.42 * v * weight, dec: 0.055 * tail, drop: 0.014 });                       // thock body
    tone(t, { f: p * 2.6, type: "triangle", peak: 0.09 * v * weight, dec: 0.022 * tail });                           // overtone
    nz(t + 0.002, { type: "bandpass", f: 720 * (pitch / 170), q: 1.6, peak: 0.16 * v * weight, dec: 0.045 * tail, len: 0.1 });   // case resonance
  }
  function mar(t, f, v = 0.22, dec = 0.35) { tone(t, { f, peak: v, dec, a: 0.003 }); tone(t, { f: f * 4, peak: v * 0.18, dec: dec * 0.25 }); }
  function shimmer(t, v = 0.08, n = 6) { for (let i = 0; i < n; i++) tone(t + i * 0.035, { f: R(2400, 4200), peak: v, dec: 0.12 }); }
  function swell(t, { f = 180, f2 = 1600, dur = 0.5, peak = 0.18, type = "lowpass" }) { nz(t, { type, f, f2, q: 0.9, a: dur * 0.6, peak, dec: dur * 0.5, len: dur + 0.2 }); }
  const kit = {
    hover: t => nz(t, { type: "highpass", f: 5200, peak: 0.05, dec: 0.008, len: 0.03 }),
    press: t => key(t, { pitch: 165 }),
    release: t => key(t, { pitch: 245, weight: 0.45, bright: 0.85, tail: 0.6, v: 0.6 }),
    tab: t => { key(t, { pitch: 190, weight: 0.8 }); mar(t + 0.03, 784, 0.07, 0.15); },
    open: t => { swell(t, { f: 260, f2: 2200, dur: 0.22, peak: 0.12, type: "bandpass" }); key(t + 0.12, { pitch: 150, weight: 1.1 }); mar(t + 0.14, 523, 0.08, 0.25); },
    close: t => { swell(t, { f: 1800, f2: 240, dur: 0.18, peak: 0.1, type: "bandpass" }); key(t + 0.08, { pitch: 210, weight: 0.6, tail: 0.7 }); },
    buy: t => { key(t, { pitch: 160, weight: 1.2 }); mar(t + 0.06, 1047, 0.2); mar(t + 0.14, 1568, 0.2, 0.5); shimmer(t + 0.16, 0.06, 8); },
    deny: t => { key(t, { pitch: 112, weight: 1.1, bright: 0.6 }); key(t + 0.09, { pitch: 96, weight: 1, bright: 0.5, v: 0.85 }); },
    pickup: t => { tone(t, { f: 1250, f0: 620, peak: 0.16, dec: 0.05, drop: 0.03 }); nz(t, { type: "highpass", f: 3000, peak: 0.08, dec: 0.01, len: 0.03 }); },
    golden: t => { kit.pickup(t); mar(t + 0.03, 2093, 0.12, 0.45); shimmer(t + 0.05, 0.05, 7); },
    peck: t => { nz(t, { type: "bandpass", f: 1800, q: 1.2, peak: 0.25, dec: 0.03, len: 0.06 }); key(t, { pitch: 300, weight: 0.5, tail: 0.5, v: 0.7 }); },
    mine: t => { nz(t, { type: "bandpass", f: 3600, q: 4, peak: 0.25, dec: 0.08, len: 0.12 }); tone(t, { f: 90, f0: 160, peak: 0.45, dec: 0.18, drop: 0.05 }); shimmer(t + 0.02, 0.05, 4); },
    hit: t => { tone(t, { f: 55, f0: 140, peak: 0.7, dec: 0.32, drop: 0.08 }); nz(t, { type: "lowpass", f: 3000, f2: 300, peak: 0.45, dec: 0.25, len: 0.4 }); key(t, { pitch: 120, weight: 1.4, v: 1 }); },
    splash: t => { nz(t, { type: "bandpass", f: 1400, f2: 500, q: 0.7, a: 0.01, peak: 0.25, dec: 0.35, len: 0.5 }); for (let i = 0; i < 4; i++) tone(t + R(0, 0.12), { f: R(700, 1400), f0: R(300, 500), peak: 0.05, dec: 0.05, drop: 0.03 }); },
    pillar: t => { kit.splash(t); [784, 988, 1175, 1568].forEach((f, i) => mar(t + 0.12 + i * 0.07, f, 0.13, 0.6)); swell(t, { f: 400, f2: 5000, dur: 1.2, peak: 0.08, type: "bandpass" }); },
    molt: t => { swell(t, { f: 200, f2: 4000, dur: 1.4, peak: 0.22, type: "bandpass" }); [523, 659, 784, 1047, 1319].forEach((f, i) => mar(t + 0.3 + i * 0.09, f, 0.14, 0.7)); shimmer(t + 0.8, 0.06, 12); tone(t, { f: 65, f0: 50, peak: 0.25, dec: 1.2, a: 0.4 }); },
    evolve: t => { swell(t, { f: 3000, f2: 180, dur: 0.75, peak: 0.2, type: "bandpass" }); const n = t + 0.76; kit.hit(n); [392, 523, 659, 784].forEach((f, i) => mar(n + 0.05 + i * 0.06, f, 0.15, 0.8)); },
    upgrade: t => { key(t, { pitch: 170 }); [659, 880].forEach((f, i) => mar(t + 0.05 + i * 0.07, f, 0.12, 0.3)); },
    unlock: t => { tone(t, { f: 42, f0: 60, peak: 0.35, dec: 2.4, a: 0.5 }); nz(t, { type: "lowpass", f: 160, f2: 420, peak: 0.28, a: 0.9, dec: 1.6, len: 2.8 }); [392, 523, 659, 784, 1047].forEach((f, i) => mar(t + 1.1 + i * 0.1, f, 0.13, 0.9)); shimmer(t + 1.5, 0.05, 10); },
    pop: t => tone(t, { f: R(500, 900), f0: R(250, 350), peak: 0.06, dec: 0.04, drop: 0.02 }),
  };
  function play(name, opts) { if (muted || !kit[name]) return; init(); if (ctx.state === "suspended") ctx.resume(); kit[name](ctx.currentTime + 0.005, opts); }
  return { play, kit, init, setMuted(m) { muted = m; }, get muted() { return muted; }, setVol(v) { vol = v; if (master) master.gain.value = v; },
    // render one sound offline (for exporting files)
    async render(name, dur = 1.5, sr = 44100) { const oc = new OfflineAudioContext(1, Math.ceil(sr * dur), sr); const save = [ctx, master]; ctx = oc; master = null; init(oc); kit[name](0.01); const buf = await oc.startRendering(); [ctx, master] = save; return buf; } };
})();
// wire every button on the page: hover tick, press thock, release clack
function wireKeys(root = document) {
  root.addEventListener("pointerover", e => { const b = e.target.closest("button,select,.fx"); if (b && !b.contains(e.relatedTarget)) SFX.play("hover"); });
  root.addEventListener("pointerdown", e => { if (e.target.closest("button,select,.fx")) SFX.play("press"); });
  root.addEventListener("pointerup", e => { if (e.target.closest("button,select,.fx")) SFX.play("release"); });
}
