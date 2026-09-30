// FX Lab: a living style guide. Lists every world effect, UI motion, sound and haptic with its tier,
// trigger, timings and the recipe to build it in Roblox, plays any of them on demand, and exports the
// whole catalog as JSON so another tool (or AI) can read it.
const LAB = (() => {
    let tab = 'world', open = false;
    const $ = (id) => document.getElementById(id);
    const TABS = [['world', 'WORLD FX'], ['kit', 'UI KIT'], ['ui', 'UI MOTION'], ['sound', 'SOUND'], ['haptic', 'HAPTICS'], ['systems', 'SYSTEMS'], ['export', 'EXPORT']];
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
        const order = ['Gameplay', 'Cinematic', 'City', 'World', 'Sea', 'Sky', 'Weather', 'Render', 'UI'];
        const cats = order.concat([...new Set(FX.CATALOG.map(e => e.category))].filter(c => !order.includes(c)));
        for (const cat of cats) {
            const list = FX.CATALOG.filter(e => e.category === cat); if (!list.length) continue;
            body.appendChild(el('div', 'hsec', cat.toUpperCase()));
            for (const e of list) {
                const dl = `<dt>WHAT</dt><dd>${esc(e.desc)}</dd>${specList(e.spec)}<dt>SOUND</dt><dd>${esc(e.sound)}</dd><dt>HAPTIC</dt><dd>${esc(e.haptic)}</dd><dt>ROBLOX</dt><dd>${esc(e.roblox)}</dd>`;
                body.appendChild(item(e.name, e.tier, e.trigger, dl, e.run.toString().length > 20 ? () => { AUDIO.unlock(); FX.play(e.id, ctxFor(e)); } : null));
            }
        }
    }
    // ---------------- UI kit: every primitive of the HUD, live, with its Roblox build ----------------
    const UI_KIT = {
        tokens: {
            ink: '#141024 (every outline, text stroke and drop shadow)',
            navy: 'frame gradient #2b3a62 > #1d2746 > #171f38; inner line rgba(140,170,255,0.18); inset rows rgba(10,14,30,0.45)',
            text: 'white #ffffff, secondary #c3cdeb, tertiary #93a0c6, gold #ffd84a, lime #a8ff5a',
            themes: 'gold #ffe96b #ffc51f #f09a00 | purple #e59bff #b54cf5 #7521d0 | green #a9f76c #45d14a #15a13b | lime button #f1ff8c #bdf43c #6fd41c | blue #86e3ff #36aef5 #1473d4 | red #ff9d6e #ff5a3c #d3241b | orange #ffcb73 #ff9a2e #e2650b | pink #ffa3ea #f45cc8 #bf2896 | teal #86f7e0 #25d0b0 #0e9687 | navy #5872d0 #30468f #1b2a63 | gray #dde4ec #a3aebb #6d7988',
            fonts: 'Fredoka 700 for every label and button (Roblox Enum.Font.FredokaOne); Luckiest Guy for numbers, prices and hero words (Enum.Font.LuckiestGuy). Minimum 13 px.',
            outline: 'text stroke shows 2 px on 13 to 17 px text, 2.5 px on 19 to 23 px, 3.5 px on 30 px+, plus a 2 to 3 px ink drop under it',
            depth: 'ink drop 4 px under cards and buttons, 5 to 6 px under frames; pressed state moves 3 px down and the drop shrinks to 1 px in 0.06 s',
            radius: 'buttons 9 to 10 px, cards 10 to 12 px, frames 12 px, pills 14 px',
        },
        parts: [
            { id: 'frame', name: 'Frame', what: 'The navy window every panel, bar and card lives in.', spec: '4 px ink border, radius 12, 2 px inner light line, 3 px top highlight, 6 px ink drop', roblox: 'Frame + UIGradient (Rotation 90, the navy stops) + UICorner 0,12 + UIStroke 4 ink. Inner line: a child Frame inset 2 px with UIStroke 2, Transparency 0.8. Drop: a second Frame behind, offset 0,6, ink.' },
            { id: 'title', name: 'Title tab', what: 'The panel name hanging over the top edge with a tilted icon sticker, like "Shop!".', spec: 'top -24 px, left 12 px; sticker 46 px card rotated -10 deg; title Fredoka 700 30 px, 3.5 px outline', roblox: 'A Frame with AnchorPoint 0,0.5 on the top edge, ZIndex above the body; ImageLabel sticker Rotation -10; TextLabel FredokaOne 30 + UIStroke 3.5. Tween it in with Back Out 0.38 s, 0.06 s after the panel.' },
            { id: 'close', name: 'Close X', what: 'Red square in the top-right corner.', spec: '46 px, top -16 right -14, red #ff8272 > #f23a2e > #c41a14, white X 27 px', roblox: 'ImageButton with red UIGradient, UICorner 0,10, UIStroke 3, TextLabel "X" FredokaOne 27 + UIStroke 2.5. Press: Position +3 px.' },
            { id: 'card', name: 'Card', what: 'A saturated tile: gradient, halftone dots fading from the top-left, gloss over the top half.', spec: 'gradient 160 deg with the 3 theme stops; dots 1.35 px every 9 px at 34% white, masked 125 deg to clear by 68%; gloss 28% white over the top 44%; 3 px ink border, 4 px ink drop', roblox: 'Frame + UIGradient (Rotation 70). Halftone: tiled ImageLabel (ScaleType Tile, TileSize 9x9), ImageTransparency 0.66, with its own UIGradient on Transparency 0 > 1. Gloss: child Frame, white, UIGradient Transparency 0.72 > 1. UIStroke 3 ink.' },
            { id: 'medal', name: 'Medallion', what: 'Round icon badge for currencies, badges and items.', spec: 'radial white > cream > gold > deep gold, 4 px inner white ring at 40%, 3 px ink border', roblox: 'ImageLabel circle (UICorner 1,0) with a radial ImageLabel gradient texture, UIStroke 3, icon ImageLabel at 72% size.' },
            { id: 'button', name: 'Buttons', what: 'Lime is the main action (buy, go, claim). Gold is the secondary (max). Purple rebuild, red destructive, navy neutral, gray unavailable.', spec: 'lime stops #f1ff8c #bdf43c #6fd41c; 3 px white top highlight at 60%, 4 px shade at the bottom, 4 px ink drop; label Fredoka 700 16 to 21 px with outline; price line Luckiest Guy 17 px with the currency icon', roblox: 'TextButton + UIGradient (Rotation 90) + UICorner 0,10 + UIStroke 3. Highlight and shade are thin child Frames. Press: tween Position +3 px and the drop Frame to 1 px (0.06 s Quad).' },
            { id: 'shine', name: 'Shine sweep', what: 'A diagonal sheen crosses ready buttons every 3.4 s (BUY when affordable, BUY ALL, Claim!).', spec: '45% wide white band at 65%, skewed 18 deg, crosses in the last 38% of a 3.4 s loop', roblox: 'A child Frame with a white UIGradient (Transparency 1 > 0.35 > 1), ClipsDescendants on the button, Position tweened from -0.7 to 1.3 on a loop with DelayTime.' },
            { id: 'seg', name: 'Segmented control', what: 'Buy mode, settings choices.', spec: 'ink outline 3 px, navy segments, selected segment gold', roblox: 'Frame with UIListLayout Horizontal, one TextButton per option, the selected one gets the gold UIGradient.' },
            { id: 'bar', name: 'Progress bar', what: 'Level and loading bars.', spec: 'ink tube 16 px, lime fill with 45 deg stripes scrolling every 1.2 s; gold fill when maxed', roblox: 'Frame (dark) + child Frame fill with UIGradient; stripes as a tiled ImageLabel whose Position loops.' },
            { id: 'rail', name: 'Side tabs', what: 'Arrow tabs on the left of a panel that jump to its sections and light up as you scroll.', spec: '58 x 46 px pentagon pointing left, tucked 6 px under the frame; active tab slides 10 px out (0.15 s Back)', roblox: 'ImageButtons with an arrow-shaped 9-slice image (ink outline baked in), ImageColor3 per section. Scroll spy: ScrollingFrame:GetPropertyChangedSignal("CanvasPosition").' },
            { id: 'section', name: 'Section header', what: 'Centred "icon TITLE icon", like FEATURED.', spec: 'Fredoka 700 21 px with 2.5 px outline; icons 18 px in the section colour', roblox: 'TextLabel FredokaOne 21 + UIStroke 2.5, two small ImageLabels either side (UIListLayout Horizontal, centred).' },
            { id: 'badge', name: 'Notification badge', what: 'Red counter on a tile.', spec: '28 px pill, red gradient, 3 px ink, pulses to 1.2x in the last 20% of 1.6 s', roblox: 'Frame + UICorner 1,0 + UIStroke 3, a UIScale tweened on a loop.' },
            { id: 'toast', name: 'Toast', what: 'Short message above the zone bar.', spec: 'navy pill, 7 px accent stripe on the left (colour by kind), Fredoka 700 16 px; in 0.26 s Back, out after 2.6 s', roblox: 'A template Frame cloned into a UIListLayout container (VerticalAlignment Bottom); tween in and Destroy after 3 s.' },
        ],
    };
    function renderKit(body) {
        body.appendChild(el('div', 'lab-note', 'The HUD is built from a handful of parts. Everything below is live and uses the same classes as the game. Each part lists its numbers and how to build it in Roblox with UIStroke, UIGradient and UICorner.'));
        const stage = (html) => { const d = el('div', 'lab-stage', html); body.appendChild(d); return d; };
        body.appendChild(el('div', 'hsec', 'THEMES'));
        stage(['gold', 'purple', 'green', 'lime', 'blue', 'red', 'orange', 'pink', 'teal', 'navy', 'gray'].map(c => `<div class="kit-swatch card c-${c}">${c.toUpperCase()}</div>`).join(''));
        body.appendChild(el('div', 'hsec', 'FRAME, TITLE TAB, CLOSE X'));
        stage(`<div class="frame" style="width:100%;height:120px;margin-top:34px"><div class="frame-title"><span class="ft-icon card c-red">&#9733;</span><h2>Shop!</h2></div><button class="x" style="pointer-events:none">X</button><div class="sechead" style="margin-top:36px"><i class="si c-gold">&#9819;</i><span>FEATURED</span><i class="si c-gold">&#9819;</i></div></div>`);
        body.appendChild(el('div', 'hsec', 'CARDS'));
        stage(`<div class="card c-gold row" style="flex:1;min-width:190px"><span class="medal">&#9733;</span><div class="grow"><div class="t1">Starter Pack</div><div class="t2">cards take any theme</div></div></div><div class="card c-purple row" style="flex:1;min-width:190px"><span class="medal">&#10022;</span><div class="grow"><div class="t1">Lucky Blocks</div><div class="t2">halftone + gloss</div></div></div>`);
        body.appendChild(el('div', 'hsec', 'BUTTONS'));
        stage(`<button class="big shine" style="flex:none;min-width:130px"><span class="bl">BUY +1</span><span class="bp"><img alt="" src="${curIcon('P', 64)}">249</span></button><button class="big max" style="flex:none;min-width:110px"><span class="bl">MAX</span><span class="bp">+12 LV</span></button><button class="sbtn purple">HOLD</button><button class="sbtn red">WIPE</button><button class="sbtn navy">GO TO</button><button class="sbtn off">LOCKED</button>`);
        body.appendChild(el('div', 'hsec', 'CONTROLS'));
        stage(`<div class="seg"><button class="on">X1</button><button>X5</button><button>X10</button><button>MAX</button></div><div class="bar" style="flex:1;min-width:140px"><i style="width:62%"></i></div><div style="position:relative;width:60px;height:40px"><b class="badge" style="position:static;animation:pop 1.6s infinite">3</b></div><nav style="display:flex;gap:6px"><button class="rtab c-gold on"><span>&#9819;</span></button><button class="rtab c-purple"><span>&#10022;</span></button><button class="rtab c-green"><span>$</span></button></nav>`);
        body.appendChild(el('div', 'hsec', 'TEXT'));
        stage(`<div style="display:flex;flex-direction:column;gap:6px;align-items:flex-start"><span class="sx" style="font:700 30px Fredoka;--sw:7px;--sd:3px">Panel title 30</span><span class="sx" style="font:700 21px Fredoka;--sw:5px">Section 21</span><span class="sx" style="font:700 16px Fredoka;--sw:4px">Label 16</span><span class="sx lg" style="font-size:34px;--sw:6px;--sd:3px">1.23M</span><span class="note">Body 14 on navy, no outline</span></div>`);
        body.appendChild(el('div', 'hsec', 'TOKENS'));
        body.appendChild(el('div', 'lab-item open', `<dl class="lab-spec" style="display:block">${specList(UI_KIT.tokens)}</dl>`));
        body.appendChild(el('div', 'hsec', 'PARTS'));
        for (const k of UI_KIT.parts) body.appendChild(item(k.name, '', k.what, `<dt>SPEC</dt><dd>${esc(k.spec)}</dd><dt>ROBLOX</dt><dd>${esc(k.roblox)}</dd>`, null));
    }
    function renderUI(body) {
        const stage = el('div', 'lab-stage');
        stage.innerHTML = `<button class="big" id="labBtn" style="flex:none;padding:12px 18px 8px"><i class="fill"></i><span>BUTTON</span></button><div class="rate-pill" id="labPill" style="position:static">+12.3K/s</div><div class="hero-num" id="labNum" style="font-size:28px">0</div><button class="rtab c-gold" id="labRail"><span>&#9819;</span></button>`;
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
            uiTitle: () => HUD.openPanel('codes'),
            uiRail: () => { const r = $('labRail'); r.classList.toggle('on'); AUDIO.tap(); },
            uiShine: () => { const b = $('labBtn'); b.classList.remove('shine'); void b.offsetWidth; b.classList.add('shine'); },
        };
        for (const m of FX.UI_MOTION) body.appendChild(item(m.name, '', m.spec, `<dt>SPEC</dt><dd>${esc(m.spec)}</dd><dt>ROBLOX</dt><dd>${esc(m.roblox)}</dd>`, demos[m.id] ? () => demos[m.id]() : null));
        body.appendChild(el('div', 'lab-note', 'Colours, fonts, outlines and every HUD part are in the UI KIT tab.'));
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
            fx: strip(FX.CATALOG), uiKit: UI_KIT, uiMotion: FX.UI_MOTION, audio: strip((typeof AUDIO !== 'undefined' && AUDIO.CATALOG) || []), haptics: strip((typeof HAPTIC !== 'undefined' && HAPTIC.CATALOG) || []),
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
        ({ world: renderWorld, kit: renderKit, ui: renderUI, sound: renderSound, haptic: renderHaptic, systems: renderSystems, export: renderExport })[tab](body);
    }
    return { show, close, toggle, get open() { return open; }, catalogJSON, UI_KIT };
})();
