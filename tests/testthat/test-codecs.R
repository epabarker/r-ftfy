# Seam 2: the generated codec tables, below the API. A wrong table entry can
# pass the tests of the exported functions by chance (resolution of #10).
#
# The tests run over every table the package ships, so a codec added to
# data-raw/codecs/ is covered without a change here.

codec_names <- function() names(ftfy:::codec_tables)

# The bytes each codec leaves unassigned, from the resolution of #10 and
# research/codecs-vs-icu.md (section 1.1). A codec with no entry has no
# holes.
codec_holes <- list(
  "windows-1252" = c(0x81, 0x8D, 0x8F, 0x90, 0x9D)
)

# From the same table: the holes of the CPython codec under each sloppy
# codec. A sloppy codec has no holes itself: it fills each of these with
# the character of the same number.
sloppy_filled <- list(
  "sloppy-windows-1252" = c(0x81, 0x8D, 0x8F, 0x90, 0x9D),
  "sloppy-windows-1251" = 0x98,
  "sloppy-windows-1250" = c(0x81, 0x83, 0x88, 0x90, 0x98),
  "sloppy-windows-1253" = c(0x81, 0x88, 0x8A, 0x8C, 0x8D, 0x8E, 0x8F, 0x90, 0x98, 0x9A,
                            0x9C, 0x9D, 0x9E, 0x9F, 0xAA, 0xD2, 0xFF),
  "sloppy-windows-1254" = c(0x81, 0x8D, 0x8E, 0x8F, 0x90, 0x9D, 0x9E),
  "sloppy-windows-1257" = c(0x81, 0x83, 0x88, 0x8A, 0x8C, 0x90, 0x98, 0x9A, 0x9C, 0x9F,
                            0xA1, 0xA5)
)

# Every byte but 00, as a vector of one-byte strings: element b is byte b.
one_byte_strings <- function() intToUtf8(1:255, multiple = TRUE)

test_that("the shipped tables are the eleven single-byte codecs a plan may name", {
  expect_setequal(codec_names(), ftfy:::plan_codecs[1:11])
  expect_identical(ftfy:::plan_codecs[12:13], c("utf-8", "utf-8-variants"))
  expect_identical(ftfy:::charmap_codecs(), ftfy:::plan_codecs[1:10])
  expect_identical(ftfy:::charmap_codecs()[1:2], c("latin-1", "sloppy-windows-1252"))
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

test_that("every sloppy codec fills the holes the research found with the same number", {
  sloppy <- grep("^sloppy-", codec_names(), value = TRUE)
  expect_setequal(sloppy, names(sloppy_filled))

  for (codec in sloppy) {
    filled <- as.integer(sloppy_filled[[codec]])
    expect_identical(ftfy:::codec_tables[[codec]][filled + 1L], filled, info = codec)
  }
})

test_that("byte 1A decodes to U+FFFD in every sloppy codec, and to itself elsewhere", {
  for (codec in codec_names()) {
    expected <- if (startsWith(codec, "sloppy-")) 0xFFFDL else 0x1AL
    expect_identical(ftfy:::codec_tables[[codec]][[0x1A + 1L]], expected, info = codec)
  }
})

test_that("every codec decodes the other ASCII bytes to themselves", {
  # Upstream's `_build_regexes()` (ftfy/chardata.py:53) relies on this.
  ascii <- setdiff(0x00:0x7F, 0x1A)
  for (codec in codec_names()) {
    expect_identical(ftfy:::codec_tables[[codec]][ascii + 1L], ascii, info = codec)
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

  strict <- ftfy:::codec_tables[["windows-1252"]]
  differs <- which(is.na(strict) | strict != table) - 1L
  expect_identical(differs, c(0x1AL, 0x81L, 0x8DL, 0x8FL, 0x90L, 0x9DL))
})

test_that("a few bytes of each table are the characters the code pages give them", {
  # Spot checks against the published code pages, independent of the
  # generator: byte, then code point.
  known <- list(
    "sloppy-windows-1251" = c(0xC0, 0x0410, 0xFF, 0x044F, 0x80, 0x0402),
    "sloppy-windows-1250" = c(0x8A, 0x0160, 0xE8, 0x010D, 0xC0, 0x0154),
    "sloppy-windows-1253" = c(0xC1, 0x0391, 0xF9, 0x03C9, 0x80, 0x20AC),
    "sloppy-windows-1254" = c(0xD0, 0x011E, 0xFD, 0x0131, 0xFE, 0x015F),
    "sloppy-windows-1257" = c(0xC0, 0x0104, 0xFE, 0x017E, 0xA8, 0x00D8),
    "iso-8859-2" = c(0xA1, 0x0104, 0xB3, 0x0142, 0xFF, 0x02D9),
    "macroman" = c(0x80, 0x00C4, 0xC0, 0x00BF, 0xD2, 0x201C, 0xDB, 0x20AC),
    "cp437" = c(0x80, 0x00C7, 0xC0, 0x2514, 0xE1, 0x00DF, 0xFF, 0x00A0),
    "windows-1252" = c(0x80, 0x20AC, 0x9F, 0x0178, 0xE9, 0x00E9)
  )
  expect_true(all(names(known) %in% codec_names()))
  for (codec in names(known)) {
    pairs <- matrix(as.integer(known[[codec]]), ncol = 2L, byrow = TRUE)
    expect_identical(ftfy:::codec_tables[[codec]][pairs[, 1L] + 1L], pairs[, 2L], info = codec)
  }
})

test_that("every assigned byte but 00 round-trips: decode, then encode", {
  bytes <- one_byte_strings()
  for (codec in codec_names()) {
    table <- ftfy:::codec_tables[[codec]][-1L]
    assigned <- !is.na(table)

    decoded <- ftfy:::codec_decode(bytes, codec)
    expect_identical(is.na(decoded), !assigned, info = codec)
    expect_identical(decoded[assigned], intToUtf8(table[assigned], multiple = TRUE), info = codec)

    expect_true(all(ftfy:::codec_can_encode(decoded[assigned], codec)), info = codec)
    expect_identical(ftfy:::codec_encode(decoded[assigned], codec), bytes[assigned], info = codec)
    expect_identical(ftfy:::codec_try_encode(decoded[assigned], codec), bytes[assigned], info = codec)
  }
})

test_that("all assigned bytes in one string round-trip, in both directions", {
  for (codec in codec_names()) {
    table <- ftfy:::codec_tables[[codec]]
    assigned <- which(!is.na(table))[-1L] - 1L
    bytes <- intToUtf8(assigned)
    text <- intToUtf8(table[assigned + 1L])

    expect_identical(ftfy:::codec_decode(bytes, codec), text, info = codec)
    expect_true(ftfy:::codec_can_encode(text, codec), info = codec)
    expect_identical(ftfy:::codec_encode(text, codec), bytes, info = codec)
  }
})

test_that("the characters a codec can encode are exactly the ones in its table", {
  # The set is rebuilt here from the shipped table and compared with what
  # the package built when it was loaded, one character at a time: every
  # character of every table, and every other character up to U+2FFF.
  in_any_table <- unlist(ftfy:::codec_tables, use.names = FALSE)
  candidates <- sort(unique(c(1:0x2FFF, in_any_table[!is.na(in_any_table) & in_any_table > 0L])))
  characters <- intToUtf8(candidates, multiple = TRUE)

  for (codec in codec_names()) {
    table <- ftfy:::codec_tables[[codec]][-1L]
    expect_identical(
      candidates[ftfy:::codec_can_encode(characters, codec)],
      sort(table[!is.na(table)]),
      info = codec
    )
  }
})

test_that("the characters a trial codec can encode are the ones upstream lists", {
  # ftfy/chardata.py:42: ASCII without 1A, and what the bytes 80 to FF and
  # 1A decode to.
  for (codec in ftfy:::charmap_codecs()) {
    table <- ftfy:::codec_tables[[codec]]
    upstream <- c(0x01:0x19, 0x1B:0x7F, table[c(0x80:0xFF, 0x1A) + 1L])
    expect_setequal(table[-1L], upstream)
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
  expect_identical(
    ftfy:::codec_can_encode(x, "windows-1252"),
    c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, NA)
  )
  expect_identical(
    ftfy:::codec_try_encode(x, "windows-1252"),
    c("caf\u00e9", "\u0080", NA, NA, NA, "\u001a", "", NA, NA)
  )
  expect_identical(
    ftfy:::codec_try_encode(x, "sloppy-windows-1252"),
    c("caf\u00e9", "\u0080", "\u0081", NA, "\u001a", NA, "", NA, NA)
  )
})

test_that("decoding with a single-byte codec fails only on a hole", {
  bytes <- c("caf\u00e9", "\u0080", "a\u0081b", "\u001a", "", NA, "plain")

  expect_identical(
    ftfy:::codec_decode(bytes, "windows-1252"),
    c("caf\u00e9", "\u20ac", NA, "\u001a", "", NA, "plain")
  )
  expect_identical(
    ftfy:::codec_decode(bytes, "sloppy-windows-1252"),
    c("caf\u00e9", "\u20ac", "a\u0081b", "\ufffd", "", NA, "plain")
  )
  expect_identical(
    ftfy:::codec_decode(bytes, "macroman"),
    c("caf\u00c8", "\u00c4", "a\u00c5b", "\u001a", "", NA, "plain")
  )
  expect_identical(Encoding(ftfy:::codec_decode(bytes, "macroman"))[1:3], rep("UTF-8", 3))
})

test_that("strict utf-8 decoding marks valid bytes as UTF-8 and fails on the rest", {
  # Bytes are held as the characters U+0001 to U+00FF.
  bytes <- c("caf\u00c3\u00a9", "\u00e2\u0080\u0099", "caf\u00e9", "\u00c3", "plain", "")

  decoded <- ftfy:::decode_utf8(bytes)

  expect_identical(decoded, c("caf\u00e9", "\u2019", NA, NA, "plain", ""))
  expect_identical(Encoding(decoded), c("UTF-8", "UTF-8", "unknown", "unknown", "unknown", "unknown"))
})

test_that("encoding to utf-8 gives the bytes of the text, and utf-8-variants gives the same", {
  x <- c("caf\u00e9", "\u2019", "plain", "", NA, "\ufeffa", "\U0001f60a", "\u0080")
  bytes <- c(
    "caf\u00c3\u00a9", "\u00e2\u0080\u0099", "plain", "", NA,
    "\u00ef\u00bb\u00bfa", "\u00f0\u009f\u0098\u008a", "\u00c2\u0080"
  )

  for (codec in c("utf-8", "utf-8-variants")) {
    expect_identical(ftfy:::codec_can_encode(x, codec), !is.na(x), info = codec)
    expect_identical(ftfy:::codec_encode(x, codec), bytes, info = codec)
    expect_identical(ftfy:::codec_try_encode(x, codec), bytes, info = codec)
    expect_identical(ftfy:::codec_decode(ftfy:::codec_encode(x, codec), codec), x, info = codec)
  }
})

test_that("a codec name is accepted only in its canonical spelling", {
  for (codec in ftfy:::plan_codecs) {
    expect_identical(ftfy:::codec_can_encode("a", codec), TRUE, info = codec)
    expect_identical(ftfy:::codec_encode("a", codec), "a", info = codec)
    expect_identical(ftfy:::codec_try_encode("a", codec), "a", info = codec)
    expect_identical(ftfy:::codec_decode("a", codec), "a", info = codec)
  }

  listed <- paste(ftfy:::plan_codecs, collapse = ", ")
  expect_length(ftfy:::plan_codecs, 13L)
  others <- c(
    "latin1", "Latin-1", "LATIN-1", "iso-8859-1", "cp1252", "windows-1251",
    "sloppy-windows-1255", "sloppy-cp1252", "UTF-8", "utf8", "cesu-8",
    "utf-8-variant", "ascii", "", NA
  )
  for (name in others) {
    for (use in list(ftfy:::codec_can_encode, ftfy:::codec_encode,
                     ftfy:::codec_try_encode, ftfy:::codec_decode)) {
      expect_error(use("a", name), "Unknown codec", info = name)
      expect_error(use("a", name), listed, fixed = TRUE, info = name)
    }
  }
  expect_error(ftfy:::codec_decode("a", c("utf-8", "latin-1")), "Unknown codec")
})
