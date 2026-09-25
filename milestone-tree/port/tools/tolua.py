# Wraps a text file as a Luau module returning it as a string: python3 tools/tolua.py in.txt out.luau
import sys
s = open(sys.argv[1], encoding='utf-8').read()
s = s.strip()
level = 1
while (']' + '=' * level + ']') in s + ']': level += 1
eq = '=' * level
open(sys.argv[2], 'w', encoding='utf-8').write('return [' + eq + '[' + s + ']' + eq + ']\n')
