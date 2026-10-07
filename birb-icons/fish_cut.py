"""Download a generated fish sheet and cut it: python3 birb-icons/fish_cut.py <sheet_no> <url>"""
import json, os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut_grid import cut
HERE = os.path.dirname(os.path.abspath(__file__))
n, url = int(sys.argv[1]), sys.argv[2]
p = json.load(open(os.path.join(HERE, 'sheets', 'fish_prompts.json')))[n - 1]
dst = os.path.join(HERE, 'sheets', p['sheet'] + '.png')
subprocess.run(['curl', '-sL', '-o', dst, url], check=True)
cut(dst, 4, 4, p['names'], out=os.path.join(HERE, 'final', 'fish'))
