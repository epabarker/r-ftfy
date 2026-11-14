# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The plans of every snapshot row, of each option switched off and of the
# steps that changed nothing are asserted through this export in
# test-fix_encoding.R (`internal_plans()` there calls it).

# Upstream doctest of fix_encoding_and_explain(), ftfy/__init__.py:437.
test_that("fix_encoding_and_explain() gives the repaired text and the plan that produced it", {
  expect_identical(
    fix_encoding_and_explain("s\u00c3\u00b3"),
    data.frame(
      text = "s\u00f3",
      plan = ftfy_plan(list(c("encode", "latin-1"), c("decode", "utf-8")))
    )
  )

  result <- fix_encoding_and_explain("voil\u00c3 le travail")
  expect_identical(result$text, "voil\u00e0 le travail")
  expect_identical(
    result$plan,
    ftfy_plan(list(
      c("encode", "latin-1"), c("transcode", "restore_byte_a0"), c("decode", "utf-8")
    ))
  )
})

test_that("fix_encoding_and_explain() returns a plain data frame, one row per input in input order", {
  x <- c(
    "plain ascii", "G\u00c3\u00a0idhlig", NA, "caf\u00e9",
    "\u00c4\u0152e\u00c5\u00a1tina", "G\u00c3\u00a0idhlig"
  )

  result <- fix_encoding_and_explain(x)

  expect_identical(class(result), "data.frame")
  expect_identical(names(result), c("text", "plan"))
  expect_identical(attr(result, "row.names"), seq_along(x))
  expect_identical(
    result$text,
    c("plain ascii", "G\u00e0idhlig", NA, "caf\u00e9", "\u010ce\u0161tina", "G\u00e0idhlig")
  )
  expect_s3_class(result$plan, "ftfy_plan", exact = TRUE)
  expect_identical(
    as.character(result$plan),
    c("none", "encode latin-1 > decode utf-8", NA, "none",
      "encode sloppy-windows-1252 > decode utf-8", "encode latin-1 > decode utf-8")
  )
  expect_identical(
    Encoding(result$text), c("unknown", "UTF-8", "unknown", "UTF-8", "UTF-8", "UTF-8")
  )
})

test_that("a missing input has an NA plan and unchanged text with no steps has the plan none", {
  result <- fix_encoding_and_explain(c(NA, "plain", "", "caf\u00e9"))

  expect_identical(result$text, c(NA, "plain", "", "caf\u00e9"))
  expect_identical(is.na(result$plan), c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(as.character(result$plan), c(NA, "none", "none", "none"))
  expect_identical(nrow(plan_steps(result$plan)), 0L)

  # An all-NA logical vector is missing text.
  expect_identical(fix_encoding_and_explain(NA), fix_encoding_and_explain(NA_character_))
  expect_identical(as.character(fix_encoding_and_explain(NA)$plan), NA_character_)
})

test_that("unchanged text can have a plan with steps", {
  # U+0081 is a hole of Windows-1252 (ADR 0002: such steps are kept).
  result <- fix_encoding_and_explain("a\u0081b")

  expect_identical(result$text, "a\u0081b")
  expect_identical(as.character(result$plan), "transcode fix_c1_controls")
})

test_that("one string gives one row and no string gives no rows", {
  one <- fix_encoding_and_explain("s\u00c3\u00b3")
  expect_identical(dim(one), c(1L, 2L))

  none <- fix_encoding_and_explain(character())
  expect_identical(class(none), "data.frame")
  expect_identical(dim(none), c(0L, 2L))
  expect_identical(none$text, character())
  expect_s3_class(none$plan, "ftfy_plan", exact = TRUE)
  expect_length(none$plan, 0L)
})

test_that("fix_encoding_and_explain() does not carry names, dim or dimnames into the data frame", {
  values <- c("s\u00c3\u00b3", "plain", NA, "caf\u00c3\u00a9")
  bare <- fix_encoding_and_explain(values)

  named <- fix_encoding_and_explain(stats::setNames(values, c("a", "b", "c", "d")))
  grid <- fix_encoding_and_explain(matrix(values, 2L, dimnames = list(c("r1", "r2"), c("x", "y"))))

  expect_identical(named, bare)
  expect_identical(grid, bare)
  expect_null(attributes(named$text))
  expect_identical(attributes(named$plan), list(class = "ftfy_plan"))
  expect_identical(rownames(named), as.character(1:4))
})

test_that("fix_encoding_and_explain() takes options by name and through a saved config", {
  x <- c("voil\u00c3 le travail", "caf\u00c3\u00a9", NA)

  off <- fix_encoding_and_explain(x, restore_byte_a0 = FALSE, decode_inconsistent_utf8 = FALSE)
  expect_identical(off$text, c("voil\u00c3 le travail", "caf\u00e9", NA))
  expect_identical(as.character(off$plan), c("none", "encode latin-1 > decode utf-8", NA))
  expect_identical(
    fix_encoding_and_explain(
      x, config = ftfy_config(restore_byte_a0 = FALSE, decode_inconsistent_utf8 = FALSE)
    ),
    off
  )
  # A named argument overrides the saved config.
  expect_identical(
    fix_encoding_and_explain(
      x, restore_byte_a0 = TRUE, config = ftfy_config(restore_byte_a0 = FALSE)
    ),
    fix_encoding_and_explain(x)
  )

  none <- fix_encoding_and_explain(x, fix_encoding = FALSE)
  expect_identical(none$text, x)
  expect_identical(as.character(none$plan), c("none", "none", NA))

  expect_error(fix_encoding_and_explain(x, explain = TRUE), "Unknown option `explain`")
  expect_error(fix_encoding_and_explain(x, FALSE))
})

test_that("the texts are those of fix_encoding() on every snapshot input", {
  snapshot <- read_reference_table("fix_encoding.tsv", text = "text")

  expect_identical(fix_encoding_and_explain(snapshot$text)$text, fix_encoding(snapshot$text))
})

# ADR 0009: plans are compared step for step, and the fail cases are pinned.
test_that("the encoding plans of the 151 pass cases are the reference version's, step for step", {
  cases <- read_json_cases()
  cases <- cases[cases$expect == "pass", ]
  expect_identical(nrow(cases), 151L)
  reference <- plan_steps(ftfy_plan(cases$reference.fix_encoding_plan))
  # Most of the reference plans have steps.
  expect_gt(nrow(reference), 200L)

  result <- fix_encoding_and_explain(cases$original)

  expect_identical(plan_steps(result$plan), reference)
  expect_identical(as.character(result$plan), cases$reference.fix_encoding_plan)
})

test_that("the encoding texts and plans of the 10 fail cases are the reference version's", {
  cases <- read_json_cases()
  cases <- cases[cases$expect == "fail", ]
  expect_identical(nrow(cases), 10L)

  result <- fix_encoding_and_explain(cases$original)

  expect_identical(result$text, cases$reference.fix_encoding_text)
  expect_identical(as.character(result$plan), cases$reference.fix_encoding_plan)
})

test_that("one call on the whole vector gives the same texts and plans as one call per element", {
  # Not among the tests issue #14 keeps on CRAN: thousands of calls on one
  # string each, the slowest kind of test here. It runs wherever NOT_CRAN
  # is "true": every job of the R-CMD-check workflow.
  skip_on_cran()
  snapshot <- read_reference_table("fix_encoding.tsv", text = "text")
  cases <- read_json_cases()
  x <- c(snapshot$text, NA, cases$original, snapshot$text[1:200], NA, cases$original[1:40])
  # A fixed shuffle, so that duplicates and `NA`s are not next to each other.
  x <- x[order((seq_along(x) * 7919) %% 2503, seq_along(x))]
  names(x) <- paste0("n", seq_along(x))
  expect_gt(anyDuplicated(x), 0L)

  whole <- fix_encoding_and_explain(x)
  each <- lapply(seq_along(x), function(i) fix_encoding_and_explain(x[i]))

  expect_identical(unique(vapply(each, nrow, 0L)), 1L)
  expect_identical(whole$text, vapply(each, function(one) one$text, ""))
  expect_identical(
    as.character(whole$plan), vapply(each, function(one) as.character(one$plan), "")
  )
  expect_identical(nrow(whole), length(x))
  expect_identical(is.na(whole$text), unname(is.na(x)))
  expect_identical(is.na(whole$plan), unname(is.na(x)))
  # Many of the plans have steps, so the comparison is not of nothing.
  expect_gt(sum(!is.na(whole$plan) & as.character(whole$plan) != "none"), 1500L)
})
