# Icons

The icons are PNGs drawn in a flat vector style in the chunky mobile-game style: a thick black outline with a hard drop, a flat base tone, a darker rim along the bottom-right, a lighter band along the top, and one white highlight.

- **Source:** `art/vector/icons.mjs`. Each icon is a few shapes on a 128 grid; facets are placed by hand and every part draws its own outline over the parts behind it.
- **Build:** `NODE_PATH=<dir with playwright> node art/vector/build.mjs` writes `art/icons/*.png` (512px, for Roblox), `art/icons/ui/*.png` (128px, for the preview) and `art/icons_sheet.png` (review sheet, also at UI sizes on tiles). The build fails if any icon reaches the edge of its canvas.
- **Preview:** `node art/vector/embed.mjs docs/preview.html` embeds the 128px PNGs.
- **Stat icons:** Rune Bulk = `rune_bulk`, Rune Speed = `bolt_blue`, Rune Luck = `clover`, Clone Chance = `dice`, Clone Amount = `clone`, Tickrate = `stopwatch`.

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
