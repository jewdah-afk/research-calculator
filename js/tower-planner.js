/**
 * tower-planner.js — calculation engine for tower.html.
 *
 * Every cost/value lookup is an exact table read out of TOWER_DATA
 * (data/tower-data.js). The only closed forms here are the lab speed /
 * discount / gem-rush model, transcribed from the game bundle — see
 * research/THE-TOWER-SOURCES.md §A2.
 */
'use strict';

var $ = function (id) { return document.getElementById(id); };
var HAVE_DATA = typeof TOWER_DATA !== 'undefined';

/* ── lab model, from the bundle ──────────────────────────────────────── */
var SEC = { min: 60, hour: 3600, day: 86400, week: 604800, month: 2592e3, q: 7776e3, year: 31104e3 };

// vb — duration divisor from the Labs Speed lab and relic bonus.
function labSpeedMult(level, relicPct) { return (1 + 0.02 * level) * (1 + relicPct / 100); }

// _b — gems to rush a lab with t seconds remaining. Piecewise linear, then ceil.
function rushGems(t) {
  var lb = 1, ub = SEC.min, db = SEC.hour, fb = SEC.day, pb = SEC.week,
      mb = SEC.month, hb = SEC.q, gb = SEC.year, r;
  if (t > gb) r = 25e3;
  else if (t > hb) r = 17e3 / (gb - hb) * (t - hb) + 8e3;
  else if (t > mb) r = 4450 / (hb - mb) * (t - mb) + 3550;
  else if (t > pb) r = 2550 / (mb - pb) * (t - pb) + 1e3;
  else if (t > fb) r = 837 / (pb - fb) * (t - fb) + 163;
  else if (t > db) r = 155.5 / (fb - db) * (t - db) + 7.5;
  else if (t > ub) r = 7.375 / (db - ub) * (t - ub) + 0.125;
  else if (t > lb) r = 0.122917 / (ub - lb) * (t - lb) + 0.002083;
  else r = 0;
  return Math.ceil(r);
}

// Cb — gold-box gem discount.
function gemDiscount(boxes) { return 1 / (1 + 0.015 * boxes); }

/* ── formatting ──────────────────────────────────────────────────────── */
var SUF = ["", "K", "M", "B", "T", "q", "Q", "s", "S", "O", "N", "D", "UD", "DD"];
function fmt(n) {
  if (!isFinite(n)) return "∞";
  if (n === 0) return "0";
  if (n < 0) return "-" + fmt(-n);
  if (n < 1000) return n < 10 ? String(Math.round(n * 100) / 100) : String(Math.round(n));
  var t = 0;
  while (n >= 1000 && t < SUF.length - 1) { n /= 1000; t++; }
  return (n < 10 ? n.toFixed(3) : n < 100 ? n.toFixed(2) : n.toFixed(1)) + SUF[t];
}
function comma(n) { return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
function dur(s) {
  if (!isFinite(s)) return "never";
  if (s <= 0) return "0s";
  if (s < 60) return s.toFixed(s < 10 ? 1 : 0) + "s";
  if (s < 3600) return Math.floor(s / 60) + "m " + Math.round(s % 60) + "s";
  if (s < 86400) return Math.floor(s / 3600) + "h " + Math.round(s % 3600 / 60) + "m";
  if (s < 86400 * 365) return Math.floor(s / 86400) + "d " + Math.round(s % 86400 / 3600) + "h";
  return (s / 86400 / 365).toFixed(1) + "y";
}
function statVal(stat, level) {
  var v = stat.val[Math.max(0, Math.min(level, stat.val.length - 1))];
  return stat.disp === "pct" ? fmt(v) + "%" : fmt(v);
}
function num(id, dflt) {
  var v = parseFloat($(id).value);
  return isFinite(v) ? v : (dflt || 0);
}
function clampInt(id, lo, hi) {
  var v = Math.floor(num(id, lo));
  if (v < lo) v = lo;
  if (hi !== undefined && v > hi) v = hi;
  return v;
}

/* ── shared reads ────────────────────────────────────────────────────── */
function wsDiscount(cat) {
  var lvl = cat === "attack" ? clampInt("wsAtk", 0, 99)
          : cat === "defense" ? clampInt("wsDef", 0, 99)
          : clampInt("wsUti", 0, 99);
  return 1 - lvl * 0.003;
}
// Marginal coins for the single level `from -> from+1`.
function wsStep(stat, from) { return (stat.cost[from] || 0) * wsDiscount(stat.c); }
// Exact coins for `from -> to`, summed level by level.
function wsSpan(stat, from, to) {
  var sum = 0;
  for (var i = from; i < to; i++) sum += stat.cost[i] || 0;
  return sum * wsDiscount(stat.c);
}
// Highest level reachable from `from` on `coins`.
function wsAfford(stat, from, coins) {
  var d = wsDiscount(stat.c), spent = 0, lvl = from;
  while (lvl < stat.max) {
    var next = (stat.cost[lvl] || 0) * d;
    if (spent + next > coins) break;
    spent += next; lvl++;
  }
  return { level: lvl, spent: spent };
}

function labIndex(lab, level) {
  // lab tables are 1-indexed by level; levels[i] describes level i+1.
  return Math.max(0, Math.min(level - 1, lab.cost.length - 1));
}
function labSpan(lab, from, to) {
  var coins = 0, secs = 0, gems = 0,
      disc = 1 - clampInt("labDisc", 0, 99) * 0.003,
      mult = labSpeedMult(clampInt("labSpeed", 0, 99), num("relic", 0)),
      cell = parseFloat($("cell").value) || 1,
      gd = gemDiscount(clampInt("boxes", 0));
  for (var L = from + 1; L <= to; L++) {
    var i = labIndex(lab, L);
    coins += (lab.cost[i] || 0);
    var t = (lab.time[i] || 0) / mult / cell;
    secs += t;
    gems += rushGems(t);
  }
  return { coins: coins * disc, secs: secs, gems: Math.round(gems * gd) };
}
function labVal(lab, level) {
  if (level <= 0) return lab.val[0] !== undefined ? 0 : 0;
  return lab.val[labIndex(lab, level)];
}

/* ── tabs & persistence ──────────────────────────────────────────────── */
var KEY = "towerPlanner.v1";
var INPUTS = ["coins", "gems", "labSpeed", "labDisc", "relic", "boxes", "wsAtk", "wsDef", "wsUti",
              "wsStat", "wsFrom", "wsTo", "labCat", "labSel", "labFrom", "labTo", "cell", "labs",
              "cph", "kshare", "gtb", "gtd", "gtc", "labAssume", "steps", "horizon"];
function save() {
  var o = {};
  INPUTS.forEach(function (id) { if ($(id)) o[id] = $(id).value; });
  o.nb = {};
  document.querySelectorAll("[data-nb]").forEach(function (el) { o.nb[el.getAttribute("data-nb")] = el.value; });
  o.pl = {};
  document.querySelectorAll("[data-pl]").forEach(function (el) { o.pl[el.getAttribute("data-pl")] = el.value; });
  try { localStorage.setItem(KEY, JSON.stringify(o)); } catch (e) { /* private mode */ }
}
function load() {
  var o;
  try { o = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) { o = {}; }
  return o || {};
}

document.querySelectorAll("nav button").forEach(function (b) {
  b.addEventListener("click", function () {
    document.querySelectorAll("nav button").forEach(function (x) { x.classList.remove("on"); });
    document.querySelectorAll(".tab").forEach(function (x) { x.classList.remove("on"); });
    b.classList.add("on");
    $(b.getAttribute("data-tab")).classList.add("on");
  });
});

/* ── populate selects ────────────────────────────────────────────────── */
var WS_KEYS = [], LAB_BY_CAT = {};
if (HAVE_DATA) {
  WS_KEYS = Object.keys(TOWER_DATA.workshop).sort(function (a, b) {
    var A = TOWER_DATA.workshop[a], B = TOWER_DATA.workshop[b];
    return A.c === B.c ? A.n.localeCompare(B.n) : A.c.localeCompare(B.c);
  });
  var h = "", lastCat = null;
  WS_KEYS.forEach(function (k) {
    var s = TOWER_DATA.workshop[k];
    if (s.c !== lastCat) { if (lastCat) h += "</optgroup>"; h += '<optgroup label="' + s.c + '">'; lastCat = s.c; }
    h += '<option value="' + k + '">' + s.n + " — max " + s.max + "</option>";
  });
  $("wsStat").innerHTML = h + "</optgroup>";

  Object.keys(TOWER_DATA.labs).forEach(function (k) {
    var l = TOWER_DATA.labs[k];
    (LAB_BY_CAT[l.c] = LAB_BY_CAT[l.c] || []).push(k);
  });
  $("labCat").innerHTML = Object.keys(LAB_BY_CAT).sort().map(function (c) {
    return '<option value="' + c + '">' + c + " (" + LAB_BY_CAT[c].length + ")</option>";
  }).join("");
} else {
  $("dataWarn").style.display = "";
}

function fillLabSel(keep) {
  var cat = $("labCat").value;
  var keys = (LAB_BY_CAT[cat] || []).slice().sort(function (a, b) {
    return TOWER_DATA.labs[a].n.localeCompare(TOWER_DATA.labs[b].n);
  });
  $("labSel").innerHTML = keys.map(function (k) {
    return '<option value="' + k + '">' + TOWER_DATA.labs[k].n + " — max " + TOWER_DATA.labs[k].max + "</option>";
  }).join("");
  if (keep && keys.indexOf(keep) >= 0) $("labSel").value = keep;
}

/* ── "next best coin" stat picker ────────────────────────────────────── */
var NB_STATS = ["damage", "attack-speed", "critical-chance", "critical-factor", "multishot-chance",
                "rend-armor-mult", "super-crit-mult", "health", "health-regen", "defense-percent",
                "defense-absolute", "thorns", "lifesteal", "coins-kill-bonus", "cash-bonus", "coins-wave"];
if (HAVE_DATA) {
  $("nbGrid").innerHTML = NB_STATS.filter(function (k) { return TOWER_DATA.workshop[k]; }).map(function (k) {
    var s = TOWER_DATA.workshop[k];
    return '<div><label for="nb-' + k + '">' + s.n + "</label>" +
           '<input id="nb-' + k + '" data-nb="' + k + '" type="number" step="1" min="0" max="' + s.max + '" value="0"></div>';
  }).join("");
}

/* ── coin plan ───────────────────────────────────────────────────────── */
var HAVE_PLAN = HAVE_DATA && typeof TOWER_EXTRAS !== "undefined" && typeof buildPlan === "function";

function planTracks() {
  return COIN_TRACKS.concat(DISCOUNT_TRACKS.map(function (t) {
    return { id: t.id, kind: t.kind, role: "discount",
             label: (TOWER_DATA.labs[t.id] || {}).n || t.id };
  }));
}
if (HAVE_PLAN) {
  $("planLevels").innerHTML = planTracks().map(function (t) {
    var tb = t.kind === "ws" ? TOWER_DATA.workshop[t.id]
           : t.kind === "enh" ? TOWER_EXTRAS.enhancements[t.id] : TOWER_DATA.labs[t.id];
    if (!tb) return "";
    var tag = t.kind === "ws" ? "workshop" : t.kind === "enh" ? "enhance" : "lab";
    return '<div><label for="pl-' + t.id + '">' + t.label + " <span style=\"color:var(--muted)\">· " +
           tag + " · max " + tb.max + "</span></label>" +
           '<input id="pl-' + t.id + '" data-pl="' + t.id + '" type="number" step="1" min="0" max="' +
           tb.max + '" value="0"></div>';
  }).join("");
}

function renderPlan() {
  if (!HAVE_PLAN) return;
  var start = {};
  document.querySelectorAll("[data-pl]").forEach(function (el) {
    var v = Math.floor(parseFloat(el.value) || 0);
    if (v > 0) start[el.getAttribute("data-pl")] = v;
  });

  var opts = {
    killShare: Math.max(0, Math.min(1, num("kshare", 0.8))),
    labCoinPerLevel: num("labAssume", 2) / 100,
    gtBase: num("gtb", 5),
    gtDuration: num("gtd", 15),
    gtCooldown: num("gtc", 300),
    coinsPerHour: num("cph", 1e9),
    labSpeed: labSpeedMult(clampInt("labSpeed", 0, 99), num("relic", 0)),
    maxSteps: clampInt("steps", 10, 600),
    horizon: clampInt("horizon", 3, 40)
  };

  var r = buildPlan(start, opts);
  var last = r.steps[r.steps.length - 1];

  $("p-mult").textContent = r.finalMult.toFixed(2) + "\u00d7";
  $("p-coins").textContent = last ? fmt(last.coins) : "\u2014";
  $("p-time").textContent = last ? dur(last.seconds) : "\u2014";
  $("p-lab").textContent = dur(r.labSeconds);

  // doubling checkpoints
  var marks = "<tr><th>Income</th><th>Step</th><th>Coins spent</th><th>Elapsed</th><th>Next buy</th></tr>";
  var targets = [2, 3, 5, 10, 25, 50, 100], ti = 0, hit = 0;
  for (var i = 0; i < r.steps.length && ti < targets.length; i++) {
    if (r.steps[i].mult >= targets[ti]) {
      var st = r.steps[i], nx = r.steps[i + 1];
      marks += "<tr><td>" + targets[ti] + "\u00d7</td><td>" + st.n + "</td><td>" + fmt(st.coins) +
               "</td><td>" + dur(st.seconds) + "</td><td>" + (nx ? nx.label : "\u2014") + "</td></tr>";
      ti++; hit++; i--;
    }
  }
  if (!hit) marks += '<tr><td colspan="5" style="text-align:left;color:var(--muted)">' +
    "This plan does not reach 2\u00d7 income \u2014 lengthen it, or check your starting levels.</td></tr>";
  $("p-marks").innerHTML = marks;

  var rows = "<tr><th>#</th><th>Buy</th><th>Level</th><th>Cost</th><th>Coins so far</th><th>Elapsed</th><th>Income</th></tr>";
  var cap = Math.min(r.steps.length, 150);
  for (var j = 0; j < cap; j++) {
    var s2 = r.steps[j];
    var cls = j === 0 ? "first" : (j === cap - 1 ? "last" : "");
    rows += '<tr class="' + cls + '"><td>' + s2.n + "</td><td>" + s2.label +
            (s2.assumed ? ' <span style="color:var(--amber)" title="relies on the assumed coin-lab rate">\u2020</span>' : "") +
            (s2.role === "discount" ? ' <span style="color:var(--muted)">cheaper, not richer</span>' : "") +
            "</td><td>" + comma(s2.from) + " \u2192 " + comma(s2.to) + "</td><td>" + fmt(s2.cost) +
            "</td><td>" + fmt(s2.coins) + "</td><td>" + dur(s2.seconds) + "</td><td>" +
            s2.mult.toFixed(3) + "\u00d7</td></tr>";
  }
  $("p-table").innerHTML = rows;

  var assumed = r.steps.filter(function (x) { return x.assumed; }).length;
  $("p-note").innerHTML =
    "Showing " + cap + " of " + r.steps.length + " steps. " +
    "\u2020 marks the " + assumed + " step" + (assumed === 1 ? "" : "s") +
    " that rely on the assumed coin-lab rate (" + num("labAssume", 2) + "%/level) rather than a sourced curve. " +
    "Rows marked <em>cheaper, not richer</em> are discount labs: they add no income, they cut the price of " +
    "everything after them, which is why they earn a place in the order at all.";
}

/* ── render ──────────────────────────────────────────────────────────── */
function renderWorkshop() {
  var stat = TOWER_DATA.workshop[$("wsStat").value];
  if (!stat) return;
  $("wsFrom").max = stat.max; $("wsTo").max = stat.max;
  var from = clampInt("wsFrom", 0, stat.max);
  var to = clampInt("wsTo", 0, stat.max);
  if (to < from) to = from;

  var cost = wsSpan(stat, from, to);
  var coins = num("coins", 0);
  var aff = wsAfford(stat, from, coins);
  var vA = stat.val[from], vB = stat.val[to];

  $("w-la").textContent = comma(from);
  $("w-lb").textContent = comma(to);
  $("w-va").textContent = statVal(stat, from);
  $("w-vb").textContent = statVal(stat, to);
  $("w-sa").textContent = stat.n;
  $("w-sb").textContent = "max " + comma(stat.max);
  $("w-mult").textContent = vA > 0 ? "×" + (vB / vA).toFixed(2) : "";
  $("w-n").textContent = comma(to - from);
  $("w-cost").textContent = fmt(cost);
  $("w-afford").textContent = "lvl " + comma(aff.level);
  $("w-max").textContent = fmt(wsSpan(stat, from, stat.max));

  var disc = wsDiscount(stat.c);
  var gain = vA > 0 ? (vB / vA - 1) * 100 : 0;
  // Past a few hundred percent, "+35000%" stops being readable — say "x351" instead.
  var gainTxt = gain > 300 ? "\u00d7" + (vB / vA).toFixed(1)
              : (gain >= 0 ? "+" : "") + gain.toFixed(1) + "%";
  $("w-verdict").innerHTML =
    "<b>" + stat.n + "</b> (" + stat.c + ") from <b>" + comma(from) + "</b> to <b>" + comma(to) + "</b> costs <b>" +
    fmt(cost) + "</b> coins" + (disc < 1 ? " after your " + ((1 - disc) * 100).toFixed(1) + "% " + stat.c + " discount" : "") +
    " and moves the stat " + gainTxt + ". " +
    (aff.level >= to
      ? "Your " + fmt(coins) + " coins cover it, with " + fmt(coins - wsSpan(stat, from, to)) + " left over."
      : "Your " + fmt(coins) + " coins stop at level <b>" + comma(aff.level) + "</b> — " +
        fmt(cost - aff.spent) + " short.");

  var rows = "<tr><th>Level</th><th>Value</th><th>This level</th><th>Cumulative</th></tr>";
  var span = to - from, step = Math.max(1, Math.ceil(span / 24)), run = 0, shown = {};
  for (var L = from; L < to; L++) {
    run += wsStep(stat, L);
    var isEdge = (L === from || L === to - 1);
    if (!isEdge && (L - from) % step !== 0) continue;
    if (shown[L]) continue; shown[L] = 1;
    var cls = L === from ? "first" : (L === to - 1 ? "last" : (L <= aff.level - 1 ? "" : "reach"));
    rows += '<tr class="' + cls + '"><td>' + comma(L) + " → " + comma(L + 1) + "</td><td>" +
            statVal(stat, L + 1) + "</td><td>" + fmt(wsStep(stat, L)) + "</td><td>" + fmt(run) + "</td></tr>";
  }
  if (span === 0) rows += '<tr><td colspan="4" style="text-align:left;color:var(--muted)">Pick a target above your current level.</td></tr>';
  $("w-table").innerHTML = rows;
}

function renderLab() {
  var lab = TOWER_DATA.labs[$("labSel").value];
  if (!lab) return;
  $("labFrom").max = lab.max; $("labTo").max = lab.max;
  var from = clampInt("labFrom", 0, lab.max);
  var to = clampInt("labTo", 0, lab.max);
  if (to < from) to = from;

  var r = labSpan(lab, from, to);
  var parallel = Math.max(1, clampInt("labs", 1, 5));
  var wall = r.secs / parallel;

  $("l-la").textContent = comma(from);
  $("l-lb").textContent = comma(to);
  $("l-va").textContent = fmt(labVal(lab, from));
  $("l-vb").textContent = fmt(labVal(lab, to));
  $("l-sa").textContent = lab.n;
  $("l-sb").textContent = lab.c + " · max " + lab.max;
  $("l-mult").textContent = comma(to - from) + " lvl";
  $("l-cost").textContent = fmt(r.coins);
  $("l-time").textContent = dur(r.secs);
  $("l-wall").textContent = dur(wall);
  $("l-gems").textContent = comma(r.gems);

  var coins = num("coins", 0), gems = num("gems", 0);
  var mult = labSpeedMult(clampInt("labSpeed", 0, 99), num("relic", 0));
  var cell = parseFloat($("cell").value) || 1;
  var done = new Date(Date.now() + wall * 1000);
  $("l-verdict").innerHTML =
    "<b>" + lab.n + "</b> " + comma(from) + " → " + comma(to) + ": <b>" + fmt(r.coins) + "</b> coins and <b>" +
    dur(r.secs) + "</b> of research at your " + mult.toFixed(2) + "× lab speed" +
    (cell > 1 ? " × " + cell + " Elite Cell" : "") + ". " +
    (parallel > 1 ? "Across " + parallel + " labs that is about " + dur(wall) + " — done " +
      done.toLocaleDateString() + ". " : "Done " + done.toLocaleDateString() + ". ") +
    (coins >= r.coins ? "Coins: covered." : "Coins: <b>" + fmt(r.coins - coins) + "</b> short.") +
    " Rushing the whole span costs <b>" + comma(r.gems) + "</b> gems" +
    (gems >= r.gems ? " — you have them." : " — " + comma(r.gems - gems) + " more than you hold.") ;

  var rows = "<tr><th>Level</th><th>Value</th><th>Coins</th><th>Time</th><th>Rush gems</th></tr>";
  var span = to - from, step = Math.max(1, Math.ceil(span / 24));
  var disc = 1 - clampInt("labDisc", 0, 99) * 0.003, gd = gemDiscount(clampInt("boxes", 0));
  for (var L = from + 1; L <= to; L++) {
    var isEdge = (L === from + 1 || L === to);
    if (!isEdge && (L - from - 1) % step !== 0) continue;
    var i = labIndex(lab, L), t = (lab.time[i] || 0) / mult / cell;
    var cls = L === from + 1 ? "first" : (L === to ? "last" : "");
    rows += '<tr class="' + cls + '"><td>' + comma(L) + "</td><td>" + fmt(lab.val[i]) + "</td><td>" +
            fmt((lab.cost[i] || 0) * disc) + "</td><td>" + dur(t) + "</td><td>" +
            comma(Math.round(rushGems(t) * gd)) + "</td></tr>";
  }
  if (span === 0) rows += '<tr><td colspan="5" style="text-align:left;color:var(--muted)">Pick a target above your current level.</td></tr>';
  $("l-table").innerHTML = rows;
}

function renderNextBest() {
  var coins = num("coins", 0), out = [];
  document.querySelectorAll("[data-nb]").forEach(function (el) {
    var key = el.getAttribute("data-nb"), stat = TOWER_DATA.workshop[key];
    if (!stat) return;
    var lvl = Math.max(0, Math.min(Math.floor(parseFloat(el.value) || 0), stat.max));
    if (lvl >= stat.max) { out.push({ stat: stat, lvl: lvl, maxed: true }); return; }
    var cost = wsStep(stat, lvl);
    var vA = stat.val[lvl], vB = stat.val[lvl + 1];
    var gainPct = vA > 0 ? (vB / vA - 1) * 100 : 0;
    out.push({ stat: stat, lvl: lvl, cost: cost, gain: gainPct, per: gainPct > 0 ? cost / gainPct : Infinity });
  });
  out.sort(function (a, b) {
    if (a.maxed !== b.maxed) return a.maxed ? 1 : -1;
    return a.per - b.per;
  });

  var rows = "<tr><th>Stat</th><th>Level</th><th>Next costs</th><th>Stat gain</th><th>Coins per 1%</th><th>Afford</th></tr>";
  out.forEach(function (o, i) {
    if (o.maxed) {
      rows += '<tr class="reach"><td>' + o.stat.n + "</td><td>" + comma(o.lvl) +
              '</td><td colspan="4" style="text-align:right;color:var(--muted)">maxed</td></tr>';
      return;
    }
    rows += '<tr class="' + (i === 0 ? "first" : "") + '"><td>' + o.stat.n + "</td><td>" + comma(o.lvl) +
            " → " + comma(o.lvl + 1) + "</td><td>" + fmt(o.cost) + "</td><td>+" + o.gain.toFixed(2) +
            "%</td><td>" + fmt(o.per) + "</td><td>" + (coins >= o.cost ? "yes" : "no") + "</td></tr>";
  });
  $("nb-table").innerHTML = rows;

  var best = out.filter(function (o) { return !o.maxed && isFinite(o.per); })[0];
  $("nbNote").innerHTML = best
    ? "Best coin right now: <b style='color:var(--moss)'>" + best.stat.n + "</b> at " + fmt(best.cost) +
      " coins for +" + best.gain.toFixed(2) + "% (" + fmt(best.per) + " per 1%)." +
      " Ratios only compare within a stat's own curve — a percent of Damage and a percent of Coins/Kill are not the same percent."
    : "Enter some levels above.";
}

function renderFormulas() {
  var e = clampInt("labSpeed", 0, 99), t = num("relic", 0), o = clampInt("boxes", 0),
      d = clampInt("labDisc", 0, 99);
  $("f-live").innerHTML =
    "vb = (1 + 0.02×" + e + ")(1 + " + t + "/100) = <b>" + labSpeedMult(e, t).toFixed(4) + "×</b><br>" +
    "coins × (1 − " + d + "×0.003) = <b>×" + (1 - d * 0.003).toFixed(4) + "</b><br>" +
    "Cb = 1/(1 + 0.015×" + o + ") = <b>×" + gemDiscount(o).toFixed(4) + "</b> on rush gems";

  $("f-rush").innerHTML =
    '<span class="c">// seconds remaining -&gt; gems, then ceil</span>\n' +
    "t &gt; 360d  →  25000\n" +
    "t &gt;  90d  →  17000/(360d−90d)·(t−90d) +  8000\n" +
    "t &gt;  30d  →   4450/( 90d−30d)·(t−30d) +  3550\n" +
    "t &gt;   7d  →   2550/( 30d− 7d)·(t− 7d) +  1000\n" +
    "t &gt;   1d  →    837/(  7d− 1d)·(t− 1d) +   163\n" +
    "t &gt;   1h  →  155.5/(  1d− 1h)·(t− 1h) +   7.5\n" +
    "t &gt;   1m  →  7.375/(  1h− 1m)·(t− 1m) +  0.125\n" +
    "t &gt;   1s  →   0.122917/(1m−1s)·(t−1s) + 0.002083";

  var marks = [["1 minute", 60], ["1 hour", 3600], ["6 hours", 21600], ["1 day", 86400],
               ["3 days", 259200], ["1 week", 604800], ["30 days", 2592e3], ["90 days", 7776e3], ["360 days", 31104e3]];
  var gd = gemDiscount(o);
  var rows = "<tr><th>Remaining</th><th>Gems</th><th>Gems / hour</th><th>After your boxes</th></tr>";
  marks.forEach(function (m) {
    var g = rushGems(m[1]);
    rows += "<tr><td>" + m[0] + "</td><td>" + comma(g) + "</td><td>" + (g / (m[1] / 3600)).toFixed(2) +
            "</td><td>" + comma(Math.round(g * gd)) + "</td></tr>";
  });
  $("f-rushtable").innerHTML = rows;
}

function renderMeta() {
  var lv = 0;
  Object.keys(TOWER_DATA.workshop).forEach(function (k) { lv += TOWER_DATA.workshop[k].max; });
  Object.keys(TOWER_DATA.labs).forEach(function (k) { lv += TOWER_DATA.labs[k].max; });
  $("s-ws").textContent = Object.keys(TOWER_DATA.workshop).length;
  $("s-lab").textContent = Object.keys(TOWER_DATA.labs).length;
  $("s-lv").textContent = comma(lv);
  $("s-gen").textContent = TOWER_DATA.generated;
}

function renderStack() {
  var mult = labSpeedMult(clampInt("labSpeed", 0, 99), num("relic", 0));
  $("stack").innerHTML =
    "Lab speed <b style='color:var(--moss)'>" + mult.toFixed(2) + "×</b> · " +
    "lab coins <b style='color:var(--moss)'>−" + (clampInt("labDisc", 0, 99) * 0.3).toFixed(1) + "%</b> · " +
    "workshop coins <b style='color:var(--moss)'>−" + (clampInt("wsAtk", 0, 99) * 0.3).toFixed(1) + "% / −" +
    (clampInt("wsDef", 0, 99) * 0.3).toFixed(1) + "% / −" + (clampInt("wsUti", 0, 99) * 0.3).toFixed(1) +
    "%</b> attack / defense / utility · rush gems <b style='color:var(--moss)'>×" +
    gemDiscount(clampInt("boxes", 0)).toFixed(3) + "</b>";
}

function render() {
  if (!HAVE_DATA) return;
  renderStack();
  renderWorkshop();
  renderLab();
  renderNextBest();
  renderPlan();
  renderFormulas();
  save();
}

/* ── wire up ─────────────────────────────────────────────────────────── */
if (HAVE_DATA) {
  var saved = load();
  INPUTS.forEach(function (id) {
    if ($(id) && saved[id] !== undefined && id !== "labSel") $(id).value = saved[id];
  });
  fillLabSel(saved.labSel);
  if (saved.nb) Object.keys(saved.nb).forEach(function (k) {
    var el = document.querySelector('[data-nb="' + k + '"]');
    if (el) el.value = saved.nb[k];
  });
  if (saved.pl) Object.keys(saved.pl).forEach(function (k) {
    var el = document.querySelector('[data-pl="' + k + '"]');
    if (el) el.value = saved.pl[k];
  });

  $("labCat").addEventListener("change", function () { fillLabSel(); render(); });
  document.addEventListener("input", render);
  document.addEventListener("change", render);
  renderMeta();
  render();
}
