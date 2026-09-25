# States the web game itself hangs on (or cannot boot) in a fuzz_js.js run, as the Luau skip list:
# python3 tools/skiplist.py js.txt fz_skip.luau
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
sk = sorted(set(int(m) for m in re.findall(r'^##S(\d+) (?:acts HANG|BOOTERR)', s, re.M)))
open(sys.argv[2], 'w').write('return "' + ','.join(map(str, sk)) + '"\n')
print('skipping', len(sk), 'states the web game hangs on:', sk)
