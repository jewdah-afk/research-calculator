// Phase 7: the Archivist's Book, the archivist tree and the Echo Field's numbers (Birb sC, Gn, Tn, In, Sn, Rn, vn, En, Cn, dn).
// Data comes from js/archivist_data.js (tools/build_archivist_data.js). The field itself (map 30) lives in js/echo_field.js.
(function () {
  const PT = window.PT, AD = window.ARCHIVIST_DATA, D = PT.D;
  // the live archivist nodes replace the older snapshot in data.js; their stations sit in the archivist tree view
  for (const u of AD.upgrades) { const old = PT.SUN.get(u.id) || {}; PT.SUN.set(u.id, Object.assign({}, old, u, { effectFn: old.effectFn || (() => 1) })); }
  // the rest of the tree: Birb's live gates (nestTierRequired, parrotRebirbRequired, maxLevel...) over the older data.js snapshot
  for (const u of AD.sunflower || []) { const old = PT.SUN.get(u.id); if (old) PT.SUN.set(u.id, Object.assign({}, old, u, { effectFn: old.effectFn, effect: old.effect })); }
  PT.ARCHIVIST_STATIONS = AD.stations;
  // names and effects shown on the stations (Birb's English labels)
  const NAMES = { d_unlock_archivist_tree: ["Archivist's Branch", "Unlock the Echo Field and its tree. Uses the Archivist's Book. Needs Evolution 6."],
    d_archivist_popcorn_echo: ["Popcorn Echo", "Plain popcorn eaten in the Echo Field has a 25% chance to spawn 1 plain + 1 Echo."], d_archivist_auric_rebirb: ["Auric Rebirb", "Golden Popcorn multiplies Molt plumes."],
    d_archivist_golden_ascension: ["Golden Ascension", "Plumes multiply Echo value (min x2.25)."], d_archivist_echo_chance: ["Echo Resonance", "Echo chance 25% → 30%."],
    d_archivist_echo_value_milestones: ["Echo Mastery", "x3 Echo value every 25 levels of Echo Value."], d_archivist_echo_capacity_expansion: ["Resonant Expansion", "+10 levels of Resonant Field."],
    d_archivist_echo_near_response: ["Nearby Response", "75% of Echo popcorn appears near where you ate."], d_archivist_echo_duet: ["Duet", "+20% Echo value."], d_archivist_echo_tuning: ["Tuning", "Echo chance 30% → 35%."],
    d_archivist_echo_trail: ["Violet Trail", "Pulls purple Echoes within 180."], d_archivist_echo_chord: ["Full Chord", "Duet +20% → +40%."], d_archivist_echo_harvest: ["Tuned Harvest", "+25% Echo value."],
    d_archivist_echo_mycelium: ["Awakened Mycelium", "One mushroom picks up to 1 popcorn/s."], d_archivist_echo_meeting: ["Meeting Points", "Half of new plain popcorn spawns near mushrooms."],
    d_archivist_echo_network: ["Underground Network", "Three mushrooms, 2 pickups/s."], d_archivist_echo_roots: ["Long Roots", "Mushroom reach 320 → 400."], d_archivist_echo_coordination: ["Coordinated Harvest", "Mushrooms 3 pickups/s."],
    d_archivist_echo_route: ["Perfect Route", "Mushrooms 4 pickups/s."], d_archivist_echo_flock_memory: ["Flock Memory", "Lifetime Echo boosts Sparrow, Dave, Seagull and Crow XP."],
    d_archivist_echo_golden_memory: ["Golden Memories", "+15% Golden Popcorn in the Desert."], d_archivist_echo_veil: ["Echoes of the Veil", "Mythic Aura drops: 10% chance of a copy."],
    d_archivist_echo_knowledge: ["Shared Knowledge", "Flock Memory also boosts Parrot XP."], d_archivist_echo_ancient_roots: ["Ancient Roots", "+15% twigs from Nest trees."],
    d_archivist_echo_deep_memory: ["Deep Memory", "Mythic copy chance 10% → 20%."], d_archivist_echo_resonant_grove: ["Resonant Grove", "+35% Echo value."], d_archivist_echo_forever: ["An Echo Forever", "+20% Echo value."] };
  for (const [id, [name, description]] of Object.entries(NAMES)) { const d = PT.SUN.get(id); if (d) Object.assign(d, { name, description }); }
  PT.isArchivistNode = (id) => id.startsWith("d_archivist_");

  // ------------------------------------------------------------------ the book (Birb sC / Gn / Yn)
  PT.ARCHIVIST_BOOK = "Archivist's Book";
  PT.archivistTreeOpen = (s) => (s.sunflowerUpgrades?.d_unlock_archivist_tree || 0) > 0; // Birb Gn (Pa)
  PT.archivistBooks = (s) => (s.parrot?.artifactInventory || []).reduce((n, t) => (t.name === PT.ARCHIVIST_BOOK ? n + Math.max(0, Math.floor(t.count ?? 1)) : n), 0); // Birb Yn
  PT.archivistBeaten = (s) => (s.expedition?.archivistEncounterVersion || 0) >= 1 && s.expedition?.archivistDefeated === true; // Birb rc
  // Birb sC: once the Archivist falls, a locked book waits in the bag until it opens the tree
  PT.grantArchivistBook = function (s) {
    const p = s.parrot; if (s.expedition && PT.expState) PT.expState(s); if (!p || !s.expedition || !PT.archivistBeaten(s) || PT.archivistTreeOpen(s) || PT.archivistBooks(s) > 0) return false;
    p.artifactInventory ||= []; p.artifactInventory.push({ instanceId: "quest_archivist_book", name: PT.ARCHIVIST_BOOK, count: 1, locked: true });
    p.discoveredArtifacts ||= []; if (!p.discoveredArtifacts.includes(PT.ARCHIVIST_BOOK)) p.discoveredArtifacts.push(PT.ARCHIVIST_BOOK);
    return true;
  };
  // the tree unlock is bought with the book (Birb purchaseSunflowerUpgrade, currency "archivist_book")
  PT.altCurrency ||= {};
  PT.altCurrency.archivist_book = {
    has: (s, c) => PT.archivistBooks(s) >= c,
    sub: (s, c) => { const inv = s.parrot.artifactInventory, i = inv.findIndex((e) => e.name === PT.ARCHIVIST_BOOK && (e.count ?? 1) > 0); if (i < 0) return; const it = inv[i];
      if ((it.count ?? 1) > 1) it.count = Math.floor(it.count) - 1; else inv.splice(i, 1); },
  };

  // ------------------------------------------------------------------ echo nodes (Birb wn / bn)
  const NODE = { R1: "near_response", R2: "duet", R3: "tuning", R4: "trail", R5: "chord", R6: "harvest", A1: "mycelium", A2: "meeting", A3: "network", A4: "roots", A5: "coordination", A6: "route",
    V1: "flock_memory", V2: "golden_memory", V3: "veil", V4: "knowledge", V5: "ancient_roots", V6: "deep_memory", F1: "resonant_grove", F2: "forever" };
  PT.echoNode = (s, k) => (s.sunflowerUpgrades?.["d_archivist_echo_" + NODE[k]] || 0) > 0;
  const has = (s, id) => (s.sunflowerUpgrades?.[id] || 0) > 0;
  PT.ECHO_FIELD_MAP = 30; PT.ECHO_FIELD_W = 1600; PT.ECHO_FIELD_H = 1200; // Birb maps b / a / E
  PT.echoFieldOpen = (s) => has(s, "d_archivist_popcorn_echo"); // Birb Oa
  PT.echoBounds = (w = PT.ECHO_FIELD_W, h = PT.ECHO_FIELD_H) => { const i = Math.min(220, w / 4), a = Math.min(180, h / 4); return { left: i, right: w - i, top: a, bottom: h - a }; }; // Birb fn
  PT.echoChance = (s) => Math.min(0.35, 0.25 + (has(s, "d_archivist_echo_chance") ? 0.05 : 0) + (PT.echoNode(s, "R3") ? 0.05 : 0)); // Birb In
  PT.echoMushroomRate = (s) => (PT.echoNode(s, "A6") ? 4 : PT.echoNode(s, "A5") ? 3 : PT.echoNode(s, "A3") ? 2 : PT.echoNode(s, "A1") ? 1 : 0); // Birb Sn
  PT.echoMushrooms = (s) => (PT.echoNode(s, "A3") ? [{ x: 480, y: 460 }, { x: 1120, y: 460 }, { x: 800, y: 820 }] : PT.echoNode(s, "A1") ? [{ x: 800, y: 600 }] : []); // Birb Rn
  PT.echoMushroomReach = (s) => (PT.echoNode(s, "A4") ? 400 : 320); // Birb vn
  // Birb An / cn / dn: golden popcorn drives Auric Rebirb, golden feathers drive Golden Ascension (min x2.25)
  const An = (x) => { const t = D(x); if (t.lte(0)) return 0; const i = t.add(1).log10().toNumber() / 16; return 6 * (i <= 1 ? i : 1 + Math.log1p(i - 1) / 10); };
  PT.auricRebirbMult = (s) => (has(s, "d_archivist_auric_rebirb") ? 1 + An(s.resources.goldenPopcorn) : 1);
  PT.goldenAscensionMult = (s) => (has(s, "d_archivist_golden_ascension") ? Math.max(2.25, 1 + An(s.resources.goldenFeathers) / 4) : 1);
  // Birb Tn: what one purple popcorn is worth on top of Echo Value's level
  PT.echoValueMult = function (s, L) {
    const m = has(s, "d_archivist_echo_value_milestones") ? 3 ** Math.floor(Math.max(0, Math.floor(Number.isFinite(L) ? L : 0)) / 25) : 1;
    const n = (k) => PT.echoNode(s, k);
    return PT.goldenAscensionMult(s) * m * (n("R5") ? 1.4 : n("R2") ? 1.2 : 1) * (n("R6") ? 1.25 : 1) * (n("F1") ? 1.35 : 1) * (n("F2") ? 1.2 : 1);
  };
  // Birb En: lifetime echo boosts companion XP (Flock Memory), and parrot XP with Shared Knowledge
  PT.echoLifetime = (s) => D(s.echoGrove?.lifetimeEarned || 0); // Birb En reads only the grove total
  PT.flockMemoryMult = function (s, who) {
    if (!PT.echoNode(s, who === "parrot" ? "V4" : "V1")) return 1;
    const i = PT.echoLifetime(s).div(1e4).add(1).log10().toNumber();
    return Number.isFinite(i) ? 1 + Math.max(0, i) / (Math.max(0, i) + 4) : 1;
  };
  PT.mythicCopyChance = (s) => (PT.echoNode(s, "V6") ? 0.2 : PT.echoNode(s, "V3") ? 0.1 : 0); // Birb Cn
  // Birb GC: the grove state (v2) keeps the lifetime total; retired v1 nodes refund their echo
  const OLD = [["d_archivist_echo_refrain", 4e3], ["d_archivist_echo_saved_song", 35e3], ["d_archivist_echo_voices", 3e5], ["d_archivist_echo_harmony", 3e6], ["d_archivist_echo_festival", 35e6], ["d_archivist_echo_last_verse", 16e7]];
  PT.echoGrove = function (s) {
    if (s.echoGrove?.version === 2) return s.echoGrove;
    const n = { version: 2, lifetimeEarned: PT.num(s.echoGrove?.lifetimeEarned ?? s.resources.echoPopcorn ?? 0) }; let back = 0; const a = s.sunflowerUpgrades || {};
    for (const [id, v] of OLD) { if (Number.isFinite(a[id]) && a[id] >= 1) back += v; delete a[id]; }
    if (back > 0) s.resources.echoPopcorn = D(s.resources.echoPopcorn).add(back);
    return (s.echoGrove = n);
  };

  // ------------------------------------------------------------------ Echo Field shop (Birb qc / jc / $c / td / ad)
  const MAXL = { p_echo_value: 999, p_echo_capacity: 10 };
  const maxL = (s, id) => MAXL[id] + (id === "p_echo_capacity" && has(s, "d_archivist_echo_capacity_expansion") ? 10 : 0);
  const td = (id, L) => { const i = Math.min(MAXL[id] + (id === "p_echo_capacity" ? 10 : 0), Math.max(1, Math.floor(Number(L) || 1))) - 1; return id === "p_echo_value" ? 1 + i : 2 + 2 * i; };
  const TXT = { p_echo_value: ["Echo Value", "+1 Popcorn Echo per purple popcorn collected."], p_echo_capacity: ["Resonant Field", "+2 popcorn capacity in the Echo Field per level."] };
  for (const u of AD.shop) PT.UP.set(u.id, Object.assign({}, u, { name: TXT[u.id][0], description: TXT[u.id][1], effectFn: (L) => (u.id === "p_echo_value" && PT.G ? td(u.id, L) * PT.echoValueMult(PT.G.s, L) : td(u.id, L)) }));
  { const ml = PT.maxLevel; PT.maxLevel = (s, id) => (id in MAXL ? maxL(s, id) : ml(s, id)); }
  { const ef = PT.effect; PT.effect = (s, id) => (id === "p_echo_value" ? td(id, PT.level(s, id)) * PT.echoValueMult(s, PT.level(s, id)) : ef(s, id)); } // Birb getUpgradeEffect x io
  PT.echoCapacity = (s) => (PT.echoFieldOpen(s) ? PT.effect(s, "p_echo_capacity") : 0); // Birb getMaxPopcorn(X)
})();
