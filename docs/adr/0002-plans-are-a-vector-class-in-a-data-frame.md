# Plans are a vector class, returned as a data frame column

`fix_and_explain()` and `fix_encoding_and_explain()` return a data frame with one row per input and two columns: `text` and `plan`, where `plan` is a vector of class `ftfy_plan` holding one plan per element. Upstream returns one `(text, list of (action, parameter) pairs)` tuple for one string; R works on whole vectors, and a plan that is a single value can be printed on one line, compared with `==`, counted with `table()` and passed straight to `apply_plan()`, which is also what column-aware repair in v0.2 needs to find a column's dominant plan.

Each plan has a text form, `encode latin-1 > decode utf-8`, that is a documented, stable format: `as.character()` returns it and `ftfy_plan()` turns it back into the same plan. A plan with no steps is written `none`, not the empty string, because CSV readers commonly read an empty field as missing and a missing plan is a different thing. How the class stores a plan is not part of the contract. Every plan converts to and from upstream's list of pairs without loss.

Decided in https://github.com/epabarker/r-ftfy/issues/9.

## Considered options

- **Bare lists, as upstream.** Rejected: a five-element vector prints as thirty lines, and comparing or counting plans needs hand-written code to build a key from each list.
- **One long data frame of steps.** Rejected: a plan is then several rows rather than one value, and inputs with no steps have no rows, so a clean value and a missing one look the same. The long form is still available from `plan_steps()`.

## Consequences

- Two more exports, `ftfy_plan()` and `plan_steps()`, making 19 in v0.1.
- `apply_plan()` replays `normalize` steps. Python ftfy 6.3.1 emits them from `fix_and_explain` but its own `apply_plan` raises `Unknown plan step: normalize`. This is a deliberate departure so that every plan the package returns can be replayed; do not "fix" it back.
- Plans keep steps that changed nothing, exactly as upstream records them (`fix_and_explain("a\u0081b")` returns the text unchanged with the plan `transcode fix_c1_controls`). A plan with no steps means the text is unchanged; unchanged text does not mean a plan with no steps. Do not drop such steps: plans are compared against Python's.
- Exported `apply_plan()` raises an error when a replay fails, as upstream does. The unexported replay it is built on returns `NA` for each element that fails, and that is the function v0.2 calls.
