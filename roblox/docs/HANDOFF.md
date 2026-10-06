# Handoff: Orb Plinko (Roblox)

This doc is the starting point for anyone picking the project up. Branch: `roblox-orb-balance`.

**Live preview:** https://claude.ai/artifact/4iSV4N8pEtrJKRdYa7z8Hi. A copy is at `docs/preview.html`. Every world or UI change goes into this preview first.

## 1. Run it
- **Roblox:**
  1. Run `rojo serve` in `roblox/`.
  2. Connect from the Rojo plugin in Studio.
  3. Press Play.
- **Tests:** `LUAU=/path/to/luau bash tests/run.sh` runs 51 unit tests plus the pacing sim to tier 30.
- **In Studio:** set the `Run` attribute on `ServerScriptService/OrbServer/Dev/TestRunner`.

## 2. Where things live

| Area | Files |
|---|---|
| Economy and balance | `shared/OrbEconomy.luau`, `OrbFormulas.luau`, `Balance.luau` (bonus softcaps), `Progression.luau` (endless tiers) |
| Rarities (2000) | `shared/OrbConfig.luau` (1–50), `shared/RarityStyle.luau` (names 51+, effects by level) |
| Prestige | `shared/Prestige.luau`: Ascension (1 AP each, need ×1.1), Transcension (45 AP, ×1.25), shops |
| Starter Runes | `shared/Runes.luau`, `client/World/RuneAltarUI.luau`, `docs/RUNES.md` |
| World | `server/World/MapBuilder.luau` (plaza, fence, sky, board, stands), `shared/MegaBoard.luau` (board geometry and physics constants) |
| Shared board | `client/World/MegaBoardClient.luau`: your orbs are fully simulated; other players' orbs are ghosts that collide only with pegs; rendering is pooled with `BulkMoveTo` |
| Progressive reveal | `shared/Unlocks.luau`, `client/World/Stands.luau` (hidden → ??? → open) |
| Backend | `server/Services/*` (DataService session locks, Events, Leaderboards, Admin) |
| UI style | `docs/UI_STYLE.md` (tokens, components, stat colours, the zoomed-in corrections) |
| Icons | `art/`: run `make_icons.py` (Blender), then `vectorize.py` for flat tones and the black outline |

## 3. UI rules (short version)
- **Windows:**
  - black 4px frame
  - studded header with brush slashes and a dark bottom lip
  - round bold title (white → grey) with a heavy outline
  - red studded X close button
- **Cards:** double border (black outside, grey rim inside) with the diamond lattice.
- **Colours:**
  - green buttons mean "spend"
  - one colour per stat: luck green, bulk red, speed blue, clone yellow, tickrate purple
  - rune rows are tinted with the rune's own colour
- **Upgrade labels:** always "current → next", for example `x1.00 [➜] x1.08`. The arrow is a green chip. At max level it shows the value plus a `MAX` pill.
- **Icons:** front-on, flat 3–4 tone vector shading, one white highlight, thick black outline with a drop.

## 4. Still to do
1. **Roblox HUD:** restyle `client/Main.client.luau` and `UI/Kit.luau` to match the preview (`docs/UI_STYLE.md`).
2. **Icon uploads:** upload `art/icons/*.png` as Decals and put their ids in `client/UI/Assets.luau`.
3. **Auto-Roll pass:** set `Runes.AUTO_PASS_ID` to the gamepass id.
4. **Pacing sim:** add runes and prestige to `tests/PacingSim.luau`.
5. **Studio playtest:**
   - which way the altar panels face
   - Mega Board physics feel
   - performance with 12+ players
6. **HTML demo:** the older Orb Plaza HTML demo is out of date and can be retired.
