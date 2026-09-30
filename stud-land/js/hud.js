// Stud City Incremental HUD (DOM). Reads game state and calls ACTIONS (defined in main.js) for anything that
// changes it. Text updates are throttled and only touch the DOM when a string actually changes.
const $ = (id) => document.getElementById(id);
function el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html !== undefined) e.innerHTML = html; return e; }
function setText(e, t) { if (e && e._t !== t) { e._t = t; e.textContent = t; } }
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

// Same math as buyUpgrade, but read only: how many levels the next press buys and what it costs.
function previewBuy(node, mode) {
    const currentLvl = getLevel(node.id), max = getMaxLevel(node);
    if (currentLvl >= max) return { levels: 0, cost: Infinity, maxed: true };
    const currency = gameState.currencies[node.costCurrency] || 0;
    let bought = 0, totalCost = 0, firstCost = 0;
    if (node.bulkFinalCost) {
        let target = currentLvl;
        const desiredMax = mode === 'MAX' ? max : Math.min(max, currentLvl + mode);
        let lo = currentLvl + 1, hi = desiredMax, it = 0;
        while (lo <= hi && it < 1200) { const mid = Math.floor((lo + hi) / 2); const c = node.costFormula(mid, getLevel, getCurr); if (typeof c === 'number' && !isNaN(c) && c <= currency) { target = mid; lo = mid + 1; } else hi = mid - 1; it++; }
        firstCost = node.costFormula(currentLvl + 1, getLevel, getCurr);
        if (target > currentLvl) { bought = target - currentLvl; totalCost = node.costFormula(target, getLevel, getCurr); }
    } else {
        const toBuy = mode === 'MAX' ? (max - currentLvl) : Math.min(mode, max - currentLvl);
        firstCost = node.costFormula(currentLvl, getLevel, getCurr);
        const cap = Math.min(toBuy, 5000);
        for (let i = 0; i < cap; i++) { const c = node.costFormula(currentLvl + i, getLevel, getCurr); if (currency >= totalCost + c) { totalCost += c; bought++; } else break; }
    }
    return { levels: bought, cost: bought ? totalCost : firstCost, firstCost };
}

const SETTINGS = (() => {
    const KEY = 'STUD_LAND_HTML_SETTINGS';
    const def = { muted: false, volume: 0.8, fx: 'full', haptics: true, names: 'stud', pass: false, dayLen: 12 };
    let s = { ...def };
    try { const raw = localStorage.getItem(KEY); if (raw) s = { ...def, ...JSON.parse(raw) }; } catch (e) { }
    try { if (!localStorage.getItem(KEY) && window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) s.fx = 'reduced'; } catch (e) { }
    return { get: (k) => s[k], set(k, v) { s[k] = v; try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { } HUD.applySettings(); } };
})();

const HUD = (() => {
    let sheetId = null, panelKind = null, stackOpen = false, lastStackKeys = '';
    let heroShown = 0;
    let focus = null;
    const rows = new Map();

    function init() {
        $('heroIcon').src = curIcon('P', 96);
        $('stackMore').onclick = () => { stackOpen = !stackOpen; setText($('stackMore'), stackOpen ? 'LESS' : 'MORE'); lastStackKeys = ''; AUDIO.tap(); };
        $('tReset').onclick = () => openPanel('reset');
        $('tIndex').onclick = () => openPanel('index');
        $('tSet').onclick = () => openPanel('settings');
        $('panelX').onclick = closePanel;
        $('panel').addEventListener('pointerdown', e => { if (e.target.id === 'panel') closePanel(); });
        $('buySeg').querySelectorAll('button').forEach(b => b.onclick = () => { const m = b.dataset.m === 'MAX' ? 'MAX' : Number(b.dataset.m); ACTIONS.setBuyMode(m); AUDIO.tap(); });
        $('buyAll').onclick = () => { if (focus) ACTIONS.buyAll(focus); };
        syncBuyMode();
        applySettings();
    }
    function applySettings() {
        AUDIO.setMuted(SETTINGS.get('muted')); AUDIO.setVolume(SETTINGS.get('volume'));
        WORLD.DIRECTOR.mode = SETTINGS.get('fx'); HAPTIC.on = SETTINGS.get('haptics') && SETTINGS.get('fx') !== 'minimal';
        SHOW_UL_NAMES = SETTINGS.get('names') === 'ul';
        STUD_CONFIG.OFFLINE_CAP_SECONDS = SETTINGS.get('pass') ? 300 : 180;
        WORLD.env.dayLen = SETTINGS.get('dayLen') * 60;
        setText($('dvNames'), SHOW_UL_NAMES ? 'NAMES: UL' : 'NAMES: STUD');
        lastStackKeys = '';
        if (panelKind) renderPanel();
    }
    function syncBuyMode() { $('buySeg').querySelectorAll('button').forEach(b => b.classList.toggle('on', String(b.dataset.m) === String(buyMode))); if (sheetId) refreshSheet(true); }

    // ---------- per frame / per tick ----------
    function heroFrame() {
        const v = getCurr('P');
        if (!isFinite(v) || !isFinite(heroShown) || Math.abs(v - heroShown) <= Math.abs(v) * 0.002 || v < heroShown) heroShown = v;
        else heroShown += (v - heroShown) * 0.25;
        setText($('heroNum'), formatNum(heroShown));
    }
    function update() {
        setText($('heroLabel'), curName('P').toUpperCase());
        setText($('heroRate'), '+' + formatNum(calculateGainRate('P')) + '/s');
        const f = WORLD.focusPlot();
        if (f && (WORLD.builtPlots().has(f.key))) focus = f;
        if (!focus) focus = PLOTS.get('0,0');
        updateStack();
        updateZone();
        // rebuild badge: resets that are ready
        let ready = 0; for (const n of TREE_NODES) if (n.type === 'reset' && isNodeUnlocked(n) && WORLD.builtPlots().has(plotKeyOf(n.coords[0], n.coords[1])) && getEffectiveResetGain(n) > 0) ready++;
        const b = $('tResetBadge'); b.classList.toggle('hidden', ready === 0); setText(b, String(ready));
        setText($('dvClock'), 'PLAY ' + formatTime(META().playMs));
        if (sheetId) refreshSheet(false);
        if (panelKind === 'reset' || panelKind === 'index' || panelKind === 'timeline') refreshPanelLive();
    }
    function stackKeys() {
        const all = (gameState.currencyOrder || []).filter(k => k !== 'P' && gameState.discoveredCurrencies.includes(k) && !(gameState.hiddenCurrencies || []).includes(k) && CURRENCIES[k]);
        const rel = new Set();
        if (focus) { plotCurrencies(focus).forEach(k => rel.add(k)); focus.upgrades.forEach(n => n.costCurrency && rel.add(n.costCurrency)); }
        const first = all.filter(k => rel.has(k)), rest = all.filter(k => !rel.has(k));
        const ordered = [...first, ...rest];
        return { list: stackOpen ? ordered : ordered.slice(0, collapsedRows()), hot: rel, total: ordered.length };
    }
    function collapsedRows() { return window.innerHeight < 500 || window.innerWidth < 720 ? 2 : 3; }
    function updateStack() {
        const { list, hot, total } = stackKeys();
        $('stackMore').classList.toggle('hidden', total <= collapsedRows());
        const sig = list.join('|') + (SHOW_UL_NAMES ? 'u' : 's');
        const st = $('stack');
        if (sig !== lastStackKeys) {
            lastStackKeys = sig; st.innerHTML = ''; rows.clear();
            for (const k of list) {
                const r = el('div', 'srow');
                r.innerHTML = `<img alt="" src="${curIcon(k, 64)}"><div><div class="nm"></div><div class="am lg"></div></div><div class="rt"></div>`;
                st.appendChild(r); rows.set(k, { r, nm: r.querySelector('.nm'), am: r.querySelector('.am'), rt: r.querySelector('.rt') });
            }
        }
        for (const [k, o] of rows) {
            setText(o.nm, curName(k).toUpperCase());
            setText(o.am, formatNum(getCurr(k)));
            const rate = calculateGainRate(k);
            setText(o.rt, rate > 0 ? '+' + formatNum(rate) + '/s' : '');
            o.r.classList.toggle('hot', hot.has(k));
        }
    }
    function updateZone() {
        const p = focus; if (!p) return;
        const tab = $('zbTab'); setText(tab, p.name.toUpperCase()); if (tab._c !== p.color) { tab._c = p.color; tab.style.background = p.color; }
        const info = ACTIONS.signInfo().get(p.key) || {};
        setText($('zbRate'), info.rateText || '');
        const st = plotStats(p);
        setText($('zbLv'), `LV ${formatNum(st.lv)} / ${formatNum(st.max)}`);
        $('zbFill').style.width = (st.max ? Math.min(100, 100 * st.lv / st.max) : 0).toFixed(1) + '%';
        $('buyAll').classList.toggle('dim', st.affordable === 0);
        setText($('buyAll'), st.affordable ? `BUY ALL (${st.affordable})` : 'BUY ALL');
    }

    // ---------- machine sheet ----------
    function openNode(id) {
        const n = NODE_MAP.get(id); if (!n) return;
        sheetId = id; WORLD.setSelected(id);
        const sh = $('sheet'); sh.classList.remove('hidden'); sh.innerHTML = ''; sh.style.animation = 'none'; void sh.offsetWidth; sh.style.animation = '';
        const p = PLOTS.get(plotKeyOf(n.coords[0], n.coords[1]));
        const head = el('div', 'sh-head'); head.style.background = n.type === 'reset' ? '#8a4fe0' : n.type === 'info' ? '#4aa8ff' : (p ? p.color : '#3fbf5f');
        head.innerHTML = `<span class="sh-code">${esc(n.code || n.id)}</span><div class="sh-name">${esc(n.type === 'reset' ? 'REBUILD' : n.name)}</div>`;
        const x = el('button', 'x', '&times;'); x.setAttribute('aria-label', 'Close'); x.onclick = closeSheet; head.appendChild(x);
        const body = el('div', 'sh-body'); body.id = 'shBody';
        sh.append(head, body);
        AUDIO.open();
        refreshSheet(true);
    }
    function closeSheet() { if (!sheetId) return; sheetId = null; WORLD.setSelected(null); $('sheet').classList.add('hidden'); AUDIO.close(); }
    function refreshSheet(full) {
        const n = NODE_MAP.get(sheetId); const body = $('shBody'); if (!n || !body) return;
        if (n.type === 'upgrade') return sheetUpgrade(n, body, full);
        if (n.type === 'reset') return sheetReset(n, body, full);
        if (full) body.innerHTML = `<div class="sh-desc">${esc(n.name)}</div><div class="sh-note">${esc(n.desc || '')}</div><div class="sh-desc" id="shInfo"></div>`;
        try { setText($('shInfo'), n.getInfoText ? n.getInfoText() : ''); } catch (e) { }
    }
    function sheetUpgrade(n, body, full) {
        const lvl = getLevel(n.id), max = getMaxLevel(n), unlocked = isNodeUnlocked(n);
        if (full || body._state !== (unlocked ? 'u' : 'l')) {
            body._state = unlocked ? 'u' : 'l';
            const makes = [];
            for (const e of (n.effects || [])) { const c = e.currency || e.targetCurrency; if (c && !makes.includes(c)) makes.push(c); }
            body.innerHTML = `<div class="sh-desc">${esc(n.desc || '')}</div>
              ${makes.length ? `<div class="sh-note">Boosts: ${makes.map(c => `<span class="tag">${esc(curName(c))}</span>`).join('')}</div>` : ''}
              <div class="sh-lv"><span id="shLv"></span><div class="zb-bar"><i id="shFill"></i></div></div>
              ${unlocked ? `<div class="sh-cost"><img alt="" src="${curIcon(n.costCurrency, 64)}"><span>Cost</span><b id="shCost"></b><span class="have" id="shHave"></span></div>
              <div class="sh-btns"><button class="big" id="shBuy"><span></span></button><button class="big max" id="shMax"><span></span></button></div>`
                : `<div class="sh-note">LOCKED. Build these first: ${(n.reqs || []).map(([x, y]) => { const r = COORD_MAP.get(`${x},${y}`); return r ? `<span class="tag">${esc(r.code || r.id)} ${esc(r.name).slice(0, 24)}</span>` : ''; }).join('')}</div>`}
              <div class="sh-note">Upgrade Land id ${esc(n.id)}, tree spot ${n.coords.join(', ')}</div>`;
            if (unlocked) {
                $('shBuy').onclick = () => ACTIONS.buy(n.id, buyMode);
                $('shMax').onclick = () => ACTIONS.buy(n.id, 'MAX');
            }
        }
        setText($('shLv'), lvl >= max ? `MAX ${formatNum(lvl)}` : `LV ${formatNum(lvl)} / ${formatNum(max)}`);
        $('shFill').style.width = Math.min(100, 100 * lvl / max).toFixed(1) + '%';
        $('shFill').style.background = lvl >= max ? 'var(--yellow)' : '';
        if (!unlocked) return;
        const pv = previewBuy(n, buyMode), pm = previewBuy(n, 'MAX');
        const have = getCurr(n.costCurrency);
        setText($('shCost'), lvl >= max ? 'MAXED' : formatNum(pv.levels ? pv.cost : pv.firstCost));
        setText($('shHave'), `you have ${formatNum(have)} ${curName(n.costCurrency)}`);
        const b = $('shBuy'), m = $('shMax');
        const bl = lvl >= max ? 'MAXED' : pv.levels ? `BUY +${formatNum(pv.levels)}` : `NEED ${formatNum(Math.max(0, pv.firstCost - have))}`;
        setText(b.firstChild, bl); b.classList.toggle('off', !pv.levels);
        setText(m.firstChild, lvl >= max ? 'MAXED' : pm.levels ? `MAX +${formatNum(pm.levels)}` : 'MAX');
        m.classList.toggle('off', !pm.levels);
    }
    function sheetReset(n, body, full) {
        const gain = getEffectiveResetGain(n);
        if (full) {
            const list = getResettedCoordsList(n).filter(e => e.id);
            const curr = (n.resetCurrencies || []).map(c => `<span class="tag">${esc(curName(c))}</span>`).join('');
            body.innerHTML = `<div class="sh-desc">${esc(n.name)}</div>
              <div class="sh-cost"><img alt="" src="${curIcon(n.targetCurrency, 64)}"><span>You get</span><b id="shGain"></b><span class="have" id="shHave"></span></div>
              <div class="sh-list">Resets ${curr || 'no currencies'} and ${list.length} machines.</div>
              <div class="sh-btns"><button class="big purple" id="shReset"><i class="fill"></i><span>HOLD TO REBUILD</span></button></div>`;
            holdButton($('shReset'), 700, () => ACTIONS.reset(n.id));
        }
        setText($('shGain'), '+' + formatNum(gain) + ' ' + curName(n.targetCurrency));
        setText($('shHave'), `you have ${formatNum(getCurr(n.targetCurrency))}`);
        const b = $('shReset'); b.classList.toggle('off', !(gain > 0)); setText(b.querySelector('span'), gain > 0 ? 'HOLD TO REBUILD' : 'NOT READY YET');
    }
    function holdButton(btn, ms, done) {
        let t0 = 0, raf = 0; const fill = btn.querySelector('.fill');
        const stop = () => { cancelAnimationFrame(raf); t0 = 0; if (fill) fill.style.width = '0'; };
        const step = () => { const k = (performance.now() - t0) / ms; if (fill) fill.style.width = Math.min(100, k * 100) + '%'; if (k >= 1) { stop(); done(); } else raf = requestAnimationFrame(step); };
        btn.addEventListener('pointerdown', e => { if (btn.classList.contains('off')) { AUDIO.deny(); return; } e.preventDefault(); t0 = performance.now(); raf = requestAnimationFrame(step); });
        ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => btn.addEventListener(ev, () => { if (t0) stop(); }));
        btn.addEventListener('click', e => { if (e.detail === 0 && !btn.classList.contains('off')) done(); });
    }

    // ---------- panels ----------
    function openPanel(kind) { panelKind = kind; $('panel').classList.remove('hidden'); AUDIO.open(); renderPanel(); }
    function closePanel() { if (!panelKind) return; panelKind = null; $('panel').classList.add('hidden'); AUDIO.close(); }
    function renderPanel() {
        const body = $('panelBody'); body.innerHTML = '';
        const head = document.querySelector('.panel-head');
        const titles = { reset: 'REBUILD', index: 'PLOTS', settings: 'SETTINGS', timeline: 'BALANCE TIMELINE' };
        const colors = { reset: '#8a4fe0', index: '#2f8fe0', settings: '#8b96a3', timeline: '#231c3d' };
        setText($('panelTitle'), titles[panelKind]); head.style.background = colors[panelKind];
        if (panelKind === 'reset') panelReset(body);
        else if (panelKind === 'index') panelIndex(body);
        else if (panelKind === 'settings') panelSettings(body);
        else if (panelKind === 'timeline') panelTimeline(body);
    }
    const live = [];
    function refreshPanelLive() { for (const f of live) f(); }
    function panelReset(body) {
        live.length = 0;
        const nodes = TREE_NODES.filter(n => n.type === 'reset' && isNodeUnlocked(n) && WORLD.builtPlots().has(plotKeyOf(n.coords[0], n.coords[1])));
        if (!nodes.length) body.appendChild(el('div', 'note', 'No rebuild portals yet. Research is the first one: it sits on Blueprint Lab once Studs reach 2,500.'));
        for (const n of nodes) {
            const r = el('div', 'row');
            r.innerHTML = `<div class="chip" style="background:${curHex(n.targetCurrency)}"></div><div class="grow"><div class="t1">${esc(n.code || n.id)}: ${esc(curName(n.targetCurrency))}</div><div class="t2"></div></div>
              <button class="sbtn">GO TO</button><button class="sbtn go"><i class="fill" style="position:absolute;inset:0;width:0;background:rgba(255,255,255,.35)"></i><span style="position:relative">HOLD</span></button>`;
            const [goto, hold] = r.querySelectorAll('.sbtn');
            goto.onclick = () => { closePanel(); ACTIONS.focusNode(n.id); };
            holdButton(hold, 700, () => ACTIONS.reset(n.id));
            const t2 = r.querySelector('.t2');
            const upd = () => { const g = getEffectiveResetGain(n); setText(t2, g > 0 ? `+${formatNum(g)} now, you have ${formatNum(getCurr(n.targetCurrency))}` : `not ready, you have ${formatNum(getCurr(n.targetCurrency))}`); hold.classList.toggle('off', !(g > 0)); };
            upd(); live.push(upd); body.appendChild(r);
        }
    }
    function panelIndex(body) {
        live.length = 0;
        const built = WORLD.builtPlots();
        for (const p of PLOT_ORDER) {
            const isBuilt = built.has(p.key);
            const r = el('div', 'row' + (isBuilt ? '' : ' locked'));
            r.innerHTML = `<div class="chip" style="background:${p.color}"></div><div class="grow"><div class="t1">${esc(p.name)}</div><div class="t2">${esc(p.ul)}</div><div class="zb-bar mini"><i></i></div></div>`;
            const btn = el('button', 'sbtn', isBuilt ? 'GO' : p.soon ? 'SOON' : 'LOOK');
            btn.onclick = () => { closePanel(); ACTIONS.focusPlot(p.key); };
            r.appendChild(btn);
            const fill = r.querySelector('i'), t2 = r.querySelector('.t2');
            const upd = () => { const s = plotStats(p); fill.style.width = (s.max ? Math.min(100, 100 * s.lv / s.max) : 0) + '%'; setText(t2, `${p.ul}, ${isBuilt ? `LV ${formatNum(s.lv)}/${formatNum(s.max)}` : p.soon ? 'not in the game yet' : 'not built'}`); };
            upd(); live.push(upd); body.appendChild(r);
        }
    }
    function seg(opts, cur, onPick) {
        const s = el('div', 'seg');
        for (const [v, label] of opts) { const b = el('button', String(v) === String(cur) ? 'on' : '', label); b.onclick = () => { onPick(v); AUDIO.tap(); }; s.appendChild(b); }
        return s;
    }
    function opt(label, ctrl) { const o = el('div', 'opt'); o.appendChild(el('span', '', label)); o.appendChild(ctrl); return o; }
    function panelSettings(body) {
        live.length = 0;
        body.appendChild(opt('Sound', seg([[false, 'ON'], [true, 'OFF']], SETTINGS.get('muted'), v => SETTINGS.set('muted', v))));
        const vol = el('input'); vol.type = 'range'; vol.min = 0; vol.max = 1; vol.step = 0.05; vol.value = SETTINGS.get('volume'); vol.oninput = () => SETTINGS.set('volume', Number(vol.value));
        body.appendChild(opt('Volume', vol));
        body.appendChild(opt('Effects', seg([['full', 'FULL'], ['reduced', 'REDUCED'], ['minimal', 'MINIMAL']], SETTINGS.get('fx'), v => SETTINGS.set('fx', v))));
        body.appendChild(opt('Vibration', seg([[true, 'ON'], [false, 'OFF']], SETTINGS.get('haptics'), v => SETTINGS.set('haptics', v))));
        body.appendChild(opt('Names', seg([['stud', 'STUD CITY'], ['ul', 'UPGRADE LAND']], SETTINGS.get('names'), v => SETTINGS.set('names', v))));
        body.appendChild(opt('Offline time', seg([[false, '3:00'], [true, 'PASS 5:00']], SETTINGS.get('pass'), v => SETTINGS.set('pass', v))));
        body.appendChild(opt('Day length', seg([[6, '6 MIN'], [12, '12 MIN'], [24, '24 MIN']], SETTINGS.get('dayLen'), v => SETTINGS.set('dayLen', v))));
        body.appendChild(el('div', 'note', 'Offline gain pays at most 3 minutes (5 with the pass) no matter how long you were away, so coming back never skips a pile of upgrades. Random and self limiting currencies (copper, silver, gold, lapis, diamonds, essence and more) do not pay offline, same as Upgrade Land.'));
        const wipe = el('button', 'big purple'); wipe.innerHTML = '<i class="fill"></i><span>HOLD TO WIPE SAVE</span>'; wipe.style.background = 'var(--red)';
        holdButton(wipe, 1200, () => ACTIONS.wipe());
        body.appendChild(wipe);
    }
    function panelTimeline(body) {
        live.length = 0;
        const m = META();
        body.appendChild(el('div', 'note', `Play time on this save: <b>${formatTime(m.playMs)}</b>. "You" is the play time when each plot got built on this save (MAX NEXT PLOT and SIM count too). "Bot" is a fresh save played by the greedy bot in tools/balance.js. It is a rough pacing guide, not a target.`));
        const t = el('table', 'tbl');
        t.innerHTML = '<thead><tr><th>Plot</th><th>You</th><th>Bot</th><th>How</th></tr></thead>';
        const tb = el('tbody');
        for (const p of PLOT_ORDER) {
            if (p.soon) continue;
            const you = m.plotBuiltAt[p.key], bot = (typeof BOT_BENCHMARK !== 'undefined' && BOT_BENCHMARK.plots[p.key]);
            const tr = el('tr', you !== undefined ? 'done' : '');
            tr.innerHTML = `<td>${esc(p.name)}</td><td class="n">${you !== undefined ? formatTime(you) : '-'}</td><td class="n">${bot !== undefined && bot !== false ? formatTime(bot) : 'not reached'}</td><td>${esc(m.plotHow[p.key] || '')}</td>`;
            tb.appendChild(tr);
        }
        t.appendChild(tb); body.appendChild(t);
        if (m.sims.length) {
            body.appendChild(el('div', 'note', '<b>Sim runs on this save</b>'));
            const t2 = el('table', 'tbl'); t2.innerHTML = '<thead><tr><th>Reached</th><th>Bot play time</th><th>Real time</th></tr></thead>';
            const b2 = el('tbody'); for (const s of m.sims.slice(-12).reverse()) { const tr = el('tr'); tr.innerHTML = `<td>${esc(s.name)}</td><td class="n">${formatTime(s.simMs)}</td><td class="n">${(s.realMs / 1000).toFixed(1)}s</td>`; b2.appendChild(tr); }
            t2.appendChild(b2); body.appendChild(t2);
        }
        if (typeof BOT_BENCHMARK !== 'undefined') body.appendChild(el('div', 'note', esc(BOT_BENCHMARK.note)));
    }

    // ---------- toasts, banner, modal, sim ----------
    function toast(msg, color) {
        const box = $('toasts'); while (box.children.length > 3) box.firstChild.remove();
        const t = el('div', 'toast'); t.textContent = msg; if (color) t.style.background = color;
        box.appendChild(t); setTimeout(() => t.remove(), 3000);
    }
    let bannerTimer = 0;
    function banner(name, label = 'NEW PLOT!') {
        const b = $('banner'); setText(b.querySelector('.b1'), label); setText($('bannerName'), name.toUpperCase());
        b.classList.remove('hidden', 'out'); b.querySelectorAll('div').forEach(d => { d.style.animation = 'none'; void d.offsetWidth; d.style.animation = ''; });
        clearTimeout(bannerTimer); bannerTimer = setTimeout(() => { b.classList.add('out'); setTimeout(() => b.classList.add('hidden'), 400); }, 2400);
    }
    function modal(html, buttons) {
        const m = $('modal'), c = $('modalCard'); c.innerHTML = html;
        const foot = el('div', 'mfoot');
        for (const [label, cls, fn] of buttons) { const b = el('button', 'big ' + cls, `<span>${label}</span>`); b.onclick = () => { m.classList.add('hidden'); AUDIO.close(); fn && fn(); }; foot.appendChild(b); }
        c.appendChild(foot); m.classList.remove('hidden'); AUDIO.open();
    }
    function offline(res) {
        const gains = Object.entries(res.gains).sort((a, b) => (b[0] === 'P') - (a[0] === 'P')).slice(0, 8);
        const capS = STUD_CONFIG.OFFLINE_CAP_SECONDS;
        modal(`<div class="mh"><div class="t">WELCOME BACK</div><div class="s">You were away ${formatTime(res.offlineSeconds * 1000)}. Your plots worked for ${formatClock(res.paidSeconds)} of it.</div></div>
          <div class="capbar"><div class="zb-bar"><i style="width:${Math.min(100, 100 * res.paidSeconds / capS)}%"></i></div><div class="note" style="margin-top:4px">Offline cap ${formatClock(capS)}${SETTINGS.get('pass') ? ' with Offline Pass' : ', Offline Pass makes it 5:00'}</div></div>
          <div class="gains">${gains.map(([k, v]) => `<div class="gain"><img alt="" src="${curIcon(k, 64)}"><span>${esc(curName(k))}</span><b>+${formatNum(v)}</b></div>`).join('')}</div>`,
            [['COLLECT', '', () => ACTIONS.collectFx()]]);
    }
    function sim(show, time, sub) { $('simbox').classList.toggle('hidden', !show); if (show) { setText($('simTime'), time); setText($('simSub'), sub); } }
    return { init, update, heroFrame, openNode, closeSheet, openPanel, closePanel, toast, banner, modal, offline, sim, syncBuyMode, applySettings, get sheetId() { return sheetId; }, get panelKind() { return panelKind; }, get focus() { return focus; }, set focus(p) { focus = p; } };
})();
