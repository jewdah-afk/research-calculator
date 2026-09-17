# Porting a Web Incremental Game to Roblox Luau, With Verifiable Equivalence

*Chapter 62 of the Roblox mastery corpus. This is a methodology chapter for a
team that has a working incremental/idle game written in HTML/CSS/JavaScript and
wants the Roblox version to produce **the same numbers and the same
progression** — not "roughly the same feel", but a bit-for-bit-defensible match
against a golden master extracted from the original.*

*Primary sources: the Luau VM C++ source (`luau-lang/luau`, `VM/src/*`), the
Roblox engine reference YAML and guide content (`Roblox/creator-docs`), and MDN's
source repository (`mdn/content`) for JavaScript semantics. `create.roblox.com`,
`devforum.roblox.com` and `luau.org` are unreachable from this environment; every
Roblox claim below is taken from the generated reference YAML that the Creator
Hub pages are built from, which is higher fidelity than the rendered pages.
Claims that could not be verified against a primary source are marked
**[unverified]**.*

---

## TL;DR

- **Port the simulation before you port anything else, as a pure module with
  zero Roblox dependencies.** One folder of Luau that takes a state table and a
  delta-time and returns a new state, importing nothing from `game`, no
  `Instance`, no `RunService`, no `wait`. This is the single most important
  structural decision in the whole project: it is what makes headless testing,
  golden-master diffing and fast-forward simulation possible at all. Everything
  else in this chapter is downstream of it.
- **Truthiness is the #1 source of silently wrong ported logic.** JavaScript
  treats `0`, `-0`, `""`, `NaN`, `null` and `undefined` as falsy
  ([MDN, *Truthy*](https://github.com/mdn/content/blob/main/files/en-us/glossary/truthy/index.md));
  Luau treats **only** `nil` and `false` as falsy, and explicitly documents that
  "Luau considers both zero and the empty string as `true`"
  (`creator-docs`, `luau/booleans.md`). Every `if (x)` where `x` is a count, a
  multiplier, a tier index or a string label is a live bug in the port.
- **`%` has different signs in the two languages.** JS `%` is a *remainder* that
  takes the sign of the dividend (`-13 % 5 === -3`, MDN). Luau `%` is a *floored
  modulo*: `luai_nummod(a, b) = a - floor(a / b) * b` (`VM/src/lnumutils.h`), so
  `-13 % 5 == 2`. Any wrap-around, cycle index, or "every Nth tick" calculation
  over a value that can go negative diverges.
- **`Math.round` and `math.round` disagree on exact halves of negative
  numbers.** JS rounds ties toward +∞ (`Math.round(-20.5) === -20`, MDN); Luau
  "rounds away from zero such that `0.5` rounds to `1` and `-0.5` rounds to
  `-1`" (`creator-docs`, `libraries/math.yaml`). Write a `jsRound` helper and use
  it everywhere the original used `Math.round`.
- **Arrays are 1-based and `#t` is undefined in the presence of holes.**
  `luaH_getn` finds *a* boundary — "an integer index such that `t[i]` is non-nil
  and `t[i+1]` is nil" — by binary search (`VM/src/ltable.cpp`). A sparse JS
  array ported naively to a Luau table with `nil` gaps gives a length that is
  *valid but unpredictable*. Never store `nil` inside an array; use a sentinel or
  a dictionary keyed by id.
- **`table.sort` is not stable and its comparator contract is enforced with
  errors.** JS `Array.prototype.sort` has been stable since ES2019 (MDN); Luau's
  is a quicksort/heapsort hybrid that raises `invalid order function for sorting`
  if `comp(a,b)` and `comp(b,a)` are both true, and `table modified during
  sorting` if the comparator resizes the table (`VM/src/ltablib.cpp`). A JS
  comparator returning a number must become a Luau comparator returning a
  strict-less-than boolean, and ties must be broken deterministically or the
  ordering of equal elements — and therefore any order-dependent UI or
  RNG-consuming loop — will not match.
- **Bitwise ops are not the same machine.** JS `&`, `|`, `^`, `<<`, `>>` coerce
  operands to **signed** 32-bit integers and return a signed 32-bit result (MDN);
  Luau's `bit32` library "treats numbers as unsigned 32-bit integers"
  (`creator-docs`, `libraries/bit32.yaml`). `bit32.band(x, y)` where JS produced
  a negative result gives you `x + 2^32`. Convert explicitly at every boundary.
- **JSON round-trips are lossy in a specific, documented way.** `JSONEncode`
  states that if a table has both string and number keys, "an array takes
  priority (string keys are ignored)", that an empty table encodes as `[]` not
  `{}`, and that `inf`/`nan` are emitted despite not being valid JSON
  (`creator-docs`, `classes/HttpService.yaml`). A save schema with any mixed or
  possibly-empty table is a save-corruption bug waiting to happen.
- **`break_infinity.js` maps cleanly onto a Luau big-number library, but the
  rounding and string formatting do not.** `Decimal.round()` delegates to
  `Math.round(this.toNumber())` for small exponents (`src/decimal.ts`), so it
  inherits JS half-up behaviour. Port the formatter and the rounding explicitly;
  do not assume the Luau library's `round`/`toString` agrees.
- **DOM→Roblox is mostly a mechanical mapping** (box model → `UDim2` +
  `UIPadding`, flexbox → `UIListLayout` + `UIFlexItem`, `position:absolute` →
  `AnchorPoint`/`Position`, px/% → Offset/Scale, transitions → `TweenService`,
  `innerHTML` → `TextLabel` + `RichText`, scrolling div → `ScrollingFrame`,
  canvas → `EditableImage`) with two genuine gaps: **CSS-drawn art and SVG have
  no Roblox equivalent** and must be rasterized or rebuilt, and there is no
  reflowing text layout.
- **Every uploaded image passes moderation before players can see it.** "If an
  asset is still in the moderation queue when you publish your game, users cannot
  see or interact with the asset until Roblox approves it"
  (`creator-docs`, `projects/assets/index.md`). Budget days, not minutes, and
  upload the full atlas set early.
- **Treat any imported save from the web version as hostile input.** Decode,
  then validate and clamp *every* field against the content tables before it
  touches the simulation. A save is the one place a player can hand your server
  arbitrary numbers.
- **Prove equivalence with golden vectors, not with vibes.** Instrument the
  original to dump state snapshots at known tick counts and an input→output table
  for every formula; run the ported simulation headlessly under **Lune** in CI
  and diff. Add property tests (monotonicity, conservation, no NaN) and
  fast-forward runs over simulated years. Publish a written tolerance policy so
  "is this drift a bug?" has an answer before anyone asks it.
- **Order the work: inventory → behavioural spec → pure simulation + harness →
  save layer → UI → presentation → assets.** Each stage has a verification gate;
  do not open the next stage until the current gate is green.

---
