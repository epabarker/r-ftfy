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

**Codec**:
A named, fixed mapping between bytes and characters that a step can encode with or decode with. Each codec has exactly one name.
_Avoid_: encoding (as a noun for the mapping), charset, converter

**Hole**:
A byte that a codec assigns no character to. Decoding a hole fails.
_Avoid_: gap, unassigned byte, undefined byte

**Sloppy codec**:
A codec with no holes, made from a Windows codec by giving each hole the character with the same number as the byte. It decodes any bytes without failing.
_Avoid_: lenient codec, permissive codec

**Reference behaviour**:
What Python ftfy 6.3.1 does when run on the reference Python. The package's correctness is judged against it.
_Avoid_: upstream behaviour, Python behaviour

**Departure**:
A deliberate, recorded difference from reference behaviour, which must not be changed back to match.
_Avoid_: known bug, divergence, deviation
