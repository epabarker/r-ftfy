import sys; sys.path.insert(0,'.')
from probe import *
from collections import Counter
C=Counter()
for lang,(g,words) in LANGS.items():
    clean=list(dict.fromkeys(build_values(words)))
    for mix in MIXUPS:
        rows=[(s,)+corrupt(s,mix) for s in clean]
        fl={}; missed=[]
        for s,c,l in rows:
            o,p=fix_encoding_and_explain(c); p=[tuple(x) for x in p]
            if p: fl[c]=(o,p)
            elif c!=s: missed.append((s,c))
        d=dominant(fl)
        if not d: continue
        vocab={ch for c,(o,p) in fl.items() if replay(c,d[2])==o for ch in o if not ch.isascii()}
        for s,c in missed:
            r=replay(c,d[2])
            if r and r!=c:
                miss=[ch for ch in r if not ch.isascii() and ch not in vocab]
                if miss: C[(lang,mix,''.join(sorted(set(miss))))]+=1
for k,v in C.items(): print(v,*k)
