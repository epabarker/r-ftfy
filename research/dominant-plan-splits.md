# How one corruption source splits into several plans (ftfy 6.3.1)

Context: [Dominant plan of a column](https://github.com/epabarker/r-ftfy/issues/20). Throwaway branch, never merged.

Run with ftfy 6.3.1 on Python 3.13.5 (`uv run --python 3.13 --with ftfy==6.3.1 python probe.py`). Corpus: 10 hand-written language lists of 200 values each (100 words, 100 two-word phrases, some with curly quotes, en dash, euro sign, ellipsis or a no-break space), corrupted with Python's codecs. In each column 1,881 of 2,000 values change when corrupted. Files: `dominant-plan-splits/probe.py`, `words.py`, full output in `output.txt`, replay checks in `replay_summary.txt`, aggregates in `summary.json`.

## Findings

- **A single-source column almost never gives one plan.** `fix_encoding_and_explain()` gives 2 to 4 distinct plans per column (up to 6); `fix_and_explain()` gives 3 to 8.
- **Cause 1: latin-1 versus sloppy-windows-1252.** latin-1 is tried first (`chardata.py:15-26`; loop at `__init__.py:493`, first success wins at `:536`). Mojibake containing any character from bytes 0x80-0x9F (euro sign, curly quotes, ellipsis, oe ligature, capital E acute, C caron, ...) gets `encode sloppy-windows-1252`; the rest gets `encode latin-1`. The same mechanism puts latin-1 and 1252 plans into windows-1250 and windows-1254 columns.
- **Cause 2: lossy values** (U+FFFD from Python's strict codecs) gain `transcode replace_lossy_sequences`. With sloppy codecs this split disappears.
- **Cause 3: `apply uncurl_quotes`**, in `fix_and_explain()` only, whenever the output has curly quotes.
- `apply decode_inconsistent_utf8` can appear in `fix_encoding_and_explain()` plans (`__init__.py:543`); seen only in strict double-1252 Russian and Greek columns.
- Never seen: `transcode fix_c1_controls`, `apply fix_c1_controls`, `transcode restore_byte_a0` (cannot fire here: Python codecs never turn A0 into a space, a corpus limit), `decode utf-8-variants`.
- **Replay between plans.** The sloppy-1252 plan replays on latin-1-plan values with identical output, always; the reverse raises `UnicodeEncodeError`. A `replace_lossy_sequences` plan replays on non-lossy values identically; the reverse raises `UnicodeDecodeError`. The commonest exact plan varies by language (latin-1 in French, sloppy-1252 in Czech).
- **Misses** are high for windows-1251, windows-1253, cp437, macroman and windows-1250 (short or ambiguous values). Replaying the column's main plan on missed values fixed nearly all of them exactly.
- **Double encoding:** values that per-value detection only half-fixes get one-layer plans; replaying the two-layer plan on them gives more than their own fix (the clean value).
- In `fix_and_explain()`, 163 windows-1251 and 130 windows-1253 values got only `apply uncurl_quotes`: missed and altered so they can no longer be repaired.
- Side note: the check `"windows-1252" in possible_1byte_encodings` at `__init__.py:552` can never be true; that list holds only `sloppy-` names.
