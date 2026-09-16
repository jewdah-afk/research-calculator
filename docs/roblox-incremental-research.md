# Roblox incremental / rarity games: what's on the front page, and what source you can actually ship

Research date: **16 September 2026**. Everything below was checked against live sources on that date
(links at the bottom). Player counts move daily — re-check before you commit to a design.

---

## 1. The short answer

**There is no "fully developed, super good, open-source, front-page-ready" Roblox incremental sitting on
GitHub waiting to be cloned.** That thing does not exist, for a structural reason: the games that hit the
front page in this genre make $100k–$2M/month, so nobody open-sources one. What *does* exist, and what
this repo now contains:

| Route | What you get | Time to playable | Front-page odds |
|---|---|---|---|
| **A. Open-source Roblox projects in the right genre** | 2–3 real Rojo/Luau repos with the loop already built, placeholder art | 1–2 days | Low alone — but a legitimate skeleton |
| **B. Open-source *web* incrementals (MIT)** | World-class **math and pacing** (Antimatter Dimensions, Profectus) — not portable code | n/a (design port) | This is where the "super good and clicky" actually comes from |
| **C. Paid kits (BuiltByBit, ~$6–60)** | A whole Steal-a-Brainrot game, art included | hours | Near zero — 5,000 people bought the same kit |
| **D. This repo's `kit/`** | Original, dependency-free Luau implementation of the 2026 meta loop, procedural art, tuned to the numbers in §6 | `rojo serve` + F5 | The realistic base to build a real game on |

**Recommendation:** take route **D** as the skeleton, steal the *pacing math* from route **B**, read route
**A** for reference implementations, and buy a route-**C** kit only if you want art you'll replace anyway.
The differentiator on the front page in 2026 is not code — it's **theme + retention hooks + update
cadence**. See §7.

---

## 2. What the meta actually is right now (16 Sep 2026)

### The #1 game is literally the one you named

**Steal An Egg (and Collect Rare Pets)** — owner `Badr_Omega`, created **25 July 2026**, already
**3.37 billion visits** and **~1.7–1.8M concurrent players**, the top game on the platform. That's ~1.7M CCU
against a whole-platform live total around 10.3M tracked concurrents: one game holding a double-digit
percentage of everyone playing Roblox at that moment. Roughly **7 weeks from launch to #1.**

Its loop, precisely:

```
raid a guarded nest in a biome  →  carry the egg home (you are slow + stealable while carrying)
  →  hatch it  →  get a pet with a rarity  →  place pet on a pad  →  pet pays $/sec forever
  →  spend on upgrades  →  train SPEED on the treadmill  →  speed unlocks the next biome
  →  better biome = better eggs  →  fuse 3 duplicates into 1 higher-rarity pet  →  repeat
```

Numbers that matter: a Forest **Chicken earns $1/sec**; a Snow **Mammoth earns $42,000/sec**. That's a
**42,000×** spread across the biome ladder, with ~78 pets, rarity classes **Divine / Eternal / Secret /
Huge / Mutated**, and limited-time eggs that expire without warning (FOMO as a retention device).

### The genre it belongs to

- **Steal a Brainrot** (SpyderSammy, 2025) — the genre's origin point. Listed genre: **Idle**, but with PvP
  theft. First and only game to pass **25M CCU**; 60B+ visits. Buy brainrots → they generate cash on your
  base → other players physically walk in and steal them.
- **Grow a Garden** — first to pass 20M CCU; plant → wait → harvest → mutations/rarity.
- Everything else on the chart (Brookhaven ~514k, Blox Fruits ~295k) is an order of magnitude behind the
  steal/idle-hybrid leaders.

**The formula, stated plainly:**

> **Idle income economy + a physical PvP theft layer + a rarity chase + speed/area gating + a fuse or
> mutation sink.** Sessions are short, the return hook is "my pets earned while I was gone" plus "there's a
> limited egg up."

The theft layer is the whole innovation over 2021-era pet simulators: it converts a solo idle game into a
*social* one, generates emergent drama (and therefore TikTok clips), and gives whales something to defend
with Robux (shields, locks, auto-collect).

### What the 2026 discovery algorithm rewards

This changed and most kits haven't caught up. Per Roblox's own June 2026 discovery post and the December
2025 "Recommended For You" rework:

- **Ranking optimizes for long-term retention — return behavior**, i.e. how often players come back after
  leaving. **Not CCU, not raw session length.**
- **Trending sorts on CCU *velocity***, not absolute CCU. 500 → 5,000 in a day beats a flat 50,000.
- Friend co-play and spend behavior are strong positive signals.
- Sponsored-ad traffic retains differently from organic — track them separately or you'll misread your D1.

Design consequence: **build the game around a reason to open it tomorrow**, not around a 3-hour first
session. Dress to Impress and Fisch are the cited examples — short sessions, constant returns. Concretely:
offline earnings with a cap you hit in ~8h, a daily egg rotation, a 20-minute limited-egg window announced
in-game, and daily login streaks. All four are in the kit.

---

## 3. Route A — open-source Roblox projects in the right genre

These are real, readable, Rojo-based, and you can run them today. None is front-page-ready; all are useful
as reference implementations.

### `99millercate-arch/StealTheClout` — the closest thing to an open-source Steal-a-Brainrot
Rojo project, Luau, no Wally deps. Implements: **weighted-rarity egg hatching**, characters placed on
**income pads**, **stealing with a hold time**, **placement grace periods**, **plot shields**, **per-pad
lock levels**, DataStore persistence (pcall-wrapped), **Developer Products** (coin packs, shields) and
**Game Passes** (2× income, auto-collect, better egg odds), a client shop/protect/inventory UI, and all
tuning centralized in `GameConfig.lua` + roster in `CharacterData.lua`. Art is placeholder neon cubes.
Honest gaps the README admits: no offline earnings, no session-sticky plots, in-memory-only receipt
dedup, no production exploit mitigation. Notably it uses **original parody characters specifically to
dodge rights-of-publicity claims** — copy that instinct, see §5.

### `adit-rah/ttt` ("Tung Tung Tycoon") — a complete tycoon with **zero external assets**
Every model is **generated in code** — no toolbox assets, no uploaded meshes. Droppers, conveyors,
upgraders, vaults, plot expansion, **rebirth with multiplier payouts**, PvP limited to an arena, raid
waves, weapon/armor tiers, procedural character generation, ~53 min to complete a factory. Rojo + Luau
with Python tooling for economic simulation and static checks. The procedural-art approach is the reason
you can `rojo serve`, hit F5, and be playing in 60 seconds — the kit in this repo copies that decision.

### Also worth a look
- `gamenew09/tycoon-game` — tycoon in **roblox-ts** (TypeScript), `npm run build` produces a baked place file.
- `jason-lee88/roblox-gym-tycoon` — 2017-era, 11k plays, Rojo-exported. Dated, but a clean plot/purchase-block model.
- `cloudytein/robloxgame` — minimal Rojo skeleton where everything lives in `src/` and the place file holds nothing.

### ⚠️ What to avoid: the "Sol's RNG uncopylocked / source" trap
Search results for *"Sol's RNG source"* are dominated by repos like `venoyxikentos/Sols-RNG-Script`,
`sol-srng/.sol-s-rng-`, `Noah2509/sols-rng-roblox-toolkit`, `robloxcomphub/stealabrainrot` and pages titled
*"roblox hack: safe & secure"*, *"Auto Roll, Aura Detection, Instant Win, No Key"*. **These are exploit
clients, not game sources.** They are for cheating in someone else's game, they are frequently
malware/token-stealer bait, and running one in Studio or an executor risks your Roblox account and your
machine. Same for most YouTube/TikTok "FREE Sol's RNG Uncopylocked" links. There is no legitimate Sol's RNG
source release.

---

## 4. Route B — the open-source web incrementals worth learning from

You cannot port these to Roblox as code (JS/Vue → Luau is a rewrite). You port the **curves, the layer
structure, and the click feel** — which is exactly the part most Roblox simulators get wrong.

| Game | Source | Why it matters for you |
|---|---|---|
| **Antimatter Dimensions** | `IvarK/AntimatterDimensionsSourceCode` — **MIT**, Vue + JS | The reference implementation of *layered prestige*. Buy-10 mechanics, softcaps, and big-number handling (`break_infinity.js`) — the direct analogue of your rebirth ladder. If you read one codebase, read this one. |
| **Profectus** (`profectus-engine/Profectus`) + The Modding Tree | Open source | A whole engine for **tree-shaped prestige layers** with big-number support baked in. Best way to prototype your rebirth/skill tree *before* you build it in Luau. |
| **Exotic Matter Dimensions**, **Synergism**, **Evolve**, **Kittens Game** | GitHub, open | Long-tail pacing: what keeps players on day 30 rather than day 1. |

**What to actually take:**
1. **Cost growth ~1.12–1.20× per level** for upgrades, so every purchase is ~5–8 seconds away early and the
   ladder never feels stalled.
2. **Softcaps instead of hard walls** — multiply by `x^0.75` past a threshold rather than blocking.
3. **Prestige when income ×10 is one reset away**, not when the player is bored. Target a first rebirth
   at ~12–20 minutes.
4. **Every number on screen, always** — income/sec, time-to-next-upgrade, storage fill %. "Clicky" is
   mostly *legible feedback*, not click count.

---

## 5. Legal reality check (read before you copy anything)

- **Mechanics, loops and genres are not protected.** A steal-and-hatch idle game is as legal to make as a
  battle royale. Roblox is full of them by design.
- **Assets, code, map, UI art, names and character likenesses are protected.** Copying another creator's
  place — including "uncopylocked" re-uploads someone else posted without the owner's rights — violates
  the Roblox ToS and gets the game deleted and the account banned, especially once it's monetized. The
  original creator can and does file DMCA. Roblox's 2026 posture is *more* proactive AI content scanning,
  not less.
- **Uncopylocked ≠ free.** Only the actual owner can uncopylock. A third party's "FREE uncopylocked
  Steal a Brainrot" is stolen goods.
- **The "Italian brainrot" characters are third-party IP** with real and contested rights claims
  (Tralalero Tralala et al. have identifiable authors). Shipping those models is the single fastest way to
  eat a takedown after you've spent on ads. Do what `StealTheClout` does: **original parody characters**,
  your own names, your own silhouettes.
- Paid kits: check each listing's resale/licence terms. A kit you may publish is not automatically a kit
  you may resell or open-source.

**Net:** build the loop, not the copy. That's what the kit in this repo does.

---

## 6. What's in this repo now: `kit/` — a runnable, original Luau implementation

`kit/` is a complete, dependency-free Rojo project implementing the 2026 meta loop end to end. No toolbox
assets, no meshes, no Wally packages — **every model is built in code**, so `rojo serve` + F5 is playable
immediately, and it's all plain text your team can diff and review.

```
kit/
  default.project.json          Rojo mapping (Shared / Server / Client)
  src/shared/Config.luau        ← ALL tuning lives here: rarities, pets, biomes, upgrades, prices
  src/shared/Rarity.luau        1-in-N rolling with linear luck scaling (the Sol's-style roller)
  src/shared/Format.luau        K/M/B/T/Qa number formatting + time formatting
  src/shared/Remotes.luau       Remote creation/lookup, one place
  src/server/init.server.luau   Bootstrap
  src/server/DataService.luau   DataStore w/ retry, session lock, autosave, BindToClose, migration
  src/server/PlotService.luau   Procedural plots + pads, assignment, release
  src/server/NestService.luau   Biome nests, guarded eggs, respawn timers, speed gating
  src/server/CarryService.luau  Carrying (slow + vulnerable), drop on death, deposit
  src/server/PetService.luau    Hatch → rarity roll → pad placement → income tick → fuse 3:1
  src/server/StealService.luau  Hold-to-steal, grace period, shields, cooldowns
  src/server/ShopService.luau   Upgrades, rebirth, game passes, ProcessReceipt with persistent dedup
  src/client/init.client.luau   HUD, shop, inventory, hatch reveal, toasts
```

Implemented mechanics, mapped to the meta:

- **Rarity roll** — 1-in-N per pet, rarest first, luck divides N linearly (`oneIn / luck`), so a 2× luck
  pass is honestly 2× — no fake luck. Secret tier at 1-in-2,000,000.
- **Income spread** — Meadow common at $1/sec up to Void secret at ~$85,000/sec, i.e. the same ~5 orders of
  magnitude Steal An Egg uses, tuned so each biome is ~8–14 minutes of play.
- **Speed gating** — biomes unlock at 16 / 28 / 42 / 60 walkspeed; speed is a purchasable upgrade.
- **Theft** — ProximityPrompt hold (4s base, reduced by pad lock level), 45s placement grace, shields as a
  Robux sink, stolen pet must be physically carried home.
- **Fuse 3 → 1** — the duplicate sink, +250% income and a visual tier bump.
- **Rebirth** — +25% permanent income each, +1 pad every 3, first one reachable in ~15 minutes.
- **Retention hooks** (the §2 algorithm point): offline earnings capped at 8h, daily login streak,
  rotating limited egg with a live timer.
- **Server authority** — the client sends *intent* only; every currency and rarity decision is server-side.
  Rate limits on all remotes.

`kit/README.md` has the 5-minute setup, the Robux ID checklist, and the tuning guide.

`tools/economy-calculator.html` is a standalone page for balancing: paste your rarity table and income
curve, see expected rolls-to-secret, time-to-rebirth, and $/sec progression before you touch Studio.

---

## 7. If you actually want the front page

Code is table stakes. The three things that decide it:

1. **Theme and silhouette.** The loop is commoditized; the *skin* is not. Steal An Egg won with eggs and
   biomes 7 weeks ago. Pick a theme with (a) instantly readable thumbnails, (b) a rarity fantasy people
   want to screenshot, (c) no third-party IP. Test 6 thumbnails before you write another line of code.
2. **Update cadence.** Weekly limited eggs/pets, announced ahead of time. Every top steal-genre game ships
   weekly. This is the return-behavior signal the 2026 algorithm ranks on.
3. **Launch velocity.** Trending rewards CCU *velocity*. Budget for a coordinated launch (creators + a
   sponsored burst) so you go 500 → 5,000 in a day rather than drifting. Track sponsored vs organic
   retention separately — they are not the same players.

Realistic plan from the kit: **week 1** reskin + theme + 40 pets and thumbnails; **week 2** art pass,
sounds, juice (the "clicky" layer — hatch flash, screen shake, rarity rays, sound stacking); **week 3**
closed test with 50 players, tune D1 retention and the first-10-minutes funnel; **then** launch with a
creator push.

---

## 8. Sources

- [Roblox live charts — most played, Sep 2026](https://rblxdb.com/charts/most-played) · [Roblox official charts](https://www.roblox.com/charts)
- [Steal An Egg on Roblox](https://www.roblox.com/games/107778070777162/Steal-An-Egg) · [Rolimon's game data](https://www.rolimons.com/game/107778070777162) · [Roblox Wiki entry](https://roblox.fandom.com/wiki/And_Collect_Rare_Pets/Steal_An_Egg)
- [Steal an Egg — all eggs, pets & income rates (games.gg)](https://games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/) · [Beginner guide: the nest-to-base loop](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/) · [Mechanics explained](https://steal-an-egg-wiki.wiki/en/guides/steal-an-egg-mechanics-explained/)
- [Steal a Brainrot (Wikipedia)](https://en.wikipedia.org/wiki/Steal_a_Brainrot) · [60B visits / top charts](https://www.lootbar.com/blog/en/steal-a-brainrot-roblox-top-charts.html)
- [Roblox newsroom — Optimizing Discovery (June 2026)](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) · [Roblox Discovery docs](https://create.roblox.com/docs/en-us/discovery.md) · [What the algorithm rewards in 2026 (not CCU)](https://rowatcher.com/news/what-the-roblox-algorithm-actually-rewards-in-2026-not-ccu) · [How the discovery algorithm works in 2026 (ROLearn)](https://rolearn.dev/insights/roblox-game-discovery-algorithm-2026/)
- [StealTheClout (open source, Rojo)](https://github.com/99millercate-arch/StealTheClout) · [Tung Tung Tycoon — all models generated in code](https://github.com/adit-rah/ttt) · [tycoon-game (roblox-ts)](https://github.com/gamenew09/tycoon-game) · [roblox-gym-tycoon](https://github.com/jason-lee88/roblox-gym-tycoon)
- [Antimatter Dimensions source (MIT)](https://github.com/IvarK/AntimatterDimensionsSourceCode) · [Profectus engine](https://github.com/profectus-engine/Profectus) · [Exotic Matter Dimensions](https://github.com/alemaninc/Exotic-Matter-Dimensions) · [incremental-game topic](https://github.com/topics/incremental-game)
- [ProfileStore (data persistence)](https://madstudioroblox.github.io/ProfileStore/) · [Lyra (Paradoxum Games)](https://github.com/paradoxum-games/lyra) · [Roblox data store best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) · [Rojo](https://github.com/rojo-rbx/rojo)
- [Roblox DMCA guidelines](https://create.roblox.com/docs/production/publishing/dmca-guidelines) · [Copyright & trademark infringement overview](https://roblox.fandom.com/wiki/Roblox_Copyright_and_trademark_infringement)
- Paid kits for comparison: [Steal A Brainrot KIT](https://builtbybit.com/resources/steal-a-brainrot-kit.79703/) · [Steal an Egg and Hatch a Brainrot](https://builtbybit.com/resources/steal-an-egg-and-hatch-a-brainrot.124005/) · [Steal a Thing](https://builtbybit.com/resources/steal-a-thing.87061/)
