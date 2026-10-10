# Worlds v2 - UI QA (zoomed) + Style Guard

Image: `concepts/snakewars_vc/after/worlds_desktop_v2.png` (1920x1080). Window = x 240..1679, y 110..969.
Method: full view once, then 2-6x Pillow crops of every region (header, 9 rows, hero, title row, stage strip, boss well, PLAY key,
bottom strip, corners) plus pixel sampling for edges, gaps, colours and cap heights. Cap height 10 px = about 15 px Source Sans.

Verified clean (so you know what was checked): window outline is 4 px ink (13,20,24) on all four sides including the header,
no gaps (L x240-243, R x1676-1679, T y110-113, B y966-969); rows are 66 px tall on an exact 73 px pitch (7 px gaps, y=214+73*(n-1));
row title/sub baselines identical in all 9 rows (title +8..+24, sub +42..+55); name column x=396, BOSSES column x=751/884, right
controls x=930..1080 in every row; list well and right panel share top 206 and bottom 873; PLAY key has a continuous 3 px ink
outline (x1120..1647, y788..865) with a 7 px lip and gloss cap and 6 px steel margin each side; selected ring is exactly 3 px white
(x268-270 / 1089-1091, y429-431 / 500-502); no placeholder text (no lorem, no TODO); close key is 46 px with 6-7 px margins.

---

## PASS 1 - UI QA defects (most severe first)

Severity: M = visible at a glance / breaks a stated rule, L = polish.

1. **[M] Next-boss portrait is a bad crop of the hero screenshot (clipped subject + clipped baked text).**
   Where: thumbnail x1130..1258, y678..766 (inside the red well).
   What: the python's head is sliced by the left edge, the in-game nameplate "1968" is cut by the top edge, and the rest is empty snow,
   a tree and a snowman. It does not read as "GLACIER PYTHON" at all, and it is 128x88 so the sliced art is unmissable.
   Fix: re-crop tight on the boss head + neck with the whole face inside the frame and the nameplate excluded (or drop in the
   dedicated boss render from `3d/bosses`); keep the 2 px ink frame.

2. **[M] Locked states are three different treatments (rows 5-8); rule 11 not met.**
   Where: thumbnails at x332..384, rows 5-8 (y 506, 579, 652, 725 + 7..58); right wells x930..1080.
   What: row 5 = egg dimmed to about 25% + padlock overlay + LOCKED / Beat BLIZZARA well (correct). Row 6 = no egg at all, a lone big padlock
   (Candy Canyon has no egg art in the kit). Rows 7 and 8 = eggs at full colour/saturation (purple, gold), no padlock, no dim.
   Rows 6-8 right wells say COMING SOON with no padlock. So 7 and 8 look unlocked-but-disabled while 5 looks locked.
   Fix: one recipe for 5-8: egg art at the row-5 dim (about 25-30%) + the same 20 px padlock bottom-right of the tile; give Candy Canyon
   an egg (or a dim "?" egg silhouette) so 6 is not a different icon type; add a small padlock before COMING SOON in the well.

3. **[M] Coloured rims instead of ink outlines on three inner components.**
   Where: (a) boss well rim x1120..1647, y668..775, 2 px #EE3B3B directly on steel, no ink around it; (b) row-4 status box rim x930..1080,
   y441..490, 2 px #32BE61; (c) stage-20 cell ring x1523..1539, y~623..656, 2 px #EE3B3B.
   Why: house rule is one black outline, no coloured rim; the ref wells (e.g. MINING HERE) are plain ink-outlined with coloured text only.
   Fix: give all three the standard 2 px ink outline; carry the red/green as a tint of the fill (e.g. red 8% fill, green 10% fill) and in the
   text. Stage-20 cell: ink outline + red crown/fill, no red ring.

4. **[M] "STAGE 17 / HERE" text stack is cramped and off-centre.**
   Where: x930..1080, y441..490. "STAGE 17" cap y447..456, "HERE" y460..474: 3 px clear between them, so the two ink halos
   touch/merge. Block sits 5 px under the top rim and about 15 px above the bottom rim (top-heavy by about 5 px).
   Fix: add 3-4 px leading (STAGE 17 up 1, HERE down 2) and centre the block (net shift down about 4 px), or drop to one line
   "STAGE 17 HERE" in Source Sans mint.

5. **[M] Hero art carries baked-in game text that is illegible and contradicts the panel.**
   Where: hero x1123..1645, y217..503: gate tag "1448" (washed white-on-orange, about 1340..1425 x 225..250), nameplates "YOU 131B" and
   "GLACIER 196B" (6-9 px tall, blurry).
   Why: below the 15 px floor and unreadable; the numbers (131B / 196B / 1448) conflict with "RECOMMENDED 4.2M" in the boss well. The
   art is also visibly softer than the UI (bilinear upscale).
   Fix: re-render the hero without nameplates/gate numbers (or paint them out), or make them match (e.g. 3.1M / 4.2M); export at 2x.

6. **[L] Progress bar: label straddles the fill edge and runs together; bar has no readable frame.**
   Where: bar x368..727, y904..931; fill ends x503; label x470..620.
   What: "3/8" sits half on gold, "WORLDS CLEARED" on black, and "8" to "W" is about 3 px so it reads "3/8WORLDS". The 1 px ink frame
   (13,20,24) against window bg (14,23,30) is invisible, so only the gold block reads.
   Fix: put "3/8 WORLDS CLEARED" entirely right of the fill (left-aligned at x=514) or as value text outside the bar; add a steel 2 px
   rim or use a lighter track (28,38,50) so the ink outline shows.

7. **[L] Lock + LOCKED line is off-centre in the locked wells.**
   Where: row 5 and row 9 wells (x930..1080): padlock+LOCKED spans x947..1017 (centre 982) while the second line is centred at 1005
   ("Beat BLIZZARA" 958..1051; "Clear Magma Hollow" 938..1071). Offset 23 px.
   Fix: shift the lock+LOCKED group +23 px (or left-align both lines at x946).

8. **[L] Egg icons have no ink outline and are low-res/soft; Void Climb thumbnail is a different art type.**
   Where: tiles x332..384 in all 9 rows (eggs about 28x40 px of a 52 px tile).
   What: eggs are soft 3D renders with no black sticker outline (confirmed at nearest-neighbour zoom); tile is half empty. Row 9's
   thumbnail is a tiny gameplay screenshot with unreadable HUD pixels, not an icon.
   Fix: add a 2 px ink outline to the egg PNGs (or stack an ink-dilated copy underneath), scale eggs up about 15% to fill the tile,
   and swap the Void thumbnail for a painted icon (the same stud tower or an infinity gate on the dark tile).

9. **[L] Number badges are saturated keys next to the single primary.**
   Where: badges 1-3 green, badge 4 gold (x282..316, each row). Same recipe/colour family as the PLAY key, so they compete with it.
   Fix: make all badges steel keys with the number in mint (cleared) / gold-outlined white (current) / grey (locked); keep colour only on
   PLAY.

10. **[L] Gold is used for non-Length things, diluting the colour code.**
    Where: "STAGE 17 / 25" chip text (x1491..1606, y531..542, #FFC93C), "5/5" counters, boss pips, cleared boss cells, progress fill.
    Fix: stage chip text to white (flag icon stays), "5/5" to body colour, pips and progress to a non-Length colour (sky or ice) so gold
    means Length only; 4.2M keeps gold, +2,500 and 345 keep amber (both verified correct).

11. **[L] Stage strip ambiguities.**
    Where: strip x1123..1647, y~622..656. (a) Current stage 17 (x~1450..1480) uses the same gold as cleared boss cells 5/10/15 and its white ring has
    no ink halo; (b) stage-25 cell (x~1630..1647) is dark-on-dark with no outline, effectively invisible; (c) label insets differ:
    STAGES starts x1128 (strip 1123, +5) but BOSS EVERY 5TH STAGE ends x1639 (strip 1647, -8).
    Fix: current = mint or white fill + ink outline + ring; cleared boss = gold; give cell 25 the same 1 px ink + dim crown at 60%;
    align both labels to the strip ends.

12. **[L] "WORLDS" title sits high in the header.**
    Where: title ink halo top y118 vs window inner edge y114 (4 px) but bottom y161 vs depth band y174 (13 px).
    Fix: move title down 4-5 px or reduce size 46 to 42.

13. **[L] Stage chip is about 4 px low against the title.**
    Where: chip y524..552 (centre 538) vs "FROSTBITE PEAKS" y519..548 (centre 534). Fix: chip up 4 px.

14. **[L] Void Climb tail row reads as "a 9th row", and its value is a bare dash.**
    Where: row 9 y798..863; "DEEPEST" x751 with a "-" at y~833. Gap above is the same 7 px as every other row.
    Fix: add 8-10 px extra gap or a hairline + "ENDLESS" tag above row 9; replace the dash with "Floor 0" (dim) so it does not look unfinished.

15. **[L] Bottom band has about 30 px of dead space.**
    Where: y874..965 is 92 px for a 28 px strip (ref is about 60 px); strip centre y~917 vs band centre 920.
    Fix: trim the window height by about 28 px (or grow rows to 69 px); not urgent.

Informational (no fix required): rows 6-8 have a 285 px blank middle (x640..925) - acceptable, matches the ref's "Area 7 ???" row; all
labels measure cap height 10 px = 15 px, so there is no headroom - nudge to 16 if the Roblox scale factor drops under 1.0; "Clear Magma
Hollow" as the Void Climb requirement is as specified in the brief but I could not verify it against the design doc.

---

## PASS 2 - Style guard checklist

| # | Rule | Result | Location / note | Fix |
|---|------|--------|-----------------|-----|
| 1 | Square-top window, one continuous 4 px black outline incl. header, no coloured rims/glows | **PASS (shell) / FAIL (inner)** | Shell: 4 px ink on all sides, square corners, no glow. Inner coloured rims: boss well, row-4 box, stage-20 cell (defect 3) | Replace with ink outline + tinted fill |
| 2 | Keys = ink body + darker lip + face with gloss cap, r<=4, one black outline | PASS | GO x5 (x930..1080), PLAY (x1120..1647), badges: ink 3 px, 6-7 px lip, gloss cap, r about 4 | none |
| 3 | Exactly ONE primary key, secondary keys steel | **FAIL (soft)** | PLAY is the only interactive primary and GO x5 are steel (good), but badges 1-4 are saturated green/gold keys (defect 9) | Steel badges |
| 4 | Round red gem close key top-right | PASS | x1624..1670, y121..167, 46 px, ink ring, gloss, white X; margins 6-7 px | none |
| 5 | Fonts: Luckiest Guy titles/big numbers, Source Sans 3 Black/Bold Italic labels/body | PASS | Luckiest: WORLDS, row names, GO, HERE, PLAY, FROSTBITE PEAKS, GLACIER PYTHON, 4.2M, +2,500, 345, badges. Source Sans Black Italic: BOSSES, PROGRESS, STAGES, chips. Bold Italic: sub lines | none |
| 6 | Length gold, rates mint, Trophies amber | PASS (with note) | 4.2M = #FFC93C, +2,500 and 345 = #FFC071 (sampled). No rates on screen; mint appears on "STAGE 17" in the HERE box. Gold overused elsewhere (defect 10) | Re-assign gold per defect 10 |
| 7 | Icons = glossy 3D-painted art with ink outline (flat vectors only for tiny glyphs) | **FAIL (low)** | Padlock, trophy, Length coil, crown, flag, globe have ink outlines and read painted. Eggs x8 have no outline and are soft/low-res (defect 8). Void thumbnail is a screenshot. The infinity badge is a flat glyph (acceptable, number-badge replacement) | Outline eggs, repaint Void icon |
| 8 | Zero clipping | **FAIL (art only)** | No text or outline cut by a parent edge. Boss portrait subject and nameplate are cut by the crop (defect 1) | Re-crop |
| 9 | Labels >= 15 px at 1920 | PASS (at the floor) | BOSSES, PROGRESS, STAGES, BOSS EVERY 5TH STAGE, COMING SOON, LOCKED, NEXT BOSS, RECOMMENDED, REWARD: cap 10 px; body lines about 16 px. Baked hero nameplates are smaller (defect 5) | Optional 16 px |
| 10 | Content: 8 Worlds + distinct Void Climb row; World 4 Frostbite Peaks Stage 17/25; next boss GLACIER PYTHON at Stage 20; guardian BLIZZARA; nothing sells arena size | PASS | 8 world rows + Void Climb; "WORLD 4 OF 8", "STAGE 17 / 25", "NEXT BOSS - STAGE 20 GLACIER PYTHON", "Beat BLIZZARA", "Guardian BLIZZARA waits at Stage 25"; bosses 3/5 matches cleared stages 5/10/15; no arena-size copy. "Distinct" tail is only mildly distinct (defect 14) | Defect 14 |
| 11 | Selected row = white 3 px ring; locked rows dim with padlock + requirement | **FAIL** | Ring PASS (exact 3 px white around row 4). Locked: row 5 and row 9 pass; rows 6-8 inconsistent and no requirement/padlock on 7-8 (defect 2) | Defect 2 |

Minimum to unblock STYLE: (a) defect 3 rims to ink, (b) defect 2 locked recipe on rows 5-8, (c) defect 1 boss crop, (d) defect 9 steel badges
(or an explicit owner waiver that non-interactive number badges may use the key recipe in colour), (e) defect 8 egg outlines.

---

## Verdicts

- **UI-QA: FAIL 15** (5 medium: boss crop, locked-state inconsistency, coloured rims, HERE stack, hero baked text; 10 low). No text is clipped
  and no sibling edges are broken; the structure (outline, row pitch, key construction, alignment) is solid and close to the bar.
- **STYLE: BLOCKED** until the five items above are fixed (all small edits, no re-layout needed).
