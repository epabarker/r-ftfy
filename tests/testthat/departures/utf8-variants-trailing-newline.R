# Matcher for the departure `utf8-variants-trailing-newline`: the reference
# version read a final newline as the last byte of a sequence cut short,
# C0 or the first five bytes of a six-byte surrogate pair, and R did not.
#
# It matches at two levels.
#
# - The decoder: `fun` is "decode utf-8-variants", `input` is a byte string
#   that ends in such a sequence and a newline, the reference version
#   decoded it and R failed.
# - fix_encoding(): `input` is a text that ends in a newline and that one
#   of the codecs the repair tries encodes to such a byte string; the
#   reference version's text has lost the newline and R's has kept it.
#   These are the snapshot rows of reference/fix_encoding.tsv that show
#   the departure. A text that reaches these bytes only after a first
#   repair is not matched: no snapshot row needs it.
#
# Ticket #41 widens it to fix_text().
function(difference) {
  ends_cut_short <- function(bytes) {
    b <- utf8ToInt(bytes)
    n <- length(b)
    within <- function(byte, low, high) byte >= low && byte <= high
    (n >= 2L && b[[n - 1L]] == 0xC0) ||
      (n >= 6L &&
        b[[n - 5L]] == 0xED && within(b[[n - 4L]], 0xA0, 0xAF) &&
        within(b[[n - 3L]], 0x80, 0xBF) &&
        b[[n - 2L]] == 0xED && within(b[[n - 1L]], 0xB0, 0xBF))
  }
  input <- difference$input
  reference <- difference$reference
  actual <- difference$actual
  if (!is.character(input) || is.na(input) || !endsWith(input, "\n") ||
      !is.character(reference) || is.na(reference) ||
      !is.character(actual)) {
    return(FALSE)
  }
  if (identical(difference$fun, "decode utf-8-variants")) {
    return(is.na(actual) && ends_cut_short(input))
  }
  if (!identical(difference$fun, "fix_encoding")) {
    return(FALSE)
  }
  # A reference text that holds U+0000 is still escaped, newline and all.
  newline_lost <- !endsWith(reference, "\n") && !endsWith(reference, "\\u000A")
  if (is.na(actual) || !endsWith(actual, "\n") || !newline_lost) {
    return(FALSE)
  }
  for (codec in ftfy:::charmap_codecs()) {
    bytes <- ftfy:::codec_try_encode(input, codec)
    if (!is.na(bytes)) {
      # Only the first codec that can encode the text is looked at. The
      # reference version goes on to later codecs when decoding fails, so
      # this is narrower than the departure, on purpose: every snapshot
      # row that shows it is of this kind.
      return(ends_cut_short(bytes))
    }
  }
  FALSE
}
