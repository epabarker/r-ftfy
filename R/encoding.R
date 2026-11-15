# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Repair encoding mix-ups
#'
#' `fix_encoding()` repairs mojibake: text that was decoded with the wrong
#' codec, such as `"caf\u00c3\u00a9"` for `"caf\u00e9"`. It changes nothing
#' else, so quotes, ligatures and line breaks are left alone, and text that
#' does not look like mojibake comes back unchanged.
#'
#' Each string is repaired by itself, as Python ftfy 6.3.1 repairs it:
#'
#' * Text that was UTF-8 and was read with a single-byte codec, such as
#'   Latin-1, Windows-1252 or another Windows code page, is encoded with
#'   that codec and decoded as UTF-8. A mix-up several layers deep is
#'   undone a layer at a time.
#' * A plain space is read as a no-break space, and a sequence in which a
#'   character was lost becomes U+FFFD, when that makes the rest of the
#'   string decodable (the options `restore_byte_a0` and
#'   `replace_lossy_sequences`).
#' * When the string as a whole cannot be decoded, the sequences in it that
#'   plainly are UTF-8 mojibake are repaired one by one (the option
#'   `decode_inconsistent_utf8`; see [decode_inconsistent_utf8()]).
#' * C1 control characters are read as the Windows-1252 characters at the
#'   same bytes (the option `fix_c1_controls`; see [fix_c1_controls()]).
#'
#' Call it on a whole vector, not once per string: each call on text that
#' is not plain ASCII has a fixed cost of up to 0.77 milliseconds,
#' however long the vector (see [ftfy][ftfy-package] for
#' the measurements).
#'
#' @section Differences from Python ftfy:
#' Where the repair decodes the two bytes C0 80, which stand for the
#' character U+0000, nothing is put in their place, because an R string
#' cannot hold U+0000. And a string that ends in a newline just after the
#' byte C0, or after the first five bytes of a six-byte surrogate pair, is
#' not repaired by reading the newline as the missing byte.
#'
#' Every departure from the reference version is listed, with examples,
#' on the page [ftfy-differences].
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8.
#' @param ... Options to change for this call, each given by its full
#'   name, such as `restore_byte_a0 = FALSE`. They override `config`. See
#'   [ftfy_config()] for the options.
#' @param config A set of options made by [ftfy_config()].
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "it\u00e2\u20ac\u2122s", "caf\u00e9", NA)
#' fix_encoding(x)
#'
#' # Mojibake beside text that was never mangled is repaired where it is
#' fix_encoding("\u2603 caf\u00c3\u00a9")
#' fix_encoding("\u2603 caf\u00c3\u00a9", decode_inconsistent_utf8 = FALSE)
#' @export
fix_encoding <- function(x, ..., config = ftfy_config()) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  config <- resolve_config(..., config = config)
  # Each distinct value is repaired once (ADR 0008).
  distinct <- unique(x)
  repaired <- repair_encoding(distinct, config)$text
  exit_step(repaired[match(x, distinct)], shape)
}

# The codecs a mix-up is looked for in, in the order upstream tries them
# (`chardata.CHARMAP_ENCODINGS`): the first ten of `plan_codecs`, which is
# the only copy of the codec names. The order decides which repair is found
# first, so it is never taken from the shipped tables.
charmap_codecs <- function() {
  plan_codecs[1:10]
}

# The encoding repair of a whole vector of valid UTF-8 strings and `NA`s:
# upstream's `fix_encoding_and_explain()` (ftfy/__init__.py:424).
#
# `config` is the resolved `ftfy_config` object (R/config.R), received
# whole. Returns a list of two:
#
#   text   the repaired texts, parallel to `x`; `NA` where `x` is.
#   steps  every step taken, as a data frame with the columns `element`
#          (a position in `x`), `action` and `parameter`. The steps of one
#          element are in the order they were taken; a step that left the
#          text as it was is recorded too, as upstream records it. This is
#          what `plan_text_from_steps()` takes; `encoding_plan_text()`
#          below makes the plans' text forms from it.
#
# One pass of `repair_encoding_step()` runs over every element still
# changing, and only the elements it changed go round again.
repair_encoding <- function(x, config) {
  steps <- new_steps()
  if (!config$fix_encoding) {
    # Upstream returns the text and an empty plan (ftfy/__init__.py:453).
    return(list(text = x, steps = bind_steps(steps)))
  }
  text <- x
  live <- which(!is.na(x))
  while (length(live) > 0L) {
    pass <- repair_encoding_step(text[live], config)
    steps <- add_step(
      steps, live[pass$steps$element], pass$steps$action, pass$steps$parameter
    )
    changed <- pass$text != text[live]
    text[live] <- pass$text
    live <- live[changed]
  }
  list(text = text, steps = bind_steps(steps))
}

# The text forms of the plans of `repair_encoding(x, config)`, parallel to
# `x`: "none" for a string no step was taken on, `NA` for a missing string.
encoding_plan_text <- function(repaired, x) {
  steps <- repaired$steps
  plan <- plan_text_from_steps(length(x), steps$element, steps$action, steps$parameter)
  plan[is.na(x)] <- NA_character_
  plan
}

# Steps are gathered as a list of chunks, each a list of `element`,
# `action` and `parameter`, and bound into one data frame at the end.
new_steps <- function() {
  list()
}

# Add a step for each of the elements `element`. `action` and `parameter`
# are single strings, the same step for all, or parallel to `element`, as
# when the steps of an inner call, renumbered, are added.
add_step <- function(steps, element, action, parameter) {
  if (length(element) == 0L) {
    return(steps)
  }
  steps[[length(steps) + 1L]] <- list(
    element = element,
    action = rep_len(action, length(element)),
    parameter = rep_len(parameter, length(element))
  )
  steps
}

bind_steps <- function(steps) {
  column <- function(name, empty) {
    if (length(steps) == 0L) empty else unlist(lapply(steps, `[[`, name), use.names = FALSE)
  }
  data.frame(
    element = column("element", integer()),
    action = column("action", character()),
    parameter = column("parameter", character()),
    stringsAsFactors = FALSE
  )
}

# One step of the repair, over strings with no `NA`: upstream's
# `_fix_encoding_one_step_and_explain()` (ftfy/__init__.py:468). Returns
# the texts and the steps taken, as `repair_encoding()` does. It loops over
# codecs, never over strings: `todo` holds the positions not yet answered.
repair_encoding_step <- function(x, config) {
  out <- x
  steps <- new_steps()

  # Empty, ASCII and not-bad text is returned unchanged.
  todo <- which(!stringi::stri_enc_isascii(x))
  todo <- todo[detect_bad(x[todo])]
  latin1 <- logical(length(x))

  # Was the text meant to be UTF-8, but decoded with a single-byte codec?
  for (codec in charmap_codecs()) {
    if (length(todo) == 0L) {
      break
    }
    tried <- todo[codec_can_encode(x[todo], codec)]
    if (length(tried) == 0L) {
      next
    }
    if (codec == "latin-1") {
      latin1[tried] <- TRUE
    }
    bytes <- codec_encode(x[tried], codec)

    # Sequences that would be UTF-8 if a space were byte A0. Not with
    # `macroman`, where the pattern would match an en dash and a space.
    restored <- logical(length(tried))
    if (config$restore_byte_a0 && codec != "macroman") {
      altered <- which(regex_detect(bytes, patterns[["ALTERED_UTF8_RE"]]))
      if (length(altered) > 0L) {
        replaced <- fixer_restore_byte_a0(bytes[altered])
        restored[altered] <- replaced != bytes[altered]
        bytes[altered] <- replaced
      }
    }

    # Sequences in which a character was lost.
    lossy <- logical(length(tried))
    if (config$replace_lossy_sequences && startsWith(codec, "sloppy")) {
      replaced <- fixer_replace_lossy_sequences(bytes)
      lossy <- replaced != bytes
      bytes <- replaced
    }

    variants <- grepl("\u00ed", bytes, fixed = TRUE) | grepl("\u00c0", bytes, fixed = TRUE)
    decoded <- rep(NA_character_, length(tried))
    decoded[!variants] <- decode_utf8(bytes[!variants])
    decoded[variants] <- decode_utf8_variants(bytes[variants])

    # What failed to decode goes on to the next codec, as it does upstream.
    fixed <- !is.na(decoded)
    out[tried[fixed]] <- decoded[fixed]
    steps <- add_step(steps, tried[fixed], "encode", codec)
    steps <- add_step(steps, tried[fixed & restored], "transcode", "restore_byte_a0")
    steps <- add_step(steps, tried[fixed & lossy], "transcode", "replace_lossy_sequences")
    steps <- add_step(
      steps, tried[fixed], "decode",
      ifelse(variants[fixed], "utf-8-variants", "utf-8")
    )
    todo <- setdiff(todo, tried[fixed])
  }

  # Sequences of UTF-8 mojibake that remain are repaired in isolation.
  if (config$decode_inconsistent_utf8 && length(todo) > 0L) {
    tried <- todo[regex_detect(x[todo], patterns[["UTF8_DETECTOR_RE"]])]
    decoded <- fixer_decode_inconsistent_utf8(x[tried])
    fixed <- decoded != x[tried]
    out[tried[fixed]] <- decoded[fixed]
    steps <- add_step(steps, tried[fixed], "apply", "decode_inconsistent_utf8")
    todo <- setdiff(todo, tried[fixed])
  }

  # Latin-1 that was meant to be read as Windows-1252. Upstream first asks
  # whether the text could also be `windows-1252`, which is never so,
  # because that codec is not among those tried (ftfy/__init__.py:552).
  # The text is its own Latin-1 bytes. A hole of Windows-1252 fails the
  # decoding, and the text goes on to the next repair.
  tried <- todo[latin1[todo]]
  if (length(tried) > 0L) {
    decoded <- codec_decode(x[tried], "windows-1252")
    fixed <- !is.na(decoded) & decoded != x[tried]
    out[tried[fixed]] <- decoded[fixed]
    steps <- add_step(steps, tried[fixed], "encode", "latin-1")
    steps <- add_step(steps, tried[fixed], "decode", "windows-1252")
    todo <- setdiff(todo, tried[fixed])
  }

  # Single C1 controls, with a less satisfying explanation. Upstream
  # returns this step whenever the pattern matches, also when every match
  # is a hole of Windows-1252 and the text stays as it was.
  if (config$fix_c1_controls && length(todo) > 0L) {
    tried <- todo[regex_detect(x[todo], patterns[["C1_CONTROL_RE"]])]
    out[tried] <- fixer_fix_c1_controls(x[tried])
    steps <- add_step(steps, tried, "transcode", "fix_c1_controls")
  }

  # What remains is a mix-up between two single-byte codecs, which is left
  # unchanged.
  list(text = out, steps = bind_steps(steps))
}
