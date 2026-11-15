# A decoded NUL is dropped

When the `utf-8-variants` decoder meets `C0 80`, Java's encoding of U+0000, it produces nothing for those two bytes. Python ftfy 6.3.1 produces U+0000, which an R string cannot hold by any route. This is a deliberate departure; do not change it to fail the decode or to produce U+FFFD.

Example: the mojibake `À€` re-encodes in `sloppy-windows-1252` to `C0 80`. Amended in https://github.com/epabarker/r-ftfy/issues/33: on its own that string is not bad enough for the reference version to repair, and it comes back unchanged. `nullÀ€separated` shows the departure; the reference version repairs it with the plan `encode sloppy-windows-1252 > decode utf-8-variants > apply remove_control_chars`.

| | Python ftfy 6.3.1 | This package |
|---|---|---|
| `fix_encoding()` | U+0000 in the output | nothing in its place |
| `fix_text()`, default options | U+0000 removed by `remove_control_chars` | same text as Python |
| `fix_text(remove_control_chars = FALSE)` | U+0000 in the output | nothing in its place |

We considered two other options. Failing the decode would leave the mojibake in place, and U+FFFD would leave a character that Python's output doesn't have. Both would change what `fix_text()` returns with default options. Dropping the NUL is the only choice that keeps default `fix_text()` identical to reference behaviour.

Decided in https://github.com/epabarker/r-ftfy/issues/12.

## Consequences

- `apply_plan()` replays `decode utf-8-variants` under the same rule, so a plan from `fix_and_explain()` replays to the same text.
- Amended in https://github.com/epabarker/r-ftfy/issues/40: plans differ as well as the mechanism. The reference version's plan ends with `apply remove_control_chars`, the step that removes the U+0000. Here there is nothing for it to remove, so the plan has no such step. The texts are equal, and the package's plan replays to its text.
- The badness heuristic scores the decoded segment with one control character fewer than Python does. The parity tests would show it if this ever changes which repair is chosen.
- A `C0 80` inside an *input* string is invalid UTF-8 and is an error at entry. This decision covers only bytes the decoder makes by re-encoding text.
