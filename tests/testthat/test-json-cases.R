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
test_that("every check on every JSON case passes", {
  results <- run_json_checks(read_json_cases())

  failing <- results[!results$passes, , drop = FALSE]
  errors <- unique(failing$error[!is.na(failing$error)])
  expect_identical(
    sprintf("%s\t%d", failing$check, failing$index), character(),
    info = paste(errors, collapse = "\n")
  )
  # Seven checks on each of the 151 pass cases and four on each of the 10
  # fail cases.
  expect_identical(nrow(results), 7L * 151L + 4L * 10L)
})
