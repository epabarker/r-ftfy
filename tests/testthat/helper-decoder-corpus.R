# Helpers for tests at the decoder level: byte strings, and the decoder
# corpus tests/testthat/reference/decoder_corpus.tsv, written by
# data-raw/generators/snapshot_decoder_corpus.py.

# The name under which a difference found by decoding bytes directly, not
# through an exported function, is given to the departure matchers.
decoder_fun <- "decode utf-8-variants"

# Byte strings as the package holds them, from hexadecimal: "C3A9" is the
# two characters U+00C3 U+00A9.
bytes_from_hex <- function(hex) {
  vapply(hex, function(one) {
    pairs <- substring(one, seq(1L, nchar(one), by = 2L), seq(2L, nchar(one), by = 2L))
    intToUtf8(strtoi(pairs, base = 16L))
  }, character(1), USE.NAMES = FALSE)
}

# Unescape reference texts. A text of the reference version that holds
# U+0000 cannot be an R string: it stays escaped, as the file has it, and
# is recognised by the six characters \u0000. (The generators escape a
# backslash, so an escaped text holds them for no other reason.) The
# matcher of the departure `decoded-nul-dropped` reads this form.
unescape_reference <- function(x) {
  holds_nul <- grepl("\\u0000", x, fixed = TRUE)
  x[!holds_nul] <- stringi::stri_unescape_unicode(x[!holds_nul])
  x
}

# The decoder corpus. `bytes` is the byte string; `utf8` and `variants`
# are what the package must give for the two codecs, with `NA` for
# "fails"; `python_variants` is what the reference version gives for
# `utf-8-variants` (see `unescape_reference()`); `departure` is "" or the
# id of the registry entry by which the last two differ.
read_decoder_corpus <- function() {
  raw <- read_reference_table("decoder_corpus.tsv", text = character())
  text_or_na <- function(status, text, unescape) {
    stopifnot(all(status %in% c("text", "fails")), all(text[status == "fails"] == ""))
    out <- unescape(text)
    out[status == "fails"] <- NA_character_
    out
  }
  data.frame(
    hex = raw$bytes,
    bytes = bytes_from_hex(raw$bytes),
    utf8 = text_or_na(raw$utf8, raw$utf8_text, stringi::stri_unescape_unicode),
    variants = text_or_na(raw$variants, raw$variants_text, stringi::stri_unescape_unicode),
    python_variants = text_or_na(raw$python_variants, raw$python_variants_text, unescape_reference),
    departure = raw$departure,
    stringsAsFactors = FALSE
  )
}
