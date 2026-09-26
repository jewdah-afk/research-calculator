// stills.js - the realm and UI stills the thumbnails are built from, rendered by the real client (snap_mk.luau) with a
// marketing camera. Camera = world px x, y and map zoom z (the realm is 3840 x 2560; z runs 0.24 .. 1.25).
//   cd art/marketing && node stills.js [name ...]        -> work/stills/<name>.png
const path = require('path'), fs = require('fs');
const { still } = require('./lib/snap');
const OUT = path.join(__dirname, 'work', 'stills');

const SHOTS = {
  // 1 GROW THE TREE: the lit tree, framed right of centre so the title block has the sky on the left
  tree: { scene: 's13_none', cam: '1060,1135,0.57', hide: ['hud', 'plate_ach'] },
  // 2 PRESTIGE: the Prestige gem up close (right), and the real P panel for the hero card crop
  prestige_bg: { scene: 's13_none', cam: '925,1597,1.2', hide: ['hud', 'plate_pe', 'plate_pp', 'plate_mm', 'plate_pb'] },
  panel_p: { scene: 'panel_p', cam: 'keep', hide: ['toasts'] },
  // 3 ENTER THE MULTIVERSE: inside the Prestige Multiverse, the rift and its lit nodes
  rift: { scene: 's19mv_none', cam: '2860,1250,0.95', hide: ['hud', 'plate_pm'] },
  // 4 FIX THE CORRUPTION: the corrupted island, its READY nodes, and the CR panel for the CORRUPT card crop
  corrupt: { scene: 's19mv_none', cam: '3290,1060,1.25', hide: ['hud', 'plate_pm', 'plate_pep', 'plate_ex'] },
  panel_cp: { scene: 'panel_cp', cam: 'keep', hide: ['toasts'] },
  // 5 EXPLORE: the whole realm (the zoom floor)
  explore: { scene: 's13_none', cam: '1920,1280,0.2', hide: ['hud'] },
};

if (require.main === module) (async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const names = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(SHOTS);
  for (const n of names) await still({ ...SHOTS[n], out: path.join(OUT, `${n}.png`) });
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
module.exports = { SHOTS };
