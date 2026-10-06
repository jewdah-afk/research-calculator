# Proposal: The Mega Board (server-wide plinko)

## Pitch
One giant plinko rig in the middle of every 12–16 player server. Everyone's rolls drop onto the same board, in their own color/nameplate trail. When something rare lands, the whole server sees it: a slow-mo drop, a big effect, and a chat/banner announcement. Your personal board stays where it is. The Mega Board is the social showpiece that turns a solo idle game into a hangout.

## Why it fits
- **Social proof:** seeing someone pull a 1/1e40 orb makes everyone else want to keep rolling. That's the retention loop Sol's RNG and Pet Sim built on.
- **Reuses what exists:** rarity rolls, rarity colors, announcement toasts (`Notify "announce"`) and `MessagingService` events are already built.
- **Cheap to watch:** most of it is spectacle, not economy, so it can't break balance.

## How it plays
1. Each player's spawners still roll on the server, exactly as now. A **sample** of each player's orbs is also sent to the Mega Board: their best orb every few seconds, plus every orb above the "showcase" rarity.
2. The Mega Board has multiplier slots along the bottom. Wide center slots pay ×1–×2; the far edges pay ×10, ×50, ×250, but the pegs make them low-odds. Landing pays that player a bonus on top of their normal collect.
   - The bonus goes through `Balance.bonusLog`, so it stays inside the bonus budget and can't run away.
3. **Rare-drop moments:** orbs above a threshold (for example, the top 5% of a player's discovered rarities, or anything above 1e15) get:
   - a server-wide banner: "jwda rolled CELESTIAL 1/4.2e18!"
   - a camera nudge or zoom for nearby players
   - a unique trail and burst effect by rarity tier
   - a short slow-mo as it falls
4. **Optional later layer:** "server luck chain". Each announced rare gives everyone in the server +x% luck for 60s, stacking a little. It rewards playing together.

## Technical plan (lag-safe)
- **Server decides, clients animate.** The server picks the landing slot when it spawns a Mega Board orb, using the slot odds, and sends `{id, owner, rarity, slot, seed}`. Each client plays a deterministic fake drop toward that slot. No physics replication, no exploit surface, identical everywhere.
- **Budget the visuals:**
  - at most ~40 Mega Board orbs alive per client
  - pooled parts/beams
  - low-tier orbs are simple glowing spheres; only rares get particles
  - distant orbs skip trails
- **Throttle networking:** batch spawns into one remote fire every 0.25s (we already batch `Spawn`).
- **New pieces:**
  - `MegaBoardService` (server): sampling, slot odds, payouts, announcements
  - `MegaBoard.luau` (client): pooled rendering and effects
  - a rarity → effect table in `Assets`
- **Cross-server (optional):** reuse `EventService`'s MessagingService topic to announce ultra-rares (top global tier) to every server.

## Open questions to decide
- Does the Mega Board **pay**, or is it pure showcase? (Paying is more fun; pure showcase is zero balance risk.)
- What threshold triggers an announcement: per-player relative, or a global absolute?
- Should players be able to mute other people's effects (a performance setting for low-end phones)?

## Rough scope
- **MVP (showcase only, announcements, pooled rendering):** about 1–2 days of work.
- **With payouts and the luck chain:** another 1–2 days, plus a pacing-sim pass.
