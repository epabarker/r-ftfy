# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Repair encoding mix-ups and say how
#'
#' `fix_encoding_and_explain()` repairs mojibake as [fix_encoding()] does
#' and returns, beside each repaired text, the plan that produced it: the
#' steps that were taken, in order. A plan can be counted, compared and
#' taken apart with [plan_steps()]; see [ftfy_plan()].
#'
#' The plans are those Python ftfy 6.3.1 records. A step is recorded
#' whenever the repair takes it, also when it leaves the text as it was:
#' `"a\u0081b"` comes back unchanged with the plan
#' `transcode fix_c1_controls`. So a plan with no steps means the text is
#' unchanged, but unchanged text does not mean a plan with no steps.
#'
#' Call it on a whole vector, not once per string.
#'
#' @inheritSection fix_encoding Differences from Python ftfy
#'
#' @inheritParams fix_encoding
#'
#' @return A data frame with one row for each element of `x`, in the order
#'   of `x`, and two columns:
#'
#'   * `text`: the repaired text, a character vector marked as UTF-8.
#'   * `plan`: the plan that produced it, a vector of class `ftfy_plan`.
#'     Text on which no step was taken has the plan `none`.
#'
#'   A missing string gives `NA` in both columns. The `names`, `dim` and
#'   `dimnames` of `x` are not carried into the data frame.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "voil\u00c3 le travail", "caf\u00e9", NA)
#' explained <- fix_encoding_and_explain(x)
#' explained
#'
#' # How often each plan was used
#' table(explained$plan)
#'
#' # One row per step
#' plan_steps(explained$plan)
#' @export
fix_encoding_and_explain <- function(x, ..., config = ftfy_config()) {
  x <- entry_step(x)
  config <- resolve_config(..., config = config)
  # Each distinct value is repaired once (ADR 0008).
  distinct <- unique(x)
  repaired <- repair_encoding(distinct, config)
  at <- match(x, distinct)
  explained_frame(repaired$text[at], encoding_plan_text(repaired, distinct)[at])
}

# The value of the two explaining exports (ADR 0002): a plain data frame
# with the columns `text` and `plan`, one row per input, row names 1 to n.
# `text` is the fixed texts and `plan_text` the text forms of their plans
# ("none", `NA` for a missing string, or steps), parallel to each other and
# without attributes.
explained_frame <- function(text, plan_text) {
  data.frame(text = text, plan = new_plan(plan_text), stringsAsFactors = FALSE)
}

#' Fix text and say how
#'
#' `fix_and_explain()` runs every fixer on each string and returns, beside
#' each fixed text, the plan that produced it: the steps that were taken,
#' in order. A plan can be replayed on other text with [apply_plan()], and
#' counted, compared and taken apart with [plan_steps()]; see
#' [ftfy_plan()].
#'
#' Each string is fixed whole, as one segment, however many lines it has.
#' The fixers run in the order of Python ftfy 6.3.1: `unescape_html`, the
#' encoding repair of [fix_encoding()], `fix_c1_controls`,
#' `fix_latin_ligatures`, `fix_character_width`, `uncurl_quotes`,
#' `fix_line_breaks`, `remove_terminal_escapes`, `remove_control_chars`,
#' and then normalisation. They run again, in that order, until the text
#' stops changing. A fixer whose option is `FALSE` is left out. With
#' `unescape_html = "auto"`, the default, HTML entities are left alone in
#' a string that holds a `<`, which is taken to be HTML.
#'
#' The plans are those Python ftfy 6.3.1 records. A fixer is recorded as a
#' step `apply <fixer>` in each round in which it changed the text, and
#' normalisation as `normalize <form>`. The steps of the encoding repair
#' are recorded whenever the repair takes them, also when they leave the
#' text as it was (see [fix_encoding_and_explain()]). So a plan with no
#' steps means the text is unchanged, but unchanged text does not mean a
#' plan with no steps.
#'
#' Call it on a whole vector, not once per string.
#'
#' @section Differences from Python ftfy:
#' Normalisation is done by the ICU library that stringi was built with,
#' so text that holds characters newer than that library's version of
#' Unicode can be normalised differently from Python ftfy 6.3.1 on Python
#' 3.13, which has Unicode 15.1. Every plan can be replayed: [apply_plan()]
#' replays `normalize` steps. Where the encoding repair decodes the two
#' bytes C0 80, which stand for the character U+0000, nothing is put in
#' their place, so no step `apply remove_control_chars` is recorded for
#' removing it. And a string that ends in a newline just after the byte
#' C0, or after the first five bytes of a six-byte surrogate pair, is not
#' repaired by reading the newline as the missing byte.
#'
#' Every departure from the reference version is listed, with examples,
#' on the page [ftfy-differences].
#'
#' @inheritParams fix_encoding
#'
#' @return A data frame with one row for each element of `x`, in the order
#'   of `x`, and two columns:
#'
#'   * `text`: the fixed text, a character vector marked as UTF-8.
#'   * `plan`: the plan that produced it, a vector of class `ftfy_plan`.
#'     Text on which no step was taken has the plan `none`.
#'
#'   A missing string gives `NA` in both columns. The `names`, `dim` and
#'   `dimnames` of `x` are not carried into the data frame.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "&lt;3 \u201cquotes\u201d", "<b>&amp;</b>", "plain", NA)
#' explained <- fix_and_explain(x)
#' explained
#'
#' # How often each plan was used
#' table(explained$plan)
#'
#' # One row per step
#' plan_steps(explained$plan)
#'
#' # A plan replays to its text
#' apply_plan(x, explained$plan)
#'
#' # Options change what is fixed and so what is recorded
#' fix_and_explain(x, uncurl_quotes = FALSE, unescape_html = TRUE)
#' @export
fix_and_explain <- function(x, ..., config = ftfy_config()) {
  x <- entry_step(x)
  config <- resolve_config(..., config = config)
  # Each distinct value is fixed once (ADR 0008).
  distinct <- unique(x)
  fixed <- fix_segments(distinct, config)
  at <- match(x, distinct)
  explained_frame(fixed$text[at], encoding_plan_text(fixed, distinct)[at])
}

# The fixers of the loop that come after the encoding repair, in the order
# upstream runs them (ftfy/__init__.py:398), less `fix_surrogates`, which
# is not ported. Each is gated by the option of its own name and found as
# `fixer_<name>`.
loop_fixers <- c(
  "fix_c1_controls", "fix_latin_ligatures", "fix_character_width",
  "uncurl_quotes", "fix_line_breaks", "remove_terminal_escapes",
  "remove_control_chars"
)

# The fixer loop over a vector of segments: upstream's `fix_and_explain()`
# (ftfy/__init__.py:359) on each element, each taken whole.
#
# `x` is a bare character vector of valid UTF-8 strings and `NA`s, as
# `entry_step()` gives it or any pieces cut from that. `config` is the
# resolved `ftfy_config` object, received whole.
#
# `unescape_html` says, for each element, whether the fixer `unescape_html`
# runs on it: a logical vector parallel to `x`, with no `NA`. Left `NULL`,
# it is decided from `config$unescape_html` as upstream decides it for one
# segment: `TRUE` or `FALSE` for every element, or, for "auto", `TRUE`
# for the elements that hold no "<". It is decided once, from the text as
# it comes in, and not looked at again. `fix_text()` passes its own vector,
# because there a "<" switches the fixer off for the later segments of the
# same string too (ftfy/__init__.py:351); when it does, the option in
# `config` is not read.
#
# Returns what `repair_encoding()` returns: a list of `text`, the fixed
# texts parallel to `x` with `NA` where `x` is, and `steps`, every step
# recorded, as a data frame of `element` (a position in `x`), `action` and
# `parameter`, the steps of one element in the order taken.
# `encoding_plan_text(result, x)` makes the plans' text forms from it.
#
# Each fixer runs once over every element still changing, and only the
# elements a round changed go round again. An element changed if its text
# after the round differs from its text before it; a recorded step does
# not say so, because the encoding repair records steps that change
# nothing. Nothing here deduplicates: the caller does.
fix_segments <- function(x, config, unescape_html = NULL) {
  if (is.null(unescape_html)) {
    unescape_html <- if (identical(config$unescape_html, "auto")) {
      !grepl("<", x, fixed = TRUE)
    } else {
      rep(config$unescape_html, length(x))
    }
  }
  text <- x
  steps <- new_steps()
  live <- which(could_change(x))
  while (length(live) > 0L) {
    before <- text[live]
    now <- before

    html <- which(unescape_html[live])
    if (length(html) > 0L) {
      fixed <- fixer_unescape_html(now[html])
      steps <- add_step(steps, live[html[fixed != now[html]]], "apply", "unescape_html")
      now[html] <- fixed
    }

    if (config$fix_encoding) {
      repaired <- repair_encoding(now, config)
      steps <- add_steps(steps, repaired$steps, element = live[repaired$steps$element])
      now <- repaired$text
    }

    for (name in loop_fixers) {
      if (config[[name]]) {
        fixed <- get(paste0("fixer_", name), mode = "function")(now)
        steps <- add_step(steps, live[fixed != now], "apply", name)
        now <- fixed
      }
    }

    if (!is.null(config$normalization)) {
      fixed <- normalize_text(now, config$normalization)
      steps <- add_step(steps, live[fixed != now], "normalize", config$normalization)
      now <- fixed
    }

    text[live] <- now
    live <- live[now != before]
  }
  list(text = text, steps = bind_steps(steps))
}

# The screen of ADR 0008: `FALSE` for a missing string and for text that no
# fixer can change under any options, which is printable ASCII, tab and
# newline, with no "&".
could_change <- function(x) {
  screened <- c(1:8, 11:31, utf8ToInt("&"), 127L)
  plain <- stringi::stri_enc_isascii(x) & !regex_detect(x, code_point_class(screened))
  !is.na(x) & !plain
}
