# The shared entry step (the resolution of issue #12, ADR 0006). Every
# export that takes text starts and ends like this:
#
#   shape <- entry_shape(x)
#   x <- entry_step(x)
#   ...                          # work on a bare character vector
#   exit_step(result, shape)
#
# After `entry_step()`, internal code may assume a character vector with no
# attributes whose elements are valid UTF-8 strings (marked UTF-8, or ASCII)
# and `NA`s. `exit_step()` puts `names`, `dim` and `dimnames` of the input
# on a result that runs parallel to it; an export that returns a data frame
# leaves both shape calls out.
#
# A new export also joins the entry-step test set with a file of its own:
# see tests/testthat/helper-entry-step.R.

# Returns the texts of `x` as a bare character vector of valid UTF-8, or
# raises an error that says what to do.
entry_step <- function(x) {
  # A column that is all `NA` is read as logical by `read.csv()` and others.
  if (all_na_logical(x)) {
    return(rep(NA_character_, length(x)))
  }
  if (!is.character(x)) {
    stop(
      "`x` must be a character vector, not ", describe_type(x), ". ",
      "Convert it with `as.character()` first.",
      call. = FALSE
    )
  }
  attributes(x) <- NULL

  # Each string is converted by its mark. ASCII and UTF-8-marked strings
  # are taken as they are.
  mark <- Encoding(x)
  entry_stop_at(
    which(mark == "bytes"), length(x),
    "strings marked as bytes",
    "Say how the bytes are to be read with `Encoding<-`, ",
    "or convert them with `iconv()`."
  )
  latin1 <- which(mark == "latin1")
  if (length(latin1) > 0L) {
    x[latin1] <- read_latin1_mark(x[latin1])
  }
  # An unmarked string that is not ASCII is in the session's native
  # encoding, which base R knows and stringi can disagree with.
  native <- which(mark == "unknown" & !stringi::stri_enc_isascii(x))
  if (length(native) > 0L) {
    x[native] <- read_native(x[native])
  }

  # A mark is a claim about the bytes, not a guarantee.
  entry_stop_at(
    which(!stringi::stri_enc_isutf8(x)), length(x),
    "invalid UTF-8",
    "The data was probably read with the wrong codec; ",
    "fix the import instead of repairing the result."
  )
  x
}

# The attributes of the input that a result keeps: `names`, `dim` and
# `dimnames`. Every other attribute, a class among them, is dropped.
entry_shape <- function(x) {
  kept <- attributes(x)
  kept[intersect(c("dim", "dimnames", "names"), names(kept))]
}

# Gives `result`, a vector parallel to the input, the shape of the input.
exit_step <- function(result, shape) {
  attributes(result) <- shape
  result
}

# Unmarked non-ASCII strings as text, read in the session's native
# encoding. Where that is UTF-8 the bytes already are the text and only
# the mark is set, so that invalid bytes reach the check in `entry_step()`
# on every R. `enc2utf8()` was measured to do the same on R 4.5.3, 4.6.2
# and devel, but on R 4.2.3 it replaces an invalid byte by text such as
# `<e9>`, and no error was raised (issue #43).
read_native <- function(x) {
  if (isTRUE(l10n_info()[["UTF-8"]])) {
    Encoding(x) <- "UTF-8"
    return(x)
  }
  enc2utf8(x)
}

# `latin1`-marked strings as text, read as true ISO 8859-1 through the
# package's own `latin-1` codec table (ADR 0006), so that bytes 80 to 9F
# become U+0080 to U+009F. `enc2utf8()` is never called on these strings:
# it reads the mark as Windows-1252.
#
# The first line only turns the bytes into bytes held as text (byte b as
# the character U+00b, see R/codecs.R); the table then decodes them.
read_latin1_mark <- function(x) {
  bytes <- iconv(x, from = "ISO-8859-1", to = "UTF-8")
  code_points <- codec_tables[["latin-1"]][-1L]
  if (anyNA(code_points) || anyNA(bytes)) {
    stop("internal error: a `latin1` mark could not be read", call. = FALSE)
  }
  moved <- code_points != 1:255
  if (!any(moved)) {
    return(bytes)
  }
  chartr(intToUtf8((1:255)[moved]), intToUtf8(code_points[moved]), bytes)
}

# Stops with "`x` holds <what> in n of m elements (first at: ...). <advice>"
# when `at`, the positions of the offending elements, is not empty.
entry_stop_at <- function(at, n, what, ...) {
  if (length(at) == 0L) {
    return(invisible(NULL))
  }
  stop(
    "`x` holds ", what, " in ", length(at), " of ", n, " elements ",
    "(first at: ", paste(utils::head(at, 5L), collapse = ", "), "). ",
    ...,
    call. = FALSE
  )
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
