# Entry-step registration of `apply_plan()`; see helper-entry-step.R.
# The plan has no default: the plan with no steps is replayed, which gives
# the text back as the entry step read it.
list(
  call = function(x) apply_plan(x, "none"),
  returns = "character"
)
