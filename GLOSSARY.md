# ftfy for R

Repairing mojibake and related damage in text, as a port of Python ftfy. This glossary fixes the words used for how a repair is described and repeated.

## Language

**Fixer**:
A named transformation that repairs one kind of damage, such as `uncurl_quotes` or `restore_byte_a0`. Most fixers take text and return text; a few work on bytes in the middle of an encoding repair.
_Avoid_: fix, cleaner, filter

**Step**:
One recorded action in a repair: an action (`encode`, `decode`, `transcode`, `apply` or `normalize`) paired with a parameter naming a codec, a fixer or a normalisation form.
_Avoid_: explanation step, operation

**Plan**:
The ordered sequence of steps that turned one input string into its fixed text. A plan may have no steps, and a missing input has a missing plan, which is not the same as a plan with no steps.
_Avoid_: explanation, recipe

**Replay**:
Applying a plan's steps in order to a string, with no detection of what is wrong with it. A replay fails when a step cannot be carried out on that string.
_Avoid_: re-fix, re-run
