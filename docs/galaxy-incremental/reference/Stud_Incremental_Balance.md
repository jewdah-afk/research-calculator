# Stud Incremental — Balance Sheet

Source: Ascension Incremental place file (`AI_copy.rbxl`), all 444 scripts. Internal stat names are used throughout (they stay the same in code/datastore; the reskin only changes display names).

## Changes applied (`AI_copy_balanced.rbxl`)

| # | What | Old | New | Why |
|---|---|---|---|---|
| 1 | Rune payout (`Libraries.Runes`) | Paid 1 rune type/sec, then cleared the pending list | Swap list out first, pay all at once | Runes rolled during payout were being wiped |
| 2 | Tier 11 cost (`Formulas.Tier_Cost[10]`) | 5e60 Droplets | 1e52 Droplets | ~7-day wall of nonstop play; Droplets plateau ~1e52 |

No other formulas or constants changed.

## Pacing (simulated active free-to-play player, real game formulas)

| Milestone | Time |
|---|---|
| Tier 1 | 6 s |
| Tier 3 | 5.5 min |
| Tier 5 | ~17 min |
| Tier 6 | ~27 min |
| Tier 7 | ~67 min |
| Tier 8 | ~1.4 h |
| Tier 9 | ~1.8 h |
| Tier 10 | ~3.1 h |
| C1 / C2 / C4 / C3 complete | 3.2 h / 3.5 h / 3.8 h / 4.1 h |
| Ascension One | ~7.1 h |
| Back to Tier 10 after Ascension | +~35 min |
| Realm Two (Energy > 1e3003) | ~10.7 h |
| Tier 11 (old 5e60 cost) | ~7.4 days → with 1e52: ~half a day (est.) |
| Tier 12 | ~1.4 days after Tier 11 |
| Chromatizer (5e43 Prisms) | not reached in 30 simulated days |

Assumptions: always online, no gamepasses/elixirs/offline gains, bot camps the rune pack that most boosts its current bottleneck. Real players are slower per day, similar per hour played.

## Balance notes

- **Tier 0 → Ascension:** healthy; gaps of minutes to ~1 hour, Ascension replay ~10× faster.
- **Tier 11 → 12:** fine *if* players roll the right pack (Droplets/Prisms runes live in Nature, Polychrome, Cryo, Arctic). Worth a UI hint.
- **R2 purchase (5e31 Prisms)** is redundant — players reach Realm Two free via Energy > 1e3003 at ~11 h.
- **Chromatize/Chromify layer** gated by 5e43 Prisms; Prisms grow slowly late. Playtest before stacking new post-Tier-12 content on top.

## Known bugs (not changed — decide individually; fixing changes live balance)

- `Freeze9` price written `2,5e313` → costs 2.
- Wrong rune passed: `Earthvein_Energy` (uses Oak), `Thunderstorm_Flesh`, `Omniscient/Almighty_Droplets` (use Frostveil), `Primordial_ChestChance`.
- `Prisms_Orbs1` effect evaluated at `Prisms_Orbs2`'s level.
- Arctic Points tier bonus never applied.
- `Draco_Follow` check missing `.Value` (always true).
- `Rune_Clone` always returns 2.
- Chromatize cost past level 10 is cheaper than level 10 (non-monotonic).
- Upgrade engine: `Additive_Scale` is never read (all prices exponential); `Base_Effect` only added when `Effect_Scale <= 1`.
- Droplets loop multiplies whole balance by `Droplets_Multiplier` every 0.5 s.
- `Rune:GetResult` called twice per open (double rewards).
- Global Goals never starts (`noinit`).
- `WaterAuto` cooldown capped at 1 s.
- Global/Ancient/Madness/Ultra pools compare thresholds independently → real odds lower than listed (Lightmatter 0.95 → ~0.90).
- Freeze module compares tiers as strings and applies boosts even if payment fails.

---

# Full Formula Reference


# Formulas module reference

Source: `ReplicatedStorage.Framework.Shared.Modules.Formulas` (2447 lines). Requires `EternityNum` (EN), `Upgrades`, `RuneFormulas`. `Base_WS = StarterPlayer.CharacterWalkSpeed`.

## Legend
- `Up(X)` = `Upgrades("X"):GetEffect(Player.Upgrades.X.Value, Player)` (the `Player` arg is noted as "no Player" when omitted; a 3rd arg like `"Water"` is shown as `Up(X,"Water")`).
- `R(Name_Eff)` = `RuneFormulas.Name_Eff(Player.Runes.Name.Value)` (rune argument noted only when it differs from Name).
- **C2-damped runes** (Energy, Flame, RealmPoints, Power, Flesh, Prisms): if `Stats.CurrentChallenge ~= "C2"` → `R(x)`; else each rune is called with `Runes.X.Value ^ 0.33`.
- **C2-skipped runes** (Damage, Orbs, Spheres): the rune block is applied only when `CurrentChallenge ~= "C2"`; no else branch.
- `Tier` = `Stats.Tier.Value`. "Tier table" values *replace* (last matching ≥ wins) unless marked "×=" (cumulative).
- Standard boosts: `Elixir` = ×2 if `Stats.StatsElixirDuration > 1`; `ServerElixir` = ×1.5 if `ReplicatedStorage.GlobalElixirDuration > 0`; `Follow` = ×1.25 if `Stats.Ayla_Follow`; `MoreStats` = ×2 gamepass; `Prime` = ×1.5 gamepass.
- `Donation` = `Formulas.Donation_Stats(Stats.RobuxDonated)`.
- `Loot` = if `Stats.Loot ≥ 1`: ×(1 + min(Loot×0.05, 1000)). `Hail(p,c)` = if `Stats.Hail ≥ 1`: ×(1 + min(Hail×p, c)); same pattern for `Haze`, `Chroma`, `Shine`, `Light`.
- Challenge completion flags: `Stats.C1..C4` (bool). `EN.me` = >, `EN.meeq` = ≥, `EN.le` = <, `EN.leeq` = ≤.

---

## STATS

### Formulas.Energy(Player, Gain)
`v = (Gain or 1) × 2 (event)`

Tier table (replace): 

| Tier ≥ | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Bonus | 2 | 4 | 20 | 80 | 500 | 5e3 | 7.5e4 | 2.5e6 | 2.5e7 | 5e10 |

`v ×= Π C2-damped runes`: Basic_Energy, Unique_Energy, Ascendant_Energy, Exotic_Energy, Tinted_Energy, Colorful_Energy, Radiance_Energy, Neon_Energy, Chrome_Energy, Vibrance_Energy, Oak_Energy, Dew_Energy, Thunderstorm_Energy, **Earthvein_Energy(Runes.Oak)**, Dreamscape_Energy, Lightmatter_Energy, Darkmatter_Energy, Glow_Energy, Noob_Energy, Experienced_Energy, Champion_Energy, Superstar_Energy, Gilded_Energy, Crown_Energy, Monarch_Energy, Overlord_Energy, Dust_Energy
`× 25 if Spheres ≥ 100`
`× Up(RP_Energy) × Up(RP_Energy2) × Up(Power_Energy) × Up(Flesh_Energy) × Up(Prisms_Energy1) × Up(Prisms_Energy2) × Up(Prisms_Multi) × Up(Orbs_Energy) × Up(Spheres_Energy) × Up(Tickets_Energy) × Up(Spheres_Energy2)`
`× Flame_Energy(Flame) × TierBonus × Orbs_Energy(Orbs) × Cube_Energy(Cube_Level) × Donation × Level_Energy(Level)`
`× 1.5 if attr GroupMember × Elixir × ServerElixir × Follow × MoreStats × Prime × 3 if gamepass TripleEnergy × Loot`
Challenges: `×1e12 if C1`; `×20 if C2`; `^1.1 if C3 and v>1`; `^0.425 if CurrentChallenge=="C1" and v>1`; `^0.5 if CurrentChallenge=="C4" and v>1`.
Notes: Earthvein_Energy is passed `Runes.Oak` (both branches) — likely should be `Runes.Earthvein`.

### Formulas.Flame(Player, Gain)
`v = (Gain or 1) × 2`; **returns 0 if CurrentChallenge=="C3"**.

| Tier ≥ | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| Bonus | 2 | 5 | 15 | 30 | 200 | 2.5e3 | 1e5 | 1.5e6 | 5e8 |

`v ×= Up(RP_Flame) × Up(Power_Flame) × Up(Flesh_Flame) × Up(Prisms_Flame1) × Up(Prisms_Flame2) × Up(Orbs_Flame) × Up(Spheres_Flame) × Up(Tickets_Flame)`
`× Π C2-damped runes`: Rare_Flame, Ascendant_Flame, Exotic_Flame, Chrome_Flame, Rainbow_Flame, Vibrance_Flame, Moss_Flame, Skylight_Flame, Thunderstorm_Flame, Emberglow_Flame, Lightmatter_Flame, Darkmatter_Flame, Intermediate_Flame, Master_Flame, Royalty_Flame
`× 100 × (Prisms/1)` if `Upgrades.Flesh_Flame2 > 0 and Prisms ≥ 1`
`× TierBonus × Orbs_Flame(Orbs) × Donation × MoreStats × Prime × ServerElixir × Follow`
`× Prisms_Flame(EN.convert(Prisms))` if `Flesh_Flame2 > 0` (= Prisms²)
`× Elixir`; Challenges: `×1e12 C1; ×20 C2; ^1.1 C3 (v>1); ^0.425 cur C1 (v>1); ^0.5 cur C4 (v>1)`.
Notes: Flesh_Flame2 applies both ×100·Prisms and ×Prisms² (double-dip, possibly intended).

### Formulas.RealmPoints(Player, Gain)
`v = (Gain or 1) × 2`; **returns 0 if CurrentChallenge=="C3"**.

| Tier ≥ | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|
| Bonus | 1.25 | 1.5 | 3 | 9 | 27 |

`v ×= Orbs_RealmPoints(Orbs, Player) × Up(Flesh_RP) × Up(Prisms_RP1) × Up(Prisms_RP2) × Up(RP_RP) × Up(RP_RP2)` (Up(RP_Power) commented out)
`× Π C2-damped runes`: Unknown_RealmPoints, Neon_RealmPoints, Dew_RealmPoints, Nightshade_RealmPoints, Earthvein_RealmPoints, Lightmatter_RealmPoints, Darkmatter_RealmPoints, Glow_RealmPoints, Iridium_RealmPoints, Legend_RealmPoints
`× TierBonus × Elixir × ServerElixir × Follow × MoreStats × Prime × 10 if Stats.AscensionOne`
`×20 if C2; ^0.425 cur C1 (v>1); ^0.5 cur C4 (v>1)`. No Donation.

### Formulas.ArcticPoints(Player, Gain)
`v = (Gain or 1) × 2`
TierBonus (×=): Tier≥12 ×1.5; Tier≥13 ×5 (→ 7.5). **Computed but never applied.**
`v ×= Up(Chromium_AP1) × Up(Chromium_AP6) × Up(Droplets_AP1) × Up(AP_AP1) × Up(Freeze2,"ArcticPoints") × Up(Freeze4,"ArcticPoints")`
`× R(Shiver_ArcticPoints) × R(Frigid_…) × R(Avalanche_…) × R(Frostveil_…) × R(Omnipotent_…) × R(Almighty_…) × R(Throne_…) × R(Glyph_ArcticPoints)` (no C2 handling)
`× MoreStats × Prime × Elixir × ServerElixir`
`× 3 if Chromatize ≥ 4`
`× FreezeMult` (Freeze2≥1 ×2; Freeze4≥1 ×4)
`× Follow`
Notes: Tier_Bonus unused (bug). Freeze2/Freeze4 both via Up() and a flat FreezeMult.

### Formulas.Tier(Player, Gain)
`return Gain or 1` (no modifiers).

### Formulas.Power(Player, Gain)
`v = (Gain or 1) × 2`
Flame scale: if Flame > 0 and (Flame − 50) > 0: `v += (Flame − 50)/50` (additive, after event ×2).

| Tier ≥ | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|
| Bonus | 2 | 4 | 16 | 80 | 250 | 1e4 | 7.5e5 | 5e7 |

`v ×= Up(Power_Power) × Up(RP_Power) × Up(Flesh_Power) × Up(Prisms_Power) × Up(Spheres_Power) × Up(Tickets_Power)`
`× Π C2-damped runes`: Exotic_Power, Radiance_Power, Oak_Power, Skylight_Power, Wavecaller_Power, Thunderstorm_Power, Lightmatter_Power, Darkmatter_Power, Experienced_Power
`× TierBonus × Orbs_Power(Orbs) × Cube_Power(Cube_Level) × Donation × Elixir × ServerElixir × Follow × MoreStats × Prime`
`×20 if C2; ^0.425 cur C1 (v>1); ^0.5 cur C4 (v>1)`.

### Formulas.Damage(Player, Gain)
`v = Gain or 1` (no event ×2)
`× Power_Damage(Power, Player) × Up(RP_DMG) × Up(RP_DMG2) × Up(Flesh_DMG) × Up(Prisms_Damage) × Up(Spheres_DMG)`
`× C2-skipped runes`: Neon_Damage, Rainbow_Damage, Moss_Damage, Thunderstorm_Damage, Dreamscape_Damage, Experienced_Damage
`× Elixir × ServerElixir × Follow × 3 if gamepass MoreDamage × Donation`
`×50 if C2; ^0.5 cur C4 (v>1)`.

### Formulas.Flesh(Player, Gain)
`v = (Gain or 1) × 2`

| Tier ≥ | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| Bonus | 2.5 | 10 | 250 | 2e4 | 5e6 | 2.5e9 |

`v ×= Up(Power_Flesh) × Up(Flesh_Power) × Up(Prisms_Flesh) × Up(Prisms_Multi) × Up(Spheres_Flesh) × Up(Tickets_Flesh)`
`× Π C2-damped runes`: Colorful_Flesh, Vibrance_Flesh, Nightshade_Flesh, Wavecaller_Flesh, **Thunderstorm_Flesh(Runes.Vibrance)**, Emberglow_Flesh, Lightmatter_Flesh, Darkmatter_Flesh, Iridium_Flesh, Spectrum_Flesh, Master_Flesh, Legend_Flesh
`× 1e15 if Spheres ≥ 1e98`; `× Cube_Level³ if Spheres ≥ 1e150`
`× Loot × Elixir × ServerElixir × Orbs_Flesh(Orbs) × TierBonus × Donation × Follow`
`×20 if C2; ^0.5 cur C4 (v>1)`. No gamepasses.
Notes: Thunderstorm_Flesh passed `Runes.Vibrance` (bug, both branches).

### Formulas.Prisms(Player, Gain, nextIce)
`v = (Gain or 1) × 2`
Tier: ≥6 → 1.5; ≥7 → 2.
`× 2 if attr Prisms_X2`
`× Up(Prisms_Prisms1) × Up(Prisms_Prisms2) × Up(RP_Prisms) × Up(Chromium_Prisms1) × Up(Chromium_Prisms2) × Up(Chromium_Prisms4) × Up(AP_Prisms1) × Up(AP_Prisms2) × Up(Freeze5,"Prisms") × Up(Freeze8,"Prisms")`
`× 1.25 if Stats.Draco_Follow` (checks object, not `.Value` → always true if exists)
`× min(3^Chromatize, 1e300)` if Chromatize ≥ 1
`× (1 + Chromium × 0.05)`
`× Π C2-damped runes`: Chrome_Prisms, Skylight_Prisms, Darkmatter_Prisms, Shimmer_Prisms, Spectrum_Prisms, Refraction_Prisms, Champion_Prisms, Elite_Prisms, Crown_Prisms, Dust_Prisms
Conditional boosts (each applied only if result < 10):
- Chromium_Prisms3 > 0 and Chromium > 0: `× Prisms^0.9` (comment says +0.05×/Chromium, cap 3 lvls)
- Chromium_Prisms5 > 0 and Mobs_Level > 0: `× Mobs_Level^0.9` (comment: 1 mob level = +5×)
- Chromium_Icicles3 > 0 and Icicles > 0: `× Prisms^0.5`
`× Prisms_Prisms(Prisms)` (= Prisms^0.25) if Cube_Level ≥ 400
`× Playtime_Prisms(Playtime)` if Prisms_Prisms4 ≥ 1
`× min(1 + Runes_Opened/1e8, 1e300)` if Flesh_Prisms ≥ 1
`× Hail(0.5, 1000) × Chroma(1, 1e300)`
`× TierBonus × Donation × 3 if AscensionOne × ServerElixir × MoreStats × 2 if gamepass MorePrisms × Prime` (Follow commented out; no Elixir)
`×2 if C1; ×15 if C4; ^0.5 cur C4 (v>1)`
`× (Icicles + 1 + (nextIce?1:0))^0.5` if Chromium_Icicles3 ≥ 1
`× FreezeMult` (Freeze5 ×50; Freeze8 ×3)
Notes: Chromium_Prisms3 / Icicles3 boosts use Prisms instead of Chromium/Icicles; "<10" gate means they vanish once large (effectively cap-by-disable). Draco_Follow missing `.Value`.

### Formulas.Orbs(Player, Gain)
`v = (Gain or 1) × 2`
Tier: ≥8 → 4; ≥9 → 50; ≥10 → 5e3.
`× Up(Flesh_Orbs) × Up(Flesh_Orbs2) × Up(Orbs_Orbs) × Upgrades("Prisms_Orbs1"):GetEffect(Upgrades.Prisms_Orbs2) × Up(Prisms_Orbs2) × Up(RP_Orbs) × Up(RP_Orbs2) × Up(Spheres_Orbs) × Up(Spheres_Orbs2) × Up(Tickets_Orbs) × Cube_Orbs(Cube_Level)`
`× C2-skipped runes`: Chrome_Orbs, Rainbow_Orbs, Vibrance_Orbs, Nightshade_Orbs, Thunderstorm_Orbs, Earthvein_Orbs, Emberglow_Orbs, Darkmatter_Orbs, Shimmer_Orbs, Iridium_Orbs, Champion_Orbs, Elite_Orbs, Imperial_Orbs, Kingslayer_Orbs, Bone_Orbs, Mad_Orbs
`× Prisms^0.9` if Prisms_OrbsEnhance > 0 and Prisms > 0
`× Orbs_RP(Orbs)` (= Orbs^0.15) if Prisms_RPEnhance > 0
`× 25 if Spheres ≥ 2.5e17`; `× (1 + Mobs_TotalKilled)³ if Spheres ≥ 1e184`
`× TierBonus × Donation × Elixir × ServerElixir × Follow × MoreStats × Prime × 5e4 if AscensionOne`
`×1e6 if C1; ×20 if C2; ^1.1 if C3 (v>1); ^0.5 cur C4 (v>1)`.
Notes: Prisms_Orbs1 effect is evaluated with the Prisms_Orbs2 level (bug).

### Formulas.Spheres(Player, Gain)
`v = (Gain or 1) × 2`; Tier ≥10 → 25.
`× Spheres_Spheres(Sphere_Levels)` (=1.5^lvl) `× Up(Prisms_Spheres3) × Up(Prisms_Spheres2) × Up(Prisms_Spheres1) × Up(RP_Spheres) × Up(RP_Spheres2) × Up(Flesh_Spheres) × Up(Flesh_Spheres2) × Up(Power_Spheres) × Up(Tickets_Spheres) × Up(Prisms_Spheres5) × Up(Droplets_Spheres1) × Up(Freeze6,"Spheres")`
`× (Droplets + 1)`
`× C2-skipped runes`: Nightshade_Spheres, Wavecaller_Spheres, Dreamscape_Spheres, Darkmatter_Spheres, Shimmer_Spheres, Mist_Spheres, Icequake_Spheres, Snowflake_Spheres, Icy_Spheres, Omniscient_Spheres, Bloom_Spheres, Legend_Spheres, Mad_Spheres
`× max(Spheres^0.75, 1)` if Chromium_SpheresEnhance > 0 and Chromium > 0 (condition duplicated/nested)
`× (1 + 0.1 × Ice)`
`× 5 if Spheres ≥ 1e7`
`× RealmPoints^0.1` if Prisms_SpheresEnhance > 0 and "Realm Points" > 0
`× Tickets_Spheres(Tickets)` (= 1 + Tickets) if Power_Spheres2 > 0
`× TierBonus × Donation × Elixir × ServerElixir × Follow × MoreStats × Prime`
`× Power_Spheres(Power)` (= Power^0.01) if Spheres_Spheres2 > 0
`×20 if C2; ^0.5 cur C4 (v>1)`; `× 7 if Freeze6 ≥ 1`.
Notes: Chromium_SpheresEnhance scales with Spheres, not Chromium (self-feedback). Droplets→Spheres ^0.25 block commented out.

### Formulas.Droplets(Player, Gain, nextIce)
`v = (Gain or 0.5) × 2 × Stats.Droplets_Multiplier`
TierBonus (×=): ≥11 ×3; ≥12 ×250; ≥13 ×4e4 (max 3e7) — applied here.
`× (1 + 0.5 × Water)`
`× Up(Prisms_Droplets1) × Up(Chromium_Droplets2) × Up(Chromium_Droplets1) × Up(Droplets_Droplets1) × Up(AP_Droplets1) × Up(Freeze1,"Droplets") × Up(Freeze4,"Droplets") × Up(Tickets_Droplets)`
`× R(Breeze_Droplets) × R(Frigid_Droplets) × R(Snowflake_Droplets) × R(Frostveil_Droplets) × Omniscient_Droplets(Runes.Frostveil) × Almighty_Droplets(Runes.Frostveil) × R(Monarch_Droplets) × R(Gilded_Droplets) × R(Master_Droplets) × R(Glyph_Droplets)`
`× MoreStats × Prime × Elixir × Haze(2, 100) × Hail(0.5, 1000)`
`× (Icicles + 1 + (nextIce?1:0))²` (unconditional)
`× 1e4 if Chromatize ≥ 2`
`× FreezeMult` (Freeze1 ×10; Freeze4 ×100) `× Follow`. No ServerElixir.
Notes: Omniscient_Droplets and Almighty_Droplets are passed `Runes.Frostveil` (bug). RuneSpeed/Water offset blocks commented out.

### Formulas.Water(Player, Gain, nextIce)
`v = (Gain or 1) × 2`; TierBonus (×=): ≥11 ×1.5; ≥12 ×10.
`× Up(Prisms_Water1) × Up(Chromium_Water1) × Up(Droplets_Water1) × Up(AP_Water1) × Up(Freeze1,"Water") × Up(Freeze2,"Water") × Up(Freeze3,"Water") × Up(Tickets_Water)`
`× R(Breeze_Water) × R(Shiver_Water) × R(Icequake_Water) × R(Snow_Water) × R(Avalanche_Water) × R(Subzero_Water) × R(Omniscient_Water) × R(Omnipotent_Water) × R(Almighty_Water)`
`× MoreStats × Prime × Elixir × Haze(2, 100) × (1 + Ice)`
`× (Icicles + 1 + (nextIce?1:0))^1` if Chromium_Icicles2 ≥ 1
`× Water^0.9` if Chromium_Icicles2 > 0 and Icicles > 0 and Water > 1
`× FreezeMult` (Freeze1 ×3; Freeze2 ×20; Freeze3 ×5) `× Follow`.

### Formulas.Ice(Player, Gain, nextIce)
`v = (Gain or 1) × 2`; Tier ≥12 ×3.
`× Up(Chromium_Ice1) × Up(Freeze3,"Ice") × Up(Freeze5,"Ice") × Up(Tickets_Ice)`
`× R(Frigid_Ice) × R(Icequake_Ice) × R(Snow_Ice) × R(Avalanche_Ice) × R(Omnipotent_Ice) × R(Almighty_Ice)`
`× MoreStats × Prime × Elixir`
`× max(Ice^0.1, 1)` if Chromium_Ice2 > 0 and Ice > 0
`× Haze(2, 100)`
`× (Icicles + 1 + (nextIce?1:0))^0.2` if Chromium_Icicles4 ≥ 1
`× 10 if Chromatize ≥ 2 × FreezeMult` (Freeze3 ×3; Freeze5 ×15) `× Follow`.

### Formulas.Chromium(Player, Gain)
`v = (Gain or 1) × 2`; Tier ≥13 ×4.
`× Up(Prisms_Chromium1) × Up(Chromium_Chromium1) × Up(Droplets_Chromium1) × Up(AP_Chromium1) × Up(Freeze5,"Chromium") × Up(Freeze8,"Chromium") × Up(Tickets_Chromium)`
`× 2 if Gamepasses.X2Chromium.Value > 0`
`× R(Icy_Chromium) × R(Hailstorm_Chromium) × R(Subzero_Chromium) × R(Almighty_Chromium) × R(Imperial_Chromium)`
Chromatize bonus: start 1; ≥2 → ×2; then +0.25 each for Chromatize ≥4,5,6,7,8,9,10 (max 2 + 1.75 = 3.75).
`× FreezeMult` (Freeze5 ×3; Freeze8 ×5) `× 1.25 if Stats.Nexo_Follow`. No gamepass MoreStats/Prime/Elixir.

### Formulas.Icicles(Player, Gain)
`v = (Gain or 1) × 2 × Up(Chromium_Icicles1) × Up(Freeze7,"Icicles") × Up(Tickets_Icicles) × MoreStats × Prime × Elixir`
`× R(Avalanche_Icicles) × R(Frostveil_Icicles) × R(Almighty_Icicles)`
Chromatize: ×1.5 each for ≥7, 8, 9, 10 (max 1.5⁴ = 5.0625).
`× 3 if Freeze7 ≥ 1 × Follow`.

### Formulas.Haze(Player, Gain)
Plain numbers (not EN). `v = 1 × Product_SecretStats × R(Eternal_AllSecret) × R(Vehemence_AllSecret) × R(Malevolence_AllSecret) × 1.25 if attr ServerBoosted`. Gain ignored.

### Formulas.Shine(Player, Gain)
`v = 1 × Product_SecretStats × Eternal_AllSecret × Vehemence_AllSecret × Malevolence_AllSecret × R(Mommy_Shine) × R(Soup_Shine) × 1.25 if ServerBoosted × Up(Chromium_Shine1) × Up(Chromium_Shine2)`. Gain ignored.

### Formulas.Hail(Player, Gain)
`v = 1 × R(Liberty_Hail) × Product_SecretStats × Eternal_AllSecret × Vehemence_AllSecret × Malevolence_AllSecret × Up(Chromium_Hail1) × 1.25 if ServerBoosted`. Gain ignored.

### Formulas.Loot(Player, Gain)
`v = 1 × Product_SecretStats × Eternal_AllSecret × Vehemence_AllSecret × Malevolence_AllSecret × 1.25 if ServerBoosted`. Gain ignored.

### Formulas.Light(Player, Gain)
`v = 1 + Up(Chromium_Light9)` (additive base)
`× Product_SecretStats × Eternal_AllSecret × R(Violence_Light) × Vehemence_AllSecret × R(Hurricane_Light) × R(Galaxy_Light) × Malevolence_AllSecret × R(Axium_Light) × R(Paracosm_Light)`
`× Up(Light_Light) × Up(Chromium_Light1..7) × Up(Chromium_Light10) × Upgrades("Reflection_Light1"):GetEffect(level)` (no Player)
`× 3 if Chromify ≥ 2; × 5 if Chromify ≥ 3; × 1.25 if ServerBoosted`
`× Shine(0.1, 1e300)`
`v = v ^ Up(Chromium_Light8)`. Gain ignored.

### Formulas.Chroma(Player, Gain)
Base (additive): `v = 1 + Up(Chromium_Chrome3) + Up(Chromium_Chrome4) + Up(Chromium_Chrome6) + Up(Chromium_Chrome9) + Up(Light_Chrome1) + R(Bozo_BaseChrome)` (these Up calls without Player)
`× Eternal_AllSecret × Vehemence_AllSecret × Malevolence_AllSecret × R(Raze_Chrome) × R(Glint_Chrome1) × R(Glint_Chrome2) × R(Nexus_Chrome) × R(Rage_Chroma) × R(Galaxy_Chroma) × R(Violence_Chroma) × R(Axium_Chroma) × R(Hyperion_Chroma1) × R(Hyperion_Chroma2)`
`× Up(Chromium_Chrome{1,2,5,7,8,10,11,12,13,15,16,17,18,19,21,22}) × Up(Tickets_Chrome1) × Up(Light_Chrome2)(no Player) × Up(Reflection_Chrome1)(no Player)`
`× 10 if Chromify ≥ 3 × 1.25 if ServerBoosted × Light(0.05, 1e300) × Shine(0.01, 1e300) × Product_SecretStats`
`v = (v ^ Up(Chromium_Chrome20)) ^ Up(Chromium_Chrome14)`. Gain ignored.

### Formulas.Reflection(Player, Gain)
`v = Gain or 1`; if Light > 0 and (Light − 1e20) > 0: `v += (Light − 1e20)/1e20`.
`× Up(Chromium_Reflection1) × Donation × R(Violence_Reflection) × R(Axium_Reflection) × R(Mommy_Reflection) × Elixir × ServerElixir × MoreStats × Prime`. No event ×2.

### Formulas.Ascended(Player, Gain)
`return 1`.

---

## DONATIONS

### Formulas.Donation_Stats(Value)
`1 if Value < 1; else 1 + 0.25 × log10(Value)`

### Formulas.Donation_RuneLuck(Value)
`1 if Value < 1; else 1 + 0.15 × log10(Value)`

### Formulas.Donation_RuneSpeed(Value)
`1 if Value < 1; else 1 + 0.15 × log10(Value)`

## FAVORITES

### Formulas.Favorites_RuneLuck(Value)
| Value | Result |
|---|---|
| ≥ 1e4 | 1.9 + 0.000005 × (Value − 1e4) (uncapped) |
| ≥ 5e3 | 1.65 + 0.00005 × (Value − 5e3) |
| ≥ 1e3 | 1.25 + 0.0001 × (Value − 1e3) |
| else | clamp(1 + 0.00025 × Value, 1, 10) |

---

## TICKETS

### Formulas.Tickets(Player)
`v = 1 × 2 (event) × RuneFormulas.Darkmatter_Tickets(Runes.Darkmatter, Player) × Up(Prisms_Tickets) × Up(Prisms_Tickets2) × Up(Tickets_Tickets) × Up(Chromium_Tickets1) × Up(Chromium_Tickets2)`
`× R(_Tickets)` for: Prismatic, Vexed, Hailstorm, Boundless, Intermediate, Legend, Gilded, Throne, Monarch, Imperial, Thorn, Abyssium, Garmin, Vanta, Squid, Array, Stray, Whirl, Riptide, CosmicDust, Star, Buff_Tickets1, Buff_Tickets2, Sorcerer, Rocket, Hurricane, Rage
`× Donation × 2 if Spheres ≥ 1e27 × ServerElixir × Elixir × Follow × 2 if Chromatize ≥ 10`.

### Formulas.Ticket_Chance(Player, runeName)
`D = 10000 − Antimatter_TicketChance(Runes.Antimatter, Player) − Sovereign_TicketChance(Runes.Sovereign, Player) − Ankh_TicketChance(Runes.Ankh, Player)`
`return (1/D) × Rune_Bulk(Player, false, runeName)`.

### Formulas.Chest_Chance(Player)
`D = 10000 − Refraction_ChestChance(Runes.Refraction, P) − Prosperity_ChestChance(Runes.Prosperity, P) − Primordial_ChestChance(Runes.Prosperity, P) − Ankh_ChestChance(Runes.Ankh, P)`; `return 1/D`.
Notes: Primordial_ChestChance is passed `Runes.Prosperity` (bug).

---

## LEVEL / XP

### Formulas.XP(Player, Gain)
`v = (Gain or 1) × Flame_XP(EN.convert(Flame)) × Up(RP_XP) × Up(Power_XP) × Up(Spheres_XP) × MoreStats × Prime × Donation`
`×20 if C2; ^0.5 cur C4 (v>1)`. No event ×2.

### Formulas.Level_Req(Currency)
`1e2 × 3^Currency` ("Temporary Formula").

---

## PRODUCTS

### Formulas.Product_RuneBulk(Player)
`clamp(Stats.RuneBulkProduct, 0, 1000000)`

### Formulas.Product_RuneLuck(Player)
`clamp(Stats.RuneLuckProduct, 1, 10.8)`

### Formulas.Product_RuneSpeed(Player)
`clamp(Stats.RuneSpeedProduct, 1, 11.4)`

### Formulas.Product_RuneBulk2(Player)
`clamp(Stats.RuneBulkMultiplierProduct, 1, 6)`

### Formulas.Product_SecretStats(Player)
`clamp(Stats.SecretStatsProduct, 1, 6)`

### Formulas.Product_RuneClone(Player)
L = Stats.RuneCloneProduct: L==8 → 1e12; L==7 → 1e10; L==1 → 1e3; else `1000 × 10^clamp(L−1, 0, 7)`.

---

## MOBS / POWER / CUBES

### Formulas.Mob_Respawn(Player)
`3 − Up(Prisms_SpawnSpeed)`

### Formulas.Power_LevelCap(Player)
`0 + Up(Prisms_Caps)`

### Formulas.AutoPower(Player)
`0.1 + Up(Prisms_AutoPower2)`

### Formulas.Cube_Level(Player)
`1 + Up(Orbs_SpawnLevel)`

### Formulas.Cube_Energy(Level)
`3^(Level − 1)`

### Formulas.Cube_Power(Level)
`2^(Level − 1)`

### Formulas.Cube_Orbs(Level)
`1.5^(Level − 1)`

### Formulas.Playtime_Prisms(Playtime)
`1 + 0.002 × floor(Playtime / 60)`

---

## RUNES

### Formulas.Rune_Luck(Player, convert, runeName)
Returns 1 if `Settings.RuneLuck.Value` is false. Plain numbers.
`v = 1 × Product_RuneLuck × Favorites_RuneLuck(ReplicatedStorage.Favorites) × 1.1 if Stats.RLBoost`
`× Up(Prisms_RuneLuck) × Up(Orbs_RuneLuck) × Up(Prisms_RuneLuck2) × Up(Tickets_RuneLuck) × Up(Tickets_RuneLuck2)`
`× R(Rainbow_RuneLuck) × Unknown_RuneLuck(Runes.Unknown, Player) × Antimatter_RuneLuck(Runes.Antimatter, Player) × R(Iridium_RuneLuck) × R(Aether_…) × R(Frigid_…) × R(Master_…) × R(Royalty_…) × R(Kingslayer_…) × R(Divinity_…) × R(Oscillon_…) × R(Sigil_RuneLuck)`
`× min(1 + (Chromium/1e21)×0.01, 2)` if Chromium_RuneLuck1 > 0 and Chromium > 0
`× Haze(0.3, 25)`
`× 1.25 if Tier ≥ 5`
`× Stats.Color_Rune_Luck / Arctic_Rune_Luck / Polychrome_Rune_Luck` if runeName == "Color"/"Arctic"/"Polychrome"
`× Stats.Global_Rune_Luck × 1.5 if Spheres ≥ 1e69 × 2 if gamepass MoreRuneLuck × 2 if RuneLuckElixirDuration > 1 × 1.25 if Stats.Akn_Follow`
`× (1 + attr PlaytimeLuckIncrease/100)` if set
`× 2 if Realm == "One" and AscensionOne`
`× Donation_RuneLuck(RobuxDonated)`. `convert` unused.

### Formulas.Rune_Bulk(Player, Convert, runeName)
Additive phase: `v = 1 + 1 if Stats.Verified + Orbs_RuneBulk(Orbs) + Upgrades Orbs_RuneBulk(no P) + Prisms_RuneBulk(no P) + Tickets_RuneBulk + Prisms_RuneBulk4(no P)`
`+ R(Emberglow_RuneBulk) + R(Prismatic_…) + R(Elite_…) + R(Crown_…) + R(Sovereign_…) + R(Divinity_…) + R(Shyft_…) + R(Overlord_…) + R(Array_RuneBulk1) + R(Disarray_RuneBulk1) + R(Planet_RuneBulk1)`
`+ attr PlaytimeBulkIncrease + 10 if Realm=="One" and AscensionOne + 3 if Spheres ≥ 5e72 + 1.25 if Stats.Icy_Follow`
`+ TierBonus` (Tier ≥7 → 1; ≥10 → 3) `+ Product_RuneBulk`
Multiplicative: `× Stats.Global_Rune_Bulk × R(_RuneBulk)` for: Blizzard, Boundless, Mystery, Antimatter, Abyssium, Gleam, Oblivion, Immortality, Vanta, Odyssey_RuneBulk1, Odyssey_RuneBulk2, Destiny, Squid, Array_RuneBulk2, Disarray_RuneBulk2, Bolt_RuneBulk1, Bolt_RuneBulk2, Zephyr, Primordial, Sigil, Omen, Bone, Apex, Liberty, Constellation_RuneBulk1, Constellation_RuneBulk2, Vanguard_RuneBulk1, Vanguard_RuneBulk2, Eternal, Raze, Vehemence
`× Up(Tickets_RuneBulk2) × Up(Tickets_RuneBulk3) × 3 (event) × Product_RuneBulk2`
`× min(1 + 0.01 × (Chromatize − 149), 4.5)` if Chromatize ≥ 150
`× Stats.Polychrome_Rune_Bulk / Arctic_Rune_Bulk / Royal_Rune_Bulk` if runeName == "Polychrome"/"Arctic"/"5MRoyal" (and stat exists and > 0)
`× 1.25 if Iris_Follow × 1.1 if RBBoost × 1.25 if BulkFix × (1 + min(Loot × 0.0075, 2)) if Loot ≥ 1 × 1.25 if GlobalElixirDuration > 0`
Exponents (sequential): `^ R(Planet_RuneBulk2) ^ R(Oscillon_RuneBulk) ^ R(Cyclone_RuneBulk) ^ Up(Prisms_RuneBulk3) ^ Up(Tickets_RuneBulk4) ^ Up(Chromium_RPS6)`
If Convert: `s = 1/Rune_Speed(Player)`; if s − 60 > 0: `× (1 + (s − 60)/60)`
`× 1.1 if Prisms_RuneBulk2 > 0 × 1.5 if Prisms_RuneClone > 0`
`return floor(v)`.

### Formulas.Rune_Speed(Player)
Returns seconds per open (lower = faster). `v = 1 / 3 (event) / Product_RuneSpeed / 1.1 if RSBoost / 1.1 if RSBoost2 / 1.15 if attr Premium`
`/ Up(Orbs_RuneSpeed)(no P) / Up(Prisms_RuneSpeed)(no P) / Up(Tickets_RuneSpeed) / Up(Tickets_RuneSpeed2) / Up(Tickets_RuneSpeed3) / Up(Chromium_RuneSpeed) / Up(Prisms_RuneSpeed2) / Up(Prisms_RuneSpeed3) / Up(Prisms_RPS) / Up(Prisms_RPS2) / Up(Chromium_RPS1..5) / Up(Chromium_RPS7..10) / Up(Reflection_RPS1)` (all from Chromium_RuneSpeed onward without Player)
`/ R(_RuneSpeed)` for: Vibrance, Earthvein, Refraction, Subzero, Boundless, Kingslayer, Thorn, Prosperity, Almighty, HyperFinality, Etherborn, Gleam, Mirror_RuneSpeed1, Mirror_RuneSpeed2, Vanta, Frostbite, Odyssey, Destiny, Cyclone, Stray, Triarch_RuneSpeed1/2/3, Zephyr, Glyph, Ankh, Omen, Whirl, Riptide_RuneSpeed1/2, Star, CosmicDust, Apex, Torrent, Sorcerer_RuneSpeed1/2, Strix, Onyx_RuneSpeed1/2, Liberty, Rocket, Vanguard_RuneSpeed1/2, Eternal, Raze, Bozo, Glint, Rage, Malevolence, Axium, Mommy, Hyperion, Soup_RuneSpeed1/2, Paracosm
`/ Donation_RuneSpeed(RobuxDonated) / 1.25 if Spheres ≥ 1e69 / 1.25 if Luffy_Follow / 2 if gamepass MoreRuneSpeed`
`/ (1 + min(Hail × 0.075, 4)) if Hail ≥ 1 / (1 + min(Chroma × 0.00001, 0.25)) if Chroma ≥ 1 / (1 + min(Shine × 0.0001, 0.1)) if Shine ≥ 1`
`/ 1.75 if attr ServerBoosted / 2 if RuneSpeedElixirDuration > 1 / TierBonus` (Tier ≥ 7 → 1.25).

### Formulas.Rune_Clone(Player)
`1 + 1 if Upgrades.Prisms_RuneClone.Value` (truthy check).
Notes: numeric 0 is truthy in Luau → always returns 2 (likely should be `> 0`).

### Formulas.RPS(Rune_Bulk, Rune_Speed)
`Rune_Bulk × (1 / Rune_Speed)` (visual only).

### Formulas.Rune_OpenTime(Afford, RPS)
`Afford / RPS`

### Formulas.Rune_Afford(Currency, Cost)
`a = toNumber(Currency / Cost)`; `0 if a < 0 else floor(a)`.

---

## WALKSPEED

### Formulas.Walkspeed(Player)
`Base_WS + 7 if Prime + 12 if gamepass Sprint + 5 if Stats.Blitz + (4 − GGRobuxRank)×2 if GGRobuxRank > 0 + 5 if attr GroupMember + Up(Prisms_Walkspeed) + R(Prismatic_Walkspeed) + R(Shyft_Walkspeed)`

---

## EFFECTS

### Formulas.Flame_Energy(Currency)
`1 + 0.5 × Currency`

### Formulas.Flame_XP(Currency)
`1 if Currency < 1e6; else Currency^0.03`

### Formulas.Gears_Speed(Currency)
`0.025 × Currency`

### Formulas.Accelerator_PrismSpeed(Currency)
`1 + 0.1 × Currency`

### Formulas.Accelerator_CubeSpeed(Currency)
`1 + 0.05 × Currency`

### Formulas.Power_Damage(Currency, Player)
`1 if Currency < 1; else Currency^p`, `p = 0.075 (+0.1 if Upgrades.Prisms_DMG > 0 → 0.175)`.

### Formulas.Power_Spheres(Currency, Player)
`1 if Currency < 1; else Currency^0.01`

### Formulas.Prisms_Flame(Currency, Player)
`1 if Currency < 1; else Currency^2`

### Formulas.Prisms_Prisms(Currency, Player)
`1 if Currency < 1; else Currency^0.25`

### Formulas.Level_Energy(Currency)
`1 if Currency ≤ 0; else 1.3^Currency`

### Formulas.Orbs_Energy(Currency)
`1 if Currency ≤ 20; else Currency / 20`

### Formulas.RuneLuck_RuneBulk(Currency)
`1 if Currency ≤ 1; else Currency` (unused in module)

### Formulas.Orbs_Flame(Currency)
`1 if Currency < 500; else Currency / 500`

### Formulas.Orbs_RP(Currency, Player)
`1 if Currency < 1; else Currency^0.15`

### Formulas.Orbs_Power(Currency)
`1 if Currency < 1e4; else Currency / 1e4`

### Formulas.Orbs_RealmPoints(Currency, Player)
`1 if Currency < 4e15; else (Currency / 4e15)^s`, `s = 0.35 + 0.01 × min(Upgrades.Prisms_RPEnhance, 5)` (max 0.40).

### Formulas.Orbs_Flesh(Currency)
`1 if Currency < 4e28; else (Currency / 4e28)^0.75`

### Formulas.Tickets_Spheres(Currency)
`1 + Currency`

### Formulas.Orbs_RuneBulk(Currency)
`+1` each for Currency ≥ 1e39, ≥ 1e78, ≥ 1e147 (0–3, additive).

### Formulas.Spheres_Spheres(Currency)
`1.5^Currency`

---

## COSTS

### Formulas.Tier_Cost(Tier)
`Tier = floor(Tier)`; table lookup:

| Tier | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 100 | 1e6 | 5e9 | 2.5e15 | 7.5e23 | 1e40 | 1e65 | 1e153 | 1e276 | "1e978" | "5e60" (Droplets) | "7.5e113" | "1e195" | "9e999…9" (unreachable) |

Fallback: `(100 × Scale^Tier)^Super`, Scale = 100 (+50 if Tier ≥ 2), Super = 1 (+0.15 if ≥3, +0.25 if ≥4).
Notes: table entries are mixed number/string types.

### Formulas.Chromatize_Cost(Chromatize)
Table: 1 "1e43"; 2 "1e50"; 3 "1e55"; 4 "1e60"; 5 "1e65"; 6 "1e70"; 7 "1e85"; 8 "1e95"; 9 "1e105"; 10 "5e178"; 1001 "1e3333…3" (wall).
Fallback (11–1000, ≥1002): `(1e40 × Scale^C)^Super`, Scale = 100 (+50 if C ≥ 2), Super = 1 (+0.15 if ≥3, +0.25 if ≥4) → `(1e40 × 150^C)^1.4`.
Notes: fallback for C=11 ≈ (1e40·150¹¹)^1.4 ≈ 1e89, cheaper than C=10's 5e178 (non-monotonic).

### Formulas.Chromify_Cost(Chromify)
Table: 0 "1e23"; 1 "7.5e36"; 2 "1e78"; 3 "1e1000…0" (wall).
Fallback: `(1e24 × Scale^C)^Super`, Scale = 10000 (+50 if C ≥ 2), Super = 1 (+0.15 if ≥3, +0.25 if ≥4).

### Formulas.Flame_Cost(Player)
`50`

### Formulas.Gears_Cost(Gears)
`1e7 × 1e3^Gears`

### Formulas.Accelerator_Cost(Accelerators)
`1e243 × 75^Accelerators`

### Formulas.Power_Cost(Player)
`50`

### Formulas.Reflection_Cost(Player)
`1e20`

### Formulas.Spheres_Cost(Player)
`25 × 4^Sphere_Levels`

### Formulas.Accelerator_Levels(Player)
`clamp(30 + Upgrades("Prisms_Accelerator"):GetEffect(level), 30, 60)`

---

## Bug summary
- Energy: `Earthvein_Energy` gets `Runes.Oak`.
- Flesh: `Thunderstorm_Flesh` gets `Runes.Vibrance`.
- Droplets: `Omniscient_Droplets`, `Almighty_Droplets` get `Runes.Frostveil`.
- Chest_Chance: `Primordial_ChestChance` gets `Runes.Prosperity`.
- Orbs: `Prisms_Orbs1` effect evaluated at `Prisms_Orbs2` level.
- ArcticPoints: Tier_Bonus computed, never applied.
- Prisms: `Stats.Draco_Follow` missing `.Value` (always ×1.25); Chromium_Prisms3 / Chromium_Icicles3 boosts use `Prisms` as base and only apply while < 10.
- Spheres: Chromium_SpheresEnhance uses `Spheres^0.75` (not Chromium); duplicated nested if.
- Rune_Clone: `if Upgrades.Prisms_RuneClone.Value` is truthy for 0 → always 2.
- Chromatize_Cost: fallback past 10 is cheaper than table value at 10.

---

# Rune System Reference

Source: `ReplicatedStorage.Framework.Shared.Modules.RuneFormulas` (346 functions), `Libraries.Runes.*`, `Libraries.{Global,Ancient,Madness,Ultra}Rune`, `Shared.Modules.RuneInfo`.

**Notes**
- `A` = number of that rune owned (`Amount`, plain Luau number). RuneFormulas uses **no EternityNum** calls — all plain `number` math with `math.clamp(value, min, max)`.
- `1e300` max = effectively uncapped. `^` is plain exponent.
- Formulas of form `k·A (returns 1 if A≤0)` are *linear from 0*, not `1 + k·A`.
- Source code comments (e.g. `-- Noob Rune >> Energy Boost`) are frequently copy-paste wrong; function names are authoritative. The source's section headers after line 1486 are all `--[ 5M Beginner ]--` though functions from every pack follow; grouping below is by rune name → pack.

## 1. Rune packs

`RuneInfo` builds `{[RuneName] = Chance}` from every module in `Libraries.Runes` (the 9 packs; not Global/Ancient/Madness/Ultra).

### Roll mechanics (`Libraries.Runes` main module)
- `luckThreshold = 1e14`. Pack `Weight` = sum of rune Chances.
- `GetRuneTable(Luck)`: for each rune in listed order, if `Chance < 0.1` and `Luck > 1` and `RuneLuck=true`, chance ×= Luck. If Luck>1 and remaining weight − newChance ≤ 0, that rune gets the remaining weight and the loop **breaks** (further runes dropped; this entry lacks RuneLuck/RuneClone flags). Remaining weight is decremented otherwise. Table then sorted ascending by chance.
- `Roll(Luck, table, Bulk)`: per rune, `RNG_Luck ∈ U(1e-14, 1/Luck)`; `Potential = Bulk × chance`. If Potential < 1 (and name ≠ "Bomboclat"): pity attribute `<Name>Pity += Potential`; if pity ≥ 1 **or** RNG_Luck ≤ chance → pity reset, Potential = 1. Skip if still < 1. Else `round(Potential)`. Stops once cumulative opens ≥ Bulk.
- Rune Clone (only RuneClone=true runes): ×2 if `RuneCloneProduct>0` and rawChance ≥ 1/`Formulas.Product_RuneClone` and no `Prisms_RuneClone` upgrade; ×2 if no product but has `Prisms_RuneClone`; ×3 if both (and chance condition). Note: with both owned but chance condition false → no multiplier at all (bug).
- Rewards applied via a Pending queue flushed every 5 s, 1 s wait per rune type.
- Cost = `Bulk × Cost` (EN.mul). `CanAfford` = EN `currency ≥ Cost`.
- `GetRune` (single) uses same RNG range, cumulative chance in listed order.

### Arctic pack
- Currency: **Chromium**, Cost: **1e6** per open. Unlock: AscensionOne_Req, HasRequirement: `Player.Stats.Chromatize.Value >= 7`. Pack-level RuneLuck flag: True.

- Total weight ≈ 1

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Glint | `1/3.33e296` | 3.33e+296 | false | false |
| Frostbite | `1/3e103` | 3e+103 | false | false |
| Mirror | `1/7.5e60` | 7.5e+60 | false | false |
| Blizzard | `1/1e11` | 1e+11 | false | false |
| Subzero | `1/2.5e14` | 2.5e+14 | true | true |
| Frostveil | `1/5e12` | 5e+12 | true | true |
| Hailstorm | `1/2.5e10` | 2.5e+10 | true | true |
| Avalanche | `1/1.5e8` | 1.5e+08 | true | true |
| Icy | `1/2.5e5` | 2.5e+05 | true | true |
| Snow | `0.01` | 100 | true | true |
| Snowflake | `.99` | 1.01 | true | true |

### Basic pack
- Currency: **Flame**, Cost: **1e3** per open. Unlock: Tier_Req = 3. Pack-level RuneLuck flag: False.

- Total weight ≈ 1.0003

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Nexus | `1/1e303` | 1e+303 | false | false |
| Strix | `1/2.5e256` | 2.5e+256 | false | false |
| Apex | `1/2.5e212` | 2.5e+212 | false | false |
| Disarray | `1/7.5e174` | 7.5e+174 | false | false |
| Array | `1/1e135` | 1e+135 | false | false |
| Shyft | `1/7.5e55` | 7.5e+55 | false | false |
| HyperFinality | `1/7.5e32` | 7.5e+32 | false | false |
| Mystery | `1/1e12` | 1e+12 | false | false |
| Unknown | `1/2.5e6` | 2.5e+06 | true | true |
| Exotic | `0.0005` | 2000 | true | true |
| Ascendant | `.0198` | 50.51 | true | true |
| Rare | `.18` | 5.556 | true | true |
| Unique | `.3` | 3.333 | true | true |
| Basic | `.5` | 2 | true | true |

### Beginner pack
- Currency: **Tickets**, Cost: **1** per open. Unlock: Tier_Req = 1. Pack-level RuneLuck flag: True.

- Total weight ≈ 1.0005

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Hyperion | `1/5e306` | 5e+306 | false | false |
| Vanguard | `1/4e267` | 4e+267 | false | false |
| Sorcerer | `1/1e234` | 1e+234 | false | false |
| Overlord | `1/5e58` | 5e+58 | false | false |
| Superstar | `1/2.5e10` | 2.5e+10 | false | false |
| Elite | `1/5e10` | 5e+10 | true | true |
| Legend | `1/7.5e8` | 7.5e+08 | true | true |
| Champion | `1/1e7` | 1e+07 | true | true |
| Master | `1/5e5` | 5e+05 | true | true |
| Experienced | `1/2e3` | 2000 | true | true |
| Intermediate | `.05` | 20 | true | true |
| Noob | `.95` | 1.053 | true | true |

### Color pack
- Currency: **Realm Points**, Cost: **2.5e4** per open. Unlock: Tier_Req = 6. Pack-level RuneLuck flag: True.

- Total weight ≈ 1.00003

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Onyx | `1/1.25e248` | 1.25e+248 | false | false |
| Whirl | `1/1e204` | 1e+204 | false | false |
| Vanta | `1/7e95` | 7e+95 | false | false |
| Gleam | `1/1e47` | 1e+47 | false | false |
| Bloom | `1/7.5e9` | 7.5e+09 | false | false |
| Vibrance | `1/5e7` | 5e+07 | true | true |
| Rainbow | `1/3e4` | 3e+04 | true | true |
| Chrome | `0.005` | 200 | true | true |
| Neon | `.025` | 40 | true | true |
| Radiance | `.17` | 5.882 | true | true |
| Colorful | `.25` | 4 | true | true |
| Tinted | `.55` | 1.818 | true | true |

### Cryo pack
- Currency: **ArcticPoints**, Cost: **50** per open. Unlock: AscensionOne_Req, HasRequirement: `Player.Upgrades.Freeze3.Value >= 1`. Pack-level RuneLuck flag: False.

- Total weight ≈ 0.990002

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Soup | `1/2.5e307` | 2.5e+307 | false | false |
| Mommy | `1/7.5e304` | 7.5e+304 | false | false |
| Bozo | `1/1e295` | 1e+295 | false | false |
| Buff | `1/2e222` | 2e+222 | false | false |
| Stray | `1/1e160` | 1e+160 | false | false |
| Garmin | `1/1e42` | 1e+42 | false | false |
| Icequake | `1/7.5e12` | 7.5e+12 | true | true |
| Frigid | `1/2.5e11` | 2.5e+11 | true | true |
| Shiver | `1/7.5e7` | 7.5e+07 | true | true |
| Breeze | `1/500e3` | 5e+05 | true | true |
| Mist | `.99` | 1.01 | true | true |

### Galactic pack
- Currency: **Tickets**, Cost: **500** per open. Unlock: AscensionOne_Req, HasRequirement: `Player.Stats.Chromatize.Value >= 750`. Pack-level RuneLuck flag: False.

- Total weight ≈ 1.04e-207

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Paracosm | `1/4e307` | 4e+307 | false | false |
| Axium | `1/1e306` | 1e+306 | false | false |
| Galaxy | `1/1.5e304` | 1.5e+304 | false | false |
| Rocket | `1/1.5e260` | 1.5e+260 | false | false |
| Planet | `1/3.33e238` | 3.33e+238 | false | false |
| Constellation | `1/2.5e223` | 2.5e+223 | false | false |
| Star | `1/2.5e208` | 2.5e+208 | false | false |
| CosmicDust | `1/1e207` | 1e+207 | false | false |

### Nature pack
- Currency: **Spheres**, Cost: **5e27** per open. Unlock: Tier_Req = 9. Pack-level RuneLuck flag: False.

- Total weight ≈ 1.0001

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Hurricane | `1/1e304` | 1e+304 | false | false |
| Torrent | `1/2.5e228` | 2.5e+228 | false | false |
| Riptide | `1/2e205` | 2e+205 | false | false |
| Bolt | `1/1.75e182` | 1.75e+182 | false | false |
| Cyclone | `1/2.5e140` | 2.5e+140 | false | false |
| Squid | `1/1e130` | 1e+130 | false | false |
| Thorn | `1/1e13` | 1e+13 | false | false |
| Dreamscape | `1/1.25e9` | 1.25e+09 | true | true |
| Emberglow | `1/2.5e8` | 2.5e+08 | true | true |
| Earthvein | `1/3e6` | 3e+06 | true | true |
| Thunderstorm | `1/2.5e5` | 2.5e+05 | true | true |
| Wavecaller | `1/1e4` | 1e+04 | true | true |
| Nightshade | `0.0025` | 400 | true | true |
| Skylight | `.0475` | 21.05 | true | true |
| Dew | `.15` | 6.667 | true | true |
| Moss | `.20` | 5 | true | true |
| Oak | `.60` | 1.667 | true | true |

### Polychrome pack
- Currency: **Prisms**, Cost: **1e15** per open. Unlock: AscensionOne_Req. Pack-level RuneLuck flag: True.

- Total weight ≈ 0.99992

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Raze | `1/7.5e286` | 7.5e+286 | false | false |
| Zephyr | `1/5e191` | 5e+191 | false | false |
| Oblivion | `1/5e73` | 5e+73 | false | false |
| Oscillon | `1/3.33e27` | 3.33e+27 | false | false |
| Abyssium | `1/1.25e20` | 1.25e+20 | false | false |
| Vexed | `1/5e10` | 5e+10 | false | false |
| Aether | `1/1.5e10` | 1.5e+10 | false | false |
| Refraction | `1/1e12` | 1e+12 | true | true |
| Prismatic | `1/5e9` | 5e+09 | true | true |
| Spectrum | `1/7.5e8` | 7.5e+08 | true | true |
| Iridium | `1/5e6` | 5e+06 | true | true |
| Shimmer | `1/5e4` | 5e+04 | true | true |
| Glow | `.9999` | 1 | true | true |

### Royal pack
- Currency: **Tickets**, Cost: **50** per open. Unlock: Tier_Req = 1. Pack-level RuneLuck flag: True.

- Total weight ≈ 0.990004

| Rune | Chance | 1 in X | RuneLuck | RuneClone |
|---|---|---|---|---|
| Liberty | `1/3.5e256` | 3.5e+256 | false | false |
| Triarch | `1/1.5e165` | 1.5e+165 | false | false |
| Destiny | `1/5e121` | 5e+121 | false | false |
| Odyssey | `1/1.5e109` | 1.5e+109 | false | false |
| Immortality | `1/2e82` | 2e+82 | false | false |
| Prosperity | `1/2.5e22` | 2.5e+22 | false | false |
| Divinity | `1/7.5e16` | 7.5e+16 | false | false |
| Kingslayer | `1/2.5e11` | 2.5e+11 | false | false |
| Sovereign | `1/2.5e15` | 2.5e+15 | true | true |
| Imperial | `1/1e14` | 1e+14 | true | true |
| Monarch | `1/2e12` | 2e+12 | true | true |
| Throne | `1/1e10` | 1e+10 | true | true |
| Crown | `1/7.5e7` | 7.5e+07 | true | true |
| Royalty | `1/2.5e5` | 2.5e+05 | true | true |
| Gilded | `.99` | 1.01 | true | true |

### Special roll pools (Global / Ancient / Madness / Ultra)
These roll one rune: `Luck = U(lo, 1)`; walk list in order, first entry with `Luck ≤ value` wins (thresholds are **not cumulative**, so actual odds = threshold − previous threshold). If none hit (Luck > last value), it re-rolls recursively. No currency/cost defined in these modules (triggered elsewhere).

**GlobalRune** (RNG `U(1/1e5, 1)`)

| Rune | Threshold | Effective chance (before reroll) |
|---|---|---|
| Etherborn | `0.0001` | 0.0001 |
| Antimatter | `0.002` | 0.0019 |
| Darkmatter | `0.048` | 0.046 |
| Lightmatter | `0.95` | 0.902 |

**AncientRune** (RNG `U(1/1e5, 1)`)

| Rune | Threshold | Effective chance (before reroll) |
|---|---|---|
| Omen | `0.00003` | 3e-05 |
| Ankh | `0.00025` | 0.00022 |
| Sigil | `0.00175` | 0.0015 |
| Glyph | `0.018` | 0.01625 |
| Bone | `0.15` | 0.132 |
| Dust | `0.83` | 0.68 |

**MadnessRune** (RNG `U(1/2e5, 1)`)

| Rune | Threshold | Effective chance (before reroll) |
|---|---|---|
| Malevolence | `1/100000` | 1e-05 |
| Vehemence | `1/25000` | 3e-05 |
| Violence | `1/7500` | 9.33333e-05 |
| Rage | `0.005` | 0.00486667 |
| Mad | `0.995` | 0.99 |

**UltraRune** (RNG `U(1/1e5, 1)`)

| Rune | Threshold | Effective chance (before reroll) |
|---|---|---|
| Eternal | `1/1.75e4` | 5.71429e-05 |
| Primordial | `0.0002` | 0.000142857 |
| Boundless | `0.001` | 0.0008 |
| Almighty | `0.0088` | 0.0078 |
| Omnipotent | `0.09` | 0.0812 |
| Omniscient | `0.9` | 0.81 |

## 2. RuneFormulas (by pack)

Columns: Formula (before clamp) | Min | Max (clamp) | Note

### Arctic

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Snowflake_Spheres | 1 + 0.25·A | 1 | 1e300 |  |
| Snowflake_Droplets | 1 + 0.0001·A | 1 | 1e300 |  |
| Snow_Water | 1 + 0.01·A | 1 | 1e300 |  |
| Snow_Ice | 1 + 0.001·A | 1 | 1e300 |  |
| Icy_Spheres | 1 + 1·A | 1 | 1e300 |  |
| Icy_Prisms | 1 + 0.25·A | 1 | 1e300 |  |
| Icy_Chromium | 1 + 0.01·A | 1 | 3 |  |
| Avalanche_Water | 1 + 0.5·A | 1 | 1e300 |  |
| Avalanche_Ice | 1 + 0.25·A | 1 | 1e300 |  |
| Avalanche_ArcticPoints | 1 + 0.1·A | 1 | 1e300 |  |
| Avalanche_Icicles | 1 + 0.0001·A | 1 | 5 |  |
| Hailstorm_Chromium | 1 + 0.05·A | 1 | 1e300 |  |
| Hailstorm_Tickets | 1 + 0.005·A | 1 | 2 |  |
| Frostveil_Droplets | 1 + 4·A | 1 | 1e300 |  |
| Frostveil_Prisms | 1 + 1·A | 1 | 1e300 |  |
| Frostveil_ArcticPoints | 1 + 0.25·A | 1 | 1e300 |  |
| Frostveil_Icicles | 1 + 0.1·A | 1 | 1e300 |  |
| Subzero_RuneSpeed | 1 + 0.025·A | 1 | 2 |  |
| Subzero_Chromium | 1 + 0.5·A | 1 | 1e300 |  |
| Subzero_Water | 1 + 6.5·A | 1 | 1e300 |  |
| Blizzard_RuneBulk | 1 + 0.05·A | 1 | 1.3 |  |
| Mirror_RuneSpeed1 | 1 + 0.0075·A | 1 | 50000 |  |
| Mirror_RuneSpeed2 | 1 + 0.0025·A | 1 | 500000 |  |
| Frostbite_RuneSpeed | 1 + 0.01·A | 1 | 100000 |  |
| Glint_RuneSpeed | 1.000001^A | 1 | 500 |  |
| Glint_Chrome1 | 1 + 0.05·A | 1 | 100 |  |
| Glint_Chrome2 | 1 + 0.000001·A | 1 | 1000 |  |

### Basic

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Basic_Energy | 1 + 0.005·A | 1 | 1e300 |  |
| Unique_Energy | 1 + 0.01·A | 1 | 1e300 |  |
| Rare_Flame | 1 + 0.005·A | 1 | 1e300 |  |
| Ascendant_Energy | 1 + 0.075·A | 1 | 1e300 |  |
| Ascendant_Flame | 1 + 0.015·A | 1 | 1e300 |  |
| Exotic_Energy | 1 + 1·A | 1 | 1e300 |  |
| Exotic_Flame | 1 + 0.6·A | 1 | 1e300 |  |
| Exotic_Power | 1 + 0.5·A | 1 | 1e300 |  |
| Unknown_RealmPoints | 2.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Unknown_Damage | 5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Unknown_RuneLuck | 1 + 0.25·A | 1 | 3 |  |
| Mystery_RobuxTokenCD | 0.1·A | 0 | 60 |  |
| Mystery_RuneBulk | 1 + 0.001·A | 1 | 5 |  |
| HyperFinality_RuneSpeed | 1.00025^A | 1 | 1e12 |  |
| Shyft_RuneBulk | 10·A | 1 | 500000 | Base 0 but clamp min 1 |
| Shyft_Walkspeed | 0.001·A | 1 | 30 | Base 0 but clamp min 1 → effectively max(1, 0.001·A) until A>1000 |
| Array_RuneBulk1 | 3500·A | 1 | 2.5e10 | Base 0 but clamp min 1 |
| Array_RuneBulk2 | 1 + 0.0025·A | 1 | 25 |  |
| Array_Tickets | 1 + 0.0005·A | 1 | 7.5 |  |
| Disarray_RuneBulk1 | 1.0000075^A | 1 | 1e12 | Base 0 + b^A → A=0 gives 1 |
| Disarray_RuneBulk2 | 1 + 0.0033·A | 1 | 250 |  |
| Apex_RuneSpeed | 1.0005^A | 1 | 1000 |  |
| Apex_RuneBulk | 1.00000033^A | 1 | 25000 |  |
| Strix_RuneSpeed | 1 + 0.01·A | 1 | 2.5 |  |
| Nexus_Chrome | 1 + 0.01·A | 1 | 1e6 |  |

### Beginner

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Noob_Energy | 1 + 0.1·A | 1 | 1e300 |  |
| Intermediate_Flame | 1 + 0.25·A | 1 | 1e300 |  |
| Intermediate_Tickets | 1 + 0.001·A | 1 | 1.2 |  |
| Experienced_Energy | 1 + 0.5·A | 1 | 1e300 |  |
| Experienced_Power | 1 + 0.3·A | 1 | 1e300 |  |
| Experienced_Damage | 1 + 0.01·A | 1 | 2 |  |
| Master_Flame | 1 + 1·A | 1 | 1e300 |  |
| Master_Flesh | 1 + 0.1·A | 1 | 1e300 |  |
| Master_RuneLuck | 1 + 0.01·A | 1 | 1.25 |  |
| Master_Droplets | 1 + 0.25·A | 1 | 3 |  |
| Champion_Energy | 1 + 2·A | 1 | 1e300 |  |
| Champion_Orbs | 1 + 0.33·A | 1 | 1e300 |  |
| Champion_Prisms | 1 + 0.1·A | 1 | 3 |  |
| Legend_RealmPoints | 1 + 1·A | 1 | 1e300 |  |
| Legend_Flesh | 1 + 2·A | 1 | 1e300 |  |
| Legend_Spheres | 1 + 0.5·A | 1 | 1e300 |  |
| Legend_Tickets | 1 + 0.05·A | 1 | 1.75 |  |
| Elite_Orbs | 1 + 3·A | 1 | 1e300 |  |
| Elite_Prisms | 1 + 0.25·A | 1 | 1e300 |  |
| Elite_RuneBulk | 1·A | 0 | 5 |  |
| Superstar_Energy | 1 + 1e6^A | 1 | 1e300 | Additive: 1 + 1e6^A → 2 at A=0; overflows to inf past A≈51 then clamps 1e300 |
| Overlord_RuneBulk | 24·A | 1 | 1e8 | Base 0 but clamp min 1 |
| Overlord_Energy | 1.01^A | 1 | 1e300 |  |
| Sorcerer_RuneSpeed1 | 1 + 0.005·A | 1 | 100 |  |
| Sorcerer_RuneSpeed2 | 1 + 0.005·A | 1 | 1000 |  |
| Sorcerer_Tickets | 1.00005^A | 1 | 5e10 |  |
| Vanguard_RuneSpeed1 | 1.001^A | 1 | 12.5 |  |
| Vanguard_RuneSpeed2 | 1.0000000001^A | 1 | 700 |  |
| Vanguard_RuneBulk1 | 1.0000225^A | 1 | 4000 |  |
| Vanguard_RuneBulk2 | 1.0000000000001^A | 1 | 15000 |  |
| Hyperion_Chroma1 | 1 + 0.0005·A | 1 | 1e6 |  |
| Hyperion_Chroma2 | 1 + 0.002·A | 1 | 1e6 |  |
| Hyperion_RuneSpeed | 1 + 0.00025·A | 1 | 1.5 |  |

### Color

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Tinted_Energy | 1 + 0.2·A | 1 | 1e300 |  |
| Colorful_Energy | 1 + 0.4·A | 1 | 1e300 |  |
| Colorful_Flesh | 1 + 0.001·A | 1 | 1e300 |  |
| Radiance_Energy | 1 + 0.3·A | 1 | 1e300 |  |
| Radiance_Power | 1 + 0.05·A | 1 | 1e300 |  |
| Neon_Energy | 1 + 0.75·A | 1 | 1e300 |  |
| Neon_Damage | 1 + 0.025·A | 1 | 1e300 |  |
| Neon_RealmPoints | 1 + 0.01·A | 1 | 2.5 |  |
| Chrome_Energy | 2·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Chrome_Flame | 1 + 0.5·A | 1 | 1e300 |  |
| Chrome_Orbs | 1 + 0.1·A | 1 | 1e300 |  |
| Chrome_Prisms | 1 + 0.15·A | 1 | 2 |  |
| Rainbow_Flame | 1 + 5.5·A | 1 | 1e300 |  |
| Rainbow_Damage | 1 + 1.25·A | 1 | 1e300 |  |
| Rainbow_Orbs | 2·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Rainbow_RuneLuck | 1 + 0.04·A | 1 | 1.2 |  |
| Vibrance_Energy | 24·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Vibrance_Flame | 14·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Vibrance_Flesh | 2·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Vibrance_Orbs | 6.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Vibrance_RuneSpeed | 1 + 0.25·A | 1 | 2 |  |
| Bloom_Spheres | 1e3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Gleam_RuneSpeed | 1 + 0.01·A | 1 | 1000 |  |
| Gleam_RuneBulk | 1 + 0.001·A | 1 | 10000 |  |
| Vanta_RuneSpeed | 1 + 1.000015^A | 1 | 3e6 | Additive: 1 + 1.000015^A → 2 at A=0 |
| Vanta_RuneBulk | 1 + 0.0005·A | 1 | 3 |  |
| Vanta_Tickets | 1.000000000000007^A | 1 | 1e39 | Base 1.000000000000007 ≈ 1+7.1e-15 in double precision |
| Whirl_RuneSpeed | 1 + 0.005·A | 1 | 25 |  |
| Whirl_Tickets | 1 + 0.001·A | 1 | 1000 |  |
| Onyx_RuneSpeed1 | 1 + 0.002·A | 1 | 75 |  |
| Onyx_RuneSpeed2 | 1.0000015^A | 1 | 1e5 |  |

### Cryo

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Mist_Spheres | 1 + 0.1·A | 1 | 1e300 |  |
| Breeze_Droplets | 1 + 0.005·A | 1 | 1e300 |  |
| Breeze_Water | 1 + 0.0001·A | 1 | 1e300 |  |
| Shiver_Water | 1 + 0.075·A | 1 | 1e300 |  |
| Shiver_Prisms | 1 + 0.005·A | 1 | 1e300 |  |
| Shiver_ArcticPoints | 1 + 0.02·A | 1 | 4 |  |
| Frigid_Droplets | 1 + 0.5·A | 1 | 1e300 |  |
| Frigid_Ice | 1 + 0.05·A | 1 | 1e300 |  |
| Frigid_ArcticPoints | 1 + 0.01·A | 1 | 1e300 |  |
| Frigid_RuneLuck | 1 + 0.001·A | 1 | 1.15 |  |
| Icequake_Water | 1 + 5·A | 1 | 1e300 |  |
| Icequake_Ice | 1 + 1·A | 1 | 1e300 |  |
| Icequake_Prisms | 1 + 0.25·A | 1 | 1e300 |  |
| Icequake_Spheres | 1 + 0.5·A | 1 | 1e300 |  |
| Icequake_DropletsCD | 0.001·A | 0 | 0.4 |  |
| Garmin_Tickets | 1.0001^A | 1 | 1e51 |  |
| Stray_RuneSpeed | 1.0002^A | 1 | 75000 |  |
| Stray_Tickets | 1.00002^A | 1 | 1e32 |  |
| Buff_Tickets1 | 1.002^A | 1 | 5e4 |  |
| Buff_Tickets2 | 1.0004^A | 1 | 1e6 |  |
| Bozo_BaseChrome | 0.1·A | 1 | 50 | Base 0 but clamp min 1 |
| Bozo_RuneSpeed | 1 + 0.05·A | 1 | 3 |  |
| Mommy_RuneSpeed | 1 + 0.001·A | 1 | 2 |  |
| Mommy_Shine | 1 + 0.01·A | 1 | 1e6 |  |
| Mommy_Reflection | 1 + 0.05·A | 1 | 1e6 |  |
| Soup_RuneSpeed1 | 1 + 0.00075·A | 1 | 2 |  |
| Soup_RuneSpeed2 | 1 + 0.00015·A | 1 | 3 |  |
| Soup_Shine | 1 + 0.05·A | 1 | 1e6 |  |

### Galactic

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| CosmicDust_RuneSpeed | 1 + 0.0001·A | 1 | 15 |  |
| CosmicDust_Tickets | 1 + 0.000025·A | 1 | 25 |  |
| Star_RuneSpeed | 1.000065^A | 1 | 1500 |  |
| Star_Tickets | 1.0001^A | 1 | 1e6 |  |
| Constellation_RuneBulk1 | 1 + 0.001·A | 1 | 25 |  |
| Constellation_RuneBulk2 | 1 + 0.00025·A | 1 | 25 |  |
| Planet_RuneBulk1 | 7.5e4·A | 1 | 2.5e13 | Base 0 but clamp min 1 |
| Planet_RuneBulk2 | 1 + 0.000002·A | 1 | 1.035 |  |
| Rocket_RuneSpeed | 1.000002^A | 1 | 75000 |  |
| Rocket_Tickets | 1 + 0.5·A | 1 | 1e21 |  |
| Galaxy_Light | 1 + 0.01·A | 1 | 1e6 |  |
| Galaxy_Chroma | 1.02^A | 1 | 1000 |  |
| Axium_Chroma | 1 + 0.025·A | 1 | 1e6 |  |
| Axium_Light | 1 + 0.005·A | 1 | 1e6 |  |
| Axium_Reflection | 1 + 0.001·A | 1 | 1e6 |  |
| Axium_RuneSpeed | 1 + 0.00005·A | 1 | 2 |  |
| Paracosm_RuneSpeed | 1 + 0.00002·A | 1 | 3 |  |
| Paracosm_Light | 1 + 0.1·A | 1 | 1e9 |  |

### Nature

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Wavecaller_Spheres | 1 + 1·A (returns 1 if A≤0) | 1 | 1e300 | Comment says "Unknown Rune"; separate from `Wavecaller` (no suffix) |
| Oak_Energy | 2·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Oak_Power | 1 + 0.5·A | 1 | 1e300 |  |
| Moss_Flame | 1.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Moss_Damage | 1 + 0.025·A | 1 | 1e300 |  |
| Dew_Energy | 1 + 3·A | 1 | 1e300 |  |
| Dew_Orbs | 1 + 0.35·A | 1 | 1e300 |  |
| Dew_RealmPoints | 1 + 0.005·A | 1 | 1e300 |  |
| Skylight_Flame | 2.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Skylight_Power | 1·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Skylight_Prisms | 1 + 0.0003·A | 1 | 4 |  |
| Nightshade_Orbs | 1 + 0.1·A (returns 1 if A≤0) | 1 | 1e300 |  |
| Nightshade_RealmPoints | 1 + 0.025·A | 1 | 1e300 |  |
| Nightshade_Spheres | 1 + 0.05·A | 1 | 1e300 |  |
| Nightshade_Flesh | 1 + 0.1·A | 1 | 1e300 |  |
| Wavecaller_Power | 2·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Wavecaller_Flesh | 1 + 0.5·A (returns 1 if A≤0) | 1 | 1e300 |  |
| Wavecaller | 1 + 0.75·A | 1 | 1e300 | Function has no stat suffix; comment says Spheres |
| Thunderstorm_Energy | 5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thunderstorm_Flame | 5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thunderstorm_Power | 5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thunderstorm_Damage | 2.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thunderstorm_Flesh | 3.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thunderstorm_Orbs | 7.5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Earthvein_Energy | 25·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Earthvein_Orbs | 5·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Earthvein_RealmPoints | 3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Earthvein_RuneSpeed | 1 + 0.025·A | 1 | 1.15 |  |
| Emberglow_Flame | 1e3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Emberglow_Flesh | 500·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Emberglow_Orbs | 2.5e3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Emberglow_RuneBulk | 1·A | 0 | 5 |  |
| Dreamscape_Energy | 5e4·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Dreamscape_Damage | 1e3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Dreamscape_Spheres | 1e4·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Thorn_RuneSpeed | 1 + 0.05·A | 1 | 2.5e4 |  |
| Thorn_Tickets | 1 + 1.5·A | 1 | 1e10 |  |
| Squid_RuneBulk | 1.0015^A | 1 | 200 |  |
| Squid_Tickets | 1 + 0.0075·A | 1 | 1e12 |  |
| Cyclone_RuneSpeed | 1 + 0.001·A | 1 | 1000 |  |
| Cyclone_RuneBulk | 1 + 0.00000075·A | 1 | 1.2 |  |
| Bolt_RuneBulk1 | 1 + 0.0025·A | 1 | 100 |  |
| Bolt_RuneBulk2 | 1 + 0.0000005·A | 1 | 250 |  |
| Riptide_RuneSpeed1 | 1 + 0.01·A | 1 | 2 |  |
| Riptide_RuneSpeed2 | 1 + 0.00075·A | 1 | 500 |  |
| Riptide_Tickets | 1.0001^A | 1 | 1e34 |  |
| Torrent_RuneSpeed | 1.000005^A | 1 | 10000 |  |
| Hurricane_Tickets | 1 + 0.033·A | 1 | 1e300 |  |
| Hurricane_Light | 1 + 0.05·A | 1 | 1e6 |  |

### Polychrome

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Glow_Energy | 1 + 5·A | 1 | 1e300 |  |
| Glow_RealmPoints | 1 + 0.1·A | 1 | 1e300 |  |
| Shimmer_Orbs | 1 + 0.1·A | 1 | 1e300 |  |
| Shimmer_Spheres | 1 + 0.25·A | 1 | 1e300 |  |
| Shimmer_Prisms | 1 + 0.0002·A | 1 | 1e300 |  |
| Iridium_RealmPoints | 1 + 0.1·A | 1 | 1e300 |  |
| Iridium_Orbs | 1 + 0.25·A | 1 | 1e300 |  |
| Iridium_Flesh | 1.3·A (returns 1 if A≤0) | 1 | 1e300 | no +1 base |
| Iridium_RuneLuck | 1 + 0.0025·A | 1 | 1.5 |  |
| Spectrum_Prisms | 1 + 0.15·A | 1 | 1e300 |  |
| Spectrum_Flesh | 1 + 0.25·A | 1 | 1e300 |  |
| Prismatic_Walkspeed | 1 + 3·A | 1 | 15 |  |
| Prismatic_Tickets | 1 + 0.05·A | 1 | 2 |  |
| Prismatic_RealmPoints | 1 + 250·A | 1 | 1e300 |  |
| Prismatic_RuneBulk | 1·A | 0 | 10 |  |
| Refraction_Prisms | 1 + 10·A | 1 | 1e300 |  |
| Refraction_RuneSpeed | 1 + 0.1·A | 1 | 2 |  |
| Refraction_RobuxTokenCD | 5·A | 0 | 60 |  |
| Refraction_ChestChance | 250·A (returns 0 if A<1) | 0 | 3000 |  |
| Aether_RuneLuck | 1 + 0.001·A | 1 | 10 |  |
| Vexed_Tickets | 1 + 0.05·A | 1 | 3 |  |
| Abyssium_Tickets | 1 + 1.1·A | 1 | 10000 |  |
| Abyssium_RuneBulk | 1 + 0.01·A | 1 | 100 |  |
| Oscillon_RuneBulk | 1 + 0.005·A | 1 | 1.3 |  |
| Oscillon_RuneLuck | 1 + 0.02·A | 1 | 1000000 |  |
| Oblivion_RuneBulk | 1 + 0.025·A | 1 | 50000 |  |
| Zephyr_RuneSpeed | 1 + 0.01·A | 1 | 3 |  |
| Zephyr_RuneBulk | 1.000000000000001^((A/15)^(A/37.5))  (Lua `^` is right-assoc) | 1 | 1e6 | Base 1.000000000000001 ≈ 1+1.11e-15 in double; grows only once (A/15)^(A/37.5) is astronomically large |
| Raze_RuneSpeed | 1 + 0.001·A | 1 | 15 |  |
| Raze_RuneBulk | 1 + 0.00003·A | 1 | 450 |  |
| Raze_Chrome | 1 + 0.0000025·A | 1 | 1000 |  |

### Royal

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Gilded_Energy | 1 + 0.5·A | 1 | 1e300 |  |
| Gilded_Droplets | 1 + 0.1·A | 1 | 1e300 |  |
| Gilded_Tickets | 1 + 0.0005·A | 1 | 1.25 |  |
| Royalty_Flame | 1 + 2·A | 1 | 1e300 |  |
| Royalty_RuneLuck | 1 + 0.01·A | 1 | 1.25 |  |
| Crown_Energy | 1 + 1·A | 1 | 1e300 |  |
| Crown_Prisms | 1 + 0.025·A | 1 | 1e300 |  |
| Crown_RuneBulk | 1·A | 1 | 2 | Base 0 but clamp min 1 → 0 owned returns 1 |
| Throne_Tickets | 1 + 0.05·A | 1 | 1.5 |  |
| Throne_ArcticPoints | 1 + 0.01·A | 1 | 3 |  |
| Monarch_Droplets | 1 + 0.33·A | 1 | 1e300 |  |
| Monarch_Energy | 2^A | 1 | 1e300 |  |
| Monarch_Tickets | 1 + 0.1·A | 1 | 1.75 |  |
| Imperial_Tickets | 1 + 0.05·A | 1 | 1e21 |  |
| Imperial_Chromium | 1 + 0.1·A | 1 | 1e300 |  |
| Imperial_Orbs | 1 + 1.1^A | 1 | 1e300 | Additive: 1 + 1.1^A → 2 at A=0 |
| Sovereign_TicketChance | 250·A | 0 | 5000 |  |
| Sovereign_RuneBulk | 1·A | 1 | 5000 | Base 0 but clamp min 1 |
| Kingslayer_RuneLuck | 1 + 0.25·A | 1 | 100 |  |
| Kingslayer_RuneSpeed | 1 + 0.25·A | 1 | 100 |  |
| Kingslayer_Orbs | 1 + 25000^A | 1 | 1e300 | Additive: 1 + 25000^A → 2 at A=0 |
| Divinity_RuneBulk | 2·A | 1 | 100000 | Base 0 but clamp min 1 |
| Divinity_RuneLuck | 1 + 0.001·A | 1 | 10 |  |
| Prosperity_RuneSpeed | 1 + 0.01·A | 1 | 100000 |  |
| Prosperity_ChestChance | 1·A (returns 0 if A<1) | 0 | 6000 |  |
| Immortality_RuneBulk | 1 + 1.0005^A | 1 | 1e9 | Additive: 1 + 1.0005^A → 2 at A=0 |
| Odyssey_RuneBulk1 | 1.000001^A | 1 | 10000 |  |
| Odyssey_RuneBulk2 | 1 + 0.000065·A | 1 | 50 |  |
| Odyssey_RuneSpeed | 1 + 0.0015·A | 1 | 50 |  |
| Destiny_RuneBulk | 1 + 0.00005·A | 1 | 10000 |  |
| Destiny_RuneSpeed | 1 + 0.0015·A | 1 | 250 |  |
| Triarch_RuneSpeed1 | 1 + 0.001·A | 1 | 75 |  |
| Triarch_RuneSpeed2 | 1 + 0.00005·A | 1 | 500 |  |
| Triarch_RuneSpeed3 | 1 + 0.00000075·A | 1 | 50000 |  |
| Liberty_RuneSpeed | 1 + 0.005·A | 1 | 10 |  |
| Liberty_RuneBulk | 1 + 0.0025·A | 1 | 100 |  |
| Liberty_Hail | 1 + 0.00001·A | 1 | 1.25 |  |

### Global

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Lightmatter_Energy | 1 + 0.1·A | 1 | 20 |  |
| Lightmatter_Flame | 1 + 0.1·A | 1 | 20 |  |
| Lightmatter_Power | 1 + 0.1·A | 1 | 20 |  |
| Lightmatter_RealmPoints | 1 + 0.1·A | 1 | 20 |  |
| Lightmatter_Flesh | 1 + 0.1·A | 1 | 20 |  |
| Antimatter_RuneBulk | 1 + 0.05·A | 0 | 15 | Base 1, clamp min 0 (min never hit) |
| Antimatter_RuneLuck | 1 + 0.1·A | 1 | 3 |  |
| Antimatter_TicketChance | 500·A | 0 | 2500 |  |
| Darkmatter_Energy | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Flame | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Power | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_RealmPoints | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Flesh | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Prisms | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Orbs | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Spheres | 1 + 0.25·A | 1 | 12.5 |  |
| Darkmatter_Tickets | 1 + 0.05·A | 1 | 2 |  |
| Etherborn_RuneSpeed | 1 + 1·A | 1 | 25 |  |
| Etherborn_RobuxTokenCD | 30·A | 0 | 60 |  |

### Ancient

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Dust_Energy | 1 + 0.01·A | 1 | 5 |  |
| Dust_Prisms | 1 + 0.001·A | 1 | 3 |  |
| Bone_Orbs | 1 + 0.01·A | 1 | 3 |  |
| Bone_RuneBulk | 1 + 0.0001·A | 1 | 1.1 |  |
| Glyph_Droplets | 1 + 0.1·A | 1 | 7.5 |  |
| Glyph_ArcticPoints | 1 + 0.25·A | 1 | 5 |  |
| Glyph_RuneSpeed | 1 + 0.00075·A | 1 | 1.33 |  |
| Sigil_RuneBulk | 1 + 0.015·A | 1 | 2.5 |  |
| Sigil_RuneLuck | 1 + 0.05·A | 1 | 5 |  |
| Ankh_RuneSpeed | 1 + 0.25·A | 1 | 10 |  |
| Ankh_ChestChance | 50·A (returns 0 if A<1) | 0 | 250 |  |
| Ankh_TicketChance | 150·A | 0 | 1500 |  |
| Omen_RuneSpeed | 1 + 0.5·A | 1 | 10 |  |
| Omen_RuneBulk | 1 + 0.25·A | 1 | 2 |  |

### Madness

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Mad_Orbs | 1 + 0.00025·A | 1 | 4 |  |
| Mad_Spheres | 1 + 0.0001·A | 1 | 3 |  |
| Rage_Chroma | 1 + 0.005·A | 1 | 1.5 |  |
| Rage_RuneSpeed | 1 + 0.0025·A | 1 | 1.25 |  |
| Rage_Tickets | 1 + 0.05·A | 1 | 10 |  |
| Violence_Chroma | 1 + 0.2·A | 1 | 7.5 |  |
| Violence_Light | 1 + 0.075·A | 1 | 4 |  |
| Violence_Reflection | 1 + 0.025·A | 1 | 2.5 |  |
| Vehemence_AllSecret | 1 + 0.25·A | 1 | 5 |  |
| Vehemence_RuneBulk | 1 + 0.075·A | 1 | 3 |  |
| Malevolence_RuneSpeed | 1 + 0.75·A | 1 | 4 |  |
| Malevolence_AllSecret | 1 + 0.5·A | 1 | 5 |  |
| Malevolence_RobuxTokenCD | 15·A | 0 | 45 |  |

### Ultra

| Function | Formula | Min | Max | Note |
|---|---|---|---|---|
| Omniscient_Spheres | 1 + 0.025·A | 1 | 5 |  |
| Omniscient_Droplets | 1 + 0.025·A | 1 | 5 |  |
| Omniscient_Water | 1 + 0.025·A | 1 | 5 |  |
| Omnipotent_Water | 1 + 0.1·A | 1 | 3 |  |
| Omnipotent_Ice | 1 + 0.1·A | 1 | 3 |  |
| Omnipotent_ArcticPoints | 1 + 0.1·A | 1 | 3 |  |
| Almighty_Droplets | 1 + 0.1·A | 1 | 4 |  |
| Almighty_Water | 1 + 0.1·A | 1 | 4 |  |
| Almighty_ArcticPoints | 1 + 0.1·A | 1 | 4 |  |
| Almighty_Ice | 1 + 0.1·A | 1 | 4 |  |
| Almighty_Icicles | 1 + 0.1·A | 1 | 4 |  |
| Almighty_RuneSpeed | 1 + 0.0075·A | 1 | 2 |  |
| Almighty_Chromium | 1 + 0.1·A | 1 | 2 |  |
| Boundless_RuneBulk | 1 + 0.1·A | 1 | 2 |  |
| Boundless_Tickets | 1 + 0.25·A | 1 | 3 |  |
| Boundless_RuneSpeed | 1 + 0.075·A | 1 | 15 |  |
| Primordial_RuneBulk | 1 + 0.3·A | 1 | 10000 |  |
| Primordial_ChestChance | 100·A (returns 0 if A<1) | 0 | 500 |  |
| Eternal_RuneSpeed | 1 + 0.4·A | 1 | 4 |  |
| Eternal_RuneBulk | 1 + 0.4·A | 1 | 6 |  |
| Eternal_AllSecret | 1 + 0.15·A | 1 | 2 |  |

## 3. Other issues noticed

- Duplicate function names: none.
- Runes with no formula: .
- Rune Clone: owning both product and Prisms_RuneClone but failing the chance check gives ×1 (neither branch fires).
- `GetRuneTable` break entry omits RuneLuck/RuneClone fields → that rune is never cloned.
- Global/Ancient/Madness/Ultra thresholds used non-cumulatively, so listed odds ≠ real odds (e.g. Lightmatter effectively 0.95−0.048).
---

# Systems Reference (non-Formulas modules)

Source: extracted Luau in `scratchpad/out/`. `EN` = EternityNum. `tick` = wall-clock seconds. All numbers exact from source.

---

## 1. Upgrade engine (`Libraries.Upgrades`)

Each upgrade module sets fields; the engine reads only these:
`Levels, Currency, Base_Price, Price_Scale, Price_Jump{every,mult}, Price_Jump2{every,mult}, MultiBuy[], Cap_Upgrades, Cap_Tier, Base_Effect, Effect_Scale, Reverse, Exponential, Log, Effect_Bonus, Bonus_Needed, HasRequirement, CustomEffect, Stay_Visible`, plus optional named sub-tables (e.g. `Droplets = {Base_Effect...}`) selected by `GetEffect(..., typeEffect)`.

**`Additive_Scale` is NOT read anywhere in the engine** (it appears in data modules with a comment "Base * x * Level" but is dead config — cost is always exponential).

### Level cap
```
MaxLevels = Levels
          + 100 * Upgrades.Prisms_Caps          (if "Prisms_Caps" in Cap_Upgrades)
          + 100 * max(Tier - 6, 0)              (if Cap_Tier)
```
(Without a Player arg, returns raw `Levels`.) Level is clamped to [0, MaxLevels] before cost/effect.

### Cost (level L = current level, cost of buying the next one)
```
Cost(L) = Base_Price * Price_Scale^L
        * Price_Jump[2]  ^ floor(L / Price_Jump[1])        (if Price_Jump)
        * (Price_Jump2[2] or 1) ^ floor(L / Price_Jump2[1]) (if Price_Jump2)
```
MultiBuy: same formula per sub-table; `GetCost` returns `{[Currency] = {cost, isRune}}` and buying requires affording every sub-cost (runes taken from `Player.Runes`, else `Player.Stats`).

CanAfford: `HasRequirement(Player)` (if present) and `L < MaxLevels` and `currency >= Cost(L)`.

### Buy
- Single: subtract Cost(L) (number stats via `toNumber`, string stats via EN), run `CustomEffect(Player)`, `L += 1`.
- Buy max: `ReturnMax` loops from current L summing `Cost(L)` until `total + next > currency` (strict: stops when sum would EXCEED, `EN.me`) or level reaches MaxLevels; yields every 100 levels. Then `NewLevel = clamp(levels, 0, MaxLevels)`, subtract total, run CustomEffect.
  - Special: if `Price_Scale == 0` returns `floor(currency / Base_Price)` (a number, not the `{Levels,Cost}` table — caller would then index `.Levels` on a number → bug).
  - Buy-max ignores MultiBuy (uses `self.Currency` only).

### Effect (level L after clamp)
```
if L <= 0: return Base_Effect
E = Effect_Scale * L
if Reverse:           return Base_Effect - E              (early return; no bonus)
if Exponential:       E = Exponential ^ L
if Effect_Scale <= 1 and not Exponential:  E = Base_Effect + E
   (NOTE: if Effect_Scale > 1 and not Exponential, Base_Effect is NOT added → E = Effect_Scale*L)
if Log:               E = log_Log(E * Log)   = 1 + log_Log(E)
if Effect_Bonus > 1:  E = E * Effect_Bonus ^ floor(L / Bonus_Needed)
return toNumber(E) if E is EN and <= 1e303, else E (EN)
```
Quirks: Exponential ignores Base_Effect and Effect_Scale entirely; Reverse skips Effect_Bonus.

---

## 2. Prestige / resets (`Shared.Modules.Resets` + triggers in `Libraries.Automations`)

All layer buttons are "stand-on" pads, polled every 1/30 s (raycast 15 studs down), gated by cooldowns (section 3).

### Preserved-talent list ("KEEP16")
Talent resets always restore: `Prisms_RuneBulk2, Chromium_RuneStarring, Prisms_Chromatizer, Prisms_RuneClone, Prisms_RuneBulk3, Prisms_RuneSpeed2, Chromium_UltraRunes, Prisms_RuneBulk4, Prisms_RTokens, Prisms_RuneSpeed3, Prisms_RPS, Prisms_RPS2, Prisms_Tickets2, Chromium_Chromifier, Chromium_Hail1, Chromium_RPS5`. "KEEP19" = KEEP16 + `Chromium_RPS9, Chromium_Shine1, Chromium_Shine2`.

### Tier (Tier N → N+1, gain +1 Tier)
- Requirement: Tier < 10: `Energy > Tier_Cost(Tier)`; Tier ≥ 10: `Droplets > Tier_Cost(Tier)` (blocked when `EN.le(currency, cost)` i.e. currency < cost, so needs `>=`; same for Flame/Power/Reflection/Chromatize/Chromify gates). Currency is **not** deducted.
- Updates `Highest_Tier`.
- Resets: Spheres="0", Sphere_Levels=0, all `Spheres` upgrades; Merger reset, Cube_Level=1, Orbs_SpawnLevel=0, Orbs_SpawnTime=0; Accelerator=0; Orbs="0", Orbs_Energy/Flame/Orbs=0; Gears=0; Mobs_Level=1, Mobs_SetLevel=1, Flesh="0", Mobs_Killed=0, mob respawn, all `Flesh` upgrades; Power="0" + all `Power` upgrades; Flame="0"; Energy="0".
- Additionally if **Tier > 10 (checked after increment)**: Droplets, Water, Ice, Chromium, Icicles = 0; Freeze1–9 = `false`; Droplets_Droplets1/Water1/Spheres1/Chromium1/AP1 = 0.
  - Bug: Freeze upgrades are numeric levels elsewhere (`Freeze2.Value >= 1`) but set to `false` here.

Tier cost table (`Formulas.Tier_Cost`, shown for completeness):

| Tier → next | Cost | Currency |
|---|---|---|
| 0 | 100 | Energy |
| 1 | 1e6 | Energy |
| 2 | 5e9 | Energy |
| 3 | 2.5e15 | Energy |
| 4 | 7.5e23 | Energy |
| 5 | 1e40 | Energy |
| 6 | 1e65 | Energy |
| 7 | 1e153 | Energy |
| 8 | 1e276 | Energy |
| 9 | 1e978 | Energy |
| 10 | 5e60 → **1e52 (changed)** | Droplets |
| 11 | 7.5e113 | Droplets |
| 12 | 1e195 | Droplets |
| 13 | 9e(10^125-ish) — effectively a hard cap | Droplets |
| other | `(100 * Scale^T)^Super`, Scale=100 (+50 if T≥2), Super=1 (+0.15 if T≥3, +0.25 if T≥4) | — |

Client display caps tier at 13 (`maxTier = 13`); XP unlocked at Tier 4.

Tier-gated unlocks (from Automations): Flame pad T≥1, Realm Points pad T≥1, Power pad T≥2, XP gen / mobs / auto-attack / Loot T≥4, Prisms gen T≥5 (x2 pad T≥6; Talent tree prism button T≥6), Orbs T≥7, Merger/Cubes T≥8, Spheres T≥9, Hail T≥10, playtime streak T≥11, Freeze1 T≥11, TierTwelveTime / Global Goal rewards T≥12, Haze/Icicles T≥13.

### Challenges C1–C4 (`Resets.C1..C4` — all four identical)
Tier reset, then: all `Talent` upgrades=0 except KEEP16; Realm Points="0" + all `Realm Points` upgrades=0; Prisms="0"; Tier=0.
Completion (checked every 1/60 s while `CurrentChallenge` set), reward = `Stats.Cn = true`:
- C1: Tier ≥ 6 · C2: Tier ≥ 8 · C3: Energy ≥ 1e393 · C4: Energy ≥ 1e96.
(Challenge restrictions themselves live in Formulas, not here.)

### Ascension One (server `Scripts.Ascensions`)
- Requirement: `Energy > 1e2283` (blocked if `<=`), one-time (`AscensionOne` flag). Gain: `AscensionOne = true` (enables Droplets gen, leaderstat Ascension=1).
- Resets: Tier reset; Talent upgrades except KEEP16; Realm Points + RP upgrades; every rune whose `RuneInfo` chance ≥ 1e-8 set to 0; Prisms="0", Tier=0, XP="0", Level=0, Highest_Tier=0; C1–C4=false.

### Freeze (Freeze1–9 upgrades, `CustomEffect = Resets.Freeze`)
Each Freeze is a 1-level upgrade bought with Droplets:

| Freeze | Price (Droplets) | Requires |
|---|---|---|
| 1 | 1e19 | Tier ≥ 11 |
| 2 | 2.5e34 | Freeze1, Tier ≥ 11 |
| 3 | 5e51 | Freeze2, Tier ≥ 11 |
| 4 | 2.5e109 | Freeze3, Tier ≥ 12 |
| 5 | 7.5e136 | Freeze4, Tier ≥ 12 |
| 6 | 2.5e185 | Freeze5, Tier ≥ 12 |
| 7 | 1e234 | Freeze6, Tier ≥ 13 |
| 8 | 5e278 | Freeze7, Tier ≥ 13 |
| 9 | `2,5e313` (**typo: parses as Base_Price = 2**) | Freeze8, Tier ≥ 13 |

Freeze1 module example effects (sub-tables): Droplets `{Base 1, Scale 10}`, Water `{Base 1, Scale 3}` → at L=1: 10 and 3 (Scale>1 path, base not added).
`Resets.Freeze` resets: everything Tier reset does (except Tier>10 branch) plus Prisms=0, Droplets/Ice/Water="0", all `Droplets` upgrades, Talent upgrades except KEEP16, Chromium="0". Does not touch Tier.

Separate server module `ServerStorage.Modules.Freeze` (Freeze tier via `Tier_Freeze`, pays with Droplets as **number**) — data:

| Lvl | Needed Droplets | Gives (sets multiplier stat to value, not multiplies) |
|---|---|---|
| 1 | 1e8 | Droplets_Mult=10, Water_Mult=3, talents Prisms_Droplets2, Prisms_AP1 |
| 2 | 1e12 | IceUnlocked, Water_Mult=20, AP_Mult=2 |
| 3 | 1e21 | Water_Mult=5, Ice_Mult=3, +1 Cryo rune, talent Prisms_Spheres5 |
| 4 | 1e36 | Droplets_Mult=100, AP_Mult=4 |
| 5 | 1e45 | Chromium_Mult=3, Ice_Mult=15, Prisms_Mult=50, talents Chromium_Prisms3/Ice2/AP4 |
| 6 | 1e63 | Spheres_Mult=7, talents Chromium_SpheresEnhance, Chromium_Prisms4 |
| 7 | 1e93 | Icicles_Mult=3 |
| 8 | 1e360 ("NOT DONE") | Prisms_Mult, Chromium_Mult read nonexistent keys → nil |
| 9 | 1e360 ("NOT DONE") | talents loop over nil Talents → error |

Bugs: tier check compares **strings** (`tostring(tier) >= tostring(Lvl)`, lexicographic); `BypassTier11 = true` disables the Tier 11 gate; boosts are applied even if the purchase failed (the `if` only guards the payment); droplets converted via `toNumber` (overflows past 1e308); Freeze3 Water_Mult=5 overwrites Freeze2's 20.

### Chromatize (+1 Chromatize)
- Requires `Prisms_Chromatizer ≥ 1`, `Prisms > Chromatize_Cost(Chromatize)` (not deducted), 1 s cooldown.
- Cost table: 1:1e43, 2:1e50, 3:1e55, 4:1e60, 5:1e65, 6:1e70, 7:1e85, 8:1e95, 9:1e105, 10:5e178, 1001: ~1e(3.3e144) cap; others `(1e40 * Scale^C)^Super` with Scale=100(+50 if C≥2), Super=1(+0.15 C≥3, +0.25 C≥4). Note C=0 is not in table → formula gives 1e40. Client shows cap "/1M".
- Resets: Talent upgrades except KEEP16; then `Prisms_Chromatizer = 1`; Prisms, Chromium, Chroma = "0".
- Chromatize ≥ 1 unlocks Chromium generation and RP auto-buy; ≥ 850 raises Robux token tick to 2.625; ≥ 1000 (plus Vanguard rune) unlocks Chroma pad.

### Chromify (+1 Chromify)
- Requires `Chromium_Chromifier ≥ 1`, `Chroma > Chromify_Cost(Chromify)`, 1 s cooldown.
- Costs: 0:1e23, 1:7.5e36, 2:1e78, 3: 1e(1e110) (cap, client shows "/3"); formula fallback base 1e24, Scale 10000(+50), same Super.
- Resets: Talents except KEEP19; `Prisms_Chromatizer=1`; Prisms, Chromium, Chroma, Light, Reflection, Shine="0"; Light_Light/Chrome1/Chrome2, Reflection_Chrome1/Light1/RPS1 = 0.
- Unlocks: Chromify ≥1 Light pad, ≥2 Ascended pad, ≥3 Reflection pad.

### Reflection (gain `Formulas.Reflection(Player,1)`)
- Requires Chromify ≥ 3 and `Light > Reflection_Cost`. Adds Reflection.
- Resets: Talents except KEEP19; `Prisms_Chromatizer=1`; Chromium, Chroma, Light="0"; Light_Light/Chrome1/Chrome2=0.

### Icicles (pad; `Resets.Icicles` is an empty stub)
- Requires Tier ≥ 13, `Ice > 1e17`, cooldown `Icicles` (5 s base).
- `base = (log10(Ice / 1e17))^5`; gain = `Formulas.Icicles(Player, base)`. Sets Droplets, Water, Ice = "0".
- Client board (display only, marked "TODO"): with I = Icicles, next = I+2 (bug: `add(I, 1+1)`): Droplets ×I², Ice ×I^0.2 (needs Chromium_Icicles4), Prisms ×I^0.5 (Chromium_Icicles3), Water ×I (Chromium_Icicles2).

### Power / Flame (non-reset layers, for completeness)
- Flame: Tier ≥1, `Energy > Flame_Cost`; +Flame(Player,1), deducts Flame_Cost from Energy.
- Power: Tier ≥2, `Flame > Power_Cost`; +Power(Player,1), sets Flame and Energy to "0".

### Realm teleport
R2 costs 5e31 Prisms (one-time purchase, `R2_Purchased`).

---

## 3. Cooldowns (`Shared.Modules.Cooldowns`, seconds; `clamp(min,max)`)
`GS = Formulas.Gears_Speed(Gears)`, `MAS` = gamepass MoreAttackSpeed.

| Key | Formula | Clamp |
|---|---|---|
| Energy, XP, Spheres, Ice, Water | 0.25 − GS − (MAS?0.04) | [0,1] |
| Icicles | 5 − GS − (MAS?0.04) | [0,5] |
| Ascender_XP | 0.25 − GS | [0.05,1] |
| Flame, Power, Reflection | 0.25 | [0.05,1] |
| RealmPoints | 1, ÷3 if Spheres ≥ 2.5e14 | [0.05,1] |
| Tier, Chromatizer, Chromifier | 1 | [0.25,1] |
| Mobs (manual hit) | 3, ÷1.5 if MAS | [0.25,3] |
| IceButton, WaterButton | 0.5 | [0.05,1] |
| Runes | Formulas.Rune_Speed(Player) | [1/60,1] |
| Prisms | (15 + eff(Prisms_Prisms3)) / Accelerator_PrismSpeed; ÷2 if Prisms_X2 | [1/60,15] |
| Orbs | 1 | [1/60,1] |
| Cubes | (20 − eff(Orbs_SpawnTime)) / Accelerator_CubeSpeed; ÷2 if Cube_Level ≥ 20 | [2,20] |
| Droplets | 0.5 − Icequake_DropletsCD(rune) | [0,1] |
| ArcticPoints | 1 + eff(Chromium_AP2) | [0.05,2] |
| WaterAuto | 3 + eff(Chromium_Automation3) | [0,1] (**max 1 < base 3 → always ≤1**) |
| Chromium | 10 + eff(Chromium_Chromium2) + eff(Chromium_Chromium3) | [0,10] |
| AutoPower | 1 − eff(Prisms_AutoPower3) | [0.05,1] |
| AutoAttack | 3 − eff(Prisms_AutoAttackSpeed) | [0.05,3] |
| RobuxTokens | 360 − 30(Premium) − 60(Prime) − Refraction/Mystery/Etherborn/Malevolence rune CDs − eff(Prisms_RTokens) | [30,360] |
| Cryo | 1 | [0.5,3] |

Notes: "+ eff" entries rely on Reverse/negative effects to reduce. Energy/Spheres etc. can clamp to 0 → fires every Heartbeat (1/60 loop). `Orbs_SpawnTime`/`Chromium_AP2` effect called without Player (cap bonuses ignored).
Cooldown mechanism: first check always passes; afterwards passes when `tick() − start ≥ threshold`, then restarts.

---

## 4. Automation loop (`Libraries.Automations`)
Heartbeat accumulates per-group timers; groups skipped while Tiering/Challenging/Ascending/ShuttingDown/Resetting attribute set.

| Group period | Content |
|---|---|
| 1/60 | Stat gens (require Settings.Automation): Energy (+Energy(P,1), also Total_Energy); Flame if Prisms_AutoFlame>0; Power if Prisms_AutoPower>0: gain = Power(P,1)×AutoPower(P); Realm Points if Refraction rune>0; Level-up +1 when XP ≥ Level_Req(Level) (XP not deducted); XP (Tier≥4): +XP(P,0.25); auto-attack mob (Tier≥4, Prisms_AutoAttack>0); Orbs (Tier≥7); Cube_Level = max(Cube_Level, 1+Orbs_SpawnLevel); Merger spawn+merge at Cube_Level(P) (Tier≥8, no Automation setting needed); Spheres (Tier≥9); Droplets (AscensionOne); Chromium (Chromatize≥1); Water +1% of Water per WaterAuto tick (Chromium_Automation2≥1) |
| 1/2 | If `Realm ~= "One"`: Droplets = (Droplets + Droplets(P,0.5)) × Droplets_Multiplier (×2 with gamepass 78793985260781). **Bug: multiplies the whole balance every 0.5 s → exponential growth.** Also calls UserOwnsGamePassAsync every 0.5 s. |
| 1/30 | Auto-buy (single level each): Orbs_* 8 upgrades if Prisms_OrbsAutoBuy>0; Power_* 8 upgrades if Freeze2≥1; RP_* 14 upgrades if Chromatize≥1 |
| 1/8 | Like rewards: goal = 35 + LikeReward × S, S=35 (LikeReward≤5), 75 (>5), 250 (>10); on reach +1 LikeReward, 1 random elixir |
| 1/30 | leaderstats sync |
| 1/60 | Challenge completion checks |
| 1/30 | Layer pads (section 2) incl. timed pads |
| 1/60 | Rune pads (Runes CD): bulk = clamp(Rune_Afford(stat,cost), 0, Rune_Bulk(P,true,name)); ticket roll per open (Ticket_Chance → +Tickets(P)); **`Rune:GetResult` called twice — first result discarded (double RNG / wasted work)**; stats Runes_Opened += Bulk, RawRunes_Opened += 1. Manual mob hit (Tier≥4, Mobs CD). |
| 1/60 | Prisms (Tier≥5): Prisms_X2 when standing on pad (Tier≥6) or Spheres ≥ 5e20; +Prisms(P) per Prisms CD |
| 1/60 | Stand-on talent/upgrade buy (single), multiplier buttons (per-type CD `<Name>Button`) |
| 1/8 | Save location |
| 1 | Premium flag; Starter pack timer −1 (0 at Tier≥4); elixir durations −1 each |
| 1/60 | Robux tokens: +1.75 per RobuxTokens CD (2.625 if Chromatize ≥ 850) |

Timed "claim" pads (gain on claim if `now − StartTime > TotalTime`):
Haze (Tier≥13, init start = now−24h), Hail (Tier≥10, now−24h), Loot (Tier≥4, now−10min), Light (Chromify≥1, now−10min), Ascended (Chromify≥2, now−2s; gives **Chroma** via Formulas.Chroma), Chroma (Chromatize≥1000 or Vanguard≥1e19 — gate is `Chromatize<1000 AND Vanguard<1e19` → return; init needs Chromatize≥1000 AND Vanguard≥1e18, now−10s), Shine (Chromium_NewStat≥1, now−30s).

Playtime (Tier≥11): `PlaytimeLuckIncrease = min(floor(streak/900), 100)`, `PlaytimeBulkIncrease = min(floor(streak/3600), 10)`.

---

## 5. Mobs (`Libraries.Mob`, `Mob.1`, `MobsHandler`)
- Level = clamp(Mobs_SetLevel, 1, Max), Max = clamp(Mobs_Level, 1, 1e6). Stage = Level.
- Chest chance: `1 / (10000 − Refraction_CC − Prosperity_CC − Primordial_CC(uses Prosperity count, bug) − Ankh_CC)`.
- HP (uniform random between min/max):
  - Level < 1000: min = 10·2^(L−1), max = 20·2^(L−1)
  - Level ≥ 1000: min = 1e303·4^(L−1000), max = 2e303·4^(L−1000)
  - Chest: ×3.
  (Discontinuity: L=999 → ~10·2^998 ≈ 2.7e301, L=1000 → 1e303.)
- Damage per hit: `Formulas.Damage(Player)`. Manual hit every Mobs CD (3 s, 2 s with MAS); auto-attack every AutoAttack CD.
- Respawn delay: `3 − eff(Prisms_SpawnSpeed)` (no clamp).
- Level-up: 15 kills at max level (`GetKillsNeeded` = 15 constant). Manual NextLevel pad, or auto if Prisms_AutoLevel>0. Kills only count when fighting at max level.
- Reward (mob type "Magma"): raw = uniform[1·1.5^(L−1), 3·1.5^(L−1)], flesh = Formulas.Flesh(P, raw).
- Chest reward roll r: r ≤ 0.001 → +rand(35..175) Robux tokens; ≤ 0.005 → 3 random elixirs; ≤ 0.139 → +rand(1..10) tokens; ≤ 0.25 → 1 elixir; else flesh ×100. Flesh is always granted (×100 only on the "else" branch).

---

## 6. Global Goals (`Libraries.GlobalGoals`, init is `noinit` — **never called, system disabled**)
- DataStore "Global_Goals_Release"; autosave+reload every 120 s, UpdateAsync adds server delta, 6 retries.
- Goal steps: Playtime 50,000 h (1.8e8 s), Runes 1e8, Robux 1e5. Each crossed multiple → all players with Tier ≥ 12 get `steps` of one random elixir stat (StatsElixir, StatsElixirDuration, RuneLuckElixir, RuneLuckElixirDuration, RuneSpeedElixir, RuneSpeedElixirDuration).
- Leaderboard rewards: RawRunes_Opened rank i (1..3): every 24 h → +(4 − i) ServerElixir. TierTwelveTime rank i: every `60·i` seconds (comment says day; code uses 60) → +1 GlobalElixir per period.
- Bugs: onPlayerJoin runes path uses GGPlaytimeRank instead of GGRunesRank; playtime path computes elapsed from GGRunesTimer; `RobuxSpent` lookup uses number userId vs string list; hours display `amount / 60*60` = amount (no division).

---

## 7. Multiplier buttons (`Libraries.MultiplierButtons`)
Button n (from name suffix): price = Base_Price·Price_Exp^(n−1); gain = Base_Effect·Effect_Exp^(n−1)·Formula(P).
- Water: pay Droplets, 25·7.5^(n−1); gain Water 1·3^(n−1)·Formulas.Water(P). No requirement. CD 0.5 s.
- Ice: pay Water, 1e8·250^(n−1); gain Ice 1·5^(n−1)·Formulas.Ice(P); **resets Droplets and Water to 0**; requires Freeze2 ≥ 1. CD 0.5 s.
- Water.GetHighestEffect: level = floor(log_7.5(Water)), returns pct·3^level.

Droplets board (display): Droplets ×(1 + 0.5·Water); Spheres ×(Droplets · eff(Droplets_Spheres1)); Water ×(1 + Ice); Spheres ×(1 + 0.1·Ice).

---

## 8. Chromatize/Chromify board helpers (client, display)
- spheresFormula: if Chromium_SpheresEnhance>0 and Chromium>0 → ×max(Spheres^0.75, 1).
- prismsFormula: (1 + 0.05·Chromium) × eff(Chromium_Prisms1) × eff(Chromium_Prisms2) × eff(Chromium_Prisms4).
- runeLuckFormula: if Chromium_RuneLuck1>0 → ×min(1 + 0.01·Chromium/1e21, 2).
(Commented out in Chromify module.)

---

## 9. Rune Starring (`ServerStorage.Modules.runeStarring`)
Per family, stage progresses Star1→Star2→Star3→Superstar→Completed; price paid in one rune; reward ops apply to Stats (`*` multiply, `+` add).

| Family | Pay rune | Prices (stage1..4) | Star1 | Star2 | Star3 | Superstar |
|---|---|---|---|---|---|---|
| Royal | Odyssey | 250, 2500, 5e5, 1e12 | Global_Rune_Bulk ×1.15 | ×1.5 | ×2 | ×10 |
| Color | Vibrance | 5e3, 1.5e4, 1e5, 1e6 | Color_Rune_Luck ×1.25 | ×1.75 | Global_Bulk +2, Global_Luck ×1.25, Color_Luck ×2 | Color_Luck ×3 and ×1.25, Global_Luck ×1.75, Global_Bulk +5 |
| Polychrome | Refraction | 10, 50, 150, 1e3 | Poly_Luck ×1.25 | ×1.75 | Poly_Luck ×2, Global_Luck ×1.25, Global_Bulk +2 | Poly_Luck ×3, Poly_Bulk ×1.25, Global_Luck ×1.75, Global_Bulk +5 |
| Arctic | Subzero | 5, 15, 50, 250 | Arctic_Luck ×1.25 | ×1.75 | Arctic_Luck ×2, Global_Luck ×1.25, Global_Bulk +2 | Arctic_Luck ×3, Arctic_Bulk ×1.25, Global_Luck ×1.75, Global_Bulk +5 |

On reaching Superstar (after stage 3): all runes of that family ×0.5; on Completed (stage 4): ×0. Debounce 0.5 s.
Stage parse takes the last char of the stage string ("Superstar" → non-number → 4; reward `Star4` nil → Superstar). Quirk: the Superstar reward is granted on the stage-4 purchase that also zeroes the family's runes; the state after stage 3 is labeled "Superstar" but grants Star3. Rune counts go through number `Value` (no EN).

---

## 10. Misc
- StatBoosts: just builds `{Upgrades=Stat_Mod.Upgrades, Fishes={}}` per Stat class; no math (Stat_Name leaks as global).
- Talent tree client: display only; price/afford via engine; tier ≥ 6 shows prism x2 button.
- Tier XP bar: progress = XP / Level_Req(Level), bar clamped 0.99; energy boost shown = Level_Energy(Level).
- TierBar progress: `log10(currency) / log10(req)` clamped [0,1]; bars for Energy, Droplets, Chroma all use Tier_Cost.

---

# Upgrade Configs (all 248 modules)

Plug these into the upgrade engine formulas in the section above. **Talent** upgrades mostly ignore the Effect fields — their real effect is in each module's custom `Update`/formula references (see Formulas section).

| Upgrade | Currency | Max Lv | Base price | Price scale | Price jumps | Effect | Requirement |
|---|---|---|---|---|---|---|---|
| **Arctic_Points** | | | | | | | |
| AP_AP1 | ArcticPoints | 400 | 75 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.Tier >= 11 |
| AP_Chromium1 | ArcticPoints | 4 | 1e6 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Upgrades.Chromium_AP3 >= 1 |
| AP_Droplets1 | ArcticPoints | 300 | 75 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Upgrades.Chromium_AP4 >= 1 |
| AP_Prisms1 | ArcticPoints | 60 | 25 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.Tier >= 4 |
| AP_Prisms2 | ArcticPoints | 60 | 75 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Upgrades.Chromium_AP5 >= 1 |
| AP_Spheres1 | ArcticPoints | 300 | 6 | 1.5 |  | base 1 + 0.75/lv, ×1.5 per 15 lv | Stats.Tier >= 4 |
| AP_Water1 | ArcticPoints | 300 | 75 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.Chromatize >= 10 |
| **Droplets** | | | | | | | |
| Droplets_AP1 | Droplets | 100 | 1e75 | 50 |  | base 1 + 0.5/lv | Upgrades.Freeze6 >= 1 |
| Droplets_Chromium1 | Droplets | 2 | 1e183 | 3 |  | exp 3 | Upgrades.Freeze9 >= 1 |
| Droplets_Droplets1 | Droplets | 100 | 1000 | 7.5 |  | exp 2 | true |
| Droplets_Spheres1 | Droplets | 100 | 1e15 | 25 |  | exp 1.25 | Upgrades.Prisms_Droplets2 >= 1 |
| Droplets_Water1 | Droplets | 100 | 1e16 | 10 |  | exp 1.5 | true |
| **Flesh** | | | | | | | |
| Flesh_DMG | Flesh | 750 | 1 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv |  |
| Flesh_Energy | Flesh | 1000 | 2 | 1.5 |  | base 1 + 1.25/lv, ×2 per 15 lv |  |
| Flesh_Flame | Flesh | 1000 | 5 | 1.5 |  | base 1 + 1.25/lv, ×2 per 15 lv |  |
| Flesh_Flame2 | Flesh | 1 | 1e399 | 2.22 |  | exp 1.45, ×2 per 15 lv |  |
| Flesh_Flesh | Flesh | 210 | 1e1284 | 1.5 |  | base 1 + 0.15/lv, ×2 per 15 lv |  |
| Flesh_Orbs | Flesh | 1000 | 5e26 | 1.5 |  | base 1 + 0.4/lv, ×2 per 15 lv | Stats.Tier >= 7 |
| Flesh_Orbs2 | Flesh | 1000 | 1e991 | 1.75 |  | base 1 + 0.3/lv, ×2 per 15 lv |  |
| Flesh_Power | Flesh | 1000 | 15 | 1.5 |  | base 1 + 0.9/lv, ×2 per 15 lv |  |
| Flesh_Power2 | Flesh | 540 | 1e1293 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv |  |
| Flesh_Prisms | Flesh | 1 | 1e1383 | 2.22 |  | exp 1.45, ×2 per 15 lv | EN.meeq(Stats.Spheres, "1e291") |
| Flesh_RP | Flesh | 1000 | 60 | 1.5 |  | base 1 + 0.2/lv, ×2 per 15 lv |  |
| Flesh_Spheres | Flesh | 500 | 1e120 | 1.5 |  | base 1 + 0.35/lv, ×2 per 15 lv | Stats.Tier >= 9 |
| Flesh_Spheres2 | Flesh | 1000 | 1e979 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv |  |
| **Freeze** | | | | | | | |
| Freeze1 | Droplets | 1 | 1e19 | 1.5 | 10, 1 24, 1 | Droplets: base 1 + 10/lv; Water: base 1 + 3/lv | Stats.Tier >= 11 |
| Freeze2 | Droplets | 1 | 2.5e34 | 1.5 | 10, 1 24, 1 | Water: base 1 + 20/lv; ArcticPoints: base 1 + 2/lv | Upgrades.Freeze1 >= 1 and Stats.Tier >= 11 |
| Freeze3 | Droplets | 1 | 5e51 | 1.5 | 10, 1 24, 1 | Ice: base 1 + 3/lv; Water: base 1 + 5/lv | Upgrades.Freeze2 >= 1 and Stats.Tier >= 11 |
| Freeze4 | Droplets | 1 | 2.5e109 | 1.5 | 10, 1 24, 1 | Droplets: base 1 + 100/lv; ArcticPoints: base 1 + 4/lv | Upgrades.Freeze3 >= 1 and Stats.Tier >= 12 |
| Freeze5 | Droplets | 1 | 7.5e136 | 1.5 | 10, 1 24, 1 | Ice: base 1 + 15/lv; Chromium: base 1 + 3/lv; Prisms: base 1 + 50/lv | Upgrades.Freeze4 >= 1 and Stats.Tier >= 12 |
| Freeze6 | Droplets | 1 | 2.5e185 | 1.5 | 10, 1 24, 1 | Spheres: base 1 + 7/lv | Upgrades.Freeze5 >= 1 and Stats.Tier >= 12 |
| Freeze7 | Droplets | 1 | 1e234 | 1.5 | 10, 1 24, 1 | Icicles: base 1 + 3/lv | Upgrades.Freeze6 >= 1 and Stats.Tier >= 13 |
| Freeze8 | Droplets | 1 | 5e278 | 1.5 | 10, 1 24, 1 | Chromium: base 1 + 5/lv; Prisms: base 1 + 3/lv | Upgrades.Freeze7 >= 1 and Stats.Tier >= 13 |
| Freeze9 | Droplets | 1 | 2 | 1.5 | 10, 1 24, 1 |  | Upgrades.Freeze8 >= 1 and Stats.Tier >= 13 |
| **Light** | | | | | | | |
| Light_Chrome1 | Light | 100 | 1000 | 1.5 |  | base 1 + 1000/lv, ×2 per 20 lv | Stats.Chromify >= 1 and Upgrades.Chromium_LightUpgrade1 > 0 |
| Light_Chrome2 | Light | 200 | 1e16 | 1.5 |  | base 1 + 0.5/lv, ×2 per 20 lv | Stats.Chromify >= 2 and Upgrades.Chromium_LightUpgrade2 > 0 |
| Light_Light | Light | 200 | 1 | 1.75 |  | base 1 + 0.5/lv, ×2 per 20 lv | Stats.Chromify >= 1 |
| **Orbs** | | | | | | | |
| Orbs_Energy | Orbs | 1e6 | 100 | 2 |  | exp 3 |  |
| Orbs_Flame | Orbs | 1e6 | 1e3 | 2 |  | exp 1.5 |  |
| Orbs_Orbs | Orbs | 1e6 | 1 | 5 |  | exp 2 |  |
| Orbs_SpawnLevel | Orbs | 100000 | 1e3 | 7.5 |  | base 0 + 1/lv |  |
| Orbs_SpawnTime | Orbs | 20 | 5e3 | 5 |  | base 0 + 0.5/lv |  |
| **Permanent** | | | | | | | |
| Orbs_RuneBulk | Orbs | 1 | 1e33 | 5 |  | base 0 + 1/lv |  |
| Orbs_RuneLuck | Orbs | 1 | 1e24 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv |  |
| Orbs_RuneSpeed | Orbs | 1 | 1e84 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv |  |
| **Power** | | | | | | | |
| Power_Energy | Power | 200 | 1 | 1.5 |  | base 1 + 1/lv, ×2 per 20 lv |  |
| Power_Flame | Power | 200 | 3 | 1.5 |  | base 1 + 0.75/lv, ×2 per 20 lv |  |
| Power_Flesh | Power | 200 | 1e9 | 1.5 |  | base 1 + 0.3/lv, ×2 per 20 lv | Stats.Tier >= 4 |
| Power_Orbs | Power | 120 | 1e3980 | 500 |  | base 1 + 0.75/lv, ×2 per 15 lv | EN.meeq(Stats.Spheres, 1e199) |
| Power_Power | Power | 200 | 15 | 1.5 |  | base 1 + 0.5/lv, ×2 per 20 lv |  |
| Power_Spheres | Power | 200 | 1e282 | 1.75 |  | base 1 + 0.3/lv, ×2 per 20 lv | Stats.Tier >= 9 |
| Power_Spheres2 | Power | 1 | 1e4220 | 1.75 |  | base 1 + 0.3/lv, ×2 per 20 lv | Stats.AscensionOne and Stats.Cube_Level >= 1440 |
| Power_XP | Power | 200 | 750 | 1.5 |  | base 1 + 0.75/lv, ×2 per 20 lv | Stats.Tier >= 4 |
| **Realm_Points** | | | | | | | |
| RP_DMG | Realm Points | 400 | 500 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.Tier >= 4 |
| RP_DMG2 | Realm Points | 180 | 1e504 | 1.5 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_Energy | Realm Points | 400 | 3 | 1.5 |  | base 1 + 1.5/lv, ×2 per 15 lv |  |
| RP_Energy2 | Realm Points | 400 | 1e3003 | 1.5 |  | base 1 + 1.5/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_Flame | Realm Points | 400 | 10 | 1.5 |  | base 1 + 1/lv, ×2 per 15 lv |  |
| RP_Orbs | Realm Points | 400 | 1e8 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.Tier >= 7 |
| RP_Orbs2 | Realm Points | 270 | 1e491 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_Power | Realm Points | 400 | 15 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.Tier >= 2 |
| RP_Prisms | Realm Points | 225 | 1e354 | 1.5 |  | base 1 + 0.1/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_RP | Realm Points | 400 | 75 | 1.5 |  | base 1 + 0.2/lv, ×2 per 15 lv |  |
| RP_RP2 | Realm Points | 240 | 1e498 | 1.5 |  | base 1 + 1.25/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_Spheres | Realm Points | 400 | 1e48 | 1.75 |  | base 1 + 0.75/lv, ×2 per 15 lv | Stats.Tier >= 9 |
| RP_Spheres2 | Realm Points | 300 | 1e486 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.AscensionOne |
| RP_XP | Realm Points | 400 | 55 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.Tier >= 4 |
| **Reflection** | | | | | | | |
| Reflection_Chrome1 | Reflection | 200 | 1 | 1.5 |  | base 1 + 1/lv, ×2 per 15 lv | Stats.Chromify >= 3 |
| Reflection_Light1 | Reflection | 200 | 5 | 1.5 |  | base 1 + 0.5/lv, ×2 per 15 lv | Stats.Chromify >= 3 |
| Reflection_RPS1 | Reflection | 2 | 1e12 | 1000 |  | exp 2 | Stats.Chromify >= 3 |
| **Spheres** | | | | | | | |
| Spheres_DMG | Spheres | 30 | 1e285 | 2 |  | base 1 + .25/lv, ×2 per 15 lv | EN.meeq(Stats.Spheres, "1e275") |
| Spheres_Energy | Spheres | 360 | 15 | 2 |  | base 1 + 3.5/lv, ×2 per 20 lv |  |
| Spheres_Energy2 | Spheres | 360 | 1e3003 | 2 |  | base 1 + 6.5/lv, ×2 per 20 lv | EN.meeq(Stats.Spheres, "1e282") |
| Spheres_Flame | Spheres | 360 | 5e4 | 2 |  | base 1 + 2.5/lv, ×2 per 20 lv |  |
| Spheres_Flesh | Spheres | 360 | 1e27 | 1.5 |  | base 1 + 0.75/lv, ×2 per 20 lv |  |
| Spheres_Orbs | Spheres | 360 | 1e66 | 1.75 |  | base 1 + 1/lv, ×2 per 20 lv |  |
| Spheres_Orbs2 | Spheres | 100 | 1e275 | 1.75 |  | base 1 + .5/lv, ×2 per 15 lv | EN.meeq(Stats.Spheres, "1e275") |
| Spheres_Power | Spheres | 360 | 1e7 | 1.75 |  | base 1 + 0.5/lv, ×2 per 20 lv |  |
| Spheres_Spheres2 | Spheres | 1 | 1e82 | 2 |  | base 1 + 0.75/lv |  |
| Spheres_XP | Spheres | 360 | 1e9 | 1.75 |  | base 1 + 0.75/lv, ×2 per 20 lv |  |
| **Talent** | | | | | | | |
| Chromium_AP1 | Chromium | 5 | 2e2 | 1.5 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Upgrades.Prisms_Chromatizer >= 1 and Stats.Chromatize >= 1 and Module.ChromaRequirement(Player) |
| Chromium_AP2 | Chromium | 3 | 1.5e4 | 1.5 | 10, 1 24, 1 | base 0 + 0.1/lv, reverse, ×2 per 15 lv | Upgrades.Chromium_AP1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_AP3 | Chromium | 1 | 2e8 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Chromium1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_AP4 | Chromium | 1 | 1e4 | 1.5 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Upgrades.Chromium_AP1 >= 1 and Upgrades.Freeze5 >= 1 |
| Chromium_AP5 | Chromium | 1 | 1e20 | 1.5 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Stats.Chromatize >= 7 and Upgrades.Chromium_Droplets1 >= 1 |
| Chromium_AP6 | Chromium | 5 | 1e19 | 1.5 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Stats.Chromatize >= 10 and Upgrades.Chromium_AP5 >= 1 and Module.RuneStarringReq(Player) |
| Chromium_AutoChroma | RobuxTokens | 1 | 1250 | 2 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Automation1 | Chromium | 1 | 7.5e7 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Prisms1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_Automation2 | Chromium | 1 | 1e15 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Chromium_Water1 >= 1 and Stats.Tier >= 13 |
| Chromium_Automation3 | Chromium | 22 | 1e15 | 1.1 | 10, 1 24, 1 | base 0 + 0.125/lv, reverse, ×2 per 15 lv | Upgrades.Chromium_Automation2 >= 1 and Stats.Tier >= 13 |
| Chromium_Chrome1 | Chroma | 1 | 10 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 |
| Chromium_Chrome10 | Chroma | 5 | 1.5e15 | 2 | 10, 1 24, 1 | exp 1.3, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome11 | Chroma | 100 | 7.5e15 | 1.015 |  | exp 1.025 | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome12 | Chroma | 1 | 5e19 | 1.015 | 10, 1 24, 1 | exp 100, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome13 | Chroma | 1 | 2.5e24 | 2 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome14 | Chroma | 1 | 1e31 | 2 | 10, 1 24, 1 | base 1 + 0.1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome15 | Chroma | 2 | 3e37 | 100 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome16 | Chroma | 15 | 1.25e47 | 1.25 | 10, 1 24, 1 | exp 1.1, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome17 | Chroma | 3 | 2.5e48 | 1.75 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome18 | Light | 1 | 5e11 | 1.75 | 10, 1 24, 1 | exp 250, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome19 | Chroma | 50 | 1e52 | 1.33 |  | exp 1.05 | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome2 | Chroma | 2 | 35 | 1.75 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome20 | Chroma | 1 | 4e58 | 2 | 10, 1 24, 1 | base 1 + 0.05/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome21 | Chroma | 1 | 1.5e68 | 100 | 10, 1 24, 1 | exp 7.5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome22 | Chroma | 10 | 1e81 | 7.5 |  | exp 2.5 | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome3 | Chroma | 1 | 90 | 1.75 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome4 | Chroma | 2 | 150 | 1.75 | 10, 1 24, 1 | base 0 + 1.5/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome5 | Chroma | 2 | 350 | 1.75 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome6 | Chroma | 3 | 1.25e7 | 1.33 | 10, 1 24, 1 | base 0 + 3/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome7 | Chroma | 10 | 1e8 | 1.25 | 10, 1 24, 1 | exp 1.15, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome8 | Chroma | 1 | 1e9 | 1.25 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chrome9 | Chroma | 10 | 1.5e14 | 1.75 | 10, 1 24, 1 | base 0 + 150/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chromifier | Chroma | 1 | 1e21 | 1.015 |  | exp 1.025 | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Chromium1 | Chromium | 3 | 2.5e7 | 25 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Upgrades.Prisms_Chromatizer >= 1  and Stats.Chromatize >= 1 and Module.ChromaRequirement(Player) |
| Chromium_Chromium2 | Chromium | 4 | 7.5e7 | 1.5 | 10, 1 24, 1 | base 0 + 0.5/lv, reverse, ×2 per 15 lv | Upgrades.Chromium_Chromium1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_Chromium3 | Chromium | 4 | 5e8 | 1.5 | 10, 1 24, 1 | base 0 + 0.1/lv, reverse, ×2 per 15 lv | Upgrades.Chromium_Ice2 >= 1 and Upgrades.Freeze8 >= 1 |
| Chromium_Droplets1 | Chromium | 1 | 5e8 | 1.5 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Upgrades.Chromium_Chromium2 >= 1 and Stats.Chromatize >= 4 |
| Chromium_Droplets2 | Chromium | 2 | 2.5e8 | 1.5 | 10, 1 24, 1 | exp 40, ×2 per 15 lv | Upgrades.Chromium_Ice2 >= 1 and Upgrades.Freeze9 >= 1 |
| Chromium_Hail1 | RobuxTokens | 1 | 350 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Ice1 | Chromium | 4 | 2.5e7 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Upgrades.Prisms_AP1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_Ice2 | Chromium | 1 | 1e8 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Upgrades.Chromium_Ice1 >= 1 and Upgrades.Freeze5 >= 1 |
| Chromium_Icicles1 | Chromium | 6 | 1.5e8 | 1.5 | 10, 1 24, 1 | exp 1.75, ×2 per 15 lv | Upgrades.Chromium_Automation1 >= 1 and Stats.Tier >= 13 |
| Chromium_Icicles2 | Chromium | 1 | 2.5e13 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_RuneSpeed >= 1 and Runes.Hailstorm >= 1 |
| Chromium_Icicles3 | Chromium | 1 | 5e17 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Droplets1 >= 1 and Upgrades.Freeze8 >= 1 |
| Chromium_Icicles4 | Chromium | 1 | 5e19 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Droplets1 >= 1 and Stats.Chromatize >= 10 |
| Chromium_Light1 | Chroma | 1 | 2e23 | 2 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light10 | Chroma | 1 | 1e82 | 1.5 | 10, 1 24, 1 | exp 100, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light2 | Chroma | 2 | 3.5e25 | 2 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light3 | Chroma | 25 | 3.33e26 | 1.33 |  | exp 1.1 | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light4 | Chroma | 1 | 1e41 | 100 | 10, 1 24, 1 | exp 4, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light5 | Chroma | 4 | 1.5e49 | 1.33 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light6 | Chroma | 1 | 3e50 | 1.33 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light7 | Chroma | 3 | 2.5e61 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light8 | Chroma | 1 | 1e63 | 2 | 10, 1 24, 1 | base 1 + 0.15/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Light9 | Light | 3 | 2.5e15 | 2.5 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_LightUpgrade1 | Chroma | 1 | 2e25 | 2 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_LightUpgrade2 | Chroma | 1 | 5e67 | 2 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Multi1 | Chromium | 2 | 7.5e8 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Chromium_Water1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_NewStat | Chroma | 1 | 5e69 | 1.5 | 10, 1 24, 1 | base 0 + 1/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Prisms1 | Chromium | 2 | 2.5e7 | 2 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Upgrades.Prisms_Chromium1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_Prisms2 | Chromium | 1 | 5e10 | 1.5 | 10, 1 24, 1 | base 1 + 100/lv | Upgrades.Chromium_Prisms1 >= 1 and Stats.Chromatize >= 1 |
| Chromium_Prisms3 | Chromium | 1 | 1e13 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Prisms2 >= 1 and Upgrades.Freeze5 >= 1 |
| Chromium_Prisms4 | Chromium | 5 | 1e16 | 1.5 | 10, 1 24, 1 | exp 10, ×2 per 15 lv | Upgrades.Chromium_Prisms2 >= 1 and Upgrades.Freeze6 >= 1 |
| Chromium_Prisms5 | Chromium | 1 | 1e18 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_Prisms4 >= 1 and Upgrades.Freeze7 >= 1 |
| Chromium_RPS1 | Chroma | 1 | 5000 | 1.75 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS10 | Chroma | 2 | 1e65 | 1.5 | 10, 1 24, 1 | exp 1.05, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS2 | Chroma | 1 | 25000 | 1.75 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS3 | Chroma | 3 | 7.5e9 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS4 | Chroma | 1 | 1e11 | 1.5 | 10, 1 24, 1 | exp 15, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS5 | RobuxTokens | 4 | 75 | 1.33 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS6 | Chroma | 1 | 2.5e12 | 1.33 | 10, 1 24, 1 | base 1 + 0.02/lv, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS7 | Chroma | 2 | 1.5e20 | 5 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS8 | Chroma | 1 | 6.5e41 | 5 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RPS9 | RobuxTokens | 3 | 450 | 1.5 | 10, 1 24, 1 | exp 1.25, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Reflection1 | Chroma | 1 | 5e88 | 1.5 | 10, 1 24, 1 | exp 4, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_RuneLuck1 | Chromium | 1 | 1e19 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Upgrades.Chromium_Multi1 >= 1 and Runes.Bloom >= 1 |
| Chromium_RuneSpeed | Chromium | 1 | 1e13 | 1.5 | 10, 1 24, 1 | exp 1.25, ×1.25 per 15 lv | Upgrades.Chromium_Automation1 >= 1 and Stats.Chromatize >= 7 |
| Chromium_RuneStarring | Chromium | 1 | 5e13 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv |  |
| Chromium_Shine1 | RobuxTokens | 2 | 400 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Shine2 | RobuxTokens | 10 | 200 | 1.2 | 10, 1 24, 1 | exp 1.15, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_SpheresEnhance | Chromium | 1 | 1e9 | 1.5 | 10, 1 24, 1 | exp 1, ×2 per 15 lv | Upgrades.Chromium_AP3 >= 1 and Upgrades.Freeze6 >= 1 |
| Chromium_Tickets1 | Chroma | 3 | 1e22 | 5 | 10, 1 24, 1 | exp 10, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_Tickets2 | Chroma | 1 | 1e55 | 5 | 10, 1 24, 1 | exp 1e15, ×2 per 15 lv | Stats.Chromatize >= 1000 and Runes.Vanguard >= 1e18 and Module.ChromaRequirement(Player) |
| Chromium_UltraRunes | RobuxTokens | 10 | 250 | 1.33 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Runes.Vexed >= 1 |
| Chromium_Water1 | Chromium | 3 | 5e7 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_AP1 >= 1 and Stats.Chromatize >= 1 |
| Prisms_AP1 | Prisms | 1 | 1e39 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_Droplets2 >= 1 |
| Prisms_Accelerator | Prisms | 6 | 1e18 | 1.5 | 10, 1 24, 1 | base 0 + 5/lv, ×2 per 15 lv | Stats.AscensionOne and Upgrades.Prisms_RPEnhance >= 1 and Stats.Cube_Level >= 1350 |
| Prisms_AutoAttack | Prisms | 1 | 500 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Flesh >= 1 |
| Prisms_AutoAttackSpeed | Prisms | 9 | 250 | 1.5 | 10, 1 24, 1 | base 0 + 0.3/lv, ×2 per 15 lv | Upgrades.Prisms_AutoAttack >= 1 |
| Prisms_AutoFlame | Prisms | 1 | 1250 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Energy2 >= 1 and Upgrades.Prisms_Prisms3 >= 1 |
| Prisms_AutoLevel | Prisms | 1 | 2e3 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_SpawnSpeed >= 1 |
| Prisms_AutoPower | Prisms | 1 | 2500 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Energy2 >= 1 |
| Prisms_AutoPower2 | Prisms | 19 | 700 | 1.5 | 10, 1 24, 1 | base 0 + 0.05/lv, ×2 per 15 lv | Upgrades.Prisms_AutoPower >= 1 |
| Prisms_AutoPower3 | Prisms | 19 | 700 | 1.5 | 10, 1 24, 1 | base 0 + 0.05/lv, ×2 per 15 lv | Upgrades.Prisms_AutoPower >= 1 |
| Prisms_Caps | Prisms | 2 | 2.5e5 | 1.5 | 10, 1 24, 1 | base 1 + 100/lv, ×2 per 15 lv | Upgrades.Prisms_Tickets >= 1 and EN.meeq(Stats.Spheres, 5e12) |
| Prisms_Chromatizer | Prisms | 1 | 5e43 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv |  |
| Prisms_Chromium1 | Prisms | 2 | 2e45 | 1.5 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | Upgrades.Prisms_Chromatizer >= 1 and Stats.Chromatize >= 1 and Module.ChromaRequirement(Player) |
| Prisms_DMG | Prisms | 1 | 1e7 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_RuneSpeed >= 1 and Stats.Tier >= 10 |
| Prisms_Damage | Prisms | 3 | 75 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_Multi >= 1 |
| Prisms_Droplets1 | Prisms | 5 | 1e36 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Stats.Tier >= 11 |
| Prisms_Droplets2 | Prisms | 1 | 1e38 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_Water1 >= 1 and Upgrades.Freeze1 >= 1 |
| Prisms_Energy1 | Prisms | 1 | 5 | 1.5 | 10, 1 24, 1 | exp 50, ×2 per 15 lv | true |
| Prisms_Energy2 | Prisms | 1 | 300 | 1.5 | 10, 1 24, 1 | base 1 + 1000/lv, ×2 per 15 lv | Upgrades.Prisms_RP1 >= 1 |
| Prisms_Flame1 | Prisms | 3 | 15 | 1.5 | 10, 1 24, 1 | exp 10, ×2 per 15 lv | Upgrades.Prisms_Energy1 >= 1 |
| Prisms_Flame2 | Prisms | 2 | 1750 | 1.5 | 10, 1 24, 1 | exp 250, ×2 per 15 lv | Upgrades.Prisms_Orbs2 >= 1 and Stats.Cube_Level >= 35 |
| Prisms_Flesh | Prisms | 2 | 125 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_Multi >= 1 |
| Prisms_Flesh2 | Prisms | 1 | 3e7 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Spheres4 >= 1 and Stats.Tier >= 10 |
| Prisms_Flesh3 | Prisms | 1 | 1.25e13 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_RPEnhance >= 1 |
| Prisms_Multi | Prisms | 2 | 70 | 1.5 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Upgrades.Prisms_Prisms1 >= 1 |
| Prisms_Orbs1 | Prisms | 4 | 500 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_AutoAttack >= 1 and Stats.Tier >= 7 |
| Prisms_Orbs2 | Prisms | 3 | 700 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Upgrades.Prisms_Power >= 1 and Stats.Tier >= 7 |
| Prisms_OrbsAutoBuy | Prisms | 1 | 1e6 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_RuneBulk >= 1 and Runes.Dreamscape > 0 |
| Prisms_OrbsEnhance | Prisms | 1 | 5e3 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Flame2 >= 1 and Stats.Cube_Level >= 55 |
| Prisms_Power | Prisms | 5 | 35 | 1.5 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Upgrades.Prisms_Flame1 >= 1 |
| Prisms_Prisms1 | Prisms | 1 | 40 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_Flame1 >= 1 |
| Prisms_Prisms2 | Prisms | 1 | 75 | 1.5 | 10, 1 24, 1 | exp 1.75, ×2 per 15 lv | Upgrades.Prisms_Prisms1 >= 1 |
| Prisms_Prisms3 | Prisms | 2 | 200 | 1.5 | 10, 1 24, 1 | base 0 + 2.5/lv, reverse, ×2 per 15 lv | Upgrades.Prisms_Prisms2 >= 1 |
| Prisms_Prisms4 | Prisms | 1 | 1e18 | 1.5 | 10, 1 24, 1 | base 0 + 5/lv, ×2 per 15 lv | Stats.AscensionOne and Upgrades.Prisms_RP2 >= 1 |
| Prisms_RP1 | Prisms | 2 | 80 | 1.5 | 10, 1 24, 1 | exp 3, ×2 per 15 lv | Upgrades.Prisms_Power >= 1 |
| Prisms_RP2 | Prisms | 1 | 650 | 1.5 | 10, 1 24, 1 | exp 5, ×2 per 15 lv | Upgrades.Prisms_Prisms3 >= 1 |
| Prisms_RPEnhance | Prisms | 1 | 3e10 | 250 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Power >= 1 and Stats.AscensionOne |
| Prisms_RPS | RobuxTokens | 8 | 80 | 1.1 |  | base 1 + .25/lv | Runes.Constellation > 0 |
| Prisms_RPS2 | RobuxTokens | 24 | 25 | 1.1 |  | base 1 + 1/lv | Runes.Rocket > 0 |
| Prisms_RTokens | RobuxTokens | 6 | 150 | 1.2 |  | base 0 + 5/lv | Runes.Cyclone > 0 |
| Prisms_RuneBulk | Prisms | 2 | 3e3 | 1.5 |  | base 0 + 1/lv, ×2 per 15 lv | Upgrades.Prisms_AutoPower2 >= 1 and Upgrades.Prisms_AutoPower3 >= 1 |
| Prisms_RuneBulk2 | RobuxTokens | 1 | 250 | 1.5 |  | base 1 + .1/lv, ×2 per 15 lv | Runes.Aether > 0 |
| Prisms_RuneBulk3 | RobuxTokens | 10 | 200 | 1.175 |  | base 1 + .01/lv | Runes.Shyft > 0 |
| Prisms_RuneBulk4 | RobuxTokens | 8 | 300 | 1.175 |  | base 0 + 5e7/lv | Runes.Frostbite > 0 |
| Prisms_RuneClone | RobuxTokens | 1 | 1000 | 1.5 |  | exp 1.5, ×2 per 15 lv | Runes.Superstar >= 1 |
| Prisms_RuneLuck | Prisms | 2 | 750 | 1.5 | 10, 1 24, 1 | base 1 + 0.125/lv, ×2 per 15 lv | Upgrades.Prisms_Orbs2 >= 1 and Stats.Tier >= 7 |
| Prisms_RuneLuck2 | Prisms | 1 | 6000 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_RuneLuck >= 1 and Stats.Tier >= 7 |
| Prisms_RuneSpeed | Prisms | 1 | 2000 | 1.5 | 10, 1 24, 1 | exp 2, ×2 per 15 lv | Upgrades.Prisms_Walkspeed >= 1 |
| Prisms_RuneSpeed2 | RobuxTokens | 100 | 20 | 1.015 | 10, 1 24, 1 | exp 1.1 | Runes.Oblivion >= 1 |
| Prisms_RuneSpeed3 | RobuxTokens | 250 | 1 | 1.011 |  | exp 1.0175 | Runes.Bolt >= 1 |
| Prisms_SpawnSpeed | Prisms | 12 | 850 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_AutoAttack >= 1 and Stats.Tier >= 6 |
| Prisms_Spheres1 | Prisms | 5 | 750 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_RP2 >= 1 and Stats.Tier >= 9 |
| Prisms_Spheres2 | Prisms | 3 | 1000 | 1.5 | 10, 1 24, 1 | exp 4, ×2 per 15 lv | Upgrades.Prisms_AutoFlame >= 1 and Stats.Tier >= 9 |
| Prisms_Spheres3 | Prisms | 1 | 1e6 | 1.5 | 10, 1 24, 1 | exp 1e9, ×2 per 15 lv | Upgrades.Prisms_Orbs1 >= 1 and EN.meeq(Stats.Spheres, 5e53) |
| Prisms_Spheres4 | Prisms | 1 | 1.75e7 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_Spheres3 >= 1  and Stats.Tier >= 10 |
| Prisms_Spheres5 | Prisms | 4 | 4.5e37 | 1.5 | 10, 1 24, 1 | exp 4, ×2 per 15 lv | Upgrades.Prisms_Water1 >= 1 and Upgrades.Freeze3 >= 1 |
| Prisms_SpheresEnhance | Prisms | 1 | 2e19 | 1.5 | 10, 1 24, 1 | base 1 + 0.85/lv, ×2 per 15 lv | Upgrades.Prisms_RuneLuck2 >= 1 and Stats.AscensionOne and EN.meeq(Stats.Spheres, 1e202) |
| Prisms_Tickets | Prisms | 1 | 10000 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_OrbsEnhance >= 1 and Stats.Tier >= 9 |
| Prisms_Tickets2 | RobuxTokens | 4 | 150 | 1.5 | 10, 1 24, 1 | exp 50000, ×2 per 15 lv | Runes.Strix >= 1 |
| Prisms_Walkspeed | Prisms | 1 | 350 | 1.5 | 10, 1 24, 1 | base 0 + 7/lv, ×2 per 15 lv | Upgrades.Prisms_Damage >= 1 |
| Prisms_Water1 | Prisms | 3 | 5e36 | 1.5 | 10, 1 24, 1 | exp 1.5, ×2 per 15 lv | Upgrades.Prisms_Droplets1 >= 1  and Stats.Tier >= 11 |
| **Tickets** | | | | | | | |
| Tickets_Chrome1 | Tickets | 30 | 1e288 | 1.5 |  | exp 1.25, ×3 per 15 lv | Runes.Hurricane >= 1 |
| Tickets_Chromium | Tickets | 1 | 1e6 | 1.155 |  | base 1 + 2/lv, ×2 per 15 lv | Upgrades.Freeze7 >= 1 |
| Tickets_Droplets | Tickets | 60 | 2.5e4 | 1.155 |  | exp 1.2, ×1.5 per 15 lv | true |
| Tickets_Energy | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv |  |
| Tickets_Flame | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv |  |
| Tickets_Flesh | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv | Stats.Tier >= 4 |
| Tickets_Ice | Tickets | 60 | 5e4 | 1.155 |  | exp 1.2, ×1.5 per 15 lv | Upgrades.Freeze2 >= 1 |
| Tickets_Icicles | Tickets | 60 | 1e5 | 1.155 |  | exp 1.2, ×1.5 per 15 lv | Stats.Tier >= 13 |
| Tickets_Orbs | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv | Stats.Tier >= 7 |
| Tickets_Power | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv |  |
| Tickets_RuneBulk | Tickets | 1 | 200 | 1.155 |  | base 0 + 1/lv, ×2 per 15 lv |  |
| Tickets_RuneBulk2 | Tickets | 25 | 1e15 | 1.75 |  | base 1 + 0.01/lv, ×1.1 per 5 lv | Runes.Thorn >= 1 |
| Tickets_RuneBulk3 | Tickets | 75 | 1e131 | 1.6 |  | base 1 + 0.075/lv, ×1.15 per 5 lv | Runes.Squid >= 1 |
| Tickets_RuneBulk4 | Tickets | 1 | 2.5e234 | 1.6 |  | base 1 + 0.01/lv, ×1.15 per 5 lv | Runes.Torrent >= 1 |
| Tickets_RuneLuck | Tickets | 1 | 75 | 1.155 |  | base 1 + 0.25/lv, ×2 per 15 lv |  |
| Tickets_RuneLuck2 | Tickets | 25 | 1e5 | 1.155 |  | base 1 + 0.01/lv, ×1.1 per 5 lv | Runes.Icequake >= 1 |
| Tickets_RuneSpeed | Tickets | 1 | 100 | 1.155 |  | base 1 + 0.25/lv, ×2 per 15 lv |  |
| Tickets_RuneSpeed2 | Tickets | 25 | 2e5 | 1.155 |  | base 1 + 0.01/lv, ×1.1 per 5 lv | Runes.Blizzard >= 1 |
| Tickets_RuneSpeed3 | Tickets | 150 | 1e37 | 1.75 |  | base 1 + 0.05/lv, ×1.25 per 5 lv | Runes.HyperFinality >= 1 |
| Tickets_Spheres | Tickets | 60 | 5 | 1.155 |  | exp 1.2, ×2 per 15 lv | Stats.Tier >= 9 |
| Tickets_Tickets | Tickets | 2 | 5e234 | 125 |  | exp 100, ×1.15 per 5 lv | Runes.Torrent >= 1 |
| Tickets_Water | Tickets | 60 | 2.5e4 | 1.155 |  | exp 1.2, ×1.5 per 15 lv | true |
