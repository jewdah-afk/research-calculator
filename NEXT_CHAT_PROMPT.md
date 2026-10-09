# Peckwood: next chat prompt (paste everything below the line)

---

> **Figma UI cleanup chat?** Start with `FIGMA_UI_NEXT.md` in the repo root instead (header edge fix, moving runtime patches into Figma, missing frames, re-export + Studio QA loop).

You are continuing **Peckwood** (Birb remake for Roblox) on the owner's PC with Roblox Studio connected (Studio MCP).

1. Repo: `~/Downloads/rc-main` (GitHub jewdah-afk/research-calculator). `git fetch && git checkout claude/peckwood-isle && git pull`.
2. Read **`HANDOUT.md` section A** (the 2026-10-09 world rebuild: Peckwood Ascent, terrain, sea, props, portals, next steps), then section 0 for how the game is built.
3. Build and open: `cd roblox && rojo build default.project.json -o Peckwood.rbxl`, then open that file in Studio (close any other Studio window first; only one at a time). You may stop Play or reload the place whenever you need to.
4. Test in Play with the dev bar: REGULAR (real save), MAXED (everything open), NEXT ISLAND. A Studio-only attribute `workspace:SetAttribute("QAHour", 11)` pins daytime for screenshots.
5. Section A starts with "INTEGRATED: Figma UI + VFX merged" (current state, open fixes, EditableMesh limits), then "Park slice v2" (latest state + gotchas: decal orientation, EditableMesh budget, Highlight occlusion). The in-game Figma UI is being built on branch `claude/peckwood-ui` (separate worktree `~/Downloads/rc-main-ui`); merge it after Studio QA. Then continue "TOP PRIORITY: full map art pass" in section A (smooth, cel-shaded, real-world-looking terrain on the approved Ascent layout), then the "Next steps" there in order, show the owner a Studio screenshot after each visible change, commit to `claude/peckwood-isle` and push.

Mechanics port: Birb's real rules go in phase by phase on branch `claude/peckwood-mech` (worktree `~/Downloads/rc-main-mech`). Phase 1 (Park, shops, Molt, sunflower tree, Sparrow, Castle) is done and held to the playtest by `node roblox/tools/parity/run.js` (README + REPORT in `roblox/tools/parity/`); see HANDOUT section A "MECHANICS". Phase 2 (Bridge, fishing, Seagull) is next after the owner's Studio QA; every phase must reach 100% in that report.

Owner's direction: the map should look like a 3DS Pokémon X/Y world (low-poly, smooth, cel-shaded, varied ground, not all green), realistic generated terrain, smooth props (no pixel cubes), animated water that feels like you are on water, and it must run smoothly. Never insert Creator Store models without reading every script inside first (one pack had a backdoor); prefer Studio `generate_mesh` for props.
