# Incremental-Game UI in Roblox: Dense, Fast, Readable, and Mobile-Survivable

*Research chapter. Verified against primary sources September 2026. Roblox API claims are cited to the `Roblox/creator-docs` repository (the source of truth behind `create.roblox.com`). Anything I could not confirm from a primary source is marked `[UNVERIFIED]`; anything sourced from developer-forum threads I could not read directly is marked `[COMMUNITY, SECOND-HAND]`.*

---

In most genres the UI is a layer over the game. In an incremental/idle game **the UI is the game**. The player's entire loop is: read a number, compare it to a cost, press a button, watch the number grow. Every craft decision in this chapter follows from three facts:

1. **The numbers never stop moving.** A production tick at 60 Hz means every readout on screen is stale one frame later.
2. **The numbers span dozens of orders of magnitude.** `1.00` and `1.00e308` must both be legible in the same 90-pixel-wide label.
3. **Most of your players are on phones.** A layout that is "dense" on a 27-inch monitor is unreadable and untappable on a 5.5-inch screen held one-handed on a bus.

This chapter is the reference for building that UI without dropping to 12 fps.

---

## TL;DR

- **Never store big values as Luau `number`.** A double loses integer exactness past `2^53` and dies at `~1.8e308`. **Chapter 60 settles the value type for this project: AlyaNum**, a flat 7-field `{sign, multiplicand, exponent, tetrate, pentate, hexate, heptate}` struct that reaches heptation. This chapter takes that as given and concerns itself only with getting those fields onto a screen. (§1.1)
- **Formatting is the hot path, not the maths.** `string.format` plus a table lookup is cheap; doing it 400 times a frame is not. The fix is a two-level cache: a **format cache** keyed on `(quantized value, notation, places)` and a **write guard** that compares the produced string to `label.Text` before assigning. (§1.4, §2.2)
- **Assigning `TextLabel.Text` is not free.** It invalidates text layout and re-runs measurement/shaping for that label; `ContentText`, `TextBounds` and `TextFits` are all derived from it, and `AutomaticSize`/`TextScaled` make it worse. Guard every write. (§1.4, §10.2)
- **Decouple UI rate from tick rate.** Simulate at whatever rate you like; repaint text at **10–20 Hz**. Humans cannot read a digit that changes at 60 Hz anyway — above ~15 Hz fast-moving digits become visual noise. Drive UI from a fixed-step accumulator, not `RenderStepped`. (§2.1)
- **Dirty flags, not re-renders.** Every readout is a `Binding` with `last` and `dirty`. A frame's work is `for binding in dirtySet do binding:flush() end`, and the dirty set is usually near-empty. (§2.3)
- **Virtualize any list over ~40 rows.** A 300-row upgrade list instantiated in full is ~3,000 GuiObjects and a guaranteed mobile stall. Recycle a pool of `ceil(viewport/rowHeight) + 2` rows and re-bind them on `CanvasPosition` change. This is the single highest-leverage optimisation in the genre. (§3, and the full implementation section)
- **`ScrollingFrame.CanvasPosition` is your virtualization signal**, and `AbsoluteWindowSize` (frame size minus visible scrollbar gutters) is the correct viewport height — not `AbsoluteSize`. ([ScrollingFrame.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml))
- **Log-scale progress bars.** When the next milestone is `1e50`, a linear bar sits at 0% for six hours then snaps to 100%. Fill by `(log10(v) - log10(start)) / (log10(goal) - log10(start))` and label it with time-to-goal computed from the *growth rate*, not the delta. (§6)
- **Mobile minimum touch target is 44×44 pt / ~48 dp**, which on a Roblox `ScreenGui` means roughly **44–48 *offset* pixels** on a phone — and offset pixels do not scale, so design your row height in offset and scale *fonts* separately. Roblox's own accessibility guidance plus the platform HIGs agree on this number. (§7.3)
- **Ship one layout, two arrangements.** A distinct mobile *layout tree* doubles your maintenance forever. A single tree with a `Breakpoint` source that flips list-vs-grid, column counts and paddings costs a day. (§7.6)
- **For the "thousands of frequently-changing values" workload, use Vide** — fine-grained reactivity means an updated source touches exactly the effects that read it, with no VDOM diff and no component re-execution. React-Lua re-runs the component function and diffs; Fusion 0.3's `Computed` graph is fine-grained but carries per-scope bookkeeping and has a shakier maintenance story. Full comparison and the dissent in §8.
- **`CanvasGroup` costs a render target.** Roblox states outright: it "consumes extra texture memory", is capped by the client's `QualityLevel`, "renders as a blank texture" when the cap is exceeded, and should be used "with static sizes". Do not wrap every panel in one. ([CanvasGroup.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml))
- **Budget: aim for ≤ 1,500 GuiObjects live on a mid-range phone**, of which ≤ 300 are `TextLabel`s with changing text. Measure it, don't guess it — the MicroProfiler's `RenderPrepare`/`Render`/`UpdateGui` labels plus a scripted `#Instances` counter tell you where you are. (§10)
- **Micro-feedback must be poolable.** A player holding buy-max does 20 purchases/second. Pre-allocate the number-popups, reuse one `Sound` per class with a rate limiter, and collapse rapid purchases into one aggregated popup. (§5.4)

---

## Contents

1. [Number display](#1-number-display) — the genre's signature problem
2. [Updating a UI where everything changes](#2-updating-a-ui-where-everything-changes)
3. [Long lists and virtualization](#3-long-lists-and-virtualization)
4. [The standard screens](#4-the-standard-screens)
5. [Affordability and feedback](#5-affordability-and-feedback)
6. [Progress bars and charts](#6-progress-bars-and-charts)
7. [Layout and platform](#7-layout-and-platform)
8. [Architecture](#8-architecture)
9. [Polish](#9-polish)
10. [Performance budget](#10-performance-budget)
- [Number formatting reference](#number-formatting-reference)
- [The virtualized list implementation](#the-virtualized-list-implementation)
- [Sources](#sources)

---

## 1. Number display

### 1.1 The value type comes first, and it is not `number`

Luau numbers are IEEE-754 doubles. Two hard walls follow:

| Wall | Value | What breaks |
|---|---|---|
| Exact integers | `2^53 = 9007199254740992` (~9.0e15) | `cost + 1 == cost`. Purchase counters silently stop incrementing. |
| Overflow | `~1.7976931348623157e308` | Anything larger becomes `inf`, and `inf - inf` is `nan`. Your whole save is poisoned. |

An incremental game crosses ~9e15 within the first hour of a typical curve and crosses 1e308 in the mid-game of anything with a prestige layer. **Decide the value type on day one**, because retrofitting it later means rewriting every formula, every save migration and every UI binding.

**Chapter 60 of this corpus settles this question for this project and the answer is AlyaNum** — a flat, 7-field `{sign, multiplicand, exponent, tetrate, pentate, hexate, heptate}` struct reaching heptation, with full operator overloading and a float64 fast path below ~1e308. This game reaches `E(4)` (`10^10^10^10`), so a `{mantissa, exponent}` `Decimal` is *not* sufficient. Do not re-litigate it here; see chapter 60 for the library comparison, the aliasing footguns and the serialization story.

What matters for the UI is narrower, and it is this: **the display layer must never do arithmetic on the value, and must never call `tostring` on it in a hot loop.** Three consequences shape everything below.

1. **Format from the fields, not from the value.** A formatter that reads `multiplicand` and `exponent` is `O(1)` no matter how large the number is. One that goes through arithmetic to extract digits is not, and it allocates — chapter 60 records that *every* AlyaNum operation allocates a fresh 7-field table, because `fix()` ends in `setmetatable` on a new table and there is no public mutate-in-place API.
2. **`a:log10()` returns an AlyaNum, not a `number`** (chapter 60, porting rules). Every `math.log10`-shaped expression in this chapter operates on a plain Luau `number` that you have *already* extracted from the low fields. Extract once per flush, into the view model (§8.4); never inside a row's rebind.
3. **AlyaNum's own formatting globals are unusable for a per-player setting.** `changeSuffixes`, `changeDecimalPoints` and `changeDefaultAbbreviation` are process-global mutable state (chapter 60). A notation *setting* (§1.5) therefore cannot be implemented by flipping AlyaNum's globals — you need your own formatter, which is what §1.2–§1.4 build. AlyaNum also ships no engineering notation and no `aa/ab/ac` letter notation at all, so those two are yours to write regardless.

For context, the ladder of representations the genre uses, so the vocabulary below is unambiguous:

| Model | Shape | Ceiling | Notations it can express |
|---|---|---|---|
| `log10` float | one double | `10^(±1.7e308)` | standard, scientific, engineering, letters, logarithm |
| `Decimal` (`break_infinity`) | `{mantissa, exponent}` | `10^1.79e308` | same | 
| `break_eternity` | `{sign, layer, mag}` | tetrational | + e-chain, `E(n)` |
| **AlyaNum** (this project) | 7 flat fields | heptation | + hyper-E `E10#8#3#2` |

([break_infinity.js](https://github.com/Patashu/break_infinity.js), [break_eternity.js](https://github.com/Patashu/break_eternity.js), [evilbocchi/alyanum](https://github.com/evilbocchi/alyanum) — and chapter 60 for the verified detail.)

**For the rest of this chapter, UI code sees a two-field adapter, not the value type itself.** The adapter is extracted once per flush from AlyaNum's low fields and carries a `layered` flag for values past `exponent >= 2`, where a mantissa/exponent pair no longer means anything and the formatter must escalate to e-chain / `E(n)` / hyper-E.

```lua
--!strict
-- The minimal surface the UI needs from whatever big-number type you pick.
export type Big = {
    mantissa: number,  -- normalized to [1, 10), or 0 when the value is 0
    exponent: number,  -- base-10 exponent
    layered: boolean,  -- true once the value is a power tower (AlyaNum exponent >= 2)
    big: any?,         -- the original value, only when `layered`
}

local function fromNumber(n: number): Big
    if n == 0 then return { mantissa = 0, exponent = 0, layered = false } end
    local e = math.floor(math.log10(math.abs(n)))
    return { mantissa = n / 10 ^ e, exponent = e, layered = false }
end

-- Extracted ONCE per flush, in the view-model pass (§2.4 / §8.4).
-- `a.exponent >= 2` means the value is a power tower: there is no mantissa to
-- show, and the formatter escalates to the library's own toEChain/toEnt/toHyperE.
local function fromAlyaNum(a): Big
    if a.exponent >= 2 or a.tetrate ~= 0 then
        return { mantissa = 0, exponent = 0, layered = true, big = a }
    end
    -- exponent 0 or 1: multiplicand carries the value; normalize to [1,10).
    local v = if a.exponent == 1 then a.multiplicand else math.log10(a.multiplicand)
    return { mantissa = 10 ^ (v % 1), exponent = math.floor(v), layered = false }
end
```

> `[UNVERIFIED]` The exact `fix()` normalization invariants (when `exponent` is 0 vs 1, and what `multiplicand` holds in each case) are documented in chapter 60 from a direct read of `src/init.luau`. **Take the field semantics from there, not from the sketch above** — this snippet shows the *shape* of the adapter, not verified field semantics.

### 1.2 The notations players expect

Incremental players have strong, specific expectations formed by Antimatter Dimensions, Cookie Clicker and their descendants. Ship **all** of these behind a settings toggle; the cost is one module and the payoff is that nobody bounces because "the numbers are unreadable".

| Notation | `1.234e15` renders as | Who wants it |
|---|---|---|
| **Standard** (suffixes) | `1.23 Qa` | Default. Most players, especially mobile. |
| **Scientific** | `1.23e15` | Players who actually do the maths. |
| **Engineering** | `1.23e15` (exponent forced to a multiple of 3) | Engineers; keeps digit groups aligned with the suffix scale. |
| **Letters** | `1.23f` (a=1e3, b=1e6, …, z=1e78, aa=1e81) | Compactness fanatics; survives to absurd magnitudes in 2–3 characters. |
| **Logarithm** | `e15.09` | Late game, when even the exponent has an exponent. |
| **Hyper-E** | `E15.09`, then `E15#2` for `10^10^15` | Tetrational games only. |
| **Arrow** | `10↑↑3.2` | Tetrational games only. |
| **Mixed** | Standard below a threshold, scientific above | The best *default*: readable early, honest late. |

**The Standard suffix table is not folklore — it has a canonical algorithm**, and getting it wrong is an instantly-noticed bug. The tables and construction rule below are transcribed from the Antimatter Dimensions notations library (MIT). Note the detail everyone gets wrong: quintillion is **`Qt`**, not `Qi` — `Qi` appears in the *second* prefix row, standing for *quinquagint*-. ([antimatter-dimensions/notations `src/utils.ts`](https://github.com/antimatter-dimensions/notations/blob/master/src/utils.ts))

```lua
-- The first ten tiers have bespoke two-letter forms.
local ABBREVIATIONS = { "K", "M", "B", "T", "Qa", "Qt", "Sx", "Sp", "Oc", "No" }

-- Beyond that, suffixes are composed from three rows of "illion" prefixes:
-- units, tens, hundreds. (Dc = deci-, Vg = vigint-, Ce = cent-, ...)
local PREFIXES = {
    { "", "U",  "D",  "T",  "Qa", "Qt", "Sx", "Sp", "O",  "N"  }, -- units
    { "", "Dc", "Vg", "Tg", "Qd", "Qi", "Se", "St", "Og", "Nn" }, -- tens
    { "", "Ce", "Dn", "Tc", "Qe", "Qu", "Sc", "Si", "Oe", "Ne" }, -- hundreds
}
-- And past 1000 tiers, an SI-style meta-prefix is appended per group of three.
local PREFIXES_2 = { "", "MI-", "MC-", "NA-", "PC-", "FM-", "AT-", "ZP-" }

--- tier is floor(exponent / 3): 1 => K, 2 => M, 11 => Dc, ...
local function abbreviateStandard(tier: number): string
    local exp = tier - 1 -- 0-based index into the tables
    if exp < 0 then
        return ""
    end
    if exp < #ABBREVIATIONS then
        return ABBREVIATIONS[exp + 1]
    end

    local prefix: { string } = {}
    local e = exp
    while e > 0 do
        local row = PREFIXES[(#prefix % 3) + 1]
        prefix[#prefix + 1] = row[(e % 10) + 1]
        e //= 10
    end
    while #prefix % 3 ~= 0 do
        prefix[#prefix + 1] = ""
    end

    local out: { string } = {}
    for i = (#prefix // 3) - 1, 0, -1 do
        local meta = PREFIXES_2[i + 1] or "" -- beyond ZP- we simply stop decorating
        out[#out + 1] = prefix[i * 3 + 1] .. prefix[i * 3 + 2] .. prefix[i * 3 + 3] .. meta
    end

    local s = table.concat(out)
    -- Canonical cleanup, transcribed from the reference implementation.
    s = s:gsub("%-%u%u%-", "-")
    s = s:gsub("U(%u%u%-)", "%1")
    s = s:gsub("%-$", "")
    return s
end
```

Spot-checks: `tier=1 → "K"`, `tier=2 → "M"`, `tier=5 → "Qa"` (1e15, quadrillion), `tier=6 → "Qt"` (1e18, quintillion), `tier=11 → "Dc"` (1e33, decillion), `tier=12 → "UDc"` (1e36, undecillion).

The **Letters** notation is a base-26 transcription of the *engineering* exponent (`exponent / 3`), also from the reference implementation:

```lua
local LETTERS = "abcdefghijklmnopqrstuvwxyz"

--- 1e3 => "a", 1e78 => "z", 1e81 => "aa", 1e84 => "ab", ...
local function transcribeLetters(exponent: number): string
    local n = exponent // 3
    local base = #LETTERS
    if n <= 0 then
        return ""
    end
    if n <= base then
        return LETTERS:sub(n, n)
    end

    local acc: { string } = {}
    while n > base do
        local rem = n % base
        local idx = if rem == 0 then base else rem
        acc[#acc + 1] = LETTERS:sub(idx, idx)
        n = (n - rem) / base
        if rem == 0 then
            n -= 1
        end
    end
    acc[#acc + 1] = LETTERS:sub(n, n)

    -- reverse in place; table.concat over a reversed view
    local i, j = 1, #acc
    while i < j do
        acc[i], acc[j] = acc[j], acc[i]
        i += 1
        j -= 1
    end
    return table.concat(acc)
end
```

### 1.3 Consistent decimal places, and why they matter more than you think

A readout that flips between `1.5 M`, `12.34 M` and `123 M` changes *width* every frame. A column of such readouts shimmers. Two rules fix it:

1. **Fix the number of significant digits, not the number of decimals.** Three significant digits (`1.23`, `12.3`, `123`) gives constant width for the mantissa in every notation. `string.format("%.2f", m)` alone does not: it produces `1.23`, `12.34`, `123.45`.
2. **Right-align every numeric column** (`TextXAlignment = Enum.TextXAlignment.Right`) and pin the suffix in its *own* label to the right of the mantissa label, so the mantissa's decimal point sits at a fixed x for the whole column.

```lua
--- Format a mantissa in [1, 1000) to exactly `sig` significant digits.
local function mantissaToSigFigs(m: number, sig: number): string
    local intDigits = if m >= 100 then 3 elseif m >= 10 then 2 else 1
    local decimals = math.max(0, sig - intDigits)
    return string.format("%." .. decimals .. "f", m)
end
```

> **Tabular figures.** `TextLabel.OpenTypeFeatures` accepts a comma-separated list of OpenType tags (the docs give `zero` and `ss03` as examples) and reports rejections through `OpenTypeFeaturesError`. Whether the tabular-numerals tag `tnum` is in the "supported subset" is `[UNVERIFIED]` — the documentation does not enumerate the subset. ([TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml)) **Test it on your target font and fall back to the robust option: pick a font whose digits are already monospaced, or split mantissa and suffix into separate right/left-aligned labels so digit-width variation cannot shift the column.**

### 1.4 The formatter, and the caching layer that makes it survivable

Here is the shape of the cost. A dense incremental screen has on the order of:

- 1 currency header with 3–5 readouts,
- 12–20 visible upgrade rows × 4 numeric fields each = 50–80 readouts,
- a handful of rate/multiplier/progress readouts.

Call it **~100 numeric readouts on screen**. At a naive 60 Hz repaint that is **6,000 format-and-assign operations per second**. At the 10–20 Hz repaint rate this chapter recommends (§2.1) it is 1,000–2,000/s. Neither is free, and almost all of it is *waste*: the vast majority of those 100 values have not changed enough to alter the rendered string.

Three layers of caching, cheapest first:

**Layer 0 — quantize before you format.** Reduce the value to the integer pair `(quantizedMantissa, exponent)` that the display would show. If that pair is unchanged, the string is unchanged, and you can stop without formatting *or* touching the Instance.

**Layer 1 — per-binding memo.** Each readout stores its own last `(qm, exp, notation)`. This is two number comparisons and zero allocations, and it catches ~95% of calls in practice because most values on screen are static (costs of unowned upgrades) or slow-moving.

**Layer 2 — shared string cache.** A two-level table `cache[exponent][qm] = string`. Two hash lookups, no string building, no garbage. This catches the case where many labels show the *same* number (a column of identical costs, the number `0`, small integers). Cap it and clear it on notation change.

```lua
--!strict
--!native
-- NumberFormat.luau
local NumberFormat = {}

export type Notation = "standard" | "scientific" | "engineering" | "letters" | "logarithm" | "mixed"

local SIG_FIGS = 3
local SUFFIX_SEPARATOR = ""     -- "" for "1.23K", " " for "1.23 K"
local MIXED_SCIENTIFIC_ABOVE = 1e33 -- switch Standard -> Scientific past decillion

-- ---------------------------------------------------------------- cache ----
-- cache[notationId][exponent][quantizedMantissa] = formatted string
local stringCache: { [string]: { [number]: { [number]: string } } } = {}
local stringCacheEntries = 0
local STRING_CACHE_MAX = 4096

local function cacheGet(notation: string, exp: number, qm: number): string?
    local byNotation = stringCache[notation]
    if not byNotation then return nil end
    local byExp = byNotation[exp]
    if not byExp then return nil end
    return byExp[qm]
end

local function cachePut(notation: string, exp: number, qm: number, s: string)
    if stringCacheEntries >= STRING_CACHE_MAX then
        -- Cheap eviction: drop everything. A full rebuild costs a few hundred
        -- microseconds once, versus LRU bookkeeping on every single lookup.
        stringCache = {}
        stringCacheEntries = 0
    end
    local byNotation = stringCache[notation]
    if not byNotation then
        byNotation = {}
        stringCache[notation] = byNotation
    end
    local byExp = byNotation[exp]
    if not byExp then
        byExp = {}
        byNotation[exp] = byExp
    end
    byExp[qm] = s
    stringCacheEntries += 1
end

function NumberFormat.clearCache()
    stringCache = {}
    stringCacheEntries = 0
end

-- ------------------------------------------------------------ formatters ---
local function formatStandard(mant3: number, tier: number): string
    if tier <= 0 then
        return mantissaToSigFigs(mant3, SIG_FIGS)
    end
    return mantissaToSigFigs(mant3, SIG_FIGS) .. SUFFIX_SEPARATOR .. abbreviateStandard(tier)
end

local function formatScientific(m: number, e: number): string
    return mantissaToSigFigs(m, SIG_FIGS) .. "e" .. tostring(e)
end

local function formatEngineering(mant3: number, tier: number): string
    if tier <= 0 then
        return mantissaToSigFigs(mant3, SIG_FIGS)
    end
    return mantissaToSigFigs(mant3, SIG_FIGS) .. "e" .. tostring(tier * 3)
end

local function formatLetters(mant3: number, tier: number): string
    if tier <= 0 then
        return mantissaToSigFigs(mant3, SIG_FIGS)
    end
    return mantissaToSigFigs(mant3, SIG_FIGS) .. transcribeLetters(tier * 3)
end

local function formatLogarithm(m: number, e: number): string
    -- log10 of the whole value, to 3 decimals: "e15.091"
    return "e" .. string.format("%.3f", e + math.log10(m))
end

-- --------------------------------------------------------------- entry -----
--- Format a big value. `v.mantissa` in [1,10), `v.exponent` integral.
--- Returns the display string. O(1) in the magnitude of the value.
function NumberFormat.format(v: Big, notation: Notation): string
    local e = v.exponent
    local m = v.mantissa

    if m == 0 then
        return "0"
    end

    local sign = ""
    if m < 0 then
        sign = "-"
        m = -m
    end

    -- Values under 1000 are shown plainly: "0", "1", "42", "999".
    if e < 3 then
        local plain = m * 10 ^ e
        return sign .. string.format(if e < 0 then "%.2f" else "%.0f", plain)
    end

    local effective: string = notation
    if notation == "mixed" then
        effective = if 10 ^ e >= MIXED_SCIENTIFIC_ABOVE then "scientific" else "standard"
    end

    -- Layer 0: quantize to what the display can actually show.
    local tier = e // 3
    local mant3 = m * 10 ^ (e - tier * 3) -- mantissa in [1, 1000)
    local qm: number, qe: number
    if effective == "scientific" or effective == "logarithm" then
        qm = math.round(m * 10 ^ (SIG_FIGS - 1))
        qe = e
    else
        -- 3 significant digits of a [1,1000) mantissa == round to 1 decimal
        qm = math.round(mant3 * 10)
        qe = tier
    end

    -- Layer 2: shared string cache.
    local hit = cacheGet(effective, qe, qm)
    if hit then
        return if sign == "" then hit else sign .. hit
    end

    local s: string
    if effective == "standard" then
        s = formatStandard(mant3, tier)
    elseif effective == "scientific" then
        s = formatScientific(m, e)
    elseif effective == "engineering" then
        s = formatEngineering(mant3, tier)
    elseif effective == "letters" then
        s = formatLetters(mant3, tier)
    else
        s = formatLogarithm(m, e)
    end

    cachePut(effective, qe, qm, s)
    return if sign == "" then s else sign .. s
end

return NumberFormat
```

**Layer 1, the per-binding memo, lives in the binding — not in the formatter.** It is the part that actually saves the frame, because it short-circuits before `format` is even called:

```lua
--!strict
-- NumericBinding.luau
local NumberFormat = require(script.Parent.NumberFormat)

local NumericBinding = {}
NumericBinding.__index = NumericBinding

export type NumericBinding = typeof(setmetatable({} :: {
    label: TextLabel,
    notation: NumberFormat.Notation,
    _qm: number,
    _qe: number,
    _text: string,
}, NumericBinding))

function NumericBinding.new(label: TextLabel, notation: NumberFormat.Notation): NumericBinding
    return setmetatable({
        label = label,
        notation = notation,
        _qm = math.huge, -- sentinel: guarantees the first set writes
        _qe = math.huge,
        _text = "",
    }, NumericBinding)
end

--- Returns true if the Instance was written to.
function NumericBinding.set(self: NumericBinding, v: Big): boolean
    -- Layer 0/1: quantize and compare. Two float compares, zero allocation.
    local tier = v.exponent // 3
    local qm = math.round(v.mantissa * 10 ^ (v.exponent - tier * 3) * 10)
    if qm == self._qm and tier == self._qe then
        return false -- the rendered string cannot have changed. Stop here.
    end
    self._qm, self._qe = qm, tier

    local s = NumberFormat.format(v, self.notation)
    -- Layer 3: the write guard. Quantization can collide across notations
    -- and at boundaries; never assign a string equal to the one already set.
    if s == self._text then
        return false
    end
    self._text = s
    self.label.Text = s -- the only line in this file that touches the engine
    return true
end

return NumericBinding
```

Note what the guard is protecting against. **Assigning `TextLabel.Text` is not a simple field write.** The engine must re-shape and re-measure the string: `ContentText`, `TextBounds` and `TextFits` are all documented as derived from it, and `TextFits` is explicitly "computed from `TextBounds` relative to the available space, so it reflects the combined effect of `TextWrapped`, `TextTruncate`, and `TextScaled`." If the label also has `AutomaticSize` or sits under a `UIListLayout`, a text change can additionally dirty the layout of its whole sibling group. ([TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml), [GuiObject.AutomaticSize](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml))

> `[UNVERIFIED]` I have no primary source giving a microsecond cost for a `Text` assignment; Roblox does not publish one. Measure it in your own game with the MicroProfiler (§10.4) before optimising further. The *architectural* claim — that a redundant `Text` write does strictly more work than a skipped one — is safe regardless.

**Benchmark harness.** Run this in Studio (not in a live session) to get your own numbers before and after adding the cache:

```lua
local NumberFormat = require(path.to.NumberFormat)

local samples = table.create(1000)
for i = 1, 1000 do
    samples[i] = { mantissa = 1 + (i % 9) + (i % 97) / 100, exponent = i * 3 }
end

local t0 = os.clock()
for _ = 1, 100 do
    for i = 1, #samples do
        NumberFormat.format(samples[i], "standard")
    end
end
print(("format: %.3f us/call"):format((os.clock() - t0) * 1e6 / 100000))
```

Do the same with `label.Text = s` in the loop to separate formatting cost from Instance-write cost. The ratio tells you which layer of the cache is earning its keep.

### 1.5 A player-facing notation setting

The setting must (a) persist, (b) apply instantly to every readout without a reload, and (c) clear the shared string cache, because cached strings are notation-specific.

```lua
--!strict
-- NotationSetting.luau
local NumberFormat = require(script.Parent.NumberFormat)

local NotationSetting = {}
local current: NumberFormat.Notation = "standard"
local listeners: { (NumberFormat.Notation) -> () } = {}

export type Option = { id: NumberFormat.Notation, label: string, example: string }

-- Shown in the settings page. Always render a live example: players pick by
-- looking, not by reading the name.
NotationSetting.OPTIONS = {
    { id = "standard",    label = "Standard",    example = "1.23 Qa" },
    { id = "mixed",       label = "Mixed",       example = "1.23 Qa / 1.23e40" },
    { id = "scientific",  label = "Scientific",  example = "1.23e15" },
    { id = "engineering", label = "Engineering", example = "1.23e15" },
    { id = "letters",     label = "Letters",     example = "1.23f" },
    { id = "logarithm",   label = "Logarithm",   example = "e15.091" },
} :: { Option }

function NotationSetting.get(): NumberFormat.Notation
    return current
end

function NotationSetting.set(n: NumberFormat.Notation)
    if n == current then return end
    current = n
    NumberFormat.clearCache() -- cached strings are per-notation; invalidate all
    for _, fn in listeners do
        fn(n)
    end
end

function NotationSetting.onChanged(fn: (NumberFormat.Notation) -> ()): () -> ()
    table.insert(listeners, fn)
    return function()
        local i = table.find(listeners, fn)
        if i then table.remove(listeners, i) end
    end
end

return NotationSetting
```

Every `NumericBinding` subscribes once and, on change, resets its memo sentinel (`self._qm = math.huge`) so the next flush re-writes. **Do not** loop over every binding writing text immediately; let the normal 10–20 Hz flush do it (§2), and the whole screen re-renders within 100 ms with no spike.

---

## 2. Updating a UI where everything changes

### 2.1 Decouple the repaint rate from the tick rate

Run the economy at whatever rate the design needs. Run the **UI at 10–20 Hz**. Reasons, in order of importance:

1. **Readability.** A digit that changes 60 times a second is not information, it is texture. Players read the *magnitude* and the *trend*; they cannot read the third significant digit at 60 Hz. 12–15 Hz is the sweet spot where a counter reads as "fast" without becoming a blur. `[UNVERIFIED — design judgement, not a measured result; A/B it.]`
2. **Cost.** Repainting 100 readouts at 15 Hz instead of 60 Hz is a 4× reduction in text work, for free, with no visible loss.
3. **Frame pacing.** `PreRender` blocks rendering: Roblox states plainly that it "should be used sparingly as the engine cannot start to render the frame until code running in this event has finished executing." UI text work belongs on `Heartbeat` (end of frame, after physics), not `PreRender`. ([RunService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/RunService.yaml))

Reserve `PreRender` for things that *must* be frame-perfect: camera, a progress bar's smooth fill, a tween you are driving manually. Everything textual goes on the slow clock.

```lua
--!strict
local RunService = game:GetService("RunService")

local UI_HZ = 15
local UI_DT = 1 / UI_HZ
local accumulator = 0

RunService.Heartbeat:Connect(function(dt: number)
    accumulator += dt
    if accumulator < UI_DT then
        return
    end
    -- Clamp rather than loop: if we were stalled for 2 seconds we want ONE
    -- repaint, not 30 of them queued up on the frame we recover.
    accumulator = 0
    UIScheduler.flush()
end)
```

### 2.2 Only write a property when the displayed value changed

This is the same guard as §1.4 generalised. Wrap *every* Instance write in a compare:

```lua
--!strict
-- Guarded writes. Each helper is ~3ns of comparison protecting an engine call.
local function setText(o: TextLabel, cache: { [string]: any }, v: string)
    if cache.text ~= v then cache.text = v; o.Text = v end
end
local function setColor(o: GuiObject, cache: { [string]: any }, v: Color3)
    -- Color3 has value equality in Luau, so == is a real comparison.
    if cache.color ~= v then cache.color = v; o.BackgroundColor3 = v end
end
local function setSize(o: GuiObject, cache: { [string]: any }, v: UDim2)
    if cache.size ~= v then cache.size = v; o.Size = v end
end
local function setVisible(o: GuiObject, cache: { [string]: any }, v: boolean)
    if cache.visible ~= v then cache.visible = v; o.Visible = v end
end
```

Keep the shadow value in a plain Luau table rather than reading the property back. Reading an Instance property also crosses the Luau↔C++ boundary; a table field does not.

Two genre-specific corollaries:

- **Quantize before comparing, always.** A progress bar whose `Size` you set from a raw float will change on literally every frame. Quantize the fill to the number of *pixels* it can actually occupy: `math.round(fraction * barWidthPx) / barWidthPx`. A 200 px bar has 200 distinguishable states, not 2^53.
- **Affordability colour is a boolean, not a number.** Recompute `canAfford` at 15 Hz, but only write `TextColor3`/`BackgroundColor3` when the boolean flips. In a 20-row list that is typically 0–2 writes per second, not 300.

### 2.3 The dirty-flag scheduler

The pattern: readouts register as *bindings*. Game state pushes into bindings; bindings mark themselves dirty; the 15 Hz flush drains the dirty set. A binding that nobody dirtied costs nothing at all.

```lua
--!strict
-- UIScheduler.luau
local UIScheduler = {}

export type Binding = {
    dirty: boolean,
    flush: (self: any) -> (),
}

-- Dirty set as an array + membership map: O(1) insert, O(n) drain over ONLY
-- the dirty entries. Never iterate the full binding list.
local dirtyList: { Binding } = {}
local dirtyCount = 0

function UIScheduler.markDirty(b: Binding)
    if b.dirty then return end
    b.dirty = true
    dirtyCount += 1
    dirtyList[dirtyCount] = b
end

function UIScheduler.flush()
    if dirtyCount == 0 then return end
    debug.profilebegin("UI.flush")
    -- Snapshot the count: a flush may dirty new bindings (e.g. a tooltip
    -- reacting to a value). Those are picked up next frame, not recursively.
    local n = dirtyCount
    for i = 1, n do
        local b = dirtyList[i]
        dirtyList[i] = nil
        b.dirty = false
        b:flush()
    end
    -- Compact anything added during the drain down to the front.
    local written = 0
    for i = n + 1, dirtyCount do
        written += 1
        dirtyList[written] = dirtyList[i]
        dirtyList[i] = nil
    end
    dirtyCount = written
    debug.profileend()
end

return UIScheduler
```

`debug.profilebegin`/`debug.profileend` put a named bar in the MicroProfiler. **Label every UI subsystem this way from day one** — §10.4 depends on it.

### 2.4 Batching: one pass per screen, not one pass per widget

Three batching rules that matter at this scale:

1. **Compute once, fan out.** `canAfford`, `nextCost`, `production` are read by the row, the tooltip, the bulk-buy bar and the header. Compute them once per flush into a per-generator "view model" table, then let bindings read the table. Never recompute a `log10` inside a row's flush.
2. **Never rebuild instance trees to reflect data changes.** Destroying and recreating a row is orders of magnitude more expensive than re-binding an existing one, and it invalidates layout for the whole container. Rows are recycled (§3), never rebuilt.
3. **Defer the expensive and rare.** Achievements, stats pages and graphs update at 1–2 Hz or only while their tab is open. Gate them on `frame.Visible` — a binding attached to a hidden panel should unregister, not flush into the void.

```lua
-- A tab that stops costing anything when it is not on screen.
local function bindPanelLifetime(panel: GuiObject, subscribe: () -> () -> ())
    local unsubscribe: (() -> ())? = nil
    local function sync()
        if panel.Visible and not unsubscribe then
            unsubscribe = subscribe()
        elseif not panel.Visible and unsubscribe then
            unsubscribe(); unsubscribe = nil
        end
    end
    panel:GetPropertyChangedSignal("Visible"):Connect(sync)
    sync()
end
```

---

## 3. Long lists and virtualization

### 3.1 Why the naive list dies

A generator/upgrade row in this genre is typically: a `Frame` + icon `ImageLabel` + name `TextLabel` + owned-count `TextLabel` + effect `TextLabel` + cost `TextLabel` + `TextButton` + `UICorner` + `UIStroke` + `UIPadding` ≈ **9–12 GuiObjects**. Three hundred upgrades is **~3,000 GuiObjects**, all of them laid out by a `UIListLayout`, all of them holding text that must be measured.

Every one of them costs even when scrolled out of view: they are still in the `ScreenGui`'s layout tree, still participating in `UIListLayout` sorting, still holding shaped text in memory. Roblox's own performance guidance frames the general principle for 3D content — the engine culls what is off-*camera*, not what is off-*canvas* — and there is no built-in canvas culling for `ScrollingFrame` children. ([performance-optimization/improve.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md))

> `[COMMUNITY, SECOND-HAND]` The DevForum is full of threads titled variations of "How do I optimize a ScrollingFrame for over 1000 frames?", and the consistent answer across them is virtualization/recycling: instantiate only what is visible and reuse row objects as the canvas scrolls. Community modules such as *VirtualScroller* package this. ([devforum thread 952022](https://devforum.roblox.com/t/how-do-i-optimize-a-scrolling-frame-for-over-1000-frames/952022), [VirtualScroller](https://devforum.roblox.com/t/virtualscroller-infinite-scrollingframes/3990429)) I could not read these directly (403) — treat as corroboration of the technique, not as a source for any specific number.

### 3.2 The recycling model

```
canvas (CanvasSize = rowCount * rowHeight, absolute offset)
┌─────────────────────────────┐  <- CanvasPosition.Y
│  row pool slot 0  (data 14) │  \
│  row pool slot 1  (data 15) │   |  viewport: AbsoluteWindowSize.Y
│  row pool slot 2  (data 16) │   |  visible = ceil(viewport / rowH) + 2
│  row pool slot 3  (data 17) │  /
└─────────────────────────────┘
       (pool size is constant; only the *data index* bound to each slot changes)
```

Key decisions:

- **Fixed row height.** Variable heights require a prefix-sum index and are a different (much harder) problem. In this genre every row is the same shape — take the fixed height and be grateful.
- **Position rows absolutely.** Do **not** use `UIListLayout` inside a virtualized canvas; you would be fighting the layout engine over positions it thinks it owns. Set `row.Position = UDim2.fromOffset(0, index * rowHeight)` yourself.
- **Set `CanvasSize` from the data count**, not from `AutomaticCanvasSize`. `AutomaticCanvasSize` sizes the canvas "based on child content" — and your children are a dozen recycled rows, not three hundred. ([ScrollingFrame.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml))
- **Use `AbsoluteWindowSize`, not `AbsoluteSize`, for the viewport.** The docs are explicit: `AbsoluteWindowSize` is "the frame's `AbsoluteSize` minus the space occupied by any currently visible scroll bar gutters." Using `AbsoluteSize` under-counts the rows you need by the scrollbar's worth of pixels and produces a one-row gap at the bottom. ([ScrollingFrame.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml))
- **Overscan by 1–2 rows** at each end so a fast flick never shows an empty slot before the rebind lands.
- **Drive rebinds from `CanvasPosition` changes**, via `GetPropertyChangedSignal("CanvasPosition")`, and additionally poll on the UI clock — momentum scrolling on touch keeps `CanvasPosition` moving after the finger leaves, and `ScrollingFrame:GetScrollVelocity()` will tell you the frame is still coasting. ([ScrollingFrame.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml))

### 3.3 The rebind must be cheap

The whole point collapses if rebinding a row is expensive. A rebind touches ~6 properties on ~10 instances. Apply §2.2's guarded writes *inside the rebind too*: when you scroll by one row, 11 of 12 slots keep the same data index and should do **zero** engine writes.

The full, working implementation is in [The virtualized list implementation](#the-virtualized-list-implementation).

---

## 4. The standard screens

Genre conventions exist for a reason: players arrive already knowing how to use them. Deviate on theme, not on structure.

### 4.1 Currency header bar

Always visible, top of screen, inside the Core UI safe area. Contents: 2–5 currency readouts, each `[icon][amount][rate]`, plus a prestige-currency slot that only appears once unlocked.

```lua
-- Header row: icons fixed-size, amounts flexible, rate right-aligned.
-- Horizontal UIListLayout + UIFlexItem(Fill) on the amount label lets the
-- amount absorb all slack without any width maths.
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalFlex = Enum.UIFlexMode.None
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)

local flex = Instance.new("UIFlexItem")
flex.FlexMode = Enum.UIFlexMode.Fill
flex.Parent = amountLabel
```

`UIFlexItem.FlexMode` supports `Fill`, `Grow`, `Shrink` and `Custom`; `UIListLayout.HorizontalFlex`/`VerticalFlex` distribute slack across the whole line. ([ui/list-flex-layouts.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/list-flex-layouts.md))

Rules: the header is the one place where a **rate** readout (`+1.23 Qa/s`) earns its screen space; make it a different, dimmer colour than the balance so the eye separates "how much" from "how fast". Never animate the header's *position* — it is the player's anchor.

### 4.2 The generator / upgrade row

The densest object in the game, and the one you virtualize. A survivable layout at phone width:

| Zone | Width | Content |
|---|---|---|
| Icon | 48 offset (square, `UIAspectRatioConstraint` 1:1) | `ImageLabel`, atlas rect |
| Body | flex `Fill` | line 1: name + `xN` owned · line 2: effect (`+1.23 M/s`) |
| Buy | 96–120 offset | cost (top), bulk label `x10` (bottom) |

Row height 64 offset on phone, 72 on desktop. Two text lines, not three — the third line is where mobile legibility dies.

```lua
export type RowView = {
    root: Frame, icon: ImageLabel, name: TextLabel, owned: TextLabel,
    effect: TextLabel, cost: TextLabel, buy: TextButton,
    -- shadow state for guarded writes (§2.2)
    shadow: { [string]: any },
    boundIndex: number?,
}
```

`UIAspectRatioConstraint` **overrides** the layout when both apply, which is exactly what you want for the icon: it stays square no matter what the list does to it. ([ui/size-modifiers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md))

### 4.3 Bulk-buy controls (x1 / x10 / x100 / Max)

A four-segment control, persistent, near the thumb. Its UI states are the part teams get wrong:

| State | Meaning | Rendering |
|---|---|---|
| Selected | active multiplier | filled, high-contrast |
| Unselected | available | outline only |
| Selected + unaffordable | you picked x100, you can afford 7 | selected chrome, but rows show **partial** cost in amber and the button reads `Buy 7` |
| `Max` with 0 affordable | nothing to buy | whole row disabled, not the segment |

**`Max` must show what it will actually do.** A `Max` button that says `Max` is a gamble; one that says `Max (37) — 1.23 Qa` is information. Compute the affordable count in closed form, never in a loop:

For a geometric cost curve `cost(n) = base * ratio^n` with `owned` already purchased and budget `B`, the number affordable is

```lua
-- Sum of a geometric series: base*r^owned * (r^k - 1)/(r - 1) <= B
-- =>  k <= log_r( 1 + B*(r-1) / (base*r^owned) )
local function maxAffordable(logBudget: number, logBase: number, ratio: number, owned: number): number
    local logR = math.log10(ratio)
    local logUnit = logBase + owned * logR           -- log10 of the next single cost
    local inner = 1 + 10 ^ (logBudget - logUnit) * (ratio - 1)
    if inner <= 1 then return 0 end
    return math.floor(math.log10(inner) / logR)
end
```

Working entirely in `log10` here is not an optimisation, it is a correctness requirement: `base * ratio^owned` overflows a double long before the player notices.

### 4.4 Prestige screen

One screen, one decision, three numbers: **what you gain**, **what you lose**, **when it becomes worth it**.

- Projected gain, large and central, with the delta since you last looked (`+3 since you opened this`).
- A log-scale bar to the *next* +1 of prestige currency, with a time-to-next readout (§6.2). This is the number that decides "reset now or in ten minutes".
- An explicit, scrollable "what is kept / what is reset" list. Never make this a tooltip.
- A confirmation that can be disabled in settings, and **must** be disabled by default after the first five prestiges — veteran players prestige constantly and a modal every time is hostile.

### 4.5 Achievements grid

`UIGridLayout` with square cells, `CellSize` in offset (not scale) so the cell count reflows with width instead of the tiles shrinking to illegibility. Three states: locked (greyscale + silhouette), in-progress (a thin bottom fill bar), unlocked (full colour + a subtle `UIGradient` sheen). **Virtualize it too** past ~60 tiles — a grid is a list with a stride.

### 4.6 Stats page

Pure text, two columns, right-aligned values, `UIListLayout` with section headers. Update at **1 Hz**, not 15 — nobody is watching "total time played" tick. Group as: this run / this prestige / all time. Include the unglamorous ones (total clicks, fastest prestige, offline time claimed); completionists read this page more than any other.

### 4.7 Settings page

Minimum viable set for this genre:

| Setting | Why it exists |
|---|---|
| **Notation** (§1.5) | The single most requested setting in every incremental game. |
| **Autosave interval** | Trust. Show "last saved 12s ago". |
| **Reduced effects** | Wire to `GuiService.ReducedMotionEnabled` as the *default*, but let players override. Roblox's accessibility guidance: set animation time to 0 or swap movement for fades. |
| **Background transparency** | Multiply your panel `BackgroundTransparency` by `GuiService.PreferredTransparency`. |
| **Text size** | Read `GuiService.PreferredTextSize` (`Medium`/`Large`/`Larger`/`Largest`) and scale your type ramp. |
| **Confirm prestige** | See §4.4. |
| **Offline progress popup** | Veterans want it suppressed. |

```lua
local GuiService = game:GetService("GuiService")

local function applyAccessibility(panel: Frame, baseTransparency: number)
    panel.BackgroundTransparency = baseTransparency * GuiService.PreferredTransparency
end
GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(refreshAll)
GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(refreshTypeRamp)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refreshMotion)
```

All three properties are documented as mapping directly to the player's Roblox **Settings** menu and are intended to be watched with `GetPropertyChangedSignal`. ([GuiService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml), [accessibility.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/accessibility.md))

### 4.8 Offline-progress "welcome back" modal

The most important retention surface in the genre. It must:

1. State the **elapsed time** in human units ("7 hours 12 minutes"), not seconds.
2. Show **what was earned**, itemised by currency, formatted in the player's notation.
3. Show the **cap** honestly if you cap offline earnings ("capped at 8h — upgrade to extend").
4. Offer a **doubling** or **claim** action if that is your monetisation, but never block dismissal behind it.
5. Appear **once**, after assets load, and never steal input from a player who is already tapping.

Compute offline gain **server-side** from the saved timestamp; the modal is a report, not a calculation. A client-computed offline reward is a duplication exploit with extra steps.

---

## 5. Affordability and feedback

### 5.1 Affordability as a first-class state

Four states, and you need all four:

| State | Colour | Button | Notes |
|---|---|---|---|
| Affordable | accent green | enabled | The default "go" state |
| Affordable soon (< ~10s away) | amber | enabled-looking, disabled | Gives the player a reason to wait instead of leaving |
| Unaffordable | muted grey | `Interactable = false` | Text dimmed, not hidden |
| Maxed / locked | outline only | `Interactable = false` | Distinct from unaffordable |

Use `GuiObject.Interactable` rather than reparenting or `Active`: it disables input while leaving the object visible and hoverable, and `GuiObject.GuiState` lets you read back the `Idle`/`Hover`/`Press` state the engine has assigned. ([GuiObject.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml))

**Never signal affordability with colour alone** — Roblox's accessibility guidance notes that over 5% of people are colour-blind and asks for "different symbols alongside colors." Pair the colour with a lock glyph, a check, or a filled-vs-outline button. ([accessibility.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/accessibility.md))

### 5.2 Hold-to-buy

```lua
--!strict
local HOLD_DELAY = 0.35   -- before repeat starts
local HOLD_MIN = 0.06     -- fastest repeat interval
local HOLD_RAMP = 0.85    -- interval multiplier per repeat

local function bindHoldToBuy(button: TextButton, buy: () -> boolean)
    local held = false
    button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        held = true
        if not buy() then return end                 -- first purchase is instant
        task.spawn(function()
            local interval = HOLD_DELAY
            while held do
                task.wait(interval)
                if not held then break end
                if not buy() then break end          -- stop the moment it fails
                interval = math.max(HOLD_MIN, interval * HOLD_RAMP)
            end
        end)
    end)
    local function release() held = false end
    button.InputEnded:Connect(release)
    button.MouseLeave:Connect(release)               -- finger slid off the button
end
```

Three details that matter: the **first press buys immediately** (a 350 ms delay on a single tap feels broken); the repeat **accelerates** rather than firing at a fixed rate; and the loop **stops on the first failed purchase** rather than hammering the server with rejections.

Server-side, hold-to-buy is a rate-limited batch: the client sends "buy N of X", the server validates affordability itself and replies with the count actually granted. Never send one remote per purchase.

### 5.3 Buy-max

`Max` uses §4.3's closed form, then issues **one** request. The UI updates optimistically (the local economy model already knows the answer) and reconciles when the server confirms. If the server grants fewer than requested — a race with an offline tick, say — snap the display to the authoritative value without an animation; a correcting animation reads as a bug.

### 5.4 Micro-feedback at 20 purchases per second

Purchases must feel good. At the rate a hold-to-buy produces them, naive feedback is a frame-rate crime: 20 `Instance.new` popups a second, 20 `Sound` instances, 20 tweens.

The rules:

1. **Pool the popups.** Pre-create 12 number-popup labels; take from a free list, return on completion. If the pool is empty, *aggregate into the oldest live popup* instead of allocating.
2. **Aggregate within a window.** Collapse purchases within ~120 ms into a single popup whose text is the sum and whose scale is bumped: `+12 x Miner` reads better than twelve overlapping `+1`s.
3. **Rate-limit sound.** One `Sound` per feedback class, replayed by setting `TimePosition = 0` and `:Play()`, with a minimum 60–80 ms gap; add a small `PlaybackSpeed` jitter (±4%) so repeats do not machine-gun. Beyond ~8 plays/second, drop to every third.
4. **Tween the cheap property.** A `UIScale.Scale` punch on one object is one tween. Scaling ten children is ten tweens and a layout invalidation. Put a `UIScale` on the row root and tween that.
5. **Particles are a desktop-only luxury.** Gate them behind the reduced-effects setting and default them off on `Enum.DisplaySize.Small` viewports.
6. **Honour reduced motion.** `GuiService.ReducedMotionEnabled` → skip the tween, apply the end state, keep the sound.

```lua
--!strict
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local PUNCH_IN  = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PUNCH_OUT = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function punch(scale: UIScale, amount: number?)
    if GuiService.ReducedMotionEnabled then return end
    scale.Scale = 1
    local up = TweenService:Create(scale, PUNCH_IN, { Scale = 1 + (amount or 0.08) })
    up.Completed:Once(function()
        TweenService:Create(scale, PUNCH_OUT, { Scale = 1 }):Play()
    end)
    up:Play()
end
```

---

## 6. Progress bars and charts

### 6.1 Log-scale progress

A linear bar toward `1e50` spends 99.999…% of its life visually at zero, then snaps full. It conveys nothing. Fill in **log space**:

```lua
--!strict
--- Fraction in [0,1] of progress from `start` to `goal` on a log scale.
--- All arguments are log10 values — never the raw numbers.
local function logProgress(logValue: number, logStart: number, logGoal: number): number
    if logGoal <= logStart then return 1 end
    return math.clamp((logValue - logStart) / (logGoal - logStart), 0, 1)
end

--- Quantize to whole pixels so §2.2's guard actually fires.
local function setBar(fill: Frame, fraction: number, barWidthPx: number, shadow: {n: number})
    local px = math.round(fraction * barWidthPx)
    if px == shadow.n then return end
    shadow.n = px
    fill.Size = UDim2.new(0, px, 1, 0)
end
```

Choosing `logStart` is the design decision. Three good options:

- **Previous milestone.** `logStart = log10(previousGoal)`. The bar resets to 0 on each milestone and fills across one "band". Best for tiered content.
- **Last order of magnitude.** `logStart = logGoal - 1`. The bar is "how close to the next power of ten" — extremely readable, always moving.
- **Current value at the moment the goal was set.** Honest, but the bar jumps when the goal changes.

**Always pair the bar with a numeric readout.** A log bar at 60% does not mean "60% of the resource"; it means "60% of the exponent gap". Label it `1.2e37 / 1e50` so nobody is misled.

### 6.2 Time-to-next-milestone

The naive `(goal - current) / rate` is wrong in this genre because `rate` itself is growing. Two tiers of answer:

```lua
--- Constant-rate ETA, in log space. Valid when production is flat.
local function etaConstant(logGoal: number, logCurrent: number, logRate: number): number
    if logCurrent >= logGoal then return 0 end
    -- (goal - current) / rate ~= goal / rate when goal >> current
    local logRemaining = logGoal + math.log10(1 - 10 ^ (logCurrent - logGoal))
    return 10 ^ (logRemaining - logRate)
end

--- Exponential-growth ETA: if the value multiplies by `growthPerSecond`
--- each second, time to reach the goal is a ratio of logs.
local function etaExponential(logGoal: number, logCurrent: number, logGrowthPerSec: number): number
    if logCurrent >= logGoal then return 0 end
    if logGrowthPerSec <= 0 then return math.huge end
    return (logGoal - logCurrent) / logGrowthPerSec
end
```

Display rules: `< 1s` → `"now"`; `< 60s` → `"12s"`; `< 1h` → `"4m 20s"`; `< 24h` → `"3h 12m"`; beyond → `"6d"`; non-finite or absurd → `"never"` (do **not** print `1.2e9 years`; it is noise). Recompute ETA at **2 Hz**, not 15 — a jittering countdown is worse than a slightly stale one.

### 6.3 In-UI graphs: frames vs EditableImage

Incremental players love a production-over-time graph. Two implementations:

| | **Frames (bar/step chart)** | **`EditableImage`** |
|---|---|---|
| What it is | N thin `Frame`s, one per sample, height = value | One raster you draw into and assign via `ImageLabel.ImageContent` |
| Instance cost | N GuiObjects (60 samples = 60 objects, plus axes) | **1** `ImageLabel` |
| Update cost | N guarded `Size` writes per redraw | One buffer write + one upload |
| Smooth lines | No — steps only, unless you rotate frames (expensive, aliased) | Yes — you control every pixel |
| Availability | Always | Gated behind the editable-asset permission model |
| Resolution | Unlimited (vector-ish) | **Max 1024×1024**, `Size` is read-only |
| Right for | ≤ 60 samples, bar/step style, any platform | Line charts, filled areas, dense histories, sparklines |

**Recommendation for this genre: frames.** A 60-sample step chart of "production per second over the last 60 seconds" is 60 `Frame`s, redrawn at 1 Hz, and it works on every device with no permission story. Reach for `EditableImage` only when you want a genuine line/area chart or a 300-point history.

```lua
--!strict
-- 60-sample ring buffer + step chart. Redraw at 1 Hz.
local SAMPLES = 60
local ring = table.create(SAMPLES, 0)
local head = 0

local function push(logValue: number)
    head = head % SAMPLES + 1
    ring[head] = logValue
end

local function redraw(bars: { Frame }, shadow: { number })
    -- Normalize in log space: charts of exponential growth are unreadable linearly.
    local lo, hi = math.huge, -math.huge
    for _, v in ring do
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    local span = math.max(hi - lo, 0.5) -- floor the span so a flat line isn't noise
    for i = 1, SAMPLES do
        local v = ring[(head + i - 1) % SAMPLES + 1]
        local frac = math.clamp((v - lo) / span, 0, 1)
        local q = math.round(frac * 100) -- 1% granularity == 1px on a 100px chart
        if shadow[i] ~= q then
            shadow[i] = q
            bars[i].Size = UDim2.new(1 / SAMPLES, -1, q / 100, 0)
        end
    end
end
```

For the `EditableImage` path — creation, the permission gate, `WritePixelsBuffer` layout, `Content.fromObject` lifetime and the 1024×1024 ceiling — see **chapter 20 (EditableImage API)** and **chapter 40 (EditableImage technique cookbook)**; this chapter does not duplicate them. The UI-side summary is: create once, keep a strong Luau reference, assign `ImageLabel.ImageContent = Content.fromObject(image)`, and redraw by writing a `buffer` rather than by issuing hundreds of draw calls.

---

## 7. Layout and platform

### 7.1 Scale, offset, and which to use where

`UDim2` mixes a **scale** fraction of the parent with an **offset** in pixels. The genre-specific rule:

- **Scale for structure** — panel widths, column splits, the fraction of the screen a list occupies. These should reflow.
- **Offset for anything a finger touches, and anything containing text** — row heights, button heights, icon sizes, paddings. These must not shrink on a small screen; a 6%-of-height button is 40 px on a phone and 90 px on a monitor, which is backwards.
- **Scale text separately** via a type ramp keyed off `GuiService.PreferredTextSize` and the viewport class, not via `TextScaled`.

Roblox explicitly recommends avoiding `TextScaled` for on-screen UI in favour of `AutomaticSize`, warning that "some text may become unreadable if scaled too small," and suggests `UITextSizeConstraint` to bound it when you do use it. For dense numeric UI, `TextScaled` is actively harmful: it makes each label's font size depend on its *content*, so a column of numbers renders at four different sizes. **Fix your `TextSize` per type ramp step and let long values truncate or abbreviate.** ([TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml))

### 7.2 A single `UIScale` at the root beats a thousand tweaks

`UIScale` "multiplies the `AbsoluteSize` of the parent `GuiObject`." Put one on the root frame of each screen and drive it from viewport width. This scales offset pixels too, which is exactly what you want for the desktop→phone transition. ([ui/size-modifiers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md))

```lua
--!strict
-- Reference design width; scale down on narrow screens, up (a little) on wide.
local DESIGN_WIDTH = 1280
local function computeScale(viewport: Vector2): number
    local s = viewport.X / DESIGN_WIDTH
    -- Never shrink below 0.55 (text becomes illegible) and never blow past 1.25.
    return math.clamp(s, 0.55, 1.25)
end
```

Caveat: `UIScale` scales the *rendered* size, so a 48-offset button under a 0.6 scale is a 29-pixel touch target. **Compute touch-target sizes after the scale**, or clamp the scale so your minimum target survives (§7.3).

`UIAspectRatioConstraint` locks width:height and **overrides** a parent layout when both apply — use it for square icons, avatar thumbnails and fixed-ratio panels so nothing stretches. ([ui/size-modifiers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md))

### 7.3 Touch targets

Roblox's own documentation does not publish a minimum tap-target size `[UNVERIFIED — I searched the accessibility and UI guides and found none]`. The platform guidelines do, and they agree closely: **Apple HIG specifies 44×44 pt; Android/Material specifies 48×48 dp.** Roblox `ScreenGui` offset pixels are not identical to either unit, but on a typical phone the practical translation is **44–48 offset pixels minimum, 56+ preferred for a primary action**.

Concrete consequences for an incremental UI:

- Buy button: **≥ 48 offset tall, ≥ 88 wide** (it holds a cost string).
- Bulk-buy segments: 4 segments across a phone's ~360-pt width leaves ~80 each — fine, but only if the bar spans the full width.
- Tab bar: ≥ 48 tall. Use `UIListLayout.HorizontalFlex = Fill` so tabs divide the width evenly regardless of count — the docs name exactly this as the canonical flex use case. ([ui/list-flex-layouts.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/list-flex-layouts.md))
- **Gap between adjacent targets ≥ 8 offset.** Adjacent buy buttons in a dense list are the #1 source of mis-taps and refund requests.

### 7.4 Safe areas and the top bar

Three mechanisms, and you need all three:

1. **`ScreenGui.ScreenInsets`** — defaults to `CoreUISafeInsets`, which "keeps all descendant `GuiObjects` inside the core UI safe area, clear of the Roblox top bar buttons and other screen cutouts like the device's camera notch." Leave it alone for gameplay UI. Setting `IgnoreGuiInset = true` switches it to `DeviceSafeInsets`. ([ScreenGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScreenGui.yaml))
2. **`GuiService.TopbarInset`** — a `Rect` of "the unoccupied area between the Roblox left-most controls and the edge of the device safe area." It is **dynamic**: it changes when core UI controls appear or resize, so the docs recommend detecting and reacting to changes rather than reading it once. If you put a currency header at the top, this is the rectangle you must fit inside. ([GuiService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml))
3. **`GuiService:GetInsetArea(insets)`** — returns the usable `Rect` for a given `ScreenInsets` value, relative to `CoreUISafeInsets`; the docs give a real mobile example returning `-59, -58, 792, 334`. Use it when you need a full-bleed background *behind* inset content. ([GuiService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml))

`ScreenGui.SafeAreaCompatibility` applies automatic compatibility transformations to descendant "fullscreen" objects on cutout displays, where eligibility requires the object to cover the safe area on both axes. Know it exists before you fight it. ([ScreenGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScreenGui.yaml))

### 7.5 One-handed reachability

A phone held in one hand has a comfortable thumb arc covering roughly the **bottom 55% and the horizontal centre**. Therefore:

- **Buy buttons on the right edge, vertically centred-to-low.** The list scrolls under the thumb; the thumb never travels.
- **Bulk-buy bar pinned to the bottom**, above any nav bar, not floating mid-screen.
- **Tabs at the bottom on phone, at the top on desktop.** This is the one place a layout genuinely differs by platform, and it is worth it.
- **Nothing important in the top-left**: that is the Roblox top bar's territory and the hardest place for a thumb to reach.
- **Modals: confirm on the right, dismiss on the left**, both in the bottom third.

### 7.6 Should you ship a distinct mobile layout?

**No — ship one tree with a breakpoint.** A separate mobile layout tree means every feature is built twice, every bug is fixed twice, and the two drift within a month. What actually differs between phone and desktop in this genre is small and parameterisable:

| Parameter | Phone | Desktop |
|---|---|---|
| Tab bar position | bottom | top |
| Upgrade list | 1 column | 2–3 columns |
| Row height (offset) | 64 | 72 |
| Simultaneous panels | 1 | 2 (list + detail side by side) |
| Tooltips | tap-to-open sheet | hover |
| Header readouts | 3 | 5 |

```lua
--!strict
local GuiService = game:GetService("GuiService")

export type Breakpoint = "phone" | "tablet" | "desktop"

local function classify(viewport: Vector2): Breakpoint
    -- Width in offset pixels is the honest signal; DisplaySize is a coarse hint.
    if viewport.X < 700 then return "phone" end
    if viewport.X < 1100 then return "tablet" end
    return "desktop"
end

-- GuiService.ViewportDisplaySize is Small (mobile/tablet/handheld),
-- Medium (laptops/monitors) or Large (TVs), and is watchable for changes.
local function isTenFoot(): boolean
    return GuiService:IsTenFootInterface()
        or GuiService.ViewportDisplaySize == Enum.DisplaySize.Large
end
```

`GuiService.ViewportDisplaySize` is documented as `Small` = "most tablet/mobile/handheld devices", `Medium` = "most laptops and monitors", `Large` = "most TVs or larger", and the docs explicitly suggest listening via `GetPropertyChangedSignal` "to adapt UI to various display sizes". On a TV, also turn on gamepad navigation (`GuiService.GuiNavigationEnabled`, `GuiObject.NextSelectionUp/Down/Left/Right`, `SelectionOrder`) — a virtualized list needs its `NextSelection*` links rebuilt on every rebind. ([GuiService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml), [GuiObject.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml))

---

## 8. Architecture

### 8.1 The workload, stated precisely

This is not a generic "which UI framework" question. The workload is specific and unusual:

- **~100–300 reactive numeric bindings live at once**, of which **20–60 change every flush**.
- **Structure is almost static.** Rows are recycled, not created; tabs toggle visibility. Mount/unmount churn is near zero after the first frame.
- **Updates are pushed, high-frequency and independent.** One currency changing should not touch the achievements grid.
- **Every wasted Instance write costs on mobile**, which is the majority platform.

That profile inverts the usual trade-offs. Frameworks optimised for *structural* change (VDOM diffing, reconciliation) are paying for something this UI never does, while frameworks with **fine-grained reactivity** — an update touching exactly the effects that read the changed value — map onto it perfectly.

### 8.2 The comparison

| | **Vide** | **Fusion** | **React-Lua** | **Plain OOP + dirty flags** |
|---|---|---|---|---|
| Model | Fine-grained, Solid-style: `source` / `derive` / `effect` | Fine-grained: `Value` / `Computed` / `Observer`, inside a `scope` | VDOM: re-run component fn, diff, reconcile | Manual bindings and a dirty set |
| Update path for one changed number | Push to the source's direct children, flush a queue, run only the affected effects | Recompute dependent `Computed`s, notify `Observer`s | Re-run the owning component (and children unless memoised), diff its tree, commit | Mark one binding dirty; flush writes one property |
| Per-update allocation | Low — queue is reused | Moderate — scope bookkeeping | Higher — element tables per render | Zero |
| Cost of 60 independent changes/flush | ~60 effects | ~60 computed+observer chains | 60 component re-renders + diffs, or one big re-render if state is hoisted | 60 guarded property writes |
| Structural change cost | Manual, explicit | Manual, explicit | Excellent — its whole point | Manual, painful |
| Version / status (Sep 2026) | **0.4.1** stable, MIT ([wally.toml](https://github.com/centau/vide/blob/main/wally.toml)) | `main` is **0.4.0-dev1** — 0.4 not yet released; 0.3 is the shipping API, MIT ([wally.toml](https://github.com/dphfox/Fusion/blob/main/wally.toml)) | Actively maintained community fork of Roblox's internal React Lua, MIT ([jsdotlua/react-lua](https://github.com/jsdotlua/react-lua)) | Immortal |
| Typing | "Fully Luau typecheckable" (README claim) | Good | Good (Luau annotations, translated from ReactJS 17.x) | As good as you write |
| Team ramp-up | Small API, ~half a day | Medium (scopes and destruction semantics) | Low **if** the team knows React | Low, but every project reinvents it |
| Ecosystem | Small | Medium | Largest (React mental model, hooks, devtools-adjacent tooling) | None |

Vide's update mechanism is worth reading directly, because it is the thing that makes it fit. `src/graph.luau` maintains a single reused `update_queue`; `update_descendants` calls `queue_children_for_update` on the changed source and then drains the queue, re-queueing children only for nodes that actually changed. There is a `flags.batch` short-circuit so a batch defers the flush. That is precisely the architecture §2.3 describes by hand — you get the dirty-set scheduler for free, and correctly. ([centau/vide `src/graph.luau`](https://github.com/centau/vide/blob/main/src/graph.luau))

React-Lua is "a comprehensive, but not exhaustive, translation of upstream ReactJS 17.x into Lua," maintained as a community fork because "Roblox's repository is a read-only mirror of their internal project." It is the strongest choice for *structurally* complex UI — wizards, editors, deeply nested conditional trees. It is the weakest choice for 200 numbers ticking at 15 Hz, because every one of those ticks goes through a component re-run and a diff unless you carefully route it around React with an imperative ref — at which point you have written §2.3 anyway, inside a framework that is charging you for machinery you bypassed. ([jsdotlua/react-lua](https://github.com/jsdotlua/react-lua))

### 8.3 Recommendation

**Use Vide.** Its fine-grained reactivity means an updated source touches exactly the effects that read it — no component re-execution, no tree diff — which is the exact shape of a UI where hundreds of independent numbers change constantly; it is at a stable tagged release (0.4.1), it is small enough to read end to end, and its scheduler is the pattern you would otherwise hand-write.

Three caveats, stated honestly:

1. **Vide is a small project.** Fewer stars, fewer contributors, and a smaller hiring pool than React-Lua. If your studio already runs React-Lua across several games, the consistency is worth more than the per-update efficiency — **use React-Lua and route the hot numeric path through imperative refs** and a §2.3 scheduler, keeping React for structure only. That is a legitimate, defensible architecture.
2. **Fusion is not a mistake, but time it.** `main` sits at `0.4.0-dev1`; 0.3 is what you would actually ship against, and the 0.3→0.4 scope/destruction changes are significant. Starting a multi-year project on a pre-release API boundary is avoidable risk.
3. **Even with a framework, keep the virtualized list imperative.** Row recycling wants direct control of ~12 row objects and their `Position`/`Text`/`Visible`. Wrap it as one component with an imperative core; do not express 300 rows as 300 reactive components and hope the framework culls them. It will not.

Whatever you pick, **`--!strict` on every UI module and `--!native` on the formatter**. The formatter is small, hot, numeric and allocation-light — the exact profile native codegen helps.

### 8.4 How UI state should observe game state

The rule: **UI depends on a read-only projection of game state; game state knows nothing about UI.**

```
 simulation (server-authoritative)
        │  replicated deltas
        ▼
 client economy model  ── pure Luau, no Instances, testable headless
        │  publishes
        ▼
 view models  ── plain tables: { logCost, logEffect, owned, canAfford, ... }
        │  observed by
        ▼
 bindings / reactive sources ── the ONLY layer that touches Instances
```

- **Never let a UI module reach into the simulation.** It reads view models. This is what makes the economy unit-testable under Lune with no DataModel.
- **The view model is recomputed on the UI clock (15 Hz), not on every simulation tick.** One pass produces every derived value the screen needs (§2.4), so `canAfford` is computed once and read by four widgets.
- **Diff at the view-model boundary, not inside widgets.** The view model is where "did anything actually change?" is answered, using the quantization from §1.4. Widgets downstream of an unchanged view model do nothing.
- **Replication carries state, not text.** The server sends numbers (or `{mantissa, exponent}` pairs); the client formats. Never send pre-formatted strings — you would be sending the player's notation setting to the server and burning bandwidth on ASCII.
- **One event bus for discrete things** (purchase succeeded, achievement unlocked, prestige completed) so feedback (§5.4) subscribes without the economy knowing feedback exists.

---

## 9. Polish

Polish is cheap here because the UI is flat and mostly static chrome. Five things carry most of the perceived quality:

**`UIGradient`.** A two-stop vertical gradient at 4–8% contrast on every panel reads as "designed" rather than "default Frame". Animate `Offset` (not `Color`) for a sheen sweep on an unlock; one property, one tween. `UIGradient` applies to a `CanvasGroup`'s flattened result as a whole, which is the cleanest way to tint a composed panel. ([CanvasGroup.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml))

**`UIStroke`.** One stroke on the row root, not on each child. `ApplyStrokeMode = Border` keeps it outside the fill; use colour, not thickness, to signal state (thickness changes re-layout perception and reads as jitter in a scrolling list).

**9-slice panels.** One small source image, `ScaleType = Slice`, `SliceCenter` set with Studio's 9-Slice Editor. Every panel in the game can be the same asset at any size, which collapses your texture budget to near zero and keeps corner radii pixel-crisp where `UICorner` would soften them. Note the editor's offsets are expressed as pixels from each edge, not as the `SliceCenter` rect values. ([ui/9-slice.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/9-slice.md))

**Icon atlases.** One sheet, addressed with `ImageLabel.ImageRectOffset` / `ImageRectSize`. Roblox's performance guidance names this directly: "consider using sprite sheets to load many smaller UI images as a single image. You can then use `ImageLabel.ImageRectOffset` and `ImageRectSize` to display portions of the sheet." For a game with 80 generator icons this is the difference between 80 asset loads with staggered pop-in and one. Keep a generated Luau table mapping icon name → `Rect` so nothing hard-codes pixel offsets. ([performance-optimization/improve.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md))

**Custom fonts.** `FontFace` accepts fonts outside `Enum.Font`. Pick one with unambiguous digits and — ideally — tabular figures (§1.3). Two weights is enough: one for numbers, one for labels. ([TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml))

**Animation, tastefully.** In a UI where everything already moves, animation must be *rare* to mean anything. Animate: purchases (a 200 ms scale punch), unlocks (a sheen sweep), tab changes (120 ms cross-fade), prestige (the one place a big flourish is earned). Do **not** animate: numbers counting up (they are already changing), list scroll (the engine does it), panel entry on every tab press (it becomes latency). Always check `GuiService.ReducedMotionEnabled` first, and for the typewriter-style reveal `MaxVisibleGraphemes` is the built-in mechanism. ([ui/animation.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/animation.md), [TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml))

**Runtime-generated imagery.** `EditableImage` can produce icon variants (tinted/tiered versions of one base), procedural panel backgrounds and the line charts of §6.3 — see chapters 20 and 40 for the API, the permission gate and the 1024×1024 ceiling. For a *UI* use case the decision rule is: if a static atlas can do it, use the atlas; `EditableImage` earns its place only when the image depends on runtime data.

---

## 10. Performance budget

### 10.1 The frame-time target, not the FPS target

Roblox's MicroProfiler documentation is blunt about this: "The MicroProfiler focuses **entirely on frame time**." 16.67 ms is 60 FPS, 33.3 ms is 30 FPS — and **consistency matters more than the average**: "if 59 frames arrive in 10 milliseconds and one frame in 410 milliseconds, players perceive a huge, jarring stutter, even though the game is running at 60 FPS." ([microprofiler/index.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/index.md))

That is the whole argument for the dirty-flag scheduler over a periodic full re-render: a full re-render of 300 rows is exactly the 410 ms frame that ruins the session. **Budget UI work at ≤ 2 ms per frame on your worst target device, and never allow a burst above 8 ms.**

Also note the trap the same doc names: "Powerful devices like gaming desktops can actually obscure performance problems." Profile on a real mid-range Android phone or you are measuring nothing.

### 10.2 The three costs of UI

| Cost | MicroProfiler tag | Roblox's own remedy |
|---|---|---|
| **Preparing 2D UI** | `Prepare/Pass2d` — "Readies 2D UI rendering (both player and Roblox UI)." | "Reduce the amount or complexity of UI elements." |
| **Building UI vertices** | `Perform/fillGuiVertices` — "Fills buffers with UI vertices… **gui count** label indicates the amount of `LayerCollectors` visible in the frame." | "If the cost is high, reduce the amount, density, and space taken by UI elements. **If there are too many `Process GuiEffect` labels, consider reducing the use of `UIGradient` and `UICorner` on text labels.**" |
| **Drawing UI** | `Perform/Scene/UI` — "In **Id_Screen**, there is a label with the number of batches, materials and triangles used." | "Reduce the number of visible UI elements. **Using `CanvasGroups` can help at the expense of increased memory use.**" |

([microprofiler/tag-table.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/tag-table.md))

Three things follow directly, and they are the most actionable facts in this chapter:

1. **`UIGradient` and `UICorner` on `TextLabel`s are explicitly called out as a cost.** In an incremental UI you have hundreds of text labels. Put gradients and corners on *panel* frames, not on every label and not on every row child. If you want rounded rows, one `UICorner` on the row root.
2. **`CanvasGroup` is a stated trade: rendering cost down, memory up.** Combined with the class documentation — it "consumes extra texture memory", is "limited by the `QualityLevel` of the client", "will render as a blank texture" past the cap, and is "recommended… with static sizes" — the rule is: use a `CanvasGroup` for a *modal or panel you fade as a whole*, at a fixed size. Never for a scrolling list (its size and content change constantly), never one per row. ([CanvasGroup.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml))
3. **`gui count` counts `LayerCollector`s, not GuiObjects.** Splitting your UI across 20 `ScreenGui`s to manage `DisplayOrder` has a measurable cost. Use **one `ScreenGui` per z-layer that genuinely needs one** (world HUD / main UI / modals / toasts ≈ 4), not one per screen.

### 10.3 A working budget

These are engineering targets to design to and then verify, not published limits. `[UNVERIFIED — Roblox publishes no GuiObject count limit; these come from the budget arithmetic below and should be validated on your own target device.]`

| Metric | Mid-range phone target | Notes |
|---|---|---|
| Live `GuiObject`s in the DataModel | **≤ 1,500** | Virtualization is what makes this achievable with 300 upgrades |
| Visible `GuiObject`s in a frame | **≤ 600** | Hidden panels should be `Visible = false`, not off-screen |
| `TextLabel`s with *changing* text | **≤ 300 live, ≤ 60 changed per flush** | §1.4's cache is what keeps the second number low |
| `ScreenGui`s (`LayerCollector`s) | **≤ 5** | `gui count` in `fillGuiVertices` |
| `UIGradient` + `UICorner` on text labels | **0** | Named remedy in the tag table |
| `CanvasGroup`s alive | **≤ 3**, fixed size | Texture memory, quality-capped |
| UI script time per frame | **≤ 2 ms**, burst ≤ 8 ms | Your `debug.profilebegin("UI.flush")` bar |

The arithmetic behind "≤ 1,500": a dense screen is a header (~25 objects) + a virtualized list of 14 visible rows × 12 (~170) + a bulk-buy bar (~15) + a tab bar (~20) + chrome (~60) ≈ **290 objects for the active screen**. Four such screens preloaded and hidden ≈ 1,200. That leaves headroom. Without virtualization, one 300-row list alone is 3,600 and the budget is gone before you have drawn anything else.

### 10.4 Measuring it

1. **Instrument first.** Wrap every UI subsystem in `debug.profilebegin` / `debug.profileend` — the docs describe exactly this: "Wrap code with `debug.profilebegin()` and `debug.profileend()` to time everything done between those function calls and create a label on the MicroProfiler timeline." Use stable names: `UI.flush`, `UI.virtualList.rebind`, `UI.format`, `UI.feedback`. ([microprofiler/index.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/index.md))
2. **Capture on device**, not in Studio. Use the frame-time graph to find a spike, then the detailed timeline to attribute it; right-click a label to zoom to exactly that task's duration.
3. **Watch the three tags from §10.2** specifically. If `Perform/Scene/UI` dominates, you have too many visible elements. If `fillGuiVertices` dominates with many `Process GuiEffect` labels, you have gradients/corners on text. If `Prepare/Pass2d` dominates, your tree is too complex — usually an un-virtualized list.
4. **Count your instances in-game**, continuously, in a debug overlay:

```lua
--!strict
local function countGui(root: Instance): (number, number, number)
    local total, visible, text = 0, 0, 0
    for _, d in root:GetDescendants() do
        if d:IsA("GuiObject") then
            total += 1
            if d.Visible then visible += 1 end
            if d:IsA("TextLabel") or d:IsA("TextButton") then text += 1 end
        end
    end
    return total, visible, text
end
-- Run this once every 5 seconds behind a debug flag; GetDescendants on a large
-- tree is itself expensive, so never run it on the UI clock.
```

5. **Regression-gate it.** Log the three counts and the `UI.flush` duration to your analytics on a 1-in-1000 session sample. An upgrade list that quietly stopped virtualizing shows up as a step change in `visible`, weeks before it shows up in a review.

---

## Number formatting reference

### Standard suffix tiers

`tier = floor(exponent / 3)`. Values below verified by executing the transcribed algorithm from [antimatter-dimensions/notations `src/utils.ts`](https://github.com/antimatter-dimensions/notations/blob/master/src/utils.ts).

| tier | magnitude | suffix | | tier | magnitude | suffix |
|---|---|---|---|---|---|---|
| 1 | 1e3 | `K` | | 13 | 1e39 | `DDc` |
| 2 | 1e6 | `M` | | 14 | 1e42 | `TDc` |
| 3 | 1e9 | `B` | | 15 | 1e45 | `QaDc` |
| 4 | 1e12 | `T` | | 16 | 1e48 | `QtDc` |
| 5 | 1e15 | `Qa` | | 17 | 1e51 | `SxDc` |
| 6 | 1e18 | **`Qt`** | | 18 | 1e54 | `SpDc` |
| 7 | 1e21 | `Sx` | | 19 | 1e57 | `ODc` |
| 8 | 1e24 | `Sp` | | 20 | 1e60 | `NDc` |
| 9 | 1e27 | `Oc` | | 21 | 1e63 | `Vg` |
| 10 | 1e30 | `No` | | 33 | 1e99 | `DTg` |
| 11 | 1e33 | `Dc` | | 101 | 1e303 | `Ce` |
| 12 | 1e36 | `UDc` | | 1001 | 1e3003 | `MI` |

**The trap:** quintillion is **`Qt`**, quadrillion is `Qa`. `Qi` exists but means *quinquagint*- (the tens row, tier 51 → 1e153 territory). Shipping `Qi` for 1e18 is the classic bug; players report it within a day.

### Letters notation

Base-26 over the engineering exponent (`exponent / 3`), lowercase:

| magnitude | letters | | magnitude | letters |
|---|---|---|---|---|
| 1e3 | `a` | | 1e81 | `aa` |
| 1e6 | `b` | | 1e84 | `ab` |
| 1e78 | `z` | | 1e2106 | `zz` |
| | | | 1e2109 | `aaa` |

### One value in every notation

`v = 1.23456e15`, three significant figures:

| Notation | Output | Rule |
|---|---|---|
| Standard | `1.23 Qa` | mantissa in `[1,1000)`, suffix by tier |
| Scientific | `1.23e15` | mantissa in `[1,10)` |
| Engineering | `1.23e15` | mantissa in `[1,1000)`, exponent ≡ 0 (mod 3) |
| Letters | `1.23e` | mantissa in `[1,1000)`, base-26 exponent |
| Logarithm | `e15.091` | `log10` of the whole value |
| Hyper-E | `E15.091` | `Ex` ≡ `10^x`; `Ex#n` ≡ `n` nested powers of ten |
| Arrow | `10↑15.091` | `a↑b` = `a^b`, `a↑↑b` = tetration, `a↑↑↑b` = pentation |
| Mixed | `1.23 Qa` | Standard below a threshold, Scientific above |

Hyper-E and arrow notations only carry information once the value itself is layered (`{sign, layer, mag}`, §1.1). With a `{mantissa, exponent}` type, `E15.091` and `e15.091` are the same string with a different prefix — ship them only if your number type reaches tetration. `[UNVERIFIED — Hyper-E is Sbiis Saibian's notation; the `Ex#n` nesting convention above is the form used by idle-game implementations such as Eternal Notations, not a formal citation.]`

### Display rules cheat sheet

| Range | Render as | Example |
|---|---|---|
| `v == 0` | `0` | `0` |
| `0 < v < 1` | 2 decimals | `0.42` |
| `1 ≤ v < 1000` | integer, no suffix | `1`, `42`, `999` |
| `1000 ≤ v` | notation-specific, 3 sig figs | `1.23 K` |
| `v` is negative | prefix `-`, never parentheses | `-1.23 K` |
| `v` is `inf`/`nan` | `"∞"` / `"—"`, and log an error | your value type has a bug |

- Right-align every numeric column. Split mantissa and suffix into adjacent labels if your font lacks tabular figures.
- Rates always carry a unit (`/s`), always in a dimmer colour than the balance.
- Costs the player cannot afford stay legible — dim them, never hide them.
- Never localise the suffixes. `K`/`M`/`B` are genre vocabulary, not English.

---

## The virtualized list implementation

A complete, working recycling `ScrollingFrame`. Fixed row height, absolute positioning, guarded writes, overscan, and correct handling of momentum scrolling. Drop-in: supply a `createRow` factory and a `bindRow` function.

```lua
--!strict
-- VirtualList.luau
-- A recycling list for a ScrollingFrame with a fixed row height.
-- Instantiates ceil(viewport / rowHeight) + 2*OVERSCAN rows and re-binds them
-- as the canvas scrolls. Row count is independent of data count.

local RunService = game:GetService("RunService")

local OVERSCAN = 2 -- extra rows above and below the viewport

export type RowHandle = {
    root: GuiObject,
    -- Free-form per-row shadow state for guarded writes (§2.2).
    shadow: { [string]: any },
}

export type Config<T> = {
    scrollingFrame: ScrollingFrame,
    rowHeight: number,                            -- in OFFSET pixels
    createRow: () -> RowHandle,                   -- called at most `poolSize` times
    bindRow: (row: RowHandle, item: T, index: number) -> (),
    unbindRow: ((row: RowHandle) -> ())?,         -- optional: for hidden slots
}

local VirtualList = {}
VirtualList.__index = VirtualList

export type VirtualList<T> = typeof(setmetatable(
    {} :: {
        _cfg: Config<T>,
        _data: { T },
        _pool: { RowHandle },
        _boundIndex: { number },  -- pool slot -> data index currently bound (0 = none)
        _poolSize: number,
        _firstVisible: number,
        _conns: { RBXScriptConnection },
        _heartbeat: RBXScriptConnection?,
        _dirtyData: boolean,
    },
    VirtualList
))

local function ensurePool<T>(self: VirtualList<T>)
    local cfg = self._cfg
    -- AbsoluteWindowSize excludes the scrollbar gutter; AbsoluteSize does not.
    local viewport = cfg.scrollingFrame.AbsoluteWindowSize.Y
    local needed = math.ceil(viewport / cfg.rowHeight) + OVERSCAN * 2
    -- Never shrink the pool: rows are cheap to keep and expensive to churn.
    if needed <= self._poolSize then
        return
    end
    for _ = self._poolSize + 1, needed do
        local row = cfg.createRow()
        row.root.AnchorPoint = Vector2.zero
        row.root.Size = UDim2.new(1, 0, 0, cfg.rowHeight)
        row.root.Visible = false
        row.root.Parent = cfg.scrollingFrame
        table.insert(self._pool, row)
        table.insert(self._boundIndex, 0)
    end
    self._poolSize = needed
end

--- The only function that touches Instances during a scroll.
local function refresh<T>(self: VirtualList<T>, force: boolean)
    local cfg = self._cfg
    local data = self._data
    local n = #data

    local scrollY = cfg.scrollingFrame.CanvasPosition.Y
    local first = math.max(1, math.floor(scrollY / cfg.rowHeight) + 1 - OVERSCAN)

    -- Fast path: nothing moved far enough to change which rows are bound.
    if not force and first == self._firstVisible then
        return
    end
    self._firstVisible = first

    debug.profilebegin("UI.virtualList.rebind")
    for slot = 1, self._poolSize do
        local row = self._pool[slot]
        local index = first + slot - 1

        if index < 1 or index > n then
            -- Off the end of the data: park the slot.
            if self._boundIndex[slot] ~= 0 then
                self._boundIndex[slot] = 0
                row.root.Visible = false
                if cfg.unbindRow then cfg.unbindRow(row) end
            end
            continue
        end

        -- Position: absolute offset, computed, never laid out.
        local y = (index - 1) * cfg.rowHeight
        local pos = UDim2.new(0, 0, 0, y)
        if row.shadow.__y ~= y then
            row.shadow.__y = y
            row.root.Position = pos
        end

        if row.shadow.__visible ~= true then
            row.shadow.__visible = true
            row.root.Visible = true
        end

        -- Only re-bind content when the data index actually changed.
        -- Scrolling by one row leaves poolSize-1 slots doing zero content work.
        if force or self._boundIndex[slot] ~= index then
            self._boundIndex[slot] = index
            cfg.bindRow(row, data[index], index)
        end
    end
    debug.profileend()
end

function VirtualList.new<T>(cfg: Config<T>): VirtualList<T>
    local self = setmetatable({
        _cfg = cfg,
        _data = {},
        _pool = {},
        _boundIndex = {},
        _poolSize = 0,
        _firstVisible = -1, -- sentinel forces the first refresh
        _conns = {},
        _heartbeat = nil,
        _dirtyData = false,
    }, VirtualList) :: VirtualList<T>

    local sf = cfg.scrollingFrame
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None -- we own CanvasSize
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.CanvasSize = UDim2.fromOffset(0, 0)

    table.insert(self._conns, sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        refresh(self, false)
    end))
    -- The viewport can change from a rotation, a window resize, a scrollbar
    -- appearing, or a UIScale change. All of them move AbsoluteWindowSize.
    table.insert(self._conns, sf:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
        ensurePool(self)
        refresh(self, true)
    end))

    -- Momentum scrolling on touch keeps CanvasPosition moving after the finger
    -- leaves. The property signal covers it, but a coasting frame is also the
    -- moment a dropped rebind is most visible, so we top up on the UI clock.
    local acc = 0
    self._heartbeat = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 1 / 15 then return end
        acc = 0
        if self._dirtyData then
            self._dirtyData = false
            refresh(self, true)
        elseif sf:GetScrollVelocity().Magnitude > 0 then
            refresh(self, false)
        end
    end)

    ensurePool(self)
    return self
end

--- Replace the backing data. Cheap: no Instances are created or destroyed.
function VirtualList.setData<T>(self: VirtualList<T>, data: { T })
    self._data = data
    local h = #data * self._cfg.rowHeight
    local want = UDim2.fromOffset(0, h)
    if self._cfg.scrollingFrame.CanvasSize ~= want then
        self._cfg.scrollingFrame.CanvasSize = want
    end
    self._firstVisible = -1
    refresh(self, true)
end

--- Call when the CONTENT of already-bound rows changed (costs changed, a
--- purchase landed) but the ordering did not. Deferred to the UI clock.
function VirtualList.invalidate<T>(self: VirtualList<T>)
    self._dirtyData = true
end

--- Re-bind exactly one data index, if it happens to be on screen.
function VirtualList.invalidateIndex<T>(self: VirtualList<T>, index: number)
    for slot = 1, self._poolSize do
        if self._boundIndex[slot] == index then
            self._cfg.bindRow(self._pool[slot], self._data[index], index)
            return
        end
    end
end

function VirtualList.scrollToIndex<T>(self: VirtualList<T>, index: number)
    local y = (index - 1) * self._cfg.rowHeight
    self._cfg.scrollingFrame.CanvasPosition = Vector2.new(0, y)
end

function VirtualList.destroy<T>(self: VirtualList<T>)
    for _, c in self._conns do c:Disconnect() end
    table.clear(self._conns)
    if self._heartbeat then self._heartbeat:Disconnect(); self._heartbeat = nil end
    for _, row in self._pool do row.root:Destroy() end
    table.clear(self._pool)
    table.clear(self._boundIndex)
    self._poolSize = 0
end

return VirtualList
```

### Using it for an upgrade list

```lua
--!strict
local NumericBinding = require(script.Parent.NumericBinding)
local NotationSetting = require(script.Parent.NotationSetting)

local list = VirtualList.new({
    scrollingFrame = upgradesScroll,
    rowHeight = 64,

    createRow = function()
        local root = rowTemplate:Clone() -- a prebuilt Frame in ReplicatedStorage
        local handle = {
            root = root,
            shadow = {},
        }
        -- Attach per-label numeric bindings ONCE, at pool construction.
        handle.shadow.costBinding =
            NumericBinding.new(root.Buy.Cost, NotationSetting.get())
        handle.shadow.effectBinding =
            NumericBinding.new(root.Body.Effect, NotationSetting.get())
        return handle
    end,

    bindRow = function(row, item, index)
        local s = row.shadow
        -- Guarded writes: scrolling one row rebinds one slot, not twelve.
        if s.name ~= item.name then
            s.name = item.name
            row.root.Body.Name.Text = item.name
        end
        if s.icon ~= item.iconRect then
            s.icon = item.iconRect
            row.root.Icon.ImageRectOffset = item.iconRect.Min
            row.root.Icon.ImageRectSize = item.iconRect.Max - item.iconRect.Min
        end
        if s.owned ~= item.owned then
            s.owned = item.owned
            row.root.Body.Owned.Text = "x" .. item.owned
        end
        s.costBinding:set(item.cost)     -- own quantize + write guard (§1.4)
        s.effectBinding:set(item.effect)

        if s.canAfford ~= item.canAfford then
            s.canAfford = item.canAfford
            row.root.Buy.BackgroundColor3 = if item.canAfford then AFFORD else DENY
            row.root.Buy.Interactable = item.canAfford
            row.root.Buy.Lock.Visible = not item.canAfford -- symbol, not just colour
        end

        s.dataIndex = index -- so the button handler knows what it is buying
    end,

    unbindRow = function(row)
        row.shadow.dataIndex = nil
    end,
})

list:setData(viewModel.upgrades)

-- On the UI clock, after the view model is recomputed (§2.4):
list:invalidate()
```

### Correctness checklist

- [ ] `AutomaticCanvasSize = None` — you own `CanvasSize`.
- [ ] No `UIListLayout` inside the canvas. Positions are computed.
- [ ] Viewport read from **`AbsoluteWindowSize`**, not `AbsoluteSize`.
- [ ] Pool grows but never shrinks.
- [ ] `OVERSCAN ≥ 1`; 2 for touch.
- [ ] Rebind is guarded per property; unchanged slots do zero engine writes.
- [ ] `GetScrollVelocity()` polled so momentum scrolling keeps rebinding.
- [ ] Button handlers read `row.shadow.dataIndex`, never a captured index — a recycled row's identity changes.
- [ ] `ZIndex` untouched: rows never overlap, so there is nothing to order.
- [ ] On gamepad, `NextSelectionUp/Down` are rebuilt on every rebind, or selection escapes the list.

---

## Sources

All Roblox API and guide citations are to the `Roblox/creator-docs` repository on GitHub, which is the source of truth published at `create.roblox.com`. Fetched and read September 2026.

### Roblox engine reference (`content/en-us/reference/engine/classes/`)

| Class | Used for |
|---|---|
| [GuiObject.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml) | `Interactable`, `GuiState`, `AutomaticSize`, `LayoutOrder`, `NextSelection*`, `SelectionOrder`, touch events |
| [ScrollingFrame.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml) | `CanvasPosition`, `CanvasSize`, `AutomaticCanvasSize`, **`AbsoluteWindowSize`** ("AbsoluteSize minus the space occupied by any currently visible scroll bar gutters"), `GetScrollVelocity()`, `ElasticBehavior` |
| [TextLabel.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml) | `Text`/`ContentText`/`TextBounds`/`TextFits` derivation, `TextScaled` warning, `OpenTypeFeatures` + `OpenTypeFeaturesError`, `FontFace`, `MaxVisibleGraphemes`, `TextTruncate` |
| [CanvasGroup.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml) | "consumes extra texture memory", `QualityLevel` cap, "render as a blank texture", "use with static sizes" |
| [ScreenGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScreenGui.yaml) | `ScreenInsets` (`CoreUISafeInsets` default), `SafeAreaCompatibility`, `IgnoreGuiInset`, `DisplayOrder` |
| [GuiService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml) | `TopbarInset`, `GetInsetArea()`, `GetGuiInset()`, `ViewportDisplaySize`, `PreferredTextSize`, `PreferredTransparency`, `ReducedMotionEnabled`, `IsTenFootInterface()` |
| [RunService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/RunService.yaml) | `PreRender` blocks rendering; `PreRender`/`PreSimulation` supersede `RenderStepped`/`Stepped`; `Heartbeat` semantics |
| Also read: [Frame](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Frame.yaml), [TextButton](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextButton.yaml), [ImageLabel](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ImageLabel.yaml), [ImageButton](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ImageButton.yaml), [UIListLayout](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIListLayout.yaml), [UIGridLayout](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIGridLayout.yaml), [UIFlexItem](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIFlexItem.yaml), [UIPadding](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIPadding.yaml), [UICorner](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UICorner.yaml), [UIStroke](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIStroke.yaml), [UIGradient](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIGradient.yaml), [UIScale](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIScale.yaml), [UIAspectRatioConstraint](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIAspectRatioConstraint.yaml) | layout, modifiers | |
| Datatypes: [UDim2](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/UDim2.yaml), [UDim](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/UDim.yaml), [NumberSequence](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/NumberSequence.yaml), [ColorSequence](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/ColorSequence.yaml), [Vector2](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/Vector2.yaml) | scale/offset, gradient stops | |

### Roblox guides (`content/en-us/`)

- [ui/index.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/index.md), [ui/frames.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/frames.md), [ui/labels.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/labels.md), [ui/buttons.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/buttons.md), [ui/scrolling-frames.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/scrolling-frames.md)
- [ui/list-flex-layouts.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/list-flex-layouts.md) — `HorizontalFlex`/`VerticalFlex`, `ItemLineAlignment`, `UIFlexItem.FlexMode` (`Fill`/`Grow`/`Shrink`/`Custom`), the tab-bar flex use case
- [ui/grid-table-layouts.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/grid-table-layouts.md), [ui/page-layouts.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/page-layouts.md)
- [ui/size-modifiers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md) — `UIScale` multiplies `AbsoluteSize`; `UIAspectRatioConstraint` **overrides** a parent layout
- [ui/position-and-size.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/position-and-size.md), [ui/on-screen-containers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/on-screen-containers.md), [ui/in-experience-containers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/in-experience-containers.md)
- [ui/appearance-modifiers.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/appearance-modifiers.md), [ui/9-slice.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/9-slice.md), [ui/styling/index.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/styling/index.md)
- [ui/animation.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/animation.md), [ui/rich-text.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/rich-text.md), [ui/viewport-frames.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/viewport-frames.md)
- [performance-optimization/microprofiler/index.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/index.md) — frame time over FPS, consistency, `debug.profilebegin`/`profileend`, the desktop-obscures-problems warning
- [performance-optimization/microprofiler/tag-table.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/tag-table.md) — **`Prepare/Pass2d`**, **`Perform/fillGuiVertices`** (`gui count` = visible `LayerCollector`s; reduce `UIGradient`/`UICorner` on text labels), **`Perform/Scene/UI`** / `Id_Screen` (CanvasGroups trade memory for render cost)
- [performance-optimization/improve.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md) — sprite sheets via `ImageRectOffset`/`ImageRectSize`; texture memory scales with pixel count
- [performance-optimization/identify.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/identify.md), [performance-optimization/design.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/design.md)
- [production/publishing/accessibility.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/accessibility.md) — reduced motion, `PreferredTransparency`, contrast, >5% colour-blindness, "different symbols alongside colors"

### Number formatting and big-number libraries

- [antimatter-dimensions/notations](https://github.com/antimatter-dimensions/notations) (MIT) — the canonical notation set. [`src/utils.ts`](https://github.com/antimatter-dimensions/notations/blob/master/src/utils.ts) is the source for `STANDARD_ABBREVIATIONS`, `STANDARD_PREFIXES`, `STANDARD_PREFIXES_2` and `abbreviateStandard`, all transcribed into Luau in §1.2 and verified by execution. [`src/custom.ts`](https://github.com/antimatter-dimensions/notations/blob/master/src/custom.ts) is the source for the base-26 letters transcription. API is `format(value, places, placesUnder1000)`.
- [Patashu/break_infinity.js](https://github.com/Patashu/break_infinity.js) — the `{mantissa, exponent}` model.
- [Patashu/break_eternity.js](https://github.com/Patashu/break_eternity.js) — the `{sign, layer, mag}` model, required for hyper-E/arrow notations.

### UI frameworks

- [centau/vide](https://github.com/centau/vide) (MIT) — "a reactive Luau UI library inspired by Solid", "fully Luau typecheckable". Version **0.4.1** per [wally.toml](https://github.com/centau/vide/blob/main/wally.toml). Reactive graph read directly at [`src/graph.luau`](https://github.com/centau/vide/blob/main/src/graph.luau): a single reused `update_queue`, `queue_children_for_update` / `flush_update_queue` / `update_descendants`, and a `flags.batch` deferral.
- [dphfox/Fusion](https://github.com/dphfox/Fusion) (MIT) — `main` is **`0.4.0-dev1`** per [wally.toml](https://github.com/dphfox/Fusion/blob/main/wally.toml); 0.3 is the shipping API.
- [jsdotlua/react-lua](https://github.com/jsdotlua/react-lua) (MIT) — "a comprehensive, but not exhaustive, translation of upstream ReactJS 17.x into Lua"; a community fork because "Roblox's repository is a read-only mirror of their internal project".

### Community, second-hand

`[COMMUNITY, SECOND-HAND]` — DevForum returns 403 to this research environment; these were surfaced via web search result summaries only and corroborate the *technique*, not any specific figure:

- ["How do I optimize a scrolling frame for over 1000 frames?"](https://devforum.roblox.com/t/how-do-i-optimize-a-scrolling-frame-for-over-1000-frames/952022)
- ["Virtual scrolling? (List virtualization)"](https://devforum.roblox.com/t/virtual-scrolling-list-virtualization/2732175)
- ["VirtualScroller | Infinite ScrollingFrames"](https://devforum.roblox.com/t/virtualscroller-infinite-scrollingframes/3990429)
- ["How to make a Virtual scrolling system using scrollingframe with over 1k frames"](https://devforum.roblox.com/t/how-to-make-a-virtual-scrolling-system-using-scrollingframe-with-over-1k-frames/3791129)

### Non-Roblox platform guidance

- Apple Human Interface Guidelines: minimum tap target **44×44 pt**.
- Material Design / Android accessibility: minimum touch target **48×48 dp**.

Both are cited in §7.3 because Roblox publishes no equivalent figure. `[UNVERIFIED — the translation from pt/dp to Roblox offset pixels is approximate and should be validated with Studio's Device Emulator on your target devices.]`

### Cross-references within this corpus

- **Chapter 20 — EditableImage API** and **chapter 40 — EditableImage technique cookbook**: the permission gate, `WritePixelsBuffer` layout, `Content.fromObject` lifetime, the 1024×1024 ceiling. §6.3 and §9 defer to them rather than duplicating.
- **Chapter 22 — Luau performance engineering**: `--!native`, `buffer`, the task scheduler. §1.4 and §2.1 assume it.
- **Chapter 25 — UI construction**: flex layout, 9-slice, ViewportFrame, atlases as general craft. This chapter is the incremental-genre specialisation of it.
- **Chapter 46 — Code architecture & frameworks**: the general framework argument. §8 is the UI-specific counterpart and reaches a different conclusion for a different reason (fine-grained reactivity fits this workload; a general-purpose game framework does not).
- **Chapter 50 — Optimization & shipping**: the MicroProfiler in general. §10 is the UI slice of it.

---

*End of chapter 63.*
