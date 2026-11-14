# The two exported fixers of the encoding repair, decode_inconsistent_utf8()
# and fix_c1_controls(), against the snapshot reference/fix_encoding.tsv.
# Upstream has no doctest and no test that calls either (ftfy/fixes.py:481
# and :505), so nothing here is translated.

fixer_snapshot <- function() {
  raw <- read_reference_table("fix_encoding.tsv", text = character())
  fill <- function(column) ifelse(raw[[column]] == "", raw$text, raw[[column]])
  data.frame(
    text = stringi::stri_unescape_unicode(raw$text),
    decode_inconsistent_utf8 = unescape_reference(fill("decode_inconsistent_utf8")),
    fix_c1_controls = unescape_reference(fill("fix_c1_controls")),
    stringsAsFactors = FALSE
  )
}

test_that("decode_inconsistent_utf8() repairs mojibake inside other text and leaves the rest", {
  x <- c("\u2603 caf\u00c3\u00a9", "caf\u00e9", "plain", "", NA)

  expect_identical(
    decode_inconsistent_utf8(x),
    c("\u2603 caf\u00e9", "caf\u00e9", "plain", "", NA)
  )
})

test_that("decode_inconsistent_utf8() leaves a sequence that is the whole string", {
  expect_identical(decode_inconsistent_utf8("\u00c3\u00a9"), "\u00c3\u00a9")
  expect_identical(decode_inconsistent_utf8("\u00c3\u00a9 "), "\u00e9 ")
})

test_that("decode_inconsistent_utf8() repairs every sequence of a string, each by itself", {
  expect_identical(
    decode_inconsistent_utf8("\u00e2\u20ac\u0153a\u00e2\u20ac\u009d \u2603 \u00c3\u00a9\u00c3\u00a9 \u00d0\u00b0"),
    "\u201ca\u201d \u2603 \u00e9\u00e9 \u0430"
  )
})

test_that("decode_inconsistent_utf8() gives the reference version's text for every snapshot input", {
  snapshot <- fixer_snapshot()
  expect_gt(sum(snapshot$decode_inconsistent_utf8 != snapshot$text), 500)

  expect_reference(
    "decode_inconsistent_utf8", snapshot$text,
    actual = decode_inconsistent_utf8(snapshot$text),
    reference = snapshot$decode_inconsistent_utf8
  )
})

test_that("fix_c1_controls() reads C1 controls as Windows-1252 and leaves its five holes", {
  x <- c("that\u0092s all\u0085", "\u0080\u0081\u008d\u008f\u0090\u009d\u009f", "plain", "", NA,
         "caf\u00c3\u00a9 \u00a0")

  expect_identical(
    fix_c1_controls(x),
    c("that\u2019s all\u2026", "\u20ac\u0081\u008d\u008f\u0090\u009d\u0178", "plain", "", NA,
      "caf\u00c3\u00a9 \u00a0")
  )
})

test_that("fix_c1_controls() gives the reference version's text for every snapshot input", {
  snapshot <- fixer_snapshot()
  expect_gt(sum(snapshot$fix_c1_controls != snapshot$text), 500)

  expect_reference(
    "fix_c1_controls", snapshot$text,
    actual = fix_c1_controls(snapshot$text),
    reference = snapshot$fix_c1_controls
  )
})

test_that("both fixers keep the shape of the input and give UTF-8 marked text", {
  x <- matrix(
    c("\u2603 caf\u00c3\u00a9", NA, "all\u0085", "plain"), 2,
    dimnames = list(c("a", "b"), c("c", "d"))
  )

  for (fixer in list(decode_inconsistent_utf8, fix_c1_controls)) {
    result <- fixer(x)
    expect_identical(attributes(result), attributes(x))
    expect_identical(is.na(result), is.na(x))
    expect_true(all(Encoding(result[!is.na(result)]) %in% c("UTF-8", "unknown")))
    expect_true(all(stringi::stri_enc_isutf8(result[!is.na(result)])))
  }
})

test_that("one call on the whole vector gives the same texts as one call per element", {
  # Not among the tests issue #14 keeps on CRAN: thousands of calls on one
  # string each, the slowest kind of test here. It runs wherever NOT_CRAN
  # is "true": every job of the R-CMD-check workflow.
  skip_on_cran()
  snapshot <- fixer_snapshot()
  x <- c(snapshot$text[seq(1, nrow(snapshot), by = 3)], NA, snapshot$text[1:50])

  for (fixer in list(decode_inconsistent_utf8, fix_c1_controls)) {
    expect_identical(fixer(x), vapply(seq_along(x), function(i) fixer(x[i]), ""))
  }
})

test_that("a leading U+FEFF survives both fixers", {
  expect_identical(decode_inconsistent_utf8("\ufeff\u2603 \u00c3\u00a9"), "\ufeff\u2603 \u00e9")
  expect_identical(decode_inconsistent_utf8("\ufeff\u00c3\u00a9 \u2603"), "\ufeff\u00e9 \u2603")
  expect_identical(fix_c1_controls("\ufeff\u0085"), "\ufeff\u2026")
})

test_that("a string with many sequences is spliced in order", {
  piece <- c("\u00c3\u00a9", "\u00e2\u20ac\u2122", "\u00c3\u00b1")
  fixed <- c("\u00e9", "\u2019", "\u00f1")
  for (n in c(1L, 2L, 3L, 7L, 64L, 1000L)) {
    at <- rep_len(seq_along(piece), n)
    x <- paste0("\u2603", paste0(piece[at], " ", seq_len(n), collapse = " "), " end")
    expected <- paste0("\u2603", paste0(fixed[at], " ", seq_len(n), collapse = " "), " end")
    expect_identical(decode_inconsistent_utf8(x), expected, label = paste(n, "sequences"))
  }
})

test_that("sequences are cut out at the right place among characters of every width", {
  # One, two, three and four bytes in UTF-8, before and between sequences.
  wide <- intToUtf8(c(0xFEFF, 0x41, 0xE9, 0x2603, 0x1F600, 0x10348))
  mangled <- intToUtf8(c(0xC3, 0xA9))
  x <- c(
    paste0(wide, mangled, wide, mangled, mangled, " ", wide),
    "plain",
    paste0(mangled, wide),
    NA,
    paste0(wide, wide, mangled)
  )
  fixed <- intToUtf8(0xE9)

  expect_identical(
    decode_inconsistent_utf8(x),
    c(
      paste0(wide, fixed, wide, fixed, fixed, " ", wide),
      "plain",
      paste0(fixed, wide),
      NA,
      paste0(wide, wide, fixed)
    )
  )
})
