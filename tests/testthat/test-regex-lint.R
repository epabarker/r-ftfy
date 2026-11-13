# The regex lint (ADR 0005): every regex call in the package passes
# `unix_lines = TRUE` and `stack_limit = 1e9`, never `comments = TRUE`, and
# turns a stack overflow into the package's error. The rules are at the top
# of helper-regex-lint.R.

test_that("regex_opts() gives exactly the options ADR 0005 requires", {
  expect_identical(
    regex_opts(),
    stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9)
  )
  expect_null(regex_opts()$comments)
})

test_that("no regex call in the package omits the options or the overflow guard", {
  expect_identical(regex_lint_namespace(), character(0))
})

test_that("no regex call in the package's source files does, outside functions too", {
  # The source is beside the tests when they run from the source tree, and
  # absent when they run on the installed package.
  root <- test_path("..", "..")
  files <- list.files(file.path(root, "R"), full.names = TRUE)
  files <- files[endsWith(files, ".R")]
  skip_if_not(
    file.exists(file.path(root, "DESCRIPTION")) && length(files) > 0L,
    "the package source is not beside the tests"
  )

  expect_identical(regex_lint_files(files), character(0))
})

test_that("the lint reads the package: it finds the calls that are there", {
  # A lint that saw nothing would pass. These are the calls in R/regex.R.
  seen <- regex_lint(list(
    body(regex_detect), body(regex_locate_all)
  ))
  expect_identical(seen, character(0))
  unguarded <- body(regex_detect)[[2L]][[2L]]
  expect_identical(called_name(unguarded[[1L]]), "stri_detect_regex")
  expect_match(regex_lint(unguarded), "outside regex_guard")
})

test_that("the lint over a namespace reports a bad call under its object's name", {
  namespace <- new.env()
  namespace$fine <- function(x) nchar(x)
  namespace$has_base_regex <- function(x) grepl("a", x)
  namespace$table <- list(1, inner = function(x) stringi::stri_detect_regex(x, "a"))
  namespace$text <- "grepl"

  found <- regex_lint_namespace(namespace)

  expect_length(found, 3L)
  expect_match(found[[1]], "^has_base_regex: a base regex call")
  expect_match(found[2:3], "^table: a regex call")
})

test_that("the lint over source files reports a bad call under its file's name", {
  file <- tempfile(fileext = ".R")
  on.exit(unlink(file))
  writeLines(c(
    "ok <- function(x) strsplit(x, ' ', fixed = TRUE)",
    "at_top_level <- sub('a', 'b', letters)"
  ), file)

  found <- regex_lint_files(file)

  expect_length(found, 1L)
  expect_match(found, basename(file), fixed = TRUE)
  expect_match(found, "a base regex call")
})

test_that("the lint knows the regex functions of stringi and base", {
  sets <- regex_lint_sets()

  expect_true(all(
    c("stri_detect_regex", "stri_locate_all_regex", "stri_replace_all_regex",
      "stri_split_regex", "stri_match_first_regex", "stri_subset_regex",
      "stri_extract_all_regex", "stri_count_regex") %in% sets$stringi_regex
  ))
  expect_true(all(c("stri_detect", "stri_replace_all", "stri_split") %in% sets$stringi_generic))
  expect_true(all(
    c("grep", "grepl", "sub", "gsub", "regexpr", "gregexpr", "regexec", "strsplit")
    %in% sets$base_fixed
  ))
})

test_that("a regex call with the options, inside the guard, passes", {
  expect_identical(regex_lint(quote(
    regex_guard(stringi::stri_detect_regex(x, p, opts_regex = regex_opts()), x)
  )), character(0))
  expect_identical(regex_lint(function(x, p) {
    found <- regex_guard(
      stri_locate_all_regex(x, p, omit_no_match = TRUE, opts_regex = regex_opts()),
      x
    )
    lengths(found)
  }), character(0))
})

test_that("a regex call that omits the options fails", {
  expect_match(
    regex_lint(quote(regex_guard(stringi::stri_detect_regex(x, p), x))),
    "without opts_regex = regex_opts()", fixed = TRUE
  )
  expect_match(
    regex_lint(quote(regex_guard(stri_replace_all_regex(x, p, "", opts_regex = NULL), x))),
    "without opts_regex = regex_opts()", fixed = TRUE
  )
  # Options built on the spot are not read: they must come from regex_opts().
  expect_match(
    regex_lint(quote(regex_guard(
      stringi::stri_detect_regex(x, p, opts_regex = list(unix_lines = TRUE, stack_limit = 1e9)), x
    ))),
    "without opts_regex = regex_opts()", fixed = TRUE
  )
  expect_match(
    regex_lint(quote(regex_guard(stringi::stri_detect_regex(x, p, opts_regex = opts), x))),
    "without opts_regex = regex_opts()", fixed = TRUE
  )
})

test_that("options without unix_lines or the stack limit, or with comments, fail", {
  lint <- function(code) paste(regex_lint(code), collapse = "\n")

  expect_identical(
    lint(quote(stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9))), ""
  )
  expect_match(lint(quote(stringi::stri_opts_regex(stack_limit = 1e9))), "without unix_lines = TRUE")
  expect_match(
    lint(quote(stri_opts_regex(unix_lines = FALSE, stack_limit = 1e9))),
    "without unix_lines = TRUE"
  )
  expect_match(lint(quote(stringi::stri_opts_regex(unix_lines = TRUE))), "without stack_limit = 1e9")
  expect_match(
    lint(quote(stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 0L))),
    "without stack_limit = 1e9"
  )
  expect_match(
    lint(quote(stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9, comments = TRUE))),
    "with comments"
  )
  expect_match(
    lint(quote(stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9, more))),
    "not named"
  )
})

test_that("a regex call outside the overflow guard fails", {
  expect_match(
    regex_lint(quote(stringi::stri_detect_regex(x, p, opts_regex = regex_opts()))),
    "outside regex_guard()", fixed = TRUE
  )
  # The guard covers the expression it evaluates, not its other argument.
  expect_match(
    regex_lint(quote(
      regex_guard(nchar(x), stringi::stri_extract_first_regex(x, p, opts_regex = regex_opts()))
    )),
    "outside regex_guard()", fixed = TRUE
  )
})

test_that("a stringi function that picks its engine by argument name must not pick regex", {
  expect_match(regex_lint(quote(stringi::stri_detect(x, regex = p))), "cannot take the options")
  expect_match(regex_lint(quote(stri_replace_all(x, p, ""))), "cannot take the options")
  expect_identical(regex_lint(quote(stringi::stri_detect(x, fixed = p))), character(0))
})

test_that("a base regex call fails, and a base search with fixed = TRUE is not one", {
  expect_match(regex_lint(quote(grepl("a+", x))), "base regex call")
  expect_match(regex_lint(quote(sub("a", "b", x, perl = TRUE))), "base regex call")
  expect_match(regex_lint(quote(strsplit(x, " > "))), "base regex call")
  expect_match(regex_lint(quote(base::gsub("a", "b", x, fixed = FALSE))), "base regex call")
  expect_match(regex_lint(quote(regexpr(" ", x, fixed = T))), "base regex call")
  expect_match(regex_lint(quote(list.files(dir, pattern = "[.]txt$"))), "filtered by a regex")

  # How the plan class reads a plan's text form.
  expect_identical(regex_lint(quote(strsplit(text, " > ", fixed = TRUE))), character(0))
  expect_identical(regex_lint(quote(regexpr(" ", flat, fixed = TRUE))), character(0))
  expect_identical(regex_lint(quote(grepl(byte, bytes, fixed = TRUE))), character(0))
  expect_identical(regex_lint(quote(list.files(dir))), character(0))
  expect_identical(regex_lint(quote(file.path(dir, "a"))), character(0))
})

test_that("a regex function used as a value, where its arguments cannot be read, fails", {
  expect_match(regex_lint(quote(lapply(x, gsub, pattern = "a", replacement = ""))), "used as a value")
  expect_match(regex_lint(quote(f <- stringi::stri_detect_regex)), "used as a value")
  expect_match(regex_lint(quote(do.call("grepl", list("a", x)))), "called by name")
  expect_match(regex_lint(quote(do.call(stri_detect_regex, args))), "used as a value")
})

test_that("the lint reads default arguments, nested functions and lists of functions", {
  expect_match(regex_lint(function(x, found = grepl("a", x)) found), "base regex call")
  expect_match(
    regex_lint(function(x) vapply(x, function(one) sub("a", "", one), "")),
    "base regex call"
  )
  expect_match(regex_lint(list(a = identity, b = function(x) grep("a", x))), "base regex call")
  expect_match(regex_lint(quote(x[, grepl("a", y)])), "base regex call")
})
