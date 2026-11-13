# Derived from python-ftfy v6.3.1, ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Detect text that looks like mojibake
#'
#' `badness()` counts the character sequences in each string that are far
#' more likely to be mojibake than intended text. `is_bad()` says whether
#' there is at least one. Neither changes the text.
#'
#' Both give what Python ftfy 6.3.1 gives on Python 3.13. The longer a
#' string is, the more likely it is to hold one such sequence by chance.
#'
#' Call these on a whole vector, not once per string: each call has a fixed
#' cost of about half a millisecond.
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8.
#'
#' @return `badness()` returns an integer vector and `is_bad()` a logical
#'   vector, each as long as `x`. A missing string gives `NA`.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "caf\u00e9", NA)
#' badness(x)
#' is_bad(x)
#' @export
badness <- function(x) {
  x <- entry_step(x)
  regex_count(x, patterns[["BADNESS_RE"]])
}

#' @rdname badness
#' @export
is_bad <- function(x) {
  x <- entry_step(x)
  regex_detect(x, patterns[["BADNESS_RE"]])
}
