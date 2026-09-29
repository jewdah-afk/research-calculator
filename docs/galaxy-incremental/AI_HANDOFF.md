# Galaxy Incremental: AI Handoff (Phase 1: Resets & Balance)

Give this file to the building AI first. It says what to read, where the code is, what to do now, and what to leave alone for later.

## What this project is

We are converting an existing, fully working Roblox incremental game ("Ascension / Stud Incremental") into **Galaxy Incremental**. The math is done. **Phase 1 focuses only on resets and balance**: making the reset layers correct, safe and presentable, and making the numbers hold up (including rune counts past 1e308). World, art, UI polish, store, codes and social features come later.

## What's in the repo

| Path | What it is |
|---|---|
| `docs/galaxy-incremental/SPEC.md` | The master spec. Phase 1 only needs **§1, §2, §3, §5.1–5.2, §7, §10, §19, §19.1, §22.1** |
| `docs/galaxy-incremental/reference/Stud_Incremental_Balance.md` | **Authoritative numbers**: every formula, cost table, reset list, rune table and upgrade config, plus known bugs and pacing sim |
| `docs/galaxy-incremental/example-render.html` | Visual reference for the reset ladder and HUD direction (open in a browser) |
| `source/place/` | **All 445 scripts** from the place file, as a Rojo-style tree (`.server.lua` / `.client.lua` / `.lua`, `init.lua` for scripts with children) |
| `source/place/_instance_tree.txt` | Every instance in the place (28,547 lines, `path<TAB>ClassName`), for finding boards, pads and UI |
| `tools/extract_rbxl.py` | Re-run this to regenerate `source/place/` from a newer `.rbxl` |

`source/place/` is a **read-only mirror**. The live game is the Studio place. Changes are made in Studio (or via Rojo once set up) and then re-extracted.

**Redeem codes were removed** (`ServerStorage/Framework/Modules/CodeData.lua` is an empty stub; the chat broadcast mentioning a code is redacted). Never write codes into this public repo.

## Read order

1. `SPEC.md` §1–§2: the rules. **The balance is solved; don't change formulas.**
2. Balance sheet → "Systems Reference §2 Prestige / resets" and "Known bugs".
3. The reset code (below).
4. `SPEC.md` §10 (reset behavior and cinematics), §19 (bug policy), §19.1 (rune overflow fix).

## Where resets and balance live

| Concern | File(s) under `source/place/` |
|---|---|
| **All formulas** (stat gains, costs, luck, bulk, speed) | `ReplicatedStorage/Framework/Shared/Modules/Formulas.lua` |
| Rune effect functions (346) | `ReplicatedStorage/Framework/Shared/Modules/RuneFormulas.lua`, `RuneInfo.lua` |
| **Reset lists** (Tier, C1–C4, Freeze, Chromatize, Chromify, Reflection, Icicles; KEEP16/KEEP19) | `ReplicatedStorage/Framework/Shared/Modules/Resets.lua` |
| Ascension One (Supernova) | `ServerStorage/Framework/Scripts/Ascensions.lua` |
| Freeze (two implementations; confirm which is live) | `ReplicatedStorage/Framework/Libraries/Upgrades/Freeze/Freeze1–9.lua` + `ServerStorage/Framework/Modules/Freeze/` |
| Reset triggers, pads, gates, generation loops | `ReplicatedStorage/Framework/Libraries/Automations.lua` |
| Cooldowns | `ReplicatedStorage/Framework/Shared/Modules/Cooldowns.lua` |
| Upgrade engine + 248 configs | `ReplicatedStorage/Framework/Libraries/Upgrades/init.lua` (+ `DOCUMENTATION.lua`, category folders) |
| Rune roll/payout + 9 packs | `ReplicatedStorage/Framework/Libraries/Runes/` |
| Special rune pools | `ReplicatedStorage/Framework/Libraries/{Global,Ancient,Madness,Ultra}Rune.lua` |
| Water/Ice multiplier buttons | `ReplicatedStorage/Framework/Libraries/MultiplierButtons/` |
| Rune Starring | `ServerStorage/Framework/Modules/runeStarring/` |
| Save schema and defaults | `ReplicatedStorage/Framework/Libraries/Datastore/Reconcile.lua` |
| Big-number library | `ReplicatedStorage/Framework/Libraries/EternityNum.lua` |
| Realm Two teleport (`Energy > 1e3003`) | `ServerScriptService/RealmHandling.server.lua` |
| Client reset UIs (boards, confirm, bars) | `ReplicatedStorage/Framework/Client/Modules/{Tier,Chromatize,Chromify,Freeze,Reflection,Icicles,Challenges}.lua`, `Client/Scripts/UI/{AscensionOne,TierBar}.lua` |

## Phase 1 task list (in order)

1. **Baseline.** Record SHA-256 hashes of the frozen modules (`SPEC.md` §20.3). Build a stat-injection test harness in Studio.
2. **Rune counts past 1e308** (`SPEC.md` §19.1, the one sanctioned engine change):
   - store runes as EternityNum strings, and migrate old numeric saves;
   - add a `RuneMath` accessor for every rune read/write/compare;
   - wrap `RuneFormulas` inputs through `RuneMath.num` (effects are capped ≤ 1e300, so balance is unchanged);
   - make the payout `Pending` queue EternityNum;
   - audit whether `Rune_Bulk` can pass 1e308, and port it if so;
   - pass the golden, overflow, migration, spend and requirement tests.
3. **Reset matrix test** (`SPEC.md` §22.1): for every reset, snapshot stats before/after and assert the diff equals the `Resets.lua` list exactly.
4. **Reset confirm sheets:** each reset shows what you gain, exactly what resets (generated from `Resets.lua`, not hand-written) and what survives (KEEP16/KEEP19). Display names come from `SPEC.md` §5.
5. **Known-bug decisions** (`SPEC.md` §19 table): list each one with its balance impact so the owner can tick fix or keep. **Fix nothing without sign-off.** The one exception is `Freeze9` costing 2 (a typo), which gets flagged loudly.
6. **Reset flow polish:** Epoch advance, Supernova, Collapse I–IX, Galaxy Formation, Reality Break, Reality Echo, Stellar Shards, Trials (`SPEC.md` §7, §10). Use simple placeholder visuals. What matters is that each is **correct, skippable and never blocks the server reset**.

## Hard rules

- Don't change formulas, costs, chances, caps, cooldowns or reset lists. §19.1 is the only exception.
- Don't rename datastore keys, `Player.Stats` / `Runes` / `Upgrades` instance names, or remote events.
- Presentation code is client-side and read-only. It never fires new remotes that change state.
- Show what the engine actually does, bugs included, until the owner decides otherwise.
- Never commit redeem codes, API keys or webhooks.

## Out of scope for Phase 1 (later)

The world rebuild, Blender/Substance art, the full UI redesign, the discovery reveal cinematics beyond basic, audio, the store, codes, gifting, leaderboards, Global Goals, social features and the full rename pass across the ~4,300 baked text labels.
