// Display layer only: number formatting, Stud City names and colors for currencies.
// Internal ids stay the Upgrade Land ones (P, R, €, α ...) so saves and the Lua port line up.
const SUFFIXES = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', 'UDc', 'DDc', 'TDc', 'QaDc', 'QiDc', 'SxDc', 'SpDc', 'OcDc', 'NoDc', 'Vg'];
function formatNum(x) {
    if (typeof x !== 'number' || isNaN(x)) return '0';
    if (!isFinite(x)) return x > 0 ? '∞' : '-∞';
    const neg = x < 0; if (neg) x = -x;
    let out;
    if (x < 1000) {
        out = x >= 100 ? x.toFixed(0) : x >= 10 ? trim(x.toFixed(1)) : trim(x.toFixed(2));
    } else {
        const e = Math.floor(Math.log10(x) / 3);
        if (e < SUFFIXES.length) {
            const v = x / Math.pow(1000, e);
            out = (v >= 100 ? v.toFixed(0) : v >= 10 ? trim(v.toFixed(1)) : trim(v.toFixed(2))) + SUFFIXES[e];
        } else {
            const ex = Math.floor(Math.log10(x));
            out = trim((x / Math.pow(10, ex)).toFixed(2)) + 'e' + ex;
        }
    }
    return (neg ? '-' : '') + out;
}
function trim(s) { return s.indexOf('.') >= 0 ? s.replace(/\.?0+$/, '') : s; }
function formatTime(ms) {
    const s = Math.max(0, Math.round(ms / 1000));
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
    if (d) return `${d}d ${h}h`;
    if (h) return `${h}h ${String(m).padStart(2, '0')}m`;
    if (m) return `${m}m ${String(ss).padStart(2, '0')}s`;
    return `${ss}s`;
}
function formatClock(sec) { sec = Math.round(sec); return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`; }

// Stud City names. Anything not listed keeps its Upgrade Land name.
const STUD_NAMES = {
    P: 'Studs', R: 'Blueprints', '€': 'Golden Bricks', A: 'Sky Bricks', E: 'Charge',
    'α': 'Alpha Bricks', 'β': 'Beta Bricks', '¤': 'Sticker Power', '∞': 'Loops', '♦': 'Loop Shards',
    S: 'Progress Score', TM: 'Tree Mass', '+': 'Plus Bricks', '×': 'Times Bricks', XP: 'XP', L: 'Levels',
    C: 'Cash', $: 'Money', IP: 'Loop Points', DE: 'Portal Essence', plates: 'Plates',
    D1: 'Portal I', D2: 'Portal II', D3: 'Portal III', D4: 'Portal IV', D5: 'Portal V', D6: 'Portal VI', D7: 'Portal VII', D8: 'Portal VIII',
};
const CURRENCY_HEX = {
    P: '#ffd23f', R: '#4aa8ff', '€': '#ffb300', A: '#ff6b6b', E: '#ff9a2e', 'α': '#39d98a', 'β': '#ff7aa2',
    D1: '#ffd6d6', D2: '#ffb3b3', D3: '#ff8f8f', D4: '#f87171', D5: '#ef4444', D6: '#dc2626', D7: '#b91c1c', D8: '#991b1b',
    grass: '#34c759', dirt: '#b45309', stone: '#94a3b8', copper: '#ea580c', silver: '#d1d5db', gold: '#facc15', lapis: '#2563eb',
    diamonds: '#22d3ee', netherite: '#5a5256', fragment: '#f5f5f5', IP: '#fcd221', essence: '#d8b4fe', DE: '#6b7bff', plates: '#93c5fd',
    S: '#ffa500', TM: '#a0522d', '+': '#3b9dff', '×': '#ff5a5a', XP: '#b0b8c4', L: '#9aa3ad', Cookie: '#bb8855', tokens: '#ce8946',
    chips: '#d9a066', $: '#86efac', customers: '#a3a3a3', fame: '#ffd580', stars: '#fff3a0', water: '#74ccf4', sunlight: '#ffee50',
    sunpower: '#fcffb5', C: '#9acd32', QT: '#06b6d4', T: '#a855f7', '¤': '#b36bff', '∞': '#ff9df2', '♦': '#b36bff',
    black: '#2b2b2b', red: '#ef4444', crimson: '#dc143c', firebrick: '#b22222', maroon: '#800000', burgundy: '#4a0404',
    yellow: '#ffeb3b', blue: '#3b82f6', orange: '#ffa500', green: '#22c55e', purple: '#a855f7', white: '#f4f4f5',
};
let SHOW_UL_NAMES = false;
function curName(k) {
    const ul = (CURRENCIES[k] && CURRENCIES[k].name) || k;
    const stud = STUD_NAMES[k] || ul;
    return SHOW_UL_NAMES ? ul : stud;
}
function curULName(k) { return (CURRENCIES[k] && CURRENCIES[k].name) || k; }
function curHex(k) { return CURRENCY_HEX[k] || '#cfcfcf'; }
function curGlyph(k) {
    const map = { P: '', '€': '€', '¤': '¤', '∞': '∞', '♦': '♦', 'α': 'α', 'β': 'β', '+': '+', '×': '×', $: '$' };
    if (map[k] !== undefined) return map[k];
    if (k.length <= 2) return k;
    return k[0].toUpperCase();
}
function shade(hex, amt) {
    let c = hex.replace('#', '');
    if (c.length === 3) c = c.split('').map(x => x + x).join('');
    const n = parseInt(c, 16);
    let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    if (amt >= 0) { r += (255 - r) * amt; g += (255 - g) * amt; b += (255 - b) * amt; }
    else { r *= 1 + amt; g *= 1 + amt; b *= 1 + amt; }
    return `rgb(${r | 0},${g | 0},${b | 0})`;
}
function hexA(hex, a) {
    let c = hex.replace('#', '');
    if (c.length === 3) c = c.split('').map(x => x + x).join('');
    const n = parseInt(c, 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}
// Small stud coin icon as a data URL, cached per currency (used by the DOM HUD).
const _iconCache = {};
function curIcon(k, size = 64) {
    const key = k + size;
    if (_iconCache[key]) return _iconCache[key];
    const c = document.createElement('canvas'); c.width = c.height = size;
    const g = c.getContext('2d'); const col = curHex(k);
    const r = size * 0.42, cx = size / 2, cy = size / 2;
    g.fillStyle = '#1b1530'; g.beginPath(); g.arc(cx, cy + size * 0.05, r + size * 0.05, 0, 7); g.fill();
    g.fillStyle = shade(col, -0.35); g.beginPath(); g.arc(cx, cy + size * 0.04, r, 0, 7); g.fill();
    g.fillStyle = col; g.beginPath(); g.arc(cx, cy - size * 0.02, r * 0.93, 0, 7); g.fill();
    g.fillStyle = shade(col, 0.45); g.beginPath(); g.ellipse(cx - r * 0.3, cy - r * 0.38, r * 0.34, r * 0.2, -0.6, 0, 7); g.fill();
    const glyph = curGlyph(k);
    if (glyph) {
        g.font = `${Math.round(size * (glyph.length > 1 ? 0.34 : 0.46))}px "Luckiest Guy", "Fredoka", sans-serif`;
        g.textAlign = 'center'; g.textBaseline = 'middle';
        g.lineWidth = size * 0.08; g.strokeStyle = '#1b1530'; g.strokeText(glyph, cx, cy + size * 0.02);
        g.fillStyle = '#fff'; g.fillText(glyph, cx, cy + size * 0.02);
    } else {
        g.fillStyle = shade(col, -0.15); g.beginPath(); g.arc(cx, cy - size * 0.02, r * 0.5, 0, 7); g.fill();
        g.fillStyle = shade(col, 0.25); g.beginPath(); g.arc(cx, cy - size * 0.05, r * 0.42, 0, 7); g.fill();
    }
    return (_iconCache[key] = c.toDataURL());
}
function resetIconCache() { for (const k in _iconCache) delete _iconCache[k]; }
