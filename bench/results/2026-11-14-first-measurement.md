# Benchmark against the reference version

A first measurement on the machine the package is developed on. Not the release-gate run: that is issue #51, the maintainer's, on a machine they name.

**WARNING: the ratio is at or above 1 on `names_n1e4` with `fix_encoding()` (1.10), `names_clean95_u1` with `fix_encoding()` (1.49), `notes_n1e4` with `fix_encoding()` (1.24).** The speed target of ADR 0008 is a ratio below 1 on every column.

- Date: 2026-11-14 07:21 UTC
- Commit: 36a90d2265594074a6153d299335c065165896e0
- Machine: Apple M5, 10 cores, aarch64-apple-darwin23
- OS: macOS Golden Gate 27.2.1
- R: 4.6.2
- stringi: 1.8.7, ICU 71.1 (system), Unicode 14.0
- Python: 3.13.5 (CPython), ftfy 6.3.1, Unicode 15.1.0
- Repetitions: 7 (whole column: 3), after one untimed call. Each cell is the median, with the lowest and highest in brackets.
- Outputs: R equals the reference version on all 1,179,000 results compared

## The speed target: time per distinct value, deduplication not counted

Each distinct value of the column once. R: one call `f(values)`. Python: `[ftfy.f(v) for v in values]`.
The ratio is R's median over Python's; its range is R's lowest over Python's highest to R's highest over Python's lowest.

### `fix_text()`

| Column | Distinct values | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 2,000 | 8.06 (7.96 to 8.15) | 6.06 (5.93 to 6.36) | **0.75** | 0.73 to 0.80 | below 1 |
| `names_n1e5` | 20,000 | 8.53 (8.49 to 8.70) | 4.91 (4.88 to 4.94) | **0.58** | 0.56 to 0.58 | below 1 |
| `names_n1e6` | 200,000 | 8.89 (8.86 to 9.00) | 5.13 (5.06 to 5.44) | **0.58** | 0.56 to 0.61 | below 1 |
| `names_clean100_u20` | 20,000 | 8.34 (8.31 to 8.36) | 4.67 (4.65 to 4.72) | **0.56** | 0.56 to 0.57 | below 1 |
| `names_clean50_u20` | 20,000 | 11.94 (11.83 to 12.27) | 7.43 (7.40 to 7.50) | **0.62** | 0.60 to 0.63 | below 1 |
| `names_clean95_u1` | 1,000 | 8.03 (7.94 to 8.08) | 7.79 (7.60 to 7.90) | **0.97** | 0.94 to 1.00 | below 1 |
| `names_clean95_u100` | 100,000 | 8.84 (8.78 to 9.02) | 4.97 (4.94 to 4.99) | **0.56** | 0.55 to 0.57 | below 1 |
| `ascii_n1e5` | 20,000 | 5.32 (5.22 to 5.57) | 0.16 (0.15 to 0.17) | **0.03** | 0.03 to 0.03 | below 1 |
| `notes_n1e4` | 10,000 | 89.87 (89.69 to 90.40) | 82.95 (82.05 to 83.55) | **0.92** | 0.91 to 0.93 | below 1 |

### `fix_encoding()`

| Column | Distinct values | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 2,000 | 2.96 (2.89 to 2.99) | 3.27 (3.19 to 3.28) | **1.10** | 1.07 to 1.13 | **AT OR ABOVE 1** |
| `names_n1e5` | 20,000 | 3.17 (3.15 to 3.19) | 2.40 (2.40 to 2.42) | **0.76** | 0.75 to 0.77 | below 1 |
| `names_n1e6` | 200,000 | 3.36 (3.34 to 3.40) | 2.36 (2.35 to 2.38) | **0.70** | 0.69 to 0.71 | below 1 |
| `names_clean100_u20` | 20,000 | 3.14 (3.13 to 3.16) | 2.25 (2.23 to 2.26) | **0.72** | 0.71 to 0.72 | below 1 |
| `names_clean50_u20` | 20,000 | 4.19 (4.18 to 4.21) | 3.25 (3.22 to 3.26) | **0.78** | 0.77 to 0.78 | below 1 |
| `names_clean95_u1` | 1,000 | 2.93 (2.93 to 2.97) | 4.37 (4.27 to 4.45) | **1.49** | 1.44 to 1.52 | **AT OR ABOVE 1** |
| `names_clean95_u100` | 100,000 | 3.28 (3.28 to 3.31) | 2.34 (2.33 to 2.35) | **0.71** | 0.70 to 0.72 | below 1 |
| `ascii_n1e5` | 20,000 | 1.31 (1.28 to 1.32) | 0.14 (0.14 to 0.14) | **0.10** | 0.10 to 0.11 | below 1 |
| `notes_n1e4` | 10,000 | 30.53 (30.45 to 30.67) | 37.80 (37.72 to 37.94) | **1.24** | 1.23 to 1.25 | **AT OR ABOVE 1** |

## As users call it: the whole column, repeats included

A separate figure, not the speed target. The whole column of n values, the distinct values recycled. R: one call `fix_text(column)`, which fixes each distinct value once. Python: `[ftfy.fix_text(v) for v in column]`, which fixes every value.

| Column | Values (n) | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 10,000 | 7.98 (7.95 to 8.01) | 1.32 (1.31 to 1.34) | **0.17** | 0.16 to 0.17 |  |
| `names_n1e5` | 100,000 | 8.58 (8.52 to 8.76) | 1.11 (1.11 to 1.13) | **0.13** | 0.13 to 0.13 |  |
| `names_n1e6` | 1,000,000 | 8.95 (8.94 to 8.96) | 1.24 (1.18 to 1.24) | **0.14** | 0.13 to 0.14 |  |
| `names_clean100_u20` | 100,000 | 8.32 (8.27 to 8.34) | 1.05 (1.05 to 1.06) | **0.13** | 0.13 to 0.13 |  |
| `names_clean50_u20` | 100,000 | 11.97 (11.95 to 12.19) | 1.62 (1.61 to 1.62) | **0.14** | 0.13 to 0.14 |  |
| `names_clean95_u1` | 100,000 | 8.04 (8.02 to 8.04) | 0.21 (0.21 to 0.21) | **0.03** | 0.03 to 0.03 |  |
| `names_clean95_u100` | 100,000 | 8.76 (8.71 to 8.87) | 4.97 (4.96 to 5.02) | **0.57** | 0.56 to 0.58 |  |
| `ascii_n1e5` | 100,000 | 5.16 (5.15 to 5.18) | 0.11 (0.11 to 0.11) | **0.02** | 0.02 to 0.02 |  |
| `notes_n1e4` | 10,000 | 91.05 (90.43 to 91.06) | 82.38 (81.79 to 83.27) | **0.90** | 0.90 to 0.92 |  |

## Where R's time goes

#### `Rprof` breakdown: `fix_encoding(values)` on the distinct values of `names_n1e4` (ratio 1.10)

1240 calls in 8.0 s (6.5 ms per call), sampled every 10 ms: 758 samples, 7.58 s of sampled time. Shares are of self time: the time spent in a function itself and not in what it calls.

| Where | Share of run time |
|---|---|
| stringi: its C code and ICU | 83.4% |
| base R functions (compiled: chartr, iconv, substring, match, unique, ...) | 9.6% |
| the package's own R code (interpreted) | 5.9% |
| R's garbage collector | 0.4% |
| other (anonymous functions, other packages) | 0.7% |

**ICU side (stringi): 83.4%. R side (everything else): 16.6%.** Of the stringi time, the regex functions (`stri_*_regex`) are 80.1% of run time. ADR 0008's condition for compiled code is R-level code above 50%.

Self time by function, the 12 largest:

| Function | Where | Self time | Share |
|---|---|---|---|
| `stringi::stri_detect_regex` | stringi | 5.98 s | 78.9% |
| `exit_step` | package | 0.19 s | 2.5% |
| `stringi::stri_enc_isascii` | stringi | 0.14 s | 1.8% |
| `repair_encoding_step` | package | 0.13 s | 1.7% |
| `stringi::stri_enc_isutf8` | stringi | 0.11 s | 1.5% |
| `which` | base | 0.08 s | 1.1% |
| `unique.default` | base | 0.08 s | 1.1% |
| `stringi::stri_replace_all_regex` | stringi | 0.07 s | 0.9% |
| `%in%` | base | 0.05 s | 0.7% |
| `chartr` | base | 0.05 s | 0.7% |
| `data.frame` | base | 0.04 s | 0.5% |
| `.set_ops_need_as_vector` | base | 0.04 s | 0.5% |

Total time (the function and everything it calls) of the package's own functions, the 15 largest:

| Function | Total time | Share |
|---|---|---|
| `repair_encoding` | 7.02 s | 92.6% |
| `repair_encoding_step` | 6.87 s | 90.6% |
| `regex_guard` | 6.10 s | 80.5% |
| `regex_detect` | 6.04 s | 79.7% |
| `bind_steps` | 0.34 s | 4.5% |
| `entry_step` | 0.21 s | 2.8% |
| `exit_step` | 0.19 s | 2.5% |
| `entry_stop_at` | 0.12 s | 1.6% |
| `codec_can_encode` | 0.11 s | 1.5% |
| `codec_encode` | 0.10 s | 1.3% |
| `check_config` | 0.08 s | 1.1% |
| `check_options` | 0.08 s | 1.1% |
| `resolve_config` | 0.08 s | 1.1% |
| `decode_utf8` | 0.07 s | 0.9% |
| `translate` | 0.07 s | 0.9% |

#### `Rprof` breakdown: `fix_encoding(values)` on the distinct values of `names_clean95_u1` (ratio 1.49)

1914 calls in 8.0 s (4.2 ms per call), sampled every 10 ms: 770 samples, 7.70 s of sampled time. Shares are of self time: the time spent in a function itself and not in what it calls.

| Where | Share of run time |
|---|---|
| stringi: its C code and ICU | 81.3% |
| base R functions (compiled: chartr, iconv, substring, match, unique, ...) | 12.7% |
| the package's own R code (interpreted) | 4.7% |
| R's garbage collector | 0.4% |
| other (anonymous functions, other packages) | 0.9% |

**ICU side (stringi): 81.3%. R side (everything else): 18.7%.** Of the stringi time, the regex functions (`stri_*_regex`) are 78.4% of run time. ADR 0008's condition for compiled code is R-level code above 50%.

Self time by function, the 12 largest:

| Function | Where | Self time | Share |
|---|---|---|---|
| `stringi::stri_detect_regex` | stringi | 5.94 s | 77.1% |
| `stringi::stri_enc_isascii` | stringi | 0.12 s | 1.6% |
| `stringi::stri_enc_isutf8` | stringi | 0.10 s | 1.3% |
| `repair_encoding` | package | 0.08 s | 1.0% |
| `tryCatch` | base | 0.07 s | 0.9% |
| `which` | base | 0.07 s | 0.9% |
| `add_step` | package | 0.07 s | 0.9% |
| `unique.default` | base | 0.07 s | 0.9% |
| `data.frame` | base | 0.06 s | 0.8% |
| `deparse` | base | 0.06 s | 0.8% |
| `%in%` | base | 0.06 s | 0.8% |
| `stringi::stri_replace_all_regex` | stringi | 0.06 s | 0.8% |

Total time (the function and everything it calls) of the package's own functions, the 15 largest:

| Function | Total time | Share |
|---|---|---|
| `repair_encoding` | 7.19 s | 93.4% |
| `repair_encoding_step` | 6.99 s | 90.8% |
| `regex_guard` | 6.16 s | 80.0% |
| `regex_detect` | 6.10 s | 79.2% |
| `bind_steps` | 0.50 s | 6.5% |
| `entry_step` | 0.31 s | 4.0% |
| `codec_can_encode` | 0.22 s | 2.9% |
| `entry_stop_at` | 0.10 s | 1.3% |
| `add_step` | 0.09 s | 1.2% |
| `fixer_replace_lossy_sequences` | 0.08 s | 1.0% |
| `regex_replace_all` | 0.07 s | 0.9% |
| `codec_encode` | 0.06 s | 0.8% |
| `resolve_config` | 0.06 s | 0.8% |
| `regex_opts` | 0.05 s | 0.6% |
| `translate` | 0.05 s | 0.6% |

#### `Rprof` breakdown: `fix_encoding(values)` on the distinct values of `notes_n1e4` (ratio 1.24)

22 calls in 8.3 s (379.4 ms per call), sampled every 10 ms: 787 samples, 7.87 s of sampled time. Shares are of self time: the time spent in a function itself and not in what it calls.

| Where | Share of run time |
|---|---|
| stringi: its C code and ICU | 96.2% |
| base R functions (compiled: chartr, iconv, substring, match, unique, ...) | 1.8% |
| the package's own R code (interpreted) | 2.0% |
| R's garbage collector | 0.0% |
| other (anonymous functions, other packages) | 0.0% |

**ICU side (stringi): 96.2%. R side (everything else): 3.8%.** Of the stringi time, the regex functions (`stri_*_regex`) are 95.4% of run time. ADR 0008's condition for compiled code is R-level code above 50%.

Self time by function, the 12 largest:

| Function | Where | Self time | Share |
|---|---|---|---|
| `stringi::stri_detect_regex` | stringi | 7.49 s | 95.2% |
| `exit_step` | package | 0.13 s | 1.7% |
| `unique.default` | base | 0.06 s | 0.8% |
| `stringi::stri_enc_isutf8` | stringi | 0.05 s | 0.6% |
| `repair_encoding` | package | 0.02 s | 0.3% |
| `chartr` | base | 0.02 s | 0.3% |
| `grepl` | base | 0.02 s | 0.3% |
| `iconv` | base | 0.02 s | 0.3% |
| `stringi::stri_replace_all_regex` | stringi | 0.02 s | 0.3% |
| `translate` | package | 0.01 s | 0.1% |
| `Encoding` | base | 0.01 s | 0.1% |
| `Encoding<-` | base | 0.01 s | 0.1% |

Total time (the function and everything it calls) of the package's own functions, the 15 largest:

| Function | Total time | Share |
|---|---|---|
| `repair_encoding` | 7.63 s | 97.0% |
| `repair_encoding_step` | 7.61 s | 96.7% |
| `regex_guard` | 7.51 s | 95.4% |
| `regex_detect` | 7.49 s | 95.2% |
| `exit_step` | 0.13 s | 1.7% |
| `entry_step` | 0.05 s | 0.6% |
| `decode_utf8` | 0.04 s | 0.5% |
| `entry_stop_at` | 0.04 s | 0.5% |
| `translate` | 0.03 s | 0.4% |
| `codec_encode` | 0.03 s | 0.4% |
| `fixer_replace_lossy_sequences` | 0.02 s | 0.3% |
| `regex_replace_all` | 0.02 s | 0.3% |

