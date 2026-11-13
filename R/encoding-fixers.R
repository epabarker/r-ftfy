# Derived from python-ftfy v6.3.1, ftfy/fixes.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The four fixers the encoding repair uses (R/encoding.R). Two work on
# bytes held as text and are internal; two work on text and are exported.
#
# Each has an internal form named `fixer_<name>`, after its name in
# `plan_fixers`, as the fixers of R/text-fixers.R have: it takes a bare
# character vector and returns one of the same length, keeps `NA` as `NA`,
# runs no entry step and never loops over strings. A string it does not
# change comes back identical.

#' Repair UTF-8 mojibake inside other text
#'
#' Text from one encoding sometimes ends up inside text from another, so
#' that the string as a whole cannot be decoded in any one way.
#' `decode_inconsistent_utf8()` finds the sequences in each string that
#' plainly are UTF-8 mojibake and repairs each as [fix_encoding()] would
#' repair it alone, leaving the rest of the string as it is.
#'
#' [fix_encoding()] does this itself, as one of its steps, for a string it
#' cannot decode as a whole (the option `decode_inconsistent_utf8`). A
#' sequence that is the whole string is left alone here: that is the case
#' [fix_encoding()] handles.
#'
#' Call it on a whole vector, not once per string.
#'
#' @inheritParams badness
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`.
#'
#' @seealso [fix_encoding()], [fix_c1_controls()]
#'
#' @examples
#' # A snowman that was never mangled, beside mojibake
#' x <- c("\u2603 caf\u00c3\u00a9", "caf\u00e9", NA)
#' decode_inconsistent_utf8(x)
#' @export
decode_inconsistent_utf8 <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_decode_inconsistent_utf8(x), shape)
}

#' Read C1 control characters as Windows-1252
#'
#' `fix_c1_controls()` replaces each C1 control character (U+0080 to
#' U+009F) with the character Windows-1252 has at the same byte, which is
#' what web browsers do. U+0085 becomes an ellipsis and U+0092 a right
#' single quotation mark. The five that Windows-1252 leaves unassigned
#' (U+0081, U+008D, U+008F, U+0090 and U+009D) stay as they are.
#'
#' [fix_encoding()] does this itself, as its last resort (the option
#' `fix_c1_controls`).
#'
#' Call it on a whole vector, not once per string.
#'
#' @inheritParams badness
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`.
#'
#' @seealso [fix_encoding()], [decode_inconsistent_utf8()]
#'
#' @examples
#' x <- c("that\u0092s all\u0085", "plain", NA)
#' fix_c1_controls(x)
#' @export
fix_c1_controls <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_fix_c1_controls(x), shape)
}

# Upstream's `fix_c1_controls()` (ftfy/fixes.py:505) over a vector: every
# C1 control is encoded as Latin-1 and decoded as `sloppy-windows-1252`,
# which is one translation of the 32 characters. `NA` stays `NA`.
fixer_fix_c1_controls <- function(x) {
  controls <- 0x80:0x9F
  becomes <- codec_tables[["sloppy-windows-1252"]][controls + 1L]
  moved <- becomes != controls
  has <- which(regex_detect(x, patterns[["C1_CONTROL_RE"]]))
  x[has] <- translate(intToUtf8(controls[moved]), intToUtf8(becomes[moved]), x[has])
  x
}

# Upstream's `decode_inconsistent_utf8()` (ftfy/fixes.py:481) over a
# vector. Every match of `UTF8_DETECTOR_RE` that is shorter than its
# string and is bad is replaced by its own encoding repair. All matches of
# the whole vector are repaired in one call, each distinct one once.
#
# That repair runs with the default options whatever the caller's are, as
# upstream's does: it calls `ftfy.fix_encoding(substr)` with no config
# (ftfy/fixes.py:494).
fixer_decode_inconsistent_utf8 <- function(x) {
  splice_matches(x, patterns[["UTF8_DETECTOR_RE"]], function(matched, whole) {
    shorter <- nchar(matched, type = "chars") < nchar(whole, type = "chars")
    repairable <- which(shorter)
    repairable <- repairable[regex_detect(matched[repairable], patterns[["BADNESS_RE"]])]
    distinct <- unique(matched[repairable])
    repaired <- repair_encoding(distinct, ftfy_config())$text
    matched[repairable] <- repaired[match(matched[repairable], distinct)]
    matched
  })
}

# Upstream's `restore_byte_a0()` (ftfy/fixes.py:419) over bytes held as
# text: puts back byte A0 where a space stands in a sequence
# that would otherwise be UTF-8.
fixer_restore_byte_a0 <- function(bytes) {
  # C3 20, an a with grave accent as a word of its own, keeps its space.
  bytes <- regex_guard(
    stringi::stri_replace_all_regex(
      bytes, patterns[["A_GRAVE_WORD_RE"]], "\u00c3\u00a0 ",
      opts_regex = regex_opts()
    ),
    bytes
  )
  splice_matches(bytes, patterns[["ALTERED_UTF8_RE"]], function(matched, whole) {
    gsub(" ", "\u00a0", matched, fixed = TRUE)
  })
}

# Upstream's `replace_lossy_sequences()` (ftfy/fixes.py:442) over bytes
# held as text: a sequence that would be UTF-8 but for a byte 1A or a "?"
# in it becomes the three bytes of U+FFFD.
fixer_replace_lossy_sequences <- function(bytes) {
  regex_guard(
    stringi::stri_replace_all_regex(
      bytes, patterns[["LOSSY_UTF8_RE"]], "\u00ef\u00bf\u00bd",
      opts_regex = regex_opts()
    ),
    bytes
  )
}

# Locate, compute, splice (ADR 0008): replace every match of `pattern` in
# `x` by a computed value. `NA` stays `NA`. `compute(matched, whole)`
# takes every match of the whole vector at once, with the string each came
# from beside it, and returns their replacements.
#
# Positions come from `stri_locate_all_regex()` and the pieces are cut
# with `substring()`, both of which keep a leading U+FEFF. Nothing here
# loops over strings or over matches.
splice_matches <- function(x, pattern, compute) {
  if (anyNA(x)) {
    present <- which(!is.na(x))
    x[present] <- splice_matches(x[present], pattern, compute)
    return(x)
  }
  located <- regex_locate_all(x, pattern)
  count <- lengths(located, use.names = FALSE) %/% 2L
  if (!any(count > 0L)) {
    return(x)
  }
  # Each matrix unlists as its starts and then its ends.
  flat <- unlist(located, use.names = FALSE)
  is_start <- sequence(2L * count) <= rep.int(count, 2L * count)
  start <- flat[is_start]
  end <- flat[!is_start]
  element <- rep.int(seq_along(x), count)
  matched <- substring(x[element], start, end)
  replacement <- compute(matched, x[element])

  # A string with matches is its gaps and replacements in turn, then what
  # is left after its last match.
  first <- !duplicated(element)
  gap_start <- c(1L, end[-length(end)] + 1L)
  gap_start[first] <- 1L
  gap <- substring(x[element], gap_start, start - 1L)
  spliced <- which(count > 0L)
  last <- cumsum(count)[spliced]
  rest <- substring(x[spliced], end[last] + 1L, nchar(x[spliced], type = "chars"))

  match_number <- seq_along(element)
  pieces <- c(gap, replacement, rest)
  owner <- c(element, element, spliced)
  place <- order(owner, c(2 * match_number - 1, 2 * match_number, 2 * last + 0.5))
  x[spliced] <- paste_runs(pieces[place], owner[place])
  x
}

# Paste together the pieces of each run of equal `owner`, giving one string
# per run, in order. Neighbouring pieces are pasted in pairs until every
# run is one piece, so the work is the total length times the logarithm of
# the longest run, with no loop over runs.
paste_runs <- function(pieces, owner) {
  while (anyDuplicated(owner) > 0L) {
    starts <- which(!duplicated(owner))
    position <- sequence(diff(c(starts, length(owner) + 1L)))
    odd <- position %% 2L == 1L
    paired <- which(odd & c(owner[-1L] == owner[-length(owner)], FALSE))
    pieces[paired] <- paste0(pieces[paired], pieces[paired + 1L])
    pieces <- pieces[odd]
    owner <- owner[odd]
  }
  pieces
}
