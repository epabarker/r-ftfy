# The "differences from Python ftfy" help page is written from the
# departure registry by data-raw/build.R, and must say what the registry
# says.

differences_help <- function() {
  page <- help_by_alias()[["ftfy-differences"]]
  if (is.null(page)) {
    stop("the package has no help page `ftfy-differences`")
  }
  page
}

test_that("the differences page shows every registry entry: input, reference output and R's", {
  registry <- read_departures()
  page <- rd_text(differences_help())

  expect_gte(nrow(registry), 7L)
  for (i in seq_len(nrow(registry))) {
    for (field in c("Title", "Input", "Reference", "R", "Id")) {
      expect_true(
        grepl(squash(registry[[field]][i]), page, fixed = TRUE),
        info = paste("the field", field, "of the entry", registry$Id[i])
      )
    }
  }
})

test_that("the differences page has one section for each entry and no other", {
  registry <- read_departures()
  sections <- rd_pieces(differences_help(), "\\section")
  titles <- vapply(sections, function(section) rd_text(section[[1L]]), "")

  expect_setequal(titles, squash(registry$Title))
  expect_identical(anyDuplicated(titles), 0L)
})

test_that("the differences page opens from help under the names a user would try", {
  pages <- help_by_alias()

  expect_true(all(c("ftfy-differences", "differences", "departures") %in% names(pages)))
  expect_identical(rd_text(rd_pieces(pages[["departures"]], "\\title")[[1L]]),
                   "Differences from Python ftfy")
})

# The generator itself is only in the source tree.
differences_generator <- function() {
  env <- new.env(parent = globalenv())
  sys.source(file.path(help_source_root(), "data-raw", "differences.R"), envir = env)
  env
}

test_that("the committed page is what the registry gives", {
  skip_without_source_tree()
  root <- help_source_root()
  generator <- differences_generator()

  expect_identical(
    readLines(file.path(root, generator$differences_file), warn = FALSE),
    generator$differences_page(
      dir = file.path(root, "inst", "departures"),
      description = file.path(root, "DESCRIPTION")
    ),
    info = "run `Rscript data-raw/build.R` and commit the result"
  )
})

test_that("a changed or added registry entry makes the committed page out of date", {
  skip_without_source_tree()
  root <- help_source_root()
  generator <- differences_generator()
  dir <- tempfile("departures")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  file.copy(list.files(file.path(root, "inst", "departures"), full.names = TRUE), dir)
  current <- function() {
    generator$differences_current(
      path = file.path(root, generator$differences_file),
      dir = dir, description = file.path(root, "DESCRIPTION")
    )
  }
  expect_true(current())

  entry <- file.path(dir, "regex-overflow.dcf")
  lines <- readLines(entry)
  writeLines(sub("^R: An error", "R: A loud error", lines), entry)
  expect_false(current())
  writeLines(lines, entry)
  expect_true(current())

  writeLines(
    c("Id: zz-fixture", "Title: A fixture with 100% of {the} \\odd characters",
      "Input: Any text.", "Reference: The text.", "R: The text, changed.",
      "Decided: docs/adr/0000-fixture.md"),
    file.path(dir, "zz-fixture.dcf")
  )
  expect_false(current())
  page <- generator$differences_page(dir = dir, description = file.path(root, "DESCRIPTION"))
  expect_true(all(stringi::stri_enc_isascii(page)))
  expect_true(any(grepl("100\\% of \\{the\\} \\\\odd characters", page, fixed = TRUE)))
  expect_true(any(grepl("ADR 0000, \\href{https://github.com/epabarker/r-ftfy/blob/main/docs/adr/0000-fixture.md}", page, fixed = TRUE)))
})

test_that("the generator refuses an entry it cannot write", {
  skip_without_source_tree()
  root <- help_source_root()
  generator <- differences_generator()
  dir <- tempfile("departures")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  page <- function() {
    generator$differences_page(dir = dir, description = file.path(root, "DESCRIPTION"))
  }

  expect_error(page(), "no registry entry")
  writeLines(c("Id: half", "Title: Half an entry"), file.path(dir, "half.dcf"))
  expect_error(page(), "must hold one entry with the fields")
})
