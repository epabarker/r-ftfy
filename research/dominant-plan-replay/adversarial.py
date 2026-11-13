"""Clean text that replays successfully under a single-layer plan: hard negatives.
Run: uv run --python 3.13 --with ftfy==6.3.1 python adversarial.py > adversarial.txt"""
import sys, unicodedata; sys.path.insert(0,'.')
from probe import *
from collections import Counter, defaultdict
CODECS=["latin-1","sloppy-windows-1252","sloppy-windows-1250","sloppy-windows-1251","sloppy-windows-1253","sloppy-windows-1254","iso-8859-2","macroman","cp437"]
def plan_for(cd, lossy=False):
    p=[("encode",cd)]
    if lossy: p.append(("transcode","replace_lossy_sequences"))
    return p+[("decode","utf-8")]
words=[]
for lang,(g,ws) in LANGS.items():
    for v in dict.fromkeys(build_values(ws)):
        if not v.isascii(): words += [(lang,'as-is',v),(lang,'upper',v.upper()),(lang,'title',v.title())]
words += [("given","given",w) for w in ["PÓŁNOC","STÓŁ","RÓŻA","Úžas","Úšklebek","Её","Ні","Ті","ΆΈ","ΌΊ","ΈΆ","ÂÊ","ÃÕ"]]
# every letter pair per codec whose bytes are a valid 2-byte UTF-8 sequence
pairs=[]
for cd in CODECS:
    for b1 in range(0xC2,0xE0):
        for b2 in range(0x80,0xC0):
            try: s=bytes([b1,b2]).decode(cd)
            except Exception: continue
            if all(unicodedata.category(ch).startswith('L') for ch in s):
                pairs.append((cd,s))
print(f"{len(words)} word variants; {len(pairs)} letter pairs that are valid UTF-8 in some codec")
res=Counter(); ex=defaultdict(list)
def judge(tag, v, cd):
    out,p=fix_encoding_and_explain(v)
    flagged=bool(p)
    for lossy in (False,True):
        r=replay(v, plan_for(cd,lossy))
        if r is None or r==v: continue
        stable = ftfy.fix_encoding(r)==r
        k=(tag, 'flagged' if flagged else 'UNFLAGGED', 'stable' if stable else 'unstable')
        res[k]+=1
        if len(ex[k])<25: ex[k].append(f"{cd}{' +lossy' if lossy else ''}: {v!r} -> {r!r} (own: {out!r})")
for lang,kind,v in words:
    for cd in CODECS: judge('word-'+kind, v, cd)
for cd,s in pairs:
    judge('pair', s, cd)
    judge('pair-in-word', s+"ka", cd)
print("\n(tag, per-value flag, replay output stable?) -> count of (value, plan) replays that change clean text")
for k,v in sorted(res.items()): print(v,k)
for k,l in sorted(ex.items()):
    if k[1]=='UNFLAGGED':
        print('\n',k); print('\n'.join('   '+x for x in l))
