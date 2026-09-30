// Boot, game loop, input and the actions the HUD and dev bar call.
// The engine runs on a fixed 100 ms tick, exactly like Upgrade Land. Speed and the bot only change
// how many ticks run per frame, never the math inside a tick.
function SAVE_META() {
    if (!gameState.studMeta || typeof gameState.studMeta !== 'object') gameState.studMeta = {};
    const m = gameState.studMeta;
    if (typeof m.playMs !== 'number') m.playMs = 0;
    if (!m.plotBuiltAt) m.plotBuiltAt = {};
    if (!m.plotHow) m.plotHow = {};
    if (!Array.isArray(m.sims)) m.sims = [];
    return m;
}

const GAME = { speed: 1, speeds: [1, 3, 10, 100], botOn: false, sim: null, mode: 'play', acc: 0, prevBuilt: new Set(), signInfo: new Map(), bestId: null, cascade: null, lastAutoSfx: 0 };
const SIM_LIMIT_MS = 12 * 3600 * 1000; // the bot stalls after Robo Works, so give up after 12h of play
const kindCache = new Map(), prodCache = new Map();

function quietFx() { return !!GAME.sim || GAME.speed >= 10; }

// ---------- per-node state for the renderer ----------
function nodeState(n) {
    if (n.type === 'reset') return { gain: getEffectiveResetGain(n) };
    if (n.type === 'info') return {};
    let kind = kindCache.get(n.id); if (!kind) { kind = WORLD.nodeKind(n); kindCache.set(n.id, kind); }
    let pc = prodCache.get(n.id);
    if (pc === undefined) { const e = (n.effects || []).find(x => x.type === 'base_gain' || x.type === 'base_gain_raw'); pc = e ? e.currency : null; prodCache.set(n.id, pc); }
    const lvl = getLevel(n.id), max = getMaxLevel(n);
    const f = HUD.focus;
    return { lvl, max, cap: capLevel(n), kind, prodCur: pc, active: lvl > 0, afford: lvl < max && canAfford(n), best: n.id === GAME.bestId, focus: !!f && f.upgrades.includes(n) };
}

// Each plot sign shows one headline: the currency it is first to produce, or its rebuild gain.
const PLOT_MAIN = (() => {
    const claimed = new Set(), out = new Map();
    for (const p of PLOT_ORDER) {
        const prod = [];
        for (const n of p.upgrades) for (const e of (n.effects || [])) if ((e.type === 'base_gain' || e.type === 'base_gain_raw') && e.currency && !prod.includes(e.currency)) prod.push(e.currency);
        const mine = prod.filter(c => !claimed.has(c));
        mine.forEach(c => claimed.add(c));
        const costs = {}; p.upgrades.forEach(n => { if (n.costCurrency) costs[n.costCurrency] = (costs[n.costCurrency] || 0) + 1; });
        const topCost = Object.entries(costs).sort((a, b) => b[1] - a[1])[0];
        out.set(p.key, { prod: mine[0] || null, cost: topCost ? topCost[0] : 'P' });
    }
    return out;
})();
function computeSignInfo() {
    const built = WORLD.builtPlots(); const m = new Map();
    for (const p of PLOTS.values()) {
        const info = {};
        if (built.has(p.key)) {
            const reset = p.resets.find(r => isNodeUnlocked(r));
            const pm = PLOT_MAIN.get(p.key) || {};
            if (reset) {
                const g = getEffectiveResetGain(reset);
                info.rateText = g > 0 ? `REBUILD +${formatNum(g)} ${curName(reset.targetCurrency)}` : `${curName(reset.targetCurrency)}: ${formatNum(getCurr(reset.targetCurrency))}`;
            } else if (pm.prod) info.rateText = `+${formatNum(calculateGainRate(pm.prod))} ${curName(pm.prod)}/s`;
            else { const c = pm.cost; const r = calculateGainRate(c); info.rateText = r > 0 ? `+${formatNum(r)} ${curName(c)}/s` : `${curName(c)}: ${formatNum(getCurr(c))}`; }
            const st = plotStats(p);
            info.frac = st.max ? Math.min(1, st.lv / st.max) : 0; info.ready = st.affordable;
            info.popCur = pm.prod && calculateGainRate(pm.prod) > 0 ? pm.prod : null;
        } else if (!p.soon) {
            let need = plotReqsValid(p) ? p.buildReqs.map(id => NODE_MAP.get(id)).find(n => getLevel(n.id) < 1) : null;
            if (!need) {
                // no valid baseplate requirement: point at the first machine here, or at what it waits for
                const open = p.upgrades.find(n => isNodeUnlocked(n));
                if (open) need = open;
                else { const first = p.upgrades[0]; const rq = first && (first.reqs || []).map(([x, y]) => COORD_MAP.get(`${x},${y}`)).find(r => r && getLevel(r.id) < 1); need = rq || null; }
            }
            if (need) { const np = PLOTS.get(plotKeyOf(need.coords[0], need.coords[1])); info.lockText = `${isNodeUnlocked(need) ? 'Buy' : 'Needs'} ${need.code || need.id}${np && np.key !== p.key ? ' on ' + np.name : ''}`; }
            else info.lockText = 'Keep upgrading nearby';
        }
        m.set(p.key, info);
    }
    GAME.signInfo = m; WORLD.setSignInfo(m);
}
function computeBest() {
    const f = HUD.focus; GAME.bestId = null; if (!f || !WORLD.builtPlots().has(f.key)) return;
    let best = null, score = Infinity;
    for (const n of f.upgrades) {
        if (!canAfford(n)) continue;
        const have = getCurr(n.costCurrency); const c = getDisplayCost(n); const s = have > 0 ? c / have : 0;
        if (s < score) { score = s; best = n; }
    }
    GAME.bestId = best ? best.id : null;
}

// ---------- plots built ----------
function checkPlots(initial) {
    if (updateDecorationUnlocks() || initial) { }
    WORLD.refreshBuilt();
    const built = WORLD.builtPlots(); const m = SAVE_META();
    const fresh = [];
    for (const k of built) if (!GAME.prevBuilt.has(k)) fresh.push(k);
    for (const k of fresh) {
        if (m.plotBuiltAt[k] === undefined) { m.plotBuiltAt[k] = m.playMs; m.plotHow[k] = initial ? 'loaded' : GAME.botOn ? 'bot' : GAME.mode; }
    }
    if (!initial && fresh.length) {
        fresh.forEach((k, i) => FX.play('plotBuilt', { plot: PLOTS.get(k), focus: i === fresh.length - 1, force: i > 0 || fresh.length > 1 }));
        const last = PLOTS.get(fresh[fresh.length - 1]);
        HUD.banner(fresh.length > 1 ? `${last.name} +${fresh.length - 1} more` : last.name);
        HUD.focus = last;
    }
    if (fresh.length || initial) { GAME.prevBuilt = new Set(built); WORLD.computeBounds(); WORLD.syncFigs(); }
}

// ---------- actions ----------
const ACTIONS = {
    signInfo: () => GAME.signInfo,
    setBuyMode(m) { buyMode = m; gameState.buyMode = m; HUD.syncBuyMode(); },
    buy(id, mode) {
        const prev = buyMode; buyMode = mode;
        GAME.mode = 'play';
        const ok = buyUpgrade(id);
        buyMode = prev;
        if (!ok) { AUDIO.deny(); const n = NODE_MAP.get(id); if (n && getLevel(n.id) < getMaxLevel(n)) HUD.toast(`Not enough ${curName(n.costCurrency)}`); }
        return ok;
    },
    buyAll(p) {
        GAME.mode = 'play';
        let levels = 0, machines = 0;
        GAME.cascade = [];
        for (const n of p.upgrades) {
            if (!isNodeUnlocked(n) || !canAfford(n)) continue;
            const before = getLevel(n.id);
            if (buyUpgrade(n.id)) { machines++; levels += getLevel(n.id) - before; }
        }
        const q = GAME.cascade; GAME.cascade = null;
        if (!machines) { AUDIO.deny(); HUD.toast('Nothing affordable here yet'); return; }
        q.slice(0, 14).forEach((e, i) => setTimeout(() => fxBuy(e), i * 70));
        HUD.toast(`Bought ${formatNum(levels)} levels on ${machines} machine${machines > 1 ? 's' : ''}`);
    },
    reset(id) {
        const n = NODE_MAP.get(id); if (!n) return;
        GAME.mode = 'play';
        if (!executeReset(n)) { AUDIO.deny(); return; }
        BOT.clear();
    },
    focusNode(id) { const n = NODE_MAP.get(id); if (!n) return; WORLD.cam.tx = n.coords[0]; WORLD.cam.ty = n.coords[1]; HUD.openNode(id); },
    focusPlot(key) { const p = PLOTS.get(key); if (!p) return; WORLD.cam.tx = p.x0 + 2.5; WORLD.cam.ty = p.y0 + 2.5; HUD.focus = p; AUDIO.tap(); },
    wipe() {
        stopSim(); wipeGame(); SAVE_META(); GAME.prevBuilt = new Set(); BOT.clear();
        HUD.closePanel(); HUD.closeSheet(); checkPlots(true); WORLD.cam.tx = 0; WORLD.cam.ty = 0; HUD.toast('Save wiped. Fresh start!');
        saveGame();
    },
    maxNextPlot() {
        // next plot with a machine that can still go up (machines stopped early for overflow count as done)
        const canRise = (n) => { const l = getLevel(n.id), c = maxCap(n); return isNodeUnlocked(n) && l < c && isFinite(c) && finiteLevel(n, l, c) > l; };
        const p = PLOT_ORDER.find(q => !q.soon && q.upgrades.some(canRise));
        if (!p) { HUD.toast('Nothing left to max right now'); AUDIO.deny(); return; }
        GAME.mode = 'max';
        const touched = [];
        let total = 0, limited = 0;
        // Machines unlock each other, so keep going until nothing new opens up on this plot.
        for (let guard = 0; guard < 40; guard++) {
            let changed = false;
            for (const n of p.upgrades) {
                if (!isNodeUnlocked(n)) continue;
                const base = capLevel(n), cap = maxCap(n), l = getLevel(n.id);
                if (l >= cap || !isFinite(cap)) continue;
                const lv = finiteLevel(n, l, cap);
                if (lv < base) limited++;
                if (lv <= l) continue;
                gameState.levels[n.id] = lv; total += lv - l; changed = true;
                if (!touched.includes(n)) touched.push(n);
                if (n.costCurrency) ensureCurrency(n.costCurrency);
                for (const e of (n.effects || [])) { const c = e.currency || e.targetCurrency; if (c) ensureCurrency(c); }
                clearCaches();
            }
            if (!changed) break;
        }
        clearCaches(true); needsNodeUpdate = true;
        ACTIONS.focusPlot(p.key);
        if (!quietFx()) FX.play('maxPlot', { nodes: touched, force: true });
        HUD.toast(`Maxed ${p.name}: +${formatNum(total)} levels on ${touched.length} machines`, '#fff3b0');
        if (limited) HUD.toast(`${limited} machine${limited > 1 ? 's' : ''} stopped where the next price passes what a wallet can hold`, '#ffe3c2');
        checkPlots(false);
        GAME.mode = 'play';
    },
    simToNextPlot() {
        if (GAME.sim) return stopSim();
        HUD.closeSheet(); HUD.closePanel();
        GAME.sim = { startBuilt: new Set(WORLD.builtPlots()), ms: 0, t0: performance.now() };
        BOT.clear();
        setText($('dvSim'), 'STOP SIM'); $('dvSim').classList.add('on');
        HUD.sim(true, '0s', 'the bot is looking for the next plot');
    },
    toggleBot() { GAME.botOn = !GAME.botOn; BOT.clear(); setText($('dvBot'), GAME.botOn ? 'BOT ON' : 'BOT OFF'); $('dvBot').classList.toggle('on', GAME.botOn); AUDIO.tap(); },
    cycleSpeed() { const i = GAME.speeds.indexOf(GAME.speed); GAME.speed = GAME.speeds[(i + 1) % GAME.speeds.length]; setText($('dvSpeed'), 'SPEED x' + GAME.speed); $('dvSpeed').classList.toggle('on', GAME.speed > 1); AUDIO.tap(); },
    away(hours) {
        saveGame();
        gameState.offlineTimestamp = Date.now() - hours * 3600 * 1000;
        const res = processOfflineProgress(Date.now());
        gameState.offlineTimestamp = Date.now();
        if (res) HUD.offline(res); else HUD.toast('Nothing earns offline yet. Build a machine first.');
    },
    collectFx() {
        const hero = $('heroIcon').getBoundingClientRect();
        WORLD.fly(WORLD.W / 2, WORLD.H / 2, hero.left + hero.width / 2, hero.top + hero.height / 2, '#ffd23f', 14);
        AUDIO.maxed();
    },
};
// Highest level a player could ever pay for: past it the next price is bigger than the most any
// wallet can hold (about 1.8e308). Endless towers like Loop Lagoon list a max of 1000, but their
// price passes that limit long before (I05 would cost about 10^1880 at level 629), so MAX stops here.
function priceLevel(n, from, to) {
    const price = (L) => { const c = n.bulkFinalCost ? n.costFormula(L, getLevel, getCurr) : n.costFormula(L - 1, getLevel, getCurr); return (typeof c === 'number' && c === c) ? c : Infinity; };
    if (price(to) <= Number.MAX_VALUE) return to;
    let lo = from, hi = to;
    while (hi - lo > 1) { const mid = Math.floor((lo + hi) / 2); if (price(mid) <= Number.MAX_VALUE) lo = mid; else hi = mid; }
    return lo;
}
function maxCap(n) { const c = capLevel(n); return isFinite(c) ? Math.min(c, priceLevel(n, getLevel(n.id), c)) : c; }
// Safety net: highest level in (from, to] that keeps every number this machine touches finite. Some machines
// overflow long before their data max (x3 per level to level 1000 is 3^1000), so MAX stops there.
function finiteLevel(n, from, to) {
    const keys = []; for (const e of (n.effects || [])) { const c = e.currency || e.targetCurrency; if (c && !keys.includes(c)) keys.push(c); }
    const resets = TREE_NODES.filter(r => r.type === 'reset' && keys.includes(r.targetCurrency));
    const ok = (lv) => {
        gameState.levels[n.id] = lv; clearCaches(true);
        for (const k of keys) { const r = calculateGainRate(k); if (typeof r !== 'number' || !isFinite(r)) return false; }
        for (const r of resets) { const g = getEffectiveResetGain(r); if (typeof g !== 'number' || !isFinite(g)) return false; }
        return true;
    };
    let best = from;
    if (ok(to)) best = to;
    else { let lo = from, hi = to; while (hi - lo > 1) { const mid = Math.floor((lo + hi) / 2); if (ok(mid)) lo = mid; else hi = mid; } best = lo; }
    gameState.levels[n.id] = from; clearCaches(true);
    return best;
}
function setText(e, t) { if (e && e._t !== t) { e._t = t; e.textContent = t; } }

function stopSim(found) {
    const s = GAME.sim; if (!s) return;
    GAME.sim = null;
    setText($('dvSim'), 'SIM TO NEXT PLOT'); $('dvSim').classList.remove('on');
    HUD.sim(false);
    const realMs = performance.now() - s.t0;
    if (found) {
        SAVE_META().sims.push({ key: found.key, name: found.name, simMs: s.ms, realMs });
        HUD.toast(`Bot built ${found.name} after ${formatTime(s.ms)} of play`, '#d8f7e4');
    } else if (s.ms >= SIM_LIMIT_MS) HUD.toast(`Bot found no new plot in ${formatTime(s.ms)} of play. Try MAX NEXT PLOT.`, '#ffd9d9');
    else HUD.toast(`Sim stopped after ${formatTime(s.ms)} of play`);
    for (const k of WORLD.builtPlots()) if (!s.startBuilt.has(k) && !SAVE_META().plotHow[k]) SAVE_META().plotHow[k] = 'sim';
    checkPlots(false);
}
function simStep() {
    const s = GAME.sim; const t0 = performance.now(); const m = SAVE_META();
    while (performance.now() - t0 < 26) {
        BOT.run(5000); m.playMs += 5000; s.ms += 5000;
        updateDecorationUnlocks();
        for (const p of PLOT_ORDER) {
            if (p.soon || s.startBuilt.has(p.key) || !plotIsBuilt(p)) continue;
            if (m.plotBuiltAt[p.key] === undefined) { m.plotBuiltAt[p.key] = m.playMs; m.plotHow[p.key] = 'sim'; }
            return stopSim(p);
        }
        if (s.ms >= SIM_LIMIT_MS) return stopSim(null);
    }
    HUD.sim(true, formatTime(s.ms), `${curName('P')} ${formatNum(getCurr('P'))}, ${BOT.state.resets} rebuilds so far`);
}

// ---------- engine events to effects ----------
function fxBuy(e) {
    const maxed = e.newLevel >= getMaxLevel(e.node);
    let from = $('heroIcon');
    if (e.node.costCurrency !== 'P') { const row = [...document.querySelectorAll('.srow')].find(r => r.querySelector('img') && r.querySelector('img').src === curIcon(e.node.costCurrency, 64)); if (row) from = row; }
    FX.play('buy', { node: e.node, bought: e.bought, big: maxed, fromEl: from });
    if (maxed) FX.play('maxed', { node: e.node, force: true });
}
EVENTS.on('buy', (e) => {
    META.bump(e.isAutomated ? 'autoBuys' : 'buys');
    GAME.activity = Math.min(1, (GAME.activity || 0) + (e.isAutomated ? 0.01 : 0.12));
    if (quietFx()) return;
    if (e.isAutomated) {
        FX.play('autoBuy', { node: e.node });
        const now = performance.now(); if (now - GAME.lastAutoSfx > 180) { GAME.lastAutoSfx = now; AUDIO.autoTick(); }
        return;
    }
    if (GAME.cascade) { GAME.cascade.push(e); return; }
    if (GAME.mode === 'max') return;
    if (GAME.botOn) { if (Math.random() < 0.25) FX.play('buy', { node: e.node, bought: e.bought }); return; }
    fxBuy(e);
});
EVENTS.on('reset', (e) => {
    META.bump('resets');
    if (quietFx()) return;
    FX.play('reset', e);
    if (!GAME.botOn) HUD.toast(`Rebuilt! +${formatNum(e.gain)} ${curName(e.node.targetCurrency)}`, '#efe2ff');
});
EVENTS.on('currency', (k) => { if (quietFx() || k === 'P') return; HUD.toast(`New: ${curName(k)}`, '#e6f4ff'); FX.play('newCurrency', { key: k, x: HUD.focus ? HUD.focus.x0 + 2.5 : 0, y: HUD.focus ? HUD.focus.y0 + 2.5 : 0 }); });

// ---------- input ----------
function initInput() {
    const cv = $('world'); const cam = WORLD.cam;
    const pts = new Map(); let drag = null, pinch = null;
    const clampZoom = z => Math.max(0.28, Math.min(2.4, z));
    cv.addEventListener('pointerdown', e => {
        AUDIO.unlock();
        cv.setPointerCapture(e.pointerId);
        pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
        if (pts.size === 1) drag = { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, t0: performance.now(), moved: 0 };
        if (pts.size === 2) {
            const [a, b] = [...pts.values()];
            pinch = { d: Math.hypot(a.x - b.x, a.y - b.y), a: Math.atan2(b.y - a.y, b.x - a.x), zoom: cam.tZoom, ang: cam.tAngle };
            if (drag) drag.moved = 999;
        }
    });
    cv.addEventListener('pointermove', e => {
        if (!pts.has(e.pointerId)) {
            if (e.pointerType === 'mouse') { const h = WORLD.pick(e.clientX, e.clientY); cv.classList.toggle('point', !!h); WORLD.setHover(h && h.type === 'plot' ? h.key : null); }
            return;
        }
        pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
        if (pinch && pts.size >= 2) {
            const [a, b] = [...pts.values()];
            const d = Math.hypot(a.x - b.x, a.y - b.y), ang = Math.atan2(b.y - a.y, b.x - a.x);
            cam.tZoom = cam.zoom = clampZoom(pinch.zoom * d / pinch.d);
            cam.tAngle = pinch.ang + (ang - pinch.a); syncRot();
            return;
        }
        if (drag && WALK.on) { drag.moved += Math.abs(e.clientX - drag.x) + Math.abs(e.clientY - drag.y); drag.x = e.clientX; drag.y = e.clientY; return; }
        if (drag) {
            const w0 = WORLD.unproject(drag.x, drag.y), w1 = WORLD.unproject(e.clientX, e.clientY);
            cam.x += w0[0] - w1[0]; cam.y += w0[1] - w1[1]; cam.tx = cam.ty = null;
            drag.moved += Math.abs(e.clientX - drag.x) + Math.abs(e.clientY - drag.y);
            drag.x = e.clientX; drag.y = e.clientY;
            if (drag.moved > 8) cv.classList.add('drag');
        }
    });
    const end = e => {
        if (!pts.has(e.pointerId)) return;
        pts.delete(e.pointerId);
        if (pts.size < 2) pinch = null;
        if (pts.size === 0 && drag) {
            cv.classList.remove('drag');
            if (drag.moved < 10 && performance.now() - drag.t0 < 600) tap(e.clientX, e.clientY);
            drag = null;
        }
    };
    cv.addEventListener('pointerup', end); cv.addEventListener('pointercancel', end);
    cv.addEventListener('wheel', e => {
        e.preventDefault();
        const before = WORLD.unproject(e.clientX, e.clientY);
        cam.zoom = cam.tZoom = clampZoom(cam.tZoom * Math.pow(1.0015, -e.deltaY));
        const after = WORLD.unproject(e.clientX, e.clientY);
        cam.x += before[0] - after[0]; cam.y += before[1] - after[1]; cam.tx = cam.ty = null;
    }, { passive: false });
    function tap(x, y) {
        const h = WORLD.pick(x, y);
        if (WALK.on && (!h || h.type === 'plot')) { HUD.closeSheet(); WALK.tapTo(x, y); return; }
        if (!h) { HUD.closeSheet(); return; }
        if ((h.type === 'star' || h.type === 'serpent') && SKY.tap(h)) return;
        if (h.type === 'code') { META.collect(h.id); return; }
        if (h.type === 'whale') { META.bump('whales'); META.secret('WHALE'); FX.play('splash', { x: WORLD.unproject(x, y, 0)[0], y: WORLD.unproject(x, y, 0)[1], force: true }); return; }
        if (h.type === 'node') { AUDIO.tap(); HUD.openNode(h.id); const n = NODE_MAP.get(h.id); HUD.focus = PLOTS.get(plotKeyOf(n.coords[0], n.coords[1])) || HUD.focus; }
        else if (h.type === 'plot') ACTIONS.focusPlot(h.key);
        else if (h.type === 'lighthouse') {
            if (WORLD.env.night > 0.3) { HUD.toast('The keeper waves and flashes a code at you.'); META.secret('LIGHTHOUSE'); FX.sfx('foghorn'); }
            else { HUD.toast('The lighthouse keeper is napping until dark.'); AUDIO.tap(); }
        }
    }
    const rot = $('camRot');
    function syncRot() { let a = cam.tAngle; a = Math.atan2(Math.sin(a), Math.cos(a)); rot.value = Math.round(a * 180 / Math.PI); }
    rot.addEventListener('input', () => { cam.tAngle = Number(rot.value) * Math.PI / 180; });
    const turn = d => { cam.tAngle = Math.round((cam.tAngle + d) / (Math.PI / 2)) * (Math.PI / 2); syncRot(); AUDIO.tap(); };
    $('camL').onclick = () => turn(-Math.PI / 2); $('camR').onclick = () => turn(Math.PI / 2);
    $('camIn').onclick = () => { cam.tZoom = clampZoom(cam.tZoom * 1.25); AUDIO.tap(); };
    $('camOut').onclick = () => { cam.tZoom = clampZoom(cam.tZoom / 1.25); AUDIO.tap(); };
    $('camHome').onclick = () => { const p = HUD.focus || PLOTS.get('0,0'); ACTIONS.focusPlot(p.key); cam.tZoom = defaultZoom(); };
    window.addEventListener('keydown', e => {
        if (e.target && (e.target.tagName === 'INPUT')) return;
        if (document.getElementById('title')) return;
        if (typeof CINE !== 'undefined' && CINE.on === 'intro') return; // Esc skips it (cine.js); nothing else fires under the intro
        const k = e.key.toLowerCase(); const step = 1.2 / cam.zoom;
        if (k === 'v') { HUD.closeSheet(); WALK.toggle(); return; }
        if (k === 'p') { if (UIX.photo.on) UIX.photo.exit(); else UIX.photo.enter(); return; }
        if (k === 'l') { LAB.toggle(); return; }
        if (k === '?' || (k === '/' && e.shiftKey)) { HUD.openPanel('help'); return; }
        if (WALK.on && ['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' ', 'e', 'shift'].includes(k)) return;
        if (k === 'escape' && UIX.photo.on) { UIX.photo.exit(); return; }
        if (k === 'escape' && LAB.open) { LAB.close(); return; }
        const move = (dx, dy) => { const c = Math.cos(cam.angle + Math.PI / 4), s = Math.sin(cam.angle + Math.PI / 4); cam.x += dx * c + dy * s; cam.y += -dx * s + dy * c; cam.tx = cam.ty = null; };
        if (k === 'q') turn(-Math.PI / 2); else if (k === 'e') turn(Math.PI / 2);
        else if (k === 'arrowleft' || k === 'a') move(-step, 0); else if (k === 'arrowright' || k === 'd') move(step, 0);
        else if (k === 'arrowup' || k === 'w') move(0, -step * 2); else if (k === 'arrowdown' || k === 's') move(0, step * 2);
        else if (k === '+' || k === '=') cam.tZoom = clampZoom(cam.tZoom * 1.2); else if (k === '-') cam.tZoom = clampZoom(cam.tZoom / 1.2);
        else if (k === 'escape') { HUD.closeSheet(); HUD.closePanel(); }
        else if (k === 'b' && HUD.sheetId) ACTIONS.buy(HUD.sheetId, buyMode);
        else if (k === 'm' && HUD.sheetId) ACTIONS.buy(HUD.sheetId, 'MAX');
        else if (k === ' ' && HUD.focus) { e.preventDefault(); ACTIONS.buyAll(HUD.focus); }
        else if (['1', '2', '3', '4'].includes(k)) ACTIONS.setBuyMode(buyModes[Number(k) - 1]);
        else return;
    });
    window.addEventListener('pointerdown', () => AUDIO.unlock(), { once: true });
}
function defaultZoom() { const W = window.innerWidth, H = window.innerHeight; return Math.max(0.45, Math.min(1.25, Math.min(W, H * 1.5) / 560)); }

// ---------- dev bar ----------
function initDevBar() {
    $('dvMax').onclick = () => { AUDIO.unlock(); ACTIONS.maxNextPlot(); };
    $('dvSim').onclick = () => { AUDIO.unlock(); ACTIONS.simToNextPlot(); };
    $('simStop').onclick = () => stopSim();
    $('dvSpeed').onclick = () => ACTIONS.cycleSpeed();
    $('dvBot').onclick = () => ACTIONS.toggleBot();
    $('dvTimeline').onclick = () => HUD.openPanel('timeline');
    $('dvAway').onclick = () => ACTIONS.away(1);
    $('dvNames').onclick = () => { SETTINGS.set('names', SETTINGS.get('names') === 'ul' ? 'stud' : 'ul'); AUDIO.tap(); };
    $('dvTime').onclick = () => { WORLD.env.tod = (WORLD.env.tod + 6) % 24; AUDIO.tap(); };
    $('dvLab').onclick = () => { AUDIO.unlock(); LAB.toggle(); };
}

// ---------- boot ----------
let _last = performance.now(), _lastHud = 0, _lastInfo = 0, _lastSave = performance.now();
function frame(now) {
    const dt = Math.min(0.1, Math.max(0, (now - _last) / 1000)); _last = now;
    if (GAME.sim) simStep();
    else {
        GAME.acc += dt * 1000 * GAME.speed;
        const t0 = performance.now(); const m = SAVE_META();
        while (GAME.acc >= STUD_CONFIG.GAME_TICK_MS) {
            GAME.acc -= STUD_CONFIG.GAME_TICK_MS;
            if (GAME.botOn) BOT.run(STUD_CONFIG.GAME_TICK_MS); else BOT.tick(STUD_CONFIG.GAME_TICK_MS);
            m.playMs += STUD_CONFIG.GAME_TICK_MS;
            if (performance.now() - t0 > 22) { GAME.acc = Math.min(GAME.acc, 1000); break; }
        }
        checkPlots(false);
    }
    if (now - _lastInfo > 250) {
        _lastInfo = now; computeSignInfo(); computeBest(); WORLD.setFocus(HUD.focus ? HUD.focus.key : null);
        // music follows what you are doing: busier when buying, and it takes the colour of the plot you look at
        GAME.activity = Math.max(0, (GAME.activity || 0) - 0.02);
        if (AUDIO.setMusicIntensity) AUDIO.setMusicIntensity(Math.min(1, 0.25 + GAME.activity + (WORLD.FXD.inHero() ? 0.3 : 0)));
        if (AUDIO.setTheme && HUD.focus && HUD.focus.theme !== GAME.theme) { GAME.theme = HUD.focus.theme; AUDIO.setTheme(GAME.theme); }
    }
    META.tick(dt); UIX.tick(dt);
    WORLD.draw(dt, nodeState);
    HUD.heroFrame();
    if (now - _lastHud > 100) { _lastHud = now; HUD.update(); }
    if (now - _lastSave > 10000) { _lastSave = now; saveGame(); }
    requestAnimationFrame(frame);
}
function boot() {
    UIX.buildLogo();
    UIX.titleProgress(0.35, 'Loading the Upgrade Land engine...');
    const loaded = loadGame();
    SAVE_META();
    let offline = null;
    if (loaded) offline = processOfflineProgress(Date.now());
    gameState.offlineTimestamp = Date.now();
    WORLD.init();
    HUD.init(); UIX.init();
    initInput(); initDevBar();
    GAME.prevBuilt = new Set(); checkPlots(true);
    META.init(); CITY.init();
    WORLD.on('autoQuality', (q) => { HUD.toast(`Graphics set to ${q.toUpperCase()} to keep things smooth`); try { SETTINGS.set('quality', q); } catch (e) { } });
    const start = HUD.focus && WORLD.builtPlots().has(HUD.focus.key) ? HUD.focus : PLOTS.get('0,0');
    const cam = WORLD.cam;
    cam.x = start.x0 + 2.5; cam.y = start.y0 + 2.5; cam.zoom = cam.tZoom = defaultZoom();
    computeSignInfo();
    window.addEventListener('resize', () => WORLD.resize());
    document.addEventListener('visibilitychange', () => { if (document.hidden) saveGame(); });
    window.addEventListener('pagehide', () => saveGame());
    requestAnimationFrame(t => { _last = t; frame(t); });
    UIX.titleProgress(0.7, 'Painting the islands...');
    setTimeout(() => {
        UIX.titleReady(() => {
            // a new save gets the full intro (cloud dive, the city builds itself, parachute, HUD slam);
            // a returning player gets a quick camera swoop so they are playing within a second
            if (!loaded && !META.state().introSeen) { CINE.intro({ fresh: true }); return; }
            cam.zoom = 0.3; cam.angle = -0.9; cam.tAngle = 0; cam.tZoom = defaultZoom();
            FX.sfx('camWhoosh');
            if (offline) setTimeout(() => HUD.offline(offline), 900);
            else if (!loaded) setTimeout(() => HUD.toast('Tap the blue blueprint to build your first machine!', '#fff3b0'), 1200);
        });
    }, 450);
}
(document.fonts && document.fonts.load ? Promise.all([document.fonts.load('20px "Luckiest Guy"'), document.fonts.load('600 16px "Fredoka"')]).catch(() => { }) : Promise.resolve())
    .then(() => boot(), () => boot());
