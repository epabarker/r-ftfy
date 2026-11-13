"""Emit Python ftfy's actual output for every upstream JSON case as raw-string JSON.

Usage: python fixtures.py <tests/test_cases.json>   (stdout: UTF-8 JSON array)
"""
import json, sys
from ftfy import fix_text, fix_and_explain, fix_encoding_and_explain
rows = []
for i, c in enumerate(json.load(open(sys.argv[1], encoding="utf-8"))):
    o = c["original"]
    fa, fa_plan = fix_and_explain(o)
    fe, fe_plan = fix_encoding_and_explain(o)
    rows.append({"index": i, "label": c["label"], "expect": c["expect"], "original": o,
                 "fix_text": fix_text(o), "fix_and_explain_text": fa,
                 "fix_and_explain_plan": [list(s) for s in fa_plan],
                 "fix_encoding": fe, "fix_encoding_plan": [list(s) for s in fe_plan]})
sys.stdout.reconfigure(encoding="utf-8")
json.dump(rows, sys.stdout, ensure_ascii=False, indent=1)
