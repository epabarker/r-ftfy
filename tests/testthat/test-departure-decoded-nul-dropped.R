# Departure `decoded-nul-dropped` (inst/departures/decoded-nul-dropped.dcf,
# ADR 0007): C0 80 decoded with `utf-8-variants` gives nothing, where the
# reference version gives U+0000.
#
# Asserted here at the decoder level and through fix_encoding(). Ticket
# #41 adds the assertions through fix_text().

# The bytes of 'null\u00c0\u20acseparated' in sloppy-windows-1252.
nul_bytes <- function() "null\u00c0\u0080separated"

test_that("a decoded C0 80 is dropped", {
  expect_identical(ftfy:::codec_decode(nul_bytes(), "utf-8-variants"), "nullseparated")
  expect_identical(
    ftfy:::codec_decode(c("\u00c0\u0080", "\u00c0\u0080\u00c0\u0080a", "caf\u00c3\u00a9\u00c0\u0080"),
                        "utf-8-variants"),
    c("", "a", "caf\u00e9")
  )
})

test_that("the text that encodes to C0 80 decodes to nothing in its place", {
  bytes <- ftfy:::codec_try_encode("null\u00c0\u20acseparated", "sloppy-windows-1252")

  expect_identical(bytes, nul_bytes())
  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), "nullseparated")
})

test_that("the bytes on the two sides of a dropped C0 80 are not joined", {
  # E2 82 AC is the euro sign; with C0 80 inside it, it is undecodable, as
  # it is in the reference version.
  bytes <- c("\u00e2\u00c0\u0080\u0082\u00ac", "\u00e2\u0082\u00c0\u0080\u00ac")

  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), c(NA_character_, NA_character_))
})

test_that("strict utf-8 does not decode C0 80", {
  expect_identical(ftfy:::codec_decode(nul_bytes(), "utf-8"), NA_character_)
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["decoded-nul-dropped"]]
  # The reference version's text, still escaped: see unescape_reference().
  reference <- unescape_reference("null\\u0000separated")
  actual <- ftfy:::codec_decode(nul_bytes(), "utf-8-variants")
  difference <- function(...) {
    utils::modifyList(
      list(fun = decoder_fun, input = nul_bytes(), reference = reference, actual = actual),
      list(...)
    )
  }

  expect_true(matcher(difference()))
  expect_true(matcher(difference(fun = "fix_encoding", input = "null\u00c0\u20acseparated")))
  # Not this departure: another text, a failure, or a reference without U+0000.
  expect_false(matcher(difference(actual = "null separated")))
  expect_false(matcher(difference(actual = NA_character_)))
  expect_false(matcher(difference(actual = simpleError("invalid UTF-8"))))
  expect_false(matcher(difference(reference = "null separated")))
  expect_false(matcher(difference(reference = "nullseparated", actual = "nullseparate")))
})

test_that("fix_encoding() puts nothing in place of a decoded C0 80", {
  # The reference version gives 'null\\x00separated', 'caf\\xe9 \\x00
  # cr\\xe8me \\x00' and 'sch\\xf6n \\x00' (run on ftfy 6.3.1 with Python 3.13).
  expect_identical(
    fix_encoding(c("null\u00c0\u20acseparated",
                   "caf\u00c3\u00a9 \u00c0\u20ac cr\u00c3\u00a8me \u00c0\u20ac",
                   "sch\u00c3\u00b6n \u00c0\u0080")),
    c("nullseparated", "caf\u00e9  cr\u00e8me ", "sch\u00f6n ")
  )
})

test_that("the two characters alone are not bad enough to be repaired, as in the reference version", {
  expect_identical(fix_encoding("\u00c0\u20ac"), "\u00c0\u20ac")
})

test_that("the registry entry matches the difference in fix_encoding()", {
  matcher <- departure_matchers()[["decoded-nul-dropped"]]
  text <- c("null\u00c0\u20acseparated", "sch\u00c3\u00b6n \u00c0\u0080")
  reference <- unescape_reference(c("null\\u0000separated", "sch\\u00F6n \\u0000"))
  actual <- fix_encoding(text)

  for (i in seq_along(text)) {
    expect_true(matcher(list(fun = "fix_encoding", input = text[[i]],
                             reference = reference[[i]], actual = actual[[i]])))
    # Returning the input unchanged is not this departure.
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = reference[[i]], actual = text[[i]])))
  }
})
