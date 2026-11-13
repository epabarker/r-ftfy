# Entry-step registration of `badness()`; see helper-entry-step.R.
list(
  call = function(x) badness(x),
  returns = "integer",
  # "\u00c2 " at the true start is bad; after U+FEFF it is not at the start.
  feff = list(x = c("\u00c2 x", "\ufeff\u00c2 x"), value = c(1L, 0L))
)
