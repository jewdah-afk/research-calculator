# Starter Runes (built)

The code is in `shared/Runes.luau`. The server runs it from `GameService` and the client panel is `Main.client.luau` → Runes.

## Where
- **Rune Altar** sits left of the Mega Board. Stand on its glowing pad (radius 14 studs) to auto-roll for free at ×1 speed.
- **Rune Forge** sits right of the board. It holds the gem upgrades.
- Both stands appear through the normal reveal:
  - The altar shows as ??? after your first cash, and opens at $10.
  - The forge opens after your first rune plus your first gem.

## The 10 runes ($10 cash per rune opened)

| # | Rune | Chance | Boost | Scaling |
|---|---|---|---|---|
| 1 | Spark | 1/1 | +0.5% cash per copy | caps at +25% (50 copies), then stays maxed |
| 2 | Pebble | 1/3 | +1% cash | caps at +40% |
| 3 | Breeze | 1/10 | +2% cash | caps at +60% |
| 4 | Tide | 1/40 | +3% cash | caps at +90% |
| 5 | Ember | 1/150 | +5% cash | caps at +150% |
| 6 | Echo | 1/1K | +1.5% rebirth points per LEVEL | never caps |
| 7 | Prism | 1/10K | +2.5% rebirth points per level | never caps |
| 8 | Halo | 1/100K | +2% AP per level | never caps |
| 9 | Crown | 1/1M | +3% AP per level | never caps |
| 10 | Eternity | 1/10M | +3% TrP per level | never caps |

- **Levels for runes 6–10:** each level needs **×1.25 more copies** than the last. That's 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 19, 24, … copies. 100 copies is LV 21, 10K is LV 42 and 1M is LV 62. They keep growing forever, slowly.
- **Points stay whole.** Point boosts build up as a hidden fraction until they make a full point. For example, +6% rebirth points over 25 rebirths gives 26, with 0.5 carried over.
- **Cash runes** count as a bonus, so `Balance.bonusLog` softcaps them like every other bonus.

## How fast you roll
- **rolls/second** = 0.5 × 1.05^(orb-drop milestones) × 1.08^(Forge Speed) × 1.10^(Forge Tickrate) × 2 with the Auto-Roll pass
- **clone**: each rune has (Clone Chance) to clone; a hit adds (1 + Clone Amount) extra copies
- **runes per roll (bulk)** = (1 + opening milestones, max +4 + Forge Bulk + pad-time +N) × 1.15^(opening milestones) × pad-time bulk multipliers
- **rune luck** = 1.10^(orb-drop milestones) × 1.12^(Forge Luck) × pad-time luck multipliers

### Milestones (10, 100, 500, 1K, 5K, 10K, 50K, … forever)
- **Runes opened:** each milestone gives ×1.15 bulk. The first 4 also give +1 bulk each, so bulk reaches 5 before the multipliers apply.
- **Orbs dropped on the board:** each milestone gives ×1.05 rune speed and ×1.10 rune luck.

### Pad time (saved forever)

| Time on pad | Bonus |
|---|---|
| 1 min | +1 bulk |
| 5 min | ×1.05 luck |
| 15 min | ×1.10 bulk |
| 30 min | +2 bulk |
| 1 h | ×1.10 luck |
| 2 h | ×1.25 bulk |
| 3 h | +3 bulk |
| 6 h | ×1.25 luck |
| 12 h | ×1.5 bulk |
| 16 h | +4 bulk |
| 20 h | ×1.5 luck |
| 24 h | ×2 bulk |

- The "+N bulk" bonuses replace each other (max +4). All multipliers stack.

### Rune Forge (gems)

| Upgrade | Per level | Cost | Max |
|---|---|---|---|
| Rune Bulk | +1 rune per roll | 1 × 2.5^lv | 16 (last ≈ 930K) |
| Rune Speed | ×1.08 rolls/s | 5 × 2.6^lv | 13 |
| Rune Luck | ×1.12 luck | 2 × 2.5^lv | 16 |
| Clone Chance | +3% chance a rune clones | 10 × 2.6^lv | 15 (45%) |
| Clone Amount | +1 extra copy per clone | 50 × 3.2^lv | 9 (+10 copies) |
| Tickrate | ×1.10 opening speed | 30 × 2.9^lv | 11 (×2.85) |

### Auto-Roll
- **Free:** standing on the pad, ×1 speed.
- **Robux pass:** rolls anywhere at ×2 speed. Set the pass id in `Runes.AUTO_PASS_ID`.

### Leaderboard
- **RUNES OPENED** has its own tab.
- Rare runes (6+) toast for you. Halo and rarer are announced to the whole server.
