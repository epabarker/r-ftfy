# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Codecs (ADR 0003). The closed set is `plan_codecs`: eleven single-byte
# codecs, `utf-8` and `utf-8-variants`, each under its one name.
#
# The decode table of every single-byte codec is shipped in the internal
# list `codec_tables`, built by data-raw/sysdata/codecs.R: 256 code points
# for each codec, with `NA` for a hole. Everything else about a codec is
# made from its table when the package is loaded and is never stored: the
# pair of strings that encodes and decodes with `chartr()`, the pattern
# that finds a character the codec cannot encode, and the pattern that
# finds a byte it cannot decode. One source is what guarantees that
# encoding cannot fail once the check has passed.
#
# Bytes are held as text: byte b is the character U+00b, so a byte string
# is a string of the characters U+0001 to U+00FF. Byte 00 never occurs,
# because an R string cannot hold U+0000. This is the form the generated
# byte patterns match against (ADR 0005).
#
# Every function here works over a whole vector with one codec, keeps `NA`
# as `NA`, and reports a failure as `NA` where the input was not `NA`. No
# ICU converter is called.

codecs <- new.env(parent = emptyenv())

# Called from `.onLoad()`. Builds both sides of every shipped table.
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
  class_of <- function(numbers) {
    paste(sprintf("\\x{%X}", sort(numbers)), collapse = "")
  }
  list(
    # `chartr(characters, bytes, x)` turns each character into its byte,
    # and `chartr(bytes, characters, x)` turns each byte into its character.
    characters = intToUtf8(code_points[moved]),
    bytes = intToUtf8(bytes[moved]),
    # Matches any character that no byte of the codec decodes to. Upstream
    # builds the same set in `chardata._build_regexes()`.
    cannot_encode = paste0("[^", class_of(code_points[assigned]), "]"),
    # Matches a hole: a byte the codec assigns no character to. `NULL` for
    # a codec without holes, whose decoding cannot fail.
    cannot_decode = if (all(assigned)) {
      NULL
    } else {
      paste0("[", class_of(bytes[!assigned]), "]")
    }
  )
}

# The names of the codecs that are UTF-8 and have no table.
utf8_codecs <- c("utf-8", "utf-8-variants")

# Stop unless `name` is one of the 13 codecs, in its canonical spelling.
# Names are case-sensitive and have no aliases (ADR 0003).
check_codec <- function(name) {
  if (!is.character(name) || length(name) != 1L || !name %in% plan_codecs) {
    shown <- if (is.character(name)) {
      paste(encodeString(name, quote = "\""), collapse = ", ")
    } else {
      paste0("<", class(name)[[1L]], ">")
    }
    stop(
      "Unknown codec: ", shown, ". ",
      "Accepted codecs: ", paste(plan_codecs, collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(name)
}

# The built form of a single-byte codec.
codec <- function(name) {
  check_codec(name)
  found <- codecs[[name]]
  if (is.null(found)) {
    stop("internal error: no table for the codec `", name, "`", call. = FALSE)
  }
  found
}

# Whether `name` is one of the 13 codecs.
codec_is_known <- function(name) {
  is.character(name) && length(name) == 1L && name %in% plan_codecs
}

# Upstream's `possible_encoding()`: could each string have been decoded
# from this codec, that is, can it be encoded with it? `NA` for `NA`.
# Every string can be encoded as UTF-8.
codec_can_encode <- function(x, name) {
  check_codec(name)
  if (name %in% utf8_codecs) {
    return(!is.na(x))
  }
  !regex_detect(x, codec(name)$cannot_encode)
}

# Encode each string, giving bytes held as text. Every string must pass
# `codec_can_encode()` first; a character outside the codec is left as it
# is, which no caller may rely on. Use `codec_try_encode()` for text that
# has not been checked.
codec_encode <- function(x, name) {
  check_codec(name)
  if (name %in% utf8_codecs) {
    return(encode_utf8(x))
  }
  pair <- codec(name)
  if (!nzchar(pair$characters)) {
    return(x)
  }
  translate(pair$characters, pair$bytes, x)
}

# Encode each string, giving bytes held as text, or `NA` for a string that
# holds a character the codec cannot encode.
codec_try_encode <- function(x, name) {
  out <- rep(NA_character_, length(x))
  possible <- which(codec_can_encode(x, name))
  out[possible] <- codec_encode(x[possible], name)
  out
}

# Decode bytes held as text, giving text marked as UTF-8, or `NA` where
# the bytes cannot be decoded: a hole of a single-byte codec, or bytes
# that are not valid UTF-8. `x` must hold byte strings and `NA`s only.
codec_decode <- function(x, name) {
  check_codec(name)
  if (name == "utf-8") {
    return(decode_utf8(x))
  }
  if (name == "utf-8-variants") {
    return(decode_utf8_variants(x))
  }
  pair <- codec(name)
  out <- if (nzchar(pair$bytes)) translate(pair$bytes, pair$characters, x) else x
  if (!is.null(pair$cannot_decode)) {
    out[regex_detect(x, pair$cannot_decode)] <- NA_character_
  }
  enc2utf8(out)
}

# `chartr()` in UTF-8 whatever the session's encoding. `chartr()` works in
# UTF-8 on an element marked as UTF-8 and in the native encoding on an
# ASCII element, where, outside a UTF-8 session, it loses a character the
# session cannot hold: the U+FFFD that byte 1A of a sloppy codec decodes
# to. So an ASCII element is translated with one marked character after
# it, which is then taken off. That is needed only when `old` holds an
# ASCII character; otherwise an ASCII element has nothing to translate.
translate <- function(old, new, x) {
  ascii <- stringi::stri_enc_isascii(x)
  marked <- which(!ascii)
  x[marked] <- chartr(old, new, x[marked])
  if (any(utf8ToInt(old) < 0x80L)) {
    plain <- which(ascii)
    padded <- chartr(old, new, paste0(x[plain], utf8_marked))
    x[plain] <- substring(padded, 1L, nchar(padded) - 1L)
  }
  x
}
utf8_marked <- intToUtf8(0x100L)

# `utf-8` encoding: the bytes of each string, held as text. The strings
# are valid UTF-8 already, so their bytes are read as ISO 8859-1, which
# gives the character U+00b for byte b. The codec is named in full because
# R reads the name "latin1" as Windows-1252 on some platforms.
encode_utf8 <- function(x) {
  iconv(x, from = "ISO-8859-1", to = "UTF-8")
}

# Strict `utf-8` decoding of bytes held as text: a validity check followed
# by marking the bytes as UTF-8. `NA` where the bytes are not valid UTF-8.
decode_utf8 <- function(bytes) {
  out <- iconv(bytes, from = "UTF-8", to = "ISO-8859-1")
  Encoding(out) <- "UTF-8"
  out[!stringi::stri_enc_isutf8(out)] <- NA_character_
  out
}
