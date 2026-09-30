// FX Lab: a living style guide. Lists every world effect, UI motion, sound and haptic with its tier,
// trigger, timings and the recipe to build it in Roblox, plays any of them on demand, and exports the
// whole catalog as JSON so another tool (or AI) can read it.
const LAB = (() => {
    let tab = 'world', open = false;
    const $ = (id) => document.getElementById(id);
    const TABS = [['world', 'WORLD FX'], ['ui', 'UI MOTION'], ['sound', 'SOUND'], ['haptic', 'HAPTICS'], ['systems', 'SYSTEMS'], ['export', 'EXPORT']];
    function show() { open = true; $('drawer').classList.remove('hidden'); render(); AUDIO.open(); }
    function close() { if (!open) return; open = false; $('drawer').classList.add('hidden'); AUDIO.close(); }
    function toggle() { if (open) close(); else show(); }
    function tabs() {
        const t = $('drawerTabs'); t.innerHTML = '';
        for (const [k, label] of TABS) { const b = el('button', tab === k ? 'on' : '', label); b.onclick = () => { tab = k; AUDIO.tap(); render(); }; t.appendChild(b); }
    }
    function specList(o) { return Object.entries(o || {}).map(([k, v]) => `<dt>${esc(k.toUpperCase())}</dt><dd>${esc(String(v))}</dd>`).join(''); }
    function item(name, tier, trig, dl, onPlay) {
        const d = el('div', 'lab-item');
        d.innerHTML = `<div class="lab-top"><div class="grow"><div class="lab-name">${esc(name)}</div><div class="lab-trig">${esc(trig || '')}</div></div>${tier ? `<span class="tier ${esc(tier)}">${esc(tier.toUpperCase())}</span>` : ''}${onPlay ? '<button class="lab-play">PLAY</button>' : ''}<button class="lab-more" aria-label="Details">SPEC</button></div><dl class="lab-spec">${dl}</dl>`;
        if (onPlay) d.querySelector('.lab-play').onclick = onPlay;
        d.querySelector('.lab-more').onclick = () => d.classList.toggle('open');
        return d;
    }
    // A context to show world effects on: the selected machine, else one on the focused plot.
    function ctxFor(e) {
        const f = HUD.focus || PLOTS.get('0,0');
        const node = (HUD.sheetId && NODE_MAP.get(HUD.sheetId)) || f.upgrades.find(n => getLevel(n.id) > 0) || f.upgrades.find(n => isNodeUnlocked(n)) || f.upgrades[0];
        const reset = f.resets[0] || TREE_NODES.find(n => n.type === 'reset' && WORLD.builtPlots().has(plotKeyOf(n.coords[0], n.coords[1])));
        const c = { force: true, node, x: node.coords[0], y: node.coords[1] };
        if (e.id === 'reset') Object.assign(c, { node: reset || node, gain: 123, resetIds: new Set(f.upgrades.filter(n => getLevel(n.id) > 0).slice(0, 12).map(n => n.id)) });
        if (e.id === 'plotBuilt') Object.assign(c, { plot: f });
        if (e.id === 'maxPlot') Object.assign(c, { nodes: f.upgrades.filter(n => isNodeUnlocked(n)) });
        if (e.id === 'newCurrency') c.key = node.costCurrency;
        if (e.id === 'portalReady' && reset) c.node = reset;
        if (e.id === 'codeFound') c.letter = 'S';
        if (e.id === 'incomePop') { c.key = 'P'; c.amount = calculateGainRate('P') * 2.6 || 1234; }
        return c;
    }
    function renderWorld(body) {
        body.appendChild(el('div', 'lab-note', 'Tiers: HERO one at a time and may move the camera; SUPPORT at most 3 starts per 250 ms; AMBIENT background, first to go when the budget is tight. PLAY forces the effect on the focused plot.'));
        for (const cat of ['Gameplay', 'World', 'Weather', 'UI']) {
            const list = FX.CATALOG.filter(e => e.category === cat); if (!list.length) continue;
            body.appendChild(el('div', 'hsec', cat.toUpperCase()));
            for (const e of list) {
                const dl = `<dt>WHAT</dt><dd>${esc(e.desc)}</dd>${specList(e.spec)}<dt>SOUND</dt><dd>${esc(e.sound)}</dd><dt>HAPTIC</dt><dd>${esc(e.haptic)}</dd><dt>ROBLOX</dt><dd>${esc(e.roblox)}</dd>`;
                body.appendChild(item(e.name, e.tier, e.trigger, dl, e.run.toString().length > 20 ? () => { AUDIO.unlock(); FX.play(e.id, ctxFor(e)); } : null));
            }
        }
    }
    function renderUI(body) {
        const stage = el('div', 'lab-stage');
        stage.innerHTML = `<button class="big" id="labBtn" style="flex:none;padding:12px 18px 8px"><i class="fill"></i><span>BUTTON</span></button><div class="rate-pill" id="labPill" style="position:static">+12.3K/s</div><div class="hero-num" id="labNum" style="font-size:28px">0</div>`;
        body.appendChild(stage);
        const demos = {
            uiPress: () => { const b = $('labBtn'); b.style.transform = 'translateY(3px)'; b.style.boxShadow = '0 1px 0 var(--ink)'; setTimeout(() => { b.style.transform = ''; b.style.boxShadow = ''; }, 120); AUDIO.tap(); },
            uiPanel: () => HUD.openPanel('help'),
            uiSheet: () => { const n = ctxFor({ id: 'buy' }).node; HUD.openNode(n.id); },
            uiToast: () => HUD.toast('This is a toast. Four can stack.'),
            uiBanner: () => HUD.banner('Demo Plot'),
            uiBadge: () => { const e = $('tResetBadge'); e.classList.remove('hidden'); e.textContent = '3'; e.style.animation = 'none'; void e.offsetWidth; e.style.animation = ''; },
            uiHold: () => { const f = $('labBtn').querySelector('.fill'); f.style.transition = 'width .7s linear'; f.style.width = '100%'; setTimeout(() => { f.style.transition = ''; f.style.width = '0'; AUDIO.maxed && AUDIO.maxed(); }, 720); },
            uiTicker: () => { let v = 0; const target = 987654; const step = () => { v += (target - v) * 0.25; if (target - v < 1) v = target; $('labNum').textContent = formatNum(v); if (v < target) requestAnimationFrame(step); }; step(); },
            uiRate: () => { const r = $('labPill'); r.classList.remove('bump'); void r.offsetWidth; r.classList.add('bump'); },
        };
        for (const m of FX.UI_MOTION) body.appendChild(item(m.name, '', m.spec, `<dt>SPEC</dt><dd>${esc(m.spec)}</dd><dt>ROBLOX</dt><dd>${esc(m.roblox)}</dd>`, demos[m.id] ? () => demos[m.id]() : null));
        body.appendChild(el('div', 'lab-note', 'Design tokens: ink #1b1530, paper #fffaf0, yellow #ffd23f, green #39d98a, blue #4aa8ff, red #ff4d4d, purple #a56ae0. Borders 3 px ink, radius 10 to 16 px, hard drop shadow 0 4 px ink. Fonts: Luckiest Guy for numbers and titles, Fredoka 600 to 700 for text. Minimum 13 px text.'));
    }
    function renderSound(body) {
        const cat = (typeof AUDIO !== 'undefined' && AUDIO.CATALOG) || [];
        if (!cat.length) { body.appendChild(el('div', 'lab-note', 'The sound catalog loads with the audio engine.')); return; }
        body.appendChild(el('div', 'lab-note', 'Everything is synthesized live with WebAudio. SPEC says how; ROBLOX says what asset to use or record and how to route it.'));
        const groups = {}; for (const s of cat) (groups[s.category] = groups[s.category] || []).push(s);
        for (const [g, list] of Object.entries(groups)) {
            body.appendChild(el('div', 'hsec', g.toUpperCase()));
            for (const s of list) body.appendChild(item(s.name, '', s.desc, `<dt>SPEC</dt><dd>${esc(s.spec)}</dd><dt>ROBLOX</dt><dd>${esc(s.roblox)}</dd>`, () => { AUDIO.unlock(); playSound(s.id); }));
        }
    }
    function playSound(id) {
        if (AUDIO.play && AUDIO.play(id) !== false) return;
        if (typeof AUDIO[id] === 'function') AUDIO[id]();
    }
    function renderHaptic(body) {
        const cat = (typeof HAPTIC !== 'undefined' && HAPTIC.CATALOG) || [];
        body.appendChild(el('div', 'lab-note', 'Vibration only works on phones that support it, and it is off in Minimal effects mode.'));
        for (const h of cat) body.appendChild(item(h.name || h.id, '', h.when || '', specList({ pattern: JSON.stringify(h.pattern), roblox: h.roblox }), () => (HAPTIC.play ? HAPTIC.play(h.id) : HAPTIC.pulse(h.pattern))));
    }
    function renderSystems(body) {
        const R = WORLD.R;
        const sec = (t, html) => { body.appendChild(el('div', 'hsec', t)); body.appendChild(el('div', 'lab-item open', `<dl class="lab-spec" style="display:block">${html}</dl>`)); };
        sec('RENDER PASSES (ONE CANVAS)', specList({
            '1 sea': 'gradient tinted by time of day, star glints at night, caustics (2 drifting pattern layers), sparkle strokes anchored to the world',
            '2 under plates': 'shallows ring, buoys, ducks, jumping fish (hook underPlates)',
            '3 plates': 'depth sorted: underwater silhouette, foam, slab sides, top texture drawn with an affine transform, boat and whale interleaved by depth',
            '4 shadows': 'sun direction from the clock, one hull per standing object, clipped per plot, one fill (hook shadows)',
            '5 standing items': 'machines, portals, signs, lamps, props, minifigs, avatar, code bricks, sorted by depth; static looks stamped from a sprite atlas while the camera is still (hook items)',
            '6 air': 'particles, drones (hook afterItems), clouds, birds, balloon and plane (hook sky)',
            '7 light': 'night tint, additive glow sprites, fireflies, rain, storm tint and snow (hook post)',
            '8 labels': 'plot signs (baked per content change, culled when they overlap), proximity prompt, confetti (hook ui)',
            'Roblox': 'This maps to Workspace models plus Lighting (ClockTime, Atmosphere, ColorCorrection), BillboardGuis for signs and prompts, ScreenGui for HUD. No custom renderer needed.',
        }));
        sec('QUALITY PRESETS', Object.entries(WORLD.QUALITY).map(([k, q]) => `<dt>${k.toUpperCase()}${WORLD.Q.name === k ? ' (CURRENT)' : ''}</dt><dd>${esc(Object.entries(q).map(([a, b]) => a + ' ' + b).join(', '))}</dd>`).join('') + '<dt>AUTO</dt><dd>If frame time averages over 30 ms for 3 s, canvas resolution drops half a step (never the math).</dd>');
        sec('THEMED PROPS PER PLOT THEME', Object.entries(PROPS.THEME_PROPS).map(([k, v]) => `<dt>${k.toUpperCase()}</dt><dd>${esc(v.join(', '))}</dd>`).join(''));
        sec('WEATHER', specList({ kinds: Object.keys(ENVFX.KINDS).join(', '), cycle: 'clear 3 to 7 min, then a pick: fog likely at dawn, snow only at night, rain 27%, storm 15%; weather ramps over about 18 s', storm: 'lightning every 6 to 18 s, darker tint, strong wind', after: 'rainbow for 40 s after rain in daytime', roblox: 'Clouds.Cover and Density tweens, Atmosphere.Haze for fog, ParticleEmitters attached to the camera for rain and snow, Lighting flash for lightning.' }));
        sec('ATTENTION BUDGET', specList({ hero: 'one at a time (new plot, rebuild): letterbox, camera, hit-stop 80 to 90 ms, flash', support: 'max 3 starts per 250 ms: buys, maxed, grow, code, badge', ambient: 'ambience particles, drones, income pops, whale, boat', flashes: 'at most 2 per second, never in Reduced, Minimal or Reduce flashing', modes: 'Full 100%, Reduced 45% particles no shake no flash, Minimal none' }));
        sec('WALK MODE', specList({ move: '3.4 u/s, sprint x1.6, screen relative, jump 3.6 u/s with gravity 12', walls: 'only built plots and bridges are walkable; locked plots bump with the reason', collide: 'machines as squares, portals and props as circles, holograms are walk-through', prompt: 'nearest usable thing within 0.95 u; E or the action button; hold repeats buys at up to 18 per second', roblox: 'Humanoid character, invisible CanCollide walls on unbuilt plots, ProximityPrompt per machine (HoldDuration 0, use InputBegan for repeat)' }));
        sec('META (MATH NEUTRAL)', specList({ badges: META.BADGES.length + ' badges, checked every second', codes: Object.keys(META.CODES).join(', '), codeBricks: '8 golden bricks spell STUDCITY', wardrobe: Object.entries(META.WARDROBE).map(([k, v]) => k + ' ' + v.length).join(', '), guide: 'next goal: ready rebuild that doubles you, else best buy (cost as share of wallet), else next plot' }));
    }
    function catalogJSON() {
        const strip = (o) => JSON.parse(JSON.stringify(o, (k, v) => typeof v === 'function' ? undefined : v));
        return JSON.stringify({
            game: 'Stud City Incremental', generated: new Date().toISOString(),
            fx: strip(FX.CATALOG), uiMotion: FX.UI_MOTION, audio: strip((typeof AUDIO !== 'undefined' && AUDIO.CATALOG) || []), haptics: strip((typeof HAPTIC !== 'undefined' && HAPTIC.CATALOG) || []),
            quality: WORLD.QUALITY, props: PROPS.THEME_PROPS, weather: Object.keys(ENVFX.KINDS), badges: META.BADGES.map(b => ({ id: b.id, name: b.name, desc: b.desc })), codes: Object.fromEntries(Object.entries(META.CODES).map(([k, v]) => [k, { hint: v.hint, reward: v.label }])),
            plots: PLOT_ORDER.map(p => ({ key: p.key, name: p.name, upgradeLand: p.ul, theme: p.theme, color: p.color, machines: p.upgrades.length })),
        }, null, 1);
    }
    function renderExport(body) {
        body.appendChild(el('div', 'lab-note', 'One JSON file with every effect, UI motion, sound, haptic, quality preset, prop list, weather kind, badge, code and plot. Hand it to the AI that builds the Roblox version.'));
        const txt = catalogJSON();
        const dl = el('a', 'big'); dl.innerHTML = '<span>DOWNLOAD CATALOG JSON</span>'; dl.style.textAlign = 'center'; dl.style.textDecoration = 'none'; dl.download = 'stud-city-catalog.json';
        try { dl.href = URL.createObjectURL(new Blob([txt], { type: 'application/json' })); } catch (e) { dl.href = 'data:application/json,' + encodeURIComponent(txt); }
        const cp = el('button', 'big max', '<span>COPY TO CLIPBOARD</span>');
        cp.onclick = () => { try { navigator.clipboard.writeText(txt).then(() => HUD.toast('Catalog copied'), () => HUD.toast('Copy blocked here, use DOWNLOAD')); } catch (e) { HUD.toast('Copy blocked here, use DOWNLOAD'); } };
        body.append(dl, cp);
        body.appendChild(el('div', 'lab-note', `${(txt.length / 1024).toFixed(0)} KB, ${FX.CATALOG.length} effects, ${FX.UI_MOTION.length} UI motions, ${((typeof AUDIO !== 'undefined' && AUDIO.CATALOG) || []).length} sounds.`));
        const pre = el('pre', 'data-code'); pre.textContent = txt.slice(0, 2400) + '\n...'; body.appendChild(pre);
    }
    function render() {
        if (!open) return;
        tabs(); const body = $('drawerBody'); body.innerHTML = '';
        ({ world: renderWorld, ui: renderUI, sound: renderSound, haptic: renderHaptic, systems: renderSystems, export: renderExport })[tab](body);
    }
    return { show, close, toggle, get open() { return open; }, catalogJSON };
})();
