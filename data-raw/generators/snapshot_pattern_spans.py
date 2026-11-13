# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the span fixture: where each of the ten generated patterns matches
in the reference version, to tests/testthat/reference/pattern_spans.tsv.

Columns, tab separated: kind, text (escaped, see _reference.escape), then
one column per pattern, named as upstream names it.

kind is "text" or "bytes". A "bytes" row is a byte string, written as text
with byte b as the character U+00b. The seven text patterns are run on every
row; the three bytes patterns only on "bytes" rows, as Python's bytes
patterns on the bytes themselves, and their columns are empty on "text"
rows.

A pattern's column holds the spans of re.finditer(), in order, as
start-end separated by spaces, counted in code points from 0 with the end
excluded, as Python counts. It is empty when there is no match.

The strings are seeded, so a rerun gives the same file byte for byte. None
holds U+0000 or a surrogate, which an R string cannot hold.
"""

import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import REPO, escape, require_reference, write_ascii

require_reference()

from ftfy import badness, chardata, fixes

SEED = 34

TEXT_PATTERNS = [
    ("BADNESS_RE", badness.BADNESS_RE),
    ("UTF8_DETECTOR_RE", chardata.UTF8_DETECTOR_RE),
    ("ANSI_RE", fixes.ANSI_RE),
    ("HTML_ENTITY_RE", chardata.HTML_ENTITY_RE),
    ("SINGLE_QUOTE_RE", chardata.SINGLE_QUOTE_RE),
    ("DOUBLE_QUOTE_RE", chardata.DOUBLE_QUOTE_RE),
    ("C1_CONTROL_RE", chardata.C1_CONTROL_RE),
]
BYTES_PATTERNS = [
    ("ALTERED_UTF8_RE", chardata.ALTERED_UTF8_RE),
    ("LOSSY_UTF8_RE", chardata.LOSSY_UTF8_RE),
    ("A_GRAVE_WORD_RE", fixes.A_GRAVE_WORD_RE),
]

# Every string with a match, and every string with two or more, that each
# pattern must have in the fixture: a pattern that never matched would be
# compared with nothing.
MIN_MATCHED = 300
MIN_REPEATED = 40

# The seven characters ICU treats as line ends unless UNIX_LINES is on.
LINE_ENDS = list("\n\r\x0b\x0c\x85\u2028\u2029")

# Characters on which Python and ICU disagree about \s, \w or \d, or which
# some string functions mishandle: controls, spaces, U+FEFF, combining
# marks, superscripts and fractions, digits of several scripts including
# two sets first assigned in Unicode 15.0 (Kawi and Nag Mundari), other
# numbers that are not \d, and characters outside the BMP.
AWKWARD = (
    LINE_ENDS
    + [chr(cp) for cp in (0x01, 0x08, 0x09, 0x1A, 0x1B, 0x1C, 0x1F, 0x7F)]
    + list("\xa0\xad\u1680\u180e\u2000\u200a\u200b\u200c\u200d\u202f\u205f\u3000\ufeff")
    + list("\u0301\u0308\u20dd\u0903")
    + list("\xb2\xb3\xb9\xbc\xbd\xbe\xaa\xba\xb5\u2460\u2167\u3007\u4e00")
    + list("\u0660\u0669\u06f0\u0967\u0e50\uff10\uff19\U0001d7ce\U0001d7ff")
    + list("\U00011f50\U00011f59\U0001e4f0\U0001e4f9")
    + list("\U0001f600\U00010348\U0001fbf0\ufffd\ufffc")
)

ASCII = [chr(cp) for cp in range(0x20, 0x7F)]

# Our own short texts, in scripts the mix-ups below can mangle.
CLEAN = [
    "caf\u00e9 cr\u00e8me br\u00fbl\u00e9e \u00e0 la carte",
    "voil\u00e0 \u00e0 quelques pas, \u00e0 quilo, \u00e0s vezes, \u00e0 noite",
    "Stra\u00dfe \u00fcber \u00c4rger \u00d6l",
    "se\u00f1or ni\u00f1o ma\u00f1ana \u00bfqu\u00e9? \u00a1s\u00ed!",
    "\u201ccurly quotes\u201d and \u2018single\u2019 it\u2019s \u201a\u201e\u201b\u201f\u02bc",
    "en \u2013 dash, em \u2014 dash, ellipsis\u2026",
    "\u00a9 2024 \u00ae \u2122 10\u00b0C \u00b12 5\u00d73 \u00bd \u00b2",
    "price: \u20ac10, \u00a35, \u00a5100, 3\u00a2 &amp; &lt;b&gt; &#233; &#x41;",
    "\u017elu\u0165ou\u010dk\u00fd k\u016f\u0148 \u00fap\u011bl",
    "za\u017c\u00f3\u0142\u0107 g\u0119\u015bl\u0105 ja\u017a\u0144",
    "\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440! \u0421\u044a\u0435\u0448\u044c \u0435\u0449\u0451",
    "\u039a\u03b1\u03bb\u03b7\u03bc\u03ad\u03c1\u03b1 \u03ba\u03cc\u03c3\u03bc\u03b5",
    "\u0645\u0631\u062d\u0628\u0627 \u0628\u0627\u0644\u0639\u0627\u0644\u0645",
    "\u05e9\u05dc\u05d5\u05dd \u05e2\u05d5\u05dc\u05dd",
    "\u0928\u092e\u0938\u094d\u0924\u0947 \u0926\u0941\u0928\u093f\u092f\u093e",
    "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c \u4f60\u597d\uff0c\u4e16\u754c\uff01",
    "\uc548\ub155\ud558\uc138\uc694 \uc138\uacc4",
    "T\u00fcrk\u00e7e \u015fi\u015fe \u011f\u0131 Latvie\u0161u \u0101\u0113\u012b\u016b",
    "emoji \U0001f600 and \U0001f44d\U0001f3fd astral \U00010348",
    "\u2192 arrows \u2190 \u2022 bullets \u2605 \u250c\u2500\u2510 \u2502",
    "\x1b[1;31mred\x1b[0m and \x1b[m plain \x1b[38;5;196mmore",
    "line one\nline two\r\nline three\u2028four",
    "\ufeffstarts with a byte order mark: c\u0153ur \u0152uvre",
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


def pattern_alphabet(compiled):
    """Every non-ASCII character a pattern's source text names, with the
    characters one below and one above each, so that both sides of every
    class boundary are drawn."""
    named = {ord(ch) for ch in compiled.pattern if ord(ch) > 0x7F}
    codes = set()
    for cp in named:
        codes.update((cp - 1, cp, cp + 1))
    return sorted(
        chr(cp) for cp in codes if cp > 0x7F and not 0xD800 <= cp <= 0xDFFF
    )


def pick(rng, weighted):
    """Draw from [(weight, list of choices), ...]."""
    roll = rng.random() * sum(weight for weight, _ in weighted)
    for weight, choices in weighted:
        roll -= weight
        if roll < 0:
            return rng.choice(choices)
    return rng.choice(weighted[-1][1])


def draw(rng, count, low, high, weighted):
    return [
        "".join(pick(rng, weighted) for _ in range(rng.randrange(low, high + 1)))
        for _ in range(count)
    ]


def mix_ups():
    out = []
    for text in CLEAN:
        raw = text.encode("utf-8")
        for codec in MISREAD_AS:
            out.append(raw.decode(codec, errors="replace"))
        for first in MISREAD_AS[:3]:
            for second in MISREAD_AS[:3]:
                out.append(
                    raw.decode(first, errors="replace")
                    .encode("utf-8")
                    .decode(second, errors="replace")
                )
    return [text.replace("\x00", "") for text in out]


def json_strings():
    path = os.path.join(REPO, "tests", "testthat", "upstream", "test_cases.json")
    with open(path, encoding="utf-8") as handle:
        cases = json.load(handle)
    out = []
    for case in cases:
        for key in ("original", "fixed-encoding", "fixed"):
            if isinstance(case.get(key), str):
                out.append(case[key])
    return out


def text_strings(rng):
    bad = pattern_alphabet(badness.BADNESS_RE)
    for value in badness.MOJIBAKE_CATEGORIES.values():
        bad = sorted(set(bad) | {ch for ch in value if ord(ch) > 0x7F})
    detector = pattern_alphabet(chardata.UTF8_DETECTOR_RE)
    c1 = [chr(cp) for cp in range(0x7F, 0xA2)]
    digits = [ch for ch in AWKWARD if ch.isdigit() or ch.isnumeric()]
    out = list(CLEAN) + mix_ups() + json_strings()

    # As the research corpus was drawn: mostly the characters the mojibake
    # classes name, some ASCII, some awkward characters.
    out += draw(rng, 4500, 1, 10, [(6, bad), (3, ASCII), (1, AWKWARD)])
    out += draw(rng, 800, 1, 8, [(5, bad), (3, list("aZ \n.?")), (2, AWKWARD)])

    # UTF8_DETECTOR_RE: runs of the characters it names and their
    # neighbours, with the space its classes hold and few interruptions.
    out += draw(
        rng, 3000, 2, 10,
        [(12, detector), (1, [" "]), (1, list("a.\n")), (1, AWKWARD)],
    )

    # ANSI_RE: an escape, a bracket, digits of every kind and semicolons,
    # then a letter or a character just outside the letter ranges.
    start = [(8, ["\x1b["]), (1, ["\x1b", "[", "\x1b\x1b[", "\x9b", "\x1b[["])]
    body = [(6, list("0123456789")), (3, [";"]), (2, digits), (1, AWKWARD)]
    final = [(6, list("mHJKAZaz")), (2, list("@[`{")), (1, AWKWARD), (1, [""])]
    for _ in range(1300):
        text = pick(rng, start)
        text += "".join(pick(rng, body) for _ in range(rng.randrange(0, 7)))
        text += pick(rng, final)
        if rng.random() < 0.4:
            text = rng.choice(["x", "\n", "\ufeff", " "]) + text
        if rng.random() < 0.4:
            text += pick(rng, start) + pick(rng, body) + pick(rng, final)
        out.append(text)

    # HTML_ENTITY_RE: an ampersand, perhaps a hash, 0 to 26 letters and
    # digits or their neighbours, then a semicolon or not.
    name = [
        (12, list("0123456789ABCXYZabcxyz")),
        (1, list("/:@[`{_-")),
        (1, digits + list("\u00e9\u00c5\u0391")),
    ]
    lengths = [0, 1, 1, 2, 2, 3, 3, 4, 5, 6, 8, 12, 23, 24, 25, 26]
    for _ in range(1300):
        text = rng.choice(["&", "&", "&", "&#", "&#", "&#x", "&&", "&##", "&amp;&"])
        text += "".join(pick(rng, name) for _ in range(rng.choice(lengths)))
        text += rng.choice([";", ";", ";", ";", "", ":", ";;", "\n;"])
        if rng.random() < 0.3:
            text = rng.choice(["a", "\ufeff", ";", "\n"]) + text
        if rng.random() < 0.3:
            text += rng.choice(["&lt;", "&#38;", "& ;", "&x"])
        out.append(text)

    # The quote patterns and C1_CONTROL_RE: both sides of every boundary.
    quotes = [chr(cp) for cp in (0x2BB, 0x2BC, 0x2BD)] + [
        chr(cp) for cp in range(0x2016, 0x2022)
    ]
    out += draw(rng, 700, 1, 6, [(5, quotes), (2, list("a' \"\n")), (1, AWKWARD)])
    out += draw(rng, 700, 1, 6, [(5, c1), (2, list("a \n")), (1, AWKWARD)])

    # Each awkward character alone and beside mojibake.
    for ch in AWKWARD:
        out += [ch, ch + "\u00c3\u00a9", "\u00c3\u00a9" + ch, "\u00c3" + ch + "\u00a9"]
        out += ["\x1b[" + ch + "m", "&" + ch + ";", "&#1" + ch + ";", ch + "\u201c"]
    return out


def bytes_strings(rng):
    lead2 = [bytes([b]) for b in range(0xC1, 0xE0)]
    lead3 = [bytes([b]) for b in range(0xE0, 0xF0)]
    lead4 = [bytes([b]) for b in range(0xEF, 0xF6)]
    tail = [bytes([b]) for b in range(0x80, 0xC0)]
    edges = [bytes([b]) for b in (0x7F, 0x80, 0x84, 0x85, 0x86, 0x9F, 0xA0, 0xA1, 0xBF, 0xC0)]
    ascii_bytes = [bytes([b]) for b in range(0x20, 0x7F)]
    other = [bytes([b]) for b in list(range(0x01, 0x20)) + list(range(0xF5, 0x100))]
    out = []

    # Our own texts as UTF-8, then with byte A0 turned into a space, and
    # with bytes replaced by the two characters a lossy codec leaves.
    for text in CLEAN:
        raw = text.encode("utf-8")
        out.append(raw)
        out.append(raw.replace(b"\xa0", b" "))
        for _ in range(12):
            damaged = bytearray(raw)
            for _ in range(rng.randrange(1, 4)):
                damaged[rng.randrange(len(damaged))] = rng.choice(b"\x1a? \x1a?")
            out.append(bytes(damaged))

    # ALTERED_UTF8_RE: lead bytes, continuation bytes and spaces.
    altered = [(3, lead2), (4, lead3), (3, lead4), (6, tail), (2, edges), (5, [b" "]), (1, ascii_bytes), (1, other)]
    out += [b"".join(p) for p in _draw_bytes(rng, 2400, 1, 8, altered)]

    # LOSSY_UTF8_RE: the same with the two replacement bytes, and the
    # surrogate lead ED, which two of its alternatives start with.
    lossy = [(3, lead2), (4, lead3), (3, lead4), (2, [b"\xed"]), (6, tail), (2, edges), (3, [b"\x1a"]), (3, [b"?"]), (1, ascii_bytes), (1, other)]
    out += [b"".join(p) for p in _draw_bytes(rng, 2400, 1, 9, lossy)]

    # A_GRAVE_WORD_RE: C3 and a space, then the words its lookahead
    # names, cut short, lengthened or changed.
    words = [b" ", b"quele", b"quela", b"quilo", b"s ", b"s", b"quel", b"quelx", b"quil", b"q", b"Quele", b"noite", b"", b"\xa0", b"s\n", b"\nquele", b"squele", b"s  ", b"\xc3 "]
    heads = [b"\xc3 ", b"\xc3 ", b"\xc3 ", b"\xc3\xa0 ", b"\xc3", b"\xc2 ", b"\xc3  ", b"a \xc3 "]
    for _ in range(1400):
        text = rng.choice(heads) + rng.choice(words)
        for _ in range(rng.randrange(0, 3)):
            text += rng.choice([b" ", b"a", b"\n"]) + rng.choice(heads) + rng.choice(words)
        out.append(text)

    # Every byte alone, and after a lead byte.
    for b in range(1, 256):
        out += [bytes([b]), b"\xc3" + bytes([b]), b"\xe2" + bytes([b]) + b" ", b"\xf0 \x9f" + bytes([b])]
    return [raw.replace(b"\x00", b"") for raw in out]


def _draw_bytes(rng, count, low, high, weighted):
    return [
        [pick(rng, weighted) for _ in range(rng.randrange(low, high + 1))]
        for _ in range(count)
    ]


def spans(compiled, subject):
    return " ".join("%d-%d" % match.span() for match in compiled.finditer(subject))


def main():
    rng = random.Random(SEED)
    texts = list(dict.fromkeys(text_strings(rng)))
    raws = list(dict.fromkeys(bytes_strings(rng)))
    rows = [("text", text, None) for text in texts if text]
    seen = set(texts)
    for raw in raws:
        text = raw.decode("latin-1")
        if raw and text not in seen:
            rows.append(("bytes", text, raw))
    for _, text, _ in rows:
        assert "\x00" not in text
        assert not any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)

    names = [name for name, _ in TEXT_PATTERNS + BYTES_PATTERNS]
    matched = dict.fromkeys(names, 0)
    repeated = dict.fromkeys(names, 0)
    lines = ["\t".join(["kind", "text"] + names) + "\n"]
    for kind, text, raw in rows:
        fields = [kind, escape(text)]
        found = [(name, spans(compiled, text)) for name, compiled in TEXT_PATTERNS]
        for name, compiled in BYTES_PATTERNS:
            found.append((name, "" if raw is None else spans(compiled, raw)))
        for name, value in found:
            matched[name] += value != ""
            repeated[name] += " " in value
            fields.append(value)
        lines.append("\t".join(fields) + "\n")
    for name in names:
        assert matched[name] >= MIN_MATCHED, (name, matched[name])
        assert repeated[name] >= MIN_REPEATED, (name, repeated[name])
    write_ascii("tests/testthat/reference/pattern_spans.tsv", "".join(lines))


main()
