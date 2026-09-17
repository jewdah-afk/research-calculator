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
