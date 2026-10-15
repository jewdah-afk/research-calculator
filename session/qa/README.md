# QA tools used this session
- `lab_check.py`: runs every Algorithm Lab plate headless in Node (timing, colour count, errors).
- `shot.js` / `shot3.js`: Playwright screenshots of the lab page (Chromium at `/opt/pw-browsers/chromium`; run with `NODE_PATH=$(npm root -g) node shot3.js`). Paths inside point at `/home/user/research-calculator/ideas/algorithm-lab.html`; edit the card ranges as needed.
- `sheet.py`: builds a contact sheet from PPM frames written by `pixelfx/qa/run.luau`.
- Luau CLI: download `https://github.com/luau-lang/luau/releases/download/0.700/luau-ubuntu.zip`, then `cd pixelfx/qa && luau run.luau > frames.bin`.
