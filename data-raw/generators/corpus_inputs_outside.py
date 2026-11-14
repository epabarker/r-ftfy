# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
# Runs after: corpus_inputs.py
"""Write the inputs of the larger corpus that are built from outside text
to tests/corpus/inputs/outside.tsv.xz (ticket #45).

The text is the committed values of data-raw/outside/values.tsv.xz, which
data-raw/outside/select.py selected from the sources named in
data-raw/outside/SOURCES. This script reads only that file and our own
slice; it downloads nothing.

Columns as in corpus_inputs.py:

- id: 1, 2, ... in file order.
- slice: "outside" on every row.
- variant: one of VARIANTS below.
- detail: "<source> <language> <kind>" of the value the row was made
  from, then, for a row that is not clean, ", " and the codecs of its
  mix-up, as "utf-8>sloppy-windows-1253" for text encoded with the first
  and decoded with the second.
- unicode: the newest Unicode version among the characters of the input.
- text: the input, escaped (see _reference.escape).

Every value is there as it is, as a clean row. Each is also mixed up
through the codecs of its language: UTF-8 read with the single-byte codec
of the language's region, as text of that language is most often
damaged, and now and then with another; and some at two layers, or with
undecodable bytes replaced by U+FFFD, or with the no-break space of the
mix-up turned into a space. No input is there twice, nor is any input of
our own slice.

Every draw is seeded, so a rerun gives the same file byte for byte. The
script stops unless it runs under the reference interpreter, because the
sloppy codecs are that version's.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, storable

require_reference()

import ftfy.bad_codecs  # noqa: E402,F401  registers the sloppy codecs

from _corpus import INPUT_COLUMNS, INPUTS_DIR, MAX_INPUTS, check_ages, newest, read_inputs, unescape  # noqa: E402
from _xz import read_xz, write_xz  # noqa: E402

SEED = 45
SLICE = "outside"
VALUES = "data-raw/outside/values.tsv.xz"
# The slice "own" may grow to 42,000 rows (corpus_inputs.py), so this one
# stays at or below the rest of the cap of 50,000.
MAX_OUTSIDE = 8_000

VARIANTS = {
    "clean": 2000,  # a value as the source has it
    "mixup-1": 2000,  # one layer: encoded with UTF-8, decoded with another codec
    "mixup-2": 500,  # two layers
    "lossy-replaced": 150,  # undecodable bytes became U+FFFD
    "lossy-a0-space": 50,  # the byte A0 of a mix-up became a space
}

WESTERN = ["sloppy-windows-1252", "latin-1"]
WESTERN_OTHER = ["windows-1252", "macroman", "cp437"]
# The codecs a language's text is most often read with by mistake, and
# the others it is sometimes read with.
REGIONS = [
    (("fr", "de", "es", "it", "pt", "nl", "sv", "da", "no", "fi", "is"), WESTERN, WESTERN_OTHER),
    (("pl", "cs", "hu", "ro", "hr", "sk", "sl"), ["sloppy-windows-1250", "iso-8859-2"], WESTERN),
    (("ru", "uk", "bg", "sr"), ["sloppy-windows-1251"], WESTERN),
    (("el",), ["sloppy-windows-1253"], WESTERN),
    (("tr",), ["sloppy-windows-1254"], WESTERN),
    (("lt", "lv", "et"), ["sloppy-windows-1257"], WESTERN),
    (("ja", "zh", "ko", "ar", "he", "und"), WESTERN, ["macroman", "sloppy-windows-1251"]),
]
CODECS_OF = {language: (main, other) for languages, main, other in REGIONS for language in languages}


def mix_up(text, encoder, decoder, errors="strict"):
    """The text encoded with one codec and decoded with another, or None
    when either cannot be done."""
    try:
        return text.encode(encoder).decode(decoder, errors=errors)
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None


def read_values():
    lines = read_xz(VALUES).split("\n")
    assert lines[0] == "source\tlanguage\tkind\ttext" and lines[-1] == "", VALUES
    out = []
    for line in lines[1:-1]:
        source, language, kind, text = line.split("\t")
        out.append(("%s %s %s" % (source, language, kind), language, unescape(text)))
    return out


class Rows:
    """The rows so far. A text is kept once, the first time it is added,
    and never when our own slice has it."""

    def __init__(self, taken):
        self.rows = []
        self.seen = set(taken)

    def add(self, variant, detail, text):
        assert variant in VARIANTS, variant
        if text is None or text in self.seen or not storable(text):
            return 0
        self.seen.add(text)
        self.rows.append((variant, detail, text))
        return 1


def build(values, rows):
    for detail, _, text in values:
        rows.add("clean", detail, text)

    rng = random.Random("%d:mixup-1" % SEED)
    for detail, language, text in values:
        main, other = CODECS_OF[language]
        codec = rng.choice(main)
        rows.add("mixup-1", "%s, utf-8>%s" % (detail, codec), mix_up(text, "utf-8", codec))
        if rng.random() < 0.4:
            codec = rng.choice(other)
            rows.add("mixup-1", "%s, utf-8>%s" % (detail, codec), mix_up(text, "utf-8", codec))
        if rng.random() < 0.1 and main[0] != "sloppy-windows-1252":
            # Text in the region's own single-byte codec, read as Western.
            legacy, decoder = main[0], rng.choice(WESTERN)
            mixed = mix_up(text, legacy, decoder)
            if mixed != text:
                rows.add("mixup-1", "%s, %s>%s" % (detail, legacy, decoder), mixed)

    rng = random.Random("%d:mixup-2" % SEED)
    for detail, language, text in values:
        if rng.random() >= 0.25:
            continue
        first = rng.choice(CODECS_OF[language][0])
        second = rng.choice([first] + WESTERN)
        once = mix_up(text, "utf-8", first)
        twice = None if once is None else mix_up(once, "utf-8", second)
        rows.add("mixup-2", "%s, utf-8>%s>utf-8>%s" % (detail, first, second), twice)

    rng = random.Random("%d:lossy" % SEED)
    made = 0
    for detail, _, text in rng.sample(values, len(values)):
        mixed = mix_up(text, "utf-8", "windows-1252", errors="replace")
        if "\ufffd" in mixed and made < 400:
            made += rows.add("lossy-replaced", detail + ", utf-8>windows-1252", mixed)
    made = 0
    for detail, _, text in rng.sample(values, len(values)):
        mixed = mix_up(text, "utf-8", "sloppy-windows-1252")
        if mixed is not None and "\xa0" in mixed and made < 200:
            made += rows.add(
                "lossy-a0-space", detail + ", utf-8>sloppy-windows-1252", mixed.replace("\xa0", " ")
            )


def main():
    check_ages()
    own = read_inputs("%s/own.tsv.xz" % INPUTS_DIR)
    rows = Rows(row["text"] for row in own)
    build(read_values(), rows)

    counts = {}
    for variant, _, _ in rows.rows:
        counts[variant] = counts.get(variant, 0) + 1
    for variant in VARIANTS:
        print("%6d %s" % (counts.get(variant, 0), variant))
    print("%6d rows" % len(rows.rows))
    for variant, least in VARIANTS.items():
        assert counts.get(variant, 0) >= least, (variant, counts.get(variant, 0), least)
    assert len(rows.rows) <= MAX_OUTSIDE and len(rows.rows) + len(own) <= MAX_INPUTS, len(rows.rows)

    lines = ["\t".join(INPUT_COLUMNS) + "\n"]
    for number, (variant, detail, text) in enumerate(rows.rows, start=1):
        assert "\t" not in detail and detail.isascii()
        fields = [str(number), SLICE, variant, detail, newest([text]), escape(text)]
        assert fields[4] != "unassigned", detail
        lines.append("\t".join(fields) + "\n")
    write_xz("%s/%s.tsv.xz" % (INPUTS_DIR, SLICE), "".join(lines))


main()
