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

## Testing

The game logic is plain Luau and was tested outside Roblox with the standalone `luau` CLI, using small stand-ins for EternityNum and `Random`:
- a 3-hour simulated playthrough
- bulk buying with 10^5000 money (under 1ms)
- 5,000 rebirths and tier 40
- save and load round-trips

Every file compiles, but nothing has been run inside Roblox Studio yet. Expect some small fixes on first Play, most likely UI sizes and positions.
