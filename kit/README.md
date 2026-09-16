# Steal a Spark — a runnable Roblox incremental/rarity kit

An original, dependency-free implementation of the loop that owns the Roblox front page in 2026:

```
raid a nest → carry the egg home (slow + stealable) → hatch → rarity pet → pet pays $/sec
   → upgrades → speed unlocks the next biome → fuse 3 duplicates → rebirth → repeat
```

No toolbox models, no meshes, no asset ids, no Wally packages, no Roblox APIs that need configuring.
**Everything you see is built in code**, so it runs the moment you sync it — and your art pass is a
rewrite of one file (`src/shared/Build.luau`) rather than an archaeology dig through a place file.

Written to be reskinned: the game's identity lives in `src/shared/Config.luau`.

---

## Run it in 5 minutes

**With Rojo (recommended)**

```bash
# once
aftman add rojo-rbx/rojo    # or: cargo install rojo, or grab the release binary

# every session
cd kit
rojo serve
```

Then in Roblox Studio: new baseplate place → Rojo plugin → **Connect** → press **F5**. You will spawn on a
plot with four pads; walk to a nest, hold **E**, run home.

**Without Rojo:** create `ReplicatedStorage/Shared` (ModuleScripts), `ServerScriptService/Server` (a Script
named `Server` with the modules as children) and `StarterPlayer/StarterPlayerScripts/Client` (a LocalScript
named `Client` with `Reveal` as a child), then paste each file in. The Rojo path is faster.

**Studio testing note:** DataStore writes are off in Studio by default (`Config.StudioSaves = false`), so
your test profile resets each run. Set it to `true` when you want persistence, and enable *Studio Access to
API Services* in Game Settings → Security.

---

## What's implemented

| System | File | Notes |
|---|---|---|
| Weighted rarity rolling | `shared/Rarity.luau` | 1-in-N, rarest-first, luck divides N — a 2× luck pass really is 2× |
| All balance numbers | `shared/Config.luau` | rarities, 5 biomes × 6 pets, upgrades, rebirth, steal, monetisation |
| Pure economy maths | `shared/Economy.luau` | income, storage, luck, speed, offline pay, limited-egg window |
| Procedural art | `shared/Build.luau` | pets, eggs, plots, pads — every visual, generated |
| Save/load | `server/DataService.luau` | retries, **session locking**, autosave, `BindToClose`, template reconcile + migration hook |
| Plots and pads | `server/PlotService.luau` | 12 plots built at boot, leased on join, released on leave |
| Biomes and nests | `server/NestService.luau` | speed-gated entry, respawning eggs on prompts |
| Carrying | `server/CarryService.luau` | slowed while carrying, dropped on death, auto-deposits at your plot |
| Hatch / pads / income / fuse | `server/PetService.luau` | server-authoritative rolls, income tick, vault cap, 3→1 fusion |
| Theft | `server/StealService.luau` | hold-to-steal, grace period, shields, per-pad locks, thief cooldown |
| Shop / rebirth / Robux | `server/ShopService.luau` | upgrades, rebirth, game passes, `ProcessReceipt` with **persistent** dedup |
| HUD, shop, pets, toasts | `client/init.client.luau` | renders a server snapshot; holds no authority |
| The hatch moment | `client/Reveal.luau` | flash, card, camera shake scaled by rarity |

**Retention hooks** (these are what the 2026 discovery algorithm actually ranks on — see
`../docs/roblox-incremental-research.md` §2): capped offline earnings, a daily streak, a rotating
limited egg on a wall-clock cycle every server agrees on, and server-wide announcements for rare pulls.

**Verified:** every module compiles under the Luau toolchain, and the roller was distribution-tested over
400,000 rolls per luck setting — observed rates track the declared 1-in-N (e.g. a declared 1-in-700 lands at
1-in-718 at 1× luck, 1-in-138 at 5× luck). What has *not* been tested is Studio runtime behaviour: no
Roblox client ran this code, so treat the first `rojo serve` as a smoke test, not a formality.

**Anti-exploit posture:** the client sends intents only. Every currency change, rarity roll, pad
assignment and theft check happens on the server, and every remote is rate limited in
`PlayerService.rateLimit`.

---

## Reskinning it (the part that actually matters)

1. **`Config.GameName`**, then the biome and pet names in `Config.Biomes`. That's your theme.
2. **`Build.petModel`** — replace the primitive creature with your models. Nothing else in the codebase
   knows what a pet looks like.
3. **Rarity spread** — keep the shape: ~6 tiers per biome, commonest at 1-in-1, rarest ~1-in-2,000,000 for
   the chase pet. Income per pet is roughly `0.55 × oneIn^0.78`; keep the exponent and you keep the pacing.
4. **Biome gates** (`speedGate`) — each gate should be ~8–14 minutes of play away at that biome's income.
5. Use `../tools/economy-calculator.html` to check a change before you rebuild in Studio.

⚠️ **Do not ship third-party characters.** The "Italian brainrot" cast has identifiable authors and real
rights claims; shipping them is the fastest way to a takedown after you've paid for ads. Original
silhouettes, original names.

---

## Robux setup checklist

Create these on the Creator Dashboard, then paste the ids into `Config`:

- Game passes → `Config.GamePasses`: `doubleIncome`, `autoCollect`, `luckyRolls`, `vipSpeed`
- Developer products → `Config.Products`: `coinsSmall`, `coinsLarge`, `shield`, `luckBoost`

An id of `0` means "not configured" and the kit skips the feature cleanly, so you can playtest first.

---

## Known gaps (deliberate, and worth knowing before launch)

- **Data:** `DataService` is a lean, correct DataStore wrapper with session locking, but before a real
  launch I would move to [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) — same API shape,
  far more battle-tested. Swap `DataService.get/save/release` and you're done.
- **No trading.** Trading needs transactional saves (Lyra or an equivalent) or you will get duplication
  exploits. Don't bolt it on casually.
- **Art, sound and juice are placeholders.** This is the skeleton; the "clicky" polish layer (hit sounds
  stacking, particles, rarity rays, UI pops) is where the next week of work goes.
- **No spatial optimisation.** At 12 plots and ~30 nests it does not need any; if you scale the map up,
  batch the income tick and stream the biomes.
- **Prompts are default Roblox UI.** Styling them is part of the art pass.
