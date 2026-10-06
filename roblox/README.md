# Orb Game (Roblox) – full playable build

A complete 2D GUI plinko/rarity idle game in Luau. The server owns all game state and the client simulates the board.

- **Progression is endless.** After the 50 hand-tuned rarities come 450 generated ones (more are one constant away). After the 4 hand-tuned tiers, requirements are generated forever.
- **Rebirths and skill points never cap.** Rebirths, skill-tree multipliers and TP sources all scale indefinitely.
- **Numbers never overflow.** Luck and rarity odds are stored as log10. Money, gems and costs use EternityNum through `Big`.

## Files

```
roblox/
  default.project.json          Rojo project (maps src/ into the DataModel)
  src/shared/   -> ReplicatedStorage.Shared
    OrbConfig.luau              every balance number (hand-tuned tables)
    Progression.luau            endless rarities + endless tier requirements
    OrbFormulas.luau            pure math (luck in log10, payouts, costs, bulk-buy maths, formatting)
    OrbEconomy.luau             player data + every action, save serialize/deserialize
    Big.luau                    EternityNum wrapper
    Remotes.luau                remote names/creation
    (EternityNum)               <- YOU ADD THIS ModuleScript here
  src/server/   -> ServerScriptService.OrbServer
    GameServer.server.luau      DataStore, spawn loops, orb validation, action whitelist, state sync
  src/client/   -> StarterPlayerScripts.OrbClient
    Main.client.luau            HUD (Figma layout), screens, toasts, server wiring
    Board.luau                  2D physics plinko board (per-tier layouts)
    ParallaxBackground.client.luau  animated 7-layer background
    UI/Kit.luau                 Figma style rebuilt with UIStroke/UICorner/UIGradient
    UI/Assets.luau              <- paste uploaded image asset ids here
    UI/SkillText.luau           skill names/descriptions
  art/icons/                    Blender icon renderer + rendered PNGs (out/)
```

## Setup when you're home

1. **Rojo:** install the Rojo plugin in Studio, then run `rojo serve` in `roblox/` and connect.
   Without Rojo, recreate the tree from `default.project.json` by hand: a `Shared` folder of ModuleScripts in ReplicatedStorage, `OrbServer` in ServerScriptService, and `OrbClient` in StarterPlayerScripts. Files ending `.server.luau` become Scripts, `.client.luau` become LocalScripts, and everything else becomes ModuleScripts.
2. **EternityNum:** put the EternityNum ModuleScript in `ReplicatedStorage.Shared` and name it `EternityNum`.
   `Big.luau` uses `add/sub/mul/div/pow/me/meeq/le/leeq/short/toString`. It also uses `log10/floor/toNumber/fromString/convert` if your version has them, and falls back to its own versions otherwise.
3. **Game Settings → Security:** turn on *Enable Studio Access to API Services* so DataStores work in Studio.
4. **Images:** upload `art/icons/out/*.png`, and the Figma textures and background layers if you want them, then paste the ids into `src/client/UI/Assets.luau` and `ParallaxBackground.client.luau`.
   Until you do, the UI shows glyph tiles and plain colours, so the game is fully playable with 0 ids.
5. Press Play.

## How it runs

- **Spawning:** each spawner's timer runs on the server (`spawnIntervals`). The server rolls the orb (`Economy.rollSpawn`) and sends `{id, kind, rarity, variant}` to the client.
- **Board:** the client drops the orb on its board (`Board.luau`, 400×600 logical px, 120 Hz fixed-step physics). When the orb reaches the bottom or a tier-3 pocket, the client reports `{id, x}`.
- **Payout:** the server checks that the orb id is pending and that at least 0.4s has passed since it spawned. It then pays out using the slot multiplier at `x`. Payouts are never trusted from the client.
- **Actions:** every button calls `Action:InvokeServer(name, ...)`. The server whitelists each action, checks argument types, and rate-limits to 40 actions a second. After any change the server pushes the full state, at most 5 times a second.
- **Saving:** on leave, on shutdown, and every 60s. Big values are saved as strings, and new fields default safely when loading old saves.

## Original game balance kept as-is

- The upgrade, spawner, boost, weather, mechanic-unlock, rebirth, tier 1–4, skill-tree, automation and TP/QP numbers are unchanged. All of them live in `OrbConfig.luau`.
- The original game's quirks are kept: weather money and MN-5 don't apply to orb payouts, the tier bonus on diamonds is added rather than multiplied, and only 9 of the 10 weathers can be unlocked.

## Changes for endless play (all easy to tune)

| What | Where | Why |
|---|---|---|
| Rarities 51–500 are generated: odds grow +2.5 orders of magnitude per step (slowly accelerating), value +2.0 per step | `Progression.luau` (`GENERATED`, growth constants) | endless rarity chase |
| Tiers 5+ need rarity `38 + 5n`, count `25 × 1.5^n` (n capped at 20) | `Progression.tierRequirement` | endless tiers |
| Luck, spawner luck and gem luck stored as log10 | `OrbFormulas`, `OrbEconomy` | luck never overflows |
| Diamond chance upgrade caps at 25% | `F.DIAMOND_CHANCE_CAP` | otherwise every drop eventually becomes a diamond |
| Automation interval floors at 0.5s | `F.MIN_AUTOMATION_SECONDS` | stops it running every frame |
| Max-buy buys in bulk using a closed-form geometric sum | `F.affordableLevels` / `F.geometricSum` | instant at any money amount |
| Board is 400×600 instead of 400×800; tier-3 pockets moved to match | `OrbConfig.Board`, `Board.luau` layouts | fits the HUD |

## Adding content later

- **New upgrade:** add numbers to `OrbConfig`, an action in `OrbEconomy`, a whitelist entry in `GameServer.server.luau` (`ACTIONS`), and a button in `Main.client.luau` that calls `act("name", ...)`.
- **New skill:** add it to `OrbConfig.SkillTree` and `UI/SkillText.luau`, then read it anywhere with `F.skill(data, "ID")`.
- **More rarities:** raise `GENERATED` in `Progression.luau`.
- **New board for a tier:** add a `LAYOUTS[n]` entry in `Board.luau` and `OrbConfig.Tiers.Slots[n]`, and raise `Tiers.Max`.

## Infinite-play design (read this before adding features)

1. **Core vs bonus.** Core progression is upgrades, rebirths, tiers, the rarity bonus and the skill tree, and it applies in full. Everything else is a **bonus source** registered in `Balance.luau`: weather, storm levels, admin events, and any future feature or gamepass. Bonuses are summed per stat (cash, luck and gems), then soft-capped against a budget that scales with the player's own core progress. A new feature can speed players up by a bounded amount but can never leapfrog the curve.
   ```lua
   -- adding a feature that boosts luck:
   Balance.register("pets", "luck", function(data, ctx) return petLuckLog10(data) end)
   ```
2. **Relative tiers.**
   - Tiers 1–4 are the original fixed requirements.
   - From tier 5 on, each tier asks for 10 orbs at a rarity a set distance beyond the luck you had at your last tier-up (max of 5 orders of magnitude or a share of that luck that eases off), collected since that tier.
   - The target follows real progress, so it can't wall and can't be trivialised, whatever future content does to growth speed.
   - There's also a minimum time per tier: 10 minutes, plus 0.5 per tier, up to 60, shown as a countdown.
3. **Endless sinks.** Rarities are generated to #2000, and you can raise `GENERATED` freely. Rebirths, storm levels, skill multipliers and TP sources never cap.
4. **Big numbers.** Luck and odds are log10 numbers; money and gems are EternityNum. Nothing overflows.
5. **The pacing simulator is the guard.** After any balance change, run `tests/run.sh 100`. It fails if any tier from 6 on takes under 9.5 or over 300 minutes for the greedy bot.

## The forever formulas (all in log10)

| Quantity | Formula |
|---|---|
| Rarity odds, k > 50 | `odds(k) = odds(k-1) + 2.5 + 0.02(k-50)` |
| Rarity value, k > 50 | `value(k) = value(k-1) + 0.8 · (2.5 + 0.02(k-50))` (value is a fixed 0.8 share of each odds step) |
| Luck | `0.301·rebirths + 0.477·tiers + 0.0792·luckLevels + 0.0414·gemLuckLevels + skills + budgeted bonuses` |
| Cash multiplier | `0.0607·cashLevels + 0.301·tiers + 0.0253·rarityBonus·best + skills + budgeted bonuses` |
| Rebirth cost | `log(4000) + min(r,25)·log(3.5) + max(r−25,0)·log(lateScale)`. The web build uses lateScale 2.5; Roblox keeps 3.5 because tiers supply growth. |
| Next tier (5+) | `max(previous + 1.5, luckAtTier + max(5, 0.15·luck/(1+n/30)))`, 10 orbs, plus a minimum time of 10 + 0.5n minutes (max 60) |

**Why it never stalls:**
- A player's money per run settles at about 0.8 × luck, because rarity value is 0.8 × odds.
- Cash and luck upgrades bought with that money then feed back into both.
- That gives about 0.457 orders of money per rebirth.
- So any rebirth cost slope below 0.457 per rebirth (2.86× each) is reachable forever. The web build's 2.5× has margin.
- In Roblox, each tier adds a permanent ×2 cash and ×3 luck on top. Relative tiers keep that from snowballing.

**Verified by the pacing sim:**
- **Web build:** time per rebirth settles at 1.5–4 minutes through 3,600+ rebirths.
- **Roblox build:** tiers 1–150 never wall. Late tiers sit at the 60-minute floor, and the bot is at rarity #553 of 2,000 at tier 150.

## Prestige layers (Ascension → Transcension → …)

`shared/Prestige.luau` defines the layers as data. Adding one is a new entry in `LAYERS`; if it should magnify something new, add a line in `gainMult`.

Each layer works like a tier: one prestige gives exactly **1 point** (times magnifiers from the layer above), and the requirement climbs ×growth every time.

| Layer | Requirement for the next one | Passive (lifetime points) | Resets |
|---|---|---|---|
| Ascension | 250 × 1.1^ascensions rebirths (250, 275, 303, 333, …) | +0.1× rebirths per click per AP (stacks with bulk rebirth) | cash, upgrades, spawners, gems, rebirths (keeps tiers) |
| Transcension | 45 × 1.25^transcensions lifetime AP (~same rebirth effort as the old curve) | +0.25× AP per ascension per TrP | everything above, plus tiers and Ascension (TP trees refunded) |

- **Shops:** the first level of the opening upgrades costs 1 point. After that, each line scales differently: `exp` (cost·g^lv), `lin` (cost + step·lv) or `soft` (cost·(1+lv)^g).
  - **Ascension:**
    - Momentum (×5 cash, ×3 luck; soft): the first point you buy gets the run rebuilt fast.
    - Ascended Luck (×2; linear)
    - Ascended Cash (×10; exponential)
    - Rebirth Echo
    - Head Start
    - Gem Vein
    - Rebirth Memory (keep 5% of rebirths per level, max 25%)
  - **Transcension:** AP Surge, Eternal Luck, Eternal Cash.
- **Performance:** shop effects are summed once and cached per player, using a fingerprint of their levels. The economy reads them every frame at no cost, so adding more upgrades doesn't add lag.
- **Passives use lifetime points,** so spending in a shop never weakens them.
- **Prestige effects count as core progression,** not capped bonuses.

## The world (Mega Board plaza)

`server/World/MapBuilder.luau` builds the plaza once at server start:

- A 512×512 grid baseplate, fenced with stone walls and pillars. Trees, rocks and hills sit outside the fence.
- **The Mega Board** at the north end: 440 × 286 studs, leaning back 12°. It has pegs, gold bumpers and slot dividers. Geometry lives in `shared/MegaBoard.luau`.
- **Upgrade stands** down the path, in unlock order:
  - Cash → Gems → Spawners → Rebirth → Skills & Tier → Storm → Ascension → Transcension
  - Each stand has a proximity prompt that opens its panel. Walking away closes it.

**Progressive reveal** (`shared/Unlocks.luau`, `client/World/Stands.luau`):

- A new player sees only the board.
- Each stand goes from **hidden** to a **black "???" silhouette** when you're close, then **pops in** when unlocked. Ascension appears 10 rebirths early; Transcension appears 5 AP early.
- Once open, a stand stays open: this is saved in `data.unlocked`.
- HUD buttons (dock, gems chip, prestige) follow the same states.

**Shared board without collisions or lag** (`client/World/MegaBoardClient.luau`):

- **Your orbs:** full physics against the pegs and your own orbs. They still decide your payout, and the server validates them as before.
- **Other players' orbs ("ghosts"):** every 0.25s the server relays a sample: up to 6 per player, plus every rare. Each client simulates them against pegs only, so they never touch your orbs. They're capped at 120 on screen.
- **Rendering:** orbs are pooled anchored parts with collision, query, touch and shadows off. All of them move with a single `BulkMoveTo` per frame. Peg checks use grid buckets, so each orb tests only the 2–4 pegs near it.
- **Rare drops:** at least 1/10,000, and within 2 of the player's best rarity. They get a server-wide toast (at most one per player per 15s), a name tag above the orb, a neon glow, and a particle burst where they land.
- **Slot multipliers:** each player sees their own multipliers (from their tier) on the slot panels.

## Rarities: names and effects

- **Names:** 1–50 are hand-named and climb from everyday things to the cosmic: Pebble → Marble → … → Phoenix → … → Black Hole → … → The Absolute. Rarities 51–2000 get unique generated titles such as "Shattered Crown", "Citadel of the Deep" or "The Cursed Dream" (`shared/RarityStyle.luau`).
- **Effect level:** every rarity has an `fx` table. The level goes up every 5 rarities until #50, then every 130 rarities until #2000, and each level adds something:

  | Levels | Effect added |
  |---|---|
  | 0–3 | plain → polished glass → glow → three-colour gradient |
  | 4–6 | sparkles → neon core → comet trail |
  | 7–9 | rings → aura → pulse |
  | 10–12 | orbiting moons → rainbow → two rings |
  | 13–15 | lightning → supercharged → starburst |
  | 16–24 | triple rings → outline → event horizon (dark core, blazing rim) → … → "Singular" |

  Effects never get weaker as rarity climbs; unit tests check this.
- **Performance:** full effects go on 24 orbs at a time. Outlines use Highlight, which is capped at 8.

## Mega Board payouts

The board is a 16-row Plinko pyramid with guide rails. Orbs drop from the top centre, bounce off low-restitution pegs with sideways damping, and settle into a bell curve. Over 200k simulated drops:

| Slot (from centre) | x0.8 | x1 | x1.5 | x2 | x3 | x5 | x10 | x20 | x40 | **x100** |
|---|---|---|---|---|---|---|---|---|---|---|
| Chance | 58% | 20% | 12% | 3.4% | 2.4% | 2.2% | 1% | 0.5% | 0.13% | **~1/6,000** |

- **Average payout:** about x1.37, which matches the x1.4 average the economy and pacing sim are tuned on.
- **Later tiers:** the same strip pays more, ×1.3 / ×1.4 / ×2.2, matching the old per-tier boards. Tier 3 or higher pays x220 on the edge.
- **Orbs are 40% of their old size** on the Mega Board.

## Systems

| System | Where | Notes |
|---|---|---|
| Saving | `server/Services/DataService.luau` | Session locking through UpdateAsync, so two servers can never write the same player. Retries with backoff, versioned migrations (`Economy.MIGRATIONS`), and a daily backup in `OrbGame_backup_v1`. |
| Game loop | `server/Services/GameService.luau` | Spawners, orb validation, the action whitelist (`GameService.ACTIONS`; add new actions here), autosave every 60s, and the tutorial. |
| Events | `shared/Events.luau`, `server/Services/EventService.luau` | Admin-dropped global events, synced to every server through MessagingService and a DataStore. Dropping the same type again extends it instead of stacking. Events are capped at 24h each, and "frenzy" spawn speed at 2×. |
| Admin | `server/Services/AdminService.luau` | **Edit `USER_IDS` / `GROUP_ID`.** The place owner is always an admin. The in-game ADMIN button only appears for admins, and every command is re-checked on the server. Announcements go through Roblox's text filter. |
| Leaderboards | `server/Services/LeaderboardService.luau` | Global boards for total cash, tiers, rebirths and best rarity, refreshed every 2 minutes, plus player-list leaderstats. Cash is stored as log10 × 100 to fit OrderedDataStore integers. |
| Tutorial | `shared/Tutorial.luau` | 7 steps. The server advances them only when the real action happens, so they can't be faked. The client highlights the target panel, and players can skip. Existing players skip it automatically through a migration. |
| QA | `tests/` | 27 unit tests plus the pacing sim. Run them from the command line with `tests/run.sh`, or in Studio with `ServerScriptService.OrbServer.Dev.TestRunner` and its attribute `Run=true`. |

## Testing

```
LUAU=/path/to/luau ./tests/run.sh 100     # unit tests + 100-tier pacing simulation
```
The latest run: 27/27 unit tests passed. The pacing sim reached tier 100 in about 107h of game time; after the original tiers, generated tiers take 14–38 minutes each and stretch slowly.

The code compiles and the logic is tested from the command line, but nothing has run inside Studio yet. Things only Studio can exercise are untested: DataStore, MessagingService, the UI layout and the board physics feel. Expect small fixes on first Play.
