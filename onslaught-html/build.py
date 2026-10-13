"""Build index.html: inline the engine, the expansion and the game data into template.html.

Usage: python3 build.py
"""
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
data_dir = here.parent / "onslaught-data"

game = json.loads((data_dir / "game.json").read_text())
expansion = json.loads((data_dir / "expansion.json").read_text()) if (data_dir / "expansion.json").exists() else {}

html = (here / "template.html").read_text()
html = html.replace("/*__GAME__*/null", json.dumps(game, separators=(",", ":")))
html = html.replace("/*__EXPANSION__*/null", json.dumps(expansion, separators=(",", ":")))
html = html.replace("/*__ENGINE__*/", (here / "engine.js").read_text())
exp_js = here / "expansion.js"
html = html.replace("/*__EXPANSION_JS__*/", exp_js.read_text() if exp_js.exists() else "")
(here / "index.html").write_text(html)
print("wrote", here / "index.html", len(html), "bytes")
