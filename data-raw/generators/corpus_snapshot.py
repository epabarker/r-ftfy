# Derived from python-ftfy v6.3.1, ftfy/__init__.py, ftfy/fixes.py and ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
# Runs after: corpus_inputs.py
"""Write the snapshot of the larger corpus: for every inputs file
tests/corpus/inputs/<slice>.tsv.xz, what the reference version gives for
each input, to tests/corpus/snapshot/<slice>.tsv.xz, row for row.

Columns, tab separated, one row for each input in the order of the inputs
file:

- id: the id of the input.
- unicode: the newest Unicode version among the characters of the input
  and of every text in this row, as "major.minor", or "unassigned" when
  one of them is not assigned in Unicode 15.1. A row is comparable only
  when the Unicode version of the running ICU is at least this, and never
  when it is "unassigned".
- badness: ftfy.badness.badness(text), an integer.
- is_bad: ftfy.badness.is_bad(text), TRUE or FALSE.
- fixer.<name>, for each of the nine fixers in FIXERS: ftfy.fixes.<name>(text).
- fix_text.default: ftfy.fix_text(text).
- fix_text.<variant>, for each variant in VARIANTS and LENGTHS:
  ftfy.fix_text(text, TextFixerConfig(<the options of the variant>)).
- fix_text.keyword_no_<option>, for each of the four options of the
  encoding repair: ftfy.fix_text(text, <option>=False), the option given
  as a keyword argument.
- fix_and_explain.default, fix_and_explain.default.plan: the text and the
  plan of ftfy.fix_and_explain(text); fix_and_explain.<variant> and
  fix_and_explain.<variant>.plan the same with
  TextFixerConfig(<the options of the variant>), for each variant in
  VARIANTS.
- fix_encoding_and_explain.*: the same columns for
  ftfy.fix_encoding_and_explain().
- apply_plan.fix_and_explain, apply_plan.fix_encoding_and_explain:
  ftfy.apply_plan(text, plan) with the plan of the default column of that
  function.

The form of the options. Every variant column is the TextFixerConfig
form. The reference version does not pass the four options of the
encoding repair on when they are given to fix_text() as keyword arguments
(ftfy/__init__.py:341 and :396; the departure
encoding-sub-options-honoured), so the keyword form is kept apart in the
fix_text.keyword_no_<option> columns. For every other option and for the
other two functions the two forms are the same call. upstream has a
thirteenth boolean option, fix_surrogates, which the package does not
have; the script stops if switching it off changes any result.

How a cell is written. A text cell is one of

    (empty)        the same text as the base of its column
    =<text>        this text, escaped (see _reference.escape); "=" alone
                   is the empty text
    !<type>: <message>   the reference version raised this exception
                   (escaped in the same way)

The base of a fixer column, of fix_text.default, fix_and_explain.default
and fix_encoding_and_explain.default is the input. The base of every
other fix_text column is fix_text.default, and of every other column of
the two explaining functions the default column of the same function.
The base of an apply_plan column is the default text of its function, so
an empty cell there says that the replay gave that text. When the base
is itself an exception, a cell is never empty.

A plan cell is the plan in its text form ("encode latin-1 > decode
utf-8", or "none" for no steps), or empty for the same plan as the
default plan column of the same function (which is never empty), or
"!<type>: <message>" where the call raised.

A text that holds U+0000 is written like any other, with \\u0000 in it;
R cannot hold that text, so its reader leaves such a cell escaped
(notes/33-codecs.md). The script stops if a result holds a surrogate.

Everything here is a pure function of the inputs files, so a rerun gives
the same files byte for byte.
"""

import multiprocessing
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import REPO, escape, plan_text, require_reference, storable

require_reference()

import ftfy
import ftfy.badness
import ftfy.fixes

from _corpus import (
    MAX_BYTES,
    MAX_INPUTS,
    SNAPSHOT_DIR,
    check_ages,
    inputs_files,
    newest,
    read_inputs,
)
from _xz import write_xz

FIXERS = [
    "unescape_html",
    "remove_terminal_escapes",
    "uncurl_quotes",
    "fix_latin_ligatures",
    "fix_character_width",
    "fix_line_breaks",
    "remove_control_chars",
    "decode_inconsistent_utf8",
    "fix_c1_controls",
]

# The boolean options the package has: upstream's thirteen without
# fix_surrogates. unescape_html is "auto" by default; off is False.
BOOLEANS = [
    "unescape_html",
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
SUB_OPTIONS = BOOLEANS[3:7]

ALL_OFF = dict({option: False for option in BOOLEANS}, normalization=None)
VARIANTS = (
    [("no_" + option, {option: False}) for option in BOOLEANS]
    + [("normalization_NULL", {"normalization": None}), ("all_off", ALL_OFF)]
)
# Small values of max_decode_length, which only fix_text() reads: every
# line longer than this is cut, so that no megabyte string is needed.
LENGTHS = [
    ("max_decode_length_10", {"max_decode_length": 10}),
    ("max_decode_length_60", {"max_decode_length": 60}),
]
EXPLAINING = ["fix_and_explain", "fix_encoding_and_explain"]

HEADER = (
    ["id", "unicode", "badness", "is_bad"]
    + ["fixer." + name for name in FIXERS]
    + ["fix_text.default"]
    + ["fix_text." + name for name, _ in VARIANTS + LENGTHS]
    + ["fix_text.keyword_no_" + option for option in SUB_OPTIONS]
    + [
        "%s.%s%s" % (fun, name, suffix)
        for fun in EXPLAINING
        for name in ["default"] + [name for name, _ in VARIANTS]
        for suffix in ("", ".plan")
    ]
    + ["apply_plan." + fun for fun in EXPLAINING]
)

CONFIGS = {
    name: ftfy.TextFixerConfig(**options) for name, options in VARIANTS + LENGTHS
}
NO_SURROGATES = ftfy.TextFixerConfig(fix_surrogates=False)


class Raised:
    """An exception the reference version raised, in place of a result."""

    def __init__(self, error):
        self.cell = "!" + escape("%s: %s" % (type(error).__name__, error))

    def __eq__(self, other):
        return isinstance(other, Raised) and other.cell == self.cell


def call(fun, *args, **kwargs):
    try:
        return fun(*args, **kwargs)
    except Exception as error:  # noqa: BLE001  every exception is a result
        return Raised(error)


def explained(fun, *args):
    """(text, plan) of an explaining function, or the exception twice."""
    result = call(fun, *args)
    if isinstance(result, Raised):
        return result, result
    text, plan = result
    return text, plan_text(plan)


def text_cell(value, base):
    if isinstance(value, Raised):
        return value.cell
    if not isinstance(value, str):
        # apply_plan() returns bytes for a plan that ends in "encode"; no
        # plan the reference version makes does.
        raise TypeError("not a text: %r" % (value,))
    if not isinstance(base, Raised) and value == base:
        return ""
    return "=" + escape(value)


def plan_cell(value, base):
    if isinstance(value, Raised):
        return value.cell
    if base is not None and value == base:
        return ""
    return value


def snapshot_row(row):
    """The fields of one row, and what the checks in main() count."""
    text = row["text"]
    texts = [text]
    differs = {}

    def keep(value):
        if isinstance(value, str):
            texts.append(value)
        return value

    fields = [row["id"], None, str(ftfy.badness.badness(text))]
    fields.append("TRUE" if ftfy.badness.is_bad(text) else "FALSE")
    assert int(fields[2]) >= 0 and (fields[3] == "TRUE") == (int(fields[2]) > 0)

    for name in FIXERS:
        fields.append(text_cell(keep(call(getattr(ftfy.fixes, name), text)), text))
        differs["fixer." + name] = fields[-1] != ""

    default = keep(call(ftfy.fix_text, text))
    assert default == call(ftfy.fix_text, text, ftfy.TextFixerConfig())
    assert default == call(ftfy.fix_text, text, NO_SURROGATES), "fix_surrogates acts"
    fields.append(text_cell(default, text))
    for name, _ in VARIANTS + LENGTHS:
        fields.append(text_cell(keep(call(ftfy.fix_text, text, CONFIGS[name])), default))
        differs["fix_text." + name] = fields[-1] != ""
    for option in SUB_OPTIONS:
        result = keep(call(ftfy.fix_text, text, **{option: False}))
        fields.append(text_cell(result, default))
        differs["fix_text.keyword_no_" + option] = fields[-1] != ""

    plans = {}
    for fun in EXPLAINING:
        function = getattr(ftfy, fun)
        fixed, plan = explained(function, text)
        keep(fixed)
        plans[fun] = (fixed, plan)
        if fun == "fix_and_explain":
            assert (fixed, plan) == explained(function, text, NO_SURROGATES), "fix_surrogates acts"
        fields += [text_cell(fixed, text), plan_cell(plan, None)]
        for name, _ in VARIANTS:
            other, other_plan = explained(function, text, CONFIGS[name])
            keep(other)
            fields += [text_cell(other, fixed), plan_cell(other_plan, plan)]
            differs["%s.%s" % (fun, name)] = fields[-1] != "" or fields[-2] != ""

    steps = set()
    for fun in EXPLAINING:
        fixed, plan = plans[fun]
        if isinstance(plan, Raised):
            fields.append(plan.cell)
            continue
        pairs = [] if plan == "none" else [tuple(step.split(" ")) for step in plan.split(" > ")]
        steps.update(pairs)
        fields.append(text_cell(keep(call(ftfy.apply_plan, text, pairs)), fixed))
        differs["apply_plan." + fun] = fields[-1] != ""

    assert all(storable(value.replace("\x00", "")) for value in texts), "a surrogate"
    fields[1] = newest(texts)
    assert len(fields) == len(HEADER)
    raised = sum(field.startswith("!") for field in fields[4:])
    nul = any("\x00" in value for value in texts)
    return "\t".join(fields) + "\n", differs, steps, raised, nul, fields[1] != row["unicode"]


def main():
    check_ages()
    files = inputs_files()
    assert files, "no inputs file under tests/corpus/inputs/"
    total = 0
    with multiprocessing.Pool(min(8, os.cpu_count() or 1)) as pool:
        for slice_name, path in files:
            rows = read_inputs(path)
            assert [row["id"] for row in rows] == [str(n) for n in range(1, len(rows) + 1)]
            assert all(row["slice"] == slice_name for row in rows), path
            total += len(rows)
            results = pool.map(snapshot_row, rows, chunksize=200)
            lines = ["\t".join(HEADER) + "\n"] + [result[0] for result in results]
            differing = {}
            steps = set()
            for _, differs, row_steps, _, _, _ in results:
                steps |= row_steps
                for name, differed in differs.items():
                    differing[name] = differing.get(name, 0) + differed
            print("slice %s: %d rows" % (slice_name, len(rows)))
            print("  rows with an exception: %d" % sum(result[3] > 0 for result in results))
            print("  rows with U+0000 in a result: %d" % sum(result[4] for result in results))
            print("  rows tagged newer than their input: %d" % sum(result[5] for result in results))
            print("  rows that differ from the base of the column:")
            for name in HEADER:
                if name in differing:
                    print("  %8d %s" % (differing[name], name))
            print("  steps: " + ", ".join(sorted("%s %s" % step for step in steps)))
            if slice_name == "own":
                check_own(differing, steps)
            write_xz("%s/%s.tsv.xz" % (SNAPSHOT_DIR, slice_name), "".join(lines))
    assert total <= MAX_INPUTS, total

    # Nothing but the inputs and their snapshots, and all of it under the cap.
    size = 0
    for kind in ("inputs", "snapshot"):
        directory = os.path.join(REPO, "tests", "corpus", kind)
        found = sorted(os.listdir(directory))
        assert found == ["%s.tsv.xz" % slice_name for slice_name, _ in files], (kind, found)
        size += sum(os.path.getsize(os.path.join(directory, name)) for name in found)
    assert size <= MAX_BYTES, size
    print("%d inputs, %d bytes under tests/corpus/" % (total, size))


def check_own(differing, steps):
    """Stop unless our own slice shows what it is there to show."""
    for name in FIXERS:
        assert differing["fixer." + name] >= 100, name
    for name, _ in VARIANTS + LENGTHS:
        assert differing["fix_text." + name] >= 100, name
        if name in CONFIGS and not name.startswith("max_"):
            assert differing["fix_and_explain." + name] >= 100, name
    # The encoding-only function reads the options of the encoding repair
    # and no other.
    for name, _ in VARIANTS:
        reads = name in ["no_fix_encoding", "all_off"] + ["no_" + o for o in SUB_OPTIONS]
        count = differing["fix_encoding_and_explain." + name]
        assert (count >= 100) if reads else (count == 0), (name, count)
    wanted = {("normalize", "NFC"), ("decode", "utf-8"), ("decode", "utf-8-variants")}
    # Steps of the default plans. "apply fix_c1_controls" is recorded only
    # with fix_encoding off, so it is not among them.
    wanted |= {("apply", name) for name in FIXERS if name != "fix_c1_controls"}
    wanted |= {("transcode", name) for name in ("restore_byte_a0", "replace_lossy_sequences", "fix_c1_controls")}
    wanted.add(("decode", "windows-1252"))
    wanted |= {("encode", codec) for codec in (
        "latin-1", "sloppy-windows-1252", "sloppy-windows-1251", "sloppy-windows-1250",
        "sloppy-windows-1253", "sloppy-windows-1254", "sloppy-windows-1257",
        "iso-8859-2", "macroman", "cp437",
    )}
    assert wanted <= steps, sorted(wanted - steps)


if __name__ == "__main__":
    main()
