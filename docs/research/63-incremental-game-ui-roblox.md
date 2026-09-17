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

- **Never store big values as Luau `number`.** A double loses integer exactness past `2^53` and dies at `~1.8e308`. Incremental games routinely exceed both. Store `{mantissa, exponent}` (a `break_infinity`-style `Decimal`) or, at minimum, a `log10` float — and format from the exponent, never from the raw value. (§1)
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

Three options, in increasing capability:

1. **`log10` float.** Store `log10(v)` as a double. Multiplication becomes addition, exponentiation becomes multiplication, and the representable range becomes `10^(±1.7e308)` — effectively infinite for a game. Cost: addition is lossy and awkward (`log10(a+b) = log10(a) + log10(1 + 10^(log10(b)-log10(a)))`), and small values lose precision near zero. Good for pure-multiplicative economies. **Formatting is trivial: you already have the exponent.**
2. **`{mantissa, exponent}` ("`Decimal`", the `break_infinity` model).** Mantissa normalized to `[1, 10)`, exponent a double. Range up to `10^1.79e308`. Exact-ish to ~15 significant digits. This is what Antimatter Dimensions and most of the genre use. ([break_infinity.js](https://github.com/Patashu/break_infinity.js))
3. **`{sign, layer, mag}` ("`break_eternity`" model).** `layer` counts how many times you have taken a log. `layer=0` → the value is `mag`; `layer=1` → `10^mag`; `layer=2` → `10^10^mag`. This is what you need if your game reaches tetrational scales, and it is the *only* representation for which arrow/hyper-E notations mean anything. ([break_eternity.js](https://github.com/Patashu/break_eternity.js))

> `[COMMUNITY, SECOND-HAND]` Luau ports of both exist (`break_infinity.lua`-style modules circulate on the DevForum and on GitHub). Verify arithmetic against a reference implementation with a property test before shipping — the normalization edge cases around `0`, negative values and `mag` crossing `1e15` are where ports go wrong.

**For the rest of this chapter the value type is assumed to expose `v.mantissa` (in `[1,10)`) and `v.exponent`.** Everything in the formatter reads only those two fields, which means it is `O(1)` regardless of how large the number is — this is the single most important property of a good formatter.

```lua
--!strict
-- The minimal surface the UI needs from whatever big-number type you pick.
export type Big = {
    mantissa: number, -- normalized to [1, 10), or 0 when the value is 0
    exponent: number, -- base-10 exponent
}

local function fromNumber(n: number): Big
    if n == 0 then return { mantissa = 0, exponent = 0 } end
    local e = math.floor(math.log10(math.abs(n)))
    return { mantissa = n / 10 ^ e, exponent = e }
end
```

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

