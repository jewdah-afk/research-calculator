"""Headless check for ideas/algorithm-lab.html: runs every plate for N steps in Node and prints ms/step,
colour count and errors. Usage: python3 session/qa/lab_check.py [steps]"""
import subprocess, sys, tempfile, os
steps = int(sys.argv[1]) if len(sys.argv) > 1 else 30
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
s = open(os.path.join(root, 'ideas', 'algorithm-lab.html')).read()
js = s[s.index('<script>') + 8:s.index('const grid =')]
js += '''
for (const [k, D] of DEMOS.entries()) { const st = { w: D.w, h: D.h }, px = new Uint32Array(D.w * D.h), t0 = Date.now(); let err = '';
  try { D.init(st); for (let i = 0; i < %d; i++) D.step(st, px); } catch (e) { err = e.message; }
  console.log(String(k + 1).padStart(3), String((Date.now() - t0) / %d | 0).padStart(4), 'ms', String(new Set(px).size).padStart(5), 'cols', err, D.name); }
''' % (steps, steps)
f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False); f.write(js); f.close()
subprocess.run(['node', f.name])
