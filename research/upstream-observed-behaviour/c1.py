import json, sys
from ftfy import *
from ftfy import TextFixerConfig
rows=[]
for t in ["caf\u0081 \u0085 \u0091x\u0092", "\u0081\u0085", "naïve \u0081 \u0093quote\u0094"]:
    off={"fix_c1_controls":False}
    r={"input":ascii(t)}
    for name,fn in [
     ("fix_text default", lambda: fix_text(t)),
     ("fix_text kwarg off", lambda: fix_text(t, **off)),
     ("fix_text config off (explain=True default)", lambda: fix_text(t, TextFixerConfig(**off))),
     ("fix_text config off, explain=False", lambda: fix_text(t, TextFixerConfig(explain=False, **off))),
     ("fix_and_explain kwarg off", lambda: tuple(fix_and_explain(t, **off))),
     ("fix_and_explain default", lambda: tuple(fix_and_explain(t))),
     ("fix_and_explain kwarg off, fix_encoding=False", lambda: tuple(fix_and_explain(t, fix_encoding=False, **off))),
     ("fix_and_explain fix_encoding=False only", lambda: tuple(fix_and_explain(t, fix_encoding=False))),
     ("fix_encoding default", lambda: fix_encoding(t)),
     ("fix_encoding kwarg off", lambda: fix_encoding(t, **off)),
     ("fix_encoding_and_explain default", lambda: tuple(fix_encoding_and_explain(t))),
    ]:
        try: r[name]=ascii(fn())
        except Exception as e: r[name]="RAISES %s: %s"%(type(e).__name__,e)
    rows.append(r)
json.dump(rows, sys.stdout, indent=1)
