# Attribution (ADR 0012, resolution of #17): every script that holds
# material derived from python-ftfy starts with the derived-file header, and
# every other script is listed in not-derived.txt with a reason. The checker
# is in helper-derived.R.

good_header <- paste(
  "# Derived from python-ftfy v6.3.1, ftfy/fixes.py. Copyright 2023 Robyn Speer.",
  "Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS."
)

# A package tree made for these tests: every file starts with the header
# unless `headless` names it.
fixture_tree <- function(headless = character(), not_derived = character()) {
  root <- tempfile("tree")
  files <- c(
    "R/fixes.R", "R/entry.R",
    "tests/testthat.R", "tests/testthat/test-fixes.R", "tests/testthat/departures/some-id.R",
    "data-raw/build.R", "data-raw/regenerate.py",
    "data-raw/generators/table_x.py", "data-raw/generators/_shared.py",
    "data-raw/sysdata/tables.R"
  )
  for (file in files) {
    path <- file.path(root, file)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(if (!file %in% headless) good_header, "x <- 1"), path)
  }
  writeLines(not_derived, file.path(root, "tests", "testthat", "not-derived.txt"))
  root
}

problems_in <- function(root) {
  derived_header_problems(
    root = root,
    not_derived = read_not_derived(file.path(root, "tests", "testthat", "not-derived.txt"))
  )
}

test_that("the header line of #17 is recognised, with one path, several, or a directory", {
  expect_true(is_derived_header(good_header))
  expect_true(is_derived_header(sub("ftfy/fixes.py", "ftfy/__init__.py and ftfy/chardata.py", good_header, fixed = TRUE)))
  expect_true(is_derived_header(sub("ftfy/fixes.py", "ftfy/a.py, ftfy/b.py and tests/test_c.py", good_header, fixed = TRUE)))
  expect_true(is_derived_header(sub("ftfy/fixes.py", "ftfy/", good_header, fixed = TRUE)))
})

test_that("a header with the credit changed or cut short is not the header", {
  expect_false(is_derived_header(sub("Copyright 2023 Robyn Speer", "Copyright 2024 Robyn Speer", good_header, fixed = TRUE)))
  expect_false(is_derived_header(sub("Copyright 2023 Robyn Speer. ", "", good_header, fixed = TRUE)))
  expect_false(is_derived_header(sub("v6.3.1", "v6.3.0", good_header, fixed = TRUE)))
  expect_false(is_derived_header(sub(" Translated to R and modified; see inst/COPYRIGHTS.", "", good_header, fixed = TRUE)))
  expect_false(is_derived_header(sub("ftfy/fixes.py", "", good_header, fixed = TRUE)))
  expect_false(is_derived_header(paste0(good_header, " More.")))
  expect_false(is_derived_header("# Derived from python-ftfy."))
  expect_false(is_derived_header(""))
  expect_false(is_derived_header(NA_character_))
})

test_that("a tree where every script has the header has no problems", {
  root <- fixture_tree()
  on.exit(unlink(root, recursive = TRUE))

  expect_identical(problems_in(root), character())
})

test_that("a ported R file without the header is a problem", {
  root <- fixture_tree(headless = "R/fixes.R")
  on.exit(unlink(root, recursive = TRUE))

  expect_match(problems_in(root), "^R/fixes[.]R: .*header")
})

test_that("a ported test file without the header is a problem, in any directory under the tests", {
  root <- fixture_tree(headless = c("tests/testthat/test-fixes.R", "tests/testthat/departures/some-id.R", "tests/testthat.R"))
  on.exit(unlink(root, recursive = TRUE))

  problems <- problems_in(root)
  expect_length(problems, 3L)
  expect_match(problems, "header")
  expect_setequal(
    sub(": .*$", "", problems),
    c("tests/testthat/test-fixes.R", "tests/testthat/departures/some-id.R", "tests/testthat.R")
  )
})

test_that("a generator script without the header is a problem", {
  for (file in c("data-raw/generators/table_x.py", "data-raw/generators/_shared.py",
                 "data-raw/regenerate.py", "data-raw/sysdata/tables.R")) {
    root <- fixture_tree(headless = file)
    expect_match(problems_in(root), "header", info = file)
    expect_match(problems_in(root), file, fixed = TRUE, info = file)
    unlink(root, recursive = TRUE)
  }
})

test_that("the header must be the first line", {
  root <- fixture_tree()
  on.exit(unlink(root, recursive = TRUE))
  writeLines(c("# A comment.", good_header), file.path(root, "R", "fixes.R"))
  writeLines(character(), file.path(root, "R", "entry.R"))

  expect_length(problems_in(root), 2L)
})

test_that("a file listed as not derived, with a reason, needs no header", {
  root <- fixture_tree(
    headless = c("R/entry.R", "data-raw/build.R", "tests/testthat.R"),
    not_derived = c(
      "# A comment line, and a blank line, are skipped.",
      "",
      "R/entry.R\tR-specific input checks.",
      "data-raw/build.R\tBuilds from committed files; holds nothing from upstream.",
      "tests/testthat.R\tThe standard testthat runner."
    )
  )
  on.exit(unlink(root, recursive = TRUE))

  expect_identical(problems_in(root), character())
})

test_that("a directory listed as not derived covers the headerless scripts under it, and only those", {
  root <- fixture_tree(
    headless = c("tests/testthat/departures/some-id.R", "tests/testthat/test-fixes.R"),
    not_derived = "tests/testthat/departures/\tDeparture matchers: R-only behaviour."
  )
  on.exit(unlink(root, recursive = TRUE))
  # A file in a listed directory may still be derived and say so.
  writeLines(good_header, file.path(root, "tests", "testthat", "departures", "ported.R"))

  expect_match(problems_in(root), "^tests/testthat/test-fixes[.]R: .*header")
  expect_length(problems_in(root), 1L)
})

test_that("a listed directory with no script under it is a problem", {
  root <- fixture_tree(not_derived = "tests/testthat/gone/\tWas removed.")
  on.exit(unlink(root, recursive = TRUE))

  expect_match(problems_in(root), "^tests/testthat/gone/: .*no script")
})

test_that("only a directory below tests/testthat/ can be listed", {
  for (dir in c("R/", "tests/", "tests/testthat/", "data-raw/")) {
    root <- fixture_tree(not_derived = paste0(dir, "\tSaid not to be derived."))
    expect_true(any(grepl("only a directory below tests/testthat/", problems_in(root), fixed = TRUE)), info = dir)
    unlink(root, recursive = TRUE)
  }
})

test_that("a generator script cannot be listed as not derived", {
  for (file in c("data-raw/generators/table_x.py", "data-raw/regenerate.py", "data-raw/sysdata/tables.R")) {
    root <- fixture_tree(headless = file, not_derived = paste0(file, "\tSaid not to be derived."))
    expect_match(problems_in(root), "generator script", info = file)
    unlink(root, recursive = TRUE)
  }
})

test_that("a file cannot both carry the header and be listed as not derived", {
  root <- fixture_tree(not_derived = "R/fixes.R\tSaid not to be derived.")
  on.exit(unlink(root, recursive = TRUE))

  expect_match(problems_in(root), "^R/fixes[.]R: .*both")
})

test_that("a listed file that does not exist is a problem", {
  root <- fixture_tree(not_derived = "R/gone.R\tWas removed.")
  on.exit(unlink(root, recursive = TRUE))

  expect_match(problems_in(root), "^R/gone[.]R: .*no such file")
})

test_that("a line of the list without a reason, or a path listed twice, is an error", {
  path <- tempfile()
  on.exit(unlink(path))

  writeLines("R/entry.R", path)
  expect_error(read_not_derived(path), "reason")
  writeLines("R/entry.R\t  ", path)
  expect_error(read_not_derived(path), "reason")
  writeLines(c("R/entry.R\tOne reason.", "R/entry.R\tAnother."), path)
  expect_error(read_not_derived(path), "twice")
})

test_that("with only the tests present, only the tests are checked", {
  root <- fixture_tree(
    headless = "tests/testthat/test-fixes.R",
    not_derived = c("R/entry.R\tR-specific input checks.", "data-raw/build.R\tBuilds only.")
  )
  on.exit(unlink(root, recursive = TRUE))
  unlink(file.path(root, c("R", "data-raw")), recursive = TRUE)

  problems <- derived_header_problems(
    root = root,
    not_derived = read_not_derived(file.path(root, "tests", "testthat", "not-derived.txt")),
    scope = "tests"
  )
  expect_length(problems, 1L)
  expect_match(problems, "^tests/testthat/test-fixes[.]R: .*header")
})

# The package itself.

test_that("every test file of the package has the derived-file header or is listed as not derived", {
  problems <- derived_header_problems(
    root = test_path("..", ".."),
    not_derived = read_not_derived(test_path("not-derived.txt")),
    scope = "tests"
  )

  expect_identical(problems, character())
})

test_that("every R file and generator script of the package has the derived-file header or is listed as not derived", {
  root <- test_path("..", "..")
  if (!is_source_tree(root)) {
    # R CMD check runs the tests away from R/ and data-raw/. The R CMD check
    # workflow runs this file from the checkout with FTFY_SOURCE_TREE=true.
    if (identical(Sys.getenv("FTFY_SOURCE_TREE"), "true")) {
      fail("FTFY_SOURCE_TREE is true, but R/ and data-raw/ are not beside the tests.")
    }
    skip("Not run from the package's source tree.")
  }

  problems <- derived_header_problems(
    root = root,
    not_derived = read_not_derived(test_path("not-derived.txt"))
  )

  expect_identical(problems, character())
})

test_that("the package has generator scripts for the header check to find", {
  root <- test_path("..", "..")
  skip_if_not(is_source_tree(root), "Not run from the package's source tree.")

  files <- derived_header_files(root)
  expect_true(all(c("R/badness.R", "data-raw/regenerate.py", "data-raw/build.R",
                    "data-raw/generators/pattern_badness.py", "data-raw/sysdata/patterns.R",
                    "tests/testthat.R", "tests/testthat/test-derived-header.R",
                    "tests/testthat/departures/invalid-utf8-input.R") %in% files))
})
