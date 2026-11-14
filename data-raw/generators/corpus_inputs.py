# Derived from python-ftfy v6.3.1, ftfy/ and tests/test_examples_in_json.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the inputs of the larger corpus that are built from our own text
to tests/corpus/inputs/own.tsv.xz.

Columns, tab separated:

- id: 1, 2, ... in file order.
- slice: "own" on every row. Another slice is another file beside this
  one (see _corpus.py).
- variant: what kind of input the row is; see VARIANTS below.
- detail: how the row was made, mostly the codecs of a mix-up, as
  "utf-8>sloppy-windows-1252" for text encoded with the first and decoded
  with the second. Free text for a reader; nothing depends on it.
- unicode: the newest Unicode version among the characters of the input,
  as "major.minor". (The snapshot has the tag to skip rows by, which also
  looks at the outputs.)
- text: the input, escaped (see _reference.escape).

The text is our own only: the strings of the upstream JSON cases, the
benchmark-column generator (_columns.py: names, invented clinical notes,
patient numbers), a few words written here, and characters drawn at
random. From these the script makes mix-ups between every two of the 13
codecs at one layer and at two, lossy variants, clean values, random
Unicode, strings of several lines and long lines.

Every draw is seeded, each part with its own generator, so a rerun gives
the same file byte for byte and a change to one part leaves the others as
they were. No input holds U+0000 or a surrogate, which an R string cannot
hold, and no input is there twice.

The reference version is not asked what it does with any input here; that
is corpus_snapshot.py. The script still stops unless it runs under the
reference interpreter, because the sloppy codecs and utf-8-variants are
that version's, and random.Random and the Unicode data are that
interpreter's.
"""

import html.entities
import json
import os
import random
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import REPO, escape, require_reference

require_reference()

import ftfy.bad_codecs  # noqa: F401  registers the sloppy codecs and utf-8-variants

import _columns
from _corpus import (
    CODECS,
    INPUT_COLUMNS,
    INPUTS_DIR,
    MAX_INPUTS,
    SINGLE_BYTE,
    age,
    age_ranges,
    check_ages,
    newest,
    storable,
)
from _xz import write_xz

SEED = 42
SLICE = "own"
# The cap of about 50,000 inputs is for every slice together. This slice
# stays below MAX_OWN, which leaves the outside-text slice (#45) at least
# 8,000 rows.
MAX_OWN = 42_000

# The variants, with the fewest rows each must have. The script stops if a
# variant has fewer, or if it makes a variant that is not listed.
VARIANTS = {
    "json-original": 150,  # the `original` of each upstream JSON case
    "json-fixed": 100,  # their `fixed` and `fixed-encoding` texts: clean
    "json-layer": 250,  # an original under one more layer of mix-up
    "clean": 2500,  # values that must come back unchanged
    "column": 2500,  # values of the benchmark columns, as they are
    "mixup-1": 7000,  # one layer: encoded with one codec, decoded with another
    "mixup-2": 5500,  # two layers
    "lossy-replaced": 800,  # undecodable bytes became U+FFFD
    "lossy-question": 350,  # ... or a question mark
    "lossy-a0-space": 700,  # the byte A0 became a space
    "lossy-dropped": 500,  # one character of a mix-up was lost
    "lossy-c1-stripped": 400,  # the C1 controls of a mix-up were lost
    "decoded-nul": 150,  # a mix-up of the two bytes C0 80
    "fuzz-assigned": 1800,  # random assigned characters
    "fuzz-mixed": 1800,  # ASCII words with characters the fixers look at
    "fuzz-bytes": 1800,  # random bytes read with a single-byte codec
    "fuzz-markup": 900,  # entities, "<", terminal escapes, controls
    "fuzz-new": 500,  # characters assigned in Unicode 11.0 to 15.1
    "multiline-note": 900,  # notes of several lines, clean or mixed up whole
    "multiline-mixed": 1800,  # each line made in its own way
    "multiline-markup": 450,  # entities, with "<" on some lines
    "multiline-cut-short": 350,  # lines ending in a sequence cut short
    "multiline-blank": 10,  # empty lines and line ends alone
    "long-line": 220,  # one line of 200 to 4,000 characters
    "long-lines": 130,  # several such lines
}


def U(*code_points):
    return "".join(chr(code_point) for code_point in code_points)


def rng_for(part):
    """A generator for one part of the corpus, seeded by its name."""
    return random.Random("%d:%s" % (SEED, part))


# ---------------------------------------------------------------- our text

# Words of our own that hold a character whose UTF-8 form has the byte A0,
# so that the mix-up holds a no-break space.
A0_WORDS = [
    "voil" + U(0xE0),
    "d" + U(0xE9) + "j" + U(0xE0),
    U(0xE0),
    U(0x420, 0x43E, 0x441, 0x441, 0x438, 0x44F),
    U(0x2020),
    "caf" + U(0xE9) + " " + U(0xE0) + " la carte",
    U(0x3A0, 0x3AC, 0x3C1, 0x3BF, 0x3C2),
]

# Characters outside the first plane, to join to names.
ASTRAL = [
    U(0x1F600), U(0x1F60A), U(0x1F44D), U(0x1F4A9), U(0x1F9D1), U(0x10348),
    U(0x1D11E), U(0x20000), U(0x1F1FA, 0x1F1F8),
    U(0x1F3F4, 0xE0067, 0xE0062, 0xE0077, 0xE006C, 0xE0073, 0xE007F),
]


def json_cases():
    path = os.path.join(REPO, "tests", "testthat", "upstream", "test_cases.json")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def all_names():
    return ["%s %s" % (first, last) for first in _columns.FIRST for last in _columns.LAST]


def note_lines(rng, count):
    return [
        " ".join(rng.choice(_columns.NOTE_WORDS) for _ in range(rng.randint(3, 20)))
        for _ in range(count)
    ]


def repertoire(codec):
    """The letters among the upper half of a single-byte codec."""
    out = []
    for byte in range(0xA0, 0x100):
        try:
            ch = bytes([byte]).decode(codec)
        except UnicodeDecodeError:
            continue
        if ch.isalpha():
            out.append(ch)
    return out


def repertoire_words(codec, rng, count):
    """Invented words in the letters of one codec."""
    letters = repertoire(codec)
    out = []
    for _ in range(count):
        words = []
        for _ in range(rng.randint(1, 3)):
            words.append(
                "".join(
                    rng.choice(letters) if rng.random() < 0.4 else rng.choice("aeinorst")
                    for _ in range(rng.randint(2, 9))
                )
            )
        out.append(" ".join(words))
    return out


def has_non_ascii(text):
    return not text.isascii()


class Sources:
    """The clean texts the mix-ups start from."""

    def __init__(self):
        rng = rng_for("sources")
        cases = json_cases()
        self.json_original = [case["original"] for case in cases]
        fixed = [case["fixed"] for case in cases]
        fixed += [case["fixed-encoding"] for case in cases if "fixed-encoding" in case]
        self.json_fixed = list(dict.fromkeys(fixed))
        self.names = all_names()
        self.lines = list(dict.fromkeys(note_lines(rng, 700)))
        self.words = {
            codec: list(dict.fromkeys(repertoire_words(codec, rng, 90)))
            for codec in SINGLE_BYTE
        }
        self.astral = [
            "%s %s" % (rng.choice(self.names), rng.choice(ASTRAL)) for _ in range(150)
        ] + [rng.choice(ASTRAL) + " " + rng.choice(self.lines) for _ in range(50)]
        self.a0 = [
            rng.choice(
                ["%s %s", "%s, %s", "%s. %s"]
            ) % ((word, other) if rng.random() < 0.5 else (other, word))
            for word in A0_WORDS
            for other in rng.sample(self.names, 12) + rng.sample(self.lines, 8)
        ] + list(A0_WORDS)
        everything = (
            self.names + self.lines + self.json_fixed + self.astral + self.a0
            + [word for codec in SINGLE_BYTE for word in self.words[codec]]
        )
        self.non_ascii = [text for text in dict.fromkeys(everything) if has_non_ascii(text)]
        self._by_codec = {}

    def for_codec(self, codec):
        """Texts with a character outside ASCII that the codec can encode."""
        if codec not in self._by_codec:
            if codec == "utf-8":
                found = self.non_ascii
            elif codec == "utf-8-variants":
                # This codec differs from utf-8 only on characters outside
                # the first plane (and U+0000, which no input holds).
                found = self.astral
            else:
                found = [text for text in self.non_ascii if can_encode(text, codec)]
            self._by_codec[codec] = found
        return self._by_codec[codec]


# ----------------------------------------------------------------- mix-ups


def can_encode(text, codec):
    try:
        text.encode(codec)
    except UnicodeEncodeError:
        return False
    return True


def cesu8(text):
    """UTF-8 as Java writes it: a character outside the first plane as its
    two surrogates, each in three bytes."""
    out = bytearray()
    for ch in text:
        code_point = ord(ch)
        if code_point > 0xFFFF:
            code_point -= 0x10000
            for half in (0xD800 + (code_point >> 10), 0xDC00 + (code_point & 0x3FF)):
                out += chr(half).encode("utf-8", errors="surrogatepass")
        else:
            out += ch.encode("utf-8")
    return bytes(out)


def encode(text, codec):
    """The bytes of the text in a codec. utf-8-variants encodes as utf-8 in
    the reference version; here it stands for the form only it decodes."""
    if codec == "utf-8-variants":
        return cesu8(text)
    return text.encode(codec)


def mix_up(text, encoder, decoder, errors="strict"):
    """The text encoded with one codec and decoded with another, or None
    when either cannot be done."""
    try:
        return encode(text, encoder).decode(decoder, errors=errors)
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None


def utf8_like(codec):
    return codec in ("utf-8", "utf-8-variants")


def one_layer(sources, rows):
    rng = rng_for("mixup-1")
    for encoder in CODECS:
        for decoder in CODECS:
            if encoder == decoder or (utf8_like(encoder) and utf8_like(decoder)):
                continue
            # UTF-8 read with a single-byte codec is the mix-up met most.
            wanted = 300 if encoder == "utf-8" else 40
            pool = sources.for_codec(encoder)
            detail = "%s>%s" % (encoder, decoder)
            made = replaced = 0
            for text in rng.sample(pool, min(len(pool), wanted * 4)):
                mixed = mix_up(text, encoder, decoder)
                if mixed is None:
                    if replaced < max(4, wanted // 5):
                        lossy = mix_up(text, encoder, decoder, errors="replace")
                        if lossy is not None and U(0xFFFD) in lossy:
                            rows.add("lossy-replaced", detail, lossy)
                            replaced += 1
                            if replaced % 3 == 0:
                                rows.add("lossy-question", detail, lossy.replace(U(0xFFFD), "?"))
                elif mixed != text and made < wanted:
                    made += rows.add("mixup-1", detail, mixed)
            if encoder not in SINGLE_BYTE or decoder not in SINGLE_BYTE:
                continue
            # Two single-byte codecs may differ on a few bytes only, which
            # our words need not hold: add words of random upper-half
            # bytes, on which the two differ somewhere.
            made = tries = 0
            while made < 12 and tries < 5000:
                tries += 1
                data = bytes(
                    rng.randint(0x80, 0xFF) if rng.random() < 0.4 else rng.choice(b"aeinorst ")
                    for _ in range(rng.randint(3, 12))
                )
                try:
                    if data.decode(encoder) != data.decode(decoder):
                        made += rows.add("mixup-1", detail, data.decode(decoder))
                except UnicodeDecodeError:
                    pass


def two_layers(sources, rows):
    rng = rng_for("mixup-2")
    # UTF-8 read with a single-byte codec, twice over.
    for first in SINGLE_BYTE:
        for second in SINGLE_BYTE:
            detail = "utf-8>%s>utf-8>%s" % (first, second)
            made = 0
            for text in rng.sample(sources.non_ascii, 120):
                once = mix_up(text, "utf-8", first)
                twice = None if once is None else mix_up(once, "utf-8", second)
                if twice is not None and made < 28:
                    made += rows.add("mixup-2", detail, twice)
    # Any four codecs.
    made = 0
    while made < 3000:
        chain = [rng.choice(CODECS) for _ in range(4)]
        if chain[0] == chain[1] or chain[2] == chain[3]:
            continue
        pool = sources.for_codec(chain[0])
        once = mix_up(rng.choice(pool), chain[0], chain[1])
        if once is None or not has_non_ascii(once):
            continue
        if chain[2] == "utf-8-variants" and not any(ord(ch) > 0xFFFF for ch in once):
            continue
        twice = mix_up(once, chain[2], chain[3])
        if twice is not None and twice != once:
            made += rows.add("mixup-2", ">".join(chain), twice)


def json_layers(sources, rows):
    for number, text in enumerate(sources.json_original):
        rows.add("json-original", "case %d" % number, text)
    for text in sources.json_fixed:
        rows.add("json-fixed", "", text)
    for number, text in enumerate(sources.json_original):
        for decoder in ("latin-1", "sloppy-windows-1252"):
            mixed = mix_up(text, "utf-8", decoder)
            if mixed is not None and mixed != text:
                rows.add("json-layer", "case %d, utf-8>%s" % (number, decoder), mixed)


def clean(sources, rows):
    rng = rng_for("clean")
    for text in sources.names:
        rows.add("clean", "name", text)
    for text in sources.lines[:500]:
        rows.add("clean", "note line", text)
    for _ in range(300):
        rows.add("clean", "patient", _columns.patient(rng))
    for codec in SINGLE_BYTE:
        for text in sources.words[codec][:60]:
            rows.add("clean", "letters of " + codec, text)
    for text in sources.astral[:120] + sources.a0:
        rows.add("clean", "", text)


def columns(rows):
    """Values of the benchmark columns, spread evenly over each."""
    for column in _columns.SPECS:
        values = _columns.distinct_values(column)
        wanted = 400
        step = max(1, len(values) // wanted)
        for value in values[::step][:wanted]:
            rows.add("column", column, value)


def lossy(sources, rows):
    rng = rng_for("lossy")
    # Read with strict windows-1252, whose five holes become U+FFFD.
    made = 0
    for text in rng.sample(sources.non_ascii, len(sources.non_ascii)):
        mixed = mix_up(text, "utf-8", "windows-1252", errors="replace")
        if U(0xFFFD) in mixed and made < 900:
            made += rows.add("lossy-replaced", "utf-8>windows-1252", mixed)
            if made % 2 == 0:
                rows.add("lossy-question", "utf-8>windows-1252", mixed.replace(U(0xFFFD), "?"))
    # The no-break space of a mix-up turned into a space.
    for decoder in SINGLE_BYTE:
        if bytes([0xA0]).decode(decoder, errors="replace") != U(0xA0):
            continue
        made = 0
        for text in rng.sample(sources.non_ascii, len(sources.non_ascii)):
            mixed = mix_up(text, "utf-8", decoder)
            if mixed is not None and U(0xA0) in mixed and made < 90:
                made += rows.add(
                    "lossy-a0-space", "utf-8>" + decoder, mixed.replace(U(0xA0), " ")
                )
    # One character lost, and the C1 controls lost.
    for decoder in SINGLE_BYTE:
        for text in rng.sample(sources.non_ascii, 70):
            mixed = mix_up(text, "utf-8", decoder)
            if mixed is None or mixed == text:
                continue
            marks = [at for at, ch in enumerate(mixed) if ord(ch) > 0x7F]
            at = rng.choice(marks)
            rows.add("lossy-dropped", "utf-8>" + decoder, mixed[:at] + mixed[at + 1 :])
    for decoder in ("latin-1", "sloppy-windows-1252", "sloppy-windows-1251", "iso-8859-2"):
        made = 0
        for text in rng.sample(sources.non_ascii, len(sources.non_ascii)):
            mixed = mix_up(text, "utf-8", decoder)
            if mixed is None:
                continue
            stripped = "".join(ch for ch in mixed if not 0x80 <= ord(ch) <= 0x9F)
            if stripped != mixed and made < 130:
                made += rows.add("lossy-c1-stripped", "utf-8>" + decoder, stripped)


def decoded_nul(sources, rows):
    """A text with U+0000 between its words, written with the two bytes
    C0 80 as Java does, and read with a single-byte codec. The input holds
    no U+0000; the reference version decodes one."""
    rng = rng_for("decoded-nul")
    for decoder in SINGLE_BYTE:
        for text in rng.sample(sources.names, 12) + rng.sample(sources.lines, 6):
            data = text.encode("utf-8").replace(b" ", b"\xc0\x80", rng.randint(1, 2))
            try:
                rows.add("decoded-nul", "C0 80, " + decoder, data.decode(decoder))
            except UnicodeDecodeError:
                pass


# -------------------------------------------------------------------- fuzz

# Characters the fixers and the badness heuristic look at.
INTERESTING = (
    [chr(cp) for cp in range(0x80, 0x100)]
    + [chr(cp) for cp in range(0x100, 0x180, 3)]
    + [chr(cp) for cp in range(0x2B0, 0x300, 5)]
    + [chr(cp) for cp in range(0x300, 0x370, 4)]
    + [chr(cp) for cp in range(0x391, 0x3CA, 2)]
    + [chr(cp) for cp in range(0x410, 0x450, 2)]
    + [chr(cp) for cp in range(0x2000, 0x2070)]
    + [chr(cp) for cp in range(0x20A0, 0x20C0, 2)]
    + [chr(cp) for cp in range(0x2100, 0x2140, 3)]
    + [chr(cp) for cp in range(0x2500, 0x25A0, 3)]
    + [chr(cp) for cp in range(0xFB00, 0xFB07)]
    + [chr(cp) for cp in range(0xFF01, 0xFFEF, 5)]
    + [U(0xFEFF), U(0xFFFD), U(0x3000), U(0x2028), U(0x2029), U(0x85), U(0x7F)]
    + [U(0x1100, 0x1161), U(0xAC00), U(0x4E16), U(0x1F600), U(0x212B), U(0xBD)]
    + [chr(cp) for cp in (1, 7, 8, 9, 0xB, 0xC, 0xD, 0xE, 0x1B, 0x1F)]
)
# Assigned characters only: what a later Unicode does with a code point
# that 15.1 left unassigned is not reference behaviour.
INTERESTING = [text for text in INTERESTING if all(age(ord(ch)) for ch in text)]
ASCII_WORDS = ["a", "the", "word", "I", "No", "it's", "e", "5", "?", "...", "ok", "Z"]


def assigned_ranges():
    """The ranges of the age table that an R string can hold a character
    of, without the private use and the unassigned-looking planes that
    would otherwise fill every draw."""
    out = []
    for first, last, _ in age_ranges():
        if first == 0:
            first = 1
        if 0xD800 <= first <= 0xDFFF:
            continue
        out.append((first, last))
    return out


def fuzz(rows):
    rng = rng_for("fuzz-assigned")
    ranges = assigned_ranges()
    for _ in range(2000):
        # A draw is of a range first, so that a small block is met as often
        # as the ideographs.
        text = "".join(
            chr(rng.randint(*rng.choice(ranges))) for _ in range(rng.randint(1, 20))
        )
        rows.add("fuzz-assigned", "", text)

    rng = rng_for("fuzz-mixed")
    for _ in range(2000):
        pieces = [
            rng.choice(INTERESTING) if rng.random() < 0.45 else rng.choice(ASCII_WORDS)
            for _ in range(rng.randint(1, 14))
        ]
        rows.add("fuzz-mixed", "", rng.choice(["", " "]).join(pieces))

    rng = rng_for("fuzz-bytes")
    made = 0
    while made < 2000:
        decoder = rng.choice(SINGLE_BYTE)
        if rng.random() < 0.5:
            # Bytes that are well-formed UTF-8 of random letters.
            data = "".join(
                chr(rng.choice([rng.randint(0xA0, 0x24F), rng.randint(0x370, 0x4FF),
                                rng.randint(0x2010, 0x2044), rng.randint(0x20, 0x7E)]))
                for _ in range(rng.randint(1, 12))
            ).encode("utf-8")
        else:
            data = bytes(rng.randint(1, 255) for _ in range(rng.randint(2, 24)))
        try:
            made += rows.add("fuzz-bytes", decoder, data.decode(decoder))
        except UnicodeDecodeError:
            pass

    rng = rng_for("fuzz-markup")
    names = sorted(html.entities.html5)
    for _ in range(1000):
        pieces = []
        for _ in range(rng.randint(1, 8)):
            draw = rng.random()
            if draw < 0.25:
                name = rng.choice(names)
                pieces.append("&" + (name.upper() if rng.random() < 0.1 else name))
            elif draw < 0.4:
                number = rng.choice(
                    [rng.randint(1, 0x2FF), rng.randint(0x80, 0x9F), rng.randint(0x2000, 0x2100),
                     0xD800, 0x110000, 0xFFFF, 0x1F600, 0]
                )
                pieces.append(rng.choice(["&#%d;", "&#x%x;", "&#X%X;", "&#%d"]) % number)
            elif draw < 0.5:
                pieces.append(rng.choice(["<", ">", "<b>", "</p>", "&", "&amp;amp;", ";"]))
            elif draw < 0.6:
                pieces.append(
                    U(0x1B) + rng.choice(["[0m", "[31;1m", "[1;2;3m", "[K", "[", "]0;t" + U(7), "[38;5;1m"])
                )
            elif draw < 0.7:
                pieces.append(rng.choice([U(0xD, 0xA), U(0xD), U(0x2028), U(0x2029), U(0x85), U(9), U(0xC)]))
            elif draw < 0.8:
                pieces.append(rng.choice(INTERESTING))
            else:
                pieces.append(rng.choice(ASCII_WORDS + [" "]))
        rows.add("fuzz-markup", "", "".join(pieces))

    # Characters newer than the oldest Unicode version stringi accepts
    # (10.0), among them the ones Unicode 15.0 gave a combining class or a
    # decomposition, so that the Unicode tag has rows to skip.
    rng = rng_for("fuzz-new")
    new = {}
    for first, last, found in age_ranges():
        if found >= (11, 0):
            new.setdefault(found, []).extend(range(first, last + 1))
    reordered = [
        cp for cp in new[(15, 0)]
        if unicodedata.combining(chr(cp)) or unicodedata.decomposition(chr(cp))
    ]
    assert len(reordered) >= 70, len(reordered)
    for found in sorted(new):
        for _ in range(60):
            pieces = [
                chr(rng.choice(new[found])) if rng.random() < 0.4
                else rng.choice(ASCII_WORDS + ["e" + U(0x301), U(0xE9), " "])
                for _ in range(rng.randint(2, 10))
            ]
            rows.add("fuzz-new", "%d.%d" % found, "".join(pieces))
    for _ in range(120):
        pieces = [
            chr(rng.choice(reordered)) if rng.random() < 0.4
            else rng.choice(["a", "q", "e" + U(0x301), U(0x301), U(0x323), " ", "x"])
            for _ in range(rng.randint(2, 8))
        ]
        rows.add("fuzz-new", "15.0, reordered or decomposed", "".join(pieces))


# ----------------------------------------------- several lines, long lines

MARKUP = [
    "&amp;", "&lt;", "&gt;", "&eacute;", "&#x201c;", "&amp;amp;", "&hellip;", "&nbsp;",
    "&EACUTE;", "&#233;", "&macr;", "<", "<b>", "</b>", "<html>", "a < b", "&",
]


def cut_short_tail(decoder, rng):
    """Characters that a codec encodes to the start of a UTF-8 sequence
    with its end missing: the byte C0, or five of the six bytes of a
    surrogate pair. A line that ends in them meets the departure
    utf8-variants-trailing-newline."""
    data = rng.choice([b"\xc0", b"\xc0", b"\xed\xa0\xbd\xed\xb8"])
    try:
        return data.decode(decoder)
    except UnicodeDecodeError:
        return None


def a_line(sources, rng):
    """One line and how it was made."""
    draw = rng.random()
    base = rng.choice(sources.lines if rng.random() < 0.6 else sources.names)
    if draw < 0.25:
        return base, "clean"
    if draw < 0.33:
        return rng.choice(_columns.NOTE_WORDS[:8]) + " " + _columns.patient(rng), "ascii"
    if draw < 0.65:
        decoder = rng.choice(SINGLE_BYTE)
        mixed = mix_up(base, "utf-8", decoder)
        if mixed is not None:
            return mixed, "utf-8>" + decoder
        return base, "clean"
    if draw < 0.72:
        once = mix_up(base, "utf-8", "sloppy-windows-1252")
        return mix_up(once, "utf-8", rng.choice(["sloppy-windows-1252", "latin-1"])), "two layers"
    if draw < 0.79:
        mixed = mix_up(rng.choice(sources.a0), "utf-8", "sloppy-windows-1252")
        return mixed.replace(U(0xA0), " "), "a0-space"
    if draw < 0.85:
        mixed = mix_up(rng.choice(sources.non_ascii), "utf-8", "windows-1252", errors="replace")
        return mixed, "replaced"
    if draw < 0.93:
        return base + " " + rng.choice(MARKUP) + " " + rng.choice(MARKUP + ["x"]), "markup"
    return rng.choice(INTERESTING) + base + rng.choice(INTERESTING), "interesting"


def join_lines(lines, rng):
    end = U(0xD, 0xA) if rng.random() < 0.1 else "\n"
    return end.join(lines) + (end if rng.random() < 0.5 else "")


def several_lines(sources, rows):
    rng = rng_for("multiline-note")
    for _ in range(500):
        rows.add("multiline-note", "clean", _columns.note(rng))
    made = 0
    while made < 600:
        text = _columns.note(rng)
        decoder = rng.choice(SINGLE_BYTE)
        mixed = mix_up(text, "utf-8", decoder)
        if mixed is not None and mixed != text:
            made += rows.add("multiline-note", "utf-8>" + decoder, mixed + rng.choice(["", "\n"]))

    rng = rng_for("multiline-mixed")
    for _ in range(2000):
        lines, kinds = zip(*[a_line(sources, rng) for _ in range(rng.randint(2, 6))])
        rows.add("multiline-mixed", ", ".join(kinds), join_lines(lines, rng))

    rng = rng_for("multiline-markup")
    for _ in range(500):
        lines = []
        for _ in range(rng.randint(2, 6)):
            pieces = [
                rng.choice(MARKUP) if rng.random() < 0.5
                else rng.choice(_columns.NOTE_WORDS + ["caf" + U(0xC3, 0xA9)])
                for _ in range(rng.randint(1, 5))
            ]
            lines.append(" ".join(pieces))
        rows.add("multiline-markup", "", join_lines(lines, rng))

    rng = rng_for("multiline-cut-short")
    made = 0
    while made < 400:
        decoder = rng.choice(SINGLE_BYTE)
        lines = []
        for _ in range(rng.randint(1, 4)):
            line = mix_up(rng.choice(sources.names + sources.lines), "utf-8", decoder)
            tail = cut_short_tail(decoder, rng)
            if line is None or tail is None:
                break
            lines.append(line + rng.choice([" ", ""]) + tail if rng.random() < 0.7 else line)
        else:
            end = rng.choice(["\n", "\n", "\n", ""])
            made += rows.add("multiline-cut-short", decoder, "\n".join(lines) + end)

    for text in ["", "\n", "\n\n\n", "\r\n", "\r\n\r\n\n\r", " \n ", "\n ", "a\n", "\na",
                 U(0xFEFF) + "\n" + U(0xFEFF), "\t\n\t", U(0x2028) + "\n" + U(0x85)]:
        rows.add("multiline-blank", "", text)


def a_long_line(sources, rng):
    words = []
    way = rng.choice(["clean", "whole", "words", "words", "markup"])
    for _ in range(rng.randint(30, 600)):
        word = rng.choice(_columns.NOTE_WORDS + _columns.FIRST + _columns.LAST)
        if way in ("words", "markup") and has_non_ascii(word) and rng.random() < 0.5:
            word = mix_up(word, "utf-8", rng.choice(SINGLE_BYTE[:10])) or word
        if way == "markup" and rng.random() < 0.05:
            word = rng.choice(MARKUP)
        words.append(word)
    line = " ".join(words)
    if way == "whole":
        line = mix_up(line, "utf-8", rng.choice(["sloppy-windows-1252", "latin-1", "macroman"]))
    return line, way


def long_lines(sources, rows):
    rng = rng_for("long")
    for _ in range(250):
        line, way = a_long_line(sources, rng)
        rows.add("long-line", way, line + rng.choice(["", "", "\n"]))
    for _ in range(150):
        lines, ways = zip(*[a_long_line(sources, rng) for _ in range(rng.randint(2, 4))])
        rows.add("long-lines", ", ".join(ways), join_lines(lines, rng))


# ------------------------------------------------------------------- write


class Rows:
    """The rows so far. A text is kept once, the first time it is added."""

    def __init__(self):
        self.rows = []
        self.seen = set()

    def add(self, variant, detail, text):
        assert variant in VARIANTS, variant
        if text is None or text in self.seen or not storable(text):
            return 0
        self.seen.add(text)
        self.rows.append((variant, detail, text))
        return 1


def main():
    check_ages()
    sources = Sources()
    rows = Rows()
    json_layers(sources, rows)
    clean(sources, rows)
    columns(rows)
    one_layer(sources, rows)
    two_layers(sources, rows)
    lossy(sources, rows)
    decoded_nul(sources, rows)
    fuzz(rows)
    several_lines(sources, rows)
    long_lines(sources, rows)

    counts = {}
    for variant, _, _ in rows.rows:
        counts[variant] = counts.get(variant, 0) + 1
    for variant in VARIANTS:
        print("%6d %s" % (counts.get(variant, 0), variant))
    print("%6d rows" % len(rows.rows))
    for variant, least in VARIANTS.items():
        assert counts.get(variant, 0) >= least, (variant, counts.get(variant, 0), least)
    assert len(rows.rows) <= MAX_OWN <= MAX_INPUTS, len(rows.rows)
    # Every mix-up between two of the 13 codecs is there, at one layer,
    # but for the pairs that cannot give one: a single-byte codec's bytes
    # are seldom UTF-8 (those rows are among the lossy ones), and strict
    # and sloppy windows-1252 agree on every byte the strict one decodes.
    pairs = {detail for variant, detail, _ in rows.rows if variant == "mixup-1"}
    same = {"windows-1252", "sloppy-windows-1252"}
    for encoder in CODECS:
        for decoder in CODECS:
            if encoder == decoder or (utf8_like(encoder) and utf8_like(decoder)):
                continue
            if (encoder in SINGLE_BYTE and utf8_like(decoder)) or {encoder, decoder} == same:
                continue
            assert "%s>%s" % (encoder, decoder) in pairs, (encoder, decoder)

    lines = ["\t".join(INPUT_COLUMNS) + "\n"]
    for number, (variant, detail, text) in enumerate(rows.rows, start=1):
        assert "\t" not in detail and detail.isascii()
        fields = [str(number), SLICE, variant, detail, newest([text]), escape(text)]
        lines.append("\t".join(fields) + "\n")
    assert not any(line.split("\t")[4] == "unassigned" for line in lines)
    write_xz("%s/%s.tsv.xz" % (INPUTS_DIR, SLICE), "".join(lines))


main()
