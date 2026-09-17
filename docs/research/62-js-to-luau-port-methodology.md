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
