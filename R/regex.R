# Every regex call the package makes passes `opts_regex = regex_opts()`, so
# that each one carries the options ADR 0005 requires: `unix_lines = TRUE`
# and `stack_limit = 1e9`, and never `comments = TRUE`. Each call is also
# wrapped in `regex_guard()`, which turns the regex engine's stack overflow
# into the package's own error. tests/testthat/test-regex-lint.R fails on a
# call that does either differently. Only the stringi functions that
# ADR 0008 lists as keeping a leading U+FEFF are used.

regex_opts <- function() {
  stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9)
}

# Does each string hold a match? `NA` for a missing string.
regex_detect <- function(x, pattern) {
  regex_guard(
    stringi::stri_detect_regex(x, pattern, opts_regex = regex_opts()),
    x
  )
}

# The number of non-overlapping matches in each string, as Python's
# `len(re.findall())` counts them. `NA` for a missing string.
regex_count <- function(x, pattern) {
  found <- regex_locate_all(x, pattern)
  # Each element is a matrix of starts and ends, with one row per match.
  count <- lengths(found, use.names = FALSE) %/% 2L
  count[is.na(x)] <- NA_integer_
  count
}

# Where each match is: a list with one integer matrix per string, a row per
# non-overlapping match in order, with the columns `start` and `end` counted
# in code points from 1, both included. A string without a match gives a
# matrix with no rows; a missing string gives one row of `NA`.
regex_locate_all <- function(x, pattern) {
  regex_guard(
    stringi::stri_locate_all_regex(
      x, pattern,
      omit_no_match = TRUE, opts_regex = regex_opts()
    ),
    x
  )
}

# Evaluate one regex call, `expr`, made on the text `x`. Python's `re` has
# no backtracking limit; ICU's is the 1e9 bytes of `regex_opts()`, and a
# regex that needs more stops with ICU's U_REGEX_STACK_OVERFLOW. That
# becomes an error of class `ftfy_regex_overflow` naming the exported
# function the user called and the length of the input (the departure
# `regex-overflow`, ADR 0005). `x` is the text this call was matching,
# which inside a fixer may be part of the user's input or a form of it. Any other error passes through unchanged.
regex_guard <- function(expr, x) {
  tryCatch(
    expr,
    error = function(e) {
      if (!grepl("U_REGEX_STACK_OVERFLOW", conditionMessage(e), fixed = TRUE)) {
        stop(e)
      }
      regex_overflow(x)
    }
  )
}

regex_overflow <- function(x) {
  caller <- exported_caller()
  longest <- max(0L, nchar(x, type = "chars", allowNA = TRUE), na.rm = TRUE)
  where <- if (is.null(caller)) "" else paste0(caller$name, "(): ")
  message <- paste0(
    where, "the regular expression engine ran out of stack while matching ",
    length(x), " ", if (length(x) == 1L) "string" else "strings",
    ", the longest of ", format(longest, big.mark = ",", scientific = FALSE),
    " characters. Its limit is 1e9 bytes, and Python ftfy has none. ",
    "Split the text into shorter strings."
  )
  stop(structure(
    class = c("ftfy_regex_overflow", "error", "condition"),
    list(message = message, call = caller$call)
  ))
}

# The outermost call on the stack to an exported function of this package:
# its name and the call, or NULL when there is none.
exported_caller <- function() {
  namespace <- topenv(environment())
  exports <- getNamespaceExports(namespace)
  exported <- mget(exports, envir = namespace, mode = "function", ifnotfound = list(NULL))
  for (frame in seq_len(sys.nframe())) {
    fun <- sys.function(frame)
    for (name in names(exported)) {
      if (identical(fun, exported[[name]])) {
        return(list(name = name, call = sys.call(frame)))
      }
    }
  }
  NULL
}
