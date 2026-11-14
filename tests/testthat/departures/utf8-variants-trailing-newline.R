# Matcher for the departure `utf8-variants-trailing-newline`: the reference
# version read a final newline as the last byte of a sequence cut short,
# C0 or the first five bytes of a six-byte surrogate pair, and R did not.
#
# It matches at four levels.
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
# - apply_plan(): `input` is such a text, the reference version's text has
#   lost the newline, and the replay of the reference version's plan failed
#   in R, so that `actual` is `NA` (what the unexported replay gives).
#
# - fix_text(): there the departure is met line by line, because each line
#   is repaired with its newline. `input` holds one or more lines that end
#   in a newline and that the first codec able to encode them encodes to
#   such a byte string, and the reference version's text has that many
#   newlines fewer than R's: it lost the newline of each such line and R
#   kept it. Nothing else of the two texts is compared, since what R gives
#   in place of the reference version's repair depends on the options.
#   These are the rows of reference/fix_text.tsv that show the departure;
#   a line cut by a small `max_decode_length` is not looked at, and no row
#   needs it.
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
  # The first codec that can encode the text gives bytes that end so. The
  # reference version goes on to later codecs when decoding fails, so this
  # is narrower than the departure, on purpose: every snapshot row that
  # shows it is of this kind.
  reaches_cut_short <- function(text) {
    for (codec in ftfy:::charmap_codecs()) {
      bytes <- ftfy:::codec_try_encode(text, codec)
      if (!is.na(bytes)) {
        return(ends_cut_short(bytes))
      }
    }
    FALSE
  }
  count <- function(text, what) {
    lengths(regmatches(text, gregexpr(what, text, fixed = TRUE)))
  }
  input <- difference$input
  reference <- difference$reference
  actual <- difference$actual
  if (!is.character(input) || is.na(input) ||
      !is.character(reference) || is.na(reference) ||
      !is.character(actual)) {
    return(FALSE)
  }
  if (identical(difference$fun, "fix_text")) {
    if (is.na(actual)) {
      return(FALSE)
    }
    lines <- strsplit(input, "(?<=\n)", perl = TRUE)[[1L]]
    lines <- lines[endsWith(lines, "\n")]
    cut_short <- sum(vapply(lines, reaches_cut_short, logical(1L)))
    # A reference text that holds U+0000 is still escaped, newlines and all.
    escaped <- grepl("\\u0000", reference, fixed = TRUE)
    lost <- count(actual, "\n") - count(reference, if (escaped) "\\u000A" else "\n")
    return(cut_short > 0L && lost == cut_short)
  }
  if (!endsWith(input, "\n")) {
    return(FALSE)
  }
  if (identical(difference$fun, "decode utf-8-variants")) {
    return(is.na(actual) && ends_cut_short(input))
  }
  if (!difference$fun %in% c("fix_encoding", "apply_plan")) {
    return(FALSE)
  }
  # A reference text that holds U+0000 is still escaped, newline and all.
  newline_lost <- !endsWith(reference, "\n") && !endsWith(reference, "\\u000A")
  if (!newline_lost) {
    return(FALSE)
  }
  if (identical(difference$fun, "apply_plan")) {
    # The replay of the reference version's own plan failed: `actual` is
    # `NA`, as the unexported replay gives it. Which plan it was is not in
    # a difference, so the bytes are looked for as for fix_encoding().
    if (!is.na(actual)) {
      return(FALSE)
    }
  } else if (is.na(actual) || !endsWith(actual, "\n")) {
    return(FALSE)
  }
  reaches_cut_short(input)
}
