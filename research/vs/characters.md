# Vampire Survivors — the 6 base starting characters (base game, no DLC)

Retrieved 2026-09-19. Companion file: `characters.json` (follows `SCHEMA.md`).

## No character swaps were needed
All six requested characters — **Antonio, Imelda, Pasqualina, Gennaro, Arca, Porta** — have complete stat data. No substitution (Lama / Poe / Clerici / Dommario / Krochi) was required.

## Source caveat (important)
`vampire.survivors.wiki`, `vampire-survivors.fandom.com`, `gamefaqs.gamespot.com`, `steamcommunity.com` and other guide sites are **blocked by this session's network egress proxy** — every direct fetch returned `EGRESS_BLOCKED`. Web *search* still worked (returning summarised wiki content), and `raw.githubusercontent.com` was reachable.

Numbers below therefore come from, in order:

| id | What it is | URL |
|---|---|---|
| `vst-chardata` | Extracted copy of the game's own character table (Vampire Survivors Tools) — the authoritative numeric source used here | https://raw.githubusercontent.com/jerek/vampire-survivors-tools/main/src/js/VST/VS/Character.js |
| `vs-build-planner` | Community build planner data (starting weapons, gold prices, ability text) | https://raw.githubusercontent.com/Danmer/vs-build-planner/main/data.js |
| `official-wiki-mirror-characters` | Verbatim mirror of the official wiki's *Characters* page wikitext | https://raw.githubusercontent.com/NobleStripes/Survivors-Helper/main/data/raw/wiki/characters.wikitext |
| `official-wiki-mirror-achievements` | Verbatim mirror of the official wiki's *Achievements* page wikitext (unlock conditions) | https://raw.githubusercontent.com/NobleStripes/Survivors-Helper/main/data/raw/wiki/achievements.wikitext |
| `websearch-wiki-summary` | Search-engine summary of https://vampire.survivors.wiki/w/Characters (used only for cross-checking wording) | https://vampire.survivors.wiki/w/Characters |

## Conventions
- Multiplier stats (`might`, `area`, `speed`, `duration`, `cooldown`, `luck`, `growth`, `greed`, `curse`, `moveSpeed`) are stored as **multipliers**: `1` = unmodified, `1.3` = +30%.
- `maxHealth` flat HP; `recovery` flat HP/sec; `armor`, `amount`, `revival` flat integers.
- `magnet` is an **additive fraction**: `0` = unmodified (this is the game's own default), `0.25` = +25% pickup radius.
- `levelBonuses` values are **deltas** added at that level.
- Game-data field name mapping: `power`→`might`, `regen`→`recovery`, `maxHp`→`maxHealth`, `revivals`→`revival`.
- The `growth +1` at level 20/40 and `growth -1` at level 21/41 entries are the game's universal "double XP for one level" mechanic; **every** character has them, so treat them as shared, not as a character feature.

## Base stats

| Stat | Antonio | Imelda | Pasqualina | Gennaro | Arca | Porta |
|---|---|---|---|---|---|---|
| maxHealth | 120 | 100 | 100 | 120 | 100 | 100 |
| recovery | 0 | 0 | 0 | 0 | 0 | 0 |
| armor | 1 | 0 | 0 | 0 | 0 | 0 |
| moveSpeed | 1 | 1 | 1 | 1 | 1 | 1 |
| might | 1 | 1 | 1 | 1 | **1.1** | 1 |
| area | 1 | 1 | 1 | 1 | 1 | **1.3** |
| speed | 1 | 1 | **1.1** | 1 | 1 | 1 |
| duration | 1 | 1 | 1 | 1 | 1 | 1 |
| amount | 0 | 0 | 0 | **1** | 0 | 0 |
| cooldown | 1 | 1 | 1 | 1 | 1 | **0.1** |
| luck | 1 | 1 | 1 | 1 | 1 | 1 |
| growth | 1 | 1 | 1 | 1 | 1 | 1 |
| greed | 1 | 1 | 1 | 1 | 1 | 1 |
| magnet | 0 | 0 | 0 | 0 | 0 | 0 |
| revival | 0 | 0 | 0 | 0 | 0 | 0 |
| curse | 1 | 1 | 1 | 1 | 1 | 1 |

Source: `vst-chardata`.

## Starting weapon, unlock, cost

| Character | Starting weapon | Unlock condition | Base gold cost |
|---|---|---|---|
| Antonio Belpaese | Whip | Available from the start (first character a new player uses) | 0 |
| Imelda Belpaese | Magic Wand | Unlocked by default; buy with gold | 10 |
| Pasqualina Belpaese | Runetracer | Unlocked by default; buy with gold | 100 |
| Gennaro Belpaese | Knife | Unlocked by default; buy with gold | 500 |
| Arca Ladonna | Fire Wand | Achievement "Arca": get Fire Wand to Level 4, then buy | 500 |
| Porta Ladonna | Lightning Ring | Achievement "Porta": get Lightning Ring to Level 4, then buy | 500 |

Sources: weapons/prices `vs-build-planner`; unlock achievements `official-wiki-mirror-achievements`; "Antonio is free / all others purchased" `official-wiki-mirror-characters`.

**Price scaling:** the official wiki states every purchasable character's price is "increased by 10% additively per character purchased". The numbers above are the *base* prices.

## Per-level bonuses and caps

### Antonio — Whip
+0.1 Might at levels **10, 20, 30, 40, 50**. Cap: **+50% Might, reached at level 50**.
Passive: "Gains 10% more damage every 10 levels (max +50%)." Also innately +20 Max Health and +1 Armor.

### Imelda — Magic Wand
+0.1 Growth at levels **5, 10, 15**. Cap: **+30% Growth, reached at level 15**.
Passive: "Gains 10% more experience every 5 levels (max +30%)." Otherwise a pure-baseline character.

### Pasqualina — Runetracer
Starts at 1.1 Speed, then +0.1 Speed at levels **5, 10, 15**. Cap: **1.4x Projectile Speed, reached at level 15**.
Passive: "Projectiles get 10% faster every 5 levels (max +30%)" — see conflict note on +30% vs +40%.

### Gennaro — Knife
**No scaling level-up bonus** (only the universal growth spike at 20/40).
Passive: permanent **+1 Amount** (one extra projectile on every weapon), plus +20 Max Health.

### Arca — Fire Wand
−0.05 Cooldown at levels **10, 20, 30**. Cap: **−15% Cooldown, reached at level 30**.
Passive: "Weapon cooldown is reduced by 5% every 10 levels (max −15%)." Also innately **+10% Might**.

### Porta — Lightning Ring
+0.3 Cooldown at levels **2, 3, 4** — i.e. her starting 0.1x Cooldown (a temporary −90% cooldown) climbs back to 1.0x by level 4. Cap: level 4, back to neutral.
Passive: permanent **+30% Area** plus that temporary massive cooldown bonus.

## Conflicts
1. **Pasqualina's cap wording** — game data: base `speed` 1.1 + 0.1 at levels 5/10/15 = **1.4x**. Wiki summary phrases this as "+10% every 5 levels, max **+40%**" (counting her innate +10%); the build planner phrases it as "max **+30%**" (counting only the level-ups). Same numbers, different framing.
2. **Antonio maxHealth 120 vs "100 + 20"** — the wiki describes "+20 Max Health" relative to the 100 default; absolute value is 120. Not a real disagreement.
3. **unlockCost** — listed values are base prices; the official wiki's +10%-per-purchase additive scaling makes the in-game displayed price higher than these.

## Unknowns
- Base gold prices for Gennaro / Arca / Porta (500 each) could only be confirmed from `vs-build-planner`; the official wiki pages that would corroborate them were unreachable from this session.
- No other listed field is null.
