# Probes run while deciding codec table construction

Throwaway measurements for issue #10. Not for merging.

Setup: macOS arm64, Python 3.9.6 with ftfy 6.3.1 from PyPI in a virtual environment, R with stringi 1.8.7 (ICU 71.1).

## probe.py

`python probe.py python-output-all-cases.json`, using the captured output on branch `research/upstream-observed-behaviour`.

- Codec names in the captured plans of all 161 cases: encode with `latin-1` (71), `sloppy-windows-1252` (86), `sloppy-windows-1250` (18), `sloppy-windows-1251` (16), `sloppy-windows-1257` (2), `iso-8859-2` (2), `macroman` (20), `cp437` (6); decode with `utf-8` (205), `utf-8-variants` (8), `windows-1252` (8).
- `b'abc\xc0\n'` decodes to `'abc\x00'`. `ED A0 BD ED B8 0A` decodes to U+1F60A, also with a prefix; with a trailing byte after the newline, or without the newline, it raises. `C0 80` decodes to U+0000.
- Over `fix_text`, `fix_encoding` and `fix_and_explain` on all 161 cases, the `utf-8-variants` decoder is called 12 times by 4 cases; all 12 calls succeed. No call's input contains `C0 80`, ends in `C0 0A`, ends in a partial pair plus newline, or contains byte `C0` at all. Calls are recorded before decoding, so a call that raised would have been counted.

## isutf8.R and isutf8.py

`Rscript isutf8.R out.bin`, then `python isutf8.py out.bin`.

Compares `stringi::stri_enc_isutf8()` with whether CPython's strict `utf-8` decoder accepts the same bytes, over 4,636,928 sequences: all 256 single bytes; all two-byte sequences with first byte 80-FF; all three-byte sequences with first byte C0-FF; four-byte sequences with first byte F0-FF, any second byte, and third and fourth bytes from 00, 7F, 80, 8F, 90, 9F, A0, BF, C0, FF.

Result: 1,921 disagreements, every one a sequence containing byte `00` that CPython accepts and stringi rejects (the single byte `00`, and 1,920 valid two-byte characters followed by `00`). No other disagreement.

Limits: one ICU version, one platform; four-byte sequences sampled, not exhaustive; sequences longer than four bytes not tested.
