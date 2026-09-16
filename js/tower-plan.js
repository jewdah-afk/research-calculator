/**
 * tower-plan.js — the infinite coin-income plan.
 *
 * WHAT THIS MODELS
 * Coin income is modelled *relatively*: every factor below is a ratio against
 * your current levels, so the plan never needs an absolute coins/hr model (and
 * therefore never needs enemy-scaling data, which is the worst-sourced corner
 * of this game). You supply your measured coins/hr; the plan scales it.
 *
 *     income(state) = yourMeasuredCoinsPerHour x coinMult(state)
 *
 *     coinMult = ( killShare * K/K0 + waveShare * W/W0 ) * G/G0
 *
 *       K  per-kill coin scaling   (workshop Coins-Kill Bonus x its lab)
 *       W  per-wave coin scaling   (workshop Coins-Wave x its lab)
 *       G  global coin multipliers (Coin Bonus + enhancement, Golden Tower
 *          duty-cycled, Black Hole / Spotlight / Death Wave coin labs,
 *          Coins Mastery)
 *
 * Golden Tower is duty-cycled rather than taken at face value: it only pays
 * while it is up, so its contribution is 1 + (mult - 1) * min(1, duration/cooldown).
 *
 * WHAT IT DOES NOT MODEL, and why
 *   - Wave depth. Pushing deeper raises coins/hr, but converting stats into a
 *     reachable wave needs enemy scaling per tier/wave, which we do not have a
 *     trustworthy source for. So this plans income *multipliers*, not the
 *     "farm deeper" lever. Re-anchor coins/hr after a big push.
 *   - Cards, modules, bots, perks, guardians, vault. They are priced in
 *     data/tower-extras.js but spend gems/medals/stones/keys, not coins, so
 *     they do not compete for the same budget and are listed separately.
 *   - The Coins/Kill and Coins/Wave LABS. The GOD tables give their exact cost
 *     and time but not their effect size, and the wiki value set does not cover
 *     them. Their per-level effect is therefore an ASSUMPTION you can edit
 *     (default +2%/level, matching the Cash Bonus and Cash/Wave labs, which the
 *     wiki does publish). Anything assumed is flagged in the output.
 */
'use strict';

/* ── which tracks feed coin income ───────────────────────────────────── */
// kind: 'ws' workshop | 'enh' enhancement | 'lab' lab
// role: 'kill' | 'wave' | 'global' | 'discount'
var COIN_TRACKS = [
  { id: 'coins-kill-bonus',            kind: 'ws',  role: 'kill',   label: 'Coins - Kill Bonus' },
  { id: 'coins-wave',                  kind: 'ws',  role: 'wave',   label: 'Coins - Wave' },
  { id: 'utility/coin-bonus-plus',     kind: 'enh', role: 'global', label: 'Coin Bonus +' },
  { id: 'utility/coins-kill-bonus',    kind: 'lab', role: 'kill',   label: 'Coins / Kill Bonus (lab)', assumed: true },
  { id: 'utility/coins-wave',          kind: 'lab', role: 'wave',   label: 'Coins / Wave (lab)',       assumed: true },
  { id: 'ultimate-weapon/golden-tower-bonus',    kind: 'lab', role: 'gt',     label: 'Golden Tower Bonus' },
  { id: 'ultimate-weapon/golden-tower-duration', kind: 'lab', role: 'gtdur',  label: 'Golden Tower Duration' },
  { id: 'ultimate-weapon/black-hole-coin-bonus', kind: 'lab', role: 'global', label: 'Black Hole Coin Bonus' },
  { id: 'ultimate-weapon/spotlight-coin-bonus',  kind: 'lab', role: 'global', label: 'Spotlight Coin Bonus' },
  { id: 'ultimate-weapon/death-wave-coin-bonus', kind: 'lab', role: 'global', label: 'Death Wave Coins Bonus' },
  { id: 'card-mastery/coins-mastery',            kind: 'lab', role: 'global', label: 'Coins Mastery' }
];

// Cost-reduction tracks. They add no income, but make everything after them
// cheaper — which is why a naive gain-per-coin ranking gets them badly wrong.
var DISCOUNT_TRACKS = [
  { id: 'main/workshop-utility-discount',          kind: 'lab', applies: 'ws-utility',  perLevel: 0.005 },
  { id: 'main/workshop-attack-discount',           kind: 'lab', applies: 'ws-attack',   perLevel: 0.005 },
  { id: 'main/workshop-defense-discount',          kind: 'lab', applies: 'ws-defense',  perLevel: 0.005 },
  { id: 'main/enhancement-utility-coin-discount',  kind: 'lab', applies: 'enh-utility', perLevel: 0.005 },
  { id: 'main/labs-coin-discount',                 kind: 'lab', applies: 'lab',         perLevel: 0.003 }
];

// Wiki LAB_VALUES keys for the labs we read effect curves from.
var LAB_VALUE_KEY = {
  'ultimate-weapon/golden-tower-bonus': 'Golden Tower Bonus',
  'ultimate-weapon/golden-tower-duration': 'Golden Tower Duration',
  'ultimate-weapon/black-hole-coin-bonus': 'Black Hole Coin Bonus',
  'ultimate-weapon/spotlight-coin-bonus': 'Spotlight Coin Bonus',
  'ultimate-weapon/death-wave-coin-bonus': 'Death Wave Coins Bonus',
  'card-mastery/coins-mastery': 'Coins Mastery'
};

function trackTable(t) {
  if (t.kind === 'ws') return TOWER_DATA.workshop[t.id];
  if (t.kind === 'enh') return TOWER_EXTRAS.enhancements[t.id];
  return TOWER_DATA.labs[t.id];
}
function trackMax(t) { var tb = trackTable(t); return tb ? tb.max : 0; }

// Marginal coin cost to take a track from `lvl` to `lvl+1`, after discounts.
function stepCost(t, lvl, disc) {
  var tb = trackTable(t);
  if (!tb || lvl >= tb.max) return Infinity;
  var raw = tb.cost[lvl];
  if (!isFinite(raw)) return Infinity;
  if (t.kind === 'ws') return raw * (1 - (disc['ws-' + tb.c] || 0));
  if (t.kind === 'enh') return raw * (1 - (disc['enh-' + tb.c.split('/')[1]] || 0));
  return raw * (1 - (disc['lab'] || 0));
}
function stepTime(t, lvl, labSpeed) {
  if (t.kind !== 'lab') return 0;
  var tb = trackTable(t);
  if (!tb || lvl >= tb.max) return 0;
  return (tb.time[lvl] || 0) / labSpeed;
}

/* ── the coin multiplier ─────────────────────────────────────────────── */
// Effect value of a lab at a given level, from the wiki value curve.
function labEffect(id, lvl) {
  var key = LAB_VALUE_KEY[id];
  if (!key || lvl <= 0) return null;
  var e = TOWER_EXTRAS.labValues.labs[key];
  if (!e) return null;
  var v = e.v[Math.min(lvl, e.v.length) - 1];
  return (v === null || v === undefined) ? null : v;
}

/**
 * coinStreams(levels, opts) — the raw per-kill and per-wave scaling, and the
 * global multiplier, at a given level set.
 */
function coinStreams(L, opts) {
  var wsKill = TOWER_DATA.workshop['coins-kill-bonus'];
  var wsWave = TOWER_DATA.workshop['coins-wave'];
  var enhCoin = TOWER_EXTRAS.enhancements['utility/coin-bonus-plus'];

  var K = wsKill.val[Math.min(L['coins-kill-bonus'] || 0, wsKill.max)];
  var W = wsWave.val[Math.min(L['coins-wave'] || 0, wsWave.max)];

  // The two unsourced coin labs: an editable assumption, compounding per level.
  K *= Math.pow(1 + opts.labCoinPerLevel, L['utility/coins-kill-bonus'] || 0);
  W *= Math.pow(1 + opts.labCoinPerLevel, L['utility/coins-wave'] || 0);

  var G = enhCoin.val[Math.min(L['utility/coin-bonus-plus'] || 0, enhCoin.max)];

  // Golden Tower, duty-cycled. Base 5.0x at UW level 0; the lab adds 0.15/level.
  var gtBonus = labEffect('ultimate-weapon/golden-tower-bonus', L['ultimate-weapon/golden-tower-bonus'] || 0) || 0;
  var gtDur = opts.gtDuration + (labEffect('ultimate-weapon/golden-tower-duration', L['ultimate-weapon/golden-tower-duration'] || 0) || 0);
  var gtMult = opts.gtBase + gtBonus;
  var duty = opts.gtCooldown > 0 ? Math.min(1, gtDur / opts.gtCooldown) : 0;
  G *= 1 + (gtMult - 1) * duty;

  ['ultimate-weapon/black-hole-coin-bonus',
   'ultimate-weapon/spotlight-coin-bonus',
   'ultimate-weapon/death-wave-coin-bonus',
   'card-mastery/coins-mastery'].forEach(function (id) {
    var v = labEffect(id, L[id] || 0);
    if (v !== null && v > 0) G *= v;
  });

  return { K: K, W: W, G: G };
}

/**
 * coinMult(levels, opts, base) — coin income relative to the `base` level set,
 * which is where the player is now. Equals exactly 1 at base.
 *
 * Each stream is normalised by its own value at base before the kill/wave split
 * is applied. Without that normalisation the split silently re-weights itself
 * by the raw magnitudes of the two curves — Coins/Wave is a flat amount that
 * climbs to 150 while Coins-Kill is a x1..x2.49 multiplier, so the wave term
 * would swamp the kill term regardless of what the user actually typed.
 */
function coinMult(L, opts, base) {
  var a = coinStreams(L, opts), b = coinStreams(base, opts);
  var sk = opts.killShare, sw = 1 - sk;
  return (sk * (a.K / b.K) + sw * (a.W / b.W)) * (a.G / b.G);
}

function discountsAt(L) {
  var d = {};
  DISCOUNT_TRACKS.forEach(function (t) {
    var tb = TOWER_DATA.labs[t.id];
    if (!tb) return;
    var lvl = Math.min(L[t.id] || 0, tb.max);
    d[t.applies] = Math.min(0.95, (d[t.applies] || 0) + lvl * t.perLevel);
  });
  return d;
}

/* ── the planner ─────────────────────────────────────────────────────── */
/**
 * buildPlan(startLevels, opts) — greedy sequencing with a discount lookahead.
 *
 * Both kinds of candidate are scored in the SAME unit — coins saved per coin
 * spent across the next `horizon` purchases — because otherwise they are not
 * comparable and the plan degenerates:
 *
 *   income track    the next `horizon` purchases cost E coins. Raising income
 *                   by m1/m0 earns those coins faster, worth E * (1 - m0/m1).
 *   discount track  saves `perLevel` of the future spend it applies to.
 *
 * An earlier revision scored income as d(ln coinMult)/cost and discounts as
 * coins-saved/cost. Those are different units, the discounts won every time,
 * and the plan bought 38 levels of Workshop Utility Discount before anything
 * that actually earns. The shared horizon is what makes the two commensurable,
 * and the lookahead is still what stops the discounts being ignored entirely.
 */
function buildPlan(start, opts) {
  var L = {}, k;
  for (k in start) L[k] = start[k];
  var all = COIN_TRACKS.concat(DISCOUNT_TRACKS.map(function (t) {
    return { id: t.id, kind: t.kind, role: 'discount', label: (TOWER_DATA.labs[t.id] || {}).n || t.id, applies: t.applies, perLevel: t.perLevel };
  }));

  var base = {};
  for (k in L) base[k] = L[k];

  var steps = [], coins = 0, seconds = 0, labSeconds = 0;
  var disc = discountsAt(L);
  var m0 = 1; // coinMult is defined relative to base, so it starts at 1
  var income0 = opts.coinsPerHour / 3600;
  var guard = 0;

  while (steps.length < opts.maxSteps && guard++ < opts.maxSteps * 4) {
    var mNow = coinMult(L, opts, base);
    var best = null;

    for (var i = 0; i < all.length; i++) {
      var t = all[i], lvl = L[t.id] || 0;
      if (lvl >= trackMax(t)) continue;
      var cost = stepCost(t, lvl, disc);
      if (!isFinite(cost) || cost <= 0) continue;

      var score;
      if (t.role === 'discount') {
        var saved = projectedSpend(L, disc, opts, base, t.applies) * t.perLevel;
        score = saved / cost;
      } else {
        L[t.id] = lvl + 1;
        var mNext = coinMult(L, opts, base);
        L[t.id] = lvl;
        if (!(mNext > mNow)) continue;
        // Value of arriving at the same future spend faster.
        var future = projectedSpend(L, disc, opts, base, null);
        score = (future * (1 - mNow / mNext)) / cost;
      }
      if (score > 0 && (!best || score > best.score)) best = { t: t, lvl: lvl, cost: cost, score: score };
    }
    if (!best) break;

    // Buy it. Income at the moment of purchase sets how long it took to afford.
    var incomeNow = income0 * mNow;
    var dt = incomeNow > 0 ? best.cost / incomeNow : Infinity;
    coins += best.cost;
    seconds += dt;
    L[best.t.id] = best.lvl + 1;
    disc = discountsAt(L);
    if (best.t.kind === 'lab') labSeconds += stepTime(best.t, best.lvl, opts.labSpeed);

    steps.push({
      n: steps.length + 1,
      id: best.t.id,
      kind: best.t.kind,
      label: best.t.label,
      role: best.t.role,
      from: best.lvl,
      to: best.lvl + 1,
      cost: best.cost,
      coins: coins,
      seconds: seconds,
      labSeconds: labSeconds,
      mult: coinMult(L, opts, base),
      assumed: !!best.t.assumed
    });
  }
  return { steps: steps, levels: L, finalMult: coinMult(L, opts, base), labSeconds: labSeconds };
}

// Rough forward spend estimate over the next `horizon` purchases. With
// `applies` null it totals all spend; with a bucket name it totals only the
// spend that bucket's discount would apply to.
function projectedSpend(L, disc, opts, base, applies) {
  var tmp = {}, k;
  for (k in L) tmp[k] = L[k];
  var total = 0, n = 0;
  var pool = COIN_TRACKS.slice();
  var mNow = coinMult(tmp, opts, base);
  while (n < opts.horizon) {
    var best = null;
    for (var i = 0; i < pool.length; i++) {
      var t = pool[i], lvl = tmp[t.id] || 0;
      if (lvl >= trackMax(t)) continue;
      var cost = stepCost(t, lvl, disc);
      if (!isFinite(cost) || cost <= 0) continue;
      tmp[t.id] = lvl + 1;
      var mNext = coinMult(tmp, opts, base);
      tmp[t.id] = lvl;
      if (!(mNext > mNow)) continue;
      var sc = Math.log(mNext / mNow) / cost;
      if (!best || sc > best.sc) best = { t: t, lvl: lvl, cost: cost, sc: sc };
    }
    if (!best) break;
    // Only count spend the discount would actually apply to.
    var tb = trackTable(best.t);
    var bucket = best.t.kind === 'ws' ? 'ws-' + tb.c
               : best.t.kind === 'enh' ? 'enh-' + tb.c.split('/')[1] : 'lab';
    if (applies === null || bucket === applies) total += best.cost;
    tmp[best.t.id] = best.lvl + 1;
    mNow = coinMult(tmp, opts, base);
    n++;
  }
  return total;
}
