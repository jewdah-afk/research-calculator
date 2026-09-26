# UI kit for Substance Painter

The game's buttons and plates are 9-sliced textures from this kit. Until you paint them, the game uses the
procedural interim textures in `base/` (bevelled, chamfered, brushed). Paint over them in Substance Painter, share
the exports, and the next build puts your textures in the game.

| Slot | In game (px) | 9-slice corners | Tinted | Used for |
|---|---|---|---|---|
| `cta` | 512 × 128 | 36 | yes, by the layer hue | the panel's big action (PRESTIGE…), the BUY bars, primary and START buttons |
| `button` | 384 × 96 | 28 | no | secondary buttons, dialog buttons, locked actions, the close button |
| `tile` | 160 × 160 | 44 | no | the dock tiles (HOME, TROPHIES, OPTIONS) |
| `panel` | 512 × 512 | 110 | no | the layer panel's frame |
| `plate` | 256 × 128 | 36 | no | HUD plates: points, toasts, READY tray |

**Tinted** slots are multiplied by the layer's colour in the game: paint them in greys (white shows the full hue,
black stays black). The other slots keep the colours you paint.

**9-slice:** the corners (inside the orange lines on the guides) are drawn 1:1, the edges stretch along their
length, and the middle stretches both ways. Put the detail (bevels, chamfers, bolts, wear) in the corners and along the
edges; keep the middle calm, because it stretches.

## Paint

1. **New project:** File › New, mesh `meshes/ui_kit.obj`, document resolution **2048**, normal map format OpenGL.
   Painter makes one texture set per slot (`cta`, `button`, `tile`, `panel`, `plate`).
2. Each plane's UVs cover only the **top part** of its texture (the slot's own aspect ratio, so texels stay square).
   The rest of the texture is unused. `guides/<slot>.png` shows the slot's outline and its 9-slice lines in that
   layout: drop it in as a fill layer (projection UV, 50 % opacity) while you work, then hide it.
3. Paint. The chamfered outline in `base/` is the shape the game expects; anything outside it should be transparent
   (use an opacity channel: Texture Set Settings › add channel **Opacity**).
4. **Bake the look into the colour:** the game shows one flat image (no lighting), so add a **Baked Lighting
   Stylized** filter (or your own light/shadow layers) on top so the bevels read.

## Export

File › Export Textures:

* Output directory: `art/substance/painted/`
* Output template: **PNG, RGBA**: RGB = Base Color (with the baked lighting), A = Opacity. The file name must be the
  texture set's name: `$textureSet` (so you get `cta.png`, `button.png`, …). `ui_kit_cta.png` or
  `cta_BaseColor.png` also work.
* Size: 2048. Export the slots you painted; unpainted slots keep their interim texture.

## Share

Double-click **`share_art.bat`** in the `milestone-tree` folder. It commits `art/substance/painted/` and pushes.
Then tell Claude "art is pushed": it runs `python3 substance/kit.py build` (crops and scales your exports, packs the
1024 atlas), uploads it (`node gems/upload.js --kit ui`), and the game picks the new id up from
`src/shared/UiKit.luau`.

## Rebuild the kit (Claude)

```sh
cd art
python3 substance/kit.py prep      # meshes/ui_kit.obj, guides/, base/ (the interim textures)
python3 substance/kit.py build     # painted/ over base/ -> out/ui_kit.png + ui_kit.json
node gems/upload.js --kit ui       # upload when the image changed -> src/shared/UiKit.luau
```
