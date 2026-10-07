# Peckwood SFX: the buttery keycap kit

Every sound here is synthesized by `concepts/reference/sfx.js` (the same code the Shop Lab and World Guide play live), rendered offline to 44.1 kHz mono and saved as Ogg Vorbis, peak-normalized to -1 dB.

The keycap model: a soft top click (filtered noise), a short pitched body that drops into place (the thock), and a warm case resonance, all through a gentle low-pass. Variants change pitch, weight and tail; big moments add marimba notes, shimmer and swells.

| File | Use |
|---|---|
| hover | pointer enters a button (desktop only) |
| press / release | button down / up |
| tab | tab switch |
| open / close | window or board opens / closes |
| buy / deny | purchase or upgrade succeeds / can't afford |
| pickup / golden / pop | popcorn, golden popcorn, small pops |
| peck / mine / hit | nest peck, mining strike, boss hit |
| splash / pillar | water splash, rare-catch light pillar |
| molt / evolve / unlock / upgrade | reset moments, area unlock, level up |

## To use in game (PC)
1. Upload each `.ogg` in Creator Hub (Audio).
2. Put the ids in `KIT_IDS` in `roblox/src/client/UI/Kit.luau`. Any id left at 0 falls back to the old keyboard slice, so it can be done one at a time.
3. Old call names keep working: `click` plays `press`, `thock` plays `buy`, `nope` plays `deny`.
