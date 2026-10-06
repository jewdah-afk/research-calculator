# Icons

The icons are 3D renders made in Blender (Cycles), in the same toy-plastic style as the original icon set.

**To regenerate them:**

```
blender -b -P art/make_icons.py -- art/icons [name ...]
```

- Each icon is a 256px transparent PNG.
- Leave the names off to render every icon.

**In Roblox:** upload the PNGs as Decals and put their asset ids in `client/UI/Assets.luau`.

**Rune stones** (`rune0`–`rune9`): a deep-toned tablet with a raised glyph that glows in the rune's own colour.
