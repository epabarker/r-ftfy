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
