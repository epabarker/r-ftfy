# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The `ftfy_plan` vector class (ADR 0002).
#
# A plan vector is stored as a character vector of text forms with the class
# attribute and nothing else: "none" for a plan with no steps, `NA` for a
# missing plan. The text form is a plan's identity, so comparing, counting
# and matching plans are character operations, and building or reading many
# plans at once never loops over plans. The storage is not part of the public
# contract; code outside this file goes through the functions under
# "Internal interface".

#' Plans: the steps that repaired a string
#'
#' A plan is the ordered sequence of steps that turned one string into its
#' fixed text. `ftfy_plan()` builds a vector of plans, one plan per element,
#' and `plan_steps()` expands a vector of plans into a data frame with one
#' row per step.
#'
#' @section Text form:
#' Every plan has a text form, which is a stable format and is the plan's
#' identity: two plans are equal exactly when their text forms are equal.
#' `as.character()` returns it and `ftfy_plan()` reads it back to the same
#' plan, so plans can be written to a file and rebuilt.
#'
#' * A step is written `action parameter`, for example `encode latin-1`.
#' * Steps are joined with `" > "`: `encode latin-1 > decode utf-8`.
#' * A plan with no steps is written `none`. Its text was not changed.
#' * A missing plan is `NA`. It belongs to a missing string, and is not the
#'   same thing as a plan with no steps.
#'
#' @section Accepted names:
#' A step is one of five actions with a parameter. Names are case-sensitive
#' and each thing has one name; any other name is an error.
#'
#' * `encode` and `decode` take a codec: `latin-1`, `sloppy-windows-1252`,
#'   `sloppy-windows-1251`, `sloppy-windows-1250`, `sloppy-windows-1253`,
#'   `sloppy-windows-1254`, `sloppy-windows-1257`, `iso-8859-2`, `macroman`,
#'   `cp437`, `windows-1252`, `utf-8` or `utf-8-variants`.
#' * `transcode` and `apply` take a fixer: `unescape_html`,
#'   `remove_terminal_escapes`, `restore_byte_a0`, `replace_lossy_sequences`,
#'   `decode_inconsistent_utf8`, `fix_c1_controls`, `fix_latin_ligatures`,
#'   `fix_character_width`, `uncurl_quotes`, `fix_line_breaks` or
#'   `remove_control_chars`.
#' * `normalize` takes a normalisation form: `NFC`, `NFD`, `NFKC` or `NFKD`.
#'
#' @section Python ftfy:
#' Python ftfy writes a plan as a list of `(action, parameter)` pairs.
#' `ftfy_plan()` builds one plan from such a list, and the `action` and
#' `parameter` columns of `plan_steps()` give the pairs back, so every plan
#' converts both ways without loss. Python's codec aliases (`latin1`,
#' `cp1252`) and its `fix_surrogates` fixer are not accepted.
#'
#' @section Methods:
#' A vector of plans can be printed, subset with `[` and `[[`, combined with
#' `c()`, repeated with `rep()`, compared with `==` and `!=`, tested with
#' `is.na()`, reduced with `unique()`, counted with `table()` and used as a
#' column of a data frame. Comparing a plan with a character vector reads
#' the character vector as text forms first.
#'
#' @param x For `ftfy_plan()`, one of:
#'   * a character vector of text forms, giving one plan per element;
#'   * a list of `c(action, parameter)` pairs, giving one plan with those
#'     steps in that order (`list()` gives one plan with no steps);
#'   * a vector of plans, which is returned as it is.
#'
#'   For `plan_steps()`, a vector of plans, or a character vector of text
#'   forms.
#'
#' @return `ftfy_plan()` returns a vector of class `ftfy_plan`.
#'
#'   `plan_steps()` returns a data frame with one row per step and four
#'   columns: `element`, the position of the plan in `x`; `step`, the
#'   position of the step in its plan, from 1; `action`; and `parameter`.
#'   Plans with no steps and missing plans give no rows.
#'
#' @examples
#' plan <- ftfy_plan(c("encode latin-1 > decode utf-8", "none", NA))
#' plan
#' as.character(plan)
#' plan == "none"
#' table(plan)
#' plan_steps(plan)
#'
#' # One plan from Python ftfy's list of pairs
#' ftfy_plan(list(c("encode", "latin-1"), c("decode", "utf-8")))
#' @export
ftfy_plan <- function(x) {
  if (inherits(x, "ftfy_plan")) {
    return(x)
  }
  if (is.character(x) || all_na_logical(x)) {
    return(plan_from_text(x))
  }
  if (is.list(x) && !is.object(x)) {
    return(plan_from_pairs(x))
  }
  stop(
    "`x` must be a character vector of plans in their text form, ",
    "or a list of `c(action, parameter)` pairs, not ", describe_type(x), ".",
    call. = FALSE
  )
}

#' @rdname ftfy_plan
#' @export
plan_steps <- function(x) {
  plan_step_table(as_plan(x, "x"))
}

# Internal interface ----------------------------------------------------
#
# What the functions that produce and replay plans use. All of it works on
# whole vectors.

# A plan vector from text forms that are already known to be good: "none",
# `NA`, or steps this file wrote. Nothing is checked.
new_plan <- function(text = character()) {
  structure(text, class = "ftfy_plan")
}

# The text forms of a plan vector, as a plain character vector.
plan_text <- function(x) {
  as.character(unclass(x))
}

# Add one step to the end of some plans, for recording a step inside a pass
# over many strings. `text` is a character vector of text forms and so is
# the result. `at` says which plans get the step (anything `[` takes, with no
# repeats); `action` and `parameter` are single strings or one per chosen
# plan. A missing plan stays missing. Names are not checked.
plan_add_step <- function(text, action, parameter, at = seq_along(text)) {
  old <- text[at]
  step <- paste(action, parameter)
  new <- paste0(old, plan_separator, step)
  none <- !is.na(old) & old == plan_none
  new[none] <- rep_len(step, length(old))[none]
  new[is.na(old)] <- NA_character_
  text[at] <- new
  text
}

# The text forms of `n` plans from a long table of their steps: one entry of
# `element`, `action` and `parameter` per step, with `element` the plan's
# position from 1 to `n`. The steps of one plan must be in order, but may be
# anywhere in the table. A plan with no entries is "none"; the caller sets
# missing plans to `NA`. Names are not checked.
plan_text_from_steps <- function(n, element, action, parameter) {
  text <- rep(plan_none, n)
  # The position of each step in its plan.
  step <- integer(length(element))
  step[order(element)] <- sequence(tabulate(element, nbins = n))
  # One pass per step position, never one per plan.
  for (k in seq_len(max(step, 0L))) {
    rows <- which(step == k)
    text <- plan_add_step(text, action[rows], parameter[rows], element[rows])
  }
  text
}

# The steps of a plan vector, or of a character vector of text forms, as the
# long data frame `plan_steps()` returns. Plans are split once per distinct
# plan. To replay, call this on `unique(x)` and `match()` back.
plan_step_table <- function(x) {
  text <- plan_text(x)
  distinct <- unique(text)
  parsed <- parse_steps(distinct)
  # Rows of `parsed` for each element of `x`, in element order.
  per_distinct <- tabulate(parsed$element, nbins = length(distinct))
  first_row <- cumsum(per_distinct) - per_distinct
  which_distinct <- match(text, distinct)
  count <- per_distinct[which_distinct]
  rows <- rep(first_row[which_distinct], count) + sequence(count)
  data.frame(
    element = rep(seq_along(text), count),
    step = parsed$step[rows],
    action = parsed$action[rows],
    parameter = parsed$parameter[rows],
    stringsAsFactors = FALSE
  )
}

# Stop unless every step names an accepted action and a parameter that
# action accepts. `action` and `parameter` are parallel vectors.
check_steps <- function(action, parameter) {
  check_names(action, plan_actions, "action", "actions")
  codec <- action %in% c("encode", "decode")
  check_names(parameter[codec], plan_codecs, "codec", "codecs")
  fixer <- action %in% c("transcode", "apply")
  check_names(parameter[fixer], plan_fixers, "fixer", "fixers")
  form <- action == "normalize"
  check_names(
    parameter[form], plan_normalizations,
    "normalisation form", "normalisation forms"
  )
  invisible(NULL)
}

# Text form ---------------------------------------------------------------

plan_none <- "none"
plan_separator <- " > "

# Split text forms into steps, with no checks: a list of parallel vectors
# `element`, `step`, `action` and `parameter`. "none" and `NA` give no
# steps. A step with no space in it has an empty parameter.
parse_steps <- function(text) {
  has_steps <- !is.na(text) & text != plan_none
  pieces <- strsplit(text[has_steps], plan_separator, fixed = TRUE)
  count <- lengths(pieces)
  flat <- unlist(pieces, use.names = FALSE)
  if (is.null(flat)) {
    flat <- character()
  }
  space <- regexpr(" ", flat, fixed = TRUE)
  space[space < 0L] <- nchar(flat)[space < 0L] + 1L
  list(
    element = rep(which(has_steps), count),
    step = sequence(count),
    action = substring(flat, 1L, space - 1L),
    parameter = substring(flat, space + 1L)
  )
}

# A plan vector from text forms nobody has checked yet.
plan_from_text <- function(x) {
  text <- as.character(x)
  attributes(text) <- NULL
  distinct <- unique(text[!is.na(text)])

  # Every accepted name is ASCII, so anything else cannot be a plan. This
  # also keeps invalid UTF-8 away from the splitting below.
  malformed <- !stringi::stri_enc_isascii(distinct)
  parsed <- parse_steps(distinct[!malformed])
  # Rebuilding the text form from the steps and comparing it with what was
  # given catches every other departure from the format: stray spaces, a
  # missing parameter, a trailing separator, the empty string.
  rebuilt <- plan_text_from_steps(
    sum(!malformed), parsed$element, parsed$action, parsed$parameter
  )
  malformed[!malformed] <- rebuilt != distinct[!malformed]
  if (any(malformed)) {
    stop_malformed(text, distinct[malformed])
  }
  check_steps(parsed$action, parsed$parameter)
  new_plan(text)
}

# One plan from upstream's list of (action, parameter) pairs.
plan_from_pairs <- function(x) {
  flat <- unlist(x, use.names = FALSE)
  if (is.null(flat)) {
    flat <- character()
  }
  pairs <- all(lengths(x) == 2L) && length(flat) == 2L * length(x) &&
    all(rapply(x, is.character, how = "unlist")) && !anyNA(flat)
  if (!pairs) {
    stop(
      "A list given to `ftfy_plan()` must hold `c(action, parameter)` pairs, ",
      "each a pair of strings, such as ",
      "`list(c(\"encode\", \"latin-1\"), c(\"decode\", \"utf-8\"))`.",
      call. = FALSE
    )
  }
  action <- flat[seq(1L, by = 2L, length.out = length(x))]
  parameter <- flat[seq(2L, by = 2L, length.out = length(x))]
  check_steps(action, parameter)
  new_plan(
    plan_text_from_steps(1L, rep(1L, length(action)), action, parameter)
  )
}

stop_malformed <- function(text, bad) {
  at <- which(text %in% bad)
  shown <- bad[[1L]]
  if (stringi::stri_enc_isascii(shown)) {
    shown <- encodeString(shown, quote = "\"")
  } else {
    shown <- "a string with characters outside ASCII"
  }
  stop(
    "`x` is not a plan in its text form in ", length(at), " of ",
    length(text), " elements (first at: ",
    paste(utils::head(at, 5L), collapse = ", "), "): ", shown, ". ",
    "Write each step as `action parameter`, join steps with ` > `, ",
    "write a plan with no steps as `none` and a missing plan as `NA`.",
    call. = FALSE
  )
}

check_names <- function(given, accepted, what, what_plural) {
  unknown <- setdiff(given, accepted)
  if (length(unknown) > 0L) {
    stop(
      "Unknown ", what, " in a plan: ",
      paste(encodeString(unknown, quote = "\""), collapse = ", "), ". ",
      "Accepted ", what_plural, ": ", paste(accepted, collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(NULL)
}

all_na_logical <- function(x) {
  is.logical(x) && !is.object(x) && all(is.na(x))
}

# What the methods accept beside a plan vector: text forms, or `NA`s.
as_plan <- function(x, arg) {
  if (inherits(x, "ftfy_plan") || is.character(x) || all_na_logical(x)) {
    return(ftfy_plan(x))
  }
  stop(
    "`", arg, "` must be a vector of plans or a character vector of plans ",
    "in their text form, not ", describe_type(x), ".",
    call. = FALSE
  )
}

# Methods -------------------------------------------------------------------

#' @export
as.character.ftfy_plan <- function(x, ...) {
  plan_text(x)
}

#' @export
format.ftfy_plan <- function(x, ...) {
  plan_text(x)
}

#' @export
print.ftfy_plan <- function(x, ...) {
  n <- length(x)
  cat("<ftfy_plan[", n, "]>\n", sep = "")
  shown <- min(n, getOption("max.print", 99999L))
  if (shown > 0L) {
    text <- format(x)[seq_len(shown)]
    text[is.na(text)] <- "<NA>"
    index <- format(paste0("[", seq_len(shown), "]"), justify = "right")
    cat(paste(index, text), sep = "\n")
  }
  if (shown < n) {
    cat("# ... and ", n - shown, " more\n", sep = "")
  }
  invisible(x)
}

#' @export
length.ftfy_plan <- function(x) {
  length(unclass(x))
}

#' @export
is.na.ftfy_plan <- function(x) {
  is.na(plan_text(x))
}

#' @export
`[.ftfy_plan` <- function(x, i) {
  new_plan(plan_text(x)[i])
}

#' @export
`[[.ftfy_plan` <- function(x, i) {
  new_plan(plan_text(x)[[i]])
}

#' @export
`[<-.ftfy_plan` <- function(x, i, value) {
  text <- plan_text(x)
  text[i] <- plan_text(as_plan(value, "value"))
  new_plan(text)
}

#' @export
`[[<-.ftfy_plan` <- function(x, i, value) {
  text <- plan_text(x)
  text[[i]] <- plan_text(as_plan(value, "value"))
  new_plan(text)
}

#' @export
c.ftfy_plan <- function(...) {
  parts <- lapply(list(...), function(part) plan_text(as_plan(part, "...")))
  new_plan(as.character(unlist(parts, use.names = FALSE)))
}

#' @export
rep.ftfy_plan <- function(x, ...) {
  new_plan(rep(plan_text(x), ...))
}

#' @export
unique.ftfy_plan <- function(x, incomparables = FALSE, ...) {
  new_plan(unique(plan_text(x), incomparables = incomparables, ...))
}

# Plans sort in the order of their text forms, which is what gives
# `table()` its order.
#' @export
xtfrm.ftfy_plan <- function(x) {
  xtfrm(plan_text(x))
}

#' @export
Ops.ftfy_plan <- function(e1, e2) {
  if (!.Generic %in% c("==", "!=") || missing(e2)) {
    stop(
      "`", .Generic, "` is not defined for plans. ",
      "Plans can be compared with `==` and `!=` only.",
      call. = FALSE
    )
  }
  e1 <- plan_text(as_plan(e1, "e1"))
  e2 <- plan_text(as_plan(e2, "e2"))
  get(.Generic)(e1, e2)
}

#' @export
as.data.frame.ftfy_plan <- function(x, row.names = NULL, optional = FALSE, ...,
                                    nm = deparse1(substitute(x))) {
  force(nm)
  as.data.frame.vector(x, row.names = row.names, optional = optional, ..., nm = nm)
}
