"""Assemble the single-file prototype: python3 rogue/prototype/build.py -> design/rogue-ui/peckwood-rogue-prototype.html
Parts: head.html (UI + CSS), engine.js (world gen + renderer), data.js (all balance tables), game.js (systems)."""
import os
H = os.path.dirname(os.path.abspath(__file__)); r = lambda f: open(os.path.join(H, f)).read()
out = r('head.html').replace('__ICONS__', r('icons.json')) + r('engine.js') + r('data.js') + r('game.js') + '\n</script>\n'
open(os.path.join(H, '..', '..', 'design', 'rogue-ui', 'peckwood-rogue-prototype.html'), 'w').write(out)
print('built', len(out))
