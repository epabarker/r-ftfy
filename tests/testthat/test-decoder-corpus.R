# Seam 2: the decoders of `utf-8` and `utf-8-variants`, below the API,
# against the committed decoder corpus: byte sequences with what the
# reference version decodes them to, or that it fails (resolution of #10).

test_that("the corpus covers both codecs, both outcomes and both departures", {
  corpus <- read_decoder_corpus()

  expect_gt(nrow(corpus), 5000)
  expect_identical(anyDuplicated(corpus$hex), 0L)
  expect_false(any(grepl("00", gsub("(..)", "\\1 ", corpus$hex), fixed = TRUE)))
  expect_gt(sum(is.na(corpus$utf8)), 100)
  expect_gt(sum(!is.na(corpus$utf8)), 100)
  expect_gt(sum(is.na(corpus$utf8) & !is.na(corpus$variants)), 100)
  expect_setequal(
    corpus$departure,
    c("", "decoded-nul-dropped", "utf8-variants-trailing-newline")
  )
  expect_true(all(c("C00A", "EDA0BDEDB80A", "C080") %in% corpus$hex))
})

test_that("strict utf-8 decoding gives the reference version's text, or fails where it fails", {
  corpus <- read_decoder_corpus()

  decoded <- ftfy:::codec_decode(corpus$bytes, "utf-8")

  expect_identical(decoded, corpus$utf8)
})

test_that("utf-8-variants decoding gives the text the corpus holds for the package", {
  corpus <- read_decoder_corpus()

  decoded <- ftfy:::codec_decode(corpus$bytes, "utf-8-variants")

  expect_identical(decoded, corpus$variants)
})

test_that("utf-8-variants differs from the reference version only by a registered departure", {
  corpus <- read_decoder_corpus()
  decoded <- ftfy:::codec_decode(corpus$bytes, "utf-8-variants")
  same <- (is.na(decoded) & is.na(corpus$python_variants)) |
    (!is.na(decoded) & !is.na(corpus$python_variants) & decoded == corpus$python_variants)

  # The marks are exactly the rows that differ ...
  expect_identical(corpus$departure != "", !same)
  # ... and each is the difference its registry entry describes.
  matchers <- departure_matchers()
  marked <- which(!same)
  matched <- vapply(marked, function(i) {
    difference <- list(
      fun = decoder_fun, input = corpus$bytes[[i]],
      reference = corpus$python_variants[[i]], actual = decoded[[i]]
    )
    isTRUE(matchers[[corpus$departure[[i]]]](difference))
  }, logical(1))
  expect_identical(corpus$hex[marked][!matched], character())
})

test_that("utf-8-variants decodes everything strict utf-8 decodes, to the same text", {
  corpus <- read_decoder_corpus()
  strict <- !is.na(corpus$utf8)

  expect_identical(corpus$variants[strict], corpus$utf8[strict])
})

test_that("the decoders keep NA and the empty string, and mark their text as UTF-8", {
  bytes <- c(NA, "", "plain", "caf\u00c3\u00a9", "\u00ef\u00bb\u00bfa")

  for (codec in c("utf-8", "utf-8-variants")) {
    decoded <- ftfy:::codec_decode(bytes, codec)
    expect_identical(decoded, c(NA, "", "plain", "caf\u00e9", "\ufeffa"), info = codec)
    expect_identical(Encoding(decoded)[4:5], c("UTF-8", "UTF-8"), info = codec)
  }
})

test_that("many surrogate pairs in many strings are rewritten in one pass", {
  pair <- "\u00ed\u00a0\u00bd\u00ed\u00b8\u008a"
  bytes <- c(
    strrep(pair, 3), "plain", paste0("a", pair, "b", pair), NA,
    paste0(pair, "\u00c0\u0080", pair), "\u00ed\u00a0\u00bd", pair
  )

  expect_identical(
    ftfy:::codec_decode(bytes, "utf-8-variants"),
    c(strrep("\U0001f60a", 3), "plain", "a\U0001f60ab\U0001f60a", NA,
      "\U0001f60a\U0001f60a", NA, "\U0001f60a")
  )
})
