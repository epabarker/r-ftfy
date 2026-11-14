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
#
# The exact rule. A difference that says which options R was called with
# (the element `options`, a list; the corpus comparison of ticket #44 gives
# it) is judged by none of the rules above but by this one: R is run again
# on the same input with the same options, with its `utf-8-variants`
# decoder made to read a final newline as the reference version reads it
# (C0 0A at the end as C0 80; ED, A0 to AF, 80 to BF, ED, B0 to BF, 0A at
# the end as a pair whose last byte is 8A, since only the low six bits of
# that byte are used: ftfy/bad_codecs/utf8_variants.py:158 and :207). The
# difference is this departure when that run met such bytes and gives the
# reference version's result, and so nothing but the departure lies
# between the two. It is asked of the function itself, so the codecs
# tried, the lines and pieces fix_text() cuts and a second layer of repair
# are all as they are in the package. Further elements of such a
# difference:
#
# - `what`: "text" (the default) or "plan".
# - `plan`: for `fun = "apply_plan"`, the plan replayed.
# - `form`: "keyword" when the reference version's result is that of
#   fix_text() with one option of the encoding repair given as a keyword
#   argument, which it ignores (the departure encoding-sub-options-honoured):
#   the reference version's result is then looked for with default options.
#
# U+0000 is allowed for as the departure decoded-nul-dropped states it: a
# reference text is compared without its \u0000, and a reference plan of
# fix_and_explain() without one `apply remove_control_chars` after a
# `decode utf-8-variants`.
function(difference) {
  exact <- function(difference) {
    fun <- difference$fun
    input <- difference$input
    reference <- difference$reference
    actual <- difference$actual
    what <- if (is.null(difference$what)) "text" else difference$what
    functions <- c("fix_text", "fix_encoding", "fix_encoding_and_explain", "fix_and_explain", "apply_plan")
    if (!is.character(fun) || !fun %in% functions ||
        !is.character(input) || is.na(input) ||
        !is.character(reference) || is.na(reference) || !is.character(actual) ||
        (fun == "apply_plan") != is.na(actual)) {
      return(FALSE)
    }
    options <- difference$options
    if (identical(difference$form, "keyword")) {
      options <- list()
    }

    # The decoder as the reference version has it.
    real <- ftfy:::decode_utf8_variants
    met <- FALSE
    null_cut <- paste0("\\x{C0}\\x{0A}\\z")
    pair_cut <- "(\\x{ED}[\\x{A0}-\\x{AF}][\\x{80}-\\x{BF}]\\x{ED}[\\x{B0}-\\x{BF}])\\x{0A}\\z"
    opts <- stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9)
    testthat::local_mocked_bindings(
      decode_utf8_variants = function(bytes) {
        cut <- which(
          stringi::stri_detect_regex(bytes, null_cut, opts_regex = opts) |
            stringi::stri_detect_regex(bytes, pair_cut, opts_regex = opts)
        )
        if (length(cut) > 0L) {
          met <<- TRUE
          rewritten <- stringi::stri_replace_all_regex(
            bytes[cut], null_cut, intToUtf8(c(0xC0L, 0x80L)), opts_regex = opts
          )
          bytes[cut] <- stringi::stri_replace_all_regex(
            rewritten, pair_cut, paste0("$1", intToUtf8(0x8AL)), opts_regex = opts
          )
        }
        real(bytes)
      },
      .package = "ftfy"
    )
    theirs <- tryCatch(
      if (fun == "apply_plan") {
        ftfy::apply_plan(input, difference$plan)
      } else {
        result <- do.call(getExportedValue("ftfy", fun), c(list(input), options))
        if (is.data.frame(result)) {
          if (what == "plan") as.character(result$plan) else result$text
        } else {
          result
        }
      },
      error = function(e) NULL
    )
    if (!met || is.null(theirs) || is.na(theirs)) {
      return(FALSE)
    }
    if (what == "plan") {
      if (identical(reference, theirs)) {
        return(TRUE)
      }
      steps <- strsplit(reference, " > ", fixed = TRUE)[[1L]]
      decoded <- match("decode utf-8-variants", steps)
      extra <- which(steps == "apply remove_control_chars")
      extra <- extra[!is.na(decoded) & extra > decoded]
      return(fun == "fix_and_explain" && any(vapply(
        extra, function(at) identical(paste(steps[-at], collapse = " > "), theirs), logical(1L)
      )))
    }
    nul <- "\\u0000"
    if (grepl(nul, reference, fixed = TRUE)) {
      reference <- stringi::stri_unescape_unicode(gsub(nul, "", reference, fixed = TRUE))
    }
    identical(reference, theirs)
  }
  if (!is.null(difference$options)) {
    return(exact(difference))
  }

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
