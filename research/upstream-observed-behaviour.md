# Upstream behaviours observed on installed ftfy 6.3.1

Task for issue #18. Everything here was **run**, not read, except the two statements marked *(reasoned)*. It confirms or corrects the items that the research for #2, #3 and #4 marked as traced from the source.

## Environment

- macOS arm64 (Darwin 27.2.0). `ftfy==6.3.1` installed from PyPI into throwaway virtual environments; the installed package files are byte-identical to `ftfy/` at tag `v6.3.1` (commit `5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3`, `diff -rq`).
- Upstream's tests were run from a checkout of that tag. pytest imported `ftfy` from the checkout rather than from site-packages (`ftfy.__file__` pointed at the checkout); since the two are byte-identical, the result is the same as for the installed library. The reproduction scripts were run from outside the checkout and import the installed package.

| Python | Unicode data | ftfy | wcwidth | pytest |
|---|---|---|---|---|
| 3.9.6 | 13.0.0 | 6.3.1 | 0.9.4 | 8.4.2 |
| 3.10.20 | 13.0.0 | 6.3.1 | 0.9.4 | 9.2.0 |
| 3.13.5 | 15.1.0 | 6.3.1 | 0.9.4 | 9.2.0 |
| 3.14.5 | 16.0.0 | 6.3.1 | 0.9.4 | 9.2.0 |
| 3.13.5 | 15.1.0 | 6.3.1 | 0.2.13 (the version in upstream's `uv.lock`) | 9.2.0 |

**Every observation below was identical on all four Python versions** (the script outputs differ only in their version block; the pytest outcomes per item are the same). The files in `upstream-observed-behaviour/` are the 3.13.5 outputs. Strings are shown as Python `ascii()` reprs.

Files: `observe.py` and `c1.py` (the reproductions), `observe.json` and `c1.json` (their output; `observe.json` holds Python's output and plans for all 161 JSON cases under `item3_all_cases`), `pytest-*.txt` (full `pytest -rA` output per environment), and `python-output-all-cases.json` with `fixtures.py` that made it: Python's `fix_text`, `fix_and_explain` and `fix_encoding_and_explain` output and plans for all 161 cases as raw UTF-8 strings, readable from R, byte-identical across the four Python versions.

## 1. `normalize` steps are not replayable: confirmed

| Input | Fixed | Plan | `apply_plan(input, plan)` |
|---|---|---|---|
| `'e\u0301'` | `'\xe9'` | `[('normalize', 'NFC')]` | raises `ValueError: Unknown plan step: normalize` |
| `'sch\xc3\xb6n cafe\u0301'` | `'sch\xf6n caf\xe9'` | `[('apply', 'decode_inconsistent_utf8'), ('normalize', 'NFC')]` | raises `ValueError: Unknown plan step: normalize` |

- Any input that NFC changes gets a `("normalize", "NFC")` step, and `apply_plan` raises `ValueError: Unknown plan step: normalize` on it.
- None of the 161 JSON cases produces a `normalize` step (list of such cases: `[]`), which is why upstream's own plan-replay test passes.

## 2. Encoding sub-options are ignored when `explain` is false: confirmed for all four

One input per option, chosen so that turning the option off changes the result. "Honoured" means the output differs from the default.

| Call | `restore_byte_a0` | `replace_lossy_sequences` | `decode_inconsistent_utf8` |
|---|---|---|---|
| input | `'voil\xc3  le travail'` | `'\xe2\u20ac\u0153 like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |
| fix_text default | `'voil\xe0 le travail'` | `'" like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_text kwarg off | `'voil\xe0 le travail'` | `'" like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_text config off (explain=True default) | `'voil\xe0  le travail'` | `'" like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |
| fix_text config off, explain=False | `'voil\xe0 le travail'` | `'" like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_text kwarg off + explain=True kwarg | `'voil\xe0  le travail'` | `'" like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |
| fix_text_segment kwarg off | `'voil\xe0 le travail'` | `'" like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_and_explain kwarg off (text) | `'voil\xe0  le travail'` | `'" like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |
| fix_and_explain kwarg off, explain=False (text) | `'voil\xe0 le travail'` | `'" like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_encoding default | `'voil\xe0 le travail'` | `'\u201c like this \ufffd'` | `'\u2014 caf\xe9 \u2014 \u0430\u0431'` |
| fix_encoding kwarg off | `'voil\xe0  le travail'` | `'\u201c like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |
| fix_encoding_and_explain kwarg off (text) | `'voil\xe0  le travail'` | `'\u201c like this \xe2\u20ac\ufffd'` | `'\u2014 caf\xc3\xa9 \u2014 \u0420\xb0\u0420\xb1'` |

Reading the table:

- `fix_text(t, option=False)` and `fix_text_segment(t, option=False)` return the **default** result: the option is ignored.
- `fix_text(t, TextFixerConfig(option=False))` honours it, because that config has `explain=True`.
- `fix_text(t, TextFixerConfig(option=False, explain=False))` ignores it again, and so does `fix_and_explain(t, option=False, explain=False)`. So the trigger is `explain` being false, however it got that way, not the use of keyword arguments.
- `fix_text(t, option=False, explain=True)` honours it: adding `explain=True` as a keyword is a working upstream workaround.
- `fix_and_explain`, `fix_encoding` and `fix_encoding_and_explain` honour the option with keyword arguments alone.

### `fix_c1_controls`

The first input I tried was fixed by the Latin-1 to Windows-1252 fallback whatever the option said, so this needs an input containing a C1 control that strict Windows-1252 cannot decode (U+0081 here), which forces the `fix_c1_controls` fallback.

| Call | `'caf\x81 \x85 \x91x\x92'` | `'\x81\x85'` | `'na\xefve \x81 \x93quote\x94'` |
|---|---|---|---|
| fix_text default | `"caf\x81 \u2026 'x'"` | `'\x81\u2026'` | `'na\xefve \x81 "quote"'` |
| fix_text kwarg off | `"caf\x81 \u2026 'x'"` | `'\x81\u2026'` | `'na\xefve \x81 "quote"'` |
| fix_text config off (explain=True default) | `'caf\x81 \n \x91x\x92'` | `'\x81\n'` | `'na\xefve \x81 \x93quote\x94'` |
| fix_text config off, explain=False | `"caf\x81 \u2026 'x'"` | `'\x81\u2026'` | `'na\xefve \x81 "quote"'` |
| fix_and_explain kwarg off | `('caf\x81 \n \x91x\x92', [('apply', 'fix_line_breaks')])` | `('\x81\n', [('apply', 'fix_line_breaks')])` | `('na\xefve \x81 \x93quote\x94', [])` |
| fix_and_explain default | `("caf\x81 \u2026 'x'", [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls'), ('apply', 'uncurl_quotes'), ('transcode', 'fix_c1_controls')])` | `('\x81\u2026', [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls')])` | `('na\xefve \x81 "quote"', [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls'), ('apply', 'uncurl_quotes'), ('transcode', 'fix_c1_controls')])` |
| fix_and_explain kwarg off, fix_encoding=False | `('caf\x81 \n \x91x\x92', [('apply', 'fix_line_breaks')])` | `('\x81\n', [('apply', 'fix_line_breaks')])` | `('na\xefve \x81 \x93quote\x94', [])` |
| fix_and_explain fix_encoding=False only | `("caf\x81 \u2026 'x'", [('apply', 'fix_c1_controls'), ('apply', 'uncurl_quotes')])` | `('\x81\u2026', [('apply', 'fix_c1_controls')])` | `('na\xefve \x81 "quote"', [('apply', 'fix_c1_controls'), ('apply', 'uncurl_quotes')])` |
| fix_encoding default | `'caf\x81 \u2026 \u2018x\u2019'` | `'\x81\u2026'` | `'na\xefve \x81 \u201cquote\u201d'` |
| fix_encoding kwarg off | `'caf\x81 \x85 \x91x\x92'` | `'\x81\x85'` | `'na\xefve \x81 \x93quote\x94'` |
| fix_encoding_and_explain default | `('caf\x81 \u2026 \u2018x\u2019', [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls')])` | `('\x81\u2026', [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls')])` | `('na\xefve \x81 \u201cquote\u201d', [('transcode', 'fix_c1_controls'), ('transcode', 'fix_c1_controls')])` |

- `fix_text(t, fix_c1_controls=False)` equals the default: ignored, like the other three. With `explain` false the main-loop fixer is skipped but the encoding stage runs with a default config and does the same work.
- With the option honoured (config object, or `fix_and_explain`), U+0085 is then turned into `\n` by `fix_line_breaks`.
- With `fix_encoding=False` and `fix_c1_controls` left on, the main-loop fixer still runs and is recorded as `("apply", "fix_c1_controls")`. So the upstream docstring's claim that this option does nothing when `fix_encoding` is false is wrong, as #2 traced.
- **No-op steps are real.** `fix_and_explain('a\x81b')` and `fix_encoding_and_explain('a\x81b')` both return the text unchanged with the plan `[('transcode', 'fix_c1_controls')]`; `'\x81'` alone does the same. U+0081 has no Windows-1252 mapping, so the fixer maps it to itself, and the step is recorded without checking for a change. In the table above the first `transcode` step in each plan is a real change and the later ones are no-ops (one of two from `fix_encoding_and_explain`, two of three from `fix_and_explain`). #2 marked this "looks possible"; it happens.

## 3. Upstream test suite at v6.3.1

368 items collected in every environment, matching the count #3 read from the source.

| Environment | Passed | Expected-fail (xfail) | Failed | Unexpected pass |
|---|---|---|---|---|
| Python 3.9.6, 3.10.20, 3.13.5, 3.14.5 with wcwidth 0.9.4 | 357 | 10 | 1 | 0 |
| Python 3.13.5 with wcwidth 0.2.13 | 358 | 10 | 0 | 0 |

- **All 151 `"pass"` JSON cases pass, and all 10 `"fail"` cases fail as declared**, on every Python version. The declared counts are now observed.
- The single failure is the doctest `ftfy.formatting.monospaced_width`: `monospaced_width('owl\N{SOFT HYPHEN}flavored')` returns 12 with wcwidth 0.9.4 where the doctest expects 11. It passes with wcwidth 0.2.13. It is in the display-width helpers, which v0.1 does not ship.
- `tests/test_cli.py` needs the `ftfy` command on `PATH`; without the virtual environment's `bin` on `PATH` its six tests fail with `FileNotFoundError`. That is an artefact of how the suite is invoked, not a library failure.

### Python's actual output for the 10 expected-fail cases

Index is the zero-based position in `tests/test_cases.json`. The suite's fail check looks only at the encoding-only fix.

| # | Label | `fix_text` equals JSON `fixed` | `fix_encoding` output | `fix_text` output | Plan from `fix_and_explain` |
|---|---|---|---|---|---|
| 51 | Synthetic: Incomplete UTF-8 / Windows-1252 mixup in Arabic | no | `'\u0623\u0643\u062b\u0631 \u0645\u0646 \xd9 \xd9 \xd9\xa1 \u0628\u0644\u062f'` | `'\u0623\u0643\u062b\u0631 \u0645\u0646 \xd9 \xd9 \xd9\xa1 \u0628\u0644\u062f'` | `[('apply', 'decode_inconsistent_utf8')]` |
| 61 | Two levels of inconsistent mojibake | no | `'Arsenal v Wolfsburg: pre-season friendly \xe2\u20ac\xe2\u20ac\u0153 live!'` | `'Arsenal v Wolfsburg: pre-season friendly \xe2\u20ac\xe2\u20ac\u0153 live!'` | `[('encode', 'latin-1'), ('decode', 'windows-1252')]` |
| 107 | Misleading mix-up in Spanish | yes | `'tiene demora y est\xe1 \u201cpr\xf3ximo a resolverse\u201d'` | `'tiene demora y est\xe1 "pr\xf3ximo a resolverse"'` | `[('apply', 'decode_inconsistent_utf8'), ('transcode', 'fix_c1_controls'), ('apply', 'uncurl_quotes')]` |
| 108 | A-with-grave in Vietnamese | no | `'Xem clip h\xe0 i, phim h\xe0 i m\u1edbi hay nh\u1ea5t'` | `'Xem clip h\xe0 i, phim h\xe0 i m\u1edbi hay nh\u1ea5t'` | `[('encode', 'sloppy-windows-1250'), ('transcode', 'restore_byte_a0'), ('decode', 'utf-8')]` |
| 110 | Latin-1 / MacRoman mixup in Spanish | no | `'Deja dos heridos hundimiento de barco tur\u2019stico en Acapulco.'` | `"Deja dos heridos hundimiento de barco tur'stico en Acapulco."` | `[('encode', 'latin-1'), ('decode', 'windows-1252'), ('apply', 'uncurl_quotes')]` |
| 111 | subtle UTF-8 / codepage 437 mixup in Spanish | no | `'\u252c\u2510que diferencia hay?'` | `'\u252c\u2510que diferencia hay?'` | `[]` |
| 112 | Latin-1 / MacRoman mixup in Spanish, 2 characters | no | `'Habitantes de Coatl\u2021n conf\u2019an en proyecto de edil electo independiente'` | `"Habitantes de Coatl\u2021n conf'an en proyecto de edil electo independiente"` | `[('encode', 'latin-1'), ('decode', 'windows-1252'), ('apply', 'uncurl_quotes')]` |
| 113 | An example with 'à' in windows-1251 where we need our heuristic to be bolder | no | `'faites attention \u0413 bien vous renseigner avant sur le m\u0413\xa9dicament'` | `'faites attention \u0413 bien vous renseigner avant sur le m\u0413\xa9dicament'` | `[]` |
| 123 | Italian UTF-8 / MacRoman mojibake that looks like math | no | `'Sarai ricontattato dal nostro Esperto al pi\u221a\u03c0 presto.'` | `'Sarai ricontattato dal nostro Esperto al pi\u221a\u03c0 presto.'` | `[]` |
| 158 | Synthetic, false positive: the title of a manga, in weird capitalized romaji, with a non-breaking space | no | `'MISUT\xa0AJIKKO'` | `'MISUT\xa0AJIKKO'` | `[('encode', 'latin-1'), ('decode', 'utf-8')]` |

- Case 107 is marked `"fail"` yet `fix_text` returns exactly the JSON `fixed` value; only the encoding-only fix differs (it keeps curly quotes). A fail case is therefore not always a case that `fix_text` gets wrong.
- Cases 111, 113 and 123 are left unchanged with an empty plan.
- For all 161 cases, `fix_and_explain(original).text == fix_text(original)`. 40 cases have an empty plan.

Step kinds seen across the 161 full plans (count of occurrences):

| Count | Step |
|---|---|
| 103 | `('decode', 'utf-8')` |
| 43 | `('encode', 'sloppy-windows-1252')` |
| 36 | `('encode', 'latin-1')` |
| 27 | `('apply', 'uncurl_quotes')` |
| 15 | `('transcode', 'restore_byte_a0')` |
| 14 | `('transcode', 'replace_lossy_sequences')` |
| 11 | `('apply', 'decode_inconsistent_utf8')` |
| 10 | `('encode', 'macroman')` |
| 9 | `('encode', 'sloppy-windows-1250')` |
| 8 | `('encode', 'sloppy-windows-1251')` |
| 6 | `('transcode', 'fix_c1_controls')` |
| 4 | `('decode', 'utf-8-variants')` |
| 4 | `('decode', 'windows-1252')` |
| 3 | `('apply', 'fix_latin_ligatures')` |
| 3 | `('encode', 'cp437')` |
| 2 | `('apply', 'remove_control_chars')` |
| 1 | `('apply', 'fix_character_width')` |
| 1 | `('apply', 'unescape_html')` |
| 1 | `('encode', 'iso-8859-2')` |
| 1 | `('encode', 'sloppy-windows-1257')` |

Not exercised by any JSON case: `normalize`, `encode` with `sloppy-windows-1253` or `sloppy-windows-1254`, and `apply` of `fix_line_breaks`, `fix_surrogates`, `remove_terminal_escapes` and `fix_c1_controls`.

## 4a. `C0 0A` at the end of input decodes to U+0000: confirmed, and reachable from text

Codec level:

| Bytes | `.decode("utf-8-variants")` | `.decode("utf-8")` |
|---|---|---|
| `b'abc\xc0\n'` | `'abc\x00'` | raises `UnicodeDecodeError` |
| `b'abc\xc0\x80'` | `'abc\x00'` | raises `UnicodeDecodeError` |
| `b'abc\xc0\ndef'` | raises `UnicodeDecodeError` | raises `UnicodeDecodeError` |
| `b'abc\xc0'` | raises `UnicodeDecodeError` | raises `UnicodeDecodeError` |
| `b'abc\xc0x'` | raises `UnicodeDecodeError` | raises `UnicodeDecodeError` |
| `b'\xc0\n'` | `'\x00'` | raises `UnicodeDecodeError` |
| `b'abc\xc0\n\n'` | raises `UnicodeDecodeError` | raises `UnicodeDecodeError` |
| `b'abc\xc0\r\n'` | raises `UnicodeDecodeError` | raises `UnicodeDecodeError` |

- `C0` followed by **exactly one final byte `0A`** decodes to U+0000 and the newline is gone. `C0 0A` followed by anything else (another newline, `def`, CRLF) raises, and so does a lone trailing `C0` or `C0 78`.

Through the public functions (U+00C0 is `À`, which Latin-1 encodes to byte `C0`):

| Text | `fix_text` | `fix_and_explain` (text, plan) | `fix_encoding` |
|---|---|---|---|
| `'\xc0\n'` | `'\xc0\n'` | `('\xc0\n', [])` | `'\xc0\n'` |
| `'sch\xc3\xb6n \xc0\n'` | `'sch\xf6n '` | `('sch\xf6n ', [('encode', 'latin-1'), ('decode', 'utf-8-variants'), ('apply', 'remove_control_chars')])` | `'sch\xf6n \x00'` |
| `'sch\xc3\xb6n \xc0'` | `'sch\xf6n \xc0'` | `('sch\xf6n \xc0', [('apply', 'decode_inconsistent_utf8')])` | `'sch\xf6n \xc0'` |
| `'sch\xc3\xb6n \xc0\nmore'` | `'sch\xf6n more'` | `('sch\xf6n \xc0\nmore', [('apply', 'decode_inconsistent_utf8')])` | `'sch\xf6n \xc0\nmore'` |

- A segment that contains real mojibake and ends in `À` plus a newline loses both the `À` and the newline: `fix_encoding` returns a string ending in U+0000, and `fix_text` then deletes the U+0000 with `remove_control_chars`.
- In the last row `fix_text` and `fix_and_explain` disagree: `fix_text` splits on the newline, so its first segment ends in `À\n` and is corrupted (`'schön more'`), while `fix_and_explain` sees one segment and leaves the `À\n` alone.
- The observed effect is that a legitimate character is dropped and two lines are joined. *(reasoned)* In R the intermediate U+0000 cannot exist in a string at all, so the port cannot pass through the same intermediate state.

## 4b. The `"windows-1252" in possible_1byte_encodings` branch is dead: confirmed

- `"windows-1252" in ftfy.chardata.CHARMAP_ENCODINGS` is `False`; the list is `['latin-1', 'sloppy-windows-1252', 'sloppy-windows-1251', 'sloppy-windows-1250', 'sloppy-windows-1253', 'sloppy-windows-1254', 'sloppy-windows-1257', 'iso-8859-2', 'macroman', 'cp437']`, and `possible_1byte_encodings` only ever receives members of it.
- Line-tracing `_fix_encoding_one_step_and_explain` over all 161 JSON originals, the same originals with one extra layer of UTF-8-as-Latin-1 mojibake, and five targeted inputs: the test at line 552 was evaluated 18 times and the "probably legit" return at line 555 ran **0** times. The Latin-1 to Windows-1252 attempt at line 561 ran all 18 times and produced a fix 13 times.
- *(reasoned, not observed)* The dead branch has no visible effect. Text in the intersection of Latin-1 and Windows-1252 has no C1 controls, so `encode("latin-1").decode("windows-1252")` returns it unchanged and the code falls through to the same "unchanged" result.

## Not covered

- One operating system and CPU (macOS arm64). Linux and Windows were not run.
- Python 3.11 and 3.12 were not run; 3.9, 3.10, 3.13 and 3.14 agree on everything here, which spans Unicode 13.0 to 16.0.
- The cross-version agreement covers the reproductions above and upstream's own tests. It does not show that Python versions agree on arbitrary text; #5 found NFC differs for code points newer than the older side's Unicode version.
- The line trace shows the dead branch is never taken on the inputs tried; that it can never be taken follows from the list contents, not from the trace.
