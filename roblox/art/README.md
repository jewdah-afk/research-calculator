# Icons

The icons are the painted set in `art/source/icon_sheet.png`, cut out into transparent PNGs.

- **Cut:** `python3 art/cut_icons.py art/source/icon_sheet.png <dir>` finds each icon on the sheet, removes the background and the name labels, and saves `<name>.png`.
- **Export:** `python3 art/export_icons.py <dir>` writes `art/icons/*.png` (512px, for Roblox) and `art/icons/ui/*.png` (128px, for the preview).
- **Preview:** `node art/vector/embed.mjs docs/preview.html` embeds the 128px PNGs.
- **Stat icons:** Rune Bulk = `rune_bulk`, Rune Speed = `bolt_blue`, Rune Luck = `clover`, Clone Chance = `dice`, Clone Amount = `clone`, Tickrate = `stopwatch`.
- **To replace one icon:** drop a transparent PNG with the same name into the cut folder and run the export again.
- The older vector set (`art/vector/icons.mjs`, Figma file https://www.figma.com/design/x27MW6WNYnrQj1dR1yYHd7) is kept for reference; its build now writes to `art/vector/out/` so it never overwrites these.

**In Roblox:** upload the PNGs as Decals and put their asset ids in `client/UI/Assets.luau`.

---

Older pipeline (Blender renders, now superseded):

The icons are 3D renders made in Blender (Cycles), in the same toy-plastic style as the original icon set.

**To regenerate them:**

```
blender -b -P art/make_icons.py -- art/icons [name ...]
```

- Each icon is a 256px transparent PNG.
- Leave the names off to render every icon.

**In Roblox:** upload the PNGs as Decals and put their asset ids in `client/UI/Assets.luau`.

**Rune stones** (`rune0`–`rune9`): a deep-toned tablet with a raised glyph that glows in the rune's own colour.

**Outline step:** after rendering, run `python3 art/outline.py <render dir> art/icons` to add the black sticker outline.
