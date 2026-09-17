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

## JS→Luau semantic gotchas table

The table is ordered by how often it bites in practice on an incremental-game
port. "Silent" means the port runs and produces wrong numbers; "loud" means you
get an error.

| # | Topic | JavaScript | Luau | Failure mode | Correct translation |
|---|-------|-----------|------|--------------|---------------------|
| 1 | Truthiness | `0`, `-0`, `""`, `NaN`, `null`, `undefined` are falsy | only `nil` and `false` are falsy | **Silent** — `if (count)` guards stop guarding | `if count ~= 0 then`, `if s ~= "" then`, `if v ~= nil then` — never bare `if v then` on a number or string |
| 2 | Default-value idiom | `const n = opts.n \|\| 10` gives `10` when `opts.n === 0` | `local n = opts.n or 10` gives `0` when `opts.n == 0` | **Silent** — and it silently *fixes* a latent JS bug, which is still a divergence | Decide per site. To match JS exactly: `local n = (opts.n == nil or opts.n == 0 or opts.n ~= opts.n) and 10 or opts.n` |
| 3 | Array indexing | 0-based; `a[0]` first, `a.length - 1` last | 1-based; `t[1]` first, `t[#t]` last | **Silent** — off-by-one in tier/level lookups | Shift every literal index and every loop bound; see §3 |
| 4 | `for` bounds | `for (let i = 0; i < n; i++)` | `for i = 1, n do` | **Silent** — `for i = 0, n` runs `n+1` times | `for i = 1, n do` and `for i = 0, n - 1 do` for a genuinely 0-based table |
| 5 | `%` sign | remainder; sign of the **dividend**: `-13 % 5 === -3` | floored modulo `a - floor(a/b)*b`: `-13 % 5 == 2` | **Silent** — wrap-around indices, cycle phases | JS-identical remainder: `local function jsMod(a,b) local r = math.fmod(a,b) return r end` (`math.fmod` "rounds the quotient towards zero") |
| 6 | Integer division | `Math.floor(a / b)` or `(a / b) \| 0` (truncates!) | `a // b` is `floor(a / b)` | **Silent** on negatives: `(-7/2)\|0 === -3` but `-7 // 2 == -4` | `Math.floor` → `//` or `math.floor`; `\| 0` / `Math.trunc` → a `trunc` helper |
| 7 | `Math.round` ties | ties go toward **+∞**: `Math.round(-20.5) === -20` | ties go **away from zero**: `math.round(-0.5) == -1` | **Silent** on negatives and on offline-progress halves | `local function jsRound(x) return math.floor(x + 0.5) end` (matches JS except at `-0`) |
| 8 | Bitwise | coerces to **signed** int32; result signed | `bit32.*` treats numbers as **unsigned** 32-bit | **Silent** — a negative JS result becomes `x + 2^32` | Wrap: `local function toI32(u) return u >= 0x80000000 and u - 0x100000000 or u end` |
| 9 | `>>>` | unsigned right shift | `bit32.rshift` (already unsigned) | Mostly fine | `x >>> n` → `bit32.rshift(x, n)`; `x >> n` → `bit32.arshift(x, n)` |
| 10 | Sparse arrays | holes are allowed; `length` is the highest index + 1 | `#t` returns *a* boundary found by binary search | **Silent and non-deterministic** | Never write `nil` into an array; use a sentinel value or a keyed dictionary + explicit `count` field |
| 11 | `undefined` vs `null` | two distinct absent values; `undefined == null` is `true`, `===` is `false` | one `nil` | **Silent** — a JS `null` used as "explicitly cleared" collapses into "never set" | If the original distinguishes them, model it explicitly (`NULL = newproxy()` sentinel or a `{ set = true, value = nil }` box) |
| 12 | `==` vs `===` | `==` coerces; `===` does not | `==` never coerces; `~=` is "not equal" | **Silent** only where the original relied on coercion (`"5" == 5`) | Port `===` → `==`. Port `==` only after reading what it was coercing |
| 13 | `sort` stability | stable since ES2019 | not stable (quicksort/heapsort hybrid) | **Silent** — ties reorder, changing display order and any index-dependent logic | Add an explicit tiebreak key (id, then index) to the comparator |
| 14 | `sort` comparator | returns a **number**; sloppy comparators just sort oddly | returns a **boolean** (strict less-than); a non-strict-weak-order comparator **errors** | **Loud** — `invalid order function for sorting` | `cmp(a,b) < 0` → `return cmp(a,b) < 0`; never `<=` |
| 15 | `Array` methods | `map/filter/reduce/slice/splice/find/some/every/includes` | none of them; `table.*` has `insert/remove/sort/concat/find/move/clone/create/pack/unpack/freeze` | **Loud** — missing method | Write a tiny `Arr` module once (§4) rather than inlining loops everywhere |
| 16 | String indexing | 0-based; `s[0]`, `s.slice(a, b)` end-exclusive | 1-based; `string.sub(s, i, j)` end-**inclusive** | **Silent** — truncated or over-long substrings | `s.slice(a, b)` → `string.sub(s, a + 1, b)` |
| 17 | `split` | `s.split(",")` | does not exist | **Loud** | `for part in string.gmatch(s, "([^,]*)") do` — note the `*` vs `+` distinction for empty fields |
| 18 | Regex | full ECMAScript regex | **Lua patterns are not regex** — no alternation, no grouping quantifiers, no lookaround, 12 magic characters `^$()%.[]*+-?` | **Silent or loud** depending on the pattern | Translate simple patterns (§7); for anything with `\|`, `{n,m}`, backrefs or lookaround, rewrite the logic or vendor a regex library |
| 19 | JSON key order | `JSON.stringify` follows insertion order for string keys | unspecified; Luau tables have no ordering | **Silent** — any hash-of-save or byte-comparison breaks | Never compare serialized saves byte-for-byte; compare decoded structures |
| 20 | JSON empty object | `JSON.stringify({})` → `"{}"` | `JSONEncode({})` → `"[]"` | **Silent** — a round-trip turns a dictionary into an array | Encode a marker field, or never allow an empty sub-table in the schema |
| 21 | JSON mixed table | JS objects and arrays are distinct types | "If a table contains both [string and number keys], an array takes priority (string keys are ignored)" | **Silent data loss** | Enforce: every table in the save schema is *either* a pure array *or* a pure dictionary |
| 22 | `NaN`/`Infinity` in JSON | `JSON.stringify(NaN)` → `"null"` | `JSONEncode` "allows values such as `inf` and `nan` which are not valid JSON" | **Silent** — produces a save no other parser can read | Sanitize before encoding; assert `v == v and v ~= math.huge` |
| 23 | `this` | dynamically bound; needs `bind`/arrow capture | `self` is just the first argument of `:` calls | **Loud** usually, **silent** if a method is stored and called as a plain function | `obj.method` → `function() return obj:method() end`; keep `:` vs `.` consistent |
| 24 | Prototypes | `class`/`prototype` chain, `instanceof` | `setmetatable` + `__index` | **Loud** | Standard `local C = {} C.__index = C` pattern; `instanceof` → an explicit `ClassName` field |
| 25 | Closures | lexical, capture by reference | identical | None | Direct port |
| 26 | `setTimeout`/`setInterval` | ms; returns a handle; `clearTimeout` | `task.delay(seconds, fn)` returns a thread; `task.cancel(thread)` | **Silent** — ms vs seconds is a 1000× error | `setTimeout(f, 250)` → `task.delay(0.25, f)` |
| 27 | `requestAnimationFrame` | per-frame callback with a DOMHighResTimeStamp | `RunService.PreRender` (client) / `Heartbeat` | **Silent** — rAF pauses in a background tab, Roblox does not | Do not drive the simulation from the frame event at all; see §10 |
| 28 | `Date.now()` | ms since epoch, **client clock** | `os.time()` (seconds), `os.clock()` (monotonic-ish CPU time), `DateTime.now()` | **Silent** — unit mismatch, and client clocks lie | Offline progress must use a *server* timestamp; never trust a client clock |
| 29 | Promises/`async` | microtask queue; `await` suspends | coroutines; yielding calls suspend implicitly | **Silent** — ordering differences around "resolved immediately" | `await p` → a direct yielding call; `Promise.all` → spawn N threads and join on a counter |
| 30 | Errors | `try/catch`, exceptions are values | `pcall`/`xpcall`, errors are values | **Loud** | `try { a } catch (e) { b }` → `local ok, e = pcall(a) if not ok then b end` |
| 31 | `0.1 + 0.2` | `0.30000000000000004` | **identical** — both are IEEE-754 binary64 | None | Direct port; this is one of the few places you get exact parity for free |
| 32 | `Number.MAX_SAFE_INTEGER` | `9007199254740991` (2^53−1); beyond it, integer equality lies | identical representation, same limit | **Silent** — but identically silent in both, so it *preserves* fidelity | Match the original's behaviour, including its bugs, unless the spec says otherwise |
| 33 | Numeric `for` with float step | `for (let x = 0; x < 1; x += 0.1)` accumulates error | `for x = 0, 1, 0.1 do` — Luau computes the trip count | **Silent** — different iteration counts | Port float-stepped loops as integer loops with a multiply |
| 34 | String concat in a loop | `+=` on strings is optimized by engines | `..` allocates every time | Performance, not correctness | `table.concat` or a `buffer` |
| 35 | Shadowing / globals | `var` hoists; undeclared assignment creates a global (non-strict) | undeclared assignment creates a global; `--!strict` + `local` everywhere catches it | **Silent** — a stray global is shared state | Turn on `--!strict`, ban implicit globals in lint |

---

## DOM→Roblox UI mapping table

| Web concept | Roblox equivalent | Notes and gotchas |
|-------------|-------------------|-------------------|
| `<div>` container | `Frame` | `BackgroundTransparency = 1` for a layout-only div |
| `<span>` / text node | `TextLabel` | No inline flow; each label is a box |
| `<button>` | `TextButton` / `ImageButton` | Fires `Activated`, `MouseButton1Click`, plus touch |
| `<img>` | `ImageLabel` | Source must be an uploaded `rbxassetid://` or an `EditableImage` `Content` |
| `<input type="text">` | `TextBox` | `FocusLost` gives `enterPressed` |
| `<progress>` / bar div | `Frame` with a child `Frame` sized by Scale | Animate with `TweenService` on `Size` |
| Box model: `width`/`height` | `Size = UDim2.new(scaleX, offsetX, scaleY, offsetY)` | Scale is "a percentage of the container's size"; Offset is "how many pixels" (`creator-docs`, `ui/position-and-size.md`) |
| `padding` | `UIPadding` (`PaddingTop/Bottom/Left/Right`, each a `UDim`) | Padding is a child instance, not a property |
| `margin` | **no equivalent** | Use `UIListLayout.Padding` for between-item spacing, or a wrapper `Frame` |
| `border` | `UIStroke` | `Thickness`, `Color`, `ApplyStrokeMode` |
| `border-radius` | `UICorner` | `CornerRadius` is a `UDim` (Scale + Offset) |
| `box-sizing: border-box` | implicit — `Size` is always the border box | `UIPadding` shrinks the *content* area, matching `border-box` |
| `display: flex` | `UIListLayout` | `FillDirection` = `Horizontal`/`Vertical` |
| `flex-direction` | `UIListLayout.FillDirection` | |
| `justify-content` | `UIListLayout.HorizontalFlex` / `VerticalFlex` (the axis matching `FillDirection`) | "specifies how to distribute extra horizontal space in the parent container" |
| `align-items` | `UIListLayout.ItemLineAlignment` | "defines the cross-directional alignment of siblings within a line"; `Stretch` ≈ `align-items: stretch` |
| `flex-wrap: wrap` | `UIListLayout.Wraps = true` | |
| `flex-grow` / `flex-shrink` | `UIFlexItem` on the child | `FlexMode` `Grow` = 1:0 ratio, `Shrink` = 0:1, `Fill` = 1:1, `Custom` enables `GrowRatio`/`ShrinkRatio` (`creator-docs`, `classes/UIFlexItem.yaml`) |
| `order` | `GuiObject.LayoutOrder` + `SortOrder = LayoutOrder` | Default `SortOrder` may be `Name` — set it explicitly |
| `display: grid` | `UIGridLayout` | Fixed `CellSize`/`CellPadding` only; no named areas, no `fr` units, no spanning |
| `position: absolute` | plain `Position` + `AnchorPoint` (no layout object on the parent) | `AnchorPoint` is "a fraction from 0 to 1, relative to the size of the object" |
| `top/left/right/bottom` | `Position` + `AnchorPoint` | `right: 0` → `AnchorPoint = Vector2.new(1,0)`, `Position = UDim2.new(1,0,0,0)` |
| `transform: translate(-50%,-50%)` | `AnchorPoint = Vector2.new(0.5, 0.5)` | The canonical centering idiom |
| `px` | `UDim.Offset` | Roblox offsets are in *screen pixels*, already DPI-scaled by the engine |
| `%` | `UDim.Scale` | |
| `em` / `rem` | **no equivalent** | Compute a pixel value from a base font size at build time, or drive it with `UIScale` |
| `vw` / `vh` | `Scale` against a root frame sized `UDim2.fromScale(1,1)` | |
| `min-width` / `max-width` | `UISizeConstraint` | `MinSize`/`MaxSize` in pixels |
| `aspect-ratio` | `UIAspectRatioConstraint` | |
| `z-index` | `GuiObject.ZIndex` | Set `ScreenGui.ZIndexBehavior = Sibling` to get CSS-like sibling stacking rather than global |
| `overflow: scroll` | `ScrollingFrame` | `CanvasSize`, or `AutomaticCanvasSize` to size from children; `CanvasPosition` is the current scroll offset in pixels |
| `overflow: hidden` | `ClipsDescendants = true` | |
| `transition` / `animation` | `TweenService:Create(instance, TweenInfo.new(...), {prop = target})` | Easing style/direction enums replace cubic-bezier; no keyframe timeline |
| `@keyframes` multi-step | chained tweens or a `RunService` driver | |
| `:hover` | `MouseEnter` / `MouseLeave` | Does not exist on touch — always provide a non-hover affordance |
| `:active` | `MouseButton1Down` / `Up`, or `GuiButton.Activated` | |
| `onclick` | `Activated` (preferred: covers mouse, touch and gamepad) | |
| `onchange` on an input | `TextBox.FocusLost` / `GetPropertyChangedSignal("Text")` | |
| `addEventListener` | `instance.Event:Connect(fn)` returning an `RBXScriptConnection` | Must `:Disconnect()`; there is no automatic GC of connections to live instances |
| `innerHTML` with markup | `TextLabel.RichText = true` and a subset of tags (`<b> <i> <u> <s> <font color size face family weight transparency> <stroke> <br/> <uppercase> <smallcaps>`) | Escape `<`, `>`, `&`, `"` , `'` in user/dynamic text or your formatting breaks (`creator-docs`, `ui/rich-text.md`) |
| `textContent` | `TextLabel.Text` | |
| `document.createElement` | `Instance.new("Frame")` | Prefer cloning a template from `ReplicatedStorage` |
| `<canvas>` 2D context | `EditableImage` + an `ImageLabel` | Pixel buffer work; see chapters 20 and 40 |
| CSS gradient | `UIGradient` | Linear only; `Color` is a `ColorSequence`, `Transparency` a `NumberSequence` |
| Sprite sheet + `background-position` | `ImageLabel.ImageRectOffset` / `ImageRectSize` | "the pixel offset (from the top-left) of the image area to be displayed"; a zero in either dimension of `ImageRectSize` shows the whole image |
| 9-slice background | `ScaleType = Slice` + `SliceCenter` | |
| `<table>` | `UIListLayout` of row `Frame`s, each with a `UIListLayout` of cells | No column auto-sizing |
| Web font (`@font-face`) | `TextLabel.FontFace = Font.new("rbxasset://fonts/families/....json", weight, style)` | Custom fonts must be uploaded as font-family assets |
| `title` attribute / tooltip | a manually positioned `Frame` shown on `MouseEnter` | |
| `localStorage` | `DataStoreService` (server) / `plr:SetAttribute` for ephemeral | See §14 |

---

## 1. The porting methodology

### 1.1 Inventory the original

Before a line of Luau is written, produce a written inventory. This is a
mechanical exercise and it should take one to three days for a mid-sized idle
game. Do it with grep and a spreadsheet, not from memory.

**State variables.** Every field that persists across a tick. For each one
record: name, type, initial value, unit, min/max observed, whether it is derived
(recomputable) or authoritative (must be saved), and the exact JS expression
that mutates it. Derived-vs-authoritative is the split that determines your save
schema. In a typical clicker this is 30–200 fields; if the original keeps them
on a single `game` object, dump `Object.keys(game)` at runtime and diff against
your list to catch the ones added dynamically.

**Formulas.** Every pure function from state to a number: production rates, cost
curves, multiplier stacking order, offline-progress integration, prestige gain,
RNG draws. Copy the JS expression verbatim into the inventory. Multiplier
*stacking order* matters and is usually implicit in the original's code order —
`(base * a) * b` and `base * (a * b)` differ in float64 once the values are not
powers of two, and an incremental game runs the multiplication millions of times.

**Content tables.** Buildings, upgrades, achievements, tiers, prestige layers.
For each: the identity key the original uses (index? string id? position in an
array?), and whether any logic depends on *order*. Array-position identity is
the single most dangerous thing you can carry across the 0-based/1-based
boundary; if the original saves "upgrade 7 is bought" as an index into an array,
you must decide once and document whether the port's `7` means the same upgrade.

**UI screens.** One row per screen/panel: what it displays, what it reads from
state, what it writes, update frequency, and whether it has any *logic* in it.
The last column is the important one: incremental games routinely bury a formula
in a render function.

**Save format.** Capture three real saves (new game, mid game, endgame). Record
the exact encoding chain — commonly `JSON.stringify` → `LZString` or
`btoa(unescape(encodeURIComponent(...)))` → `localStorage`. Write down the
version field and any migration code the original already has; that migration
code is a specification of the schema's history.

**Assets.** Every image, sprite sheet, font, sound, and — separately — every
piece of art that is *drawn in CSS* (gradients, border-radius chips, box-shadow
glows, pseudo-element icons) or delivered as SVG. The CSS and SVG entries are
work items, not asset entries; they have no Roblox equivalent (§13).

**Non-determinism.** Every use of `Math.random`, `Date.now`, `performance.now`,
and anything that reads the DOM for a measurement. Each one is a place where the
port cannot be verified against the original unless you make it deterministic
first (§15.1).

### 1.2 Build the behavioural spec

The inventory is a list of facts. The **behavioural spec** is the contract the
port must satisfy, and it is what the test suite asserts. It has four parts:

1. **The tick contract.** What is a tick? How long is it? Is the original
   fixed-step, variable-step, or accumulator-based? Does it clamp `dt`? What
   happens on a long pause? Write this as pseudocode, because it is the single
   most common place where a "faithful" port silently diverges: a web game
   driven by `requestAnimationFrame` gets a variable `dt` that is *capped by the
   browser* when the tab is backgrounded, while a Roblox `Heartbeat` keeps
   ticking. If the original accumulates fractional production per frame, the
   port must accumulate identically or it will drift.
2. **The formula catalogue.** Every formula from the inventory, restated as a
   pure function signature with its exact expression, plus the evaluation order
   of any multiplier chain.
3. **The invariants.** Statements that must hold at every tick regardless of
   input: currency never negative; total-spent + current-balance equals
   total-earned; prestige count is monotonic; no field is ever NaN. These become
   property tests (§15.3).
4. **The golden vectors.** The concrete input→output pairs extracted from the
   original (§15.1). This is the part that turns "we think it matches" into
   "CI says it matches."

### 1.3 Port the pure simulation first — the load-bearing decision

**The simulation must be a module that imports nothing from Roblox.** No
`game:GetService`, no `Instance`, no `RunService`, no `task.wait`, no
`Players.LocalPlayer`. It takes data in and returns data out. Everything about
verifying this port depends on that property, because it is what lets the
simulation run under Lune in CI (§15.5) at thousands of times real speed, with
no engine, no renderer, and no player.

The rule to enforce in code review: *if a file in `sim/` contains the string
`game`, `Instance`, `task.`, `os.time`, `RunService` or `math.random`, it is a
bug.* Time comes in as a parameter. Randomness comes in as an injected seeded
generator. Both are then controllable by the test harness.

Concretely, the simulation exposes:

```lua
-- sim/init.luau
export type State = { ... }          -- plain data, JSON-serializable
export type Config = { ... }         -- content tables, frozen
export type Event  = { kind: string, ... }

local Sim = {}

function Sim.newState(config: Config, seed: number): State
function Sim.step(state: State, config: Config, dt: number): State
function Sim.apply(state: State, config: Config, event: Event): (State, boolean, string?)
function Sim.derive(state: State, config: Config): Derived   -- pure, cached per tick
function Sim.fastForward(state, config, elapsed: number): State

return Sim
```

Two design notes that matter for fidelity:

- **`step` should be pure-ish.** Either return a new table, or mutate in place
  and document it — but pick one and never mix. Returning a new table each tick
  allocates; for a 30 Hz simulation with a few hundred fields that is fine, and
  the debuggability is worth it. If profiling says otherwise, mutate in place and
  add a `Sim.clone(state)` used by the harness for snapshots.
- **`apply` returns success plus a reason.** All player actions — buy, prestige,
  claim — go through it. The UI never mutates state directly, and neither does
  the network layer. This gives you one place to validate, one place to log, and
  one surface for the golden vectors to exercise.

### 1.4 Recommended module layout

```
src/
  sim/                     -- PURE. No Roblox API. Runs under Lune.
    init.luau              -- the Sim interface above
    state.luau             -- State type, newState, clone, invariants()
    formulas.luau          -- every formula from the spec, one function each
    content/
      buildings.luau       -- content tables, table.freeze'd
      upgrades.luau
      achievements.luau
      prestige.luau
    bignum.luau            -- big-number facade (§11) — the ONLY bignum import
    rng.luau               -- seeded PRNG, explicitly constructed, never global
    jscompat.luau          -- jsRound, jsMod, jsTrunc, toI32, truthy helpers (§2)
    save/
      schema.luau          -- version, field list, defaults
      serialize.luau       -- State -> plain table
      deserialize.luau     -- plain table -> State, with validation + clamping
      migrate.luau         -- v1 -> v2 -> ... -> current
      importWeb.luau       -- the original web save format -> current (§14)

  shared/                  -- Roblox-aware but side-effect free
    remotes.luau
    types.luau

  server/
    init.server.luau       -- owns the authoritative Sim, drives the tick
    datastore.luau
    validate.luau          -- thin: delegates to sim/save/deserialize

  client/
    init.client.luau
    ui/
      app.luau             -- builds the tree, subscribes to state
      components/          -- one file per screen from the inventory
      theme.luau           -- the CSS variables, ported
      format.luau          -- number formatting (ported from the original!)
    fx/                    -- tweens, particles, sound — presentation only

  tests/                   -- runs under Lune
    golden/                -- the extracted vectors (JSON)
    harness.luau
    formulas.spec.luau
    snapshots.spec.luau
    properties.spec.luau
    fastforward.spec.luau
    saves.spec.luau
```

The boundary that matters: **`sim/` has no upward dependencies.** `server/` and
`client/` require `sim/`; `sim/` requires nothing outside itself. Enforce it with
a lint rule or a test that greps the tree — it is worth the ten lines.

### 1.5 Order of work

| Stage | Output | Gate before proceeding |
|-------|--------|------------------------|
| 0 | Inventory + behavioural spec | Spec reviewed by whoever knows the original best |
| 1 | Golden-vector extraction harness in the *original* | Vectors regenerate byte-identically twice in a row |
| 2 | `sim/` ported, no UI | Formula vectors pass; snapshot diff at tick 1/10/100/10k passes |
| 3 | Save layer | Round-trip test passes; all three captured real saves import |
| 4 | Server tick + DataStore | Fast-forward over a simulated year matches; no NaN |
| 5 | UI skeleton (correct data, ugly) | Every screen reads the same numbers the harness prints |
| 6 | Assets uploaded and wired | All asset ids resolve; nothing still in moderation |
| 7 | Presentation (tweens, sound, juice) | No presentation code touches `sim/` |
| 8 | Live-ops, analytics, monetization | Out of scope here; see chapter 51 |

Stage 1 before stage 2 is not negotiable. If you port first and extract vectors
later, you will unconsciously write vectors that match the port.

---

## 2. Truthiness — the single biggest source of ported-logic bugs

JavaScript's falsy set is `false`, `0`, `-0`, `0n`, `""`, `null`, `undefined`,
`NaN` and `document.all`
([MDN, *Truthy*](https://github.com/mdn/content/blob/main/files/en-us/glossary/truthy/index.md)).
Luau's falsy set is `false` and `nil`. That is the whole difference, and it is
enough to break an incremental game in a dozen places, because incremental games
are made of counts that are legitimately zero.

Roblox's own documentation calls this out directly: "If a value isn't `false` or
`nil`, Luau evaluates it as `true` ... Unlike many other languages, Luau
considers both zero and the empty string as `true`"
(`creator-docs`, `content/en-us/luau/booleans.md`, and again in
`luau/operators.md`). And the `not` examples are explicit:

```lua
print(not "text") -- false
print(not 0)      -- false
```

### 2.1 The four shapes that break

**Shape 1 — the zero guard.**

```js
// original
if (player.gems) { spendGems(); }        // skipped when gems === 0
```

```lua
-- WRONG: runs when gems == 0
if player.gems then spendGems() end
-- RIGHT
if player.gems ~= 0 then spendGems() end
```

**Shape 2 — the `||` default.** This is the one that hides best, because it also
*fixes* a latent bug in the original — and a fix is a divergence.

```js
const interval = config.interval || 5;   // config.interval === 0 yields 5
```

```lua
local interval = config.interval or 5    -- config.interval == 0 yields 0
```

If `0` is a meaningful value for `interval`, the JS was wrong and the Luau is
right, and the port now behaves differently from the golden master. Decide
explicitly, write it in the spec, and if you are preserving the original
behaviour, say so in a comment with the reason. A `jscompat` helper makes the
intent legible:

```lua
-- sim/jscompat.luau
local M = {}

-- true exactly when JS would consider v truthy
function M.truthy(v: any): boolean
	if v == nil or v == false then return false end
	if v == 0 then return false end          -- covers -0 too: -0 == 0 in Luau
	if v == "" then return false end
	if v ~= v then return false end          -- NaN
	return true
end

-- exactly `a || b` in JS
function M.or_(a: any, b: any): any
	return M.truthy(a) and a or b
end

-- exactly `a ?? b` in JS (nullish coalescing: only null/undefined fall through)
function M.nullish(a: any, b: any): any
	if a == nil then return b end
	return a
end

return M
```

Note that `?? ` (nullish coalescing) maps *exactly* onto Luau's `or` for the
`nil` case but not for `false`: `false ?? 1` is `false` in JS, while
`false or 1` is `1` in Luau. If the original uses `??` on a boolean, use
`M.nullish`.

**Shape 3 — the empty-string guard.**

```js
if (save.playerName) { greet(save.playerName); }
```

An empty name skips the greet in JS and triggers it in Luau. In save-loading
code this becomes a validation hole.

**Shape 4 — the NaN sentinel.** Some incremental games use `NaN` as "not yet
computed". In JS, `if (cache)` is false for `NaN`. In Luau, `NaN` is truthy
(only `nil`/`false` are falsy). Port `NaN` sentinels to `nil` and check
`== nil`, or keep them and check `v ~= v`.

### 2.2 How to find them all

Grep the original for the shapes rather than reading every line:

```bash
# bare truthiness checks
rg -n 'if\s*\([A-Za-z_$][\w.$\[\]]*\)\s*[{\n]' src/
# || defaults
rg -n '\|\|\s*[0-9"'"'"'\[{]' src/
# ternaries on a bare value
rg -n '\b[A-Za-z_$][\w.$]*\s*\?\s*' src/ | rg -v '[=<>!]='
# negations
rg -n '!\s*[A-Za-z_$][\w.$\[\]]*\s*[)&|]' src/
```

Then, for each hit, ask one question: *can this value be `0`, `""` or `NaN` in
normal play?* If yes, it is a port bug. Record the decision in the inventory
spreadsheet so the reviewer can check it.

### 2.3 The strict-mode assist

Turn on `--!strict` at the top of every `sim/` file. Luau's type checker will not
catch truthiness differences (both `number` and `string` are valid conditions),
but it *will* catch the adjacent class of bugs — passing `nil` where a number is
expected, forgetting a return, misspelling a field — which otherwise get blamed
on the truthiness work. Types are also how you document that a field is
`number?` rather than `number`, which is the real signal about whether a
`nil` check is needed at all.

---

## 3. Indexing: 0-based to 1-based

Luau arrays conventionally start at index 1: "you can also use a numeric `for`
loop from `1` to the length of the array (`#array`)"
(`creator-docs`, `luau/tables.md`). Nothing *prevents* a 0-based table, and that
is precisely the trap — a 0-based Luau table works fine until something calls
`#t`, `ipairs`, `table.insert`, `table.sort` or `table.concat` on it, all of
which start at 1 and will silently skip element `0`.

**Rule: convert to 1-based at the boundary, once, and never keep a 0-based Luau
table.** The conversion points are (a) content tables, (b) save files, and
(c) any index stored in state.

### 3.1 Loop translation

| JavaScript | Luau |
|---|---|
| `for (let i = 0; i < n; i++)` | `for i = 1, n do` |
| `for (let i = 0; i <= n; i++)` | `for i = 1, n + 1 do` |
| `for (let i = n - 1; i >= 0; i--)` | `for i = n, 1, -1 do` |
| `for (const x of arr)` | `for _, x in arr do` (or `ipairs(arr)`) |
| `for (const k in obj)` | `for k in obj do` (or `pairs(obj)`) — **order differs** |
| `arr.forEach((x, i) => …)` | `for i, x in arr do … end` — `i` is now 1-based |

The `for (const k in obj)` case deserves attention: JS object key enumeration
order is specified (integer-like keys ascending, then string keys in insertion
order), while Luau's `pairs` order is hash order and is **not** stable across
runs or across versions. If the original iterates an object and the *order*
affects the result — applying upgrades, accumulating floats, drawing RNG — you
must port it to an explicit ordered array of keys. This is a real source of
non-reproducible drift, and it is invisible until a float sum comes out different
on the third decimal.

### 3.2 Content tables

Keep the original's identity keys, not its positions:

```lua
-- content/buildings.luau
-- `order` preserves the original array order for display and for any
-- order-dependent logic. `byId` is the identity map. Nothing depends on
-- the numeric position of an entry in `order`.
local Buildings = {}

Buildings.byId = {
	cursor  = { id = "cursor",  baseCost = 15,    baseCps = 0.1,  costMul = 1.15 },
	grandma = { id = "grandma", baseCost = 100,   baseCps = 1,    costMul = 1.15 },
	farm    = { id = "farm",    baseCost = 1100,  baseCps = 8,    costMul = 1.15 },
}

Buildings.order = { "cursor", "grandma", "farm" }

-- the original's numeric ids, for save import only (§14)
Buildings.legacyIndexToId = { [0] = "cursor", [1] = "grandma", [2] = "farm" }

return table.freeze(Buildings)
```

`Buildings.legacyIndexToId` is deliberately 0-based, because that is what the
original's save file contains. Marking it `legacy` and confining it to the import
path keeps exactly one 0-based table in the codebase, in the one place it
belongs.

`table.freeze` on content tables is cheap insurance: content is read-only by
definition, and a frozen table turns "something mutated the config at runtime"
from a three-day debugging session into an immediate error.

---

## 4. Array methods

Luau's `table` library has `insert`, `remove`, `sort`, `concat`, `find`, `move`,
`clone`, `create`, `pack`, `unpack`, `freeze` and `isfrozen`. It does not have
`map`, `filter`, `reduce`, `slice`, `splice`, `some`, `every`, `includes`,
`indexOf`, `flat`, or `reverse`. Write one small module and use it consistently
— inlining the loops is fine for performance but makes the port hard to diff
against the original.

```lua
-- sim/arr.luau  (1-based throughout)
local Arr = {}

function Arr.map<T, U>(t: {T}, f: (T, number) -> U): {U}
	local out = table.create(#t)
	for i, v in t do out[i] = f(v, i) end
	return out
end

function Arr.filter<T>(t: {T}, f: (T, number) -> boolean): {T}
	local out, n = {}, 0
	for i, v in t do
		if f(v, i) then n += 1; out[n] = v end
	end
	return out
end

-- NOTE: JS reduce with no initial value uses t[0] as the seed and starts at 1.
-- This version requires an explicit seed. Port `arr.reduce(f)` (no seed) as
-- Arr.reduce(Arr.slice(t, 2), f, t[1]) and assert #t > 0 like JS does.
function Arr.reduce<T, A>(t: {T}, f: (A, T, number) -> A, seed: A): A
	local acc = seed
	for i, v in t do acc = f(acc, v, i) end
	return acc
end

-- JS: arr.slice(begin, end) is 0-based, end-exclusive.
-- This is 1-based, end-INCLUSIVE, matching string.sub and table.move.
function Arr.slice<T>(t: {T}, i: number, j: number?): {T}
	local n = #t
	local last = j or n
	if i < 1 then i = 1 end
	if last > n then last = n end
	if last < i then return {} end
	return table.move(t, i, last, 1, table.create(last - i + 1))
end

function Arr.indexOf<T>(t: {T}, v: T): number?   -- nil, not -1
	return table.find(t, v)
end

function Arr.includes<T>(t: {T}, v: T): boolean
	return table.find(t, v) ~= nil
end

function Arr.some<T>(t: {T}, f: (T, number) -> boolean): boolean
	for i, v in t do if f(v, i) then return true end end
	return false
end

function Arr.every<T>(t: {T}, f: (T, number) -> boolean): boolean
	for i, v in t do if not f(v, i) then return false end end
	return true
end

function Arr.reverse<T>(t: {T}): {T}
	local n = #t
	local out = table.create(n)
	for i = 1, n do out[n - i + 1] = t[i] end
	return out
end

return Arr
```

Two translations that are not one-liners:

**`indexOf` returns `-1`, `table.find` returns `nil`.** Every
`if (arr.indexOf(x) !== -1)` becomes `if table.find(t, x) ~= nil`, and every
`arr.indexOf(x) >= 0` likewise. Getting this wrong is loud (`-1` compared to
`nil` errors) which is the good case; getting `if (arr.indexOf(x))` wrong is
silent, because `-1` is truthy in JS and `nil` is falsy in Luau — *this specific
line reverses meaning*.

**`splice` does two jobs.** As a remover, `arr.splice(i, n)` is `n` calls to
`table.remove(t, i)` (or one `table.move`). As an inserter,
`arr.splice(i, 0, x)` is `table.insert(t, i, x)`. As both, write it explicitly.
Remember the index shift: `arr.splice(2, 1)` removes the third element in JS and
`table.remove(t, 2)` removes the second in Luau.

### 4.1 `table.sort`: stability and the comparator contract

Two differences, both of which can change results.

**Stability.** `Array.prototype.sort` is stable as of ES2019 — "the
specification dictates that `Array.prototype.sort` is stable"
([MDN, *Array.prototype.sort*](https://github.com/mdn/content/blob/main/files/en-us/web/javascript/reference/global_objects/array/sort/index.md)).
Luau's `table.sort` is a quicksort with a heapsort fallback
(`VM/src/ltablib.cpp`) and is **not** stable. If your shop list sorts by price
and two items cost the same, JS keeps the original order and Luau does not. Fix
it in the comparator, not by hoping:

```lua
table.sort(items, function(a, b)
	if a.price ~= b.price then
		return a.price < b.price
	end
	return a.index < b.index      -- deterministic tiebreak, matches JS stability
end)
```

**The contract is enforced.** Luau's comparator must be a *strict* weak
ordering. The engine raises `invalid order function for sorting` if it detects
`comp(a,b)` and `comp(b,a)` both true, and `table modified during sorting` if
the comparator changes the array's size (both literal strings from
`VM/src/ltablib.cpp`; the documented behaviour is "The error `invalid order
function for sorting` is thrown if both `comp(a, b)` and `comp(b, a)` return
`true`", `creator-docs`, `libraries/table.yaml`). JavaScript, by contrast,
tolerates a sloppy comparator and just produces a weird order.

So the mechanical translation of a JS numeric comparator is:

```js
arr.sort((a, b) => a.value - b.value);
```

```lua
table.sort(arr, function(a, b) return a.value < b.value end)
```

and **never** `<=`. A `<=` comparator makes `comp(a,a)` true, which trips the
check and errors at runtime on a table large enough to reach the quicksort path.
This is the most common way a ported sort blows up in production and not in
testing, because small arrays take the insertion-sort path where the check is not
reached. **[unverified]** — the exact size threshold at which the check fires is
an implementation detail; do not rely on small arrays being safe.

One more subtlety: if the comparator reads a value that can be `NaN`
(a big-number `toNumber()` overflowing, say), `NaN < x` and `x < NaN` are both
false, which is a valid strict weak ordering only by accident, and the resulting
order is arbitrary. Sanitize before sorting.

---

## 5. `undefined`, `null`, `nil`, and holes

JavaScript has two absent values. `undefined` means "never assigned / no such
property"; `null` means "explicitly nothing". `undefined == null` is `true` but
`undefined === null` is `false`. Luau has one: `nil`.

Most of the time the collapse is harmless. It is not harmless when the original
uses `null` as a *third state*:

```js
lastPrestigeAt: undefined   // never prestiged
lastPrestigeAt: null        // prestige reset was cleared by a migration
lastPrestigeAt: 1690000000  // a timestamp
```

If you find this, model it explicitly rather than hoping. Two options, in order
of preference:

```lua
-- (a) a discriminated field — always preferred, survives JSON
lastPrestige = { state = "never" }                  -- | "cleared" | "at"
lastPrestige = { state = "at", t = 1690000000 }

-- (b) a sentinel, if you must keep the field shape
local NULL = newproxy(false)   -- unique, not equal to anything else
```

Option (b) does **not** survive `JSONEncode`, so if the field is persisted you
have to map it at the save boundary anyway — which is option (a) with extra
steps.

### 5.1 Sparse arrays and `#t`

A JS array can have holes: `const a = [1, , 3]` has `a.length === 3` with index
`1` absent. `Array.prototype.sort` even documents that it "preserves empty slots"
and moves them to the end (MDN).

Luau has nothing equivalent. A table with a `nil` in the middle of its array part
has an **undefined length**. From `VM/src/ltable.cpp`:

> Try to find a boundary in table `t`. A `boundary` is an integer index such that
> `t[i]` is non-nil and `t[i+1]` is nil (and 0 if `t[1]` is nil).

`luaH_getn` finds *a* boundary via a branchless binary search over the array
part, with a cached-boundary fast path. For `{1, nil, 3}` both `1` and `3` are
valid answers, and which one you get depends on the table's internal array size,
its allocation history and whether a boundary was cached. It is not random, but
it is not something you can reason about from the source code of your game.

Consequences for the port:

- **Never write `nil` into an array.** Use `table.remove` (which shifts), or
  overwrite with a sentinel, or switch to a dictionary keyed by id plus an
  explicit `count`.
- **`ipairs` stops at the first `nil`**; the generalized `for _, v in t` iterator
  and `pairs` do not. Mixing them over a possibly-holed table gives different
  element counts in different places in your code.
- **A save round-trip can create holes.** `JSONDecode` of `[1, null, 3]` produces
  a table where index 2 is `nil`. Validate array fields on load by rebuilding
  them densely rather than trusting them.

Practical rule for state design: **the simulation's `State` contains no arrays
with gaps and no `nil` values at all.** Absent means "the key is not present in a
dictionary", never "there is a hole in a list". This one rule removes an entire
class of divergence, makes `#` meaningful everywhere, and makes the JSON round
trip total.

---

## 6. Number semantics

Both languages use IEEE-754 binary64 for all numbers. Roblox documents the number
type as "a double-precision (64-bit) floating-point number ... around 15 digits
of precision" and notes that "Luau doesn't distinguish between integers and
numbers" (`creator-docs`, `luau/numbers.md`). That means the good news first:

- `0.1 + 0.2` is `0.30000000000000004` in both. Identical.
- Accumulated float error in a per-tick production sum is identical, *provided
  the operation order is identical*.
- `Number.MAX_SAFE_INTEGER` (`9007199254740991`, 2^53−1) is the same boundary in
  Luau. Past it, `x + 1 == x + 2` in both languages
  ([MDN, *Number.MAX_SAFE_INTEGER*](https://github.com/mdn/content/blob/main/files/en-us/web/javascript/reference/global_objects/number/max_safe_integer/index.md)).
  An idle game that counts "total clicks" past 2^53 is already lying in the
  original; the port should lie identically, not "fix" it.
- Division by zero gives `inf`/`-inf`/`nan` in both, with no exception.

Now the divergences.

### 6.1 `%` — different signs, a real bug source

JS `%` is a **remainder**: "It always takes the sign of the dividend"
([MDN, *Remainder*](https://github.com/mdn/content/blob/main/files/en-us/web/javascript/reference/operators/remainder/index.md)),
so `-13 % 5 === -3` and `-4 % 2 === -0`.

Luau `%` is a **floored modulo**. From `VM/src/lnumutils.h`:

```c
inline double luai_nummod(double a, double b)
{
    return a - floor(a / b) * b;
}
```

So `-13 % 5 == 2`. MDN even names the distinction: "the modulo result always has
the same sign as the *divisor*, while the remainder has the same sign as the
*dividend*, which can make them differ by one unit of `d`."

| Expression | JS | Luau |
|---|---|---|
| `13 % 5` | `3` | `3` |
| `-13 % 5` | `-3` | `2` |
| `13 % -5` | `3` | `-2` |
| `-13 % -5` | `-3` | `-3` |

Where this bites in an incremental game: cycle phase (`tick % period` where tick
can go negative after an offline-time correction), wrap-around tier indices,
"every Nth" triggers computed from a signed delta, and hash functions ported from
the original's RNG.

Translation:

```lua
-- exactly JS `a % b`
function M.jsMod(a: number, b: number): number
	return math.fmod(a, b)   -- "rounds the quotient towards zero"
end
```

`math.fmod` is documented as returning "the remainder of the division of `x` by
`y` that rounds the quotient towards zero" (`creator-docs`,
`libraries/math.yaml`) — i.e. C's `fmod`, i.e. JS's `%`. Use `%` only where you
have confirmed both operands are non-negative.

### 6.2 Integer division and truncation

`Math.floor(a / b)` → `a // b` or `math.floor(a / b)`. Luau's floor division is
documented with a negative example: `-10 // 4 = -3`
(`creator-docs`, `luau/operators.md`) — wait, that is Roblox's own table, and it
is what `floor(-2.5) = -3` gives. Consistent.

But `(a / b) | 0` and `Math.trunc(a / b)` truncate toward zero, which is a
*different* function on negatives:

```lua
function M.jsTrunc(x: number): number
	return x >= 0 and math.floor(x) or math.ceil(x)
	-- or: local i = math.modf(x) ; return i
end
```

`math.modf` "returns two numbers: the integral part of `x` and the fractional
part of `x`" and is the cleanest spelling.

### 6.3 Rounding

This one is documented on both sides and they disagree.

MDN, `Math.round`: "If the fractional portion is exactly 0.5, the argument is
rounded to the next integer in the direction of +∞", with the explicit note:
"This differs from many languages' `round()` functions, which often round
half-increments *away from zero*, giving a different result in the case of
negative numbers with a fractional part of exactly 0.5." Worked examples:
`Math.round(-20.5) === -20`, `Math.round(20.5) === 21`, `Math.round(-0.1) === -0`.

Roblox, `math.round`: "For values like `0.5` that are equidistant to two
integers, the value with the greater difference between it and zero is chosen.
In other words, the function 'rounds away from zero' such that `0.5` rounds to
`1` and `-0.5` rounds to `-1`."

| x | `Math.round(x)` | `math.round(x)` |
|---|---|---|
| `20.5` | `21` | `21` |
| `-20.5` | `-20` | **`-21`** |
| `-0.5` | `-0` | **`-1`** |
| `-2.5` | `-2` | **`-3`** |

Translation:

```lua
function M.jsRound(x: number): number
	return math.floor(x + 0.5)
end
```

MDN notes the one case where this differs from `Math.round`: "When `x` is -0, or
-0.5 ≤ x < 0, `Math.round(x)` returns -0, while `Math.floor(x + 0.5)` returns
0." Since `-0 == 0` in Luau (`creator-docs`, `luau/numbers.md`: "In Luau, the
number `-0` is equivalent to `0`"), this difference is unobservable in Luau
arithmetic — but it *is* observable in the sign of a formatted string. If the
original ever prints a rounded negative-fractional value, check it.

`toFixed` has no Luau equivalent either. `string.format("%.2f", x)` uses C's
round-half-to-even on the exact binary value, while JS `toFixed` is specified
over the decimal expansion. They agree on the overwhelming majority of inputs and
disagree on exact ties. For displayed numbers this rarely matters; for a number
that is *parsed back* into state, port the formatter explicitly.

### 6.4 Bitwise

JS `&`, `|`, `^`, `~`, `<<`, `>>` "convert both operands to 32-bit integers" —
**signed** — and return a signed result (MDN, *Bitwise AND*). `>>>` is the
unsigned right shift.

Luau has no bitwise operators; `bit32` "treats numbers as unsigned 32-bit
integers; numbers will be converted to this before being used"
(`creator-docs`, `libraries/bit32.yaml`).

| JS | Luau | Sign note |
|---|---|---|
| `a & b` | `bit32.band(a, b)` | result is unsigned; convert if the JS result could be negative |
| `a \| b` | `bit32.bor(a, b)` | same |
| `a ^ b` | `bit32.bxor(a, b)` | same |
| `~a` | `bit32.bnot(a)` | `~0` is `-1` in JS, `4294967295` in Luau |
| `a << b` | `bit32.lshift(a, b)` | |
| `a >> b` | `bit32.arshift(a, b)` | arithmetic shift: "Vacant bits on the left are filled with copies of the higher bit of `x`" |
| `a >>> b` | `bit32.rshift(a, b)` | logical shift |
| `x \| 0` (truncate idiom) | `M.jsTrunc(x)` — **not** a bit op | `\| 0` also wraps to 32 bits, which `jsTrunc` does not; if the original relies on the wrap, use `M.toI32(bit32.bor(x, 0))` |

```lua
function M.toI32(u: number): number          -- unsigned bit32 result -> signed JS result
	return u >= 0x80000000 and u - 0x100000000 or u
end
```

The most common place this matters in an incremental port is a hand-rolled PRNG
(xorshift, mulberry32, LCG) copied from the original. Those are *built* out of
32-bit wraparound, and a sign mismatch changes the entire random stream — which
changes every drop, every crit, every procedural name. Port the PRNG first and
golden-test it on its own (§15.2) before anything that consumes it.

---

## 7. Strings and patterns

`string.sub` is 1-based and **end-inclusive**; `String.prototype.slice` is
0-based and end-exclusive.

| JavaScript | Luau |
|---|---|
| `s.length` | `#s` or `string.len(s)` |
| `s[i]` | `string.sub(s, i + 1, i + 1)` |
| `s.slice(a, b)` | `string.sub(s, a + 1, b)` |
| `s.slice(-3)` | `string.sub(s, -3)` — negative indices work the same |
| `s.charCodeAt(i)` | `string.byte(s, i + 1)` |
| `String.fromCharCode(n)` | `string.char(n)` |
| `s.toUpperCase()` | `string.upper(s)` |
| `s.indexOf(sub)` | `string.find(s, sub, 1, true)` → returns `nil` or a **1-based** start |
| `s.includes(sub)` | `string.find(s, sub, 1, true) ~= nil` |
| `s.startsWith(p)` | `string.sub(s, 1, #p) == p` |
| `s.repeat(n)` | `string.rep(s, n)` |
| `s.trim()` | `(string.gsub(s, "^%s*(.-)%s*$", "%1"))` — note the parens to drop the count |
| `s.padStart(n, "0")` | `string.rep("0", math.max(0, n - #s)) .. s` |
| `s.split(",")` | see below |
| `` `${a} and ${b}` `` | `` `{a} and {b}` `` (Luau string interpolation) or `string.format` |
| `arr.join(",")` | `table.concat(arr, ",")` |

**The fourth argument to `string.find` is not optional in spirit.** `string.find`
treats its pattern as a *pattern* unless you pass `true` for `plain`. Searching
for a literal `"1.5x"` without `plain = true` matches `"145x"` too, because `.`
is a wildcard. Every `indexOf` port must pass `true`.

### 7.1 `split`

```lua
-- non-empty fields only (like s.split(",").filter(Boolean))
local function splitNonEmpty(s: string, sep: string): {string}
	local out = {}
	for part in string.gmatch(s, "([^" .. sep .. "]+)") do
		table.insert(out, part)
	end
	return out
end

-- exact JS semantics: preserves empty fields, so "a,,b" -> {"a","","b"}
-- and ",".split(",") -> {"", ""}
local function split(s: string, sep: string): {string}
	local out, start = {}, 1
	while true do
		local i, j = string.find(s, sep, start, true)
		if not i then
			table.insert(out, string.sub(s, start))
			return out
		end
		table.insert(out, string.sub(s, start, i - 1))
		start = j + 1
	end
end
```

Use the exact version in save parsing. The `gmatch` version silently drops empty
fields, and a save format with an empty field is exactly where that bites.

### 7.2 Lua patterns are not regular expressions

This is a language difference, not an API difference. Lua patterns have:

- character classes `%a %d %s %w %l %u %p %c %x` and their negations `%A %D …`
- sets `[abc]`, ranges `[a-z]`, negated sets `[^abc]`
- quantifiers `*` (greedy 0+), `+` (greedy 1+), `-` (**lazy** 0+), `?` (0 or 1)
- anchors `^` and `$`
- captures `(...)`, position captures `()`, backreferences `%1`–`%9`
- `%b()` balanced match and `%f[set]` frontier

and they do **not** have: alternation (`|`), grouping for quantification
(`(ab)+`), counted repetition (`{2,5}`), lookahead/lookbehind, non-greedy `+?`,
named captures, or Unicode classes. The 12 magic characters are
``^ $ ( ) % . [ ] * + - ?`` (`creator-docs`, `luau/strings.md`), escaped with
`%`, and note that `-` is magic (it is the lazy quantifier) while `/` and `{`
are not.

| Regex | Lua pattern | Verdict |
|---|---|---|
| `/\d+/` | `"%d+"` | direct |
| `/\w+/` | `"%w+"` | close — Lua `%w` excludes `_`, JS `\w` includes it; use `"[%w_]+"` |
| `/\s*$/` | `"%s*$"` | direct |
| `/^v(\d+)$/` | `"^v(%d+)$"` | direct |
| `/[A-Za-z_][A-Za-z0-9_]*/` | `"[%a_][%w_]*"` | direct |
| `/.+?,/` | `".-,"` | direct (`-` is the lazy star) |
| `/\d{2,4}/` | none | rewrite: match `"%d+"` and check the length |
| `/(foo\|bar)/` | none | rewrite: two `string.find` calls, or a loop over alternatives |
| `/(ab)+/` | none | rewrite as a loop |
| `/(?<=x)y/` | none | rewrite with an explicit index check |
| `/\bword\b/` | `"%f[%w]word%f[%W]"` | the frontier pattern is the idiom, and it is not obvious |
| `s.replace(/a/g, "b")` | `string.gsub(s, "a", "b")` — `gsub` is global by default | note `gsub` returns **two** values; wrap in parens when using it as an expression |

When the original uses a regex you cannot express, do not approximate. Either
rewrite the logic (usually the right answer — most game regexes are parsing a
save string or a number format, and hand-written parsing is clearer anyway), or
vendor a real regex engine. Under Lune you have `@lune/regex`, which is useful
for the *extraction tooling* even though it is not available in-engine.

One more trap: `gsub`'s replacement string treats `%` specially (`%1` is a
capture, `%%` is a literal `%`). Any replacement containing a percent sign — a
number formatter, say — must escape it.

---

## 8. Objects, prototypes, `this`, and `===`

`===` → `==`. Luau's `==` never coerces, so it *is* `===`. Port JS `==` only
after reading what the coercion was doing; in game code it is almost always
either `x == null` (meaning "null or undefined", which is `x == nil` in Luau) or
a latent bug.

Prototype OOP maps onto metatables mechanically:

```js
class Building {
  constructor(def, owned) { this.def = def; this.owned = owned; }
  cost() { return this.def.baseCost * Math.pow(this.def.costMul, this.owned); }
  static fromSave(def, s) { return new Building(def, s.owned); }
}
```

```lua
local Building = {}
Building.__index = Building

function Building.new(def, owned)
	return setmetatable({ def = def, owned = owned }, Building)
end

function Building:cost()            -- `self` is the implicit first parameter
	return self.def.baseCost * self.def.costMul ^ self.owned
end

function Building.fromSave(def, s)  -- `.` not `:` — a static
	return Building.new(def, s.owned)
end
```

| JS | Luau |
|---|---|
| `class X { … }` | `local X = {} ; X.__index = X` |
| `new X(a)` | `X.new(a)` calling `setmetatable({}, X)` |
| `this` | `self`, the first parameter of a `:` method |
| `obj.method()` | `obj:method()` |
| `X.staticMethod()` | `X.staticMethod()` (defined with `.`) |
| `class Y extends X` | `setmetatable(Y, {__index = X})` plus `Y.__index = Y` |
| `super.m()` | `X.m(self, …)` |
| `x instanceof X` | `getmetatable(x) == X`, or an explicit `x.__class == "X"` field |
| `get`/`set` accessors | `__index`/`__newindex` functions |
| `toString()` | `__tostring` |
| `Symbol.iterator` | `__iter` |
| operator overloading (none) | `__add`, `__mul`, `__lt`, `__eq`, `__unm`, … |

**`this` is the real hazard, and it is a hazard in both directions.** In JS,
`const f = obj.method; f()` loses `this` (and in strict mode `this` is
`undefined`). Games work around it with `.bind(this)` or arrow functions in
constructors. In Luau, `local f = obj.method; f()` passes whatever the first
argument is as `self` — so `f(5)` silently sets `self = 5` and then errors
somewhere else, or worse, reads `5.owned` as `nil` and produces a wrong number.
Every callback you register must be wrapped:

```lua
button.Activated:Connect(function() controller:onBuy(id) end)
-- NOT: button.Activated:Connect(controller.onBuy)
```

Closures are identical in both languages — lexical scope, capture by reference,
upvalues shared between sibling closures. A closure-heavy original ports
directly, and closure-based "private state" needs no translation at all.
`--!strict` plus the `self` type annotation (`function Building.cost(self:
Building)`) catches most of the `.`/`:` mistakes at analysis time.

One Luau-only fact worth knowing: metatables are also how big-number libraries
give you `a + b` on `Decimal`-like values (§11). That means the *same expression
shape* as the JS `Decimal` code is often unavailable (JS has no operator
overloading, so the original is written as `a.plus(b)`), and you will be
tempted to "improve" it to `a + b`. Don't, during the port — keep the shape so
the diff against the original stays readable. Improve it after the gate is green.

---

## 9. JSON

`HttpService:JSONEncode` / `JSONDecode` replace `JSON.stringify` / `JSON.parse`.
Both are documented as usable "regardless of whether HTTP requests are enabled"
and are `thread_safety: Safe` (`creator-docs`, `classes/HttpService.yaml`).
Under Lune, the equivalent is `serde.encode("json", t)` /
`serde.decode("json", s)` — write a two-line shim so `sim/` code is identical in
both environments.

The documented encoding rules, verbatim from the reference YAML, and what each
one costs you:

| Rule (documented) | Consequence for a save schema |
|---|---|
| "Keys of the table must be either strings or numbers. If a table contains both, an array takes priority (string keys are ignored)." | **Silent data loss.** A table like `{[1]="a", name="x"}` loses `name`. Never mix. |
| "An empty Luau table (`{}`) generates an empty JSON array (e.g. `[]`)." | An empty dictionary round-trips as an array. `JSON.stringify({})` is `"{}"`. |
| "avoid `nil` values for any index" | A `nil` in the middle of an array truncates or holes it, per §5.1. |
| "Cyclic table references cause an error." | Loud, and fine — but shared sub-tables get *duplicated*, not shared, on decode. |
| "allows values such as `inf` and `nan` which are not valid JSON" | You can write a save that nothing else can read. `JSON.stringify(NaN)` emits `null`. |
| buffers up to 50 MiB encode to base64 "(and often compresses)" | A useful escape hatch for packed numeric state. |

Three rules that make the trap go away:

1. **Every table in the save schema is either a pure array (contiguous integer
   keys from 1) or a pure dictionary (string keys only). Never both, never
   empty-ambiguous.** Where the original has an object that can be empty, add a
   constant marker field (`{ _ = 1, … }`) or represent it as an array of
   `{k, v}` pairs.
2. **Sanitize before encoding.** Walk the table and assert every number `v`
   satisfies `v == v` (not NaN) and `v ~= math.huge and v ~= -math.huge`. A
   single `inf` from an overflowed multiplier poisons the save.
3. **Never compare serialized saves byte-for-byte.** `JSON.stringify` follows a
   specified key order for string keys (insertion order); Luau tables have no
   order and the encoder's output order is unspecified. Compare *decoded
   structures* with a deep-equal that is order-insensitive for dictionaries. This
   matters directly for the test harness (§15).

For the *import* direction (§14), `JSONDecode` gives you a Luau table where JSON
`null` became `nil` — which means a JSON object `{"a": null}` decodes to an empty
table, and a JSON array `[1, null, 3]` decodes to a table with a hole. Both are
things the original's save can legitimately contain. Handle them explicitly in
the importer, not in the simulation.

---

## 10. Time, scheduling and async

### 10.1 The mapping

| Web | Roblox | Notes |
|---|---|---|
| `setTimeout(f, ms)` | `task.delay(seconds, f)` | **ms → seconds.** Returns a thread; `task.cancel(thread)` is `clearTimeout`. "no throttling occurs: on the very same Heartbeat step in which enough time has passed, the function is guaranteed to be called" |
| `setTimeout(f, 0)` | `task.defer(f)` | "defers it until the end of the current resume point within the current frame" — closest to a macrotask |
| `queueMicrotask(f)` | `task.spawn(f)` | Runs **immediately**, synchronously, until it yields — closer to calling `f()` than to a microtask |
| `setInterval(f, ms)` | a loop in a `task.spawn`ed thread with `task.wait(s)`, or a `Heartbeat` connection with an accumulator | There is no interval primitive; build it |
| `clearInterval` | `connection:Disconnect()` or a flag the loop checks | |
| `requestAnimationFrame` | `RunService.PreRender` (client only) or `RunService.Heartbeat` | `Heartbeat` "fires every frame, after the physics simulation has completed" with a `deltaTime` argument |
| `performance.now()` | `os.clock()` | Monotonic-ish; use for durations, not wall time |
| `Date.now()` | `os.time()` (seconds, UTC) / `DateTime.now()` | **Seconds, not ms** |
| `document.hidden` / visibility change | no equivalent | Roblox keeps running |
| `await` | any yielding call | |
| `Promise.all` | spawn N threads, join on a counter or a `BindableEvent` | |

`task.wait(t)` "yields the current thread until the given duration has elapsed,
then resumes the thread on the next Heartbeat step" and returns the actual
elapsed time. With no argument it is equivalent to `RunService.Heartbeat:Wait()`.

### 10.2 The tick, and why you should not use the frame event

The most common fidelity bug in a web→Roblox port is driving the simulation
directly off the frame event, because that is what the original did with
`requestAnimationFrame`. Three things differ:

- **rAF stops when the tab is hidden.** `Heartbeat` does not. A web player who
  tabs away accumulates *offline* progress through the game's offline path; a
  Roblox player accumulates *online* progress through the tick path. If those two
  paths differ at all — and they almost always do, because offline progress is
  usually rate-capped — the port diverges from the original for a behaviour the
  player does constantly.
- **`dt` distributions differ.** Browser rAF is vsync-locked and capped;
  `Heartbeat` `deltaTime` can spike arbitrarily on a loading hitch.
- **Float accumulation depends on step count.** Summing `rate * dt` over 3600
  small steps and over 60 large steps gives different last-digit results, and in
  a game that runs for months, "different last digit" compounds.

The fix is the same one that makes the simulation testable: **a fixed-step
accumulator, with the step size written into the behavioural spec.**

```lua
-- server/init.server.luau
local STEP = 1 / 20            -- must match the spec and the harness exactly
local MAX_CATCHUP = 5          -- seconds of real time processed per frame, max

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += math.min(dt, MAX_CATCHUP)
	while acc >= STEP do
		acc -= STEP
		state = Sim.step(state, config, STEP)   -- always the SAME dt
	end
end)
```

Now `Sim.step` only ever sees `STEP`, so the harness can call it 20 million times
and get exactly what the live server would get. Frame-rate no longer affects
numbers. The leftover `acc` is presentation-only interpolation, and it lives in
`client/`, not `sim/`.

Offline progress becomes `Sim.fastForward(state, config, elapsed)`, which runs
the same `Sim.step` in a loop with a cap and a batching optimization — and
critically, it is *the same function* the online path uses, so the two cannot
drift apart.

### 10.3 Promises and coroutines

Luau has no promises in the language; yielding calls suspend the calling
coroutine and resume it transparently. So:

```js
async function buyAndSave(id) {
  const ok = await sim.apply(id);
  if (ok) await saveToServer();
  return ok;
}
```

```lua
local function buyAndSave(id)
	local ok = Sim.apply(state, config, { kind = "buy", id = id })  -- pure, no yield
	if ok then saveToServer() end                                    -- yields
	return ok
end
```

The `async` keyword disappears. What replaces it is a discipline question: **any
function that might yield must be documented as yielding**, because a yield in
the middle of a state mutation is where race conditions come from. Keep `sim/`
non-yielding by construction (it has no access to anything that can yield) and
all yielding in `server/`.

`Promise.all` has no primitive:

```lua
local function all(fns: {() -> any}): {any}
	local results, remaining = table.create(#fns), #fns
	local done = Instance.new("BindableEvent")
	for i, fn in fns do
		task.spawn(function()
			results[i] = fn()
			remaining -= 1
			if remaining == 0 then done:Fire() end
		end)
	end
	if remaining > 0 then done.Event:Wait() end
	return results
end
```

Some teams vendor a Promise library (evaera's `Promise` is the common one) to
keep the ported code shaped like the original. That is a reasonable choice for
the *network* layer and a bad one for `sim/`, which must stay dependency-free.

Error handling: `try/catch` → `pcall`. Note `pcall` returns
`(ok, resultOrError)` and swallows the traceback; use `xpcall` with
`debug.traceback` where you care. An unhandled error in a `task.spawn`ed thread
does not kill the game, it logs and the thread dies — which means a ported
`Promise` rejection that the original surfaced to the user can vanish silently.
Log every `pcall` failure in `sim/`-adjacent code.

---

## 11. Big numbers: `break_infinity.js` → Luau

If the original uses `Decimal` (from `break_infinity.js` or `break_eternity.js`),
the number system *is* the game, and this section is the highest-risk part of the
port.

`break_infinity.js` stores a number as `mantissa × 10^exponent` with both parts
as float64, giving a range up to about `1e(9e15)`
([README](https://github.com/Patashu/break_infinity.js)). On Roblox the mature
options are **AlyaNum** (a rewrite of OmegaNum, range to `10^^^^^10`,
[evilbocchi/alyanum](https://github.com/evilbocchi/alyanum)), **SerikaNum**
(same author, cap `10^(2^1024)`, faster), **EternityNum2**, and
**InfiniteMath**. For a straight `break_infinity.js` port, SerikaNum's range is
the closest match and the cheapest; pick AlyaNum only if the original uses
`break_eternity.js` tetration.

**Wrap the library.** Every `sim/` file imports `sim/bignum.luau`, never the
library directly. That facade is where you (a) normalise the API to the
original's method names so the diff stays readable, (b) fix the rounding and
formatting differences below, and (c) make it possible to swap libraries after
benchmarking without touching game logic.

### 11.1 Translation table

`D` is the facade; `a`, `b` are big numbers. AlyaNum method names are from
`alya.luau`; the operator forms come from its metatable.

| `break_infinity.js` | Facade (`sim/bignum.luau`) | AlyaNum underneath | Notes |
|---|---|---|---|
| `new Decimal(x)` | `D.new(x)` | `AlyaNum.new(x)` | accepts number or string |
| `Decimal.fromMantissaExponent(m, e)` | `D.fromME(m, e)` | `AlyaNum.new(m) * AlyaNum.new(10) ^ e` | verify normalization |
| `a.add(b)` / `.plus` | `D.add(a, b)` | `a + b` / `add` | |
| `a.sub(b)` / `.minus` | `D.sub(a, b)` | `a - b` / `subtract` | |
| `a.mul(b)` / `.times` | `D.mul(a, b)` | `a * b` / `mul` | |
| `a.div(b)` / `.dividedBy` | `D.div(a, b)` | `a / b` / `div` | |
| `a.recip()` | `D.recip(a)` | `reciprocal` | |
| `a.neg()` / `.negate` | `D.neg(a)` | `unary` / `-a` | |
| `a.abs()` | `D.abs(a)` | `abs` | |
| `a.sgn()` / `.sign` | `D.sign(a)` | derive from `compare(a, 0)` | returns a plain number |
| `a.pow(n)` | `D.pow(a, n)` | `a ^ n` / `pow` | |
| `Decimal.pow10(n)` | `D.pow10(n)` | `pow10` | |
| `a.exp()` | `D.exp(a)` | `AlyaNum.new(math.exp(1)) ^ a` | check the library's own `exp` first |
| `a.sqrt()` / `.cbrt()` / `.sqr()` / `.cube()` | `D.sqrt` / `D.cbrt` / `D.sqr` / `D.cube` | `root(a, 2)`, `root(a, 3)`, `a^2`, `a^3` | |
| `a.log10()` | `D.log10(a)` | `log10` | **JS returns a plain `number`**; make the facade do the same |
| `a.log(base)` / `.logarithm` | `D.log(a, base)` | `log` | plain number |
| `a.ln()` / `.log2()` | `D.ln(a)` / `D.log2(a)` | `log(a, e)` / `log(a, 2)` | plain number |
| `a.cmp(b)` / `.compare` | `D.cmp(a, b)` | `compare` | returns −1/0/1 |
| `a.eq/neq/lt/lte/gt/gte(b)` | `D.eq(a,b)` etc. | `equals`, `lessThan`, `lessEquals`, `moreThan`, `moreEquals` | or the `==`/`<`/`<=` operators |
| `a.max(b)` / `.min(b)` | `D.max` / `D.min` | `max` / `min` | |
| `a.clamp(lo, hi)` / `.clampMin` / `.clampMax` | `D.clamp(a, lo, hi)` | compose `max`/`min` | |
| `a.eq_tolerance(b, t)` (and the whole `*_tolerance` family) | `D.eqTol(a, b, t)` | `isCloseTo(a, b, relTol, absTol)` | **semantics differ** — see below |
| `a.floor()` / `.ceil()` / `.trunc()` | `D.floor` / `D.ceil` / `D.trunc` | `floor` / `ceil` | |
| `a.round()` | `D.round(a)` | **do not use the library's `round`** | see below |
| `a.toNumber()` | `D.toNumber(a)` | `toNumber` | may overflow to `inf` |
| `a.toString()` | `D.toString(a)` | `toString` | **formats differ** — port the original's formatter |
| `a.toExponential(p)` / `.toFixed(p)` / `.toStringWithDecimalPlaces(p)` | port explicitly | — | |
| `Decimal.affordGeometricSeries(res, price, mul, owned)` | `D.affordGeometric(…)` | not present — port the formula | the closed form matters; see below |
| `Decimal.sumGeometricSeries(n, price, mul, owned)` | `D.sumGeometric(…)` | not present — port the formula | |
| `Decimal.affordArithmeticSeries` / `sumArithmeticSeries` | port explicitly | not present | |
| `Decimal.efficiencyOfPurchase(cost, rps, dRps)` | port explicitly | not present | |

### 11.2 The three places fidelity actually breaks

**Rounding.** `break_infinity.js`'s `round()` is:

```ts
public round(): Decimal {
  if (this.e < -1) { return ZERO; }
  if (this.e < MAX_SIGNIFICANT_DIGITS) {
    return Decimal.fromNumber(Math.round(this.toNumber()));
  }
  return this;
}
```

(`src/decimal.ts`.) So it inherits `Math.round`'s half-toward-+∞ tie behaviour
(§6.3), and it silently *floors to zero* for exponents below −1 and becomes the
identity above 17 significant digits. A Luau library's `round` will not reproduce
any of that. Implement `D.round` in the facade as a direct transcription of
those three branches, with `jsRound` in the middle one.

**Bulk-buy closed forms.** `affordGeometricSeries` / `sumGeometricSeries` are the
functions that answer "how many can I buy with this much currency" and "what does
buying N more cost". They are logarithm-based closed forms, so they are the most
float-sensitive code in the game, and they are the most visible — the player sees
"Buy Max: 137" and any off-by-one is a bug report. Port them from the original's
source, not from a formula you derive yourself, and golden-test them across the
full exponent range (§15.2). A single `Math.floor` vs `math.floor` difference at
a tie produces a one-item discrepancy that shows up in a bulk-buy tooltip.

**Tolerance comparisons.** `break_infinity.js`'s `eq_tolerance(b, t)` compares
using a tolerance that defaults to a *relative* epsilon; AlyaNum's `isCloseTo`
takes both a `relativeTolerance` and an `absoluteTolerance` (`alya.luau`). These
are not the same predicate. If the original uses `eq_tolerance` to decide
anything — "is this upgrade already maxed", "has the player reached the
threshold" — transcribe the JS implementation into the facade rather than mapping
to the nearest-looking Luau function.

**Formatting.** Number formatting in an incremental game is a *feature*, with the
original's own suffix table ("K, M, B, T, Qa, Qi, …"), its own notation modes
(scientific, engineering, letters, hyper-E), and its own rounding at each
threshold. Luau libraries ship their own (`toSuffix`, `toScientific`,
`toEChain`, `toHyperE` in AlyaNum) and they will not match. Port
`client/ui/format.luau` from the original's formatter source, treat it as part of
the behavioural spec, and golden-test it on a few thousand values.

### 11.3 When the original does *not* use a big-number library

Some idle games stay in plain float64 and simply let numbers go to `1e308` and
`Infinity`. That ports perfectly — both languages are binary64 — and you should
resist the temptation to "upgrade" to a big-number library during the port,
because it changes every result at the top end. Do it as a separate, spec'd
change afterwards, with its own golden vectors.

---

## 12. UI translation

The mapping table above is the reference. This section covers the four places
where the mapping is *not* mechanical.

**There is no layout engine.** CSS reflows: text wraps, boxes grow to fit
content, siblings push each other around, and the whole thing re-solves on every
change. Roblox has `UIListLayout`, `UIGridLayout`, `UITableLayout`, `UIPageLayout`
and a set of constraints — and that is all. `AutomaticSize` will grow a frame to
its children, and `UIFlexItem` will distribute slack along one axis, but there is
no general constraint solver and no content-driven two-dimensional reflow. In
practice this means: **rebuild the layout, do not translate it.** Take the screen
inventory, sketch each screen as a tree of `Frame`s with one layout object each,
and accept that a CSS layout which relied on intrinsic sizing will become an
explicit size.

**Flex is close enough to be useful and different enough to check.** A
`UIListLayout` with `FillDirection = Horizontal` is `flex-direction: row`;
`HorizontalFlex` is `justify-content`; `ItemLineAlignment` is `align-items`;
`Wraps` is `flex-wrap`. Per-item `flex-grow`/`flex-shrink` is a `UIFlexItem`
child, where `Grow` gives "an effective `1:0` grow-shrink ratio", `Shrink` gives
`0:1`, `Fill` gives `1:1`, and `Custom` exposes `GrowRatio`/`ShrinkRatio`
(`creator-docs`, `classes/UIFlexItem.yaml`). Roblox's own docs warn that flex
"adds a slight performance cost above non-flex, especially when resizing the
layout or dynamically adding/removing flex items" — which is exactly what an idle
game's shop list does, so measure it.

**`ZIndex` is global by default.** Set `ScreenGui.ZIndexBehavior = Sibling` to
get CSS-like behaviour where a child's `ZIndex` is only compared against its
siblings. Without it, a `ZIndex = 2` label deep in one panel draws over a
`ZIndex = 1` modal, which is not how the web version behaved.

**Rich text is a small, escape-sensitive subset.** `TextLabel.RichText = true`
enables `<b> <i> <u> <s> <br/> <font …> <stroke …> <uppercase> <smallcaps>`
(`creator-docs`, `ui/rich-text.md`). There is no layout inside it — no floats, no
inline-block, no per-run line-height. And crucially: **any dynamic text
interpolated into a rich-text label must be escaped** (`<` → `&lt;`, `>` →
`&gt;`, `&` → `&amp;`, `"` → `&quot;`, `'` → `&apos;`). An unescaped player name
or a number formatter emitting `<` breaks the whole label's formatting, and in
the worst case lets a player inject markup into other players' UI.

**Canvas → `EditableImage`.** A 2D-context canvas becomes an `EditableImage`
assigned to an `ImageLabel`. This is a full pixel-buffer API, not a drawing API:
you get `WritePixelsBuffer`/`ReadPixelsBuffer` and a handful of `Draw*`
operations, and you write your own rasterization for anything else. See chapters
20 and 40. Two constraints to plan around: the editable APIs require the creator
to be 13+ age-verified **and** ID-verified with Mesh/Image APIs enabled on the
Creator Dashboard, and almost every mutator is `Unsafe` in the parallel phase —
compute in parallel, commit in serial.

**Update frequency.** A web idle game typically re-renders the whole number
display every frame because the DOM diff is cheap enough. In Roblox, every
`TextLabel.Text` assignment is a property write that can trigger a text re-layout.
Drive UI updates from a throttled subscription (10 Hz is usually indistinguishable
from 60 for a counter) and only touch labels whose formatted string actually
changed. This is presentation, so it cannot affect `sim/` — which is the point of
the split.

---

## 13. Asset translation

**Everything must be uploaded, and everything is moderated.** Roblox performs
"both human and automated asset moderation", generally "within a few hours after
you import the asset", and — the operationally important line — "If an asset is
still in the moderation queue when you publish your game, users cannot see or
interact with the asset until Roblox approves it"
(`creator-docs`, `projects/assets/index.md`). Upload the whole asset set at the
start of stage 6, not the day before launch, and keep a manifest mapping the
original's filenames to `rbxassetid://` ids so a re-upload is a one-line change.

| Web asset | Roblox | Work required |
|---|---|---|
| PNG / JPG | uploaded Image asset → `ImageLabel.Image` | Upload + moderation. Note transparent pixels are set to black on upload, so author with premultiplied-safe edges |
| Sprite sheet + `background-position` | one uploaded image + `ImageRectOffset` / `ImageRectSize` | Direct translation; `ImageRectOffset` is "the pixel offset (from the top-left) of the image area to be displayed", and a zero in either dimension of `ImageRectSize` shows the whole image |
| CSS sprite with `background-size` scaling | atlas + `ImageRectSize` + `ScaleType` | `ScaleType.Stretch` is the default; use `Slice` + `SliceCenter` for 9-slice |
| **SVG** | **no equivalent** | Rasterize at the target resolutions (2–3 sizes) and upload, or rebuild as `Frame`s + `UICorner` + `UIGradient`. Rasterize unless the art needs to scale continuously |
| **CSS-drawn art** (gradients, radii, shadows, pseudo-element icons) | partly `UIGradient` + `UICorner` + `UIStroke`; otherwise rasterize | `box-shadow` has no equivalent — use a 9-sliced shadow image. Multi-stop radial gradients have no equivalent |
| Icon font | rasterized atlas, or an uploaded font family | `FontFace = Font.new("rbxasset://fonts/families/….json", weight, style)` |
| Web font | uploaded font family asset | |
| Animated GIF / CSS keyframe sprite | a sprite-sheet atlas driven by `ImageRectOffset` on a `Heartbeat` timer | |
| Audio | uploaded Audio asset | Moderated, and subject to its own licensing rules |
| Procedurally drawn canvas art | `EditableImage`, generated at runtime | **No upload, no moderation** — the reason to prefer it for anything derived from game state |

**Atlasing.** Roblox has a per-image size cap (1024×1024 is the long-standing
practical limit for UI images) **[unverified — confirm the current cap against
`art/…/texture-specifications` before committing an atlas layout]**. Pack icons
into atlases and address them with `ImageRectOffset`/`ImageRectSize`; each
distinct image is a separate texture and a separate download, so an idle game
with 200 building icons wants 2–4 atlases, not 200 assets.

**`EditableImage` as the upload escape hatch.** Anything you would have drawn
with canvas or CSS — a progress ring, a stat sparkline, a tinted variant of a
base icon, a generated background gradient — can be produced at runtime into an
`EditableImage` and assigned to an `ImageLabel` with no asset, no upload and no
moderation. `AssetService:CreateAssetAsync` can also upload an `EditableImage` as
an `Enum.AssetType.Image`, but it "can only be used in locally loaded plugins"
(`creator-docs`, `classes/AssetService.yaml`), so runtime generation is a
*rendering* strategy, not a content-pipeline one.

---

## 14. Save-format migration

### 14.1 Read the original's format exactly

Typical web save chains, in rough order of frequency:

1. `JSON.stringify(state)` → `localStorage`
2. `btoa(JSON.stringify(state))` → base64 → `localStorage`
3. `LZString.compressToBase64(JSON.stringify(state))`
4. A hand-rolled delimited format (`"5|17|0|1|…"`), sometimes with a checksum
5. Any of the above with a version prefix and an obfuscation XOR

For (1) and (2), `HttpService:JSONDecode` plus a base64 decoder gets you there.
For (3), you need an LZString decompressor in Luau — port it from the reference
implementation and golden-test it against a set of real compressed saves before
you trust it with anyone's progress. For (4), write the parser with the *exact*
`split` from §7.1 that preserves empty fields.

Capture at least three real saves (new / mid / endgame) plus one save from every
version the original ever shipped that you intend to support, and check them into
`tests/golden/saves/`. Those files are the specification.

### 14.2 Map to the new schema

```lua
-- sim/save/schema.luau
return table.freeze({
	VERSION = 4,
	fields = {
		-- name            type        default          min        max
		{ "cookies",       "bignum",   "0",             "0",       nil },
		{ "totalEarned",   "bignum",   "0",             "0",       nil },
		{ "prestigeCount", "int",      0,               0,         1e6 },
		{ "buildings",     "map<id,int>", {},           0,         1e9 },
		{ "upgrades",      "set<id>",  {},              nil,       nil },
		{ "lastSeen",      "int",      0,               0,         nil },
		{ "rngState",      "int",      0,               0,         2^32 - 1 },
	},
})
```

Driving validation from a declared schema rather than hand-written `if`s is the
difference between "we checked the fields we remembered" and "every field is
checked". It also gives the harness something to enumerate.

### 14.3 Should you import the player's existing web save?

It is a strong retention play and a real security surface. If you do it:

- **The import runs on the server, never the client.** The client may paste the
  string; the server decodes and validates it.
- **Never trust a single field.** Every numeric field is clamped to the schema's
  min/max. Every id is checked for membership in the content tables — an unknown
  building id is dropped, not defaulted. Every array is rebuilt densely. Every
  string is length-capped before it goes anywhere near a `TextLabel`.
- **Cross-validate derived against authoritative.** If the save claims 10 cursors
  and `1e40` cookies, check that `1e40` is reachable given the claimed purchase
  history — or, more practically, clamp the currency to a function of the
  strongest claim in the save. A save is *the* place to inject an arbitrary
  number into your economy.
- **Rate-limit and one-shot it.** One import per account, ever, recorded in the
  DataStore before the state is applied. Otherwise a valid save becomes a
  currency faucet.
- **Log every import** with the raw string, the decoded structure and the
  clamped result. When (not if) someone finds a hole, the log is how you find
  every account that used it.
- **Cap the input size** before decoding. A 50 MB "save" is a denial-of-service,
  and `JSONDecode` on adversarial input is not free.
- **Decode inside `pcall`.** Malformed input must produce a friendly error, not
  a server error.

If the answer is "we are not confident we can validate this", the correct
decision is to grant a fixed founder bonus instead of importing. That is a
product decision with a known cost; an unvalidated import is an unbounded one.
See chapter 47 for the general threat model.

### 14.4 Forward migration

Keep `migrate.luau` as an ordered chain of single-version steps
(`v1→v2`, `v2→v3`, …), never a big switch. Each step is a pure function over
plain tables, which means each step is unit-testable against a captured save from
that version, and the chain is testable end to end: load a v1 save, run the
chain, assert the result equals a v4 save captured independently.

---
