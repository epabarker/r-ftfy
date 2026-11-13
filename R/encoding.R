# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Repair encoding mix-ups
#'
#' `fix_encoding()` repairs mojibake: text that was decoded with the wrong
#' codec, such as `"caf\u00c3\u00a9"` for `"caf\u00e9"`. It changes nothing
#' else, so quotes, ligatures and line breaks are left alone, and text that
#' does not look like mojibake comes back unchanged.
#'
#' This version repairs a mix-up of one layer between UTF-8 and Latin-1 or
#' Windows-1252. Any other value comes back unchanged.
#'
#' Call it on a whole vector, not once per string: each call has a fixed
#' cost of about half a millisecond.
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8.
#'
#' @return A character vector as long as `x`, marked as UTF-8. A missing
#'   string gives `NA`.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "it\u00e2\u20ac\u2122s", "caf\u00e9", NA)
#' fix_encoding(x)
#' @export
fix_encoding <- function(x) {
  x <- entry_step(x)
  repair_encoding(x)$text
}

# The codecs a mix-up is looked for in, in the order upstream tries them
# (`chardata.CHARMAP_ENCODINGS`): the first ten of `plan_codecs`, which is
# the only copy of the codec names. The order decides which repair is found
# first, so it is never taken from the shipped tables.
charmap_codecs <- function() {
  plan_codecs[1:10]
}

# The encoding repair of a whole vector of valid UTF-8 strings and `NA`s:
# upstream's `fix_encoding_and_explain()`. Returns a list, of which `text`
# is the repaired vector; the plans join it there.
#
# One pass of `repair_encoding_step()` runs over every element still
# changing, and only the elements it changed go round again.
#
# Parts of the heuristic are not built yet. A pass reports an element it
# cannot answer for as "unsure", and such an element comes back as it was
# given, with nothing done to it, because a repair that stops part of the
# way is a wrong text. When no part is absent nothing is ever unsure.
repair_encoding <- function(x) {
  text <- x
  unsure <- logical(length(x))
  live <- which(!is.na(x))
  while (length(live) > 0L) {
    pass <- repair_encoding_step(text[live])
    text[live] <- pass$text
    unsure[live[pass$status == "unsure"]] <- TRUE
    live <- live[pass$status == "changed"]
  }
  text[unsure] <- x[unsure]
  list(text = text)
}

# One step of the repair, over strings with no `NA`: upstream's
# `_fix_encoding_one_step_and_explain()`. Returns the texts and, for each,
# a status: "same" (upstream changes nothing either), "changed", or
# "unsure" (an absent part of the heuristic might have acted).
repair_encoding_step <- function(x) {
  out <- x
  status <- rep("same", length(x))

  # Empty, ASCII and not-bad text is returned unchanged.
  todo <- which(nzchar(x) & !stringi::stri_enc_isascii(x))
  todo <- todo[regex_detect(x[todo], patterns[["BADNESS_RE"]])]

  # Was the text meant to be UTF-8, but decoded with a single-byte codec?
  for (codec in charmap_codecs()) {
    if (length(todo) == 0L) {
      break
    }
    if (!codec_is_known(codec)) {
      # ABSENT (#33): this codec's table.
      status[todo] <- "unsure"
      todo <- integer()
      break
    }
    tried <- todo[codec_can_encode(x[todo], codec)]
    if (length(tried) == 0L) {
      next
    }
    bytes <- codec_encode(x[tried], codec)
    decoded <- decode_utf8(bytes)
    answered <- !absent_byte_steps_could_act(bytes, codec, failed = is.na(decoded))

    fixed <- answered & !is.na(decoded)
    out[tried[fixed]] <- decoded[fixed]
    status[tried[fixed]] <- "changed"
    status[tried[!answered]] <- "unsure"
    # What is left failed to decode, as it does upstream: try the next codec.
    todo <- setdiff(todo, tried[fixed | !answered])
  }

  # ABSENT (#36): `decode_inconsistent_utf8`, Latin-1 read as Windows-1252,
  # and `fix_c1_controls`, which upstream tries next on text no codec
  # repaired.
  status[todo] <- "unsure"

  list(text = out, status = status)
}

# ABSENT (#34, #36): between encoding and decoding, upstream may rewrite
# the bytes with `restore_byte_a0` and `replace_lossy_sequences`, and it
# decodes with `utf-8-variants` when the bytes hold ED or C0. Until those
# exist, this says for which byte strings one of them could have changed
# the outcome of a plain strict decode. It is deliberately wider than what
# they match, and is deleted when they are in place.
#
# - Bytes that are valid UTF-8 match neither `ALTERED_UTF8_RE` nor any
#   branch of `LOSSY_UTF8_RE` but its last, the lone byte 1A, and
#   `utf-8-variants` decodes them as `utf-8` does. So a decode that
#   succeeded stands unless a sloppy codec gave byte 1A.
# - A decode that failed might have succeeded after `restore_byte_a0`
#   (needs a space, and is not used with `macroman`), after
#   `replace_lossy_sequences` (a sloppy codec, and byte 1A or "?"), or with
#   `utf-8-variants` (byte ED or C0).
absent_byte_steps_could_act <- function(bytes, codec, failed) {
  has <- function(byte) grepl(byte, bytes, fixed = TRUE)
  sloppy <- startsWith(codec, "sloppy-")
  lossy_mark <- sloppy & has("\u001a")
  lossy_mark | (failed & (
    (codec != "macroman" & has(" ")) |
      (sloppy & has("?")) |
      has("\u00ed") | has("\u00c0")
  ))
}
