# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of fix_and_explain() from the reference version to
tests/testthat/reference/fix_and_explain.tsv.

Columns, tab separated. Texts are escaped (see _reference.escape) and a
plan is in its text form ("encode latin-1 > decode utf-8", or "none" for
no steps).

- text: the input.
- fixed, plan: what fix_and_explain() gives with default options.
- <variant>, plan.<variant>, for each variant in VARIANTS below (each
  boolean option False, each other normalisation form and None, and
  unescape_html True and False): the text and the plan with that one
  option changed. Both fields are empty when both are the same as with
  default options; otherwise both are written, so a plan field is never
  empty for a result that differs.

This snapshot is small on purpose: the shipped fixtures have a budget, and
the large corpus is kept out of the build. The inputs are chosen so that
every fixer, every action and every option shows; the script stops if one
does not. The inputs are seeded, so a rerun gives the same file byte for
byte. A row whose input holds U+0000 or a surrogate, or whose output holds
a surrogate, is left out, because an R string cannot hold them. An output
that holds U+0000 is kept, escaped: the departure decoded-nul-dropped says
what the package gives in its place.

Normalisation follows the user's ICU in R (the departure
normalization-follows-icu), so the random part draws only characters
that Unicode 3.2 already assigned, whose normalisation no version of ICU
in use can give differently. The rows of NEW_IN_UNICODE_15 are the
exception, and are there for that departure.
"""

import os
import random
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, has_surrogate, plan_text, require_reference, storable, write_ascii

require_reference()

import ftfy

SEED = 40
MAX_BYTES = 110000

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
    ]
)

CLEAN = [
    "caf\u00e9 cr\u00e8me br\u00fbl\u00e9e \u00e0 la carte",
    "voil\u00e0 le travail",
    "Stra\u00dfe \u00fcber \u00c4rger",
    "\u00bfqu\u00e9? \u00a1s\u00ed, se\u00f1or!",
    "\u201ccurly quotes\u201d and it\u2019s \u2018single\u2019",
    "en \u2013 dash, em \u2014 dash, ellipsis\u2026",
    "price: \u20ac10, \u00a35 \u2122",
    "\u017elu\u0165ou\u010dk\u00fd k\u016f\u0148",
    "\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440!",
    "\u039a\u03b1\u03bb\u03b7\u03bc\u03ad\u03c1\u03b1",
    "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c",
    "\u2714 No problems \U0001f600",
    "na\u00efve \u00c0 propos, \u00e0 demain",
]

CODECS = [
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


def one_layer(text, codec):
    return text.encode("utf-8").decode(codec, errors="replace")


def mix_ups():
    out = []
    for number, text in enumerate(CLEAN):
        # One of the two common codecs and one of the others in turn, so
        # that every codec is met.
        for codec in (CODECS[number % 2], CODECS[2 + number % 8]):
            out.append(one_layer(text, codec))
        once = one_layer(text, "sloppy-windows-1252")
        # The no-break space turned into a space, as a browser does.
        out.append(once.replace("\xa0", " "))
        # Read by a strict codec, so that each hole became U+FFFD, or "?"
        # where the character was lost.
        lossy = text.encode("utf-8").decode("windows-1252", errors="replace")
        out.append(lossy if number % 2 else lossy.replace("\ufffd", "?"))
        # Two layers.
        if number % 2:
            out.append(one_layer(once, "sloppy-windows-1252"))
        else:
            out.append(one_layer(one_layer(text, "latin-1"), "sloppy-windows-1251"))
        # A mix-up inside text that is otherwise fine.
        out.append(text + " " + once)
        # Latin-1 read as it is, where Windows-1252 was meant.
        out.append(text.encode("sloppy-windows-1252", errors="replace").decode("latin-1"))
    return out


# Texts for each fixer of the loop and each option, alone and together.
CHOSEN = [
    "",
    " ",
    "plain ASCII text, nothing to see",
    "tab\tand newline\nkept",
    # unescape_html, and its "auto" value
    "&amp;",
    "&amp;amp;amp;",
    "&lt;&gt;",
    "&lt;b&gt; &amp;amp;",
    "<b> &amp;",
    "<html> &eacute; &amp;eacute;",
    "a < b &amp;&amp; c",
    "&amp;\n<html>\n&amp;",
    "jednocze&sacute;nie",
    "JEDNOCZE&Sacute;NIE",
    "ellipsis&#133;",
    "ellipsis&#x85;",
    "broken&#x81;",
    "euro &#x80; &euro; &EURO;",
    "this is just informal english &not html",
    "&#59; &#x3b; &#0; &#xffff; &#xffffffff; &#20x6;",
    "&quot;quoted&quot; &apos;s &nbsp; &hellip;",
    "&ldquo;curly&rdquo; &rsquo;s &#8220;numeric&#8221;",
    "caf&Atilde;&copy;",
    "caf&amp;Atilde;&amp;copy;",
    "&macr;\\_(\u00e3\u0083\u0084)_/&macr;",
    "Broken text&hellip; it&#x2019;s \ufb02ubberi\ufb01c!",
    "&#xfb01;ne &#xff21;&#xff22; &#x1b;[0m &#13;&#10;",
    "<tag> caf\u00c3\u00a9 &amp; \u201cquotes\u201d",
    # remove_terminal_escapes
    "\x1b[36;44mfoo\x1b[0m",
    "\x01\x1b[36;44mfoo",
    "\x1b[1m\x1b[31mbold red\x1b[m plain",
    "not an escape: \x1b[ and [36m",
    "\x1b[2Kcaf\u00c3\u00a9\x1b[0m",
    # fix_c1_controls, in and out of the encoding repair
    "a\u0081b",
    "\u0093quoted\u0094",
    "\u0093quoted\u0094 \u0080 5",
    "\u0085 next line or ellipsis",
    "it\u0092s \u0081 hole",
    "\u0080\u0081\u008d\u008f\u0090\u009d\u009f",
    "C1 \u0096 beside \u2014 dash",
    "caf\u00e9 \u0093x\u0094",
    # fix_latin_ligatures
    "\ufb01ne \ufb02u\ufb00y o\ufb03ce wa\ufb04e",
    "\u0132sselmeer \u0153uvre \u01c4 \u01c6 \u02a3",
    "\ufb05 \ufb06 \u0149 \u01f1",
    # fix_character_width
    "\uff2c\uff2f\uff35\uff24\u3000\uff2e\uff2f\uff29\uff33\uff25\uff33",
    "\uff8a\uff9d\uff76\uff78 \uff76\uff9e half-width katakana",
    "\uffe3\uffe5\uffe6 \uff5e \uff01\uff1f",
    "\uffa1\uffa2 \uffe8\uffe9",
    # uncurl_quotes
    "\u201chello\u201d \u2018world\u2019 \u201a\u201b\u201e\u201f \u02bc",
    "it\u2019s",
    "\u00ab guillemets \u00bb \u2039 stay \u203a",
    # fix_line_breaks
    "one\r\ntwo\rthree\u2028four\u2029five\u0085six",
    "\r\r\n\n\r",
    "line\u2028",
    "dos\r\n",
    # remove_control_chars
    "\ufeffhello",
    "\ufeff",
    "hello\ufeff",
    "a\ufeffb \u200bzero\u200cwidth\u200d",
    "bell\x07 del\x7f \x00x".replace("\x00", "\x1f"),
    "\ufeffSometimes, \ufffcbad ideas \x7f\ufffalike these characters\ufffb \u206aget standardized.\r\n",
    "This flag has a dragon on it \U0001f3f4\U000e0067\U000e0062\U000e0077\U000e006c\U000e0073\U000e007f",
    "\u202eright to left\u202c \u2066isolate\u2069",
    "\x08\x0b\x0c\x0e \t\n kept",
    # normalisation
    "e\u0301",
    "e\u0301 e\u0300 a\u0308 n\u0303",
    "\u00e9 already composed",
    "\u212b \u2126 \u212a",
    "\u1e9b\u0323",
    "q\u0323\u0307 q\u0307\u0323",
    "\u1100\u1161\u11a8 \uac01",
    "\u00bd \u00b2 \u2460 \u3392 \u2122 \u2026",
    "\u00a0no-break\u2002spaces\u2003",
    "\u03d2\u0301 \u1fee \u0344",
    "\ufdfa \ufb2c\u05bc",
    "\u0958 \u0f73 \u2adc",
    "\uff76\uff9e",
    "\ufb01e\u0301",
    # several fixers on one text, and steps over several passes
    "\ufeff\u201cCaf\u00c3\u00a9\u201d &amp; \ufb01ne\r\n",
    "&lt;3 \u00e2\u0099\u00a5 \uff21\uff22\uff23",
    "\u00c3\u00a2\u00e2\u0082\u00ac\u00c5\u0093quoted\u00c3\u00a2\u00e2\u0082\u00ac\u00c2\u009d",
    "\x1b[1m&ldquo;bold&rdquo;\x1b[0m e\u0301\u2028",
    "\u00e2\u20ac\u0153mojibake quotes\u00e2\u20ac\u009d",
    "\u00e2\u20ac\u0153lost quote\u00e2\u20ac",
    "&#xc3;&#xa9; &#195;&#169; &Atilde;&#169;",
    "\u00ef\u00bb\u00bfbyte order mark mojibake",
    "\u00c3\u00af\u00c2\u00bb\u00c2\u00bftwo layers of it",
    "\u00ef\u00ac\u0081 ligature mojibake",
    "\u00ef\u00bc\u00a1 full-width mojibake",
    "e\u00cc\u0081 combining mojibake \u00e2\u0080\u009cq\u00e2\u0080\u009d",
    "\u00e2\u0080\u00a8 line separator mojibake",
    "\u00c2\u0085 next line mojibake",
    "\u00c3\u0083\u00c2\u00a9t\u00c3\u0083\u00c2\u00a9",
    "voil\u00c3 le travail",
    "voil\u00c3 le travail \u2603",
    "\u2603 caf\u00c3\u00a9",
    "\ufffd\u00e9\u00e2\u20ac",
    "\u00c3\ufffdtude \u00c3? la carte",
    "\u00c3\u0081 \u00c3 \u00c3\u00a0",
    "l\u00e2\u20ac\u2122\u00c3 propos",
    "\uff23\uff41\uff46\u00c3\u00a9 \u201cx\u201d\r",
    "&amp;lt;tag&amp;gt; caf\u00c3\u00a9",
    "#\u2581\u2588 \u00c2\u00a0 no-break",
    "\u00d0\u009f\u00d1\u0080\u00d0\u00b8\u00d0\u00b2\u00d0\u00b5\u00d1\u0082",
    "\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35 \u00e0\u00b8\u00aa\u00e0\u00b8\u00a7",
]

# Inputs whose decoding gives U+0000 (the departure decoded-nul-dropped).
NUL = [
    "null\u00c0\u20acseparated",
    "caf\u00c3\u00a9 \u00c0\u0080 end",
]

# Characters that Unicode 15.0 assigned and that have a combining class or
# a decomposition, so an ICU that does not know them yet normalises these
# texts differently (the departure normalization-follows-icu).
NEW_IN_UNICODE_15 = [
    "a\U00010efd\u0301",
    "q\u0301\U00010efd",
    "\U0001e030\U0001e051 e\u0301",
    "x\u0301\U0001e4ee \U0001e08f",
]

# Pieces the seeded texts are joined from: each is something one fixer of
# the loop, or the encoding repair, changes.
PIECES = [
    "&amp;", "&lt;", "&eacute;", "&#x201c;", "&#x81;", "&amp;amp;", "<",
    "\x1b[0m", "\x1b[31;1m",
    "\u0081", "\u0085", "\u0092", "\u0080",
    "\ufb01", "\u0153", "\ufb03",
    "\uff21", "\u3000", "\uff76\uff9e", "\uffe3",
    "\u201c", "\u2019", "\u201e",
    "\r\n", "\r", "\u2028", "\u2029",
    "\ufeff", "\u200b", "\x07", "\x7f",
    "e\u0301", "\u212b", "\u00bd", "a\u0323\u0302", "\u1100\u1161",
    "\u00c3\u00a9", "\u00e2\u20ac\u2122", "\u00c3 ", "\u00e2\u20ac", "\u00c2\u00a0",
    "\u00c3\u0192\u00c2\u00a9", "\u00d0\u00b6", "\u0413\u00a9", "\ufffd", "\u00ef\u00bb\u00bf",
    "\u00e9", "\u2603", "\u4e16", "\U0001f600",
]
FILLER = ["a", "e", "t", "n", " ", " ", "Z", ".", ",", "?", "1", "\n", "the ", "word"]


def joined_pieces(rng):
    out = []
    for _ in range(60):
        length = rng.randrange(2, 9)
        out.append(
            "".join(
                rng.choice(PIECES) if rng.random() < 0.55 else rng.choice(FILLER)
                for _ in range(length)
            )
        )
    return out


def old_characters(rng):
    # Characters assigned since Unicode 3.2, with no U+0000 and no surrogate.
    pool = [
        chr(cp)
        for cp in range(1, 0x30000)
        if not 0xD800 <= cp <= 0xDFFF
        and unicodedata.ucd_3_2_0.category(chr(cp)) not in ("Cn", "Co")
    ]
    out = []
    for _ in range(20):
        length = rng.randrange(1, 7)
        out.append("".join(rng.choice(pool) for _ in range(length)))
    return out


def main():
    rng = random.Random(SEED)
    texts = (
        CHOSEN + CLEAN + mix_ups() + NUL + NEW_IN_UNICODE_15
        + joined_pieces(rng) + old_characters(rng)
    )
    texts = list(dict.fromkeys(texts))
    header = ["text", "fixed", "plan"]
    for name, _ in VARIANTS:
        header += [name, "plan." + name]
    lines = ["\t".join(header) + "\n"]
    differing = {name: 0 for name, _ in VARIANTS}
    steps_seen = set()
    for text in texts:
        if not storable(text):
            continue
        default = ftfy.fix_and_explain(text)
        assert default.text == ftfy.fix_text_segment(text)
        results = [default]
        fields = [escape(text), escape(default.text), plan_text(default.explanation)]
        for name, options in VARIANTS:
            result = ftfy.fix_and_explain(text, **options)
            results.append(result)
            if (result.text, result.explanation) == (default.text, default.explanation):
                fields += ["", ""]
            else:
                fields += [escape(result.text), plan_text(result.explanation)]
        if any(has_surrogate(result.text) for result in results):
            continue
        for (name, _), result in zip(VARIANTS, results[1:]):
            if (result.text, result.explanation) != (default.text, default.explanation):
                differing[name] += 1
        for result in results:
            steps_seen.update(tuple(step) for step in result.explanation)
        lines.append("\t".join(fields) + "\n")

    # Every option shows, and so does every step the loop can record.
    for name, count in differing.items():
        assert count >= 5, (name, count)
    wanted = (
        [("apply", fixer) for fixer in (
            "unescape_html", "remove_terminal_escapes", "fix_c1_controls",
            "fix_latin_ligatures", "fix_character_width", "uncurl_quotes",
            "fix_line_breaks", "remove_control_chars", "decode_inconsistent_utf8",
        )]
        + [("transcode", fixer) for fixer in (
            "fix_c1_controls", "restore_byte_a0", "replace_lossy_sequences",
        )]
        + [("normalize", form) for form in ("NFC", "NFD", "NFKC", "NFKD")]
        + [("encode", codec) for codec in CODECS]
        + [("decode", codec) for codec in ("utf-8", "utf-8-variants", "windows-1252")]
    )
    missing = [step for step in wanted if step not in steps_seen]
    assert not missing, missing
    out = "".join(lines)
    assert len(out) <= MAX_BYTES, len(out)
    write_ascii("tests/testthat/reference/fix_and_explain.tsv", out)


main()
