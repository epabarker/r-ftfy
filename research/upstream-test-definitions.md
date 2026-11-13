# How upstream's tests define a pass (ftfy v6.3.1)

Research for issue #3. Feeds #7 (v0.1 public surface), #14 (test harness and CI comparison) and #17 (vendoring).

## Source and method

- Source: `https://github.com/rspeer/python-ftfy`, tag `v6.3.1`, commit `5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3`. All `path:line` citations below are to that commit.
- Method: the source was read, not run. Nothing from upstream was imported, executed or installed. JSON counts come from parsing `tests/test_cases.json` with the Python standard library; doctest counts come from parsing docstrings with `ast` and `doctest.DocTestParser`, without importing the modules.
- Consequence: every count of "passing" and "failing" cases here is **declared** by upstream's data, not **observed** by running Python. See "What was not verified".
- pytest behaviour is cited from the pytest 8.3 docs (upstream pins `pytest >= 8.3.2, < 9`, `pyproject.toml:33`).

## Short answer

1. `tests/test_cases.json` is one JSON array of 161 objects. Each has `label`, `original`, `fixed`, `expect`; 33 also have `fixed-encoding`; 60 also have `comment`.
2. `expect` is the only marker. It is `"pass"` on 151 records and `"fail"` on 10. There is no other skip or known-wrong mechanism.
3. A pass case must satisfy seven assert statements, six of them distinct, covering `fix_text`, `fix_encoding_and_explain`, plan replay through `apply_plan`, a config-disabled `fix_text`, and a re-mojibaked input.
4. A fail case is a strict expected failure of one assertion only: the encoding-only fix must *not* equal the expected text. The file does not record what Python actually outputs for those 10.
5. There is no unit-test file for width or for files. Width is tested only by doctests in `ftfy/formatting.py`. `fix_file` is tested only through the command-line tests.
6. Upstream has no CI workflow that runs the tests; the only workflow publishes to PyPI.

## The JSON case file

File facts:

| Fact | Value |
| --- | --- |
| Path | `tests/test_cases.json` |
| Size | 48,962 bytes, 1,061 lines when split on LF |
| SHA-256 | `73aeefd7b405af501da79b4ca510f183becd6a289bfad90b499578a9450ad681` |
| Encoding | UTF-8, no BOM, LF line endings, no trailing newline |
| Top level | one array of 161 objects |
| Raw non-ASCII characters | 2,153 (most text is literal UTF-8, not escaped) |

Fields (all values are strings):

| Field | Present on | Meaning | Source |
| --- | --- | --- | --- |
| `label` | 161 | Human-readable name | `tests/test_examples_in_json.py:16` |
| `original` | 161 | Input text | `:17` |
| `fixed` | 161 | Expected `fix_text` output | `:18` |
| `expect` | 161 | `"pass"` or `"fail"` | `:38-39`, `:44` |
| `fixed-encoding` | 33 | Expected encoding-only output; defaults to `fixed` when absent | `:22-23`, `:85`, `:101` |
| `comment` | 60 | Free-text commentary, never read by the runner | `:24` |

Format quirks:

- The runner's docstring (`tests/test_examples_in_json.py:14-24`) documents every field except `expect`, and still says "nosetests". The code at `:38-44` is the only definition of `expect`.
- Key order in the file is always `label`, `comment`?, `original`, `fixed-encoding`?, `fixed`, `expect`.
- Labels are not unique, and `parametrize` is called without `ids=` (`:42`, `:47`, `:92`), so pytest identifies cases by position, not by label.
- One record is duplicated in full: array index 7 (line 46) and index 10 (line 64) are identical. So there are 161 records but 160 distinct cases, and 151 pass records but 150 distinct pass cases.
- JSON escapes in the raw file are `\"` (33), `\\` (4) and `\uXXXX` (many). The `\u` escapes are used mainly for invisible characters: U+00A0, U+00AD, C1 controls U+0080 to U+009F, U+001A, and U+FFFD.

### Counts by kind

Indexes are 0-based positions in the array.

| Kind | pass | fail |
| --- | --- | --- |
| Records | 151 | 10 |
| Has `fixed-encoding` | 33 | 0 |
| `fixed-encoding` differs from `fixed` | 29 | 0 |
| Has `comment` | 52 | 8 |
| `original == fixed` (text must be left alone) | 37 | 1 |
| `original ==` effective encoding fix | 48 | 1 |

Among the 151 pass records:

- 37 are "negative" cases where `fix_text` must return the input unchanged.
- 81 have no `fixed-encoding` and `original != fixed`, so the encoding-only fix must already equal the full fix.
- 11 have a `fixed-encoding` equal to `original`: the encoding step must do nothing while other fixers change the text.
- Labels containing "synthetic" (case-insensitive): 35 of 161. Labels containing "negative": 45 of 161.

### Characters that appear in the cases

| Feature | In `original` | In `fixed` / `fixed-encoding` |
| --- | --- | --- |
| NUL (U+0000) | none | none |
| Lone surrogates | none | none |
| LF, CR, TAB | none | none |
| Other C0 control | 2 pass cases (U+001A; indexes 141, 142 at lines 920, 928) | same 2, in `fixed-encoding` |
| C1 controls U+0080 to U+009F | 20 pass, 4 fail | 1 pass |
| U+00A0 | 13 pass, 1 fail | 7 pass, 1 fail |
| U+FFFD | 11 pass | 14 pass |
| Astral (above U+FFFF) | none | 4 pass |
| Not NFC-normalised | none | none |
| `<` | 1 pass | |
| `&` | 2 pass | |

- 96 of 151 pass originals contain a codepoint above U+00FF; only 1 is pure ASCII. Longest original is 533 codepoints. No original is empty.
- Because no original contains `\n`, the JSON cases never exercise `fix_text`'s line segmentation (`ftfy/__init__.py:346-361`).

## What the runner asserts

Runner: `tests/test_examples_in_json.py`. It imports `apply_plan`, `fix_and_explain`, `fix_encoding_and_explain`, `fix_text` from `ftfy` (`:32`).

### All 161 records: well-formedness (`:42-44`)

`expect` must be `"pass"` or `"fail"`. Nothing else about the record is checked.

### The 151 pass records: `test_json_example` (`:47-89`)

With `orig = original` and `fixed = fixed`, in order:

| # | Line | Assertion |
| --- | --- | --- |
| 1 | 54 | `fix_text(orig) == fixed` |
| 2 | 58-59 | `fix_and_explain(orig)` returns `(fixed_output, plan)`; `apply_plan(orig, plan) == fixed_output` |
| 3 | 62-63 | `fix_encoding_and_explain(orig)` returns `(encoding_fix, plan)`; `apply_plan(orig, plan) == encoding_fix` |
| 4 | 67-81 | `fix_text(orig, ...nine options off...) == encoding_fix` |
| 5 | 84 | `fix_text(orig) == fixed` again (exact repeat of 1) |
| 6 | 85 | `encoding_fix == fixed-encoding`, or `== fixed` when the field is absent |
| 7 | 88-89 | `fix_text(extra_bad) == fixed`, where `extra_bad = orig.encode("utf-8").decode("latin-1")` |

Details that matter for a port:

- **Assertion 2 and 3 are self-consistency checks only.** The plan is never compared with any expected plan. The JSON file contains no expected plans. `fixed_output` from `fix_and_explain` is also never compared with `fixed`; only its replay is.
- **Assertion 4** turns off `unescape_html`, `remove_terminal_escapes`, `fix_character_width`, `fix_latin_ligatures`, `uncurl_quotes`, `fix_line_breaks`, `fix_surrogates`, `remove_control_chars`, and sets `normalization=None` (`:70-78`). It leaves on, by default, `fix_encoding`, `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8` and `fix_c1_controls` (`ftfy/__init__.py:214-218`). To replicate the check, the R port must be able to turn off those nine options individually.
- **The four encoding sub-options are ignored when explanations are off.** With `explain=False`, `fix_and_explain` calls `fix_encoding(text)` without passing the config (`ftfy/__init__.py:394-396`). `fix_text` and `fix_text_segment` default to `explain=False` (`:341`, `:617`), so on that path `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8` and `fix_c1_controls` inside the encoding fixer always take their defaults. `fix_encoding=False` is still honoured (`:394`). Source-derived, not observed; no upstream test covers it.
- **Assertion 7** maps each UTF-8 byte of the input to the codepoint U+00NN, including the C1 range U+0080 to U+009F. It demands that one extra layer of UTF-8-read-as-Latin-1 mojibake is always undone, for all 151 cases, including the 37 that must otherwise be left unchanged.
- `fix_text` and `fix_and_explain` treat `unescape_html="auto"` as off when the segment contains `<` (`ftfy/__init__.py:356-357`, `:380-381`). One pass original contains `<`.

### The 10 fail records: `test_failing_json_example` (`:92-101`)

- Decorated `@pytest.mark.xfail(strict=True)` with no `raises=` (`:93`).
- Body: `encoding_fix, plan = fix_encoding_and_explain(orig)`; `assert encoding_fix == test_case.get("fixed-encoding", fixed)` (`:100-101`).
- Nothing else is asserted. `fix_text`, plan replay and the extra-mojibake check are not run for fail cases.
- None of the 10 has `fixed-encoding`, so the comparison is always against `fixed`.

pytest semantics (pytest 8.3 docs, "How to use skip and xfail"): by default neither XFAIL nor XPASS fails the suite; `strict=True` "will make XPASS ('unexpectedly passing') results from this test to fail the test suite". With no `raises=`, the docs do not restrict which exception counts, so a case counts as an expected failure whether the comparison is false or the call raises.

So `expect: "fail"` means exactly: *in Python, the encoding-only fix of `original` is not equal to `fixed`*. If Python ever starts producing `fixed`, upstream's suite goes red until the record is flipped to `"pass"`.

The 10 fail records (index, line of the opening brace):

| Index | Line | What it is (short description based on the upstream label) |
| --- | --- | --- |
| 51 | 323 | Synthetic incomplete UTF-8 / Windows-1252 mix-up in Arabic |
| 61 | 386 | Two levels of inconsistent mojibake |
| 107 | 696 | Spanish with C1 quote characters |
| 108 | 703 | Vietnamese a-with-grave |
| 110 | 716 | Latin-1 / MacRoman mix-up in Spanish |
| 111 | 723 | UTF-8 / codepage 437 mix-up in Spanish |
| 112 | 729 | Latin-1 / MacRoman mix-up, two characters |
| 113 | 736 | a-with-grave in Windows-1251 needing a bolder heuristic |
| 123 | 802 | Italian UTF-8 / MacRoman mojibake that looks like maths |
| 158 | 1040 | Synthetic false positive: `original == fixed`, so Python must be *changing* text it should leave alone |

Two consequences:

- **The fail records give a port no target output.** They say what Python does not produce. Matching Python on these 10 requires output captured from Python itself.
- **Index 107 probably cannot unexpectedly pass.** Its `fixed` has straight ASCII quotes, but the assertion checks the encoding-only fix, and straightening quotes is a separate fixer (`uncurl_quotes`, run at `ftfy/__init__.py:406`, not inside `_fix_encoding_one_step_and_explain` at `:468-583`). This is inferred from the source, not observed.

### Plans: what can appear and what can be replayed

- Plan steps are `(action, parameter)` pairs. `apply_plan` accepts the actions `encode`, `decode`, `transcode` and `apply`, and raises `ValueError` for anything else (`ftfy/__init__.py:752-763`).
- `fix_and_explain` can also emit a `("normalize", <form>)` step when normalisation changes the text (`ftfy/__init__.py:414-417`). `apply_plan` has no branch for `normalize`.
- So a plan containing a normalise step cannot be replayed by upstream's own `apply_plan`. Assertion 2 would raise for any pass case that triggered one. No pass `original` or `fixed` is non-NFC, which is consistent with none triggering it, but intermediate text was not checked. Source-derived, not observed.
- `fix_c1_controls` is recorded with action `transcode` inside the encoding fixer (`:573`) but with action `apply` when run as a top-level fixer (`:284`, `:403`). `apply_plan` treats the two actions identically (`:757`).
- The only tests that pin exact plan contents are one unit test (`tests/test_characters.py:49-56`) and two doctest examples (`ftfy/__init__.py:437-444`).

## Unit-test files and the surface they cover

Upstream declares no `__all__` anywhere in `ftfy/`. The nearest thing to a public-surface definition is what the Sphinx docs pull in: `fix_text`, `fix_and_explain`, `fix_encoding_and_explain`, `fix_encoding`, `ExplainedText`, `apply_plan`, `explain_unicode` (`docs/explain.rst:44-73`), `TextFixerConfig` (`docs/config.rst:27`), `guess_bytes` (`docs/detect.rst:22`), thirteen named `ftfy.fixes` members (`docs/fixes.rst:4-9`), `ftfy.badness.badness` and `is_bad` (`docs/heuristic.rst:9-10`), and the three `ftfy.bad_codecs` modules (`docs/bad_encodings.rst:4-12`). `ftfy.formatting` and `fix_file` are not in any autodoc directive; the command line has its own page (`docs/cli.rst`).

| Test file | Lines | Test functions (pytest items) | What it imports and exercises |
| --- | --- | --- | --- |
| `tests/test_examples_in_json.py` | 101 | 3 functions (161 + 151 + 10 = 322 items) | `fix_text`, `fix_and_explain`, `fix_encoding_and_explain`, `apply_plan` |
| `tests/test_bytes.py` | 50 | 3 functions (5 + 1 + 1 = 7 items) | `guess_bytes`; `ftfy.bad_codecs.utf8_variants.IncrementalDecoder` |
| `tests/test_characters.py` | 56 | 7 | `fix_encoding`, `fix_text`, `fix_and_explain`; `ftfy.chardata.possible_encoding`; `ftfy.fixes.fix_surrogates`, `remove_control_chars` |
| `tests/test_cli.py` | 66 | 6 | the installed `ftfy` executable, by subprocess; `tests/face.txt` |
| `tests/test_encodings.py` | 20 | 2 | `ftfy.bad_codecs.search_function`; Python's `bytes.decode` with the `cesu8` and `utf-8-variants` codecs; `guess_bytes` |
| `tests/test_entities.py` | 45 | 2 | `fix_text`, `fix_text_segment`; `ftfy.fixes.unescape_html`; the deprecated `fix_entities` keyword |

Mapping to the surfaces named in the issue:

| Surface | Covered by | Notes |
| --- | --- | --- |
| Bytes (`guess_bytes`, codecs) | `test_bytes.py`, `test_encodings.py`, doctests in `ftfy/bad_codecs/*.py` | See per-file notes |
| Files (`fix_file`) | no test file | Reached only indirectly, through `ftfy/cli.py:127` in `test_cli.py` |
| Command line | `test_cli.py` | Needs `ftfy` installed on `PATH` |
| Entities | `test_entities.py`, doctests of `unescape_html` | |
| Characters | `test_characters.py`, doctests in `ftfy/fixes.py` | |
| Width | no test file | Doctests in `ftfy/formatting.py` only |
| Core fixing | `test_examples_in_json.py`, doctests in `ftfy/__init__.py` | |

### Per-file notes

`tests/test_bytes.py`

- `test_guess_bytes` (`:17-27`), 5 strings × 3 encodings (`utf-16`, `utf-8`, `sloppy-windows-1252`): encode, then `guess_bytes` must return both the original string and the same encoding name. For strings containing `\n`, a MacRoman round trip with `\r` is also checked, text only.
- `test_guess_bytes_null` (`:30-34`): bytes `C0 80` must decode to a string containing U+0000, with encoding name `utf-8-variants`.
- `test_incomplete_sequences` (`:37-50`): feeds a 29-byte string to the incremental decoder in two pieces, for split offsets 0 to 23; the result must contain an astral character and U+0000. The loop bound is the length of the 23-character expected string (`:43`), not of the byte string, so the splits fall inside the CESU-8 surrogate sequence but never inside the final `C0 80`. This tests a Python codec class, not a top-level function.

`tests/test_characters.py`

- `possible_encoding` accepts every character U+0000 to U+00FF as `latin-1` (`:10-13`).
- `fix_encoding` turns the three-character UTF-8 BOM mojibake into U+FEFF (`:16-17`).
- `remove_control_chars` exact output on a mixed string, and leaves emoji tag sequences alone (`:20-33`).
- `fix_text` leaves an unusual flag tag sequence unchanged (`:36-41`).
- `fix_surrogates` joins two lone surrogate code units into one astral character (`:44-46`). The inputs are strings containing lone surrogates.
- `fix_and_explain` returns an exact two-step plan for a terminal-escape input (`:49-56`).

`tests/test_cli.py`

- Fixture `tests/face.txt`: 35 bytes, SHA-256 `f757109c2693a04bd0c58babd9fa2513cdea7faae63e283eaa82670cdd55fd60`.
- Six cases: plain file argument, `-g`, `-e sloppy-windows-1252`, `-e windows-1252` (must exit non-zero), same input and output file (must exit non-zero), and standard input.
- Output is compared as a whole, including the trailing line separator (`os.linesep`, `:9`).
- The wrong-encoding case compares the full error text, which embeds Python's own codec error message, "'charmap' codec can't decode byte 0x9d in position 4: character maps to <undefined>" (`:10-22`, `:52`). That sentence is produced by CPython, not by ftfy.
- Command-line options are defined at `ftfy/cli.py:53-91`: `filename`, `-o`, `-g`, `-e`, `-n`, `--preserve-entities`. Only `-g`, `-e`, `-o` and standard input are tested.

`tests/test_encodings.py`

- `cesu8` and `cesu-8` resolve to the same codec class; a CESU-8 byte string decodes to an astral character plus U+0000 (`:4-11`).
- A Windows-1251 Russian byte string must not crash `utf-8-variants` decoding or `guess_bytes`; the result is not checked (`:14-20`).

`tests/test_entities.py`

- 23 assertions in one function (`:7-37`) on `fix_text`, `fix_text_segment` and `unescape_html`: the `<` rule for `"auto"`, explicit `unescape_html=True/False`, upper-case entity names, numeric entities in the C1 range, out-of-range numeric entities, and text that is not an entity.
- `:9-10` is the only place the difference between `fix_text` (per-line segments) and `fix_text_segment` (one segment) is tested.
- `test_old_parameter_name` (`:40-45`) requires a `DeprecationWarning` for `fix_entities=`.

### Doctests are part of the suite

`pytest.ini:2` sets `addopts = --doctest-modules --ignore=setup.py --ignore=specimens --ignore=scripts --ignore=docs`. So a plain `pytest` run also collects doctests from module docstrings. Per the pytest docs, text files are only collected if they match `test*.txt`, so `README.md` and `docs/*.rst` are not doctested.

22 docstrings contain examples, 66 examples in total, none marked skip:

| Module | Docstrings with examples | Examples | Subjects |
| --- | --- | --- | --- |
| `ftfy/__init__.py` | 5 | 14 | `fix_text` (`:290`), `fix_encoding_and_explain` (`:424`), `fix_encoding` (`:586`), `apply_plan` (`:727`), `explain_unicode` (`:768`) |
| `ftfy/fixes.py` | 9 | 25 | `unescape_html` (`:94`), `remove_terminal_escapes` (`:145`), `uncurl_quotes` (`:158`), `fix_latin_ligatures` (`:168`), `fix_character_width` (`:186`), `fix_line_breaks` (`:206`), `fix_surrogates` (`:274`), `remove_bom` (`:330`), `decode_escapes` (`:355`) |
| `ftfy/formatting.py` | 5 | 17 | `character_width` (`:16`), `monospaced_width` (`:37`), `display_ljust` (`:79`), `display_rjust` (`:113`), `display_center` (`:142`) |
| `ftfy/bad_codecs/__init__.py` | 1 | 2 | module docstring |
| `ftfy/bad_codecs/sloppy.py` | 1 | 5 | module docstring |
| `ftfy/bad_codecs/utf8_variants.py` | 1 | 3 | module docstring |

Notes:

- Width has two meanings upstream. `fix_character_width` (`ftfy/fixes.py:186`) converts fullwidth and halfwidth characters and is part of `fix_text`. `ftfy/formatting.py` measures display width and depends on the third-party `wcwidth` package (`ftfy/formatting.py:11`, `pyproject.toml:8`). Its expected values are whatever the installed `wcwidth` returns.
- `explain_unicode` is tested only by its doctest, which pins Unicode character names, categories and display padding (`ftfy/__init__.py:776-788`).
- Functions with no direct test of their own: `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8`, `fix_c1_controls`, `badness`, `is_bad`. They are exercised only indirectly, mainly through the JSON cases. `fix_file` also has no direct test and is reached only through the command-line tests.

### Derived size of a full upstream run

322 (JSON runner) + 24 (other test files) + 22 (doctests) = 368 pytest items, of which 10 are expected failures. This is counted from the source, not from a run, and assumes `ftfy` and `wcwidth` are installed.

## How upstream runs its tests

- `tox.ini:1-8`: environments `py39` to `py313`, dependencies `pytest` and `wcwidth`, command `pytest`.
- `pyproject.toml:9`: `requires-python = ">=3.9"`. `pyproject.toml:33`: `pytest >= 8.3.2, < 9`.
- `.github/workflows/publish.yml` is the only workflow. It triggers on `v*` tags, builds and publishes to PyPI, and runs no tests.
- There is no `conftest.py`.

So nothing in the repository proves that the suite was green at the tag. The claim "151 pass and 10 fail in Python" rests on the maintainer having run it locally.

## What was not verified

- That all 151 pass records actually pass, and all 10 fail records actually fail, on Python ftfy 6.3.1. Nothing was run.
- What Python outputs for the 10 fail records.
- Whether results depend on the Python version. `fix_and_explain` calls `unicodedata.normalize` (`ftfy/__init__.py:415`), and `ftfy/chardata.py:11` imports `unicodedata`, so the Unicode data version of the interpreter is an input. Issue #5 covers this.
- Whether any pass case emits a `normalize` plan step.
- The 368 item count.

## Implications for the open decisions

These are inferences for the decision tickets, not upstream facts.

For #14 (harness and CI):

- The parity bar as worded ("every JSON case that passes in Python passes in R") needs an observed pass set. The JSON gives a declared one. A CI job that runs Python ftfy 6.3.1 over the file is the only way to get the observed set, and the only source of target outputs for the 10 fail records.
- An R runner that replicates upstream needs six distinct checks per pass case, not one. Checks 2 and 3 need an R `apply_plan` equivalent. Check 4 needs the ability to turn off the nine listed options. Check 7 needs UTF-8 bytes re-read as Latin-1.
- Replicating strict expected failure in R means asserting that the encoding-only fix differs from `fixed` for the 10 fail records. A stricter and more useful check is equality with captured Python output.
- Plans are not pinned by the JSON. If R plans should match Python plans, the comparison job has to capture them too.
- Deduplicate or keep the duplicate record deliberately; identify cases by index, since labels are not unique.

For #7 (v0.1 surface):

- JSON parity alone requires `fix_text`, `fix_and_explain`, `fix_encoding_and_explain`, `apply_plan`, and the option set used at `tests/test_examples_in_json.py:70-78`.
- Leaving out display-width formatting, the command line, `fix_file`, `guess_bytes` or `explain_unicode` drops whole test files or doctest groups cleanly: no JSON case depends on them.
- Three unit tests expect a string containing U+0000 (`tests/test_bytes.py:33`, `:39`; `tests/test_encodings.py:10`) and one takes lone surrogates as string input (`tests/test_characters.py:45-46`), as do the `fix_surrogates` doctests. R character strings are generally understood not to hold embedded NUL or lone surrogates; this was not checked here and belongs to #12 and #6. The JSON cases contain neither.
- `test_cli.py:52` pins a CPython error message. An R command line could not match it byte for byte without copying that text.

For #17 (vendoring):

- Candidate files: `tests/test_cases.json` (48,962 bytes, hash above) and `tests/face.txt` (35 bytes, hash above).
- `test_cases.json` is UTF-8 with 2,153 raw non-ASCII characters and no trailing newline. Any tooling that rewrites the file will change its hash.
- `LICENSE.txt` at the tag is 552 bytes: the Apache-2.0 notice header with "Copyright 2023 Robyn Speer", not the full licence text (SHA-256 `a0bfc5020bc2e1e820551a0625c70c95faa898c15e737100ff4880aa10197857`). The repository root has no `NOTICE` file.
- The build backend is hatchling (`pyproject.toml:22-24`), and its sdist exclude list (`pyproject.toml:26-27`) does not exclude `tests/`, so the same files probably ship in the PyPI sdist. The sdist itself was not inspected. `MANIFEST.in:1` also says `graft tests`, but that is a setuptools file and may be a leftover.
- The upstream changelog says the JSON file exists partly to "ease porting to other languages" (`CHANGELOG.md:267-268`).

## References

- python-ftfy at v6.3.1: <https://github.com/rspeer/python-ftfy/tree/v6.3.1>
  - `tests/test_examples_in_json.py`, `tests/test_cases.json`, `tests/test_bytes.py`, `tests/test_characters.py`, `tests/test_cli.py`, `tests/test_encodings.py`, `tests/test_entities.py`, `tests/face.txt`
  - `ftfy/__init__.py`, `ftfy/fixes.py`, `ftfy/formatting.py`, `ftfy/cli.py`, `ftfy/bad_codecs/`
  - `pytest.ini`, `tox.ini`, `pyproject.toml`, `MANIFEST.in`, `.github/workflows/publish.yml`, `docs/*.rst`, `CHANGELOG.md`, `LICENSE.txt`
- pytest 8.3, "How to use skip and xfail to deal with tests that cannot succeed": <https://docs.pytest.org/en/8.3.x/how-to/skipping.html>
- pytest 8.3, "How to run doctests": <https://docs.pytest.org/en/8.3.x/how-to/doctest.html>
