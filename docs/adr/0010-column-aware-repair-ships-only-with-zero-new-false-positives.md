# Column-aware repair ships only with zero new false positives on a held-out synthetic corpus

Column-aware repair is evaluated on synthetic columns, not real data. Each column is generated with ground truth per row: the clean value, the corrupted value and the true plan. A release is blocked by any new false positive: a value that per-value `fix_text()` gets right but column-aware repair gets wrong, or that `fix_text()` leaves unrepaired but column-aware repair changes to something other than its reachable target. There is no tolerance rate. The check runs on a held-out corpus whose seed changes at each minor release, kept apart from the development corpus the heuristics are tuned on. We chose zero over a rate bound because "never worse than `fix_text()`" is the whole promise of the feature, and with exact ground truth a non-zero allowance has no principled value. The held-out split stops that zero from meaning only that we tuned until our own data stopped failing. Decided in https://github.com/epabarker/r-ftfy/issues/15.

## Consequences

- **Synthetic, so generated with outside code.** The corpus is corrupted with CPython's codecs and ftfy's sloppy codecs, never the package's own tables, so a wrong table entry can't corrupt and repair consistently and go unnoticed.
- **Outside text, licence-gated.** Source text comes from outside lists under public-domain, CC0, permissive or attribution-only licences only, downloaded at pinned checksums. Only the generated columns are committed. Self-written lists are allowed for categorical values alone.
- **Lossy rows are scored against what is reachable**, not against the lost original, unless lost-character recovery is switched on.
- **A miss turned into wrong text counts too.** Amended in https://github.com/epabarker/r-ftfy/issues/21: at runtime a value `fix_text()` misses looks the same as a clean one, so a row `fix_text()` leaves unrepaired that column-aware repair changes to anything but its reachable target blocks release like any other new false positive.
- **Real data never decides a release.** An optional local script reports aggregate counts on real columns. It commits no values.
