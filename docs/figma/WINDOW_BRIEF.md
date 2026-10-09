# Peckwood window brief (for every Figma design agent)

You design ONE Peckwood game window in Figma at Birb parity, in the owner-approved squared style.
Design only: no Roblox code, no git commits.

## Where
- Figma file key `SQOJ2gzGt12vFMGGlNRWBE`, page **UI v2** (`7:7`). Tools: `use_figma`, `get_screenshot`, `upload_assets`
  (load them with ToolSearch: `select:mcp__6f01c653-49f3-472e-b5aa-ed4ac06a0cc7__use_figma,mcp__6f01c653-49f3-472e-b5aa-ed4ac06a0cc7__get_screenshot,mcp__6f01c653-49f3-472e-b5aa-ed4ac06a0cc7__upload_assets,mcp__6f01c653-49f3-472e-b5aa-ed4ac06a0cc7__get_figma_skill`).
  Before your first `use_figma` call read `skill://figma/figma-use/SKILL.md` with `get_figma_skill` and pass
  `skillNames: "resource:figma-use,resource:figma-generate-design"` on every call.
- **Windows board** `239:307` (page coords x 5400, y 17600). Work ONLY inside your column:
  board-local `x0 = 40 + col*1400`, `y0 = 110`, width 1360, height up to 4300. Never create, move or delete anything
  outside your column, never edit components, the HUD board `213:7`, the icon strip `213:10`, or other windows.
- **Reference window** (copy its look exactly): `Window / Sunflower Tree` `239:309` (column 0). Screenshot it first.
- **Kit**: `C:\Users\jacob\Downloads\rc-main\docs\figma\kit.js`. Paste the WHOLE file at the top of every
  `use_figma` script (each call is a fresh context), then write your code below it. It gives you:
  `WINDOW, TABS, STEEL, WELL, KEY, BTN, CHIP, BAR, T, BODY, ICO, GLYPH, CHEVRONS, SPEC, PAL, THEME, ICON, textW, grad, hgrad, R, F, STROKE, LATT, HALFTONE, STRIPES, SHADOW, INNER, INKDS`.
  Keep each script under ~45 KB (kit is ~14 KB); build a window in a few calls (frame + header + tabs, then rows, then details).

## Icons (glossy painted PNGs only)
- `ICON[name]` already has: the shared strip (`213:10`, e.g. egg, egg_golden, plume, seed, moneta, twig, wood, echo,
  ore, goldore, skill_point, sparrow, seagull, redpanda, crow, dove, parrot, rod_simple, bait, hook_iron, lure_basic,
  item_full_potion, aura, relic, map, teleport, fish, index, settings, auto, lock, clock, pickaxe, golem, totem,
  night_mode, shop, birb, monster, nest, golden, quest_scroll, plank, trophy, legendary_key, node_* for 16 sunflower
  nodes) plus every `icons/...` frame on the Windows board.
- Need more? Source PNGs: `C:\Users\jacob\Downloads\rc-main\birb-icons\final\` (fish icons in `final\fish\`).
  1) In your column create a frame `icons/<your-slug>` at board-local (x0, y0+4000), add 72x72 rectangles named
  `src/<file stem>` (one per icon). 2) `upload_assets` with `nodeIds` = those rectangles, `scaleMode: "FIT"`.
  3) POST each PNG with curl (Bash): `curl -s -X POST -H "Content-Type: image/png" --data-binary @<file> "<submitUrl>"`.
  The next kit run picks them up automatically. Never draw icons with vectors; never use flat/vector icons.
  If an icon truly does not exist, reuse the closest existing painted icon and list it in `openQuestions`.

## Owner rules (non-negotiable, learned the hard way)
1. **Squared**: ink body r4, faces/lips r2.5, plates r4, wells r3. One black ink outline. No coloured rims, no glows.
2. **Keys = the game's Kit.button** (`KEY`/`BTN`): ink body, lip = face x0.58 shifted down, stripes, gloss cap.
   The COMPANIONS header on the HUD board is the shading reference. Pressed = face sinks the full lip depth, lip hidden.
3. **Never** put a white inner shadow over an inside stroke (it greys the top outline). Use a 1.5 px `top highlight`
   strip inside the outline (STEEL does this). Dark steel faces: gloss cap opacity <= 0.2.
4. **Zero clipping** at the LONGEST real values (big numbers look like `1.84SpSpgDCe`, `255.75B`). Measure with
   `textW` and size boxes to fit. Nothing spills past a window edge (WINDOW clips the header).
5. **No dead space, no notches**: fill widths (justify cells, centre content), joins share one outline and sit flush.
6. **Visual hierarchy**: exactly one bright call-to-action per view (green BUY/CLAIM key), the selected item gets a
   white 3 px ring, everything secondary sits on dark steel. Title (`T`) > values > body text (`BODY`) > hints.
   **ALL UI text is Fredoka One** (the game's Kit.text uses it for everything). Never use the "Fredoka" family
   (SemiBold/Medium) inside a window: normal text = `BODY(...)` = Fredoka One with a light 1.2 px ink outline and
   1 px ink drop, colour `#c9d2e3` (hints `#8d94a3`, good `#9dffae`, bad `#ff9a8a`). Min size 12.
7. **Names**: eggs replace popcorn everywhere (golden popcorn = golden eggs, echo popcorn = echo eggs, butter/cheese/
   rainbow popcorn = butter/cheese/rainbow eggs), feathers = plumes, moneta, twigs, wood, planks, brute ore, gold ore,
   skill points. Birb's rebirb stays "Rebirb" for the Parrot/Crow, Molt for the player prestige.
8. Textures only via the kit (`STRIPES` is the new seamless one, `LATT`, `HALFTONE`). Check that no texture shows a
   break/seam where a frame clips it.
9. Window = square-top modal via `WINDOW` (1000-1200 wide, <= 880 tall), tabs via `TABS`. Header theme from `THEME`.

## Parity source (layout, sections, data, flow)
HTML parity build (a 1:1 copy of Birb's logic and screens): `C:\Users\jacob\Downloads\rc-parity\playtest\`.
- `js/main.js`: `WINS` registry (window titles + tabs) and the panel functions named in your task; `drawHud` for HUD bits.
- System files beside it (`mine.js`, `fishing.js`, `aquarium.js`, `nest.js`, `riverside.js`, `archivist*.js`,
  `expedition*.js`, `desert.js`, `data.js`, `tools/sunflower_stations.json`). Read the real numbers there
  (node it if useful: `node -e` with the files). Birb screenshots for reference: `playtest/parity/birb_ui/`.
- Show a believable mid-game save state (some owned, some buyable, some locked, some hidden).
- Copy Birb's layout, sections, data and flow only; never Birb's art.

## QA (do this before you return)
After building, `get_screenshot` your window at full size (`enableBase64Response: true`, `maxDimension` 1600) and check:
clipping/overflow, overlaps, grey top outlines, texture seams, notches, empty dead areas, unreadable text (< 12 px),
icons not centred, more than one bright CTA, popcorn/feathers wording. Fix with targeted edits and screenshot again.
Repeat until clean (max 4 rounds). Then add a spec card with `SPEC(...)` to the right of or below the window:
SIZE + LAYOUT, VISUAL HIERARCHY, BUILD, STATES, MOTION, SFX (every key press = the buttery keycap; each effect gets
its classic cue), PARITY NOTES. Report honestly what is still imperfect.

## Late additions (owner, while you work)
- Symbols on keys (+, -, x, check, arrows) are `GLYPH(...)` centred on the key face: never typed characters (they sit off-centre).
- Close key comes from `WINDOW` (44 px at W-54, 10): do not add another and do not move it.
- Tree / node-map connector lines: draw ALL ink (outline) segments first, then ALL coloured segments on top, square ends (r 0) that overlap at elbows and T-joins. Never draw ink+colour per segment (the next segment's ink cuts through the joint).
- Cost / value chips: use the updated `CHIP` (steel mini plate, ink outline 2, top highlight, ink drop). Re-read kit.js if you pasted an older copy; the old flat black chip is rejected.
- PRESSED state is `PRESS(k)`: the whole key (ink body AND face) drops by the lip depth, body loses that height, lip hidden. A face sinking inside a full-height ink body (black band on top) is WRONG (owner).
- Window outline (owner-approved): frame stroke 4 + `OUTLINE(win)` called LAST (continuous 4 px, header included). Not 5.
