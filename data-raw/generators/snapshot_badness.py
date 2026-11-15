# Derived from python-ftfy v6.3.1, ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of badness() and is_bad() from the reference version
to tests/testthat/reference/badness.tsv.

Columns, tab separated: text (escaped, see _reference.escape), badness,
is_bad (TRUE or FALSE). The inputs are seeded, so a rerun gives the same
file byte for byte. No input holds U+0000 or a surrogate, which an R string
cannot hold.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

from ftfy import badness

SEED = 29

# Our own short texts, in the scripts the mix-ups below can mangle.
CLEAN = [
    "",
    "plain ASCII text, nothing to see",
    "caf\u00e9 cr\u00e8me br\u00fbl\u00e9e \u00e0 la carte",
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
    "\u0421\u044a\u0435\u0448\u044c \u0435\u0449\u0451 \u044d\u0442\u0438\u0445 \u0431\u0443\u043b\u043e\u043a",
    "\u039a\u03b1\u03bb\u03b7\u03bc\u03ad\u03c1\u03b1 \u03ba\u03cc\u03c3\u03bc\u03b5",
    "\u0645\u0631\u062d\u0628\u0627 \u0628\u0627\u0644\u0639\u0627\u0644\u0645",
    "\u05e9\u05dc\u05d5\u05dd \u05e2\u05d5\u05dc\u05dd",
    "\u0928\u092e\u0938\u094d\u0924\u0947 \u0926\u0941\u0928\u093f\u092f\u093e",
    "\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35\u0e0a\u0e32\u0e27\u0e42\u0e25\u0e01",
    "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c",
    "\u4f60\u597d\uff0c\u4e16\u754c\uff01",
    "\uc548\ub155\ud558\uc138\uc694 \uc138\uacc4",
    "T\u00fcrk\u00e7e \u015fi\u015fe \u011f\u0131",
    "Latvie\u0161u valoda \u0101\u0113\u012b\u016b",
    "emoji \U0001f600 and \U0001f44d\U0001f3fd astral \U00010348",
    "\u2192 arrows \u2190 and \u2022 bullets \u2605",
    "\u250c\u2500\u2500\u2510 box \u2502 drawing \u2514\u2500\u2518",
    "(\u256f\u00b0\u25a1\u00b0)\u256f\ufe35 \u253b\u2501\u253b",
    "line one\nline two\r\nline three",
    "OE ligature: c\u0153ur, \u0152uvre, \u0153",
    "f\u00fcnf \u00d8re sm\u00f8rrebr\u00f8d \u00e5",
    "a\u0301 combining e\u0308 marks",
]

MISREAD_AS = [
    "latin-1",
    "sloppy-windows-1252",
    "sloppy-windows-1251",
    "sloppy-windows-1250",
    "sloppy-windows-1253",
    "sloppy-windows-1254",
    "sloppy-windows-1257",
    "iso-8859-2",
    "macroman",
    "cp437",
]

# Characters where Python and ICU disagree about \s or \w, or which ICU
# treats as line ends unless told otherwise, each placed where the pattern
# asks for \s, \w, "." or "^".
PROBE_CHARS = (
    [chr(cp) for cp in range(0x09, 0x0E)]
    + [chr(cp) for cp in range(0x1C, 0x21)]
    + list("\x85\xa0\u1680\u180e\u2000\u200a\u200b\u2028\u2029\u202f\u205f\u3000\ufeff")
    + list("aZ5_\xb2\xb3\xb9\xbc\xbd\xbe\xaa\xba\xb5")
    + list("\u0301\u0308\u20dd\u0903\u0660\u0967\u2460\u2167\u3007\u4e00")
    + list("\u203f\u2040\u200c\u200d\U0001d7ce\U0001f600\U00010348-.")
)


def probes():
    out = []
    for ch in PROBE_CHARS:
        # [lower_accented][end_punctuation] \w
        out.append("\u00e9\u00bb" + ch)
        out.append("x\u00e9\u201d" + ch + "y")
        # [a-z] \s? [\u00c3\u00c2] [ ]
        out.append("a" + ch + "\u00c3 ")
        out.append("a" + ch + "\u00c2 b")
        # ^ [\u00c3\u00c2] [ ]: only the true start counts
        out.append(ch + "\u00c3 ")
        out.append("\u00c2 " + ch)
        # the five Cyrillic letters, then ".", then a Latin letter or space
        out.append("\u0413\u045e\u0412\u0402\u0412" + ch + "a")
        # [\u0152\u0153][^A-Za-z]
        out.append("\u0153" + ch)
    out += [
        "\u00c3 ",
        "\n\u00c3 ",
        "x\n\u00c3 ",
        "\u00c2 \n\u00c2 ",
        "\ufeff\u00c3\u00a9",
        "\ufeff",
        "\ufeffplain",
        "\u00c3\u00a9\u00c3\u00a9\u00c3\u00a9",
        "\u00e2\u20ac\u2122 \u00e2\u20ac\u0153 \u00e2\u20ac\u009d",
        "\u00c3\u00a9\n\u00c3\u00a9\n",
        "\U0001f600\u00c3\u00a9\U0001f600",
        "\x80\x81\x9f",
        "\ufffd\ufffd",
        "tab\there, backslash \\ and \\u0041 literal",
        " leading and trailing space ",
    ]
    return out


def mix_ups():
    out = []
    for text in CLEAN:
        raw = text.encode("utf-8")
        for codec in MISREAD_AS:
            once = raw.decode(codec, errors="replace")
            out.append(once)
        for first in MISREAD_AS[:3]:
            for second in MISREAD_AS[:3]:
                twice = (
                    raw.decode(first, errors="replace")
                    .encode("utf-8")
                    .decode(second, errors="replace")
                )
                out.append(twice)
    return out


def pattern_alphabet():
    """Every character the upstream pattern text names, plus ASCII filler."""
    chars = set(badness.BADNESS_RE.pattern)
    for value in badness.MOJIBAKE_CATEGORIES.values():
        chars.update(value)
    chars.update(chr(cp) for cp in range(0x80, 0xA0))
    chars -= set("\x00")
    return sorted(ch for ch in chars if ord(ch) > 0x7F)


def random_strings(rng):
    odd = pattern_alphabet()
    filler = list("aeiotnsr AEZ.,?! 019\n")
    out = []
    for _ in range(1400):
        length = rng.randrange(1, 13)
        out.append(
            "".join(
                rng.choice(odd) if rng.random() < 0.6 else rng.choice(filler)
                for _ in range(length)
            )
        )
    blocks = [
        (0x01, 0x7F),
        (0x80, 0x24F),
        (0x250, 0x52F),
        (0x2000, 0x2BFF),
        (0x3000, 0x30FF),
        (0xFB00, 0xFFFD),
        (0x10000, 0x1F9FF),
    ]
    for _ in range(400):
        length = rng.randrange(1, 9)
        chars = []
        for _ in range(length):
            low, high = rng.choice(blocks)
            cp = rng.randrange(low, high + 1)
            chars.append(rng.choice(odd) if 0xD800 <= cp <= 0xDFFF else chr(cp))
        out.append("".join(chars))
    return out


def main():
    rng = random.Random(SEED)
    texts = CLEAN + probes() + mix_ups() + random_strings(rng)
    texts = list(dict.fromkeys(texts))
    assert all("\x00" not in text for text in texts)
    lines = ["text\tbadness\tis_bad\n"]
    for text in texts:
        lines.append(
            "%s\t%d\t%s\n"
            % (
                escape(text),
                badness.badness(text),
                "TRUE" if badness.is_bad(text) else "FALSE",
            )
        )
    write_ascii("tests/testthat/reference/badness.tsv", "".join(lines))


main()
