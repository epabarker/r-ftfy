# Column repair returns a plain vector, and the report comes from a separate function

Column-aware repair has two exports with the same arguments as the core functions, `(x, ..., config = ftfy_config())`. `fix_column()` returns a plain character vector shaped like `fix_text()`'s, so `df$x <- fix_column(df$x)` works. `diagnose_encoding()` returns the cause report, an S3 list of class `ftfy_cause_report`, and never repairs. Both are deterministic, so the report describes exactly what `fix_column()` does with the same arguments, including one row per overridden element (`element`, `input`, `fix_text`, `text`, `reason`). Getting both costs two passes. That is accepted.

Decided in https://github.com/epabarker/r-ftfy/issues/26.

## Considered options

- **The report as an attribute on the returned vector.** Rejected after a probe on R 4.6.2:
  - `[`, `c()`, `paste0()`, `ifelse()` and a CSV round trip drop it;
  - `filter()` and `arrange()` keep it, so its element numbers then point at the wrong rows;
  - a bare vector prints the whole report beneath it.
- **A classed character vector.** Rejected: `bind_rows()` refuses to combine it with plain character, and fixing that needs vctrs, a second hard dependency.
- **A list of `text` and `report`**, or a third `fix_column_and_explain()`. Rejected: the first breaks `df$x <- fix_column(df$x)`, and the second adds an export for something two calls already give.

## Consequences

- "Every override is reported" is met by `diagnose_encoding(x)$overrides`. `fix_column()` also emits a classed message (`ftfy_override_message`) when it overrides anything. Suppressing the message hides the notice but not the data, so it is not an off switch.
- The report's fields are API. Its printed wording is not.
- There is no encoding-only column function. A config with the text fixers off gives the same result.
