# The Milestone Tree NG+ on Roblox

A Roblox port of the web incremental game **The Milestone Tree NG+** (v2.044, by Seder3214 / loader3229, built on
The Modding Tree). The game itself is not rewritten: its JavaScript is transpiled to Luau and runs on the server for
each player, with big numbers on TowerNum. The screen is the web page's "Revamped" layout, drawn with Roblox GUI.

**To play it:** open `build/MilestoneTree.rbxlx` in Roblox Studio and press Play. For saves in Studio, turn on
*Game Settings → Security → Enable Studio Access to API Services*. Without it the game still runs, but it shows a
red "not being saved" banner.

## How it fits together

```
 web game JS (game-js/) ──port/js2lua.js──► src/server/Game/*.luau    (the game, unchanged, as Luau chunks)
                                             src/server/Runtime/       (JSRT: the JS semantics the game needs;
                                                                        BEcore: the old break_eternity's quirks)
 ServerScriptService.MilestoneTree
   Main      players, remotes, rate limits; one Actor per player (parallel Luau)
   Session   one player's game: load a save, tick like the page's 50 ms loop, buttons, screen diffs, saves
   Store     DataStore with a session lock (no two servers playing the same save)
 ServerStorage.MilestoneTreeWorker (Actor)
   Worker    runs a Session in parallel; sends screen patches; autosaves every 60 s and on leave / shutdown
 ReplicatedStorage.MilestoneTree
   Html      the game's HTML strings -> RichText (colours, sizes, glow, <hr>, the exploration map's <svg>)
   ZoneMaps  the exploration zones' background drawings
 StarterPlayerScripts.MilestoneTree
   Main      the page: menu of layers, points header, the current tab, tooltips, popups, hotkeys, export/import
   Render    view nodes -> GUI objects, updated in place from patches
   Style     the page's CSS (TMT + NG+) as GUI properties
 ReplicatedStorage.TowerNum   TowerNum 2.0.0 (with its Hyper tier)
```

What the player sees comes from `port/rbx/view.js`, which mirrors TMT's Vue components (upgrades, milestones,
buyables, clickables, challenges, achievements, grids, microtabs, infoboxes, bars) and the NG+ menu. It runs inside
the game, so it calls the game's own display functions. The server sends only what changed, keyed by each node's
path. Buttons send their action back, and the server only runs actions that are on that player's screen right now.

Everything in the web page's options works through the Options tab: Save, Hard Reset (press twice), Export (a
string the web game can import), Import (web-game saves work too), offline production, milestone display mode,
completed challenges, milestone order. Hotkeys work the same as on the web (Ctrl+E, the arrow keys and R on the
exploration grid, ...). Buyables repeat while held, as on the web page.

## Folders

| | |
|---|---|
| `default.project.json` | Rojo project (`rojo build -o build/MilestoneTree.rbxlx`, or `rojo serve`) |
| `src/` | the Roblox scripts (see above); `src/server/Game` is generated, do not edit |
| `vendor/` | TowerNum 2.0.0 + Hyper |
| `game-js/` | the web game's JavaScript, extracted from the single-file HTML build |
| `port/` | the transpiler, the build, the JS/Luau test harness (see `port/test.sh`) |
| `build/` | the built place |

## Updating the game or the port

```sh
python3 port/tools/extract_html.py milestone-tree-ng.html game-js   # a newer web build -> game-js/
cd port && npm install && node build.js                               # game-js/ -> src/server/Game/
python3 tools/zonemaps.py ../game-js/zone_svg.js ../src/shared/ZoneMaps.luau
./test.sh all                                                         # needs luau on PATH (or LUAU=...)
cd .. && rojo build default.project.json -o build/MilestoneTree.rbxlx
```

## Tests (`port/test.sh`)

The port is checked against the original JavaScript running in Node:

* **game**: 60 random saves (from the start of the game to the end) and random actions. Every value in `player` and
  `tmp` is compared between JS and Luau (447,717 values). A 150-save run with another seed was also checked.
* **view**: every tab of those saves, drawn by the view builder in both engines (803 screens).
* **decimal / strings**: 20,000 Decimal operations and 5,857 strings through `new Decimal(...)`, against the game's
  bundled break_eternity.
* **timeline**: 2,000 ticks of a deterministic bot, identical in both engines.
* **html**: every HTML string the game shows, converted to RichText and checked for well-formedness.
* **sim**: the Session at 20 ticks a second with a bot pressing on-screen buttons; save → load and export → import
  round trips.
* **roblox**: the real Roblox scripts (Main, the Actor worker, Store, Session, the client UI) on a mock engine
  (`port/tests/mock.luau`). A player joins, plays by pressing drawn buttons, leaves, rejoins and the server shuts
  down. Every remote payload is checked against what a RemoteEvent can carry.

The Roblox scripts are type-checked against the Roblox API with
`luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json` (sourcemap from `rojo sourcemap`).

What still differs from the web game, and why:

* **Float noise.** A handful of values differ in the last digits (e.g. 9604910052119.408 vs 9604904779226.307 where
  two e1,061,342,929 numbers are divided). break_eternity and TowerNum round huge exponents differently. Once in a
  while a comparison of two such values that are equal to the last digit comes out the other way.
* **States that freeze the web game.** Some broken saves send the web game into an endless loop (e.g. a NaN point
  softcap). In the port every loop is capped. The game errors out instead, and the server puts the player back on
  their last good save. NaN in the player data is handled the same way (the web page stops and asks you to refresh).
* **`tetrate` edge cases** (negative bases, 0^^x) differ from break_eternity. The game never tetrates.
* **Not ported:** the old "Tree Style" layout (only the Revamped menu layout), particles, themes, and the two
  images the web game shows (the corrupted-prestige and warning icons).

## Performance

A tick costs about 7–14 ms of Luau in the command-line interpreter at mid-game (a good part of that is the
corruption grid's own loops, which cost the web game the same). Each player's game runs in its own Actor, so
players spread over the server's cores. A session that gets expensive ticks less often, keeping each player under
about a quarter of a core (`Config.TICK_CPU_SHARE`). The game uses real elapsed time, so this only coarsens
automation, not progress. The screen refreshes 5 times a second and right after every button press. Patches
average about 0.5–1.5 KB.

## Credits

The Milestone Tree NG+ by Seder3214 and loader3229 (qq1010903229); The Modding Tree by Acamaeda; The Prestige Tree
by Jacorb and Aarex; break_eternity.js by Patashu. TowerNum's Hyper tier is a port of PowiainaNum.js (VeryrrDefine),
itself built on ExpantaNum.js (Naruyoko); see `vendor/LICENSE.luau`.
