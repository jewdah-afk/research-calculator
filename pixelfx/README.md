# PixelFX: EditableImage effect library

Pure-Luau pixel effects that write RGBA8 buffers in the layout `EditableImage:WritePixelsBuffer` expects.
Every effect also runs headless, so it can be timed and diffed outside Studio.

## Using it in Roblox
```lua
local AssetService = game:GetService("AssetService")
local Core = require(PixelFX.Core)
local Lightning = require(PixelFX.fx.Lichtenberg)

local img = AssetService:CreateEditableImage({ Size = Vector2.new(96, 96) }) -- nil if the memory budget is spent
label.ImageContent = Content.fromObject(img)
local canvas = Core.canvas(96, 96)
local fx = Lightning.new(96, 96)
fx:strike(48, 2)
RunService.Heartbeat:Connect(function(dt)
	fx:step(dt); fx:render(canvas); Core.present(canvas, img)
end)
```
Folder layout in Studio: `PixelFX` (ModuleScript = Core) with a child Folder `fx`, or Core and `fx` as siblings under one Folder. Each effect requires `script.Parent.Parent.Core`.

Pixels are stored straight-alpha. `Core.add` blends additively, so glow composites correctly over the game.

## Effects
| Module | Algorithm | VS use | Headless cost (96×96, interpreter) |
|---|---|---|---|
| `Lichtenberg` | Dielectric breakdown model, fast incremental point-charge potential (Kim & Lin 2007) | Lightning Ring, Thunder Loop strikes | strike 42 ms (precompute a pool), frame 1 ms |
| `Physarum` | Jones 2010 slime-mould agents: sense, turn, deposit, diffuse, decay | Corruption, Mudman sludge, curse aura | 3.4 ms / 2000 agents |
| `WaveRing` | 2D damped wave equation, leapfrog, with slope specular | Garlic / Soul Eater pulse | 1.4–20 ms (varies between runs) |
| `FrostDLA` | Diffusion-limited aggregation with arrival-order reveal and shimmer | Clock Lancet / Orologion freeze frost | grow 30 ms once, frame <1 ms |
| `JumpFloodOutline` | Jump Flooding distance field, outline and breathing glow | Selected card, evolved glow, co-op outlines, chest reveal halo | build 33 ms once per sprite |
| `BlueNoiseDissolve` | Void-and-cluster blue noise, threshold dissolve with burning edge | Enemy death, chest vanish | noise 39 ms once (cache), frame <1 ms |
| `Bloom` | Bright pass, half res, 3× running-sum box blur ≈ Gaussian | Crits, evolved projectiles, chest light | 6 ms |
| `PaletteDither` | Floyd–Steinberg (serpentine) or Bayer 4×4, nearest colour in OKLab | Snap any effect to the stage palette; portrait filter | 11 ms (FS) |
| `Phyllotaxis` | Vogel spiral, staggered unfurl | Celestial Dusting, Garlic petals, level-up burst | <1 ms |
| `OrbitTrails` | Spring-driven orbiters (substepped), Lissajous option, persistence trails | King Bible, Unholy Vespers, Peachone/Ebony Wings | <1 ms |
| `FabrikChain` | FABRIK IK with joint angle limits, tapered render | Bloody Tear lash, tethers, chained enemies | <0.1 ms |
| `CaveCA` | Hash-seeded 4-5 cellular automaton per chunk, seamless borders, marching-squares tile index | Stage decor scatter on the repeating chunk | 14 ms per chunk |
| `SlotReel` | Predetermined landing (quintic ease + spring tail), speed smear, drum shading | Treasure chest roulette | <1 ms |

## QA
`cd qa && luau run.luau > frames.bin` renders every effect, prints timings, and writes PPM frames for diffing against reference captures. See `research/vs-fx/hierarchy_qa.md` for the metrics and thresholds.

## Not done yet
- No real-game frame captures yet, so nothing has been diffed against the original.
- Not tested in Studio. Studio's `--!native` codegen should beat the interpreter timings above.
- Lichtenberg is still bushy and drifts sideways. It needs tuning against footage.
