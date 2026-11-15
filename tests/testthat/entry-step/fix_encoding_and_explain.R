# Entry-step registration of `fix_encoding_and_explain()`; see helper-entry-step.R.
list(
  call = function(x) fix_encoding_and_explain(x),
  returns = "character",
  value = function(result) result$text,
  shape = FALSE
)
