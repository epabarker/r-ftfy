# Probes run while deciding regex and Unicode-data parity strategy

Throwaway measurements for issue #11. Not for merging. Setup: macOS arm64, Python 3.9.6 with ftfy 6.3.1, R with stringi 1.8.7 (ICU 71.1).

## ages.py and nfc_stack.R

`python ages.py python-output-all-cases.json DerivedAge.txt nfc.json` (Unicode 16.0.0 `DerivedAge.txt`; captured cases from branch `research/upstream-observed-behaviour`), then `Rscript nfc_stack.R nfc.json`.

- Over the 644 strings of the 161 cases (original and the three outputs), every code point was assigned by Unicode 6.1 or earlier.
- Python's NFC changes none of the 644 strings, and stringi's NFC agrees on all of them. So the cases do not exercise NFC; this is not evidence that ICU's NFC matches Python's.
- `ANSI_RE` (with `[0-9]` for `\d`) on `ESC [` + 999,997 digits + `m`: overflows at a stack limit of 8 MB and 32 MB, succeeds from 64 MB.

## stack2.R and stack3.R

- Stack limits up to 1.07e9 work; 1.08e9 and above (including `.Machine$integer.max`) overflow immediately at 1,000,000 characters, as does `stack_limit = 0L`.
- With a limit of 2.56e8, 5.12e8 or 1e9, `ANSI_RE` succeeds at 4,000,000 characters.
- `UTF8_DETECTOR_RE` was not measured at these lengths.

## Upstream's Python versions (read with `gh api`, tag v6.3.1)

`tox.ini` lists `py39, py310, py311, py312, py313`; `pyproject.toml` has `requires-python = ">=3.9"`; Read the Docs builds on 3.11; `publish.yml` uses `3.x`. Tag committed 2024-10-26.
