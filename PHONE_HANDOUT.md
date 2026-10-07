# Peckwood: phone / cloud session handout

Paste everything below the line into a new chat (claude.ai/code or the phone app).

---

You're continuing **Peckwood**, a Roblox remake of the incremental game Birb. This is a **cloud session on a phone**, so there is no Roblox Studio, no local PC and no Figma desktop. Work only in the GitHub repo and push commits; the owner syncs and tests on PC later. The owner is very picky about visual quality, so keep replies short and plain.

## Repo
- GitHub `jewdah-afk/research-calculator`, branch `main`, last commit `8ad7503`. Clone it, work on a branch, open a PR (or push to `main` if the owner says so). Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Roblox game (Rojo) is in `roblox/`:
  - `src/client/UI/Hud.luau`: HUD. Wallet keys, left tiles (SHOP hero / AUTO / MAP / TELEPORT / PROFILE, settings gear), right-side group bars, toast, popups, and the **shop board** (`Hud.openShop`, tabs PASSES/BOOSTS/CRATES).
  - `src/client/UI/Kit.luau`: building blocks (`Kit.button` 3D key, `Kit.shake`, `Kit.grad`, `Kit.stops`, `Kit.texture`, `Kit.icon`).
  - `src/client/UI/Window.luau`, `Windows.luau`, `Spec.luau`: the upgrade windows, their binders and themes (`Spec.GROUPS`).
  - `src/client/IslandView.luau`: the LEGO islands (EditableMesh ground on the Park, part bricks elsewhere), 12 rope bridges, 24-min day cycle, unlock build-in.
  - `src/server/Game.luau`: all game logic. `give()` applies shop multipliers. `Main.server.luau`: players, remotes and the shop purchase plumbing.
  - `src/shared/Shop.luau`: shop catalogue + `Shop.mult`. `EternityNum.luau`: big numbers (suffixes only, composed past Vg). `IslandData.luau` / `World.luau`: islands and bridges. `Icons.luau`: asset ids.
- Icons: `birb-icons/final/*.png` (shop art is `shop_*.png`).

## Gotchas (learned the hard way)
- `Kit.grad` stop format is `{hex, pos, opacity}` with **3rd value = opacity (1 = solid, 0 = clear)**. Getting it backwards turns cards black.
- Luau `UIScale` shrinks toward the top-left, so for presses sink the button face; don't squash from the corner.
- Client EditableMesh budget is ~8 meshes. Keep each EditableMesh alive (destroying one blanks its mesh).
- All purchases and effects are server-side. Never trust the client.
- No `task.wait` stepped animations; use TweenService or RenderStepped.

## Owner rules
Hero-quality UI with zero clipping, one thin black outline and no glow rims. Glossy 3D icons only, not AI-looking. Big numbers always through EternityNum. Screenshots with every visual change (on phone: describe exactly what changed and where). Keep knowledge in Obsidian (`OneDrive/Documents/Obsidian Vault/Claude`); on phone you can't reach it, so put notes in the PR description.

## Done recently
Shop v3 (bundle 899 R$ for all 6 passes, passes, boosts, crates), wallet stat names, left tile hierarchy + textures, right-side group bars, Profile full height, bridge piers/ropes, temple flicker fix, EN suffix fix.

## Next tasks (good for phone, code only)
1. **Fishing overhaul** (`Windows.luau` fishing binders + `Game.luau`): recent catches list, sell fish for moneta, rod/bait upgrades. Use the existing formulas in `BirbFormulas.luau` / `BirbSystems.luau`.
2. **Fish Index**: show only caught fish, with each fish's catch chance below, and clear hierarchy (`Windows.openIndex` in Hud).
3. Check every window's gameplay makes sense (mine, expedition/mob fighting, nest, echo). Where the core mechanic isn't just "buy upgrades", make sure it exists and works.
4. Perf: the 8 newer islands build ground from ~2k Parts each (`buildIslandGround` in IslandView). Merge them into fewer parts or meshes.

## Needs the PC (leave for later)
Studio QA screenshots, new icon art (Figma), Creator Hub pass/product ids (`assetId` in `Shop.luau`, currently 0).
