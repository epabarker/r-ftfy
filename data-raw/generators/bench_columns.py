# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the benchmark columns to bench/columns/.

- bench/columns/columns.tsv: one line for each column, tab separated:
  `column`, `n` (the number of values), `distinct` (the number of distinct
  values), `clean` (the fraction of the distinct values that is not a
  mix-up, as asked of the generator), `seed`, `kind` (what a value is:
  name, patient or note), `characters` (in the distinct values, in all)
  and `md5` (of the uncompressed text of the column's file).
- bench/columns/<column>.txt.xz: the distinct values of the column in the
  order they were drawn, one to a line, escaped (see _reference.escape; a
  note holds line ends, written \\u000A).

The column itself is the distinct values recycled to `n`: value i is the
distinct value (i - 1) mod `distinct`, counted from 1. In R:

    values <- stringi::stri_unescape_unicode(readLines(xzfile(path)))
    column <- rep_len(values, n)

The distinct values are those of the prototype's columns.py (same
specifications, same seeds). The prototype shuffled the recycled values; a
shuffle is left out so that the committed file holds each value once and
the column can be rebuilt without Python. The order of a column does not
change what is measured: the speed target is per value with deduplication
not counted (ADR 0008).

Nothing is read from the reference version: the values come from
_columns.py alone. The script still stops unless it runs under the
reference interpreter, because random.Random and the sloppy codecs that
make the mix-ups are that interpreter's.
"""

import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

import ftfy.bad_codecs  # noqa: F401  registers the sloppy codecs

import _columns
from _xz import write_xz


def main():
    header = ["column", "n", "distinct", "clean", "seed", "kind", "characters", "md5"]
    lines = ["\t".join(header) + "\n"]
    for column, (n, clean, unique, gen) in _columns.SPECS.items():
        seed = _columns.seed_of(column)
        values = _columns.distinct_values(column)
        assert len(set(values)) == len(values) == max(1, int(n * unique))
        assert not any("\x00" in value for value in values)
        text = "".join(escape(value) + "\n" for value in values)
        write_xz("bench/columns/%s.txt.xz" % column, text)
        fields = [
            column, n, len(values), clean, seed, gen.__name__,
            sum(map(len, values)), hashlib.md5(text.encode("ascii")).hexdigest(),
        ]
        lines.append("\t".join(str(field) for field in fields) + "\n")
    write_ascii("bench/columns/columns.tsv", "".join(lines))


main()
