# The entry step, seen through every export that runs it. The test set is
# `test_entry_step()` in helper-entry-step.R; each export joins it with a
# file of its own in entry-step/.

for (export in names(entry_step_registrations())) {
  registration <- entry_step_registrations()[[export]]
  if (is.null(registration$exempt) &&
        length(entry_step_registration_problems(registration)) == 0L) {
    test_entry_step(export, registration)
  }
}

test_that("every export is in the entry-step test set or exempted by name", {
  registered <- names(entry_step_registrations())
  exports <- getNamespaceExports("ftfy")

  for (export in sort(setdiff(exports, registered))) {
    fail(paste0(
      "The export `", export, "()` is not in the entry-step test set.\n",
      "If it takes text to repair or to judge, it must start with ",
      "`entry_step()` (see R/entry.R): add the file tests/testthat/entry-step/",
      export, ".R, whose value is its registration, for example\n",
      "    list(call = function(x) ", export, "(x), returns = \"character\")\n",
      "If it takes no such text, exempt it: the same file, holding\n",
      "    list(exempt = \"<why it does not run the entry step>\")\n",
      "The elements of a registration are described at the top of ",
      "tests/testthat/helper-entry-step.R."
    ))
  }
  for (file in sort(setdiff(registered, exports))) {
    fail(paste0(
      "tests/testthat/entry-step/", file, ".R is named after `", file,
      "`, which the package does not export. Rename or delete it."
    ))
  }
  expect_true(all(c("badness", "is_bad", "fix_encoding") %in% registered))
})

test_that("every entry-step registration is complete", {
  registrations <- entry_step_registrations()
  for (export in names(registrations)) {
    for (problem in entry_step_registration_problems(registrations[[export]])) {
      fail(paste0("tests/testthat/entry-step/", export, ".R: ", problem))
    }
  }
  expect_gt(length(registrations), 0L)
})

test_that("an incomplete registration is reported, element by element", {
  problems <- entry_step_registration_problems

  expect_identical(problems(list(exempt = "takes a plan")), character())
  expect_identical(
    problems(list(call = identity, returns = "character")), character()
  )
  expect_length(problems(list(exempt = "")), 1L)
  expect_length(problems(list(exempt = "why", call = identity)), 1L)
  expect_match(problems(list(returns = "character")), "`call`")
  expect_match(problems(list(call = identity, returns = "double")), "`returns`")
  expect_match(problems(list(call = identity, returns = "integer")), "`feff`")
  expect_match(
    problems(list(call = identity, returns = "integer",
                  feff = list(x = "no mark", value = 0L))),
    "`feff`"
  )
  expect_match(
    problems(list(call = identity, returns = "character", plan = TRUE)),
    "unknown element `plan`"
  )
})
