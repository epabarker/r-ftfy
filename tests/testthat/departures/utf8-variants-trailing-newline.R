# Matcher for the departure `utf8-variants-trailing-newline`: the reference
# version read a final newline as the last byte of a sequence cut short,
# C0 or the first five bytes of a six-byte surrogate pair, and R did not.
#
# It matches at the decoder level only: `fun` is "decode utf-8-variants",
# `input` is a byte string that ends in such a sequence and a newline, the
# reference version decoded it and R failed. No exported function reaches
# these bytes yet, so no difference in an exported function is this
# departure. Ticket #36 widens the matcher to fix_encoding(), against the
# snapshot rows that show it, and ticket #41 to fix_text().
function(difference) {
  if (!identical(difference$fun, "decode utf-8-variants") ||
      !is.character(difference$input) || is.na(difference$input) ||
      !is.character(difference$actual) || !is.na(difference$actual) ||
      !is.character(difference$reference) || is.na(difference$reference) ||
      !endsWith(difference$input, "\n")) {
    return(FALSE)
  }
  b <- utf8ToInt(difference$input)
  n <- length(b)
  within <- function(byte, low, high) byte >= low && byte <= high
  (n >= 2L && b[[n - 1L]] == 0xC0) ||
    (n >= 6L &&
      b[[n - 5L]] == 0xED && within(b[[n - 4L]], 0xA0, 0xAF) &&
      within(b[[n - 3L]], 0x80, 0xBF) &&
      b[[n - 2L]] == 0xED && within(b[[n - 1L]], 0xB0, 0xBF))
}
