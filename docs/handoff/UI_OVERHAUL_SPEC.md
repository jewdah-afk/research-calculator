# UI Overhaul Spec — Shark Incremental

Concrete work order, derived from four screenshots of the live build:
the Stats panel, the Resets panel, the main HUD, and the roll-room boards.

**Direction confirmed by the owner:** the Resets panel (orange header, per-layer
rows with progress bar + action button) is the right track. Everything else
moves toward it. Stats needs work.

---

## 1. Fix these first — visible defects

- **Placeholder checkerboard is showing** at the bottom of both the Stats and
  Resets panels. A transparent/missing texture is rendering. Ships as a bug.
- **Number glyphs are corrupting.** In Stats, `1.00`, `[21]` and `1 136` render
  with vertical bar artifacts between digits. Suspects, in order: a custom
  `FontFace` with broken glyph metrics; a `UIGradient` or `UIStroke` applied to
  a TextLabel mid-tween; or a rolling-digit animation caught between frames.
  Reproduce by freezing the value, then by removing effects one at a time.
- **Walking to the Reset pad opens the Upgrades tab, and the action doesn't
  fire.** The proximity trigger is bound to the wrong panel id and the confirm
  path is broken. See §3.

## 2. HUD scope — read-only reference, actions at stations

**Resolved from two rounds of feedback, which appeared to conflict:** all four
tabs stay reachable from the HUD, but **Upgrades and Resets become read-only
reference panels.** You can look up anything from anywhere; you can only *act*
at the station. That satisfies both "you have to walk to them" and "move the
four icons".

| Surface | Shows | Can act? |
|---|---|---|
| Stats tab | Progress, gauges, history | n/a |
| Settings tab | Options | yes |
| **Upgrades tab** | Every upgrade, level, cost, effect, locked state | **no — view only** |
| **Resets tab** | Every layer, required **rarity index**, progress, projected gain | **no — view only** |
| Upgrade station | Same data | **yes — purchase here** |
| Reset pad | Layer status | **yes — reset here** |

Each read-only panel ends each row with a location hint instead of a button —
*"Purchase at the Upgrade Terminal"* — so the panel teaches the room.

**Button cluster moves to bottom-left**, beside the ROLL button:
- One horizontal row of four, all **identical size**, evenly spaced
- Baseline-aligned with the ROLL button so the bottom edge reads as one bar
- Larger than the current top-left icons — these are primary navigation
- Top-left corner clears entirely

**Reset pad behaviour (the bug).** Stepping on a ready pad must perform that
layer's reset — a confirm step if the reset is destructive — and must **never**
open the Upgrades tab. Root cause is a station firing another station's panel
id. Fix it structurally: each station instance carries an attribute naming its
own action, resolved at runtime. A station then cannot reference another's id,
so the two can never drift apart again.

Pad states: **Locked** (dim, no prompt) · **Not yet** (visible, shows what's
required) · **Ready** (full chromatic treatment, "step on" prompt, the reward
figure). The existing "READY — step on!" pad label is the right pattern; give
every station the same language.

## 3. Boards## 3. Boards — flush to the wall, AAA finish

Currently the boards float at arbitrary angles, visibly detached.

**Mounting.** Do not hand-place. Raycast from the board's anchor into the wall,
take the hit normal, and build the CFrame from it:

- position = `hitPosition + normal * mountOffset` (2–4 studs)
- orientation = `CFrame.lookAlong(position, -normal, Vector3.yAxis)`
  — `lookAlong` is documented as exactly `lookAt(at, at + direction)`, and this
  gives a board that is genuinely parallel to the wall rather than eyeballed.

Snap every board through the same function. Nothing gets a manual rotation.

**Construction.** A board is a mounted physical object, not a floating GUI:
- A frame mesh with real depth and a bezel that catches the room light
- `SurfaceGui` on the face, `PixelsPerStud` tuned so text is crisp at reading
  distance, `LightInfluence` set deliberately (0 for a self-lit screen look,
  1 to sit in the room's lighting — pick per board and be consistent)
- Subtle emissive edge so the board reads at distance
- A floor decal or light pool marking the interaction zone (the existing
  "STAND TO ROLL" pad is the right idea — extend the language to every station)

**Legibility rule:** a player standing at the pad must be able to read every
value on the board without zooming. If they can't, the board is too dense —
split it or raise the type size.

## 4. Upgrade UI — full overhaul

Rebuild to match the Resets panel's structure, because that structure works:
header banner → scrollable body of uniform rows → one clear action per row.

**Row anatomy** (fixed height, no exceptions):
`[icon] [name + current effect] [cost] [buy button + state]`

- **Affordability is the primary visual signal.** Affordable rows are fully
  saturated; unaffordable ones desaturate — do not just grey the button.
- **Bulk buy** (x1 / x10 / x100 / Max) as a persistent segmented control in the
  panel header, not per row. Max needs the **closed form** for a geometric cost
  curve; looping to find the count is far too slow at scale.
- **Show the delta**, not just the cost: "Luck ×1.00 → ×1.12".
- **Hold-to-buy-repeatedly** with acceleration. Players buy in the hundreds.
- **Virtualize the list.** Recycle rows; only build what's visible. Use
  `ScrollingFrame.AbsoluteWindowSize` as the viewport (`AbsoluteSize`
  over-counts by the scrollbar gutter and leaves a one-row gap), and
  `GetScrollVelocity()` to keep rebinding smooth through touch momentum.
- **Do not wrap rows in `CanvasGroup`** — it renders as a blank texture past
  the client's quality cap and is documented as "recommended with static sizes".

**Stats panel specifically.** The four gauges are good; keep them as the hero
band. Below them, the flat stat list is the weak half — give rows the same
treatment as upgrade rows (icon, label, value, and a sparkline or trend arrow
where the stat has history). Right-align values with tabular figures so the
column scans.

**Performance rule for all of it:** Roblox's own MicroProfiler guidance says
that if `Process GuiEffect` is heavy, reduce `UIGradient` and `UICorner` **on
text labels**. With hundreds of labels this is the dominant cost. Bake gradients
and rounded corners into generated panel/row images instead of stacking live
effects on every label.

Update text at **10–20 Hz**, never per tick, and quantize → compare → skip:
if the displayed string hasn't changed, don't touch `.Text`.

## 5. Rarity naming — 10,000 names that lap

**Requirement:** ≥10,000 distinct names, index-driven, lapping past 10,001.
Resets key off the rarity *number*, so names are cosmetic — but they carry the
sense of escalation, so they must keep climbing in grandeur.

**Structure — 10 bands × 1,000 names.** Each band has its own lexical register
so the feel shifts as players climb:

| Band | Index range | Register |
|---|---|---|
| 1 | 1–1,000 | Mundane → notable |
| 2 | 1,001–2,000 | Material / elemental |
| 3 | 2,001–3,000 | Radiant / celestial |
| 4 | 3,001–4,000 | Cosmic |
| 5 | 4,001–5,000 | Temporal |
| 6 | 5,001–6,000 | Dimensional |
| 7 | 6,001–7,000 | Conceptual / abstract |
| 8 | 7,001–8,000 | Mythic / divine |
| 9 | 8,001–9,000 | Transcendent |
| 10 | 9,001–10,000 | Beyond-language / symbolic |

**Generation — collision-free by construction.** Per band: **100 roots × 10
prefixes = exactly 1,000**, no duplicates possible, no dedupe pass needed.

```
local function rarityName(n)          -- n >= 1
    local idx  = (n - 1) % 10000      -- position in the cycle
    local lap  = (n - 1) // 10000     -- how many times we've wrapped
    local band = idx // 1000          -- 0..9
    local i    = idx % 1000           -- 0..999 within band
    local root   = BANDS[band + 1].roots[i % 100 + 1]
    local prefix = BANDS[band + 1].prefixes[i // 100 + 1]
    return prefix, root, lap
end
```

Hand-write the first ~100 names (the ones every player sees) for quality, then
let generation carry the rest. The early game is where naming matters most.

**The lap marker.** Past 10,000 the name repeats, so the lap must be legible at
a glance and must read as *higher*, not as a bug:
- A numeral affix on the name
- An escalating frame treatment on the rarity card (metal → gem → prismatic)
- A distinct glyph count or halo ring per lap

Lap 0 shows no marker at all, so normal play never sees the mechanism.

Store only the **index**. Never persist a name string — names are presentation
and must stay re-skinnable without touching saves.

## 6. Rarity reveal — scale the spectacle to the rarity

**The current effect takes over the whole screen for everything. That is the
core problem: if every roll is a spectacle, none of them are.** The reveal must
be earned, and the ceiling has to stay reachable.

Tier the reveal by **odds**, not by index:

| Odds | Treatment |
|---|---|
| to 1/1e3 | No popup. Recent Rolls entry only. |
| 1/1e3 – 1/1e6 | Small corner toast, ~1.2 s, soft chime |
| 1/1e6 – 1/1e9 | Side banner, sound sting, card edge glow |
| 1/1e9 – 1/1e15 | Lower-third banner, particle burst, screen-edge vignette pulse |
| 1/1e15 – 1/1e30 | Partial takeover: camera push-in, chromatic pulse, hit-stop |
| beyond 1/1e30 | Full takeover with **bespoke VFX authored per named rarity** |

**Craft rules for the reveal:**
- **Stagger the stack.** Audio at t=0, particles at +16 ms, name card at +80 ms,
  counter/stat update at +150 ms. Firing everything on the same frame is what
  makes an effect feel cheap; the stagger is where the quality lives.
- **Hit-stop** on the top two tiers — a few frames of pause sells impact more
  than any particle count.
- **Never block input.** Even a full takeover stays skippable; a player rolling
  thousands of times will resent a 3-second cutscene by the tenth viewing.
- **Set `LightInfluence` explicitly on every emitter.** It defaults to **1** via
  Studio insert but **0** via `Instance.new()`, so artist-made and code-made
  emitters silently differ.
- **Pool every effect instance.** At this roll rate, creating them per event
  will cost frames.
- `Highlight` caps at **255 client instances**, and disabled ones still hold a
  slot — delete rather than disable.
- **Randomise `PlaybackSpeed`** on repeated sounds. Cheapest quality win
  available; its absence is most of why repeated audio grates.

**Bespoke tier.** The rarest entries get hand-authored effects — that is the
payoff for the whole climb. Build a small effect-definition module so a named
rarity can declare its own emitters, sound set, camera move and duration,
falling back to its tier default when unspecified.

## 7. Verification

- **Blind side-by-side.** Screenshot a panel next to a screen from a genuinely
  premium game, strip labels, have someone who didn't build it pick the better
  one. Don't score against a rubric — scores inflate and stop discriminating.
- **Read test:** stand at each station, read every value without zooming.
- **Roll-rate test:** hold roll for two minutes. Effects must not accumulate,
  audio must not grate, frame time must stay flat.
- **Lap test:** force rarity index to 9,999 / 10,000 / 10,001 / 20,001 and
  confirm names cycle and lap markers escalate correctly.
- **Profile on a real low-end phone**, and check `Process GuiEffect` specifically.
- **You cannot read the client's graphics quality** —
  `UserGameSettings.GraphicsQualityLevel` is `RobloxScriptSecurity`, and
  `SavedQualityLevel` returns `Automatic` by default. Build effect degradation
  on **measured frame time**.


---

# Round 2 — board craft, colour system, and the chromatic language

Supersedes anything above that conflicts.

## 8. The chromatic treatment is the design language

The holographic sheen on the Transcend button is the house style. Promote it
from a one-off to a system.

**How to build it:** a `UIGradient` over the button's base fill, with a narrow
bright band in its `ColorSequence`, animated by driving `Offset` (and slightly
`Rotation`) on a loop. Keep the band narrow and the peak just above the base
value — a wide or blown-out sweep looks cheap. Mask to the button shape.

**Make it carry state**, so the sheen is information, not decoration:

| State | Treatment |
|---|---|
| Locked | Desaturated, **no sweep**, flat |
| Not yet | Slow, dim sweep — alive but not calling you |
| Ready | Full-brightness sweep, faster cycle, subtle outer glow |
| Hover / focus | Sweep speeds up, bezel brightens |
| Just purchased | One bright pulse, then settle |

Same treatment on reset buttons, station prompts, ready pads, and the roll
button. A player should learn "shimmer means available" in the first minute.

**Cost note:** animated `UIGradient` on a handful of large buttons is fine.
Animated gradients on *hundreds of list rows* are not — Roblox's own profiler
guidance calls out `UIGradient` and `UICorner` on text labels as the dominant
GUI cost. Buttons get live sheen; rows get it baked into their background image.

## 9. Board dimensions — wide, not tall

Current boards read as tall columns (the Prestige Upgrades board especially).
Tall boards force scrolling, shrink type, and read as cramped.

**Rules:**
- Target aspect between **16:9 and 2:1**. Never taller than wide.
- **Reset layers:** all layers visible at once with no scrolling. Three layers
  today, so three full-width rows — wide rows, generous vertical padding,
  large type. If layers exceed five, paginate rather than growing the board.
- **Upgrade boards:** multi-column grid (2 or 3 columns by board width), not a
  single long column. A 3×4 grid of twelve upgrades in one glance beats a
  twelve-row scroll.
- **One idea per row.** Name, effect delta, cost, state. Nothing else.
- **Readability gate:** stand at the interaction pad and read every value
  without zooming. If you can't, the board is too dense. Split it.

**Finish:** real frame depth with a lit bezel, panel background baked as a
generated image (gradient + subtle noise, not flat colour), consistent internal
margins, and a single accent hue per board matching its header banner.

## 10. Rarity colour system — make the colours match

The rarity list currently mixes colours without a rule, which is why it reads
as noisy. Derive every colour from one source instead.

**Bind colour to the rarity band** — the same 10 bands as the naming scheme in
§5. One hue family per band; within a band, step lightness/saturation by
position. Then:

- Row label, index chip, icon tint and odds text all derive from **that one
  band colour**. No hand-picked per-row colours anywhere.
- Rising bands climb in visual energy: early bands muted and low-chroma, later
  bands saturated, top bands prismatic/animated.
- Keep contrast ratios legible on the dark panel — check the lightest and
  darkest band against the background, not just the mid ones.
- **Colour is never the only signal.** Every row also carries its numeric
  index, so a colour-blind player loses nothing.

Store the band palette as data and generate the swatches — with 10,000
rarities, hand-authoring colour per rarity is impossible, and a generated ramp
is the only thing that stays consistent.

**Rarity list layout:** the two-column numbered list is good. Keep the index
prominent (it is the real currency of progress), right-align odds with tabular
figures so the column scans, and mark the player's current best inline rather
than only in a separate header.

## 11. Roll button and the auto-roll flame

- **The flame is off-centre because it is positioned by a fixed offset.**
  Anchor it to the button's true centre instead: `AnchorPoint = (0.5, 0.5)` and
  `Position = UDim2.fromScale(0.5, 0.5)` within the button, so it re-centres
  automatically at every resolution. If it is a world-space emitter, derive the
  attachment from `AbsolutePosition + AbsoluteSize/2` rather than a constant.
- **Make it layered rather than one sprite:** a bright core, a soft outer glow,
  and sparse rising sparks. Tie intensity to auto-roll speed so holding R
  visibly spins the button up.
- **Set `LightInfluence` explicitly** on every emitter — it defaults to 1 via
  Studio insert and 0 via `Instance.new()`, so hand-placed and code-made
  emitters silently differ.
- **Pool the particles.** At auto-roll rates, creating them per roll costs
  frames.
- The fill/progress bar and the flame should share one timing source, so they
  never visibly disagree.
- Give the button the §8 chromatic treatment at rest so it reads as the primary
  action on screen.
