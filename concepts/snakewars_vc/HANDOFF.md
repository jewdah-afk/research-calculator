# Snake Wars · Venom Candy → Peckwood bar: handoff

Branch: `claude/snakewars-venom-upgrade` (jewdah-afk/research-calculator). Started from a phone chat, which has no Roblox
Studio access, so the Studio work moves to a desktop chat. Paste the prompt at the bottom into that chat.

## Where things are

- **Figma file:** `6ghy7bHkwpGaQ82Ha0n5gy` ("Snake Wars 2.5D — UI Revamp").
  - VC pages: `92:3` HUD & Menu, `115:1747` Collection, `115:1748` Popups & Play, `117:2` Shop & Eggs, `92:2` Foundations.
  - Hero screen to upgrade: **Worlds · Desktop `129:52438`** (Collection page) and Worlds · Phone `130:55816`.
  - Its boss slot (`129:53197`) is a recoloured skin placeholder ("Glacier Fang").
  - Art sources: `118:1148` (eggs, skins, hatchlings) and `120:40457` (egg renders). Hatchling 3D renders are in `205:29918`.
- **Before screenshots (all 41 VC frames):** `concepts/snakewars_vc/before/`.
- **Audit vs the Peckwood bar:** `concepts/snakewars_vc/AUDIT.md`, which has scores, a ranked list, patterns and content mismatches.
- **Snake Wars docs** (Claude Docs):
  - Roadmap: https://claude.ai/artifact/BKx4JyKAjmFLUpftXU6u8f
  - Rebrand: https://claude.ai/artifact/74yxdNwkKT2m4SH7MeTVms
  - Layout: https://claude.ai/artifact/5GcZSeWcZW5j7A4vMV3caS
- **The `snakewars-25d` repo** could not be reached from the cloud session. It is not under jewdah-afk. A desktop chat
  can open it locally.

## Audit headline (worst first; full table in AUDIT.md)

- **Lowest scores:** billboards and settings at 5/15. Boosts, codes, gift 1/2, main menu, pets index, quests
  achievements and Worlds phone are at 7. Worlds desktop is at 8.
- **No single primary key per window.** Green Robux keys and the red OP! gift compete on Hub, Pets, Egg Stall, Shop,
  Daily and the Reveal screen.
- **Colour is overloaded.** Green does rates, buy, claim and ribbons all at once. Gold does Length, trophies and
  multipliers.
- **Many labels are under 15 px**, especially on phone.
- **Almost no real art.** No screen has painted headers or a full-bleed stage.
- **Content is wrong in places:**
  - Worlds shows 8 Worlds ("World 4 of 8"). Launch has 5 Worlds plus the Void Climb.
  - Pets index and Skins still reference the cut Worlds (Candy Canyon, Starfall Nebula, Crown Core).
  - Egg Stall shows Frostbite locked while Worlds shows the player at Frostbite stage 17.
  - The boss name doesn't match. The Frostbite stage-20 boss is GLACIER PYTHON, and the guardian is BLIZZARA.
  - Some phone screens show PC-only hints.

## Made so far

- `tools/boss3d/guardian.py` builds the six World guardians procedurally in Blender:
  - OAKCOIL, CORALCROWN, PRISMARA, BLIZZARA, IGNIS and VOID WARDEN.
  - Each is a coiled toy snake with big eyes and fang tips, plus a per-World crown.
  - It uses the same cel shader and inverted-hull ink outline as `inflate.py`.
  - Outputs: still, a 17-frame look-around sheet (yaw −40..+40) and a `.glb`.
  - Results are in `concepts/snakewars_vc/3d/bosses/`.
- `tools/boss3d/scenery.py` (untested) builds a toy-brick diorama per World: a studded road, gate wall, props and sky.
  It renders three parallax layers (far is opaque, mid and fg are transparent).
  - Test with: `python3 tools/boss3d/scenery.py frost <out> --w 800 --h 380 --samples 8`.
- Blender for Python: `pip install bpy opencv-python-headless`.

## Next steps (in order)

1. **Studio QA.** Look at what is already in Studio, list bugs, and compare it against the Figma frames.
2. **Restore the shop and icons.** Cookie's Astra pass edited the game directly inside Studio, not in git. Those
   changes are AI-generated icons and a reworked shop, and only the live place shows them.
   - Diff the place against the `snakewars-25d` source to find what Astra changed. Studio's Version History (or the
     published place versions) and the Asset Manager can help.
   - Restore the original icon asset IDs and shop from the repo source, or from an earlier place version.
   - Then lift them to the new Figma standard.
3. **Upgrade the Worlds hero screen:**
   - Rail of 5 Worlds plus the Void Climb, each with a live status chip.
   - A full-bleed stage using the World scenery layers with parallax, and the guardian in 3D turning toward the cursor.
   - The title gets a status chip, and there is ONE primary key ("PLAY STAGE 17").
   - Build it as an HTML prototype artifact, plus a duplicated, upgraded Figma frame next to `129:52438`. Never redraw;
     duplicate the real frame.
   - Show the owner before and after, and wait for their reaction.
4. Then do the Egg Stall, Pets, Skins and Rebirth the same way.

## Fork prompt (paste into a desktop chat with Roblox Studio open)

> Continue the Snake Wars UI work. Read `concepts/snakewars_vc/HANDOFF.md` on branch `claude/snakewars-venom-upgrade` in
> jewdah-afk/research-calculator first. It covers the Figma file, the audit, the 3D guardians and the next steps.
> Also open the `snakewars-25d` project locally, including `docs/design/UI_DIRECTION.md`, EGGS, SKINS and PROGRESSION.
> Roblox Studio is open with the game.
>
> 1. Do a Studio QA pass. Screenshot every UI screen in play mode (desktop and phone emulator) and list bugs. Compare
>    each screen with its Venom Candy Figma frame.
> 2. My friend used Astra inside Studio, editing the game directly rather than in git. It changed the shop and
>    replaced our icons with bad AI-generated ones. Find exactly what Astra changed by diffing the live place against
>    the `snakewars-25d` source and Studio's version history. Restore our original icons and shop, then improve them to
>    the Venom Candy and Peckwood bar from the handoff. Show me before and after before replacing anything.
> 3. Then upgrade the Worlds hero screen, as in the handoff's next steps: the HTML prototype artifact and the duplicated
>    Figma frame, with before and after. Wait for my reaction before doing the rest.
>
> Rules: keep the Venom Candy rules. The Roblox build uses only Frames, UICorner, UIStroke and UIGradient. Ask before
> spending Figma credits. QA zoomed in with the agents in `.claude/agents/`. Commit and push as each part lands, and
> keep the handoff updated.
