# Strict `utf-8` decoding is a validity check made by the platform's
# `iconv()` and stringi's `stri_enc_isutf8()` (ADR 0003). This compares it,
# on the platform the tests run on, with a reference written here from the
# Unicode standard: Table 3-7, "Well-Formed UTF-8 Byte Sequences".
#
#   Code points          1st byte  2nd byte  3rd byte  4th byte
#   U+0000..U+007F       00..7F
#   U+0080..U+07FF       C2..DF    80..BF
#   U+0800..U+0FFF       E0        A0..BF    80..BF
#   U+1000..U+CFFF       E1..EC    80..BF    80..BF
#   U+D000..U+D7FF       ED        80..9F    80..BF
#   U+E000..U+FFFF       EE..EF    80..BF    80..BF
#   U+10000..U+3FFFF     F0        90..BF    80..BF    80..BF
#   U+40000..U+FFFFF     F1..F3    80..BF    80..BF    80..BF
#   U+100000..U+10FFFF   F4        80..8F    80..BF    80..BF
#
# Byte 00 is left out: an R string cannot hold it. Skipped on CRAN, for
# its size (resolution of #10).

# Is each row of bytes one well-formed sequence of Table 3-7? `m` is an
# integer matrix with one to four columns.
one_sequence <- function(m) {
  between <- function(b, low, high) b >= low & b <= high
  tail_byte <- function(b) between(b, 0x80, 0xBF)
  b1 <- m[, 1L]
  switch(
    ncol(m),
    b1 <= 0x7F,
    between(b1, 0xC2, 0xDF) & tail_byte(m[, 2L]),
    ((b1 == 0xE0 & between(m[, 2L], 0xA0, 0xBF)) |
       (between(b1, 0xE1, 0xEC) & tail_byte(m[, 2L])) |
       (b1 == 0xED & between(m[, 2L], 0x80, 0x9F)) |
       (between(b1, 0xEE, 0xEF) & tail_byte(m[, 2L]))) & tail_byte(m[, 3L]),
    ((b1 == 0xF0 & between(m[, 2L], 0x90, 0xBF)) |
       (between(b1, 0xF1, 0xF3) & tail_byte(m[, 2L])) |
       (b1 == 0xF4 & between(m[, 2L], 0x80, 0x8F))) & tail_byte(m[, 3L]) & tail_byte(m[, 4L])
  )
}

# Is each row of bytes well-formed UTF-8: well-formed sequences, end to end?
well_formed <- function(m) {
  if (ncol(m) == 0L) {
    return(rep(TRUE, nrow(m)))
  }
  ok <- rep(FALSE, nrow(m))
  for (width in seq_len(min(4L, ncol(m)))) {
    ok <- ok | (one_sequence(m[, seq_len(width), drop = FALSE]) &
                  well_formed(m[, -seq_len(width), drop = FALSE]))
  }
  ok
}

# The rows of a matrix of bytes as byte strings held as text.
byte_strings <- function(m) {
  characters <- intToUtf8(1:255, multiple = TRUE)
  do.call(paste0, lapply(seq_len(ncol(m)), function(j) characters[m[, j]]))
}

expect_validity_agrees <- function(m) {
  bytes <- byte_strings(m)
  expected <- well_formed(m)

  decoded <- ftfy:::decode_utf8(bytes)

  disagree <- which(is.na(decoded) == expected)
  hex <- apply(m[utils::head(disagree, 5L), , drop = FALSE], 1L, function(row) {
    paste(sprintf("%02X", row), collapse = " ")
  })
  expect_identical(as.character(hex), character())
  expect_identical(length(disagree), 0L)
  # What decodes is the same bytes read as UTF-8.
  valid <- which(expected & !is.na(decoded))
  expect_identical(ftfy:::encode_utf8(decoded[valid]), enc2utf8(bytes[valid]))
}

test_that("the reference from Table 3-7 knows the edges of the table", {
  rows <- function(...) matrix(c(...), ncol = 3L, byrow = TRUE)
  expect_identical(
    well_formed(rows(
      0xE0, 0xA0, 0x80, 0xE0, 0x9F, 0xBF, 0xED, 0x9F, 0xBF, 0xED, 0xA0, 0x80,
      0xEF, 0xBF, 0xBF, 0x41, 0xC2, 0x80, 0xC1, 0x80, 0x41, 0x41, 0xC2, 0x41
    )),
    c(TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE)
  )
  expect_identical(
    well_formed(matrix(c(0xF0, 0x90, 0x80, 0x80, 0xF0, 0x8F, 0xBF, 0xBF,
                         0xF4, 0x8F, 0xBF, 0xBF, 0xF4, 0x90, 0x80, 0x80,
                         0xC3, 0xA9, 0xC3, 0xA9, 0xF5, 0x80, 0x80, 0x80),
                       ncol = 4L, byrow = TRUE)),
    c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE)
  )
})

test_that("strict utf-8 agrees with Table 3-7 on every sequence of one or two bytes", {
  skip_on_cran()

  expect_validity_agrees(matrix(1:255, ncol = 1L))
  expect_validity_agrees(as.matrix(expand.grid(b1 = 0x80:0xFF, b2 = 1:255)))
})

test_that("strict utf-8 agrees with Table 3-7 on sequences of three bytes", {
  skip_on_cran()

  # Every sequence that starts with a three-byte lead byte.
  for (b1 in 0xE0:0xEF) {
    expect_validity_agrees(as.matrix(expand.grid(b1 = b1, b2 = 1:255, b3 = 1:255)))
  }
  # After every other byte from C0 up, every second byte and the third
  # bytes at the edges of the ranges.
  edges <- c(0x01, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF)
  expect_validity_agrees(
    as.matrix(expand.grid(b1 = c(0xC0:0xDF, 0xF0:0xFF), b2 = 1:255, b3 = edges))
  )
})

test_that("strict utf-8 agrees with Table 3-7 on sequences of four bytes at the edges", {
  skip_on_cran()

  edges <- c(0x01, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF)
  expect_validity_agrees(
    as.matrix(expand.grid(b1 = 0xF0:0xFF, b2 = 1:255, b3 = edges, b4 = edges))
  )
  # Two two-byte sequences, and a three-byte sequence beside an ASCII byte.
  expect_validity_agrees(
    as.matrix(expand.grid(b1 = c(0xC1, 0xC2, 0xDF, 0xE0), b2 = edges,
                          b3 = c(0x41, 0xC2, 0xDF, 0xE0, 0xED), b4 = edges))
  )
})
