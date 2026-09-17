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

