# The cost of one call on one string

Release gate for v0.1, on a Lenovo ThinkPad X1 Carbon Gen 10.

- Date: 2026-11-15 11:25 UTC
- Commit: ee8b0dd5f023cabec70ba77fe4bb62567f8cec8a (with uncommitted changes)
- Machine: 12th Gen Intel(R) Core(TM) i7-1260P, 16 cores, x86_64-redhat-linux-gnu
- OS: Fedora Linux 45 (Workstation Edition)
- R: 4.6.2
- stringi: 1.8.9, ICU 78.3 (system), Unicode 17.0
- Repetitions: 301 calls on each string, after one untimed call.

ADR 0008 accepts 0.6 to 1.6 ms for a call on one string that is not plain ASCII.

| String | Written as |
|---|---|
| `ascii` | `"plain text"` |
| `accented` | `"caf\u00e9 au lait"` |
| `cyrillic` | `"\u043f\u0440\u0438\u0432\u0435\u0442"` |
| `mojibake` | `"caf\u00c3\u00a9"` |
| `mojibake quote` | `"it\u00e2\u20ac\u2122s"` |

## Time of one call, ms

The median, with the 10th and 90th percentiles in brackets.

| Function | `ascii` | `accented` | `cyrillic` | `mojibake` | `mojibake quote` |
|---|---|---|---|---|---|
| `fix_text()` | 0.106 (0.102 to 0.124) | 0.864 (0.821 to 0.934) | 1.485 (1.372 to 1.678) | 2.252 (2.107 to 2.740) | 2.300 (2.204 to 2.831) |
| `fix_encoding()` | 0.279 (0.264 to 0.332) | 0.947 (0.284 to 1.223) | 0.971 (0.869 to 1.138) | 1.256 (1.141 to 3.301) | 1.314 (1.250 to 1.437) |

## Where the time goes: regex calls by pattern

Each cell is the time in that pattern's calls per call of the function, in ms, with the number of calls in brackets; a call on no strings at all is not counted, and compiles nothing. The time is taken with every regex call timed, so the totals run a little above the times above. "Outside regex calls" is the rest of the call.

### `fix_text()`

| Pattern | `ascii` | `accented` | `cyrillic` | `mojibake` | `mojibake quote` |
|---|---|---|---|---|---|
| `ALTERED_UTF8_RE` |  |  |  | 0.028 (1) | 0.027 (1) |
| `ANSI_RE` |  | 0.032 (1) | 0.031 (1) | 0.060 (2) | 0.060 (2) |
| `BADNESS_DETECT_RE` |  |  | 0.578 (1) | 0.562 (1) | 0.560 (1) |
| `BADNESS_SCREEN_RE` |  | 0.020 (1) | 0.018 (1) | 0.061 (3) | 0.061 (2) |
| built in `could_change()` | 0.032 (1) | 0.069 (2) | 0.067 (2) | 0.067 (2) | 0.067 (2) |
| built in `fixer_remove_control_chars()` |  | 0.032 (1) | 0.032 (1) | 0.082 (2) | 0.064 (2) |
| built in `splice_matches()` |  | 0.056 (2) | 0.059 (2) | 0.108 (4) | 0.124 (4) |
| `C1_CONTROL_RE` |  | 0.021 (1) | 0.025 (1) | 0.040 (2) | 0.041 (2) |
| `DOUBLE_QUOTE_RE` |  | 0.020 (1) | 0.019 (1) | 0.052 (2) | 0.035 (2) |
| `latin-1 cannot_encode` |  |  |  | 0.033 (1) | 0.033 (1) |
| `LOSSY_UTF8_RE` |  |  |  |  | 0.042 (1) |
| `SINGLE_QUOTE_RE` |  | 0.014 (1) | 0.015 (1) | 0.027 (2) | 0.028 (2) |
| `sloppy-windows-1252 cannot_encode` |  |  |  |  | 0.031 (1) |
| **All regex calls** | **0.032 (1)** | **0.264 (10)** | **0.845 (11)** | **1.119 (22)** | **1.174 (23)** |
| Calls on no strings, not counted | 0 | 1 | 1 | 3 | 4 |
| Outside regex calls | 0.074 | 0.600 | 0.640 | 1.133 | 1.126 |

### `fix_encoding()`

| Pattern | `ascii` | `accented` | `cyrillic` | `mojibake` | `mojibake quote` |
|---|---|---|---|---|---|
| `ALTERED_UTF8_RE` |  |  |  | 0.027 (1) | 0.027 (1) |
| `BADNESS_DETECT_RE` |  |  | 0.569 (1) | 0.556 (1) | 0.553 (1) |
| `BADNESS_SCREEN_RE` |  | 0.021 (1) | 0.027 (1) | 0.048 (2) | 0.046 (2) |
| `latin-1 cannot_encode` |  |  |  | 0.033 (1) | 0.032 (1) |
| `LOSSY_UTF8_RE` |  |  |  |  | 0.042 (1) |
| `sloppy-windows-1252 cannot_encode` |  |  |  |  | 0.031 (1) |
| **All regex calls** | **0.000 (0)** | **0.021 (1)** | **0.596 (2)** | **0.664 (5)** | **0.732 (7)** |
| Calls on no strings, not counted | 1 | 0 | 0 | 1 | 1 |
| Outside regex calls | 0.279 | 0.925 | 0.376 | 0.592 | 0.581 |

