# Snake Wars "Worlds" v2 (1920x1080) - Visual Hierarchy + Roblox Feasibility review

Image reviewed: concepts/snakewars_vc/after/worlds_desktop_v2.png. Compared with before/worlds_desktop.png (old map version) and ref/peckwood_v2_mine_areas.png (style reference). Kit read: figma/sw_kit.js.
Method: Gaussian blur r=8 then 25 % and 50 % downscale (colour and grayscale), plus per-region luminance/saturation measurements and WCAG contrast sampling on the full-res PNG. Read-only; nothing edited except this report.

Layout facts used below (px at 1920x1080): window x242-1676, y114-970 (1434x856, flat blue header 60 px). Rail x274-1086 (9 rows, 73 px pitch). Hero well x1122-1646, y217-503 (524x286). Title block y515-560. Stage strip y600-656. Boss card y670-775. PLAY key x1122-1646, y790-862 (524x72). Footer y900-935. Backdrop is dimmed to about 32 % of its original brightness (about 68 % scrim).

---

## SQUINT ORDER (what the eye actually lands on)

| # | Shape | Evidence |
|---|-------|----------|
| 1 | The hero art slab (snow scene, top right, 524x286) | Mean luminance 0.72 vs window mean 0.28 and PLAY region 0.59. Near-white snow is the brightest and largest shape in the window. It is also the only big light object on a dark UI. |
| 2 | The blue header band with white WORLDS, full width | Saturation 0.72, luminance 0.48, 1434 px wide. It is the most saturated shape in the window. lum x sat = 0.32 vs 0.29 for the PLAY region, so it edges the key out on raw pop. |
| 3 | PLAY STAGE 17 green key (bottom right) | Strong and isolated, but third. Wins on isolation and hue, loses on size of the bright area and on luminance. |
| 4 | The gold pip column on rail rows 1-4 (four 5-pip bars stacked at x750-905) plus the green number badges 1-3 and the white outline on row 4 | Repeated saturated gold dashes read as one vertical stripe. Cleared rows (1-3) are louder than the current row (4): full gold pips x3 and bright green badges x3 vs only 3 pips and an amber badge on row 4. |
| 5 | The yellow "3/8 WORLDS CLEARED" bar, isolated bottom left (with the gold 345 chip bottom right) | Full-saturation gold (235,171,43) on near-black (10,15,20), alone in a dead footer. Isolation makes it pop far above its importance. |

Also visible but outside the window: the red/gold gift box at the right edge (the strongest backdrop object even at 32 % brightness).
Also pulling in the right column: the boss-card thumbnail (a bright white-blue crop of the hero art, directly above PLAY) and the amber "1448" lock tag baked into the hero art (top centre, highest-saturation warm dot in the hero).

## INTENDED ORDER (player job: where am I, next boss, press PLAY; then replay / what is locked and why)

1. PLAY STAGE 17 - the one primary key: strongest saturation, biggest key, terminus of the right column.
2. FROSTBITE PEAKS plus a big "17/25" numeral (where am I). Biggest white type in the window.
3. World 4 row in the rail (white outline, brighter plate, "HERE") - confirms location, anchors the rail.
4. NEXT BOSS card: GLACIER PYTHON, 4.2M recommended, +2,500 reward - the only warm/red panel.
5. Hero art as atmosphere - supports #2, must never out-shine #1.
Then: stage strip (17 marker, crown at 20) > cleared-world GO keys (steel, quiet) > locked rows (quietest) > progress footer (quietest of all) > header chrome.

## Mismatch table (squint vs intended)

| Mismatch | Cause | Smallest fix |
|----------|-------|--------------|
| Hero art is #1, PLAY is #3 | contrast (luminance 0.72) + size | Darken/cool the art and add edge vignette (see FIX 1). |
| Header outranks PLAY | saturation + width | Lower header value 20-25 %, dome gloss 0.32 to 0.18 (FIX 4). |
| Cleared rows louder than current row | saturation + repetition (3x gold pips, 3x bright green badges) | Mute cleared pips/badges; keep bright gold only for row 4 (FIX 2). |
| "Where am I" numbers are tiny | size (numbers smaller than labels - breaks "numbers before labels") | Big gold numerals for 17 and 17/25 (FIX 3). |
| Footer progress bar and 345 chip pop | isolation + saturation (dead-zone magnets) | Mute bar, drop duplicate chip (FIX 5). |
| Boss thumbnail pulls the eye next to PLAY | luminance + duplicates hero art | Dark portrait on the card's own background (FIX 6). |

## FIXES (ranked, smallest change first within each rank)

1. **Hero art too bright (cause: luminance/size).** Target mean luminance <= 0.45 so the PLAY face is the brightest large shape. In the render: re-expose the snow cooler/darker (snow about (150,175,200) instead of (225,245,254)) and add a 25-30 % black vignette at top and bottom edges; keep the green snake and blue boss bright so the subject still pops. Delete the baked-in amber "1448" lock tag, "YOU 1318" and "1968" world-space billboards (tiny unreadable text, one saturated amber dot that looks like UI). In Roblox this is free: ImageLabel.ImageColor3 = (0.70, 0.76, 0.88) multiplies the art darker/cooler, plus two edge gradient Frames.
2. **Cleared rows outshine the current row (cause: saturation + repetition).** Rows 1-3: pips at about 45 % (muted dull gold, or collapse to a single "5/5 BOSSES" text with a check); badges to steel or venom-bevel dark green with a small check. Only row 4 keeps full-bright gold pips and the amber badge. Add a 6 px amber accent bar on the left edge of row 4 and make row 4 about 16 px taller (space comes from FIX 7).
3. **Numbers must read before labels in the "where am I" cluster (cause: size).**
   - Hero chip "STAGE 17 / 25": make "17" a Luckiest Guy gold numeral about 28-32 px with a 12 px "STAGE" label above or beside; "/ 25" smaller.
   - Row-4 HERE chip: today "STAGE 17" is about 13 px and "HERE" is 22 px, so the word beats the number. Swap: "STAGE" 11 px label, "17" 28 px, drop the word HERE (the white outline and accent bar already say here).
   - Row-4 subtitle "Stage 17 of 25": make "17/25" gold Luckiest 18 px.
   - Stage strip: add a numeral above the amber tile ("17") and under the red boss tile ("20"). Today the strip has no numbers, so the amber tile is not tied to 17 without reading the title.
4. **Header louder than the key (cause: saturation + width).** Drop header value about 20-25 % (e.g. gradient from #1C4F86 to #143A66) and the dome gloss alpha from 0.32 to 0.18; keep sparkles and the title. This is where the screen beats the Peckwood reference, whose header is as loud as the window gets.
5. **Footer magnets (cause: isolation + saturation).** Progress bar: muted fill (venom at 55 % or desaturated gold), numerals "3/8" in Luckiest 20 px *inside/left* of the bar, "WORLDS CLEARED" label outside to the right (today the label straddles fill and track with no gap: "3/8WORLDS CLEARED"). Delete the 345 trophy chip (duplicates the HUD, and the HUD already shows 345/350); if trophies really gate worlds, say so ("Need 400 for next world") instead. Delete the footer sentence "Guardian BLIZZARA waits at Stage 25..." (duplicates row 5's "Beat BLIZZARA") or fold it into the row-5 lock reason.
6. **Boss card (cause: luminance + duplication).** Boss portrait should be a dedicated head/body render on the card's own dark-red gradient, not a bright crop of the hero (it currently shows ice terrain and the "1968" tag and sits right above PLAY). Add a "YOUR LENGTH 1.4M" line next to "RECOMMENDED 4.2M" - the recommendation has no reference number, so the player cannot decide. Keep the card as the only red panel. Add 8-10 px more gap between card and PLAY key (today 15 px; red outline and green key vibrate against each other) and soften the red border to about 60 %.
7. **Dead zone: rows 6, 7, 8 (cause: wasted height, 3x identical copy "Coming in a future update").** Collapse to one 52 px row "WORLDS 6-8 - COMING SOON" with three small padlock icons. That returns about 165 px of rail height (use it for FIX 2's taller row 4 and for a 2-line lock reason on row 5). Tie the lock reason to the strip: tint the stage-25 crown (currently almost invisible) rose/ember with a tiny lock so "Beat BLIZZARA" visibly points at the end of the strip.
8. **Push PLAY further (position/isolation/motion).** Idle sheen sweep across the PLAY face every 4 s (UIGradient.Offset tween) and a 1.5 % UIScale breathe; nothing else in the window moves. Optional: raise the lip from 6 to 8 px, label to 40 px. Do not add a second saturated key anywhere.
9. **Selection semantics.** "HERE" (where progress is) and the white outline (selected row) are different states that currently coincide. When the player selects row 2, the outline must move and the HERE marker must stay on row 4; PLAY becomes REPLAY ... Spec this before building.
10. **Hero chips.** "WORLD 4 OF 8" (13 px label) is fine as an orientation chip but the number is as small as the words; if space allows, "4" gets the same big-numeral treatment as 17.

### Competing primaries, dead zones, fold

- Competing primaries: none among keys (PLAY is the only saturated key, GO keys are steel, HERE is a dark-green well, the red gem close is standard). The competition is non-key: hero art, header band, gold pips, gold progress bar. The round red close gem is the second-most-saturated key and is acceptable.
- Gold is overloaded (boss-beaten pips, current-stage tile, row-4 badge, reward numbers, progress bar, trophy chip). Keep gold = "boss / reward" and let current = white outline + amber, and the progress bar goes to venom/steel.
- Dead zones: rows 6-8 (about 220 px, 340 px empty centre columns); footer strip (60 px for one stat plus a duplicated sentence plus a duplicated trophy count).
- Below the fold: nothing at 1080p (the window is 856 px tall). The "why locked" information is the lowest-placed text (footer sentence) and the smallest on row 5 (14 px coral); the row-level reason (9:1 contrast) is right, the footer duplicate should go. Contrast is fine across the board: dim locked titles are 3.5-4.1:1 (intentional), secondary labels 4.6-5.9:1, body text 10:1+, so the problems are hierarchy, not legibility. Phone layout not reviewed; the rail has 9 rows, so on phone scroll it to row 4 and pin PLAY outside the scroll area.

## Old vs new vs Peckwood reference

- **Old (map version):** the green header (lum 0.66, pop 0.35) and the PLAY key (pop 0.35) tied for first; the winding green path, snake mascot, 25 green stage nodes and green PLAY made a green soup, so there was no unique primary. Location ("World 4, Stage 17") was only a small snake head on the map plus a gold node in the grid. Locked worlds were coloured, lit platforms as vivid as the open ones. Strengths worth keeping: big node numbers, strong journey/story feel.
- **New:** clearly better. One green key in the whole window, header moved off green, steel secondaries, locked rows genuinely quiet, rail/hero/primary-beside-details structure as specified, boss pips and lock reasons are new information, and the boss card has real numbers-over-labels (RECOMMENDED 4.2M, +2,500). It loses the journey-map feel and the world identity is now concentrated in the hero art plus 48 px egg icons, so the hero must change per selected world.
- **vs Peckwood v2 reference:** on par, not yet higher. Ahead: no tab-bar green competing with the primary key, and the label vs number split in the boss card is cleaner. Behind: Peckwood's hero is dark purple with a dark golem, so it never competes with the green key; ours is near-white and does. The reference also has bright gold milestone pips x4, same as ours, so that is not a differentiator. To go higher: FIX 1, 2, 3, 4 and 8.

## VERDICT

**CLEAR in structure, muddled at the top of the order.** One primary key, quiet secondaries, and a readable rail/hero/PLAY flow, so the player can find the job in a second. But the squint order is hero art, header, PLAY, gold pips, footer bar, so the primary key is third and the "where am I" numbers are the smallest text in their cluster. FIX 1-5 (all palette/size changes, no layout rebuild) turn this into a clear order and put it above the Peckwood reference.

---

# PASS 2 - ROBLOX FEASIBILITY

Allowed toolbox assumed: Frame, UICorner, UIStroke, UIGradient (linear), ImageLabel (icons/art/textures/flipbooks), TextLabel (LuckiestGuy, SourceSansPro Heavy/Bold Italic), UIScale, TweenService. No EditableImage, shaders, blend modes, conic gradients, skew, letter-spacing, backdrop blur, native drop shadows.

Everything in this screen uses only normal-alpha blending, linear gradients and axis-aligned or rotated rectangles/triangles. Nothing needs a blend mode, a conic gradient, a skew or letter-spacing. The kit's DROP_SHADOW/INNER_SHADOW effects are the only things with no native equivalent.

Rough instance budget for this window if built literally from the kit: about 350-450 GuiObjects (about 28 per rail row x 9 = 250, right column about 70, window/header/footer about 35), about 60 UIGradients, about 100 UIStrokes. That is fine for a static, build-once screen; the notes below trim the avoidable part (hex overlays that are invisible at 5 %, strokes on small steel-plate text, soft shadows). Treat the counts as estimates, not engine limits.

| # | Effect (where) | Verdict | Roblox recipe | Perf note | Redesign? |
|---|----------------|---------|---------------|-----------|-----------|
| 1 | Square-top window, 4 px continuous ink outline | native | Frame (no UICorner) + UIStroke(Thickness 4, Color ink #0D1418, ApplyStrokeMode Border). UIStroke draws outside the frame bounds (verify once in Studio) so inset the frame by the thickness or give the parent padding. | 1 stroke. | No |
| 2 | Dimmed hub backdrop (about 68 % scrim) | native | Full-screen Frame, black, BackgroundTransparency about 0.32, Active=true to eat clicks. No blur. Live HUD stays under it. | 1 quad. | No. Consider 0.25 so the red gift box recedes. |
| 3 | Soft window shadow (SHADOW 10/24/0.5) | recipe, optional | One 9-slice soft-shadow ImageLabel (ScaleType Slice, SliceCenter) behind the window, offset +10 Y, ImageTransparency about 0.5. | 1 image. | In the render it is invisible against the scrim: safe to drop. |
| 4 | Header: L-to-R gradient, hex scales, gloss dome, depth band, ink line | native | Frame + UIGradient(Rotation 0); tiled ImageLabel for scales; dome = Frame with UICorner(1,0) and UIGradient Transparency 0.68 to 1, parent header ClipsDescendants; depth band and ink line = 2 Frames. | About 6 objects. | No |
| 5 | Sparkles (5 four-point stars, header) | native | 4-point-star PNG in ImageLabels, 5-10 px; optional TweenService twinkle on ImageTransparency/Rotation. | 5 tiny images; tween only on window open. | No |
| 6 | Round red gem close key | native | 4 Frames with UICorner(1,0) (ink body, lip, face, gloss), X as ImageLabel PNG (kit builds it from vector strokes - not available), 56 px hit area as an ImageButton/TextButton. | about 6 objects. | Glyph must be a PNG. |
| 7 | Gem keys (PLAY, GO, HERE, number badges): ink body + lip + face + hex scales + facet + gloss cap | native (composed) | Frame ink body (UICorner 4) > lip Frame (face colours x0.62, UICorner 2.5) > face Frame (UIGradient vertical) > children: tiled scales ImageLabel, facet, gloss Frame. Press state: tween face Position down by D and hide lip. Build as one Key factory. | 5-7 objects per key, about 15 keys = about 90. Steel keys: skip scales and facet (they are 3-5 % opacity). | Slim steel variant. |
| 8 | Gloss cap (white .45 to .04 on upper 42 %) | native | Frame, BackgroundColor3 white, UICorner, UIGradient Transparency (0.55 at top to 0.96 at bottom; Roblox transparency = 1 - alpha). | 2 objects (frame + gradient). | No |
| 9 | Face and plate gradients | native | UIGradient ColorSequence, Rotation 90 (vertical) or 0 (horizontal); set BackgroundColor3 white so the gradient carries the colour. Kit only uses linear gradients. | Cheap, static. | No |
| 10 | Facet triangle (3-7 % white, rotated polygon on keys) | recipe | No polygon primitive. Use a Frame with UIGradient Rotation -28 and a hard-stop Transparency sequence (0:1, 0.5:1, 0.501:0.93, 1:0.93). No asset needed. Alternative: shared white-triangle PNG in an ImageLabel, rotated, ClipsDescendants on the face. | 1 object per key. At 3 % (steel keys) it is invisible in the render. | Drop on steel; keep on coloured keys only. |
| 11 | Hex-scale texture (5-8 %) on window, header, plates, keys | recipe | ImageLabel, ScaleType Tile, TileSize about 28x16 px, ImageTransparency 0.92-0.95, seamless PNG <= 256 px, own asset (not a sprite sheet; Tile + ImageRect is unreliable). UIScale on the window scales tiles with it. | Each layer is an overdraw quad and breaks draw batching when interleaved with text. About 35 in this screen. | Keep only on window bg, header, PLAY key and keys >= 120 px; drop the <= 5 % layers on plates/chips/badges (invisible). |
| 12 | Ink drop on text (hard 0-blur offset 1-4 px) | recipe | Duplicate TextLabel behind: ink colour, same text, Position +(0, y), lower ZIndex, its own UIStroke. | Doubles label count. | Limit to Luckiest Guy display text and numbers >= 18 px (title, PLAY, row names, big numerals); at <= 16 px the drop sits inside the outline and does nothing. |
| 13 | Outlined text (ink stroke 1.2-4.5 px) | native | UIStroke on the TextLabel: ApplyStrokeMode Contextual, Color ink, Thickness = about 0.09 x size, LineJoinMode Round. | About 100 strokes in the literal build. Text strokes cost more than plain text. | Skip the stroke on <= 16 px labels that sit on steel plates (they already read at 5-10:1 contrast and the 1.2 px outline is not visible); keep it on text over art, gradients and keys. Tune thickness against one real label (the kit's OUTSIDE 9 % may need +/-0.5 px). |
| 14 | Fonts: Luckiest Guy titles/numbers; Source Sans Black Italic / Bold Italic labels | native | Enum.Font.LuckiestGuy; SourceSansPro family via Font.new(..., Heavy, Italic) and (..., Bold, Italic). Uppercase with string.upper. | None. | Do not hard-code widths from Figma's textW (Source Sans 3 vs SourceSansPro metrics differ slightly): use AutomaticSize.X, UIListLayout and TextBounds. No letter-spacing is needed (kit uses none). |
| 15 | Infinity glyph on the Void Climb badge | NOT possible as text (uncertain) | Luckiest Guy is unlikely to have U+221E and Roblox will fall back to a different font. Use an ImageLabel glyph PNG. | trivial. | Yes - make it an icon. |
| 16 | Steel plate rows (gradient + 2 px stroke + top highlight + soft drop) | native + recipe | Frame + UICorner(4) + UIGradient + UIStroke(2) + 1.5 px top highlight Frame (white, transparency 0.82). Soft SHADOW(4,10) replaced with a 3 px hard ink Frame offset below, or dropped. | 3-4 objects x 9 rows. | Replace soft shadow. |
| 17 | Inner shadow on wells (value fields, icon wells, COMING SOON wells, hero frame) | recipe | One 9-slice inner-shadow ImageLabel (single PNG shared by all wells) or a 6 px top Frame with UIGradient Transparency 0.35 to 1 plus optional 2 px side strips. | 1-3 objects per well. | Yes, replace the effect. |
| 18 | Soft drop shadows on keys, chips, plates, icons (SHADOW/INKDS with blur) | NOT possible natively | Hard-offset ink Frame under the element (the key lip already is one), or a 9-slice soft-shadow ImageLabel for large items only. For icons: bake the 1.5 px drop into the PNG, or a duplicate ImageLabel with ImageColor3 = ink, 50 % transparent, +1.5 px Y. | Soft shadows on every key/plate would add about 30 image quads; they are almost invisible on the dark steel. | Yes - remove blurred shadows, keep hard offsets. |
| 19 | Hero art (snow scene with snakes) | recipe | Pre-rendered image (Studio/Blender), uploaded as one ImageLabel asset, <= 1024 px on its long side (Roblox downsizes larger uploads; use about 1024x560). UICorner 3, UIStroke 2 ink, ImageColor3 tint to darken (FIX 1), edge vignette via 2 gradient Frames or one 9-slice vignette PNG. Chips ("WORLD 4 OF 8", "HAZARD - ICE RINKS") are Frame + UIStroke + TextLabel on top. Load only the selected world's art (ContentProvider:PreloadAsync). Avoid a live ViewportFrame (EditableMesh snakes, cost). | About 1-2 MB of GPU memory per hero; 8 worlds = load on demand, release on close. | Re-render clean without baked world-space tags (amber lock "1448", "YOU 1318", "1968"); baked text cannot be localised. |
| 20 | Boss portrait crop (card thumbnail) | native (but redesign) | ImageLabel with ImageRectOffset/ImageRectSize cropping the same hero asset costs no extra memory; better a dedicated 256x256 boss render on a dark backdrop. UIStroke 2 red on the thumbnail only. | trivial. | Yes - dedicated portrait (FIX 6). |
| 21 | Icons (eggs, flag, trophy, crown, locks, length stack, globe) | native | ImageLabels from 3D renders (Blender); pack into 1-2 sprite sheets with ImageRectOffset/Size (pad edges) to keep texture count down. ZIndex above the plate. | About 35 icons; unique textures break batching, so use sheets. | No |
| 22 | Vector glyphs (X, check, plus) built from SVG strokes in the kit | NOT possible as vectors | Render once to PNG (white fill + ink outline baked in) or use a TextLabel with a font glyph. | trivial. | Bake to PNG. |
| 23 | Rail row selection (white 2 px outline on row 4, accent bar) | native | UIStroke(2.5, white) on the row Frame + 6 px accent Frame. The stroke is drawn outward: leave 4+ px padding in the list container so ClipsDescendants does not cut it. Tween Thickness/Transparency to animate selection. | 1 stroke. | Layout padding. |
| 24 | Locked-row dimming | recipe | Use pre-dimmed colour tokens on those rows. Do not use CanvasGroup/GroupTransparency (not in the toolbox, and it costs an offscreen buffer). | none. | Token set, not a runtime fade. |
| 25 | Pips (boss pips, stage strip of 25 tiles + crowns, progress bar) | native | Small Frames with UICorner 2 + UIStroke 1.5; UIListLayout/UIGridLayout; crowns as ImageLabels; BAR = track Frame + fill Frame (UIGradient) + gloss + TextLabel on top. Idea: the 5 boss pips per row could be one Frame with a hard-stop UIGradient, but 5 pips x (colour + gap) is about 20 keypoints, the maximum, so just use Frames. | About 55 objects for the strip, 25 for the pips. For cleared rows replace 5 pips with one text/check chip (saves about 18 objects). | Optional |
| 26 | Chips (STAGE 17/25, WORLD 4 OF 8, HAZARD, 345) | native | Frame + UICorner 3 + UIStroke 2 + UIListLayout (icon + label) with AutomaticSize. | small. | No |
| 27 | Boss card (red tint, red 2 px border) | native | Frame bg dark red (26,16,19), UIStroke red, children via UIListLayout. | small. | No |
| 28 | Void Climb row vertical-stripe texture | recipe | Tiled low-alpha stripe PNG in one ImageLabel (or drop; barely visible). | 1 image. | Optional |
| 29 | Open/close pop and PLAY idle sheen/pulse | native | TweenService on UIScale (0.94 to 1, <= 0.2 s) and window Position; sheen via UIGradient.Offset tween; pulse via UIScale on the PLAY face. Tweening UIScale on a window with about 100 text labels re-lays out text each step, so keep it short and do not loop it on the whole window; loop only the PLAY sheen. | Low if scoped to PLAY. | No |
| 30 | Gradient-filled text | native (not used here) | UIGradient parented to the TextLabel. | n/a | n/a |

Clip behaviour to remember: ClipsDescendants clips to the rectangle, not to UICorner shape. At the kit's radii (2.5-4 px) nothing visibly leaks, but the hero well and rounded keys should not rely on rounded-corner clipping for art.

## MUST-REDESIGN LIST (before this screen is built)

1. **Hero art: re-render clean and darker.** No baked billboards or lock tag, <= 1024 px, tuned to mean luminance <= 0.45, vignette via gradient/9-slice. (Visual FIX 1 and Roblox constraint align.)
2. **Boss portrait: dedicated render**, not a crop of the hero (baked "1968" tag, bright ice).
3. **Facets: drop on steel keys; use a hard-stop UIGradient Frame on coloured keys** instead of rotated polygon assets.
4. **Soft shadows (window, keys, plates, chips, icons): remove**; keep only hard ink offsets and the key lip. At most one 9-slice shadow for the window (invisible anyway).
5. **Inner shadows on wells: swap for one shared 9-slice inset PNG** (or a 6 px top gradient strip).
6. **Text effects tiered:** outline + ink-drop duplicate only on display text and numbers >= 18 px and on text over art; <= 16 px steel-plate text gets neither (saves about 35 strokes and about 40 duplicate labels).
7. **Hex-scale overlay only on window, header, PLAY and large keys;** drop the <= 5 % layers (about 25 objects).
8. **Infinity glyph and all SVG-built glyphs (X, check, plus) become PNG icons.**
9. **Do not bake Figma text widths** (font metrics differ): AutomaticSize + UIListLayout everywhere; fix the "3/8WORLDS CLEARED" collision by splitting numeral and label.
10. **Locked-row dimming through colour tokens**, no CanvasGroup.
11. **Padding for outward strokes:** the 4 px window outline and the 2.5 px row-4 outline are drawn outside their frames; reserve space or they will be clipped by parent ClipsDescendants.
12. **Merge cleared-row pips into one chip** (also fixes the visual hierarchy: FIX 2) and collapse rows 6-8 into one row (FIX 7): about 40 fewer objects and a calmer rail.

Net verdict for Roblox: everything on screen is buildable with the allowed set. The only things that are not native (blurred drop shadows, inner shadows, vector glyphs, polygon facets) have cheap substitutes, and in every case the substitute is closer to what is actually visible in the render than the original effect was (the soft shadows and 3-5 % overlays are essentially invisible at 1080p).
