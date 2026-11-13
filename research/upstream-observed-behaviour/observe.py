"""Observations of installed ftfy 6.3.1 for r-ftfy issue #18.

Usage: python observe.py <path to upstream tests/test_cases.json>
Prints one JSON document to stdout. All strings are escaped with ascii().
"""
import importlib.metadata as md
import json
import sys
import unicodedata

import ftfy
from ftfy import (
    TextFixerConfig,
    apply_plan,
    chardata,
    fix_and_explain,
    fix_encoding,
    fix_encoding_and_explain,
    fix_text,
    fix_text_segment,
)

out = {}


def a(x):
    return ascii(x)


def attempt(fn):
    try:
        return a(fn())
    except Exception as e:  # noqa: BLE001
        return "RAISES %s: %s" % (type(e).__name__, e)


out["versions"] = {
    "python": sys.version.split()[0],
    "unicodedata": unicodedata.unidata_version,
    "ftfy": ftfy.__version__,
    "wcwidth": md.version("wcwidth"),
}

# ---------------------------------------------------------------- item 1
item1 = []
for label, text in [
    ("decomposed e-acute only", "é"),
    ("mojibake plus decomposed", "schÃ¶n café"),
]:
    fixed, plan = fix_and_explain(text)
    item1.append(
        {
            "label": label,
            "input": a(text),
            "fixed": a(fixed),
            "plan": a([tuple(s) for s in plan]),
            "apply_plan": attempt(lambda: apply_plan(text, plan)),
        }
    )
out["item1_normalize"] = item1

# ---------------------------------------------------------------- item 2
# One input per sub-option, chosen so that the option changes the result.
cases2 = [
    ("restore_byte_a0", "voilÃ  le travail"),
    ("replace_lossy_sequences", "â€œ like this â€�"),
    ("decode_inconsistent_utf8", "— cafÃ© — Р°Р±"),
    ("fix_c1_controls", "caf\u0082 \u0085 \u0091x\u0092"),
]
item2 = []
for opt, text in cases2:
    off = {opt: False}
    row = {"option": opt, "input": a(text)}
    row["fix_text default"] = attempt(lambda: fix_text(text))
    row["fix_text kwarg off"] = attempt(lambda: fix_text(text, **off))
    row["fix_text config off (explain=True default)"] = attempt(
        lambda: fix_text(text, TextFixerConfig(**off))
    )
    row["fix_text config off, explain=False"] = attempt(
        lambda: fix_text(text, TextFixerConfig(explain=False, **off))
    )
    row["fix_text kwarg off + explain=True kwarg"] = attempt(
        lambda: fix_text(text, explain=True, **off)
    )
    row["fix_text_segment kwarg off"] = attempt(lambda: fix_text_segment(text, **off))
    row["fix_and_explain kwarg off (text)"] = attempt(
        lambda: fix_and_explain(text, **off).text
    )
    row["fix_and_explain kwarg off, explain=False (text)"] = attempt(
        lambda: fix_and_explain(text, explain=False, **off).text
    )
    row["fix_encoding default"] = attempt(lambda: fix_encoding(text))
    row["fix_encoding kwarg off"] = attempt(lambda: fix_encoding(text, **off))
    row["fix_encoding_and_explain kwarg off (text)"] = attempt(
        lambda: fix_encoding_and_explain(text, **off).text
    )
    item2.append(row)
out["item2_suboptions"] = item2

# ---------------------------------------------------------------- item 3
cases = json.load(open(sys.argv[1], encoding="utf-8"))
fail_rows = []
normalize_cases = []
all_rows = []
for i, c in enumerate(cases):
    orig = c["original"]
    ft = fix_text(orig)
    fe, fe_plan = fix_encoding_and_explain(orig)
    fa, fa_plan = fix_and_explain(orig)
    row = {
        "index": i,
        "label": c["label"],
        "expect": c["expect"],
        "original": a(orig),
        "json_fixed": a(c["fixed"]),
        "fix_text": a(ft),
        "fix_text == json fixed": ft == c["fixed"],
        "fix_encoding": a(fe),
        "fix_encoding == json fixed-encoding-or-fixed": fe
        == c.get("fixed-encoding", c["fixed"]),
        "fix_encoding_plan": a([tuple(s) for s in fe_plan]),
        "fix_and_explain_text": a(fa),
        "fix_and_explain_plan": a([tuple(s) for s in fa_plan]),
        "fix_and_explain text == fix_text": fa == ft,
    }
    all_rows.append(row)
    if any(s[0] == "normalize" for s in fa_plan):
        normalize_cases.append(i)
    if c["expect"] == "fail":
        fail_rows.append(row)
out["item3_fail_cases"] = fail_rows
out["item3_all_cases"] = all_rows
out["item3_cases_whose_full_plan_has_normalize"] = normalize_cases
out["item3_summary"] = {
    "n": len(cases),
    "pass_marked": sum(c["expect"] == "pass" for c in cases),
    "fail_marked": sum(c["expect"] == "fail" for c in cases),
    "pass_marked where fix_text == fixed": sum(
        r["fix_text == json fixed"] for r in all_rows if r["expect"] == "pass"
    ),
    "fail_marked where fix_text == fixed": sum(
        r["fix_text == json fixed"] for r in all_rows if r["expect"] == "fail"
    ),
    "fail_marked where fix_encoding == fixed": sum(
        r["fix_encoding == json fixed-encoding-or-fixed"]
        for r in all_rows
        if r["expect"] == "fail"
    ),
}

# ---------------------------------------------------------------- item 4a
item4a = []
for b in [
    b"abc\xc0\n",
    b"abc\xc0\x80",
    b"abc\xc0\ndef",
    b"abc\xc0",
    b"abc\xc0x",
    b"\xc0\n",
    b"abc\xc0\n\n",
    b"abc\xc0\r\n",
]:
    item4a.append(
        {
            "bytes": a(b),
            "utf-8-variants": attempt(lambda: b.decode("utf-8-variants")),
            "utf-8": attempt(lambda: b.decode("utf-8")),
        }
    )
out["item4a_c0_0a_codec"] = item4a
# Can it be reached from text? U+00C0 followed by newline, plus mojibake
# elsewhere so the heuristic fires.
item4a_text = []
for t in [
    "À\n",
    "schÃ¶n À\n",
    "schÃ¶n À",
    "schÃ¶n À\nmore",
]:
    item4a_text.append(
        {
            "text": a(t),
            "fix_text": attempt(lambda: fix_text(t)),
            "fix_and_explain": attempt(
                lambda: (
                    fix_and_explain(t).text,
                    [tuple(s) for s in fix_and_explain(t).explanation],
                )
            ),
            "fix_encoding": attempt(lambda: fix_encoding(t)),
        }
    )
out["item4a_c0_0a_from_text"] = item4a_text

# ---------------------------------------------------------------- item 4b
# Line-trace _fix_encoding_one_step_and_explain and record which of lines
# 551-569 execute over every JSON case plus targeted inputs.
func = ftfy._fix_encoding_one_step_and_explain
code = func.__code__
hit = {}


def tracer(frame, event, arg):
    if frame.f_code is code:
        def local(frame, event, arg):
            if event == "line":
                hit[frame.f_lineno] = hit.get(frame.f_lineno, 0) + 1
            return local
        return local
    return None


targeted = [
    "café Ã©té ¬¬",  # Latin-1 ∩ cp1252, no C1
    "Ã© \u0085",  # has a C1 control
    "Â¿Â¡ Ð",
    "".join(chr(i) for i in range(0xA0, 0x100)),
    "".join(chr(i) for i in range(0x80, 0x100)),
]
sys.settrace(tracer)
for c in cases:
    fix_encoding_and_explain(c["original"])
    fix_encoding_and_explain(c["original"].encode("utf-8").decode("latin-1"))
for t in targeted:
    fix_encoding_and_explain(t)
sys.settrace(None)
out["item4b"] = {
    "'windows-1252' in CHARMAP_ENCODINGS": "windows-1252" in chardata.CHARMAP_ENCODINGS,
    "CHARMAP_ENCODINGS": list(chardata.CHARMAP_ENCODINGS),
    "hits line 551 (if latin-1 in possible)": hit.get(551, 0),
    "hits line 552 (if windows-1252 in possible)": hit.get(552, 0),
    "hits line 555 (return 'probably legit')": hit.get(555, 0),
    "hits line 561 (latin-1 -> windows-1252 attempt)": hit.get(561, 0),
    "hits line 567 (return latin-1 -> windows-1252 fix)": hit.get(567, 0),
    "targeted": [
        {
            "input": a(t),
            "fix_encoding_and_explain": attempt(
                lambda: (
                    fix_encoding_and_explain(t).text,
                    [tuple(s) for s in fix_encoding_and_explain(t).explanation],
                )
            ),
        }
        for t in targeted[:3]
    ],
}

json.dump(out, sys.stdout, indent=1, ensure_ascii=True)
