# Entry-step registration of `fix_and_explain()`; see helper-entry-step.R.
list(
  # With default options the fixer remove_control_chars removes U+FEFF, so
  # it is switched off here and a leading U+FEFF must come back.
  # test-fix_and_explain.R asserts that the defaults remove it as a
  # recorded step.
  call = function(x) fix_and_explain(x, remove_control_chars = FALSE),
  returns = "character",
  value = function(result) result$text,
  shape = FALSE
)
