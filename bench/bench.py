"""The reference version's side of the benchmark (issue #46). Run by
bench/bench.R; see bench/README.md for what is timed.

    python bench/bench.py info
    python bench/bench.py run --column C --function F --scope S
                              --reps N --out DIR

`info` prints the interpreter's versions, one `key<TAB>value` to a line.

`run` reads the distinct values of one committed benchmark column
(bench/columns/C.txt.xz, checked against the md5 in columns.tsv), and times
the list comprehension `[ftfy.F(value) for value in values]`:

- scope `distinct`: `values` is the distinct values, each once;
- scope `full`: `values` is the whole column, the distinct values recycled
  to the column's n (value i is distinct value i mod distinct).

Before any timing the comprehension runs once, untimed, on the distinct
values: that is the warm-up, and its result is written to
DIR/C.F.output.txt (escaped, one value to a line) for R to compare with its
own. Every timed repetition must give that same result. The times go to
DIR/C.F.S.seconds.txt, one to a line.

Only the comprehension is between the two clock readings. Reading the
file, building the column and a garbage collection before each repetition
are outside them.
"""

import argparse
import gc
import hashlib
import os
import platform
import sys
import time
import unicodedata

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "data-raw", "generators"))

from _reference import escape, require_reference  # noqa: E402

require_reference()

import ftfy  # noqa: E402

from _xz import read_xz  # noqa: E402

FUNCTIONS = {"fix_text": ftfy.fix_text, "fix_encoding": ftfy.fix_encoding}


def columns_table():
    path = os.path.join(REPO, "bench", "columns", "columns.tsv")
    with open(path, encoding="ascii") as handle:
        lines = handle.read().split("\n")
    header = lines[0].split("\t")
    return {
        fields[0]: dict(zip(header, fields))
        for fields in (line.split("\t") for line in lines[1:] if line)
    }


def distinct_values(column):
    """The distinct values of a committed column, and its n."""
    row = columns_table()[column]
    text = read_xz("bench/columns/%s.txt.xz" % column)
    found = hashlib.md5(text.encode("ascii")).hexdigest()
    if found != row["md5"]:
        sys.exit("%s: md5 %s, columns.tsv says %s" % (column, found, row["md5"]))
    lines = text.split("\n")
    assert lines[-1] == ""
    values = [line.encode("ascii").decode("unicode_escape") for line in lines[:-1]]
    assert len(values) == int(row["distinct"]) == len(set(values))
    assert all(escape(value) == line for value, line in zip(values, lines))
    return values, int(row["n"])


def run(args):
    function = FUNCTIONS[args.function]
    distinct, n = distinct_values(args.column)

    # The warm-up, and the result R is compared with.
    output = [function(value) for value in distinct]

    if args.scope == "distinct":
        values, expected = distinct, output
    else:
        k = len(distinct)
        values = [distinct[i % k] for i in range(n)]
        expected = [output[i % k] for i in range(n)]

    seconds = []
    for _ in range(args.reps):
        gc.collect()
        start = time.perf_counter()
        result = [function(value) for value in values]
        end = time.perf_counter()
        seconds.append(end - start)
        if result != expected:
            sys.exit("%s: a repetition gave another result" % args.column)

    stem = os.path.join(args.out, "%s.%s" % (args.column, args.function))
    with open(stem + ".output.txt", "w", encoding="ascii", newline="\n") as handle:
        handle.write("".join(escape(value) + "\n" for value in output))
    with open(stem + ".%s.seconds.txt" % args.scope, "w", encoding="ascii") as handle:
        handle.write("".join("%.9f\n" % value for value in seconds))


def info():
    fields = [
        ("python", platform.python_version()),
        ("implementation", platform.python_implementation()),
        ("ftfy", ftfy.__version__),
        ("unicode", unicodedata.unidata_version),
    ]
    sys.stdout.write("".join("%s\t%s\n" % field for field in fields))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("info")
    run_parser = commands.add_parser("run")
    run_parser.add_argument("--column", required=True)
    run_parser.add_argument("--function", required=True, choices=sorted(FUNCTIONS))
    run_parser.add_argument("--scope", required=True, choices=["distinct", "full"])
    run_parser.add_argument("--reps", required=True, type=int)
    run_parser.add_argument("--out", required=True)
    args = parser.parse_args()
    if args.command == "info":
        info()
    else:
        run(args)


if __name__ == "__main__":
    main()
