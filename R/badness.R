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
#' Call these on a whole vector, not once per string: a call of `badness()`
#' has a fixed cost of about half a millisecond, and so does a call of
#' `is_bad()` when any string in it could be mojibake.
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8 or is marked as bytes. A logical vector that
#'   is all `NA` is taken as missing strings.
#'
#' @return `badness()` returns an integer vector and `is_bad()` a logical
#'   vector, each as long as `x` and with its `names`, `dim` and `dimnames`.
#'   A missing string gives `NA`.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "caf\u00e9", NA)
#' badness(x)
#' is_bad(x)
#' @export
badness <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(regex_count(x, patterns[["BADNESS_RE"]]), shape)
}

#' @rdname badness
#' @export
is_bad <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(detect_bad(x), shape)
}

# Does each string hold a match of BADNESS_RE? `NA` for a missing string.
# The answer of `regex_detect(x, patterns[["BADNESS_RE"]])`, from the two
# patterns derived from it (data-raw/generators/_badness.py, #52): a string
# the screen does not match cannot match it, and the detect form, which
# matches the same strings, runs only on those the screen does match. That
# saves BADNESS_RE's compile, about 0.4 ms a call, when no string passes
# the screen, and the detect form lets ICU skip ASCII text. Counting and
# locating need BADNESS_RE itself.
detect_bad <- function(x) {
  bad <- logical(length(x))
  bad[is.na(x)] <- NA
  screened <- which(regex_detect(x, patterns[["BADNESS_SCREEN_RE"]]))
  if (length(screened) > 0L) {
    bad[screened] <- regex_detect(x[screened], patterns[["BADNESS_DETECT_RE"]])
  }
  bad
}
