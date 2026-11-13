# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of fix_encoding() from the reference version to
tests/testthat/reference/fix_encoding.tsv.

Columns, tab separated: text and fixed (both escaped, see
_reference.escape) and plan, the plan of fix_encoding_and_explain() in its
text form ("encode latin-1 > decode utf-8", or "none" for no steps). The
inputs are seeded, so a rerun gives the same file byte for byte. A row
whose input or output holds U+0000 or a surrogate, which an R string
cannot hold, is left out.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

import ftfy
from ftfy import chardata

SEED = 30

# Our own short texts, in the scripts the mix-ups below can mangle.
CLEAN = [
    "",
    "plain ASCII text, nothing to see",
    "caf\u00e9",
    "caf\u00e9 cr\u00e8me br\u00fbl\u00e9e \u00e0 la carte",
    "voil\u00e0 le travail",
    "na\u00efve fa\u00e7ade d\u00e9j\u00e0 vu",
    "Stra\u00dfe \u00fcber \u00c4rger \u00d6l",
    "se\u00f1or ni\u00f1o ma\u00f1ana \u00bfqu\u00e9? \u00a1s\u00ed!",
    "\u201ccurly quotes\u201d and \u2018single\u2019 it\u2019s",
    "en \u2013 dash, em \u2014 dash, ellipsis\u2026",
    "\u00a9 2024 \u00ae \u2122 10\u00b0C \u00b12 5\u00d73 \u00bd \u00b2",
    "price: \u20ac10, \u00a35, \u00a5100, 3\u00a2",
    "\u017elu\u0165ou\u010dk\u00fd k\u016f\u0148 \u00fap\u011bl",
    "za\u017c\u00f3\u0142\u0107 g\u0119\u015bl\u0105 ja\u017a\u0144",
    "\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440!",
    "\u039a\u03b1\u03bb\u03b7\u03bc\u03ad\u03c1\u03b1 \u03ba\u03cc\u03c3\u03bc\u03b5",
    "\u05e9\u05dc\u05d5\u05dd \u05e2\u05d5\u05dc\u05dd",
    "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c",
    "\u4f60\u597d\uff0c\u4e16\u754c\uff01",
    "\uc548\ub155\ud558\uc138\uc694 \uc138\uacc4",
    "\ud55c\uad6d\uc5b4 \ud0c0\uc774\ud551",
    "T\u00fcrk\u00e7e \u015fi\u015fe \u011f\u0131",
    "emoji \U0001f600 and \U0001f44d\U0001f3fd astral \U00010348",
    "\u2192 arrows \u2190 and \u2022 bullets \u2605",
    "(\u256f\u00b0\u25a1\u00b0)\u256f\ufe35 \u253b\u2501\u253b",
    "line one\nline two\r\nline three \u00e9",
    "OE ligature: c\u0153ur, \u0152uvre",
    "f\u00fcnf \u00d8re sm\u00f8rrebr\u00f8d \u00e5",
    "\u00c0 la carte, \u00edndice, \u00cdndice",
    "a\u0301 combining e\u0308 marks",
    "\ufeffbyte order mark then \u00e9",
    "question? caf\u00e9? \u201cwhy?\u201d",
]

SLOPPY = [codec for codec in chardata.CHARMAP_ENCODINGS if codec.startswith("sloppy-")]


def one_layer(text, codec):
    return text.encode("utf-8").decode(codec, errors="replace")


def mix_ups():
    out = []
    for text in CLEAN:
        for codec in chardata.CHARMAP_ENCODINGS:
            once = one_layer(text, codec)
            out.append(once)
            # The no-break space turned into a space, as a browser does.
            out.append(once.replace("\xa0", " "))
        # Read by a strict Windows codec, so that each hole became U+FFFD,
        # and the same with "?" where the character was lost.
        for codec in SLOPPY:
            lossy = text.encode("utf-8").decode(codec[len("sloppy-"):], errors="replace")
            out.append(lossy)
            out.append(lossy.replace("\ufffd", "?"))
        for first in chardata.CHARMAP_ENCODINGS[:3]:
            for second in chardata.CHARMAP_ENCODINGS[:3]:
                out.append(one_layer(one_layer(text, first), second))
        # A mix-up inside text that is otherwise fine, and beside text from
        # another mix-up.
        out.append(text + " " + one_layer(text, "sloppy-windows-1252"))
        out.append(one_layer(text, "latin-1") + " " + one_layer(text, "sloppy-windows-1251"))
        # A mix-up beside a character that was already lost: U+FFFD encodes
        # to byte 1A in a sloppy codec, which is valid UTF-8 as it stands.
        out.append(one_layer(text, "latin-1") + " \ufffd")
        out.append("\ufffd" + one_layer(text, "sloppy-windows-1252"))
        # Latin-1 read as it is, where Windows-1252 was meant.
        out.append(text.encode("sloppy-windows-1252", errors="replace").decode("latin-1"))
    return out


def random_strings(rng):
    odd = sorted(
        {
            ch
            for codec in chardata.CHARMAP_ENCODINGS[:4]
            for ch in bytes(range(0x80, 0x100)).decode(codec)
        }
        | {"\ufffd", "\x1a", "\ufeff"}
    )
    filler = list("aeiotnsr AEZ.,?! 019\n")
    out = []
    for _ in range(1500):
        length = rng.randrange(1, 13)
        out.append(
            "".join(
                rng.choice(odd) if rng.random() < 0.6 else rng.choice(filler)
                for _ in range(length)
            )
        )
    return out


def storable(text):
    return "\x00" not in text and not any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def plan_text(plan):
    if not plan:
        return "none"
    return " > ".join("%s %s" % (action, parameter) for action, parameter in plan)


def main():
    rng = random.Random(SEED)
    texts = CLEAN + mix_ups() + random_strings(rng)
    texts = list(dict.fromkeys(texts))
    lines = ["text\tfixed\tplan\n"]
    for text in texts:
        fixed, plan = ftfy.fix_encoding_and_explain(text)
        assert fixed == ftfy.fix_encoding(text)
        if not (storable(text) and storable(fixed)):
            continue
        lines.append("%s\t%s\t%s\n" % (escape(text), escape(fixed), plan_text(plan)))
    write_ascii("tests/testthat/reference/fix_encoding.tsv", "".join(lines))


main()
