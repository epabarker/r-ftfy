# Fixers run over whole vectors in pure R

`fix_text()` and the other core functions never loop over strings in R. Each input is split into segments, and all segments of the whole vector are flattened into one vector. Each fixer then runs once over every segment still changing, and only the segments that changed go round the loop again. Before that, the input is deduplicated (`unique()`, then `match()` back), and a single regex screen skips any value that no default fixer can change: printable ASCII with no `&`.

We chose this because a per-string port is 70 to 100 times slower. Each string pays the fixed cost of about 15 stringi calls. Vectorised passes are 0.6 to 0.85 times Python ftfy 6.3.1's time per value on every benchmark column, before deduplication. Deduplication gives a further 5 to 50 times on columns with repeated values. Evidence: https://github.com/epabarker/r-ftfy/tree/research/vectorisation-speed. Decided in https://github.com/epabarker/r-ftfy/issues/13.

## Consequences

- **Speed target.** Per value, on the committed benchmark columns and the same machine, the package is never slower than Python ftfy 6.3.1, with deduplication not counted.
- **Accepted cost per call.** stringi compiles a pattern on every call, and the frozen badness regex takes about 460 µs to compile. A call on one non-ASCII string therefore costs 0.6 to 1.6 ms, where Python takes 6 to 16 µs. The documentation tells users to call on whole vectors, not per row.
- **No compiled code in v0.1.** It becomes justified only if one of these holds:
  - the column target is missed;
  - `Rprof` shows R-level code, not ICU, above 50% of runtime on a benchmark column;
  - the cost per call is judged unacceptable. The remedy would then be a narrow compiled layer that holds compiled ICU matchers across calls.
- **Encode tables.** They are built at load time from the shipped decode tables, as one `chartr()` pair per codec. Encoding is `chartr()` onto the characters U+0001 to U+00FF, then `iconv()` to latin1, re-marking as UTF-8, then `stri_enc_isutf8()`.
- **U+FEFF-safe functions.** On text, internal code may use only functions measured to keep a leading U+FEFF:
  - stringi: `stri_detect_regex`, `stri_replace_all_regex`, `stri_locate_all_regex`, `stri_trans_nfc`, `stri_enc_isascii`, `stri_enc_isutf8`;
  - base R: `chartr`, `substring`, `nchar`, `paste`, `iconv`, and `gsub` and `grepl` with `fixed = TRUE`.

  `stri_replace_all_fixed`, `stri_sub`, `stri_join_list` and `stri_split_regex` are banned on text. Splicing uses positions from `stri_locate_all_regex()` with base `substring()`.
- **Plans.** Each element's plan is accumulated inside the same passes. Recording it costs nothing measurable.
