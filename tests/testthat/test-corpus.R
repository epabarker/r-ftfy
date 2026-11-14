# The comparison of every exported behaviour with the snapshot of the
# larger corpus (ticket #44; the resolution of issue #14, "Larger corpus";
# ADR 0009). Every difference in a text, a plan, `badness` or `is_bad`,
# and every mismatch in which side raised an error, fails unless a
# departure registry entry matches it. The machinery is in
# helper-corpus-comparison.R, the readers in helper-corpus.R.
#
# The corpus is kept out of the built package, so this file skips from the
# tarball and on CRAN. Two environment variables steer it:
#
# - FTFY_CORPUS_COMPARISON: "required" (the corpus jobs of the R-CMD-check
#   workflow) makes a missing corpus a failure, not a skip; "skip" skips
#   the file (the runs of the whole suite in other sessions, which leave
#   the comparison to the corpus jobs). Unset, the corpus is compared when
#   it is there.
# - FTFY_CORPUS_MISMATCHES: the CSV file the mismatches are written to
#   (else a file in the session's temporary directory). It is started
#   afresh by the first test here and holds a header line and one line for
#   each difference no registry entry matches.
#
# Rows tagged with a Unicode version newer than the running ICU's are not
# compared, nor are the rows tagged "unassigned"; the first test says how
# many.
#
# The counts pinned here are of the slice "own" only, so that another
# slice (outside text, ticket #45) changes none of them; the comparison
# itself is over every slice.

skip_unless_comparing <- function() {
  mode <- Sys.getenv("FTFY_CORPUS_COMPARISON")
  if (identical(mode, "skip")) {
    skip("FTFY_CORPUS_COMPARISON is \"skip\": the corpus jobs compare the corpus.")
  }
  if (!corpus_present()) {
    if (identical(mode, "required")) {
      stop("FTFY_CORPUS_COMPARISON is \"required\" but the corpus, tests/corpus/, is not here.")
    }
    skip("The larger corpus, tests/corpus/, is not here (it is not in the built package).")
  }
}

# Everything the tests share, read once for the file: the corpus, the
# rows to compare, every call, the registry's matchers, the differences
# already matched, and the differences found so far, by family.
corpus_state <- new.env()

corpus_loaded <- function() {
  if (is.null(corpus_state$inputs)) {
    inputs <- read_corpus_inputs()
    snapshot <- read_corpus_snapshot()
    corpus_state$inputs <- inputs
    corpus_state$snapshot <- snapshot
    corpus_state$rows <- which(corpus_comparable(snapshot$unicode))
    corpus_state$calls <- corpus_calls(snapshot, inputs)
    corpus_state$matchers <- departure_matchers()
    corpus_state$seen <- new.env()
    corpus_state$differences <- list()
    start_corpus_mismatches()
  }
  corpus_state
}

corpus_families <- c(
  "badness", "fixers", "fix_text", "fix_encoding", "fix_and_explain",
  "fix_encoding_and_explain", "apply_plan"
)

# Compare every call of one family, write what no entry matches to the
# CSV, and fail on it.
expect_family_agrees <- function(family) {
  state <- corpus_loaded()
  calls <- Filter(function(call) identical(call$family, family), state$calls)
  expect_gt(length(calls), 0L)
  differences <- corpus_compare(
    calls, state$snapshot, state$inputs, state$rows, state$matchers, state$seen
  )
  write_corpus_mismatches(differences, state$inputs)
  state$differences[[family]] <- differences
  expect_no_corpus_mismatch(differences, state$inputs, family)
}

# The rows tagged "unassigned" are left out on every ICU. In each, a
# result of the reference version holds a code point that Unicode 15.1,
# the reference version's, has not assigned (category Cn in the reference
# interpreter, and not a noncharacter; no input holds one). What a function
# does with such a code point is not reference behaviour: a later Unicode
# may assign it. So this test always skips, with the counts; the CI script
# accepts this one skip by its name.
test_that("rows tagged newer than the running ICU's Unicode or unassigned are not compared", {
  skip_unless_comparing()
  state <- corpus_loaded()
  tag <- state$snapshot$unicode
  icu <- stringi::stri_info()$Unicode.version
  unassigned <- sum(tag == "unassigned")
  newer <- sum(tag != "unassigned" & !corpus_comparable(tag))

  expect_identical(length(state$rows) + newer + unassigned, nrow(state$snapshot))
  expect_identical(sum(tag == "unassigned" & state$inputs$slice == "own"), 80L)
  skip(sprintf(
    paste(
      "%d of the %d rows of the corpus are compared. Not compared: %d tagged",
      "with a Unicode version newer than this ICU's (%s), whose characters it",
      "may not know; and %d tagged unassigned, where a result of the reference",
      "version holds a code point Unicode 15.1 has not assigned, which is not",
      "reference behaviour."
    ),
    length(state$rows), nrow(state$snapshot), newer, icu, unassigned
  ))
})

test_that("badness() and is_bad() give the reference version's values", {
  skip_unless_comparing()
  expect_family_agrees("badness")
})

test_that("each of the nine text fixers gives the reference version's text", {
  skip_unless_comparing()
  expect_family_agrees("fixers")
})

test_that("fix_text() gives the reference version's text under every option variant", {
  skip_unless_comparing()
  expect_family_agrees("fix_text")
})

test_that("fix_encoding() gives the text of the reference version's fix_encoding_and_explain()", {
  skip_unless_comparing()
  expect_family_agrees("fix_encoding")
})

test_that("fix_and_explain() gives the reference version's text and plan under every option variant", {
  skip_unless_comparing()
  expect_family_agrees("fix_and_explain")
})

test_that("fix_encoding_and_explain() gives the reference version's text and plan under every option variant", {
  skip_unless_comparing()
  expect_family_agrees("fix_encoding_and_explain")
})

test_that("apply_plan() replays the reference version's plans to its texts", {
  # Cross-replay: each plan of the two explaining functions, under every
  # variant, against the text the reference version's function gave; and
  # each default plan against the reference version's own replay of it,
  # which raises for a plan with a `normalize` step.
  skip_unless_comparing()
  expect_family_agrees("apply_plan")
})

test_that("the inputs that hold a noncharacter are compared", {
  # The corpus found that base R's chartr() refused U+FFFE and U+FFFF
  # (test-noncharacters.R); these rows are compared like any other.
  skip_unless_comparing()
  state <- corpus_loaded()
  noncharacter <- stringi::stri_detect_regex(state$inputs$text, "\\p{Noncharacter_Code_Point}")
  tag <- state$snapshot$unicode
  old <- noncharacter & state$inputs$slice == "own" & tag != "unassigned" &
    numeric_version(ifelse(tag == "unassigned", "0", tag)) <= numeric_version("14.0")

  expect_identical(sum(old), 184L)
  expect_true(all(which(noncharacter & corpus_comparable(tag)) %in% state$rows))
  if (corpus_comparable("14.0")) {
    expect_true(all(which(old) %in% state$rows))
  }
})

# How many differences of each comparison the registry entry
# utf8-variants-trailing-newline matches in the slice "own". Every row
# there that shows it is of
# the variant multiline-cut-short, tagged Unicode 6.0 or older, so these
# counts hold on every ICU. They are 0 for the two variants that do not
# repair encoding, and for the fixers, badness() and is_bad().
trailing_newline_counts <- function() {
  variants <- setdiff(names(corpus_variants()), c("no_fix_encoding", "all_off"))
  repeated <- function(keys, n) stats::setNames(rep(n, length(keys)), keys)
  explaining <- c("fix_and_explain", "fix_encoding_and_explain")
  counts <- c(
    repeated(c(paste0("fix_text.", variants), paste0("fix_text.keyword_no_", corpus_sub_options)), 293L),
    fix_text.max_decode_length_10 = 124L,
    fix_text.max_decode_length_60 = 279L,
    repeated(c(
      paste0(rep(explaining, each = length(variants)), ".", variants),
      paste0(rep(explaining, each = length(variants)), ".", variants, ".plan"),
      paste0("fix_encoding.", variants),
      paste0("replay.", rep(explaining, each = length(variants)), ".", variants),
      paste0("apply_plan.", explaining)
    ), 56L)
  )
  counts[order(names(counts), method = "radix")]
}

test_that("the trailing-newline departure is met as often as pinned, in one variant only", {
  skip_unless_comparing()
  state <- corpus_loaded()
  if (!all(corpus_families %in% names(state$differences))) {
    skip("Not every family was compared.")
  }
  differences <- do.call(rbind, unname(state$differences[corpus_families]))
  own <- state$inputs$slice == "own"
  shown <- differences[differences$departure %in% "utf8-variants-trailing-newline", ]
  shown <- shown[own[shown$row], , drop = FALSE]
  cut_short <- state$inputs$variant == "multiline-cut-short" & own

  expect_true(all(cut_short[shown$row]))
  expect_true(all(numeric_version(state$snapshot$unicode[cut_short]) <= numeric_version("6.0")))
  expect_identical(length(unique(shown$row)), 294L)
  counts <- table(shown$key)
  counts <- stats::setNames(as.integer(counts), names(counts))
  expect_identical(counts[order(names(counts), method = "radix")], trailing_newline_counts())
  expect_identical(sum(counts), 10592L)
})

# A sample of the inputs for the test below: every ninth row, every row of
# multiline-cut-short and multiline-blank, and every input that holds a
# noncharacter; with missing strings and repeats spread through it, and
# names. It is a sample because one call per element costs about 6 ms for
# the four functions together, which for all 37,370 inputs is minutes.
whole_vector_sample <- function(inputs) {
  noncharacter <- stringi::stri_detect_regex(inputs$text, "\\p{Noncharacter_Code_Point}")
  picked <- sort(unique(c(
    seq(1L, nrow(inputs), by = 9L),
    which(inputs$variant %in% c("multiline-cut-short", "multiline-blank")),
    which(noncharacter)
  )))
  x <- inputs$text[picked]
  x <- c(x, NA, x[seq(1L, length(x), by = 5L)], NA, NA)
  x <- x[order((seq_along(x) * 7919L) %% 4999L, seq_along(x))]
  names(x) <- paste0("n", seq_along(x))
  x
}

test_that("for the four core functions, one call on a sample of the corpus gives what one call per element gives", {
  skip_unless_comparing()
  state <- corpus_loaded()
  x <- whole_vector_sample(state$inputs)
  expect_true(anyNA(x) && anyDuplicated(x) > 0L)
  expect_gt(length(x), 5000L)
  option_sets <- list(
    list(),
    list(unescape_html = TRUE, remove_control_chars = FALSE, normalization = "NFKC", max_decode_length = 60)
  )

  # The call on one element is made once for each distinct value, on its
  # first place in `x`, and the result is put at every place of that value.
  first <- which(!duplicated(unname(x)))
  place <- match(unname(x), unname(x)[first])

  for (options in option_sets) {
    call <- function(fun, x) do.call(fun, c(list(x), options))
    info <- paste(names(options), collapse = ", ")

    for (fun in list(fix_text, fix_encoding)) {
      whole <- call(fun, x)
      each <- vapply(first, function(i) unname(call(fun, x[i])), "")[place]
      expect_identical(unname(whole), each, info = info)
      expect_identical(names(whole), names(x), info = info)
      expect_identical(is.na(whole), is.na(x), info = info)
    }
    for (fun in list(fix_and_explain, fix_encoding_and_explain)) {
      whole <- call(fun, x)
      each <- lapply(first, function(i) call(fun, x[i]))[place]
      expect_identical(whole$text, vapply(each, function(one) one$text, ""), info = info)
      expect_identical(
        as.character(whole$plan),
        vapply(each, function(one) as.character(one$plan), ""),
        info = info
      )
      expect_identical(is.na(whole$text), unname(is.na(x)), info = info)
    }
  }
})
