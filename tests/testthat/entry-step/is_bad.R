# Entry-step registration of `is_bad()`; see helper-entry-step.R.
list(
  call = function(x) is_bad(x),
  returns = "logical",
  # "\u00c2 " at the true start is bad; after U+FEFF it is not at the start.
  feff = list(x = c("\u00c2 x", "\ufeff\u00c2 x"), value = c(TRUE, FALSE))
)
