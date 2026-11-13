# Departure `invalid-utf8-input` (inst/departures/invalid-utf8-input.dcf):
# invalid UTF-8 input is an error, where the reference version accepts the
# nearest thing a Python string can hold.

invalid_utf8 <- function() {
  # A Latin-1 byte, a lone surrogate, CESU-8, Java's NUL, a cut-off sequence.
  x <- c("caf\xe9", "\xed\xa0\x80", "\xed\xa0\xbd\xed\xb8\x8a", "\xc0\x80", "\xe2\x82")
  Encoding(x) <- "UTF-8"
  x
}

test_that("invalid UTF-8 input is an error in every export that takes text", {
  for (x in invalid_utf8()) {
    expect_error(fix_encoding(x), "invalid UTF-8")
    expect_error(badness(x), "invalid UTF-8")
    expect_error(is_bad(x), "invalid UTF-8")
  }
})

test_that("the error names the first offending elements and hints at the cause", {
  x <- c("fine", invalid_utf8()[[1]], NA, "caf\u00c3\u00a9", invalid_utf8()[[2]])

  expect_error(fix_encoding(x), "invalid UTF-8 in 2 of 5 elements.*first at: 2, 5.*wrong codec")
})

test_that("no invalid input is repaired: one bad element fails the whole call", {
  x <- c("caf\u00c3\u00a9", invalid_utf8()[[1]])

  expect_error(fix_encoding(x), "invalid UTF-8")
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["invalid-utf8-input"]]
  x <- invalid_utf8()[[1]]
  raised <- tryCatch(fix_encoding(x), error = identity)

  expect_true(matcher(list(fun = "fix_encoding", input = x,
                           reference = x, actual = raised)))
  # A text that differs is not this departure, nor is an error on valid input.
  expect_false(matcher(list(fun = "fix_encoding", input = x,
                            reference = x, actual = "cafe")))
  expect_false(matcher(list(fun = "fix_encoding", input = "caf\u00e9",
                            reference = "caf\u00e9", actual = raised)))
})
