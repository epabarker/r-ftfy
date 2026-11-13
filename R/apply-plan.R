# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Replay a plan on text
#'
#' `apply_plan()` carries out the steps of a plan on text, in order, with
#' no detection of what is wrong with the text. It repeats a repair that
#' [fix_encoding_and_explain()] found: on the same strings, or on other
#' strings that are known to be damaged in the same way.
#'
#' There are two ways to call it:
#'
#' * with one plan, which is replayed on every element of `x`;
#' * with one plan for each element of `x`, such as the `plan` column that
#'   came back with the texts. Each distinct plan is replayed once over all
#'   the elements that have it.
#'
#' Every plan this package returns can be replayed on the text it was made
#' for, and gives the fixed text.
#'
#' @section Failed replays:
#' A replay fails on a string when one of its steps cannot be carried out:
#' an `encode` step meets a character its codec does not have, or a
#' `decode` step meets bytes its codec cannot read. Nothing is guessed or
#' skipped: the call is an error of class `ftfy_replay_failed`, which names
#' the first element that failed, the step and the reason, and no text is
#' returned.
#'
#' A plan can also be impossible on every string, because its steps do not
#' fit together. An `encode` step turns text into bytes and a `decode`
#' step turns bytes into text; the fixers `restore_byte_a0` and
#' `replace_lossy_sequences` work on bytes, and every other fixer and
#' `normalize` work on text. A plan that decodes text, encodes bytes, hands
#' a fixer the wrong one of the two or ends with bytes fails on every
#' string that is not missing.
#'
#' A name that is not an accepted action, codec, fixer or normalisation
#' form is an error before anything is replayed. See [ftfy_plan()] for the
#' accepted names.
#'
#' @section Differences from Python ftfy:
#' `normalize` steps are replayed. Python ftfy 6.3.1 records them in the
#' plans of `fix_and_explain()`, but its `apply_plan()` raises
#' `Unknown plan step: normalize`. Normalisation uses the Unicode data of
#' the ICU library that the stringi package was built with.
#'
#' A plan that ends in an `encode` step returns a `bytes` object in Python;
#' here it is a failed replay. Where a `decode utf-8-variants` step decodes
#' the two bytes C0 80, which stand for the character U+0000, nothing is
#' put in their place, because an R string cannot hold U+0000. Codec names
#' are accepted in one spelling only.
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8.
#' @param plan The plan to replay: a vector of plans, or a character vector
#'   of plans in their text form (see [ftfy_plan()]), of length 1 or as
#'   long as `x`.
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`, and
#'   so does a missing plan. Attributes of `plan` are not used.
#'
#' @examples
#' x <- c("sch\u00c3\u00b6n", "caf\u00c3\u00a9", NA)
#' explained <- fix_encoding_and_explain(x)
#' explained
#'
#' # Each string with its own plan
#' apply_plan(x, explained$plan)
#'
#' # One plan on every string
#' apply_plan(c("d\u00c3\u00a9j\u00c3\u00a0 vu", "na\u00c3\u00afve"), explained$plan[1])
#' apply_plan("e\u0301", "normalize NFC")
#'
#' # A replay that fails is an error
#' try(apply_plan("5 \u20ac", "encode latin-1 > decode utf-8"))
#' @export
apply_plan <- function(x, plan) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  plan <- plan_text(as_plan(plan, "plan"))
  if (length(plan) != 1L && length(plan) != length(x)) {
    stop(
      "`plan` must hold one plan, or one plan for each element of `x` (",
      length(x), "), not ", length(plan), " plans.",
      call. = FALSE
    )
  }
  replayed <- replay(x, plan)
  stop_replay_failed(replayed$failed, plan)
  exit_step(replayed$text, shape)
}

# The unexported replay (ADR 0002): `apply_plan()` without the entry step,
# the checks and the error. This is the function column-aware repair calls.
#
# `x` is a bare character vector of valid UTF-8 strings and `NA`s, as
# `entry_step()` gives it. `plan` is a plan vector, or a character vector of
# text forms, that holds accepted names only (nothing is checked here), of
# length 1 or as long as `x`.
#
# Returns the replayed texts, parallel to `x` and marked as UTF-8: `NA`
# where the string is `NA`, where the plan is `NA`, and where the replay
# failed. It raises no error for any text or any plan of accepted names.
# A failed element is `is.na(result) & !is.na(x) & !is.na(plan)`.
replay_plan <- function(x, plan) {
  replay(x, plan)$text
}

# The replay with the place of each failure: a list of `text`, as
# `replay_plan()` returns it, and `failed`, the position in its plan of the
# step at which an element failed, or `NA` for an element that did not
# fail. An element whose plan ends with bytes failed after its last step,
# at the number of steps plus one.
#
# No loop is over strings: the elements are grouped by plan, each distinct
# plan is replayed once over the distinct strings of its group, and each of
# its steps is one call on those strings.
replay <- function(x, plan) {
  n <- length(x)
  plan <- rep_len(plan_text(plan), n)
  text <- rep(NA_character_, n)
  failed <- rep(NA_integer_, n)

  live <- which(!is.na(x) & !is.na(plan))
  distinct <- unique(plan[live])
  steps <- parse_steps(distinct)
  members <- split(live, match(plan[live], distinct))
  first_row <- match(seq_along(distinct), steps$element)
  count <- tabulate(steps$element, nbins = length(distinct))
  for (k in seq_along(distinct)) {
    at <- members[[k]]
    rows <- first_row[[k]] - 1L + seq_len(count[[k]])
    strings <- unique(x[at])
    replayed <- replay_steps(strings, steps$action[rows], steps$parameter[rows])
    back <- match(x[at], strings)
    text[at] <- replayed$text[back]
    failed[at] <- replayed$failed[back]
  }
  list(text = text, failed = failed)
}

# One plan, given as its steps, over strings with no `NA`: upstream's
# `apply_plan()` (ftfy/__init__.py:727) over a vector. Returns `text` and
# `failed` as `replay()` does.
replay_steps <- function(x, action, parameter) {
  failed <- rep(NA_integer_, length(x))
  kinds <- step_kinds(action, parameter)
  # The first step that is handed the wrong one of text and bytes, where
  # upstream raises whatever the string is; past the last step when the
  # plan ends with bytes, which are not text to return.
  misfit <- match(TRUE, c(kinds$needs != kinds$given, kinds$result != "text"))
  for (j in seq_along(action)) {
    live <- which(is.na(failed))
    if (length(live) == 0L) {
      break
    }
    if (identical(j, misfit)) {
      break
    }
    stepped <- replay_step(x[live], action[[j]], parameter[[j]])
    failed[live[is.na(stepped)]] <- j
    x[live] <- stepped
  }
  if (!is.na(misfit)) {
    failed[is.na(failed)] <- misfit
  }
  x[!is.na(failed)] <- NA_character_
  list(text = x, failed = failed)
}

# One step over strings with no `NA`: text or bytes held as text in, the
# same out, and `NA` where the step cannot be carried out. Only `encode`
# and `decode` can fail.
replay_step <- function(x, action, parameter) {
  switch(action,
    encode = codec_try_encode(x, parameter),
    decode = codec_decode(x, parameter),
    normalize = normalize_text(x, parameter),
    # `transcode` and `apply`: upstream does not tell them apart. Every
    # fixer a plan may name has its internal form under this name.
    get(paste0("fixer_", parameter), mode = "function")(x)
  )
}

# The fixers that work on bytes (ftfy/fixes.py:420 and :463). Every other
# fixer works on text, `fix_c1_controls` too, although upstream records it
# as a `transcode` step.
byte_fixers <- c("restore_byte_a0", "replace_lossy_sequences")

# What each step of one plan works on, "text" or "bytes": `needs`, what the
# step takes; `given`, what the steps before it hand it (the replay starts
# with text); and `result`, what the plan ends with.
step_kinds <- function(action, parameter) {
  needs <- rep("text", length(action))
  needs[action == "decode"] <- "bytes"
  needs[action %in% c("transcode", "apply") & parameter %in% byte_fixers] <- "bytes"
  gives <- needs
  gives[action == "encode"] <- "bytes"
  gives[action == "decode"] <- "text"
  after <- c("text", gives)
  list(
    needs = needs,
    given = after[seq_along(action)],
    result = after[[length(after)]]
  )
}

# Unicode normalisation of text, in one of the forms of
# `plan_normalizations`, by the ICU that stringi was built with. All four
# keep a leading U+FEFF. `NA` stays `NA`.
normalize_text <- function(x, form) {
  switch(form,
    NFC = stringi::stri_trans_nfc(x),
    NFD = stringi::stri_trans_nfd(x),
    NFKC = stringi::stri_trans_nfkc(x),
    NFKD = stringi::stri_trans_nfkd(x),
    stop("internal error: unknown normalisation form `", form, "`", call. = FALSE)
  )
}

# The error of `apply_plan()` for a failed replay, naming the first element
# that failed. `failed` is what `replay()` gave and `plan` the text forms,
# one or one per element.
stop_replay_failed <- function(failed, plan) {
  at <- which(!is.na(failed))
  if (length(at) == 0L) {
    return(invisible(NULL))
  }
  first <- at[[1L]]
  text <- rep_len(plan, length(failed))[[first]]
  steps <- parse_steps(text)
  j <- failed[[first]]
  kinds <- step_kinds(steps$action, steps$parameter)
  if (j > length(steps$action)) {
    reason <- paste0(
      "the plan `", text, "` ends with bytes, not text: ",
      "its last `encode` step has no `decode` step after it."
    )
  } else {
    step <- paste0("`", steps$action[[j]], " ", steps$parameter[[j]], "`")
    where <- paste0("step ", j, " of the plan `", text, "`, ", step, ", ")
    reason <- if (kinds$needs[[j]] != kinds$given[[j]]) {
      paste0(
        where, "works on ", kinds$needs[[j]], " and was handed ",
        kinds$given[[j]], ": an `encode` step turns text into bytes and a ",
        "`decode` step turns bytes into text."
      )
    } else if (steps$action[[j]] == "encode") {
      paste0(where, "met a character that the codec cannot encode.")
    } else {
      paste0(where, "met bytes that the codec cannot decode.")
    }
  }
  message <- paste0(
    "The replay failed in ", length(at), " of ", length(failed),
    " elements of `x` (first at: ", paste(utils::head(at, 5L), collapse = ", "),
    "). In element ", first, ", ", reason
  )
  stop(structure(
    class = c("ftfy_replay_failed", "error", "condition"),
    list(message = message, call = NULL, element = at, step = failed[at])
  ))
}
