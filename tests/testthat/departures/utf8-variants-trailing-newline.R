# Matcher for the departure `utf8-variants-trailing-newline`: the reference
# version read a final newline as the last byte of a sequence cut short,
# C0 or the first five bytes of a six-byte surrogate pair, and R did not.
#
# At the decoder level (`fun` is "decode utf-8-variants" and `input` is a
# byte string) it matches when the bytes end in such a sequence and a
# newline, the reference version decoded them and R failed.
#
# For an exported function it matches when a line of the input, read as
# bytes of one of the ten codecs a mix-up is looked for in, ends in such a
# sequence and its newline, and R returned a text. Ticket #36 may narrow
# this once fix_encoding() reaches these inputs.
function(difference) {
  # Do these bytes end in a sequence cut short and the newline after it?
  cut_short <- function(bytes) {
    if (is.na(bytes) || !endsWith(bytes, "\n")) {
      return(FALSE)
    }
    b <- utf8ToInt(bytes)
    n <- length(b)
    within <- function(byte, low, high) byte >= low && byte <= high
    (n >= 2L && b[[n - 1L]] == 0xC0) ||
      (n >= 6L &&
        b[[n - 5L]] == 0xED && within(b[[n - 4L]], 0xA0, 0xAF) &&
        within(b[[n - 3L]], 0x80, 0xBF) &&
        b[[n - 2L]] == 0xED && within(b[[n - 1L]], 0xB0, 0xBF))
  }

  if (!is.character(difference$input) || is.na(difference$input) ||
      !is.character(difference$actual)) {
    return(FALSE)
  }
  if (identical(difference$fun, "decode utf-8-variants")) {
    return(is.na(difference$actual) && !is.na(difference$reference) &&
             cut_short(difference$input))
  }
  if (is.na(difference$actual)) {
    return(FALSE)
  }

  # The ends of the lines that have a newline: at most the five characters
  # before it, since each byte of the sequence is one character.
  lines <- strsplit(difference$input, "\n", fixed = TRUE)[[1L]]
  if (!endsWith(difference$input, "\n")) {
    lines <- lines[-length(lines)]
  }
  for (line in lines) {
    size <- nchar(line)
    for (width in c(1L, 5L)) {
      if (size < width) {
        next
      }
      end <- paste0(substring(line, size - width + 1L, size), "\n")
      for (codec in ftfy:::charmap_codecs()) {
        if (cut_short(ftfy:::codec_try_encode(end, codec))) {
          return(TRUE)
        }
      }
    }
  }
  FALSE
}
