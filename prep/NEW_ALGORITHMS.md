# New procedural effects: candidates (prep, 2026-10-15)

The artifact (L2VLi2c41hTdvKf3LNYQa9) names 89 effects: 79 effect algorithms plus 10 weapon styles.
Weapon styles: Whip, Magic Wand, Knife, Axe, Cross, King Bible, Fire Wand, Garlic, Holy Water, Lightning Ring.
`PixelCore.luau`, `PixelSims.luau` and `PROCEDURAL_BIBLE.md` are not in this repo. Push them to diff against the real code.

Each candidate below is a different technique from the 79 already built. Next to each is where it would fit in VS.

## Simulation / physics
1. Rope/chain IK (FABRIK): Peachone/Ebony Wings tether, chain whip
2. Cloth grid (Verlet 2D mesh): banners, chest lid cloth
3. Soft-body pressure blob: slime enemies, Laurel shield
4. SPH-lite fluid particles: Holy Water spill/pool
5. Cellular fire spread (grass burns): Hellfire trail
6. Sand-pile toppling (abelian): gold pile on pickup
7. Lava lamp (thermal metaballs): La Borra pools
8. Snow accumulation (per-column heightmap): Frozen stage HUD
9. Ice crystal growth (DLA): freeze status (Clock Lancet)
10. Electric breakdown (Lichtenberg / dielectric breakdown model): Thunder Loop
11. Spring-mass jiggle grid: hit squash on enemy sprites
12. Rigid tumbling debris (2D impulse): Brazier/light-source smash
13. Projectile trails with drag (ribbon): Runetracer bounces
14. Wave equation 2D (membrane): Garlic pulse ring

## Noise / fields
15. Worley/cellular noise animated: Song of Mana column
16. Flow-field streaks (Perlin advect lines): Phiera/Eight the Sparrow
17. Fractal flames (IFS): Arcana cards
18. Julia/Mandelbrot zoom: Arcana select background
19. Gabor noise (wood/brushed grain): chest wood, coffin
20. Truchet tiles animated: map/menu backgrounds
21. Moiré interference: curse status
22. Hex-grid pulse: Laurel / armor icon
23. Lissajous orbit: Unholy Vespers orbit path
24. Superformula morph (Gielis): evolution flash shapes

## Image / sprite processing
25. Outline glow via distance transform: selected item
26. Chromatic aberration split: damage taken
27. Ordered-dither fade (Bayer) in/out: enemy spawn/despawn
28. Sobel edge neon: Arcana unlock
29. Pixel dissolve via blue noise: enemy death
30. Mosaic/pixelate zoom: stage transition
31. Palette quantize + error diffusion (Floyd–Steinberg): portrait filter
32. Hit flash (white silhouette + decay): every enemy hit (core VS feel)
33. Squash/stretch sprite warp: player run bob
34. Drop shadow ellipse projection: every entity
35. Sprite trail onion-skin: dash / Clock Lancet freeze
36. Mirror/kaleid tile of icon: Pandora / Arcana
37. Twirl/pinch distortion: Vacuum pickup
38. CRT barrel + vignette: whole-screen filter option
39. Bloom (downsample + blur): crits, evolutions

## Growth / generative
40. Diffusion-limited aggregation (frost): freeze
41. Cave CA (4-5 rule): procedural stage tiles
42. Wave Function Collapse tiles: map gen
43. Phyllotaxis spiral: flower/seed pickups, Garlic petals
44. Spider web (radial + spiral): Spider enemy
45. Crack propagation (random walk branch): armor break
46. Mycelium/slime-mould (Physarum agents): Corruption, Mudman
47. Branching coral (Eden growth): Gallo Tower
48. Maze generator (recursive backtrack): Arcana / map secrets

## Agents / swarms
49. Flocking bats with obstacle avoid (enemy swarm wave)
50. Ant pheromone trails: Peachone birds
51. Predator-prey particles: Bone Zone enemies
52. Fish schooling: water stage
53. Homing missile steering (seek + arrive): Magic Wand
54. Orbital mechanics (n-body lite): Celestial Dusting / King Bible

## UI / text / numbers
55. Wavy text (per-letter sine): LEVEL UP banner
56. Text scramble decode: Arcana names
57. Slot-machine reels: treasure chest roulette (core VS feel)
58. Number count-up with ease + punch: kill counter
59. Tally/coin stack: end-of-run gold
60. Radial menu bloom: level-up choices
61. Progress ring with particles: XP to next level
62. Ticker tape / marquee: unlock announcements
63. Stamp/slam impact text: "EVOLVED!"

## Lighting / atmosphere
64. 2D point lights with occlusion (raycast): night stages
65. Volumetric light shafts from torches: Library
66. Day/night tint cycle: run timer
67. Rain with splash particles: weather
68. Lightning flash + screen tint: Lightning Ring evolve
69. Underwater wobble + caustic shafts: water stage
70. Dust motes in sun beam: Library/Dairy Plant
71. Heat shimmer column: Hellfire / Brazier

## Weapon styles not yet built (base game)
72. Runetracer (bouncing diamond, reflect)
73. Fire trail (Hellfire evolved)
74. Peachone / Ebony Wings (bird bombing orbit)
75. Phiera / Eight the Sparrow (cross shots)
76. Gatti Amari (cats + chasing)
77. Song of Mana (vertical column)
78. Shadow Pinion (trail-on-move)
79. Clock Lancet (freeze beam)
80. Laurel (shield shimmer)
81. Vento Sacro / Bloody Tear (dash whip, evolved)
82. Bone / Cherry Bomb / Carréllo (bouncers)
83. Celestial Dusting (flower drop)
84. Death Spiral (evolved Axe: spiral scythes)
85. Heaven Sword (evolved Cross)
86. Unholy Vespers (evolved Bible)
87. Thousand Edge (evolved Knife: stream)
88. Hellfire, Holy Wand, La Borra, Soul Eater, Thunder Loop (evolved)

Total: about 71 new effect techniques plus about 17 weapon styles.
The weapon list will be checked against `research/vs/weapons.json` (11 weapons, 32 evolutions) on branch `claude/vampire-survivors-mechanics-y1l323`.
