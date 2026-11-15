# Benchmark against the reference version

Release gate for v0.1, on a Lenovo ThinkPad X1 Carbon Gen 10.

**The ratio is below 1 on every column, for both functions.**

- Date: 2026-11-15 11:23 UTC
- Commit: ee8b0dd5f023cabec70ba77fe4bb62567f8cec8a (with uncommitted changes)
- Machine: 12th Gen Intel(R) Core(TM) i7-1260P, 16 cores, x86_64-redhat-linux-gnu
- OS: Fedora Linux 45 (Workstation Edition)
- R: 4.6.2
- stringi: 1.8.9, ICU 78.3 (system), Unicode 17.0
- Python: 3.13.17 (CPython), ftfy 6.3.1, Unicode 15.1.0
- Repetitions: 7 (whole column: 3), after one untimed call. Each cell is the median, with the lowest and highest in brackets.
- Outputs: R equals the reference version on all 1,179,000 results compared

## The speed target: time per distinct value, deduplication not counted

Each distinct value of the column once. R: one call `f(values)`. Python: `[ftfy.f(v) for v in values]`.
The ratio is R's median over Python's; its range is R's lowest over Python's highest to R's highest over Python's lowest.

### `fix_text()`

| Column | Distinct values | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 2,000 | 13.62 (13.55 to 13.88) | 7.62 (7.48 to 9.55) | **0.56** | 0.54 to 0.71 | below 1 |
| `names_n1e5` | 20,000 | 14.58 (14.52 to 14.64) | 5.41 (5.39 to 5.58) | **0.37** | 0.37 to 0.38 | below 1 |
| `names_n1e6` | 200,000 | 15.77 (15.09 to 15.93) | 6.27 (6.13 to 6.47) | **0.40** | 0.38 to 0.43 | below 1 |
| `names_clean100_u20` | 20,000 | 14.36 (14.21 to 14.85) | 5.22 (5.17 to 5.24) | **0.36** | 0.35 to 0.37 | below 1 |
| `names_clean50_u20` | 20,000 | 20.33 (20.15 to 20.46) | 8.73 (8.65 to 8.92) | **0.43** | 0.42 to 0.44 | below 1 |
| `names_clean95_u1` | 1,000 | 13.64 (13.46 to 14.66) | 9.89 (9.71 to 10.99) | **0.73** | 0.66 to 0.82 | below 1 |
| `names_clean95_u100` | 100,000 | 14.89 (14.70 to 17.60) | 5.83 (5.76 to 6.61) | **0.39** | 0.33 to 0.45 | below 1 |
| `ascii_n1e5` | 20,000 | 11.22 (10.43 to 13.04) | 0.43 (0.43 to 0.45) | **0.04** | 0.03 to 0.04 | below 1 |
| `notes_n1e4` | 10,000 | 195.16 (156.71 to 207.06) | 63.28 (61.92 to 118.17) | **0.32** | 0.30 to 0.75 | below 1 |

### `fix_encoding()`

| Column | Distinct values | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 2,000 | 4.72 (4.52 to 5.14) | 2.92 (2.86 to 3.04) | **0.62** | 0.56 to 0.67 | below 1 |
| `names_n1e5` | 20,000 | 5.15 (5.08 to 5.24) | 1.53 (1.47 to 1.66) | **0.30** | 0.28 to 0.33 | below 1 |
| `names_n1e6` | 200,000 | 5.55 (5.49 to 6.19) | 1.60 (1.55 to 1.97) | **0.29** | 0.25 to 0.36 | below 1 |
| `names_clean100_u20` | 20,000 | 5.15 (5.05 to 7.30) | 1.30 (1.28 to 1.34) | **0.25** | 0.17 to 0.27 | below 1 |
| `names_clean50_u20` | 20,000 | 7.08 (7.06 to 7.11) | 2.79 (2.76 to 2.80) | **0.39** | 0.39 to 0.40 | below 1 |
| `names_clean95_u1` | 1,000 | 4.95 (4.89 to 4.99) | 4.04 (3.91 to 4.69) | **0.82** | 0.78 to 0.96 | below 1 |
| `names_clean95_u100` | 100,000 | 5.70 (5.38 to 6.35) | 1.56 (1.47 to 1.58) | **0.27** | 0.23 to 0.29 | below 1 |
| `ascii_n1e5` | 20,000 | 2.69 (2.67 to 2.71) | 0.78 (0.68 to 1.34) | **0.29** | 0.25 to 0.50 | below 1 |
| `notes_n1e4` | 10,000 | 46.00 (42.22 to 49.10) | 3.71 (3.59 to 4.55) | **0.08** | 0.07 to 0.11 | below 1 |

## As users call it: the whole column, repeats included

A separate figure, not the speed target. The whole column of n values, the distinct values recycled. R: one call `fix_text(column)`, which fixes each distinct value once. Python: `[ftfy.fix_text(v) for v in column]`, which fixes every value.

| Column | Values (n) | Python, us per value | R, us per value | R / Python | Range of the ratio | |
|---|---|---|---|---|---|---|
| `names_n1e4` | 10,000 | 14.04 (13.94 to 22.66) | 1.71 (1.69 to 1.72) | **0.12** | 0.07 to 0.12 |  |
| `names_n1e5` | 100,000 | 15.87 (15.01 to 16.79) | 1.37 (1.36 to 1.45) | **0.09** | 0.08 to 0.10 |  |
| `names_n1e6` | 1,000,000 | 18.78 (15.53 to 19.09) | 1.59 (1.57 to 1.66) | **0.08** | 0.08 to 0.11 |  |
| `names_clean100_u20` | 100,000 | 14.08 (13.89 to 14.77) | 1.31 (1.30 to 1.49) | **0.09** | 0.09 to 0.11 |  |
| `names_clean50_u20` | 100,000 | 21.50 (21.01 to 22.03) | 1.99 (1.99 to 2.00) | **0.09** | 0.09 to 0.10 |  |
| `names_clean95_u1` | 100,000 | 14.05 (13.94 to 14.65) | 0.37 (0.37 to 0.38) | **0.03** | 0.03 to 0.03 |  |
| `names_clean95_u100` | 100,000 | 20.75 (16.19 to 23.21) | 7.08 (7.02 to 11.83) | **0.34** | 0.30 to 0.73 |  |
| `ascii_n1e5` | 100,000 | 10.73 (10.55 to 14.75) | 0.34 (0.33 to 0.37) | **0.03** | 0.02 to 0.03 |  |
| `notes_n1e4` | 10,000 | 142.09 (137.59 to 143.98) | 54.64 (52.33 to 55.32) | **0.38** | 0.36 to 0.40 |  |

