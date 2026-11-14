# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""What the generators of the larger corpus share. Not a generator.

The corpus is under tests/corpus/, kept out of the built package:

    tests/corpus/inputs/<slice>.tsv.xz     the inputs of one slice
    tests/corpus/snapshot/<slice>.tsv.xz   what the reference version gives

corpus_inputs.py writes the slice `own`, built from our own text.
corpus_snapshot.py writes one snapshot for every inputs file it finds, so
another slice is added by committing its inputs file and nothing else.

An inputs file has the columns `id` (1, 2, ... in file order), `slice`,
`variant`, `detail`, `unicode` and `text` (escaped, see _reference.escape).
"""

import bisect
import glob
import os
import unicodedata

from _reference import REPO, escape
from _xz import read_xz

INPUTS_DIR = "tests/corpus/inputs"
SNAPSHOT_DIR = "tests/corpus/snapshot"
INPUT_COLUMNS = ["id", "slice", "variant", "detail", "unicode", "text"]

# The caps of the resolution of #14, over every slice together.
MAX_INPUTS = 50_000
MAX_BYTES = 20_000_000

# The 13 codecs of the package (plan_codecs in R/plan-names.R), under the
# names the reference version gives them in a plan.
SINGLE_BYTE = [
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
    "windows-1252",
]
CODECS = SINGLE_BYTE + ["utf-8", "utf-8-variants"]


# The Unicode version in which a code point was assigned. The reference
# interpreter has no such property, so it is read from a committed copy of
# the Unicode Character Database's DerivedAge.txt for Unicode 15.1.

UNASSIGNED = "unassigned"
_AGES = None


def _load_ages():
    firsts, lasts, ages = [], [], []
    path = os.path.join(REPO, "data-raw", "unicode", "age.txt")
    with open(path, encoding="ascii") as handle:
        lines = [line for line in handle.read().splitlines() if not line.startswith("#")]
    assert lines[0] == "first\tlast\tage", lines[0]
    for line in lines[1:]:
        first, last, age = line.split("\t")
        major, minor = age.split(".")
        firsts.append(int(first, 16))
        lasts.append(int(last, 16))
        ages.append((int(major), int(minor)))
    assert firsts == sorted(firsts)
    assert all(a <= b for a, b in zip(firsts, lasts))
    assert all(b < a for a, b in zip(firsts[1:], lasts))
    return firsts, lasts, ages


def age_ranges():
    """(first, last, (major, minor)) for every range of the age table."""
    global _AGES
    if _AGES is None:
        _AGES = _load_ages()
    return list(zip(*_AGES))


def age(code_point):
    """(major, minor) of the version that assigned the code point, or None
    for a code point that Unicode 15.1 has not assigned."""
    global _AGES
    if _AGES is None:
        _AGES = _load_ages()
    firsts, lasts, ages = _AGES
    at = bisect.bisect_right(firsts, code_point) - 1
    if at >= 0 and code_point <= lasts[at]:
        return ages[at]
    return None


def check_ages():
    """Stop unless the age table agrees with the reference interpreter on
    which code points are assigned, and with its Unicode 3.2 data on which
    were assigned by then."""
    assert unicodedata.unidata_version == "15.1.0"
    old = unicodedata.ucd_3_2_0
    for code_point in range(0x110000):
        found = age(code_point)
        noncharacter = 0xFDD0 <= code_point <= 0xFDEF or code_point & 0xFFFE == 0xFFFE
        assigned = unicodedata.category(chr(code_point)) != "Cn" or noncharacter
        assert (found is not None) == assigned, hex(code_point)
        if found is not None:
            assert (1, 1) <= found <= (15, 1), hex(code_point)
        if old.category(chr(code_point)) != "Cn":
            assert found is not None and found <= (3, 2), hex(code_point)


_NEWEST = {}


def newest(texts):
    """The newest Unicode version among the characters of the texts, as
    "major.minor", or "unassigned" when one of them is not assigned in
    Unicode 15.1."""
    best = (1, 1)
    for text in texts:
        for ch in set(text):
            found = _NEWEST.get(ch)
            if found is None:
                found = _NEWEST[ch] = age(ord(ch)) or (99, 0)
            if found > best:
                best = found
    return UNASSIGNED if best == (99, 0) else "%d.%d" % best


def storable(text):
    """Whether an R string can hold the text: no U+0000 and no surrogate."""
    return "\x00" not in text and not any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def unescape(field):
    """The text of an escaped field (the inverse of _reference.escape)."""
    return field.encode("ascii").decode("unicode_escape")


def inputs_files():
    """Every committed inputs file, as (slice, path from the repo root), in
    slice order."""
    found = sorted(glob.glob(os.path.join(REPO, *INPUTS_DIR.split("/"), "*.tsv.xz")))
    return [
        (os.path.basename(path)[: -len(".tsv.xz")], INPUTS_DIR + "/" + os.path.basename(path))
        for path in found
    ]


def read_inputs(relative_path):
    """The rows of an inputs file, as dictionaries, `text` unescaped."""
    lines = read_xz(relative_path).split("\n")
    assert lines[-1] == "" and lines[0].split("\t") == INPUT_COLUMNS, relative_path
    rows = []
    for line in lines[1:-1]:
        row = dict(zip(INPUT_COLUMNS, line.split("\t")))
        assert len(row) == len(INPUT_COLUMNS) and escape(unescape(row["text"])) == row["text"]
        row["text"] = unescape(row["text"])
        rows.append(row)
    return rows
