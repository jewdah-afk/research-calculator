# Peckwood 3D (web)

A 2.5D web build of Peckwood. It is the guide for the Roblox version.

- **Logic:** none of its own. It loads `../playtest/js/*` (1:1 with Birb, checked by `playtest/parity`), so every number and system matches the playtest.
- **World:** `world.html` is the Peckwood World Guide (every tile, prop, the sea, lighting, day cycle) in game mode: demo UI hidden, `window.WG` exposes the scene, camera, `groundY`, `unlock`, `flyTo`. Islands rise (terraform) the first time you reach them.
- **Game layer:** `render3d.js` loads `world.html` in a frame and adds the birb, eggs, sparrows, nest trees and planters. Camera: fixed angle (straight north, tilted down), follows the birb, zoom clamped to the island plus some sea. Birb maps sit on islands: Park→park, Sunflower→garden, Bridge/Aquarium/Market→bridge, Castle→castle, Nest→forest, Mine→mine, Desert→desert, Echo→echo, Expedition→expedition.
- **Models:** clean low-poly (eggs per type, the birb, sparrows, pines, planters, the Red Panda); the map is LEGO.
- **3D so far:** the Park (eggs on open ground, collecting, sparrows, pickup ring), the Nest on the forest island (30 choppable trees replace the decorative ones, planters, Red Panda) and the Sunflower Field on the garden island (station pedestals coloured by state with name / cost cards). Eggs, trees and the birb keep to open ground (ponds, props and sea are blocked; the shore counts as the map edge).
- **Hooks in `playtest/js/main.js`:** `window.R3D.render` replaces the 2D render, `R3D.edge` takes the arrow when you walk off an edge, `G.clickWorld` takes clicks in map coordinates, `G.render2D` draws the corner panel. Without `render3d.js` the playtest runs as before.

Open `game3d/index.html` through any static server from the repo root (it shares the playtest save).

Next: Sunflower Field and Bridge in 3D (stations, platform, fishing), then the Desert, the Aquarium / Market, the Mine and the Expedition.
