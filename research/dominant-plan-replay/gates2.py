"""Script and character-vocabulary checks for replays on unflagged values.
Run: uv run --python 3.13 --with ftfy==6.3.1 python gates2.py > gates2.txt"""
import sys, unicodedata; sys.path.insert(0,'.')
from probe import *
from collections import Counter
def script(ch):
    if ch.isascii(): return None
    cat=unicodedata.category(ch)
    if cat.startswith('M'): return 'MARK'
    if not cat.startswith('L'): return 'COMMON'
    return unicodedata.name(ch,'?').split()[0]
def reach(s, mix):
    # reachable target: each clean char whose corruption was lossy becomes U+FFFD
    out=[]
    for ch in s:
        c,l=corrupt(ch,mix)
        out.append('�' if l else ch)
    return ''.join(out)
adv=[]
for lang,(g,ws) in LANGS.items():
    for v in dict.fromkeys(build_values(ws)):
        if not v.isascii(): adv += [v, v.upper(), v.title()]
adv += ["PÓŁNOC","STÓŁ","RÓŻA","Úžas","Úšklebek","Её","Ні","Ті"]
adv=[v for v in dict.fromkeys(adv) if not fix_encoding_and_explain(v)[1]]   # unflagged only
T=Counter(); exs=[]
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
        sup=[o for c,(o,p) in fl.items() if replay(c,d[2])==o]
        vocab={ch for o in sup for ch in o if not ch.isascii()}
        scripts={script(ch) for ch in vocab}-{None}
        def gate(inp, r):
            if r is None or r==inp: return None
            st = ftfy.fix_encoding(r)==r
            sc = st and all(script(ch) in scripts for ch in r if not ch.isascii())
            vo = st and all(ch in vocab for ch in r if not ch.isascii())
            return st, sc, vo
        for s,c in missed:
            g_=gate(c, replay(c,d[2]))
            if g_ is None: T['miss: replay fails/no-op']+=1; continue
            r=replay(c,d[2]); ok = r==s or r==reach(s,mix)
            T[('miss', 'reachable' if ok else 'NOT reachable')]+=1
            for name,v in zip(('stable','script','vocab'),g_):
                if v: T[('miss accepted by',name,'reachable' if ok else 'NOT reachable')]+=1
        for v in adv:
            g_=gate(v, replay(v,d[2]))
            if g_ is None: continue
            T[('clean unflagged changed',)]+=1
            for name,x in zip(('stable','script','vocab'),g_):
                if x:
                    T[('clean accepted by',name)]+=1
                    if name!='stable': exs.append((lang,mix,name,v,replay(v,d[2])))
for k,v in sorted(T.items(),key=str): print(v,k)
for e in sorted(set(exs)): print(*e)
