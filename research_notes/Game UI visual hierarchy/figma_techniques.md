# Figma Techniques for Chunky Bevelled Game UI (and Roblox Hand-off), 2026

## Which Figma features matter most?

### Takeaway
For chunky bevelled game UI, the features that matter most are stacked effects (up to 8 inner and 8 drop shadows per layer, noise and texture), variables with modes for rarity, tower colour and state theming, and component variants. Glass, progressive blur and texture are now native, but they do not survive export to Roblox, so treat them as baked-image or mockup-only features.

### Cited Findings
- Figma has seven effect types: Glass, drop shadow, inner shadow, layer blur, background blur, noise and texture. Per-layer limits are 8 drop shadows, 8 inner shadows, 1 layer blur, 2 noise, 1 texture, 1 background blur and 1 glass, with only one layer or background blur per object — [Figma Help: Apply effects](https://help.figma.com/hc/en-us/articles/360041488473-Apply-effects-to-layers)
- Noise comes in Mono, Duo or Multi, with size, density and colour or opacity controls. Texture has a size, a radius and a "clip to shape" option. Layer and background blur each have Uniform or Progressive modes, and Progressive lets you set the start, end, direction and intensity — [Figma Help](https://help.figma.com/hc/en-us/articles/360041488473-Apply-effects-to-layers)
- The Plugin API added noise, texture and progressive blur effect types (all beta) in Update 110, May 2025 — [Figma dev docs Update 110](https://developers.figma.com/docs/plugins/updates/2025/05/07/version-1-update-110/); [Effect API](https://developers.figma.com/docs/plugins/api/Effect)
- Glass came out of beta on January 27, 2026. It now applies to any object or text and gained non-uniform corners, a Splay property and variable binding — [Figma forum: Glass out of beta](https://forum.figma.com/product-updates-3/glass-is-officially-out-of-beta-50185). Glass effects disappear on CSS or Flutter export — [Figma forum](https://forum.figma.com/report-a-problem-6/glass-effect-does-not-export-to-flutter-51026)
- Variables hold solid colours only, not gradients. Designers pair colour variables with paint styles for gradients, and individual gradient stops can be bound to colour variables. A feature request is still open as of July 2026 — [Figma forum](https://forum.figma.com/suggest-a-feature-11/support-gradient-values-in-variables-56401)
- Extended collections inherit a parent collection's variables and modes and let you override values, which suits themes or brands. Creating them through the Plugin API (Update 121, Nov 2025) is limited to the Enterprise plan — [REST variables types](https://developers.figma.com/docs/rest-api/variables-types); [Update 121](https://developers.figma.com/docs/plugins/updates/2025/11/20/version-1-update-121)

### Inferences
- Bevel button recipe, top to bottom. The body has a linear gradient fill (light top, mid bottom). On the body, stack inner shadows: (1) white at 0,+4, blur 0, about 50% for a hard top highlight; (2) darker tone at 0,-6, blur 0 for the bottom lip; (3) a soft dark inner glow, blur 8. Add a thick outer dark stroke of 3 to 4 px with the position set to Outside. Under the body, place a duplicate shape offset 0,+6 in the darker "base" colour for the chunky 3D underside. Finish with a hard drop shadow (0,+4, blur 0, about 25% black). Add a gloss ellipse on the top half at about 30% white, masked to the body. Optionally add 1 Mono noise effect at low opacity for texture. Every hard shadow (blur 0) maps cleanly to Roblox (see below).
- Rarity and tower colour theming. Create a "Palette" primitive collection and a "Role" collection with one mode per rarity (Common, Rare, Epic, Legendary, Mythic). Give it the variables fill-top, fill-bottom, base, stroke, highlight and text-stroke. Bind gradient stops to these variables, then swap the mode on a card instance to recolour the whole card. Put states (default, hover, pressed, disabled) in component variants. A pressed state removes the base layer and shifts the body down 4 to 6 px.
- Use auto layout with min and max width plus hug for buttons and currency pills. These map to AutomaticSize and UISizeConstraint in Roblox.

### Gaps
- I did not find authoritative 2026 documentation of a native "shader" fill feature for end users in Figma. The Figma MCP exposes create_shader and list_shaders tools, which suggests shader support exists, but I could not verify its scope from public docs.
- I found no pro game UI artist's written Figma bevel tutorial (the search results were generic). The recipe above is synthesized, not sourced.

## How do pro game UI artists build bevelled, glossy or sticker-style buttons?

### Takeaway
Searches turned up only generic inner-shadow guidance. The established approach is layer stacks: base, body, highlight, gloss and outline, with hard inner shadows standing in for bevels.

### Cited Findings
- A drop shadow makes an object read as raised and an inner shadow reads as pressed in, which supports using the raised look for the default state and inner shadow for the pressed state — [Skyeng guide](https://skyeng.ru/it-industry/design/sozdaniye-teney-dlya-obyektov-v-figma-poshagovaya-instruktsiya/)
- One bevel method sets an inner shadow to white with the light source at one corner (here using the Beautiful Shadows plugin) — [Skillbox](https://skillbox.ru/media/design/figma-dimensional-object-1/)

### Inferences
- Sticker style: outline the text and shape, then add a thick white Outside stroke plus a dark second outline. A layer has only one stroke, so duplicate the layer, or wrap it in a frame with its own stroke. On Roblox, this becomes two UIStrokes with different ZIndex values.

### Gaps
- Specific Config talks or artist videos on this topic were not found or verified.

## Building a design-system token set for a game

### Takeaway
Use variables in three tiers: primitive colours, semantic roles with modes per rarity or tower colour, and number variables for spacing, radius, stroke width and type size. Gradients stay as styles built from bound stops.

### Cited Findings
- Variables are solid colour only, so gradients go in paint styles with variable-bound stops — [Figma forum](https://forum.figma.com/suggest-a-feature-11/support-gradient-values-in-variables-56401)
- Extended collections suit theme variations that share one source of truth — [Figma REST docs](https://developers.figma.com/docs/rest-api/variables-types)
- Glass properties can now be bound to variables — [Figma forum](https://forum.figma.com/product-updates-3/glass-is-officially-out-of-beta-50185)

### Inferences
- Suggested number tokens: radius (8, 12, 16, pill), stroke (2, 3, 4), elevation as base-lip offset (0, 4, 6, 8), spacing on a 4-pt scale, and type scale in the 14/18/24/32/48 range with a chunky display font. Name the tokens after their Roblox counterparts (strokeThickness, cornerRadius) to ease the Luau theme-table export.
- Elevation for flat cartoon UI is the base-lip offset plus a hard shadow, not blur depth.

### Gaps
- No sourced game-specific token taxonomy was found.

## Figma to Roblox: what translates and what does not

### Takeaway
Most of the structure maps to native Roblox objects: rounded rects to UICorner, strokes to UIStroke (now with Inner, Outer and Center positions and ZIndex stacking), linear, radial and conical gradients to UIGradient, and drop shadows to UIShadow (beta). Multi-inner-shadow bevels, noise, texture, blur and glass have to be baked into 9-slice images.

### Cited Findings
- UIStroke properties include Thickness, Color, Transparency, ApplyStrokeMode (Contextual or Border, for text), BorderStrokePosition (Center, Inner or Outer), BorderOffset, LineJoinMode (Round, Bevel or Miter), StrokeSizingMode and ZIndex. Sibling strokes with the same ZIndex render in undefined order. A UIGradient child gives a gradient stroke. Tweening Thickness on text causes flicker and performance issues. Some properties need the "Improved UIStrokes" beta — [UIStroke reference](https://create.roblox.com/docs/en-us/reference/engine/classes/UIStroke.md)
- UIGradient has Color (ColorSequence), Transparency (NumberSequence), Type (Linear, Radial or Conical), Offset, Rotation, Scale and TileMode (Clamp, Repeat or Mirror). Rotation has no effect on a Radial gradient. Fill and stroke gradients are independent — [Appearance modifiers](https://create.roblox.com/docs/en-us/ui/appearance-modifiers.md)
- UICorner supports per-corner radii, and a Scale of 0.5 or more gives a pill shape. UIShadow (upgraded version in beta) offers Mode (Shape or Text), BlurRadius, Offset, Spread, Inset, ShowBehindParent, ZIndex and a UIGradient child. It follows UICorner, and Spread, Inset and ShowBehindParent do not work in Text mode — [Appearance modifiers](https://create.roblox.com/docs/en-us/ui/appearance-modifiers.md)
- For 9-slice, set ScaleType to Slice on an ImageLabel or ImageButton and set SliceCenter in the 9-Slice Editor. The editor's offsets (pixels from each image edge) differ from the raw SliceCenter property values. Corners do not scale, edges stretch along one axis and the centre stretches both ways — [Roblox 9-slice docs](https://create.roblox.com/docs/ui/9-slice)
- With roimport, autolayouts become layout objects and strokes come through with the `_stroke` tag. Inner shadows convert to inner strokes, but only the spread value is supported. Radial, angular and diamond gradients, dashed strokes and brush strokes export as images, and layer-blur objects are grayscaled. Tags include `_Slice`, `_2x`/`_3x`, `_UIList`, `_Grid` and `_Button` — [DevForum roimport](https://devforum.roblox.com/t/free-figma-to-roblox-plugin-roimport/4731967)

### Inferences
- Mapping cheat sheet:
  - Auto layout maps to UIListLayout. Wrap maps to UIGridLayout or a wrapping UIListLayout.
  - Hug maps to AutomaticSize. Min and max sizes map to UISizeConstraint.
  - A fixed aspect maps to UIAspectRatioConstraint.
  - The design-resolution difference maps to UIScale.
  - Text maps to TextLabel with RichText. Use Roblox fonts such as Fredoka One or Luckiest Guy, because custom fonts must match a Roblox font family.
- To export a 9-slice: build the panel at 1x with fixed corners, export a PNG at 2x, and set SliceCenter in source pixels. Then use SliceScale (not documented on the page fetched) to keep corners crisp at 1x.
- Pitfalls:
  - Figma inside and outside stroke positions only match Roblox if you set BorderStrokePosition.
  - Roblox gradients are limited to Linear, Radial and Conical, so diamond gradients are not supported.
  - Blur-0 hard inner shadows can be faked with a nested frame plus an inner UIStroke or UIShadow Inset.
  - Mixing offset and scale sizing causes drift across devices.

### Gaps
- I did not verify the UIGradient keypoint limit (believed to be 20) or the exact UIShadow beta status as of October 2026.
- The SliceScale details were not on the page I fetched.

## Useful plugins

### Takeaway
Several Figma-to-Roblox exporters are active in 2026, and all of them come from the DevForum community. None is first-party.

### Cited Findings
- UILint v2: a Figma plugin with a Studio companion that lints the design and rebuilds the hierarchy. The free tier covers linting and manual export, and Smart Sync and Live Sync are paid — [DevForum](https://devforum.roblox.com/t/plugin-uilint-v2-import-figma-ui-into-roblox-studio/4765869)
- roimport: free, tag-based, supports reimport, and can auto-upload images with an API key through a local bridge — [DevForum](https://devforum.roblox.com/t/free-figma-to-roblox-plugin-roimport/4731967)
- UI Designer Pro (a Figma plugin paired with a Studio plugin) — [DevForum](https://devforum.roblox.com/t/plugin-ui-designer-pro/4685902); GuiForge — [DevForum](https://devforum.roblox.com/t/guiforge-roblox-ui-editorfigma-export/4834077); FigBloxUI (active thread in July 2026) — [DevForum figma tag](https://devforum.roblox.com/tag/figma)
- Beautiful Shadows, a plugin for building bevel shadows — [Skillbox](https://skillbox.ru/media/design/figma-dimensional-object-1/)

### Gaps
- I did not check pricing, reliability or reviews for these plugins. General Figma game-UI plugins and community UI kits were not researched in depth.
