# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Upstream doctest of fix_encoding_and_explain(), ftfy/__init__.py:403.
test_that("fix_encoding() repairs a one-layer mix-up", {
  expect_identical(fix_encoding("s\u00c3\u00b3"), "s\u00f3")
  expect_identical(fix_encoding("\u00e2\u20ac\u2122"), "\u2019")
})

test_that("fix_encoding() works over a whole vector and leaves text that is not bad unchanged", {
  x <- c(
    "caf\u00c3\u00a9", "caf\u00e9", "plain", "", NA,
    "it\u00e2\u20ac\u2122s", "\u00c3\u00a9t\u00c3\u00a9", "caf\u00c3\u00a9"
  )

  expect_identical(
    fix_encoding(x),
    c("caf\u00e9", "caf\u00e9", "plain", "", NA, "it\u2019s", "\u00e9t\u00e9", "caf\u00e9")
  )
})

test_that("fix_encoding() leaves quotes, ligatures and line breaks alone", {
  x <- c("\u201cquoted\u201d", "\ufb01n", "one\r\ntwo", "&amp;")

  expect_identical(fix_encoding(x), x)
})

# The reach of this ticket: one layer between `latin-1` or
# `sloppy-windows-1252` and `utf-8`, ending in text that is not bad. Ticket
# #36 completes the heuristic; it deletes `in_reach()` and compares every
# row exactly.
in_reach <- function(snapshot) {
  snapshot$plan %in% c(
    "none",
    "encode latin-1 > decode utf-8",
    "encode sloppy-windows-1252 > decode utf-8"
  ) & !is_bad(snapshot$fixed)
}

test_that("fix_encoding() gives the reference version's text for every snapshot input in reach", {
  snapshot <- read_reference_table("fix_encoding.tsv", text = c("text", "fixed"))
  expect_gt(nrow(snapshot), 2000)
  reach <- in_reach(snapshot)
  expect_gt(sum(reach & snapshot$plan != "none"), 80)

  result <- fix_encoding(snapshot$text)

  expect_reference(
    "fix_encoding", snapshot$text[reach],
    actual = result[reach], reference = snapshot$fixed[reach]
  )
})

test_that("out of reach, fix_encoding() returns the input unchanged, never a wrong text", {
  snapshot <- read_reference_table("fix_encoding.tsv", text = c("text", "fixed"))

  result <- fix_encoding(snapshot$text)

  wrong <- result != snapshot$fixed & result != snapshot$text
  expect_identical(snapshot$text[wrong], character())
})

test_that("fix_encoding() gives UTF-8 marked text", {
  expect_identical(Encoding(fix_encoding(c("caf\u00c3\u00a9", "caf\u00e9", "plain"))),
                   c("UTF-8", "UTF-8", "unknown"))
})
