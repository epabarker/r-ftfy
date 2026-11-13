# Options are named arguments that override a config object

The four core functions (`fix_text`, `fix_and_explain`, `fix_encoding`, `fix_encoding_and_explain`) take `(x, ..., config = ftfy_config())`: named arguments in `...` override the config, and the entry point resolves both into one validated `ftfy_config` object that internal code receives whole. This is upstream's model, it keeps the one-option case short, and it lets settings be saved and shared between calls and, later, passed through the column functions.

The port always honours the four encoding sub-options (`restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8`, `fix_c1_controls`). This is a deliberate departure: Python ftfy 6.3.1 ignores them whenever its `explain` field is false, so `fix_text(t, restore_byte_a0=False)` returns the default result. Output with default options is identical to upstream; do not "fix" this back to match Python.

Decided in https://github.com/epabarker/r-ftfy/issues/8.

## Considered options

- **Plain arguments only.** Rejected: R's partial matching silently accepts a typo such as `uncurl_quote = FALSE`, a positional second argument silently sets the first option, and settings cannot be saved or shared.
- **Config object only.** Rejected: turning one option off needs a nested constructor call, and a saved config cannot be adjusted for a single call.

## Consequences

- Options do not appear in the function signatures or in autocomplete; they are documented on the `ftfy_config` help page.
- Three of upstream's 16 config fields have no R counterpart: `explain` (`fix_text` never returns a plan, `fix_and_explain` always does), `fix_surrogates` (an R string cannot hold a surrogate) and the deprecated alias `fix_entities`. Passing any of them is an unknown-option error.
