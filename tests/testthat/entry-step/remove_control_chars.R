# Entry-step registration of `remove_control_chars()`; see helper-entry-step.R.
list(
  call = function(x) remove_control_chars(x),
  returns = "character",
  # The fixer removes U+FEFF wherever it is, so the result shows only that
  # the rest of the text was kept. test-text-fixers.R shows, with the fixer
  # replaced by one that changes nothing, that U+FEFF reached it.
  feff = list(x = c("\ufeffa", "a\ufeff", "a"), value = c("a", "a", "a"))
)
