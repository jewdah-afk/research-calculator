# Onslaught 2: HTML remake

`index.html` is a single file you can open in any browser. It is a playable remake of Onslaught 2. All numbers and map paths come from the original game's code (`../onslaught-data/`), and the art is drawn on a canvas in the original's style.

To rebuild after the data or the template changes, run `python3 build.py`. It inlines `defaults.json` and `maps.json` into `template.html`.

## What matches the original
- 4 colour turrets with their exact costs, base stats and upgrade tables, plus Freakout for Blue and Yellow.
- The Green laser chain: ready greens in range add their damage ×1.25.
- The Yellow tazer: its spark slows by subtracting from speed, and charge boosts the slow. As in the original, charge does not boost damage.
- The 7 modifier turrets and 3 super turrets, which unlock at the original kill counts.
- All 20 combos: the original recipes, partner use, recharge times and damage values. A turret can combo once its damage is maxed, and partners must be within 70px.
- Waves: 10 attackers, 700ms apart, 20s between waves, and 9 attacker types that cycle. HP grows ×rate per wave from each difficulty's table. Bounty is $1 times the wave number, and you start with 10 lives and $30.
- All 12 maps.
- Selling refunds 70% of what you spent on the turret.

## Approximations
- The art is redrawn, not the original sprites.
- Some combo details are approximate: cluster bomblet behaviour, the BFG's side rockets, the laser-rocket fire rate and the poison-gas slow strength.
- Not included: challenge games, the map editor, mods, the Targeter and Combonly turrets, and the Red rocket holding pattern.

Keys: 1-4 build · Q/W/E upgrade · S sell · N next wave · F speed · P pause · Esc cancel.
