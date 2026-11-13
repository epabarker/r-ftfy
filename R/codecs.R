# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Codecs (ADR 0003). The decode table of every single-byte codec is shipped
# in the internal list `codec_tables`, built by data-raw/sysdata/codecs.R:
# 256 code points for each codec, with `NA` for a hole. Everything else
# about a codec is made from its table when the package is loaded and is
# never stored: the pair of strings that encodes with `chartr()`, and the
# pattern that finds a character the codec cannot encode. One source is
# what guarantees that encoding cannot fail once the check has passed.
#
# Bytes are held as text: byte b is the character U+00b, so a byte string
# is a string of the characters U+0001 to U+00FF. Byte 00 never occurs,
# because an R string cannot hold U+0000. This is the form the generated
# byte patterns match against (ADR 0005).

codecs <- new.env(parent = emptyenv())

# Called from `.onLoad()`. Builds the encode side of every shipped table.
build_codecs <- function() {
  for (codec in names(codec_tables)) {
    assign(codec, build_codec(codec_tables[[codec]]), envir = codecs)
  }
  invisible(NULL)
}

build_codec <- function(table) {
  bytes <- 1:255
  code_points <- table[bytes + 1L]
  assigned <- !is.na(code_points)
  moved <- assigned & code_points != bytes
  list(
    # `chartr(old, new, x)` turns each character into its byte.
    old = intToUtf8(code_points[moved]),
    new = intToUtf8(bytes[moved]),
    # Matches any character that no byte of the codec decodes to. Upstream
    # builds the same set in `chardata._build_regexes()`.
    cannot_encode = paste0(
      "[^",
      paste(sprintf("\\x{%X}", sort(code_points[assigned])), collapse = ""),
      "]"
    )
  )
}

codec <- function(name) {
  found <- codecs[[name]]
  if (is.null(found)) {
    stop("internal error: no table for the codec `", name, "`", call. = FALSE)
  }
  found
}

# Whether a table for this codec is shipped.
codec_is_known <- function(name) {
  !is.null(codecs[[name]])
}

# Upstream's `possible_encoding()`: could each string have been decoded
# from this codec, that is, can it be encoded with it? `NA` for `NA`.
codec_can_encode <- function(x, name) {
  !regex_detect(x, codec(name)$cannot_encode)
}

# Encode each string, giving bytes held as text. Every string must pass
# `codec_can_encode()` first; a character outside the codec is left as it
# is, which no caller may rely on.
codec_encode <- function(x, name) {
  pair <- codec(name)
  if (!nzchar(pair$old)) {
    return(x)
  }
  chartr(pair$old, pair$new, x)
}

# Strict `utf-8` decoding of bytes held as text: a validity check followed
# by marking the bytes as UTF-8. `NA` where the bytes are not valid UTF-8.
decode_utf8 <- function(bytes) {
  out <- iconv(bytes, from = "UTF-8", to = "latin1")
  Encoding(out) <- "UTF-8"
  out[!stringi::stri_enc_isutf8(out)] <- NA_character_
  out
}
