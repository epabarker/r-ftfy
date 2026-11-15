# Matcher for the departure `apply-plan-replays-normalize`: the reference
# version's apply_plan() raised its error for a `normalize` step, and R
# replayed the plan and gave a text.
#
# A snapshot of the reference version's apply_plan() holds, where it
# raised, the exception as `<type>: <message>`. This is the only such
# reference the matcher accepts.
function(difference) {
  identical(difference$fun, "apply_plan") &&
    identical(difference$reference, "ValueError: Unknown plan step: normalize") &&
    is.character(difference$actual) &&
    length(difference$actual) == 1L &&
    !is.na(difference$actual)
}
