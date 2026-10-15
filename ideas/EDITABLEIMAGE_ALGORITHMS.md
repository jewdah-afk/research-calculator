# EditableImage algorithm ideas (not built)

Every idea here is a pixel algorithm that writes into an EditableImage buffer. This list leaves out the 89 effects you already have and the 15 in `pixelfx/`.
Format: **Name**: what it does → where it fits in the game.

## A. Fire, heat and energy
1. **Cellular fire spread on grass tiles**: each burning cell ignites its neighbours by a probability that depends on wind, then turns to ash → Hellfire trail, Fire Wand impacts.
2. **Ember advection on a curl field**: sparks follow a divergence-free noise field, so they swirl without bunching → anything burning.
3. **Blackbody palette fire**: temperature field mapped through a physical blackbody ramp (red→orange→white→blue) → evolved fire weapons burn hotter.
4. **Flame tongue noise**: vertical stretched value noise scrolling upward, masked by a teardrop → candles, braziers, torch props.
5. **Plasma arc between two points**: midpoint-displacement lightning re-rolled every frame, with glow → chain-lightning between enemies.
6. **Electric crawl over a sprite edge**: random walk along the alpha outline that leaves sparks → shocked enemies.
7. **Static discharge sparks**: short Bresenham zig-zags spawned at random edge pixels → Lightning Ring idle shimmer.
8. **Magma crust**: Voronoi cells darken as they cool and cracks glow between them → lava hazards, fire boss floor.
9. **Heat shimmer column**: offsets screen pixels by a rising sine field inside a mask → above fires and lava.
10. **Ignition flash ring**: an expanding ring whose thickness decays, with an additive core → fireball impact.
11. **Afterburn decal**: scorch marks painted into the ground layer that fade over 10 s → impacts leave history.
12. **Phoenix feather burst**: particles shaped like feathers via an SDF, burning out from the tips inward → revival effect.
13. **Fire-to-smoke transition**: a particle's colour ramp crossfades from flame to grey smoke over its life, and its size grows → realistic burn-out.
14. **Spontaneous combustion seeds**: Poisson-disc points ignite one after another → area fire attack.
15. **Ion trail**: a projectile leaves a fading trail with a jitter that decays → magic projectiles.
16. **Energy charge-up implosion**: particles spiral inward on a log spiral, then flash → charged attacks, boss telegraphs.
17. **Overheat glow on sprites**: a ramp-lit tint from the bottom of the sprite up, based on a heat value → enemies taking burn damage.
18. **Solar flare loops**: Bezier arcs of particles anchored on a circle → sun-themed weapons.
19. **Fire whirl**: a vortex velocity field acting on flame particles → evolved fire area attack.
20. **Pilot-light flicker**: brightness from 1/f pink noise → light sources feel organic.

## B. Water, liquid and fluids
21. **Shallow water height field**: a Saint-Venant style height plus velocity grid, so splashes carry momentum → water stages, Holy Water.
22. **Puddle spread with surface tension**: a cellular automaton where liquid cells flow downhill but hold a rounded edge → Holy Water pools.
23. **Rain splash rings**: tiny ripple rings at random spots plus a falling line → weather layer.
24. **Foam lines at the shore**: a noise threshold advected along a coast distance field → water edges.
25. **Underwater caustic projection**: a projected Voronoi-ripple pattern added onto the ground → shallow water.
26. **Blood splatter physics**: ballistic droplets that stretch along their velocity and splat into ground decals → hits (respect the Disable Blood option).
27. **Slime drip**: Verlet strands hanging from sprite bottoms that stretch and snap → slime enemies.
28. **Bubble rise with wobble**: buoyancy plus a sine wobble, popping at the surface into 4 px → poison and swamp stages.
29. **Wet footprint trail**: stamps that dry out (alpha fade) over time → the player walking through water.
30. **Viscous ooze**: a high-viscosity fluid that slowly fills dips → La Borra.
31. **Water drop lens**: a circular refraction that samples the background offset by a sphere normal → raindrops on the screen when hit.
32. **Ink in water**: a dye field advected by a decaying velocity field → curse or dark magic.
33. **Waterfall streaks**: vertical noise streaks scrolling fast, with foam at the bottom → map props.
34. **Ice melt**: an ice mask erodes from the edges by a distance field and drips → when a freeze ends.
35. **Mercury beads**: metaballs that attract each other and merge → silver projectiles, boss attack.
36. **Tide line**: a sine-shifted shoreline mask with a wet darkening band → beach stage.
37. **Pond surface glints**: sparkles appear where the wave slope matches the light angle → ambient water.
38. **Acid sizzle**: a dissolve mask on a sprite plus green smoke particles → acid damage.
39. **Splash crown**: a radial sheet of droplets in a ring with gravity → heavy impacts in water.
40. **Flood fill-up**: the water level rises in a tile map, with a refracted wobble under the surface line → stage event.

## C. Smoke, gas, dust and air
41. **Semi-Lagrangian smoke at low res**: a stable fluids variant at 48×48, upscaled with dither → explosions.
42. **Poison cloud**: puffs of Perlin noise that grow and fade with a sickly ramp → gas attacks.
43. **Dust kick-up**: a small particle burst at the feet on direction change → player and enemy movement.
44. **Wind streak lines**: short lines along a global wind vector that loop → windy stages.
45. **Fog of war reveal**: a darkness mask carved out by distance from the player, with soft edges → dark stages.
46. **Volumetric fog layers**: 3 scrolling noise layers at different speeds and densities (parallax fog) → atmosphere.
47. **Smoke ring**: a toroidal vortex drawn as a dithered ellipse that expands and fades → boss attack.
48. **Steam vents**: an upward plume with a lateral sway and a periodic burst → map hazards.
49. **Sand storm**: dense, fast horizontal particles plus a screen tint and a lower visibility radius → desert event.
50. **Soot deposition**: smoke particles leave dark specks where they settle → long fights look scarred.
51. **Spore puffs**: slow, drifting, glowing particles released when a plant is hit → forest stage.
52. **Breath vapour**: a periodic puff from the player's mouth in cold stages.
53. **Shockwave dust ring**: a ring that lifts ground-coloured particles → landing or slam.
54. **Gas ignition**: a gas field that turns to fire when flame touches it (field interaction) → combo mechanics.
55. **Vacuum suction lines**: lines converging on a point with an accelerating ease → Vacuum pickup.
56. **Miasma tendrils**: domain-warped noise strands creeping along the ground → curse aura.
57. **Ash fall**: slow, rotating flakes with a lateral sine drift → after fire, boss arenas.
58. **Pollen motes**: Brownian glow dots in sunlight shafts → peaceful stages.
59. **Exhaust puffs**: discrete smoke puffs on a timer behind moving objects → carts, machines.
60. **Air distortion trail**: background pixels displaced behind fast projectiles → speed feel.

## D. Light, shadow and colour
61. **2D raymarched soft shadows from a distance field**: shadows from props onto the ground → lit stages.
62. **Light propagation by flood fill**: Minecraft-style light levels spreading tile to tile → torch-lit dungeons.
63. **Radiance cascades (simplified)**: multi-scale light probes giving global illumination in 2D → premium lighting mode.
64. **Colour grading LUT per stage**: a 3D LUT baked into a 16×256 strip and applied per pixel → stage moods.
65. **Dynamic palette swap on damage**: the sprite palette shifts to hurt colours for a few frames → hit feedback.
66. **Rim light by direction**: the edge pixels facing a light are brightened with a normal from the alpha gradient → depth.
67. **Ambient occlusion from height**: darkening near walls and props from the distance field → grounding.
68. **Light cookies**: patterned masks (window panes, leaves) projected as light → library and forest stages.
69. **Flashlight cone**: a cone mask with a soft falloff that follows aim → dark stage mode.
70. **Lens flare streaks**: anamorphic horizontal streaks from bright pixels → evolution flashes.
71. **Exposure adaptation**: screen brightness adapts slowly after a flash → avoids blinding repeats.
72. **Day/night palette blend**: two palettes interpolated over run time → long runs feel like a journey.
73. **Specular glint on metal**: a moving highlight band across sprite pixels flagged as metal → armour, weapons.
74. **Emissive mask glow**: only sprite pixels tagged emissive feed bloom → eyes glowing in the dark.
75. **Shadow blob scaling with height**: a ground ellipse that shrinks and fades as the object rises → bats, jumpers.
76. **Silhouette x-ray**: the player is drawn as an outline when behind props → readability.
77. **Hue cycling aura**: hue rotated in a smooth wave through a sprite → rainbow and legendary items.
78. **Contrast-adaptive outline**: outline colour picked against the local background luminance → enemies are always visible.
79. **Selective desaturation**: everything except threats is desaturated during an event → clarity at peak chaos.
80. **Torchlight flicker**: the light radius modulated by noise, with shadows that wobble → dungeon mood.

## E. Particles and motion systems
81. **GPU-style particle pool in a buffer**: struct-of-arrays particles with no Instances → thousands of particles.
82. **Curl noise particle trails**: particles traced through a curl field with fading tails → magical ambience.
83. **Attractor particles (Lorenz, Clifford)**: strange-attractor paths projected to 2D → Arcana backgrounds.
84. **Particle springs to text**: particles fly in and settle into letters → "LEVEL UP".
85. **Particle explosion from sprite pixels**: each sprite pixel becomes a particle with outward velocity → deaths, chest opening.
86. **Reverse explosion assembly**: particles converge into a sprite → spawning, evolutions.
87. **Swirling pickup magnet**: gems spiral into the player instead of flying straight → magnet feel.
88. **Particle trails with ribbons**: connected quads between past positions, tapering → whip trails.
89. **Sub-pixel motion via dithered position**: movements smaller than a pixel are shown by alternating frames → smooth slow motion in pixel art.
90. **Collision-aware particles**: particles bounce off the tile mask → sparks bouncing off walls.
91. **Flocking firefly swarm**: boids with a light pulse in sync (Kuramoto phase sync) → fireflies blink together.
92. **Kuramoto synchronised blink**: oscillators that slowly synchronise → a field of glowing mushrooms.
93. **Particle size by speed**: fast particles stretch and slow ones shrink to dots → motion readability.
94. **Gravity well lensing**: particles and background pixels are pulled around a point → black hole weapon.
95. **Confetti with 3D flip**: the width of each rectangle varies by cos(angle) to fake 3D tumbling → celebration screens.
96. **Snow with accumulation**: flakes land and stack in a per-column height map → snow stages.
97. **Leaf fall**: pendulum-path leaves with spin → autumn ambience.
98. **Butterfly paths**: Perlin-driven flight with a wing-flap frame swap → peaceful stages.
99. **Shrapnel scatter**: fragments with drag and angular velocity that leave sparks → explosions.
100. **Particle LOD**: distant particles merge into one larger particle → performance at 1000s.

## F. Physics and soft bodies
101. **Pressure soft body**: a ring of points plus an area constraint → slimes that squish.
102. **Rope bridge**: a Verlet chain with planks that sways when walked on → map props.
103. **Cloth banner**: a Verlet grid pinned at the top that flaps in wind → castle stages.
104. **Rigid-body tumbling debris**: simple 2D rigid bodies with impulse collisions → destructibles.
105. **Chain lightning physics**: the bolt is a Verlet rope pulled between targets, so it swings → stylised lightning.
106. **Ragdoll from sprite pieces**: a sprite cut into 4–6 pieces with joints, collapsing → boss deaths.
107. **Spring-mass jelly grid**: a sprite warped by a 4×4 spring grid → wobble on hit.
108. **Hair and fur strands**: short Verlet strands on the head → character flair.
109. **Pendulum props**: hanging lamps that swing on impact → library and castle.
110. **Sand pile toppling**: an abelian sandpile cascade → gold coin piles.
111. **Granular sand flow**: a falling-sand variant with angle of repose → hourglass, desert.
112. **Shatter into Voronoi shards**: a sprite split into Voronoi shards that fly with spin → ice and glass deaths.
113. **Bounce squash on landing**: spring compression timed to the impact speed → everything that lands.
114. **Rope tether to a target**: a whip tether with slack → grappling enemies.
115. **Magnet field lines**: lines traced through a dipole field → magnet items.
116. **Elastic collision bounce projectiles**: Runetracer reflecting off screen edges → Runetracer.
117. **Buoyancy bob**: objects in water bob by a spring on the surface height → floating pickups.
118. **Wind sway on sprites**: top rows offset by a wind field with spring delay → trees, grass, banners.
119. **Destructible pixel terrain**: a pixel mask carved by explosions (Worms-style) → arena stages.
120. **Cascade of dominoes**: chained impulse reactions → stage events.

## G. Growth, generative and organic
121. **Space-filling vine growth on borders**: an L-system constrained to a UI frame's edges → card frames grow vines.
122. **Crystal growth by anisotropic DLA**: DLA with a preferred hex direction → ice crystals.
123. **Coral growth (Eden model)**: random boundary growth → underwater decor.
124. **Lichen spread**: a slow CA with colour variation → long runs age the map.
125. **Moss creeping**: noise-thresholded growth toward the shade → ruins.
126. **Root network**: space colonisation going downward → Gallo Tower roots.
127. **Mushroom ring (fairy ring)**: Poisson points on a circle that grow in sequence → Garlic aesthetics.
128. **Flower bloom animation**: procedural petals unfolding (polar rose curve) → Celestial Dusting.
129. **Tree growth from seed**: a recursive tree with growth over time → map events.
130. **Thorn bramble**: an L-system with spikes that grows from a point → nature weapon.
131. **Blood vessel branching**: Murray's-law branching from a heart → horror boss.
132. **Tentacle growth**: a curling noise-driven spine that tapers → boss attacks.
133. **Rust spread**: a corrosion CA on metal pixels → old machinery.
134. **Frost fern on glass**: branching DLA with a dendritic ramp → frozen screen overlay.
135. **Cell division (mitosis) blobs**: metaballs splitting → Mitosis-style enemies.
136. **Honeycomb growth**: hexagonal cells appearing in BFS order → bee enemies, shields.
137. **Spider web weaving**: radial lines plus a spiral drawn as the web is spun → Spider enemy.
138. **Leaf venation**: auxin-based vein patterns → leaf icons, nature menus.
139. **Seashell pattern CA**: Meinhardt reaction CA on a 1D line → decorative shell props.
140. **Zebra and leopard spots**: reaction-diffusion with stripe or spot presets → animal enemies.
141. **Sprouting grass after rain**: grass blades growing where water fell → weather aftermath.
142. **Wither and decay**: green pixels shift to brown and fall away → Evolve-style reset or curse.
143. **Bark texture**: stretched Worley noise plus cracks → tree props.
144. **Fungus glow network**: Physarum seeded from glowing mushrooms → dark forest.
145. **Ivy climb on walls**: growth hugging tile edges → castle ruins.
146. **Ink blot (Rorschach)**: symmetric noise thresholding → Arcana cards.
147. **Fractal fern (Barnsley IFS)**: chaos-game points → background flora.
148. **Dragon curve borders**: an L-system fractal border that animates as it draws → legendary item frames.
149. **Hilbert curve reveal**: pixels revealed in Hilbert order → smooth area wipes.
150. **Truchet maze grow**: random Truchet tiles laid in spiral order → map secrets.

## H. Geometry, patterns and shapes
151. **SDF shape morphs**: blending signed distance fields (circle→star→skull) → icon transitions.
152. **Rounded-box SDF UI panels**: resolution-independent panel corners with a bevel shade → UI.
153. **Polar coordinate warp**: an image wrapped into a ring → circular HP bars.
154. **Spirograph with live gears**: drawing hypotrochoids, showing the gear → magic sigils.
155. **Penrose tiling**: aperiodic tiles for floors → Cappella Magna floors.
156. **Islamic star patterns**: girih tiling → ornate menus.
157. **Celtic knot generator**: grid-based over/under knots → borders.
158. **Rotating polyhedra wireframe**: 3D projection with pixel lines → Arcana or secret items.
159. **Hypnotic rings**: concentric rings with phase offsets → curse status.
160. **Starburst rays**: rotating rays with an alternating colour → rarity reveal.
161. **Sunburst sweep**: a conic gradient rotating behind items → chest reveal.
162. **Diamond grid shimmer**: a sine wave travelling across a diamond lattice → card backs.
163. **Hex pulse wave**: a pulse travelling over a hex grid → shields.
164. **Moiré grids**: two rotated grids interfering → illusion and curse effects.
165. **Op-art warp**: a grid displaced by a radial function → boss phase change.
166. **Tessellation morph (Escher)**: one tile shape morphing into another → menus.
167. **Superellipse pulsing**: the shape exponent animates from circle to square → UI buttons.
168. **Golden spiral zoom**: an infinite zoom into a spiral → title screen.
169. **Rose curves**: polar rose sigils with petal counts by level → level-scaled weapons.
170. **Lissajous sigils**: animated Lissajous figures as runes → Arcana.
171. **Voronoi stained glass with leading**: a thick dark border between cells → Cappella windows.
172. **Delaunay low-poly**: an image converted to triangles with flat colours → stylised portraits.
173. **Polygon shatter of the UI**: a panel breaking into triangles and falling → screen transitions.
174. **Concentric squares tunnel**: squares zooming inward → transition into bosses.
175. **Checkerboard warp transition**: a checkerboard with growing squares hiding the screen → scene cuts.
176. **Diagonal stripe wipe**: animated hazard stripes → warnings.
177. **Radial clock wipe**: an angular reveal → cooldowns, scene transitions.
178. **Iris wipe on a target**: a circle closing on the player → death, end of stage.
179. **Heart shape SDF pulse**: a heart beating at a BPM tied to low HP → low HP warning.
180. **Star polygon sparkle**: an n-point star SDF with rotating arms → pickups.

## I. Sprite processing and post effects
181. **Pixel-perfect rotation (RotSprite variants)**: Scale2x then rotate then downsample → rotating weapons stay crisp.
182. **Smear frames from velocity**: generated motion-smear frames between poses → fast attacks.
183. **Afterimage with hue shift**: ghost copies, each hue-shifted → dashes.
184. **Palette quantisation per sprite**: reduce generated effects to 8 colours → consistent pixel art.
185. **Outline thickening by dilation**: morphological dilate → selected or hovered sprites.
186. **Erosion damage**: morphological erode as HP drops → enemies visibly crumbling.
187. **Silhouette fill with gradient**: a sprite filled with a vertical gradient → shadow clones.
188. **Pixel sort by brightness**: rows sorted in a mask region → glitch hits.
189. **Scanline jitter**: rows offset by a random burst → corruption.
190. **CRT phosphor**: an RGB subpixel mask plus bloom → retro filter option.
191. **Chromatic split on hit**: R and B channels offset by 1–2 px for 2 frames → hit impact.
192. **Edge-detect neon (Sobel)**: edges coloured with a neon ramp → Arcana mode.
193. **Posterise plus dither**: fewer levels with ordered dither → a stylised screen.
194. **Mosaic pixelation**: block averaging with an animated block size → transitions.
195. **Halftone dots**: dot size by luminance → comic-style pause screen.
196. **Ink outline from luminance**: the threshold of a blur gives a hand-drawn line → storybook mode.
197. **Watercolour bleed**: edge darkening plus noise blur → title art.
198. **Emboss**: a directional derivative shaded → stone UI.
199. **Pixel stretch glitch**: one column smeared to the edge → corruption.
200. **Kuwahara filter**: a painterly smoothing → portraits.
201. **Thermal vision**: luminance mapped through a heat ramp → a special item.
202. **Night vision**: green ramp, noise and vignette → a special item.
203. **Negative flash**: colours inverted for a frame → critical events.
204. **Duotone**: two-colour mapping by luminance → menus.
205. **Ghost transparency dither**: a checkerboard dither in place of alpha → ghost enemies at 50%.
206. **Sprite fake-3D shading from height map**: an auto-generated normal from luminance → lighting.
207. **Mirror reflection**: the sprite flipped below with a wave offset and fade → water.
208. **Sprite bend**: the sprite curved along an arc → boomerang Cross.
209. **Squash on a curve path**: the sprite deformed along a Bezier → stylised jumps.
210. **Cutout reveal**: an SDF mask animated from the centre → item reveal.

## J. Weapon-specific ideas (VS style)
211. **Whip slash crescent**: an arc swept by an SDF with a thickness profile → Whip.
212. **Bloody Tear lifesteal particles**: red particles pulled from enemies to the player → Bloody Tear.
213. **Magic missile homing trails**: seek steering with a wavy tail → Magic Wand.
214. **Holy Wand rapid stream**: a continuous ribbon of bolts → Holy Wand.
215. **Knife throw spin blur**: a rotation blur by angular velocity → Knife.
216. **Thousand Edge flurry**: a dense knife stream with offset jitter → Thousand Edge.
217. **Axe arc with gravity**: a parabolic arc with spin and motion blur → Axe.
218. **Death Spiral scythe swirl**: scythes spiralling outward → Death Spiral.
219. **Cross boomerang path**: decelerate, reverse, accelerate, with a trail → Cross.
220. **Heaven Sword with a light pillar**: a crossing sword leaving a light column → Heaven Sword.
221. **King Bible pages flutter**: page flips during the orbit → King Bible.
222. **Unholy Vespers dark orbit**: dark particles orbiting with a void ring → Unholy Vespers.
223. **Fire Wand fireball tail**: a teardrop SDF with a flame noise tail → Fire Wand.
224. **Hellfire meteor**: a large fireball with a shadow on the ground → Hellfire.
225. **Garlic aura shimmer**: a pulsing ring with petal particles → Garlic.
226. **Soul Eater soul drain**: wisps drifting from enemies to the player → Soul Eater.
227. **Santa Water flame puddle**: a puddle shape with a fire tongue noise on top → Holy Water.
228. **La Borra moving pools**: pools that drift toward the player and merge → La Borra.
229. **Runetracer bouncing diamond**: a reflecting path with a rotating diamond and trail → Runetracer.
230. **NO FUTURE explosion on bounce**: an explosion at each bounce point → evolved Runetracer.
231. **Lightning Ring strike**: a bolt from the top of the screen with a ground flash → Lightning Ring.
232. **Thunder Loop double strike**: a delayed second bolt with a ring → Thunder Loop.
233. **Pentagram screen erase**: a pentagram drawn on screen then a white wipe → Pentagram.
234. **Gorgeous Moon erase**: the same wipe plus gem collection → Gorgeous Moon.
235. **Peachone bombardment**: a bird looping and dropping bomb circles → Peachone.
236. **Vandalier union birds**: two birds orbiting each other → Vandalier.
237. **Phiera Der Tuphello cross-shots**: shots in four directions with muzzle flashes → Phiera.
238. **Gatti Amari cat wander**: cats wandering on random walks and pouncing → Gatti Amari.
239. **Song of Mana vertical beam**: a scrolling noise column → Song of Mana.
240. **Shadow Pinion trail**: shadow blades left behind while moving → Shadow Pinion.
241. **Clock Lancet freeze beam**: a beam rotating like a clock hand, freezing enemies it touches → Clock Lancet.
242. **Infinite Corridor halving**: a clock face with a corridor zoom → Infinite Corridor.
243. **Laurel shield bubble**: a hex shield shimmer that cracks on hit → Laurel.
244. **Crimson Shroud damage cap ring**: a red ring that flashes on capped hits → Crimson Shroud.
245. **Vento Sacro dash streak**: a dash streak with wind particles → Vento Sacro.
246. **Celestial Dusting flower fall**: flowers drifting down and bursting → Celestial Dusting.
247. **Carréllo bouncing bottles**: bottles with squash on bounce → Carréllo.
248. **Bone ricochet**: bones with spin that ricochet off enemies → Bone.
249. **Cherry Bomb timer flash**: a blink rate that rises before the explosion → Cherry Bomb.
250. **Ebony Wings dark bird**: a bird loop with a dark trail → Ebony Wings.

## K. Enemies, crowds and bosses
251. **Crowd heatmap darkening**: ground darkened by local enemy density → pressure reads at a glance.
252. **Formation path swarms**: groups following baked splines → bat lines, ghost lines.
253. **Flower wall closing ring**: enemies placed on a shrinking circle → Flower Wall event.
254. **Boss telegraph decals**: a red ground marker growing to full before the attack → readable bosses.
255. **Boss phase shatter**: a boss sprite cracking (crack propagation) at HP thresholds → phase change.
256. **Elite aura**: a rotating rune ring under elites → elites stand out.
257. **Enemy spawn portal**: a swirl portal that opens then closes → spawns at the screen edge.
258. **Enemy burrow-up**: a dirt mound grows, then the sprite rises with dust → underground spawns.
259. **Ghost phase**: a sine-modulated alpha dither → ghosts.
260. **Mummy wrap unravel**: strips peeling off on death → mummies.
261. **Skeleton bone collapse**: a sprite split into bones falling → skeletons.
262. **Bat wing flap from one frame**: wing rows squashed on a sine → bats with one PNG.
263. **Zombie shamble lean**: an irregular lurch rhythm in the bake → zombies.
264. **Plant enemy root anchor**: the bottom rows fixed, the top sways strongly → Venus-type plants.
265. **Giant enemy screen shake by step**: a small shake on each footstep → giants.
266. **Reaper presence**: the screen vignette darkens as the Reaper approaches → endgame dread.
267. **Freeze shatter**: frozen enemies breaking into ice shards when killed → Orologion kills.
268. **Knockback dust**: a dust puff in the knockback direction → hit feel.
269. **Overkill gib burst**: more particles when the damage greatly exceeds the remaining HP → satisfying kills.
270. **Corpse fade by blue-noise**: bodies left for 1 s and then dissolved → battlefield history.
271. **Enemy hit stagger wobble**: a damped sine rotation after a hit → hit reaction.
272. **Swarm shimmer LOD**: far crowds drawn as a moving texture instead of sprites → 2000+ enemies.
273. **Threat-colour outline**: the outline colour by enemy danger tier → hierarchy.
274. **Enemy shadow merging**: shadows merge into one dark blob in dense crowds → cheaper and cleaner.
275. **Charge-up trail**: a charging enemy leaves afterimages → telegraphed charges.
276. **Split-on-death blobs**: slimes splitting into two smaller metaballs → splitter enemies.
277. **Enemy shield bubble**: a refracting dome around protected enemies → shield enemies.
278. **Status icons above enemies**: tiny procedural icons (burn, freeze, curse) → status readability.
279. **Boss HP bar shatter**: chunks fall off the bar as damage is taken → boss bars.
280. **Mini-map dots by density**: a density map of enemies blitted to a radar → awareness.

## L. Pickups, loot and economy
281. **Gem facet sparkle**: a highlight sweeping across gem facets → XP gems.
282. **Gem merge animation**: small gems fly together into a red gem → gem cap merge.
283. **Coin spin**: a width modulated by cos(angle) with an edge highlight → coins.
284. **Coin bag burst**: coins fountain out with bounces → coin bags.
285. **Chicken steam**: rising heat squiggles → floor chicken.
286. **Rosary holy flash**: a cross-shaped light expanding to fill the screen → Rosary.
287. **Orologion clock overlay**: clock hands sweep with a blue tint spreading → Orologion.
288. **Nduja fire breath**: a flame cone in the facing direction → Nduja Fritta.
289. **Magnet ripple**: a ripple ring expanding to the edge, then gems streaming in → Vacuum.
290. **Clover luck sparkle**: green four-point sparkles orbiting → Little Clover.
291. **Chest beam of light**: a light pillar from the chest into the sky → treasure chests.
292. **Chest lid squash and open**: an anticipation squash, then the lid pops → chest pickup.
293. **Item tier glow**: glow colour by rarity → loot readability.
294. **Pickup attraction trail**: a tail behind gems flying to the player → magnet feel.
295. **Gold Fever screen tint**: a gold vignette pulse and coin rain → Gold Fever.
296. **Relic unveiling**: a cloth sheet pulled off via a Verlet cloth → relic pickups.
297. **Brazier break**: a brazier shatters with embers and drops its item → light sources.
298. **Candle snuff**: the flame shrinks and a smoke wisp rises → light sources.
299. **Pickup pulse ring**: rings pulsing outward from uncollected rare items → item visibility.
300. **Off-screen item arrow**: an edge arrow bobbing toward a chest → navigation.
301. **Pickup sparkle density by value**: more sparkles for rarer drops → value readability.
302. **Coin counter odometer with blur**: digit rolls with vertical motion blur → gold HUD.
303. **XP absorb flash**: a brief glow on the player when gems are collected → feedback.
304. **Chest roulette light chase**: lights chasing around the reel frame → chest screen.
305. **Firework burst behind chests**: firework shells with trails and glitter → chest screen.
306. **Treasure reveal starfield**: stars streaming behind the revealed item → chest screen.
307. **Ribbon banner unfurl**: a banner unrolling as a curved ribbon → item name reveal.
308. **Coin rain accumulation**: coins piling up at the bottom of the screen → big rewards.
309. **Evolution fusion**: two icons orbit, merge with a flash, and the evolved icon appears → evolutions.
310. **Arcana card flip**: a 3D flip faked by width, with a shine on the back → Arcana selection.

## M. HUD and UI
311. **XP bar liquid fill with meniscus**: liquid with a curved surface → XP bar.
312. **XP bar segment flash on level-up**: each segment lights in sequence → level-up.
313. **HP bar damage ghost**: a white bar lagging behind the real HP and then draining → damage reading.
314. **HP bar heal shimmer**: a sparkle sweeping across on heal → healing.
315. **Low HP heartbeat vignette**: a red edge pulse whose rate rises as HP drops → danger.
316. **Timer digit flip**: a split-flap animation → the run timer.
317. **Kill counter punch**: the number scales up on each multiple of 100 → milestones.
318. **Slot icon level pips fill**: pips filling with a glint → weapon slots.
319. **Cooldown radial with glow edge**: a sweep with a bright leading edge → cooldowns.
320. **Damage number styles**: crit numbers in gold with a pop and shake, normal numbers in white → readability.
321. **Damage number stacking**: numbers on one enemy combine into a growing total → less clutter.
322. **Text outline by distance field**: a crisp outline on any font → readability.
323. **Typewriter with glitch**: letters scramble before they settle → Arcana text.
324. **Button hover ripple**: a ripple from the cursor point → menus.
325. **Card hover parallax**: card layers shift by mouse or tilt → level-up cards.
326. **Card holographic foil**: a rainbow gradient by tilt angle, masked → legendary cards.
327. **Card rarity rays**: rays behind the card, coloured by rarity → card hierarchy.
328. **Pause menu blur**: the game screen downsampled and blurred → pause.
329. **Results screen bar race**: damage bars growing in rank order → results.
330. **Top-damage gold highlight sweep**: a sweep across the highest row → results.
331. **Unlock popup stamp**: a stamp-in with dust and a shake → unlocks.
332. **Achievement shine**: a diagonal shine with a sparkle burst → achievements.
333. **Menu background parallax pixel art**: 4 layers scrolling → the main menu.
334. **Character select spotlight**: a light cone on the selected character → character select.
335. **Shop purchase coin drain**: coins fly from the counter to the item → the PowerUp shop.
336. **Minimap fog reveal**: the explored area revealed with soft edges → map screen.
337. **Tooltip unfold**: the panel unfolding from a point → tooltips.
338. **Scrolling list inertia blur**: motion blur by scroll speed → long lists.
339. **Number tick with colour flash**: green when rising, red when falling → stat changes.
340. **Notification stack slide**: toasts pushing each other up with springs → notifications.

## N. Map, tiles and environment
341. **Autotile from mask (47-tile blob)**: correct edges from any mask → procedural map edges.
342. **Wang tile terrain blending**: Wang tiles for seamless biome mixes → stage variety.
343. **Infinite chunk scroll with seed**: each chunk regenerated from its coordinates → infinite maps.
344. **Grass sway by player proximity**: grass bends away from the player → living ground.
345. **Trampled grass trail**: grass flattened where enemies walk, recovering slowly → battlefield history.
346. **Flowers closing at night**: a sprite swap by time → day/night.
347. **Water tile animation by flow map**: tiles scrolled by a flow vector → rivers.
348. **Torch light pooling on tiles**: a light radius painted onto the ground → dungeons.
349. **Tile decay over the run**: cracks spread across the floor over time → atmosphere.
350. **Puddle reflections of the sky**: a sky texture sampled into puddle masks → rainy stages.
351. **Footprints in snow and sand**: stamps that slowly fill back in → snow and desert.
352. **Ground decal atlas**: blood, scorch and frost written into one decal layer → persistent marks.
353. **Prop wobble on hit**: props jiggle when hit → interactivity.
354. **Destructible prop debris**: props break into tiles of themselves → braziers, crates.
355. **Sky gradient with clouds**: a vertical gradient plus scrolling clouds → outdoor stages.
356. **Star twinkle field**: stars with random twinkle phases → night stages.
357. **Moon eclipse**: a moon disc covered by a shadow disc with a corona → Moongolow.
358. **Lava tiles with crust**: a magma crust animation per tile → fire stages.
359. **Bookshelf flicker**: book spines with tiny colour shifts → Library.
360. **Dairy plant machines**: gears rotating and pistons moving → Dairy Plant.
361. **Stained glass light shafts**: coloured light beams on the floor → Cappella Magna.
362. **Bone pile rattle**: bones shifting when enemies pass → Bone Zone.
363. **Corn field ripple**: wave lines across corn stalks → Green Acres.
364. **Stage invert transition**: a 180° rotation with a hue shift (Inverse mode) → Inverse stages.
365. **Tower climb parallax**: background bricks scrolling slower → Gallo Tower.
366. **Infinite corridor zoom**: a recursive frame zoom → special stages.
367. **Water edge foam**: foam lines along the coast distance field → beaches.
368. **Fog banks in hollows**: fog density by a height map → forests.
369. **Map seam hider**: a noise overlay crossing chunk boundaries → no visible repeats.
370. **Weather system blend**: rain, snow and wind crossfading → long runs.

## O. Screen-wide, camera and transitions
371. **Screen shake with Perlin**: a trauma value drives noise-based offsets → impacts.
372. **Hit stop**: freeze for 2–4 frames on big hits → game feel.
373. **Zoom punch**: the camera scale pulses on evolution → big moments.
374. **Vignette by danger**: vignette strength by the number of nearby enemies → tension.
375. **Screen crack overlay**: cracks drawn when HP is critical → danger.
376. **Pixel dissolve transition**: a blue-noise wipe between scenes → transitions.
377. **Diamond wipe**: diamonds growing across the screen → scene cuts.
378. **Spiral wipe**: an angular spiral reveal → boss entry.
379. **Melt transition (Doom wipe)**: columns sliding down at random speeds → game over.
380. **Page curl**: a fake 3D page turn → menus.
381. **Glass shatter transition**: the screen breaks into Voronoi shards → stage clear.
382. **Ink spread transition**: an ink blot expanding to fill the screen → Arcana.
383. **Time-slow tint**: a desaturated blue with ghost trails → Orologion.
384. **Screen flash with a flashing-VFX gate**: flashes limited to safe frequencies → accessibility.
385. **Letterbox bars**: black bars sliding in for bosses → cinematic moments.
386. **Radial blur zoom**: samples along rays from the centre → speed boosts.
387. **Directional blur dash**: blur along the movement → dashes.
388. **Camera lead**: the camera offset ahead of movement with a spring → visibility ahead.
389. **Kaleidoscope pause**: the paused frame mirrored into a kaleidoscope → pause art.
390. **Death slow-motion fade**: time slows and the screen desaturates to grey → game over.
391. **Revival flash**: a white screen bloom, then the colour returns → revive.
392. **Boss intro silhouette**: the boss drawn as a black silhouette on a red flash → boss entry.
393. **Screen-space rain on the lens**: drops sliding down the screen → weather.
394. **Damage direction indicator**: an edge glow toward the damage source → awareness.
395. **Combo meter fire**: a fire border growing with the kill streak → streaks.
396. **Countdown overlay**: big numbers with squash and stretch → event timers.
397. **Map reveal sweep**: a radar sweep revealing the map → map items.
398. **Tunnel vision at low HP**: an edge blur plus desaturation → danger.
399. **Freeze frame snapshot**: the screen captured and spun away → victory.
400. **Credits star scroll**: a starfield with names → credits.

## P. Noise, fields and maths
401. **Simplex noise animated in 3D slices**: time as the third dimension → smooth animated textures.
402. **Domain warping, two levels**: noise warping noise warping noise → marble, clouds.
403. **Ridged multifractal**: absolute-value noise layers → mountains, electric veins.
404. **Billow noise**: rounded cloud puffs → clouds.
405. **Worley F2−F1**: crack networks → dry earth, cracked shields.
406. **Gabor noise**: oriented texture → wood, brushed metal.
407. **Flow noise (rotating gradients)**: a swirling texture → magical liquids.
408. **Value noise with cosine interpolation**: a cheap smooth texture → low-end devices.
409. **Blue noise dithering of gradients**: banding-free fades → every gradient.
410. **Hash-based star fields**: stars per cell from a hash → infinite skies.
411. **Fractional Brownian motion clouds**: 4-octave fBm → skies.
412. **Turbulence fire**: the absolute fBm → fire textures.
413. **Curl of noise for flow**: divergence-free flow → smoke, particles.
414. **Spectral synthesis via FFT**: an inverse FFT of a shaped spectrum → ocean-like water.
415. **Wavelet noise**: band-limited noise → crisp detail at all scales.
416. **Tileable noise via torus mapping**: seamless textures → tiles.
417. **Distance field from a bitmap (8SSEDT)**: an exact SDF → glows, outlines.
418. **Poisson solver blending**: seamless pasting of a sprite into a background → decals.
419. **Heat equation diffusion**: smooth spreading of a value → temperature, influence maps.
420. **Advection-reaction field**: a field moved by flow plus a reaction → poison spread.
421. **Random walk fields**: many walkers depositing → paths, cracks.
422. **Lévy flight scatter**: long-tailed jumps → firefly paths, glitches.
423. **Golden-ratio sequence sampling**: even point placement → sparkles without clumps.
424. **Halton sequence scatter**: low-discrepancy points → decor scatter.
425. **Bridson Poisson disc**: blue-noise point sets → prop placement.
426. **Stippling by Lloyd relaxation**: dots relaxed to an image → a stylised filter.
427. **Weighted Voronoi stippling**: dot density from luminance → portraits.
428. **Marching squares contours**: iso-lines from a field → topo maps, magic circles.
429. **Isosurface glow bands**: multiple iso bands, each coloured → energy fields.
430. **Gradient noise flowfield painting**: brush strokes along a field → painterly backgrounds.
431. **Chladni plate patterns**: sums of standing waves → sound-themed weapons.
432. **Interference of point sources**: summed waves from emitters → magic fields.
433. **Fourier epicycles**: a shape drawn by rotating circles → magic sigils.
434. **Bezier ribbon fields**: flowing ribbons → menu backgrounds.
435. **Cellular noise with jittered heights**: cobblestone → streets.
436. **Bayer matrix animated fade**: a temporal dither → smooth fades.
437. **Smoothstep easing library**: ease curves baked into lookup tables → all animation.
438. **Spring integrator lookup tables**: critically damped springs precomputed → UI motion.
439. **Noise-based shake curves**: a 1D noise for trauma shake → camera.
440. **Probability heatmaps**: drop-chance fields painted → debug and QA views.

## Q. Cellular automata and simulations
441. **Brian's Brain**: a 3-state CA with gliders → electric field textures.
442. **Langton's ant highways**: emergent paths → secret patterns.
443. **Cyclic CA**: spirals of N states → psychedelic Arcana.
444. **Forest fire CA**: tree growth, lightning and spread → stage event.
445. **Sandpile CA**: avalanche fractals → treasure piles.
446. **Life-like rules (HighLife, Day & Night)**: varied organic motion → background textures.
447. **Lenia (continuous Life)**: smooth lifeforms → alien creatures.
448. **Rock-paper-scissors CA**: spiral waves → corruption battles.
449. **Belousov-Zhabotinsky CA**: chemical spiral waves → magic pools.
450. **Lattice gas fluid**: particle fluid on a hex lattice → liquids.
451. **Erosion simulation**: hydraulic erosion on a height map → terrain generation.
452. **Ising model**: magnetic domains forming → curse patterns.
453. **Predator-prey CA**: population waves → infection spread.
454. **Epidemic SIR spread**: infection waves across enemies → plague weapon.
455. **Traffic CA**: lane flow → enemy marching columns.
456. **Crystal CA**: hexagonal snowflake growth (Reiter model) → snowflakes.
457. **Lightning by CA**: a branching discharge on a grid → cheap lightning.
458. **Ant colony pheromone**: trails to food → Peachone or insect enemies.
459. **Termite CA**: termites gathering chips into piles → swarm behaviour.
460. **Belt CA**: a conveyor movement grid → Dairy Plant.

## R. Text, numbers and glyphs
461. **Pixel font renderer from a bitmap atlas**: glyphs blitted with kerning → all text.
462. **Wave text**: letters offset by sine → LEVEL UP.
463. **Shake text**: letters jittered randomly → damage and warnings.
464. **Rainbow text**: hue by letter and time → legendary names.
465. **Melting text**: letters drip downward → game over.
466. **Burning text**: letters dissolve with a fire edge → curse text.
467. **Frozen text**: an ice crust grows over the letters → freeze text.
468. **Electric text**: sparks crawl along the glyph edges → lightning names.
469. **Ghost text**: an alpha wave with offset copies → ghost names.
470. **Golden text shine**: a specular band sweeping across glyphs → rewards.
471. **Counting numbers with overshoot**: a number tween that overshoots then settles → rewards.
472. **Big number compression animation**: 999K rolls into 1.00M with a squish → big numbers.
473. **Floating text with bezier arcs**: numbers flying in arcs → damage.
474. **Text decode reveal**: random glyphs that settle into the real ones → secrets.
475. **Handwriting reveal**: a stroke-order mask → story text.
476. **Stamped text**: slam with dust and cracks → milestones.
477. **Neon flicker text**: a broken-sign flicker pattern → shops.
478. **Chalk text**: noise erosion on the glyph edges → tutorial boards.
479. **Pixel shadow text**: a hard 1 px offset shadow → readability.
480. **Glyph particle burst**: a word bursts into particles → dismissing popups.

## S. Readability, QA and debug tools (visual)
481. **Overdraw heatmap**: count the writes per pixel → find expensive areas.
482. **Contrast checker overlay**: flag pixels with low contrast to the local background → hierarchy QA.
483. **Saliency map**: a simple centre-surround saliency → check what draws the eye.
484. **Colour-blind simulation**: Brettel/Viénot matrices → accessibility QA.
485. **Flash frequency detector**: luminance-change history per region → seizure-safety QA.
486. **Diff overlay against reference**: an absolute diff in false colour → 1:1 QA.
487. **SSIM map**: per-window similarity in false colour → QA.
488. **Palette compliance checker**: highlight pixels outside the stage palette → art QA.
489. **Frame-time graph**: a sparkline drawn into the HUD → performance QA.
490. **Entity bounding box overlay**: hitboxes drawn as outlines → gameplay QA.
491. **Flow field visualiser**: arrows of the crowd flow field → AI QA.
492. **Spatial hash visualiser**: cell occupancy as a heat grid → performance QA.
493. **Layer isolate view**: only one z-layer shown → hierarchy QA.
494. **Motion trail recorder**: the path of an entity over time → movement QA.
495. **Blur test**: the screen blurred to check hierarchy (does the player still read?) → hierarchy QA.
496. **Squint test filter**: downsample plus a contrast boost → hierarchy QA.
497. **Grayscale value check**: luminance only → value hierarchy QA.
498. **Clutter metric map**: local edge density → noise QA.
499. **Golden image comparator**: a side-by-side flip-book → regression QA.
500. **Pixel grid alignment check**: highlight sub-pixel blurring → pixel-perfect QA.

## T. Status effects and buffs
501. **Burn status**: small flames along the top edge of the sprite plus an orange tint pulse → burning enemies.
502. **Poison status**: green bubbles rising and a sickly palette swap → poisoned enemies.
503. **Freeze status**: the sprite quantised to an ice palette with a frost rim → frozen enemies.
504. **Stun status**: stars orbiting the head on an ellipse → stunned enemies.
505. **Curse status**: purple tendrils with a slow hue drift → cursed enemies.
506. **Bleed status**: drips falling from random pixels → bleeding.
507. **Slow status**: afterimages lagging behind → slowed enemies.
508. **Haste status**: speed lines plus a slight lean → buffed player.
509. **Shield buff**: a hex bubble with a Fresnel-like edge brightening → Laurel.
510. **Invincibility frames**: alternate-frame blinking dither → after being hit.
511. **Regen aura**: green plus-signs rising → Pummarola.
512. **Damage buff**: a red power aura with flame wisps → Spinach.
513. **Luck buff**: clover sparkles → Clover.
514. **Greed buff**: gold coins orbiting → Stone Mask.
515. **Magnet buff**: field lines toward the player → Attractorb.
516. **Area buff**: a ring grows when picked up → Candelabrador.
517. **Cooldown buff**: clock ticks orbiting → Empty Tome.
518. **Duration buff**: an hourglass with sand → Spellbinder.
519. **Projectile speed buff**: wind streaks behind projectiles → Bracer.
520. **Amount buff**: a duplication flash on each weapon → Duplicator.
521. **Armour buff**: metal plates clink as a sparkle → Armor.
522. **Max HP buff**: a heart pulse expansion → Hollow Heart.
523. **Revival buff**: a phoenix feather glint → Tiragisù.
524. **Curse buff**: a skull overlay on enemies → Skull O'Maniac.
525. **Growth buff**: rising XP motes → Crown.
526. **Mark of a buff stacking**: rings stacking with each level → buff readability.
527. **Status blend system**: multiple statuses layered by priority → combined effects.
528. **Status expiry warning**: the effect blinks faster before it ends → timing.
529. **Immunity flash**: a white ring when an immune enemy is hit → feedback.
530. **Overheal glow**: a gold edge when above max HP → feedback.

## U. Player and characters
531. **Character idle breathing**: a 1 px chest rise baked → idle.
532. **Character walk bob**: a squash and bob baked from one PNG → walk.
533. **Cape physics**: a Verlet cape attached to the shoulders → characters with capes.
534. **Hair sway**: strands lagging behind motion → characters with hair.
535. **Hurt flash plus recoil**: a white flash plus a 1 px offset → taking damage.
536. **Level-up glow column**: a light pillar on the player → level-up.
537. **Evolution aura change**: the aura colour shifts with the evolved weapon set → progression.
538. **Footstep dust per surface**: the particle colour sampled from the ground → grounding.
539. **Character portrait animation**: blink, breathe and an eye glint → menus.
540. **Death crumple**: the sprite falls and dissolves into soul particles → game over.
541. **Revive rise**: soul particles assemble the player → Tiragisù revive.
542. **Co-op player outline colours**: 4 player colours with outlines → co-op.
543. **Player trail at high speed**: afterimages when the speed stat is high → speed builds.
544. **Weapon-holding pose**: the sprite bends toward the attack direction → attacks.
545. **Character select turnaround**: a fake 3D rotation by sprite layering → character select.
546. **Secret character glitch reveal**: glitch tiles revealing the sprite → secret unlocks.
547. **Character shadow under lights**: shadow direction from the nearest light → lighting.
548. **Low HP sweat drops**: drops flying off the head → danger.
549. **Victory pose**: a jump with confetti → stage clear.
550. **Character skin palette swap**: palette-indexed sprites → skins.

## V. Arcana, magic and cards
551. **Arcana card tarot frame generator**: an ornate frame generated from symmetric curves → Arcana cards.
552. **Arcana sigil drawing**: a sigil drawn stroke by stroke → Arcana selection.
553. **Magic circle**: concentric rings, runes and rotation per ring → spellcasting.
554. **Rune glyph generator**: random glyphs from stroke grammar → runes everywhere.
555. **Card back pattern**: symmetric procedural pattern per run seed → card backs.
556. **Card burn-in reveal**: a fire edge reveal of the card face → Arcana reveal.
557. **Card shuffle animation**: cards fanned and riffled with springs → selection screens.
558. **Card glow by power**: glow intensity by tier → hierarchy.
559. **Constellation drawing**: stars connected in sequence → celestial Arcana.
560. **Mana flow lines**: particle streams between runes → magic UI.
561. **Spell trail sigils**: trails that form a glyph when complete → special attacks.
562. **Portal ring**: a rotating ring with an inner swirl and sparks → secret areas.
563. **Ethereal flame**: a blue flame with desaturated noise → ghostly magic.
564. **Enchant shimmer**: a rolling sparkle across items → enchanted items.
565. **Prophecy text**: text that fades in via ink spread → lore.
566. **Hourglass Arcana**: sand falling between sprite halves → time Arcana.
567. **Sun and Moon Arcana**: a rotation between sun and moon icons → day/night Arcana.
568. **Mirror Arcana**: a reflection effect with a shimmer line → mirror Arcana.
569. **Wheel of Fortune spin**: a wheel with ease-out and a pointer flick → chance events.
570. **Chaos Arcana**: random effects blended each frame → chaos effects.

## W. Boss-specific spectacles
571. **Screen-filling boss silhouette**: a giant shadow passing overhead → boss entrance.
572. **Boss charge laser**: an expanding line warning then a full beam → boss attack.
573. **Bullet hell patterns**: spirals, rings and waves of bullets → boss attacks.
574. **Boss arena shrink**: a ring of hazards closing in → final phase.
575. **Boss rage tint**: a red tint and stronger shake → enrage.
576. **Boss weak point glint**: a sparkle on the critical spot → strategy.
577. **Boss death explosion chain**: explosions in a sequence over the sprite → boss death.
578. **Boss loot shower**: coins and gems in a fountain → boss death.
579. **Boss summon circles**: circles appear before minions → summons.
580. **Boss ground slam ripple**: a radial ground wave with displacement → slams.
581. **Boss shadow tendrils**: tentacles from the shadow → dark boss.
582. **Boss eye tracking**: the pupils follow the player → creepiness.
583. **Boss armour break**: plates flying off → phase change.
584. **Boss dialogue box**: a portrait glitch and typewriter → boss intro.
585. **Boss timer bar**: a bar that drains with a fire edge → timed fights.
586. **Reaper scythe swing arc**: a huge arc with a void trail → Reaper.
587. **Reaper multiplication**: Reapers spawning with a dark flash each → endgame.
588. **Final boss reality tear**: screen tears showing a void → final boss.
589. **Boss phase transition flash**: freeze, flash, then a new palette → phases.
590. **Boss arrival quake**: progressive shake with debris falling → boss arrival.

## X. Audio-reactive visuals
591. **Beat-synced pulse**: UI elements pulse on the beat from the music BPM → rhythm feel.
592. **Bass-driven screen shake**: shake amount by the bass level (if available) → intensity.
593. **Spectrum bars in menus**: bars from the audio level → menu flair.
594. **Waveform ring**: a circle displaced by audio → the music menu.
595. **Jingle-synced chest lights**: lights timed to the chest jingle → chest screen.
596. **Footstep-synced dust**: dust tied to footstep sounds → coherence.
597. **Hit sound sync flash**: flash on the impact frame of the sound → snappiness.
598. **Music intensity colour grade**: saturation by the music's intensity layer → dynamic mood.
599. **Silence fade**: the screen dims when the music cuts → dramatic moments.
600. **Victory fanfare confetti timing**: confetti bursts on fanfare hits → celebration.

## Y. Advanced rendering techniques in 2D
601. **2D signed distance raymarching**: soft light and shadows from an SDF scene → premium lighting.
602. **Jump-flood Voronoi in real time**: a moving-seed Voronoi each frame → shifting glass.
603. **Temporal accumulation**: blend each frame with the last for smooth noise → cheap smoke.
604. **Checkerboard rendering**: update half the pixels per frame → doubled effect resolution.
605. **Interlaced updates**: odd and even rows on alternate frames → cheaper large effects.
606. **Dirty rectangle tracking**: only changed regions uploaded → performance.
607. **Tile-based effect culling**: effects split into tiles and off-screen tiles skipped → performance.
608. **Mipmap pyramid of a buffer**: multi-resolution copies → fast blur and bloom.
609. **Summed-area table blur**: constant-time box blur of any radius → variable blur.
610. **Separable Gaussian with LUT weights**: an exact blur → quality bloom.
611. **Kawase blur**: an iterative offset blur → cheap bloom.
612. **Dual-filter blur**: down then up sampling → fastest bloom.
613. **Unsharp mask**: sharpen generated textures → crispness.
614. **Bilateral filter**: smooth while keeping edges → painterly filters.
615. **Guided filter**: edge-aware smoothing → light bleeding control.
616. **Normal map from height (Sobel)**: auto normals → sprite lighting.
617. **Parallax occlusion in 2D**: height-based texture offset → fake depth on tiles.
618. **Sprite stacking**: slices layered to fake 3D → chests, props.
619. **Isometric voxel slices**: a voxel model drawn as slices → 3D-looking props.
620. **Billboard impostors**: pre-rendered angles chosen at runtime → rotating props.
621. **Indexed colour rendering**: render to palette indices, then map → palette animation for free.
622. **Palette cycling with multiple ranges**: several colour ranges cycling at different speeds → water, fire, lava in one pass.
623. **Hue-preserving tone mapping**: avoid hue shift when adding glow → clean bloom.
624. **Premultiplied alpha pipeline**: correct blending everywhere → no dark halos.
625. **Gamma-correct blending**: blend in linear space → nicer gradients.
626. **Dithered alpha with a temporal offset**: transparency that animates smoothly → ghosts, fog.
627. **Sub-pixel sprite filtering**: integer scaling with an AA border → smooth moves at pixel scale.
628. **Screen-door transparency**: patterned holes → see-through props.
629. **Order-independent additive layers**: glow layers summed regardless of order → robust glows.
630. **Multi-layer compositing**: separate EditableImages per layer with ZIndex → hierarchy control.
631. **Atlas packing for effects**: many small effects in one image (shelf packing) → memory saving.
632. **Ring buffer for trails**: a fixed buffer of past positions → cheap trails.
633. **Lookup-table trigonometry**: sin and cos tables → faster inner loops.
634. **Fixed-point integer maths**: integer-only fields → speed.
635. **Bit-packed masks**: 1 bit per pixel masks → memory.
636. **Run-length encoded sprites**: skip transparent runs when blitting → faster blits.
637. **Sprite span lists**: precomputed opaque spans → faster blits.
638. **Precomputed rotation frames**: 32 angles baked → no runtime rotation cost.
639. **Hierarchical Z for sprites**: skip fully covered sprites → overdraw saving.
640. **Effect quality tiers**: the same effect at 3 resolutions by device → scalability.

## Z. Meta, menus and progression screens
641. **PowerUp shop item breathing**: icons breathing, with a glint on affordable ones → shop.
642. **Collection grid reveal**: discovered items unblurred one by one → collection.
643. **Bestiary silhouettes**: undiscovered enemies as silhouettes with "?" → bestiary.
644. **Unlock tree lines**: connections drawn between unlocked nodes → progression.
645. **Stage select map fly-over**: a parallax map pan → stage select.
646. **Gold balance waterfall**: coins pouring into the counter → after a run.
647. **Achievement wall shimmer**: a wave shimmer across unlocked badges → achievements.
648. **Secret code input feedback**: glyphs glow as they're typed → secrets.
649. **Settings slider glow**: a glow follows the handle → settings.
650. **Loading screen pixel fill**: a loading progress drawn as a filling sprite → loading.
651. **Title logo shine**: a diagonal sweep plus sparkles → title screen.
652. **Title background parade**: enemies walking across in the background → title screen.
653. **Menu cursor trail**: a sparkle trail on the selection cursor → menus.
654. **Daily challenge seal**: a wax seal stamp → challenges.
655. **Leaderboard rank rise**: rows swapping with springs → leaderboards.
656. **Run summary timeline**: a graph of HP, kills and level over time → results.
657. **Damage pie chart**: a drawn pie with animated slices → results.
658. **Weapon damage heat ranking**: bars coloured by weapon element → results.
659. **New item badge**: a "NEW" label wobbling → new items.
660. **Profile card generator**: a card from character, stats and badges → sharing.

## AA. Hierarchy-driven effects (for readability)
661. **Focus dim**: everything outside a radius around the player slightly darkened → focus.
662. **Threat pulse**: enemies about to hit the player pulse red → anticipation.
663. **Projectile opacity by ownership**: other players' projectiles at 50% in co-op → clarity.
664. **Effect density limiter**: when too many effects overlap, low-priority ones fade → noise control.
665. **Priority-based particle budget**: particles allocated by importance → clarity.
666. **Pickup emphasis when safe**: pickups glow brighter when no enemies are near → guidance.
667. **Boss focus ring**: a faint ring linking the player to the boss direction → awareness.
668. **Elite marker above heads**: a small icon above elites → triage.
669. **Damage number filtering**: only numbers above a threshold are shown → clarity.
670. **Hit marker on crits**: a crosshair sparkle → crit readability.
671. **Danger zone overlay**: tinted ground where the danger density is high → avoidance.
672. **Safe path hint**: a faint highlight on the least dense direction → assist mode.
673. **Background desaturation by chaos**: the more chaos, the duller the background → readability.
674. **Outline-only mode for projectiles**: a projectile drawn as an outline at high density → clarity.
675. **Brightness ceiling**: overlapping additive effects clamped → no white-out.
676. **Player beacon**: a short ring pulse on the player when hidden by effects → visibility.
677. **Pickup magnet radius ring**: a faint ring showing the magnet range → planning.
678. **Weapon range previews**: faint arcs when hovering in level-up → planning.
679. **Cooldown ready flash**: a slot flashes when a weapon fires → rhythm.
680. **HUD fade when unused**: HUD parts fade when not changing → focus.

## AB. Juicy micro-feedback
681. **Button press squash**: 0.94 squash with a 1.06 release → every button.
682. **Pickup pop**: a scale pop on collect → collection.
683. **Number pop**: a scale pop when a number changes → counters.
684. **Slot fill flash**: a flash when a new weapon fills a slot → acquisition.
685. **Coin chime sparkle**: a sparkle per coin collected → gold.
686. **Gem tinkle sparkle**: a colour-matched sparkle per gem → XP.
687. **Level number flip**: the level digit flips over → level-up.
688. **Bar overshoot**: bars overshoot then settle → bars.
689. **Card select bounce**: the card bounces on selection → level-up.
690. **Reroll spin**: cards spin and swap → reroll.
691. **Banish shred**: the card shreds into strips → banish.
692. **Skip fade**: the cards slide away → skip.
693. **Menu open unroll**: the menu unrolls like a scroll → menus.
694. **Tab switch slide**: content slides with a spring → tabs.
695. **Tooltip lag follow**: the tooltip follows the cursor with a spring → tooltips.
696. **Error shake**: shake ±6 px with a red flash → invalid actions.
697. **Success sparkle**: a ring of sparkles → valid actions.
698. **Hover lift**: lift by 2 px plus a shadow grow → hover.
699. **Long-press fill**: a ring fills while held → hold-to-confirm.
700. **Charge meter wobble**: the meter wobbles near full → anticipation.

## AC. Explosions and impacts
701. **Layered explosion**: a flash, then a fireball, smoke, debris and a scorch, each its own layer → explosions.
702. **Shockwave refraction ring**: a ring displacing background pixels → big blasts.
703. **Pixel-art explosion sheet generator**: an explosion baked as 12 frames from noise → cheap explosions.
704. **Impact spark star**: a 4–8 point star that shrinks quickly → hits.
705. **Directional impact cone**: sparks in a cone along the hit normal → directional hits.
706. **Crit impact rings**: two rings in different colours with offset timing → crits.
707. **Ground crack decal**: radial cracks from the impact point → heavy hits.
708. **Debris arcs**: chunks with parabolic paths and bounces → destruction.
709. **Implosion collapse**: pixels pulled inward, then a burst → void attacks.
710. **Chain explosion propagation**: explosions triggering nearby ones by delay → combos.
711. **Mushroom cloud**: a rising toroid plus a stem → huge blasts.
712. **Holy explosion**: a cross-shaped flash with light rays → holy weapons.
713. **Ice explosion**: crystal spikes radiating → ice weapons.
714. **Poison explosion**: a green splash with lingering gas → poison weapons.
715. **Electric explosion**: an arc burst with forks → lightning weapons.
716. **Void explosion**: an inverted-colour sphere → dark weapons.
717. **Blood explosion**: droplets plus a splatter decal → gore setting.
718. **Gold explosion**: coins plus glitter → greed effects.
719. **Starburst explosion**: a star ring that rotates → magic.
720. **Pixel confetti explosion**: multicolour pixels with gravity → celebrations.

## AD. Trails, ribbons and motion
721. **Catmull-Rom trail smoothing**: smooth curves through past points → whips, swords.
722. **Tapered ribbon with UV scroll**: a texture scrolled along the ribbon → magic trails.
723. **Fading dot trail**: dots spaced by distance, fading → simple trails.
724. **Comet tail**: a stretched tail behind with a glow head → projectiles.
725. **Zigzag trail**: alternating offset points → electric trails.
726. **Sparkle trail emitter**: sparkles emitted by distance travelled → magical movement.
727. **Ghost trail sprite copies**: sprite copies with decreasing alpha → dashes.
728. **Ink brush trail**: width varying by speed → calligraphy effects.
729. **Fire trail**: flame particles left behind → fire dash.
730. **Ice trail**: frost decals left on the ground → ice paths.
731. **Shadow trail**: dark smoky trails → shadow characters.
732. **Rainbow trail**: hue by segment age → secret items.
733. **Light painting trail**: long exposure additive trails → menus.
734. **Speed lines**: lines behind fast objects → speed.
735. **Motion arcs**: arcs showing the swing path → melee readability.
736. **Path preview dashes**: animated marching dashes → previews.
737. **Bezier projectile curves**: projectiles flying curved paths → magic.
738. **Wobble projectile**: a sine offset perpendicular to motion → erratic magic.
739. **Spiral projectile**: rotation around the forward axis → drills.
740. **Boomerang easing**: decelerate, return and accelerate → Cross.

## AE. Ground and decals
741. **Decal pool with priority**: a fixed number of decals with the oldest replaced → performance.
742. **Decal fading by age**: alpha fading over time → clean ground.
743. **Decal blending**: overlapping decals merged → natural look.
744. **Scorch rings**: radial dark rings → fire impacts.
745. **Frost patches**: crystal decals → ice impacts.
746. **Holy glyph decals**: a cross glyph glowing then fading → holy impacts.
747. **Crack decals**: crack patterns scaled by damage → heavy impacts.
748. **Footprint decals**: per-step footprints → movement.
749. **Puddle decals**: water puddles that evaporate → water.
750. **Gold glint decals**: shiny spots where coins dropped → greed.
751. **Leaf litter decals**: leaves scattered by explosions → forests.
752. **Bone decals**: bone scatter after skeleton deaths → Bone Zone.
753. **Slime trail decals**: wet slime trails → slime enemies.
754. **Ash decals**: grey ash after fire → aftermath.
755. **Rune decals**: magic circle remnants → spells.
756. **Bullet hole decals**: holes with soot → projectile hits.
757. **Paint splash decals**: colour splashes → colourful weapons.
758. **Water ripple decals**: rings fading out → water hits.
759. **Sand ripple decals**: rings in sand → desert hits.
760. **Petal decals**: petals left after flower attacks → nature.

## AF. Time and rhythm effects
761. **Bullet time**: slowed simulation with ghosting → special moments.
762. **Rewind effect**: frames replayed backwards with a scanline overlay → time items.
763. **Time freeze crystallisation**: everything frozen with a crystal overlay → Orologion.
764. **Time ripple**: a ripple from the player that slows things inside it → time zones.
765. **Clock hand sweep**: a big clock overlay sweeping → time events.
766. **Hourglass flip transition**: the screen as sand falling → transitions.
767. **Day/night shadow sweep**: shadows rotating with time → long runs.
768. **Seasons cycle**: palette shifts through 4 seasons → long runs.
769. **Pulse clock**: UI pulses in time with a global tick → rhythm.
770. **Countdown flash**: the final 10 seconds flash red → urgency.

## AG. Interaction and interactivity
771. **Cursor-reactive particles**: particles repelled by the cursor → menus.
772. **Touch ripple**: a ripple from the touch point → mobile.
773. **Drag trail**: a trail behind dragged items → inventory.
774. **Hover reveal**: a hidden pattern revealed under the cursor → secrets.
775. **Paint mode**: the player paints on the map → fun extras.
776. **Interactive water**: the cursor makes ripples → menus.
777. **Grass parting**: the cursor parts grass → title screen.
778. **Magnetic snap**: items snap with a spring → inventory.
779. **Swipe streak**: a swipe gesture streak → mobile.
780. **Tilt parallax (gyro)**: layers shift by device tilt → mobile cards.

## AH. Hybrid and combo effects
781. **Fire + ice steam**: overlapping fire and ice zones produce steam → elemental combos.
782. **Lightning + water conduction**: lightning spreads through water puddles → combos.
783. **Poison + fire explosion**: gas clouds ignite → combos.
784. **Holy + dark cancellation**: opposing effects annihilate with a flash → combos.
785. **Wind + fire spread**: wind pushes fire → combos.
786. **Ice + physics shatter**: frozen enemies shatter when hit hard → combos.
787. **Gravity + particles orbit**: particles caught in gravity wells → combos.
788. **Light + crystal refraction**: beams split by crystals → combos.
789. **Water + growth**: plants grow where water falls → combos.
790. **Curse + gold transmutation**: cursed kills drop coins → combos.

## AI. Procedural sprite generation
791. **Procedural enemy generator**: symmetric pixel sprites from noise plus a palette → endless enemy variants.
792. **Procedural weapon icons**: blade, hilt and gem parts combined → loot variety.
793. **Procedural potion icons**: bottle shape plus liquid colour → consumables.
794. **Procedural gem icons**: facet shading from a polygon → gem types.
795. **Procedural spell icons**: glyph plus ring plus colour → spells.
796. **Procedural rune stones**: stone shape with a carved glyph → runes.
797. **Procedural tree sprites**: trunk plus canopy blobs → map trees.
798. **Procedural rock sprites**: a Voronoi rock with highlights → map rocks.
799. **Procedural flower sprites**: petals in a ring with a centre → flowers.
800. **Procedural crystal sprites**: a prism shape with an internal glow → crystals.
801. **Procedural chest sprites**: box, lid, trim and lock → chest variety.
802. **Procedural banner sprites**: cloth plus an emblem → decor.
803. **Procedural emblem generator**: a heraldic shield with charges → guild badges.
804. **Procedural face portraits**: eyes, nose and mouth from parts → NPCs.
805. **Procedural planet sprites**: a sphere with noise terrain and an atmosphere rim → space stages.
806. **Procedural ghost sprites**: wavy-bottom blobs with eyes → ghost variants.
807. **Procedural slime sprites**: blobs with a highlight and eyes → slime variants.
808. **Procedural bat sprites**: a body plus generated wing shapes → bat variants.
809. **Procedural skeleton sprites**: bones from line segments → skeleton variants.
810. **Procedural boss sprites**: a large symmetric design plus extra parts → endless bosses.

## AJ. Mathematical spectacles
811. **Mandelbrot zoom**: a deep zoom with smooth colouring → secret screens.
812. **Julia set morph**: the c parameter animated → Arcana backgrounds.
813. **Burning Ship fractal**: an absolute-value variant → fire Arcana.
814. **Newton fractal**: basins of attraction → puzzle art.
815. **Lyapunov fractal**: the stability of a sequence → alien textures.
816. **Buddhabrot**: an escape-trajectory density → mystical backgrounds.
817. **Sierpinski reveal**: a triangle fractal drawn in by recursion → triangle sigils.
818. **Koch snowflake grow**: iterations animated → ice sigils.
819. **Apollonian gasket**: circle packing → holy patterns.
820. **Hopf fibration projection**: a 4D projection drawn in 2D → secret ending.
821. **Lorenz attractor**: a butterfly trajectory → chaos Arcana.
822. **Double pendulum chaos**: a traced pendulum path → chaos visuals.
823. **Harmonograph**: damped pendulum curves → sigils.
824. **Strange attractor painting**: density-accumulated attractor points → backgrounds.
825. **Fourier drawing**: epicycles tracing a silhouette → reveals.
826. **Prime spiral (Ulam)**: primes on a spiral → secrets.
827. **Collatz tree**: a branching path visualisation → lore art.
828. **Fibonacci tiling**: squares with a spiral → golden UI.
829. **Polar function bloom**: an animated r(θ) curve → magic.
830. **Elementary CA rule 30 textures**: a 1D CA scrolled → glitch textures.

## AK. Atmosphere and mood
831. **God rays through canopy**: light shafts from a leaf mask → forests.
832. **Dust in light beams**: particles visible only inside beams → interiors.
833. **Candle-lit vignette**: a warm vignette with flicker → castles.
834. **Moonlight tint**: a blue cast with stronger contrast → night.
835. **Blood moon tint**: a red cast with an eerie pulse → events.
836. **Aurora ribbons**: sine-warped vertical curtains → cold stages.
837. **Heat haze horizon**: a wavering horizon band → deserts.
838. **Distant lightning flicker**: a background brightening flicker → storms.
839. **Falling stars**: occasional streaks across the sky → night.
840. **Mist curling**: domain-warped mist near the ground → swamps.
841. **Spirit wisps**: slow glowing orbs drifting → haunted stages.
842. **Crows taking off**: birds burst away when the player approaches → ambience.
843. **Ripple of wind through trees**: a wave of sway across tree sprites → forests.
844. **Sunbeam sweep**: a slow-moving light beam → cathedral.
845. **Underwater light dapple**: moving bright patches → water stages.
846. **Floating islands drift**: background layers bobbing → sky stages.
847. **Snow drift wind**: snow blown across the ground → snow stages.
848. **Lightning-lit silhouettes**: background shown only during flashes → horror.
849. **Ember glow on stones**: residual glow fading on stones near fire → fire stages.
850. **Breathing darkness**: darkness edges pulsing slowly → horror.

## AL. Materials and surfaces
851. **Metal anisotropic sheen**: a stretched highlight moving with the view → armour.
852. **Glass refraction**: the background offset by a normal map → crystals, potions.
853. **Gold specular sparkle**: random glints on gold pixels → treasure.
854. **Cloth weave texture**: a woven pattern from a sine grid → banners.
855. **Leather grain**: Worley plus fine noise → books, armour.
856. **Wood rings**: concentric noise rings → crates.
857. **Stone with moss**: stone noise plus a moss mask on top → ruins.
858. **Marble veins**: domain-warped sine → cathedral floors.
859. **Ice with bubbles**: a translucent ramp plus bubble dots → ice.
860. **Lava rock glow cracks**: glowing cracks in dark rock → fire.
861. **Crystal facets**: Voronoi facets shaded by a light direction → gems.
862. **Slime gloss**: a highlight blob plus a translucent edge → slimes.
863. **Holographic film**: a rainbow by angle → legendary items.
864. **Rust patches**: a noise-thresholded rust colour → old metal.
865. **Paper texture**: fibre noise plus slight yellowing → scrolls, menus.
866. **Velvet**: dark centre, bright edges (a Fresnel-like effect) → royal UI.
867. **Pearl iridescence**: a hue shift by normal → pearls.
868. **Bone texture**: porous Worley noise → bones.
869. **Feather barbs**: line patterns along the shaft → feathers.
870. **Scales**: an overlapping arc tile pattern → reptile enemies.

## AM. Camera, view and space
871. **Infinite zoom transitions**: one scene zooming into the next → stage changes.
872. **Fake 3D tilt of the whole map**: the map row scale varies (Mode 7) → special stages.
873. **Mode 7 floor**: an affine floor projection → racing or flying bonus.
874. **Fisheye lens**: radial distortion → Moongolow eclipse.
875. **Barrel distortion pulse**: on big hits → impact.
876. **Tilt-shift blur**: blurred top and bottom bands → miniature look.
877. **Depth of field by layer**: background layers blurred → focus.
878. **Split screen**: two views composited → local co-op.
879. **Picture-in-picture**: a mini-view of the boss → awareness.
880. **Rotating camera roll**: a slight roll on dash → dynamism.

## AN. Retro and stylisation filters
881. **Game Boy 4-shade filter**: a 4-colour palette with a dot matrix → retro mode.
882. **NES palette filter**: snap to the 54-colour NES palette → retro mode.
883. **CGA filter**: a 4-colour CGA palette → retro mode.
884. **Commodore 64 palette**: a 16-colour palette with dithering → retro mode.
885. **Virtual Boy red**: a red monochrome → secret mode.
886. **VHS tape effect**: chroma bleed, tracking lines and noise → horror.
887. **Old film**: grain, scratches, flicker and sepia → flashbacks.
888. **Comic panel mode**: an ink outline plus halftone → special mode.
889. **Woodcut**: hatching lines by luminance → lore screens.
890. **ASCII render**: luminance mapped to glyphs → secret mode.
891. **Pixel art upscalers (xBR, EPX)**: smoother scaled sprites → HD option.
892. **Ink wash**: grey wash ramps with bleed → Asian-themed stages.
893. **Stained glass filter**: Voronoi cells plus dark leading → cathedral.
894. **Mosaic tiles**: tiles with grout lines → floors.
895. **Cross-stitch filter**: X-shaped pixels on cloth → cosy mode.
896. **Lego brick filter**: blocks with studs → fun mode.
897. **Neon outline mode**: edges only, glowing → arcade mode.
898. **Blueprint mode**: white lines on blue → debug-art mode.
899. **Thermal camera**: a heat ramp → special item.
900. **Infrared ghost reveal**: hidden objects shown only in IR mode → secrets.

## AO. Endgame and spectacle at scale
901. **Screen-filling projectile carpets**: thousands of sprites in one batch → late game.
902. **Light-show mode**: weapon colours driving the background tint → late-game flair.
903. **Kill streak aura**: the aura grows with consecutive kills → power fantasy.
904. **Dominion effect**: enemies dissolve as they enter a radius → godlike builds.
905. **Gem tsunami**: a wave of gems sweeping into the player → magnet pickups late game.
906. **Gold rain storm**: gold falling everywhere during Gold Fever → late game.
907. **Evolution showcase**: a short slow-motion moment on a new evolution → moments.
908. **Max level burst**: a radial pulse when all slots are maxed → completion.
909. **Infinite enemy shimmer**: crowd LOD as a living texture → 5000 enemies.
910. **Reaper approach darkening**: darkness creeping from the edges at 30:00 → finale.
911. **Final screen erase spectacle**: a white wave erasing all enemies → endgame.
912. **Victory crown**: a crown descending onto the player → wins.
913. **Overkill fireworks**: fireworks on big damage spikes → spectacle.
914. **Damage meter crescendo**: the screen border glows with DPS → power feel.
915. **Combo shatter**: the screen cracks and repairs on huge combos → spectacle.
916. **God mode silhouette**: the player becomes a glowing silhouette → max power.
917. **Map-wide lightning storm**: random bolts everywhere → late-game weapons.
918. **Black hole finale**: everything sucked to the centre → special endings.
919. **Star collapse**: a screen-wide implosion then a bloom → special endings.
920. **New Game+ glitch**: the world glitches into a remixed palette → replays.

## AP. Utility and infrastructure ideas
921. **Effect scheduler by tier**: effects at 60/30/15/8 fps with staggered updates → performance.
922. **Frame budget manager**: the low-priority effects skip frames when over budget → stability.
923. **Memory budget monitor**: tracks EditableImage memory and degrades quality → mobile safety.
924. **Shared noise textures**: precomputed noise atlases reused by all effects → memory and time.
925. **Sprite cache by parameters**: generated sprites cached by a key → speed.
926. **Deterministic RNG streams**: per-effect seeds → reproducible QA.
927. **Effect recorder**: frames captured to buffers for QA → golden images.
928. **Effect parameter inspector**: on-screen sliders for tuning → iteration speed.
929. **Hot-reload effect params**: live parameter updates → iteration.
930. **Effect benchmark scene**: the standard stress scene → regressions.
931. **Pixel-perfect camera snapping**: the camera snapped to integer pixels → crispness.
932. **Integer scale manager**: chooses the best integer scale per device → crispness.
933. **Palette manager**: a global palette per stage → consistency.
934. **Layer manager**: ZIndex assignments by hierarchy → hierarchy.
935. **Effect pooling**: effects reused, never destroyed → GC stability.
936. **Buffer pooling**: buffers reused between effects → GC stability.
937. **Parallel simulation via Actors**: simulations run in parallel → speed.
938. **Off-thread baking**: bakes spread across frames with coroutines → no hitches.
939. **Progressive generation**: big effects generate over several frames → no spikes.
940. **Quality presets**: low, medium, high and ultra effect sets → device range.

## AQ. Experimental and novel
941. **Neural-style palette transfer (precomputed LUT)**: a colour mood from a reference image → stage themes.
942. **Wave Function Collapse animated**: watching WFC solve the map → loading screens.
943. **Genetic art evolution**: patterns evolved by selection → secret gallery.
944. **Reaction-diffusion as a weapon field**: patterns that grow damage zones → unique weapon.
945. **Physarum as a pathfinding enemy**: slime that finds the player through a network → unique enemy.
946. **Lenia creatures as enemies**: continuous-CA lifeforms that hunt → unique enemy.
947. **Boids with predator avoidance**: swarms fleeing the player's aura → fear mechanics.
948. **Sound-of-colour synaesthesia**: hue mapped from sound pitch → art mode.
949. **Fluid ink weapon**: a weapon that paints a fluid dye that damages enemies → unique weapon.
950. **Sand alchemy**: a falling-sand world where weapons interact with materials → sandbox mode.
951. **Destructible pixel enemies**: enemies lose pixels where they are hit → visceral damage.
952. **Living map**: tiles evolving by CA during the run → dynamic stages.
953. **Shadow puppets**: light and shadow as enemies → special stage.
954. **Mirror world**: a reflected copy with inverted colours → special stage.
955. **Echo trails**: past player positions spawn echo attacks → unique weapon.
956. **Painted enemy paths**: enemies leave colour trails that form art → end-of-run art.
957. **End-of-run painting**: the run's paths accumulated into an image → share screen.
958. **Kill heatmap art**: kill locations as a heat painting → results.
959. **Run fingerprint**: a unique glyph from the run stats → sharing.
960. **Generative music visuals**: visuals generated from the game state → ambience.

## AR. Accessibility-focused effects
961. **High-contrast mode**: an outline plus flat colours → low vision.
962. **Colour-blind palettes**: alternative ramps for each effect → colour blindness.
963. **Reduced motion mode**: no shake and slower effects → motion sensitivity.
964. **Flash limiter**: luminance changes capped per second → photosensitivity.
965. **Big text mode**: scaled pixel fonts with outlines → readability.
966. **Projectile shape coding**: shapes plus colours for elements → colour independence.
967. **Enemy pattern overlays**: stripes and dots for enemy types → colour independence.
968. **Audio cue visualiser**: on-screen icons for important sounds → deaf players.
969. **Aim assist glow**: a faint target highlight → motor accessibility.
970. **Clutter reducer slider**: scales the effect density → focus.

## AS. Polish passes (systemic)
971. **Consistent light direction**: all baked shading from top-left → coherence.
972. **Global squash timing curve**: one easing curve family for all → coherence.
973. **Unified sparkle shape**: the same 4-point sparkle everywhere → coherence.
974. **Unified glow palette per element**: fire, ice, holy, dark, poison and lightning → coherence.
975. **Element colour hierarchy**: player-owned effects brighter than enemy effects → readability.
976. **Pixel density consistency**: all effects at the same pixel scale → coherence.
977. **Outline consistency**: 1 px dark outline on all sprites → coherence.
978. **Shadow consistency**: one shadow style for all entities → coherence.
979. **Timing consistency**: hits at 60 ms, pops at 120 ms, reveals at 300 ms → coherence.
980. **Colour temperature by stage**: each stage's palette biased warm or cool → identity.

## AT. Cross-system showpieces
981. **Living HUD**: HUD frames react to game state (cracks at low HP, glow at level-up) → immersion.
982. **Weapon-themed HUD slots**: each slot with a micro-animation of its weapon → identity.
983. **Diegetic XP**: XP gems orbit the player before entering the bar → connection.
984. **Kill counter skulls**: skulls fill a jar → fun counters.
985. **Gold piles growing in the corner**: an actual pile of coin sprites → greed feel.
986. **Timer as a sun arc**: the sun moves across the top over 30 minutes → time feel.
987. **Health as a candle**: the candle melts as you take damage → theme.
988. **Level-up portal**: the level-up screen opens from a portal at the player → continuity.
989. **Chest light connected to the HUD**: light travels from the chest to the HUD slot → continuity.
990. **Evolution tree drawing**: a vine draws between weapon and passive icons → evolution clarity.
991. **Stage intro map draw**: the stage drawn as ink spreading → stage starts.
992. **Boss bar from the boss**: the HP bar tears off the boss sprite → continuity.
993. **Death recap rewind**: the last 3 seconds replayed in fast rewind → game over.
994. **Revival time reversal**: the screen rewinds briefly → revive.
995. **Arcana world tint**: each Arcana tints the world subtly → identity.
996. **Curse world corruption**: the map corrupts more as curse rises → feedback.
997. **Luck sparkle density**: ambient sparkles scale with Luck → stat feel.
998. **Greed gold tint**: gold highlights scale with Greed → stat feel.
999. **Speed wind**: ambient wind streaks scale with move speed → stat feel.
1000. **Power aura**: the aura scales with total might → stat feel.
