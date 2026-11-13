import sys; sys.path.insert(0,'.')
from probe import *
from collections import Counter
agg=Counter()
for lang,(g,words) in LANGS.items():
    clean=list(dict.fromkeys(build_values(words)))
    for mix in MIXUPS:
        rows=[(s,)+corrupt(s,mix) for s in clean]
        fl={}; truth={}
        for s,c,l in rows:
            o,p=fix_encoding_and_explain(c); p=[tuple(x) for x in p]
            if p: fl[c]=(o,p); truth[c]=s
        d=dominant(fl)
        if not d: continue
        for c,(o,p) in fl.items():
            r=replay(c,d[2]); s=truth[c]
            if r is None or r==o: continue
            good = r==s
            key=('good' if good else 'bad', 'bad_r<bad_own' if badness(r)<badness(o) else 'not lower', 'own is_bad' if is_bad(o) else 'own not bad', 'r stable' if ftfy.fix_encoding(r)==r else 'r unstable')
            agg[key]+=1
            if good and agg[key]<=2: print(lang,mix,repr(c),'own',repr(o),ptxt(p),'| dom',d[1],'->',repr(r))
for k,v in agg.items(): print(v,k)
