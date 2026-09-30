// Stud City Incremental plots. Upgrade Land lays its tree out on 5 x 5 baseplates (one unit = 160 px in the
// original canvas). Every baseplate becomes one Stud City Incremental plot. This file only reads the data:
// which nodes sit on which plot, what the plot is called, and when it counts as built.
const PLOT_SIZE = 5;

// Display info per plot, keyed by grid cell "gx,gy" where gx = floor((x + 2.5) / 5).
// name: Stud City Incremental name, ul: the Upgrade Land baseplate it comes from, theme: world look.
const PLOT_INFO = {
    '0,0':   { name: 'Stud Square',        ul: 'Point baseplate',            theme: 'meadow',   color: '#3fbf5f' },
    '-1,0':  { name: 'Stud Square East',   ul: 'Point baseplate: extension', theme: 'meadow',   color: '#58c96f' },
    '0,1':   { name: 'Blueprint Lab',      ul: 'Research baseplate',         theme: 'lab',      color: '#4a9ee8' },
    '1,0':   { name: 'Robo Works',         ul: 'Automation baseplate',       theme: 'factory',  color: '#f28fa6' },
    '-1,1':  { name: 'Battery Farm',       ul: 'Energy baseplate',           theme: 'energy',   color: '#ff9a2e' },
    '1,1':   { name: 'Sticker Studio',     ul: 'Decoration baseplate',       theme: 'studio',   color: '#a56ae0' },
    '0,2':   { name: 'Golden Brick Hall',  ul: 'Prestige baseplate',         theme: 'gold',     color: '#f2c53d' },
    '-1,2':  { name: 'Level Up Gym',       ul: 'Experience baseplate',       theme: 'gym',      color: '#b9c2cc' },
    '1,2':   { name: 'Math Mill',          ul: 'Operation baseplate',        theme: 'mill',     color: '#3fd1c6' },
    '2,0':   { name: 'Robo Works Plus',    ul: 'Automation+ baseplate',      theme: 'factory',  color: '#b0305f' },
    '0,3':   { name: 'Sky Tower',          ul: 'Ascension baseplate',        theme: 'sky',      color: '#ff7f7f' },
    '1,3':   { name: 'Robo Works Max',     ul: 'Automation++ baseplate',     theme: 'factory',  color: '#8a1c1c' },
    '-1,3':  { name: 'Progress Path',      ul: 'Progression baseplate',      theme: 'path',     color: '#ffa500' },
    '2,1':   { name: 'Brick Grove',        ul: 'Tree baseplate',             theme: 'grove',    color: '#9a6232' },
    '2,2':   { name: 'Brick Grove Falls',  ul: 'Tree+ baseplate',            theme: 'grove',    color: '#7a4a24' },
    '2,3':   { name: 'Sunflower Ridge',    ul: 'Tree++ baseplate',           theme: 'sun',      color: '#e0a526' },
    '0,4':   { name: 'Portal Park',        ul: 'Dimension baseplate',        theme: 'portal',   color: '#a3202a' },
    '1,4':   { name: 'Portal Park II',     ul: 'Dimension baseplate II',     theme: 'portal',   color: '#8b0000' },
    '-1,4':  { name: 'Portal Park III',    ul: 'Dimension baseplate III',    theme: 'portal',   color: '#6e0010' },
    '2,4':   { name: 'Plate Yard',         ul: 'plate plate',                theme: 'yard',     color: '#3060c0' },
    '3,4':   { name: 'Grass Mine',         ul: 'Mining plate',               theme: 'mine',     color: '#6cc24a' },
    '3,3':   { name: 'Ore Mine',           ul: 'Mining plate II',            theme: 'mine',     color: '#9aa3ab' },
    '3,2':   { name: 'Gem Mine',           ul: 'Mining plate III',           theme: 'gem',      color: '#5c6b8a' },
    '3,1':   { name: 'Deep Mine',          ul: 'Mining plate IV',            theme: 'deep',     color: '#3a3040' },
    '3,0':   { name: 'The Finale',         ul: 'Finale I',                   theme: 'finale',   color: '#f4f4f4' },
    '5,0':   { name: 'World Two Gate',     ul: 'Uni II start',               theme: 'cosmos',   color: '#8d8d9a' },
    '6,1':   { name: 'Brick Mart',         ul: 'Business',                   theme: 'market',   color: '#43b36b' },
    '5,1':   { name: 'Brick Mart II',      ul: 'Business II',                theme: 'market',   color: '#35a05c' },
    '6,0':   { name: 'Brick Mart III',     ul: 'Business III',               theme: 'market',   color: '#2d8a4f' },
    '7,0':   { name: 'Forever Forge',      ul: 'Infinity',                   theme: 'forge',    color: '#fcd221' },
    '7,1':   { name: 'Night Bricks',       ul: 'Black',                      theme: 'night',    color: '#343434' },
    '7,2':   { name: 'Red Brick Canyon',   ul: 'Red (latest update)',        theme: 'canyon',   color: '#e0413a' },
    '0,-1':  { name: 'Alpha Bonus Bay',    ul: 'Bonus baseplate',            theme: 'bay',      color: '#7fe07f' },
    '-1,-1': { name: 'Cash Corner',        ul: 'Cash baseplate',             theme: 'cash',     color: '#1f7a3f' },
    '1,-1':  { name: 'Loop Lagoon',        ul: 'Infinity baseplate',         theme: 'lagoon',   color: '#d1d0d0' },
    '0,-2':  { name: 'Beta Beach',         ul: 'Beta baseplate',             theme: 'beach',    color: '#ffb6c9' },
    '-1,-2': { name: 'Cookie Cove',        ul: 'Cookie baseplate',           theme: 'cookie',   color: '#bb8855' },
    '1,-2':  { name: 'Token Tent',         ul: 'Token baseplate',            theme: 'tent',     color: '#ce8946' },
    '1,-3':  { name: 'Clip Cliff',         ul: 'Clip baseplate',             theme: 'tent',     color: '#b87333' },
    // Announced in the latest update, not playable yet.
    '8,1':   { name: 'Yellow Plate',       ul: 'Yellow (coming soon)',       theme: 'soon',     color: '#ffe14d', soon: true },
    '8,2':   { name: 'Blue Plate',         ul: 'Blue (coming soon)',         theme: 'soon',     color: '#6ab8ff', soon: true },
};

function plotKeyOf(x, y) { return Math.floor((x + 2.5) / 5) + ',' + Math.floor((y + 2.5) / 5); }

// Build plot records: nodes, the decoration rect that "builds" the plot, and its grid rect.
const PLOTS = (() => {
    const map = new Map();
    const get = (key) => {
        if (!map.has(key)) {
            const [gx, gy] = key.split(',').map(Number);
            const info = PLOT_INFO[key] || { name: 'Plot ' + key, ul: '', theme: 'meadow', color: '#888' };
            map.set(key, { key, gx, gy, x0: gx * 5 - 2.5, y0: gy * 5 - 2.5, ...info, nodes: [], upgrades: [], resets: [], buildReqs: null, deco: [] });
        }
        return map.get(key);
    };
    TREE_NODES.forEach(n => {
        const p = get(plotKeyOf(n.coords[0], n.coords[1]));
        p.nodes.push(n);
        if (n.type === 'upgrade') p.upgrades.push(n);
        if (n.type === 'reset') p.resets.push(n);
    });
    DECORATIONS.forEach((d, idx) => {
        if (d.type !== 'rect' || !(d.width >= 800 && d.height >= 800)) return;
        const key = plotKeyOf(d.coords[0] + 0.01, d.coords[1] + 0.01);
        const p = get(key);
        if (!p.buildReqs) { p.buildReqs = d.requirements || []; p.decoIndex = idx; p.fill = d.fillColor; }
    });
    for (const k of Object.keys(PLOT_INFO)) if (PLOT_INFO[k].soon) get(k);
    return map;
})();

// Requirement depth of every node (0 for roots). Used to order plots and to max them in order.
const NODE_DEPTH = (() => {
    const depth = new Map();
    const visiting = new Set();
    function d(n) {
        if (depth.has(n.id)) return depth.get(n.id);
        if (visiting.has(n.id)) return 0;
        visiting.add(n.id);
        let v = 0;
        for (const [x, y] of (n.reqs || [])) {
            const r = COORD_MAP.get(`${x},${y}`);
            if (r) v = Math.max(v, d(r) + 1);
        }
        visiting.delete(n.id);
        depth.set(n.id, v);
        return v;
    }
    TREE_NODES.forEach(d);
    return depth;
})();
PLOTS.forEach(p => {
    p.upgrades.sort((a, b) => NODE_DEPTH.get(a.id) - NODE_DEPTH.get(b.id));
    p.minDepth = p.nodes.length ? Math.min(...p.nodes.map(n => NODE_DEPTH.get(n.id))) : 1e9;
});

// Progression order, used by MAX NEXT PLOT and the PLOTS list. Plots missing here fall back to
// requirement depth.
const PLOT_ORDER_HINT = [
    // first fourteen in the order the bot builds them (js/benchmark.js)
    '0,0', '0,-1', '1,-1', '1,-2', '1,-3', '0,1', '-1,-1', '1,1', '0,-2', '-1,1', '0,2', '-1,2', '1,0', '-1,-2',
    // after that, by Upgrade Land requirement chains
    '-1,0', '1,2', '2,0', '0,3', '1,3', '-1,3',
    '2,1', '2,2', '2,3', '0,4', '1,4', '-1,4', '2,4', '3,4', '3,3', '3,2', '3,1', '3,0',
    '5,0', '5,1', '6,1', '6,0', '7,0', '7,1', '7,2', '8,1', '8,2',
];
const PLOT_ORDER = (() => {
    const known = PLOT_ORDER_HINT.filter(k => PLOTS.has(k));
    const rest = [...PLOTS.keys()].filter(k => !known.includes(k)).sort((a, b) => PLOTS.get(a).minDepth - PLOTS.get(b).minDepth);
    return [...known, ...rest].map(k => PLOTS.get(k));
})();

// A plot is built when its baseplate decoration would show in Upgrade Land. Eight baseplates there
// point at ids that do not exist (B12, +B13, P16 ...), so their backgrounds never appear; those
// plots count as built once any machine on them has a level.
function plotReqsValid(p) { return !!(p.buildReqs && p.buildReqs.length && p.buildReqs.every(id => NODE_MAP.has(id))); }
function plotIsBuilt(p) {
    if (p.soon) return false;
    if (p.key === '0,0') return true; // Stud Square is the home island, there from the start
    if (plotReqsValid(p)) {
        if (p.decoIndex !== undefined && gameState.unlockedDecorations.includes(p.decoIndex)) return true;
        return p.buildReqs.every(id => getLevel(id) >= 1);
    }
    return p.upgrades.some(n => getLevel(n.id) >= 1);
}
// Level cap used by MAX NEXT PLOT and the plot progress bars: the machine's own max level from the
// data. Some machines raise each other's max (Loop Lagoon, Cash Corner towers); following that
// chain to the end gives levels like 1e189, so the dev tools stop at the base max and the rest
// is bought in normal play.
function capLevel(n) { return Math.min(getMaxLevel(n), n.maxLevel || 1); }
// Decorations stay unlocked once seen (same rule as the original renderDecorationsUnlock).
function updateDecorationUnlocks() {
    let changed = false;
    DECORATIONS.forEach((deco, idx) => {
        const reqs = deco.requirements;
        const ok = !reqs || reqs.length === 0 || reqs.every(id => getLevel(id) >= 1);
        if (ok && !gameState.unlockedDecorations.includes(idx)) { gameState.unlockedDecorations.push(idx); changed = true; }
    });
    return changed;
}
function plotStats(p) {
    let lv = 0, max = 0, visible = 0, maxed = 0, affordable = 0;
    for (const n of p.upgrades) {
        const m = capLevel(n);
        const l = Math.min(getLevel(n.id), m);
        lv += l; max += m;
        if (isNodeUnlocked(n)) { visible++; if (l >= m) maxed++; if (canAfford(n)) affordable++; }
    }
    return { lv, max, visible, maxed, affordable, total: p.upgrades.length };
}
// Currencies a plot produces (its upgrades' gain effects), used for the plot sign.
function plotCurrencies(p) {
    if (p._curr) return p._curr;
    const out = [];
    for (const n of p.upgrades) for (const e of (n.effects || [])) {
        if ((e.type === 'base_gain' || e.type === 'base_gain_raw') && e.currency && !out.includes(e.currency)) out.push(e.currency);
    }
    for (const n of p.resets) if (!out.includes(n.targetCurrency)) out.push(n.targetCurrency);
    if (!out.length) for (const n of p.upgrades) if (n.costCurrency && !out.includes(n.costCurrency)) out.push(n.costCurrency);
    p._curr = out;
    return out;
}
