# Peckwood: Figma UI cleanup handout (next chat)

Written 2026-10-09 when the owner paused. The goal of the next chat: **make the Figma UI source clean, so every
window re-imports into the game with no code patches**, then finish the missing screens. The game side already
works. This is about fixing the *source* in Figma so later imports come out right.

---

## Paste this into a new chat

The full copy-paste prompt is in **`FIGMA_UI_NEXT_PROMPT.txt`** (plain text, no markdown symbols, safe to copy on a phone). Short version:

> Continue Peckwood (Roblox, Birb remake). Repo `~/Downloads/rc-main`, branch `claude/peckwood-isle`
> (`git fetch && git checkout claude/peckwood-isle && git pull`). Read `FIGMA_UI_NEXT.md` (this file) first, then
> `HANDOUT.md` section A ("INTEGRATED" + "In-game UI from Figma"). Figma file `SQOJ2gzGt12vFMGGlNRWBE`, page
> **UI v2** = node `7:7` (Figma MCP: `use_figma`, `get_screenshot`, `get_metadata`). Job: do the Figma fix list
> below in order, re-export each fixed frame into the game with the exporter pipeline, QA it in Studio (one Studio
> window only), and screenshot every window to me as it lands. Don't touch the game mechanics branch
> (`claude/peckwood-mech`, paused mid Phase 2).

---

## 1. Where everything is

| What | Where |
|---|---|
| Figma file | `SQOJ2gzGt12vFMGGlNRWBE`, page **UI v2** `7:7` |
| HUD board | `213:7` (screen mock with everything placed: `229:7`) |
| Windows board | `239:307` (every window frame) |
| Figma helper kit (build recipes) | `docs/figma/kit.js` (WINDOW, TABS, STEEL, WELL, KEY, BTN, PRESS, CHIP, BAR, T, BODY, ICO, GLYPH, CHEVRONS, SPEC, OUTLINE) |
| Agent brief + style rules | `docs/figma/WINDOW_BRIEF.md` |
| Birb parity list | `FIGMA_INVENTORY.md`, Birb screenshots in `playtest/parity/birb_ui/` |
| Exporter (Figma → game) | `roblox/tools/figma_export/` (`exporter.js`, `collect.py`, `build_layouts.py`, `roots.json`) |
| Generated layouts | `roblox/src/client/UI/Figma/Layouts/*.luau` (one per frame, node id in the header) |
| Renderer | `roblox/src/client/UI/Figma/Render.luau` |
| Code-built windows (no Figma frame yet) | `roblox/src/client/UI/Screens.luau` via `UI/Figma/FKit.luau` (Luau port of kit.js) |
| Frame → window map | `roblox/src/client/UI/WindowDefs.luau` |
| Runtime patches that SHOULD move into Figma | `Render.cleanHeaderEdge` (Render.luau ~line 446), `UI/LayoutPatches.luau` |

---

## 2. Locked style rules (owner decisions, don't change)

- Squared UI = HUD v3 layout + square-top windows.
- Every key uses the game's Kit.button recipe; the **COMPANIONS header** is the shading reference.
- Pressed key = the whole key drops by the lip depth; no black band above the face.
- **Continuous 4 px ink window outline**, running over the header. 5 px was "too thick".
- Close key = 44 px red key at **(W-54, 10)**; never move it.
- **All text Fredoka One.** Body text = 1.2 outline + 1 px drop.
- Cost chips = steel mini plates.
- Glyphs are centred drawn icons, never typed characters.
- Tree connector lines: **all ink first, all colour on top**.
- Stripes = the seamless texture (12.8 px period, uploaded as `ui/stripes`).
- Icons are glossy 3D renders (flat/SVG icons rejected). All 992 icons are uploaded (`shared/Icons.luau`).
- Zero clipping. One black outline only, no coloured rim or glow. QA every window zoomed in.
- Visual hierarchy: one primary key per window (strongest colour and size), secondary keys steel and quieter, numbers
  read before labels.

---

## 3. How Figma becomes game UI (read before editing anything)

The game rebuilds each Figma frame **node for node** from an exported layer tree, so layer names and structure
matter:

1. `exporter.js` (READ-ONLY `use_figma` script): replace `__ROOT__` with a frame's node id and `__PART__` with 0, 1, 2…
   Each call returns one 19 KB slice of the frame's tree.
2. `python roblox/tools/figma_export/collect.py <claude session dir>` reassembles the slices from the session
   transcripts.
3. `python roblox/tools/figma_export/build_layouts.py` writes `UI/Figma/Layouts/<Module>.luau`. Frame ids and
   module names are in `roots.json`; add new frames there.
4. Sync to Studio and QA (section 6).

**Layer-name contract (the renderer finds things by name; keep these exact):**
- `header` (with children `depth band`, `bevel`, `ink`), `window outline`, `btn/close`.
- Tabs: `tab/<LABEL>` and `tab/<LABEL> (active)`; segmented switches: `seg/<LABEL>`.
- Keys: `btn/<action>` (buy, max, molt, feed, hold to feed, evolve, craft, claim, hatch, breed, fuse, donate, …).
  A keycap = `ink body` + `face` (+ `lip`).
- Icons: `ico/<name>`, which must match a name in `shared/Icons.luau`. Glyphs: `glyph/<name>`.
- Textures: `tex/…` fills using `ui/stripes`, `ui/lattice`, `ui/halftone`, `ui/sparkle`, `ui/shadow`, `ui/softellipse`.
- Rows / lists are cloned from the first row template, so keep one clean template row per list.

**What the importer can't reproduce (design around it):**
- Header "swoosh" **vector shapes** are dropped. Use rectangles / gradients, or an uploaded image.
- **Radial / conical gradients** become a soft ellipse; the Upgraded UIGradients beta can't publish yet. Prefer linear.
- **Letter spacing** is ignored (Roblox has none). Don't rely on it for fit.
- Rotated gradient strips inside clipping frames are converted approximately. Keep sweeps axis-aligned when possible.
- Images taller than ~2048 px don't render.

---

## 4. Fix list (in order)

### A. Window header bottom edge (owner flagged it twice)
**Problem:** under every window header there's a light streak line: the `bevel` gradient strip that fades out
mid-way, plus a 12 px `depth band`. In game it reads as a broken line. Today the game hides it with a runtime patch
(`Render.cleanHeaderEdge`: removes the bevel's gradients and draws a 1.5 px highlight over a 4 px ink line). The
owner still sees a line (e.g. on PROFILE), and the patch shouldn't be needed.

**Fix in Figma, on every window header and in the kit.js `WINDOW()` recipe:**
- The header ends in ONE clean edge: a full-width **4 px ink line**, continuous with the 4 px window outline.
- At most ONE uniform highlight above it (1–2 px, a single solid colour at fixed opacity, full width).
- No partial / fading gradient strips and no separate depth band that stops short.
- Check every theme: blue, gold, red, purple, green, brown, and the sidebar SHOP header.
- Fix the source header the code-built windows clone (FKit copies the Mine header; see FKit.luau ~line 169).

**Then:** re-export every window, delete `Render.cleanHeaderEdge` and its call, and QA that no header has a line.

### B. Move the other runtime patches into Figma
- `UI/LayoutPatches.luau` adds Birb features the frames don't have yet. Add each one to its Figma frame properly, then
  delete the patch.
- The rows' `(buy)` / `(can)` / `(cannot afford)` variants: the state is now an attribute in code. In Figma, name
  the keys only `btn/buy` / `btn/max`.

### C. Missing squared Figma frames (today code-built in Screens.luau)
Design these as proper square-top windows on the Windows board, add them to `roots.json` and `WindowDefs.luau`, and
replace the code-built versions:
- Profile, Settings, Leaderboards (one window with 3 tabs)
- Fast Travel (compact popup above its icon key)
- Welcome back (offline earnings, 8 h cap)
- (The dev Sound Board can stay code-built.)

### D. Birb features still missing from frames
- Parrot UPGRADE: spend slider + typed amount
- Parrot header: PARROT CAM toggle
- Objectives: a GOALS (suggestions) tab
- Window headers: a "?" help key and a settings gear where Birb has them
- Locked-tab states (dimmed tab + padlock) for tabs that open later

### E. Smaller polish found in Studio QA
- Tree windows: Birb's tree view opens centred on what you can act on. Make sure the Figma tree frames have a
  clear root area. (The game's camera framing fix is queued on the mechanics branch.)
- Tab count badges: designed on the tab's top-right corner, half over the border, never on the label.
- Footer strips: one 40 px height everywhere.
- Collection / enemy / quest grids: keep one clean template cell; the game fills them with real data.

---

## 5. Things NOT to change
- The HUD placement (owner's screenshot direction, Birb's screen split): banner + wallet column top-left, area
  meter top-centre, COMPANIONS pull-down board top-right against the sidebar, one centred icon row at the bottom
  with the objective above it, permanent right sidebar (25 %). See HANDOUT "In-game UI from Figma" for the table.
- The motion spec (open 0.86 → 1.04 → 1, rows cascade 40 ms, tab crossfade without re-pop, close = rows collapse then
  shrink into the button) and the press-in feel. They live in code (`UI/Motion.luau`), not Figma.

---

## 6. Studio QA loop (how to check each fix)
- **One Studio window only** (RAM). The place is `birb(test)`. Get its id with `list_roblox_studios`.
- Live sync: run `python -m http.server 8778 --bind 127.0.0.1` in `roblox/` and
  `python roblox/tools/gen_manifest.py`, then the sync snippet from HANDOUT (Edit mode). It uses
  `ScriptEditorService:UpdateSourceAsync` for files over 200k chars.
- Open any window without clicking: `PlayerGui:SetAttribute("PeckwoodOpen", "mine:AREAS")` (window:tab).
  Dev saves: fire `Remotes.Action:FireServer("dev", "maxed" | "regular" | "next" | "grant")`.
- `execute_luau` / the command bar runs a **separate copy** of ModuleScripts, so `require` from there doesn't see
  the game's state. Drive the game through attributes and remotes.
- Real clicks: `user_mouse_input` with `instance_path` = `LocalPlayer.PlayerGui.<path to the key>.hit` (every key has
  a `hit` button). The Tab key can't be sent (Roblox core binding); click the COMPANIONS header instead.
- `_G.__uiKeys()` lists every live key (press / sound wiring).
- Screenshot every window after a fix and send it to the owner.

---

## 7. Everything else (status when paused)
- **Integrated on `claude/peckwood-isle` (pushed):** map (Park + every island, unlock animation), Figma UI in game
  with the owner's layout, VFX (egg hatch, collect pop, level up, island unlock), 992 icons, licensed sounds (pick
  by ear on the dev Sound Board: SOUNDS on the dev bar), mechanics Phase 1 (the Park on Birb's real rules, 45,582 /
  45,582 parity).
- **Paused:** mechanics Phase 2 (Bridge, fishing, Seagull, Aquarium, Market) on `claude/peckwood-mech`, WIP
  committed. Status and the next step are in HANDOUT section A "MECHANICS". Parity harness:
  `node roblox/tools/parity/run.js`.
- A fresh `Peckwood.rbxl` is on the OneDrive Desktop.
