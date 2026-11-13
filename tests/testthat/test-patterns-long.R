# Long input (ADR 0005): two generated patterns on one string of 4,000,000
# characters, shaped so that the whole string is one match and the regex
# engine must keep state for all of it. The expected spans were checked
# once against the reference version: on ftfy 6.3.1 with Python 3.13,
# finditer() gives the single span (0, 4000000) for each of these strings.
# Skipped on CRAN for their size.

long_length <- 4000000L

test_that("UTF8_DETECTOR_RE matches 4,000,000 characters of unbroken mojibake", {
  skip_on_cran()
  # U+00C3 U+00A9, "e acute" read as Latin-1, repeated.
  x <- strrep("\u00c3\u00a9", long_length %/% 2L)

  found <- regex_locate_all(x, patterns[["UTF8_DETECTOR_RE"]])

  expect_equal(unname(found[[1]]), cbind(1L, long_length, deparse.level = 0))
  expect_true(regex_detect(x, patterns[["UTF8_DETECTOR_RE"]]))
})

test_that("UTF8_DETECTOR_RE finds each run when a long string has two", {
  skip_on_cran()
  run <- strrep("\u00c3\u00a9", long_length %/% 4L)
  x <- paste0(run, "\n", run)

  found <- regex_locate_all(x, patterns[["UTF8_DETECTOR_RE"]])

  half <- long_length %/% 2L
  expect_equal(unname(found[[1]]), cbind(c(1L, half + 2L), c(half, long_length + 1L)))
})

test_that("ANSI_RE matches one escape sequence of 4,000,000 characters", {
  skip_on_cran()
  # ESC [ 1;1; ... 1m
  x <- paste0("\u001b[", strrep("1;", (long_length - 4L) %/% 2L), "1m")
  expect_identical(nchar(x), long_length)

  found <- regex_locate_all(x, patterns[["ANSI_RE"]])

  expect_equal(unname(found[[1]]), cbind(1L, long_length, deparse.level = 0))
})
