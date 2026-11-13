# Derived from python-ftfy v6.3.1, tests/test_examples_in_json.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The upstream JSON cases. The checks themselves are in helper-json-cases.R,
# each with its upstream path and line.

test_that("a missing JSON reader is an error, never a skip", {
  expect_error(json_reader(available = FALSE), "jsonlite")
  expect_error(json_reader(available = FALSE), "never skipped")
  expect_type(json_reader(), "closure")
})

test_that("the JSON cases are upstream's file, byte for byte", {
  # md5 of tests/test_cases.json at python-ftfy v6.3.1 (commit 5340af6).
  expect_identical(
    unname(tools::md5sum(json_cases_path())),
    "b3fbe64f9c3a2325510c4e0dc684c8f4"
  )
})

# tests/test_examples_in_json.py:43, test_well_formed_example()
test_that("there are 161 cases, 151 marked pass and 10 marked fail, identified by index", {
  cases <- read_json_cases()

  expect_identical(cases$index, 0:160)
  expect_identical(sum(cases$expect == "pass"), 151L)
  expect_identical(sum(cases$expect == "fail"), 10L)
  expect_false(anyNA(cases$original))
  expect_false(anyNA(cases$fixed))
})

test_that("the duplicate record runs twice", {
  cases <- read_json_cases()
  expect_identical(cases$original[[8]], cases$original[[11]])

  results <- run_json_checks(cases)

  per_check <- table(results$check)
  pass_checks <- grep("^pass-", names(json_checks), value = TRUE)
  fail_checks <- grep("^fail-", names(json_checks), value = TRUE)
  expect_length(pass_checks, 7L)
  expect_true(all(per_check[pass_checks] == 151L))
  expect_true(all(per_check[fail_checks] == 10L))
  expect_identical(sum(results$index == 7L), 7L)
  expect_identical(sum(results$index == 10L), 7L)
})

# tests/test_examples_in_json.py:48, test_json_example(), and
# tests/test_examples_in_json.py:94, test_failing_json_example()
test_that("every check on every JSON case passes, apart from the not-yet-passing list", {
  results <- run_json_checks(read_json_cases())

  # Set FTFY_SHRINK_NOT_YET_PASSING=true to delete the entries that now pass.
  if (identical(Sys.getenv("FTFY_SHRINK_NOT_YET_PASSING"), "true")) {
    shrink_not_yet_passing(results)
  }

  listed <- read_not_yet_passing()
  listed_keys <- paste0(listed$check, "\t", listed$index)
  all_keys <- entry_keys(results)
  failing <- entry_keys(results[!results$passes, , drop = FALSE])
  passing <- entry_keys(results[results$passes, , drop = FALSE])

  # The list is sorted and has no repeats, so that it has one form.
  expect_identical(listed_keys, entry_keys(listed))
  expect_identical(anyDuplicated(listed_keys), 0L)

  # Every entry names a check that exists on a case it applies to.
  expect_identical(setdiff(listed_keys, all_keys), character())

  # A check that fails must be on the list.
  unlisted <- setdiff(failing, listed_keys)
  errors <- unique(results$error[!is.na(results$error) &
    paste0(results$check, "\t", results$index) %in% unlisted])
  expect_identical(unlisted, character(), info = paste(errors, collapse = "\n"))

  # The list may only shrink: a listed check that now passes must be removed.
  expect_identical(intersect(listed_keys, passing), character())
})
