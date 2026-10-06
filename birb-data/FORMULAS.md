# Birb: stat and formula reference (for the Roblox remake)

Every number here comes from a source. If a value is not known, it is marked **UNKNOWN**. Nothing is guessed.

Sources:
- `index.html` in this repo (the research calculator)
- birb.wiki.gg pages, read on 2026-10-06 (the wiki marks itself as unfinished)

---

## 1. Research and RLGM (from this repo, exact)

| Name | Formula |
|---|---|
| Base research/sec | `BASE = 5` |
| Infinite-upgrade boost at level L | `1.01^L` |
| Research rate | `rps(L) = 5 × M × 1.01^L` |
| Research upgrade cost at level L | `100000 × r^L`, where `r = 100000^0.00087 = 1.0100665756` |
| RLGM cost at level L | `100000 × 1.122^L` |
| RLGM luck multiplier | `1.01^L` |
| Total cost from level a to a+n | `1e5 · r^a · (r^n − 1)/(r − 1)` |
| Time from level a to a+n | `(1e5 / 5M) · q^a · (q^n − 1)/(q − 1)`, where `q = r/1.01` |
| RLGM total cost | `1e5 · 1.122^a · (1.122^n − 1)/0.122` |

The multiplier `M` is the product of every research source the player has, times the achievement multiplier:

| Group | Source | Multiplier |
|---|---|---|
| Playtime | Minutes | 1.15 |
| Playtime | Hours | 1.25 |
| Playtime | Days | 1.5 |
| Challenge | Researcher | 1.5 |
| Board | Upgrade 1–7 | 1.15, 1.25, 1.35, 1.45, 1.55, 1.7, 1.8 |

Achievement multiplier: **UNKNOWN** (the calculator takes it as an input).

## 2. Popcorn upgrades (wiki)

| Upgrade | Effect | Levels | Cost formula |
|---|---|---|---|
| Popcorn Value | +1 flat popcorn value per level | max 999 | **UNKNOWN** |
| Faster Popcorn | Spawn time goes from 2.4s to 0.2s (Meadow and Desert) | 12 | **UNKNOWN**; the per-level step is also unknown |
| Popcorn Cap | +2 cap per level. Max 40 levels for an 80 cap, raised to 50 levels for a 100 cap | 40 → 50 | **UNKNOWN** |
| Wing Training | Move speed starts at 100% and reaches 252% at level 30 | 20 → 30 | **UNKNOWN**; the per-level step is also unknown |

The base popcorn value, the base cap, and what raises the level caps are all **UNKNOWN**.

## 3. Rebirb

- Rebirbing gives an extra multiplier to XP gain and to popcorn respawn rate. The size of that multiplier is **UNKNOWN**.
- Each rebirb raises Speed, Rare %, and Popcorn gain. The amounts are **UNKNOWN**.

## 4. Companions (wiki)

**Sparrow** (automates popcorn)
- Flight speed is `150 + 2 × level` px/s.
- Resonance drains XP, capped at 25% of the XP needed for the next level.
- You can have up to 16 sparrows before Rebirb unlocks.
- Milestones:

| Milestone | Reward |
|---|---|
| 2 sparrows | Feeding +25% |
| 16 sparrows | Feeding +25% |
| 1 rebirb | Resonance +25% |
| 4 sparrows | Resonance +25% |
| 5 rebirbs | Mitosis −15% |
| 8 sparrows | Mitosis −20% |

**Seagull** (fishing)
- Max level starts at 50, with a rebirb every 25 levels.
- After the Reborn milestone, the cap rises to 100 and a rebirb takes 50 levels.
- Doctrines:

| Doctrine | Interval | XP | Notes |
|---|---|---|---|
| Balanced | 1.00× | 1.00× | — |
| Hunter | 1.30× | 0.94× | 72% rare reroll |
| Training | 1.02× | 1.45× | 56% penalty reduction |

- Base reroll chance is 15%.
- The Echo milestone gives an 8% chance of a double fish per catch.
- Moonlit adds +0.4% shiny chance per hour.

**Parrot** (equipment)
- Equipment starts at a 0.1× multiplier.
- Common V reaches 1.0×.
- An evolution happens every 5 upgrades.
- Infusion caps:

| Rarity | Max level | Multiplier |
|---|---|---|
| Common | 3 | 1.36× |
| Uncommon | 5 | 1.60× |
| Rare | 7 | 1.84× |
| Epic | 10 | 2.20× |
| Legendary | 15 | 2.80× |

- Artifact slots go from 3 to 10.

**Dave**
- Rebirbs every 25 levels, up to 1,000 rebirbs.
- Each level gives +1% Golden Bonus.
- Each rebirb gives +0.1 Golden Bonus, +2 Forage Size, and +3% Travel Speed.

**Red Panda**: no data. **UNKNOWN**

## 5. Still missing (needed for a balanced 1:1 port)

- Every cost curve (popcorn upgrades, companion levels, rebirb requirements)
- The XP curve per level
- Golden popcorn rates
- Values for fish, twigs, and zones
- Artifact stats
- Sacrifice Room and Expedition mechanics
