# Onslaught 2 for Roblox

This is the Roblox build of the Onslaught 2.2 remake. It is a Rojo project.

- **Classic** plays the original game 1:1.
- **Onslaught+** adds the expansion: new towers, combos, research, and passes and products.
- Up to 4 players can play together.

The simulation is the same code as the HTML prototype (`../onslaught-html`), ported line for line. Tests check that both versions produce the same numbers, bit for bit.

## Layout
| Path | What it is |
|---|---|
| `src/shared/Onslaught/Engine.luau` | The game, 1:1 with Onslaught 2.2. Spec: `../onslaught-data/MECHANICS.md`. Pure Luau, with fixed 1 ms steps. |
| `src/shared/Onslaught/Expansion.luau` | Onslaught+: the new towers and combos, the products, and account progression. Design notes: `../onslaught-data/DESIGN.md`. |
| `src/shared/Onslaught/Data.luau`, `ExpansionData.luau` | Generated from `../onslaught-data/*.json` by `tools/gen_data.py`. Don't edit them by hand. |
| `src/shared/Onslaught/EternityNum.luau` | Numbers bigger than a double can hold (see the EternityNum section below). |
| `src/shared/Snapshot.luau` | Server → client state, packed into buffers. A snapshot is about 300 bytes, sent 15 times a second. |
| `src/shared/Net.luau` | Remotes, plus the list of in-match actions and their argument types. |
| `src/shared/Rules.luau` | Mode unlocks, end-of-game rewards, and daily quests. |
| `src/shared/Config.luau` | **Game pass and product ids go here**, along with other tuning values. |
| `src/server/Match.luau` | One run. Steps the engine, validates every action, and handles co-op ownership, host controls, Commander Tools and the revive window. |
| `src/server/MatchService.luau` | Connects a Match to remotes, Heartbeat, players, rewards and in-match products. |
| `src/server/PartyService.luau` | The lobby: parties of 1–4, starting runs on reserved servers, and all lobby requests. |
| `src/server/Profiles.luau` | DataStore profiles with a session lock. Lifetime totals are stored as EternityNum. |
| `src/server/Monetization.luau` | Game passes, and an idempotent `ProcessReceipt`. In-match products that arrive too late become credits. |
| `src/server/Leaderboards.luau` | OrderedDataStore boards: Classic best wave, Onslaught+ best wave (unassisted runs only), and lifetime kills. |
| `src/client/Board.luau` | The 3D top-down board: map, turrets, attackers, shots and effects. Uses pooled parts and 100 ms interpolation. |
| `src/client/MatchUI.luau` | The match HUD, build palette, turret panel, menus, end screen and input. |
| `src/client/LobbyUI.luau` | Play (mode, map, parties), Research, Quests, Store, Leaderboards and Profile. |

## Build and run
1. Install the tools with [rokit](https://github.com/rojo-rbx/rokit): `rokit install`. This installs rojo 7.5.1, selene and lune.
2. Run `rojo serve` and connect from the Rojo plugin in Studio. Or run `rojo build -o Onslaught.rbxl` and open the file.
3. In Studio, turn on Game Settings → Security → **Enable Studio Access to API Services**, so DataStores work.
4. Press Play.
   - In Studio, every pass counts as owned (`Config.STUDIO_OWNS_ALL_PASSES`).
   - **Play solo** and **Start** run the match in the same server, because Studio has no reserved servers.

To try co-op in Studio, use Test → Clients and Servers → 2 players. One player creates a party, the other presses **Join**, and the leader presses **Start**.

## Publishing checklist
1. Publish the place.
2. On the Creator Dashboard, create the 10 game passes and 16 developer products. Their names and prices are in `../onslaught-data/DESIGN.md`. Second Chance is three products: 99, 199 and 399 R$.
3. Paste the ids into `Config.PASS_IDS` and `Config.PRODUCT_IDS`.
   - An id of 0 shows the item in the store, marked "not on sale yet".
4. Set **Max Players** for the place. Public servers are lobbies, and runs go to reserved servers that hold one party each. A lobby size of 12–20 is a good start.
5. In live games, public servers are lobbies. A run starts with `TeleportService:ReserveServer`. The run settings go to a MemoryStore map keyed by the reserved server's `PrivateServerId`, so a client can't forge them.

## How it plays the same as the original
- The engine steps in 1 ms ticks and uses the original timers: turrets every 70 ms, the spawner every 200 ms, tweens every 32 ms, and so on.
- It keeps the original's quirks, all listed in `MECHANICS.md`.
- `test/parity/` runs 46 scripted games through the JS engine and the Luau engine with the same seed and compares 500 ms checkpoints exactly. The games cover:
  - all 20 combos and Combonly
  - challenges
  - co-op
  - the bot playing to wave 40
  - every Onslaught+ tower and combo
  - products
- Trig is computed by the engine itself (fdlibm kernels using only `+ − × ÷`). Normally `math.sin` and `math.atan2` can differ by one bit between platforms, and that difference would grow over a game.

## EternityNum
EternityNum is for **range**, not speed.

- **The simulation uses plain doubles.** The original game used doubles, so this is what keeps it 1:1, and doubles are the fastest number type in Luau.
- **Lifetime totals use EternityNum:** kills, XP and bounty. They only ever grow, so they can pass 2^53 and even 1e308 without breaking.
  - They are saved as lossless strings (`EN.toString` / `EN.fromSave`).
  - They are ranked with `EN.lbencode`, an order-preserving number for OrderedDataStore.
  - They are shown with `EN.short`.
- The HUD switches to `EN.short` above 1e15.
- Speed comes from:
  - running the engine at fixed steps on the server (about 420× realtime in Lune, so 5× speed costs about 1% of a core)
  - binary snapshots
  - pooled parts on the client

## Tests
`test/run_all.sh` runs everything below. It needs node and lune, plus rojo for the last step.

| Test | What it checks |
|---|---|
| `../onslaught-html/test/*.js` | The HTML engine (65) and the expansion (39). |
| `test/expansion_test.luau` | The Luau expansion (31), including XP, research and quest results matched against the JS. |
| `test/unit/match_test.luau` | Action validation, ownership, host controls, rate limits, Commander Tools and the revive window (37). |
| `test/unit/rules_test.luau` | Mode locks, rewards, unlocks, EternityNum totals and quest rerolls (24). |
| `test/unit/snapshot_test.luau` | Buffer round trips on a real game. |
| `test/parity/` | Bit-exact JS ↔ Luau games (46). |
| `test/roblox/smoke.luau` | Plays the **built place** headless (36 checks; details below). |

`test/roblox/smoke.luau` runs in `runtime.luau`, which is built on Lune's `@lune/roblox`. Property names and types are checked against Roblox's API, and the server and each client run as separate "machines" connected by remotes. The test plays:
1. lobby
2. party of two
3. Classic match: build by clicking, hotkeys, upgrades, ownership rules, speed, losing, the end screen, back to lobby
4. Onslaught+ solo run
5. receipts: applied once, and a late purchase turning into a credit

To see the screens, run `lune run test/roblox/smoke.luau build.rbxl <dir>`, then open `test/roblox/render.html?f=match.json` from that directory. This renders the exported GUI tree and parts. It is a layout preview, not Roblox's renderer.

## Not done yet (next steps)
- Sound effects, and the original music.
- Mobile layout. It scales, but the side panel isn't a bottom sheet yet.
- VIP chat tag. The `VIP` attribute is set; it needs a TextChatService hook.
- The Retro skin is the default look with flat materials. It isn't the original 2008 sprites yet.
- Test in Studio and on real servers. Everything above was verified headless.
