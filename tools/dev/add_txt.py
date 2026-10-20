# Add text entries to scripts/txt.gd before a given key, skipping keys that already exist
# (a duplicate key would stop every script from loading).
# usage: python add_txt.py <anchor key> <entries file: lines of  key|zh|en>
import sys, re
fn = 'E:/godot/zeropower/scripts/txt.gd'
s = open(fn, encoding='utf-8').read()
anchor_key, entries = sys.argv[1], sys.argv[2]
m = re.search(r'^\t"%s":.*\n' % re.escape(anchor_key), s, re.M)
assert m, anchor_key
add = ''
for line in open(entries, encoding='utf-8'):
    line = line.rstrip('\n')
    if not line.strip():
        continue
    k, zh, en = line.split('|')
    if re.search(r'^\t"%s":' % re.escape(k), s, re.M):
        print('have', k)
        continue
    add += '\t"%s": ["%s", "%s"],\n' % (k, zh, en)
s = s[:m.start()] + add + s[m.start():]
open(fn, 'w', encoding='utf-8', newline='\n').write(s)
print('added', add.count('\n'))
