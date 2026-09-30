// Meta systems on top of the game: badges, hidden code bricks, secret codes, the wardrobe of cosmetic
// rewards, the "next goal" guide and a small stats history. None of it touches currencies or levels:
// Stud City keeps the Upgrade Land math exactly, so every reward here is cosmetic.
// Where these would live in Roblox: badges map to BadgeService (plus an in-game list), codes to a
// RemoteFunction validated on the server, cosmetics to a DataStore profile, the guide to a client UI.

// Hidden golden code bricks. Each sits on a free cell of a plot and shows once that plot is built.
// Together they spell the release code STUDCITY.
const META_SPOTS = [
    { id: 'c1', plot: '0,0', letter: 'S', cell: 3 }, { id: 'c2', plot: '0,1', letter: 'T', cell: 1 },
    { id: 'c3', plot: '1,1', letter: 'U', cell: 2 }, { id: 'c4', plot: '0,2', letter: 'D', cell: 0 },
    { id: 'c5', plot: '0,-1', letter: 'C', cell: 1 }, { id: 'c6', plot: '1,0', letter: 'I', cell: 2 },
    { id: 'c7', plot: '0,3', letter: 'T', cell: 1 }, { id: 'c8', plot: '3,0', letter: 'Y', cell: 0 },
];
const META = (() => {
    const R = WORLD.R;
    function M() { const m = SAVE_META(); if (!m.x) m.x = {}; const x = m.x;
        x.badges = x.badges || {}; x.found = x.found || []; x.redeemed = x.redeemed || []; x.counters = x.counters || {};
        x.owned = x.owned || { hat: ['hardhat', 'none'], torso: ['#4aa8ff'], trail: ['none'], boat: ['red'] };
        x.wear = x.wear || { hat: 'hardhat', torso: '#4aa8ff', legs: '#2b3a67', trail: 'none', boat: 'red', name: 'YOU' };
        x.secrets = x.secrets || []; return x; }

    // ---------- cosmetics ----------
    const WARDROBE = {
        hat: [['hardhat', 'Hard hat'], ['none', 'No hat'], ['cap', 'Red cap'], ['crown', 'Gold crown'], ['wizard', 'Wizard'], ['pirate', 'Pirate']],
        torso: [['#4aa8ff', 'Blue'], ['#e8453c', 'Red'], ['#39d98a', 'Green'], ['#ffd23f', 'Yellow'], ['#a855f7', 'Purple'], ['#1b1530', 'Night'], ['#ff7ae0', 'Pink']],
        trail: [['none', 'None'], ['studs', 'Stud drops'], ['sparkles', 'Sparkles'], ['bubbles', 'Bubbles'], ['flames', 'Embers']],
        boat: [['red', 'Red sail'], ['pirate', 'Pirate'], ['gold', 'Golden']],
    };
    const cosmetics = () => M().wear;
    const cosmetic = (k) => M().wear[k];
    function setCosmetic(k, v) { if (!M().owned[k] || !M().owned[k].includes(v)) return false; M().wear[k] = v; return true; }
    function give(k, v) { const o = M().owned; o[k] = o[k] || []; if (!o[k].includes(v)) o[k].push(v); }

    // ---------- codes ----------
    const CODES = {
        STUDCITY: { hint: 'Find all 8 golden code bricks hidden on the islands.', reward: [['hat', 'crown'], ['trail', 'studs'], ['torso', '#ffd23f']], label: 'Gold crown, stud trail, yellow outfit' },
        LIGHTHOUSE: { hint: 'Visit the lighthouse keeper when the beam is on.', reward: [['hat', 'pirate'], ['boat', 'pirate'], ['torso', '#1b1530']], label: 'Pirate hat, pirate boat, night outfit' },
        WHALE: { hint: 'Tap the whale when it surfaces.', reward: [['trail', 'bubbles'], ['torso', '#39d98a']], label: 'Bubble trail, green outfit' },
        REDCANYON: { hint: 'Build the newest plot, Red Brick Canyon.', reward: [['trail', 'flames'], ['torso', '#e8453c'], ['hat', 'cap']], label: 'Ember trail, red outfit, red cap' },
        NIGHTOWL: { hint: 'Spend 5 minutes of real time on the islands at night.', reward: [['hat', 'wizard'], ['trail', 'sparkles'], ['torso', '#a855f7']], label: 'Wizard hat, sparkle trail, purple outfit' },
        BRICKS: { hint: 'The launch code. Free for everyone.', reward: [['torso', '#ff7ae0'], ['boat', 'gold']], label: 'Pink outfit, golden boat' },
    };
    function redeem(raw) {
        const code = String(raw || '').toUpperCase().replace(/[^A-Z]/g, '');
        const c = CODES[code]; const x = M();
        if (!c) return { ok: false, msg: 'That code does not exist.' };
        if (x.redeemed.includes(code)) return { ok: false, msg: 'Already redeemed.' };
        if (code !== 'BRICKS' && !x.secrets.includes(code)) return { ok: false, msg: 'Not unlocked yet. ' + c.hint };
        x.redeemed.push(code); for (const [k, v] of c.reward) give(k, v);
        FX.play('achievement', { force: true });
        return { ok: true, msg: 'Unlocked: ' + c.label };
    }
    function secret(code) { const x = M(); if (x.secrets.includes(code)) return false; x.secrets.push(code); HUD.toast(`Secret code found: ${code}. Redeem it in CODES.`, '#fff3b0'); FX.sfx('codeFound'); return true; }

    // ---------- code bricks ----------
    function spotPos(s) { const p = PLOTS.get(s.plot); const cells = R.freeCells(p); const c = cells[s.cell % cells.length]; return [c[0], c[1]]; }
    function visibleCodes() {
        const x = M(); const out = [];
        for (const s of META_SPOTS) { if (x.found.includes(s.id) || !R.builtCache().has(s.plot)) continue; const [px, py] = spotPos(s); out.push({ id: s.id, x: px, y: py, letter: s.letter }); }
        return out;
    }
    function collect(id) {
        const x = M(); if (x.found.includes(id)) return;
        const s = META_SPOTS.find(q => q.id === id); if (!s) return;
        x.found.push(id); const [px, py] = spotPos(s);
        FX.play('codeFound', { x: px, y: py, letter: s.letter, force: true });
        HUD.toast(`Code brick ${x.found.length}/8: "${s.letter}"`, '#fff3b0');
        if (x.found.length === META_SPOTS.length) setTimeout(() => secret('STUDCITY'), 900);
        check(false);
    }
    WORLD.use('items', (items) => {
        for (const c of visibleCodes()) {
            items.push({ d: R.depth(c.x, c.y), draw() {
                const bob = Math.sin(R.T * 2.2 + c.x) * 0.04, z = R.TOP + 0.03 + bob;
                const bb = R.box(c.x, c.y, z, 0.1, 0.07, 0.09, '#ffd23f', { topCol: '#ffe680' });
                R.stud(c.x - 0.04, c.y, z + 0.09, 0.03, '#ffd23f'); R.stud(c.x + 0.04, c.y, z + 0.09, 0.03, '#ffd23f');
                const tw = (Math.sin(R.T * 2.6 + c.x * 3) + 1) / 2; if (tw > 0.8 && R.Q.sparkle) { const s = R.P(c.x, c.y, z + 0.2); R.sparkle(s[0] + 3, s[1] - 2, (tw - 0.8) * 40 * R.cam.zoom); }
                if (R.env.night > 0.3) R.light([c.x, c.y, z + 0.1, '#ffd23f', 0.5]);
                R.hit({ type: 'code', id: c.id, x0: bb[0] - 8, y0: bb[1] - 10, x1: bb[2] + 8, y1: bb[3] + 6 });
            } });
        }
    });
    WORLD.use('shadows', (p) => { for (const c of visibleCodes()) if (plotKeyOf(c.x, c.y) === p.key) R.shadow(c.x, c.y, 0.1, 0.07, 0.12); });

    // ---------- badges ----------
    const cnt = (k) => M().counters[k] || 0;
    function bump(k, n = 1) { M().counters[k] = cnt(k) + n; }
    const machines = () => { let n = 0; for (const k in gameState.levels) if (gameState.levels[k] > 0) n++; return n; };
    const maxedCount = () => TREE_NODES.reduce((a, n) => a + (n.type === 'upgrade' && getLevel(n.id) > 0 && getLevel(n.id) >= getMaxLevel(n) ? 1 : 0), 0);
    const BADGES = [
        ['firstBuy', 'First Brick', 'Buy your first machine', '▣', () => machines() >= 1],
        ['ten', 'Busy Builder', 'Own 10 machines', '⚒', () => machines() >= 10],
        ['fifty', 'Brick Tycoon', 'Own 50 machines', '★', () => machines() >= 50],
        ['twohundred', 'City Planner', 'Own 200 machines', '♔', () => machines() >= 200],
        ['maxOne', 'Topped Out', 'Max a machine', '▲', () => maxedCount() >= 1],
        ['maxTen', 'Gold Roofs', 'Max 10 machines', '☀', () => maxedCount() >= 10],
        ['rebuild', 'Fresh Start', 'Rebuild once', '⟳', () => cnt('resets') >= 1],
        ['rebuild25', 'Demolition Pro', 'Rebuild 25 times', '☢', () => cnt('resets') >= 25],
        ['plots3', 'Island Hopper', 'Build 3 plots', '⚑', () => R.builtCache().size >= 3],
        ['plots10', 'Archipelago', 'Build 10 plots', '⚐', () => R.builtCache().size >= 10],
        ['plots20', 'Mapmaker', 'Build 20 plots', '⌖', () => R.builtCache().size >= 20],
        ['plotsAll', 'Stud City Complete', 'Build all 39 plots', '♛', () => R.builtCache().size >= 39],
        ['red', 'Hot Off the Press', 'Build Red Brick Canyon, the newest plot', '♨', () => R.builtCache().has('7,2')],
        ['studsM', 'Millionaire', 'Hold 1M Studs', '$', () => getCurr('P') >= 1e6],
        ['studs30', 'Stud Mountain', 'Hold 1e30 Studs', '⛰', () => getCurr('P') >= 1e30],
        ['studs100', 'Googol-ish', 'Hold 1e100 Studs', '∞', () => getCurr('P') >= 1e100],
        ['cur10', 'Collector', 'Discover 10 currencies', '❖', () => gameState.discoveredCurrencies.length >= 10],
        ['cur30', 'Treasurer', 'Discover 30 currencies', '❈', () => gameState.discoveredCurrencies.length >= 30],
        ['drones', 'Drone Swarm', 'Get 100 automated buys', '✈', () => cnt('autoBuys') >= 100],
        ['walker', 'Stroll', 'Walk 100 units', '⚔', () => (typeof WALK !== 'undefined' ? WALK.A.dist : 0) + cnt('walkDist') >= 100],
        ['explorer', 'Explorer', 'Walk onto 10 different plots', '⚐', () => (M().counters.visits || []).length >= 10],
        ['codes4', 'Treasure Hunter', 'Find 4 code bricks', '✦', () => M().found.length >= 4],
        ['codes8', 'Code Breaker', 'Find all 8 code bricks', '✧', () => M().found.length >= 8],
        ['whale', 'Whale Watcher', 'Spot the whale', '♒', () => cnt('whales') >= 1],
        ['storm', 'Storm Chaser', 'Play through a storm', '⚡', () => cnt('storms') >= 1],
        ['photo', 'Photographer', 'Take a photo in photo mode', '◉', () => cnt('photos') >= 1],
    ].map(([id, name, desc, icon, test]) => ({ id, name, desc, icon, test }));
    let checkT = 0, ready = false;
    // silent: award without the pop (used when a save already qualifies on load)
    function check(silent) {
        if (!ready) return;
        const x = M();
        for (const b of BADGES) {
            if (x.badges[b.id]) continue;
            let ok = false; try { ok = b.test(); } catch (e) { }
            if (ok) { x.badges[b.id] = SAVE_META().playMs; if (!silent) announce(b); }
        }
    }
    function announce(b) {
        if (typeof GAME !== 'undefined' && GAME.sim) return;
        FX.play('achievement', { force: true });
        const el = document.getElementById('badgePop'); if (!el) return;
        el.querySelector('.bp-icon').textContent = b.icon; el.querySelector('.bp-name').textContent = b.name; el.querySelector('.bp-desc').textContent = b.desc;
        el.classList.remove('show'); void el.offsetWidth; el.classList.add('show');
        clearTimeout(announce.t); announce.t = setTimeout(() => el.classList.remove('show'), 2800);
    }
    function visit(key) { const v = M().counters.visits = M().counters.visits || []; if (!v.includes(key)) v.push(key); }

    // ---------- next goal guide ----------
    function nextGoal() {
        const built = R.builtCache();
        // 1. a rebuild that at least doubles what you hold
        for (const n of TREE_NODES) {
            if (n.type !== 'reset' || !isNodeUnlocked(n) || !built.has(plotKeyOf(n.coords[0], n.coords[1]))) continue;
            const g = getEffectiveResetGain(n), have = getCurr(n.targetCurrency);
            if (g > 0 && (have === 0 || g >= have)) return { icon: '⟳', text: `Rebuild for +${formatNum(g)} ${curName(n.targetCurrency)}`, sub: n.code || n.id, act: () => ACTIONS.focusNode(n.id) };
        }
        // 2. the best buy on the plot you are looking at, then anywhere
        const focus = typeof HUD !== 'undefined' && HUD.focus;
        const pick = (list) => { let best = null, sc = Infinity; for (const n of list) { if (!canAfford(n)) continue; const s = getDisplayCost(n) / Math.max(1e-300, getCurr(n.costCurrency)); if (s < sc) { sc = s; best = n; } } return best; };
        let n = focus && built.has(focus.key) ? pick(focus.upgrades) : null;
        if (!n) { const all = []; for (const k of built) all.push(...PLOTS.get(k).upgrades); n = pick(all); }
        if (n) { const p = PLOTS.get(plotKeyOf(n.coords[0], n.coords[1])); return { icon: '▲', text: `Buy ${n.code || n.id}: ${n.name}`.slice(0, 48), sub: p ? p.name : '', act: () => ACTIONS.focusNode(n.id) }; }
        // 3. the next plot to build
        for (const p of PLOT_ORDER) {
            if (p.soon || built.has(p.key) || !R.plotVisibleGhost(p)) continue;
            const info = GAME.signInfo.get(p.key); return { icon: '⚑', text: `Build ${p.name}`, sub: (info && info.lockText) || '', act: () => ACTIONS.focusPlot(p.key) };
        }
        return { icon: '…', text: `Earn more ${curName('P')}`, sub: 'Machines are working', act: null };
    }

    // ---------- stats history (for the stats panel sparkline) ----------
    const history = [];
    let histT = 0, nightT = 0;
    function tick(dt) {
        checkT += dt; histT += dt;
        if (R.env.night > 0.6) { nightT += dt; if (nightT > 300) secret('NIGHTOWL'); }
        if (R.env.storm > 0.6 && !tick.storm) { tick.storm = true; bump('storms'); } else if ((R.env.storm || 0) < 0.2) tick.storm = false;
        if (histT >= 5) { histT = 0; history.push({ t: SAVE_META().playMs, p: Math.log10(getCurr('P') + 1), r: Math.log10(calculateGainRate('P') + 1) }); if (history.length > 360) history.shift(); }
        if (checkT >= 1) { checkT = 0; check(false); }
        if (R.builtCache().has('7,2') && !M().secrets.includes('REDCANYON')) secret('REDCANYON');
    }
    function init() { M(); ready = true; check(true); if (WORLD.on) WORLD.on('whale', () => bump('whales')); }
    return { init, tick, bump, visit, BADGES, CODES, WARDROBE, redeem, secret, collect, visibleCodes, cosmetics, cosmetic, setCosmetic, owned: (k) => M().owned[k] || [], state: M, nextGoal, history };
})();
