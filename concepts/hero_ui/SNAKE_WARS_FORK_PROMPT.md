# Fork prompt: bring the Peckwood hero-UI treatment to Snake Wars (Venom Candy)

Paste everything below the line into a new chat.

---

We're doing the UI for the Snake Wars relaunch ("Snake Wars 🐍 +1 Length Every Second"). The whole UI already exists in
Figma as "Venom Candy" (26 desktop + 10 phone screens), but it doesn't look as good as my other game Peckwood. The job:
**upgrade the existing Venom Candy screens to Peckwood's quality.** Keep Snake Wars' identity and layout logic, and
raise the craft, depth and effects. Before you change anything, read the sources below and audit the Figma screens
against the "Peckwood bar" checklist. Then upgrade ONE hero screen first and show me before/after.

**Snake Wars sources (read these first)**
- Game overview and roadmap doc: https://claude.ai/artifact/BKx4JyKAjmFLUpftXU6u8f (the "UI: Venom Candy" section
  lists every screen and its status)
- Rebrand proposal doc: https://claude.ai/artifact/74yxdNwkKT2m4SH7MeTVms (its "UI: the glossy kit" section has the
  main menu, popup anatomy, HUD layout and the two technical rules)
- Game layout page: https://claude.ai/artifact/5GcZSeWcZW5j7A4vMV3caS
- The Snake Wars code lives in the `snakewars-25d` project, with `docs/design/UI_DIRECTION.md`, `EGGS.md`,
  `SKINS.md` and `PROGRESSION.md`. It is NOT in jewdah-afk/research-calculator. Find it with list_repos/add_repo;
  if it isn't there, ask me where it is. The Venom Candy Figma file (26 desktop + 10 phone screens) is linked from
  UI_DIRECTION.md or the roadmap; if not, ask me for the link.

**Venom Candy rules (keep them)**
- Glossy candy buttons with thick ink outlines.
- Faceted gem surfaces that echo the low-poly Snake Eggs, and a faint snake-scale texture on panels.
- Ribbons end in fang tips, and the close key is a round red gem.
- Fonts: Luckiest Guy for titles and big numbers, Source Sans Pro Heavy Italic for labels.
- Length is always gold and rates are mint.
- Icons are 3D renders.
- Roblox build: only Frames, UICorner, UIStroke and UIGradient, with no EditableImages.
- WARS stays fair: nothing on screen sells arena size.

**The Peckwood bar: why it looks better (score every Venom Candy screen against this)**
1. **One focal point per window.** A big hero stage shows the selected thing large, the title has a status chip
   beside it, and there is ONE loud primary key. Everything else is calmer: dimmer secondary tabs, values at about
   70 % white, and unselected rows that sit back.
2. **Real art, not flat fills.** A painted scenery header, and a full-bleed stage image ending in one 4 px ink line.
   Depth comes from layers and parallax, not from more boxes.
3. **3D renders everywhere:** cel-shaded, ink-outlined toy renders for every character and item, and the boss turns
   to face the cursor.
4. **Consistent craft:**
   - the same ink weight everywhere (4 px windows, 3 px rows and chips);
   - one 2 px top highlight per surface;
   - three surface tiers;
   - the key recipe (ink body, lip, face; press-in drops the whole key, no squash);
   - labels never under 15 px, and zero clipping or overlap at 1:1.
5. **Everything moves with purpose:** odometer numbers with a small gold suffix, live timers synced in every place
   they appear, rows cascading in, a light sweep on the primary key, and a reward sequence (slam, shake,
   shockwave, card flip, coins flying into the wallet).
6. **Two style variants from one token set,** so a colour direction can be judged side by side.

**What to carry over from Peckwood (references, not its colours or art)**
Live prototype: https://claude.ai/artifact/LmwbnbygFJ8unmke9HVkWV. Its source is
`concepts/hero_ui/hero_ui.src.html` in jewdah-afk/research-calculator, branch `claude/peckwood-isle`, and its
"How it maps to Roblox" panel is the effect spec.
1. **Hero stage in list + detail windows.** A slim numbered rail on the left (plate, icon, name, live status chip),
   a big stage on the right with the selected item as hero art, the title with a status chip beside it, then
   details and ONE primary key that carries the status. For Snake Wars: Worlds and Stages, the Egg Stall, Pets,
   Skins and the Rebirth altar.
2. **Painted scenery banners in headers, and a full-bleed stage image.** One painted header per World (Sprout
   Meadow, Tidepool, Crystal Caverns, Frostbite, Magma, Void). The stage art runs edge to edge and ends in one
   4 px ink line, the same way the header does. Painted scenery only; characters and items always use the game's
   own art.
3. **Depth parallax.** Cut each stage painting into 3 layers (far, mid, foreground), fill in the far plate behind
   the cut-outs, and ease each layer toward the cursor by a different amount, with a slow idle drift for phones.
4. **3D renders from Blender (no credits needed).**
   - Blender runs in the container with `pip install bpy opencv-python-headless`.
   - Port `tools/boss3d/inflate.py` from research-calculator. It turns any icon into a smooth inflated toy mesh,
     cel-shades it (light/mid/shadow bands, rim band, crisp highlight) and adds an inverted-hull ink outline.
   - It renders 17 look-around frames (yaw -40 to +40) plus a .glb.
   - Use it for the World guardian bosses (OAKCOIL, CORALCROWN, PRISMARA, BLIZZARA, IGNIS, VOID WARDEN), Hatchlings,
     Snake Eggs, Fangs and the HUD and shop icons.
   - The boss turns to face the cursor by picking the matching frame. In Roblox it's a flipbook ImageLabel (16
     frames × 256 px in one 1024 sheet), or the mesh in a ViewportFrame.
   - Match the cel light colours to Venom Candy.
5. **Big-moment effects** for Stage clear, boss kill, World unlock, hatch reveal and rebirth:
   - a per-letter slam title, a screen shake, and shockwave rings from the key and the title;
   - drop cards flipping in with overshoot, sparkle bursts, and rays behind rare cards;
   - coins and Length flying into the wallet and Length chip, with odometer number rolls and "+amount" floats.
   - Everything stays Roblox-feasible: no shaders, no blend modes, no conic gradients, no skew, no letter-spacing,
     no CSS filters on icons.
6. **Live state.** Per-item data, synced timers (restock, boss respawn, OP! gift) on the rail, the title chip and
   the key, and state that changes after an action.
7. **Two style options side by side** from one token set: Venom Candy as designed, and one bolder variant. I pick.

**How to work**
- Start from the real Figma file: screenshot every Venom Candy screen, score each one against the Peckwood bar, and
  give me a ranked list of what's holding each screen back.
- Then upgrade ONE hero screen: the Worlds and Stages window over the hub, with the World guardian in 3D on its stage.
  Build it as an HTML prototype artifact (like the Peckwood one) and as a duplicated, upgraded Figma frame next to
  the original, then show me before/after. Wait for my reaction before doing the rest.
- In Figma, never redraw from scratch; duplicate the real Venom Candy frames.
- QA everything zoomed in before showing me. Use the ui-qa, visual-hierarchy, style-guard and roblox-feasibility
  agents (the definitions are in research-calculator `.claude/agents/`; copy them over).
- Paid tools: Weave image-to-3D is blocked until I upgrade, and Figma image generation costs credits. Ask before
  spending.
- Commit and push as each part lands, and keep a handout doc updated.
