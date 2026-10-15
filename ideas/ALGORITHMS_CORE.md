# 100 core algorithms (maths → what it builds)

These are the generative algorithms themselves, the same kind of thing as the artifact's list (Doom Fire, Reaction-Diffusion, Voronoi, Boids...).
Left out because they're already built: the artifact's 89 effects and `pixelfx/` (Lichtenberg DBM, Physarum, 2D wave equation, DLA, Jump Flood, void-and-cluster blue noise, bloom, Floyd–Steinberg/OKLab dither, phyllotaxis, spring orbits, FABRIK, 4-5 cave CA, slot reel, enemy bake, flow-field crowd).

## Simulation and physics
1. **Shallow water equations**: height and velocity grid with momentum → travelling splashes and waves.
2. **Lattice Boltzmann (D2Q9)**: particle distributions on a lattice → realistic liquid flow, vortices.
3. **SPH**: particles with a pressure kernel → pourable liquids, blood.
4. **FLIP / PIC**: particle velocities mapped to a grid → splashy water.
5. **Vorticity confinement**: re-injected curl → swirly, alive smoke.
6. **Position-based dynamics**: constraint projection → cloth, ropes and soft bodies in one solver.
7. **Pressure soft body**: a point ring plus an area constraint → squishy slimes.
8. **Mass-spring lattice**: Hooke springs on a grid → jelly deformation of sprites.
9. **2D rigid-body impulse solver**: boxes and circles with friction → tumbling debris.
10. **Granular flow with angle of repose**: a sand CA with slope rules → sand piles, hourglasses.
11. **Hydraulic erosion**: droplets carving and depositing → terrain.
12. **Thermal erosion**: slope-limited transfer → cliffs, scree.
13. **Heat diffusion with sources**: the heat equation → fire spread, warmth fields.
14. **Advection–reaction–diffusion**: moved field plus a reaction → poison, corruption spread.
15. **Membrane standing waves**: modal wave sums → Chladni patterns.
16. **Abelian sandpile**: avalanche toppling → fractal piles, coin heaps.
17. **Barnes–Hut N-body**: quadtree gravity → orbits, galaxies, swarms.
18. **Elastic rod (Kirchhoff)**: bending stiffness → whips and tentacles with real curl.

## Cellular automata
19. **Lenia**: continuous Life → organic moving creatures.
20. **SmoothLife**: continuous-space Life → blob creatures.
21. **Cyclic CA**: N cycling states → self-organising spirals.
22. **Belousov–Zhabotinsky (hodgepodge)**: oscillating chemistry → spiral waves.
23. **Brian's Brain**: 3-state CA → electric crackle.
24. **Langton's ant / turmites**: state-machine walkers → emergent highways.
25. **Forest-fire model**: growth, lightning, spread → self-organised fire waves.
26. **Reiter snowflake**: hexagonal vapour CA → real snowflakes.
27. **Ising model (Metropolis)**: energy-based spin flips → domain textures.
28. **Rock–paper–scissors CA**: cyclic dominance → battling colour spirals.
29. **FHP lattice gas**: hex-lattice particles → cheap fluid.
30. **Meinhardt shell CA**: 1D activator–inhibitor → seashell patterns.
31. **Elementary CA (rules 30, 90, 110)**: scrolled 1D rules → glitch and Sierpinski textures.
32. **Margolus block CA**: reversible 2×2 rules → falling particles, gas.

## Growth and morphogenesis
33. **Eden growth**: random boundary accretion → coral, mould.
34. **Anisotropic DLA**: lattice-biased aggregation → frost ferns, crystals.
35. **Differential growth**: a curve with repulsion that subdivides as it grows → brain coral, ruffled edges.
36. **Auxin leaf venation (Runions)**: veins grow toward sources → leaves.
37. **Gierer–Meinhardt Turing patterns**: activator–inhibitor → spots and stripes.
38. **Voronoi cell division + Lloyd**: splitting and relaxing → tissue, honeycomb.
39. **Murray's-law branching**: flow-conserving radii → blood vessels, rivers.
40. **Stochastic parametric L-systems**: probabilistic rules → varied plants.
41. **Shape grammars**: rule-based geometry → buildings, ornaments.
42. **Stress-field crack propagation**: fracture along a gradient → realistic cracks.
43. **Mycelium growth (tip branching + anastomosis)**: hyphae that branch and fuse → fungal networks.
44. **Reaction-diffusion on a growing domain**: patterns that split as the area grows → animal skins forming.

## Noise and procedural texture
45. **Simplex / OpenSimplex noise**: gradient noise without grid artefacts → base for everything.
46. **Gabor noise**: oriented sparse convolution → wood, brushed metal.
47. **Wavelet noise**: band-limited noise → crisp detail at every scale.
48. **Ridged multifractal**: absolute inverted fBm → mountains, energy veins.
49. **Worley F2−F1 and variants**: cellular distance combinations → cracks, scales, cobbles.
50. **Flow noise**: rotating gradients → swirling liquids.
51. **Spectral synthesis (inverse FFT)**: shaped spectrum → ocean, clouds.
52. **Phasor noise**: oscillation field with no contrast loss → clean stripes and waves.
53. **Multi-scale Truchet**: rotated arc tiles at several sizes → mazes, knots.
54. **Wave Function Collapse**: constraint propagation → maps and buildings from samples.
55. **Wang / corner tiles**: edge-matched sets → seamless terrain.
56. **Efros–Leung texture synthesis**: patch growth from an example → texture from a sample.

## Geometry and space
57. **Delaunay (Bowyer–Watson)** → low-poly art, meshes.
58. **Weighted Voronoi / power diagrams** → cells of varying size.
59. **Lloyd relaxation** → even stippling, cells.
60. **Medial axis / skeletonisation** → sprite skeletons, auto rigging.
61. **Marching squares** → contours and autotile edges.
62. **2D dual contouring** → sharp-cornered contours.
63. **Convex hull (monotone chain)** → bounds, shields.
64. **Exact Euclidean distance transform (Felzenszwalb)** → exact glows.
65. **SDF composition (smooth union, blend, morph)** → shape morphs, auras.
66. **Polygon offsetting / Minkowski sum** → outlines and auras around shapes.
67. **Front-chain circle packing** → bubbles, scales.
68. **Penrose deflation tiling** → ornate floors.
69. **Girih star construction** → ornament.
70. **Hilbert / Peano / Gosper curves** → space-filling reveals.
71. **Bezier / Catmull-Rom / B-spline evaluation** → paths, ribbons.
72. **Superformula (Gielis)** → morphing organic shapes.

## Agents and crowds
73. **Reynolds steering (seek, flee, arrive, wander, pursue)** → enemy behaviours.
74. **Ant colony optimisation** → pheromone networks.
75. **Particle swarm optimisation** → swarms converging on targets.
76. **Vicsek model** → flocks with alignment noise.
77. **Kuramoto oscillators** → fireflies blinking in sync.
78. **Lotka–Volterra agents** → population waves.
79. **RVO / ORCA** → crowds that avoid each other smoothly.
80. **Continuum crowds** → huge flowing crowds from density plus potential fields.

## Fractals and chaos
81. **Escape-time fractals (Mandelbrot, Julia, Burning Ship, Newton)**.
82. **IFS / fractal flames (Barnsley fern, flame variations)**.
83. **Strange attractors (Lorenz, Clifford, De Jong)**.
84. **Buddhabrot** (trajectory density).
85. **Apollonian gasket** (circle inversion).
86. **Kleinian groups / Indra's pearls** (Möbius transforms).
87. **Lyapunov fractals**.
88. **Harmonograph and double pendulum**.

## Image processing and rendering
89. **Kuwahara / anisotropic Kuwahara** → painterly look.
90. **Bilateral and guided filters** → edge-preserving smoothing.
91. **Summed-area tables** → O(1) blur at any radius.
92. **Kawase and dual-filter blur** → cheap bloom.
93. **Pixel-art scalers (xBR, EPX/Scale2x, hqx)** → smooth pixel upscales.
94. **Poisson image editing** → seamless decals.
95. **Seam carving** → content-aware sprite squash.
96. **Lucas–Kanade optical flow** → generated in-between frames.
97. **2D radiance cascades** → real 2D global illumination.
98. **2D SDF raymarched soft shadows**.
99. **Palette-index rendering with cycling ranges** → animated water, fire and lava for free.
100. **Temporal reprojection / accumulation** → noise-free effects at low cost.
