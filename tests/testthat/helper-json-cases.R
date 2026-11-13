# Derived from python-ftfy v6.3.1, tests/test_examples_in_json.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The harness for the upstream JSON cases (resolution of #14).
#
# - upstream/test_cases.json is upstream's file, byte for byte.
# - reference/json_cases.tsv is the snapshot of what the reference version
#   gives for each case, written by data-raw/generators/snapshot_json_cases.py.
# - not-yet-passing.txt lists the checks the package cannot pass yet.
#
# A case is identified by its index in the JSON array, from 0, and by
# nothing else: one record occurs twice (indexes 7 and 10) and runs twice.

# The JSON reader. A missing reader is an error and never a skip: skipping
# would let the package pass with none of the cases run.
json_reader <- function(available = requireNamespace("jsonlite", quietly = TRUE)) {
  if (!available) {
    stop(
      "The package 'jsonlite' is needed to read the upstream JSON cases. ",
      "These tests are never skipped: install 'jsonlite'.",
      call. = FALSE
    )
  }
  function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
}

json_cases_path <- function() test_path("upstream", "test_cases.json")

# One row per case: what the JSON says, beside the reference version's
# texts and plans from the snapshot.
read_json_cases <- function(reader = json_reader()) {
  records <- reader(json_cases_path())
  field <- function(name) {
    vapply(records, function(record) {
      value <- record[[name]]
      if (is.null(value)) NA_character_ else enc2utf8(value)
    }, "")
  }
  cases <- data.frame(
    index = seq_along(records) - 1L,
    expect = field("expect"),
    original = field("original"),
    fixed = field("fixed"),
    fixed_encoding = field("fixed-encoding"),
    stringsAsFactors = FALSE
  )
  # "fixed-encoding" is optional and stands for "fixed" when absent.
  absent <- is.na(cases$fixed_encoding)
  cases$fixed_encoding[absent] <- cases$fixed[absent]

  snapshot <- read_reference_table(
    "json_cases.tsv",
    text = c("original", "fix_text", "fix_and_explain_text", "fix_encoding_text",
             "extra_layer", "extra_layer_fix_text")
  )
  if (!identical(as.integer(snapshot$index), cases$index) ||
      !identical(snapshot$expect, cases$expect) ||
      !identical(snapshot$original, cases$original)) {
    stop("reference/json_cases.tsv does not match upstream/test_cases.json: regenerate it")
  }
  cbind(cases, reference = snapshot[setdiff(names(snapshot), names(cases))])
}

# The checks. Each takes the rows of the cases it applies to and returns
# one logical per row. They are written against the exports the spec (#27)
# names; a check that calls a function not built yet raises an error, which
# `run_json_checks()` counts as not passing for every case.
#
# Where a check compares with the JSON or the snapshot, a difference is
# accepted only when a departure registry entry matches it.

# Upstream's call in tests/test_examples_in_json.py:68, less `fix_surrogates`,
# which has no counterpart in R.
fix_text_encoding_only <- function(x) {
  fix_text(
    x,
    unescape_html = FALSE,
    remove_terminal_escapes = FALSE,
    fix_character_width = FALSE,
    fix_latin_ligatures = FALSE,
    uncurl_quotes = FALSE,
    fix_line_breaks = FALSE,
    remove_control_chars = FALSE,
    normalization = NULL
  )
}

same_text <- function(a, b) !is.na(a) & !is.na(b) & a == b

json_checks <- list(
  # tests/test_examples_in_json.py:47, test_json_example(), for the cases
  # marked "pass".
  "pass-1-fix-text" = list(expect = "pass", run = function(cases) {
    agrees_with_reference("fix_text", cases$original,
                          fix_text(cases$original), cases$fixed)
  }),
  "pass-2-plan-replays" = list(expect = "pass", run = function(cases) {
    explained <- fix_and_explain(cases$original)
    same_text(apply_plan(cases$original, explained$plan), explained$text)
  }),
  "pass-3-encoding-plan-replays" = list(expect = "pass", run = function(cases) {
    explained <- fix_encoding_and_explain(cases$original)
    same_text(apply_plan(cases$original, explained$plan), explained$text)
  }),
  "pass-4-options-off" = list(expect = "pass", run = function(cases) {
    same_text(fix_text_encoding_only(cases$original),
              fix_encoding_and_explain(cases$original)$text)
  }),
  "pass-5-encoding-only" = list(expect = "pass", run = function(cases) {
    agrees_with_reference("fix_encoding", cases$original,
                          fix_encoding(cases$original), cases$fixed_encoding)
  }),
  "pass-6-extra-layer" = list(expect = "pass", run = function(cases) {
    extra <- cases$reference.extra_layer
    agrees_with_reference("fix_text", extra, fix_text(extra), cases$fixed)
  }),
  "pass-7-plans" = list(expect = "pass", run = function(cases) {
    agrees_with_reference(
      "fix_and_explain", cases$original,
      as.character(fix_and_explain(cases$original)$plan),
      cases$reference.fix_and_explain_plan
    ) & agrees_with_reference(
      "fix_encoding_and_explain", cases$original,
      as.character(fix_encoding_and_explain(cases$original)$plan),
      cases$reference.fix_encoding_plan
    )
  }),

  # tests/test_examples_in_json.py:92, test_failing_json_example(), for the
  # cases marked "fail". Upstream only asserts that these are not repaired;
  # here they must equal the reference version's texts and plans (ADR 0009).
  "fail-fix-text" = list(expect = "fail", run = function(cases) {
    agrees_with_reference("fix_text", cases$original,
                          fix_text(cases$original), cases$reference.fix_text)
  }),
  "fail-fix-and-explain" = list(expect = "fail", run = function(cases) {
    explained <- fix_and_explain(cases$original)
    agrees_with_reference(
      "fix_and_explain", cases$original,
      explained$text, cases$reference.fix_and_explain_text
    ) & agrees_with_reference(
      "fix_and_explain", cases$original,
      as.character(explained$plan), cases$reference.fix_and_explain_plan
    )
  }),
  "fail-encoding-text" = list(expect = "fail", run = function(cases) {
    agrees_with_reference("fix_encoding", cases$original,
                          fix_encoding(cases$original), cases$reference.fix_encoding_text)
  }),
  "fail-encoding-plan" = list(expect = "fail", run = function(cases) {
    explained <- fix_encoding_and_explain(cases$original)
    agrees_with_reference(
      "fix_encoding_and_explain", cases$original,
      explained$text, cases$reference.fix_encoding_text
    ) & agrees_with_reference(
      "fix_encoding_and_explain", cases$original,
      as.character(explained$plan), cases$reference.fix_encoding_plan
    )
  })
)

# Run every check on every case it applies to. One row per case and check:
# `check`, `index`, `passes`, and `error`, the message if the check raised
# one. Each check is one call on the whole vector of its cases.
run_json_checks <- function(cases, checks = json_checks) {
  results <- lapply(names(checks), function(name) {
    rows <- cases[cases$expect == checks[[name]]$expect, , drop = FALSE]
    error <- NA_character_
    passes <- tryCatch(
      checks[[name]]$run(rows),
      error = function(e) {
        error <<- conditionMessage(e)
        rep(FALSE, nrow(rows))
      }
    )
    if (!is.logical(passes) || length(passes) != nrow(rows)) {
      error <- "the check did not return one logical per case"
      passes <- rep(FALSE, nrow(rows))
    }
    data.frame(
      check = rep(name, nrow(rows)), index = rows$index,
      passes = passes %in% TRUE, error = rep(error, nrow(rows)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, results)
}

# The not-yet-passing list: one line per case and check, "<check><tab><index>",
# sorted by check and then by index.
not_yet_passing_path <- function() test_path("not-yet-passing.txt")

read_not_yet_passing <- function(path = not_yet_passing_path()) {
  lines <- readLines(path, encoding = "UTF-8")
  parts <- strsplit(lines, "\t", fixed = TRUE)
  if (!all(lengths(parts) == 2L)) {
    stop(path, " must hold one check and one case index per line, separated by a tab")
  }
  data.frame(
    check = vapply(parts, `[[`, "", 1L),
    index = as.integer(vapply(parts, `[[`, "", 2L)),
    stringsAsFactors = FALSE
  )
}

entry_keys <- function(entries) {
  if (nrow(entries) == 0L) {
    return(character())
  }
  entries <- entries[order(entries$check, entries$index, method = "radix"), , drop = FALSE]
  paste0(entries$check, "\t", entries$index)
}

# Remove from the list every entry whose check now passes, and every entry
# that names no check that exists. This only ever deletes lines. Run it
# through the test file, as data-raw/README.md says.
shrink_not_yet_passing <- function(results, path = not_yet_passing_path()) {
  listed <- unique(entry_keys(read_not_yet_passing(path)))
  failing <- entry_keys(results[!results$passes, , drop = FALSE])
  kept <- failing[failing %in% listed]
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(kept, con, sep = "\n", useBytes = TRUE)
  message("not-yet-passing.txt: kept ", length(kept), " of ", length(listed), " entries")
  invisible(kept)
}
