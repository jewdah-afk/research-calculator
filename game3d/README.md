# Peckwood 3D (web)

A 2.5D web build of Peckwood. It is the guide for the Roblox version.

- **Logic:** none of its own. It loads `../playtest/js/*` (1:1 with Birb, checked by `playtest/parity`), so every number and system matches the playtest.
- **View:** `render3d.js` (three.js r128). Fixed camera angle (straight ahead, tilted 52° down), orthographic, free zoom (wheel, pinch, + / -), clamped to the shown world plus a band of sea.
- **World:** maps sit side by side in one world and you walk across their edges: Nest | Park | Sunflower Field | Bridge (`LAYOUT` in `render3d.js`). A map shows once you can walk into it. Rooms (nest interior, aquarium, mine, expedition...) are their own islands, reached with the arrows as before.
- **Ground:** LEGO brick columns with studs and a ragged sand coast (only the map is LEGO). **Models:** clean low-poly (eggs per type, the birb, sparrows, pines, planters, the nest tree, the Red Panda).
- **3D so far:** the Park (eggs, collecting, sparrows, pickup ring) and the Nest (forest, planting beds, nest tree, Red Panda). Every other map is drawn flat (the playtest drawing) on a 3D ground plate until it gets its own 3D scene.
- **Hooks in `playtest/js/main.js`:** `window.R3D.render` replaces the 2D render, `R3D.edge` walks across edges, `G.clickWorld` takes clicks in map coordinates, `G.render2D` draws a map flat for the fallback plates. Without `render3d.js` the playtest runs as before.

Open `game3d/index.html` through any static server from the repo root (it shares the playtest save).

Next: Sunflower Field and Bridge in 3D (stations, platform, fishing), then the Desert, the Aquarium / Market, the Mine and the Expedition.
