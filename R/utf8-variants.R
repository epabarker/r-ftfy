# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/utf8_variants.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The codec `utf-8-variants`: UTF-8, and also CESU-8, where a character
# outside the Basic Multilingual Plane is written as two surrogates of
# three bytes each, and Java's two-byte form of U+0000, C0 80.
#
# Encoding gives plain UTF-8 (ftfy/bad_codecs/utf8_variants.py:233); see
# `codec_encode()`. Decoding is a rewrite of the bytes in front of the
# strict `utf-8` validity check (ADR 0003):
#
# - a six-byte surrogate pair becomes the four-byte form of its character;
# - C0 80 gives nothing, because an R string cannot hold U+0000 (ADR 0007).
#
# Everything else is left to the strict check, so a lone surrogate, a pair
# cut short and a C0 followed by anything but 80 are undecodable.
#
# The two patterns below are the only hand-written patterns in the package
# (ADR 0005). Upstream's (utf8_variants.py:58 and :81) also match a
# sequence cut short by the end of the input, written with `$`, which in
# Python matches before a final newline as well. That is what makes
# upstream read C0 0A and ED A0 BD ED B8 0A at the end of the input as
# complete sequences. Here a sequence must be complete to match, so
# nothing depends on where the input ends and a sequence cut short falls
# to the strict check, for which the end is the true end (ADR 0004). Do
# not add `$` to either pattern: in ICU, too, it matches before a final
# newline.
#
# Both match bytes held as text (see R/codecs.R).

# A six-byte CESU-8 surrogate pair: upstream's `CESU8_RE` without its
# cut-short forms.
CESU8_RE <- "\\x{ED}[\\x{A0}-\\x{AF}][\\x{80}-\\x{BF}]\\x{ED}[\\x{B0}-\\x{BF}][\\x{80}-\\x{BF}]"

# What must be decoded differently from standard UTF-8: upstream's
# `SPECIAL_BYTES_RE` without its cut-short forms and without the lone
# surrogate, which the strict check refuses by itself.
SPECIAL_BYTES_RE <- paste0("\\x{C0}\\x{80}|", CESU8_RE)

# Java's U+0000, as bytes held as text.
java_null <- "\u00c0\u0080"

# Decode bytes held as text with `utf-8-variants`. `NA` where the bytes
# cannot be decoded.
decode_utf8_variants <- function(bytes) {
  out <- decode_utf8(bytes)
  special <- which(regex_detect(bytes, SPECIAL_BYTES_RE))
  if (length(special) == 0L) {
    return(out)
  }
  rewritten <- bytes[special]
  paired <- regex_detect(rewritten, CESU8_RE)
  rewritten[paired] <- rewrite_surrogate_pairs(rewritten[paired])

  # Upstream decodes what stands before a C0 80 as complete UTF-8, so the
  # bytes on its two sides must each be valid: E2 C0 80 82 AC is not the
  # euro sign. Validity is therefore checked with one byte standing in
  # for each C0 80, and the text is made with nothing in its place.
  valid <- !is.na(decode_utf8(gsub(java_null, "\u0001", rewritten, fixed = TRUE)))
  decoded <- decode_utf8(gsub(java_null, "", rewritten, fixed = TRUE))
  decoded[!valid] <- NA_character_

  out[special] <- decoded
  out
}

# Rewrite every six-byte surrogate pair as the four bytes of the character
# it stands for (utf8_variants.py:217). `bytes` holds byte strings that
# each hold a pair, and no `NA`.
#
# The strings are joined into one, with a character that is not a byte
# between them, so that every pair in the vector is rewritten by one pass
# of arithmetic over the code points. Two pairs cannot overlap.
rewrite_surrogate_pairs <- function(bytes) {
  if (length(bytes) == 0L) {
    return(bytes)
  }
  separator <- "\u0100"
  joined <- paste(bytes, collapse = separator)
  at <- regex_locate_all(joined, CESU8_RE)[[1L]][, 1L]
  b <- utf8ToInt(joined)

  code_point <- bitwAnd(b[at + 1L], 0x0FL) * 65536L +
    bitwAnd(b[at + 2L], 0x3FL) * 1024L +
    bitwAnd(b[at + 4L], 0x0FL) * 64L +
    bitwAnd(b[at + 5L], 0x3FL) +
    0x10000L
  b[at] <- 0xF0L + code_point %/% 262144L
  b[at + 1L] <- 0x80L + (code_point %/% 4096L) %% 64L
  b[at + 2L] <- 0x80L + (code_point %/% 64L) %% 64L
  b[at + 3L] <- 0x80L + code_point %% 64L
  b <- b[-c(at + 4L, at + 5L)]

  # No piece is empty: each holds at least the four bytes of a character.
  strsplit(intToUtf8(b), separator, fixed = TRUE)[[1L]]
}
