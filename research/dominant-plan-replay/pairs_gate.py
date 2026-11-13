"""The agreed acceptance checks (3 and 4) on unflagged two-letter strings, per corpus column.
Run: uv run --python 3.13 --with ftfy==6.3.1 python pairs_gate.py > pairs_gate.txt"""
import sys, unicodedata; sys.path.insert(0,'.')
from probe import *
from collections import Counter
CODECS=["latin-1","sloppy-windows-1252","sloppy-windows-1250","sloppy-windows-1251","sloppy-windows-1253","sloppy-windows-1254","iso-8859-2","macroman","cp437"]
pairs=set()
for cd in CODECS:
    for b1 in range(0xC2,0xE0):
        for b2 in range(0x80,0xC0):
            try: s=bytes([b1,b2]).decode(cd)
            except Exception: continue
            if all(unicodedata.category(ch).startswith('L') for ch in s): pairs.add(s)
cands=[]
for s in sorted(pairs):
    for v in (s, s+"ka", "Na "+s):
        if not fix_encoding_and_explain(v)[1]: cands.append(v)
print(len(cands),"unflagged candidates")
T=Counter(); acc=[]
for lang,(g,words) in LANGS.items():
    clean=list(dict.fromkeys(build_values(words)))
    for mix in MIXUPS:
        rows=[(s,)+corrupt(s,mix) for s in clean]
        fl={}
        for s,c,l in rows:
            o,p=fix_encoding_and_explain(c); p=[tuple(x) for x in p]
            if p: fl[c]=(o,p)
        d=dominant(fl)
        if not d: continue
        vocab={ch for c,(o,p) in fl.items() if replay(c,d[2])==o for ch in o if not ch.isascii()}
        for v in cands:
            r=replay(v,d[2])
            if r is None or r==v: continue
            T['changed']+=1
            if ftfy.fix_encoding(r)==r and all(ch in vocab for ch in r if not ch.isascii()):
                T['ACCEPTED']+=1; acc.append((lang,mix,v,r))
print(dict(T))
for a in acc: print(*a)
