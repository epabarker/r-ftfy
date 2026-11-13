# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of fix_encoding() from the reference version to
tests/testthat/reference/fix_encoding.tsv.

Columns, tab separated. Texts are escaped (see _reference.escape) and a
plan is in its text form ("encode latin-1 > decode utf-8", or "none" for
no steps).

- text: the input.
- fixed, plan: what fix_encoding_and_explain() gives with default options.
- no_<option>, plan_no_<option>, for each of the four options under
  fix_encoding: the same with that option False. An empty field means
  "the same as with default options".
- decode_inconsistent_utf8, fix_c1_controls: what the fixer of that name
  in ftfy.fixes gives. An empty field means "the input, unchanged".

The inputs are seeded, so a rerun gives the same file byte for byte. A row
whose input holds U+0000 or a surrogate, or whose output holds a
surrogate, is left out, because an R string cannot hold them. An output
that holds U+0000 is kept, escaped: the departure decoded-nul-dropped
says what the package gives in its place.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

import ftfy
from ftfy import chardata, fixes

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

# Texts that reach the two departures of the codec utf-8-variants: bytes
# C0 80 (decoded-nul-dropped), and C0 or five bytes of a six-byte
# surrogate pair before a final newline (utf8-variants-trailing-newline),
# with their neighbours that the reference version does not misread.
VARIANTS = [
    "null\u00c0\u20acseparated",
    "\u00c0\u20ac",
    "caf\u00c3\u00a9 \u00c0\u20ac cr\u00c3\u00a8me \u00c0\u20ac",
    "sch\u00c3\u00b6n \u00c0\u0080",
    "sch\u00c3\u00b6n \u00c0\n",
    "sch\u00c3\u00b6n \u00c0\n\n",
    "sch\u00c3\u00b6n \u00c0\nx",
    "sch\u00c3\u00b6n \u00c0",
    "one \u00c0\ntwo sch\u00c3\u00b6n",
    "\u0421\u0440\u0410\n",
    "\u00c3\u00a9t\u00c3\u00a9 \u00c0\n",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\u008a",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\u0160 caf\u00c3\u00a9",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\n",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\n",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\nx",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8",
    "\u00ed\u00a0\u00bd\n",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n",
]

# Texts on which the options under fix_encoding, and the two exported
# fixers, show: inconsistent mix-ups inside other text, C1 controls, and
# lost characters.
OPTION_TEXTS = [
    "voil\u00c3 le travail",
    "\u00c3 perturber la r\u00c3\u00a9flexion",
    "\u00e2\u20ac\u0153 like this \u00e2\u20ac\ufffd",
    "\u00e2\u20ac\u0153mismatched quotes\u00e2\u20ac\u009d\u2026\u201d",
    "This text was never Unicode at all\u0085",
    "\u0081 alone, and \u0081\u008d\u008f\u0090\u009d the five holes",
    "\u0080\u0099 C1 with a hole \u0081",
    "\u201chere\u2019s a test\u201d \u00e2\u20ac\u201d with \u00c3\u00a9 and \u0085",
    "\u00e3\u0081\u201d\u00e3\u0081\u2013 \u65e5\u672c\u8a9e \u00e2\u20ac\u2122",
    "na\u00efve \u00c3\u00a9 \u00c3\u00a9\u00c3\u00a9 \u2603 \u00e2\u20ac\u2122\u00e2\u20ac\u2122",
    "\u00c3\u00a9",
    "\u2603 \u00c3\u00a9",
    "\ufffd alone",
    "\ufffd\u00c3\u00a9",
]

OPTIONS = [
    "restore_byte_a0",
    "replace_lossy_sequences",
    "decode_inconsistent_utf8",
    "fix_c1_controls",
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


def same_or(value, default):
    """A sparse field: empty when the value is the default."""
    return "" if value == default else value


def has_surrogate(text):
    return any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def main():
    rng = random.Random(SEED)
    texts = CLEAN + mix_ups() + random_strings(rng) + VARIANTS + OPTION_TEXTS
    texts = list(dict.fromkeys(texts))
    header = ["text", "fixed", "plan"]
    header += ["no_" + option for option in OPTIONS]
    header += ["plan_no_" + option for option in OPTIONS]
    header += ["decode_inconsistent_utf8", "fix_c1_controls"]
    lines = ["\t".join(header) + "\n"]
    for text in texts:
        if not storable(text):
            continue
        fixed, plan = ftfy.fix_encoding_and_explain(text)
        assert fixed == ftfy.fix_encoding(text)
        outputs = [fixed]
        fields = [escape(text), escape(fixed), plan_text(plan)]
        off = []
        for option in OPTIONS:
            result = ftfy.fix_encoding_and_explain(text, **{option: False})
            assert result.text == ftfy.fix_encoding(text, **{option: False})
            off.append(result)
            outputs.append(result.text)
        fields += [same_or(escape(result.text), escape(fixed)) for result in off]
        fields += [
            same_or(plan_text(result.explanation), plan_text(plan)) for result in off
        ]
        for fixer in (fixes.decode_inconsistent_utf8, fixes.fix_c1_controls):
            result = fixer(text)
            outputs.append(result)
            fields.append(same_or(escape(result), escape(text)))
        if any(has_surrogate(output) for output in outputs):
            continue
        lines.append("\t".join(fields) + "\n")
    write_ascii("tests/testthat/reference/fix_encoding.tsv", "".join(lines))


main()
