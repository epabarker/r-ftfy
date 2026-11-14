# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of fix_text() from the reference version to
tests/testthat/reference/fix_text.tsv.

Columns, tab separated. Texts are escaped (see _reference.escape).

- text: the input.
- fixed: what fix_text(text) gives with default options.
- <variant>, for each variant in VARIANTS below: what fix_text() gives
  with that one option changed, given as a keyword argument, as in
  fix_text(text, uncurl_quotes=False). The field is empty when the result
  is the same as with default options.
- config_no_<option>, for each of the four options of the encoding repair:
  what fix_text(text, TextFixerConfig(<option>=False)) gives, empty when
  it is the same as with default options.

The last four are there because the reference version treats the two
forms differently. Given as a keyword argument, an option of the encoding
repair is not passed on to the repair (ftfy/__init__.py:341 makes a config
that does not explain, and :396 then calls fix_encoding(text) with no
config), so the four columns no_<option> of these options are empty in
every row, and the script stops if one is not. (For fix_c1_controls that
is a fact about these rows: the fixer of that name in the loop is switched
off, and the encoding repair replaces the same characters first.) Given in
a TextFixerConfig, the option is passed on. The R package
honours the option in both forms (the departure
encoding-sub-options-honoured), so what it gives must equal the config_
column.

This snapshot is small on purpose: the shipped fixtures have a budget, and
the large corpus is kept out of the build. It holds strings of several
lines, lines longer than a small max_decode_length, a "<" that switches
unescape_html off for the lines after it, and every option. The inputs are
seeded, so a rerun gives the same file byte for byte. A row whose input
holds U+0000 or a surrogate, or whose output holds a surrogate, is left
out, because an R string cannot hold them, and so is a row with an empty
result that differs from the default one, which an empty field could not
show. An output that holds U+0000 is kept, escaped: the reference version
decodes one from a line that ends in the byte C0 (the departure
utf8-variants-trailing-newline) and keeps it when remove_control_chars is
off.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

import ftfy

SEED = 41
MAX_BYTES = 60000

BOOLEANS = [
    "remove_terminal_escapes",
    "fix_encoding",
    "restore_byte_a0",
    "replace_lossy_sequences",
    "decode_inconsistent_utf8",
    "fix_c1_controls",
    "fix_latin_ligatures",
    "fix_character_width",
    "uncurl_quotes",
    "fix_line_breaks",
    "remove_control_chars",
]

SUB_OPTIONS = [
    "restore_byte_a0",
    "replace_lossy_sequences",
    "decode_inconsistent_utf8",
    "fix_c1_controls",
]

# The name of each variant's column, and the one option it changes.
VARIANTS = (
    [("no_" + option, {option: False}) for option in BOOLEANS]
    + [
        ("normalization_NFD", {"normalization": "NFD"}),
        ("normalization_NFKC", {"normalization": "NFKC"}),
        ("normalization_NFKD", {"normalization": "NFKD"}),
        ("normalization_NULL", {"normalization": None}),
        ("unescape_html_TRUE", {"unescape_html": True}),
        ("unescape_html_FALSE", {"unescape_html": False}),
        ("max_decode_length_3", {"max_decode_length": 3}),
        ("max_decode_length_10", {"max_decode_length": 10}),
    ]
)

CHOSEN = [
    "",
    "\n",
    "\n\n\n",
    "plain ASCII text\nof two lines\n",
    "no newline at the end\nof the last line",
    # the "<" that switches unescape_html off for the later segments
    "&amp;\n<html>\n&amp;",
    "&amp;\n&amp;\n<\n&amp;\n&amp;",
    "<\n&amp;",
    "&lt;\n&amp;\n",
    "&amp; a < b\n&amp;",
    "&amp;lt;\n&amp;\n&lt;b&gt; &amp;amp;\n&amp;",
    "one &amp; two <three> &amp; four &amp; five\n&eacute;",
    "caf&Atilde;&copy;\n<p>caf&Atilde;&copy;</p>\ncaf&Atilde;&copy;\n",
    "P&EACUTE;REZ\n&#x201c;q&#x201d;\n",
    # each line repaired by itself
    "caf\u00c3\u00a9\ncaf\u00e9\n\u2603 caf\u00c3\u00a9\n",
    "\u00e2\u0153\u201d No problems\n\u0413\u00a9 other codec\nvoil\u00c3 le travail\n",
    "caf\u00c3\u00a9 \u2603\ncaf\u00c3\u00a9",
    "l\u2019humanit\u00c3\u00a9\n\u00c3\u00a0 perturber la r\u00c3\u00a9flexion\n\u00c3 perturber la r\u00c3\u00a9flexion",
    "The Mona Lisa doesn\u00c3\u0192\u00c2\u00a2\u00c3\u00a2\u00e2\u20ac\u0161\u00c2\u00ac\u00c3\u00a2\u00e2\u20ac\u017e\u00c2\u00a2t have eyebrows.\nIL Y MARQU\u00c9\u2026\n",
    "\u00c3\u00a9t\u00c3\u00a9\n\u00d0\u009f\u00d1\u0080\u00d0\u00b8\u00d0\u00b2\u00d0\u00b5\u00d1\u0082\n\u00ce\u00ba\u00ce\u00b1\u00ce\u00bb\n",
    # line breaks: only "\n" ends a segment
    "dos\r\nlines\r\nhere",
    "old mac\rlines\rcaf\u00c3\u00a9\r",
    "sep\u2028arators\u2029and\u0085next line\ncaf\u00c3\u00a9\u2028\n",
    "\r\n\r\n\n\r",
    # U+FEFF and characters outside the first plane, at the cuts
    "\ufeffcaf\u00c3\u00a9\n\ufeffsecond\n",
    "\ufeff",
    "\ufeff\n\ufeff",
    "a\ufeff\nb",
    "\U0001f600\n\U0001f600\U0001f600\n\U0001f3f4\U000e0067\U000e0062\U000e0077\U000e006c\U000e0073\U000e007f flag\n",
    "#superman #ohio \U0001f3f4\U000e0075\U000e0073\U000e006f\U000e0068\U000e007f #cleveland #usa \U0001f1fa\U0001f1f8",
    "\u00f0\u0178\u02dc\u20ac mojibake of U+1F600\n\U0001f600 and the real one\n",
    # every fixer, across lines
    "\x1b[36;44mfoo\x1b[0m\n\x1b[1mbar\nbaz\x1b[0m",
    "\ufb01ne\n\uff2c\uff2f\uff35\uff24\u3000\uff2e\uff2f\uff29\uff33\uff25\uff33\n\u201cquotes\u201d it\u2019s\n",
    "e\u0301\ne\n\u0301\n\u212b \u00bd\n",
    "\u0093quoted\u0094\n\u0085\na\u0081b\n\u0080 5 \u2603\n",
    "bell\x07\ndel\x7f\n\u200bzero\u200cwidth\n",
    "&macr;\\_(\u00e3\u0083\u0084)_/&macr;\nBroken text&hellip; it&#x2019;s \ufb02ubberi\ufb01c!\n",
    "\ufeff\u201cCaf\u00c3\u00a9\u201d &amp; \ufb01ne\r\n<b>\u201cCaf\u00c3\u00a9\u201d &amp; \ufb01ne</b>\r\n&amp;",
    # the options of the encoding repair
    "\u00c3 \u00e2\u20ac\u2122\nvoil\u00c3  le travail\n",
    "\ufffd\u00c3\u00a9\ncaf\u00c3\u00a9 \ufffd\n\u00c3\ufffdtude\n",
    "\u00e9\u00c2\u00a0\n\u2603 caf\u00c3\u00a9\ncaf\u00c3\u00a9\n",
    "\u0094\u044f\n\u015a\u0091\ncaf\u00c3\u00a9 \u0093x\u0094 \u2603\n",
    "\u0085\u040e \u0085\u0449",
    "\u00e0\u00b8 \u00e0\u00b8\u00b2\u00e0\u00b8\u00a9\u00e0\u00b8\u00b2\u00e0\u00b9\u201e\u00e0\u00b8\u2014\u00e0\u00b8\u00a2\n",
    "voil\u00c3 le travail\n\ufffd\u00e9\u00e2\u20ac x\n",
    "\u00c3 \u00e2\u20ac\u2122",
    "voil\u00c3  le travail",
    "\u00d0 \u00d1\u0192\u00d1\ufffd\u00d1\ufffd\u00d0\u00ba\u00d0\u00b8\u00d0\u00b9\nplain\n",
    "\u00e0\u00b8 \u00e0\u00b8\u00b2\u00e0\u00b8\u00a9\u00e0\u00b8\u00b2\u00e0\u00b9\u201e\u00e0\u00b8\u2014\u00e0\u00b8\u00a2",
    # a line that ends in a sequence cut short, C0 or five bytes of a
    # six-byte surrogate pair (the departure utf8-variants-trailing-newline)
    "sch\u00c3\u00b6n \u00c0\n",
    "sch\u00c3\u00b6n \u00c0",
    "one \u00c3\u00a9 \u00c0\ntwo \u00c3\u00a9",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\n",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n",
    # lines longer than a small max_decode_length
    "caf\u00c3\u00a9 caf\u00c3\u00a9 caf\u00c3\u00a9 caf\u00c3\u00a9 caf\u00c3\u00a9",
    "abc\ndefghi\njklmnopqrstuvwxyz\n0123456789\n01234567890\n",
    "&amp;&amp;&amp;&amp; <&amp;&amp;&amp;&amp;&amp;&amp;&amp;&amp;\n&amp;",
    "\u00e2\u20ac\u0153mojibake quotes\u00e2\u20ac\u009d that are cut\u00e2\u20ac\u2122",
    "\uff21\uff22\uff23\uff24\uff25\uff26\uff27\uff28\uff29\uff2a\uff2b\uff2c\ne\u0301e\u0301e\u0301e\u0301e\u0301e\u0301\n",
    "12\r\n4567890\r\n\r\n",
    "\U0001f600\U0001f600\U0001f600\ufeff\U0001f600\U0001f600\U0001f600\U0001f600\U0001f600\U0001f600\U0001f600\U0001f600",
]

# Pieces the seeded texts are joined from: each is something one fixer, or
# the encoding repair, changes. The characters to normalise were all
# assigned by Unicode 3.2, so no ICU in use normalises them differently.
PIECES = [
    "&amp;", "&lt;", "&eacute;", "&#x201c;", "&amp;amp;", "<", "<b>",
    "\x1b[0m", "\x1b[31;1m",
    "\u0081", "\u0085", "\u0092", "\u0080",
    "\ufb01", "\u0153", "\ufb03",
    "\uff21", "\u3000", "\uff76\uff9e",
    "\u201c", "\u2019",
    "\r\n", "\r", "\u2028",
    "\ufeff", "\u200b", "\x07",
    "e\u0301", "\u212b", "\u00bd", "\u1100\u1161",
    "\u00c3\u00a9", "\u00e2\u20ac\u2122", "\u00c3 ", "\u00e2\u20ac", "\u00c2\u00a0",
    "\u00c3\u0192\u00c2\u00a9", "\u00d0\u00b6", "\u0413\u00a9", "\ufffd", "\u00ef\u00bb\u00bf",
    "\u00e9", "\u2603", "\u4e16", "\U0001f600", "\u00c0",
]
FILLER = ["a", "e", "t", " ", " ", "Z", ".", "?", "1", "the ", "word"]


def joined_lines(rng):
    out = []
    for _ in range(60):
        lines = []
        for _ in range(rng.randrange(2, 6)):
            length = rng.randrange(0, 8)
            lines.append(
                "".join(
                    rng.choice(PIECES) if rng.random() < 0.5 else rng.choice(FILLER)
                    for _ in range(length)
                )
            )
        out.append("\n".join(lines) + ("\n" if rng.random() < 0.5 else ""))
    return out


def has_surrogate(text):
    return any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def main():
    rng = random.Random(SEED)
    texts = list(dict.fromkeys(CHOSEN + joined_lines(rng)))
    header = ["text", "fixed"] + [name for name, _ in VARIANTS]
    header += ["config_no_" + option for option in SUB_OPTIONS]
    lines = ["\t".join(header) + "\n"]
    differing = {name: 0 for name in header[2:]}
    carried = 0
    for text in texts:
        default = ftfy.fix_text(text)
        results = [ftfy.fix_text(text, **options) for _, options in VARIANTS]
        results += [
            ftfy.fix_text(text, ftfy.TextFixerConfig(**{option: False}))
            for option in SUB_OPTIONS
        ]
        if "\x00" in text or any(has_surrogate(t) for t in [text, default] + results):
            continue
        if any(result == "" and default != "" for result in results):
            continue
        fields = [escape(text), escape(default)]
        for name, result in zip(header[2:], results):
            fields.append("" if result == default else escape(result))
            differing[name] += result != default
        # A "<" in one segment that keeps an entity in a later one.
        carried += (
            "<" in text
            and default != ftfy.fix_text(text, unescape_html=True)
            and default != ftfy.fix_text(text, unescape_html=False)
        )
        lines.append("\t".join(fields) + "\n")

    # A keyword argument for an option of the encoding repair changes
    # nothing in the reference version; the same option in a config does.
    for option in SUB_OPTIONS:
        assert differing["no_" + option] == 0, (option, differing["no_" + option])
    for name, count in differing.items():
        if name not in ("no_" + option for option in SUB_OPTIONS):
            assert count >= 3, (name, count)
    assert carried >= 3, carried
    out = "".join(lines)
    assert len(out) <= MAX_BYTES, len(out)
    write_ascii("tests/testthat/reference/fix_text.tsv", out)


main()
