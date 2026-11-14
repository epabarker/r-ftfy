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

- `bench_columns.py` writes the benchmark columns to `bench/columns/`: a list, `columns.tsv`, and the distinct values of each column in `<column>.txt.xz`. The values come from `_columns.py`.
- `corpus_inputs.py` writes the inputs of the larger corpus that are built from our own text to `tests/corpus/inputs/own.tsv.xz`, and `corpus_snapshot.py` writes what the reference version gives for every inputs file there to `tests/corpus/snapshot/<slice>.tsv.xz`. The docstring of each says what its columns are. Another slice of inputs is another file in `tests/corpus/inputs/`. Neither `bench/` nor `tests/corpus/` is in the built package.
- `corpus_inputs_outside.py` writes the slice of outside natural-language text, `tests/corpus/inputs/outside.tsv.xz`, from the committed values in `outside/values.tsv.xz` (see below). It downloads nothing.

## Outside text

`outside/` holds the outside text of the larger corpus (ticket #45), under the licence rule of the resolution of #15. `outside/SOURCES` names each source with its version, licence and attribution; `outside/pins.tsv` gives the URL and SHA-256 of every file read from them; `outside/values.tsv.xz` is the values selected, committed; `outside/variants.tsv` lists the variants of the slice with the fewest rows of each, read by both the generator and the tests. The languages and the codecs each is mixed up with are in `generators/_outside.py`, which the selection and the generator both import. The selection script is the only thing here that downloads, and it is run by a maintainer, never by the `reference` workflow:

```
python data-raw/outside/select.py --downloads <empty directory outside the repo>
```

It stops, writing nothing, if any downloaded file's checksum is not the one pinned. With `--pin` it downloads every file again and rewrites `pins.tsv`, which is how a source is moved to a new version; review what it downloaded before committing. The Project Gutenberg files are not versioned, so when one is rebuilt upstream its checksum fails and it must be pinned again. Once `values.tsv.xz` changes, run `regenerate.py` to rebuild the slice and its snapshot.

A script that reads a file another script writes has a comment line `# Runs after: <script>.py`, and `regenerate.py` runs it after that script; otherwise the order is by name. One run always suffices.

The files ending in `.xz` are ASCII text compressed with fixed settings (`_xz.py`); R reads them with `xzfile()`. A file that already holds the text to be written is left as it is, so that the bytes do not depend on the version of the compressor.

`unicode/age.txt` is not generated: it is the Unicode Character Database's `DerivedAge-15.1.0.txt` without its comments, from which the corpus rows are tagged with the newest Unicode version among their characters. The reference interpreter has no such property; `_corpus.py` checks the table against the Unicode data it does have.

The `reference` workflow runs the two commands above and fails if any committed file changes.

To add a generated file, add one script to `generators/` that writes one file. Nothing lists the scripts, so there is nothing else to edit. Shared code goes in a file whose name starts with an underscore.

## Stage 2: R builds internal package data

```
Rscript data-raw/build.R
```

`build.R` runs every script in `sysdata/` and saves the objects they define to `R/sysdata.rda`, writes the "differences from Python ftfy" help page to `R/differences.R`, then rebuilds `NAMESPACE` and `man/` with roxygen2. It needs no Python. `Rscript data-raw/build.R --check` fails if `R/sysdata.rda` or `R/differences.R` does not match its sources.

The differences page is written by `differences.R` from the departure registry, `inst/departures/`: one section for each `<id>.dcf`, found by listing. To change what the page says about a departure, edit its entry and run `build.R`; a new entry needs nothing else. The help topic is `ftfy-differences` (`man/ftfy-differences.Rd`).

`sysdata/patterns.R` reads every file in `patterns/` into the internal vector `patterns`, and `sysdata/codecs.R` reads every file in `codecs/` into the internal list `codec_tables`. Neither lists its files. `sysdata/tables.R` reads the five files in `tables/` into `html_entities`, `html_numeric`, `ligatures`, `width_map` and `control_chars`. Only decode tables are shipped: the encode side of each codec is built from its table when the package is loaded.

`R/sysdata.rda`, `R/differences.R`, `NAMESPACE` and `man/` are never edited or merged by hand. On a merge conflict in any of them, take either side and run `build.R`.

## The upstream JSON cases

`tests/testthat/upstream/test_cases.json` is upstream's file, byte for byte. `generators/snapshot_json_cases.py` reads it and writes what the reference version gives for each case to `tests/testthat/reference/json_cases.tsv`. Every check on every case passes (`tests/testthat/test-json-cases.R`); there is no list of checks that may fail.

## The departure registry

`inst/departures/` holds one file per departure, `<id>.dcf`, with the fields `Id`, `Title`, `Input`, `Reference`, `R` and `Decided`. Each entry also has `tests/testthat/test-departure-<id>.R`, which asserts R's behaviour, and `tests/testthat/departures/<id>.R`, the function that says whether a difference from a snapshot is this departure. All three are found by name; nothing lists them.
