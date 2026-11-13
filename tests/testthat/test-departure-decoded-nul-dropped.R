# Departure `decoded-nul-dropped` (inst/departures/decoded-nul-dropped.dcf,
# ADR 0007): C0 80 decoded with `utf-8-variants` gives nothing, where the
# reference version gives U+0000.
#
# Asserted here at the decoder level. Ticket #36 adds the assertions
# through fix_encoding() beside these, and ticket #41 through fix_text().

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
