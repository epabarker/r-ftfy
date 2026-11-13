# Upstream is followed by deliberate moves, and departures may only reduce damage

Each R release promises parity with exactly one reference version: a tagged PyPI release of Python ftfy paired with one Python version (now 6.3.1 on 3.13). The R package keeps its own version numbers and records the upstream version it matches in `DESCRIPTION` (`Config/ftfy/upstream`) and in its documentation. Moving to a new reference version is a deliberate decision with no promised timing. Every behaviour change in the regenerated snapshots is either adopted or recorded as a departure, and every existing departure is checked again. We chose this over following upstream automatically, or copying its version numbers, because upstream has had no release or commit since October 2024. v0.2 is also an R-only feature release, and silently inheriting upstream's output changes would break the promise that a patch release never changes `fix_text()`. Decided in https://github.com/epabarker/r-ftfy/issues/16.

## Consequences

- **The Python version moves only when forced.** It moves when a new upstream release requires a different Python, or when the pinned one can no longer be installed in the `reference` workflow. Either case counts as a move to a new reference version and follows the same steps.
- **Untagged upstream commits are never followed.**
- **A bug fix may depart from reference behaviour, but a new heuristic may not.** A departure is allowed when reference behaviour damages text that wasn't mojibake, loses or corrupts real characters, errors, produces a plan that fails to replay on its own input, or contradicts upstream's own documentation or test cases. Making `fix_text()` repair mojibake it currently misses stays out of scope.
- **Bug-fix departures are on by default**, with no option to restore the reference behaviour. Each one is also reported upstream, and its registry entry links that issue. It is retired when a move to a new reference version brings in upstream's own fix.
- **Bugs that match reference behaviour and aren't damage go upstream**, not into the package.
- **Default output changes only in minor releases.** A move to a new reference version and a new departure each bump at least the minor version, and NEWS lists every changed output with an example. Patch releases never change `fix_text()` output.
