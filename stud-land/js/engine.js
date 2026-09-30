// Stud City Incremental engine: a DOM-free port of the Upgrade Land engine.
// Every function that touches the math is copied line for line from the original
// (andyyim175/upgtree index.html) so results match bit for bit. Only rendering,
// sound and DOM calls were removed; they are replaced by the EVENTS hooks below.
// Global names (gameState, getCurr, getLevel, calculateGainRate, getResetGain,
// formatNum, buyMode) are kept because the node formulas in ul-data.js call them.

// ==================== CONFIG (Stud City Incremental changes live here, nowhere else) ====================
const STUD_CONFIG = {
    GAME_TICK_MS: 100,            // same as the original
    AUTOMATION_INTERVAL_MS: 200,  // same as the original
    // Offline: the Stud City Incremental dev asked for a hard cap of 2 to 5 minutes instead of the
    // original softcap (which paid about 6 minutes for 1 hour away and 14 minutes for 8 hours).
    OFFLINE_CAP_SECONDS: 180,
    OFFLINE_MODE: 'stud_cap',     // 'stud_cap' (hard cap above) or 'original' (Upgrade Land softcap)
    SAVE_KEY: 'STUD_LAND_HTML_V1',
    SAVE_BACKUP_KEY: 'STUD_LAND_HTML_V1_BACKUP',
};

// ==================== EVENTS ====================
const EVENTS = {
    _h: {},
    on(name, fn) { (this._h[name] = this._h[name] || []).push(fn); },
    emit(name, data) { const l = this._h[name]; if (!l) return; for (const fn of l) { try { fn(data); } catch (e) { console.warn('event', name, e); } } },
};

// ==================== GAME STATE (same shape and defaults as the original) ====================
function freshGameState() {
    return { currencies: { P: 0, PR: 0, QT: 0, T: 0, D1: 0, D2: 0, D3: 0, D4: 0, D5: 0, D6: 0, D7: 0, D8: 0 }, discoveredCurrencies: ['P'], currencyOrder: ['P'], hiddenCurrencies: [], userHiddenCurrencies: [], levels: {}, unlockedDecorations: [], skipResetConfirm: {}, paused: false, offlineTimestamp: Date.now(), buyMode: 1 };
}
let gameState = freshGameState();
let buyMode = 1;
const buyModes = [1, 5, 10, 'MAX'];
let lastAutomationTime = 0;
let needsNodeUpdate = true;

// ==================== CACHES (identical semantics to the original) ====================
const cache = { maxLevel: new Map(), displayCost: new Map(), gainRate: new Map(), resetGain: new Map(), format: new Map() };
let cacheDirty = true;
let cacheDirtyFrame = 0;
let _maxLevelModEffectsBuilt = false;
let _maxLevelCache = {};
let _maxLevelFrame = {};
let _maxLevelModEffects = null;
let _currencyRateCache = {};
let _currencyRateFrame = {};
let _displayCostCache = {};
let _displayCostFrame = {};
let _resetGainCache = {};
let _resetGainFrame = {};
let _formatCache = {};

function ensureMaxLevelModIndex() {
    if (_maxLevelModEffectsBuilt) return;
    _maxLevelModEffects = [];
    TREE_NODES.forEach(other => {
        if (other.type !== 'upgrade' || !other.effects) return;
        other.effects.forEach(eff => {
            if (eff.type === 'max_level_mod') {
                _maxLevelModEffects.push({ nodeId: other.id, targets: Array.isArray(eff.target) ? eff.target : [eff.target], amount: eff.amount });
            }
        });
    });
    _maxLevelModEffectsBuilt = true;
}
function clearTickCaches() {
    cacheDirty = true;
    cacheDirtyFrame++;
    _maxLevelCache = {};
    _currencyRateCache = {};
    _resetGainCache = {};
    _displayCostCache = {};
}
function getLevel(nodeId) { return gameState.levels[nodeId] || 0; }
function getCurr(key) { return gameState.currencies[key] || 0; }
function clearCaches(clearAll = false) {
    cacheDirty = true;
    cacheDirtyFrame++;
    cache.maxLevel.clear();
    cache.displayCost.clear();
    cache.gainRate.clear();
    if (clearAll) {
        cache.resetGain.clear();
        _resetGainCache = {};
        _formatCache = {};
    }
    _maxLevelCache = {};
    _displayCostCache = {};
    _currencyRateCache = {};
}

// ==================== INDEXES ====================
const CURRENCY_EFFECT_INDEX = {};
Object.keys(CURRENCIES).forEach(c => CURRENCY_EFFECT_INDEX[c] = []);
TREE_NODES.forEach(node => {
    if (node.type !== 'upgrade' || !node.effects) return;
    node.effects.forEach(eff => {
        const target = eff.currency || eff.targetCurrency;
        if (!target) return;
        if (['base_gain', 'base_gain_raw', 'currency_mult', 'dynamic_mult'].includes(eff.type)) {
            if (!CURRENCY_EFFECT_INDEX[target]) CURRENCY_EFFECT_INDEX[target] = [];
            CURRENCY_EFFECT_INDEX[target].push({ nodeId: node.id, type: eff.type, formula: eff.formula });
        }
    });
});
const NODE_MAP = new Map();
const COORD_MAP = new Map();
TREE_NODES.forEach(n => { NODE_MAP.set(n.id, n); COORD_MAP.set(`${n.coords[0]},${n.coords[1]}`, n); });
const _resetGainEffectsIndex = (() => {
    const idx = {};
    TREE_NODES.forEach(node => {
        if (node.type !== 'upgrade' || !node.effects) return;
        node.effects.forEach(eff => {
            if (eff.type === 'reset_gain_add' || eff.type === 'reset_gain_mult') {
                const key = eff.targetCurrency;
                if (!idx[key]) idx[key] = [];
                idx[key].push({ nodeId: node.id, type: eff.type, formula: eff.formula });
            }
        });
    });
    return idx;
})();
// Automation targets resolved once (the original rebuilt this list every 200 ms; same result, less work).
const AUTOMATION_INDEX = (() => {
    const out = [];
    TREE_NODES.forEach(node => {
        if (node.type !== 'upgrade' || !node.effects) return;
        node.effects.forEach(eff => {
            if (eff.type !== 'automation') return;
            let targets = [];
            if (Array.isArray(eff.target)) targets = eff.target;
            else if (typeof eff.target === 'string') targets = [eff.target];
            if (eff.targetPrefix && typeof eff.targetPrefix === 'string') {
                for (const [id] of NODE_MAP) if (id.startsWith(eff.targetPrefix)) targets.push(id);
            }
            targets = [...new Set(targets)];
            out.push({ nodeId: node.id, targets });
        });
    });
    return out;
})();

// ==================== CORE MATH (copied from the original) ====================
function getMaxLevel(node) {
    if (!node || node.type !== 'upgrade') return 0;
    if (_maxLevelFrame[node.id] === cacheDirtyFrame && _maxLevelCache[node.id] !== undefined) return _maxLevelCache[node.id];
    if (!cacheDirty && cache.maxLevel.has(node.id)) return cache.maxLevel.get(node.id);
    let maxCap = node.maxLevel || 1;
    ensureMaxLevelModIndex();
    for (const mod of _maxLevelModEffects) {
        const lvl = getLevel(mod.nodeId);
        if (lvl <= 0) continue;
        if (mod.targets.includes(node.id)) {
            maxCap += typeof mod.amount === 'function' ? mod.amount(lvl, getLevel, getCurr) : (mod.amount || 0) * lvl;
        }
    }
    maxCap = Math.max(1, maxCap);
    cache.maxLevel.set(node.id, maxCap);
    _maxLevelCache[node.id] = maxCap;
    _maxLevelFrame[node.id] = cacheDirtyFrame;
    return maxCap;
}
function isNodeUnlocked(node) {
    if (!node) return false;
    if (!node.reqs || node.reqs.length === 0) return true;
    return node.reqs.every(([x, y]) => { const reqNode = COORD_MAP.get(`${x},${y}`); return reqNode && getLevel(reqNode.id) >= 1; });
}
function calculateGainRate(currency) {
    try {
        if (_currencyRateFrame[currency] === cacheDirtyFrame && _currencyRateCache[currency] !== undefined) return _currencyRateCache[currency];
        if (!cacheDirty && cache.gainRate.has(currency)) return cache.gainRate.get(currency);
        let base = 0, baseRaw = 0, mult = 1;
        const effects = CURRENCY_EFFECT_INDEX[currency];
        if (effects && effects.length > 0) {
            for (let i = 0, len = effects.length; i < len; i++) {
                const eff = effects[i];
                const lvl = gameState.levels[eff.nodeId] || 0;
                if (lvl <= 0) continue;
                const val = eff.formula(lvl, getLevel, getCurr);
                if (eff.type === 'base_gain') base += val;
                else if (eff.type === 'base_gain_raw') baseRaw += val;
                else mult *= val;
            }
        }
        if (mult <= 0) mult = 1;
        const result = base * mult + baseRaw;
        cache.gainRate.set(currency, result);
        _currencyRateCache[currency] = result;
        _currencyRateFrame[currency] = cacheDirtyFrame;
        return result;
    } catch (e) { console.warn('gainRate error for', currency, e); return 0; }
}
function getCost(node, levelOffset = 0) {
    const curLvl = getLevel(node.id) + levelOffset;
    const max = getMaxLevel(node);
    if (curLvl >= max) return Infinity;
    if (node.bulkFinalCost) { return node.costFormula(curLvl + 1, getLevel, getCurr); }
    return node.costFormula(curLvl, getLevel, getCurr);
}
function getDisplayCost(node) {
    if (_displayCostFrame[node.id] === cacheDirtyFrame && _displayCostCache[node.id] !== undefined) return _displayCostCache[node.id];
    if (!cacheDirty && cache.displayCost.has(node.id)) return cache.displayCost.get(node.id);
    const curLvl = getLevel(node.id);
    const max = getMaxLevel(node);
    let cost;
    if (curLvl >= max) { cost = Infinity; } else { cost = getCost(node); }
    cache.displayCost.set(node.id, cost);
    _displayCostCache[node.id] = cost;
    _displayCostFrame[node.id] = cacheDirtyFrame;
    return cost;
}
function getEffectiveResetGain(resetNode) {
    if (_resetGainFrame[resetNode.id] === cacheDirtyFrame && _resetGainCache[resetNode.id] !== undefined) return _resetGainCache[resetNode.id];
    if (!cacheDirty && cache.resetGain.has(resetNode.id)) return cache.resetGain.get(resetNode.id);
    const base = resetNode.calculateGain(getLevel, getCurr) || 0;
    if (base <= 0) {
        cache.resetGain.set(resetNode.id, 0);
        _resetGainCache[resetNode.id] = 0;
        return 0;
    }
    let add = 0, mult = 1;
    const effects = _resetGainEffectsIndex[resetNode.targetCurrency];
    if (effects) {
        for (const eff of effects) {
            const lvl = getLevel(eff.nodeId);
            if (lvl <= 0) continue;
            if (eff.type === 'reset_gain_add') add += eff.formula(lvl, getLevel, getCurr);
            if (eff.type === 'reset_gain_mult') mult *= eff.formula(lvl, getLevel, getCurr);
        }
    }
    const result = (base + add) * mult;
    cache.resetGain.set(resetNode.id, result);
    _resetGainCache[resetNode.id] = result;
    _resetGainFrame[resetNode.id] = cacheDirtyFrame;
    return result;
}
function getResetGain(currency) {
    const node = TREE_NODES.find(n => n.type === 'reset' && n.targetCurrency === currency);
    return node ? getEffectiveResetGain(node) : 0;
}

// ==================== CURRENCY DISCOVERY ====================
function addCurrencyToOrder(currKey) {
    if (!gameState.currencyOrder) gameState.currencyOrder = [];
    if (!gameState.discoveredCurrencies.includes(currKey)) gameState.discoveredCurrencies.push(currKey);
    if (gameState.hiddenCurrencies && gameState.hiddenCurrencies.includes(currKey)) {
        if (!gameState.userHiddenCurrencies || !gameState.userHiddenCurrencies.includes(currKey)) {
            gameState.hiddenCurrencies = gameState.hiddenCurrencies.filter(k => k !== currKey);
        }
    }
    const isNew = !gameState.currencyOrder.includes(currKey);
    if (isNew) {
        gameState.currencyOrder.push(currKey);
        EVENTS.emit('currency', currKey);
    } else if (gameState.currencyOrder.indexOf(currKey) > gameState.currencyOrder.lastIndexOf(currKey)) {
        const idx = gameState.currencyOrder.lastIndexOf(currKey);
        if (idx !== gameState.currencyOrder.indexOf(currKey)) gameState.currencyOrder.splice(idx, 1);
    }
}
function ensureCurrency(key) {
    if (gameState.currencies[key] === undefined) gameState.currencies[key] = 0;
    if (!gameState.discoveredCurrencies.includes(key)) {
        gameState.discoveredCurrencies.push(key);
        addCurrencyToOrder(key);
    } else if (gameState.currencyOrder && !gameState.currencyOrder.includes(key)) {
        gameState.currencyOrder.push(key);
    }
}

// ==================== BUY (copied; the sound and animation calls became an event) ====================
function buyUpgrade(nodeId, isAutomated = false, isFree = false) {
    try {
        const node = NODE_MAP.get(nodeId);
        if (!node || node.type !== 'upgrade' || !isNodeUnlocked(node)) return false;
        const currentLvl = getLevel(node.id);
        const max = getMaxLevel(node);
        if (currentLvl >= max) return false;
        const currency = gameState.currencies[node.costCurrency] || 0;
        let bought = 0, totalCost = 0;
        if (node.bulkFinalCost) {
            let target = currentLvl;
            const desiredMax = isAutomated || buyMode === 'MAX' ? max : Math.min(max, currentLvl + buyMode);
            let lo = currentLvl + 1, hi = desiredMax;
            let iterations = 0;
            while (lo <= hi && iterations < 1200) {
                const mid = Math.floor((lo + hi) / 2);
                const cost = node.costFormula(mid, getLevel, getCurr);
                if (typeof cost === 'number' && !isNaN(cost) && cost <= currency) { target = mid; lo = mid + 1; } else { hi = mid - 1; }
                iterations++;
            }
            if (target > currentLvl) { bought = target - currentLvl; totalCost = node.costFormula(target, getLevel, getCurr); }
        } else {
            const levelsToBuy = isAutomated || buyMode === 'MAX' ? (max - currentLvl) : Math.min(buyMode, max - currentLvl);
            for (let i = 0; i < levelsToBuy; i++) {
                const cost = node.costFormula(currentLvl + i, getLevel, getCurr);
                if (currency >= totalCost + cost) { totalCost += cost; bought++; } else break;
            }
        }
        if (bought > 0) {
            if (!isFree) gameState.currencies[node.costCurrency] -= totalCost;
            const oldLevel = currentLvl, newLevel = currentLvl + bought;
            gameState.levels[node.id] = newLevel;
            if (!gameState.discoveredCurrencies.includes(node.costCurrency)) {
                gameState.discoveredCurrencies.push(node.costCurrency);
                addCurrencyToOrder(node.costCurrency);
            }
            if (node.effects) {
                node.effects.forEach(eff => { const ckey = eff.currency || eff.targetCurrency; if (ckey) ensureCurrency(ckey); });
            }
            needsNodeUpdate = true;
            clearCaches();
            EVENTS.emit('buy', { node, oldLevel, newLevel, bought, totalCost, isAutomated, isFree });
            return true;
        }
        return false;
    } catch (e) { console.warn('buyUpgrade error for', nodeId, e); return false; }
}

// ==================== AUTOMATION (same order and checks as the original) ====================
function checkAutomation() {
    try {
        if (gameState.paused) return;
        for (const a of AUTOMATION_INDEX) {
            if (getLevel(a.nodeId) <= 0) continue;
            for (const tid of a.targets) {
                const targetNode = NODE_MAP.get(tid);
                if (targetNode && isNodeUnlocked(targetNode)) {
                    const cost = getCost(targetNode);
                    if ((gameState.currencies[targetNode.costCurrency] || 0) >= cost) {
                        buyUpgrade(targetNode.id, true, true);
                    }
                }
            }
        }
    } catch (e) { console.warn('checkAutomation error:', e); }
}

// ==================== RESETS ====================
function getResettedCoordsList(node) {
    const list = node.resettedCoords || [];
    const result = [];
    for (const item of list) {
        if (typeof item === 'string') {
            if (NODE_MAP.has(item)) {
                const targetNode = NODE_MAP.get(item);
                result.push({ type: 'id', id: item, coords: targetNode.coords });
            } else {
                for (const [id, n] of NODE_MAP) { if (id.startsWith(item)) result.push({ type: 'id', id, coords: n.coords }); }
            }
        } else if (Array.isArray(item) && item.length === 2 && typeof item[0] === 'number' && typeof item[1] === 'number') {
            const targetNode = COORD_MAP.get(`${item[0]},${item[1]}`);
            if (targetNode) result.push({ type: 'coord', coords: item, id: targetNode.id });
            else result.push({ type: 'coord', coords: item, id: null });
        }
    }
    return result;
}
function resetNodeLevels(node) {
    const list = getResettedCoordsList(node);
    const resetIds = new Set();
    for (const entry of list) { if (entry.id) { resetIds.add(entry.id); gameState.levels[entry.id] = 0; } }
    if (node.resetCurrencies && Array.isArray(node.resetCurrencies)) { for (const curr of node.resetCurrencies) gameState.currencies[curr] = 0; }
    cacheDirty = true;
    return resetIds;
}
// The original saveGame() cleans the live state (NaN or non-number currencies and levels become 0)
// and skips everything when P itself is NaN. executeReset calls it before and after every reset,
// so that cleanup is part of the reset math and is kept here.
function sanitizeLiveState() {
    if (!gameState || typeof gameState !== 'object') return;
    if (!gameState.currencies || typeof gameState.currencies !== 'object') return;
    if (typeof gameState.currencies.P !== 'number' || isNaN(gameState.currencies.P)) return;
    for (const key of Object.keys(gameState.currencies)) {
        const v = gameState.currencies[key];
        if (typeof v !== 'number' || isNaN(v)) gameState.currencies[key] = 0;
    }
    if (gameState.levels) {
        for (const key of Object.keys(gameState.levels)) {
            const v = gameState.levels[key];
            if (typeof v !== 'number' || isNaN(v)) gameState.levels[key] = 0;
        }
    } else gameState.levels = {};
}
function executeReset(node) {
    let ok = false;
    try {
        if (!node) return false;
        const gain = getEffectiveResetGain(node);
        if (gain <= 0) { EVENTS.emit('resetFail', node); return false; }
        sanitizeLiveState();
        gameState.currencies[node.targetCurrency] = (gameState.currencies[node.targetCurrency] || 0) + gain;
        if (!gameState.discoveredCurrencies.includes(node.targetCurrency)) {
            gameState.discoveredCurrencies.push(node.targetCurrency);
            addCurrencyToOrder(node.targetCurrency);
        } else if (gameState.hiddenCurrencies && gameState.hiddenCurrencies.includes(node.targetCurrency)
            && (!gameState.userHiddenCurrencies || !gameState.userHiddenCurrencies.includes(node.targetCurrency))) {
            gameState.hiddenCurrencies = gameState.hiddenCurrencies.filter(k => k !== node.targetCurrency);
        }
        const resetIds = resetNodeLevels(node);
        needsNodeUpdate = true;
        clearCaches(true);
        EVENTS.emit('reset', { node, gain, resetIds });
        ok = true;
    } catch (e) { console.warn('executeReset error:', e); }
    sanitizeLiveState();
    return ok;
}

// ==================== TICK (copied; UI refresh calls removed) ====================
function tickGame(dtMs, nowMs) {
    try {
        const dt = dtMs / 1000;
        if (gameState.paused) return;
        clearTickCaches();
        // Kept from the original: it fixes the order formulas are first evaluated in each tick,
        // which matters for the currencies that roll Math.random.
        for (const key of gameState.discoveredCurrencies) {
            if (calculateGainRate(key) < 0) break;
        }
        const discoveredSet = new Set(gameState.discoveredCurrencies);
        for (const key of Object.keys(CURRENCIES)) {
            const rate = calculateGainRate(key);
            if (rate !== 0) {
                if (!discoveredSet.has(key)) {
                    gameState.discoveredCurrencies.push(key);
                    addCurrencyToOrder(key);
                    discoveredSet.add(key);
                    needsNodeUpdate = true;
                }
                if (gameState.currencies[key] === undefined) gameState.currencies[key] = 0;
            }
        }
        for (const key of gameState.discoveredCurrencies) {
            const rate = calculateGainRate(key);
            if (rate !== 0) {
                const old = gameState.currencies[key] || 0;
                gameState.currencies[key] = old + rate * dt;
            }
        }
        for (const key of gameState.discoveredCurrencies || []) {
            const rate = calculateGainRate(key);
            if (rate > 0 && gameState.hiddenCurrencies && gameState.hiddenCurrencies.includes(key)) {
                if (!gameState.userHiddenCurrencies || !gameState.userHiddenCurrencies.includes(key)) {
                    gameState.hiddenCurrencies = gameState.hiddenCurrencies.filter(k => k !== key);
                }
            }
        }
        const now = nowMs === undefined ? performance.now() : nowMs;
        if (now - lastAutomationTime >= STUD_CONFIG.AUTOMATION_INTERVAL_MS) {
            lastAutomationTime = now;
            checkAutomation();
        }
    } catch (e) { console.warn('tick error:', e); }
}

// ==================== OFFLINE ====================
function offlineEffectiveSeconds(offlineSeconds) {
    if (STUD_CONFIG.OFFLINE_MODE === 'original') {
        if (offlineSeconds < 120) return offlineSeconds;
        return Math.floor(110 + Math.sqrt(100 + 20 * (offlineSeconds - 100)));
    }
    return Math.min(offlineSeconds, STUD_CONFIG.OFFLINE_CAP_SECONDS);
}
// Same payout rule as the original (rate x effective seconds, skipping the random or
// self-limiting currencies), only the effective time changed.
function processOfflineProgress(nowMs) {
    const lastTime = gameState.offlineTimestamp;
    if (!lastTime) return null;
    const elapsedMs = (nowMs || Date.now()) - lastTime;
    if (elapsedMs < 1000) return null;
    const offlineSeconds = Math.floor(elapsedMs / 1000);
    const dt = offlineEffectiveSeconds(offlineSeconds);
    if (dt <= 0) return null;
    cacheDirty = true;
    const gains = {};
    for (const key of Object.keys(CURRENCIES)) {
        if (OFFLINE_EXCLUDED_CURRENCIES.has(key)) continue;
        const rate = calculateGainRate(key);
        if (rate > 0 && (gameState.currencies[key] || 0) > 0) {
            const earned = rate * dt;
            if (earned > 0.01 || (key === 'P' && earned > 0)) {
                gains[key] = earned;
                gameState.currencies[key] = (gameState.currencies[key] || 0) + earned;
                if (!gameState.discoveredCurrencies.includes(key)) { gameState.discoveredCurrencies.push(key); addCurrencyToOrder(key); }
            }
        }
    }
    if (Object.keys(gains).length === 0) return null;
    clearCaches(true);
    return { offlineSeconds, paidSeconds: dt, gains };
}

// ==================== SAVE / LOAD ====================
function sanitizeState(s) {
    const g = freshGameState();
    if (!s || typeof s !== 'object') return g;
    for (const key of Object.keys(s)) { if (key === '__version') continue; if (s[key] !== undefined && s[key] !== null) g[key] = s[key]; }
    if (!g.currencies || typeof g.currencies !== 'object') g.currencies = { P: 0 };
    for (const k of Object.keys(g.currencies)) { const v = g.currencies[k]; if (typeof v !== 'number' || isNaN(v)) g.currencies[k] = 0; }
    if (!g.levels || typeof g.levels !== 'object') g.levels = {};
    for (const k of Object.keys(g.levels)) { const v = g.levels[k]; if (typeof v !== 'number' || isNaN(v) || v < 0) g.levels[k] = 0; }
    for (const arr of ['hiddenCurrencies', 'userHiddenCurrencies', 'unlockedDecorations']) if (!Array.isArray(g[arr])) g[arr] = [];
    if (!Array.isArray(g.currencyOrder)) g.currencyOrder = ['P'];
    if (!Array.isArray(g.discoveredCurrencies)) g.discoveredCurrencies = ['P'];
    for (const k of Object.keys(g.currencies)) {
        if ((g.currencies[k] || 0) > 0 && !g.currencyOrder.includes(k)) { g.currencyOrder.push(k); if (!g.discoveredCurrencies.includes(k)) g.discoveredCurrencies.push(k); }
    }
    if (!g.skipResetConfirm || typeof g.skipResetConfirm !== 'object') g.skipResetConfirm = {};
    return g;
}
function serializeState() {
    gameState.offlineTimestamp = Date.now();
    gameState.buyMode = buyMode;
    return JSON.stringify(gameState);
}
function saveGame() {
    try {
        sanitizeLiveState();
        const raw = serializeState();
        const prev = localStorage.getItem(STUD_CONFIG.SAVE_KEY);
        if (prev) localStorage.setItem(STUD_CONFIG.SAVE_BACKUP_KEY, prev);
        localStorage.setItem(STUD_CONFIG.SAVE_KEY, raw);
        return true;
    } catch (e) { return false; }
}
function loadState(obj) {
    gameState = sanitizeState(obj);
    buyMode = buyModes.includes(gameState.buyMode) ? gameState.buyMode : 1;
    clearCaches(true);
    needsNodeUpdate = true;
}
function loadGame() {
    let raw = null;
    try { raw = localStorage.getItem(STUD_CONFIG.SAVE_KEY); } catch (e) { }
    let parsed = null;
    if (raw) { try { parsed = JSON.parse(raw); } catch (e) { parsed = null; } }
    if (!parsed) {
        try { const b = localStorage.getItem(STUD_CONFIG.SAVE_BACKUP_KEY); if (b) parsed = JSON.parse(b); } catch (e) { parsed = null; }
    }
    if (parsed) loadState(parsed);
    return !!parsed;
}
function wipeGame() {
    gameState = freshGameState();
    buyMode = 1;
    clearCaches(true);
    needsNodeUpdate = true;
    try { localStorage.removeItem(STUD_CONFIG.SAVE_KEY); } catch (e) { }
}

// ==================== HELPERS FOR THE NEW UI (read only) ====================
function nodeIsMaxed(node) { return node.type === 'upgrade' && getLevel(node.id) >= getMaxLevel(node); }
function canAfford(node) {
    if (node.type !== 'upgrade' || !isNodeUnlocked(node) || nodeIsMaxed(node)) return false;
    const c = getDisplayCost(node);
    return typeof c === 'number' && c <= (gameState.currencies[node.costCurrency] || 0);
}
