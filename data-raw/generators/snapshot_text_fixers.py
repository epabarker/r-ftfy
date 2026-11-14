# Derived from python-ftfy v6.3.1, ftfy/fixes.py and ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
# Runs after: table_html_numeric.py
"""Write the snapshot of seven text fixers from the reference version to
tests/testthat/reference/text_fixers.tsv: unescape_html,
remove_terminal_escapes, uncurl_quotes, fix_latin_ligatures,
fix_character_width, fix_line_breaks and remove_control_chars.

Columns, tab separated: fixer (the name of the function in ftfy.fixes),
text and fixed (both escaped, see _reference.escape). Every fixer runs on
a shared set of inputs and on a set of its own, built from its table or
pattern. The inputs are seeded, so a rerun gives the same file byte for
byte. A row whose input or output holds U+0000 or a surrogate, which an R
string cannot hold, is left out.

The inputs for numeric HTML references are taken from the edges of the
ranges in data-raw/tables/html_numeric.txt, which table_html_numeric.py
writes. regenerate.py runs this script before that one, so after a change
to that table it must be run twice.

Every character is written here by its number, never as a literal or an
escape, so that the file stays ASCII whatever tool edits it.
"""

import itertools
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, storable, write_ascii

require_reference()

from ftfy import chardata, fixes

SEED = 38

FIXERS = [
    "unescape_html",
    "remove_terminal_escapes",
    "uncurl_quotes",
    "fix_latin_ligatures",
    "fix_character_width",
    "fix_line_breaks",
    "remove_control_chars",
]


def U(*numbers):
    return "".join(chr(number) for number in numbers)


BOM = U(0xFEFF)
ESC = U(0x1B)
CR = U(0x0D)
LF = U(0x0A)

# Text with something for every fixer, alone and together, and with a
# leading U+FEFF, which only remove_control_chars may take away.
SHARED = [
    "",
    "plain ASCII text, nothing to fix",
    "caf" + U(0xE9) + " cr" + U(0xE8) + "me",
    BOM,
    BOM + BOM + "twice",
    BOM + "&amp; after a byte order mark",
    BOM + ESC + "[1mbold" + ESC + "[0m after a byte order mark",
    BOM + U(0x201C) + "quoted" + U(0x201D) + " after a byte order mark",
    BOM + U(0xFB01) + "ne after a byte order mark",
    BOM + U(0xFF21, 0xFF22, 0xFF23) + " after a byte order mark",
    BOM + CR + LF + "after a byte order mark",
    BOM + U(0x7F) + "after a byte order mark",
    "in the middle " + BOM + " of the text",
    "at the end" + BOM,
    U(0x201C) + "here" + U(0x2019) + "s a test" + U(0x201D),
    U(0xFB02) + "u" + U(0xFB03) + "e" + U(0xFB06),
    U(0xFF2C, 0xFF2F, 0xFF35, 0xFF24, 0x3000, 0xFF2E, 0xFF2F, 0xFF29, 0xFF33, 0xFF25, 0xFF33),
    U(0xFF35, 0xFF80, 0xFF70, 0xFF9D),
    "This string is made of two things:" + U(0x2029) + "1. Unicode" + U(0x2028) + "2. Spite",
    "Content-type: text/plain" + CR + LF + CR + LF + "Hi.",
    "This is how Microsoft " + CR + " trolls Mac users",
    "What is this " + U(0x85) + " I don't even",
    ESC + "[36;44mI'm blue, da ba dee da ba doo..." + ESC + "[0m",
    U(0x01) + ESC + "[36;44mfoo",
    BOM + "Sometimes, " + U(0xFFFC) + "bad ideas " + U(0x7F, 0xFFFA) + "like these characters"
    + U(0xFFFB) + " " + U(0x206A) + "get standardized." + CR + LF,
    "This flag has a dragon on it " + U(0x1F3F4, 0xE0067, 0xE0062, 0xE0077, 0xE006C, 0xE0073, 0xE007F),
    "&lt;tag&gt;",
    "P&eacute;rez and P&EACUTE;REZ",
    "&amp;amp;amp;",
    "&#8220;curly&#8221; &amp; &#x201c;curly&#x201D;",
    "&#13;&#10; &#x85; &#133; &#27;[0m &#xfb01; &#xFF21;",
    "this&not that; this &not; that",
    "tab\tand form feed" + U(0x0C) + "stay",
    U(0x200D) + "joiners" + U(0x200C) + " and " + U(0x200E) + "marks" + U(0x202E) + " stay",
    "emoji " + U(0x1F600) + " and astral " + U(0x10348) + " and " + U(0x1D4A5),
    "a" + U(0x301) + " combining, " + U(0xE6) + " and " + U(0x153) + " stay, " + U(0x132) + " goes",
    U(0xFFE3) + " becomes two characters, " + U(0xFFE0, 0xFFE1, 0xFFE5, 0xFFE6),
    "half " + U(0xFF61, 0xFF62, 0xFF63) + " and Hangul " + U(0xFFA1, 0xFFC2, 0xFFDC),
    U(0x2018) + "single" + U(0x2019) + " " + U(0x201A) + "low" + U(0x201B) + " "
    + U(0x201E) + "low double" + U(0x201F) + " " + U(0x2BC) + " " + U(0x2032, 0x2033, 0xAB, 0xBB),
    "?" * 3 + " $1 \\1 \\ $ percent % and regex [a-z]+ (text) {2}",
]


def shared_fuzz(rng):
    special = (
        [BOM, ESC, CR, LF, "&", ";", "#", "[", "m", "x", "<", " ", "\t"]
        + [U(n) for n in (0x01, 0x08, 0x0B, 0x1F, 0x7F, 0x80, 0x85, 0x9F, 0xA0)]
        + [U(n) for n in (0x2BC, 0x2018, 0x2019, 0x201C, 0x201D, 0x201F, 0x2028, 0x2029)]
        + [U(n) for n in (0x206A, 0x206F, 0x2070, 0xFFF9, 0xFFFC, 0xFFFD, 0x3000)]
        + [U(n) for n in (0x132, 0x149, 0x1C4, 0xFB00, 0xFB06, 0xFB07)]
        + [U(n) for n in (0xFF01, 0xFF5E, 0xFF61, 0xFF9F, 0xFFE3, 0xFFEE, 0xFFEF)]
        + [U(0x1F600), U(0xE007F), "amp", "lt", "39", "eacute", "0", "1;2"]
    )
    filler = list("aeiotn AEZ.,?!019")
    out = []
    for _ in range(90):
        length = rng.randrange(1, 16)
        out.append(
            "".join(
                rng.choice(special) if rng.random() < 0.55 else rng.choice(filler)
                for _ in range(length)
            )
        )
    return out


def html_inputs(rng):
    out = []
    names = sorted(chardata.HTML_ENTITIES)
    # Every entity of the table, several to a string, so that strings
    # differ in how many matches they hold.
    shuffled = names[:]
    rng.shuffle(shuffled)
    at = 0
    while at < len(shuffled):
        size = rng.randrange(1, 13)
        chunk = shuffled[at : at + size]
        at += size
        out.append(rng.choice(["", " ", "x", "&", ";"]).join(chunk))
    # Names that are nearly entities: another case, no semicolon, a
    # character more or less.
    for name in rng.sample(names, 50):
        inner = name[1:-1]
        out.append(
            " ".join(
                [
                    "&" + inner.lower() + ";",
                    "&" + inner.upper() + ";",
                    "&" + inner.capitalize() + ";",
                    "&" + inner.swapcase() + ";",
                    "&" + inner,
                    "&" + inner + "x;",
                    "&" + inner[:-1] + ";",
                    "& " + inner + ";",
                    "&&" + inner + ";;",
                    "&amp;" + inner + ";",
                ]
            )
        )
    # The longest name HTML_ENTITY_RE can match has 24 characters.
    for length in (1, 2, 23, 24, 25, 26, 32, 33):
        out.append("&" + "a" * length + ";")
        out.append("&#" + "1" * length + ";")
        out.append("&#" + "0" * length + "65;")
        out.append("&#x" + "0" * length + "41;")
        out.append("&#x" + "f" * length + ";")
    out += [name for name in names if len(name) > 26]

    # Numeric references: both sides of every range of the table of
    # exceptions, in every way of writing a number.
    edges = set()
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tables", "html_numeric.txt")) as handle:
        for line in list(handle)[1:]:
            first, last, _ = line.rstrip("\n").split("\t")
            first = int(first, 16)
            edges.update([first - 1, first])
            if last != "inf":
                edges.update([int(last, 16), int(last, 16) + 1])
    edges.discard(-1)
    edges.update([9, 10, 12, 13, 32, 38, 59, 60, 65, 0x81, 0x8D, 0x90, 0x9D, 0xA0, 0xFEFF])
    edges.update([0x10000, 0x1F600, 2**31 - 1, 2**31, 2**32, 2**53, 2**64, 10**23])
    for number in sorted(edges):
        forms = ["&#%d;", "&#x%x;", "&#X%X;", "&#00%d;", "&#x00%x;", "&#%d", "&#x%X;"]
        out.append(" ".join(form % number for form in forms))
    for _ in range(150):
        numbers = [rng.choice([rng.randrange(0x300), rng.randrange(0x110000)]) for _ in range(rng.randrange(1, 6))]
        out.append("".join(rng.choice(["&#%d;", "&#x%x;", "&#X%X;"]) % n + rng.choice(["", " ", "a"]) for n in numbers))
    out += [
        "&#;", "&#x;", "&#X;", "&#xg;", "&#12a;", "&#x12g;", "&#abc;", "&#0x41;",
        "&#x0x41;", "&#x0X41;", "&#xx41;", "&#Xx41;", "&#1e3;", "&#x1e3;", "&#-65;",
        "&#+65;", "&# 65;", "&#65 ;", "&#6_5;", "&#65.0;", "&#" + U(0x663) + ";",
        "&#" + U(0xFF11) + ";", "&#x41", "&#65", "&#59;", "&#x3b;", "&#X3B;", "&#059;",
        "&#59;&#59;", "a&#59;b&amp;c", "&#38;#38;", "&#38;amp;", "&amp;#38;", "&#x26;lt;",
        "&;", "&", ";", "&&;;", "&a;", "&amp", "&AMP;", "&Amp;", "&aMp;", "&amp;amp;",
        "&ntilde; &Ntilde; &NTILDE; &nTILDE;", "BUNDESSTRA&SZLIG;E", "&checkmark;",
        "&Jscr;ohn &HilbertSpace;ancock", "EURO &EURO;", "JEDNOCZE&SACUTE;NIE",
        "V&SCARON;ICHNI", "&#xffff;", "&#xffffffff;", "euro &#x80;",
        "not an entity &#20x6;", "this is just informal english &not html",
        "&lt;" * 40, "&#65;" * 40, ("&amp; " * 7 + "&bogus; ") * 5,
        "&nbsp;&NBSP;&shy;&zwj;&zwnj;&lrm;&rlm;", "&NewLine;&Tab;&excl;&quot;&apos;",
        "&" + U(0xE9) + ";", "&e" + U(0x301) + ";", U(0xFF06) + "amp;",
    ]
    return out


def ansi_inputs(rng):
    out = [
        ESC, ESC + "[", ESC + "[m", ESC + "[0m", ESC + "[0", ESC + "[;", ESC + "[;m",
        ESC + "[1;2;3x", ESC + "[1;", ESC + "[?25h", ESC + "[38;5;1m", ESC + "[38:5:1m",
        ESC + "[" + ESC + "[0m", ESC + ESC + "[0m", ESC + "[0" + LF + "m", ESC + "[0 m",
        ESC + "[" + U(0x663) + "m", ESC + "[" + U(0xFF11) + ";" + U(0x0967) + "Z",
        ESC + "[1" + U(0xE9), ESC + "[1" + U(0xFF4D), ESC + "]0;title" + U(0x07),
        ESC + "(B", U(0x9B) + "0m", "[0m", "\\033[0m", ESC + "[0mm", ESC + "[A" + ESC + "[B",
        "a" + ESC + "[2Kb" + ESC + "[1Gc", ESC + "[" + "1;" * 60 + "m", ESC + "[" + "9" * 80 + "H",
        BOM + ESC + "[0m", ESC + "[0m" + BOM,
    ]
    parts = [ESC, "[", ";", "m", "H", "0", "1", "31", " ", "a", LF, U(0x664), "?"]
    for _ in range(60):
        out.append("".join(rng.choice(parts) for _ in range(rng.randrange(2, 12))))
    # Whole sequences inside text, one or more to a string.
    letters = "mHJKABCDfhlsu" + "Zzq"
    for _ in range(90):
        text = ""
        for _ in range(rng.randrange(1, 5)):
            numbers = [str(rng.randrange(120)) for _ in range(rng.randrange(0, 4))]
            text += rng.choice(["", "a", "text ", LF]) + ESC + "[" + ";".join(numbers) + rng.choice(letters)
        out.append(text + rng.choice(["", "end", ESC]))
    return out


def quote_inputs(rng):
    numbers = list(range(0x2B9, 0x2C0)) + list(range(0x2010, 0x2024)) + [0x22, 0x27, 0x60, 0xB4, 0xAB, 0xBB, 0x2032, 0x2033, 0x2039, 0x203A, 0x275B, 0x275D, 0x301D, 0xFF02, 0xFF07]
    out = ["a" + U(number) + "b" for number in numbers]
    out.append("".join(U(number) for number in numbers))
    out.append(U(0x201C) * 30 + U(0x2019) * 30)
    pool = [U(number) for number in numbers] + list("ab '\"")
    for _ in range(80):
        out.append("".join(rng.choice(pool) for _ in range(rng.randrange(1, 12))))
    return out


def table_inputs(mapping, rng, near):
    """Every character of a translate table: alone, in runs, and mixed
    with characters next to the table's."""
    numbers = sorted(number for number in mapping if number != 0)
    out = [U(number) for number in numbers]
    out += ["a" + U(number) + "b" + U(number) for number in numbers]
    for at in range(0, len(numbers), 16):
        out.append(U(*numbers[at : at + 16]))
    pool = numbers + near
    for _ in range(60):
        out.append("".join(rng.choice([U(rng.choice(pool)), "a", " "]) for _ in range(rng.randrange(1, 14))))
    out += [U(number) for number in near]
    return out


def line_break_inputs():
    parts = [CR, LF, U(0x2028), U(0x2029), U(0x85), "a"]
    out = []
    for length in (1, 2, 3):
        out += ["".join(combo) for combo in itertools.product(parts, repeat=length)]
    out += [
        CR + CR + LF, LF + CR, CR + LF + CR + LF, CR + CR + LF + LF, U(0x0B), U(0x0C),
        U(0x1C, 0x1D, 0x1E), U(0x2027), U(0x202A), U(0x84), U(0x86), "a\\r\\nb",
        BOM + CR, CR + BOM + LF, (CR + LF) * 50,
    ]
    return out


def main():
    rng = random.Random(SEED)
    own = {
        "unescape_html": html_inputs(rng),
        "remove_terminal_escapes": ansi_inputs(rng),
        "uncurl_quotes": quote_inputs(rng),
        "fix_latin_ligatures": table_inputs(
            chardata.LIGATURES, rng,
            [0xC6, 0xE6, 0x152, 0x153, 0xDF, 0x131, 0x134, 0x148, 0x14A, 0x1C3, 0x1CD,
             0x1F0, 0x1F4, 0x17F, 0xFB07, 0xFB13, 0xFB1D, 0xFB4F, 0x2BC],
        ),
        "fix_character_width": table_inputs(
            chardata.WIDTH_MAP, rng,
            [0x3001, 0x3002, 0x2FFF, 0xFF00, 0xFFA0, 0xFFBF, 0xFFC0, 0xFFC1, 0xFFC8,
             0xFFDD, 0xFFDF, 0xFFE7, 0xFFEF, 0xFFF0, 0xFFFD, 0x30FB, 0x3099, 0x309A,
             0x20, 0xA0, 0x304, 0x1F600],
        ),
        "fix_line_breaks": line_break_inputs(),
        "remove_control_chars": table_inputs(
            chardata.CONTROL_CHARS, rng,
            [0x09, 0x0A, 0x0C, 0x0D, 0x20, 0x80, 0x85, 0x9F, 0xA0, 0xAD, 0x200B,
             0x200C, 0x200F, 0x2028, 0x2029, 0x202A, 0x202E, 0x2060, 0x2069, 0x2070,
             0xFEFE, 0xFFF8, 0xFFFD, 0xFFFE, 0x1D173, 0x1D17A, 0xE0001, 0xE007F],
        ),
    }
    shared = SHARED + shared_fuzz(rng)
    lines = ["fixer\ttext\tfixed\n"]
    for fixer in FIXERS:
        function = getattr(fixes, fixer)
        for text in dict.fromkeys(shared + own[fixer]):
            fixed = function(text)
            if not (storable(text) and storable(fixed)):
                continue
            lines.append("%s\t%s\t%s\n" % (fixer, escape(text), escape(fixed)))
    write_ascii("tests/testthat/reference/text_fixers.tsv", "".join(lines))


main()
