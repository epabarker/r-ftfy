# The shared entry step. Every export that takes text calls
# `entry_step(x)` before any other work, and may then assume a character
# vector of valid UTF-8 strings and `NA`s.
#
# This is the minimal form: the complete rules (marks, attributes, the
# all-`NA` logical vector) are in the resolution of issue #12.

entry_step <- function(x) {
  if (!is.character(x)) {
    stop(
      "`x` must be a character vector, not ", describe_type(x), ". ",
      "Convert it with `as.character()` first.",
      call. = FALSE
    )
  }
  x <- enc2utf8(x)
  invalid <- which(!stringi::stri_enc_isutf8(x))
  if (length(invalid) > 0L) {
    shown <- paste(utils::head(invalid, 5L), collapse = ", ")
    stop(
      "`x` holds invalid UTF-8 in ", length(invalid), " of ", length(x),
      " elements (first at: ", shown, "). ",
      "The data was probably read with the wrong codec; ",
      "fix the import instead of repairing the result.",
      call. = FALSE
    )
  }
  x
}

describe_type <- function(x) {
  if (is.null(x)) {
    return("NULL")
  }
  if (is.object(x)) {
    return(paste0("an object of class <", class(x)[[1L]], ">"))
  }
  paste0("of type <", typeof(x), ">")
}
