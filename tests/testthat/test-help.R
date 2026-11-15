# Every exported function has a help page with an example that calls it,
# and the package help page says what a user is promised.

# The code of a help page's examples that R CMD check runs: everything but
# what is inside \dontrun{} and \donttest{}, and without comments.
example_code <- function(page) {
  collect <- function(piece) {
    if (rd_tag(piece) %in% c("\\dontrun", "\\donttest", "COMMENT")) {
      return(character())
    }
    if (is.list(piece)) {
      return(unlist(lapply(piece, collect)))
    }
    as.character(piece)
  }
  paste(collect(rd_pieces(page, "\\examples")), collapse = "")
}

# Does `code` call the function `name`?
calls_function <- function(code, name) {
  parsed <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
  if (is.null(parsed)) {
    return(FALSE)
  }
  name %in% all.names(parsed, functions = TRUE)
}

test_that("every export has a help page", {
  exports <- sort(getNamespaceExports("ftfy"))
  pages <- help_by_alias()

  expect_gte(length(exports), 19L)
  expect_identical(setdiff(exports, names(pages)), character())
})

test_that("every export's help page has an example that calls it and that is run", {
  exports <- sort(getNamespaceExports("ftfy"))
  pages <- help_by_alias()

  for (name in intersect(exports, names(pages))) {
    code <- example_code(pages[[name]])
    expect_true(calls_function(code, name), info = paste0("no example calls ", name, "()"))
  }
})

test_that("the example check tells a call from a mention and from code that is not run", {
  expect_true(calls_function("x <- 1\nfix_text(x)", "fix_text"))
  expect_true(calls_function("lapply(x, fix_text)", "fix_text"))
  expect_false(calls_function("# fix_text(x)\nfix_encoding(x)", "fix_text"))
  expect_false(calls_function("print('fix_text')", "fix_text"))
  expect_false(calls_function("", "fix_text"))
})

test_that("the source of every help page is ASCII", {
  skip_without_source_tree()
  root <- help_source_root()
  files <- c(
    list.files(file.path(root, "man"), pattern = "[.]Rd$", full.names = TRUE),
    list.files(file.path(root, "R"), pattern = "[.][Rr]$", full.names = TRUE)
  )

  expect_gt(length(files), 0L)
  for (path in files) {
    expect_true(all(stringi::stri_enc_isascii(readLines(path, warn = FALSE))), info = path)
  }
})

package_page <- function() {
  page <- help_by_alias()[["ftfy-package"]]
  if (is.null(page)) {
    stop("the package has no help page `ftfy-package`")
  }
  page
}

test_that("the package help page states the reference version recorded in DESCRIPTION", {
  upstream <- utils::packageDescription("ftfy")[["Config/ftfy/upstream"]]
  text <- rd_text(package_page())

  expect_identical(upstream, "6.3.1")
  expect_true(grepl(paste0("The reference version is Python ftfy ", upstream, " on Python 3.13"),
                    text, fixed = TRUE))
})

test_that("the package help page opens as ?ftfy and leads to the differences page", {
  pages <- help_by_alias()

  expect_true("ftfy" %in% names(pages))
  links <- vapply(rd_pieces(package_page(), "\\link"), rd_text, "")
  options <- vapply(rd_pieces(package_page(), "\\link"), function(link) {
    option <- attr(link, "Rd_option")
    if (is.null(option)) "" else rd_text(option)
  }, "")
  expect_true("ftfy-differences" %in% c(links, options))
})

test_that("the package help page says to call on whole vectors and what one call costs", {
  text <- rd_text(package_page())

  expect_match(text, "whole vector", fixed = TRUE)
  expect_match(text, "0.6 to 1.6 milliseconds", fixed = TRUE)
})

test_that("the help says that nothing is carried from one element to the next", {
  package <- rd_text(package_page())
  fix_text_page <- rd_text(help_by_alias()[["fix_text"]])

  expect_match(package, "fix_file", fixed = TRUE)
  expect_match(fix_text_page, "fix_file", fixed = TRUE)
})

# NEWS.md is beside the tests only in the source tree; the installed
# package has it as the news R shows.
test_that("NEWS states its convention", {
  skip_without_source_tree()
  news <- squash(paste(readLines(file.path(help_source_root(), "NEWS.md"), warn = FALSE),
                       collapse = " "))

  expect_match(news, "every changed default output is listed", ignore.case = TRUE)
  expect_match(news, "with an example", fixed = TRUE)
  expect_match(news, "never changes in a patch release", fixed = TRUE)
})
