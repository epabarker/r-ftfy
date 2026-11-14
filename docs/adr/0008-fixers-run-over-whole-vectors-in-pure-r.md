# Fixers run over whole vectors in pure R

`fix_text()` and the other core functions never loop over strings in R. Each input is split into segments, and all segments of the whole vector are flattened into one vector. Each fixer then runs once over every segment still changing, and only the segments that changed go round the loop again. Before that, the input is deduplicated (`unique()`, then `match()` back), and a single regex screen skips any value that no default fixer can change: printable ASCII with no `&`.

We chose this because a per-string port is 70 to 100 times slower. Each string pays the fixed cost of about 15 stringi calls. Vectorised passes are 0.6 to 0.85 times Python ftfy 6.3.1's time per value on every benchmark column, before deduplication. Deduplication gives a further 5 to 50 times on columns with repeated values. Evidence: https://github.com/epabarker/r-ftfy/tree/research/vectorisation-speed. Decided in https://github.com/epabarker/r-ftfy/issues/13.

## Consequences

- **Speed target.** Per value, on the committed benchmark columns and the same machine, the package is never slower than Python ftfy 6.3.1, with deduplication not counted. Amended in https://github.com/epabarker/r-ftfy/issues/27: the target covers `fix_encoding()` as well as `fix_text()`. The first measurement ([#46](https://github.com/epabarker/r-ftfy/issues/46)) has `fix_text()` below 1 on every column. `fix_encoding()` is at or above 1 on three columns, on both the development machine and the CI runner:
  - on long text, because ICU runs the badness pattern about 1.3 times slower than Python's `re`;
  - on columns of a few thousand distinct values or fewer, because of the cost per call below.

  For v0.1 the target is met by `fix_text()` alone, and bringing `fix_encoding()` under it follows the release ([#52](https://github.com/epabarker/r-ftfy/issues/52)).

  Amended in [#52](https://github.com/epabarker/r-ftfy/issues/52), which made the target met by both functions. The first cause above was a misdiagnosis. Five of the badness pattern's 37 branches begin with an item that can match ASCII, so the engine tried every branch at every ASCII letter. Python's `re` does the same work a little faster. The detection of mojibake now runs a cheap screen first and then a form of the pattern in which every branch starts on non-ASCII (ADR 0005). Both come from upstream's pattern, and neither needs compiled code. The spike's measurements are in https://github.com/epabarker/r-ftfy/issues/52#issuecomment-6877735470. The measurement after the change is `bench/results/2026-11-14-after-52.md`.
- **Accepted cost per call.** stringi compiles a pattern on every call, and the frozen badness regex takes about 460 µs to compile. A call on one non-ASCII string therefore costs 0.6 to 1.6 ms, where Python takes 6 to 16 µs. The documentation tells users to call on whole vectors, not per row. Amended in https://github.com/epabarker/r-ftfy/issues/27: as built, one `fix_text()` call makes 41 regex calls, 4 of them the badness pattern. On the development machine it costs 0.8 to 2.1 ms on one non-ASCII string, above the range accepted here, and the documentation states that figure. Bringing it back within the range is [#53](https://github.com/epabarker/r-ftfy/issues/53). Measured after [#52](https://github.com/epabarker/r-ftfy/issues/52) on the same machine, it costs 0.4 to 1.3 ms, and one `fix_encoding()` call costs 0.16 to 0.75 ms. Amended in [#53](https://github.com/epabarker/r-ftfy/issues/53): that is within the accepted range, and no other figure is accepted. `bench/per-call.R` measures the cost and breaks it down by regex call, and the benchmark workflow runs it on the runner. The development machine's result is `bench/results/2026-11-14-per-call.md`.
- **No compiled code in v0.1.** It becomes justified only if one of these holds:
  - the column target is missed;
  - `Rprof` shows R-level code, not ICU, above 50% of runtime on a benchmark column;
  - the cost per call is judged unacceptable. The remedy would then be a narrow compiled layer that holds compiled ICU matchers across calls.
- **Encode tables.** They are built at load time from the shipped decode tables, as one `chartr()` pair per codec. Encoding is `chartr()` onto the characters U+0001 to U+00FF, then `iconv()` to latin1, re-marking as UTF-8, then `stri_enc_isutf8()`.
- **U+FEFF-safe functions.** On text, internal code may use only functions measured to keep a leading U+FEFF:
  - stringi: `stri_detect_regex`, `stri_replace_all_regex`, `stri_locate_all_regex`, `stri_trans_nfc`, `stri_enc_isascii`, `stri_enc_isutf8`;
  - base R: `chartr`, `substring`, `nchar`, `paste`, `iconv`, and `gsub` and `grepl` with `fixed = TRUE`.

  `stri_replace_all_fixed`, `stri_sub`, `stri_join_list` and `stri_split_regex` are banned on text. Splicing uses positions from `stri_locate_all_regex()` with base `substring()`.

  Amended in https://github.com/epabarker/r-ftfy/issues/27. These changes were made while building v0.1, and each is covered by tests that a leading U+FEFF and astral characters survive:
  - **Cutting by byte position.** `substring()` by character position is quadratic on one long non-ASCII string. Splicing and cutting into segments therefore take positions from `utf8ToInt()`, turn them into byte offsets, and cut with `substring()` on the string re-marked as bytes ([#36](https://github.com/epabarker/r-ftfy/issues/36), [#41](https://github.com/epabarker/r-ftfy/issues/41)). On 1,000,000 characters with 50,000 matches, a splice went from 44 s to 0.05 s.
  - **More functions measured safe:** `utf8ToInt`, `intToUtf8`, `stri_trans_nfd`, `stri_trans_nfkc` and `stri_trans_nfkd` on text. `strsplit` and `regexpr` with `fixed = TRUE` are used only on ASCII plan text and on bytes.
  - **`chartr()` has two weaknesses.**
    - It refuses text holding U+FFFE or U+FFFF; such text is translated around those two characters ([#44](https://github.com/epabarker/r-ftfy/issues/44)).
    - In a Latin-1 session it mistranslated ASCII strings when mapping to a character outside Latin-1: byte `1A` to U+FFFD came out empty. Codec tables go through a wrapper that avoids this ([#33](https://github.com/epabarker/r-ftfy/issues/33)).
- **Plans.** Each element's plan is accumulated inside the same passes. Recording it costs nothing measurable.
