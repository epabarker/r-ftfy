# The departure registry as a whole, and the rule that a comparison with a
# snapshot accepts a difference only when a registry entry matches it.
# Each entry's own behaviour is asserted in test-departure-<id>.R.

test_that("every registry entry has an id, the input, both outputs and what decided it", {
  registry <- read_departures()

  expect_gte(nrow(registry), 1L)
  for (field in departure_fields) {
    expect_false(anyNA(registry[[field]]), info = field)
    expect_true(all(nzchar(trimws(registry[[field]]))), info = field)
  }
  expect_identical(anyDuplicated(registry$Id), 0L)
  expect_match(registry$Id, "^[a-z0-9]+(-[a-z0-9]+)*$")
  expect_identical(registry$file, paste0(registry$Id, ".dcf"))
  # The deciding ticket or ADR: an issue link or a file under docs/adr/.
  expect_match(registry$Decided, "issues/[0-9]+|docs/adr/[0-9]{4}-")
})

test_that("the registry files hold nothing but entries, in ASCII", {
  files <- list.files(departure_dir(), full.names = TRUE)

  expect_match(basename(files), "[.]dcf$")
  for (path in files) {
    expect_true(all(stringi::stri_enc_isascii(readLines(path, warn = FALSE))), info = path)
  }
})

test_that("the registry's first entry is that invalid UTF-8 input is an error", {
  expect_true("invalid-utf8-input" %in% read_departures()$Id)
})

test_that("every registry entry has a test of R's behaviour and a matcher", {
  ids <- read_departures()$Id

  expect_true(all(file.exists(test_path(paste0("test-departure-", ids, ".R")))))
  expect_named(departure_matchers(), ids)
})

test_that("every departure test and matcher belongs to a registry entry", {
  ids <- read_departures()$Id
  tests <- list.files(test_path(), pattern = "^test-departure-.*[.]R$")
  matchers <- list.files(test_path("departures"), pattern = "[.]R$")

  expect_setequal(sub("^test-departure-(.*)[.]R$", "\\1", tests), ids)
  expect_setequal(sub("[.]R$", "", matchers), ids)
})

# A registry made for this test: one entry, whose matcher accepts a result
# that is the reference text without its letter "x".
fixture_registry <- function(dir) {
  dir.create(dir)
  writeLines(
    c("Id: fixture-drops-x", "Title: The letter x is dropped", "Input: Any text.",
      "Reference: The text.", "R: The text without x.", "Decided: docs/adr/0000-fixture.md"),
    file.path(dir, "fixture-drops-x.dcf")
  )
  writeLines(
    c("function(difference) {",
      "  is.character(difference$actual) &&",
      "    identical(difference$actual, gsub('x', '', difference$reference, fixed = TRUE))",
      "}"),
    file.path(dir, "fixture-drops-x.R")
  )
  departure_matchers(dir, matcher_dir = dir)
}

test_that("a comparison accepts a difference only when a registry entry matches it", {
  dir <- tempfile("departures")
  on.exit(unlink(dir, recursive = TRUE))
  matchers <- fixture_registry(dir)
  input <- c("same", "matched", "unmatched", NA)
  reference <- c("same", "axb", "axb", NA)

  expect_identical(
    agrees_with_reference("f", input, c("same", "ab", "a-b", NA), reference, matchers),
    c(TRUE, TRUE, FALSE, TRUE)
  )
  expect_success(
    expect_reference("f", input[1:2], c("same", "ab"), reference[1:2], matchers)
  )
  expect_failure(
    expect_reference("f", input, c("same", "ab", "a-b", NA), reference, matchers),
    "no departure registry entry matches"
  )
})

test_that("with no matching entry, any difference from the snapshot is refused", {
  input <- c("a", "b", NA, "d")

  expect_identical(
    agrees_with_reference("fix_encoding", input, c("a", "B", NA, NA), c("a", "b", "c", "d")),
    c(TRUE, FALSE, FALSE, FALSE)
  )
  expect_failure(expect_reference("fix_encoding", "a", "b", "a"))
  expect_success(expect_reference("fix_encoding", input, input, input))
})

test_that("a registry entry without a matcher is an error", {
  dir <- tempfile("departures")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  writeLines("Id: no-matcher", file.path(dir, "no-matcher.dcf"))

  expect_error(departure_matchers(dir, matcher_dir = dir), "has no matcher")
})
