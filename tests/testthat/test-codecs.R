# Seam 2: the generated codec tables, below the API. A wrong table entry can
# pass the tests of the exported functions by chance (resolution of #10).
#
# The tests run over every table the package ships, so a codec added to
# data-raw/codecs/ is covered without a change here. Expected holes are
# listed per codec in `codec_holes` below; a codec with no entry there has
# no holes.

codec_names <- function() names(ftfy:::codec_tables)

# From the resolution of #10 and research/codec-table-probes: the bytes each
# codec with holes leaves unassigned.
codec_holes <- list()

test_that("the two codecs the tracer needs are shipped", {
  expect_true(all(c("latin-1", "sloppy-windows-1252") %in% codec_names()))
})

test_that("every codec table is 256 code points or holes", {
  for (codec in codec_names()) {
    table <- ftfy:::codec_tables[[codec]]
    expect_type(table, "integer")
    expect_length(table, 256L)
    assigned <- table[!is.na(table)]
    expect_true(all(assigned >= 0L & assigned <= 0x10FFFFL), info = codec)
    expect_identical(anyDuplicated(assigned), 0L, info = codec)
  }
})

test_that("the holes of every codec are the ones the research found", {
  for (codec in codec_names()) {
    expected <- codec_holes[[codec]]
    if (is.null(expected)) {
      expected <- integer()
    }
    holes <- which(is.na(ftfy:::codec_tables[[codec]])) - 1L
    expect_identical(holes, as.integer(expected), info = codec)
  }
})

test_that("byte 1A decodes to U+FFFD in every sloppy codec, and to itself elsewhere", {
  for (codec in codec_names()) {
    expected <- if (startsWith(codec, "sloppy-")) 0xFFFDL else 0x1AL
    expect_identical(ftfy:::codec_tables[[codec]][[0x1A + 1L]], expected, info = codec)
  }
})

test_that("latin-1 decodes every byte to the character with the same number", {
  expect_identical(ftfy:::codec_tables[["latin-1"]], 0:255)
})

test_that("sloppy-windows-1252 is windows-1252 with its five holes filled from latin-1", {
  table <- ftfy:::codec_tables[["sloppy-windows-1252"]]
  expect_identical(table[c(0x81, 0x8D, 0x8F, 0x90, 0x9D) + 1L],
                   c(0x81L, 0x8DL, 0x8FL, 0x90L, 0x9DL))
  expect_identical(table[c(0x80, 0x92, 0x99, 0x9F) + 1L],
                   c(0x20ACL, 0x2019L, 0x2122L, 0x0178L))
  same <- setdiff(0:255, c(0x1A, 0x80:0x9F))
  expect_identical(table[same + 1L], same)
})

test_that("every assigned byte but 00 encodes back to itself", {
  for (codec in codec_names()) {
    table <- ftfy:::codec_tables[[codec]]
    bytes <- which(!is.na(table))[-1L] - 1L
    text <- intToUtf8(table[bytes + 1L])

    expect_true(ftfy:::codec_can_encode(text, codec), info = codec)
    encoded <- ftfy:::codec_encode(text, codec)
    expect_identical(utf8ToInt(encoded), bytes, info = codec)
  }
})

test_that("a character outside a codec cannot be encoded with it", {
  x <- c("caf\u00e9", "\u20ac", "\u0081", "\u0080", "\ufffd", "\u001a", "", "\ufeffa", NA)

  expect_identical(
    ftfy:::codec_can_encode(x, "latin-1"),
    c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NA)
  )
  expect_identical(
    ftfy:::codec_can_encode(x, "sloppy-windows-1252"),
    c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, NA)
  )
})

test_that("strict utf-8 decoding marks valid bytes as UTF-8 and fails on the rest", {
  # Bytes are held as the characters U+0001 to U+00FF.
  bytes <- c("caf\u00c3\u00a9", "\u00e2\u0080\u0099", "caf\u00e9", "\u00c3", "plain", "")

  decoded <- ftfy:::decode_utf8(bytes)

  expect_identical(decoded, c("caf\u00e9", "\u2019", NA, NA, "plain", ""))
  expect_identical(Encoding(decoded), c("UTF-8", "UTF-8", "unknown", "unknown", "unknown", "unknown"))
})
