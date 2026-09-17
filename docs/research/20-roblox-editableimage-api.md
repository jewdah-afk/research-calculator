# Roblox `EditableImage`: The Definitive Internal Reference

> **Scope.** Everything a team needs to build runtime image generation on Roblox: creation,
> the verification gate, memory budgets, the pixel buffer format, the drawing API, every
> display sink, performance, uploading, and the version churn that makes most tutorials wrong.
>
> **Verification rule used throughout.** Every API claim in this document is traceable to a
> URL listed in [Sources](#sources) — primarily the machine-generated YAML in
> `Roblox/creator-docs`, which is the same source the rendered documentation site is built
> from. Anything not confirmed there is marked `[UNVERIFIED]` or
> `[COMMUNITY, SECOND-HAND]`. Nothing is guessed.
>
> **Docs snapshot:** `Roblox/creator-docs@main`, fetched 2026-09-17.

---

## Table of contents

1. [TL;DR for builders](#tldr-for-builders)
2. [The verification gate](#the-verification-gate)
3. [Verified API surface](#verified-api-surface)
4. [Creation and lifecycle](#1-creation-and-lifecycle)
5. [Size and memory](#2-size-and-memory)
6. [Pixel access: the buffer format](#3-pixel-access-the-buffer-format)
7. [The drawing API](#4-the-drawing-api)
8. [Display sinks: where an EditableImage can actually appear](#5-display-sinks-where-an-editableimage-can-actually-appear)
9. [Performance and the cost model](#6-performance-and-the-cost-model)
10. [Parallel Luau and thread safety](#7-parallel-luau-and-thread-safety)
11. [Saving and uploading generated images](#8-saving-and-uploading-generated-images)
12. [Gotchas](#gotchas)
13. [Version churn: what changed and what stale tutorials get wrong](#version-churn-what-changed-and-what-stale-tutorials-get-wrong)
14. [Sources](#sources)

