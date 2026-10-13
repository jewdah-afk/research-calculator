/*
  Onslaught+ : the post-release expansion layer (new towers, combos, account progression, passes and products).
  Classic mode never touches this file. Data lives in onslaught-data/expansion.json; the Luau mirror is
  onslaught-roblox/src/shared/Onslaught/Expansion.luau.

  Part A (sim) and part B (progression) are pure and run in Node for tests. Part C is the HTML UI.
*/
(function (root) {
"use strict";
const XD = (typeof EXPANSION !== "undefined" && EXPANSION) || (typeof require !== "undefined" ? require("../onslaught-data/expansion.json") : null);
const E = root.OnsEngine || (typeof require !== "undefined" ? require("./engine.js") : null);

// ================================================================ A. sim
// Merge the expansion into a copy of the classic data. `loadout` = { level, research: {id: lvl}, passes: {id: true} }.
function data(GAME, loadout) {
  loadout = loadout || { level: 1, research: {}, passes: {} };
  const D = JSON.parse(JSON.stringify(GAME));
  const arsenal = !!(loadout.passes && loadout.passes.arsenal);
  for (const k of XD.buildOrder) {
    const s = XD.turrets[k];
    const t = Object.assign({ unlock: 0, freak: false, freakLevel: { damage: 4, range: 0, rate: 4 }, modifiable: true, comboNever: false, poison: 0 }, JSON.parse(JSON.stringify(s)));
    if (arsenal && t.unlock) t.unlock = Math.floor(t.unlock / 2);
    const need = arsenal ? 0 : (s.requires && s.requires.level) || 0;
    t.levelLocked = (loadout.level || 1) < need ? need : 0;
    if (t.levelLocked) t.unlock = Infinity;          // never unlocks inside this game
    D.turrets[k] = t;
  }
  D.buildOrder = GAME.buildOrder.concat(XD.buildOrder);
  D.extraColours = XD.extraColours.slice();
  for (const k in XD.combos) D.combos[k] = XD.combos[k];
  return D;
}
function parseRule(str) {                            // "Yellow>=1&Green>=1"
  const parts = str.split("&").map(p => { const m = p.match(/^(\w+)(>=|==)(\d+)$/); return [m[1], m[2], +m[3]]; });
  return n => parts.every(([c, op, v]) => op === ">=" ? (n[c] || 0) >= v : (n[c] || 0) === v);
}
const RULES = {};
for (const lead in XD.rules) RULES[lead] = XD.rules[lead].map(([r, name]) => [parseRule(r), name]);
function rLevel(L, id) { return (L.research && L.research[id]) || 0; }
function researchValue(id, lvl) { const r = XD.research.find(q => q.id === id); return r ? r.per * Math.min(lvl, r.max) : 0; }

// Build the per-game options. `loadouts` maps playerId -> loadout (co-op: each player brings their own research).
function gameOpts(opts, loadouts) {
  const host = loadouts[opts.players ? opts.players[0] : "p1"] || Object.values(loadouts)[0] || { research: {}, passes: {} };
  opts.bonusCash = {};
  for (const pid in loadouts) {
    const L = loadouts[pid];
    opts.bonusCash[pid] = researchValue("funds", rLevel(L, "funds")) + (L.passes && L.passes.supply ? 50 : 0);
  }
  let bunker = 0; for (const pid in loadouts) bunker = Math.max(bunker, researchValue("bunker", rLevel(loadouts[pid], "bunker")));
  opts.lives = 10 + bunker;
  opts.mods = makeMods(loadouts, host);
  return opts;
}
function makeMods(loadouts, host) {
  const Lof = pid => loadouts[pid] || host;
  const beaconFor = (G, t) => {
    for (const b of G.turrets) if (b.kind === "Beacon" && b.active && !b.dead && E.dist(b, t) <= b.base.range) return b;
    return null;
  };
  const mods = {
    rules: RULES,
    init(G) {
      for (const k of XD.buildOrder) if (G.D.turrets[k].levelLocked) G.unlocked[k] = false;
      G.assisted = false; G.vaultPaid = 0; G.freeze = 0;
    },
    canBuild(G, pid, kind) {
      const d = G.D.turrets[kind];
      if (d.limitPerPlayer) { let n = 0; for (const t of G.turrets) if (t.kind === kind && t.owner === pid) n++; if (n >= d.limitPerPlayer) return false; }
      return true;
    },
    bounty(G, amount) {
      // the pool is split per player in cashWin; the multiplier is the host's (shared bounty)
      const L = host;
      return amount * (1 + researchValue("bounty", rLevel(L, "bounty")) + (L.passes && L.passes.supply ? 0.1 : 0));
    },
    resale(G, t) { return G.D.settings.resale + researchValue("salvage", rLevel(Lof(t.owner), "salvage")); },
    effective(G, t) {
      const d = G.D.turrets[t.kind];
      if (d.behaviour === "cryo") t.eff.damage = t.base.damage;            // strength ignores damage modifiers
      const m = researchValue("m_" + t.kind, rLevel(Lof(t.owner), "m_" + t.kind));
      if (m) t.eff.damage *= 1 + m;
    },
    rechargeMult(G, t) {
      const L = Lof(t.owner);
      let m = 1 - researchValue("theory", rLevel(L, "theory"));
      if (L.passes && L.passes.combomaster) m *= 0.85;
      if (beaconFor(G, t)) m *= XD.turrets.Beacon.modify.combo_recharge;
      return m;
    },
    comboDamage(G, t) { return beaconFor(G, t) ? XD.turrets.Beacon.modify.combo_damage : 1; },
    waveSent(G) {                                    // Gold Vault interest
      for (const t of G.turrets) {
        if (t.kind !== "Vault" || t.dead) continue;
        const p = G.players[t.owner]; if (!p) continue;
        const pay = Math.floor(Math.min(t.base.damage, p.cash * t.base.rate / 100));
        if (pay > 0) { p.cash += pay; G.vaultPaid += pay; E.fx(G, { k: "vault", x: t.x, y: t.y, v: pay }); }
      }
    },
    update(G, t, dt) {
      const d = G.D.turrets[t.kind];
      switch (d.behaviour) {
        case "vault": return true;
        case "mortar": {
          if (!inRing(t, t.target, t.eff.range, d.minRange)) t.target = acquireRing(G, t, t.eff.range, d.minRange, t.targetMode);
          if (E.alive(t.target)) { t.bearTo = null; E.tryFiring(G, t, t.target, dt); }
          return true;
        }
        case "cryo": {
          t.target = E.availOrAcquire(G, t.target, t, t.eff.range, t.targetMode);
          if (E.alive(t.target)) E.tryFiring(G, t, t.target, dt);
          return true;
        }
        case "arc": return false;                     // the standard update (aim, fire, combo) is right for it
        case "orbital": {
          if (E.canFire(G, t)) {
            const tg = E.acquire(G, t, t.eff.range, "strong");
            if (tg) E.turretFire(G, t, tg, t.eff.damage);
          }
          return true;
        }
      }
      return false;
    },
    fire(G, t, target, dmg, p) {
      const d = G.D.turrets[t.kind];
      switch (d.behaviour) {
        case "mortar": return shell(G, t, target, dmg, { type: "small", dmg, poison: 1 });
        case "cryo": {
          for (const a of G.attackers) {
            if (a.dead || a.holed || E.dist(t, a) > t.eff.range) continue;
            const cap = a.speedInit / t.eff.damage;
            if (a.speed > cap) { a.speed = cap; E.attackerMove(G, a); }
          }
          E.fx(G, { k: "cryo", x: t.x, y: t.y, r: t.eff.range });
          return null;
        }
        case "arc": {
          const jumps = (d.baseJumps || 2) + Math.floor(t.lvl.rate / 2);
          chain(G, t, E.muzzle(t), target, dmg, d.falloff, jumps, d.jumpRange, t.eff.poison || d.poison);
          return null;
        }
        case "orbital": {
          E.spawnBlast(G, d.blast, target.x, target.y, dmg, 1, t, null);
          E.fx(G, { k: "orbital", x: target.x, y: target.y });
          return null;
        }
      }
      return null;
    },
    comboFire(G, t, name, c, target, silent, h) {
      const C = XD.combos[name];
      switch (name) {
        case "carpet_bomb": {
          const pts = roadWalk(G, target, C.blasts, C.spacing);
          E.addShot(G, { k: "carpet", pts, i: 0, next: G.now, timing: C.timing, dmg: h.md(C.blast_damage), src: t });
          h.take(); break;
        }
        case "cryo_shell": shell(G, t, target, 0, { type: "poison", dmg: h.md(C.blast_damage), poison: C.blast_poison }); h.take(); break;
        case "ion_mortar": shell(G, t, target, 0, { type: "large", dmg: h.md(C.blast_damage), poison: 1 }, { arcs: C.arcs, arcDmg: h.md(C.arc_damage) }); h.take(); break;
        case "absolute_zero": {
          const dmg = h.md(C.damage);
          for (const a of G.attackers.slice()) {
            if (a.dead || a.holed || E.dist(t, a) > C.radius) continue;
            a.speed = 5; E.attackerMove(G, a); E.hit(G, a, dmg, t);
          }
          E.fx(G, { k: "freezewave", x: t.x, y: t.y, r: C.radius }); h.take(); break;
        }
        case "frost_mine": {
          const maxR = E.upAmountMax(t, "range");
          const pts = G.mines.filter(q => E.dist(t, q) <= maxR);
          if (pts.length) {
            const spot = E.arrayPick(G, pts, 1)[0];
            E.addShot(G, { k: "mine", x: t.x, y: t.y, sx: t.x, sy: t.y, tx: spot.x, ty: spot.y, t0: G.now, planted: false, twNext: G.now + 32, next: G.now + 150,
              target, src: t, big: true, blast: { type: "poison", dmg: h.md(C.blast_damage), poison: C.blast_poison }, cluster: null });
          }
          h.take(); break;
        }
        case "ion_field":
          E.addShot(G, { k: "field", x: target.x, y: target.y, r: C.radius, end: G.now + C.duration, next: G.now, tick: C.tick, dmg: h.md(C.damage), src: t });
          h.take(); break;
        case "storm": {
          const link = h.link();
          chain(G, t, h.m, target, h.md(link + C.damage), 1, C.jumps, C.jumpRange, 0);
          break;
        }
      }
    },
    updateShot(G, s) {
      if (s.k === "mortar") {                        // lobbed shell: flies to a fixed point
        if (G.now < s.land) { const r = (G.now - s.t0) / (s.land - s.t0); s.x = s.sx + (s.tx - s.sx) * r; s.y = s.sy + (s.ty - s.sy) * r; return; }
        s.x = s.tx; s.y = s.ty; s.dead = true;
        if (s.blast) E.spawnBlast(G, s.blast.type, s.x, s.y, s.blast.dmg, s.blast.poison, s.src, null);
        if (s.extra && s.extra.arcs) {
          const near = G.attackers.filter(a => !a.dead && !a.holed && E.dist(a, s) <= 150);
          for (const a of E.arrayPick(G, near, Math.min(near.length, s.extra.arcs))) E.sparkNow(G, s, a, s.extra.arcDmg, 0, s.src, "arc");
        }
        return;
      }
      if (s.k === "carpet") {
        if (G.now < s.next) return;
        s.next += s.timing;
        if (s.i >= s.pts.length) { s.dead = true; return; }
        const p = s.pts[s.i++];
        E.spawnBlast(G, "medium", p.x, p.y, s.dmg, 1, s.src, null);
        return;
      }
      if (s.k === "field") {
        if (G.now >= s.end) { s.dead = true; return; }
        if (G.now < s.next) return;
        s.next += s.tick;
        for (const a of G.attackers) if (!a.dead && !a.holed && E.dist(a, s) <= s.r) E.sparkNow(G, s, a, s.dmg, 0, s.src, "arc");
      }
    },
    step(G) {                                       // Time Freeze product: every attacker's clock stands still
      if (G.freeze > 0) {
        G.freeze--;
        for (const a of G.attackers) { if (a.tw) { a.tw.t0++; a.tw.next++; } if (a.rep) { a.rep.t0++; a.rep.next++; } }
      }
    },
  };
  return mods;
}
function inRing(t, a, r, min) { if (!a || a.dead) return false; const d = E.dist(t, a); return d <= r && d > min; }
function acquireRing(G, t, r, min, mode) {
  const saved = G.attackers;
  G.attackers = saved.filter(a => !a.dead && E.dist(t, a) > min);
  const a = E.acquire(G, t, r, mode);
  G.attackers = saved;
  return a;
}
function shell(G, t, target, dmg, blast, extra) {
  const m = E.muzzle(t), tx = target.x, ty = target.y;
  const d = E.dist(m, { x: tx, y: ty }), speed = G.D.turrets.Orange.shellSpeed;
  return E.addShot(G, { k: "mortar", sx: m.x, sy: m.y, x: m.x, y: m.y, tx, ty, t0: G.now, land: G.now + Math.max(1, Math.round(d / speed * 1000)), blast, extra: extra || null, src: t });
}
function chain(G, t, from, first, dmg, falloff, jumps, range, slow) {
  const hitSet = new Set();
  let cur = first, src = from, d = dmg;
  for (let i = 0; i <= jumps && E.alive(cur); i++) {
    hitSet.add(cur.id);
    E.sparkNow(G, src, cur, d, slow, t, "arc");
    src = { x: cur.x, y: cur.y };
    let best = null, bd = Infinity;
    for (const a of G.attackers) {
      if (a.dead || a.holed || hitSet.has(a.id)) continue;
      const q = E.dist(src, a);
      if (q <= range && q < bd) { bd = q; best = a; }
    }
    cur = best; d *= falloff;
  }
}
// Points along the road, walking backwards (toward the spawn) from the target
function roadWalk(G, target, n, spacing) {
  const pts = [];
  let x = target.x, y = target.y, wp = Math.max(1, (target.wp || 2) - 1);   // road index (1-based) behind the target
  for (let i = 0; i < n; i++) {
    pts.push({ x, y });
    let left = spacing;
    while (left > 0 && wp >= 1) {
      const p = G.road[wp - 1], d = E.dist({ x, y }, p);
      if (d >= left) { x += (p.x - x) / d * left; y += (p.y - y) / d * left; left = 0; }
      else { x = p.x; y = p.y; left -= d; wp--; }
    }
  }
  return pts;
}
// In-game products (the server validates the purchase; these apply it)
function useProduct(G, id, pid, arg) {
  const p = XD.products.find(q => q.id === id);
  if (!p || G.over && id !== "revive") return false;
  G.assisted = true;
  switch (id) {
    case "drop_s": case "drop_m": case "drop_l": G.players[pid].cash += 10 * Math.max(1, G.waveNum) * p.waves; return true;
    case "life": G.livesBought = (G.livesBought || 0) + 1; if (G.livesBought > p.maxPerGame) return false; G.lives++; return true;
    case "freeze": G.freeze += 8000; E.fx(G, { k: "freeze" }); return true;
    case "airstrike": {
      const hp = G.energy;
      E.spawnBlast(G, "huge", arg.x, arg.y, Math.max(6e7, 3 * hp), 1, null, null);
      E.fx(G, { k: "orbital", x: arg.x, y: arg.y }); return true;
    }
    case "revive":
      if (!G.lost) return false;
      G.over = false; G.lost = false; G.lives = 5; G.revives = (G.revives || 0) + 1;
      for (const a of G.attackers) a.dead = true;
      G.attackers = []; G.waves = [];
      G.waveLast = G.now;
      return true;
  }
  return false;
}
function revivePrice(G) { return 99 * Math.pow(2, G.revives || 0) + (G.revives ? Math.pow(2, G.revives) - 1 : 0); }

// ================================================================ B. account progression (pure)
const P = XD.progression;
function xpToNext(level) { return Math.round(P.levelCurve.base + P.levelCurve.coef * Math.pow(level, P.levelCurve.power)); }
function gameRewards(G, meta) {
  const W = G.waveNum, d = (G.challenge ? P.xp.difficulty[G.challenge.difficulty] : P.xp.difficulty[G.mode]) || 0;
  const passes = meta.passes || {};
  const tier = meta.prestige || 0, pb = 1 + tier * P.prestige.bonusPerTier;
  let xp = (W * (W + 1) / 2) * d * P.xp.perWave + G.kills * P.xp.perKill * (d > 0 ? 1 : 0);
  if (G.challenge && G.won) xp += P.xp.challengeWin;
  let intel = Math.floor(Math.pow(W, P.intel.waveExp) * d / P.intel.waveDiv + G.kills / P.intel.perKills * (d > 0 ? 1 : 0));
  const vip = passes.vip ? 1.25 : 1;
  xp *= vip * pb * (meta.xpBoostUntil && meta.xpBoostUntil > Date.now() ? 2 : 1);
  intel *= vip * pb * (passes.intel2 ? 2 : 1);
  return { xp: Math.round(xp), intel: Math.round(intel) };
}
function addXP(meta, xp) {
  meta.xp = (meta.xp || 0) + xp; meta.level = meta.level || 1;
  let ups = 0;
  while (meta.xp >= xpToNext(meta.level)) { meta.xp -= xpToNext(meta.level); meta.level++; ups++; }
  meta.totalXP = (meta.totalXP || 0) + xp;
  return ups;
}
function canPrestige(meta) { return (meta.level || 1) >= P.prestige.level; }
function prestige(meta) { if (!canPrestige(meta)) return false; meta.prestige = (meta.prestige || 0) + 1; meta.level = 1; meta.xp = 0; return true; }
function researchCost(id, lvl) { const r = XD.research.find(q => q.id === id); return r && lvl < r.max ? Math.round(r.base * Math.pow(r.growth, lvl)) : null; }
function buyResearch(meta, id) {
  meta.research = meta.research || {};
  const lvl = meta.research[id] || 0, c = researchCost(id, lvl);
  if (c === null || (meta.intel || 0) < c) return false;
  meta.intel -= c; meta.research[id] = lvl + 1; return true;
}
function dailyQuests(meta, dateKey) {
  if (meta.quests && meta.quests.date === dateKey) return meta.quests;
  let s = 0; for (const ch of dateKey) s = (s * 31 + ch.charCodeAt(0)) >>> 0;
  const pool = XD.quests.slice(), pick = [];
  for (let i = 0; i < 3 && pool.length; i++) { s = (s * 1103515245 + 12345) >>> 0; pick.push(pool.splice(s % pool.length, 1)[0].id); }
  meta.quests = { date: dateKey, list: pick.map(id => ({ id, progress: 0, done: false })) };
  return meta.quests;
}
function questStats(G) {
  const st = { combos: G.stats.combos, challenge_wins: G.challenge && G.won ? 1 : 0, wave_nolife: G.lives >= (G.startLives || 10) ? G.waveNum : 0 };
  for (const t of G.turrets) st["kills_" + t.kind] = (st["kills_" + t.kind] || 0) + t.kills;
  for (const k in (G.comboCounts || {})) st["combo_" + k] = G.comboCounts[k];
  const order = ["easy", "medium", "hard", "extreme"], mi = order.indexOf(G.challenge ? G.challenge.difficulty : G.mode);
  if (mi >= 1) st.wave_medium = G.waveNum;
  if (mi >= 2) st.wave_hard = G.waveNum;
  return st;
}
function applyQuests(meta, G) {
  const q = meta.quests; if (!q) return [];
  const st = questStats(G), done = [];
  for (const it of q.list) {
    if (it.done) continue;
    const def = XD.quests.find(d => d.id === it.id); if (!def) continue;
    const v = st[def.stat] || 0;
    it.progress = def.stat.startsWith("wave") || def.stat === "combos" ? Math.max(it.progress, v) : it.progress + v;
    if (it.progress >= def.goal) { it.done = true; meta.intel = (meta.intel || 0) + def.intel; addXP(meta, def.xp); done.push(def); }
  }
  return done;
}

const API = { XD, data, gameOpts, makeMods, useProduct, revivePrice, RULES, xpToNext, gameRewards, addXP, canPrestige, prestige, researchCost, buyResearch, researchValue, dailyQuests, applyQuests, roadWalk };
if (typeof module !== "undefined" && module.exports) module.exports = API;

// ================================================================ C. HTML UI (browser only)
if (typeof document === "undefined") return;
const store = {
  get(k, d) { try { const v = localStorage.getItem("ons2." + k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem("ons2." + k, JSON.stringify(v)); } catch (e) {} },
};
let meta = store.get("meta", { level: 1, xp: 0, intel: 0, research: {}, passes: {}, prestige: 0 });
const saveMeta = () => store.set("meta", meta);
const today = () => new Date().toISOString().slice(0, 10);
const fmtI = n => Math.floor(n).toLocaleString();

const css = document.createElement("style");
css.textContent = `.xbar{height:6px;background:#262b36;border-radius:3px;overflow:hidden}.xbar b{display:block;height:100%;background:var(--gold)}
.rs{display:grid;grid-template-columns:1fr auto auto;gap:6px;align-items:center;padding:6px 0;border-top:1px solid #222733}.rs small{color:var(--muted)}
.shopg{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px}.sp{border:1px solid var(--line);background:var(--panel2);border-radius:10px;padding:8px 10px}
.sp b{display:block}.sp p{margin:4px 0 6px;color:var(--muted);font-size:12px}.rbx{color:#7cf;font-weight:700}`;
document.head.appendChild(css);

function addOverlay(id, html) {
  const d = document.createElement("div"); d.className = "ov"; d.id = id; d.innerHTML = `<div class="card">${html}</div>`;
  document.getElementById("stage").appendChild(d);
  d.querySelectorAll("[data-x-back]").forEach(b => b.onclick = () => root.__onsOpenTitle && root.__onsOpenTitle());
  return d;
}
const ovProfile = addOverlay("ovProfile", `<div class="row"><h2>Profile & Research</h2><span class="spacer"></span><button class="btn sm" data-x-back>← Back</button></div><div id="profBody"></div>`);
const ovShop = addOverlay("ovShop", `<div class="row"><h2>Store (preview)</h2><span class="spacer"></span><button class="btn sm" data-x-back>← Back</button></div>
<p class="sub">Prices are the planned Robux prices. Nothing is bought here: the toggles only preview what each pass does.</p><div id="shopBody"></div>`);

function renderProfile() {
  const need = xpToNext(meta.level), q = dailyQuests(meta, today());
  saveMeta();
  const rows = XD.research.map(r => { const lvl = (meta.research[r.id] || 0), c = researchCost(r.id, lvl);
    return `<div class="rs"><div><b>${r.label}</b> <small>${lvl}/${r.max} · ${r.desc}</small></div><span class="num">${c === null ? '<span class="tag ok">max</span>' : fmtI(c) + " Intel"}</span><button class="btn sm gold" data-r="${r.id}" ${c === null || meta.intel < c ? "disabled" : ""}>Research</button></div>`; }).join("");
  const unlocks = Object.entries(XD.unlockLevels).map(([k, L]) => `<span class="tag ${meta.level >= L || meta.passes.arsenal ? "ok" : ""}">${XD.turrets[k].label} · L${L}</span>`).join(" ");
  const quests = q.list.map(it => { const d = XD.quests.find(x => x.id === it.id); return `<div class="rs"><div>${it.done ? "✔ " : ""}${d.text}<br><small>${Math.min(it.progress, d.goal)}/${d.goal}</small></div><span class="num">${d.intel} Intel</span><span class="num">${d.xp} XP</span></div>`; }).join("");
  document.getElementById("profBody").innerHTML = `
    <div class="row"><div><div style="font-size:22px;font-weight:700">Level ${meta.level}${meta.prestige ? ` <span class="tag warn">Clearance ${meta.prestige}</span>` : ""}</div><div class="num" style="color:var(--muted)">${fmtI(meta.xp)} / ${fmtI(need)} XP</div></div><span class="spacer"></span>
    <div style="text-align:right"><div style="font-size:22px;font-weight:700;color:var(--gold)" class="num">${fmtI(meta.intel)}</div><div style="color:var(--muted);font-size:12px">INTEL</div></div></div>
    <div class="xbar" style="margin:6px 0 10px"><b style="width:${Math.min(100, meta.xp / need * 100)}%"></b></div>
    ${canPrestige(meta) ? `<button class="btn gold" id="bPrestige">Take Clearance (reset to level 1, +5% XP & Intel forever)</button>` : ""}
    <h2 style="font-size:15px;margin-top:10px">Tower unlocks</h2><div class="row">${unlocks}</div>
    <h2 style="font-size:15px;margin-top:12px">Daily quests</h2>${quests}
    <h2 style="font-size:15px;margin-top:12px">Research lab <small style="color:var(--muted);font-weight:normal">(Onslaught+ only; Classic stays 1:1)</small></h2>${rows}`;
  document.querySelectorAll("[data-r]").forEach(b => b.onclick = () => { buyResearch(meta, b.dataset.r); saveMeta(); renderProfile(); });
  const bp = document.getElementById("bPrestige"); if (bp) bp.onclick = () => { prestige(meta); saveMeta(); renderProfile(); };
}
function renderShop() {
  const passes = XD.gamepasses.map(p => `<div class="sp"><b>${p.name}</b><span class="rbx">R$ ${p.robux}</span>${p.classic ? ' <span class="tag">Classic + Plus</span>' : ' <span class="tag warn">Plus only</span>'}<p>${p.effect}</p>
    <label style="font-size:12px"><input type="checkbox" data-p="${p.id}" ${meta.passes[p.id] ? "checked" : ""}> owned (preview)</label></div>`).join("");
  const prods = XD.products.map(p => `<div class="sp"><b>${p.name}</b><span class="rbx">R$ ${p.robux}</span>${p.plusOnly ? ' <span class="tag warn">in-game, Plus</span>' : ""}<p>${p.effect}</p>${p.intel ? `<button class="btn sm" data-i="${p.intel}">Add (preview)</button>` : ""}</div>`).join("");
  document.getElementById("shopBody").innerHTML = `<h2 style="font-size:15px">Game passes</h2><div class="shopg">${passes}</div><h2 style="font-size:15px;margin-top:12px">Developer products</h2><div class="shopg">${prods}</div>
    <p class="sub" style="margin-top:10px">${XD.fairness}</p>`;
  document.querySelectorAll("[data-p]").forEach(c => c.onchange = () => { meta.passes[c.dataset.p] = c.checked; saveMeta(); });
  document.querySelectorAll("[data-i]").forEach(b => b.onclick = () => { meta.intel += +b.dataset.i; saveMeta(); b.textContent = "Added"; });
}

const ui = {
  data(GAME) { return data(GAME, meta); },
  gameOpts(opts) { opts.players = ["p1"]; return gameOpts(opts, { p1: meta }); },
  titleTiles(list, startPlus) {
    const add = (title, sub, fn, cls) => { const b = document.createElement("button"); b.className = "tile"; if (cls) b.style.borderColor = cls; b.innerHTML = `<b>${title}</b><span>${sub}</span>`; b.onclick = fn; list.appendChild(b); };
    add("Onslaught+ · Medium", `New towers, combos and research · Level ${meta.level}`, () => startPlus("medium"), "#a07c1f");
    add("Onslaught+ · Hard", "The expansion on Hard", () => startPlus("hard"), "#a07c1f");
    add("Profile & Research", `${fmtI(meta.intel)} Intel · daily quests`, () => { for (const o of document.querySelectorAll(".ov")) o.classList.toggle("show", o.id === "ovProfile"); renderProfile(); });
    add("Store (preview)", "Game passes and products", () => { for (const o of document.querySelectorAll(".ov")) o.classList.toggle("show", o.id === "ovShop"); renderShop(); });
  },
  finish(G, profile) {
    G.startLives = G.startLives || 10;
    const r = gameRewards(G, meta);
    const ups = addXP(meta, r.xp);
    meta.intel = (meta.intel || 0) + r.intel;
    dailyQuests(meta, today());
    const done = applyQuests(meta, G);
    meta.lifetimeKills = (meta.lifetimeKills || 0) + G.kills;
    G.rewards = { ...r, ups, quests: done.map(d => d.text) };
    saveMeta();
  },
  endRows(G) {
    const r = G.rewards || { xp: 0, intel: 0, ups: 0, quests: [] };
    return `<tr><td>XP</td><td class="num"><b>+${fmtI(r.xp)}</b>${r.ups ? ` <span class="tag ok">level ${meta.level}!</span>` : ""}</td></tr><tr><td>Intel</td><td class="num"><b>+${fmtI(r.intel)}</b></td></tr>` +
      (r.quests.length ? `<tr><td>Quests</td><td>${r.quests.join("<br>")}</td></tr>` : "") + (G.assisted ? `<tr><td>Run</td><td><span class="tag warn">assisted</span></td></tr>` : "");
  },
  drawTurret(g, kind, rot, t) {
    const C = { Orange: "#f08a24", Cyan: "#29c4d8", Violet: "#9b5de5" };
    if (kind === "Orange") { g.rotate(rot * Math.PI / 180); g.fillStyle = C.Orange; g.beginPath(); g.arc(0, 0, 10, 0, 7); g.fill(); g.fillStyle = "#5a3410"; g.beginPath(); g.arc(4, 0, 5.5, 0, 7); g.fill(); g.fillStyle = "#222"; g.beginPath(); g.arc(6, 0, 3, 0, 7); g.fill(); return true; }
    if (kind === "Cyan") { g.fillStyle = C.Cyan; g.beginPath(); for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3; g.lineTo(Math.cos(a) * 10, Math.sin(a) * 10); } g.fill(); g.strokeStyle = "#e9fdff"; g.lineWidth = 1.6; for (let i = 0; i < 3; i++) { const a = i * Math.PI / 3; g.beginPath(); g.moveTo(Math.cos(a) * 7, Math.sin(a) * 7); g.lineTo(-Math.cos(a) * 7, -Math.sin(a) * 7); g.stroke(); } return true; }
    if (kind === "Violet") { g.fillStyle = C.Violet; g.beginPath(); g.arc(0, 0, 10, 0, 7); g.fill(); g.strokeStyle = "#f3e8ff"; g.lineWidth = 1.8; g.beginPath(); g.moveTo(-3, -7); g.lineTo(2, -1); g.lineTo(-2, 1); g.lineTo(3, 7); g.stroke(); return true; }
    if (kind === "Vault") { g.fillStyle = "#e0b23a"; g.fillRect(-10, -10, 20, 20); g.fillStyle = "#7a5a10"; g.beginPath(); g.arc(0, 0, 6, 0, 7); g.fill(); g.fillStyle = "#ffe9a8"; g.fillRect(-1, -6, 2, 12); return true; }
    if (kind === "Orbital") { g.fillStyle = "#24314d"; g.beginPath(); g.arc(0, 0, 13, 0, 7); g.fill(); g.strokeStyle = "#9cf"; g.lineWidth = 2; g.beginPath(); g.arc(0, 0, 8, 0, 7); g.stroke(); g.fillStyle = "#fff"; g.beginPath(); g.arc(0, 0, 3, 0, 7); g.fill(); return true; }
    return false;
  },
  drawShot(g, s, G) {
    if (s.k === "mortar") { const r = (G.now - s.t0) / Math.max(1, s.land - s.t0), lift = Math.sin(Math.PI * Math.min(1, r)) * 6; g.fillStyle = "rgba(0,0,0,.25)"; g.beginPath(); g.arc(s.x, s.y, 3, 0, 7); g.fill(); g.fillStyle = "#3a2410"; g.beginPath(); g.arc(s.x, s.y - lift * 3, 3.5 + lift / 3, 0, 7); g.fill(); return; }
    if (s.k === "field") { g.strokeStyle = "rgba(155,93,229,.7)"; g.fillStyle = "rgba(155,93,229,.12)"; g.lineWidth = 2; g.beginPath(); g.arc(s.x, s.y, s.r, 0, 7); g.fill(); g.stroke(); return; }
  },
};
root.OnsExpansion = Object.assign({}, API, ui, { meta: () => meta, saveMeta });
})(typeof window !== "undefined" ? window : globalThis);
