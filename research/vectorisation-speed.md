# Vectorisation and speed strategy: prototype findings

Prototype for https://github.com/epabarker/r-ftfy/issues/13. Throwaway; never merged.

**Deviation from the prototype skill.** Neither its HTML logic demo nor its UI variants fit a speed question, so the prototype is R scripts that print tables.

## Set-up

- macOS arm64 (Darwin 27.2.0), R 4.6.2, stringi 1.8.7 reporting ICU 71.1. Python 3.13.5 with ftfy 6.3.1 from PyPI. **One machine only.**
- `gen_data.py` dumps the regexes and tables from installed ftfy 6.3.1 into `data.json`. Verbose patterns are flattened, and `\s`, `\w` and `\d` are frozen to Python's code-point sets, as in ADR 0005. `data.json` is not committed because it embeds upstream literals.
- `columns.py` builds nine synthetic columns and times Python `fix_text` on each, one value at a time. Names are drawn from 42 first names and 30 surnames in Latin, Cyrillic and Greek script; mojibake is made by real codecs (60% sloppy-1252, 20% latin-1, 10% double, 10% sloppy-1250). Notes are 2 to 5 lines of about 75 characters. The column sweep varies n (10^4 to 10^6), clean fraction (50%, 95%, 100%), unique fraction (1%, 20%, 100%) and multi-line text.
- `proto.R` is a rough port of the default `fix_text` path, written **once over vectors**. The strategies differ only in how they call it. It ignores `max_decode_length` and options.
- `bench.R`, `probes.R`, `percall.R`, `profile.R` and `gate.R` print the results below. Raw output is in `results/`.

## Correctness gate (before any timing)

- `fix_text`: **161/161** upstream JSON cases match Python output, including all 151 pass cases.
- `fix_and_explain`: **161/161** match Python on both text and plan.
- **Every strategy matches Python's output on 100% of every benchmark column**, so all timings are of the same function.

## Strategies (µs per value; lower is better)

The per-string strategies (A) were timed on the first 10,000 values of each column.

| Column | A loop | A + fast path + dedup | B vectorised | C B + fast path | D C + dedup | Python |
|---|---:|---:|---:|---:|---:|---:|
| names, n=10^6, 95% clean, 20% unique | n/a | n/a | 7.84 | 7.58 | **1.36** | 9.76 |
| names, n=10^5, 95% clean, 20% unique | 622 | 512 | 6.90 | 6.97 | **1.24** | 9.01 |
| names, 100% clean | 588 | 479 | 5.83 | 5.76 | **1.16** | 9.26 |
| names, 50% clean | 1067 | 845 | 8.27 | 8.20 | **1.66** | 13.05 |
| names, 1% unique | 629 | 63 | 5.71 | 5.69 | **0.12** | 8.67 |
| names, 100% unique | 625 | 617 | 6.16 | 6.19 | 6.23 | 10.08 |
| ASCII IDs, n=10^5 | 117 | 0.00 | 2.95 | **0.06** | 0.03 | 5.50 |
| notes, multi-line, n=10^4 | 1029 | 1031 | **67.9** | 70.1 | 73.8 | 91.5 |

(A + fast path + dedup was timed on a 10,000-value prefix, so its duplicate rate is not the whole column's. The A columns come from a run before the U+FEFF-safe segment split; the B to D columns come from the final code. The splitting change barely moved B to D.)

- **A per-string loop is 70 to 100 times slower than B.** Each value pays about 15 stringi calls of fixed overhead, around 40 µs. Ruled out.
- **B vectorised passes with an active set** are faster than Python on every column: 0.6 to 0.85 times its time. Each fixer runs once over every still-changing segment, and only segments that changed go round the loop again. Line segments are flattened into one vector and re-joined.
- **C, the fast-path screen**, is one regex that marks printable ASCII with no `&` as unchangeable. It costs nothing measurable and is about 50 times faster on ASCII columns.
- **D, deduplication** (`unique()`, fix, `match()`), gives 5 to 50 times when values repeat. It costs about 1% when every value is unique, and about 5% on unique multi-line notes. `attributes()` are copied back. A probe with an `NA`-bearing matrix with dimnames, and a named vector, confirms that `NA`, `dim`, `dimnames` and `names` survive dedup and segment flattening.

## Fixed cost per call (small n)

The column timings hide a large fixed cost per call (`percall.R`):

| Input to one call | R prototype | Python ftfy |
|---|---:|---:|
| one mojibake name | 1,653 µs | 16.5 µs |
| one clean non-ASCII name | 601 µs | 6.4 µs |
| one ASCII string (fast path) | 4 µs | 5.3 µs |

| n (all unique) | 1 | 10 | 100 | 1000 |
|---|---:|---:|---:|---:|
| µs per value | 1,594 | 163 | 23 | 8.0 |

R overtakes Python at a few hundred values per call.

**Cause, measured:** stringi recompiles a pattern on every call. 1,000 length-1 calls with `BADNESS_RE` (26,419 characters once frozen) take 0.461 s; one call on a length-1,000 vector takes 0.001 s. That is about 460 µs to compile it each time. A small class pattern costs 2 µs per call, the encoding regexes 8 µs, and `UTF8_DETECTOR_RE` 33 µs. One `fix_text` pass calls `BADNESS_RE` at least once, and mojibake makes it more.

So anyone calling `fix_text()` per row (`vapply`, `dplyr::rowwise`, a small group) pays about 0.5 to 1.6 ms per call. That cost would be removed by compiled code that holds the compiled ICU matcher across calls, the one thing stringi can't do. A lighter mitigation is to make sure each pass calls `BADNESS_RE` exactly once, over all active segments together; the prototype already does this.

## Where the time goes (Rprof, strategy C)

- **Notes:** 74% `stri_detect_regex`, almost all of it `BADNESS_RE`, which takes about 11 µs per 75-character segment. Each encoding regex takes about 0.3 µs. R-level work (`vapply`, `split`, `substring`, closures) is under 10%.
- **Unique names:** 39% `stri_detect_regex`. R-level overhead is about 25 to 35%: `vapply`, `split` and `FUN` in segment re-joining and the splice.
- **ICU against Python on the same regex:** `BADNESS_RE` on 33,319 note segments takes 0.333 s with ICU and 0.251 s with Python `re`, so ICU is 1.3 times slower. With frozen `\w` and with ICU's own `\w`, ICU takes the same 0.333 s, so the frozen sets cost nothing.

**Implication:** compiled code could only remove the R-level share, at most about 35% of the worst column. The dominant cost is the badness heuristic inside ICU, which compiled code would speed up only by hand-writing a scanner to replace the regex. That would be a parity risk.

## Sub-decisions from the ticket's comments

- **Encode tables are built at load time** from the shipped decode tables, as one `chartr()` old/new string pair per codec. This takes 1 ms for all 11. Decode-table holes and byte 0 are skipped.
- **Encode lookup with base `chartr()` is fastest:** 0.37 µs per value, against 1.87 for a per-string `utf8ToInt` + `match()` and 1.27 for an unlisted `match()`. All three give identical results.
- **Bytes go to UTF-8** through `iconv(to = "latin1")`, re-marking as UTF-8, then `stri_enc_isutf8()`. This takes 0.22 µs per value.
- **Locate, compute, splice:** positions come from `stri_locate_all_regex()` and are spliced with base `substring()` and `paste()`. On a column where every value contains entities it costs 2.24 µs per value; a constant-replacement regex costs 0.21. On a column where 10% of values contain entities it costs 0.21 µs per value overall. `fix_c1_controls` needs no splice because it maps characters one to one, so it uses `chartr()`.
- **Plans:** recording a per-element plan in the active set costs nothing measurable: on 20,000 unique names the difference is within noise (0.068 to 0.071 s).
- **U+FEFF safety, measured.** These functions keep a leading U+FEFF:
  - stringi: `stri_detect_regex`, `stri_replace_all_regex` (also with `vectorize_all = FALSE`), `stri_locate_all_regex`, `stri_trans_nfc`, `stri_enc_isascii`, `stri_enc_isutf8`.
  - base R: `chartr`, `substring`, `nchar`, `paste0`, `iconv`, `gsub(fixed = TRUE)`, `grepl(fixed = TRUE)`.

  These lose a U+FEFF at the very start of their input:
  - `stri_replace_all_fixed`, `stri_sub`, `stri_join_list`.
  - **`stri_split_regex`**: segment splitting was switched to locate plus `substring()`.

  End to end with `remove_control_chars` off, every U+FEFF survives, including one that opens a later segment.

## Recommendation for the human to decide

1. **Strategy:** use vectorised passes with an active set (B), with the ASCII fast path (C) and deduplication at entry (D). The fixers are written once over vectors, and there is no per-string R loop anywhere.
2. **Speed target, columns:** never slower per value than Python ftfy 6.3.1 on the reference machine, on this benchmark column set, without counting deduplication. That holds now with margin (0.6 to 0.85 times). Dedup is a bonus, not part of the bar.
3. **Speed target, one call:** state the per-call cost honestly rather than match Python. About 0.6 to 1.6 ms per non-ASCII string is the price of pure R on stringi, because the big patterns are compiled on every call. Document that `fix_text()` should be called on whole vectors, not per row.
4. **Compiled-code threshold:** none for v0.1. Justified if the column target is missed, if Rprof shows R-level code (not ICU) above 50% of runtime on a benchmark column, or if the per-call cost is judged unacceptable. In the last case the compiled part is narrow: hold compiled ICU matchers for the big patterns across calls. Replacing ICU's regex with a hand-written scanner is a separate decision, because of parity.

## Caveats

- macOS arm64 and ICU 71.1 only; other ICU versions may run `BADNESS_RE` at a different speed.
- The columns are synthetic, and the prototype ignores options and `max_decode_length`.
- The prototype's numeric HTML entity handling is rough. It passed every upstream case, but it is not a parity claim.
