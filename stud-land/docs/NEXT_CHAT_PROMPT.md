# Stud City Incremental: brief for the next session (Roblox Studio)

Start the new chat on my computer (Claude desktop app, or Claude Code running there) with our place open in Roblox Studio and the Studio MCP connected, so you can see the real icons. Paste this whole file into it, and attach:
1. The Shop reference screenshot (the dark "Shop!" panel with Featured, Gamepasses, Cash and Codes).
2. The current Studio HUD screenshot (Welcome Back popup open, 58.3B Studs).
3. The two screen recordings (ScreenRecording 17-31-34 and 19-38-35).

Playable reference (the "artifact game"): https://claude.ai/artifact/DP3yFnm8tcoDsNek5Mgh3L
Its source: GitHub `jewdah-afk/research-calculator`, branch `claude/stud-land-html`, folder `stud-land/`.
My Roblox user ID: 5167569069.

---

## 1. The goal

1. **World, effects, sound: copy the artifact game.** Bring its map design, visual hierarchy, VFX, GFX and SFX into our real Roblox game as the hero layer over everything.
2. **UI and HUD: keep ours, upgrade it.** Same layout, same icons, same buttons and screens we already have in Studio. Rebuild every frame, bar, button, pill and panel around them to AAA quality, in the style of the Shop reference. Do not replace our UI with the artifact's UI.
3. **Same build as the reference, your own design.** Use the same UICorner radii, UIStroke outlines, UIGradient fills, backgrounds (halftone, gloss, ink drop shadow), fonts and motion as the Shop reference, everything it does. But make the design your own: an original take in that style, not a copy of the reference.

Work directly in Roblox Studio on the open place (Studio MCP), or through Open Cloud with the API key. Work on a copy or a test place first, never on the live place without asking.

## 2. Hard rules

- **Never edit, redraw, recolour or replace our icons.** Use the exact icon assets already in the Studio place (read their `Image` asset ids from the existing ImageLabels and reuse them). Only the UI around them changes.
- **Keep our HUD layout** (section 4). Everything stays where it is. It just looks far better and has clear visual hierarchy.
- **Keep our game logic.** Do not change currencies, formulas, rates, costs or save data. Visual and audio changes only, unless asked.
- **Text:** no em dashes anywhere. At least 24 px for in-game text on phone. Nothing that looks AI-generated.
- **Mobile first:** landscape phone is the main target, then tablet and desktop. Respect the Roblox top bar and safe areas.
- **Screenshots:** send before and after screenshots in chat, grouped by screen, not zipped.

## 3. The style to apply (from the Shop reference)

Apply this language to every frame of our UI. Same corners, strokes, gradients and backgrounds as the reference, but make the result your own:

- **Frames:** dark navy window (about #2b3a62 at the top to #171f38 at the bottom), thick near-black outline (#141024, 4 px), a thin light inner line, and a hard ink drop shadow under it.
- **Title tab:** hangs over the top-left edge, with a tilted 3D icon sticker and a big outlined title ("Shop!").
- **Close button:** red square X in the top-right corner, outlined.
- **Side tabs:** arrow-shaped category tabs on the left edge of a panel. They jump to each section and light up as you scroll.
- **Section headers:** centred, "icon TITLE icon" (like the crown FEATURED crown row).
- **Cards:** saturated gradients (gold, purple, green, blue, red, orange, pink, teal, navy), a halftone dot pattern fading from the top-left corner, a soft gloss over the top half, and a thick outline. Big 3D icon on the left, title plus short perk lines on the right.
- **Price and action buttons:** chunky lime (#f1ff8c to #bdf43c to #6fd41c), outlined white text, Robux icon plus price. A shine sweep runs across ready buttons.
- **Cash grid:** small cards plus one tall "BONUS" card.
- **Codes:** a gold REDEEM CODES! card with a dark input and a lime Claim! button. A "THANK YOU FOR YOUR SUPPORT!" footer sits under it.
- **Text:** white with a thick dark outline everywhere. Use FredokaOne for labels and LuckiestGuy for big numbers; both exist as Roblox fonts.
- **Depth and motion:** buttons press down 3 px, and their drop shadow shrinks when pressed. Panels pop in (scale 0.88 to 1, Back easing). The title tab drops in just after the panel. Notification badges pulse.

Roblox build for each part: `UIStroke` (Border for shapes, Contextual for text), `UIGradient`, `UICorner`, a tiled halftone `ImageLabel` masked by a transparency `UIGradient`, a gloss Frame, and an ink drop Frame offset 4 to 6 px. The full token list and every part's recipe are in the artifact's **FX LAB > UI KIT** tab. That tab is committed on the branch (commit `fb82a55`) but not in the published link yet, so read it from the repo, `stud-land/js/lab.js` (`UI_KIT`).

## 4. Our HUD today (keep this layout, upgrade the look)

From the Studio screenshot and the recordings (landscape):

**Top left, the main currency block**
- Studs: the 3D green brick icon, the big green outlined number (58.3B), and the green + button, which opens the Shop's cash section.
- Under it: the rate pill (up-arrow icon, "+71.6M/s") and the boost pill (potion icon, "X2 5:22:45").
- The currency bars (purple): Alpha Bricks (teal alpha brick icon), Loops (rainbow infinity), Tickets (ticket). Each shows a small name, the amount, and a rate top right. Then the "+3 MORE" pill.

**Left column, the main buttons**
- DAILY REWARDS: a wide rainbow button with the gift icon and a "!" badge.
- A 2x2 grid of big square buttons:
  - SHOP (pink, bag icon, count badge)
  - PASSES (yellow, pass tag)
  - REBUILD (blue, brick with arrows, READY! tag)
  - INDEX (blue, book)
- COMMUNITY panel: likes (+10% production), favourites (+8% rebuild) and group members (luck), each with a progress bar.

**Top right**
- A row of square icon buttons with hotkey chips: settings (gear), mute (speaker), codes (tag), effects (wand), map, home (house).
- STARTER PACK offer: purple gift, "!" badge, timer.
- 2X PRODUCTION (FOREVER) offer card.
- SERVER BOOST (x2, 15 MIN) offer card.

**Bottom centre**
- "X2.66 MULTIPLIER" label.
- The plot bar: island icon, plot name (COIN MINT), and progress (0 / 12).
- Buy mode buttons X1, X5, X10, MAX, with hotkey chips; the selected one is green.

**Bottom right**
- Multiplier icons: flag x1.1, P badge x1.1, thumbs up x1.1, potion x2 with a timer.

**World plot signs**
- Navy panels with a lime outline. The top line shows the plot code and level ("LW-02 8/1080"). The big line shows the rate ("1.79 Loops", lime) or the rebuild gain ("BL-02 +23.9 Blueprints", gold). There's a progress bar underneath.

**Popups and menus we already have**
- **Welcome Back:**
  - moon icon and title bar
  - the "away for X, worth Y (soft-capped after 2m)" line
  - currency cards in 2 columns: Studs, Coins, Arcade Chips, Tickets, Alpha Bricks, Loops
  - the NIGHT SHIFT: NO SOFT CAP upsell
  - the COLLECT button
- **Shop:** pink header, tabs Featured, Ranks, Boosts, Server, Passes, Time Warp, Cosmetics (My Style), Support. It's mostly empty today.
- **First Rebuild confirm:**
  - gold card "+22.8 BLUEPRINTS"
  - RESETS and KEEPS rows
  - "Don't ask again" checkbox
  - CANCEL and REBUILD +24 buttons
- Index, Settings and Codes.

## 5. What "upgraded" means for each piece

- **Visual hierarchy first:**
  - The Studs number is the loudest thing on screen.
  - The action buttons (Shop, Passes, Rebuild, Index, Daily Rewards) come second.
  - Secondary currencies, offers and multipliers come third.
  - Plot signs and small hints come last.
  - Only one element may pulse or glow for attention at a time.
- Every bar and pill gets the frame treatment (outline, gradient, gloss, drop), consistent corner radii, and one spacing grid.
- The 2x2 buttons and Daily Rewards become reference-style cards: gradient, halftone, gloss, our icon large and overlapping the top edge, and outlined labels.
- Offer cards (Starter Pack, 2X Production, Server Boost) look like the reference's Featured cards, with lime price buttons.
- **Shop:** rebuild it as the reference layout: side tabs for our categories (Featured, Ranks, Boosts, Server, Passes, Time Warp, Cosmetics, Support, Codes), sections with headers, and 2-column cards. Fill the empty tabs with properly designed cards. Mark prices as placeholders if they aren't set yet.
- **Passes** opens the Shop at the Passes section.
- **Daily Rewards:** a 7-day card grid (day 7 big), with CLAIM on today.
- **Welcome Back:** keep its content and layout, restyled: the frame, currency cards as reference cards, the upsell as a Featured card, and COLLECT as a big lime button.
- **First Rebuild confirm:** keep the content, restyled. The reward card becomes a gold reference card and the buttons become lime and navy.
- **Plot signs:** keep navy and lime, add the frame treatment and a crisp outline, and make them readable at every zoom.
- **Motion and sound on every button:** press, hover, open and close tweens. A shine on ready buttons. Count-up tickers. A badge pulse. UI sounds from the artifact's sound kit.

## 6. The hero layer from the artifact game (world, VFX, GFX, SFX)

Everything is specified with exact numbers and a Roblox recipe in:
- `stud-land/docs/REFERENCE.md`: architecture, world space, plots and props, machines, light and colour, weather, life, the effects and attention budget, HUD, walk mode, meta, sound, performance and the wow layer (section 14).
- The artifact's **FX LAB** (dev bar):
  - 39 effects, each with its trigger, tier, spec and Roblox recipe
  - 75 sounds and 14 haptics
  - **EXPORT** gives one JSON of all of it
- `stud-land/docs/LUA_PORT.md` covers the game math, if needed.

Bring over, in this order:
1. **Visual hierarchy of the world:**
   - readable plots
   - a machine size that grows with level, going gold at max
   - lit windows at night
   - clear signs
   - calm ambient life that never fights the HUD
2. **Buy feedback:**
   - a brick snap with a rising pitch ladder
   - squash and stretch
   - a stud burst
   - hold to buy
3. **New plot:**
   - the plot assembles from 25 falling tiles, then its machines pop up
   - letterbox, camera fly-to, hit-stop, splash, confetti and the NEW PLOT banner
4. **Rebuild:** the crumble, the shockwave and the stinger.
5. **First-play intro:**
   - cloud dive
   - the city builds itself
   - the builder parachutes in
   - the HUD slams in piece by piece
6. **City tiers:**
   - Village, Town, City, Metropolis, each with a one-time celebration
   - the STUD CITY hillside sign
   - the downtown skyline
   - the Stud Express train
7. **Day and night, weather and sky:**
   - god rays and the sunset sea
   - aurora
   - shooting stars
   - the sea serpent
   - milestone takeovers
   - bloom on high quality
8. **Sound:** the full synth-spec sound kit and adaptive music, with the UI sounds on the new HUD.

Attention budget (keep it):
- **Hero moments:** one at a time. Forced heroes still claim the slot.
- **Support effects:** at most 3 starts per 250 ms.
- **Ambient effects:** these go first when the budget is tight.
- **Flashes:** at most 2 per second.
- **Reduced motion:** Full, Reduced and Minimal modes.

Badge pops and overlays wait for hero moments and open panels.

## 7. How to work

- Work on my computer with the place open in Studio. Look at our real icons in the place first, and read their asset ids from the existing ImageLabels. Never guess, recreate or swap them.
- Prefer the Roblox Studio MCP on the open place.
- Otherwise, Open Cloud with the API key works:
  - upload images and sounds as assets
  - run Luau against a place to read its UI tree and icon asset ids
  - publish place versions
- The earlier Milestone Tree pipeline is a working example of building places and uploading assets. It's on branch `claude/roblox-project-continue-x136d3`: `milestone-tree/art/roblox/upload.js` and the `MilestoneTree.rbxlx` build.
- Start by dumping our current StarterGui (every ScreenGui, Frame, ImageLabel and its Image id). Then build the upgraded UI as ModuleScripts (a small UI kit: Frame, Card, Button, Pill, Tab, TitleTab, CloseButton, SectionHeader, Badge) and restyle our screens with it, keeping our icons and names.
- Test on phone landscape (Device Emulator) and desktop. Send screenshots before and after, grouped per screen.
- Commit the source to the repo (a new branch), and publish only to a test place until I approve.

## 8. Done means

- Every HUD element and menu listed in section 4 is restyled in the reference style, with our icons unchanged and our layout kept.
- The Shop and every other menu has the reference layout (side tabs, section headers, cards, lime price buttons, codes card).
- The world, effects and sound from the artifact game run in our game within the attention budget, with Full, Reduced and Minimal modes.
- Phone landscape, tablet and desktop are all checked, with screenshots sent.
- Nothing in the game logic changed.
