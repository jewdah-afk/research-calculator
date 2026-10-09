# Peckwood: next chat prompt (paste everything below the line)

---

You are continuing **Peckwood** (Birb remake for Roblox) on the owner's PC with Roblox Studio connected (Studio MCP).

1. Repo: `~/Downloads/rc-main` (GitHub jewdah-afk/research-calculator). `git fetch && git checkout claude/peckwood-isle && git pull`.
2. Read **`HANDOUT.md` section A** (the 2026-10-09 world rebuild: Peckwood Ascent, terrain, sea, props, portals, next steps), then section 0 for how the game is built.
3. Build and open: `cd roblox && rojo build default.project.json -o Peckwood.rbxl`, then open that file in Studio (close any other Studio window first; only one at a time). You may stop Play or reload the place whenever you need to.
4. Test in Play with the dev bar: REGULAR (real save), MAXED (everything open), NEXT ISLAND. A Studio-only attribute `workspace:SetAttribute("QAHour", 11)` pins daytime for screenshots.
5. Section A starts with "Park slice v2" (latest state + gotchas: decal orientation, EditableMesh budget, Highlight occlusion). The in-game Figma UI is being built on branch `claude/peckwood-ui` (separate worktree `~/Downloads/rc-main-ui`); merge it after Studio QA. Then continue "TOP PRIORITY: full map art pass" in section A (smooth, cel-shaded, real-world-looking terrain on the approved Ascent layout), then the "Next steps" there in order, show the owner a Studio screenshot after each visible change, commit to `claude/peckwood-isle` and push.

Owner's direction: the map should look like a 3DS Pokémon X/Y world (low-poly, smooth, cel-shaded, varied ground, not all green), realistic generated terrain, smooth props (no pixel cubes), animated water that feels like you are on water, and it must run smoothly. Never insert Creator Store models without reading every script inside first (one pack had a backdoor); prefer Studio `generate_mesh` for props.
