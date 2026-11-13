# data-raw

Everything the package takes from the reference version (ftfy 6.3.1 on Python 3.13) is generated here in two stages. Nothing in this directory is shipped in the package.

## Stage 1: Python writes committed text files

```
python -m pip install --require-hashes --no-deps -r data-raw/requirements.txt
python data-raw/regenerate.py
```

`regenerate.py` runs every script in `generators/` whose name does not start with an underscore, in name order. Each script stops unless it is running under the reference version. The outputs are ASCII-only text files, committed and never edited by hand. The docstring at the top of each script names the file it writes and what it reads from the reference version:

- `pattern_*.py` writes one ICU pattern to `patterns/<NAME>.txt`. Python's `\s`, `\w` and `\d` are written in as the code-point sets observed on CPython 3.13 (Unicode 15.1). A bytes pattern is written over the code points U+0000 to U+00FF, to match a byte string held as text with byte `b` as the character U+00`b`. The translator, `_icu.py`, raises an error on any construct it has not been taught. `snapshot_pattern_spans.py` writes the span fixture, which holds where each pattern matches in the reference version; a new pattern must be added to it.
- `snapshot_*.py` writes one snapshot of reference behaviour to `tests/testthat/reference/`.
- `codec_<name>.py` writes one codec table to `codecs/<name>.txt`: each of the 256 bytes with the code point the reference version decodes it to, or `hole`. A new codec is a copy of `codec_latin-1.py` with the name changed.
- `table_<name>.py` writes one data table of the text fixers to `tables/<name>.txt`: the named HTML entities, the ligatures, the width map and the control characters, each read from the reference version, with every character written as its code point in hexadecimal. `table_html_numeric.py` probes the reference version's `unescape_html()` with the numeric reference for every number and writes, as ranges, only the numbers that do not give the character with that number.

The `reference` workflow runs the two commands above and fails if any committed file changes.

To add a generated file, add one script to `generators/` that writes one file. Nothing lists the scripts, so there is nothing else to edit. Shared code goes in a file whose name starts with an underscore.

## Stage 2: R builds internal package data

```
Rscript data-raw/build.R
```

`build.R` runs every script in `sysdata/` and saves the objects they define to `R/sysdata.rda`, then rebuilds `NAMESPACE` and `man/` with roxygen2. It needs no Python. `Rscript data-raw/build.R --check` fails if `R/sysdata.rda` does not match its sources.

`sysdata/patterns.R` reads every file in `patterns/` into the internal vector `patterns`, and `sysdata/codecs.R` reads every file in `codecs/` into the internal list `codec_tables`. Neither lists its files. `sysdata/tables.R` reads the five files in `tables/` into `html_entities`, `html_numeric`, `ligatures`, `width_map` and `control_chars`. Only decode tables are shipped: the encode side of each codec is built from its table when the package is loaded.

`R/sysdata.rda`, `NAMESPACE` and `man/` are never edited or merged by hand. On a merge conflict in any of them, take either side and run `build.R`.

## The upstream JSON cases and the not-yet-passing list

`tests/testthat/upstream/test_cases.json` is upstream's file, byte for byte. `generators/snapshot_json_cases.py` reads it and writes what the reference version gives for each case to `tests/testthat/reference/json_cases.tsv`.

`tests/testthat/not-yet-passing.txt` names every check on those cases that the package cannot pass yet, one line per check and case index. The list may only shrink. When a change makes listed checks pass, the test fails until they are removed; remove them with:

```
FTFY_SHRINK_NOT_YET_PASSING=true Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-json-cases.R")'
```

This only deletes lines. Never add a line by hand. The file merges with git's union driver, so two branches that delete different lines do not conflict; after any merge that touches it, run the command above and commit the result.

## The departure registry

`inst/departures/` holds one file per departure, `<id>.dcf`, with the fields `Id`, `Title`, `Input`, `Reference`, `R` and `Decided`. Each entry also has `tests/testthat/test-departure-<id>.R`, which asserts R's behaviour, and `tests/testthat/departures/<id>.R`, the function that says whether a difference from a snapshot is this departure. All three are found by name; nothing lists them.
