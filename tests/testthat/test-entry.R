# The minimal entry step, seen through the exports that run it.

test_that("a missing string gives NA of the result's type", {
  x <- c("caf\u00c3\u00a9", NA, "plain", NA)

  expect_identical(badness(x), c(1L, NA, 0L, NA))
  expect_identical(is_bad(x), c(TRUE, NA, FALSE, NA))
  expect_identical(badness(NA_character_), NA_integer_)
  expect_identical(is_bad(NA_character_), NA)
  expect_identical(fix_encoding(x), c("caf\u00e9", NA, "plain", NA))
  expect_identical(fix_encoding(NA_character_), NA_character_)
})

test_that("a zero-length character vector gives a zero-length result", {
  expect_identical(badness(character()), integer())
  expect_identical(is_bad(character()), logical())
  expect_identical(fix_encoding(character()), character())
})

test_that("a leading U+FEFF is data, not something to strip", {
  # "\u00c2 " at the true start is bad; after U+FEFF it is not at the start.
  expect_identical(badness(c("\u00c2 x", "\ufeff\u00c2 x")), c(1L, 0L))
  expect_identical(is_bad(c("\u00c2 x", "\ufeff\u00c2 x")), c(TRUE, FALSE))
})

test_that("fix_encoding() keeps a leading U+FEFF", {
  x <- c("\ufeffplain", "\ufeffcaf\u00e9", "\ufeffcaf\u00c3\u00a9")

  result <- fix_encoding(x)

  expect_identical(result[1:2], x[1:2])
  # The reference version repairs the third to "\ufeffcaf\u00e9", by a part
  # of the heuristic that is not built yet. Either way U+FEFF stays first.
  expect_true(result[[3]] %in% c(x[[3]], "\ufeffcaf\u00e9"))
})

test_that("anything but a character vector is an error suggesting as.character()", {
  rejected <- list(
    factor("caf\u00c3\u00a9"), 1, 1L, TRUE, list("a"), NULL, as.raw(1),
    as.Date("2024-01-01")
  )
  for (x in rejected) {
    expect_error(badness(x), "as.character()", fixed = TRUE)
    expect_error(is_bad(x), "as.character()", fixed = TRUE)
    expect_error(fix_encoding(x), "as.character()", fixed = TRUE)
  }
})

test_that("invalid UTF-8 is an error naming the first offending elements", {
  x <- c("fine", "caf\xe9", NA, "\xc3\x28")
  Encoding(x) <- "UTF-8"

  expect_error(badness(x), "invalid UTF-8.*first at: 2, 4.*wrong codec")
  expect_error(is_bad(x), "invalid UTF-8.*first at: 2, 4.*wrong codec")
  expect_error(fix_encoding(x), "invalid UTF-8.*first at: 2, 4.*wrong codec")
})
