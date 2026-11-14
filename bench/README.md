# The benchmark against the reference version

Issue #46, ADR 0008. Nothing here is in the built package.

```
Rscript bench/bench.R --python <Python 3.13 with ftfy 6.3.1>
```

That one command installs the package from this tree into a temporary library, runs it and the reference version on the committed benchmark columns (`bench/columns/`, written by `data-raw/generators/bench_columns.py`), checks that both give the same text for every value, and prints a Markdown report. Without `--python` it takes `FTFY_BENCH_PYTHON`, then `python3`, then `python`. `data-raw/requirements.txt` is the reference version, hash-pinned.

| Option | Default | |
|---|---|---|
| `--out FILE` | none | also write the report to a file |
| `--label TEXT` | `Not the release-gate run.` | the first line of the report |
| `--columns a,b` | all nine | |
| `--reps N` | 7 | timed repetitions on the distinct values |
| `--full-reps N` | 3 | timed repetitions on the whole column |
| `--profile auto`, `always` or `never` | `auto` | `auto` adds the `Rprof` breakdown for every column at 1 or above |
| `--lib DIR` | none | use the package installed in this library instead of installing the tree |

Exit status 0 means the bench ran and every output was equal, whatever the ratio. A ratio at or above 1 is a warning at the top of the report, not a failure. Status 1 means something failed or an output differed.

## What is timed

For each column and each of `fix_text` and `fix_encoding`, the reference version runs and then R, back to back, so both meet the same state of the machine.

| | Python (`bench.py`) | R (`bench.R`) |
|---|---|---|
| Values | the distinct values of the column, each once, as `str` | the same values in the same order, as a UTF-8 character vector |
| Timed | `[ftfy.fix_text(v) for v in values]` | `fix_text(values)`, one call |
| Clock | `time.perf_counter()` | `Sys.time()` |
| Warm-up | the same expression once, untimed | the same call once, untimed |
| Before each repetition, untimed | `gc.collect()` | `gc()` |
| Not timed | starting Python, importing ftfy, reading the file | starting R, loading the package, reading the file |

The time is divided by the number of distinct values. This is "per value, with deduplication not counted" as ticket #41 took it: no value is there twice, so R's deduplication of values gains nothing. R's call is the exported function as a user calls it, so it includes the entry step, `unique()` on values that are already distinct, and for `fix_text()` the deduplication of segments (lines) across values, which is part of how the package works. The reference version is called once per value because that is its only interface.

A cell is the median of the repetitions with the lowest and highest. The ratio is R's median over Python's median.

**The whole column, as users call it,** is a separate table and not the speed target: `fix_text(column)` against `[ftfy.fix_text(v) for v in column]`, where the column is the distinct values recycled to its n. R fixes each distinct value once; Python fixes every value.

## The check of the outputs

The reference version writes what it gave for every distinct value, for both functions. R compares its own result with it, value for value, and every timed repetition on either side must give the result of the warm-up. Any difference fails the run, and the report then says the times mean nothing. No departure is excused: the benchmark values reach none.

## Results

`--out` writes a file fit to commit: the label, the date, the commit, the machine (CPU model, never a host or user name), OS, R, stringi and ICU, Python and ftfy, and the figures of every column. Committed results are in `bench/results/`. For the release gate (issue #51):

```
Rscript bench/bench.R --python <python> --label "Release gate for v0.1, on <machine>." --out bench/results/<date>-release-gate.md
```

## The `Rprof` breakdown

ADR 0008 allows compiled code only if the column target is missed, or `Rprof` shows R-level code above 50% of the run time on a column. `bench.R` adds the breakdown to its report for every column at 1 or above. For any column:

```
Rscript bench/profile.R --column notes_n1e4 --function fix_text
```

Self time is put into five buckets by where the function lives: stringi (its C code and ICU, which `Rprof` cannot tell apart), base R's compiled functions, the package's own R code, the garbage collector, and the rest.

## The cost of one call on one string

ADR 0008 accepts a fixed cost of 0.6 to 1.6 ms for one call on one string that is not plain ASCII (#53). `per-call.R` measures it. It needs no Python:

```
Rscript bench/per-call.R [--out FILE] [--label TEXT] [--reps 301] [--lib DIR]
```

It times one call of `fix_text()` and of `fix_encoding()` on each of five single strings: plain ASCII, accented Latin and Cyrillic that are not mojibake, and two kinds of mojibake. Each cell is the median of `--reps` calls after one untimed call, with the 10th and 90th percentiles.

It then runs the calls again with every call of the package's regex wrappers (`regex_detect`, `regex_locate_all`, `regex_replace_all`) timed, and gives the time and number of calls per pattern. A pattern is named after its file in `data-raw/patterns/`, its codec, or its object in the package. A pattern built at run time is named after the function that used it. A call on no strings is counted separately, because stringi compiles nothing for it. Results are committed in `bench/results/` as `<date>-per-call.md`.

## CI

`.github/workflows/benchmark.yaml` runs the same command, and then `per-call.R`, on an Ubuntu runner on every pull request and every push to the integration branch. It puts both reports in the job summary and uploads them. It never fails on a ratio.
