# UI style guide (from the "SHOP / Starter Pack" reference)

Every window, card, button and in-world panel follows these rules, in both the browser preview and Roblox.

## 1. What the reference is made of

| Element | Observed detail |
|---|---|
| **Window frame** | Thick black outline (~4px at 1x) with rounded corners (~12px). Charcoal body (#2e3036 → #26282d top to bottom). A faint giant swoosh/emblem watermark in the body (white at ~5%). |
| **Header bar** | Full-width, ~56px tall. Sky-blue vertical gradient (#63ccff → #2b8de6). No studs. A glossy top half (~20% white fading out at the middle), a slow diagonal sheen that drifts across (7s, back and forth), a 3px lit top edge and a 12px darker bottom lip. Two soft diagonal gloss streaks. A 3px black rule on the bottom edge. |
| **Title** | "SHOP": heavy rounded display face, white, thick dark navy/black outline (~3–4px), hard 2–3px drop shadow straight down. Left-aligned with ~24px inset. |
| **Close button** | Square, flush in the header's top-right, same height as the header. Red gradient (#ff4b4b → #d31b1b), same gloss and lip, no studs. A 3px black divider on its left. White chunky "X" with a black outline. |
| **Item card** | Inset panel inside the body. Darker charcoal (#3a3c43) with a diamond-lattice pattern (thin lines, ~6% white). 3px black border, 6px radius. A 1px light bevel on the top inner edge and a darker inner bottom edge. |
| **Card title** | "Starter Pack": same display face, white, outlined, top-left. |
| **Left art area** | A halftone dot field that fades out to the right, with a grey sunburst (radiating rays) behind it. |
| **Item tiles** | Squares in rarity colours: grey, green, blue, purple. A sunburst of lighter rays from the centre. A darker 3px bottom lip that makes a 3D block. Black outline. "???" sits over the top edge in white with a black outline. |
| **Small icon tile** | Pink/purple square holding the gift icon. Same black outline. |
| **Price button** | Bright green (#46ef55 → #1db52c), black outline, white "199" with a currency glyph, both outlined. A light bevel along the top edge. Wide and short, aligned to the right of the card. |
| **Overall** | Toy-like and chunky. Every shape has a black outline, a bevel or lip, and saturated primaries over neutral charcoal. Texture (gloss, lattice, halftone, sunburst) is subtle and never fights the text. |

## 2. Tokens

```
Frame      #0b0c10 outline, 4px; radius 12px
Body       #2e3036 → #25272c, watermark swoosh 5% white
Card       #3a3c43 → #33353b, lattice 6% white, border 3px #0b0c10, radius 7px,
           bevel: inset 0 2px 0 rgba(255,255,255,.12), inset 0 -3px 0 rgba(0,0,0,.35)
Header     blue   #63ccff → #2b8de6   (default windows)
           purple #c47dff → #7a3fe0   (prestige / runes rare)
           gold   #ffd84a → #f0a412   (rewards)
Close      #ff4b4b → #d31b1b
Buy        #46ef55 → #1db52c   (all purchases)
Secondary  #5aa9ff → #2f6fe0   (neutral actions)
Rarity     grey #9aa0ab · green #3fdc5a · blue #3a9bff · purple #b45cff · gold #ffc63a · red #ff4f6a · cyan #5cf2ff
Text       white display face; outline #0b0c10 at 0.12em; drop shadow 0 0.08em 0 #0b0c10
Sub-text   #b9bdc8 body face, no outline
```

## 3. Type
- **Display** (titles, numbers, buttons): Lilita One. Fallback: Fredoka 700.
- **Body** (descriptions, small stats): Fredoka 600.
- **Hierarchy:**
  - Window title 30px
  - Card title 20px
  - Big number 22–28px
  - Button 16px
  - Sub-text 12–13px

## 4. Components
1. **Window** = frame + header (title, close) + body (padding 12px, gap 10px).
2. **Card** = inset lattice panel. The title sits top-left; content sits on the right.
3. **Tile** = rarity square with sunburst and bottom lip, and an optional ??? / count badge.
4. **Buttons:**
   - Buy (green): price plus a currency icon.
   - Secondary (blue).
   - Danger (red).
   - Toggle on (gold).
   - All buttons share the outline, a 4px bottom lip and pressed-down movement.
5. **Toast** = mini window: a tile on the left, the title strip on top, outlined headline.
6. **Tabs** = secondary buttons. The active tab uses the header colour and sits 2px lower (pressed).
7. **In-world panels** use exactly the same window/card/tile drawing, rendered to a texture (preview) or a SurfaceGui (Roblox).

## 5. Visual hierarchy rules
- **Window level:** one header colour per window. The colour says what the window is: blue = info, purple = runes and prestige, gold = rewards.
- **Primary action colour:** green means "spend", only ever. Only one green button per card.
- **Locked and undiscovered:** dark tile with "???". Found items get their rarity colour and a sunburst.
- **Biggest text:** big numbers (counts, multipliers) are the largest text inside a card. Labels sit above them, smaller and muted.

## 6. Stat colours (one per stat, used everywhere)
Every place a stat appears uses its colour: label, value, icon tile and progress bar.

| Stat | Colour |
|---|---|
| Rune luck | green #4cf05a |
| Rune bulk | red #ff4848 |
| Rune speed / rolls per second | blue #3aa8ff |
| Clone (chance and amount) | yellow #ffd84a |
| Tickrate | purple #c47dff |
| Opened / rolls | cyan #5cf2ff |
| Discovered | orange #ff8a3d |
| Pad time | amber #ffb13a |
| Milestones | pink #ff5caa |
| Gems | cyan #5cf2ff |
| Cash | gold #ffd84a |
| Boost amounts ("+25% cash") | lime #7cff5b |

## 7. Corrections from a zoomed-in pass (these win over sections 1–3)
- **No studs anywhere in the UI.** Headers, buttons and the close button use smooth gradients with a glossy top half, a lit top edge and a dark bottom lip for depth. Headers also have a slow drifting sheen.
- **Header:**
  - **Brush slashes:** 3–4 translucent curved white slashes (~20%) sweep diagonally across the right half. They replace neat gloss bands.
  - **Bottom lip:** a thick darker band (~11px, navy for blue headers, deep purple for purple ones) above the 4px black rule.
  - **Size and title:** the header is about 58px tall, with a 32px title.
- **Title font:** wide and round (Fredoka 700 / Fredoka One), not condensed. Fill is white fading to light grey (#fff → #c3c6cf), with a heavy black outline and a 3px drop.
- **Close button:** a fat outlined "X" in the same title treatment. The red gets the same gloss and a dark red bottom lip.
- **Window body:** semi-transparent charcoal (~85%) with the world blurred behind it. A large tribal swoosh emblem sits at ~7% white.
- **Cards:**
  - **Border:** double: 3px black outside, then a 2px light grey rim (#b2b6c0 at ~55%) inside.
  - **Lattice:** diamond pattern drawn with dark lines (~28% black) plus a faint light inner line.
  - **Feature cards:** a lower-left corner with a sunburst and halftone squares.
- **Tiles:** no black outline. They have a 2.5px rim in a lighter tint of their own colour, a thin outer dark ring, and alternating light/dark sunburst rays over a soft top-to-bottom gradient.
- **Buttons:** flatter and brighter, with a 2px inner light rim and a small bottom shade. The buy button is neon green (#3dff7a → #0ff52e).
