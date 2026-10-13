"""Inline the extracted Onslaught 2 data into the HTML remake.

Usage: python3 build.py   (writes index.html next to this file)
"""
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
data_dir = here.parent / "onslaught-data"

defaults = json.loads((data_dir / "defaults.json").read_text())
maps = json.loads((data_dir / "maps.json").read_text())

html = (here / "template.html").read_text()
html = html.replace("/*__DEFAULTS__*/null", json.dumps(defaults, separators=(",", ":")))
html = html.replace("/*__MAPS__*/null", json.dumps(maps, separators=(",", ":")))
(here / "index.html").write_text(html)
print("wrote", here / "index.html", len(html), "bytes")
