# Every regex call the package makes goes through this file, so that each
# one carries the options ADR 0005 requires: `unix_lines = TRUE` and
# `stack_limit = 1e9`, and never `comments = TRUE`. Only the stringi
# functions that ADR 0008 lists as keeping a leading U+FEFF are used.

regex_opts <- function() {
  stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9)
}

# Does each string hold a match? `NA` for a missing string.
regex_detect <- function(x, pattern) {
  stringi::stri_detect_regex(x, pattern, opts_regex = regex_opts())
}

# The number of non-overlapping matches in each string, as Python's
# `len(re.findall())` counts them. `NA` for a missing string.
regex_count <- function(x, pattern) {
  found <- stringi::stri_locate_all_regex(
    x, pattern,
    omit_no_match = TRUE, opts_regex = regex_opts()
  )
  # Each element is a matrix of starts and ends, with one row per match.
  count <- lengths(found, use.names = FALSE) %/% 2L
  count[is.na(x)] <- NA_integer_
  count
}
