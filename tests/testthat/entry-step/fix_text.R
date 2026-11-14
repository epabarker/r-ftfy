# Entry-step registration of `fix_text()`; see helper-entry-step.R.
list(
  # With default options the fixer remove_control_chars removes U+FEFF, so
  # it is switched off here and a leading U+FEFF must come back.
  # test-fix_text.R asserts that the defaults remove it.
  call = function(x) fix_text(x, remove_control_chars = FALSE),
  returns = "character"
)
