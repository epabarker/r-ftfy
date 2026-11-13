# Replaying a column's dominant plan on values it was not detected on (ftfy 6.3.1)

Context: [Applying the dominant plan to values it was not detected on](https://github.com/epabarker/r-ftfy/issues/21). Throwaway branch, never merged.

Run with ftfy 6.3.1 on Python 3.13 (`uv run --python 3.13 --with ftfy==6.3.1 python <script>.py`). Corpus: the 10 hand-written language lists from `research/dominant-plan-splits` (`words.py`), 200 values each, corrupted with Python's codecs under 11 sources. Dominant plan computed with the rules of [Dominant plan of a column](https://github.com/epabarker/r-ftfy/issues/20) (support floor 3, more than half of flagged values, tie by upstream's encoding order). Every column had a dominant plan.

Files:
- `probe.py` → `output.txt`, `summary.json`: replay on missed, non-supporting and clean values.
- `adversarial.py` → `adversarial.txt`: clean all-caps, title-case and short words, plus every letter pair whose bytes are valid UTF-8 in a codec.
- `gates2.py` → `gates2.txt`: script and character checks against misses and unflagged clean values.
- `lost.py` → `lost.txt`: which characters make the character check reject a miss.
- `peek3.py`: checks on non-supporting flagged values.

## Findings

- **Missed values.** All 2,873 corrupted values that per-value detection missed replay to their reachable target: 2,732 exactly clean, 141 lossy with U+FFFD exactly where a character was lost (checked against a computed reachable target).
- **Badness is useless as a check.** Missed values have low badness by definition; badness never drops on a replayed miss, and goes up by one for each U+FFFD.
- **Clean values can be damaged.** Mixed-case dictionary words never replayed. But clean, unflagged all-caps or short words in Central European and Cyrillic do: `PÓŁNOC → PӣNOC`, `RÓŻA → RӯA`, `STÓŁ → STӣ`, `VĚŽ → V̎`, `GĘŚ → Gʌ`, `Úžas → ڞas`, `Úšklebek → ښklebek`, `Её → Ÿ`, `Ті → ҳ`. Over the word pool × every column: 173 (value, column) cases where the replay succeeds and changes a clean, unflagged value.
- **Checks on those 173 versus the 2,873 misses:**

  | Check on the replayed text | Clean values accepted (of 173) | Misses accepted (of 2,873) |
  |---|---|---|
  | per-value encoding repair leaves it unchanged ("stable") | 173 | 2,872 |
  | stable, and only scripts seen in supporters' repaired outputs | 21 | 2,872 |
  | stable, and only non-ASCII characters seen in supporters' repaired outputs | **0** | 2,843 |

  The 29 misses the character check rejects all contain a letter no supporter had (`õ`, `ú`, `ó`, `È`, `э`, `Χ`, `ζ`, `ξ`); they fall back to per-value `fix_text()`, unchanged.
- **Valid mojibake written on purpose** (`Ã©`, `â€™`, `Ãœber`) is flagged by per-value detection too, so it is not an unflagged-value problem.
- **Flagged values that do not support the dominant plan:** 56 in all. In 48 (half-fixed double encoding: own plan one layer, dominant plan two) the replay is exactly clean and the own fix is not. In 8 (two Greek double-encoding columns) the own fix is right and the replay is worse; there the dominant plan has no more decode steps than the value's own plan. Too few negatives to prove a rule.
- **Letter pairs** (`adversarial.txt`): 3,622 two-letter strings are valid UTF-8 in some codec; 6,116 of their (string, plan) replays change an unflagged string and stay stable, so short values are where any acceptance rule is tested hardest.
