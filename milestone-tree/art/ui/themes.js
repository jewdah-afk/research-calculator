// Per-layer theme parameters over the master "cosmic ornate" style (shared by the painters, the samples and,
// later, the client: every value here maps to a Theme.luau field). A layer = a hue + its crystal + its body tint +
// a motif switch; the metal (gold) is shared, the CR layer swaps in tarnish, cracks and the glitch treatment.
const UI_THEMES = {
  m: {
    key: 'm', name: 'MILESTONE', sym: 'M', hue: '#b35cff', hueHi: '#e6c2ff', hueDeep: '#35105c',
    body: ['#1b1128', '#0f0a18', '#0a0712'], wash: '#b35cff', text: '#f5ecff', soft: '#d9c8ee', motif: 'amethyst',
  },
  p: {
    key: 'p', name: 'PRESTIGE', sym: 'P', hue: '#6fc3ff', hueHi: '#d2eeff', hueDeep: '#0c3558',
    body: ['#0f1a2a', '#0a111d', '#070b14'], wash: '#6fc3ff', text: '#eef7ff', soft: '#c3d6ea', motif: 'ice',
  },
  cp: {
    key: 'cp', name: 'CORRUPTED PRESTIGE', sym: 'CR', hue: '#39ff14', hueHi: '#c9ffb5', hueDeep: '#0c4a05',
    body: ['#0b170d', '#070f08', '#040905'], wash: '#39ff14', text: '#eaffe4', soft: '#b9dcb0', motif: 'corrupt',
    glitch: { alt: '#ff2e63', cyan: '#2ef2ff' },
  },
};
// the shared metal + state colours (DESIGN.md palette)
const UI_GOLD = { hi: '#fff6d2', light: '#ffe08a', mid: '#f2c35a', low: '#b07a28', deep: '#5a3a12', ink: '#2a1a06' };
const UI_STATE = { owned: '#4be07a', locked: '#8a6f7a', danger: '#ff3b5c', ready: '#ffd34d', info: '#7a8cff' };
if (typeof module !== 'undefined') module.exports = { UI_THEMES, UI_GOLD, UI_STATE };
