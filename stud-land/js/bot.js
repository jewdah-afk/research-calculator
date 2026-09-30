// Greedy autoplayer. It only uses the public game actions (buyUpgrade, executeReset), so anything
// it reaches a real player can reach too. It powers SIM TO NEXT PLOT in the dev bar and
// tools/balance.js. Rules:
//   buy:   every decision (1 s of play), buy MAX of every affordable upgrade, cheapest share of
//          wallet first.
//   reset: reset currencies stack (you keep what you had and add the gain), so the bot resets when
//          a run has lasted at least 5 minutes and its gain per second has peaked and fallen 15
//          percent, or right away when the gain at least doubles what you hold. Shorter runs were
//          measured to be far worse (tools/balance.js). When several are ready it takes the one
//          that wipes the most (the highest layer). Time Warp is skipped: it trades Blueprints
//          back into Studs, which a greedy rule would abuse.
const BOT = (() => {
    const SKIP = new Set(['warping']);
    const UPG = TREE_NODES.filter(n => n.type === 'upgrade');
    const RES = TREE_NODES.filter(n => n.type === 'reset' && !SKIP.has(n.id)).map(n => ({ n, size: getResettedCoordsList(n).length + (n.resetCurrencies || []).length * 3 }));
    const s = { gameMs: 0, lastBuyMs: 0, lastDecisionMs: 0, buys: 0, resets: 0, stallMs: 60000, decisionMs: 1000, minCycle: 300, drop: 0.85, peakOnly: null, doubleAt: 1 };
    const track = new Map(); // reset id -> { since, peak }

    function buyPass() {
        const prev = buyMode; buyMode = 'MAX';
        const cands = [];
        for (const n of UPG) {
            if (!isNodeUnlocked(n)) continue;
            const lvl = getLevel(n.id);
            if (lvl >= getMaxLevel(n)) continue;
            const cost = getCost(n);
            const have = gameState.currencies[n.costCurrency] || 0;
            if (!(cost <= have)) continue;
            cands.push([n, have > 0 ? cost / have : 0]);
        }
        cands.sort((a, b) => a[1] - b[1]);
        let n = 0;
        for (const [node] of cands) if (buyUpgrade(node.id)) n++;
        buyMode = prev;
        return n;
    }
    function resetPass(stalled) {
        let best = null;
        for (const r of RES) {
            const node = r.n;
            if (!isNodeUnlocked(node)) { track.delete(node.id); continue; }
            let t = track.get(node.id);
            if (!t) { t = { since: s.gameMs, peak: 0 }; track.set(node.id, t); }
            const g = getEffectiveResetGain(node);
            if (!(g > 0) || !isFinite(g)) continue;
            const el = Math.max(1, (s.gameMs - t.since) / 1000);
            const rate = g / el;
            if (rate > t.peak) t.peak = rate;
            const have = getCurr(node.targetCurrency);
            const ratio = have > 0 ? g / have : Infinity;
            const usePeak = !s.peakOnly || s.peakOnly.has(node.id);
            const peaked = usePeak && el > s.minCycle && rate < t.peak * s.drop;
            if (ratio >= (usePeak ? 2 : s.doubleAt) || peaked || (stalled && ratio >= 0.1)) {
                if (!best || r.size > best.size || (r.size === best.size && ratio > best.ratio)) best = { ...r, ratio };
            }
        }
        if (best && executeReset(best.n)) {
            s.resets++;
            // everything this reset touched starts a fresh measurement
            for (const r of RES) {
                if (r.n === best.n || getEffectiveResetGain(r.n) <= 0) track.set(r.n.id, { since: s.gameMs, peak: 0 });
            }
            return best.n;
        }
        return null;
    }
    // Advance the game by `ms` of play time, deciding once per decisionMs. Returns true if stopFn fired.
    function run(ms, stopFn) {
        const end = s.gameMs + ms;
        const step = STUD_CONFIG.GAME_TICK_MS;
        while (s.gameMs < end) {
            s.gameMs += step;
            tickGame(step, s.gameMs);
            if (s.gameMs - s.lastDecisionMs >= s.decisionMs) {
                s.lastDecisionMs = s.gameMs;
                const b = buyPass();
                if (b) { s.buys += b; s.lastBuyMs = s.gameMs; }
                const stalled = s.gameMs - s.lastBuyMs > s.stallMs;
                if (resetPass(stalled)) s.lastBuyMs = s.gameMs;
                if (stopFn && stopFn()) return true;
            }
        }
        return false;
    }
    // Plain ticking on the same clock, for when the bot is off.
    function tick(ms) { const end = s.gameMs + ms; while (s.gameMs < end) { s.gameMs += STUD_CONFIG.GAME_TICK_MS; tickGame(STUD_CONFIG.GAME_TICK_MS, s.gameMs); } }
    function clear() { track.clear(); s.lastBuyMs = s.gameMs; s.lastDecisionMs = s.gameMs; }
    return { run, tick, clear, state: s, buyPass, resetPass };
})();
