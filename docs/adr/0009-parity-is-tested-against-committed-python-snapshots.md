# Parity is tested against committed Python snapshots

Reference behaviour is captured once, by seeded scripts in `data-raw/` that run Python ftfy 6.3.1 on Python 3.13, and the output (texts, plans, `badness`, `is_bad`) is committed as snapshots. R tests compare against those snapshots on every platform, CRAN included. Python runs only in one `reference` workflow, which reruns every generator and fails on any byte difference from what is committed. We chose this over running Python live against R in CI because it keeps Python out of R CMD check, makes every failure reproducible offline, and reuses the regeneration job that the codec tables and patterns already need. Decided in https://github.com/epabarker/r-ftfy/issues/14.

Amended in https://github.com/epabarker/r-ftfy/issues/46: Python also runs in a second workflow, `benchmark`, which times the reference version against the package on the committed benchmark columns. It also fails when the package's output differs from the reference version's on any benchmark value, so a fast wrong answer cannot pass. The maintainer chose to keep that check. The `benchmark` workflow never fails on a speed ratio, and no test of the package runs Python.

## Consequences

- **Fail cases are pinned, not just "not fixed".** The 10 upstream JSON cases marked `fail` must equal Python's captured output exactly, texts and plans. This is stricter than upstream's `xfail` and stricter than the map's parity bar. A change that makes R produce the expected `fixed` text for one of them is a failing test until it is recorded as a departure.
- **Plans are compared step by step** with Python's plans, which upstream's own tests never do.
- **Every departure is listed in one committed registry.** Each entry has its own test asserting R's behaviour, and the comparison accepts a difference only when an entry matches it.
- **The larger corpus never ships.** It lives under `tests/corpus/`, is excluded by `.Rbuildignore`, and its test skips unless the directory is present.
