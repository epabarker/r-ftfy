# Lost-character recovery: can a lossy value be matched to an intact one in its column?

Probe for the map ticket [Lost-character recovery](https://github.com/epabarker/r-ftfy/issues/22). Throwaway branch, never merged.

Run: `uv run --python 3.13 --with ftfy==6.3.1 python probe.py > output.txt` (ftfy 6.3.1, Python 3.13, macOS). Then `python a0_check.py output.txt`.

## Set-up

- Word lists from the dominant-plan probes (10 languages, about 200 values each), plus an all-caps copy of 100 of them, because capitals hit codec holes more often.
- Columns of 100 and 1,000 rows, drawn **with repetition** (Zipf weights), share corrupted *p* in {0.1, 0.5, 0.9}. A lossy row can therefore have an intact twin elsewhere in the column.
- A separate adversarial set of **minimal pairs**: real names that differ in one non-ASCII letter (`ÍÑIGO`/`ÏÑIGO`, `Zoé`/`Zoë`, `ÁLVARO`/`ÄLVARO`).
- Three loss kinds:
  - **U+FFFD**: UTF-8 decoded with a codec that has holes, `errors="replace"`. Codecs: 1250, 1251, 1252, 1253, 1254. Per-value encoding repair leaves U+FFFD where a character was lost.
  - **`?`**: clean text exported to a narrower codec with `errors="replace"`, so that each character the codec can't hold became `?`. Western text to ASCII; other languages to latin-1 and windows-1252.
  - **A0 turned into a space**: UTF-8 read as windows-1252, with every NBSP then turned into a space.
- **Matching rule tested.** Candidates are distinct values in the column that contain no loss marker after per-value repair. A candidate must:
  - have the same length as the lossy value;
  - be equal to it at every position that is not a loss site;
  - carry a non-ASCII character at every loss site.

  The **holes** variant (U+FFFD only) also requires each site's character to have a UTF-8 byte that is a hole of the column's codec.

## Results

Counts are distinct lossy values, summed over the grid.

| Loss kind | Set | Lossy | No candidate | One, right | One, **wrong** | Several |
|---|---|---|---|---|---|---|
| U+FFFD, plain | words | 5,606 | 3,475 | 2,114 | **6** | 11 |
| U+FFFD, holes | words | 5,606 | 3,483 | 2,121 | **0** | 2 |
| U+FFFD, plain | pairs | 101 | 27 | 17 | **17** | 40 |
| U+FFFD, holes | pairs | 101 | 37 | 42 | **7** | 15 |
| `?` | words | 4,343 | 2,448 | 1,756 | **25** | 114 |
| `?` | pairs | 110 | 20 | 41 | **8** | 41 |

- **Recovery only works on partly corrupted columns.**
  - About 62% of U+FFFD values and 56% of `?` values have no candidate at all.
  - One corruption damages the same value the same way every time, so the only intact twin of a lossy value is an uncorrupted row of the same value.
  - When *p* = 1 there is nothing to recover from.
- **Uniqueness within the column is not uniqueness in the language.** The wrong matches are real words or names that happen to be the only same-shape value present:
  - `GR?SSE` matched to `GRÖSSE`; the truth was `GRÜSSE`
  - `T�` matched to `TŰ`; the truth was `TŐ`
  - `Д�` matched to `ДО`; the truth was `ДА`
  - from the pairs set: `�ÑIGO` matched to `ÍÑIGO` (truth `ÏÑIGO`), even with the holes check, and `Zo?` matched to `Zoé` (truth `Zoë`). `output.txt` lists every wrong match.
- **The holes constraint helps but doesn't remove the problem.**
  - On ordinary words it removes every wrong match (6 → 0).
  - On minimal pairs, 7 of the 49 unique matches are still wrong, whenever the twin's letter shares a hole byte (for example Á/Í/Ï/Ð/Ý in windows-1252).
  - Real name columns contain such pairs. ADR 0010 counts each wrong match as a new false positive.
- **`?` has no marker of its own.**
  - In Cyrillic, Greek and similar text exported to latin-1, every letter becomes `?`. A value like `????` matches any intact four-letter word.
  - Values that are clean but contain a literal `?` (13 in the Spanish set, such as `¿qué?`) are indistinguishable from lossy ones.
- **A0 turned into a space is already handled per value** (measured on the four Western languages under windows-1252 only).
  - `fix_text()` repairs 1,696 of 1,888 rows.
  - Of the 99 distinct values it leaves unrepaired, 95 are ordinary misses unrelated to A0, mostly all-caps values. The dominant-plan replay handles those.
  - Only 4 involve an A0 byte. All four end in `à`, at the end of the value or followed by punctuation.
- **Side finding: windows-1253 often leaves a value unrepaired per value** (`Γ�ve` for `Ève`; 493 values not at their reachable target, mostly windows-1253). These are misses for the dominant-plan replay, not cases for recovery.
